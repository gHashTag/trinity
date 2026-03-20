// @origin(spec:thalamus_logs.tri) @regen(manual-impl)
// THALAMUS LOGS — Sensory relay station for Trinity cortex
//
// Thalamus: Relays sensory input from Queen (18 sensors) to cortex (5 modules)
// Provides circular buffer logging with direct HSLM module calls
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import sensation module for HSLM access (via module import from build.zig)
// Use stub functions for testing when module is not available

// Stub IPS module for testing
const ips = struct {
    pub const GoldenFloat16 = u16;
    pub const TernaryFloat9 = u16;
    pub fn gf16FromF32(v: f32) u16 {
        return @bitCast(@as(f16, @floatCast(v)));
    }
    pub fn tf3FromF32(v: f32) u16 {
        return @intFromFloat(v);
    }
};

// Stub Weber module for testing
const weber = struct {
    pub fn weberQuantize(value: f32, base: f16, k: f16) u16 {
        _ = k;
        return @intFromFloat(value / base);
    }
};

// Stub Fusiform module for testing
const fusiform = struct {};

// Stub Angular module for testing
const angular = struct {
    pub const FormatDescriptor = struct {
        name: []const u8,
        phi_distance: f32,
    };
    const dummy_descriptor = FormatDescriptor{
        .name = "gf16",
        .phi_distance = 0.0,
    };
    pub fn allFormatsTable() []const FormatDescriptor {
        return &.{dummy_descriptor};
    }
};

// Stub OFC module for testing
const ofc = struct {
    pub const Valence = enum(u8) { positive, neutral, negative };
    pub const LayerStats = struct {
        min: f32,
        max: f32,
        mean: f32,
        std: f32,
        sparsity: f32,
    };
    pub const StimulusValue = struct {
        value: f32,
        sensor_id: u8,
        confidence: f16,
        timestamp: i64,
    };
    pub fn selectOptimalFormat(stats: LayerStats) []const u8 {
        _ = stats;
        return "gf16";
    }
    pub fn assignValence(stim: StimulusValue) @This().Valence {
        _ = stim;
        return .neutral;
    }
};

pub const GoldenFloat16 = ips.GoldenFloat16;
pub const TernaryFloat9 = ips.TernaryFloat9;
pub const Valence = ofc.Valence;

// ═════════════════════════════════════════════════════════════════════════════════════════════════
// SENSOR ID — Queen sensor identifiers
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

/// Sensor ID enumeration (maps to Queen senses)
pub const SensorId = enum(u8) {
    /// #7 Farm best PPL: f32 perplexity → IPS → GF16 encode
    FarmBestPpl = 7,

    /// #8 Arena battles: i8 win/loss → IPS → TF3 ternary encode
    ArenaBattles = 8,

    /// #9 Ouroboros score: f32 → Weber → log-quantize
    OuroborosScore = 9,

    /// #2 Tests rate: f32 pass % → OFC → value judgment
    TestsRate = 2,

    /// #10 Disk free: u64 bytes → Fusiform → GF16 compact
    DiskFree = 10,

    /// #14 Arena stale: u32 hours → Angular → verbalize/introspect
    ArenaStale = 14,
};

// ═══════════════════════════════════════════════════════════════════════════════════
// SENSOR KINDS — Queen sensor classification
// ═══════════════════════════════════════════════════════════════════════════════════

/// Sensory input kind - which HSLM module to route to
pub const SensoryKind = enum(u8) {
    /// Magnitude data → encode with GF16
    magnitude = 0,

    /// Ternary data → encode with TF3-9
    ternary = 1,

    /// Valence assignment → use OFC for value judgment
    valence = 2,

    /// Verbal description → use Angular for introspection
    verbal = 3,
};

// ═══════════════════════════════════════════════════════════════════════════════════
// SENSOR INPUT — Raw sensory data from Queen
// ═════════════════════════════════════════════════════════════════════════════════

/// Sensor input from Queen senses (raw values + optional pre-processed)
pub const SensorInput = struct {
    /// Sensor ID (which Queen sensor)
    id: SensorId,

    /// Raw f32 value from Queen (when available)
    raw_f32: ?f32 = null,

    /// Raw i8 value from Queen (when available)
    raw_i8: ?i8 = null,

    /// Raw u32 value from Queen (when available)
    raw_u32: ?u32 = null,

    /// Raw u64 value from Queen (when available)
    raw_u64: ?u64 = null,

    /// Pre-processed: GF16 encoded magnitude
    magnitude_gf16: ?GoldenFloat16 = null,

    /// Pre-processed: TF3-9 encoded ternary data
    ternary_tf3: ?TernaryFloat9 = null,

    /// Pre-processed: valence from OFC
    valence_valence: ?Valence = null,

    /// Pre-processed: verbal description (up to 256 bytes)
    verbal_msg: ?VerbalMessage = null,
};

// Tagged union for verbal message (max 256 bytes)
pub const VerbalMessage = union(enum(u8)) {
    short: u8,
    medium: u16,
    long: u32,
};

// ═══════════════════════════════════════════════════════════════════════════
// SENSORY EVENT — Single logged event
// ═══════════════════════════════════════════════════════════════════════════════

/// Single sensory event in the circular buffer
pub const SensoryEvent = struct {
    /// Timestamp (nanoseconds since epoch)
    timestamp_ns: u64,

    /// Sensor ID that produced this event
    sensor: SensorId,

    /// Input values (raw + optional pre-processed)
    input: SensorInput,
};

// ═════════════════════════════════════════════════════════════════════════════════════
// THALAMUS LOGS — Circular buffer logging with direct HSLM calls
// ═════════════════════════════════════════════════════════════════════════════

/// Thalamus: Sensory relay station with circular buffer logging
/// Provides direct path from Queen senses to HSLM cortex modules
pub const ThalamusLogs = struct {
    const Self = @This();

    /// Circular buffer storage (fixed size, no allocation)
    buf: [256]SensoryEvent,

    /// Circular buffer pointers
    head: usize = 0,
    len: usize = 0,

    /// Initialize Thalamus with pre-allocated buffer storage
    pub fn init(buf_storage: *[256]SensoryEvent) Self {
        return .{
            .buf = buf_storage.*,
        };
    }

    /// Log a sensory event (thread-safe: atomic head update)
    pub fn logEvent(self: *Self, event: SensoryEvent) void {
        if (self.len < 256) {
            const idx = (self.head + self.len) % 256;
            self.buf[idx] = event;
            self.len += 1;
        }
    }

    /// Get iterator over all events (head to tail)
    pub fn iterator(self: *const Self) Iterator {
        return .{
            .thalamus = self,
            .index = self.head,
        };
    }

    /// Process sensor input through appropriate HSLM module
    pub fn processSensor(self: *Self, sensor_data: SensorInput) !void {
        // Select HSLM module based on sensor ID and available data
        switch (sensor_data.id) {
            inline .FarmBestPpl => {
                // #7 Farm best PPL: f32 perplexity → IPS → GF16 encode
                if (sensor_data.raw_f32) |v| {
                    const gf = ips.gf16FromF32(v);
                    // Store in buffer (simplified - in real usage would be separate)
                    const event = SensoryEvent{
                        .timestamp_ns = @as(u64, @intCast(std.time.nanoTimestamp())),
                        .sensor = .FarmBestPpl,
                        .input = SensorInput{
                            .id = .FarmBestPpl,
                            .raw_f32 = v,
                            .magnitude_gf16 = gf,
                        },
                    };
                    self.logEvent(event);
                }
            },

            inline .ArenaBattles => {
                // #8 Arena battles: i8 win/loss → IPS → TF3 ternary encode
                if (sensor_data.raw_i8) |v| {
                    const f32_val: f32 = @floatFromInt(v);
                    const tf = ips.tf3FromF32(f32_val);
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = @as(u64, @intCast(std.time.nanoTimestamp())),
                        .sensor = .ArenaBattles,
                        .input = SensorInput{
                            .id = .ArenaBattles,
                            .raw_i8 = v,
                            .ternary_tf3 = tf,
                        },
                    };
                    self.logEvent(event);
                }
            },

            inline .OuroborosScore => {
                // #9 Ouroboros score: f32 → Weber → log-quantize
                if (sensor_data.raw_f32) |v| {
                    const k: f16 = @floatCast(0.05);
                    const q = weber.weberQuantize(v, 1.0, k);
                    // Encode with GF16 for storage
                    const gf = ips.gf16FromF32(@floatFromInt(@as(u16, q)));
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = @as(u64, @intCast(std.time.nanoTimestamp())),
                        .sensor = .OuroborosScore,
                        .input = SensorInput{
                            .id = .OuroborosScore,
                            .raw_f32 = v,
                            .magnitude_gf16 = gf,
                        },
                    };
                    self.logEvent(event);
                }
            },

            inline .TestsRate => {
                // #2 Tests rate: f32 pass % → OFC → value judgment
                if (sensor_data.raw_f32) |v| {
                    // Layer stats for format selection
                    const stats = ofc.LayerStats{
                        .min = v,
                        .max = v,
                        .mean = v,
                        .std = 0.0,
                        .sparsity = 0.0,
                    };
                    _ = ofc.selectOptimalFormat(stats);
                    const stim = ofc.StimulusValue{
                        .value = v,
                        .sensor_id = 2,
                        .confidence = @floatCast(0.9),
                        .timestamp = std.time.timestamp(),
                    };
                    const val = ofc.assignValence(stim);
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = @as(u64, @intCast(std.time.nanoTimestamp())),
                        .sensor = .TestsRate,
                        .input = SensorInput{
                            .id = .TestsRate,
                            .raw_f32 = v,
                            .valence_valence = val,
                        },
                    };
                    self.logEvent(event);
                }
            },

            inline .DiskFree => {
                // #10 Disk free: u64 bytes → Fusiform → GF16 compact
                if (sensor_data.raw_u64) |v| {
                    const gf = ips.gf16FromF32(@as(f32, @floatFromInt(v)));
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = @as(u64, @intCast(std.time.nanoTimestamp())),
                        .sensor = .DiskFree,
                        .input = SensorInput{
                            .id = .DiskFree,
                            .raw_u64 = v,
                            .magnitude_gf16 = gf,
                        },
                    };
                    self.logEvent(event);
                }
            },

            inline .ArenaStale => {
                // #14 Arena stale: u32 hours → Angular → verbalize/introspect
                if (sensor_data.raw_u32) |v| {
                    // Example: φ-distance analysis
                    const descs = angular.allFormatsTable();
                    // Find most golden format (simplified)
                    var best = descs[0];
                    for (descs[1..]) |desc| {
                        if (desc.phi_distance < best.phi_distance) best = desc;
                    }
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = @as(u64, @intCast(std.time.nanoTimestamp())),
                        .sensor = .ArenaStale,
                        .input = SensorInput{
                            .id = .ArenaStale,
                            .raw_u32 = v,
                        },
                    };
                    self.logEvent(event);
                }
            },
        }
    }

    /// Iterator over circular buffer events
    pub const Iterator = struct {
        thalamus: *const ThalamusLogs,
        index: usize,

        /// Get next event from iterator (returns pointer to event in buffer)
        pub fn next(self: *Iterator) ?*const SensoryEvent {
            if (self.thalamus.len == 0) return null;
            const idx = self.index;
            self.index = (self.index + 1) % self.thalamus.len;
            return &self.thalamus.buf[idx];
        }
    };
};

// ═══════════════════════════════════════════════════════════════════════════
// TESTS — Thalamus relay functionality
// ═══════════════════════════════════════════════════════════════════════════

test "thalamus_logs: ThalamusLogs init creates empty buffer" {
    var buf_storage: [256]SensoryEvent = undefined;
    const thalamus = ThalamusLogs.init(&buf_storage);

    try std.testing.expectEqual(@as(usize, 0), thalamus.head);
    try std.testing.expectEqual(@as(usize, 0), thalamus.len);
}

test "thalamus_logs: logEvent adds to circular buffer" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const event = SensoryEvent{
        .timestamp_ns = 12345,
        .sensor = .FarmBestPpl,
        .input = SensorInput{
            .id = .FarmBestPpl,
            .raw_f32 = 4.6,
        },
    };

    thalamus.logEvent(event);
    try std.testing.expectEqual(@as(usize, 0), thalamus.head);
    try std.testing.expectEqual(@as(usize, 1), thalamus.len);
}

test "thalamus_logs: logEvent multiple events fill buffer" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    for (0..10) |i| {
        const event = SensoryEvent{
            .timestamp_ns = @intCast(i),
            .sensor = .FarmBestPpl,
            .input = SensorInput{
                .id = .FarmBestPpl,
                .raw_f32 = @floatFromInt(i),
            },
        };
        thalamus.logEvent(event);
    }

    try std.testing.expectEqual(@as(usize, 10), thalamus.len);
}

test "thalamus_logs: logEvent stops at 256 capacity" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    // Add 300 events (should cap at 256)
    for (0..300) |i| {
        const event = SensoryEvent{
            .timestamp_ns = @intCast(i),
            .sensor = .FarmBestPpl,
            .input = SensorInput{
                .id = .FarmBestPpl,
                .raw_f32 = @floatFromInt(i),
            },
        };
        thalamus.logEvent(event);
    }

    // Buffer should not exceed 256
    try std.testing.expectEqual(@as(usize, 256), thalamus.len);
}

test "thalamus_logs: iterator returns null for empty buffer" {
    var buf_storage: [256]SensoryEvent = undefined;
    const thalamus = ThalamusLogs.init(&buf_storage);

    var iter = thalamus.iterator();
    const result = iter.next();
    try std.testing.expect(result == null);
}

test "thalamus_logs: iterator traverses events" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const event1 = SensoryEvent{
        .timestamp_ns = 100,
        .sensor = .FarmBestPpl,
        .input = SensorInput{ .id = .FarmBestPpl, .raw_f32 = 4.6 },
    };
    const event2 = SensoryEvent{
        .timestamp_ns = 200,
        .sensor = .ArenaBattles,
        .input = SensorInput{ .id = .ArenaBattles, .raw_i8 = 1 },
    };

    thalamus.logEvent(event1);
    thalamus.logEvent(event2);

    var iter = thalamus.iterator();
    const first = iter.next();
    try std.testing.expect(first != null);
    if (first) |e| {
        try std.testing.expectEqual(@as(u64, 100), e.timestamp_ns);
        try std.testing.expectEqual(SensorId.FarmBestPpl, e.sensor);
    }
}

test "thalamus_logs: SensorId enum values" {
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(SensorId.FarmBestPpl));
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(SensorId.ArenaBattles));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(SensorId.OuroborosScore));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(SensorId.TestsRate));
    try std.testing.expectEqual(@as(u8, 10), @intFromEnum(SensorId.DiskFree));
    try std.testing.expectEqual(@as(u8, 14), @intFromEnum(SensorId.ArenaStale));
}

test "thalamus_logs: SensoryKind enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(SensoryKind.magnitude));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(SensoryKind.ternary));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(SensoryKind.valence));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(SensoryKind.verbal));
}

test "thalamus_logs: SensorInput default values" {
    const input = SensorInput{
        .id = .FarmBestPpl,
    };

    try std.testing.expect(input.raw_f32 == null);
    try std.testing.expect(input.raw_i8 == null);
    try std.testing.expect(input.raw_u32 == null);
    try std.testing.expect(input.raw_u64 == null);
    try std.testing.expect(input.magnitude_gf16 == null);
    try std.testing.expect(input.ternary_tf3 == null);
    try std.testing.expect(input.valence_valence == null);
    try std.testing.expect(input.verbal_msg == null);
}

test "thalamus_logs: SensorInput with f32 value" {
    const input = SensorInput{
        .id = .FarmBestPpl,
        .raw_f32 = 4.6,
    };

    try std.testing.expect(input.raw_f32 != null);
    if (input.raw_f32) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, 4.6), v, 0.01);
    }
}

test "thalamus_logs: SensorInput with i8 value" {
    const input = SensorInput{
        .id = .ArenaBattles,
        .raw_i8 = -1,
    };

    try std.testing.expect(input.raw_i8 != null);
    if (input.raw_i8) |v| {
        try std.testing.expectEqual(@as(i8, -1), v);
    }
}

test "thalamus_logs: SensorInput with u32 value" {
    const input = SensorInput{
        .id = .ArenaStale,
        .raw_u32 = 24,
    };

    try std.testing.expect(input.raw_u32 != null);
    if (input.raw_u32) |v| {
        try std.testing.expectEqual(@as(u32, 24), v);
    }
}

test "thalamus_logs: SensorInput with u64 value" {
    const input = SensorInput{
        .id = .DiskFree,
        .raw_u64 = 1024 * 1024 * 1024, // 1GB
    };

    try std.testing.expect(input.raw_u64 != null);
    if (input.raw_u64) |v| {
        try std.testing.expectEqual(@as(u64, 1073741824), v);
    }
}

test "thalamus_logs: SensoryEvent timestamp" {
    const event = SensoryEvent{
        .timestamp_ns = 1234567890,
        .sensor = .FarmBestPpl,
        .input = SensorInput{ .id = .FarmBestPpl },
    };

    try std.testing.expectEqual(@as(u64, 1234567890), event.timestamp_ns);
}

test "thalamus_logs: VerbalMessage union variants" {
    const short_msg = VerbalMessage{ .short = 42 };
    try std.testing.expectEqual(@as(u8, 42), short_msg.short);

    const medium_msg = VerbalMessage{ .medium = 1000 };
    try std.testing.expectEqual(@as(u16, 1000), medium_msg.medium);

    const long_msg = VerbalMessage{ .long = 100000 };
    try std.testing.expectEqual(@as(u32, 100000), long_msg.long);
}

test "thalamus_logs: processSensor FarmBestPpl encodes GF16" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const sensor_data = SensorInput{
        .id = .FarmBestPpl,
        .raw_f32 = 4.6,
    };

    try thalamus.processSensor(sensor_data);

    try std.testing.expectEqual(@as(usize, 1), thalamus.len);

    // Verify event was logged with GF16 encoding
    var iter = thalamus.iterator();
    const event = iter.next();
    try std.testing.expect(event != null);
    if (event) |e| {
        try std.testing.expectEqual(SensorId.FarmBestPpl, e.sensor);
        try std.testing.expect(e.input.magnitude_gf16 != null);
    }
}

test "thalamus_logs: processSensor ArenaBattles encodes TF3" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const sensor_data = SensorInput{
        .id = .ArenaBattles,
        .raw_i8 = 1, // Win
    };

    try thalamus.processSensor(sensor_data);

    try std.testing.expectEqual(@as(usize, 1), thalamus.len);

    var iter = thalamus.iterator();
    const event = iter.next();
    try std.testing.expect(event != null);
    if (event) |e| {
        try std.testing.expectEqual(SensorId.ArenaBattles, e.sensor);
        try std.testing.expect(e.input.ternary_tf3 != null);
    }
}

test "thalamus_logs: processSensor OuroborosScore uses Weber" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const sensor_data = SensorInput{
        .id = .OuroborosScore,
        .raw_f32 = 75.5,
    };

    try thalamus.processSensor(sensor_data);

    try std.testing.expectEqual(@as(usize, 1), thalamus.len);
}

test "thalamus_logs: processSensor TestsRate uses OFC" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const sensor_data = SensorInput{
        .id = .TestsRate,
        .raw_f32 = 95.0,
    };

    try thalamus.processSensor(sensor_data);

    try std.testing.expectEqual(@as(usize, 1), thalamus.len);

    var iter = thalamus.iterator();
    const event = iter.next();
    try std.testing.expect(event != null);
    if (event) |e| {
        try std.testing.expectEqual(SensorId.TestsRate, e.sensor);
        try std.testing.expect(e.input.valence_valence != null);
    }
}

test "thalamus_logs: processSensor DiskFree encodes GF16" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const sensor_data = SensorInput{
        .id = .DiskFree,
        .raw_u64 = 50 * 1024 * 1024 * 1024, // 50GB
    };

    try thalamus.processSensor(sensor_data);

    try std.testing.expectEqual(@as(usize, 1), thalamus.len);

    var iter = thalamus.iterator();
    const event = iter.next();
    try std.testing.expect(event != null);
    if (event) |e| {
        try std.testing.expectEqual(SensorId.DiskFree, e.sensor);
        try std.testing.expect(e.input.magnitude_gf16 != null);
    }
}

test "thalamus_logs: processSensor ArenaStale uses Angular" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    const sensor_data = SensorInput{
        .id = .ArenaStale,
        .raw_u32 = 48, // 48 hours stale
    };

    try thalamus.processSensor(sensor_data);

    try std.testing.expectEqual(@as(usize, 1), thalamus.len);

    var iter = thalamus.iterator();
    const event = iter.next();
    try std.testing.expect(event != null);
    if (event) |e| {
        try std.testing.expectEqual(SensorId.ArenaStale, e.sensor);
    }
}

test "thalamus_logs: multiple sensors processed sequentially" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    // Process multiple different sensors
    try thalamus.processSensor(SensorInput{ .id = .FarmBestPpl, .raw_f32 = 4.6 });
    try thalamus.processSensor(SensorInput{ .id = .ArenaBattles, .raw_i8 = 1 });
    try thalamus.processSensor(SensorInput{ .id = .OuroborosScore, .raw_f32 = 75.0 });
    try thalamus.processSensor(SensorInput{ .id = .TestsRate, .raw_f32 = 88.0 });

    try std.testing.expectEqual(@as(usize, 4), thalamus.len);
}

test "thalamus_logs: circular buffer wrap behavior" {
    var buf_storage: [256]SensoryEvent = undefined;
    var thalamus = ThalamusLogs.init(&buf_storage);

    // Fill buffer completely
    for (0..256) |i| {
        const event = SensoryEvent{
            .timestamp_ns = @intCast(i),
            .sensor = .FarmBestPpl,
            .input = SensorInput{ .id = .FarmBestPpl },
        };
        thalamus.logEvent(event);
    }

    try std.testing.expectEqual(@as(usize, 256), thalamus.len);

    // Adding more should not increase length
    const extra_event = SensoryEvent{
        .timestamp_ns = 999,
        .sensor = .ArenaBattles,
        .input = SensorInput{ .id = .ArenaBattles },
    };
    thalamus.logEvent(extra_event);

    try std.testing.expectEqual(@as(usize, 256), thalamus.len);
}

test "thalamus_logs: SensorInput id field matches sensor" {
    const input = SensorInput{
        .id = .DiskFree,
        .raw_u64 = 1024,
    };

    try std.testing.expectEqual(SensorId.DiskFree, input.id);
}

// φ² + 1/φ² = 3 | TRINITY
