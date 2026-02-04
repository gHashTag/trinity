# Firebird WASM Module

This directory will contain the compiled WASM module for high-performance ternary operations.

## Building WASM

To compile the Firebird engine to WASM:

```bash
cd /workspaces/trinity
zig build-lib -target wasm32-freestanding -O ReleaseFast src/firebird/extension_wasm.zig -o extension/chrome/wasm/firebird.wasm
```

## Module Exports

The WASM module exports:
- `evolve(dim, generations, target_similarity)` - Evolve fingerprint
- `bind(vec_a, vec_b)` - VSA bind operation
- `similarity(vec_a, vec_b)` - Cosine similarity
- `generate_fingerprint(dim, seed)` - Generate random fingerprint

## Usage in Extension

```javascript
const wasm = await WebAssembly.instantiateStreaming(
  fetch(chrome.runtime.getURL('wasm/firebird.wasm'))
);

const result = wasm.instance.exports.evolve(10000, 100, 0.85);
```

## Note

For MVP, the extension uses a JavaScript implementation of the evolution algorithm.
WASM integration will be added in v1.1 for 10-100x performance improvement.
