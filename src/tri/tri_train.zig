// @origin(manual) @regen(pending)
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
