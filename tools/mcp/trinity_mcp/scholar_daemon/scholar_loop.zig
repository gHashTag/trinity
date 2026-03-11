// scholar_loop.zig — Core Scholar research loop
// Each cycle: SCAN → RESEARCH → FEED MU → NOTIFY → SLEEP
const std = @import("std");
const telegram = @import("telegram");

pub const Config = struct {
    project_root: []const u8,
    sleep_interval_s: u64,
    max_wakes: u32,
    single_shot: bool,
    tg_config: telegram.TelegramConfig,
};

const CmdResult = struct {
    stdout: []const u8,
    exit_code: u8,
};

/// Run a tri subcommand in the project root directory.
fn runTriCmd(allocator: std.mem.Allocator, project_root: []const u8, args: []const []const u8) CmdResult {
    var bin_buf: [512]u8 = undefined;
    const tri_bin = std.fmt.bufPrint(&bin_buf, "{s}/zig-out/bin/tri", .{project_root}) catch
        return .{ .stdout = "", .exit_code = 1 };

    var argv_buf: [11][]const u8 = undefined;
    argv_buf[0] = "env";
    argv_buf[1] = "AGENT_NAME=scholar";
    argv_buf[2] = tri_bin;
    const n = @min(args.len, 8);
    for (0..n) |i| {
        argv_buf[3 + i] = args[i];
    }

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv_buf[0 .. 3 + n],
        .cwd = project_root,
        .max_output_bytes = 64 * 1024,
    }) catch return .{ .stdout = "", .exit_code = 1 };

    allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    return .{ .stdout = result.stdout, .exit_code = code };
}

/// Write heartbeat JSON to .trinity/scholar/heartbeat.json
fn writeHeartbeat(
    allocator: std.mem.Allocator,
    project_root: []const u8,
    wake: u32,
    fails_found: u32,
    researched: u32,
    fed_mu: u32,
) void {
    var path_buf: [512]u8 = undefined;
    const dir_path = std.fmt.bufPrint(&path_buf, "{s}/.trinity/scholar", .{project_root}) catch return;
    std.fs.cwd().makePath(dir_path) catch |err| {
        std.log.debug("writeHeartbeat: makePath failed: {s}", .{@errorName(err)});
    };

    var file_buf: [512]u8 = undefined;
    const file_path = std.fmt.bufPrint(&file_buf, "{s}/.trinity/scholar/heartbeat.json", .{project_root}) catch return;

    const timestamp = @as(u64, @intCast(std.time.timestamp()));
    const json = std.fmt.allocPrint(
        allocator,
        "{{\"agent\":\"scholar\",\"wake\":{d},\"timestamp\":{d},\"fails_found\":{d},\"researched\":{d},\"fed_mu\":{d}}}",
        .{ wake, timestamp, fails_found, researched, fed_mu },
    ) catch return;
    defer allocator.free(json);

    const file = std.fs.cwd().createFile(file_path, .{}) catch return;
    defer file.close();
    file.writeAll(json) catch |err| {
        std.log.debug("writeHeartbeat: writeAll failed: {s}", .{@errorName(err)});
    };
}

/// Parse failed spec names from tri test report output
fn parseFailedSpecs(allocator: std.mem.Allocator, output: []const u8) !std.ArrayList([]const u8) {
    var specs = std.ArrayList([]const u8){};
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        // Look for "❌" lines with spec names: "| N | spec_name | ❌ ..."
        if (std.mem.indexOf(u8, line, "\xe2\x9d\x8c") == null) continue;
        // Extract spec name between second and third "|"
        var pipe_count: u32 = 0;
        var name_start: usize = 0;
        var name_end: usize = 0;
        for (line, 0..) |c, i| {
            if (c == '|') {
                pipe_count += 1;
                if (pipe_count == 2) name_start = i + 1;
                if (pipe_count == 3) {
                    name_end = i;
                    break;
                }
            }
        }
        if (name_start > 0 and name_end > name_start) {
            const name = std.mem.trim(u8, line[name_start..name_end], " ");
            if (name.len > 0) {
                const duped = try allocator.dupe(u8, name);
                try specs.append(allocator, duped);
            }
        }
    }
    return specs;
}

/// Increment wake count in .trinity/scholar/state/wake_count
fn incrementWake(project_root: []const u8) u32 {
    var path_buf: [512]u8 = undefined;
    const dir_path = std.fmt.bufPrint(&path_buf, "{s}/.trinity/scholar/state", .{project_root}) catch return 1;
    std.fs.cwd().makePath(dir_path) catch |err| {
        std.log.debug("incrementWake: makePath failed: {s}", .{@errorName(err)});
    };

    var file_path_buf: [512]u8 = undefined;
    const file_path = std.fmt.bufPrint(&file_path_buf, "{s}/wake_count", .{dir_path}) catch return 1;

    var count: u32 = 0;
    if (std.fs.cwd().openFile(file_path, .{})) |f| {
        defer f.close();
        var buf: [32]u8 = undefined;
        const n = f.readAll(&buf) catch 0;
        count = std.fmt.parseInt(u32, std.mem.trim(u8, buf[0..n], " \t\n\r"), 10) catch 0;
    } else |_| {}

    count += 1;
    if (std.fs.cwd().createFile(file_path, .{})) |f| {
        defer f.close();
        var num_buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&num_buf, "{d}", .{count}) catch return count;
        f.writeAll(s) catch |err| {
            std.log.debug("incrementWake: writeAll failed: {s}", .{@errorName(err)});
        };
    } else |_| {}

    return count;
}

pub fn run(allocator: std.mem.Allocator, config: Config) !void {
    while (true) {
        const wake = incrementWake(config.project_root);
        std.debug.print("[scholar] Wake #{d}\n", .{wake});

        // 1. SCAN: tri test report → find failed specs
        const report = runTriCmd(allocator, config.project_root, &.{ "test", "report" });
        var fails_found: u32 = 0;
        var researched: u32 = 0;
        var fed_mu: u32 = 0;

        var failed_specs = parseFailedSpecs(allocator, report.stdout) catch std.ArrayList([]const u8){};
        defer {
            for (failed_specs.items) |s| allocator.free(s);
            failed_specs.deinit(allocator);
        }
        if (report.stdout.len > 0) allocator.free(report.stdout);

        fails_found = @intCast(failed_specs.items.len);
        std.debug.print("[scholar] Found {d} failed specs\n", .{fails_found});

        // Telegram: after SCAN
        {
            var scan_buf: [256]u8 = undefined;
            telegram.sendFmt(config.tg_config, &scan_buf, "\xf0\x9f\x93\x9a Scholar Wake #{d}. {d} \xd1\x84\xd0\xb5\xd0\xb9\xd0\xbb\xd0\xbe\xd0\xb2.", .{ wake, fails_found });
        }

        // 2. RESEARCH: for each failed spec, research the error
        const max_research = @min(fails_found, 3); // Max 3 per cycle
        for (failed_specs.items[0..max_research]) |spec_name| {
            // Research the error pattern
            const res = runTriCmd(allocator, config.project_root, &.{ "research", "explain", spec_name });
            if (res.stdout.len > 0) {
                // 3. FEED MU: save to inbox
                var inbox_dir_buf: [512]u8 = undefined;
                const inbox_dir = std.fmt.bufPrint(&inbox_dir_buf, "{s}/.trinity/mu/inbox", .{config.project_root}) catch continue;
                std.fs.cwd().makePath(inbox_dir) catch |err| {
                    std.log.debug("research: makePath failed for inbox: {s}", .{@errorName(err)});
                };

                var inbox_path_buf: [512]u8 = undefined;
                const inbox_path = std.fmt.bufPrint(&inbox_path_buf, "{s}/{s}.txt", .{ inbox_dir, spec_name }) catch continue;

                if (std.fs.cwd().createFile(inbox_path, .{})) |f| {
                    defer f.close();
                    f.writeAll(res.stdout) catch |err| {
                        std.log.debug("research: writeAll failed for inbox file: {s}", .{@errorName(err)});
                    };
                    fed_mu += 1;
                } else |_| {}

                allocator.free(res.stdout);
                researched += 1;
            }
        }

        std.debug.print("[scholar] Researched {d}, fed MU {d}\n", .{ researched, fed_mu });

        // 4. HEARTBEAT
        writeHeartbeat(allocator, config.project_root, wake, fails_found, researched, fed_mu);

        // 5. NOTIFY
        if (researched > 0) {
            var msg_buf: [256]u8 = undefined;
            telegram.sendFmt(config.tg_config, &msg_buf, "\xf0\x9f\x93\x9a Scholar Researched {d}, fed MU {d}. \xf0\x9f\x98\xb4 {d}\xd0\xbc\xd0\xb8\xd0\xbd.", .{ researched, fed_mu, config.sleep_interval_s / 60 });
        }

        if (config.single_shot) break;
        if (config.max_wakes > 0 and wake >= config.max_wakes) break;

        std.debug.print("[scholar] Sleeping {d}s...\n", .{config.sleep_interval_s});
        std.Thread.sleep(config.sleep_interval_s * std.time.ns_per_s);
    }

    std.debug.print("[scholar] Done.\n", .{});
}
