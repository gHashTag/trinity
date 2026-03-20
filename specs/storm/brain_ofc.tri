# OFC — Orbitofrontal Cortex, Палата ценностей

## Module
storm.brain_zones.ofc

## Description
Orbitofrontal Cortex — Палата ценностей. 12D ethical metric system for toxic verdict detection.

## Dependencies
- std

## Structs
### Dimension
enum(u4) {
    corruption,      // Коррупция
    dishonesty,      // Ложь
    cruelty,         // Жестокость
    broken_promises, // Нарушение обещаний
    danger,          // Опасность
    unfairness,      // Несправедливость
    machiavellian,   // Макиавеллизм
    hubris,          // Хюбрис
    bad_selection,   // Негативный отбор
    no_empathy,      // Утрата эмпатии
    lock_in,         // Технофеодальная блокировка
    distrust,        // Кризис доверия
}

### Verdict
enum {
    safe,   // Allow action
    warn,   // Review needed
    toxic,  // Block action
}

### Action
- description: []const u8
    agent: ?[]const u8 = null
    reward: ?f32 = null
    effort: ?f32 = null

### Context
- timestamp: i64
    issue_id: ?u32 = null
    task: []const u8

### OFC
- allocator: std.mem.Allocator
    threshold_warn: f32 = 0.4
    threshold_toxic: f32 = 0.7

### DimensionScore
- dimension: Dimension
    score: f32 (0.0 to 1.0)
    weight: f32 = 1.0

### VerdictResult
- verdict: Verdict
    scores: [12]DimensionScore
    average: f32
    reason: []const u8

## Constants
### DEFAULT_WEIGHTS
[12]f32 — equal weight 1.0 for all dimensions.

### PHI_SCALING
f32 = 1.618 — golden ratio scaling for aggregate score.

## Functions
### init(allocator) !OFC
Initialize OFC with default thresholds.

### verdict(ofc, ctx, action) !VerdictResult
Evaluate action against 12D ethical metric.
- Returns .toxic if average >= threshold_toxic (0.7)
- Returns .warn if average >= threshold_warn (0.4)
- Returns .safe otherwise

### evaluateDimension(ofc, dimension, ctx, action) !f32
Score single dimension (0.0 to 1.0).
- Checks: corruption, dishonesty, cruelty, etc.
- Returns normalized score.

### cmdVerdict(allocator, args) !u8
CLI: tri ofc verdict --toxic
Parse action from args, run verdict, print result with emoji.

### formatVerdict(result) ![]const u8
Format verdict as colored CLI output.
- GREEN for .safe
- YELLOW for .warn
- RED for .toxic

## CLI Integration
```bash
tri ofc verdict --toxic "description of action"
tri ofc check --dimension=corruption --context="..."
tri ofc dimensions  # List all 12 dimensions
```

## Tests
- Verdict thresholds (safe/warn/toxic)
- All 12 dimensions score 0.0-1.0
- Empty action returns .safe
- Context integration
