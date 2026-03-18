//! SIMD-accelerated operations

#[cfg(all(target_arch = "x86_64", feature = "simd"))]
use std::arch::x86_64::*;

/// Check if AVX2 is available
#[cfg(target_arch = "x86_64")]
pub fn has_avx2() -> bool {
    is_x86_feature_detected!("avx2")
}

/// Check if AVX-512 is available
#[cfg(target_arch = "x86_64")]
pub fn has_avx512() -> bool {
    is_x86_feature_detected!("avx512f")
}

/// SIMD-accelerated bind for i8 vectors
#[cfg(all(target_arch = "x86_64", feature = "simd"))]
pub unsafe fn bind_avx2(a: &[i8], b: &[i8], result: &mut [i8]) {
    assert_eq!(a.len(), b.len());
    assert_eq!(a.len(), result.len());
    
    let len = a.len();
    let chunks = len / 32;
    
    for i in 0..chunks {
        let offset = i * 32;
        let va = _mm256_loadu_si256(a.as_ptr().add(offset) as *const __m256i);
        let vb = _mm256_loadu_si256(b.as_ptr().add(offset) as *const __m256i);
        
        // For balanced ternary, we need sign multiplication
        // This is a simplified version - full impl would handle all cases
        let signs_a = _mm256_cmpgt_epi8(_mm256_setzero_si256(), va);
        let signs_b = _mm256_cmpgt_epi8(_mm256_setzero_si256(), vb);
        let sign_xor = _mm256_xor_si256(signs_a, signs_b);
        
        let abs_a = _mm256_abs_epi8(va);
        let abs_b = _mm256_abs_epi8(vb);
        let abs_prod = _mm256_min_epi8(abs_a, abs_b); // min(|a|,|b|) for ternary
        
        // Apply sign
        let neg_prod = _mm256_sub_epi8(_mm256_setzero_si256(), abs_prod);
        let prod = _mm256_blendv_epi8(abs_prod, neg_prod, sign_xor);
        
        _mm256_storeu_si256(result.as_mut_ptr().add(offset) as *mut __m256i, prod);
    }
    
    // Handle remainder
    for i in (chunks * 32)..len {
        result[i] = a[i] * b[i];
    }
}

/// SIMD-accelerated dot product
#[cfg(all(target_arch = "x86_64", feature = "simd"))]
pub unsafe fn dot_avx2(a: &[i8], b: &[i8]) -> i64 {
    assert_eq!(a.len(), b.len());
    
    let len = a.len();
    let chunks = len / 32;
    let mut sum: i64 = 0;
    
    let mut acc = _mm256_setzero_si256();
    
    for i in 0..chunks {
        let offset = i * 32;
        let va = _mm256_loadu_si256(a.as_ptr().add(offset) as *const __m256i);
        let vb = _mm256_loadu_si256(b.as_ptr().add(offset) as *const __m256i);
        
        // Multiply and accumulate (simplified)
        let prod = _mm256_mullo_epi16(
            _mm256_cvtepi8_epi16(_mm256_extracti128_si256(va, 0)),
            _mm256_cvtepi8_epi16(_mm256_extracti128_si256(vb, 0))
        );
        acc = _mm256_add_epi32(acc, _mm256_cvtepi16_epi32(_mm256_extracti128_si256(prod, 0)));
    }
    
    // Horizontal sum
    let mut arr = [0i32; 8];
    _mm256_storeu_si256(arr.as_mut_ptr() as *mut __m256i, acc);
    sum += arr.iter().map(|&x| x as i64).sum::<i64>();
    
    // Handle remainder
    for i in (chunks * 32)..len {
        sum += (a[i] as i64) * (b[i] as i64);
    }
    
    sum
}

#[cfg(test)]
mod tests {
    #[test]
    #[cfg(target_arch = "x86_64")]
    fn test_feature_detection() {
        println!("AVX2: {}", super::has_avx2());
        println!("AVX-512: {}", super::has_avx512());
    }
}
