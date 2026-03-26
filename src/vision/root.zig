// Vision Module — Cross-modal validation for Trinity S³AI
// Root module: re-exports all public API
//
// Purpose: Demonstrate ternary neural networks on vision tasks
// Target: CIFAR-10 classification with >85% accuracy
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

pub const cifar10 = @import("cifar10_loader.zig");
pub const cifar10_model = @import("cifar10_model.zig");
pub const cifar10_train = @import("cifar10_train.zig");

// Re-export primary types
pub const CIFAR10Image = cifar10.CIFAR10Image;
pub const CIFAR10Batch = cifar10.CIFAR10Batch;
pub const CIFAR10Dataset = cifar10.CIFAR10Dataset;
pub const CIFAR10Config = cifar10_model.CIFAR10Config;
pub const CIFAR10Model = cifar10_model.CIFAR10Model;
pub const CIFAR10Trainer = cifar10_train.CIFAR10Trainer;
pub const CIFAR10Metrics = cifar10_train.CIFAR10Metrics;

// Re-export constants
pub const IMAGE_SIZE = cifar10.IMAGE_SIZE;
pub const NUM_CHANNELS = cifar10.NUM_CHANNELS;
pub const NUM_CLASSES = cifar10.NUM_CLASSES;
pub const TRAIN_SIZE = cifar10.TRAIN_SIZE;
pub const TEST_SIZE = cifar10.TEST_SIZE;
pub const IMAGE_BYTES = cifar10.IMAGE_BYTES;
pub const BYTES_PER_IMAGE = cifar10.BYTES_PER_IMAGE;

// Re-export utility functions
pub const loadDataset = cifar10.loadDataset;
pub const normalizePixel = cifar10.normalizePixel;
pub const denormalizePixel = cifar10.denormalizePixel;
pub const className = cifar10.className;

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

comptime {
    _ = cifar10;
    _ = cifar10_model;
    _ = cifar10_train;
}

test "vision: cifar10 image structure" {
    // Verify image dimensions
    try std.testing.expect(IMAGE_SIZE == 32);
    try std.testing.expect(NUM_CHANNELS == 3);
    try std.testing.expect(IMAGE_BYTES == 3072); // 32×32×3

    // Verify class count
    try std.testing.expect(NUM_CLASSES == 10);

    // Verify dataset sizes
    try std.testing.expect(TRAIN_SIZE == 50000);
    try std.testing.expect(TEST_SIZE == 10000);
}

test "vision: pixel normalization" {
    // Test: 0 → -1.0, 128 → 0.0, 255 → 1.0
    const normalized_zero = normalizePixel(0);
    try std.testing.expectApproxEqAbs(normalized_zero, -1.0, 0.001);

    const normalized_mid = normalizePixel(128);
    try std.testing.expectApproxEqAbs(normalized_mid, 0.0, 0.01);

    const normalized_max = normalizePixel(255);
    try std.testing.expectApproxEqAbs(normalized_max, 1.0, 0.001);
}

test "vision: pixel denormalization" {
    // Test roundtrip: 0 → normalized → denormalized ≈ 0
    const original: u8 = 100;
    const norm = normalizePixel(original);
    const denorm = denormalizePixel(norm);

    const diff = @abs(@as(i32, denorm) - @as(i32, original));
    try std.testing.expect(diff <= 1); // Should round back to same or adjacent value
}
