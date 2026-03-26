// TRI TRAIN TYPES — Sacred training type definitions
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const CheckpointInfo = struct {
    step: u32 = 0,
    loss: f32 = 0.0,
    ppl: f32 = 0.0,
    file_size: u64 = 0,
    path: []const u8 = "",
};

pub const TrainLogEntry = struct {
    step: u32 = 0,
    loss: f32 = 0.0,
    ppl: f32 = 0.0,
    host: []const u8 = "",
    lr: f64 = 0.0,
    timestamp: i64 = 0,
};

pub const Sacred = struct {
    // Comptime constants
    pub const phi = 1.618033988749895;
    pub const phi_inv = 0.618033988749895;
    pub const PHI = 1.618033988749895;
    pub const PHI_INV = 0.618033988749895;
    pub const PHI_SQ = 2.618033988749895;
    pub const PHI_INV_SQ = 0.3819660112501051;
    pub const LOG2_3 = 1.584962500721156; // log2(3) for ternary encoding
};
