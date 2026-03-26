# Integration Examples

> **Wave 1 Complete** — TRI-27, Queen, and FPGA working together

---

## Overview

This document provides end-to-end integration examples for Trinity's key components:
- **TRI-27** — Ternary RISC processor
- **Queen** — Self-learning brain system
- **FPGA** — Hardware backend

---

## TRI-27 + Queen Integration

### Episode-Based Learning

Queen observes TRI-27 execution, evaluates results, and generates policy adjustments.

**Workflow**:
```bash
# 1. Run TRI-27 program (generates episode)
tri tri27 run program.tbin

# 2. Queen observes results
tri queen observe

# 3. Queen generates policy
tri queen plan

# 4. Queen applies policy
tri queen act
```

**Episode Structure**:
```json
{
  "id": "uuid",
  "timestamp": "2026-03-26T12:00:00Z",
  "task": {
    "description": "fibonacci calculation",
    "params": {"n": 10}
  },
  "execution": {
    "cycles": 47,
    "result": {"t2": 55},
    "status": "success"
  },
  "queen": {
    "dipfc": {"state": "planning", "score": 0.85},
    "vmpfc": {"score": 0.9, "confidence": 0.95},
    "dlpfc": {"action": "assign", "queue": "medium"},
    "lotus_state": "purified"
  }
}
```

**File Locations**:
- Episodes: `.trinity/queen/episodes.jsonl`
- Queen Config: `.trinity/queen/tri27_config.json`
- Policy: `.trinity/queen/policy.json`
- Senses: `.trinity/queen/senses.json`

---

## Brain + FPGA Pipeline

### Complete Flow

From high-level task description to FPGA bitstream execution.

```
Task Description
    ↓
[Queen] Plan
    ↓
[TRI-27] Assembly
    ↓
[TRI-27] Compile to Binary
    ↓
[Queen] Verify
    ↓
[Queen] Diagnose
    ↓
[Queen] Purify
    ↓
[TRI-27] Disassemble
    ↓
[Verilog Backend] Generate Verilog
    ↓
[openXC7] Synthesize
    ↓
[FPGA] Flash
    ↓
Execute on Hardware
```

### Code Example

```zig
// src/integration/brain_fpga_pipeline.zig

pub const TaskPipeline = struct {
    description: []const u8,
    tri_source: []const u8,
    tri_binary: []u8,
    verilog_source: []const u8,
    bitstream: []const u8,
    execution: ExecutionResult,
};

pub fn runPipeline(task: Task) !TaskPipeline {
    // 1. Queen Plan
    const plan = try queen.plan(task);

    // 2. TRI-27 Assembly
    const source = try tri27.assemble(plan.tri_code);

    // 3. Binary Compilation
    const binary = try tri27.compile(source);

    // 4. Queen Verify
    _ = try queen.verify(binary);

    // 5. Queen Diagnose
    const diagnosis = try queen.diagnose(binary);

    // 6. Queen Purify
    const purified = try queen.purify(diagnosis);

    // 7. Verilog Generation
    const verilog = try tri27.verilogBackend(purified);

    // 8. FPGA Synthesis
    const bitstream = try fpga.synthesize(verilog);

    // 9. Flash
    try fpga.flash(bitstream);

    // 10. Execute & Collect Results
    const execution = try fpga.execute(bitstream);

    return TaskPipeline{
        .description = task,
        .tri_source = source,
        .tri_binary = binary,
        .verilog_source = verilog,
        .bitstream = bitstream,
        .execution = execution,
    };
}
```

---

## End-to-End Example

### Complete Training to Inference Pipeline

```bash
#!/usr/bin/env bash
# complete_pipeline.sh

# 1. Train HSLM
tri hslm train --config configs/training.json

# 2. Extract best checkpoint
tri hslm extract --checkpoint best

# 3. Compile to TRI-27
tri tri27 compile --model model.gguf --format tri

# 4. Queen validation
tri queen validate --input program.tri

# 5. Assemble for TRI-27
tri tri27 assemble program.tri -o program.tbin

# 6. Generate Verilog
tri tri27 verilog program.tbin -o rtl/tri27_core.v

# 7. FPGA synthesis
cd fpga/openxc7-synth
make hslm_tri27_top.bit

# 8. Flash to FPGA
sudo fxload -D 0008:0403 -t fx2 -I /usr/share/usb/contexts/04b4-0008
sudo ../tools/flash.sh hslm_tri27_top.bit

# 9. Run and collect metrics
tri tri27 run program.tbin --collect-metrics

# 10. Queen analyze results
tri queen analyze --episodes .trinity/queen/episodes.jsonl
```

---

## Monitoring & Debugging

### Real-Time Health Monitor

```bash
# Watch Queen health in real-time
tri queen watch --interval 30s --threshold 70

# Output format:
# [2026-03-26T12:00:00Z] dlpfc: 0.85 vmpfc: 0.90 ofc: STABLE vlpfc: 0.80 dmpfc: 0.75 acc: 0.05 lotus: purified
```

### Experience-Based Debugging

TRI-27 tracks past operations to avoid repeating failures.

```bash
# Initialize experience database
tri tri27 experience init

# Recall similar past operations
tri tri27 experience recall "fibonacci n=10"

# Output shows:
# Found 3 similar operations:
#   [ASM] fibonacci.tri n=10 (2026-03-25, success, 47 cycles)
#   [ASM] fibonacci.tri n=10 (2026-03-26, success, 45 cycles)
#   [RUN] fibonacci.tbin (2026-03-26, success, 43 cycles)

# Recommendation:
#   Try: "INC t0, JNZ t0, loop" (optimized pattern)
```

### VSA Debugging

```bash
# VSA operation visualization
tri vsa bind --a "cat" --b "pet" --visualize

# Shows hypervector representation:
# hypervector[cat]:  [-0.1, 0.3, -0.2, ..., 0.1]
# hypervector[pet]:  [-0.2, -0.1, 0.0, ..., 0.3]
# bind result:     [0.1, -0.2, 0.0, ..., 0.0] (intersection)
# similarity:      0.742 (cat-pet correlation)
```

---

## API Integration

### Queen Episode API

```bash
# Start Queen episode server
tri queen api --port 8080

# Example API call:
curl -X POST http://localhost:8080/api/v1/episode \
  -H "Content-Type: application/json" \
  -d '{
    "task": {"description": "compute fibonacci", "params": {"n": 10}},
    "priority": "high",
    "timeout": 60
  }'

# Response:
{
  "episode_id": "uuid",
  "status": "queued",
  "queue_position": 2,
  "estimated_completion": "2026-03-26T12:01:30Z"
}
```

### TRI-27 Episode API

```bash
# Start TRI-27 episode server
tri tri27 api --port 8081

# Example API call:
curl -X POST http://localhost:8081/api/v1/execute \
  -H "Content-Type: application/json" \
  -d '{
    "program": "fibonacci.tri",
    "input": {"n": 10},
    "mode": "emulate"
  }'

# Response:
{
  "episode_id": "uuid",
  "status": "running",
  "cycles": 0,
  "result": null
}
```

---

## Troubleshooting

### Common Issues

| Issue | Symptom | Solution |
|--------|----------|----------|
| Build fails | Zig 0.15 compatibility | Run `zig fmt src/` and check API changes |
| Flash fails | JTAG in bootloader mode | Run `fxload -D vendor:product -t fx2` before flash |
| Queen stuck | Episode backlog full | Increase `max_retries` in config |
| FPGA timeout | Program too long | Reduce complexity or enable pipelining |
| High memory usage | VSA hypervectors | Use sparse bundling or dimensionality reduction |

### Diagnostic Commands

```bash
# Check Queen health
tri queen health

# Check TRI-27 status
tri tri27 status

# Check FPGA status
tri fpga status

# Check system health
tri doctor

# View recent episodes
tri queen episodes --last 20

# View experience recall
tri tri27 experience recall --recent 10
```

---

## Performance Tips

### Optimize Lotus Cycle Speed

1. **Batch Episodes**: Process multiple small tasks together
2. **Cache VSA Results**: Reuse hypervector computations
3. **Parallel Queen Cells**: Enable concurrent dlpfc/vmpfc operations
4. **Reduce Diagnosis Depth**: Limit evaluation window to essential checks
5. **Experience Matching**: High confidence before full re-diagnosis

### Optimize FPGA Performance

1. **Pipeline Instructions**: Enable fetch-decode-execute pipeline
2. **Cache Memories**: Use BRAM for frequently accessed data
3. **Ternary Optimization**: Leverage {-1, 0, +1} encoding for smaller LUTs
4. **Clock Management**: Dynamic frequency scaling based on workload
5. **DSP-Free**: Prefer LUT-based ternary arithmetic (0 DSP blocks)

---

## References

- **TRI-27 Documentation**: [README](../tri27/README.md), [User Guide](../tri27/USER_GUIDE.md)
- **Queen Documentation**: [README](../README.md#queen-integration--lotus-cycle)
- **Brain Architecture**: [ARCHITECTURE.md](./ARCHITECTURE.md)
- **FPGA Documentation**: [FPGA README](../fpga/openxc7-synth/UART_README.md)
