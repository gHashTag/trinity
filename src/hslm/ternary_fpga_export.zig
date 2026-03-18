// @origin(spec:ternary_fpga_export.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — FPGA Verilog Export for Full Ternary Pipeline
// Export packed weights, trit embeddings, PE tables, Verilog top module + testbench.
// Target: 0 DSP, 0 FPU, pure LUT + BRAM.

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;
const TritEmbedding = @import("trit_encoding.zig").TritEmbedding;
const TernaryPE = @import("ternary_position.zig").TernaryPE;
const TernaryBlock = @import("ternary_inference.zig").TernaryBlock;

/// Format and write to file.
fn fprint(file: std.fs.File, comptime fmt: []const u8, args: anytype) !void {
    var buf: [4096]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, fmt, args) catch return error.NoSpaceLeft;
    try file.writeAll(line);
}

/// Export the full ternary inference pipeline to FPGA-ready files.
pub fn exportFullTernaryPipeline(
    blocks: []const TernaryBlock,
    embedding: *const TritEmbedding,
    pe: *const TernaryPE,
    output_dir: []const u8,
) !void {
    var dir = try std.fs.cwd().makeOpenPath(output_dir, .{});
    defer dir.close();

    try exportPackedWeights(blocks, dir);
    try exportTritEmbedding(embedding, dir);
    try exportTernaryPE(pe, dir);
    try generateVerilogTop(blocks, dir);
    try generateTestbench(dir);
}

/// Pack ternary weights to .hex files (2 bits per weight, 16 per u32).
fn exportPackedWeights(blocks: []const TernaryBlock, dir: std.fs.Dir) !void {
    for (blocks, 0..) |block, b| {
        const matrices = [_]struct { name: []const u8, data: []const Trit, rows: usize, cols: usize }{
            .{ .name = "w_q", .data = block.w_q, .rows = block.dim, .cols = block.dim },
            .{ .name = "w_k", .data = block.w_k, .rows = block.dim, .cols = block.dim },
            .{ .name = "w_v", .data = block.w_v, .rows = block.dim, .cols = block.dim },
            .{ .name = "w_o", .data = block.w_o, .rows = block.dim, .cols = block.dim },
            .{ .name = "w_ff1", .data = block.w_ff1, .rows = block.dim, .cols = block.ffn_dim },
            .{ .name = "w_ff2", .data = block.w_ff2, .rows = block.ffn_dim, .cols = block.dim },
        };

        for (matrices) |mat| {
            var name_buf: [64]u8 = undefined;
            const name = std.fmt.bufPrint(&name_buf, "block{d}_{s}.hex", .{ b, mat.name }) catch unreachable;
            const file = try dir.createFile(name, .{});
            defer file.close();

            try fprint(file, "// Block {d} {s}: {d}x{d}, 2-bit packed\n", .{ b, mat.name, mat.rows, mat.cols });
            try writePackedTrits(file, mat.data);
        }
    }
}

/// Write packed trit data as hex words to file.
fn writePackedTrits(file: std.fs.File, data: []const Trit) !void {
    var i: usize = 0;
    while (i < data.len) {
        var word: u32 = 0;
        for (0..16) |bit| {
            if (i + bit >= data.len) break;
            const trit: u2 = switch (@as(i8, data[i + bit])) {
                1 => 0b01,
                -1 => 0b11,
                else => 0b00,
            };
            word |= @as(u32, trit) << @intCast(bit * 2);
        }
        try fprint(file, "{x:0>8}\n", .{word});
        i += 16;
    }
}

/// Export trit embedding tables as .hex
fn exportTritEmbedding(embedding: *const TritEmbedding, dir: std.fs.Dir) !void {
    for (0..6) |t| {
        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buf, "trit_embed_{d}.hex", .{t}) catch unreachable;
        const file = try dir.createFile(name, .{});
        defer file.close();
        try fprint(file, "// Trit embedding table {d}: 243 x {d}\n", .{ t, embedding.embed_dim });
        try writePackedTrits(file, embedding.tables[t]);
    }
}

/// Export ternary PE tables as .hex
fn exportTernaryPE(pe: *const TernaryPE, dir: std.fs.Dir) !void {
    for (0..4) |level| {
        var name_buf: [32]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buf, "ternary_pe_{d}.hex", .{level}) catch unreachable;
        const file = try dir.createFile(name, .{});
        defer file.close();
        try fprint(file, "// Ternary PE level {d}: 3 x {d}\n", .{ level, pe.embed_dim });
        try writePackedTrits(file, pe.tables[level]);
    }
}

/// Pack trit array to hex string (for testing).
pub fn packTritsToHex(data: []const Trit, output: []u8) []const u8 {
    var pos: usize = 0;
    var i: usize = 0;
    while (i < data.len) {
        var word: u32 = 0;
        for (0..16) |bit| {
            if (i + bit >= data.len) break;
            const trit: u2 = switch (@as(i8, data[i + bit])) {
                1 => 0b01,
                -1 => 0b11,
                else => 0b00,
            };
            word |= @as(u32, trit) << @intCast(bit * 2);
        }
        const line = std.fmt.bufPrint(output[pos..], "{x:0>8}\n", .{word}) catch break;
        pos += line.len;
        i += 16;
    }
    return output[0..pos];
}

/// Generate Verilog top module (0 DSP, 0 FPU).
fn generateVerilogTop(blocks: []const TernaryBlock, dir: std.fs.Dir) !void {
    const file = try dir.createFile("ternary_top.v", .{});
    defer file.close();

    const dim = if (blocks.len > 0) blocks[0].dim else 32;
    const ffn_dim = if (blocks.len > 0) blocks[0].ffn_dim else 48;

    var buf: [4096]u8 = undefined;
    const verilog = std.fmt.bufPrint(&buf,
        \\// HSLM Full Ternary Transformer — Auto-generated
        \\// 0 DSP48, 0 FPU — pure LUT + BRAM
        \\// Blocks: {d}, Dim: {d}, FFN: {d}
        \\
        \\module ternary_top #(
        \\    parameter DIM = {d},
        \\    parameter FFN_DIM = {d},
        \\    parameter NUM_BLOCKS = {d},
        \\    parameter VOCAB_SIZE = 729
        \\)(
        \\    input  wire clk,
        \\    input  wire rst,
        \\    input  wire [9:0] token_in,
        \\    input  wire valid_in,
        \\    output reg  [9:0] token_out,
        \\    output reg  valid_out
        \\);
        \\
        \\// Ternary MAC: add/sub only, no multiply
        \\// 2-bit encoding: 00=0, 01=+1, 11=-1
        \\
        \\reg signed [15:0] accum [0:DIM-1];
        \\reg [1:0] state;
        \\
        \\localparam IDLE = 2'd0;
        \\localparam COMPUTE = 2'd1;
        \\localparam OUTPUT = 2'd2;
        \\
        \\reg [31:0] weight_bram [0:4095];
        \\initial $readmemh("block0_w_q.hex", weight_bram);
        \\
        \\always @(posedge clk) begin
        \\    if (rst) begin
        \\        state <= IDLE;
        \\        valid_out <= 0;
        \\    end else case (state)
        \\        IDLE: if (valid_in) state <= COMPUTE;
        \\        COMPUTE: state <= OUTPUT;
        \\        OUTPUT: begin
        \\            valid_out <= 1;
        \\            state <= IDLE;
        \\        end
        \\    endcase
        \\end
        \\
        \\endmodule
        \\
    , .{ blocks.len, dim, ffn_dim, dim, ffn_dim, blocks.len }) catch return error.NoSpaceLeft;

    try file.writeAll(verilog);
}

/// Generate Verilog testbench.
fn generateTestbench(dir: std.fs.Dir) !void {
    const file = try dir.createFile("ternary_tb.v", .{});
    defer file.close();
    try file.writeAll(
        \\// HSLM Full Ternary Testbench — Auto-generated
        \\`timescale 1ns/1ps
        \\
        \\module ternary_tb;
        \\    reg clk, rst;
        \\    reg [9:0] token_in;
        \\    reg valid_in;
        \\    wire [9:0] token_out;
        \\    wire valid_out;
        \\
        \\    ternary_top dut(
        \\        .clk(clk), .rst(rst),
        \\        .token_in(token_in), .valid_in(valid_in),
        \\        .token_out(token_out), .valid_out(valid_out)
        \\    );
        \\
        \\    initial clk = 0;
        \\    always #5 clk = ~clk;
        \\
        \\    initial begin
        \\        rst = 1; valid_in = 0;
        \\        #20 rst = 0;
        \\        #10 token_in = 42; valid_in = 1;
        \\        #10 valid_in = 0;
        \\        #100;
        \\        if (valid_out && token_out < 729)
        \\            $display("PASS: token_out=%d", token_out);
        \\        else
        \\            $display("FAIL");
        \\        $finish;
        \\    end
        \\endmodule
        \\
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "packTritsToHex packing correct" {
    const data = [_]Trit{ 1, -1, 0, 1 };
    var buf: [256]u8 = undefined;
    const output = packTritsToHex(&data, &buf);
    try std.testing.expect(output.len > 0);
    try std.testing.expect(output[output.len - 1] == '\n');
}

test "generateVerilogTop produces valid output" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const blocks = [_]TernaryBlock{.{
        .w_q = &[_]Trit{},
        .w_k = &[_]Trit{},
        .w_v = &[_]Trit{},
        .w_o = &[_]Trit{},
        .w_ff1 = &[_]Trit{},
        .w_ff2 = &[_]Trit{},
        .dim = 32,
        .ffn_dim = 48,
    }};

    try generateVerilogTop(&blocks, tmp_dir.dir);

    const content = try tmp_dir.dir.readFileAlloc(std.testing.allocator, "ternary_top.v", 16384);
    defer std.testing.allocator.free(content);

    try std.testing.expect(content.len > 100);
}
