// tri package — Prepare Trinity archive for friend's Mac
// φ² + 1/φ² = 3 = TRINITY
//
// Creates minimal archive with Docker files + training code + dataset
// Removes: .git, zig-cache, zig-out, src/tri, fpga, docs, specs

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

const FriendPackage = struct {
    allocator: mem.Allocator,
    source_dir: []const u8,
    output_dir: []const u8,
    temp_dir: std.fs.Dir,

    // Files/dirs to include
    includes: []const []const u8 = &.{
        "deploy/docker/docker-compose.wave9.yml",
        "deploy/Dockerfile.hslm-train-local.arm64-test",
        "data/tinystories",
        "data/wave9",
        "src/hslm",
        "kaggle/eval",
    },

    // Patterns to exclude
    excludes: []const []const u8 = &.{
        ".git",
        "zig-cache",
        "zig-out",
        "zig-out-linux",
        ".zig-cache",
        ".zig-build",
        "src/tri",
        "src/vm",
        "src/vsa",
        "src/temple",
        "src/queen",
        "src/farm",
        "src/economy",
        "src/tri-lang",
        "src/trinity_node",
        "fpga",
        "docs",
        "specs",
        ".github",
        ".ralph",
        "tnn",
        "node_modules",
    },

    fn create(allocator: mem.Allocator, source_dir: []const u8, output_dir: []const u8) !FriendPackage {
        const temp_path = try fs.path.join(allocator, &.{ output_dir, "trinity-friend-temp" });
        defer allocator.free(temp_path);

        // Clean temp dir if exists
        fs.cwd().deleteTree(temp_path) catch {};

        const temp_dir = try fs.cwd().makeOpenPath(temp_path, .{});
        return .{
            .allocator = allocator,
            .source_dir = source_dir,
            .output_dir = output_dir,
            .temp_dir = temp_dir,
        };
    }

    fn shouldExclude(self: *const FriendPackage, path: []const u8) bool {
        for (self.excludes) |exclude| {
            if (std.mem.indexOf(u8, path, exclude) != null) {
                return true;
            }
        }
        return false;
    }

    fn copyDir(self: *FriendPackage, src_path: []const u8, dest_path: []const u8) !void {
        var src_dir = try fs.cwd().openDir(src_path, .{ .iterate = true });
        defer src_dir.close();

        var walker = try src_dir.walk(self.allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const full_path = try fs.path.join(self.allocator, &.{ src_path, entry.path });
            defer self.allocator.free(full_path);

            if (self.shouldExclude(full_path)) continue;

            const rel_path = entry.path;
            const dest_full = try fs.path.join(self.allocator, &.{ dest_path, rel_path });
            defer self.allocator.free(dest_full);

            switch (entry.kind) {
                .directory => {
                    try self.temp_dir.makePath(dest_full);
                },
                .file => {
                    const dest_dir_path = fs.path.dirname(dest_full) orelse ".";
                    try self.temp_dir.makePath(dest_dir_path);

                    const src_file = try fs.cwd().openFile(full_path, .{});
                    defer src_file.close();

                    const dest_file = try self.temp_dir.createFile(dest_full, .{});
                    defer dest_file.close();

                    // Copy file in chunks (copyRange has 32KB limit)
                    const buffer_size = 64 * 1024; // 64KB chunks
                    var buffer: [buffer_size]u8 = undefined;
                    var offset: u64 = 0;
                    while (true) {
                        const bytes_read = try src_file.preadAll(&buffer, offset);
                        if (bytes_read == 0) break;
                        try dest_file.writeAll(buffer[0..bytes_read]);
                        offset += bytes_read;
                    }
                },
                else => {},
            }
        }
    }

    fn build(self: *FriendPackage) !void {
        std.debug.print("Creating Trinity friend package...\n", .{});

        for (self.includes) |include| {
            const src_path = try fs.path.join(self.allocator, &.{ self.source_dir, include });
            defer self.allocator.free(src_path);

            const stat = fs.cwd().statFile(src_path) catch |err| {
                std.debug.print("Warning: skipping {s}: {s}\n", .{ include, @errorName(err) });
                continue;
            };

            const dest_path = include;

            switch (stat.kind) {
                .directory => {
                    std.debug.print("Copying {s}/...\n", .{include});
                    try self.copyDir(src_path, dest_path);
                },
                .file => {
                    std.debug.print("Copying {s}\n", .{include});
                    const dest_dir = fs.path.dirname(dest_path) orelse ".";
                    try self.temp_dir.makePath(dest_dir);

                    const src_file = try fs.cwd().openFile(src_path, .{});
                    defer src_file.close();

                    const dest_file = try self.temp_dir.createFile(dest_path, .{});
                    defer dest_file.close();

                    // Copy file in chunks (copyRange has 32KB limit)
                    const buffer_size = 64 * 1024; // 64KB chunks
                    var buffer: [buffer_size]u8 = undefined;
                    var offset: u64 = 0;
                    while (true) {
                        const bytes_read = try src_file.preadAll(&buffer, offset);
                        if (bytes_read == 0) break;
                        try dest_file.writeAll(buffer[0..bytes_read]);
                        offset += bytes_read;
                    }
                },
                else => {},
            }
        }

        // Create README for friend
        const readme =
            \\# Trinity HSLM Training — Friend Package
            \\\\phi² + 1/phi² = 3 = TRINITY
            \\
            \\## Что нужно
            \\
            \\1. Docker Desktop для Mac (Apple Silicon) — https://www.docker.com/products/docker-desktop/
            \\2. Этот архив распаковать в любую папку
            \\
            \\## Запуск
            \\
            \\```bash
            \\cd trinity-friend
            \\docker compose -f deploy/docker/docker-compose.wave9.yml up -d w9-1 w9-2
            \\```
            \\
            \\## Статус
            \\
            \\```bash
            \\docker compose -f deploy/docker/docker-compose.wave9.yml logs -f w9-1
            \\docker compose -f deploy/docker/docker-compose.wave9.yml ps
            \\```
            \\
            \\## Остановить
            \\
            \\```bash
            \\docker compose -f deploy/docker/docker-compose.wave9.yml down
            \\```
            \\
            \\## Что внутри
            \\
            \\- `deploy/docker/docker-compose.wave9.yml` — конфигурация 48 workers
            \\- `data/tinystories/` — обучающий датасет (~2GB)
            \\- `data/wave9/` — папки для чекпоинтов
            \\- `src/hslm/` — код обучения HSLM
            \\- `kaggle/eval/` — метрики для оценки
            \\
        ;

        try self.temp_dir.writeFile(.{ .sub_path = "README.md", .data = readme });
    }

    fn createArchive(self: *FriendPackage) !void {
        const timestamp = std.time.timestamp();
        const archive_name = try std.fmt.allocPrint(self.allocator, "trinity-friend-{d}.tar.gz", .{timestamp});
        defer self.allocator.free(archive_name);

        const archive_path = try fs.path.join(self.allocator, &.{ self.output_dir, archive_name });
        defer self.allocator.free(archive_path);

        std.debug.print("\nCreating archive: {s}...\n", .{archive_name});

        // Use system tar to create gzipped archive
        const argv = &[_][]const u8{
            "tar",
            "-czf",
            archive_path,
            "-C",
            try fs.path.join(self.allocator, &.{ self.output_dir, "trinity-friend-temp" }),
            ".",
        };

        const result = try process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
            .cwd = ".",
        });

        if (result.term.Exited != 0 and result.term.Exited != 0) {
            std.debug.print("tar warning: exit code {d}\n", .{result.term.Exited});
        }

        // Get file size
        const file_stat = try fs.cwd().statFile(archive_path);
        const size_mb = @as(f64, @floatFromInt(file_stat.size)) / (1024 * 1024);

        std.debug.print("\n✓ Archive created: {s} ({d:.1} MB)\n", .{ archive_path, size_mb });
        std.debug.print("\nПередай этот файл другу!\n", .{});
    }

    fn cleanup(self: *FriendPackage) void {
        const temp_path = fs.path.join(self.allocator, &.{ self.output_dir, "trinity-friend-temp" }) catch return;
        defer self.allocator.free(temp_path);
        fs.cwd().deleteTree(temp_path) catch {};
    }

    fn deinit(self: *FriendPackage) void {
        self.temp_dir.close();
    }
};

pub fn execute(allocator: mem.Allocator, args: []const []const u8) !u8 {
    _ = args;

    const source_dir = "."; // Current directory
    const output_dir = "."; // Output to current directory

    var pkg = try FriendPackage.create(allocator, source_dir, output_dir);
    defer pkg.deinit();
    defer pkg.cleanup();

    try pkg.build();
    try pkg.createArchive();

    return 0;
}
