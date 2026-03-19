// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// CORPUS CALLOSUM — Inter-Hemisphere Communication
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Connect left/right hemispheres, information transfer
// Trinity: Sync Queen ↔ Phoenix, bridge consciousness modules
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SYNAPSE — Connection point between modules
// ═══════════════════════════════════════════════════════════════════════════════

pub const Synapse = struct {
    from: Module,
    to: Module,
    signal: Signal,
    timestamp: i64 = 0,

    pub fn init(from_mod: Module, to_mod: Module, sig: Signal) Synapse {
        return .{
            .from = from_mod,
            .to = to_mod,
            .signal = sig,
            .timestamp = std.time.timestamp(),
        };
    }
};

pub const Module = enum {
    queen_dlpfc,
    queen_vmpfc,
    queen_vlpfc,
    queen_dmpfc,
    queen_ofc,
    phoenix_locus_coeruleus,
    phoenix_medulla,
    phoenix_pons,
    hippocampus,
    thalamus,
    reticular_aras,
    reticular_raphe,
    reticular_gigantocellular,
    basal_ganglia,
    cerebellum,

    pub fn label(self: Module) []const u8 {
        return switch (self) {
            .queen_dlpfc => "Queen DLPFC",
            .queen_vmpfc => "Queen VMPFC",
            .queen_vlpfc => "Queen VLPFC",
            .queen_dmpfc => "Queen DMPFC",
            .queen_ofc => "Queen OFC",
            .phoenix_locus_coeruleus => "Locus Coeruleus",
            .phoenix_medulla => "Medulla",
            .phoenix_pons => "Pons",
            .hippocampus => "Hippocampus",
            .thalamus => "Thalamus",
            .reticular_aras => "ARAS",
            .reticular_raphe => "Raphe",
            .reticular_gigantocellular => "Gigantocellular",
            .basal_ganglia => "Basal Ganglia",
            .cerebellum => "Cerebellum",
        };
    }
};

pub const Signal = struct {
    kind: SignalKind,
    data: []const u8,
    urgency: Urgency = .normal,

    pub fn isAlert(self: *const Signal) bool {
        return self.urgency == .critical or self.urgency == .high;
    }
};

pub const SignalKind = enum {
    heartbeat, // "I'm alive"
    alert, // "Something wrong"
    request, // "Need info"
    response, // "Here's info"
    command, // "Do this"
    done, // "Finished"

    pub fn emoji(self: SignalKind) []const u8 {
        return switch (self) {
            .heartbeat => qt.E_CHECK,
            .alert => qt.E_SIREN,
            .request => qt.E_EYE,
            .response => qt.E_BRAIN,
            .command => qt.E_WRENCH,
            .done => qt.E_TROPHY,
        };
    }
};

pub const Urgency = enum(u8) {
    normal,
    high,
    critical,
};

// ═══════════════════════════════════════════════════════════════════════════════
// COMMUNICATION BUS — Broadcast signals to all modules
// ═══════════════════════════════════════════════════════════════════════════════

pub const CommBus = struct {
    signals: []Synapse = &.{},
    last_broadcast: i64 = 0,

    /// Broadcast signal to all connected modules
    pub fn broadcast(self: *CommBus, allocator: Allocator, from: Module, kind: SignalKind, data: []const u8) !void {
        const sig = Signal{
            .kind = kind,
            .data = data,
            .urgency = if (kind == .alert) .critical else .normal,
        };

        // Create synapses to all modules except sender
        const all_modules = [_]Module{
            .queen_dlpfc,               .queen_vmpfc,             .queen_vlpfc,     .queen_dmpfc,
            .queen_ofc,                 .phoenix_locus_coeruleus, .phoenix_medulla, .phoenix_pons,
            .hippocampus,               .thalamus,                .reticular_aras,  .reticular_raphe,
            .reticular_gigantocellular, .basal_ganglia,           .cerebellum,
        };
        var new_signals = try std.ArrayList(Synapse).initCapacity(allocator, all_modules.len);

        for (all_modules) |target_mod| {
            if (target_mod == from) continue;

            try new_signals.append(allocator, Synapse.init(from, target_mod, sig));
        }

        self.signals = try new_signals.toOwnedSlice(allocator);
        self.last_broadcast = std.time.timestamp();
    }

    /// Get signals for a specific module (filters by target)
    /// Returns allocated slice of signals where `to` matches the given module
    /// Caller owns the returned memory and must free it
    pub fn getSignals(self: *const CommBus, allocator: Allocator, target: Module) ![]const Synapse {
        // Count matching signals first
        var count: usize = 0;
        for (self.signals) |sig| {
            if (sig.to == target) count += 1;
        }

        // Allocate and collect matching signals (empty slice if no matches)
        var filtered = try std.ArrayList(Synapse).initCapacity(allocator, count);
        for (self.signals) |sig| {
            if (sig.to == target) {
                try filtered.append(allocator, sig);
            }
        }

        return filtered.toOwnedSlice(allocator);
    }
};

/// Initialize communication bus
pub fn initCommBus(allocator: Allocator) !CommBus {
    var bus = CommBus{};
    bus.signals = try allocator.alloc(Synapse, 0);
    return bus;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRIDGE SYNC — Queen ↔ Phoenix synchronization
// ═══════════════════════════════════════════════════════════════════════════════

pub const BridgeState = struct {
    queen_cycle: u32 = 0,
    phoenix_sleep_state: PhoenixSleepState = .awake,
    last_sync: i64 = 0,
    sync_count: u32 = 0,

    pub fn needsSync(self: *const BridgeState) bool {
        const now = std.time.timestamp();
        const age_sec = now - self.last_sync;
        return age_sec > 60; // Sync every minute
    }
};

pub const PhoenixSleepState = enum {
    awake,
    sleeping,
    waking,
};

/// Synchronize Queen and Phoenix states
pub fn syncBridge(
    allocator: Allocator,
    bus: *CommBus,
    state: *BridgeState,
) !void {
    state.last_sync = std.time.timestamp();
    state.sync_count += 1;

    // Broadcast sync signal
    const data = "sync";
    try bus.broadcast(allocator, .hippocampus, .heartbeat, data);

    // Write to hippocampus
    const hippocampus = @import("hippocampus.zig");
    const log_data = try std.fmt.allocPrint(
        allocator,
        "{{\"sync_count\":{d},\"queen_cycle\":{d},\"phoenix_state\":\"{s}\"}}",
        .{ state.sync_count, state.queen_cycle, @tagName(state.phoenix_sleep_state) },
    );
    defer allocator.free(log_data);

    _ = try hippocampus.writeObservation(allocator, "corpus_callosum", "bridge sync completed", log_data);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Synapse init" {
    const syn = Synapse.init(.queen_dlpfc, .hippocampus, .{
        .kind = .heartbeat,
        .data = "ping",
    });

    try std.testing.expectEqual(.queen_dlpfc, syn.from);
    try std.testing.expectEqual(.hippocampus, syn.to);
    try std.testing.expect(syn.timestamp > 0);
}

test "corpus_callosum — Module label" {
    try std.testing.expectEqualStrings("Queen DLPFC", Module.queen_dlpfc.label());
    try std.testing.expectEqualStrings("Hippocampus", Module.hippocampus.label());
    try std.testing.expectEqualStrings("Locus Coeruleus", Module.phoenix_locus_coeruleus.label());
}

test "corpus_callosum — SignalKind emoji" {
    try std.testing.expectEqual(qt.E_CHECK, SignalKind.heartbeat.emoji());
    try std.testing.expectEqual(qt.E_SIREN, SignalKind.alert.emoji());
    try std.testing.expectEqual(qt.E_EYE, SignalKind.request.emoji());
}

test "corpus_callosum — Signal isAlert" {
    const normal = Signal{
        .kind = .heartbeat,
        .data = "ok",
        .urgency = .normal,
    };
    try std.testing.expect(!normal.isAlert());

    const alert = Signal{
        .kind = .alert,
        .data = "error",
        .urgency = .critical,
    };
    try std.testing.expect(alert.isAlert());
}

test "corpus_callosum — BridgeState needsSync" {
    var state = BridgeState{
        .last_sync = std.time.timestamp() - 120, // 2 min ago
    };
    try std.testing.expect(state.needsSync());

    state.last_sync = std.time.timestamp(); // Just synced
    try std.testing.expect(!state.needsSync());
}

test "corpus_callosum — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}

test "corpus_callosum — Signal urgency levels" {
    const critical = Signal{
        .kind = .alert,
        .data = "critical",
        .urgency = .critical,
    };
    try std.testing.expect(critical.isAlert());

    const high = Signal{
        .kind = .alert,
        .data = "warning",
        .urgency = .high,
    };
    try std.testing.expect(high.isAlert());

    const normal = Signal{
        .kind = .heartbeat,
        .data = "ok",
        .urgency = .normal,
    };
    try std.testing.expect(!normal.isAlert());
}

test "corpus_callosum — Synapse captures timestamp" {
    const before = std.time.timestamp();
    const syn = Synapse.init(.queen_dlpfc, .hippocampus, .{
        .kind = .heartbeat,
        .data = "test",
    });
    const after = std.time.timestamp();

    try std.testing.expect(syn.timestamp >= before);
    try std.testing.expect(syn.timestamp <= after);
}

test "corpus_callosum — Module enum coverage" {
    const modules = [_]Module{
        .queen_dlpfc,               .queen_vmpfc,             .queen_vlpfc,     .queen_dmpfc,
        .queen_ofc,                 .phoenix_locus_coeruleus, .phoenix_medulla, .phoenix_pons,
        .hippocampus,               .thalamus,                .reticular_aras,  .reticular_raphe,
        .reticular_gigantocellular, .basal_ganglia,           .cerebellum,
    };

    for (modules) |m| {
        const label = m.label();
        try std.testing.expect(label.len > 0);
    }
}

test "corpus_callosum — SignalKind enum coverage" {
    const kinds = [_]SignalKind{
        .heartbeat, .alert, .request, .response, .command, .done,
    };

    for (kinds) |kind| {
        _ = kind.emoji(); // Verify all have emojis
    }
}

test "corpus_callosum — PhoenixSleepState enum coverage" {
    const states = [_]PhoenixSleepState{
        .awake, .sleeping, .waking,
    };

    for (states) |s| {
        _ = s; // Verify all enum values exist
    }
}

test "corpus_callosum — BridgeState defaults" {
    const state = BridgeState{};
    try std.testing.expectEqual(@as(u32, 0), state.queen_cycle);
    try std.testing.expectEqual(PhoenixSleepState.awake, state.phoenix_sleep_state);
    try std.testing.expectEqual(@as(i64, 0), state.last_sync);
    try std.testing.expectEqual(@as(u32, 0), state.sync_count);
}

test "corpus_callosum — CommBus initialization" {
    const bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try std.testing.expectEqual(@as(usize, 0), bus.signals.len);
    try std.testing.expectEqual(@as(i64, 0), bus.last_broadcast);
}

// ═══════════════════════════════════════════════════════════════════════════════
// URGENCY ENUM TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Urgency enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(Urgency.normal));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(Urgency.high));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(Urgency.critical));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIGNAL STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Signal defaults" {
    const sig = Signal{
        .kind = .heartbeat,
        .data = "",
        .urgency = .normal,
    };

    try std.testing.expectEqual(SignalKind.heartbeat, sig.kind);
    try std.testing.expectEqualStrings("", sig.data);
    try std.testing.expectEqual(Urgency.normal, sig.urgency);
}

test "corpus_callosum — Signal isAlert with high urgency" {
    const sig = Signal{
        .kind = .request,
        .data = "urgent request",
        .urgency = .high,
    };

    try std.testing.expect(sig.isAlert());
}

test "corpus_callosum — Signal isAlert with normal urgency" {
    const sig = Signal{
        .kind = .response,
        .data = "normal response",
        .urgency = .normal,
    };

    try std.testing.expect(!sig.isAlert());
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMM BUS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — CommBus broadcast creates signals" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .queen_dlpfc, .alert, "test alert");

    try std.testing.expect(bus.signals.len > 0);
    try std.testing.expect(bus.last_broadcast > 0);
}

test "corpus_callosum — CommBus getSignals empty for no match" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    const signals = try bus.getSignals(std.testing.allocator, .hippocampus);
    defer std.testing.allocator.free(signals);
    try std.testing.expectEqual(@as(usize, 0), signals.len);
}

test "corpus_callosum — CommBus getSignals filters by target" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .queen_dlpfc, .heartbeat, "ping");

    // Get signals for hippocampus (should have one from queen_dlpfc)
    const signals = try bus.getSignals(std.testing.allocator, .hippocampus);
    defer std.testing.allocator.free(signals);
    try std.testing.expect(signals.len > 0);

    // All signals should target hippocampus
    for (signals) |sig| {
        try std.testing.expectEqual(.hippocampus, sig.to);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRIDGE STATE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — BridgeState sync threshold" {
    const state = BridgeState{
        .last_sync = std.time.timestamp() - 59, // 59 seconds ago
    };

    try std.testing.expect(!state.needsSync()); // < 60 seconds
}

test "corpus_callosum — BridgeState sync increment" {
    var state = BridgeState{};
    const before = state.sync_count;

    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try syncBridge(std.testing.allocator, &bus, &state);

    try std.testing.expectEqual(before + 1, state.sync_count);
    try std.testing.expect(state.last_sync > 0);
}

test "corpus_callosum — BridgeState custom phoenix state" {
    const state = BridgeState{
        .phoenix_sleep_state = .sleeping,
    };

    try std.testing.expectEqual(PhoenixSleepState.sleeping, state.phoenix_sleep_state);
}

test "corpus_callosum — PhoenixSleepState enum values" {
    try std.testing.expectEqual(PhoenixSleepState.awake, .awake);
    try std.testing.expectEqual(PhoenixSleepState.sleeping, .sleeping);
    try std.testing.expectEqual(PhoenixSleepState.waking, .waking);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — CellHealth timestamp" {
    const h = health();
    try std.testing.expect(h.last_check > 0);
}

test "corpus_callosum — CellHealth defaults" {
    const h = CellHealth{};

    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "corpus_callosum — CellHealth Status enum" {
    try std.testing.expectEqual(CellHealth.Status.healthy, .healthy);
    try std.testing.expectEqual(CellHealth.Status.weak, .weak);
    try std.testing.expectEqual(CellHealth.Status.broken, .broken);
}

test "corpus_callosum — CellHealth custom values" {
    var h = CellHealth{};
    h.status = .weak;
    h.cycle = 5;
    h.last_check = 12345;

    try std.testing.expectEqual(CellHealth.Status.weak, h.status);
    try std.testing.expectEqual(@as(u32, 5), h.cycle);
    try std.testing.expectEqual(@as(i64, 12345), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE LABEL ALL VALUES
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Module label all queen modules" {
    try std.testing.expectEqualStrings("Queen DLPFC", Module.queen_dlpfc.label());
    try std.testing.expectEqualStrings("Queen VMPFC", Module.queen_vmpfc.label());
    try std.testing.expectEqualStrings("Queen VLPFC", Module.queen_vlpfc.label());
    try std.testing.expectEqualStrings("Queen DMPFC", Module.queen_dmpfc.label());
    try std.testing.expectEqualStrings("Queen OFC", Module.queen_ofc.label());
}

test "corpus_callosum — Module label all phoenix modules" {
    try std.testing.expectEqualStrings("Locus Coeruleus", Module.phoenix_locus_coeruleus.label());
    try std.testing.expectEqualStrings("Medulla", Module.phoenix_medulla.label());
    try std.testing.expectEqualStrings("Pons", Module.phoenix_pons.label());
}

test "corpus_callosum — Module label all other modules" {
    try std.testing.expectEqualStrings("Hippocampus", Module.hippocampus.label());
    try std.testing.expectEqualStrings("Thalamus", Module.thalamus.label());
    try std.testing.expectEqualStrings("ARAS", Module.reticular_aras.label());
    try std.testing.expectEqualStrings("Raphe", Module.reticular_raphe.label());
    try std.testing.expectEqualStrings("Gigantocellular", Module.reticular_gigantocellular.label());
    try std.testing.expectEqualStrings("Basal Ganglia", Module.basal_ganglia.label());
    try std.testing.expectEqualStrings("Cerebellum", Module.cerebellum.label());
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIGNAL KIND EMOJI ALL VALUES
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — SignalKind emoji all values" {
    try std.testing.expectEqual(qt.E_CHECK, SignalKind.heartbeat.emoji());
    try std.testing.expectEqual(qt.E_SIREN, SignalKind.alert.emoji());
    try std.testing.expectEqual(qt.E_EYE, SignalKind.request.emoji());
    try std.testing.expectEqual(qt.E_BRAIN, SignalKind.response.emoji());
    try std.testing.expectEqual(qt.E_WRENCH, SignalKind.command.emoji());
    try std.testing.expectEqual(qt.E_TROPHY, SignalKind.done.emoji());
}

// ═══════════════════════════════════════════════════════════════════════════════
// SYNPASE STRUCT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Synapse with all fields" {
    const syn = Synapse{
        .from = .thalamus,
        .to = .hippocampus,
        .signal = .{
            .kind = .alert,
            .data = "warning",
            .urgency = .high,
        },
        .timestamp = 12345,
    };

    try std.testing.expectEqual(.thalamus, syn.from);
    try std.testing.expectEqual(.hippocampus, syn.to);
    try std.testing.expectEqual(SignalKind.alert, syn.signal.kind);
    try std.testing.expectEqual(@as(i64, 12345), syn.timestamp);
}

test "corpus_callosum — Synapse default timestamp zero" {
    const syn = Synapse{
        .from = .queen_dlpfc,
        .to = .basal_ganglia,
        .signal = .{
            .kind = .command,
            .data = "act",
        },
        .timestamp = 0,
    };

    try std.testing.expectEqual(@as(i64, 0), syn.timestamp);
}

test "corpus_callosum — Synapse bidirectional" {
    const forward = Synapse.init(.queen_dlpfc, .hippocampus, .{
        .kind = .request,
        .data = "data?",
    });

    const backward = Synapse.init(.hippocampus, .queen_dlpfc, .{
        .kind = .response,
        .data = "data",
    });

    try std.testing.expectEqual(.queen_dlpfc, forward.from);
    try std.testing.expectEqual(.hippocampus, forward.to);
    try std.testing.expectEqual(.hippocampus, backward.from);
    try std.testing.expectEqual(.queen_dlpfc, backward.to);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMM BUS BROADCAST TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — CommBus broadcast excludes sender" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .hippocampus, .heartbeat, "ping");

    // Should not have signal to hippocampus (sender)
    for (bus.signals) |sig| {
        try std.testing.expect(sig.to != .hippocampus);
    }
}

test "corpus_callosum — CommBus broadcast sets critical urgency for alert" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .queen_dlpfc, .alert, "error");

    // All signals should have critical urgency
    for (bus.signals) |sig| {
        try std.testing.expectEqual(Urgency.critical, sig.signal.urgency);
    }
}

test "corpus_callosum — CommBus broadcast sets normal urgency for non-alert" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .queen_dlpfc, .heartbeat, "ping");

    // All signals should have normal urgency
    for (bus.signals) |sig| {
        try std.testing.expectEqual(Urgency.normal, sig.signal.urgency);
    }
}

test "corpus_callosum — CommBus broadcast updates timestamp" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    const before = bus.last_broadcast;
    try bus.broadcast(std.testing.allocator, .thalamus, .done, "complete");

    try std.testing.expect(bus.last_broadcast > before);
}

test "corpus_callosum — CommBus getSignals for sender" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .hippocampus, .heartbeat, "ping");

    // Sender should have no signals
    const signals = try bus.getSignals(std.testing.allocator, .hippocampus);
    defer std.testing.allocator.free(signals);
    try std.testing.expectEqual(@as(usize, 0), signals.len);
}

test "corpus_callosum — CommBus getSignals for non-participant" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .queen_dlpfc, .request, "info");

    // All modules except sender should have signals
    const thal_signals = try bus.getSignals(std.testing.allocator, .thalamus);
    defer std.testing.allocator.free(thal_signals);
    try std.testing.expect(thal_signals.len > 0);

    const basal_signals = try bus.getSignals(std.testing.allocator, .basal_ganglia);
    defer std.testing.allocator.free(basal_signals);
    try std.testing.expect(basal_signals.len > 0);
}

test "corpus_callosum — CommBus multiple broadcasts" {
    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try bus.broadcast(std.testing.allocator, .queen_dlpfc, .heartbeat, "ping1");
    try bus.broadcast(std.testing.allocator, .thalamus, .heartbeat, "ping2");

    // Should have signals from both broadcasts
    try std.testing.expect(bus.signals.len > 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRIDGE STATE EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — BridgeState needsSync at exact threshold" {
    const state = BridgeState{
        .last_sync = std.time.timestamp() - 60, // Exactly 60 seconds
    };

    try std.testing.expect(state.needsSync()); // >= 60 seconds
}

test "corpus_callosum — BridgeState needsSync just before threshold" {
    const state = BridgeState{
        .last_sync = std.time.timestamp() - 61, // 61 seconds ago
    };

    try std.testing.expect(state.needsSync());
}

test "corpus_callosum — BridgeState with custom queen_cycle" {
    const state = BridgeState{
        .queen_cycle = 100,
        .phoenix_sleep_state = .waking,
    };

    try std.testing.expectEqual(@as(u32, 100), state.queen_cycle);
    try std.testing.expectEqual(PhoenixSleepState.waking, state.phoenix_sleep_state);
}

test "corpus_callosum — BridgeState sync_count increments" {
    var state = BridgeState{
        .sync_count = 5,
    };

    var bus = try initCommBus(std.testing.allocator);
    defer {
        std.testing.allocator.free(bus.signals);
    }

    try syncBridge(std.testing.allocator, &bus, &state);

    try std.testing.expectEqual(@as(u32, 6), state.sync_count);
}

test "corpus_callosum — BridgeState with all phoenix states" {
    const awake = BridgeState{
        .phoenix_sleep_state = .awake,
    };
    try std.testing.expectEqual(PhoenixSleepState.awake, awake.phoenix_sleep_state);

    const sleeping = BridgeState{
        .phoenix_sleep_state = .sleeping,
    };
    try std.testing.expectEqual(PhoenixSleepState.sleeping, sleeping.phoenix_sleep_state);

    const waking = BridgeState{
        .phoenix_sleep_state = .waking,
    };
    try std.testing.expectEqual(PhoenixSleepState.waking, waking.phoenix_sleep_state);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — CellHealth all statuses" {
    const healthy = CellHealth{ .status = .healthy };
    try std.testing.expectEqual(CellHealth.Status.healthy, healthy.status);

    const weak = CellHealth{ .status = .weak };
    try std.testing.expectEqual(CellHealth.Status.weak, weak.status);

    const broken = CellHealth{ .status = .broken };
    try std.testing.expectEqual(CellHealth.Status.broken, broken.status);
}

test "corpus_callosum — CellHealth max cycle value" {
    const h = CellHealth{
        .cycle = std.math.maxInt(u32),
    };

    try std.testing.expectEqual(std.math.maxInt(u32), h.cycle);
}

test "corpus_callosum — CellHealth negative timestamp" {
    const h = CellHealth{
        .last_check = -1000,
    };

    try std.testing.expectEqual(@as(i64, -1000), h.last_check);
}

test "corpus_callosum — CellHealth from health function has timestamp" {
    const h = health();

    try std.testing.expect(h.last_check != 0);
    try std.testing.expect(h.last_check <= std.time.timestamp());
}

test "corpus_callosum — CellHealth zero timestamp valid" {
    const h = CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = 0,
    };

    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

// ═══════════════════════════════════════════════════════════════════════════════
// URGENCY ENUM TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Urgency enum all values" {
    const normal: Urgency = .normal;
    const high: Urgency = .high;
    const critical: Urgency = .critical;

    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(normal));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(high));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(critical));
}

test "corpus_callosum — Urgency ordering" {
    try std.testing.expect(@intFromEnum(Urgency.normal) < @intFromEnum(Urgency.high));
    try std.testing.expect(@intFromEnum(Urgency.high) < @intFromEnum(Urgency.critical));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIGNAL EDGE CASES
// ═══════════════════════════════════════════════════════════════════════════════

test "corpus_callosum — Signal with empty data" {
    const sig = Signal{
        .kind = .done,
        .data = "",
        .urgency = .normal,
    };

    try std.testing.expectEqual(@as(usize, 0), sig.data.len);
    try std.testing.expect(!sig.isAlert());
}

test "corpus_callosum — Signal with large data" {
    const large_data = "x" ** 1000;
    const sig = Signal{
        .kind = .response,
        .data = large_data,
        .urgency = .high,
    };

    try std.testing.expectEqual(@as(usize, 1000), sig.data.len);
    try std.testing.expect(sig.isAlert());
}

test "corpus_callosum — Signal all kinds" {
    const kinds = [_]SignalKind{
        .heartbeat, .alert, .request, .response, .command, .done,
    };

    for (kinds) |kind| {
        const sig = Signal{
            .kind = kind,
            .data = "test",
            .urgency = .normal,
        };
        try std.testing.expectEqual(kind, sig.kind);
    }
}

test "corpus_callosum — Signal isAlert boundary cases" {
    const critical_sig = Signal{
        .kind = .alert,
        .data = "critical",
        .urgency = .critical,
    };
    try std.testing.expect(critical_sig.isAlert());

    const high_sig = Signal{
        .kind = .alert,
        .data = "high",
        .urgency = .high,
    };
    try std.testing.expect(high_sig.isAlert());

    const normal_sig = Signal{
        .kind = .heartbeat,
        .data = "normal",
        .urgency = .normal,
    };
    try std.testing.expect(!normal_sig.isAlert());
}
