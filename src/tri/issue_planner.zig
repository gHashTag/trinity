// @origin(spec:issue_planner.tri) @regen(manual-impl)

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const FarmTask = struct {
    issue_number: u32,
    issue_title: []const u8,
    objective: []const u8,
    count: u32,
    context: u32,
    lr_schedule: []const u8,
    sacred: bool,
    priority: u8,
    status: []const u8,

    // Stores backing memory for string fields
    backing_buffer: ?[]const u8 = null,

    pub fn deinit(self: *const FarmTask, allocator: Allocator) void {
        // backing_buffer contains all string data, issue_title points into it
        if (self.backing_buffer) |buf| allocator.free(buf);
    }

    fn compareAsc(context: void, a: FarmTask, b: FarmTask) bool {
        _ = context;
        if (a.priority != b.priority) return a.priority < b.priority;
        return a.issue_number < b.issue_number;
    }
};

pub fn listFarmTasks(allocator: Allocator, json_response: []const u8) ![]FarmTask {
    // Parse JSON response from gh issue list --json or GitHub REST API
    // Both return a JSON array directly, not GraphQL "data" wrapper
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_response, .{});
    defer parsed.deinit();

    // Response is an array of issue objects
    const root = parsed.value.array;

    // Count matching issues
    var count: usize = 0;
    for (root.items) |issue_val| {
        const issue_obj = issue_val.object;
        const labels_val = issue_obj.get("labels") orelse continue;
        const labels = labels_val.array;

        var has_farm_task = false;
        var is_done = false;
        for (labels.items) |label_val| {
            // gh CLI returns: {"name": "label-name"}
            // REST API returns: "label-name" (string) or object with name
            const label_name = blk: {
                if (label_val == .string) {
                    break :blk label_val.string;
                }
                if (label_val.object.get("name")) |name_val| {
                    if (name_val == .string) break :blk name_val.string;
                }
                continue;
            };

            if (std.mem.eql(u8, label_name, "farm-task")) has_farm_task = true;
            if (std.mem.eql(u8, label_name, "status:done")) is_done = true;
        }

        if (has_farm_task and !is_done) count += 1;
    }

    if (count == 0) return &.{};

    // Allocate result slice
    const result = try allocator.alloc(FarmTask, count);

    // Fill the slice
    var index: usize = 0;
    for (root.items) |issue_val| {
        const issue_obj = issue_val.object;
        const labels_val = issue_obj.get("labels") orelse continue;
        const labels = labels_val.array;

        var has_farm_task = false;
        var is_done = false;

        const number_val = issue_obj.get("number") orelse continue;
        if (number_val != .integer) continue;
        const title_val = issue_obj.get("title") orelse continue;
        if (title_val != .string) continue;

        var task = FarmTask{
            .issue_number = @intCast(number_val.integer),
            .issue_title = try allocator.dupe(u8, title_val.string),
            .objective = "ntp",
            .count = 5,
            .context = 81,
            .lr_schedule = "cosine",
            .sacred = false,
            .priority = 2,
            .status = "pending",
        };

        for (labels.items) |label_val| {
            const label_name = blk: {
                if (label_val == .string) {
                    break :blk label_val.string;
                }
                if (label_val.object.get("name")) |name_val| {
                    if (name_val == .string) break :blk name_val.string;
                }
                continue;
            };

            if (std.mem.eql(u8, label_name, "farm-task")) has_farm_task = true;
            if (std.mem.eql(u8, label_name, "status:done")) is_done = true;

            if (std.mem.startsWith(u8, label_name, "objective:")) {
                const obj = label_name["objective:".len..];
                if (std.mem.eql(u8, obj, "ntp") or std.mem.eql(u8, obj, "nca") or
                    std.mem.eql(u8, obj, "jepa") or std.mem.eql(u8, obj, "hybrid"))
                {
                    task.objective = obj;
                }
            } else if (std.mem.startsWith(u8, label_name, "count:")) {
                const count_str = label_name["count:".len..];
                const count_val = std.fmt.parseInt(u32, count_str, 10) catch 5;
                task.count = @min(count_val, 25);
            } else if (std.mem.startsWith(u8, label_name, "context:")) {
                const ctx_str = label_name["context:".len..];
                const ctx_val = std.fmt.parseInt(u32, ctx_str, 10) catch 81;
                if (ctx_val == 27 or ctx_val == 54 or ctx_val == 81 or ctx_val == 243) {
                    task.context = ctx_val;
                }
            } else if (std.mem.startsWith(u8, label_name, "schedule:")) {
                const sched = label_name["schedule:".len..];
                if (std.mem.eql(u8, sched, "cosine") or std.mem.eql(u8, sched, "wsd") or
                    std.mem.eql(u8, sched, "phi_restart") or std.mem.eql(u8, sched, "d2z"))
                {
                    task.lr_schedule = sched;
                }
            } else if (std.mem.eql(u8, label_name, "sacred")) {
                task.sacred = true;
            } else if (std.mem.eql(u8, label_name, "priority:P1")) {
                task.priority = 1;
            } else if (std.mem.eql(u8, label_name, "priority:P2")) {
                task.priority = 2;
            } else if (std.mem.eql(u8, label_name, "priority:P3")) {
                task.priority = 3;
            } else if (std.mem.eql(u8, label_name, "status:in-progress")) {
                task.status = "in-progress";
            }
        }

        if (has_farm_task and !is_done) {
            result[index] = task;
            index += 1;
        }
    }

    // Sort by priority
    std.sort.insertion(FarmTask, result, {}, FarmTask.compareAsc);

    return result;
}

pub fn saveTasksToDir(allocator: Allocator, tasks: []const FarmTask) !void {
    const tasks_dir = ".trinity/tasks";
    try std.fs.cwd().makePath(tasks_dir);

    for (tasks) |task| {
        const filename = try std.fmt.allocPrint(allocator, "{s}/farm-{d}.json", .{ tasks_dir, task.issue_number });
        defer allocator.free(filename);

        const file = try std.fs.cwd().createFile(filename, .{ .truncate = true });
        defer file.close();

        const json_str = try std.json.Stringify.valueAlloc(allocator, task, .{ .whitespace = .indent_2 });
        defer allocator.free(json_str);
        try file.writeAll(json_str);
    }
}

pub fn loadTasksFromDir(allocator: Allocator) ![]FarmTask {
    // Count files first
    var count: usize = 0;
    {
        const tasks_dir = ".trinity/tasks";
        var dir = try std.fs.cwd().openDir(tasks_dir, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".json"))
                count += 1;
        }
    }

    if (count == 0) return &.{};

    // Allocate result slice
    const result = try allocator.alloc(FarmTask, count);

    // Fill the slice
    var index: usize = 0;
    {
        const tasks_dir = ".trinity/tasks";
        var dir = try std.fs.cwd().openDir(tasks_dir, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            const file = try dir.openFile(entry.name, .{});
            defer file.close();

            const stat = try file.stat();
            const content = try allocator.alloc(u8, stat.size);
            // NOTE: Don't free content here - it's stored in task.backing_buffer

            _ = try file.readAll(content);

            const parsed = try std.json.parseFromSlice(FarmTask, allocator, content, .{
                .ignore_unknown_fields = true,
            });
            var task = parsed.value;
            task.backing_buffer = content;
            task.issue_title = try allocator.dupe(u8, task.issue_title);
            result[index] = task;
            index += 1;
        }
    }

    return result;
}

pub fn deleteTaskFile(allocator: Allocator, issue_number: u32) !void {
    const filename = try std.fmt.allocPrint(allocator, ".trinity/tasks/farm-{d}.json", .{issue_number});
    defer allocator.free(filename);

    std.fs.cwd().deleteFile(filename) catch |err| {
        if (err == error.FileNotFound) return;
        return err;
    };
}
