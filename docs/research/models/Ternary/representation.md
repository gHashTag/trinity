# Ternary Representation ADR

## Decision Record

**ADR-002:** Packed trit encoding for memory efficiency

## Context

Trinity uses ternary representations with trits {-1, 0, +1}. Efficient memory representation requires packing multiple trits into storage units.

## Decision

**Use packed trit encoding: 2 bits per trit**

## Rationale

- **Memory efficiency:** 2 bits/trit provides good balance
- **Alignment:** Packs 4 trits into 8 bits (1 byte boundary)
- **Decoding:** Fast bit-level extraction for trit access

## Trade-offs

| Approach | Bits per Trit | Memory Efficiency | Decoding Cost |
|-----------|----------------|-------------------|----------------|
| 1 bit/trit (packed) | 1.0 | High | Low |
| 2 bits/trit (chosen) | 2.0 | Medium | Medium |
| 3 bits/trit (direct) | 3.0 | Low | Zero |

## Implementation

The full representation analysis is in:

**[docs/docs/concepts/balanced-ternary.md](../../docs/concepts/balanced-ternary.md)**

## Related

- [Overview: ./balanced-ternary.md](./balanced-ternary.md)
- [Hybrid API: ../Hybrid/api.md](../Hybrid/api.md)
