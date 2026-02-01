const std = @import("std");

// ============================================================================
// TRINITY TYPES
// ============================================================================

/// The Sacred Trit.
/// Value Space: {-1, 0, +1}
pub const Trit = enum(i8) {
    Zero = 0,
    Pos = 1,
    Neg = -1,
};

// ============================================================================
// THE HEART (Inference Engine)
// ============================================================================

pub const Engine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Engine {
        return Engine{ .allocator = allocator };
    }

    /// The Holy Operation: Matrix Multiplication WITHOUT Multiplication.
    ///
    /// Standard MatMul:   y = W * x
    /// Trinity MatMul:    y = Σ (x if w=+1), (-x if w=-1), (0 if w=0)
    ///
    /// Arguments:
    /// - inputs: Input vector [in_features]
    /// - weights: Flattened weight matrix [out_features * in_features]
    /// - out_features: Number of output neurons
    ///
    /// Returns:
    /// - Output vector [out_features]
    pub fn forward_pass(self: *Engine, inputs: []const f32, weights: []const Trit, out_features: usize) ![]const f32 {
        const in_features = inputs.len;

        // Safety check
        if (weights.len != out_features * in_features) {
            return error.DimensionMismatch;
        }

        const output = try self.allocator.alloc(f32, out_features);
        // We do typically zero-initialize, or we just sum.
        @memset(output, 0.0);

        var weight_idx: usize = 0;

        // Iterate over each output neuron
        for (0..out_features) |out_idx| {
            var accumulator: f32 = 0.0;

            // Iterate over inputs (Dot Product)
            for (inputs) |in_val| {
                const w = weights[weight_idx];
                weight_idx += 1; // Sequential access is cache-friendly

                // THE CORE LOGIC: NO MULTIPLICATION
                switch (w) {
                    .Pos => accumulator += in_val,
                    .Neg => accumulator -= in_val,
                    .Zero => {}, // No-op (Sparsity advantage)
                }
            }
            output[out_idx] = accumulator;
        }

        return output;
    }
};

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("💓 ACTIVATING TRINITY ENGINE (Heart)...\n", .{});

    var engine = Engine.init(allocator);

    // Simulation: Linear Layer 3 -> 2
    // Input vector (x)
    const inputs = [_]f32{ 1.0, 2.0, 0.5 }; // [3]

    // Weight Matrix (W) [2 x 3]
    // Neuron 0 weights: [+1, -1, 0]  -> should be (1.0 - 2.0 + 0) = -1.0
    // Neuron 1 weights: [ 0, +1, +1] -> should be (0 + 2.0 + 0.5) = 2.5
    const weights_raw = [_]Trit{
        .Pos,  .Neg, .Zero, // Row 0
        .Zero, .Pos, .Pos, // Row 1
    };

    std.debug.print("Input: {any}\n", .{inputs});
    std.debug.print("Weights (Trits): {any}\n", .{weights_raw});

    const output = try engine.forward_pass(&inputs, &weights_raw, 2);
    defer allocator.free(output);

    std.debug.print("Output: {any}\n", .{output});

    // Verification
    const expected = [_]f32{ -1.0, 2.5 };
    var accurate = true;
    for (output, 0..) |val, i| {
        if (std.math.approxEqAbs(f32, val, expected[i], 0.0001)) {
            // Good
        } else {
            accurate = false;
        }
    }

    if (accurate) {
        std.debug.print("✅ VERIFIED: Calculation correct. Zero Multiplications used.\n", .{});
    } else {
        std.debug.print("❌ FAILED: Calculation mismatch.\n", .{});
    }
}
