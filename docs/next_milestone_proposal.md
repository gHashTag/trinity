# Next Milestone Proposal

**Date:** 2026-02-06
**Context:** Documentation restructuring complete. Docs live at https://gHashTag.github.io/trinity/docs with zero mystical terminology, 15+ academic references, honest claim classification.

---

## Current State

| Component | Status | Readiness |
|-----------|--------|-----------|
| Documentation | Deployed, Nobel-level | Production |
| VSA core (bind/bundle/permute/similarity) | Implemented, tested | Production |
| HybridBigInt (packed/unpacked) | Implemented, tested | Production |
| Ternary VM (bytecode interpreter) | Implemented, tested | Production |
| VIBEE compiler (Zig + Verilog codegen) | Implemented, tested | Production |
| Firebird LLM engine | Implemented, basic inference | Beta |
| BitNet b1.58 integration | Implemented, tokenizer decoding fixed | Beta |
| JIT compiler | Implemented | Beta |
| DePIN subsystem | Implemented | Alpha |
| FPGA/Verilog output | Code generation works | Alpha |

---

## Three Options for Next Milestone

### Option A: Coherent BitNet Demo on RunPod

**What:** Produce a public demo showing BitNet b1.58 generating coherent, readable text via the Firebird engine on RunPod GPU infrastructure. Record it, publish results, add to docs.

**Why this matters:**
- Proves the ternary inference engine works end-to-end on real hardware
- Creates a tangible artifact investors and researchers can evaluate
- Builds on existing work (BitNet report, RunPod deploy guide already in docs)
- Lowest risk -- infrastructure and code already exist

**Concrete steps:**
1. Deploy Firebird + BitNet 2B4T model to RunPod A100 instance
2. Run inference on standard benchmarks (HellaSwag, ARC, WinoGrande)
3. Generate sample outputs demonstrating coherent text
4. Measure tokens/sec, memory usage, compare to llama.cpp baseline
5. Write `docs/research/bitnet-demo-results.md` with methodology and data
6. Record terminal session as proof

**Risks:**
- Model coherence may still be limited (previous report showed issues)
- RunPod costs for A100 time
- Results may not be competitive vs llama.cpp without further optimization

**Deliverable:** Published benchmark results + coherent text samples + terminal recording

---

### Option B: $TRI Token Launch (Mainnet)

**What:** Launch the $TRI token on a blockchain (Solana, Base, or standalone) with supply 3^21 = 10,460,353,203.

**Why this matters:**
- Creates an economic layer for the Trinity ecosystem
- Enables DePIN incentives (node operators earn $TRI for inference)
- Token launch generates visibility and community momentum

**Concrete steps:**
1. Choose blockchain (Solana SPL token vs Base ERC-20 vs custom)
2. Write token contract with fixed supply = 3^21
3. Audit the contract (or use audited template)
4. Set up liquidity pool
5. Create tokenomics documentation
6. Launch and announce

**Risks:**
- Regulatory uncertainty -- token launches face legal scrutiny
- Requires marketing/community infrastructure beyond engineering
- Distraction from core technology development
- Token without demonstrated utility may not sustain value

**Deliverable:** Live token contract + liquidity + tokenomics docs

---

### Option C: Firebird Chrome Extension Release

**What:** Package the Firebird LLM engine as a Chrome extension for local/edge inference in the browser via WebAssembly.

**Why this matters:**
- Demonstrates practical use case: local AI inference without cloud dependency
- Chrome Web Store provides distribution channel
- WebAssembly target already partially supported in build system

**Concrete steps:**
1. Build Firebird WASM target with minimal model (small BitNet)
2. Create Chrome extension manifest and popup UI
3. Implement text generation interface in extension
4. Optimize WASM binary size (target under 50MB)
5. Test across Chrome versions
6. Submit to Chrome Web Store

**Risks:**
- WASM performance may be insufficient for usable inference speed
- Chrome extension size limits may require aggressive model compression
- UX design for a Chrome extension inference tool is non-trivial
- Chrome Web Store review process can be slow

**Deliverable:** Published Chrome extension + Web Store listing

---

## Recommendation

**Option A (Coherent BitNet Demo)** is the strongest next move:

1. **Lowest risk** -- all infrastructure exists, just needs execution
2. **Highest credibility** -- published benchmarks with methodology are what researchers and investors evaluate
3. **Directly builds on docs work** -- the documentation now has proper research section and RunPod deploy guide
4. **Concrete and measurable** -- either the model generates coherent text or it doesn't
5. **Prerequisite for B and C** -- token launch and Chrome extension both need a working inference engine demonstrated first

Option B (token launch) is premature without a demonstrated working product. Option C (Chrome extension) depends on WASM inference performance that hasn't been benchmarked yet.

---

## Proposed Timeline for Option A

| Step | Action |
|------|--------|
| 1 | Deploy BitNet 2B4T to RunPod A100 |
| 2 | Run standard benchmarks (HellaSwag, ARC, WinoGrande) |
| 3 | Generate and curate coherent text samples |
| 4 | Measure throughput (tokens/sec) and memory |
| 5 | Compare against llama.cpp baseline on same hardware |
| 6 | Write results page with full methodology |
| 7 | Record terminal session demo |
| 8 | Add to docs and deploy |
