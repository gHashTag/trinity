---
sidebar_position: 14
sidebar_label: TVC Learning
---

# TVC Distributed Learning

TVC (Ternary Vector Corpus) is Trinity's distributed continual learning system. It provides zero-forgetting knowledge storage using ternary vector embeddings, bundled into a persistent corpus for instant retrieval.

## Commands

### tvc-demo

Interactive demonstration of the TVC distributed learning system.

**Aliases:** `tvc`

```bash
tri tvc-demo
```

Shows:
- Corpus architecture and configuration
- Hit/miss semantics with cosine similarity
- Bundling and retrieval demo
- Distributed learning flow

**Example output:**

```
TVC DISTRIBUTED LEARNING — DEMO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Architecture:
  ┌──────────────┐    ┌──────────────┐
  │   Query      │───→│  TVC Corpus  │
  │  (embed)     │    │  10K entries │
  └──────────────┘    └──────┬───────┘
                             │
                    ┌────────┴────────┐
                    │  Similarity ≥ φ⁻¹│
                    │  (0.618)?       │
                    └────────┬────────┘
                     YES     │     NO
                 ┌───────┐   │   ┌───────┐
                 │ CACHE  │       │  LLM  │
                 │  HIT   │       │ CALL  │
                 └────────┘       └───────┘

Configuration:
  Capacity:      10,000 entries (100x TextCorpus)
  Dimensions:    1,000 trits per vector
  Threshold:     phi^-1 = 0.618
  Encoding:      Ternary {-1, 0, +1}
  File format:   .tvc (TVC1 magic header)
  Memory:        ~26 MB heap-allocated
```

### tvc-stats

Display TVC corpus configuration and statistics.

```bash
tri tvc-stats
```

**Example output:**

```
TVC CORPUS STATISTICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Capacity:         10,000 entries
  Vector dimension: 1,000 trits
  Threshold:        0.618 (phi^-1)
  Encoding:         Ternary {-1, 0, +1}
  Storage:          ~26 MB

  File format:
    Magic:          TVC1
    Header:         64 bytes
    Entry size:     1,000 bytes + metadata

  Bundling:
    Method:         Majority vote
    Memory vector:  Bundled accumulator
    Forgetting:     ZERO (all patterns retained)
```

## Architecture

### How TVC Works

1. **Query embedding:** User input is converted to a 1,000-trit ternary vector
2. **Similarity search:** Cosine similarity is computed against all corpus entries
3. **Threshold check:** If similarity $\geq \phi^{-1} = 0.618$, it's a **cache hit**
4. **Hit:** Return cached response instantly (no LLM call needed)
5. **Miss:** Call LLM, then store the query-response pair in the corpus

### Zero-Forgetting Bundling

TVC uses the VSA **bundle** operation (majority vote) to accumulate all learned patterns into a single `memory_vector`. This means:

- No patterns are ever discarded
- New knowledge is **bundled** with existing knowledge
- Retrieval uses cosine similarity against the bundled vector
- Capacity: 10,000 discrete entries + 1 bundled memory vector

### Comparison with TextCorpus

| Feature | TextCorpus | TVC Corpus |
|---------|-----------|------------|
| Capacity | 100 entries | 10,000 entries |
| Vector type | Float32 | Ternary {-1, 0, +1} |
| Memory | ~40 MB | ~26 MB |
| Compression | None | 20x (vs float32) |
| Forgetting | FIFO eviction | Zero-forgetting |
| Bundling | No | Yes (majority vote) |
| File format | JSON | .tvc binary |

### File Format

TVC files use a binary format with a `TVC1` magic header:

```
Offset  Size    Field
0x00    4       Magic: "TVC1"
0x04    4       Version
0x08    4       Entry count
0x0C    4       Vector dimension
0x10    48      Reserved
0x40    ...     Entries (vector + metadata)
```

**Save path:** `trinity_chat.tvc` (auto-saved on REPL exit)

## Sacred Mathematics

The TVC threshold is derived from the golden ratio:

$$\text{threshold} = \phi^{-1} = \frac{1}{\phi} = \phi - 1 = 0.6180339887...$$

This is the **Needle threshold** (Koschei's Needle) — the minimum similarity required for a cache hit. The number $\phi^{-1}$ is the reciprocal of the golden ratio and appears throughout Trinity's architecture as the quality gate.

## Integration with Chat

TVC is automatically loaded when starting the REPL or using `tri chat`:

```bash
# TVC is loaded automatically
tri chat "What is VSA?"

# First time: LLM call + stored in TVC
# Second time: instant cache hit
tri chat "What is VSA?"
```

The TVC corpus persists across sessions via the `trinity_chat.tvc` file.

## See Also

- [Interactive REPL](/cli/repl) — REPL mode with TVC integration
- [Core Commands](/cli/core) — Chat command details
- [Demos & Benchmarks](/cli/demos) — Needle Check benchmarks
- [Sacred Math](/cli/math) — Golden ratio constants
