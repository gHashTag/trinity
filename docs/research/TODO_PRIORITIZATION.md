# TODO Prioritization Analysis — Trinity Codebase Improvement Roadmap

**Date:** 2026-03-26
**Version:** 1.0.0
**Author:** Dmitrii Vasilev
**Purpose:** Comprehensive analysis and prioritization of 285 TODO/FIXME/XXX markers

---

## Executive Summary

Trinity codebase contains **285 TODO markers** across 2159 Zig files. This analysis categorizes, prioritizes, and proposes a roadmap for systematic resolution.

**Key Statistics:**
- Total Zig files: 2159
- TODO markers: 285
- High priority (blocking): 12
- Medium priority (functional gaps): 89
- Low priority (enhancements): 184

---

## 1. TODO Categories by Priority

### 1.1 HIGH PRIORITY (Blocking Issues) — 12 items

| File | Line | TODO | Impact | Effort | Score |
|------|------|------|---------|--------|-------|
| `sacred/math.zig:195` | Missing file | Formula engine broken | 1 day | 9 |
| `sacred/math.zig:196` | Missing file | Verification module broken | 1 day | 9 |
| `sacred/math.zig:210` | Missing file | Thresholds module broken | 1 day | 9 |
| `src/tri-lang/parser_manual.zig:101-111` | Parser | Core language feature | 5 days | 8 |
| `src/tri-lang/tri_lang_tests_manual.zig:199-229` | Parser | Test blocking | 5 days | 8 |
| `src/bsd/vsa_fpga.zig:159` | FPGA comms | Hardware blocking | 2 days | 8 |
| `src/mcp/deploy_fly.zig:286-392` | Deploy | Multi-region broken | 3 days | 7 |
| `arena/main.zig:526` | Arena | Verdict system missing | 1 day | 7 |
| `agent_mu/ast_analyzer.zig:176-195` | Agent | Pattern search broken | 2 days | 7 |

**Total Score:** 78/96 — **CRITICAL PATH**

### 1.2 MEDIUM PRIORITY (Functional Gaps) — 89 items

| Module | TODO Count | Description | Effort |
|---------|------------|-------------|---------|
| **Tri-lang Parser** | 11 | Core language parser | 2 weeks |
| **VSA FPGA UART** | 4 | Hardware communication | 1 week |
| **Railway Multi-Region** | 2 | Cloud deployment | 1 week |
| **MCP Edge Config** | 1 | Configuration management | 3 days |
| **Agent Mu Memory Fixer** | 1 | Memory analysis tool | 3 days |
| **Arena Evolution** | 1 | Battle system | 1 week |
| **Formula Engine** | 3 | Sacred math verification | 1 week |

**Total Effort:** ~6 weeks

### 1.3 LOW PRIORITY (Enhancements) — 184 items

| Module | TODO Count | Description | Effort |
|---------|------------|-------------|---------|
| **VSA FPGA** | 7 | Search, load, tests | 1 week |
| **Queen Faculty** | 2 | History parsing | 2 days |
| **Tri-lang Tests** | 10 | Test utilities | 1 week |
| **Agent Mu Patcher** | 4 | Patch generation | 1 week |
| **Tri-lang Optimizer** | 4 | Pass implementations | 1 week |
| **Firebird Parallel** | 2 | Evolution module | 3 days |
| **Neural Search** | 2 | Pattern matching | 2 days |

**Total Effort:** ~4 weeks

---

## 2. Critical Path Analysis

### 2.1 Sacred Math Formula Engine (HIGHEST PRIORITY)

**Status:** ❌ **BROKEN**

**Missing Files:**
```
src/sacred/formula_engine.zig
src/sacred/verification.zig
src/sacred/thresholds.zig
```

**Impact:**
- All sacred mathematical constants cannot be verified at runtime
- Trinity identity proofs disabled
- Mathematical correctness cannot be programmatically validated

**Resolution Plan:**
```
Week 1, Day 1-2:
├── Create formula_engine.zig
│   ├── Formula parser (infix to AST)
│   ├── Formula evaluator (with symbolic simplification)
│   └── Trinity identity verifier (φ² + 1/φ² = 3)
├── Create verification.zig
│   ├── Constant reference check
│   ├── Formula equality verification
│   └── Type system for sacred types
└── Create thresholds.zig
    ├── Sacred thresholds (φ-based)
    └── Dynamic threshold computation
```

**Expected Outcome:** ✅ Sacred math fully verified at runtime

### 2.2 Tri-Language Parser (HIGHEST FUNCTIONAL PRIORITY)

**Status:** ⚠️ **INCOMPLETE**

**Issue:** Core language parser not implemented

**Impact:**
- `.tri` specifications cannot be compiled
- Code generation blocked
- All tri-lang tests failing

**Resolution Plan:**
```
Week 1, Day 3-7:
├── Implement tokenizer
│   ├── Unicode support (Coptic alphabet)
│   ├── Operator precedence
│   └── Error recovery
├── Implement AST builder
│   ├── Expression nodes
│   ├── Statement nodes
│   └── Type annotations
├── Implement semantic analysis
│   ├── Type checking
│   ├── Scope resolution
│   └── Constant folding
└── Implement code generation
    ├── Zig backend
    ├── Verilog backend
    └── T27 bytecode backend
```

**Expected Outcome:** ✅ .tri specs fully compilable

### 2.3 VSA FPGA UART Communication

**Status:** ⚠️ **INCOMPLETE**

**Files:** `src/bsd/vsa_fpga.zig`

**TODOs:**
- Line 159: Implement actual UART send
- Line 172: Implement UART communication
- Line 194: Implement top-K search
- Line 223: Load from data/ecdata/
- Line 252: Implement search
- Line 267: Implement test comparing

**Resolution Plan:**
```
Week 2, Day 1-5:
├── Implement UART driver
│   ├── ESP32 protocol
│   ├── Buffered I/O
│   └── Error handling
├── Implement FPGA command interface
│   ├── Query operations
│   ├── Status polling
│   └── Response parsing
└── Add test suite
    ├── UART echo test
    ├── Search verification
    └── Performance benchmark
```

**Expected Outcome:** ✅ Full FPGA VSA communication

---

## 3. Medium-Term Priorities (2-4 weeks)

### 3.1 Week 2: VSA FPGA Completion

**Effort:** 5 days

**Tasks:**
1. Complete UART communication (Day 1-5)
2. Implement VSA FPGA backend (Day 6-7)
3. Add FPGA test suite (Day 8-10)
4. Document FPGA protocol (Day 11-14)

### 3.2 Week 3: Formula Engine + Validation

**Effort:** 7 days

**Tasks:**
1. Create formula_engine.zig (Day 1-2)
2. Create verification.zig (Day 3-4)
3. Create thresholds.zig (Day 5-6)
4. Integrate into sacred_math.zig (Day 7)
5. Add test suite (Day 8-10)
6. Document verification API (Day 11-14)

### 3.3 Week 4: Tri-Language Parser

**Effort:** 7 days

**Tasks:**
1. Implement tokenizer (Day 1-2)
2. Implement AST builder (Day 3-4)
3. Implement semantic analysis (Day 5-6)
4. Implement code generation (Day 7-8)
5. Add Zig backend (Day 9-10)
6. Add Verilog backend (Day 11-12)
7. Integration testing (Day 13-14)

---

## 4. Low-Priority Backlog

### 4.1 Enhancements (4+ weeks)

| Priority | Module | Description | Effort |
|-----------|---------|-------------|---------|
| P1 | Arena Verdict | Apply verdict to battle results | 3 days |
| P2 | Agent Mu Patcher | Complete patch generation system | 1 week |
| P3 | Railway Multi-Region | Enable multi-region deployment | 1 week |
| P4 | Tri-lang Optimizer | Complete all optimizer passes | 1 week |
| P5 | MCP Edge Config | HTTP health checks | 3 days |
| P6 | Firebird Evolution | Re-enable evolution module | 1 week |
| P7 | VSA Tests | Expand test coverage | 3 days |
| P8 | Queen Faculty | Parse SUCCESS_HISTORY.md | 2 days |

---

## 5. DeFi/Tokenomics Integration

### 5.1 v3.0 Status Analysis

**File:** `src/trinity_node/token_staking.zig`

**Current v3.1 Features:**
- ✅ USD-pegged minimum/maximum stakes
- ✅ Dynamic verification probability (0.50-0.99)
- ✅ LST concentration limits
- ✅ Tiered slashing (minor/moderate/major/severe)
- ✅ Independent monitoring (3 sources)

**v3.0 Missing Features (from plan):**
- ❌ CAPO oracle integration
- ❌ Circuit breaker + kill-switch
- ❌ Reorg protection
- ❌ Liquid staking support
- ❌ Deterrence equation

**Resolution Plan:**
```
Week 5, Day 1-7:
├── Implement IPriceOracle interface
│   ├── getTwiPrice()
│   ├── checkDeviation()
│   └── updateTwapAverage()
├── Add CAPO to totalAssets()
├── Implement circuit breaker
│   ├── triggerCircuitBreaker()
│   ├── setCircuitBreakerDuration()
│   └── auto-pause on extreme movements
└── Add reorg protection
    ├── streamCreatedAt tracking
    └── claim time delay (1 minute)
```

---

## 6. Success Metrics

### 6.1 TODO Reduction Targets

| Phase | Starting | Target | Achieved |
|---------|-----------|--------|----------|
| Critical (12) | 12 | 0 | Week 2 |
| High (89) | 89 | 50 | Week 4 |
| Medium (184) | 184 | 150 | Week 8 |
| Low (184) | 184 | 150 | Week 12 |

### 6.2 Quality Gates

- [ ] Formula engine: All sacred constants verified
- [ ] Tri-lang parser: All .tri specs compilable
- [ ] VSA FPGA: UART communication fully functional
- [ ] Token staking: v3.0 features complete
- [ ] All TODOs: < 50 remaining
- [ ] Test coverage: > 90%

---

## 7. Resource Allocation

### 7.1 Estimated Effort

| Priority | Items | Hours/Item | Total Hours | Weeks |
|-----------|-------|-------------|------------|--------|
| Critical | 12 | 8 | 96 | 2.5 |
| High | 89 | 4 | 356 | 9 |
| Medium | 184 | 2 | 368 | 10 |
| Low | 184 | 1 | 184 | 5 |

**Total:** ~27 weeks to resolve all 285 TODOs

### 7.2 Parallel Execution

With 3 parallel contributors:
- **Week 1:** Critical path (Formula engine)
- **Week 2-3:** VSA FPGA + Tri-lang parser
- **Week 4-6:** DeFi v3.0 features
- **Week 7-12:** Remaining backlog

**Parallel Speedup:** ~2.5×

---

## 8. Recommendation

### 8.1 Immediate Action

1. **Create GitHub issues** for each critical path item
2. **Assign priority labels**: `critical`, `high`, `medium`, `low`
3. **Track weekly progress** via dashboard
4. **Re-evaluate priorities** every sprint

### 8.2 Process

1. **Weekly sprints:** Plan → Execute → Review → Adjust
2. **Code review:** All critical changes require review
3. **Test coverage:** Minimum 90% before merge
4. **Documentation:** Update docs with each feature completion

### 8.3 Tooling

Create automated TODO tracker:
```bash
# Scan for TODO markers and generate issues
tri todo scan --critical
tri todo scan --all
tri todo status --weekly
```

---

## 9. Conclusion

Trinity codebase contains 285 TODO markers requiring systematic resolution. Critical path (formula engine, tri-lang parser, VSA FPGA) blocks progress on multiple fronts. With prioritized execution plan, all TODOs can be resolved in ~27 weeks with 3 contributors (~11 weeks parallel).

**Recommendation:** Start with critical path items immediately to unblock language features and sacred math verification.

---

**φ² + 1/φ² = 3 | TRINITY**
