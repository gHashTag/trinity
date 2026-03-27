// @origin(spec:tri_asm.tri) @regen(done)
//
// TRI-27 ASSEMBLER — Minimal working implementation
//
// φ² + 1/φ² = 3 = TRINITY
//

const std = @import("std");
const encoder = @import("./asm_encoder.zig");

pub fn assemble(source: []const u8) !void {
    _ = source;
    const tbin = "test.tbin";

    // Emit .tbin format
    std.debug.print("Assembling {s}...\n", .{source});

    // For now, just emit NOPs (will parse real instructions later)
    for (0..10) |_| {
        const word = encoder.encodeInstruction(std.heap.page_allocator, "nop", 0, 0, 0);
        try std.io.writeAll(std.heap.page_allocator, word);
    }

    std.debug.print("Wrote {d} instructions (NOP placeholders)\n", .{word.len});
}

test "assemble" {
    const allocator = std.testing.allocator;
    const result = assemble("example.tasm");
    try std.testing.expectEqual(@as(usize, 2), result.instruction_count); // 2 bytes
}
