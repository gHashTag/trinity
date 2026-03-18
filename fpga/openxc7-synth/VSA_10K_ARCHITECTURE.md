# 10K-Dimensional VSA Architecture — Design Document

## Overview

**Goal**: Scale from 16-trit vectors (256-bit) to 10K-trit vectors (20,000-bit)

**Motivation**: Higher dimensional VSA enables:
- More expressive representations
- Better similarity discrimination
- Larger symbol vocabularies
- Real-world embedding storage (e.g., word embeddings)

---

## Resource Analysis

### Current State (16-trit VSA)
| Metric | Value |
|--------|-------|
| Trits per vector | 16 |
| Storage per vector | 32 bits (4 bytes) |
| LUT usage | ~80 |
| Operations | Bind, Bundle, Similarity |

### Target State (10K-trit VSA)
| Metric | Value |
|--------|-------|
| Trits per vector | 10,000 |
| Storage per vector | 20,000 bits (2,500 bytes) |
| BRAM required | ~1 BRAM (32Kb) per vector |
| LUT estimated | ~500 |
| Operations | Bind, Bundle, Similarity (same API) |

---

## Architecture Options

### Option A: Direct BRAM Storage (Recommended)

**Structure**:
```verilog
// 10K trits = 10,000 × 2 bits = 20,000 bits
// BRAM on XC7A100T: 32Kb = 32,768 bits
// One BRAM can hold ~1.3 vectors (with overhead)

module vsa_10k_storage (
    input wire clk,
    input wire [12:0] addr,      // 2^13 = 8192 addresses (enough for 10K/32 words)
    input wire we,               // Write enable
    input wire [31:0] din,       // 32-bit data in
    output reg [31:0] dout       // 32-bit data out
);
    // 10K trits / 16 trits per word = 625 words
    // Round to 640 for alignment (20 * 32-bit words)
    reg [31:0] memory [0:639];

    always @(posedge clk) begin
        if (we)
            memory[addr] <= din;
        dout <= memory[addr];
    end
endmodule
```

**Pros**:
- Simple implementation
- Fast access (1 cycle latency)
- Low LUT usage (~500)

**Cons**:
- Limited to ~1-2 vectors in BRAM
- Need to implement paging for more vectors

---

### Option B: Distributed RAM (Alternative)

**Structure**:
```verilog
// Store 10K trits across multiple smaller RAM blocks
// Each block: 256 trits (512 bits)

module vsa_10k_distributed (
    input wire clk,
    input wire [4:0] block_sel,   // 32 blocks of ~313 trits each
    input wire [8:0] addr,        // 512 addresses per block
    input wire we,
    input wire [31:0] din,
    output reg [31:0] dout
);
    // 32 blocks × 32 words × 32 bits = 32,768 bits total
    reg [31:0] blocks [0:31][0:31];

    always @(posedge clk) begin
        if (we)
            blocks[block_sel][addr[4:0]] <= din;
        dout <= blocks[block_sel][addr[4:0]];
    end
endmodule
```

**Pros**:
- Parallel access (multiple blocks)
- Better for pipelined operations

**Cons**:
- Higher LUT usage (~800)
- More complex addressing

---

## Operations

### BIND (10K Trit Multiplication)

```verilog
function [639:0] bind_10k;
    input [639:0] a;  // 640 words × 16 trits = 10,240 trits (close enough to 10K)
    input [639:0] b;
    integer i, j;
    reg [1:0] a_trit, b_trit, r_trit;
    begin
        bind_10k = 0;
        for (i = 0; i < 640; i = i + 1) begin  // Each 32-bit word
            for (j = 0; j < 16; j = j + 1) begin  // Each trit in word
                a_trit = a[i*32 + j*2 +: 2];
                b_trit = b[i*32 + j*2 +: 2];

                if (a_trit == 2'b00 || b_trit == 2'b00)
                    r_trit = 2'b00;
                else if (a_trit == b_trit)
                    r_trit = 2'b01;
                else
                    r_trit = 2'b10;

                bind_10k[i*32 + j*2 +: 2] = r_trit;
            end
        end
    end
endfunction
```

**Timing Estimate**:
- Sequential: ~10,240 cycles @ 50MHz = 0.2ms
- Parallel (16×): ~640 cycles = 12.8μs

---

### BUNDLE (10K Majority Vote)

```verilog
function [639:0] bundle_10k;
    input [639:0] a;
    input [639:0] b;
    integer i, j;
    reg [1:0] a_trit, b_trit, r_trit;
    begin
        bundle_10k = 0;
        for (i = 0; i < 640; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                a_trit = a[i*32 + j*2 +: 2];
                b_trit = b[i*32 + j*2 +: 2];

                if (a_trit == 2'b10 && b_trit == 2'b10)
                    r_trit = 2'b10;
                else if (a_trit == 2'b01 && b_trit == 2'b01)
                    r_trit = 2'b01;
                else if (a_trit == 2'b00)
                    r_trit = b_trit;
                else if (b_trit == 2'b00)
                    r_trit = a_trit;
                else
                    r_trit = 2'b00;

                bundle_10k[i*32 + j*2 +: 2] = r_trit;
            end
        end
    end
endfunction
```

**Timing Estimate**: Similar to BIND (~12.8μs parallel)

---

### SIMILARITY (10K Cosine Similarity)

```verilog
function [15:0] similarity_10k;
    input [639:0] a;
    input [639:0] b;
    integer i, j;
    reg [1:0] a_trit, b_trit;
    reg signed [7:0] a_val, b_val;
    reg signed [31:0] dot_product;
    reg signed [15:0] norm_a, norm_b;
    begin
        dot_product = 0;
        norm_a = 0;
        norm_b = 0;

        for (i = 0; i < 640; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                a_trit = a[i*32 + j*2 +: 2];
                b_trit = b[i*32 + j*2 +: 2];

                a_val = (a_trit == 2'b01) ? 8'sd01 : (a_trit == 2'b10) ? 8'sd81 : 8'sd00;
                b_val = (b_trit == 2'b01) ? 8'sd01 : (b_trit == 2'b10) ? 8'sd81 : 8'sd00;

                dot_product = dot_product + (a_val * b_val);
                norm_a = norm_a + (a_val * a_val);
                norm_b = norm_b + (b_val * b_val);
            end
        end

        if (norm_a == 0 || norm_b == 0)
            similarity_10k = 16'd0;
        else if (dot_product >= 0)
            similarity_10k = (dot_product * 16'd65535) / (norm_a + norm_b);
        else
            similarity_10k = 16'd0;
    end
endfunction
```

**Timing Estimate**:
- Sequential: ~10,240 cycles = 0.2ms
- Accumulation requires wider adders (32-bit)

---

## UART Protocol for 10K Vectors

### Chunked Transfer

10K trits = 2,500 bytes. Need to chunk for reliable UART transfer.

**Protocol**:
```
[0xAA][CMD][LEN_H][LEN_L][CHUNK][DATA...][CRC_L][CRC_H]

CMD:
- 0x10: BIND_10K (needs 2 vectors = 5,000 bytes total)
- 0x11: BUNDLE_10K (needs 2 vectors = 5,000 bytes total)
- 0x12: SIMILARITY_10K (needs 2 vectors = 5,000 bytes total)

CHUNK: 0-255 (chunk index, 256 bytes per chunk)
```

**Transfer**:
```
Total: 5,000 bytes
Chunk size: 128 bytes (safe margin)
Chunks needed: 40 chunks

Host → FPGA: Send 40 chunks
FPGA → Host: Ack each chunk with CRC
Host → FPGA: Send EXECUTE command
FPGA → Host: Send result
```

---

## Resource Estimates (Week 2)

| Module | LUT | FF | BRAM | DSP | Notes |
|--------|-----|----|----|-----|-------|
| VSA 10K Storage | ~200 | ~100 | 2 | 0 | 2 vectors |
| VSA 10K BIND | ~500 | ~200 | 0 | 0 | Parallel |
| VSA 10K BUNDLE | ~500 | ~200 | 0 | 0 | Parallel |
| VSA 10K SIMILARITY | ~300 | ~150 | 0 | 0 | With accumulators |
| UART Chunking | ~200 | ~100 | 0 | 0 | Protocol layer |
| Control Logic | ~200 | ~100 | 0 | 0 | State machines |
| **Total** | **~1900** | **~850** | **2** | **0** |
| **% of XC7A100T** | **~3%** | **~0.7%** | **~1%** | **0%** |

**Result**: Plenty of room for TQNN + KV Cache!

---

## Next Steps

1. **Implement vsa_10k.v** — Core operations
2. **Create tb_vsa_10k.v** — Test bench with random vectors
3. **Update uart_host_v7.zig** — Chunked transfer support
4. **Synthesize and test** — Verify timing and resources
5. **Benchmark** — Measure vs CPU ( Trinity Core software)

---

**φ² + 1/φ² = 3 = TRINITY**

**Cycle #125 — Week 2 Day 1 — 10K VSA Architecture**
