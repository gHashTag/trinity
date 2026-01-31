---
sidebar_position: 4
---

# Permute Operation

**Permute** encodes order and sequence information by cyclically shifting vector elements.

## Definition

Permute shifts elements to the right by k positions:

```
permute(v, k)[i] = v[(i - k) mod D]
```

Inverse permute shifts left:

```
inverse_permute(v, k)[i] = v[(i + k) mod D]
```

## Properties

### Reversibility

```zig
inverse_permute(permute(v, k), k) = v
```

### Orthogonality

Permuted vectors are nearly orthogonal to the original:

```zig
cosine(v, permute(v, k)) ≈ 0  // for k > 0
```

### Composition

```zig
permute(permute(v, a), b) = permute(v, a + b)
```

## Use Cases

### Sequence Encoding

Encode ordered sequences using permute:

```zig
// "the cat sat" = the + ρ(cat) + ρ²(sat)
var sentence = the;
var p1 = trinity.permute(&cat, 1);
var p2 = trinity.permute(&sat, 2);
sentence = sentence.add(&p1);
sentence = sentence.add(&p2);
```

Or use the helper function:

```zig
var items = [_]trinity.HybridBigInt{ the, cat, sat };
var sentence = trinity.encodeSequence(&items);
```

### Position Probing

Check if a word is at a specific position:

```zig
const similarity = trinity.probeSequence(&sentence, &cat, 1);
// High similarity means "cat" is at position 1
```

### N-grams

Encode n-grams for NLP:

```zig
// Bigram "the cat"
var bigram = trinity.bind(&the, &trinity.permute(&cat, 1));
```

## API

```zig
// Permute (shift right)
var shifted = trinity.permute(&v, k);

// Inverse permute (shift left)
var original = trinity.inversePermute(&shifted, k);

// Encode sequence
var items = [_]trinity.HybridBigInt{ a, b, c };
var seq = trinity.encodeSequence(&items);

// Probe sequence
const sim = trinity.probeSequence(&seq, &candidate, position);
```

## Performance

| Operation | Time | Throughput |
|-----------|------|------------|
| Permute | 509 ns/op | 502 M trits/sec |
| Inverse Permute | 509 ns/op | 502 M trits/sec |
