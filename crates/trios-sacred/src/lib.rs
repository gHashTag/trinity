//! TRIOS Sacred — Sacred Geometry and Golden Ratio FFI
//!
//! This crate provides FFI bindings for TRIOS sacred geometry constants
//! and mathematical operations based on the golden ratio φ.
//!
//! ## Features
//!
//! - **Golden Ratio Constants**: φ, φ², 1/φ, 1/φ²
//! - **Mathematical Constants**: π, e, √2, √3, √5
//! - **Fibonacci Numbers**: nth Fibonacci number, golden ratio approximation
//! - **Continued Fractions**: φ as continued fraction
//! - **Trinity Identity**: φ² + 1/φ² = 3
//!
//! ## Symbol: `✦`
//!
//! ## Trinity Identity
//!
//! The fundamental identity:
//! ```
//! φ² + 1/φ² = 3
//! ```
//!
//! Where φ = (1 + √5) / 2 ≈ 1.618...

use std::os::raw::{c_char, c_double, c_long};

/// Golden ratio φ = (1 + √5) / 2
pub const PHI: c_double = 1.6180339887498948482;

/// φ² = φ + 1
pub const PHI_SQ: c_double = 2.6180339887498948482;

/// 1/φ = φ - 1
pub const PHI_INV: c_double = 0.6180339887498948482;

/// 1/φ² = 2 - φ
pub const PHI_INV_SQ: c_double = 0.3819660112501051518;

/// π
pub const PI: c_double = 3.14159265358979323846;

/// e (Euler's number)
pub const E: c_double = 2.71828182845904523536;

/// √2
pub const SQRT2: c_double = 1.4142135623730950488;

/// √3
pub const SQRT3: c_double = 1.7320508075688772935;

/// √5
pub const SQRT5: c_double = 2.2360679774997896964;

/// φ² + 1/φ² = 3 = TRINITY
pub const TRINITY: c_long = 3;

/// γ (Euler-Mascheroni constant)
pub const GAMMA: c_double = 0.5772156649015328606;

/// ln(φ)
pub const LN_PHI: c_double = 0.48121182505960347;

/// Phoenix constant = φ⁴
pub const PHOENIX: c_double = 6.8541019662496845;

/// Golden angle in degrees = 360/φ²
pub const GOLDEN_ANGLE_DEG: c_double = 137.50776405003785;

/// Golden angle in radians = 2π/φ²
pub const GOLDEN_ANGLE_RAD: c_double = 2.3999632297286533;

/// α_φ = φ³/2 ≈ 0.118033988749895
pub const ALPHA_PHI: c_double = 0.118033988749895;

/// Fibonacci numbers context (opaque)
#[repr(C)]
pub struct FibonacciContext {
    _private: [u8; 0],
}

/// Continued fraction approximation result
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ContinuedFraction {
    /// Numerator
    pub numerator: c_long,
    /// Denominator
    pub denominator: c_long,
    /// Approximation value
    pub value: c_double,
    /// Error from actual value
    pub error: c_double,
}

/// Get φ (golden ratio)
#[no_mangle]
pub extern "C" fn trios_sacred_phi() -> c_double {
    PHI
}

/// Get φ²
#[no_mangle]
pub extern "C" fn trios_sacred_phi_sq() -> c_double {
    PHI_SQ
}

/// Get 1/φ (phi inverse)
#[no_mangle]
pub extern "C" fn trios_sacred_phi_inv() -> c_double {
    PHI_INV
}

/// Get 1/φ²
#[no_mangle]
pub extern "C" fn trios_sacred_phi_inv_sq() -> c_double {
    PHI_INV_SQ
}

/// Get α_φ = φ³/2
#[no_mangle]
pub extern "C" fn trios_sacred_alpha_phi() -> c_double {
    ALPHA_PHI
}

/// Validate Trinity identity: φ² + 1/φ² = 3
///
/// Returns true if identity holds within floating point tolerance.
#[no_mangle]
pub extern "C" fn trios_sacred_validate_trinity() -> bool {
    (PHI_SQ + PHI_INV_SQ - 3.0).abs() < 1e-15
}

/// Calculate nth Fibonacci number
#[no_mangle]
pub extern "C" fn trios_sacred_fibonacci(n: u32) -> u64 {
    // Binet's formula: F(n) = (φ^n - (1-φ)^n) / √5
    // For n ≤ 93, fits in u64
    if n <= 1 {
        return n as u64;
    }

    let phi_f = PHI as f64;
    let psi_f = (1.0 - PHI) as f64; // = -1/φ
    let sqrt5_f = SQRT5 as f64;

    let fn_f = (phi_f.powi(n as i32) - psi_f.powi(n as i32)) / sqrt5_f;
    fn_f.round() as u64
}

/// Create Fibonacci context for sequence generation
#[no_mangle]
pub extern "C" fn trios_sacred_fibonacci_context_new() -> *mut FibonacciContext {
    // TODO: Allocate Zig Fibonacci context
    std::ptr::null_mut()
}

/// Free Fibonacci context
#[no_mangle]
pub extern "C" fn trios_sacred_fibonacci_context_free(_ctx: *mut FibonacciContext) {
    // TODO: Free Zig context
}

/// Get next Fibonacci number from context
#[no_mangle]
pub extern "C" fn trios_sacred_fibonacci_next(
    _ctx: *mut FibonacciContext,
) -> u64 {
    // TODO: Get next from Zig context
    0
}

/// Reset Fibonacci context
#[no_mangle]
pub extern "C" fn trios_sacred_fibonacci_reset(_ctx: *mut FibonacciContext) {
    // TODO: Reset Zig context
}

/// Calculate φ^n (phi power)
#[no_mangle]
pub extern "C" fn trios_sacred_phi_power(n: i32) -> c_double {
    PHI.powi(n)
}

/// Calculate φ^(-n) (phi inverse power)
#[no_mangle]
pub extern "C" fn trios_sacred_phi_inv_power(n: i32) -> c_double {
    PHI_INV.powi(n)
}

/// Calculate continued fraction approximation of φ
///
/// After n iterations, returns numerator/denominator approximation.
#[no_mangle]
pub extern "C" fn trios_sacred_phi_cfrac(n: u32) -> ContinuedFraction {
    // φ = [1; 1, 1, 1, ...] (all ones)
    // Convergents are ratios of consecutive Fibonacci numbers
    let fn_1 = trios_sacred_fibonacci(n + 1);
    let fn_0 = trios_sacred_fibonacci(n);

    let value = fn_1 as c_double / fn_0 as c_double;
    let error = (value - PHI).abs();

    ContinuedFraction {
        numerator: fn_1 as c_long,
        denominator: fn_0 as c_long,
        value,
        error,
    }
}

/// Get continued fraction coefficients for φ
///
/// Returns array of length `n` with all ones (φ has all-ones CF).
#[no_mangle]
pub extern "C" fn trios_sacred_phi_cfrac_coeffs(
    n: usize,
    coeffs: *mut i32,
) -> i32 {
    if coeffs.is_null() || n == 0 {
        return -1;
    }
    // φ = [1; 1, 1, 1, ...]
    unsafe {
        for i in 0..n {
            *coeffs.add(i) = 1;
        }
    }
    0
}

/// Calculate golden ratio from continued fraction coefficients
#[no_mangle]
pub extern "C" fn trios_sacred_cfrac_to_phi(
    coeffs: *const i32,
    n: usize,
) -> c_double {
    if coeffs.is_null() || n == 0 {
        return 0.0;
    }
    unsafe {
        // Evaluate continued fraction from right to left
        let mut result = *coeffs.add(n - 1) as c_double;
        for i in (0..n - 1).rev() {
            result = *coeffs.add(i) as c_double + 1.0 / result;
        }
        result
    }
}

/// Golden angle in degrees
#[no_mangle]
pub extern "C" fn trios_sacred_golden_angle_deg() -> c_double {
    GOLDEN_ANGLE_DEG
}

/// Golden angle in radians
#[no_mangle]
pub extern "C" fn trios_sacred_golden_angle_rad() -> c_double {
    GOLDEN_ANGLE_RAD
}

/// Phoenix constant (φ⁴)
#[no_mangle]
pub extern "C" fn trios_sacred_phoenix() -> c_double {
    PHOENIX
}

/// Get all mathematical constants as a struct
#[no_mangle]
pub extern "C" fn trios_sacred_constants() -> SacredConstants {
    SacredConstants {
        phi: PHI,
        phi_sq: PHI_SQ,
        phi_inv: PHI_INV,
        phi_inv_sq: PHI_INV_SQ,
        alpha_phi: ALPHA_PHI,
        pi: PI,
        e: E,
        sqrt2: SQRT2,
        sqrt3: SQRT3,
        sqrt5: SQRT5,
        gamma: GAMMA,
        ln_phi: LN_PHI,
        phoenix: PHOENIX,
        trinity: TRINITY,
        golden_angle_deg: GOLDEN_ANGLE_DEG,
        golden_angle_rad: GOLDEN_ANGLE_RAD,
    }
}

/// All sacred constants in one struct
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct SacredConstants {
    pub phi: c_double,
    pub phi_sq: c_double,
    pub phi_inv: c_double,
    pub phi_inv_sq: c_double,
    pub alpha_phi: c_double,
    pub pi: c_double,
    pub e: c_double,
    pub sqrt2: c_double,
    pub sqrt3: c_double,
    pub sqrt5: c_double,
    pub gamma: c_double,
    pub ln_phi: c_double,
    pub phoenix: c_double,
    pub trinity: c_long,
    pub golden_angle_deg: c_double,
    pub golden_angle_rad: c_double,
}

/// Get last error
#[no_mangle]
pub extern "C" fn trios_sacred_last_error() -> *const c_char {
    std::ptr::null()
}

/// Get version
#[no_mangle]
pub extern "C" fn trios_sacred_version() -> *const c_char {
    "0.1.0\0".as_ptr() as *const c_char
}

/// Get build info
#[no_mangle]
pub extern "C" fn trios_sacred_build_info() -> *const c_char {
    "trios-sacred 0.1.0 (FFI wrapper for Zig Sacred Geometry)\0".as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_phi() {
        assert!((PHI - 1.618033988749895).abs() < 1e-12);
    }

    #[test]
    fn test_phi_sq() {
        assert!((PHI_SQ - 2.618033988749895).abs() < 1e-12);
    }

    #[test]
    fn test_phi_inv() {
        assert!((PHI_INV - 0.6180339887498949).abs() < 1e-12);
    }

    #[test]
    fn test_trinity_identity() {
        assert!(trios_sacred_validate_trinity());
        assert!((PHI_SQ + PHI_INV_SQ - 3.0).abs() < 1e-15);
    }

    #[test]
    fn test_fibonacci() {
        assert_eq!(trios_sacred_fibonacci(0), 0);
        assert_eq!(trios_sacred_fibonacci(1), 1);
        assert_eq!(trios_sacred_fibonacci(2), 1);
        assert_eq!(trios_sacred_fibonacci(3), 2);
        assert_eq!(trios_sacred_fibonacci(10), 55);
        assert_eq!(trios_sacred_fibonacci(20), 6765);
    }

    #[test]
    fn test_phi_power() {
        assert!((trios_sacred_phi_power(2) - PHI_SQ).abs() < 1e-12);
        assert!((trios_sacred_phi_power(0) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn test_phi_cfrac() {
        let cf = trios_sacred_phi_cfrac(5);
        // F(6)/F(5) = 8/5 = 1.6
        assert_eq!(cf.numerator, 8);
        assert_eq!(cf.denominator, 5);
        assert!((cf.value - 1.6).abs() < 1e-10);
        // Error should be small
        assert!(cf.error < 0.02);
    }

    #[test]
    fn test_cfrac_coeffs() {
        let mut coeffs = [0i32; 10];
        let result = trios_sacred_phi_cfrac_coeffs(10, coeffs.as_mut_ptr());
        assert_eq!(result, 0);
        // All coefficients should be 1 for φ
        for &c in &coeffs {
            assert_eq!(c, 1);
        }
    }

    #[test]
    fn test_cfrac_to_phi() {
        let coeffs = [1i32; 10];
        let result = trios_sacred_cfrac_to_phi(coeffs.as_ptr(), 10);
        // Should be close to φ
        assert!((result - PHI).abs() < 0.01);
    }

    #[test]
    fn test_golden_angle() {
        let deg = trios_sacred_golden_angle_deg();
        assert!((deg - 137.50776405003785).abs() < 1e-10);

        let rad = trios_sacred_golden_angle_rad();
        assert!((rad - 2.3999632297286533).abs() < 1e-10);
    }

    #[test]
    fn test_constants_struct() {
        let consts = trios_sacred_constants();
        assert!((consts.phi - PHI).abs() < 1e-12);
        assert_eq!(consts.trinity, TRINITY);
    }

    #[test]
    fn test_version() {
        let version = unsafe {
            std::ffi::CStr::from_ptr(trios_sacred_version())
        };
        assert_eq!(version.to_str().unwrap(), "0.1.0");
    }

    #[test]
    fn test_build_info() {
        let info = unsafe {
            std::ffi::CStr::from_ptr(trios_sacred_build_info())
        };
        let info_str = info.to_str().unwrap();
        assert!(info_str.contains("trios-sacred"));
        assert!(info_str.contains("0.1.0"));
    }
}
