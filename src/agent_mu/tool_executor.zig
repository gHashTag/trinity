//! AGENT MU v8.25 - MCP Tool Executor
//!
//! This module provides the integration layer with MCP (Model Context Protocol) tools.
//! It bridges AGENT MU's tool requests to actual MCP tool calls.
//!
//! MCP Tools Available:
//! - Read: File reading from repository
//! - Bash: Command execution (zig build, test, git)
//! - WebSearch: Web search for documentation and solutions
//! - Task: Agent spawning and task management
//! - Memory: Vector storage and retrieval

const std = @import("std");
const tool_coordinator = @import("tool_coordinator.zig");

/// MCP tool types that AGENT MU can invoke
pub const MCPToolType = enum {
    read, // Read file from repository
    bash, // Execute shell command
    web_search, // Search web for information
    task_spawn, // Spawn sub-agent for task
    memory_store, // Store vector in memory
    memory_retrieve, // Retrieve from memory
    memory_search, // Semantic search

    pub fn toMCPName(self: MCPToolType) []const u8 {
        return switch (self) {
            .read => "Read",
            .bash => "Bash",
            .web_search => "WebSearch",
            .task_spawn => "Task",
            .memory_store => "memory_store",
            .memory_retrieve => "memory_retrieve",
            .memory_search => "memory_search",
        };
    }
};

/// MCP tool request wrapper
pub const MCPRequest = struct {
    tool_type: MCPToolType,
    parameters: std.StringHashMap([]const u8),
    timeout_ms: u64 = 10000,

    pub fn init(allocator: std.mem.Allocator, tool_type: MCPToolType) MCPRequest {
        return MCPRequest{
            .tool_type = tool_type,
            .parameters = std.StringHashMap([]const u8).init(allocator),
            .timeout_ms = 10000,
        };
    }

    pub fn deinit(self: *MCPRequest) void {
        var it = self.parameters.iterator();
        while (it.next()) |entry| {
            self.parameters.allocator.free(entry.key_ptr.*);
            self.parameters.allocator.free(entry.value_ptr.*);
        }
        self.parameters.deinit();
    }

    pub fn setParam(self: *MCPRequest, key: []const u8, value: []const u8) !void {
        const key_dup = try self.parameters.allocator.dupe(u8, key);
        errdefer self.parameters.allocator.free(key_dup);
        const value_dup = try self.parameters.allocator.dupe(u8, value);
        errdefer self.parameters.allocator.free(value_dup);

        try self.parameters.put(key_dup, value_dup);
    }
};

/// MCP tool response wrapper
pub const MCPResponse = struct {
    success: bool,
    data: []const u8,
    error_message: []const u8,
    execution_time_ms: u64,

    pub fn deinit(self: *MCPResponse, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        allocator.free(self.error_message);
    }
};

/// Tool executor - bridges AGENT MU to MCP
pub const MCPToolExecutor = struct {
    allocator: std.mem.Allocator,
    enabled_tools: std.StaticBitSet(7), // 7 MCP tool types

    pub fn init(allocator: std.mem.Allocator) MCPToolExecutor {
        const enabled = std.StaticBitSet(7).initFull();
        return MCPToolExecutor{
            .allocator = allocator,
            .enabled_tools = enabled,
        };
    }

    pub fn disableTool(self: *MCPToolExecutor, tool: MCPToolType) void {
        self.enabled_tools.unset(@intFromEnum(tool));
    }

    /// Execute MCP tool request
    pub fn execute(self: *MCPToolExecutor, req: MCPRequest) !MCPResponse {
        const tool_idx = @intFromEnum(req.tool_type);

        if (!self.enabled_tools.isSet(tool_idx)) {
            return MCPResponse{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Tool disabled"),
                .execution_time_ms = 0,
            };
        }

        const start_time = std.time.nanoTimestamp();

        // Route to appropriate MCP tool handler
        const result = switch (req.tool_type) {
            .read => try self.executeRead(req),
            .bash => try self.executeBash(req),
            .web_search => try self.executeWebSearch(req),
            .task_spawn => try self.executeTaskSpawn(req),
            .memory_store => try self.executeMemoryStore(req),
            .memory_retrieve => try self.executeMemoryRetrieve(req),
            .memory_search => try self.executeMemorySearch(req),
        };

        const elapsed_ns = std.time.nanoTimestamp() - start_time;
        const elapsed_ms: u64 = if (elapsed_ns > 0) @intCast(@divTrunc(elapsed_ns, 1_000_000)) else 0;

        return MCPResponse{
            .success = result.success,
            .data = result.data,
            .error_message = result.error_message,
            .execution_time_ms = elapsed_ms,
        };
    }

    /// Execute Read tool - read file from repository
    fn executeRead(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const file_path = req.parameters.get("file_path") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing file_path parameter"),
            };
        };

        // Read file directly (MCP Read tool would be called externally)
        const content = std.fs.cwd().readFileAlloc(self.allocator, file_path, 1024 * 1024) catch |err| {
            return .{
                .success = false,
                .data = "",
                .error_message = try std.fmt.allocPrint(self.allocator, "Cannot read file: {s}", .{@errorName(err)}),
            };
        };

        return .{
            .success = true,
            .data = content,
            .error_message = "",
        };
    }

    /// Execute Bash tool - run shell command
    fn executeBash(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const command = req.parameters.get("command") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing command parameter"),
            };
        };

        const process = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "sh", "-c", command },
            .max_output_bytes = 64 * 1024,
        }) catch |err| {
            return .{
                .success = false,
                .data = "",
                .error_message = try std.fmt.allocPrint(self.allocator, "Command failed: {s}", .{@errorName(err)}),
            };
        };

        defer {
            self.allocator.free(process.stdout);
            self.allocator.free(process.stderr);
        }

        const exit_code = switch (process.term) {
            .Exited => |code| code,
            else => @as(u32, 1),
        };
        if (exit_code != 0) {
            return .{
                .success = false,
                .data = "",
                .error_message = try std.fmt.allocPrint(self.allocator, "Command exited {d}: {s}", .{ exit_code, process.stderr }),
            };
        }

        return .{
            .success = true,
            .data = try self.allocator.dupe(u8, process.stdout),
            .error_message = "",
        };
    }

    /// Execute WebSearch tool - search for documentation
    fn executeWebSearch(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const query = req.parameters.get("query") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing query parameter"),
            };
        };

        _ = query;

        // Placeholder for actual MCP WebSearch integration
        return .{
            .success = true,
            .data = try std.fmt.allocPrint(self.allocator, "WebSearch result for query (v8.26 integration pending)\n", .{}),
            .error_message = "",
        };
    }

    /// Execute Task tool - spawn sub-agent
    fn executeTaskSpawn(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const description = req.parameters.get("description") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing description parameter"),
            };
        };

        _ = description;

        // Placeholder for actual MCP Task spawn integration
        return .{
            .success = true,
            .data = try std.fmt.allocPrint(self.allocator, "Task spawned via MCP (v8.26 integration pending)\n", .{}),
            .error_message = "",
        };
    }

    /// Execute Memory Store tool
    fn executeMemoryStore(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const key = req.parameters.get("key") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing key parameter"),
            };
        };

        const value = req.parameters.get("value") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing value parameter"),
            };
        };

        _ = key;
        _ = value;

        // Placeholder for actual MCP Memory integration
        return .{
            .success = true,
            .data = try std.fmt.allocPrint(self.allocator, "Stored in MCP Memory (v8.26 integration pending)\n", .{}),
            .error_message = "",
        };
    }

    /// Execute Memory Retrieve tool
    fn executeMemoryRetrieve(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const key = req.parameters.get("key") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing key parameter"),
            };
        };

        _ = key;

        // Placeholder for actual MCP Memory integration
        return .{
            .success = true,
            .data = try std.fmt.allocPrint(self.allocator, "Retrieved from MCP Memory (v8.26 integration pending)\n", .{}),
            .error_message = "",
        };
    }

    /// Execute Memory Search tool (semantic search)
    fn executeMemorySearch(self: *MCPToolExecutor, req: MCPRequest) !struct { success: bool, data: []const u8, error_message: []const u8 } {
        const query = req.parameters.get("query") orelse {
            return .{
                .success = false,
                .data = "",
                .error_message = try self.allocator.dupe(u8, "Missing query parameter"),
            };
        };

        _ = query;

        // Placeholder for actual MCP Memory search integration
        return .{
            .success = true,
            .data = try std.fmt.allocPrint(self.allocator, "Searched MCP Memory (v8.26 integration pending)\n", .{}),
            .error_message = "",
        };
    }
};

/// Convert AGENT MU ToolRequest to MCP Request
pub fn toolRequestToMCP(allocator: std.mem.Allocator, tool_req: tool_coordinator.ToolRequest) !MCPRequest {
    const mcp_type = switch (tool_req.tool_type) {
        .file_read => MCPToolType.read,
        .command_exec, .git_op => MCPToolType.bash,
        .web_search => MCPToolType.web_search,
        .code_analysis => MCPToolType.task_spawn,
    };

    var mcp_req = MCPRequest.init(allocator, mcp_type);

    // Set common parameters
    try mcp_req.setParam("target", tool_req.target);

    // Set confidence for routing decisions
    const confidence_str = try std.fmt.allocPrint(allocator, "{d:.3}", .{tool_req.confidence});
    try mcp_req.setParam("confidence", confidence_str);

    // Copy additional parameters
    var it = tool_req.parameters.iterator();
    while (it.next()) |entry| {
        try mcp_req.setParam(entry.key_ptr.*, entry.value_ptr.*);
    }

    return mcp_req;
}

/// Convert MCP Response to AGENT MU ToolResponse
pub fn mcpResponseToTool(allocator: std.mem.Allocator, mcp_resp: MCPResponse, tool_type: tool_coordinator.ToolType) !tool_coordinator.ToolResponse {
    if (mcp_resp.success) {
        return tool_coordinator.ToolResponse{
            .success = true,
            .output = try allocator.dupe(u8, mcp_resp.data),
            .err_msg = "",
            .execution_time_ms = mcp_resp.execution_time_ms,
            .tool_type = tool_type,
        };
    } else {
        return tool_coordinator.ToolResponse{
            .success = false,
            .output = "",
            .err_msg = try allocator.dupe(u8, mcp_resp.error_message),
            .execution_time_ms = mcp_resp.execution_time_ms,
            .tool_type = tool_type,
        };
    }
}

/// Bridge function: Execute AGENT MU tool request via MCP
pub fn executeViaMCP(allocator: std.mem.Allocator, tool_req: tool_coordinator.ToolRequest, _: tool_coordinator.ToolConfig) !tool_coordinator.ToolResponse {
    var executor = MCPToolExecutor.init(allocator);

    var mcp_req = try toolRequestToMCP(allocator, tool_req);
    defer mcp_req.deinit();

    const mcp_resp = try executor.execute(mcp_req);
    defer {
        allocator.free(mcp_resp.data);
        allocator.free(mcp_resp.error_message);
    }

    return mcpResponseToTool(allocator, mcp_resp, tool_req.tool_type);
}

test "MCPToolType toMCPName" {
    try std.testing.expectEqualSlices(u8, "Read", MCPToolType.read.toMCPName());
    try std.testing.expectEqualSlices(u8, "Bash", MCPToolType.bash.toMCPName());
    try std.testing.expectEqualSlices(u8, "WebSearch", MCPToolType.web_search.toMCPName());
}

test "MCPToolExecutor init" {
    const allocator = std.testing.allocator;
    var executor = MCPToolExecutor.init(allocator);
    try std.testing.expect(executor.enabled_tools.isSet(0)); // Read enabled

    executor.disableTool(.read);
    try std.testing.expect(!executor.enabled_tools.isSet(0)); // Read disabled
}
