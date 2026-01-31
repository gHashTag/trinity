---
sidebar_position: 3
---

# Bundle Operation

**Bundle** combines multiple vectors into a single vector that is similar to all inputs.

## Definition

Bundle is element-wise addition with normalization (majority voting):

```
bundle(a, b)[i] = sign(a[i] + b[i])
```

For 3 vectors (true majority):
```
bundle(a, b, c)[i] = majority(a[i], b[i], c[i])
```

## Properties

### Similarity Preservation

The bundled vector is similar to all inputs:

```zig
var bundled = trinity.bundle2(&a, &b);
cosine(bundled, a) > 0  // Similar to a
cosine(bundled, b) > 0  // Similar to b
```

### Superposition

Bundle creates a superposition of concepts:

```zig
// "fruits" = apple + banana + orange
var fruits = trinity.bundle3(&apple, &banana, &orange);
```

### Capacity

A bundle can hold approximately √D items before interference becomes significant (D = dimension).

## Use Cases

### Set Representation

```zig
// Set of colors
var colors = trinity.bundle3(&red, &green, &blue);

// Check membership
const is_red = trinity.cosineSimilarity(&colors, &red);
// is_red > 0 means red is in the set
```

### Memory Storage

```zig
// Store multiple associations
var memory = trinity.bundle2(&red_apple, &yellow_banana);

// Query works on bundled memory
var query = trinity.bind(&memory, &red);
```

### Concept Composition

```zig
// "vehicle" = car + truck + bus
var vehicle = trinity.bundle3(&car, &truck, &bus);
```

## API

```zig
// Bundle 2 vectors
var result = trinity.bundle2(&a, &b);

// Bundle 3 vectors (true majority voting)
var result = trinity.bundle3(&a, &b, &c);
```

## Performance

| Operation | Time | Throughput |
|-----------|------|------------|
| Bundle2 | ~50 ns/op | ~5 B trits/sec |
| Bundle3 | 75 ns/op | 3.4 B trits/sec |
