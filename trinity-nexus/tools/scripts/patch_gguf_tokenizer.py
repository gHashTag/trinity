#!/usr/bin/env python3
"""
Patch an existing GGUF file to add tokenizer.ggml.pre metadata.

This reads the original GGUF, copies all metadata and tensors,
and adds the missing tokenizer.ggml.pre = "llama-bpe" field.

Usage:
    python scripts/patch_gguf_tokenizer.py \
        --input models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf \
        --output models/bitnet-2b-fixed-i2s.gguf
"""

import sys
import os
import struct
import argparse
from pathlib import Path

# Add gguf-py to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'bitnet-cpp' / '3rdparty' / 'llama.cpp' / 'gguf-py'))
import gguf


def patch_gguf(input_path, output_path, pre_tokenizer="llama-bpe"):
    """Read GGUF, add tokenizer.ggml.pre, write new file."""
    print(f"Reading: {input_path}")
    reader = gguf.GGUFReader(str(input_path))

    # Get architecture from metadata
    arch = None
    for field in reader.fields.values():
        if field.name == 'general.architecture':
            arch_data = field.parts[field.data[0]]
            arch = bytes(arch_data).decode('utf-8')
            break

    if arch is None:
        arch = "bitnet"
    print(f"Architecture: {arch}")

    # Create writer with same architecture
    writer = gguf.GGUFWriter(str(output_path), arch)

    # Check if pre already exists
    has_pre = False

    # Copy all metadata
    print("Copying metadata...")
    for field in reader.fields.values():
        name = field.name

        if name == 'general.architecture':
            continue  # Already set by constructor

        if name == 'tokenizer.ggml.pre':
            has_pre = True
            print(f"  Found existing tokenizer.ggml.pre, will override")
            continue  # Will add our own

        # Get field type and data
        field_type = field.types[0] if field.types else None

        # Handle different field types
        if field_type == gguf.GGUFValueType.STRING:
            if len(field.data) == 1:
                val_data = field.parts[field.data[0]]
                val = bytes(val_data).decode('utf-8')
                writer.add_string(name, val)
                if 'tokenizer' in name and 'model' in name:
                    print(f"  {name} = {val}")
            else:
                # String array
                vals = []
                for idx in field.data:
                    val_data = field.parts[idx]
                    vals.append(bytes(val_data).decode('utf-8'))
                writer.add_array(name, vals)
                if 'tokenizer' in name:
                    print(f"  {name} = [{len(vals)} strings]")
        elif field_type == gguf.GGUFValueType.UINT32:
            val = struct.unpack('<I', bytes(field.parts[-1]))[0]
            writer.add_uint32(name, val)
        elif field_type == gguf.GGUFValueType.INT32:
            val = struct.unpack('<i', bytes(field.parts[-1]))[0]
            writer.add_int32(name, val)
        elif field_type == gguf.GGUFValueType.FLOAT32:
            val = struct.unpack('<f', bytes(field.parts[-1]))[0]
            writer.add_float32(name, val)
        elif field_type == gguf.GGUFValueType.BOOL:
            val = bool(bytes(field.parts[-1])[0])
            writer.add_bool(name, val)
        elif field_type == gguf.GGUFValueType.UINT64:
            val = struct.unpack('<Q', bytes(field.parts[-1]))[0]
            writer.add_uint64(name, val)
        elif field_type == gguf.GGUFValueType.INT64:
            val = struct.unpack('<q', bytes(field.parts[-1]))[0]
            writer.add_int64(name, val)
        elif field_type == gguf.GGUFValueType.FLOAT64:
            val = struct.unpack('<d', bytes(field.parts[-1]))[0]
            writer.add_float64(name, val)
        elif field_type == gguf.GGUFValueType.UINT8:
            val = bytes(field.parts[-1])[0]
            writer.add_uint8(name, val)
        elif field_type == gguf.GGUFValueType.INT8:
            val = struct.unpack('<b', bytes(field.parts[-1]))[0]
            writer.add_int8(name, val)
        elif field_type == gguf.GGUFValueType.UINT16:
            val = struct.unpack('<H', bytes(field.parts[-1]))[0]
            writer.add_uint16(name, val)
        elif field_type == gguf.GGUFValueType.INT16:
            val = struct.unpack('<h', bytes(field.parts[-1]))[0]
            writer.add_int16(name, val)
        elif field_type == gguf.GGUFValueType.ARRAY:
            # Arrays need special handling based on element type
            if len(field.types) > 1:
                elem_type = field.types[-1]
                if elem_type == gguf.GGUFValueType.STRING:
                    vals = []
                    for idx in field.data:
                        val_data = field.parts[idx]
                        vals.append(bytes(val_data).decode('utf-8'))
                    writer.add_array(name, vals)
                    if 'tokenizer' in name:
                        print(f"  {name} = [{len(vals)} strings]")
                elif elem_type == gguf.GGUFValueType.INT32:
                    vals = []
                    for idx in field.data:
                        val_data = field.parts[idx]
                        vals.append(struct.unpack('<i', bytes(val_data))[0])
                    import numpy as np
                    writer.add_array(name, np.array(vals, dtype=np.int32))
                    if 'tokenizer' in name:
                        print(f"  {name} = [{len(vals)} int32s]")
                elif elem_type == gguf.GGUFValueType.FLOAT32:
                    vals = []
                    for idx in field.data:
                        val_data = field.parts[idx]
                        vals.append(struct.unpack('<f', bytes(val_data))[0])
                    import numpy as np
                    writer.add_array(name, np.array(vals, dtype=np.float32))
                    if 'tokenizer' in name:
                        print(f"  {name} = [{len(vals)} float32s]")
                else:
                    print(f"  SKIP array {name} (unsupported element type {elem_type})")
            else:
                print(f"  SKIP array {name} (no element type)")
        else:
            print(f"  SKIP {name} (unsupported type {field_type})")

    # Add the missing pre-tokenizer type
    writer.add_string("tokenizer.ggml.pre", pre_tokenizer)
    print(f"\n  ADDED: tokenizer.ggml.pre = {pre_tokenizer}")

    # Copy all tensors
    print(f"\nCopying {len(reader.tensors)} tensors...")
    for tensor in reader.tensors:
        # Get the raw tensor data
        data = tensor.data
        writer.add_tensor(tensor.name, data, raw_dtype=tensor.tensor_type)

    print(f"  Copied {len(reader.tensors)} tensors")

    # Write
    print(f"\nWriting: {output_path}")
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()

    file_size = Path(output_path).stat().st_size
    print(f"\nDone! Output: {file_size / (1024**3):.2f} GiB")
    if has_pre:
        print("  Replaced existing tokenizer.ggml.pre")
    else:
        print("  Added missing tokenizer.ggml.pre")


def main():
    parser = argparse.ArgumentParser(description="Patch GGUF tokenizer metadata")
    parser.add_argument("--input", type=Path, required=True, help="Input GGUF file")
    parser.add_argument("--output", type=Path, required=True, help="Output GGUF file")
    parser.add_argument("--pre", type=str, default="llama-bpe", help="Pre-tokenizer type")
    args = parser.parse_args()

    patch_gguf(args.input, args.output, args.pre)


if __name__ == '__main__':
    main()
