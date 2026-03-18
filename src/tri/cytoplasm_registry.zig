// ═══════════════════════════════════════════════════════════════════════════════
// CYTOPLASM REGISTRY MANAGEMENT — validate, repair, backup, restore
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");

const Allocator = std.mem.Allocator;

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;

const CORE_VERSION = "1.0.0";

pub fn runRegistry(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}tri cell registry{s} — Registry management commands\n\n", .{ GOLDEN, RESET });
        std.debug.print("  {s}validate{s}    Check registry consistency\n", .{ GREEN, RESET });
        std.debug.print("  {s}repair{s}      Fix inconsistencies\n", .{ GREEN, RESET });
        std.debug.print("  {s}backup{s}      Create timestamped backup\n", .{ GREEN, RESET });
        std.debug.print("  {s}restore <ts>{s} Restore from backup (YYYYMMDD-HHMMSS)\n", .{ GREEN, RESET });
        std.debug.print("  {s}list{s}        List available backups\n", .{ GREEN, RESET });
        return;
    }

    const sub = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "validate")) return runRegistryValidate(allocator);
    if (std.mem.eql(u8, sub, "repair")) return runRegistryRepair(allocator);
    if (std.mem.eql(u8, sub, "backup")) return runRegistryBackup(allocator, rest);
    if (std.mem.eql(u8, sub, "restore")) return runRegistryRestore(allocator, rest);
    if (std.mem.eql(u8, sub, "list")) return runRegistryListBackups(allocator);

    std.debug.print("{s}ERROR{s}: Unknown registry subcommand: {s}\n", .{ RED, RESET, sub });
}

fn loadRegistry(allocator: Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, "data/cells/registry.json", 262144) catch |err| {
        std.debug.print("{s}ERROR{s}: Cannot read data/cells/registry.json: {}\n", .{ RED, RESET, err });
        return err;
    };
}

fn jsonStr(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj.get(key)) |v| {
        return switch (v) {
            .string => |s| s,
            else => "",
        };
    }
    return "";
}

const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    fn parse(str: []const u8) ?Version {
        var iter = std.mem.splitScalar(u8, str, '.');
        const major_str = iter.next() orelse return null;
        const minor_str = iter.next() orelse return null;
        var patch_str = iter.next() orelse "0";
        if (std.mem.indexOf(u8, patch_str, "-")) |dash| patch_str = patch_str[0..dash];
        return .{
            .major = std.fmt.parseInt(u32, major_str, 10) catch return null,
            .minor = std.fmt.parseInt(u32, minor_str, 10) catch return null,
            .patch = std.fmt.parseInt(u32, patch_str, 10) catch return null,
        };
    }
};

fn runRegistryValidate(allocator: Allocator) !void {
    std.debug.print("\n{s}🔍 REGISTRY VALIDATE{s} — Checking registry consistency\n\n", .{ CYAN, RESET });

    const registry = loadRegistry(allocator) catch {
        std.debug.print("  {s}✗ FAIL{s}: Cannot read registry.json\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("  {s}✗ FAIL{s}: Invalid JSON syntax\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    var issues: usize = 0;
    var warnings: usize = 0;

    const required_keys = [_][]const u8{ "version", "updated", "core_version", "cells" };
    for (required_keys) |key| {
        if (root.get(key) == null) {
            std.debug.print("  {s}✗ ERROR{s}: Missing top-level key '{s}'\n", .{ RED, RESET, key });
            issues += 1;
        }
    }

    const cells_val = root.get("cells") orelse {
        std.debug.print("  {s}✗ ERROR{s}: No cells array found\n", .{ RED, RESET });
        return;
    };

    const cells = switch (cells_val) {
        .array => |a| a.items,
        else => {
            std.debug.print("  {s}✗ ERROR{s}: 'cells' is not an array\n", .{ RED, RESET });
            return;
        },
    };

    std.debug.print("  Checking {d} cells...\n\n", .{cells.len});

    var cell_ids = std.StringHashMap(void).init(allocator);
    defer cell_ids.deinit();

    for (cells, 0..) |cell_val, idx| {
        const cell = switch (cell_val) {
            .object => |o| o,
            else => {
                std.debug.print("  [{d:3}] {s}✗ ERROR{s}: Cell is not an object\n", .{ idx, RED, RESET });
                issues += 1;
                continue;
            },
        };

        const required_fields = [_][]const u8{ "id", "path", "version", "kind", "status", "files", "tests", "enabled" };
        for (required_fields) |field| {
            if (cell.get(field) == null) {
                std.debug.print("  [{d:3}] {s}⚠ WARNING{s}: Missing field '{s}'\n", .{ idx, YELLOW, RESET, field });
                warnings += 1;
            }
        }

        const id = jsonStr(cell, "id");
        if (id.len > 0) {
            const gop = try cell_ids.getOrPut(id);
            if (gop.found_existing) {
                std.debug.print("  [{d:3}] {s}✗ ERROR{s}: Duplicate cell ID '{s}'\n", .{ idx, RED, RESET, id });
                issues += 1;
            }
        }

        const path = jsonStr(cell, "path");
        if (path.len > 0) {
            const cell_tri = std.fmt.allocPrint(allocator, "{s}/cell.tri", .{path}) catch continue;
            defer allocator.free(cell_tri);
            if (std.fs.cwd().openFile(cell_tri, .{})) |_| {} else |err| {
                std.debug.print("  [{d:3}] {s}⚠ WARNING{s}: Path '{s}' inaccessible ({})\n", .{ idx, YELLOW, RESET, path, err });
                warnings += 1;
            }
        }

        const version = jsonStr(cell, "version");
        if (version.len > 0 and Version.parse(version) == null) {
            std.debug.print("  [{d:3}] {s}⚠ WARNING{s}: Invalid version format '{s}'\n", .{ idx, YELLOW, RESET, version });
            warnings += 1;
        }

        const status = jsonStr(cell, "status");
        if (status.len > 0) {
            const valid_statuses = [_][]const u8{ "stable", "experimental", "deprecated", "broken" };
            var valid = false;
            for (valid_statuses) |s| {
                if (std.mem.eql(u8, status, s)) valid = true;
            }
            if (!valid) {
                std.debug.print("  [{d:3}] {s}⚠ WARNING{s}: Unknown status '{s}'\n", .{ idx, YELLOW, RESET, status });
                warnings += 1;
            }
        }

        const kind = jsonStr(cell, "kind");
        if (kind.len > 0) {
            const valid_kinds = [_][]const u8{ "library", "tool", "agent", "service", "binary" };
            var valid = false;
            for (valid_kinds) |k| {
                if (std.mem.eql(u8, kind, k)) valid = true;
            }
            if (!valid) {
                std.debug.print("  [{d:3}] {s}⚠ WARNING{s}: Unknown kind '{s}'\n", .{ idx, YELLOW, RESET, kind });
                warnings += 1;
            }
        }
    }

    std.debug.print("\n{s}Validation Summary:{s}\n", .{ CYAN, RESET });
    if (issues == 0 and warnings == 0) {
        std.debug.print("  {s}✓ PASS{s}: No issues found ({d} cells)\n\n", .{ GREEN, RESET, cells.len });
    } else {
        std.debug.print("  {s}✗ Errors:{s}  {d}\n", .{ RED, RESET, issues });
        std.debug.print("  {s}⚠ Warnings:{s} {d}\n\n", .{ YELLOW, RESET, warnings });
        if (issues > 0) {
            std.debug.print("  Run: {s}tri cell registry repair{s} to fix errors\n\n", .{ GREEN, RESET });
        }
    }
}

fn runRegistryRepair(allocator: Allocator) !void {
    std.debug.print("\n{s}🔧 REGISTRY REPAIR{s} — Fixing inconsistencies\n\n", .{ YELLOW, RESET });

    const registry = loadRegistry(allocator) catch {
        std.debug.print("  {s}✗ FAIL{s}: Cannot read registry.json\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(registry);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("  {s}✗ FAIL{s}: Invalid JSON, cannot repair\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = &parsed.value.object;
    var repairs: usize = 0;

    if (root.get("version") == null) {
        try root.put("version", .{ .string = "1.0.0" });
        std.debug.print("  {s}+ Added{s}: missing 'version' key\n", .{ GREEN, RESET });
        repairs += 1;
    }
    if (root.get("updated") == null) {
        const now = try getCurrentTimestamp(allocator);
        defer allocator.free(now);
        try root.put("updated", .{ .string = now });
        std.debug.print("  {s}+ Added{s}: missing 'updated' key\n", .{ GREEN, RESET });
        repairs += 1;
    }
    if (root.get("core_version") == null) {
        try root.put("core_version", .{ .string = CORE_VERSION });
        std.debug.print("  {s}+ Added{s}: missing 'core_version' key\n", .{ GREEN, RESET });
        repairs += 1;
    }

    var cells = switch (root.get("cells") orelse blk: {
        try root.put("cells", .{ .array = &[_]std.json.Value{} });
        std.debug.print("  {s}+ Added{s}: empty cells array\n", .{ GREEN, RESET });
        repairs += 1;
        break :blk &[_]std.json.Value{};
    }) {
        .array => |*a| a,
        else => return,
    };

    var seen_ids = std.StringHashMap(void).init(allocator);
    defer seen_ids.deinit();

    var i: usize = 0;
    while (i < cells.items.len) {
        const cell = switch (cells.items[i]) {
            .object => |*o| o,
            else => {
                _ = cells.orderedRemove(i);
                std.debug.print("  {s}- Removed{s}: invalid cell entry at index {d}\n", .{ YELLOW, RESET, i });
                repairs += 1;
                continue;
            },
        };

        const id = jsonStr(cell.*, "id");
        if (id.len == 0) {
            _ = cells.orderedRemove(i);
            std.debug.print("  {s}- Removed{s}: cell without ID at index {d}\n", .{ YELLOW, RESET, i });
            repairs += 1;
            continue;
        }

        const gop = try seen_ids.getOrPut(id);
        if (gop.found_existing) {
            _ = cells.orderedRemove(i);
            std.debug.print("  {s}- Removed{s}: duplicate cell '{s}'\n", .{ YELLOW, RESET, id });
            repairs += 1;
            continue;
        }

        if (cell.get("enabled") == null) {
            try cell.put("enabled", .{ .bool = true });
            repairs += 1;
        }
        if (cell.get("status") == null) {
            try cell.put("status", .{ .string = "experimental" });
            repairs += 1;
        }
        if (cell.get("files") == null) {
            try cell.put("files", .{ .integer = 0 });
            repairs += 1;
        }
        if (cell.get("tests") == null) {
            try cell.put("tests", .{ .integer = 0 });
            repairs += 1;
        }

        i += 1;
    }

    if (repairs > 0) {
        const registry_path = "data/cells/registry.json";
        const file = try std.fs.cwd().createFile(registry_path, .{ .read = true });
        defer file.close();

        try std.json.stringify(parsed.value, .{ .whitespace = .indent_2 }, file.writer());
        std.debug.print("\n  {s}✓ Repaired{s}: {s} ({d} fixes applied)\n\n", .{ GREEN, RESET, registry_path, repairs });
    } else {
        std.debug.print("  {s}✓ No repairs needed{s}\n\n", .{ GREEN, RESET });
    }
}

fn runRegistryBackup(allocator: Allocator, args: []const u8) !void {
    _ = args;

    std.debug.print("\n{s}💾 REGISTRY BACKUP{s} — Creating timestamped backup\n\n", .{ GOLDEN, RESET });

    const backup_dir = "data/cells/backups";
    try std.fs.cwd().makePath(backup_dir);

    const timestamp = try getCurrentTimestamp(allocator);
    defer allocator.free(timestamp);

    const backup_filename = try std.fmt.allocPrint(allocator, "{s}/registry-{s}.json", .{ backup_dir, timestamp });
    defer allocator.free(backup_filename);

    const registry = loadRegistry(allocator) catch {
        std.debug.print("  {s}✗ FAIL{s}: Cannot read registry.json\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(registry);

    const file = try std.fs.cwd().createFile(backup_filename, .{ .read = true });
    defer file.close();

    _ = try file.write(registry);

    const stat = try file.stat();
    const size_kb = @as(f64, @floatFromInt(stat.size)) / 1024.0;

    std.debug.print("  {s}✓ Backup created:{s} {s}\n", .{ GREEN, RESET, backup_filename });
    std.debug.print("  Size: {d:.1} KB\n\n", .{size_kb});
    std.debug.print("  Restore with: {s}tri cell registry restore {s}{s}\n\n", .{ GREEN, timestamp, RESET });
}

fn runRegistryListBackups(allocator: Allocator) !void {
    std.debug.print("\n{s}📋 REGISTRY BACKUPS{s} — Available backups\n\n", .{ CYAN, RESET });

    const backup_dir = std.fs.cwd().openDir("data/cells/backups", .{ .iterate = true }) catch {
        std.debug.print("  No backups directory found\n\n");
        return;
    };
    defer backup_dir.close();

    var backups = std.ArrayList(struct {
        filename: []const u8,
        timestamp: []const u8,
        size: u64,
    }).init(allocator);
    defer {
        for (backups.items) |b| {
            allocator.free(b.filename);
            allocator.free(b.timestamp);
        }
        backups.deinit();
    }

    var iter = backup_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.startsWith(u8, entry.name, "registry-") and std.mem.endsWith(u8, entry.name, ".json")) {
            const ts_start = "registry-".len;
            const ts_end = entry.name.len - ".json".len;
            if (ts_end > ts_start) {
                const timestamp = try allocator.dupe(u8, entry.name[ts_start..ts_end]);
                const stat = try backup_dir.statFile(entry.name);
                try backups.append(.{
                    .filename = try allocator.dupe(u8, entry.name),
                    .timestamp = timestamp,
                    .size = stat.size,
                });
            }
        }
    }

    if (backups.items.len == 0) {
        std.debug.print("  No backups found\n\n");
        return;
    }

    std.sort.insertion(struct {
        filename: []const u8,
        timestamp: []const u8,
        size: u64,
    }, backups.items, {}, struct {
        fn lessThan(_: void, a: @FieldType(@This(), "Item"), b: @FieldType(@This(), "Item")) bool {
            return std.mem.order(u8, a.timestamp, b.timestamp) == .gt;
        }
    }.lessThan);

    std.debug.print("  {s}Filename{s}                        {s}Size{s}      {s}Timestamp{s}\n", .{ CYAN, RESET, CYAN, RESET, CYAN, RESET });
    std.debug.print("  {s}\n", .{"─────────────────────────────────────────────────────────────"});

    for (backups.items) |b| {
        const size_kb = @as(f64, @floatFromInt(b.size)) / 1024.0;
        std.debug.print("  {s}{s}{s} {d:>8.1} KB  {s}\n", .{ YELLOW, b.filename, RESET, size_kb, b.timestamp });
    }

    std.debug.print("\n  Total: {d} backup(s)\n\n", .{backups.items.len});
}

fn runRegistryRestore(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}ERROR{s}: Missing timestamp argument\n", .{ RED, RESET });
        std.debug.print("  Usage: tri cell registry restore <timestamp>\n");
        std.debug.print("  Run: tri cell registry list -- to see available backups\n");
        return;
    }

    const timestamp = args[0];

    std.debug.print("\n{s}REGISTRY RESTORE{s} — Restoring from backup\n\n", .{ YELLOW, RESET });
    std.debug.print("  Timestamp: {s}\n", .{timestamp});

    const backup_filename = try std.fmt.allocPrint(allocator, "data/cells/backups/registry-{s}.json", .{timestamp});
    defer allocator.free(backup_filename);

    const backup_data = std.fs.cwd().readFileAlloc(allocator, backup_filename, 1024 * 1024) catch {
        std.debug.print("  {s}✗ FAIL{s}: Backup not found: {s}\n", .{ RED, RESET, backup_filename });
        return;
    };
    defer allocator.free(backup_data);

    _ = std.json.parseFromSlice(std.json.Value, allocator, backup_data, .{}) catch {
        std.debug.print("  {s}✗ FAIL{s}: Backup file contains invalid JSON\n", .{ RED, RESET });
        return;
    };

    const current_backup = try std.fmt.allocPrint(allocator, "data/cells/backups/registry-before-restore-{s}.json", .{try getCurrentTimestamp(allocator)});
    defer allocator.free(current_backup);

    if (loadRegistry(allocator)) |current_registry| {
        defer allocator.free(current_registry);
        if (std.fs.cwd().writeFile(current_backup, current_registry)) |_| {
            std.debug.print("  {s}✓ Backed up{s} current registry to: {s}\n", .{ GREEN, RESET, current_backup });
        } else |_| {
            std.debug.print("  {s}⚠ WARNING{s}: Could not backup current registry\n", .{ YELLOW, RESET });
        }
    } else |err| {
        std.debug.print("  {s}⚠ WARNING{s}: Cannot backup current registry: {}\n", .{ YELLOW, RESET, err });
    }

    const registry_path = "data/cells/registry.json";
    try std.fs.cwd().writeFile(registry_path, backup_data);

    const size_kb = @as(f64, @floatFromInt(backup_data.len)) / 1024.0;
    std.debug.print("\n  {s}✓ Restored{s}: {s}\n", .{ GREEN, RESET, registry_path });
    std.debug.print("  From: {s}\n", .{backup_filename});
    std.debug.print("  Size: {d:.1} KB\n\n", .{size_kb});
    std.debug.print("  Previous registry backed up to: {s}\n\n", .{current_backup});
}

fn getCurrentTimestamp(allocator: Allocator) ![]u8 {
    const now = std.time.timestamp();
    const epoch = @as(u64, @intCast(now));

    const seconds = epoch % 60;
    const minutes = (epoch / 60) % 60;
    const hours = (epoch / 3600) % 24;
    const days = (epoch / 86400) + 719528;

    const year: u64 = @divFloor(days * 100 + 99, 3652425);
    const day_of_year = days - @divFloor(year * 3652425, 100);

    const month = @divFloor(day_of_year * 100 + 99, 3044) + 3;
    const day = day_of_year - @divFloor(month * 3044 - 3040, 100);

    const year_str = try std.fmt.allocPrint(allocator, "{d:04}", .{@as(u16, @intCast(year + 1970))});
    defer allocator.free(year_str);

    const month_str = try std.fmt.allocPrint(allocator, "{d:02}", .{@as(u8, @intCast(if (month > 12) month - 12 else month))});
    defer allocator.free(month_str);

    const day_str = try std.fmt.allocPrint(allocator, "{d:02}", .{@as(u8, @intCast(day))});
    defer allocator.free(day_str);

    const hour_str = try std.fmt.allocPrint(allocator, "{d:02}", .{@as(u8, @intCast(hours))});
    defer allocator.free(hour_str);

    const min_str = try std.fmt.allocPrint(allocator, "{d:02}", .{@as(u8, @intCast(minutes))});
    defer allocator.free(min_str);

    const sec_str = try std.fmt.allocPrint(allocator, "{d:02}", .{@as(u8, @intCast(seconds))});
    defer allocator.free(sec_str);

    return std.fmt.allocPrint(allocator, "{s}{s}{s}-{s}{s}{s}", .{ year_str, month_str, day_str, hour_str, min_str, sec_str });
}
