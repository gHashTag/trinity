// DOGFOOD-1: No More Zig — TRI-27 Dogfooding Wave 1
// Enforcement: Zig is now TTT only (Temple/Tool/Transport)
// New business logic MUST be written in .t27 or .tri
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;
const print = std.debug.print;

const CANON_MAP_PATH = ".trinity/canonmap.json";

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// DOGFOOD SCOPE — Modules that must be .t27 only
// ═══════════════════════════════════════════════════════════════════════════════

pub const DogfoodScope = enum {
    tri27_only, // Must be .t27 only (Zig shell wrapper OK)
    zig_shell_ok, // Zig shell wrapper allowed
    hybrid, // Both allowed (transition mode)
    zig_ttt, // Zig = Temple/Tool/Transport only
};

pub const DogfoodFile = struct {
    path: []const u8,
    scope: DogfoodScope,
    exists: bool = false,
    has_t27_equivalent: bool = false,
    zig_loc: usize = 0,
    violates: bool = false,
    wave: u32 = 0,
};

pub const Violation = struct {
    path: []const u8,
    reason: []const u8,
};

pub const DogfoodSet = struct {
    files: []DogfoodFile,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !DogfoodSet {
        var list = std.ArrayListUnmanaged(DogfoodFile){};

        // Wave 1 targets (3 modules, ~1,262 LOC total)
        // These MUST have .t27 equivalents
        try list.append(allocator, DogfoodFile{
            .path = "src/tri/reticular_raphe.zig",
            .scope = .tri27_only,
            .wave = 1,
        });
        try list.append(allocator, DogfoodFile{
            .path = "src/queen/phoenix_medulla.zig",
            .scope = .tri27_only,
            .wave = 1,
        });
        try list.append(allocator, DogfoodFile{
            .path = "src/queen/queen_vmpfc.zig",
            .scope = .tri27_only,
            .wave = 1,
        });

        // Shell wrappers (allowed, but must be _shell.zig)
        try list.append(allocator, DogfoodFile{
            .path = "src/tri27/reticular_raphe_shell.zig",
            .scope = .zig_shell_ok,
            .wave = 1,
        });
        try list.append(allocator, DogfoodFile{
            .path = "src/tri27/phoenix_medulla_shell.zig",
            .scope = .zig_shell_ok,
            .wave = 1,
        });
        try list.append(allocator, DogfoodFile{
            .path = "src/tri27/queen_vmpfc_shell.zig",
            .scope = .zig_shell_ok,
            .wave = 1,
        });

        return .{
            .files = try list.toOwnedSlice(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DogfoodSet) void {
        self.allocator.free(self.files);
    }

    pub fn scan(self: *DogfoodSet) !void {
        for (self.files) |*f| {
            if (fs.cwd().openFile(f.path, .{})) |file| {
                file.close();
                f.exists = true;
                f.zig_loc = getLoc(f.path);

                // Check if .t27 equivalent exists
                const t27_path = getT27Path(f.path);
                if (fs.cwd().openFile(t27_path, .{})) |t27_file| {
                    t27_file.close();
                    f.has_t27_equivalent = true;
                } else |_| {}
            } else |_| {}
        }
    }

    pub fn checkNewZig(self: *DogfoodSet, staged_files: [][]const u8) ![]Violation {
        var violations = std.ArrayList(Violation).initCapacity(self.allocator, 0) catch @panic("OOM");
        errdefer {
            for (violations.items) |v| {
                self.allocator.free(v.path);
                self.allocator.free(v.reason);
            }
            violations.deinit(self.allocator);
        }

        for (staged_files) |file_path| {
            const trimmed = std.mem.trimRight(u8, file_path, "\r\n");
            if (trimmed.len == 0) continue;

            // Check if file is in DogfoodSet
            for (self.files) |f| {
                if (std.mem.eql(u8, f.path, trimmed)) {
                    if (f.scope == .tri27_only and f.exists and !f.has_t27_equivalent) {
                        // NEW Zig file in tri27_only zone WITHOUT .t27 equivalent
                        const path_copy = try self.allocator.dupe(u8, f.path);
                        errdefer self.allocator.free(path_copy);

                        const reason = try std.fmt.allocPrint(
                            self.allocator,
                            "New Zig file in tri27_only zone. Write .t27 or use _shell.zig wrapper instead.",
                            .{},
                        );
                        errdefer self.allocator.free(reason);

                        try violations.append(self.allocator, Violation{
                            .path = path_copy,
                            .reason = reason,
                        });
                    }
                    break;
                }
            }

            // Also check: NEW .zig files in protected zones (src/queen/, src/brain/, src/hslm/)
            if (std.mem.endsWith(u8, trimmed, ".zig")) {
                if (isInProtectedZone(trimmed)) {
                    // Check if it's a shell wrapper (allowed)
                    if (!std.mem.endsWith(u8, trimmed, "_shell.zig")) {
                        // Check if .t27 equivalent exists
                        const t27_path = getT27Path(trimmed);
                        var has_t27 = false;
                        if (fs.cwd().openFile(t27_path, .{})) |file| {
                            file.close();
                            has_t27 = true;
                        } else |_| {}

                        if (!has_t27) {
                            const path_copy = try self.allocator.dupe(u8, trimmed);
                            errdefer self.allocator.free(path_copy);

                            const reason = try std.fmt.allocPrint(
                                self.allocator,
                                "DOGFOOD VIOLATION: Zig business logic forbidden. Write .t27 or use _shell.zig wrapper.",
                                .{},
                            );
                            errdefer self.allocator.free(reason);

                            try violations.append(self.allocator, Violation{
                                .path = path_copy,
                                .reason = reason,
                            });
                        }
                    }
                }
            }
        }

        return violations.toOwnedSlice(self.allocator);
    }

    pub fn report(self: *const DogfoodSet) void {
        print("\n{s}🐕 DOGFOOD STATUS: Wave 1{s}\n", .{ BOLD, RESET });
        print("{s}═════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

        var converted: usize = 0;
        var total: usize = 0;

        // Group by module
        print("{s}Zone R (Reticula):{s} reticular_raphe\n", .{ CYAN, RESET });
        if (self.files[0].has_t27_equivalent) {
            print("  {s}✓{s} Converted to .t27\n", .{ GREEN, RESET });
            converted += 1;
        } else {
            print("  {s}✗{s} Missing .t27 equivalent\n", .{ RED, RESET });
        }
        total += 1;
        print("\n", .{});

        print("{s}Zone P (Phoenix):{s} phoenix_medulla\n", .{ CYAN, RESET });
        if (self.files[1].has_t27_equivalent) {
            print("  {s}✓{s} Converted to .t27\n", .{ GREEN, RESET });
            converted += 1;
        } else {
            print("  {s}✗{s} Missing .t27 equivalent\n", .{ RED, RESET });
        }
        total += 1;
        print("\n", .{});

        print("{s}Zone Q (Queen):{s} queen_vmpfc\n", .{ CYAN, RESET });
        if (self.files[2].has_t27_equivalent) {
            print("  {s}✓{s} Converted to .t27\n", .{ GREEN, RESET });
            converted += 1;
        } else {
            print("  {s}✗{s} Missing .t27 equivalent\n", .{ RED, RESET });
        }
        total += 1;
        print("\n", .{});

        print("Progress: {d}/{d} ({d:.0}%)\n", .{ converted, total, @as(f32, @floatFromInt(converted)) * 100.0 / @as(f32, @floatFromInt(total)) });
        print("\n", .{});
    }
};

fn isInProtectedZone(path: []const u8) bool {
    const zones = [_][]const u8{
        "src/queen/",
        "src/brain/",
        "src/hslm/",
    };

    for (zones) |zone| {
        if (std.mem.indexOf(u8, path, zone) != null) {
            return true;
        }
    }
    return false;
}

fn getT27Path(zig_path: []const u8) []const u8 {
    // Convert src/queen/queen_vmpfc.zig → src/tri27/queen_vmpfc.t27
    // Convert src/tri/reticular_raphe.zig → src/tri27/reticular_raphe.t27
    // Convert src/queen/phoenix_medulla.zig → src/tri27/phoenix_medulla.t27

    if (std.mem.endsWith(u8, zig_path, "queen_vmpfc.zig")) {
        return "src/tri27/queen_vmpfc.t27";
    } else if (std.mem.endsWith(u8, zig_path, "reticular_raphe.zig")) {
        return "src/tri27/reticular_raphe.t27";
    } else if (std.mem.endsWith(u8, zig_path, "phoenix_medulla.zig")) {
        return "src/tri27/phoenix_medulla.t27";
    }

    // Default: replace .zig with .t27 in same directory
    var result: [256]u8 = undefined;
    const dot_index = std.mem.lastIndexOfScalar(u8, zig_path, '.');
    if (dot_index != null) {
        @memcpy(result[0..dot_index.?], zig_path[0..dot_index.?]);
        @memcpy(result[dot_index.?..][0..4], ".t27");
        return result[0 .. dot_index.? + 4];
    }

    return zig_path; // Fallback
}

fn getLoc(path: []const u8) usize {
    if (fs.cwd().readFileAlloc(std.heap.page_allocator, path, 1024 * 1024)) |content| {
        defer std.heap.page_allocator.free(content);
        // Count non-empty, non-comment lines
        var lines: usize = 0;
        var iter = std.mem.splitScalar(u8, content, '\n');
        while (iter.next()) |line| {
            const trimmed = std.mem.trimLeft(u8, line, " \t");
            if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "//") and !std.mem.startsWith(u8, trimmed, "#")) {
                lines += 1;
            }
        }
        return lines;
    } else |_| {
        return 0;
    }
}

pub const DogfoodError = error{
    DogfoodViolation,
    PreCommitFailed,
};
