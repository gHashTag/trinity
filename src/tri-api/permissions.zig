// permissions.zig — Tool permission system for tri-api
// User and project rules are combined; deny always takes priority.
// Issue #65: Phase 6 permissions + checkpoints
const std = @import("std");

const user_settings = ".trinity/api/settings.json";
const project_settings = ".trinity/api/settings.json";
const max_rules = 64;

pub const Permission = enum { allow, deny };

pub const PermissionConfig = struct {
    allow_rules: std.ArrayList(Rule),
    deny_rules: std.ArrayList(Rule),
    invalid: bool = false,

    pub fn deinit(self: *PermissionConfig, allocator: std.mem.Allocator) void {
        for (self.allow_rules.items) |rule| rule.deinit(allocator);
        for (self.deny_rules.items) |rule| rule.deinit(allocator);
        self.allow_rules.deinit(allocator);
        self.deny_rules.deinit(allocator);
    }

    /// Check if a tool invocation is permitted. deny wins over allow.
    /// Returns .deny if any deny rule matches, .allow if any allow rule matches,
    /// otherwise defaults: read_file/grep → allow, bash/write_file → deny.
    pub fn check(self: *const PermissionConfig, tool: []const u8, arg: []const u8) Permission {
        if (self.invalid) return .deny;
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
    owned: bool = false,

    fn deinit(self: Rule, allocator: std.mem.Allocator) void {
        if (self.owned) {
            allocator.free(self.tool);
            allocator.free(self.pattern);
        }
    }
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

/// Load and combine user/project permission settings; deny always wins.
/// Format: {"permissions":{"allow":["bash(git diff *)","read_file(*)"],"deny":["bash(rm -rf *)"]}}
pub fn loadConfig(allocator: std.mem.Allocator) PermissionConfig {
    var config = PermissionConfig{
        .allow_rules = std.ArrayList(Rule).empty,
        .deny_rules = std.ArrayList(Rule).empty,
    };

    // Try user settings first (~/.trinity/api/settings.json)
    const home = std.posix.getenv("HOME") orelse "";
    if (home.len > 0) {
        var user_path_buf: [512]u8 = undefined;
        if (std.fmt.bufPrint(&user_path_buf, "{s}/{s}", .{ home, user_settings })) |user_path| {
            loadFromFile(allocator, &config, user_path);
        } else |_| {}
    }

    // Add project settings (.trinity/api/settings.json in cwd)
    loadFromFile(allocator, &config, project_settings);

    return config;
}

/// Missing settings use defaults; unreadable or invalid settings deny every tool.
fn loadFromFile(allocator: std.mem.Allocator, config: *PermissionConfig, path: []const u8) void {
    const content = readFile(allocator, path) catch |err| {
        if (err != error.FileNotFound) config.invalid = true;
        return;
    };
    defer allocator.free(content);
    parseSettings(allocator, config, content) catch {
        config.invalid = true;
    };
}

fn parseSettings(allocator: std.mem.Allocator, config: *PermissionConfig, content: []const u8) !void {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidSettings;
    const perms = parsed.value.object.get("permissions") orelse return;
    if (perms != .object) return error.InvalidSettings;
    try parseRuleArray(allocator, perms.object.get("allow"), &config.allow_rules);
    try parseRuleArray(allocator, perms.object.get("deny"), &config.deny_rules);
}

fn parseRuleArray(allocator: std.mem.Allocator, value: ?std.json.Value, rules: *std.ArrayList(Rule)) !void {
    const array = value orelse return;
    if (array != .array) return error.InvalidSettings;
    for (array.array.items) |item| {
        if (item != .string) return error.InvalidRule;
        const rule = parseRuleString(item.string) orelse return error.InvalidRule;
        if (rules.items.len >= max_rules) return error.TooManyRules;
        // Parsed JSON and file buffers die after loading; the config owns its strings.
        const tool = try allocator.dupe(u8, rule.tool);
        errdefer allocator.free(tool);
        const pattern = try allocator.dupe(u8, rule.pattern);
        errdefer allocator.free(pattern);
        try rules.append(allocator, .{ .tool = tool, .pattern = pattern, .owned = true });
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

test "loaded rules survive JSON and file buffer release" {
    const a = std.testing.allocator;
    var config = PermissionConfig{ .allow_rules = .empty, .deny_rules = .empty };
    defer config.deinit(a);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "settings.json", .data =
        \\{"permissions": {"allow": ["read_file(*)"], "deny": ["read_file(.env)"]}}
    });
    const path = try tmp.dir.realpathAlloc(a, "settings.json");
    defer a.free(path);
    loadFromFile(a, &config, path);
    try std.testing.expect(!config.invalid);
    try std.testing.expectEqual(Permission.deny, config.check("read_file", ".env"));
    try std.testing.expectEqual(Permission.allow, config.check("read_file", "README.md"));
}

test "invalid settings fail closed, including partially parsed allow" {
    const a = std.testing.allocator;
    const cases = [_][]const u8{
        "{",                                                              "[]",                                         "{\"permissions\":null}",
        "{\"permissions\":{\"allow\":[\"read_file(*)\"],\"deny\":[42]}}", "{\"permissions\":{\"deny\":[\"invalid\"]}}", "{\"permissions\":{\"deny\":\"read_file(*)\"}}",
        "{\"permissions\":{\"deny\":[],\"deny\":[]}}",
    };
    for (cases) |content| {
        var config = PermissionConfig{ .allow_rules = .empty, .deny_rules = .empty };
        defer config.deinit(a);
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();
        try tmp.dir.writeFile(.{ .sub_path = "settings.json", .data = content });
        const path = try tmp.dir.realpathAlloc(a, "settings.json");
        defer a.free(path);
        loadFromFile(a, &config, path);
        try std.testing.expect(config.invalid);
        try std.testing.expectEqual(Permission.deny, config.check("read_file", "README.md"));
        try std.testing.expectEqual(Permission.deny, config.check("bash", "pwd"));
    }
}

test "rules decode escaped JSON and enforce capacity without truncation" {
    const a = std.testing.allocator;
    var config = PermissionConfig{ .allow_rules = .empty, .deny_rules = .empty };
    defer config.deinit(a);
    try parseSettings(a, &config,
        \\{ "permissions" : { "deny" : ["read_file(secret\u002efile)"] } }
    );
    try std.testing.expectEqual(Permission.deny, config.check("read_file", "secret.file"));
    for (0..max_rules - 1) |_| try parseSettings(a, &config,
        \\{"permissions":{"deny":["read_file(*)"]}}
    );
    try std.testing.expectError(error.TooManyRules, parseSettings(a, &config,
        \\{"permissions":{"deny":["read_file(.env)"]}}
    ));
}
