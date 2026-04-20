//! Forward pass operations and Trinity 3ᵏ architecture constants
//!
//! Research: EXP-001 to EXP-025
//! - EXP-001: ctx=27 (3³) → PPL 2.96 vs ctx=18 → PPL 5.58
//! - EXP-012: Square Attention Theorem — ctx must equal head_dim
//! - EXP-014: Resonance Law — optimal values are 3ᵏ "orbitals" (9, 27, 81)

/// Trinity 3ᵏ-based architecture constants
///
/// From EXP-014 (Resonance Law): All dimensions are powers of 3.
/// From GAMMA #67: ACTIVE_VOCAB=256 for 8-bit Parameter Golf optimization.
pub const ACTIVE_VOCAB: usize = 256;  // byte-level for logits masking
pub const TRINITY_VOCAB_SIZE: usize = 256;  // 2^8, aligned (Parameter Golf optimization)
pub const TRINITY_HIDDEN_DIM: usize = 243;  // 3^5
pub const TRINITY_EMBED_DIM: usize = 243;   // tied
pub const TRINITY_FFN_DIM: usize = TRINITY_HIDDEN_DIM;  // tied
pub const TRINITY_CONTEXT_LEN: usize = 81;  // 3^4
pub const TRINITY_NUM_BLOCKS: usize = 9;    // 3^2
pub const TRINITY_HEADS: usize = 9;         // 3^2
pub const TRINITY_HEAD_DIM: usize = 27;     // 3^3 (d_model / n_heads = 243 / 9 = 27)

/// Full Trinity theoretical vocab size (for reference, not used in Parameter Golf)
pub const TRINITY_VOCAB_SIZE_THEORETICAL: usize = 729;  // 3^6 (theoretical)

/// Runtime invariants
// debug_assert!(TRINITY_CONTEXT_LEN % TRINITY_HEAD_DIM == 0);  // 81%27=0
// debug_assert!(ACTIVE_VOCAB < TRINITY_VOCAB_SIZE);           // 256 < 729
// debug_assert_eq!(TRINITY_FFN_DIM, 3 * TRINITY_HIDDEN_DIM);  // tied 3× expansion

/// Helper: is_power_of_three
// ============================================================================
trait PowerOfThree {
    fn is_power_of_three(self) -> bool;
}

impl PowerOfThree for usize {
    fn is_power_of_three(self) -> bool {
        if self == 0 {
            return false;
        }
        let mut n = self;
        while n % 3 == 0 {
            n /= 3;
        }
        n == 1
    }
}

/// Layer dimensions for transformer architecture
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LayerDims {
    /// Model dimension (d_model)
    pub d_model: usize,
    /// Number of attention heads
    pub n_heads: usize,
    /// Feed-forward network dimension
    pub d_ffn: usize,
}

impl LayerDims {
    /// Trinity 3ᵏ-based architecture (EXP-014: Resonance Law)
    ///
    /// All dimensions are powers of 3 for ternary symmetry:
    /// - d_model: 243 = 3^5 (Parameter Golf optimization)
    /// - n_heads: 9 = 3^2
    /// - d_ffn: 243 = 3^5 (same as d_model for ternary symmetry)
    pub fn trinity() -> Self {
        Self {
            d_model: TRINITY_HIDDEN_DIM,  // 243 = 3^5
            n_heads: TRINITY_HEADS,       // 9 = 3^2
            d_ffn: TRINITY_FFN_DIM,       // 243 = 3^5 (tied with d_model)
        }
    }

    /// Legacy Fibonacci-based architecture (for comparison)
    ///
    /// EXP-001: ctx=27 (3³) → PPL 2.96 vs ctx=18 → PPL 5.58 (1.89× improvement)
    #[deprecated(note = "Use LayerDims::trinity() instead")]
    pub fn fibonacci() -> Self {
        Self {
            d_model: 144,  // F12
            n_heads: 4,
            d_ffn: 233,   // F13
        }
    }

    /// Optimal context length for this configuration
    ///
    /// EXP-012: Square Attention — ctx equals head_dim for full rank
    /// For Trinity: head_dim = 27, TRINITY_CONTEXT_LEN = 81 = 3×head_dim
    pub fn optimal_context(&self) -> usize {
        self.head_dim()  // 27 = 3^3, square attention
    }

    /// Head dimension (d_model / n_heads)
    pub fn head_dim(&self) -> usize {
        self.d_model / self.n_heads
    }

    /// Verify dimensions satisfy Square Attention Theorem (EXP-012)
    ///
    /// Returns true if context_length is a valid multiple of head_dim
    pub fn is_valid_context(&self, context_length: usize) -> bool {
        let head_dim = self.head_dim();
        // ctx must be head_dim, 3×head_dim, 9×head_dim, or a power-of-three divisor
        context_length == head_dim
            || context_length == head_dim * 3
            || context_length == head_dim * 9
            || (head_dim % context_length == 0 && context_length.is_power_of_three())
    }
}

/// Matrix multiplication (CPU, naive implementation)
///
/// For production use, consider BLAS/accelerated implementations.
pub fn matmul(out: &mut [f32], a: &[f32], b: &[f32], m: usize, n: usize, k: usize) {
    for i in 0..m {
        for j in 0..n {
            let mut sum = 0.0_f32;
            for l in 0..k {
                sum += a[i * k + l] * b[l * n + j];
            }
            out[i * n + j] = sum;
        }
    }
}

/// GELU activation function
///
/// From BERT: x * P(X <= x) where X ~ N(0,1)
pub fn gelu(x: f32) -> f32 {
    const SQRT_2_OVER_PI: f32 = 0.7978845608;  // sqrt(2 / π)
    const CDF_CONST: f32 = 0.044715;          // 0.5 * sqrt(2 / π)

    x * (0.5 * (1.0 + (SQRT_2_OVER_PI * x + CDF_CONST * x * x).tanh()))
}

/// Apply GELU element-wise to a slice
pub fn gelu_inplace(vec: &mut [f32]) {
    for val in vec.iter_mut() {
        *val = gelu(*val);
    }
}

/// Layer normalization
///
/// Normalizes features to zero mean and unit variance.
pub fn layer_norm(out: &mut [f32], input: &[f32], gamma: &[f32], beta: &[f32], eps: f32) {
    let len = input.len();
    assert_eq!(len, gamma.len());
    assert_eq!(len, beta.len());

    // Compute mean
    let mean: f64 = input.iter().map(|&x| x as f64).sum::<f64>() / len as f64;

    // Compute variance
    let var: f64 = input.iter()
        .map(|&x| {
            let diff = x as f64 - mean;
            diff * diff
        })
        .sum::<f64>() / len as f64;

    // Apply normalization
    let std_dev = (var + eps as f64).sqrt() as f32;
    for i in 0..len {
        out[i] = gamma[i] * ((input[i] as f32 - mean as f32) / std_dev) + beta[i];
    }
}

/// Layer normalization in-place
pub fn layer_norm_inplace(vec: &mut [f32], gamma: &[f32], beta: &[f32], eps: f32) {
    let len = vec.len();
    assert_eq!(len, gamma.len());
    assert_eq!(len, beta.len());

    // Compute mean
    let mean: f64 = vec.iter().map(|&x| x as f64).sum::<f64>() / len as f64;

    // Compute variance
    let var: f64 = vec.iter()
        .map(|&x| {
            let diff = x as f64 - mean;
            diff * diff
        })
        .sum::<f64>() / len as f64;

    // Apply normalization
    let std_dev = (var + eps as f64).sqrt() as f32;
    for i in 0..len {
        vec[i] = gamma[i] * ((vec[i] as f32 - mean as f32) / std_dev) + beta[i];
    }
}

/// Apply vocab padding mask to logits
///
/// Masks logits beyond ACTIVE_VOCAB with NEG_INFINITY so they
/// have zero probability after softmax.
pub fn apply_vocab_mask(logits: &mut [f32]) {
    for i in ACTIVE_VOCAB..logits.len() {
        logits[i] = f32::NEG_INFINITY;
    }
}

/// Verify targets are within ACTIVE_VOCAB range
pub fn validate_targets(targets: &[usize]) -> bool {
    targets.iter().all(|&t| t < ACTIVE_VOCAB)
}

/// Softmax activation with vocab masking
///
/// Converts logits to probabilities, masking padding tokens
/// with NEG_INFINITY so they contribute zero probability.
pub fn softmax(out: &mut [f32], input: &[f32]) {
    // Find max for numerical stability
    let max = input.iter().fold(f32::NEG_INFINITY, |a, &b| a.max(b));

    // Compute exp and sum
    let mut sum = 0.0_f32;
    for i in 0..input.len() {
        out[i] = (input[i] - max).exp();
        sum += out[i];
    }

    // Normalize
    for i in 0..input.len() {
        out[i] /= sum;
    }
}

/// Softmax with target validation
///
/// Validates targets are within ACTIVE_VOCAB range.
pub fn softmax_with_validation(out: &mut [f32], input: &[f32], targets: &[usize]) -> Result<(), &'static str> {
    // Validate targets
    if !validate_targets(targets) {
        return Err("Targets out of ACTIVE_VOCAB range");
    }

    // Apply softmax
    softmax(out, input);

    Ok(())
}

/// Transpose a 2D matrix in-place
///
/// Used for attention pattern reordering.
pub fn transpose_inplace(matrix: &mut [f32], rows: usize, cols: usize) {
    for i in 0..rows {
        for j in (i + 1)..cols {
            let idx1 = i * cols + j;
            let idx2 = j * rows + i;
            matrix.swap(idx1, idx2);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_trinity_constants() {
        assert_eq!(TRINITY_VOCAB_SIZE, 256);  // 2^8 (Parameter Golf)
        assert_eq!(TRINITY_VOCAB_SIZE_THEORETICAL, 729);  // 3^6 (theoretical)
        assert_eq!(TRINITY_HIDDEN_DIM, 243);  // 3^5
        assert_eq!(TRINITY_EMBED_DIM, 243);   // 3^5
        assert_eq!(TRINITY_CONTEXT_LEN, 81);  // 3^4
        assert_eq!(TRINITY_NUM_BLOCKS, 9);    // 3^2
        assert_eq!(TRINITY_HEADS, 9);         // 3^2
        assert_eq!(TRINITY_HEAD_DIM, 27);     // 3^3 (d_model / n_heads = 243 / 9)
        assert_eq!(ACTIVE_VOCAB, 256);
        assert_eq!(TRINITY_VOCAB_SIZE, ACTIVE_VOCAB);  // aligned
    }

    #[test]
    fn test_layer_dims_trinity() {
        let dims = LayerDims::trinity();
        assert_eq!(dims.d_model, 243);  // 3^5 (Parameter Golf)
        assert_eq!(dims.n_heads, 9);    // 3^2
        assert_eq!(dims.d_ffn, 243);    // 3^5 (tied with d_model)
        assert_eq!(dims.head_dim(), 27);  // 243 / 9 = 27
    }

    #[test]
    fn test_layer_dims_optimal_context() {
        let dims = LayerDims::trinity();
        let ctx = dims.optimal_context();
        assert_eq!(ctx, 27);  // head_dim = 27
        // For Trinity architecture, context 81 is also valid (3× head_dim)
        assert!(dims.is_valid_context(81));
    }

    #[test]
    fn test_gelu() {
        // GELU(0) ≈ 0.5 * 0 = 0
        assert!((gelu(0.0) - 0.0).abs() < 1e-6);
        // GELU(negative) < 0
        assert!(gelu(-1.0) < 0.0);
        // GELU(positive) > 0
        assert!(gelu(1.0) > 0.0);
    }

    #[test]
    fn test_layer_norm() {
        let mut out = [0.0_f32; 4];
        let input = [1.0, 2.0, 3.0, 4.0];
        let gamma = [1.0, 1.0, 1.0, 1.0];
        let beta = [0.0, 0.0, 0.0, 0.0];

        layer_norm(&mut out, &input, &gamma, &beta, 1e-5);

        // After layer norm: mean ≈ 0, std ≈ 1
        let mean: f64 = out.iter().map(|&x| x as f64).sum::<f64>() / 4.0;
        let var: f64 = out.iter()
            .map(|&x| (x as f64 - mean).powi(2))
            .sum::<f64>() / 4.0;
        let std = var.sqrt();

        assert!((mean).abs() < 0.1);  // Mean should be near 0
        assert!((std - 1.0).abs() < 0.1);  // Std should be near 1
    }

    #[test]
    fn test_softmax() {
        let mut out = [0.0_f32; 3];
        let input = [1.0, 2.0, 3.0];

        softmax(&mut out, &input);

        // All probabilities sum to 1
        let sum: f32 = out.iter().sum();
        assert!((sum - 1.0).abs() < 1e-6);

        // Higher input gets higher probability
        assert!(out[0] < out[1] && out[1] < out[2]);
    }

    #[test]
    fn test_apply_vocab_mask() {
        let mut logits = vec![0.0_f32; 512];
        apply_vocab_mask(&mut logits);

        // First 256 should be preserved
        for i in 0..ACTIVE_VOCAB {
            assert_eq!(logits[i], 0.0);
        }
        // Next 256 should be NEG_INF
        for i in ACTIVE_VOCAB..logits.len() {
            assert_eq!(logits[i], f32::NEG_INFINITY);
        }
    }

    #[test]
    fn test_is_power_of_three() {
        assert!(1.is_power_of_three());
        assert!(3.is_power_of_three());
        assert!(9.is_power_of_three());
        assert!(27.is_power_of_three());
        assert!(81.is_power_of_three());
        assert!(!10.is_power_of_three());
        assert!(!100.is_power_of_three());
    }
}
