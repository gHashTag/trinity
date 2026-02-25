# GitHub Issues for Trinity Repository Cleanup

## Migration & Structure

### Issue #1: Complete phi-engine integration
**Labels:** `enhancement`, `migration`
**Priority:** High

Integrate phi-engine fully into Trinity build system:
- [ ] Add phi-engine to build.zig
- [ ] Create tests for quantum/ and ouroboros modules
- [ ] Document phi-engine API in docs/api/

---

### Issue #2: Consolidate duplicate code between vibeec and tvc
**Labels:** `refactor`, `tech-debt`
**Priority:** Medium

Both `src/vibeec/` and `src/tvc/` contain overlapping functionality:
- [ ] Audit both directories for duplicates
- [ ] Merge common code into shared modules
- [ ] Remove deprecated files

---

### Issue #3: Clean up generated files from repository
**Labels:** `cleanup`
**Priority:** Low

Remove auto-generated files that shouldn't be in git:
- [ ] Add `trinity/output/` to .gitignore
- [ ] Remove any committed .zig-cache directories
- [ ] Clean up binary artifacts

---

## Documentation

### Issue #4: Complete API documentation
**Labels:** `documentation`
**Priority:** High

Expand docs/api/ with:
- [ ] Full type reference for all public structs
- [ ] Error handling documentation
- [ ] Thread safety guidelines
- [ ] Performance tuning guide

---

### Issue #5: Add architecture diagrams
**Labels:** `documentation`
**Priority:** Medium

Create visual diagrams for:
- [ ] System architecture (ASCII or SVG)
- [ ] Data flow diagrams
- [ ] FPGA hardware architecture
- [ ] Network topology

---

### Issue #6: Translate Russian documentation to English
**Labels:** `documentation`, `i18n`
**Priority:** Medium

Several docs are in Russian:
- [ ] docs/academic/BITNET_MATHEMATICAL_PROOF.md (partial)
- [ ] docs/fpga/FPGA_NETWORK_WHITEPAPER.md (partial)
- [ ] Create English versions or bilingual docs

---

## Testing

### Issue #7: Add comprehensive test suite
**Labels:** `testing`
**Priority:** High

Current test coverage is incomplete:
- [ ] Unit tests for all VSA operations
- [ ] Integration tests for VIBEE compiler
- [ ] FPGA simulation tests
- [ ] Benchmark regression tests

---

### Issue #8: Set up CI/CD pipeline
**Labels:** `ci/cd`, `infrastructure`
**Priority:** High

Automate testing and releases:
- [ ] GitHub Actions for Zig build/test
- [ ] Automated benchmarks on PR
- [ ] Release automation
- [ ] Documentation deployment

---

## FPGA

### Issue #9: Add more FPGA board support
**Labels:** `fpga`, `enhancement`
**Priority:** Medium

Currently focused on Xilinx, expand to:
- [ ] Intel/Altera Stratix support
- [ ] Lattice ECP5 support
- [ ] Add board-specific constraints files

---

### Issue #10: Create FPGA bitstream CI
**Labels:** `fpga`, `ci/cd`
**Priority:** Low

Automate bitstream generation:
- [ ] Set up Vivado in CI (license issues)
- [ ] Or use open-source tools (Yosys/nextpnr)
- [ ] Publish pre-built bitstreams

---

## API & SDK

### Issue #11: Create Python bindings
**Labels:** `sdk`, `python`
**Priority:** High

Python is essential for ML integration:
- [ ] Create FFI interface in Zig
- [ ] Build Python wheel with ctypes/cffi
- [ ] Publish to PyPI
- [ ] Add examples for PyTorch/HuggingFace

---

### Issue #12: Create JavaScript/WASM bindings
**Labels:** `sdk`, `wasm`
**Priority:** Medium

For browser-based applications:
- [ ] Compile Trinity core to WASM
- [ ] Create npm package
- [ ] Add browser examples

---

## FPGA Network

### Issue #13: Implement Proof of Inference
**Labels:** `fpga-network`, `crypto`
**Priority:** High

Cryptographic verification of inference:
- [ ] Design proof protocol
- [ ] Implement in agent
- [ ] Add verification to coordinator

---

### Issue #14: Deploy testnet
**Labels:** `fpga-network`, `infrastructure`
**Priority:** Medium

Launch public testnet:
- [ ] Deploy coordinator server
- [ ] Create faucet for test $FPGA
- [ ] Onboard beta providers

---

## Performance

### Issue #15: Optimize SIMD for ARM (NEON)
**Labels:** `performance`, `arm`
**Priority:** Medium

Currently optimized for x86:
- [ ] Add NEON intrinsics
- [ ] Benchmark on Apple Silicon
- [ ] Benchmark on Raspberry Pi

---

### Issue #16: Implement JIT compilation for VM
**Labels:** `performance`, `jit`
**Priority:** Low

VM is currently interpreted:
- [ ] Design JIT architecture
- [ ] Implement hot path detection
- [ ] Add x86_64 code generation

---

## Community

### Issue #17: Create CONTRIBUTING.md
**Labels:** `documentation`, `community`
**Priority:** Medium

Guide for contributors:
- [ ] Code style guide
- [ ] PR process
- [ ] Issue templates
- [ ] Development setup

---

### Issue #18: Add examples directory
**Labels:** `documentation`, `examples`
**Priority:** Medium

Practical examples:
- [ ] Knowledge graph demo
- [ ] NLP classifier
- [ ] Sensor fusion
- [ ] FPGA inference demo

---

## Summary

| Priority | Count |
|----------|-------|
| High | 6 |
| Medium | 9 |
| Low | 3 |

**Recommended order:**
1. #7 (tests) - foundation for safe changes
2. #8 (CI/CD) - automate quality
3. #4 (API docs) - enable contributors
4. #11 (Python) - ML ecosystem integration
5. #1 (phi-engine) - complete migration
