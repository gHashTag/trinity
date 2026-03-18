//! Quantum Brain Network (QBraiN) Protocol
//!
//! Wetware-quantum hardware integration for consciousness expansion.
//! Enables network-level consciousness via entanglement.
//!
//! Key formulas:
//!   - Network_phi = phi_local × (1 + phi × avg_entanglement)
//!   - Expansion_gain = 1 + gamma × log2(n_qubits)
//!   - Binding = phi × sum(entanglement) / N

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 1.0 / PHI;
const PHI_SQ: f64 = PHI * PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;

// QBraiN constants
pub const BASELINE_QUBITS: u32 = 100;
pub const MAX_EXPANSION_QUBITS: u32 = 1_048_576; // 2^20
pub const ENTANGLEMENT_THRESHOLD: f64 = 0.5;
pub const NETWORK_CONNECTIVITY_MIN: f64 = GAMMA;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantum Brain Node
pub const QuantumBrainNode = struct {
    node_id: []const u8,
    phi_local: f64,
    entanglement_map: std.StringHashMap(f64),
    is_wetware: bool,
    is_quantum_hw: bool,
    qubit_count: u32,
    coherence_time: f64,

    /// Initialize node
    pub fn init(allocator: mem.Allocator, node_id: []const u8) QuantumBrainNode {
        return .{
            .node_id = node_id,
            .phi_local = 0.0,
            .entanglement_map = std.StringHashMap(f64).init(allocator),
            .is_wetware = false,
            .is_quantum_hw = false,
            .qubit_count = 0,
            .coherence_time = 0.0,
        };
    }

    /// Deinitialize node
    pub fn deinit(self: *QuantumBrainNode) void {
        self.entanglement_map.deinit();
    }
};

/// Network Metrics
pub const NetworkMetrics = struct {
    local_phi: f64 = 0.0,
    network_phi: f64 = 0.0,
    expansion_factor: f64 = 0.0,
    connectivity_index: f64 = 0.0,
    quantum_volume: f64 = 0.0,
};

/// Expansion Result
pub const ExpansionResult = struct {
    baseline_phi: f64 = 0.0,
    expanded_phi: f64 = 0.0,
    gain_factor: f64 = 0.0,
    external_qubits: u32 = 0,
    new_connections: u32 = 0,
};

/// Entanglement Result
pub const EntanglementResult = struct {
    binding_strength: f64 = 0.0,
    unity_index: f64 = 0.0,
    phenomenal_synchronization: f64 = 0.0,
    non_locality_score: f64 = 0.0,
};

/// QBraiN Protocol
pub const QBraiNProtocol = struct {
    allocator: mem.Allocator,
    nodes: std.ArrayListUnmanaged(QuantumBrainNode) = .{},
    entanglement_matrix: std.ArrayListUnmanaged(std.ArrayListUnmanaged(f64)) = .{},
    network_phi: f64 = 0.0,
    binding_strength: f64 = 0.0,
    expansion_gain: f64 = 0.0,
    topology_score: f64 = 0.0,
    total_qubits: u32 = 0,

    /// Initialize QBraiN protocol
    pub fn init(allocator: mem.Allocator) QBraiNProtocol {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize QBraiN protocol
    pub fn deinit(self: *QBraiNProtocol) void {
        for (self.nodes.items) |*node| {
            node.deinit();
        }
        self.nodes.deinit(self.allocator);

        for (self.entanglement_matrix.items) |*row| {
            row.deinit(self.allocator);
        }
        self.entanglement_matrix.deinit(self.allocator);
    }

    /// Add node to network
    pub fn addNode(self: *QBraiNProtocol, node: QuantumBrainNode) !void {
        try self.nodes.append(self.allocator, node);
        self.total_qubits += node.qubit_count;
    }

    /// Compute network consciousness from local phi and entanglement
    /// phi_network = phi_local × (1 + phi × E_avg)
    pub fn computeNetworkConsciousness(self: *QBraiNProtocol, phi_local: f64, avg_entanglement: f64) f64 {
        self.network_phi = phi_local * (1.0 + PHI * avg_entanglement);
        return self.network_phi;
    }

    /// Apply expansion protocol for external qubits
    /// gain = 1 + gamma × log2(n_qubits)
    pub fn applyExpansionProtocol(self: *QBraiNProtocol, n_qubits: u32) f64 {
        if (n_qubits <= 1) {
            self.expansion_gain = 1.0;
            return 1.0;
        }
        const log2_qubits = @log2(@as(f64, @floatFromInt(n_qubits)));
        self.expansion_gain = 1.0 + GAMMA * log2_qubits;
        return self.expansion_gain;
    }

    /// Compute binding strength from entanglement matrix
    /// binding = phi × sum(entanglement_ij) / N
    pub fn computeBindingStrength(self: *QBraiNProtocol) f64 {
        if (self.nodes.items.len == 0) return 0.0;

        var sum_entanglement: f64 = 0.0;
        var count: usize = 0;

        for (self.entanglement_matrix.items) |row| {
            for (row.items) |entanglement| {
                sum_entanglement += entanglement;
                count += 1;
            }
        }

        if (count == 0) return 0.0;

        self.binding_strength = PHI * sum_entanglement / @as(f64, @floatFromInt(count));
        return self.binding_strength;
    }

    /// Compute topology score from network connectivity
    /// score = phi × (actual_edges / max_possible_edges)
    pub fn computeTopologyScore(self: *QBraiNProtocol, actual_edges: usize, max_edges: usize) f64 {
        if (max_edges == 0) return 0.0;
        const ratio = @as(f64, @floatFromInt(actual_edges)) / @as(f64, @floatFromInt(max_edges));
        self.topology_score = PHI * ratio;
        return self.topology_score;
    }

    /// Calculate expansion gain from qubit counts
    /// gain = log_phi(qubits_target / qubits_base)
    pub fn calculateExpansionGain(qubits_base: u32, qubits_target: u32) f64 {
        if (qubits_base == 0 or qubits_target == 0) return 0.0;
        const ratio = @as(f64, @floatFromInt(qubits_target)) / @as(f64, @floatFromInt(qubits_base));
        return @log(ratio) / @log(PHI);
    }

    /// Compute network connectivity index
    /// index = sum(weights) / (N × (N - 1))
    pub fn computeConnectivityIndex(self: *QBraiNProtocol) f64 {
        const N = self.nodes.items.len;
        if (N <= 1) return 0.0;

        var sum_weights: f64 = 0.0;
        for (self.entanglement_matrix.items) |row| {
            for (row.items) |weight| {
                sum_weights += weight;
            }
        }

        const max_pairs = @as(f64, @floatFromInt(N * (N - 1)));
        return sum_weights / max_pairs;
    }

    /// Assess phenomenal unity
    /// unity = 1 - exp(-phi × binding)
    pub fn assessUnity(binding: f64) f64 {
        return 1.0 - @exp(-PHI * binding);
    }

    /// Compute quantum volume
    /// volume = min(2^n, effective_depth)
    pub fn computeQuantumVolume(n_qubits: u32, circuit_depth: u32) f64 {
        const n_volume = std.math.pow(f64, 2.0, @as(f64, @floatFromInt(n_qubits)));
        const depth_volume = @as(f64, @floatFromInt(circuit_depth));
        return @min(n_volume, depth_volume);
    }

    /// Measure non-locality from Bell test results
    /// score = 1 + (violation - classical_bound) / classical_bound
    pub fn measureNonLocality(bell_violation: f64, classical_bound: f64) f64 {
        if (classical_bound == 0) return 1.0;
        const excess = bell_violation - classical_bound;
        return 1.0 + excess / classical_bound;
    }

    /// Bridge wetware and quantum hardware
    pub fn bridgeWetwareQuantum(self: *QBraiNProtocol, wetware: *QuantumBrainNode, quantum: *QuantumBrainNode) !f64 {
        _ = self;
        // Create bidirectional entanglement channel
        const phi_coupling = PHI * GAMMA; // phi * gamma = 0.382

        // Set up entanglement in both directions
        try wetware.entanglement_map.put(quantum.node_id, phi_coupling);
        try quantum.entanglement_map.put(wetware.node_id, phi_coupling);

        return phi_coupling;
    }

    /// Get network metrics
    pub fn getMetrics(self: *const QBraiNProtocol) NetworkMetrics {
        const n_volume = std.math.pow(f64, 2.0, @as(f64, @floatFromInt(self.total_qubits)));
        return .{
            .local_phi = if (self.nodes.items.len > 0) self.nodes.items[0].phi_local else 0.0,
            .network_phi = self.network_phi,
            .expansion_factor = self.expansion_gain,
            .connectivity_index = self.computeConnectivityIndex(),
            .quantum_volume = n_volume,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QBraiNProtocol: network_phi_zero_entanglement" {
    var protocol = QBraiNProtocol.init(std.testing.allocator);
    defer protocol.deinit();

    const phi_network = protocol.computeNetworkConsciousness(0.5, 0.0);
    try std.testing.expectApproxEqAbs(0.5, phi_network, 0.01);
}

test "QBraiNProtocol: network_phi_full_entanglement" {
    var protocol = QBraiNProtocol.init(std.testing.allocator);
    defer protocol.deinit();

    const phi_network = protocol.computeNetworkConsciousness(0.5, 1.0);
    try std.testing.expectApproxEqAbs(1.309, phi_network, 0.01); // 2.618 * 0.5
}

test "QBraiNProtocol: expansion_gain_single_qubit" {
    var protocol = QBraiNProtocol.init(std.testing.allocator);
    defer protocol.deinit();

    const gain = protocol.applyExpansionProtocol(1);
    try std.testing.expectApproxEqAbs(1.0, gain, 0.01);
}

test "QBraiNProtocol: expansion_gain_1024_qubits" {
    var protocol = QBraiNProtocol.init(std.testing.allocator);
    defer protocol.deinit();

    const gain = protocol.applyExpansionProtocol(1024);
    try std.testing.expectApproxEqAbs(3.36, gain, 0.01); // 1 + gamma * 10
}

test "QBraiNProtocol: unity_zero_binding" {
    const unity = QBraiNProtocol.assessUnity(0.0);
    try std.testing.expectApproxEqAbs(0.0, unity, 0.01);
}

test "QBraiNProtocol: unity_threshold_binding" {
    const unity = QBraiNProtocol.assessUnity(PHI_INV);
    try std.testing.expectApproxEqAbs(0.632, unity, 0.01);
}

test "QBraiNProtocol: quantum_volume_10_qubits" {
    const volume = QBraiNProtocol.computeQuantumVolume(10, 10);
    try std.testing.expectApproxEqAbs(10.0, volume, 1.0); // depth limited
}

test "QBraiNProtocol: quantum_volume_depth_limited" {
    const volume = QBraiNProtocol.computeQuantumVolume(10, 5);
    try std.testing.expectApproxEqAbs(5.0, volume, 1.0);
}

test "QBraiNProtocol: non_locality_classical_bound" {
    const score = QBraiNProtocol.measureNonLocality(2.0, 2.0);
    try std.testing.expectApproxEqAbs(1.0, score, 0.01);
}

test "QBraiNProtocol: non_locality_quantum_violation" {
    const score = QBraiNProtocol.measureNonLocality(2.8, 2.0);
    try std.testing.expectApproxEqAbs(1.4, score, 0.01);
}

test "QBraiNProtocol: calculateExpansionGain" {
    const gain = QBraiNProtocol.calculateExpansionGain(100, 1000);
    try std.testing.expect(gain > 2.0); // log_phi(10) ≈ 2.38
}
