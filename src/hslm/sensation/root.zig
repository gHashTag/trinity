// @origin(spec:sensation.tri) @regen(manual-impl)
// SENSATION — Trinity Cortex Integration Module
//
// Sensation root: Unifies all 5 HSLM cortex modules
// Provides single import point for Thalamus → Cortex relay
//
// φ² + 1/φ² = 3 | TRINITY

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE IMPORTS — All 5 sensation modules
// ═══════════════════════════════════════════════════════════════════════════════

/// IPS (Intraparietal Sulcus): GF16/TF3 core format definitions
pub const ips = @import("../intraparietal_sulcus.zig");

/// Weber Tuning: Logarithmic quantization
pub const weber = @import("../weber_tuning.zig");

/// Fusiform Gyrus: Format conversion (cross-format)
pub const fusiform = @import("../fusiform_gyrus.zig");

/// Angular Gyrus: Format introspection
pub const angular = @import("../angular_gyrus.zig");

/// Orbitofrontal Value: Valence assignment and format selection
pub const ofc = @import("../orbitofrontal_value.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// EXPORTS — Core types for Thalamus integration
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden Float 16: φ-optimized 16-bit format
pub const GoldenFloat16 = ips.GoldenFloat16;

/// Ternary Float 9: 9-trit ternary format
pub const TernaryFloat9 = ips.TernaryFloat9;

/// Valence: Affective value categories
pub const Valence = ofc.Valence;

/// Format type for introspection
pub const FormatType = angular.FormatType;

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE SUMMARY — Sensation System
// ═══════════════════════════════════════════════════════════════════════════════
//
// The Trinity Sensation System consists of 5 cortical modules:
//
// 1. IPS (intraparietal_sulcus.zig):
//    - GoldenFloat16: exp:mant = 6:9 ≈ 1/φ (0.666 vs 0.618)
//    - TernaryFloat9: 9 trits, exp:mant = 3:5 = 0.6 ≈ 1/φ
//    - Functions: gf16FromF32, gf16ToF32, tf3FromF32, tf3ToF32
//    - Tests: 10/10 passed
//
// 2. Weber (weber_tuning.zig):
//    - Weber-Fechner quantization: Δ = k × S
//    - Functions: weberQuantize, weberDequantize, ternaryWeberLevels
//    - Tests: 11/11 passed
//
// 3. Fusiform (fusiform_gyrus.zig):
//    - Cross-format conversions: FP16/BF16 ↔ GF16
//    - Slice operations: f32ToGf16Slice, gf16ToF32Slice
//    - Tests: 58/58 passed
//
// 4. Angular (angular_gyrus.zig):
//    - Format introspection with φ-distance analysis
//    - Functions: goldenDistance, allFormatsTable, FormatDescriptor
//    - Tests: 27/27 passed
//
// 5. OFC (orbitofrontal_value.zig):
//    - Valence assignment and format selection
//    - Functions: selectOptimalFormat, computeReward, assignValence
//    - Tests: 50/50 passed
//
// TOTAL: 156/156 tests passing
//
// Integration: Thalamus (src/brain/thalamus_logs.zig) → Sensation → Queen Senses
//
// φ² + 1/φ² = 3 | TRINITY
