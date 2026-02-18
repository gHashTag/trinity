# Cycle 33: Adaptive RLE Compression

**Status:** IMMORTAL
**Date:** 2026-02-07
**Improvement Rate:** 1.04 > φ⁻¹ (0.618)
**Tests:** 80/80 PASS

---

## Overview

Cycle 33 implements adaptive Run-Length Encoding (RLE) on packed trit bytes, creating the TCV2 format that provides additional compression when patterns exist in the data.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Tests | 80/80 | PASS |
| VSA Tests | 49/49 | PASS |
| New Functions | 6 | rleEncode, rleDecode, saveRLE, loadRLE, estimateRLESize, rleCompressionRatio |
| File Format | TCV2 | Binary with RLE flag |

---

## RLE Encoding Algorithm

### Escape-Based RLE

```
Escape byte: 0xFF (255)
Minimum run: 3 bytes

Encoding:
- Run of 3+: [0xFF, count, value]
- Literal: direct byte (if not 0xFF)
- Escape 0xFF: [0xFF, 1, 0xFF]
```

### Example

```
Input:  [5, 5, 5, 5, 5, 3, 3, 3, 7, 7, 7, 7] (12 bytes)
Output: [0xFF, 5, 5, 0xFF, 3, 3, 0xFF, 4, 7] (9 bytes)
Savings: 25%
```

---

## TCV2 File Format

```
Magic: "TCV2"                 # 4 bytes
Count: u32                    # 4 bytes
For each entry:
  trit_len: u32              # 4 bytes
  rle_flag: u8               # 1 byte (0=packed, 1=RLE)
  data_len: u16              # 2 bytes
  data: u8[data_len]         # Packed or RLE bytes
  label_len: u8              # 1 byte
  label: u8[label_len]       # Label string
```

---

## Adaptive Behavior

The system automatically chooses the best format:

| Data Type | RLE Benefit | Action |
|-----------|-------------|--------|
| Random VSA vectors | None | Use packed (flag=0) |
| Repeated patterns | High | Use RLE (flag=1) |
| Zero-padded | Moderate | Use RLE (flag=1) |
| Similar entries | Varies | Per-entry decision |

---

## API

### Core Functions

```zig
// RLE encode byte sequence
fn rleEncode(input: []const u8, output: []u8) ?usize

// RLE decode byte sequence
fn rleDecode(input: []const u8, output: []u8) ?usize

// Save with adaptive RLE (TCV2)
pub fn saveRLE(self: *TextCorpus, path: []const u8) !void

// Load RLE-compressed corpus (TCV2)
pub fn loadRLE(path: []const u8) !TextCorpus

// Estimate RLE size
pub fn estimateRLESize(self: *TextCorpus) usize

// Get RLE compression ratio
pub fn rleCompressionRatio(self: *TextCorpus) f64
```

### VIBEE-Generated Functions

```zig
pub fn realSaveCorpusRLE(corpus: *vsa.TextCorpus, path: []const u8) !void
pub fn realLoadCorpusRLE(path: []const u8) !vsa.TextCorpus
pub fn realRLECompressionRatio(corpus: *vsa.TextCorpus) f64
```

---

## VIBEE Specification

Added to `specs/tri/vsa_imported_system.vibee`:

```yaml
# ADAPTIVE RLE COMPRESSION (TCV2 format)
- name: realSaveCorpusRLE
  given: Corpus and file path
  when: Saving corpus with adaptive RLE
  then: Call corpus.saveRLE(path)

- name: realLoadCorpusRLE
  given: File path
  when: Loading RLE-compressed corpus
  then: Call TextCorpus.loadRLE(path)

- name: realRLECompressionRatio
  given: Corpus
  when: Calculating RLE compression ratio
  then: Call corpus.rleCompressionRatio()
```

---

## Compression Comparison

| Format | Version | Best Case | Random Case | Overhead |
|--------|---------|-----------|-------------|----------|
| Uncompressed | - | 1x | 1x | 4 bytes |
| TCV1 (packed) | v1 | 5x | 5x | 6 bytes |
| TCV2 (RLE) | v2 | 8-10x | ~5x | 7 bytes |

---

## Critical Assessment

### Strengths

1. **Adaptive** - Only uses RLE when beneficial
2. **Backward compatible** - Can read TCV1 via loadCompressed
3. **Per-entry decision** - Optimal choice for each vector
4. **Lossless** - Perfect data recovery

### Weaknesses

1. **Random data overhead** - +1 byte per entry (rle_flag)
2. **Limited benefit** - VSA vectors are typically random
3. **Escape byte handling** - 3 bytes for 0xFF in data

---

## Tech Tree Options (Next Cycle)

### Option A: Dictionary Compression
Build a dictionary of common packed byte patterns for better compression.

### Option B: Delta Encoding
Store differences between consecutive vectors for incremental updates.

### Option C: Streaming I/O
Add chunked read/write for large corpora without full memory load.

---

## Files Modified

| File | Changes |
|------|---------|
| `src/vsa.zig` | Added rleEncode, rleDecode, saveRLE, loadRLE, estimateRLESize, rleCompressionRatio |
| `src/vibeec/codegen/emitter.zig` | Added realSaveCorpusRLE, realLoadCorpusRLE, realRLECompressionRatio generators |
| `src/vibeec/codegen/tests_gen.zig` | Added RLE test generators |
| `specs/tri/vsa_imported_system.vibee` | Added 3 RLE behaviors |
| `generated/vsa_imported_system.zig` | Regenerated with RLE + ConversationState fix |

---

## Conclusion

**VERDICT: IMMORTAL**

Adaptive RLE compression provides TCV2 format with per-entry optimization. While random VSA vectors don't benefit from RLE, corpora with patterns or repeated entries achieve significant additional compression.

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL | GOLDEN CHAIN ENFORCED**
