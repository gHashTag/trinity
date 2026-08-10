# Trinity Ecosystem Architecture Map (Multi-Repo)

**Last updated**: 2026-04-19

**Brand Kit:** See [BRAND-KIT.md](./BRAND-KIT.md) for TRIOS naming, design tokens, and visual identity.

---

## 1. TRIOS — Rust MCP workspace (`gHashTag/trios`)

| # | Module             | Symbol | Type           | stub | FFI | test | Status                                        | SSOT spec (t27)                      | Priority |
|---|--------------------|--------|--------------|------|-----|------|-----------------------------------------------|--------------------------------------|-----------|
| 1 | trios-core         | `△`    | lib          | ✅   | N/A | ✅   | GREEN                                         | `specs/trios/core.t27`              | P1 ✅     |
| 2 | trios-vsa          | `△`    | lib          | ✅   | 📋   | ✅   | 🟡 MIGRATED — Zig files in src/           | `specs/vsa/core.t27`                | P1 ✅     |
| 3 | trios-hybrid       | `∓`    | lib          | ✅   | 📋   | ✅   | 🟡 MIGRATED — Zig files in src/           | `specs/vsa/hybrid.t27`              | P1 ✅     |
| 4 | trios-vm           | `⚙`    | lib          | ✅   | 📋   | ✅   | 🟡 MIGRATED — Zig files in src/           | `specs/vm/arch.t27`                 | P1 ✅     |
| 5 | trios-sdk          | `∞`    | lib          | ✅   | 📋   | ✅   | 🟡 MIGRATED — Zig files in src/           | `specs/sdk/api.t27`                 | P1 ✅     |
| 6 | trios-git          | `⑂`    | lib          | ✅   | N/A | ✅   | GREEN                                         | `specs/trios/git.t27`               | P1 ✅     |
| 7 | trios-gb           | `📦`    | lib          | ✅   | N/A | ✅   | GREEN                                         | `specs/trios/gitbutler.t27`         | P1 ✅     |
| 8 | trios-server       | `⬡`    | bin (MCP/REST) | ✅ | N/A | N/A  | GREEN                                         | `specs/trios/server.t27`            | P1 ✅     |
| 9 | trios-kg           | `◉`    | lib (KG)     | ✅   | N/A | ✅   | GREEN                                         | `specs/trios/kg.t27`                | P1 ✅     |
|10 | trios-agents       | `⚡`    | lib          | ✅   | N/A | ✅   | GREEN                                         | `specs/trios/agents.t27`            | P1 ✅     |
|11 | trios-training     | `⊕`    | lib          | ✅   | N/A | ✅   | GREEN                                         | `specs/trios/training.t27`          | P1 ✅     |
|12 | trios-crypto       | `🔒`    | FFI wrapper  | ✅   | ✅  | ❌   | 🟡 UPDATED — Zig files in src/          | `specs/crypto/mining.t27`           | P1 блокер |
|13 | trios-golden-float | `φ`     | FFI wrapper  | ✅   | ❌  | ❌   | FAIL — missing `_gf16_compress_weights*`      | `specs/golden-float/gf16.t27`       | P1 FFI debt |
|14 | trios-hdc          | `⬛`    | FFI wrapper  | ✅   | ❌  | ❌   | FAIL — vendor submodule missing               | `specs/hdc/core.t27`                | P1 FFI debt |
|15 | trios-physics      | `Ψ`    | FFI wrapper  | ✅   | ❌  | ❌   | FAIL — vendor submodule missing               | `specs/physics/constants.t27`       | P1 FFI debt |
|16 | trios-sacred       | `✦`    | FFI wrapper  | ✅   | 📋   | ✅   | 🟡 UPDATED — Zig files in src/          | `specs/sacred-geometry/phi.t27`     | P1 ✅     |
|17 | trios-ternary     | `∓`    | lib          | ✅   | 📋   | ✅   | 🟡 UPDATED — Zig files in src/          | `specs/ternary/core.t27`            | P1 ✅     |
|18 | trios-clara (planned) | —     | lib       | 📋   | —   | —    | PLANNED — MCP bridge for CLARA / ParameterGolf | `specs/clara/parameter-golf.t27`    | P2        |
|19 | trios-zig-agents   | `⚙△`   | FFI wrapper  | ✅   | ✅  | ✅   | GREEN (separate vendor, not submodule)       | `specs/agents/zig.t27`              | P1 ✅     |
|20 | trios-hdc-bridge (planned) | —     | lib  | 📋   | —   | —    | PLANNED — HDC→CLARA bridge                    | `specs/clara/hdc-bridge.t27`        | P3 D2–3   |
|21 | trios-phi-quant (planned) | —     | lib   | 📋   | —   | —    | PLANNED — φ‑quantization                      | `specs/clara/phi-quant.t27`         | P3 D4–5   |
|22 | trios-fibonacci-attn (planned) | `φ²`   | lib | 📋   | — | —    | PLANNED — Fibonacci attention                  | `specs/clara/fib-attention.t27`     | P3 D6–7   |
|23 | trios-ensemble (planned) | —     | lib    | 📋   | —   | —    | PLANNED — ensemble orchestrator                | `specs/clara/ensemble.t27`          | P3 D8–9   |
|24 | trios-agi-bench (planned) | —     | lib   | 📋   | —   | —    | PLANNED — 5 AGI tracks wrapper                 | `specs/agi/tracks.t27`              | P3 parallel |
|25 | trinity-brain             | `🧠`   | FFI wrapper | ✅  | 📋   | ❌   | 🟡 UPDATED — Zig files in src/          | `specs/brain/architecture.t27`      | P1 ✅     |
|26 | trios-route (planned)  | `⇌`    | lib          | 📋   | —   | —    | PLANNED — GF16↔Ternary policy engine           | `specs/trios/route.t27`             | P1 Φ1     |
|27 | trios-attn (planned)   | `φ²`    | lib          | 📋   | —   | —    | PLANNED — φ-Sparse Attention                    | `specs/trios/phi-attn.t27`         | P2 Φ5     |
|28 | trios-hw (planned)     | `⬛`    | lib          | 📋   | —   | —    | PLANNED — DSP/FPGA scheduler                  | `specs/trios/hardware.t27`         | P1 Φ4     |
|29 | trios-ffi (planned)    | `↯`    | FFI wrapper  | 📋   | —   | —    | PLANNED — FFI bridge for training              | `specs/trios/ffi.t27`              | P2        |
|30 | trios-llm (planned)    | `∞`    | lib          | ✅   | 📋   | ✅   | 🟡 INITIAL — LLM inference path           | `specs/trios/llm.t27`              | P2        |

**TRIOS Summary**: 30 modules (26 existing + 4 planned), 8 green, 5 FFI modules require sync with Zig‑vendors, 5 newly migrated with Zig source files.

---

## 2. ZIG vendor ecosystem (external repos, pulled into TRIOS)

| # | Repository          | Zig version | build | SSOT link in README | submodule in trinity | Current status               |
|---|---------------------|------------|-------|---------------------|---------------------|------------------------------|
| 1 | zig-golden-float    | 0.16.0 ✅   | ✅    | 📋 Step 2            | ⚠️ symbols mismatch  | PARTIAL (FFI mismatch)       |
| 2 | zig-hdc             | 0.16.0 🟡   | —     | 📋 Step 2            | ✅ vendor/hdc        | 🟡 submodule exists, build pending |
| 3 | zig-physics         | 0.16.0 ✅   | ✅    | 📋 Step 2            | ✅ vendor/physics    | ✅ submodule exists          |
| 4 | zig-sacred-geometry | ⚠️         | —     | 📋 deferred          | ❌ 404                | BLOCKED (repo to restore)     |
| 5 | zig-crypto-mining   | 0.16.0 ✅   | ✅    | 📋 Step 2            | ✅ vendor/zig-crypto-mining | ⚠️ symbols mismatch  |
| 6 | zig-agents          | 0.16.0 ✅   | ✅    | 📋 Step 2            | no (used separately) | GREEN                        |
| 7 | trinity-brain       | —          | —     | —                    | 🟡 vendor/trinity-brain | 🟡 INITIAL (Rust crate ready) |
| 8 | zig-kg (verify/plan) | —        | —     | 📋 Step 2            | —                    | TBD                          |
| 9 | zig-training (planned) | —       | —     | —                    | —                    | PLANNED                      |
|10 | zig-ensemble (planned) | —       | —     | —                    | —                    | PLANNED                      |
|11 | zig-agi-eval (planned) | —       | —     | —                    | —                    | PLANNED                      |

---

## 3. T27 — SSOT of language and specifications (`gHashTag/t27`)

| # | Component                       | Type           | Status                | Priority |
|---|---------------------------------|---------------|-----------------------|----------|
| 1 | t27 language (.t27/.tri)        | Rust compiler | 🟡 in development     | core     |
| 2 | `specs/ARCHITECTURE-MULTIREPO.md` | docs SSOT     | ✅ created            | done     |
| 3 | `specs/golden-float/*.t27`      | spec          | 🟡 partial             | P1       |
| 4 | `specs/hdc/*.t27`               | spec          | 🟡 partial             | P2       |
| 5 | `specs/physics/*.t27`           | spec          | 🟡 partial             | P2       |
| 6 | `specs/sacred-geometry/*.t27`   | spec          | 🟡 partial             | P3       |
| 7 | `specs/crypto/*.t27`            | spec          | 🟡 partial             | P1       |
| 8 | `specs/agents/*.t27`            | spec          | 🟡 partial             | P2       |
| 9 | `specs/brain/*.t27`             | spec          | 📋 planned            | P1 NEW   |
|10 | `specs/trios/*.t27`             | spec          | 📋 planned            | P2       |
|11 | `specs/clara/*.t27`             | spec          | 📋 planned            | P3       |
|12 | `specs/agi/*.t27`               | spec          | 📋 planned            | P3       |
|13 | TS codegen (PR #529)            | tooling       | 🟡 PR pending          | CI queue |
|14 | bootstrap (PR #524)             | tooling       | 🟡 PR pending          | CI queue |
|15 | GF16 backend (PR #521)          | tooling       | 🟡 PR pending          | CI queue |
|16 | All backends (PR #532)          | tooling       | 🟡 PR pending          | CI queue |
|17 | TECH_DEBT.md                    | docs          | 📋 create              | NOW      |
|18 | Coq formal verification        | research      | 📋 planned            | long‑term|

---

## 4. `trinity-claraParameter` — Parameter Golf

| # | Module                                | Type        | Status   | Priority |
|---|---------------------------------------|------------|----------|----------|
| 1 | Mini‑baseline (3L/4H/256d, 11.08MB)    | model      | ✅       | P2 D1    |
| 2 | wikitext‑2 data loader                 | Rust       | ✅       | P2 D1    |
| 3 | Tokenizer (50257)                      | Rust       | ✅       | P2 D1    |
| 4 | BPB tracking loop                      | Rust       | ✅       | P2 D1    |
| 5 | Hyperparameter search (27 configs)     | Rust       | ✅       | P2 D1    |
| 6 | Training pipeline + checkpointing      | Rust       | ✅       | P2 D1    |
| 7 | Chunked HTTP downloader                | Rust       | ✅       | P2 D1    |
| 8 | Runpod grant application               | docs       | 🟡 DRAFT  | P2       |
| 9 | README Trinity Cognitive Stack         | docs       | 📋       | P2 D2    |
|10 | HDC→ParameterGolf bridge               | Rust+Zig   | 📋       | P3 D2–3  |
|11 | φ‑quantization module (GF16)           | Rust+Zig   | 📋       | P3 D2–3  |
|12 | Compression ratio benchmark            | Rust       | 📋       | P3 D3    |
|13 | Semantic indexing (HDC)                | Rust       | 📋       | P3 D3    |
|14 | BitNet b1.58 ternary quant             | Rust       | 📋       | P3 D4–5  |
|15 | Fibonacci attention heads              | Rust       | 📋       | P3 D6–7  |
|16 | Sacred bottleneck (hidden_dim=377)     | Rust+Zig   | 📋       | P3 D6–7  |
|17 | Ensemble orchestration                 | Rust       | 📋       | P3 D8–9  |
|18 | Final submission pipeline              | Rust       | 📋       | P3 D8    |
|19 | Competitors analysis (LoRA/QLoRA/…)    | docs       | 🟡 partial | P2      |
|20 | 5‑track AGI validation layer           | Rust       | 📋       | P3 parallel |

---

## 5. `trinity-brain` — Neuroanatomical Brain Architecture (NEW)

| # | Module                          | Type        | Status   | Priority |
|---|---------------------------------|------------|----------|----------|
| 1 | Rust FFI crate (lib.rs)        | FFI        | ✅       | P1 ✅    |
| 2 | cbindgen config                | build      | ✅       | P1 ✅    |
| 3 | BrainRegion enum               | type       | ✅       | P1 ✅    |
| 4 | Thalamus (sensory relay)       | module     | 🟡 Zig   | P1       |
| 5 | Hippocampus (episodic memory)  | module     | 🟡 Zig   | P1       |
| 6 | Insula (interoception)         | module     | 🟡 Zig   | P1       |
| 7 | ACC (conflict detection)       | module     | 🟡 Zig   | P1       |
| 8 | SafetyVerdict enum             | type       | ✅       | P1 ✅    |
| 9 | FFI functions (7)              | API        | ✅       | P1 ✅    |
|10 | Zig integration                | bridge     | 📋       | P2       |
|11 | Tests                          | test       | ✅       | P1 ✅    |
|12 | C header generation            | build      | 📋       | P2       |

---

## 6. IGLA-GF16 — Intelligent Golden-ratio Language Architecture

### GF16 Format (sign:exp:mantissa = 1:6:9)

| Parameter      | Value              | Proof                                    |
|----------------|--------------------|------------------------------------------|
| man/exp ratio  | 9/6 = 1.500        | ≈ φ = 1.618, Δ = α_φ = 0.118034          |
| precision      | 2⁹ = 512 levels    | —                                        |
| range          | ±2.15×10⁹           | —                                        |
| BENCH-004b     | 97.67% = f32, Δ=0.00% | ✅ [cite:14]                            |
| bf16/ternary   | 9.80% (−87.87% ❌)   | —                                        |

### Trinity Constants

| Constant      | Value                | Proof                              |
|---------------|----------------------|-------------------------------------|
| φ             | 1.618033988749895    | golden ratio                       |
| φ⁻¹           | 0.618033988749895    | —                                   |
| φ⁻²           | 0.381966011250105    | —                                   |
| φ²            | 2.618033988749895    | —                                   |
| **α_φ = φ³/2** | **0.118033988749895** | = α_s(mZ) PDG2024 ✅                |
| φ²+φ⁻²        | 3.000000000000000    | Trinity Identity exact              |

### Fibonacci Architecture (all dimensions are Fibonacci numbers)

| Parameter | Value             | Rationale                               |
|-----------|-------------------|-----------------------------------------|
| d_model   | 144 [Fib #12]     | —                                       |
| n_heads   | 8 [Fib #6]        | —                                       |
| d_head    | 18 [144/8]        | —                                       |
| d_ffn     | 233 [Fib #13]     | ≈ 144×φ = 232.99 (Δ<0.1%)                |
| n_layers  | 7 (was 9)         | log_φ(budget)                           |

### Trinity Weight Init — 4 Physics Sectors

| Sector            | std        | Formula        |
|-------------------|------------|----------------|
| gauge (attn QKV)  | 0.11803399 | α_φ            |
| higgs (attn proj) | 0.07294902 | α_φ × φ⁻¹      |
| lepton (ffn gate) | 0.04508497 | α_φ × φ⁻²      |
| cosmology (embed) | 0.02786405 | α_φ × φ⁻³      |

### φ-LR Schedule

```
LR(t) = α_φ · φ^(−t/τ)
τ = T/(φ·27) = 228.9 steps

t=0   : 0.118034  ████████████████████
t=100 : 0.095655  ████████████████
t=500 : 0.041258  ██████
t=1000: 0.014421  ██
```

### CA φ-Mask (Fibonacci distances)

| Parameter  | Value                                    |
|------------|------------------------------------------|
| Visible    | {1,2,3,5,8,13,21,34,55,89,144}           |
| Sparsity   | 2.15% (11/512 per token)                  |
| Reduction  | 262144 → 5632 pairs (46.6× sparse)        |

### JEPA-T Split (7 layers)

| Component  | Layers | Params | Size   |
|------------|--------|--------|--------|
| Encoder    | 6      | 8.14M  | 15.5 MB |
| Predictor  | 1      | 0.45M  | 0.9 MB  |
| **TOTAL**  | **7**  | **8.59M** | **16.4 MB** |

### Model Size (GF16)

| Component        | Params    | Size (GF16) |
|------------------|-----------|-------------|
| embedding (tied) | 7,237,008 | 13.80 MB    |
| attention ×7     | 580,864   | 1.10 MB     |
| ffn ×7           | 486,208   | 0.93 MB     |
| **TOTAL**        | **8,304,080** | **15.83 MB** |

### Proofs for whitepaper

1. ✅ GF16 1:6:9 ratio = man/exp = 1.5 ≈ φ, Δ = α_φ
2. ✅ Trinity init std = α_φ = α_s(mZ) PDG2024 (Δ=0.03σ)
3. ✅ LR_init = α_φ (same constant)
4. ✅ BENCH-004b = 97.67% = f32 Δ=0.00%
5. ✅ Fib d_model/d_ffn = 144/233 → 144×φ=232.99 ≈ 233 (Δ<0.1%)

### IGLA-GF16 Module Status

| # | Module          | Type  | Status | Priority |
|---|-----------------|-------|--------|----------|
| 1 | GF16 format     | spec  | ✅     | P1 ✅    |
| 2 | φ-constants    | math  | ✅     | P1 ✅    |
| 3 | Fibonacci arch | config| ✅     | P1 ✅    |
| 4 | Trinity init   | code  | 🟡     | P1       |
| 5 | φ-LR schedule  | code  | 🟡     | P1       |
| 6 | CA φ-mask      | code  | 📋     | P2       |
| 7 | JEPA-T split   | code  | 📋     | P2       |
| 8 | Whitepaper     | docs  | 📋     | P1       |

---

## 7. `trinity-training`

| # | Component                | Status           | Priority |
|---|--------------------------|------------------|----------|
| 1 | Migration from monolith  | 🟡 in progress   | ongoing  |
| 2 | AGENTS_MATRIX.md         | 📋 planned       | NOW      |
| 3 | Dataset indexing         | 📋 planned       | P3       |
| 4 | Training recipes         | 🟡 partial        | P3       |

---

## 8. `agi-hackathon`

| # | Track              | Status | Priority |
|---|--------------------|--------|----------|
| 1 | Learning           | ✅     | done     |
| 2 | Metacognition      | ✅     | done     |
| 3 | Attention          | ✅     | done     |
| 4 | Executive Functions | ✅     | done     |
| 5 | Social Cognition   | ✅     | done     |

---

## Repository Relationships

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Trinity Ecosystem                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐       ┌──────────────┐       ┌─────────────────┐      │
│  │   TRIOS     │───────│  Zig Vendors │───────│      T27        │      │
│  │ (26 modules)│  FFI   │  (11 repos)  │  specs│  (SSOT language)│      │
│  │  Brand Kit: │       │              │       │                 │      │
│  │  φ △ ∓ ⇌   │       │              │       │                 │      │
│  └──────┬──────┘       └──────┬───────┘       └─────────────────┘      │
│         │                     │                                          │
│         │ MCP                 │                                          │
│         ▼                     │                                          │
│  ┌─────────────┐              │                                          │
│  │ ClaraParam  │◄─────────────┘                                          │
│  │ (20 modules)│                                                        │
│  └──────┬──────┘                                                        │
│         │                                                               │
│         │ validation                                                     │
│         ▼                                                               │
│  ┌─────────────┐                                                        │
│  │ AGI Tracks  │                                                        │
│  │ (5 tracks)  │                                                        │
│  └─────────────┘                                                        │
│                                                                         │
│  ┌─────────────┐       ┌──────────────┐                                 │
│  │   Trinity   │───────│   Trinity    │                                 │
│  │   Brain     │  FFI  │  (Zig impl)  │                                 │
│  │  (Rust)     │       │  (Thalamus,  │                                 │
│  │     🧠      │       │   Hippocampus,│                                 │
│  │             │       │   Insula,   │                                 │
│  │             │       │   ACC)      │                                 │
│  └─────────────┘       └──────────────┘                                 │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │  TRIOS Brand Kit: Ternary Precision Trinity                         ││
│  │  △ core · ⇌ route · φ gf16 · ∓ tri · ⬛ hw · φ² attn · ⊕ jepa      ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Ecosystem Status

| Repository | GREEN | BLOCKER | PLANNED | NEW | MIGRATED | Total |
|------------|-------|---------|---------|-----|-----------|-------|
| TRIOS      | 8     | 5       | 8       | 0   | 5          | 26    |
| Zig vendors| 1     | 4       | 4       | 1   | 0          | 11    |
| T27        | 2     | 4       | 4       | 1   | 0          | 18    |
| ClaraParam | 7     | 0       | 13      | 0   | 0          | 20    |
| IGLA-GF16  | 4     | 0       | 4       | 0   | 0          | 8     |
| Brain      | 9     | 0       | 3       | —   | 1          | 12    |
| Training   | 0     | 0       | 4       | 0   | 0          | 4     |
| AGI Hack   | 5     | 0       | 0       | 0   | 0          | 5     |
| **Total**  | **36** | **13**   | **40**   | **2** | **6**      | **104** |
