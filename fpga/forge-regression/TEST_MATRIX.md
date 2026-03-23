# FORGE Hardware Validation Matrix

## Test Suite (12 cases)

| # | Test | Features | Priority | Status |
|---|------|----------|----------|--------|
| 1 | static_io | Static IO, OBUF | HIGH | TODO |
| 2 | direct_clock | Direct clock to LED | HIGH | TODO |
| 3 | single_ff | Single FF toggle | HIGH | TODO |
| 4 | counter | 25-bit counter | HIGH | TODO |
| 5 | bufg_test | BUFG clock buffer | HIGH | TODO |
| 6 | srl16e_test | SRL16E shift register | MEDIUM | TODO |
| 7 | carry4_test | CARRY4 arithmetic | MEDIUM | TODO |
| 8 | multi_led | Multi-LED different rates | MEDIUM | TODO |
| 9 | bank_crossing | Cross-bank routing | MEDIUM | TODO |
| 10 | uart_loopback | UART TX-RX loopback | LOW | TODO |
| 11 | simple_fsm | 3-state FSM | LOW | TODO |
| 12 | trinity_top | Real Trinity design | HIGH | TODO |

## Validation Columns

| Design | FORGE Pass | Docker Pass | Vivado Ref | Runtime (ms) | Timing (ns) | Hardware Proof | Verdict |
|--------|------------|-------------|------------|--------------|-------------|----------------|---------|
| static_io | | | | | | | |
| direct_clock | | | | | | | |
| ... | | | | | | | |

## Deliverables

1. **Test Artifacts** (per case):
   - `design.v` — Verilog source
   - `design.xdc` — Pin constraints
   - `design_forge.bit` — FORGE bitstream
   - `design_docker.bit` — Docker bitstream
   - `timing.txt` — Timing report
   - `evidence.jpg` — Photo/video of board

2. **Benchmark Report**:
   - Runtime comparison
   - Bitstream size
   - Timing slack
   - Success rate

3. **Compatibility Matrix**:
   - Pass/fail per toolchain
   - Root cause analysis
   - Toxic verdict (Russian)
