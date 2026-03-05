//! E8 Integration Layer
//!
//! FFI bridge between Zig E8 implementation and Python modules.
//! Provides C ABI for interoperability.

const std = @import("std");
const e8 = @import("e8_root_system.zig");

//===========================================================================
// C ABI Exports
//===========================================================================

export const e8_result_t = extern enum(c_int) {
    SUCCESS = 0,
    ERROR_INVALID_PARAM = -1,
    ERROR_ALLOC_FAILED = -2,
    ERROR_NOT_FOUND = -3,
};

export const e8_root_t = extern struct {
    components: [8]f64,
};

export const e8_system_t = opaque {};

//===========================================================================
// E8 Root System Functions
//===========================================================================

/// Create E8 root system
export fn e8_system_create() ?*e8_system_t {
    const allocator = std.heap.c_allocator;
    const system = allocator.create(e8.E8RootSystem) catch return null;
    system.* = e8.E8RootSystem.generate(allocator) catch return null;
    return @ptrCast(system);
}

/// Destroy E8 root system
export fn e8_system_destroy(system: ?*e8_system_t) void {
    if (system) |s| {
        const allocator = std.heap.c_allocator;
        allocator.destroy(@ptrCast(*e8.E8RootSystem, s));
    }
}

/// Get root by index
export fn e8_system_get_root(
    system: ?*e8_system_t,
    index: c_uint,
    root: ?*e8_root_t,
) e8_result_t {
    if (system == null or root == null) return .ERROR_INVALID_PARAM;
    if (index >= e8.E8_NUM_ROOTS) return .ERROR_INVALID_PARAM;

    const e8_sys = @ptrCast(*e8.E8RootSystem, system.?);
    const e8_root = e8_sys.getRoot(index);

    root.?.components = e8_root.components;
    return .SUCCESS;
}

/// Get number of roots
export fn e8_system_get_num_roots() c_uint {
    return e8.E8_NUM_ROOTS;
}

/// Get dimension
export fn e8_system_get_dim() c_uint {
    return e8.E8_DIM;
}

/// Verify root norm
export fn e8_root_verify_norm(root: ?*const e8_root_t) e8_result_t {
    if (root == null) return .ERROR_INVALID_PARAM;

    const e8_root = e8.E8Root{
        .components = root.?.components,
    };

    if (e8_root.isValidE8Root()) {
        return .SUCCESS;
    } else {
        return .ERROR_INVALID_PARAM;
    }
}

/// Calculate root dot product
export fn e8_root_dot(
    root1: ?*const e8_root_t,
    root2: ?*const e8_root_t,
) f64 {
    if (root1 == null or root2 == null) return 0;

    const r1 = e8.E8Root{ .components = root1.?.components };
    const r2 = e8.E8Root{ .components = root2.?.components };

    return r1.dot(r2);
}

/// Get golden ratio constant
export fn e8_get_golden_ratio() f64 {
    return e8.GOLDEN_RATIO;
}

/// Get 2φ constant
export fn e8_get_two_phi() f64 {
    return e8.TWO_PHI;
}

//===========================================================================
// Tests
//===========================================================================

test "E8 C ABI - get golden ratio" {
    const phi = e8_get_golden_ratio();
    try std.testing.expectApproxEqAbs(f64, 1.618033988749895, phi, 1e-10);
}

test "E8 C ABI - get two phi" {
    const two_phi = e8_get_two_phi();
    try std.testing.expectApproxEqAbs(f64, 3.23606797749979, two_phi, 1e-10);
}

test "E8 C ABI - get dimensions" {
    try std.testing.expectEqual(@as(c_uint, 240), e8_system_get_num_roots());
    try std.testing.expectEqual(@as(c_uint, 248), e8_system_get_dim());
}

test "E8 C ABI - root verification" {
    var root = e8_root_t{
        .components = [_]f64{ 1, 1, 0, 0, 0, 0, 0, 0 },
    };

    const result = e8_root_verify_norm(&root);
    try std.testing.expectEqual(e8_result_t.SUCCESS, result);
}

test "E8 C ABI - root dot product" {
    const root1 = e8_root_t{
        .components = [_]f64{ 1, 1, 0, 0, 0, 0, 0, 0 },
    };
    const root2 = e8_root_t{
        .components = [_]f64{ 1, -1, 0, 0, 0, 0, 0, 0 },
    };

    const dot = e8_root_dot(&root1, &root2);
    try std.testing.expectApproxEqAbs(f64, 0.0, dot, 1e-10);
}
