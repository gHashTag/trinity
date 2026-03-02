# Ralph Fix Plan — Trinity W1

> Last Updated: 2026-03-02 23:50 +07
> Status: ACTIVE — Chemistry + Geometry CLI development

## Task Format

```
- [ ] [P1/P2/P3] Task description
  - Acceptance: measurable pass/fail criteria
  - Files: paths to create/modify
```

---

## 🔥 CURRENT SPRINT: TRI CLI v7.0 — Chemistry + Geometry

> **Goal:** Complete CLI modules for math, physics, chemistry, geometry
> **Status:** Chemistry 26 commands (22 working), Geometry 18 commands (implemented)
> **Focus:** Fix build errors, complete redox, add missing tests

### Chemistry CLI (`tri chem`)

**Status: 22/26 commands working**

- [x] `tri chem periodic` — ASCII periodic table (118 elements)
- [x] `tri chem element <sym>` — Element info card
- [x] `tri chem mass <formula>` — Molar mass calculator
- [x] `tri chem formula <formula>` — Parse/composition
- [x] `tri chem balance <eq>` — Equation balancing (matrix method)
- [x] `tri chem moles` — Mole calculations
- [x] `tri chem atoms` — Atom count
- [x] `tri chem ideal-gas` — PV=nRT
- [x] `tri chem stp` — Standard conditions
- [x] `tri chem ph` / `poh` — pH calculations
- [x] `tri chem molarity` — Concentration
- [x] `tri chem dilution` — M1V1=M2V2
- [x] `tri chem yield` — Percent yield
- [x] `tri chem gibbs` — Free energy
- [x] `tri chem nernst` — Electrochemistry
- [x] `tri chem half-life` — Radioactive decay
- [x] `tri chem search` — Element search
- [x] `tri chem group/period/block` — Filters
- [ ] `tri chem redox` — Redox analysis (IN PROGRESS — oxidation states working)
- [ ] `tri chem oxidation` — Oxidation number calculator (PARTIAL)
- [ ] `tri chem limiting` — Limiting reagent (NEEDS TEST)
- [ ] `tri chem titration` — Titration curves (NEEDS TEST)
- [ ] `tri chem buffer` — Buffer calculations (NEEDS TEST)
- [ ] `tri chem ksp` — Solubility product (NEEDS TEST)

**Files:**
- `src/tri/tri_chemistry.zig` (1594 lines)
- `src/sacred/chemistry.zig` (periodic table data)
- `specs/tri/chemistry_cli.vibee`
- `specs/tri/chemistry_core.vibee`

**Quarks:**
- [ ] [P1] Fix build errors (manifest_create FileNotFound)
- [ ] [P1] Complete redox analysis — electron transfer, half-reactions
- [ ] [P2] Add tests for limiting/titration/buffer/ksp
- [ ] [P2] Improve oxidation state algorithm for complex compounds

---

### Geometry CLI (`tri geom`)

**Status: 18 commands implemented (2046 lines)**

- [x] `tri geom platonic` — Platonic solids info
- [x] `tri geom euler` — Euler's formula V-E+F=2
- [x] `tri geom vesica` — Vesica Piscis
- [x] `tri geom pentagon` — Golden ratio geometry
- [x] `tri geom flower` — Flower of Life
- [x] `tri geom metatron` — Metatron's Cube
- [x] `tri geom sierpinski` — Sierpinski triangle
- [x] `tri geom koch` — Koch snowflake
- [x] `tri geom cantor` — Cantor set
- [x] `tri geom fractal-dim` — Fractal dimension calculator
- [x] `tri geom mandelbrot` — Mandelbrot set info
- [x] `tri geom hull` — Convex hull (computational)
- [x] `tri geom pip` — Point in polygon
- [x] `tri geom trit3d` — Trit 3D lattice
- [x] `tri geom sphere` — Spherical geometry
- [x] `tri geom hyper` — Hyperbolic geometry
- [x] `tri geom curvature` — Curvature types
- [x] `tri geom help` — Command help

**Files:**
- `src/tri/geometry/commands.zig` (124 lines)
- `src/tri/geometry/platonic.zig` (279 lines)
- `src/tri/geometry/fractal.zig` (379 lines)
- `src/tri/geometry/sacred.zig` (236 lines)
- `src/tri/geometry/computational.zig` (361 lines)
- `src/tri/geometry/non_euclidean.zig` (309 lines)
- `src/tri/geometry/format.zig` (93 lines)
- `src/tri/geometry/mod.zig` (265 lines)

**Quarks:**
- [ ] [P1] Add tests for all geometry commands
- [ ] [P2] Add `tri geom area` — Polygon area
- [ ] [P2] Add `tri geom volume` — 3D volume calculator
- [ ] [P3] ASCII art output for fractals

---

## 📊 Math CLI (`tri math`)

**Status: Working, needs expansion**

- [x] Basic operations, constants
- [x] Sequences (fibonacci, primes, etc.)
- [x] Special functions
- [x] Geometry basics (in math_geometry.vibee)
- [x] Identities

**Files:**
- `src/tri/math/` directory
- `specs/tri/math_*.vibee`

---

## 🔧 Build & Test Issues

**Current Problems:**
1. `manifest_create FileNotFound` — cache issue
2. 12 build steps failing
3. 4 tests skipped
4. Some compile errors in test files

**Solutions:**
- [ ] [P1] Clean build cache: `rm -rf .zig-cache`
- [ ] [P1] Rebuild: `zig build`
- [ ] [P1] Run tests: `zig build test`
- [ ] [P2] Fix compile errors in test files

---

## 🎯 NEXT PRIORITIES

### Tonight (while sleeping)
1. Ralph subagent working on Golden Chain Cycle 43
2. Fix build issues
3. Complete redox analysis

### Tomorrow
1. Add tests for chemistry commands
2. Add tests for geometry commands
3. Document all CLI commands in README

### This Week
1. Physics CLI (`tri physics`)
2. Complete VIBEE specs for all modules
3. 100% test coverage for core commands

---

## 📁 Key Files

| File | Purpose | Lines |
|------|---------|-------|
| `src/tri/tri_chemistry.zig` | Chemistry CLI | 1594 |
| `src/tri/geometry/*.zig` | Geometry CLI | 2046 |
| `src/sacred/chemistry.zig` | Periodic table | 420+ |
| `specs/tri/chemistry_cli.vibee` | Chemistry spec | - |
| `specs/tri/math_*.vibee` | Math specs | - |

---

## 🚫 BLOCKED

(none currently)

---

## ✅ COMPLETED TODAY (2026-03-02)

- [x] Chemistry CLI v6.0 — 26 commands
- [x] Geometry CLI v1.0 — 18 commands
- [x] Redox analysis partial implementation
- [x] Oxidation state calculator
- [x] Fractal geometry (Sierpinski, Koch, Cantor, Mandelbrot)
- [x] Sacred geometry (Vesica, Pentagon, Flower, Metatron)
- [x] Non-Euclidean geometry (Sphere, Hyperbolic)
- [x] Computational geometry (Hull, PIP)
- [x] **Golden Chain Cycle 43: Multilingual Codegen** — 5 languages (Zig, Python, Rust, TypeScript, Go) with 100% idiom compliance, φ gate validation passed

---

*φ² + 1/φ² = 3 | TRINITY*
