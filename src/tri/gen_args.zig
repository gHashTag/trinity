//! TRI Args — Generated from specs/tri/tri_args.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Single argument definition
pub const Arg = struct {
    name: []const u8,
    short: ?u8,
    long: ?[]const u8,
    description: []const u8,
    required: bool,
};

/// Parsed argument value
pub const ArgValue = struct {
    name: []const u8,
    value: ?[]const u8,
    present: bool,
};

/// Result of argument parsing
pub const ParseResult = struct {
    positional: []const []const u8,
    named: []const ArgValue,
    err_msg: ?[]const u8,

    pub fn deinit(self: *ParseResult, allocator: std.mem.Allocator) void {
        allocator.free(self.positional);
        for (self.named) |*nv| {
            if (nv.value) |v| {
                allocator.free(v);
            }
            allocator.free(nv.name);
        }
        allocator.free(self.named);
        if (self.err_msg) |msg| {
            allocator.free(msg);
        }
        self.* = undefined;
    }

    pub fn deinitConst(self: *const ParseResult, allocator: std.mem.Allocator) void {
        // Cast away const for cleanup
        @as(*ParseResult, @constCast(self)).deinit(allocator);
    }
};

// ============================================================================
// INTERNAL STATE
// ============================================================================

const ArgMap = std.StringHashMap(ArgValue);

// ============================================================================
// PARSING FUNCTIONS
// ============================================================================

/// Parse command-line arguments
pub fn parse(allocator: std.mem.Allocator, args: []const []const u8, spec: []const Arg) !ParseResult {
    // Count positional arguments (everything after -- or doesn't start with -)
    var pos_count: usize = 0;
    var after_double_dash: bool = false;
    for (args[1..]) |arg| {
        if (!after_double_dash and std.mem.eql(u8, arg, "--")) {
            after_double_dash = true;
        } else if (after_double_dash or !std.mem.startsWith(u8, arg, "-")) {
            pos_count += 1;
        }
    }

    // Allocate positional array
    var positional_idx: usize = 0;
    const positional = try allocator.alloc([]const u8, pos_count);

    var arg_map = ArgMap.init(allocator);
    defer {
        var it = arg_map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.value) |v| {
                allocator.free(v);
            }
        }
        arg_map.deinit();
    }

    var i: usize = 1; // Skip program name
    var double_dash: bool = false;

    while (i < args.len) {
        const arg = args[i];

        if (!double_dash and std.mem.eql(u8, arg, "--")) {
            double_dash = true;
            i += 1;
            continue;
        }

        if (!double_dash and std.mem.startsWith(u8, arg, "--")) {
            // Long option
            const opt_name = arg[2..];
            const eq_idx = std.mem.indexOf(u8, opt_name, "=");

            if (eq_idx) |idx| {
                // --name=value format
                const name = opt_name[0..idx];
                const value = opt_name[idx + 1 ..];
                try storeArg(allocator, &arg_map, name, value, spec);
            } else {
                // --name value format
                const name = opt_name;
                // Check if this is a flag or expects a value
                const expects_value = argExpectsValue(name, spec);
                if (expects_value and i + 1 < args.len) {
                    const value = args[i + 1];
                    if (!std.mem.startsWith(u8, value, "-")) {
                        try storeArg(allocator, &arg_map, name, value, spec);
                        i += 2;
                        continue;
                    }
                }
                try storeArg(allocator, &arg_map, name, null, spec);
                i += 1;
                continue;
            }
        } else if (!double_dash and std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            // Short option(s)
            const opts = arg[1..];
            if (opts.len == 1) {
                // Single short option
                const name = opts[0..1];
                const expects_value = argExpectsValueShort(name[0], spec);
                if (expects_value and i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                    try storeArgShort(allocator, &arg_map, name[0], args[i + 1], spec);
                    i += 2;
                    continue;
                }
                try storeArgShort(allocator, &arg_map, name[0], null, spec);
            } else {
                // Multiple short options (treated as flags)
                for (opts) |c| {
                    try storeArgShort(allocator, &arg_map, c, null, spec);
                }
            }
        } else {
            // Positional argument
            positional[positional_idx] = arg;
            positional_idx += 1;
        }

        i += 1;
    }

    // Convert map to result arrays
    const named_count = arg_map.count();
    var named_idx: usize = 0;
    const named = try allocator.alloc(ArgValue, named_count);

    var it = arg_map.iterator();
    while (it.next()) |entry| {
        const name_copy = try allocator.dupe(u8, entry.key_ptr.*);
        const value_copy = if (entry.value_ptr.value) |v|
            try allocator.dupe(u8, v)
        else
            null;
        named[named_idx] = ArgValue{
            .name = name_copy,
            .value = value_copy,
            .present = entry.value_ptr.present,
        };
        named_idx += 1;
    }

    // Check required arguments
    for (spec) |arg_def| {
        if (arg_def.required) {
            const found = if (arg_def.long) |long|
                arg_map.get(long) != null
            else if (arg_def.short) |s|
                hasKeyShort(&arg_map, s)
            else
                false;

            if (!found) {
                // Return error result
                const err_msg = try std.fmt.allocPrint(allocator, "Missing required argument: {s}", .{arg_def.name});
                return ParseResult{
                    .positional = positional,
                    .named = named,
                    .err_msg = err_msg,
                };
            }
        }
    }

    return ParseResult{
        .positional = positional,
        .named = named,
        .err_msg = null,
    };
}

/// Store an argument in the map
fn storeArg(allocator: std.mem.Allocator, map: *ArgMap, name: []const u8, value: ?[]const u8, spec: []const Arg) !void {
    _ = spec; // Unused in this simplified version
    const key = try allocator.dupe(u8, name);
    errdefer allocator.free(key);

    const value_copy = if (value) |v|
        try allocator.dupe(u8, v)
    else
        null;
    errdefer {
        if (value_copy) |v| allocator.free(v);
    }

    try map.put(key, ArgValue{
        .name = key,
        .value = value_copy,
        .present = true,
    });
}

/// Store a short argument in the map
fn storeArgShort(allocator: std.mem.Allocator, map: *ArgMap, short: u8, value: ?[]const u8, spec: []const Arg) !void {
    _ = spec; // Unused in this simplified version
    var name_buf: [2]u8 = undefined;
    name_buf[0] = short;
    name_buf[1] = 0;
    const name = name_buf[0..1];

    const key = try allocator.dupe(u8, name);
    errdefer allocator.free(key);

    const value_copy = if (value) |v|
        try allocator.dupe(u8, v)
    else
        null;
    errdefer {
        if (value_copy) |v| allocator.free(v);
    }

    try map.put(key, ArgValue{
        .name = key,
        .value = value_copy,
        .present = true,
    });
}

/// Check if argument expects a value
fn argExpectsValue(name: []const u8, spec: []const Arg) bool {
    for (spec) |arg| {
        if (arg.long) |long| {
            if (std.mem.eql(u8, long, name)) {
                // If it has a short form, it likely expects a value
                return arg.short != null;
            }
        }
    }
    return false;
}

/// Check if short argument expects a value
fn argExpectsValueShort(short: u8, spec: []const Arg) bool {
    for (spec) |arg| {
        if (arg.short) |s| {
            if (s == short) {
                return arg.long != null;
            }
        }
    }
    return false;
}

/// Check if map has a short key
fn hasKeyShort(map: *ArgMap, short: u8) bool {
    var name_buf: [2]u8 = undefined;
    name_buf[0] = short;
    name_buf[1] = 0;
    return map.get(name_buf[0..1]) != null;
}

// ============================================================================
// QUERY FUNCTIONS
// ============================================================================

/// Check if flag was present
pub fn hasFlag(result: ParseResult, name: []const u8) bool {
    for (result.named) |nv| {
        if (std.mem.eql(u8, nv.name, name)) {
            return nv.present;
        }
    }
    return false;
}

/// Get value for named argument
pub fn getValue(result: ParseResult, name: []const u8) ?[]const u8 {
    for (result.named) |nv| {
        if (std.mem.eql(u8, nv.name, name)) {
            return nv.value;
        }
    }
    return null;
}

/// Get positional argument by index
pub fn getPositional(result: ParseResult, index: usize) ?[]const u8 {
    if (index >= result.positional.len) return null;
    return result.positional[index];
}

// ============================================================================
// TESTS
// ============================================================================

test "Args: parse positional only" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "program", "arg1", "arg2" };
    const spec = [_]Arg{};

    const result = try parse(allocator, &args, &spec);
    defer result.deinitConst(allocator);

    try std.testing.expectEqual(@as(usize, 2), result.positional.len);
    try std.testing.expectEqualStrings("arg1", result.positional[0]);
    try std.testing.expectEqualStrings("arg2", result.positional[1]);
}

test "Args: parse short flag" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "program", "-v" };
    const spec = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .description = "Verbose", .required = false },
    };

    const result = try parse(allocator, &args, &spec);
    defer result.deinitConst(allocator);

    try std.testing.expect(hasFlag(result, "v"));
}

test "Args: parse long option with value" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "program", "--output", "file.txt" };
    const spec = [_]Arg{
        .{ .name = "output", .short = 'o', .long = "output", .description = "Output", .required = false },
    };

    const result = try parse(allocator, &args, &spec);
    defer result.deinitConst(allocator);

    const value = getValue(result, "output");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("file.txt", value.?);
}

test "Args: parse long option with equals" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "program", "--output=file.txt" };
    const spec = [_]Arg{
        .{ .name = "output", .short = 'o', .long = "output", .description = "Output", .required = false },
    };

    const result = try parse(allocator, &args, &spec);
    defer result.deinitConst(allocator);

    const value = getValue(result, "output");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("file.txt", value.?);
}

test "Args: getPositional" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "program", "pos1", "pos2" };
    const spec = [_]Arg{};

    const result = try parse(allocator, &args, &spec);
    defer result.deinitConst(allocator);

    try std.testing.expectEqualStrings("pos1", getPositional(result, 0).?);
    try std.testing.expectEqualStrings("pos2", getPositional(result, 1).?);
    try std.testing.expect(getPositional(result, 2) == null);
}

test "Args: double dash separator" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "program", "--verbose", "--", "-v", "positional" };
    const spec = [_]Arg{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .description = "Verbose", .required = false },
    };

    const result = try parse(allocator, &args, &spec);
    defer result.deinitConst(allocator);

    try std.testing.expect(hasFlag(result, "verbose")); // Long option stored by long name
    try std.testing.expectEqual(@as(usize, 2), result.positional.len);
    try std.testing.expectEqualStrings("-v", result.positional[0]);
    try std.testing.expectEqualStrings("positional", result.positional[1]);
}
