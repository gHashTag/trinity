//! Dense trit vector implementation

use crate::Trit;
use rand::Rng;

/// Dense vector of balanced ternary values
/// 
/// # Example
/// ```
/// use trinity_vsa::TritVector;
/// 
/// let v = TritVector::random(1000);
/// assert_eq!(v.len(), 1000);
/// ```
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TritVector {
    data: Vec<i8>,
}

impl TritVector {
    /// Create zero vector of given dimension
    pub fn zeros(dim: usize) -> Self {
        Self {
            data: vec![0; dim],
        }
    }

    /// Create random hypervector
    /// 
    /// Generates uniformly distributed trits in {-1, 0, +1}
    pub fn random(dim: usize) -> Self {
        let mut rng = rand::thread_rng();
        let data: Vec<i8> = (0..dim)
            .map(|_| rng.gen_range(-1..=1))
            .collect();
        Self { data }
    }

    /// Create random sparse hypervector
    /// 
    /// `sparsity` is probability of non-zero (0.0 = all zeros, 1.0 = no zeros)
    pub fn random_sparse(dim: usize, sparsity: f64) -> Self {
        let mut rng = rand::thread_rng();
        let data: Vec<i8> = (0..dim)
            .map(|_| {
                if rng.gen::<f64>() > sparsity {
                    0
                } else if rng.gen::<bool>() {
                    1
                } else {
                    -1
                }
            })
            .collect();
        Self { data }
    }

    /// Create from slice of i8 values
    pub fn from_slice(data: &[i8]) -> Self {
        Self {
            data: data.iter().map(|&v| v.signum()).collect(),
        }
    }

    /// Vector dimension
    #[inline]
    pub fn len(&self) -> usize {
        self.data.len()
    }

    /// Check if empty
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }

    /// Get trit at index
    #[inline]
    pub fn get(&self, idx: usize) -> Trit {
        Trit::from_i8(self.data[idx])
    }

    /// Set trit at index
    #[inline]
    pub fn set(&mut self, idx: usize, trit: Trit) {
        self.data[idx] = trit.to_i8();
    }

    /// Get raw data slice
    #[inline]
    pub fn as_slice(&self) -> &[i8] {
        &self.data
    }

    /// Get mutable raw data slice
    #[inline]
    pub fn as_mut_slice(&mut self) -> &mut [i8] {
        &mut self.data
    }

    /// Count non-zero elements
    pub fn nnz(&self) -> usize {
        self.data.iter().filter(|&&v| v != 0).count()
    }

    /// Sparsity ratio (fraction of zeros)
    pub fn sparsity(&self) -> f64 {
        1.0 - (self.nnz() as f64 / self.len() as f64)
    }

    /// Negate all elements
    pub fn negate(&mut self) {
        for v in &mut self.data {
            *v = -*v;
        }
    }

    /// Create negated copy
    pub fn negated(&self) -> Self {
        Self {
            data: self.data.iter().map(|&v| -v).collect(),
        }
    }
}

impl std::ops::Index<usize> for TritVector {
    type Output = i8;

    fn index(&self, idx: usize) -> &Self::Output {
        &self.data[idx]
    }
}

impl std::ops::IndexMut<usize> for TritVector {
    fn index_mut(&mut self, idx: usize) -> &mut Self::Output {
        &mut self.data[idx]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_random() {
        let v = TritVector::random(1000);
        assert_eq!(v.len(), 1000);
        // All values should be in {-1, 0, 1}
        assert!(v.as_slice().iter().all(|&x| x >= -1 && x <= 1));
    }

    #[test]
    fn test_negate() {
        let mut v = TritVector::from_slice(&[1, 0, -1, 1, -1]);
        v.negate();
        assert_eq!(v.as_slice(), &[-1, 0, 1, -1, 1]);
    }
}
