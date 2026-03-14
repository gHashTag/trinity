// ═══════════════════════════════════════════════════════════════════════════════
// TRI CHIMERA — Fused Multi-Step Command Sequences
// ═══════════════════════════════════════════════════════════════════════════════
//
// Chimera commands fuse common multi-step sequences into single invocations.
// Pattern: MACRO paper — agents auto-discover repeated sequences → composite tools.
//
// Commands:
//   tri chimera farm-cycle     — status → idle → recycle → evolve
//   tri chimera train-cycle    — status → loss → diagnose → chart → leaderboard
//   tri chimera deploy-full    — commit → push → deploy → verify → notify
//   tri chimera doctor-full    — scan → mark → report → heal
//   tri chimera research-deep  — query → recall → idempotency → duplication
//   tri chimera help           — show all chimeras
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
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

const ChimeraStep = struct {
    name: []const u8 = "",
    success: bool = false,
    detail: [256]u8 = [_]u8{0} ** 256,
    detail_len: usize = 0,

    fn setDetail(self: *ChimeraStep, msg: []const u8) void {
        const len = @min(msg.len, self.detail.len);
        @memcpy(self.detail[0..len], msg[0..len]);
        self.detail_len = len;
    }

    fn getDetail(self: *const ChimeraStep) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runChimeraCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "farm-cycle")) {
        try runFarmCycle(allocator);
    } else if (std.mem.eql(u8, subcmd, "train-cycle")) {
        try runTrainCycle(allocator);
    } else if (std.mem.eql(u8, subcmd, "deploy-full")) {
        try runDeployFull(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
    } else if (std.mem.eql(u8, subcmd, "doctor-full")) {
        try runDoctorFull(allocator);
    } else if (std.mem.eql(u8, subcmd, "research-deep")) {
        try runResearchDeep(allocator, if (args.len > 1) args[1..] else &[_][]const u8{});
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printChimeraHelp();
    } else {
        print("{s}Unknown chimera: {s}{s}\n", .{ RED, subcmd, RESET });
        printChimeraHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FARM CYCLE — status → idle → recycle → evolve
// ═══════════════════════════════════════════════════════════════════════════════

fn runFarmCycle(allocator: Allocator) !void {
    const tri_farm = @import("tri_farm.zig");
    const tri_farm_evolve = @import("tri_farm_evolve.zig");

    printChimeraHeader("FARM CYCLE", "status → idle → recycle → evolve", 4);

    var steps: [4]ChimeraStep = [_]ChimeraStep{.{}} ** 4;

    // Step 1: Farm status
    printStepStart(1, 4, "Farm status");
    steps[0].name = "farm status";
    tri_farm.runFarmStatus(allocator, false) catch |err| {
        steps[0].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[0].detail_len == 0) {
        steps[0].success = true;
        steps[0].setDetail("OK");
        printStepEnd(true);
    }

    // Step 2: Farm idle
    printStepStart(2, 4, "Find idle services");
    steps[1].name = "farm idle";
    tri_farm.runFarmStatus(allocator, true) catch |err| {
        steps[1].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[1].detail_len == 0) {
        steps[1].success = true;
        steps[1].setDetail("OK");
        printStepEnd(true);
    }

    // Step 3: Farm recycle
    printStepStart(3, 4, "Recycle idle services");
    steps[2].name = "farm recycle";
    tri_farm.runFarmRecycle(allocator, &[_][]const u8{}) catch |err| {
        steps[2].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[2].detail_len == 0) {
        steps[2].success = true;
        steps[2].setDetail("OK");
        printStepEnd(true);
    }

    // Step 4: Farm evolve
    printStepStart(4, 4, "Evolve population");
    steps[3].name = "farm evolve";
    tri_farm_evolve.runEvolveCommand(allocator, &[_][]const u8{}) catch |err| {
        steps[3].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[3].detail_len == 0) {
        steps[3].success = true;
        steps[3].setDetail("OK");
        printStepEnd(true);
    }

    printChimeraSummary("FARM CYCLE", &steps);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRAIN CYCLE — status → loss → diagnose → chart → leaderboard
// ═══════════════════════════════════════════════════════════════════════════════

fn runTrainCycle(allocator: Allocator) !void {
    const tri_train = @import("tri_train.zig");
    const tri_experiment = @import("tri_experiment.zig");

    printChimeraHeader("TRAIN CYCLE", "status → loss → diagnose → chart → leaderboard", 5);

    var steps: [5]ChimeraStep = [_]ChimeraStep{.{}} ** 5;

    // Step 1: Training status
    printStepStart(1, 5, "Training status");
    steps[0].name = "train status";
    tri_train.runTrainCommand(allocator, &[_][]const u8{"status"}) catch |err| {
        steps[0].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[0].detail_len == 0) {
        steps[0].success = true;
        steps[0].setDetail("OK");
        printStepEnd(true);
    }

    // Step 2: Loss curve
    printStepStart(2, 5, "Loss curve");
    steps[1].name = "train loss";
    tri_train.runTrainCommand(allocator, &[_][]const u8{"loss"}) catch |err| {
        steps[1].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[1].detail_len == 0) {
        steps[1].success = true;
        steps[1].setDetail("OK");
        printStepEnd(true);
    }

    // Step 3: Diagnose
    printStepStart(3, 5, "Diagnose issues");
    steps[2].name = "train diagnose";
    tri_train.runTrainCommand(allocator, &[_][]const u8{"diagnose"}) catch |err| {
        steps[2].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[2].detail_len == 0) {
        steps[2].success = true;
        steps[2].setDetail("OK");
        printStepEnd(true);
    }

    // Step 4: Experiment chart
    printStepStart(4, 5, "Experiment chart");
    steps[3].name = "experiment chart";
    tri_experiment.runExperimentCommand(allocator, &[_][]const u8{"chart"}) catch |err| {
        steps[3].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[3].detail_len == 0) {
        steps[3].success = true;
        steps[3].setDetail("OK");
        printStepEnd(true);
    }

    // Step 5: Leaderboard
    printStepStart(5, 5, "Leaderboard");
    steps[4].name = "experiment list";
    tri_experiment.runExperimentCommand(allocator, &[_][]const u8{"list"}) catch |err| {
        steps[4].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[4].detail_len == 0) {
        steps[4].success = true;
        steps[4].setDetail("OK");
        printStepEnd(true);
    }

    printChimeraSummary("TRAIN CYCLE", &steps);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPLOY FULL — commit → push → deploy → verify → notify
// ═══════════════════════════════════════════════════════════════════════════════

fn runDeployFull(allocator: Allocator, args: []const []const u8) !void {
    const commands = @import("tri_commands.zig");

    printChimeraHeader("DEPLOY FULL", "commit → push → deploy → verify → notify", 5);

    var steps: [5]ChimeraStep = [_]ChimeraStep{.{}} ** 5;

    // Step 1: Git commit
    printStepStart(1, 5, "Git commit");
    steps[0].name = "git commit";
    commands.runGitCommand(allocator, "commit", args) catch |err| {
        steps[0].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[0].detail_len == 0) {
        steps[0].success = true;
        steps[0].setDetail("OK");
        printStepEnd(true);
    }

    // Step 2: Git push
    printStepStart(2, 5, "Git push");
    steps[1].name = "git push";
    commands.runGitCommand(allocator, "push", &[_][]const u8{}) catch |err| {
        steps[1].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[1].detail_len == 0) {
        steps[1].success = true;
        steps[1].setDetail("OK");
        printStepEnd(true);
    }

    // Step 3: Deploy push
    printStepStart(3, 5, "Deploy push");
    steps[2].name = "deploy push";
    commands.runDeployCommand(allocator, "push", &[_][]const u8{}) catch |err| {
        steps[2].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[2].detail_len == 0) {
        steps[2].success = true;
        steps[2].setDetail("OK");
        printStepEnd(true);
    }

    // Step 4: Deploy status (verify)
    printStepStart(4, 5, "Deploy verify");
    steps[3].name = "deploy status";
    commands.runDeployCommand(allocator, "status", &[_][]const u8{}) catch |err| {
        steps[3].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[3].detail_len == 0) {
        steps[3].success = true;
        steps[3].setDetail("OK");
        printStepEnd(true);
    }

    // Step 5: Notify
    printStepStart(5, 5, "Telegram notify");
    steps[4].name = "notify";
    commands.runNotifyCommand(allocator, "Deploy complete via chimera", null, false, null) catch |err| {
        steps[4].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[4].detail_len == 0) {
        steps[4].success = true;
        steps[4].setDetail("OK");
        printStepEnd(true);
    }

    printChimeraSummary("DEPLOY FULL", &steps);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOCTOR FULL — scan → mark → report → heal
// ═══════════════════════════════════════════════════════════════════════════════

fn runDoctorFull(allocator: Allocator) !void {
    const commands = @import("tri_commands.zig");

    printChimeraHeader("DOCTOR FULL", "scan → mark → report → heal", 4);

    var steps: [4]ChimeraStep = [_]ChimeraStep{.{}} ** 4;

    const doctor_cmds = [_]struct { name: []const u8, arg: []const u8 }{
        .{ .name = "doctor scan", .arg = "scan" },
        .{ .name = "doctor mark", .arg = "mark" },
        .{ .name = "doctor report", .arg = "report" },
        .{ .name = "doctor heal", .arg = "heal" },
    };

    for (doctor_cmds, 0..) |dc, i| {
        printStepStart(i + 1, 4, dc.name);
        steps[i].name = dc.name;
        commands.runDoctorCommand(allocator, &[_][]const u8{dc.arg}) catch |err| {
            steps[i].setDetail(@errorName(err));
            printStepEnd(false);
        };
        if (steps[i].detail_len == 0) {
            steps[i].success = true;
            steps[i].setDetail("OK");
            printStepEnd(true);
        }
    }

    printChimeraSummary("DOCTOR FULL", &steps);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESEARCH DEEP — query → recall → idempotency → dedup
// ═══════════════════════════════════════════════════════════════════════════════

fn runResearchDeep(allocator: Allocator, args: []const []const u8) !void {
    const tri_research = @import("tri_research.zig");
    const tri_experience = @import("tri_experience.zig");

    printChimeraHeader("RESEARCH DEEP", "query → recall → cross-ref → dedup", 4);

    var steps: [4]ChimeraStep = [_]ChimeraStep{.{}} ** 4;

    // Step 1: Research query
    printStepStart(1, 4, "Research query");
    steps[0].name = "research query";
    tri_research.runResearchCommand(allocator, args) catch |err| {
        steps[0].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[0].detail_len == 0) {
        steps[0].success = true;
        steps[0].setDetail("OK");
        printStepEnd(true);
    }

    // Step 2: Experience recall
    printStepStart(2, 4, "Experience recall");
    steps[1].name = "experience recall";
    const recall_query = if (args.len > 0) args[0] else "research";
    tri_experience.runExperienceCommand(allocator, &[_][]const u8{ "recall", "--task", recall_query }) catch |err| {
        steps[1].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[1].detail_len == 0) {
        steps[1].success = true;
        steps[1].setDetail("OK");
        printStepEnd(true);
    }

    // Step 3: Research idempotency check
    printStepStart(3, 4, "Idempotency check");
    steps[2].name = "research idempotency";
    tri_research.runResearchCommand(allocator, &[_][]const u8{"idempotency"}) catch |err| {
        steps[2].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[2].detail_len == 0) {
        steps[2].success = true;
        steps[2].setDetail("OK");
        printStepEnd(true);
    }

    // Step 4: Deduplication
    printStepStart(4, 4, "Deduplication");
    steps[3].name = "research dedup";
    tri_research.runResearchCommand(allocator, &[_][]const u8{"dedup"}) catch |err| {
        steps[3].setDetail(@errorName(err));
        printStepEnd(false);
    };
    if (steps[3].detail_len == 0) {
        steps[3].success = true;
        steps[3].setDetail("OK");
        printStepEnd(true);
    }

    printChimeraSummary("RESEARCH DEEP", &steps);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn printChimeraHeader(name: []const u8, steps_desc: []const u8, total: usize) void {
    print("\n{s}🧬 CHIMERA: {s}{s}\n", .{ BOLD, name, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}Steps: {s} ({d} total){s}\n\n", .{ DIM, steps_desc, total, RESET });
}

fn printStepStart(step: usize, total: usize, name: []const u8) void {
    print("  {s}[{d}/{d}]{s} {s}...", .{ CYAN, step, total, RESET, name });
}

fn printStepEnd(success: bool) void {
    if (success) {
        print(" {s}OK{s}\n", .{ GREEN, RESET });
    } else {
        print(" {s}FAIL{s}\n", .{ RED, RESET });
    }
}

fn printChimeraSummary(name: []const u8, steps: []const ChimeraStep) void {
    var ok: usize = 0;
    var fail: usize = 0;
    for (steps) |s| {
        if (s.success) ok += 1 else fail += 1;
    }

    print("\n  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}{s} SUMMARY{s}\n", .{ BOLD, name, RESET });
    print("  {s}════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Steps:  {s}{d} OK{s} / {s}{d} FAIL{s}\n", .{
        GREEN, ok, RESET, if (fail > 0) RED else DIM, fail, RESET,
    });

    const verdict: []const u8 = if (fail == 0) "PASS" else "PARTIAL";
    const verdict_color = if (fail == 0) GREEN else YELLOW;
    print("  Result: {s}{s}{s}\n\n", .{ verdict_color, verdict, RESET });

    // Auto-save experience
    experience_hooks.autoSaveExperience(name, verdict, fail == 0);
}

fn printChimeraHelp() void {
    print("\n{s}🧬 CHIMERA — Fused Multi-Step Commands{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}farm-cycle{s}     status → idle → recycle → evolve\n", .{ CYAN, RESET });
    print("  {s}train-cycle{s}    status → loss → diagnose → chart → leaderboard\n", .{ CYAN, RESET });
    print("  {s}deploy-full{s}    commit → push → deploy → verify → notify\n", .{ CYAN, RESET });
    print("  {s}doctor-full{s}    scan → mark → report → heal\n", .{ CYAN, RESET });
    print("  {s}research-deep{s}  query → recall → idempotency → dedup\n", .{ CYAN, RESET });
    print("\n  Usage: {s}tri chimera <name>{s}\n\n", .{ BOLD, RESET });
}
