#!/usr/bin/env python3
"""
Wrapper around convert-ms-to-gguf-bitnet.py that patches the tokenizer.ggml.pre field.

The official conversion script doesn't set tokenizer.ggml.pre, causing
"GENERATION QUALITY WILL BE DEGRADED!" warning in llama.cpp/bitnet.cpp.

This script:
1. Monkey-patches OutputFile.add_meta_vocab to also set tokenizer.ggml.pre
2. Runs the official conversion with --vocab-type bpe --outtype i2
"""

import sys
import os
from pathlib import Path

# Add paths
bitnet_utils = Path(__file__).parent.parent / 'bitnet-cpp' / 'utils'
gguf_py = Path(__file__).parent.parent / 'bitnet-cpp' / '3rdparty' / 'llama.cpp' / 'gguf-py'

sys.path.insert(0, str(gguf_py))
sys.path.insert(0, str(bitnet_utils))

# Import the conversion module
# The module has hyphens in its name, use importlib
import importlib.util
spec = importlib.util.spec_from_file_location(
    "converter", str(bitnet_utils / "convert-ms-to-gguf-bitnet.py"))
converter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)
import gguf

# Monkey-patch: Save original add_meta_vocab
original_add_meta_vocab = converter.OutputFile.add_meta_vocab

def patched_add_meta_vocab(self, vocab):
    """Patched version that adds tokenizer.ggml.pre = llama-bpe."""
    original_add_meta_vocab(self, vocab)
    # Add the missing pre-tokenizer type for LLaMA 3 BPE
    self.gguf.add_tokenizer_pre("llama-bpe")
    print("PATCH: Added tokenizer.ggml.pre = llama-bpe")

converter.OutputFile.add_meta_vocab = patched_add_meta_vocab

# Run with fixed args
if __name__ == '__main__':
    # Default args if none provided
    if len(sys.argv) == 1:
        sys.argv = [
            sys.argv[0],
            '--vocab-type', 'bpe',
            '--outtype', 'i2',
            '--outfile', str(Path(__file__).parent.parent / 'models' / 'bitnet-2b-fixed-i2.gguf'),
            str(Path(__file__).parent.parent / 'models' / 'microsoft-bitnet-2b'),
        ]
        print(f"Using default args: {' '.join(sys.argv[1:])}")

    converter.main()
