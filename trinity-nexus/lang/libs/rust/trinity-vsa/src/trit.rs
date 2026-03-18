//! Balanced ternary trit type

use std::ops::{Add, Mul, Neg};

/// A single balanced ternary digit (trit)
/// 
/// Values: -1, 0, +1
/// 
/// # Properties
/// - Multiplication is sign selection: a * b
/// - Addition with saturation: clamp(a + b, -1, 1)
/// - Self-inverse: a * a = 1 (for non-zero)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
#[repr(i8)]
pub enum Trit {
    Neg = -1,
    #[default]
    Zero = 0,
    Pos = 1,
}

impl Trit {
    /// Create trit from i8 value
    #[inline]
    pub fn from_i8(v: i8) -> Self {
        match v.signum() {
            -1 => Trit::Neg,
            0 => Trit::Zero,
            1 => Trit::Pos,
            _ => unreachable!(),
        }
    }

    /// Convert to i8
    #[inline]
    pub fn to_i8(self) -> i8 {
        self as i8
    }

    /// Random trit with given probability of non-zero
    pub fn random(sparsity: f64) -> Self {
        use rand::Rng;
        let mut rng = rand::thread_rng();
        if rng.gen::<f64>() > sparsity {
            Trit::Zero
        } else if rng.gen::<bool>() {
            Trit::Pos
        } else {
            Trit::Neg
        }
    }
}

impl Neg for Trit {
    type Output = Self;

    #[inline]
    fn neg(self) -> Self {
        match self {
            Trit::Neg => Trit::Pos,
            Trit::Zero => Trit::Zero,
            Trit::Pos => Trit::Neg,
        }
    }
}

impl Mul for Trit {
    type Output = Self;

    #[inline]
    fn mul(self, rhs: Self) -> Self {
        Trit::from_i8(self.to_i8() * rhs.to_i8())
    }
}

impl Add for Trit {
    type Output = Self;

    #[inline]
    fn add(self, rhs: Self) -> Self {
        Trit::from_i8((self.to_i8() + rhs.to_i8()).clamp(-1, 1))
    }
}

impl From<i8> for Trit {
    fn from(v: i8) -> Self {
        Trit::from_i8(v)
    }
}

impl From<Trit> for i8 {
    fn from(t: Trit) -> Self {
        t.to_i8()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mul() {
        assert_eq!(Trit::Pos * Trit::Pos, Trit::Pos);
        assert_eq!(Trit::Pos * Trit::Neg, Trit::Neg);
        assert_eq!(Trit::Neg * Trit::Neg, Trit::Pos);
        assert_eq!(Trit::Zero * Trit::Pos, Trit::Zero);
    }

    #[test]
    fn test_neg() {
        assert_eq!(-Trit::Pos, Trit::Neg);
        assert_eq!(-Trit::Neg, Trit::Pos);
        assert_eq!(-Trit::Zero, Trit::Zero);
    }
}
