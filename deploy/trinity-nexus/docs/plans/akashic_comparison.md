# 3.5. Comparison Summary Table

## Hash Benchmarks (theoretical/simulated, full run pending vibee gen improvements)

| Algo       | Size | Collision Rate | Entropy (bits) | Avalanche | Crypto? | Semantic Search | Adaptive? |
|------------|------|----------------|---------------|-----------|---------|-----------------|-----------|
| Fibonacci | u64  | ~1/N           | ~64           | good      | No      | Medium          | No        |
| SHA256    | 256  | 2^-256         | 256           | excellent | Yes     | Low             | No        |
| SHA3-256  | 256  | 2^-256         | 256           | excellent | Yes     | Low             | No        |
| BLAKE3    | 256  | 2^-256         | 256           | excellent | Yes     | Low             | No        |
| Akashic   | var  | adaptive       | ~128-256      | good      | No      | **High**        | **Yes**   |

## Key Insights

1. **Akashic Hash** is not cryptographic but optimized for semantic similarity search
2. **Fibonacci Hash** is fast but limited to 64-bit output
3. **Cryptographic hashes** (SHA, BLAKE) are secure but not semantic-aware

## Recommendation

Use **Akashic Hash** for:
- Semantic search in knowledge bases
- Similarity matching
- Adaptive caching

Use **SHA256/BLAKE3** for:
- Security-critical applications
- Data integrity verification
- Cryptographic signatures

---

**φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL**
