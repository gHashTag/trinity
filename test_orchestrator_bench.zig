const std = @import("std");

test "Orchestrator v2.0 Benchmark" {
    const allocator = std.testing.allocator;
    const orchestrator = @import("src/tri/orchestrator_v2_working.zig");

    std.debug.print("\n═══ ORCHESTRATOR v2.0 BENCHMARK ═══\n", .{});

    // Benchmark: Create and destroy registry 1000 times
    {
        const start = try std.time.Instant.now();
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            var registry = try orchestrator.initCommandRegistry(allocator);
            try orchestrator.registerCoreCommands(&registry, allocator);
            registry.deinit();
        }
        const end = try std.time.Instant.now();
        const elapsed_ns = end.since(start);
        const avg_ns = elapsed_ns / 1000;
        std.debug.print("Registry init+register: {d: >8} ns/op\n", .{avg_ns});
    }

    // Benchmark: Sacred score calculation 10000 times
    {
        var registry = try orchestrator.initCommandRegistry(allocator);
        try orchestrator.registerCoreCommands(&registry, allocator);
        defer registry.deinit();

        const start = try std.time.Instant.now();
        var i: usize = 0;
        var score: f64 = 0;
        while (i < 10000) : (i += 1) {
            score = orchestrator.calculateRegistrySacredScore(&registry);
        }
        const end = try std.time.Instant.now();
        const elapsed_ns = end.since(start);
        const avg_ns = elapsed_ns / 10000;
        std.debug.print("Sacred score calc:      {d: >8} ns/op → {d:.3}\n", .{avg_ns, score});
    }

    // Benchmark: Command lookup 10000 times
    {
        var registry = try orchestrator.initCommandRegistry(allocator);
        try orchestrator.registerCoreCommands(&registry, allocator);
        defer registry.deinit();

        const commands = [_][]const u8{"chat", "code", "gen", "fix", "explain", "pipeline", "plan", "verify", "math", "fib"};

        const start = try std.time.Instant.now();
        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            _ = orchestrator.getCommandMetadata(&registry, commands[i % commands.len]);
        }
        const end = try std.time.Instant.now();
        const elapsed_ns = end.since(start);
        const avg_ns = elapsed_ns / 10000;
        std.debug.print("Command lookup:        {d: >8} ns/op\n", .{avg_ns});
    }

    std.debug.print("20 commands | Trinity identity: {}\n", .{orchestrator.verifyTrinityIdentity()});
}
