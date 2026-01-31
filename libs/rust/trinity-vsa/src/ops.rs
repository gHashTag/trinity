//! VSA operations: bind, bundle, permute, similarity

use crate::TritVector;

/// Bind two vectors (element-wise multiplication)
/// 
/// Creates an association between two concepts.
/// 
/// # Properties
/// - `bind(a, a) = all +1` (self-binding)
/// - `bind(a, bind(a, b)) = b` (unbinding)
/// - Commutative: `bind(a, b) = bind(b, a)`
/// 
/// # Example
/// ```
/// use trinity_vsa::{TritVector, bind};
/// 
/// let a = TritVector::random(100);
/// let b = TritVector::random(100);
/// let bound = bind(&a, &b);
/// ```
pub fn bind(a: &TritVector, b: &TritVector) -> TritVector {
    assert_eq!(a.len(), b.len(), "Vectors must have same dimension");
    
    let data: Vec<i8> = a.as_slice()
        .iter()
        .zip(b.as_slice().iter())
        .map(|(&x, &y)| x * y)
        .collect();
    
    TritVector::from_slice(&data)
}

/// Unbind (same as bind for balanced ternary)
/// 
/// Retrieves one vector from a bound pair.
/// 
/// # Example
/// ```
/// use trinity_vsa::{TritVector, bind, unbind, similarity};
/// 
/// let a = TritVector::random(100);
/// let b = TritVector::random(100);
/// let bound = bind(&a, &b);
/// let recovered = unbind(&bound, &a);
/// // recovered ≈ b
/// ```
pub fn unbind(bound: &TritVector, key: &TritVector) -> TritVector {
    bind(bound, key)
}

/// Bundle multiple vectors (majority voting)
/// 
/// Creates a superposition that is similar to all inputs.
/// 
/// # Example
/// ```
/// use trinity_vsa::{TritVector, bundle};
/// 
/// let vectors: Vec<TritVector> = (0..5)
///     .map(|_| TritVector::random(100))
///     .collect();
/// let refs: Vec<&TritVector> = vectors.iter().collect();
/// let bundled = bundle(&refs);
/// ```
pub fn bundle(vectors: &[&TritVector]) -> TritVector {
    if vectors.is_empty() {
        return TritVector::zeros(0);
    }
    
    let dim = vectors[0].len();
    assert!(vectors.iter().all(|v| v.len() == dim), "All vectors must have same dimension");
    
    let mut sums: Vec<i32> = vec![0; dim];
    
    for v in vectors {
        for (i, &trit) in v.as_slice().iter().enumerate() {
            sums[i] += trit as i32;
        }
    }
    
    // Threshold: positive -> 1, negative -> -1, zero -> 0
    let data: Vec<i8> = sums.iter().map(|&s| s.signum() as i8).collect();
    TritVector::from_slice(&data)
}

/// Permute vector (circular shift)
/// 
/// Used for encoding sequences and positions.
/// 
/// # Example
/// ```
/// use trinity_vsa::{TritVector, permute};
/// 
/// let v = TritVector::random(100);
/// let shifted = permute(&v, 5);  // Shift right by 5
/// ```
pub fn permute(v: &TritVector, shift: i32) -> TritVector {
    let len = v.len();
    if len == 0 {
        return TritVector::zeros(0);
    }
    
    let shift = ((shift % len as i32) + len as i32) as usize % len;
    
    let mut data = vec![0i8; len];
    for i in 0..len {
        let new_idx = (i + shift) % len;
        data[new_idx] = v.as_slice()[i];
    }
    
    TritVector::from_slice(&data)
}

/// Cosine similarity between two vectors
/// 
/// Returns value in [-1.0, 1.0]:
/// - 1.0: identical
/// - 0.0: orthogonal
/// - -1.0: opposite
/// 
/// # Example
/// ```
/// use trinity_vsa::{TritVector, similarity};
/// 
/// let a = TritVector::random(100);
/// let b = TritVector::random(100);
/// let sim = similarity(&a, &b);
/// ```
pub fn similarity(a: &TritVector, b: &TritVector) -> f64 {
    assert_eq!(a.len(), b.len(), "Vectors must have same dimension");
    
    let dot: i64 = a.as_slice()
        .iter()
        .zip(b.as_slice().iter())
        .map(|(&x, &y)| (x as i64) * (y as i64))
        .sum();
    
    let norm_a: f64 = a.as_slice().iter().map(|&x| (x as f64).powi(2)).sum::<f64>().sqrt();
    let norm_b: f64 = b.as_slice().iter().map(|&x| (x as f64).powi(2)).sum::<f64>().sqrt();
    
    if norm_a == 0.0 || norm_b == 0.0 {
        return 0.0;
    }
    
    (dot as f64) / (norm_a * norm_b)
}

/// Hamming distance (number of differing positions)
/// 
/// # Example
/// ```
/// use trinity_vsa::{TritVector, hamming_distance};
/// 
/// let a = TritVector::random(100);
/// let b = TritVector::random(100);
/// let dist = hamming_distance(&a, &b);
/// ```
pub fn hamming_distance(a: &TritVector, b: &TritVector) -> usize {
    assert_eq!(a.len(), b.len(), "Vectors must have same dimension");
    
    a.as_slice()
        .iter()
        .zip(b.as_slice().iter())
        .filter(|(&x, &y)| x != y)
        .count()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bind_unbind() {
        let a = TritVector::random(100);
        let b = TritVector::random(100);
        
        let bound = bind(&a, &b);
        let recovered = unbind(&bound, &a);
        
        // recovered should be similar to b
        let sim = similarity(&recovered, &b);
        assert!(sim > 0.9, "Unbind should recover original: {}", sim);
    }

    #[test]
    fn test_bundle_similarity() {
        let vectors: Vec<TritVector> = (0..5)
            .map(|_| TritVector::random(1000))
            .collect();
        let refs: Vec<&TritVector> = vectors.iter().collect();
        
        let bundled = bundle(&refs);
        
        // Bundled should be similar to all inputs
        for v in &vectors {
            let sim = similarity(&bundled, v);
            assert!(sim > 0.3, "Bundle should be similar to inputs: {}", sim);
        }
    }

    #[test]
    fn test_permute() {
        let v = TritVector::from_slice(&[1, -1, 0, 1, -1]);
        let shifted = permute(&v, 2);
        assert_eq!(shifted.as_slice(), &[-1, 1, 1, -1, 0]);
    }

    #[test]
    fn test_self_similarity() {
        let v = TritVector::random(100);
        let sim = similarity(&v, &v);
        assert!((sim - 1.0).abs() < 1e-10, "Self-similarity should be 1.0");
    }
}
