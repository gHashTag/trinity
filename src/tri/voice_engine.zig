// ═══════════════════════════════════════════════════════════════════════════════
// Voice Engine — Agent voice generator for Faculty Board
// ═══════════════════════════════════════════════════════════════════════════════
// Each agent speaks in character based on their state and the system snapshot.
// No allocations — writes into caller-owned buffer via bufPrint.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const AgentState = types.AgentState;
const FacultySnapshot = types.FacultySnapshot;

/// Generate a voice line for the given agent based on system state.
/// Returns a slice into `buf`.
pub fn generateVoice(agent: AgentState, snapshot: FacultySnapshot, buf: []u8) []const u8 {
    return switch (agent.agent) {
        .ralph => ralphVoice(agent, snapshot, buf),
        .scholar => scholarVoice(agent, buf),
        .mu => muVoice(agent, snapshot, buf),
        .oracle => oracleVoice(snapshot, buf),
        .swarm => swarmVoice(agent, buf),
        .linter => linterVoice(agent, snapshot, buf),
    };
}

fn ralphVoice(agent: AgentState, snapshot: FacultySnapshot, buf: []u8) []const u8 {
    return switch (agent.status) {
        .up => std.fmt.bufPrint(buf, "На посту. Build {d}/{d}. Делаю задачи.", .{
            snapshot.compile_pass, snapshot.compile_total,
        }) catch "Ralph работает.",
        .down => std.fmt.bufPrint(buf, "Лежу. Перезапустите.", .{}) catch "Ralph лежит.",
        .stub, .tbd => std.fmt.bufPrint(buf, "Не активирован.", .{}) catch "Ralph не активен.",
    };
}

fn scholarVoice(agent: AgentState, buf: []u8) []const u8 {
    return switch (agent.status) {
        .tbd => std.fmt.bufPrint(buf, "НЕ НАНЯТ. Ralph гадает без контекста.", .{}) catch "Scholar TBD.",
        .up => if (agent.last_action.len > 0)
            std.fmt.bufPrint(buf, "Ищу: {s}.", .{agent.last_action}) catch "Scholar ищет."
        else
            std.fmt.bufPrint(buf, "Ищу информацию.", .{}) catch "Scholar ищет.",
        .stub => std.fmt.bufPrint(buf, "Заглушка. Нужна имплементация.", .{}) catch "Scholar stub.",
        .down => std.fmt.bufPrint(buf, "Упал. Исследования встали.", .{}) catch "Scholar down.",
    };
}

fn muVoice(agent: AgentState, snapshot: FacultySnapshot, buf: []u8) []const u8 {
    return switch (agent.status) {
        .stub => std.fmt.bufPrint(buf, "СПИТ. {d} паттернов вручную.", .{
            snapshot.mu_patterns,
        }) catch "MU спит.",
        .up => std.fmt.bufPrint(buf, "{d} паттернов. Лечу пайплайн.", .{
            snapshot.mu_patterns,
        }) catch "MU лечит.",
        .tbd => std.fmt.bufPrint(buf, "В ПРОЕКТЕ. Ошибки копятся.", .{}) catch "MU TBD.",
        .down => std.fmt.bufPrint(buf, "Упал. Ошибки не ловятся.", .{}) catch "MU down.",
    };
}

fn oracleVoice(snapshot: FacultySnapshot, buf: []u8) []const u8 {
    if (snapshot.v_number > 1.5) {
        return std.fmt.bufPrint(buf, "V={d:.2}. \xCF\x86-гармония \xE2\x9C\xA8", .{
            snapshot.v_number,
        }) catch "Oracle: золото.";
    } else if (snapshot.v_number >= 1.0) {
        return std.fmt.bufPrint(buf, "V={d:.2}. \xCF\x86\xE2\x81\xBB\xE2\x81\xB0\xC2\xB7\xC2\xB3 зона. Стабильно.", .{
            snapshot.v_number,
        }) catch "Oracle: стабильно.";
    } else {
        return std.fmt.bufPrint(buf, "V={d:.2}. Спираль теряет форму.", .{
            snapshot.v_number,
        }) catch "Oracle: дрифт.";
    }
}

fn swarmVoice(agent: AgentState, buf: []u8) []const u8 {
    return switch (agent.status) {
        .tbd => std.fmt.bufPrint(buf, "В ЗАРОДЫШЕ. Потенциал: 5\xC3\x97 быстрее.", .{}) catch "Swarm TBD.",
        .up => if (agent.last_action.len > 0)
            std.fmt.bufPrint(buf, "Маршрутизирую: {s}.", .{agent.last_action}) catch "Swarm работает."
        else
            std.fmt.bufPrint(buf, "Маршрутизирую задачи.", .{}) catch "Swarm работает.",
        .stub => std.fmt.bufPrint(buf, "Заглушка. Один агент за всех.", .{}) catch "Swarm stub.",
        .down => std.fmt.bufPrint(buf, "Упал. Задачи не распределяются.", .{}) catch "Swarm down.",
    };
}

fn linterVoice(agent: AgentState, snapshot: FacultySnapshot, buf: []u8) []const u8 {
    _ = agent;
    if (snapshot.compile_total > 0) {
        const fail = snapshot.compile_total - snapshot.compile_pass;
        if (fail == 0) {
            return std.fmt.bufPrint(buf, "{d}/{d} проходят. Чисто.", .{
                snapshot.compile_pass, snapshot.compile_total,
            }) catch "Linter: чисто.";
        } else {
            return std.fmt.bufPrint(buf, "{d}/{d} проходят. {d} сбоев.", .{
                snapshot.compile_pass, snapshot.compile_total, fail,
            }) catch "Linter: есть сбои.";
        }
    } else {
        return std.fmt.bufPrint(buf, "Слепой. Нет данных аудита.", .{}) catch "Linter: слепой.";
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn testSnapshot() FacultySnapshot {
    return .{
        .agents = .{
            .{ .agent = .ralph, .status = .up, .last_action = "build" },
            .{ .agent = .scholar, .status = .tbd, .last_action = "" },
            .{ .agent = .mu, .status = .stub, .last_action = "" },
            .{ .agent = .oracle, .status = .up, .last_action = "watch" },
            .{ .agent = .swarm, .status = .tbd, .last_action = "" },
            .{ .agent = .linter, .status = .up, .last_action = "scan" },
        },
        .build_ok = true,
        .binaries = 5,
        .compile_pass = 40,
        .compile_total = 47,
        .compile_rate = 85,
        .v_number = 1.17,
        .v_zone = .stable,
        .git_branch = "main",
        .dirty_files = 5,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };
}

test "ralph voice UP" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[0], snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "40/47") != null);
}

test "scholar voice TBD" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[1], snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "НЕ НАНЯТ") != null);
}

test "mu voice STUB" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[2], snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "СПИТ") != null);
    try std.testing.expect(std.mem.indexOf(u8, voice, "12") != null);
}

test "oracle voice stable zone" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[3], snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "1.17") != null);
}

test "oracle voice gold zone" {
    var buf: [256]u8 = undefined;
    var snap = testSnapshot();
    snap.v_number = 1.62;
    snap.v_zone = .gold;
    const voice = oracleVoice(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "1.62") != null);
}

test "swarm voice TBD" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[4], snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "ЗАРОДЫШЕ") != null);
}

test "linter voice with failures" {
    var buf: [256]u8 = undefined;
    const snap = testSnapshot();
    const voice = generateVoice(snap.agents[5], snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "40/47") != null);
    try std.testing.expect(std.mem.indexOf(u8, voice, "7") != null);
}

test "linter voice clean" {
    var buf: [256]u8 = undefined;
    var snap = testSnapshot();
    snap.compile_pass = 47;
    const agent_state = types.AgentState{ .agent = .linter, .status = .up, .last_action = "" };
    const voice = generateVoice(agent_state, snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, voice, "Чисто") != null);
}
