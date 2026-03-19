//! LOCUS COERULEUS — v0.1 — Arousal Regulation
//!
//! Exponential backoff policy for agent retry logic.
//! Brain Region: Locus Coeruleus (Norepinephrine System)

const std = @import("std");

pub const BackoffPolicy = struct {
    initial_ms: u64 = 1000,
    max_ms: u64 = 60000,
    multiplier: f32 = 2.0,
    linear_increment: u64 = 1000,
    strategy: enum { exponential, linear, constant } = .exponential,
    jitter_type: enum { none, uniform, phi_weighted } = .none,

    pub fn init() BackoffPolicy {
        return BackoffPolicy{};
    }

    pub fn nextDelay(self: *const BackoffPolicy, attempt: u32) u64 {
        const base_delay: u64 = switch (self.strategy) {
            .exponential => {
                const delay = @as(f64, @floatFromInt(self.initial_ms)) *
                    std.math.pow(f32, self.multiplier, @as(f32, @floatFromInt(attempt)));
                if (delay > @as(f64, @floatFromInt(std.math.maxInt(u64))))
                    return std.math.maxInt(u64);
                return @as(u64, @intFromFloat(delay));
            },
            .linear => @min(self.max_ms, self.initial_ms + self.linear_increment * attempt),
            .constant => self.initial_ms,
        };

        // Apply jitter
        return switch (self.jitter_type) {
            .none => base_delay,
            .uniform => {
                const seed = @as(u32, @truncate(std.time.nanoTimestamp()));
                const factor = @as(f32, @floatFromInt(seed % 1000)) / 1000.0;
                @as(u64, @intFromFloat(base_delay * (1.0 + factor)));
            },
            .phi_weighted => {
                const seed = @as(u32, @truncate(std.time.nanoTimestamp()));
                const factor = if (seed % 2 == 0) 0.618 else 1.618;
                @as(u64, @intFromFloat(base_delay * factor));
            },
        };
    }
};
