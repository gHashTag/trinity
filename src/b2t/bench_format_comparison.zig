const std = @import("std");

pub const CIFAR10Image = struct {
    label: u8,
    pixels: [3072]u8,
};

pub const CIFAR10Dataset = struct {
    images: []CIFAR10Image,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, batch_paths: []const []const u8) !CIFAR10Dataset {
        var total_images: usize = 0;
        for (batch_paths) |path| {
            const file = std.fs.cwd().openFile(path, .{}) catch continue;
            defer file.close();
            const size = (try file.stat()).size;
            total_images += (size - 1) / 3073;
        }

        const images = try allocator.alloc(CIFAR10Image, total_images);
        var idx: usize = 0;

        for (batch_paths) |path| {
            const file = std.fs.cwd().openFile(path, .{}) catch continue;
            defer file.close();

            var buf: [3073]u8 = undefined;
            while (true) {
                const n = file.read(&buf) catch break;
                if (n < 3073) break;
                images[idx].label = buf[0];
                @memcpy(&images[idx].pixels, buf[1..3073]);
                idx += 1;
            }
        }

        return .{
            .images = images[0..idx],
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CIFAR10Dataset) void {
        self.allocator.free(self.images);
    }

    pub fn toFloats(self: *const CIFAR10Dataset, allocator: std.mem.Allocator) ![][3072]f32 {
        const result = try allocator.alloc([3072]f32, self.images.len);
        for (self.images, result) |img, *out| {
            for (img.pixels, out) |p, *o| {
                o.* = @as(f32, @floatFromInt(p)) / 255.0;
            }
        }
        return result;
    }
};

pub const MNISTImage = struct {
    label: u8,
    pixels: [784]u8,
};

pub const MNISTDataset = struct {
    images: []MNISTImage,
    allocator: std.mem.Allocator,

    pub fn loadImages(allocator: std.mem.Allocator, images_path: []const u8, labels_path: []const u8) !MNISTDataset {
        const img_file = try std.fs.cwd().openFile(images_path, .{});
        defer img_file.close();
        const lbl_file = try std.fs.cwd().openFile(labels_path, .{});
        defer lbl_file.close();

        var header: [16]u8 = undefined;
        _ = try img_file.read(&header);
        var lbl_header: [8]u8 = undefined;
        _ = try lbl_file.read(&lbl_header);

        const num_images = std.mem.readIntBig(u32, header[4..8]);
        const rows = std.mem.readIntBig(u32, header[8..12]);
        const cols = std.mem.readIntBig(u32, header[12..16]);
        const pixel_count = rows * cols;

        const images = try allocator.alloc(MNISTImage, num_images);
        for (images) |*img| {
            var px: [784]u8 = undefined;
            _ = try img_file.read(px[0..pixel_count]);
            var lbl: [1]u8 = undefined;
            _ = try lbl_file.read(&lbl);
            img.label = lbl[0];
            @memcpy(&img.pixels, &px);
        }

        return .{
            .images = images,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MNISTDataset) void {
        self.allocator.free(self.images);
    }

    pub fn toFloats(self: *const MNISTDataset, allocator: std.mem.Allocator) ![][784]f32 {
        const result = try allocator.alloc([784]f32, self.images.len);
        for (self.images, result) |img, *out| {
            for (img.pixels, out) |p, *o| {
                o.* = @as(f32, @floatFromInt(p)) / 255.0;
            }
        }
        return result;
    }
};

pub const FormatBenchmark = struct {
    format_name: []const u8,
    bits_per_weight: f32,
    train_accuracy: f32,
    test_accuracy: f32,
    gap_vs_fp32: f32,
    model_size_kb: f32,

    pub fn passes(self: *const FormatBenchmark, gf16_threshold: f32, ternary_threshold: f32) bool {
        if (std.mem.eql(u8, self.format_name, "GF16")) {
            return @abs(self.gap_vs_fp32) <= gf16_threshold;
        }
        if (std.mem.eql(u8, self.format_name, "Ternary")) {
            return @abs(self.gap_vs_fp32) <= ternary_threshold;
        }
        return true;
    }
};

pub const BenchResult = struct {
    benchmarks: []FormatBenchmark,
    dataset_name: []const u8,
    seed: u64,

    pub fn print(self: *const BenchResult, writer: anytype) !void {
        try writer.print("\n  BENCH-005: {s} (seed={d})\n", .{ self.dataset_name, self.seed });
        try writer.print  ("  {s}\n", .{"-" * 72});
        try writer.print  ("  {s:<12} {s:>6} {s:>10} {s:>10} {s:>12}\n", .{ "Format", "Bits", "Train%", "Test%", "Gap vs FP32" });
        try writer.print  ("  {s}\n", .{"-" * 72});
        for (self.benchmarks) |b| {
            try writer.print("  {s:<12} {d:>5.1} {d:>9.2} {d:>9.2} {d:>11.2}%\n", .{
                b.format_name,
                b.bits_per_weight,
                b.train_accuracy * 100,
                b.test_accuracy * 100,
                b.gap_vs_fp32 * 100,
            });
        }
        try writer.print("  {s}\n\n", .{"-" * 72});
    }
};

pub fn computeAccuracy(predictions: []const usize, labels: []const u8) f32 {
    var correct: usize = 0;
    for (predictions, labels) |pred, lbl| {
        if (pred == lbl) correct += 1;
    }
    return @as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(labels.len));
}

pub fn computeGap(ternary_acc: f32, fp32_acc: f32) f32 {
    return fp32_acc - ternary_acc;
}

test "compute accuracy" {
    const preds = [_]usize{ 0, 1, 2, 3, 4 };
    const labels = [_]u8{ 0, 1, 3, 3, 5 };
    const acc = computeAccuracy(&preds, &labels);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), acc, 1e-6);
}

test "compute gap" {
    const gap = computeGap(0.95, 0.98);
    try std.testing.expectApproxEqAbs(@as(f32, 0.03), gap, 1e-6);
}

test "format benchmark passes" {
    const bench = FormatBenchmark{
        .format_name = "GF16",
        .bits_per_weight = 16,
        .train_accuracy = 0.97,
        .test_accuracy = 0.96,
        .gap_vs_fp32 = 0.003,
        .model_size_kb = 100,
    };
    try std.testing.expect(bench.passes(0.005, 0.02));
}

test "format benchmark fails" {
    const bench = FormatBenchmark{
        .format_name = "Ternary",
        .bits_per_weight = 2,
        .train_accuracy = 0.90,
        .test_accuracy = 0.88,
        .gap_vs_fp32 = 0.05,
        .model_size_kb = 10,
    };
    try std.testing.expect(!bench.passes(0.005, 0.02));
}
