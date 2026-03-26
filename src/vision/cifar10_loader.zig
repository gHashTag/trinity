// CIFAR-10 Data Loader
// Binary file format parser for CIFAR-10 dataset
//
// Format: Each image = 1 byte label + 3072 bytes pixel data
// Layout: row-major, RRR...GGG...BBB...
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const IMAGE_SIZE: usize = 32;
pub const NUM_CHANNELS: usize = 3;
pub const NUM_CLASSES: usize = 10;
pub const TRAIN_SIZE: usize = 50000;
pub const TEST_SIZE: usize = 10000;
pub const IMAGE_BYTES: usize = IMAGE_SIZE * IMAGE_SIZE * NUM_CHANNELS; // 3072
pub const BYTES_PER_IMAGE: usize = 1 + IMAGE_BYTES; // label + pixels

// Class names for CIFAR-10
pub const CLASS_NAMES = [_][]const u8{
    "airplane", // 0
    "automobile", // 1
    "bird", // 2
    "cat", // 3
    "deer", // 4
    "dog", // 5
    "frog", // 6
    "horse", // 7
    "ship", // 8
    "truck", // 9
};

/// Return human-readable class name
pub fn className(label: u8) []const u8 {
    if (label < NUM_CLASSES) {
        return CLASS_NAMES[label];
    }
    return "unknown";
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Single CIFAR-10 image with label
pub const CIFAR10Image = struct {
    data: [IMAGE_BYTES]u8, // 32×32×3 pixels
    label: u8, // 0-9

    /// Get pixel at (row, col, channel)
    pub inline fn getPixel(self: *const CIFAR10Image, row: usize, col: usize, channel: usize) u8 {
        const index = channel * IMAGE_SIZE * IMAGE_SIZE + row * IMAGE_SIZE + col;
        return self.data[index];
    }

    /// Set pixel at (row, col, channel)
    pub inline fn setPixel(self: *CIFAR10Image, row: usize, col: usize, channel: usize, value: u8) void {
        const index = channel * IMAGE_SIZE * IMAGE_SIZE + row * IMAGE_SIZE + col;
        self.data[index] = value;
    }
};

/// Batch of CIFAR-10 images
pub const CIFAR10Batch = struct {
    images: std.ArrayList(CIFAR10Image),
    labels: std.ArrayList(u8),
    batch_size: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, batch_size: usize) Self {
        return .{
            .images = std.ArrayList(CIFAR10Image).empty,
            .labels = std.ArrayList(u8).empty,
            .batch_size = batch_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.images.deinit(self.allocator);
        self.labels.deinit(self.allocator);
    }

    pub fn addImage(self: *Self, image: CIFAR10Image) !void {
        try self.images.append(self.allocator, image);
        try self.labels.append(self.allocator, image.label);
    }

    pub fn isFull(self: *const Self) bool {
        return self.images.items.len >= self.batch_size;
    }

    pub fn size(self: *const Self) usize {
        return self.images.items.len;
    }
};

/// Complete CIFAR-10 dataset (train or test)
pub const CIFAR10Dataset = struct {
    images: std.ArrayList(CIFAR10Image),
    is_normalized: bool,
    shuffled: bool,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var images_list: std.ArrayList(CIFAR10Image) = .empty;
        try images_list.ensureTotalCapacityPrecise(allocator, 1000);

        return .{
            .images = images_list,
            .is_normalized = false,
            .shuffled = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.images.deinit(self.allocator);
    }

    pub fn len(self: *const Self) usize {
        return self.images.items.len;
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.images.items.len == 0;
    }

    /// Normalize all pixels to [-1, 1]
    pub fn normalize(self: *Self) !void {
        if (self.is_normalized) return; // Already normalized

        for (self.images.items) |*img| {
            for (0..IMAGE_BYTES) |i| {
                const norm = (@as(f32, @floatFromInt(img.data[i])) / 127.5 - 1.0);
                img.data[i] = @intFromFloat(@round(norm * 127.5));
            }
        }

        self.is_normalized = true;
    }

    /// Shuffle dataset in place
    pub fn shuffle(self: *Self, rng: anytype) void {
        var rng_copy = rng;
        const random = rng_copy.random();
        random.shuffle(CIFAR10Image, self.images.items);
        self.shuffled = true;
    }

    /// Get image at index
    pub inline fn get(self: *const Self, index: usize) CIFAR10Image {
        return self.images.items[index];
    }

    /// Create batch from dataset (with optional shuffling)
    pub fn createBatch(
        self: *Self,
        allocator: std.mem.Allocator,
        start_idx: usize,
        batch_size: usize,
    ) !CIFAR10Batch {
        var batch = CIFAR10Batch.init(allocator, batch_size);
        errdefer batch.deinit();

        const end_idx = @min(start_idx + batch_size, self.images.items.len);

        for (start_idx..end_idx) |i| {
            try batch.addImage(self.images.items[i]);
        }

        return batch;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Normalize pixel from [0, 255] to [-1, 1]
pub inline fn normalizePixel(pixel: u8) f32 {
    return @as(f32, @floatFromInt(pixel)) / 127.5 - 1.0;
}

/// Denormalize pixel from [-1, 1] to [0, 255]
pub inline fn denormalizePixel(normalized: f32) u8 {
    const clamped = @max(-1.0, @min(1.0, normalized));
    return @intFromFloat(@round(clamped * 127.5 + 127.5));
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE LOADING
// ═══════════════════════════════════════════════════════════════════════════════

/// Load CIFAR-10 dataset from binary file
pub fn loadDataset(
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !CIFAR10Dataset {
    var dataset = try CIFAR10Dataset.init(allocator);
    errdefer dataset.deinit();

    // Open file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    // Get file size
    const file_size = try file.getEnd();
    const expected_images = file_size / BYTES_PER_IMAGE;

    // Create buffered reader
    const reader = std.io.bufferedReader(file.reader()).reader();

    // Read all images
    var image_count: usize = 0;
    while (image_count < expected_images) {
        var image: CIFAR10Image = undefined;

        // Read label (1 byte)
        image.label = try reader.readByte();

        // Read pixel data (3072 bytes)
        const n = try reader.readAll(&image.data);
        if (n != IMAGE_BYTES) {
            return error.IncompleteImageData;
        }

        try dataset.images.append(image);
        image_count += 1;
    }

    return dataset;
}

/// Load full CIFAR-10 training set (5 batches merged)
pub fn loadTrainingSet(allocator: std.mem.Allocator, data_dir: []const u8) !CIFAR10Dataset {
    const combined = CIFAR10Dataset.init(allocator);
    errdefer combined.deinit();

    // Load all 5 training batches
    for (1..6) |i| {
        const batch_name = try std.fmt.allocPrint(allocator, "data_batch_{d}.bin", .{i});
        defer allocator.free(batch_name);

        const batch_path = try std.fs.path.join(allocator, &.{ data_dir, batch_name });
        defer allocator.free(batch_path);

        const batch = try loadDataset(allocator, batch_path);
        defer batch.deinit(allocator);

        // Merge images into combined dataset
        for (batch.images.items) |img| {
            try combined.images.append(combined.allocator, img);
        }
    }

    return combined;
}

/// Load CIFAR-10 test set (single batch)
pub fn loadTestSet(allocator: std.mem.Allocator, data_dir: []const u8) !CIFAR10Dataset {
    const test_path = try std.fs.path.join(allocator, &.{ data_dir, "test_batch.bin" });
    defer allocator.free(test_path);

    return loadDataset(allocator, test_path);
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "cifar10: pixel normalization" {
    // Test bounds
    try testing.expectApproxEqAbs(normalizePixel(0), -1.0, 0.001);
    try testing.expectApproxEqAbs(normalizePixel(127), 0.0, 0.01);
    try testing.expectApproxEqAbs(normalizePixel(255), 1.0, 0.001);
}

test "cifar10: pixel denormalization" {
    // Test roundtrip
    const values = [_]u8{ 0, 64, 128, 192, 255 };

    for (values) |v| {
        const norm = normalizePixel(v);
        const denorm = denormalizePixel(norm);
        try testing.expect(denorm == v or @abs(@as(i32, denorm) - @as(i32, v)) == 1);
    }
}

test "cifar10: image pixel access" {
    var image: CIFAR10Image = undefined;
    image.label = 5;

    // Set some pixels
    image.setPixel(0, 0, 0, 10); // R at top-left
    image.setPixel(0, 0, 1, 20); // G at top-left
    image.setPixel(0, 0, 2, 30); // B at top-left

    // Verify they were set correctly
    try testing.expect(image.getPixel(0, 0, 0) == 10);
    try testing.expect(image.getPixel(0, 0, 1) == 20);
    try testing.expect(image.getPixel(0, 0, 2) == 30);
}

test "cifar10: batch management" {
    var batch = CIFAR10Batch.init(testing.allocator, 4);
    defer batch.deinit();

    try testing.expect(!batch.isFull());
    try testing.expect(batch.size() == 0);

    var img: CIFAR10Image = undefined;
    img.label = 3;

    // Add images
    try batch.addImage(img);
    try testing.expect(batch.size() == 1);
    try testing.expect(!batch.isFull());

    try batch.addImage(img);
    try batch.addImage(img);
    try batch.addImage(img);
    try testing.expect(batch.size() == 4);
    try testing.expect(batch.isFull());
}

test "cifar10: class names" {
    try testing.expectEqualStrings(className(0), "airplane");
    try testing.expectEqualStrings(className(5), "dog");
    try testing.expectEqualStrings(className(9), "truck");
    try testing.expectEqualStrings(className(10), "unknown");
}

test "cifar10: dataset shuffle" {
    var dataset = try CIFAR10Dataset.init(testing.allocator);
    defer dataset.deinit();

    // Add 10 images with labels 0-9
    for (0..10) |i| {
        var img: CIFAR10Image = undefined;
        img.label = @intCast(i);
        try dataset.images.append(testing.allocator, img);
    }

    // Initial order
    var before: [10]u8 = undefined;
    for (0..10) |i| {
        before[i] = dataset.images.items[i].label;
    }

    // Shuffle
    const rng = std.Random.DefaultPrng.init(42);
    dataset.shuffle(rng);

    // Verify shuffled (not in same order)
    var different: bool = false;
    for (0..10) |i| {
        if (dataset.images.items[i].label != before[i]) {
            different = true;
            break;
        }
    }
    try testing.expect(different);
    try testing.expect(dataset.shuffled);
}

test "cifar10: dataset normalization" {
    var dataset = try CIFAR10Dataset.init(testing.allocator);
    defer dataset.deinit();

    // Add image with known pixel values
    var img: CIFAR10Image = undefined;
    img.label = 7;
    @memset(&img.data, 128); // All pixels = 128

    try dataset.images.append(dataset.allocator, img);

    try testing.expect(!dataset.is_normalized);

    // Normalize
    try dataset.normalize();

    try testing.expect(dataset.is_normalized);

    // After normalization, 128 should become 1
    const normalized_img = dataset.images.items[0];
    for (0..10) |i| {
        // Normalization formula: (pixel / 127.5 - 1.0) * 127.5
        // For pixel=128: (128/127.5 - 1.0) * 127.5 = 0.5 ≈ 1 (rounds up)
        try testing.expect(normalized_img.data[i] == 1);
    }
}
