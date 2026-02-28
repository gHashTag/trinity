---
sidebar_position: 4
---

# SDK API

High-level developer API for Hyperdimensional Computing applications.

**Module:** `src/sdk.zig`

## Overview

The Trinity SDK provides a simplified, intuitive interface for working with Vector Symbolic Architecture (VSA) operations. While the low-level VSA API (`src/vsa.zig`) operates directly on `HybridBigInt` structures, the SDK wraps these operations into user-friendly types:

| Level | Module | Purpose |
|-------|--------|---------|
| **Low-Level** | `vsa.zig` | Direct VSA operations on `HybridBigInt` |
| **High-Level** | `sdk.zig` | Developer-friendly wrappers with semantics |

### SDK Components

The SDK consists of six main types:

- **Hypervector** - Main abstraction for VSA operations
- **Codebook** - Symbol-to-vector mapping with encoding/decoding
- **AssociativeMemory** - Key-value storage using binding
- **SequenceEncoder** - Ordered data representation via permutation
- **GraphEncoder** - Relational triple encoding (subject-predicate-object)
- **Classifier** - Simple HDC-based machine learning

---

## Hypervector

The primary type for all VSA operations. Wraps `HybridBigInt` with labeled semantics and intuitive methods.

### Construction

#### init(dim: usize) → Hypervector

Creates a zero hypervector with specified dimension.

```zig
var hv = Hypervector.init(1000);
```

#### random(dim: usize, seed: u64) → Hypervector

Creates a random hypervector (for atomic symbols).

```zig
var hv = Hypervector.random(1000, 42);
```

#### randomLabeled(dim: usize, seed: u64, label: []const u8) → Hypervector

Creates a random hypervector with a label for debugging.

```zig
var cat = Hypervector.randomLabeled(1000, 42, "cat");
```

#### fromRaw(raw: HybridBigInt) → Hypervector

Wraps an existing `HybridBigInt` into a `Hypervector`.

```zig
var raw = vsa.randomVector(1000, 42);
var hv = Hypervector.fromRaw(raw);
```

### Accessors

#### getDimension() → usize

Returns the number of trits in the hypervector.

```zig
const dim = hv.getDimension(); // 1000
```

#### get(index: usize) → Trit

Returns the trit value at position (-1, 0, or +1).

```zig
const trit = hv.get(5); // Returns: -1, 0, or +1
```

#### set(index: usize, value: Trit) → void

Sets the trit at a specific position.

```zig
hv.set(5, 1); // Set position 5 to +1
```

### VSA Operations

#### bind(other: *Hypervector) → Hypervector

Creates an associative binding between two hypervectors.

**Properties:**
- Self-inverse: `bind(A, A)` = all +1
- Unbind reverses: `unbind(bind(A, B), B)` ≈ A

```zig
var associated = key.bind(&value);
```

#### unbind(key: *Hypervector) → Hypervector

Retrieves a hypervector from a binding.

```zig
var recovered = bound.unbind(&key);
```

#### bundle(other: *Hypervector) → Hypervector

Combines two hypervectors via majority voting (superposition).

```zig
var combined = a.bundle(&b);
// combined is similar to both a and b
```

#### bundle3(b: *Hypervector, c: *Hypervector) → Hypervector

Combines three hypervectors via majority voting.

```zig
var combined = a.bundle3(&b, &c);
```

#### permute(k: usize) → Hypervector

Cyclic shift by k positions (for sequence encoding).

```zig
var shifted = hv.permute(3); // Shift right by 3
```

#### inversePermute(k: usize) → Hypervector

Inverse cyclic shift.

```zig
var restored = shifted.inversePermute(3);
```

### Similarity Measures

#### similarity(other: *Hypervector) → f64

Cosine similarity in range [-1, 1].

- `1.0` = identical
- `0.0` = orthogonal
- `-1.0` = opposite

```zig
const sim = a.similarity(&b);
if (sim > 0.8) {
    // Highly similar
}
```

#### hammingDistance(other: *Hypervector) → usize

Count of differing trit positions.

```zig
const dist = a.hammingDistance(&b);
```

#### hammingSimilarity(other: *Hypervector) → f64

Normalized Hamming similarity in [0, 1].

```zig
const sim = a.hammingSimilarity(&b);
```

#### dotSimilarity(other: *Hypervector) → f64

Dot product similarity.

```zig
const sim = a.dotSimilarity(&b);
```

### Utility Methods

#### countNonZero() → usize

Returns the count of non-zero trits.

```zig
const active = hv.countNonZero();
```

#### density() → f64

Ratio of non-zero trits [0, 1].

```zig
const density = hv.density();
// density = countNonZero() / getDimension()
```

#### clone() → Hypervector

Creates a deep copy of the hypervector.

```zig
var copy = hv.clone();
```

#### negate() → Hypervector

Negates all trits (-1 → +1, +1 → -1, 0 → 0).

```zig
var inverted = hv.negate();
```

---

## Codebook

Maps symbols (strings) to hypervectors for encoding and decoding.

### Initialization

#### init(allocator: Allocator, dimension: usize) → Codebook

Creates a new codebook with specified dimension.

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
var codebook = Codebook.init(allocator, 1000);
defer codebook.deinit();
```

### Encoding

#### encode(symbol: []const u8) → !*Hypervector

Gets or creates a hypervector for a symbol. Uses deterministic hashing.

```zig
const cat_hv = try codebook.encode("cat");
const dog_hv = try codebook.encode("dog");
```

### Decoding

#### decode(query: *Hypervector) → ?[]const u8

Finds the symbol most similar to the query hypervector.

```zig
const symbol = codebook.decode(&query);
if (symbol) |s| {
    std.debug.print("Matched: {s}\n", .{s});
}
```

#### decodeWithThreshold(query: *Hypervector, threshold: f64) → ?[]const u8

Decodes with minimum similarity threshold.

```zig
const symbol = codebook.decodeWithThreshold(&query, 0.7);
// Returns null if no symbol has similarity >= 0.7
```

#### findSimilar(query: *Hypervector, threshold: f64, results: *ArrayList(SimilarityResult)) → !void

Finds all symbols above the similarity threshold.

```zig
var results = std.ArrayList(SimilarityResult).init(allocator);
try codebook.findSimilar(&query, 0.5, &results);

for (results.items) |result| {
    std.debug.print("{s}: {d:.2}\n", .{result.symbol, result.similarity});
}
```

### Utility

#### count() → usize

Returns the number of symbols in the codebook.

```zig
const size = codebook.count();
```

---

## AssociativeMemory

Key-value storage using binding operations. Stores multiple associations in a single hypervector.

### Initialization

#### init(dimension: usize) → AssociativeMemory

Creates an empty associative memory.

```zig
var memory = AssociativeMemory.init(1000);
```

### Operations

#### store(key: *Hypervector, value: *Hypervector) → void

Stores a key-value association.

```zig
var key = Hypervector.random(1000, 1);
var value = Hypervector.random(1000, 2);
memory.store(&key, &value);
```

**Internal operation:**
```zig
memory = bundle(memory, bind(key, value))
```

#### retrieve(key: *Hypervector) → Hypervector

Retrieves a value by key (returns noisy approximation).

```zig
var retrieved = memory.retrieve(&key);
const similarity = retrieved.similarity(&value);
// Typically > 0.2 for successful retrieval
```

#### contains(key: *Hypervector, threshold: f64) → bool

Checks if a key exists in memory.

```zig
if (memory.contains(&key, 0.1)) {
    // Key exists
}
```

#### clear() → void

Clears all stored associations.

```zig
memory.clear();
```

#### count() → usize

Returns the number of stored items.

```zig
const count = memory.count();
```

---

## SequenceEncoder

Encodes ordered sequences using permutation. Each position in the sequence is shifted by its index.

### Initialization

#### init(dimension: usize) → SequenceEncoder

Creates a sequence encoder.

```zig
var encoder = SequenceEncoder.init(1000);
```

### Operations

#### encode(items: []Hypervector) → Hypervector

Encodes a sequence of hypervectors.

**Formula:**
```
result = items[0] + permute(items[1], 1) + permute(items[2], 2) + ...
```

```zig
var items = [_]Hypervector{
    Hypervector.random(1000, 1),
    Hypervector.random(1000, 2),
    Hypervector.random(1000, 3),
};
var sequence = encoder.encode(&items);
```

#### probe(sequence: *Hypervector, candidate: *Hypervector, position: usize) → f64

Tests similarity of a candidate at a specific position.

```zig
const sim = encoder.probe(&sequence, &candidate, 2);
if (sim > 0.6) {
    // Candidate likely at position 2
}
```

#### findPosition(sequence: *Hypervector, candidate: *Hypervector, max_length: usize, threshold: f64) → ?usize

Finds the position of a candidate in the sequence.

```zig
if (encoder.findPosition(&sequence, &candidate, 10, 0.5)) |pos| {
    std.debug.print("Found at position: {}\n", .{pos});
}
```

---

## GraphEncoder

Encodes relational triples (subject-predicate-object) using role vectors.

### Initialization

#### init(dim: usize) → GraphEncoder

Creates a graph encoder with random role vectors.

```zig
var encoder = GraphEncoder.init(1000);
```

**Internal role vectors:**
- `role_subject` - random(seed=0x5B)
- `role_predicate` - random(seed=0x9D)
- `role_object` - random(seed=0x0B)

### Operations

#### encodeTriple(subject: *Hypervector, predicate: *Hypervector, object: *Hypervector) → Hypervector

Encodes a triple (S, P, O).

**Formula:**
```
triple = bind(role_s, S) + bind(role_p, P) + bind(role_o, O)
```

```zig
var s = Hypervector.randomLabeled(1000, 1, "Paris");
var p = Hypervector.randomLabeled(1000, 2, "capital_of");
var o = Hypervector.randomLabeled(1000, 3, "France");

var triple = encoder.encodeTriple(&s, &p, &o);
```

#### querySubject(triple: *Hypervector) → Hypervector

Extracts the subject from a triple.

```zig
var subject = encoder.querySubject(&triple);
const similarity = subject.similarity(&s); // Should be high
```

#### queryPredicate(triple: *Hypervector) → Hypervector

Extracts the predicate from a triple.

```zig
var predicate = encoder.queryPredicate(&triple);
```

#### queryObject(triple: *Hypervector) → Hypervector

Extracts the object from a triple.

```zig
var object = encoder.queryObject(&triple);
```

---

## Classifier

Simple Hyperdimensional Computing classifier using prototype learning.

### Initialization

#### init(allocator: Allocator, dimension: usize) → Classifier

Creates a new classifier.

```zig
var classifier = Classifier.init(allocator, 1000);
defer classifier.deinit();
```

### Training

#### train(class_name: []const u8, sample: *Hypervector) → !void

Adds a sample to a class. Bundles with existing class vector.

```zig
var sample1 = Hypervector.random(1000, 1);
var sample2 = Hypervector.random(1000, 2);

try classifier.train("positive", &sample1);
try classifier.train("positive", &sample2);
```

### Prediction

#### predict(sample: *Hypervector) → ?[]const u8

Returns the most similar class name.

```zig
var test = Hypervector.random(1000, 3);
if (classifier.predict(&test)) |class| {
    std.debug.print("Predicted: {s}\n", .{class});
}
```

#### predictWithConfidence(sample: *Hypervector) → struct { class: ?[]const u8, confidence: f64 }

Returns prediction with similarity score.

```zig
var result = classifier.predictWithConfidence(&test);
if (result.class) |class| {
    std.debug.print("Class: {s}, Confidence: {d:.2}\n", .{class, result.confidence});
}
```

### Utility

#### classCount() → usize

Returns the number of classes.

```zig
const num_classes = classifier.classCount();
```

---

## Usage Examples

### Example 1: Symbolic Reasoning

```zig
const std = @import("std");
const sdk = @import("trinity").sdk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Create codebook for symbols
    var codebook = sdk.Codebook.init(allocator, 1000);
    defer codebook.deinit();

    // Encode entities
    const cat = try codebook.encode("cat");
    const dog = try codebook.encode("dog");
    const mammal = try codebook.encode("mammal");
    const animal = try codebook.encode("animal");

    // Create associative memory
    var memory = sdk.AssociativeMemory.init(1000);

    // Store facts: cat → mammal, mammal → animal
    memory.store(cat, mammal);
    memory.store(mammal, animal);

    // Query: what is cat related to?
    var retrieved = memory.retrieve(cat);
    const decoded = codebook.decode(&retrieved);
    std.debug.print("cat is a {s}\n", .{decoded}); // "mammal"
}
```

### Example 2: Sequence Processing

```zig
const std = @import("std");
const sdk = @import("trinity").sdk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var codebook = sdk.Codebook.init(allocator, 1000);
    defer codebook.deinit();

    // Encode words
    const the = try codebook.encode("the");
    const quick = try codebook.encode("quick");
    const brown = try codebook.encode("brown");
    const fox = try codebook.encode("fox");

    // Create sequence encoder
    var encoder = sdk.SequenceEncoder.init(1000);

    // Encode sentence
    var words = [_]sdk.Hypervector{ the.*, quick.*, brown.*, fox.* };
    var sentence = encoder.encode(&words);

    // Probe for words
    const pos_fox = encoder.findPosition(&sentence, fox, 10, 0.5);
    std.debug.print("'fox' at position: {?}\n", .{pos_fox}); // 3
}
```

### Example 3: Knowledge Graph

```zig
const std = @import("std");
const sdk = @import("trinity").sdk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var codebook = sdk.Codebook.init(allocator, 1000);
    defer codebook.deinit();

    // Encode entities and relations
    const paris = try codebook.encode("Paris");
    const france = try codebook.encode("France");
    const capital = try codebook.encode("capital_of");

    // Create graph encoder
    var graph = sdk.GraphEncoder.init(1000);

    // Encode triple: Paris → capital_of → France
    var triple = graph.encodeTriple(paris, capital, france);

    // Query: what is Paris the capital of?
    var object = graph.queryObject(&triple);
    const country = codebook.decode(&object);
    std.debug.print("Paris is capital of: {s}\n", .{country}); // "France"

    // Query: what is the capital of France?
    var subject = graph.querySubject(&triple);
    const city = codebook.decode(&subject);
    std.debug.print("Capital of France: {s}\n", .{city}); // "Paris"
}
```

### Example 4: Text Classification

```zig
const std = @import("std");
const sdk = @import("trinity").sdk;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var classifier = sdk.Classifier.init(allocator, 1000);
    defer classifier.deinit();

    var codebook = sdk.Codebook.init(allocator, 1000);
    defer codebook.deinit();

    // Training data
    const positive_words = [_][]const u8{ "good", "great", "excellent", "amazing" };
    const negative_words = [_][]const u8{ "bad", "terrible", "awful", "poor" };

    // Train positive class
    for (positive_words) |word| {
        const hv = try codebook.encode(word);
        try classifier.train("positive", hv);
    }

    // Train negative class
    for (negative_words) |word| {
        const hv = try codebook.encode(word);
        try classifier.train("negative", hv);
    }

    // Classify new text
    const test_word = try codebook.encode("excellent");
    var result = classifier.predictWithConfidence(&test_word);

    std.debug.print("Class: {s}, Confidence: {d:.2}\n", .{
        result.class orelse "unknown",
        result.confidence
    }); // "positive", high confidence
}
```

---

## Best Practices

### 1. Choose Appropriate Dimensions

| Use Case | Recommended Dimension |
|----------|----------------------|
| Symbolic reasoning | 512 - 1000 |
| Sequence encoding | 1000 - 2000 |
| Graph encoding | 1000+ |
| Text classification | 2000+ |

Higher dimensions improve capacity and noise resistance but increase memory/compute.

### 2. Similarity Thresholds

Guidelines for similarity thresholds:

| Threshold | Interpretation |
|-----------|----------------|
| `> 0.8` | Strong match (identical or near-identical) |
| `0.6 - 0.8` | Good match (likely correct) |
| `0.4 - 0.6` | Weak match (ambiguous) |
| `< 0.4` | Poor match (noise or unrelated) |

Adjust based on your application's tolerance for false positives/negatives.

### 3. Associative Memory Capacity

As a rule of thumb, associative memory can reliably store:
- **~10 items** with high accuracy (> 0.8 similarity)
- **~50 items** with moderate accuracy (> 0.5 similarity)

Beyond this, use sharding or hierarchical memory.

### 4. Sequence Position Limits

`SequenceEncoder.findPosition()` searches up to `max_length`. For practical purposes:
- Keep sequences under 20 items for best results
- Longer sequences require higher dimensions

### 5. Classifier Training

For best classification accuracy:
- Use balanced training data (similar samples per class)
- Train with 5-10 samples minimum per class
- More diverse samples → better generalization

---

## Performance Considerations

### Memory Usage

| Type | Memory per item (dim=1000) |
|------|---------------------------|
| Hypervector | ~1.5 KB (packed) |
| Codebook entry | ~1.5 KB + string overhead |
| AssociativeMemory | ~1.5 KB (single bundled vector) |

### Computation Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| bind/unbind | O(n) | n = dimension |
| bundle2/bundle3 | O(n) | Majority voting |
| similarity | O(n) | Dot product |
| Codebook.encode | O(n) | Hash + random generation |
| Codebook.decode | O(k·n) | k = symbol count |
| SequenceEncoder.encode | O(m·n) | m = sequence length |
| GraphEncoder.query* | O(n) | Single unbind |

### Optimization Tips

1. **Reuse hypervectors** - Clone is cheaper than regenerating
2. **Batch operations** - Bundle multiple items at once
3. **Use packed mode** - `HybridBigInt.pack()` when not computing
4. **Limit codebook size** - Decode is O(k), prefer smaller dictionaries
5. **Cache similarities** - Expensive recomputation

---

## Integration Examples

### With Low-Level VSA API

```zig
const sdk = @import("trinity").sdk;
const vsa = @import("trinity").vsa;

// Can convert between SDK and VSA
var hv = sdk.Hypervector.random(1000, 42);

// Access raw HybridBigInt
const raw = hv.data; // HybridBigInt

// Use low-level operations
const processed = vsa.permute(&raw, 3);

// Wrap back in SDK
var result = sdk.Hypervector.fromRaw(processed);
```

### With Custom Allocators

```zig
const std = @import("std");
const sdk = @import("trinity").sdk;

pub fn main() !void {
    // Use arena allocator for temporary operations
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var codebook = sdk.Codebook.init(allocator, 1000);
    // ... use codebook

    // Everything freed at once
}
```

### Error Handling

```zig
const sdk = @import("trinity").sdk;

pub fn classifyWord(word: []const u8) ![]const u8 {
    // Returns error on allocation failure
    const hv = try codebook.encode(word);

    // Returns null if no match found
    const decoded = codebook.decodeWithThreshold(&hv, 0.7)
        orelse return error.NoMatch;

    return decoded;
}
```

---

## See Also

- [VSA API](/api/vsa) - Low-level Vector Symbolic Architecture
- [Hybrid API](/api/hybrid) - HybridBigInt storage internals
- [C API](/api/c-api) - C library bindings
- [Python SDK](/api/python-sdk) - Python bindings
