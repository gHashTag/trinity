---
sidebar_position: 4
---

# Hybrid API

HybridBigInt — Optimal Memory/Speed Trade-off.

**Module:** `src/hybrid.zig`

## Storage Modes

| Mode | Storage | Speed | Use Case |
|------|---------|-------|----------|
| Packed | 1.58 bits/trit | Slower | Storage |
| Unpacked | 8 bits/trit | Fast | Computation |

## Core Functions

### zero() → HybridBigInt

```zig
var v = HybridBigInt.zero();
```

### random(len) → HybridBigInt

```zig
var v = HybridBigInt.random(1000);
```

### pack() / ensureUnpacked()

```zig
vector.pack();           // Memory efficient
vector.ensureUnpacked(); // Compute efficient
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_TRITS` | 59049 | Maximum dimension |
| `SIMD_WIDTH` | 32 | Parallel trits |

## Memory Comparison

```jsx live
function MemoryDemo() {
  const [trits, setTrits] = React.useState(1000);

  // Storage calculations
  const binaryBits = trits * 2;          // 2 bits per trit (naive)
  const packedBits = trits * 1.585;      // log2(3) bits per trit
  const unpackedBits = trits * 8;        // 1 byte per trit

  const savings = ((binaryBits - packedBits) / binaryBits * 100).toFixed(1);

  return (
    <div style={{fontFamily: 'monospace'}}>
      <div>
        <label>Trits: </label>
        <input
          type="range"
          min="100"
          max="10000"
          value={trits}
          onChange={(e) => setTrits(Number(e.target.value))}
        />
        <span> {trits}</span>
      </div>
      <table style={{marginTop: '1rem', width: '100%'}}>
        <thead>
          <tr><th>Mode</th><th>Bits</th><th>Bytes</th></tr>
        </thead>
        <tbody>
          <tr>
            <td>Binary (2 bit)</td>
            <td>{binaryBits}</td>
            <td>{(binaryBits/8).toFixed(0)}</td>
          </tr>
          <tr style={{color: '#16a34a', fontWeight: 'bold'}}>
            <td>Packed (1.58 bit)</td>
            <td>{packedBits.toFixed(0)}</td>
            <td>{(packedBits/8).toFixed(0)}</td>
          </tr>
          <tr>
            <td>Unpacked (8 bit)</td>
            <td>{unpackedBits}</td>
            <td>{(unpackedBits/8).toFixed(0)}</td>
          </tr>
        </tbody>
      </table>
      <div style={{marginTop: '0.5rem'}}>
        <b>Packed savings vs binary: {savings}%</b>
      </div>
    </div>
  );
}
```
