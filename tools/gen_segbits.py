#!/usr/bin/env python3
"""
FORGE OF KOSCHEI — Segbits Data Generator

Auto-downloads prjxray-db and generates segbits_data.zig with comptime lookup tables.

Usage:
    python3 tools/gen_segbits.py [--output src/forge/segbits_data.zig] [--device artix7]

Pipeline:
    1. Clone prjxray-db (shallow) to /tmp/prjxray-db (if not cached)
    2. Parse segbits_*.db for required tile types
    3. Parse tilegrid.json for tile -> frame address mapping
    4. Generate segbits_data.zig with comptime arrays
    5. Clean up (optional)

Sacred Formula: phi^2 + 1/phi^2 = 3
"""

import os
import sys
import json
import shutil
import argparse
import subprocess
from pathlib import Path
from collections import defaultdict

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

PRJXRAY_DB_REPO = "https://github.com/f4pga/prjxray-db.git"
PRJXRAY_DB_DIR = "/tmp/prjxray-db"

# Tile types we need segbits for
REQUIRED_TILE_TYPES = [
    "clbll_l",
    "clbll_r",
    "clblm_l",
    "clblm_r",
    "int_l",
    "int_r",
    "liob33",
    "lioi3",
    "riob33",
    "rioi3",
    "io_int_interface_l",
    "io_int_interface_r",
    "clk_bufg_bot_r",
    "clk_bufg_top_r",
    "clk_bufg_rebuf",
    "clk_hrow_bot_r",
    "clk_hrow_top_r",
    "hclk_l",
    "hclk_r",
    "hclk_cmt",
    "hclk_cmt_l",
    "bram_l",
    "bram_r",
    "dsp_l",
    "dsp_r",
]

# XC7A100T FGG676 for QMTECH board (also covers xc7a35t via shared tilegrid)
TARGET_PART = "xc7a100t"
TARGET_FAMILY = "artix7"


# ═══════════════════════════════════════════════════════════════════════════
# Step 1: Download prjxray-db
# ═══════════════════════════════════════════════════════════════════════════

def download_prjxray_db(force=False):
    """Clone prjxray-db shallow to /tmp."""
    if os.path.exists(PRJXRAY_DB_DIR) and not force:
        print(f"  Using cached prjxray-db at {PRJXRAY_DB_DIR}")
        return

    if os.path.exists(PRJXRAY_DB_DIR):
        shutil.rmtree(PRJXRAY_DB_DIR)

    print(f"  Cloning prjxray-db (shallow)...")
    subprocess.check_call([
        "git", "clone", "--depth", "1",
        PRJXRAY_DB_REPO, PRJXRAY_DB_DIR
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"  Done. Cached at {PRJXRAY_DB_DIR}")


# ═══════════════════════════════════════════════════════════════════════════
# Step 2: Parse segbits_*.db files
# ═══════════════════════════════════════════════════════════════════════════

def parse_segbits_file(filepath):
    """
    Parse a segbits_*.db file.

    Format: TILE_TYPE.FEATURE frame_bit [!frame_bit ...]
    Where frame_bit = NN_MM (frame_offset=NN, bit=MM)
    ! prefix means bit must be 0 (inverted)

    Returns: list of (feature_name, [(frame_offset, bit_index, inverted), ...])
    """
    entries = []
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            parts = line.split()
            if len(parts) < 2:
                continue

            feature = parts[0]
            bits = []
            for bit_str in parts[1:]:
                inverted = bit_str.startswith('!')
                if inverted:
                    bit_str = bit_str[1:]

                try:
                    frame_str, bit_str_val = bit_str.split('_')
                    frame_offset = int(frame_str)
                    bit_index = int(bit_str_val)
                    bits.append((frame_offset, bit_index, inverted))
                except (ValueError, IndexError):
                    continue

            if bits:
                entries.append((feature, bits))

    return entries


def load_all_segbits(family_dir):
    """Load segbits for all required tile types."""
    all_segbits = {}
    found_types = set()

    for tile_type in REQUIRED_TILE_TYPES:
        filename = f"segbits_{tile_type}.db"
        filepath = os.path.join(family_dir, filename)

        if not os.path.exists(filepath):
            continue

        entries = parse_segbits_file(filepath)
        if entries:
            all_segbits[tile_type.upper()] = entries
            found_types.add(tile_type)
            print(f"    {tile_type}: {len(entries)} features")

    print(f"  Loaded {len(found_types)}/{len(REQUIRED_TILE_TYPES)} tile types")
    return all_segbits


# ═══════════════════════════════════════════════════════════════════════════
# Step 3: Parse tilegrid.json
# ═══════════════════════════════════════════════════════════════════════════

def load_tilegrid(part_dir):
    """
    Load tilegrid.json for frame address mapping.
    Returns: dict of tile_name -> {type, baseaddr, frames, offset, words}
    """
    tilegrid_path = os.path.join(part_dir, "tilegrid.json")
    if not os.path.exists(tilegrid_path):
        # Try the family-level tilegrid
        tilegrid_path = os.path.join(os.path.dirname(part_dir), "tilegrid.json")

    if not os.path.exists(tilegrid_path):
        print(f"  WARNING: tilegrid.json not found, using segbits-only mode")
        return {}

    print(f"  Loading tilegrid from {tilegrid_path}")
    with open(tilegrid_path, 'r') as f:
        data = json.load(f)

    tiles = {}
    for tile_name, tile_info in data.items():
        tile_type = tile_info.get("type", "")
        bits = tile_info.get("bits", {})

        # The bits dict may have segment keys like "CLB_IO_CLK"
        for seg_name, seg_info in bits.items():
            baseaddr = seg_info.get("baseaddr", None)
            if baseaddr is not None:
                # Parse hex baseaddr
                if isinstance(baseaddr, str):
                    baseaddr = int(baseaddr, 16)
                tiles[tile_name] = {
                    "type": tile_type,
                    "baseaddr": baseaddr,
                    "frames": seg_info.get("frames", 0),
                    "offset": seg_info.get("offset", 0),
                    "words": seg_info.get("words", 0),
                }
                break  # Take first segment

    print(f"  Loaded {len(tiles)} tiles from tilegrid")
    return tiles


# ═══════════════════════════════════════════════════════════════════════════
# Step 4: Generate segbits_data.zig
# ═══════════════════════════════════════════════════════════════════════════

def generate_zig_segbits(all_segbits, tilegrid, output_path):
    """Generate segbits_data.zig with comptime lookup tables."""

    # Count total entries
    total_features = sum(len(entries) for entries in all_segbits.values())
    total_bits = sum(
        sum(len(bits) for _, bits in entries)
        for entries in all_segbits.values()
    )

    print(f"  Generating {output_path}")
    print(f"    Total features: {total_features}")
    print(f"    Total bit mappings: {total_bits}")
    print(f"    Tile types: {len(all_segbits)}")

    lines = []
    lines.append("// =============================================================================")
    lines.append("// FORGE OF KOSCHEI v2.0 — Generated Segbits Data")
    lines.append("// =============================================================================")
    lines.append("//")
    lines.append("// AUTO-GENERATED by tools/gen_segbits.py — DO NOT EDIT")
    lines.append(f"// Source: prjxray-db/{TARGET_FAMILY}")
    lines.append(f"// Target: {TARGET_PART}")
    lines.append(f"// Total features: {total_features}")
    lines.append(f"// Total bit mappings: {total_bits}")
    lines.append(f"// Tile types: {len(all_segbits)}")
    lines.append("//")
    lines.append("// Sacred Formula: phi^2 + 1/phi^2 = 3")
    lines.append("//")
    lines.append("// =============================================================================")
    lines.append("")
    lines.append("const std = @import(\"std\");")
    lines.append("")

    # --- Bit entry struct ---
    lines.append("/// A single bit in a segbit mapping.")
    lines.append("pub const SegBit = struct {")
    lines.append("    frame_offset: u8,")
    lines.append("    bit_index: u16,")
    lines.append("    inverted: bool,")
    lines.append("};")
    lines.append("")

    # --- Feature entry struct ---
    lines.append("/// A FASM feature mapped to one or more configuration bits.")
    lines.append("pub const FeatureEntry = struct {")
    lines.append("    feature: []const u8,")
    lines.append("    bits: []const SegBit,")
    lines.append("};")
    lines.append("")

    # --- Tile type enum ---
    lines.append("/// Supported tile types with segbits data.")
    lines.append("pub const TileType = enum {")
    for tile_type in sorted(all_segbits.keys()):
        zig_name = tile_type.lower()
        lines.append(f"    {zig_name},")
    lines.append("};")
    lines.append("")

    # --- Per-tile-type feature arrays ---
    for tile_type in sorted(all_segbits.keys()):
        entries = all_segbits[tile_type]
        zig_name = tile_type.lower()

        # Sort entries by feature name for binary search
        entries.sort(key=lambda x: x[0])

        # Generate bits arrays first
        for i, (feature, bits) in enumerate(entries):
            bits_name = f"_{zig_name}_bits_{i}"
            bits_strs = []
            for frame_off, bit_idx, inv in bits:
                inv_str = "true" if inv else "false"
                bits_strs.append(f".{{ .frame_offset = {frame_off}, .bit_index = {bit_idx}, .inverted = {inv_str} }}")

            lines.append(f"const {bits_name} = [_]SegBit{{ {', '.join(bits_strs)} }};")

        lines.append("")

        # Generate feature table
        lines.append(f"pub const {zig_name}_features = [_]FeatureEntry{{")
        for i, (feature, bits) in enumerate(entries):
            bits_name = f"_{zig_name}_bits_{i}"
            lines.append(f"    .{{ .feature = \"{feature}\", .bits = &{bits_name} }},")
        lines.append("};")
        lines.append("")

    # --- Tilegrid data (tile instance -> frame address) ---
    # Group tiles by type
    tiles_by_type = defaultdict(list)
    for tile_name, info in tilegrid.items():
        tile_type = info["type"]
        if tile_type.upper() in all_segbits:
            tiles_by_type[tile_type.upper()].append((tile_name, info))

    if tiles_by_type:
        lines.append("// =============================================================================")
        lines.append("// Tilegrid: Tile Instance -> Frame Address Mapping")
        lines.append("// =============================================================================")
        lines.append("")
        lines.append("pub const TileInstance = struct {")
        lines.append("    name: []const u8,")
        lines.append("    baseaddr: u32,")
        lines.append("    frames: u16,")
        lines.append("    offset: u16,")
        lines.append("    words: u16,")
        lines.append("};")
        lines.append("")

        for tile_type in sorted(tiles_by_type.keys()):
            tiles = tiles_by_type[tile_type]
            tiles.sort(key=lambda x: x[0])  # Sort by name
            zig_name = tile_type.lower()

            lines.append(f"pub const {zig_name}_tiles = [_]TileInstance{{")
            for tile_name, info in tiles:
                baseaddr = info["baseaddr"]
                frames = info.get("frames", 0)
                offset = info.get("offset", 0)
                words = info.get("words", 0)
                lines.append(f"    .{{ .name = \"{tile_name}\", .baseaddr = 0x{baseaddr:08X}, .frames = {frames}, .offset = {offset}, .words = {words} }},")
            lines.append("};")
            lines.append("")

    # --- Lookup function ---
    lines.append("// =============================================================================")
    lines.append("// Lookup Functions")
    lines.append("// =============================================================================")
    lines.append("")
    lines.append("/// Get feature entries for a tile type by name.")
    lines.append("pub fn getFeaturesForTileType(tile_type_name: []const u8) ?[]const FeatureEntry {")

    for tile_type in sorted(all_segbits.keys()):
        zig_name = tile_type.lower()
        lines.append(f"    if (std.mem.eql(u8, tile_type_name, \"{tile_type}\")) return &{zig_name}_features;")

    lines.append("    return null;")
    lines.append("}")
    lines.append("")

    lines.append("/// Binary search for a feature within a tile type's feature table.")
    lines.append("pub fn findFeature(features: []const FeatureEntry, name: []const u8) ?*const FeatureEntry {")
    lines.append("    var lo: usize = 0;")
    lines.append("    var hi: usize = features.len;")
    lines.append("    while (lo < hi) {")
    lines.append("        const mid = lo + (hi - lo) / 2;")
    lines.append("        const cmp = std.mem.order(u8, features[mid].feature, name);")
    lines.append("        switch (cmp) {")
    lines.append("            .eq => return &features[mid],")
    lines.append("            .lt => lo = mid + 1,")
    lines.append("            .gt => hi = mid,")
    lines.append("        }")
    lines.append("    }")
    lines.append("    return null;")
    lines.append("}")
    lines.append("")

    # --- Tile instance lookup ---
    if tiles_by_type:
        lines.append("/// Find a tile instance by name, returns its base frame address.")
        lines.append("pub fn findTileInstance(tile_type_name: []const u8, tile_name: []const u8) ?*const TileInstance {")

        for tile_type in sorted(tiles_by_type.keys()):
            zig_name = tile_type.lower()
            lines.append(f"    if (std.mem.eql(u8, tile_type_name, \"{tile_type}\")) {{")
            lines.append(f"        for (&{zig_name}_tiles) |*tile| {{")
            lines.append(f"            if (std.mem.eql(u8, tile.name, tile_name)) return tile;")
            lines.append(f"        }}")
            lines.append(f"        return null;")
            lines.append(f"    }}")

        lines.append("    return null;")
        lines.append("}")
        lines.append("")

    # --- Stats ---
    lines.append("// =============================================================================")
    lines.append("// Statistics")
    lines.append("// =============================================================================")
    lines.append("")
    lines.append(f"pub const total_features: u32 = {total_features};")
    lines.append(f"pub const total_bits: u32 = {total_bits};")
    lines.append(f"pub const tile_type_count: u32 = {len(all_segbits)};")
    lines.append("")

    # --- Tests ---
    lines.append("// =============================================================================")
    lines.append("// Tests")
    lines.append("// =============================================================================")
    lines.append("")
    lines.append("test \"segbits data loaded\" {")
    lines.append(f"    try std.testing.expect(total_features > 0);")
    lines.append(f"    try std.testing.expect(total_bits > 0);")
    lines.append(f"    try std.testing.expect(tile_type_count > 0);")
    lines.append("}")
    lines.append("")
    lines.append("test \"feature lookup\" {")

    # Pick first available tile type for test
    first_type = sorted(all_segbits.keys())[0]
    first_entries = all_segbits[first_type]
    if first_entries:
        first_feature = first_entries[0][0]
        zig_name = first_type.lower()
        lines.append(f"    const features = &{zig_name}_features;")
        lines.append(f"    const found = findFeature(features, \"{first_feature}\");")
        lines.append(f"    try std.testing.expect(found != null);")

    lines.append("}")
    lines.append("")
    lines.append("test \"tile type lookup\" {")
    first_type = sorted(all_segbits.keys())[0]
    lines.append(f"    const features = getFeaturesForTileType(\"{first_type}\");")
    lines.append(f"    try std.testing.expect(features != null);")
    lines.append(f"    try std.testing.expect(features.?.len > 0);")
    lines.append("}")
    lines.append("")

    # Write file
    content = '\n'.join(lines) + '\n'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(content)

    file_size = os.path.getsize(output_path)
    print(f"  Generated {output_path} ({file_size:,} bytes)")
    return total_features, total_bits


# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="FORGE OF KOSCHEI — Generate segbits_data.zig from prjxray-db"
    )
    parser.add_argument(
        "--output", "-o",
        default="src/forge/segbits_data.zig",
        help="Output path for segbits_data.zig"
    )
    parser.add_argument(
        "--family",
        default=TARGET_FAMILY,
        help="FPGA family (default: artix7)"
    )
    parser.add_argument(
        "--part",
        default=TARGET_PART,
        help="Target part (default: xc7a35tcsg324-1)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force re-download prjxray-db"
    )
    parser.add_argument(
        "--keep",
        action="store_true",
        help="Keep prjxray-db after generation"
    )

    args = parser.parse_args()

    print("═══════════════════════════════════════════════════════")
    print("  FORGE OF KOSCHEI — Segbits Generator")
    print("  φ² + 1/φ² = 3")
    print("═══════════════════════════════════════════════════════")
    print()

    # Step 1: Download
    print("[1/4] Downloading prjxray-db...")
    download_prjxray_db(force=args.force)
    print()

    # Step 2: Parse segbits
    print("[2/4] Parsing segbits...")
    family_dir = os.path.join(PRJXRAY_DB_DIR, args.family)
    if not os.path.exists(family_dir):
        print(f"  ERROR: Family directory not found: {family_dir}")
        sys.exit(1)

    all_segbits = load_all_segbits(family_dir)
    if not all_segbits:
        print("  ERROR: No segbits found!")
        sys.exit(1)
    print()

    # Step 3: Parse tilegrid
    print("[3/4] Parsing tilegrid...")
    part_dir = os.path.join(family_dir, args.part)
    tilegrid = load_tilegrid(part_dir)
    print()

    # Step 4: Generate Zig
    print("[4/4] Generating Zig code...")
    total_features, total_bits = generate_zig_segbits(
        all_segbits, tilegrid, args.output
    )
    print()

    # Cleanup
    if not args.keep:
        print("  (Use --keep to preserve prjxray-db cache)")

    print("═══════════════════════════════════════════════════════")
    print(f"  DONE: {total_features} features, {total_bits} bits")
    print(f"  Output: {args.output}")
    print("═══════════════════════════════════════════════════════")


if __name__ == "__main__":
    main()
