// @origin(spec:toxic_verdict.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// toxic_verdict v3.0.0 — Hungry Snake: 12 Honest Dimensions
// ═══════════════════════════════════════════════════════════════════════════════
//
// 12 dimensions in 3 tiers:
//   Tier 1 (0.50): BUILD, TEST_PASS, TEST_COVER
//   Tier 2 (0.30): TODO_DEBT, GOD_FILES, DEAD_CODE, DUPLICATION, SPEC_GAP
//   Tier 3 (0.20): RESEARCH, TOKEN_COST, ENERGY
//
// Formula:
//   total = 0.20*BUILD + 0.15*TEST_PASS + 0.15*TEST_COVER
//         + 0.06*TODO_DEBT + 0.05*GOD_FILES + 0.06*DEAD_CODE
//         + 0.05*DUPLICATION + 0.08*SPEC_GAP
//         + 0.08*RESEARCH + 0.06*TOKEN_COST + 0.06*ENERGY
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");
const swe_arena = @import("swe_arena.zig");
const thalamus = @import("thalamus.zig");
const github_client = @import("github_client.zig");
const hippocampus = @import("hippocampus.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;
const YELLOW = "\x1b[33m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerdictLevel = enum {
    legendary, // 90-100
    solid, // 70-89
    mediocre, // 50-69
    garbage, // 30-49
    disaster, // 0-29

    pub fn emoji(self: VerdictLevel) []const u8 {
        return switch (self) {
            .legendary => "💎",
            .solid => "🟢",
            .mediocre => "🟡",
            .garbage => "🔴",
            .disaster => "💀",
        };
    }

    pub fn label(self: VerdictLevel) []const u8 {
        return switch (self) {
            .legendary => "LEGENDARY",
            .solid => "SOLID",
            .mediocre => "MEDIOCRE",
            .garbage => "GARBAGE",
            .disaster => "DISASTER",
        };
    }

    pub fn color(self: VerdictLevel) []const u8 {
        return switch (self) {
            .legendary => GOLDEN,
            .solid => GREEN,
            .mediocre => YELLOW,
            .garbage => RED,
            .disaster => RED,
        };
    }
};

pub const VerdictInput = struct {
    // Existing (kept for backwards compat)
    build_ok: bool,
    test_passed: u32,
    test_total: u32,
    lines_added: u32 = 0,
    lines_removed: u32 = 0,
    specs_touched: u32 = 0,
    new_files: u32 = 0,
    dirty_files: u32 = 0,
    doctor_health: u32 = 0,
    compile_pass: u32 = 0,
    compile_total: u32 = 0,
    // v3: New fields for 12 dimensions
    files_with_tests: u32 = 0,
    files_total_zig: u32 = 0,
    todo_count: u32 = 0,
    fixme_count: u32 = 0,
    hack_count: u32 = 0,
    god_files: u32 = 0,
    stub_fns: u32 = 0,
    total_pub_fns: u32 = 0,
    duplicate_groups: u32 = 0,
    spec_gaps: u32 = 0,
    spec_total: u32 = 0,
    scholar_wakes: u32 = 0,
    scholar_researched: u32 = 0,
    experience_total: u32 = 0,
    experience_pass: u32 = 0,
    token_cost_score: u32 = 50,
};

pub const VerdictScore = struct {
    total: f32,
    // Tier 1 — Critical (0.50)
    build_score: f32,
    test_score: f32,
    cover_score: f32,
    // Tier 2 — Code Health (0.30)
    debt_score: f32,
    god_score: f32,
    dead_score: f32,
    dup_score: f32,
    spec_score: f32,
    // Tier 3 — Evolution (0.20)
    research_score: f32,
    cost_score: f32,
    energy_score: f32,
};

pub const PastComparison = struct {
    prev_score: f32,
    delta: f32,
    trend_up: bool,
};

pub const ToxicVerdict = struct {
    score: VerdictScore,
    level: VerdictLevel,
    input: VerdictInput,
    comparison: PastComparison,
    timestamp: i64,
};

pub const CellHealth = struct {
    healthy: u32,
    weak: u32,
    broken: u32,
    total: u32,
    timestamp: i64,
};

/// Read cell health from hippocampus — parses cerebellum observation summaries
/// Summary format: "cell health: 105/116 total (A:105 B:11 C:0 F:0)"
pub fn readCellHealthFromHippocampus(allocator: std.mem.Allocator) !CellHealth {
    const results = hippocampus.read(allocator, .{
        .agent = "cerebellum",
        .kind = .observation,
        .limit = 1,
    }) catch return .{
        .healthy = 0,
        .weak = 0,
        .broken = 0,
        .total = 0,
        .timestamp = 0,
    };
    defer results.deinit(allocator);

    if (results.items.len == 0) return .{
        .healthy = 0,
        .weak = 0,
        .broken = 0,
        .total = 0,
        .timestamp = 0,
    };

    // Parse "cell health: 105/116 total (A:105 B:11 C:0 F:0)"
    const summary = results.items[0].summary();
    var healthy: u32 = 0;
    var weak: u32 = 0;
    var broken: u32 = 0;
    var total: u32 = 0;

    if (std.mem.indexOf(u8, summary, "A:")) |idx| {
        const start = idx + 2;
        var end = start;
        while (end < summary.len and summary[end] >= '0' and summary[end] <= '9') : (end += 1) {}
        healthy = std.fmt.parseInt(u32, summary[start..end], 10) catch 0;
    }
    if (std.mem.indexOf(u8, summary, "B:")) |idx| {
        const start = idx + 2;
        var end = start;
        while (end < summary.len and summary[end] >= '0' and summary[end] <= '9') : (end += 1) {}
        weak = std.fmt.parseInt(u32, summary[start..end], 10) catch 0;
    }
    if (std.mem.indexOf(u8, summary, "C:")) |idx| {
        const start = idx + 2;
        var end = start;
        while (end < summary.len and summary[end] >= '0' and summary[end] <= '9') : (end += 1) {}
        broken = std.fmt.parseInt(u32, summary[start..end], 10) catch 0;
    }
    if (std.mem.indexOf(u8, summary, "total")) |idx| {
        const start = idx + 6;
        var end = start;
        while (end < summary.len and summary[end] >= '0' and summary[end] <= '9') : (end += 1) {}
        total = std.fmt.parseInt(u32, summary[start..end], 10) catch 0;
    }

    return .{
        .healthy = healthy,
        .weak = weak,
        .broken = broken,
        .total = total,
        .timestamp = results.items[0].ts,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Collect inputs from live system state — all 12 dimensions
pub fn collectInputs(allocator: std.mem.Allocator) VerdictInput {
    const tests = countTestBlocks(allocator);
    const build_ok = checkBuild(allocator);
    const coverage = countFileCoverage(allocator);
    const debt = countTechDebt(allocator);
    const gods = countGodFiles(allocator);
    const dead = countDeadCode(allocator);
    const dups = countDuplication(allocator);
    const specs = countSpecGaps(allocator);
    const scholar = readScholarHealth();
    const energy_vc = thalamus.countEpisodeVerdicts(allocator);
    const energy = EnergyHealth{ .total = energy_vc.total, .pass = energy_vc.pass };
    const cost = readTokenCost();

    return VerdictInput{
        .build_ok = build_ok,
        .test_passed = tests.passed,
        .test_total = tests.total,
        .files_with_tests = coverage.with_tests,
        .files_total_zig = coverage.total,
        .todo_count = debt.todo,
        .fixme_count = debt.fixme,
        .hack_count = debt.hack,
        .god_files = gods,
        .stub_fns = dead.stubs,
        .total_pub_fns = dead.total,
        .duplicate_groups = dups,
        .spec_gaps = specs.gaps,
        .spec_total = specs.total,
        .scholar_wakes = scholar.wakes,
        .scholar_researched = scholar.researched,
        .experience_total = energy.total,
        .experience_pass = energy.pass,
        .token_cost_score = cost,
    };
}

/// 12-dimension weighted formula
pub fn computeScore(input: VerdictInput) VerdictScore {
    // Tier 1 — Critical
    const build_score: f32 = if (input.build_ok) 100.0 else 0.0;
    const test_score: f32 = if (input.test_total > 0)
        @as(f32, @floatFromInt(input.test_passed)) / @as(f32, @floatFromInt(input.test_total)) * 100.0
    else
        0.0; // no tests = 0, not 50
    const cover_score: f32 = if (input.files_total_zig > 0)
        @as(f32, @floatFromInt(input.files_with_tests)) / @as(f32, @floatFromInt(input.files_total_zig)) * 100.0
    else
        0.0;

    // Tier 2 — Code Health
    const debt_total = input.todo_count + input.fixme_count * 2 + input.hack_count * 3;
    const debt_score: f32 = @max(0.0, 100.0 - @as(f32, @floatFromInt(debt_total)) * 0.3);
    const god_f: f32 = @floatFromInt(input.god_files);
    const god_score: f32 = @max(0.0, 100.0 - god_f * 3.0);
    const dead_score: f32 = if (input.total_pub_fns > 0)
        (1.0 - @as(f32, @floatFromInt(input.stub_fns)) / @as(f32, @floatFromInt(input.total_pub_fns))) * 100.0
    else
        50.0;
    const dup_f: f32 = @floatFromInt(input.duplicate_groups);
    const dup_score: f32 = @max(0.0, 100.0 - dup_f * 5.0);
    const spec_score: f32 = if (input.spec_total > 0)
        (1.0 - @as(f32, @floatFromInt(input.spec_gaps)) / @as(f32, @floatFromInt(input.spec_total))) * 100.0
    else
        0.0;

    // Tier 3 — Evolution
    const research_score: f32 = if (input.scholar_wakes > 0)
        @min(100.0, @as(f32, @floatFromInt(input.scholar_researched)) / @as(f32, @floatFromInt(input.scholar_wakes)) * 1000.0)
    else
        0.0;
    const cost_score: f32 = @as(f32, @floatFromInt(@min(input.token_cost_score, 100)));
    const energy_score: f32 = if (input.experience_total > 0)
        @as(f32, @floatFromInt(input.experience_pass)) / @as(f32, @floatFromInt(input.experience_total)) * 100.0
    else
        0.0;

    const total: f32 = 0.20 * build_score + 0.15 * test_score + 0.15 * cover_score + 0.06 * debt_score + 0.05 * god_score + 0.06 * dead_score + 0.05 * dup_score + 0.08 * spec_score + 0.08 * research_score + 0.06 * cost_score + 0.06 * energy_score;

    return VerdictScore{
        .total = @min(100.0, total),
        .build_score = build_score,
        .test_score = test_score,
        .cover_score = cover_score,
        .debt_score = debt_score,
        .god_score = god_score,
        .dead_score = dead_score,
        .dup_score = dup_score,
        .spec_score = spec_score,
        .research_score = research_score,
        .cost_score = cost_score,
        .energy_score = energy_score,
    };
}

/// Classify score into VerdictLevel
pub fn classifyLevel(score: f32) VerdictLevel {
    if (score >= 90.0) return .legendary;
    if (score >= 70.0) return .solid;
    if (score >= 50.0) return .mediocre;
    if (score >= 30.0) return .garbage;
    return .disaster;
}

/// Compare with past verdict from .trinity/verdict_history.json
pub fn compareWithPast(allocator: std.mem.Allocator, current_score: f32) PastComparison {
    _ = allocator;
    const path = ".trinity/verdict_history.json";
    const file = std.fs.cwd().openFile(path, .{}) catch {
        return PastComparison{ .prev_score = 0, .delta = current_score, .trend_up = true };
    };
    defer file.close();

    var buf: [4096]u8 = undefined;
    const bytes_read = file.readAll(&buf) catch {
        return PastComparison{ .prev_score = 0, .delta = current_score, .trend_up = true };
    };

    const content = buf[0..bytes_read];
    var last_score: f32 = 0;
    var pos: usize = 0;
    const needle = "\"total\":";
    while (pos < content.len) {
        if (std.mem.indexOf(u8, content[pos..], needle)) |idx| {
            const start = pos + idx + needle.len;
            var s = start;
            while (s < content.len and (content[s] == ' ' or content[s] == '\t')) : (s += 1) {}
            var end = s;
            while (end < content.len and (content[end] >= '0' and content[end] <= '9' or content[end] == '.')) : (end += 1) {}
            if (end > s) {
                last_score = std.fmt.parseFloat(f32, content[s..end]) catch 0;
            }
            pos = end;
        } else break;
    }

    return PastComparison{
        .prev_score = last_score,
        .delta = current_score - last_score,
        .trend_up = current_score >= last_score,
    };
}

/// Save verdict to .trinity/verdict_history.json
pub fn saveVerdict(allocator: std.mem.Allocator, v: ToxicVerdict) void {
    _ = allocator;
    const path = ".trinity/verdict_history.json";

    var existing: [32768]u8 = undefined;
    var existing_len: usize = 0;
    if (std.fs.cwd().openFile(path, .{})) |file| {
        existing_len = file.readAll(&existing) catch 0;
        file.close();
    } else |_| {}

    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();

    if (existing_len > 2) {
        const trimmed = std.mem.trimRight(u8, existing[0..existing_len], " \n\r\t");
        if (trimmed.len > 0 and trimmed[trimmed.len - 1] == ']') {
            file.writeAll(trimmed[0 .. trimmed.len - 1]) catch return;
            file.writeAll(",\n") catch return;
        } else {
            file.writeAll("[\n") catch return;
        }
    } else {
        file.writeAll("[\n") catch return;
    }

    var buf: [512]u8 = undefined;
    const entry = std.fmt.bufPrint(&buf, "  {{\"total\":{d:.1},\"build\":{d:.0},\"test\":{d:.1},\"cover\":{d:.1},\"debt\":{d:.1},\"spec\":{d:.1},\"level\":\"{s}\",\"ts\":{d}}}\n]", .{
        v.score.total,
        v.score.build_score,
        v.score.test_score,
        v.score.cover_score,
        v.score.debt_score,
        v.score.spec_score,
        v.level.label(),
        v.timestamp,
    }) catch return;
    file.writeAll(entry) catch return;
}

/// Render toxic verdict output — 12 dimensions in 3 tiers
pub fn renderVerdict(v: ToxicVerdict) void {
    const level = v.level;
    const score = v.score;
    const comp = v.comparison;

    std.debug.print("\n{s}TOXIC VERDICT v3 — HUNGRY SNAKE{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}SCORE: {d:.0}/100 {s} {s}{s}\n\n", .{
        level.color(), score.total, level.emoji(), level.label(), RESET,
    });

    // Tier 1 — Critical
    std.debug.print("  {s}TIER 1 — CRITICAL (50%){s}\n", .{ GOLDEN, RESET });
    printDim("BUILD", score.build_score, 0.20);
    printDim("TEST_PASS", score.test_score, 0.15);
    printDim("TEST_COVER", score.cover_score, 0.15);

    // Tier 2 — Code Health
    std.debug.print("  {s}TIER 2 — CODE HEALTH (30%){s}\n", .{ GOLDEN, RESET });
    printDim("TODO_DEBT", score.debt_score, 0.06);
    printDim("GOD_FILES", score.god_score, 0.05);
    printDim("DEAD_CODE", score.dead_score, 0.06);
    printDim("DUPLICATION", score.dup_score, 0.05);
    printDim("SPEC_GAP", score.spec_score, 0.08);

    // Tier 3 — Evolution
    std.debug.print("  {s}TIER 3 — EVOLUTION (20%){s}\n", .{ GOLDEN, RESET });
    printDim("RESEARCH", score.research_score, 0.08);
    printDim("TOKEN_COST", score.cost_score, 0.06);
    printDim("ENERGY", score.energy_score, 0.06);
    std.debug.print("\n", .{});

    // Past comparison
    if (comp.prev_score > 0) {
        const arrow: []const u8 = if (comp.trend_up) "↑" else "↓";
        const delta_color: []const u8 = if (comp.trend_up) GREEN else RED;
        const sign: []const u8 = if (comp.delta >= 0) "+" else "";
        std.debug.print("  Past: {d:.0}/100 → Now: {d:.0}/100 {s}{s}{s}{d:.0}{s}\n\n", .{
            comp.prev_score, score.total, delta_color, arrow, sign, comp.delta, RESET,
        });
    } else {
        std.debug.print("  First verdict — no past data\n\n", .{});
    }

    // Toxic roast
    std.debug.print("{s}ROAST:{s}\n", .{ RED, RESET });
    switch (level) {
        .legendary => std.debug.print("  Ship it. Actually ship it. Stop staring.\n", .{}),
        .solid => std.debug.print("  Not bad. Not great. You'll survive.\n", .{}),
        .mediocre => std.debug.print("  Mediocre. The code equivalent of room temperature water.\n", .{}),
        .garbage => std.debug.print("  This is garbage. You know it. I know it. Fix it.\n", .{}),
        .disaster => std.debug.print("  DISASTER. Stop everything. Fix the build. Fix the tests. NOW.\n", .{}),
    }
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn printDim(name: []const u8, score: f32, weight: f32) void {
    const clr: []const u8 = if (score >= 80) GREEN else if (score >= 60) CYAN else if (score >= 40) YELLOW else RED;
    std.debug.print("    {s}{s:<12}{s} {d:>5.1}/100  (w={d:.2})\n", .{ clr, name, RESET, score, weight });
}

/// Full verdict command: collect → compute → classify → compare → render → save
pub fn runVerdictCommand(allocator: std.mem.Allocator) void {
    const input = collectInputs(allocator);
    const score = computeScore(input);
    const level = classifyLevel(score.total);
    const comparison = compareWithPast(allocator, score.total);
    const timestamp = std.time.timestamp();

    const v = ToxicVerdict{
        .score = score,
        .level = level,
        .input = input,
        .comparison = comparison,
        .timestamp = timestamp,
    };

    renderVerdict(v);
    saveVerdict(allocator, v);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECTORS — Live system data
// ═══════════════════════════════════════════════════════════════════════════════

const TestCount = struct { passed: u32, total: u32 };
const CoverageCount = struct { with_tests: u32, total: u32 };
const DebtCount = struct { todo: u32, fixme: u32, hack: u32 };
const DeadCount = struct { stubs: u32, total: u32 };
const SpecGapCount = struct { gaps: u32, total: u32 };
const ScholarHealth = struct { wakes: u32, researched: u32 };
const EnergyHealth = struct { total: u32, pass: u32 };

fn checkBuild(allocator: std.mem.Allocator) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build", "--summary", "none" },
        .max_output_bytes = 1024 * 1024,
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    return result.term.Exited == 0;
}

fn countTestBlocks(allocator: std.mem.Allocator) TestCount {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig", "build", "test" },
        .max_output_bytes = 4 * 1024 * 1024,
    }) catch return TestCount{ .passed = 0, .total = 0 };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Count test blocks declared in build.zig output
    // Zig 0.15 prints "test\n+- run test ..." for each test step
    var test_steps: u32 = 0;
    var lines_iter = std.mem.splitScalar(u8, result.stderr, '\n');
    while (lines_iter.next()) |line| {
        // Each "+- run test" line = one test step in build.zig
        if (std.mem.indexOf(u8, line, "+- run test") != null) {
            test_steps += 1;
        }
    }

    const total = if (test_steps > 0) test_steps else 1;

    if (result.term.Exited == 0) {
        // Exit 0 = all tests passed
        return TestCount{ .passed = total, .total = total };
    }

    // Parse stderr for specific failure info
    const output = if (result.stderr.len > 0) result.stderr else result.stdout;
    const stats = swe_arena.parseTestOutput(output);
    if (stats.total > 0) {
        return TestCount{ .passed = stats.passed, .total = stats.total };
    }

    return TestCount{ .passed = 0, .total = total };
}

/// Count .zig files in src/tri/ that have test blocks
fn countFileCoverage(allocator: std.mem.Allocator) CoverageCount {
    _ = allocator;
    var dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch return CoverageCount{ .with_tests = 0, .total = 0 };
    defer dir.close();

    var total: u32 = 0;
    var with_tests: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        total += 1;

        // Read file and check for test blocks
        var fbuf: [65536]u8 = undefined;
        const f = dir.openFile(entry.name, .{}) catch continue;
        defer f.close();
        const n = f.readAll(&fbuf) catch continue;
        if (std.mem.indexOf(u8, fbuf[0..n], "test \"") != null) {
            with_tests += 1;
        }
    }

    return CoverageCount{ .with_tests = with_tests, .total = total };
}

/// Count TODO, FIXME, HACK, XXX markers in src/tri/
fn countTechDebt(allocator: std.mem.Allocator) DebtCount {
    _ = allocator;
    var dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch return DebtCount{ .todo = 0, .fixme = 0, .hack = 0 };
    defer dir.close();

    var todo: u32 = 0;
    var fixme: u32 = 0;
    var hack: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        var fbuf: [65536]u8 = undefined;
        const f = dir.openFile(entry.name, .{}) catch continue;
        defer f.close();
        const n = f.readAll(&fbuf) catch continue;
        const content = fbuf[0..n];

        var pos: usize = 0;
        while (pos < content.len) {
            if (pos + 4 <= content.len and std.mem.eql(u8, content[pos .. pos + 4], "TODO")) {
                todo += 1;
                pos += 4;
            } else if (pos + 5 <= content.len and std.mem.eql(u8, content[pos .. pos + 5], "FIXME")) {
                fixme += 1;
                pos += 5;
            } else if (pos + 4 <= content.len and std.mem.eql(u8, content[pos .. pos + 4], "HACK")) {
                hack += 1;
                pos += 4;
            } else if (pos + 3 <= content.len and std.mem.eql(u8, content[pos .. pos + 3], "XXX")) {
                hack += 1;
                pos += 3;
            } else {
                pos += 1;
            }
        }
    }

    return DebtCount{ .todo = todo, .fixme = fixme, .hack = hack };
}

/// Count files > 1500 LOC in src/tri/ (god file threshold)
fn countGodFiles(allocator: std.mem.Allocator) u32 {
    _ = allocator;
    var dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch return 0;
    defer dir.close();

    var gods: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        var fbuf: [131072]u8 = undefined;
        const f = dir.openFile(entry.name, .{}) catch continue;
        defer f.close();
        const n = f.readAll(&fbuf) catch continue;

        var lines: u32 = 0;
        for (fbuf[0..n]) |c| {
            if (c == '\n') lines += 1;
        }
        if (lines > 1500) gods += 1;
    }

    return gods;
}

/// Count stub pub fns (body is unreachable, return error, or < 3 lines)
fn countDeadCode(allocator: std.mem.Allocator) DeadCount {
    _ = allocator;
    var dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch return DeadCount{ .stubs = 0, .total = 0 };
    defer dir.close();

    var total: u32 = 0;
    var stubs: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        var fbuf: [131072]u8 = undefined;
        const f = dir.openFile(entry.name, .{}) catch continue;
        defer f.close();
        const n = f.readAll(&fbuf) catch continue;
        const content = fbuf[0..n];

        // Count "pub fn" occurrences
        var pos: usize = 0;
        while (pos + 6 < content.len) {
            if (std.mem.eql(u8, content[pos .. pos + 6], "pub fn")) {
                total += 1;
                // Check if next 200 chars contain stub indicators
                const check_end = @min(pos + 200, content.len);
                const snippet = content[pos..check_end];
                if (std.mem.indexOf(u8, snippet, "unreachable") != null or
                    std.mem.indexOf(u8, snippet, "_ = ") != null or
                    std.mem.indexOf(u8, snippet, "@panic") != null)
                {
                    stubs += 1;
                }
                pos += 6;
            } else {
                pos += 1;
            }
        }
    }

    return DeadCount{ .stubs = stubs, .total = total };
}

/// Count duplicate file groups (_v2, _v3, _v4 patterns)
fn countDuplication(allocator: std.mem.Allocator) u32 {
    _ = allocator;
    var dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch return 0;
    defer dir.close();

    // Simple: count files matching *_v[2-9].zig pattern
    var dups: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        const base = entry.name[0 .. entry.name.len - 4]; // remove .zig
        if (base.len >= 3) {
            const last = base[base.len - 1];
            const penult = base[base.len - 2];
            if (penult == 'v' and base[base.len - 3] == '_' and last >= '2' and last <= '9') {
                dups += 1;
            }
        }
    }

    return dups;
}

/// Count specs without matching .zig implementation
fn countSpecGaps(allocator: std.mem.Allocator) SpecGapCount {
    _ = allocator;
    var dir = std.fs.cwd().openDir("specs/tri", .{ .iterate = true }) catch return SpecGapCount{ .gaps = 0, .total = 0 };
    defer dir.close();

    var total: u32 = 0;
    var gaps: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".tri")) continue;
        total += 1;

        // Check if matching .zig exists in src/tri/ or generated/
        const base = entry.name[0 .. entry.name.len - 4]; // remove .tri
        var zig_name_buf: [256]u8 = undefined;
        const zig_name = std.fmt.bufPrint(&zig_name_buf, "{s}.zig", .{base}) catch continue;

        // Check src/tri/ (top-level)
        const has_src = blk: {
            var src_dir = std.fs.cwd().openDir("src/tri", .{}) catch break :blk false;
            defer src_dir.close();
            _ = src_dir.statFile(zig_name) catch break :blk false;
            break :blk true;
        };

        if (has_src) continue;

        // Check deploy/trinity-nexus/output/ subdirs for generated impl
        const has_gen = blk: {
            const gen_dirs = [_][]const u8{
                "deploy/trinity-nexus/output/lang/zig",
                "deploy/trinity-nexus/output/tri/zig",
                "deploy/trinity-nexus/output/phi/zig",
                "deploy/trinity-nexus/output/ralph/zig",
                "deploy/trinity-nexus/output/storage/zig",
                "deploy/trinity-nexus/output/network/zig",
                "deploy/trinity-nexus/output/sym/zig",
                "deploy/trinity-nexus/output/core/zig",
                "deploy/trinity-nexus/output/deploy/zig",
                "deploy/trinity-nexus/output/bootstrap/zig",
                "deploy/trinity-nexus/output/agent_mu/zig",
                "deploy/trinity-nexus/output/examples/zig",
            };
            for (gen_dirs) |gd| {
                var gdir = std.fs.cwd().openDir(gd, .{}) catch continue;
                defer gdir.close();
                _ = gdir.statFile(zig_name) catch continue;
                break :blk true;
            }
            break :blk false;
        };

        if (!has_gen) gaps += 1;
    }

    return SpecGapCount{ .gaps = gaps, .total = total };
}

/// Read scholar health from heartbeat + count real research artifacts
fn readScholarHealth() ScholarHealth {
    // Read wakes from heartbeat
    var wakes: u32 = 0;
    if (std.fs.cwd().openFile(".trinity/scholar/heartbeat.json", .{})) |file| {
        defer file.close();
        var buf: [4096]u8 = undefined;
        const n = file.readAll(&buf) catch 0;
        if (n > 0) {
            wakes = simpleJsonU32(buf[0..n], "wakes") orelse
                simpleJsonU32(buf[0..n], "wake_count") orelse
                simpleJsonU32(buf[0..n], "wake") orelse 0;
        }
    } else |_| {}

    // Count real research artifacts: docs/lab/papers/*.md + EXPERIENCE_LOG EXP- entries
    var researched: u32 = 0;

    // Count papers
    if (std.fs.cwd().openDir("papers", .{ .iterate = true })) |papers_dir_val| {
        var papers_dir = papers_dir_val;
        defer papers_dir.close();
        var piter = papers_dir.iterate();
        while (piter.next() catch null) |pentry| {
            if (pentry.kind == .directory) {
                // Each subdir with .md files = 1 research output
                var subdir = papers_dir.openDir(pentry.name, .{ .iterate = true }) catch continue;
                defer subdir.close();
                var siter = subdir.iterate();
                while (siter.next() catch null) |sentry| {
                    if (sentry.kind == .file and std.mem.endsWith(u8, sentry.name, ".md")) {
                        researched += 1;
                    }
                }
            }
        }
    } else |_| {}

    // Count EXPERIENCE_LOG entries (lines containing "EXP-0")
    if (std.fs.cwd().openFile("docs/lab/papers/EXPERIENCE_LOG.md", .{})) |efile| {
        defer efile.close();
        var ebuf: [32768]u8 = undefined;
        const en = efile.readAll(&ebuf) catch 0;
        if (en > 0) {
            var lines = std.mem.splitScalar(u8, ebuf[0..en], '\n');
            while (lines.next()) |line| {
                if (std.mem.indexOf(u8, line, "EXP-0") != null) researched += 1;
            }
        }
    } else |_| {}

    // Ensure wakes >= researched for sane ratio
    if (wakes < researched) wakes = researched;

    return ScholarHealth{ .wakes = wakes, .researched = researched };
}

/// Read experience episode success rate
fn readEnergyHealth(allocator: std.mem.Allocator) EnergyHealth {
    _ = allocator;
    var dir = std.fs.cwd().openDir(".trinity/experience/episodes", .{ .iterate = true }) catch
        return EnergyHealth{ .total = 0, .pass = 0 };
    defer dir.close();

    var total: u32 = 0;
    var pass: u32 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        total += 1;

        var fbuf: [8192]u8 = undefined;
        const f = dir.openFile(entry.name, .{}) catch continue;
        defer f.close();
        const n = f.readAll(&fbuf) catch continue;
        const content = fbuf[0..n];

        // Check for success verdict
        if (std.mem.indexOf(u8, content, "\"success\"") != null or
            std.mem.indexOf(u8, content, "\"PASS\"") != null or
            std.mem.indexOf(u8, content, "\"pass\"") != null)
        {
            pass += 1;
        }
    }

    return EnergyHealth{ .total = total, .pass = pass };
}

/// Read token cost efficiency score
fn readTokenCost() u32 {
    const file = std.fs.cwd().openFile(".trinity/ouroboros_metrics.json", .{}) catch return 50;
    defer file.close();

    var buf: [4096]u8 = undefined;
    const n = file.readAll(&buf) catch return 50;
    const content = buf[0..n];

    return simpleJsonU32(content, "efficiency") orelse 50;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPLAIN — 12 Dimension breakdown
// ═══════════════════════════════════════════════════════════════════════════════

pub const DimensionStatus = enum {
    strong, // >= 80
    ok, // >= 60
    weak, // >= 40
    critical, // < 40

    pub fn label(self: DimensionStatus) []const u8 {
        return switch (self) {
            .strong => "STRONG",
            .ok => "OK",
            .weak => "WEAK",
            .critical => "CRITICAL",
        };
    }

    pub fn color(self: DimensionStatus) []const u8 {
        return switch (self) {
            .strong => GREEN,
            .ok => CYAN,
            .weak => YELLOW,
            .critical => RED,
        };
    }
};

pub const DimensionExplanation = struct {
    name: []const u8,
    score: f32,
    weight: f32,
    status: DimensionStatus,
    reason: [256]u8 = [_]u8{0} ** 256,
    reason_len: u8 = 0,

    pub fn reasonStr(self: *const DimensionExplanation) []const u8 {
        return self.reason[0..self.reason_len];
    }
};

pub const VerdictExplanation = struct {
    dimensions: [12]DimensionExplanation,
    weakest: usize,
    strongest: usize,
};

fn classifyDimension(score: f32) DimensionStatus {
    if (score >= 80.0) return .strong;
    if (score >= 60.0) return .ok;
    if (score >= 40.0) return .weak;
    return .critical;
}

fn setReason(dim: *DimensionExplanation, msg: []const u8) void {
    const len: u8 = @intCast(@min(msg.len, dim.reason.len));
    @memcpy(dim.reason[0..len], msg[0..len]);
    dim.reason_len = len;
}

pub fn explainScore(score: VerdictScore, input: VerdictInput) VerdictExplanation {
    var dims: [12]DimensionExplanation = undefined;

    // Tier 1
    dims[0] = .{ .name = "BUILD", .score = score.build_score, .weight = 0.20, .status = classifyDimension(score.build_score) };
    if (input.build_ok) setReason(&dims[0], "Build passes") else setReason(&dims[0], "Build BROKEN — fix compilation errors");

    dims[1] = .{ .name = "TEST_PASS", .score = score.test_score, .weight = 0.15, .status = classifyDimension(score.test_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d}/{d} tests pass", .{ input.test_passed, input.test_total }) catch "tests";
        setReason(&dims[1], msg);
    }

    dims[2] = .{ .name = "TEST_COVER", .score = score.cover_score, .weight = 0.15, .status = classifyDimension(score.cover_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d}/{d} files have test blocks", .{ input.files_with_tests, input.files_total_zig }) catch "coverage";
        setReason(&dims[2], msg);
    }

    // Tier 2
    dims[3] = .{ .name = "TODO_DEBT", .score = score.debt_score, .weight = 0.06, .status = classifyDimension(score.debt_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d} TODO + {d} FIXME + {d} HACK", .{ input.todo_count, input.fixme_count, input.hack_count }) catch "debt";
        setReason(&dims[3], msg);
    }

    dims[4] = .{ .name = "GOD_FILES", .score = score.god_score, .weight = 0.05, .status = classifyDimension(score.god_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d} files > 1500 LOC", .{input.god_files}) catch "god files";
        setReason(&dims[4], msg);
    }

    dims[5] = .{ .name = "DEAD_CODE", .score = score.dead_score, .weight = 0.06, .status = classifyDimension(score.dead_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d}/{d} pub fns are stubs", .{ input.stub_fns, input.total_pub_fns }) catch "dead code";
        setReason(&dims[5], msg);
    }

    dims[6] = .{ .name = "DUPLICATION", .score = score.dup_score, .weight = 0.05, .status = classifyDimension(score.dup_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d} duplicate file groups (_v2/_v3)", .{input.duplicate_groups}) catch "duplication";
        setReason(&dims[6], msg);
    }

    dims[7] = .{ .name = "SPEC_GAP", .score = score.spec_score, .weight = 0.08, .status = classifyDimension(score.spec_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d}/{d} specs lack impl", .{ input.spec_gaps, input.spec_total }) catch "spec gaps";
        setReason(&dims[7], msg);
    }

    // Tier 3
    dims[8] = .{ .name = "RESEARCH", .score = score.research_score, .weight = 0.08, .status = classifyDimension(score.research_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d}/{d} scholar wakes productive", .{ input.scholar_researched, input.scholar_wakes }) catch "research";
        setReason(&dims[8], msg);
    }

    dims[9] = .{ .name = "TOKEN_COST", .score = score.cost_score, .weight = 0.06, .status = classifyDimension(score.cost_score) };
    setReason(&dims[9], "Token cost efficiency");

    dims[10] = .{ .name = "ENERGY", .score = score.energy_score, .weight = 0.06, .status = classifyDimension(score.energy_score) };
    {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{d}/{d} episodes pass", .{ input.experience_pass, input.experience_total }) catch "energy";
        setReason(&dims[10], msg);
    }

    // Padding for compile — keep array at 12
    dims[11] = .{ .name = "IP_PROTECT", .score = readIpScore(), .weight = 0.00, .status = classifyDimension(readIpScore()) };
    setReason(&dims[11], "Patent/DOI protection status");

    // Find weakest and strongest (only dims 0..11 with weight > 0)
    var weakest: usize = 0;
    var strongest: usize = 0;
    for (dims[0..11], 0..) |d, i| {
        if (d.score < dims[weakest].score) weakest = i;
        if (d.score > dims[strongest].score) strongest = i;
    }

    return .{ .dimensions = dims, .weakest = weakest, .strongest = strongest };
}

fn readIpScore() f32 {
    const file = std.fs.cwd().openFile(".trinity/patent/status.json", .{}) catch return 50.0;
    defer file.close();
    var buf: [4096]u8 = undefined;
    const n = file.readAll(&buf) catch return 50.0;
    const content = buf[0..n];
    // Count how many discoveries have status beyond "doi_only"
    var total_disc: u32 = 0;
    var protected: u32 = 0;
    var pos: usize = 0;
    while (pos < content.len) {
        if (std.mem.indexOfPos(u8, content, pos, "\"status\":")) |idx| {
            total_disc += 1;
            const s = idx + 9;
            if (s < content.len) {
                const rest = content[s..@min(s + 30, content.len)];
                if (std.mem.indexOf(u8, rest, "provisional") != null or
                    std.mem.indexOf(u8, rest, "filed") != null)
                {
                    protected += 1;
                }
            }
            pos = idx + 10;
        } else break;
    }
    if (total_disc == 0) return 50.0;
    return @as(f32, @floatFromInt(protected)) / @as(f32, @floatFromInt(total_disc)) * 50.0 + 50.0;
}

pub fn renderExplanation(explanation: VerdictExplanation) void {
    std.debug.print("\n{s}VERDICT BREAKDOWN — 12 DIMENSIONS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}─────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    for (&explanation.dimensions, 0..) |dim, i| {
        if (dim.weight == 0 and i >= 11) continue; // skip zero-weight dims
        const arrow: []const u8 = if (i == explanation.weakest) " <--" else "";
        std.debug.print("  {s}{s:<12}{s} {d:>5.1}/100  {s}{s:<8}{s}{s}\n", .{
            dim.status.color(), dim.name,           RESET,
            dim.score,          dim.status.color(), dim.status.label(),
            RESET,              arrow,
        });
    }

    std.debug.print("{s}─────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    const w = explanation.dimensions[explanation.weakest];
    std.debug.print("  WEAKEST: {s}{s}{s} ({d:.0}/100) — {s}\n\n", .{
        RED, w.name, RESET, w.score, w.reasonStr(),
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRESCRIBE — Concrete fix actions from 12 dimensions
// ═══════════════════════════════════════════════════════════════════════════════

pub const PrescribedAction = struct {
    priority: u8,
    dimension: []const u8,
    action: [512]u8 = [_]u8{0} ** 512,
    action_len: u16 = 0,
    expected_impact: f32,
    is_auto: bool = false,

    pub fn actionStr(self: *const PrescribedAction) []const u8 {
        return self.action[0..self.action_len];
    }
};

pub const MistakeEntry = struct {
    pattern: [128]u8 = [_]u8{0} ** 128,
    pattern_len: u8 = 0,
    count: u32 = 0,
    fix_hint: [256]u8 = [_]u8{0} ** 256,
    fix_hint_len: u8 = 0,

    pub fn patternStr(self: *const MistakeEntry) []const u8 {
        return self.pattern[0..self.pattern_len];
    }

    pub fn fixHintStr(self: *const MistakeEntry) []const u8 {
        return self.fix_hint[0..self.fix_hint_len];
    }
};

pub const VerdictPrescription = struct {
    actions: [15]PrescribedAction = undefined,
    action_count: u8 = 0,
    mistakes: [5]MistakeEntry = undefined,
    mistake_count: u8 = 0,
    current_score: f32,
    projected_score: f32,
};

fn setActionStr(act: *PrescribedAction, msg: []const u8) void {
    const len: u16 = @intCast(@min(msg.len, act.action.len));
    @memcpy(act.action[0..len], msg[0..len]);
    act.action_len = len;
}

pub fn prescribe(allocator: std.mem.Allocator, explanation: VerdictExplanation, score: VerdictScore) VerdictPrescription {
    var rx = VerdictPrescription{ .current_score = score.total, .projected_score = score.total };

    for (explanation.dimensions) |dim| {
        if (rx.action_count >= 15) break;
        if (dim.weight == 0) continue;

        switch (dim.status) {
            .critical, .weak => {
                var act = PrescribedAction{
                    .priority = if (dim.status == .critical) 1 else 2,
                    .dimension = dim.name,
                    .expected_impact = 0,
                };

                if (std.mem.eql(u8, dim.name, "BUILD")) {
                    setActionStr(&act, "Fix build: zig build 2>&1 | head -20");
                    act.expected_impact = 20;
                    act.is_auto = true;
                } else if (std.mem.eql(u8, dim.name, "TEST_PASS")) {
                    setActionStr(&act, "Fix failing tests: tri test");
                    act.expected_impact = (100.0 - dim.score) * 0.15;
                    act.is_auto = true;
                } else if (std.mem.eql(u8, dim.name, "TEST_COVER")) {
                    setActionStr(&act, "Add test blocks to untested files");
                    act.expected_impact = (100.0 - dim.score) * 0.15;
                } else if (std.mem.eql(u8, dim.name, "TODO_DEBT")) {
                    setActionStr(&act, "Resolve or remove TODO/FIXME markers");
                    act.expected_impact = (100.0 - dim.score) * 0.06;
                } else if (std.mem.eql(u8, dim.name, "GOD_FILES")) {
                    setActionStr(&act, "Split files > 1500 LOC (manual refactoring needed)");
                    act.expected_impact = (100.0 - dim.score) * 0.05;
                } else if (std.mem.eql(u8, dim.name, "DEAD_CODE")) {
                    setActionStr(&act, "Remove stub functions or implement them");
                    act.expected_impact = (100.0 - dim.score) * 0.06;
                } else if (std.mem.eql(u8, dim.name, "DUPLICATION")) {
                    setActionStr(&act, "Merge _v2/_v3 duplicates");
                    act.expected_impact = (100.0 - dim.score) * 0.05;
                } else if (std.mem.eql(u8, dim.name, "SPEC_GAP")) {
                    setActionStr(&act, "Create .zig impl for specs or remove stale specs");
                    act.expected_impact = (100.0 - dim.score) * 0.08;
                    act.is_auto = true;
                } else if (std.mem.eql(u8, dim.name, "RESEARCH")) {
                    setActionStr(&act, "Run tri scholar scan to find relevant papers");
                    act.expected_impact = (100.0 - dim.score) * 0.08;
                } else if (std.mem.eql(u8, dim.name, "TOKEN_COST")) {
                    setActionStr(&act, "Optimize: use smaller model for simple tasks");
                    act.expected_impact = (100.0 - dim.score) * 0.06;
                } else if (std.mem.eql(u8, dim.name, "ENERGY")) {
                    setActionStr(&act, "Fix failing experience episodes");
                    act.expected_impact = (100.0 - dim.score) * 0.06;
                }

                rx.projected_score += act.expected_impact;
                rx.actions[rx.action_count] = act;
                rx.action_count += 1;
            },
            .ok, .strong => {},
        }
    }

    loadMistakePatterns(allocator, &rx);
    rx.projected_score = @min(100.0, rx.projected_score);
    return rx;
}

fn loadMistakePatterns(allocator: std.mem.Allocator, rx: *VerdictPrescription) void {
    var dir = std.fs.cwd().openDir(".trinity/experience/mistakes", .{ .iterate = true }) catch return;
    defer dir.close();

    var all: [64]MistakeEntry = undefined;
    var count: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        if (count >= 64) break;

        const contents = dir.readFileAlloc(allocator, entry.name, 16 * 1024) catch continue;
        defer allocator.free(contents);

        var me = MistakeEntry{};
        if (simpleJsonStr(contents, "pattern")) |v| {
            const len: u8 = @intCast(@min(v.len, 128));
            @memcpy(me.pattern[0..len], v[0..len]);
            me.pattern_len = len;
        }
        if (simpleJsonStr(contents, "fix_hint")) |v| {
            const len: u8 = @intCast(@min(v.len, 256));
            @memcpy(me.fix_hint[0..len], v[0..len]);
            me.fix_hint_len = len;
        }
        if (simpleJsonU32(contents, "count")) |v| me.count = v;

        if (me.pattern_len > 0 and me.count >= 2) {
            all[count] = me;
            count += 1;
        }
    }

    if (count > 1) {
        std.mem.sort(MistakeEntry, all[0..count], {}, struct {
            fn lessThan(_: void, a: MistakeEntry, b: MistakeEntry) bool {
                return a.count > b.count;
            }
        }.lessThan);
    }

    const take = @min(count, 3);
    for (0..take) |i| {
        rx.mistakes[i] = all[i];
        rx.mistake_count += 1;
    }
}

fn simpleJsonStr(json: []const u8, key: []const u8) ?[]const u8 {
    var needle_buf: [140]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    const start = idx + needle.len;
    const end = std.mem.indexOfScalarPos(u8, json, start, '"') orelse return null;
    return json[start..end];
}

fn simpleJsonU32(json: []const u8, key: []const u8) ?u32 {
    var needle_buf: [140]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":", .{key}) catch return null;
    const idx = std.mem.indexOf(u8, json, needle) orelse return null;
    var s = idx + needle.len;
    while (s < json.len and (json[s] == ' ' or json[s] == '\t')) : (s += 1) {}
    var end = s;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == s) return null;
    return std.fmt.parseInt(u32, json[s..end], 10) catch null;
}

pub fn renderPrescription(rx: VerdictPrescription) void {
    if (rx.action_count == 0 and rx.mistake_count == 0) {
        std.debug.print("\n  {s}No prescriptions needed — looking good!{s}\n\n", .{ GREEN, RESET });
        return;
    }

    const total_items = @as(u8, rx.action_count) + rx.mistake_count;
    std.debug.print("\n{s}PRESCRIPTION ({d} actions){s}\n", .{ GOLDEN, total_items, RESET });
    std.debug.print("{s}─────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    for (rx.actions[0..rx.action_count]) |*act| {
        const pri_icon: []const u8 = if (act.priority == 1) "P1" else if (act.priority == 2) "P2" else "P3";
        const pri_color: []const u8 = if (act.priority == 1) RED else YELLOW;
        std.debug.print("  {s}{s}{s}  {s:<12} {s} → +{d:.0} pts\n", .{
            pri_color,     pri_icon,        RESET,
            act.dimension, act.actionStr(), act.expected_impact,
        });
    }

    for (rx.mistakes[0..rx.mistake_count]) |*m| {
        std.debug.print("  {s}P3{s}  PATTERN      \"{s}\" seen {d}x\n", .{
            YELLOW, RESET, m.patternStr(), m.count,
        });
        if (m.fix_hint_len > 0) {
            std.debug.print("                      Fix: {s}\n", .{m.fixHintStr()});
        }
    }

    std.debug.print("{s}─────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    const cur_level = classifyLevel(rx.current_score);
    const proj_level = classifyLevel(rx.projected_score);
    std.debug.print("  Current: {d:.0}/100 {s} → Projected: {d:.0}/100 {s}\n\n", .{
        rx.current_score, cur_level.label(), rx.projected_score, proj_level.label(),
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEED-AGENT — Machine-readable JSON
// ═══════════════════════════════════════════════════════════════════════════════

pub fn renderFeedAgentJson(
    score: VerdictScore,
    level: VerdictLevel,
    explanation: VerdictExplanation,
    rx: VerdictPrescription,
) void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    stdout.print("{{\"score\":{d:.0},\"level\":\"{s}\",\"dimensions\":{{", .{ score.total, level.label() }) catch return;

    for (&explanation.dimensions, 0..) |dim, i| {
        if (dim.weight == 0 and i >= 11) continue;
        if (i > 0) stdout.writeAll(",") catch return;
        stdout.print("\"{s}\":{{\"score\":{d:.0},\"status\":\"{s}\",\"reason\":\"", .{
            dim.name, dim.score, dim.status.label(),
        }) catch return;
        writeJsonEscaped(stdout, dim.reasonStr()) catch return;
        stdout.writeAll("\"}") catch return;
    }

    stdout.writeAll("},\"actions\":[") catch return;
    for (rx.actions[0..rx.action_count], 0..) |*act, i| {
        if (i > 0) stdout.writeAll(",") catch return;
        stdout.print("{{\"priority\":{d},\"dim\":\"{s}\",\"action\":\"", .{ act.priority, act.dimension }) catch return;
        writeJsonEscaped(stdout, act.actionStr()) catch return;
        stdout.print("\",\"impact\":{d:.0}}}", .{act.expected_impact}) catch return;
    }

    stdout.writeAll("],\"mistakes\":[") catch return;
    for (rx.mistakes[0..rx.mistake_count], 0..) |*m, i| {
        if (i > 0) stdout.writeAll(",") catch return;
        stdout.print("{{\"pattern\":\"", .{}) catch return;
        writeJsonEscaped(stdout, m.patternStr()) catch return;
        stdout.print("\",\"count\":{d},\"fix\":\"", .{m.count}) catch return;
        writeJsonEscaped(stdout, m.fixHintStr()) catch return;
        stdout.writeAll("\"}") catch return;
    }

    stdout.print("],\"projected_score\":{d:.0}}}\n", .{rx.projected_score}) catch return;
}

fn writeJsonEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTENDED VERDICT COMMAND — --explain, --prescribe, --feed-agent
// ═══════════════════════════════════════════════════════════════════════════════

pub const VerdictMode = enum {
    normal,
    explain,
    prescribe_mode,
    feed_agent,
};

pub fn runVerdictCommandEx(allocator: std.mem.Allocator, args: []const []const u8) void {
    var mode = VerdictMode.normal;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--explain")) mode = .explain else if (std.mem.eql(u8, arg, "--prescribe")) mode = .prescribe_mode else if (std.mem.eql(u8, arg, "--feed-agent")) mode = .feed_agent;
    }

    const input = collectInputs(allocator);
    const score = computeScore(input);
    const level = classifyLevel(score.total);
    const comparison = compareWithPast(allocator, score.total);
    const timestamp = std.time.timestamp();

    const v = ToxicVerdict{
        .score = score,
        .level = level,
        .input = input,
        .comparison = comparison,
        .timestamp = timestamp,
    };

    const explanation = explainScore(score, input);

    switch (mode) {
        .normal => renderVerdict(v),
        .explain => {
            renderVerdict(v);
            renderExplanation(explanation);
        },
        .prescribe_mode => {
            renderVerdict(v);
            renderExplanation(explanation);
            const rx = prescribe(allocator, explanation, score);
            renderPrescription(rx);
        },
        .feed_agent => {
            const rx = prescribe(allocator, explanation, score);
            renderFeedAgentJson(score, level, explanation, rx);
        },
    }

    saveVerdict(allocator, v);
}

/// Agent briefing: short verdict summary for step 2 of agent run
pub fn renderAgentBriefing(allocator: std.mem.Allocator) void {
    const input = collectInputs(allocator);
    const score = computeScore(input);
    const level = classifyLevel(score.total);
    const explanation = explainScore(score, input);
    const rx = prescribe(allocator, explanation, score);

    std.debug.print("    VERDICT BRIEFING: score {d:.0} ({s})\n", .{ score.total, level.label() });

    for (&explanation.dimensions) |dim| {
        switch (dim.status) {
            .critical => std.debug.print("      {s}{s}{s}: {s}\n", .{ RED, dim.name, RESET, dim.reasonStr() }),
            .weak => std.debug.print("      {s}{s}{s}: {s}\n", .{ YELLOW, dim.name, RESET, dim.reasonStr() }),
            .ok, .strong => {},
        }
    }

    for (rx.mistakes[0..rx.mistake_count]) |*m| {
        std.debug.print("      {s}pattern{s}: \"{s}\" ({d}x)\n", .{ YELLOW, RESET, m.patternStr(), m.count });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "compute_score_perfect_v3" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 100,
        .test_total = 100,
        .files_with_tests = 100,
        .files_total_zig = 100,
        .todo_count = 0,
        .fixme_count = 0,
        .hack_count = 0,
        .god_files = 0,
        .stub_fns = 0,
        .total_pub_fns = 100,
        .duplicate_groups = 0,
        .spec_gaps = 0,
        .spec_total = 50,
        .scholar_wakes = 10,
        .scholar_researched = 10,
        .experience_total = 10,
        .experience_pass = 10,
        .token_cost_score = 100,
    };
    const score = computeScore(input);
    try std.testing.expect(score.total >= 90.0);
    try std.testing.expect(score.build_score == 100.0);
    try std.testing.expect(score.cover_score == 100.0);
}

test "compute_score_broken_build_v3" {
    const input = VerdictInput{
        .build_ok = false,
        .test_passed = 0,
        .test_total = 10,
        .files_with_tests = 50,
        .files_total_zig = 100,
        .todo_count = 200,
        .fixme_count = 30,
        .hack_count = 5,
        .god_files = 5,
        .stub_fns = 50,
        .total_pub_fns = 100,
        .duplicate_groups = 10,
        .spec_gaps = 200,
        .spec_total = 250,
        .scholar_wakes = 100,
        .scholar_researched = 0,
        .experience_total = 10,
        .experience_pass = 2,
        .token_cost_score = 30,
    };
    const score = computeScore(input);
    try std.testing.expect(score.total < 40.0);
    try std.testing.expect(score.build_score == 0.0);
}

test "classify_levels" {
    try std.testing.expect(classifyLevel(95) == .legendary);
    try std.testing.expect(classifyLevel(75) == .solid);
    try std.testing.expect(classifyLevel(55) == .mediocre);
    try std.testing.expect(classifyLevel(35) == .garbage);
    try std.testing.expect(classifyLevel(15) == .disaster);
}

test "explain_12_dimensions" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 100,
        .test_total = 100,
        .files_with_tests = 80,
        .files_total_zig = 100,
        .todo_count = 50,
        .fixme_count = 10,
        .hack_count = 5,
        .god_files = 3,
        .stub_fns = 20,
        .total_pub_fns = 200,
        .duplicate_groups = 5,
        .spec_gaps = 100,
        .spec_total = 200,
        .scholar_wakes = 100,
        .scholar_researched = 0,
        .experience_total = 10,
        .experience_pass = 5,
        .token_cost_score = 50,
    };
    const score = computeScore(input);
    const explanation = explainScore(score, input);

    // Should have 12 dimensions
    try std.testing.expect(explanation.dimensions.len == 12);
    // BUILD should be strong
    try std.testing.expect(explanation.dimensions[0].status == .strong);
    // RESEARCH should be critical (0/100 researched)
    try std.testing.expect(explanation.dimensions[8].status == .critical);
}

test "classify_dimension_thresholds" {
    try std.testing.expect(classifyDimension(85) == .strong);
    try std.testing.expect(classifyDimension(65) == .ok);
    try std.testing.expect(classifyDimension(45) == .weak);
    try std.testing.expect(classifyDimension(35) == .critical);
}

test "prescribe_generates_actions_v3" {
    const input = VerdictInput{
        .build_ok = false,
        .test_passed = 50,
        .test_total = 100,
        .files_with_tests = 30,
        .files_total_zig = 100,
        .todo_count = 200,
        .fixme_count = 50,
        .hack_count = 10,
        .god_files = 5,
        .stub_fns = 50,
        .total_pub_fns = 100,
        .duplicate_groups = 10,
        .spec_gaps = 200,
        .spec_total = 250,
        .scholar_wakes = 100,
        .scholar_researched = 0,
        .experience_total = 10,
        .experience_pass = 2,
        .token_cost_score = 30,
    };
    const score = computeScore(input);
    const explanation = explainScore(score, input);
    const rx = prescribe(std.testing.allocator, explanation, score);

    // Should have multiple actions (build broken + many weak dims)
    try std.testing.expect(rx.action_count >= 5);
    try std.testing.expect(rx.projected_score > rx.current_score);
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-COLLECT — Pipeline-friendly verdict without manual input (v2.0)
// ═══════════════════════════════════════════════════════════════════════════════

/// Auto-collect verdict input, compute score, and return gate result.
/// Used by pipeline_parallel for automated quality gates.
pub const PipelineVerdictResult = struct {
    verdict: ToxicVerdict,
    gate_pass: bool,
    threshold: f32,
    recommendation: [256]u8 = [_]u8{0} ** 256,
    recommendation_len: usize = 0,
};

/// Collect inputs, compute verdict, check against threshold.
/// Returns PipelineVerdictResult with gate_pass and recommendation.
/// Also triggers immune system (auto-create doctor tasks) when health is low.
pub fn autoCollectAndVerdict(allocator: std.mem.Allocator, threshold: f32) PipelineVerdictResult {
    const input = collectInputs(allocator);
    defer allocator.free(input.files);
    const score = computeScore(input);
    const level = classifyLevel(score.total);
    const comparison = compareWithPast(allocator, score.total);
    const timestamp = std.time.timestamp();

    // Immune system: read cell health and potentially create doctor task
    const cell_health = readCellHealthFromHippocampus(allocator) catch CellHealth{
        .healthy = 0,
        .weak = 0,
        .broken = 0,
        .total = 0,
        .timestamp = timestamp,
    };
    createDoctorTaskIfNeeded(allocator, score.total, cell_health) catch |err| {
        std.debug.print("Warning: failed to create doctor task: {}\n", .{err});
    };

    const verdict = ToxicVerdict{
        .score = score,
        .level = level,
        .input = input,
        .comparison = comparison,
        .timestamp = timestamp,
    };

    const pass = score.total >= threshold;

    var result = PipelineVerdictResult{
        .verdict = verdict,
        .gate_pass = pass,
        .threshold = threshold,
    };

    // Generate recommendation
    const rec = if (!input.build_ok)
        "Build broken — fix compilation errors first"
    else if (!pass)
        "Score below threshold — improve test coverage and reduce debt"
    else
        "Quality gate passed — proceed to next pipeline step";

    const rec_len = @min(rec.len, 256);
    @memcpy(result.recommendation[0..rec_len], rec[0..rec_len]);
    result.recommendation_len = rec_len;

    return result;
}

test "simpleJsonStr_parsing" {
    const json = "{\"pattern\":\"forgot errdefer\",\"count\":5}";
    const pattern = simpleJsonStr(json, "pattern");
    try std.testing.expect(pattern != null);
    try std.testing.expectEqualStrings("forgot errdefer", pattern.?);
}

test "simpleJsonU32_parsing" {
    const json = "{\"pattern\":\"test\",\"count\":42}";
    const count = simpleJsonU32(json, "count");
    try std.testing.expect(count != null);
    try std.testing.expectEqual(@as(u32, 42), count.?);
}

test "debt_score_formula" {
    // 0 debt = 100
    const input_clean = VerdictInput{
        .build_ok = true,
        .test_passed = 1,
        .test_total = 1,
    };
    const clean = computeScore(input_clean);
    try std.testing.expect(clean.debt_score == 100.0);

    // 300 TODO + 0 FIXME + 0 HACK = debt_total = 300, score = max(0, 100 - 300*0.3) = 10
    const input_dirty = VerdictInput{
        .build_ok = true,
        .test_passed = 1,
        .test_total = 1,
        .todo_count = 300,
    };
    const dirty = computeScore(input_dirty);
    try std.testing.expect(dirty.debt_score == 10.0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMMUNE SYSTEM — Auto-generate doctor tasks when health drops (v1.0)
// ═══════════════════════════════════════════════════════════════════════════════

/// Create GitHub doctor issue if health score is low or cells are broken.
/// Trigger conditions:
///   - score < 70 (health threshold)
///   - broken > 0 (any broken cells)
///
/// Labels applied:
///   - agent:doctor (assigned to doctor agent)
///   - status:queued (ready for processing)
///   - priority:critical (score < 50) or priority:high (score < 70)
///   - auto-generated (immune system trigger)
pub fn createDoctorTaskIfNeeded(allocator: std.mem.Allocator, score: f32, cell_health: CellHealth) !void {
    const threshold: f32 = 70.0;

    // Skip if health is acceptable and no broken cells
    if (score >= threshold and cell_health.broken == 0) return;

    // Build issue title
    var title_buf: [256]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Doctor Auto-Task: Health {d:.1}% | {d} broken cells", .{ score, cell_health.broken }) catch return;

    // Build issue body
    var body_buf: [2048]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        \\## Auto-Generated Doctor Task
        \\
        \\**Trigger**: Health score below threshold ({d:.1}% < {d:.0}%)
        \\**Cell Health**: {d} healthy, {d} weak, {d} broken
        \\
        \\### Actions Required
        \\
        \\1. **Scan**: `tri doctor scan` — full analysis
        \\2. **Report**: `tri doctor report` — detailed breakdown
        \\3. **Heal**: `tri doctor heal` — auto-fix where possible
        \\
        \\### Priority: {s}
        \\
        \\*Generated by Pathology ({d})*
    , .{
        score,                threshold,
        cell_health.healthy,  cell_health.weak,
        cell_health.broken,   if (score < 50) "CRITICAL" else "HIGH",
        std.time.timestamp(),
    }) catch return;

    // Create GitHub issue
    var gh = try github_client.GitHubClient.init(allocator, false);
    defer gh.deinit();

    const priority_label = if (score < 50) "priority:critical" else "priority:high";
    const labels = &[_][]const u8{
        "agent:doctor",
        "status:queued",
        priority_label,
        "auto-generated",
    };

    _ = try gh.createIssue(title, body, labels);
}

test "createDoctorTaskIfNeeded_skips_when_healthy" {
    const health = CellHealth{
        .healthy = 100,
        .weak = 10,
        .broken = 0,
        .total = 110,
        .timestamp = std.time.timestamp(),
    };

    // Score 80, no broken cells — should skip (no error = skipped)
    try createDoctorTaskIfNeeded(std.testing.allocator, 80.0, health);
}

test "createDoctorTaskIfNeeded_creates_on_low_score" {
    const health = CellHealth{
        .healthy = 50,
        .weak = 20,
        .broken = 0,
        .total = 70,
        .timestamp = std.time.timestamp(),
    };

    // Score 60 < 70 — should create task (dry run in test env)
    try createDoctorTaskIfNeeded(std.testing.allocator, 60.0, health);
}

test "createDoctorTaskIfNeeded_creates_on_broken_cells" {
    const health = CellHealth{
        .healthy = 80,
        .weak = 10,
        .broken = 5,
        .total = 95,
        .timestamp = std.time.timestamp(),
    };

    // Score 75 but broken > 0 — should create task
    try createDoctorTaskIfNeeded(std.testing.allocator, 75.0, health);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRYPOINT — Manual auto-task check
// ═══════════════════════════════════════════════════════════════════════════════

/// Run auto-task check manually from CLI.
/// Collects inputs, reads cell health from hippocampus, computes score,
/// and creates doctor task if health is low or cells are broken.
pub fn runAutoTaskCheck(allocator: std.mem.Allocator) !void {
    const input = collectInputs(allocator);
    defer allocator.free(input.files);
    const cell_health = try readCellHealthFromHippocampus(allocator);
    const score = computeScore(input);
    try createDoctorTaskIfNeeded(allocator, score.total, cell_health);
    std.debug.print("\n Auto-task check complete\n", .{});
}

// ═══════════════════════════════════════════════════════════════════
// VERDICT LEVEL TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — VerdictLevel emoji" {
    try std.testing.expectEqualStrings("💎", VerdictLevel.legendary.emoji());
    try std.testing.expectEqualStrings("🟢", VerdictLevel.solid.emoji());
    try std.testing.expectEqualStrings("🟡", VerdictLevel.mediocre.emoji());
    try std.testing.expectEqualStrings("🔴", VerdictLevel.garbage.emoji());
    try std.testing.expectEqualStrings("💀", VerdictLevel.disaster.emoji());
}

test "pathology — VerdictLevel label" {
    try std.testing.expectEqualStrings("LEGENDARY", VerdictLevel.legendary.label());
    try std.testing.expectEqualStrings("SOLID", VerdictLevel.solid.label());
    try std.testing.expectEqualStrings("MEDIOCRE", VerdictLevel.mediocre.label());
    try std.testing.expectEqualStrings("GARBAGE", VerdictLevel.garbage.label());
    try std.testing.expectEqualStrings("DISASTER", VerdictLevel.disaster.label());
}

test "pathology — VerdictLevel color" {
    try std.testing.expectEqual(GOLDEN, VerdictLevel.legendary.color());
    try std.testing.expectEqualStrings(GREEN, VerdictLevel.solid.color());
    try std.testing.expectEqualStrings(YELLOW, VerdictLevel.mediocre.color());
    try std.testing.expectEqualStrings(RED, VerdictLevel.garbage.color());
    try std.testing.expectEqualStrings(RED, VerdictLevel.disaster.color());
}

test "pathology — classifyLevel boundary values" {
    try std.testing.expect(classifyLevel(90) == .legendary);
    try std.testing.expect(classifyLevel(100) == .legendary);
    try std.testing.expect(classifyLevel(70) == .solid);
    try std.testing.expect(classifyLevel(89) == .solid);
    try std.testing.expect(classifyLevel(50) == .mediocre);
    try std.testing.expect(classifyLevel(69) == .mediocre);
    try std.testing.expect(classifyLevel(30) == .garbage);
    try std.testing.expect(classifyLevel(49) == .garbage);
    try std.testing.expect(classifyLevel(0) == .disaster);
    try std.testing.expect(classifyLevel(29) == .disaster);
}

test "pathology — classifyLevel edge cases" {
    try std.testing.expect(classifyLevel(89.9) == .solid); // Just below legendary
    try std.testing.expect(classifyLevel(90.0) == .legendary); // Exactly legendary
    try std.testing.expect(classifyLevel(69.9) == .mediocre); // Just below solid
    try std.testing.expect(classifyLevel(70.0) == .solid); // Exactly solid
}

test "pathology — classifyDimension boundary values" {
    try std.testing.expect(classifyDimension(85) == .strong);
    try std.testing.expect(classifyDimension(100) == .strong);
    try std.testing.expect(classifyDimension(80) == .strong);
    try std.testing.expect(classifyDimension(65) == .ok);
    try std.testing.expect(classifyDimension(60) == .ok);
    try std.testing.expect(classifyDimension(45) == .weak);
    try std.testing.expect(classifyDimension(40) == .weak);
    try std.testing.expect(classifyDimension(0) == .critical);
    try std.testing.expect(classifyDimension(39) == .critical);
}

// ═══════════════════════════════════════════════════════════════════
// VERDICT INPUT TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — VerdictInput defaults" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 10,
        .test_total = 10,
    };
    try std.testing.expectEqual(@as(u32, 0), input.files_with_tests);
    try std.testing.expectEqual(@as(u32, 0), input.files_total_zig);
    try std.testing.expectEqual(@as(u32, 0), input.todo_count);
    try std.testing.expectEqual(@as(u32, 0), input.fixme_count);
    try std.testing.expectEqual(@as(u32, 0), input.hack_count);
    try std.testing.expectEqual(@as(u32, 50), input.token_cost_score);
}

test "pathology — VerdictInput all fields" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 95,
        .test_total = 100,
        .files_with_tests = 80,
        .files_total_zig = 100,
        .todo_count = 10,
        .fixme_count = 5,
        .hack_count = 2,
        .god_files = 1,
        .stub_fns = 10,
        .total_pub_fns = 200,
        .duplicate_groups = 3,
        .spec_gaps = 20,
        .spec_total = 100,
        .scholar_wakes = 50,
        .scholar_researched = 40,
        .experience_total = 10,
        .experience_pass = 8,
        .token_cost_score = 80,
    };
    try std.testing.expectEqual(@as(u32, 95), input.test_passed);
    try std.testing.expectEqual(@as(u32, 80), input.token_cost_score);
}

// ═══════════════════════════════════════════════════════════════════
// VERDICT SCORE TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — VerdictScore tier_weights" {
    // Perfect input should give 100 for each dimension
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 100,
        .test_total = 100,
        .files_with_tests = 100,
        .files_total_zig = 100,
        .todo_count = 0,
        .fixme_count = 0,
        .hack_count = 0,
        .god_files = 0,
        .stub_fns = 0,
        .total_pub_fns = 100,
        .duplicate_groups = 0,
        .spec_gaps = 0,
        .spec_total = 100,
        .scholar_wakes = 10,
        .scholar_researched = 10,
        .experience_total = 10,
        .experience_pass = 10,
        .token_cost_score = 100,
    };
    const score = computeScore(input);

    // Each dimension should be 100 for perfect input
    try std.testing.expect(score.build_score == 100.0);
    try std.testing.expect(score.test_score == 100.0);
    try std.testing.expect(score.cover_score == 100.0);
    try std.testing.expect(score.debt_score == 100.0);
    try std.testing.expect(score.god_score == 100.0);
    try std.testing.expect(score.dead_score == 100.0);
    try std.testing.expect(score.dup_score == 100.0);
    try std.testing.expect(score.spec_score == 100.0);
    try std.testing.expect(score.research_score == 100.0);
    try std.testing.expect(score.cost_score == 100.0);
    try std.testing.expect(score.energy_score == 100.0);

    // Total should be 100 (weighted and capped)
    try std.testing.expect(score.total == 100.0);
}

// ═══════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — CellHealth defaults" {
    const health = CellHealth{
        .healthy = 0,
        .weak = 0,
        .broken = 0,
        .total = 0,
        .timestamp = 0,
    };
    try std.testing.expectEqual(@as(u32, 0), health.healthy);
    try std.testing.expectEqual(@as(u32, 0), health.weak);
    try std.testing.expectEqual(@as(u32, 0), health.broken);
    try std.testing.expectEqual(@as(u32, 0), health.total);
}

test "pathology — CellHealth with values" {
    const health = CellHealth{
        .healthy = 100,
        .weak = 10,
        .broken = 5,
        .total = 115,
        .timestamp = 1234567890,
    };
    try std.testing.expectEqual(@as(u32, 100), health.healthy);
    try std.testing.expectEqual(@as(u32, 10), health.weak);
    try std.testing.expectEqual(@as(u32, 5), health.broken);
    try std.testing.expectEqual(@as(u32, 115), health.total);
}

test "pathology — CellHealth timestamp" {
    const health = CellHealth{
        .healthy = 50,
        .weak = 5,
        .broken = 0,
        .total = 55,
        .timestamp = std.time.timestamp(),
    };
    try std.testing.expect(health.timestamp > 0);
}

// ═══════════════════════════════════════════════════════════════════
// SIMPLE JSON PARSING TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — simpleJsonStr missing key" {
    const json = "{\"pattern\":\"test\"}";
    const result = simpleJsonStr(json, "missing");
    try std.testing.expect(result == null);
}

test "pathology — simpleJsonStr empty string" {
    const json = "{\"value\":\"\"}";
    const result = simpleJsonStr(json, "value");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("", result.?);
}

test "pathology — simpleJsonU32 missing key" {
    const json = "{\"count\":42}";
    const result = simpleJsonU32(json, "missing");
    try std.testing.expect(result == null);
}

test "pathology — simpleJsonU32 zero" {
    const json = "{\"count\":0}";
    const result = simpleJsonU32(json, "count");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 0), result.?);
}

test "pathology — simpleJsonU32 large number" {
    const json = "{\"value\":999999}";
    const result = simpleJsonU32(json, "value");
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u32, 999999), result.?);
}

// ═══════════════════════════════════════════════════════════════════
// PAST COMPARISON TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — PastComparison structure" {
    const comp = PastComparison{
        .prev_score = 75.0,
        .delta = 5.0,
        .trend_up = true,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 75.0), comp.prev_score, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), comp.delta, 0.01);
    try std.testing.expect(comp.trend_up);
}

test "pathology — PastComparison downward trend" {
    const comp = PastComparison{
        .prev_score = 70.0,
        .delta = -10.0,
        .trend_up = false,
    };
    try std.testing.expectApproxEqAbs(@as(f32, -10.0), comp.delta, 0.01);
    try std.testing.expect(!comp.trend_up);
}

// ═══════════════════════════════════════════════════════════════════
// TOXIC VERDICT TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — ToxicVerdict structure" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 100,
        .test_total = 100,
    };
    const score = computeScore(input);
    const level = classifyLevel(score.total);
    const comparison = PastComparison{
        .prev_score = 80.0,
        .delta = 5.0,
        .trend_up = true,
    };

    const verdict = ToxicVerdict{
        .score = score,
        .level = level,
        .input = input,
        .comparison = comparison,
        .timestamp = std.time.timestamp(),
    };

    // With minimal input, score will be mediocre (around 50-60 range)
    try std.testing.expect(verdict.level == .mediocre or verdict.level == .solid);
    try std.testing.expect(verdict.timestamp > 0);
}

// ═══════════════════════════════════════════════════════════════════
// PRESCRIPTION TESTS
// ═══════════════════════════════════════════════════════════════════

test "pathology — Prescription structure" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 50,
        .test_total = 100,
        .files_with_tests = 30,
        .files_total_zig = 100,
    };
    const score = computeScore(input);
    const explanation = explainScore(score, input);
    const rx = prescribe(std.testing.allocator, explanation, score);

    try std.testing.expect(rx.action_count > 0);
    try std.testing.expect(rx.current_score < 100.0);
    try std.testing.expect(rx.projected_score > rx.current_score);
}

test "pathology — Prescription projected_score cap" {
    const input = VerdictInput{
        .build_ok = true,
        .test_passed = 100,
        .test_total = 100,
        .files_with_tests = 100,
        .files_total_zig = 100,
        .todo_count = 0,
        .fixme_count = 0,
        .hack_count = 0,
        .god_files = 0,
        .stub_fns = 0,
        .total_pub_fns = 100,
        .duplicate_groups = 0,
        .spec_gaps = 0,
        .spec_total = 100,
        .scholar_wakes = 10,
        .scholar_researched = 10,
        .experience_total = 10,
        .experience_pass = 10,
        .token_cost_score = 100,
    };
    const score = computeScore(input);
    const explanation = explainScore(score, input);
    const rx = prescribe(std.testing.allocator, explanation, score);

    // Perfect score should cap at 100
    try std.testing.expect(rx.projected_score <= 100.0);
}
