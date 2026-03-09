---
sidebar_position: 3
---
# GGUF Model Format

Trinity reads model weights from GGUF (GPT-Generated Unified Format) files, the standard format used by the llama.cpp ecosystem. This page documents how Trinity parses GGUF v3 files and what model configurations are supported.

## GGUF v3 File Structure

A GGUF file is organized into four sequential sections:

1. **Header**: Begins with the magic bytes `0x46554747` ("GGUF" in little-endian ASCII), followed by the format version number (3), the count of metadata key-value pairs, and the count of tensors.

2. **Metadata**: A sequence of key-value pairs that describe the model architecture, tokenizer configuration, and training parameters. Each entry consists of a length-prefixed string key, a type tag, and the corresponding value.

3. **Tensor Descriptors**: For each tensor, the file records the name (string), number of dimensions, shape (array of dimension sizes), quantization type (enum), and byte offset into the data section. Tensors are aligned to 32-byte boundaries by default.

4. **Tensor Data**: The raw weight data for all tensors, laid out contiguously and aligned according to the alignment parameter. Trinity reads this data directly into memory for inference.

## Metadata Value Types

The GGUF format supports the following value types for metadata entries:

| Type ID | Name | Description |
|---------|------|-------------|
| 0 | UINT8 | Unsigned 8-bit integer |
| 1 | INT8 | Signed 8-bit integer |
| 2 | UINT16 | Unsigned 16-bit integer |
| 3 | INT16 | Signed 16-bit integer |
| 4 | UINT32 | Unsigned 32-bit integer |
| 5 | INT32 | Signed 32-bit integer |
| 6 | FLOAT32 | 32-bit IEEE 754 float |
| 7 | BOOL | Boolean (1 byte) |
| 8 | STRING | Length-prefixed UTF-8 string |
| 9 | ARRAY | Typed array with element type and count |
| 10 | UINT64 | Unsigned 64-bit integer |
| 11 | INT64 | Signed 64-bit integer |
| 12 | FLOAT64 | 64-bit IEEE 754 double |

## Supported Quantization Types

Trinity's GGUF reader recognizes a wide range of quantization formats. The following types are most relevant for BitNet inference:

### Standard Types

| Type | ID | Block Size | Bytes/Block | Description |
|------|----|-----------|-------------|-------------|
| F32 | 0 | 1 | 4 | Full precision 32-bit float |
| F16 | 1 | 1 | 2 | Half precision 16-bit float |
| BF16 | 30 | 1 | 2 | Brain floating point 16-bit |
| Q8_0 | 8 | 32 | 34 | 8-bit quantization with scale |
| Q4_0 | 2 | 32 | 18 | 4-bit quantization with scale |
| Q4_1 | 3 | 32 | 20 | 4-bit quantization with scale and minimum |

### BitNet Ternary Types

| Type | ID | Block Size | Bytes/Block | Description |
|------|----|-----------|-------------|-------------|
| I2_S | 36 | 4 | 1 | 2-bit integer with scale; encodes ternary \{-1, 0, +1\} as 4 values per byte |
| TQ1_0 | 34 | 32 | 8 | Pure ternary packed, no scale factor |
| TQ2_0 | 35 | 32 | 10 | Ternary packed with 2-byte scale factor |
| TL1 | 38 | 4 | 1 | BitNet TL1 format |
| TL2 | 39 | 4 | 1 | BitNet TL2 format |

### Low-Bit Quantization Types

| Type | ID | Description |
|------|----|-------------|
| IQ1_S | 19 | 1-bit integer quantization with scale |
| IQ1_M | 29 | 1-bit integer quantization (modified) |
| IQ2_XXS | 16 | Ultra-low 2-bit quantization |
| IQ2_XS | 17 | Extra-small 2-bit quantization |
| IQ2_S | 22 | 2-bit integer quantization with scale |
| IQ3_XXS | 18 | Ultra-low 3-bit quantization |
| IQ3_S | 21 | 3-bit integer quantization with scale |
| IQ4_NL | 20 | 4-bit non-linear quantization |
| IQ4_XS | 23 | 4-bit extra-small quantization |

## Ternary Weight Encoding

For BitNet models using I2_S quantization, ternary weights are packed at 4 values per byte using 2-bit encoding:

| Bit Pattern | Trit Value |
|-------------|------------|
| `00` | 0 |
| `01` | +1 |
| `10` | -1 |
| `11` | 0 (unused) |

This encoding is read through a lookup table (`TRIT_LUT`) during inference, enabling efficient unpacking during the ternary matrix-vector multiply operation.

## Model Architecture Metadata

Trinity reads the following architecture parameters from GGUF metadata to configure the inference engine:

| Metadata Key | Example Value | Purpose |
|--------------|---------------|---------|
| `n_layers` / `num_hidden_layers` | 30 | Number of transformer layers |
| `n_heads` / `num_attention_heads` | 20 | Number of query attention heads |
| `n_kv_heads` / `num_key_value_heads` | 5 | Number of key-value heads (for GQA) |
| `n_embd` / `hidden_size` | 2560 | Hidden dimension size |
| `intermediate_size` | 6912 | Feed-forward intermediate dimension |
| `vocab_size` | 128256 | Vocabulary size for embedding/output |
| `max_position_embeddings` | 4096 | Maximum sequence length |
| `rms_norm_eps` | 1e-5 | RMSNorm epsilon for numerical stability |
| `rope_theta` | 500000.0 | Rotary position embedding base frequency |

## RoPE (Rotary Position Embeddings)

The model uses Rotary Position Embeddings to encode token positions. The RoPE theta parameter (500000.0 for BitNet 2B) controls the frequency base for the sinusoidal position encoding. Higher theta values extend the effective context length. Trinity computes RoPE frequencies on-the-fly during the attention computation.

## Obtaining Compatible Models

BitNet GGUF models can be obtained from the Hugging Face model hub. Look for models specifically quantized with I2_S or TQ1_0 quantization types. Models originally published in the Hugging Face Transformers format can be converted to GGUF using the conversion tools provided by the llama.cpp project, with explicit support for BitNet ternary quantization.
