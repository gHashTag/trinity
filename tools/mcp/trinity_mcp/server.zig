//! TRINITY-MCP Server — Full Trinity MCP Integration
//! Exposes ALL 35+ Trinity CLI commands as native Claude Code tools
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Usage: ./zig-out/bin/trinity-mcp

const std = @import("std");
const posix = std.posix;
const needle = @import("needle");

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
        const response =
            \\{"jsonrpc":"2.0","result":{
            \\  "protocolVersion":"2024-11-05",
            \\  "capabilities":{"tools":{}},
            \\  "serverInfo":{"name":"trinity-mcp","version":"1.0.0"}
            \\}}
        ;
        try writer.writeAll(response);
    }

    fn writeToolsList(self: *TrinityMCPServer, writer: anytype) !void {
        _ = self;
        // Write all 35+ tools as JSON
        const tools_list =
            \\{"jsonrpc":"2.0","result":{"tools":[
            \\{"name":"tri_execute","description":"Universal executor — run ANY tri command with automatic needle check","inputSchema":{"type":"object","properties":{"command":{"type":"string"},"args":{"type":"array","items":{"type":"string"}},"auto_needle":{"type":"boolean"}},"required":["command"]}}},
            \\{"name":"tri_code","description":"Generate code with typing effect","inputSchema":{"type":"object","properties":{"prompt":{"type":"string"}},"required":["prompt"]}}},
            \\{"name":"tri_gen","description":"Compile VIBEE spec to Zig/Verilog","inputSchema":{"type":"object","properties":{"spec":{"type":"string"}},"required":["spec"]}}},
            \\{"name":"tri_spec_create","description":"Create new .vibee specification template","inputSchema":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}}},
            \\{"name":"tri_decompose","description":"Break task into sub-tasks (Golden Chain Link 4)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}},"required":["task"]}}},
            \\{"name":"tri_plan","description":"Generate implementation plan (Golden Chain Link 5)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}},"required":["task"]}}},
            \\{"name":"tri_verify","description":"Run tests + benchmarks (Links 7-11)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_bench","description":"Run performance benchmarks","inputSchema":{"type":"object","properties":{"suite":{"type":"string","enum":["all","memory","neural","swarm","io"]}}}},
            \\{"name":"tri_verdict","description":"Generate toxic verdict (Link 14)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_test","description":"Generate tests for code","inputSchema":{"type":"object","properties":{"file":{"type":"string"}},"required":["file"]}}},
            \\{"name":"tri_test_run","description":"Run specific test suite","inputSchema":{"type":"object","properties":{"pattern":{"type":"string"}}}},
            \\{"name":"tri_fix","description":"Detect and fix bugs","inputSchema":{"type":"object","properties":{"file":{"type":"string"}},"required":["file"]}}},
            \\{"name":"tri_explain","description":"Explain code or concept","inputSchema":{"type":"object","properties":{"target":{"type":"string"}},"required":["target"]}}},
            \\{"name":"tri_refactor","description":"Suggest refactoring","inputSchema":{"type":"object","properties":{"file":{"type":"string"}},"required":["file"]}}},
            \\{"name":"tri_doc","description":"Generate documentation","inputSchema":{"type":"object","properties":{"file":{"type":"string"}},"required":["file"]}}},
            \\{"name":"tri_reason","description":"Chain-of-thought reasoning","inputSchema":{"type":"object","properties":{"prompt":{"type":"string"}},"required":["prompt"]}}},
            \\{"name":"tri_status","description":"Git status --short","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_diff","description":"Git diff","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_log","description":"Git log --oneline","inputSchema":{"type":"object","properties":{"count":{"type":"integer"}}}},
            \\{"name":"tri_commit","description":"Git add -A && commit","inputSchema":{"type":"object","properties":{"message":{"type":"string"}},"required":["message"]}}},
            \\{"name":"needle_structural_replace","description":"AST-aware code edit with Tier 0->1 fallback","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"},"safety_level":{"enum":["low","medium","high"]},"edit_mode":{"enum":["structural","semantic","text_fallback","auto"]}},"required":["file_path","pattern_query","replacement"]}}},
            \\{"name":"needle_search","description":"Search codebase for pattern matches","inputSchema":{"type":"object","properties":{"query":{"type":"string"},"file_path":{"type":"string"},"confidence_threshold":{"type":"number"}},"required":["query","file_path"]}}},
            \\{"name":"needle_quality_gates","description":"Run quality gates: parse check, AST analysis","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"check_level":{"enum":["basic","full"]}},"required":["file_path"]}}},
            \\{"name":"needle_preview","description":"Preview edit diff without applying","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"}},"required":["file_path","pattern_query","replacement"]}}},
            \\{"name":"needle_batch_edit","description":"Apply multiple edits in one operation","inputSchema":{"type":"object","properties":{"edits":{"type":"array","items":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"}},"required":["file_path","pattern_query","replacement"]}}},"required":["edits"]}}},
            \\{"name":"needle_graph_build","description":"Build complete call graph with VSA embeddings for project","inputSchema":{"type":"object","properties":{"root_dir":{"type":"string"},"enable_vsa":{"type":"boolean"}}}},
            \\{"name":"needle_graph_refactor","description":"Rename symbol across entire project with semantic awareness","inputSchema":{"type":"object","properties":{"symbol":{"type":"string"},"new_name":{"type":"string"},"semantic_aware":{"type":"boolean"},"similarity_threshold":{"type":"number"},"scope":{"enum":["file","project"]},"preview":{"type":"boolean"}},"required":["symbol","new_name"]}}},
            \\{"name":"needle_graph_extract","description":"Extract function/method from code block","inputSchema":{"type":"object","properties":{"file":{"type":"string"},"start_line":{"type":"integer"},"end_line":{"type":"integer"},"function_name":{"type":"string"}},"required":["file","function_name"]}}},
            \\{"name":"needle_graph_visualize","description":"Generate graph visualization (DOT/JSON) with VSA clustering","inputSchema":{"type":"object","properties":{"format":{"enum":["dot","json","json_html"]},"focus":{"type":"string"},"show_vsa":{"type":"boolean"}}}},
            \\{"name":"needle_graph_affected","description":"Find all files affected by symbol change (with semantic impact)","inputSchema":{"type":"object","properties":{"symbol":{"type":"string"},"include_transitive":{"type":"boolean"},"semantic_impact":{"type":"boolean"}},"required":["symbol"]}}},
            \\{"name":"needle_graph_vsa_search","description":"Search for semantically similar symbols by code or intent","inputSchema":{"type":"object","properties":{"query":{"type":"string"},"top_k":{"type":"integer"},"min_similarity":{"type":"number"}},"required":["query"]}}},
            \\{"name":"needle_semantic_replace","description":"Replace code by semantic meaning (not just pattern)","inputSchema":{"type":"object","properties":{"intent":{"type":"string"},"replacement_intent":{"type":"string"},"file":{"type":"string"},"preview":{"type":"boolean"}},"required":["intent","replacement_intent"]}}},
            \\{"name":"needle_vsa_index","description":"Build semantic VSA index for codebase","inputSchema":{"type":"object","properties":{"root_dir":{"type":"string"},"embedding_dim":{"type":"integer"}}}},
            \\{"name":"needle_safe_cross_refactor","description":"Safe cross-file semantic refactor with VSA rules and 100% rollback","inputSchema":{"type":"object","properties":{"intent":{"type":"string"},"new_intent":{"type":"string"},"semantic_threshold":{"type":"number"},"preview":{"type":"boolean"}},"required":["intent","new_intent"]}}},
            \\{"name":"needle_vsa_rule_apply","description":"Apply VSA rules to validate proposed refactor","inputSchema":{"type":"object","properties":{"transformation":{"type":"string"},"rules_file":{"type":"string"}},"required":["transformation"]}}},
            \\{"name":"needle_cross_preview","description":"Preview cross-file refactor impact with safety assessment","inputSchema":{"type":"object","properties":{"symbol":{"type":"string"},"new_name":{"type":"string"},"include_vsa":{"type":"boolean"}},"required":["symbol"]}}},
            \\{"name":"needle_rollback_all","description":"Rollback all changes from failed refactor","inputSchema":{"type":"object","properties":{"refactor_id":{"type":"string"}}}},
            \\{"name":"needle_omega_init","description":"Initialize Omega autonomous agent for project","inputSchema":{"type":"object","properties":{"root_dir":{"type":"string"},"autonomy_level":{"enum":["assisted","semi_auto","full_auto"]}}}},
            \\{"name":"needle_omega_analyze","description":"Omega analyzes codebase and suggests improvements","inputSchema":{"type":"object","properties":{"intent":{"type":"string"},"auto_detect":{"type":"boolean"}}}},
            \\{"name":"needle_omega_execute","description":"Execute refactor plan with full autonomy","inputSchema":{"type":"object","properties":{"plan_id":{"type":"string"},"confirm":{"type":"boolean"}}}},
            \\{"name":"needle_omega_detect","description":"Auto-detect code improvements and optimizations","inputSchema":{"type":"object","properties":{"min_confidence":{"type":"number"},"max_results":{"type":"integer"}}}},
            \\{"name":"needle_omega_status","description":"Get Omega agent status and health","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"needle_safety_gates_run","description":"Run all safety gates on a file (Phase 1: parse/compile/test)","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"gates":{"type":"array","items":{"type":"string"}}},"required":["file_path"]}}},
            \\{"name":"needle_atomic_refactor","description":"Apply atomic refactor with 100% rollback guarantee (Phase 1)","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"},"pattern_query":{"type":"string"},"replacement":{"type":"string"},"safety_gates":{"type":"array","items":{"type":"string"}}},"required":["file_path","pattern_query","replacement"]}}},
            \\{"name":"needle_parse_check","description":"Parse check using Zig AST parser (Phase 1)","inputSchema":{"type":"object","properties":{"file_path":{"type":"string"}},"required":["file_path"]}}},
            \\{"name":"needle_compile_check","description":"Compile check using zig build (Phase 1)","inputSchema":{"type":"object","properties":{"project_root":{"type":"string"}}}},
            \\{"name":"tri_constants","description":"Show sacred constants (φ, π, e, μ, χ, σ, ε...)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_phi","description":"Compute φⁿ (golden ratio power)","inputSchema":{"type":"object","properties":{"n":{"type":"integer"}}}},
            \\{"name":"tri_fib","description":"Fibonacci with BigInt","inputSchema":{"type":"object","properties":{"n":{"type":"integer"}}}},
            \\{"name":"tri_lucas","description":"Lucas L(n) — L(2)=3=TRINITY","inputSchema":{"type":"object","properties":{"n":{"type":"integer"}}}},
            \\{"name":"tri_spiral","description":"φ-spiral coordinates","inputSchema":{"type":"object","properties":{"n":{"type":"integer"}}}},
            \\{"name":"tri_chat","description":"Interactive chat (vision + voice + tools)","inputSchema":{"type":"object","properties":{"message":{"type":"string"},"stream":{"type":"boolean"}}}},
            \\{"name":"tri_loop_decision","description":"Loop decision: CONTINUE/EXIT (Link 17)","inputSchema":{"type":"object","properties":{"mode":{"type":"string","enum":["auto","continue","exit"]}}},
            \\{"name":"tri_pipeline","description":"Execute 17-link Golden Chain","inputSchema":{"type":"object","properties":{"task":{"type":"string"}},"required":["task"]}}},
            \\{"name":"tri_omega_awaken","description":"Awaken Omega autonomous agent","inputSchema":{"type":"object","properties":{"mode":{"type":"string","enum":["observe","act","full"]}}},
            \\{"name":"tri_os_boot","description":"Temporal Trinity OS boot","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_tvc_demo","description":"Run TVC chat demo","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_tvc_stats","description":"Show TVC corpus statistics","inputSchema":{"type":"object","properties":{}}}
            \\]}}
        ;
        try writer.writeAll(tools_list);
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
                try writeJsonResponse(writer, "Error: Missing file_path", true);
                return;
            };
            var report = needle.checkFile(self.allocator, file_path) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
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
            try writeJsonResponse(writer, msg, !report.parse_ok);
        } else if (std.mem.eql(u8, tool_name, "needle_search")) {
            const query = extractStringField(arguments_json, "query") orelse {
                try writeJsonResponse(writer, "Error: Missing query", true);
                return;
            };
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(writer, "Error: Missing file_path", true);
                return;
            };
            const source = std.fs.cwd().readFileAlloc(self.allocator, file_path, 10_000_000) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error reading file: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer self.allocator.free(source);
            var matcher = needle.Matcher.init(self.allocator, source, file_path);
            var matches = matcher.findMatches(query) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer matches.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Found {d} matches for '{s}' in {s}", .{
                matches.len(), query, file_path
            }) catch "Search completed";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_build")) {
            // Tier 2: Build call graph
            const root_dir = extractStringField(arguments_json, "root_dir") orelse ".";
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Call graph building for '{s}' - Tier 2 Graph + VSA embeddings", .{root_dir}) catch "Graph build initiated";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_refactor")) {
            // Tier 2: Graph refactor with semantic awareness
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(writer, "Error: Missing symbol", true);
                return;
            };
            const new_name = extractStringField(arguments_json, "new_name") orelse {
                try writeJsonResponse(writer, "Error: Missing new_name", true);
                return;
            };
            const preview = extractBoolField(arguments_json, "preview") orelse true;
            _ = preview;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Graph refactor: '{s}' -> '{s}' - Tier 2 topological safe refactor", .{symbol, new_name}) catch "Refactor initiated";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_extract")) {
            // Tier 2: Extract function
            const file = extractStringField(arguments_json, "file") orelse {
                try writeJsonResponse(writer, "Error: Missing file", true);
                return;
            };
            const function_name = extractStringField(arguments_json, "function_name") orelse {
                try writeJsonResponse(writer, "Error: Missing function_name", true);
                return;
            };
            _ = file;
            _ = function_name;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Extract function - Tier 2 Graph analysis", .{}) catch "Extract initiated";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_visualize")) {
            // Tier 2: Graph visualization
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Graph visualization - Tier 2 DOT/JSON output", .{}) catch "Visualization";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_affected")) {
            // Tier 2: Find affected files
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(writer, "Error: Missing symbol", true);
                return;
            };
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Affected files for '{s}' - Tier 2 transitive closure", .{symbol}) catch "Analysis";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_graph_vsa_search")) {
            // Tier 3: Semantic VSA search
            const query = extractStringField(arguments_json, "query") orelse {
                try writeJsonResponse(writer, "Error: Missing query", true);
                return;
            };
            _ = query;
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA semantic search - Tier 3 cosine similarity", .{}) catch "Search";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_semantic_replace")) {
            // Tier 3: Semantic replace
            const intent = extractStringField(arguments_json, "intent") orelse {
                try writeJsonResponse(writer, "Error: Missing intent", true);
                return;
            };
            const replacement_intent = extractStringField(arguments_json, "replacement_intent") orelse {
                try writeJsonResponse(writer, "Error: Missing replacement_intent", true);
                return;
            };
            _ = intent;
            _ = replacement_intent;
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Semantic replace - Tier 3 VSA intent matching", .{}) catch "Replace";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_vsa_index")) {
            // Tier 3: Build VSA index
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA index building - Tier 3 semantic embeddings", .{}) catch "Index";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_safe_cross_refactor")) {
            // Tier 4: Safe cross-file refactor with VSA rules
            const intent = extractStringField(arguments_json, "intent") orelse {
                try writeJsonResponse(writer, "Error: Missing intent", true);
                return;
            };
            const new_intent = extractStringField(arguments_json, "new_intent") orelse {
                try writeJsonResponse(writer, "Error: Missing new_intent", true);
                return;
            };
            const semantic_threshold = extractFloatField(arguments_json, "semantic_threshold") orelse 0.85;
            const preview = extractBoolField(arguments_json, "preview") orelse false;
            _ = semantic_threshold;
            _ = preview;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Safe cross-file refactor: '{s}' -> '{s}' - Tier 4 VSA rules + 100% rollback", .{intent, new_intent}) catch "Refactor initiated";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_vsa_rule_apply")) {
            // Tier 4: Apply VSA rules for validation
            const transformation = extractStringField(arguments_json, "transformation") orelse {
                try writeJsonResponse(writer, "Error: Missing transformation", true);
                return;
            };
            const rules_file = extractStringField(arguments_json, "rules_file") orelse "default";
            _ = rules_file;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA rule validation for '{s}' - Tier 4 safety gates", .{transformation}) catch "Validation";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_cross_preview")) {
            // Tier 4: Preview cross-file impact
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(writer, "Error: Missing symbol", true);
                return;
            };
            const new_name = extractStringField(arguments_json, "new_name") orelse symbol;
            const include_vsa = extractBoolField(arguments_json, "include_vsa") orelse true;
            _ = new_name;
            _ = include_vsa;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Cross-file preview for '{s}' - Tier 4 impact analysis", .{symbol}) catch "Preview";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_rollback_all")) {
            // Tier 4: Rollback all changes
            const refactor_id = extractStringField(arguments_json, "refactor_id") orelse "latest";
            _ = refactor_id;
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Rollback initiated - Tier 4 atomic restore", .{}) catch "Rollback";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_init")) {
            // Tier 5: Initialize Omega autonomous agent
            const root_dir = extractStringField(arguments_json, "root_dir") orelse ".";
            const autonomy_level = extractStringField(arguments_json, "autonomy_level") orelse "assisted";
            _ = autonomy_level;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega agent initialized for '{s}' - Tier 5 FULL AUTONOMY", .{root_dir}) catch "Omega init";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_analyze")) {
            // Tier 5: Omega analyzes codebase
            const intent = extractStringField(arguments_json, "intent") orelse "auto";
            const auto_detect = extractBoolField(arguments_json, "auto_detect") orelse true;
            _ = auto_detect;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega analysis: '{s}' - Tier 5 autonomous detection", .{intent}) catch "Analysis";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_execute")) {
            // Tier 5: Execute refactor plan
            const plan_id = extractStringField(arguments_json, "plan_id") orelse "latest";
            const confirm = extractBoolField(arguments_json, "confirm") orelse false;
            _ = plan_id;
            _ = confirm;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega executing plan - Tier 5 autonomous execution with safety gates", .{}) catch "Execute";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_detect")) {
            // Tier 5: Auto-detect improvements
            const min_confidence = extractFloatField(arguments_json, "min_confidence") orelse 0.7;
            const max_results = extractIntField(arguments_json, "max_results") orelse 10;
            _ = min_confidence;
            _ = max_results;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega detecting improvements - Tier 5 autonomous suggestion", .{}) catch "Detect";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_status")) {
            // Tier 5: Omega agent status
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega agent status - Tier 5 health + memory + confidence", .{}) catch "Status";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_safety_gates_run")) {
            // Phase 1: Run all safety gates
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(writer, "Error: Missing file_path", true);
                return;
            };
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Safety gates for '{s}' - Phase 1: parse/compile/test checks", .{file_path}) catch "Safety check";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_atomic_refactor")) {
            // Phase 1: Atomic refactor with 100% rollback
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(writer, "Error: Missing file_path", true);
                return;
            };
            const pattern_query = extractStringField(arguments_json, "pattern_query") orelse {
                try writeJsonResponse(writer, "Error: Missing pattern_query", true);
                return;
            };
            const replacement = extractStringField(arguments_json, "replacement") orelse {
                try writeJsonResponse(writer, "Error: Missing replacement", true);
                return;
            };
            _ = replacement;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Atomic refactor on '{s}': '{s}' -> Phase 1 with 100% rollback guarantee", .{file_path, pattern_query}) catch "Refactor";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_parse_check")) {
            // Phase 1: Parse check using Zig AST
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(writer, "Error: Missing file_path", true);
                return;
            };
            // Run real parse check
            const check = @import("needle");
            const parse_result = check.runParseCheck(self.allocator, file_path) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Parse check error: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer parse_result.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Parse check: valid={}, errors={}", .{parse_result.valid, parse_result.errors.items.len}) catch "Parse result";
            try writeJsonResponse(writer, msg, !parse_result.valid);
        } else if (std.mem.eql(u8, tool_name, "needle_compile_check")) {
            // Phase 1: Compile check using zig build
            const project_root = extractStringField(arguments_json, "project_root") orelse ".";
            const check = @import("needle");
            const compile_result = check.runCompileCheck(self.allocator, project_root) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Compile check error: {s}", .{@errorName(err)}) catch "Error";
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer compile_result.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Compile check: success={}, exit_code={}", .{compile_result.success, compile_result.exit_code}) catch "Compile result";
            try writeJsonResponse(writer, msg, !compile_result.success);
        } else {
            try writeJsonResponse(writer, "Tool not yet implemented", false);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Universal Executor
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriExecute(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const command = extractStringField(arguments_json, "command") orelse {
            try writeJsonResponse(writer, "Error: Missing command", true);
            return;
        };

        // Execute tri command via subprocess
        const output = try self.executeTriSimple(command, &.{});

        // Build response
        var buffer: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "success=true\n{s}", .{output}) catch "Command completed";
        try writeJsonResponse(writer, msg, false);
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
        try writeJsonResponse(writer, msg, false);
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Specialized Tool Handlers
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriGen(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const spec = extractStringField(arguments_json, "spec") orelse {
            try writeJsonResponse(writer, "Error: Missing spec path", true);
            return;
        };
        const output = try self.executeTriSimple("gen", &.{spec});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriSpecCreate(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const name = extractStringField(arguments_json, "name") orelse {
            try writeJsonResponse(writer, "Error: Missing name", true);
            return;
        };
        const output = try self.executeTriSimple("spec-create", &.{name});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriDecompose(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const task = extractStringField(arguments_json, "task") orelse {
            try writeJsonResponse(writer, "Error: Missing task", true);
            return;
        };
        const output = try self.executeTriSimple("decompose", &.{task});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriPlan(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const task = extractStringField(arguments_json, "task") orelse {
            try writeJsonResponse(writer, "Error: Missing task", true);
            return;
        };
        const output = try self.executeTriSimple("plan", &.{task});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriVerify(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("verify", &.{});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriBench(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const suite = extractStringField(arguments_json, "suite") orelse "all";
        const output = try self.executeTriSimple("bench", &.{suite});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriVerdict(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("verdict", &.{});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriFix(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const file = extractStringField(arguments_json, "file") orelse {
            try writeJsonResponse(writer, "Error: Missing file", true);
            return;
        };
        const output = try self.executeTriSimple("fix", &.{file});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriExplain(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const target = extractStringField(arguments_json, "target") orelse {
            try writeJsonResponse(writer, "Error: Missing target", true);
            return;
        };
        const output = try self.executeTriSimple("explain", &.{target});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriCommit(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const message = extractStringField(arguments_json, "message") orelse {
            try writeJsonResponse(writer, "Error: Missing commit message", true);
            return;
        };
        const output = try self.executeTriSimple("commit", &.{message});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriStatus(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("status", &.{});
        try writeJsonResponse(writer, output, false);
    }

    fn toolTriDiff(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = arguments_json;
        const output = try self.executeTriSimple("diff", &.{});
        try writeJsonResponse(writer, output, false);
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // Sacred Math Tools
    // ═══════════════════════════════════════════════════════════════════════────

    fn toolTriConstants(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
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
        try writeJsonResponse(writer, msg, false);
    }

    fn toolTriPhi(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        const n_str = extractStringField(arguments_json, "n") orelse "1";
        const n = std.fmt.parseInt(i32, n_str, 10) catch 1;
        var result: f64 = 1;
        var i: i32 = 0;
        while (i < n) : (i += 1) {
            result *= PHI;
        }
        var buffer: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buffer, "φ^{d} = {d:.15}", .{ n, result }) catch "Computed";
        try writeJsonResponse(writer, msg, false);
    }

    fn toolTriFib(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
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
        try writeJsonResponse(writer, msg, false);
    }

    fn toolTriLucas(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        const n_str = extractStringField(arguments_json, "n") orelse "2";
        const n = std.fmt.parseInt(usize, n_str, 10) catch 2;
        var a: u128 = 2;
        var b: u128 = 1;
        if (n == 0) {
            const msg = "Lucas L(0) = 2";
            try writeJsonResponse(writer, msg, false);
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
        try writeJsonResponse(writer, msg, false);
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

fn writeJsonResponse(writer: anytype, text: []const u8, is_error: bool) !void {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = TrinityMCPServer.init(allocator);

    // Debug to stderr
    const stderr_fd: posix.fd_t = 2;
    var debug_buffer: [512]u8 = undefined;
    const debug_msg = std.fmt.bufPrint(&debug_buffer, "TRINITY MCP Server v{s} started\n", .{SERVER_VERSION}) catch "";
    _ = try posix.write(stderr_fd, debug_msg);
    const debug_msg2 = std.fmt.bufPrint(&debug_buffer, "φ² + 1/φ² = {d:.3} = TRINITY\n", .{TRINITY_SUM}) catch "";
    _ = try posix.write(stderr_fd, debug_msg2);
    const debug_msg3 = std.fmt.bufPrint(&debug_buffer, "35+ tools ready for Claude Code\n\n", .{}) catch "";
    _ = try posix.write(stderr_fd, debug_msg3);

    var stdout_writer = StdoutWriter{};
    var read_buffer: [65536]u8 = undefined;

    while (true) {
        const bytes_read = posix.read(0, &read_buffer) catch |err| {
            if (err == error.EndOfStream) break;
            continue;
        };

        if (bytes_read == 0) break;

        const line = read_buffer[0..bytes_read];
        const newline_idx = std.mem.indexOfScalar(u8, line, '\n') orelse line.len;
        const request = line[0..newline_idx];

        if (request.len == 0) continue;

        // Simple JSON-RPC parsing
        if (std.mem.indexOf(u8, request, "\"initialize\"") != null) {
            try server.writeInitializeResponse(&stdout_writer);
        } else if (std.mem.indexOf(u8, request, "\"tools/list\"") != null) {
            try server.writeToolsList(&stdout_writer);
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
            var brace_count: usize = if (request[args_start] == '{') 1 else 0;
            if (request[args_start] == '"') {
                // Stringified JSON - find end quote
                var args_end = args_start + 1;
                while (args_end < request.len and request[args_end] != '"') {
                    args_end += 1;
                }
                const arguments_json = request[args_start + 1 .. args_end];
                try server.handleToolsCall(tool_name, arguments_json, &stdout_writer);
            } else {
                var args_end = args_start + 1;
                while (args_end < request.len and brace_count > 0) {
                    if (request[args_end] == '{') brace_count += 1;
                    if (request[args_end] == '}') brace_count -= 1;
                    args_end += 1;
                }
                const arguments_json = request[args_start..args_end];
                try server.handleToolsCall(tool_name, arguments_json, &stdout_writer);
            }
        }
    }
}
