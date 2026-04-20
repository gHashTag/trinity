//! Data loading and batching
//!
//! Placeholder for data pipeline.

/// Data batch
#[derive(Debug, Clone)]
pub struct Batch {
    /// Input token IDs
    pub input: Vec<usize>,

    /// Target token IDs (next tokens)
    pub target: Vec<usize>,

    /// Attention mask (for padding)
    pub mask: Vec<f32>,
}

impl Default for Batch {
    fn default() -> Self {
        Self {
            input: Vec::new(),
            target: Vec::new(),
            mask: Vec::new(),
        }
    }
}

/// Data loader
#[derive(Debug)]
pub struct DataLoader {
    /// Batch size
    pub batch_size: usize,

    /// Sequence length
    pub seq_len: usize,
}

impl Default for DataLoader {
    fn default() -> Self {
        Self {
            batch_size: 66,   // EXP-001: optimal for ctx=27
            seq_len: 81,     // EXP-014: 3^4 = TRINITY_CONTEXT_LEN
        }
    }
}

impl DataLoader {
    pub fn new(batch_size: usize, seq_len: usize) -> Self {
        Self {
            batch_size,
            seq_len,
        }
    }

    /// Load a batch of data (placeholder)
    pub fn load_batch(&self) -> Option<Batch> {
        // TODO: Implement actual data loading
        Some(Batch::default())
    }

    /// Reset data iterator (placeholder)
    pub fn reset(&mut self) {
        // TODO: Implement reset logic
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_batch_default() {
        let batch = Batch::default();
        assert!(batch.input.is_empty());
        assert!(batch.target.is_empty());
        assert!(batch.mask.is_empty());
    }

    #[test]
    fn test_dataloader_default() {
        let loader = DataLoader::default();
        assert_eq!(loader.batch_size, 66);
        assert_eq!(loader.seq_len, 81);
    }

    #[test]
    fn test_dataloader_new() {
        let loader = DataLoader::new(32, 128);
        assert_eq!(loader.batch_size, 32);
        assert_eq!(loader.seq_len, 128);
    }
}
