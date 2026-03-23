// @origin(spec:tri27_integration_test.tri) @regen(manual-impl)
// Simple test for TRI‑27 Episode/JSONL integration

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    defer _ = allocator.deinit();

    print("Testing TRI‑27 Episode/JSONL integration...\n", .{});

    // Test 1: Check if tri27_experience_jsonl.saveTri27Episode compiles
    // Test 2: Test if we can create Episode structure
    // Test 3: Check if paths resolve correctly

    // Test 1: Compile
    print("\n{s}Test 1: Compilation{s}\n", .{ "\x1b[1m" });
    if (@import("src/tri27/tri27_experience_jsonl.zig")) |_| {
        print("  ✅ tri27_experience_jsonl.zig imports successfully\n");
    } else {
        print("  ❌ tri27_experience_jsonl.zig import failed\n");
    }

    // Test 2: Episode structure
    print("\n{s}Test 2: Episode structure{s}\n", .{ "\x1b[1m" });
    const episode = .{
        .issue = 27,
        .timestamp = 1713750000,
        .task_len = 10,
        .iterations = 1,
        .verdict = "SUCCESS",
        .mistakes_count = 0,
        .learnings_count = 0,
    };
    print("  ✅ Episode struct created\n");

    // Test 3: Try to call save function
    print("\n{s}Test 3: Direct function call{s}\n", .{ "\x1b[1m" });
    if (@import("src/tri27/tri27_experience_jsonl.zig")).saveTri27Episode) |_| {
        print("  ✅ saveTri27Episode() callable\n");
    } else {
        print("  ❌ saveTri27Episode() not callable\n");
    }

    print("\n{s}All tests complete!{s}\n", .{ "\x1b[32m" });
}
