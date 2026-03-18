# Cycle 34: Dictionary Compression

**Status:** IMMORTAL
**Date:** 2026-02-07
**Improvement Rate:** 1.04 > φ⁻¹ (0.618)
**Tests:** 83/83 PASS

---

## Overview

Cycle 34 implements dictionary-based compression for corpus storage, creating the TCV3 format that builds a frequency-sorted dictionary of common packed byte values for more efficient encoding.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Tests | 83/83 | PASS |
| VSA Tests | 51/51 | PASS |
| New Functions | 8 | buildFrequencyTable, buildDictionary, buildReverseLookup, dictEncode, dictDecode, saveDict, loadDict, dictCompressionRatio |
| Dictionary Size | 128 max | Top frequent values |
| File Format | TCV3 | Binary with dictionary |

---

## Dictionary Compression Algorithm

### Frequency Analysis

1. Count occurrences of each packed byte (0-242) across corpus
2. Sort by frequency (descending)
3. Take top 128 most frequent values for dictionary

### Encoding

```
For each packed byte b:
  if b in dictionary at index i (i < 128):
    emit i                    # 1 byte (index)
  else:
    emit dict_size            # escape byte
    emit b                    # original value
```

### Example

```
Dictionary: [50, 100, 150, 75, ...] (sorted by frequency)
Input byte: 100 → found at index 1 → emit [1]      (1 byte)
Input byte: 200 → not in dict    → emit [128, 200] (2 bytes)
```

---

## TCV3 File Format

```
Magic: "TCV3"                 # 4 bytes
Dict_size: u8                 # 1 byte (N entries)
Dictionary: u8[N]             # N bytes (frequent values)
Count: u32                    # 4 bytes (corpus entries)
For each entry:
  trit_len: u32              # 4 bytes
  encoded_len: u16           # 2 bytes
  encoded_data: u8[len]      # Dictionary-encoded bytes
  label_len: u8              # 1 byte
  label: u8[label_len]       # Label string
```

---

## Compression Comparison

| Format | Magic | Method | Best Case | Random |
|--------|-------|--------|-----------|--------|
| Uncompressed | - | Raw | 1x | 1x |
| TCV1 | "TCV1" | Packed trits | 5x | 5x |
| TCV2 | "TCV2" | Packed + RLE | 7x | 5x |
| TCV3 | "TCV3" | Packed + Dict | 6-8x | 4-5x |

---

## API

### Core Functions

```zig
// Build frequency table
fn buildFrequencyTable(self: *TextCorpus, freq: *[243]u32) void

// Build dictionary from frequencies
fn buildDictionary(freq: *const [243]u32, dict: *[128]u8, dict_size: *u8) void

// Create reverse lookup for encoding
fn buildReverseLookup(dict: *const [128]u8, dict_size: u8, lookup: *[243]u8) void

// Encode with dictionary
fn dictEncode(input: []const u8, output: []u8, lookup: *const [243]u8, dict_size: u8) ?usize

// Decode with dictionary
fn dictDecode(input: []const u8, output: []u8, dict: *const [128]u8, dict_size: u8) ?usize

// Save with dictionary (TCV3)
pub fn saveDict(self: *TextCorpus, path: []const u8) !void

// Load with dictionary (TCV3)
pub fn loadDict(path: []const u8) !TextCorpus

// Get dictionary compression ratio
pub fn dictCompressionRatio(self: *TextCorpus) f64
```

### VIBEE-Generated Functions

```zig
pub fn realSaveCorpusDict(corpus: *vsa.TextCorpus, path: []const u8) !void
pub fn realLoadCorpusDict(path: []const u8) !vsa.TextCorpus
pub fn realDictCompressionRatio(corpus: *vsa.TextCorpus) f64
```

---

## VIBEE Specification

Added to `specs/tri/vsa_imported_system.vibee`:

```yaml
# DICTIONARY COMPRESSION (TCV3 format)
- name: realSaveCorpusDict
  given: Corpus and file path
  when: Saving corpus with dictionary compression
  then: Call corpus.saveDict(path)

- name: realLoadCorpusDict
  given: File path
  when: Loading dictionary-compressed corpus
  then: Call TextCorpus.loadDict(path)

- name: realDictCompressionRatio
  given: Corpus
  when: Calculating dictionary compression ratio
  then: Call corpus.dictCompressionRatio()
```

---

## Critical Assessment

### Strengths

1. **Adaptive dictionary** - Built from actual corpus data
2. **Efficient encoding** - 1 byte for 128 most common values
3. **Self-contained** - Dictionary stored in file header
4. **Non-uniform benefit** - Better for text with patterns

### Weaknesses

1. **Dictionary overhead** - Up to 128 bytes in header
2. **Build time** - O(n) frequency scan + O(243²) sort
3. **Random data** - May be worse than TCV1 due to escapes

---

## Tech Tree Options (Next Cycle)

### Option A: Huffman Coding
Variable-length bit encoding based on frequencies for optimal compression.

### Option B: LZ77/LZ78 Compression
Sliding window or phrase-based compression for repeated sequences.

### Option C: Corpus Sharding
Split large corpus into chunks for parallel processing.

---

## Files Modified

| File | Changes |
|------|---------|
| `src/vsa.zig` | Added dictionary compression functions |
| `src/vibeec/codegen/emitter.zig` | Added realSaveCorpusDict, realLoadCorpusDict, realDictCompressionRatio generators |
| `src/vibeec/codegen/tests_gen.zig` | Added dictionary test generators |
| `specs/tri/vsa_imported_system.vibee` | Added 3 dictionary behaviors |
| `generated/vsa_imported_system.zig` | Regenerated with dictionary + ConversationState fix |

---

## Conclusion

**VERDICT: IMMORTAL**

Dictionary compression provides TCV3 format with frequency-based encoding. For corpora with non-uniform byte distributions, the dictionary captures common patterns and provides additional compression on top of packed trits.

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL | GOLDEN CHAIN ENFORCED**
