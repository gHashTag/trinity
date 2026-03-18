// @origin(manual) @regen(pending)
// HSLM Reference — Core Types
// Migrated from archive/implementations/zig/src/core.zig
// Sacred constants, DType, Shape, Tensor, config types

const std = @import("std");

// Sacred Constants
pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQUARED: f64 = PHI * PHI;
pub const GOLDEN_IDENTITY: f64 = PHI_SQUARED + 1.0 / PHI_SQUARED; // = 3
pub const PHOENIX: i64 = 999;

/// Supported data types for tensors
pub const DType = enum {
    f32,
    f16,
    bf16,
    i8,
    i4,

    pub fn sizeBytes(self: DType) usize {
        return switch (self) {
            .f32 => 4,
            .f16, .bf16 => 2,
            .i8 => 1,
            .i4 => 1,
        };
    }
};

/// Tensor shape (up to 4 dimensions)
pub const Shape = struct {
    dims: [4]usize = .{ 0, 0, 0, 0 },
    ndim: usize = 0,

    pub fn init(dims: []const usize) Shape {
        var shape = Shape{};
        shape.ndim = @min(dims.len, 4);
        for (0..shape.ndim) |i| {
            shape.dims[i] = dims[i];
        }
        return shape;
    }

    pub fn numel(self: Shape) usize {
        var n: usize = 1;
        for (0..self.ndim) |i| {
            n *= self.dims[i];
        }
        return n;
    }
};

/// Generic tensor with data and shape
pub fn Tensor(comptime T: type) type {
    return struct {
        data: []T,
        shape: Shape,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, shape: Shape) !Self {
            const data = try allocator.alloc(T, shape.numel());
            return Self{ .data = data, .shape = shape };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }

        pub fn fill(self: *Self, value: T) void {
            @memset(self.data, value);
        }

        pub fn get(self: Self, indices: []const usize) T {
            var idx: usize = 0;
            var stride: usize = 1;
            var i = self.shape.ndim;
            while (i > 0) {
                i -= 1;
                idx += indices[i] * stride;
                stride *= self.shape.dims[i];
            }
            return self.data[idx];
        }
    };
}

pub const TrainingConfig = struct {
    batch_size: usize = 32,
    learning_rate: f32 = 1e-4,
    weight_decay: f32 = 0.01,
    max_grad_norm: f32 = 1.0,
    mixed_precision: bool = true,
    gradient_checkpointing: bool = true,
};

pub const InferenceConfig = struct {
    max_batch_size: usize = 32,
    max_sequence_length: usize = 4096,
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,
    use_cache: bool = true,
};

test "sacred constants" {
    try std.testing.expect(@abs(GOLDEN_IDENTITY - 3.0) < 1e-10);
    try std.testing.expect(@abs(PHI_SQUARED - PHI - 1.0) < 1e-10);
}

test "tensor basics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const shape = Shape.init(&[_]usize{ 2, 3 });
    try std.testing.expectEqual(@as(usize, 6), shape.numel());

    var tensor = try Tensor(f32).init(allocator, shape);
    defer tensor.deinit(allocator);
    tensor.fill(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), tensor.data[0]);
}

test "dtype sizes" {
    try std.testing.expectEqual(@as(usize, 4), DType.f32.sizeBytes());
    try std.testing.expectEqual(@as(usize, 2), DType.f16.sizeBytes());
    try std.testing.expectEqual(@as(usize, 1), DType.i8.sizeBytes());
}
