# TRIOS Brand Kit — Ternary Precision Trinity

**Concept:** *Three states × Golden Ratio × Formal Precision*

All naming is built on three pillars: **φ (golden ratio)**, **{-1, 0, +1} (ternary)**, **Ω (completion/verification)**.

---

## Crate Naming — Design System

Real crates from [gHashTag/trios](https://github.com/gHashTag/trios/tree/main/crates) + planned from Master Plan:

| Crate (current / plan) | Brand Name | Symbol | Role |
|---|---|---|---|
| `trios-core` | **trios-core** | `△` | Base types, SSOT schema (Φ0) |
| `precision-router` → | **trios-route** | `⇌` | Policy engine GF16↔Ternary (Φ1) |
| `trios-golden-float` | **trios-gf** | `φ` | GoldenFloat16 kernel (Φ2) |
| *(plan)* `trios-ternary` | **trios-tri** | `∓` | Ternary BitLinear + QAT (Φ3) |
| `trios-hdc` → | **trios-hw** | `⬛` | Hardware/DSP scheduler (Φ4) |
| *(plan)* `trios-phi-attn` | **trios-attn** | `φ²` | φ-Sparse Attention (Φ5) |
| `trios-training` | **trios-jepa** | `⊕` | JEPA trainer loop (Φ6) |
| `trios-training-ffi` | **trios-ffi** | `↯` | FFI bridge for training |
| `trios-llm` | **trios-llm** | `∞` | LLM inference path |
| `trios-sacred` | **trios-sacred** | `✦` | Sacred geometry / φ constants |
| `trios-physics` | **trios-physics` | `Ψ` | Physics constants layer |
| `trios-crypto` | **trios-crypto** | `🔒` | Blake3 / Merkle integrity |
| `trios-kg` | **trios-kg** | `◉` | Knowledge graph (WIP) |
| `trios-server` | **trios-server** | `⬡` | API / MCP server |
| `trios-agents` | **trios-agents** | `⚡` | Agent orchestration |
| `trinity-brain` | **trinity-brain** | `🧠` | SSOT brain / `.trinity` processor |
| `zig-agents` | `zig-agents` | `⚙` | Zig-based agent kernels |
| `trios-zig-agents` | **trios-zig** | `⚙△` | Zig↔Rust agent bridge |
| `zig-knowledge-graph` | **zig-kg` | `◉⚙` | Zig KG engine |
| `trios-gb` | **trios-gb` | `📦` | Global build / workspace utils |
| `trios-git` | **trios-git** | `⑂` | Git worktree automation |

---

## Naming Tokens

Each name follows the pattern `trios-<domain>` where `<domain>`:

```
Tier 1 (Precision): gf · tri · route · attn · hw
Tier 2 (Training):  jepa · ffi · llm · training
Tier 3 (Research):  sacred · physics · kg · hdc
Tier 4 (Infra):     core · crypto · server · agents · git · gb
```

**Consistency rule:** The `trios-` prefix is mandatory for all new crates. Exceptions — legacy `zig-*` and `trinity-brain` (separate namespaces).

---

## Φ-Phases → Crate Mapping

```
Φ0 → trios-core         (△)   schema, types, SSOT
Φ1 → trios-route        (⇌)   precision policy engine
Φ2 → trios-gf           (φ)   GoldenFloat16 — core innovation
Φ3 → trios-tri          (∓)   Ternary + QAT
Φ4 → trios-hw           (⬛)  DSP/FPGA scheduler
Φ5 → trios-attn         (φ²)  φ-sparse attention
Φ6 → trios-jepa         (⊕)   JEPA training loop
Φ7 → proofs/            (Qed) Coq formal proofs
Φ8 → trinity-brain      (🧠)  publication artifact build
```

---

## Design System — Color Palette

**Concept:** *Golden Ratio Dark* — dark background with gold accent and ternary tricolor.

```
Background:     #0D0D0F   (void black — "zero state")
Surface:        #1A1A1E   (dark slate)
Border:         #2E2E36   (muted grid)

φ-Gold:         #D4A017   (GF16 — critical layers, HIGH sensitivity)
Ternary-Pos:    #4FC3A1   (teal — {+1} positive weight)
Ternary-Zero:   #6B6B7A   (slate — {0} zero weight)
Ternary-Neg:    #E05C5C   (red — {-1} negative weight)

Accent:         #8B5CF6   (violet — φ-attention, sacred geometry)
Verify-Green:   #22C55E   (tri verify = green)
Error-Red:      #EF4444   (tri verify = red / collapse detected)
Warning-Amber:  #F59E0B   (QAT gap > threshold)

Text-Primary:   #F4F4F5
Text-Secondary: #A1A1AA
Text-Muted:     #52525B
```

---

## Design System — Typography

```
Display:   "Space Grotesk"   800  — TRIOS, GF16, headers
Mono:      "JetBrains Mono"  400/700 — code, φ-formulas, CLI
Body:      "Inter"           400/500 — documentation, README
Math:      "Latin Modern Math" — LaTeX renders, whitepaper
```

**Size scale (φ-based):** each next size = previous × 1.618

```
4px → 6.5px → 10.5px → 17px → 27.5px → 44.5px → 72px
```

---

## Design System — Iconography / Symbols

| Context | Symbol | Meaning |
|---|---|---|
| CLI prompt | `tri ❯` | Ternary CLI identity |
| GF16 | `φ` or `Φ` | GoldenFloat precision |
| Ternary | `{∓}` | Three-state weights |
| Verified | `✓ Qed` | Formal proof complete |
| Phase marker | `Φn` | Experience phase |
| SSOT | `.trinity` | Single source of truth |
| Worktree | `⑂` | Isolated branch |
| Collapse | `⚠ collapse` | JEPA anti-collapse alert |

---

## Brand Voice (Tone)

- **Precision > Emotion** — every claim backed by metric (`97.67%`, `≤ 2%`, `0 Admitted`)
- **Formal verification as aesthetic** — `Qed` is not just CI status, it's the finale
- **Φ-notation everywhere** — phases, constants, attention — all through golden ratio
- **CLI as language** — `tri verify`, `tri route plan`, `tri pack` — commands sound like mantras

---

## README Badge Kit

```markdown
![tri verify](https://img.shields.io/badge/tri_verify-green-22C55E?style=flat-square&logo=rust)
![GF16 accuracy](https://img.shields.io/badge/GF16_MNIST-97.67%25-D4A017?style=flat-square)
![Coq proofs](https://img.shields.io/badge/Coq-0_Admitted-8B5CF6?style=flat-square)
![No .sh](https://img.shields.io/badge/.sh-banned-E05C5C?style=flat-square)
![Ternary](https://img.shields.io/badge/ternary-%7B--1%2C0%2C%2B1%7D-4FC3A1?style=flat-square)
```

---

All 17 real crates from [repository](https://github.com/gHashTag/trios/tree/main/crates) are covered. Missing from Master Plan (`trios-route`, `trios-tri`, `trios-attn`, `trios-hw`) follow the same `trios-<domain>` pattern — consistent with existing structure.
