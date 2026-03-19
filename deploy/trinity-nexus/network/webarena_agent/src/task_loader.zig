// WebArena Task Loader
// Loads task configurations from WebArena JSON format
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const json = std.json;

// Task configuration matching WebArena format
pub const TaskConfig = struct {
    task_id: u32,
    sites: []const []const u8,
    intent: []const u8,
    start_url: []const u8,
    require_login: bool,
    require_reset: bool,
    eval_types: []const []const u8,
    reference_answers: []const u8,
    intent_template: ?[]const u8 = null,
    intent_template_id: ?u32 = null,
};

// Evaluation configuration
pub const EvalConfig = struct {
    eval_types: []const []const u8,
    reference_answers: []const u8,
    reference_url: ?[]const u8 = null,
};

// Parsed task from JSON
pub const ParsedTask = struct {
    allocator: std.mem.Allocator,
    task_id: u32,
    sites: std.ArrayList([]const u8),
    intent: []const u8,
    start_url: []const u8,
    require_login: bool,
    require_reset: bool,
    eval_types: std.ArrayList([]const u8),
    reference_answers: []const u8,

    pub fn deinit(self: *ParsedTask) void {
        self.sites.deinit();
        self.eval_types.deinit();
    }

    pub fn toConfig(self: *const ParsedTask) TaskConfig {
        return .{
            .task_id = self.task_id,
            .sites = self.sites.items,
            .intent = self.intent,
            .start_url = self.start_url,
            .require_login = self.require_login,
            .require_reset = self.require_reset,
            .eval_types = self.eval_types.items,
            .reference_answers = self.reference_answers,
        };
    }
};

// Task loader for WebArena JSON files
pub const TaskLoader = struct {
    allocator: std.mem.Allocator,
    tasks: std.ArrayList(ParsedTask),
    raw_json: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) TaskLoader {
        return .{
            .allocator = allocator,
            .tasks = std.ArrayList(ParsedTask).init(allocator),
        };
    }

    pub fn deinit(self: *TaskLoader) void {
        for (self.tasks.items) |*task| {
            task.deinit();
        }
        self.tasks.deinit();
        if (self.raw_json) |raw| {
            self.allocator.free(raw);
        }
    }

    // Load tasks from file path
    pub fn loadFromFile(self: *TaskLoader, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const content = try self.allocator.alloc(u8, stat.size);
        _ = try file.readAll(content);
        self.raw_json = content;

        try self.parseJson(content);
    }

    // Load tasks from string
    pub fn loadFromString(self: *TaskLoader, content: []const u8) !void {
        try self.parseJson(content);
    }

    // Parse JSON array of tasks
    fn parseJson(self: *TaskLoader, content: []const u8) !void {
        // Simple JSON array parser for WebArena format
        // Note: Full implementation would use std.json.parseFromSlice

        var i: usize = 0;

        // Skip whitespace and opening bracket
        while (i < content.len and (content[i] == ' ' or content[i] == '\n' or content[i] == '[')) {
            i += 1;
        }

        var task_count: u32 = 0;
        var brace_depth: u32 = 0;
        var task_start: usize = i;

        while (i < content.len) {
            if (content[i] == '{') {
                if (brace_depth == 0) {
                    task_start = i;
                }
                brace_depth += 1;
            } else if (content[i] == '}') {
                brace_depth -= 1;
                if (brace_depth == 0) {
                    // Found complete task object
                    const task_json = content[task_start .. i + 1];
                    if (self.parseTaskObject(task_json, task_count)) |task| {
                        try self.tasks.append(task);
                        task_count += 1;
                    } else |_| {
                        // Skip malformed tasks
                    }
                }
            }
            i += 1;
        }
    }

    // Parse single task object
    fn parseTaskObject(self: *TaskLoader, task_json: []const u8, default_id: u32) !ParsedTask {
        var task = ParsedTask{
            .allocator = self.allocator,
            .task_id = default_id,
            .sites = std.ArrayList([]const u8).init(self.allocator),
            .intent = "",
            .start_url = "",
            .require_login = false,
            .require_reset = false,
            .eval_types = std.ArrayList([]const u8).init(self.allocator),
            .reference_answers = "",
        };

        // Extract task_id
        if (findJsonValue(task_json, "task_id")) |id_str| {
            task.task_id = std.fmt.parseInt(u32, id_str, 10) catch default_id;
        }

        // Extract intent
        if (findJsonString(task_json, "intent")) |intent| {
            task.intent = intent;
        }

        // Extract start_url
        if (findJsonString(task_json, "start_url")) |url| {
            task.start_url = url;
        }

        // Extract require_login
        if (findJsonValue(task_json, "require_login")) |val| {
            task.require_login = std.mem.eql(u8, val, "true");
        }

        // Extract require_reset
        if (findJsonValue(task_json, "require_reset")) |val| {
            task.require_reset = std.mem.eql(u8, val, "true");
        }

        // Extract sites array
        if (findJsonArray(task_json, "sites")) |sites_str| {
            var site_iter = std.mem.split(u8, sites_str, ",");
            while (site_iter.next()) |site| {
                const trimmed = std.mem.trim(u8, site, " \t\n\"[]");
                if (trimmed.len > 0) {
                    try task.sites.append(trimmed);
                }
            }
        }

        return task;
    }

    // Get task by ID
    pub fn getTask(self: *const TaskLoader, task_id: u32) ?*const ParsedTask {
        for (self.tasks.items) |*task| {
            if (task.task_id == task_id) {
                return task;
            }
        }
        return null;
    }

    // Get tasks by category
    pub fn getTasksByCategory(self: *const TaskLoader, category: []const u8, allocator: std.mem.Allocator) !std.ArrayList(*const ParsedTask) {
        var result = std.ArrayList(*const ParsedTask).init(allocator);
        for (self.tasks.items) |*task| {
            for (task.sites.items) |site| {
                if (std.mem.indexOf(u8, site, category) != null) {
                    try result.append(task);
                    break;
                }
            }
        }
        return result;
    }

    // Get total task count
    pub fn count(self: *const TaskLoader) usize {
        return self.tasks.items.len;
    }

    // Category distribution result
    pub const CategoryDist = struct {
        shopping: u32 = 0,
        shopping_admin: u32 = 0,
        gitlab: u32 = 0,
        reddit: u32 = 0,
        map: u32 = 0,
        wikipedia: u32 = 0,
        other: u32 = 0,
    };

    // Get category distribution
    pub fn getCategoryDistribution(self: *const TaskLoader) CategoryDist {
        var dist = CategoryDist{};

        for (self.tasks.items) |task| {
            var categorized = false;
            for (task.sites.items) |site| {
                if (std.mem.indexOf(u8, site, "shopping_admin") != null) {
                    dist.shopping_admin += 1;
                    categorized = true;
                    break;
                } else if (std.mem.indexOf(u8, site, "shopping") != null) {
                    dist.shopping += 1;
                    categorized = true;
                    break;
                } else if (std.mem.indexOf(u8, site, "gitlab") != null) {
                    dist.gitlab += 1;
                    categorized = true;
                    break;
                } else if (std.mem.indexOf(u8, site, "reddit") != null) {
                    dist.reddit += 1;
                    categorized = true;
                    break;
                } else if (std.mem.indexOf(u8, site, "map") != null) {
                    dist.map += 1;
                    categorized = true;
                    break;
                } else if (std.mem.indexOf(u8, site, "wikipedia") != null) {
                    dist.wikipedia += 1;
                    categorized = true;
                    break;
                }
            }
            if (!categorized) {
                dist.other += 1;
            }
        }

        return dist;
    }
};

// Helper: Find JSON string value
fn findJsonString(json_str: []const u8, key: []const u8) ?[]const u8 {
    // Find "key": "value"
    var search_key: [64]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&search_key, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json_str, key_pattern)) |key_pos| {
        const value_start = key_pos + key_pattern.len;
        var i = value_start;

        // Skip whitespace
        while (i < json_str.len and (json_str[i] == ' ' or json_str[i] == '\t')) {
            i += 1;
        }

        if (i < json_str.len and json_str[i] == '"') {
            i += 1; // Skip opening quote
            const str_start = i;
            while (i < json_str.len and json_str[i] != '"') {
                if (json_str[i] == '\\' and i + 1 < json_str.len) {
                    i += 2; // Skip escaped char
                } else {
                    i += 1;
                }
            }
            return json_str[str_start..i];
        }
    }
    return null;
}

// Helper: Find JSON value (non-string)
fn findJsonValue(json_str: []const u8, key: []const u8) ?[]const u8 {
    var search_key: [64]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&search_key, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json_str, key_pattern)) |key_pos| {
        const value_start = key_pos + key_pattern.len;
        var i = value_start;

        // Skip whitespace
        while (i < json_str.len and (json_str[i] == ' ' or json_str[i] == '\t')) {
            i += 1;
        }

        const val_start = i;
        // Read until comma, brace, or bracket
        while (i < json_str.len and json_str[i] != ',' and json_str[i] != '}' and json_str[i] != ']') {
            i += 1;
        }

        const val = std.mem.trim(u8, json_str[val_start..i], " \t\n");
        if (val.len > 0) {
            return val;
        }
    }
    return null;
}

// Helper: Find JSON array
fn findJsonArray(json_str: []const u8, key: []const u8) ?[]const u8 {
    var search_key: [64]u8 = undefined;
    const key_pattern = std.fmt.bufPrint(&search_key, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json_str, key_pattern)) |key_pos| {
        const value_start = key_pos + key_pattern.len;
        var i = value_start;

        // Skip whitespace
        while (i < json_str.len and (json_str[i] == ' ' or json_str[i] == '\t' or json_str[i] == '\n')) {
            i += 1;
        }

        if (i < json_str.len and json_str[i] == '[') {
            const arr_start = i;
            var depth: u32 = 1;
            i += 1;
            while (i < json_str.len and depth > 0) {
                if (json_str[i] == '[') depth += 1;
                if (json_str[i] == ']') depth -= 1;
                i += 1;
            }
            return json_str[arr_start..i];
        }
    }
    return null;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.print("\n🔥 WebArena Task Loader Test\n", .{});
    try stdout.print("═══════════════════════════════════════════════════════════════════\n", .{});

    // Test with sample JSON
    const sample_json =
        \\[
        \\  {
        \\    "task_id": 0,
        \\    "sites": ["shopping_admin"],
        \\    "intent": "What is the top-1 best-selling product in 2022",
        \\    "start_url": "http://localhost:7780/admin",
        \\    "require_login": true,
        \\    "require_reset": false
        \\  },
        \\  {
        \\    "task_id": 1,
        \\    "sites": ["shopping"],
        \\    "intent": "Find a red dress under $50",
        \\    "start_url": "http://localhost:7770",
        \\    "require_login": false,
        \\    "require_reset": false
        \\  },
        \\  {
        \\    "task_id": 2,
        \\    "sites": ["gitlab"],
        \\    "intent": "Create a new issue in project X",
        \\    "start_url": "http://localhost:8023",
        \\    "require_login": true,
        \\    "require_reset": false
        \\  }
        \\]
    ;

    var loader = TaskLoader.init(allocator);
    defer loader.deinit();

    try loader.loadFromString(sample_json);

    try stdout.print("\nLoaded {d} tasks\n", .{loader.count()});

    const dist = loader.getCategoryDistribution();
    try stdout.print("\nCategory Distribution:\n", .{});
    try stdout.print("  Shopping:       {d}\n", .{dist.shopping});
    try stdout.print("  Shopping Admin: {d}\n", .{dist.shopping_admin});
    try stdout.print("  GitLab:         {d}\n", .{dist.gitlab});
    try stdout.print("  Reddit:         {d}\n", .{dist.reddit});
    try stdout.print("  Map:            {d}\n", .{dist.map});
    try stdout.print("  Wikipedia:      {d}\n", .{dist.wikipedia});
    try stdout.print("  Other:          {d}\n", .{dist.other});

    try stdout.print("\nTask Details:\n", .{});
    for (loader.tasks.items) |task| {
        try stdout.print("  [{d}] {s}\n", .{ task.task_id, task.intent });
        try stdout.print("       URL: {s}\n", .{task.start_url});
        try stdout.print("       Login: {}\n", .{task.require_login});
    }

    try stdout.print("\n✅ Task loader ready for WebArena integration\n", .{});
    try stdout.print("\nφ² + 1/φ² = 3 = TRINITY\n", .{});
}

test "load_sample_json" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sample =
        \\[{"task_id": 0, "sites": ["shopping"], "intent": "test", "start_url": "http://test", "require_login": false, "require_reset": false}]
    ;

    var loader = TaskLoader.init(allocator);
    defer loader.deinit();

    try loader.loadFromString(sample);
    try std.testing.expectEqual(@as(usize, 1), loader.count());
}

test "category_distribution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sample =
        \\[
        \\{"task_id": 0, "sites": ["shopping"], "intent": "a", "start_url": "a", "require_login": false, "require_reset": false},
        \\{"task_id": 1, "sites": ["gitlab"], "intent": "b", "start_url": "b", "require_login": false, "require_reset": false}
        \\]
    ;

    var loader = TaskLoader.init(allocator);
    defer loader.deinit();

    try loader.loadFromString(sample);
    const dist = loader.getCategoryDistribution();

    try std.testing.expectEqual(@as(u32, 1), dist.shopping);
    try std.testing.expectEqual(@as(u32, 1), dist.gitlab);
}

test "find_json_string" {
    const json_str =
        \\{"intent": "Find product", "url": "http://test"}
    ;
    const intent = findJsonString(json_str, "intent");
    try std.testing.expect(intent != null);
    try std.testing.expectEqualStrings("Find product", intent.?);
}
