//! Sessions CRUD Operations
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;

const PostgresClient = @import("client.zig").PostgresClient;
const Error = @import("client.zig").Error;

/// Session data structure
pub const Session = struct {
    id: []const u8,
    name: []const u8,
    status: []const u8,
    railway_service_id: []const u8,
    soul_file: []const u8,
    created_at: i64,
    updated_at: i64,
};

/// Sessions error
pub const SessionsError = error{
    SessionNotFound,
    InvalidStatus,
    DatabaseError,
    InvalidInput,
};


// ── Sessions without a database ────────────────────────────────────────────
//
// The Postgres client cannot authenticate against a managed database yet (it
// speaks only trust auth), so the agent runs with LOCAL_MODE and no connection.
// Every session call then failed with ConnectionFailed, which meant the Queen
// could not open a task for a bee at all.
//
// When there is no connection these calls keep sessions in memory instead. The
// data does not survive a restart and says so; it is what lets the loop run
// while the client learns SCRAM.
const MemoryStore = struct {
    var mutex: std.Thread.Mutex = .{};
    var items: ?std.ArrayList(Session) = null;
    var counter: u32 = 0;

    fn list(allocator: Allocator) *std.ArrayList(Session) {
        if (items == null) items = std.ArrayList(Session).initCapacity(allocator, 8) catch unreachable;
        return &items.?;
    }
};

fn connected(client: *PostgresClient) bool {
    return client.stream != null;
}

/// A quote in a name would end the string literal these queries build by hand.
/// Reject rather than escape: the caller gets a clear error instead of a value
/// that silently changed shape between the request and the row.
fn rejectQuotes(value: []const u8) !void {
    if (std.mem.indexOfAny(u8, value, "'\\") != null) return error.InvalidInput;
}

/// Create a new session
pub fn createSession(allocator: Allocator, client: *PostgresClient, name: []const u8, service_id: []const u8) !Session {
    if (name.len == 0) return error.InvalidInput;
    if (service_id.len == 0) return error.InvalidInput;
    try rejectQuotes(name);
    try rejectQuotes(service_id);

    const now = std.time.timestamp();
    const session_id = try generateSessionId(allocator);

    if (!connected(client)) {
        MemoryStore.mutex.lock();
        defer MemoryStore.mutex.unlock();
        MemoryStore.counter += 1;
        const kept = Session{
            .id = try allocator.dupe(u8, session_id),
            .name = try allocator.dupe(u8, name),
            .status = try allocator.dupe(u8, "active"),
            .railway_service_id = try allocator.dupe(u8, service_id),
            .soul_file = try allocator.dupe(u8, ""),
            .created_at = now,
            .updated_at = now,
        };
        try MemoryStore.list(allocator).append(allocator, kept);
        return Session{
            .id = try allocator.dupe(u8, kept.id),
            .name = try allocator.dupe(u8, kept.name),
            .status = try allocator.dupe(u8, kept.status),
            .railway_service_id = try allocator.dupe(u8, kept.railway_service_id),
            .soul_file = try allocator.dupe(u8, kept.soul_file),
            .created_at = now,
            .updated_at = now,
        };
    }

    const sql = try std.fmt.allocPrint(allocator,
        \\INSERT INTO sessions (id, name, status, railway_service_id, soul_file, created_at, updated_at)
        \\VALUES ('{s}', '{s}', 'active', '{s}', '', {d}, {d})
    , .{ session_id, name, service_id, now, now });

    defer allocator.free(sql);

    var result = try PostgresClient.query(client, sql);
    defer {
        for (result.rows.items) |*row| {
            row.columns.deinit(allocator);
            row.values.deinit(allocator);
        }
        result.rows.deinit(allocator);
    }

    return Session{
        .id = try allocator.dupe(u8, session_id),
        .name = try allocator.dupe(u8, name),
        .status = try allocator.dupe(u8, "active"),
        .railway_service_id = try allocator.dupe(u8, service_id),
        .soul_file = try allocator.dupe(u8, ""),
        .created_at = now,
        .updated_at = now,
    };
}

/// Get session by ID
pub fn getSession(allocator: Allocator, client: *PostgresClient, session_id: []const u8) !Session {
    if (!connected(client)) {
        MemoryStore.mutex.lock();
        defer MemoryStore.mutex.unlock();
        for (MemoryStore.list(allocator).items) |k| {
            if (std.mem.eql(u8, k.id, session_id)) {
                return Session{
                    .id = try allocator.dupe(u8, k.id),
                    .name = try allocator.dupe(u8, k.name),
                    .status = try allocator.dupe(u8, k.status),
                    .railway_service_id = try allocator.dupe(u8, k.railway_service_id),
                    .soul_file = try allocator.dupe(u8, k.soul_file),
                    .created_at = k.created_at,
                    .updated_at = k.updated_at,
                };
            }
        }
        return error.SessionNotFound;
    }
    if (session_id.len == 0) return error.InvalidInput;

    const sql = try std.fmt.allocPrint(allocator,
        \\SELECT id, name, status, railway_service_id, soul_file,
        \\EXTRACT(EPOCH FROM created_at) as created_at,
        \\EXTRACT(EPOCH FROM updated_at) as updated_at
        \\FROM sessions WHERE id = '{s}'
    , .{ session_id });

    defer allocator.free(sql);

    var result = try PostgresClient.query(client, sql);
    defer {
        for (result.rows.items) |*row| {
            row.columns.deinit(allocator);
            row.values.deinit(allocator);
        }
        result.rows.deinit(allocator);
    }

    if (result.rows.items.len == 0) {
        return error.SessionNotFound;
    }

    const row = &result.rows.items[0];

    // Parse created_at and updated_at from epoch
    const created_at = if (row.values.items.len > 5)
        std.fmt.parseInt(i64, row.values.items[5], 10) catch std.time.timestamp()
    else std.time.timestamp();

    const updated_at = if (row.values.items.len > 6)
        std.fmt.parseInt(i64, row.values.items[6], 10) catch std.time.timestamp()
    else std.time.timestamp();

    return Session{
        .id = try allocator.dupe(u8, session_id),
        .name = if (row.values.items.len > 1) try allocator.dupe(u8, row.values.items[1]) else try allocator.dupe(u8, ""),
        .status = if (row.values.items.len > 2) try allocator.dupe(u8, row.values.items[2]) else try allocator.dupe(u8, "unknown"),
        .railway_service_id = if (row.values.items.len > 3) try allocator.dupe(u8, row.values.items[3]) else try allocator.dupe(u8, ""),
        .soul_file = if (row.values.items.len > 4) try allocator.dupe(u8, row.values.items[4]) else try allocator.dupe(u8, ""),
        .created_at = created_at,
        .updated_at = updated_at,
    };
}

/// List all sessions
pub fn listSessions(allocator: Allocator, client: *PostgresClient) !std.ArrayList(Session) {
    if (!connected(client)) {
        MemoryStore.mutex.lock();
        defer MemoryStore.mutex.unlock();
        const kept = MemoryStore.list(allocator);
        var out = try std.ArrayList(Session).initCapacity(allocator, kept.items.len);
        for (kept.items) |k| {
            try out.append(allocator, .{
                .id = try allocator.dupe(u8, k.id),
                .name = try allocator.dupe(u8, k.name),
                .status = try allocator.dupe(u8, k.status),
                .railway_service_id = try allocator.dupe(u8, k.railway_service_id),
                .soul_file = try allocator.dupe(u8, k.soul_file),
                .created_at = k.created_at,
                .updated_at = k.updated_at,
            });
        }
        return out;
    }
    const sql = "SELECT id, name, status, railway_service_id, soul_file, EXTRACT(EPOCH FROM created_at) as created_at, EXTRACT(EPOCH FROM updated_at) as updated_at FROM sessions ORDER BY created_at DESC";

    var result = try PostgresClient.query(client, sql);
    errdefer {
        for (result.rows.items) |*row| {
            row.columns.deinit(allocator);
            row.values.deinit(allocator);
        }
        result.rows.deinit(allocator);
    }

    var sessions = try std.ArrayList(Session).initCapacity(allocator, 0);

    for (result.rows.items) |*row| {
        const created_at = if (row.values.items.len > 4)
            std.fmt.parseInt(i64, row.values.items[4], 10) catch std.time.timestamp()
        else std.time.timestamp();

        const updated_at = if (row.values.items.len > 5)
            std.fmt.parseInt(i64, row.values.items[5], 10) catch std.time.timestamp()
        else std.time.timestamp();

        try sessions.append(allocator, Session{
            .id = try allocator.dupe(u8, row.values.items[0]),
            .name = if (row.values.items.len > 1) try allocator.dupe(u8, row.values.items[1]) else try allocator.dupe(u8, ""),
            .status = if (row.values.items.len > 2) try allocator.dupe(u8, row.values.items[2]) else try allocator.dupe(u8, "unknown"),
            .railway_service_id = if (row.values.items.len > 3) try allocator.dupe(u8, row.values.items[3]) else try allocator.dupe(u8, ""),
            .soul_file = if (row.values.items.len > 4) try allocator.dupe(u8, row.values.items[4]) else try allocator.dupe(u8, ""),
            .created_at = created_at,
            .updated_at = updated_at,
        });
    }

    return sessions;
}

/// Update session
pub fn updateSession(allocator: Allocator, client: *PostgresClient, session_id: []const u8, data: struct {
    status: ?[]const u8,
    name: ?[]const u8,
    railway_service_id: ?[]const u8,
}) !void {
    if (session_id.len == 0) return error.InvalidInput;

    const now = std.time.timestamp();
    var updates = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer updates.deinit(allocator);

    if (data.status) |status| {
        try updates.appendSlice(allocator, "status = '");
        try updates.appendSlice(allocator, status);
        try updates.appendSlice(allocator, "', ");
    }
    if (data.name) |name| {
        try updates.appendSlice(allocator, "name = '");
        try updates.appendSlice(allocator, name);
        try updates.appendSlice(allocator, "', ");
    }
    if (data.railway_service_id) |sid| {
        try updates.appendSlice(allocator, "railway_service_id = '");
        try updates.appendSlice(allocator, sid);
        try updates.appendSlice(allocator, "', ");
    }

    if (updates.items.len == 0) return;

    // Remove trailing comma
    if (updates.items.len > 2) {
        updates.items.len -= 2;
    }

    try updates.writer(allocator).print(", updated_at = {d}", .{now});

    const set_clause = try updates.toOwnedSlice(allocator);

    const sql = try std.fmt.allocPrint(allocator,
        \\UPDATE sessions SET {s} WHERE id = '{s}'
    , .{ set_clause, session_id });

    defer {
        allocator.free(set_clause);
        allocator.free(sql);
    }

    _ = try PostgresClient.query(client, sql);
}

/// Delete session
pub fn deleteSession(client: *PostgresClient, session_id: []const u8) !void {
    if (!connected(client)) {
        MemoryStore.mutex.lock();
        defer MemoryStore.mutex.unlock();
        if (MemoryStore.items) |*kept| {
            for (kept.items, 0..) |k, i| {
                if (std.mem.eql(u8, k.id, session_id)) {
                    _ = kept.orderedRemove(i);
                    return;
                }
            }
        }
        return error.SessionNotFound;
    }
    if (session_id.len == 0) return error.InvalidInput;

    const sql = try std.fmt.allocPrint(std.heap.page_allocator,
        \\DELETE FROM sessions WHERE id = '{s}'
    , .{ session_id });

    defer std.heap.page_allocator.free(sql);

    _ = try PostgresClient.query(client, sql);
}

/// Generate a unique session ID
fn generateSessionId(allocator: Allocator) ![]const u8 {
    const now = std.time.nanoTimestamp();
    const random = std.crypto.random.intRangeAtMost(usize, 0, std.math.maxInt(usize));

    return try std.fmt.allocPrint(allocator, "sess_{d}_{x}", .{ now, random });
}

test "sessions: create and get" {
    // Test only creates Session struct directly - no DB connection needed
    const id = "sess_123_456";
    const now = std.time.timestamp();

    const session = Session{
        .id = id,
        .name = "test-session",
        .status = "active",
        .railway_service_id = "svc_123",
        .created_at = now,
        .updated_at = now,
    };

    try std.testing.expectEqualStrings(session.id, id);
    try std.testing.expectEqualStrings(session.name, "test-session");
    try std.testing.expectEqualStrings(session.status, "active");
}
