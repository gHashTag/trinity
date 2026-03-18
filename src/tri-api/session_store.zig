// session_store.zig — Persistent conversation sessions for tri-api
// Storage: ~/.tri-api/sessions/ with index.json + per-session {id}.json
// Issue #64: Phase 5 native sessions
const std = @import("std");
const proto = @import("tool_protocol.zig");

const sessions_subdir = ".tri-api/sessions";
const index_filename = "index.json";
const max_file_size = 10 * 1024 * 1024; // 10MB per session

pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    base_dir: []const u8, // resolved absolute path
    base_dir_owned: bool = true,

    /// Initialize with resolved ~/.tri-api/sessions path.
    pub fn init(allocator: std.mem.Allocator) SessionStore {
        const home = std.posix.getenv("HOME") orelse "/tmp";
        const base = std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, sessions_subdir }) catch
            return .{ .allocator = allocator, .base_dir = "/tmp/.tri-api/sessions", .base_dir_owned = false };
        return .{ .allocator = allocator, .base_dir = base, .base_dir_owned = true };
    }

    pub fn deinit(self: *SessionStore) void {
        if (self.base_dir_owned) self.allocator.free(self.base_dir);
    }

    /// Save a session: write {id}.json and append to index.json.
    pub fn save(self: *SessionStore, messages_json: []const u8, prompt: []const u8) void {
        // Ensure directory exists
        std.fs.cwd().makePath(self.base_dir) catch return;

        // Generate session ID from timestamp (hex, 8 chars)
        const ts = std.time.timestamp();
        var id_buf: [8]u8 = undefined;
        _ = std.fmt.bufPrint(&id_buf, "{x:0>8}", .{@as(u32, @truncate(@as(u64, @intCast(ts))))}) catch return;
        const id = &id_buf;

        // Write session file: {id}.json
        var session_path_buf: [512]u8 = undefined;
        const session_path = std.fmt.bufPrint(&session_path_buf, "{s}/{s}.json", .{ self.base_dir, id }) catch return;

        var session_body: std.ArrayList(u8) = .empty;
        defer session_body.deinit(self.allocator);

        session_body.appendSlice(self.allocator, "{\"id\":\"") catch return;
        session_body.appendSlice(self.allocator, id) catch return;
        session_body.appendSlice(self.allocator, "\",\"ts\":") catch return;
        var ts_buf: [20]u8 = undefined;
        const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{ts}) catch return;
        session_body.appendSlice(self.allocator, ts_str) catch return;
        session_body.appendSlice(self.allocator, ",\"messages\":\"") catch return;
        // Escape the messages JSON as a string value
        proto.writeJsonEscaped(session_body.writer(self.allocator), messages_json) catch return;
        session_body.appendSlice(self.allocator, "\"}") catch return;

        writeFileAbs(session_path, session_body.items) catch return;

        // Update index.json: read existing, append entry
        var index_path_buf: [512]u8 = undefined;
        const index_path = std.fmt.bufPrint(&index_path_buf, "{s}/{s}", .{ self.base_dir, index_filename }) catch return;

        const preview_len = @min(prompt.len, 80);
        var entry: std.ArrayList(u8) = .empty;
        defer entry.deinit(self.allocator);

        entry.appendSlice(self.allocator, "{\"id\":\"") catch return;
        entry.appendSlice(self.allocator, id) catch return;
        entry.appendSlice(self.allocator, "\",\"ts\":") catch return;
        entry.appendSlice(self.allocator, ts_str) catch return;
        entry.appendSlice(self.allocator, ",\"preview\":\"") catch return;
        proto.writeJsonEscaped(entry.writer(self.allocator), prompt[0..preview_len]) catch return;
        entry.appendSlice(self.allocator, "\"}") catch return;

        // Read existing index or start new
        const existing = readFileAbs(self.allocator, index_path) catch null;
        var new_index: std.ArrayList(u8) = .empty;
        defer new_index.deinit(self.allocator);

        if (existing) |idx| {
            defer self.allocator.free(idx);
            // Strip trailing ] and append
            if (idx.len > 2 and idx[idx.len - 1] == ']') {
                new_index.appendSlice(self.allocator, idx[0 .. idx.len - 1]) catch return;
                new_index.appendSlice(self.allocator, ",") catch return;
            } else {
                new_index.appendSlice(self.allocator, "[") catch return;
            }
        } else {
            new_index.appendSlice(self.allocator, "[") catch return;
        }
        new_index.appendSlice(self.allocator, entry.items) catch return;
        new_index.appendSlice(self.allocator, "]") catch return;

        writeFileAbs(index_path, new_index.items) catch |err| {
            std.log.warn("session_store: failed to write index {s}: {}", .{ index_path, err });
        };

        std.debug.print("[tri-api] Session saved: {s}\n", .{id});
    }

    /// Load a session by ID. Returns the messages JSON (caller owns memory).
    pub fn load(self: *SessionStore, session_id: []const u8) ?[]const u8 {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.json", .{ self.base_dir, session_id }) catch return null;

        const content = readFileAbs(self.allocator, path) catch return null;
        defer self.allocator.free(content);

        // Extract "messages":"..." — it's stored as escaped string
        const messages_escaped = proto.extractField(content, "messages") orelse return null;
        return proto.unescapeString(self.allocator, messages_escaped) catch return null;
    }

    /// Load the most recent session. Returns messages JSON (caller owns memory).
    pub fn loadLatest(self: *SessionStore) ?[]const u8 {
        var index_path_buf: [512]u8 = undefined;
        const index_path = std.fmt.bufPrint(&index_path_buf, "{s}/{s}", .{ self.base_dir, index_filename }) catch return null;

        const index_content = readFileAbs(self.allocator, index_path) catch return null;
        defer self.allocator.free(index_content);

        // Find the last "id":" in index
        const needle = "\"id\":\"";
        var last_pos: ?usize = null;
        var pos: usize = 0;
        while (pos < index_content.len) {
            if (std.mem.indexOfPos(u8, index_content, pos, needle)) |idx| {
                last_pos = idx;
                pos = idx + needle.len;
            } else break;
        }

        if (last_pos) |lp| {
            const id_start = lp + needle.len;
            var id_end = id_start;
            while (id_end < index_content.len and index_content[id_end] != '"') : (id_end += 1) {}
            if (id_end > id_start) {
                return self.load(index_content[id_start..id_end]);
            }
        }
        return null;
    }

    /// List all sessions as formatted text. Caller owns memory.
    pub fn listSessions(self: *SessionStore) ?[]const u8 {
        var index_path_buf: [512]u8 = undefined;
        const index_path = std.fmt.bufPrint(&index_path_buf, "{s}/{s}", .{ self.base_dir, index_filename }) catch return null;

        const index_content = readFileAbs(self.allocator, index_path) catch return null;
        defer self.allocator.free(index_content);

        var out: std.ArrayList(u8) = .empty;
        out.appendSlice(self.allocator, "Sessions:\n") catch return null;

        // Scan for entries
        const id_needle = "\"id\":\"";
        const preview_needle = "\"preview\":\"";
        var pos: usize = 0;
        var count: u32 = 0;

        while (pos < index_content.len) {
            const id_idx = std.mem.indexOfPos(u8, index_content, pos, id_needle) orelse break;
            const id_start = id_idx + id_needle.len;
            var id_end = id_start;
            while (id_end < index_content.len and index_content[id_end] != '"') : (id_end += 1) {}
            const id = index_content[id_start..id_end];

            const preview = blk: {
                if (std.mem.indexOfPos(u8, index_content, id_end, preview_needle)) |pi| {
                    const ps = pi + preview_needle.len;
                    var pe = ps;
                    while (pe < index_content.len and index_content[pe] != '"') : (pe += 1) {}
                    break :blk index_content[ps..pe];
                }
                break :blk "(no preview)";
            };

            count += 1;
            var line_buf: [256]u8 = undefined;
            const line = std.fmt.bufPrint(&line_buf, "  {d}. [{s}] {s}\n", .{ count, id, preview }) catch break;
            out.appendSlice(self.allocator, line) catch break;

            pos = id_end + 1;
        }

        if (count == 0) {
            out.appendSlice(self.allocator, "  (no sessions yet)\n") catch |err| {
                std.log.debug("session_store: failed to append empty list text: {}", .{err});
            };
        }

        return out.toOwnedSlice(self.allocator) catch null;
    }
};

/// Read a file at an absolute path.
fn readFileAbs(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, max_file_size);
}

/// Write a file at an absolute path.
fn writeFileAbs(path: []const u8, data: []const u8) !void {
    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(data);
}
