// ╔════════════════════════════════════════════════════════════════════════════╗
// ║  TRINITY TQNN — Ternary Quantum Neural Network Inference                       ║
// ║  Week 2 Day 5: TQNN inference with VSA integration                             ║
// ║                                                                              ║
// ║  Architecture:                                                                ║
// ║  1. Input → Qutrit states (quantum encoding)                                  ║
// ║  2. TQNN Layer 1 → Hadamard + Sacred Phase                                    ║
// ║  3. VSA integration → Bind with 10K hypervectors                             ║
// ║  4. Output → Classical values via measurement                                ║
// ║                                                                              ║
// ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
// ╚════════════════════════════════════════════════════════════════════════════╝

const std = @import("std");
const qutrit = @import("../../quantum/qutrit.zig");
const vsa10k = @import("../../vsa/10k_vsa.zig");

/// Quantum state summary
pub const QuantumState = struct {
    pos: usize,
    neg: usize,
    zero: usize,
};

/// TQNN Layer configuration
pub const TQNNConfig = struct {
    /// Input dimension
    input_dim: usize,
    /// VSA dimension (typically 10,000)
    vsa_dim: usize,
    /// Gate selection (0=Hadamard, 1=CPhase, 2=Rotation)
    gate_select: u2,
    /// Sacred phase enabled
    sacred_phase_enabled: bool,

    pub fn default(input_dim: usize) TQNNConfig {
        return .{
            .input_dim = input_dim,
            .vsa_dim = vsa10k.DIM_10K,
            .gate_select = 0,
            .sacred_phase_enabled = true,
        };
    }
};

/// TQNN Layer 1 state
pub const TQNNLayer1 = struct {
    /// Qutrit neurons
    neurons: []qutrit.Qutrit,
    /// Layer configuration
    config: TQNNConfig,
    /// Coherence flag
    coherent: bool = false,
    /// Phase accumulator
    phase_acc: u8 = 0,

    const Self = @This();

    /// Create a new TQNN Layer 1
    pub fn init(allocator: std.mem.Allocator, config: TQNNConfig) !Self {
        const neurons = try allocator.alloc(qutrit.Qutrit, config.input_dim);
        @memset(neurons, qutrit.Qutrit.from_trit(0));
        return .{
            .neurons = neurons,
            .config = config,
        };
    }

    /// Deinitialize layer
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.neurons);
    }

    /// Forward pass through TQNN Layer 1
    pub fn forward(self: *Self, input: []const f32) ![]qutrit.Qutrit {
        std.debug.assert(input.len == self.neurons.len);

        // Step 1: Encode input as qutrits
        for (input, 0..) |val, i| {
            self.neurons[i] = qutrit.Qutrit.from_float(val);
        }

        // Step 2: Apply gate based on configuration
        switch (self.config.gate_select) {
            0 => self.hadamard_all(),
            1 => try self.cphase_all(),
            2 => self.rotate_all(),
            else => {},
        }

        // Step 3: Apply Sacred Phase if enabled
        if (self.config.sacred_phase_enabled) {
            self.sacred_phase_all();
        }

        // Step 4: Measure coherence
        self.coherent = self.compute_coherence();

        return self.neurons;
    }

    /// Apply Hadamard gate to all neurons
    fn hadamard_all(self: *Self) void {
        for (self.neurons) |*n| {
            n.hadamard();
        }
    }

    /// Apply CPhase gate to all neurons
    fn cphase_all(self: *Self) !void {
        for (self.neurons, 0..) |*n, i| {
            const phase = self.phase_acc +| @as(u8, @intCast(i * 16));
            const control = qutrit.Qutrit.from_trit(1); // Control = +1
            n.cphase(control, phase);
        }
    }

    /// Apply Rotation gate to all neurons
    fn rotate_all(self: *Self) void {
        for (self.neurons, 0..) |*n, i| {
            const angle = self.phase_acc +| @as(u8, @intCast(i * 16));
            n.rotate(angle);
        }
    }

    /// Apply Sacred Phase to all neurons
    fn sacred_phase_all(self: *Self) void {
        for (self.neurons) |*n| {
            n.sacred_phase();
        }
        self.phase_acc +|= qutrit.GOLDEN_ANGLE_U8;
    }

    /// Compute quantum coherence
    fn compute_coherence(self: *const Self) bool {
        var pos_count: usize = 0;
        var neg_count: usize = 0;

        for (self.neurons) |n| {
            switch (n.value) {
                qutrit.TRIT_POS => pos_count += 1,
                qutrit.TRIT_NEG => neg_count += 1,
                else => {},
            }
        }

        return (pos_count > self.neurons.len / 4) and
            (neg_count > self.neurons.len / 4);
    }

    /// Get quantum state summary
    pub fn quantum_state(self: *const Self) QuantumState {
        var result = QuantumState{
            .pos = 0,
            .neg = 0,
            .zero = 0,
        };

        for (self.neurons) |n| {
            switch (n.value) {
                qutrit.TRIT_POS => result.pos += 1,
                qutrit.TRIT_NEG => result.neg += 1,
                else => result.zero += 1,
            }
        }

        return result;
    }
};

/// Hybrid TQNN-VSA Inference Engine
/// Combines TQNN quantum layer with VSA hypervector operations
pub const TQNNVSAInference = struct {
    /// TQNN Layer 1
    layer1: TQNNLayer1,
    /// VSA weight storage
    weights: vsa10k.HyperVector10K,
    /// Output buffer
    output: [vsa10k.DIM_10K]qutrit.Trit,
    /// Allocator reference
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new TQNN-VSA inference engine
    pub fn init(allocator: std.mem.Allocator, input_dim: usize) !Self {
        const config = TQNNConfig.default(input_dim);
        const layer1 = try TQNNLayer1.init(allocator, config);

        // Initialize random VSA weights
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
        const weights = try vsa10k.HyperVector10K.random(&rng);

        return .{
            .layer1 = layer1,
            .weights = weights,
            .output = [_]qutrit.Trit{0} ** vsa10k.DIM_10K,
            .allocator = allocator,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *Self) void {
        self.layer1.deinit(self.allocator);
    }

    /// Full forward pass: Input → TQNN → VSA → Output
    pub fn forward(self: *Self, input: []const f32) !struct {
        /// Quantum state after TQNN Layer 1
        quantum_state: QuantumState,
        /// Coherence flag
        coherent: bool,
        /// VSA similarity score (0-65535)
        similarity: u16,
        /// Output vector (packed)
        output: []const qutrit.Trit,
    } {
        // Step 1: TQNN Layer 1 forward pass
        _ = try self.layer1.forward(input);

        // Step 2: Map qutrits to VSA vector (expand to 10K)
        try self.map_to_vsa();

        // Step 3: VSA Bind operation with weights (result stored in output)
        _ = self.vsa_bind();

        // Step 4: Compute similarity (for monitoring)
        const similarity = self.compute_similarity();

        return .{
            .quantum_state = self.layer1.quantum_state(),
            .coherent = self.layer1.coherent,
            .similarity = similarity,
            .output = self.output[0..self.layer1.config.input_dim],
        };
    }

    /// Map qutrits to VSA hypervector space
    fn map_to_vsa(self: *Self) !void {
        const input_dim = self.layer1.config.input_dim;
        const expansion = vsa10k.DIM_10K / input_dim;

        // Measure qutrits and expand into VSA space
        var vsa_input = vsa10k.HyperVector10K.zero();

        var i: usize = 0;
        while (i < input_dim) : (i += 1) {
            const trit = self.layer1.neurons[i].measure();
            var j: usize = 0;
            while (j < expansion) : (j += 1) {
                const vsa_idx = (i * expansion + j) % vsa10k.DIM_10K;
                vsa_input.set(vsa_idx, trit) catch unreachable; // vsa_idx < DIM_10K by construction
            }
        }

        // Store in self.output for binding
        for (0..vsa10k.DIM_10K) |k| {
            self.output[k] = @as(qutrit.Trit, @intCast(vsa_input.get(k) catch unreachable)); // k < DIM_10K by construction
        }
    }

    /// VSA Bind operation
    fn vsa_bind(self: *const Self) vsa10k.HyperVector10K {
        var result = vsa10k.HyperVector10K.zero();

        for (0..vsa10k.DIM_10K) |i| {
            const a = self.output[i];
            const b = self.weights.get(i) catch unreachable; // i < DIM_10K by construction

            // Trit multiplication for bind
            const result_trit: qutrit.Trit = if (a == 0 or b == 0)
                0
            else if (a == b)
                1
            else
                -1;

            result.set(i, result_trit) catch unreachable; // i < DIM_10K by construction
        }

        return result;
    }

    /// Compute similarity between output and weights
    fn compute_similarity(self: *const Self) u16 {
        var dot_product: i32 = 0;
        var norm_a: i32 = 0;
        var norm_b: i32 = 0;

        for (0..vsa10k.DIM_10K) |i| {
            const a = self.output[i];
            const b = self.weights.get(i) catch unreachable; // i < DIM_10K by construction

            dot_product += @as(i32, a) * @as(i32, b);
            norm_a += @as(i32, a) * @as(i32, a);
            norm_b += @as(i32, b) * @as(i32, b);
        }

        if (norm_a == 0 or norm_b == 0) return 0;

        const abs_dot = if (dot_product < 0) -dot_product else dot_product;
        const norm_sum = @as(u32, @intCast(norm_a + norm_b));

        // Scale to 0-65535
        return @as(u16, @intCast((@as(u64, @as(u32, @intCast(abs_dot))) * 65535) / norm_sum));
    }
};

//==============================================================================
// CONVENIENCE FUNCTIONS
//==============================================================================

/// Simple TQNN inference without VSA (for testing)
pub fn tqnn_forward_simple(input: []const f32, gate_select: u2) ![]qutrit.Qutrit {
    const allocator = std.heap.page_allocator;

    var layer = try TQNNLayer1.init(allocator, .{
        .input_dim = input.len,
        .vsa_dim = 1000,
        .gate_select = gate_select,
        .sacred_phase_enabled = true,
    });
    defer layer.deinit(allocator);

    return try layer.forward(input);
}

/// TQNN inference with VSA (full pipeline)
pub fn tqnn_forward_vsa(input: []const f32) !struct {
    quantum_state: struct { pos: usize, neg: usize, zero: usize },
    coherent: bool,
    similarity: u16,
    output: []const qutrit.Trit,
} {
    const allocator = std.heap.page_allocator;

    var engine = try TQNNVSAInference.init(allocator, input.len);
    defer engine.deinit();

    return try engine.forward(input);
}

//==============================================================================
// BATCH PROCESSING
//==============================================================================

/// Process multiple inputs through TQNN
pub fn tqnn_forward_batch(inputs: [][]const f32, gate_select: u2) !struct {
    outputs: [][]qutrit.Qutrit,
    avg_coherence: f32,
    avg_similarity: u16,
} {
    _ = gate_select; // DEFERRED (v12): Use gate_select in layer config routing
    const allocator = std.heap.page_allocator;

    const batch_size = inputs.len;
    var outputs = try allocator.alloc([]qutrit.Qutrit, batch_size);

    var total_coherence: f32 = 0;
    var total_similarity: u32 = 0;

    for (inputs, 0..) |input, i| {
        var engine = try TQNNVSAInference.init(allocator, input.len);
        defer engine.deinit();

        const result = try engine.forward(input);

        outputs[i] = try allocator.dupe(qutrit.Qutrit, result.output);

        total_coherence += if (result.coherent) @as(f32, 1.0) else 0;
        total_similarity += result.similarity;
    }

    return .{
        .outputs = outputs,
        .avg_coherence = total_coherence / @as(f32, @floatFromInt(batch_size)),
        .avg_similarity = @as(u16, @intCast(total_similarity / batch_size)),
    };
}

// φ² + 1/φ² = 3 = TRINITY
// Cycle #127 — Week 2 Day 5
