# HSLM Checkpoint Binary Format

## Header: 16 bytes

| Offset | Size | Field | Format |
|--------|------|-------|--------|
| 0x00 | 4 | Magic | "MSLH" (0x484C534D LE) |
| 0x04 | 4 | Version | uint32 LE (currently 1) |
| 0x08 | 4 | Step | uint32 LE |
| 0x0C | 4 | Loss | float32 LE |

## Body

Raw weight tensor data follows the 16-byte header.
Checkpoint size: 4,971,796 bytes (~4.7 MB) for 1.95M parameter model.

## Notes

- Magic bytes spell "HSLM" when read as little-endian
- Loss is validation loss at checkpoint step
- PPL = exp(loss)
- No optimizer state saved (m/v/t) — v2 format adds this
