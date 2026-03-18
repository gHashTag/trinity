const std = @import("std");
const AdaptiveCache = @import("adaptive_cache.zig").AdaptiveCache;
const StreamingInference = @import("updated_codex.zig").StreamingInference;

test "AdaptiveCache - mutation on load" {
    const allocator = std.testing.allocator;
    var cache = try AdaptiveCache.init(allocator, 2);
    defer cache.deinit();

    // Initial state
    try std.testing.expect(cache.current_type == .LRU);

    // Force high CPU load
    cache.simulated_cpu_load = 0.9;
    try cache.evolveCache();

    // Should mutate to RANDOM for high load
    try std.testing.expect(cache.current_type == .RANDOM);

    // Force low CPU load
    cache.simulated_cpu_load = 0.1;
    try cache.evolveCache();

    // Should mutate to LFU for low load
    try std.testing.expect(cache.current_type == .LFU);
}

test "StreamingInference - metabolism adaptation" {
    const allocator = std.testing.allocator;
    var cache = try AdaptiveCache.init(allocator, 5);
    defer cache.deinit();

    var inference = StreamingInference.init(allocator, &cache);

    // Initial buffer
    try std.testing.expect(inference.buffer_size == 128);

    // Short input
    inference.adaptBuffer(50);
    try std.testing.expect(inference.buffer_size == 128);

    // Long input
    inference.adaptBuffer(1500);
    try std.testing.expect(inference.buffer_size == 1024);

    // Medium input
    inference.adaptBuffer(500);
    try std.testing.expect(inference.buffer_size == 512);
}

test "AdaptiveCache - eviction logic" {
    const allocator = std.testing.allocator;
    var cache = try AdaptiveCache.init(allocator, 2);
    defer cache.deinit();

    try cache.put("a", "1");
    try cache.put("b", "2");

    // Access "a" once more
    _ = cache.get("a");

    // Strategy is LRU by default. Evict "b" when putting "c".
    try cache.put("c", "3");

    try std.testing.expect(cache.entries.contains("a"));
    try std.testing.expect(cache.entries.contains("c"));
    try std.testing.expect(!cache.entries.contains("b"));
}
