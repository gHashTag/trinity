//! Packed trit vector with bitsliced storage

use crate::{Trit, TritVector};

/// Packed trit vector using 2 bits per trit
/// 
/// Encoding:
/// - 00 = 0
/// - 01 = +1
/// - 10 = -1
/// - 11 = reserved
/// 
/// Memory savings: 4x compared to i8 storage
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackedTritVec {
    /// Positive bits (1 where trit = +1)
    pos: Vec<u64>,
    /// Negative bits (1 where trit = -1)
    neg: Vec<u64>,
    /// Number of trits
    len: usize,
}

impl PackedTritVec {
    /// Create zero vector
    pub fn zeros(len: usize) -> Self {
        let num_words = (len + 63) / 64;
        Self {
            pos: vec![0; num_words],
            neg: vec![0; num_words],
            len,
        }
    }

    /// Create from TritVector
    pub fn from_trit_vector(v: &TritVector) -> Self {
        let len = v.len();
        let num_words = (len + 63) / 64;
        let mut pos = vec![0u64; num_words];
        let mut neg = vec![0u64; num_words];

        for (i, &trit) in v.as_slice().iter().enumerate() {
            let word_idx = i / 64;
            let bit_idx = i % 64;
            match trit {
                1 => pos[word_idx] |= 1u64 << bit_idx,
                -1 => neg[word_idx] |= 1u64 << bit_idx,
                _ => {}
            }
        }

        Self { pos, neg, len }
    }

    /// Convert to TritVector
    pub fn to_trit_vector(&self) -> TritVector {
        let mut data = vec![0i8; self.len];
        
        for i in 0..self.len {
            let word_idx = i / 64;
            let bit_idx = i % 64;
            let mask = 1u64 << bit_idx;
            
            if self.pos[word_idx] & mask != 0 {
                data[i] = 1;
            } else if self.neg[word_idx] & mask != 0 {
                data[i] = -1;
            }
        }
        
        TritVector::from_slice(&data)
    }

    /// Vector length
    #[inline]
    pub fn len(&self) -> usize {
        self.len
    }

    /// Check if empty
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    /// Get trit at index
    pub fn get(&self, idx: usize) -> Trit {
        assert!(idx < self.len);
        let word_idx = idx / 64;
        let bit_idx = idx % 64;
        let mask = 1u64 << bit_idx;

        if self.pos[word_idx] & mask != 0 {
            Trit::Pos
        } else if self.neg[word_idx] & mask != 0 {
            Trit::Neg
        } else {
            Trit::Zero
        }
    }

    /// Set trit at index
    pub fn set(&mut self, idx: usize, trit: Trit) {
        assert!(idx < self.len);
        let word_idx = idx / 64;
        let bit_idx = idx % 64;
        let mask = 1u64 << bit_idx;

        // Clear both bits
        self.pos[word_idx] &= !mask;
        self.neg[word_idx] &= !mask;

        // Set appropriate bit
        match trit {
            Trit::Pos => self.pos[word_idx] |= mask,
            Trit::Neg => self.neg[word_idx] |= mask,
            Trit::Zero => {}
        }
    }

    /// Fast bind using bitwise operations
    pub fn bind(&self, other: &PackedTritVec) -> PackedTritVec {
        assert_eq!(self.len, other.len);
        
        let mut result = PackedTritVec::zeros(self.len);
        
        for i in 0..self.pos.len() {
            // Multiplication table for balanced ternary:
            // (+1) * (+1) = +1, (+1) * (-1) = -1, (+1) * 0 = 0
            // (-1) * (+1) = -1, (-1) * (-1) = +1, (-1) * 0 = 0
            // 0 * anything = 0
            
            // Result is +1 when: (a=+1 AND b=+1) OR (a=-1 AND b=-1)
            result.pos[i] = (self.pos[i] & other.pos[i]) | (self.neg[i] & other.neg[i]);
            
            // Result is -1 when: (a=+1 AND b=-1) OR (a=-1 AND b=+1)
            result.neg[i] = (self.pos[i] & other.neg[i]) | (self.neg[i] & other.pos[i]);
        }
        
        result
    }

    /// Fast dot product using popcount
    pub fn dot(&self, other: &PackedTritVec) -> i64 {
        assert_eq!(self.len, other.len);
        
        let mut sum: i64 = 0;
        
        for i in 0..self.pos.len() {
            // Count +1 * +1 and -1 * -1 (contribute +1)
            let pos_pos = (self.pos[i] & other.pos[i]).count_ones() as i64;
            let neg_neg = (self.neg[i] & other.neg[i]).count_ones() as i64;
            
            // Count +1 * -1 and -1 * +1 (contribute -1)
            let pos_neg = (self.pos[i] & other.neg[i]).count_ones() as i64;
            let neg_pos = (self.neg[i] & other.pos[i]).count_ones() as i64;
            
            sum += pos_pos + neg_neg - pos_neg - neg_pos;
        }
        
        sum
    }

    /// Memory usage in bytes
    pub fn memory_bytes(&self) -> usize {
        self.pos.len() * 8 * 2 // Two u64 arrays
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_roundtrip() {
        let v = TritVector::random(1000);
        let packed = PackedTritVec::from_trit_vector(&v);
        let unpacked = packed.to_trit_vector();
        assert_eq!(v, unpacked);
    }

    #[test]
    fn test_bind() {
        let a = TritVector::random(1000);
        let b = TritVector::random(1000);
        
        let packed_a = PackedTritVec::from_trit_vector(&a);
        let packed_b = PackedTritVec::from_trit_vector(&b);
        
        let packed_result = packed_a.bind(&packed_b);
        let result = packed_result.to_trit_vector();
        
        // Compare with dense bind
        let expected = crate::bind(&a, &b);
        assert_eq!(result, expected);
    }

    #[test]
    fn test_memory_savings() {
        let dim = 10000;
        let dense_bytes = dim; // 1 byte per trit
        let packed = PackedTritVec::zeros(dim);
        let packed_bytes = packed.memory_bytes();
        
        // Should be ~4x smaller
        assert!(packed_bytes < dense_bytes / 3);
    }
}
