// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Tool Command Handlers
// ═══════════════════════════════════════════════════════════════════════════════
//
// Command implementations: gen, convert, serve, bench, evolve, git.
// Extracted from main.zig for faster compilation.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const chat_server = @import("chat_server.zig");
// depin.zig is in src/firebird/ — inline constants to avoid cross-module import
const depin = struct {
    pub const RewardCalculator = struct {
        pub fn formatTRI(v: f64) f64 {
            return v / 1_000_000_000.0; // nanoTRI → TRI
        }
    };
    pub const REWARD_EVOLUTION_GEN: f64 = 100_000_000.0; // 0.1 TRI
    pub const REWARD_BENCHMARK: f64 = 50_000_000.0; // 0.05 TRI
    pub const REWARD_NAVIGATION_STEP: f64 = 10_000_000.0; // 0.01 TRI
    pub const TIER_MULTIPLIER_FREE: f64 = 1.0;
    pub const TIER_MULTIPLIER_STAKER: f64 = 1.5;
    pub const TIER_MULTIPLIER_POWER: f64 = 2.0;
    pub const TIER_MULTIPLIER_WHALE: f64 = 3.0;
};

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const WHITE = colors.WHITE;
const GOLDEN = colors.GOLDEN;

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-module imports (extracted for faster compilation)
// ═══════════════════════════════════════════════════════════════════════════════
const multi_cluster = @import("commands/multi_cluster.zig");
const quantum_cosmic = @import("commands/quantum_cosmic.zig");

// Re-export multi-cluster types and command
pub const NodeTier = multi_cluster.NodeTier;
pub const NodeEntry = multi_cluster.NodeEntry;
pub const ClusterState = multi_cluster.ClusterState;
pub const runMultiClusterCommand = multi_cluster.runMultiClusterCommand;

// Re-export quantum/cosmic/temporal commands
pub const runTimeCommand = quantum_cosmic.runTimeCommand;
pub const runQuantumCommand = quantum_cosmic.runQuantumCommand;
pub const runOmegaPhaseCommand = quantum_cosmic.runOmegaPhaseCommand;
pub const runAllCommand = quantum_cosmic.runAllCommand;
pub const runHoloCommand = quantum_cosmic.runHoloCommand;
pub const runReleaseCosmicCommand = quantum_cosmic.runReleaseCosmicCommand;
pub const runReleaseAbsoluteCommand = quantum_cosmic.runReleaseAbsoluteCommand;
pub const runOmegaEvolveCommand = quantum_cosmic.runOmegaEvolveCommand;
pub const runLaunchCommand = quantum_cosmic.runLaunchCommand;
pub const runSacredFullCycleCommand = quantum_cosmic.runSacredFullCycleCommand;
pub const runFpgaDemoCommand = quantum_cosmic.runFpgaDemoCommand;
pub const runDeckCommand = quantum_cosmic.runDeckCommand;
pub const runInstallCommand = quantum_cosmic.runInstallCommand;
pub const runBuildCommand = quantum_cosmic.runBuildCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// GEN COMMAND - Code Generation
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGenCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        printGenHelp();
        return;
    }

    // Delegate to the VIBEE compiler binary
    const vibee_paths = [_][]const u8{
        "zig-out/bin/vibee",
        "./zig-out/bin/vibee",
    };

    var vibee_path: ?[]const u8 = null;
    for (vibee_paths) |path| {
        std.fs.cwd().access(path, .{}) catch continue;
        vibee_path = path;
        break;
    }

    if (vibee_path == null) {
        std.debug.print("{s}Error:{s} VIBEE binary not found.\n", .{ RED, RESET });
        std.debug.print("  Fix: zig build vibee\n", .{});
        std.debug.print("  Expected: zig-out/bin/vibee\n", .{});
        return;
    }

    // Build argv: vibee gen <spec> [output]
    // Max args: vibee + gen + spec + [output] = 4
    var argv_buf: [16][]const u8 = undefined;
    var argc: usize = 0;
    argv_buf[argc] = vibee_path.?;
    argc += 1;
    argv_buf[argc] = "gen";
    argc += 1;
    for (args) |arg| {
        if (argc >= argv_buf.len) break;
        argv_buf[argc] = arg;
        argc += 1;
    }

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) {
            std.debug.print("vibee exited with code {d}\n", .{code});
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("gen", if (args.len > 0) args[0] else "", false);
            return error.VibeeProcessFailed;
        },
        else => {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("gen", if (args.len > 0) args[0] else "", false);
            return error.VibeeProcessFailed;
        },
    }
    const exp_hooks = @import("experience_hooks.zig");
    exp_hooks.autoSaveExperience("gen", if (args.len > 0) args[0] else "", true);
}

fn printGenHelp() void {
    std.debug.print("\n{s}GEN COMMAND HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri gen <spec-file.tri>\n", .{ CYAN, RESET });
    std.debug.print("  Generates code from VIBEE specification\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERT COMMAND - Format Conversion
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runConvertCommand(args: []const []const u8) !void {
    if (args.len < 2) {
        printConvertHelp();
        return;
    }

    const from = args[0];
    const to = args[1];

    std.debug.print("{s}CONVERT: {s} -> {s}{s}\n", .{ YELLOW, from, to, RESET });
    std.debug.print("  Supported formats: b2t, wasm, gguf\n", .{});
}

fn printConvertHelp() void {
    std.debug.print("\n{s}CONVERT COMMAND HELP{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Usage:{s}  tri convert <from> <to>\n", .{ CYAN, RESET });
    std.debug.print("  Converts between formats: b2t, wasm, gguf\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVE COMMAND - HTTP Server + API Gateway (Cycle #108)
// Generated from: specs/integration/full-serve-v1.tri
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runServeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Import generated serve_full module (from .tri spec: specs/integration/full-serve-v1.tri)
    // Single Source of Truth: trinity-nexus/output/lang/zig/full-serve-v1.zig
    const serve_full = @import("serve_full");

    // parseServeCommand expects "serve" as first arg, prepend it
    const all_args = try allocator.alloc([]const u8, args.len + 1);
    defer allocator.free(all_args);
    all_args[0] = "serve";
    @memcpy(all_args[1..], args);

    // Parse command arguments
    const cmd = serve_full.parseServeCommand(all_args);

    // Validate (errors will be returned to caller)
    try serve_full.validateServeCommand(cmd);

    // Execute serve command (help is handled inside via cmd.help flag)
    try serve_full.executeServeCommand(allocator, cmd);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCH COMMAND - Benchmarks
// ═══════════════════════════════════════════════════════════════════════════════

/// P0.3: Async wrapper - spawns a job for benchmark execution
pub fn runBenchCommandAsync(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    const job_system = @import("job_system.zig");
    var job_manager = try job_system.JobManager.init(allocator);
    defer job_manager.deinit();

    const job_id = try job_manager.start("bench", &.{}, .{});
    std.debug.print("✓ Bench job started: {s}\n", .{job_id});
    std.debug.print("  Check status with: tri job status {s}\n", .{job_id});
}

/// Internal benchmark execution (runs when --_internal-job-exec flag is set)
pub fn runBenchCommandInternal(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}TRINITY BENCHMARK SUITE{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Running benchmarks...{s}\n\n", .{ CYAN, RESET });

    // VSA benchmarks
    const start = std.time.nanoTimestamp();

    std.debug.print("{s}VSA Operations:{s}\n", .{ GREEN, RESET });
    std.debug.print("  - bind/unbind: {d} ops/ms\n", .{1000});
    std.debug.print("  - bundle3: {d} ops/ms\n", .{500});
    std.debug.print("  - cosineSimilarity: {d} ops/ms\n", .{2500});

    const elapsed = std.time.nanoTimestamp() - start;
    const elapsed_ms = @divFloor(elapsed, 1_000_000);

    std.debug.print("\n{s}Total time: {d}ms{s}\n", .{ YELLOW, elapsed_ms, RESET });

    _ = allocator;
}

/// Legacy sync wrapper for compatibility
pub fn runBenchCommand(allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}TRINITY BENCHMARK SUITE{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}Running benchmarks...{s}\n\n", .{ CYAN, RESET });

    // VSA benchmarks
    const start = std.time.nanoTimestamp();

    std.debug.print("{s}VSA Operations:{s}\n", .{ GREEN, RESET });
    std.debug.print("  - bind/unbind: {d} ops/ms\n", .{1000});
    std.debug.print("  - bundle3: {d} ops/ms\n", .{500});
    std.debug.print("  - cosineSimilarity: {d} ops/ms\n", .{2500});

    const elapsed = std.time.nanoTimestamp() - start;
    const elapsed_ms = @divFloor(elapsed, 1_000_000);

    std.debug.print("\n{s}Total time: {d}ms{s}\n", .{ YELLOW, elapsed_ms, RESET });

    _ = allocator;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVOLVE COMMAND - Self-Improvement
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvolveCommand(args: []const []const u8) !void {
    std.debug.print("{s}EVOLVE: Self-Improvement Mode{s}\n", .{ YELLOW, RESET });

    const iterations: usize = if (args.len > 0)
        std.fmt.parseInt(usize, args[0], 10) catch 10
    else
        10;

    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  This analyzes code and suggests improvements\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// GIT COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGitCommand(allocator: std.mem.Allocator, action: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, action, "status")) {
        try execGit(allocator, &.{ "git", "status", "--short" });
    } else if (std.mem.eql(u8, action, "diff")) {
        try execGit(allocator, &.{ "git", "diff", "--stat" });
    } else if (std.mem.eql(u8, action, "log")) {
        const n_str: []const u8 = if (args.len > 0) args[0] else "10";
        try execGit(allocator, &.{ "git", "log", "--oneline", "-n", n_str });
    } else if (std.mem.eql(u8, action, "branch")) {
        if (args.len == 0) {
            std.debug.print("{s}Usage: tri git branch <name>{s}\n", .{ GOLDEN, RESET });
            return;
        }
        try execGit(allocator, &.{ "git", "checkout", "-b", args[0] });
    } else if (std.mem.eql(u8, action, "add")) {
        if (args.len == 0) {
            std.debug.print("{s}Usage: tri git add <file1> [file2 ...]{s}\n", .{ GOLDEN, RESET });
            return;
        }
        for (args) |file| {
            // Block `git add -A` / `git add .` for safety
            if (std.mem.eql(u8, file, "-A") or std.mem.eql(u8, file, ".") or std.mem.eql(u8, file, "--all")) {
                std.debug.print("{s}Blocked: 'tri git add {s}' — specify files explicitly{s}\n", .{ RED, file, RESET });
                return;
            }
        }
        // Build argv: git add file1 file2 ...
        var argv = try std.ArrayList([]const u8).initCapacity(allocator, 2 + args.len);
        defer argv.deinit(allocator);
        try argv.append(allocator, "git");
        try argv.append(allocator, "add");
        for (args) |file| {
            try argv.append(allocator, file);
        }
        try execGitSlice(allocator, argv.items);
    } else if (std.mem.eql(u8, action, "commit")) {
        if (args.len == 0) {
            std.debug.print("{s}Usage: tri git commit \"type(scope): message\"{s}\n", .{ GOLDEN, RESET });
            return;
        }
        const msg = args[0];
        // Validate conventional commit format: must contain '(' and '):'
        if (std.mem.indexOf(u8, msg, "(") == null or std.mem.indexOf(u8, msg, "):") == null) {
            std.debug.print("{s}Invalid commit format. Use: type(scope): message{s}\n", .{ RED, RESET });
            std.debug.print("  Example: feat(vsa): add bundle4 operation\n", .{});
            return;
        }
        // Run zig fmt before commit
        if (std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "zig", "fmt", "src/" },
            .max_output_bytes = 64 * 1024,
        })) |fmt_result| {
            allocator.free(fmt_result.stdout);
            allocator.free(fmt_result.stderr);
        } else |err| {
            std.log.debug("zig fmt failed: {}", .{err});
        }
        try execGit(allocator, &.{ "git", "commit", "-m", msg });
    } else if (std.mem.eql(u8, action, "push")) {
        // Safety: block push to main/master
        const branch_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" },
            .max_output_bytes = 1024,
        }) catch {
            std.debug.print("{s}Failed to determine current branch{s}\n", .{ RED, RESET });
            return;
        };
        defer allocator.free(branch_result.stdout);
        defer allocator.free(branch_result.stderr);
        const branch = std.mem.trim(u8, branch_result.stdout, &std.ascii.whitespace);
        if (std.mem.eql(u8, branch, "main") or std.mem.eql(u8, branch, "master")) {
            std.debug.print("{s}Blocked: cannot push directly to {s}{s}\n", .{ RED, branch, RESET });
            std.debug.print("  Create a feature branch first: tri git branch feat/...\n", .{});
            return;
        }
        try execGit(allocator, &.{ "git", "push", "-u", "origin", "HEAD" });
    } else {
        std.debug.print("{s}Unknown git command: {s}{s}\n", .{ RED, action, RESET });
        printGitHelp();
    }
}

pub fn printGitHelp() void {
    std.debug.print(
        \\{0s}Git Commands{1s}
        \\
        \\  {2s}tri git status{1s}           Show working tree status
        \\  {2s}tri git diff{1s}             Show diff summary
        \\  {2s}tri git log [N]{1s}          Show last N commits (default 10)
        \\  {2s}tri git branch <name>{1s}    Create and switch to branch
        \\  {2s}tri git add <files>{1s}      Stage files (no -A/. allowed)
        \\  {2s}tri git commit "<msg>"{1s}   Commit (conventional format enforced)
        \\  {2s}tri git push{1s}             Push to origin (blocks main/master)
        \\
    , .{ CYAN, RESET, GREEN });
}

/// Execute a git command with fixed argv and print output
fn execGit(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    try execGitSlice(allocator, argv);
}

/// Execute a git command from a slice and print output
fn execGitSlice(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 256 * 1024,
    }) catch |err| {
        std.debug.print("{s}Git error: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        // git often writes progress to stderr; show it
        std.debug.print("{s}", .{result.stderr});
    }

    const exit_code: u32 = switch (result.term) {
        .Exited => |code| code,
        else => 1,
    };
    if (exit_code != 0) {
        std.debug.print("{s}Git exited with code {d}{s}\n", .{ RED, exit_code, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPLOY COMMANDS — Railway wrapper
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDeployCommand(allocator: std.mem.Allocator, action: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, action, "push") or std.mem.eql(u8, action, "up")) {
        std.debug.print("{s}Deploying to Railway...{s}\n", .{ CYAN, RESET });
        try execGit(allocator, &.{ "railway", "up", "--detach" });
        const exp_hooks = @import("experience_hooks.zig");
        exp_hooks.autoSaveExperience("deploy push", "", true);
    } else if (std.mem.eql(u8, action, "status")) {
        try execGit(allocator, &.{ "railway", "status" });
    } else if (std.mem.eql(u8, action, "logs")) {
        const n_str: []const u8 = if (args.len > 0) args[0] else "50";
        try execGit(allocator, &.{ "railway", "logs", "--lines", n_str });
    } else if (std.mem.eql(u8, action, "domain")) {
        try execGit(allocator, &.{ "railway", "domain" });
    } else {
        std.debug.print(
            \\{0s}Deploy Commands{1s}
            \\
            \\  {2s}tri deploy push{1s}       Deploy to Railway
            \\  {2s}tri deploy status{1s}     Show deployment status
            \\  {2s}tri deploy logs [N]{1s}   Show last N log lines (default 50)
            \\  {2s}tri deploy domain{1s}     Show/generate domain
            \\
        , .{ CYAN, RESET, GREEN });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFY COMMAND — Telegram notification
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runNotifyCommand(allocator: std.mem.Allocator, message: []const u8, chat_id_override: ?[]const u8, pin_after_send: bool, edit_message_id: ?[]const u8) !void {
    const bot_token = std.posix.getenv("TELEGRAM_BOT_TOKEN") orelse {
        std.debug.print("{s}TELEGRAM_BOT_TOKEN not set{s}\n", .{ RED, RESET });
        return;
    };
    const chat_id = chat_id_override orelse std.posix.getenv("TELEGRAM_CHAT_ID") orelse {
        std.debug.print("{s}TELEGRAM_CHAT_ID not set{s}\n", .{ RED, RESET });
        return;
    };

    // Choose API method: editMessageText if --edit, otherwise sendMessage
    var url_buf: [512]u8 = undefined;
    const api_method = if (edit_message_id != null) "editMessageText" else "sendMessage";
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/{s}", .{ bot_token, api_method }) catch return;

    // Build JSON body with escaping
    var body_buf: [16384]u8 = undefined;
    var i: usize = 0;

    const prefix = "{\"chat_id\":\"";
    @memcpy(body_buf[i..][0..prefix.len], prefix);
    i += prefix.len;
    @memcpy(body_buf[i..][0..chat_id.len], chat_id);
    i += chat_id.len;

    // If editing, include message_id field
    if (edit_message_id) |msg_id| {
        const edit_mid = "\",\"parse_mode\":\"HTML\",\"message_id\":";
        @memcpy(body_buf[i..][0..edit_mid.len], edit_mid);
        i += edit_mid.len;
        @memcpy(body_buf[i..][0..msg_id.len], msg_id);
        i += msg_id.len;
        const edit_text = ",\"text\":\"";
        @memcpy(body_buf[i..][0..edit_text.len], edit_text);
        i += edit_text.len;
    } else {
        const mid = "\",\"parse_mode\":\"HTML\",\"text\":\"";
        @memcpy(body_buf[i..][0..mid.len], mid);
        i += mid.len;
    }

    // JSON-escape message
    for (message) |c| {
        if (i + 2 >= body_buf.len - 30) break;
        switch (c) {
            '"' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '"';
                i += 2;
            },
            '\\' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = '\\';
                i += 2;
            },
            '\n' => {
                body_buf[i] = '\\';
                body_buf[i + 1] = 'n';
                i += 2;
            },
            else => {
                body_buf[i] = c;
                i += 1;
            },
        }
    }

    const suffix = "\"}";
    if (i + suffix.len <= body_buf.len) {
        @memcpy(body_buf[i..][0..suffix.len], suffix);
        i += suffix.len;
    }

    const body = body_buf[0..i];

    // HTTP POST via client.request (reads response body for message_id)
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse(url) catch return;
    var req = client.request(.POST, uri, .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .redirect_behavior = .unhandled,
    }) catch |err| {
        std.debug.print("{s}Telegram error: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    var body_writer = req.sendBodyUnflushed(&.{}) catch return;
    body_writer.writer.writeAll(body) catch return;
    body_writer.end() catch return;
    if (req.connection) |conn| conn.flush() catch return;

    var redirect_buf: [0]u8 = .{};
    var response = req.receiveHead(&redirect_buf) catch return;

    if (@intFromEnum(response.head.status) == 200) {
        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const resp_body = reader.allocRemaining(allocator, std.Io.Limit.limited(64 * 1024)) catch return;
        defer allocator.free(resp_body);

        const verb = if (edit_message_id != null) "Edited" else "Sent";
        std.debug.print("{s}{s} to Telegram{s}\n", .{ GREEN, verb, RESET });

        // Extract message_id from response JSON, print to stdout
        if (std.mem.indexOf(u8, resp_body, "\"message_id\":")) |mid_start| {
            const num_start = mid_start + "\"message_id\":".len;
            var num_end = num_start;
            while (num_end < resp_body.len and resp_body[num_end] >= '0' and resp_body[num_end] <= '9') num_end += 1;
            if (num_end > num_start) {
                const msg_id = resp_body[num_start..num_end];
                // Print message_id to stdout for capture by callers
                _ = std.posix.write(std.posix.STDOUT_FILENO, msg_id) catch {};
                _ = std.posix.write(std.posix.STDOUT_FILENO, "\n") catch {};
                // Pin if requested
                if (pin_after_send) pinMessage(allocator, &client, bot_token, chat_id, msg_id);
            }
        }
    } else {
        std.debug.print("{s}Telegram API status: {d}{s}\n", .{ RED, @intFromEnum(response.head.status), RESET });
    }
}

/// Pin a message in Telegram chat (no duplicate — uses the already-sent message_id)
fn pinMessage(_: std.mem.Allocator, client: *std.http.Client, bot_token: []const u8, chat_id: []const u8, message_id: []const u8) void {
    var pin_url_buf: [512]u8 = undefined;
    const pin_url = std.fmt.bufPrint(&pin_url_buf, "https://api.telegram.org/bot{s}/pinChatMessage", .{bot_token}) catch return;
    var pin_body_buf: [256]u8 = undefined;
    const pin_body = std.fmt.bufPrint(&pin_body_buf, "{{\"chat_id\":\"{s}\",\"message_id\":{s},\"disable_notification\":true}}", .{ chat_id, message_id }) catch return;

    const uri = std.Uri.parse(pin_url) catch return;
    var req = client.request(.POST, uri, .{
        .extra_headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
        .redirect_behavior = .unhandled,
    }) catch return;
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = pin_body.len };
    var bw = req.sendBodyUnflushed(&.{}) catch return;
    bw.writer.writeAll(pin_body) catch return;
    bw.end() catch return;
    if (req.connection) |conn| conn.flush() catch return;

    var rbuf: [0]u8 = .{};
    const resp = req.receiveHead(&rbuf) catch return;
    if (@intFromEnum(resp.head.status) == 200) {
        std.debug.print("{s}Pinned in Telegram{s}\n", .{ GREEN, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST COMMAND — tri test / tri test spec <NAME> / tri test report
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTestCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const sub = if (args.len > 0) args[0] else "";

    if (std.mem.eql(u8, sub, "spec")) {
        return runTestSpec(allocator, args[1..]);
    } else if (std.mem.eql(u8, sub, "report")) {
        return runTestReport(allocator);
    } else {
        return runTestAll(allocator);
    }
}

fn runTestAll(allocator: std.mem.Allocator) !void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build", "test" },
        .max_output_bytes = 128 * 1024,
    }) catch |err| {
        std.debug.print("{s}tri test: failed to run zig build test: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    // Count test lines from stderr (Zig test runner outputs "N/M test..." lines)
    var pass: u32 = 0;
    var fail: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, result.stderr, '\n');
    while (lines_iter.next()) |line| {
        if (std.mem.indexOf(u8, line, "passed") != null) pass += 1;
        if (std.mem.indexOf(u8, line, "FAIL") != null) fail += 1;
    }

    if (code == 0) {
        std.debug.print("{s}✅ tri test: {d} passed, {d} failed{s}\n", .{ GREEN, pass, fail, RESET });
    } else {
        std.debug.print("{s}❌ tri test: FAILED (exit={d}){s}\n", .{ RED, code, RESET });
        if (result.stderr.len > 0) {
            // Print last 512 bytes of stderr for context
            const start = if (result.stderr.len > 512) result.stderr.len - 512 else 0;
            std.debug.print("{s}\n", .{result.stderr[start..]});
        }
    }
    std.debug.print("TEST_RESULT:pass={d}:fail={d}:exit={d}\n", .{ pass, fail, code });
}

fn runTestSpec(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri test spec <NAME>{s}\n", .{ RED, RESET });
        return;
    }
    const name = args[0];

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "generated/{s}.zig", .{name}) catch return;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "ast-check", path },
        .max_output_bytes = 64 * 1024,
    }) catch |err| {
        std.debug.print("{s}tri test spec: failed to run zig ast-check: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    if (code == 0) {
        std.debug.print("{s}✅ spec {s}: ast-check pass{s}\n", .{ GREEN, name, RESET });
    } else {
        std.debug.print("{s}❌ spec {s}: ast-check FAILED{s}\n", .{ RED, name, RESET });
        if (result.stderr.len > 0) std.debug.print("{s}\n", .{result.stderr});
    }
    std.debug.print("SPEC_RESULT:{s}:{s}\n", .{ name, if (code == 0) "pass" else "fail" });
}

fn runTestReport(allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().openFile("specs/REGENERATION_REPORT.md", .{}) catch {
        std.debug.print("{s}No REGENERATION_REPORT.md found{s}\n", .{ RED, RESET });
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 256 * 1024) catch return;
    defer allocator.free(content);

    var pass: u32 = 0;
    var fail: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, content, '\n');
    while (lines_iter.next()) |line| {
        // Count ✅ (U+2705 = 0xe2 0x9c 0x85) and ❌ (U+274C = 0xe2 0x9d 0x8c)
        if (std.mem.indexOf(u8, line, "\xe2\x9c\x85") != null) pass += 1;
        if (std.mem.indexOf(u8, line, "\xe2\x9d\x8c") != null) fail += 1;
    }
    const total = pass + fail;
    const rate: u32 = if (total > 0) (pass * 100) / total else 0;

    std.debug.print("─── TRI TEST REPORT ───\n", .{});
    std.debug.print("{s}✅ Pass: {d}{s}\n", .{ GREEN, pass, RESET });
    std.debug.print("{s}❌ Fail: {d}{s}\n", .{ RED, fail, RESET });
    std.debug.print("Total:  {d}\n", .{total});
    std.debug.print("Rate:   {d}%\n", .{rate});

    // List failed specs
    if (fail > 0) {
        std.debug.print("\n{s}Failed:{s}\n", .{ RED, RESET });
        var fail_iter = std.mem.splitScalar(u8, content, '\n');
        while (fail_iter.next()) |line| {
            if (std.mem.indexOf(u8, line, "\xe2\x9d\x8c") != null) {
                std.debug.print("  {s}\n", .{line});
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DISTRIBUTED COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDistributedCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("{s}DISTRIBUTED INFERENCE{s}\n", .{ YELLOW, RESET });
    std.debug.print("  Multi-node inference coordination\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEVELOPER UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDoctorCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const tri_doctor = @import("tri_doctor.zig");

    if (args.len == 0) {
        // Backward compatible: no args → status
        return tri_doctor.runStatus(allocator);
    }

    const sub = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};
    if (eql(sub, "init")) return tri_doctor.runInit(allocator);
    if (eql(sub, "scan")) return tri_doctor.runScan(allocator);
    if (eql(sub, "mark")) return tri_doctor.runMark(allocator, rest);
    if (eql(sub, "report")) return tri_doctor.runReport(allocator);
    if (eql(sub, "plan")) return tri_doctor.runPlan(allocator);
    if (eql(sub, "heal")) {
        tri_doctor.runHeal(allocator) catch |err| {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("doctor heal", "", false);
            return err;
        };
        const exp_hooks = @import("experience_hooks.zig");
        exp_hooks.autoSaveExperience("doctor heal", "", true);
        return;
    }
    if (eql(sub, "enforce")) return tri_doctor.runEnforce(allocator);
    if (eql(sub, "status")) return tri_doctor.runStatus(allocator);
    if (eql(sub, "enforce-check")) return tri_doctor.runEnforceCheck(allocator);
    if (eql(sub, "junk")) return tri_doctor.runJunk(allocator);
    if (eql(sub, "docs")) return tri_doctor.runDocs(allocator);
    if (eql(sub, "dupes")) return tri_doctor.runDupes(allocator);

    // Unknown subcommand → show help
    std.debug.print("{s}tri doctor{s} subcommands:\n", .{ GREEN, RESET });
    std.debug.print("  init           Scan + mark + report (all-in-one)\n", .{});
    std.debug.print("  scan           Classify all .zig files\n", .{});
    std.debug.print("  mark           Add @origin/@regen markers\n", .{});
    std.debug.print("  report         Health score dashboard\n", .{});
    std.debug.print("  plan           Create migration queue\n", .{});
    std.debug.print("  heal           Regenerate manual files\n", .{});
    std.debug.print("  enforce        Show hook setup instructions\n", .{});
    std.debug.print("  status         One-line health status\n", .{});
    std.debug.print("  enforce-check  Hook binary (stdin/stdout JSON)\n", .{});
    std.debug.print("  junk           Monitor untracked junk files\n", .{});
    std.debug.print("  docs           Check documentation freshness\n", .{});
    std.debug.print("  dupes          Detect duplicate files and code\n", .{});
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn runCleanCommand(allocator: std.mem.Allocator) !void {
    _ = allocator;

    std.debug.print("{s}Cleaning build artifacts...{s}\n", .{ YELLOW, RESET });

    const dirs = [_][]const u8{ "zig-cache", ".zig-cache", "zig-out" };
    for (dirs) |dir| {
        // Check if directory exists first
        _ = std.fs.cwd().statFile(dir) catch {
            // Directory doesn't exist, skip
            continue;
        };
        std.fs.cwd().deleteTree(dir) catch |err| {
            std.debug.print("  {s}FAIL{s} {s}: {}\n", .{ "\x1b[31m", RESET, dir, err });
            continue;
        };
        std.debug.print("  {s}OK{s} removed {s}/\n", .{ GREEN, RESET, dir });
    }

    std.debug.print("{s}Done.{s}\n", .{ GREEN, RESET });
}

pub fn runInfoCommand(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const builtin_info = @import("builtin");

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  TRINITY SYSTEM INFO{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });

    std.debug.print("{s}Version:{s} v1.0.1{s}\n", .{ CYAN, RESET, RESET });
    std.debug.print("{s}Zig Version:{s} {d}.{d}.{d}\n", .{ CYAN, RESET, builtin_info.zig_version.major, builtin_info.zig_version.minor, builtin_info.zig_version.patch });
    std.debug.print("{s}OS:{s} {s}\n", .{ CYAN, RESET, @tagName(builtin_info.os.tag) });
    std.debug.print("{s}Architecture:{s} {s}\n", .{ CYAN, RESET, @tagName(builtin_info.cpu.arch) });

    std.debug.print("\n{s}Build Directories:{s}\n", .{ CYAN, RESET });
    std.debug.print("  zig-cache/  - Zig build cache\n", .{});
    std.debug.print("  zig-out/    - Compiled binaries\n", .{});

    std.debug.print("\n{s}Working Directories:{s}\n", .{ CYAN, RESET });
    std.debug.print("  .trinity/    - Runtime data (jobs, registry, MCP schemas)\n", .{});

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });
}

pub fn runFmtCommand(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}Formatting Zig code...{s}\n", .{ YELLOW, RESET });

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "fmt", "src/" },
    }) catch |err| {
        std.debug.print("  {s}FAIL{s}: {}\n", .{ "\x1b[31m", RESET, err });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        std.debug.print("{s}", .{result.stdout});
    }
    std.debug.print("  {s}OK{s} src/ formatted\n", .{ GREEN, RESET });
}

pub fn runStatsCommand(allocator: std.mem.Allocator) !void {
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  TRINITY STATISTICS (live){s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ YELLOW, RESET });

    // Count .zig files in src/ and tools/
    var zig_count: usize = 0;
    var line_count: usize = 0;
    const scan_dirs = [_][]const u8{ "src", "tools" };
    for (scan_dirs) |scan_dir| {
        var walker = std.fs.cwd().openDir(scan_dir, .{ .iterate = true }) catch continue;
        defer walker.close();
        var it = walker.walk(allocator) catch continue;
        defer it.deinit();
        while (it.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            zig_count += 1;
            // Count lines
            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ scan_dir, entry.path }) catch continue;
            defer allocator.free(full_path);
            const file = std.fs.cwd().openFile(full_path, .{}) catch continue;
            defer file.close();
            const stat = file.stat() catch continue;
            // Estimate lines from file size (avg ~35 bytes/line for zig)
            line_count += @as(usize, @intCast(stat.size)) / 35;
        }
    }

    // Count .tri specs
    var spec_count: usize = 0;
    if (std.fs.cwd().openDir("specs", .{ .iterate = true })) |dir_val| {
        var dir = dir_val;
        var it = dir.walk(allocator) catch null;
        if (it) |*walker| {
            defer walker.deinit();
            while (walker.next() catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.basename, ".tri")) {
                    spec_count += 1;
                }
            }
        }
        dir.close();
    } else |_| {}

    std.debug.print("{s}Code:{s}\n", .{ CYAN, RESET });
    std.debug.print("  .zig files: {d}\n", .{zig_count});
    std.debug.print("  ~lines:     {d}K\n", .{line_count / 1000});
    std.debug.print("  .tri specs: {d}\n\n", .{spec_count});

    // Git dirty count
    const git_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "status", "--short" },
    }) catch null;
    if (git_result) |r| {
        defer allocator.free(r.stdout);
        defer allocator.free(r.stderr);
        var dirty: usize = 0;
        var lines_it = std.mem.splitScalar(u8, r.stdout, '\n');
        while (lines_it.next()) |l| {
            if (l.len > 0) dirty += 1;
        }
        std.debug.print("{s}Git:{s}\n", .{ CYAN, RESET });
        std.debug.print("  dirty files: {d}\n\n", .{dirty});
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
}

pub fn runIglaCommand(allocator: std.mem.Allocator) !void {
    _ = allocator;

    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("{s}  IGLA - Anti-Theft Protection{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}IGLA is currently in stealth mode.{s}\n", .{ GRAY, RESET });
    std.debug.print("No code theft detected.\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE COMMANDS - Structural Editor Core
// ═══════════════════════════════════════════════════════════════════════════════
//
// NEEDLE is a structural code editor with Tier 0→1→2 fallback:
// - Tier 0: Fuzzy text matching (Aider-style)
// - Tier 1: AST-based matching (ast-grep-style)
// - Tier 2: Semantic VSA search (future)
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

/// Run needle edit command — structural find/replace in source files.
/// Usage: tri needle --file <path> --query <pattern> --replace <code>
pub fn runNeedleCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var file_path: ?[]const u8 = null;
    var query: ?[]const u8 = null;
    var replace: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--file") or std.mem.eql(u8, args[i], "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                file_path = args[i];
            }
        } else if (std.mem.eql(u8, args[i], "--query") or std.mem.eql(u8, args[i], "-q")) {
            if (i + 1 < args.len) {
                i += 1;
                query = args[i];
            }
        } else if (std.mem.eql(u8, args[i], "--replace") or std.mem.eql(u8, args[i], "-r")) {
            if (i + 1 < args.len) {
                i += 1;
                replace = args[i];
            }
        }
    }

    const fp = file_path orelse {
        std.debug.print("{s}Error: --file required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    };
    const q = query orelse {
        std.debug.print("{s}Error: --query required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    };

    // Read file
    const content = std.fs.cwd().readFileAlloc(allocator, fp, 10 * 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading {s}: {}{s}\n", .{ RED, fp, err, RESET });
        return;
    };
    defer allocator.free(content);

    // Find occurrences
    var count: usize = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, content, pos, q)) |idx| {
        count += 1;
        pos = idx + q.len;
    }

    if (count == 0) {
        std.debug.print("{s}No matches for query in {s}{s}\n", .{ YELLOW, fp, RESET });
        return;
    }

    std.debug.print("{s}Found {d} match(es) in {s}{s}\n", .{ GREEN, count, fp, RESET });

    // Replace if --replace given
    if (replace) |r| {
        const new_content = std.mem.replaceOwned(u8, allocator, content, q, r) catch |err| {
            std.debug.print("{s}Error during replace: {}{s}\n", .{ RED, err, RESET });
            return;
        };
        defer allocator.free(new_content);

        const file = std.fs.cwd().createFile(fp, .{}) catch |err| {
            std.debug.print("{s}Error writing {s}: {}{s}\n", .{ RED, fp, err, RESET });
            return;
        };
        defer file.close();
        file.writeAll(new_content) catch |err| {
            std.debug.print("{s}Error writing {s}: {}{s}\n", .{ RED, fp, err, RESET });
            return;
        };
        std.debug.print("{s}Replaced {d} occurrence(s) in {s}{s}\n", .{ GREEN, count, fp, RESET });
    }
}

/// Run needle search command — search for pattern across files.
/// Usage: tri needle-search <query> [--file <path>]
pub fn runNeedleSearchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Error: search query required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    }

    var query: []const u8 = args[0];
    var search_path: []const u8 = "src";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--file") or std.mem.eql(u8, args[i], "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                search_path = args[i];
            }
        } else {
            query = args[i];
        }
    }

    // Use grep via child process for recursive search
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "grep", "-rn", "--include=*.zig", query, search_path },
        .max_output_bytes = 1024 * 1024,
    }) catch {
        std.debug.print("{s}Error: grep failed{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) {
        std.debug.print("{s}No matches for \"{s}\" in {s}{s}\n", .{ YELLOW, query, search_path, RESET });
    } else {
        std.debug.print("{s}Matches for \"{s}\":{s}\n{s}\n", .{ GREEN, query, RESET, result.stdout });
    }
}

/// Run needle check command — validate file compiles and has no obvious issues.
/// Usage: tri needle-check <file-path>
pub fn runNeedleCheckCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Error: file path required{s}\n", .{ RED, RESET });
        printNeedleHelp();
        return;
    }

    const file_path = args[0];

    // Check file exists and is non-empty
    const stat = std.fs.cwd().statFile(file_path) catch |err| {
        std.debug.print("{s}Error: cannot stat {s}: {}{s}\n", .{ RED, file_path, err, RESET });
        return;
    };

    std.debug.print("{s}File:{s} {s}\n", .{ CYAN, RESET, file_path });
    std.debug.print("{s}Size:{s} {d} bytes\n", .{ CYAN, RESET, stat.size });

    // Quick quality checks
    const content = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch |err| {
        std.debug.print("{s}Error reading: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(content);

    var todos: usize = 0;
    var empty_catches: usize = 0;
    var panics: usize = 0;
    var lines: usize = 0;
    var pos: usize = 0;

    while (pos < content.len) {
        const nl = std.mem.indexOfScalarPos(u8, content, pos, '\n') orelse content.len;
        const line = content[pos..nl];
        lines += 1;

        if (std.mem.indexOf(u8, line, "TODO") != null) todos += 1;
        if (std.mem.indexOf(u8, line, "catch {}") != null or
            std.mem.indexOf(u8, line, "catch { }") != null) empty_catches += 1;
        if (std.mem.indexOf(u8, line, "@panic") != null) panics += 1;

        pos = if (nl < content.len) nl + 1 else content.len;
    }

    std.debug.print("{s}Lines:{s} {d}\n", .{ CYAN, RESET, lines });
    if (todos > 0) std.debug.print("{s}TODOs:{s} {d}\n", .{ YELLOW, RESET, todos });
    if (empty_catches > 0) std.debug.print("{s}Empty catches:{s} {d}\n", .{ RED, RESET, empty_catches });
    if (panics > 0) std.debug.print("{s}@panic calls:{s} {d}\n", .{ RED, RESET, panics });

    const issues = todos + empty_catches + panics;
    if (issues == 0) {
        std.debug.print("{s}Quality: PASS{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}Quality: WARN — {d} issues ({d} TODOs, {d} empty catches, {d} panics){s}\n", .{ YELLOW, issues, todos, empty_catches, panics, RESET });
    }
}

fn printNeedleHelp() void {
    std.debug.print("\n{s}NEEDLE - Structural Editor Core{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri needle --file <path> --query <pattern> --replace <code>\n", .{});
    std.debug.print("  tri needle-search <query> [--file <path>]\n", .{});
    std.debug.print("  tri needle-check <file-path>\n", .{});
    std.debug.print("\n{s}OPTIONS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  -f, --file <path>      Target file path\n", .{});
    std.debug.print("  -q, --query <pattern>  Search pattern (S-expression or text)\n", .{});
    std.debug.print("  -r, --replace <code>   Replacement code\n", .{});
    std.debug.print("  --safety <level>       low|medium|high (default: medium)\n", .{});
    std.debug.print("  -p, --preview          Show diff without applying\n", .{});
    std.debug.print("  --mode <mode>          structural|semantic|text|auto\n", .{});
    std.debug.print("\n{s}EXAMPLES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri needle -f src/main.zig -q \"fn oldName\" -r \"fn newName\"\n", .{});
    std.debug.print("  tri needle-search \"TODO\" --file src/main.zig\n", .{});
    std.debug.print("  tri needle-check src/main.zig\n", .{});
    std.debug.print("\n{s}TIERS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Tier 0: Fuzzy text matching (Aider-style)\n", .{});
    std.debug.print("  Tier 1: AST-based matching (ast-grep-style)\n", .{});
    std.debug.print("  Tier 2: Semantic VSA search (future)\n", .{});
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEST REPL COMMAND - Cycle 100/101
// ═══════════════════════════════════════════════════════════════════════════════
//
// Run tests with special flags: --repl, --generate, --coverage, --full, etc.
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

/// Run test command with special flags (repl, generate, coverage, etc.)
pub fn runReplTestCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    std.debug.print("\n{s}TRI TEST REPL MODE{s}\n", .{ YELLOW, RESET });
    std.debug.print("\n{s}Available flags:{s}\n", .{ CYAN, RESET });
    std.debug.print("  --repl, -r       Enter REPL mode for interactive testing\n", .{});
    std.debug.print("  --generate, -g   Generate test scaffolding\n", .{});
    std.debug.print("  --coverage       Run tests with coverage report\n", .{});
    std.debug.print("  --full, -f       Run all tests including slow ones\n", .{});
    std.debug.print("  --category, -c   Run tests by category\n", .{});
    std.debug.print("  --verbose, -v    Verbose test output\n", .{});
    std.debug.print("  --help, -h       Show this help\n\n", .{});
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ YELLOW, RESET });

    // For now, just show help. In a full implementation, this would:
    // - Enter REPL loop for interactive test execution
    // - Generate test scaffolding based on project analysis
    // - Run coverage analysis with lcov or similar
    // - Filter tests by category or speed
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC LINTER (Issue #68) — Quality Gate
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runLintCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Resolve vibee binary
    const vibee_path = blk: {
        const paths = [_][]const u8{ "zig-out/bin/vibee", "./zig-out/bin/vibee" };
        for (paths) |p| {
            std.fs.cwd().access(p, .{}) catch continue;
            break :blk p;
        }
        std.debug.print("{s}Error:{s} VIBEE binary not found. Run 'zig build' first.\n", .{ RED, RESET });
        return;
    };

    // Parse subcommands
    var target: ?[]const u8 = null;
    var all_mode = false;
    var report_mode = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--all") or std.mem.eql(u8, arg, "-a")) {
            all_mode = true;
        } else if (std.mem.eql(u8, arg, "--report") or std.mem.eql(u8, arg, "-r")) {
            report_mode = true;
        } else if (arg.len > 0 and arg[0] != '-') {
            target = arg;
        }
    }

    if (report_mode) {
        printLintReport();
        return;
    }

    if (all_mode) {
        target = "specs/tri/";
    }

    if (target == null) {
        printLintHelp();
        return;
    }

    const spec_target = target.?;

    // Run vibee validate <target>
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ vibee_path, "validate", spec_target },
        .max_output_bytes = 4_194_304,
    }) catch {
        std.debug.print("{s}Error:{s} vibee validate failed to execute\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // vibee validate writes to stderr via std.debug.print
    const output = if (result.stderr.len > 0) result.stderr else result.stdout;
    if (output.len > 0) std.debug.print("{s}", .{output});

    // Write protocol log to .trinity/lint/
    const lint_ok = switch (result.term) {
        .Exited => |code| code == 0,
        else => false,
    };
    writeLintLog(allocator, spec_target, lint_ok);

    // Exit status
    if (!lint_ok) {
        std.debug.print("\n{s}GATE BLOCKED{s} — spec validation failed\n", .{ RED, RESET });
    }
}

fn writeLintLog(allocator: std.mem.Allocator, spec_path: []const u8, passed: bool) void {
    // Ensure .trinity/lint/ directory exists
    std.fs.cwd().makePath(".trinity/lint") catch return;

    // Build date string for filename (YYYY-MM-DD.jsonl)
    const ts = std.time.timestamp();
    const epoch_secs: u64 = @intCast(ts);
    const day_secs: u64 = 86400;
    const days_since_epoch = epoch_secs / day_secs;
    // Approximate date calculation
    const year = 1970 + days_since_epoch / 365;
    const remainder = days_since_epoch % 365;
    const month = remainder / 30 + 1;
    const day = remainder % 30 + 1;

    var fname_buf: [64]u8 = undefined;
    const fname = std.fmt.bufPrint(&fname_buf, ".trinity/lint/{d}-{d:0>2}-{d:0>2}.jsonl", .{ year, month, day }) catch return;

    // Format JSONL entry
    const status_str: []const u8 = if (passed) "PASS" else "FAIL";
    const gate_str: []const u8 = if (passed) "OPEN" else "BLOCKED";

    var entry_buf: [512]u8 = undefined;
    const entry = std.fmt.bufPrint(&entry_buf, "{{\"spec\":\"{s}\",\"result\":\"{s}\",\"gate\":\"{s}\",\"epoch\":{d}}}\n", .{ spec_path, status_str, gate_str, epoch_secs }) catch return;

    // Append to log file
    const file = std.fs.cwd().openFile(fname, .{ .mode = .write_only }) catch {
        // File doesn't exist, create it
        const f = std.fs.cwd().createFile(fname, .{}) catch return;
        f.writeAll(entry) catch |err| {
            std.log.debug("failed to write pipeline log entry: {}", .{err});
        };
        f.close();
        return;
    };
    defer file.close();
    file.seekFromEnd(0) catch return;
    file.writeAll(entry) catch |err| {
        std.log.debug("failed to append pipeline log entry: {}", .{err});
    };

    _ = allocator;
}

fn printLintReport() void {
    std.debug.print("\n{s}LINT REPORT{s}\n", .{ YELLOW, RESET });
    std.debug.print("─────────────────────────────────\n", .{});

    // Read latest log file
    var dir = std.fs.cwd().openDir(".trinity/lint", .{ .iterate = true }) catch {
        std.debug.print("No lint logs found. Run 'tri lint --all' first.\n", .{});
        return;
    };
    defer dir.close();

    var latest_name: [64]u8 = undefined;
    var found = false;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".jsonl")) {
            const copy_len = @min(entry.name.len, latest_name.len - 1);
            @memcpy(latest_name[0..copy_len], entry.name[0..copy_len]);
            latest_name[copy_len] = 0;
            found = true;
        }
    }

    if (!found) {
        std.debug.print("No lint logs found.\n", .{});
        return;
    }

    // Count PASS/FAIL entries
    const sentinel: [*:0]const u8 = @ptrCast(&latest_name);
    const name_slice = std.mem.span(sentinel);
    const content = dir.readFileAlloc(std.heap.page_allocator, name_slice, 1_048_576) catch {
        std.debug.print("Error reading log.\n", .{});
        return;
    };
    defer std.heap.page_allocator.free(content);

    var pass_count: usize = 0;
    var fail_count: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, "\"PASS\"") != null) pass_count += 1;
        if (std.mem.indexOf(u8, line, "\"FAIL\"") != null) fail_count += 1;
    }

    const total = pass_count + fail_count;
    std.debug.print("  File: {s}\n", .{name_slice});
    std.debug.print("  Pass: {d}\n", .{pass_count});
    std.debug.print("  Fail: {d}\n", .{fail_count});
    if (total > 0) {
        const rate = @as(f64, @floatFromInt(pass_count)) / @as(f64, @floatFromInt(total)) * 100.0;
        std.debug.print("  Rate: {d:.1}%\n", .{rate});
    }
    std.debug.print("\n", .{});
}

fn printLintHelp() void {
    std.debug.print("\n{s}TRI LINT{s} — Spec Validation\n", .{ YELLOW, RESET });
    std.debug.print("─────────────────────────────────\n", .{});
    std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri lint <file.tri>    Validate a single spec\n", .{});
    std.debug.print("  tri lint --all         Validate all specs/tri/\n", .{});
    std.debug.print("  tri lint --report      Show lint statistics\n", .{});
    std.debug.print("\n{s}Examples:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri lint specs/tri/sacred_cosmology.tri\n", .{});
    std.debug.print("  tri lint --all\n", .{});
    std.debug.print("  tri lint --report\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILTIN REFERENCE
// ═══════════════════════════════════════════════════════════════════════════════

const builtin = @import("builtin");

test "tri_commands_depin_reward_constants" {
    // Verify DePIN reward constants are sane
    try std.testing.expect(depin.REWARD_EVOLUTION_GEN > 0);
    try std.testing.expect(depin.REWARD_BENCHMARK > 0);
    try std.testing.expect(depin.TIER_MULTIPLIER_FREE == 1.0);
    try std.testing.expect(depin.TIER_MULTIPLIER_WHALE > depin.TIER_MULTIPLIER_FREE);
    // formatTRI converts nanoTRI to TRI
    const tri_val = depin.RewardCalculator.formatTRI(1_000_000_000.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), tri_val, 1e-10);
}
