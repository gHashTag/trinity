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
//   - XC7A100T: 9,012 frames total (from prjxray-db)
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");
const segbits = @import("segbits.zig");
const far_table = @import("far_table.zig");

const DeviceId = types.DeviceId;
const FasmFeature = types.FasmFeature;

// Xilinx command register addresses
const CMD_NULL: u32 = 0x00000000;
const CMD_WCFG: u32 = 0x00000001;
const CMD_DGHIGH: u32 = 0x00000003; // Signal last frame loaded
const CMD_START: u32 = 0x00000005;
const CMD_RCRC: u32 = 0x00000007;
const CMD_SWITCH: u32 = 0x00000009; // Activate COR0 clock config
const CMD_GRESTORE: u32 = 0x0000000A;
const CMD_DESYNC: u32 = 0x0000000D;

// Register addresses
const REG_CRC: u5 = 0x00;
const REG_FAR: u5 = 0x01;
const REG_FDRI: u5 = 0x02;
const REG_CMD: u5 = 0x04;
const REG_CTL0: u5 = 0x05;
const REG_MASK: u5 = 0x06;
const REG_COR0: u5 = 0x09;
const REG_IDCODE: u5 = 0x0C;
const REG_COR1: u5 = 0x0E;
const REG_WBSTAR: u5 = 0x10;
const REG_TIMER: u5 = 0x11;
const REG_CTL1: u5 = 0x18;

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
/// Groups frames by column and writes each column with an explicit FAR address,
/// avoiding dependency on auto-increment padding details.
fn writeBitFile(allocator: Allocator, path: []const u8, device: DeviceId, frames: []const u32, params: device_db.DeviceParams) !void {
    _ = params;
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);

    const frame_words: u32 = 101;
    const frame_count = far_table.frame_count;

    // Header (field 'e' length will be patched after all data is written)
    try writeHeader(writer, device);
    const e_field_offset = buf.items.len - 4; // position of the 4-byte length we just wrote
    const data_start_offset = buf.items.len; // data starts right after 'e' field

    // Sync word sequence
    try writeWord(writer, types.XILINX_DUMMY);
    try writeWord(writer, types.XILINX_BUS_WIDTH_DETECT);
    try writeWord(writer, types.XILINX_BUS_WIDTH_SYNC);
    try writeWord(writer, types.XILINX_DUMMY);
    try writeWord(writer, types.XILINX_DUMMY);
    try writeWord(writer, types.XILINX_SYNC_WORD);
    try writeWord(writer, types.XILINX_NOOP);

    // --- Preamble: match xc7frames2bit register sequence ---

    // Timer and WBSTAR (disable watchdog, no multiboot)
    try writeType1(writer, REG_TIMER, 0x00000000);
    try writeType1(writer, REG_WBSTAR, 0x00000000);

    // CMD=NULL then reset CRC
    try writeType1(writer, REG_CMD, CMD_NULL);
    try writeWord(writer, types.XILINX_NOOP);
    try writeType1(writer, REG_CMD, CMD_RCRC);
    try writeWord(writer, types.XILINX_NOOP);
    try writeWord(writer, types.XILINX_NOOP);

    // BOOTSTS register (0x16 mapped to 0x13 in packet) — written by xc7frames2bit
    try writeType1(writer, 0x13, 0x00000000);

    // COR0: startup timing — GTS_cycle=6, GWE_cycle=6, DONE_cycle, LCK_cycle
    try writeType1(writer, REG_COR0, 0x02003FE5);

    // COR1: default
    try writeType1(writer, REG_COR1, 0x00000000);

    // IDCODE
    try writeType1(writer, REG_IDCODE, device_db.getDeviceParams(device).idcode);

    // CMD=SWITCH — activate COR0 clock/startup config
    try writeType1(writer, REG_CMD, CMD_SWITCH);
    try writeWord(writer, types.XILINX_NOOP);

    // MASK + CTL0: GTS_USR_B=1 (deassert global tri-state on all user IOs)
    try writeType1(writer, REG_MASK, 0x00000401);
    try writeType1(writer, REG_CTL0, 0x00000501);

    // Clear MASK, set CTL1=0
    try writeType1(writer, REG_MASK, 0x00000000);
    try writeType1(writer, REG_CTL1, 0x00000000);

    // Flush pipeline
    for (0..8) |_| {
        try writeWord(writer, types.XILINX_NOOP);
    }

    // FAR=0, CMD=WCFG
    try writeType1(writer, REG_FAR, 0x00000000);
    try writeType1(writer, REG_CMD, CMD_WCFG);
    try writeWord(writer, types.XILINX_NOOP);

    // --- Monolithic FDRI write (matching xc7frames2bit) ---
    //
    // xc7frames2bit writes ALL frames in a single FDRI packet:
    //   1. All frames in FAR auto-increment order
    //   2. Two zero-frame separators between sections (different bt/half/row)
    //   3. Two zero-frame padding at the very end
    //
    // Total = frame_count + section_transitions * 2 + 2

    // Count section transitions to compute total FDRI size
    var section_transitions: u32 = 0;
    {
        var i: u32 = 1;
        while (i < frame_count) : (i += 1) {
            const prev = far_table.far_table[i - 1];
            const curr = far_table.far_table[i];
            const bt_changed = far_table.farBlockType(prev) != far_table.farBlockType(curr);
            const half_changed = far_table.farHalf(prev) != far_table.farHalf(curr);
            const row_changed = far_table.farRow(prev) != far_table.farRow(curr);
            if (bt_changed or half_changed or row_changed) {
                section_transitions += 1;
            }
        }
    }

    const fdri_total_frames = frame_count + section_transitions * 2 + 2;
    const fdri_total_words = fdri_total_frames * frame_words;

    // FDRI header: Type1 with wc=0 followed by Type2 with total word count
    try writeType1Count(writer, REG_FDRI, 0);
    try writeType2(writer, fdri_total_words);

    // Write all frames with section separators
    // We need a mutable copy of each frame to compute ECC in-place
    var ecc_frame: [101]u32 = undefined;

    var frame_idx: u32 = 0;
    while (frame_idx < frame_count) : (frame_idx += 1) {
        // Copy frame data into mutable buffer
        const base = @as(usize, frame_idx) * @as(usize, frame_words);
        var w: u32 = 0;
        while (w < frame_words) : (w += 1) {
            ecc_frame[w] = if (base + w < frames.len) frames[base + w] else 0;
        }

        // Compute and insert ECC (lower 13 bits of word 50)
        updateFrameEcc(&ecc_frame);

        // Write the frame with ECC
        for (ecc_frame) |word| {
            try writeWord(writer, word);
        }

        // Check if next frame is in a different section → insert 2 zero frames
        if (frame_idx + 1 < frame_count) {
            const curr = far_table.far_table[frame_idx];
            const next = far_table.far_table[frame_idx + 1];
            const bt_changed = far_table.farBlockType(curr) != far_table.farBlockType(next);
            const half_changed = far_table.farHalf(curr) != far_table.farHalf(next);
            const row_changed = far_table.farRow(curr) != far_table.farRow(next);
            if (bt_changed or half_changed or row_changed) {
                // Two zero frames as separator
                var z: u32 = 0;
                while (z < frame_words * 2) : (z += 1) {
                    try writeWord(writer, 0);
                }
            }
        }
    }

    // Final two zero frames at the end
    {
        var z: u32 = 0;
        while (z < frame_words * 2) : (z += 1) {
            try writeWord(writer, 0);
        }
    }

    // --- Postamble: match xc7frames2bit register sequence exactly ---

    // Reset CRC after frame data
    try writeType1(writer, REG_CMD, CMD_RCRC);
    try writeWord(writer, types.XILINX_NOOP);
    try writeWord(writer, types.XILINX_NOOP);

    // GRESTORE — restore global signals
    try writeType1(writer, REG_CMD, CMD_GRESTORE);
    try writeWord(writer, types.XILINX_NOOP);

    // DGHIGH/LFRM — signal that all frames have been loaded
    try writeType1(writer, REG_CMD, CMD_DGHIGH);
    for (0..100) |_| {
        try writeWord(writer, types.XILINX_NOOP);
    }

    // START — begin startup sequence (GTS/GWE release)
    try writeType1(writer, REG_CMD, CMD_START);
    try writeWord(writer, types.XILINX_NOOP);

    // FAR to end-of-device address (last FAR + 1 column)
    try writeType1(writer, REG_FAR, 0x03BE0000);

    // Re-assert MASK + CTL0 for startup
    try writeType1(writer, REG_MASK, 0x00000501);
    try writeType1(writer, REG_CTL0, 0x00000501);

    // Reset CRC before DESYNC
    try writeType1(writer, REG_CMD, CMD_RCRC);
    try writeWord(writer, types.XILINX_NOOP);
    try writeWord(writer, types.XILINX_NOOP);

    // DESYNC — exit configuration mode
    try writeType1(writer, REG_CMD, CMD_DESYNC);

    // Padding NOOPs (flush pipeline — xc7frames2bit uses 400)
    for (0..400) |_| {
        try writeWord(writer, types.XILINX_NOOP);
    }

    // Patch field 'e' length with actual data size
    {
        const data_length: u32 = @intCast(buf.items.len - data_start_offset);
        buf.items[e_field_offset + 0] = @intCast((data_length >> 24) & 0xFF);
        buf.items[e_field_offset + 1] = @intCast((data_length >> 16) & 0xFF);
        buf.items[e_field_offset + 2] = @intCast((data_length >> 8) & 0xFF);
        buf.items[e_field_offset + 3] = @intCast(data_length & 0xFF);
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

    // Data length (field 'e') — placeholder, patched after all data is written
    try writer.writeByte('e');
    try writer.writeInt(u32, 0x00000000, .big);
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
    // Type 2 packet: [31:29]=010, [28:27]=opcode(write=10), [26:0]=word_count
    const header: u32 = (0b010 << 29) | (0b10 << 27) | (count & 0x7FFFFFF);
    try writeWord(writer, header);
}

// =============================================================================
// ECC Computation (per Xilinx UG470, matching xc7frames2bit / prjxray)
// =============================================================================
//
// Each 7-series frame has 101 words (indices 0x00-0x64).
// Word 50 (0x32) holds:
//   - Bits [31:13]: HCLK (horizontal clock) configuration
//   - Bits [12:0]:  ECC (13-bit error-correcting code)
//
// The ECC is computed over all 101 words and stored in the lower 13 bits
// of word 50. When computing ECC over word 50 itself, the existing ECC
// bits are masked out (only the HCLK upper bits contribute).

/// Compute the ICAP ECC for one word at the given index.
/// This matches prjxray's xc7series::icap_ecc exactly.
fn icapEcc(idx: u32, data_in: u32, ecc_in: u32) u32 {
    var val: u32 = idx * 32; // bit offset

    // Add architecture-specific offsets to avoid collisions
    if (idx > 0x25) {
        val += 0x1360; // avoid 0x800
    } else if (idx > 0x6) {
        val += 0x1340; // avoid 0x400
    } else {
        val += 0x1320; // avoid lower
    }

    var data = data_in;
    // At ECC word (0x32), mask out existing ECC bits
    if (idx == 0x32) {
        data &= 0xFFFFE000;
    }

    var ecc = ecc_in;
    for (0..32) |i| {
        if (data & 1 != 0) {
            ecc ^= val + @as(u32, @intCast(i));
        }
        data >>= 1;
    }

    // At last word (0x64 = 100), compute parity bit
    if (idx == 0x64) {
        var v = ecc & 0xFFF;
        v ^= v >> 8;
        v ^= v >> 4;
        v ^= v >> 2;
        v ^= v >> 1;
        ecc ^= (v & 1) << 12; // parity
    }

    return ecc;
}

/// Compute and update the ECC for a frame in-place.
/// frame must be exactly 101 words (frame_words).
fn updateFrameEcc(frame: []u32) void {
    std.debug.assert(frame.len >= 101);

    // Compute ECC over all 101 words
    var ecc: u32 = 0;
    for (0..101) |i| {
        ecc = icapEcc(@intCast(i), frame[i], ecc);
    }

    // Store ECC in lower 13 bits of word 50, preserving upper 19 bits (HCLK)
    frame[50] = (frame[50] & 0xFFFFE000) | (ecc & 0x1FFF);
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
    try std.testing.expectEqual(@as(u32, 0x03631093), p100.idcode);
}

test "frame dimensions" {
    const p = device_db.getDeviceParams(.xc7a35t);
    // XC7A35T: 16620 frames * 101 words * 4 bytes = ~6.7MB
    const total_bytes = @as(u64, p.frame_count) * @as(u64, p.frame_words) * 4;
    try std.testing.expect(total_bytes > 6_000_000);
    try std.testing.expect(total_bytes < 8_000_000);
}

test "ECC computation for zero frame" {
    // A zero frame should have zero ECC
    var frame = [_]u32{0} ** 101;
    updateFrameEcc(&frame);
    try std.testing.expectEqual(@as(u32, 0), frame[50] & 0x1FFF);
}

test "ECC computation preserves HCLK bits" {
    // Set some HCLK bits in word 50 upper 19 bits
    var frame = [_]u32{0} ** 101;
    frame[50] = 0x80220000; // HCLK config in upper bits
    updateFrameEcc(&frame);
    // HCLK bits should be preserved
    try std.testing.expectEqual(@as(u32, 0x80220000), frame[50] & 0xFFFFE000);
    // ECC should be non-zero (since HCLK bits contribute to ECC)
    try std.testing.expect((frame[50] & 0x1FFF) != 0);
}

test "ECC computation matches reference" {
    // Frame with data at word 0 only: 0x00000001
    // This tests the basic ECC XOR logic
    var frame = [_]u32{0} ** 101;
    frame[0] = 0x00000001; // bit 0 of word 0
    updateFrameEcc(&frame);
    const ecc = frame[50] & 0x1FFF;
    // icap_ecc(0, 1, 0): val = 0*32 + 0x1320 = 0x1320
    // bit 0 set: ecc ^= 0x1320 + 0 = 0x1320
    // At word 0x64 (100): parity calc
    // 0x1320 & 0xFFF = 0x320
    // v = 0x320 ^ (0x320>>8=3) = 0x323 ^ (0x323>>4=0x32) = 0x311
    // 0x311 ^ (0x311>>2=0xC4) = 0x3D5 ^ (0x3D5>>1=0x1EA) = 0x23F
    // parity = 0x23F & 1 = 1 → ecc ^= (1 << 12) = 0x1000
    // Final: 0x1320 ^ 0x1000 = 0x0320
    try std.testing.expectEqual(@as(u32, 0x0320), ecc);
}
