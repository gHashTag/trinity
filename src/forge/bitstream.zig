// =============================================================================
// FORGE OF KOSCHEI v2.0 — Xilinx 7-Series Bitstream Writer
// =============================================================================
//
// Generates Xilinx .bit files from FASM features.
//
// Pipeline: FASM features -> frame bits (via segbits) -> .bit file
//
// Xilinx .bit format:
//   - ASCII header (design name, part, date, time)
//   - Sync word: 0xAA995566
//   - Configuration commands (IDCODE, FDRI, etc.)
//   - Frame data (all configuration frames)
//   - CRC check
//   - DESYNC
//
// Frame layout for Artix-7:
//   - Each frame = 101 x 32-bit words
//   - XC7A35T: 16,620 frames total
//   - XC7A100T: 51,840 frames total
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");
const segbits = @import("segbits.zig");

const DeviceId = types.DeviceId;
const FasmFeature = types.FasmFeature;

// Xilinx command register addresses
const CMD_NULL: u32 = 0x00000000;
const CMD_WCFG: u32 = 0x00000001;
const CMD_GRESTORE: u32 = 0x0000000A;
const CMD_START: u32 = 0x00000005;
const CMD_RCRC: u32 = 0x00000007;
const CMD_DESYNC: u32 = 0x0000000D;

// Register addresses
const REG_CRC: u5 = 0x00;
const REG_FAR: u5 = 0x01;
const REG_FDRI: u5 = 0x02;
const REG_CMD: u5 = 0x04;
const REG_CTL0: u5 = 0x05;
const REG_MASK: u5 = 0x06;
const REG_IDCODE: u5 = 0x0C;

pub const BitstreamError = error{
    OutOfMemory,
    WriteError,
    InvalidDevice,
};

/// Generate a Xilinx .bit file from FASM features.
/// This is the main entry point for the bitstream backend.
pub fn generateBitstreamFromFasm(
    allocator: Allocator,
    device: DeviceId,
    features: []const FasmFeature,
    output_path: []const u8,
) !segbits.ApplyStats {
    const params = device_db.getDeviceParams(device);

    // Allocate all frames (initialized to zero)
    const total_words = @as(usize, params.frame_count) * @as(usize, params.frame_words);
    const frames = try allocator.alloc(u32, total_words);
    defer allocator.free(frames);
    @memset(frames, 0);

    // Apply FASM features -> frame bits via segbits lookup
    const stats = segbits.applyFeatures(features, frames, device);

    // Build bitstream in memory then write to file
    try writeBitFile(allocator, output_path, device, frames, params);

    return stats;
}

/// Generate a blank Xilinx .bit file (no FASM features applied).
pub fn generateBitstream(allocator: Allocator, device: DeviceId, output_path: []const u8) !void {
    const params = device_db.getDeviceParams(device);

    // Allocate all frames (initialized to zero)
    const total_words = @as(usize, params.frame_count) * @as(usize, params.frame_words);
    const frames = try allocator.alloc(u32, total_words);
    defer allocator.free(frames);
    @memset(frames, 0);

    // Build bitstream in memory then write to file
    try writeBitFile(allocator, output_path, device, frames, params);
}

/// Write the .bit file in Xilinx format.
/// Builds entire bitstream in an ArrayList buffer, then writes to file at once.
fn writeBitFile(allocator: Allocator, path: []const u8, device: DeviceId, frames: []const u32, params: device_db.DeviceParams) !void {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    // Header
    try writeHeader(writer, device);

    // Sync word sequence
    try writeWord(writer, types.XILINX_DUMMY);
    try writeWord(writer, types.XILINX_BUS_WIDTH_DETECT);
    try writeWord(writer, types.XILINX_BUS_WIDTH_SYNC);
    try writeWord(writer, types.XILINX_DUMMY);
    try writeWord(writer, types.XILINX_DUMMY);
    try writeWord(writer, types.XILINX_SYNC_WORD);
    try writeWord(writer, types.XILINX_NOOP);

    // Reset CRC
    try writeType1(writer, REG_CMD, CMD_RCRC);
    try writeWord(writer, types.XILINX_NOOP);
    try writeWord(writer, types.XILINX_NOOP);

    // IDCODE
    try writeType1(writer, REG_IDCODE, params.idcode);

    // Write Configuration: CMD=WCFG
    try writeType1(writer, REG_CMD, CMD_WCFG);
    try writeWord(writer, types.XILINX_NOOP);

    // Frame Address Register (start at 0)
    try writeType1(writer, REG_FAR, 0x00000000);

    // FDRI: Write all frames
    // Type 1 header for FDRI with word count
    const frame_word_count: u32 = @intCast(frames.len);
    if (frame_word_count <= 0x7FF) {
        try writeType1Count(writer, REG_FDRI, frame_word_count);
    } else {
        // Type 2 packet for large data
        try writeType1Count(writer, REG_FDRI, 0);
        try writeType2(writer, frame_word_count);
    }

    // Frame data
    for (frames) |word| {
        try writeWord(writer, word);
    }

    // Reset CRC — standard open-source approach per prjxray docs:
    // "CRC writes can be safely removed. Alternatively, replace with
    //  write to command register to reset calculated CRC value."
    // Using RCRC resets the internal CRC accumulator, bypassing CRC check.
    try writeType1(writer, REG_CMD, CMD_RCRC);
    try writeWord(writer, types.XILINX_NOOP);
    try writeWord(writer, types.XILINX_NOOP);

    // GRESTORE
    try writeType1(writer, REG_CMD, CMD_GRESTORE);
    try writeWord(writer, types.XILINX_NOOP);

    // START
    try writeType1(writer, REG_CMD, CMD_START);
    try writeWord(writer, types.XILINX_NOOP);

    // DESYNC
    try writeType1(writer, REG_CMD, CMD_DESYNC);

    // Padding NOOPs
    for (0..16) |_| {
        try writeWord(writer, types.XILINX_NOOP);
    }

    // Write buffer to file
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(buf.items);
}

fn writeHeader(writer: anytype, device: DeviceId) !void {
    // Xilinx .bit file header format:
    // Field 1: 2-byte length + padding (0009 0ff00ff00ff00ff000)
    // Field 2: 'a' + design name
    // Field 3: 'b' + part name
    // Field 4: 'c' + date
    // Field 5: 'd' + time
    // Field 6: 'e' + 4-byte data length

    // Header magic
    const header_magic = [_]u8{
        0x00, 0x09, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0,
        0x0f, 0xf0, 0x00, 0x00, 0x01,
    };
    try writer.writeAll(&header_magic);

    // Design name (field 'a')
    const design_name = "forge;UserID=0xFFFFFFFF";
    try writer.writeByte('a');
    try writer.writeInt(u16, @intCast(design_name.len + 1), .big);
    try writer.writeAll(design_name);
    try writer.writeByte(0);

    // Part name (field 'b')
    const part = device.partName();
    try writer.writeByte('b');
    try writer.writeInt(u16, @intCast(part.len + 1), .big);
    try writer.writeAll(part);
    try writer.writeByte(0);

    // Date (field 'c')
    const date = "2026/03/01";
    try writer.writeByte('c');
    try writer.writeInt(u16, @intCast(date.len + 1), .big);
    try writer.writeAll(date);
    try writer.writeByte(0);

    // Time (field 'd')
    const time = "00:00:00";
    try writer.writeByte('d');
    try writer.writeInt(u16, @intCast(time.len + 1), .big);
    try writer.writeAll(time);
    try writer.writeByte(0);

    // Data length (field 'e') — placeholder, will be approximate
    const params = device_db.getDeviceParams(device);
    const data_bytes: u32 = @as(u32, params.frame_count) * @as(u32, params.frame_words) * 4 + 1024;
    try writer.writeByte('e');
    try writer.writeInt(u32, data_bytes, .big);
}

fn writeWord(writer: anytype, word: u32) !void {
    try writer.writeInt(u32, word, .big);
}

fn writeType1(writer: anytype, reg: u5, value: u32) !void {
    // Type 1 packet: [31:29]=001, [28:27]=op(write=10), [17:13]=reg, [10:0]=word_count
    const header: u32 = (0b001 << 29) | (0b10 << 27) | (@as(u32, reg) << 13) | 1;
    try writeWord(writer, header);
    try writeWord(writer, value);
}

fn writeType1Count(writer: anytype, reg: u5, count: u32) !void {
    const header: u32 = (0b001 << 29) | (0b10 << 27) | (@as(u32, reg) << 13) | (count & 0x7FF);
    try writeWord(writer, header);
}

fn writeType2(writer: anytype, count: u32) !void {
    // Type 2 packet: [31:29]=010, [26:0]=word_count
    const header: u32 = (0b010 << 29) | (count & 0x7FFFFFF);
    try writeWord(writer, header);
}

// =============================================================================
// In-Memory Bitstream Generation (for testing)
// =============================================================================

/// Generate bitstream to a buffer (for testing without file I/O).
pub fn generateToBuffer(allocator: Allocator, device: DeviceId) ![]u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);

    const writer = buf.writer(allocator);
    const params = device_db.getDeviceParams(device);

    // Sync
    try writeWord(writer, types.XILINX_SYNC_WORD);
    try writeWord(writer, types.XILINX_NOOP);

    // IDCODE
    try writeType1(writer, REG_IDCODE, params.idcode);

    // DESYNC
    try writeType1(writer, REG_CMD, CMD_DESYNC);

    return buf.toOwnedSlice(allocator);
}

// =============================================================================
// Tests
// =============================================================================

test "sync word encoding" {
    try std.testing.expectEqual(@as(u32, 0xAA995566), types.XILINX_SYNC_WORD);
    try std.testing.expectEqual(@as(u32, 0x20000000), types.XILINX_NOOP);
}

test "type1 packet encoding" {
    // Type1 write to IDCODE (reg=0x0C) with 1 word
    const expected: u32 = (0b001 << 29) | (0b10 << 27) | (@as(u32, 0x0C) << 13) | 1;
    // = 0x30018001
    try std.testing.expectEqual(@as(u32, 0x30018001), expected);
}

test "generate to buffer" {
    const allocator = std.testing.allocator;

    const buf = try generateToBuffer(allocator, .xc7a35t);
    defer allocator.free(buf);

    // Should contain sync word and IDCODE
    try std.testing.expect(buf.len > 0);

    // First 4 bytes should be sync word (big-endian)
    try std.testing.expectEqual(@as(u8, 0xAA), buf[0]);
    try std.testing.expectEqual(@as(u8, 0x99), buf[1]);
    try std.testing.expectEqual(@as(u8, 0x55), buf[2]);
    try std.testing.expectEqual(@as(u8, 0x66), buf[3]);
}

test "IDCODE values" {
    const p35 = device_db.getDeviceParams(.xc7a35t);
    try std.testing.expectEqual(@as(u32, 0x0362D093), p35.idcode);

    const p100 = device_db.getDeviceParams(.xc7a100t);
    try std.testing.expectEqual(@as(u32, 0x13631093), p100.idcode);
}

test "frame dimensions" {
    const p = device_db.getDeviceParams(.xc7a35t);
    // XC7A35T: 16620 frames * 101 words * 4 bytes = ~6.7MB
    const total_bytes = @as(u64, p.frame_count) * @as(u64, p.frame_words) * 4;
    try std.testing.expect(total_bytes > 6_000_000);
    try std.testing.expect(total_bytes < 8_000_000);
}
