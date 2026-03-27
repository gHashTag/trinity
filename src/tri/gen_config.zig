//! TRI Config — Generated from specs/tri/tri_config.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

/// Configuration value (string, number, bool, or null)
pub const ConfigValue = struct {
    string: ?[]const u8,
    number: ?f64,
    boolean: ?bool,
    is_null: bool,

    pub fn deinit(self: *ConfigValue, allocator: std.mem.Allocator) void {
        if (self.string) |s| {
            allocator.free(s);
        }
        self.* = undefined;
    }
};

/// Single configuration key-value pair
pub const ConfigEntry = struct {
    key: []const u8,
    value: ConfigValue,

    pub fn deinit(self: *ConfigEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        self.value.deinit(allocator);
    }
};

/// Configuration container
pub const Config = struct {
    entries: []ConfigEntry,
    err_msg: ?[]const u8,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        for (self.entries) |*entry| {
            entry.deinit(allocator);
        }
        allocator.free(self.entries);
        if (self.err_msg) |msg| {
            allocator.free(msg);
        }
        self.* = undefined;
    }

    pub fn deinitConst(self: *const Config, allocator: std.mem.Allocator) void {
        @as(*Config, @constCast(self)).deinit(allocator);
    }
};

// ============================================================================
// PARSING
// ============================================================================

/// Parse simple key=value config format
pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Config {
    // First pass: count non-empty, non-comment lines
    var line_count: usize = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 0 and trimmed[0] != '#') {
            line_count += 1;
        }
    }

    // Allocate entries array
    var entries_idx: usize = 0;
    const entries = try allocator.alloc(ConfigEntry, line_count);

    // Second pass: parse entries
    lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");

        // Skip empty lines and comments
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Parse key=value
        const eq_idx = std.mem.indexOfScalar(u8, trimmed, '=') orelse {
            const err_msg = try std.fmt.allocPrint(allocator, "Missing '=' in line", .{});
            return Config{
                .entries = entries[0..entries_idx],
                .err_msg = err_msg,
            };
        };

        const key = std.mem.trim(u8, trimmed[0..eq_idx], " \t");
        const val_str = std.mem.trim(u8, trimmed[eq_idx + 1 ..], " \t");

        if (key.len == 0) {
            const err_msg = try std.fmt.allocPrint(allocator, "Empty key in line", .{});
            return Config{
                .entries = entries[0..entries_idx],
                .err_msg = err_msg,
            };
        }

        // Parse value
        const value = try parseValue(allocator, val_str);

        const key_copy = try allocator.dupe(u8, key);
        errdefer allocator.free(key_copy);

        entries[entries_idx] = ConfigEntry{
            .key = key_copy,
            .value = value,
        };
        entries_idx += 1;
    }

    return Config{
        .entries = entries[0..entries_idx],
        .err_msg = null,
    };
}

/// Parse a configuration value
fn parseValue(allocator: std.mem.Allocator, s: []const u8) !ConfigValue {
    if (s.len == 0) {
        return ConfigValue{
            .string = null,
            .number = null,
            .boolean = null,
            .is_null = true,
        };
    }

    // Check for boolean
    if (std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "yes") or std.mem.eql(u8, s, "on")) {
        return ConfigValue{
            .string = null,
            .number = null,
            .boolean = true,
            .is_null = false,
        };
    }
    if (std.mem.eql(u8, s, "false") or std.mem.eql(u8, s, "no") or std.mem.eql(u8, s, "off")) {
        return ConfigValue{
            .string = null,
            .number = null,
            .boolean = false,
            .is_null = false,
        };
    }

    // Check for quoted string
    if (s[0] == '"' or s[0] == '\'') {
        const quote = s[0];
        if (s.len >= 2 and s[s.len - 1] == quote) {
            const unquoted = s[1 .. s.len - 1];
            const str_copy = try allocator.dupe(u8, unquoted);
            return ConfigValue{
                .string = str_copy,
                .number = null,
                .boolean = null,
                .is_null = false,
            };
        }
    }

    // Check for number
    if (std.fmt.parseFloat(f64, s)) |num| {
        return ConfigValue{
            .string = null,
            .number = num,
            .boolean = null,
            .is_null = false,
        };
    } else |_| {}

    // Default: treat as string
    const str_copy = try allocator.dupe(u8, s);
    return ConfigValue{
        .string = str_copy,
        .number = null,
        .boolean = null,
        .is_null = false,
    };
}

// ============================================================================
// GETTERS
// ============================================================================

/// Find entry by key
fn findEntry(config: Config, key: []const u8) ?*const ConfigEntry {
    for (config.entries) |*entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            return entry;
        }
    }
    return null;
}

/// Get string value with default
pub fn getString(config: Config, key: []const u8, default: []const u8) []const u8 {
    if (findEntry(config, key)) |entry| {
        if (entry.value.string) |s| return s;
        if (entry.value.is_null) return default;
        // Convert to string
        if (entry.value.number != null) {
            // This is a simplified approach - in real code, allocate and format
            return default;
        }
        if (entry.value.boolean) |b| {
            return if (b) "true" else "false";
        }
    }
    return default;
}

/// Get number value with default
pub fn getNumber(config: Config, key: []const u8, default: f64) f64 {
    if (findEntry(config, key)) |entry| {
        if (entry.value.number) |n| return n;
        if (entry.value.boolean) |b| return if (b) 1.0 else 0.0;
    }
    return default;
}

/// Get boolean value with default
pub fn getBool(config: Config, key: []const u8, default: bool) bool {
    if (findEntry(config, key)) |entry| {
        if (entry.value.boolean) |b| return b;
        if (entry.value.number) |n| return n != 0.0;
        if (entry.value.string) |s| {
            if (s.len > 0) return true;
        }
    }
    return default;
}

// ============================================================================
// TESTS
// ============================================================================

test "Config: parse simple" {
    const allocator = std.testing.allocator;
    const content = "name=value\nnumber=42";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqual(@as(usize, 2), config.entries.len);
    try std.testing.expectEqualStrings("name", config.entries[0].key);
    try std.testing.expect(config.entries[0].value.string != null);
}

test "Config: parse comments" {
    const allocator = std.testing.allocator;
    const content = "# Comment\nname=value\n# Another comment";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqual(@as(usize, 1), config.entries.len);
}

test "Config: parse boolean" {
    const allocator = std.testing.allocator;
    const content = "flag1=true\nflag2=false\nflag3=yes\nflag4=no";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqual(@as(usize, 4), config.entries.len);
    try std.testing.expect(config.entries[0].value.boolean.? == true);
    try std.testing.expect(config.entries[1].value.boolean.? == false);
}

test "Config: parse number" {
    const allocator = std.testing.allocator;
    const content = "count=42\npi=3.14\nnegative=-10";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqual(@as(f64, 42), config.entries[0].value.number.?);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), config.entries[1].value.number.?, 0.001);
    try std.testing.expectEqual(@as(f64, -10), config.entries[2].value.number.?);
}

test "Config: parse quoted string" {
    const allocator = std.testing.allocator;
    const content = "name=\"John Doe\"\ndesc='simple'";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqualStrings("John Doe", config.entries[0].value.string.?);
    try std.testing.expectEqualStrings("simple", config.entries[1].value.string.?);
}

test "Config: getString" {
    const allocator = std.testing.allocator;
    const content = "name=value\nempty=";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqualStrings("value", getString(config, "name", "default"));
    try std.testing.expectEqualStrings("default", getString(config, "missing", "default"));
}

test "Config: getNumber" {
    const allocator = std.testing.allocator;
    const content = "count=42";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expectEqual(@as(f64, 42), getNumber(config, "count", 0));
    try std.testing.expectEqual(@as(f64, 99), getNumber(config, "missing", 99));
}

test "Config: getBool" {
    const allocator = std.testing.allocator;
    const content = "flag=true\nother=false";

    const config = try parse(allocator, content);
    defer config.deinitConst(allocator);

    try std.testing.expect(getBool(config, "flag", false) == true);
    try std.testing.expect(getBool(config, "other", true) == false);
    try std.testing.expect(getBool(config, "missing", true) == true);
}
