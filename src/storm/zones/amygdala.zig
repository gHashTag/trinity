//! AMYGDALA - Mistake Memory (MNL Pattern)
//! 1x failure → Warning logged
//! 2x failure → Elevated concern
//! 3x failure → BLACKLISTED

const std = @import("std");

pub const BlacklistEntry = struct {
    task: []const u8,
    failure_count: u8,
    last_failure: i64,
    context: []const u8,
};

pub const Amygdala = struct {
    allocator: std.mem.Allocator,
    blacklist: std.StringHashMap(BlacklistEntry),
    blacklist_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !Amygdala {
        const blacklist_path = try allocator.dupe(u8, ".trinity/mistakes/blacklist.json");
        errdefer allocator.free(blacklist_path);

        // Ensure directory exists
        std.fs.cwd().makePath(".trinity/mistakes") catch {};

        var amygdala = Amygdala{
            .allocator = allocator,
            .blacklist = std.StringHashMap(BlacklistEntry).init(allocator),
            .blacklist_path = blacklist_path,
        };

        // Load existing blacklist
        try amygdala.load();

        return amygdala;
    }

    pub fn deinit(self: *Amygdala) void {
        var iter = self.blacklist.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.task);
            self.allocator.free(entry.value_ptr.context);
        }
        self.blacklist.deinit();
        self.allocator.free(self.blacklist_path);
    }

    pub fn load(self: *Amygdala) !void {
        const file = std.fs.cwd().openFile(self.blacklist_path, .{}) catch |err| {
            if (err == error.FileNotFound) return; // No blacklist yet
            return err;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        // Parse JSON blacklist
        const parsed = try std.json.parseFromSlice(
            std.StringHashMap(BlacklistEntry),
            self.allocator,
            content,
            .{ .ignore_unknown_fields = true },
        );
        defer parsed.deinit();

        // Merge into existing
        var iter = parsed.value.iterator();
        while (iter.next()) |entry| {
            const key = try self.allocator.dupe(u8, entry.key_ptr.*);
            const value = BlacklistEntry{
                .task = try self.allocator.dupe(u8, entry.value_ptr.task),
                .failure_count = entry.value_ptr.failure_count,
                .last_failure = entry.value_ptr.last_failure,
                .context = try self.allocator.dupe(u8, entry.value_ptr.context),
            };
            try self.blacklist.put(key, value);
        }
    }

    pub fn save(self: *Amygdala) !void {
        const file = try std.fs.cwd().createFile(.{
            .sub_path = self.blacklist_path,
        });
        defer file.close();

        try std.json.stringify(self.blacklist, .{ .whitespace = .indent_2 }, file.writer());
    }

    pub fn recordFailure(self: *Amygdala, task: []const u8, context: []const u8) !void {
        const now = std.time.nanoTimestamp();

        if (self.blacklist.get(task)) |entry| {
            // Increment failure count
            var updated = entry;
            updated.failure_count += 1;
            updated.last_failure = now;
            updated.context = try self.allocator.dupe(u8, context);

            // Free old context
            self.allocator.free(entry.context);

            try self.blacklist.put(task, updated);

            if (updated.failure_count >= 3) {
                std.log.warn("⚠️  AMYGDALA: Task '{s}' BLACKLISTED ({d} failures)", .{ task, updated.failure_count });
            } else if (updated.failure_count == 2) {
                std.log.warn("⚠️  AMYGDALA: Task '{s}' has 2 failures - elevated concern", .{task});
            }
        } else {
            // New failure
            const entry = BlacklistEntry{
                .task = try self.allocator.dupe(u8, task),
                .failure_count = 1,
                .last_failure = now,
                .context = try self.allocator.dupe(u8, context),
            };
            try self.blacklist.put(try self.allocator.dupe(u8, task), entry);
            std.log.warn("⚠️  AMYGDALA: Task '{s}' failed (1st time)", .{task});
        }

        try self.save();
    }

    pub fn checkFear(self: *Amygdala, task: []const u8) !struct {
        is_blacklisted: bool,
        failure_count: u8,
        reason: []const u8,
    } {
        if (self.blacklist.get(task)) |entry| {
            if (entry.failure_count >= 3) {
                return .{
                    .is_blacklisted = true,
                    .failure_count = entry.failure_count,
                    .reason = try std.fmt.allocPrint(
                        self.allocator,
                        "Task blacklisted after {d} failures. Last context: {s}",
                        .{ entry.failure_count, entry.context },
                    ),
                };
            }
        }

        return .{
            .is_blacklisted = false,
            .failure_count = 0,
            .reason = "Task not blacklisted",
        };
    }

    /// Levenshtein distance for fuzzy matching
    pub fn levenshteinDistance(self: *Amygdala, a: []const u8, b: []const u8) !usize {
        _ = self;
        const m = a.len;
        const n = b.len;

        // Early exit for empty strings
        if (m == 0) return n;
        if (n == 0) return m;

        // Create distance matrix
        var matrix = try self.allocator.alloc(usize, (m + 1) * (n + 1));
        defer self.allocator.free(matrix);

        // Initialize first row and column
        var i: usize = 0;
        while (i <= m) : (i += 1) {
            matrix[i * (n + 1)] = i;
        }
        var j: usize = 0;
        while (j <= n) : (j += 1) {
            matrix[j] = j;
        }

        // Fill matrix
        i = 1;
        while (i <= m) : (i += 1) {
            j = 1;
            while (j <= n) : (j += 1) {
                const cost = if (a[i - 1] == b[j - 1]) @as(usize, 0) else 1;
                const deletion = matrix[(i - 1) * (n + 1) + j] + 1;
                const insertion = matrix[i * (n + 1) + (j - 1)] + 1;
                const substitution = matrix[(i - 1) * (n + 1) + (j - 1)] + cost;

                matrix[i * (n + 1) + j] = @min(deletion, @min(insertion, substitution));
            }
        }

        return matrix[m * (n + 1) + n];
    }

    pub fn findSimilar(self: *Amygdala, task: []const u8, threshold: usize) ![]const []const u8 {
        var similar = std.ArrayList([]const u8).init(self.allocator);

        var iter = self.blacklist.iterator();
        while (iter.next()) |entry| {
            const distance = try self.levenshteinDistance(task, entry.key_ptr.*);
            if (distance <= threshold) {
                try similar.append(try self.allocator.dupe(u8, entry.key_ptr.*));
            }
        }

        return similar.toOwnedSlice();
    }
};
