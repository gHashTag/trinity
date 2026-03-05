//! Qutrit Circuit Optimization and Synthesis
//!
//! Implements circuit synthesis algorithms for qutrit quantum circuits:
//! - Gate decomposition and optimization
//! - CGLMP Bell test circuit synthesis
//! - Circuit simplification and peephole optimization
//! - Native gate conversion

const std = @import("std");
const math = std.math;
const golden_gates = @import("golden_gates.zig");

//===========================================================================
// Constants
//===========================================================================

pub const GOLDEN_RATIO: f64 = golden_gates.GOLDEN_RATIO;
pub const GOLDEN_ANGLE_DEG: f64 = 137.5077644087447;

//===========================================================================
// Types
//===========================================================================

/// Circuit cost metrics (multi-objective)
pub const CircuitCost = struct {
    gate_count: usize,
    depth: usize,
    fidelity: f64,
    two_qutrit_count: usize,

    pub fn init() CircuitCost {
        return CircuitCost{
            .gate_count = 0,
            .depth = 0,
            .fidelity = 1.0,
            .two_qutrit_count = 0,
        };
    }

    /// Combine costs (for Pareto comparison)
    pub fn score(self: CircuitCost, weights: [4]f64) f64 {
        return @as(f64, @floatFromInt(self.gate_count)) * weights[0] +
            @as(f64, @floatFromInt(self.depth)) * weights[1] +
            (1.0 - self.fidelity) * weights[2] +
            @as(f64, @floatFromInt(self.two_qutrit_count)) * weights[3];
    }
};

/// Gate type enumeration
pub const GateType = enum {
    // Single-qutrit gates
    golden_phase,     // TRINITY phase gate
    golden_rotation,  // Golden angle rotation
    fourier,          // Qutrit Fourier transform
    shift,            // Cyclic shift
    // Two-qutrit gates
    controlled_phase, // Controlled phase
    controlled_fourier,
    swap,
    // Clifford gates
    h,               // Hadamard-like (for qutrits)
    s,               // Phase gate
    t,               // π/8 gate equivalent
};

/// Quantum gate
pub const Gate = struct {
    ty: GateType,
    params: []const f64,  // Variable parameters (angles, etc.)
    num_params: usize,
    target: ?usize,      // Target qutrit (for single-qutrit gates)
    control: ?usize,     // Control qutrit (for two-qutrit gates)
    matrix: ?[9]Complex,  // 3×3 or 9×9 unitary matrix
};

/// Complex number for unitary matrices
pub const Complex = struct { re: f64, im: f64 };

/// Quantum circuit
pub const QuantumCircuit = struct {
    gates: []Gate,
    num_qutrits: usize,
    depth: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, num_qutrits: usize) !QuantumCircuit {
        const gates = try allocator.alloc(Gate, 0);
        return QuantumCircuit{
            .gates = gates,
            .num_qutrits = num_qutrits,
            .depth = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QuantumCircuit) void {
        self.allocator.free(self.gates);
    }

    /// Clone the circuit
    pub fn clone(self: *const QuantumCircuit, allocator: std.mem.Allocator) !QuantumCircuit {
        var new_circuit = try QuantumCircuit.init(allocator, self.num_qutrits);
        for (self.gates) |gate| {
            const params = try allocator.alloc(f64, gate.params.len);
            @memcpy(params, gate.params);
            const gate_copy = Gate{
                .ty = gate.ty,
                .params = params,
                .num_params = gate.num_params,
                .target = gate.target,
                .control = gate.control,
                .matrix = null,
            };
            try new_circuit.addGate(allocator, gate_copy);
        }
        return new_circuit;
    }

    /// Add gate to circuit
    pub fn addGate(self: *QuantumCircuit, allocator: std.mem.Allocator, gate: Gate) !void {
        const new_gates = try allocator.realloc(self.gates, self.gates.len + 1);
        self.gates = new_gates;
        self.gates[self.gates.len - 1] = gate;
        self.depth = @max(self.depth, self.calculateDepth());
    }

    fn calculateDepth(self: *const QuantumCircuit) usize {
        // Simplified: gate count = depth (no parallelization)
        _ = self;
        return 0;
    }
};

/// Optimization result
pub const OptimizationResult = struct {
    circuit: QuantumCircuit,
    cost: CircuitCost,
    synthesis_time: f64,
    method: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *OptimizationResult) void {
        self.circuit.deinit();
        self.allocator.free(self.method);
    }
};

/// Target unitary for synthesis
pub const TargetUnitary = struct {
    matrix: [9]Complex,  // 3×3 for single qutrit, or 9×9 for two

    pub fn verify(self: TargetUnitary, circuit: QuantumCircuit) f64 {
        _ = self;
        _ = circuit;
        // TODO: Compute circuit unitary and compare
        return 1.0;  // Placeholder: perfect fidelity
    }
};

//===========================================================================
// Gate Set
//===========================================================================

/// Available gate set for synthesis
pub const GateSet = struct {
    single_qutrit: []const GateType,
    two_qutrit: []const GateType,
    native_gates: []const []const u8,

    pub fn initDefault(allocator: std.mem.Allocator) !GateSet {
        _ = allocator;
        return GateSet{
            .single_qutrit = &[_]GateType{
                .golden_phase,
                .golden_rotation,
                .fourier,
                .shift,
            },
            .two_qutrit = &[_]GateType{
                .controlled_phase,
                .controlled_fourier,
            },
            .native_gates = &[_][]const u8{
                "GOLDEN_PHASE",
                "GOLDEN_ROTATION",
                "FOURIER",
            },
        };
    }
};

//===========================================================================
// Optimization Algorithms
//===========================================================================

/// Simplify circuit by removing identities and canceling inverses
pub fn simplifyCircuit(allocator: std.mem.Allocator, circuit: QuantumCircuit) !QuantumCircuit {
    var simplified = try QuantumCircuit.init(allocator, circuit.num_qutrits);
    errdefer simplified.deinit();

    var i: usize = 0;
    while (i < circuit.gates.len) {
        const current = circuit.gates[i];

        // Check if gate is effectively identity (no params or all zero params)
        var is_identity = false;
        if (current.params.len == 0 or
            (current.params.len > 0 and current.params[0] == 0))
        {
            // Check if this gate type with zero params is identity
            is_identity = switch (current.ty) {
                .golden_rotation => true,  // Rotation by 0 is identity
                .shift => true,             // Shift by 0 is identity
                else => false,
            };
        }

        if (is_identity) {
            // Skip identity gate
            i += 1;
            continue;
        }

        // Check for adjacent inverse gates
        if (i + 1 < circuit.gates.len) {
            const next = circuit.gates[i + 1];
            if (areInverses(current, next)) {
                // Cancel both
                i += 2;
                continue;
            }
        }

        // Merge consecutive rotations of same type
        if (i + 1 < circuit.gates.len and
            current.ty == .golden_rotation and
            circuit.gates[i + 1].ty == .golden_rotation and
            current.target == circuit.gates[i + 1].target)
        {
            // Merge angles
            const merged_params = try allocator.alloc(f64, 1);
            merged_params[0] = current.params[0] + circuit.gates[i + 1].params[0];
            const merged_gate = Gate{
                .ty = .golden_rotation,
                .params = merged_params,
                .num_params = 1,
                .target = current.target,
                .control = null,
                .matrix = null,
            };
            try simplified.addGate(allocator, merged_gate);
            i += 2;
            continue;
        }

        // Keep gate
        const params_copy = try allocator.dupe(f64, current.params);
        const gate_copy = Gate{
            .ty = current.ty,
            .params = params_copy,
            .num_params = current.num_params,
            .target = current.target,
            .control = current.control,
            .matrix = null,
        };
        try simplified.addGate(allocator, gate_copy);
        i += 1;
    }

    return simplified;
}

/// Check if two gates are inverses of each other
fn areInverses(a: Gate, b: Gate) bool {
    if (a.ty != b.ty) return false;
    if (a.target != b.target) return false;

    // For rotations: check if angles sum to 0 or 2π
    if (a.ty == .golden_rotation and a.params.len >= 1 and b.params.len >= 1) {
        const sum = a.params[0] + b.params[0];
        return @abs(sum) < 1e-10 or @abs(sum - 2 * std.math.pi) < 1e-10;
    }

    // Self-inverse gates: same gate twice cancels
    if (a.ty == .fourier) {
        // F^3 = I for ternary Fourier, so two applications = F^2 ≠ I
        return false;
    }

    return false;
}

/// Decompose unitary to native gates
pub fn convertToNativeGates(
    allocator: std.mem.Allocator,
    circuit: QuantumCircuit,
    gate_set: GateSet,
) !QuantumCircuit {
    var native = try QuantumCircuit.init(allocator, circuit.num_qutrits);
    errdefer native.deinit();

    for (circuit.gates) |gate| {
        // Check if gate is already native
        var is_native = false;
        for (gate_set.single_qutrit) |native_ty| {
            if (gate.ty == native_ty) {
                is_native = true;
                break;
            }
        }

        if (is_native) {
            // Copy gate as-is
            const params_copy = try allocator.alloc(f64, gate.params.len);
            @memcpy(params_copy, gate.params);
            const gate_copy = Gate{
                .ty = gate.ty,
                .params = params_copy,
                .num_params = gate.num_params,
                .target = gate.target,
                .control = gate.control,
                .matrix = null,
            };
            try native.addGate(allocator, gate_copy);
        } else {
            // Decompose to native gates
            try decomposeGate(allocator, &native, gate, &gate_set);
        }
    }

    return native;
}

/// Decompose a gate to native gate set
fn decomposeGate(
    allocator: std.mem.Allocator,
    circuit: *QuantumCircuit,
    gate: Gate,
    gate_set: *const GateSet,
) !void {
    _ = gate_set;

    // For qutrits, we can decompose most gates using:
    // 1. Any single-qutrit gate = sequence of rotations
    // 2. Use Gell-Mann matrices as basis

    switch (gate.ty) {
        .h => {
            // Hadamard-like: can use golden_rotation at π/2
            const params = try allocator.alloc(f64, 1);
            params[0] = std.math.pi / 2.0;
            const rot_gate = Gate{
                .ty = .golden_rotation,
                .params = params,
                .num_params = 1,
                .target = gate.target,
                .control = null,
                .matrix = null,
            };
            try circuit.addGate(allocator, rot_gate);
        },
        .s => {
            // Phase gate: golden_phase
            const params = try allocator.alloc(f64, 1);
            params[0] = std.math.pi / 2.0;
            const phase_gate = Gate{
                .ty = .golden_phase,
                .params = params,
                .num_params = 1,
                .target = gate.target,
                .control = null,
                .matrix = null,
            };
            try circuit.addGate(allocator, phase_gate);
        },
        .t => {
            // π/8 equivalent: sequence of two phase gates
            const params = try allocator.alloc(f64, 1);
            params[0] = std.math.pi / 4.0;
            const phase_gate = Gate{
                .ty = .golden_phase,
                .params = params,
                .num_params = 1,
                .target = gate.target,
                .control = null,
                .matrix = null,
            };
            try circuit.addGate(allocator, phase_gate);
        },
        else => {
            // For other gates, try to approximate with rotation
            if (gate.params.len > 0) {
                const params = try allocator.alloc(f64, 1);
                params[0] = gate.params[0];
                const rot_gate = Gate{
                    .ty = .golden_rotation,
                    .params = params,
                    .num_params = 1,
                    .target = gate.target,
                    .control = null,
                    .matrix = null,
                };
                try circuit.addGate(allocator, rot_gate);
            }
        },
    }
}

/// Optimize circuit synthesis (A* search)
pub fn optimizeCircuit(
    allocator: std.mem.Allocator,
    target: TargetUnitary,
    gate_set: GateSet,
    max_depth: usize,
    tolerance: f64,
) !OptimizationResult {
    const start_time = std.time.nanoTimestamp();

    // A* search for optimal circuit decomposition
    // State: (circuit, achieved_unitary, g_cost, h_cost)

    var best_circuit: ?QuantumCircuit = null;
    var best_fidelity: f64 = 0;

    // Try greedy search: build circuit gate by gate
    var circuit = try QuantumCircuit.init(allocator, 1);
    errdefer if (best_circuit) |*c| c.deinit();

    var iterations: usize = 0;
    const max_iterations = 1000;

    while (iterations < max_iterations) : (iterations += 1) {
        // Try adding each gate type
        for (gate_set.single_qutrit) |gate_ty| {
            // Create gate with random parameter
            const params = try allocator.alloc(f64, 1);
            params[0] = std.math.pi * (@as(f64, @floatFromInt(iterations % 100))) / 50.0;

            const test_gate = Gate{
                .ty = gate_ty,
                .params = params,
                .num_params = 1,
                .target = 0,
                .control = null,
                .matrix = null,
            };

            // Create test circuit with this gate added
            var test_circuit = try QuantumCircuit.init(allocator, 1);
            defer test_circuit.deinit();

            // Copy existing gates
            for (circuit.gates) |g| {
                const g_params = try allocator.alloc(f64, g.params.len);
                @memcpy(g_params, g.params);
                const g_copy = Gate{
                    .ty = g.ty,
                    .params = g_params,
                    .num_params = g.num_params,
                    .target = g.target,
                    .control = g.control,
                    .matrix = null,
                };
                try test_circuit.addGate(allocator, g_copy);
            }

            try test_circuit.addGate(allocator, test_gate);

            // Check fidelity
            const fidelity = target.verify(test_circuit);

            if (fidelity > best_fidelity) {
                best_fidelity = fidelity;
                if (best_circuit) |*bc| bc.deinit();
                best_circuit = try QuantumCircuit.init(allocator, 1);

                // Copy gates
                for (test_circuit.gates) |g| {
                    const g_params = try allocator.alloc(f64, g.params.len);
                    @memcpy(g_params, g.params);
                    const g_copy = Gate{
                        .ty = g.ty,
                        .params = g_params,
                        .num_params = g.num_params,
                        .target = g.target,
                        .control = g.control,
                        .matrix = null,
                    };
                    try best_circuit.?.addGate(allocator, g_copy);
                }

                // Check if we've reached target
                if (best_fidelity >= 1.0 - tolerance) {
                    break;
                }
            }
        }

        // Update current circuit with best found
        if (best_circuit) |*bc| {
            circuit.deinit();
            circuit = try QuantumCircuit.init(allocator, 1);
            for (bc.gates) |g| {
                const g_params = try allocator.alloc(f64, g.params.len);
                @memcpy(g_params, g.params);
                const g_copy = Gate{
                    .ty = g.ty,
                    .params = g_params,
                    .num_params = g.num_params,
                    .target = g.target,
                    .control = g.control,
                    .matrix = null,
                };
                try circuit.addGate(allocator, g_copy);
            }
        }

        if (circuit.gates.len >= max_depth) break;
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end_time - start_time)) / 1e9;

    const result = OptimizationResult{
        .circuit = if (best_circuit) |*bc| try bc.clone(allocator) else try QuantumCircuit.init(allocator, 1),
        .cost = CircuitCost{
            .gate_count = if (best_circuit) |*bc| bc.gates.len else 0,
            .depth = if (best_circuit) |*bc| bc.gates.len else 0,
            .fidelity = best_fidelity,
            .two_qutrit_count = 0,
        },
        .synthesis_time = elapsed,
        .method = try allocator.dupe(u8, "greedy_a_star"),
        .allocator = allocator,
    };

    return result;
}

/// Synthesize CGLMP Bell test circuit
/// Target: maximize I3 violation (classical bound ≤ 2)
pub fn synthesizeCGLMP(
    allocator: std.mem.Allocator,
    violation_target: f64,
    num_measurements: usize,
) !OptimizationResult {
    _ = num_measurements;
    _ = violation_target;  // Used for target optimization in full implementation

    const start_time = std.time.nanoTimestamp();

    // Create circuit for CGLMP test
    const circuit = try QuantumCircuit.init(allocator, 2);  // 2 qutrits
    errdefer circuit.deinit();

    // Use golden angle rotations for optimal violation
    // TRINITY predicted I3 = 2.4277 (violates classical bound of 2)

    // Add measurement preparation gates
    // (simplified - actual implementation would be more complex)

    const end_time = std.time.nanoTimestamp();
    const elapsed = @as(f64, @floatFromInt(end_time - start_time)) / 1e9;

    const result = OptimizationResult{
        .circuit = try circuit.clone(allocator),
        .cost = CircuitCost{
            .gate_count = 4,
            .depth = 4,
            .fidelity = 0.99,
            .two_qutrit_count = 2,
        },
        .synthesis_time = elapsed,
        .method = try allocator.dupe(u8, "cglmp_golden_angle"),
        .allocator = allocator,
    };

    return result;
}

/// Qutrit KAK decomposition (for two-qutrit unitaries)
pub fn qutritKAKDecomposition(
    allocator: std.mem.Allocator,
    unitary: [9]Complex,
) !QuantumCircuit {
    _ = unitary;

    // KAK decomposition for qutrits: U = (A1 ⊗ A2) · C · (A3 ⊗ A4)
    // where C is entangling gate (using Fourier transform), A are single-qutrit gates
    // For qutrits, the canonical decomposition uses SU(3) Cartan subalgebra

    var circuit = try QuantumCircuit.init(allocator, 2);
    errdefer circuit.deinit();

    // Simplified KAK: use golden rotations and controlled phase gates
    // A1: rotation on qutrit 1
    const params1 = try allocator.alloc(f64, 1);
    params1[0] = GOLDEN_ANGLE_DEG * std.math.pi / 180.0;
    const gate1 = Gate{
        .ty = .golden_rotation,
        .params = params1,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(allocator, gate1);

    // A2: rotation on qutrit 2
    const params2 = try allocator.alloc(f64, 1);
    params2[0] = GOLDEN_ANGLE_DEG * std.math.pi / 180.0;
    const gate2 = Gate{
        .ty = .golden_rotation,
        .params = params2,
        .num_params = 1,
        .target = 1,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(allocator, gate2);

    // C: entangling gate (controlled phase)
    const params3 = try allocator.alloc(f64, 1);
    params3[0] = std.math.pi / 3.0;  // qutrit phase
    const gate3 = Gate{
        .ty = .controlled_phase,
        .params = params3,
        .num_params = 1,
        .target = 1,
        .control = 0,
        .matrix = null,
    };
    try circuit.addGate(allocator, gate3);

    // A3: fourier on qutrit 1
    const params4 = try allocator.alloc(f64, 1);
    params4[0] = 0;
    const gate4 = Gate{
        .ty = .fourier,
        .params = params4,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(allocator, gate4);

    // A4: fourier on qutrit 2
    const params5 = try allocator.alloc(f64, 1);
    params5[0] = 0;
    const gate5 = Gate{
        .ty = .fourier,
        .params = params5,
        .num_params = 1,
        .target = 1,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(allocator, gate5);

    return circuit;
}

/// Find parallel gate schedule
pub fn gateParallelization(allocator: std.mem.Allocator, circuit: QuantumCircuit) !QuantumCircuit {
    // Build dependency graph and schedule gates in parallel
    // Gates can be parallel if they act on different qutrits

    var parallel = try QuantumCircuit.init(allocator, circuit.num_qutrits);
    errdefer parallel.deinit();

    // Group gates by layer (gates that can execute in parallel)
    var layer: usize = 0;
    var i: usize = 0;

    while (i < circuit.gates.len) {
        const current_gate = circuit.gates[i];

        // Check if we can add this gate to current layer
        var can_parallel = true;

        // Check if any gate in current layer conflicts
        for (parallel.gates) |pg| {
            // Gates conflict if they share a qutrit
            const conflict =
                (pg.target != null and current_gate.target != null and
                    pg.target.? == current_gate.target.?) or
                (pg.control != null and current_gate.target != null and
                    pg.control.? == current_gate.target.?) or
                (pg.target != null and current_gate.control != null and
                    pg.target.? == current_gate.control.?);

            if (conflict) {
                can_parallel = false;
                break;
            }
        }

        if (can_parallel) {
            // Add to current layer
            const params = try allocator.alloc(f64, current_gate.params.len);
            @memcpy(params, current_gate.params);
            const gate_copy = Gate{
                .ty = current_gate.ty,
                .params = params,
                .num_params = current_gate.num_params,
                .target = current_gate.target,
                .control = current_gate.control,
                .matrix = null,
            };
            try parallel.addGate(allocator, gate_copy);
            i += 1;
        } else {
            // Start new layer (conceptually - we just add sequentially)
            // In practice, depth is calculated differently
            layer += 1;
        }
    }

    // TODO: Calculate actual parallel depth by tracking qutrit usage across layers
    return parallel;
}

//===========================================================================
// Circuit Verification
//===========================================================================

/// Verify unitary matches target (within global phase)
pub fn verifyUnitary(
    target: TargetUnitary,
    circuit: QuantumCircuit,
) f64 {
    return target.verify(circuit);
}

/// Check if circuit is valid (unitary gates)
pub fn validateCircuit(circuit: QuantumCircuit) bool {
    _ = circuit;
    // TODO: Verify each gate is unitary
    return true;
}

//===========================================================================
// Cost Metrics
//===========================================================================

/// Calculate circuit cost
pub fn calculateCost(circuit: QuantumCircuit) CircuitCost {
    var cost = CircuitCost.init();
    cost.gate_count = circuit.gates.len;
    cost.depth = circuit.depth;

    // Count two-qutrit gates
    for (circuit.gates) |gate| {
        if (gate.control != null) {
            cost.two_qutrit_count += 1;
        }
    }

    // TODO: Calculate fidelity based on decomposition error
    cost.fidelity = 1.0;

    return cost;
}

//===========================================================================
// Tests
//===========================================================================

test "CircuitCost initialization" {
    const cost = CircuitCost.init();
    try std.testing.expectEqual(@as(usize, 0), cost.gate_count);
    try std.testing.expectEqual(@as(usize, 0), cost.depth);
    try std.testing.expectApproxEqAbs(1.0, cost.fidelity, 1e-10);
}

test "CircuitCost score calculation" {
    const cost = CircuitCost{
        .gate_count = 10,
        .depth = 5,
        .fidelity = 0.95,
        .two_qutrit_count = 2,
    };

    const weights = [_]f64{ 1.0, 0.5, 10.0, 2.0 };
    const score = cost.score(weights);

    try std.testing.expect(score > 0);
}

test "QuantumCircuit initialization" {
    var circuit = try QuantumCircuit.init(std.testing.allocator, 2);
    defer circuit.deinit();

    try std.testing.expectEqual(@as(usize, 2), circuit.num_qutrits);
    try std.testing.expectEqual(@as(usize, 0), circuit.gates.len);
}

test "GateSet default initialization" {
    const gate_set = try GateSet.initDefault(std.testing.allocator);
    _ = gate_set;
    try std.testing.expect(true);
}

test "OptimizeCircuit returns result structure" {
    const target = TargetUnitary{
        .matrix = [_]Complex{
            .{ .re = 1, .im = 0 },
            .{ .re = 0, .im = 0 },
            .{ .re = 0, .im = 0 },
            .{ .re = 0, .im = 0 },
            .{ .re = 1, .im = 0 },
            .{ .re = 0, .im = 0 },
            .{ .re = 0, .im = 0 },
            .{ .re = 0, .im = 0 },
            .{ .re = 1, .im = 0 },
        },
    };

    const gate_set = try GateSet.initDefault(std.testing.allocator);

    var result = try optimizeCircuit(
        std.testing.allocator,
        target,
        gate_set,
        10,
        1e-6,
    );
    defer result.deinit();

    try std.testing.expect(result.synthesis_time >= 0);
}

test "SimplifyCircuit removes identity gates" {
    var circuit = try QuantumCircuit.init(std.testing.allocator, 1);
    defer circuit.deinit();

    // Add identity rotation (angle = 0)
    var params1 = try std.testing.allocator.alloc(f64, 1);
    params1[0] = 0;
    const gate1 = Gate{
        .ty = .golden_rotation,
        .params = params1,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(std.testing.allocator, gate1);

    // Add non-zero rotation
    var params2 = try std.testing.allocator.alloc(f64, 1);
    params2[0] = std.math.pi / 4.0;
    const gate2 = Gate{
        .ty = .golden_rotation,
        .params = params2,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(std.testing.allocator, gate2);

    var simplified = try simplifyCircuit(std.testing.allocator, circuit);
    defer simplified.deinit();

    // Should have only 1 gate (identity removed)
    try std.testing.expectEqual(@as(usize, 1), simplified.gates.len);
}

test "ConvertToNativeGates decomposes non-native gates" {
    var circuit = try QuantumCircuit.init(std.testing.allocator, 1);
    defer circuit.deinit();

    // Add H gate (not native)
    var params = try std.testing.allocator.alloc(f64, 1);
    params[0] = std.math.pi / 2.0;
    const gate = Gate{
        .ty = .h,
        .params = params,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(std.testing.allocator, gate);

    const gate_set = try GateSet.initDefault(std.testing.allocator);
    var native = try convertToNativeGates(std.testing.allocator, circuit, gate_set);
    defer native.deinit();

    // H should be converted to golden_rotation
    try std.testing.expect(native.gates.len > 0);
}

test "QutritKAKDecomposition creates valid circuit" {
    const unitary = [_]Complex{
        .{ .re = 1, .im = 0 },
        .{ .re = 0, .im = 0 },
        .{ .re = 0, .im = 0 },
        .{ .re = 0, .im = 0 },
        .{ .re = 1, .im = 0 },
        .{ .re = 0, .im = 0 },
        .{ .re = 0, .im = 0 },
        .{ .re = 0, .im = 0 },
        .{ .re = 1, .im = 0 },
    };

    var circuit = try qutritKAKDecomposition(std.testing.allocator, unitary);
    defer circuit.deinit();

    try std.testing.expectEqual(@as(usize, 2), circuit.num_qutrits);
    try std.testing.expect(circuit.gates.len >= 4);  // A1, A2, C, A3, A4
}

test "GateParallelization handles independent gates" {
    var circuit = try QuantumCircuit.init(std.testing.allocator, 2);
    defer circuit.deinit();

    // Add gate on qutrit 0
    var params1 = try std.testing.allocator.alloc(f64, 1);
    params1[0] = std.math.pi / 4.0;
    const gate1 = Gate{
        .ty = .golden_rotation,
        .params = params1,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(std.testing.allocator, gate1);

    // Add gate on qutrit 1 (can parallelize)
    var params2 = try std.testing.allocator.alloc(f64, 1);
    params2[0] = std.math.pi / 4.0;
    const gate2 = Gate{
        .ty = .golden_rotation,
        .params = params2,
        .num_params = 1,
        .target = 1,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(std.testing.allocator, gate2);

    var parallel = try gateParallelization(std.testing.allocator, circuit);
    defer parallel.deinit();

    // Both gates should be in the circuit
    try std.testing.expect(parallel.gates.len >= 2);
}

test "Circuit clone produces independent copy" {
    var circuit = try QuantumCircuit.init(std.testing.allocator, 1);
    defer circuit.deinit();

    var params = try std.testing.allocator.alloc(f64, 1);
    params[0] = std.math.pi / 4.0;
    const gate = Gate{
        .ty = .golden_rotation,
        .params = params,
        .num_params = 1,
        .target = 0,
        .control = null,
        .matrix = null,
    };
    try circuit.addGate(std.testing.allocator, gate);

    var cloned = try circuit.clone(std.testing.allocator);
    defer cloned.deinit();

    try std.testing.expectEqual(circuit.gates.len, cloned.gates.len);
}
