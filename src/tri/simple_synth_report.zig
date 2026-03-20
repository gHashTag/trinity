// Simple Yosys JSON Parser — Phase 6.4
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const colors = @import("tri_colors.zig");
const GOLD = colors.GOLDEN;
const CYAN = colors.CYAN;
const GREEN = colors.GREEN;
const RED = colors.RED;
const RESET = colors.RESET;

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var json_path: []const u8 = "fpga/openxc7-synth/sacred_alu.json";
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--input") and i + 1 < args.len) {
            json_path = args[i + 1];
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--help") or std.mem.eql(u8, args[i], "-h")) {
            try printHelp();
            return;
        }
    }

    std.debug.print("\n{s}═════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}SACRED ALU SYNTHESIS REPORT{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n\n", .{ GOLD, RESET });
    std.debug.print("{s}Input:{s} {s}\n", .{ CYAN, RESET, json_path });

    // Read JSON file
    const file = std.fs.cwd().openFile(json_path, .{}) catch |err| {
        std.debug.print("{s}Error:{s} Failed to read file: {s}\n", .{ RED, RESET, @errorName(err) });
        return;
    };
    defer file.close();

    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, @intCast(stat.size));
    defer allocator.free(buffer);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, buffer, .{}) catch {
        std.debug.print("{s}Error:{s} Failed to parse JSON\n", .{ RED, RESET });
        return;
    };

    // Count cell types
    var luts: u32 = 0;
    var dffs: u32 = 0;
    var dsp: u32 = 0;
    var bram: u32 = 0;
    var cells: u32 = 0;

    // Navigate to modules -> sacred_alu -> cells
    if (parsed.value.object.get("modules")) |modules_val| {
        if (modules_val.object.get("sacred_alu")) |alu_val| {
            if (alu_val.object.get("cells")) |cells_val| {
                if (cells_val != .null) {
                    const cells_array = cells_val.array;
                    cells = @intCast(cells_array.items.len);

                    for (cells_array.items) |cell_val| {
                        if (cell_val != .null) {
                            const cell_obj = cell_val.object;
                            const type_opt = cell_obj.get("type");
                            if (type_opt) |type_val| {
                                const cell_type = type_val.string;

                                if (std.mem.indexOf(u8, cell_type, "LUT") != null) {
                                    luts += 1;
                                } else if (std.mem.indexOf(u8, cell_type, "DFF") != null or
                                    std.mem.eql(u8, cell_type, "$dff"))
                                {
                                    dffs += 1;
                                } else if (std.mem.indexOf(u8, cell_type, "DSP48") != null or
                                    std.mem.eql(u8, cell_type, "DSP48E1"))
                                {
                                    dsp += 1;
                                } else if (std.mem.indexOf(u8, cell_type, "BRAM") != null or
                                    std.mem.indexOf(u8, cell_type, "RAMB") != null)
                                {
                                    bram += 1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    std.debug.print("\n{s}Resource Usage:{s}\n", .{ GREEN, RESET });
    std.debug.print("  LUT cells:    {d:6}\n", .{luts});
    std.debug.print("  DFF registers: {d:6}\n", .{dffs});
    std.debug.print("  DSP48E1:      {d:6}\n", .{dsp});
    std.debug.print("  BRAM blocks:   {d:6}\n", .{bram});
    std.debug.print("  Total cells:   {d:6}\n\n", .{cells});

    // XC7A100T limits
    const artix_lut_max: u32 = 63400;
    const artix_ff_max: u32 = 126800;
    const artix_dsp_max: u32 = 240;
    const artix_bram_max: u32 = 270;

    const lut_util = (@as(f64, @floatFromInt(luts)) / @as(f64, @floatFromInt(artix_lut_max))) * 100.0;
    const ff_util = (@as(f64, @floatFromInt(dffs)) / @as(f64, @floatFromInt(artix_ff_max))) * 100.0;
    const dsp_util = (@as(f64, @floatFromInt(dsp)) / @as(f64, @floatFromInt(artix_dsp_max))) * 100.0;
    const bram_util = (@as(f64, @floatFromInt(bram)) / @as(f64, @floatFromInt(artix_bram_max))) * 100.0;

    std.debug.print("\n{s}XC7A100T Resource Limits:{s}\n", .{ GOLD, RESET });
    std.debug.print("  LUT:   {d:6}/{d:6} ({d:5.1}%)\n", .{ luts, artix_lut_max, lut_util });
    std.debug.print("  FF:    {d:6}/{d:6} ({d:5.1}%)\n", .{ dffs, artix_ff_max, ff_util });
    std.debug.print("  DSP:   {d:6}/{d:6} ({d:5.1}%)\n", .{ dsp, artix_dsp_max, dsp_util });
    std.debug.print("  BRAM:  {d:6}/{d:6} ({d:5.1}%)\n\n", .{ bram, artix_bram_max, bram_util });

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n", .{ GOLD, RESET });
}

fn printHelp() !void {
    std.debug.print("\n{s}═══════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}SACRED SYNTHESIS REPORT COMMAND{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}═════════════════════════════════════{s}\n\n", .{ GOLD, RESET });

    std.debug.print("{s}Usage:{s} tri sacred synth-report [options]\n\n", .{ CYAN, RESET });
    std.debug.print("{s}Options:{s}\n", .{ GOLD, RESET });
    std.debug.print("  {s}--input PATH{s}  Path to Yosys JSON (default: sacred_alu.json)\n", .{ GREEN, RESET });
    std.debug.print("  {s}-h, --help{s}        Show this help\n\n", .{ GREEN, RESET });
}
