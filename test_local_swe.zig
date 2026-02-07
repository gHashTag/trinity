// Test IGLA Local SWE Agent - Pure Local Code Generation
const std = @import("std");
const IglaLocalSWE = @import("src/vibeec/igla_local_swe.zig").IglaLocalSWE;
const Language = @import("src/vibeec/igla_local_swe.zig").Language;
const TaskType = @import("src/vibeec/igla_local_swe.zig").TaskType;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TEST: IGLA LOCAL SWE - Pure Local Coding Agent          ║\n", .{});
    std.debug.print("║     BitNet-2B | M1 Pro | 100%% LOCAL | No Cloud              ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Initialize SWE agent
    var swe = IglaLocalSWE.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer swe.deinit();

    // Test 1: Hello World Zig
    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 1: Generate Hello World (Zig)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    const result1 = swe.execute(.{
        .task = .CodeGen,
        .language = .Zig,
        .prompt = "Write a simple hello world program",
        .max_tokens = 128,
    }) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer allocator.free(result1.code);
    defer allocator.free(result1.explanation);

    std.debug.print("\nGenerated Code:\n", .{});
    std.debug.print("```zig\n{s}\n```\n", .{result1.code});
    std.debug.print("\nTokens: {d}, Time: {d}ms, Source: {s}\n", .{
        result1.tokens_generated,
        result1.inference_time_ms,
        result1.source,
    });

    // Test 2: Fibonacci Python
    std.debug.print("\n═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 2: Generate Fibonacci (Python)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    const result2 = swe.execute(.{
        .task = .CodeGen,
        .language = .Python,
        .prompt = "Write a recursive fibonacci function",
        .max_tokens = 128,
    }) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer allocator.free(result2.code);
    defer allocator.free(result2.explanation);

    std.debug.print("\nGenerated Code:\n", .{});
    std.debug.print("```python\n{s}\n```\n", .{result2.code});
    std.debug.print("\nTokens: {d}, Time: {d}ms, Source: {s}\n", .{
        result2.tokens_generated,
        result2.inference_time_ms,
        result2.source,
    });

    // Print final statistics
    swe.printStats();

    std.debug.print("\n✓ IGLA LOCAL SWE TEST COMPLETE - 100%% LOCAL, NO CLOUD!\n\n", .{});
}
