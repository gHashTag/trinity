// =============================================================================
// FORGE OF KOSCHEI v2.0 — Segbits Engine
// =============================================================================
//
// Maps FASM features to configuration frame bits using generated segbits data.
//
// Pipeline:
//   FASM feature line → parse tile type + feature name
//                     → lookup in segbits_data comptime tables
//                     → set/clear bits in frame array
//
// FASM line format: TILE_TYPE_XCOORD_YCOORD.FEATURE
//   Example: CLBLL_L_X2Y148.SLICEL_X0.ALUT.INIT[63:0] = 0x...
//   Example: INT_L_X0Y136.IMUX_L34.VCC_WIRE
//   Example: LIOB33_X0Y75.IOB_Y1.LVCMOS25_LVCMOS33_LVTTL.IN
//
// Tile instance → base frame address (from device_db)
// Feature → relative bit positions (from segbits_data)
// Absolute frame bit = base_frame_addr + frame_offset, word_offset, bit_in_word
//
// Sacred Formula: phi^2 + 1/phi^2 = 3
//
// =============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const device_db = @import("device_db.zig");
const segbits_data = @import("segbits_data.zig");
const far_table = @import("far_table.zig");

const DeviceId = types.DeviceId;
const FasmFeature = types.FasmFeature;

pub const SegbitsError = error{
    OutOfMemory,
    UnknownTileType,
    UnknownFeature,
    InvalidFasmLine,
};

pub const ApplyStats = struct {
    features_applied: u32,
    bits_set: u32,
    bits_cleared: u32,
    features_skipped: u32,
    unknown_tile_types: u32,
    unknown_features: u32,
};

// =============================================================================
// FASM Line Parsing
// =============================================================================

/// Parse a FASM line into tile type, tile instance name, and feature name.
/// Format: TILE_TYPE_X#Y#.FEATURE...
/// Returns: (tile_type, tile_instance, feature_within_tile)
pub fn parseFasmLine(line: []const u8) ?struct {
    tile_type: []const u8,
    tile_name: []const u8,
    feature: []const u8,
} {
    // Skip empty lines and comments
    if (line.len == 0 or line[0] == '#') return null;

    // Find the first dot — separates tile instance from feature
    const dot_pos = std.mem.indexOfScalar(u8, line, '.') orelse return null;
    if (dot_pos == 0 or dot_pos >= line.len - 1) return null;

    const tile_name = line[0..dot_pos];
    const feature = line[dot_pos + 1 ..];

    // Extract tile type from tile name by removing _X#Y# suffix
    // E.g. "CLBLL_L_X2Y148" -> "CLBLL_L"
    //       "INT_L_X0Y136"  -> "INT_L"
    //       "LIOB33_X0Y75"  -> "LIOB33"
    const tile_type = extractTileType(tile_name) orelse return null;

    return .{
        .tile_type = tile_type,
        .tile_name = tile_name,
        .feature = feature,
    };
}

/// Extract tile type from tile instance name.
/// Removes the _X#Y# coordinate suffix.
fn extractTileType(tile_name: []const u8) ?[]const u8 {
    // Find last _X followed by digits, then Y followed by digits
    // Scan from the end
    var i: usize = tile_name.len;
    while (i > 0) {
        i -= 1;
        if (tile_name[i] == 'Y') {
            // Check if everything after Y is digits
            var all_digits = true;
            var j = i + 1;
            while (j < tile_name.len) : (j += 1) {
                if (tile_name[j] < '0' or tile_name[j] > '9') {
                    all_digits = false;
                    break;
                }
            }
            if (!all_digits or j == i + 1) continue;

            // Now look for _X before the Y
            if (i < 2) continue;
            var k = i - 1;
            while (k > 0 and tile_name[k] >= '0' and tile_name[k] <= '9') {
                k -= 1;
            }
            if (tile_name[k] == 'X' and k > 0 and tile_name[k - 1] == '_') {
                return tile_name[0 .. k - 1];
            }
        }
    }
    return null;
}

// =============================================================================
// Feature Lookup and Application
// =============================================================================

/// Look up the segbits for a FASM feature in the comptime data tables.
/// Returns the bit mappings if found.
pub fn lookupFeature(tile_type: []const u8, feature: []const u8) ?[]const segbits_data.SegBit {
    // Get feature table for this tile type
    const features = segbits_data.getFeaturesForTileType(tile_type) orelse return null;

    // Construct the full feature key: TILE_TYPE.feature
    // The segbits_data has keys like "CLBLL_L.SLICEL_X0.AFF.ZINI"
    // Our tile_type is "CLBLL_L" and feature is "SLICEL_X0.AFF.ZINI"
    // The segbits key is TILE_TYPE + "." + feature

    // Binary search for this feature
    // The feature entries already include tile_type prefix (e.g., "CLBLL_L.SLICEL_X0.AFF.ZINI")
    // We need to search for tile_type + "." + feature

    // Linear scan since features have the full key
    for (features) |entry| {
        // entry.feature is "CLBLL_L.SLICEL_X0.AFF.ZINI"
        // We want to match against tile_type + "." + feature
        // Check if entry starts with tile_type + "." and rest matches feature
        if (entry.feature.len > tile_type.len + 1 and
            std.mem.eql(u8, entry.feature[0..tile_type.len], tile_type) and
            entry.feature[tile_type.len] == '.' and
            std.mem.eql(u8, entry.feature[tile_type.len + 1 ..], feature))
        {
            return entry.bits;
        }
    }

    return null;
}

/// Apply FASM features to a frame array.
/// Resolves tile instances to frame addresses using tilegrid data from
/// segbits_data (generated from prjxray-db tilegrid.json).
/// Uses far_table for FAR-to-linear-index mapping.
/// Looks up segbits for each feature, and sets/clears bits.
///
/// Handles bit-vector features like ALUT.INIT[63:0] = 64'b... by expanding
/// them into individual bit lookups (ALUT.INIT[00], ALUT.INIT[01], etc.)
pub fn applyFeatures(
    features: []const FasmFeature,
    frames: []u32,
    device: DeviceId,
) ApplyStats {
    _ = device; // Frame base addresses come from tilegrid lookup

    var stats = ApplyStats{
        .features_applied = 0,
        .bits_set = 0,
        .bits_cleared = 0,
        .features_skipped = 0,
        .unknown_tile_types = 0,
        .unknown_features = 0,
    };

    const frame_words: u32 = 101;

    for (features) |fasm| {
        const parsed = parseFasmLine(fasm.line) orelse {
            stats.features_skipped += 1;
            continue;
        };

        // Check if this is a bit-vector feature (e.g., ALUT.INIT[63:0] = 64'b...)
        if (parseBitVector(parsed.feature)) |bv| {
            // Look up tile instance
            const tile = segbits_data.findTileInstance(parsed.tile_type, parsed.tile_name) orelse {
                stats.features_skipped += 1;
                continue;
            };

            // Expand bit-vector into individual bit features
            var any_applied = false;
            var bit_idx: u7 = 0;
            while (bit_idx <= bv.hi) : (bit_idx += 1) {
                // Check if this bit is set in the value
                if ((bv.value >> @as(u6, @intCast(bit_idx))) & 1 == 0) continue;

                // Build feature name: e.g., "SLICEL_X0.ALUT.INIT[05]"
                var feat_buf: [128]u8 = undefined;
                const feat_name = formatBitFeature(&feat_buf, bv.base_feature, bit_idx) orelse continue;

                // Look up segbits for this individual bit
                const bits = lookupFeature(parsed.tile_type, feat_name) orelse continue;

                // Apply each config bit
                for (bits) |bit| {
                    applyBit(frames, tile, bit, frame_words, &stats);
                }
                any_applied = true;
            }
            if (any_applied) {
                stats.features_applied += 1;
            } else {
                stats.unknown_features += 1;
            }
            continue;
        }

        // Standard feature lookup (non-bit-vector)
        const bits = lookupFeature(parsed.tile_type, parsed.feature) orelse {
            stats.unknown_features += 1;
            continue;
        };

        // Look up tile instance in tilegrid for real frame base address AND word offset
        const tile = segbits_data.findTileInstance(parsed.tile_type, parsed.tile_name) orelse {
            stats.features_skipped += 1;
            continue;
        };

        // Apply each bit
        for (bits) |bit| {
            applyBit(frames, tile, bit, frame_words, &stats);
        }

        stats.features_applied += 1;
    }

    return stats;
}

/// Apply a single segbit to the frame array.
fn applyBit(
    frames: []u32,
    tile: *const segbits_data.TileInstance,
    bit: segbits_data.SegBit,
    frame_words: u32,
    stats: *ApplyStats,
) void {
    const frame_far = tile.baseaddr + @as(u32, bit.frame_offset);
    const linear_idx = far_table.farToLinear(frame_far) orelse return;
    const word_in_frame = @as(u32, tile.offset) + @as(u32, bit.bit_index) / 32;
    const bit_in_word = @as(u5, @intCast(@as(u32, bit.bit_index) % 32));
    const abs_word = linear_idx * frame_words + word_in_frame;
    if (abs_word >= frames.len) return;

    if (bit.inverted) {
        frames[abs_word] &= ~(@as(u32, 1) << bit_in_word);
        stats.bits_cleared += 1;
    } else {
        frames[abs_word] |= @as(u32, 1) << bit_in_word;
        stats.bits_set += 1;
    }
}

/// Parse a bit-vector FASM feature like "SLICEL_X0.ALUT.INIT[63:0] = 64'b0101..."
/// Returns the base feature name (before [), the bit range, and the parsed value.
fn parseBitVector(feature: []const u8) ?struct {
    base_feature: []const u8,
    hi: u7,
    value: u64,
} {
    // Find '[' in feature
    const bracket_pos = std.mem.indexOfScalar(u8, feature, '[') orelse return null;

    // Find ':' for range (must be [HI:LO])
    const rest_after_bracket = feature[bracket_pos + 1 ..];
    const colon_pos = std.mem.indexOfScalar(u8, rest_after_bracket, ':') orelse return null;

    // Find closing ']'
    const close_bracket = std.mem.indexOfScalar(u8, rest_after_bracket, ']') orelse return null;
    if (colon_pos >= close_bracket) return null;

    // Parse HI:LO
    const hi_str = rest_after_bracket[0..colon_pos];
    const lo_str = rest_after_bracket[colon_pos + 1 .. close_bracket];
    const hi = std.fmt.parseInt(u7, hi_str, 10) catch return null;
    const lo = std.fmt.parseInt(u7, lo_str, 10) catch return null;
    if (lo != 0 or hi > 63) return null; // Only support [63:0] style ranges

    // Find "= " followed by value
    const after_bracket = feature[bracket_pos + close_bracket + 2 ..]; // after ']'
    const eq_pos = std.mem.indexOf(u8, after_bracket, "= ") orelse return null;
    const value_str = std.mem.trimLeft(u8, after_bracket[eq_pos + 2 ..], " ");

    // Parse value: N'bBBBBBBBBBBBBBBBBBBBB or N'hHHHH
    const value = parseFasmValue(value_str, hi + 1) orelse return null;

    return .{
        .base_feature = feature[0..bracket_pos],
        .hi = hi,
        .value = value,
    };
}

/// Parse a FASM value like "64'b010101..." or "64'hABCD..."
fn parseFasmValue(value_str: []const u8, expected_bits: u8) ?u64 {
    _ = expected_bits;
    // Find the tick mark
    const tick_pos = std.mem.indexOfScalar(u8, value_str, '\'') orelse return null;
    if (tick_pos + 1 >= value_str.len) return null;

    const radix_char = value_str[tick_pos + 1];
    const digits = value_str[tick_pos + 2 ..];

    switch (radix_char) {
        'b' => {
            // Binary: MSB first, parse to u64
            var result: u64 = 0;
            for (digits) |ch| {
                if (ch == '0') {
                    result = result << 1;
                } else if (ch == '1') {
                    result = (result << 1) | 1;
                } else {
                    break; // stop at whitespace/newline
                }
            }
            return result;
        },
        'h' => {
            // Hex: parse directly
            var result: u64 = 0;
            for (digits) |ch| {
                const nibble: u64 = if (ch >= '0' and ch <= '9')
                    ch - '0'
                else if (ch >= 'a' and ch <= 'f')
                    ch - 'a' + 10
                else if (ch >= 'A' and ch <= 'F')
                    ch - 'A' + 10
                else
                    break;
                result = (result << 4) | nibble;
            }
            return result;
        },
        else => return null,
    }
}

/// Format a bit index into a feature name like "SLICEL_X0.ALUT.INIT[05]"
fn formatBitFeature(buf: []u8, base: []const u8, bit_idx: u7) ?[]const u8 {
    // base = "SLICEL_X0.ALUT.INIT", bit_idx = 5 → "SLICEL_X0.ALUT.INIT[05]"
    if (base.len + 5 > buf.len) return null; // [XX]\0
    @memcpy(buf[0..base.len], base);
    buf[base.len] = '[';
    buf[base.len + 1] = '0' + bit_idx / 10;
    buf[base.len + 2] = '0' + bit_idx % 10;
    buf[base.len + 3] = ']';
    return buf[0 .. base.len + 4];
}

// =============================================================================
// Coordinate Parsing
// =============================================================================

fn parseTileCoords(tile_name: []const u8) ?struct { x: u16, y: u16 } {
    // Find _X#Y# pattern
    var i: usize = tile_name.len;
    while (i > 0) {
        i -= 1;
        if (tile_name[i] == 'Y') {
            var j = i + 1;
            while (j < tile_name.len and tile_name[j] >= '0' and tile_name[j] <= '9') : (j += 1) {}
            if (j == i + 1) continue;
            const y = std.fmt.parseInt(u16, tile_name[i + 1 .. j], 10) catch continue;

            // Find X before Y
            var k = i;
            while (k > 0) : (k -= 1) {
                if (tile_name[k] == 'X') break;
            }
            if (tile_name[k] != 'X') continue;
            const x_start = k + 1;
            var x_end = k + 1;
            while (x_end < i and tile_name[x_end] >= '0' and tile_name[x_end] <= '9') : (x_end += 1) {}
            if (x_end == x_start) continue;
            const x = std.fmt.parseInt(u16, tile_name[x_start..x_end], 10) catch continue;

            return .{ .x = x, .y = y };
        }
    }
    return null;
}

/// Compute base frame address from tile type and tile instance name.
/// Uses the real tilegrid data from prjxray-db (via segbits_data.zig).
/// The tilegrid maps each tile instance (e.g., "CLBLL_L_X2Y148") to its
/// actual frame base address, which encodes block_type, half, row, and column.
fn computeBaseFrame(tile_type: []const u8, tile_name: []const u8) ?u32 {
    const tile = segbits_data.findTileInstance(tile_type, tile_name) orelse return null;
    return tile.baseaddr;
}

// =============================================================================
// Tests
// =============================================================================

test "parse FASM line" {
    const result = parseFasmLine("CLBLL_L_X2Y148.SLICEL_X0.ALUT.INIT[0]");
    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectEqualStrings("CLBLL_L", r.tile_type);
    try std.testing.expectEqualStrings("CLBLL_L_X2Y148", r.tile_name);
    try std.testing.expectEqualStrings("SLICEL_X0.ALUT.INIT[0]", r.feature);
}

test "parse FASM line INT" {
    const result = parseFasmLine("INT_L_X0Y136.IMUX_L34.VCC_WIRE");
    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectEqualStrings("INT_L", r.tile_type);
    try std.testing.expectEqualStrings("INT_L_X0Y136", r.tile_name);
    try std.testing.expectEqualStrings("IMUX_L34.VCC_WIRE", r.feature);
}

test "parse FASM line IOB" {
    const result = parseFasmLine("LIOB33_X0Y75.IOB_Y1.PULLTYPE.NONE");
    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectEqualStrings("LIOB33", r.tile_type);
    try std.testing.expectEqualStrings("LIOB33_X0Y75", r.tile_name);
    try std.testing.expectEqualStrings("IOB_Y1.PULLTYPE.NONE", r.feature);
}

test "extract tile type" {
    try std.testing.expectEqualStrings("CLBLL_L", extractTileType("CLBLL_L_X2Y148").?);
    try std.testing.expectEqualStrings("INT_L", extractTileType("INT_L_X0Y136").?);
    try std.testing.expectEqualStrings("LIOB33", extractTileType("LIOB33_X0Y75").?);
    try std.testing.expectEqualStrings("LIOI3", extractTileType("LIOI3_X0Y135").?);
    try std.testing.expectEqualStrings("CLK_BUFG_BOT_R", extractTileType("CLK_BUFG_BOT_R_X60Y48").?);
}

test "parse tile coords" {
    const c1 = parseTileCoords("CLBLL_L_X2Y148").?;
    try std.testing.expectEqual(@as(u16, 2), c1.x);
    try std.testing.expectEqual(@as(u16, 148), c1.y);

    const c2 = parseTileCoords("INT_L_X0Y136").?;
    try std.testing.expectEqual(@as(u16, 0), c2.x);
    try std.testing.expectEqual(@as(u16, 136), c2.y);
}

test "segbits data accessible" {
    try std.testing.expect(segbits_data.total_features > 0);
    try std.testing.expect(segbits_data.total_bits > 0);
    try std.testing.expect(segbits_data.tile_type_count > 0);
}

test "feature lookup CLB" {
    // Look up a known CLB feature
    const bits = lookupFeature("CLBLL_L", "SLICEL_X0.AFF.ZINI");
    try std.testing.expect(bits != null);
    try std.testing.expect(bits.?.len > 0);
}

test "feature lookup IOB" {
    const bits = lookupFeature("LIOB33", "IOB_Y0.PULLTYPE.NONE");
    try std.testing.expect(bits != null);
    try std.testing.expect(bits.?.len > 0);
}

test "feature lookup INT routing PIPs" {
    // These are the exact PIP formats our router generates
    const ee = lookupFeature("INT_L", "EE2BEG0.EE2END0");
    try std.testing.expect(ee != null);
    try std.testing.expect(ee.?.len > 0);

    const nn = lookupFeature("INT_L", "NN2BEG0.NN2END0");
    try std.testing.expect(nn != null);

    const ss = lookupFeature("INT_L", "SS2BEG0.SS2END0");
    try std.testing.expect(ss != null);

    const ww = lookupFeature("INT_L", "WW2BEG0.WW2END0");
    try std.testing.expect(ww != null);

    // INT_R variants
    const ee_r = lookupFeature("INT_R", "EE2BEG0.EE2END0");
    try std.testing.expect(ee_r != null);

    const nn_r = lookupFeature("INT_R", "NN2BEG0.NN2END0");
    try std.testing.expect(nn_r != null);
}

test "parse INT routing FASM line" {
    // Full FASM line as generated by our pipeline
    const result = parseFasmLine("INT_L_X10Y15.EE2BEG0.EE2END0");
    try std.testing.expect(result != null);
    const r = result.?;
    try std.testing.expectEqualStrings("INT_L", r.tile_type);
    try std.testing.expectEqualStrings("INT_L_X10Y15", r.tile_name);
    try std.testing.expectEqualStrings("EE2BEG0.EE2END0", r.feature);
}

test "tilegrid lookup for reference tiles" {
    // These are the tiles from trinity.fasm (reference passthrough design)
    // Verify that computeBaseFrame returns correct tilegrid addresses

    // LIOB33_X0Y75 → baseaddr 0x00400000
    const liob75 = computeBaseFrame("LIOB33", "LIOB33_X0Y75");
    try std.testing.expect(liob75 != null);
    try std.testing.expectEqual(@as(u32, 0x00400000), liob75.?);

    // LIOB33_X0Y135 → baseaddr 0x00000000
    const liob135 = computeBaseFrame("LIOB33", "LIOB33_X0Y135");
    try std.testing.expect(liob135 != null);
    try std.testing.expectEqual(@as(u32, 0x00000000), liob135.?);

    // INT_L_X0Y136 → baseaddr 0x00000000
    const int136 = computeBaseFrame("INT_L", "INT_L_X0Y136");
    try std.testing.expect(int136 != null);
    try std.testing.expectEqual(@as(u32, 0x00000000), int136.?);

    // LIOI3_X0Y135 → baseaddr 0x00000000
    const lioi135 = computeBaseFrame("LIOI3", "LIOI3_X0Y135");
    try std.testing.expect(lioi135 != null);
    try std.testing.expectEqual(@as(u32, 0x00000000), lioi135.?);
}

test "unknown tile returns null" {
    const result = computeBaseFrame("CLBLL_L", "CLBLL_L_X999Y999");
    try std.testing.expect(result == null);
}

test "empty line returns null" {
    try std.testing.expect(parseFasmLine("") == null);
    try std.testing.expect(parseFasmLine("#comment") == null);
}

test "parseBitVector binary" {
    const bv = parseBitVector("SLICEL_X0.ALUT.INIT[63:0] = 64'b0000111100001111000011110000111100001111000011110000111100001111");
    try std.testing.expect(bv != null);
    const r = bv.?;
    try std.testing.expectEqualStrings("SLICEL_X0.ALUT.INIT", r.base_feature);
    try std.testing.expectEqual(@as(u7, 63), r.hi);
    // Binary: 0x0F0F0F0F0F0F0F0F (MSB first)
    try std.testing.expectEqual(@as(u64, 0x0F0F0F0F0F0F0F0F), r.value);
}

test "parseBitVector non-vector returns null" {
    // Standard feature without bit range
    try std.testing.expect(parseBitVector("SLICEL_X0.AFF.ZINI") == null);
    // Single bit (no colon in range)
    try std.testing.expect(parseBitVector("SLICEL_X0.ALUT.INIT[0]") == null);
}

test "formatBitFeature" {
    var buf: [128]u8 = undefined;
    const r0 = formatBitFeature(&buf, "SLICEL_X0.ALUT.INIT", 0).?;
    try std.testing.expectEqualStrings("SLICEL_X0.ALUT.INIT[00]", r0);

    const r42 = formatBitFeature(&buf, "SLICEL_X0.ALUT.INIT", 42).?;
    try std.testing.expectEqualStrings("SLICEL_X0.ALUT.INIT[42]", r42);

    const r63 = formatBitFeature(&buf, "SLICEL_X0.ALUT.INIT", 63).?;
    try std.testing.expectEqualStrings("SLICEL_X0.ALUT.INIT[63]", r63);
}

test "LUT INIT expansion applies bits" {
    // Test that a full FASM line with INIT value gets expanded correctly
    const line = "CLBLL_L_X2Y142.SLICEL_X0.ALUT.INIT[63:0] = 64'b0000111100001111000011110000111100001111000011110000111100001111";
    const parsed = parseFasmLine(line);
    try std.testing.expect(parsed != null);
    const p = parsed.?;
    try std.testing.expectEqualStrings("CLBLL_L", p.tile_type);

    // The feature should contain the full INIT value
    const bv = parseBitVector(p.feature);
    try std.testing.expect(bv != null);
    try std.testing.expectEqualStrings("SLICEL_X0.ALUT.INIT", bv.?.base_feature);
    try std.testing.expectEqual(@as(u64, 0x0F0F0F0F0F0F0F0F), bv.?.value);
}
