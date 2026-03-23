// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE E2E Test Helpers
// ═══════════════════════════════════════════════════════════════════════════════
//
// Mock MCP client for testing Model Context Protocol tools
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const needle = @import("needle");

// ═══════════════════════════════════════════════════════════════════════════════
// JSON-RPC Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const MCPResponse = struct {
    jsonrpc: []const u8 = "2.0",
    id: ?[]const u8 = null,
    result: ?MCPResult = null,
    mcp_error: ?MCPError = null,

    pub fn isSuccess(self: MCPResponse) bool {
        return self.mcp_error == null and self.result != null;
    }

    pub fn deinit(self: *const MCPResponse, allocator: std.mem.Allocator) void {
        if (self.result) |r| r.deinit(allocator);
        if (self.mcp_error) |e| e.deinit(allocator);
        if (self.id) |id| allocator.free(id);
    }
};

pub const MCPResult = struct {
    content: [1]MCPContent, // Fixed-size array instead of slice to avoid dangling pointer
    isError: bool = false,

    pub fn deinit(self: *const MCPResult, allocator: std.mem.Allocator) void {
        _ = allocator; // Prevent unused warnings
        _ = self; // Prevent unused warnings
        // Note: We skip freeing text to avoid complex lifetime issues
        // In production code, proper memory management would be needed
    }
};

pub const MCPContent = struct {
    type: []const u8, // "text" - always a static literal
    text: []const u8,

    pub fn deinit(self: *const MCPContent, allocator: std.mem.Allocator) void {
        _ = allocator; // Intentionally unused - text memory is managed elsewhere
        _ = self;
    }
};

pub const MCPError = struct {
    code: i32,
    message: []const u8,
    data: ?[]const u8 = null,

    pub fn deinit(self: *const MCPError, allocator: std.mem.Allocator) void {
        _ = allocator;
        _ = self;
        // Note: message and data are now arena-allocated by MockMCPClient
        // They will be freed automatically when the arena is destroyed
    }
};

pub const MCPToolCall = struct {
    name: []const u8,
    arguments: std.json.Value,

    pub fn deinit(self: *MCPToolCall, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        // arguments is owned by the parsed JSON
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Error Classification (5-tier system from MCP best practices)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ErrorClass = enum(u16) {
    parameter_error = 4001, // Missing/invalid parameters
    permission_error = 4101, // File access denied
    resource_error = 4201, // File not found, resource unavailable
    business_error = 4301, // Invalid operation for state
    system_error = 5001, // Internal errors
};

pub fn classifyError(err: anyerror) ErrorClass {
    return switch (err) {
        error.FileNotFound, error.NameTooLong => .resource_error,
        error.AccessDenied, error.PermDenied => .permission_error,
        error.InvalidArgument, error.Overflow => .parameter_error,
        else => .system_error,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Mock MCP Client
// ═══════════════════════════════════════════════════════════════════════════════

pub const MockMCPClient = struct {
    allocator: std.mem.Allocator,
    arena_allocator: std.heap.ArenaAllocator,
    server_path: []const u8,
    server_process: ?*std.process.Child = null,

    pub fn init(allocator: std.mem.Allocator, server_path: []const u8) MockMCPClient {
        return .{
            .allocator = allocator,
            .arena_allocator = std.heap.ArenaAllocator.init(allocator),
            .server_path = server_path,
            .server_process = null,
        };
    }

    pub fn deinit(self: *MockMCPClient) void {
        self.arena_allocator.deinit();
        if (self.server_process) |p| {
            _ = p.kill() catch {};
            self.allocator.destroy(p);
        }
    }

    // Helper to allocate formatted string from arena (auto-freed on client deinit)
    fn allocPrint(self: *MockMCPClient, comptime fmt: []const u8, args: anytype) ![]const u8 {
        return std.fmt.allocPrint(self.arena_allocator.allocator(), fmt, args);
    }

    // Helper to duplicate string from arena
    fn dupe(self: *MockMCPClient, str: []const u8) ![]const u8 {
        return self.arena_allocator.allocator().dupe(u8, str);
    }

    /// Call a single MCP tool (direct API call for testing)
    pub fn callTool(self: *MockMCPClient, tool_name: []const u8, arguments: struct {
        file_path: []const u8 = "",
        query: []const u8 = "",
        pattern_query: []const u8 = "",
        replacement: []const u8 = "",
        safety_level: []const u8 = "medium",
        edit_mode: []const u8 = "auto",
        check_level: []const u8 = "basic",
    }) !MCPResponse {
        // Route to appropriate handler
        if (std.mem.eql(u8, tool_name, "needle_search")) {
            return self.handleSearch(arguments);
        } else if (std.mem.eql(u8, tool_name, "needle_quality_gates")) {
            return self.handleQualityGates(arguments);
        } else if (std.mem.eql(u8, tool_name, "needle_structural_replace")) {
            return self.handleStructuralReplace(arguments);
        } else if (std.mem.eql(u8, tool_name, "needle_preview")) {
            return self.handlePreview(arguments);
        } else {
            return MCPResponse{
                .mcp_error = .{
                    .code = -32601,
                    .message = try self.allocPrint("Unknown tool: {s}", .{tool_name})
                },
            };
        }
    }

    /// Handle needle_search
    fn handleSearch(self: *MockMCPClient, args: anytype) !MCPResponse {
        if (args.file_path.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing file_path")
                },
            };
        }
        if (args.query.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing query")
                },
            };
        }

        // Read file
        const source = std.fs.cwd().readFileAlloc(self.allocator, args.file_path, 10_000_000) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(classifyError(err)),
                    .message = try self.allocPrint("Error reading file: {}", .{err})
                },
            };
        };
        defer self.allocator.free(source);

        // Perform search
        var matcher = needle.Matcher.init(self.allocator, source, args.file_path);
        var matches = matcher.findMatches(args.query) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.system_error),
                    .message = try self.allocPrint("Search error: {}", .{err})
                },
            };
        };
        defer matches.deinit();

        const text = try self.allocPrint("Found {d} matches for '{s}' in {s}", .{
            matches.len(),
            args.query,
            args.file_path,
        });

        return MCPResponse{
            .result = .{
                .content = [_]MCPContent{
                    .{
                        .type = "text",
                        .text = text,
                    },
                },
                .isError = false,
            },
        };
    }

    /// Handle needle_quality_gates
    fn handleQualityGates(self: *MockMCPClient, args: anytype) !MCPResponse {
        if (args.file_path.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing file_path")
                },
            };
        }

        var report = needle.checkFile(self.allocator, args.file_path) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(classifyError(err)),
                    .message = try self.allocPrint("Check error: {}", .{err})
                },
            };
        };
        defer report.deinit();

        const parse_ok_str = if (report.parse_ok) "true" else "false";
        const score = report.safetyScore();

        const text = try self.allocPrint("parse_ok={s}, violations={d}, safety_score={d:.2}", .{
            parse_ok_str,
            report.violations.items.len,
            score,
        });

        return MCPResponse{
            .result = .{
                .content = [_]MCPContent{
                    .{
                        .type = "text",
                        .text = text,
                    },
                },
                .isError = !report.parse_ok,
            },
        };
    }

    /// Handle needle_structural_replace
    fn handleStructuralReplace(self: *MockMCPClient, args: anytype) !MCPResponse {
        if (args.file_path.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing file_path")
                },
            };
        }
        if (args.pattern_query.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing pattern_query")
                },
            };
        }
        if (args.replacement.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing replacement")
                },
            };
        }

        // Create EditOperation
        var op = needle.EditOperation.init(
            args.file_path,
            args.pattern_query,
            args.replacement,
        );

        // Configure for actual write (not preview)
        op.preview = false;

        // Set safety level
        if (std.mem.eql(u8, args.safety_level, "low")) {
            op.safety_level = .low;
        } else if (std.mem.eql(u8, args.safety_level, "high")) {
            op.safety_level = .high;
        } else {
            op.safety_level = .medium;
        }

        // Apply edit
        var report = needle.EditEngine.apply(self.allocator, op) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.system_error),
                    .message = try self.allocPrint("Edit error: {}", .{err})
                },
            };
        };
        defer report.deinit();

        const success_str = if (report.isSuccess()) "true" else "false";
        const parse_ok_int: u32 = if (report.parse_ok) 1 else 0;

        const text = try self.allocPrint("success={s}, ops={d}, files={d}, parse_ok={d}", .{
            success_str,
            report.operations_applied,
            report.files_modified,
            parse_ok_int,
        });

        return MCPResponse{
            .result = .{
                .content = [_]MCPContent{
                    .{
                        .type = "text",
                        .text = text,
                    },
                },
                .isError = !report.isSuccess(),
            },
        };
    }

    /// Handle needle_preview
    fn handlePreview(self: *MockMCPClient, args: anytype) !MCPResponse {
        if (args.file_path.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing file_path")
                },
            };
        }
        if (args.pattern_query.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing pattern_query")
                },
            };
        }
        if (args.replacement.len == 0) {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.parameter_error),
                    .message = try self.dupe("Missing replacement")
                },
            };
        }

        const source = std.fs.cwd().readFileAlloc(self.allocator, args.file_path, 10_000_000) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(classifyError(err)),
                    .message = try self.allocPrint("Read error: {}", .{err})
                },
            };
        };
        defer self.allocator.free(source);

        var matcher = needle.Matcher.init(self.allocator, source, args.file_path);
        var matches = matcher.findMatches(args.pattern_query) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.system_error),
                    .message = try self.allocPrint("Match error: {}", .{err})
                },
            };
        };
        defer matches.deinit();

        if (matches.isEmpty()) {
            return MCPResponse{
                .result = .{
                    .content = [_]MCPContent{
                        .{
                            .type = try self.dupe("text"),
                            .text = try self.dupe("No matches found"),
                        },
                    },
                    .isError = false,
                },
            };
        }

        const best_match = matches.items.items[0];

        // Compute diff
        var editor = needle.TextEditor.init(self.allocator, source, args.file_path);
        var diff = editor.computeDiff(best_match, args.replacement) catch |err| {
            return MCPResponse{
                .mcp_error = .{
                    .code = @intFromEnum(ErrorClass.system_error),
                    .message = try self.allocPrint("Diff error: {}", .{err})
                },
            };
        };
        defer diff.deinit(self.allocator);

        const text = try self.allocPrint("Found match at line {d}-{d}\n{s}", .{
            best_match.start_line,
            best_match.end_line,
            diff.hunk,
        });

        return MCPResponse{
            .result = .{
                .content = [_]MCPContent{
                    .{
                        .type = "text",
                        .text = text,
                    },
                },
                .isError = false,
            },
        };
    }

    /// Call multiple tools in batch
    pub fn callToolsBatch(self: *MockMCPClient, calls: []const struct {
        name: []const u8,
        args: struct {
            file_path: []const u8 = "",
            query: []const u8 = "",
            pattern_query: []const u8 = "",
            replacement: []const u8 = "",
            safety_level: []const u8 = "medium",
            edit_mode: []const u8 = "auto",
        },
    }) ![]MCPResponse {
        const responses = try self.allocator.alloc(MCPResponse, calls.len);
        errdefer {
            for (responses) |*r| r.deinit(self.allocator);
            self.allocator.free(responses);
        }

        for (calls, 0..) |call, i| {
            responses[i] = try self.callTool(
                call.name,
                .{
                    .file_path = call.args.file_path,
                    .query = call.args.query,
                    .pattern_query = call.args.pattern_query,
                    .replacement = call.args.replacement,
                    .safety_level = call.args.safety_level,
                    .edit_mode = call.args.edit_mode,
                },
            );
        }

        return responses;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Test Assertions
// ═══════════════════════════════════════════════════════════════════════════════

pub fn assertSuccess(response: MCPResponse) !void {
    if (!response.isSuccess()) {
        return error.TestFailed;
    }
}

pub fn assertError(response: MCPResponse, expected_code: i32) !void {
    if (response.mcp_error == null) {
        return error.TestFailed;
    }
    if (response.mcp_error.?.code != expected_code) {
        return error.TestFailed;
    }
}

pub fn assertContains(response: MCPResponse, substring: []const u8) !void {
    if (response.result == null) {
        return error.TestFailed;
    }
    const text = response.result.?.content[0].text;
    if (std.mem.indexOf(u8, text, substring) == null) {
        return error.TestFailed;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test Helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a temporary test file
pub fn createTempFile(allocator: std.mem.Allocator, content: []const u8, suffix: []const u8) ![]const u8 {
    _ = suffix;
    const tmp_dir = std.testing.tmpDir();
    const filename = try std.fmt.allocPrint(allocator, "needle_test_{d}.zig", .{
        std.time.microTimestamp(),
    });
    // Write using relative path (Dir.writeFile expects relative path)
    try tmp_dir.dir.writeFile(filename, content);
    // Return absolute path for later use
    const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ tmp_dir.dir.path, filename });
    allocator.free(filename);
    return path;
}

/// Clean up a temporary file
pub fn cleanupTempFile(path: []const u8) void {
    std.fs.cwd().deleteFile(path) catch {};
}

/// Validate JSON-RPC response structure
pub fn validateJsonRpcResponse(json: []const u8) !bool {
    // Basic validation: must contain "jsonrpc":"2.0"
    if (std.mem.indexOf(u8, json, "\"jsonrpc\":\"2.0\"") == null) {
        return false;
    }
    // Must have either "result" or "error"
    if (std.mem.indexOf(u8, json, "\"result\"") == null and
        std.mem.indexOf(u8, json, "\"error\"") == null)
    {
        return false;
    }
    return true;
}
