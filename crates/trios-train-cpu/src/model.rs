//! Trinity model with IglaConfig
//!
//! Research: EXP-014 (Trinity 3ᵏ architecture)

use crate::forward::{LayerDims, TRINITY_VOCAB_SIZE, TRINITY_CONTEXT_LEN};
use crate::objective::Objective;

// ============================================================================
// Model Configuration
// ============================================================================

/// Igla configuration with Trinity 3ᵏ architecture
#[derive(Debug, Clone)]
pub struct IglaConfig {
    /// Vocabulary size (729 = 3^6)
    pub vocab_size: usize,

    /// Maximum sequence length (81 = 3^4)
    pub max_seq_len: usize,

    /// Layer dimensions (Trinity 3ᵏ)
    pub dims: LayerDims,

    /// Number of layers (9 = 3^2)
    pub n_layers: usize,

    /// Training objective
    pub objective: Objective,
}

impl Default for IglaConfig {
    fn default() -> Self {
        Self {
            vocab_size: TRINITY_VOCAB_SIZE,  // 256 = 2^8 (Parameter Golf)
            max_seq_len: TRINITY_CONTEXT_LEN, // 81 = 3^4
            dims: LayerDims::trinity(),
            n_layers: crate::forward::TRINITY_NUM_BLOCKS,  // 9 = 3^2
            objective: Objective::default(),  // NTP (baseline)
        }
    }
}

impl IglaConfig {
    pub fn from_dims(dims: LayerDims) -> Self {
        Self {
            vocab_size: TRINITY_VOCAB_SIZE,
            max_seq_len: TRINITY_CONTEXT_LEN,
            dims,
            n_layers: crate::forward::TRINITY_NUM_BLOCKS,
            objective: Objective::default(),
        }
    }

    /// Verify configuration is valid
    pub fn validate(&self) -> Result<(), String> {
        // Check vocab size
        if self.vocab_size != TRINITY_VOCAB_SIZE {
            return Err(format!("vocab_size must be {}", TRINITY_VOCAB_SIZE));
        }

        // Check max sequence length
        if self.max_seq_len != TRINITY_CONTEXT_LEN {
            return Err(format!("max_seq_len must be {}", TRINITY_CONTEXT_LEN));
        }

        // Check layer dimensions
        if self.dims != LayerDims::trinity() {
            return Err("dims must be Trinity 3ᵏ".to_string());
        }

        // Check number of layers
        if self.n_layers != crate::forward::TRINITY_NUM_BLOCKS {
            return Err(format!("n_layers must be {}", crate::forward::TRINITY_NUM_BLOCKS));
        }

        // Check square attention
        if !self.dims.is_valid_context(crate::forward::TRINITY_CONTEXT_LEN) {
            return Err("context_length must be valid for square attention".to_string());
        }

        Ok(())
    }

    /// Get total parameter count
    ///
    /// Approximate parameter count for Trinity configuration.
    pub fn param_count(&self) -> usize {
        // Embedding: vocab * d_model = 729 * 729 ≈ 531K
        let embedding = self.vocab_size * self.dims.d_model;

        // Each layer: 2 * (d_model^2) + 4 * d_model (QKV)
        let layer = 2 * self.dims.d_model.pow(2) + 4 * self.dims.d_model * self.dims.d_model;

        // Output projection: d_model * vocab = 729 * 729 ≈ 531K
        let output = self.dims.d_model * self.vocab_size;

        // Layer norms: 4 * n_layers * d_model
        let ln = 4 * self.n_layers * self.dims.d_model;

        embedding + self.n_layers * layer + output + ln
    }
}

// ============================================================================
// IglaModel
// ============================================================================

/// Igla neural network model
///
/// Trinity 3ᵏ-based transformer with ~10M parameters.
#[derive(Debug)]
pub struct IglaModel {
    config: IglaConfig,
}

impl IglaModel {
    pub fn new(config: IglaConfig) -> Result<Self, String> {
        config.validate()?;
        Ok(Self { config })
    }

    pub fn from_default() -> Result<Self, String> {
        Self::new(IglaConfig::default())
    }

    pub fn forward(&self, _input: &[usize]) -> Vec<f32> {
        // Placeholder: actual forward pass implementation
        // This will be implemented with attention, FFN, etc.
        vec![0.0; self.config.max_seq_len]
    }

    pub fn param_count(&self) -> usize {
        self.config.param_count()
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_igla_config_default() {
        let config = IglaConfig::default();
        assert_eq!(config.vocab_size, 256);  // Parameter Golf
        assert_eq!(config.max_seq_len, 81);
        assert_eq!(config.dims, LayerDims::trinity());
        assert_eq!(config.n_layers, 9);
        assert_eq!(config.objective, Objective::Ntp);
    }

    #[test]
    fn test_igla_config_validate() {
        let config = IglaConfig::default();

        // Valid config
        assert!(config.validate().is_ok());

        // Invalid vocab size
        let mut invalid = config.clone();
        invalid.vocab_size = 100;
        assert!(invalid.validate().is_err());

        // Invalid context
        invalid.vocab_size = 256;
        invalid.max_seq_len = 100;
        assert!(invalid.validate().is_err());
    }

    #[test]
    fn test_param_count() {
        let config = IglaConfig::default();

        // With d_model=243, vocab=256, n_layers=9:
        // Embedding: 256 * 243 ≈ 62K
        // Each layer: ~600K parameters
        // Output: 243 * 256 ≈ 62K
        // Total: ~5-6M parameters (reduced from ~10M with d_model=729)
        let count = config.param_count();
        assert!(count > 1_000_000);
        assert!(count < 10_000_000);
    }

    #[test]
    fn test_igla_model_creation() {
        let model = IglaModel::from_default();
        assert!(model.is_ok());

        let model = model.unwrap();
        assert_eq!(model.config.vocab_size, 256);  // Parameter Golf
        assert_eq!(model.config.max_seq_len, 81);
    }

    #[test]
    fn test_igla_model_forward() {
        let model = IglaModel::from_default().unwrap();
        let input = vec![1, 2, 3, 4, 5];  // 5 tokens
        let output = model.forward(&input);

        // Should return max_seq_len values
        assert_eq!(output.len(), 81);
    }
}
