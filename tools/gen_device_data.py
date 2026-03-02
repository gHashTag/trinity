#!/usr/bin/env python3
"""Generate xc7a100t_tiles.zig from prjxray-db tilegrid.json + package_pins.csv.

Usage:
    python3 tools/gen_device_data.py

Inputs:
    /tmp/xc7a100t_tilegrid.json            — tile grid from prjxray-db
    /tmp/prjxray-db/artix7/xc7a100tfgg676-1/package_pins.csv — package pin mapping

Output:
    src/forge/xc7a100t_tiles.zig           — comptime tile data for FORGE placer/router
"""

import json
import csv
import re
import sys
from pathlib import Path

TILEGRID_PATH = "/tmp/xc7a100t_tilegrid.json"
PACKAGE_PINS_PATH = "/tmp/prjxray-db/artix7/xc7a100tfgg676-1/package_pins.csv"
OUTPUT_PATH = Path(__file__).parent.parent / "src" / "forge" / "xc7a100t_tiles.zig"

# Tile type classification
CLB_TYPES = {"CLBLL_L", "CLBLL_R", "CLBLM_L", "CLBLM_R"}
IOB_TYPES = {"LIOB33", "LIOB33_SING", "RIOB33", "RIOB33_SING"}
INT_TYPES = {"INT_L", "INT_R"}
BUFG_TYPES = {"CLK_BUFG_BOT_R", "CLK_BUFG_TOP_R"}
HCLK_TYPES = {"HCLK_L", "HCLK_R", "HCLK_CMT", "HCLK_CMT_L"}
CLK_HROW_TYPES = {"CLK_HROW_BOT_R", "CLK_HROW_TOP_R"}
CLK_REBUF_TYPES = {"CLK_BUFG_REBUF"}
LIOI_TYPES = {"LIOI3", "LIOI3_SING", "LIOI3_TBYTESRC", "LIOI3_TBYTETERM"}
RIOI_TYPES = {"RIOI3", "RIOI3_SING", "RIOI3_TBYTESRC", "RIOI3_TBYTETERM"}


def parse_xy(name):
    """Extract X,Y from tile name like CLBLL_L_X2Y69."""
    m = re.search(r'_X(\d+)Y(\d+)$', name)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None, None


def tile_type_enum(tile_type):
    """Convert tile type string to Zig enum name."""
    return tile_type.lower().replace("_sing", "_sing")


def main():
    print(f"Reading tilegrid from {TILEGRID_PATH}...")
    with open(TILEGRID_PATH) as f:
        tilegrid = json.load(f)
    print(f"  {len(tilegrid)} tiles total")

    # Classify tiles
    clb_tiles = []
    iob_tiles = []
    int_tiles = []
    bufg_tiles = []
    hclk_tiles = []
    clk_hrow_tiles = []
    clk_rebuf_tiles = []
    lioi_tiles = []
    rioi_tiles = []

    for tile_name, tile_data in tilegrid.items():
        tile_type = tile_data.get("type", "")
        x, y = parse_xy(tile_name)
        if x is None:
            continue

        entry = {
            "name": tile_name,
            "type": tile_type,
            "x": x,
            "y": y,
            "grid_x": tile_data.get("grid_x", 0),
            "grid_y": tile_data.get("grid_y", 0),
            "sites": tile_data.get("sites", {}),
        }

        if tile_type in CLB_TYPES:
            clb_tiles.append(entry)
        elif tile_type in IOB_TYPES:
            iob_tiles.append(entry)
        elif tile_type in INT_TYPES:
            int_tiles.append(entry)
        elif tile_type in BUFG_TYPES:
            bufg_tiles.append(entry)
        elif tile_type in HCLK_TYPES:
            hclk_tiles.append(entry)
        elif tile_type in CLK_HROW_TYPES:
            clk_hrow_tiles.append(entry)
        elif tile_type in CLK_REBUF_TYPES:
            clk_rebuf_tiles.append(entry)
        elif tile_type in LIOI_TYPES:
            lioi_tiles.append(entry)
        elif tile_type in RIOI_TYPES:
            rioi_tiles.append(entry)

    # Sort all by (x, y)
    for lst in [clb_tiles, iob_tiles, int_tiles, bufg_tiles, hclk_tiles,
                clk_hrow_tiles, clk_rebuf_tiles, lioi_tiles, rioi_tiles]:
        lst.sort(key=lambda t: (t["x"], t["y"]))

    print(f"  CLB:  {len(clb_tiles)}")
    print(f"  IOB:  {len(iob_tiles)}")
    print(f"  INT:  {len(int_tiles)}")
    print(f"  BUFG: {len(bufg_tiles)}")
    print(f"  HCLK: {len(hclk_tiles)}")
    print(f"  CLK_HROW: {len(clk_hrow_tiles)}")
    print(f"  CLK_REBUF: {len(clk_rebuf_tiles)}")
    print(f"  LIOI: {len(lioi_tiles)}")
    print(f"  RIOI: {len(rioi_tiles)}")

    # Read package pins
    print(f"\nReading package pins from {PACKAGE_PINS_PATH}...")
    package_pins = []
    with open(PACKAGE_PINS_PATH) as f:
        reader = csv.DictReader(f)
        for row in reader:
            package_pins.append({
                "pin": row["pin"],
                "bank": int(row["bank"]),
                "site": row["site"],
                "tile": row["tile"],
                "pin_function": row["pin_function"],
            })
    package_pins.sort(key=lambda p: p["pin"])
    print(f"  {len(package_pins)} pins")

    # Get unique CLB X coordinates
    clb_x_coords = sorted(set(t["x"] for t in clb_tiles))
    print(f"\n  CLB X coordinates: {clb_x_coords}")

    # Get CLB Y range
    clb_y_min = min(t["y"] for t in clb_tiles)
    clb_y_max = max(t["y"] for t in clb_tiles)
    print(f"  CLB Y range: {clb_y_min}..{clb_y_max}")

    # Generate Zig file
    print(f"\nWriting {OUTPUT_PATH}...")
    with open(OUTPUT_PATH, "w") as f:
        f.write("// =============================================================================\n")
        f.write("// XC7A100T Tile Data — Auto-generated from prjxray-db\n")
        f.write("// =============================================================================\n")
        f.write("//\n")
        f.write(f"// Generated by tools/gen_device_data.py\n")
        f.write(f"// CLB tiles:  {len(clb_tiles)}\n")
        f.write(f"// IOB tiles:  {len(iob_tiles)}\n")
        f.write(f"// INT tiles:  {len(int_tiles)}\n")
        f.write(f"// BUFG tiles: {len(bufg_tiles)}\n")
        f.write(f"// Package pins: {len(package_pins)}\n")
        f.write("//\n")
        f.write("// =============================================================================\n\n")

        # Tile type enum
        f.write("pub const TileType = enum {\n")
        f.write("    clbll_l,\n")
        f.write("    clbll_r,\n")
        f.write("    clblm_l,\n")
        f.write("    clblm_r,\n")
        f.write("    liob33,\n")
        f.write("    liob33_sing,\n")
        f.write("    riob33,\n")
        f.write("    riob33_sing,\n")
        f.write("    int_l,\n")
        f.write("    int_r,\n")
        f.write("    clk_bufg_bot_r,\n")
        f.write("    clk_bufg_top_r,\n")
        f.write("    clk_bufg_rebuf,\n")
        f.write("    clk_hrow_bot_r,\n")
        f.write("    clk_hrow_top_r,\n")
        f.write("    hclk_l,\n")
        f.write("    hclk_r,\n")
        f.write("    hclk_cmt,\n")
        f.write("    hclk_cmt_l,\n")
        f.write("    lioi3,\n")
        f.write("    lioi3_sing,\n")
        f.write("    lioi3_tbytesrc,\n")
        f.write("    lioi3_tbyteterm,\n")
        f.write("    rioi3,\n")
        f.write("    rioi3_sing,\n")
        f.write("    rioi3_tbytesrc,\n")
        f.write("    rioi3_tbyteterm,\n")
        f.write("};\n\n")

        # CLB tile struct and array
        f.write("pub const ClbTile = struct {\n")
        f.write("    x: u8,\n")
        f.write("    y: u8,\n")
        f.write("    tile_type: TileType,\n")
        f.write("};\n\n")

        f.write(f"pub const clb_count: u32 = {len(clb_tiles)};\n")
        f.write(f"pub const clb_tiles = [_]ClbTile{{\n")
        for t in clb_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # CLB X coordinates (unique, for quick column lookup)
        f.write(f"pub const clb_x_coords = [_]u8{{ ")
        f.write(", ".join(str(x) for x in clb_x_coords))
        f.write(" };\n\n")

        # INT tile struct and array
        f.write("pub const IntTile = struct {\n")
        f.write("    x: u8,\n")
        f.write("    y: u8,\n")
        f.write("    tile_type: TileType,\n")
        f.write("};\n\n")

        f.write(f"pub const int_count: u32 = {len(int_tiles)};\n")
        f.write(f"pub const int_tiles = [_]IntTile{{\n")
        for t in int_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # IOB tile struct and array
        f.write("pub const IobTile = struct {\n")
        f.write("    x: u8,\n")
        f.write("    y: u8,\n")
        f.write("    tile_type: TileType,\n")
        f.write("    site0: ?u16,  // IOB site Y (lower)\n")
        f.write("    site1: ?u16,  // IOB site Y (upper) — null for SING tiles\n")
        f.write("};\n\n")

        f.write(f"pub const iob_count: u32 = {len(iob_tiles)};\n")
        f.write(f"pub const iob_tiles = [_]IobTile{{\n")
        for t in iob_tiles:
            tt = t["type"].lower()
            sites = t["sites"]
            # Parse IOB site Y values
            site_ys = []
            for site_name in sorted(sites.keys()):
                m = re.search(r'Y(\d+)$', site_name)
                if m:
                    site_ys.append(int(m.group(1)))
            site0 = site_ys[0] if len(site_ys) > 0 else None
            site1 = site_ys[1] if len(site_ys) > 1 else None
            s0 = str(site0) if site0 is not None else "null"
            s1 = str(site1) if site1 is not None else "null"
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt}, .site0 = {s0}, .site1 = {s1} }},\n")
        f.write("};\n\n")

        # Package pin struct and array
        f.write("pub const PackagePin = struct {\n")
        f.write("    pin: []const u8,\n")
        f.write("    bank: u8,\n")
        f.write("    iob_site_y: u16,   // IOB_X?Y{this}\n")
        f.write("    tile_x: u8,\n")
        f.write("    tile_y: u8,\n")
        f.write("    tile_type: TileType,\n")
        f.write("};\n\n")

        f.write(f"pub const pin_count: u32 = {len(package_pins)};\n")
        f.write(f"pub const package_pins = [_]PackagePin{{\n")
        for p in package_pins:
            tile_name = p["tile"]
            tile_type_str = tilegrid[tile_name]["type"].lower() if tile_name in tilegrid else "liob33"
            tx, ty = parse_xy(tile_name)
            if tx is None:
                tx, ty = 0, 0
            site_y_m = re.search(r'Y(\d+)$', p["site"])
            site_y = int(site_y_m.group(1)) if site_y_m else 0
            f.write(f"    .{{ .pin = \"{p['pin']}\", .bank = {p['bank']}, "
                    f".iob_site_y = {site_y}, .tile_x = {tx}, .tile_y = {ty}, "
                    f".tile_type = .{tile_type_str} }},\n")
        f.write("};\n\n")

        # BUFG tiles
        f.write("pub const BufgTile = struct {\n")
        f.write("    x: u8,\n")
        f.write("    y: u16,\n")
        f.write("    tile_type: TileType,\n")
        f.write("};\n\n")

        f.write(f"pub const bufg_count: u32 = {len(bufg_tiles)};\n")
        f.write(f"pub const bufg_tiles = [_]BufgTile{{\n")
        for t in bufg_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # HCLK tiles
        f.write("pub const HclkTile = struct {\n")
        f.write("    x: u8,\n")
        f.write("    y: u16,\n")
        f.write("    tile_type: TileType,\n")
        f.write("};\n\n")

        f.write(f"pub const hclk_count: u32 = {len(hclk_tiles)};\n")
        f.write(f"pub const hclk_tiles = [_]HclkTile{{\n")
        for t in hclk_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # CLK_HROW tiles
        f.write(f"pub const clk_hrow_count: u32 = {len(clk_hrow_tiles)};\n")
        f.write(f"pub const clk_hrow_tiles = [_]HclkTile{{\n")
        for t in clk_hrow_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # CLK_BUFG_REBUF tiles
        f.write(f"pub const clk_rebuf_count: u32 = {len(clk_rebuf_tiles)};\n")
        f.write(f"pub const clk_rebuf_tiles = [_]HclkTile{{\n")
        for t in clk_rebuf_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # LIOI tiles
        f.write("pub const IoiTile = struct {\n")
        f.write("    x: u8,\n")
        f.write("    y: u8,\n")
        f.write("    tile_type: TileType,\n")
        f.write("};\n\n")

        f.write(f"pub const lioi_count: u32 = {len(lioi_tiles)};\n")
        f.write(f"pub const lioi_tiles = [_]IoiTile{{\n")
        for t in lioi_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        f.write(f"pub const rioi_count: u32 = {len(rioi_tiles)};\n")
        f.write(f"pub const rioi_tiles = [_]IoiTile{{\n")
        for t in rioi_tiles:
            tt = t["type"].lower()
            f.write(f"    .{{ .x = {t['x']}, .y = {t['y']}, .tile_type = .{tt} }},\n")
        f.write("};\n\n")

        # Lookup functions
        f.write("// =============================================================================\n")
        f.write("// Lookup Functions\n")
        f.write("// =============================================================================\n\n")

        f.write("/// Find package pin by name (e.g. \"U22\").\n")
        f.write("pub fn findPackagePin(pin_name: []const u8) ?PackagePin {\n")
        f.write("    for (package_pins) |pin| {\n")
        f.write("        if (std.mem.eql(u8, pin.pin, pin_name)) return pin;\n")
        f.write("    }\n")
        f.write("    return null;\n")
        f.write("}\n\n")

        f.write("/// Find CLB tile at (x, y).\n")
        f.write("pub fn findClbTile(x: u8, y: u8) ?ClbTile {\n")
        f.write("    for (clb_tiles) |tile| {\n")
        f.write("        if (tile.x == x and tile.y == y) return tile;\n")
        f.write("    }\n")
        f.write("    return null;\n")
        f.write("}\n\n")

        f.write("/// Find INT tile at (x, y).\n")
        f.write("pub fn findIntTile(x: u8, y: u8) ?IntTile {\n")
        f.write("    for (int_tiles) |tile| {\n")
        f.write("        if (tile.x == x and tile.y == y) return tile;\n")
        f.write("    }\n")
        f.write("    return null;\n")
        f.write("}\n\n")

        f.write("/// Find IOB tile containing a given IOB site Y.\n")
        f.write("pub fn findIobBySiteY(site_y: u16) ?IobTile {\n")
        f.write("    for (iob_tiles) |tile| {\n")
        f.write("        if (tile.site0) |s0| {\n")
        f.write("            if (s0 == site_y) return tile;\n")
        f.write("        }\n")
        f.write("        if (tile.site1) |s1| {\n")
        f.write("            if (s1 == site_y) return tile;\n")
        f.write("        }\n")
        f.write("    }\n")
        f.write("    return null;\n")
        f.write("}\n\n")

        f.write("/// Get tile type name string for FASM output.\n")
        f.write("pub fn tileTypeName(tt: TileType) []const u8 {\n")
        f.write("    return switch (tt) {\n")
        f.write("        .clbll_l => \"CLBLL_L\",\n")
        f.write("        .clbll_r => \"CLBLL_R\",\n")
        f.write("        .clblm_l => \"CLBLM_L\",\n")
        f.write("        .clblm_r => \"CLBLM_R\",\n")
        f.write("        .liob33 => \"LIOB33\",\n")
        f.write("        .liob33_sing => \"LIOB33_SING\",\n")
        f.write("        .riob33 => \"RIOB33\",\n")
        f.write("        .riob33_sing => \"RIOB33_SING\",\n")
        f.write("        .int_l => \"INT_L\",\n")
        f.write("        .int_r => \"INT_R\",\n")
        f.write("        .clk_bufg_bot_r => \"CLK_BUFG_BOT_R\",\n")
        f.write("        .clk_bufg_top_r => \"CLK_BUFG_TOP_R\",\n")
        f.write("        .clk_bufg_rebuf => \"CLK_BUFG_REBUF\",\n")
        f.write("        .clk_hrow_bot_r => \"CLK_HROW_BOT_R\",\n")
        f.write("        .clk_hrow_top_r => \"CLK_HROW_TOP_R\",\n")
        f.write("        .hclk_l => \"HCLK_L\",\n")
        f.write("        .hclk_r => \"HCLK_R\",\n")
        f.write("        .hclk_cmt => \"HCLK_CMT\",\n")
        f.write("        .hclk_cmt_l => \"HCLK_CMT_L\",\n")
        f.write("        .lioi3 => \"LIOI3\",\n")
        f.write("        .lioi3_sing => \"LIOI3_SING\",\n")
        f.write("        .lioi3_tbytesrc => \"LIOI3_TBYTESRC\",\n")
        f.write("        .lioi3_tbyteterm => \"LIOI3_TBYTETERM\",\n")
        f.write("        .rioi3 => \"RIOI3\",\n")
        f.write("        .rioi3_sing => \"RIOI3_SING\",\n")
        f.write("        .rioi3_tbytesrc => \"RIOI3_TBYTESRC\",\n")
        f.write("        .rioi3_tbyteterm => \"RIOI3_TBYTETERM\",\n")
        f.write("    };\n")
        f.write("}\n\n")

        f.write("/// Check if tile type is a left-side tile.\n")
        f.write("pub fn isLeftTile(tt: TileType) bool {\n")
        f.write("    return switch (tt) {\n")
        f.write("        .clbll_l, .clblm_l, .int_l, .liob33, .liob33_sing, .hclk_l, .lioi3, .lioi3_sing, .lioi3_tbytesrc, .lioi3_tbyteterm => true,\n")
        f.write("        else => false,\n")
        f.write("    };\n")
        f.write("}\n\n")

        f.write("const std = @import(\"std\");\n")

    print(f"  Done! {OUTPUT_PATH}")

    # Stats
    total = len(clb_tiles) + len(iob_tiles) + len(int_tiles) + len(bufg_tiles) + \
            len(hclk_tiles) + len(clk_hrow_tiles) + len(clk_rebuf_tiles) + \
            len(lioi_tiles) + len(rioi_tiles)
    print(f"\n  Total entries: {total}")
    print(f"  Package pins: {len(package_pins)}")


if __name__ == "__main__":
    main()
