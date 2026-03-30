// @origin manual

// ═════════════════════════════════════════════════════════════════════════════
// KAGGLE MODULE — Export kaggle submodules for use by tri_kaggle
// ═════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3 = TRINITY
// ═════════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const Track = struct {
    id: []const u8,
    name: []const u8,
    dataset: []const u8,
    path: []const u8,
    notebook_count: usize,
};

pub const CsvParser = @import("csv_parser.zig").CsvParser;
pub const McGenerator = @import("mc_generator.zig").McGenerator;
pub const Evaluator = @import("evaluator.zig").Evaluator;
pub const Exporter = @import("export.zig").BatchExporter;

pub const Kaggle = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Kaggle {
        return .{
            .allocator = allocator,
        };
    }

    /// Export kaggle submodules for use by tri kaggle
    pub fn exportModules(self: *Kaggle, output_dir: []const u8) !void {
        const kaggle_dir = try std.fs.cwd().makePath(output_dir) catch "";
        defer {
            self.allocator.free(kaggle_dir);
        };

        const exports_dir = try std.fmt.allocPrint(self.allocator, "{s}/kaggle", .{kaggle_dir});
        defer self.allocator.free(exports_dir);

        // Create src/kaggle subdirectory if needed
        const src_path = try std.fmt.allocPrint(self.allocator, "{s}/src", .{kaggle_dir});
        defer self.allocator.free(src_path);

        try std.fs.cwd().makeDir(src_path) catch {};

        const module_path = try std.fmt.allocPrint(self.allocator, "{s}/kaggle/zig", .{src_path});
        defer self.allocator.free(module_path);

        std.debug.print("Created Kaggle module at {s}\n", .{module_path});

        // Copy all submodule files
        const files = [_][]const u8{
            "csv_parser.zig",
            "mc_generator.zig",
            "matcher.zig",
            "evaluator.zig",
            "export.zig",
        };

        for (files) |file| {
            const src = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ "src/kaggle", file });
            defer self.allocator.free(src);

            const dst = try std.fmt.allocPrint(self.allocator, "{s}/kaggle/zig", .{file });
            defer self.allocator.free(dst);

            const src_file = try std.fs.cwd().openFile(src, .{}) catch |err| {
                std.debug.print("❌ Failed to copy {s}: {}\n", .{file, err});
                continue;
            };
            defer src_file.close();

            const result = try std.fs.cwd().copyFile(src, dst, .{}) catch |err| {
                std.debug.print("❌ Failed to copy {s}: {}\n", .{file, err});
                continue;
            };
            defer result.close();
            std.debug.print("✅ Copied {s}\n", .{file});
        }

        std.debug.print("Copied {} files to {s}/src/kaggle/\n", .{files.len, exports_dir});
    }
};

// ═════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "export kaggle modules" {
    const allocator = std.testing.allocator;

    const kaggle = Kaggle.init(allocator);
    try kaggle.exportModules(allocator, "/tmp/test_kaggle_export");
}
