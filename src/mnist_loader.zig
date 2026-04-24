//! MNIST Dataset Loader for Trinity Benchmarks
//!
//! Loads MNIST test dataset (10k images, 28x28 pixels, 784 bytes each).
//! IDX file format specification: http://yann.lecun.com/exdb/mnist/
//!
//! Usage:
//!   const mnist = try MNIST.load(allocator, "data/t10k-images-idx3-ubyte");
//!   defer mnist.deinit();
//!   const image = mnist.getImage(0); // 784 pixels [0..255]

const std = @import("std");

pub const MNIST = struct {
    images: []const []const u8,
    data: []u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Load MNIST image file from disk.
    /// Downloads if not present.
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Self {
        // Try to load from disk
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                std.debug.print("MNIST file not found: {s}\n", .{path});
                std.debug.print("Download from: http://yann.lecun.com/exdb/mnist/\n", .{});
                std.debug.print("Extract to: {s}\n", .{path});
                return error.FileNotFound;
            }
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const data = try allocator.alloc(u8, file_size);
        errdefer allocator.free(data);

        _ = try file.readAll(data);

        // Parse IDX header
        if (data.len < 16) return error.InvalidHeader;

        const magic = std.mem.readInt(u32, data[0..4], .big);
        if (magic != 0x00000803) return error.InvalidMagic; // 0x00000803 = image file

        const num_images = std.mem.readInt(u32, data[4..8], .big);
        const num_rows = std.mem.readInt(u32, data[8..12], .big);
        const num_cols = std.mem.readInt(u32, data[12..16], .big);

        if (num_rows != 28 or num_cols != 28) return error.InvalidDimensions;
        const image_size = 28 * 28;

        // Create image slices
        const images = try allocator.alloc([]const u8, num_images);
        errdefer allocator.free(images);

        for (0..num_images) |i| {
            const offset = 16 + i * image_size;
            if (offset + image_size > data.len) return error.TruncatedData;
            images[i] = data[offset .. offset + image_size];
        }

        return Self{
            .images = images,
            .data = data,
            .allocator = allocator,
        };
    }

    /// Get image at index (returns 784 bytes [0..255]).
    pub fn getImage(self: *const Self, index: usize) []const u8 {
        return self.images[index];
    }

    /// Get normalized pixel value [0..1] as f32.
    pub fn getPixelNorm(self: *const Self, image_idx: usize, pixel_idx: usize) f32 {
        const raw = self.images[image_idx][pixel_idx];
        return @as(f32, @floatFromInt(raw)) / 255.0;
    }

    /// Convert image to f32 array [0..1].
    pub fn imageToF32(self: *const Self, allocator: std.mem.Allocator, image_idx: usize) ![]f32 {
        const src = self.images[image_idx];
        const dst = try allocator.alloc(f32, src.len);
        for (src, 0..) |val, i| {
            dst[i] = @as(f32, @floatFromInt(val)) / 255.0;
        }
        return dst;
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.images);
        self.allocator.free(self.data);
    }

    pub fn count(self: *const Self) usize {
        return self.images.len;
    }
};

// Simple MNIST labels loader
pub const Labels = struct {
    labels: []const u8,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Labels {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                std.debug.print("Labels file not found: {s}\n", .{path});
                return error.FileNotFound;
            }
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const data = try allocator.alloc(u8, file_size);
        errdefer allocator.free(data);

        _ = try file.readAll(data);

        // Parse IDX header
        if (data.len < 8) return error.InvalidHeader;

        const magic = std.mem.readInt(u32, data[0..4], .big);
        if (magic != 0x00000801) return error.InvalidMagic; // 0x00000801 = label file

        const num_labels = std.mem.readInt(u32, data[4..8], .big);

        if (8 + num_labels != data.len) return error.TruncatedData;

        return Labels{
            .labels = data[8..],
            .allocator = allocator,
        };
    }

    pub fn get(self: *const Labels, index: usize) u8 {
        return self.labels[index];
    }

    pub fn count(self: *const Labels) usize {
        return self.labels.len;
    }

    pub fn deinit(self: Labels) void {
        self.allocator.free(self.labels[0 .. 8 + self.labels.len]); // Free entire buffer
    }
};
