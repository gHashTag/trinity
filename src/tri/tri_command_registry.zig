// @origin(spec:tri_command_registry.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Command Registry v2.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Metadata-driven command registration with O(1) HashMap lookup
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

/// Command execution function signature
pub const CommandFn = *const fn (allocator: std.mem.Allocator, args: []const []const u8) anyerror!void;

/// Subcommand metadata
pub const Subcommand = struct {
    name: []const u8,
    description: []const u8,
    example: []const u8,
    execute: CommandFn,
};

/// Command category for grouping in help
pub const CommandCategory = enum {
    ai,
    dev,
    git,
    math,
    science,
    sacred,
    system,
    demo,
    benchmark,
    advanced,
    depin, // DePIN - Decentralized Physical Infrastructure Network
};

/// Command metadata for self-documenting CLI
pub const CommandMetadata = struct {
    /// Primary command name
    name: []const u8,
    /// Alternative names (short forms)
    aliases: []const []const u8,
    /// Short description (1 line)
    description: []const u8,
    /// Extended help text
    long_help: []const u8 = "",
    /// Category for grouping
    category: CommandCategory,
    /// Usage examples
    examples: []const []const u8 = &.{},
    /// Whether command has subcommands
    has_subcommands: bool = false,
    /// Subcommands (if any)
    subcommands: []const Subcommand = &.{},
    /// Execution function
    execute: CommandFn,
};

/// Command registry with O(1) HashMap lookup
pub const CommandRegistry = struct {
    allocator: std.mem.Allocator,
    /// HashMap: name -> CommandMetadata
    commands: std.StringHashMap(*const CommandMetadata),
    /// All metadata storage (owned)
    metadata_storage: std.ArrayList(CommandMetadata),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const storage = std.ArrayList(CommandMetadata).initCapacity(allocator, 256) catch return error.OutOfMemory;
        return .{
            .allocator = allocator,
            .commands = std.StringHashMap(*const CommandMetadata).init(allocator),
            .metadata_storage = storage,
        };
    }

    pub fn deinit(self: *Self) void {
        self.commands.deinit();
        self.metadata_storage.deinit(self.allocator);
    }

    /// Register a new command
    pub fn register(self: *Self, metadata: CommandMetadata) !void {
        try self.metadata_storage.append(self.allocator, metadata);

        // Get pointer to the newly added item
        const cmd_ptr = &self.metadata_storage.items[self.metadata_storage.items.len - 1];

        // Register primary name
        try self.commands.put(cmd_ptr.name, cmd_ptr);

        // Register aliases
        for (cmd_ptr.aliases) |alias| {
            try self.commands.put(alias, cmd_ptr);
        }
    }

    /// Find command by name or alias (O(1) lookup)
    pub fn find(self: *const Self, name: []const u8) ?*const CommandMetadata {
        return self.commands.get(name);
    }

    /// Get all commands in a category
    pub fn getByCategory(self: *const Self, category: CommandCategory) ![]const *const CommandMetadata {
        // First pass: count matching commands
        var count: usize = 0;
        for (self.metadata_storage.items) |*meta| {
            if (meta.category == category) count += 1;
        }

        // Allocate result array
        const result = try self.allocator.alloc(*const CommandMetadata, count);

        // Second pass: fill result array
        var idx: usize = 0;
        for (self.metadata_storage.items) |*meta| {
            if (meta.category == category) {
                result[idx] = meta;
                idx += 1;
            }
        }

        return result;
    }

    /// Get similar commands for "did you mean?" suggestions
    /// Using Levenshtein distance for fuzzy matching
    pub fn findSimilar(self: *const Self, name: []const u8, max_results: usize) ![]const []const u8 {
        const DistEntry = struct { cmd: []const u8, dist: usize };

        // Fixed-size buffer for distance entries
        var buffer: [64]DistEntry = undefined;
        var count: usize = 0;

        for (self.metadata_storage.items) |meta| {
            // Check primary name
            const dist = levenshtein(name, meta.name);
            if (dist <= 3 and count < buffer.len) { // Maximum edit distance of 3 for suggestions
                buffer[count] = .{ .cmd = meta.name, .dist = dist };
                count += 1;
            }

            // Check aliases
            for (meta.aliases) |alias| {
                const alias_dist = levenshtein(name, alias);
                if (alias_dist <= 3 and count < buffer.len) {
                    buffer[count] = .{ .cmd = alias, .dist = alias_dist };
                    count += 1;
                }
            }
        }

        // Sort by distance
        std.sort.insertion(DistEntry, buffer[0..count], {}, struct {
            pub fn lessThan(_: void, a: DistEntry, b: DistEntry) bool {
                return a.dist < b.dist;
            }
        }.lessThan);

        // Extract top results
        const result_count = @min(max_results, count);
        const result = try self.allocator.alloc([]const u8, result_count);
        for (0..result_count) |i| {
            result[i] = buffer[i].cmd;
        }

        return result;
    }

    /// Count commands per category
    pub fn countByCategory(self: *const Self) ![11]usize {
        const counts = [_]CommandCategory{ .ai, .dev, .git, .math, .science, .sacred, .system, .demo, .benchmark, .advanced, .depin };
        var result: [11]usize = undefined;

        for (counts, 0..) |cat, i| {
            var count: usize = 0;
            for (self.metadata_storage.items) |meta| {
                if (meta.category == cat) count += 1;
            }
            result[i] = count;
        }

        return result;
    }
};

/// Levenshtein distance algorithm for fuzzy string matching
pub fn levenshtein(a: []const u8, b: []const u8) usize {
    const m = a.len;
    const n = b.len;

    // Handle empty strings
    if (m == 0) return n;
    if (n == 0) return m;

    // Use a single row for space efficiency
    var prev_row = std.ArrayList(usize).init(std.heap.page_allocator);
    defer prev_row.deinit();
    prev_row.appendAssumeCapacity(n + 1);
    for (0..n + 1) |i| {
        prev_row.items[i] = i;
    }

    for (a, 0..) |ch_a, i| {
        var curr_row = std.ArrayList(usize).init(std.heap.page_allocator);
        defer curr_row.deinit();
        curr_row.appendAssumeCapacity(n + 1);
        curr_row.items[0] = i + 1;

        for (b, 0..) |ch_b, j| {
            const cost = if (ch_a == ch_b) 0 else 1;
            const delete = prev_row.items[j + 1] + 1;
            const insert = curr_row.items[j] + 1;
            const substitute = prev_row.items[j] + cost;

            const min_val = @min(delete, @min(insert, substitute));
            curr_row.items[j + 1] = min_val;
        }

        prev_row.shrinkRetainingCapacity(0);
        prev_row.appendSliceAssumeCapacity(curr_row.items);
    }

    return prev_row.items[n];
}
