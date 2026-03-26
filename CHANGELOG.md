# Changelog

All notable changes to Trinity will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- API implementation status document (docs/api_status.md)
- TODO triage report (docs/research/TODO_TRIAGE_REPORT_20260326.md)
- Version clarification for CLI vs Research Bundle versions

### Changed
- Clarified version numbering scheme (CLI v1.0.2 vs Research v5.2)
- Added HTTP API implementation status to README
- Improved documentation consistency

### Fixed
- Corrected misleading claims about HTTP API "not implemented"
- The HTTP API IS implemented in:
  - `src/vibeec/http_server.zig` (1059 LOC) - OpenAI-compatible `/v1/chat/completions`
  - `src/trinity_node/http_api.zig` (1359 LOC) - DePIN node endpoints
  - `src/api/unified_server.zig` (431 LOC) - Unified API registry

---

## [1.0.2] HEARTBEAT - 2026-03-03

### Added
- Issue templates for bug reports, feature requests, and documentation
- Pull request template with comprehensive checklist
- API reference documentation (docs/api_reference.md)
- Troubleshooting guide (docs/troubleshooting.md)
- Contributing guidelines (CONTRIBUTING.md)
- Code of conduct (CODE_OF_CONDUCT.md)
- Enhanced CI workflow for documentation checks
- Markdown link check configuration

### Changed
- Updated README.md with new documentation links
- Enhanced DOCUMENTATION_INDEX.md with new resources
- Updated patents.md with T-JEPA implemented status

---

## [1.0.2] HEARTBEAT - 2026-03-03

### Added
- Queen Trinity UI with 27-screen SwiftUI architecture
- TRI-27 ISA and binary format
- T-JEPA implementation (src/hslm/tjepa.zig, src/hslm/tjepa_trainer.zig)
- Rigid Process Framework for development workflow
- FPGA autoregressive ternary LLM on XC7A100T

### Fixed
- UART echo test Zig 0.15 compatibility
- Queen UI race condition with debounced binding

### Changed
- Migrated to Zig 0.15.x API
- Improved documentation structure

---

## [1.0.1] - 2026-02-XX

### Added
- Golden Chain pipeline v5.1
- Honeycomb cell system v30
- Phoenix self-regenerating system
- Faculty board (A2A agent communication)

### Fixed
- Various build issues with Zig 0.14.x

---

## [1.0.0] - 2026-01-XX

### Added
- Initial release of Trinity CLI
- VSA (Vector Symbolic Architecture) implementation
- Ternary Virtual Machine (VM)
- BitNet LLM inference engine (Firebird)
- VIBEE compiler for Zig/Verilog generation
- DePIN node with token staking
- MCP server integration
- 50+ CLI commands

### Architecture
- Core modules: src/vsa/, src/vm.zig, src/hybrid.zig
- Brain modules: 5 cortical modules with 156 tests
- FPGA toolchain: openXC7 (Yosys + nextpnr-xilinx)

### Documentation
- ARCHITECTURE.md
- AGENTS.md
- CLAUDE.md
- Initial README.md

---

## Links

- [GitHub Releases](https://github.com/gHashTag/trinity/releases)
- [Documentation Index](docs/DOCUMENTATION_INDEX.md)
- [Issue Tracker](https://github.com/gHashTag/trinity/issues)

---

*For older versions, see git history.*
