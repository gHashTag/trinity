---
sidebar_position: 3
---

# Quick Start

This guide will help you build your first VSA application with Trinity.

## Creating Vectors

In VSA, everything is represented as high-dimensional vectors:

```zig
const trinity = @import("trinity");

// Create random vectors (256 dimensions)
var apple = trinity.randomVector(256, 1);  // seed = 1
var banana = trinity.randomVector(256, 2); // seed = 2
var red = trinity.randomVector(256, 3);
var yellow = trinity.randomVector(256, 4);
```

## Binding: Creating Associations

**Bind** creates an association between two concepts:

```zig
// "red apple" = bind(apple, red)
var red_apple = trinity.bind(&apple, &red);

// "yellow banana" = bind(banana, yellow)
var yellow_banana = trinity.bind(&banana, &yellow);
```

Properties of bind:
- `bind(a, a)` = all +1 (self-inverse)
- `bind(a, bind(a, b))` = b (reversible)

## Bundling: Combining Concepts

**Bundle** combines multiple vectors into one:

```zig
// Memory contains both associations
var memory = trinity.bundle2(&red_apple, &yellow_banana);
```

The bundled vector is similar to all inputs.

## Querying: Finding Associations

To query "What is red?", bind memory with red:

```zig
var query = trinity.bind(&memory, &red);

// Check similarity with concepts
const sim_apple = trinity.cosineSimilarity(&query, &apple);
const sim_banana = trinity.cosineSimilarity(&query, &banana);

// apple should have higher similarity
```

## Complete Example

```zig
const std = @import("std");
const trinity = @import("trinity");

pub fn main() !void {
    // Create concepts
    var apple = trinity.randomVector(256, 1);
    var banana = trinity.randomVector(256, 2);
    var red = trinity.randomVector(256, 3);
    var yellow = trinity.randomVector(256, 4);

    // Create associations
    var red_apple = trinity.bind(&apple, &red);
    var yellow_banana = trinity.bind(&banana, &yellow);

    // Store in memory
    var memory = trinity.bundle2(&red_apple, &yellow_banana);

    // Query: "What is red?"
    var query = trinity.bind(&memory, &red);

    const sim_apple = trinity.cosineSimilarity(&query, &apple);
    const sim_banana = trinity.cosineSimilarity(&query, &banana);

    std.debug.print("Query: What is red?\n", .{});
    std.debug.print("  Apple:  {d:.4}\n", .{sim_apple});
    std.debug.print("  Banana: {d:.4}\n", .{sim_banana});
    std.debug.print("  Answer: {s}\n", .{
        if (sim_apple > sim_banana) "Apple!" else "Banana!"
    });
}
```

## Next Steps

- [Bind Operation](concepts/bind) - Deep dive into binding
- [Bundle Operation](concepts/bundle) - Learn about bundling
- [Permute Operation](concepts/permute) - Sequence encoding
