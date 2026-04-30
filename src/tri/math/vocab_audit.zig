const std = @import("std");

pub const TRINITY_VOCAB: usize = 729;
pub const TRINITY_HIDDEN: usize = 243;
pub const TRINITY_CONTEXT: usize = 81;
pub const TRINITY_BLOCKS: usize = 9;
pub const TRINITY_HEADS: usize = 9;
pub const TRINITY_HEAD_DIM: usize = 27;
pub const TRINITY_FFN: usize = 729;

pub fn isVocabCompliant(vocab_size: usize) bool {
    return vocab_size == TRINITY_VOCAB;
}

pub fn paddingActiveRange() struct { lo: usize, hi: usize } {
    return .{ .lo = 0, .hi = 255 };
}

pub fn paddingLogitMask(logits: []f32, vocab_size: usize) void {
    if (vocab_size != TRINITY_VOCAB) return;
    for (256..vocab_size) |i| {
        if (i < logits.len) logits[i] = -std.math.inf(f32);
    }
}

pub const AuditResult = struct {
    source: []const u8,
    vocab_size: usize,
    compliant: bool,
};

pub fn auditEntry(source: []const u8, vocab_size: usize) AuditResult {
    return .{
        .source = source,
        .vocab_size = vocab_size,
        .compliant = isVocabCompliant(vocab_size),
    };
}

pub fn printAuditReport(results: []const AuditResult, writer: anytype) !void {
    try writer.print("\n  Vocab Audit Report (SSOT = {d} = 3^6)\n", .{TRINITY_VOCAB});
    try writer.print("  {s}\n", .{"-" * 52});
    try writer.print("  {s:<40} {s:>6} {s:>6}\n", .{ "Source", "Vocab", "Status" });
    try writer.print("  {s}\n", .{"-" * 52});

    var non_compliant: usize = 0;
    for (results) |r| {
        const status = if (r.compliant) "OK" else "MISMATCH";
        try writer.print("  {s:<40} {d:>6} {s:>6}\n", .{ r.source, r.vocab_size, status });
        if (!r.compliant) non_compliant += 1;
    }

    try writer.print("  {s}\n", .{"-" * 52});
    if (non_compliant == 0) {
        try writer.print("  ALL MODULES COMPLIANT: vocab={d}\n\n", .{TRINITY_VOCAB});
    } else {
        try writer.print("  NON-COMPLIANT: {d} module(s) need fix\n\n", .{non_compliant});
    }
}

test "is vocab compliant" {
    try std.testing.expect(isVocabCompliant(729));
    try std.testing.expect(!isVocabCompliant(256));
    try std.testing.expect(!isVocabCompliant(128256));
}

test "padding logit mask" {
    var logits: [729]f32 = undefined;
    for (&logits) |*l| l.* = 0.0;

    paddingLogitMask(&logits, 729);

    for (0..256) |i| {
        try std.testing.expect(logits[i] == 0.0);
    }
    for (256..729) |i| {
        try std.testing.expect(std.math.isInf(logits[i]) and logits[i] < 0);
    }
}

test "padding logit mask ignores wrong vocab" {
    var logits: [256]f32 = undefined;
    for (&logits) |*l| l.* = 1.0;
    paddingLogitMask(&logits, 256);
    for (logits) |l| {
        try std.testing.expect(l == 1.0);
    }
}

test "audit entry" {
    const r = auditEntry("test_module", 729);
    try std.testing.expect(r.compliant);
    try std.testing.expectEqual(@as(usize, 729), r.vocab_size);
}

test "trinity config values" {
    try std.testing.expectEqual(@as(usize, 729), TRINITY_VOCAB);
    try std.testing.expectEqual(@as(usize, 243), TRINITY_HIDDEN);
    try std.testing.expectEqual(@as(usize, 81), TRINITY_CONTEXT);
    try std.testing.expectEqual(@as(usize, 9), TRINITY_BLOCKS);
    try std.testing.expectEqual(@as(usize, 9), TRINITY_HEADS);
    try std.testing.expectEqual(@as(usize, 27), TRINITY_HEAD_DIM);
}
