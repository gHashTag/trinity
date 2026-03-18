// ═══════════════════════════════════════════════════════════════════════════════
// I/O PATTERNS - Read, Write, Load, Save, Store, Retrieve (PRE: 16%)
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Match I/O patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {
    // Pattern: read* -> read file contents
    if (std.mem.startsWith(u8, b.name, "read")) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, path: []const u8) ![]u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Read entire file into memory");
        try builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("return try file.readToEndAlloc(allocator, 1024 * 1024);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: write* -> write data to file
    if (std.mem.startsWith(u8, b.name, "write")) {
        try builder.writeFmt("pub fn {s}(path: []const u8, data: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Write data to file");
        try builder.writeLine("const file = try std.fs.cwd().createFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("try file.writeAll(data);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: load* -> load data
    if (std.mem.startsWith(u8, b.name, "load")) {
        try builder.writeFmt("pub fn {s}(path: []const u8, allocator: std.mem.Allocator) ![]u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Load entire file into memory");
        try builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("return file.readToEndAlloc(allocator, 1024 * 1024);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: save* -> save data
    if (std.mem.startsWith(u8, b.name, "save")) {
        try builder.writeFmt("pub fn {s}(data: []const u8, path: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Save data to file");
        try builder.writeLine("const file = try std.fs.cwd().createFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("try file.writeAll(data);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: store* -> store data
    if (std.mem.startsWith(u8, b.name, "store")) {
        try builder.writeFmt("pub fn {s}(map: *std.StringHashMap([]const u8), key: []const u8, value: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Store key-value pair in map");
        try builder.writeLine("try map.put(key, value);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: retrieve* -> retrieve data
    if (std.mem.startsWith(u8, b.name, "retrieve")) {
        try builder.writeFmt("pub fn {s}(map: *const std.StringHashMap([]const u8), key: []const u8) ?[]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Retrieve value by key");
        try builder.writeLine("return map.get(key);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: cache* -> caching
    if (std.mem.startsWith(u8, b.name, "cache")) {
        try builder.writeFmt("pub fn {s}(key: []const u8, value: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Cache value");
        try builder.writeLine("_ = key; _ = value;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: fetch* -> fetch data
    if (std.mem.startsWith(u8, b.name, "fetch")) {
        try builder.writeFmt("pub fn {s}(url: []const u8) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Fetch from URL");
        try builder.writeLine("_ = url;");
        try builder.writeLine("return &[_]u8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: import* -> import data
    if (std.mem.startsWith(u8, b.name, "import")) {
        try builder.writeFmt("pub fn {s}(source: []const u8) !ImportResult {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Import from source");
        try builder.writeLine("_ = source;");
        try builder.writeLine("return ImportResult{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: export* -> export data
    if (std.mem.startsWith(u8, b.name, "export")) {
        try builder.writeFmt("pub fn {s}(data: anytype, dest: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Export to destination");
        try builder.writeLine("_ = data; _ = dest;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: open* -> open resource
    if (std.mem.startsWith(u8, b.name, "open")) {
        try builder.writeFmt("pub fn {s}(path: []const u8) !Handle {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Open resource");
        try builder.writeLine("_ = path;");
        try builder.writeLine("return Handle{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: close* -> close resource
    if (std.mem.startsWith(u8, b.name, "close")) {
        try builder.writeFmt("pub fn {s}(file: std.fs.File) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Close file resource");
        try builder.writeLine("file.close();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: connect* -> connect
    if (std.mem.startsWith(u8, b.name, "connect")) {
        try builder.writeFmt("pub fn {s}(target: []const u8) !Connection {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Connect to target");
        try builder.writeLine("_ = target;");
        try builder.writeLine("return Connection{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: disconnect* -> disconnect
    if (std.mem.startsWith(u8, b.name, "disconnect")) {
        try builder.writeFmt("pub fn {s}(conn: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Disconnect");
        try builder.writeLine("_ = conn;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: send* -> send data
    if (std.mem.startsWith(u8, b.name, "send")) {
        try builder.writeFmt("pub fn {s}(dest: anytype, data: []const u8) !void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Send data");
        try builder.writeLine("_ = dest; _ = data;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: receive* -> receive data
    if (std.mem.startsWith(u8, b.name, "receive")) {
        try builder.writeFmt("pub fn {s}(source: anytype) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Receive data");
        try builder.writeLine("_ = source;");
        try builder.writeLine("return &[_]u8{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: stream* -> streaming
    if (std.mem.startsWith(u8, b.name, "stream")) {
        try builder.writeFmt("pub fn {s}(source: anytype) StreamIterator {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Create stream iterator");
        try builder.writeLine("_ = source;");
        try builder.writeLine("return StreamIterator{};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: mmap* -> memory mapping
    if (std.mem.startsWith(u8, b.name, "mmap")) {
        try builder.writeFmt("pub fn {s}(path: []const u8, allocator: std.mem.Allocator) ![]align(4096) u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Memory map file (read-only)");
        try builder.writeLine("const file = try std.fs.cwd().openFile(path, .{});");
        try builder.writeLine("defer file.close();");
        try builder.writeLine("const file_size = try file.getEndPos();");
        try builder.writeLine("const ptr = try std.os.mmap(null, file_size, std.os.PROT.READ, std.os.MAP.PRIVATE, file.handle, 0);");
        try builder.writeLine("return ptr[0..file_size];");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: prefetch* -> prefetching
    if (std.mem.startsWith(u8, b.name, "prefetch")) {
        try builder.writeFmt("pub fn {s}(addr: anytype) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Prefetch data into cache");
        try builder.writeLine("_ = addr;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: memory* -> memory operations
    if (std.mem.startsWith(u8, b.name, "memory")) {
        try builder.writeFmt("pub fn {s}(key: []const u8) ?[]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Memory operation");
        try builder.writeLine("_ = key;");
        try builder.writeLine("return null;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: recall* -> memory recall
    if (std.mem.startsWith(u8, b.name, "recall")) {
        try builder.writeFmt("pub fn {s}(key: []const u8) ?[]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Recall value from memory");
        try builder.writeLine("_ = key;");
        try builder.writeLine("return null;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: http_client* -> HTTP client with std.http.Client
    if (std.mem.startsWith(u8, b.name, "http_client")) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, url: []const u8, method: []const u8) ![]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// HTTP client with full request/response handling");
        try builder.writeLine("var client = std.http.Client{ .allocator = allocator };");
        try builder.writeLine("defer client.deinit();");
        try builder.writeLine("");
        try builder.writeLine("const uri = try std.Uri.parse(url);");
        try builder.writeLine("var req = try client.open(method, uri, .{ .redirect_behavior = .not_allowed });");
        try builder.writeLine("defer req.deinit();");
        try builder.writeLine("");
        try builder.writeLine("try req.send(.{});");
        try builder.writeLine("try req.finish();");
        try builder.writeLine("");
        try builder.writeLine("const body = try req.reader().readAllAlloc(allocator, 10 * 1024 * 1024);");
        try builder.writeLine("return body;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: websocket* -> WebSocket client/server
    if (std.mem.startsWith(u8, b.name, "websocket")) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, url: []const u8) !WebSocketClient {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// WebSocket client with handshake and message handling");
        try builder.writeLine("var client = std.http.Client{ .allocator = allocator };");
        try builder.writeLine("defer client.deinit();");
        try builder.writeLine("");
        try builder.writeLine("const uri = try std.Uri.parse(url);");
        try builder.writeLine("var req = try client.open(\"GET\", uri, .{");
        try builder.writeLine("    .header = .{");
        try builder.writeLine("        .Upgrade = \"websocket\",");
        try builder.writeLine("        .Connection = \"Upgrade\",");
        try builder.writeLine("        .Sec_WebSocket_Key = \"dGhlIHNhbXBsZSBub25jZQ==\",");
        try builder.writeLine("        .Sec_WebSocket_Version = \"13\",");
        try builder.writeLine("    },");
        try builder.writeLine("});");
        try builder.writeLine("defer req.deinit();");
        try builder.writeLine("");
        try builder.writeLine("try req.send(.{});");
        try builder.writeLine("try req.finish();");
        try builder.writeLine("");
        try builder.writeLine("return WebSocketClient{");
        try builder.writeLine("    .allocator = allocator,");
        try builder.writeLine("    .stream = req.transfer.?,");
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: sqlite* -> SQLite database operations
    if (std.mem.startsWith(u8, b.name, "sqlite")) {
        try builder.writeFmt("pub fn {s}(allocator: std.mem.Allocator, db_path: []const u8, query: []const u8) ![][]const u8 {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// SQLite query execution (using sqlite3 C API)");
        try builder.writeLine("const c = @cImport({");
        try builder.writeLine("    @cInclude(\"sqlite3.h\"),");
        try builder.writeLine("});");
        try builder.writeLine("");
        try builder.writeLine("var db: ?*c.sqlite3 = null;");
        try builder.writeLine("const rc = c.sqlite3_open(db_path.ptr, &db);");
        try builder.writeLine("if (rc != c.SQLITE_OK) return error.DatabaseOpenError;");
        try builder.writeLine("defer c.sqlite3_close(db);");
        try builder.writeLine("");
        try builder.writeLine("var stmt: ?*c.sqlite3_stmt = null;");
        try builder.writeLine("if (c.sqlite3_prepare_v2(db, query.ptr, @intCast(query.len), &stmt, null) != c.SQLITE_OK) {");
        try builder.writeLine("    return error.PreparedStatementError;");
        try builder.writeLine("}");
        try builder.writeLine("defer c.sqlite3_finalize(stmt);");
        try builder.writeLine("");
        try builder.writeLine("var results = std.ArrayList([]const u8).init(allocator);");
        try builder.writeLine("errdefer results.deinit();");
        try builder.writeLine("");
        try builder.writeLine("while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {");
        try builder.writeLine("    const col_count = c.sqlite3_column_count(stmt);");
        try builder.writeLine("    for (0..@intCast(col_count)) |i| {");
        try builder.writeLine("        const text = c.sqlite3_column_text(stmt, @intCast(i));");
        try builder.writeLine("        const len = c.sqlite3_column_bytes(stmt, @intCast(i));");
        try builder.writeLine("        const slice = try allocator.dupe(u8, @ptrCast([*]const u8, text)[0..@intCast(len)]);");
        try builder.writeLine("        try results.append(slice);");
        try builder.writeLine("    }");
        try builder.writeLine("}");
        try builder.writeLine("");
        try builder.writeLine("return try results.toOwnedSlice();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false;
}
