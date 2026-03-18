// =============================================================================
// FORGE OF KOSCHEI v2.0 — Design Checkpoint Save/Load
// =============================================================================
//
// Saves and loads ForgeDB state at any pipeline phase.
// Binary format with magic header for quick validation.
//
// Format:
//   [4 bytes] Magic: 0x464F5247 ("FORG")
//   [4 bytes] Version: 0x00020000 (v2.0.0)
//   [4 bytes] Phase (enum)
//   [4 bytes] Device (enum)
//   [4 bytes] Cell count
//   [N * 21 bytes] Cell data (id:4 + type:4 + x:2 + y:2 + lut_init:8 + locked:1)
//   [4 bytes] Net count
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

const ForgeDB = types.ForgeDB;
const Phase = types.Phase;
const DeviceId = types.DeviceId;
const MappedCell = types.MappedCell;
const CellType = types.CellType;

pub const FORGE_MAGIC: u32 = 0x464F5247; // "FORG"
pub const FORGE_VERSION: u32 = 0x00020000; // v2.0.0

pub const CheckpointError = error{
    InvalidMagic,
    InvalidVersion,
    InvalidPhase,
    InvalidDevice,
    OutOfMemory,
    ReadError,
    WriteError,
};

// Helper: write u32 big-endian to raw file
fn writeU32(file: std.fs.File, val: u32) !void {
    const bytes = std.mem.toBytes(std.mem.nativeTo(u32, val, .big));
    try file.writeAll(&bytes);
}

fn writeU16(file: std.fs.File, val: u16) !void {
    const bytes = std.mem.toBytes(std.mem.nativeTo(u16, val, .big));
    try file.writeAll(&bytes);
}

fn writeU64(file: std.fs.File, val: u64) !void {
    const bytes = std.mem.toBytes(std.mem.nativeTo(u64, val, .big));
    try file.writeAll(&bytes);
}

fn writeU8(file: std.fs.File, val: u8) !void {
    try file.writeAll(&[_]u8{val});
}

// Helper: read big-endian from raw file
fn readU32(file: std.fs.File) !u32 {
    var bytes: [4]u8 = undefined;
    const n = try file.readAll(&bytes);
    if (n != 4) return error.EndOfStream;
    return std.mem.nativeTo(u32, std.mem.bytesToValue(u32, &bytes), .big);
}

fn readU16(file: std.fs.File) !u16 {
    var bytes: [2]u8 = undefined;
    const n = try file.readAll(&bytes);
    if (n != 2) return error.EndOfStream;
    return std.mem.nativeTo(u16, std.mem.bytesToValue(u16, &bytes), .big);
}

fn readU64(file: std.fs.File) !u64 {
    var bytes: [8]u8 = undefined;
    const n = try file.readAll(&bytes);
    if (n != 8) return error.EndOfStream;
    return std.mem.nativeTo(u64, std.mem.bytesToValue(u64, &bytes), .big);
}

fn readU8(file: std.fs.File) !u8 {
    var bytes: [1]u8 = undefined;
    const n = try file.readAll(&bytes);
    if (n != 1) return error.EndOfStream;
    return bytes[0];
}

/// Save a ForgeDB checkpoint to a binary file.
pub fn saveCheckpoint(db: *const ForgeDB, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    // Header
    try writeU32(file, FORGE_MAGIC);
    try writeU32(file, FORGE_VERSION);
    try writeU32(file, @intFromEnum(db.phase));
    try writeU32(file, @intFromEnum(db.device));

    // Cell count
    try writeU32(file, @intCast(db.cells.items.len));

    // Cells
    for (db.cells.items) |cell| {
        try writeU32(file, cell.id);
        try writeU32(file, @intFromEnum(cell.cell_type));
        try writeU16(file, cell.tile_x orelse 0xFFFF);
        try writeU16(file, cell.tile_y orelse 0xFFFF);
        try writeU64(file, cell.lut_init);
        try writeU8(file, if (cell.locked) 1 else 0);
    }

    // Net count
    try writeU32(file, @intCast(db.nets.items.len));
}

/// Load a ForgeDB checkpoint from a binary file.
pub fn loadCheckpoint(allocator: Allocator, path: []const u8) !ForgeDB {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Validate header
    const magic = try readU32(file);
    if (magic != FORGE_MAGIC) return CheckpointError.InvalidMagic;

    const version = try readU32(file);
    if (version != FORGE_VERSION) return CheckpointError.InvalidVersion;

    const phase_int = try readU32(file);
    const phase: Phase = @enumFromInt(phase_int);

    const device_int = try readU32(file);
    const device: DeviceId = @enumFromInt(device_int);

    var db = ForgeDB.init(allocator, device);
    errdefer db.deinit();
    db.phase = phase;

    // Read cells
    const cell_count = try readU32(file);
    for (0..cell_count) |_| {
        const id = try readU32(file);
        const ct_int = try readU32(file);
        const tx = try readU16(file);
        const ty = try readU16(file);
        const lut_init = try readU64(file);
        const locked_byte = try readU8(file);

        try db.cells.append(allocator, MappedCell{
            .id = id,
            .cell_type = @enumFromInt(ct_int),
            .name = "", // Names not persisted in checkpoint
            .tile_x = if (tx == 0xFFFF) null else tx,
            .tile_y = if (ty == 0xFFFF) null else ty,
            .lut_init = lut_init,
            .locked = locked_byte != 0,
        });
    }

    // Read net count (nets stored minimally for now)
    _ = try readU32(file);

    return db;
}

// =============================================================================
// Tests
// =============================================================================

test "magic and version" {
    try std.testing.expectEqual(@as(u32, 0x464F5247), FORGE_MAGIC);
    try std.testing.expectEqual(@as(u32, 0x00020000), FORGE_VERSION);
}

test "checkpoint roundtrip" {
    const allocator = std.testing.allocator;

    // Create a test DB
    var db = ForgeDB.init(allocator, .xc7a35t);
    defer db.deinit();

    db.phase = .placed;
    try db.cells.append(allocator, MappedCell{
        .id = 0,
        .cell_type = .LUT1,
        .name = "lut0",
        .tile_x = 10,
        .tile_y = 20,
        .lut_init = 0b01,
        .locked = false,
    });
    try db.cells.append(allocator, MappedCell{
        .id = 1,
        .cell_type = .FDRE,
        .name = "ff0",
        .tile_x = 30,
        .tile_y = 40,
        .lut_init = 0,
        .locked = true,
    });

    // Save
    const path = "/tmp/forge_test_checkpoint.bin";
    try saveCheckpoint(&db, path);

    // Load
    var loaded = try loadCheckpoint(allocator, path);
    defer loaded.deinit();

    try std.testing.expectEqual(Phase.placed, loaded.phase);
    try std.testing.expectEqual(DeviceId.xc7a35t, loaded.device);
    try std.testing.expectEqual(@as(usize, 2), loaded.cells.items.len);

    const c0 = loaded.cells.items[0];
    try std.testing.expectEqual(CellType.LUT1, c0.cell_type);
    try std.testing.expectEqual(@as(?u16, 10), c0.tile_x);
    try std.testing.expectEqual(@as(?u16, 20), c0.tile_y);
    try std.testing.expectEqual(@as(u64, 0b01), c0.lut_init);
    try std.testing.expect(!c0.locked);

    const c1 = loaded.cells.items[1];
    try std.testing.expectEqual(CellType.FDRE, c1.cell_type);
    try std.testing.expect(c1.locked);

    // Cleanup
    std.fs.cwd().deleteFile(path) catch |err| {
        std.log.debug("forge_db: failed to delete checkpoint file: {}", .{err});
    };
}
