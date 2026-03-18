# Queen Phase 2 Specification

## Overview
Phase 2 wires the brain cells into a unified thinking loop.

## Phase 2 Goals
1. **Callback Interfaces**: Replace direct @import with callbacks
2. **Motor Cortex**: Add M1 for action execution
3. **Premotor Cortex**: Add PMC for action sequencing
4. **Unified Loop**: Wire READ→THINK→ACT→SPEAK

## Unified Loop
```
READ (senses) → THINK (dlpfc) → ACT (dmpfc) → SPEAK (motor)
     ↑              ↓                ↓              ↓
     └────────────── feedback ──────────────────────┘
```

## Callback Interface Pattern
```zig
pub const SensesCallback = *const fn() SenseResult;
pub const ThinkCallback = *const fn(SenseResult) Decision;
pub const ActCallback = *const fn(Decision) ActionResult;
pub const SpeakCallback = *const fn(ActionResult) Message;

pub fn UnifiedBrain struct {
    senses: SensesCallback,
    think: ThinkCallback,
    act: ActCallback,
    speak: SpeakCallback,
};
```

## Files to Create
- `src/tri/queen_motor.zig` - Primary Motor Cortex M1
- `src/tri/queen_premotor.zig` - Premotor Cortex PMC

## Files to Modify
- `src/tri/queen_telegram.zig` - Add callback interfaces
- `src/tri/queen_dlpfc.zig` - Phase 2 (enable execution)

## DLPFC Phase 2
- Change `PHASE = 2` (EXECUTE)
- Execute decisions after logging
- Add feedback loop
