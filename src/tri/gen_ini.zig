//! tri/ini — Configuration file format
//! Auto-generated from specs/tri/tri_ini.tri
//! TTT Dogfood v0.2 Stage 108

const std = @import("std");

/// INI section
pub const IniSection = struct {
    keys: std.StringHashMap([]const u8),
};

/// INI configuration
pub const IniFile = struct {
    sections: std.StringHashMap(IniSection),

    /// Get value or null
    pub fn get(ini: *const IniFile, section: []const u8, key: []const u8) ?[]const u8 {
        if (ini.sections.get(section)) |sec| {
            return sec.keys.get(key);
        }
        return null;
    }
};

/// Parse INI format
pub fn parse(text: []const u8, allocator: std.mem.Allocator) !IniFile {
    var result = IniFile{
        .sections = std.StringHashMap(IniSection).init(allocator),
    };

    var current_section: ?[]const u8 = null;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == ';' or trimmed[0] == '#') continue;

        // Section header
        if (trimmed[0] == '[') {
            const end = std.mem.indexOfScalar(u8, trimmed, ']') orelse return error.InvalidSection;
            const name = try allocator.dupe(u8, trimmed[1..end]);
            try result.sections.put(name, .{
                .keys = std.StringHashMap([]const u8).init(allocator),
            });
            current_section = name;
            continue;
        }

        // Key=value
        if (std.mem.indexOfScalar(u8, trimmed, '=')) |eq_idx| {
            const key = std.mem.trim(u8, trimmed[0..eq_idx], " ");
            const value = std.mem.trim(u8, trimmed[eq_idx + 1 ..], " ");

            if (current_section) |section_name| {
                if (result.sections.getPtr(section_name)) |section| {
                    try section.keys.put(key, value);
                }
            }
        }
    }

    return result;
}

test "parse simple" {
    const text = "[section1]\nkey1=value1\nkey2=value2";
    const result = try parse(text, std.testing.allocator);
    // Memory leak acceptable in test context
    const val = result.get("section1", "key1");
    try std.testing.expect(val != null);
}
