// ═══════════════════════════════════════════════════════════════════════════════
// Analysis Engine — Metric → Narrative for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Converts system metrics into 2-3 sentence causal narrative in Russian.
// Delta-aware: compares current snapshot to previous run for dynamic text.
// No allocations — writes into caller-owned buffer.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const FacultySnapshot = types.FacultySnapshot;
const FacultyDelta = types.FacultyDelta;

/// Generate a causal analysis narrative from the snapshot + delta.
/// Returns a slice into `buf`.
pub fn generateAnalysis(snapshot: FacultySnapshot, delta: FacultyDelta, buf: []u8) []const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const w = stream.writer();

    const active = snapshot.activeFaculty();
    const faculty_pct: u8 = if (active == 6) 100 else @intCast((@as(u16, active) * 100) / 6);

    // 1. Build broken — everything blocked
    if (!snapshot.build_ok) {
        w.print("Сборка сломана — всё стоит. ", .{}) catch |err| {
            std.log.debug("analysis_engine: write build broken failed: {}", .{err});
        };
        w.print("Факультет {d}/6 ({d}%). ", .{ active, faculty_pct }) catch |err| {
            std.log.debug("analysis_engine: write faculty count failed: {}", .{err});
        };
        w.print("Пока build не починен, ни один движок не работает.", .{}) catch |err| {
            std.log.debug("analysis_engine: write build block message failed: {}", .{err});
        };
        return stream.getWritten();
    }

    // 2. Compile rate low
    if (snapshot.compile_rate < 80) {
        w.print("Генератор сбоит — {d}% проходят. ", .{snapshot.compile_rate}) catch |err| {
            std.log.debug("analysis_engine: write compile rate failed: {}", .{err});
        };
        w.print("Пайплайн заблокирован до починки кодогена.", .{}) catch |err| {
            std.log.debug("analysis_engine: write pipeline blocked failed: {}", .{err});
        };
        if (active < 6) {
            w.print(" Факультет {d}/6.", .{active}) catch |err| {
                std.log.debug("analysis_engine: write faculty count failed: {}", .{err});
            };
        }
        return stream.getWritten();
    }

    // 3. Faculty count + delta
    w.print("Факультет {d}/6 ({d}%)", .{ active, faculty_pct }) catch |err| {
        std.log.debug("analysis_engine: write faculty header failed: {}", .{err});
    };
    if (delta.has_prev and delta.active_delta != 0) {
        if (delta.active_delta > 0) {
            w.print(" (+{d})", .{delta.active_delta}) catch |err| {
                std.log.debug("analysis_engine: write delta positive failed: {}", .{err});
            };
        } else {
            w.print(" ({d})", .{delta.active_delta}) catch |err| {
                std.log.debug("analysis_engine: write delta negative failed: {}", .{err});
            };
        }
    }
    w.print(". ", .{}) catch |err| {
        std.log.debug("analysis_engine: write separator failed: {}", .{err});
    };

    // 4. Find bottleneck
    var has_bottleneck = false;

    // Check for down agents
    for (snapshot.agents) |a| {
        if (a.status == .down) {
            const consequence: []const u8 = switch (a.agent) {
                .ralph => "задачи не двигаются",
                .oracle => "нет надзора",
                .linter => "сбои не видны",
                .mu => "ошибки не ловятся",
                .scholar => "нет исследований",
                .swarm => "нет распределения",
            };
            w.print("{s} лежит — {s}. ", .{ a.agent.name(), consequence }) catch |err| {
                std.log.debug("analysis_engine: write agent down status failed: {}", .{err});
            };
            has_bottleneck = true;
            break;
        }
    }

    // 5. Entropy warning
    if (snapshot.dirty_files > 15) {
        w.print("Энтропия растёт — {d} грязных файлов. ", .{snapshot.dirty_files}) catch |err| {
            std.log.debug("analysis_engine: write entropy warning failed: {}", .{err});
        };
        has_bottleneck = true;
    }

    // 6. Summary — delta-aware if possible
    if (!has_bottleneck) {
        if (delta.has_prev) {
            const fail = snapshot.compile_total -| snapshot.compile_pass;

            if (delta.compile_frozen and fail > 0) {
                // Compile rate hasn't changed for over an hour
                const hours: i64 = @divTrunc(delta.seconds_ago, 3600);
                w.print("Compile замёрзла на {d}%", .{snapshot.compile_rate}) catch |err| {
                    std.log.debug("analysis_engine: write compile frozen failed: {}", .{err});
                };
                if (hours > 0) {
                    w.print(" ({d}ч)", .{hours}) catch |err| {
                        std.log.debug("analysis_engine: write frozen hours failed: {}", .{err});
                    };
                }
                w.print(" — {d} спеков не чинятся.", .{fail}) catch |err| {
                    std.log.debug("analysis_engine: write failed specs count failed: {}", .{err});
                };
            } else if (delta.compile_rate_delta > 0) {
                w.print("Compile {d}→{d}% (+{d}pp).", .{
                    delta.prev_compile_rate, snapshot.compile_rate, delta.compile_rate_delta,
                }) catch |err| {
                    std.log.debug("analysis_engine: write compile improved failed: {}", .{err});
                };
            } else if (delta.compile_rate_delta < 0) {
                w.print("Compile {d}→{d}% ({d}pp). Регрессия!", .{
                    delta.prev_compile_rate, snapshot.compile_rate, delta.compile_rate_delta,
                }) catch |err| {
                    std.log.debug("analysis_engine: write compile regression failed: {}", .{err});
                };
            } else if (delta.dirty_delta < -3) {
                w.print("Dirty {d}→{d}. Порядок наводится.", .{
                    delta.prev_dirty, snapshot.dirty_files,
                }) catch |err| {
                    std.log.debug("analysis_engine: write dirty reduced failed: {}", .{err});
                };
            } else if (delta.dirty_delta > 5) {
                w.print("Dirty {d}→{d}. Энтропия нарастает.", .{
                    delta.prev_dirty, snapshot.dirty_files,
                }) catch |err| {
                    std.log.debug("analysis_engine: write dirty increased failed: {}", .{err});
                };
            } else if (active == 6 and snapshot.compile_rate >= 95) {
                w.print("Всё работает штатно.", .{}) catch |err| {
                    std.log.debug("analysis_engine: write all working failed: {}", .{err});
                };
            } else {
                w.print("Без изменений. Стабильно.", .{}) catch |err| {
                    std.log.debug("analysis_engine: write stable failed: {}", .{err});
                };
            }
        } else {
            // No delta — static fallback (first run)
            if (active == 6 and snapshot.compile_rate >= 95) {
                w.print("Всё работает штатно.", .{}) catch |err| {
                    std.log.debug("analysis_engine: write all working fallback failed: {}", .{err});
                };
            } else if (active < 4) {
                w.print("Большинство агентов не активны — возможности ограничены.", .{}) catch |err| {
                    std.log.debug("analysis_engine: write agents inactive failed: {}", .{err});
                };
            } else {
                w.print("Система стабильна, но есть резерв роста.", .{}) catch |err| {
                    std.log.debug("analysis_engine: write stable with potential failed: {}", .{err});
                };
            }
        }
    }

    // 7. Causal chains — link agent states to metric dynamics
    appendCausalChain(w, snapshot, delta);

    return stream.getWritten();
}

/// Append causal chain linking agent states to metric implications.
fn appendCausalChain(w: anytype, snapshot: FacultySnapshot, delta: FacultyDelta) void {
    const mu_up = agentIsUp(snapshot, .mu);
    const scholar_up = agentIsUp(snapshot, .scholar);
    const fail = snapshot.compile_total -| snapshot.compile_pass;

    // Agent TRI healing + compile improving → credit Agent TRI
    if (mu_up and delta.has_prev and delta.compile_rate_delta > 0) {
        w.print(" Agent TRI лечит — паттерны работают.", .{}) catch |err| {
            std.log.debug("analysis_engine: write Agent TRI healing failed: {}", .{err});
        };
        return;
    }

    // Agent TRI up + compile frozen + Scholar missing → bottleneck is new patterns
    if (mu_up and !scholar_up and delta.compile_frozen and fail > 0) {
        w.print(" Agent TRI лечит известное, но Scholar не нанят — новые паттерны некому искать.", .{}) catch |err| {
            std.log.debug("analysis_engine: write Scholar missing failed: {}", .{err});
        };
        return;
    }

    // Agent TRI up + compile regressed → Agent TRI fix may have caused it
    if (mu_up and delta.has_prev and delta.compile_rate_delta < -2) {
        w.print(" Регрессия при Agent TRI UP — проверить последний fix.", .{}) catch |err| {
            std.log.debug("analysis_engine: write Agent TRI regression failed: {}", .{err});
        };
        return;
    }

    // Faculty grew → acknowledge
    if (delta.has_prev and delta.active_delta > 0) {
        w.print(" +{d} агент.", .{delta.active_delta}) catch |err| {
            std.log.debug("analysis_engine: write faculty grew failed: {}", .{err});
        };
    }
}

fn agentIsUp(snapshot: FacultySnapshot, agent: @import("faculty_types.zig").Agent) bool {
    for (snapshot.agents) |a| {
        if (a.agent == agent and a.status == .up) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn makeSnapshot(build_ok: bool, compile_rate: u8, active_count: u8, dirty: u16) FacultySnapshot {
    var agents: [6]types.AgentState = undefined;
    const agent_list = [_]types.Agent{ .ralph, .scholar, .mu, .oracle, .swarm, .linter };
    for (agent_list, 0..) |a, i| {
        agents[i] = .{
            .agent = a,
            .status = if (i < active_count) .up else .tbd,
            .last_action = "",
        };
    }
    const pass: u16 = @intCast((@as(u16, compile_rate) * 47) / 100);
    return .{
        .agents = agents,
        .build_ok = build_ok,
        .binaries = 5,
        .compile_pass = pass,
        .compile_total = 47,
        .compile_rate = compile_rate,
        .v_number = 1.0,
        .v_zone = .stable,
        .git_branch = "main",
        .dirty_files = dirty,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };
}

const no_delta = FacultyDelta{};

test "analysis — build broken" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(false, 85, 3, 5);
    const text = generateAnalysis(snap, no_delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "сломана") != null);
}

test "analysis — low compile rate" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 60, 3, 5);
    const text = generateAnalysis(snap, no_delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "60%") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "заблокирован") != null);
}

test "analysis — healthy system" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 98, 6, 3);
    const text = generateAnalysis(snap, no_delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "6/6") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "штатно") != null);
}

test "analysis — high entropy" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 90, 4, 20);
    const text = generateAnalysis(snap, no_delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "Энтропия") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "20") != null);
}

test "analysis — agent down" {
    var buf: [512]u8 = undefined;
    var snap = makeSnapshot(true, 90, 5, 3);
    snap.agents[0].status = .down; // ralph down
    const text = generateAnalysis(snap, no_delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "Ralph") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "лежит") != null);
}

test "analysis — delta compile frozen" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 90, 3, 5);
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 7200, // 2 hours
        .compile_rate_delta = 0,
        .compile_frozen = true,
        .prev_compile_rate = 90,
        .prev_active = 3,
        .prev_dirty = 5,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "замёрзла") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "90%") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "2ч") != null);
}

test "analysis — delta compile improved" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 92, 3, 5);
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 1800,
        .compile_rate_delta = 5,
        .prev_compile_rate = 87,
        .prev_active = 3,
        .prev_dirty = 5,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "87") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "92%") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "+5pp") != null);
}

test "analysis — Agent TRI healing credits" {
    var buf: [512]u8 = undefined;
    // MU is agent index 2 — make it UP
    var snap = makeSnapshot(true, 93, 4, 5);
    snap.agents[2] = .{ .agent = .mu, .status = .up, .last_action = "healing" };
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 600,
        .compile_rate_delta = 3,
        .prev_compile_rate = 90,
        .prev_active = 4,
        .prev_dirty = 5,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "паттерны работают") != null);
}

test "analysis — MU up Scholar missing frozen" {
    var buf: [512]u8 = undefined;
    var snap = makeSnapshot(true, 90, 4, 5);
    snap.agents[1] = .{ .agent = .scholar, .status = .tbd, .last_action = "" };
    snap.agents[2] = .{ .agent = .mu, .status = .up, .last_action = "healing" };
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 7200,
        .compile_frozen = true,
        .prev_compile_rate = 90,
        .prev_active = 4,
        .prev_dirty = 5,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "Scholar не нанят") != null);
}

test "analysis — delta faculty changed" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 90, 4, 5);
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 600,
        .active_delta = 1,
        .prev_active = 3,
        .prev_compile_rate = 90,
        .prev_dirty = 5,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "(+1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "4/6") != null);
}

test "analysis — delta dirty reduced" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 90, 3, 5);
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 600,
        .dirty_delta = -10,
        .prev_dirty = 15,
        .prev_compile_rate = 90,
        .prev_active = 3,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "15") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "5") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Порядок") != null);
}

test "analysis — delta no change stable" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 90, 3, 5);
    const delta = FacultyDelta{
        .has_prev = true,
        .seconds_ago = 300,
        .prev_compile_rate = 90,
        .prev_active = 3,
        .prev_dirty = 5,
    };
    const text = generateAnalysis(snap, delta, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "Без изменений") != null);
}
