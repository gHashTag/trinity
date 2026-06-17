//! TRIOS Validation — Schema Validation and Conformance Checking FFI
//!
//! This crate provides FFI bindings for TRIOS validation operations including
//! schema validation, input sanitization, range checking, and conformance
//! vector verification.
//!
//! ## Features
//!
//! - **Schema Validation**: Validate data against predefined schemas
//! - **Range Checking**: Numeric range and bounds validation
//! - **Pattern Matching**: String pattern validation
//! - **Conformance Vectors**: Verify sacred physics and numeric conformance
//! - **Validation Pipeline**: Chain multiple validators together
//!
//! ## Symbol: `✓`

use std::os::raw::{c_char, c_double, c_int, c_long};

/// Copy a C string into a fixed-size `c_char` buffer, null-terminating.
fn copy_cstr_to_buf<const N: usize>(src: *const c_char, dst: &mut [c_char; N]) {
    if src.is_null() {
        return;
    }
    let cstr = unsafe { std::ffi::CStr::from_ptr(src) };
    let bytes = cstr.to_bytes();
    let len = bytes.len().min(N - 1);
    for i in 0..len {
        dst[i] = bytes[i] as c_char;
    }
    dst[len] = 0;
}

// ─── Constants ────────────────────────────────────────────────────────

/// Maximum number of validation errors per context
pub const MAX_ERRORS: usize = 64;

/// Maximum length of error message
pub const MAX_ERROR_LEN: usize = 256;

/// Maximum number of validation rules
pub const MAX_RULES: usize = 32;

// ─── Enums ────────────────────────────────────────────────────────────

/// Validation severity level
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ValidationSeverity {
    /// Informational — no action needed
    Info = 0,
    /// Warning — potential issue
    Warning = 1,
    /// Error — validation failed
    Error = 2,
    /// Critical — system invariant violated
    Critical = 3,
}

/// Validation rule type
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ValidationRuleType {
    /// Numeric range [min, max]
    Range = 0,
    /// Exact value match
    Exact = 1,
    /// Non-null/zero check
    NotNull = 2,
    /// String pattern (regex-like)
    Pattern = 3,
    /// Custom validator function
    Custom = 4,
    /// Conformance vector check
    Conformance = 5,
    /// Sacred physics invariant
    SacredInvariant = 6,
}

/// Validation result code
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ValidationCode {
    /// Validation passed
    Pass = 0,
    /// Validation failed
    Fail = 1,
    /// Validation skipped (rule not applicable)
    Skip = 2,
    /// Validation error (internal)
    Error = 3,
    /// Toxic change detected
    Toxic = 4,
}

// ─── Structs ──────────────────────────────────────────────────────────

/// Single validation error
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ValidationError {
    /// Error severity
    pub severity: ValidationSeverity,
    /// Rule that triggered the error
    pub rule_type: ValidationRuleType,
    /// Error code
    pub code: ValidationCode,
    /// Error message (null-terminated)
    pub message: [c_char; MAX_ERROR_LEN],
    /// Field/parameter name (null-terminated)
    pub field: [c_char; MAX_ERROR_LEN],
    /// Expected value (if applicable)
    pub expected: c_double,
    /// Actual value (if applicable)
    pub actual: c_double,
}

/// Validation rule definition
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ValidationRule {
    /// Rule type
    pub rule_type: ValidationRuleType,
    /// Minimum value (for range checks)
    pub min_value: c_double,
    /// Maximum value (for range checks)
    pub max_value: c_double,
    /// Expected value (for exact match)
    pub expected_value: c_double,
    /// Tolerance for floating-point comparison
    pub tolerance: c_double,
    /// Whether this rule is active
    pub active: bool,
    /// Field name this rule applies to
    pub field: [c_char; MAX_ERROR_LEN],
}

/// Validation context — holds state for a validation session
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ValidationContext {
    /// Number of rules in this context
    pub rule_count: usize,
    /// Number of errors collected
    pub error_count: usize,
    /// Overall result code
    pub result: ValidationCode,
    /// Maximum severity seen
    pub max_severity: ValidationSeverity,
    /// Rules array
    pub rules: [ValidationRule; MAX_RULES],
    /// Errors array
    pub errors: [ValidationError; MAX_ERRORS],
}

/// Conformance vector header
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ConformanceHeader {
    /// Vector name (null-terminated)
    pub name: [c_char; 64],
    /// Version of the conformance spec
    pub version: c_int,
    /// Number of entries in the vector
    pub entry_count: usize,
    /// Whether all checks passed
    pub passed: bool,
    /// Toxicity score [0.0, 1.0]
    pub toxicity_score: c_double,
}

// ─── Validation Context Lifecycle ─────────────────────────────────────

/// Create a new validation context
#[no_mangle]
pub extern "C" fn trios_validation_context_new() -> ValidationContext {
    ValidationContext {
        rule_count: 0,
        error_count: 0,
        result: ValidationCode::Pass,
        max_severity: ValidationSeverity::Info,
        rules: unsafe { std::mem::zeroed() },
        errors: unsafe { std::mem::zeroed() },
    }
}

/// Reset a validation context for reuse
#[no_mangle]
pub extern "C" fn trios_validation_context_reset(ctx: *mut ValidationContext) {
    if ctx.is_null() {
        return;
    }
    unsafe {
        (*ctx).rule_count = 0;
        (*ctx).error_count = 0;
        (*ctx).result = ValidationCode::Pass;
        (*ctx).max_severity = ValidationSeverity::Info;
    }
}

/// Get overall pass/fail status
#[no_mangle]
pub extern "C" fn trios_validation_passed(ctx: *const ValidationContext) -> bool {
    if ctx.is_null() {
        return false;
    }
    unsafe { (*ctx).result == ValidationCode::Pass }
}

/// Get number of errors
#[no_mangle]
pub extern "C" fn trios_validation_error_count(ctx: *const ValidationContext) -> usize {
    if ctx.is_null() {
        return 0;
    }
    unsafe { (*ctx).error_count }
}

/// Get maximum severity
#[no_mangle]
pub extern "C" fn trios_validation_max_severity(ctx: *const ValidationContext) -> ValidationSeverity {
    if ctx.is_null() {
        return ValidationSeverity::Error
    }
    unsafe { (*ctx).max_severity }
}

// ─── Rule Management ──────────────────────────────────────────────────

/// Add a range validation rule
#[no_mangle]
pub extern "C" fn trios_validation_add_range_rule(
    ctx: *mut ValidationContext,
    field: *const c_char,
    min_value: c_double,
    max_value: c_double,
) -> bool {
    if ctx.is_null() || field.is_null() {
        return false;
    }
    unsafe {
        if (*ctx).rule_count >= MAX_RULES {
            return false;
        }
        let rule = &mut (*ctx).rules[(*ctx).rule_count];
        rule.rule_type = ValidationRuleType::Range;
        rule.min_value = min_value;
        rule.max_value = max_value;
        rule.active = true;
        // Copy field name
        copy_cstr_to_buf(field, &mut rule.field);
        (*ctx).rule_count += 1;
        true
    }
}

/// Add an exact-value validation rule
#[no_mangle]
pub extern "C" fn trios_validation_add_exact_rule(
    ctx: *mut ValidationContext,
    field: *const c_char,
    expected: c_double,
    tolerance: c_double,
) -> bool {
    if ctx.is_null() || field.is_null() {
        return false;
    }
    unsafe {
        if (*ctx).rule_count >= MAX_RULES {
            return false;
        }
        let rule = &mut (*ctx).rules[(*ctx).rule_count];
        rule.rule_type = ValidationRuleType::Exact;
        rule.expected_value = expected;
        rule.tolerance = tolerance;
        rule.active = true;
        copy_cstr_to_buf(field, &mut rule.field);
        (*ctx).rule_count += 1;
        true
    }
}

/// Add a sacred invariant validation rule
#[no_mangle]
pub extern "C" fn trios_validation_add_sacred_rule(
    ctx: *mut ValidationContext,
    field: *const c_char,
    expected: c_double,
    tolerance: c_double,
) -> bool {
    if ctx.is_null() || field.is_null() {
        return false;
    }
    unsafe {
        if (*ctx).rule_count >= MAX_RULES {
            return false;
        }
        let rule = &mut (*ctx).rules[(*ctx).rule_count];
        rule.rule_type = ValidationRuleType::SacredInvariant;
        rule.expected_value = expected;
        rule.tolerance = tolerance;
        rule.active = true;
        copy_cstr_to_buf(field, &mut rule.field);
        (*ctx).rule_count += 1;
        true
    }
}

// ─── Validation Execution ─────────────────────────────────────────────

/// Validate a single numeric value against all rules in context
#[no_mangle]
pub extern "C" fn trios_validation_check_value(
    ctx: *mut ValidationContext,
    field: *const c_char,
    value: c_double,
) -> ValidationCode {
    if ctx.is_null() || field.is_null() {
        return ValidationCode::Error;
    }

    let field_str = unsafe { std::ffi::CStr::from_ptr(field) };
    let field_bytes = field_str.to_bytes();

    let mut result = ValidationCode::Pass;

    unsafe {
        for i in 0..(*ctx).rule_count {
            let rule = &(*ctx).rules[i];
            if !rule.active {
                continue;
            }

            // Check if rule applies to this field
            let rule_field = std::ffi::CStr::from_ptr(rule.field.as_ptr());
            if rule_field.to_bytes() != field_bytes {
                continue;
            }

            let mut passed = true;
            match rule.rule_type {
                ValidationRuleType::Range => {
                    passed = value >= rule.min_value && value <= rule.max_value;
                    if !passed {
                        trios_validation_add_error_internal(
                            ctx,
                            ValidationSeverity::Error,
                            rule.rule_type,
                            field,
                            rule.min_value,
                            value,
                        );
                    }
                }
                ValidationRuleType::Exact => {
                    let diff = (value - rule.expected_value).abs();
                    passed = diff <= rule.tolerance;
                    if !passed {
                        trios_validation_add_error_internal(
                            ctx,
                            ValidationSeverity::Error,
                            rule.rule_type,
                            field,
                            rule.expected_value,
                            value,
                        );
                    }
                }
                ValidationRuleType::SacredInvariant => {
                    let diff = (value - rule.expected_value).abs();
                    passed = diff <= rule.tolerance;
                    if !passed {
                        trios_validation_add_error_internal(
                            ctx,
                            ValidationSeverity::Critical,
                            rule.rule_type,
                            field,
                            rule.expected_value,
                            value,
                        );
                    }
                }
                _ => {
                    // Other rule types handled elsewhere
                    continue;
                }
            }

            if !passed {
                result = ValidationCode::Fail;
            }
        }
    }

    if result != ValidationCode::Pass {
        unsafe {
            (*ctx).result = result;
        }
    }

    result
}

/// Internal helper to add an error to the context
unsafe fn trios_validation_add_error_internal(
    ctx: *mut ValidationContext,
    severity: ValidationSeverity,
    rule_type: ValidationRuleType,
    field: *const c_char,
    expected: c_double,
    actual: c_double,
) {
    if (*ctx).error_count >= MAX_ERRORS {
        return;
    }

    let err = &mut (*ctx).errors[(*ctx).error_count];
    err.severity = severity;
    err.rule_type = rule_type;
    err.code = ValidationCode::Fail;
    err.expected = expected;
    err.actual = actual;

    // Copy field name
    copy_cstr_to_buf(field, &mut err.field);

    // Update max severity
    if severity as c_int > (*ctx).max_severity as c_int {
        (*ctx).max_severity = severity;
    }

    (*ctx).error_count += 1;
}

// ─── Sacred Physics Conformance ───────────────────────────────────────

/// Golden ratio φ
const PHI: f64 = 1.6180339887498948482;

/// Validate the Trinity identity: φ² + 1/φ² = 3
#[no_mangle]
pub extern "C" fn trios_validation_trinity_identity(tolerance: c_double) -> bool {
    let phi_sq = PHI * PHI;
    let phi_inv_sq = 1.0 / phi_sq;
    let sum = phi_sq + phi_inv_sq;
    (sum - 3.0).abs() <= tolerance
}

/// Validate golden ratio value
#[no_mangle]
pub extern "C" fn trios_validation_phi(value: c_double, tolerance: c_double) -> bool {
    (value - PHI).abs() <= tolerance
}

/// Validate Fibonacci relationship: F(n+2) = F(n+1) + F(n)
#[no_mangle]
pub extern "C" fn trios_validation_fibonacci(
    fn_prev: c_long,
    fn_curr: c_long,
    fn_next: c_long,
) -> bool {
    fn_prev + fn_curr == fn_next
}

/// Check toxicity score — returns true if the change is toxic
#[no_mangle]
pub extern "C" fn trios_validation_is_toxic(
    ctx: *const ValidationContext,
    threshold: c_double,
) -> bool {
    if ctx.is_null() {
        return true; // Null context = toxic
    }
    unsafe {
        let critical_count = (0..(*ctx).error_count)
            .filter(|&i| (*ctx).errors[i].severity == ValidationSeverity::Critical)
            .count();
        let score = critical_count as c_double / MAX_ERRORS as c_double;
        score >= threshold
    }
}

/// Compute conformance score [0.0, 1.0] for a context
#[no_mangle]
pub extern "C" fn trios_validation_conformance_score(ctx: *const ValidationContext) -> c_double {
    if ctx.is_null() {
        return 0.0;
    }
    unsafe {
        if (*ctx).rule_count == 0 {
            return 1.0;
        }
        let failed = (*ctx).error_count;
        let total = (*ctx).rule_count;
        1.0 - (failed as c_double / total as c_double)
    }
}

// ─── Unit Tests ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trinity_identity() {
        assert!(trios_validation_trinity_identity(1e-10));
    }

    #[test]
    fn test_phi_validation() {
        assert!(trios_validation_phi(PHI, 1e-10));
        assert!(!trios_validation_phi(1.5, 1e-10));
    }

    #[test]
    fn test_fibonacci() {
        assert!(trios_validation_fibonacci(5, 8, 13));
        assert!(!trios_validation_fibonacci(5, 8, 14));
    }

    #[test]
    fn test_context_new() {
        let ctx = trios_validation_context_new();
        assert_eq!(ctx.rule_count, 0);
        assert_eq!(ctx.error_count, 0);
        assert_eq!(ctx.result, ValidationCode::Pass);
    }

    #[test]
    fn test_range_validation() {
        let mut ctx = trios_validation_context_new();
        let field = b"x\0";
        let field_ptr = field.as_ptr() as *const c_char;

        assert!(trios_validation_add_range_rule(&mut ctx, field_ptr, 0.0, 10.0));

        let result = trios_validation_check_value(&mut ctx, field_ptr, 5.0);
        assert_eq!(result, ValidationCode::Pass);

        let result = trios_validation_check_value(&mut ctx, field_ptr, 15.0);
        assert_eq!(result, ValidationCode::Fail);
    }

    #[test]
    fn test_conformance_score() {
        let ctx = trios_validation_context_new();
        let score = trios_validation_conformance_score(&ctx);
        assert_eq!(score, 1.0); // No rules = perfect score
    }
}
