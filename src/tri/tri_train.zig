// @origin(spec:tri_train.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI TRAIN — HSLM Training Monitor CLI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri train status              Live dashboard
//   tri train status --json       Machine-readable JSON
//   tri train loss <dir>          Parse checkpoint loss curve
//   tri train diagnose <dir>      Auto-diagnose anomalies
//   tri train compare <d1> <d2>   Side-by-side comparison
//   tri train checkpoint list <d> List checkpoints with metrics
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("train_types.zig");
const diag = @import("train_diagnostics.zig");
const CheckpointInfo = types.CheckpointInfo;
const TrainLogEntry = types.TrainLogEntry;
const Sacred = types.Sacred;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";
const GOLDEN = "\x1b[38;5;220m";

const DEFAULT_CKPT_DIR = "data/checkpoints";
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTrainCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        runStatus(false);
        return;
    }

    const subcmd = args[0];
    const sub_args = args[1..];

    // Check for --host railway flag
    const is_railway = hasFlag(sub_args, "--host", "railway");

    if (std.mem.eql(u8, subcmd, "status")) {
        if (is_railway) return runRemoteStatus(allocator);
        const json_mode = for (sub_args) |a| {
            if (std.mem.eql(u8, a, "--json")) break true;
        } else false;
        runStatus(json_mode);
    } else if (std.mem.eql(u8, subcmd, "start")) {
        if (is_railway) return runRemoteStart(allocator, sub_args);
        return runLocalStart(allocator, sub_args);
    } else if (std.mem.eql(u8, subcmd, "logs")) {
        if (is_railway) return runRemoteLogs(allocator);
        print("Usage: tri train logs --host railway\n", .{});
    } else if (std.mem.eql(u8, subcmd, "loss")) {
        const dir = if (sub_args.len > 0 and !std.mem.startsWith(u8, sub_args[0], "--")) sub_args[0] else DEFAULT_CKPT_DIR;
        runLossCurve(dir);
    } else if (std.mem.eql(u8, subcmd, "diagnose")) {
        const dir = if (sub_args.len > 0 and !std.mem.startsWith(u8, sub_args[0], "--")) sub_args[0] else DEFAULT_CKPT_DIR;
        runDiagnose(dir);
    } else if (std.mem.eql(u8, subcmd, "compare")) {
        if (sub_args.len < 2) {
            print("Usage: tri train compare <dir1> <dir2>\n", .{});
            return;
        }
        runCompare(sub_args[0], sub_args[1]);
    } else if (std.mem.eql(u8, subcmd, "checkpoint")) {
        if (sub_args.len > 0 and std.mem.eql(u8, sub_args[0], "list")) {
            const dir = if (sub_args.len > 1) sub_args[1] else DEFAULT_CKPT_DIR;
            runCheckpointList(dir);
        } else {
            print("Usage: tri train checkpoint list [dir]\n", .{});
        }
    } else if (std.mem.eql(u8, subcmd, "dashboard")) {
        return runDashboard(allocator);
    } else {
        print("Unknown subcommand: {s}\n", .{subcmd});
        print("Usage: tri train <status|start|logs|loss|diagnose|compare|checkpoint> [args]\n", .{});
        print("  --host railway       Run on Railway cloud server\n", .{});
        print("  --optimizer <type>   adamw|lamb (default: adamw)\n", .{});
        print("  --batch <n>          Batch size (default: 64)\n", .{});
        print("  --grad-accum <n>     Gradient accumulation steps (default: 1)\n", .{});
        print("  --context <n>        Context window size (default: 81)\n", .{});
        print("  --ste <mode>         none|vanilla|twn|progressive\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REMOTE TRAINING (Railway SSH)
// ═══════════════════════════════════════════════════════════════════════════════

const railway_ssh = @import("railway_ssh.zig");

/// tri train status --host railway — Show remote training progress via tmux capture
fn runRemoteStatus(allocator: std.mem.Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    print("{s}{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}{s} HSLM TRAINING — Railway Cloud{s}\n", .{ GOLDEN, BOLD, RESET });
    print("{s}{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, BOLD, RESET });

    // Check if training tmux session exists and capture output
    const output = ssh.tmuxCapture(allocator, "train", 20) catch |err| {
        print("{s}No active training session on Railway: {}{s}\n", .{ YELLOW, err, RESET });
        print("Start training: tri train start --host railway\n", .{});
        return;
    };
    defer allocator.free(output);

    print("{s}", .{output});
    print("{s}═══════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
}

/// tri train start — Launch local training
fn runLocalStart(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const steps = getFlagValue(args, "--steps") orelse "100000";
    const lr = getFlagValue(args, "--lr") orelse "3e-4";
    const warmup = getFlagValue(args, "--warmup") orelse "5000";
    const batch = getFlagValue(args, "--batch") orelse "64";
    const optimizer = getFlagValue(args, "--optimizer") orelse "adamw";
    const ste = getFlagValue(args, "--ste") orelse "none";
    const wd = getFlagValue(args, "--wd") orelse "0.1";
    const ckpt_dir = getFlagValue(args, "--checkpoint-dir") orelse "data/checkpoints";
    const resume_path = getFlagValue(args, "--resume");
    const data_path = getFlagValue(args, "--data") orelse "data/tinystories/real_tinystories.txt";
    const grad_accum = getFlagValue(args, "--grad-accum") orelse "1";
    const context = getFlagValue(args, "--context") orelse "81";

    print("{s}{s}Starting local HSLM training...{s}\n", .{ CYAN, BOLD, RESET });
    print("  Steps: {s}, LR: {s}, Batch: {s}x{s}, Ctx: {s}, Opt: {s}, STE: {s}\n", .{ steps, lr, batch, grad_accum, context, optimizer, ste });

    // Build command
    var cmd_buf: [2048]u8 = undefined;
    var idx: usize = 0;
    const base = "./zig-out/bin/hslm-train";
    idx += copyTo(cmd_buf[idx..], base);
    idx += copyTo(cmd_buf[idx..], " --data ");
    idx += copyTo(cmd_buf[idx..], data_path);
    idx += copyTo(cmd_buf[idx..], " --steps ");
    idx += copyTo(cmd_buf[idx..], steps);
    idx += copyTo(cmd_buf[idx..], " --lr ");
    idx += copyTo(cmd_buf[idx..], lr);
    idx += copyTo(cmd_buf[idx..], " --warmup ");
    idx += copyTo(cmd_buf[idx..], warmup);
    idx += copyTo(cmd_buf[idx..], " --batch ");
    idx += copyTo(cmd_buf[idx..], batch);
    idx += copyTo(cmd_buf[idx..], " --optimizer ");
    idx += copyTo(cmd_buf[idx..], optimizer);
    idx += copyTo(cmd_buf[idx..], " --ste ");
    idx += copyTo(cmd_buf[idx..], ste);
    idx += copyTo(cmd_buf[idx..], " --wd ");
    idx += copyTo(cmd_buf[idx..], wd);
    idx += copyTo(cmd_buf[idx..], " --checkpoint-dir ");
    idx += copyTo(cmd_buf[idx..], ckpt_dir);
    idx += copyTo(cmd_buf[idx..], " --grad-accum ");
    idx += copyTo(cmd_buf[idx..], grad_accum);
    idx += copyTo(cmd_buf[idx..], " --context ");
    idx += copyTo(cmd_buf[idx..], context);
    if (resume_path) |rp| {
        idx += copyTo(cmd_buf[idx..], " --resume ");
        idx += copyTo(cmd_buf[idx..], rp);
    }

    const cmd = cmd_buf[0..idx];
    print("  Command: {s}{s}{s}\n\n", .{ GRAY, cmd, RESET });

    // Execute via child process
    var child = std.process.Child.init(
        &.{ "/bin/sh", "-c", cmd },
        allocator,
    );
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    _ = child.spawn() catch |err| {
        print("{s}Failed to start training: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    _ = child.wait() catch |err| {
        print("{s}Training process error: {}{s}\n", .{ RED, err, RESET });
    };
}

/// tri train start --host railway — Launch remote training via SSH+tmux
fn runRemoteStart(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();

    // Parse training arguments
    const steps = getFlagValue(args, "--steps") orelse "100000";
    const lr = getFlagValue(args, "--lr") orelse "1e-4";
    const warmup = getFlagValue(args, "--warmup") orelse "1000";
    const resume_path = getFlagValue(args, "--resume");
    const optimizer = getFlagValue(args, "--optimizer") orelse "adamw";
    const batch = getFlagValue(args, "--batch") orelse "64";
    const ste = getFlagValue(args, "--ste") orelse "none";
    const grad_accum = getFlagValue(args, "--grad-accum") orelse "1";
    const context = getFlagValue(args, "--context") orelse "81";

    print("{s}Preparing remote training on Railway...{s}\n", .{ CYAN, RESET });

    // Step 1: Pull latest code
    print("{s}[1/3]{s} Pulling latest code...\n", .{ GRAY, RESET });
    const pull_out = ssh.pullCode(allocator) catch |err| {
        print("{s}Failed to pull code: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(pull_out);

    if (std.mem.indexOf(u8, pull_out, "---DONE---") == null) {
        print("{s}Warning: Pull may have issues:{s}\n{s}", .{ YELLOW, RESET, pull_out });
    }

    // Step 2: Build binary
    print("{s}[2/3]{s} Building hslm-train binary...\n", .{ GRAY, RESET });
    const build_out = ssh.exec(allocator, "cd /data/trinity && PATH=/data/zig-x86_64-linux-0.15.2:$PATH zig build 2>&1 | tail -5") catch |err| {
        print("{s}Build failed: {}{s}\n", .{ RED, err, RESET });
        return;
    };
    defer allocator.free(build_out);
    if (build_out.len > 0) print("{s}{s}{s}\n", .{ GRAY, build_out, RESET });

    // Step 3: Launch training in tmux session
    print("{s}[3/3]{s} Launching training session...\n", .{ GRAY, RESET });

    var cmd_buf: [2048]u8 = undefined;
    const base_args = std.fmt.bufPrint(&cmd_buf, "cd /data/trinity && ./zig-out/bin/hslm-train --steps {s} --lr {s} --warmup {s} --batch {s} --optimizer {s} --ste {s} --grad-accum {s} --context {s}", .{
        steps, lr, warmup, batch, optimizer, ste, grad_accum, context,
    }) catch "cd /data/trinity && ./zig-out/bin/hslm-train";
    var final_buf: [2048]u8 = undefined;
    const train_cmd = if (resume_path) |rp|
        std.fmt.bufPrint(&final_buf, "{s} --resume {s}", .{ base_args, rp }) catch base_args
    else
        base_args;

    ssh.tmuxNewSession(allocator, "train", train_cmd) catch |err| {
        print("{s}Failed to start training: {}{s}\n", .{ RED, err, RESET });
        return;
    };

    print("\n{s}{s}✓ Training started on Railway!{s}\n", .{ GREEN, BOLD, RESET });
    print("  Steps: {s}, LR: {s}, Batch: {s}x{s}, Ctx: {s}, Opt: {s}, STE: {s}\n", .{ steps, lr, batch, grad_accum, context, optimizer, ste });
    if (resume_path) |rp| print("  Resuming from: {s}\n", .{rp});
    print("\n  Monitor: {s}tri train status --host railway{s}\n", .{ CYAN, RESET });
    print("  Logs:    {s}tri train logs --host railway{s}\n", .{ CYAN, RESET });
}

/// tri train logs --host railway — Tail training logs
fn runRemoteLogs(allocator: std.mem.Allocator) !void {
    const ssh = railway_ssh.RailwaySSH.initDefault();
    const output = ssh.tmuxCapture(allocator, "train", 50) catch |err| {
        print("{s}No active training session: {}{s}\n", .{ YELLOW, err, RESET });
        return;
    };
    defer allocator.free(output);
    print("{s}", .{output});
}

/// Check if a --flag value pair exists in args.
fn hasFlag(args: []const []const u8, flag: []const u8, value: []const u8) bool {
    for (args, 0..) |a, i| {
        if (std.mem.eql(u8, a, flag) and i + 1 < args.len and std.mem.eql(u8, args[i + 1], value)) {
            return true;
        }
    }
    return false;
}

/// Get the value after a --flag in args.
fn getFlagValue(args: []const []const u8, flag: []const u8) ?[]const u8 {
    for (args, 0..) |a, i| {
        if (std.mem.eql(u8, a, flag) and i + 1 < args.len) {
            return args[i + 1];
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(json_mode: bool) void {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(DEFAULT_CKPT_DIR, &ckpts);

    var entries: [64]TrainLogEntry = undefined;
    for (0..n_ckpts) |i| {
        entries[i] = .{
            .step = ckpts[i].step,
            .loss = ckpts[i].loss,
            .ppl = ckpts[i].ppl,
            .host = "local",
        };
    }

    var anomalies: [32]diag.Anomaly = undefined;
    const n_anom = diag.diagnose(entries[0..n_ckpts], &anomalies);
    const rec = diag.recommend(entries[0..n_ckpts]);

    if (json_mode) {
        writeStatusJson(ckpts[0..n_ckpts], anomalies[0..n_anom], rec);
    } else {
        writeStatusAnsi(ckpts[0..n_ckpts], anomalies[0..n_anom], rec);
    }
}

fn writeStatusAnsi(ckpts: []const CheckpointInfo, anomalies: []const diag.Anomaly, rec: diag.Recommendation) void {
    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("═══════════════════════════════════════════════════════\n", .{});
    print(" HSLM TRAINING OBSERVATORY{s}\n", .{RESET});
    print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    // Architecture
    print("{s}[ARCHITECTURE]{s}\n", .{ CYAN, RESET });
    print("  Model: HSLM-1.95M | Blocks: 3 | Heads: 3 | Vocab: 729\n", .{});
    print("  Embed: 243 (3^5) | Hidden: 729 (3^6) | Context: 81 (3^4)\n", .{});
    print("  Params: ~1,952,991 | Ternary: ~390 KB | Bits/param: 1.58\n\n", .{});

    // Checkpoints
    print("{s}[CHECKPOINTS]{s} {d} saved\n", .{ CYAN, RESET, ckpts.len });
    if (ckpts.len > 0) {
        print("\n  {s}Step   |  Loss    |   PPL     | Delta{s}\n", .{ GRAY, RESET });
        print("  {s}-------|----------|-----------|--------{s}\n", .{ GRAY, RESET });

        var best_loss: f32 = 999.0;
        var best_step: u32 = 0;

        for (ckpts, 0..) |ck, i| {
            if (ck.loss < best_loss and ck.loss > 0) {
                best_loss = ck.loss;
                best_step = ck.step;
            }

            // Phase transition marker
            const marker: []const u8 = if (i > 0 and ck.loss > 0) mrk: {
                const abs_d = @abs(ck.loss - ckpts[i - 1].loss);
                break :mrk if (abs_d > @as(f32, @floatCast(Sacred.PHI))) " <-- PHASE TRANSITION" else "";
            } else "";

            if (i > 0) {
                const d = ck.loss - ckpts[i - 1].loss;
                const sign: []const u8 = if (d >= 0) "+" else "";
                print("  {d:>5}K | {d:>7.3} | {d:>8.2} | {s}{d:.3}{s}\n", .{
                    ck.step / 1000, ck.loss, ck.ppl, sign, d, marker,
                });
            } else {
                print("  {d:>5}K | {d:>7.3} | {d:>8.2} |      --\n", .{
                    ck.step / 1000, ck.loss, ck.ppl,
                });
            }
        }

        print("\n  {s}Best: loss={d:.3} PPL={d:.2} at step {d}K{s}\n", .{
            GREEN, best_loss, @exp(best_loss), best_step / 1000, RESET,
        });
    }

    // Anomalies
    if (anomalies.len > 0) {
        print("\n{s}[ANOMALIES]{s} {d} detected\n", .{ CYAN, RESET, anomalies.len });
        for (anomalies) |a| {
            const color = switch (a.severity) {
                .critical => RED,
                .warning => YELLOW,
                .info => GREEN,
            };
            print("  {s}{s}{s} {s}: {s} (step {d})\n", .{
                color,  a.severity.symbol(), RESET,
                a.host, a.message,           a.step,
            });
        }
    }

    // Recommendation
    print("\n{s}[RECOMMENDATION]{s}\n", .{ CYAN, RESET });
    print("  Action: {s}{s}{s}\n", .{ GOLDEN, rec.action, RESET });
    print("  Reason: {s}\n", .{rec.reason});
    print("  Command: {s}{s}{s}\n", .{ GRAY, rec.command, RESET });

    // Scientific metrics
    print("\n{s}[SCIENTIFIC]{s}\n", .{ CYAN, RESET });
    print("  Bits/param: {d:.4} (log2(3))\n", .{Sacred.LOG2_3});
    print("  Compression vs f32: {d:.1}x\n", .{32.0 / Sacred.LOG2_3});
    print("  Consciousness threshold: {d:.4} (phi^-1)\n", .{Sacred.PHI_INV});
    print("  Trinity identity: phi^2 + phi^-2 = {d:.1}\n", .{Sacred.PHI_SQ + Sacred.PHI_INV_SQ});
    print("\n{s}========================================================={s}\n\n", .{ GOLDEN, RESET });
}

fn writeStatusJson(ckpts: []const CheckpointInfo, anomalies: []const diag.Anomaly, rec: diag.Recommendation) void {
    print("{{\"checkpoints\":[", .{});
    for (ckpts, 0..) |ck, i| {
        if (i > 0) print(",", .{});
        print("{{\"step\":{d},\"loss\":{d:.6},\"ppl\":{d:.2}}}", .{ ck.step, ck.loss, ck.ppl });
    }
    print("],\"anomalies\":", .{});

    var anom_buf: [4096]u8 = undefined;
    const anom_json = diag.anomaliesToJson(anomalies, &anom_buf);
    print("{s}", .{anom_json});

    print(",\"recommendation\":{{\"action\":\"{s}\",\"reason\":\"{s}\",\"command\":\"{s}\"}}}}\n", .{
        rec.action, rec.reason, rec.command,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOSS CURVE
// ═══════════════════════════════════════════════════════════════════════════════

fn runLossCurve(dir: []const u8) void {
    var ckpts: [64]CheckpointInfo = undefined;
    const n = diag.scanCheckpoints(dir, &ckpts);

    if (n == 0) {
        print("No checkpoints found in {s}\n", .{dir});
        return;
    }

    print("\n{s}HSLM Loss Curve{s} ({d} checkpoints from {s})\n\n", .{ BOLD, RESET, n, dir });
    print("  Step    |  Loss    |  PPL      | Bar\n", .{});
    print("  --------|----------|-----------|---------------------\n", .{});

    for (ckpts[0..n]) |ck| {
        const bar_len: usize = if (ck.ppl > 700) 20 else if (ck.ppl < 5) 1 else @intFromFloat(ck.ppl / 35.0);
        print("  {d:>6}  | {d:>7.3} | {d:>8.2} | ", .{ ck.step, ck.loss, ck.ppl });
        for (0..@min(bar_len, 20)) |_| print("#", .{});
        if (ck.ppl < 5.0) print(" <<<", .{});
        print("\n", .{});
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIAGNOSE
// ═══════════════════════════════════════════════════════════════════════════════

fn runDiagnose(dir: []const u8) void {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(dir, &ckpts);

    if (n_ckpts == 0) {
        print("No checkpoints found in {s}\n", .{dir});
        return;
    }

    var entries: [64]TrainLogEntry = undefined;
    for (0..n_ckpts) |i| {
        entries[i] = .{
            .step = ckpts[i].step,
            .loss = ckpts[i].loss,
            .ppl = ckpts[i].ppl,
            .host = "local",
        };
    }

    var anomalies: [32]diag.Anomaly = undefined;
    const n_anom = diag.diagnose(entries[0..n_ckpts], &anomalies);
    const rec = diag.recommend(entries[0..n_ckpts]);

    print("\n{s}HSLM Training Diagnostics{s}\n\n", .{ BOLD, RESET });
    print("  Checkpoints scanned: {d}\n", .{n_ckpts});
    print("  Anomalies found: {d}\n\n", .{n_anom});

    if (n_anom > 0) {
        for (anomalies[0..n_anom]) |a| {
            const sev_str = a.severity.symbol();
            print("  [{s}] step {d}: {s}\n", .{ sev_str, a.step, a.message });
            print("     -> {s}\n\n", .{a.recommendation});
        }
    } else {
        print("  No anomalies -- training looks healthy.\n\n", .{});
    }

    print("  {s}Recommendation: {s}{s}\n", .{ GOLDEN, rec.action, RESET });
    print("  {s}\n\n", .{rec.reason});
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPARE
// ═══════════════════════════════════════════════════════════════════════════════

fn runCompare(dir1: []const u8, dir2: []const u8) void {
    var ckpts1: [64]CheckpointInfo = undefined;
    var ckpts2: [64]CheckpointInfo = undefined;
    const n1 = diag.scanCheckpoints(dir1, &ckpts1);
    const n2 = diag.scanCheckpoints(dir2, &ckpts2);

    print("\n{s}HSLM Training Comparison{s}\n\n", .{ BOLD, RESET });
    print("  Run A: {s} ({d} checkpoints)\n", .{ dir1, n1 });
    print("  Run B: {s} ({d} checkpoints)\n\n", .{ dir2, n2 });

    var best1: f32 = 999.0;
    var best2: f32 = 999.0;
    var best1_step: u32 = 0;
    var best2_step: u32 = 0;

    for (ckpts1[0..n1]) |ck| {
        if (ck.loss < best1 and ck.loss > 0) {
            best1 = ck.loss;
            best1_step = ck.step;
        }
    }
    for (ckpts2[0..n2]) |ck| {
        if (ck.loss < best2 and ck.loss > 0) {
            best2 = ck.loss;
            best2_step = ck.step;
        }
    }

    print("  Metric        | Run A          | Run B\n", .{});
    print("  --------------|----------------|----------------\n", .{});
    print("  Checkpoints   | {d:<14} | {d}\n", .{ n1, n2 });
    print("  Best loss     | {d:<14.3} | {d:.3}\n", .{ best1, best2 });
    print("  Best PPL      | {d:<14.2} | {d:.2}\n", .{ @exp(best1), @exp(best2) });
    print("  Best step     | {d:<14} | {d}\n", .{ best1_step, best2_step });

    const winner: []const u8 = if (best1 < best2) "Run A" else "Run B";
    print("\n  {s}Winner: {s}{s}\n\n", .{ GREEN, winner, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKPOINT LIST
// ═══════════════════════════════════════════════════════════════════════════════

fn runCheckpointList(dir: []const u8) void {
    var ckpts: [64]CheckpointInfo = undefined;
    const n = diag.scanCheckpoints(dir, &ckpts);

    if (n == 0) {
        print("No checkpoints in {s}\n", .{dir});
        return;
    }

    print("\n{s}HSLM Checkpoints{s} ({s})\n\n", .{ BOLD, RESET, dir });
    print("  Step    |  Loss    |   PPL    |  Size\n", .{});
    print("  --------|----------|----------|----------\n", .{});

    for (ckpts[0..n]) |ck| {
        print("  {d:>6}  | {d:>7.3} | {d:>7.2} | {d:.1} MB\n", .{
            ck.step,
            ck.loss,
            ck.ppl,
            @as(f64, @floatFromInt(ck.file_size)) / 1048576.0,
        });
    }
    print("\n  Total: {d} checkpoints\n\n", .{n});
}

// ═══════════════════════════════════════════════════════════════════════════════
// MCP INTEGRATION — functions callable from MCP server
// ═══════════════════════════════════════════════════════════════════════════════

/// Get training status as JSON (for MCP tool)
pub fn getStatusJson(buf: []u8) []const u8 {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(DEFAULT_CKPT_DIR, &ckpts);

    var entries: [64]TrainLogEntry = undefined;
    for (0..n_ckpts) |i| {
        entries[i] = .{
            .step = ckpts[i].step,
            .loss = ckpts[i].loss,
            .ppl = ckpts[i].ppl,
            .host = "local",
        };
    }

    var anomalies: [32]diag.Anomaly = undefined;
    const n_anom = diag.diagnose(entries[0..n_ckpts], &anomalies);
    const rec = diag.recommend(entries[0..n_ckpts]);

    var idx: usize = 0;
    idx += copyTo(buf[idx..], "{\"status\":\"ok\",\"checkpoints\":");
    idx += fmtInt(buf[idx..], n_ckpts);
    idx += copyTo(buf[idx..], ",\"anomalies\":");
    idx += fmtInt(buf[idx..], n_anom);
    idx += copyTo(buf[idx..], ",\"recommendation\":\"");
    idx += copyTo(buf[idx..], rec.action);
    idx += copyTo(buf[idx..], "\",\"reason\":\"");
    idx += copyTo(buf[idx..], rec.reason);
    idx += copyTo(buf[idx..], "\"");

    if (n_ckpts > 0) {
        var best_loss: f32 = 999.0;
        var best_step: u32 = 0;
        var latest_step: u32 = 0;
        var latest_loss: f32 = 0;
        for (ckpts[0..n_ckpts]) |ck| {
            if (ck.loss < best_loss and ck.loss > 0) {
                best_loss = ck.loss;
                best_step = ck.step;
            }
            if (ck.step > latest_step) {
                latest_step = ck.step;
                latest_loss = ck.loss;
            }
        }
        idx += copyTo(buf[idx..], ",\"best_loss\":");
        idx += fmtFloat(buf[idx..], best_loss);
        idx += copyTo(buf[idx..], ",\"best_step\":");
        idx += fmtInt(buf[idx..], best_step);
        idx += copyTo(buf[idx..], ",\"latest_step\":");
        idx += fmtInt(buf[idx..], latest_step);
        idx += copyTo(buf[idx..], ",\"latest_loss\":");
        idx += fmtFloat(buf[idx..], latest_loss);
    }

    idx += copyTo(buf[idx..], "}");
    return buf[0..idx];
}

/// Get anomaly list as JSON (for MCP tool)
pub fn getDiagnoseJson(buf: []u8, dir: []const u8) []const u8 {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(dir, &ckpts);

    var entries: [64]TrainLogEntry = undefined;
    for (0..n_ckpts) |i| {
        entries[i] = .{
            .step = ckpts[i].step,
            .loss = ckpts[i].loss,
            .ppl = ckpts[i].ppl,
            .host = "local",
        };
    }

    var anomalies: [32]diag.Anomaly = undefined;
    const n_anom = diag.diagnose(entries[0..n_ckpts], &anomalies);
    return diag.anomaliesToJson(anomalies[0..n_anom], buf);
}

/// Get loss curve as JSON (for MCP tool)
pub fn getLossCurveJson(buf: []u8, dir: []const u8) []const u8 {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(dir, &ckpts);

    var idx: usize = 0;
    idx += copyTo(buf[idx..], "[");
    for (ckpts[0..n_ckpts], 0..) |ck, i| {
        if (i > 0) idx += copyTo(buf[idx..], ",");
        idx += copyTo(buf[idx..], "{\"step\":");
        idx += fmtInt(buf[idx..], ck.step);
        idx += copyTo(buf[idx..], ",\"loss\":");
        idx += fmtFloat(buf[idx..], ck.loss);
        idx += copyTo(buf[idx..], ",\"ppl\":");
        idx += fmtFloat(buf[idx..], ck.ppl);
        idx += copyTo(buf[idx..], "}");
    }
    idx += copyTo(buf[idx..], "]");
    return buf[0..idx];
}

/// Get recommendation as JSON (for MCP tool)
pub fn getRecommendJson(buf: []u8, dir: []const u8) []const u8 {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(dir, &ckpts);

    var entries: [64]TrainLogEntry = undefined;
    for (0..n_ckpts) |i| {
        entries[i] = .{
            .step = ckpts[i].step,
            .loss = ckpts[i].loss,
            .ppl = ckpts[i].ppl,
            .host = "local",
        };
    }

    const rec = diag.recommend(entries[0..n_ckpts]);
    var idx: usize = 0;
    idx += copyTo(buf[idx..], "{\"action\":\"");
    idx += copyTo(buf[idx..], rec.action);
    idx += copyTo(buf[idx..], "\",\"reason\":\"");
    idx += copyTo(buf[idx..], rec.reason);
    idx += copyTo(buf[idx..], "\",\"command\":\"");
    idx += copyTo(buf[idx..], rec.command);
    idx += copyTo(buf[idx..], "\"}");
    return buf[0..idx];
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL DASHBOARD — Farm + Local + Health + Loss History + Recommendations
// ═══════════════════════════════════════════════════════════════════════════════

const MAGENTA = "\x1b[35m";
const DIM = "\x1b[2m";
const WHITE = "\x1b[97m";
const BG_RED = "\x1b[41m";

const farm_evolve = @import("tri_farm_evolve.zig");

fn runDashboard(allocator: std.mem.Allocator) !void {
    // ═══════ HEADER ═══════
    print("\n{s}{s}", .{ GOLDEN, BOLD });
    print("🧠 ═══════════════════════════════════════════════════════════════\n", .{});
    print("   HSLM TRAINING OBSERVATORY                                     \n", .{});
    print("   ═══════════════════════════════════════════════════════════════{s}\n\n", .{RESET});

    // ═══════ ARCHITECTURE ═══════
    print("{s}{s}🔬 ARCHITECTURE{s}\n", .{ CYAN, BOLD, RESET });
    print("   Model: {s}HSLM-1.95M{s} │ Blocks: 3 │ Heads: 3 │ Vocab: 729 (3⁶)\n", .{ WHITE, RESET });
    print("   Embed: 243 (3⁵) │ Hidden: 729 (3⁶) │ Context: 81 (3⁴)\n", .{});
    print("   Params: ~1,952,991 │ Ternary: ~390 KB │ Bits/param: {s}1.58{s}\n\n", .{ GREEN, RESET });

    // ═══════ FARM EVOLUTION STATE ═══════
    const state_file = std.fs.cwd().openFile(".trinity/evolution_state.json", .{}) catch {
        print("{s}   ⚠️  No evolution state — run: tri farm evolve init{s}\n\n", .{ YELLOW, RESET });
        // Still show local checkpoints
        printLocalCheckpoints();
        printScientific();
        return;
    };
    defer state_file.close();

    const contents = state_file.readToEndAlloc(allocator, 512 * 1024) catch {
        print("{s}   ⚠️  Cannot read evolution state{s}\n\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch {
        print("{s}   ⚠️  Invalid evolution state JSON{s}\n\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    const root = parsed.value;
    const evo_step = jsonU32(root, "evolution_step");
    const best_ppl = jsonF32(root, "best_ppl");
    const best_name = getJsonStr(root, "best_name");
    const best_step = jsonU32(root, "best_step");
    const svc_count = jsonU32(root, "service_count");

    // Parse services
    const svcs_val = getJsonObj(root, "services");
    const svcs = if (svcs_val != null and svcs_val.? == .array) svcs_val.?.array.items else &[_]std.json.Value{};

    // Count states
    var alive: u32 = 0;
    var killed: u32 = 0;
    var stalled: u32 = 0;
    var diverged: u32 = 0;
    var stuck: u32 = 0;
    var with_metrics: u32 = 0;
    var sub5: u32 = 0;
    var sub10: u32 = 0;
    var total_tps: f32 = 0;
    var tps_count: u32 = 0;
    var min_ppl: f32 = 999;
    var max_ppl: f32 = 0;
    var ppl_sum: f32 = 0;
    var ppl_count: u32 = 0;
    var at_100k: u32 = 0;
    var max_step: u32 = 0;

    // Per-account stats
    var acct_alive: [8]u32 = .{0} ** 8;
    var acct_total: [8]u32 = .{0} ** 8;

    for (svcs) |s| {
        const status = jsonU32(s, "status");
        const acct: usize = @intCast(@min(jsonU32(s, "acct"), 7));
        acct_total[acct] += 1;

        if (status == 0) { // running
            alive += 1;
            acct_alive[acct] += 1;
            const ppl = jsonF32(s, "ppl");
            const step = jsonU32(s, "step");
            const tps = jsonF32(s, "tps");
            if (step > max_step) max_step = step;
            if (step >= 100000) at_100k += 1;
            if (ppl > 0 and ppl < 998) {
                with_metrics += 1;
                if (ppl < 5) sub5 += 1;
                if (ppl < 10) sub10 += 1;
                if (ppl < min_ppl) min_ppl = ppl;
                if (ppl > max_ppl) max_ppl = ppl;
                ppl_sum += ppl;
                ppl_count += 1;
            }
            if (tps > 0) {
                total_tps += tps;
                tps_count += 1;
            }
        } else if (status == 3) {
            killed += 1;
        } else if (status == 5) {
            stalled += 1;
        } else if (status == 6) {
            diverged += 1;
        } else if (status == 7) {
            stuck += 1;
        }
    }

    // ═══════ FARM OVERVIEW ═══════
    print("{s}{s}📊 FARM OVERVIEW{s}  │  Evolution step: {s}{d}{s}\n", .{ CYAN, BOLD, RESET, WHITE, evo_step, RESET });
    print("   Workers: {s}{d}{s} alive │ {d} killed │ {d} total\n", .{ GREEN, alive, RESET, killed, svc_count });
    if (stalled > 0 or diverged > 0 or stuck > 0) {
        print("   {s}⚠️  Alerts:{s}", .{ YELLOW, RESET });
        if (stalled > 0) print(" {s}{d} stalled{s}", .{ YELLOW, stalled, RESET });
        if (diverged > 0) print(" {s}{d} diverged{s}", .{ RED, diverged, RESET });
        if (stuck > 0) print(" {s}{d} stuck{s}", .{ RED, stuck, RESET });
        print("\n", .{});
    }
    if (ppl_count > 0) {
        const median_ppl = ppl_sum / @as(f32, @floatFromInt(ppl_count));
        print("   PPL range: {s}{d:.2}{s} — {d:.2} (median {d:.1})\n", .{ GREEN, min_ppl, RESET, max_ppl, median_ppl });
        print("   Sub-5: {s}{d}{s} │ Sub-10: {s}{d}{s} │ At 100K: {d}\n", .{ GREEN, sub5, RESET, CYAN, sub10, RESET, at_100k });
    }
    if (tps_count > 0) {
        print("   Avg tok/s: {d:.0}\n", .{total_tps / @as(f32, @floatFromInt(tps_count))});
    }
    print("   Best: {s}{s}{s} PPL={s}{d:.2}{s} at step {d}K\n\n", .{ GOLDEN, best_name, RESET, GREEN, best_ppl, RESET, best_step / 1000 });

    // ═══════ LEADERBOARD ═══════
    print("{s}{s}🏆 LEADERBOARD{s}  (top 15 by PPL)\n", .{ CYAN, BOLD, RESET });
    print("   {s}#  │ Service         │   PPL │ Step │ Obj  │ Ctx │ Opt  │ LR      │ Sched │ GC   │ Tok/s │ Gen │ Trend{s}\n", .{ DIM, RESET });
    print("   {s}───┼─────────────────┼───────┼──────┼──────┼─────┼──────┼─────────┼───────┼──────┼───────┼─────┼──────{s}\n", .{ DIM, RESET });

    // Sort services by PPL (simple insertion sort on indices)
    var sorted: [256]usize = undefined;
    var sorted_count: usize = 0;
    for (svcs, 0..) |s, si| {
        const status = jsonU32(s, "status");
        const ppl = jsonF32(s, "ppl");
        if (status == 0 and ppl > 0 and ppl < 998) {
            sorted[sorted_count] = si;
            sorted_count += 1;
        }
    }
    // Insertion sort
    {
        var i: usize = 1;
        while (i < sorted_count) : (i += 1) {
            const key = sorted[i];
            const key_ppl = jsonF32(svcs[key], "ppl");
            var j: usize = i;
            while (j > 0 and jsonF32(svcs[sorted[j - 1]], "ppl") > key_ppl) {
                sorted[j] = sorted[j - 1];
                j -= 1;
            }
            sorted[j] = key;
        }
    }

    const show = @min(sorted_count, 15);
    for (0..show) |rank| {
        const s = svcs[sorted[rank]];
        const name = getJsonStr(s, "name");
        const ppl = jsonF32(s, "ppl");
        const step = jsonU32(s, "step");
        const lr = getJsonStr(s, "lr");
        const tps = jsonF32(s, "tps");
        const gen = jsonU32(s, "gen");
        const obj = getJsonStr(s, "obj");
        const ctx = jsonU32(s, "ctx");
        const opt = getJsonStr(s, "opt");
        const sched = getJsonStr(s, "sched");
        const gc = jsonF32(s, "gc");

        // Trend from loss_history
        const trend = getLossHistoryTrend(s);

        // Rank + medal
        const medal: []const u8 = if (rank == 0) "👑" else if (rank < 3) "🥈" else if (ppl < 10) "⚡" else "  ";
        print("  {s}{s}{d:>2}", .{ medal, if (rank < 3) GOLDEN else RESET, rank + 1 });
        print("{s} │ ", .{RESET});

        // Name (pad to 15)
        print("{s}", .{name});
        padN(name.len, 15);

        // PPL
        print("{s}", .{" │ "});
        if (ppl < 5) {
            print("{s}{d:>5.2}{s}", .{ GREEN, ppl, RESET });
        } else if (ppl < 10) {
            print("{s}{d:>5.2}{s}", .{ CYAN, ppl, RESET });
        } else {
            print("{d:>5.2}", .{ppl});
        }

        // Step
        print(" │ {d:>4}", .{step / 1000});
        print("{s}", .{"K │ "});

        // Objective (4 chars: NTP/JEPA/HYB/NCA)
        const obj_short: []const u8 = if (std.mem.indexOf(u8, obj, "hybrid") != null) "HYB " else if (std.mem.indexOf(u8, obj, "nca") != null) "NCA " else if (std.mem.indexOf(u8, obj, "jepa") != null) "JEPA" else "NTP ";
        print("{s}", .{obj_short});

        // Context
        print(" │ {d:>3}", .{if (ctx > 0) ctx else @as(u32, 27)});

        // Optimizer (4 chars)
        print(" │ ", .{});
        print("{s}", .{opt});
        padN(opt.len, 4);

        // LR
        print(" │ {s}", .{lr});
        padN(lr.len, 7);

        // Schedule (3 chars: cos/phi/wsd/d2z)
        print(" │ ", .{});
        const sched_short: []const u8 = if (std.mem.eql(u8, sched, "phi_restart")) "phi  " else if (std.mem.eql(u8, sched, "wsd")) "wsd  " else if (std.mem.eql(u8, sched, "d2z")) "d2z  " else "cos  ";
        print("{s}", .{sched_short});

        // Grad clip
        print("│ ", .{});
        if (gc > 0) {
            print("{d:>4.2}", .{gc});
        } else {
            print("1.00", .{});
        }

        // Tok/s
        print(" │ ", .{});
        if (tps > 0) {
            print("{d:>5.0}", .{tps});
        } else {
            print("{s}  ---{s}", .{ DIM, RESET });
        }

        // Gen
        print(" │ G{d:<2}", .{gen});

        // Trend
        print(" │ {s}", .{trend});

        print("\n", .{});
    }
    print("\n", .{});

    // ═══════ ARCHITECTURE MIX ═══════
    print("{s}{s}🧬 ARCHITECTURE MIX{s}\n", .{ CYAN, BOLD, RESET });
    {
        // Objective breakdown
        const obj_labels = [_][]const u8{ "NTP", "NCA", "JEPA", "HYBRID" };
        const obj_keys = [_][]const u8{ "ntp", "nca", "jepa", "hybrid" };
        var obj_counts: [4]u32 = .{ 0, 0, 0, 0 };
        var obj_best: [4]f32 = .{ 999, 999, 999, 999 };
        var obj_sum: [4]f32 = .{ 0, 0, 0, 0 };

        for (svcs) |s| {
            if (jsonU32(s, "status") != 0) continue;
            const ppl_v = jsonF32(s, "ppl");
            if (ppl_v <= 0 or ppl_v >= 998) continue;
            const o = getJsonStr(s, "obj");
            var oi: usize = 0; // default NTP
            for (obj_keys, 0..) |k, ki| {
                if (ki == 0) continue; // check specific first
                if (std.mem.indexOf(u8, o, k) != null) {
                    oi = ki;
                    break;
                }
            }
            obj_counts[oi] += 1;
            obj_sum[oi] += ppl_v;
            if (ppl_v < obj_best[oi]) obj_best[oi] = ppl_v;
        }

        print("   {s}Objective │ Count │ Best PPL │ Avg PPL │ Bar{s}\n", .{ DIM, RESET });
        print("   {s}──────────┼───────┼──────────┼─────────┼────────────────────{s}\n", .{ DIM, RESET });
        for (obj_labels, 0..) |label, li| {
            if (obj_counts[li] == 0) continue;
            const avg = obj_sum[li] / @as(f32, @floatFromInt(obj_counts[li]));
            print("   {s}", .{label});
            padN(label.len, 9);
            print(" │ {d:>5} │ {d:>8.2} │ {d:>7.1} │ ", .{ obj_counts[li], obj_best[li], avg });
            const bar_n: usize = @intCast(@min(obj_counts[li], 20));
            for (0..bar_n) |_| print("{s}█{s}", .{ GREEN, RESET });
            print("\n", .{});
        }
        print("\n", .{});

        // Context breakdown
        const ctx_vals = [_]u32{ 27, 81, 243 };
        var ctx_counts: [3]u32 = .{ 0, 0, 0 };
        var ctx_best: [3]f32 = .{ 999, 999, 999 };

        for (svcs) |s| {
            if (jsonU32(s, "status") != 0) continue;
            const ppl_v = jsonF32(s, "ppl");
            if (ppl_v <= 0 or ppl_v >= 998) continue;
            const c = jsonU32(s, "ctx");
            const cv: u32 = if (c > 0) c else 27;
            var ci: usize = 0;
            for (ctx_vals, 0..) |v, vi| {
                if (cv == v) {
                    ci = vi;
                    break;
                }
            }
            ctx_counts[ci] += 1;
            if (ppl_v < ctx_best[ci]) ctx_best[ci] = ppl_v;
        }

        print("   {s}Context   │ Count │ Best PPL{s}\n", .{ DIM, RESET });
        print("   {s}──────────┼───────┼─────────{s}\n", .{ DIM, RESET });
        for (ctx_vals, 0..) |cv, ci| {
            if (ctx_counts[ci] == 0) continue;
            print("   {d:<9} │ {d:>5} │ {d:>8.2}\n", .{ cv, ctx_counts[ci], ctx_best[ci] });
        }
        print("\n", .{});

        // Schedule breakdown
        const sched_labels = [_][]const u8{ "cosine", "phi_rst", "wsd", "d2z" };
        const sched_keys = [_][]const u8{ "cosine", "phi_restart", "wsd", "d2z" };
        var sched_counts: [4]u32 = .{ 0, 0, 0, 0 };
        var sched_best: [4]f32 = .{ 999, 999, 999, 999 };

        for (svcs) |s| {
            if (jsonU32(s, "status") != 0) continue;
            const ppl_v = jsonF32(s, "ppl");
            if (ppl_v <= 0 or ppl_v >= 998) continue;
            const sc = getJsonStr(s, "sched");
            var si: usize = 0; // default cosine
            for (sched_keys, 0..) |k, ki| {
                if (std.mem.eql(u8, sc, k)) {
                    si = ki;
                    break;
                }
            }
            sched_counts[si] += 1;
            if (ppl_v < sched_best[si]) sched_best[si] = ppl_v;
        }

        print("   {s}Schedule  │ Count │ Best PPL{s}\n", .{ DIM, RESET });
        print("   {s}──────────┼───────┼─────────{s}\n", .{ DIM, RESET });
        for (sched_labels, 0..) |label, li| {
            if (sched_counts[li] == 0) continue;
            print("   {s}", .{label});
            padN(label.len, 9);
            print(" │ {d:>5} │ {d:>8.2}\n", .{ sched_counts[li], sched_best[li] });
        }
        print("\n", .{});
    }

    // ═══════ POPULATION SCIENCE ═══════
    print("{s}{s}📈 POPULATION SCIENCE{s}\n", .{ CYAN, BOLD, RESET });
    {
        // Compute diversity (coefficient of variation of PPL)
        var sum_ppl_sq: f32 = 0;
        var pop_ppl_sum: f32 = 0;
        var pop_count: u32 = 0;
        var best_pop_ppl: f32 = 999;
        var worst_pop_ppl: f32 = 0;
        var gen_counts: [16]u32 = .{0} ** 16;
        var max_gen: u32 = 0;
        var spike_count: u32 = 0;

        for (svcs) |s| {
            if (jsonU32(s, "status") != 0) continue;
            const ppl_v = jsonF32(s, "ppl");
            if (ppl_v <= 0 or ppl_v >= 998) continue;
            pop_ppl_sum += ppl_v;
            sum_ppl_sq += ppl_v * ppl_v;
            pop_count += 1;
            if (ppl_v < best_pop_ppl) best_pop_ppl = ppl_v;
            if (ppl_v > worst_pop_ppl) worst_pop_ppl = ppl_v;
            const g: usize = @intCast(@min(jsonU32(s, "gen"), 15));
            gen_counts[g] += 1;
            if (g > max_gen) max_gen = @intCast(g);
            if (ppl_v > 100) spike_count += 1;
        }

        if (pop_count > 1) {
            const mean = pop_ppl_sum / @as(f32, @floatFromInt(pop_count));
            const variance = sum_ppl_sq / @as(f32, @floatFromInt(pop_count)) - mean * mean;
            const std_dev = @sqrt(@max(variance, 0));
            const diversity = if (mean > 0) std_dev / mean else 0;
            const elite_gap = if (best_pop_ppl > 0) mean / best_pop_ppl else 1;
            const spike_pct = @as(f32, @floatFromInt(spike_count)) / @as(f32, @floatFromInt(pop_count)) * 100.0;

            // Health score: lower diversity=more converged, low spike rate, low elite gap
            const div_score: f32 = @max(0, 25.0 - diversity * 100.0);
            const spike_score: f32 = @max(0, 25.0 - spike_pct);
            const gap_score: f32 = if (elite_gap < 2) 25.0 else if (elite_gap < 5) 15.0 else 5.0;
            const gen_score: f32 = if (max_gen >= 3) 25.0 else if (max_gen >= 1) 15.0 else 5.0;
            const health = div_score + spike_score + gap_score + gen_score;

            const health_bars: usize = @intFromFloat(@min(health / 4.0, 25));
            print("   Health Score: {s}{d:.1}/100{s}  [", .{ if (health > 70) GREEN else if (health > 40) YELLOW else RED, health, RESET });
            for (0..25) |bi| {
                if (bi < health_bars) {
                    print("{s}█{s}", .{ GREEN, RESET });
                } else {
                    print("{s}░{s}", .{ DIM, RESET });
                }
            }
            print("]\n\n", .{});

            print("   Diversity:    {d:.5}  │  Elite Gap:    {d:.2}x\n", .{ diversity, elite_gap });
            print("   Spike Rate:   {d:.1}%    │  Max Gen:      G{d}\n", .{ spike_pct, max_gen });
            print("   Leader PPL:   {s}{d:.2}{s}   │  Mean PPL:     {d:.1}\n\n", .{ GREEN, best_pop_ppl, RESET, mean });

            // Generation distribution
            print("   {s}Generation Distribution:{s}\n", .{ DIM, RESET });
            for (0..max_gen + 1) |gi| {
                if (gen_counts[gi] == 0) continue;
                print("   G{d} ", .{gi});
                const bar_n: usize = @intCast(@min(gen_counts[gi], 40));
                for (0..bar_n) |_| print("{s}█{s}", .{ CYAN, RESET });
                print(" {d}\n", .{gen_counts[gi]});
            }
        } else {
            print("   {s}Not enough data (need 2+ running services with metrics){s}\n", .{ DIM, RESET });
        }
        print("\n", .{});
    }

    // ═══════ ACCOUNTS ═══════
    print("{s}{s}☁️  ACCOUNTS{s}\n", .{ CYAN, BOLD, RESET });
    const acct_names = [8][]const u8{ "PRIMARY ", "FARM-2  ", "FARM-3  ", "FARM-4  ", "FARM-5  ", "FARM-6  ", "FARM-7  ", "FARM-8  " };
    print("   {s}Account  │ Alive │ Total │ Bar{s}\n", .{ DIM, RESET });
    print("   {s}─────────┼───────┼───────┼───────────────────{s}\n", .{ DIM, RESET });
    for (0..8) |ai| {
        if (acct_total[ai] == 0) continue;
        const bar_len: usize = @intCast(@min(acct_alive[ai], 20));
        print("   {s} │ {s}{d:>5}{s} │ {d:>5} │ ", .{ acct_names[ai], GREEN, acct_alive[ai], RESET, acct_total[ai] });
        for (0..bar_len) |_| print("{s}█{s}", .{ GREEN, RESET });
        print("\n", .{});
    }
    print("\n", .{});

    // ═══════ LOSS HISTORY (leaders) ═══════
    if (show > 0) {
        print("{s}{s}📉 LOSS CURVES{s}  (top 3 leaders, last 20 points)\n", .{ CYAN, BOLD, RESET });
        const curves_show = @min(show, 3);
        for (0..curves_show) |rank| {
            const s = svcs[sorted[rank]];
            const name = getJsonStr(s, "name");
            const lh = getJsonObj(s, "lh");
            if (lh == null) continue;
            if (lh.? != .array or lh.?.array.items.len == 0) continue;

            print("   {s}{s}{s}: ", .{ GOLDEN, name, RESET });

            const items = lh.?.array.items;
            for (items, 0..) |pt, pi| {
                if (pt != .array or pt.array.items.len < 2) continue;
                const pt_ppl = jsonValF32(pt.array.items[1]);
                if (pt_ppl <= 0) continue;

                // Sparkline: map PPL to block char
                const ch: []const u8 = if (pt_ppl > 100) "▇" else if (pt_ppl > 50) "▆" else if (pt_ppl > 20) "▅" else if (pt_ppl > 10) "▃" else if (pt_ppl > 5) "▂" else "▁";

                const color: []const u8 = if (pt_ppl < 5) GREEN else if (pt_ppl < 10) CYAN else if (pt_ppl < 30) YELLOW else RED;
                print("{s}{s}{s}", .{ color, ch, RESET });

                // Show PPL number at end
                if (pi == items.len - 1) {
                    print(" {d:.1}", .{pt_ppl});
                }
            }
            print("\n", .{});
        }
        print("\n", .{});
    }

    // ═══════ ALERTS ═══════
    if (stalled > 0 or diverged > 0 or stuck > 0) {
        print("{s}{s}🚨 ALERTS{s}\n", .{ RED, BOLD, RESET });
        for (svcs) |s| {
            const status = jsonU32(s, "status");
            const name = getJsonStr(s, "name");
            const step = jsonU32(s, "step");
            if (status == 5) print("   {s}⏸️  {s}: stalled at step {d}{s}\n", .{ YELLOW, name, step, RESET });
            if (status == 6) print("   {s}💥 {s}: diverged (PPL={d:.0}) at step {d}{s}\n", .{ RED, name, jsonF32(s, "ppl"), step, RESET });
            if (status == 7) print("   {s}🔒 {s}: stuck at step=0{s}\n", .{ RED, name, RESET });
        }
        print("\n", .{});
    }

    // ═══════ ETA ═══════
    print("{s}{s}⏱️  ETA{s}\n", .{ CYAN, BOLD, RESET });
    if (show > 0) {
        const leader = svcs[sorted[0]];
        const l_name = getJsonStr(leader, "name");
        const l_step = jsonU32(leader, "step");
        const l_tps = jsonF32(leader, "tps");
        const l_ppl = jsonF32(leader, "ppl");
        if (l_tps > 0 and l_step < 100000) {
            const remaining = 100000 - l_step;
            const ctx_batch: f32 = 27.0 * 66.0; // ctx × batch
            const eta_sec = @as(f32, @floatFromInt(remaining)) * ctx_batch / l_tps;
            const eta_h = eta_sec / 3600.0;
            print("   Leader {s}{s}{s} (PPL={d:.2}): {d}K→100K = {s}~{d:.1}h{s}\n", .{ GOLDEN, l_name, RESET, l_ppl, l_step / 1000, GREEN, eta_h, RESET });
        } else if (l_step >= 100000) {
            print("   Leader {s}{s}{s}: {s}✅ FINISHED{s} at {d}K, PPL={d:.2}\n", .{ GOLDEN, l_name, RESET, GREEN, RESET, l_step / 1000, l_ppl });
        }

        // Tail ETA (worst running)
        if (sorted_count > 1) {
            const tail = svcs[sorted[sorted_count - 1]];
            const t_name = getJsonStr(tail, "name");
            const t_step = jsonU32(tail, "step");
            const t_tps = jsonF32(tail, "tps");
            if (t_tps > 0 and t_step < 100000) {
                const t_remaining = 100000 - t_step;
                const t_eta_sec = @as(f32, @floatFromInt(t_remaining)) * 27.0 * 66.0 / t_tps;
                print("   Tail {s} ({d}K): ~{d:.1}h to 100K\n", .{ t_name, t_step / 1000, t_eta_sec / 3600.0 });
            }
        }
    }
    print("\n", .{});

    // ═══════ LOCAL CHECKPOINTS ═══════
    printLocalCheckpoints();

    // ═══════ SCIENTIFIC ═══════
    printScientific();

    // ═══════ RECOMMENDATIONS ═══════
    print("{s}{s}🎯 RECOMMENDATIONS{s}\n", .{ CYAN, BOLD, RESET });
    if (sub10 >= 3 and at_100k == 0) {
        print("   → {d} workers sub-10 PPL — approaching phase transition territory\n", .{sub10});
    }
    if (at_100k > 0) {
        print("   → {s}{d} workers at 100K{s} — verify with RECORD_VERIFIED\n", .{ GREEN, at_100k, RESET });
    }
    // G0 diversity check
    var g0_count: u32 = 0;
    for (svcs) |s| {
        if (jsonU32(s, "status") == 0 and jsonU32(s, "gen") == 0) g0_count += 1;
    }
    if (g0_count > alive / 2 and alive > 10) {
        print("   → {s}{d}/{d} workers still G0{s} — inject diversity: tri farm evolve inject --sacred\n", .{ YELLOW, g0_count, alive, RESET });
    }
    if (stalled > 0) {
        print("   → {s}{d} stalled workers{s} — check logs: tri farm evolve logs <name>\n", .{ YELLOW, stalled, RESET });
    }
    if (diverged > 0) {
        print("   → {s}{d} diverged workers{s} — recycle: tri farm evolve inject --target <name>\n", .{ RED, diverged, RESET });
    }
    print("   → Commands: {s}tri farm evolve status{s} │ {s}tri farm evolve step{s} │ {s}tri farm evolve notify{s}\n", .{ DIM, RESET, DIM, RESET, DIM, RESET });

    // Footer
    print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    print("{s}   φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ DIM, RESET });
}

fn printLocalCheckpoints() void {
    var ckpts: [64]CheckpointInfo = undefined;
    const n_ckpts = diag.scanCheckpoints(DEFAULT_CKPT_DIR, &ckpts);

    if (n_ckpts > 0) {
        print("{s}{s}💾 LOCAL CHECKPOINTS{s}  ({d} saved)\n", .{ CYAN, BOLD, RESET, n_ckpts });
        print("   {s}Step   │  Loss    │   PPL     │ Delta{s}\n", .{ DIM, RESET });
        print("   {s}───────┼──────────┼───────────┼────────{s}\n", .{ DIM, RESET });

        for (ckpts[0..n_ckpts], 0..) |ck, i| {
            if (i > 0) {
                const d = ck.loss - ckpts[i - 1].loss;
                const sign: []const u8 = if (d >= 0) "+" else "";
                const color: []const u8 = if (d < 0) GREEN else RED;
                print("   {d:>5}K │ {d:>7.3} │ {d:>8.2} │ {s}{s}{d:.3}{s}\n", .{
                    ck.step / 1000, ck.loss, ck.ppl, color, sign, d, RESET,
                });
            } else {
                print("   {d:>5}K │ {d:>7.3} │ {d:>8.2} │      --\n", .{
                    ck.step / 1000, ck.loss, ck.ppl,
                });
            }
        }
        print("\n", .{});
    }
}

fn printScientific() void {
    print("{s}{s}🔬 SCIENTIFIC{s}\n", .{ CYAN, BOLD, RESET });
    print("   Bits/param: {s}{d:.4}{s} (log₂3)  │  Compression vs f32: {s}{d:.1}x{s}\n", .{ GREEN, Sacred.LOG2_3, RESET, GREEN, 32.0 / Sacred.LOG2_3, RESET });
    print("   φ⁻¹ = {d:.4}  │  φ² + φ⁻² = {s}{d:.1}{s}\n\n", .{ Sacred.PHI_INV, GREEN, Sacred.PHI_SQ + Sacred.PHI_INV_SQ, RESET });
}

/// Get loss trend arrow from loss_history
fn getLossHistoryTrend(s: std.json.Value) []const u8 {
    const lh = getJsonObj(s, "lh") orelse return "  ";
    if (lh != .array or lh.array.items.len < 2) return "  ";

    const items = lh.array.items;
    const last = items[items.len - 1];
    const prev = items[items.len - 2];
    if (last != .array or prev != .array) return "  ";
    if (last.array.items.len < 2 or prev.array.items.len < 2) return "  ";

    const last_ppl = jsonValF32(last.array.items[1]);
    const prev_ppl = jsonValF32(prev.array.items[1]);
    if (last_ppl <= 0 or prev_ppl <= 0) return "  ";

    const delta = last_ppl - prev_ppl;
    const ratio = @abs(delta) / prev_ppl;
    if (ratio < 0.02) return "➡️";
    return if (delta < 0) "📉" else "📈";
}

// Dashboard JSON helpers (separate from farm_evolve to avoid circular deps)
fn getJsonStr(val: std.json.Value, key: []const u8) []const u8 {
    if (val != .object) return "?";
    const v = val.object.get(key) orelse return "?";
    if (v != .string) return "?";
    return v.string;
}

fn getJsonObj(val: std.json.Value, key: []const u8) ?std.json.Value {
    if (val != .object) return null;
    return val.object.get(key);
}

fn jsonU32(val: std.json.Value, key: []const u8) u32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| @intCast(@max(0, i)),
        .float => |f| @intFromFloat(@max(0, f)),
        else => 0,
    };
}

fn jsonF32(val: std.json.Value, key: []const u8) f32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .float => |f| @floatCast(f),
        .integer => |i| @floatFromInt(i),
        else => 0,
    };
}

fn jsonValF32(v: std.json.Value) f32 {
    return switch (v) {
        .float => |f| @floatCast(f),
        .integer => |i| @floatFromInt(i),
        else => 0,
    };
}

fn padN(current: usize, target: usize) void {
    if (current >= target) return;
    var i: usize = current;
    while (i < target) : (i += 1) print(" ", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn copyTo(dst: []u8, src: []const u8) usize {
    const n = @min(dst.len, src.len);
    @memcpy(dst[0..n], src[0..n]);
    return n;
}

fn fmtInt(dst: []u8, val: anytype) usize {
    var num_buf: [20]u8 = undefined;
    const s = std.fmt.bufPrint(&num_buf, "{d}", .{val}) catch return 0;
    return copyTo(dst, s);
}

fn fmtFloat(dst: []u8, val: f32) usize {
    var num_buf: [20]u8 = undefined;
    const s = std.fmt.bufPrint(&num_buf, "{d:.4}", .{val}) catch return 0;
    return copyTo(dst, s);
}

test "fmtInt helper" {
    var buf: [32]u8 = undefined;
    const n = fmtInt(&buf, @as(u32, 42));
    try std.testing.expectEqualStrings("42", buf[0..n]);
}

test "fmtFloat helper" {
    var buf: [32]u8 = undefined;
    const n = fmtFloat(&buf, 3.14);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.startsWith(u8, buf[0..n], "3.14"));
}
