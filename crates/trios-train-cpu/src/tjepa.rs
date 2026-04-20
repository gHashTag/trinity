//! Ternary Joint-Embedding Predictive Architecture (T-JEPA)
//!
//! Research: EXP-012 to EXP-025

use rand::rngs::StdRng;
use rand::Rng;
use rand::SeedableRng;


// ============================================================================
// Mask Configuration (Span Masking)
// ============================================================================

/// Mask configuration for span masking
#[derive(Debug, Clone, Copy)]
pub struct MaskConfig {
    pub mask_ratio: f32,
    pub min_span: usize,
    pub max_span: usize,
    pub num_spans: usize,
}

impl Default for MaskConfig {
    fn default() -> Self {
        Self {
            mask_ratio: 0.3,
            min_span: 3,
            max_span: 9,
            num_spans: 2,
        }
    }
}

// ============================================================================
// EMA Synchronization
// ============================================================================

/// EMA synchronization for target encoder
#[derive(Debug, Clone, Copy)]
pub struct EmaSync {
    pub decay_start: f32,
    pub decay_end: f32,
}

impl Default for EmaSync {
    fn default() -> Self {
        Self {
            decay_start: 0.996,
            decay_end: 1.0,
        }
    }
}

/// Compute EMA decay at a given step
pub fn ema_decay(sync: &EmaSync, step: usize, max_steps: usize) -> f32 {
    let t = step as f64 / max_steps as f64;
    let decay_range = (sync.decay_end - sync.decay_start) as f64;
    ((sync.decay_start as f64) + t * decay_range) as f32
}

// ============================================================================
// Loss Functions (L2-Normalized MSE)
// ============================================================================

/// L2-normalized MSE loss (anti-collapse)
pub fn l2_normalized_mse(pred: &[f32], target: &[f32]) -> f32 {
    assert_eq!(pred.len(), target.len());

    let n = pred.len();

    let mut pred_mean: f64 = 0.0;
    let mut target_mean: f64 = 0.0;

    for i in 0..n {
        pred_mean += pred[i] as f64;
        target_mean += target[i] as f64;
    }

    pred_mean /= n as f64;
    target_mean /= n as f64;

    let mut pred_norm: f64 = 0.0;
    let mut target_norm: f64 = 0.0;

    for i in 0..n {
        pred_norm += (pred[i] as f64 - pred_mean).powi(2);
        target_norm += (target[i] as f64 - target_mean).powi(2);
    }

    let pred_std = pred_norm.sqrt().max(1e-8);
    let target_std = target_norm.sqrt().max(1e-8);

    let mut mse = 0.0_f64;
    for i in 0..n {
        let pred_norm = (pred[i] as f64 - pred_mean) / pred_std;
        let target_norm = (target[i] as f64 - target_mean) / target_std;
        mse += (pred_norm - target_norm).powi(2);
    }

    (mse / n as f64) as f32
}

/// Standard MSE (for comparison)
pub fn mse(pred: &[f32], target: &[f32]) -> f32 {
    let mut sum = 0.0_f32;
    for i in 0..pred.len() {
        let diff = pred[i] - target[i];
        sum += diff * diff;
    }
    sum / pred.len() as f32
}

// ============================================================================
// T-JEPA Predictor
// ============================================================================

/// T-JEPA predictor (1 TrinityBlock + Linear projection)
#[derive(Debug, Clone)]
pub struct TjepaPredictor {
    pub d_input: usize,
    pub d_output: usize,
    pub weight: Vec<f32>,
    pub bias: Option<Vec<f32>>,
    pub is_training: bool,
}

impl TjepaPredictor {
    pub fn new(d_input: usize, d_output: usize) -> Self {
        let weight = vec![0.0_f32; d_input * d_output];
        let bias = Some(vec![0.0_f32; d_output]);

        Self {
            d_input,
            d_output,
            weight,
            bias,
            is_training: true,
        }
    }

    pub fn from_trinity_dims(dims: &crate::forward::LayerDims) -> Self {
        Self::new(dims.d_model, dims.d_model)
    }

    pub fn generate_mask(&self, seq_len: usize, config: &MaskConfig) -> Vec<usize> {
        let num_masked = (seq_len as f32 * config.mask_ratio) as usize;
        let mut rng = StdRng::seed_from_u64(42);

        let mut mask_indices = Vec::with_capacity(num_masked * config.num_spans);

        for _ in 0..config.num_spans {
            let start = rng.gen_range(0..seq_len.saturating_sub(config.max_span));
            let span_len = rng.gen_range(config.min_span..=config.max_span);
            let end = (start + span_len).min(seq_len);

            for i in start..end {
                mask_indices.push(i);
            }
        }

        mask_indices
    }

    pub fn forward(&self, input: &[f32]) -> Vec<f32> {
        let mut output = vec![0.0_f32; self.d_output];

        for i in 0..self.d_output {
            let mut sum = 0.0_f32;
            for j in 0..self.d_input {
                sum += input[j] * self.weight[j * self.d_output + i];
            }
            output[i] = sum + self.bias.as_ref().map(|b| b[i]).unwrap_or(0.0);
        }

        output
    }

    pub fn compute_loss(&self, pred: &[f32], target: &[f32]) -> f32 {
        l2_normalized_mse(pred, target)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mask_config_default() {
        let config = MaskConfig::default();
        assert_eq!(config.mask_ratio, 0.3);
        assert_eq!(config.min_span, 3);
        assert_eq!(config.max_span, 9);
        assert_eq!(config.num_spans, 2);
    }

    #[test]
    fn test_ema_sync_default() {
        let sync = EmaSync::default();
        assert_eq!(sync.decay_start, 0.996);
        assert_eq!(sync.decay_end, 1.0);
    }

    #[test]
    fn test_ema_decay_schedule() {
        let sync = EmaSync::default();

        let decay_0 = ema_decay(&sync, 0, 50000);
        assert!((decay_0 - 0.996).abs() < 1e-6);

        let decay_25k = ema_decay(&sync, 25000, 50000);
        assert!((decay_25k - 0.998).abs() < 1e-6);

        let decay_50k = ema_decay(&sync, 50000, 50000);
        assert!((decay_50k - 1.0).abs() < 1e-6);
    }

    #[test]
    fn test_l2_normalized_mse() {
        let pred = vec![1.0, 2.0, 3.0, 4.0];
        let target = vec![4.0, 2.0, 1.0, 3.0];  // Different order, should have positive loss

        let loss = l2_normalized_mse(&pred, &target);

        assert!(loss > 0.0);

        let loss_sym = l2_normalized_mse(&target, &pred);
        assert!((loss - loss_sym).abs() < 1e-6);
    }

    #[test]
    fn test_mse() {
        let pred = vec![1.0, 2.0, 3.0, 4.0];
        let target = vec![1.5, 2.5, 3.5, 4.5];

        let loss = mse(&pred, &target);

        assert!(loss > 0.0);
    }

    #[test]
    fn test_tjepa_predictor_creation() {
        let predictor = TjepaPredictor::new(243, 243);

        assert_eq!(predictor.d_input, 243);
        assert_eq!(predictor.d_output, 243);
        assert_eq!(predictor.weight.len(), 243 * 243);
        assert!(predictor.bias.is_some());
    }

    #[test]
    fn test_tjepa_forward() {
        let mut predictor = TjepaPredictor::new(2, 2);
        // Row-major layout: weight[j * d_output + i]
        // For output[0]: input[0]*weight[0] + input[1]*weight[2] + bias[0]
        // For output[1]: input[0]*weight[1] + input[1]*weight[3] + bias[1]
        predictor.weight = vec![1.0, 2.0, 3.0, 4.0];
        predictor.bias = Some(vec![0.1, 0.2]);

        let input = vec![1.0, 2.0];
        let output = predictor.forward(&input);

        // output[0] = 1.0*1.0 + 2.0*3.0 + 0.1 = 1.0 + 6.0 + 0.1 = 7.1
        // output[1] = 1.0*2.0 + 2.0*4.0 + 0.2 = 2.0 + 8.0 + 0.2 = 10.2
        assert!((output[0] - 7.1).abs() < 1e-6);
        assert!((output[1] - 10.2).abs() < 1e-6);
    }

    #[test]
    fn test_generate_mask() {
        let predictor = TjepaPredictor::new(81, 81);
        let config = MaskConfig::default();

        let mask = predictor.generate_mask(81, &config);

        // With mask_ratio=0.3, num_spans=2, min_span=3, max_span=9:
        // Expected range: 2*3=6 to 2*9=18 masked tokens
        assert!(mask.len() >= 6);
        assert!(mask.len() <= 18);
    }
}
