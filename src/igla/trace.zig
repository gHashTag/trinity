// TRI-TRACE: Symbolic Reasoning Trace Mode (DEV-001)
// Records VSA operation chains for debugging symbolic reasoning
const std = @import("std");

pub const MAX_TRACE_ENTRIES: usize = 256;
pub const MAX_LABEL_LEN: usize = 64;

pub const OpKind = enum {
    bind,
    unbind,
    bundle2,
    bundle3,
    bundleN,
    permute,
    similarity,
    norm,
    count_nz,
};

pub const VectorMeta = struct {
    trit_len: usize,
    norm_val: f64,
    non_zero: usize,
};

pub const TraceEntry = struct {
    step: usize,
    op: OpKind,
    label: [MAX_LABEL_LEN]u8,
    label_len: usize,
    input_a: VectorMeta,
    input_b: VectorMeta,
    result_meta: VectorMeta,
    scalar_result: f64,
};

pub const Tracer = struct {
    entries: [MAX_TRACE_ENTRIES]TraceEntry,
    count: usize,
    active: bool,

    pub fn init() Tracer {
        return .{
            .entries = undefined,
            .count = 0,
            .active = false,
        };
    }

    pub fn start(self: *Tracer) void {
        self.count = 0;
        self.active = true;
    }

    pub fn stop(self: *Tracer) usize {
        self.active = false;
        return self.count;
    }

    pub fn record(self: *Tracer, op: OpKind, label: []const u8, a: VectorMeta, b: VectorMeta, result: VectorMeta, scalar: f64) void {
        if (!self.active) return;
        if (self.count >= MAX_TRACE_ENTRIES) return;

        var entry: TraceEntry = .{
            .step = self.count,
            .op = op,
            .label = undefined,
            .label_len = @min(label.len, MAX_LABEL_LEN),
            .input_a = a,
            .input_b = b,
            .result_meta = result,
            .scalar_result = scalar,
        };
        @memset(&entry.label, 0);
        const copy_len = @min(label.len, MAX_LABEL_LEN);
        @memcpy(entry.label[0..copy_len], label[0..copy_len]);
        self.entries[self.count] = entry;
        self.count += 1;
    }

    pub fn recordBinary(self: *Tracer, op: OpKind, label: []const u8, a: VectorMeta, b: VectorMeta, result: VectorMeta) void {
        self.record(op, label, a, b, result, 0.0);
    }

    pub fn recordScalar(self: *Tracer, op: OpKind, label: []const u8, a: VectorMeta, b: VectorMeta, scalar: f64) void {
        self.record(op, label, a, b, .{ .trit_len = 0, .norm_val = 0, .non_zero = 0 }, scalar);
    }

    pub fn getEntries(self: *const Tracer) []const TraceEntry {
        return self.entries[0..self.count];
    }

    pub fn printTrace(self: *const Tracer) void {
        if (self.count == 0) {
            std.debug.print("[TRI-TRACE] No entries recorded.\n", .{});
            return;
        }
        std.debug.print("\n[TRI-TRACE] Trace ({d} steps)\n", .{self.count});
        for (self.entries[0..self.count]) |e| {
            const op_str = opName(e.op);
            const lbl = e.label[0..e.label_len];
            std.debug.print("{d:>4} {s: <9} {s: <20} A:{d:>5},nz:{d:>5} B:{d:>5},nz:{d:>5} scalar={d:.4}\n", .{
                e.step,
                op_str,
                lbl,
                e.input_a.trit_len,
                e.input_a.non_zero,
                e.input_b.trit_len,
                e.input_b.non_zero,
                e.scalar_result,
            });
        }
    }
};

fn opName(op: OpKind) []const u8 {
    return switch (op) {
        .bind => "bind",
        .unbind => "unbind",
        .bundle2 => "bundle2",
        .bundle3 => "bundle3",
        .bundleN => "bundleN",
        .permute => "permute",
        .similarity => "sim",
        .norm => "norm",
        .count_nz => "count_nz",
    };
}

var global_tracer: Tracer = Tracer.init();

pub fn getGlobalTracer() *Tracer {
    return &global_tracer;
}

pub fn meta(trit_len: usize, non_zero: usize, norm_val: f64) VectorMeta {
    return .{ .trit_len = trit_len, .norm_val = norm_val, .non_zero = non_zero };
}

pub fn emptyMeta() VectorMeta {
    return .{ .trit_len = 0, .norm_val = 0, .non_zero = 0 };
}

test "Tracer init and record" {
    var t = Tracer.init();
    t.start();
    const a_meta = meta(1024, 680, 26.0);
    const b_meta = meta(1024, 690, 26.3);
    const r_meta = meta(1024, 700, 26.5);
    t.recordBinary(.bind, "bind(apple,red)", a_meta, b_meta, r_meta);
    try std.testing.expect(t.count == 1);
    try std.testing.expect(t.entries[0].op == .bind);
    try std.testing.expect(t.entries[0].input_a.trit_len == 1024);
    const stopped = t.stop();
    try std.testing.expect(stopped == 1);
    try std.testing.expect(!t.active);
}

test "Tracer full reasoning chain" {
    var t = Tracer.init();
    t.start();
    const m = meta(256, 170, 13.0);
    t.recordBinary(.bind, "bind(apple,red)", m, m, m);
    t.recordBinary(.bind, "bind(banana,yellow)", m, m, m);
    t.recordBinary(.bundle2, "memory=bundle2", m, m, m);
    t.recordBinary(.unbind, "unbind(mem,red)", m, m, m);
    t.recordScalar(.similarity, "sim(query,apple)", m, m, 0.63);
    t.recordScalar(.similarity, "sim(query,banana)", m, m, 0.02);
    try std.testing.expect(t.count == 6);
    try std.testing.expect(t.entries[4].scalar_result > 0.5);
    try std.testing.expect(t.entries[5].scalar_result < 0.1);
    _ = t.stop();
}

test "Tracer inactive does not record" {
    var t = Tracer.init();
    const m = meta(100, 66, 8.0);
    t.recordBinary(.bind, "should_not_record", m, m, m);
    try std.testing.expect(t.count == 0);
}

test "Tracer overflow protection" {
    var t = Tracer.init();
    t.start();
    const m = meta(100, 66, 8.0);
    for (0..MAX_TRACE_ENTRIES + 10) |_| {
        t.recordBinary(.bind, "overflow", m, m, m);
    }
    try std.testing.expect(t.count == MAX_TRACE_ENTRIES);
    _ = t.stop();
}

// phi^2 + 1/phi^2 = 3 | TRINITY
