// permissions.zig — Tool permission system for tri-api
// deny > allow, project overrides user. Same model as Claude Code.
// Issue #65: Phase 6 permissions + checkpoints
const std = @import("std");
const proto = @import("tool_protocol.zig");

const user_settings = ".tri-api/settings.json";
const project_settings = ".tri-api/settings.json";
const max_rules = 64;

pub const Permission = enum { allow, deny };

pub const PermissionConfig = struct {
    allow_rules: std.ArrayList(Rule),
    deny_rules: std.ArrayList(Rule),

    pub fn deinit(self: *PermissionConfig, allocator: std.mem.Allocator) void {
        self.allow_rules.deinit(allocator);
        self.deny_rules.deinit(allocator);
    }

    /// Check if a tool invocation is permitted. deny wins over allow.
    /// Returns .deny if any deny rule matches, .allow if any allow rule matches,
    /// otherwise defaults: read_file/grep → allow, bash/write_file → deny.
    pub fn check(self: *const PermissionConfig, tool: []const u8, arg: []const u8) Permission {
        // 1. deny rules take priority
        for (self.deny_rules.items) |rule| {
            if (ruleMatches(rule, tool, arg)) return .deny;
        }
        // 2. allow rules
        for (self.allow_rules.items) |rule| {
            if (ruleMatches(rule, tool, arg)) return .allow;
        }
        // 3. defaults: read-only tools are allowed, write/bash are denied
        if (std.mem.eql(u8, tool, "read_file") or std.mem.eql(u8, tool, "grep")) {
            return .allow;
        }
        return .deny;
    }
};

const Rule = struct {
    tool: []const u8, // "bash", "write_file", etc.
    pattern: []const u8, // glob-like: "*", "git diff *", ".env"
};

/// Check if a rule matches a tool+arg pair.
/// Pattern matching: "*" matches everything, "prefix*" matches prefix, exact otherwise.
fn ruleMatches(rule: Rule, tool: []const u8, arg: []const u8) bool {
    if (!std.mem.eql(u8, rule.tool, tool)) return false;

    const pat = rule.pattern;
    if (pat.len == 0 or std.mem.eql(u8, pat, "*")) return true;

    // "prefix*" — startsWith match
    if (pat[pat.len - 1] == '*') {
        const prefix = pat[0 .. pat.len - 1];
        return arg.len >= prefix.len and std.mem.eql(u8, arg[0..prefix.len], prefix);
    }

    // Exact match
    return std.mem.eql(u8, arg, pat);
}

/// Load permission config. Project settings override user settings.
/// Format: {"permissions":{"allow":["bash(git diff *)","read_file(*)"],"deny":["bash(rm -rf *)"]}}
pub fn loadConfig(allocator: std.mem.Allocator) PermissionConfig {
    var config = PermissionConfig{
        .allow_rules = std.ArrayList(Rule).empty,
        .deny_rules = std.ArrayList(Rule).empty,
    };

    // Try user settings first (~/.tri-api/settings.json)
    const home = std.posix.getenv("HOME") orelse "";
    if (home.len > 0) {
        var user_path_buf: [512]u8 = undefined;
        if (std.fmt.bufPrint(&user_path_buf, "{s}/{s}", .{ home, user_settings })) |user_path| {
            loadFromFile(allocator, &config, user_path);
        } else |_| {}
    }

    // Project settings override (.tri-api/settings.json in cwd)
    loadFromFile(allocator, &config, project_settings);

    return config;
}

/// Parse a settings file and add rules to config.
fn loadFromFile(allocator: std.mem.Allocator, config: *PermissionConfig, path: []const u8) void {
    const content = readFile(allocator, path) catch return;
    defer allocator.free(content);

    // Parse "allow":[...] array
    parseRuleArray(allocator, content, "allow", &config.allow_rules);
    // Parse "deny":[...] array
    parseRuleArray(allocator, content, "deny", &config.deny_rules);
}

/// Parse a JSON array of rule strings: "tool(pattern)"
fn parseRuleArray(allocator: std.mem.Allocator, data: []const u8, key: []const u8, rules: *std.ArrayList(Rule)) void {
    // Find "key":[ in the JSON
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":[", .{key}) catch return;

    const idx = std.mem.indexOf(u8, data, needle) orelse return;
    var pos = idx + needle.len;

    // Scan for quoted strings until ]
    while (pos < data.len and data[pos] != ']') {
        // Find next quoted string
        if (std.mem.indexOfPos(u8, data, pos, "\"")) |q_start| {
            if (q_start >= data.len) break;
            const str_start = q_start + 1;
            var str_end = str_start;
            while (str_end < data.len and data[str_end] != '"') : (str_end += 1) {}

            if (str_end > str_start) {
                const rule_str = data[str_start..str_end];
                if (parseRuleString(rule_str)) |rule| {
                    if (rules.items.len < max_rules) {
                        rules.append(allocator, rule) catch |err| {
                            std.log.warn("permissions: failed to append rule: {}", .{err});
                        };
                    }
                }
            }
            pos = str_end + 1;
        } else break;
    }
}

/// Parse "tool(pattern)" into a Rule. E.g., "bash(git diff *)" → {.tool="bash", .pattern="git diff *"}
fn parseRuleString(s: []const u8) ?Rule {
    const paren_idx = std.mem.indexOf(u8, s, "(") orelse return null;
    if (s.len < 3 or s[s.len - 1] != ')') return null;

    const tool = s[0..paren_idx];
    const pattern = s[paren_idx + 1 .. s.len - 1];

    if (tool.len == 0) return null;
    return .{ .tool = tool, .pattern = pattern };
}

/// Read a file, trying both absolute and relative paths.
fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (path.len > 0 and path[0] == '/') {
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();
        return file.readToEndAlloc(allocator, 1024 * 1024);
    }
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 1024 * 1024);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

test "ruleMatches wildcard" {
    const rule = Rule{ .tool = "bash", .pattern = "*" };
    try std.testing.expect(ruleMatches(rule, "bash", "anything"));
    try std.testing.expect(!ruleMatches(rule, "grep", "anything"));
}

test "ruleMatches prefix" {
    const rule = Rule{ .tool = "bash", .pattern = "git diff *" };
    try std.testing.expect(ruleMatches(rule, "bash", "git diff HEAD"));
    try std.testing.expect(ruleMatches(rule, "bash", "git diff "));
    try std.testing.expect(!ruleMatches(rule, "bash", "rm -rf /"));
}

test "ruleMatches exact" {
    const rule = Rule{ .tool = "write_file", .pattern = ".env" };
    try std.testing.expect(ruleMatches(rule, "write_file", ".env"));
    try std.testing.expect(!ruleMatches(rule, "write_file", ".env.local"));
}

test "parseRuleString" {
    const r1 = parseRuleString("bash(git diff *)").?;
    try std.testing.expectEqualStrings("bash", r1.tool);
    try std.testing.expectEqualStrings("git diff *", r1.pattern);

    const r2 = parseRuleString("write_file(.env)").?;
    try std.testing.expectEqualStrings("write_file", r2.tool);
    try std.testing.expectEqualStrings(".env", r2.pattern);

    try std.testing.expect(parseRuleString("invalid") == null);
    try std.testing.expect(parseRuleString("") == null);
}

test "check deny wins over allow" {
    const allocator = std.testing.allocator;
    var config = PermissionConfig{
        .allow_rules = std.ArrayList(Rule).empty,
        .deny_rules = std.ArrayList(Rule).empty,
    };
    defer config.deinit(allocator);

    try config.allow_rules.append(allocator, .{ .tool = "bash", .pattern = "*" });
    try config.deny_rules.append(allocator, .{ .tool = "bash", .pattern = "rm -rf *" });

    // bash allowed in general
    try std.testing.expectEqual(Permission.allow, config.check("bash", "ls"));
    // but rm -rf denied
    try std.testing.expectEqual(Permission.deny, config.check("bash", "rm -rf /"));
}

test "check defaults" {
    var config = PermissionConfig{
        .allow_rules = std.ArrayList(Rule).empty,
        .deny_rules = std.ArrayList(Rule).empty,
    };
    // read_file defaults to allow
    try std.testing.expectEqual(Permission.allow, config.check("read_file", "any"));
    // grep defaults to allow
    try std.testing.expectEqual(Permission.allow, config.check("grep", "any"));
    // bash defaults to deny
    try std.testing.expectEqual(Permission.deny, config.check("bash", "any"));
    // write_file defaults to deny
    try std.testing.expectEqual(Permission.deny, config.check("write_file", "any"));
}
