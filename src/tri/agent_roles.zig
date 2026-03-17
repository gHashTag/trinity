// ═════════════════════════════════════════════════════════════════════════════
// AGENT ROLES — Meta-Observation Layer for Trinity
// ═══════════════════════════════════════════════════════════════════════════════
// Maps agent names to observer roles with symbols and descriptions
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const AgentRole = enum {
    // === META-OBSERVERS (slow, deep) ===
    oracle,
    sentinel,
    muse,
    scholar,
    chronos,

    // === INNER OBSERVERS (fast, reactive) ===
    cortex,
    salience_network,
    pathology_analyst,
    voice_narrator,
    thalamus_relay,

    // === MEMORY STORES ===
    hippocampus,

    // === SENSORY INPUT (Wave 3) ===
    cerebellum,
    hypothalamus,

    // === CORPUS CALLOSUM (Wave 4) ===
    corpus_callosum,

    // === ACTORS / CONTROLLERS ===
    phoenix_core,
    basal_ganglia,
    evolution_events,
    farm_orchestrator,
    arena_competition,

    // === UNKNOWN ===
    unknown,
};

/// Role descriptions for display
pub fn roleDescription(role: AgentRole) []const u8 {
    return switch (role) {
        .oracle => "🔮 ORACLE — Deep review, long-term patterns",
        .sentinel => "🛡️ SENTINEL — Risk monitoring",
        .muse => "🔍 MUSE — Research & anomaly detection",
        .scholar => "📚 SCHOLAR — Active research",
        .chronos => "⏰ CHRONOS — Time & rhythm monitoring",
        .cortex => "CORTEX — State observer, world model",
        .salience_network => "SALIENCE — Importance filter",
        .pathology_analyst => "PATHOLOGY — Health analyst",
        .voice_narrator => "VOICE — Narrator output",
        .thalamus_relay => "THALAMUS — Signal router",
        .hippocampus => "HIPPOCAMPUS — Memory store",
        .cerebellum => "CEREBELLUM — Cell health monitoring",
        .hypothalamus => "HYPOTHALAMUS — Metabolism & anomaly detection",
        .corpus_callosum => "CORPUS CALLOSUM — Inter-hemisphere memory transfer",
        .phoenix_core => "PHOENIX_CORE — Immune system, executor",
        .basal_ganglia => "BASAL_GANGLIA — Procedural memory (MU)",
        .evolution_events => "EVOLUTION — Events (kill/crash)",
        .farm_orchestrator => "FARM — Training orchestration",
        .arena_competition => "ARENA — Model battles",
        .unknown => "UNKNOWN — Unidentified",
    };
}

/// Symbol for role (emoji)
pub fn roleSymbol(role: AgentRole) []const u8 {
    return switch (role) {
        .oracle => "🔮",
        .sentinel => "🛡️",
        .muse => "🔍",
        .scholar => "📚",
        .chronos => "⏰",
        .cortex => "🧠",
        .salience_network => "👁",
        .pathology_analyst => "🩺",
        .voice_narrator => "🗣️",
        .thalamus_relay => "⚛️",
        .hippocampus => "🧠",
        .cerebellum => "🧠",
        .hypothalamus => "🌡",
        .corpus_callosum => "🌉",
        .phoenix_core => "🧬",
        .basal_ganglia => "🧠",
        .evolution_events => "💀",
        .farm_orchestrator => "🧬",
        .arena_competition => "⚔️",
        .unknown => "❓",
    };
}

/// Lookup table: Agent → Role
/// Returns UNKNOWN if agent not mapped
pub fn agentToRole(agent_name: []const u8) AgentRole {
    const mapping = [_]struct { []const u8, AgentRole }{
        .{ "cortex", .cortex },
        .{ "phoenix", .phoenix_core },
        .{ "queen", .salience_network },
        .{ "pathology", .pathology_analyst },
        .{ "hippocampus", .hippocampus },
        .{ "thalamus", .thalamus_relay },
        .{ "voice", .voice_narrator },
        .{ "mu", .basal_ganglia },
        .{ "mu_learning_db", .basal_ganglia },
        .{ "mu_error_protocol", .basal_ganglia },
        .{ "evolution", .evolution_events },
        .{ "farm", .farm_orchestrator },
        .{ "arena", .corpus_callosum },
        .{ "arena_competition", .corpus_callosum },
        .{ "oracle", .oracle },
        .{ "sentinel", .sentinel },
        .{ "scholar", .scholar },
        .{ "muse", .muse },
        .{ "chronos", .chronos },
        .{ "cerebellum", .cerebellum },
        .{ "hypothalamus", .hypothalamus },
    };

    for (mapping) |entry| {
        if (std.mem.eql(u8, agent_name, entry[0])) {
            return entry[1];
        }
    }
    return .unknown;
}

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "agent_roles agentToRole returns correct role" {
    try std.testing.expectEqual(agentToRole("cortex"), .cortex);
    try std.testing.expectEqual(agentToRole("mu"), .basal_ganglia);
    try std.testing.expectEqual(agentToRole("phoenix"), .phoenix_core);
    try std.testing.expectEqual(agentToRole("unknown_agent"), .unknown);
}

test "agent_roles roleSymbol returns emoji" {
    try std.testing.expectEqual(roleSymbol(.oracle), "🔮");
    try std.testing.expectEqual(roleSymbol(.basal_ganglia), "🧠");
    try std.testing.expectEqual(roleSymbol(.thalamus_relay), "⚛️");
    try std.testing.expectEqual(roleSymbol(.unknown), "❓");
}

test "agent_roles roleDescription returns description" {
    const desc = roleDescription(.cortex);
    try std.testing.expect(std.mem.indexOf(u8, desc, "CORTEX") != null);
}
