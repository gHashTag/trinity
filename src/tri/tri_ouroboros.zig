// @origin(spec:ouroboros.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// OUROBOROS — Self-evolving recursive improvement loop
// ═══════════════════════════════════════════════════════════════════════════════
//
// Layer 1: Local mode — DIAGNOSE → PLAN → ACT → VERIFY → MEASURE → PERSIST
// Layer 2: Queen mode — spawns Railway workers per dimension, merges, re-scores
//
// Three Laws:
//   ENDURE — never break build (verify fails → rollback)
//   EXCEL  — each cycle improves score (3 stagnations → change strategy)
//   EVOLVE — accumulate experience (federated sync via git)
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const verdict = @import("toxic_verdict.zig");
const colors = @import("tri_colors.zig");
const experience = @import("experience_hooks.zig");
const cloud = @import("cloud_orchestrator.zig");
const github_client = @import("github_client.zig");

const print = std.debug.print;
const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Mode = enum { local, queen };

pub const Strategy = enum {
    priority_first,
    weakest_first,
    random_walk,

    pub fn next(self: Strategy) Strategy {
        return switch (self) {
            .priority_first => .weakest_first,
            .weakest_first => .random_walk,
            .random_walk => .priority_first,
        };
    }

    pub fn label(self: Strategy) []const u8 {
        return switch (self) {
            .priority_first => "priority_first",
            .weakest_first => "weakest_first",
            .random_walk => "random_walk",
        };
    }
};

pub const OuroborosConfig = struct {
    max_cycles: u32 = 10,
    target_score: f32 = 95.0,
    dry_run: bool = false,
    focus_dimension: ?[]const u8 = null,
    mode: Mode = .local,
    worker_count: u32 = 3,
};

pub const OuroborosState = struct {
    cycle: u32 = 0,
    initial_score: f32 = 0,
    current_score: f32 = 0,
    stagnation_count: u32 = 0,
    strategy: Strategy = .priority_first,
    started_at: i64 = 0,
};

const STATE_PATH = ".trinity/ouroboros_state.json";

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runOuroborosCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var config = OuroborosConfig{};

    if (args.len > 0) {
        // Sub-commands
        if (std.mem.eql(u8, args[0], "status")) {
            showStatus();
            return;
        }
        if (std.mem.eql(u8, args[0], "reset")) {
            resetState();
            return;
        }
        if (std.mem.eql(u8, args[0], "queen")) {
            config.mode = .queen;
        }

        // Parse flags
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--cycles") and i + 1 < args.len) {
                config.max_cycles = std.fmt.parseInt(u32, args[i + 1], 10) catch 10;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--target") and i + 1 < args.len) {
                config.target_score = std.fmt.parseFloat(f32, args[i + 1]) catch 95.0;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--dry-run")) {
                config.dry_run = true;
            } else if (std.mem.eql(u8, args[i], "--dimension") and i + 1 < args.len) {
                config.focus_dimension = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--workers") and i + 1 < args.len) {
                config.worker_count = std.fmt.parseInt(u32, args[i + 1], 10) catch 3;
                i += 1;
            }
        }
    }

    switch (config.mode) {
        .local => try runOuroboros(allocator, config),
        .queen => try runQueen(allocator, config),
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 1: LOCAL OUROBOROS
// ═══════════════════════════════════════════════════════════════════════════════

fn runOuroboros(allocator: std.mem.Allocator, config: OuroborosConfig) !void {
    var state = loadState();
    if (state.started_at == 0) state.started_at = std.time.timestamp();

    const hard_limit = @min(config.max_cycles, 50);

    // Initial diagnosis
    var input = verdict.collectInputs(allocator);
    var score = verdict.computeScore(input);
    if (state.cycle == 0) state.initial_score = score.total;
    state.current_score = score.total;

    saveState(state);
    printHeader(state, config);

    var cycle: u32 = 0;
    while (cycle < hard_limit) {
        cycle += 1;
        state.cycle += 1;

        // DIAGNOSE
        const explanation = verdict.explainScore(score, input);
        const rx = verdict.prescribe(allocator, explanation, score);

        // Hungry snake law: stop only when ALL dimensions >= 95
        var all_strong = true;
        for (explanation.dimensions) |dim| {
            if (dim.weight > 0 and dim.score < 95.0) {
                all_strong = false;
                break;
            }
        }
        if (all_strong) {
            print("\n  {s}💎 LEGENDARY: all 12 dimensions >= 95{s}\n", .{ GREEN, RESET });
            break;
        }
        if (score.total >= config.target_score) {
            const w = explanation.dimensions[explanation.weakest];
            print("  {s}⚡{s} Avg >= target but {s} still at {d:.0} — continuing\n", .{ GOLDEN, RESET, w.name, w.score });
        }
        if (rx.action_count == 0) {
            print("\n  {s}⊘ NO ACTIONS AVAILABLE{s}\n", .{ GRAY, RESET });
            break;
        }

        // PLAN — select action
        const action = selectAction(&rx, state.strategy, config.focus_dimension);
        const dimension = action.dimension;

        if (config.dry_run) {
            print("  {s}[DRY]{s} Cycle {d}/{d}: {s} (P{d}) → \"{s}\"\n", .{
                GOLDEN, RESET, cycle, hard_limit, dimension, action.priority, action.actionStr(),
            });
            continue;
        }

        const score_before = score.total;
        print("\n  {s}⟳{s} Cycle {d}/{d}: {s}{s}{s} (P{d})\n", .{
            CYAN, RESET, cycle, hard_limit, GOLDEN, dimension, RESET, action.priority,
        });

        // ACT
        executeAction(allocator, dimension);

        // VERIFY (ENDURE law)
        if (!runVerifyGate(allocator)) {
            rollback(allocator);
            experience.autoSaveWithMistake("ouroboros", dimension, "verify failed after action");
            print("  {s}✗ Verify FAILED → rollback{s}\n", .{ RED, RESET });
            continue;
        }

        // MEASURE
        input = verdict.collectInputs(allocator);
        score = verdict.computeScore(input);
        state.current_score = score.total;

        // PERSIST
        commitCycle(allocator, state.cycle, dimension);
        experience.autoSaveExperience("ouroboros", dimension, true);

        // EXCEL — stagnation detection
        const delta = score.total - score_before;
        if (delta <= 0.5) {
            state.stagnation_count += 1;
        } else {
            state.stagnation_count = 0;
        }
        if (state.stagnation_count >= 3) {
            state.strategy = state.strategy.next();
            state.stagnation_count = 0;
            print("  {s}↻ Strategy rotation → {s}{s}\n", .{ GOLDEN, state.strategy.label(), RESET });
        }

        saveState(state);

        // Print cycle result
        const arrow: []const u8 = if (delta > 0.5) "↑" else if (delta < -0.5) "↓" else "→";
        const clr: []const u8 = if (delta > 0.5) GREEN else if (delta < -0.5) RED else GRAY;
        const sign: []const u8 = if (delta >= 0) "+" else "";
        print("  {s}✓{s} {d:.1} → {s}{d:.1} ({s}{s}{d:.1}{s}) {s}\n", .{
            GREEN, RESET, score_before, clr, score.total, clr, sign, delta, RESET, arrow,
        });
    }

    printSummary(state, config);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER 2: QUEEN MODE (Distributed)
// ═══════════════════════════════════════════════════════════════════════════════

fn runQueen(allocator: std.mem.Allocator, config: OuroborosConfig) !void {
    var state = loadState();
    if (state.started_at == 0) state.started_at = std.time.timestamp();

    // Initial diagnosis
    const input = verdict.collectInputs(allocator);
    const score = verdict.computeScore(input);
    if (state.cycle == 0) state.initial_score = score.total;
    state.current_score = score.total;

    if (score.total >= config.target_score) {
        print("\n  {s}💎 ALREADY LEGENDARY: {d:.1}/100{s}\n", .{ GOLDEN, score.total, RESET });
        return;
    }

    const explanation = verdict.explainScore(score, input);
    const rx = verdict.prescribe(allocator, explanation, score);

    printQueenHeader(score, config);

    if (rx.action_count == 0) {
        print("  {s}⊘ No weak dimensions to fix{s}\n", .{ GRAY, RESET });
        return;
    }

    // Create dimension-locked issues + spawn workers
    var gh = github_client.GitHubClient.init(allocator, config.dry_run) catch {
        print("  {s}✗ GitHub client init failed — check GITHUB_TOKEN{s}\n", .{ RED, RESET });
        return;
    };

    const to_spawn = @min(rx.action_count, @as(u8, @intCast(config.worker_count)));
    var spawned: u32 = 0;

    for (0..to_spawn) |i| {
        const act = &rx.actions[i];
        const dimension = act.dimension;

        // Build issue title
        var title_buf: [128]u8 = undefined;
        const title = std.fmt.bufPrint(&title_buf, "ouroboros: fix {s} (cycle {d})", .{
            dimension, state.cycle + 1,
        }) catch continue;

        // Build issue body
        var body_buf: [2048]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf,
            \\## Ouroboros Cycle {d} — Fix {s}
            \\
            \\**Current Score**: {d:.0}/100 ({s})
            \\**Prescription**: {s}
            \\**Expected Impact**: +{d:.0} pts
            \\
            \\### Instructions
            \\1. Focus ONLY on {s} dimension
            \\2. Run `tri verdict --explain` before and after
            \\3. Max 100 LOC changes
            \\4. Must pass `zig build` + `zig fmt --check src/`
            \\5. Create PR with title: `fix(ouroboros): {s} cycle {d}`
        , .{
            state.cycle + 1, dimension,
            score.total,     verdict.classifyLevel(score.total).label(),
            act.actionStr(), act.expected_impact,
            dimension,       dimension,
            state.cycle + 1,
        }) catch continue;

        const labels = &[_][]const u8{ "agent:ouroboros", "status:queued" };
        const issue = gh.createIssue(title, body, labels) catch {
            print("  {s}✗ Failed to create issue for {s}{s}\n", .{ RED, dimension, RESET });
            continue;
        };

        if (!config.dry_run) {
            // Spawn Railway worker
            _ = cloud.spawnAgent(allocator, issue.number) catch {
                print("  {s}✗ Failed to spawn worker for #{d}{s}\n", .{ RED, issue.number, RESET });
                continue;
            };
        }

        spawned += 1;
        print("  {s}⚙{s} Worker {d} → {s} (issue #{d})\n", .{
            GREEN, RESET, spawned, dimension, issue.number,
        });
    }

    state.cycle += 1;
    saveState(state);

    print("\n  {s}👑 Queen spawned {d} workers. Monitor via `tri cloud agents`{s}\n", .{
        GOLDEN, spawned, RESET,
    });
    print("  {s}   Re-run `tri ouroboros` after PRs merge to measure progress{s}\n", .{ GRAY, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION DISPATCHER
// ═══════════════════════════════════════════════════════════════════════════════

fn selectAction(rx: *const verdict.VerdictPrescription, strategy: Strategy, focus: ?[]const u8) *const verdict.PrescribedAction {
    // If focused on a specific dimension, find it
    if (focus) |dim| {
        for (0..rx.action_count) |i| {
            if (std.ascii.eqlIgnoreCase(rx.actions[i].dimension, dim)) {
                return &rx.actions[i];
            }
        }
    }

    return switch (strategy) {
        .priority_first => &rx.actions[0], // already sorted by priority
        .weakest_first => blk: {
            // Find lowest-score action
            var lowest: usize = 0;
            for (1..rx.action_count) |i| {
                if (rx.actions[i].expected_impact > rx.actions[lowest].expected_impact) {
                    lowest = i;
                }
            }
            break :blk &rx.actions[lowest];
        },
        .random_walk => blk: {
            // Pseudo-random: use timestamp mod action_count
            const ts: u64 = @intCast(std.time.timestamp());
            const idx = ts % rx.action_count;
            break :blk &rx.actions[idx];
        },
    };
}

fn executeAction(allocator: std.mem.Allocator, dimension: []const u8) void {
    if (std.mem.eql(u8, dimension, "BUILD")) {
        _ = runChild(allocator, &.{ "zig", "fmt", "src/" });
        _ = runChild(allocator, &.{ "zig", "build", "--summary", "none" });
    } else if (std.mem.eql(u8, dimension, "TEST_PASS")) {
        _ = runChild(allocator, &.{ "zig", "build", "test", "--summary", "none" });
    } else if (std.mem.eql(u8, dimension, "TEST_COVER")) {
        // Manual: add test blocks to untested files
        print("    → Add test blocks to untested .zig files\n", .{});
    } else if (std.mem.eql(u8, dimension, "TODO_DEBT")) {
        print("    → Resolve or remove TODO/FIXME markers\n", .{});
    } else if (std.mem.eql(u8, dimension, "GOD_FILES")) {
        print("    → Split files > 1000 LOC\n", .{});
    } else if (std.mem.eql(u8, dimension, "DEAD_CODE")) {
        print("    → Remove stub functions or implement them\n", .{});
    } else if (std.mem.eql(u8, dimension, "DUPLICATION")) {
        print("    → Merge _v2/_v3 duplicates\n", .{});
    } else if (std.mem.eql(u8, dimension, "SPEC_GAP")) {
        _ = runChild(allocator, &.{ "zig", "build", "--summary", "none" });
    } else if (std.mem.eql(u8, dimension, "RESEARCH")) {
        print("    → Run tri scholar scan\n", .{});
    } else if (std.mem.eql(u8, dimension, "TOKEN_COST")) {
        print("    → Optimize token usage\n", .{});
    } else if (std.mem.eql(u8, dimension, "ENERGY")) {
        print("    → Fix failing experience episodes\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFY GATE + ROLLBACK
// ═══════════════════════════════════════════════════════════════════════════════

fn runVerifyGate(allocator: std.mem.Allocator) bool {
    _ = runChild(allocator, &.{ "zig", "fmt", "src/" });
    return runChild(allocator, &.{ "zig", "build", "--summary", "none" }) == 0;
}

fn rollback(allocator: std.mem.Allocator) void {
    _ = runChild(allocator, &.{ "git", "checkout", "--", "." });
}

fn commitCycle(allocator: std.mem.Allocator, cycle: u32, dimension: []const u8) void {
    _ = runChild(allocator, &.{ "git", "add", "-A" });
    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "fix(ouroboros): {s} cycle {d}", .{ dimension, cycle }) catch return;
    // Need to pass as a slice element — build args with buffer
    var args: [4][]const u8 = .{ "git", "commit", "-m", msg };
    _ = runChild(allocator, &args);
}

fn runChild(allocator: std.mem.Allocator, argv: []const []const u8) u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
    }) catch return 1;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    return result.term.Exited;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn loadState() OuroborosState {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return OuroborosState{};
    defer file.close();

    var buf: [1024]u8 = undefined;
    const n = file.readAll(&buf) catch return OuroborosState{};
    const content = buf[0..n];

    return OuroborosState{
        .cycle = parseJsonU32(content, "\"cycle\":") orelse 0,
        .initial_score = parseJsonFloat(content, "\"initial\":") orelse 0,
        .current_score = parseJsonFloat(content, "\"current\":") orelse 0,
        .stagnation_count = parseJsonU32(content, "\"stagnation\":") orelse 0,
        .strategy = parseStrategy(content),
        .started_at = @intCast(parseJsonU32(content, "\"started\":") orelse 0),
    };
}

fn saveState(state: OuroborosState) void {
    // Ensure .trinity/ exists
    std.fs.cwd().makePath(".trinity") catch {};

    const file = std.fs.cwd().createFile(STATE_PATH, .{}) catch return;
    defer file.close();

    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&buf,
        \\{{"cycle":{d},"initial":{d:.1},"current":{d:.1},"stagnation":{d},"strategy":"{s}","started":{d}}}
    , .{
        state.cycle,
        state.initial_score,
        state.current_score,
        state.stagnation_count,
        state.strategy.label(),
        state.started_at,
    }) catch return;
    file.writeAll(json) catch {};
}

fn resetState() void {
    std.fs.cwd().deleteFile(STATE_PATH) catch {};
    print("  {s}⟳ Ouroboros state reset{s}\n", .{ CYAN, RESET });
}

fn showStatus() void {
    const state = loadState();
    if (state.started_at == 0) {
        print("  {s}⊘ No ouroboros state. Run `tri ouroboros` to start.{s}\n", .{ GRAY, RESET });
        return;
    }

    const level = verdict.classifyLevel(state.current_score);
    print("\n  {s}🐍 OUROBOROS STATUS{s}\n", .{ GOLDEN, RESET });
    print("  {s}────────────────────────────{s}\n", .{ GRAY, RESET });
    print("  Cycle:      {d}\n", .{state.cycle});
    print("  Score:      {d:.1} → {s}{d:.1}{s} ({s})\n", .{
        state.initial_score,
        level.color(),
        state.current_score,
        RESET,
        level.label(),
    });
    print("  Strategy:   {s}\n", .{state.strategy.label()});
    print("  Stagnation: {d}/3\n", .{state.stagnation_count});
    print("  {s}────────────────────────────{s}\n\n", .{ GRAY, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON PARSING HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn parseJsonU32(content: []const u8, key: []const u8) ?u32 {
    const idx = std.mem.indexOf(u8, content, key) orelse return null;
    const start = idx + key.len;
    var s = start;
    while (s < content.len and (content[s] == ' ' or content[s] == '\t')) : (s += 1) {}
    var end = s;
    while (end < content.len and content[end] >= '0' and content[end] <= '9') : (end += 1) {}
    if (end == s) return null;
    return std.fmt.parseInt(u32, content[s..end], 10) catch null;
}

fn parseJsonFloat(content: []const u8, key: []const u8) ?f32 {
    const idx = std.mem.indexOf(u8, content, key) orelse return null;
    const start = idx + key.len;
    var s = start;
    while (s < content.len and (content[s] == ' ' or content[s] == '\t')) : (s += 1) {}
    var end = s;
    while (end < content.len and (content[end] >= '0' and content[end] <= '9' or content[end] == '.' or content[end] == '-')) : (end += 1) {}
    if (end == s) return null;
    return std.fmt.parseFloat(f32, content[s..end]) catch null;
}

fn parseStrategy(content: []const u8) Strategy {
    if (std.mem.indexOf(u8, content, "\"weakest_first\"") != null) return .weakest_first;
    if (std.mem.indexOf(u8, content, "\"random_walk\"") != null) return .random_walk;
    return .priority_first;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRETTY-PRINT
// ═══════════════════════════════════════════════════════════════════════════════

fn printHeader(state: OuroborosState, config: OuroborosConfig) void {
    print("\n{s}╭─────── УРОБОРОС ───────╮{s}\n", .{ GOLDEN, RESET });
    print("{s}│{s} Target: {d:.0}  Cycles: {d}/{d}\n", .{
        GOLDEN, RESET, config.target_score, state.cycle, config.max_cycles,
    });
    print("{s}│{s} Score: {d:.1} → ???\n", .{ GOLDEN, RESET, state.current_score });
    if (config.dry_run) print("{s}│{s} {s}[DRY RUN]{s}\n", .{ GOLDEN, RESET, GOLDEN, RESET });
    print("{s}╰────────────────────────╯{s}\n", .{ GOLDEN, RESET });
}

fn printQueenHeader(score: verdict.VerdictScore, config: OuroborosConfig) void {
    print("\n{s}╭─────── 👑 QUEEN MODE ───────╮{s}\n", .{ GOLDEN, RESET });
    print("{s}│{s} Score: {d:.1}/100 ({s})\n", .{
        GOLDEN, RESET, score.total, verdict.classifyLevel(score.total).label(),
    });
    print("{s}│{s} Workers: {d}\n", .{ GOLDEN, RESET, config.worker_count });
    if (config.dry_run) print("{s}│{s} {s}[DRY RUN]{s}\n", .{ GOLDEN, RESET, GOLDEN, RESET });
    print("{s}╰────────────────────────────╯{s}\n\n", .{ GOLDEN, RESET });
}

fn printSummary(state: OuroborosState, config: OuroborosConfig) void {
    _ = config;
    const delta = state.current_score - state.initial_score;
    const level_before = verdict.classifyLevel(state.initial_score);
    const level_after = verdict.classifyLevel(state.current_score);

    print("\n{s}╭─────── ИТОГО ───────╮{s}\n", .{ GOLDEN, RESET });
    const sign: []const u8 = if (delta >= 0) "+" else "";
    print("{s}│{s} {d:.1} → {d:.1} ({s}{s}{d:.1}{s}) in {d} cycles\n", .{
        GOLDEN,                        RESET,
        state.initial_score,           state.current_score,
        if (delta > 0) GREEN else RED, sign,
        delta,                         RESET,
        state.cycle,
    });
    print("{s}│{s} Level: {s} → {s}\n", .{
        GOLDEN, RESET, level_before.label(), level_after.label(),
    });
    print("{s}│{s} 🐍 Уроборос завершён\n", .{ GOLDEN, RESET });
    print("{s}╰─────────────────────╯{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "strategy_rotation" {
    try testing.expect(Strategy.priority_first.next() == .weakest_first);
    try testing.expect(Strategy.weakest_first.next() == .random_walk);
    try testing.expect(Strategy.random_walk.next() == .priority_first);
}

test "config_defaults" {
    const config = OuroborosConfig{};
    try testing.expect(config.max_cycles == 10);
    try testing.expect(config.target_score == 95.0);
    try testing.expect(config.dry_run == false);
    try testing.expect(config.mode == .local);
}

test "state_json_roundtrip" {
    const state = OuroborosState{
        .cycle = 5,
        .initial_score = 42.0,
        .current_score = 67.5,
        .stagnation_count = 1,
        .strategy = .weakest_first,
        .started_at = 1710000000,
    };

    // Serialize
    var buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&buf,
        \\{{"cycle":{d},"initial":{d:.1},"current":{d:.1},"stagnation":{d},"strategy":"{s}","started":{d}}}
    , .{
        state.cycle,
        state.initial_score,
        state.current_score,
        state.stagnation_count,
        state.strategy.label(),
        state.started_at,
    }) catch unreachable;

    // Parse back
    const parsed = OuroborosState{
        .cycle = parseJsonU32(json, "\"cycle\":") orelse 0,
        .initial_score = parseJsonFloat(json, "\"initial\":") orelse 0,
        .current_score = parseJsonFloat(json, "\"current\":") orelse 0,
        .stagnation_count = parseJsonU32(json, "\"stagnation\":") orelse 0,
        .strategy = parseStrategy(json),
        .started_at = @intCast(parseJsonU32(json, "\"started\":") orelse 0),
    };

    try testing.expect(parsed.cycle == 5);
    try testing.expect(parsed.stagnation_count == 1);
    try testing.expect(parsed.strategy == .weakest_first);
    try testing.expect(@abs(parsed.initial_score - 42.0) < 0.1);
    try testing.expect(@abs(parsed.current_score - 67.5) < 0.1);
}
