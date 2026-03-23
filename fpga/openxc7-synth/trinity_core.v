//! Strand III: Language \& Hardware Bridge
//!
//! FPGA component for Trinity S³AI — synthesizable Verilog module.
//!

`default_nettype none

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CORE V2 — Enhanced RISC-V Processor
// ═══════════════════════════════════════════════════════════════════════════════
//
// A tiny RISC-V RV32I subset processor that:
// - Runs autonomously from BRAM (no external programming needed)
// - Executes enhanced instruction set (SHIFT, MUL, UART, Interrupts)
// - Fits in <1000 LUTs
//
// V2 ADDITIONS: SLL, SRL, SRA shift instructions; MUL instruction; UART; Interrupts
// ═══════════════════════════════════════════════════════════════════════════════

module trinity_core #(
    parameter BOOT_ADDR = 12'h000,    // Boot address in BRAM
    parameter PC_WIDTH  = 12,         // PC width (4KB address space)
    parameter USE_DSP    = 1          // Use DSP48E1 for multiplier (1=DSP, 0=LUT)
)(
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory interface (BRAM)
    output wire [11:0]  instr_addr,
    input  wire [31:0]  instr_data,

    // Data memory interface (same BRAM, separate access)
    output wire        data_we,
    output wire [11:0]  data_addr,
    output wire [31:0]  data_wdata,
    input  wire [31:0]  data_rdata,

    // GPIO outputs
    output wire [31:0]  gpio_out,

    // V2: UART interface
    output wire        uart_tx,
    input  wire        uart_rx,

    // Status
    output wire        running,
    output wire [11:0]  pc
);

    //==========================================================================
    // PROGRAM COUNTER
    //==========================================================================
    reg [PC_WIDTH-1:0] pc_reg;
    wire [PC_WIDTH-1:0] pc_next;
    wire [PC_WIDTH-1:0] pc_plus4 = pc_reg + 4;
    wire [PC_WIDTH-1:0] pc_branch;
    wire        pc_load;

    assign pc = pc_reg;
    assign instr_addr = pc_reg[PC_WIDTH-1:2];  // Word-aligned

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= BOOT_ADDR;
        else if (is_mret) begin
            // PC is restored by interrupt handling logic
        end else if (pc_load)
            pc_reg <= pc_branch;
        else if (handle_interrupt)
            pc_reg <= IRQ_HANDLER;  // Jump to interrupt handler
        else if (!mul_busy)  // V2: Stall PC during MUL
            pc_reg <= pc_plus4;
    end

    //==========================================================================
    // INSTRUCTION DECODE
    //==========================================================================
    wire [6:0] opcode = instr_data[6:0];
    wire [4:0] rd     = instr_data[11:7];
    wire [4:0] rs1    = instr_data[19:15];
    wire [4:0] rs2    = instr_data[24:20];
    wire [2:0] funct3 = instr_data[14:12];
    wire [6:0] funct7 = instr_data[31:25];
    wire [11:0] imm_i = {instr_data[31], instr_data[29:20]};
    wire [11:0] imm_s = {instr_data[31], instr_data[29:25], instr_data[11:7]};

    // Instruction type detection
    wire is_r_type = (opcode == 7'b0110011);
    wire is_i_type = (opcode == 7'b0010011) || (opcode == 7'b0000011) || (opcode == 7'b0001111);
    wire is_s_type = (opcode == 7'b0100011);
    wire is_b_type = (opcode == 7'b1100011);
    wire is_jal   = (opcode == 7'b1101111);

    // V2: Shift instruction detection (SLL, SRL, SRA)
    // SLL/SLLI: funct3=001, funct7=0000000
    // SRL/SRLI: funct3=101, funct7=0000000
    // SRA/SRAI: funct3=101, funct7=0100000
    wire is_shift = (opcode == 7'b0010011 || opcode == 7'b0110011) &&
                    ((funct3 == 3'b001 && funct7 == 7'b0000000) ||  // SLL
                     (funct3 == 3'b101 && funct7 == 7'b0000000) ||  // SRL
                     (funct3 == 3'b101 && funct7 == 7'b0100000));    // SRA

    // V2: MUL instruction detection (RISC-V M extension)
    // MUL: opcode=0110011, funct3=000, funct7=0000001
    wire is_mul = (opcode == 7'b0110011) && (funct3 == 3'b000) && (funct7 == 7'b0000001);

    // V2: MRET instruction detection (return from interrupt)
    // MRET: opcode=1110011
    wire is_mret = (opcode == 7'b1110011);

    //==========================================================================
    // REGISTER FILE (x0-x31, x0 is hardwired to 0)
    //==========================================================================
    reg [31:0] registers[0:31];
    wire [31:0] rs1_data = registers[rs1];
    wire [31:0] rs2_data = registers[rs2];

    wire reg_write_enable;
    wire [4:0] reg_dst;
    wire [31:0] reg_wdata;

    integer i;
    always @(posedge clk) begin
        if (reg_write_enable && |reg_dst)  // Don't write to x0
            registers[reg_dst] <= reg_wdata;
    end

    //==========================================================================
    // V2: CONTROL AND STATUS REGISTERS (CSRs)
    //==========================================================================
    // MIE: Machine Interrupt Enable
    // MIP: Machine Interrupt Pending
    // mepc: Machine Exception PC (saved PC on interrupt)
    reg [31:0] mie;
    reg [31:0] mip;
    reg [31:0] mepc;

    // V2: Interrupt pending from UART (bit 0)
    wire uart_irq;
    wire interrupt_pending = (mip & mie) != 32'd0;

    // On interrupt, save PC+4 to mepc and jump to handler
    // Interrupt handler is at address 0x80 (can be changed)
    localparam IRQ_HANDLER = 12'h080;

    //==========================================================================
    // V2: INTERRUPT HANDLING
    //==========================================================================
    // When an interrupt occurs and interrupts are enabled:
    // 1. Save current PC+4 to mepc
    // 2. Disable interrupts (clear MIE)
    // 3. Jump to interrupt handler

    reg handle_interrupt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mie <= 32'd0;
            mip <= 32'd0;
            mepc <= 32'd0;
            handle_interrupt <= 1'b0;
        end else begin
            // Set UART interrupt pending
            mip[0] <= uart_irq;

            // Detect interrupt condition
            handle_interrupt <= interrupt_pending && !mul_busy;

            // On MRET, restore PC and re-enable interrupts
            if (is_mret) begin
                pc_reg <= mepc[PC_WIDTH-1:2];
                mie <= 32'hFFFFFFFF;  // Re-enable all interrupts
                handle_interrupt <= 1'b0;
            end

            // Save mepc on interrupt (PC+4 to return after)
            if (handle_interrupt && !pc_load && !mul_busy) begin
                mepc <= pc_plus4;
                mie <= 32'd0;  // Disable interrupts during handler
            end
        end
    end

    //==========================================================================
    // IMMEDIATE GENERATION
    //==========================================================================
    wire [31:0] imm_i_sext = {{20{imm_i[11]}}, imm_i};
    wire [31:0] imm_s_sext = {{20{imm_s[11]}}, imm_s};
    wire [31:0] imm_b_sext = {{19{imm_s[11]}}, imm_s, 1'b0};

    //==========================================================================
    // ALU
    //==========================================================================
    wire [31:0] alu_src_a = rs1_data;
    wire [31:0] alu_src_b = is_r_type ? rs2_data : imm_i_sext;

    wire [31:0] alu_result;
    wire        alu_zero;

    // V2: Shifter for SLL, SRL, SRA instructions
    wire [31:0] shifter_result;
    wire [4:0] shamt = is_r_type ? rs2_data[4:0] : instr_data[24:20];  // Shift amount

    // Shift operations
    // SLL:  shift left logical
    // SRL:  shift right logical
    // SRA:  shift right arithmetic
    assign shifter_result = (funct3 == 3'b001) ? (alu_src_a << shamt) :           // SLL
                           (funct7 == 7'b0100000) ? ($signed(alu_src_a) >>> shamt) :  // SRA
                           (alu_src_a >> shamt);                                          // SRL

    // ALU operations (updated to include shifts)
    assign alu_result = is_shift ? shifter_result : funct3[2] ? (
        funct3[1] ? (
            funct3[0] ? (alu_src_a & alu_src_b) :            // AND
                      (alu_src_a | alu_src_b)                // OR
        ) : (
            funct3[0] ? (alu_src_a ^ alu_src_b) :            // XOR
                      (alu_src_a - alu_src_b)                // SUB
        )
    ) : (
        funct3[1] ? (
            funct3[0] ? (alu_src_a < alu_src_b) :            // SLTU
                      ($signed(alu_src_a) < $signed(alu_src_b))  // SLT
        ) : (
            funct3[0] ? alu_src_a :                          // MV (ADD with 0)
                      (alu_src_a + alu_src_b)                // ADD
        )
    );

    assign alu_zero = (alu_result == 32'd0);

    //==========================================================================
    // V2: MULTIPLIER (MUL instruction with LUT-based multiplier)
    //==========================================================================
    // MUL has 3-cycle pipeline latency, so we need to stall the pipeline
    wire mul_valid;
    wire [31:0] mul_result;

    // Stall counter for MUL instruction (3 cycles)
    reg [1:0] mul_stall;
    wire mul_busy = |mul_stall;

    // Universal multiplier (DSP48E1 or LUT based on USE_DSP parameter)
    universal_mul #(
        .USE_DSP(USE_DSP)
    ) multiplier (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(is_mul),
        .a(rs1_data),
        .b(rs2_data),
        .result(mul_result),
        .valid_out(mul_valid)
    );

    // Stall logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mul_stall <= 2'd0;
        else if (is_mul && !mul_busy)
            mul_stall <= 2'd11;  // Start stall (3 cycles)
        else if (|mul_stall)
            mul_stall <= mul_stall - 1'd1;
    end

    //==========================================================================
    // BRANCH LOGIC
    //==========================================================================
    wire branch_taken;
    assign branch_taken = funct3[2] ? (
        funct3[1] ? (
            funct3[0] ? (!alu_zero) :                        // BNE
                      (alu_zero)                             // BEQ
        ) : (
            funct3[0] ? (!alu_zero && !alu_src_a[31]) :      // BLTU (simplified)
                      (alu_zero || alu_src_a[31])            // BGE (simplified)
        )
    ) : 1'b0;  // Default: not taken

    assign pc_branch = is_jal ? (pc_reg + {{19{instr_data[31]}}, instr_data[30:21], instr_data[20], instr_data[30:21], 1'b0}) :
                       (pc_reg + imm_b_sext);
    assign pc_load = is_jal || (is_b_type && branch_taken);

    //==========================================================================
    // WRITEBACK
    //==========================================================================
    wire [31:0] mem_rdata_aligned = data_rdata;

    assign reg_dst = is_jal ? 5'd1 : rd;
    assign reg_wdata = is_jal ? (pc_plus4) :
                       (opcode == 7'b0000011) ? mem_rdata_aligned :  // LOAD
                       is_mul ? mul_result :                          // V2: MUL result
                       alu_result;

    assign reg_write_enable = (is_r_type || is_i_type || is_jal) && |rd && !mul_busy;

    //==========================================================================
    // MEMORY INTERFACE
    //==========================================================================
    assign data_addr = is_s_type ? {{20{imm_s[11]}}, imm_s} : alu_result[11:0];
    assign data_wdata = rs2_data;
    assign data_we = is_s_type;

    //==========================================================================
    // GPIO OUTPUT (memory-mapped at 0x100)
    //==========================================================================
    reg [31:0] gpio_reg;
    wire gpio_sel = (data_addr[11:2] == 10'h100) && data_we;

    always @(posedge clk) begin
        if (!rst_n)
            gpio_reg <= 32'h0;
        else if (gpio_sel)
            gpio_reg <= data_wdata;
    end

    assign gpio_out = gpio_reg;

    //==========================================================================
    // V2: UART MODULE (memory-mapped at 0x200-0x20C)
    //==========================================================================
    // Address map:
    // 0x200: UART_DIV - Baud rate divisor
    // 0x204: UART_TX  - Transmit data
    // 0x208: UART_RX  - Receive data
    // 0x20C: UART_STAT - Status register

    wire [31:0] uart_rdata;
    wire uart_sel = (data_addr[11:2] >= 10'h80) && (data_addr[11:2] < 10'h84);

    trinity_uart uart (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .addr(data_addr[4:0]),
        .we(data_we && uart_sel),
        .re(!data_we && uart_sel),
        .wdata(data_wdata),
        .rdata(uart_rdata),
        .rx_irq(uart_irq)  // V2: Connect to interrupt controller
    );

    //==========================================================================
    // STATUS
    //==========================================================================
    assign running = rst_n;

endmodule

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY CORE TOP LEVEL — With BRAM and Boot Program
// ═══════════════════════════════════════════════════════════════════════════════

module trinity_top (
    input  wire clk,
    output wire led,
    output wire uart_tx,
    input  wire uart_rx
);

    // Reset generation (internal, always 1 after power-on)
    reg [3:0] rst_sync;
    wire rst_n = rst_sync[3];

    always @(posedge clk) begin
        rst_sync <= {rst_sync[2:0], 1'b1};
    end

    //==========================================================================
    // BRAM — 4KB Instruction + Data Memory
    //==========================================================================
    reg [31:0] memory [0:1023];  // 4KB = 1024 words

    // Boot program: LED blink at ~3 Hz
    // Assembly:
    //   li x1, 0x100      // GPIO base
    //   li x2, 1          // LED ON value
    //   li x3, 0          // LED OFF value
    // loop:
    //   sw x2, 0(x1)      // LED ON
    //   delay_on:
    //     addi x4, x4, 1  // counter++
    //     blt x4, x100, delay_on
    //   sw x3, 0(x1)      // LED OFF
    //   delay_off:
    //     addi x5, x5, 1  // counter++
    //     blt x5, x100, delay_off
    //   jal x0, loop      // repeat

    initial begin
        // Address 0x000: li x1, 0x100 (addi x1, x0, 0x100)
        memory[0] = 32'h10000113;  // addi x1, x0, 0x100
        // Address 0x004: li x2, 1
        memory[1] = 32'h00100293;  // addi x2, x0, 1
        // Address 0x008: li x3, 0
        memory[2] = 32'h00000313;  // addi x3, x0, 0
        // Address 0x00C: li x4, 0 (counter)
        memory[3] = 32'h00000393;  // addi x4, x0, 0
        // Address 0x010: li x5, 0 (counter)
        memory[4] = 32'h00000413;  // addi x5, x0, 0

        // Loop start:
        // Address 0x014: sw x2, 0(x1)  -> LED ON
        memory[5] = 32'h0010A023;  // sw x2, 0(x1)

        // Delay loop ON:
        // Address 0x018: addi x4, x4, 1
        memory[6] = 32'h00170713;  // addi x4, x4, 1
        // Address 0x01C: li x6, 100 (compare value)
        memory[7] = 32'h06400813;  // addi x6, x0, 100
        // Address 0x020: blt x4, x6, -2  -> loop back if x4 < 100
        memory[8] = 32'hFE040463;  // blt x4, x6, -8 (to 0x018)

        // Address 0x024: sw x3, 0(x1)  -> LED OFF
        memory[9] = 32'h0000A023;  // sw x3, 0(x1)

        // Delay loop OFF:
        // Address 0x028: addi x5, x5, 1
        memory[10] = 32'h00178793;  // addi x5, x5, 1
        // Address 0x02C: blt x5, x6, -2  -> loop back if x5 < 100
        memory[11] = 32'hFE050863;  // blt x5, x6, -8 (to 0x028)

        // Address 0x030: jal x0, -28  -> jump to loop start (0x014)
        memory[12] = 32'hFF1FF06F;  // jal x0, -28

        // Fill remaining with NOP
        // Note: Yosys will automatically zero-initialize unspecified memory
        // So we only need to explicitly set the instructions we use
    end

    //==========================================================================
    // TRINITY CORE INSTANCE
    //==========================================================================
    wire [11:0] instr_addr_core;
    wire [11:0] data_addr_core;
    wire [31:0] data_wdata_core;
    wire        data_we_core;
    wire [31:0] gpio_out_core;

    // Memory interface registers (declared before instance)
    reg [31:0] instr_data_reg = 32'h00000013;  // NOP by default
    reg [31:0] data_rdata_reg = 32'h0;

    trinity_core core (
        .clk(clk),
        .rst_n(rst_n),

        .instr_addr(instr_addr_core),
        .instr_data(instr_data_reg),

        .data_we(data_we_core),
        .data_addr(data_addr_core),
        .data_wdata(data_wdata_core),
        .data_rdata(data_rdata_reg),

        .gpio_out(gpio_out_core),

        .uart_tx(uart_tx),
        .uart_rx(uart_rx),

        .running(),
        .pc()
    );

    //==========================================================================
    // MEMORY INTERFACE
    //==========================================================================
    // Memory read (synchronous, dual-port for instr/data)
    always @(posedge clk) begin
        instr_data_reg <= memory[instr_addr_core];
        if (data_we_core)
            memory[data_addr_core] <= data_wdata_core;
        else
            data_rdata_reg <= memory[data_addr_core];
    end

    //==========================================================================
    // LED OUTPUT (bit 0 of GPIO)
    //==========================================================================
    assign led = gpio_out_core[0];

endmodule
