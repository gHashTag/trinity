// CIFAR-10 Dataset Downloader
//
// Downloads and extracts CIFAR-10 binary dataset to data/cifar-10/
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

const CIFAR10_URL = "https://www.cs.toronto.edu/~kriz/cifar-10-binary.tar.gz";
const TARGET_DIR = "data/cifar-10";
const ARCHIVE_NAME = "cifar-10-binary.tar.gz";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create target directory
    std.fs.cwd().makePath(TARGET_DIR) catch |e| {
        std.debug.print("Error creating directory: {}\n", .{e});
        return e;
    };

    const archive_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ TARGET_DIR, ARCHIVE_NAME });
    defer allocator.free(archive_path);

    // Download using curl (platform-provided)
    std.debug.print("Downloading CIFAR-10 dataset from {s}...\n", .{CIFAR10_URL});

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-L", "-o", archive_path, CIFAR10_URL },
    }) catch |e| {
        std.debug.print("Error downloading: {}\n", .{e});
        return e;
    };
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) {
        std.debug.print("curl failed: {s}\n", .{result.stderr});
        return error.DownloadFailed;
    }

    std.debug.print("Downloaded to {s}\n", .{archive_path});

    // Extract archive
    std.debug.print("Extracting archive...\n", .{});

    const extract_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "tar", "-xzf", archive_path, "-C", TARGET_DIR },
    }) catch |e| {
        std.debug.print("Error extracting: {}\n", .{e});
        return e;
    };
    defer {
        allocator.free(extract_result.stdout);
        allocator.free(extract_result.stderr);
    }

    if (extract_result.term.Exited != 0) {
        std.debug.print("tar failed: {s}\n", .{extract_result.stderr});
        return error.ExtractFailed;
    }

    std.debug.print("Extracted successfully\n", .{});

    // Verify files exist
    const expected_files = [_][]const u8{
        "data_batch_1.bin",
        "data_batch_2.bin",
        "data_batch_3.bin",
        "data_batch_4.bin",
        "data_batch_5.bin",
        "test_batch.bin",
    };

    std.debug.print("\nVerifying extracted files:\n", .{});
    for (expected_files) |file| {
        const file_path = try std.fmt.allocPrint(allocator, "{s}/cifar-10-batches-bin/{s}", .{ TARGET_DIR, file });
        defer allocator.free(file_path);

        if (std.fs.cwd().statFile(file_path)) |_| {
            std.debug.print("  ✓ {s}\n", .{file});
        } else |e| {
            std.debug.print("  ✗ {s} (missing: {})\n", .{ file, e });
        }
    }

    std.debug.print("\nCIFAR-10 dataset ready at {s}/cifar-10-batches-bin/\n", .{TARGET_DIR});
}
