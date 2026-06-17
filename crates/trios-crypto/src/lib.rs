//! TRIOS Crypto — Cryptographic Operations and DePIN Mining FFI
//!
//! This crate provides FFI bindings for TRIOS cryptographic operations.
//!
//! ## Features
//!
//! - **Blake3**: Fast hash function
//! - **Merkle Tree**: Root hash computation
//! - **GF256**: Galois Field operations
//!
//! ## Symbol: `🔒`

use std::os::raw::{c_char, c_int, c_uchar, c_uint};

/// Hash output size (256 bits = 32 bytes)
pub const HASH_SIZE: usize = 32;

/// Blake3 hash result
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HashOutput {
    pub data: [u8; HASH_SIZE],
}

/// Merkle tree node
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct MerkleNode {
    pub hash: HashOutput,
    pub left: *mut MerkleNode,
    pub right: *mut MerkleNode,
}

/// GF256 element (byte in Galois Field)
pub type GF256 = u8;

/// Blake3 hash of data
#[no_mangle]
pub extern "C" fn trios_crypto_blake3_hash(
    data: *const u8,
    len: usize,
    output: *mut HashOutput,
) -> c_int {
    if data.is_null() || output.is_null() {
        return -1;
    }
    // TODO: Call Zig Blake3 implementation
    unsafe {
        // Placeholder: XOR hash for now
        let data_slice = std::slice::from_raw_parts(data, len);
        let mut hash: [u8; 32] = [0; 32];
        for (i, &b) in data_slice.iter().enumerate() {
            hash[i % 32] ^= b;
        }
        (*output).data = hash;
    }
    0
}

/// Compute Merkle root from hashes
#[no_mangle]
pub extern "C" fn trios_crypto_merkle_root(
    hashes: *const HashOutput,
    count: usize,
    root: *mut HashOutput,
) -> c_int {
    if hashes.is_null() || root.is_null() || count == 0 {
        return -1;
    }
    // TODO: Call Zig Merkle root computation
    unsafe {
        if count == 1 {
            (*root).data = (*hashes).data;
        } else {
            // Placeholder: XOR all hashes
            let mut combined: [u8; 32] = [0; 32];
            for i in 0..count {
                let h = &*hashes.add(i);
                for j in 0..32 {
                    combined[j] ^= h.data[j];
                }
            }
            (*root).data = combined;
        }
    }
    0
}

/// GF256 multiplication
#[no_mangle]
pub extern "C" fn trios_crypto_gf256_mul(a: GF256, b: GF256) -> GF256 {
    let mut result = 0u8;
    let mut a = a;
    let mut b = b;

    while b != 0 {
        if b & 1 != 0 {
            result ^= a;
        }
        let high = (a & 0x80) != 0;
        a <<= 1;
        if high {
            a ^= 0x1b; // x^8 + x^4 + x^3 + x + 1
        }
        b >>= 1;
    }
    result
}

/// GF256 addition (XOR)
#[no_mangle]
pub extern "C" fn trios_crypto_gf256_add(a: GF256, b: GF256) -> GF256 {
    a ^ b
}

/// GF256 inverse
#[no_mangle]
pub extern "C" fn trios_crypto_gf256_inv(a: GF256) -> GF256 {
    if a == 0 {
        return 0; // No inverse for 0
    }
    // Extended Euclidean algorithm for GF(2^8)
    let mut t0 = 0u8;
    let mut t1 = 1u8;
    let mut r0 = 0x1bu8; // Irreducible polynomial
    let mut r1 = a;

    while r1 != 0 {
        let q = gf256_div(r0, r1);
        let r2 = gf256_mul(q, r1) ^ r0;
        let t2 = gf256_mul(q, t1) ^ t0;
        r0 = r1;
        r1 = r2;
        t0 = t1;
        t1 = t2;
    }
    t0
}

fn gf256_div(a: u8, b: u8) -> u8 {
    let mut q = 0u8;
    let mut r = a;

    for _ in 0..8 {
        q <<= 1;
        r <<= 1;
        if (r & 0x100) != 0 {
            r ^= 0x1b;
            q |= 1;
        }
    }
    q
}

/// Mining: find nonce for target
#[no_mangle]
pub extern "C" fn trios_crypto_mine_nonce(
    block_data: *const u8,
    block_len: usize,
    target: *const HashOutput,
    nonce_start: u32,
    max_nonce: u32,
    found_nonce: *mut u32,
    found_hash: *mut HashOutput,
) -> c_int {
    if block_data.is_null() || target.is_null() || found_nonce.is_null() || found_hash.is_null() {
        return -1;
    }
    // TODO: Call Zig mining implementation
    unsafe {
        *found_nonce = 0;
    }
    0
}

/// Verify hash meets target difficulty
#[no_mangle]
pub extern "C" fn trios_crypto_verify_target(
    hash: *const HashOutput,
    target: *const HashOutput,
) -> bool {
    if hash.is_null() || target.is_null() {
        return false;
    }
    unsafe {
        // Compare hash to target (hash must be <= target)
        for i in 0..HASH_SIZE {
            if (*hash).data[i] < (*target).data[i] {
                return true;
            }
            if (*hash).data[i] > (*target).data[i] {
                return false;
            }
        }
        true
    }
}

/// Get version
#[no_mangle]
pub extern "C" fn trios_crypto_version() -> *const c_char {
    "0.1.0\0".as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gf256_mul() {
        // 2 * 3 = 6 in GF256
        assert_eq!(trios_crypto_gf256_mul(2, 3), 6);
        // 0 * anything = 0
        assert_eq!(trios_crypto_gf256_mul(0, 5), 0);
    }

    #[test]
    fn test_gf256_add() {
        assert_eq!(trios_crypto_gf256_add(5, 3), 5 ^ 3);
        assert_eq!(trios_crypto_gf256_add(0, 5), 5);
    }

    #[test]
    fn test_gf256_inv() {
        // 1's inverse is 1
        assert_eq!(trios_crypto_gf256_inv(1), 1);
        // 0 has no inverse
        assert_eq!(trios_crypto_gf256_inv(0), 0);
        // Verify a * inv(a) = 1
        for a in 1..=255u8 {
            let inv = trios_crypto_gf256_inv(a);
            if inv != 0 {
                assert_eq!(trios_crypto_gf256_mul(a, inv), 1);
            }
        }
    }

    #[test]
    fn test_verify_target() {
        let hash = HashOutput { data: [1u8; 32] };
        let target = HashOutput { data: [2u8; 32] };
        assert!(trios_crypto_verify_target(&hash, &target));

        let hash2 = HashOutput { data: [3u8; 32] };
        assert!(!trios_crypto_verify_target(&hash2, &target));
    }

    #[test]
    fn test_null_checks() {
        assert_eq!(trios_crypto_blake3_hash(std::ptr::null(), 0, std::ptr::null_mut()), -1);
        assert_eq!(trios_crypto_merkle_root(std::ptr::null(), 0, std::ptr::null_mut()), -1);
    }

    #[test]
    fn test_version() {
        let version = unsafe {
            std::ffi::CStr::from_ptr(trios_crypto_version())
        };
        assert_eq!(version.to_str().unwrap(), "0.1.0");
    }
}
