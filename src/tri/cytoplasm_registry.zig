// @origin(manual) @regen(pending)
const std = @import("std");
const colors = @import("tri_colors.zig");

const Allocator = std.mem.Allocator;

const CYAN = colors.CYAN;
const RESET = colors.RESET;
const GREEN = colors.GREEN;
const YELLOW = colors.YELLOW;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;

pub fn runRegistry(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}tri cell registry{s} — Registry management\n\n", .{ GOLDEN, RESET });
        std.debug.print("  {s}validate{s}  Check registry consistency\n", .{ GREEN, RESET });
        std.debug.print("  {s}backup{s}    Create timestamped backup\n", .{ GREEN, RESET });
        std.debug.print("  {s}list{s}      List available backups\n", .{ GREEN, RESET });
        return;
    }

    const sub = args[0];
    const rest = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "validate")) return runValidate(allocator);
    if (std.mem.eql(u8, sub, "repair")) return runRepair(allocator);
    if (std.mem.eql(u8, sub, "backup")) return runBackup(allocator, rest);
    if (std.mem.eql(u8, sub, "list")) return runListBackups(allocator);

    std.debug.print("{s}ERROR{s}: Unknown subcommand: {s}\n", .{ RED, RESET, sub });
}

fn runValidate(allocator: Allocator) !void {
    std.debug.print("\n{s}REGISTRY VALIDATE{s}\n\n", .{ CYAN, RESET });

    const registry = std.fs.cwd().readFileAlloc(allocator, "data/cells/registry.json", 262144) catch {
        std.debug.print("  {s}FAIL{s}: Cannot read registry.json\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(registry);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, registry, .{}) catch {
        std.debug.print("  {s}FAIL{s}: Invalid JSON\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value.object;
    var issues: usize = 0;

    if (root.get("cells")) |cells_val| {
        const cells = switch (cells_val) {
            .array => |a| a.items,
            else => {
                std.debug.print("  {s}ERROR{s}: 'cells' is not an array\n", .{ RED, RESET });
                return;
            },
        };
        std.debug.print("  {d} cells found\n", .{cells.len});
    } else {
        std.debug.print("  {s}ERROR{s}: No 'cells' key\n", .{ RED, RESET });
        issues += 1;
    }

    if (issues == 0) {
        std.debug.print("  {s}PASS{s}: Registry is valid\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}FAIL{s}: {d} issues found\n\n", .{ RED, RESET, issues });
    }
}

fn runRepair(allocator: Allocator) !void {
    _ = allocator;
    std.debug.print("\n{s}REGISTRY REPAIR{s}\n\n", .{ YELLOW, RESET });
    std.debug.print("  Repair not implemented yet\n\n", .{});
}

fn runBackup(allocator: Allocator, args: []const []const u8) !void {
    _ = args;

    std.debug.print("\n{s}REGISTRY BACKUP{s}\n\n", .{ GOLDEN, RESET });

    const backup_dir = "data/cells/backups";
    std.fs.cwd().makePath(backup_dir) catch {};

    const now = std.time.timestamp();
    const ts_fmt = try std.fmt.allocPrint(allocator, "{d}", .{now});
    defer allocator.free(ts_fmt);

    const backup_path = try std.fmt.allocPrint(allocator, "{s}/registry-{s}.json", .{ backup_dir, ts_fmt });
    defer allocator.free(backup_path);

    const registry = std.fs.cwd().readFileAlloc(allocator, "data/cells/registry.json", 262144) catch {
        std.debug.print("  {s}FAIL{s}: Cannot read registry.json\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(registry);

    const file = try std.fs.cwd().createFile(backup_path, .{});
    defer file.close();
    _ = try file.writeAll(registry);

    std.debug.print("  {s}DONE{s}: Backup created\n\n", .{ GREEN, RESET });
}

fn runListBackups(allocator: Allocator) !void {
    _ = allocator;

    std.debug.print("\n{s}REGISTRY BACKUPS{s}\n\n", .{ CYAN, RESET });

    var backup_dir = std.fs.cwd().openDir("data/cells/backups", .{ .iterate = true }) catch {
        std.debug.print("  No backups found\n\n", .{});
        return;
    };
    defer backup_dir.close();

    var iter = backup_dir.iterate();
    var count: usize = 0;
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.startsWith(u8, entry.name, "registry-")) {
            std.debug.print("  {s}\n", .{entry.name});
            count += 1;
        }
    }

    std.debug.print("\n  Total: {d} backup(s)\n\n", .{count});
}
