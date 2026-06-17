//! TRIOS VSA — Vector Symbolic Architecture FFI
//!
//! This crate provides FFI bindings for TRIOS Vector Symbolic Architecture operations.
//! Core operations include bind, unbind, bundle, permute, and similarity metrics.
//!
//! ## Data Types
//!
//! - `Trit`: Ternary value (-1, 0, +1) represented as i8
//! - `VSAVector`: Dense vector of trits
//! - `VSASparseVector`: Sparse representation with indices and values
//!
//! ## Core Operations
//!
//! - **bind(x, y)**: Element-wise multiplication for binding
//! - **unbind(x, y)**: Inverse of bind (same as bind for symmetric trits)
//! - **bundle(vectors)**: Addition-like operation for bundling
//! - **permute(vec, perm)**: Permutation for order preservation
//!
//! ## Safety
//!
//! All FFI functions that take pointers must be called with valid, non-null pointers.
//! Vectors must be allocated with matching allocators and freed properly.

use std::os::raw::{c_char, c_double, c_int, c_long};
use std::ptr;

/// Trit value: -1, 0, or +1
pub type Trit = i8;

/// Trit values
pub const TRIT_NEGATIVE: Trit = -1;
pub const TRIT_ZERO: Trit = 0;
pub const TRIT_POSITIVE: Trit = 1;

/// SIMD width for vector operations
pub const SIMD_WIDTH: usize = 32;

/// Dense VSA vector
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct VSAVector {
    /// Pointer to trit data
    pub data: *mut Trit,
    /// Number of trits in the vector
    pub len: usize,
    /// Capacity (for memory management)
    pub capacity: usize,
}

/// Sparse VSA vector (for high-dimensional sparse data)
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct VSASparseVector {
    /// Non-zero indices
    pub indices: *mut usize,
    /// Trit values at those indices
    pub values: *mut Trit,
    /// Number of non-zero elements
    pub nnz: usize,
    /// Total dimension
    pub dimension: usize,
}

/// Search result for similarity queries
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct VSASearchResult {
    /// Index of the best match
    pub index: usize,
    /// Similarity score (0.0 to 1.0)
    pub score: f64,
    /// Whether a good match was found
    pub found: bool,
}

/// Allocator type for VSA operations
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VSAAllocator {
    /// Default system allocator
    System = 0,
    /// Arena allocator (for batch operations)
    Arena = 1,
    /// Pool allocator (for frequent allocs/frees)
    Pool = 2,
}

/// VSA Context (manages allocator and state)
#[repr(C)]
pub struct VSAContext {
    _private: [u8; 0], // Zero-sized type for opaque handle
}

/// Create a new VSA context
///
/// Returns null pointer on allocation failure.
#[no_mangle]
pub extern "C" fn trios_vsa_context_new(alloc_type: VSAAllocator) -> *mut VSAContext {
    // TODO: Initialize Zig allocator and context
    let _ = alloc_type;
    ptr::null_mut()
}

/// Destroy a VSA context
#[no_mangle]
pub extern "C" fn trios_vsa_context_free(ctx: *mut VSAContext) {
    if !ctx.is_null() {
        // TODO: Free Zig context
    }
}

/// Create a new VSA vector
///
/// # Safety
/// - `ctx` must be a valid VSAContext pointer
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_vector_new(
    ctx: *mut VSAContext,
    len: usize,
) -> *mut VSAVector {
    let _ = ctx;
    let _ = len;
    // TODO: Allocate vector in Zig
    ptr::null_mut()
}

/// Create a VSA vector from raw data
///
/// # Safety
/// - `ctx` must be a valid VSAContext pointer
/// - `data` must point to valid trit data of length `len`
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_vector_from_data(
    ctx: *mut VSAContext,
    data: *const Trit,
    len: usize,
) -> *mut VSAVector {
    let _ = ctx;
    let _ = data;
    let _ = len;
    // TODO: Copy data into new vector in Zig
    ptr::null_mut()
}

/// Free a VSA vector
#[no_mangle]
pub extern "C" fn trios_vsa_vector_free(vec: *mut VSAVector) {
    if !vec.is_null() {
        unsafe {
            if !(*vec).data.is_null() {
                // TODO: Free data in Zig allocator
            }
            // TODO: Free vector struct
        }
    }
}

/// Get vector length
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_vector_len(vec: *const VSAVector) -> usize {
    if vec.is_null() {
        0
    } else {
        (*vec).len
    }
}

/// Get vector data pointer (read-only)
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_vector_data(vec: *const VSAVector) -> *const Trit {
    if vec.is_null() {
        ptr::null()
    } else {
        (*vec).data
    }
}

/// Bind operation: element-wise multiplication
///
/// Returns null on failure.
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_bind(
    ctx: *mut VSAContext,
    a: *const VSAVector,
    b: *const VSAVector,
) -> *mut VSAVector {
    if ctx.is_null() || a.is_null() || b.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig bind operation
    ptr::null_mut()
}

/// Unbind operation: inverse of bind (same as bind for symmetric trits)
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_unbind(
    ctx: *mut VSAContext,
    a: *const VSAVector,
    b: *const VSAVector,
) -> *mut VSAVector {
    // For symmetric trits, unbind = bind
    trios_vsa_bind(ctx, a, b)
}

/// Bundle 2 vectors: addition-like operation
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_bundle2(
    ctx: *mut VSAContext,
    a: *const VSAVector,
    b: *const VSAVector,
) -> *mut VSAVector {
    if ctx.is_null() || a.is_null() || b.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig bundle2 operation
    ptr::null_mut()
}

/// Bundle 3 vectors
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_bundle3(
    ctx: *mut VSAContext,
    a: *const VSAVector,
    b: *const VSAVector,
    c: *const VSAVector,
) -> *mut VSAVector {
    if ctx.is_null() || a.is_null() || b.is_null() || c.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig bundle3 operation
    ptr::null_mut()
}

/// Bundle N vectors
///
/// # Safety
/// - `vectors` must point to an array of `count` VSAVector pointers
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_bundle_n(
    ctx: *mut VSAContext,
    vectors: *const *const VSAVector,
    count: usize,
) -> *mut VSAVector {
    if ctx.is_null() || vectors.is_null() || count == 0 {
        return ptr::null_mut();
    }
    // TODO: Call Zig bundleN operation
    ptr::null_mut()
}

/// Permute vector with a permutation pattern
///
/// # Safety
/// - `perm` must point to valid permutation data of length `vec.len`
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_permute(
    ctx: *mut VSAContext,
    vec: *const VSAVector,
    perm: *const usize,
) -> *mut VSAVector {
    if ctx.is_null() || vec.is_null() || perm.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig permute operation
    ptr::null_mut()
}

/// Inverse permute vector
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_inverse_permute(
    ctx: *mut VSAContext,
    vec: *const VSAVector,
    perm: *const usize,
) -> *mut VSAVector {
    if ctx.is_null() || vec.is_null() || perm.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig inversePermute operation
    ptr::null_mut()
}

/// Generate a random vector
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_random_vector(
    ctx: *mut VSAContext,
    len: usize,
    seed: u64,
) -> *mut VSAVector {
    if ctx.is_null() {
        return ptr::null_mut();
    }
    let _ = seed;
    // TODO: Call Zig randomVector operation
    ptr::null_mut()
}

/// Cosine similarity between two vectors
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_cosine_similarity(
    a: *const VSAVector,
    b: *const VSAVector,
) -> c_double {
    if a.is_null() || b.is_null() {
        return 0.0;
    }
    // TODO: Call Zig cosineSimilarity operation
    0.0
}

/// Hamming distance between two vectors
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_hamming_distance(
    a: *const VSAVector,
    b: *const VSAVector,
) -> usize {
    if a.is_null() || b.is_null() {
        return usize::MAX;
    }
    // TODO: Call Zig hammingDistance operation
    0
}

/// Hamming similarity (1.0 - distance / len)
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_hamming_similarity(
    a: *const VSAVector,
    b: *const VSAVector,
) -> c_double {
    if a.is_null() || b.is_null() {
        return 0.0;
    }
    // TODO: Call Zig hammingSimilarity operation
    0.0
}

/// Dot product similarity
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_dot_similarity(
    a: *const VSAVector,
    b: *const VSAVector,
) -> c_long {
    if a.is_null() || b.is_null() {
        return 0;
    }
    // TODO: Call Zig dotSimilarity operation
    0
}

/// Vector norm (L2)
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_vector_norm(vec: *const VSAVector) -> c_double {
    if vec.is_null() {
        return 0.0;
    }
    // TODO: Call Zig vectorNorm operation
    0.0
}

/// Count non-zero trits
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_count_non_zero(vec: *const VSAVector) -> usize {
    if vec.is_null() {
        return 0;
    }
    // TODO: Call Zig countNonZero operation
    0
}

/// Dot product
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_dot_product(
    a: *const VSAVector,
    b: *const VSAVector,
) -> c_long {
    if a.is_null() || b.is_null() {
        return 0;
    }
    // TODO: Call Zig dotProduct operation
    0
}

/// Encode a sequence into a single vector
///
/// # Safety
/// - `sequence` must point to an array of `count` VSAVector pointers
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_encode_sequence(
    ctx: *mut VSAContext,
    sequence: *const *const VSAVector,
    count: usize,
) -> *mut VSAVector {
    if ctx.is_null() || sequence.is_null() || count == 0 {
        return ptr::null_mut();
    }
    // TODO: Call Zig encodeSequence operation
    ptr::null_mut()
}

/// Probe sequence: find best match in memory
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_probe_sequence(
    ctx: *mut VSAContext,
    query: *const VSAVector,
    memory: *const *const VSAVector,
    memory_count: usize,
    result: *mut VSASearchResult,
) -> c_int {
    if ctx.is_null() || query.is_null() || memory.is_null() || result.is_null() {
        return -1;
    }
    // TODO: Call Zig probeSequence operation
    (*result).found = false;
    (*result).score = 0.0;
    (*result).index = 0;
    0
}

/// Create a sparse vector from dense
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_sparse_from_dense(
    ctx: *mut VSAContext,
    dense: *const VSAVector,
) -> *mut VSASparseVector {
    if ctx.is_null() || dense.is_null() {
        return ptr::null_mut();
    }
    // TODO: Call Zig SparseVector.fromDense
    ptr::null_mut()
}

/// Free a sparse vector
#[no_mangle]
pub extern "C" fn trios_vsa_sparse_free(vec: *mut VSASparseVector) {
    if !vec.is_null() {
        unsafe {
            if !(*vec).indices.is_null() {
                // TODO: Free indices
            }
            if !(*vec).values.is_null() {
                // TODO: Free values
            }
            // TODO: Free sparse vector struct
        }
    }
}

/// Get sparse vector non-zero count
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_sparse_nnz(vec: *const VSASparseVector) -> usize {
    if vec.is_null() {
        0
    } else {
        (*vec).nnz
    }
}

/// Get sparse vector dimension
#[no_mangle]
pub unsafe extern "C" fn trios_vsa_sparse_dimension(vec: *const VSASparseVector) -> usize {
    if vec.is_null() {
        0
    } else {
        (*vec).dimension
    }
}

/// Get last error message (null if no error)
#[no_mangle]
pub extern "C" fn trios_vsa_last_error() -> *const c_char {
    // TODO: Return last error from Zig context
    ptr::null()
}

/// Clear last error
#[no_mangle]
pub extern "C" fn trios_vsa_clear_error() {
    // TODO: Clear error state
}

/// Get VSA version
#[no_mangle]
pub extern "C" fn trios_vsa_version() -> *const c_char {
    "0.1.0\0".as_ptr() as *const c_char
}

/// Get VSA build info
#[no_mangle]
pub extern "C" fn trios_vsa_build_info() -> *const c_char {
    "trios-vsa 0.1.0 (FFI wrapper for Zig VSA core)\0".as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_trit_constants() {
        assert_eq!(TRIT_NEGATIVE, -1);
        assert_eq!(TRIT_ZERO, 0);
        assert_eq!(TRIT_POSITIVE, 1);
    }

    #[test]
    fn test_simd_width() {
        assert_eq!(SIMD_WIDTH, 32);
    }

    #[test]
    fn test_version() {
        let version = unsafe { CStr::from_ptr(trios_vsa_version()) };
        assert_eq!(version.to_str().unwrap(), "0.1.0");
    }

    #[test]
    fn test_build_info() {
        let info = unsafe { CStr::from_ptr(trios_vsa_build_info()) };
        let info_str = info.to_str().unwrap();
        assert!(info_str.contains("trios-vsa"));
        assert!(info_str.contains("0.1.0"));
    }

    #[test]
    fn test_vector_null_checks() {
        unsafe {
            assert_eq!(trios_vsa_vector_len(ptr::null()), 0);
            assert_eq!(trios_vsa_vector_data(ptr::null()), ptr::null());
            assert_eq!(trios_vsa_cosine_similarity(ptr::null(), ptr::null()), 0.0);
            assert_eq!(trios_vsa_hamming_distance(ptr::null(), ptr::null()), usize::MAX);
        }
    }

    #[test]
    fn test_sparse_null_checks() {
        unsafe {
            assert_eq!(trios_vsa_sparse_nnz(ptr::null()), 0);
            assert_eq!(trios_vsa_sparse_dimension(ptr::null()), 0);
        }
    }
}
