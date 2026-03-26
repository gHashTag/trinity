# Trinity Glossary

Technical terms and concepts used throughout Trinity documentation.

---

## A

### AGI (Artificial General Intelligence)
Hypothetical AI with human-level cognitive abilities across all domains. Trinity aims to contribute research toward AGI through biological architectures.

### Agent
Autonomous software component that performs tasks. Trinity includes multiple agents:
- **Ralph**: Sleep-wake daemon for GitHub issues
- **tri-api**: Standalone agentic loop (Claude Code replacement)
- **tri-bot**: Telegram bot with SSE streaming

### Allocator
Zig memory management interface. Explicit allocators required for most operations.

---

## B

### Bind (VSA)
VSA operation that associates two vectors. `bind(a, b)` creates a bound representation.

See: [src/vsa/core.zig](../src/vsa/core.zig)

### BitNet
Neural network architecture using ternary weights {-1, 0, +1} for 20x memory efficiency.

### Board
GitHub Project Board for tracking issues. Commands: `tri board <action>`

### BRAM (Block RAM)
FPGA memory resource. Trinity uses 98% of BRAM on XC7A100T.

### Bundle (VSA)
VSA operation for majority voting. `bundle2(a, b)`, `bundle3(a, b, c)` combine vectors.

---

## C

### Cell (Honeycomb)
Smallest unit of Trinity architecture. 116 cells in v30, organized by domain (math, bio, neuro, chem, cosmos).

### Claude Code
Anthropic's CLI coding tool. `tri-api` is Trinity's replacement/addition.

### CLAUDE.md
Project instructions for AI agents. **Never** bypass without maintainer approval.

### Commit Format
Trinity uses Conventional Commits:
```
<type>(<scope>): <description> (#<issue>)
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

### Cortex
Brain module responsible for agent coordination (Faculty Board).

See: [src/tri/cortex.zig](../src/tri/cortex.zig)

---

## D

### DePIN (Decentralized Physical Infrastructure Network)
Trinity's distributed inference network with token staking.

### dev (Development Commands)
Rigid Process Framework commands:
```bash
tri dev start --issue <N>
tri dev test
tri dev commit "msg"
tri dev ship
```

### DSP (Digital Signal Processing)
FPGA resource for multiply-accumulate operations. Trinity uses **0 DSP blocks** (pure LUT ternary compute).

---

## E

### Episode
Single training cycle in T-JEPA. TRI-27 has 15 episode tests passing.

### Experience (FPGA)
`.trinity/fpga/experience.json` logs FPGA operations to prevent repeating failed attempts.

---

## F

### Faculty Board
Agent-to-agent communication system (A2A) with phi-based voting (V=1.311).

Command: `tri faculty`

### Farm
Training farm on Railway with 100+ workers across multiple accounts.

Commands: `tri farm status`, `tri farm recycle`, `tri farm evolve`

### Flash (FPGA)
Programming bitstream onto FPGA. **REQUIRES** `fxload` first to switch JTAG cable mode.

### fxload
USB utility to switch FTDI JTAG cable from bootloader (PID 0x0013) to JTAG mode (PID 0x0008).

**CRITICAL**: Always run fxload before FPGA operations.

---

## G

### Git Workflow
Trinity uses specific git workflow:
- Branch: `feat/issue-{N}` or `fix/issue-{N}`
- Commit: `feat(scope): description (#N)`
- Push: Create PR with `Closes #N`

### Golden Chain
28-link pipeline for code generation. Current version: v5.1.

---

## H

### Honeycomb
Cell-based architecture system. v30 has 116 cells across 5 domains.

Health formula:
```
health = 100 × (0.4 × generated_ratio + 0.3 × compliance_rate
              + 0.2 × specs_coverage + 0.1 × tests_passing)
```

### HSLM (Hyper-Sparse Language Model)
Trinity's ternary language model. Variants: NTP, JEPA, NCA, Hybrid.

---

## I

### Issue
GitHub issue tracking. All significant work tracked via issues.

Commands: `tri issue list`, `tri issue create`, `tri issue comment`

---

## J

### JEPA (Joint Embedding Predictive Architecture)
Architecture for self-supervised learning. Trinity has T-JEPA implemented.

See: [src/hslm/tjepa.zig](../src/hslm/tjepa.zig)

### JTAG
Joint Test Action Group interface for FPGA programming.

---

## L

### LUT (Look-Up Table)
FPGA resource for logic. Trinity uses 5.8% LUT on XC7A100T.

---

## M

### MCP (Model Context Protocol)
Protocol for tool integration. Trinity has 3 MCP servers: trinity (47 tools), needle (6 tools), zig-docs (4 tools).

### MEMORY.md
Auto-memory file at `.claude/projects/-Users-playra-trinity-w1/memory/MEMORY.md`. Must be <200 lines.

---

## N

### Namespace
Command grouping syntax: `tri <namespace> <command>`

Examples: `tri dev status`, `tri fpga flash`, `tri farm evolve`

### NTP (Next Token Prediction)
Standard language modeling architecture.

---

## O

### Ouroboros
Self-referential training monitoring system. Checks loss convergence and config health.

---

## P

### Phoenix
Self-regenerating cell system. Commands: `tri phoenix scan`, `tri phoenix regen`

### Pipeline
Code generation pipeline. Commands: `tri pipeline run "<task>"`

### PR (Pull Request)
GitHub pull request. Commands: `tri pr list`, `tri pr create`

---

## Q

### Queen Trinity
27-screen SwiftUI UI for Trinity management.

Commands: `tri queen ui`, `tri queen build`, `tri queen kill`

---

## R

### Ralph
Sleep-wake agent daemon. Picks GitHub issues and manages workflow.

### README.md
Main project documentation. Should always be up to date.

### REPL (Read-Eval-Print Loop)
Interactive mode. Run `tri` for interactive REPL.

---

## S

### SACRED (Sacred Architecture for Computing Evolutionary Development)
Trinity's mathematical framework based on φ (golden ratio).

Identity: `φ² + 1/φ² = 3 = TRINITY`

### SEBO (Sacred EVolutionary Objective Search)
Evolutionary hyperparameter optimization for training.

### Swarm
Multi-agent coordination system. Command: `tri swarm <action>`

---

## T

### T-JEPA (Ternary JEPA)
Ternary version of JEPA architecture. **IMPLEMENTED** in `src/hslm/tjepa.zig`.

Status: All 46/46 tests passing, 15/15 episode tests passing.

### TRI-27
Trinity Instruction Set Architecture v27. 7 opcode groups.

Commands: `tri tri27 asm`, `tri tri27 disasm`, `tri tri27 run`

### Trinity Identity
`φ² + 1/φ² = 3` — mathematical foundation connecting golden ratio to ternary computing.

---

## U

### Unbind (VSA)
VSA operation to retrieve from binding. `unbind(bound, key)` recovers original vector.

### UART
Universal Asynchronous Receiver-Transmitter. FPGA communication protocol.

See: [fpga/openxc7-synth/UART_README.md](../fpga/openxc7-synth/UART_README.md)

---

## V

### VIBEE
V-specified BEE — compiler that generates Zig/Verilog from `.tri` specifications.

Command: `tri vibee gen <spec>`

### VSA (Vector Symbolic Architecture)
Cognitive computing framework. Operations: bind, unbind, bundle, similarity.

See: [src/vsa/core.zig](../src/vsa/core.zig)

---

## Z

### Zenodo
Scientific data repository for Trinity publications.

Records:
- 18939352: v2.0.1
- 18947017: concept DOI
- 18950696: v2.0.3

### Zig
Programming language for Trinity. Required version: **0.15.x**

---

## Symbols

### φ (phi)
Golden ratio ≈ 1.61803398874989482

### φ² + 1/φ² = 3
Trinity Identity. Foundation for mathematical framework.

### {-1, 0, +1}
Ternary values used in Trinity computations.

---

## Acronyms Summary

| Acronym | Full Name |
|---------|-----------|
| AGI | Artificial General Intelligence |
| API | Application Programming Interface |
| BRAM | Block RAM |
| CI | Continuous Integration |
| CPU | Central Processing Unit |
| CPLD | Complex Programmable Logic Device |
| D2XX | FTDI direct driver |
| DePIN | Decentralized Physical Infrastructure Network |
| DSP | Digital Signal Processing |
| EVT | Event |
| FPGA | Field-Programmable Gate Array |
| FTDI | Future Technology Devices International |
| FX2 | Cypress FX2 USB microcontroller |
| HTTP | Hypertext Transfer Protocol |
| HSLM | Hyper-Sparse Language Model |
| ISA | Instruction Set Architecture |
| JEPA | Joint Embedding Predictive Architecture |
| JSON | JavaScript Object Notation |
| JTAG | Joint Test Action Group |
| LLM | Large Language Model |
| LOC | Lines of Code |
| LUT | Look-Up Table |
| MCP | Model Context Protocol |
| NTP | Next Token Prediction |
| NCA | Non-contrastive Architecture |
| PAT | Personal Access Token |
| PR | Pull Request |
| RAM | Random Access Memory |
| REPL | Read-Eval-Print Loop |
| ROM | Read-Only Memory |
| RPC | Remote Procedure Call |
| SACRED | Sacred Architecture for Computing Evolutionary Development |
| SEBO | Sacred EVolutionary Objective Search |
| SSE | Server-Sent Events |
| STEM | Science, Technology, Engineering, Mathematics |
| T-JEPA | Ternary JEPA |
| TRI | Ternary Recursive Interface |
| UART | Universal Asynchronous Receiver-Transmitter |
| USB | Universal Serial Bus |
| VIBEE | V-specified BEE |
| VSA | Vector Symbolic Architecture |
| WSL | Windows Subsystem for Linux |

---

*Last updated: 2026-03-24*
