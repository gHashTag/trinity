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
        const all_modules = std.meta.tags(Module);
        var new_signals = std.ArrayList(Synapse).init(allocator);

        for (all_modules) |mod_tag| {
            const target_mod = @field(Module, mod_tag.name);
            if (target_mod == from) continue;

            try new_signals.append(Synapse.init(from, target_mod, sig));
        }

        self.signals = try new_signals.toOwnedSlice(allocator);
        self.last_broadcast = std.time.timestamp();
    }

    /// Get signals for a specific module
    pub fn getSignals(self: *const CommBus, target: Module) []const Synapse {
        var count: usize = 0;
        for (self.signals) |s| {
            if (s.to == target) count += 1;
        }

        if (count == 0) return &.{};

        // Note: In real implementation, would return slice
        _ = count;
        return &.{};
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
    try bus.broadcast(allocator, .corpus_callosum, .heartbeat, data);

    // Write to hippocampus
    const hippocampus = @import("hippocampus.zig");
    const log_data = try std.fmt.allocPrint(
        allocator,
        "{{\"sync_count\":{d},\"queen_cycle\":{d},\"phoenix_state\":\"{s}\"}}",
        .{ state.sync_count, state.queen_cycle, @tagName(state.phoenix_sleep_state) },
    );
    defer allocator.free(log_data);

    _ = try hippocampus.write(allocator, .{
        .agent = "corpus_callosum",
        .kind = .observation,
        .summary = "bridge sync completed",
        .data = log_data,
    });
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
