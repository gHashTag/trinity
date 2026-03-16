// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY ARENA — LLM Battle Platform
// ═══════════════════════════════════════════════════════════════════════════════
//
// HTTP server + CLI for LLM vs LLM battles with ELO leaderboard
//
// Usage:
//   arena serve              Start HTTP server on :8080
//   arena battle <prompt>    Run a CLI battle
//   arena leaderboard        Show ELO rankings
//   arena bench <category>   Run all tasks in a category
//   arena tasks              List available tasks
//   arena register <name> <kind> [model]  Register a fighter
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const battle_mod = @import("battle.zig");
const tasks_mod = @import("tasks.zig");
const elo = @import("elo.zig");
const Allocator = std.mem.Allocator;

const print = std.debug.print;
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GOLDEN = "\x1b[38;5;220m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const DIM = "\x1b[2m";

/// Main entry point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Skip binary name
    const cmd_args = if (args.len > 1) args[1..] else args[0..0];

    try runArenaCommand(allocator, cmd_args);
}

/// Entry point for `tri arena` subcommand routing
pub fn runArenaCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printUsage();
        return;
    }

    const subcmd = args[0];
    const sub_args = if (args.len > 1) args[1..] else args[0..0];

    if (std.mem.eql(u8, subcmd, "serve") or std.mem.eql(u8, subcmd, "start")) {
        try serveHttp(allocator);
    } else if (std.mem.eql(u8, subcmd, "battle")) {
        try cliBattle(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "leaderboard") or std.mem.eql(u8, subcmd, "lb")) {
        try cliLeaderboard(allocator);
    } else if (std.mem.eql(u8, subcmd, "bench")) {
        try cliBench(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "tasks")) {
        cliTasks();
    } else if (std.mem.eql(u8, subcmd, "register")) {
        try cliRegister(allocator, sub_args);
    } else {
        print("{s}Unknown arena command: {s}{s}\n", .{ RED, subcmd, RESET });
        printUsage();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI commands
// ─────────────────────────────────────────────────────────────────────────────

fn cliBattle(allocator: Allocator, args: []const []const u8) !void {
    // Parse: arena battle "prompt" [--a fighter_a] [--b fighter_b] [--judge]
    var prompt: ?[]const u8 = null;
    var fighter_a: []const u8 = "trinity-hslm";
    var fighter_b: []const u8 = "echo";
    var auto_judge = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--a") and i + 1 < args.len) {
            i += 1;
            fighter_a = args[i];
        } else if (std.mem.eql(u8, args[i], "--b") and i + 1 < args.len) {
            i += 1;
            fighter_b = args[i];
        } else if (std.mem.eql(u8, args[i], "--judge")) {
            auto_judge = true;
        } else if (std.mem.eql(u8, args[i], "--task") and i + 1 < args.len) {
            i += 1;
            if (tasks_mod.findTask(args[i])) |task| {
                prompt = task.prompt;
            }
        } else if (prompt == null) {
            prompt = args[i];
        }
    }

    if (prompt == null) {
        print("{s}Usage: arena battle <prompt> [--a fighter] [--b fighter] [--judge]{s}\n", .{ RED, RESET });
        return;
    }

    var arena = battle_mod.Arena.init(allocator);

    print("\n{s}{s}\xe2\x9a\x94 ARENA BATTLE{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}Task:{s} {s}\n", .{ CYAN, RESET, prompt.? });
    print("{s}Fighter A:{s} {s}\n", .{ CYAN, RESET, fighter_a });
    print("{s}Fighter B:{s} {s}\n\n", .{ CYAN, RESET, fighter_b });

    const task = types.Task{
        .id = "cli-custom",
        .category = .wild,
        .prompt = prompt.?,
        .difficulty = .medium,
    };

    const result = arena.runBattle(task, fighter_a, fighter_b, auto_judge) catch |err| {
        print("{s}Battle error: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };

    // Display results
    print("{s}--- Response A ({s}) ---{s}\n", .{ GOLDEN, fighter_a, RESET });
    if (result.response_a) |r| {
        print("{s}\n", .{r});
    } else {
        print("{s}(no response){s}\n", .{ DIM, RESET });
    }
    print("{s}Latency: {d}ms{s}\n\n", .{ DIM, result.latency_a_ms, RESET });

    print("{s}--- Response B ({s}) ---{s}\n", .{ GOLDEN, fighter_b, RESET });
    if (result.response_b) |r| {
        print("{s}\n", .{r});
    } else {
        print("{s}(no response){s}\n", .{ DIM, RESET });
    }
    print("{s}Latency: {d}ms{s}\n\n", .{ DIM, result.latency_b_ms, RESET });

    if (result.judge_verdict) |v| {
        print("{s}{s}Judge verdict: {s}{s}\n", .{ BOLD, GREEN, v.toString(), RESET });
        if (result.judge_reasoning) |r| {
            print("{s}Reasoning: {s}{s}\n", .{ DIM, r, RESET });
        }
    }
    print("\n", .{});
}

fn cliLeaderboard(allocator: Allocator) !void {
    var arena = battle_mod.Arena.init(allocator);

    // Register some common fighters for display
    arena.registerFighter("gpt-4o", .openai, "gpt-4o", null);
    arena.registerFighter("claude-sonnet", .anthropic, "claude-sonnet-4-20250514", null);

    // TODO: load persisted ELO from leaderboard.json
    arena.printLeaderboard();
}

fn cliBench(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        print("{s}Usage: arena bench <math|coding|reasoning|all>{s}\n", .{ RED, RESET });
        return;
    }

    var arena = battle_mod.Arena.init(allocator);
    const category_str = args[0];

    print("\n{s}{s}\xf0\x9f\x8f\x86 ARENA BENCHMARK: {s}{s}\n\n", .{ BOLD, GOLDEN, category_str, RESET });

    if (std.mem.eql(u8, category_str, "all")) {
        // Run all categories
        inline for (.{ types.TaskCategory.math, types.TaskCategory.coding, types.TaskCategory.reasoning }) |cat| {
            try runCategoryBench(&arena, cat);
        }
    } else if (types.TaskCategory.fromString(category_str)) |cat| {
        try runCategoryBench(&arena, cat);
    } else {
        print("{s}Unknown category: {s}{s}\n", .{ RED, category_str, RESET });
    }

    print("\n", .{});
    arena.printLeaderboard();
    arena.writeLeaderboard() catch {};
}

fn runCategoryBench(arena: *battle_mod.Arena, category: types.TaskCategory) !void {
    var task_buf: [20]types.Task = undefined;
    const count = tasks_mod.tasksByCategory(category, &task_buf);

    print("{s}\xe2\x96\xb6 Category: {s} ({d} tasks){s}\n", .{ CYAN, category.toString(), count, RESET });

    for (0..count) |i| {
        const task = task_buf[i];
        print("  {s} [{s}] ...", .{ task.id, task.difficulty.toString() });

        const result = arena.runBattle(task, "trinity-hslm", "echo", false) catch |err| {
            print(" {s}ERROR: {s}{s}\n", .{ RED, @errorName(err), RESET });
            continue;
        };

        const status_icon: []const u8 = if (result.status == .complete or result.status == .judged) "\xe2\x9c\x93" else "\xe2\x9c\x97";
        print(" {s} ({d}ms vs {d}ms)\n", .{ status_icon, result.latency_a_ms, result.latency_b_ms });
    }
}

fn cliTasks() void {
    print("\n{s}{s}\xf0\x9f\x93\x8b ARENA TASK CATALOG{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}Total: {d} tasks{s}\n\n", .{ DIM, tasks_mod.BUILTIN_TASKS.len, RESET });

    var last_cat: ?types.TaskCategory = null;
    for (&tasks_mod.BUILTIN_TASKS) |*task| {
        if (last_cat == null or last_cat.? != task.category) {
            print("\n{s}\xe2\x96\xb6 {s}{s}\n", .{ CYAN, task.category.toString(), RESET });
            last_cat = task.category;
        }

        const diff_color: []const u8 = switch (task.difficulty) {
            .easy => GREEN,
            .medium => GOLDEN,
            .hard => RED,
        };

        // Truncate prompt for display
        const max_display = 60;
        const display_prompt = if (task.prompt.len > max_display) task.prompt[0..max_display] else task.prompt;
        const ellipsis: []const u8 = if (task.prompt.len > max_display) "..." else "";

        print("  {s:<12} {s}[{s}]{s} {s}{s}\n", .{
            task.id,
            diff_color,
            task.difficulty.toString(),
            RESET,
            display_prompt,
            ellipsis,
        });
    }
    print("\n", .{});
}

fn cliRegister(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 2) {
        print("{s}Usage: arena register <name> <trinity|openai|anthropic|echo|custom> [model]{s}\n", .{ RED, RESET });
        return;
    }

    const name = args[0];
    const kind_str = args[1];
    const model = if (args.len > 2) args[2] else null;

    const kind = types.FighterKind.fromString(kind_str) orelse {
        print("{s}Unknown fighter kind: {s}{s}\n", .{ RED, kind_str, RESET });
        return;
    };

    print("{s}\xe2\x9c\x93 Registered fighter: {s} ({s}){s}", .{ GREEN, name, kind.toString(), RESET });
    if (model) |m| print(" model={s}", .{m});
    print("\n", .{});
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP server
// ─────────────────────────────────────────────────────────────────────────────

fn serveHttp(allocator: Allocator) !void {
    var arena_state = battle_mod.Arena.init(allocator);

    // Register common fighters
    arena_state.registerFighter("gpt-4o", .openai, "gpt-4o", null);
    arena_state.registerFighter("claude-sonnet", .anthropic, "claude-sonnet-4-20250514", null);

    // Read port from PORT env (Railway) or default 8080
    const port: u16 = blk: {
        const port_str = std.process.getEnvVarOwned(allocator, "PORT") catch break :blk 8080;
        defer allocator.free(port_str);
        break :blk std.fmt.parseInt(u16, port_str, 10) catch 8080;
    };
    const address = std.net.Address.parseIp("0.0.0.0", port) catch unreachable;
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    print("\n{s}{s}\xe2\x9a\x94 TRINITY ARENA SERVER{s}\n", .{ BOLD, GOLDEN, RESET });
    print("{s}   Listening on http://0.0.0.0:{d}{s}\n", .{ DIM, port, RESET });
    print("{s}   Ctrl+C to stop{s}\n\n", .{ DIM, RESET });

    while (true) {
        const conn = server.accept() catch continue;
        handleConnection(allocator, conn, &arena_state) catch |err| {
            print("{s}Connection error: {s}{s}\n", .{ RED, @errorName(err), RESET });
        };
    }
}

fn handleConnection(allocator: Allocator, conn: std.net.Server.Connection, arena_state: *battle_mod.Arena) !void {
    _ = allocator;
    const stream = conn.stream;
    defer stream.close();

    // Read HTTP request
    var req_buf: [8192]u8 = undefined;
    const n = stream.read(&req_buf) catch return;
    const request = req_buf[0..n];

    // OPTIONS preflight
    if (std.mem.startsWith(u8, request, "OPTIONS ")) {
        sendResponse(stream, "200 OK", "text/plain", "") catch return;
        return;
    }

    // Route dispatch
    if (std.mem.startsWith(u8, request, "GET /tasks")) {
        handleTasks(stream) catch return;
    } else if (std.mem.startsWith(u8, request, "GET /leaderboard")) {
        handleLeaderboard(stream, arena_state) catch return;
    } else if (std.mem.startsWith(u8, request, "POST /battle/") and std.mem.indexOf(u8, request, "/vote") != null) {
        handleVote(stream, request) catch return;
    } else if (std.mem.startsWith(u8, request, "POST /battle")) {
        handleCreateBattle(stream, request, arena_state) catch return;
    } else if (std.mem.startsWith(u8, request, "GET /battle/")) {
        handleGetBattle(stream, arena_state) catch return;
    } else if (std.mem.startsWith(u8, request, "GET / ") or std.mem.startsWith(u8, request, "GET /index.html")) {
        serveStaticFile(stream, "web/arena/index.html", "text/html") catch return;
    } else {
        sendResponse(stream, "404 Not Found", "application/json", "{\"error\":\"not found\"}") catch return;
    }
}

fn sendResponse(stream: std.net.Stream, status: []const u8, content_type: []const u8, body: []const u8) !void {
    var header_buf: [512]u8 = undefined;
    const header = std.fmt.bufPrint(
        &header_buf,
        "HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n",
        .{ status, content_type, body.len },
    ) catch return;
    _ = stream.write(header) catch return;
    _ = stream.write(body) catch return;
}

fn handleTasks(stream: std.net.Stream) !void {
    var buf: [16384]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writer.writeAll("{\"categories\":[\"math\",\"coding\",\"reasoning\"],\"tasks\":[");

    var first = true;
    for (&tasks_mod.BUILTIN_TASKS) |*task| {
        if (!first) try writer.writeAll(",");
        first = false;

        const preview_len = @min(task.prompt.len, 80);
        try std.fmt.format(writer,
            \\{{"id":"{s}","category":"{s}","difficulty":"{s}","preview":"{s}"}}
        , .{ task.id, task.category.toString(), task.difficulty.toString(), task.prompt[0..preview_len] });
    }
    try writer.writeAll("]}");

    try sendResponse(stream, "200 OK", "application/json", fbs.getWritten());
}

fn handleLeaderboard(stream: std.net.Stream, arena_state: *battle_mod.Arena) !void {
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writer.writeAll("{\"fighters\":[");

    var first = true;
    for (arena_state.fighters[0..arena_state.fighter_count]) |*f| {
        if (!f.active) continue;
        if (!first) try writer.writeAll(",");
        first = false;

        var elo_buf: [16]u8 = undefined;
        const elo_str = elo.formatElo(f.elo, &elo_buf);

        try std.fmt.format(writer,
            \\{{"name":"{s}","elo":{s},"wins":{d},"losses":{d},"ties":{d}}}
        , .{ f.getName(), elo_str, f.wins, f.losses, f.ties });
    }

    try std.fmt.format(writer,
        \\],"total_battles":{d}}}
    , .{arena_state.total_battles});

    try sendResponse(stream, "200 OK", "application/json", fbs.getWritten());
}

fn handleCreateBattle(stream: std.net.Stream, request: []const u8, arena_state: *battle_mod.Arena) !void {
    // Find body (after \r\n\r\n)
    const body_start = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return;
    const body = request[body_start + 4 ..];

    // Parse simple fields from JSON body
    var prompt: ?[]const u8 = null;
    var fighter_a: []const u8 = "trinity-hslm";
    var fighter_b: []const u8 = "echo";
    var task_id: ?[]const u8 = null;

    if (extractJsonField(body, "\"prompt\":\"")) |p| prompt = p;
    if (extractJsonField(body, "\"fighter_a\":\"")) |a| fighter_a = a;
    if (extractJsonField(body, "\"fighter_b\":\"")) |b| fighter_b = b;
    if (extractJsonField(body, "\"task_id\":\"")) |t| task_id = t;

    // Resolve task
    const task = if (task_id) |tid| tasks_mod.findTask(tid) else null;
    const final_task = task orelse types.Task{
        .id = "api-custom",
        .category = .wild,
        .prompt = prompt orelse "Hello, who are you?",
        .difficulty = .medium,
    };

    const result = arena_state.runBattle(final_task, fighter_a, fighter_b, false) catch {
        try sendResponse(stream, "500 Internal Server Error", "application/json", "{\"error\":\"battle failed\"}");
        return;
    };

    var resp_buf: [512]u8 = undefined;
    const resp = std.fmt.bufPrint(&resp_buf,
        \\{{"battle_id":{d},"status":"{s}","latency_a_ms":{d},"latency_b_ms":{d}}}
    , .{ result.id, result.status.toString(), result.latency_a_ms, result.latency_b_ms }) catch "{\"error\":\"format\"}";

    try sendResponse(stream, "200 OK", "application/json", resp);
}

fn handleVote(stream: std.net.Stream, request: []const u8) !void {
    _ = request;
    // TODO: parse battle_id from path, apply vote
    try sendResponse(stream, "200 OK", "application/json", "{\"status\":\"ok\"}");
}

fn handleGetBattle(stream: std.net.Stream, arena_state: *battle_mod.Arena) !void {
    // Return last battle info
    if (arena_state.total_battles == 0) {
        try sendResponse(stream, "404 Not Found", "application/json", "{\"error\":\"no battles yet\"}");
        return;
    }
    var buf: [512]u8 = undefined;
    const resp = std.fmt.bufPrint(&buf,
        \\{{"total_battles":{d},"fighters":{d},"status":"ok"}}
    , .{ arena_state.total_battles, arena_state.fighter_count }) catch "{\"error\":\"format\"}";
    try sendResponse(stream, "200 OK", "application/json", resp);
}

fn serveStaticFile(stream: std.net.Stream, path: []const u8, content_type: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try sendResponse(stream, "404 Not Found", "application/json", "{\"error\":\"file not found\"}");
        return;
    };
    defer file.close();

    var buf: [65536]u8 = undefined;
    const size = file.readAll(&buf) catch {
        try sendResponse(stream, "500 Internal Server Error", "application/json", "{\"error\":\"read error\"}");
        return;
    };

    try sendResponse(stream, "200 OK", content_type, buf[0..size]);
}

/// Extract a string value from JSON given a field prefix like "\"key\":\""
fn extractJsonField(json: []const u8, prefix: []const u8) ?[]const u8 {
    const start_idx = std.mem.indexOf(u8, json, prefix) orelse return null;
    const content_start = start_idx + prefix.len;
    const end_idx = std.mem.indexOfPos(u8, json, content_start, "\"") orelse return null;
    return json[content_start..end_idx];
}

// ─────────────────────────────────────────────────────────────────────────────
// Usage
// ─────────────────────────────────────────────────────────────────────────────

fn printUsage() void {
    print(
        \\{s}\xe2\x9a\x94 Trinity Arena 2.0 — LLM Battle Platform{s}
        \\
        \\{s}Commands:{s}
        \\  arena serve                Start HTTP server on :8080
        \\  arena battle <prompt>      Run a CLI battle
        \\  arena leaderboard          Show ELO rankings
        \\  arena bench <category>     Run all tasks in category
        \\  arena tasks                List available tasks
        \\  arena register <n> <kind>  Register a fighter
        \\
        \\{s}Battle options:{s}
        \\  --a <fighter>     Fighter A (default: trinity-hslm)
        \\  --b <fighter>     Fighter B (default: echo)
        \\  --judge           Enable LLM auto-judge
        \\  --task <id>       Use preset task by ID
        \\
        \\{s}Fighter kinds:{s} trinity, openai, anthropic, echo, local, custom
        \\
        \\{s}Examples:{s}
        \\  arena battle "What is 2+2?" --a trinity-hslm --b echo
        \\  arena bench math
        \\  arena serve
        \\
    , .{ GOLDEN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET, CYAN, RESET });
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

test "extract json field" {
    const json =
        \\{"prompt":"Hello world","fighter_a":"trinity"}
    ;
    const prompt = extractJsonField(json, "\"prompt\":\"");
    try std.testing.expect(prompt != null);
    try std.testing.expectEqualStrings("Hello world", prompt.?);

    const fighter = extractJsonField(json, "\"fighter_a\":\"");
    try std.testing.expect(fighter != null);
    try std.testing.expectEqualStrings("trinity", fighter.?);
}

test "extract json field missing" {
    const json = "{}";
    try std.testing.expect(extractJsonField(json, "\"missing\":\"") == null);
}
