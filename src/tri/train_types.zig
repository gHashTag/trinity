// TRI TRAIN TYPES — Stub for training type definitions
// TODO: Implement proper training types
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const CheckpointInfo = struct {
    step: u64 = 0,
    loss: f64 = 0.0,
    path: []const u8 = "",
};

pub const TrainLogEntry = struct {
    step: u64 = 0,
    loss: f64 = 0.0,
    lr: f64 = 0.0,
    timestamp: i64 = 0,
};

pub const Sacred = struct {
    phi: f64 = 1.618033988749895,
    phi_inv: f64 = 0.618033988749895,
};
