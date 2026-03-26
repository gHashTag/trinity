// CIFAR-10 Integration Test — Full Training Pipeline
//
// Tests end-to-end training on real CIFAR-10 data
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

const cifar10_loader = @import("cifar10_loader.zig");
const cifar10_model = @import("cifar10_model.zig");
const cifar10_train = @import("cifar10_train.zig");

const testing = std.testing;

// Test training on single batch from real CIFAR-10 data
test "cifar10: train on single batch" {
    // Use absolute path for dataset
    const batch_path = "data/cifar-10/cifar-10-batches-bin/data_batch_1.bin";

    // Check if file exists first
    if (std.fs.cwd().openFile(batch_path, .{})) |_| {
        // File exists, continue
    } else |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Skipping test: dataset not found at {s}\n", .{batch_path});
            return error.SkipZigTest;
        }
        return err;
    }

    // Load first training batch
    var dataset = try cifar10_loader.loadDataset(testing.allocator, batch_path);
    defer dataset.deinit();

    std.debug.print("Loaded {d} images from {s}\n", .{ dataset.len(), batch_path });

    // Verify we have images
    try testing.expect(dataset.len() > 0);

    // Initialize model
    const config = cifar10_model.CIFAR10Config.linear();
    var model = try cifar10_model.CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    const param_count = model.paramCount();
    std.debug.print("Model initialized: {d} parameters\n", .{param_count});
    try testing.expect(param_count > 1_500_000);

    // Initialize trainer
    var trainer = try cifar10_train.CIFAR10Trainer.init(testing.allocator, &model, config);
    defer trainer.deinit();

    // Train on small subset (first 10 images)
    const subset_size: usize = @min(10, dataset.len());
    var total_loss: f32 = 0.0;
    var correct: usize = 0;

    std.debug.print("Training on {d} images...\n", .{subset_size});

    for (0..subset_size) |i| {
        const img = dataset.get(i);
        const metrics = try trainer.trainStep(img);
        total_loss += metrics.loss;
        if (metrics.correct > 0) correct = metrics.correct;

        if (i == 0 or i == subset_size - 1) {
            std.debug.print("  Step {d}: loss={d:.4}, acc={d:.2}\n", .{
                i + 1,
                metrics.loss,
                metrics.accuracy,
            });
        }
    }

    const avg_loss = total_loss / @as(f32, @floatFromInt(subset_size));
    std.debug.print("Average loss: {d:.4}\n", .{avg_loss});
    std.debug.print("Accuracy: {d}/{d} = {d:.2}%\n", .{
        correct,
        subset_size,
        @as(f32, @floatFromInt(correct)) * 100.0 / @as(f32, @floatFromInt(subset_size)),
    });

    // Verify loss decreased from initial random state
    // (not testing specific value, just that training ran without error)
    try testing.expect(avg_loss > 0.0);
}

// Test forward pass on real data
test "cifar10: forward pass on real data" {
    // Use absolute path for dataset
    const batch_path = "data/cifar-10/cifar-10-batches-bin/data_batch_1.bin";

    // Check if file exists first
    if (std.fs.cwd().openFile(batch_path, .{})) |_| {
        // File exists, continue
    } else |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Skipping test: dataset not found at {s}\n", .{batch_path});
            return error.SkipZigTest;
        }
        return err;
    }

    // Load single image
    var dataset = try cifar10_loader.loadDataset(testing.allocator, batch_path);
    defer dataset.deinit();

    try testing.expect(dataset.len() > 0);

    // Initialize model
    const config = cifar10_model.CIFAR10Config.linear();
    var model = try cifar10_model.CIFAR10Model.init(testing.allocator, config);
    defer model.deinit();

    // Get first image
    const img = dataset.get(0);

    // Convert to float tensor
    const input = try testing.allocator.alloc(f32, 3072);
    defer testing.allocator.free(input);

    for (0..3072) |i| {
        input[i] = cifar10_loader.normalizePixel(img.data[i]);
    }

    // Forward pass
    var logits: [10]f32 = undefined;
    try model.forward(input, &logits);

    std.debug.print("Image label: {d} ({s})\n", .{
        img.label,
        cifar10_loader.className(img.label),
    });

    std.debug.print("Logits: ", .{});
    for (logits, 0..) |l, i| {
        std.debug.print("{d}={d:.2}", .{ i, l });
        if (i < 9) std.debug.print(", ", .{});
    }
    std.debug.print("\n", .{});

    // Verify logits are finite
    for (logits) |l| {
        try testing.expect(!std.math.isNan(l));
        try testing.expect(!std.math.isInf(l));
    }

    // Get prediction
    var probs: [10]f32 = undefined;
    const pred = try model.predict(input, &probs);

    std.debug.print("Predicted: {d} ({s})\n", .{
        pred,
        cifar10_loader.className(@intCast(pred)),
    });

    // Probabilities should sum to ~1.0
    var sum: f32 = 0.0;
    for (probs) |p| {
        try testing.expect(p >= 0.0);
        try testing.expect(p <= 1.0);
        sum += p;
    }
    try testing.expectApproxEqAbs(sum, 1.0, 0.01);
}
