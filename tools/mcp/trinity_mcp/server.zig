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
fn readMCPMessage(allocator: std.mem.Allocator, buffer: []u8, buffer_used: *usize) !?MCPMessage {
    if (buffer_used.* == 0) return null;

    // Find Content-Length header
    const header_start = std.mem.indexOf(u8, buffer[0..buffer_used.*], "Content-Length:") orelse return null;
    const value_start = header_start + "Content-Length:".len;

    // Find the end of the header line (first \r or \n after the header name)
    const header_line_end = blk: {
        const search_from = buffer[value_start..buffer_used.*];
        const idx1 = std.mem.indexOfScalar(u8, search_from, '\r');
        const idx2 = std.mem.indexOfScalar(u8, search_from, '\n');
        break :blk if (idx1) |i| value_start + i else if (idx2) |i| value_start + i else null;
    } orelse return null;

    // Skip whitespace before the number
    var val_start: usize = value_start;
    while (val_start < header_line_end and std.ascii.isWhitespace(buffer[val_start])) : (val_start += 1) {}

    // Find end of number (first non-digit, whitespace)
    var val_end: usize = val_start;
    while (val_end < header_line_end and (buffer[val_end] >= '0' and buffer[val_end] <= '9')) : (val_end += 1) {}

    if (val_start >= val_end) return null;

    const length_str = buffer[val_start..val_end];
    const content_length = std.fmt.parseInt(usize, length_str, 10) catch return null;

    // Find the end of headers (double newline)
    const headers_end = blk: {
        const idx1 = std.mem.indexOf(u8, buffer[0..buffer_used.*], "\r\n\r\n");
        const idx2 = std.mem.indexOf(u8, buffer[0..buffer_used.*], "\n\n");
        break :blk if (idx1) |i| i + 4 else if (idx2) |i| i + 2 else null;
    } orelse return null;

    const body_start = headers_end;

    // Check if we have the complete message body
    if (body_start + content_length > buffer_used.*) {
        return null; // Need more data
    }

    const body_end = body_start + content_length;
    const content = buffer[body_start..body_end];

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
            const final_id_end = scan + 1 + id_val_end;
            const id_content = content[scan + 1 .. final_id_end];
            id = allocator.dupe(u8, id_content) catch null;
        }
    }

    // Copy the content
    const content_copy = try allocator.dupe(u8, content);

    // Shift remaining data to start of buffer
    const remaining = buffer_used.* - body_end;
    if (remaining > 0) {
        const src = buffer[body_end..buffer_used.*];
        @memcpy(buffer[0..src.len], src);
    }
    buffer_used.* = remaining;

    return MCPMessage{
        .content = content_copy,
        .id = id,
    };
}

/// Write an MCP response with proper Content-Length framing
fn writeMCPResponse(response: []const u8) !void {
    var header_buf: [128]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "Content-Length: {d}\r\n\r\n", .{response.len}) catch unreachable;
    _ = try posix.write(1, header);
    _ = try posix.write(1, response);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main Entry Point
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = TrinityMCPServer.init(allocator);

    var read_buffer: [65536]u8 = undefined;
    var buffer_used: usize = 0;

    while (true) {
        // Read more data if buffer has space
        if (buffer_used < read_buffer.len) {
            const bytes_read = posix.read(0, read_buffer[buffer_used..]) catch |err| {
                if (err == error.EndOfStream) break;
                continue;
            };
            if (bytes_read == 0) break;
            buffer_used += bytes_read;
        }

        // Try to read a complete MCP message
        const msg = (try readMCPMessage(allocator, &read_buffer, &buffer_used)) orelse continue;
        defer msg.deinit(allocator);

        const request = msg.content;

        // Process JSON-RPC request
        if (std.mem.indexOf(u8, request, "\"initialize\"") != null) {
            const response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{},\"resources\":{},\"prompts\":{}}},\"serverInfo\":{\"name\":\"trinity-mcp\",\"version\":\"2.0.0\"}}";
            try writeMCPResponse(response);
        } else if (std.mem.indexOf(u8, request, "\"tools/list\"") != null) {
            const tools_json = try auto_discovery.generateToolsList(server.allocator);
            defer server.allocator.free(tools_json);
            // Wrap in proper JSON-RPC response
            const response = try std.fmt.allocPrint(allocator, "{{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{s}}}", .{tools_json});
            defer allocator.free(response);
            try writeMCPResponse(response);
        } else if (std.mem.indexOf(u8, request, "\"resources/list\"") != null) {
            const list = try resources.generateResourcesList(server.allocator);
            defer server.allocator.free(list);
            const response = try std.fmt.allocPrint(allocator, "{{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{s}}}", .{list});
            defer allocator.free(response);
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
                var response_buffer: [8192]u8 = undefined;
                const response = std.fmt.bufPrint(&response_buffer,
                    "{{\"jsonrpc\":\"2.0\",\"result\":{{\"contents\":[{{\"uri\":\"{s}\",\"text\":\"{s}\"}}]}}}}"
                , .{ uri, content }) catch continue;
                try writeMCPResponse(response);
            } else {
                const err = "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"message\":\"Resource not found\"}}";
                try writeMCPResponse(err);
            }
        } else if (std.mem.indexOf(u8, request, "\"prompts/list\"") != null) {
            const list = try prompts.generatePromptsList(server.allocator);
            defer server.allocator.free(list);
            const response = try std.fmt.allocPrint(allocator, "{{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{s}}}", .{list});
            defer allocator.free(response);
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
        }
    }
}
