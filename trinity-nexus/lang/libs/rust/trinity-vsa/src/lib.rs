//! # Trinity VSA
//!
//! High-performance Vector Symbolic Architecture (VSA) library with balanced ternary arithmetic.
//!
//! ## Features
//!
//! - **Balanced Ternary**: Values in {-1, 0, +1} for efficient computation
//! - **VSA Operations**: bind, bundle, permute, similarity
//! - **SIMD Acceleration**: AVX-512, AVX2, NEON support
//! - **FPGA Ready**: Designed for hardware acceleration
//! - **Packed Storage**: 2 bits per trit, 256x memory savings
//!
//! ## Quick Start
//!
//! ```rust
//! use trinity_vsa::{TritVector, bind, bundle, similarity};
//!
//! // Create random hypervectors
//! let apple = TritVector::random(10000);
//! let red = TritVector::random(10000);
//!
//! // Bind: create association "red apple"
//! let red_apple = bind(&apple, &red);
//!
//! // Bundle: combine concepts
//! let fruits = bundle(&[&apple, &orange, &banana]);
//!
//! // Similarity: compare vectors
//! let sim = similarity(&red_apple, &apple);
//! ```
//!
//! ## Theory
//!
//! VSA represents concepts as high-dimensional vectors where:
//! - **Binding** (⊗): Creates associations via element-wise multiplication
//! - **Bundling** (+): Combines concepts via majority voting
//! - **Permutation** (ρ): Encodes sequences via circular shift
//!
//! Golden Identity: φ² + 1/φ² = 3

#![cfg_attr(feature = "simd", feature(portable_simd))]

mod trit;
mod vector;
mod packed;
mod sparse;
mod ops;
mod simd;

pub use trit::Trit;
pub use vector::TritVector;
pub use packed::PackedTritVec;
pub use sparse::SparseVec;
pub use ops::{bind, unbind, bundle, permute, similarity, hamming_distance};

/// Prelude for convenient imports
pub mod prelude {
    pub use crate::{Trit, TritVector, PackedTritVec, SparseVec};
    pub use crate::{bind, unbind, bundle, permute, similarity, hamming_distance};
}
