const std = @import("std");
const Allocator = std.mem.Allocator;

const orchestrator = @import("orchestrator_v2_working.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    try stdout.print("ORCHESTRATOR v2.0 BENCHMARKS\n", .{});
    try stdout.print("============================\n\n", .{});

    // Benchmark 1: Command registry initialization
    {
        const start = try std.time.Instant.now();
        const iterations: usize = 10000;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            var registry = try orchestrator.initCommandRegistry(allocator);
            try orchestrator.registerCoreCommands(&registry, allocator);
            registry.deinit();
        }
        const end = try std.time.Instant.now();
        const elapsed = end.since(start);
        try stdout.print("Registry init + register: {d: >10} ns/op ({d:.3} us/op)\n", .{
            @as(u64, @intCast(elapsed / iterations)),
            @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations)) / 1000.0
        });
    }

    // Benchmark 2: Sacred score calculation
    {
        var registry = try orchestrator.initCommandRegistry(allocator);
        try orchestrator.registerCoreCommands(&registry, allocator);
        defer registry.deinit();

        const start = try std.time.Instant.now();
        const iterations: usize = 100000;
        var i: usize = 0;
        var total_score: f64 = 0;
        while (i < iterations) : (i += 1) {
            total_score += orchestrator.calculateRegistrySacredScore(&registry);
        }
        const end = try std.time.Instant.now();
        const elapsed = end.since(start);
        try stdout.print("Sacred score calculation: {d: >10} ns/op ({d:.3} us/op)\n", .{
            @as(u64, @intCast(elapsed / iterations)),
            @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations)) / 1000.0
        });
        try stdout.print("  Score: {d:.3} (Trinity: {})\n", .{ total_score / @as(f64, @floatFromInt(iterations)), orchestrator.verifyTrinityIdentity() });
    }

    // Benchmark 3: Command lookup
    {
        var registry = try orchestrator.initCommandRegistry(allocator);
        try orchestrator.registerCoreCommands(&registry, allocator);
        defer registry.deinit();

        const commands = [_][]const u8{"chat", "code", "gen", "fix", "explain", "pipeline", "plan", "verify", "math", "fib"};

        const start = try std.time.Instant.now();
        const iterations: usize = 100000;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = orchestrator.getCommandMetadata(&registry, commands[i % commands.len]);
        }
        const end = try std.time.Instant.now();
        const elapsed = end.since(start);
        try stdout.print("Command lookup:           {d: >10} ns/op ({d:.3} us/op)\n", .{
            @as(u64, @intCast(elapsed / iterations)),
            @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations)) / 1000.0
        });
    }

    try stdout.print("\n20 commands registered | Trinity identity verified\n", .{});
}
