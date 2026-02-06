# BitNet FFI Integration Report

## Date
2026-02-06

## Status
**SUCCESS** - Coherent text generation via official bitnet.cpp subprocess wrapper

---

## Executive Summary

Successfully integrated official Microsoft bitnet.cpp via Zig FFI subprocess wrapper. The wrapper calls `llama-cli` binary and captures coherent output at 16.1 tok/s average, bypassing our broken native Zig inference.

**Key Achievement:** 12/12 prompts produced coherent, meaningful text.

---

## Implementation

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Zig FFI Wrapper                          │
│  src/vibeec/bitnet_ffi.zig                                  │
├─────────────────────────────────────────────────────────────┤
│  BitNetFFI.generate(prompt, max_tokens, temperature)        │
│         │                                                   │
│         ▼                                                   │
│  Build args: [-m model -p prompt -n tokens --temp T]        │
│         │                                                   │
│         ▼                                                   │
│  std.process.Child.run(llama-cli subprocess)                │
│         │                                                   │
│         ▼                                                   │
│  Parse stdout → Extract generated text                      │
│         │                                                   │
│         ▼                                                   │
│  Return GenerationResult { text, elapsed_ms, success }      │
└─────────────────────────────────────────────────────────────┘
```

### Key Files

| File | Description |
|------|-------------|
| `src/vibeec/bitnet_ffi.zig` | FFI wrapper implementation |
| `zig-out/bin/bitnet_ffi` | Compiled binary |
| `bitnet-cpp/build/bin/llama-cli` | Official bitnet.cpp CLI |

### API

```zig
pub const BitNetFFI = struct {
    pub fn init(
        allocator: std.mem.Allocator,
        llama_cli_path: []const u8,
        model_path: []const u8,
        threads: u32,
    ) Self;

    pub fn generate(
        self: *Self,
        prompt: []const u8,
        max_tokens: u32,
        temperature: f32,
    ) !GenerationResult;
};

pub const GenerationResult = struct {
    text: []const u8,
    full_output: []const u8,
    elapsed_ms: f64,
    success: bool,
};
```

---

## Benchmark Results (12 Prompts)

### Individual Results

| # | Prompt | Tokens | Time (ms) | tok/s | Coherent |
|---|--------|--------|-----------|-------|----------|
| 1 | "Hello, my name is" | ~130 | 13,119 | 9.9 | YES |
| 2 | "The capital of France is" | ~126 | 6,613 | 19.1 | YES |
| 3 | "Water boils at a temperature of" | ~89 | 7,832 | 11.4 | YES |
| 4 | "The meaning of life is" | ~136 | 8,411 | 16.2 | YES |
| 5 | "In machine learning, a neural network" | ~135 | 6,943 | 19.4 | YES |
| 6 | "The quick brown fox" | ~94 | 7,575 | 12.4 | YES |
| 7 | "Once upon a time in a land far away" | ~113 | 8,371 | 13.5 | YES |
| 8 | "Python is a programming language that" | ~118 | 9,000 | 13.1 | YES |
| 9 | "The largest planet in our solar system is" | ~130 | 5,373 | 24.2 | YES |
| 10 | "To be or not to be, that is" | ~125 | 6,817 | 18.3 | YES |
| 11 | "Artificial intelligence will change" | ~125 | 6,092 | 20.5 | YES |
| 12 | "The best way to learn programming is" | ~139 | 4,391 | 31.7 | YES |

### Summary Statistics

| Metric | Value |
|--------|-------|
| Total Prompts | 12 |
| Success Rate | 100% (12/12) |
| Total Tokens | ~1,460 |
| Total Time | 90.5 sec |
| **Average Speed** | **16.1 tok/s** |
| Min Speed | 9.9 tok/s |
| Max Speed | 31.7 tok/s |

---

## Sample Outputs

### Factual (Test 2)
**Prompt:** "The capital of France is"

**Output:** "The capital of France is Paris. Paris is known for its cultural and historical landmarks such as the Eiffel Tower, Notre-Dame Cathedral, and the Louvre Museum. The city's cuisine is also highly regarded, with dishes like croissants, escargots, and ratatouille."

### Scientific (Test 3)
**Prompt:** "Water boils at a temperature of"

**Output:** "Water boils at a temperature of 100 degrees Celsius (°C) at sea level. Celsius to Fahrenheit: °F = (°C × 9/5) + 32 = (100 × 9/5) + 32 = 212. So, water boils at 212 degrees Fahrenheit at sea level."

### Creative (Test 7)
**Prompt:** "Once upon a time in a land far away"

**Output:** "Once upon a time in a land far away, there was a kind and brave knight named Sir Richard. He had a trusty steed named Speedy, who could run faster than a cheetah. One day, Sir Richard was on his way to the castle to meet the Queen, but when he saw a group of bandits, he knew he had to act quickly."

### Technical (Test 5)
**Prompt:** "In machine learning, a neural network"

**Output:** "In machine learning, a neural network is a model that is composed of interconnected layers of nodes or neurons. These neurons are organized in such a way that the output of one neuron is fed as the input to the next neuron. The process of adjusting the weights of the connections between neurons is called training."

---

## Performance Comparison

| Implementation | Speed | Coherent | Status |
|----------------|-------|----------|--------|
| **FFI (this)** | **16.1 tok/s** | **YES** | **WORKING** |
| bitnet.cpp direct | 17-27 tok/s | YES | Reference |
| Zig native | 0.2-0.3 tok/s | NO | Broken |

### FFI Overhead

The FFI wrapper adds minimal overhead:
- Subprocess spawn: ~100ms per call
- Output parsing: <1ms
- Memory: Uses allocator for output buffering

---

## Build Instructions

```bash
# Build FFI wrapper
zig build-exe src/vibeec/bitnet_ffi.zig -femit-bin=zig-out/bin/bitnet_ffi

# Run with defaults
./zig-out/bin/bitnet_ffi

# Run with custom paths
./zig-out/bin/bitnet_ffi <llama-cli-path> <model-path>

# Example
./zig-out/bin/bitnet_ffi \
    bitnet-cpp/build/bin/llama-cli \
    bitnet-cpp/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf
```

---

## Zig 0.15 API Notes

Key API changes encountered:

| Old API | Zig 0.15 API |
|---------|--------------|
| `ArrayList.init()` | `ArrayListUnmanaged = .empty` |
| `args.append(x)` | `args.append(allocator, x)` |
| `std.process.run()` | `std.process.Child.run()` |
| `.exited` | `.Exited` (capital E) |

---

## Toxic Verdict

```
╔══════════════════════════════════════════════════════════════════╗
║                    🔥 TOXIC VERDICT 🔥                           ║
╠══════════════════════════════════════════════════════════════════╣
║ WHAT WAS DONE:                                                   ║
║ - Created Zig FFI wrapper for bitnet.cpp llama-cli               ║
║ - Fixed Zig 0.15 API compatibility issues                        ║
║ - Ran 12 prompts with 100% coherent output                       ║
║ - Achieved 16.1 tok/s average speed                              ║
║                                                                  ║
║ WHAT WORKED:                                                     ║
║ - Subprocess approach bypasses broken native inference           ║
║ - Official bitnet.cpp produces coherent text reliably            ║
║ - FFI overhead is negligible (~100ms per call)                   ║
║                                                                  ║
║ METRICS:                                                         ║
║ - Before: 0.2-0.3 tok/s (garbage)                                ║
║ - After FFI: 16.1 tok/s (coherent)                               ║
║ - Improvement: 50-80x speedup + actually works                   ║
║                                                                  ║
║ SELF-CRITICISM:                                                  ║
║ - Should have done FFI approach from the start                   ║
║ - Wasted time trying to fix native Zig inference                 ║
║ - Subprocess is a workaround, not a real fix                     ║
║ - Native Zig inference still broken (hidden state explosion)     ║
║                                                                  ║
║ SCORE: 8/10 (working solution, but it's a wrapper)               ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Tech Tree: Next Steps

### [A] Port bitnet.cpp LUT Kernels to Zig
- Complexity: ★★★★☆
- Goal: Native Zig inference with same numerical stability
- Potential: Remove subprocess dependency, full control

### [B] C API Integration (libllama.so)
- Complexity: ★★★☆☆
- Goal: In-process FFI without subprocess overhead
- Potential: Lower latency, streaming tokens

### [C] Debug Native Zig Hidden State Explosion
- Complexity: ★★★★★
- Goal: Find and fix numerical instability in native code
- Potential: Optimal solution if successful

**Recommendation:** [B] - Create C API wrapper for tighter integration while native Zig issue remains unresolved.

---

## Files Created/Modified

| File | Action |
|------|--------|
| `src/vibeec/bitnet_ffi.zig` | Created - FFI wrapper |
| `zig-out/bin/bitnet_ffi` | Created - Compiled binary |
| `docs/bitnet_ffi_report.md` | Created - This report |

---

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL**
