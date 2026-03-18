const std = @import("std");
const AdaptiveCache = @import("adaptive_cache.zig").AdaptiveCache;

// ============================================================================
// UPDATED CODEX - THE VOICE (STREAMING & ADAPTIVE)
// ============================================================================

const InferenceMode = enum {
    STANDARD,
    TURBO,
};

pub const StreamingInference = struct {
    allocator: std.mem.Allocator,
    cache: *AdaptiveCache,
    buffer_size: usize,
    mode: InferenceMode,

    pub fn init(allocator: std.mem.Allocator, cache: *AdaptiveCache) StreamingInference {
        return StreamingInference{
            .allocator = allocator,
            .cache = cache,
            .buffer_size = 128, // Start small
            .mode = .STANDARD,
        };
    }

    /// Adapt buffer based on input length (Metabolic adjustment)
    pub fn adaptBuffer(self: *StreamingInference, input_len: usize) void {
        const old_size = self.buffer_size;

        if (input_len > 1000) {
            self.buffer_size = 1024;
        } else if (input_len > 100) {
            self.buffer_size = 512;
        } else {
            self.buffer_size = 128;
        }

        if (self.buffer_size != old_size) {
            std.debug.print("🌊 [Voice] Adusting Metobolism: Buffer {d} -> {d} bytes\n", .{ old_size, self.buffer_size });
        }
    }

    /// Simulate streaming inference with real-time mutation
    pub fn stream(self: *StreamingInference, input: []const u8) !void {
        self.adaptBuffer(input.len);

        std.debug.print("🎤 [Voice] Streaming (Mode: {s})...\n", .{@tagName(self.mode)});

        var i: usize = 0;
        var hit_rate_sim: f32 = 1.0;

        // Simulate output generation
        while (i < 10) : (i += 1) {
            // Fake delay - using std.Thread.sleep
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Decaying hit rate simulation
            hit_rate_sim -= 0.05;

            std.debug.print("{s} ", .{"word"});

            // Real-time Mutation Check
            if (hit_rate_sim < 0.70 and self.mode == .STANDARD) {
                try self.mutate();
                hit_rate_sim = 0.95; // Recovered
            }
        }
        std.debug.print("\n", .{});
    }

    fn mutate(self: *StreamingInference) !void {
        std.debug.print("\n⚠️ [Voice] Critical Hit Rate Drop! Triggering Mutation...\n", .{});
        std.debug.print("🦋 [Voice] Evolving to TURBO Mode (Simulated AVX2 Switch)\n", .{});
        self.mode = .TURBO;
        // In real code: this would swap backend function pointers or load different .tri weights

        // Also evolve the cache while we are at it
        try self.cache.evolveCache();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cache_mod = @import("adaptive_cache.zig");
    var cache = try cache_mod.AdaptiveCache.init(allocator, 10);
    defer cache.deinit();

    var inference = StreamingInference.init(allocator, &cache);

    // Test Run
    std.debug.print("--- THE SECOND LIFE: LIVING INFERENCE ---\n", .{});

    // 1. Short input
    try inference.stream("Hello world");

    // 2. Long input (Triggers buffer resize)
    const long_input = try allocator.alloc(u8, 2000);
    defer allocator.free(long_input);
    @memset(long_input, 'a');

    try inference.stream(long_input); // This run will simulate the hit rate drop and mutation
}
