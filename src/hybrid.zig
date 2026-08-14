//! Совместимостный слой для перенесённого src/hybrid.zig.
//! Типы HybridBigInt/Trit и константы доступны через фасад `zig-hdc-vsa`.

const hdc = @import("zig-hdc-vsa");

pub const HybridBigInt = hdc.HybridBigInt;
pub const Trit = hdc.Trit;
pub const MAX_TRITS = hdc.MAX_TRITS;
pub const Vec32i8 = hdc.Vec32i8;
pub const SIMD_WIDTH = hdc.SIMD_WIDTH;
