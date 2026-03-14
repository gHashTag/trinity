// @origin(spec:tri_self.tri) @regen(manual-impl)
// @origin(manual)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI SELF — Dogfooding Self-Check Quality Gates
// ═══════════════════════════════════════════════════════════════════════════════
//
// `tri self test` runs 5 quality gates on the Trinity repo itself.
// If an action can't be done through `tri`, that's a bug in `tri`.
//
// Commands:
//   tri self test [--ci]   — run all 5 quality gates
//   tri self health        — alias for tri doctor report
//   tri self benchmark     — performance benchmark (stub)
//   tri self help          — show sub-commands
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const tri_doctor = @import("tri_doctor.zig");
const toxic_verdict = @import("toxic_verdict.zig");
const experience_hooks = @import("experience_hooks.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

const Gate = struct {
    name: []const u8 = "",
    success: bool = false,
    detail: [256]u8 = [_]u8{0} ** 256,
    detail_len: usize = 0,

    fn setDetail(self: *Gate, msg: []const u8) void {
        const len = @min(msg.len, self.detail.len);
        @memcpy(self.detail[0..len], msg[0..len]);
        self.detail_len = len;
    }

    fn getDetail(self: *const Gate) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runSelfCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try runSelfTest(allocator, args);
        return;
    }

    const cmd = args[0];
    if (std.mem.eql(u8, cmd, "test")) {
        const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};
        try runSelfTest(allocator, sub_args);
    } else if (std.mem.eql(u8, cmd, "health")) {
        try tri_doctor.runReport(allocator);
    } else if (std.mem.eql(u8, cmd, "benchmark")) {
        printBenchmarkStub();
    } else if (std.mem.eql(u8, cmd, "help")) {
        printSelfHelp();
    } else {
        print("{s}Unknown self command: {s}{s}\n", .{ RED, cmd, RESET });
        printSelfHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELF TEST — 5 quality gates
// ═══════════════════════════════════════════════════════════════════════════════

fn runSelfTest(allocator: Allocator, args: []const []const u8) !void {
    var ci_mode = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--ci")) ci_mode = true;
    }

    print("\n{s}{s}🔬 TRI SELF TEST — Dogfooding Quality Gates{s}\n", .{ BOLD, CYAN, RESET });
    print("{s}════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var gates: [5]Gate = .{
        .{ .name = "BUILD" },
        .{ .name = "TEST" },
        .{ .name = "FORMAT" },
        .{ .name = "HEALTH" },
        .{ .name = "VERDICT" },
    };

    // Gate 1: BUILD
    print("{s}[1/5]{s} BUILD  — zig build ... ", .{ DIM, RESET });
    gates[0] = runChildGate("BUILD", &.{ "zig", "build" }, allocator);
    printGateResult(&gates[0]);

    // Gate 2: TEST
    print("{s}[2/5]{s} TEST   — zig build test ... ", .{ DIM, RESET });
    gates[1] = runChildGate("TEST", &.{ "zig", "build", "test" }, allocator);
    printGateResult(&gates[1]);

    // Gate 3: FORMAT
    print("{s}[3/5]{s} FORMAT — zig fmt --check src/tri/ tools/mcp/ src/hslm/ ... ", .{ DIM, RESET });
    gates[2] = runChildGate("FORMAT", &.{ "zig", "fmt", "--check", "src/tri/", "tools/mcp/", "src/hslm/" }, allocator);
    printGateResult(&gates[2]);

    // Gate 4: HEALTH
    print("{s}[4/5]{s} HEALTH — doctor scan (threshold ≥ 70) ... ", .{ DIM, RESET });
    gates[3] = runHealthGate(allocator);
    printGateResult(&gates[3]);

    // Gate 5: VERDICT
    print("{s}[5/5]{s} VERDICT — toxic verdict (threshold ≥ SOLID) ... ", .{ DIM, RESET });
    gates[4] = runVerdictGate(allocator);
    printGateResult(&gates[4]);

    // Summary
    printSelfSummary(&gates);

    // Save experience
    var passed: u8 = 0;
    for (&gates) |*g| {
        if (g.success) passed += 1;
    }
    var detail_buf: [64]u8 = undefined;
    const detail = std.fmt.bufPrint(&detail_buf, "{d}/5 gates passed", .{passed}) catch "self test";
    experience_hooks.autoSaveExperience("self test", detail, passed == 5);

    // CI mode: exit with failure count
    if (ci_mode and passed < 5) {
        std.process.exit(5 - passed);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GATE IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn runChildGate(name: []const u8, argv: []const []const u8, allocator: Allocator) Gate {
    var gate = Gate{ .name = name };

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 128 * 1024,
    }) catch |err| {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "failed to spawn: {s}", .{@errorName(err)}) catch "spawn error";
        gate.setDetail(msg);
        return gate;
    };
    allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const code: u8 = switch (result.term) {
        .Exited => |c| c,
        else => 1,
    };

    gate.success = (code == 0);
    if (code == 0) {
        gate.setDetail("exit 0");
    } else {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "exit {d}", .{code}) catch "non-zero exit";
        gate.setDetail(msg);
    }
    return gate;
}

fn runHealthGate(allocator: Allocator) Gate {
    var gate = Gate{ .name = "HEALTH" };

    const scan = tri_doctor.performScan(allocator) catch |err| {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "scan failed: {s}", .{@errorName(err)}) catch "scan error";
        gate.setDetail(msg);
        return gate;
    };

    const health = tri_doctor.computeHealth(scan);
    gate.success = (health.total >= 70);

    var buf: [128]u8 = undefined;
    const grade_str: []const u8 = switch (health.grade) {
        .healthy => "HEALTHY",
        .recovering => "RECOVERING",
        .infected => "INFECTED",
        .critical => "CRITICAL",
    };
    const msg = std.fmt.bufPrint(&buf, "score={d}/100 ({s})", .{ health.total, grade_str }) catch "health done";
    gate.setDetail(msg);
    return gate;
}

fn runVerdictGate(allocator: Allocator) Gate {
    var gate = Gate{ .name = "VERDICT" };

    const input = toxic_verdict.collectInputs(allocator);
    const score = toxic_verdict.computeScore(input);
    const level = toxic_verdict.classifyLevel(score.total);

    const level_ok = switch (level) {
        .legendary, .solid => true,
        .mediocre, .garbage, .disaster => false,
    };

    gate.success = level_ok;

    var buf: [128]u8 = undefined;
    const total_int: u32 = @intFromFloat(@min(100.0, @max(0.0, score.total)));
    const msg = std.fmt.bufPrint(&buf, "score={d}/100 ({s} {s})", .{ total_int, level.emoji(), level.label() }) catch "verdict done";
    gate.setDetail(msg);
    return gate;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OUTPUT
// ═══════════════════════════════════════════════════════════════════════════════

fn printGateResult(gate: *const Gate) void {
    if (gate.success) {
        print("{s}✅ PASS{s}", .{ GREEN, RESET });
    } else {
        print("{s}❌ FAIL{s}", .{ RED, RESET });
    }
    const detail = gate.getDetail();
    if (detail.len > 0) {
        print(" {s}({s}){s}", .{ DIM, detail, RESET });
    }
    print("\n", .{});
}

fn printSelfSummary(gates: *const [5]Gate) void {
    var passed: u8 = 0;
    var failed: u8 = 0;
    for (gates) |g| {
        if (g.success) {
            passed += 1;
        } else {
            failed += 1;
        }
    }

    print("\n{s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    if (passed == 5) {
        print("{s}{s}🏆 ALL 5 GATES PASSED — Trinity is self-consistent{s}\n", .{ BOLD, GREEN, RESET });
    } else {
        print("{s}{s}📊 RESULT: {d}/5 passed, {d}/5 failed{s}\n", .{ BOLD, YELLOW, passed, failed, RESET });
        print("\n{s}Failed gates:{s}\n", .{ RED, RESET });
        for (gates) |g| {
            if (!g.success) {
                print("  ❌ {s} — {s}\n", .{ g.name, g.getDetail() });
            }
        }
    }
    print("\n", .{});
}

fn printSelfHelp() void {
    print("\n{s}{s}TRI SELF — Dogfooding Self-Check{s}\n\n", .{ BOLD, CYAN, RESET });
    print("  {s}tri self test [--ci]{s}   Run 5 quality gates\n", .{ GREEN, RESET });
    print("  {s}tri self health{s}        Doctor health report\n", .{ GREEN, RESET });
    print("  {s}tri self benchmark{s}     Performance benchmark (stub)\n", .{ GREEN, RESET });
    print("  {s}tri self help{s}          This help\n\n", .{ GREEN, RESET });
    print("{s}Gates:{s}\n", .{ DIM, RESET });
    print("  BUILD    zig build               exit 0\n", .{});
    print("  TEST     zig build test           exit 0\n", .{});
    print("  FORMAT   zig fmt --check (core dirs)  exit 0\n", .{});
    print("  HEALTH   doctor scan → score      ≥ 70\n", .{});
    print("  VERDICT  toxic verdict → level    ≥ SOLID\n", .{});
    print("\n{s}--ci{s}  exit non-zero if any gate fails\n\n", .{ DIM, RESET });
}

fn printBenchmarkStub() void {
    print("\n{s}{s}🏎️  TRI SELF BENCHMARK{s}\n\n", .{ BOLD, CYAN, RESET });
    print("{s}Not yet implemented. Coming soon:{s}\n", .{ DIM, RESET });
    print("  • Build time measurement\n", .{});
    print("  • Test suite duration\n", .{});
    print("  • MCP server startup latency\n", .{});
    print("  • CLI command response times\n\n", .{});
}
