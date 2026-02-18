const std = @import("std");
const engine = @import("multilingual_engine.zig");

test "multilingual engine: smoke test" {
    // 1. Test Language Detection
    std.debug.print("\nTesting Language Detection...\n", .{});
    try engine.detect_input_language();

    // 2. Test Code Generation Dispatch
    std.debug.print("\nTesting Multilingual Generation Dispatch...\n", .{});
    try engine.generate_code();
}

test "multilingual engine: direct language gen" {
    std.debug.print("\nTesting Direct Generation:\n", .{});

    std.debug.print("--- Python ---\n", .{});
    try engine.gen_python();

    std.debug.print("--- Go ---\n", .{});
    try engine.gen_go();

    std.debug.print("--- Rust ---\n", .{});
    try engine.gen_rust();

    std.debug.print("--- Zig ---\n", .{});
    try engine.gen_zig();
}
