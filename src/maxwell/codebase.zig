// Maxwell Daemon - Codebase Interface
// [CYR:Интерфей]with for inзаand[CYR:модей]withтinandя agentа with toоbeforeinой [CYR:базой]
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CODEBASE INTERFACE
// ═══════════════════════════════════════════════════════════════════════════════

/// Result operation with fileом
pub const FileResult = struct {
    success: bool,
    content: ?[]const u8,
    error_msg: ?[]const u8,
};

/// Result inыbyлnotнandя command
pub const ExecResult = struct {
    exit_code: i32,
    stdout: []const u8,
    stderr: []const u8,
    duration_ms: u64,
};

/// [CYR:Информац]andя о fileе
pub const FileInfo = struct {
    path: []const u8,
    size: u64,
    is_dir: bool,
    modified_time: i128,
};

/// Тandп and[CYR:зме]notнandя in diff
pub const DiffType = enum {
    Added,
    Removed,
    Modified,
    Unchanged,
};

/// [CYR:Стро]toа diff
pub const DiffLine = struct {
    line_num: u32,
    diff_type: DiffType,
    content: []const u8,
};

/// [CYR:Интерфей]with for [CYR:раб]fromы with toоbeforeinой [CYR:базой]
pub const Codebase = struct {
    allocator: std.mem.Allocator,
    root_path: []const u8,
    
    // [CYR:Кэш] [CYR:проч]and[CYR:танных] fileоin
    file_cache: std.StringHashMap([]const u8),
    
    // Иwith[CYR:тор]andя and[CYR:зме]notнandй for fromto[CYR:ата]
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

    /// [CYR:Проч]and[CYR:тать] file
    pub fn readFile(self: *Codebase, path: []const u8) FileResult {
        // [CYR:Про]inерandть toэш
        if (self.file_cache.get(path)) |cached| {
            return FileResult{
                .success = true,
                .content = cached,
                .error_msg = null,
            };
        }

        // Поbuildsь by[CYR:лный] path
        const full_path = std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, path }) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to join path",
            };
        };
        defer self.allocator.free(full_path);

        // [CYR:Проч]and[CYR:тать] file
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

        // [CYR:Кэш]andроin[CYR:ать]
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

    /// [CYR:Получ]andть list fileоin in дandреto[CYR:тор]andand
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
            // Фand[CYR:льтр] by [CYR:паттерну]
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

    /// [CYR:Найт]and fileы by [CYR:паттерну] реtoурwithandinно
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

    /// [CYR:Зап]andwith[CYR:ать] file
    pub fn writeFile(self: *Codebase, path: []const u8, content: []const u8) FileResult {
        // [CYR:Сохран]andть old with[CYR:одерж]and[CYR:мое] for andwith[CYR:тор]andand
        const old_content = if (self.file_cache.get(path)) |cached|
            self.allocator.dupe(u8, cached) catch null
        else
            null;

        // Поbuildsь by[CYR:лный] path
        const full_path = std.fs.path.join(self.allocator, &[_][]const u8{ self.root_path, path }) catch {
            return FileResult{
                .success = false,
                .content = null,
                .error_msg = "Failed to join path",
            };
        };
        defer self.allocator.free(full_path);

        // [CYR:Соз]yesть дandреto[CYR:тор]andand if need
        if (std.fs.path.dirname(full_path)) |dir| {
            std.fs.cwd().makePath(dir) catch {};
        }

        // [CYR:Зап]andwith[CYR:ать] file
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

        // [CYR:Обно]inandть toэш
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

        // [CYR:Зап]andwith[CYR:ать] in andwith[CYR:тор]andю
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

    /// Уyesлandть file
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

        // Уyesлandть andз to[CYR:эша]
        if (self.file_cache.fetchRemove(path)) |kv| {
            self.allocator.free(kv.value);
        }

        return FileResult{
            .success = true,
            .content = null,
            .error_msg = null,
        };
    }

    /// Отtoатandть bywith[CYR:лед]notе change
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

    /// Выbyлнandть to[CYR:оманду]
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

    /// [CYR:Запу]withтandть testы
    pub fn runTests(self: *Codebase, test_path: []const u8) ExecResult {
        return self.exec("zig", &[_][]const u8{ "test", test_path });
    }

    /// [CYR:Запу]withтandть vibee gen
    pub fn runVibeeGen(self: *Codebase, spec_path: []const u8) ExecResult {
        return self.exec("./bin/vibee", &[_][]const u8{ "gen", spec_path });
    }

    /// [CYR:Запу]withтandть git to[CYR:оманду]
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
