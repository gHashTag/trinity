# EXPERIENCE LOG (ExpeL)

Structured knowledge base for HSLM training. Every significant event gets an entry.

**Agent rules:**
- Before every deploy/push: `grep FAILURE EXPERIENCE_LOG.md`
- Trigger new entry on: service FAILED, PPL >10% improvement, unexpected result, deployment error, build failure, seed anomaly

---

### EXP-001 | DISCOVERY | 2026-03-13 | architecture
**Impact**: HIGH
**Context**: Compared ctx=18 (Wave 3-4 baseline) vs ctx=27 (Wave 5) across identical configs (LAMB 1e-3, cosine, batch=66).
**Outcome**: ctx=27 achieved PPL 2.96 (R5) vs ctx=18 best PPL 5.58 (R18). 1.89x PPL improvement. ctx=27 = 3^3 aligns with ternary architecture.
**Lesson**: Context length is the dominant hyperparameter — more important than optimizer, LR, or batch size.
**Action items**: Test ctx=81 (3^4) and ctx=243 (3^5) once Railway build is fixed.

---

### EXP-002 | FAILURE | 2026-03-13 | deployment
**Impact**: HIGH
**Context**: Set HSLM_FRESH=1 on services that had accumulated 30K+ steps of training (R5, R23v2).
**Outcome**: Checkpoints wiped. R5 (PPL 2.96 KING) and R23v2 (PPL 2.9) lost all progress and restarted from scratch.
**Root cause**: HSLM_FRESH=1 calls clearCheckpoints() which deletes all hslm_step_*.bin files. Did not preserve _final.bin naming convention.
**Lesson**: NEVER set HSLM_FRESH=1 on services with valuable checkpoints. Use HSLM_FRESH=1 ONLY for new/recycled services.
**Action items**: Added _final.bin preservation in clearCheckpoints(). Always save checkpoint_final before recycling.

---

### EXP-003 | FAILURE | 2026-03-13 | deployment
**Impact**: HIGH
**Context**: Git push to main triggered Railway auto-rebuild on 4 PRIMARY services (trinity, Agents Anywhere, ubuntu, trinity-mcp).
**Outcome**: All 4 PRIMARY services entered FAILED state. Training runs C1v2 (97.5K steps), C2 (93.7K), C3 (80.3K), C4v2 (46.3K) interrupted near completion.
**Root cause**: Railway watches the git repo. Push triggers rebuild. Build likely OOM or submodule bloat (fpga/prjxray 1.5GB). Services that were training crashed mid-run.
**Lesson**: Git pushes to main affect ALL Railway services linked to the repo. Push during training = service crash.
**Action items**: 1) Fix .dockerignore to exclude heavy submodules. 2) Use deploymentRedeploy with previous image instead of push-triggered builds. 3) Consider branch-based deploy isolation.

---

### EXP-004 | DISCOVERY | 2026-03-13 | training
**Impact**: MEDIUM
**Context**: R29v2 running PHI+restart schedule (cosine with phi-based warm restarts) at ctx=21.
**Outcome**: PPL 3.10 at 75.2K steps — competitive with cosine-only runs at larger ctx=27. PHI restarts provide periodic LR boosts that help escape local minima.
**Lesson**: PHI+restart schedule approximates cosine performance at smaller context lengths. May be optimal for resource-constrained training.
**Action items**: Implement lr_phi_restart as a first-class schedule in trainer.zig. Test at ctx=27 for fair comparison.

---

### EXP-005 | DISCOVERY | 2026-03-13 | training
**Impact**: MEDIUM
**Context**: Compared AdamW 3e-4 (R18, ctx=18) vs LAMB 1e-3 (R5, ctx=27) across different context lengths.
**Outcome**: At ctx=18, AdamW achieves PPL 5.58 (R18 at 89.9K steps). At ctx=27, LAMB achieves PPL 2.96 (R5 at 32.4K). LAMB with ctx=27 learns faster, but the dominant factor is context length, not optimizer.
**Lesson**: Context length >> optimizer choice. AdamW and LAMB converge to similar quality given sufficient steps at the same context.
**Action items**: Standardize on LAMB 1e-3 for convenience (faster convergence) but prioritize context length experiments over optimizer sweeps.

---

### EXP-006 | WARNING | 2026-03-13 | training
**Impact**: HIGH
**Context**: Wave 5-6 seed sweep with 38 services, all same config (LAMB 1e-3, cosine, batch=66, ctx=27), different random seeds.
**Outcome**: PPL range from 2.96 (R5, best) to 464 (R26v2, worst at 2.3K steps warming). Even mature runs: PPL 2.96 to 53.8 at similar step counts. Variance factor ~157x between best and worst seeds.
**Root cause**: Ternary quantization amplifies seed sensitivity. Initial random weights quantize to different sparsity patterns, some of which trap the optimizer in poor basins.
**Lesson**: Seed variance is extreme in ternary models. Must run 5+ seeds per config to get reliable comparisons. Single-seed results are unreliable.
**Action items**: Always run 5-seed sweeps. Report median PPL, not best. Consider init_weights_zero to reduce seed variance.

---

### EXP-007 | SUCCESS | 2026-03-13 | training
**Impact**: HIGH
**Context**: v13 training run with LAMB 1e-3, cosine schedule, batch=128, ctx=18 (legacy config).
**Outcome**: PPL broke through plateau at step 50K, dropping from 109 to 73 by step 60K. Loss curve showed clear inflection point at 50K — likely attention heads aligning.
**Lesson**: HSLM has a characteristic plateau around PPL 100-120 that breaks at ~50K steps. Patience pays off — do not abort runs before 50K.
**Action items**: Set minimum run length to 60K steps for meaningful comparison. Use 50K as "plateau checkpoint" for comparison.

---

### EXP-008 | SUCCESS | 2026-03-13 | training
**Impact**: MEDIUM
**Context**: Wave 6 launched with fresh seeds across all 38 services after recycling completed runs.
**Outcome**: 68% of seeds (26/38) reached PPL < 15 within 30K steps. 8% (3/38) achieved PPL < 5. 32% (12/38) still warming or stuck above PPL 50.
**Lesson**: Good seed rate of ~68% means roughly 1 in 3 seeds underperforms significantly. Need seed filtering strategy.
**Action items**: Implement early stopping for seeds with PPL > 30 at step 20K — recycle those slots. Monitor seed quality distribution across waves.
