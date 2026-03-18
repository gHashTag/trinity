// Trinity - Associative Memory Example
const std = @import("std");
const trinity = @import("trinity");

pub fn main() !void {
    std.debug.print("\n=== Trinity Associative Memory ===\n\n", .{});

    // Create concept vectors
    var apple = trinity.randomVector(256, 1001);
    var banana = trinity.randomVector(256, 1002);
    var red = trinity.randomVector(256, 2001);
    var yellow = trinity.randomVector(256, 2002);

    // Create associations
    var red_apple = trinity.bind(&apple, &red);
    var yellow_banana = trinity.bind(&banana, &yellow);

    // Bundle into memory
    var memory = trinity.bundle2(&red_apple, &yellow_banana);

    // Query: "What is red?"
    var query = trinity.bind(&memory, &red);

    const sim_apple = trinity.cosineSimilarity(&query, &apple);
    const sim_banana = trinity.cosineSimilarity(&query, &banana);

    std.debug.print("Query: 'What is red?'\n", .{});
    std.debug.print("  Similarity to apple:  {d:.4}\n", .{sim_apple});
    std.debug.print("  Similarity to banana: {d:.4}\n", .{sim_banana});
    std.debug.print("  Answer: {s}\n\n", .{if (sim_apple > sim_banana) "apple" else "banana"});
}
