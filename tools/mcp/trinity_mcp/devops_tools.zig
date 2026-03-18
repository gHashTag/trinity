// @origin(manual) @regen(pending)
//! DEVOPS TOOLS — MCP Tool Module for DevOps/Utility CLI Groups
//! Catch-all for patent, depin, research, experiment, chimera, ouroboros,
//! self, context, faculty, mu, zenodo, analyze, clean, fmt, stats, lint,
//! search, metrics, trace, eval.
//! Shells out to `tri <group> <subcommand>` CLI commands.
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const MAX_OUTPUT = 8192;

// ═══════════════════════════════════════════════════════════════════════════════
// PATENT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn patentStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "patent", "status" });
}

pub fn patentAnalysis(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "patent", "analysis" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn depinStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "depin", "status" });
}

pub fn depinNodes(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "depin", "nodes" });
}

pub fn depinFitness(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "depin", "fitness" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESEARCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn researchQuery(buf: *[MAX_OUTPUT]u8, query: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "research", query });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPERIMENT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn experimentList(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "experiment", "list" });
}

pub fn experimentCompare(buf: *[MAX_OUTPUT]u8, a: []const u8, b: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "experiment", "compare", a, b });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHIMERA
// ═══════════════════════════════════════════════════════════════════════════════

pub fn chimeraRun(buf: *[MAX_OUTPUT]u8, name: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "chimera", name });
}

// ═══════════════════════════════════════════════════════════════════════════════
// OUROBOROS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn ouroborosStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "ouroboros", "status" });
}

pub fn ouroborosRun(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "ouroboros", "run" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SELF
// ═══════════════════════════════════════════════════════════════════════════════

pub fn selfTest(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "self", "test" });
}

pub fn selfHealth(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "self", "health" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn contextInfo(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "context", "info" });
}

pub fn contextLoad(buf: *[MAX_OUTPUT]u8, path: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "context", "load", path });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FACULTY / MU
// ═══════════════════════════════════════════════════════════════════════════════

pub fn facultyStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"faculty"});
}

pub fn muStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "mu", "status" });
}

pub fn muPatterns(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "mu", "patterns" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// ZENODO
// ═══════════════════════════════════════════════════════════════════════════════

pub fn zenodoStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "zenodo", "status" });
}

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY COMMANDS (single-word tri commands)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn analyze(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"analyze"});
}

pub fn clean(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"clean"});
}

pub fn fmt(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"fmt"});
}

pub fn stats(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"stats"});
}

pub fn lint(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"lint"});
}

pub fn search(buf: *[MAX_OUTPUT]u8, query: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "search", query });
}

pub fn metrics(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"metrics"});
}

pub fn trace(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"trace"});
}

pub fn eval(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{"eval"});
}

// ═══════════════════════════════════════════════════════════════════════════════
// FARM (additional commands not in cloud_tools)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn farmStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "status" });
}

pub fn farmIdle(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "idle" });
}

pub fn farmRecycle(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "recycle" });
}

pub fn farmFill(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "fill" });
}

pub fn farmAccounts(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "status" });
}

pub fn farmWaveSpawn(buf: *[MAX_OUTPUT]u8, account: []const u8, count: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "farm", "fill", "--account", account, "--count", count });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FPGA (additional commands not in fpga_tools)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn fpgaSynth(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "fpga", "synth" });
}

pub fn fpgaStatus(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "fpga", "status" });
}

pub fn fpgaBuild(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "fpga", "build" });
}

pub fn fpgaVerify(buf: *[MAX_OUTPUT]u8) []const u8 {
    return runTriCmd(buf, &.{ "fpga", "verify" });
}

pub fn fpgaFlash(buf: *[MAX_OUTPUT]u8, bitstream: []const u8) []const u8 {
    return runTriCmd(buf, &.{ "fpga", "flash", bitstream });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL — generic tri command runner
// ═══════════════════════════════════════════════════════════════════════════════

fn runTriCmd(buf: *[MAX_OUTPUT]u8, args: []const []const u8) []const u8 {
    var argv: [16][]const u8 = undefined;
    argv[0] = TRI_PATH;
    const n = @min(args.len, 15);
    for (0..n) |i| {
        argv[1 + i] = args[i];
    }

    var child = std.process.Child.init(argv[0 .. 1 + n], std.heap.page_allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    child.spawn() catch |err| {
        return copyToBuf(buf, switch (err) {
            error.FileNotFound => "Error: tri binary not found (run zig build)",
            else => "Error: Failed to spawn tri process",
        });
    };
    defer {
        _ = child.wait() catch |err| {
            std.log.warn("devops_tools: child.wait() failed: {}", .{err});
        };
    }

    const stdout = child.stdout.?.readToEndAlloc(std.heap.page_allocator, MAX_OUTPUT) catch {
        return copyToBuf(buf, "Error: Failed to read tri output");
    };
    defer std.heap.page_allocator.free(stdout);

    if (stdout.len == 0) {
        return copyToBuf(buf, "OK (no output — check stderr)");
    }

    const len = @min(stdout.len, MAX_OUTPUT);
    @memcpy(buf[0..len], stdout[0..len]);
    return buf[0..len];
}

fn copyToBuf(buf: *[MAX_OUTPUT]u8, msg: []const u8) []const u8 {
    const len = @min(msg.len, MAX_OUTPUT);
    @memcpy(buf[0..len], msg[0..len]);
    return buf[0..len];
}

const TRI_PATH = "zig-out/bin/tri";
