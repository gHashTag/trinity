// Test wrapper for generated MLP code
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

// Import generated modules
const mlp = @import("../generated/mlp.zig");
const dense = @import("../generated/dense.zig");
const relu = @import("../generated/relu.zig");
const sgd = @import("../generated/sgd.zig");

test "generated_phi_constants" {
    // Test that all generated modules have consistent Sacred constants
    try expectApproxEqAbs(mlp.PHI * mlp.PHI_INV, 1.0, 1e-10);
    try expectApproxEqAbs(dense.PHI * dense.PHI_INV, 1.0, 1e-10);
    try expectApproxEqAbs(relu.PHI * relu.PHI_INV, 1.0, 1e-10);
    try expectApproxEqAbs(sgd.PHI * sgd.PHI_INV, 1.0, 1e-10);

    // Test Trinity identity: φ² + 1/φ² = 3
    try expectApproxEqAbs(mlp.PHI_SQ + 1.0 / mlp.PHI_SQ, 3.0, 1e-10);
}

test "generated_module_export" {
    // Test that generated modules export expected functions
    _ = mlp.get_global_buffer_ptr;
    _ = mlp.get_f64_buffer_ptr;
    _ = dense.get_global_buffer_ptr;
    _ = dense.get_f64_buffer_ptr;
    _ = relu.get_global_buffer_ptr;
    _ = relu.get_f64_buffer_ptr;
    _ = sgd.get_global_buffer_ptr;
    _ = sgd.get_f64_buffer_ptr;
}
