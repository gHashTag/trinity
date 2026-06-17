//! TRIOS Hybrid — Hybrid BigInt and Packed Trit FFI
//!
//! This crate provides FFI bindings for TRIOS Hybrid BigInt operations
//! and packed trit encoding/decoding.
//!
//! ## Features
//!
//! - **HybridBigInt**: Arbitrary precision balanced ternary arithmetic
//! - **Packed Trits**: Space-efficient trit encoding
//! - **BigInt Operations**: add, subtract, multiply, division
//! - **Conversions**: i64 ↔ BigInt, packed ↔ dense
//!
//! ## Symbol: `∓`
//!
//! ## Balanced Ternary Representation
//!
//! Each trit has value {-1, 0, +1}. A number is represented as:
//! ```
//! N = Σ(trit[i] × 3^i) for i = 0..n-1
//! ```
//!
//! No separate sign bit is needed — the sign is inherent in the representation.

use std::os::raw::{c_char, c_int, c_longlong};
use std::ptr;

/// Trit value: -1, 0, or +1
pub type Trit = i8;

/// Trit values
pub const TRIT_NEGATIVE: Trit = -1;
pub const TRIT_ZERO: Trit = 0;
pub const TRIT_POSITIVE: Trit = 1;

/// Maximum trits for BigInt (supports numbers up to 3^256 ≈ 10^122)
pub const MAX_TRITS: usize = 256;

/// SIMD width for trit operations
pub const SIMD_WIDTH: usize = 32;

/// Storage mode for HybridBigInt
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HybridStorageMode {
    /// Dense storage (one trit per byte)
    Dense = 0,
    /// Packed storage (2 trits per byte)
    Packed = 1,
    /// Hybrid storage (chunks of packed + dense)
    Hybrid = 2,
}

/// HybridBigInt — arbitrary precision balanced ternary number
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HybridBigInt {
    /// Trit data
    pub data: *mut Trit,
    /// Number of trits
    pub len: usize,
    /// Capacity
    pub capacity: usize,
    /// Storage mode
    pub mode: HybridStorageMode,
    /// Sign (-1, 0, +1)
    pub sign: i8,
}

/// Packed trit buffer (2 trits per byte)
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct PackedTritBuffer {
    /// Packed data (each byte = 2 trits)
    pub data: *mut u8,
    /// Number of bytes
    pub len: usize,
    /// Number of trits (may be odd)
    pub trit_count: usize,
}

/// BigInt operation result
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct BigIntResult {
    /// Result value
    pub value: HybridBigInt,
    /// Overflow flag
    pub overflow: bool,
    /// Success flag
    pub success: bool,
}

/// Create a new HybridBigInt
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_new(capacity: usize) -> *mut HybridBigInt {
    let _ = capacity;
    // TODO: Allocate BigInt in Zig
    ptr::null_mut()
}

/// Create a HybridBigInt from i64
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_from_i64(value: c_longlong) -> *mut HybridBigInt {
    let _ = value;
    // TODO: Call Zig fromI64
    ptr::null_mut()
}

/// Convert HybridBigInt to i64
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_to_i64(bigint: *const HybridBigInt) -> c_longlong {
    if bigint.is_null() {
        return 0;
    }
    // TODO: Call Zig toI64
    0
}

/// Free a HybridBigInt
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_free(bigint: *mut HybridBigInt) {
    if !bigint.is_null() {
        unsafe {
            if !(*bigint).data.is_null() {
                // TODO: Free data in Zig allocator
            }
            // TODO: Free BigInt struct
        }
    }
}

/// Clone a HybridBigInt
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_clone(
    bigint: *const HybridBigInt,
) -> *mut HybridBigInt {
    if bigint.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig clone operation
    ptr::null_mut()
}

/// Get number of trits
#[no_mangle]
pub unsafe extern "C" fn trios_hybrid_bigint_len(bigint: *const HybridBigInt) -> usize {
    if bigint.is_null() {
        0
    } else {
        (*bigint).len
    }
}

/// Get storage mode
#[no_mangle]
pub unsafe extern "C" fn trios_hybrid_bigint_mode(bigint: *const HybridBigInt) -> HybridStorageMode {
    if bigint.is_null() {
        HybridStorageMode::Dense
    } else {
        (*bigint).mode
    }
}

/// Add two BigInts
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_add(
    a: *const HybridBigInt,
    b: *const HybridBigInt,
    result: *mut BigIntResult,
) -> c_int {
    if a.is_null() || b.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig add operation
    unsafe {
        (*result).success = false;
        (*result).overflow = false;
    }
    0
}

/// Subtract two BigInts (a - b)
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_sub(
    a: *const HybridBigInt,
    b: *const HybridBigInt,
    result: *mut BigIntResult,
) -> c_int {
    if a.is_null() || b.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig sub operation
    unsafe {
        (*result).success = false;
        (*result).overflow = false;
    }
    0
}

/// Multiply two BigInts
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_mul(
    a: *const HybridBigInt,
    b: *const HybridBigInt,
    result: *mut BigIntResult,
) -> c_int {
    if a.is_null() || b.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig mul operation
    unsafe {
        (*result).success = false;
        (*result).overflow = false;
    }
    0
}

/// Divide two BigInts (a / b)
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_div(
    a: *const HybridBigInt,
    b: *const HybridBigInt,
    quotient: *mut BigIntResult,
    remainder: *mut BigIntResult,
) -> c_int {
    if a.is_null() || b.is_null() || quotient.is_null() || remainder.is_null() {
        return -1;
    }
    // TODO: Call Zig div operation
    unsafe {
        (*quotient).success = false;
        (*remainder).success = false;
    }
    0
}

/// Compare two BigInts
///
/// Returns: -1 if a < b, 0 if a == b, 1 if a > b
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_cmp(
    a: *const HybridBigInt,
    b: *const HybridBigInt,
) -> c_int {
    if a.is_null() || b.is_null() {
        return 0;
    }
    // TODO: Call Zig cmp operation
    0
}

/// Check if BigInt is zero
#[no_mangle]
pub unsafe extern "C" fn trios_hybrid_bigint_is_zero(bigint: *const HybridBigInt) -> bool {
    if bigint.is_null() {
        return true;
    }
    // TODO: Call Zig isZero
    false
}

/// Check if BigInt is negative
#[no_mangle]
pub unsafe extern "C" fn trios_hybrid_bigint_is_negative(bigint: *const HybridBigInt) -> bool {
    if bigint.is_null() {
        return false;
    }
    // TODO: Call Zig isNegative
    (*bigint).sign < 0
}

/// Negate a BigInt
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_neg(
    bigint: *const HybridBigInt,
    result: *mut BigIntResult,
) -> c_int {
    if bigint.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig neg operation
    unsafe {
        (*result).success = false;
    }
    0
}

/// Absolute value of BigInt
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_abs(
    bigint: *const HybridBigInt,
    result: *mut BigIntResult,
) -> c_int {
    if bigint.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig abs operation
    unsafe {
        (*result).success = false;
    }
    0
}

/// Left shift (multiply by 3^n)
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_shl(
    bigint: *const HybridBigInt,
    _n: usize,
    result: *mut BigIntResult,
) -> c_int {
    if bigint.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig shl operation
    unsafe {
        (*result).success = false;
    }
    0
}

/// Right shift (divide by 3^n)
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_shr(
    bigint: *const HybridBigInt,
    _n: usize,
    result: *mut BigIntResult,
) -> c_int {
    if bigint.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig shr operation
    unsafe {
        (*result).success = false;
    }
    0
}

/// Create a packed trit buffer
#[no_mangle]
pub extern "C" fn trios_hybrid_packed_new(_trit_count: usize) -> *mut PackedTritBuffer {
    // TODO: Allocate packed buffer in Zig
    ptr::null_mut()
}

/// Free a packed trit buffer
#[no_mangle]
pub extern "C" fn trios_hybrid_packed_free(buffer: *mut PackedTritBuffer) {
    if !buffer.is_null() {
        unsafe {
            if !(*buffer).data.is_null() {
                // TODO: Free data in Zig allocator
            }
            // TODO: Free buffer struct
        }
    }
}

/// Encode dense trits to packed format
#[no_mangle]
pub extern "C" fn trios_hybrid_encode_pack(
    trits: *const Trit,
    trit_count: usize,
    packed: *mut PackedTritBuffer,
) -> c_int {
    if trits.is_null() || packed.is_null() {
        return -1;
    }
    // TODO: Call Zig encodePack
    0
}

/// Decode packed trits to dense format
#[no_mangle]
pub extern "C" fn trios_hybrid_decode_pack(
    packed: *const PackedTritBuffer,
    trits: *mut Trit,
    trit_count: usize,
) -> c_int {
    if packed.is_null() || trits.is_null() {
        return -1;
    }
    // TODO: Call Zig decodePack
    0
}

/// Get packed buffer trit count
#[no_mangle]
pub unsafe extern "C" fn trios_hybrid_packed_trit_count(buffer: *const PackedTritBuffer) -> usize {
    if buffer.is_null() {
        0
    } else {
        (*buffer).trit_count
    }
}

/// Get packed buffer byte count
#[no_mangle]
pub unsafe extern "C" fn trios_hybrid_packed_byte_count(buffer: *const PackedTritBuffer) -> usize {
    if buffer.is_null() {
        0
    } else {
        (*buffer).len
    }
}

/// Convert BigInt to packed format
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_to_packed(
    bigint: *const HybridBigInt,
    packed: *mut PackedTritBuffer,
) -> c_int {
    if bigint.is_null() || packed.is_null() {
        return -1;
    }
    // TODO: Call Zig toPacked operation
    0
}

/// Convert packed format to BigInt
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_from_packed(
    packed: *const PackedTritBuffer,
) -> *mut HybridBigInt {
    if packed.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig fromPacked operation
    ptr::null_mut()
}

/// Set storage mode
#[no_mangle]
pub extern "C" fn trios_hybrid_bigint_set_mode(
    bigint: *mut HybridBigInt,
    mode: HybridStorageMode,
) -> c_int {
    if bigint.is_null() {
        return -1;
    }
    unsafe {
        (*bigint).mode = mode;
    }
    0
}

/// Get last error message
#[no_mangle]
pub extern "C" fn trios_hybrid_last_error() -> *const c_char {
    // TODO: Return last error from Zig context
    ptr::null()
}

/// Get version
#[no_mangle]
pub extern "C" fn trios_hybrid_version() -> *const c_char {
    "0.1.0\0".as_ptr() as *const c_char
}

/// Get build info
#[no_mangle]
pub extern "C" fn trios_hybrid_build_info() -> *const c_char {
    "trios-hybrid 0.1.0 (FFI wrapper for Zig Hybrid BigInt)\0".as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trit_constants() {
        assert_eq!(TRIT_NEGATIVE, -1);
        assert_eq!(TRIT_ZERO, 0);
        assert_eq!(TRIT_POSITIVE, 1);
    }

    #[test]
    fn test_max_trits() {
        assert_eq!(MAX_TRITS, 256);
    }

    #[test]
    fn test_simd_width() {
        assert_eq!(SIMD_WIDTH, 32);
    }

    #[test]
    fn test_storage_mode() {
        assert_eq!(HybridStorageMode::Dense as i32, 0);
        assert_eq!(HybridStorageMode::Packed as i32, 1);
        assert_eq!(HybridStorageMode::Hybrid as i32, 2);
    }

    #[test]
    fn test_null_checks() {
        unsafe {
            assert_eq!(trios_hybrid_bigint_len(ptr::null()), 0);
            assert_eq!(
                trios_hybrid_bigint_mode(ptr::null()),
                HybridStorageMode::Dense
            );
            assert!(trios_hybrid_bigint_is_zero(ptr::null()));
            assert!(!trios_hybrid_bigint_is_negative(ptr::null()));
        }
    }

    #[test]
    fn test_version() {
        let version = unsafe {
            std::ffi::CStr::from_ptr(trios_hybrid_version())
        };
        assert_eq!(version.to_str().unwrap(), "0.1.0");
    }

    #[test]
    fn test_build_info() {
        let info = unsafe {
            std::ffi::CStr::from_ptr(trios_hybrid_build_info())
        };
        let info_str = info.to_str().unwrap();
        assert!(info_str.contains("trios-hybrid"));
        assert!(info_str.contains("0.1.0"));
    }
}
