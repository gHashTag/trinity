---
sidebar_position: 2
---
# Inference Pipeline

This page provides a detailed walkthrough of how BitNet inference works in Trinity, from loading a model file to generating text output. The entire pipeline is implemented natively in Zig with zero external dependencies.

## 1. Model Loading -- GGUF Format Reader

The inference pipeline begins with loading a pre-quantized model from a GGUF v3 file. Trinity's `gguf_reader.zig` module handles this process:

- Validates the GGUF magic bytes (`0x46554747`, which is "GGUF" in little-endian) and version number.
- Parses the metadata header to extract model architecture parameters: number of layers, attention heads, hidden dimensions, vocabulary size, RoPE theta, and normalization epsilon.
- Reads tensor descriptors that specify the name, shape, quantization type, and byte offset for each weight tensor in the file.
- Maps tensor data into memory. For BitNet models, weight tensors use the I2_S quantization type, which packs 4 ternary values per byte (2 bits each, where `00` = 0, `01` = +1, `10` = -1).

The model configuration for the BitNet 2B architecture defaults to:

| Parameter | Value |
|-----------|-------|
| Vocabulary size | 128,256 |
| Hidden size | 2,560 |
| Intermediate size | 6,912 |
| Number of layers | 30 |
| Attention heads | 20 |
| Key-value heads | 5 |
| Max context length | 4,096 |
| RoPE theta | 500,000 |

## 2. Tokenization -- SentencePiece BPE

Input text is converted to token IDs using the SentencePiece BPE tokenizer:

- The tokenizer loads a vocabulary file (JSON format) containing token-to-ID mappings and special tokens.
- It supports both SentencePiece-style space markers (U+2581) and GPT-2-style markers (U+0120), auto-detecting the convention used by the model.
- Text is preprocessed by prepending a space marker and replacing internal spaces with the marker character.
- Encoding uses a greedy longest-match algorithm: at each position, the tokenizer tries the longest possible substring first and works downward until it finds a match in the vocabulary.
- For bytes not covered by any vocabulary entry, the tokenizer falls back to byte-level encoding using `<0xNN>` tokens.
- A BOS (beginning-of-sequence) token is prepended to every encoded sequence.

## 3. Embedding -- Token to Vector Lookup

Each token ID is mapped to a dense vector of size 2560 (the hidden dimension) through an embedding table lookup. The embedding weights are stored in the GGUF file as part of the model tensors. This lookup produces the initial hidden state that will be processed by the transformer layers.

## 4. Transformer Layers -- 30-Layer Processing

The hidden state passes through 30 identical transformer layers. Each layer performs the following operations in sequence:

### RMSNorm (Input Normalization)

Root Mean Square normalization is applied before attention:

```
rms = sqrt(mean(x^2) + eps)
output = (x / rms) * weight
```

The epsilon value is set to 1e-5 to prevent division by zero.

### Grouped Query Attention (GQA)

The attention mechanism uses 20 query heads and 5 key-value heads (a 4:1 grouping ratio):

- **Q/K/V Projections**: The normalized hidden state is projected through ternary weight matrices to produce query (Q), key (K), and value (V) vectors. These projections use the ternary matrix-vector multiply, which replaces multiplication with conditional addition and subtraction.
- **Rotary Position Embeddings (RoPE)**: Positional information is injected into Q and K vectors using rotary embeddings with theta=500000. This allows the model to understand token positions without explicit position embeddings.
- **KV-Cache**: Key and value vectors are stored in a per-layer cache to avoid recomputation during autoregressive generation. The cache stores `[layer][position][kv_head][head_dim]` and supports sequences up to the maximum context length.
- **Scaled Dot-Product Attention**: For each query head, attention scores are computed against all cached key vectors, scaled by `1/sqrt(head_dim)`, passed through softmax, and used to weight the value vectors. Each group of 4 query heads shares the same KV head.
- **Output Projection**: The concatenated attention output is projected back to the hidden dimension through a ternary weight matrix.

### Residual Connection

The attention output is added to the original input (skip connection).

### RMSNorm (Post-Attention Normalization)

A second RMSNorm is applied before the feed-forward network.

### Feed-Forward Network (FFN)

The FFN uses a gated architecture with three ternary projections:

- **Gate projection**: hidden_size (2560) to intermediate_size (6912)
- **Up projection**: hidden_size (2560) to intermediate_size (6912)
- **Activation**: The gate output is passed through squared ReLU: `relu2(x) = max(0, x)^2`
- **Element-wise multiply**: gate_activated * up_output
- **Down projection**: intermediate_size (6912) back to hidden_size (2560)

### Residual Connection

The FFN output is added to the post-attention hidden state.

## 5. Output -- Token Generation

After all 30 layers have processed the hidden state:

1. **Final RMSNorm**: The output hidden state is normalized one last time.
2. **Logits Computation**: The normalized hidden state is projected against the output embedding matrix to produce logits over the full vocabulary (128,256 scores).
3. **Temperature Sampling**: Logits are divided by a temperature parameter, then softmax is applied to produce a probability distribution. A token is sampled from this distribution.
4. **Token Decoding**: The sampled token ID is converted back to text using the tokenizer's reverse vocabulary. Space markers are replaced with actual spaces, and special tokens are handled appropriately.
5. **Autoregressive Loop**: The generated token is fed back as input, its KV representations are cached, and the process repeats until an EOS token is generated or the maximum length is reached.

## CLI Usage

Trinity provides two interfaces for BitNet inference:

### Interactive Chat

```bash
./bin/vibee chat --model path/to/bitnet-2b.gguf
```

This starts an interactive session where you can type prompts and receive generated responses.

### HTTP API Server

```bash
./bin/vibee serve --port 8080
```

This launches an HTTP server that accepts inference requests, suitable for integration with other applications or services.

## Performance Characteristics

Because all weight matrices use ternary values, the dominant computation in each layer is the ternary matrix-vector multiply. This operation processes 4 trits per byte using a lookup table, replacing floating-point multiplication with conditional addition. The SIMD-optimized variant (`ternaryMatVecSIMD`) processes 8 elements at a time using vector instructions. The KV-cache ensures that each new token only requires a single forward pass through all layers, rather than reprocessing the entire sequence.
