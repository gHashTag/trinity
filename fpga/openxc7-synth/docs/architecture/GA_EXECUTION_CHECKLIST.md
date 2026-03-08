# GA Execution Checklist
**Trinity v2.2.0 - Quick Reference**

**Copy this file and check off items as you complete them.**

---

## Phase 1: Clean Build Verification (5 min)

### Step 1.1: Environment Check
- [ ] Zig version = 0.15.x
- [ ] Docker daemon running
- [ ] FORGE binary exists
- [ ] Baseline tests: 3584/3589 passing

**Command:** `zig version && docker --version && ls zig-out/bin/forge`

**Log:** `phase1_env_check.log`

---

### Step 1.2: Clean Build
- [ ] Removed `zig-cache/` and `zig-out/`
- [ ] Build completed with 0 errors
- [ ] All binaries generated (tri, vibee, forge, firebird)

**Command:** `rm -rf zig-cache/ zig-out/ && zig build`

**Log:** `phase1_clean_build.log`

---

### Step 1.3: Dependency Verification
- [ ] TRI CLI responsive
- [ ] VIBEE compiler responsive
- [ ] FORGE toolchain responsive
- [ ] No "module not found" errors

**Command:** `zig build tri -- help && zig build vibee -- gen --help`

**Log:** `phase1_dependency_check.log`

---

## Phase 2: Full Regression Run (10 min)

### Step 2.1: VSA Tests
- [ ] All VSA tests pass
- [ ] Operations: bind, unbind, bundle, permute, similarity
- [ ] Performance within 5% of baseline

**Command:** `zig test src/vsa.zig`

**Log:** `phase2_vsa_tests.log`

**Baseline:**
- BIND: 365K ops/s
- BUNDLE: 455K ops/s
- PERMUTE: 2.9B ops/s
- SIMILARITY: 26M ops/s

---

### Step 2.2: VM Tests
- [ ] All VM tests pass
- [ ] Stack operations correct
- [ ] No memory leaks

**Command:** `zig test src/vm.zig`

**Log:** `phase2_vm_tests.log`

---

### Step 2.3: Full Test Suite
- [ ] Pass rate ≥ 99.8% (3584/3589 tests)
- [ ] No new failures vs baseline
- [ ] Known failure: `test.PackedArray get/set` in qutrit.zig

**Command:** `zig build test`

**Log:** `phase2_full_tests.log`

---

### Step 2.4: Contract Tests
- [ ] 19/19 contract tests pass
- [ ] IConfigManager: load, save, validate
- [ ] IPersistentState: serialize, deserialize
- [ ] IBatchExecutor: submit, run, cancel

**Command:** `zig test trinity-nexus/output/lang/zig/contract_test.zig`

**Log:** `phase2_contract_tests.log`

---

## Phase 3: E2E Validation (15 min)

### Step 3.1: FPGA Synthesis (Docker)
- [ ] Synthesis completes without errors
- [ ] Bitstream generated (.bit file)
- [ ] Resource utilization within limits
- [ ] Timing constraints met (50 MHz)

**Command:** `cd fpga/openxc7-synth && ./synth.sh d6_blink.v trinity_top`

**Log:** `phase3_fpga_synth.log`

**Note:** Use openXC7 Docker (FORGE has known bugs)

---

### Step 3.2: VIBEE Zig Generation
- [ ] Zig code generated from spec
- [ ] Output file created
- [ ] Generated code compiles
- [ ] All 16 functions present

**Command:** `zig build vibee -- gen specs/tri/contract_test.vibee`

**Log:** `phase3_vibee_zig.log`

---

### Step 3.3: VIBEE Verilog Generation
- [ ] Verilog file generated
- [ ] Syntax validation passes (Yosys)
- [ ] Module structure correct

**Command:** `zig build vibee -- gen specs/tri/d6_blink.vibee && yosys -p "proc; check" trinity-nexus/output/fpga/d6_blink.v`

**Log:** `phase3_vibee_verilog.log`

---

### Step 3.4: AI Chat E2E
- [ ] Chat interface responds
- [ ] Sacred mathematics knowledge works
- [ ] No crashes or hangs
- [ ] Response time < 5 seconds

**Command:** `echo "What is φ?" | ./zig-out/bin/tri chat`

**Log:** `phase3_chat_e2e.log`

---

## Phase 4: Benchmark Comparison (10 min)

### Step 4.1: VSA Performance
- [ ] No regression > 5%
- [ ] BIND ≥ 350K ops/s
- [ ] BUNDLE ≥ 430K ops/s
- [ ] PERMUTE ≥ 2.7B ops/s
- [ ] SIMILARITY ≥ 24M ops/s

**Command:** `zig build bench`

**Log:** `phase4_vsa_bench.log`

---

### Step 4.2: Memory Efficiency
- [ ] Compression ratio ≥ 5x
- [ ] No memory leaks
- [ ] Consistent with baseline

**Command:** `zig test src/packed_trit.zig`

**Log:** `phase4_memory.log`

---

### Step 4.3: Build Time
- [ ] Clean build < 5 min
- [ ] Test suite < 3 min
- [ ] No significant increase vs baseline

**Command:** `time zig build && time zig build test`

**Log:** `phase4_build_time.log`

---

### Step 4.4: Comparison Report
- [ ] All metrics documented
- [ ] SHIP/NO-SHIP recommendation clear
- [ ] Regressions identified and justified

**Output:** `phase4_comparison.md`

---

## Phase 5: Evidence Gathering (5 min)

### Step 5.1: Test Evidence
- [ ] All test logs collected
- [ ] Organized by category
- [ ] No missing evidence

**Command:** `mkdir -p ga_evidence/tests && cp phase2_*.log ga_evidence/tests/`

---

### Step 5.2: Build Artifacts
- [ ] All binaries archived
- [ ] Archive can be extracted
- [ ] File sizes reasonable

**Command:** `cd zig-out/bin && tar czf ../../ga_evidence/trinity-v2.2.0-binaries.tar.gz tri vibee forge firebird`

---

### Step 5.3: Documentation
- [ ] GA_CERTIFICATION_v2.2.0.md present
- [ ] Status = "PRODUCTION READY"
- [ ] Known issues documented
- [ ] Release checklist complete

**Command:** `cat fpga/openxc7-synth/docs/architecture/GA_CERTIFICATION_v2.2.0.md | grep -E "Status|Approved"`

---

### Step 5.4: Git State
- [ ] Commit hash matches expected (f667b7ad4)
- [ ] No uncommitted changes in artifacts
- [ ] Branch is main or release branch

**Command:** `git log -1 --pretty=format:"%H %s" > ga_evidence/git_commit.txt && git status > ga_evidence/git_status.txt`

---

### Step 5.5: Evidence Package
- [ ] All evidence included
- [ ] Archive integrity verified
- [ ] Checksum generated
- [ ] Pack size < 50MB

**Command:** `cd ga_evidence && tar czf ../trinity-v2.2.0-GA-CERTIFICATION.tar.gz * && shasum ../trinity-v2.2.0-GA-CERTIFICATION.tar.gz > ../trinity-v2.2.0-GA-CERTIFICATION.sha256`

---

## Phase 6: Final Verdict (5 min)

### Step 6.1: Evidence Review
- [ ] All evidence reviewed
- [ ] No blocking issues
- [ ] All checks documented

**Output:** `phase6_review.md`

---

### Step 6.2: Toxic Verdict
- [ ] Verdict generated
- [ ] "Что работает" documented
- [ ] "Что требует работы" documented
- [ ] "Честная оценка" provided
- [ ] SHIP/NO-SHIP decision clear

**Command:** `./zig-out/bin/tri verdict`

**Output:** `phase6_verdict.txt`

---

### Step 6.3: Final Sign-Off
- [ ] All checklist items marked
- [ ] Decision documented
- [ ] Rationale provided
- [ ] Signatures captured

**Output:** `GA_SIGNOFF.md`

---

## Overall Status

**Complete:** [ ] / [ ] phases

**Go/No-Go Decision:** [ ] GO / [ ] NO-GO

**Date:** _______________

**Signature:** _______________

---

## Stop Conditions

**IMMEDIATE STOP if:**
- [ ] Build fails (Phase 1)
- [ ] Test pass rate < 99% (Phase 2)
- [ ] E2E validation fails (Phase 3)
- [ ] Performance regression > 10% (Phase 4)

**WARN and CONTINUE if:**
- [ ] Performance regression 5-10% (Phase 4)
- [ ] Known issues documented (Phase 5)

---

## Quick Reference Commands

**Full execution (sequential):**
```bash
# Phase 1
zig version && docker --version
rm -rf zig-cache/ zig-out/ && zig build

# Phase 2
zig test src/vsa.zig
zig test src/vm.zig
zig build test
zig test trinity-nexus/output/lang/zig/contract_test.zig

# Phase 3
cd fpga/openxc7-synth && ./synth.sh d6_blink.v trinity_top
cd ../.. && zig build vibee -- gen specs/tri/contract_test.vibee
zig build vibee -- gen specs/tri/d6_blink.vibee

# Phase 4
zig build bench
time zig build && time zig build test

# Phase 5
mkdir -p ga_evidence
# Collect all evidence...

# Phase 6
./zig-out/bin/tri verdict
```

**Parallel execution (where possible):**
```bash
# Run Phase 2 tests in parallel
zig test src/vsa.zig &
zig test src/vm.zig &
wait

# Run Phase 3 E2E in parallel
cd fpga/openxc7-synth && ./synth.sh d6_blink.v trinity_top &
cd ../.. && zig build vibee -- gen specs/tri/contract_test.vibee &
wait
```

---

**φ² + 1/φ² = 3 | γ = φ⁻³ | TRINITY v2.2.0**
