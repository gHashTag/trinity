# tri brain ofc — Orbitofrontal Cortex

## Module
tri.brain.ofc

## Description
Ethical evaluation chamber. OFC (Cortex orbitofrontalis) implements "toxic verdict".

## Subcommand
`tri brain ofc verdict --toxic <action>`

## Neuroanatomy
Cortex orbitofrontalis — value judgment, reward expectation, ethical decision-making.

## Structs
### Verdict
enum { SAFE, WARN, TOXIC }

### Metric (12D)
- corruption: f32 (0-1)
- cruelty: f32 (0-1)
- promise_break: f32 (0-1)
- fairness: f32 (0-1)
- transparency: f32 (0-1)
- accountability: f32 (0-1)
- empathy: f32 (0-1)
- respect: f32 (0-1)
- integrity: f32 (0-1)
- harm_prevention: f32 (0-1)
- consent: f32 (0-1)
- proportionality: f32 (0-1)

## Functions
### verdict(ctx, action) !Verdict
12D ethical assessment.

### cmdVerdict(args) !u8
CLI entry for `tri brain ofc verdict --toxic`.

## Thresholds
TOXIC_THRESHOLD: 0.7 (any metric > 0.9 or weighted > 0.7)
WARN_THRESHOLD: 0.5

## Weights (φ-based)
corruption, cruelty, promise_break: φ² ≈ 2.618
fairness, transparency, accountability: 1.0
others: 1/φ² ≈ 0.382
