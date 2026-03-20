# FPGA Cost Model for Hardware-Aware Evolution

## Overview

The FPGA cost model integrates hardware resource budgets into the Sacred evolution simulation, enabling Bayesian optimization (BO) to find FPGA-ideal architectures that balance performance with hardware constraints.

## Cost Model

### Normalized FPGA Cost (0-1, where 1 = cheapest)

`fpga_cost_norm = (lut_ratio * 0.7 + bram_ratio * 0.3)`

Where:
- `lut_ratio = fpga_lut / 50000` (normalized to 0-1)
- `bram_ratio = fpga_bram / 200` (normalized to 0-1)

### Budget Constraints (Artix-7 K=16)

| Resource | Budget | Percentage |
|---------|-------|-----------|
| LUT     | 50,000 | 100% |
| BRAM36 | 100     | 74% |
| DSP     | 0        | 0%   |

## Scenario FPGA Costs

| Scenario | LUT (K) | BRAM | Cost (norm) |
|--------|----------|-----------------|--------|
| S1 Baseline | 8K (16%) | 30 (15%) | 0.22 |
| S2 Current | 19K (38%) | 100 (50%) | 0.40 |
| S3 Multi-Obj | 14K (28%) | 50 (25%) | 0.42 |
| S4 dePIN | 25K (50%) | 110 (55%) | 0.50 |
| S5 dePIN NI | 25K (50%) | 110 (55%) | 0.50 |
| S6 JEPA-Heavy | 16K (32%) | 85 (42%) | 0.46 |
| S7 High-Diversity | 15K (30%) | 60 (30%) | 0.27 |
| S8 Low-Crash | 13K (26%) | 75 (37.5%) | 0.20 |
| S9 Byzantine-Heavy | 16K (32%) | 85 (42%) | 0.46 |
| S10 Energy-Opt | 12K (24%) | 50 (25%) | 0.15 |
| S11 Sacred-A | 25K (50%) | 80 (40%) | 0.40 |
| S12 Sacred-B | 35K (70%) | 120 (60%) | 0.50 |
| S13 Sacred-C | 15K (30%) | 90 (45%) | 0.25 |
| S14 Wide | 18K (36%) | 100 (50%) | 0.30 |
| S15 Baseline-Ext | 18K (36%) | 100 (50%) | 0.30 |

## Cost Calculation

### LUT Cost

`lut_cost = 1.0` per operation/worker (baseline)

### BRAM Cost

`bram_cost = 10.0` per memory block (normalized to BRAM36)

### Energy Cost

`energy_cost = workers_alive × steps × 1000`

Each iteration represents 1000 simulated steps per worker.

## Implementation

**File:** `src/brain/evolution_simulation.zig`

**Structs:**
- `FpgCost` - hardware cost model
- `EvolutionSimulationConfig.fpga_lut`, `.fpga_bram`, `.fpga_dsp`
- `EvolutionResult.fpga_lut`, `.fpga_bram`, `.fpga_dsp`, `.fpga_cost_norm`

**Functions:**
- `FpgCost.normalizedCost(lut, bram, dsp)` - returns 0-1 normalized cost
- Energy cost calculation in simulation `run()`:
  ```zig
  var total_energy: f32 = 0.0;
  for (self.timeline[0..self.timeline_count]) |entry| {
      total_energy += @as(f32, @floatFromInt(entry.alive_workers));
  }
  const energy_cost = total_energy * 1000.0; // 1000 steps per iteration
  ```

## Future Work

1. **Quantum scenarios (S16-S20)** - add FPGA constraints
2. **FPGA-aware BO optimization** - integrate cost model into SEVO algorithm
3. **CSV export** - ✅ DONE: FPGA cost columns (fpga_lut, fpga_bram, fpga_cost_norm)
4. **Visualization** - ✅ DONE: `tri-sim-plot --view=fpga` mode added
5. **Test fixes** - ✅ DONE: All 23 evolution_simulation tests pass

## References

- Artix-7 K=16 synthesis: `papers/fpga_synthesis_results.md`
- Wide BRAM discovery: `project_fpga_wide_bram.md`
- FPGA cost model: `src/brain/evolution_simulation.zig`
- Energy cost model: `src/brain/evolution_simulation.zig` (energy_cost calculation)
