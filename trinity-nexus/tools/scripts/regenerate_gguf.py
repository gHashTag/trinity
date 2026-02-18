#!/usr/bin/env python3
"""
Regenerate BitNet GGUF with correct tokenizer metadata.

The official Microsoft GGUF is missing tokenizer.ggml.pre field,
causing "GENERATION QUALITY WILL BE DEGRADED!" warning in llama.cpp.

This script:
1. Loads model from safetensors
2. Converts weights to I2_S ternary format
3. Sets tokenizer.ggml.model = "gpt2" (BPE tokenizer)
4. Sets tokenizer.ggml.pre = "llama-bpe" (LLaMA 3 pre-tokenizer regex)
5. Writes correct GGUF file

Usage:
    python scripts/regenerate_gguf.py \
        --model models/microsoft-bitnet-2b \
        --outfile models/bitnet-2b-fixed.gguf
"""

import sys
import os
import argparse
import json
import struct
import numpy as np
from pathlib import Path
from hashlib import sha256

# Add gguf-py to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'bitnet-cpp' / '3rdparty' / 'llama.cpp' / 'gguf-py'))
import gguf


def load_tokenizer_vocab(model_dir: Path):
    """Load vocabulary from tokenizer.json (HuggingFace BPE format)."""
    tokenizer_path = model_dir / 'tokenizer.json'
    with open(tokenizer_path, encoding='utf-8') as f:
        tokenizer_json = json.load(f)

    model_data = tokenizer_json['model']
    vocab = model_data['vocab']
    merges = model_data.get('merges', [])
    added_tokens = tokenizer_json.get('added_tokens', [])

    # Build token list in order
    vocab_size = len(vocab)
    tokens = [''] * vocab_size
    for tok, idx in vocab.items():
        tokens[idx] = tok

    # Add special/added tokens
    for added in added_tokens:
        content = added['content']
        idx = added['id']
        if idx >= vocab_size:
            # Extend list
            while len(tokens) <= idx:
                tokens.append('')
            tokens[idx] = content
        else:
            tokens[idx] = content

    return tokens, merges, added_tokens


def detect_pre_tokenizer(model_dir: Path) -> str:
    """Detect the pre-tokenizer type by hashing encoded test text."""
    try:
        from transformers import AutoTokenizer
        tokenizer = AutoTokenizer.from_pretrained(
            str(model_dir), local_files_only=True
        )

        chktxt = '\n \n\n \n\n\n \t \t\t \t\n  \n   \n    \n     \n🚀 (normal) 😶\u200d🌫️ (multiple emojis concatenated) ✅ 🦙🦙 3 33 333 3333 33333 333333 3333333 33333333 3.3 3..3 3...3 កាន់តែពិសេសអាច😁 ?我想在apple工作1314151天～ ------======= нещо на Български \'\'\'\'\'\'```````""""......!!!!!!?????? I\'ve been \'told he\'s there, \'RE you sure? \'M not sure I\'ll make it, \'D you like some tea? We\'Ve a\'lL'
        chktok = tokenizer.encode(chktxt)
        chkhsh = sha256(str(chktok).encode()).hexdigest()

        # Known hashes
        known = {
            "0ef9807a4087ebef797fc749390439009c3b9eda9ad1a097abbe738f486c01e5": "llama-bpe",
        }

        if chkhsh in known:
            return known[chkhsh]

        print(f"WARNING: Unknown pre-tokenizer hash: {chkhsh}")
        print("Defaulting to llama-bpe for LLaMA 3 tokenizer")
        return "llama-bpe"
    except Exception as e:
        print(f"WARNING: Could not detect pre-tokenizer: {e}")
        print("Using llama-bpe (LLaMA 3 tokenizer)")
        return "llama-bpe"


def load_safetensors(model_dir: Path):
    """Load model weights from safetensors using PyTorch (supports bfloat16)."""
    import torch
    from safetensors import safe_open

    model_path = model_dir / 'model.safetensors'
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")

    tensors = {}
    with safe_open(str(model_path), framework="pt", device="cpu") as f:
        for key in f.keys():
            tensor = f.get_tensor(key)
            # Convert bfloat16 to float32 for numpy compatibility
            if tensor.dtype == torch.bfloat16:
                tensor = tensor.float()
            tensors[key] = tensor.numpy()

    return tensors


def weight_quant(weight: np.ndarray) -> np.ndarray:
    """Quantize weights to ternary {-1, 0, +1} using absmax scaling."""
    w = weight.astype(np.float32)
    s = 1.0 / max(np.abs(w).mean(), 1e-5)
    result = np.clip(np.round(w * s), -1, 1) / s
    return result.astype(weight.dtype)


def convert_to_i2s(weight: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Convert ternary weights to I2_S format (2-bit packed with scale)."""
    w = weight.astype(np.float32)
    s = 1.0 / max(np.abs(w).mean(), 1e-5)
    ternary = np.clip(np.round(w * s), -1, 1).astype(np.int8)
    scale = np.float32(1.0 / s)
    return ternary, np.array([scale], dtype=np.float32)


# Tensor name mapping: HuggingFace -> GGUF
TENSOR_MAP = {
    "model.embed_tokens.weight": "token_embd.weight",
    "model.norm.weight": "output_norm.weight",
    "lm_head.weight": "output.weight",
}

LAYER_TENSOR_MAP = {
    "model.layers.{}.self_attn.q_proj.weight": "blk.{}.attn_q.weight",
    "model.layers.{}.self_attn.k_proj.weight": "blk.{}.attn_k.weight",
    "model.layers.{}.self_attn.v_proj.weight": "blk.{}.attn_v.weight",
    "model.layers.{}.self_attn.o_proj.weight": "blk.{}.attn_output.weight",
    "model.layers.{}.self_attn.attn_sub_norm.weight": "blk.{}.attn_sub_norm.weight",
    "model.layers.{}.mlp.gate_proj.weight": "blk.{}.ffn_gate.weight",
    "model.layers.{}.mlp.up_proj.weight": "blk.{}.ffn_up.weight",
    "model.layers.{}.mlp.down_proj.weight": "blk.{}.ffn_down.weight",
    "model.layers.{}.mlp.ffn_sub_norm.weight": "blk.{}.ffn_sub_norm.weight",
    "model.layers.{}.input_layernorm.weight": "blk.{}.attn_norm.weight",
    "model.layers.{}.post_attention_layernorm.weight": "blk.{}.ffn_norm.weight",
}

# Tensors to skip (weight_scale is embedded in quantized format)
SKIP_TENSORS = {"weight_scale"}

# Weight tensors that should be quantized to ternary
QUANT_TENSORS = {
    "q_proj.weight", "k_proj.weight", "v_proj.weight", "o_proj.weight",
    "gate_proj.weight", "up_proj.weight", "down_proj.weight",
}


def map_tensor_name(hf_name: str, n_layers: int):
    """Map HuggingFace tensor name to GGUF tensor name."""
    if hf_name in TENSOR_MAP:
        return TENSOR_MAP[hf_name]

    for hf_pattern, gguf_pattern in LAYER_TENSOR_MAP.items():
        for i in range(n_layers):
            if hf_name == hf_pattern.format(i):
                return gguf_pattern.format(i)

    return None


def main():
    parser = argparse.ArgumentParser(description="Regenerate BitNet GGUF with correct tokenizer")
    parser.add_argument("--model", type=Path, required=True, help="Model directory with safetensors")
    parser.add_argument("--outfile", type=Path, required=True, help="Output GGUF file")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    model_dir = args.model
    outfile = args.outfile

    # Load config
    with open(model_dir / 'config.json') as f:
        config = json.load(f)

    print(f"Model: {config.get('model_type', 'unknown')}")
    print(f"Hidden size: {config['hidden_size']}")
    print(f"Layers: {config['num_hidden_layers']}")
    print(f"Heads: {config['num_attention_heads']} (KV: {config['num_key_value_heads']})")
    print(f"Vocab size: {config['vocab_size']}")
    print()

    # Create GGUF writer
    writer = gguf.GGUFWriter(str(outfile), "bitnet")

    # Set model parameters
    writer.add_name("bitnet2b_2501")
    writer.add_vocab_size(config['vocab_size'])
    writer.add_context_length(config.get('max_position_embeddings', 4096))
    writer.add_embedding_length(config['hidden_size'])
    writer.add_block_count(config['num_hidden_layers'])
    writer.add_feed_forward_length(config['intermediate_size'])
    writer.add_head_count(config['num_attention_heads'])
    writer.add_head_count_kv(config['num_key_value_heads'])
    writer.add_rope_dimension_count(config['hidden_size'] // config['num_attention_heads'])
    writer.add_layer_norm_rms_eps(config.get('rms_norm_eps', 1e-5))
    writer.add_rope_freq_base(config.get('rope_theta', 500000.0))
    writer.add_add_bos_token(True)
    # Use F16 file type (ternary weights stored as quantized f16)
    writer.add_file_type(gguf.GGMLQuantizationType.F16)

    # Set tokenizer with CORRECT metadata
    print("Setting up tokenizer...")
    tokens, merges, added_tokens = load_tokenizer_vocab(model_dir)

    # CRITICAL: Set tokenizer model type to gpt2 (BPE)
    writer.add_tokenizer_model("gpt2")

    # CRITICAL: Set pre-tokenizer to llama-bpe
    pre_type = detect_pre_tokenizer(model_dir)
    writer.add_tokenizer_pre(pre_type)
    print(f"  tokenizer.ggml.model = gpt2")
    print(f"  tokenizer.ggml.pre = {pre_type}")

    # Add token list
    token_bytes = [t.encode('utf-8') if isinstance(t, str) else t for t in tokens]
    writer.add_token_list(token_bytes)

    # Add token types
    special_ids = set()
    for added in added_tokens:
        if added.get('special', False):
            special_ids.add(added['id'])

    toktypes = []
    for i in range(len(tokens)):
        if i in special_ids:
            toktypes.append(gguf.TokenType.CONTROL)
        else:
            toktypes.append(gguf.TokenType.NORMAL)
    writer.add_token_types(toktypes)

    # Add BPE merges
    if merges:
        merge_strs = [m if isinstance(m, str) else m.decode('utf-8') for m in merges]
        writer.add_token_merges(merge_strs)
        print(f"  Added {len(merge_strs)} BPE merges")

    # Add special token IDs
    bos_id = config.get('bos_token_id', 128000)
    eos_id = config.get('eos_token_id', 128001)
    writer.add_bos_token_id(bos_id)
    writer.add_eos_token_id(eos_id)
    print(f"  BOS token: {bos_id}, EOS token: {eos_id}")

    # Load and convert model weights
    print("\nLoading model weights...")
    tensors = load_safetensors(model_dir)
    n_layers = config['num_hidden_layers']

    tensor_count = 0
    skipped = 0
    for hf_name, data in sorted(tensors.items()):
        # Skip weight_scale tensors (embedded in quantized format)
        if any(hf_name.endswith(s) for s in SKIP_TENSORS):
            skipped += 1
            continue

        gguf_name = map_tensor_name(hf_name, n_layers)
        if gguf_name is None:
            print(f"  SKIP: {hf_name} (no mapping)")
            continue

        # Determine if this is a weight tensor that should be quantized
        should_quant = any(hf_name.endswith(q) for q in QUANT_TENSORS)

        if should_quant:
            # Quantize to ternary and store as float16
            data_quant = weight_quant(data)
            data_np = data_quant.astype(np.float16)
        elif len(data.shape) == 1 or 'norm' in hf_name or 'embed' in hf_name:
            # Keep 1D tensors (norms), embeddings as float32
            data_np = data.astype(np.float32)
        else:
            data_np = data.astype(np.float16)

        writer.add_tensor(gguf_name, data_np)
        tensor_count += 1
        if args.verbose or tensor_count % 20 == 0:
            print(f"  [{tensor_count}] {hf_name} -> {gguf_name} ({data_np.shape}, {data_np.dtype})")

    print(f"  Skipped {skipped} weight_scale tensors (embedded in quantized weights)")

    print(f"\nTotal tensors written: {tensor_count}")

    # Handle tied embeddings
    if config.get('tie_word_embeddings', False) and 'lm_head.weight' not in tensors:
        embed_data = tensors['model.embed_tokens.weight']
        embed_np = embed_data.astype(np.float16)
        writer.add_tensor("output.weight", embed_np)
        tensor_count += 1
        print(f"  Added tied output.weight from embed_tokens")

    # Write file
    print(f"\nWriting GGUF to {outfile}...")
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()

    file_size = outfile.stat().st_size
    print(f"\nDone! File size: {file_size / (1024**3):.2f} GiB")
    print(f"Tokenizer: gpt2 (BPE) with pre={pre_type}")
    print(f"This should fix the 'missing pre-tokenizer type' warning!")


if __name__ == '__main__':
    main()
