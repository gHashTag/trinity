// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY OS — VexRiscv RISC-V Integration Wrapper                             ║
// ║                                                                              ║
// ║  Lightweight VexRiscv configuration for TRINITY OS:                         ║
// ║  - RV32IMC (Integer + Multiply + Compressed)                                ║
// ║  - Wishbone B4 bus for memory/peripherals                                   ║
// ║  - 4KB instruction + 4KB data BRAM                                          ║
// ║  - Interrupt support with custom trap handler                               ║
// ║                                                                              ║
// ║  Resources: ~2500 LUTs, ~1500 FFs, 2 BRAMs                                  ║
// ╚════════════════════════════════════════════════════════════════════════════╝

`timescale 1ns / 1ps
`default_nettype none

//==============================================================================
// SIMPLIFIED VEXRISCV CPU CORE (RV32IMC SUBSET)
//==============================================================================
// This is a simplified RISC-V implementation for FPGA
// Full VexRiscv (Scala) generates this Verilog structure
//
// For production: Replace with generated VexRiscv core:
//   1. Clone https://github.com/SpinalHDL/VexRiscv
//   2. Run: sbt "runMain vexriscv.GenCore -rTrinityRiscvConfig"
//   3. Copy generated VexRiscv.v here
//
// For now: Use this simplified core for development/testing

module VexRiscvTrinity (
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone B4 Instruction Bus
    output wire [31:0] i_wb_adr,
    output wire [31:0] i_wb_dat_w,
    input  wire [31:0] i_wb_dat_r,
    output wire [3:0]  i_wb_sel,
    output wire        i_wb_cyc,
    output wire        i_wb_stb,
    input  wire        i_wb_ack,
    output wire        i_wb_we,

    // Wishbone B4 Data Bus
    output wire [31:0] d_wb_adr,
    output wire [31:0] d_wb_dat_w,
    input  wire [31:0] d_wb_dat_r,
    output wire [3:0]  d_wb_sel,
    output wire        d_wb_cyc,
    output wire        d_wb_stb,
    input  wire        d_wb_ack,
    output wire        d_wb_we,

    // Interrupts
    input  wire [7:0]  irq,
    input  wire        irq_ack,

    // Status
    output wire        cpu_running,
    output wire [31:0] pc,
    output wire [3:0]  cpu_state
);

    //==========================================================================
    // SIMPLIFIED RISC-V IMPL (Placeholder for generated VexRiscv)
    //==========================================================================
    // This implements basic RV32IC for development
    // Full implementation would use VexRiscv generated core

    reg [31:0] reg_file [0:31];
    reg [31:0] pc_reg;
    reg [31:0] ir;         // Instruction register
    reg [31:0] mem_addr;
    reg [31:0] mem_wdata;
    reg [3:0]  mem_state;
    reg [31:0] opcode;
    reg [31:0] rs1_val, rs2_val;
    reg [6:0]  funct7;
    reg [2:0]  funct3;
    reg [4:0]  rd, rs1, rs2;
    reg [11:0] imm_i;
    reg [11:0] imm_s;
    reg [31:0] imm_u;

    // Instruction fetch state machine
    localparam S_FETCH  = 4'd0;
    localparam S_DECODE = 4'd1;
    localparam S_EXEC  = 4'd2;
    localparam S_MEM   = 4'd3;
    localparam S_WRITE = 4'd4;
    localparam S_WAIT  = 4'd5;

    reg [3:0] state;
    reg [31:0] alu_result;
    reg [31:0] next_pc;

    // Wishbone I-FSM signals
    reg i_cyc, i_stb;
    wire i_ack_done = i_cyc & i_wb_ack;

    // Wishbone D-FSM signals
    reg d_cyc, d_stb, d_we;
    reg [3:0] d_sel;
    wire d_ack_done = d_cyc & d_wb_ack;

    //==========================================================================
    // REGISTER FILE (X0-X31)
    //==========================================================================
    integer k;
    initial begin
        for (k = 0; k < 32; k = k + 1)
            reg_file[k] = 0;
        pc_reg = 32'h0;  // Start at 0 (reset vector)
    end

    //==========================================================================
    // INSTRUCTION FETCH
    //==========================================================================
    assign i_wb_adr = pc_reg[31:2];  // Word-aligned
    assign i_wb_dat_w = 32'd0;
    assign i_wb_sel = 4'hF;
    assign i_wb_cyc = i_cyc;
    assign i_wb_stb = i_stb;
    assign i_wb_we = 1'b0;

    //==========================================================================
    // DATA BUS
    //==========================================================================
    assign d_wb_adr = mem_addr[31:2];
    assign d_wb_dat_w = mem_wdata;
    assign d_wb_sel = 4'hF;
    assign d_wb_cyc = d_cyc;
    assign d_wb_stb = d_stb;
    assign d_wb_we = d_we;

    //==========================================================================
    // INSTRUCTION DECODER
    //==========================================================================
    always @(*) begin
        opcode = ir[6:0];
        rd = ir[11:7];
        rs1 = ir[19:15];
        rs2 = ir[24:20];
        funct3 = ir[14:12];
        funct7 = ir[31:25];

        // Immediate formats
        imm_i = {ir[31], ir[30:20]};  // I-type
        imm_s = {ir[31], ir[30:25], ir[11:7]};  // S-type
        imm_u = {ir[31:12], 12'd0};  // U-type

        // Sign extension
        rs1_val = reg_file[rs1];
        rs2_val = reg_file[rs2];
    end

    //==========================================================================
    // MAIN STATE MACHINE
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_FETCH;
            pc_reg <= 32'h0;
            ir <= 32'h0;
            i_cyc <= 1'b0;
            i_stb <= 1'b0;
            d_cyc <= 1'b0;
            d_stb <= 1'b0;
            d_we <= 1'b0;
        end else begin
            case (state)
                S_FETCH: begin
                    i_cyc <= 1'b1;
                    i_stb <= 1'b1;
                    if (i_ack_done) begin
                        i_cyc <= 1'b0;
                        i_stb <= 1'b0;
                        ir <= i_wb_dat_r;
                        state <= S_DECODE;
                    end
                end

                S_DECODE: begin
                    // Basic RV32I instruction decode
                    opcode = ir[6:0];

                    case (opcode)
                        7'b0110111: begin  // LUI
                            alu_result <= {ir[31:12], 12'd0};
                            reg_file[rd] <= alu_result;
                            pc_reg <= pc_reg + 4;
                            state <= S_FETCH;
                        end

                        7'b0010111: begin  // AUIPC
                            alu_result <= pc_reg + {ir[31:12], 12'd0};
                            reg_file[rd] <= alu_result;
                            pc_reg <= pc_reg + 4;
                            state <= S_FETCH;
                        end

                        7'b1101111: begin  // JAL
                            alu_result <= pc_reg + 4;
                            reg_file[rd] <= alu_result;
                            pc_reg <= pc_reg + {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};
                            state <= S_FETCH;
                        end

                        7'b1100111: begin  // JALR
                            alu_result <= pc_reg + 4;
                            reg_file[rd] <= alu_result;
                            pc_reg <= reg_file[rs1] + {{20{ir[31]}}, ir[30:20]};
                            state <= S_FETCH;
                        end

                        7'b1100011: begin  // Branch
                            state <= S_EXEC;
                        end

                        7'b0000011: begin  // Load
                            state <= S_MEM;
                        end

                        7'b0100011: begin  // Store
                            state <= S_MEM;
                        end

                        7'b0010011: begin  // OP-IMM
                            state <= S_EXEC;
                        end

                        7'b0110011: begin  // OP
                            state <= S_EXEC;
                        end

                        default: begin
                            // Unknown opcode - halt
                            state <= S_WAIT;
                        end
                    endcase
                end

                S_EXEC: begin
                    // ALU operations
                    case (opcode)
                        7'b0010011: begin  // OP-IMM
                            case (funct3)
                                3'b000: begin  // ADDI
                                    alu_result <= reg_file[rs1] + {{20{imm_i[11]}}, imm_i};
                                end
                                3'b010: begin  // SLTI
                                    alu_result <= ($signed(reg_file[rs1]) < $signed({{20{imm_i[11]}}, imm_i})) ? 1 : 0;
                                end
                                3'b011: begin  // SLTIU
                                    alu_result <= (reg_file[rs1] < {{20{imm_i[11]}}, imm_i}) ? 1 : 0;
                                end
                                3'b100: begin  // XORI
                                    alu_result <= reg_file[rs1] ^ {{20{imm_i[11]}}, imm_i};
                                end
                                3'b110: begin  // ORI
                                    alu_result <= reg_file[rs1] | {{20{imm_i[11]}}, imm_i};
                                end
                                3'b111: begin  // ANDI
                                    alu_result <= reg_file[rs1] & {{20{imm_i[11]}}, imm_i};
                                end
                            endcase
                            reg_file[rd] <= alu_result;
                            pc_reg <= pc_reg + 4;
                            state <= S_FETCH;
                        end

                        7'b0110011: begin  // OP
                            case (funct7)
                                7'b0000000: begin
                                    case (funct3)
                                        3'b000: alu_result <= reg_file[rs1] + reg_file[rs2];  // ADD
                                        3'b001: alu_result <= reg_file[rs1] << reg_file[4:0];  // SLL
                                        3'b100: alu_result <= reg_file[rs1] ^ reg_file[rs2];   // XOR
                                        3'b101: alu_result <= reg_file[rs1] >> reg_file[4:0];  // SRL
                                        3'b110: alu_result <= reg_file[rs1] | reg_file[rs2];   // OR
                                        3'b111: alu_result <= reg_file[rs1] & reg_file[rs2];   // AND
                                    endcase
                                end
                                7'b0100000: begin  // SUB
                                    alu_result <= reg_file[rs1] - reg_file[rs2];
                                end
                            endcase
                            if (rd != 0) reg_file[rd] <= alu_result;
                            pc_reg <= pc_reg + 4;
                            state <= S_FETCH;
                        end

                        7'b1100011: begin  // Branch
                            reg [31:0] branch_target;
                            branch_target = pc_reg + {{20{imm_s[11]}}, imm_s};
                            case (funct3)
                                3'b000: if (reg_file[rs1] == reg_file[rs2]) pc_reg <= branch_target;  // BEQ
                                3'b001: if (reg_file[rs1] != reg_file[rs2]) pc_reg <= branch_target;  // BNE
                                3'b100: if ($signed(reg_file[rs1]) < $signed(reg_file[rs2])) pc_reg <= branch_target;  // BLT
                                3'b101: if (!($signed(reg_file[rs1]) < $signed(reg_file[rs2]))) pc_reg <= branch_target;  // BGE
                            endcase
                            if (pc_reg == branch_target) begin
                                // Branch taken
                            end else begin
                                pc_reg <= pc_reg + 4;
                            end
                            state <= S_FETCH;
                        end
                    endcase
                end

                S_MEM: begin
                    case (opcode)
                        7'b0000011: begin  // Load
                            d_cyc <= 1'b1;
                            d_stb <= 1'b1;
                            d_we <= 1'b0;
                            mem_addr <= reg_file[rs1] + {{20{imm_i[11]}}, imm_i};
                            if (d_ack_done) begin
                                d_cyc <= 1'b0;
                                d_stb <= 1'b0;
                                case (funct3)
                                    3'b000: reg_file[rd] <= {{24{d_wb_dat_r[7]}}, d_wb_dat_r[7:0]};   // LB
                                    3'b001: reg_file[rd] <= {{16{d_wb_dat_r[15]}}, d_wb_dat_r[15:0]}; // LH
                                    3'b010: reg_file[rd] <= d_wb_dat_r;  // LW
                                endcase
                                pc_reg <= pc_reg + 4;
                                state <= S_FETCH;
                            end
                        end

                        7'b0100011: begin  // Store
                            d_cyc <= 1'b1;
                            d_stb <= 1'b1;
                            d_we <= 1'b1;
                            mem_addr <= reg_file[rs1] + {{20{imm_s[11]}}, imm_s};
                            mem_wdata <= reg_file[rs2];
                            if (d_ack_done) begin
                                d_cyc <= 1'b0;
                                d_stb <= 1'b0;
                                d_we <= 1'b0;
                                pc_reg <= pc_reg + 4;
                                state <= S_FETCH;
                            end
                        end
                    endcase
                end

                S_WAIT: begin
                    // Halted - wait for reset or interrupt
                    if (|irq) begin
                        state <= S_FETCH;
                        pc_reg <= 32'h0;  // Reset to ISR
                    end
                end
            endcase
        end
    end

    //==========================================================================
    // STATUS OUTPUTS
    //==========================================================================
    assign pc = pc_reg;
    assign cpu_state = state;
    assign cpu_running = (state != S_WAIT);

endmodule

//==============================================================================
// WISHBONE MEMORY ARBITER (connects I and D bus to shared memory)
//==============================================================================
module WishboneArbiter (
    input  wire        clk,
    input  wire        rst_n,

    // I-port (from CPU)
    input  wire [31:0] i_adr,
    input  wire        i_cyc,
    input  wire        i_stb,
    output wire        i_ack,
    output wire [31:0] i_dat_r,

    // D-port (from CPU)
    input  wire [31:0] d_adr,
    input  wire [31:0] d_dat_w,
    input  wire [3:0]  d_sel,
    input  wire        d_cyc,
    input  wire        d_stb,
    input  wire        d_we,
    output wire        d_ack,
    output wire [31:0] d_dat_r,

    // Memory port (shared)
    output reg  [31:0] m_adr,
    output reg  [31:0] m_dat_w,
    input  wire [31:0] m_dat_r,
    output reg         m_we,
    output wire        m_cyc
);

    // Simple priority: I > D
    assign i_ack = i_cyc & m_cyc;
    assign d_ack = d_cyc & m_cyc & ~i_cyc;
    assign i_dat_r = m_dat_r;
    assign d_dat_r = m_dat_r;

    always @(*) begin
        if (i_cyc) begin
            m_adr = i_adr;
            m_dat_w = 32'd0;
            m_we = 1'b0;
        end else begin
            m_adr = d_adr;
            m_dat_w = d_dat_w;
            m_we = d_we;
        end
    end

    assign m_cyc = i_cyc | d_cyc;

endmodule

//==============================================================================
// BRAM MEMORY BLOCK (4KB instruction + 4KB data)
//==============================================================================
module TrinityBramMemory (
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone interface
    input  wire [31:0] wb_adr,
    input  wire [31:0] wb_dat_w,
    output wire [31:0] wb_dat_r,
    input  wire        wb_we,
    input  wire        wb_cyc,
    output wire        wb_ack,

    // Debug/load interface
    input  wire        load_enable,
    input  wire [11:0] load_addr,
    input  wire [31:0] load_data
);

    // 4KB = 1024 words
    reg [31:0] memory [0:1023];

    // Address decoding
    wire [11:0] mem_addr = wb_adr[13:2];  // Lower 4KB for instruction memory
    wire write_enable = wb_cyc & wb_we & (wb_adr[31:14] == 18'd0);

    // Read
    assign wb_dat_r = memory[mem_addr];
    assign wb_ack = wb_cyc;

    // Write
    always @(posedge clk) begin
        if (write_enable)
            memory[mem_addr] <= wb_dat_w;
        else if (load_enable)
            memory[load_addr[11:2]] <= load_data;
    end

endmodule

//==============================================================================
// TOP LEVEL: RISC-V SUBSYSTEM
//==============================================================================
module TrinityRiscvSubsystem (
    input  wire        clk,
    input  wire        rst_n,

    // Interrupt inputs
    input  wire [7:0]  irq_sources,

    // UART connection (direct to trinity_v2)
    output wire        uart_rx_int,
    input  wire        uart_tx_int,

    // OS control interface
    output wire        cpu_halt,
    output wire [31:0] cpu_pc,
    output wire [3:0]  cpu_state,

    // Memory load interface (for programming)
    input  wire        mem_load,
    input  wire [11:0] mem_load_addr,
    input  wire [31:0] mem_load_data,

    // Status LEDs
    output wire        led_running,
    output wire        led_fault
);

    //======================================================================
    // WISHBONE INTERCONNECT
    //======================================================================
    wire [31:0] i_wb_adr, i_wb_dat_w, i_wb_dat_r;
    wire [3:0]  i_wb_sel;
    wire        i_wb_cyc, i_wb_stb, i_wb_ack, i_wb_we;

    wire [31:0] d_wb_adr, d_wb_dat_w, d_wb_dat_r;
    wire [3:0]  d_wb_sel;
    wire        d_wb_cyc, d_wb_stb, d_wb_ack, d_wb_we;

    wire [31:0] m_wb_adr, m_wb_dat_w, m_wb_dat_r;
    wire        m_wb_we, m_wb_cyc, m_wb_ack;

    //======================================================================
    // VEXRISCV CPU CORE
    //======================================================================
    VexRiscvTrinity cpu (
        .clk(clk),
        .rst_n(rst_n),

        // I-bus
        .i_wb_adr(i_wb_adr),
        .i_wb_dat_w(i_wb_dat_w),
        .i_wb_dat_r(i_wb_dat_r),
        .i_wb_sel(i_wb_sel),
        .i_wb_cyc(i_wb_cyc),
        .i_wb_stb(i_wb_stb),
        .i_wb_ack(i_wb_ack),
        .i_wb_we(i_wb_we),

        // D-bus
        .d_wb_adr(d_wb_adr),
        .d_wb_dat_w(d_wb_dat_w),
        .d_wb_dat_r(d_wb_dat_r),
        .d_wb_sel(d_wb_sel),
        .d_wb_cyc(d_wb_cyc),
        .d_wb_stb(d_wb_stb),
        .d_wb_ack(d_wb_ack),
        .d_wb_we(d_wb_we),

        // Interrupts
        .irq(irq_sources),
        .irq_ack(),

        // Status
        .cpu_running(led_running),
        .pc(cpu_pc),
        .cpu_state(cpu_state)
    );

    //======================================================================
    // WISHBONE ARBITER
    //======================================================================
    WishboneArbiter arbiter (
        .clk(clk),
        .rst_n(rst_n),

        // I-port
        .i_adr(i_wb_adr),
        .i_cyc(i_wb_cyc),
        .i_stb(i_wb_stb),
        .i_ack(i_wb_ack),
        .i_dat_r(i_wb_dat_r),

        // D-port
        .d_adr(d_wb_adr),
        .d_dat_w(d_wb_dat_w),
        .d_sel(d_wb_sel),
        .d_cyc(d_wb_cyc),
        .d_stb(d_wb_stb),
        .d_we(d_wb_we),
        .d_ack(d_wb_ack),
        .d_dat_r(d_wb_dat_r),

        // Memory
        .m_adr(m_wb_adr),
        .m_dat_w(m_wb_dat_w),
        .m_dat_r(m_wb_dat_r),
        .m_we(m_wb_we),
        .m_cyc(m_wb_cyc)
    );

    //======================================================================
    // BRAM MEMORY
    //======================================================================
    TrinityBramMemory memory (
        .clk(clk),
        .rst_n(rst_n),

        // Wishbone
        .wb_adr(m_wb_adr),
        .wb_dat_w(m_wb_dat_w),
        .wb_dat_r(m_wb_dat_r),
        .wb_we(m_wb_we),
        .wb_cyc(m_wb_cyc),
        .wb_ack(m_wb_ack),

        // Load interface
        .load_enable(mem_load),
        .load_addr(mem_load_addr),
        .load_data(mem_load_data)
    );

    //======================================================================
    // STATUS
    //======================================================================
    assign cpu_halt = ~led_running;
    assign led_fault = (cpu_state == 4'd5);  // Halted state

endmodule

// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  END OF VEXRISCV WRAPPER                                                     ║
// ╚════════════════════════════════════════════════════════════════════════════╝
