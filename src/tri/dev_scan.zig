// @origin(spec:dev_scan.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// DEV SCAN — Scan issues + codebase for actionable work queue
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri dev scan — reads GitHub issues, dirty files, doctor violations,
// pipeline state. Produces ranked work queue for tri dev pick --smart.
//
// Part of Trinity Tech Tree: Foundation Layer [F1]
// Dependencies: none (reads external state only)
// Consumers: dev_pick.zig (L1), dev_loop.zig (I1)
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
const WHITE = colors.WHITE;
const PURPLE = colors.PURPLE;
const RESET = colors.RESET;

const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from dev_scan.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScanSource = enum {
    github_issues,
    dirty_files,
    doctor_violations,
    pipeline_failures,
    experience_similar,

    pub fn icon(self: ScanSource) []const u8 {
        return switch (self) {
            .github_issues => "GH",
            .dirty_files => "DF",
            .doctor_violations => "DR",
            .pipeline_failures => "PL",
            .experience_similar => "EX",
        };
    }

    pub fn label(self: ScanSource) []const u8 {
        return switch (self) {
            .github_issues => "issue",
            .dirty_files => "dirty",
            .doctor_violations => "doctor",
            .pipeline_failures => "pipeline",
            .experience_similar => "experience",
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
            .high => GOLDEN,
            .medium => YELLOW,
            .low => CYAN,
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
    created_at: i64 = 0,

    pub fn idStr(self: *const ScanItem) []const u8 {
        return self.id[0..self.id_len];
    }

    pub fn titleStr(self: *const ScanItem) []const u8 {
        return self.title[0..self.title_len];
    }

    pub fn setId(self: *ScanItem, text: []const u8) void {
        const len = @min(text.len, self.id.len);
        @memcpy(self.id[0..len], text[0..len]);
        self.id_len = len;
    }

    pub fn setTitle(self: *ScanItem, text: []const u8) void {
        const len = @min(text.len, self.title.len);
        @memcpy(self.title[0..len], text[0..len]);
        self.title_len = len;
    }
};

const MAX_ITEMS = 64;

pub const ScanResult = struct {
    items: [MAX_ITEMS]ScanItem = undefined,
    count: usize = 0,
    total_issues: u32 = 0,
    total_dirty: u32 = 0,
    total_doctor: u32 = 0,
    total_pipeline: u32 = 0,

    pub fn addItem(self: *ScanResult, item: ScanItem) void {
        if (self.count < MAX_ITEMS) {
            self.items[self.count] = item;
            self.count += 1;
        }
    }

    pub fn sort(self: *ScanResult) void {
        std.mem.sort(ScanItem, self.items[0..self.count], {}, struct {
            fn lessThan(_: void, a: ScanItem, b: ScanItem) bool {
                const pa = @intFromEnum(a.priority);
                const pb = @intFromEnum(b.priority);
                if (pa != pb) return pa < pb;
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
            "gh", "issue", "list", "--state", "open",
            "--json", "number,title,labels",
            "-L", "50",
        },
        .max_output_bytes = 256_000,
    }) catch {
        print("  {s}GitHub scan failed (gh not available){s}\n", .{ DIM, RESET });
        return;
    };
    defer allocator.free(gh_result.stdout);
    defer allocator.free(gh_result.stderr);

    if (gh_result.stdout.len < 3) return;

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

        const num_val = obj.get("number") orelse continue;
        const num: u32 = switch (num_val) {
            .integer => |i| @intCast(@as(u64, @bitCast(i))),
            else => continue,
        };

        const title_val = obj.get("title") orelse continue;
        const title_str = switch (title_val) {
            .string => |s| s,
            else => continue,
        };

        var priority: Priority = .backlog;
        var skip = false;
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
                        if (std.mem.eql(u8, lbl, "agent:spawn")) {
                            skip = true;
                            break;
                        }
                        if (std.mem.eql(u8, lbl, "P0") or std.mem.indexOf(u8, lbl, "critical") != null) {
                            priority = .critical;
                        } else if (std.mem.eql(u8, lbl, "P1") or std.mem.indexOf(u8, lbl, "bug") != null) {
                            if (@intFromEnum(priority) > @intFromEnum(Priority.high)) priority = .high;
                        } else if (std.mem.eql(u8, lbl, "status:in-progress")) {
                            if (@intFromEnum(priority) > @intFromEnum(Priority.high)) priority = .high;
                        } else if (std.mem.eql(u8, lbl, "status:queued") or std.mem.eql(u8, lbl, "P2") or std.mem.eql(u8, lbl, "enhancement")) {
                            if (@intFromEnum(priority) > @intFromEnum(Priority.medium)) priority = .medium;
                        } else if (std.mem.eql(u8, lbl, "P3")) {
                            if (@intFromEnum(priority) > @intFromEnum(Priority.low)) priority = .low;
                        }
                    }
                },
                else => {},
            }
        }
        if (skip) continue;

        var item = ScanItem{
            .source = .github_issues,
            .priority = priority,
            .created_at = std.time.timestamp(),
        };
        const id_str = std.fmt.bufPrint(&item.id, "#{d}", .{num}) catch continue;
        item.id_len = id_str.len;
        const copy_len = @min(title_str.len, item.title.len);
        @memcpy(item.title[0..copy_len], title_str[0..copy_len]);
        item.title_len = copy_len;

        result.addItem(item);
        result.total_issues += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN DIRTY FILES
// ═══════════════════════════════════════════════════════════════════════════════

fn scanDirty(allocator: Allocator, result: *ScanResult) void {
    const git_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "status", "--short" },
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
            .created_at = std.time.timestamp(),
        };
        const id_str = std.fmt.bufPrint(&item.id, "{d} .zig", .{dirty_zig}) catch return;
        item.id_len = id_str.len;
        item.setTitle("Uncommitted .zig files");
        result.addItem(item);
        result.total_dirty += 1;
    }

    if (dirty_spec > 0) {
        var item = ScanItem{
            .source = .dirty_files,
            .priority = .medium,
            .created_at = std.time.timestamp(),
        };
        const id_str = std.fmt.bufPrint(&item.id, "{d} .tri", .{dirty_spec}) catch return;
        item.id_len = id_str.len;
        item.setTitle("Uncommitted .tri specs");
        result.addItem(item);
        result.total_dirty += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN DOCTOR — .doctor/scan_results.json
// ═══════════════════════════════════════════════════════════════════════════════

fn scanDoctor(result: *ScanResult) void {
    const doctor_file = std.fs.cwd().openFile(".doctor/scan_results.json", .{}) catch return;
    defer doctor_file.close();

    var item = ScanItem{
        .source = .doctor_violations,
        .priority = .medium,
        .created_at = std.time.timestamp(),
    };
    item.setId("doctor");
    item.setTitle("Doctor violations pending");
    result.addItem(item);
    result.total_doctor += 1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN PIPELINE — .trinity/loop_state.json
// ═══════════════════════════════════════════════════════════════════════════════

fn scanPipeline(result: *ScanResult) void {
    const loop_file = std.fs.cwd().openFile(".trinity/loop_state.json", .{}) catch return;
    defer loop_file.close();

    var buf: [4096]u8 = undefined;
    const bytes_read = loop_file.readAll(&buf) catch return;
    const content = buf[0..bytes_read];

    if (content.len < 5) return;

    if (std.mem.indexOf(u8, content, "\"failed\"") != null or
        std.mem.indexOf(u8, content, "\"FAILED\"") != null)
    {
        var item = ScanItem{
            .source = .pipeline_failures,
            .priority = .high,
            .created_at = std.time.timestamp(),
        };
        item.setId("pipeline");
        item.setTitle("Pipeline has failed state — needs investigation");
        result.addItem(item);
        result.total_pipeline += 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER TABLE
// ═══════════════════════════════════════════════════════════════════════════════

fn renderTable(result: *const ScanResult) void {
    print("\n{s}DEV SCAN RESULTS{s}\n", .{ GOLDEN, RESET });
    print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // Summary line
    print("  {s}Issues:{s} {d}  {s}Dirty:{s} {d}  {s}Doctor:{s} {d}  {s}Pipeline:{s} {d}  {s}Total:{s} {d}\n\n", .{
        CYAN,   RESET, result.total_issues,
        YELLOW, RESET, result.total_dirty,
        PURPLE, RESET, result.total_doctor,
        RED,    RESET, result.total_pipeline,
        GREEN,  RESET, result.count,
    });

    if (result.count == 0) {
        print("  {s}No actionable items found. Codebase is clean.{s}\n\n", .{ GREEN, RESET });
        return;
    }

    print("  {s}Pri  Source  ID            Title{s}\n", .{ GRAY, RESET });
    print("  {s}---  ------  ------------  -------------------------{s}\n", .{ GRAY, RESET });

    for (result.items[0..result.count]) |item| {
        print("  {s}{s}{s}  {s}    {s:<12}  {s}\n", .{
            item.priority.color(),
            item.priority.tag(),
            RESET,
            item.source.icon(),
            item.idStr(),
            item.titleStr(),
        });
    }

    print("\n  {s}Total: {d} items{s}\n\n", .{ GRAY, result.count, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAVE RESULTS — .trinity/scan_results.json
// ═══════════════════════════════════════════════════════════════════════════════

fn saveResults(result: *const ScanResult) void {
    std.fs.cwd().makePath(".trinity") catch {};

    const file = std.fs.cwd().createFile(".trinity/scan_results.json", .{}) catch return;
    defer file.close();

    var count_buf: [16]u8 = undefined;

    file.writeAll("{\"count\":") catch return;
    const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.count}) catch return;
    file.writeAll(count_str) catch return;

    file.writeAll(",\"github\":") catch return;
    const gh_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.total_issues}) catch return;
    file.writeAll(gh_str) catch return;

    file.writeAll(",\"dirty\":") catch return;
    const d_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.total_dirty}) catch return;
    file.writeAll(d_str) catch return;

    file.writeAll(",\"doctor\":") catch return;
    const doc_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.total_doctor}) catch return;
    file.writeAll(doc_str) catch return;

    file.writeAll(",\"pipeline\":") catch return;
    const pl_str = std.fmt.bufPrint(&count_buf, "{d}", .{result.total_pipeline}) catch return;
    file.writeAll(pl_str) catch return;

    file.writeAll(",\"timestamp\":") catch return;
    const ts_str = std.fmt.bufPrint(&count_buf, "{d}", .{std.time.timestamp()}) catch return;
    file.writeAll(ts_str) catch return;

    file.writeAll("}\n") catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — CLI entrypoint for tri dev scan
// ═══════════════════════════════════════════════════════════════════════════════

/// Collect scan results without rendering (for programmatic use by dev_pick)
pub fn collectScanResults(allocator: Allocator) ScanResult {
    var result = ScanResult{};
    scanGithub(allocator, &result);
    scanDirty(allocator, &result);
    scanDoctor(&result);
    scanPipeline(&result);
    result.sort();
    return result;
}

pub fn runScanCommand(allocator: Allocator, _: []const []const u8) !void {
    print("\n{s}Scanning for actionable work...{s}\n", .{ GRAY, RESET });

    var result = collectScanResults(allocator);
    _ = &result;

    renderTable(&result);

    saveResults(&result);
    print("  {s}Results saved to .trinity/scan_results.json{s}\n\n", .{ GRAY, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ScanResult sort by priority" {
    var result = ScanResult{};

    var low_item = ScanItem{ .priority = .low };
    low_item.setTitle("low task");

    var crit_item = ScanItem{ .priority = .critical };
    crit_item.setTitle("critical task");

    var med_item = ScanItem{ .priority = .medium };
    med_item.setTitle("medium task");

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
    try std.testing.expectEqual(@as(u32, 0), result.total_issues);
}

test "ScanItem setId and setTitle" {
    var item = ScanItem{};
    item.setId("#369");
    item.setTitle("Fix the build");
    try std.testing.expectEqualStrings("#369", item.idStr());
    try std.testing.expectEqualStrings("Fix the build", item.titleStr());
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
    try std.testing.expectEqualStrings("pipeline", ScanSource.pipeline_failures.label());
    try std.testing.expectEqualStrings("experience", ScanSource.experience_similar.label());
}

test "MNL anti-pattern sort" {
    var result = ScanResult{};

    var normal = ScanItem{ .priority = .high, .fail_count = 0 };
    normal.setTitle("normal");

    var repeat_fail = ScanItem{ .priority = .high, .fail_count = 5 };
    repeat_fail.setTitle("repeat fail");

    result.addItem(repeat_fail);
    result.addItem(normal);

    result.sort();

    try std.testing.expectEqual(@as(u32, 0), result.items[0].fail_count);
    try std.testing.expectEqual(@as(u32, 5), result.items[1].fail_count);
}
