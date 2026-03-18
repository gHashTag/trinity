# Trinity FPGA — Technology Tree

**Hardware:** QMTECH Artix-7 XC7A100T-1FGG676C
**JTAG:** Xilinx Platform Cable USB II

---

## Technology Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRINITY FPGA TECHNOLOGY                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │   DESIGN      │  │  SYNTHESIS     │  │  DEPLOYMENT    │   │
│  │   (Verilog)    │  │  (Toolchains)  │  │  (Hardware)    │   │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘   │
│           │                   │                   │             │
│           ▼                   ▼                   ▼             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    APPLICATION LAYER                     │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  • VSA Coprocessor     • Quantum Designs                 │   │
│  │  • UART Communication  • RISC-V Integration             │   │
│  │  • Singularity Core    • Consciousness Modules          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     CORE MODULES                         │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  VSA Operations          │  UART Protocol                │   │
│  │  ├── bind/unbind         │  ├── CRC-16/CCITT             │   │
│  │  ├── bundle2/bundle3     │  ├── Framing                  │   │
│  │  ├── similarity          │  ├── Commands (BIND/BUNDLE/   │   │
│  │  └── hamming distance    │  │   SIMILARITY/PING)         │   │
│  │                         │  └── Trit encoding            │   │
│  │  Ternary Logic          │  Memory                       │   │
│  │  ├── Trit {-1,0,+1}     │  ├── Block RAM                 │   │
│  │  ├── HybridBigInt       │  ├── Distributed RAM           │   │
│  │  └── Packed encoding    │  └── Registers                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   PRIMITIVES (Xilinx 7-series)          │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  Logic       │  Memory     │  DSP      │  Clocking      │   │
│  │  ├── LUT1-6  │  ├── BRAM   │  ├── DSP48E1│  ├── BUFG     │   │
│  │  ├── FDRE/   │  ├── SRL16  │  └── Packed │  ├── MMCM     │   │
│  │  │   FDSE/   │  └── URAM   │     MAC    │  └── PLL      │   │
│  │  │   FDCE/   │            │            │               │   │
│  │  │   FDPE   │            │            │  I/O           │   │
│  │  ├── CARRY4 │            │            │  ├── IBUF/OBUF │   │
│  │  ├── MUXF7  │            │            │  ├── IOBUF     │   │
│  │  └── MUXF8  │            │            │  └── IDELAY/   │   │
│  │            │            │            │     ODELAY      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    TOOLCHAINS                            │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  RECOMMENDED (openXC7)     │  EXPERIMENTAL (FORGE)       │   │
│  │  ├── Yosys (synthesis)     │  ├── 100% Zig               │   │
│  │  ├── nextpnr-xilinx (P&R)  │  ├── Native implementation   │   │
│  │  ├── fasm2frames           │  ├── Known bugs:            │   │
│  │  ├── xc7frames2bit         │  │   • IOB placement         │   │
│  │  └── Docker container      │  │   • OLOGIC config         │   │
│  │     (regymm/openxc7)       │  │   • net-to-port matching  │   │
│  │                            │  └── Status: WIP           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    HOST SOFTWARE                         │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  UART Host (Zig)          │  JTAG Tools                  │   │
│  │  ├── uart_host_v6.zig     │  ├── jtag_program           │   │
│  │  ├── crc16Ccitt()         │  ├── fxload (firmware)      │   │
│  │  ├── trit encoding        │  └── flash_safe.sh          │   │
│  │  └── packet framing       │                              │   │
│  │                          │  Build Scripts               │   │
│  │  Correctness Tests        │  ├── synth.sh                │   │
│  │  ├── uart_correctness     │  └── batch_synthesize.sh    │   │
│  │  ├── vsa_correctness      │                              │   │
│  │  └── protocol validation  │                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    HARDWARE                              │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  FPGA: QMTECH Artix-7 XC7A100T-1FGG676C                 │   │
│  │  ├── 100K LUTs              ├── 48 DSP48E1               │   │
│  │  ├── 200K FFs               └── 1350 BRAM               │   │
│  │  ├── 6.5Mb Block RAM                                        │   │
│  │  └── FGG676 package (676 pins)                            │   │
│  │                                                            │   │
│  │  JTAG: Xilinx Platform Cable USB II                       │   │
│  │  ├── VID: 0x03fd → PID: 0013 (bootloader)               │   │
│  │  └── VID: 0x03fd → PID: 0008 (JTAG mode after fxload)   │   │
│  │                                                            │   │
│  │  LEDs: D6 (Green, user LED) on pin T23                   │   │
│  │  Clock: 50MHz oscillator on pin U22                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Dependency Graph

```
vsa_coprocessor.v
    ├── vsa_bind.v (VSA bind operation)
    ├── vsa_bundle.v (VSA bundle operation)
    ├── uart_top.v (UART interface)
    │   ├── uart_tx.v
    │   ├── uart_rx.v
    │   └── uart_command_decoder.v
    └── trit_encoding.v (Trit ↔ 2-bit)
```

---

## Designs Status

| Design | Status | Description |
|--------|--------|-------------|
| `blink.v` | ✅ Working | Basic LED blink (tested on hardware) |
| `counter.v` | ✅ Working | 4-bit counter with LED display |
| `fsm_simple.v` | ✅ Working | Simple state machine |
| `vsa_coprocessor.v` | 🚧 WIP | VSA operations accelerator |
| `uart_top.v` | ✅ Synthesized | UART communication module |
| `riscv_vsa_top.v` | 🚧 WIP | RISC-V + VSA integration |
| `singularity_core.v` | ✅ Synthesized | Quantum-inspired design |

---

## Protocol: UART v6

**Frame Format:**
```
[SYNC 0xAA][CMD][LEN][DATA...][CRC_L][CRC_H]
```

**Commands:**
- `0x01` MODE
- `0x02` BIND
- `0x03` BUNDLE
- `0x04` SIMILARITY
- `0x05` BITNET
- `0xFF` PING

**Trit Encoding (2-bit):**
- `10b` → NEGATIVE (-1)
- `00b` → ZERO (0)
- `01b` → POSITIVE (+1)

**CRC:** CRC-16/CCITT (poly 0x1021, init 0xFFFF)

---

## Development Workflow

```bash
# 1. Write Verilog design
vim fpga/openxc7-synth/design.v

# 2. Synthesize with openXC7
cd fpga/openxc7-synth
./synth.sh design.v top_module

# 3. Load JTAG firmware
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex

# 4. Replug cable (PID changes to 0008)

# 5. Flash bitstream
fpga/tools/jtag_program /tmp/design.bit

# 6. Verify LED behavior on hardware
```

---

## Known Issues

| Issue | Severity | Workaround |
|-------|----------|------------|
| FORGE IOB placement bugs | High | Use openXC7 Docker |
| FORGE OLOGIC missing ZINV/TFF | High | Use openXC7 Docker |
| JTAG fxload required each session | Medium | Automated in flash_safe.sh |
| LED D6 stuck on (FORGE) | Medium | Use openXC7 |

---

## Roadmap

### Phase 1: Foundation ✅
- Basic synthesis working (blink, counter)
- UART protocol defined
- openXC7 toolchain validated

### Phase 2: VSA Accelerator (Current)
- Complete VSA coprocessor
- UART host communication
- Hardware/software co-design

### Phase 3: Advanced Features
- RISC-V integration
- Quantum consciousness modules
- Performance optimization

---

φ² + 1/φ² = 3 = TRINITY
