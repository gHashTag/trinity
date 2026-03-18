// Trinity SDK - Basic Usage Example
// Demonstrates core hypervector operations for developers
//
// Run: zig build-exe examples/sdk_basics.zig --mod trinity:src/trinity.zig -OReleaseFast
// Or:  zig run examples/sdk_basics.zig --mod trinity:src/trinity.zig

const std = @import("std");
const trinity = @import("trinity");

const Hypervector = trinity.Hypervector;
const Codebook = trinity.Codebook;
const AssociativeMemory = trinity.AssociativeMemory;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    TRINITY SDK BASICS\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Creating Hypervectors
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("1. CREATING HYPERVECTORS\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // Create random hypervectors (atomic symbols)
    var apple = Hypervector.random(1000, 0xAPPLE);
    var banana = Hypervector.random(1000, 0xBANANA);
    var fruit = Hypervector.random(1000, 0xFRUIT);

    try stdout.print("Created hypervectors: apple, banana, fruit (dim=1000)\n", .{});
    try stdout.print("Apple density: {d:.2}%\n", .{apple.density() * 100});
    try stdout.print("Non-zero trits: {d}\n\n", .{apple.countNonZero()});

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Similarity Measures
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("2. SIMILARITY MEASURES\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // Random vectors are nearly orthogonal
    const sim_ab = apple.similarity(&banana);
    const sim_aa = apple.similarity(&apple);

    try stdout.print("Similarity(apple, apple):  {d:.4} (self-similarity)\n", .{sim_aa});
    try stdout.print("Similarity(apple, banana): {d:.4} (nearly orthogonal)\n", .{sim_ab});
    try stdout.print("Hamming similarity:        {d:.4}\n\n", .{apple.hammingSimilarity(&banana)});

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Bind Operation (Associations)
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("3. BIND OPERATION (ASSOCIATIONS)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // bind(apple, fruit) = "apple is a fruit"
    var apple_is_fruit = apple.bind(&fruit);

    try stdout.print("Created: apple_is_fruit = bind(apple, fruit)\n", .{});
    try stdout.print("Similarity to apple: {d:.4}\n", .{apple_is_fruit.similarity(&apple)});
    try stdout.print("Similarity to fruit: {d:.4}\n", .{apple_is_fruit.similarity(&fruit)});

    // Unbind to recover
    var recovered_fruit = apple_is_fruit.unbind(&apple);
    try stdout.print("Recovered fruit via unbind: similarity = {d:.4}\n\n", .{recovered_fruit.similarity(&fruit)});

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Bundle Operation (Superposition)
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("4. BUNDLE OPERATION (SUPERPOSITION)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    // bundle(apple, banana) = "apple and banana"
    var fruits = apple.bundle(&banana);

    try stdout.print("Created: fruits = bundle(apple, banana)\n", .{});
    try stdout.print("Similarity to apple:  {d:.4}\n", .{fruits.similarity(&apple)});
    try stdout.print("Similarity to banana: {d:.4}\n", .{fruits.similarity(&banana)});
    try stdout.print("Similarity to fruit:  {d:.4} (unrelated)\n\n", .{fruits.similarity(&fruit)});

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Permute Operation (Sequences)
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("5. PERMUTE OPERATION (SEQUENCES)\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    var permuted = apple.permute(1);
    var recovered = permuted.inversePermute(1);

    try stdout.print("permute(apple, 1) similarity to apple: {d:.4}\n", .{permuted.similarity(&apple)});
    try stdout.print("After inverse permute: {d:.4}\n\n", .{recovered.similarity(&apple)});

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Associative Memory
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("6. ASSOCIATIVE MEMORY\n", .{});
    try stdout.print("─────────────────────────────────────────────────────────────────\n", .{});

    var memory = AssociativeMemory.init(1000);

    // Store associations
    var red = Hypervector.random(1000, 0xRED);
    var yellow = Hypervector.random(1000, 0xYELLOW);

    memory.store(&apple, &red); // apple -> red
    memory.store(&banana, &yellow); // banana -> yellow

    try stdout.print("Stored: apple->red, banana->yellow\n", .{});

    // Retrieve
    var retrieved_color = memory.retrieve(&apple);
    try stdout.print("Retrieved color for apple: similarity to red = {d:.4}\n", .{retrieved_color.similarity(&red)});
    try stdout.print("Items in memory: {d}\n\n", .{memory.count()});

    // ─────────────────────────────────────────────────────────────────────────
    // Summary
    // ─────────────────────────────────────────────────────────────────────────
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("                    SUMMARY\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════\n", .{});
    try stdout.print("✓ Hypervectors: high-dimensional sparse ternary vectors\n", .{});
    try stdout.print("✓ Bind: creates associations (self-inverse)\n", .{});
    try stdout.print("✓ Bundle: creates superpositions (similar to all inputs)\n", .{});
    try stdout.print("✓ Permute: encodes position/sequence\n", .{});
    try stdout.print("✓ Similarity: measures relatedness [-1, 1]\n", .{});
    try stdout.print("\nφ² + 1/φ² = 3\n\n", .{});
}
