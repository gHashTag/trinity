# Trinity Brain Phase 1 Specification

## Overview
Phase 1 implements 20 brain cells organized into 3 layers:
- **Prefrontal Cortex (PFC)**: Decision making, planning, value assessment
- **Brainstem**: Vital functions, arousal
- **Reticular Formation**: Activation, sleep/wake

## Cells Created

### Prefrontal Cortex (13 cells)
| File | Lines | Function |
|------|-------|----------|
| queen_dlpfc.zig | 440 | DLPFC - READ THINK ACT SPEAK loop (PHASE=1 READ ONLY) |
| queen_senses.zig | 512 | Sensory input processing |
| queen_types.zig | 514 | Shared type definitions |
| queen_telegram.zig | 620 | Telegram interface |
| queen_policy.zig | 730 | Policy enforcement |
| queen_ofc.zig | 224 | OFC - reward valuation |
| queen_vmpfc.zig | 167 | VMPFC - value assessment |
| queen_vlpfc.zig | 250 | VLPFC - planning |
| queen_dmpfc.zig | 230 | DMPFC - action selection |
| queen_actions.zig | 314 | Action execution |
| queen_cortex.zig | 67 | Facade (re-export) |

### Brainstem (4 cells)
| File | Lines | Function |
|------|-------|----------|
| phoenix_core.zig | 917 | Core Phoenix system |
| phoenix_locus_coeruleus.zig | 277 | Locus Coeruleus - norepinephrine |
| phoenix_pons.zig | 159 | Pons - sleep regulation |
| phoenix_medulla.zig | 157 | Medulla - vital functions |

### Reticular Formation (3 cells)
| File | Lines | Function |
|------|-------|----------|
| reticular_aras.zig | 267 | ARAS - activation |
| reticular_gigantocellular.zig | 247 | Gigantocellular - motor |
| reticular_raphe.zig | 210 | Raphe - serotonin |

## Interface Pattern
- All cells have `pub fn health()` returning status struct
- Phase 1 uses direct `@import` (acceptable for isolated cells)
- Phase 2 will replace with callback interfaces

## DLPFC Phase 1
- `PHASE = 1` (READ ONLY)
- Decisions logged, NOT executed
- Prevents autonomous actions during development
