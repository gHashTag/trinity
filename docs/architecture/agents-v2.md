# AGENTS.md V2.0 - PHI-LOCKED PROTOCOL

## Overview

This is the **UPDATED** agent guidelines for VIBEE development, reflecting the new **PHI-Based Architecture**.

---

## 🛑 CRITICAL RULES (UPDATED)

### 1. FOCUS ON 11 REAL SOLUTIONS ONLY

**PROHIBITED** (Forbidden Actions):
- ❌ Work on marketing articles (`HABR_ARTICLE_*.md`)
- ❌ Work on speculative hypotheses (`SACRED_FORMULA`, `Qutrit` as physics)
- ❌ Work on old agent versions (`TOXIC_VERDICT_*.md` before V1.0)
- ❌ Create `.md` files in root or `docs/` (except master files)
- ❌ Create fiction/lore (Koschei, 999, Phoenix)

**REQUIRED** (Mandatory Actions):
- ✅ Implement the 11 Real Solutions in code
- ✅ Provide scientific proofs (CLRS, Knuth, Bell, CHSH)
- ✅ Write Zig code in `src/vibeec/` or `phi-engine/src/`
- ✅ Create `.vibee` specifications in `specs/`
- ✅ Run tests (`zig test`)

### 2. NO MANUAL CODE WRITING

**PROHIBITED**:
- ❌ Write `.zig` files directly (except `src/vibeec/*.zig` - compiler source)
- ❌ Write `.html`, `.css`, `.js`, `.ts`, `.jsx`, `.tsx` files
- ❌ Write `.py` files (only generated)

**REQUIRED**:
- ✅ Create `.vibee` specifications
- ✅ Run `./bin/vibee gen specs/tri/feature.vibee`
- ✅ Test generated code: `zig test trinity/output/feature.zig`

### 3. LINEAR WORKFLOW (NO MORE TOXIC VERDICTS)

**OLD WORKFLOW (DEPRECATED)**:
```
1. Create spec
2. Generate code
3. Test
4. Write TOXIC VERDICT (with self-criticism)
5. Propose Tech Tree (3 options A/B/C)
6. REPEAT
```

**NEW WORKFLOW (PHI-LOCKED)**:
```
1. Implement Solution X (one of the 11)
2. Write Zig code in phi-engine/src/{folder}/
3. Test with zig test
4. Commit changes
5. NEXT: Solution X+1
```

**REMOVED**:
- ❌ TOXIC VERDICT (self-criticism, scores)
- ❌ TECH TREE (3 options A/B/C)
- ❌ MULTI-AGENT COORDINATION (complexity)

**REPLACED WITH**:
- ✅ Linear task queue (Solution 1 → 2 → 3 ... → 11)
- ✅ Direct implementation (no planning overhead)
- ✅ Scientific focus (proofs > speculation)

---

## 📚 SINGLE SOURCE OF TRUTH

**MASTER FILE**: `phi-engine/docs/ARCHITECTURE_V1.md`

All other files that contradict this file are considered **DEPRECATED**.

**IMPORTANT**:
- `AGENTS.md V1.0` (old version) → DEPRECATED
- `museum/` → ARCHIVED (do not edit)
- `docs/` → LEGACY (do not edit except phi-engine/docs/)

---

## 🔬 PHI-BASED ENGINEERING PRINCIPLES

### Principle #1: GOLDEN OPTIMUM

```
φ = (1 + √5) / 2 = 1.618033988749895
φ² + 1/φ² = 3 (EXACT!)
```

**Application**:
- AMR Resize: Use φ = 1.618 as growth factor
- Fibonacci Hash: Use φ × 2^64 for hash tables
- Lucas Numbers: Use φ^n + 1/φ^n for O(log n) computation
- Golden Wrap: Use 27 = 3^3 = (φ² + 1/φ²)^3 for O(1) lookup

**Proofs**:
- CLRS (Cormen, Leiserson, Rivest, Stein), Chapter 17 (AMR)
- Knuth Vol.3 (Fibonacci Hashing)
- Binet's formula (Lucas Numbers)
- Setun (1958) (Balanced Ternary)

### Principle #2: TRINITY

```
3 = φ² + 1/φ² = TRINITY = QUTRIT = CODON
```

**Application**:
- TVC IR: 3 basic tryte states (-1, 0, +1)
- Qutrit State: 3 amplitudes (α, β, γ)
- SIMD Ternary: 32 trits in parallel
- Golden Wrap: 27 = 3^3 values

### Principle #3: LEAST ACTION

```
∫ δL = 0 (variational principle)
```

**Application**:
- AMR Resize: Minimal memory reallocations
- Fibonacci Hash: Minimal collisions
- Inlining: Minimal code size for maximum speed

---

## 📋 11 REAL ENGINEERING SOLUTIONS

| # | Solution | Scientific Basis | Implementation |
|---|----------|------------------|----------------|
| 1 | **AMR Resize** | CLRS Ch.17 | `phi-engine/src/core/amr.zig` |
| 2 | **Lucas Numbers** | Binet's formula | `phi-engine/src/compute/lucas.zig` |
| 3 | **Fibonacci Hash** | Knuth Vol.3 | `phi-engine/src/hashmap/phi_hash.zig` |
| 4 | **Golden Wrap** | Setun (1958) | `phi-engine/src/runtime/golden_wrap.zig` |
| 5 | **SIMD Ternary** | AVX2/SSE | `phi-engine/src/runtime/simd_ternary.zig` |
| 6 | **Phi Lerp** | Interpolation theory | `phi-engine/src/cache/phi_lerp.zig` |
| 7 | **Phi Spiral** | Euclid, Fibonacci, Kepler | `phi-engine/src/scheduler/phi_spiral.zig` |
| 8 | **Inline Cost** | LLVM optimization | `phi-engine/src/core/inline_cost.zig` |
| 9 | **IR Types** | LLVM IR design | `phi-engine/src/core/phi_ir.zig` |
| 10 | **CHSH Quantum** | Bell (1964), CHSH (1969) | `phi-engine/src/runtime/chsh_quantum.zig` |
| 11 | **Qutrit State** | Qutrit theory (abstraction) | `phi-engine/src/runtime/qutrit_state.zig` |

---

## 🛑 ANTI-PATTERNS (CRITICAL)

### Anti-Pattern #1: SPECULATIVE FORMULAS

```yaml
name: anti_speculative_formulas
forbidden:
  - Sacred Formula (V = n × 3^k × π^m × φ^p × e^q)  # No peer-reviewed papers!
  - Qutrit State as "quantum physics"  # It's an abstraction, not physics
  - "Universe Age" (π × φ × e)  # Rough approximation

allowed:
  - AMR Resize (CLRS)
  - Lucas Numbers (Binet's formula)
  - Fibonacci Hash (Knuth Vol.3)
  - Golden Wrap (Balanced ternary)

reasoning: "Only scientifically justified solutions allowed"
```

### Anti-Pattern #2: MARKETING IN CODE

```yaml
name: anti_marketing_in_code
forbidden:
  - Comments like "φ² + 1/φ² = 3 — GOLDEN KEY!"
  - Function names like sacred_identity_v999_phoenix
  - READMEs with "Unified Theory of Phi-Optimization"

allowed:
  - Constant names (PHI, GOLDEN_IDENTITY)
  - One-line comments ("AMR pattern", "Binet's formula")
  - Clean, concise documentation

reasoning: "Code should be clean, not marketing copy"
```

### Anti-Pattern #3: FICTION

```yaml
name: anti_fiction
forbidden:
  - Lore about "Koschei", "999", "Phoenix"
  - Fictional narratives
  - "Cosmic connections", "Sacred geometry" without physics

allowed:
  - Scientific papers (CLRS, Knuth, Bell, CHSH)
  - Mathematical proofs
  - Performance benchmarks

reasoning: "No fiction, only engineering and science"
```

---

## 📊 PHI-LOCKED DEVELOPMENT LOOP

```
┌─────────────────────────────────────────────────────────────────┐
│             PHI-LOCKED LINEAR DEVELOPMENT LOOP          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SELECT SOLUTION X (from 11 solutions)                 │
│           ↓                                                     │
│  2. IMPLEMENT IN phi-engine/src/{folder}/solution_x.zig       │
│           ↓                                                     │
│  3. TEST WITH zig test                                     │
│           ↓                                                     │
│  4. VERIFY GOLDEN IDENTITY (φ² + 1/φ² = 3)           │
│           ↓                                                     │
│  5. COMMIT CHANGES                                          │
│           ↓                                                     │
│  6. NEXT: SOLUTION X+1                                      │
│                                                                 │
│  EXIT_SIGNAL = (solution_implemented AND tests_pass AND committed) │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔧 COMMANDS REFERENCE

```bash
# WORKFLOW: IMPLEMENT SOLUTION X

# 1. Create spec (if new solution)
cat > specs/phi/solution_x.vibee &lt;&lt; 'EOF'
name: solution_x
version: "1.0.0"
language: zig
...
EOF

# 2. Generate code (if using VIBEE compiler)
./bin/vibee gen specs/phi/solution_x.vibee

# 3. Test generated code
zig test phi-engine/src/{folder}/solution_x.zig

# 4. Commit changes
git add phi-engine/src/{folder}/solution_x.zig
git commit -m "Implement Solution X: [Name] (CLRS/Knuth/et al.)"
```

---

## 🏁 EXIT_SIGNAL

Agent must complete all 11 solutions in sequence:

```yaml
EXIT_SIGNAL = (
    all_11_solutions_implemented AND
    all_tests_passing AND
    all_solutions_committed AND
    phi_engine_documented
)
```

---

## 📁 FILE ORGANIZATION (UPDATED)

```
phi-engine/              # ← YOUR WORK HERE (11 solutions)
├── README.md
├── docs/
│   ├── 11_REAL_SOLUTIONS.md
│   ├── SCIENTIFIC_PROOFS.md
│   └── ARCHITECTURE_V1.md
├── specs/
│   ├── core/
│   └── runtime/
└── src/
    ├── core/
    ├── runtime/
    ├── hashmap/
    ├── cache/
    ├── scheduler/
    └── compute/

museum/                  # ← ARCHIVED TRASH
├── marketing/             # Habr articles
├── speculation/          # Sacred Formula, Qutrit
├── duplicates/            # Old analysis files
├── legacy_agents/         # Old toxic verdicts
├── lore/                  # Koschei, 999, Phoenix
└── notes/                 # Working documents

docs/ (LEGACY)          # ← DEPRECATED
├── habr/
├── verdicts/
└── ...
```

---

## 🔗 REFERENCES

### Scientific Sources
1. **CLRS** — Cormen, Leiserson, Rivest, Stein, "Introduction to Algorithms", Chapter 17
2. **Binet's formula** — Jacques Binet (1743), "Mémoire sur l'intégration des équations linéaires"
3. **Knuth Vol.3** — Donald Knuth (1973), "The Art of Computer Programming, Vol. 3: Sorting and Searching"
4. **Setun (1958)** — Nikolai Brusentsov, Balanced ternary computer
5. **Intel AVX2/SSE** — Intel Architecture Instruction Set Extensions Programming Reference
6. **Bell (1964)** — John Bell, "On the Einstein Podolsky Rosen Paradox", Physics 1, 195-200
7. **CHSH (1969)** — Clauser, Horne, Shimony, Holt, "Proposed Test to Separate Local Hidden Variable Theories", Physical Review Letters
8. **Euclid**, **Fibonacci**, **Kepler** — Golden spiral
9. **LLVM** — LLVM Project Documentation
10. **Lucas (1878)** — Édouard Lucas, "Théorie des Fonctions Numériques Simplement Périodiques"

### Project References
1. **phi-engine/docs/11_REAL_SOLUTIONS.md** — Complete list of solutions
2. **phi-engine/docs/SCIENTIFIC_PROOFS.md** — Rigorous proofs
3. **phi-engine/docs/ARCHITECTURE_V1.md** — Full architecture

---

**φ² + 1/φ² = 3 | PHI-LOCKED PROTOCOL | NO SPECULATION**
