// CIFAR-10 Training Tool
//
// Autonomous training on full CIFAR-10 dataset
//
// Usage: train_cifar10 [epochs] [learning_rate] [batch_size]
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

const vision = @import("vision");
const cifar10_loader = vision.cifar10;
const cifar10_model = vision.cifar10_model;
const cifar10_train = vision.cifar10_train;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse arguments
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    var epochs: usize = 5;
    var learning_rate: f64 = 0.001;
    var batch_size: usize = 32;
    var seed: u64 = 42;

    var arg_idx: usize = 1;
    while (arg_idx < args.len) {
        const arg = args[arg_idx];

        if (std.mem.eql(u8, arg, "--epochs") or std.mem.eql(u8, arg, "-e")) {
            if (arg_idx + 1 >= args.len) {
                std.debug.print("Error: --epochs requires value\n", .{});
                printUsage(args[0]);
                return error.InvalidArguments;
            }
            epochs = try std.fmt.parseInt(usize, args[arg_idx + 1], 10);
            arg_idx += 2;
        } else if (std.mem.eql(u8, arg, "--lr") or std.mem.eql(u8, arg, "-l")) {
            if (arg_idx + 1 >= args.len) {
                std.debug.print("Error: --lr requires value\n", .{});
                printUsage(args[0]);
                return error.InvalidArguments;
            }
            learning_rate = try std.fmt.parseFloat(f64, args[arg_idx + 1]);
            arg_idx += 2;
        } else if (std.mem.eql(u8, arg, "--batch") or std.mem.eql(u8, arg, "-b")) {
            if (arg_idx + 1 >= args.len) {
                std.debug.print("Error: --batch requires value\n", .{});
                printUsage(args[0]);
                return error.InvalidArguments;
            }
            batch_size = try std.fmt.parseInt(usize, args[arg_idx + 1], 10);
            arg_idx += 2;
        } else if (std.mem.eql(u8, arg, "--seed") or std.mem.eql(u8, arg, "-s")) {
            if (arg_idx + 1 >= args.len) {
                std.debug.print("Error: --seed requires value\n", .{});
                printUsage(args[0]);
                return error.InvalidArguments;
            }
            seed = try std.fmt.parseInt(u64, args[arg_idx + 1], 10);
            arg_idx += 2;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage(args[0]);
            return;
        } else {
            std.debug.print("Error: Unknown argument {s}\n", .{arg});
            printUsage(args[0]);
            return error.InvalidArguments;
        }
    }

    // Print configuration
    std.debug.print("═══════════════════════════════════════════════════════\n", .{});
    std.debug.print("CIFAR-10 Training Configuration\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════\n", .{});
    std.debug.print("Epochs:         {d}\n", .{epochs});
    std.debug.print("Learning Rate:   {d:.6}\n", .{learning_rate});
    std.debug.print("Batch Size:      {d}\n", .{batch_size});
    std.debug.print("Seed:            {d}\n", .{seed});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});

    // Initialize RNG
    const rng = std.Random.DefaultPrng.init(seed);

    // Load training data
    std.debug.print("\nLoading training data...\n", .{});

    const data_dir = "data/cifar-10/cifar-10-batches-bin";

    // Try to load full training set
    var train_dataset = cifar10_loader.loadTrainingSet(allocator, data_dir) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("Training data not found at {s}\n", .{data_dir});
            std.debug.print("Please download CIFAR-10 dataset first.\n", .{});
            return error.DatasetNotFound;
        }
        return err;
    };
    defer train_dataset.deinit();

    std.debug.print("Loaded {d} training images\n", .{train_dataset.len()});

    // Shuffle training data
    train_dataset.shuffle(rng);
    std.debug.print("Training data shuffled\n", .{});

    // Initialize model
    std.debug.print("\nInitializing model...\n", .{});
    var config = cifar10_model.CIFAR10Config.linear();
    config.learning_rate = learning_rate;

    var model = try cifar10_model.CIFAR10Model.init(allocator, config);
    defer model.deinit();

    const param_count = model.paramCount();
    std.debug.print("Model: {d} parameters\n", .{param_count});

    // Initialize trainer
    var trainer = try cifar10_train.CIFAR10Trainer.init(allocator, &model, config);
    defer trainer.deinit();

    // Training loop
    std.debug.print("\n═══════════════════════════════════════════════════════\n", .{});
    std.debug.print("Training\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════\n", .{});

    const start_time = std.time.nanoTimestamp();

    for (0..epochs) |epoch| {
        std.debug.print("\nEpoch {d}/{d}\n", .{ epoch + 1, epochs });

        const epoch_start = std.time.nanoTimestamp();

        // Train for one epoch
        const train_metrics = try trainer.trainEpoch(&train_dataset, batch_size, allocator);

        const epoch_time = std.time.nanoTimestamp();
        const duration_ns = epoch_time - epoch_start;
        const duration_sec = @as(f64, @floatFromInt(duration_ns)) / 1_000_000_000.0;

        // Print results
        std.debug.print("  Loss:     {d:.6}\n", .{train_metrics.loss});
        std.debug.print("  Accuracy: {d:.2}% ({d}/{d})\n", .{
            train_metrics.accuracy * 100.0,
            train_metrics.correct,
            train_metrics.total,
        });
        std.debug.print("  Time:     {d:.2}s\n", .{duration_sec});

        // Calculate ETA
        const elapsed = epoch_time - start_time;
        const elapsed_sec = @as(f64, @floatFromInt(elapsed)) / 1_000_000_000.0;
        const per_epoch = elapsed_sec / @as(f64, @floatFromInt(epoch + 1));
        const remaining = @as(f64, @floatFromInt(epochs - epoch - 1)) * per_epoch;
        std.debug.print("  ETA:      {d:.1}s remaining\n", .{remaining});

        // Reset metrics for next epoch
        trainer.metrics.reset();

        // Shuffle for next epoch
        train_dataset.shuffle(rng);
    }

    const total_time = std.time.nanoTimestamp();
    const total_duration_ns = total_time - start_time;
    const total_duration_sec = @as(f64, @floatFromInt(total_duration_ns)) / 1_000_000_000.0;

    std.debug.print("\n═══════════════════════════════════════════════════════\n", .{});
    std.debug.print("Training Complete\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════\n", .{});
    std.debug.print("Total Time: {d:.2}s ({d:.2} min)\n", .{ total_duration_sec, total_duration_sec / 60.0 });

    // Save model weights (simple binary format)
    const model_path = "cifar10_linear_model.bin";
    std.debug.print("\nSaving model to {s}...\n", .{model_path});

    const model_file = try std.fs.cwd().createFile(model_path, .{});
    defer model_file.close();

    // Write layer1 weights + bias
    try model_file.writeAll(std.mem.sliceAsBytes(model.layer1.weights));
    try model_file.writeAll(std.mem.sliceAsBytes(model.layer1.bias));

    // Write layer2 weights + bias
    try model_file.writeAll(std.mem.sliceAsBytes(model.layer2.weights));
    try model_file.writeAll(std.mem.sliceAsBytes(model.layer2.bias));

    // Write layer3 weights + bias
    try model_file.writeAll(std.mem.sliceAsBytes(model.layer3.weights));
    try model_file.writeAll(std.mem.sliceAsBytes(model.layer3.bias));

    const file_size = (model.layer1.weights.len + model.layer1.bias.len +
        model.layer2.weights.len + model.layer2.bias.len +
        model.layer3.weights.len + model.layer3.bias.len) * @sizeOf(f32);

    std.debug.print("Saved {d} bytes ({d:.2} MB)\n", .{ file_size, @as(f64, @floatFromInt(file_size)) / 1_048_576.0 });
}

fn printUsage(exe_name: []const u8) void {
    std.debug.print("Usage: {s} [OPTIONS]\n\n", .{exe_name});
    std.debug.print("Options:\n", .{});
    std.debug.print("  -e, --epochs <n>      Number of epochs (default: 5)\n", .{});
    std.debug.print("  -l, --lr <rate>       Learning rate (default: 0.001)\n", .{});
    std.debug.print("  -b, --batch <size>    Batch size (default: 32)\n", .{});
    std.debug.print("  -s, --seed <n>        Random seed (default: 42)\n", .{});
    std.debug.print("  -h, --help             Show this help\n", .{});
}
