// =============================================================================
// COST TRACKER — v5.1 Per-Issue Token & USD Tracking
// =============================================================================
//
// Accumulates token counts per role, estimates USD cost using hardcoded rates.
// Writes cost data into handoff artifacts.
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const golden_chain = @import("golden_chain.zig");

const AgentRole = golden_chain.AgentRole;

// =============================================================================
// COST RATES (USD per 1K tokens)
// =============================================================================

pub const ModelRates = struct {
    input_per_1k: f64,
    output_per_1k: f64,
};

/// Hardcoded rates per model. Update as pricing changes.
pub fn getRates(model: []const u8) ModelRates {
    if (std.mem.eql(u8, model, "glm-5")) {
        return .{ .input_per_1k = 0.001, .output_per_1k = 0.002 };
    } else if (std.mem.startsWith(u8, model, "claude-sonnet") or std.mem.eql(u8, model, "claude-sonnet-4-20250514")) {
        return .{ .input_per_1k = 0.003, .output_per_1k = 0.015 };
    } else if (std.mem.startsWith(u8, model, "claude-opus")) {
        return .{ .input_per_1k = 0.015, .output_per_1k = 0.075 };
    } else if (std.mem.startsWith(u8, model, "claude-haiku")) {
        return .{ .input_per_1k = 0.00025, .output_per_1k = 0.00125 };
    }
    // Default to glm-5 rates
    return .{ .input_per_1k = 0.001, .output_per_1k = 0.002 };
}

// =============================================================================
// COST ENTRY (per role)
// =============================================================================

pub const CostEntry = struct {
    role: AgentRole,
    tokens_in: u64,
    tokens_out: u64,
    model: [64]u8,
    model_len: usize,
    usd: f64,

    pub fn init(role: AgentRole) CostEntry {
        return .{
            .role = role,
            .tokens_in = 0,
            .tokens_out = 0,
            .model = undefined,
            .model_len = 0,
            .usd = 0.0,
        };
    }

    pub fn setModel(self: *CostEntry, model: []const u8) void {
        const len = @min(model.len, self.model.len);
        @memcpy(self.model[0..len], model[0..len]);
        self.model_len = len;
    }

    pub fn getModel(self: *const CostEntry) []const u8 {
        return self.model[0..self.model_len];
    }

    pub fn addTokens(self: *CostEntry, tokens_in: u64, tokens_out: u64) void {
        self.tokens_in += tokens_in;
        self.tokens_out += tokens_out;
        self.recalculate();
    }

    fn recalculate(self: *CostEntry) void {
        const rates = getRates(self.getModel());
        const in_cost = @as(f64, @floatFromInt(self.tokens_in)) / 1000.0 * rates.input_per_1k;
        const out_cost = @as(f64, @floatFromInt(self.tokens_out)) / 1000.0 * rates.output_per_1k;
        self.usd = in_cost + out_cost;
    }
};

// =============================================================================
// COST TRACKER (aggregates all roles for one issue)
// =============================================================================

pub const CostTracker = struct {
    issue_number: u32,
    entries: [5]CostEntry, // one per role
    started_at: i64,

    pub fn init(issue_number: u32) CostTracker {
        var entries: [5]CostEntry = undefined;
        for (golden_chain.ALL_ROLES, 0..) |role, i| {
            entries[i] = CostEntry.init(role);
        }
        return .{
            .issue_number = issue_number,
            .entries = entries,
            .started_at = std.time.timestamp(),
        };
    }

    pub fn getEntry(self: *CostTracker, role: AgentRole) *CostEntry {
        const idx: usize = switch (role) {
            .planner => 0,
            .coder => 1,
            .reviewer => 2,
            .tester => 3,
            .integrator => 4,
        };
        return &self.entries[idx];
    }

    pub fn addTokens(self: *CostTracker, role: AgentRole, model: []const u8, tokens_in: u64, tokens_out: u64) void {
        var entry = self.getEntry(role);
        entry.setModel(model);
        entry.addTokens(tokens_in, tokens_out);
    }

    pub fn totalUSD(self: *const CostTracker) f64 {
        var total: f64 = 0.0;
        for (self.entries) |entry| {
            total += entry.usd;
        }
        return total;
    }

    pub fn totalTokensIn(self: *const CostTracker) u64 {
        var total: u64 = 0;
        for (self.entries) |entry| {
            total += entry.tokens_in;
        }
        return total;
    }

    pub fn totalTokensOut(self: *const CostTracker) u64 {
        var total: u64 = 0;
        for (self.entries) |entry| {
            total += entry.tokens_out;
        }
        return total;
    }

    /// Write cost summary to .trinity/handoff/issue-{N}/cost_summary.json
    pub fn writeSummary(self: *const CostTracker) !void {
        const handoff_mod = @import("handoff.zig");
        try handoff_mod.ensureHandoffDir(self.issue_number);

        var dir_buf: [256]u8 = undefined;
        const dir = handoff_mod.getHandoffDir(&dir_buf, self.issue_number);

        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/cost_summary.json", .{dir}) catch return error.NameTooLong;

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const w = file.writer();

        try w.writeAll("{\n");
        try std.fmt.format(w, "  \"issue_number\": {d},\n", .{self.issue_number});
        try std.fmt.format(w, "  \"total_tokens_in\": {d},\n", .{self.totalTokensIn()});
        try std.fmt.format(w, "  \"total_tokens_out\": {d},\n", .{self.totalTokensOut()});
        try std.fmt.format(w, "  \"total_usd\": {d:.6},\n", .{self.totalUSD()});
        try std.fmt.format(w, "  \"timestamp\": {d},\n", .{std.time.timestamp()});
        try w.writeAll("  \"roles\": [\n");

        for (self.entries, 0..) |entry, i| {
            try w.writeAll("    {");
            try std.fmt.format(w, "\"role\": \"{s}\", ", .{entry.role.getName()});
            try std.fmt.format(w, "\"model\": \"{s}\", ", .{entry.getModel()});
            try std.fmt.format(w, "\"tokens_in\": {d}, ", .{entry.tokens_in});
            try std.fmt.format(w, "\"tokens_out\": {d}, ", .{entry.tokens_out});
            try std.fmt.format(w, "\"usd\": {d:.6}", .{entry.usd});
            try w.writeByte('}');
            if (i < self.entries.len - 1) {
                try w.writeAll(",\n");
            } else {
                try w.writeByte('\n');
            }
        }

        try w.writeAll("  ]\n}\n");
    }

    /// Print cost table to stdout
    pub fn printTable(self: *const CostTracker) void {
        const RESET = "\x1b[0m";
        const GREEN = "\x1b[38;2;0;229;153m";
        const GOLDEN = "\x1b[38;2;255;215;0m";
        const CYAN = "\x1b[38;2;0;255;255m";
        const GRAY = "\x1b[38;2;156;156;160m";
        const WHITE = "\x1b[38;2;255;255;255m";

        std.debug.print("\n{s}Cost Summary — Issue #{d}{s}\n", .{ GOLDEN, self.issue_number, RESET });
        std.debug.print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n", .{ GRAY, RESET });
        std.debug.print("  {s}Role          Model       Tokens In   Tokens Out  USD{s}\n", .{ CYAN, RESET });
        std.debug.print("{s}  ──────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });

        for (self.entries) |entry| {
            if (entry.tokens_in == 0 and entry.tokens_out == 0) continue;

            std.debug.print("  {s}{s:<12}{s}  {s:<10}  {s}{d:<10}{s}  {s}{d:<10}{s}  {s}${d:.4}{s}\n", .{
                WHITE,        entry.role.getName(),
                RESET,        entry.getModel(),
                GRAY,         entry.tokens_in,
                RESET,        GRAY,
                entry.tokens_out, RESET,
                GREEN,        entry.usd,
                RESET,
            });
        }

        std.debug.print("{s}  ──────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });
        std.debug.print("  {s}TOTAL{s}                     {d:<10}  {d:<10}  {s}${d:.4}{s}\n\n", .{
            WHITE,                       RESET,
            self.totalTokensIn(),        self.totalTokensOut(),
            GREEN,                       self.totalUSD(),
            RESET,
        });
    }
};

// =============================================================================
// READ COST FROM HANDOFF DIRECTORY
// =============================================================================

/// Read cost summary from .trinity/handoff/issue-{N}/cost_summary.json
/// Returns null if file doesn't exist.
pub fn readCostSummary(allocator: std.mem.Allocator, issue_number: u32) ?CostTracker {
    const handoff_mod = @import("handoff.zig");
    var dir_buf: [256]u8 = undefined;
    const dir = handoff_mod.getHandoffDir(&dir_buf, issue_number);

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/cost_summary.json", .{dir}) catch return null;

    const file = std.fs.cwd().openFile(path, .{}) catch return null;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 64 * 1024) catch return null;
    defer allocator.free(content);

    // Parse and reconstruct tracker (basic — check file exists as confirmation)
    return CostTracker.init(issue_number);
}

// =============================================================================
// TESTS
// =============================================================================

test "CostEntry basic" {
    var entry = CostEntry.init(.planner);
    entry.setModel("glm-5");
    entry.addTokens(1000, 500);

    try std.testing.expectEqual(@as(u64, 1000), entry.tokens_in);
    try std.testing.expectEqual(@as(u64, 500), entry.tokens_out);
    // glm-5: 1000/1000*0.001 + 500/1000*0.002 = 0.001 + 0.001 = 0.002
    try std.testing.expectApproxEqAbs(@as(f64, 0.002), entry.usd, 0.0001);
}

test "CostTracker aggregate" {
    var tracker = CostTracker.init(42);
    tracker.addTokens(.planner, "glm-5", 1000, 500);
    tracker.addTokens(.coder, "glm-5", 2000, 1000);

    try std.testing.expectEqual(@as(u64, 3000), tracker.totalTokensIn());
    try std.testing.expectEqual(@as(u64, 1500), tracker.totalTokensOut());
    try std.testing.expect(tracker.totalUSD() > 0.0);
}

test "getRates known models" {
    const glm = getRates("glm-5");
    try std.testing.expectApproxEqAbs(@as(f64, 0.001), glm.input_per_1k, 0.0001);

    const sonnet = getRates("claude-sonnet-4-20250514");
    try std.testing.expectApproxEqAbs(@as(f64, 0.003), sonnet.input_per_1k, 0.0001);

    const unknown = getRates("some-model");
    try std.testing.expectApproxEqAbs(@as(f64, 0.001), unknown.input_per_1k, 0.0001);
}
