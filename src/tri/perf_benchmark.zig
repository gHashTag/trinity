// @origin(spec:perf_benchmark.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// PERF BENCHMARK — Performance benchmarking against previous versions
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri bench [compare|record|history]
// Collects compile rate, spec count, LOC, test count, build time, binaries.
// Compares with stored baselines, shows deltas with direction arrows.
//
// Part of Trinity Tech Tree: Optimization Layer [O1]
// Baselines stored in .trinity/baselines.json
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const colors = @import("tri_colors.zig");
const print = std.debug.print;

const GREEN = colors.GREEN;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RESET = colors.RESET;
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from perf_benchmark.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Baseline = struct {
    version: [32]u8 = undefined,
    version_len: usize = 0,
    date: [16]u8 = undefined,
    date_len: usize = 0,
    specs_count: u32 = 0,
    loc: u32 = 0,
    test_count: u32 = 0,
    binaries: u32 = 0,
    binaries_total: u32 = 6,
    build_time_ms: u32 = 0,

    pub fn versionStr(self: *const Baseline) []const u8 {
        return self.version[0..self.version_len];
    }

    pub fn dateStr(self: *const Baseline) []const u8 {
        return self.date[0..self.date_len];
    }

    fn setVersion(self: *Baseline, text: []const u8) void {
        const len = @min(text.len, self.version.len);
        @memcpy(self.version[0..len], text[0..len]);
        self.version_len = len;
    }

    fn setDate(self: *Baseline, text: []const u8) void {
        const len = @min(text.len, self.date.len);
        @memcpy(self.date[0..len], text[0..len]);
        self.date_len = len;
    }
};

pub const Delta = struct {
    metric: [32]u8 = undefined,
    metric_len: usize = 0,
    old_val: u32 = 0,
    new_val: u32 = 0,
    direction: Direction = .neutral,

    pub const Direction = enum {
        better,
        worse,
        neutral,

        pub fn arrow(self: Direction) []const u8 {
            return switch (self) {
                .better => "+",
                .worse => "-",
                .neutral => "=",
            };
        }

        pub fn color(self: Direction) []const u8 {
            return switch (self) {
                .better => GREEN,
                .worse => RED,
                .neutral => GRAY,
            };
        }
    };

    pub fn metricStr(self: *const Delta) []const u8 {
        return self.metric[0..self.metric_len];
    }

    fn setMetric(self: *Delta, text: []const u8) void {
        const len = @min(text.len, self.metric.len);
        @memcpy(self.metric[0..len], text[0..len]);
        self.metric_len = len;
    }

    pub fn change(self: *const Delta) i64 {
        return @as(i64, self.new_val) - @as(i64, self.old_val);
    }
};

const MAX_DELTAS = 8;
const MAX_BASELINES = 16;

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECT CURRENT METRICS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn collectCurrent(allocator: Allocator) Baseline {
    var baseline = Baseline{};

    // Version = today's date
    var date_buf: [16]u8 = undefined;
    const ts = std.time.timestamp();
    const epoch_day = @divTrunc(ts, 86400);
    const date_str = std.fmt.bufPrint(&date_buf, "v{d}", .{epoch_day}) catch "v0";
    baseline.setVersion(date_str);
    baseline.setDate(date_str);

    // Count specs
    baseline.specs_count = countFiles(allocator, "specs/tri", ".tri");

    // Count test blocks in .zig files
    baseline.test_count = countTestBlocks(allocator);

    // Count LOC
    baseline.loc = countLoc(allocator);

    // Count binaries
    baseline.binaries = countFiles(allocator, "zig-out/bin", "");

    // Build time
    baseline.build_time_ms = measureBuildTime(allocator);

    return baseline;
}

fn countFiles(allocator: Allocator, dir_path: []const u8, extension: []const u8) u32 {
    _ = allocator;
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();

    var count: u32 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (extension.len > 0 and !std.mem.endsWith(u8, entry.name, extension)) continue;
        count += 1;
    }
    return count;
}

fn countTestBlocks(allocator: Allocator) u32 {
    _ = allocator;
    var count: u32 = 0;

    // Scan src/tri/ for test blocks
    var dir = std.fs.cwd().openDir("src/tri", .{ .iterate = true }) catch return 0;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();

        var buf: [65536]u8 = undefined;
        const bytes = file.readAll(&buf) catch continue;
        const content = buf[0..bytes];

        // Count test " occurrences
        var pos: usize = 0;
        while (pos < content.len) {
            const idx = std.mem.indexOfPos(u8, content, pos, "test \"") orelse break;
            count += 1;
            pos = idx + 6;
        }
    }
    return count;
}

fn countLoc(allocator: Allocator) u32 {
    _ = allocator;
    var total: u32 = 0;

    const dirs = [_][]const u8{ "src/tri", "src/hslm", "src/cli" };
    for (dirs) |dir_path| {
        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch continue;
        defer dir.close();

        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

            const file = dir.openFile(entry.name, .{}) catch continue;
            defer file.close();

            var buf: [131072]u8 = undefined;
            const bytes = file.readAll(&buf) catch continue;
            const content = buf[0..bytes];

            var lines: u32 = 0;
            for (content) |c| {
                if (c == '\n') lines += 1;
            }
            total += lines;
        }
    }
    return total;
}

fn measureBuildTime(allocator: Allocator) u32 {
    const start = std.time.milliTimestamp();
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "build" },
        .max_output_bytes = 65536,
    }) catch return 0;
    const end = std.time.milliTimestamp();
    return @intCast(@as(u64, @bitCast(end - start)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPUTE DELTAS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DeltaResult = struct {
    deltas: [MAX_DELTAS]Delta = undefined,
    count: usize = 0,
};

pub fn computeDeltas(current: *const Baseline, previous: *const Baseline) DeltaResult {
    var result = DeltaResult{};

    const metrics = [_]struct { name: []const u8, cur: u32, prev: u32, higher_better: bool }{
        .{ .name = "specs", .cur = current.specs_count, .prev = previous.specs_count, .higher_better = true },
        .{ .name = "tests", .cur = current.test_count, .prev = previous.test_count, .higher_better = true },
        .{ .name = "loc", .cur = current.loc, .prev = previous.loc, .higher_better = true },
        .{ .name = "binaries", .cur = current.binaries, .prev = previous.binaries, .higher_better = true },
        .{ .name = "build_ms", .cur = current.build_time_ms, .prev = previous.build_time_ms, .higher_better = false },
    };

    for (metrics) |m| {
        var delta = Delta{
            .old_val = m.prev,
            .new_val = m.cur,
        };
        delta.setMetric(m.name);

        if (m.cur > m.prev) {
            delta.direction = if (m.higher_better) .better else .worse;
        } else if (m.cur < m.prev) {
            delta.direction = if (m.higher_better) .worse else .better;
        } else {
            delta.direction = .neutral;
        }

        result.deltas[result.count] = delta;
        result.count += 1;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BASELINES PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn saveBaseline(baseline: *const Baseline) void {
    std.fs.cwd().makePath(".trinity") catch {};
    const file = std.fs.cwd().createFile(".trinity/baselines.json", .{ .truncate = false }) catch {
        // Create new file
        const new_file = std.fs.cwd().createFile(".trinity/baselines.json", .{}) catch return;
        defer new_file.close();
        writeBaselineJson(new_file, baseline);
        return;
    };
    defer file.close();

    // Append
    const stat = file.stat() catch return;
    file.seekTo(stat.size) catch return;
    if (stat.size > 0) {
        file.writeAll("\n") catch return;
    }
    writeBaselineJson(file, baseline);
}

fn writeBaselineJson(file: std.fs.File, baseline: *const Baseline) void {
    var buf: [512]u8 = undefined;
    const content = std.fmt.bufPrint(&buf, "{{\"version\":\"{s}\",\"date\":\"{s}\",\"specs\":{d},\"tests\":{d},\"loc\":{d},\"binaries\":{d},\"build_ms\":{d},\"timestamp\":{d}}}", .{
        baseline.versionStr(),
        baseline.dateStr(),
        baseline.specs_count,
        baseline.test_count,
        baseline.loc,
        baseline.binaries,
        baseline.build_time_ms,
        std.time.timestamp(),
    }) catch return;
    file.writeAll(content) catch return;
}

fn loadLastBaseline() ?Baseline {
    const file = std.fs.cwd().openFile(".trinity/baselines.json", .{}) catch return null;
    defer file.close();

    var buf: [65536]u8 = undefined;
    const bytes = file.readAll(&buf) catch return null;
    if (bytes == 0) return null;

    // Find the last JSON object
    const content = buf[0..bytes];
    const last_brace = std.mem.lastIndexOf(u8, content, "{") orelse return null;
    const end_brace = std.mem.indexOfPos(u8, content, last_brace, "}") orelse return null;
    const json_obj = content[last_brace .. end_brace + 1];

    var baseline = Baseline{};

    // Extract fields
    if (extractJsonString(json_obj, "\"version\":\"")) |v| baseline.setVersion(v);
    if (extractJsonString(json_obj, "\"date\":\"")) |v| baseline.setDate(v);
    if (extractJsonInt(json_obj, "\"specs\":")) |v| baseline.specs_count = v;
    if (extractJsonInt(json_obj, "\"tests\":")) |v| baseline.test_count = v;
    if (extractJsonInt(json_obj, "\"loc\":")) |v| baseline.loc = v;
    if (extractJsonInt(json_obj, "\"binaries\":")) |v| baseline.binaries = v;
    if (extractJsonInt(json_obj, "\"build_ms\":")) |v| baseline.build_time_ms = v;

    return baseline;
}

fn extractJsonString(json: []const u8, needle: []const u8) ?[]const u8 {
    const start = std.mem.indexOf(u8, json, needle) orelse return null;
    const val_start = start + needle.len;
    const val_end = std.mem.indexOfPos(u8, json, val_start, "\"") orelse return null;
    return json[val_start..val_end];
}

fn extractJsonInt(json: []const u8, needle: []const u8) ?u32 {
    const start = std.mem.indexOf(u8, json, needle) orelse return null;
    const val_start = start + needle.len;
    var end = val_start;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == val_start) return null;
    return std.fmt.parseInt(u32, json[val_start..end], 10) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER
// ═══════════════════════════════════════════════════════════════════════════════

fn renderReport(current: *const Baseline, previous: ?*const Baseline) void {
    print("\n{s}PERFORMANCE BENCHMARK{s}\n", .{ GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    // Current metrics
    print("  {s}Version:{s}   {s}\n", .{ CYAN, RESET, current.versionStr() });
    print("  {s}Specs:{s}     {d}\n", .{ CYAN, RESET, current.specs_count });
    print("  {s}Tests:{s}     {d}\n", .{ CYAN, RESET, current.test_count });
    print("  {s}LOC:{s}       {d}\n", .{ CYAN, RESET, current.loc });
    print("  {s}Binaries:{s}  {d}/{d}\n", .{ CYAN, RESET, current.binaries, current.binaries_total });
    print("  {s}Build:{s}     {d}ms\n\n", .{ CYAN, RESET, current.build_time_ms });

    // Deltas if previous exists
    if (previous) |prev| {
        const delta_result = computeDeltas(current, prev);

        print("  {s}Metric       Now      Prev     Delta{s}\n", .{ GRAY, RESET });
        print("  {s}──────────   ───────  ───────  ───────{s}\n", .{ GRAY, RESET });

        for (delta_result.deltas[0..delta_result.count]) |d| {
            const ch = d.change();
            print("  {s:<12} {d:>7}  {d:>7}  {s}{s}{d}{s}\n", .{
                d.metricStr(),
                d.new_val,
                d.old_val,
                d.direction.color(),
                d.direction.arrow(),
                ch,
                RESET,
            });
        }
        print("\n  {s}Previous: {s}{s}\n", .{ DIM, prev.versionStr(), RESET });
    } else {
        print("  {s}No previous baseline. Run 'tri bench record' to save one.{s}\n", .{ DIM, RESET });
    }

    print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn renderHistory() void {
    print("\n{s}BENCHMARK HISTORY{s}\n", .{ GOLDEN, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    const file = std.fs.cwd().openFile(".trinity/baselines.json", .{}) catch {
        print("  {s}No baselines recorded yet.{s}\n\n", .{ DIM, RESET });
        return;
    };
    defer file.close();

    var buf: [65536]u8 = undefined;
    const bytes = file.readAll(&buf) catch return;
    const content = buf[0..bytes];

    print("  {s}Version       Specs  Tests    LOC  Binaries  Build{s}\n", .{ GRAY, RESET });
    print("  {s}────────────  ─────  ─────  ─────  ────────  ─────{s}\n", .{ GRAY, RESET });

    // Parse each JSON object line
    var pos: usize = 0;
    while (pos < content.len) {
        const obj_start = std.mem.indexOfPos(u8, content, pos, "{") orelse break;
        const obj_end = std.mem.indexOfPos(u8, content, obj_start, "}") orelse break;
        const obj = content[obj_start .. obj_end + 1];

        const ver = extractJsonString(obj, "\"version\":\"") orelse "?";
        const specs = extractJsonInt(obj, "\"specs\":") orelse 0;
        const tests = extractJsonInt(obj, "\"tests\":") orelse 0;
        const loc = extractJsonInt(obj, "\"loc\":") orelse 0;
        const bins = extractJsonInt(obj, "\"binaries\":") orelse 0;
        const build = extractJsonInt(obj, "\"build_ms\":") orelse 0;

        print("  {s:<14}{d:>5}  {d:>5}  {d:>5}  {d:>8}  {d:>5}ms\n", .{
            ver, specs, tests, loc, bins, build,
        });

        pos = obj_end + 1;
    }

    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — CLI entrypoint for tri bench
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchCommand(allocator: Allocator, args: []const []const u8) void {
    const subcmd: []const u8 = if (args.len > 0) args[0] else "compare";

    if (std.mem.eql(u8, subcmd, "record")) {
        print("\n{s}Recording baseline...{s}\n", .{ DIM, RESET });
        var current = collectCurrent(allocator);
        saveBaseline(&current);
        renderReport(&current, null);
        print("  {s}Baseline saved to .trinity/baselines.json{s}\n\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, subcmd, "history")) {
        renderHistory();
    } else {
        // compare (default)
        print("\n{s}Collecting current metrics...{s}\n", .{ DIM, RESET });
        var current = collectCurrent(allocator);

        var prev = loadLastBaseline();
        const prev_ptr: ?*const Baseline = if (prev != null) &(prev.?) else null;
        renderReport(&current, prev_ptr);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Baseline defaults" {
    const b = Baseline{};
    try std.testing.expectEqual(@as(u32, 6), b.binaries_total);
    try std.testing.expectEqual(@as(u32, 0), b.specs_count);
}

test "Baseline setters" {
    var b = Baseline{};
    b.setVersion("v20260314");
    b.setDate("2026-03-14");
    try std.testing.expectEqualStrings("v20260314", b.versionStr());
    try std.testing.expectEqualStrings("2026-03-14", b.dateStr());
}

test "Delta direction higher_better" {
    var d = Delta{ .old_val = 10, .new_val = 20, .direction = .better };
    d.setMetric("specs");
    try std.testing.expectEqualStrings("+", d.direction.arrow());
    try std.testing.expectEqual(@as(i64, 10), d.change());
}

test "Delta direction lower_better" {
    const d = Delta{ .old_val = 5000, .new_val = 3000, .direction = .better };
    try std.testing.expectEqual(@as(i64, -2000), d.change());
}

test "Delta neutral" {
    const d = Delta{ .old_val = 100, .new_val = 100, .direction = .neutral };
    try std.testing.expectEqual(@as(i64, 0), d.change());
    try std.testing.expectEqualStrings("=", d.direction.arrow());
}

test "computeDeltas" {
    const current = Baseline{ .specs_count = 120, .test_count = 200, .loc = 50000, .binaries = 6, .build_time_ms = 3000 };
    const previous = Baseline{ .specs_count = 100, .test_count = 150, .loc = 45000, .binaries = 5, .build_time_ms = 4000 };

    const result = computeDeltas(&current, &previous);

    // specs: 120 > 100, higher_better → better
    try std.testing.expectEqual(Delta.Direction.better, result.deltas[0].direction);
    // tests: 200 > 150 → better
    try std.testing.expectEqual(Delta.Direction.better, result.deltas[1].direction);
    // build_ms: 3000 < 4000, lower_better → better
    try std.testing.expectEqual(Delta.Direction.better, result.deltas[4].direction);
}

test "countFiles finds specs" {
    const count = countFiles(std.testing.allocator, "specs/tri", ".tri");
    try std.testing.expect(count >= 10);
}

test "extractJsonInt" {
    const json = "{\"specs\":42,\"tests\":100}";
    try std.testing.expectEqual(@as(u32, 42), extractJsonInt(json, "\"specs\":").?);
    try std.testing.expectEqual(@as(u32, 100), extractJsonInt(json, "\"tests\":").?);
    try std.testing.expectEqual(@as(?u32, null), extractJsonInt(json, "\"missing\":"));
}

test "extractJsonString" {
    const json = "{\"version\":\"v123\",\"date\":\"2026\"}";
    try std.testing.expectEqualStrings("v123", extractJsonString(json, "\"version\":\"").?);
    try std.testing.expectEqualStrings("2026", extractJsonString(json, "\"date\":\"").?);
}
