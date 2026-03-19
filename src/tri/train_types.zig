// @origin(spec:train_types.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// HSLM Training Log Types — SSOT format (JSONL)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Standard structured log entry for HSLM training monitoring.
// Written by trainer, read by `tri train` CLI and MCP tools.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Single training log entry (JSONL line)
pub const TrainLogEntry = struct {
    step: u32 = 0,
    loss: f32 = 0.0,
    ppl: f32 = 0.0,
    lr: f32 = 0.0,
    grad_norm: f32 = 0.0,
    max_logit: f32 = 0.0,
    min_logit: f32 = 0.0,
    c_ratio: f32 = 0.0,
    tok_per_sec: f32 = 0.0,
    epoch: u32 = 1,
    wall_sec: u64 = 0,
    host: []const u8 = "",
    ts: []const u8 = "",

    /// Format as JSONL line into buffer
    pub fn toJson(self: TrainLogEntry, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf,
            \\{{"step":{d},"loss":{d:.6},"ppl":{d:.2},"lr":{d:.6},"grad_norm":{d:.4},"max_logit":{d:.2},"min_logit":{d:.2},"c_ratio":{d:.4},"tok_per_sec":{d:.0},"epoch":{d},"wall_sec":{d},"host":"{s}","ts":"{s}"}}
        , .{
            self.step,        self.loss,      self.ppl,       self.lr,
            self.grad_norm,   self.max_logit, self.min_logit, self.c_ratio,
            self.tok_per_sec, self.epoch,     self.wall_sec,  self.host,
            self.ts,
        }) catch buf[0..0];
    }
};

/// Checkpoint binary header (16 bytes)
pub const CheckpointHeader = struct {
    magic: u32, // 0x484C534D = "HSLM"
    version: u32,
    step: u32,
    loss: f32,

    pub const MAGIC: u32 = 0x484C534D;
    pub const SIZE: usize = 16;

    pub fn fromBytes(bytes: *const [16]u8) CheckpointHeader {
        return .{
            .magic = std.mem.readInt(u32, bytes[0..4], .little),
            .version = std.mem.readInt(u32, bytes[4..8], .little),
            .step = std.mem.readInt(u32, bytes[8..12], .little),
            .loss = @bitCast(std.mem.readInt(u32, bytes[12..16], .little)),
        };
    }

    pub fn isValid(self: CheckpointHeader) bool {
        return self.magic == MAGIC and self.version >= 1;
    }
};

/// Parsed checkpoint info
pub const CheckpointInfo = struct {
    /// Fixed buffer for path — iterator's name buffer is reused/freed after iteration
    path_buf: [128]u8 = undefined,
    path_len: u8 = 0,
    step: u32 = 0,
    loss: f32 = 0,
    ppl: f32 = 0,
    file_size: u64 = 0,
    mtime_sec: i128 = 0,

    /// Get the path as a slice (safe — points to owned buffer, not iterator internals)
    pub fn path(self: *const CheckpointInfo) []const u8 {
        return self.path_buf[0..self.path_len];
    }

    /// Set path from a source slice (copies into owned buffer)
    pub fn setPath(self: *CheckpointInfo, src: []const u8) void {
        const n: u8 = @intCast(@min(src.len, self.path_buf.len));
        @memcpy(self.path_buf[0..n], src[0..n]);
        self.path_len = n;
    }
};

/// Training run summary
pub const TrainRunSummary = struct {
    host: []const u8,
    total_steps: u32,
    current_step: u32,
    best_loss: f32,
    best_step: u32,
    latest_loss: f32,
    latest_ppl: f32,
    checkpoints: u32,
    wall_sec: u64,
    tok_per_sec: f32,
    is_running: bool,
};

/// Sacred constants for thresholds
pub const Sacred = struct {
    pub const PHI: f64 = 1.6180339887498948482;
    pub const PHI_INV: f64 = 0.6180339887498948482;
    pub const PHI_SQ: f64 = PHI * PHI; // 2.618
    pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV; // 0.382
    pub const PHI_INV_CUBED: f64 = PHI_INV * PHI_INV * PHI_INV; // 0.236
    pub const LOG2_3: f64 = 1.5849625007211562; // bits per trit
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "checkpoint header from bytes" {
    // Magic: HSLM (0x484C534D), Version: 1, Step: 50000, Loss: 0.984
    const bytes = [16]u8{
        0x4D, 0x53, 0x4C, 0x48, // magic LE
        0x01, 0x00, 0x00, 0x00, // version
        0x50, 0xC3, 0x00, 0x00, // step 50000
        0x00, 0x00, 0x00, 0x00, // loss placeholder
    };
    const header = CheckpointHeader.fromBytes(&bytes);
    try std.testing.expect(header.isValid());
    try std.testing.expectEqual(@as(u32, 50000), header.step);
}

test "train log entry to json" {
    const entry = TrainLogEntry{
        .step = 5000,
        .loss = 6.489,
        .ppl = 657.6,
        .lr = 0.001,
        .host = "m1pro",
    };
    var buf: [512]u8 = undefined;
    const json = entry.toJson(&buf);
    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"step\":5000") != null);
}

test "sacred constants" {
    const trinity = Sacred.PHI_SQ + Sacred.PHI_INV_SQ;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), trinity, 1e-10);
}

test "TrainLogEntry initialization" {
    const entry = TrainLogEntry{
        .step = 100,
        .loss = 0.0,
        .ppl = 2.0,
        .lr = 0.01,
        .grad_norm = 0.5,
        .max_logit = 100,
        .min_logit = 1,
        .c_ratio = 0.5,
        .tok_per_sec = 100.0,
        .epoch = 1,
        .wall_sec = 60,
        .host = "test-host",
        .ts = "2024-01-01T00:00:00",
    };

    var buf = [_]u8{0} ** 1024;
    _ = entry.toJson(&buf);
    const json = entry.toJson(&buf);
    // Verify key fields are present in JSON
    try std.testing.expect(std.mem.indexOf(u8, json, "\"step\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"loss\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"ppl\":2.00") != null);
}

test "JSON formatting" {
    // Verify JSON output format
    const entry = TrainLogEntry{
        .step = 1,
        .loss = 1.0,
        .ppl = 2.0,
        .tok_per_sec = 100.0,
    };
    var buf = [_]u8{0} ** 1024;
    const json = entry.toJson(&buf);
    try std.testing.expect(json.len > 0);
}
