//! Sparse trit vector for high-dimensional data

use crate::{Trit, TritVector};
use std::collections::HashMap;

/// Sparse vector storing only non-zero elements
/// 
/// Efficient for vectors with >90% zeros (common in VSA)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SparseVec {
    /// Non-zero elements: index -> trit value
    data: HashMap<usize, i8>,
    /// Total dimension
    dim: usize,
}

impl SparseVec {
    /// Create empty sparse vector
    pub fn new(dim: usize) -> Self {
        Self {
            data: HashMap::new(),
            dim,
        }
    }

    /// Create from TritVector
    pub fn from_trit_vector(v: &TritVector) -> Self {
        let mut data = HashMap::new();
        for (i, &trit) in v.as_slice().iter().enumerate() {
            if trit != 0 {
                data.insert(i, trit);
            }
        }
        Self { data, dim: v.len() }
    }

    /// Convert to TritVector
    pub fn to_trit_vector(&self) -> TritVector {
        let mut result = vec![0i8; self.dim];
        for (&idx, &val) in &self.data {
            result[idx] = val;
        }
        TritVector::from_slice(&result)
    }

    /// Vector dimension
    #[inline]
    pub fn dim(&self) -> usize {
        self.dim
    }

    /// Number of non-zero elements
    #[inline]
    pub fn nnz(&self) -> usize {
        self.data.len()
    }

    /// Sparsity ratio
    pub fn sparsity(&self) -> f64 {
        1.0 - (self.nnz() as f64 / self.dim as f64)
    }

    /// Get trit at index
    pub fn get(&self, idx: usize) -> Trit {
        match self.data.get(&idx) {
            Some(&1) => Trit::Pos,
            Some(&-1) => Trit::Neg,
            _ => Trit::Zero,
        }
    }

    /// Set trit at index
    pub fn set(&mut self, idx: usize, trit: Trit) {
        match trit {
            Trit::Zero => { self.data.remove(&idx); }
            _ => { self.data.insert(idx, trit.to_i8()); }
        }
    }

    /// Sparse dot product (only iterates non-zeros)
    pub fn dot(&self, other: &SparseVec) -> i64 {
        assert_eq!(self.dim, other.dim);
        
        // Iterate over smaller set
        let (smaller, larger) = if self.nnz() < other.nnz() {
            (&self.data, &other.data)
        } else {
            (&other.data, &self.data)
        };
        
        smaller.iter()
            .filter_map(|(&idx, &val)| {
                larger.get(&idx).map(|&other_val| (val as i64) * (other_val as i64))
            })
            .sum()
    }

    /// Sparse bind (only non-zeros matter)
    pub fn bind(&self, other: &SparseVec) -> SparseVec {
        assert_eq!(self.dim, other.dim);
        
        let mut result = SparseVec::new(self.dim);
        
        // Result is non-zero only where both are non-zero
        for (&idx, &val) in &self.data {
            if let Some(&other_val) = other.data.get(&idx) {
                let prod = val * other_val;
                if prod != 0 {
                    result.data.insert(idx, prod);
                }
            }
        }
        
        result
    }

    /// Memory usage in bytes (approximate)
    pub fn memory_bytes(&self) -> usize {
        // HashMap overhead + entries
        std::mem::size_of::<HashMap<usize, i8>>() + self.nnz() * (8 + 1)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roundtrip() {
        let v = TritVector::random_sparse(1000, 0.1); // 10% non-zero
        let sparse = SparseVec::from_trit_vector(&v);
        let dense = sparse.to_trit_vector();
        assert_eq!(v, dense);
    }

    #[test]
    fn test_sparsity() {
        let v = TritVector::random_sparse(10000, 0.05); // 5% non-zero
        let sparse = SparseVec::from_trit_vector(&v);
        assert!(sparse.sparsity() > 0.9);
    }

    #[test]
    fn test_dot() {
        let a = TritVector::random_sparse(1000, 0.1);
        let b = TritVector::random_sparse(1000, 0.1);
        
        let sparse_a = SparseVec::from_trit_vector(&a);
        let sparse_b = SparseVec::from_trit_vector(&b);
        
        let sparse_dot = sparse_a.dot(&sparse_b);
        
        // Compare with dense dot
        let dense_dot: i64 = a.as_slice().iter()
            .zip(b.as_slice().iter())
            .map(|(&x, &y)| (x as i64) * (y as i64))
            .sum();
        
        assert_eq!(sparse_dot, dense_dot);
    }
}
