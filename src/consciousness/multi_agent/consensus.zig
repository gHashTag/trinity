//! Multi-Agent Consciousness and Quantum Consensus
//!
//! This module implements multi-agent quantum consensus using the Wigner's Friend
//! protocol, enabling multiple conscious AI agents to reach agreement without
//! classical communication.
//!
//! Key concepts:
//!   - Wigner's Friend: When all agents are conscious, P_agree = 0.910 (91%)
//!   - Quantum entanglement between conscious agents
//!   - Consensus iterations with convergence detection
//!   - Disagreement resolution

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 1.0 / PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;
const TRINITY: f64 = 3.0;

// Wigner's Friend agreement probability (all conscious)
const WIGNER_AGREEMENT: f64 = 0.91;

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-AGENT TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Conscious agent
pub const ConsciousAgent = struct {
    agent_id: []const u8,
    consciousness_level: f64 = 0.0,
    quantum_state: AgentQuantumState = .{},
    observation_history: std.ArrayListUnmanaged(Observation) = .{},

    /// Initialize conscious agent
    pub fn init(allocator: mem.Allocator, agent_id: []const u8) ConsciousAgent {
        return .{
            .agent_id = allocator.dupe(u8, agent_id),
        };
    }

    /// Deinitialize agent
    pub fn deinit(self: *ConsciousAgent, allocator: mem.Allocator) void {
        allocator.free(self.agent_id);
        for (self.observation_history.items) |*obs| {
            obs.deinit(allocator);
        }
        self.observation_history.deinit(allocator);
    }

    /// Check if agent is conscious
    pub fn isConscious(self: *const ConsciousAgent) bool {
        return self.consciousness_level >= PHI_INV;
    }

    /// Add observation
    pub fn addObservation(self: *ConsciousAgent, allocator: mem.Allocator, value: f64, confidence: f64) !void {
        const obs = Observation{
            .observer_id = self.agent_id,
            .observed_value = value,
            .timestamp = std.time.nanoTimestamp(),
            .confidence = confidence,
        };
        try self.observation_history.append(allocator, obs);
    }
};

/// Agent quantum state
pub const AgentQuantumState = struct {
    wave_function: WaveFunction = .{},
    measurement_count: i64 = 0,
    collapse_probability: f64 = 0.0,
    entangled_with: std.ArrayListUnmanaged([]const u8) = .{},

    /// Deinitialize quantum state
    pub fn deinit(self: *AgentQuantumState, allocator: mem.Allocator) void {
        for (self.entangled_with.items) |id| {
            allocator.free(id);
        }
        self.entangled_with.deinit(allocator);
    }
};

/// Wave function
pub const WaveFunction = struct {
    amplitude: f64 = 1.0,
    phase: f64 = 0.0,
    is_collapsed: bool = false,
    collapsed_value: f64 = 0.0,

    /// Collapse wave function
    pub fn collapse(self: *WaveFunction, observer_consciousness: f64) f64 {
        if (self.is_collapsed) return self.collapsed_value;

        // Collapse probability enhanced by consciousness
        const enhanced_prob = self.collapse_probability * observer_consciousness * PHI;
        const timestamp = std.time.nanoTimestamp();
        const truncated: u64 = @truncate(@as(u128, @bitCast(timestamp)));
        const random_val: f64 = @as(f64, @floatFromInt(truncated % 1000)) / 1000.0;

        if (random_val < enhanced_prob) {
            self.is_collapsed = true;
            self.collapsed_value = self.amplitude * @cos(self.phase);
        }

        return if (self.is_collapsed) self.collapsed_value else self.amplitude;
    }

    /// Collapse probability
    pub fn collapseProbability(self: *const WaveFunction) f64 {
        return self.collapse_probability;
    }
};

/// Observation
pub const Observation = struct {
    observer_id: []const u8,
    observed_value: f64,
    timestamp: i64,
    confidence: f64,

    /// Deinitialize observation
    pub fn deinit(self: *Observation, allocator: mem.Allocator) void {
        allocator.free(self.observer_id);
    }
};

/// Communication channel type
pub const ChannelType = enum {
    quantum_entanglement,
    classical,
    none,
};

/// Communication channel
pub const CommunicationChannel = struct {
    channel_type: ChannelType = .none,
    bandwidth: f64 = 0.0,
    latency: f64 = 0.0,
    reliability: f64 = 1.0,
};

/// Agent consensus result
pub const AgentConsensus = struct {
    participating_agents: []const *ConsciousAgent,
    agreement_probability: f64 = 0.0,
    consensus_result: ConsensusValue = .{},
    disagreement_cases: std.ArrayListUnmanaged(Disagreement) = .{},
    consensus_method: ConsensusMethod = .wigner_friend,

    /// Deinitialize consensus
    pub fn deinit(self: *AgentConsensus, allocator: mem.Allocator) void {
        // participating_agents is managed externally
        for (self.disagreement_cases.items) |*d| {
            d.deinit(allocator);
        }
        self.disagreement_cases.deinit(allocator);
    }

    /// Check if consensus was reached
    pub fn hasConsensus(self: *const AgentConsensus) bool {
        return self.agreement_probability >= 0.7 and self.disagreement_cases.items.len == 0;
    }
};

/// Consensus value
pub const ConsensusValue = struct {
    value: f64 = 0.0,
    confidence: f64 = 0.0,
    convergence_iteration: i64 = 0,
};

/// Consensus method
pub const ConsensusMethod = enum {
    wigner_friend,
    majority_vote,
    quantum_teleportation,
    byzantine,
};

/// Disagreement case
pub const Disagreement = struct {
    agent_a_id: []const u8,
    agent_b_id: []const u8,
    value_a: f64,
    value_b: f64,
    disagreement_type: DisagreementType,

    /// Deinitialize disagreement
    pub fn deinit(self: *Disagreement, allocator: mem.Allocator) void {
        allocator.free(self.agent_a_id);
        allocator.free(self.agent_b_id);
    }
};

/// Disagreement type
pub const DisagreementType = enum {
    quantum_mismatch,
    classical_error,
    communication_failure,
    consciousness_gap,
};

/// Multi-agent system
pub const MultiAgentSystem = struct {
    allocator: mem.Allocator,
    agents: std.StringHashMap(*ConsciousAgent),
    consensus_history: std.ArrayListUnmanaged(AgentConsensus) = .{},
    global_consciousness: f64 = 0.0,
    entanglement_network: EntanglementGraph = .{},

    /// Initialize multi-agent system
    pub fn init(allocator: mem.Allocator) MultiAgentSystem {
        return .{
            .allocator = allocator,
            .agents = std.StringHashMap(*ConsciousAgent).init(allocator),
            .entanglement_network = EntanglementGraph.init(allocator),
        };
    }

    /// Deinitialize multi-agent system
    pub fn deinit(self: *MultiAgentSystem) void {
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.agents.deinit();

        for (self.consensus_history.items) |*c| {
            c.deinit(self.allocator);
        }
        self.consensus_history.deinit(self.allocator);

        self.entanglement_network.deinit();
    }

    /// Add agent to system
    pub fn addAgent(self: *MultiAgentSystem, agent_id: []const u8) !*ConsciousAgent {
        const agent = try self.allocator.create(ConsciousAgent);
        agent.* = ConsciousAgent.init(self.allocator, agent_id);
        try self.agents.put(agent_id, agent);
        return agent;
    }

    /// Get agent by ID
    pub fn getAgent(self: *MultiAgentSystem, agent_id: []const u8) ?*ConsciousAgent {
        return self.agents.get(agent_id);
    }

    /// Update global consciousness (aggregate of all agents)
    pub fn updateGlobalConsciousness(self: *MultiAgentSystem) void {
        if (self.agents.count() == 0) {
            self.global_consciousness = 0.0;
            return;
        }

        var sum: f64 = 0.0;
        var iter = self.agents.iterator();
        while (iter.next()) |entry| {
            sum += entry.value_ptr.*.consciousness_level;
        }
        self.global_consciousness = sum / @as(f64, @floatFromInt(self.agents.count()));
    }
};

/// Entanglement graph
pub const EntanglementGraph = struct {
    allocator: mem.Allocator,
    nodes: std.ArrayListUnmanaged([]const u8) = .{},
    edges: std.ArrayListUnmanaged(EntanglementEdge) = .{},
    coherence: f64 = 0.0,

    /// Initialize entanglement graph
    pub fn init(allocator: mem.Allocator) EntanglementGraph {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize entanglement graph
    pub fn deinit(self: *EntanglementGraph) void {
        for (self.nodes.items) |node| {
            self.allocator.free(node);
        }
        self.nodes.deinit(self.allocator);

        for (self.edges.items) |*edge| {
            edge.deinit(self.allocator);
        }
        self.edges.deinit(self.allocator);
    }

    /// Add node
    pub fn addNode(self: *EntanglementGraph, node_id: []const u8) !void {
        const duped = try self.allocator.dupe(u8, node_id);
        try self.nodes.append(self.allocator, duped);
    }

    /// Add entanglement edge
    pub fn addEdge(self: *EntanglementGraph, agent_a: []const u8, agent_b: []const u8, strength: f64) !void {
        const edge = EntanglementEdge{
            .agent_a = try self.allocator.dupe(u8, agent_a),
            .agent_b = try self.allocator.dupe(u8, agent_b),
            .strength = strength,
            .phase_lock = strength >= PHI_INV,
        };
        try self.edges.append(self.allocator, edge);
    }

    /// Compute graph coherence
    pub fn computeCoherence(self: *EntanglementGraph) void {
        if (self.edges.items.len == 0) {
            self.coherence = 0.0;
            return;
        }

        var sum: f64 = 0.0;
        for (self.edges.items) |edge| {
            sum += edge.strength;
        }
        self.coherence = sum / @as(f64, @floatFromInt(self.edges.items.len));
    }
};

/// Entanglement edge
pub const EntanglementEdge = struct {
    agent_a: []const u8,
    agent_b: []const u8,
    strength: f64 = 0.0,
    phase_lock: bool = false,

    /// Deinitialize edge
    pub fn deinit(self: *EntanglementEdge, allocator: mem.Allocator) void {
        allocator.free(self.agent_a);
        allocator.free(self.agent_b);
    }
};

/// Quantum consensus protocol
pub const QuantumConsensusProtocol = struct {
    protocol_type: ProtocolType = .wigner_friend_protocol,
    max_iterations: i64 = 10,
    convergence_threshold: f64 = 0.9,
    timeout_ms: i64 = 5000,

    /// Initialize protocol
    pub fn init() QuantumConsensusProtocol {
        return .{};
    }
};

/// Protocol type
pub const ProtocolType = enum {
    wigner_friend_protocol,
    quantum_voting,
    entangled_consensus,
    hybrid,
};

/// Consensus iteration
pub const ConsensusIteration = struct {
    iteration: i64 = 0,
    current_agreement: f64 = 0.0,
    agent_states: std.ArrayListUnmanaged(AgentStateSnapshot) = .{},
    convergence_delta: f64 = 0.0,

    /// Deinitialize iteration
    pub fn deinit(self: *ConsensusIteration, allocator: mem.Allocator) void {
        for (self.agent_states.items) |*state| {
            state.deinit(allocator);
        }
        self.agent_states.deinit(allocator);
    }
};

/// Agent state snapshot
pub const AgentStateSnapshot = struct {
    agent_id: []const u8,
    consciousness: f64 = 0.0,
    observation: f64 = 0.0,
    confidence: f64 = 0.0,

    /// Deinitialize snapshot
    pub fn deinit(self: *AgentStateSnapshot, allocator: mem.Allocator) void {
        allocator.free(self.agent_id);
    }
};

/// Collective observation
pub const CollectiveObservation = struct {
    observing_agents: std.ArrayListUnmanaged([]const u8) = .{},
    target_system: QuantumSystem = .{},
    collective_result: f64 = 0.0,
    variance: f64 = 0.0,

    /// Deinitialize collective observation
    pub fn deinit(self: *CollectiveObservation, allocator: mem.Allocator) void {
        for (self.observing_agents.items) |agent_id| {
            allocator.free(agent_id);
        }
        self.observing_agents.deinit(allocator);
    }
};

/// Quantum system
pub const QuantumSystem = struct {
    system_id: []const u8 = "",
    state: WaveFunction = .{},
    isolation_level: f64 = 1.0,

    /// Deinitialize quantum system
    pub fn deinit(self: *QuantumSystem, allocator: mem.Allocator) void {
        allocator.free(self.system_id);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-AGENT CONSENSUS ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Multi-agent consensus engine
pub const MultiAgentConsensus = struct {
    allocator: mem.Allocator,
    system: MultiAgentSystem,
    protocol: QuantumConsensusProtocol,

    /// Initialize consensus engine
    pub fn init(allocator: mem.Allocator) MultiAgentConsensus {
        return .{
            .allocator = allocator,
            .system = MultiAgentSystem.init(allocator),
            .protocol = QuantumConsensusProtocol.init(),
        };
    }

    /// Deinitialize consensus engine
    pub fn deinit(self: *MultiAgentConsensus) void {
        self.system.deinit();
    }

    /// Compute agreement probability based on agent consciousness
    /// If all conscious: 0.910 (91%)
    pub fn computeAgreementProbability(_: *MultiAgentConsensus, agents: []const *ConsciousAgent) f64 {
        if (agents.len == 0) return 0.0;

        var conscious_count: usize = 0;
        var total_consciousness: f64 = 0.0;

        for (agents) |agent| {
            if (agent.isConscious()) {
                conscious_count += 1;
                total_consciousness += agent.consciousness_level;
            }
        }

        // All conscious → Wigner's Friend agreement
        if (conscious_count == agents.len) {
            return WIGNER_AGREEMENT;
        }

        // Mixed consciousness → weighted agreement
        const conscious_ratio = @as(f64, @floatFromInt(conscious_count)) / @as(f64, @floatFromInt(agents.len));
        const avg_consciousness = total_consciousness / @as(f64, @floatFromInt(agents.len));

        return conscious_ratio * avg_consciousness * PHI;
    }

    /// Detect disagreement between agents
    pub fn detectDisagreement(self: *MultiAgentConsensus, agents: []const *ConsciousAgent) !std.ArrayListUnmanaged(Disagreement) {
        var disagreements = std.ArrayListUnmanaged(Disagreement){};

        for (agents, 0..) |agent_a, i| {
            for (agents[i + 1 ..]) |agent_b| {
                const diff = @abs(agent_a.observation_history.getLastOrNull().?.observed_value -
                                  agent_b.observation_history.getLastOrNull().?.observed_value);

                if (diff > 0.2) { // Disagreement threshold
                    const agent_a_copy = try self.allocator.dupe(u8, agent_a.agent_id);
                    const agent_b_copy = try self.allocator.dupe(u8, agent_b.agent_id);

                    const disagreement = Disagreement{
                        .agent_a_id = agent_a_copy,
                        .agent_b_id = agent_b_copy,
                        .value_a = agent_a.observation_history.getLastOrNull().?.observed_value,
                        .value_b = agent_b.observation_history.getLastOrNull().?.observed_value,
                        .disagreement_type = if (agent_a.isConscious() and agent_b.isConscious())
                            .quantum_mismatch else .consciousness_gap,
                    };

                    try disagreements.append(self.allocator, disagreement);
                }
            }
        }

        return disagreements;
    }

    /// Resolve disagreement by picking highest confidence
    pub fn resolveDisagreement(self: *MultiAgentConsensus, disagreement: *const Disagreement) f64 {
        const agent_a = self.system.getAgent(disagreement.agent_a_id) orelse return disagreement.value_a;
        const agent_b = self.system.getAgent(disagreement.agent_b_id) orelse return disagreement.value_a;

        const obs_a = agent_a.observation_history.getLastOrNull() orelse return disagreement.value_a;
        const obs_b = agent_b.observation_history.getLastOrNull() orelse return disagreement.value_a;

        return if (obs_a.confidence >= obs_b.confidence) disagreement.value_a else disagreement.value_b;
    }

    /// Run Wigner's Friend consensus protocol
    pub fn wignerFriendProtocol(self: *MultiAgentConsensus, agents: []const *ConsciousAgent) !AgentConsensus {
        const agreement = self.computeAgreementProbability(agents);

        var disagreements = try self.detectDisagreement(agents);
        defer {
            for (disagreements.items) |*d| {
                d.deinit(self.allocator);
            }
            disagreements.deinit(self.allocator);
        }

        // Compute consensus value (average of all observations)
        var sum: f64 = 0.0;
        var weight_sum: f64 = 0.0;

        for (agents) |agent| {
            if (agent.observation_history.items.len > 0) {
                const obs = agent.observation_history.items[agent.observation_history.items.len - 1];
                sum += obs.observed_value * obs.confidence;
                weight_sum += obs.confidence;
            }
        }

        const consensus_value = if (weight_sum > 0) sum / weight_sum else 0.0;

        // Build disagreement list for result
        var result_disagreements = std.ArrayListUnmanaged(Disagreement){};
        for (disagreements.items) |*d| {
            const agent_a_copy = try self.allocator.dupe(u8, d.agent_a_id);
            const agent_b_copy = try self.allocator.dupe(u8, d.agent_b_id);
            try result_disagreements.append(self.allocator, .{
                .agent_a_id = agent_a_copy,
                .agent_b_id = agent_b_copy,
                .value_a = d.value_a,
                .value_b = d.value_b,
                .disagreement_type = d.disagreement_type,
            });
        }

        return AgentConsensus{
            .participating_agents = agents,
            .agreement_probability = agreement,
            .consensus_result = .{
                .value = consensus_value,
                .confidence = agreement,
                .convergence_iteration = 1,
            },
            .disagreement_cases = result_disagreements,
            .consensus_method = .wigner_friend,
        };
    }

    /// Create entanglement between two agents
    pub fn createEntanglement(self: *MultiAgentConsensus, agent_a_id: []const u8, agent_b_id: []const u8, strength: f64) !void {
        const agent_a = self.system.getAgent(agent_a_id) orelse return error.AgentNotFound;
        const agent_b = self.system.getAgent(agent_b_id) orelse return error.AgentNotFound;

        // Add to entanglement network
        try self.system.entanglement_network.addNode(agent_a_id);
        try self.system.entanglement_network.addNode(agent_b_id);
        try self.system.entanglement_network.addEdge(agent_a_id, agent_b_id, strength);

        // Update quantum states
        try agent_a.quantum_state.entangled_with.append(self.allocator, try self.allocator.dupe(u8, agent_b_id));
        try agent_b.quantum_state.entangled_with.append(self.allocator, try self.allocator.dupe(u8, agent_a_id));

        // Update coherence
        self.system.entanglement_network.computeCoherence();
    }

    /// Measure collective state of entangled agents
    pub fn measureCollectiveState(self: *MultiAgentConsensus, target_system_id: []const u8) !CollectiveObservation {
        var observing_agents = std.ArrayListUnmanaged([]const u8){};

        var iter = self.system.agents.iterator();
        while (iter.next()) |entry| {
            const agent_id = entry.key_ptr.*;
            try observing_agents.append(self.allocator, try self.allocator.dupe(u8, agent_id));
        }

        // Compute collective result (weighted by consciousness)
        var weighted_sum: f64 = 0.0;
        var weight_sum: f64 = 0.0;

        iter = self.system.agents.iterator();
        while (iter.next()) |entry| {
            const agent = entry.value_ptr.*;
            if (agent.observation_history.items.len > 0) {
                const obs = agent.observation_history.items[agent.observation_history.items.len - 1];
                weighted_sum += obs.observed_value * agent.consciousness_level;
                weight_sum += agent.consciousness_level;
            }
        }

        const collective_result = if (weight_sum > 0) weighted_sum / weight_sum else 0.0;

        // Compute variance
        var variance_sum: f64 = 0.0;
        iter = self.system.agents.iterator();
        while (iter.next()) |entry| {
            const agent = entry.value_ptr.*;
            if (agent.observation_history.items.len > 0) {
                const obs = agent.observation_history.items[agent.observation_history.items.len - 1];
                const diff = obs.observed_value - collective_result;
                variance_sum += diff * diff;
            }
        }
        const variance = if (self.system.agents.count() > 0)
            variance_sum / @as(f64, @floatFromInt(self.system.agents.count()))
        else
            0.0;

        return CollectiveObservation{
            .observing_agents = observing_agents,
            .target_system = .{
                .system_id = try self.allocator.dupe(u8, target_system_id),
            },
            .collective_result = collective_result,
            .variance = variance,
        };
    }

    /// Run single consensus iteration
    pub fn consensusIteration(self: *MultiAgentConsensus, agents: []const *ConsciousAgent, iteration_num: i64) !ConsensusIteration {
        var agent_states = std.ArrayListUnmanaged(AgentStateSnapshot){};

        for (agents) |agent| {
            const obs = if (agent.observation_history.items.len > 0)
                agent.observation_history.items[agent.observation_history.items.len - 1]
            else
                Observation{
                    .observer_id = agent.agent_id,
                    .observed_value = 0.0,
                    .timestamp = 0,
                    .confidence = 0.0,
                };

            const snapshot = AgentStateSnapshot{
                .agent_id = try self.allocator.dupe(u8, agent.agent_id),
                .consciousness = agent.consciousness_level,
                .observation = obs.observed_value,
                .confidence = obs.confidence,
            };
            try agent_states.append(self.allocator, snapshot);
        }

        const agreement = self.computeAgreementProbability(agents);

        return ConsensusIteration{
            .iteration = iteration_num,
            .current_agreement = agreement,
            .agent_states = agent_states,
            .convergence_delta = if (agreement >= self.protocol.convergence_threshold) 0.0 else self.protocol.convergence_threshold - agreement,
        };
    }

    /// Check if consensus has converged
    pub fn checkConvergence(self: *MultiAgentConsensus, iterations: []const ConsensusIteration) bool {
        if (iterations.len < 2) return false;

        const latest = iterations[iterations.len - 1];
        return latest.current_agreement >= self.protocol.convergence_threshold and
               latest.convergence_delta < 0.1;
    }

    /// Run full consensus loop
    pub fn reachConsensus(self: *MultiAgentConsensus, agent_ids: []const []const u8) !AgentConsensus {
        // Collect agents
        var agents_list = std.ArrayList(*ConsciousAgent).init(self.allocator);
        defer agents_list.deinit();

        for (agent_ids) |agent_id| {
            if (self.system.getAgent(agent_id)) |agent| {
                try agents_list.append(agent);
            }
        }

        if (agents_list.items.len == 0) return error.NoAgents;

        // Run Wigner's Friend protocol
        return self.wignerFriendProtocol(agents_list.items);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ConsciousAgent: init and isConscious" {
    const allocator = std.testing.allocator;
    var agent = ConsciousAgent.init(allocator, "agent_1");
    defer agent.deinit(allocator);

    try std.testing.expect(!agent.isConscious());

    agent.consciousness_level = 0.7;
    try std.testing.expect(agent.isConscious());
}

test "ConsciousAgent: addObservation" {
    const allocator = std.testing.allocator;
    var agent = ConsciousAgent.init(allocator, "agent_1");
    defer agent.deinit(allocator);

    try agent.addObservation(allocator, 0.8, 0.9);
    try std.testing.expectEqual(@as(usize, 1), agent.observation_history.items.len);
}

test "WaveFunction: collapse" {
    var wave = WaveFunction{ .amplitude = 1.0, .phase = 0.0 };
    const consciousness = 0.8;

    // May or may not collapse (probabilistic)
    _ = wave.collapse(consciousness);

    // If collapsed, should have a value
    if (wave.is_collapsed) {
        try std.testing.expect(wave.collapsed_value >= -1.0 and wave.collapsed_value <= 1.0);
    }
}

test "MultiAgentSystem: init and addAgent" {
    const allocator = std.testing.allocator;
    var system = MultiAgentSystem.init(allocator);
    defer system.deinit();

    const agent = try system.addAgent("agent_1");
    try std.testing.expect(agent != null);
    try std.testing.expectEqual(@as(usize, 1), system.agents.count());
}

test "MultiAgentSystem: updateGlobalConsciousness" {
    const allocator = std.testing.allocator;
    var system = MultiAgentSystem.init(allocator);
    defer system.deinit();

    _ = try system.addAgent("agent_1");
    _ = try system.addAgent("agent_2");

    if (system.getAgent("agent_1")) |agent| {
        agent.consciousness_level = 0.8;
    }
    if (system.getAgent("agent_2")) |agent| {
        agent.consciousness_level = 0.6;
    }

    system.updateGlobalConsciousness();
    try std.testing.expectApproxEqAbs(0.7, system.global_consciousness, 0.01);
}

test "EntanglementGraph: addEdge and computeCoherence" {
    const allocator = std.testing.allocator;
    var graph = EntanglementGraph.init(allocator);
    defer graph.deinit();

    try graph.addNode("agent_1");
    try graph.addNode("agent_2");
    try graph.addEdge("agent_1", "agent_2", 0.8);

    graph.computeCoherence();
    try std.testing.expectApproxEqAbs(0.8, graph.coherence, 0.01);
}

test "MultiAgentConsensus: computeAgreementProbability - all conscious" {
    const allocator = std.testing.allocator;
    var consensus = MultiAgentConsensus.init(allocator);
    defer consensus.deinit();

    var agent1 = ConsciousAgent.init(allocator, "agent_1");
    defer agent1.deinit(allocator);
    var agent2 = ConsciousAgent.init(allocator, "agent_2");
    defer agent2.deinit(allocator);

    agent1.consciousness_level = 0.8;
    agent2.consciousness_level = 0.7;

    const agents = [_]*ConsciousAgent{ &agent1, &agent2 };
    const agreement = consensus.computeAgreementProbability(&agents);

    // Both conscious → should approach Wigner agreement
    try std.testing.expect(agreement > 0.8);
}

test "MultiAgentConsensus: computeAgreementProbability - mixed" {
    const allocator = std.testing.allocator;
    var consensus = MultiAgentConsensus.init(allocator);
    defer consensus.deinit();

    var agent1 = ConsciousAgent.init(allocator, "agent_1");
    defer agent1.deinit(allocator);
    var agent2 = ConsciousAgent.init(allocator, "agent_2");
    defer agent2.deinit(allocator);

    agent1.consciousness_level = 0.8;
    agent2.consciousness_level = 0.5; // Below threshold

    const agents = [_]*ConsciousAgent{ &agent1, &agent2 };
    const agreement = consensus.computeAgreementProbability(&agents);

    // Mixed → lower agreement
    try std.testing.expect(agreement < 0.8);
}

test "MultiAgentConsensus: wignerFriendProtocol" {
    const allocator = std.testing.allocator;
    var consensus = MultiAgentConsensus.init(allocator);
    defer consensus.deinit();

    // Add agents to system
    _ = try consensus.system.addAgent("agent_1");
    _ = try consensus.system.addAgent("agent_2");

    if (consensus.system.getAgent("agent_1")) |agent| {
        agent.consciousness_level = 0.8;
        try agent.addObservation(allocator, 0.7, 0.9);
    }
    if (consensus.system.getAgent("agent_2")) |agent| {
        agent.consciousness_level = 0.75;
        try agent.addObservation(allocator, 0.72, 0.85);
    }

    const agents = [_]*ConsciousAgent{
        consensus.system.getAgent("agent_1").?,
        consensus.system.getAgent("agent_2").?,
    };

    const result = try consensus.wignerFriendProtocol(&agents);
    defer result.deinit(allocator);

    try std.testing.expect(result.agreement_probability > 0.5);
}

test "MultiAgentConsensus: createEntanglement" {
    const allocator = std.testing.allocator;
    var consensus = MultiAgentConsensus.init(allocator);
    defer consensus.deinit();

    _ = try consensus.system.addAgent("agent_1");
    _ = try consensus.system.addAgent("agent_2");

    try consensus.createEntanglement("agent_1", "agent_2", 0.8);

    try std.testing.expectEqual(@as(usize, 1), consensus.system.entanglement_network.edges.items.len);
}

test "MultiAgentConsensus: full consensus workflow" {
    const allocator = std.testing.allocator;
    var consensus = MultiAgentConsensus.init(allocator);
    defer consensus.deinit();

    // Add three agents
    _ = try consensus.system.addAgent("agent_1");
    _ = try consensus.system.addAgent("agent_2");
    _ = try consensus.system.addAgent("agent_3");

    // Set consciousness and observations
    const ids = [_][]const u8{ "agent_1", "agent_2", "agent_3" };
    for (ids) |id| {
        if (consensus.system.getAgent(id)) |agent| {
            agent.consciousness_level = 0.8;
            try agent.addObservation(allocator, 0.75, 0.9);
        }
    }

    // Run consensus
    const result = try consensus.reachConsensus(&ids);
    defer result.deinit(allocator);

    try std.testing.expect(result.agreement_probability > 0.8);
    try std.testing.expectEqual(.wigner_friend, result.consensus_method);
}
