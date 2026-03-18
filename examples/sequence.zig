// Trinity - Sequence Encoding Example
const std = @import("std");
const trinity = @import("trinity");

pub fn main() !void {
    std.debug.print("\n=== Trinity Sequence Encoding ===\n\n", .{});

    // Create word vectors
    var the = trinity.randomVector(256, 100);
    var cat = trinity.randomVector(256, 101);
    var sat = trinity.randomVector(256, 102);

    // Encode sequence "the cat sat"
    var items = [_]trinity.HybridBigInt{ the, cat, sat };
    var sentence = trinity.encodeSequence(&items);

    std.debug.print("Sentence: 'the cat sat'\n\n", .{});

    // Probe positions
    std.debug.print("Probing word positions:\n", .{});
    for (0..4) |pos| {
        const sim_the = trinity.probeSequence(&sentence, &the, pos);
        const sim_cat = trinity.probeSequence(&sentence, &cat, pos);
        const sim_sat = trinity.probeSequence(&sentence, &sat, pos);

        std.debug.print("  Position {}: the={d:.3}, cat={d:.3}, sat={d:.3}\n", .{ pos, sim_the, sim_cat, sim_sat });
    }
}
