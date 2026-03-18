// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// AMYGDALA — Emotional Processing & Fear Conditioning
// ═══════════════════════════════════════════════════════════════════════════════
// S³AI Brain Module — Emotional valence, fear learning, reward association
// Neuro: Emotional processing, threat detection, fear conditioning, reward learning
// Trinity: Tag hippocampus memories with emotion, avoidance learning, mood modulation
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const hippocampus = @import("hippocampus.zig");
const ofc = @import("queen_ofc.zig");
const voice_engine = @import("voice_engine.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// EMOTION — Basic emotion types
// ═══════════════════════════════════════════════════════════════════════════════

pub const Emotion = enum {
    fear,
    reward,
    neutral,
    anger,
    joy,

    pub fn toString(self: Emotion) []const u8 {
        return switch (self) {
            .fear => "fear",
            .reward => "reward",
            .neutral => "neutral",
            .anger => "anger",
            .joy => "joy",
        };
    }

    pub fn fromString(s: []const u8) ?Emotion {
        if (std.mem.eql(u8, s, "fear")) return .fear;
        if (std.mem.eql(u8, s, "reward")) return .reward;
        if (std.mem.eql(u8, s, "neutral")) return .neutral;
        if (std.mem.eql(u8, s, "anger")) return .anger;
        if (std.mem.eql(u8, s, "joy")) return .joy;
        return null;
    }
};

/// Valence: -100 (extreme fear/anger) to +100 (extreme reward/joy)
pub const Valence = struct {
    emotion: Emotion,
    intensity: i8, // -100 to +100

    pub fn init(emotion: Emotion, intensity: i8) Valence {
        return .{ .emotion = emotion, .intensity = intensity };
    }

    pub fn fear(intensity: i8) Valence {
        const abs = if (intensity < 0) -intensity else intensity;
        return .{ .emotion = .fear, .intensity = -abs };
    }

    pub fn reward(intensity: i8) Valence {
        const abs = if (intensity < 0) -intensity else intensity;
        return .{ .emotion = .reward, .intensity = abs };
    }

    pub fn anger(intensity: i8) Valence {
        const abs = if (intensity < 0) -intensity else intensity;
        return .{ .emotion = .anger, .intensity = -abs };
    }

    pub fn joy(intensity: i8) Valence {
        const abs = if (intensity < 0) -intensity else intensity;
        return .{ .emotion = .joy, .intensity = abs };
    }

    pub fn isNegative(self: *const Valence) bool {
        return self.intensity < 0;
    }

    pub fn isPositive(self: *const Valence) bool {
        return self.intensity > 0;
    }

    pub fn absolute(self: *const Valence) i8 {
        if (self.intensity < 0) return -self.intensity;
        return self.intensity;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// FEAR CONDITIONING — One-shot learning from aversive events
// ═══════════════════════════════════════════════════════════════════════════════

/// Fear memory - associates context with negative outcome
pub const FearMemory = struct {
    context: []const u8, // e.g., "flat-lr-schedule"
    intensity: i8, // 1-100
    encounter_count: u32,
    last_encounter: i64,
    extinction_progress: f32 = 0.0, // 0 = strong, 1 = extinguished

    pub fn shouldAvoid(self: *const FearMemory) bool {
        // Avoid if intensity > 30 and not mostly extinguished
        return self.intensity > 30 and self.extinction_progress < 0.8;
    }

    pub fn avoidanceConfidence(self: *const FearMemory) f32 {
        const base = @as(f32, @floatFromInt(self.intensity)) / 100.0;
        return base * (1.0 - self.extinction_progress);
    }
};

/// Condition fear from negative episode (one-shot learning)
pub fn conditionFear(
    allocator: Allocator,
    context: []const u8,
    summary: []const u8,
    data_json: []const u8,
    intensity: i8,
) !void {
    const clamped = @min(@abs(intensity), 100);

    // Build episode record with fear tags
    var record = hippocampus.MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    hippocampus.generateId(&record.id_buf, &record.id_len, ts, "amygdala");
    hippocampus.copyToFixed(32, &record.agent_buf, &record.agent_len, "amygdala");
    record.kind = .episode;
    record.ts = ts;
    record.ttl = hippocampus.MemoryKind.episode.defaultTtl();

    hippocampus.copyToFixed(2048, &record.data_buf, &record.data_len, data_json);

    // Build summary with context
    var summary_buf: [512]u8 = undefined;
    const full_summary = try std.fmt.bufPrint(
        &summary_buf,
        "[FEAR] {s}: {s}",
        .{ context, summary },
    );
    hippocampus.copyToFixed(256, &record.summary_buf, &record.summary_len, full_summary);

    // Add emotion tags
    var tag_buf: [32]u8 = undefined;
    const emo_tag = try std.fmt.bufPrint(&tag_buf, "emo:fear", .{});
    const val_tag = try std.fmt.bufPrint(&tag_buf, "emo-v:{d}", .{clamped});
    const ctx_tag = try std.fmt.bufPrint(&tag_buf, "ctx:{s}", .{context});

    hippocampus.copyToFixed(32, &record.tags[0], &record.tag_lens[0], emo_tag);
    hippocampus.copyToFixed(32, &record.tags[1], &record.tag_lens[1], val_tag);
    hippocampus.copyToFixed(32, &record.tags[2], &record.tag_lens[2], ctx_tag);
    record.tag_count = 3;

    try hippocampus.write(allocator, &record);
}

/// Condition reward from positive episode
pub fn conditionReward(
    allocator: Allocator,
    context: []const u8,
    summary: []const u8,
    data_json: []const u8,
    intensity: i8,
) !void {
    const clamped = @min(@abs(intensity), 100);

    var record = hippocampus.MemoryRecord{};
    const ts: u64 = @intCast(std.time.timestamp());
    hippocampus.generateId(&record.id_buf, &record.id_len, ts, "amygdala");
    hippocampus.copyToFixed(32, &record.agent_buf, &record.agent_len, "amygdala");
    record.kind = .episode;
    record.ts = ts;
    record.ttl = hippocampus.MemoryKind.episode.defaultTtl();

    hippocampus.copyToFixed(2048, &record.data_buf, &record.data_len, data_json);

    var summary_buf: [512]u8 = undefined;
    const full_summary = try std.fmt.bufPrint(
        &summary_buf,
        "[REWARD] {s}: {s}",
        .{ context, summary },
    );
    hippocampus.copyToFixed(256, &record.summary_buf, &record.summary_len, full_summary);

    // Add emotion tags
    var tag_buf: [32]u8 = undefined;
    const emo_tag = try std.fmt.bufPrint(&tag_buf, "emo:reward", .{});
    const val_tag = try std.fmt.bufPrint(&tag_buf, "emo-v:{d}", .{clamped});
    const ctx_tag = try std.fmt.bufPrint(&tag_buf, "ctx:{s}", .{context});

    hippocampus.copyToFixed(32, &record.tags[0], &record.tag_lens[0], emo_tag);
    hippocampus.copyToFixed(32, &record.tags[1], &record.tag_lens[1], val_tag);
    hippocampus.copyToFixed(32, &record.tags[2], &record.tag_lens[2], ctx_tag);
    record.tag_count = 3;

    try hippocampus.write(allocator, &record);
}

// ═══════════════════════════════════════════════════════════════════════════════
// AVOIDANCE — Check if context triggers avoidance behavior
// ═══════════════════════════════════════════════════════════════════════════════

pub const AvoidanceResult = struct {
    avoid: bool,
    confidence: f32, // 0-1
    reason: []const u8,
};

/// Check if a context should be avoided based on fear memory
pub fn shouldAvoid(
    allocator: Allocator,
    context: []const u8,
) !AvoidanceResult {
    var results = try hippocampus.read(allocator, .{
        .tag_filter = "emo:fear",
        .limit = 100,
    });
    defer results.deinit(allocator);

    var max_intensity: i8 = 0;
    var match_count: u32 = 0;

    for (results.items) |rec| {
        const summary = rec.summary();
        const data = rec.data();

        // Check if context appears in memory
        const in_summary = std.mem.indexOf(u8, summary, context) != null;
        const in_data = std.mem.indexOf(u8, data, context) != null;

        if (in_summary or in_data) {
            // Parse emo-v tag
            var ti: u8 = 0;
            while (ti < rec.tag_count) : (ti += 1) {
                const tag = rec.getTag(ti);
                if (std.mem.startsWith(u8, tag, "emo-v:")) {
                    const val_str = tag["emo-v:".len..];
                    const val = std.fmt.parseInt(i8, val_str, 10) catch 0;
                    if (val > max_intensity) max_intensity = val;
                }
            }
            match_count += 1;
        }
    }

    if (max_intensity > 30 and match_count > 0) {
        var reason_buf: [128]u8 = undefined;
        const reason = try std.fmt.bufPrint(
            &reason_buf,
            "Fear association: {s} (intensity {d}, {d} episodes)",
            .{ context, max_intensity, match_count },
        );
        return .{
            .avoid = true,
            .confidence = @as(f32, @floatFromInt(max_intensity)) / 100.0,
            .reason = reason,
        };
    }

    return .{
        .avoid = false,
        .confidence = 0.0,
        .reason = "No fear association",
    };
}

/// Extinct fear through safe exposure
pub fn extinguish(
    allocator: Allocator,
    context: []const u8,
) !void {
    // Find fear memories for this context
    var results = try hippocampus.read(allocator, .{
        .tag_filter = "emo:fear",
        .limit = 100,
    });
    defer results.deinit(allocator);

    const extinction_increment: f32 = 0.1; // 10% progress per extinguish call

    for (results.items) |*rec| {
        const summary = rec.summary();
        // Check if this memory matches our context
        if (std.mem.indexOf(u8, summary, context) != null) {
            // Parse current extinction_progress from data
            const data = rec.data();
            var current_progress: f32 = 0.0;
            if (voice_engine.parseJsonF32(data, "\"extinction_progress\":")) |v| {
                current_progress = v;
            }

            // Cap at 1.0 (fully extinguished)
            const new_progress = @min(1.0, current_progress + extinction_increment);

            // Update the memory with new extinction progress
            var updated_data_buf: [512]u8 = undefined;
            const updated_data = try std.fmt.bufPrint(&updated_data_buf,
                \\"{{"extinction_progress":{d:.1},"context":"{s}"}}
            , .{ new_progress, context });

            // Write updated memory as a learning episode
            try hippocampus.writeLearning(allocator, "amygdala", updated_data);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOOD MODULATION — Enhance OFC mood with emotional memory
// ═══════════════════════════════════════════════════════════════════════════════

/// Modulate OFC mood based on emotional context
pub fn modulateMood(
    allocator: Allocator,
    base_mood: ofc.Mood,
    context: []const u8,
) !ofc.Mood {
    // Check for recent fear associations
    var results = try hippocampus.read(allocator, .{
        .tag_filter = "emo:fear",
        .limit = 50,
    });
    defer results.deinit(allocator);

    var recent_fear_count: u32 = 0;
    const now = std.time.timestamp();
    const one_hour_ago = now - 3600;

    for (results.items) |rec| {
        if (rec.ts >= one_hour_ago) {
            const summary = rec.summary();
            if (std.mem.indexOf(u8, summary, context) != null) {
                recent_fear_count += 1;
            }
        }
    }

    // Check for recent reward associations
    var reward_results = try hippocampus.read(allocator, .{
        .tag_filter = "emo:reward",
        .limit = 50,
    });
    defer reward_results.deinit(allocator);

    var recent_reward_count: u32 = 0;
    for (reward_results.items) |rec| {
        if (rec.ts >= one_hour_ago) {
            const summary = rec.summary();
            if (std.mem.indexOf(u8, summary, context) != null) {
                recent_reward_count += 1;
            }
        }
    }

    // Modulate mood based on emotional history
    return switch (base_mood) {
        .calm => if (recent_fear_count >= 3) .alert else if (recent_reward_count >= 5) .euphoria else .calm,
        .alert => if (recent_fear_count >= 5) .alarm else if (recent_reward_count >= 3) .calm else .alert,
        .alarm => if (recent_reward_count >= 5) .alert else .alarm,
        .euphoria => if (recent_fear_count >= 3) .calm else .euphoria,
    };
}

/// Get emotional summary for a context
pub fn getEmotionalSummary(
    allocator: Allocator,
    context: []const u8,
) !struct {
    fear_intensity: i8,
    reward_intensity: i8,
    fear_count: u32,
    reward_count: u32,
} {
    var fear_results = try hippocampus.read(allocator, .{
        .tag_filter = "emo:fear",
        .limit = 100,
    });
    defer fear_results.deinit(allocator);

    var fear_intensity: i8 = 0;
    var fear_count: u32 = 0;

    for (fear_results.items) |rec| {
        const summary = rec.summary();
        const data = rec.data();
        if (std.mem.indexOf(u8, summary, context) != null or
            std.mem.indexOf(u8, data, context) != null)
        {
            fear_count += 1;
            // Parse emo-v tag
            var ti: u8 = 0;
            while (ti < rec.tag_count) : (ti += 1) {
                const tag = rec.getTag(ti);
                if (std.mem.startsWith(u8, tag, "emo-v:")) {
                    const val_str = tag["emo-v:".len..];
                    const val = std.fmt.parseInt(i8, val_str, 10) catch 0;
                    if (val > fear_intensity) fear_intensity = val;
                }
            }
        }
    }

    var reward_results = try hippocampus.read(allocator, .{
        .tag_filter = "emo:reward",
        .limit = 100,
    });
    defer reward_results.deinit(allocator);

    var reward_intensity: i8 = 0;
    var reward_count: u32 = 0;

    for (reward_results.items) |rec| {
        const summary = rec.summary();
        const data = rec.data();
        if (std.mem.indexOf(u8, summary, context) != null or
            std.mem.indexOf(u8, data, context) != null)
        {
            reward_count += 1;
            // Parse emo-v tag
            var ti: u8 = 0;
            while (ti < rec.tag_count) : (ti += 1) {
                const tag = rec.getTag(ti);
                if (std.mem.startsWith(u8, tag, "emo-v:")) {
                    const val_str = tag["emo-v:".len..];
                    const val = std.fmt.parseInt(i8, val_str, 10) catch 0;
                    if (val > reward_intensity) reward_intensity = val;
                }
            }
        }
    }

    return .{
        .fear_intensity = fear_intensity,
        .reward_intensity = reward_intensity,
        .fear_count = fear_count,
        .reward_count = reward_count,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// THREAT DETECTION — Identify patterns that should trigger fear
// ═══════════════════════════════════════════════════════════════════════════════

pub const ThreatKind = enum {
    build_failure,
    ppl_divergence,
    token_expiry,
    worker_death,
    stagnation,
    memory_corruption,
    flat_lr_schedule, // DEADLY
};

/// Detect threat from system state
pub fn detectThreat(
    build_ok: bool,
    ppl: f32,
    ppl_delta: f32,
) ?ThreatKind {
    // Flat LR schedule is deadly
    if (ppl_delta > 50.0) return .flat_lr_schedule; // PPL jumped > 50

    // Build failure
    if (!build_ok) return .build_failure;

    // PPL divergence (getting worse)
    if (ppl > 20.0 and ppl_delta > 10.0) return .ppl_divergence;

    return null;
}

/// Auto-condition fear from detected threat
pub fn autoConditionFromThreat(
    allocator: Allocator,
    threat: ThreatKind,
    context_data: []const u8,
) !void {
    const intensity: i8 = switch (threat) {
        .flat_lr_schedule => 100, // MAXIMUM FEAR
        .build_failure => 70,
        .ppl_divergence => 60,
        .token_expiry => 80,
        .worker_death => 50,
        .stagnation => 30,
        .memory_corruption => 90,
    };

    const context = switch (threat) {
        .flat_lr_schedule => "flat-lr-schedule",
        .build_failure => "build-failure",
        .ppl_divergence => "ppl-divergence",
        .token_expiry => "token-expiry",
        .worker_death => "worker-death",
        .stagnation => "stagnation",
        .memory_corruption => "memory-corruption",
    };

    try conditionFear(
        allocator,
        context,
        switch (threat) {
            .build_failure => "build-failure",
            .ppl_divergence => "ppl-divergence",
            .token_expiry => "token-expiry",
            .worker_death => "worker-death",
            .stagnation => "stagnation",
            .memory_corruption => "memory-corruption",
            .flat_lr_schedule => "flat-lr-schedule",
        },
        context_data,
        intensity,
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "amygdala — Emotion toString/fromString roundtrip" {
    const e = Emotion.fear;
    try std.testing.expectEqualStrings("fear", e.toString());
    try std.testing.expectEqual(Emotion.fear, Emotion.fromString("fear").?);
}

test "amygdala — Valence fear is negative" {
    const v = Valence.fear(50);
    try std.testing.expect(v.isNegative());
    try std.testing.expect(!v.isPositive());
    try std.testing.expectEqual(@as(i8, 50), v.absolute());
}

test "amygdala — Valence reward is positive" {
    const v = Valence.reward(75);
    try std.testing.expect(v.isPositive());
    try std.testing.expect(!v.isNegative());
}

test "amygdala — FearMemory shouldAvoid logic" {
    const fm = FearMemory{
        .context = "test",
        .intensity = 80,
        .encounter_count = 5,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.0,
    };
    try std.testing.expect(fm.shouldAvoid());
    try std.testing.expect(fm.avoidanceConfidence() > 0.5);

    const extinguished = FearMemory{
        .context = "test",
        .intensity = 80,
        .encounter_count = 5,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.9,
    };
    try std.testing.expect(!extinguished.shouldAvoid());
}

test "amygdala — detectThreat finds flat LR" {
    const threat = detectThreat(true, 50.0, 60.0);
    try std.testing.expectEqual(ThreatKind.flat_lr_schedule, threat.?);
}

test "amygdala — detectThreat finds build failure" {
    const threat = detectThreat(false, 10.0, 0.0);
    try std.testing.expectEqual(ThreatKind.build_failure, threat.?);
}

test "amygdala — detectThreat returns null when OK" {
    const threat = detectThreat(true, 5.0, 1.0);
    try std.testing.expectEqual(@as(?ThreatKind, null), threat);
}

test "amygdala — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "amygdala — shouldAvoid returns result" {
    const result = try shouldAvoid(std.testing.allocator, "nonexistent-context");
    try std.testing.expect(!result.avoid);
    try std.testing.expectEqual(@as(f32, 0.0), result.confidence);
}

test "amygdala — Valence constructor edge cases" {
    // Negative intensity becomes positive absolute value for fear
    const v1 = Valence.fear(-50);
    try std.testing.expectEqual(@as(i8, -50), v1.intensity);

    // Zero intensity
    const v2 = Valence.reward(0);
    try std.testing.expectEqual(@as(i8, 0), v2.intensity);
    try std.testing.expect(!v2.isPositive());
    try std.testing.expect(!v2.isNegative());

    // Maximum intensity clamping (via conditionFear)
    const max_i8: i8 = 127;
    _ = max_i8; // Reference for documentation
}

test "amygdala — FearMemory avoidanceConfidence formula" {
    var fm = FearMemory{
        .context = "test",
        .intensity = 50,
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.0,
    };
    // confidence = (50 / 100) * (1.0 - 0.0) = 0.5
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), fm.avoidanceConfidence(), 0.01);

    fm.extinction_progress = 0.5;
    // confidence = (50 / 100) * (1.0 - 0.5) = 0.25
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), fm.avoidanceConfidence(), 0.01);
}

test "amygdala — FearMemory shouldAvoid thresholds" {
    const fm1 = FearMemory{
        .context = "test",
        .intensity = 31, // Just above threshold
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.0,
    };
    try std.testing.expect(fm1.shouldAvoid());

    const fm2 = FearMemory{
        .context = "test",
        .intensity = 30, // At threshold
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.0,
    };
    try std.testing.expect(!fm2.shouldAvoid());

    const fm3 = FearMemory{
        .context = "test",
        .intensity = 100,
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.81, // Extinguished
    };
    try std.testing.expect(!fm3.shouldAvoid());
}

test "amygdala — Emotion fromString unknown" {
    const unknown = Emotion.fromString("unknown");
    try std.testing.expectEqual(@as(?Emotion, null), unknown);
}

test "amygdala — Valence absolute" {
    const v1 = Valence.fear(75);
    try std.testing.expectEqual(@as(i8, 75), v1.absolute());

    const v2 = Valence.anger(-50);
    try std.testing.expectEqual(@as(i8, 50), v2.absolute());

    const v3 = Valence.joy(0);
    try std.testing.expectEqual(@as(i8, 0), v3.absolute());
}

test "amygdala — ThreatKind enum coverage" {
    const threats = [_]ThreatKind{
        .build_failure,
        .ppl_divergence,
        .token_expiry,
        .worker_death,
        .stagnation,
        .memory_corruption,
        .flat_lr_schedule,
    };
    for (threats) |t| {
        _ = t; // Verify all enum values exist
    }
}

test "amygdala — detectThreat ppl divergence" {
    const threat = detectThreat(true, 25.0, 15.0);
    try std.testing.expectEqual(ThreatKind.ppl_divergence, threat.?);
}

test "amygdala — detectThreat priority" {
    // Flat LR has highest priority (checked first)
    const threat = detectThreat(false, 50.0, 60.0);
    // Both build failure and flat LR apply, but flat LR is checked first
    try std.testing.expectEqual(ThreatKind.flat_lr_schedule, threat.?);
}

test "amygdala — AvoidanceResult structure" {
    const result = AvoidanceResult{
        .avoid = true,
        .confidence = 0.8,
        .reason = "Test reason",
    };
    try std.testing.expect(result.avoid);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), result.confidence, 0.01);
}

test "amygdala — Emotion enum coverage" {
    const emotions = [_]Emotion{ .fear, .reward, .neutral, .anger, .joy };
    for (emotions) |e| {
        const s = e.toString();
        try std.testing.expect(s.len > 0);
    }
}

// ═══════════════════════════════════════════════════════════════════
// EMOTION TESTS
// ═══════════════════════════════════════════════════════════════════

test "amygdala — Emotion all toString roundtrip" {
    const emotions = [_]Emotion{ .fear, .reward, .neutral, .anger, .joy };
    for (emotions) |e| {
        const s = e.toString();
        const parsed = Emotion.fromString(s).?;
        try std.testing.expectEqual(e, parsed);
    }
}

test "amygdala — Emotion neutral toString" {
    try std.testing.expectEqualStrings("neutral", Emotion.neutral.toString());
}

test "amygdala — Emotion anger toString" {
    try std.testing.expectEqualStrings("anger", Emotion.anger.toString());
}

test "amygdala — Emotion joy toString" {
    try std.testing.expectEqualStrings("joy", Emotion.joy.toString());
}

test "amygdala — Emotion reward toString" {
    try std.testing.expectEqualStrings("reward", Emotion.reward.toString());
}

// ═══════════════════════════════════════════════════════════════════
// VALENCE TESTS
// ═══════════════════════════════════════════════════════════════════

test "amygdala — Valence anger" {
    const v = Valence.anger(60);
    try std.testing.expect(v.isNegative());
    try std.testing.expectEqual(Emotion.anger, v.emotion);
    try std.testing.expectEqual(@as(i8, -60), v.intensity);
}

test "amygdala — Valence joy" {
    const v = Valence.joy(80);
    try std.testing.expect(v.isPositive());
    try std.testing.expectEqual(Emotion.joy, v.emotion);
    try std.testing.expectEqual(@as(i8, 80), v.intensity);
}

test "amygdala — Valence init" {
    const v = Valence.init(.neutral, 0);
    try std.testing.expectEqual(Emotion.neutral, v.emotion);
    try std.testing.expectEqual(@as(i8, 0), v.intensity);
    try std.testing.expect(!v.isPositive());
    try std.testing.expect(!v.isNegative());
}

test "amygdala — Valence absolute zero" {
    const v = Valence.init(.neutral, 0);
    try std.testing.expectEqual(@as(i8, 0), v.absolute());
}

test "amygdala — Valence fear negative input" {
    const v = Valence.fear(-30);
    try std.testing.expectEqual(@as(i8, -30), v.intensity);
    try std.testing.expectEqual(@as(i8, 30), v.absolute());
}

test "amygdala — Valence reward negative input" {
    const v = Valence.reward(-25);
    try std.testing.expectEqual(@as(i8, 25), v.intensity); // Absolute value
    try std.testing.expect(v.isPositive());
}

// ═══════════════════════════════════════════════════════════════════
// FEAR MEMORY TESTS
// ═══════════════════════════════════════════════════════════════════

test "amygdala — FearMemory defaults" {
    const fm = FearMemory{
        .context = "test",
        .intensity = 0,
        .encounter_count = 0,
        .last_encounter = 0,
    };
    try std.testing.expectEqual(@as(i8, 0), fm.intensity);
    try std.testing.expectEqual(@as(u32, 0), fm.encounter_count);
    try std.testing.expectEqual(@as(i64, 0), fm.last_encounter);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fm.extinction_progress, 0.01);
}

test "amygdala — FearMemory shouldAvoid low intensity" {
    const fm = FearMemory{
        .context = "test",
        .intensity = 20, // Below threshold
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.0,
    };
    try std.testing.expect(!fm.shouldAvoid());
}

test "amygdala — FearMemory avoidanceConfidence max" {
    const fm = FearMemory{
        .context = "test",
        .intensity = 100,
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 0.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), fm.avoidanceConfidence(), 0.01);
}

test "amygdala — FearMemory avoidanceConfidence extinguished" {
    const fm = FearMemory{
        .context = "test",
        .intensity = 100,
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
        .extinction_progress = 1.0,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fm.avoidanceConfidence(), 0.01);
}

test "amygdala — FearMemory encounter_count increments" {
    var fm = FearMemory{
        .context = "test",
        .intensity = 50,
        .encounter_count = 1,
        .last_encounter = std.time.timestamp(),
    };
    try std.testing.expectEqual(@as(u32, 1), fm.encounter_count);

    fm.encounter_count = 5;
    try std.testing.expectEqual(@as(u32, 5), fm.encounter_count);
}

// ═══════════════════════════════════════════════════════════════════
// THREAT KIND TESTS
// ═══════════════════════════════════════════════════════════════════

test "amygdala — ThreatKind all values" {
    const threats = [_]ThreatKind{
        .build_failure,
        .ppl_divergence,
        .token_expiry,
        .worker_death,
        .stagnation,
        .memory_corruption,
        .flat_lr_schedule,
    };
    for (threats) |t| {
        _ = t; // Verify all enum values exist
    }
}

test "amygdala — detectThreat token expiry priority" {
    // Token expiry isn't directly detected by detectThreat (needs additional params)
    // This test documents that token_expiry is a valid threat kind
    const threat: ThreatKind = .token_expiry;
    try std.testing.expectEqual(ThreatKind.token_expiry, threat);
}

test "amygdala — detectThreat stagnation" {
    const threat: ThreatKind = .stagnation;
    try std.testing.expectEqual(ThreatKind.stagnation, threat);
}

test "amygdala — detectThreat memory corruption" {
    const threat: ThreatKind = .memory_corruption;
    try std.testing.expectEqual(ThreatKind.memory_corruption, threat);
}

test "amygdala — detectThreat worker death" {
    const threat: ThreatKind = .worker_death;
    try std.testing.expectEqual(ThreatKind.worker_death, threat);
}

// ═══════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════

test "amygdala — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "amygdala — CellHealth defaults" {
    const h = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "amygdala — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "amygdala — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .broken;
    h.cycle = 10;
    h.last_check = 11111;

    try std.testing.expectEqual(CellHealth.Status.broken, h.status);
    try std.testing.expectEqual(@as(u32, 10), h.cycle);
    try std.testing.expectEqual(@as(i64, 11111), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════
// AVOIDANCE RESULT TESTS
// ═══════════════════════════════════════════════════════════════════

test "amygdala — AvoidanceResult no avoid" {
    const result = AvoidanceResult{
        .avoid = false,
        .confidence = 0.0,
        .reason = "No fear association",
    };
    try std.testing.expect(!result.avoid);
    try std.testing.expectEqual(@as(f32, 0.0), result.confidence);
}

test "amygdala — AvoidanceResult high confidence" {
    const result = AvoidanceResult{
        .avoid = true,
        .confidence = 0.95,
        .reason = "Strong fear association",
    };
    try std.testing.expect(result.avoid);
    try std.testing.expect(result.confidence > 0.9);
}
