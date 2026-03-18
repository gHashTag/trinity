# Changelog

All notable changes to NeoDetect Anti-Detect Browser Extension.

## [2.0.0] - 2026-02-04

### Added
- WASM-powered fingerprint engine compiled from Zig
- OS emulation: Windows 10/11, macOS Sonoma, Linux Ubuntu
- Hardware profiles: Intel i5/i7/i9, AMD Ryzen 5/7/9, Apple M1/M2/M3
- GPU spoofing: NVIDIA RTX 3060/4070/4090, AMD RX 6700/7900, Intel UHD 770, Apple GPU
- Profile management with save/load/import/export
- Protection presets: Paranoid, Balanced, Minimal
- Detection risk indicator with real-time scoring
- AI-powered fingerprint evolution
- WebRTC IP leak protection
- Battery API spoofing
- Bluetooth API blocking
- Permissions API spoofing
- Storage API spoofing
- Client Hints spoofing
- Deterministic fingerprint recreation from seed

### Changed
- Complete UI redesign with modern popup interface
- Improved canvas noise algorithm with ternary noise
- Enhanced WebGL vendor/renderer spoofing
- Better audio context fingerprint protection

### Technical
- Migrated to Chrome Manifest V3
- WASM module for high-performance fingerprint generation
- Specification-driven development with `.vibee` files

## [1.1.0] - 2026-01-15

### Added
- WebGL fingerprint protection
- Audio context fingerprint protection

### Changed
- Improved canvas noise algorithm
- Performance optimizations

### Fixed
- Memory leak in content script
- Popup state persistence

## [1.0.0] - 2026-01-01

### Added
- Initial release
- Canvas fingerprint protection with noise injection
- Navigator spoofing (platform, userAgent, hardwareConcurrency)
- Basic popup UI with enable/disable toggle
- Chrome Manifest V3 support

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
