// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 2.4 — MCP AST Query Tool
// ═══════════════════════════════════════════════════════════════════════════════
//
// Model Context Protocol server for NEEDLE AST queries
// Allows LLMs to query AST, find symbols, and perform safe refactoring
//
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zig_parser = @import("zig_parser.zig");
const refactor = @import("refactor.zig");
const vsa = @import("vsa.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MCP PROTOCOL TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// MCP Request method
pub const McpMethod = enum {
    /// Initialize the MCP server
    initialize,
    /// List available tools
    tools_list,
    /// Call a tool
    tools_call,
    /// Get AST for a file
    ast_get,
    /// Find symbol definition
    symbol_find,
    /// Find all references
    symbol_references,
    /// Query AST with pattern
    ast_query,
    /// Get project stats
    project_stats,
};

/// MCP Request
pub const McpRequest = struct {
    id: []const u8,
    method: McpMethod,
    params: std.json.Value,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *McpRequest) void {
        _ = self;
        // params is managed by allocator
    }
};

/// MCP Response
pub const McpResponse = struct {
    id: []const u8,
    result: ?std.json.Value,
    mcp_error: ?McpError,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) McpResponse {
        return .{
            .id = id,
            .result = null,
            .mcp_error = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *McpResponse) void {
        if (self.result) |*r| {
            r.deinit(self.allocator);
        }
        if (self.mcp_error) |*e| {
            e.deinit(self.allocator);
        }
    }

    pub fn toJson(self: *const McpResponse) ![]const u8 {
        var obj = std.json.ObjectMap.init(self.allocator);
        defer obj.deinit();

        try obj.put("id", std.json.Value{ .string = self.id });

        if (self.result) |r| {
            try obj.put("result", r);
        }

        if (self.mcp_error) |e| {
            var err_obj = std.json.ObjectMap.init(self.allocator);
            defer err_obj.deinit();

            try err_obj.put("code", std.json.Value{ .integer = @intFromEnum(e.code) });
            try err_obj.put("message", std.json.Value{ .string = e.message });

            try obj.put("error", std.json.Value{ .object = err_obj });
        }

        return std.json.stringifyAlloc(self.allocator, std.json.Value{ .object = obj }, .{});
    }
};

/// MCP Error
pub const McpError = struct {
    code: ErrorCode,
    message: []const u8,

    pub fn deinit(self: *const McpError, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }
};

pub const ErrorCode = enum(i32) {
    invalid_request = -32600,
    method_not_found = -32601,
    invalid_params = -32602,
    internal_error = -32603,
    parse_error = -32700,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TOOL DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Tool description for MCP
pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    input_schema: std.json.Value,

    pub fn deinit(self: *Tool, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        self.input_schema.deinit(allocator);
    }
};

/// Available tools
pub const tools = &[_]ToolDescription{
    .{
        .name = "ast_get",
        .description = "Get the AST for a Zig source file",
        .params = &[_]Param{
            .{ .name = "file_path", .type = "string", .description = "Path to the Zig source file", .required = true },
        },
    },
    .{
        .name = "symbol_find",
        .description = "Find the definition of a symbol in the project",
        .params = &[_]Param{
            .{ .name = "symbol_name", .type = "string", .description = "Name of the symbol to find", .required = true },
        },
    },
    .{
        .name = "symbol_references",
        .description = "Find all references to a symbol across the project",
        .params = &[_]Param{
            .{ .name = "symbol_name", .type = "string", .description = "Name of the symbol", .required = true },
        },
    },
    .{
        .name = "ast_query",
        .description = "Query the AST with a pattern (S-expression or simple identifier)",
        .params = &[_]Param{
            .{ .name = "query", .type = "string", .description = "Query pattern or identifier", .required = true },
            .{ .name = "file_path", .type = "string", .description = "Optional file path to limit search", .required = false },
        },
    },
    .{
        .name = "project_stats",
        .description = "Get statistics about the project AST",
        .params = &[_]Param{},
    },
    .{
        .name = "symbol_rename",
        .description = "Rename a symbol across all files (preview mode by default)",
        .params = &[_]Param{
            .{ .name = "old_name", .type = "string", .description = "Current symbol name", .required = true },
            .{ .name = "new_name", .type = "string", .description = "New symbol name", .required = true },
            .{ .name = "preview_only", .type = "boolean", .description = "Preview changes without applying (default: true)", .required = false },
        },
    },
    .{
        .name = "semantic_find",
        .description = "Find code patterns semantically similar to example using VSA embeddings",
        .params = &[_]Param{
            .{ .name = "query_code", .type = "string", .description = "Example code snippet to match semantically", .required = true },
            .{ .name = "threshold", .type = "number", .description = "Minimum similarity threshold (0-1, default: 0.7)", .required = false },
            .{ .name = "top_k", .type = "number", .description = "Maximum number of results to return (default: 10)", .required = false },
        },
    },
};

pub const ToolDescription = struct {
    name: []const u8,
    description: []const u8,
    params: []const Param,
};

pub const Param = struct {
    name: []const u8,
    type: []const u8,
    description: []const u8,
    required: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MCP SERVER
// ═══════════════════════════════════════════════════════════════════════════════

pub const McpServer = struct {
    allocator: std.mem.Allocator,
    ast_graph: *zig_parser.ASTGraph,
    project_root: []const u8,

    pub fn init(allocator: std.mem.Allocator, graph: *zig_parser.ASTGraph, project_root: []const u8) McpServer {
        return .{
            .allocator = allocator,
            .ast_graph = graph,
            .project_root = project_root,
        };
    }

    /// Handle an incoming MCP request
    pub fn handleRequest(self: *McpServer, req: McpRequest) !McpResponse {
        var resp = McpResponse.init(self.allocator, req.id);
        errdefer resp.deinit();

        switch (req.method) {
            .initialize => {
                var result_obj = std.json.ObjectMap.init(self.allocator);
                defer result_obj.deinit();

                try result_obj.put("serverInfo", try self.getServerInfo());
                try result_obj.put("capabilities", try self.getC_capabilities());

                resp.result = std.json.Value{ .object = result_obj };
            },
            .tools_list => {
                var tools_array = std.json.Array.init(self.allocator);
                defer {
                    for (tools_array.items) |*t| {
                        if (t.* == .object) {
                            t.object.deinit(self.allocator);
                        }
                    }
                    tools_array.deinit(self.allocator);
                }

                for (tools) |tool| {
                    var tool_obj = std.json.ObjectMap.init(self.allocator);
                    try tool_obj.put("name", std.json.Value{ .string = tool.name });
                    try tool_obj.put("description", std.json.Value{ .string = tool.description });

                    // Build input schema
                    var params_obj = std.json.ObjectMap.init(self.allocator);
                    var props_array = std.json.Array.init(self.allocator);
                    var required_array = std.json.Array.init(self.allocator);

                    for (tool.params) |param| {
                        var param_obj = std.json.ObjectMap.init(self.allocator);
                        try param_obj.put("type", std.json.Value{ .string = param.type });
                        try param_obj.put("description", std.json.Value{ .string = param.description });

                        try props_array.append(std.json.Value{ .object = param_obj });

                        if (param.required) {
                            try required_array.append(std.json.Value{ .string = param.name });
                        }
                    }

                    try params_obj.put("properties", std.json.Value{ .array = props_array });
                    try params_obj.put("required", std.json.Value{ .array = required_array });
                    try params_obj.put("type", std.json.Value{ .string = "object" });

                    try tool_obj.put("inputSchema", std.json.Value{ .object = params_obj });

                    try tools_array.append(std.json.Value{ .object = tool_obj });
                }

                var result_obj = std.json.ObjectMap.init(self.allocator);
                try result_obj.put("tools", std.json.Value{ .array = tools_array });

                resp.result = std.json.Value{ .object = result_obj };
            },
            .tools_call => {
                resp.result = try self.handleToolCall(req.params);
            },
            else => {
                resp.mcp_error = .{
                    .code = .method_not_found,
                    .message = try self.allocator.dupe(u8, "Method not found"),
                };
            },
        }

        return resp;
    }

    fn getServerInfo(self: *McpServer) !std.json.Value {
        var info = std.json.ObjectMap.init(self.allocator);
        try info.put("name", std.json.Value{ .string = "needle-ast-query" });
        try info.put("version", std.json.Value{ .string = "2.0.0" });
        try info.put("protocolVersion", std.json.Value{ .string = "2024-11-05" });
        return std.json.Value{ .object = info };
    }

    fn getC_capabilities(self: *McpServer) !std.json.Value {
        var caps = std.json.ObjectMap.init(self.allocator);
        var tools_caps = std.json.ObjectMap.init(self.allocator);
        try tools_caps.put("listChanged", std.json.Value{ .bool = false });
        try caps.put("tools", std.json.Value{ .object = tools_caps });
        return std.json.Value{ .object = caps };
    }

    fn handleToolCall(self: *McpServer, params: std.json.Value) !std.json.Value {
        const obj = params.object;
        const name_obj = obj.get("name") orelse return error.MissingToolName;
        const name = name_obj.string;

        const args_obj = obj.get("arguments") orelse return error.MissingArguments;
        const args = args_obj.object;

        var result = std.json.ObjectMap.init(self.allocator);

        if (std.mem.eql(u8, name, "ast_get")) {
            const file_path = args.get("file_path").?.string orelse return error.MissingParam;
            _ = file_path;
            try result.put("message", std.json.Value{ .string = "AST query functionality - implement with full parser" });
        } else if (std.mem.eql(u8, name, "symbol_find")) {
            const symbol_name = args.get("symbol_name").?.string orelse return error.MissingParam;

            if (self.ast_graph.findSymbol(symbol_name)) |defs| {
                var defs_array = std.json.Array.init(self.allocator);
                for (defs) |def| {
                    var def_obj = std.json.ObjectMap.init(self.allocator);
                    try def_obj.put("name", std.json.Value{ .string = def.name });
                    try def_obj.put("file", std.json.Value{ .string = def.file });
                    try def_obj.put("kind", std.json.Value{ .string = @tagName(def.kind) });
                    try defs_array.append(std.json.Value{ .object = def_obj });
                }
                try result.put("definitions", std.json.Value{ .array = defs_array });
            } else {
                try result.put("definitions", std.json.Value{ .array = std.json.Array.init(self.allocator) });
            }
        } else if (std.mem.eql(u8, name, "symbol_references")) {
            const symbol_name = args.get("symbol_name").?.string orelse return error.MissingParam;

            const refs = try self.ast_graph.findReferences(symbol_name);
            defer self.allocator.free(refs);

            var refs_array = std.json.Array.init(self.allocator);
            for (refs) |ref| {
                var ref_obj = std.json.ObjectMap.init(self.allocator);
                try ref_obj.put("file", std.json.Value{ .string = ref.file });
                try ref_obj.put("line", std.json.Value{ .integer = @intFromEnum(ref.line) });
                try ref_obj.put("kind", std.json.Value{ .string = @tagName(ref.kind) });
                try refs_array.append(std.json.Value{ .object = ref_obj });
            }
            try result.put("references", std.json.Value{ .array = refs_array });
        } else if (std.mem.eql(u8, name, "project_stats")) {
            const stats = self.ast_graph.stats();
            var stats_obj = std.json.ObjectMap.init(self.allocator);
            try stats_obj.put("file_count", std.json.Value{ .integer = stats.file_count });
            try stats_obj.put("symbol_count", std.json.Value{ .integer = stats.symbol_count });
            try stats_obj.put("cross_ref_count", std.json.Value{ .integer = stats.cross_ref_count });
            try stats_obj.put("call_edge_count", std.json.Value{ .integer = stats.call_edge_count });
            try result.put("stats", std.json.Value{ .object = stats_obj });
        } else if (std.mem.eql(u8, name, "symbol_rename")) {
            const old_name = args.get("old_name").?.string orelse return error.MissingParam;
            const new_name = args.get("new_name").?.string orelse return error.MissingParam;
            const preview_only = if (args.get("preview_only")) |p| p.bool else true;

            const refactor_result = try refactor.renameSymbol(self.allocator, self.ast_graph, old_name, new_name, preview_only);
            defer refactor_result.deinit(self.allocator);

            var rename_result = std.json.ObjectMap.init(self.allocator);
            try rename_result.put("success", std.json.Value{ .bool = refactor_result.success });
            try rename_result.put("files_modified", std.json.Value{ .integer = refactor_result.files_modified });
            try rename_result.put("total_changes", std.json.Value{ .integer = refactor_result.total_changes });

            if (refactor_result.errors.items.len > 0) {
                var errors_array = std.json.Array.init(self.allocator);
                for (refactor_result.errors.items) |err| {
                    try errors_array.append(std.json.Value{ .string = err });
                }
                try rename_result.put("errors", std.json.Value{ .array = errors_array });
            }

            if (refactor_result.diffs.items.len > 0) {
                var diffs_array = std.json.Array.init(self.allocator);
                for (refactor_result.diffs.items) |diff| {
                    try diffs_array.append(std.json.Value{ .string = diff });
                }
                try rename_result.put("diffs", std.json.Value{ .array = diffs_array });
            }

            try result.put("rename_result", std.json.Value{ .object = rename_result });
        } else if (std.mem.eql(u8, name, "semantic_find")) {
            const query_code = args.get("query_code").?.string orelse return error.MissingParam;
            const threshold_f = if (args.get("threshold")) |t| t.float else 0.7;
            const threshold = @as(f32, @floatCast(threshold_f));
            const top_k_i = if (args.get("top_k")) |k| k.integer else 10;
            const top_k = @as(usize, @intCast(top_k_i));

            // Build semantic index from AST graph
            const embedding_dim = vsa.DEFAULT_EMBEDDING_DIM;
            var index = try vsa.buildSemanticIndex(self.allocator, self.ast_graph, embedding_dim);
            defer index.deinit();

            // Perform semantic search
            const matches = try vsa.semanticSearch(&index, query_code, top_k, threshold, self.allocator);
            defer {
                for (matches.items) |*m| {
                    m.deinit();
                }
                matches.deinit(self.allocator);
            }

            // Build response
            var matches_array = std.json.Array.init(self.allocator);
            for (matches.items) |m| {
                var match_obj = std.json.ObjectMap.init(self.allocator);
                try match_obj.put("symbol_id", std.json.Value{ .string = m.symbol_id });
                try match_obj.put("file", std.json.Value{ .string = m.file });
                try match_obj.put("line", std.json.Value{ .integer = m.line });
                try match_obj.put("similarity", std.json.Value{ .float = m.similarity });
                try match_obj.put("context_match", std.json.Value{ .float = m.context_match });
                try match_obj.put("confidence", std.json.Value{ .float = m.confidence });
                try match_obj.put("node_type", std.json.Value{ .string = @tagName(m.node_type) });
                try matches_array.append(std.json.Value{ .object = match_obj });
            }

            try result.put("matches", std.json.Value{ .array = matches_array });
            try result.put("query", std.json.Value{ .string = query_code });
            try result.put("threshold", std.json.Value{ .float = threshold });
            try result.put("total_found", std.json.Value{ .integer = matches.items.len });
        } else {
            try result.put("message", std.json.Value{ .string = "Tool not implemented yet" });
        }

        return std.json.Value{ .object = result };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse JSON-RPC request string
pub fn parseRequest(allocator: std.mem.Allocator, json_str: []const u8) !McpRequest {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str);
    errdefer parsed.deinit();

    if (parsed != .object) return error.InvalidRequest;

    const id = parsed.object.get("id").?.string orelse return error.InvalidRequest;
    const method_str = parsed.object.get("method").?.string orelse return error.InvalidRequest;
    const params = parsed.object.get("params") orelse std.json.Value{ .object = std.json.ObjectMap.init(allocator) };

    const method = std.meta.stringToEnum(McpMethod, method_str) orelse return error.UnknownMethod;

    return .{
        .id = try allocator.dupe(u8, id),
        .method = method,
        .params = params,
        .allocator = allocator,
    };
}
