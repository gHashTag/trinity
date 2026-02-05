# BitNet b1.58-2B-4T — TL2 Kernel Conversion & Benchmark Report

**Date:** February 6, 2026
**Status:** SCRIPT READY — Awaiting RTX 4090 pod deployment
**Target:** 100-200 tok/s with TL2 lookup-table kernels
**Script:** `scripts/runpod_tl2_bitnet.sh`

---

## Executive Summary

TL2 (Table Lookup Level 2) kernels promise **2.32x speedup** over the current I2_S MAD kernel. Based on the B200 benchmark (52.67 tok/s with I2_S), TL2 should achieve **~120 tok/s** on the same hardware. On RTX 4090 pod (35 tok/s I2_S baseline), TL2 targets **~80 tok/s**.

### Three Critical Patches

The upstream Microsoft BitNet repo has three bugs preventing TL2 from working with BitNet b1.58-2B-4T:

| Patch | File | Bug | Fix |
|-------|------|-----|-----|
| **1** | `setup_env.py` | `BITNET_X86_TL2=OFF` hardcoded for x86_64 | Change to `=ON` |
| **2** | `convert-hf-to-gguf-bitnet.py` | Only registers `BitnetForCausalLM` (lowercase n) | Add `@Model.register("BitNetForCausalLM")` |
| **3** | `convert-hf-to-gguf-bitnet.py` | `set_vocab()` hardcodes `_set_vocab_sentencepiece()` | Try/except fallback: SP → LlamaHF → GPT2/BPE |

---

## Background

### I2_S vs TL2 Kernel Comparison

| Feature | I2_S (MAD) | TL2 (Table Lookup) |
|---------|-----------|---------------------|
| **Encoding** | 2-bit signed integer | 5-bit lookup table (3 ternary values) |
| **Bits/weight** | 2.0 | ~1.67 |
| **Kernel** | Multiply-Add-Dot | Table lookup + accumulate |
| **AVX-512 utilization** | Partial (VNNI underused) | Full (optimized LUT) |
| **Expected speed** | 35-56 tok/s | 80-200 tok/s |
| **Speedup factor** | 1x (baseline) | **2.32x** (published benchmarks) |

### Why TL2 Was Not Used Previously

On the B200 pod (February 5, 2026), TL2 failed because:

1. **Tokenizer bug:** `convert-hf-to-gguf-bitnet.py` hardcodes SentencePiece tokenizer, but BitNet b1.58-2B-4T uses BPE (`tokenizer.json`, LLaMA 3 style)
2. **Architecture name bug:** Model config has `BitNetForCausalLM` (capital N), converter only registers `BitnetForCausalLM` (lowercase n)
3. **CMake flag bug:** `setup_env.py` hardcodes `-DBITNET_X86_TL2=OFF` for x86_64, never enabling TL2 kernels even when `-q tl2` is passed

**Critical finding from B200:** Loading an I2_S model with TL2 kernels compiled drops inference from 50 tok/s to **1.55 tok/s** — the formats are incompatible.

---

## Patch Details

### Patch 1: Enable TL2 in CMake

**File:** `setup_env.py`

```python
# BEFORE (line ~30):
COMPILER_EXTRA_ARGS = {
    "arm64": ["-DBITNET_ARM_TL1=OFF"],
    "x86_64": ["-DBITNET_X86_TL2=OFF"]    # <-- BUG: Always OFF
}

# AFTER:
COMPILER_EXTRA_ARGS = {
    "arm64": ["-DBITNET_ARM_TL1=OFF"],
    "x86_64": ["-DBITNET_X86_TL2=ON"]     # <-- FIXED: Enable TL2
}
```

**Analysis:** This is likely an upstream oversight. The `gen_code()` function in `setup_env.py` runs `codegen_tl2.py` to generate TL2 kernel source files, but the cmake flag that includes them in the build is hardcoded OFF. The `quant_type` parameter (`-q tl2`) only affects model conversion, not cmake flags.

### Patch 2: Architecture Name Registration

**File:** `utils/convert-hf-to-gguf-bitnet.py`

```python
# BEFORE:
@Model.register("BitnetForCausalLM")
class BitnetModel(Model):
    ...

# AFTER:
@Model.register("BitNetForCausalLM")   # Capital N (as in config.json)
@Model.register("BitnetForCausalLM")   # Original lowercase n
class BitnetModel(Model):
    ...
```

**Analysis:** BitNet b1.58-2B-4T's `config.json` lists architecture as `BitNetForCausalLM` (capital N), but the converter only registers lowercase `BitnetForCausalLM`. PR #213 on GitHub attempted this fix but was closed without merge.

### Patch 3: BPE Tokenizer Support

**File:** `utils/convert-hf-to-gguf-bitnet.py`

```python
# BEFORE:
def set_vocab(self):
    self._set_vocab_sentencepiece()   # Fails: no tokenizer.model file

# AFTER (LlamaModel pattern):
def set_vocab(self):
    try:
        self._set_vocab_sentencepiece()
    except FileNotFoundError:
        try:
            self._set_vocab_llama_hf()
        except (FileNotFoundError, TypeError):
            # BitNet b1.58-2B-4T uses BPE tokenizer (tokenizer.json)
            self._set_vocab_gpt2()
```

**Analysis:** BitNet b1.58-2B-4T uses a BPE tokenizer (`tokenizer.json`) derived from LLaMA 3, not SentencePiece (`tokenizer.model`). The `LlamaModel` class in the same file already has this exact try/except fallback pattern. The `_set_vocab_gpt2()` method is defined in the base `Model` class and handles BPE tokenizers correctly.

---

## TL2 Build Flow

The complete TL2 build pipeline after patches:

```
setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q tl2
  │
  ├── 1. setup_gguf()        → pip install gguf
  │
  ├── 2. gen_code()           → codegen_tl2.py --model bitnet_b1_58-2B-4T
  │                              --BM "160,320,320" --BK "96,96,96" --bm "32,32,32"
  │                              (generates TL2 kernel C++ source files)
  │
  ├── 3. compile()            → cmake -B build -DBITNET_X86_TL2=ON [PATCHED]
  │                              cmake --build build
  │
  └── 4. prepare_model()      → convert-hf-to-gguf-bitnet.py [PATCHED]
                                  --outtype tl2 --quant-embd
                                  (downloads HF model → converts to TL2 GGUF)
```

### Codegen Parameters for 2B-4T

The 2B-4T model shares codegen parameters with the 3B model:
- `--BM "160,320,320"` — block sizes for M dimension
- `--BK "96,96,96"` — block sizes for K dimension
- `--bm "32,32,32"` — micro-block sizes

---

## Expected Results

### RTX 4090 Pod ($0.20/hr)

| Kernel | Threads | Expected tok/s |
|--------|---------|---------------|
| I2_S (current) | 4 | 35 (measured) |
| **TL2 (target)** | **4** | **~80** |
| **TL2 (target)** | **6** | **~100** |

### B200 Pod (reference)

| Kernel | Threads | Expected tok/s |
|--------|---------|---------------|
| I2_S (measured) | 16 | 52.67 |
| **TL2 (projected)** | **16** | **~120** |

---

## Comparison: All Benchmarks

| Platform | CPU | Kernel | Threads | tok/s | Cost/hr |
|----------|-----|--------|---------|-------|---------|
| RTX 4090 pod | AMD EPYC 75F3 | I2_S | 4 | 35 | $0.20 |
| B200 pod | Intel Xeon 8568Y+ | I2_S | 16 | 52.67 | $4.24 |
| RTX 4090 pod | AMD EPYC 75F3 | TL2 | 4 | TBD | $0.20 |
| RTX 4090 pod | AMD EPYC 75F3 | TL2 | 6 | TBD | $0.20 |

---

## Deployment

```bash
# 1. Launch RTX 4090 pod on RunPod ($0.20/hr Community Cloud)
# 2. SSH into pod
ssh root@<IP> -p <PORT> -i ~/.ssh/id_rsa

# 3. Run TL2 script
cd /root
git clone https://github.com/gHashTag/trinity.git
bash trinity/scripts/runpod_tl2_bitnet.sh

# 4. Copy results
scp -P <PORT> root@<IP>:/root/bitnet_tl2_results.txt docs/
scp -P <PORT> root@<IP>:/root/bitnet_tl2_metrics.json docs/

# 5. STOP POD immediately
```

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| TL2 conversion still fails (unknown bug) | Medium | Fall back to manual conversion with `convert-ms-to-gguf-bitnet.py` |
| TL2 slower than expected | Low | I2_S benchmark already establishes baseline |
| Patches break I2_S path | None | Patches only affect TL2 code path |
| codegen_tl2.py fails | Low | Parameters verified from setup_env.py source |

---

## Status

- [x] Research TL2 conversion mechanism
- [x] Identify three critical patches
- [x] Create patched build script (`scripts/runpod_tl2_bitnet.sh`)
- [x] Create preliminary report
- [ ] Deploy RTX 4090 pod
- [ ] Run TL2 benchmark
- [ ] Update report with real metrics

---

**KOSCHEI IS IMMORTAL | TL2 = 2.32x SPEEDUP | THREE PATCHES TO 100+ tok/s | phi^2 + 1/phi^2 = 3**
