// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND PATCHER - Integrates generated CLI commands into TRI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Reads type: cli_command specs and patches:
//   - src/tri/tri_utils.zig (Command enum, parseCommand)
//   - src/tri/main.zig (dispatch cases)
//
// φ² + 1/φ² = 3 = TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

pub const CliPatcher = struct {
    allocator: Allocator,
    tri_utils_path: []const u8,
    main_zig_path: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .tri_utils_path = "src/tri/tri_utils.zig",
            .main_zig_path = "src/tri/main.zig",
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Apply all CLI command patches
    pub fn apply(self: *Self, commands: []const CliCommand) !void {
        // Patch tri_utils.zig
        try self.patchTriUtils(commands);

        // Patch main.zig
        try self.patchMainZig(commands);
    }

    /// Patch Command enum and parseCommand in tri_utils.zig
    fn patchTriUtils(self: *Self, commands: []const CliCommand) !void {
        const content = try std.fs.cwd().readFileAlloc(self.allocator, self.tri_utils_path, 10_000_000);
        defer self.allocator.free(content);

        var lines = ArrayList([]const u8).init(self.allocator);
        defer {
            for (lines.items) |line| self.allocator.free(line);
            lines.deinit(self.allocator);
        }

        var iter = std.mem.tokenizeScalar(u8, content);
        while (iter.next()) |line| {
            try lines.append(try self.allocator.dupe(u8, line));
        }

        // Find Command enum and add variants
        var enum_found = false;
        var enum_end_line: usize = 0;
        var i: usize = 0;
        while (i < lines.items.len) : (i += 1) {
            if (std.mem.indexOf(u8, lines.items[i], "pub const Command = enum")) |_| {
                enum_found = true;
                // Find enum end
                var j = i + 1;
                while (j < lines.items.len) : (j += 1) {
                    if (lines.items[j][0] == '}') {
                        enum_end_line = j;
                        break;
                    }
                }
                break;
            }
        }

        if (!enum_found) {
            std.debug.print("ERROR: Command enum not found in {s}\n", .{self.tri_utils_path});
            return error.CommandEnumNotFound;
        }

        // Insert enum variants before closing brace
        for (commands) |cmd| {
            const variant_line = try std.fmt.allocPrint(self.allocator, "    {s},", .{cmd.enum_name});
            try lines.insert(enum_end_line, variant_line);
            enum_end_line += 1;
        }
        enum_end_line += 1;

        // Find parseCommand function
        var parse_found = false;
        var parse_end_line: usize = 0;
        i = 0;
        while (i < lines.items.len) : (i += 1) {
            if (std.mem.indexOf(u8, lines.items[i], "pub fn parseCommand(arg: []const u8) Command")) |_| {
                parse_found = true;
                // Find function end (first closing brace at start of line)
                var j = i + 1;
                while (j < lines.items.len) : (j += 1) {
                    const line = lines.items[j];
                    if (line.len > 0 and line[0] == '}' and
                        (std.mem.indexOf(u8, line, "fn") == null and
                         std.mem.indexOf(u8, line, "const") == null and
                         std.mem.indexOf(u8, line, "pub") == null)) {
                        parse_end_line = j;
                        break;
                    }
                }
                break;
            }
        }

        if (!parse_found) {
            std.debug.print("ERROR: parseCommand not found in {s}\n", .{self.tri_utils_path});
            return error.ParseCommandNotFound;
        }

        // Insert parseCommand cases before closing brace
        for (commands) |cmd| {
            const parse_case = try std.fmt.allocPrint(self.allocator,
                "    if (std.mem.eql(u8, arg, \"{s}\")) return .{s};",
                .{ cmd.name, cmd.enum_name });
            try lines.insert(parse_end_line, parse_case);
            parse_end_line += 1;

            // Add aliases
            for (cmd.aliases) |alias| {
                const alias_case = try std.fmt.allocPrint(self.allocator,
                    "    if (std.mem.eql(u8, arg, \"{s}\")) return .{s};",
                    .{ alias, cmd.enum_name });
                try lines.insert(parse_end_line, alias_case);
                parse_end_line += 1;
            }
        }

        // Write patched content
        const output = try std.mem.join(self.allocator, "\n", lines.items);
        defer self.allocator.free(output);

        const file = try std.fs.cwd().createFile(self.tri_utils_path, .{});
        defer file.close();
        try file.writeAll(output);
    }

    /// Patch dispatch cases in main.zig
    fn patchMainZig(self: *Self, commands: []const CliCommand) !void {
        const content = try std.fs.cwd().readFileAlloc(self.allocator, self.main_zig_path, 10_000_000);
        defer self.allocator.free(content);

        var lines = ArrayList([]const u8).init(self.allocator);
        defer {
            for (lines.items) |line| self.allocator.free(line);
            lines.deinit(self.allocator);
        }

        var iter = std.mem.tokenizeScalar(u8, content);
        while (iter.next()) |line| {
            try lines.append(try self.allocator.dupe(u8, line));
        }

        // Find the switch statement for Command enum
        var switch_found = false;
        var switch_end_line: usize = 0;
        var i: usize = 0;
        while (i < lines.items.len) : (i += 1) {
            if (std.mem.indexOf(u8, lines.items[i], "switch (cmd)") |_| {
                switch_found = true;
                // Find switch end
                var j = i + 1;
                var depth: usize = 1;
                while (j < lines.items.len and depth > 0) : (j += 1) {
                    if (std.mem.indexOf(u8, lines.items[j], "switch") != null) depth += 1;
                    if (lines.items[j][0] == '}') depth -= 1;
                    if (depth == 0) {
                        switch_end_line = j;
                        break;
                    }
                }
                break;
            }
        }

        if (!switch_found) {
            std.debug.print("ERROR: Command switch not found in {s}\n", .{self.main_zig_path});
            return error.CommandSwitchNotFound;
        }

        // Find the position before the closing brace
        // Insert before the last few cases (none, chat, etc.)
        var insert_line: usize = switch_end_line;
        var j = switch_end_line - 1;
        while (j > 0) : (j -= 1) {
            const line = std.mem.trim(u8, lines.items[j], " ");
            if (line.len > 0 and line[0] != '.' and line[0] != '}') {
                insert_line = j + 1;
                break;
            }
        }

        // Insert dispatch cases
        for (commands) |cmd| {
            const dispatch_case = try std.fmt.allocPrint(self.allocator,
                "        .{s} => commands.run{s}Command(allocator, cmd_args),",
                .{ cmd.enum_name, capitalize(cmd.name) });
            try lines.insert(insert_line, dispatch_case);
            insert_line += 1;
        }

        // Write patched content
        const output = try std.mem.join(self.allocator, "\n", lines.items);
        defer self.allocator.free(output);

        const file = try std.fs.cwd().createFile(self.main_zig_path, .{});
        defer file.close();
        try file.writeAll(output);
    }
};

pub const CliCommand = struct {
    name: []const u8,
    enum_name: []const u8,
    aliases: []const []const u8,
};

fn capitalize(s: []const u8) []const u8 {
    if (s.len == 0) return s;

    var result: [128]u8 = undefined;
    @memcpy(result[0..s.len], s);

    if (result[0] >= 'a' and result[0] <= 'z') {
        result[0] -= 32;
    }

    return result[0..s.len];
}
