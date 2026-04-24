// ═══════════════════════════════════════════════════════════════════════════════
// CIFAR-10 Binary Dataset Loader
// ═══════════════════════════════════════════════════════════════════════════════
//
// CIFAR-10 binary format:
//   - 5 training batches: data_batch_1.bin ... data_batch_5.bin
//   - 1 test batch: test_batch.bin
//
// Each batch file contains 10,000 records:
//   [1 byte label][3072 bytes pixels (1024 R + 1024 G + 1024 B)]
//
// Pixel layout: channel-first (all R, then all G, then all B)
// Total per record: 3073 bytes
// Total per batch: 30,730,000 bytes (10,000 × 3073)
//
// Usage:
//   var loader = CIFAR10Loader.init(allocator);
//   defer loader.deinit();
//   const train = try loader.loadTrain(allocator, "/path/to/cifar-10-binary");
//   const test = try loader.loadTest(allocator, "/path/to/cifar-10-binary");
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

// ═══════════════════════════════════════════════════════════════════════════════
// CIFAR-10 Sample
// ═══════════════════════════════════════════════════════════════════════════════

pub const Sample = struct {
    label: u8, // 0-9 class label
    pixels: [3072]f32, // 32×32×3 = 3072 pixels, normalized to [0, 1]

    /// Flatten pixels to 1D vector (already flat, just returns reference)
    pub fn flatten(self: *const Sample) []const f32 {
        return &self.pixels;
    }

    /// Get image dimensions
    pub fn size() struct { width: u32, height: u32, channels: u32 } {
        return .{ .width = 32, .height = 32, .channels = 3 };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CIFAR-10 Dataset
// ═══════════════════════════════════════════════════════════════════════════════

pub const Dataset = struct {
    samples: ArrayListUnmanaged(Sample),

    /// Get total number of samples
    pub fn len(self: *const Dataset) usize {
        return self.samples.items.len;
    }

    /// Get sample by index
    pub fn get(self: *const Dataset, index: usize) *const Sample {
        std.debug.assert(index < self.samples.items.len);
        return &self.samples.items[index];
    }

    /// Get label distribution
    pub fn labelDistribution(self: *const Dataset, allocator: Allocator) ![]const usize {
        const dist = try allocator.alloc(usize, 10);
        @memset(dist, 0);
        for (self.samples.items) |sample| {
            dist[sample.label] += 1;
        }
        return dist;
    }

    /// Deinitialize dataset
    pub fn deinit(self: *Dataset, allocator: Allocator) void {
        self.samples.deinit(allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CIFAR-10 Loader
// ═══════════════════════════════════════════════════════════════════════════════

pub const CIFAR10Loader = struct {
    const RECORD_SIZE: usize = 3073; // 1 label byte + 3072 pixel bytes
    const BATCH_SIZE: usize = 10_000;
    const BATCH_BYTES: usize = BATCH_SIZE * RECORD_SIZE; // 30,730,000 bytes

    /// Initialize loader
    pub fn init() CIFAR10Loader {
        return .{};
    }

    /// Load a single batch file
    pub fn loadBatch(
        _: CIFAR10Loader,
        allocator: Allocator,
        batch_path: []const u8,
    ) !Dataset {
        const file = try std.fs.cwd().openFile(batch_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size != BATCH_BYTES) {
            std.debug.print("Warning: Expected {d} bytes, got {d}\n", .{ BATCH_BYTES, file_size });
        }

        const expected_records = file_size / RECORD_SIZE;
        var dataset = Dataset{
            .samples = ArrayListUnmanaged(Sample){},
        };
        errdefer dataset.deinit(allocator);

        try dataset.samples.ensureTotalCapacity(allocator, expected_records);

        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        _ = try file.readAll(buffer);

        var offset: usize = 0;
        while (offset + RECORD_SIZE <= file_size) {
            const label = buffer[offset];
            offset += 1;

            var sample = Sample{
                .label = label,
                .pixels = undefined,
            };

            // Pixels are stored channel-first: RRR...GGG...BBB...
            // Each channel has 1024 bytes (32×32)
            // Normalize to [0, 1] by dividing by 255.0
            var pixel_idx: usize = 0;
            while (pixel_idx < 3072) : (pixel_idx += 1) {
                const raw = buffer[offset + pixel_idx];
                sample.pixels[pixel_idx] = @as(f32, @floatFromInt(raw)) / 255.0;
            }

            offset += 3072;
            try dataset.samples.append(allocator, sample);
        }

        return dataset;
    }

    /// Load training dataset (all 5 batches merged)
    pub fn loadTrain(
        self: CIFAR10Loader,
        allocator: Allocator,
        data_dir: []const u8,
    ) !Dataset {
        const batch_files = [_][]const u8{
            "data_batch_1.bin",
            "data_batch_2.bin",
            "data_batch_3.bin",
            "data_batch_4.bin",
            "data_batch_5.bin",
        };

        var merged = Dataset{
            .samples = ArrayListUnmanaged(Sample){},
        };
        errdefer merged.deinit(allocator);

        // Pre-allocate for 50,000 samples
        try merged.samples.ensureTotalCapacity(allocator, 50_000);

        for (batch_files) |batch_name| {
            var batch_path_buf: [1024]u8 = undefined;
            const batch_path = try std.fmt.bufPrint(
                &batch_path_buf,
                "{s}" ++ std.fs.path.sep_str ++ "{s}",
                .{ data_dir, batch_name },
            );

            var batch = try self.loadBatch(allocator, batch_path);
            defer batch.deinit(allocator);

            // Merge samples
            for (batch.samples.items) |sample| {
                try merged.samples.append(allocator, sample);
            }

            std.debug.print("Loaded {s}: {d} samples (total: {d})\n", .{
                batch_name,
                batch.samples.items.len,
                merged.samples.items.len,
            });
        }

        return merged;
    }

    /// Load test dataset
    pub fn loadTest(
        self: CIFAR10Loader,
        allocator: Allocator,
        data_dir: []const u8,
    ) !Dataset {
        var test_path_buf: [1024]u8 = undefined;
        const test_path = try std.fmt.bufPrint(
            &test_path_buf,
            "{s}" ++ std.fs.path.sep_str ++ "test_batch.bin",
            .{data_dir},
        );

        return self.loadBatch(allocator, test_path);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "CIFAR-10: Sample structure size" {
    try testing.expectEqual(@as(usize, 3073), @sizeOf(Sample));
}

test "CIFAR-10: Image dimensions" {
    const dims = Sample.size();
    try testing.expectEqual(@as(u32, 32), dims.width);
    try testing.expectEqual(@as(u32, 32), dims.height);
    try testing.expectEqual(@as(u32, 3), dims.channels);
}

test "CIFAR-10: Record size constant" {
    try testing.expectEqual(@as(usize, 3073), CIFAR10Loader.RECORD_SIZE);
    try testing.expectEqual(@as(usize, 10_000), CIFAR10Loader.BATCH_SIZE);
    try testing.expectEqual(@as(usize, 30_730_000), CIFAR10Loader.BATCH_BYTES);
}

test "CIFAR-10: Normalization range" {
    const zero_raw: u8 = 0;
    const zero_norm = @as(f32, @floatFromInt(zero_raw)) / 255.0;
    try testing.expectEqual(@as(f32, 0.0), zero_norm);

    const max_raw: u8 = 255;
    const max_norm = @as(f32, @floatFromInt(max_raw)) / 255.0;
    try testing.expectEqual(@as(f32, 1.0), max_norm);

    const mid_raw: u8 = 128;
    const mid_norm = @as(f32, @floatFromInt(mid_raw)) / 255.0;
    try testing.expectApproxEqAbs(@as(f32, 0.502), mid_norm, 0.001);
}
