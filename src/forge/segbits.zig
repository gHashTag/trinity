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
/// Resolves tile instances to frame addresses using device_db,
/// looks up segbits for each feature, and sets/clears bits.
pub fn applyFeatures(
    features: []const FasmFeature,
    frames: []u32,
    device: DeviceId,
) ApplyStats {
    _ = device; // Frame base addresses come from tile coordinates

    var stats = ApplyStats{
        .features_applied = 0,
        .bits_set = 0,
        .bits_cleared = 0,
        .features_skipped = 0,
        .unknown_tile_types = 0,
        .unknown_features = 0,
    };

    for (features) |fasm| {
        const parsed = parseFasmLine(fasm.line) orelse {
            stats.features_skipped += 1;
            continue;
        };

        // Look up segbits for this feature
        const bits = lookupFeature(parsed.tile_type, parsed.feature) orelse {
            stats.unknown_features += 1;
            continue;
        };

        // Parse tile coordinates for frame address
        const coords = parseTileCoords(parsed.tile_name) orelse {
            stats.features_skipped += 1;
            continue;
        };

        // Compute base frame address from tile coordinates
        // For now use a simplified mapping — the real mapping requires
        // the full tilegrid from prjxray-db
        const base_frame = computeBaseFrame(parsed.tile_type, coords.x, coords.y) orelse {
            stats.features_skipped += 1;
            continue;
        };

        // Apply each bit
        for (bits) |bit| {
            const frame_addr = base_frame + @as(u32, bit.frame_offset);
            // bit_index encodes: word_index * 32 + bit_within_word
            // Actually in prjxray: frame_offset is the minor frame number,
            // bit_index is the absolute bit position within the frame (0..3231 for 101 words)
            const word_idx = @as(u32, bit.bit_index) / 32;
            const bit_in_word = @as(u5, @intCast(@as(u32, bit.bit_index) % 32));

            // Compute absolute position in frame array
            const abs_word = frame_addr * 101 + word_idx;
            if (abs_word >= frames.len) continue;

            if (bit.inverted) {
                // Inverted bit: clear it (should be 0)
                frames[abs_word] &= ~(@as(u32, 1) << bit_in_word);
                stats.bits_cleared += 1;
            } else {
                // Normal bit: set it (should be 1)
                frames[abs_word] |= @as(u32, 1) << bit_in_word;
                stats.bits_set += 1;
            }
        }

        stats.features_applied += 1;
    }

    return stats;
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

/// Compute base frame address from tile type and coordinates.
/// This is a simplified mapping for Artix-7 devices.
/// The real mapping comes from tilegrid.json — for now we use
/// the column-based frame address encoding from UG470:
///   [25:23] = block_type (0=CLB/IO/CLK, 1=BRAM content, 2=BRAM reg)
///   [22]    = top/bottom half
///   [21:17] = row address
///   [16:7]  = column address (major)
///   [6:0]   = minor address (within tile's frame range)
fn computeBaseFrame(tile_type: []const u8, x: u16, y: u16) ?u32 {
    // Determine block type and column from tile type
    const block_type: u3 = if (std.mem.startsWith(u8, tile_type, "BRAM"))
        1
    else
        0;

    // Determine top/bottom half (Artix-7 has 2 half-rows)
    // For XC7A35T: rows 0-99 are bottom, 100+ are top
    const half: u1 = if (y >= 100) 1 else 0;

    // Row address within half
    const rows_per_region: u16 = 50;
    const row_in_half = if (y >= 100) (y - 100) / rows_per_region else y / rows_per_region;

    // Column address = x coordinate (simplified)
    const col: u10 = @intCast(x & 0x3FF);

    // Build frame address (minor = 0, will be added by frame_offset from segbits)
    const frame_addr: u32 = (@as(u32, block_type) << 23) |
        (@as(u32, half) << 22) |
        (@as(u32, @as(u5, @intCast(row_in_half & 0x1F))) << 17) |
        (@as(u32, col) << 7) |
        0; // minor = 0

    return frame_addr;
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

test "empty line returns null" {
    try std.testing.expect(parseFasmLine("") == null);
    try std.testing.expect(parseFasmLine("#comment") == null);
}
