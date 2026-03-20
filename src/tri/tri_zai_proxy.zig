// Z.AI rotating HTTP proxy — daemon control via `tri dev zai-proxy …`
// Script lives in ~/.claude/scripts/zai-rotating-proxy.mjs

const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

const DEFAULT_PORT: u16 = 18789;
const HEALTH_PATH = "/__zai_proxy__/health";

const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const RESET = "\x1b[0m";
const YELLOW = "\x1b[33m";

fn pidFilePath(allocator: Allocator, home: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ home, ".claude", ".zai-proxy.pid" });
}

fn logDirPath(allocator: Allocator, home: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ home, ".claude", "logs" });
}

fn logFilePath(allocator: Allocator, home: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ home, ".claude", "logs", "zai-proxy.log" });
}

fn scriptPath(allocator: Allocator, home: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ home, ".claude", "scripts", "zai-rotating-proxy.mjs" });
}

fn plistSrcPath(allocator: Allocator, home: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ home, ".claude", "scripts", "zai-proxy.launchagent.plist" });
}

fn launchAgentDstPath(allocator: Allocator, home: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ home, "Library", "LaunchAgents", "local.zai-proxy.plist" });
}

fn envDefaultPort() u16 {
    const raw = std.posix.getenv("ZAI_PROXY_PORT") orelse return DEFAULT_PORT;
    return std.fmt.parseInt(u16, raw, 10) catch DEFAULT_PORT;
}

/// Wrap `s` in single quotes for safe use in bash -lc "…".
fn shellSingleQuote(allocator: Allocator, s: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    try buf.append(allocator, '\'');
    var start: usize = 0;
    while (std.mem.indexOfPos(u8, s, start, "'")) |idx| {
        try buf.appendSlice(allocator, s[start..idx]);
        try buf.appendSlice(allocator, "'\\''");
        start = idx + 1;
    }
    try buf.appendSlice(allocator, s[start..]);
    try buf.append(allocator, '\'');
    return buf.toOwnedSlice(allocator);
}

fn parsePortFromArgs(args: []const []const u8) struct { port: u16, consumed: usize } {
    var i: usize = 0;
    var port = envDefaultPort();
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            if (std.fmt.parseInt(u16, args[i + 1], 10)) |p| {
                port = p;
                return .{ .port = port, .consumed = i + 2 };
            } else |_| {}
            i += 1;
        }
    }
    return .{ .port = port, .consumed = args.len };
}

/// Read PID (and optional stored port on line 2) from state file.
fn readPidFile(path: []const u8) !struct {
    pid: ?u32,
    port_line: ?u16,
} {
    const file = std.fs.cwd().openFile(path, .{}) catch return .{ .pid = null, .port_line = null };
    defer file.close();
    const max = 128;
    var buf: [max]u8 = undefined;
    const n = try file.readAll(&buf);
    if (n == 0) return .{ .pid = null, .port_line = null };
    const text = std.mem.trim(u8, buf[0..n], " \t\r\n");
    var it = std.mem.splitScalar(u8, text, '\n');
    const line1 = it.next() orelse return .{ .pid = null, .port_line = null };
    const pid = std.fmt.parseInt(u32, std.mem.trim(u8, line1, " \t\r\n"), 10) catch null;
    const line2 = it.next();
    var port_opt: ?u16 = null;
    if (line2) |ln| {
        port_opt = std.fmt.parseInt(u16, std.mem.trim(u8, ln, " \t\r\n"), 10) catch null;
    }
    return .{ .pid = pid, .port_line = port_opt };
}

fn processAlive(pid: u32) bool {
    std.posix.kill(@intCast(pid), 0) catch return false;
    return true;
}

fn writePidState(allocator: Allocator, path: []const u8, pid: u32, port: u16) !void {
    const dir = std.fs.path.dirname(path) orelse return error.BadPath;
    try std.fs.cwd().makePath(dir);
    const tmp = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmp);
    {
        const f = try std.fs.cwd().createFile(tmp, .{ .truncate = true });
        defer f.close();
        var wbuf: [32]u8 = undefined;
        const blob = try std.fmt.bufPrint(&wbuf, "{d}\n{d}\n", .{ pid, port });
        try f.writeAll(blob);
    }
    try std.fs.cwd().rename(tmp, path);
}

fn removePidFile(path: []const u8) void {
    std.fs.cwd().deleteFile(path) catch {};
}

fn startDaemon(allocator: Allocator, home: []const u8, port: u16) !void {
    const pid_path = try pidFilePath(allocator, home);
    defer allocator.free(pid_path);

    if (readPidFile(pid_path)) |st| {
        if (st.pid) |p| {
            if (processAlive(p)) {
                print("{s}zai-proxy already running{s} (pid {d}, port {d})\n", .{ YELLOW, RESET, p, st.port_line orelse envDefaultPort() });
                return;
            }
        }
    } else |_| {}
    removePidFile(pid_path);

    const script = try scriptPath(allocator, home);
    defer allocator.free(script);
    std.fs.cwd().access(script, .{}) catch {
        print("{s}error:{s} script not found: {s}\n", .{ RED, RESET, script });
        return error.MissingScript;
    };

    const log_dir = try logDirPath(allocator, home);
    defer allocator.free(log_dir);
    try std.fs.cwd().makePath(log_dir);
    const log_path = try logFilePath(allocator, home);
    defer allocator.free(log_path);

    const q_script = try shellSingleQuote(allocator, script);
    defer allocator.free(q_script);
    const q_log = try shellSingleQuote(allocator, log_path);
    defer allocator.free(q_log);

    // One bash: background node, print its PID (same after exec).
    const inner = try std.fmt.allocPrint(allocator,
        \\export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:$PATH"
        \\nohup env ZAI_PROXY_PORT={d} CLAUDE_ENV_PATH="${{CLAUDE_ENV_PATH:-$HOME/.claude/.env}}" node {s} >> {s} 2>&1 & echo $!
    , .{ port, q_script, q_log });
    defer allocator.free(inner);

    // `-lc` takes one argv slot; no extra quoting layer (not via sh -c).
    const argv = [_][]const u8{ "/bin/bash", "-lc", inner };
    var child = std.process.Child.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    try child.spawn();

    const st_out = child.stdout orelse return error.NoPipe;
    defer st_out.close();
    var out_buf: [64]u8 = undefined;
    const read_n = try st_out.readAll(&out_buf);
    _ = try child.wait();

    const pid_text = std.mem.trim(u8, out_buf[0..read_n], " \t\r\n");
    const pid = std.fmt.parseInt(u32, pid_text, 10) catch {
        print("{s}error:{s} could not read background pid from shell\n", .{ RED, RESET });
        return error.BadPid;
    };

    try writePidState(allocator, pid_path, pid, port);
    print("{s}zai-proxy started{s} pid {d} port {d}\n", .{ GREEN, RESET, pid, port });
    print("{s}log:{s} {s}\n", .{ DIM, RESET, log_path });
}

fn stopDaemon(allocator: Allocator, home: []const u8) void {
    const pid_path = blk: {
        const p = pidFilePath(allocator, home) catch break :blk null;
        break :blk p;
    };
    defer if (pid_path) |p| allocator.free(p);
    const path = pid_path orelse {
        print("{s}error:{s} could not build pid path\n", .{ RED, RESET });
        return;
    };

    const st = readPidFile(path) catch {
        print("{s}no pid file{s} ({s})\n", .{ DIM, RESET, path });
        return;
    };
    const pid = st.pid orelse {
        print("{s}no pid in{s} {s}\n", .{ DIM, RESET, path });
        removePidFile(path);
        return;
    };
    if (!processAlive(pid)) {
        print("{s}zai-proxy not running{s} (stale pid {d})\n", .{ YELLOW, RESET, pid });
        removePidFile(path);
        return;
    }
    std.posix.kill(@intCast(pid), std.posix.SIG.TERM) catch {};
    print("{s}sent SIGTERM{s} to pid {d}\n", .{ GREEN, RESET, pid });
    removePidFile(path);
}

fn printStatus(allocator: Allocator, home: []const u8) void {
    const pid_path = pidFilePath(allocator, home) catch {
        print("{s}error:{s} HOME path\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(pid_path);

    const st = readPidFile(pid_path) catch {
        print("{s}zai-proxy:{s} no state file\n", .{ CYAN, RESET });
        return;
    };
    const pid = st.pid orelse {
        print("{s}zai-proxy:{s} no pid in state file\n", .{ CYAN, RESET });
        return;
    };
    const port = st.port_line orelse envDefaultPort();
    if (processAlive(pid)) {
        print("{s}zai-proxy:{s} {s}running{s} pid {d} port {d}\n", .{ CYAN, RESET, GREEN, RESET, pid, port });
        print("  health: http://127.0.0.1:{d}{s}\n", .{ port, HEALTH_PATH });
    } else {
        print("{s}zai-proxy:{s} {s}not running{s} (stale pid {d})\n", .{ CYAN, RESET, YELLOW, RESET, pid });
    }
}

fn runForeground(allocator: Allocator, home: []const u8, port: u16) !void {
    const script = try scriptPath(allocator, home);
    defer allocator.free(script);
    std.fs.cwd().access(script, .{}) catch {
        print("{s}error:{s} script not found: {s}\n", .{ RED, RESET, script });
        return error.MissingScript;
    };
    const port_str = try std.fmt.allocPrint(allocator, "{d}", .{port});
    defer allocator.free(port_str);

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    try env_map.put("ZAI_PROXY_PORT", port_str);

    const node_argv = [_][]const u8{ "node", script };
    var child = std.process.Child.init(&node_argv, allocator);
    child.env_map = &env_map;
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    _ = try child.wait();
}

fn installLaunchAgentMac(allocator: Allocator, home: []const u8) !void {
    if (builtin.os.tag != .macos) {
        print("{s}install:{s} only supported on macOS\n", .{ YELLOW, RESET });
        return;
    }
    const src = try plistSrcPath(allocator, home);
    defer allocator.free(src);
    const dst = try launchAgentDstPath(allocator, home);
    defer allocator.free(dst);

    std.fs.cwd().access(src, .{}) catch {
        print("{s}error:{s} missing {s}\n", .{ RED, RESET, src });
        return error.MissingPlist;
    };

    const dst_dir = std.fs.path.dirname(dst) orelse return error.BadPath;
    try std.fs.cwd().makePath(dst_dir);
    try std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{});

    var uid_buf: [32]u8 = undefined;
    const uid_str = try std.fmt.bufPrint(&uid_buf, "{d}", .{std.posix.getuid()});

    const bootout = try std.fmt.allocPrint(allocator, "launchctl bootout gui/{s}/local.zai-proxy 2>/dev/null; true", .{uid_str});
    defer allocator.free(bootout);
    const boot_argv = [_][]const u8{ "/bin/bash", "-lc", bootout };
    var c1 = std.process.Child.init(&boot_argv, allocator);
    c1.stdout_behavior = .Inherit;
    c1.stderr_behavior = .Inherit;
    try c1.spawn();
    _ = try c1.wait();

    const bootstrap = blk: {
        const q_dst = try shellSingleQuote(allocator, dst);
        defer allocator.free(q_dst);
        break :blk try std.fmt.allocPrint(allocator, "launchctl bootstrap gui/{s} {s}", .{ uid_str, q_dst });
    };
    defer allocator.free(bootstrap);
    const boot2_argv = [_][]const u8{ "/bin/bash", "-lc", bootstrap };
    var c2 = std.process.Child.init(&boot2_argv, allocator);
    c2.stdout_behavior = .Inherit;
    c2.stderr_behavior = .Inherit;
    try c2.spawn();
    _ = try c2.wait();

    print("{s}LaunchAgent installed{s} → {s}\n", .{ GREEN, RESET, dst });
    print("{s}logs:{s} /tmp/zai-proxy.out.log, /tmp/zai-proxy.err.log\n", .{ DIM, RESET });
}

fn uninstallLaunchAgent(allocator: Allocator, home: []const u8) !void {
    if (builtin.os.tag != .macos) return;
    var uid_buf: [32]u8 = undefined;
    const uid_str = try std.fmt.bufPrint(&uid_buf, "{d}", .{std.posix.getuid()});

    const bootout = try std.fmt.allocPrint(allocator, "launchctl bootout gui/{s}/local.zai-proxy 2>/dev/null; true", .{uid_str});
    defer allocator.free(bootout);
    const boot_argv = [_][]const u8{ "/bin/bash", "-lc", bootout };
    var c1 = std.process.Child.init(&boot_argv, allocator);
    c1.stdout_behavior = .Inherit;
    c1.stderr_behavior = .Inherit;
    try c1.spawn();
    _ = try c1.wait();

    const dst = try launchAgentDstPath(allocator, home);
    defer allocator.free(dst);
    std.fs.cwd().deleteFile(dst) catch {};
    print("{s}LaunchAgent removed{s}\n", .{ GREEN, RESET });
}

fn printUsage() void {
    print("\n{s}tri dev zai-proxy{s} — Z.AI rotating proxy daemon\n\n", .{ CYAN, RESET });
    print("  {s}start{s} [--port N]   Start in background (~/.claude/logs/zai-proxy.log)\n", .{ GREEN, RESET });
    print("  {s}stop{s}              SIGTERM + clear pid file\n", .{ GREEN, RESET });
    print("  {s}restart{s} [--port N]\n", .{ GREEN, RESET });
    print("  {s}status{s}            Pid + health URL hint\n", .{ GREEN, RESET });
    print("  {s}run{s} [--port N]    Foreground (debug)\n", .{ GREEN, RESET });
    print("  {s}install{s}           macOS: copy LaunchAgent + launchctl bootstrap\n", .{ GREEN, RESET });
    print("  {s}uninstall{s}         macOS: bootout + remove plist\n\n", .{ GREEN, RESET });
    print("  Env: {s}ZAI_PROXY_PORT{s} (default {d}), {s}CLAUDE_ENV_PATH{s}\n\n", .{ DIM, RESET, DEFAULT_PORT, DIM, RESET });
}

pub fn runZaiProxyCommand(allocator: Allocator, args: []const []const u8) !void {
    const home = std.posix.getenv("HOME") orelse {
        print("{s}error:{s} HOME is not set\n", .{ RED, RESET });
        return error.NoHome;
    };

    if (args.len == 0) {
        printUsage();
        return;
    }
    const sub = args[0];
    const rest = args[1..];

    if (std.mem.eql(u8, sub, "help") or std.mem.eql(u8, sub, "--help") or std.mem.eql(u8, sub, "-h")) {
        printUsage();
        return;
    }

    if (std.mem.eql(u8, sub, "start")) {
        const pr = parsePortFromArgs(rest);
        try startDaemon(allocator, home, pr.port);
        return;
    }
    if (std.mem.eql(u8, sub, "stop")) {
        stopDaemon(allocator, home);
        return;
    }
    if (std.mem.eql(u8, sub, "restart")) {
        stopDaemon(allocator, home);
        const pr = parsePortFromArgs(rest);
        try startDaemon(allocator, home, pr.port);
        return;
    }
    if (std.mem.eql(u8, sub, "status")) {
        printStatus(allocator, home);
        return;
    }
    if (std.mem.eql(u8, sub, "run")) {
        const pr = parsePortFromArgs(rest);
        try runForeground(allocator, home, pr.port);
        return;
    }
    if (std.mem.eql(u8, sub, "install")) {
        try installLaunchAgentMac(allocator, home);
        return;
    }
    if (std.mem.eql(u8, sub, "uninstall")) {
        try uninstallLaunchAgent(allocator, home);
        return;
    }

    print("{s}unknown:{s} {s}\n", .{ RED, RESET, sub });
    printUsage();
}
