//! PostgreSQL Wire Protocol v3.0 Client
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Implements PostgreSQL wire protocol startup and query messages.
//! See: https://www.postgresql.org/docs/current/protocol-message-formats.html

const std = @import("std");
const Allocator = std.mem.Allocator;
const net = std.net;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS - PostgreSQL Wire Protocol v3.0
// ═══════════════════════════════════════════════════════════════════════════════

/// Protocol version 3.0 (196608 = 3.0 in PostgreSQL encoding)
pub const PROTOCOL_VERSION: u32 = 196608;

/// Message type identifiers
pub const MessageType = enum(u8) {
    StartupMessage = 0x00, // No type byte for startup
    AuthenticationOk = 'R',
    BackendKeyData = 'K',
    ReadyForQuery = 'Z',
    CommandComplete = 'C',
    ErrorResponse = 'E',
    Query = 'Q',
    Terminate = 'X',
};

/// Transaction status in ReadyForQuery
pub const TransactionStatus = enum(u8) {
    Idle = 'I',              // Not in transaction
    InTransaction = 'T',      // In transaction
    Failed = 'E',            // Failed transaction
};

/// PostgreSQL OIDs (Object Identifiers) for common types
pub const Oid = struct {
    pub const BOOL: u32 = 16;
    pub const INT2: u32 = 21;
    pub const INT4: u32 = 23;
    pub const INT8: u32 = 20;
    pub const FLOAT4: u32 = 700;
    pub const FLOAT8: u32 = 701;
    pub const TEXT: u32 = 25;
    pub const VARCHAR: u32 = 1043;
    pub const JSON: u32 = 114;
    pub const JSONB: u32 = 3802;
    pub const UUID: u32 = 2950;
    pub const TIMESTAMP: u32 = 1114;
    pub const TIMESTAMPTZ: u32 = 1184;
    pub const DATE: u32 = 1082;
    pub const BYTEA: u32 = 17;
};

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// PostgreSQL connection
pub const PostgresClient = struct {
    allocator: Allocator,
    stream: ?net.Stream,
    host: []const u8 = "localhost",
    port: u16 = 5432,
    database: []const u8 = "postgres",
    user: []const u8 = "postgres",
    password: []const u8 = "",
    backend_pid: i32 = 0,
    backend_key: i32 = 0,
    transaction_status: TransactionStatus = .Idle,

    /// Connect to PostgreSQL database using wire protocol
    pub fn connect(self: *PostgresClient, database_url: []const u8) !void {
        // Parse database URL: postgres://user:password@host:port/database
        var iter = std.mem.splitScalar(u8, database_url, '/');
        _ = iter.first(); // "postgres:"

        const credentials = iter.next() orelse return error.InvalidUrl;
        const host_port = iter.next() orelse return error.InvalidUrl;
        const db_name = iter.next() orelse return error.InvalidUrl;

        // Parse host:port
        var hp_iter = std.mem.splitScalar(u8, host_port, '@');
        const host_part: ?[]const u8 = hp_iter.first();
        if (host_part == null) return error.InvalidUrl;
        const actual_host_port = hp_iter.next() orelse host_part.?;

        hp_iter = std.mem.splitScalar(u8, actual_host_port, ':');
        const hp_first = hp_iter.next();
        if (hp_first) |hp| {
            self.host = hp;
        } else {
            self.host = "localhost";
        }
        if (hp_iter.next()) |port_str| {
            self.port = std.fmt.parseInt(u16, port_str, 10) catch 5432;
        }

        // Parse credentials user:password
        var cred_iter = std.mem.splitScalar(u8, credentials, ':');
        const cred_user = cred_iter.first();
        const cred_pass = cred_iter.next();
        self.user = cred_user;
        self.password = cred_pass orelse "";

        self.database = if (db_name.len > 0) db_name else "postgres";

        // Connect via TCP.
        //
        // resolveIp parses a literal address and does no name lookup, so every
        // managed Postgres crashed the agent on boot with InvalidIPAddressFormat:
        // Railway addresses its database as postgres.railway.internal, a name.
        // tcpConnectToHost resolves names and still accepts a literal IP.
        var stream = try std.net.tcpConnectToHost(self.allocator, self.host, self.port);
        self.stream = stream;

        // Send startup message
        const startup_msg = try buildStartupMessage(self.allocator, self.user, self.database);
        defer self.allocator.free(startup_msg);

        _ = try stream.writeAll(startup_msg);

        // Handle authentication
        try handleAuthentication(&stream);

        // Wait for ReadyForQuery
        try self.waitForReady(&stream);
    }

    /// Execute SQL query using wire protocol
    pub fn query(self: *PostgresClient, sql: []const u8) !QueryResult {
        if (self.stream == null) return error.ConnectionFailed;

        var result = QueryResult{
            .rows = try std.ArrayList(Row).initCapacity(self.allocator, 0),
            .affected_rows = 0,
        };
        errdefer {
            for (result.rows.items) |*row| {
                row.deinit(self.allocator);
            }
            result.rows.deinit(self.allocator);
        }

        // Send query message
        const query_msg = try buildQueryMessage(self.allocator, sql);
        defer self.allocator.free(query_msg);

        _ = try self.stream.?.writeAll(query_msg);

        // Read response
        try self.readQueryResponse(&self.stream.?, &result);

        return result;
    }

    /// Close database connection
    pub fn close(self: *PostgresClient) void {
        if (self.stream) |stream| {
            // Send terminate message
            const terminate_msg = [_]u8{@intFromEnum(MessageType.Terminate), 0, 0, 0, 4};
            _ = stream.writeAll(&terminate_msg) catch {};
            stream.close();
            self.stream = null;
        }
    }

    /// Handle authentication response from server
    fn handleAuthentication(stream: *net.Stream) !void {
        var len_buf: [4]u8 = undefined;
        const bytes_read = try stream.read(&len_buf);
        if (bytes_read < 4) return error.InvalidMessage;
        const msg_len_u32 = std.mem.readInt(u32, &len_buf, .big);

        var type_buf: [1]u8 = undefined;
        const read_bytes = try stream.read(&type_buf);
        if (read_bytes != 1) return error.InvalidMessage;
        const msg_type = type_buf[0];

        // For AuthenticationOk (R), msg_len_u32 includes the type byte
        // AuthenticationOk has auth_code = 0
        if (msg_type == @intFromEnum(MessageType.AuthenticationOk)) {
            const remaining_len = msg_len_u32 - 4;
            if (remaining_len >= 4) {
                var auth_buf: [4]u8 = undefined;
                const auth_bytes_read = try stream.read(&auth_buf);
                if (auth_bytes_read < 4) return error.InvalidMessage;
                const auth_code = std.mem.readInt(u32, &auth_buf, .big);

                if (auth_code != 0) {
                    // Not AuthenticationOk, need to handle password
                    return error.AuthenticationNotImplemented;
                }
            }
            return;
        }

        return error.UnexpectedMessage;
    }

    /// Wait for ReadyForQuery message
    fn waitForReady(self: *PostgresClient, stream: *net.Stream) !void {
        var type_buf: [1]u8 = undefined;
        const type_bytes = try stream.read(type_buf[0..]);
        if (type_bytes != 1) return error.InvalidMessage;
        const msg_type = type_buf[0];

        var len_buf: [4]u8 = undefined;
        const len_bytes = try stream.read(len_buf[0..]);
        if (len_bytes != 4) return error.InvalidMessage;
        const msg_len_u32 = std.mem.readInt(u32, &len_buf, .big);

        if (msg_type == @intFromEnum(MessageType.BackendKeyData)) {
            // Read backend key data
            var buf: [8]u8 = undefined;
            const buf_bytes = try stream.read(buf[0..]);
            if (buf_bytes != 8) return error.InvalidMessage;
            self.backend_pid = std.mem.readInt(i32, buf[0..4], .big);
            self.backend_key = std.mem.readInt(i32, buf[4..8], .big);

            // Now wait for ReadyForQuery
            return self.waitForReady(stream);
        }

        if (msg_type == @intFromEnum(MessageType.ReadyForQuery)) {
            var status_buf: [1]u8 = undefined;
            const status_bytes = try stream.read(status_buf[0..]);
            if (status_bytes != 1) return error.InvalidMessage;
            self.transaction_status = @as(TransactionStatus, @enumFromInt(status_buf[0]));
            return;
        }

        if (msg_type == @intFromEnum(MessageType.ErrorResponse)) {
            return readErrorResponse(stream, msg_len_u32 - 4);
        }

        return error.UnexpectedMessage;
    }

    /// Read query response from server
    fn readQueryResponse(self: *PostgresClient, stream: *net.Stream, result: *QueryResult) !void {
        _ = result; // autofix
        while (true) {
            var type_buf: [1]u8 = undefined;
            const n = try stream.read(type_buf[0..]);
            if (n == 0) break;

            const msg_type = type_buf[0];

            var len_buf: [4]u8 = undefined;
            const len_bytes = try stream.read(len_buf[0..]);
            if (len_bytes != 4) return error.InvalidMessage;
            const msg_len_u32 = std.mem.readInt(u32, &len_buf, .big);

            switch (msg_type) {
                @intFromEnum(MessageType.CommandComplete) => {
                    _ = try skipMessage(stream, msg_len_u32 - 4);
                },
                @intFromEnum(MessageType.ReadyForQuery) => {
                    var status_buf: [1]u8 = undefined;
                    const status_bytes = try stream.read(status_buf[0..]);
                    if (status_bytes != 1) return error.InvalidMessage;
                    self.transaction_status = @as(TransactionStatus, @enumFromInt(status_buf[0]));
                    break;
                },
                @intFromEnum(MessageType.ErrorResponse) => {
                    return readErrorResponse(stream, msg_len_u32 - 4);
                },
                else => {
                    _ = try skipMessage(stream, msg_len_u32 - 4);
                },
            }
        }
    }

    /// Read a DataRow message
    fn readDataRow(self: *PostgresClient, stream: *net.Stream, len: u32, result: *QueryResult) !void {
        var col_count_buf: [2]u8 = undefined;
        const col_count_bytes = try stream.read(col_count_buf[0..]);
        if (col_count_bytes != 2) return error.InvalidMessage;
        const col_count = std.mem.readInt(u16, &col_count_buf, .big);

        var row = Row{
            .columns = std.ArrayList([]const u8).init(self.allocator),
            .values = std.ArrayList([]const u8).init(self.allocator),
        };
        errdefer row.deinit(self.allocator);

        var remaining: u32 = len - 2;
        for (0..col_count) |_| {
            var value_len_buf: [4]u8 = undefined;
            const value_len_bytes = try stream.read(value_len_buf[0..]);
            if (value_len_bytes != 4) return error.InvalidMessage;
            const value_len = std.mem.readInt(i32, &value_len_buf, .big);
            remaining -= 4;

            if (value_len == -1) {
                // NULL value
                try row.columns.append("");
                try row.values.append("");
            } else {
                const value_len_usize = @as(usize, @intCast(value_len));
                const value_buf = try self.allocator.alloc(u8, value_len_usize);
                const value_bytes = try stream.read(value_buf[0..value_len_usize]);
                if (value_bytes != value_len_usize) return error.InvalidMessage;
                try row.values.append(value_buf[0..value_len_usize]);
                try row.columns.append(""); // Column name not in DataRow
                remaining -= value_len_usize;
            }
        }

        try result.rows.append(try row.clone(self.allocator));
        row.deinit(self.allocator);
    }

    /// Read and parse error response
    fn readErrorResponse(stream: *net.Stream, len: u32) !void {
        var message: [256]u8 = undefined;
        var message_len: usize = 0;

        var remaining: u32 = len;
        while (remaining > 0) {
            var type_buf: [1]u8 = undefined;
            const type_bytes = try stream.read(type_buf[0..]);
            if (type_bytes != 1) return error.InvalidMessage;
            remaining -= 1;

            if (type_buf[0] == 0) break; // Null terminator

            // Read string until null terminator
            while (true) {
                var byte_buf: [1]u8 = undefined;
                const byte_bytes = try stream.read(byte_buf[0..]);
                if (byte_bytes != 1) return error.InvalidMessage;
                remaining -= 1;

                if (byte_buf[0] == 0) break;
                if (message_len < message.len) {
                    message[message_len] = byte_buf[0];
                    message_len += 1;
                }
            }
        }

    if (message_len > 0) {
        return error.PostgresError;
    }
}

    /// Skip a message
    fn skipMessage(stream: *net.Stream, len: u32) !void {
        var buf: [1024]u8 = undefined;
        var remaining: u32 = len;

        while (remaining > 0) {
            const to_read = @min(remaining, buf.len);
            const n = try stream.read(buf[0..to_read]);
            if (n == 0) return error.ConnectionClosed;
            remaining -= @intCast(n);
        }
    }
};

/// SQL query result
pub const QueryResult = struct {
    rows: std.ArrayList(Row),
    affected_rows: usize,

    pub fn deinit(self: *QueryResult, allocator: Allocator) void {
        for (self.rows.items) |*row| {
            row.deinit(allocator);
        }
        self.rows.deinit();
    }
};

/// Database row
pub const Row = struct {
    columns: std.ArrayList([]const u8),
    values: std.ArrayList([]const u8),

    pub fn deinit(self: *Row, allocator: Allocator) void {
        for (self.columns.items) |col| {
            allocator.free(col);
        }
        for (self.values.items) |val| {
            allocator.free(val);
        }
        self.columns.deinit(allocator);
        self.values.deinit(allocator);
    }

    pub fn clone(self: *const Row, allocator: Allocator) !Row {
        var new_columns = try std.ArrayList([]const u8).initCapacity(allocator, self.columns.items.len);
        var new_values = try std.ArrayList([]const u8).initCapacity(allocator, self.values.items.len);

        for (self.columns.items) |col| {
            try new_columns.append(try allocator.dupe(u8, col));
        }
        for (self.values.items) |val| {
            try new_values.append(try allocator.dupe(u8, val));
        }

        return Row{
            .columns = new_columns,
            .values = new_values,
        };
    }
};

/// PostgreSQL errors
pub const Error = error{
    ConnectionFailed,
    QueryFailed,
    ParseError,
    InvalidUrl,
    AuthenticationNotImplemented,
    UnexpectedMessage,
    PostgresError,
    ConnectionClosed,
};

// ═══════════════════════════════════════════════════════════════════════════════
// WIRE PROTOCOL MESSAGE BUILDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Build PostgreSQL StartupMessage
/// Format: [len:4][version:4][user\0user_name\0database\0db_name\0...\0]
pub fn buildStartupMessage(allocator: Allocator, user: []const u8, database: []const u8) ![]u8 {
    // Each parameter is a NUL-terminated key followed by a NUL-terminated value,
    // and the whole list ends with one more NUL. The keys carry their own
    // terminator here ("user\x00" is five bytes, "database\x00" is nine), which
    // is why no separate NUL is written after them.
    //
    // Two bugs lived here: @memcpy was handed a five-byte destination and the
    // four-byte "user", which panics on non-equal lengths in safe builds, and
    // the size counted a terminator after each key that the literals already
    // included — two bytes of slack the server would read as a malformed
    // parameter list.
    const user_key = "user\x00";
    const database_key = "database\x00";
    const size = 4 + 4 + user_key.len + user.len + 1 + database_key.len + database.len + 1 + 1;

    const msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    std.mem.writeInt(u32, msg[0..4], @intCast(size), .big);
    std.mem.writeInt(u32, msg[4..8], PROTOCOL_VERSION, .big);
    var offset: usize = 8;

    @memcpy(msg[offset..][0..user_key.len], user_key);
    offset += user_key.len;
    @memcpy(msg[offset..][0..user.len], user);
    offset += user.len;
    msg[offset] = 0;
    offset += 1;

    @memcpy(msg[offset..][0..database_key.len], database_key);
    offset += database_key.len;
    @memcpy(msg[offset..][0..database.len], database);
    offset += database.len;
    msg[offset] = 0;
    offset += 1;

    // End of the parameter list.
    msg[offset] = 0;

    return msg;
}

/// Build Query message ('Q')
/// Format: [type:1='Q'][len:4][query_string\0]
pub fn buildQueryMessage(allocator: Allocator, sql: []const u8) ![]u8 {
    const size = 1 + 4 + sql.len + 1;

    var msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    msg[0] = @intFromEnum(MessageType.Query);
    std.mem.writeInt(u32, msg[1..5], @intCast(sql.len + 1), .big);
    @memcpy(msg[5..5+sql.len], sql);
    msg[5 + sql.len] = 0;

    return msg;
}

/// Build AuthenticationOk response ('R')
/// For server-side use only
pub fn buildAuthenticationOk(allocator: Allocator) ![]u8 {
    const size = 1 + 4 + 4; // type + len + auth_code

    var msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    msg[0] = @intFromEnum(MessageType.AuthenticationOk);
    std.mem.writeInt(u32, msg[1..5], 4, .big); // length of auth_code
    std.mem.writeInt(u32, msg[5..9], 0, .big); // AUTH_OK

    return msg;
}

/// Build BackendKeyData response ('K')
/// For server-side use only
/// Format: [type:1='K'][len:4][pid:4][key:4]
pub fn buildBackendKeyData(allocator: Allocator, pid: i32, key: i32) ![]u8 {
    const size = 1 + 4 + 8;

    var msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    msg[0] = @intFromEnum(MessageType.BackendKeyData);
    std.mem.writeInt(u32, msg[1..5], 8, .big);
    std.mem.writeInt(i32, msg[5..9], pid, .big);
    std.mem.writeInt(i32, msg[9..13], key, .big);

    return msg;
}

/// Build ReadyForQuery response ('Z')
/// For server-side use only
/// Format: [type:1='Z'][len:4][status:1]
pub fn buildReadyForQuery(allocator: Allocator, status: TransactionStatus) ![]u8 {
    const size = 1 + 4 + 1;

    var msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    msg[0] = @intFromEnum(MessageType.ReadyForQuery);
    std.mem.writeInt(u32, msg[1..5], 1, .big);
    msg[5] = @intFromEnum(status);

    return msg;
}

/// Build CommandComplete response ('C')
/// For server-side use only
/// Format: [type:1='C'][len:4][tag\0]
pub fn buildCommandComplete(allocator: Allocator, tag: []const u8) ![]u8 {
    const size = 1 + 4 + tag.len + 1;

    var msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    msg[0] = @intFromEnum(MessageType.CommandComplete);
    std.mem.writeInt(u32, msg[1..5], @intCast(tag.len + 1), .big);
    @memcpy(msg[5..5+tag.len], tag);
    msg[5 + tag.len] = 0;

    return msg;
}

/// Build ErrorResponse ('E')
/// For server-side use only
/// Format: [type:1='E'][len:4][field_type:1][value\0]...[0]
pub fn buildErrorResponse(allocator: Allocator, message: []const u8) ![]u8 {
    // Field type 'M' for message
    const size = 1 + 4 + 1 + message.len + 1 + 1;

    var msg = try allocator.alloc(u8, size);
    errdefer allocator.free(msg);

    msg[0] = @intFromEnum(MessageType.ErrorResponse);
    std.mem.writeInt(u32, msg[1..5], @intCast(size - 5), .big);
    msg[5] = 'M'; // Message field
    @memcpy(msg[6..6+message.len], message);
    msg[6 + message.len] = 0; // Null terminator for value
    msg[6 + message.len + 1] = 0; // Terminator

    return msg;
}
