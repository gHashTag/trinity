// ═══════════════════════════════════════════════════════════════════════════════
// Analysis Engine — Metric → Narrative for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Converts system metrics into 2-3 sentence causal narrative in Russian.
// No allocations — writes into caller-owned buffer.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const FacultySnapshot = types.FacultySnapshot;

/// Generate a causal analysis narrative from the snapshot.
/// Returns a slice into `buf`.
pub fn generateAnalysis(snapshot: FacultySnapshot, buf: []u8) []const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const w = stream.writer();

    const active = snapshot.activeFaculty();
    const faculty_pct: u8 = if (active == 6) 100 else @intCast((@as(u16, active) * 100) / 6);

    // 1. Build broken — everything blocked
    if (!snapshot.build_ok) {
        w.print("Сборка сломана — всё стоит. ", .{}) catch {};
        w.print("Факультет {d}/6 ({d}%). ", .{ active, faculty_pct }) catch {};
        w.print("Пока build не починен, ни один движок не работает.", .{}) catch {};
        return stream.getWritten();
    }

    // 2. Compile rate low
    if (snapshot.compile_rate < 80) {
        w.print("Генератор сбоит — {d}% проходят. ", .{snapshot.compile_rate}) catch {};
        w.print("Пайплайн заблокирован до починки кодогена.", .{}) catch {};
        if (active < 6) {
            w.print(" Факультет {d}/6.", .{active}) catch {};
        }
        return stream.getWritten();
    }

    // 3. Start with faculty count
    w.print("Факультет {d}/6 ({d}%). ", .{ active, faculty_pct }) catch {};

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
            w.print("{s} лежит — {s}. ", .{ a.agent.name(), consequence }) catch {};
            has_bottleneck = true;
            break;
        }
    }

    // 5. Entropy warning
    if (snapshot.dirty_files > 15) {
        w.print("Энтропия растёт — {d} грязных файлов. ", .{snapshot.dirty_files}) catch {};
        has_bottleneck = true;
    }

    // 6. Summary if no specific bottleneck
    if (!has_bottleneck) {
        if (active == 6 and snapshot.compile_rate >= 95) {
            w.print("Всё работает штатно.", .{}) catch {};
        } else if (active < 4) {
            w.print("Большинство агентов не активны — возможности ограничены.", .{}) catch {};
        } else {
            w.print("Система стабильна, но есть резерв роста.", .{}) catch {};
        }
    }

    return stream.getWritten();
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

test "analysis — build broken" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(false, 85, 3, 5);
    const text = generateAnalysis(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "сломана") != null);
}

test "analysis — low compile rate" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 60, 3, 5);
    const text = generateAnalysis(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "60%") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "заблокирован") != null);
}

test "analysis — healthy system" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 98, 6, 3);
    const text = generateAnalysis(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "6/6") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "штатно") != null);
}

test "analysis — high entropy" {
    var buf: [512]u8 = undefined;
    const snap = makeSnapshot(true, 90, 4, 20);
    const text = generateAnalysis(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "Энтропия") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "20") != null);
}

test "analysis — agent down" {
    var buf: [512]u8 = undefined;
    var snap = makeSnapshot(true, 90, 5, 3);
    snap.agents[0].status = .down; // ralph down
    const text = generateAnalysis(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, text, "Ralph") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "лежит") != null);
}
