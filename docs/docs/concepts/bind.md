---
sidebar_position: 2
---

# Bind Operation

**Bind** creates an association between two vectors. It's the VSA equivalent of XOR.

## Definition

For balanced ternary, bind is element-wise multiplication:

```
bind(a, b)[i] = a[i] * b[i]
```

Results:
- (-1) * (-1) = +1
- (-1) * 0 = 0
- (-1) * (+1) = -1
- 0 * x = 0
- (+1) * (+1) = +1

## Properties

### Self-Inverse

```zig
bind(a, a) = all +1 (for non-zero elements)
```

### Reversibility

```zig
bind(a, bind(a, b)) = b
```

This allows "unbinding" to recover the original:

```zig
var bound = trinity.bind(&key, &value);
var recovered = trinity.unbind(&bound, &key);
// recovered ≈ value
```

### Dissimilarity

Bound vectors are dissimilar to their inputs:

```zig
cosine(a, bind(a, b)) ≈ 0
```

## Use Cases

### Key-Value Storage

```zig
// Store: key -> value
var pair = trinity.bind(&key, &value);

// Retrieve: given key, find value
var retrieved = trinity.bind(&pair, &key);
// retrieved ≈ value
```

### Role-Filler Binding

```zig
// "red apple"
var color_role = trinity.randomVector(256, 1);
var red_value = trinity.randomVector(256, 2);
var apple_object = trinity.randomVector(256, 3);

var red_apple = trinity.bind(&color_role, &red_value);
red_apple = trinity.bind(&red_apple, &apple_object);
```

## API

```zig
// Bind two vectors
var result = trinity.bind(&a, &b);

// Unbind (same as bind for balanced ternary)
var unbound = trinity.unbind(&bound, &key);
```

## Performance

| Operation | Time | Throughput |
|-----------|------|------------|
| Bind | 602 ns/op | 425 M trits/sec |
