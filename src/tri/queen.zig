// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN v4 — Maximum Autonomy: Full Capability Unlock
// ═══════════════════════════════════════════════════════════════════════════════
//
// Head of Trinity. Sees (18 senses), Acts (29 actions, 3 safety levels),
// Listens (Telegram), Decides (12-rule policy-gated auto-heal), Remembers.
//
// Safety: L0=read-only(12), L1=soft-write(10), L2=dangerous(7)
// Hard bans: 12 NEVER-unlock actions (PRIMARY protection, force-push, etc.)
// Memory: incident ring buffer, daily aggregates, escalation on repeated failure
// Audit: .trinity/queen/audit.jsonl — every action logged with verdict
//
// Launch: tri queen start [--daemon] [--interval <sec>] [--god-mode]
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const faculty_board = @import("cortex.zig");
const faculty_types = @import("faculty_types.zig");
const colors = @import("tri_colors.zig");
const qt = @import("queen_types.zig");
const queen_senses = @import("queen_senses.zig");
const queen_actions = @import("queen_actions.zig");
const queen_telegram = @import("queen_telegram.zig");
const queen_policy = @import("queen_policy.zig");
const queen_issues = @import("queen_issues.zig");

// Phase 2: Brain motor hierarchy
const queen_premotor = @import("queen_premotor.zig");
const queen_motor = @import("queen_motor.zig");

// Phase 3: DLPFC — Autonomous decision engine (READ→THINK→ACT→SPEAK)
const queen_dlpfc = @import("queen_dlpfc.zig");

const Allocator = std.mem.Allocator;
const FacultySnapshot = faculty_types.FacultySnapshot;
const print = std.debug.print;

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;

// Re-export types for backward compat with tests
const QueenConfig = qt.QueenConfig;
const QueenState = qt.QueenState;
const AlertKind = qt.AlertKind;
const Alert = qt.Alert;
const EvolutionInfo = qt.EvolutionInfo;
const ArenaInfo = qt.ArenaInfo;

// ═══════════════════════════════════════════════════════════════════════════════
// CLI ENTRY
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runQueenCommand(allocator: Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printUsage();
        return;
    }

    if (std.mem.eql(u8, args[0], "supervisor")) {
        try runSupervisorMode(allocator);
    } else if (std.mem.eql(u8, args[0], "start")) {
        var config = QueenConfig{};
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--daemon")) {
                config.daemon = true;
            } else if (std.mem.eql(u8, args[i], "--dry-run")) {
                config.dry_run = true;
            } else if (std.mem.eql(u8, args[i], "--allow-auto-actions")) {
                config.allow_auto_actions = true;
            } else if (std.mem.eql(u8, args[i], "--max-level")) {
                i += 1;
                if (i < args.len) {
                    config.max_auto_level = std.fmt.parseInt(u8, args[i], 10) catch 1;
                }
            } else if (std.mem.eql(u8, args[i], "--no-approval")) {
                config.require_human_approval = false;
            } else if (std.mem.eql(u8, args[i], "--interval")) {
                i += 1;
                if (i < args.len) {
                    config.interval_sec = std.fmt.parseInt(u64, args[i], 10) catch 600;
                }
            } else if (std.mem.eql(u8, args[i], "--god-mode")) {
                config.applyGodMode();
            }
        }
        try runQueenLoop(allocator, config);
    } else if (std.mem.eql(u8, args[0], "status")) {
        try showStatus(allocator);
    } else if (std.mem.eql(u8, args[0], "once")) {
        try runOneCycle(allocator, .{ .dry_run = true });
    } else if (std.mem.eql(u8, args[0], "senses")) {
        try showSenses(allocator);
    } else if (std.mem.eql(u8, args[0], "act")) {
        if (args.len < 2) {
            print("Usage: tri queen act <kind>  (29 actions, use tri queen act ? for list)\n", .{});
            return;
        }
        try runManualAction(allocator, args[1]);
    } else if (std.mem.eql(u8, args[0], "policy")) {
        showPolicy();
    } else if (std.mem.eql(u8, args[0], "history")) {
        showHistory();
    } else {
        printUsage();
    }
}

fn printUsage() void {
    print("{s}" ++ qt.E_CROWN ++ " Queen v4 — Maximum Autonomy{s}\n\n" ++
        "{s}Usage:{s}\n" ++
        "  tri queen supervisor           Autonomous monitoring + self-healing\n" ++
        "  tri queen start [--daemon] [--interval <sec>] [--god-mode]\n" ++
        "  tri queen status\n" ++
        "  tri queen once\n" ++
        "  tri queen senses\n" ++
        "  tri queen act <kind>\n" ++
        "  tri queen policy\n" ++
        "  tri queen history\n\n" ++
        "{s}Options:{s}\n" ++
        "  --daemon              Background (no TTY)\n" ++
        "  --interval N          Cycle sec (default: 600)\n" ++
        "  --dry-run             Monitor only\n" ++
        "  --allow-auto-actions  Enable autonomous actions\n" ++
        "  --max-level N         Max auto safety level (0-2, default: 1)\n" ++
        "  --no-approval         Skip L2 human approval\n" ++
        "  --god-mode            = --allow-auto-actions --max-level 2 --no-approval\n\n" ++
        "{s}Safety Levels (29 actions):{s}\n" ++
        "  L0 read-only (12):  farm/arena/train/ouroboros status, doctor scan, ...\n" ++
        "  L1 soft-write (10): doctor quick/heal, ouroboros, git, notify, arena, fmt\n" ++
        "  L2 dangerous (7):   farm recycle/evolve, cloud spawn/kill, issue create\n\n" ++
        "{s}Hard Bans (12 — NEVER unlocked):{s}\n" ++
        "  Delete running service, flat LR, startCommand, force-push main,\n" ++
        "  deploy w/o env, recycle PRIMARY, re-enable auto-deploy,\n" ++
        "  .sh files, edit generated/, Zenodo publish, patent snapshot, PR merge\n", .{ GOLDEN, RESET, CYAN, RESET, GRAY, RESET, CYAN, RESET, RED, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SENSES / POLICY / HISTORY COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

fn showSenses(allocator: Allocator) !void {
    const snapshot = try faculty_board.collectSnapshot(allocator);
    const senses = queen_senses.collectAllSenses(allocator, snapshot);
    queen_senses.printSensesTable(senses);
}

fn showPolicy() void {
    const config = QueenConfig{}; // defaults
    var counters = queen_policy.ActionCounters{};
    queen_policy.printPolicyMap(config, &counters);
}

fn showHistory() void {
    // Read audit log and show last entries
    const memory = queen_policy.IncidentMemory.init();
    var buf: [2048]u8 = undefined;
    const msg = queen_policy.fmtHistoryTelegram(&buf, &memory);
    print("\n{s}\n", .{msg});
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW: MANUAL ACTION COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

fn runManualAction(allocator: Allocator, kind_str: []const u8) !void {
    const kind = queen_telegram.parseActionKind(kind_str) orelse {
        print("{s}" ++ qt.E_CROSS ++ " Unknown action: {s}{s}\n", .{ RED, kind_str, RESET });
        print("\nAvailable actions ({d}):\n", .{@as(u8, qt.ActionKind.COUNT)});
        for (0..qt.ActionKind.COUNT) |i| {
            const k: qt.ActionKind = @enumFromInt(i);
            const level = queen_policy.actionLevel(k);
            print("  {s} {s} ({s})\n", .{ k.emojiIcon(), k.label(), level.label() });
        }
        return;
    };

    print("{s}" ++ qt.E_BOLT ++ " Executing: {s}{s}\n", .{ GOLDEN, kind.label(), RESET });
    const result = queen_actions.execute(allocator, kind);
    queen_actions.printActionResult(kind, result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════════════

fn runQueenLoop(allocator: Allocator, config: QueenConfig) !void {
    var state = loadState();
    if (state.started_at == 0) state.started_at = std.time.timestamp();

    const tg = qt.initTelegram();

    // v3: Policy state
    var counters = queen_policy.ActionCounters{};
    var incidents = queen_policy.IncidentMemory.init();
    var pending = queen_policy.PendingQueue.init();

    // Start Telegram poll thread if enabled
    var cmd_queue = queen_telegram.CommandQueue{};
    var last_update_id = std.atomic.Value(i64).init(state.tg_last_update_id);
    var poll_running = std.atomic.Value(bool).init(true);
    var poll_ctx = queen_telegram.PollContext{
        .tg = tg,
        .queue = &cmd_queue,
        .last_update_id = &last_update_id,
        .allowed_chat_id = tg.chat_id,
        .running = &poll_running,
    };
    var poll_thread: ?std.Thread = null;
    if (tg.enabled) {
        poll_thread = queen_telegram.startPollThread(&poll_ctx) catch null;
    }
    defer {
        poll_running.store(false, .release);
        if (poll_thread) |t| t.join();
    }

    if (!config.daemon) {
        print("\n{s}" ++ qt.E_CROWN ++ " QUEEN v4 DAEMON{s}\n" ++
            "  " ++ qt.E_TIMER ++ " {d}s | Telegram: {s} | Auto: {s} | L{d} | Approval: {s}\n\n", .{
            GOLDEN,
            RESET,
            config.interval_sec,
            if (tg.enabled) "ON" else "OFF",
            if (config.allow_auto_actions) "ON" else "OFF",
            config.max_auto_level,
            if (config.require_human_approval) "ON" else "OFF",
        });
    }

    // Startup notification
    if (!config.dry_run) {
        var buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, qt.E_CROWN ++ " Queen v4 \xd0\xb7\xd0\xb0\xd0\xbf\xd1\x83\xd1\x89\xd0\xb5\xd0\xbd\xd0\xb0\n\n" ++ // запущена
            qt.E_TIMER ++ " \xd0\x98\xd0\xbd\xd1\x82\xd0\xb5\xd1\x80\xd0\xb2\xd0\xb0\xd0\xbb: {d} \xd0\xbc\xd0\xb8\xd0\xbd\n" ++ // Интервал: N мин
            qt.E_BOLT ++ " Auto: {s} | L{d}\n" ++
            qt.E_GEAR ++ " 12 hard bans | 29 actions\n" ++
            qt.E_CYCLE ++ " 18 senses | 12 rules | /queen", .{
            config.interval_sec / 60,
            if (config.allow_auto_actions) "ON" else "OFF",
            config.max_auto_level,
        }) catch "";
        queen_telegram.tgSend(tg, msg);
    }

    while (true) {
        state.cycle += 1;
        const cycle_start = std.time.timestamp();

        if (!config.daemon) {
            print("{s}=== Queen #{d} ==={s}\n", .{ GOLDEN, state.cycle, RESET });
        }

        // 1. System snapshot
        emitStep(&state, 1, 10, "System snapshot");
        const snapshot = faculty_board.collectSnapshot(allocator) catch |err| {
            if (!config.daemon) print("  {s}" ++ qt.E_CROSS ++ " Snapshot: {s}{s}\n", .{ RED, @errorName(err), RESET });
            sleepInterval(config.interval_sec);
            continue;
        };

        // 2. Collect all 12 senses
        emitStep(&state, 2, 10, "Collecting 18 senses");
        const senses = queen_senses.collectAllSenses(allocator, snapshot);

        // 2b. Write JSON files for SwiftUI
        emitStep(&state, 3, 10, "Writing SwiftUI data");
        writeSensesFile(senses);
        writeTodosFile(senses);
        if (state.cycle == 1) writeActionsFile();

        // 3. Evolution & arena (for alerts and formatting)
        emitStep(&state, 4, 10, "Reading evolution + arena");
        const evo = queen_senses.readEvolutionInfo();
        const arena = ArenaInfo{ .total_battles = senses.arena_battles };

        // 4. Detect alerts → record in incident memory
        emitStep(&state, 5, 10, "Detecting alerts");
        var alerts: [8]Alert = undefined;
        var alert_count: usize = 0;
        detectAlerts(&state, snapshot, evo, &alerts, &alert_count);

        // 5. Send instant alerts + log incidents
        if (!config.dry_run and alert_count > 0) {
            sendAlerts(tg, &alerts, alert_count);
            for (alerts[0..alert_count]) |a| {
                incidents.record(.alert, .doctor_quick, true, a.detailStr());
            }
            if (!snapshot.build_ok) incidents.build_breaks_24h +|= 1;
        }

        // 5b. v3: Policy-gated auto-actions
        emitStep(&state, 6, 10, "Policy-gated auto-actions");
        if (config.allow_auto_actions and !config.dry_run) {
            if (queen_actions.maybeAutoAction(&state, senses, config, &counters, &incidents)) |decision| {
                if (decision.verdict.isAllowed()) {
                    // Execute
                    const result = queen_actions.execute(allocator, decision.action);
                    queen_telegram.tgSendAutoReport(tg, decision.action, result);
                    queen_actions.recordAutoAction(&state, decision.action, &counters);
                    const inc_kind: queen_policy.IncidentKind = if (result.success) .auto_action else .auto_action_fail;
                    incidents.record(inc_kind, decision.action, result.success, result.outputStr());
                    queen_policy.writeAuditEntry("auto", decision.action, decision.verdict, result.success, result.outputStr());
                    if (decision.action == .doctor_quick) incidents.heal_cycles_24h +|= 1;
                    if (!config.daemon) queen_actions.printActionResult(decision.action, result);
                } else if (decision.verdict == .needs_approval) {
                    // Queue for human approval via Telegram
                    if (pending.add(decision.action, "auto-triggered")) |id| {
                        var buf: [256]u8 = undefined;
                        const msg = std.fmt.bufPrint(&buf, qt.E_SIREN ++ " L2 Approval Needed\n\n" ++
                            "{s} {s}\nID: #{d}\n\n/queen approve {d}\n/queen deny {d}", .{
                            decision.action.emojiIcon(),
                            decision.action.label(),
                            id,
                            id,
                            id,
                        }) catch "";
                        queen_telegram.tgSend(tg, msg);
                        incidents.record(.escalation, decision.action, false, "needs approval");
                        queen_policy.writeAuditEntry("auto_pending", decision.action, decision.verdict, false, "queued for approval");
                    }
                } else {
                    // Denied by policy — audit only
                    queen_policy.writeAuditEntry("auto_denied", decision.action, decision.verdict, false, decision.verdict.reason());
                    if (!config.daemon) {
                        print("  " ++ qt.E_STOP ++ " Auto-action {s} denied: {s}\n", .{
                            decision.action.label(), decision.verdict.reason(),
                        });
                    }
                }
            }
        }

        // 5c. v4: Phase 2 Brain — PMC → M1 pipeline (goal-directed planning)
        emitStep(&state, 7, 12, "Phase 2 Brain (PMC → M1)");
        if (config.allow_auto_actions and !config.dry_run) {
            const goal = determineGoal(snapshot, evo, &incidents);
            if (goal) |g| {
                var plan = queen_premotor.MotorPlan.init(g);
                var motor_executor = queen_motor.MotorExecutor.init(allocator);
                const exec_result = motor_executor.executePlan(&plan) catch |err| {
                    if (!config.daemon) {
                        print("  " ++ qt.E_CROSS ++ " Plan execution failed: {s}\n", .{@errorName(err)});
                    }
                    incidents.record(.auto_action_fail, .doctor_quick, false, @errorName(err));
                    continue;
                };

                if (exec_result.success) {
                    if (!config.daemon) {
                        print("  " ++ qt.E_BOLT ++ " Phase 2: {s} plan executed ({d}/{d} steps, {d}ms)\n", .{
                            g.label(), exec_result.steps_executed, plan.sequence.step_count, exec_result.total_duration_ms,
                        });
                    }
                    if (g == .heal_system) incidents.heal_cycles_24h +|= 1;
                } else {
                    if (!config.daemon) {
                        print("  " ++ qt.E_CROSS ++ " Phase 2: {s} plan failed at step {d}: {s}\n", .{
                            g.label(), exec_result.failed_at orelse 0, exec_result.error_msg,
                        });
                    }
                    incidents.record(.auto_action_fail, .doctor_quick, false, exec_result.error_msg);
                }

                queen_policy.writeAuditEntry(
                    "phase2",
                    .doctor_quick,
                    if (exec_result.success) .allowed else .denied_escalated,
                    exec_result.success,
                    if (exec_result.success) @as([]const u8, "plan executed") else exec_result.error_msg,
                );
            }
        }

        // 5d. v5: Phase 3 Brain — DLPFC autonomous decision engine (READ→THINK→ACT→SPEAK)
        emitStep(&state, 8, 13, "Phase 3 Brain (DLPFC)");
        if (config.allow_auto_actions and !config.dry_run) {
            // Build DLPFC context
            var dlpfc_ctx = queen_dlpfc.DecisionContext{
                .allocator = allocator,
                .farm = .{}, // Will be populated by readSenses
                .issues = .{}, // Will be populated by readSenses
                .mu_heartbeat = .{}, // Will be populated by readSenses
                .config = config,
                .state = &state,
                .counters = &counters,
                .incidents = &incidents,
                .build_ok = snapshot.build_ok,
                .dirty_files = snapshot.dirty_files,
            };

            // READ phase
            queen_dlpfc.readSenses(allocator, &dlpfc_ctx) catch |err| {
                if (!config.daemon) {
                    print("  {s} DLPFC READ failed: {s}\n", .{qt.E_WRENCH, @errorName(err)});
                }
            };

            // THINK phase
            const decision = queen_dlpfc.decide(&dlpfc_ctx) catch |err| blk: {
                if (!config.daemon) {
                    print("  {s} DLPFC THINK failed: {s}\n", .{qt.E_WRENCH, @errorName(err)});
                }
                break :blk null;
            };

            if (decision) |d| {
                // ACT phase
                const act_result = queen_dlpfc.act(&dlpfc_ctx, d) catch |err| {
                    incidents.record(.auto_action_fail, d.action, false, @errorName(err));
                    continue;
                };

                // SPEAK phase
                queen_dlpfc.speak(&dlpfc_ctx, d, act_result) catch |err| {
                    if (!config.daemon) {
                        print("  {s} DLPFC SPEAK failed: {s}\n", .{qt.E_WRENCH, @errorName(err)});
                    }
                };

                // Track success/failure
                if (act_result.success) {
                    if (!config.daemon) {
                        print("  " ++ qt.E_BOLT ++ " Phase 3: {s} executed ({d}ms)\n", .{
                            d.action.label(), act_result.duration_ms,
                        });
                    }
                }
            }
        }

        // 5e. Expire old pending approvals
        pending.expireOld();

        // 5f. Process Telegram commands (v3: with policy context)
        while (cmd_queue.pop()) |cmd| {
            queen_telegram.dispatchCommand(.{
                .allocator = allocator,
                .tg = tg,
                .senses = senses,
                .config = config,
                .counters = &counters,
                .incidents = &incidents,
                .pending = &pending,
            }, cmd);
            state.tg_last_update_id = last_update_id.load(.acquire);
        }

        // 5g. Read UI user input (mid-flight steering)
        readUserInput(&state);

        // 5h. Read UI action queue (SwiftUI button actions)
        readActionsQueue(allocator, &state);

        // 6. Hourly heartbeat (pinned)
        emitStep(&state, 8, 12, "Heartbeat check");
        if (shouldSendHeartbeat(state, cycle_start)) {
            var msg_buf: [2048]u8 = undefined;
            const msg = fmtHeartbeat(&msg_buf, snapshot, evo, arena, senses);
            if (!config.dry_run) {
                if (state.pinned_msg_id) |mid| {
                    queen_telegram.tgEdit(tg, mid, msg);
                } else {
                    const mid = queen_telegram.tgSendCapture(tg, msg);
                    if (mid) |m| {
                        state.pinned_msg_id = m;
                        queen_telegram.tgPin(tg, m);
                    }
                }
            }
            state.last_heartbeat = cycle_start;
            if (!config.daemon) print("  " ++ qt.E_CHECK ++ " Heartbeat\n", .{});
        }

        // 7. Daily summary (23:00)
        emitStep(&state, 9, 12, "Daily summary check");
        if (shouldSendDaily(state, cycle_start)) {
            var msg_buf: [2048]u8 = undefined;
            const msg = fmtDaily(&msg_buf, snapshot, evo, arena, senses, state);
            if (!config.dry_run) queen_telegram.tgSend(tg, msg);
            state.last_daily = cycle_start;
            if (!config.daemon) print("  " ++ qt.E_CHECK ++ " Daily\n", .{});
        }

        // 8. Update delta state
        emitStep(&state, 10, 12, "Update delta state");
        state.prev_build_ok = snapshot.build_ok;
        state.prev_dirty = snapshot.dirty_files;
        if (evo.best_ppl < state.prev_best_ppl) state.prev_best_ppl = evo.best_ppl;

        // 9. TTY summary
        if (!config.daemon) printCycleSummary(snapshot, evo, arena, alert_count, senses, state);

        // 10. Persist
        emitStep(&state, 11, 12, "Persist state");
        saveState(state);
        logEvent(&state, snapshot, alert_count);
        writeAuditSummary(config, &counters);

        sleepInterval(config.interval_sec);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUPERVISOR MODE — Autonomous monitoring + self-healing
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runSupervisorMode(allocator: Allocator) !void {
    const cortex = @import("queen_cortex.zig");
    const cerebellum = @import("cerebellum.zig");
    const queen_ofc = @import("queen_ofc.zig");
    const queen_vmpfc = @import("queen_vmpfc.zig");

    print("\n{s}" ++ qt.E_CROWN ++ " Queen Supervisor Mode — Autonomous Monitoring{s}\n", .{ GOLDEN, RESET });
    print("  Integrating all brain cells for self-healing...\n\n", .{});

    const tg = qt.initTelegram();

    // Initial notification
    if (tg.enabled) {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, qt.E_CROWN ++ " Supervisor \xd0\xb7\xd0\xb0\xd0\xbf\xd1\x83\xd1\x89\xd0\xb5\xd0\xbd\n\n" ++ // запущен
            qt.E_BRAIN ++ " 5 PFC cells\n" ++
            qt.E_DNA ++ " Cerebellum coordinator\n" ++
            qt.E_CYCLE ++ " PMC + M1 motor hierarchy\n" ++
            qt.E_EYE ++ " Continuous health monitoring", .{}) catch "";
        queen_telegram.tgSend(tg, msg);
    }

    var cycle: u32 = 0;
    var last_heal_cycle: u32 = 0;

    while (true) {
        cycle += 1;
        const cycle_start = std.time.timestamp();

        print("{s}=== Supervisor Cycle #{d} ==={s}\n", .{ GOLDEN, cycle, RESET });

        // 1. Collect health from all PFC cells
        emitSupervisorStep(1, 8, "Collecting PFC cell health");
        const pfc_health = cortex.health(allocator) catch blk: {
            print("  {s}" ++ qt.E_CROSS ++ " Cortex health collection failed{s}\n", .{ RED, RESET });
            break :blk cortex.CellHealth{
                .dlpfc = .{ .status = .broken, .cycle = 0, .last_check = cycle_start },
                .vmpfc = .{ .status = .broken, .cycle = 0, .last_check = cycle_start },
                .ofc = .{ .status = .broken, .cycle = 0, .last_check = cycle_start },
                .vlpfc = .{ .status = .broken, .cycle = 0, .last_check = cycle_start },
                .dmpfc = .{ .status = .broken, .cycle = 0, .last_check = cycle_start },
            };
        };

        const all_healthy = cortex.isHealthy(&pfc_health);
        const grade = if (all_healthy) "A" else "C";

        // 2. Collect Cerebellum status
        emitSupervisorStep(2, 8, "Checking Cerebellum coordination");
        const cerebellum_health = cerebellum.health();

        // 3. Get system snapshot
        emitSupervisorStep(3, 8, "System snapshot");
        const snapshot = faculty_board.collectSnapshot(allocator) catch |err| {
            print("  {s}" ++ qt.E_CROSS ++ " Snapshot failed: {s}{s}\n", .{ RED, @errorName(err), RESET });
            sleepInterval(300);
            continue;
        };

        const senses = queen_senses.collectAllSenses(allocator, snapshot);

        // 4. Analyze system health
        emitSupervisorStep(4, 8, "Analyzing system health");
        const health_analysis = analyzeSystemHealth(snapshot, senses, pfc_health, cerebellum_health);

        // 5. Print health dashboard
        printSupervisorDashboard(cycle, pfc_health, cerebellum_health, health_analysis, senses);

        // 6. Self-healing actions
        emitSupervisorStep(5, 8, "Executing self-healing");
        if (health_analysis.critical_count > 0 or health_analysis.warning_count > 2) {
            if (cycle - last_heal_cycle >= 3) { // Rate limit healing
                const healing_result = executeSelfHealing(allocator, health_analysis, senses, snapshot);
                last_heal_cycle = cycle;

                // Report healing via OFC
                if (tg.enabled) {
                    var report_buf: [512]u8 = undefined;
                    const mood = queen_ofc.inferMood(snapshot.build_ok, senses.ouroboros_score, false);
                    const report = std.fmt.bufPrint(&report_buf,
                        "{s} Supervisor Healing #{d}\n\n" ++
                        "{s} Actions: {d}\n" ++
                        "{s} Success: {d} | Fail: {d}\n" ++
                        "PFC Grade: {s}",
                        .{
                        mood.emoji(),
                        cycle,
                        qt.E_WRENCH,
                        healing_result.actions_taken,
                        if (healing_result.all_success) qt.E_CHECK else qt.E_CROSS,
                        healing_result.success_count,
                        healing_result.failure_count,
                        grade,
                        }
                    ) catch "";
                    queen_telegram.tgSend(tg, report);
                }
            }
        }

        // 7. Value assessment via VMPFC
        emitSupervisorStep(6, 8, "VMPFC value assessment");
        if (cycle % 10 == 0) { // Every 10 cycles, do farm value assessment
            const farm_value = queen_vmpfc.assessFarmAction(allocator, .recycle, senses.farm_best_ppl) catch continue;
            defer allocator.free(farm_value.reasonStr());

            if (farm_value.recommendation == .execute and farm_value.roi > 3.0) {
                print("  " ++ qt.E_DNA ++ " VMPFC recommends farm recycle (ROI: {d:.1})\n", .{farm_value.roi});
            }
        }

        // 8. Resource coordination via Cerebellum
        emitSupervisorStep(7, 8, "Cerebellum resource check");
        const resource_pool = cerebellum.getResourcePool(allocator) catch .{};
        const utilization = resource_pool.utilization();
        const health_score = resource_pool.healthScore();

        print("  " ++ qt.E_DNA ++ " Resources: {d:.0}% util | Score: {d:.1}\n", .{ utilization * 100, health_score });

        // 9. Plan next action via PMC if needed
        emitSupervisorStep(8, 8, "PMC goal planning");
        if (health_analysis.critical_count > 0) {
            const goal = determineGoal(snapshot, EvolutionInfo{}, &queen_policy.IncidentMemory.init());
            if (goal) |g| {
                print("  " ++ qt.E_BRAIN ++ " PMC Goal: {s} (priority {d})\n", .{ g.label(), g.priority() });

                // Create motor plan via PMC
                const plan = queen_premotor.MotorPlan.init(g);

                // In god-mode, would execute via M1 here
                _ = plan;
                _ = queen_motor;
            }
        }

        // 10. Report status summary
        print("  {s}" ++ qt.E_CHECK ++ " Cycle {d}: {s} | Critical: {d} | Warnings: {d}{s}\n\n", .{
            if (health_analysis.critical_count == 0) GREEN else RED,
            cycle,
            if (all_healthy) "HEALTHY" else "RECOVERING",
            health_analysis.critical_count,
            health_analysis.warning_count,
            RESET,
        });

        // 11. Save supervisor state
        saveSupervisorState(cycle, pfc_health, health_analysis);

        // Sleep before next cycle (5 min default for supervisor)
        sleepInterval(300);
    }
}

const HealthAnalysis = struct {
    overall_status: Status = .healthy,
    critical_count: u8 = 0,
    warning_count: u8 = 0,
    issues: [16]Issue = undefined,
    issue_count: u8 = 0,

    const Status = enum {
        healthy,
        warning,
        critical,
    };

    const Issue = struct {
        source: []const u8,
        description: [128]u8 = undefined,
        desc_len: usize = 0,
        severity: Status = .warning,
    };
};

fn analyzeSystemHealth(
    snap: FacultySnapshot,
    senses: qt.SenseResult,
    pfc_health: anytype,
    cerebellum_health: anytype,
) HealthAnalysis {
    _ = cerebellum_health; // Currently unused, reserved for future use
    var analysis = HealthAnalysis{};

    // Build status
    if (!snap.build_ok) {
        addIssue(&analysis, "Build", "Build broken - zig build fails", .critical);
    }

    // PFC cells
    if (pfc_health.dlpfc.status != .healthy) {
        addIssue(&analysis, "DLPFC", "Decision engine unhealthy", .warning);
    }
    if (pfc_health.vmpfc.status != .healthy) {
        addIssue(&analysis, "VMPFC", "Value assessment impaired", .warning);
    }
    if (pfc_health.ofc.status != .healthy) {
        addIssue(&analysis, "OFC", "Communication degraded", .warning);
    }

    // Ouroboros score
    if (senses.ouroboros_score < 40) {
        addIssue(&analysis, "Ouroboros", "System health critical", .critical);
    } else if (senses.ouroboros_score < 70) {
        addIssue(&analysis, "Ouroboros", "System health degraded", .warning);
    }

    // Farm issues
    if (senses.farm_idle_count > 5) {
        addIssue(&analysis, "Farm", "Many idle workers", .warning);
    }
    if (senses.farm_best_ppl > 20.0) {
        addIssue(&analysis, "Farm", "Poor best PPL", .warning);
    }

    // Dirty files
    if (senses.dirty_files > 100) {
        addIssue(&analysis, "Git", "Excessive dirty files", .warning);
    }

    // Keys
    if (senses.keys_present < 3) {
        addIssue(&analysis, "Auth", "Many keys expired", .critical);
    }

    // Determine overall status
    if (analysis.critical_count > 0) {
        analysis.overall_status = .critical;
    } else if (analysis.warning_count > 0) {
        analysis.overall_status = .warning;
    }

    return analysis;
}

fn addIssue(analysis: *HealthAnalysis, source: []const u8, desc: []const u8, severity: HealthAnalysis.Status) void {
    if (analysis.issue_count >= 16) return;

    var issue = HealthAnalysis.Issue{
        .source = source,
        .severity = severity,
    };
    const len = @min(desc.len, issue.description.len);
    @memcpy(issue.description[0..len], desc[0..len]);
    issue.desc_len = len;

    analysis.issues[analysis.issue_count] = issue;
    analysis.issue_count += 1;

    if (severity == .critical) {
        analysis.critical_count += 1;
    } else {
        analysis.warning_count += 1;
    }
}

const HealingResult = struct {
    actions_taken: u8 = 0,
    success_count: u8 = 0,
    failure_count: u8 = 0,
    all_success: bool = true,
};

fn executeSelfHealing(
    allocator: Allocator,
    analysis: HealthAnalysis,
    senses: qt.SenseResult,
    snapshot: FacultySnapshot,
) HealingResult {
    _ = senses; // Reserved for future healing logic
    _ = snapshot; // Reserved for future healing logic
    var result = HealingResult{};

    for (analysis.issues[0..analysis.issue_count]) |issue| {
        // Only auto-heal warnings and some critical issues
        if (issue.severity == .critical and std.mem.eql(u8, issue.source, "Auth")) continue;

        // Map issues to actions
        const action = switch (issue.severity) {
            .healthy => continue,
            .warning => qt.ActionKind.doctor_quick,
            .critical => qt.ActionKind.doctor_heal,
        };

        print("  {s}" ++ qt.E_WRENCH ++ " Healing: {s} - {s}{s}\n", .{
            GOLDEN, issue.source, issue.description[0..issue.desc_len], RESET,
        });

        const exec_result = queen_actions.execute(allocator, action);
        result.actions_taken += 1;

        if (exec_result.success) {
            result.success_count += 1;
            print("    " ++ qt.E_CHECK ++ " Success ({d}ms)\n", .{exec_result.duration_ms});
        } else {
            result.failure_count += 1;
            result.all_success = false;
            print("    " ++ qt.E_CROSS ++ " Failed: {s}\n", .{exec_result.outputStr()});
        }

        // Small delay between actions
        std.Thread.sleep(1 * std.time.ns_per_s);
    }

    return result;
}

fn printSupervisorDashboard(
    cycle: u32,
    pfc_health: anytype,
    cerebellum_health: anytype,
    analysis: HealthAnalysis,
    senses: qt.SenseResult,
) void {
    print("\n  {s}" ++ qt.E_CROWN ++ " Supervisor Dashboard #{d}{s}\n", .{ GOLDEN, cycle, RESET });

    // PFC Status
    const pfc_status = if (pfc_health.dlpfc.status == .healthy) qt.E_CHECK else qt.E_CROSS;
    print("    {s} PFC: {s} DLPFC={s} VMPFC={s} OFC={s}\n", .{
        qt.E_BRAIN,
        pfc_status,
        statusEmoji(pfc_health.dlpfc.status),
        statusEmoji(pfc_health.vmpfc.status),
        statusEmoji(pfc_health.ofc.status),
    });

    // Cerebellum
    print("    {s} Cerebellum: {s}\n", .{ qt.E_DNA, statusEmoji(cerebellum_health.status) });

    // System status
    const sys_status = switch (analysis.overall_status) {
        .healthy => qt.E_CHECK,
        .warning => qt.E_WRENCH,
        .critical => qt.E_SIREN,
    };
    print("    {s} System: {s} ({d} critical, {d} warnings)\n", .{
        qt.E_EYE,
        sys_status,
        analysis.critical_count,
        analysis.warning_count,
    });

    // Key metrics
    print("    {s} Build: {s} | Ouroboros: {d:.0} | Dirty: {d}\n", .{
        qt.E_CLIP,
        if (senses.build_ok) "OK" else "FAIL",
        senses.ouroboros_score,
        senses.dirty_files,
    });
}

fn statusEmoji(status: anytype) []const u8 {
    return switch (status) {
        .healthy => qt.E_CHECK,
        .weak => qt.E_WRENCH,
        .broken => qt.E_CROSS,
    };
}

fn saveSupervisorState(cycle: u32, pfc_health: anytype, analysis: HealthAnalysis) void {
    _ = pfc_health; // Currently unused, reserved for future use
    const path = ".trinity/queen/supervisor_state.json";
    const file = std.fs.cwd().createFile(path, .{}) catch return;
    defer file.close();

    var buf: [512]u8 = undefined;
    const data = std.fmt.bufPrint(&buf,
        \\{{"cycle":{d},"critical_count":{d},"warning_count":{d},"pfc_healthy":{s}}}
    , .{
        cycle,
        analysis.critical_count,
        analysis.warning_count,
        if (analysis.overall_status == .healthy) "true" else "false",
    }) catch return;

    _ = file.write(data) catch {};
}

fn runOneCycle(allocator: Allocator, config: QueenConfig) !void {
    print("\n{s}" ++ qt.E_CROWN ++ " QUEEN v2 — \xd0\x9e\xd0\xb4\xd0\xb8\xd0\xbd \xd1\x86\xd0\xb8\xd0\xba\xd0\xbb{s}\n\n", .{ GOLDEN, RESET }); // Один цикл

    const snapshot = try faculty_board.collectSnapshot(allocator);
    const senses = queen_senses.collectAllSenses(allocator, snapshot);
    const evo = queen_senses.readEvolutionInfo();
    const arena = ArenaInfo{ .total_battles = senses.arena_battles };

    // Write JSON files for SwiftUI
    writeSensesFile(senses);
    writeActionsFile();
    writeTodosFile(senses);

    var state = loadState();
    emitEvent(&state, "thought", "Collecting senses: build/farm/arena/issues");
    var alerts: [8]Alert = undefined;
    var alert_count: usize = 0;
    detectAlerts(&state, snapshot, evo, &alerts, &alert_count);

    // Print senses table
    queen_senses.printSensesTable(senses);

    printCycleSummary(snapshot, evo, arena, alert_count, senses, state);

    if (alert_count > 0) {
        print("\n  {s}" ++ qt.E_FIRE ++ " Alerts ({d}):{s}\n", .{ RED, alert_count, RESET });
        for (alerts[0..alert_count]) |a| {
            print("    {s} {s}: {s}\n", .{ a.kind.emoji(), a.kind.labelRu(), a.detailStr() });
        }
    }

    // Heartbeat preview
    var msg_buf: [2048]u8 = undefined;
    const hb = fmtHeartbeat(&msg_buf, snapshot, evo, arena, senses);
    print("\n  {s}" ++ qt.E_ROBOT ++ " Telegram preview:{s}\n  ────────────────────\n  {s}\n  ────────────────────\n", .{ CYAN, RESET, hb });

    if (!config.dry_run) {
        const tg = qt.initTelegram();
        if (tg.enabled) {
            queen_telegram.tgSend(tg, hb);
            print("  {s}" ++ qt.E_CHECK ++ " Sent!{s}\n", .{ GREEN, RESET });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALERTER — Event Detection
// ═══════════════════════════════════════════════════════════════════════════════

fn detectAlerts(state: *QueenState, snap: FacultySnapshot, evo: EvolutionInfo, alerts: *[8]Alert, count: *usize) void {
    count.* = 0;

    // Build broken (was OK, now broken)
    if (state.prev_build_ok and !snap.build_ok) {
        addAlert(alerts, count, .build_broken, "zig build \xd1\x83\xd0\xbf\xd0\xb0\xd0\xbb"); // zig build упал
    }

    // New PPL record
    if (evo.best_ppl < state.prev_best_ppl and evo.best_ppl < 900.0) {
        var buf: [256]u8 = undefined;
        const detail = std.fmt.bufPrint(&buf, "{s} \xd0\xb4\xd0\xbe\xd1\x81\xd1\x82\xd0\xb8\xd0\xb3 PPL {d:.2}\n\xd1\x88\xd0\xb0\xd0\xb3 {d}K (\xd0\xb1\xd1\x8b\xd0\xbb\xd0\xbe {d:.2})", .{
            evo.bestNameStr(),    evo.best_ppl,
            evo.best_step / 1000, state.prev_best_ppl,
        }) catch "new record";
        addAlert(alerts, count, .new_ppl_record, detail);
    }

    // Dirty overload (> 50)
    if (snap.dirty_files > 50 and state.prev_dirty <= 50) {
        var buf: [256]u8 = undefined;
        const detail = std.fmt.bufPrint(&buf, "{d} dirty \xd1\x84\xd0\xb0\xd0\xb9\xd0\xbb\xd0\xbe\xd0\xb2 (\xd0\xb1\xd1\x8b\xd0\xbb\xd0\xbe {d})", .{
            snap.dirty_files, state.prev_dirty,
        }) catch "dirty overload";
        addAlert(alerts, count, .dirty_overload, detail);
    }
}

fn addAlert(alerts: *[8]Alert, count: *usize, kind: AlertKind, detail: []const u8) void {
    if (count.* >= 8) return;
    var a = Alert{ .kind = kind };
    const len = @min(detail.len, a.detail.len);
    @memcpy(a.detail[0..len], detail[0..len]);
    a.detail_len = len;
    alerts[count.*] = a;
    count.* += 1;
}

fn sendAlerts(tg: qt.TgConfig, alerts: *const [8]Alert, count: usize) void {
    for (alerts[0..count]) |a| {
        var buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{s} {s}\n\n{s}", .{
            a.kind.emoji(), a.kind.labelRu(), a.detailStr(),
        }) catch continue;
        queen_telegram.tgSend(tg, msg);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPORTER — Telegram Message Formatting (v2: includes senses)
// ═══════════════════════════════════════════════════════════════════════════════

fn fmtHeartbeat(buf: []u8, snap: FacultySnapshot, evo: EvolutionInfo, arena: ArenaInfo, senses: qt.SenseResult) []const u8 {
    const ts = std.time.timestamp();
    const day_sec: u64 = @intCast(@mod(ts, 86400));
    const hour = day_sec / 3600;
    const minute = (day_sec % 3600) / 60;

    const build_icon = if (snap.build_ok) qt.E_CHECK else qt.E_CROSS;

    return std.fmt.bufPrint(buf, qt.E_CROWN ++ " Queen v2 | {d:0>2}:{d:0>2}\n" ++
        "\n" ++
        qt.E_BRAIN ++ " SEVO\n" ++
        "   {s} \xe2\x80\x94 PPL {d:.1} (\xd1\x88\xd0\xb0\xd0\xb3 {d}K)\n" ++ // — PPL ... (шаг ...K)
        "   {d} \xd0\xba\xd0\xbe\xd0\xbd\xd1\x84\xd0\xb8\xd0\xb3\xd0\xbe\xd0\xb2 | {d} \xd1\x81\xd0\xb5\xd1\x80\xd0\xb2\xd0\xb8\xd1\x81\xd0\xbe\xd0\xb2\n" ++ // конфигов | сервисов
        "\n" ++
        qt.E_SWORDS ++ " Arena: {d} \xd0\xb1\xd0\xbe\xd1\x91\xd0\xb2\n" ++ // боёв
        "\n" ++
        qt.E_CLIP ++ " Issues: {d} | Dirty: {d}\n" ++
        "{s} Build {s} | V={d:.2} | {d}/6 \xd0\xb0\xd0\xb3\xd0\xb5\xd0\xbd\xd1\x82\xd0\xbe\xd0\xb2\n" ++ // агентов
        "\n" ++
        qt.E_EYE ++ " Senses: {d}%% tests | {d:.1}GB disk\n" ++
        qt.E_KEY ++ " Keys: {d}/{d} | XP: {d}\n" ++
        "{s} {s}", .{
        hour,
        minute,
        evo.bestNameStr(),
        evo.best_ppl,
        evo.best_step / 1000,
        evo.total_configs,
        evo.service_count,
        arena.total_battles,
        snap.open_issues,
        snap.dirty_files,
        build_icon,
        if (snap.build_ok) "OK" else "FAIL",
        snap.v_number,
        snap.activeFaculty(),
        senses.test_rate,
        senses.disk_free_gb,
        senses.keys_present,
        senses.keys_total,
        senses.experience_count,
        senses.healthEmoji(),
        if (!senses.build_ok) "BUILD BROKEN" else if (senses.ouroboros_score >= 70) "HEALTHY" else "RECOVERING",
    }) catch buf[0..0];
}

fn fmtDaily(buf: []u8, snap: FacultySnapshot, evo: EvolutionInfo, arena: ArenaInfo, senses: qt.SenseResult, state: QueenState) []const u8 {
    const uptime_h = @divTrunc(std.time.timestamp() - state.started_at, 3600);

    return std.fmt.bufPrint(buf, qt.E_CROWN ++ " Queen v2 Daily\n" ++
        "\n" ++
        qt.E_DNA ++ " SEVO\n" ++
        "   \xd0\x9b\xd0\xb8\xd0\xb4\xd0\xb5\xd1\x80: {s} \xe2\x80\x94 PPL {d:.1} (\xd1\x88\xd0\xb0\xd0\xb3 {d}K)\n" ++ // Лидер: ... — PPL ... (шаг ...K)
        "   {d} \xd0\xba\xd0\xbe\xd0\xbd\xd1\x84\xd0\xb8\xd0\xb3\xd0\xbe\xd0\xb2 | {d} \xd1\x81\xd0\xb5\xd1\x80\xd0\xb2\xd0\xb8\xd1\x81\xd0\xbe\xd0\xb2\n" ++ // конфигов | сервисов
        "\n" ++
        qt.E_SWORDS ++ " Arena: {d} \xd0\xb1\xd0\xbe\xd1\x91\xd0\xb2\n" ++ // боёв
        "\n" ++
        qt.E_CLIP ++ " Issues: {d} open\n" ++
        qt.E_WRENCH ++ " Build: {s} | Dirty: {d} | V={d:.2}\n" ++
        qt.E_ROBOT ++ " Faculty: {d}/6\n" ++
        "\n" ++
        qt.E_EYE ++ " Senses: {d}%% tests | {d:.1}GB disk | {d}/{d} keys\n" ++
        qt.E_CYCLE ++ " Ouroboros: {d:.1} | XP: {d}\n" ++
        "\n" ++
        qt.E_CYCLE ++ " \xd0\xa6\xd0\xb8\xd0\xba\xd0\xbb: {d} | Uptime: {d}h", // Цикл: N | Uptime: Nh
        .{
            evo.bestNameStr(),
            evo.best_ppl,
            evo.best_step / 1000,
            evo.total_configs,
            evo.service_count,
            arena.total_battles,
            snap.open_issues,
            if (snap.build_ok) "OK" else "FAIL",
            snap.dirty_files,
            snap.v_number,
            snap.activeFaculty(),
            senses.test_rate,
            senses.disk_free_gb,
            senses.keys_present,
            senses.keys_total,
            senses.ouroboros_score,
            senses.experience_count,
            state.cycle,
            uptime_h,
        }) catch buf[0..0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULER — Timing
// ═══════════════════════════════════════════════════════════════════════════════

fn shouldSendHeartbeat(state: QueenState, now: i64) bool {
    return (now - state.last_heartbeat) >= 3600;
}

fn shouldSendDaily(state: QueenState, now: i64) bool {
    if ((now - state.last_daily) < 82800) return false;
    const day_sec: u64 = @intCast(@mod(now, 86400));
    const hour = day_sec / 3600;
    return (hour == 23);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 2 BRAIN — Goal Planner (PFC → PMC)
// ═══════════════════════════════════════════════════════════════════════════════

fn determineGoal(snap: FacultySnapshot, evo: EvolutionInfo, incidents: *const queen_policy.IncidentMemory) ?queen_premotor.Goal {
    if (!snap.build_ok) return .heal_system;

    const fail_rate: f32 = if (incidents.total_auto_actions_24h > 0)
        @as(f32, @floatFromInt(incidents.total_auto_fails_24h)) / @as(f32, @floatFromInt(incidents.total_auto_actions_24h))
    else
        0;
    if (fail_rate > 0.5 and incidents.total_auto_fails_24h >= 3) {
        return .assess_health;
    }

    if (evo.service_count == 0) return .check_farm;
    if (snap.dirty_files > 100) return .cleanup_cloud;

    const ts = std.time.timestamp();
    const hour: u64 = @intCast(@mod(@divTrunc(ts, 3600), 24));
    if (hour == 9) return .research_update;

    return null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════

fn loadState() QueenState {
    const file = std.fs.cwd().openFile(qt.STATE_PATH, .{}) catch return QueenState{};
    defer file.close();

    var buf: [1024]u8 = undefined;
    const n = file.read(&buf) catch return QueenState{};
    const data = buf[0..n];

    var state = QueenState{};
    if (qt.findJsonU32(data, "\"cycle\":")) |v| state.cycle = v;
    if (qt.findJsonI64(data, "\"last_heartbeat\":")) |v| state.last_heartbeat = v;
    if (qt.findJsonI64(data, "\"last_daily\":")) |v| state.last_daily = v;
    if (qt.findJsonBool(data, "\"prev_build_ok\":")) |v| state.prev_build_ok = v;
    if (qt.findJsonF32(data, "\"prev_best_ppl\":")) |v| state.prev_best_ppl = v;
    if (qt.findJsonU32(data, "\"prev_dirty\":")) |v| state.prev_dirty = @intCast(v);
    if (qt.findJsonI64(data, "\"started_at\":")) |v| state.started_at = v;
    if (qt.findJsonI64(data, "\"pinned_msg_id\":")) |v| state.pinned_msg_id = v;
    if (qt.findJsonU32(data, "\"auto_actions_this_hour\":")) |v| state.auto_actions_this_hour = @intCast(@min(v, 255));
    if (qt.findJsonI64(data, "\"last_auto_action_ts\":")) |v| state.last_auto_action_ts = v;
    if (qt.findJsonU32(data, "\"last_build_heal_cycle\":")) |v| state.last_build_heal_cycle = v;
    if (qt.findJsonI64(data, "\"tg_last_update_id\":")) |v| state.tg_last_update_id = v;
    if (qt.findJsonU32(data, "\"event_seq\":")) |v| state.event_seq = v;

    return state;
}

fn saveState(state: QueenState) void {
    var buf: [768]u8 = undefined;
    const data = std.fmt.bufPrint(&buf,
        \\{{"cycle":{d},"last_heartbeat":{d},"last_daily":{d},"prev_build_ok":{s},"prev_best_ppl":{d:.2},"prev_dirty":{d},"started_at":{d},"pinned_msg_id":{d},"auto_actions_this_hour":{d},"last_auto_action_ts":{d},"last_build_heal_cycle":{d},"tg_last_update_id":{d},"event_seq":{d}}}
    , .{
        state.cycle,
        state.last_heartbeat,
        state.last_daily,
        if (state.prev_build_ok) "true" else "false",
        state.prev_best_ppl,
        state.prev_dirty,
        state.started_at,
        state.pinned_msg_id orelse @as(i64, 0),
        state.auto_actions_this_hour,
        state.last_auto_action_ts,
        state.last_build_heal_cycle,
        state.tg_last_update_id,
        state.event_seq,
    }) catch return;

    const file = std.fs.cwd().createFile(qt.STATE_PATH, .{}) catch return;
    defer file.close();
    _ = file.write(data) catch {};
}

fn showStatus(allocator: Allocator) !void {
    const state = loadState();
    const snap = try faculty_board.collectSnapshot(allocator);
    const senses = queen_senses.collectAllSenses(allocator, snap);
    const evo = queen_senses.readEvolutionInfo();

    const uptime = std.time.timestamp() - state.started_at;
    const hours = @divTrunc(uptime, 3600);
    const minutes = @divTrunc(@mod(uptime, 3600), 60);

    print("\n{s}" ++ qt.E_CROWN ++ " Queen v2 Status{s}\n\n" ++
        "  Cycle:     {d}\n" ++
        "  Uptime:    {d}h {d}m\n" ++
        "  Build:     {s}{s}{s}\n" ++
        "  Dirty:     {d}\n" ++
        "  Issues:    {d}\n" ++
        "  Faculty:   {d}/6\n" ++
        "  SEVO:      PPL {d:.1} ({s})\n" ++
        "  Arena:     {d} battles\n" ++
        "  Ouroboros: {d:.1}\n" ++
        "  Keys:      {d}/{d}\n" ++
        "  Disk:      {d:.1} GB\n" ++
        "  Telegram:  {s}\n" ++
        "  Auto:      {d}/3 this hour\n\n", .{
        GOLDEN,
        RESET,
        state.cycle,
        hours,
        minutes,
        if (snap.build_ok) GREEN else RED,
        if (snap.build_ok) "OK" else "FAIL",
        RESET,
        snap.dirty_files,
        snap.open_issues,
        snap.activeFaculty(),
        evo.best_ppl,
        evo.bestNameStr(),
        senses.arena_battles,
        senses.ouroboros_score,
        senses.keys_present,
        senses.keys_total,
        senses.disk_free_gb,
        if (qt.initTelegram().enabled) "ON" else "OFF",
        state.auto_actions_this_hour,
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CYCLE SUMMARY (TTY)
// ═══════════════════════════════════════════════════════════════════════════════

fn printCycleSummary(snap: FacultySnapshot, evo: EvolutionInfo, arena: ArenaInfo, alert_count: usize, senses: qt.SenseResult, state: QueenState) void {
    const build_s = if (snap.build_ok) GREEN ++ "OK" ++ RESET else RED ++ "FAIL" ++ RESET;
    print("  " ++ qt.E_WRENCH ++ " Build: {s} | Dirty: {d} | Issues: {d}\n", .{ build_s, snap.dirty_files, snap.open_issues });
    print("  " ++ qt.E_BRAIN ++ " SEVO: PPL={d:.1} ({s}) | {d} configs\n", .{ evo.best_ppl, evo.bestNameStr(), evo.total_configs });
    print("  " ++ qt.E_SWORDS ++ " Arena: {d} | Faculty: {d}/6\n", .{ arena.total_battles, snap.activeFaculty() });
    print("  " ++ qt.E_EYE ++ " Senses: {d}%% tests | {d:.1}GB | {d}/{d} keys | {d} xp\n", .{
        senses.test_rate, senses.disk_free_gb, senses.keys_present, senses.keys_total, senses.experience_count,
    });
    if (alert_count > 0) {
        print("  {s}" ++ qt.E_FIRE ++ " {d} alert(s){s}\n", .{ RED, alert_count, RESET });
    }
    const since_hb = std.time.timestamp() - state.last_heartbeat;
    const next_hb_min = if (state.last_heartbeat == 0) @as(i64, 0) else @divTrunc(@as(i64, 3600) - since_hb, 60);
    print("  " ++ qt.E_CYCLE ++ " #{d} | Heartbeat in {d}m\n\n", .{ state.cycle, next_hb_min });
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT LOG
// ═══════════════════════════════════════════════════════════════════════════════

fn logEvent(state: *QueenState, snap: FacultySnapshot, alert_count: usize) void {
    const file = std.fs.cwd().openFile(".trinity/event_log.jsonl", .{ .mode = .read_write }) catch return;
    defer file.close();
    file.seekFromEnd(0) catch return;

    state.event_seq += 1;
    var buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buf,
        \\{{"ts":{d},"seq":{d},"agent":"queen","kind":"queen_cycle","event":"queen_cycle","cycle":{d},"build_ok":{s},"dirty":{d},"issues":{d},"alerts":{d}}}
        \\
    , .{
        std.time.timestamp(),
        state.event_seq,
        state.cycle,
        if (snap.build_ok) "true" else "false",
        snap.dirty_files,
        snap.open_issues,
        alert_count,
    }) catch return;
    _ = file.write(line) catch {};
}

fn emitEvent(state: *QueenState, kind: []const u8, text: []const u8) void {
    const file = std.fs.cwd().openFile(".trinity/event_log.jsonl", .{ .mode = .read_write }) catch return;
    defer file.close();
    file.seekFromEnd(0) catch return;

    state.event_seq += 1;
    var buf: [1024]u8 = undefined;
    const line = std.fmt.bufPrint(&buf,
        \\{{"ts":{d},"seq":{d},"agent":"queen","kind":"{s}","text":"{s}"}}
        \\
    , .{
        std.time.timestamp(),
        state.event_seq,
        kind,
        text,
    }) catch return;
    _ = file.write(line) catch {};
}

fn emitStep(state: *QueenState, step: u8, total: u8, text: []const u8) void {
    const file = std.fs.cwd().openFile(".trinity/event_log.jsonl", .{ .mode = .read_write }) catch return;
    defer file.close();
    file.seekFromEnd(0) catch return;

    state.event_seq += 1;
    var buf: [1024]u8 = undefined;
    const line = std.fmt.bufPrint(&buf,
        \\{{"ts":{d},"seq":{d},"agent":"queen","kind":"queen_cycle","step":{d},"total":{d},"text":"{s}"}}
        \\
    , .{
        std.time.timestamp(),
        state.event_seq,
        step,
        total,
        text,
    }) catch return;
    _ = file.write(line) catch {};
}

// Helper for supervisor mode (stateless logging)
fn emitSupervisorStep(step: u8, total: u8, text: []const u8) void {
    const file = std.fs.cwd().openFile(".trinity/event_log.jsonl", .{ .mode = .read_write }) catch return;
    defer file.close();
    file.seekFromEnd(0) catch return;

    var buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buf,
        \\{{"ts":{d},"agent":"supervisor","kind":"supervisor_cycle","step":{d},"total":{d},"text":"{s}"}}
        \\
    , .{
        std.time.timestamp(),
        step,
        total,
        text,
    }) catch return;
    _ = file.write(line) catch {};
}

fn readUserInput(state: *QueenState) void {
    const path = ".trinity/queen/user_input.json";
    const file = std.fs.cwd().openFile(path, .{}) catch return;
    defer file.close();

    var buf: [1024]u8 = undefined;
    const n = file.read(&buf) catch return;
    if (n == 0) return;

    // Extract message from JSON: {"ts":...,"message":"..."}
    const data = buf[0..n];
    if (std.mem.indexOf(u8, data, "\"message\":\"")) |start| {
        const msg_start = start + 11;
        if (std.mem.indexOfPos(u8, data, msg_start, "\"")) |msg_end| {
            const msg = data[msg_start..msg_end];
            if (msg.len > 0) {
                emitEvent(state, "thought", msg);
                if (!std.mem.eql(u8, msg, "")) {
                    print("  " ++ qt.E_ROBOT ++ " UI input: {s}\n", .{msg});
                }
            }
        }
    }

    // Delete file after reading (one-shot message)
    std.fs.cwd().deleteFile(path) catch {};
}

/// Read UI action queue (written by SwiftUI ActionQueue)
/// Executes each action and deletes the queue file
fn readActionsQueue(allocator: Allocator, state: *QueenState) void {
    const path = ".trinity/queen/actions_queue.json";
    const file = std.fs.cwd().openFile(path, .{}) catch return;
    defer file.close();

    var buf: [4096]u8 = undefined;
    const n = file.read(&buf) catch return;
    if (n == 0) return;

    const data = buf[0..n];

    // Parse JSON array of actions: [{"action":"build","params":{},"ts":...},...]
    // Simple extraction: find all "action":"<name>" pairs
    var offset: usize = 0;
    while (offset < data.len) {
        const needle = "\"action\":\"";
        const found = std.mem.indexOfPos(u8, data, offset, needle) orelse break;
        const action_start = found + needle.len;
        const action_end = std.mem.indexOfPos(u8, data, action_start, "\"") orelse break;
        const action_name = data[action_start..action_end];
        offset = action_end + 1;

        // Map action name to queen action
        if (mapUiAction(action_name)) |kind| {
            print("  " ++ qt.E_BOLT ++ " UI Action: {s}\n", .{kind.label()});
            const result = queen_actions.execute(allocator, kind);
            queen_policy.writeAuditEntry("ui_action", kind, .allowed, result.success, result.outputStr());
            emitEvent(state, "ui_action", kind.label());
        } else {
            print("  " ++ qt.E_CROSS ++ " Unknown UI action: {s}\n", .{action_name});
        }
    }

    // Delete queue file after processing
    std.fs.cwd().deleteFile(path) catch {};
}

fn mapUiAction(name: []const u8) ?qt.ActionKind {
    const mappings = .{
        .{ "build", qt.ActionKind.doctor_quick },
        .{ "farm_evolve", qt.ActionKind.farm_evolve_step },
        .{ "farm_kill_idle", qt.ActionKind.cloud_kill },
        .{ "git_commit", qt.ActionKind.git_commit_state },
        .{ "git_push", qt.ActionKind.git_push },
        .{ "issues_refresh", qt.ActionKind.farm_status },
        .{ "telegram_test", qt.ActionKind.notify },
        .{ "telegram_check", qt.ActionKind.notify },
        .{ "redeploy", qt.ActionKind.farm_recycle },
        .{ "keys_test", qt.ActionKind.doctor_scan },
        .{ "scholar_research", qt.ActionKind.farm_status },
    };
    inline for (mappings) |m| {
        if (std.mem.eql(u8, name, m[0])) return m[1];
    }
    return null;
}

fn writeTodosFile(senses: qt.SenseResult) void {
    ensureQueenDir();
    const file = std.fs.cwd().createFile(".trinity/queen/todos.json", .{}) catch return;
    defer file.close();

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    w.print("{{\"generated_at\":{d},\"items\":[", .{std.time.timestamp()}) catch return;

    var count: usize = 0;

    // Open issues as todos
    if (senses.open_issues > 0) {
        if (count > 0) w.writeAll(",") catch {};
        w.print("{{\"id\":\"iss-open\",\"text\":\"Open issues: {d}\",\"source\":\"issue\",\"status\":\"pending\"}}", .{senses.open_issues}) catch {};
        count += 1;
    }

    // Dirty files
    if (senses.dirty_files > 0) {
        if (count > 0) w.writeAll(",") catch {};
        w.print("{{\"id\":\"git-dirty\",\"text\":\"Dirty files: {d}\",\"source\":\"git\",\"status\":\"pending\"}}", .{senses.dirty_files}) catch {};
        count += 1;
    }

    // Build status
    if (!senses.build_ok) {
        if (count > 0) w.writeAll(",") catch {};
        w.writeAll("{\"id\":\"build-fix\",\"text\":\"Fix broken build\",\"source\":\"build\",\"status\":\"pending\"}") catch {};
        count += 1;
    }

    // Farm idle
    if (senses.farm_idle_count > 0) {
        if (count > 0) w.writeAll(",") catch {};
        w.print("{{\"id\":\"farm-idle\",\"text\":\"Idle farm services: {d}\",\"source\":\"farm\",\"status\":\"pending\"}}", .{senses.farm_idle_count}) catch {};
        count += 1;
    }

    // Experience episodes
    if (senses.experience_count > 0) {
        if (count > 0) w.writeAll(",") catch {};
        w.print("{{\"id\":\"exp-count\",\"text\":\"Experience episodes: {d}\",\"source\":\"experience\",\"status\":\"done\"}}", .{senses.experience_count}) catch {};
        count += 1;
    }

    w.writeAll("]}") catch {};
    const data = fbs.getWritten();
    _ = file.write(data) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON FILE WRITERS — SwiftUI data channel
// ═══════════════════════════════════════════════════════════════════════════════

fn ensureQueenDir() void {
    std.fs.cwd().makePath(".trinity/queen") catch {};
}

fn writeSensesFile(s: qt.SenseResult) void {
    ensureQueenDir();
    const file = std.fs.cwd().createFile(".trinity/queen/senses.json", .{}) catch return;
    defer file.close();

    var buf: [2048]u8 = undefined;
    const data = std.fmt.bufPrint(&buf,
        \\{{"ts":{d},"build_ok":{s},"test_rate":{d},"dirty_files":{d},"open_issues":{d},"agent_count":{d},"farm_services":{d},"farm_best_ppl":{d:.2},"arena_battles":{d},"ouroboros_score":{d:.1},"disk_free_gb":{d:.1},"keys_present":{d},"keys_total":{d},"experience_episodes":{d},"network_ok":{s},"farm_idle_count":{d},"stale_arena_hours":{d},"agent_spawn_issues":{d},"finished_containers":{d},"last_git_push_ts":{d}}}
    , .{
        std.time.timestamp(),
        if (s.build_ok) "true" else "false",
        s.test_rate,
        s.dirty_files,
        s.open_issues,
        s.agent_count,
        s.farm_services,
        s.farm_best_ppl,
        s.arena_battles,
        s.ouroboros_score,
        s.disk_free_gb,
        s.keys_present,
        s.keys_total,
        s.experience_count,
        if (s.network_ok) "true" else "false",
        s.farm_idle_count,
        s.stale_arena_hours,
        s.agent_spawn_issues,
        s.finished_containers,
        s.last_git_push_ts,
    }) catch return;
    _ = file.write(data) catch {};
}

fn writeActionsFile() void {
    ensureQueenDir();
    const file = std.fs.cwd().createFile(".trinity/queen/actions.json", .{}) catch return;
    defer file.close();

    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    w.print("{{\"version\":4,\"generated_at\":{d},\"actions\":[", .{std.time.timestamp()}) catch return;

    for (0..qt.ActionKind.COUNT) |i| {
        if (i > 0) w.print(",", .{}) catch return;
        const k: qt.ActionKind = @enumFromInt(i);
        const level = queen_policy.actionLevel(k);
        const limits = queen_policy.actionRateLimit(k);
        w.print("{{\"id\":\"{s}\",\"label\":\"{s}\",\"emoji\":\"{s}\",\"level\":{d},\"max_per_hour\":{d},\"cooldown_sec\":{d}}}", .{
            k.label(),
            k.label(),
            k.emojiIcon(),
            @intFromEnum(level),
            limits.max_per_hour,
            limits.cooldown_sec,
        }) catch return;
    }

    w.print("]}}", .{}) catch return;
    _ = file.write(fbs.getWritten()) catch {};
}

fn writeAuditSummary(config: qt.QueenConfig, counters: *const queen_policy.ActionCounters) void {
    ensureQueenDir();
    const file = std.fs.cwd().createFile(".trinity/queen/policy.json", .{}) catch return;
    defer file.close();

    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    w.print("{{\"max_auto_level\":{d},\"require_human_approval\":{s},\"god_mode\":{s},\"rate_limits\":{{", .{
        config.max_auto_level,
        if (config.require_human_approval) "true" else "false",
        if (!config.require_human_approval and config.allow_auto_actions and config.max_auto_level == 2) "true" else "false",
    }) catch return;

    for (0..qt.ActionKind.COUNT) |i| {
        if (i > 0) w.print(",", .{}) catch return;
        const k: qt.ActionKind = @enumFromInt(i);
        const level = queen_policy.actionLevel(k);
        const limits = queen_policy.actionRateLimit(k);
        const used = counters.getCount(k);
        w.print("\"{s}\":{{\"level\":{d},\"max_per_hour\":{d},\"cooldown_sec\":{d},\"used\":{d}}}", .{
            k.label(),
            @intFromEnum(level),
            limits.max_per_hour,
            limits.cooldown_sec,
            used,
        }) catch return;
    }

    w.print("}}}}", .{}) catch return;
    _ = file.write(fbs.getWritten()) catch {};
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLEEP
// ═══════════════════════════════════════════════════════════════════════════════

fn sleepInterval(sec: u64) void {
    std.Thread.sleep(sec * std.time.ns_per_s);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Queen alert — build broken" {
    var state = QueenState{ .prev_build_ok = true };
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = false;
    var alerts: [8]Alert = undefined;
    var count: usize = 0;
    detectAlerts(&state, snap, EvolutionInfo{}, &alerts, &count);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(AlertKind.build_broken, alerts[0].kind);
}

test "Queen alert — no alert when OK" {
    var state = QueenState{ .prev_build_ok = true };
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    var alerts: [8]Alert = undefined;
    var count: usize = 0;
    detectAlerts(&state, snap, EvolutionInfo{}, &alerts, &count);
    try std.testing.expectEqual(@as(usize, 0), count);
}

test "Queen alert — PPL record" {
    var state = QueenState{ .prev_best_ppl = 7.4 };
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    var evo = EvolutionInfo{};
    evo.best_ppl = 6.8;
    var alerts: [8]Alert = undefined;
    var count: usize = 0;
    detectAlerts(&state, snap, evo, &alerts, &count);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(AlertKind.new_ppl_record, alerts[0].kind);
}

test "Queen alert — dirty overload" {
    var state = QueenState{ .prev_dirty = 30, .prev_build_ok = true };
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    snap.dirty_files = 55;
    var alerts: [8]Alert = undefined;
    var count: usize = 0;
    detectAlerts(&state, snap, EvolutionInfo{}, &alerts, &count);
    try std.testing.expectEqual(@as(usize, 1), count);
    try std.testing.expectEqual(AlertKind.dirty_overload, alerts[0].kind);
}

test "Queen scheduler — heartbeat" {
    const now: i64 = 1710000000;
    try std.testing.expect(!shouldSendHeartbeat(.{ .last_heartbeat = now - 1800 }, now));
    try std.testing.expect(shouldSendHeartbeat(.{ .last_heartbeat = now - 7200 }, now));
}

test "Queen heartbeat format" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    snap.dirty_files = 31;
    snap.open_issues = 67;
    snap.v_number = 1.31;

    var evo = EvolutionInfo{};
    evo.best_ppl = 4.6;
    evo.best_step = 100000;
    const name = "R33";
    @memcpy(evo.best_name[0..name.len], name);
    evo.best_name_len = name.len;
    evo.total_configs = 139;

    const senses = qt.SenseResult{
        .build_ok = true,
        .test_rate = 85,
        .disk_free_gb = 42.0,
        .keys_present = 4,
        .keys_total = 5,
        .experience_count = 7,
    };

    var buf: [2048]u8 = undefined;
    const msg = fmtHeartbeat(&buf, snap, evo, .{ .total_battles = 5 }, senses);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, qt.E_CROWN) != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "4.6") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "R33") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 2 TESTS — PMC → M1 Integration
// ═══════════════════════════════════════════════════════════════════════════════

test "Phase 2 — determineGoal returns heal_system when build broken" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = false;
    const evo = EvolutionInfo{};
    const incidents = queen_policy.IncidentMemory.init();

    const goal = determineGoal(snap, evo, &incidents);
    try std.testing.expectEqual(queen_premotor.Goal.heal_system, goal.?);
}

test "Phase 2 — determineGoal returns assess_health when high failure rate" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    const evo = EvolutionInfo{};
    var incidents = queen_policy.IncidentMemory.init();
    // Simulate high failure rate: 3 fails out of 4 actions (75% > 50%)
    incidents.total_auto_actions_24h = 4;
    incidents.total_auto_fails_24h = 3;

    const goal = determineGoal(snap, evo, &incidents);
    try std.testing.expectEqual(queen_premotor.Goal.assess_health, goal.?);
}

test "Phase 2 — determineGoal returns check_farm when no services" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    var evo = EvolutionInfo{};
    evo.service_count = 0;
    const incidents = queen_policy.IncidentMemory.init();

    const goal = determineGoal(snap, evo, &incidents);
    try std.testing.expectEqual(queen_premotor.Goal.check_farm, goal.?);
}

test "Phase 2 — determineGoal returns cleanup_cloud when dirty files high" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    snap.dirty_files = 150;
    var evo = EvolutionInfo{};
    evo.service_count = 5; // Need services > 0 to prioritize cleanup over check_farm
    const incidents = queen_policy.IncidentMemory.init();

    const goal = determineGoal(snap, evo, &incidents);
    try std.testing.expectEqual(queen_premotor.Goal.cleanup_cloud, goal.?);
}

test "Phase 2 — determineGoal returns null when all is well" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    snap.dirty_files = 50;
    var evo = EvolutionInfo{};
    evo.service_count = 10;
    var incidents = queen_policy.IncidentMemory.init();
    incidents.total_auto_actions_24h = 10;
    incidents.total_auto_fails_24h = 2; // 20% failure rate < 50%

    const goal = determineGoal(snap, evo, &incidents);
    try std.testing.expect(goal == null);
}

test "Phase 2 — MotorPlan.init creates correct plan" {
    const plan = queen_premotor.MotorPlan.init(.heal_system);

    try std.testing.expectEqual(queen_premotor.Goal.heal_system, plan.source_goal);
    try std.testing.expectEqual(@as(u8, 80), plan.priority); // heal_system priority
    try std.testing.expect(plan.created_at > 0);
    try std.testing.expectEqual(@as(u8, 4), plan.sequence.step_count); // fullHeal has 4 steps
}

test "Phase 2 — MotorPlan.init for assess_health" {
    const plan = queen_premotor.MotorPlan.init(.assess_health);

    try std.testing.expectEqual(queen_premotor.Goal.assess_health, plan.source_goal);
    try std.testing.expectEqual(@as(u8, 60), plan.priority);
    try std.testing.expectEqual(@as(u8, 4), plan.sequence.step_count);
    try std.testing.expectEqual(qt.ActionKind.doctor_scan, plan.sequence.steps[0].action);
}

test "Phase 2 — MotorPlan.init for check_farm" {
    const plan = queen_premotor.MotorPlan.init(.check_farm);

    try std.testing.expectEqual(queen_premotor.Goal.check_farm, plan.source_goal);
    try std.testing.expectEqual(@as(u8, 40), plan.priority);
    try std.testing.expectEqual(@as(u8, 2), plan.sequence.step_count);
}

test "Phase 2 — MotorExecutor.init and executePlan (no execute)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const plan = queen_premotor.MotorPlan.init(.assess_health);
    const executor = queen_motor.MotorExecutor.init(allocator);

    // Just test that executor was initialized and plan is valid
    _ = executor;
    try std.testing.expect(plan.sequence.step_count > 0);
}

test "Phase 2 — PMC → M1 full integration (dry run)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Simulate the full flow: PFC (determineGoal) → PMC (MotorPlan.init) → M1 (MotorExecutor)
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = false;
    const evo = EvolutionInfo{};
    const incidents = queen_policy.IncidentMemory.init();

    // PFC: Determine goal
    const goal = determineGoal(snap, evo, &incidents);
    try std.testing.expectEqual(queen_premotor.Goal.heal_system, goal.?);

    // PMC: Create motor plan
    const plan = queen_premotor.MotorPlan.init(goal.?);
    try std.testing.expectEqual(@as(u8, 4), plan.sequence.step_count);

    // M1: Initialize executor (don't actually execute)
    const executor = queen_motor.MotorExecutor.init(allocator);
    _ = executor;

    // Verify plan has expected actions
    try std.testing.expectEqual(qt.ActionKind.doctor_scan, plan.sequence.steps[0].action);
    try std.testing.expectEqual(qt.ActionKind.ouroboros_cycle, plan.sequence.steps[2].action);
}

test "Phase 2 — Goal priority ordering" {
    try std.testing.expectEqual(@as(u8, 100), queen_premotor.Goal.emergency_shutdown.priority());
    try std.testing.expectEqual(@as(u8, 80), queen_premotor.Goal.heal_system.priority());
    try std.testing.expectEqual(@as(u8, 60), queen_premotor.Goal.assess_health.priority());
    try std.testing.expectEqual(@as(u8, 40), queen_premotor.Goal.check_farm.priority());
    try std.testing.expectEqual(@as(u8, 30), queen_premotor.Goal.cleanup_cloud.priority());
    try std.testing.expectEqual(@as(u8, 10), queen_premotor.Goal.research_update.priority());
}

test "Phase 2 — PlanQueue FIFO behavior" {
    var queue = queen_premotor.PlanQueue{};

    // Push 3 plans
    try std.testing.expect(queue.push(queen_premotor.MotorPlan.init(.research_update)));
    try std.testing.expect(queue.push(queen_premotor.MotorPlan.init(.cleanup_cloud)));
    try std.testing.expect(queue.push(queen_premotor.MotorPlan.init(.check_farm)));
    try std.testing.expectEqual(@as(u8, 3), queue.len());

    // Pop in FIFO order
    const p1 = queue.pop().?;
    try std.testing.expectEqual(queen_premotor.Goal.research_update, p1.source_goal);

    const p2 = queue.pop().?;
    try std.testing.expectEqual(queen_premotor.Goal.cleanup_cloud, p2.source_goal);

    const p3 = queue.pop().?;
    try std.testing.expectEqual(queen_premotor.Goal.check_farm, p3.source_goal);

    try std.testing.expectEqual(@as(u8, 0), queue.len());
    try std.testing.expect(queue.pop() == null);
}

test "Phase 2 — PlanQueue wraparound" {
    var queue = queen_premotor.PlanQueue{};

    // Fill and empty to test wraparound
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        try std.testing.expect(queue.push(queen_premotor.MotorPlan.init(.check_farm)));
    }
    try std.testing.expect(!queue.push(queen_premotor.MotorPlan.init(.check_farm))); // Full

    while (queue.pop()) |_| {}
    try std.testing.expectEqual(@as(u8, 0), queue.len());

    // After empty, should work again
    try std.testing.expect(queue.push(queen_premotor.MotorPlan.init(.heal_system)));
}

test "Phase 2 — Sequencer context updates" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sequencer = queen_premotor.Sequencer.init(allocator);

    const senses = qt.SenseResult{
        .build_ok = true,
        .test_rate = 90,
        .farm_idle_count = 3,
        .arena_battles = 5,
    };

    sequencer.updateContext(senses);

    try std.testing.expect(sequencer.context.build_ok);
    try std.testing.expect(sequencer.context.tests_pass);
    try std.testing.expectEqual(@as(u8, 3), sequencer.context.farm_idle_count);
    try std.testing.expect(sequencer.context.arena_exists);
}

test "Phase 2 — ActionSequence conditions" {
    var seq = queen_premotor.ActionSequence{};

    try seq.addStepWithCondition(.doctor_quick, .build_ok);
    try std.testing.expectEqual(@as(u8, 1), seq.step_count);
    try std.testing.expectEqual(queen_premotor.SequenceStep.Condition.build_ok, seq.steps[0].condition.?);
}

test "Phase 2 — ActionSequence delayed step" {
    var seq = queen_premotor.ActionSequence{};

    try seq.addDelayedStep(.notify, 5000);
    try std.testing.expectEqual(@as(u8, 1), seq.step_count);
    try std.testing.expectEqual(@as(u64, 5000), seq.steps[0].delay_ms);
}

test "Phase 2 — MotorCommand from two-word action" {
    const cmd = queen_motor.MotorCommand.fromAction(.farm_status);

    try std.testing.expectEqualStrings("farm", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("status", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Phase 2 — MotorCommand from single-word action" {
    const cmd = queen_motor.MotorCommand.fromAction(.notify);

    try std.testing.expectEqualStrings("notify", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 0), cmd.arg_count);
}

test "Phase 2 — MotorCommand format" {
    const cmd = queen_motor.MotorCommand.fromAction(.farm_status);
    var buf: [128]u8 = undefined;
    const formatted = cmd.format(&buf);

    try std.testing.expect(formatted.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "tri farm status") != null);
}

test "Phase 2 — CommandBuilder fluent API" {
    var builder = queen_motor.CommandBuilder{};
    try builder.subcommand("cloud");
    try builder.arg("status");
    const cmd = builder.build();

    try std.testing.expectEqualStrings("cloud", cmd.subcommandStr());
    try std.testing.expectEqual(@as(u8, 1), cmd.arg_count);
    try std.testing.expectEqualStrings("status", cmd.args[0][0..cmd.arg_lens[0]]);
}

test "Phase 2 — MotorBatch sequential execution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var batch = queen_motor.MotorBatch{};
    batch.parallel = false;

    try batch.addCommand(queen_motor.MotorCommand.fromAction(.farm_status));
    try batch.addCommand(queen_motor.MotorCommand.fromAction(.arena_status));

    try std.testing.expectEqual(@as(u8, 2), batch.count);

    // Execute batch (should not fail even if commands don't exist)
    const result = batch.execute(allocator) catch return error.ExecuteFailed;
    _ = result;
}

test "Phase 2 — failure rate edge cases" {
    var snap = std.mem.zeroes(FacultySnapshot);
    snap.build_ok = true;
    const evo = EvolutionInfo{};

    // Exactly 50% failure rate (should NOT trigger assess_health, needs > 50%)
    {
        var incidents = queen_policy.IncidentMemory.init();
        incidents.total_auto_actions_24h = 10;
        incidents.total_auto_fails_24h = 5; // 50% exactly
        const goal = determineGoal(snap, evo, &incidents);
        try std.testing.expect(goal != .assess_health);
    }

    // Just over 50% (should trigger)
    {
        var incidents = queen_policy.IncidentMemory.init();
        incidents.total_auto_actions_24h = 10;
        incidents.total_auto_fails_24h = 6; // 60%
        const goal = determineGoal(snap, evo, &incidents);
        try std.testing.expectEqual(queen_premotor.Goal.assess_health, goal.?);
    }

    // Less than 3 failures (should NOT trigger regardless of rate)
    {
        var incidents = queen_policy.IncidentMemory.init();
        incidents.total_auto_actions_24h = 3;
        incidents.total_auto_fails_24h = 2; // 66% but only 2 fails
        const goal = determineGoal(snap, evo, &incidents);
        try std.testing.expect(goal != .assess_health);
    }
}
