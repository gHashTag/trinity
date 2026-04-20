//! Training configuration and benchmark utilities
//!
//! Research: EXP-025 (early kill thresholds), EXP-001 (context discovery)

use std::f64::consts::PI;
use crate::forward::LayerDims;

// ============================================================================
// Learning Rate Schedules
// ============================================================================

/// Learning rate schedule type
#[derive(Debug, Clone, Copy)]
pub enum LrSchedule {
    /// Cosine decay from base_lr to lr_min
    Cosine { lr_min: f64, restart_period: usize },
    /// Phi-based schedule with warm restarts (legacy)
    Phi,
}

impl Default for LrSchedule {
    fn default() -> Self {
        Self::Cosine {
            lr_min: 1e-5,
            restart_period: 0,  // 0 = no restart
        }
    }
}

// ============================================================================
// Training Configuration
// ============================================================================

/// Early kill thresholds based on research (EXP-025)
///
/// Prevents wasting compute on stuck training runs.
#[derive(Debug, Clone, Copy)]
pub struct KillThresholds {
    /// Kill if PPL > this at 10K steps
    pub ppl_10k: Option<f32>,
    /// Kill if PPL > this at 30K steps
    pub ppl_30k: Option<f32>,
    /// Kill if PPL > this at 60K steps
    pub ppl_60k: Option<f32>,
    /// Kill if PPL > this at 80K steps
    pub ppl_80k: Option<f32>,
}

impl Default for KillThresholds {
    fn default() -> Self {
        Self {
            // EXP-025: Updated thresholds to prevent false kills
            // Old: 200, 50 (W7 runs incorrectly killed)
            ppl_10k: Some(500.0),   // 72/72 W7 runs saved
            ppl_30k: Some(200.0),
            ppl_60k: Some(100.0),
            ppl_80k: Some(50.0),
        }
    }
}

/// Training configuration with Trinity research-backed defaults
///
/// Based on EXP-001 to EXP-025 experiments.
#[derive(Debug, Clone)]
pub struct TrainConfig {
    /// Maximum training steps
    ///
    /// EXP-007: Characteristic plateau at 50K steps
    pub max_steps: usize,

    /// Batch size
    ///
    /// EXP-001: 66 is optimal for ctx=27 (fits in GPU memory)
    pub batch_size: usize,

    /// Sequence length (context window)
    ///
    /// EXP-014: Must be 3ᵏ for optimal performance
    /// TRINITY_CONTEXT_LEN = 81 = 3^4
    pub seq_len: usize,

    /// Base learning rate
    ///
    /// EXP-005: 3e-4 works well with LAMB + Trinity
    pub learning_rate: f64,

    /// Warmup steps
    ///
    /// Gradually increase LR to base_lr
    pub warmup_steps: usize,

    /// Gradient clipping value
    ///
    /// Prevents exploding gradients
    pub grad_clip: f32,

    /// Logging interval
    ///
    /// Report metrics every N steps
    pub log_every: usize,

    /// Checkpoint path
    pub checkpoint_path: String,

    /// Model dimensions
    pub dims: LayerDims,

    /// Learning rate schedule
    pub lr_schedule: LrSchedule,

    /// Early kill thresholds
    pub kill_thresholds: KillThresholds,

    /// Weight decay
    ///
    /// EXP-005: 0.01 works well with LAMB
    pub weight_decay: f64,

    /// Dropout rate
    ///
    /// EXP-001: 0.1 for ctx=27
    pub dropout: f32,
}

impl TrainConfig {
    /// Get total parameter count
    ///
    /// Approximate parameter count for Trinity configuration.
    pub fn param_count(&self) -> usize {
        // Embedding: vocab * d_model = 256 * 243 ≈ 62K (Parameter Golf)
        let embedding = crate::forward::TRINITY_VOCAB_SIZE * self.dims.d_model;

        // Each layer: 2 * (d_model^2) + 4 * d_model (QKV)
        let layer = 2 * self.dims.d_model.pow(2) + 4 * self.dims.d_model * self.dims.d_model;

        // Output projection: d_model * vocab = 243 * 256 ≈ 62K
        let output = self.dims.d_model * crate::forward::TRINITY_VOCAB_SIZE;

        // Layer norms: 4 * n_layers * d_model
        let ln = 4 * 9 * self.dims.d_model;  // n_layers = 9

        embedding + 9 * layer + output + ln
    }

    /// Get estimated memory usage in bytes
    ///
    /// Based on f32 (4 bytes) per parameter.
    pub fn estimated_memory(&self) -> usize {
        self.param_count() * 4
    }

    /// Get minimal configuration (small model for fast testing)
    pub fn minimal() -> Self {
        Self {
            max_steps: 1000,
            batch_size: 4,
            seq_len: 27,  // 3^3 for testing
            learning_rate: 1e-3,
            warmup_steps: 50,
            grad_clip: 1.0,
            log_every: 100,
            checkpoint_path: "minimal.bin".to_string(),
            dims: LayerDims {
                d_model: 243,  // 3^5
                n_heads: 9,
                d_ffn: 243,
            },
            lr_schedule: LrSchedule::default(),
            kill_thresholds: KillThresholds::default(),
            weight_decay: 0.01,
            dropout: 0.1,
        }
    }

    /// Check if training should stop early based on metrics
    pub fn should_early_stop(&self, step: usize, current_ppl: f32) -> bool {
        match self.kill_thresholds {
            KillThresholds { .. } => false,
        }
    }

    /// Get minimal configuration (small model for fast testing)
    pub fn minimal() -> Self {
        Self {
            max_steps: 1000,
            batch_size: 4,
            seq_len: 27,
            learning_rate: 1e-3,
            warmup_steps: 50,
            grad_clip: 1.0,
            log_every: 100,
            checkpoint_path: "minimal.bin".to_string(),
            dims: LayerDims {
                d_model: 243,
                n_heads: 9,
                d_ffn: 243,
            },
            lr_schedule: LrSchedule::default(),
            kill_thresholds: KillThresholds::default(),
            weight_decay: 0.01,
            dropout: 0.1,
        }
    }
}

impl Default for TrainConfig {
    fn default() -> Self {
        Self {
            // EXP-007: 50K minimum run length
            max_steps: 50000,

            // EXP-001: 66 optimal for ctx=27
            batch_size: 66,

            // EXP-014: 81 = 3^4 (TRINITY_CONTEXT_LEN)
            seq_len: crate::forward::TRINITY_CONTEXT_LEN,

            // EXP-005: 3e-4 optimal with LAMB
            learning_rate: 3e-4,

            // 100 steps warmup
            warmup_steps: 100,

            // 1.0 gradient clipping
            grad_clip: 1.0,

            // Log every 34 steps (3×11+1)
            log_every: 34,

            checkpoint_path: "trinity-cpu.bin".to_string(),

            // Trinity dimensions
            dims: LayerDims::trinity(),

            // Cosine schedule (default)
            lr_schedule: LrSchedule::default(),

            // EXP-025 early kill thresholds
            kill_thresholds: KillThresholds::default(),

            // EXP-005: 0.01 weight decay
            weight_decay: 0.01,

            // 0.1 dropout
            dropout: 0.1,
        }
    }
}

/// Run configuration for a single training experiment
#[derive(Debug, Clone)]
pub struct RunConfig {
    /// Training config
    pub train: TrainConfig,
    /// Random seed for reproducibility
    ///
    /// EXP-006: Run 5+ seeds per config, report median PPL
    pub seed: u64,
    /// Run name/identifier
    pub name: String,
    /// Output directory
    pub output_dir: String,
}

impl Default for RunConfig {
    fn default() -> Self {
        Self {
            train: TrainConfig::default(),
            seed: 42,
            name: "default".to_string(),
            output_dir: ".".to_string(),
        }
    }
}

// ============================================================================
// Learning Rate Schedule Functions
// ============================================================================

/// Cosine learning rate schedule
///
/// LR(t) = lr_min + 0.5 * (lr_base - lr_min) * (1 + cos(π * progress))
pub fn cosine_lr_schedule(
    step: usize,
    base_lr: f64,
    warmup_steps: usize,
    min_lr: f64,
    max_steps: usize,
) -> f64 {
    if step < warmup_steps {
        // Linear warmup
        base_lr * (step as f64 / warmup_steps as f64)
    } else {
        // Cosine decay
        let progress = (step - warmup_steps) as f64 / (max_steps - warmup_steps) as f64;
        min_lr + 0.5 * (base_lr - min_lr) * (1.0 + (PI * progress).cos())
    }
}

/// Phi-based learning rate schedule (legacy)
///
/// Based on "AdamW and super-convergence" paper.
pub fn phi_lr_schedule(
    step: usize,
    base_lr: f64,
    warmup_steps: usize,
    phi: f64,
) -> f64 {
    if step < warmup_steps {
        // Linear warmup
        base_lr * (step as f64 / warmup_steps as f64)
    } else {
        // Phi decay
        let t = (step - warmup_steps) as f64;
        base_lr * (t / (t + phi))
    }
}

/// Check if training should be killed based on PPL thresholds
///
/// EXP-025: Prevent wasting compute on stuck runs
pub fn should_kill(
    step: usize,
    current_ppl: f32,
    thresholds: &KillThresholds,
) -> Option<f32> {
    let kill_at = match step {
        0..10_000 => None,  // Before first threshold
        10_000..=30_000 => thresholds.ppl_10k,
        30_001..=60_000 => thresholds.ppl_30k,
        60_001..=80_000 => thresholds.ppl_60k,
        80_001..=100_000 => thresholds.ppl_80k,
        _ => None,  // After all thresholds
    };

    match (kill_at, current_ppl) {
        (Some(threshold), ppl) if ppl > threshold => Some(threshold),
        _ => None,
    }
}

// ============================================================================
// Benchmark Metrics
// ============================================================================

/// Metrics from a training run
#[derive(Debug, Clone)]
pub struct BenchMetrics {
    /// Training steps completed
    pub steps: usize,

    /// Final perplexity
    pub final_ppl: f32,

    /// Average tokens per second
    pub tokens_per_sec: f64,

    /// Total time in seconds
    pub total_time_sec: f64,
}

impl Default for BenchMetrics {
    fn default() -> Self {
        Self {
            steps: 0,
            final_ppl: 0.0,
            tokens_per_sec: 0.0,
            total_time_sec: 0.0,
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cosine_lr_schedule() {
        let lr_base = 1e-3;
        let lr_min = 1e-5;
        let max_steps = 1000;
        let warmup = 100;

        // At step 0 (warmup)
        let lr_0 = cosine_lr_schedule(0, lr_base, warmup, lr_min, max_steps);
        assert!((lr_0 - 0.0).abs() < 1e-9);

        // At step warmup/2
        let lr_50 = cosine_lr_schedule(warmup / 2, lr_base, warmup, lr_min, max_steps);
        assert!(lr_50 > lr_0 && lr_50 < lr_base);

        // At half steps
        let lr_500 = cosine_lr_schedule(500, lr_base, warmup, lr_min, max_steps);
        assert!(lr_500 > lr_min && lr_500 < lr_base);

        // At max steps
        let lr_1000 = cosine_lr_schedule(max_steps, lr_base, warmup, lr_min, max_steps);
        assert!((lr_1000 - lr_min).abs() < 1e-9);
    }

    #[test]
    fn test_train_config_default() {
        let config = TrainConfig::default();

        assert_eq!(config.max_steps, 50000);
        assert_eq!(config.batch_size, 66);
        assert_eq!(config.seq_len, crate::forward::TRINITY_CONTEXT_LEN);
        assert!((config.learning_rate - 3e-4).abs() < 1e-9);
        assert_eq!(config.warmup_steps, 100);
        assert_eq!(config.grad_clip, 1.0);
    }

    #[test]
    fn test_should_kill() {
        let thresholds = KillThresholds::default();

        // At 5K (before first threshold)
        assert!(should_kill(5000, 600.0, &thresholds).is_none());

        // At 15K with PPL > threshold (in 10K-30K range)
        assert_eq!(should_kill(15000, 600.0, &thresholds), Some(500.0));

        // At 15K with PPL < threshold
        assert!(should_kill(15000, 400.0, &thresholds).is_none());

        // At 35K with PPL > threshold (in 30K-60K range, uses ppl_30k)
        assert_eq!(should_kill(35000, 300.0, &thresholds), Some(200.0));

        // At 85K (after all thresholds)
        assert!(should_kill(85000, 1000.0, &thresholds).is_none());
    }

    #[test]
    fn test_kill_thresholds_updated() {
        let thresholds = KillThresholds::default();

        // EXP-025: Updated to 500 at 10K
        assert_eq!(thresholds.ppl_10k, Some(500.0));
        // Was: Some(200.0) (too aggressive)

        // 60K and 80K thresholds added
        assert_eq!(thresholds.ppl_60k, Some(100.0));
        assert_eq!(thresholds.ppl_80k, Some(50.0));
    }
}
