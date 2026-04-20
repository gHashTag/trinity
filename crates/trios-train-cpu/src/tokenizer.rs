//! Tokenizer for Trinity vocabulary
//!
//! Trinity vocabulary size: 729 = 3^6

/// Token type for Trinity vocabulary
pub type Token = usize;

/// Trinity tokenizer
///
/// Maps tokens to/from vocabulary indices.
#[derive(Debug, Clone)]
pub struct Tokenizer {
    /// Vocabulary size (729 = 3^6)
    pub vocab_size: usize,
}

impl Default for Tokenizer {
    fn default() -> Self {
        Self {
            vocab_size: crate::forward::TRINITY_VOCAB_SIZE,  // 729 = 3^6
        }
    }
}

impl Tokenizer {
    pub fn new(vocab_size: usize) -> Self {
        Self { vocab_size }
    }

    /// Encode text to tokens (placeholder)
    pub fn encode(&self, _text: &str) -> Vec<Token> {
        // TODO: Implement actual tokenization
        Vec::new()
    }

    /// Decode tokens to text (placeholder)
    pub fn decode(&self, _tokens: &[Token]) -> String {
        // TODO: Implement actual detokenization
        String::new()
    }

    /// Check if token is valid
    pub fn is_valid(&self, token: Token) -> bool {
        token < self.vocab_size
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tokenizer_default() {
        let tokenizer = Tokenizer::default();
        assert_eq!(tokenizer.vocab_size, 729);
    }

    #[test]
    fn test_tokenizer_is_valid() {
        let tokenizer = Tokenizer::default();
        assert!(tokenizer.is_valid(0));
        assert!(tokenizer.is_valid(728));
        assert!(!tokenizer.is_valid(729));
        assert!(!tokenizer.is_valid(1000));
    }
}
