// @origin(manual) @regen(pending)
// MAC CLUSTER — Multi-Mac Wave 9 Training Discovery
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Arch = @import("tri_hardware_deploy.zig").Arch;
const Platform = @import("tri_hardware_deploy.zig").Platform;

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";

pub const NodeRole = enum {
    coordinator,
    worker,
    storage,

    pub fn toString(self: NodeRole) []const u8 {
        return switch (self) {
            .coordinator => "coordinator",
            .worker => "worker",
            .storage => "storage",
        };
    }

    pub fn emoji(self: NodeRole) []const u8 {
        return switch (self) {
            .coordinator => "👑",
            .worker => "⚙️",
            .storage => "💾",
        };
    }

    pub fn defaultWorkers(self: NodeRole) usize {
        return switch (self) {
            .coordinator => 4,
            .worker => 12,
            .storage => 0,
        };
    }

    pub fn maxWorkers(self: NodeRole) usize {
        return switch (self) {
            .coordinator => 4,
            .worker => 12,
            .storage => 0,
        };
    }
};

pub const MacNode = struct {
    id: usize,
    hostname: []const u8,
    ip: []const u8,
    arch: Arch,
    platform: Platform,
    workers_start: usize,
    workers_count: usize,
    role: NodeRole,
    last_seen: i64,
    online: bool,
};

pub const MacCluster = struct {
    nodes: std.ArrayListUnmanaged(MacNode),
    coordinator_id: ?usize,
    total_workers: usize,
    created_at: i64,
    updated_at: i64,
};

pub fn init(allocator: Allocator) !MacCluster {
    _ = allocator;
    return MacCluster{
        .nodes = std.ArrayListUnmanaged(MacNode){},
        .coordinator_id = null,
        .total_workers = 0,
        .created_at = std.time.timestamp(),
        .updated_at = std.time.timestamp(),
    };
}

pub fn deinit(self: *MacCluster, allocator: Allocator) void {
    for (self.nodes.items) |*node| {
        allocator.free(node.hostname);
        allocator.free(node.ip);
    }
    self.nodes.deinit(allocator);
}

pub fn load(allocator: Allocator) !MacCluster {
    const file = std.fs.cwd().openFile(".trinity/mac_cluster.json", .{}) catch |err| switch (err) {
        error.FileNotFound => return init(allocator),
        else => return err,
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(MacCluster, allocator, content, .{});
    defer parsed.deinit();

    var result = try init(allocator);
    for (parsed.value.nodes.items) |node| {
        const hostname_copy = try allocator.dupe(u8, node.hostname);
        errdefer allocator.free(hostname_copy);
        const ip_copy = try allocator.dupe(u8, node.ip);
        errdefer allocator.free(ip_copy);

        try result.nodes.append(allocator, .{
            .id = node.id,
            .hostname = hostname_copy,
            .ip = ip_copy,
            .arch = node.arch,
            .platform = node.platform,
            .workers_start = node.workers_start,
            .workers_count = node.workers_count,
            .role = node.role,
            .last_seen = node.last_seen,
            .online = node.online,
        });
    }
    result.coordinator_id = parsed.value.coordinator_id;
    result.total_workers = parsed.value.total_workers;
    result.created_at = parsed.value.created_at;
    result.updated_at = parsed.value.updated_at;

    return result;
}

pub fn save(self: *const MacCluster, allocator: Allocator) !void {
    const state_dir = std.fs.path.dirname(".trinity/mac_cluster.json") orelse ".";
    std.fs.cwd().makeDir(state_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const file = try std.fs.cwd().createFile(".trinity/mac_cluster.json", .{});
    defer file.close();

    const json_str = try std.json.Stringify.valueAlloc(allocator, self, .{ .whitespace = .indent_2 });
    defer allocator.free(json_str);
    try file.writeAll(json_str);
}

pub fn discover(allocator: Allocator) !MacCluster {
    var cluster = try init(allocator);
    errdefer cluster.deinit(allocator);

    var hostname_buf: [256]u8 = undefined;
    const hostname = std.os.gethostname(&hostname_buf) catch "localhost";

    const local_ip = try getLocalIP(allocator);
    const platform = @import("tri_hardware_deploy.zig").detectPlatform();
    const arch = @import("tri_hardware_deploy.zig").detectArch();

    const hostname_copy = try allocator.dupe(u8, hostname);
    errdefer allocator.free(hostname_copy);

    try cluster.nodes.append(allocator, .{
        .id = 0,
        .hostname = hostname_copy,
        .ip = local_ip,
        .arch = arch,
        .platform = platform,
        .workers_start = 1,
        .workers_count = 0,
        .role = .coordinator,
        .last_seen = std.time.timestamp(),
        .online = true,
    });

    cluster.coordinator_id = 0;

    return cluster;
}

pub fn addNode(self: *MacCluster, allocator: Allocator, ip: []const u8, hostname: []const u8, role: NodeRole) !void {
    const id = self.nodes.items.len;
    const hostname_copy = try allocator.dupe(u8, hostname);
    errdefer allocator.free(hostname_copy);

    const ip_copy = try allocator.dupe(u8, ip);
    errdefer allocator.free(ip_copy);

    const platform = @import("tri_hardware_deploy.zig").detectPlatform();
    const arch = @import("tri_hardware_deploy.zig").detectArch();

    try self.nodes.append(allocator, .{
        .id = id,
        .hostname = hostname_copy,
        .ip = ip_copy,
        .arch = arch,
        .platform = platform,
        .workers_start = 1,
        .workers_count = 0,
        .role = role,
        .last_seen = std.time.timestamp(),
        .online = true,
    });

    self.updated_at = std.time.timestamp();
}

pub fn assignWorkers(self: *MacCluster, total: usize) !void {
    self.total_workers = total;

    var remaining: usize = total;
    var worker_id: usize = 1;

    if (self.coordinator_id) |coord_id| {
        if (coord_id < self.nodes.items.len) {
            const coord_workers = @min(4, remaining);
            self.nodes.items[coord_id].workers_count = coord_workers;
            self.nodes.items[coord_id].workers_start = worker_id;
            worker_id += coord_workers;
            remaining -= coord_workers;
        }
    }

    const worker_count = self.nodes.items.len;
    if (worker_count > 0) {
        const per_node = remaining / worker_count;
        const extra = remaining % worker_count;

        for (self.nodes.items) |*node| {
            if (node.role == .coordinator) continue;

            const has_extra = if (extra > 0) node.id < extra else false;
            const node_workers = per_node + if (has_extra) @as(usize, 1) else 0;
            node.workers_count = @min(node_workers, node.role.maxWorkers());
            node.workers_start = worker_id;
            worker_id += node.workers_count;
        }
    }

    self.updated_at = std.time.timestamp();
}

pub fn totalCapacity(self: *const MacCluster) usize {
    var total: usize = 0;
    for (self.nodes.items) |node| {
        total += node.role.maxWorkers();
    }
    return total;
}

pub fn displayStatus(self: *const MacCluster) void {
    print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    print("{s}MAC CLUSTER — Wave 9 Distributed Training{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════{s}\n", .{ DIM, RESET });

    print("{s}Nodes: {d}  {s}│{s}  Total Workers: {d}  {s}│{s}  Capacity: {d}{s}\n\n", .{
        CYAN, self.nodes.items.len, RESET, CYAN, self.total_workers, RESET, DIM, totalCapacity(self), RESET,
    });

    if (self.nodes.items.len == 0) {
        print("{s}No nodes in cluster. Run 'tri mac-cluster discover' to find Macs.{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    print("{s}Nodes:{s}\n", .{ BOLD, RESET });
    for (self.nodes.items) |node| {
        const status_emoji = if (node.online) "🟢" else "🔴";
        const role_emoji = node.role.emoji();
        const coord_mark = if (self.coordinator_id) |cid| cid == node.id else false;
        const coord_str = if (coord_mark) " [COORDINATOR]" else "";

        print("  {s}{s} {s}{s} {s}mac-{d:2} {s}{s}\n", .{
            role_emoji, status_emoji, BOLD, node.hostname, RESET, node.id, DIM,
        });

        if (coord_mark) {
            print("    {s}{s}{s}\n", .{ YELLOW, coord_str, RESET });
        }

        if (node.workers_count > 0) {
            print("    {s}Workers: {d}-{d} ({d} total){s}\n", .{
                DIM, node.workers_start, node.workers_start + node.workers_count - 1, node.workers_count, RESET,
            });
        }
    }
    print("\n", .{});
}

pub fn generateComposeFiles(self: *const MacCluster, allocator: Allocator) !void {
    const wave9_device = @import("wave9_device.zig");

    for (self.nodes.items) |node| {
        if (node.workers_count == 0) continue;

        const compose = try wave9_device.generateDeviceCompose(
            allocator,
            node.id,
            .{ .start = node.workers_start, .count = node.workers_count },
        );
        defer allocator.free(compose);

        const output_path = try std.fmt.allocPrint(
            allocator,
            "deploy/docker/docker-compose.wave9-mac-{d}.yml",
            .{node.id},
        );
        defer allocator.free(output_path);

        const output_dir = std.fs.path.dirname(output_path) orelse ".";
        std.fs.cwd().makeDir(output_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const file = try std.fs.cwd().createFile(output_path, .{});
        defer file.close();
        try file.writeAll(compose);

        print("  {s}✅{s} Generated: {s}\n", .{ GREEN, RESET, output_path });
    }
}

fn getLocalIP() ![]const u8 {
    const allocator = std.heap.page_allocator;
    return allocator.dupe(u8, "127.0.0.1");
}

test "MacCluster init" {
    const allocator = std.testing.allocator;
    const cluster = try init(allocator);
    defer cluster.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), cluster.nodes.items.len);
    try std.testing.expect(cluster.coordinator_id == null);
}

test "MacCluster add node" {
    const allocator = std.testing.allocator;
    var cluster = try init(allocator);
    defer cluster.deinit(allocator);

    try cluster.addNode(allocator, "192.168.1.100", "test-mac", .worker);

    try std.testing.expectEqual(@as(usize, 1), cluster.nodes.items.len);
    try std.testing.expectEqualStrings("192.168.1.100", cluster.nodes.items[0].ip);
}

test "MacCluster assign workers" {
    const allocator = std.testing.allocator;
    var cluster = try init(allocator);
    defer cluster.deinit(allocator);

    try cluster.addNode(allocator, "192.168.1.1", "coord", .coordinator);
    cluster.nodes.items[0].id = 0;
    cluster.coordinator_id = 0;

    try cluster.addNode(allocator, "192.168.1.2", "worker1", .worker);
    cluster.nodes.items[1].id = 1;

    try cluster.addNode(allocator, "192.168.1.3", "worker2", .worker);
    cluster.nodes.items[2].id = 2;

    try cluster.assignWorkers(20);

    try std.testing.expectEqual(@as(usize, 4), cluster.nodes.items[0].workers_count);
    try std.testing.expectEqual(@as(usize, 1), cluster.nodes.items[0].workers_start);
    try std.testing.expectEqual(cluster.nodes.items[1].workers_count + cluster.nodes.items[2].workers_count, 16);
}
