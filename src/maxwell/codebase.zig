// Maxwell Daemon - Codebase Interface
// Интерфейс для взаимодействия агента с кодовой базой
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CODEBASE INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════

/// Результат операции с файлом
pub const FileResult = struct {
    success: bool,
    content: ?[]const u8,
    error_msg: ?[]const u8,
};

/// Результат выполнения команды
pub const ExecResult = struct {
    exit_code: i32,
    stdout: []const u8,
    stderr: []const u8,
    duration_ms: u64,
};

/// Информация о файле
pub const FileInfo = struct {
    path: []const u8,
    size: u64,
    is_dir: bool,
    modified_time: i128,
};

/// Тип изменения в diff
pub const DiffType = enum {
    Added,
    Removed,
    Modified,
    Unchanged,
};

/// Строка diff
pub const DiffLine = struct {
    line_num: u32,
    diff_type: DiffType,
    content: []const u8,
};

/// Интерфейс для работы с кодовой базой
pub const Codebase = struct {
    allocator: std.mem.Allocator,
    root_path: []const u8,
    
    // Кэш прочитанных файлов
    file_cache: std.StringHashMap([]const u8),
    
    // История изменений для отката
    change_history: std.ArrayList(Change),
    
    const Change = struct {
        path: []const u8,
        old_content: ?[]const u8,
        new_content: []const u8,
        timestamp: i64,
    };

    pub fn init(allocator: std.mem.Allocator, root_path: []const u8) Codebase {
        return Codebase{
            .allocator = allocator,
            .root_path = root_path,
            .file_cache = std.StringHashMap([]const u8).init(allocator),
            .change_history = std.ArrayList(Change).init(allocator),
        };
    }

    pub fn deinit(self: *Codebase) void {
        var iter = self.file_cache.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.file_cache.deinit();
        
        for (self.change_history.items) |change| {
            if (change.old_content) |old| {
                self.allocator.free(old);
            }
            self.allocator.free(change.new_content);
        }
        self.change_history.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // READ OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Прочитать файл
    pub fn readFile(self: *Codebase, path: []const u8) FileResult {
        // Проверить кэш
        if (self.file_cache.get(path)) |cached| {
            return FileResult{
                .success = true,
                .content = cached,
                .error_msg = null,
            };
        }

        // Построить полный путь
        const full_path = std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, path }) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to join path",
            };
        };
        defer self.allocator.free(full_path);

        // Прочитать файл
        const file = std.fs.cwd().openFile(full_path, .{}) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "File not found",
            };
        };
        defer file.close();

        const stat = file.stat() catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to stat file",
            };
        };

        const content = self.allocator.alloc(u8, stat.size) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Out of memory",
            };
        };

        _ = file.readAll(content) catch {
            self.allocator.free(content);
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to read file",
            };
        };

        // Кэшировать
        const path_copy = self.allocator.dupe(u8, path) catch {
            self.allocator.free(content);
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Out of memory",
            };
        };
        self.file_cache.put(path_copy, content) catch {};

        return FileResult{
            .success = true,
            .content = content,
            .error_msg = null,
        };
    }

    /// Получить список файлов в директории
    pub fn listFiles(self: *Codebase, dir_path: []const u8, pattern: ?[]const u8) !std.ArrayList(FileInfo) {
        var result = std.ArrayList(FileInfo).init(self.allocator);

        const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, dir_path });
        defer self.allocator.free(full_path);

        var dir = std.fs.cwd().openDir(full_path, .{ .iterate = true }) catch {
            return result;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            // Фильтр по паттерну
            if (pattern) |p| {
                if (!matchPattern(entry.name, p)) continue;
            }

            const info = FileInfo{
                .path = try self.allocator.dupe(u8, entry.name),
                .size = 0, // TODO: get actual size
                .is_dir = entry.kind == .directory,
                .modified_time = 0,
            };
            try result.append(info);
        }

        return result;
    }

    /// Найти файлы по паттерну рекурсивно
    pub fn findFiles(self: *Codebase, pattern: []const u8) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(self.allocator);
        try self.findFilesRecursive("", pattern, &result);
        return result;
    }

    fn findFilesRecursive(self: *Codebase, dir_path: []const u8, pattern: []const u8, result: *std.ArrayList([]const u8)) !void {
        const full_path = if (dir_path.len > 0)
            try std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, dir_path })
        else
            try self.allocator.dupe(u8, self.root_path);
        defer self.allocator.free(full_path);

        var dir = std.fs.cwd().openDir(full_path, .{ .iterate = true }) catch return;
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            const entry_path = if (dir_path.len > 0)
                try std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, entry.name })
            else
                try self.allocator.dupe(u8, entry.name);

            if (entry.kind == .directory) {
                // Skip hidden and common ignore dirs
                if (entry.name[0] != '.' and !std.mem.eql(u8, entry.name, "node_modules") and
                    !std.mem.eql(u8, entry.name, "zig-cache") and !std.mem.eql(u8, entry.name, ".zig-cache"))
                {
                    try self.findFilesRecursive(entry_path, pattern, result);
                }
                self.allocator.free(entry_path);
            } else {
                if (matchPattern(entry.name, pattern)) {
                    try result.append(entry_path);
                } else {
                    self.allocator.free(entry_path);
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WRITE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Записать файл
    pub fn writeFile(self: *Codebase, path: []const u8, content: []const u8) FileResult {
        // Сохранить старое содержимое для истории
        const old_content = if (self.file_cache.get(path)) |cached|
            self.allocator.dupe(u8, cached) catch null
        else
            null;

        // Построить полный путь
        const full_path = std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, path }) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to join path",
            };
        };
        defer self.allocator.free(full_path);

        // Создать директории если нужно
        if (std.fs.path.dirname(full_path)) |dir| {
            std.fs.cwd().makePath(dir) catch {};
        }

        // Записать файл
        const file = std.fs.cwd().createFile(full_path, .{}) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to create file",
            };
        };
        defer file.close();

        file.writeAll(content) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to write file",
            };
        };

        // Обновить кэш
        const content_copy = self.allocator.dupe(u8, content) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Out of memory",
            };
        };

        if (self.file_cache.getPtr(path)) |ptr| {
            self.allocator.free(ptr.*);
            ptr.* = content_copy;
        } else {
            const path_copy = self.allocator.dupe(u8, path) catch {
                self.allocator.free(content_copy);
                return FileResult{
                    .success = false,
                    .content = null,
                    .error_msg = "Out of memory",
                };
            };
            self.file_cache.put(path_copy, content_copy) catch {};
        }

        // Записать в историю
        self.change_history.append(Change{
            .path = self.allocator.dupe(u8, path) catch path,
            .old_content = old_content,
            .new_content = self.allocator.dupe(u8, content) catch content,
            .timestamp = std.time.timestamp(),
        }) catch {};

        return FileResult{
            .success = true,
            .content = content_copy,
            .error_msg = null,
        };
    }

    /// Удалить файл
    pub fn deleteFile(self: *Codebase, path: []const u8) FileResult {
        const full_path = std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, path }) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to join path",
            };
        };
        defer self.allocator.free(full_path);

        std.fs.cwd().deleteFile(full_path) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to delete file",
            };
        };

        // Удалить из кэша
        if (self.file_cache.fetchRemove(path)) |kv| {
            self.allocator.free(kv.value);
        }

        return FileResult{
            .success = true,
            .content = null,
            .error_msg = null,
        };
    }

    /// Откатить последнее изменение
    pub fn undo(self: *Codebase) FileResult {
        if (self.change_history.items.len == 0) {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "No changes to undo",
            };
        }

        const change = self.change_history.pop();
        
        if (change.old_content) |old| {
            return self.writeFile(change.path, old);
        } else {
            return self.deleteFile(change.path);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // EXECUTE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Выполнить команду
    pub fn exec(self: *Codebase, command: []const u8, args: []const []const u8) ExecResult {
        const start_time = std.time.milliTimestamp();

        var argv = std.ArrayList([]const u8).init(self.allocator);
        defer argv.deinit();
        
        argv.append(command) catch {
            return ExecResult{
                .exit_code = -1,
                .stdout = "",
                .stderr = "Failed to build argv",
                .duration_ms = 0,
            };
        };
        
        for (args) |arg| {
            argv.append(arg) catch {};
        }

        var child = std.process.Child.init(argv.items, self.allocator);
        child.cwd = self.root_path;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch {
            return ExecResult{
                .exit_code = -1,
                .stdout = "",
                .stderr = "Failed to spawn process",
                .duration_ms = 0,
            };
        };

        const stdout = child.stdout.?.reader().readAllAlloc(self.allocator, 1024 * 1024) catch "";
        const stderr = child.stderr.?.reader().readAllAlloc(self.allocator, 1024 * 1024) catch "";

        const term = child.wait() catch {
            return ExecResult{
                .exit_code = -1,
                .stdout = stdout,
                .stderr = stderr,
                .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
            };
        };

        const exit_code: i32 = switch (term) {
            .Exited => |code| @as(i32, code),
            else => -1,
        };

        return ExecResult{
            .exit_code = exit_code,
            .stdout = stdout,
            .stderr = stderr,
            .duration_ms = @intCast(std.time.milliTimestamp() - start_time),
        };
    }

    /// Запустить тесты
    pub fn runTests(self: *Codebase, test_path: []const u8) ExecResult {
        return self.exec("zig", &[_][]const u8{ "test", test_path });
    }

    /// Запустить vibee gen
    pub fn runVibeeGen(self: *Codebase, spec_path: []const u8) ExecResult {
        return self.exec("./bin/vibee", &[_][]const u8{ "gen", spec_path });
    }

    /// Запустить git команду
    pub fn git(self: *Codebase, args: []const []const u8) ExecResult {
        return self.exec("git", args);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn matchPattern(name: []const u8, pattern: []const u8) bool {
    // Simple glob matching: *.zig, *.vibee, etc.
    if (pattern.len == 0) return true;
    
    if (pattern[0] == '*') {
        // Match suffix
        const suffix = pattern[1..];
        if (name.len < suffix.len) return false;
        return std.mem.eql(u8, name[name.len - suffix.len ..], suffix);
    }
    
    return std.mem.eql(u8, name, pattern);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Codebase init and deinit" {
    var codebase = Codebase.init(std.testing.allocator, "/tmp");
    defer codebase.deinit();
    
    try std.testing.expectEqualStrings("/tmp", codebase.root_path);
}

test "matchPattern glob" {
    try std.testing.expect(matchPattern("test.zig", "*.zig"));
    try std.testing.expect(matchPattern("module.vibee", "*.vibee"));
    try std.testing.expect(!matchPattern("test.zig", "*.vibee"));
    try std.testing.expect(matchPattern("anything", ""));
}
