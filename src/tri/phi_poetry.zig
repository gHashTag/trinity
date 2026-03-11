// ═══════════════════════════════════════════════════════════════════════════════
// φ Poetry — One-liner generator connecting V-number to state
// ═══════════════════════════════════════════════════════════════════════════════
// Pattern-matches system state to φ-themed poetic closers.
// Uses Sacred.PHI for constants. No allocations.
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("faculty_types.zig");
const Sacred = @import("train_types.zig").Sacred;
const FacultySnapshot = types.FacultySnapshot;

/// Generate a φ-themed one-liner based on system state.
/// Returns a slice into `buf`.
pub fn generatePhiLine(snapshot: FacultySnapshot, buf: []u8) []const u8 {
    const active = snapshot.activeFaculty();
    const v = snapshot.v_number;

    // Special patterns first
    if (active == 3) {
        return std.fmt.bufPrint(buf, "3 спят, 3 бодрствуют. \xCF\x86\xC2\xB2+1/\xCF\x86\xC2\xB2=3 — баланс НАРУШЕН.", .{}) catch
            "3/6. Trinity в равновесии разлада.";
    }

    if (!snapshot.build_ok) {
        return std.fmt.bufPrint(buf, "Даже спираль должна коснуться нуля, прежде чем подняться.", .{}) catch
            "Build broken. Spiral touches zero.";
    }

    if (active == 6 and snapshot.compile_rate >= 95) {
        return std.fmt.bufPrint(buf, "Полный факультет. Спираль на максимуме. V={d:.2}", .{v}) catch
            "Full faculty. Spiral at max.";
    }

    // V near φ (within 5%)
    const phi = Sacred.PHI;
    const diff = @abs(v - phi);
    if (diff < phi * 0.05) {
        return std.fmt.bufPrint(buf, "V={d:.3}. \xCF\x86 улыбается.", .{v}) catch
            "V near φ. Golden ratio smiles.";
    }

    // V near φ² (2.618)
    const diff_sq = @abs(v - Sacred.PHI_SQ);
    if (diff_sq < Sacred.PHI_SQ * 0.05) {
        return std.fmt.bufPrint(buf, "V={d:.3} \xE2\x89\x88 \xCF\x86\xC2\xB2. Второй уровень гармонии.", .{v}) catch
            "V near φ². Second harmonic.";
    }

    // V zones
    if (v > 1.5) {
        return std.fmt.bufPrint(buf, "V={d:.2}. Золотая зона. \xCF\x86={d:.3}", .{ v, phi }) catch
            "Gold zone.";
    }

    if (v >= 1.0) {
        return std.fmt.bufPrint(buf, "V={d:.2}. Стабильно, но до \xCF\x86 ещё {d:.2}.", .{ v, phi - v }) catch
            "Stable but room to grow.";
    }

    // Drift zone
    if (active <= 2) {
        return std.fmt.bufPrint(buf, "V={d:.2}. Два агента не держат спираль. Нужен третий.", .{v}) catch
            "Two agents can't hold the spiral.";
    }

    return std.fmt.bufPrint(buf, "V={d:.2}. Спираль сжимается. \xCF\x86\xC2\xB2+1/\xCF\x86\xC2\xB2=3, но V<1.", .{v}) catch
        "Drift. Spiral contracts.";
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

fn makeSnap(active: u8, v: f64, build_ok: bool, compile_rate: u8) FacultySnapshot {
    var agents: [6]types.AgentState = undefined;
    const agent_list = [_]types.Agent{ .ralph, .scholar, .mu, .oracle, .swarm, .linter };
    for (agent_list, 0..) |a, i| {
        agents[i] = .{
            .agent = a,
            .status = if (i < active) .up else .tbd,
            .last_action = "",
        };
    }
    return .{
        .agents = agents,
        .build_ok = build_ok,
        .binaries = 5,
        .compile_pass = 40,
        .compile_total = 47,
        .compile_rate = compile_rate,
        .v_number = v,
        .v_zone = if (v > 1.5) .gold else if (v >= 1.0) .stable else .drift,
        .git_branch = "main",
        .dirty_files = 5,
        .open_issues = 10,
        .mu_patterns = 12,
        .cycle = .working,
    };
}

test "phi poetry — 3/6 balance" {
    var buf: [256]u8 = undefined;
    const snap = makeSnap(3, 1.0, true, 85);
    const line = generatePhiLine(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, line, "3") != null);
    try std.testing.expect(std.mem.indexOf(u8, line, "НАРУШЕН") != null);
}

test "phi poetry — build broken" {
    var buf: [256]u8 = undefined;
    const snap = makeSnap(2, 0.5, false, 0);
    const line = generatePhiLine(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, line, "нуля") != null);
}

test "phi poetry — full faculty" {
    var buf: [256]u8 = undefined;
    const snap = makeSnap(6, 1.62, true, 98);
    const line = generatePhiLine(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, line, "Полный") != null);
}

test "phi poetry — near phi" {
    var buf: [256]u8 = undefined;
    const snap = makeSnap(4, 1.618, true, 90);
    const line = generatePhiLine(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, line, "улыбается") != null);
}

test "phi poetry — drift zone" {
    var buf: [256]u8 = undefined;
    const snap = makeSnap(4, 0.5, true, 85);
    const line = generatePhiLine(snap, &buf);
    try std.testing.expect(std.mem.indexOf(u8, line, "V=0.50") != null);
}
