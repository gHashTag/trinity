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
    /// Percent-decoding: a generated password routinely contains characters that
    /// only survive a URL as %XX, and sending them raw fails authentication in a
    /// way that looks like a wrong password.
    fn percentDecode(allocator: Allocator, text: []const u8) ![]u8 {
        var out = try std.ArrayList(u8).initCapacity(allocator, text.len);
        errdefer out.deinit(allocator);
        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == '%' and i + 2 < text.len) {
                const hi = std.fmt.charToDigit(text[i + 1], 16) catch { try out.append(allocator, text[i]); i += 1; continue; };
                const lo = std.fmt.charToDigit(text[i + 2], 16) catch { try out.append(allocator, text[i]); i += 1; continue; };
                try out.append(allocator, @intCast(hi * 16 + lo));
                i += 3;
            } else {
                try out.append(allocator, text[i]);
                i += 1;
            }
        }
        return out.toOwnedSlice(allocator);
    }

    pub fn connect(self: *PostgresClient, database_url: []const u8) !void {
        // scheme://[user[:password]@]host[:port]/database[?params]
        //
        // The previous parser split the whole URL on '/' and took the second
        // field as the credentials. In "postgres://u:p@h:5432/db" that field is
        // the empty string between the two slashes of "//", so the user was
        // always empty and the server answered "no PostgreSQL user name
        // specified in startup packet" — a wrong-credentials error caused by
        // parsing, not by credentials.
        const scheme_end = std.mem.indexOf(u8, database_url, "://") orelse return error.InvalidUrl;
        var rest = database_url[scheme_end + 3 ..];

        // Strip any query string: it is not part of the database name.
        if (std.mem.indexOfScalar(u8, rest, '?')) |q| rest = rest[0..q];

        const slash = std.mem.indexOfScalar(u8, rest, '/');
        const authority = if (slash) |i| rest[0..i] else rest;
        const db_name = if (slash) |i| rest[i + 1 ..] else "";

        // The last '@' separates userinfo from the host: a password may contain one.
        var userinfo: []const u8 = "";
        var host_port: []const u8 = authority;
        if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| {
            userinfo = authority[0..at];
            host_port = authority[at + 1 ..];
        }

        // The last ':' separates the port, which lets an IPv6 literal keep its colons.
        if (std.mem.lastIndexOfScalar(u8, host_port, ':')) |colon| {
            self.host = host_port[0..colon];
            self.port = std.fmt.parseInt(u16, host_port[colon + 1 ..], 10) catch 5432;
        } else {
            self.host = if (host_port.len > 0) host_port else "localhost";
            self.port = 5432;
        }

        // The first ':' separates user from password: a password may contain one.
        if (std.mem.indexOfScalar(u8, userinfo, ':')) |colon| {
            self.user = try percentDecode(self.allocator, userinfo[0..colon]);
            self.password = try percentDecode(self.allocator, userinfo[colon + 1 ..]);
        } else {
            self.user = try percentDecode(self.allocator, userinfo);
            self.password = "";
        }
        if (self.user.len == 0) return error.InvalidUrl;

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
        try self.handleAuthentication(&stream);

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
    /// Read exactly buf.len bytes, or fail. A single read() returns what has
    /// arrived, not what was asked for.
    fn readExactly(stream: *net.Stream, buf: []u8) !void {
        var got: usize = 0;
        while (got < buf.len) {
            const n = try stream.read(buf[got..]);
            if (n == 0) return error.UnexpectedEndOfStream;
            got += n;
        }
    }

    const Message = struct { kind: u8, payload: []u8 };

    /// Every backend message is [type:1][len:4][payload], and the length counts
    /// itself but not the type byte. The previous reader took the length first
    /// and the type second, so it mistook the top byte of the length for the
    /// message type and misread every message it ever saw.
    fn readMessage(allocator: Allocator, stream: *net.Stream) !Message {
        var head: [5]u8 = undefined;
        try readExactly(stream, &head);
        const len = std.mem.readInt(u32, head[1..5], .big);
        if (len < 4) return error.InvalidMessage;
        const payload = try allocator.alloc(u8, len - 4);
        errdefer allocator.free(payload);
        if (payload.len > 0) try readExactly(stream, payload);
        return .{ .kind = head[0], .payload = payload };
    }

    fn sendPassword(stream: *net.Stream, allocator: Allocator, body: []const u8) !void {
        const msg = try allocator.alloc(u8, 5 + body.len);
        defer allocator.free(msg);
        msg[0] = 'p';
        std.mem.writeInt(u32, msg[1..5], @intCast(4 + body.len), .big);
        @memcpy(msg[5..], body);
        try stream.writeAll(msg);
    }

    fn b64Encode(allocator: Allocator, raw: []const u8) ![]u8 {
        const enc = std.base64.standard.Encoder;
        const out = try allocator.alloc(u8, enc.calcSize(raw.len));
        _ = enc.encode(out, raw);
        return out;
    }

    fn b64Decode(allocator: Allocator, text: []const u8) ![]u8 {
        const dec = std.base64.standard.Decoder;
        const size = try dec.calcSizeForSlice(text);
        const out = try allocator.alloc(u8, size);
        errdefer allocator.free(out);
        try dec.decode(out, text);
        return out;
    }

    fn fieldAfter(text: []const u8, prefix: []const u8) ?[]const u8 {
        var it = std.mem.splitScalar(u8, text, ',');
        while (it.next()) |part| {
            if (std.mem.startsWith(u8, part, prefix)) return part[prefix.len..];
        }
        return null;
    }

    /// SCRAM-SHA-256 (RFC 5802) over Postgres SASL framing.
    ///
    /// The client used to understand one thing only: AuthenticationOk, the
    /// answer a server gives when it asks for no password at all. Every managed
    /// database asks for SCRAM, so the agent could never connect to one and ran
    /// with its sessions in memory instead.
    fn scram(self: *PostgresClient, stream: *net.Stream) !void {
        const allocator = self.allocator;

        var nonce_raw: [18]u8 = undefined;
        std.crypto.random.bytes(&nonce_raw);
        const client_nonce = try b64Encode(allocator, &nonce_raw);
        defer allocator.free(client_nonce);

        const client_first_bare = try std.fmt.allocPrint(allocator, "n=,r={s}", .{client_nonce});
        defer allocator.free(client_first_bare);

        // SASLInitialResponse: mechanism, then the length of what follows.
        const mechanism = "SCRAM-SHA-256";
        const initial = try allocator.alloc(u8, mechanism.len + 1 + 4 + 3 + client_first_bare.len);
        defer allocator.free(initial);
        @memcpy(initial[0..mechanism.len], mechanism);
        initial[mechanism.len] = 0;
        std.mem.writeInt(u32, initial[mechanism.len + 1 ..][0..4], @intCast(3 + client_first_bare.len), .big);
        @memcpy(initial[mechanism.len + 5 ..][0..3], "n,,");
        @memcpy(initial[mechanism.len + 8 ..], client_first_bare);
        try sendPassword(stream, allocator, initial);

        // AuthenticationSASLContinue: r=<nonce>,s=<salt>,i=<iterations>
        const cont = try readMessage(allocator, stream);
        defer allocator.free(cont.payload);
        if (cont.kind == 'E') return error.AuthenticationFailed;
        if (cont.kind != 'R' or cont.payload.len < 4) return error.UnexpectedMessage;
        if (std.mem.readInt(u32, cont.payload[0..4], .big) != 11) return error.UnexpectedMessage;
        const server_first = cont.payload[4..];

        const combined_nonce = fieldAfter(server_first, "r=") orelse return error.InvalidMessage;
        const salt_b64 = fieldAfter(server_first, "s=") orelse return error.InvalidMessage;
        const iter_text = fieldAfter(server_first, "i=") orelse return error.InvalidMessage;
        const iterations = try std.fmt.parseInt(u32, iter_text, 10);
        if (!std.mem.startsWith(u8, combined_nonce, client_nonce)) return error.InvalidMessage;

        const salt = try b64Decode(allocator, salt_b64);
        defer allocator.free(salt);

        var salted: [32]u8 = undefined;
        try std.crypto.pwhash.pbkdf2(&salted, self.password, salt, iterations, std.crypto.auth.hmac.sha2.HmacSha256);

        const Hmac = std.crypto.auth.hmac.sha2.HmacSha256;
        var client_key: [32]u8 = undefined;
        Hmac.create(&client_key, "Client Key", &salted);
        var stored_key: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&client_key, &stored_key, .{});

        const client_final_bare = try std.fmt.allocPrint(allocator, "c=biws,r={s}", .{combined_nonce});
        defer allocator.free(client_final_bare);
        const auth_message = try std.fmt.allocPrint(allocator, "{s},{s},{s}", .{ client_first_bare, server_first, client_final_bare });
        defer allocator.free(auth_message);

        var client_sig: [32]u8 = undefined;
        Hmac.create(&client_sig, auth_message, &stored_key);
        var proof: [32]u8 = undefined;
        for (client_key, client_sig, 0..) |k, sig, i| proof[i] = k ^ sig;

        const proof_b64 = try b64Encode(allocator, &proof);
        defer allocator.free(proof_b64);
        const client_final = try std.fmt.allocPrint(allocator, "{s},p={s}", .{ client_final_bare, proof_b64 });
        defer allocator.free(client_final);
        try sendPassword(stream, allocator, client_final);

        // AuthenticationSASLFinal carries the server's own proof. Verifying it is
        // what makes this mutual: without the check a man in the middle could
        // replay a success we would believe.
        const fin = try readMessage(allocator, stream);
        defer allocator.free(fin.payload);
        if (fin.kind == 'E') return error.AuthenticationFailed;
        if (fin.kind != 'R' or fin.payload.len < 4) return error.UnexpectedMessage;
        if (std.mem.readInt(u32, fin.payload[0..4], .big) != 12) return error.UnexpectedMessage;

        const server_sig_b64 = fieldAfter(fin.payload[4..], "v=") orelse return error.InvalidMessage;
        const server_sig_given = try b64Decode(allocator, server_sig_b64);
        defer allocator.free(server_sig_given);

        var server_key: [32]u8 = undefined;
        Hmac.create(&server_key, "Server Key", &salted);
        var server_sig: [32]u8 = undefined;
        Hmac.create(&server_sig, auth_message, &server_key);
        if (server_sig_given.len != server_sig.len) return error.AuthenticationFailed;
        if (!std.crypto.timing_safe.eql([32]u8, server_sig_given[0..32].*, server_sig)) return error.AuthenticationFailed;
    }

    /// An ErrorResponse is a run of [field:1][value\0] pairs; 'M' is the message
    /// a human needs, 'C' the SQLSTATE.
    fn describeError(payload: []const u8) []const u8 {
        var i: usize = 0;
        while (i < payload.len and payload[i] != 0) {
            const code = payload[i];
            const start = i + 1;
            var end = start;
            while (end < payload.len and payload[end] != 0) end += 1;
            if (code == 'M') return payload[start..end];
            i = end + 1;
        }
        return "no message";
    }

    fn handleAuthentication(self: *PostgresClient, stream: *net.Stream) !void {
        const allocator = self.allocator;
        while (true) {
            const msg = try readMessage(allocator, stream);
            defer allocator.free(msg.payload);
            switch (msg.kind) {
                'E' => {
                    // The server's own words. Swallowing them left every
                    // failure looking identical from the outside.
                    std.log.err("postgres refused the connection: {s}", .{describeError(msg.payload)});
                    return error.AuthenticationFailed;
                },
                'R' => {
                    if (msg.payload.len < 4) return error.InvalidMessage;
                    switch (std.mem.readInt(u32, msg.payload[0..4], .big)) {
                        0 => return,
                        10 => try self.scram(stream),
                        else => return error.AuthenticationNotImplemented,
                    }
                },
                else => return error.UnexpectedMessage,
            }
        }
    }

    /// Wait for ReadyForQuery message
    fn waitForReady(self: *PostgresClient, stream: *net.Stream) !void {
        // Between authentication and readiness the server sends a run of
        // ParameterStatus messages and a BackendKeyData, and their number is its
        // business, not ours. The previous version read one message, understood
        // three kinds and rejected the rest — so the very first ParameterStatus
        // ended the connection with UnexpectedMessage.
        while (true) {
            const msg = try readMessage(self.allocator, stream);
            defer self.allocator.free(msg.payload);
            switch (msg.kind) {
                'Z' => {
                    if (msg.payload.len >= 1) self.transaction_status = @enumFromInt(msg.payload[0]);
                    return;
                },
                'K' => {
                    if (msg.payload.len >= 8) {
                        self.backend_pid = std.mem.readInt(i32, msg.payload[0..4], .big);
                        self.backend_key = std.mem.readInt(i32, msg.payload[4..8], .big);
                    }
                },
                'E' => {
                    std.log.err("postgres error before ready: {s}", .{describeError(msg.payload)});
                    return error.QueryFailed;
                },
                // ParameterStatus, NoticeResponse and anything else the server
                // volunteers: read past it rather than treating it as a fault.
                else => {},
            }
        }
    }

    /// Read query response from server
    fn readQueryResponse(self: *PostgresClient, stream: *net.Stream, result: *QueryResult) !void {
        // This used to discard the result outright — `_ = result` — so every
        // query returned zero rows however many the server sent, and listing
        // sessions could only ever answer with an empty array. It also read
        // headers with bare read() calls that may return short, which desynced
        // the stream and killed the connection on the next query with a broken
        // pipe.
        const allocator = self.allocator;
        var columns = try std.ArrayList([]const u8).initCapacity(allocator, 8);
        defer {
            for (columns.items) |c| allocator.free(c);
            columns.deinit(allocator);
        }

        while (true) {
            const msg = try readMessage(allocator, stream);
            defer allocator.free(msg.payload);

            switch (msg.kind) {
                // RowDescription: the column names this result set carries.
                'T' => {
                    for (columns.items) |c| allocator.free(c);
                    columns.clearRetainingCapacity();
                    if (msg.payload.len < 2) continue;
                    const count = std.mem.readInt(u16, msg.payload[0..2], .big);
                    var at: usize = 2;
                    var i: u16 = 0;
                    while (i < count and at < msg.payload.len) : (i += 1) {
                        const nul = std.mem.indexOfScalarPos(u8, msg.payload, at, 0) orelse break;
                        try columns.append(allocator, try allocator.dupe(u8, msg.payload[at..nul]));
                        at = nul + 1 + 18; // the field's fixed descriptor follows its name
                    }
                },
                // DataRow: one row, each value length-prefixed; -1 means NULL.
                'D' => {
                    if (msg.payload.len < 2) continue;
                    const count = std.mem.readInt(u16, msg.payload[0..2], .big);
                    var row = Row{
                        .columns = try std.ArrayList([]const u8).initCapacity(allocator, count),
                        .values = try std.ArrayList([]const u8).initCapacity(allocator, count),
                    };
                    errdefer row.deinit(allocator);

                    var at: usize = 2;
                    var i: u16 = 0;
                    while (i < count and at + 4 <= msg.payload.len) : (i += 1) {
                        const len = std.mem.readInt(i32, msg.payload[at..][0..4], .big);
                        at += 4;
                        const value = if (len < 0) "" else blk: {
                            const n: usize = @intCast(len);
                            if (at + n > msg.payload.len) break :blk "";
                            const v = msg.payload[at .. at + n];
                            at += n;
                            break :blk v;
                        };
                        const name = if (i < columns.items.len) columns.items[i] else "";
                        try row.columns.append(allocator, try allocator.dupe(u8, name));
                        try row.values.append(allocator, try allocator.dupe(u8, value));
                    }
                    try result.rows.append(allocator, row);
                },
                'C' => result.affected_rows = result.rows.items.len,
                'Z' => {
                    if (msg.payload.len >= 1) self.transaction_status = @enumFromInt(msg.payload[0]);
                    return;
                },
                'E' => {
                    std.log.err("postgres rejected the query: {s}", .{describeError(msg.payload)});
                    return error.QueryFailed;
                },
                else => {},
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
        // Zig 0.15's ArrayList holds no allocator of its own, so freeing needs
        // the one that allocated. Nothing called this before, which is why a
        // missing argument sat here compiling fine until it was used.
        self.rows.deinit(allocator);
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
    // The length counts itself and the payload, but not the type byte. Leaving
    // its own four bytes out told the server the message ended four bytes early,
    // and it answered "invalid string in message" for every query sent.
    std.mem.writeInt(u32, msg[1..5], @intCast(4 + sql.len + 1), .big);
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
