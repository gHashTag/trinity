// @origin(spec:train_diagnostics.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// HSLM Training Diagnostics — φ-aware Anomaly Detector
// ═══════════════════════════════════════════════════════════════════════════════
//
// Automatic anomaly detection for HSLM training runs.
// Thresholds derived from sacred constants (φ, φ², φ⁻¹, φ⁻³).
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("train_types.zig");
const TrainLogEntry = types.TrainLogEntry;
const CheckpointInfo = types.CheckpointInfo;
const Sacred = types.Sacred;

// ═══════════════════════════════════════════════════════════════════════════════
// ANOMALY TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const AnomalyType = enum {
    zero_loss, // loss == 0.0
    loss_explosion, // loss > 10.0 or >200% growth in 1K steps
    zero_gradients, // grad_norm == 0.0
    gradient_explosion, // grad_norm > 100.0
    logit_overflow, // max_logit > 50.0
    logit_underflow, // min_logit < -50.0
    ppl_suspicion, // PPL < 3.0 without val_loss confirmation
    phase_transition, // |Δloss| > φ (1.618) between checkpoints
    stale_checkpoint, // no new checkpoint > 30 min
    throughput_drop, // tok/s dropped > 50% from baseline
    overfitting, // val_loss / train_loss > φ² (2.618)
    c_ratio_flat, // compression_ratio == 1.0 (no learning)
};

pub const Severity = enum {
    info,
    warning,
    critical,

    pub fn symbol(self: Severity) []const u8 {
        return switch (self) {
            .info => "INFO",
            .warning => "WARN",
            .critical => "CRIT",
        };
    }
};

pub const Anomaly = struct {
    anomaly_type: AnomalyType,
    severity: Severity,
    step: u32,
    host: []const u8,
    message: []const u8,
    recommendation: []const u8,
};

pub const Recommendation = struct {
    action: []const u8,
    reason: []const u8,
    command: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANOMALY DETECTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Diagnose anomalies from a sequence of training log entries.
/// Returns detected anomalies in provided buffer. Returns count of anomalies found.
pub fn diagnose(entries: []const TrainLogEntry, out: []Anomaly) usize {
    var count: usize = 0;

    for (entries, 0..) |entry, i| {
        // Zero loss
        if (entry.loss == 0.0 and entry.step > 0) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .zero_loss,
                    .severity = .critical,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Loss is exactly 0.0 — model not learning or data empty",
                    .recommendation = "Check data path and batch loading. Verify tokenizer output.",
                };
                count += 1;
            }
        }

        // Loss explosion
        if (entry.loss > 10.0) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .loss_explosion,
                    .severity = .critical,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Loss > 10.0 — possible divergence",
                    .recommendation = "Reduce learning rate. Check for NaN in gradients.",
                };
                count += 1;
            }
        }

        // Zero gradients (only when grad_norm is actually reported, not default 0)
        if (entry.grad_norm == 0.0 and entry.step > 0 and entry.loss != 0.0 and entry.tok_per_sec > 0) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .zero_gradients,
                    .severity = .critical,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Gradient norm is 0.0 — model is dead",
                    .recommendation = "Check backward pass. Verify STE quantization is not zeroing all grads.",
                };
                count += 1;
            }
        }

        // Gradient explosion
        if (entry.grad_norm > 100.0) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .gradient_explosion,
                    .severity = .warning,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Gradient norm > 100.0 — explosion risk",
                    .recommendation = "Enable gradient clipping. Reduce learning rate.",
                };
                count += 1;
            }
        }

        // Logit overflow
        if (entry.max_logit > 50.0) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .logit_overflow,
                    .severity = .warning,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Max logit > 50.0 — NaN risk in softmax",
                    .recommendation = "Add logit clamping or reduce weight scale.",
                };
                count += 1;
            }
        }

        // Logit underflow
        if (entry.min_logit < -50.0) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .logit_underflow,
                    .severity = .warning,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Min logit < -50.0 — underflow risk",
                    .recommendation = "Check weight initialization. Look for dead neurons.",
                };
                count += 1;
            }
        }

        // PPL suspicion (too good without validation)
        if (entry.ppl > 0.0 and entry.ppl < 3.0 and entry.step > 1000) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .ppl_suspicion,
                    .severity = .warning,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "PPL < 3.0 — suspiciously good, may be overfitting",
                    .recommendation = "Run validation: tri train checkpoint eval <ckpt> --data validation.txt",
                };
                count += 1;
            }
        }

        // C-ratio flat (no learning)
        if (entry.c_ratio == 1.0 and entry.step > 100) {
            if (count < out.len) {
                out[count] = .{
                    .anomaly_type = .c_ratio_flat,
                    .severity = .critical,
                    .step = entry.step,
                    .host = entry.host,
                    .message = "Compression ratio = 1.0 — model not transforming data",
                    .recommendation = "Verify forward pass produces varied outputs. Check weight init.",
                };
                count += 1;
            }
        }

        // Phase transition: |Δloss| > φ between consecutive entries
        if (i > 0) {
            const prev = entries[i - 1];
            const delta = entry.loss - prev.loss;
            const abs_delta = if (delta < 0) -delta else delta;
            if (abs_delta > @as(f32, @floatCast(Sacred.PHI))) {
                if (count < out.len) {
                    out[count] = .{
                        .anomaly_type = .phase_transition,
                        .severity = .info,
                        .step = entry.step,
                        .host = entry.host,
                        .message = "Phase transition detected — loss changed by more than phi",
                        .recommendation = "Run validation to confirm. Compare generation at previous vs current step.",
                    };
                    count += 1;
                }
            }
        }

        // Throughput drop (> 50% from first entry baseline)
        if (i > 0 and entries[0].tok_per_sec > 0) {
            const baseline = entries[0].tok_per_sec;
            if (entry.tok_per_sec > 0 and entry.tok_per_sec < baseline * 0.5) {
                if (count < out.len) {
                    out[count] = .{
                        .anomaly_type = .throughput_drop,
                        .severity = .warning,
                        .step = entry.step,
                        .host = entry.host,
                        .message = "Throughput dropped > 50% from baseline",
                        .recommendation = "Check system resources. Possible memory pressure or thermal throttling.",
                    };
                    count += 1;
                }
            }
        }
    }

    return count;
}

/// Get top recommendation based on anomalies
pub fn recommend(entries: []const TrainLogEntry) Recommendation {
    var anomaly_buf: [32]Anomaly = undefined;
    const n = diagnose(entries, &anomaly_buf);
    const anomalies = anomaly_buf[0..n];

    for (anomalies) |a| {
        if (a.anomaly_type == .zero_loss) {
            return .{
                .action = "STOP",
                .reason = "Zero loss — training is not learning",
                .command = "Kill process and check data path",
            };
        }
    }

    for (anomalies) |a| {
        if (a.anomaly_type == .zero_gradients) {
            return .{
                .action = "STOP",
                .reason = "Zero gradients — model is dead",
                .command = "Check backward pass and STE implementation",
            };
        }
    }

    for (anomalies) |a| {
        if (a.anomaly_type == .phase_transition) {
            return .{
                .action = "VALIDATE",
                .reason = "Phase transition detected — verify on val set",
                .command = "tri train checkpoint eval <ckpt> --data validation.txt",
            };
        }
    }

    for (anomalies) |a| {
        if (a.anomaly_type == .ppl_suspicion) {
            return .{
                .action = "EVAL",
                .reason = "PPL suspiciously low — check for overfitting",
                .command = "tri train compare train.jsonl val.jsonl",
            };
        }
    }

    for (anomalies) |a| {
        if (a.anomaly_type == .loss_explosion) {
            return .{
                .action = "REDUCE_LR",
                .reason = "Loss explosion detected",
                .command = "Reduce LR by phi^-1 (0.618x)",
            };
        }
    }

    return .{
        .action = "CONTINUE",
        .reason = "Training healthy — no anomalies detected",
        .command = "Monitor next checkpoint",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKPOINT SCANNING
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan directory for HSLM checkpoint files and read headers.
/// Returns count of checkpoints found.
pub fn scanCheckpoints(
    dir_path: []const u8,
    out: []CheckpointInfo,
) usize {
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return 0;
    defer dir.close();

    var count: usize = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (count >= out.len) break;
        if (entry.kind != .file) continue;

        // Match hslm_step_*.bin
        const name = entry.name;
        if (!std.mem.startsWith(u8, name, "hslm_step_")) continue;
        if (!std.mem.endsWith(u8, name, ".bin")) continue;
        // Skip backup copies
        if (std.mem.indexOf(u8, name, "PHASE") != null) continue;

        // Read 16-byte header
        const file = dir.openFile(name, .{}) catch continue;
        defer file.close();

        var header_bytes: [16]u8 = undefined;
        const n = file.read(&header_bytes) catch continue;
        if (n < 16) continue;

        const header = types.CheckpointHeader.fromBytes(&header_bytes);
        if (!header.isValid()) continue;

        const stat = file.stat() catch continue;

        out[count] = .{
            .step = header.step,
            .loss = header.loss,
            .ppl = @exp(header.loss),
            .file_size = stat.size,
            .mtime_sec = @divFloor(stat.mtime, std.time.ns_per_s),
        };
        out[count].setPath(name);
        count += 1;
    }

    // Sort by step
    std.mem.sort(CheckpointInfo, out[0..count], {}, struct {
        fn lessThan(_: void, a: CheckpointInfo, b: CheckpointInfo) bool {
            return a.step < b.step;
        }
    }.lessThan);

    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON OUTPUT
// ═══════════════════════════════════════════════════════════════════════════════

/// Format anomalies as JSON into buffer
pub fn anomaliesToJson(anomalies: []const Anomaly, buf: []u8) []const u8 {
    var idx: usize = 0;
    const b = buf;

    idx += copySlice(b[idx..], "[");
    for (anomalies, 0..) |a, i| {
        if (i > 0) idx += copySlice(b[idx..], ",");
        idx += copySlice(b[idx..], "{\"type\":\"");
        idx += copySlice(b[idx..], @tagName(a.anomaly_type));
        idx += copySlice(b[idx..], "\",\"severity\":\"");
        idx += copySlice(b[idx..], a.severity.symbol());
        idx += copySlice(b[idx..], "\",\"step\":");
        var num_buf: [16]u8 = undefined;
        const num = std.fmt.bufPrint(&num_buf, "{d}", .{a.step}) catch "0";
        idx += copySlice(b[idx..], num);
        idx += copySlice(b[idx..], ",\"host\":\"");
        idx += copySlice(b[idx..], a.host);
        idx += copySlice(b[idx..], "\",\"message\":\"");
        idx += copySlice(b[idx..], a.message);
        idx += copySlice(b[idx..], "\",\"recommendation\":\"");
        idx += copySlice(b[idx..], a.recommendation);
        idx += copySlice(b[idx..], "\"}");
    }
    idx += copySlice(b[idx..], "]");
    return b[0..idx];
}

fn copySlice(dst: []u8, src: []const u8) usize {
    const n = @min(dst.len, src.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "diagnose zero loss" {
    const entries = [_]TrainLogEntry{
        .{ .step = 100, .loss = 0.0, .host = "railway" },
    };
    var anomalies: [8]Anomaly = undefined;
    const n = diagnose(&entries, &anomalies);
    try std.testing.expect(n >= 1);
    try std.testing.expectEqual(AnomalyType.zero_loss, anomalies[0].anomaly_type);
    try std.testing.expectEqual(Severity.critical, anomalies[0].severity);
}

test "diagnose phase transition" {
    const entries = [_]TrainLogEntry{
        .{ .step = 45000, .loss = 5.638, .host = "m1pro" },
        .{ .step = 50000, .loss = 0.984, .host = "m1pro" },
    };
    var anomalies: [8]Anomaly = undefined;
    const n = diagnose(&entries, &anomalies);
    var found_pt = false;
    for (anomalies[0..n]) |a| {
        if (a.anomaly_type == .phase_transition) found_pt = true;
    }
    try std.testing.expect(found_pt);
}

test "diagnose c_ratio flat" {
    const entries = [_]TrainLogEntry{
        .{ .step = 200, .loss = 6.5, .c_ratio = 1.0, .host = "railway" },
    };
    var anomalies: [8]Anomaly = undefined;
    const n = diagnose(&entries, &anomalies);
    var found = false;
    for (anomalies[0..n]) |a| {
        if (a.anomaly_type == .c_ratio_flat) found = true;
    }
    try std.testing.expect(found);
}

test "recommend stop on zero loss" {
    const entries = [_]TrainLogEntry{
        .{ .step = 100, .loss = 0.0, .host = "railway" },
    };
    const rec = recommend(&entries);
    try std.testing.expect(std.mem.eql(u8, rec.action, "STOP"));
}

test "recommend validate on phase transition" {
    const entries = [_]TrainLogEntry{
        .{ .step = 45000, .loss = 5.638, .host = "m1pro" },
        .{ .step = 50000, .loss = 0.984, .host = "m1pro" },
    };
    const rec = recommend(&entries);
    try std.testing.expect(std.mem.eql(u8, rec.action, "VALIDATE"));
}

test "recommend continue when healthy" {
    const entries = [_]TrainLogEntry{
        .{ .step = 5000, .loss = 6.5, .ppl = 665.0, .c_ratio = 0.85, .tok_per_sec = 1400, .grad_norm = 5.0, .host = "m1pro" },
        .{ .step = 10000, .loss = 5.9, .ppl = 365.0, .c_ratio = 0.82, .tok_per_sec = 1380, .grad_norm = 4.5, .host = "m1pro" },
    };
    const rec = recommend(&entries);
    try std.testing.expect(std.mem.eql(u8, rec.action, "CONTINUE"));
}

test "anomalies to json" {
    const anomalies = [_]Anomaly{
        .{
            .anomaly_type = .zero_loss,
            .severity = .critical,
            .step = 100,
            .host = "railway",
            .message = "Loss is 0.0",
            .recommendation = "Check data",
        },
    };
    var buf: [1024]u8 = undefined;
    const json = anomaliesToJson(&anomalies, &buf);
    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "zero_loss") != null);
}
