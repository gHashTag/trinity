// @origin(spec) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// DEV SCAN — Scan issues + codebase for actionable work queue
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri dev scan — reads GitHub issues, dirty files, doctor violations.
// Produces ranked work queue written to .trinity/scan_results.json.
//
// Foundation Layer [F1] — no dependencies, feeds dev_pick (L1)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const GRAY = "\x1b[90m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from dev_scan.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScanSource = enum {
    github_issues,
    dirty_files,
    doctor_violations,
    pipeline_idle,
    failing_tests,

    pub fn emoji(self: ScanSource) []const u8 {
        return switch (self) {
            .github_issues => "\xf0\x9f\x90\x99", // octopus
            .dirty_files => "\xf0\x9f\x93\x9d", // memo
            .doctor_violations => "\xf0\x9f\xa9\xba", // stethoscope
            .pipeline_idle => "\xe2\x8f\xb8\xef\xb8\x8f", // pause
            .failing_tests => "\xe2\x9d\x8c", // cross
        };
    }

    pub fn label(self: ScanSource) []const u8 {
        return switch (self) {
            .github_issues => "issue",
            .dirty_files => "dirty",
            .doctor_violations => "doctor",
            .pipeline_idle => "pipeline",
            .failing_tests => "test",
        };
    }
};

pub const Priority = enum(u8) {
    critical = 0,
    high = 1,
    medium = 2,
    low = 3,
    backlog = 4,

    pub fn color(self: Priority) []const u8 {
        return switch (self) {
            .critical => RED,
            .high => YELLOW,
            .medium => CYAN,
            .low => DIM,
            .backlog => GRAY,
        };
    }

    pub fn tag(self: Priority) []const u8 {
        return switch (self) {
            .critical => "P0",
            .high => "P1",
            .medium => "P2",
            .low => "P3",
            .backlog => "P4",
        };
    }
};

pub const ScanItem = struct {
    source: ScanSource = .github_issues,
    id: [64]u8 = undefined,
    id_len: usize = 0,
    title: [128]u8 = undefined,
    title_len: usize = 0,
    priority: Priority = .backlog,
    fail_count: u32 = 0,

    pub fn idStr(self: *const ScanItem) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn titleStr(self: *const ScanItem) []const u8 {
        return self.title[0..self.title_len];
    }
};

const MAX_ITEMS = 64;

pub const ScanResult = struct {
    items: [MAX_ITEMS]ScanItem = undefined,
    count: usize = 0,
    github_count: u32 = 0,
    dirty_count: u32 = 0,
    doctor_count: u32 = 0,
    test_count: u32 = 0,

    pub fn addItem(self: *ScanResult, item: ScanItem) void {
        if (self.count < MAX_ITEMS) {
            self.items[self.count] = item;
            self.count += 1;
        }
    }

    pub fn sort(self: *ScanResult) void {
        std.mem.sort(ScanItem, self.items[0..self.count], {}, struct {
            fn lessThan(_: void, a: ScanItem, b: ScanItem) bool {
                // Sort by priority first (critical=0 < backlog=4)
                const pa = @intFromEnum(a.priority);
                const pb = @intFromEnum(b.priority);
                if (pa != pb) return pa < pb;
                // Then by fail_count ascending (avoid repeated failures)
                return a.fail_count < b.fail_count;
            }
        }.lessThan);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN GITHUB ISSUES
// ═══════════════════════════════════════════════════════════════════════════════

fn scanGithub(allocator: Allocator, result: *ScanResult) void {
    const gh_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "gh", "issue", "list", "--json", "number,title,labels", "--limit", "50", "--repo", "gHashTag/trinity",
        },
        .max_output_bytes = 256_000,
    }) catch {
        print("  {s}GitHub scan failed (gh not available){s}\n", .{ DIM, RESET });
        return;
    };
    defer allocator.free(gh_result.stdout);
    defer allocator.free(gh_result.stderr);

    if (gh_result.stdout.len < 3) return; // empty []

    // Parse JSON array of issues
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, gh_result.stdout, .{}) catch {
        print("  {s}GitHub JSON parse failed{s}\n", .{ DIM, RESET });
        return;
    };
    defer parsed.deinit();

    const issues = switch (parsed.value) {
        .array => |a| a,
        else => return,
    };

    for (issues.items) |issue| {
        const obj = switch (issue) {
            .object => |o| o,
            else => continue,
        };

        // Get number
        const num_val = obj.get("number") orelse continue;
        const num: u32 = switch (num_val) {
            .integer => |i| @intCast(@as(u64, @bitCast(i))),
            else => continue,
        };

        // Get title
        const title_val = obj.get("title") orelse continue;
        const title_str = switch (title_val) {
            .string => |s| s,
            else => continue,
        };

        // Determine priority from labels
        var priority: Priority = .backlog;
        if (obj.get("labels")) |labels_val| {
            switch (labels_val) {
                .array => |labels| {
                    for (labels.items) |label_item| {
                        const lbl = switch (label_item) {
                            .object => |lo| blk: {
                                const name_val = lo.get("name") orelse continue;
                                break :blk switch (name_val) {
                                    .string => |s| s,
                                    else => continue,
                                };
                            },
                            else => continue,
                        };
                        if (std.mem.eql(u8, lbl, "P0") or std.mem.indexOf(u8, lbl, "critical") != null) {
                            priority = .critical;
                        } else if (std.mem.eql(u8, lbl, "P1") or std.mem.indexOf(u8, lbl, "bug") != null) {
                            if (@intFromEnum(priority) > @intFromEnum(Priority.high)) priority = .high;
                        } else if (std.mem.eql(u8, lbl, "enhancement") or std.mem.eql(u8, lbl, "easy")) {
                            if (@intFromEnum(priority) > @intFromEnum(Priority.medium)) priority = .medium;
                        }
                    }
                },
                else => {},
            }
        }

        var item = ScanItem{
            .source = .github_issues,
            .priority = priority,
        };
        // Set id
        const id_str = std.fmt.bufPrint(&item.id, "#{d}", .{num}) catch continue;
        item.id_len = id_str.len;
        // Set title (truncate)
        const copy_len = @min(title_str.len, item.title.len);
        @memcpy(item.title[0..copy_len], title_str[0..copy_len]);
        item.title_len = copy_len;

        result.addItem(item);
        result.github_count += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN DIRTY FILES
// ═══════════════════════════════════════════════════════════════════════════════

fn scanDirty(allocator: Allocator, result: *ScanResult) void {
    const git_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "status", "--porcelain" },
        .max_output_bytes = 65536,
    }) catch return;
    defer allocator.free(git_result.stdout);
    defer allocator.free(git_result.stderr);

    if (git_result.stdout.len == 0) return;

    var dirty_zig: u32 = 0;
    var dirty_spec: u32 = 0;

    var lines = std.mem.splitScalar(u8, git_result.stdout, '\n');
    while (lines.next()) |line| {
        if (line.len < 4) continue;
        const path = std.mem.trimLeft(u8, line[2..], " ");
        if (std.mem.endsWith(u8, path, ".zig")) {
            dirty_zig += 1;
        } else if (std.mem.endsWith(u8, path, ".tri")) {
            dirty_spec += 1;
        }
    }

    if (dirty_zig > 0) {
        var item = ScanItem{
            .source = .dirty_files,
            .priority = .high,
        };
        const id_str = std.fmt.bufPrint(&item.id, "{d} .zig", .{dirty_zig}) catch return;
        item.id_len = id_str.len;
        const t = "Uncommitted .zig files";
        @memcpy(item.title[0..t.len], t);
        item.title_len = t.len;
        result.addItem(item);
        result.dirty_count += 1;
    }

    if (dirty_spec > 0) {
        var item = ScanItem{
            .source = .dirty_files,
            .priority = .medium,
        };
        const id_str = std.fmt.bufPrint(&item.id, "{d} .tri", .{dirty_spec}) catch return;
        item.id_len = id_str.len;
        const t = "Uncommitted .tri specs";
        @memcpy(item.title[0..t.len], t);
        item.title_len = t.len;
        result.addItem(item);
        result.dirty_count += 1;
    }

}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN BUILD/TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn scanBuild(allocator: Allocator, result: *ScanResult) void {
    const build_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "build" },
        .max_output_bytes = 65536,
    }) catch return;
    defer allocator.free(build_result.stdout);
    defer allocator.free(build_result.stderr);

    if (build_result.term.Exited != 0) {
        var item = ScanItem{
            .source = .failing_tests,
            .priority = .critical,
        };
        const t = "zig build FAILS";
        @memcpy(item.title[0..t.len], t);
        item.title_len = t.len;
        const id = "build";
        @memcpy(item.id[0..id.len], id);
        item.id_len = id.len;
        result.addItem(item);
        result.test_count += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN DOCTOR
// ═══════════════════════════════════════════════════════════════════════════════

fn scanDoctor(result: *ScanResult) void {
    const doctor_file = std.fs.cwd().openFile(".doctor/scan_results.json", .{}) catch return;
    defer doctor_file.close();

    // If file exists, there are doctor findings
    var item = ScanItem{
        .source = .doctor_violations,
        .priority = .medium,
    };
    const t = "Doctor violations pending";
    @memcpy(item.title[0..t.len], t);
    item.title_len = t.len;
    const id = "doctor";
    @memcpy(item.id[0..id.len], id);
    item.id_len = id.len;
    result.addItem(item);
    result.doctor_count += 1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER TABLE
// ═══════════════════════════════════════════════════════════════════════════════

fn renderTable(result: *const ScanResult) void {
    print("\n{s}DEV SCAN RESULTS{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    if (result.count == 0) {
        print("  {s}No actionable items found. All clear.{s}\n\n", .{ GREEN, RESET });
        return;
    }

    print("  {s}Pri  Source    ID            Title{s}\n", .{ DIM, RESET });
    print("  {s}───  ──────   ──────────    ─────────────────────────{s}\n", .{ DIM, RESET });

    for (result.items[0..result.count]) |item| {
        print("  {s}{s}{s}  {s}  {s:<12}  {s}\n", .{
            item.priority.color(),
            item.priority.tag(),
            RESET,
            item.source.emoji(),
            item.idStr(),
            item.titleStr(),
        });
    }

    print("\n  {s}Total: {d} items{s} | ", .{ DIM, result.count, RESET });
    print("Issues: {d} | Dirty: {d} | Doctor: {d} | Tests: {d}\n\n", .{
        result.github_count, result.dirty_count, result.doctor_count, result.test_count,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVE RESULTS
// ═══════════════════════════════════════════════════════════════════════════════

fn saveResults(result: *const ScanResult) void {
    // Ensure .trinity directory exists
    std.fs.cwd().makePath(".trinity") catch {};

    const file = std.fs.cwd().createFile(".trinity/scan_results.json", .{}) catch return;
    defer file.close();

    // Write minimal JSON
    file.writeAll("{\"count\":") catch return;
    var count_buf: [16]u8 = undefined;
    const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.count}) catch return;
    file.writeAll(count_str) catch return;
    file.writeAll(",\"github\":") catch return;
    const gh_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.github_count}) catch return;
    file.writeAll(gh_str) catch return;
    file.writeAll(",\"dirty\":") catch return;
    const d_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.dirty_count}) catch return;
    file.writeAll(d_str) catch return;
    file.writeAll(",\"doctor\":") catch return;
    const doc_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.doctor_count}) catch return;
    file.writeAll(doc_str) catch return;
    file.writeAll(",\"tests\":") catch return;
    const t_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.test_count}) catch return;
    file.writeAll(t_str) catch return;
    file.writeAll("}\n") catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runScanCommand(allocator: Allocator) void {
    var result = ScanResult{};

    print("  Scanning GitHub issues...\n", .{});
    scanGithub(allocator, &result);

    print("  Scanning dirty files...\n", .{});
    scanDirty(allocator, &result);

    print("  Scanning build status...\n", .{});
    scanBuild(allocator, &result);

    print("  Scanning doctor violations...\n", .{});
    scanDoctor(&result);

    // Sort by priority
    result.sort();

    // Render
    renderTable(&result);

    // Save
    saveResults(&result);
    print("  {s}Results saved to .trinity/scan_results.json{s}\n\n", .{ DIM, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ScanResult sort by priority" {
    var result = ScanResult{};

    var low_item = ScanItem{ .priority = .low };
    const low_t = "low task";
    @memcpy(low_item.title[0..low_t.len], low_t);
    low_item.title_len = low_t.len;

    var crit_item = ScanItem{ .priority = .critical };
    const crit_t = "critical task";
    @memcpy(crit_item.title[0..crit_t.len], crit_t);
    crit_item.title_len = crit_t.len;

    var med_item = ScanItem{ .priority = .medium };
    const med_t = "medium task";
    @memcpy(med_item.title[0..med_t.len], med_t);
    med_item.title_len = med_t.len;

    result.addItem(low_item);
    result.addItem(crit_item);
    result.addItem(med_item);

    result.sort();

    try std.testing.expectEqual(Priority.critical, result.items[0].priority);
    try std.testing.expectEqual(Priority.medium, result.items[1].priority);
    try std.testing.expectEqual(Priority.low, result.items[2].priority);
}

test "ScanResult empty" {
    const result = ScanResult{};
    try std.testing.expectEqual(@as(usize, 0), result.count);
    try std.testing.expectEqual(@as(u32, 0), result.github_count);
}

test "ScanItem idStr" {
    var item = ScanItem{};
    const id = "#369";
    @memcpy(item.id[0..id.len], id);
    item.id_len = id.len;
    try std.testing.expectEqualStrings("#369", item.idStr());
}

test "Priority ordering" {
    try std.testing.expect(@intFromEnum(Priority.critical) < @intFromEnum(Priority.high));
    try std.testing.expect(@intFromEnum(Priority.high) < @intFromEnum(Priority.medium));
    try std.testing.expect(@intFromEnum(Priority.medium) < @intFromEnum(Priority.low));
    try std.testing.expect(@intFromEnum(Priority.low) < @intFromEnum(Priority.backlog));
}

test "ScanSource labels" {
    try std.testing.expectEqualStrings("issue", ScanSource.github_issues.label());
    try std.testing.expectEqualStrings("dirty", ScanSource.dirty_files.label());
    try std.testing.expectEqualStrings("doctor", ScanSource.doctor_violations.label());
    try std.testing.expectEqualStrings("test", ScanSource.failing_tests.label());
}

test "MNL anti-pattern sort" {
    var result = ScanResult{};

    var normal = ScanItem{ .priority = .high, .fail_count = 0 };
    const n_t = "normal";
    @memcpy(normal.title[0..n_t.len], n_t);
    normal.title_len = n_t.len;

    var repeat_fail = ScanItem{ .priority = .high, .fail_count = 5 };
    const rf_t = "repeat fail";
    @memcpy(repeat_fail.title[0..rf_t.len], rf_t);
    repeat_fail.title_len = rf_t.len;

    result.addItem(repeat_fail);
    result.addItem(normal);

    result.sort();

    // Same priority — lower fail_count comes first
    try std.testing.expectEqual(@as(u32, 0), result.items[0].fail_count);
    try std.testing.expectEqual(@as(u32, 5), result.items[1].fail_count);
}
