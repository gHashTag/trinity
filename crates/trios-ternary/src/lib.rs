//! TRIOS Ternary — Ternary Logic and BitLinear FFI
//!
//! This crate provides FFI bindings for TRIOS ternary operations
//! and BitLinear quantization for neural networks.
//!
//! ## Features
//!
//! - **Ternary Logic**: AND, OR, NOT, implication, consensus, majority
//! - **Tekum Arithmetic**: Balanced ternary number system
//! - **BitLinear**: Ternary quantization for neural networks
//! - **Trinity Metrics**: Sacred scoring functions
//!
//! ## Symbol: `∓`

use std::os::raw::{c_char, c_float, c_int};

/// Trit value: -1, 0, or +1
pub type Trit = i8;

pub const TRIT_NEGATIVE: Trit = -1;
pub const TRIT_ZERO: Trit = 0;
pub const TRIT_POSITIVE: Trit = 1;

/// Tekum buffer size (27 trits for large numbers)
pub const TEKUM_SIZE: usize = 27;

/// Dense ternary vector
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct TernaryVector {
    pub data: *mut Trit,
    pub len: usize,
}

/// BitLinear quantized weight
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct BitLinearWeight {
    /// Quantized value (-1, 0, or +1)
    pub value: Trit,
    /// Scale factor for dequantization
    pub scale: c_float,
}

/// BitLinear layer configuration
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct BitLinearConfig {
    /// Input size
    pub input_size: usize,
    /// Output size
    pub output_size: usize,
    /// Quantization threshold
    pub threshold: c_float,
}

/// Ternary AND: min(a, b)
#[no_mangle]
pub extern "C" fn trios_ternary_and(a: Trit, b: Trit) -> Trit {
    a.min(b)
}

/// Ternary OR: max(a, b)
#[no_mangle]
pub extern "C" fn trios_ternary_or(a: Trit, b: Trit) -> Trit {
    a.max(b)
}

/// Ternary NOT: negation
#[no_mangle]
pub extern "C" fn trios_ternary_not(a: Trit) -> Trit {
    -a
}

/// Ternary implication: OR(NOT(a), b)
#[no_mangle]
pub extern "C" fn trios_ternary_implies(a: Trit, b: Trit) -> Trit {
    trios_ternary_or(trios_ternary_not(a), b)
}

/// Ternary consensus: a if a == b, else 0
#[no_mangle]
pub extern "C" fn trios_ternary_consensus(a: Trit, b: Trit) -> Trit {
    if a == b { a } else { TRIT_ZERO }
}

/// Ternary majority vote of three trits
#[no_mangle]
pub extern "C" fn trios_ternary_majority(a: Trit, b: Trit, c: Trit) -> Trit {
    let ab = trios_ternary_and(a, b);
    let bc = trios_ternary_and(b, c);
    let ac = trios_ternary_and(a, c);
    trios_ternary_or(ab, trios_ternary_or(bc, ac))
}

/// Convert trit to confidence [0.0, 1.0]
#[no_mangle]
pub extern "C" fn trios_ternary_to_confidence(t: Trit) -> c_float {
    (t + 1) as c_float / 2.0
}

/// Convert confidence to trit
#[no_mangle]
pub extern "C" fn trios_ternary_from_confidence(c: c_float) -> Trit {
    if c < 0.33 {
        TRIT_NEGATIVE
    } else if c > 0.66 {
        TRIT_POSITIVE
    } else {
        TRIT_ZERO
    }
}

/// Tekum: Convert integer to balanced ternary
#[no_mangle]
pub extern "C" fn trios_ternary_tekum_from_int(n: c_int, buf: *mut Trit) {
    if buf.is_null() {
        return;
    }
    unsafe {
        let mut val = n;
        for i in 0..TEKUM_SIZE {
            let t = if val == 0 {
                TRIT_ZERO
            } else {
                let rem = ((val + 1) % 3) - 1;
                val = (val - rem) / 3;
                rem as Trit
            };
            *buf.add(i) = t;
        }
    }
}

/// Tekum: Convert balanced ternary to integer
#[no_mangle]
pub extern "C" fn trios_ternary_tekum_to_int(buf: *const Trit) -> c_int {
    if buf.is_null() {
        return 0;
    }
    unsafe {
        let mut result: c_int = 0;
        let mut power: c_int = 1;
        for i in 0..TEKUM_SIZE {
            result += (*buf.add(i) as c_int) * power;
            power *= 3;
        }
        result
    }
}

/// Quantize float to trit using threshold
#[no_mangle]
pub extern "C" fn trios_ternary_quantize(x: c_float, threshold: c_float) -> Trit {
    if x > threshold {
        TRIT_POSITIVE
    } else if x < -threshold {
        TRIT_NEGATIVE
    } else {
        TRIT_ZERO
    }
}

/// Dequantize trit to float with scale
#[no_mangle]
pub extern "C" fn trios_ternary_dequantize(t: Trit, scale: c_float) -> c_float {
    t as c_float * scale
}

/// Quantize weights for BitLinear layer
#[no_mangle]
pub extern "C" fn trios_ternary_quantize_weights(
    weights: *const c_float,
    count: usize,
    threshold: c_float,
    out: *mut Trit,
) {
    if weights.is_null() || out.is_null() {
        return;
    }
    unsafe {
        for i in 0..count {
            *out.add(i) = trios_ternary_quantize(*weights.add(i), threshold);
        }
    }
}

/// BitLinear forward pass: y = sign(W) * scale * x
#[no_mangle]
pub extern "C" fn trios_ternary_bitlinear_forward(
    weights: *const Trit,
    scales: *const c_float,
    input: *const c_float,
    output: *mut c_float,
    n: usize,
) {
    if weights.is_null() || scales.is_null() || input.is_null() || output.is_null() {
        return;
    }
    unsafe {
        for i in 0..n {
            *output.add(i) = *weights.add(i) as c_float * *scales.add(i) * *input.add(i);
        }
    }
}

/// Create ternary vector
#[no_mangle]
pub extern "C" fn trios_ternary_vector_new(len: usize) -> *mut TernaryVector {
    // TODO: Allocate in Zig
    std::ptr::null_mut()
}

/// Free ternary vector
#[no_mangle]
pub extern "C" fn trios_ternary_vector_free(vec: *mut TernaryVector) {
    if !vec.is_null() {
        unsafe {
            if !(*vec).data.is_null() {
                // TODO: Free data
            }
            // TODO: Free vector
        }
    }
}

/// Get version
#[no_mangle]
pub extern "C" fn trios_ternary_version() -> *const c_char {
    "0.1.0\0".as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_and() {
        assert_eq!(trios_ternary_and(TRIT_NEGATIVE, TRIT_ZERO), TRIT_NEGATIVE);
        assert_eq!(trios_ternary_and(TRIT_NEGATIVE, TRIT_POSITIVE), TRIT_NEGATIVE);
        assert_eq!(trios_ternary_and(TRIT_ZERO, TRIT_POSITIVE), TRIT_ZERO);
        assert_eq!(trios_ternary_and(TRIT_POSITIVE, TRIT_POSITIVE), TRIT_POSITIVE);
    }

    #[test]
    fn test_or() {
        assert_eq!(trios_ternary_or(TRIT_NEGATIVE, TRIT_ZERO), TRIT_ZERO);
        assert_eq!(trios_ternary_or(TRIT_NEGATIVE, TRIT_POSITIVE), TRIT_POSITIVE);
        assert_eq!(trios_ternary_or(TRIT_ZERO, TRIT_POSITIVE), TRIT_POSITIVE);
    }

    #[test]
    fn test_not() {
        assert_eq!(trios_ternary_not(TRIT_NEGATIVE), TRIT_POSITIVE);
        assert_eq!(trios_ternary_not(TRIT_ZERO), TRIT_ZERO);
        assert_eq!(trios_ternary_not(TRIT_POSITIVE), TRIT_NEGATIVE);
    }

    #[test]
    fn test_consensus() {
        assert_eq!(trios_ternary_consensus(TRIT_POSITIVE, TRIT_POSITIVE), TRIT_POSITIVE);
        assert_eq!(trios_ternary_consensus(TRIT_POSITIVE, TRIT_NEGATIVE), TRIT_ZERO);
    }

    #[test]
    fn test_tekum_roundtrip() {
        let mut buf = [0i8; TEKUM_SIZE];
        trios_ternary_tekum_from_int(42, buf.as_mut_ptr());
        assert_eq!(trios_ternary_tekum_to_int(buf.as_ptr()), 42);

        trios_ternary_tekum_from_int(-17, buf.as_mut_ptr());
        assert_eq!(trios_ternary_tekum_to_int(buf.as_ptr()), -17);

        trios_ternary_tekum_from_int(0, buf.as_mut_ptr());
        assert_eq!(trios_ternary_tekum_to_int(buf.as_ptr()), 0);
    }

    #[test]
    fn test_quantize() {
        assert_eq!(trios_ternary_quantize(0.8, 0.5), TRIT_POSITIVE);
        assert_eq!(trios_ternary_quantize(-0.8, 0.5), TRIT_NEGATIVE);
        assert_eq!(trios_ternary_quantize(0.3, 0.5), TRIT_ZERO);
    }

    #[test]
    fn test_dequantize() {
        assert!((trios_ternary_dequantize(TRIT_POSITIVE, 1.0) - 1.0).abs() < 1e-6);
        assert!((trios_ternary_dequantize(TRIT_NEGATIVE, 1.0) + 1.0).abs() < 1e-6);
    }
}
