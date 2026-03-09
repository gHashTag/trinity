//! NEEDLE MCP Server - Native Zig Model Context Protocol Server
//! Provides 5 tools for AST-aware code editing with safety gates
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Usage: ./zig-out/bin/needle-mcp

const std = @import("std");
const posix = std.posix;
const os = std.os;
const fs = std.fs;
const needle = @import("needle");

// Sacred constants
const PHI: f64 = 1.618033988749895;
const TRINITY_SUM: f64 = 3.0; // φ² + 1/φ² = 3
const PHOENIX: u16 = 999;

// MCP Protocol version
const PROTOCOL_VERSION = "2024-11-05";

// Server info
const SERVER_NAME = "needle-mcp";
const SERVER_VERSION = "1.0.0";

// ─────────────────────────────────────────────────────────────────────────────
// JSON Types for MCP Protocol (Zig 0.15)
// ─────────────────────────────────────────────────────────────────────────────

const JsonString = []const u8;

// ─────────────────────────────────────────────────────────────────────────────
// MCP Server
// ─────────────────────────────────────────────────────────────────────────────

const NeedleMCPServer = struct {
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) NeedleMCPServer {
        return .{
            .allocator = allocator,
        };
    }

    fn writeInitializeResponse(self: *NeedleMCPServer, writer: anytype) !void {
        _ = self;
        try writer.writeAll(
            \\{"jsonrpc":"2.0","result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"needle-mcp","version":"1.0.0"}}}
        );
    }

    fn writeToolsList(self: *NeedleMCPServer, writer: anytype) !void {
        _ = self;
        try writer.writeAll(
            \\{"jsonrpc":"2.0","result":{"tools":[
            \\{"name":"needle_structural_replace","description":"Apply AST-aware code edit with Tier 0->1 fallback and safety gates","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"},"safety_level":{"enum":["low","medium","high"]},"edit_mode":{"enum":["structural","semantic","text_fallback","auto"]}},"required":["file_path","pattern_query","replacement"]}},
            \\{"name":"needle_search","description":"Search codebase for pattern matches with confidence scores","inputSchema":{"type":"object","properties":{"query":{"type":"string"},"file_path":{"type":"string"},"confidence_threshold":{"type":"number"}},"required":["query","file_path"]}},
            \\{"name":"needle_quality_gates","description":"Run quality gates: parse check, AST analysis, violation detection","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"check_level":{"enum":["basic","full"]}},"required":["file_path"]}},
            \\{"name":"needle_preview","description":"Preview edit diff without applying changes","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"}},"required":["file_path","pattern_query","replacement"]}},
            \\{"name":"needle_batch_edit","description":"Apply multiple edits in a single operation","inputSchema":{"type":"object","properties":{"edits":{"type":"array","items":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"}},"required":["file_path","pattern_query","replacement"]}}},"required":["edits"]}},
            \\{"name":"needle_autonomous_refactor","description":"Execute Ralph Loop: intent-aware refactoring using semantic search + HNSW + VSA validation","inputSchema":{"type":"object","properties":{"intent":{"type":"string","description":"Natural language refactor intent (e.g., 'extract validation logic')"},"confidence_threshold":{"type":"number","description":"Minimum intent confidence (default: 0.8)"},"safety_level":{"enum":["low","medium","high","critical"],"description":"Safety level for refactoring"}},"required":["intent"]}}
            \\]}}
        );
    }

    fn handleToolsCall(self: *NeedleMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        if (std.mem.eql(u8, tool_name, "needle_structural_replace")) {
            try self.toolStructuralReplace(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "needle_search")) {
            try self.toolSearch(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "needle_quality_gates")) {
            try self.toolQualityGates(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "needle_preview")) {
            try self.toolPreview(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "needle_batch_edit")) {
            try self.toolBatchEdit(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "needle_autonomous_refactor")) {
            try self.toolAutonomousRefactor(arguments_json, writer);
        } else {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32601,\"message\":\"Unknown tool\"}}");
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Tool Implementations
    // ─────────────────────────────────────────────────────────────────────────

    fn toolStructuralReplace(self: *NeedleMCPServer, arguments_json: []const u8, writer: anytype) !void {
        // Simple JSON parsing for required fields
        const file_path = extractStringField(arguments_json, "file_path") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing file_path\"}],\"isError\":true}}");
            return;
        };
        const pattern_query = extractStringField(arguments_json, "pattern_query") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing pattern_query\"}],\"isError\":true}}");
            return;
        };
        const replacement = extractStringField(arguments_json, "replacement") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing replacement\"}],\"isError\":true}}");
            return;
        };

        // Create EditOperation
        var op = needle.EditOperation.init(
            file_path,
            pattern_query,
            replacement,
        );

        // Set safety level
        const safety_level = extractStringField(arguments_json, "safety_level") orelse "medium";
        if (std.mem.eql(u8, safety_level, "low")) {
            op.safety_level = .low;
        } else if (std.mem.eql(u8, safety_level, "high")) {
            op.safety_level = .high;
        } else {
            op.safety_level = .medium;
        }

        // Set edit mode
        const edit_mode = extractStringField(arguments_json, "edit_mode") orelse "auto";
        if (std.mem.eql(u8, edit_mode, "structural")) {
            op.edit_mode = .structural;
        } else if (std.mem.eql(u8, edit_mode, "semantic")) {
            op.edit_mode = .semantic;
        } else if (std.mem.eql(u8, edit_mode, "text_fallback")) {
            op.edit_mode = .text_fallback;
        } else {
            op.edit_mode = .auto;
        }

        // Apply edit
        var report = needle.EditEngine.apply(self.allocator, op) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer report.deinit();

        // Build response
        const success_str = if (report.isSuccess()) "true" else "false";
        const parse_ok_int: u32 = if (report.parse_ok) 1 else 0;

        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "success={s}, ops={d}, files={d}, parse_ok={d}", .{
            success_str,
            report.operations_applied,
            report.files_modified,
            parse_ok_int,
        }) catch "Edit completed";
        try writeJsonResponse(writer, msg, !report.isSuccess());
    }

    fn toolSearch(self: *NeedleMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const query = extractStringField(arguments_json, "query") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing query\"}],\"isError\":true}}");
            return;
        };
        const file_path = extractStringField(arguments_json, "file_path") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing file_path (required)\"}],\"isError\":true}}");
            return;
        };

        // Single file search
        const source = std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error reading file: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer self.allocator.free(source);

        var matcher = needle.Matcher.init(self.allocator, source, file_path);
        var matches = matcher.findMatches(query) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer matches.deinit();

        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "Found {d} matches for '{s}' in {s}", .{ matches.len(), query, file_path }) catch "Search completed";
        try writeJsonResponse(writer, msg, false);
    }

    fn toolQualityGates(self: *NeedleMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const file_path = extractStringField(arguments_json, "file_path") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing file_path\"}],\"isError\":true}}");
            return;
        };

        var report = needle.checkFile(self.allocator, file_path) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer report.deinit();

        const parse_ok_str = if (report.parse_ok) "true" else "false";
        const score = report.safetyScore();

        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "parse_ok={s}, violations={d}, safety_score={d:.2}", .{
            parse_ok_str,
            report.violations.items.len,
            score,
        }) catch "Check completed";
        try writeJsonResponse(writer, msg, !report.parse_ok);
    }

    fn toolPreview(self: *NeedleMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const file_path = extractStringField(arguments_json, "file_path") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing file_path\"}],\"isError\":true}}");
            return;
        };
        const pattern_query = extractStringField(arguments_json, "pattern_query") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing pattern_query\"}],\"isError\":true}}");
            return;
        };
        const replacement = extractStringField(arguments_json, "replacement") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing replacement\"}],\"isError\":true}}");
            return;
        };

        const source = std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error reading file: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer self.allocator.free(source);

        var matcher = needle.Matcher.init(self.allocator, source, file_path);
        var matches = matcher.findMatches(pattern_query) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer matches.deinit();

        if (matches.isEmpty()) {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"No matches found\"}],\"isError\":false}}");
            return;
        }

        const best_match = matches.items.items[0];

        // Compute diff
        var editor = needle.TextEditor.init(self.allocator, source, file_path);
        var diff = editor.computeDiff(best_match, replacement) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer diff.deinit(self.allocator);

        // Build response with diff hunk
        var buffer: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "Found match at line {d}-{d}\n{s}", .{
            best_match.start_line,
            best_match.end_line,
            diff.hunk,
        }) catch "Diff computed";
        try writeJsonResponse(writer, msg, false);
    }

    fn toolBatchEdit(self: *NeedleMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        _ = arguments_json;
        try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Batch edit: Not yet implemented\"}],\"isError\":false}}");
    }

    fn toolAutonomousRefactor(self: *NeedleMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const intent = extractStringField(arguments_json, "intent") orelse {
            try writer.writeAll("{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"Error: Missing intent\"}],\"isError\":true}}");
            return;
        };

        // Parse optional parameters
        const confidence_threshold_str = extractStringField(arguments_json, "confidence_threshold");
        const confidence_threshold = if (confidence_threshold_str) |s|
            std.fmt.parseFloat(f32, s) catch 0.8
        else
            0.8;

        const safety_level_str = extractStringField(arguments_json, "safety_level");
        const safety_level: needle.autonomous_refactor.SafetyLevel = if (safety_level_str) |s| blk: {
            if (std.mem.eql(u8, s, "low")) break :blk .low;
            if (std.mem.eql(u8, s, "high")) break :blk .high;
            if (std.mem.eql(u8, s, "critical")) break :blk .critical;
            break :blk .medium;
        } else .medium;

        // Build AST graph from current directory
        var graph = needle.zig_parser.ASTGraph.init(self.allocator);
        defer graph.deinit();

        // Parse all .zig files in current directory
        var dir = std.fs.cwd().openDir(".", .{}) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error opening directory: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer dir.close();

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

            const file_path = try self.allocator.dupe(u8, entry.path);
            const source = dir.readFileAlloc(self.allocator, entry.path, 10_000_000) catch continue;
            defer self.allocator.free(source);

            var parser = needle.zig_parser.ZigParser.init(self.allocator, source);
            const ast_node = try parser.parseSourceFile();

            try graph.files.put(file_path, ast_node);
        }

        // Execute Ralph Loop with graph
        var engine = needle.autonomous_refactor.AutonomousRefactorEngine.init(
            self.allocator,
            ".", // root_dir - use current directory
        );
        defer engine.deinit();

        // Set confidence and safety level (these are public fields)
        engine.confidence = confidence_threshold;
        // Note: autonomy_level maps to safety level concept
        engine.autonomy_level = if (safety_level == .low) .assisted else if (safety_level == .high) .semi_auto else .full_auto;

        // Use the correct OmegaAgent API: plan -> execute
        var refactor_plan = engine.plan(intent) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Plan error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer refactor_plan.deinit();

        var result = engine.execute(&refactor_plan, true) catch |err| {
            const err_name = @errorName(err);
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Execute error: {s}", .{err_name}) catch "Error";
            try writeJsonResponse(writer, msg, true);
            return;
        };
        defer {
            result.deinit();
        }

        // Build response
        const success_str = if (result.success) "✅ SUCCESS" else "❌ FAILED";
        const vsa_str = if (result.confidence > confidence_threshold) "VSA: ✅" else "VSA: ❌";
        const tests_str = "TESTS: ⏭"; // Tests not run in this stub

        var buffer: [2048]u8 = undefined;
        var idx: usize = 0;

        @memcpy(buffer[idx..], success_str);
        idx += success_str.len;

        const stats = std.fmt.bufPrint(buffer[idx..], "\nTargets: {d}\n{s}\n{s}\nTransformations: {d}\nFiles: {d}", .{
            refactor_plan.steps.items.len,
            vsa_str,
            tests_str,
            result.operations_performed,
            result.files_modified,
        }) catch "";

        var response = std.ArrayList(u8).empty;
        defer response.deinit(self.allocator);

        // Append buffer content
        for (buffer[0..idx]) |c| {
            try response.append(self.allocator, c);
        }
        // Append stats
        for (stats) |c| {
            try response.append(self.allocator, c);
        }

        // Note: AutonomousResult doesn't have errors/warnings fields
        // Add lessons learned if present
        if (result.lessons_learned.len > 0) {
            try response.append(self.allocator, '\n');
            try response.appendSlice(self.allocator, "📝 ");
            try response.appendSlice(self.allocator, result.lessons_learned);
        }

        try writeJsonResponse(writer, response.items, !result.success);
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────────────

fn extractStringField(json: []const u8, key: []const u8) ?[]const u8 {
    // Simple JSON extraction - looks for "key":"value" pattern
    const key_pattern = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\":\"", .{key}) catch return null;
    defer std.heap.page_allocator.free(key_pattern);

    const key_start = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    const value_start = key_start + key_pattern.len;
    const value_end = std.mem.indexOfScalarPos(u8, json, value_start, '"') orelse return null;
    return json[value_start..value_end];
}

fn writeJsonResponse(writer: anytype, text: []const u8, is_error: bool) !void {
    // Build JSON response manually with escaping
    var buffer: [8192]u8 = undefined;
    var idx: usize = 0;

    const prefix = "{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"";
    @memcpy(buffer[idx..][0..prefix.len], prefix);
    idx += prefix.len;

    // Escape and write text
    for (text) |c| {
        const escaped: ?[]const u8 = switch (c) {
            '\\' => "\\\\",
            '"' => "\\\"",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            else => null,
        };
        if (escaped) |e| {
            @memcpy(buffer[idx..][0..e.len], e);
            idx += e.len;
        } else {
            buffer[idx] = c;
            idx += 1;
        }
    }

    const suffix = "\"}],\"isError\":";
    @memcpy(buffer[idx..][0..suffix.len], suffix);
    idx += suffix.len;

    const error_val = if (is_error) "true" else "false";
    @memcpy(buffer[idx..][0..error_val.len], error_val);
    idx += error_val.len;

    const closing = "}}";
    @memcpy(buffer[idx..][0..closing.len], closing);
    idx += closing.len;

    try writer.writeAll(buffer[0..idx]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Entry Point - stdio transport
// ─────────────────────────────────────────────────────────────────────────────

// StdoutWriter wrapper for posix.write
const StdoutWriter = struct {
    const Self = @This();

    pub fn writeAll(self: *Self, bytes: []const u8) !void {
        _ = self;
        _ = try posix.write(1, bytes);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = NeedleMCPServer.init(allocator);

    // Debug output goes to stderr (fd 2) so we don't interfere with MCP protocol on stdout
    const stderr_fd: posix.fd_t = 2;
    var debug_buffer: [512]u8 = undefined;
    const debug_msg = std.fmt.bufPrint(&debug_buffer, "NEEDLE MCP Server v{s} started\n", .{SERVER_VERSION}) catch "";
    _ = try posix.write(stderr_fd, debug_msg);
    const debug_msg2 = std.fmt.bufPrint(&debug_buffer, "φ² + 1/φ² = {d:.3} = TRINITY\n", .{TRINITY_SUM}) catch "";
    _ = try posix.write(stderr_fd, debug_msg2);
    const debug_msg3 = std.fmt.bufPrint(&debug_buffer, "PHOENIX = {d}\n\n", .{PHOENIX}) catch "";
    _ = try posix.write(stderr_fd, debug_msg3);

    var stdout_writer = StdoutWriter{};

    var read_buffer: [65536]u8 = undefined;

    while (true) {
        // Read line from stdin (fd 0)
        const bytes_read = posix.read(0, &read_buffer) catch |err| {
            if (err == error.EndOfStream) break;
            const err_msg = std.fmt.bufPrint(&debug_buffer, "Error reading: {}\n", .{err}) catch "";
            _ = try posix.write(stderr_fd, err_msg);
            continue;
        };

        if (bytes_read == 0) break;

        const line = read_buffer[0..bytes_read];
        const bytes_msg = std.fmt.bufPrint(&debug_buffer, "Read {d} bytes\n", .{bytes_read}) catch "";
        _ = try posix.write(stderr_fd, bytes_msg);

        // Find newline and process only up to it
        const newline_idx = std.mem.indexOfScalar(u8, line, '\n') orelse line.len;
        const request = line[0..newline_idx];

        if (request.len == 0) continue;

        // Debug: log request
        const debug_req = std.fmt.bufPrint(&debug_buffer, "Got request: {s}\n", .{request}) catch "";
        _ = try posix.write(stderr_fd, debug_req);

        // Simple JSON-RPC parsing
        if (std.mem.indexOf(u8, request, "\"initialize\"") != null) {
            try server.writeInitializeResponse(&stdout_writer);
        } else if (std.mem.indexOf(u8, request, "\"tools/list\"") != null) {
            try server.writeToolsList(&stdout_writer);
        } else if (std.mem.indexOf(u8, request, "\"tools/call\"") != null) {
            // MCP tools/call format: {"params":{"name":"tool_name","arguments":{...}}}
            const params_idx = std.mem.indexOf(u8, request, "\"params\":") orelse {
                _ = try posix.write(stderr_fd, "Error: params not found\n");
                continue;
            };
            const name_after_params = std.mem.indexOf(u8, request[params_idx..], "\"name\":") orelse {
                _ = try posix.write(stderr_fd, "Error: name not found after params\n");
                continue;
            };
            const name_idx = params_idx + name_after_params;
            const name_start = name_idx + 8;
            const name_end = std.mem.indexOfScalarPos(u8, request, name_start, '"') orelse {
                _ = try posix.write(stderr_fd, "Error: name end quote not found\n");
                continue;
            };
            const tool_name = request[name_start..name_end];

            const arguments_idx = std.mem.indexOf(u8, request[params_idx..], "\"arguments\":") orelse {
                _ = try posix.write(stderr_fd, "Error: arguments not found after params\n");
                continue;
            };
            const args_absolute_idx = params_idx + arguments_idx;
            // Skip whitespace and colon after "arguments"
            var args_search_start = args_absolute_idx + 13; // 13 = length of "\"arguments\":"
            while (args_search_start < request.len and std.ascii.isWhitespace(request[args_search_start])) {
                args_search_start += 1;
            }
            // The next character should be { or " (for stringified JSON)
            if (args_search_start >= request.len or (request[args_search_start] != '{' and request[args_search_start] != '"')) {
                _ = try posix.write(stderr_fd, "Error: arguments { not found\n");
                continue;
            }
            const args_start = args_search_start;
            var brace_count: usize = 1;
            var args_end = args_start + 1;
            while (args_end < request.len and brace_count > 0) {
                if (request[args_end] == '{') brace_count += 1;
                if (request[args_end] == '}') brace_count -= 1;
                args_end += 1;
            }
            const arguments_json = request[args_start..args_end];

            try server.handleToolsCall(tool_name, arguments_json, &stdout_writer);
        } else {
            const unknown_msg = std.fmt.bufPrint(&debug_buffer, "Unknown request\n", .{}) catch "";
            _ = try posix.write(stderr_fd, unknown_msg);
        }
    }
}
