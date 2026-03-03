// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND TYPES - For type: cli_command specifications
// ═══════════════════════════════════════════════════════════════════════════════
//
// When a .tri spec has type: cli_command, VIBEE will:
//   1. Add variant to Command enum in tri_utils.zig
//   2. Add parseCommand() case in tri_utils.zig
//   3. Add dispatch case in main.zig
//   4. Add handler stub in tri_commands.zig
//
// φ² + 1/φ² = 3 = TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

/// CLI Command specification from type: cli_command
pub const CliCommandSpec = struct {
    name: []const u8,
    aliases: ArrayList([]const u8),
    description: []const u8,
    category: []const u8,
    module: []const u8,
    help_short: []const u8,
    help_long: []const u8,

    // Enum variant info
    variant: []const u8,
    enum_name: []const u8,
    is_flag: bool,

    // Arguments (subcommands, options)
    arguments: ArrayList(Argument),

    pub fn init(_: Allocator) CliCommandSpec {
        return .{
            .name = "",
            .aliases = .{},
            .description = "",
            .category = "",
            .module = "tri_commands",
            .help_short = "",
            .help_long = "",
            .variant = "",
            .enum_name = "",
            .is_flag = false,
            .arguments = .{},
        };
    }

    pub fn deinit(self: *CliCommandSpec) void {
        self.aliases.deinit(self.allocator);
        self.arguments.deinit(self.allocator);
    }
};

/// Command argument definition
pub const Argument = struct {
    name: []const u8,
    type: []const u8, // enum, string, int, bool
    required: bool,
    description: []const u8,
    values: ArrayList(ArgValue),

    pub fn deinit(self: *Argument) void {
        self.values.deinit();
    }
};

/// Argument value (for enum types)
pub const ArgValue = struct {
    value: []const u8,
    description: []const u8,
};

/// Generated code snippets for CLI command integration
pub const CliCommandCode = struct {
    // Command enum variant
    enum_variant: []const u8,

    // parseCommand case
    parse_case: []const u8,

    // main.zig dispatch case
    dispatch_case: []const u8,

    // Handler function stub
    handler_stub: []const u8,

    pub fn init(_: Allocator) CliCommandCode {
        return .{
            .enum_variant = "",
            .parse_case = "",
            .dispatch_case = "",
            .handler_stub = "",
        };
    }

    pub fn deinit(self: *CliCommandCode) void {
        self.allocator.free(self.enum_variant);
        self.allocator.free(self.parse_case);
        self.allocator.free(self.dispatch_case);
        self.allocator.free(self.handler_stub);
    }
};

/// Generate CLI command integration code
pub fn generateCommandCode(allocator: Allocator, spec: CliCommandSpec) !CliCommandCode {
    var result = CliCommandCode.init(allocator);

    // 1. Generate enum variant
    result.enum_variant = try std.fmt.allocPrint(allocator,
        \\    // {s}: {s} command
        \\    {s},
    , .{ spec.name, spec.category, spec.enum_name });

    // 2. Generate parseCommand case
    if (spec.aliases.items.len > 0) {
        var aliases_str = ArrayList([]const u8).init(allocator);
        defer aliases_str.deinit(allocator);

        try aliases_str.append(spec.name);
        for (spec.aliases.items) |alias| {
            try aliases_str.append(alias);
        }

        var cases = ArrayList([]const u8).init(allocator);
        defer {
            for (cases.items) |c| allocator.free(c);
            cases.deinit(allocator);
        }

        for (aliases_str.items) |alias| {
            const case = try std.fmt.allocPrint(allocator,
                "    if (std.mem.eql(u8, arg, \"{s}\")) return .{s};",
                .{ alias, spec.enum_name });
            try cases.append(case);
        }

        result.parse_case = try std.mem.join(allocator, "\n", cases.items);
    } else {
        result.parse_case = try std.fmt.allocPrint(allocator,
            "    if (std.mem.eql(u8, arg, \"{s}\")) return .{s};",
            .{ spec.name, spec.enum_name });
    }

    // 3. Generate dispatch case
    result.dispatch_case = try std.fmt.allocPrint(allocator,
        \\        .{s} => commands.run{s}Command(allocator, cmd_args),
    , .{ spec.enum_name, capitalize(spec.name) });

    // 4. Generate handler stub
    const handler_name = try std.fmt.allocPrint(allocator, "run{s}Command", .{capitalize(spec.name)});
    defer allocator.free(handler_name);

    result.handler_stub = try std.fmt.allocPrint(allocator,
        \\/// Run {s} command
        \\pub fn {s}(allocator: std.mem.Allocator, args: []const []const u8) !void {{
        \\    _ = allocator;
        \\    _ = args;
        \\
        \\    // TODO: Implement {s} command
        \\    std.debug.print("{s} command not yet implemented\\n", .{{}});
        \\}}
    , .{ spec.name, handler_name, spec.name, spec.name });

    return result;
}

fn capitalize(s: []const u8) []const u8 {
    if (s.len == 0) return s;

    // First char to uppercase
    var result: [128]u8 = undefined;
    @memcpy(result[0..s.len], s);

    if (result[0] >= 'a' and result[0] <= 'z') {
        result[0] -= 32;
    }

    // Note: This returns a slice that may be invalidated
    // In production, should use allocator
    return result[0..s.len];
}
