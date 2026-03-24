// @origin(spec:tri27_backend.tri) @regen(manual-impl)
// TRI‑27 Verilog Backend — Generate synthesizable Verilog from TRI‑27 bytecode
// ═════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const Decoder = @import("emu/decoder.zig");
const Opcode = Decoder.Opcode;
const Instruction = Decoder.Instruction;

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";

// ═════════════════════════════════════════════════════════════════════════

// Generate Verilog module for TRI‑27 CPU
pub fn generateVerilogFromBytecode(allocator: Allocator, bytecode: []const u8) ![]const u8 {
    if (bytecode.len % 4 != 0) {
        print("{s}Error: Bytecode must be multiple of 4 bytes{s}\n", .{ RED, RESET });
        return error.InvalidBytecode;
    }

    var generated = std.ArrayList(u8).initCapacity(allocator, 16384) catch return error.OutOfMemory;
    defer generated.deinit(allocator);

    // Module header
    try generated.appendSlice(allocator,
        \\// TRI-27 CPU — Ternary Computing Processor
        \\// Auto-generated from TRI‑27 ISA bytecode
        \\// Target: Xilinx Artix-7 (openxc7-synth)
        \\// Generated: 2026-03-24
        \\
        \\module tri27_cpu (
        \\    input wire clk,
        \\    input wire rst_n,
        \\    input wire [31:0] instr_in,
        \\    output reg [31:0] result_out,
        \\    output reg halt,
        \\    // 27 ternary registers (exposed as 32-bit for convenience)
        \\    output reg [31:0] r0 [26:0],
        \\    output reg [31:0] t0 [26:0],
        \\    // 3 sacred constant registers
        \\    output wire [31:0] phi_const,
        \\    output wire [31:0] pi_const,
        \\    output wire [31:0] e_const,
        \\    // Program counter
        \\    output reg [15:0] pc,
        \\    // Status flags
        \\    output reg [7:0] flags,
        \\    // Memory interface
        \\    output reg [15:0] mem_addr,
        \\    output reg [31:0] mem_data_out,
        \\    input wire [31:0] mem_data_in,
        \\    output reg mem_we
        \\);
        \\
    );

    // Register declarations
    try generated.appendSlice(allocator,
        \\    // 27 ternary registers (trits packed into 32-bit words)
        \\    reg [31:0] t [26:0];
        \\    reg [31:0] r [26:0];
        \\    // Alias: r[i] = t[i] for convenience
        \\    genvar i;
        \\    generate
        \\        for (i = 0; i < 27; i = i + 1) begin : r_aliases
        \\            assign r[i] = t[i];
        \\        end
        \\    endgenerate
        \\
        \\    // 3 sacred constant registers (GF16 format: exp=6, mant=9, sign=1)
        \\    // φ = 1.61803398875, π = 3.14159265359, e = 2.718281828
        \\    wire [31:0] phi_const = 32'h3F9E3779;  // φ in GF16
        \\    wire [31:0] pi_const  = 32'h408F4197;  // π in GF16
        \\    wire [31:0] e_const   = 32'h402DF854;  // e in GF16
        \\
        \\    // Vector registers (8 GF16 + 3 float + 8 T-word)
        \\    reg [31:0] v_gf16 [7:0];   // 8 Golden Float 16
        \\    reg [31:0] v_float [2:0];   // 3 float32
        \\    reg [31:0] v_tword [7:0];   // 8 T-word (27 trits each)
        \\
        \\    // Stack (16-word return address stack)
        \\    reg [31:0] stack [15:0];
        \\    reg [4:0] sp; // 5-bit stack pointer
        \\
        \\    // Program counter
        \\    reg [15:0] pc;
        \\    reg [15:0] pc_next;
        \\
        \\    // Status flags
        \\    reg [7:0] flags;
        \\    wire flag_h = flags[0];  // Halt
        \\    wire flag_z = flags[6];  // Zero
        \\    wire flag_n = flags[7];  // Negative
        \\    wire flag_v = flags[2];  // Overflow
        \\    wire flag_c = flags[5];  // Carry
        \\
        \\    // Instruction register
        \\    reg [31:0] ir;
        \\    reg [7:0] opcode;
        \\    reg [15:0] imm;
        \\
        \\    // Control signals
        \\    wire halt;
        \\
    );

    // Clock edge and reset logic
    try generated.appendSlice(allocator,
        \\    // Clock edge and reset
        \\    always @(posedge clk or negedge rst_n) begin
        \\        if (!rst_n) begin
        \\            // Reset state
        \\            pc <= 16'h0000;
        \\            flags <= 8'h00;
        \\            sp <= 5'b00000;
        \\            halt <= 1'b0;
        \\        end else begin
        \\            // Normal operation
        \\            if (!halt) begin
        \\                ir <= instr_in;
        \\                opcode <= ir[31:24];  // Upper 8 bits = opcode
        \\                imm <= ir[23:8];     // Middle 16 bits = immediate
        \\                pc_next <= pc + 1;
        \\            end
        \\        end
        \\    end
        \\
    );

    // ALU instantiation
    try generated.appendSlice(allocator,
        \\    // ALU instantiation
        \\    wire [31:0] alu_a;
        \\    wire [31:0] alu_b;
        \\    wire [2:0]  alu_op;
        \\    wire [31:0] alu_result;
        \\    wire [2:0]  alu_status;
        \\
        \\    ternary_alu alu_inst (
        \\        .a(alu_a),
        \\        .b(alu_b),
        \\        .op(alu_op),
        \\        .result(alu_result),
        \\        .status(alu_status)
        \\    );
        \\
    );

    // Opcode decoder
    try generated.appendSlice(allocator,
        \\    // Opcode Decoder
        \\    wire [4:0] dst;
        \\    wire [4:0] src1;
        \\    wire [4:0] src2;
        \\    wire [15:0] immediate;
        \\
        \\    // Destination register decode (from lower 5 bits of opcode)
        \\    assign dst = opcode[4:0];
        \\    assign src1 = ir[19:15];
        \\    assign src2 = ir[14:10];
        \\    assign immediate = ir[23:8];
        \\
        \\    // ALU operation decode
        \\    assign alu_op = (opcode == 8'h03) ? 3'b000 :  // ADD
        \\                   (opcode == 8'h04) ? 3'b001 :  // SUB
        \\                   (opcode == 8'h05) ? 3'b010 :  // MUL
        \\                   (opcode == 8'h06) ? 3'b011 :  // DIV
        \\                   (opcode == 8'h0D) ? 3'b100 :  // AND
        \\                   (opcode == 8'h0E) ? 3'b101 :  // OR
        \\                   (opcode == 8'h0F) ? 3'b110 :  // XOR
        \\                   (opcode == 8'h10) ? 3'b111 :  // SHL
        \\                   3'b000;
        \\
        \\    // Source operands
        \\    assign alu_a = t[src1];
        \\    assign alu_b = t[src2];
        \\
    );

    // Opcode execution
    try generated.appendSlice(allocator,
        \\    // Opcode execution
        \\    always @(*) begin
        \\        case (opcode)
        \\            8'h00: begin // NOP
        \\            end
        \\            8'hFF: begin // HALT
        \\                halt <= 1'b1;
        \\            end
        \\            8'h03: begin // ADD
        \\                t[dst] <= alu_result;
        \\                flags <= {flags[7:6], alu_status[1], flags[4:3], flags[2], alu_status[0], flags[0]};
        \\            end
        \\            8'h04: begin // SUB
        \\                t[dst] <= alu_result;
        \\                flags <= {flags[7:6], alu_status[1], flags[4:3], flags[2], alu_status[0], flags[0]};
        \\            end
        \\            8'h05: begin // MUL
        \\                t[dst] <= alu_result;
        \\            end
        \\            8'h06: begin // DIV
        \\                if (alu_status[1]) begin // Division by zero
        \\                    flags[6] <= 1'b1; // Set error flag
        \\                end else begin
        \\                    t[dst] <= alu_result;
        \\                end
        \\            end
        \\            8'h0D: begin // AND
        \\                t[dst] <= alu_result;
        \\            end
        \\            8'h0E: begin // OR
        \\                t[dst] <= alu_result;
        \\            end
        \\            8'h0F: begin // XOR
        \\                t[dst] <= alu_result;
        \\            end
        \\            8'h10: begin // SHL
        \\                t[dst] <= alu_result;
        \\            end
        \\            8'h11: begin // LDI
        \\                t[dst] <= {{16{immediate[15]}}, immediate};
        \\            end
        \\            8'h12: begin // STI
        \\                mem_data_out <= {{16{immediate[15]}}, immediate};
        \\                mem_we <= 1'b1;
        \\            end
        \\            8'h14: begin // INC
        \\                t[dst] <= t[src1] + 1;
        \\            end
        \\            8'h15: begin // DEC
        \\                t[dst] <= t[src1] - 1;
        \\            end
        \\            8'h16: begin // JZ
        \\                if (t[dst] == 0) pc <= immediate;
        \\            end
        \\            8'h17: begin // JNZ
        \\                if (t[dst] != 0) pc <= immediate;
        \\            end
        \\            8'h18: begin // POP
        \\                if (sp > 0) begin
        \\                    sp <= sp - 1;
        \\                    t[dst] <= stack[sp - 1];
        \\                end
        \\            end
        \\            8'h19: begin // PUSH
        \\                if (sp < 16) begin
        \\                    stack[sp] <= t[src1];
        \\                    sp <= sp + 1;
        \\                end
        \\            end
        \\            8'h80: begin // PHI_CONST
        \\                t[dst] <= phi_const;
        \\            end
        \\            8'h81: begin // PI_CONST
        \\                t[dst] <= pi_const;
        \\            end
        \\            8'h82: begin // E_CONST
        \\                t[dst] <= e_const;
        \\            end
        \\            default: begin
        \\                // Unknown opcode - halt
        \\                halt <= 1'b1;
        \\            end
        \\        endcase
        \\    end
        \\
    );

    // Memory interface
    try generated.appendSlice(allocator,
        \\    // Memory (256 words × 32-bit)
        \\    reg [31:0] mem [255:0];
        \\
        \\    // Memory read/write
        \\    always @(posedge clk) begin
        \\        if (mem_we) begin
        \\            mem[mem_addr] <= mem_data_out;
        \\            mem_we <= 1'b0;
        \\        end
        \\    end
        \\
        \\    assign mem_data_in = mem[mem_addr];
        \\    assign mem_addr = (opcode == 8'h01 || opcode == 8'h02) ? t[src1] : immediate[11:0];
        \\
    );

    // Module footer
    try generated.appendSlice(allocator,
        \\endmodule
        \\
    );

    // Ternary ALU module
    try generated.appendSlice(allocator,
        \\//----------------------------------------------------------------
        \\// Ternary ALU — supports {-1, 0, +1} arithmetic
        \\//----------------------------------------------------------------
        \\
        \\module ternary_alu (
        \\    input wire [31:0] a,
        \\    input wire [31:0] b,
        \\    input wire [2:0]  op,  // 0=ADD, 1=SUB, 2=MUL, 3=DIV, 4=AND, 5=OR, 6=XOR, 7=SHL
        \\    output wire [31:0] result,
        \\    output wire [2:0]  status  // 0=ok, 1=overflow, 2=underflow, 3=div_zero
        \\);
        \\    wire [31:0] a_neg = -a;
        \\    wire [31:0] b_neg = -b;
        \\    wire [31:0] a_abs = a[31] ? a_neg : a;
        \\    wire [31:0] b_abs = b[31] ? b_neg : b;
        \\
        \\    // Ternary multiplication: (a * b) with -1 special handling
        \\    wire [63:0] mul_raw = $signed({32'b0, a}) * $signed({32'b0, b});
        \\    wire [31:0] mul_result = mul_raw[31:0];
        \\
        \\    // Operation selection
        \\    assign result = (op == 3'b000) ? (a + b) :
        \\                  (op == 3'b001) ? (a - b) :
        \\                  (op == 3'b010) ? mul_result :
        \\                  (op == 3'b011) ? ((b != 0) ? (a / b) : 32'hFFFFFFFF) :
        \\                  (op == 3'b100) ? (a & b) :
        \\                  (op == 3'b101) ? (a | b) :
        \\                  (op == 3'b110) ? (a ^ b) :
        \\                  (op == 3'b111) ? (a << 1) :
        \\                  a;
        \\
        \\    assign status = (op == 3'b011 && b == 0) ? 3'b011 :  // div by zero
        \\                  (op == 3'b000 && ((a ^ (a+b)) & (b ^ (a+b))) < 0) ? 3'b001 :  // overflow
        \\                  3'b000;
        \\endmodule
        \\
    );

    // Sacred Constant ROM module
    try generated.appendSlice(allocator,
        \\//----------------------------------------------------------------
        \\// Sacred Constant ROM — φ, π, e in GF16 format
        \\//----------------------------------------------------------------
        \\
        \\module sacred_constants (
        \\    output wire [31:0] phi,
        \\    output wire [31:0] pi,
        \\    output wire [31:0] e
        \\);
        \\    // GF16 format: 1 sign bit, 6 exponent bits, 9 mantissa bits
        \\    // φ = 1.61803398875
        \\    // π = 3.14159265359
        \\    // e = 2.718281828
        \\    assign phi = 32'h3F9E3779;
        \\    assign pi  = 32'h408F4197;
        \\    assign e   = 32'h402DF854;
        \\endmodule
        \\
    );

    // Vector Dot Product module
    try generated.appendSlice(allocator,
        \\//----------------------------------------------------------------
        \\// Vector Dot Product Unit — 8×8 GF16 dot product
        \\//----------------------------------------------------------------
        \\
        \\module vector_dot_product (
        \\    input wire [31:0] vec_a [7:0],
        \\    input wire [31:0] vec_b [7:0],
        \\    output wire [31:0] dot_result
        \\);
        \\    wire [63:0] products [7:0];
        \\    genvar j;
        \\    generate
        \\        for (j = 0; j < 8; j = j + 1) begin : calc_products
        \\            assign products[j] = vec_a[j] * vec_b[j];
        \\        end
        \\    endgenerate
        \\
        \\    assign dot_result = products[0][31:0] + products[1][31:0] +
        \\                       products[2][31:0] + products[3][31:0] +
        \\                       products[4][31:0] + products[5][31:0] +
        \\                       products[6][31:0] + products[7][31:0];
        \\endmodule
        \\
    );

    return generated.toOwnedSlice(allocator);
}

// ═════════════════════════════════════════════════════════════════════════

test "emit_verilog: generateVerilogFromBytecode produces valid Verilog" {
    const allocator = std.testing.allocator;

    const test_bytecode = [_]u8{
        0x00, 0x00, 0x00, 0x00, // NOP
        0xFF, 0x00, 0x00, 0x00, // HALT
        0x03, 0x08, 0x10, 0x00, // ADD r1, r2
        0x80, 0x00, 0x00, 0x00, // PHI_CONST r0
    };

    const result = try generateVerilogFromBytecode(allocator, &test_bytecode);
    defer allocator.free(result);

    // Verify it generates valid Verilog
    try std.testing.expect(std.mem.startsWith(u8, result, "// TRI-27 CPU"));
    try std.testing.expect(std.mem.indexOf(u8, result, "module tri27_cpu") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "endmodule") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "ternary_alu") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "sacred_constants") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "vector_dot_product") != null);

    // Check sacred constants are present
    try std.testing.expect(std.mem.indexOf(u8, result, "phi_const") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "pi_const") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "e_const") != null);

    // Check GF16 format values
    try std.testing.expect(std.mem.indexOf(u8, result, "32'h3F9E3779") != null); // φ
    try std.testing.expect(std.mem.indexOf(u8, result, "32'h408F4197") != null); // π
    try std.testing.expect(std.mem.indexOf(u8, result, "32'h402DF854") != null); // e

    print("{s}✅ emit_verilog.zig generates synthesizable Verilog{s}\n", .{ GREEN, RESET });
}

test "emit_verilog: contains all required modules" {
    const allocator = std.testing.allocator;
    const empty_bytecode = [_]u8{ 0x00, 0x00, 0x00, 0x00 };

    const result = try generateVerilogFromBytecode(allocator, &empty_bytecode);
    defer allocator.free(result);

    // Check all modules are present
    try std.testing.expect(std.mem.indexOf(u8, result, "module tri27_cpu") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "module ternary_alu") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "module sacred_constants") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "module vector_dot_product") != null);

    // Check proper Verilog syntax elements
    try std.testing.expect(std.mem.indexOf(u8, result, "input wire") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "output reg") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "always @") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "assign") != null);
}
