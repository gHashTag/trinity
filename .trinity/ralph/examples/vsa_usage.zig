//! ═══════════════════════════════════════════════════════════════════════════════
//! VSA USAGE REFERENCE (GOLDEN PATTERN)
//! Purpose: Demonstrate high-performance VSA operations in Zig
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const vsa = @import("vsa"); // Refer to src/vsa.zig (or as configured in build.zig)
const Hypervector = vsa.Hypervector;

pub fn example() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Create a Codebook (Identity state)
    var codebook = vsa.Codebook.init(allocator);
    defer codebook.deinit();

    // 2. Generate named identity vectors
    const v_apple = try codebook.getOrGenerate("apple");
    const v_color = try codebook.getOrGenerate("color");
    const v_red = try codebook.getOrGenerate("red");

    // 3. Bind properties (Attribute-Value pairing)
    // Concept: apple is red -> apple ^ (color * red)
    const property = v_color.bind(v_red);
    const apple_instance = v_apple.bundle(property);

    // 4. Query state
    const result_color = apple_instance.unbind(v_apple);
    const similarity = result_color.similarity(v_red);

    std.debug.print("Similarity to 'red': {d:.4}\n", .{similarity});
}

// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
