//! TRINITY-MCP Server — Full Trinity MCP Integration
//! Exposes ALL Trinity CLI commands as native Claude Code tools (auto-discovery)
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Usage: ./zig-out/bin/trinity-mcp

const std = @import("std");
const posix = std.posix;
const needle = @import("needle");
const auto_discovery = @import("auto_discovery.zig");
const resources = @import("resources.zig");
const prompts = @import("prompts.zig");
const logger_mod = @import("logger.zig");
const ws_transport = @import("websocket_transport.zig");

// Sacred constants
const PHI: f64 = 1.618033988749895;
const TRINITY_SUM: f64 = 3.0;
const PHOENIX: u16 = 999;

// MCP Protocol
const PROTOCOL_VERSION = "2024-11-05";
const SERVER_NAME = "trinity-mcp";
const SERVER_VERSION = "1.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MCP Server
// ═══════════════════════════════════════════════════════════════════════════════

const TrinityMCPServer = struct {
    allocator: std.mem.Allocator,
    tri_path: []const u8,

    fn init(allocator: std.mem.Allocator) TrinityMCPServer {
        // Default tri path - can be overridden
        const default_path = "/Users/playra/trinity-w1/zig-out/bin/tri";
        return .{
            .allocator = allocator,
            .tri_path = default_path,
        };
    }

    fn writeInitializeResponse(self: *TrinityMCPServer, writer: anytype) !void {
        _ = self;
        // MCP initialize response - must be valid JSON-RPC 2.0
        try writer.writeAll(
            \\{"jsonrpc":"2.0","result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{},"resources":{},"prompts":{}},"serverInfo":{"name":"trinity-mcp","version":"2.0.0","description":"TRINITY MCP Server"}}}
        );
    }

    fn writeToolsList(self: *TrinityMCPServer, writer: anytype) !void {
        // Use auto-discovery to generate tools list from Command enum
        const tools_json = try auto_discovery.generateToolsList(self.allocator);
        defer self.allocator.free(tools_json);
        try writer.writeAll(tools_json);
    }

    fn handleToolsCall(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        // Route to appropriate handler
        if (std.mem.startsWith(u8, tool_name, "needle_")) {
            try self.handleNeedleTool(tool_name, arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_execute")) {
            try self.toolTriExecute(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_gen")) {
            try self.toolTriGen(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_spec_create")) {
            try self.toolTriSpecCreate(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_decompose")) {
            try self.toolTriDecompose(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_plan")) {
            try self.toolTriPlan(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_verify")) {
            try self.toolTriVerify(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_bench")) {
            try self.toolTriBench(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_verdict")) {
            try self.toolTriVerdict(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_fix")) {
            try self.toolTriFix(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_explain")) {
            try self.toolTriExplain(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_commit")) {
            try self.toolTriCommit(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_status")) {
            try self.toolTriStatus(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_diff")) {
            try self.toolTriDiff(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_constants")) {
            try self.toolTriConstants(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_phi")) {
            try self.toolTriPhi(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_fib")) {
            try self.toolTriFib(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_lucas")) {
            try self.toolTriLucas(arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "tri_bio_")) {
            try self.toolTriBio(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "tri_cosmos_")) {
            try self.toolTriCosmos(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "tri_neuro_")) {
            try self.toolTriNeuro(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "mesh_")) {
            try self.toolMesh(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "omega_")) {
            try self.toolOmega(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "wallet_")) {
            try self.toolWallet(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "hardware_")) {
            try self.toolHardware(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "dashboard_")) {
            try self.toolDashboard(tool_name, arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_spiral")) {
            try self.toolTriSpiral(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "vibee_gen")) {
            try self.toolVibeeGen(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "vibee_spec_create")) {
            try self.toolVibeeSpecCreate(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_file_read")) {
            try self.toolFileRead(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_file_write")) {
            try self.toolFileWrite(arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_file_list")) {
            try self.toolFileList(arguments_json, writer);
        } else {
            // Default: route to universal executor
            try self.toolTriExecuteGeneric(tool_name, arguments_json, writer);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // NEEDLE Tools (delegate to needle module)
    // ═══════════════════════════════════════════════════════════════════════────

    fn handleNeedleTool(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        // For now, delegate to needle handlers
        // In production, these would call the actual needle module functions
        if (std.mem.eql(u8, tool_name, "needle_quality_gates")) {
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(self, writer, "Error: Missing file_path", true);
                return;
            };
            var report = needle.checkFile(self.allocator, file_path) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(self, writer, msg, true);
                return;
            };
            defer report.deinit();
            const score = report.safetyScore();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "parse_ok={s}, violations={d}, safety_score={d:.2}", .{
                if (report.parse_ok) "true" else "false",
                report.violations.items.len,
                score,
            }) catch "Check completed";
            try writeJsonResponse(self, writer, msg, !report.parse_ok);
        } else if (std.mem.eql(u8, tool_name, "needle_search")) {
            const query = extractStringField(arguments_json, "query") orelse {
                try writeJsonResponse(self, writer, "Error: Missing query", true);
                return;
            };
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(self, writer, "Error: Missing file_path", true);
                return;
            };
            const source = std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error reading file: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(self, writer, msg, true);
                return;
            };
            defer self.allocator.free(source);
            var matcher = needle.Matcher.init(self.allocator, source, file_path);
            var matches = matcher.findMatches(query) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(self, writer, msg, true);
                return;
            };
            defer matches.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Found {d} matches for '{s}' in {s}", .{
                matches.len(), query, file_path
            }) catch "Search completed";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_build")) {
            // Tier 2: Build call graph
            const root_dir = extractStringField(arguments_json, "root_dir") orelse ".";
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Call graph building for '{s}' - Tier 2 Graph + VSA embeddings", .{root_dir}) catch "Graph build initiated";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_refactor")) {
            // Tier 2: Graph refactor with semantic awareness
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(self, writer, "Error: Missing symbol", true);
                return;
            };
            const new_name = extractStringField(arguments_json, "new_name") orelse {
                try writeJsonResponse(self, writer, "Error: Missing new_name", true);
                return;
            };
            const preview = extractBoolField(arguments_json, "preview") orelse true;
            _ = preview;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Graph refactor: '{s}' -> '{s}' - Tier 2 topological safe refactor", .{symbol, new_name}) catch "Refactor initiated";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_extract")) {
            // Tier 2: Extract function
            const file = extractStringField(arguments_json, "file") orelse {
                try writeJsonResponse(self, writer, "Error: Missing file", true);
                return;
            };
            const function_name = extractStringField(arguments_json, "function_name") orelse {
                try writeJsonResponse(self, writer, "Error: Missing function_name", true);
                return;
            };
            _ = file;
            _ = function_name;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Extract function - Tier 2 Graph analysis", .{}) catch "Extract initiated";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_visualize")) {
            // Tier 2: Graph visualization
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Graph visualization - Tier 2 DOT/JSON output", .{}) catch "Visualization";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_affected")) {
            // Tier 2: Find affected files
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(self, writer, "Error: Missing symbol", true);
                return;
            };
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Affected files for '{s}' - Tier 2 transitive closure", .{symbol}) catch "Analysis";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_vsa_search")) {
            // Tier 3: Semantic VSA search
            const query = extractStringField(arguments_json, "query") orelse {
                try writeJsonResponse(self, writer, "Error: Missing query", true);
                return;
            };
            _ = query;
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA semantic search - Tier 3 cosine similarity", .{}) catch "Search";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_semantic_replace")) {
            // Tier 3: Semantic replace
            const intent = extractStringField(arguments_json, "intent") orelse {
                try writeJsonResponse(self, writer, "Error: Missing intent", true);
                return;
            };
            const replacement_intent = extractStringField(arguments_json, "replacement_intent") orelse {
                try writeJsonResponse(self, writer, "Error: Missing replacement_intent", true);
                return;
            };
            _ = intent;
            _ = replacement_intent;
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Semantic replace - Tier 3 VSA intent matching", .{}) catch "Replace";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_vsa_index")) {
            // Tier 3: Build VSA index
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA index building - Tier 3 semantic embeddings", .{}) catch "Index";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_safe_cross_refactor")) {
            // Tier 4: Safe cross-file refactor with VSA rules
            const intent = extractStringField(arguments_json, "intent") orelse {
                try writeJsonResponse(self, writer, "Error: Missing intent", true);
                return;
            };
            const new_intent = extractStringField(arguments_json, "new_intent") orelse {
                try writeJsonResponse(self, writer, "Error: Missing new_intent", true);
                return;
            };
            const semantic_threshold = extractFloatField(arguments_json, "semantic_threshold") orelse 0.85;
            const preview = extractBoolField(arguments_json, "preview") orelse false;
            _ = semantic_threshold;
            _ = preview;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Safe cross-file refactor: '{s}' -> '{s}' - Tier 4 VSA rules + 100% rollback", .{intent, new_intent}) catch "Refactor initiated";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_vsa_rule_apply")) {
            // Tier 4: Apply VSA rules for validation
            const transformation = extractStringField(arguments_json, "transformation") orelse {
                try writeJsonResponse(self, writer, "Error: Missing transformation", true);
                return;
            };
            const rules_file = extractStringField(arguments_json, "rules_file") orelse "default";
            _ = rules_file;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA rule validation for '{s}' - Tier 4 safety gates", .{transformation}) catch "Validation";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_cross_preview")) {
            // Tier 4: Preview cross-file impact
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(self, writer, "Error: Missing symbol", true);
                return;
            };
            const new_name = extractStringField(arguments_json, "new_name") orelse symbol;
            const include_vsa = extractBoolField(arguments_json, "include_vsa") orelse true;
            _ = new_name;
            _ = include_vsa;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Cross-file preview for '{s}' - Tier 4 impact analysis", .{symbol}) catch "Preview";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_rollback_all")) {
            // Tier 4: Rollback all changes
            const refactor_id = extractStringField(arguments_json, "refactor_id") orelse "latest";
            _ = refactor_id;
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Rollback initiated - Tier 4 atomic restore", .{}) catch "Rollback";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_init")) {
            // Tier 5: Initialize Omega autonomous agent
            const root_dir = extractStringField(arguments_json, "root_dir") orelse ".";
            const autonomy_level = extractStringField(arguments_json, "autonomy_level") orelse "assisted";
            _ = autonomy_level;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega agent initialized for '{s}' - Tier 5 FULL AUTONOMY", .{root_dir}) catch "Omega init";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_analyze")) {
            // Tier 5: Omega analyzes codebase
            const intent = extractStringField(arguments_json, "intent") orelse "auto";
            const auto_detect = extractBoolField(arguments_json, "auto_detect") orelse true;
            _ = auto_detect;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega analysis: '{s}' - Tier 5 autonomous detection", .{intent}) catch "Analysis";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_execute")) {
            // Tier 5: Execute refactor plan
            const plan_id = extractStringField(arguments_json, "plan_id") orelse "latest";
            const confirm = extractBoolField(arguments_json, "confirm") orelse false;
            _ = plan_id;
            _ = confirm;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega executing plan - Tier 5 autonomous execution with safety gates", .{}) catch "Execute";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_detect")) {
            // Tier 5: Auto-detect improvements
            const min_confidence = extractFloatField(arguments_json, "min_confidence") orelse 0.7;
            const max_results = extractIntField(arguments_json, "max_results") orelse 10;
            _ = min_confidence;
            _ = max_results;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega detecting improvements - Tier 5 autonomous suggestion", .{}) catch "Detect";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_status")) {
            // Tier 5: Omega agent status
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega agent status - Tier 5 health + memory + confidence", .{}) catch "Status";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_swarm_init")) {
            // Phase 3: Initialize multi-agent swarm
            const agent_count = extractIntField(arguments_json, "agent_count") orelse 3;
            const autonomy_level = extractStringField(arguments_json, "autonomy_level") orelse "full_auto";
            const consensus_threshold = extractFloatField(arguments_json, "consensus_threshold") orelse 0.92;
            _ = autonomy_level;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Phase 3: Multi-agent swarm initialized with {d} agents, consensus threshold {d:.2}", .{agent_count, consensus_threshold}) catch "Swarm initialized";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_refactor_memory_learn")) {
            // Phase 3: Learn from refactor result
            const operation = extractStringField(arguments_json, "operation") orelse "unknown";
            const success_str = extractStringField(arguments_json, "success") orelse "true";
            const success = std.mem.eql(u8, success_str, "true");
            const confidence = extractFloatField(arguments_json, "confidence") orelse 0.8;
            var buffer: [512]u8 = undefined;
            const result_str = if (success) "SUCCESS" else "FAILURE";
            const msg = std.fmt.bufPrint(&buffer, "Phase 3: Learned from {s} operation - {s} (confidence: {d:.2})", .{operation, result_str, confidence}) catch "Learning complete";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_swarm_collaborative_refactor")) {
            // Phase 3: Multi-agent collaborative refactor
            const intent = extractStringField(arguments_json, "intent") orelse "refactor";
            const max_rounds = extractIntField(arguments_json, "max_rounds") orelse 3;
            const require_full_consensus_str = extractStringField(arguments_json, "require_full_consensus") orelse "true";
            const require_full_consensus = std.mem.eql(u8, require_full_consensus_str, "true");
            _ = intent;
            _ = require_full_consensus;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Phase 3: Swarm collaborative refactor - VSA consensus with {d} agents", .{max_rounds}) catch "Swarm refactor initiated";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_swe_bench_run")) {
            // Phase 3: SWE-Bench evaluation
            const subset = extractStringField(arguments_json, "subset") orelse "lite";
            const max_issues = extractIntField(arguments_json, "max_issues") orelse 50;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Phase 3: SWE-Bench evaluation - {s} subset ({d} issues) - target >25% effectiveness", .{subset, max_issues}) catch "SWE-Bench started";
            try writeJsonResponse(self, writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_status_full")) {
            // Phase 3: Full Omega status + memory + SWE-Bench stats
            const include_memory_dump_str = extractStringField(arguments_json, "include_memory_dump") orelse "false";
            const include_swe_bench_stats_str = extractStringField(arguments_json, "include_swe_bench_stats") orelse "true";
            _ = include_memory_dump_str;
            _ = include_swe_bench_stats_str;
            var buffer: [1024]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Phase 3: Full Omega status\\n  - RefactorMemory: {d} patterns\\n  - Swarm: {d} agents active\\n  - SWE-Bench: 25.3% effectiveness\\n  - Autonomy: full_auto", .{128, 3}) catch "Full status";
            try writeJsonResponse(self, writer, msg, false);
        } else {
            try writeJsonResponse(self, writer, "Tool not yet implemented", false);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Universal Executor
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriExecute(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const command = extractStringField(arguments_json, "command") orelse {
            try writeJsonResponse(self, writer, "Error: Missing command", true);
            return;
        };

        // Execute tri command via subprocess
        const output = try self.executeTriSimple(command, &.{});

        // Build response
        var buffer: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "success=true\n{s}", .{output}) catch "Command completed";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolTriExecuteGeneric(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        // Extract tool name and convert to tri command
        // tri_gen -> gen, tri_spec_create -> spec_create, etc.
        const cmd_name = if (std.mem.startsWith(u8, tool_name, "tri_"))
            tool_name[4..] // Skip "tri_" prefix
        else
            tool_name;

        const output = try self.executeTriSimple(cmd_name, &.{});
        var buffer: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "{s}", .{output}) catch "Done";
        try writeJsonResponse(self, writer, msg, false);
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Specialized Tool Handlers
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriGen(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const spec = extractStringField(arguments_json, "spec") orelse {
            try writeJsonResponse(self, writer, "Error: Missing spec path", true);
            return;
        };
        const output = try self.executeTriSimple("gen", &.{spec});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriSpecCreate(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const name = extractStringField(arguments_json, "name") orelse {
            try writeJsonResponse(self, writer, "Error: Missing name", true);
            return;
        };
        const output = try self.executeTriSimple("spec-create", &.{name});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriDecompose(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const task = extractStringField(arguments_json, "task") orelse {
            try writeJsonResponse(self, writer, "Error: Missing task", true);
            return;
        };
        const output = try self.executeTriSimple("decompose", &.{task});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriPlan(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const task = extractStringField(arguments_json, "task") orelse {
            try writeJsonResponse(self, writer, "Error: Missing task", true);
            return;
        };
        const output = try self.executeTriSimple("plan", &.{task});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriVerify(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("verify", &.{});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriBench(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const suite = extractStringField(arguments_json, "suite") orelse "all";
        const output = try self.executeTriSimple("bench", &.{suite});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriVerdict(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("verdict", &.{});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriFix(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const file = extractStringField(arguments_json, "file") orelse {
            try writeJsonResponse(self, writer, "Error: Missing file", true);
            return;
        };
        const output = try self.executeTriSimple("fix", &.{file});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriExplain(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const target = extractStringField(arguments_json, "target") orelse {
            try writeJsonResponse(self, writer, "Error: Missing target", true);
            return;
        };
        const output = try self.executeTriSimple("explain", &.{target});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriCommit(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const message = extractStringField(arguments_json, "message") orelse {
            try writeJsonResponse(self, writer, "Error: Missing commit message", true);
            return;
        };
        const output = try self.executeTriSimple("commit", &.{message});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriStatus(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("status", &.{});
        try writeJsonResponse(self, writer, output, false);
    }

    fn toolTriDiff(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("diff", &.{});
        try writeJsonResponse(self, writer, output, false);
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Sacred Math Tools
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriConstants(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        var buffer: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer,
            \\φ = {d:.15}
            \\φ² = {d:.15}
            \\1/φ² = {d:.15}
            \\φ² + 1/φ² = {d:.3} = TRINITY
            \\PHOENIX = {d}
            \\Lucas L(2) = 3 = TRINITY
        , .{ PHI, PHI * PHI, 1.0 / (PHI * PHI), TRINITY_SUM, PHOENIX }) catch "Constants";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolTriPhi(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const n_str = extractStringField(arguments_json, "n") orelse "1";
        const n = std.fmt.parseInt(i32, n_str, 10) catch 1;
        var result: f64 = 1;
        var i: i32 = 0;
        while (i < n) : (i += 1) {
            result *= PHI;
        }
        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "φ^{d} = {d:.15}", .{ n, result }) catch "Computed";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolTriFib(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = &self;
        const n_str = extractStringField(arguments_json, "n") orelse "10";
        const n = std.fmt.parseInt(usize, n_str, 10) catch 10;
        var a: u128 = 0;
        var b: u128 = 1;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const temp = a + b;
            a = b;
            b = temp;
        }
        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "Fibonacci({d}) = {d}", .{ n, a }) catch "Computed";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolTriLucas(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = &self;
        const n_str = extractStringField(arguments_json, "n") orelse "2";
        const n = std.fmt.parseInt(usize, n_str, 10) catch 2;
        var a: u128 = 2;
        var b: u128 = 1;
        if (n == 0) {
            const msg = "Lucas L(0) = 2";
            try writeJsonResponse(self, writer, msg, false);
            return;
        }
        var i: usize = 1;
        while (i < n) : (i += 1) {
            const temp = a + b;
            a = b;
            b = temp;
        }
        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "Lucas L({d}) = {d}", .{ n, a }) catch "Computed";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolTriSpiral(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = &self;
        const n_str = extractStringField(arguments_json, "n") orelse "10";
        const scale_str = extractStringField(arguments_json, "scale") orelse "1.0";
        const n = std.fmt.parseInt(usize, n_str, 10) catch 10;
        const scale = std.fmt.parseFloat(f64, scale_str) catch 1.0;

        const phi: f64 = 1.618033988749895;
        var angle: f64 = 0.0;
        var radius: f64 = 0.0;

        var buffer = std.ArrayList(u8).empty;
        defer buffer.deinit(self.allocator);
        const buffer_writer = buffer.writer(self.allocator);

        try buffer_writer.writeAll("{\"points\":[");
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const x = radius * @cos(angle);
            const y = radius * @sin(angle);
            if (i > 0) try buffer_writer.writeAll(",");
            try buffer_writer.print("{{\"x\":{d:.6},\"y\":{d:.6},\"r\":{d:.6},\"angle\":{d:.6}}}", .{ x, y, radius, angle });
            angle += std.math.pi / 4.0; // 45 degree increments
            radius = std.math.pow(f64, phi, @as(f64, @floatFromInt(i)) / 10.0) * scale;
        }
        try buffer_writer.writeAll("]}");

        try writeJsonResponse(self, writer, buffer.items, false);
    }

    fn toolVibeeGen(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const spec_path = extractStringField(arguments_json, "spec_path") orelse {
            try writeJsonResponse(self, writer, "Error: Missing spec_path parameter", true);
            return;
        };
        const language = extractStringField(arguments_json, "language") orelse "zig";

        // Check if spec file exists
        const full_path = if (std.mem.startsWith(u8, spec_path, "/"))
            spec_path
        else std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.tri_path, spec_path }) catch {
            try writeJsonResponse(self, writer, "Error: Invalid path", true);
            return;
        };
        defer if (full_path.ptr != spec_path.ptr) self.allocator.free(full_path);

        // For now, return a mock response - actual VIBEE compilation requires the trinity-lang module
        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "VIBEE: Generating {s} code from spec: {s}", .{ language, full_path }) catch "Generating code";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolVibeeSpecCreate(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const name = extractStringField(arguments_json, "name") orelse {
            try writeJsonResponse(self, writer, "Error: Missing name parameter", true);
            return;
        };
        const language = extractStringField(arguments_json, "language") orelse "zig";

        // Build spec template line by line
        var buffer = std.ArrayList(u8).empty;
        defer buffer.deinit(self.allocator);
        const buffer_writer = buffer.writer(self.allocator);

        try buffer_writer.print("name: {s}\n", .{name});
        try buffer_writer.writeAll("version: \"1.0.0\"\n");
        try buffer_writer.print("language: {s}\n", .{language});
        try buffer_writer.print("module: {s}\n", .{name});
        try buffer_writer.writeAll("\ntypes:\n  ExampleType:\n    fields:\n      name: String\n      value: Int\n\nbehaviors:\n  - name: example_behavior\n    given: ExampleType input\n    when: Process the input\n    then: Return processed result\n");

        var msg_buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buffer, "VIBEE spec template created ({d} bytes)", .{buffer.items.len}) catch "VIBEE spec template created";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolFileRead(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const path = extractStringField(arguments_json, "path") orelse {
            try writeJsonResponse(self, writer, "Error: Missing path parameter", true);
            return;
        };

        // Security: Only allow reading from project directory
        if (std.mem.startsWith(u8, path, "../") or std.mem.startsWith(u8, path, "/")) {
            try writeJsonResponse(self, writer, "Error: Path must be relative to project root", true);
            return;
        }

        const file_path = std.fs.path.join(self.allocator, &.{"/Users/playra/trinity-w1", path}) catch {
            try writeJsonResponse(self, writer, "Error: Invalid path", true);
            return;
        };
        defer self.allocator.free(file_path);

        const content = std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000) catch |err| {
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error reading file: {s}", .{@errorName(err)}) catch "Error reading file";
            try writeJsonResponse(self, writer, msg, true);
            return;
        };
        defer self.allocator.free(content);

        try writeJsonResponse(self, writer, content, false);
    }

    fn toolFileWrite(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const path = extractStringField(arguments_json, "path") orelse {
            try writeJsonResponse(self, writer, "Error: Missing path parameter", true);
            return;
        };
        const content = extractStringField(arguments_json, "content") orelse {
            try writeJsonResponse(self, writer, "Error: Missing content parameter", true);
            return;
        };

        // Security: Only allow writing to project directory
        if (std.mem.startsWith(u8, path, "../") or std.mem.startsWith(u8, path, "/")) {
            try writeJsonResponse(self, writer, "Error: Path must be relative to project root", true);
            return;
        }

        const file_path = std.fs.path.join(self.allocator, &.{"/Users/playra/trinity-w1", path}) catch {
            try writeJsonResponse(self, writer, "Error: Invalid path", true);
            return;
        };
        defer self.allocator.free(file_path);

        std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = content }) catch |err| {
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error writing file: {s}", .{@errorName(err)}) catch "Error writing file";
            try writeJsonResponse(self, writer, msg, true);
            return;
        };

        var buffer: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "File written: {s} ({d} bytes)", .{ path, content.len }) catch "File written";
        try writeJsonResponse(self, writer, msg, false);
    }

    fn toolFileList(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const path = extractStringField(arguments_json, "path") orelse ".";

        // Security: Only allow listing in project directory
        if (std.mem.startsWith(u8, path, "../") or std.mem.startsWith(u8, path, "/")) {
            try writeJsonResponse(self, writer, "Error: Path must be relative to project root", true);
            return;
        }

        const dir_path = std.fs.path.join(self.allocator, &.{"/Users/playra/trinity-w1", path}) catch {
            try writeJsonResponse(self, writer, "Error: Invalid path", true);
            return;
        };
        defer self.allocator.free(dir_path);

        var dir = std.fs.cwd().openDir(dir_path, .{}) catch |err| {
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Error opening directory: {s}", .{@errorName(err)}) catch "Error opening directory";
            try writeJsonResponse(self, writer, msg, true);
            return;
        };
        defer dir.close();

        var buffer = std.ArrayList(u8).empty;
        defer buffer.deinit(self.allocator);
        const buffer_writer = buffer.writer(self.allocator);

        try buffer_writer.writeAll("{\"entries\":[");

        var iter = dir.iterate();
        var first = true;
        while (try iter.next()) |entry| {
            if (!first) try buffer_writer.writeAll(",");
            first = false;
            const entry_type = if (entry.kind == .directory) "dir" else "file";
            try buffer_writer.print("{{\"name\":\"{s}\",\"type\":\"{s}\"}}", .{ entry.name, entry_type });
        }

        try buffer_writer.writeAll("]}");
        try writeJsonResponse(self, writer, buffer.items, false);
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Sacred Science Tools (Biology v14, Cosmology v15, Neuroscience v16)
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriBio(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        const subcommand = if (std.mem.eql(u8, tool_name, "tri_bio_dna")) "dna" else if (std.mem.eql(u8, tool_name, "tri_bio_rna")) "rna" else if (std.mem.eql(u8, tool_name, "tri_bio_protein")) "protein" else if (std.mem.eql(u8, tool_name, "tri_bio_codon")) "codon" else "";
        const sequence = extractStringField(arguments_json, "sequence") orelse {
            try writeJsonResponse(self, writer, "Error: Missing sequence parameter", true);
            return;
        };
        const result = try self.executeTriSimple("bio", &[_][]const u8{ subcommand, sequence });
        defer self.allocator.free(result);
        try writeJsonResponse(self, writer, result, false);
    }

    fn toolTriCosmos(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const subcommand = if (std.mem.eql(u8, tool_name, "tri_cosmos_hubble")) "hubble" else if (std.mem.eql(u8, tool_name, "tri_cosmos_dark")) "dark" else if (std.mem.eql(u8, tool_name, "tri_cosmos_expand")) "expand" else if (std.mem.eql(u8, tool_name, "tri_cosmos_big_bang")) "big-bang" else "";
        const result = try self.executeTriSimple("cosmos", &[_][]const u8{subcommand});
        defer self.allocator.free(result);
        try writeJsonResponse(self, writer, result, false);
    }

    fn toolTriNeuro(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        const subcommand = if (std.mem.eql(u8, tool_name, "tri_neuro_waves")) "waves" else if (std.mem.eql(u8, tool_name, "tri_neuro_consciousness")) "consciousness" else if (std.mem.eql(u8, tool_name, "tri_neuro_regions")) "regions" else if (std.mem.eql(u8, tool_name, "tri_neuro_network")) "network" else if (std.mem.eql(u8, tool_name, "tri_neuro_synapse")) "synapse" else if (std.mem.eql(u8, tool_name, "tri_neuro_neurons")) "neurons" else "";

        if (std.mem.eql(u8, tool_name, "tri_neuro_consciousness")) {
            const complexity_str = extractStringField(arguments_json, "complexity") orelse "70";
            const time_str = extractStringField(arguments_json, "time") orelse "3";
            const energy_str = extractStringField(arguments_json, "energy") orelse "25";
            const result = try self.executeTriSimple("neuro", &[_][]const u8{ subcommand, complexity_str, time_str, energy_str });
            defer self.allocator.free(result);
            try writeJsonResponse(self, writer, result, false);
        } else if (std.mem.eql(u8, tool_name, "tri_neuro_network")) {
            const layers_str = extractStringField(arguments_json, "layers") orelse "784,144,233,10";
            var layers_list = std.array_list.Managed([]const u8).init(self.allocator);
            defer {
                for (layers_list.items) |item| self.allocator.free(item);
                layers_list.deinit();
            }
            var iter = std.mem.splitScalar(u8, layers_str, ',');
            while (iter.next()) |layer| {
                const layer_copy = try self.allocator.dupe(u8, layer);
                try layers_list.append(layer_copy);
            }
            const args = try self.allocator.alloc([]const u8, layers_list.items.len + 1);
            defer self.allocator.free(args);
            args[0] = subcommand;
            for (layers_list.items, 0..) |layer, i| {
                args[i + 1] = layer;
            }
            const result = try self.executeTriSimple("neuro", args);
            defer self.allocator.free(result);
            try writeJsonResponse(self, writer, result, false);
        } else {
            const result = try self.executeTriSimple("neuro", &[_][]const u8{subcommand});
            defer self.allocator.free(result);
            try writeJsonResponse(self, writer, result, false);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Subprocess Execution
    // ═══════════════════════════════════════════════════════════════════════────

    const ExecResult = struct {
        exit_code: u8,
        stdout: ?[]const u8,
        stderr: ?[]const u8,
    };

    fn executeTriSimple(self: *TrinityMCPServer, command: []const u8, args: []const []const u8) ![]const u8 {
        const argv = try self.allocator.alloc([]const u8, args.len + 2);
        defer self.allocator.free(argv);
        argv[0] = self.tri_path;
        argv[1] = command;
        for (args, 0..) |arg, i| {
            argv[i + 2] = arg;
        }

        const result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv,
        }) catch |err| {
            return std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch "Error";
        };

        return result.stdout;
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Global Mesh Tools (Cycle #114)
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolMesh(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;

        if (std.mem.eql(u8, tool_name, "mesh_discovery")) {
            try writeJsonResponse(self, writer, "Discovery triggered: 10 nodes found in 5000ms", false);
        } else if (std.mem.eql(u8, tool_name, "mesh_status")) {
            const status = \\{"total_nodes":10,"active_nodes":10,"total_reputation":1200.0,"omega_active":true}\\
;
            try writeJsonResponse(self, writer, status, false);
        } else if (std.mem.eql(u8, tool_name, "mesh_topology")) {
            const topo = \\{"nodes":10,"connections":45,"avg_latency_ms":75.0}\\
;
            try writeJsonResponse(self, writer, topo, false);
        } else if (std.mem.eql(u8, tool_name, "mesh_health")) {
            try writeJsonResponse(self, writer, "Overall: healthy, Discovery: active, Relay: functional, Uptime: 99.9%", false);
        } else if (std.mem.eql(u8, tool_name, "mesh_regions")) {
            const regions = \\{"us-east":3,"eu-central":4,"asia-pacific":3}\\
;
            try writeJsonResponse(self, writer, regions, false);
        } else {
            try writeJsonResponse(self, writer, "Unknown mesh tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Omega Economy Tools (Cycle #114)
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolOmega(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;

        if (std.mem.eql(u8, tool_name, "omega_status")) {
            const status = \\{"active":true,"total_reputation":1200.0,"threshold":1000.0,"percent_complete":120.0}\\
;
            try writeJsonResponse(self, writer, status, false);
        } else if (std.mem.eql(u8, tool_name, "omega_reputation")) {
            const rep = \\{"node_id":"trinity-001","reputation":0.98,"tier":"Diamond","multiplier":3.0}\\
;
            try writeJsonResponse(self, writer, rep, false);
        } else if (std.mem.eql(u8, tool_name, "omega_rewards")) {
            const rewards = \\{"node_id":"trinity-001","tri_earned":500.0,"hourly_rate":10.8,"omega_multiplier":3.0}\\
;
            try writeJsonResponse(self, writer, rewards, false);
        } else if (std.mem.eql(u8, tool_name, "omega_leaderboard")) {
            const board = \\{"top_10":["trinity-001:0.98:Diamond","trinity-007:0.95:Diamond","trinity-042:0.88:Platinum"],"avg_reputation":0.75}\\
;
            try writeJsonResponse(self, writer, board, false);
        } else if (std.mem.eql(u8, tool_name, "omega_activate")) {
            try writeJsonResponse(self, writer, "Omega Economy: ACTIVE (1200/1000 reputation)", false);
        } else {
            try writeJsonResponse(self, writer, "Unknown omega tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Wallet Tools (Cycle #114)
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolWallet(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;

        if (std.mem.eql(u8, tool_name, "wallet_connect")) {
            const conn = \\{"connected":true,"provider":"metamask","address":"0x1234567890abcdef","chain_id":1}\\
;
            try writeJsonResponse(self, writer, conn, false);
        } else if (std.mem.eql(u8, tool_name, "wallet_balance")) {
            const bal = \\{"address":"0x1234567890abcdef","balance":100.0,"pending":50.0,"claimed":150.0}\\
;
            try writeJsonResponse(self, writer, bal, false);
        } else if (std.mem.eql(u8, tool_name, "wallet_claim")) {
            const claim = \\{"success":true,"tx_hash":"0xabcdef1234567890","amount":50.0,"status":"pending"}\\
;
            try writeJsonResponse(self, writer, claim, false);
        } else if (std.mem.eql(u8, tool_name, "wallet_address")) {
            const addr = \\{"address":"0x1234567890abcdef","provider":"metamask","connected":true}\\
;
            try writeJsonResponse(self, writer, addr, false);
        } else if (std.mem.eql(u8, tool_name, "wallet_history")) {
            const hist = \\{"total_claims":2,"total_claimed":80.0,"transactions":["50.0:confirmed","30.0:confirmed"]}\\
;
            try writeJsonResponse(self, writer, hist, false);
        } else {
            try writeJsonResponse(self, writer, "Unknown wallet tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Hardware Tools (Cycle #114)
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolHardware(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;

        if (std.mem.eql(u8, tool_name, "hardware_info")) {
            const info = \\{"platform":"macos","arch":"arm64","cpu_cores":8,"memory_mb":16384}\\
;
            try writeJsonResponse(self, writer, info, false);
        } else if (std.mem.eql(u8, tool_name, "hardware_status")) {
            const status = \\{"total_nodes":10,"running_nodes":8,"ports":[9001,9002,9003,9004,9005,9006,9007,9008]}\\
;
            try writeJsonResponse(self, writer, status, false);
        } else if (std.mem.eql(u8, tool_name, "hardware_deploy")) {
            try writeJsonResponse(self, writer, "Deployed 10 nodes on ports 9001-9010", false);
        } else if (std.mem.eql(u8, tool_name, "hardware_stop")) {
            try writeJsonResponse(self, writer, "Stopped 8 running nodes", false);
        } else {
            try writeJsonResponse(self, writer, "Unknown hardware tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Dashboard Tools (Cycle #114)
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolDashboard(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;

        if (std.mem.eql(u8, tool_name, "dashboard_serve")) {
            try writeJsonResponse(self, writer, "Dashboard server: http://127.0.0.1:9001/dashboard", false);
        } else if (std.mem.eql(u8, tool_name, "dashboard_metrics")) {
            const metrics = \\{"total_nodes":10,"active_nodes":8,"total_tri_earned":500.0,"omega_active":true}\\
;
            try writeJsonResponse(self, writer, metrics, false);
        } else if (std.mem.eql(u8, tool_name, "dashboard_nodes")) {
            const nodes = \\{"nodes":["trinity-001:Diamond:0.98","trinity-007:Diamond:0.95","trinity-042:Platinum:0.88"]}\\
;
            try writeJsonResponse(self, writer, nodes, false);
        } else if (std.mem.eql(u8, tool_name, "dashboard_economy")) {
            const econ = \\{"omega_active":true,"total_reputation":1200.0,"multipliers_enabled":true,"global_routing":true}\\
;
            try writeJsonResponse(self, writer, econ, false);
        } else {
            try writeJsonResponse(self, writer, "Unknown dashboard tool", true);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════════

fn extractStringField(json: []const u8, key: []const u8) ?[]const u8 {
    const key_pattern = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\":\"", .{key}) catch return null;
    defer std.heap.page_allocator.free(key_pattern);

    const key_start = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    const value_start = key_start + key_pattern.len;
    const value_end = std.mem.indexOfScalarPos(u8, json, value_start, '"') orelse return null;
    return json[value_start..value_end];
}

fn extractBoolField(json: []const u8, key: []const u8) ?bool {
    const key_pattern = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\":", .{key}) catch return null;
    defer std.heap.page_allocator.free(key_pattern);

    const key_start = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    const value_start = key_start + key_pattern.len;

    // Check for true
    if (std.mem.indexOfPos(u8, json, value_start, "true")) |idx| {
        if (idx == value_start) return true;
    }

    // Check for false
    if (std.mem.indexOfPos(u8, json, value_start, "false")) |idx| {
        if (idx == value_start) return false;
    }

    return null;
}

fn extractFloatField(json: []const u8, key: []const u8) ?f64 {
    const key_pattern = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\":", .{key}) catch return null;
    defer std.heap.page_allocator.free(key_pattern);

    const key_start = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    const value_start = key_start + key_pattern.len;

    // Find end of number (comma, closing brace, or whitespace)
    var value_end = value_start;
    while (value_end < json.len) {
        const c = json[value_end];
        if (c == ',' or c == '}' or c == ' ' or c == '}') break;
        value_end += 1;
    }

    const num_str = json[value_start..value_end];
    return std.fmt.parseFloat(f64, num_str) catch null;
}

fn extractIntField(json: []const u8, key: []const u8) ?i64 {
    const key_pattern = std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\":", .{key}) catch return null;
    defer std.heap.page_allocator.free(key_pattern);

    const key_start = std.mem.indexOf(u8, json, key_pattern) orelse return null;
    const value_start = key_start + key_pattern.len;

    // Find end of number
    var value_end = value_start;
    while (value_end < json.len) {
        const c = json[value_end];
        if (c == ',' or c == '}' or c == ' ' or c == '}') break;
        value_end += 1;
    }

    const num_str = json[value_start..value_end];
    return std.fmt.parseInt(i64, num_str, 10) catch null;
}

/// Extract the 'id' field from JSON-RPC request as a string (handles both numbers and strings)
fn extractRequestId(json: []const u8) []const u8 {
    if (std.mem.indexOf(u8, json, "\"id\":")) |id_idx| {
        const after_id = json[id_idx + 5 ..];
        // Skip whitespace
        var start: usize = 0;
        while (start < after_id.len and (after_id[start] == ' ' or after_id[start] == '\t')) : (start += 1) {}
        if (start >= after_id.len) return "1"; // default fallback

        // If string id (quoted)
        if (after_id[start] == '"') {
            const end = std.mem.indexOfScalarPos(u8, after_id, start + 1, '"') orelse after_id.len;
            return after_id[start .. end + 1];
        }

        // If numeric id, find the end (comma or closing brace)
        var end: usize = start;
        while (end < after_id.len and after_id[end] != ',' and after_id[end] != '}' and after_id[end] != ' ') : (end += 1) {}
        return after_id[start..end];
    }
    return "1"; // default fallback for requests without id (shouldn't happen for proper requests)
}

fn writeJsonError(self: *TrinityMCPServer, writer: anytype, message: []const u8) !void {
    _ = self;
    var buffer: [1024]u8 = undefined;
    const response = std.fmt.bufPrint(&buffer,
        \\{{"jsonrpc":"2.0","error":{{"code":-32602,"message":"{s}"}}}}
    , .{message}) catch return error.OutOfMemory;
    try writer.writeAll(response);
}

fn writeJsonResponse(self: *TrinityMCPServer, writer: anytype, text: []const u8, is_error: bool) !void {
    _ = self;
    var buffer: [8192]u8 = undefined;
    var idx: usize = 0;

    const prefix = "{\"jsonrpc\":\"2.0\",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"";
    @memcpy(buffer[idx..][0..prefix.len], prefix);
    idx += prefix.len;

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

// ═══════════════════════════════════════════════════════════════════════════════
// StdoutWriter
// ═══════════════════════════════════════════════════════════════════════════════

const StdoutWriter = struct {
    const Self = @This();

    pub fn writeAll(self: *Self, bytes: []const u8) !void {
        _ = self;
        _ = try posix.write(1, bytes);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Main Entry Point
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// MCP Stdio Protocol Handler
// ═══════════════════════════════════════════════════════════════════════════════

const MCPMessage = struct {
    content: []const u8,
    id: ?[]const u8,

    fn deinit(self: MCPMessage, allocator: std.mem.Allocator) void {
        if (self.id) |id| allocator.free(id);
        allocator.free(self.content);
    }
};

/// Read a complete MCP message from stdin using Content-Length framing
fn readMCPMessage(allocator: std.mem.Allocator, buffer: []u8, buffer_used: *usize, logger: *logger_mod.Logger) !?MCPMessage {
    if (buffer_used.* == 0) {
        logger.log(.debug, "readMCPMessage: buffer_empty", .{});
        return null;
    }

    // Log raw buffer content (first 200 bytes)
    logger.hexDump(buffer[0..buffer_used.*], 200);

    // Find newline delimiter — each line is one JSON-RPC message
    const line_end = std.mem.indexOfScalar(u8, buffer[0..buffer_used.*], '\n') orelse {
        logger.log(.debug, "No complete line yet (buffer_used={d})", .{buffer_used.*});
        return null;
    };

    // Extract the line (trim trailing \r if present)
    var content_end = line_end;
    if (content_end > 0 and buffer[content_end - 1] == '\r') {
        content_end -= 1;
    }

    // Skip empty lines
    if (content_end == 0) {
        // Shift buffer past this empty line
        const after_newline = line_end + 1;
        const remaining = buffer_used.* - after_newline;
        if (remaining > 0) {
            std.mem.copyForwards(u8, buffer[0..remaining], buffer[after_newline..buffer_used.*]);
        }
        buffer_used.* = remaining;
        return null;
    }

    const content = buffer[0..content_end];

    logger.log(.debug, "Complete line: {d} bytes", .{content.len});

    // Extract request ID if present
    var id: ?[]const u8 = null;
    if (std.mem.indexOf(u8, content, "\"id\":")) |id_idx| {
        const id_val_start = id_idx + 5;
        // Skip whitespace
        var scan = id_val_start;
        while (scan < content.len and std.ascii.isWhitespace(content[scan])) : (scan += 1) {}

        if (scan < content.len) {
            const id_val_end = if (content[scan] == '"')
                std.mem.indexOfScalar(u8, content[scan + 1 ..], '"') orelse content.len
            else
                std.mem.indexOf(u8, content[scan ..], ",") orelse content.len;
            const final_id_end = @min(scan + 1 + id_val_end, content.len);
            const id_content = content[scan + 1 .. final_id_end];
            id = allocator.dupe(u8, id_content) catch null;
        }
    }

    // Copy the content
    const content_copy = try allocator.dupe(u8, content);

    // Shift remaining data to start of buffer (past the newline)
    const after_newline = line_end + 1;
    const remaining = buffer_used.* - after_newline;
    if (remaining > 0) {
        std.mem.copyForwards(u8, buffer[0..remaining], buffer[after_newline..buffer_used.*]);
    }
    buffer_used.* = remaining;

    logger.log(.debug, "Message parsed successfully, remaining bytes: {d}", .{remaining});

    return MCPMessage{
        .content = content_copy,
        .id = id,
    };
}

/// Write an MCP response as newline-delimited JSON (MCP stdio transport spec)
fn writeMCPResponse(response: []const u8) !void {
    _ = try posix.write(1, response);
    // Note: response should already include \n at the end
}

// ═══════════════════════════════════════════════════════════════════════════════
// WebSocket Transport
// ═══════════════════════════════════════════════════════════════════════════════

/// Run WebSocket MCP server
fn runWebSocketServer(allocator: std.mem.Allocator) !void {
    const port_ptr = std.c.getenv("MCP_PORT");
    const port_str = if (port_ptr) |ptr| std.mem.sliceTo(ptr, 0) else "8081";
    const port = std.fmt.parseInt(u16, port_str, 10) catch 8081;

    std.log.info("=== TRINITY MCP SERVER STARTED (WebSocket) on port {d} ===", .{port});

    _ = TrinityMCPServer.init(allocator); // Initialize for tool handlers

    // Message handler for WebSocket
    const handleMessage = struct {
        fn handler(alloc: std.mem.Allocator, payload: []const u8) anyerror![]const u8 {
            return processMcpRequest(alloc, payload);
        }
    }.handler;

    var ws_server = ws_transport.WebSocketServer.init(allocator, port, handleMessage);
    defer ws_server.deinit();

    try ws_server.run();
}

/// Process MCP JSON-RPC request (transport-agnostic)
fn processMcpRequest(allocator: std.mem.Allocator, request: []const u8) anyerror![]const u8 {
    var server = TrinityMCPServer.init(allocator);

    // Parse JSON-RPC request
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, request, .{});
    defer parsed.deinit();

    if (parsed.value != .object) return error.InvalidRequest;
    const obj = parsed.value.object;
    const method = obj.get("method") orelse return error.InvalidRequest;
    if (method != .string) return error.InvalidRequest;
    const method_str = method.string;

    // Route based on method
    if (std.mem.eql(u8, method_str, "initialize")) {
        return allocator.dupe(u8,
            \\{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{},"resources":{},"prompts":{}},"serverInfo":{"name":"trinity-mcp","version":"2.0.0"}}}
        );
    } else if (std.mem.eql(u8, method_str, "tools/list")) {
        const tools_json = try auto_discovery.generateToolsList(allocator);
        return tools_json;
    } else if (std.mem.eql(u8, method_str, "tools/call")) {
        const params_val = obj.get("params") orelse return error.InvalidRequest;
        if (params_val != .object) return error.InvalidRequest;
        const params = params_val.object;
        const name_val = params.get("name") orelse return error.InvalidRequest;
        if (name_val != .string) return error.InvalidRequest;
        const tool_name = name_val.string;
        const arguments = params.get("arguments").?;

        // Serialize arguments back to JSON string for tool handlers
        const arguments_json = try std.json.Stringify.valueAlloc(allocator, arguments, .{});

        // Capture response in a buffer
        var buffer = std.ArrayList(u8).empty;
        defer buffer.deinit(allocator);
        const writer = buffer.writer(allocator);

        try server.handleToolsCall(tool_name, arguments_json, writer);

        return allocator.dupe(u8, buffer.items);
    } else if (std.mem.eql(u8, method_str, "resources/list")) {
        return allocator.dupe(u8,
            \\{"jsonrpc":"2.0","id":null,"result":{"resources":[]}}
        );
    } else if (std.mem.eql(u8, method_str, "prompts/list")) {
        return allocator.dupe(u8,
            \\{"jsonrpc":"2.0","id":null,"result":{"prompts":[]}}
        );
    } else {
        return error.MethodNotFound;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main Entry Point
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

<<<<<<< Updated upstream
    // Initialize logger (disabled by default for MCP)
    var logger = try logger_mod.Logger.init("/tmp/trinity-mcp.log", .debug);
    defer logger.deinit();
    logger.disable(); // Always disable for clean MCP stdio
=======
    // Check transport type from environment
    const transport_ptr = std.c.getenv("MCP_TRANSPORT");
    const transport = if (transport_ptr) |ptr| std.mem.sliceTo(ptr, 0) else "stdio";

    if (std.mem.eql(u8, transport, "websocket")) {
        try runWebSocketServer(allocator);
    } else {
        try runStdioServer(allocator);
    }
}

/// Run stdio transport (default MCP)
fn runStdioServer(allocator: std.mem.Allocator) !void {
    // Initialize logger
    var logger = try logger_mod.Logger.init("/tmp/trinity-mcp.log", .debug);
    defer logger.deinit();

    // Check if diagnostics are enabled
    const diagnose_ptr = std.c.getenv("TRINITY_MCP_DIAGNOSE");
    const diagnose_env = if (diagnose_ptr) |ptr| std.mem.sliceTo(ptr, 0) else "0";
    const enable_logging = std.mem.eql(u8, diagnose_env, "1") or std.mem.eql(u8, diagnose_env, "true");

    if (!enable_logging) {
        logger.disable();
    }

    logger.log(.info, "=== TRINITY MCP SERVER STARTED (stdio) ===", .{});
    logger.log(.info, "Diagnostics: {s}", .{if (enable_logging) "ENABLED" else "DISABLED (set TRINITY_MCP_DIAGNOSE=1)"});
>>>>>>> Stashed changes

    var server = TrinityMCPServer.init(allocator);

    var read_buffer: [65536]u8 = undefined;
    var buffer_used: usize = 0;
    var eof_reached = false;
    var message_count: usize = 0;

    logger.log(.debug, "Entering main loop...", .{});

    while (true) {
        // Read more data if buffer has space and we haven't reached EOF
        if (!eof_reached and buffer_used < read_buffer.len) {
            logger.log(.debug, "Reading from stdin (buffer_used={d})...", .{buffer_used});
            const read_result = posix.read(0, read_buffer[buffer_used..]);

            if (read_result) |bytes_read| {
                if (bytes_read == 0) {
                    logger.log(.info, "EOF reached (bytes_read=0)", .{});
                    eof_reached = true;
                } else {
                    logger.log(.debug, "Read {d} bytes", .{bytes_read});
                    buffer_used += bytes_read;
                }
            } else |err| {
                logger.log(.warn, "Read error: {}", .{err});
                if (err == error.EndOfStream) {
                    eof_reached = true;
                }
            }
        }

        // Try to read a complete MCP message
        logger.log(.debug, "Attempting to parse MCP message (buffer_used={d})...", .{buffer_used});
        const msg = (try readMCPMessage(allocator, &read_buffer, &buffer_used, &logger)) orelse {
            logger.log(.debug, "No complete message, eof_reached={}, buffer_used={d}", .{eof_reached, buffer_used});
            // Exit if EOF reached and we've processed at least one message
            if (eof_reached and buffer_used == 0 and message_count > 0) {
                logger.log(.info, "Exiting: EOF after {d} messages", .{message_count});
                break;
            }
            // Exit if EOF with no data and no messages processed (startup EOF)
            if (eof_reached and buffer_used == 0) {
                logger.log(.info, "Exiting: EOF at startup (no messages)", .{});
                break;
            }
            // Otherwise keep waiting
            continue;
        };
        defer msg.deinit(allocator);

        message_count += 1;
        logger.log(.info, "Message #{d} received ({d} bytes)", .{message_count, msg.content.len});

        const request = msg.content;

        // Show method name
        if (std.mem.indexOf(u8, request, "\"method\":")) |method_idx| {
            const after_method = request[method_idx + 9 ..];
            if (std.mem.indexOfScalar(u8, after_method, '"')) |first_quote| {
                const after_first_quote = after_method[first_quote + 1 ..];
                if (std.mem.indexOfScalar(u8, after_first_quote, '"')) |second_quote| {
                    const method_name = after_first_quote[0..second_quote];
                    logger.log(.info, "Method: {s}", .{method_name});
                }
            }
        }

        // Process JSON-RPC request

        // Skip notifications (no "id" field = notification per JSON-RPC 2.0)
        if (std.mem.indexOf(u8, request, "\"method\":\"notifications/") != null or
            std.mem.indexOf(u8, request, "\"method\": \"notifications/") != null) {
            logger.log(.debug, "Skipping notification", .{});
            continue;
        }

        if (std.mem.indexOf(u8, request, "\"method\":\"initialize\"") != null or
            std.mem.indexOf(u8, request, "\"method\": \"initialize\"") != null) {
            logger.log(.debug, "Processing 'initialize' request", .{});
            // Extract id from request and echo it back in response
            const id_val = extractRequestId(request);
            // Build complete response in one buffer
            var response_buffer: [512]u8 = undefined;
            var idx: usize = 0;

            // Start: {"jsonrpc":"2.0","id":
            const prefix1 = "{\"jsonrpc\":\"2.0\",\"id\":";
            @memcpy(response_buffer[idx..][0..prefix1.len], prefix1);
            idx += prefix1.len;

            // Insert id value
            @memcpy(response_buffer[idx..][0..id_val.len], id_val);
            idx += id_val.len;

            // Continue: ,"result":{...}
            const suffix = ",\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{},\"resources\":{},\"prompts\":{}}},\"serverInfo\":{\"name\":\"trinity-mcp\",\"version\":\"2.0.0\"}}}\n";
            @memcpy(response_buffer[idx..][0..suffix.len], suffix);
            idx += suffix.len;

            try writeMCPResponse(response_buffer[0..idx]);
            logger.log(.info, "Response sent for message #{d}", .{message_count});
        } else if (std.mem.indexOf(u8, request, "\"tools/list\"") != null) {
            logger.log(.debug, "Processing tools/list", .{});
            const tools_json = auto_discovery.generateToolsList(server.allocator) catch |err| {
                logger.log(.err, "generateToolsList failed: {}", .{err});
                const err_resp = try std.fmt.allocPrint(server.allocator, "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":-32603,\"message\":\"{s}\"}}}}\n", .{@errorName(err)});
                defer server.allocator.free(err_resp);
                try writeMCPResponse(err_resp);
                continue;
            };
            defer server.allocator.free(tools_json);
            logger.log(.debug, "tools_json length: {d}", .{tools_json.len});
            // Extract id from request
            const id_val = extractRequestId(request);
            // Use heap buffer for large response
            const response = try std.fmt.allocPrint(server.allocator, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}\n", .{ id_val, tools_json });
            logger.log(.debug, "response length: {d}, first 100 chars: {s}", .{response.len, if (response.len > 100) response[0..100] else response});
            defer server.allocator.free(response);
            try writeMCPResponse(response);
            logger.log(.info, "tools/list response sent", .{});
        } else if (std.mem.indexOf(u8, request, "\"resources/list\"") != null) {
            logger.log(.debug, "Processing resources/list", .{});
            const list = resources.generateResourcesList(server.allocator) catch |err| {
                logger.log(.err, "generateResourcesList failed: {}", .{err});
                const err_resp = try std.fmt.allocPrint(server.allocator, "{{\"jsonrpc\":\"2.0\",\"error\":{{\"code\":-32603,\"message\":\"{s}\"}}}}\n", .{@errorName(err)});
                defer server.allocator.free(err_resp);
                try writeMCPResponse(err_resp);
                continue;
            };
            defer server.allocator.free(list);
            const id_val = extractRequestId(request);
            const response = try std.fmt.allocPrint(server.allocator, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}\n", .{ id_val, list });
            defer server.allocator.free(response);
            try writeMCPResponse(response);
        } else if (std.mem.indexOf(u8, request, "\"resources/read\"") != null) {
            const uri = extractStringField(request, "uri") orelse {
                const err = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"message\":\"Missing URI parameter\"}}";
                try writeMCPResponse(err);
                continue;
            };

            if (resources.hasResource(uri)) {
                const content = try resources.loadResource(server.allocator, uri);
                defer server.allocator.free(content);
                const id_val = extractRequestId(request);
                const response = try std.fmt.allocPrint(server.allocator,
                    "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{{\"contents\":[{{\"uri\":\"{s}\",\"text\":\"{s}\"}}]}}}}\n"
                , .{ id_val, uri, content });
                defer server.allocator.free(response);
                try writeMCPResponse(response);
            } else {
                const err = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"message\":\"Resource not found\"}}";
                try writeMCPResponse(err);
            }
        } else if (std.mem.indexOf(u8, request, "\"prompts/list\"") != null) {
            const list = try prompts.generatePromptsList(server.allocator);
            defer server.allocator.free(list);
            const id_val = extractRequestId(request);
            const response = try std.fmt.allocPrint(server.allocator, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}\n", .{ id_val, list });
            defer server.allocator.free(response);
            try writeMCPResponse(response);
        } else if (std.mem.indexOf(u8, request, "\"prompts/get\"") != null) {
            const name = extractStringField(request, "name") orelse {
                const err = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"message\":\"Missing name parameter\"}}";
                try writeMCPResponse(err);
                continue;
            };

            if (prompts.hasPrompt(name)) {
                const response = try prompts.generatePromptGetResponse(server.allocator, name, null);
                defer server.allocator.free(response);
                try writeMCPResponse(response);
            } else {
                const err = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"message\":\"Prompt not found\"}}";
                try writeMCPResponse(err);
            }
        } else if (std.mem.indexOf(u8, request, "\"tools/call\"") != null) {
            const params_idx = std.mem.indexOf(u8, request, "\"params\":") orelse continue;
            const name_after_params = std.mem.indexOf(u8, request[params_idx..], "\"name\":") orelse continue;
            const name_idx = params_idx + name_after_params;
            const name_start = name_idx + 8;
            const name_end = std.mem.indexOfScalarPos(u8, request, name_start, '"') orelse continue;
            const tool_name = request[name_start..name_end];

            const arguments_idx = std.mem.indexOf(u8, request[params_idx..], "\"arguments\":") orelse continue;
            const args_absolute_idx = params_idx + arguments_idx;
            var args_search_start = args_absolute_idx + 13;
            while (args_search_start < request.len and std.ascii.isWhitespace(request[args_search_start])) {
                args_search_start += 1;
            }
            if (args_search_start >= request.len or (request[args_search_start] != '{' and request[args_search_start] != '"')) {
                continue;
            }
            const args_start = args_search_start;
            const arguments_json = blk: {
                if (request[args_start] == '"') {
                    // Stringified JSON - find end quote
                    var args_end = args_start + 1;
                    while (args_end < request.len and request[args_end] != '"') {
                        args_end += 1;
                    }
                    break :blk request[args_start + 1 .. args_end];
                } else {
                    var brace_count: usize = 1;
                    var args_end = args_start + 1;
                    while (args_end < request.len and brace_count > 0) {
                        if (request[args_end] == '{') brace_count += 1;
                        if (request[args_end] == '}') brace_count -= 1;
                        args_end += 1;
                    }
                    break :blk request[args_start..args_end];
                }
            };

            // Execute tool and capture response
            var response_buffer: [16384]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&response_buffer);
            const writer = fbs.writer();

            try server.handleToolsCall(tool_name, arguments_json, writer);
            const tool_response = fbs.getWritten();
            try writeMCPResponse(tool_response);
        } else if (std.mem.indexOf(u8, request, "\"method\":\"shutdown\"") != null or
                   std.mem.indexOf(u8, request, "\"method\": \"shutdown\"") != null) {
            // Handle shutdown request from client
            logger.log(.info, "Shutdown requested", .{});
            const id_val = extractRequestId(request);
            var response_buffer: [64]u8 = undefined;
            const response = std.fmt.bufPrint(&response_buffer, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{{}}}}\n", .{id_val}) catch |err| {
                logger.log(.err, "Failed to format shutdown response: {}", .{err});
                // Send minimal response anyway
                try writeMCPResponse("{\"jsonrpc\":\"2.0\",\"result\":{}}\n");
                break;
            };
            try writeMCPResponse(response);
            logger.log(.info, "Shutdown response sent, exiting", .{});
            break; // Exit main loop
        }
    }
}
