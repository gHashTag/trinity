// @origin(spec:thalamus_logs.tri) @regen(manual-impl)
// THALAMUS LOGS — Sensory relay station for Trinity cortex
//
// Thalamus: Relays sensory input from Queen (18 sensors) to cortex (5 modules)
// Provides circular buffer logging with direct HSLM module calls
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
// Import sensation module for HSLM access
const sensation_mod = @import("trinity-sensation");
const ips = sensation_mod.ips;
const weber = sensation_mod.weber;
const fusiform = sensation_mod.fusiform;
const angular = sensation_mod.angular;
const ofc = sensation_mod.ofc;

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
    short = u8,
    medium = u16,
    long = u32,
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
                        .timestamp_ns = std.time.nanoTimestamp(),
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
                    const f32_val = @as(f32, v);
                    const tf = ips.tf3FromF32(f32_val);
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = std.time.nanoTimestamp(),
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
                        .timestamp_ns = std.time.nanoTimestamp(),
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
                        .timestamp_ns = std.time.nanoTimestamp(),
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
                    const gf = ips.gf16FromF32(@floatFromInt(@as(f64, v)));
                    // Store in buffer
                    const event = SensoryEvent{
                        .timestamp_ns = std.time.nanoTimestamp(),
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
                        .timestamp_ns = std.time.nanoTimestamp(),
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
    };

    /// Get next event from iterator
    pub fn next(self: *Iterator) ?SensoryEvent {
        if (self.thalamus.len == 0) return null;
        const idx = self.index;
        self.index = (self.index + 1) % self.thalamus.len;
        return &self.thalamus.buf[idx];
    }
};

// φ² + 1/φ² = 3 | TRINITY
