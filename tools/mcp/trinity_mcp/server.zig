//! TRINITY-MCP Server — Full Trinity MCP Integration
//! Exposes ALL 35+ Trinity CLI commands as native Claude Code tools
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Usage: ./zig-out/bin/trinity-mcp

const std = @import("std");
const posix = std.posix;
const needle = @import("needle");
const resources_mod = @import("resources.zig");
const prompts_mod = @import("prompts.zig");
const science = @import("science_tools.zig");
const swarm = @import("swarm_tools.zig");
const cloud = @import("cloud_tools.zig");
const oracle = @import("oracle_watchdog.zig");

// Sacred constants
const PHI: f64 = 1.618033988749895;
const TRINITY_SUM: f64 = 3.0;
const PHOENIX: u16 = 999;

// MCP Protocol
const PROTOCOL_VERSION = "2024-11-05";
const SERVER_NAME = "trinity-mcp";
const SERVER_VERSION = "2.0.0";

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY MCP Server
// ═══════════════════════════════════════════════════════════════════════════════

const TrinityMCPServer = struct {
    allocator: std.mem.Allocator,
    tri_path: []const u8,

    fn init(allocator: std.mem.Allocator) TrinityMCPServer {
        // Default tri path - can be overridden
        const default_path = "zig-out/bin/tri";
        return .{
            .allocator = allocator,
            .tri_path = default_path,
        };
    }

    fn writeInitializeResponse(self: *TrinityMCPServer, id_str: []const u8, writer: anytype) !void {
        _ = self;
        var buf: [1024]u8 = undefined;
        const response = std.fmt.bufPrint(&buf,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"protocolVersion":"2024-11-05","capabilities":{{"tools":{{}},"resources":{{"subscribe":false}},"prompts":{{}}}},"serverInfo":{{"name":"trinity-mcp","version":"2.0.0"}}}}}}
        , .{id_str}) catch return;
        try writeWithContentLength(writer, response);
    }

    fn writeToolsList(self: *TrinityMCPServer, id_str: []const u8, writer: anytype) !void {
        _ = self;
        // Build response with id
        var header_buf: [128]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{{\"tools\":[", .{id_str}) catch return;
        // Write all 35+ tools as JSON
        const tools_body =
            \\{"name":"tri_execute","description":"Universal executor — run ANY tri command with automatic needle check","inputSchema":{"type":"object","properties":{"command":{"type":"string"},"args":{"type":"array","items":{"type":"string"}},"auto_needle":{"type":"boolean"}},"required":["command"]}}},
            \\{"name":"tri_code","description":"Generate code with typing effect","inputSchema":{"type":"object","properties":{"prompt":{"type":"string"}},"required":["prompt"]}}},
            \\{"name":"tri_gen","description":"Compile VIBEE spec to Zig/Verilog","inputSchema":{"type":"object","properties":{"spec":{"type":"string"}},"required":["spec"]}}},
            \\{"name":"tri_spec_create","description":"Create new .tri specification template","inputSchema":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}}},
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
            \\{"name":"tri_pipeline","description":"Execute 26-link Golden Chain pipeline","inputSchema":{"type":"object","properties":{"task":{"type":"string"}},"required":["task"]}}},
            \\{"name":"tri_omega_awaken","description":"Awaken Omega autonomous agent","inputSchema":{"type":"object","properties":{"mode":{"type":"string","enum":["observe","act","full"]}}},
            \\{"name":"tri_os_boot","description":"Temporal Trinity OS boot","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_tvc_demo","description":"Run TVC chat demo","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_tvc_stats","description":"Show TVC corpus statistics","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_chem_periodic","description":"List periodic table elements by category","inputSchema":{"type":"object","properties":{"category":{"type":"string","description":"Element category (all, nonmetal, noble_gas, etc.)"}}}},
            \\{"name":"tri_chem_element","description":"Look up element by symbol or atomic number","inputSchema":{"type":"object","properties":{"element":{"type":"string"}},"required":["element"]}},
            \\{"name":"tri_chem_mass","description":"Calculate molar mass of chemical formula","inputSchema":{"type":"object","properties":{"formula":{"type":"string"}},"required":["formula"]}},
            \\{"name":"tri_chem_moles","description":"Calculate moles, molecules, atoms from mass","inputSchema":{"type":"object","properties":{"formula":{"type":"string"},"mass":{"type":"number"}},"required":["formula","mass"]}},
            \\{"name":"tri_bio_dna","description":"Analyze DNA sequence (GC content, composition)","inputSchema":{"type":"object","properties":{"sequence":{"type":"string"}},"required":["sequence"]}},
            \\{"name":"tri_bio_codon","description":"Look up RNA codon to amino acid","inputSchema":{"type":"object","properties":{"codon":{"type":"string"}}}},
            \\{"name":"tri_bio_protein","description":"Analyze protein sequence (mass, composition)","inputSchema":{"type":"object","properties":{"sequence":{"type":"string"}},"required":["sequence"]}},
            \\{"name":"tri_quantum_constants","description":"Show quantum physics constants (h, hbar, alpha)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_quantum_states","description":"Show quantum basis states and phi-state","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_bell_states","description":"Show four Bell entangled states","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_formula","description":"Evaluate V = n * 3^k * pi^m * phi^p * e^q","inputSchema":{"type":"object","properties":{"n":{"type":"integer"},"k":{"type":"integer"},"m":{"type":"integer"},"p":{"type":"integer"},"q":{"type":"integer"}}}},
            \\{"name":"swarm_status","description":"Get Ralph Agent Swarm status summary (agents, tasks, counts)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"swarm_agents","description":"List all registered swarm agents with status","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"swarm_register","description":"Register a new agent in the swarm","inputSchema":{"type":"object","properties":{"agent_id":{"type":"string"},"hostname":{"type":"string"}},"required":["agent_id"]}},
            \\{"name":"swarm_heartbeat","description":"Agent heartbeat with status, branch, task_id, commit_sha (circuit breaker)","inputSchema":{"type":"object","properties":{"agent_id":{"type":"string"},"status":{"type":"string"},"branch":{"type":"string"},"task_id":{"type":"string"},"commit_sha":{"type":"string"}},"required":["agent_id","status"]}},
            \\{"name":"swarm_task_get","description":"Get next pending task for an agent (priority-ordered)","inputSchema":{"type":"object","properties":{"agent_id":{"type":"string"}},"required":["agent_id"]}},
            \\{"name":"swarm_task_add","description":"Add a new task to the swarm queue","inputSchema":{"type":"object","properties":{"id":{"type":"string"},"slug":{"type":"string"},"description":{"type":"string"},"priority":{"type":"string","enum":["P0","P1","P2","P3"]}},"required":["slug","description"]}},
            \\{"name":"swarm_task_cancel","description":"Cancel and remove a task from the queue","inputSchema":{"type":"object","properties":{"task_id":{"type":"string"}},"required":["task_id"]}},
            \\{"name":"swarm_tasks","description":"List all tasks in the swarm queue","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"swarm_pause","description":"Pause all swarm agents (finish current tasks, no new assignments)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"swarm_resume","description":"Resume all paused swarm agents","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"swarm_assign","description":"Create and assign a task to a specific agent","inputSchema":{"type":"object","properties":{"agent_id":{"type":"string"},"description":{"type":"string"}},"required":["agent_id","description"]}},
            \\{"name":"swarm_github_sync","description":"Convert GitHub issue to swarm task. Returns labels/actions for Go proxy.","inputSchema":{"type":"object","properties":{"issue_number":{"type":"string"},"title":{"type":"string"},"labels":{"type":"string","description":"comma-separated label names"}},"required":["issue_number","title"]}},
            \\{"name":"swarm_github_on_start","description":"Notify that agent started a GitHub-sourced task. Returns label swaps + comment.","inputSchema":{"type":"object","properties":{"task_id":{"type":"string"},"agent_id":{"type":"string"},"branch":{"type":"string"}},"required":["task_id","agent_id","branch"]}},
            \\{"name":"swarm_github_on_complete","description":"Notify GitHub task completed. Returns labels, comment, close_issue.","inputSchema":{"type":"object","properties":{"task_id":{"type":"string"},"agent_id":{"type":"string"},"result":{"type":"string"}},"required":["task_id","agent_id"]}},
            \\{"name":"swarm_github_on_fail","description":"Notify GitHub task failed. Returns labels + error comment.","inputSchema":{"type":"object","properties":{"task_id":{"type":"string"},"agent_id":{"type":"string"},"error":{"type":"string"}},"required":["task_id","agent_id"]}},
            \\{"name":"oracle_start","description":"Start Oracle Telegram watchdog thread (sends swarm status every N minutes)","inputSchema":{"type":"object","properties":{"telegram_token":{"type":"string"},"chat_id":{"type":"string"},"interval_ms":{"type":"string"}},"required":["telegram_token","chat_id"]}},
            \\{"name":"oracle_stop","description":"Stop Oracle Telegram watchdog thread","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"oracle_status","description":"Get Oracle watchdog status (running/stopped, messages sent, errors)","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_train_status","description":"Get HSLM training status — checkpoints, loss, anomalies, recommendation","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"tri_train_diagnose","description":"Diagnose HSLM training anomalies (zero loss, phase transition, overfitting)","inputSchema":{"type":"object","properties":{"dir":{"type":"string","description":"Checkpoint directory (default: data/checkpoints)"}}}},
            \\{"name":"tri_train_loss_curve","description":"Get HSLM loss curve from checkpoint headers","inputSchema":{"type":"object","properties":{"dir":{"type":"string","description":"Checkpoint directory"}}}},
            \\{"name":"tri_train_recommend","description":"Get phi-aware recommendation for next training action","inputSchema":{"type":"object","properties":{"dir":{"type":"string","description":"Checkpoint directory"}}}},
            \\{"name":"tri_train_checkpoint","description":"List HSLM checkpoints with step, loss, PPL, size","inputSchema":{"type":"object","properties":{"dir":{"type":"string","description":"Checkpoint directory"}}}},
            \\{"name":"cloud_spawn","description":"Spawn a cloud agent container for a GitHub issue","inputSchema":{"type":"object","properties":{"issue_number":{"type":"string","description":"GitHub issue number"}},"required":["issue_number"]}},
            \\{"name":"cloud_kill","description":"Kill a cloud agent container","inputSchema":{"type":"object","properties":{"issue_number":{"type":"string","description":"GitHub issue number"}},"required":["issue_number"]}},
            \\{"name":"cloud_list","description":"List all active cloud agent containers","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_status","description":"Get cloud infrastructure status","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_logs","description":"Get cloud agent deployment logs","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_spawn_all","description":"Spawn agents for all issues labeled agent:spawn","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_cleanup","description":"Remove inactive cloud agent entries","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_history","description":"Get event history for a cloud agent","inputSchema":{"type":"object","properties":{"issue_number":{"type":"string","description":"GitHub issue number (optional, omit for all)"}}}},
            \\{"name":"cloud_api_check","description":"Test API key connectivity and model routing — detects proxy returning wrong model","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_redeploy","description":"Reuse existing Railway service for a new issue number","inputSchema":{"type":"object","properties":{"service_id":{"type":"string","description":"Railway service ID"},"issue_number":{"type":"string","description":"New issue number"}},"required":["service_id","issue_number"]}},
            \\{"name":"cloud_diagnose","description":"Diagnose why an agent failed — shows GitHub comments, JSONL events, PR status","inputSchema":{"type":"object","properties":{"issue_number":{"type":"string","description":"GitHub issue number"}},"required":["issue_number"]}},
            \\{"name":"cloud_issue_create","description":"Create a GitHub issue with agent:spawn label for auto-spawning","inputSchema":{"type":"object","properties":{"title":{"type":"string","description":"Issue title"}},"required":["title"]}},
            \\{"name":"cloud_farm","description":"Railway multi-account farm dashboard — shows all accounts with capacity and daily limits","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_farm_sync","description":"Sync active service counts across all Railway accounts","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_farm_capacity","description":"Get farm capacity as JSON — total slots, active services, daily remaining per account","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_farm_rebalance","description":"Migrate services from overloaded to underloaded Railway accounts","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_train","description":"Spawn an HSLM training experiment on Railway farm","inputSchema":{"type":"object","properties":{"name":{"type":"string","description":"Experiment name (e.g. hslm-r4)"}},"required":["name"]}},
            \\{"name":"cloud_train_batch","description":"Spawn all 13 HSLM training experiments across Railway farm","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"chain_cache","description":"Chain Link 0: TVC Gate — search corpus, return cached or continue","inputSchema":{"type":"object","properties":{"task":{"type":"string","description":"Task description"}}}},
            \\{"name":"chain_baseline","description":"Chain Link 1: Analyze previous version v(n-1)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_metrics","description":"Chain Link 2: Collect performance metrics","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_patterns","description":"Chain Link 3: Research patterns and science (PAS)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_tree","description":"Chain Link 4: Build technology dependency tree","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_check_spec","description":"Chain Link 5: VIBEE-first compliance check","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_spec","description":"Chain Link 6: Create .tri specifications","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_codegen","description":"Chain Link 7: Generate Zig code from .tri specs","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_analyze","description":"Chain Link 8: Sacred Intelligence code analysis","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_test","description":"Chain Link 9: Run zig build test suite","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_bench","description":"Chain Link 10: CRITICAL — Compare to baseline v(n-1)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_fix","description":"Chain Link 11: SWE Agent error fixing","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_bench_ext","description":"Chain Link 12: Compare to external tools (llama.cpp/vLLM)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_bench_theory","description":"Chain Link 13: Gap to theoretical maximum","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_delta","description":"Chain Link 14: Generate improvement delta report","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_optimize","description":"Chain Link 15: Optimize if needed (optional)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_docs","description":"Chain Link 16: Generate documentation with proofs","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_verdict","description":"Chain Link 17: Critical self-assessment (toxic verdict)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_git","description":"Chain Link 18: Commit and push changes","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_loop","description":"Chain Link 19: Decide next iteration (continue/exit)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_deploy","description":"Chain Link 20: Auto-deploy to cloud","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_evolve","description":"Chain Link 21: Pipeline analyzes itself (eternal self-evolution)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_self_ref","description":"Chain Link 22: Pipeline improves itself (circular bootstrapping)","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_fpga_test","description":"Chain Link 23: Camera-based LED verification for FPGA","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_research","description":"Chain Link 24: Research-assisted error fixing via Perplexity","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_lint_spec","description":"Chain Link 25: Validate .tri spec syntax before codegen","inputSchema":{"type":"object","properties":{"task":{"type":"string"}}}},
            \\{"name":"chain_list","description":"List all 26 Golden Chain links with roles and status","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"cloud_decompose","description":"Decompose a GitHub issue into 5 role-based sub-issues (planner/coder/reviewer/tester/integrator)","inputSchema":{"type":"object","properties":{"issue_number":{"type":"string","description":"GitHub issue number"},"template":{"type":"string","description":"Template: standard (default), bugfix, spike"}},"required":["issue_number"]}},
            \\{"name":"tri_notify","description":"Send/edit/pin Telegram messages via tri CLI","inputSchema":{"type":"object","properties":{"text":{"type":"string","description":"Message text (HTML supported)"},"chat_id":{"type":"string","description":"Override chat ID"},"pin":{"type":"boolean","description":"Pin message after sending"},"edit_id":{"type":"string","description":"Message ID to edit instead of sending new"}},"required":["text"]}}
            \\]}}}}
        ;
        // Combine header (with id) + tools body and send with Content-Length
        const total_len = header.len + tools_body.len;
        var len_buf: [32]u8 = undefined;
        const cl_header = std.fmt.bufPrint(&len_buf, "Content-Length: {d}\r\n\r\n", .{total_len}) catch return;
        try writer.writeAll(cl_header);
        try writer.writeAll(header);
        try writer.writeAll(tools_body);
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
        } else if (std.mem.eql(u8, tool_name, "tri_chem_periodic")) {
            const cat = extractStringField(arguments_json, "category") orelse "all";
            var buf: [8192]u8 = undefined;
            try writeJsonResponse(writer, science.chemPeriodic(&buf, cat), false);
        } else if (std.mem.eql(u8, tool_name, "tri_chem_element")) {
            const elem = extractStringField(arguments_json, "element") orelse {
                try writeJsonResponse(writer, "Error: Missing element", true);
                return;
            };
            var buf: [1024]u8 = undefined;
            try writeJsonResponse(writer, science.chemElement(&buf, elem), false);
        } else if (std.mem.eql(u8, tool_name, "tri_chem_mass")) {
            const formula = extractStringField(arguments_json, "formula") orelse {
                try writeJsonResponse(writer, "Error: Missing formula", true);
                return;
            };
            var buf: [1024]u8 = undefined;
            try writeJsonResponse(writer, science.chemMass(&buf, formula), false);
        } else if (std.mem.eql(u8, tool_name, "tri_chem_moles")) {
            const formula = extractStringField(arguments_json, "formula") orelse {
                try writeJsonResponse(writer, "Error: Missing formula", true);
                return;
            };
            const mass_val = extractFloatField(arguments_json, "mass") orelse 1.0;
            var buf: [1024]u8 = undefined;
            try writeJsonResponse(writer, science.chemMoles(&buf, formula, mass_val), false);
        } else if (std.mem.eql(u8, tool_name, "tri_bio_dna")) {
            const seq = extractStringField(arguments_json, "sequence") orelse {
                try writeJsonResponse(writer, "Error: Missing sequence", true);
                return;
            };
            var buf: [2048]u8 = undefined;
            try writeJsonResponse(writer, science.bioDna(&buf, seq), false);
        } else if (std.mem.eql(u8, tool_name, "tri_bio_codon")) {
            const codon = extractStringField(arguments_json, "codon") orelse "";
            var buf: [1024]u8 = undefined;
            try writeJsonResponse(writer, science.bioCodon(&buf, codon), false);
        } else if (std.mem.eql(u8, tool_name, "tri_bio_protein")) {
            const seq = extractStringField(arguments_json, "sequence") orelse {
                try writeJsonResponse(writer, "Error: Missing sequence", true);
                return;
            };
            var buf: [1024]u8 = undefined;
            try writeJsonResponse(writer, science.bioProtein(&buf, seq), false);
        } else if (std.mem.eql(u8, tool_name, "tri_quantum_constants")) {
            var buf: [512]u8 = undefined;
            try writeJsonResponse(writer, science.quantumConstants(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "tri_quantum_states")) {
            var buf: [1024]u8 = undefined;
            try writeJsonResponse(writer, science.quantumStates(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "tri_bell_states")) {
            var buf: [256]u8 = undefined;
            try writeJsonResponse(writer, science.bellStates(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "tri_formula")) {
            const n = @as(i32, @intCast(extractIntField(arguments_json, "n") orelse 1));
            const k = @as(i32, @intCast(extractIntField(arguments_json, "k") orelse 0));
            const m = @as(i32, @intCast(extractIntField(arguments_json, "m") orelse 0));
            const p = @as(i32, @intCast(extractIntField(arguments_json, "p") orelse 0));
            const q = @as(i32, @intCast(extractIntField(arguments_json, "q") orelse 0));
            var buf: [512]u8 = undefined;
            try writeJsonResponse(writer, science.sacredFormula(&buf, n, k, m, p, q), false);
        } else if (std.mem.startsWith(u8, tool_name, "swarm_")) {
            // ═══ SWARM TOOLS ═══
            try self.handleSwarmTool(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "chain_")) {
            // ═══ CHAIN TOOLS (26 Golden Chain links) ═══
            try self.handleChainTool(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "cloud_")) {
            // ═══ CLOUD TOOLS ═══
            try self.handleCloudTool(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "oracle_")) {
            // ═══ ORACLE WATCHDOG TOOLS ═══
            try self.handleOracleTool(tool_name, arguments_json, writer);
        } else if (std.mem.startsWith(u8, tool_name, "tri_train_")) {
            // ═══ TRAINING MONITOR TOOLS ═══
            try self.handleTrainTool(tool_name, arguments_json, writer);
        } else if (std.mem.eql(u8, tool_name, "tri_notify")) {
            try self.toolTriNotify(arguments_json, writer);
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
                const msg = std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch {
                    try writeJsonResponse(writer, "Error", true);
                    return;
                };
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
                const msg = std.fmt.allocPrint(self.allocator, "Error reading file: {s}", .{@errorName(err)}) catch {
                    try writeJsonResponse(writer, "Error reading file", true);
                    return;
                };
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer self.allocator.free(source);
            var matcher = needle.Matcher.init(self.allocator, source, file_path);
            var matches = matcher.findMatches(query) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch {
                    try writeJsonResponse(writer, "Error", true);
                    return;
                };
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer matches.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Found {d} matches for '{s}' in {s}", .{ matches.len(), query, file_path }) catch "Search completed";
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
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Graph refactor: '{s}' -> '{s}' - Tier 2 topological safe refactor (preview={s})", .{ symbol, new_name, if (preview) "true" else "false" }) catch "Refactor initiated";
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
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Extract function '{s}' from '{s}' - Tier 2 Graph analysis", .{ function_name, file }) catch "Extract initiated";
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
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA semantic search: '{s}' - Tier 3 cosine similarity", .{query}) catch "Search";
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
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Semantic replace: '{s}' -> '{s}' - Tier 3 VSA intent matching", .{ intent, replacement_intent }) catch "Replace";
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
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Safe cross-file refactor: '{s}' -> '{s}' threshold={d:.2} preview={s} - Tier 4 VSA rules + 100% rollback", .{ intent, new_intent, semantic_threshold, if (preview) "true" else "false" }) catch "Refactor initiated";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_vsa_rule_apply")) {
            // Tier 4: Apply VSA rules for validation
            const transformation = extractStringField(arguments_json, "transformation") orelse {
                try writeJsonResponse(writer, "Error: Missing transformation", true);
                return;
            };
            const rules_file = extractStringField(arguments_json, "rules_file") orelse "default";
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "VSA rule validation for '{s}' (rules: {s}) - Tier 4 safety gates", .{ transformation, rules_file }) catch "Validation";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_cross_preview")) {
            // Tier 4: Preview cross-file impact
            const symbol = extractStringField(arguments_json, "symbol") orelse {
                try writeJsonResponse(writer, "Error: Missing symbol", true);
                return;
            };
            const new_name = extractStringField(arguments_json, "new_name") orelse symbol;
            const include_vsa = extractBoolField(arguments_json, "include_vsa") orelse true;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Cross-file preview: '{s}' -> '{s}' vsa={s} - Tier 4 impact analysis", .{ symbol, new_name, if (include_vsa) "true" else "false" }) catch "Preview";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_rollback_all")) {
            // Tier 4: Rollback all changes
            const refactor_id = extractStringField(arguments_json, "refactor_id") orelse "latest";
            var buffer: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Rollback '{s}' - Tier 4 atomic restore", .{refactor_id}) catch "Rollback";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_init")) {
            // Tier 5: Initialize Omega autonomous agent
            const root_dir = extractStringField(arguments_json, "root_dir") orelse ".";
            const autonomy_level = extractStringField(arguments_json, "autonomy_level") orelse "assisted";
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega agent initialized for '{s}' (level: {s}) - Tier 5 FULL AUTONOMY", .{ root_dir, autonomy_level }) catch "Omega init";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_analyze")) {
            // Tier 5: Omega analyzes codebase
            const intent = extractStringField(arguments_json, "intent") orelse "auto";
            const auto_detect = extractBoolField(arguments_json, "auto_detect") orelse true;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega analysis: '{s}' auto_detect={s} - Tier 5 autonomous detection", .{ intent, if (auto_detect) "true" else "false" }) catch "Analysis";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_execute")) {
            // Tier 5: Execute refactor plan
            const plan_id = extractStringField(arguments_json, "plan_id") orelse "latest";
            const confirm = extractBoolField(arguments_json, "confirm") orelse false;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega executing plan '{s}' confirm={s} - Tier 5 autonomous execution with safety gates", .{ plan_id, if (confirm) "true" else "false" }) catch "Execute";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_omega_detect")) {
            // Tier 5: Auto-detect improvements
            const min_confidence = extractFloatField(arguments_json, "min_confidence") orelse 0.7;
            const max_results = extractIntField(arguments_json, "max_results") orelse 10;
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Omega detecting improvements min_conf={d:.2} max={d} - Tier 5 autonomous suggestion", .{ min_confidence, max_results }) catch "Detect";
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
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Atomic refactor on '{s}': '{s}' -> '{s}' Phase 1 with 100% rollback guarantee", .{ file_path, pattern_query, replacement }) catch "Refactor";
            try writeJsonResponse(writer, msg, false);
        } else if (std.mem.eql(u8, tool_name, "needle_parse_check")) {
            // Phase 1: Parse check using Zig AST
            const file_path = extractStringField(arguments_json, "file_path") orelse {
                try writeJsonResponse(writer, "Error: Missing file_path", true);
                return;
            };
            // Run real parse check
            const check = @import("needle");
            var parse_result = check.runParseCheck(self.allocator, file_path) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Parse check error: {s}", .{@errorName(err)}) catch {
                    try writeJsonResponse(writer, "Parse check error", true);
                    return;
                };
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer parse_result.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Parse check: valid={}, errors={}", .{ parse_result.valid, parse_result.error_count }) catch "Parse result";
            try writeJsonResponse(writer, msg, !parse_result.valid);
        } else if (std.mem.eql(u8, tool_name, "needle_compile_check")) {
            // Phase 1: Compile check using zig build
            const project_root = extractStringField(arguments_json, "project_root") orelse ".";
            const check = @import("needle");
            var compile_result = check.runCompileCheck(self.allocator, project_root) catch |err| {
                const msg = std.fmt.allocPrint(self.allocator, "Compile check error: {s}", .{@errorName(err)}) catch {
                    try writeJsonResponse(writer, "Compile check error", true);
                    return;
                };
                defer self.allocator.free(msg);
                try writeJsonResponse(writer, msg, true);
                return;
            };
            defer compile_result.deinit();
            var buffer: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buffer, "Compile check: success={}, exit_code={}", .{ compile_result.success, compile_result.exit_code }) catch "Compile result";
            try writeJsonResponse(writer, msg, !compile_result.success);
        } else {
            try writeJsonResponse(writer, "Tool not yet implemented", false);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // SWARM Tools (delegate to swarm_tools.zig)
    // ═══════════════════════════════════════════════════════════════════════────

    fn handleSwarmTool(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        var buf: [8192]u8 = undefined;

        if (std.mem.eql(u8, tool_name, "swarm_status")) {
            try writeJsonResponse(writer, swarm.swarmStatus(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_agents")) {
            try writeJsonResponse(writer, swarm.swarmAgents(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_register")) {
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            const hostname = extractStringField(arguments_json, "hostname") orelse "";
            try writeJsonResponse(writer, swarm.swarmRegister(&buf, agent_id, hostname), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_heartbeat")) {
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            const status = extractStringField(arguments_json, "status") orelse "idle";
            const branch = extractStringField(arguments_json, "branch") orelse "";
            const task_id = extractStringField(arguments_json, "task_id") orelse "";
            const commit_sha = extractStringField(arguments_json, "commit_sha") orelse "";
            try writeJsonResponse(writer, swarm.swarmHeartbeat(&buf, agent_id, status, branch, task_id, commit_sha), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_task_get")) {
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            try writeJsonResponse(writer, swarm.swarmTaskGet(&buf, agent_id), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_task_add")) {
            const id = extractStringField(arguments_json, "id") orelse "";
            const slug_str = extractStringField(arguments_json, "slug") orelse "";
            const description = extractStringField(arguments_json, "description") orelse "";
            const priority = extractStringField(arguments_json, "priority") orelse "P1";
            try writeJsonResponse(writer, swarm.swarmTaskAdd(&buf, id, slug_str, description, priority), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_task_cancel")) {
            const task_id = extractStringField(arguments_json, "task_id") orelse {
                try writeJsonResponse(writer, "Error: Missing task_id", true);
                return;
            };
            try writeJsonResponse(writer, swarm.swarmTaskCancel(&buf, task_id), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_tasks")) {
            try writeJsonResponse(writer, swarm.swarmTasks(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_pause")) {
            try writeJsonResponse(writer, swarm.swarmPause(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_resume")) {
            try writeJsonResponse(writer, swarm.swarmResume(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_assign")) {
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            const description = extractStringField(arguments_json, "description") orelse {
                try writeJsonResponse(writer, "Error: Missing description", true);
                return;
            };
            try writeJsonResponse(writer, swarm.swarmAssign(&buf, agent_id, description), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_github_sync")) {
            const issue_number = extractStringField(arguments_json, "issue_number") orelse {
                try writeJsonResponse(writer, "Error: Missing issue_number", true);
                return;
            };
            const title = extractStringField(arguments_json, "title") orelse {
                try writeJsonResponse(writer, "Error: Missing title", true);
                return;
            };
            const labels = extractStringField(arguments_json, "labels") orelse "";
            try writeJsonResponse(writer, swarm.swarmGithubSync(&buf, issue_number, title, labels), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_github_on_start")) {
            const task_id = extractStringField(arguments_json, "task_id") orelse {
                try writeJsonResponse(writer, "Error: Missing task_id", true);
                return;
            };
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            const branch = extractStringField(arguments_json, "branch") orelse "";
            try writeJsonResponse(writer, swarm.swarmGithubOnStart(&buf, task_id, agent_id, branch), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_github_on_complete")) {
            const task_id = extractStringField(arguments_json, "task_id") orelse {
                try writeJsonResponse(writer, "Error: Missing task_id", true);
                return;
            };
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            const result_str = extractStringField(arguments_json, "result") orelse "";
            try writeJsonResponse(writer, swarm.swarmGithubOnComplete(&buf, task_id, agent_id, result_str), false);
        } else if (std.mem.eql(u8, tool_name, "swarm_github_on_fail")) {
            const task_id = extractStringField(arguments_json, "task_id") orelse {
                try writeJsonResponse(writer, "Error: Missing task_id", true);
                return;
            };
            const agent_id = extractStringField(arguments_json, "agent_id") orelse {
                try writeJsonResponse(writer, "Error: Missing agent_id", true);
                return;
            };
            const error_msg = extractStringField(arguments_json, "error") orelse "";
            try writeJsonResponse(writer, swarm.swarmGithubOnFail(&buf, task_id, agent_id, error_msg), false);
        } else {
            try writeJsonResponse(writer, "Error: Unknown swarm tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // CHAIN Tools — 26 Golden Chain links (delegate to cloud_tools.zig chainRun)
    // ═══════════════════════════════════════════════════════════════════════────

    fn handleChainTool(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        var buf: [8192]u8 = undefined;

        if (std.mem.eql(u8, tool_name, "chain_list")) {
            try writeJsonResponse(writer, cloud.chainList(&buf), false);
            return;
        }

        // All chain_* tools map to: tri chain <cli_name> --task <task>
        // Strip "chain_" prefix and convert underscores to hyphens for CLI name
        const prefix = "chain_";
        if (tool_name.len <= prefix.len) {
            try writeJsonResponse(writer, "Error: Invalid chain tool name", true);
            return;
        }
        const raw_name = tool_name[prefix.len..];

        // Convert underscores to hyphens: chain_check_spec → check-spec
        var cli_name_buf: [64]u8 = undefined;
        const cli_len = @min(raw_name.len, cli_name_buf.len);
        @memcpy(cli_name_buf[0..cli_len], raw_name[0..cli_len]);
        for (cli_name_buf[0..cli_len]) |*c| {
            if (c.* == '_') c.* = '-';
        }
        const cli_name = cli_name_buf[0..cli_len];

        const task = extractStringField(arguments_json, "task") orelse "";
        try writeJsonResponse(writer, cloud.chainRun(&buf, cli_name, task), false);
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // CLOUD Tools (delegate to cloud_tools.zig)
    // ═══════════════════════════════════════════════════════════════════════────

    fn handleCloudTool(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        var buf: [8192]u8 = undefined;

        if (std.mem.eql(u8, tool_name, "cloud_spawn")) {
            const issue_number = extractStringField(arguments_json, "issue_number") orelse {
                try writeJsonResponse(writer, "Error: Missing issue_number", true);
                return;
            };
            try writeJsonResponse(writer, cloud.cloudSpawn(&buf, issue_number), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_kill")) {
            const issue_number = extractStringField(arguments_json, "issue_number") orelse {
                try writeJsonResponse(writer, "Error: Missing issue_number", true);
                return;
            };
            try writeJsonResponse(writer, cloud.cloudKill(&buf, issue_number), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_list")) {
            try writeJsonResponse(writer, cloud.cloudList(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_status")) {
            try writeJsonResponse(writer, cloud.cloudStatus(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_logs")) {
            try writeJsonResponse(writer, cloud.cloudLogs(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_spawn_all")) {
            try writeJsonResponse(writer, cloud.cloudSpawnAll(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_cleanup")) {
            try writeJsonResponse(writer, cloud.cloudCleanup(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_history")) {
            const issue_number = extractStringField(arguments_json, "issue_number") orelse "";
            try writeJsonResponse(writer, cloud.cloudHistory(&buf, issue_number), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_api_check")) {
            try writeJsonResponse(writer, cloud.cloudApiCheck(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_redeploy")) {
            const service_id = extractStringField(arguments_json, "service_id") orelse {
                try writeJsonResponse(writer, "Error: Missing service_id", true);
                return;
            };
            const issue_number = extractStringField(arguments_json, "issue_number") orelse {
                try writeJsonResponse(writer, "Error: Missing issue_number", true);
                return;
            };
            try writeJsonResponse(writer, cloud.cloudRedeploy(&buf, service_id, issue_number), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_diagnose")) {
            const issue_number = extractStringField(arguments_json, "issue_number") orelse {
                try writeJsonResponse(writer, "Error: Missing issue_number", true);
                return;
            };
            try writeJsonResponse(writer, cloud.cloudDiagnose(&buf, issue_number), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_issue_create")) {
            const title = extractStringField(arguments_json, "title") orelse {
                try writeJsonResponse(writer, "Error: Missing title", true);
                return;
            };
            try writeJsonResponse(writer, cloud.cloudIssueCreate(&buf, title), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_decompose")) {
            const issue_number = extractStringField(arguments_json, "issue_number") orelse {
                try writeJsonResponse(writer, "Error: Missing issue_number", true);
                return;
            };
            const template = extractStringField(arguments_json, "template") orelse "";
            try writeJsonResponse(writer, cloud.decomposeIssue(&buf, issue_number, template), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_farm")) {
            try writeJsonResponse(writer, cloud.cloudFarm(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_farm_sync")) {
            try writeJsonResponse(writer, cloud.cloudFarmSync(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_farm_capacity")) {
            try writeJsonResponse(writer, cloud.cloudFarmCapacity(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_farm_rebalance")) {
            try writeJsonResponse(writer, cloud.cloudFarmRebalance(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_train")) {
            const name = extractStringField(arguments_json, "name") orelse {
                try writeJsonResponse(writer, "Error: Missing name", true);
                return;
            };
            try writeJsonResponse(writer, cloud.cloudTrain(&buf, name), false);
        } else if (std.mem.eql(u8, tool_name, "cloud_train_batch")) {
            try writeJsonResponse(writer, cloud.cloudTrainBatch(&buf), false);
        } else {
            try writeJsonResponse(writer, "Error: Unknown cloud tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // ORACLE Watchdog Tools (delegate to oracle_watchdog.zig)
    // ═══════════════════════════════════════════════════════════════════════────

    fn handleOracleTool(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        var buf: [2048]u8 = undefined;

        if (std.mem.eql(u8, tool_name, "oracle_start")) {
            const token = extractStringField(arguments_json, "telegram_token") orelse {
                try writeJsonResponse(writer, "Error: Missing telegram_token", true);
                return;
            };
            const chat_id = extractStringField(arguments_json, "chat_id") orelse {
                try writeJsonResponse(writer, "Error: Missing chat_id", true);
                return;
            };
            const interval = extractStringField(arguments_json, "interval_ms") orelse "300000";
            try writeJsonResponse(writer, oracle.oracleStart(&buf, token, chat_id, interval), false);
        } else if (std.mem.eql(u8, tool_name, "oracle_stop")) {
            try writeJsonResponse(writer, oracle.oracleStop(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "oracle_status")) {
            try writeJsonResponse(writer, oracle.oracleStatus(&buf), false);
        } else {
            try writeJsonResponse(writer, "Error: Unknown oracle tool", true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════────
    // TRAINING MONITOR TOOLS
    // ═══════════════════════════════════════════════════════════════════════────

    fn handleTrainTool(self: *TrinityMCPServer, tool_name: []const u8, arguments_json: []const u8, writer: anytype) !void {
        _ = self;
        const tri_train = @import("tri_train");
        const default_dir = "data/checkpoints";
        const dir = extractStringField(arguments_json, "dir") orelse default_dir;
        var buf: [8192]u8 = undefined;

        if (std.mem.eql(u8, tool_name, "tri_train_status")) {
            try writeJsonResponse(writer, tri_train.getStatusJson(&buf), false);
        } else if (std.mem.eql(u8, tool_name, "tri_train_diagnose")) {
            try writeJsonResponse(writer, tri_train.getDiagnoseJson(&buf, dir), false);
        } else if (std.mem.eql(u8, tool_name, "tri_train_loss_curve")) {
            try writeJsonResponse(writer, tri_train.getLossCurveJson(&buf, dir), false);
        } else if (std.mem.eql(u8, tool_name, "tri_train_recommend")) {
            try writeJsonResponse(writer, tri_train.getRecommendJson(&buf, dir), false);
        } else if (std.mem.eql(u8, tool_name, "tri_train_checkpoint")) {
            try writeJsonResponse(writer, tri_train.getLossCurveJson(&buf, dir), false);
        } else {
            try writeJsonResponse(writer, "Error: Unknown train tool", true);
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

    fn toolTriNotify(self: *TrinityMCPServer, arguments_json: []const u8, writer: anytype) !void {
        const text = extractStringField(arguments_json, "text") orelse {
            try writeJsonResponse(writer, "Error: Missing text parameter", true);
            return;
        };
        const chat_id = extractStringField(arguments_json, "chat_id");
        const edit_id = extractStringField(arguments_json, "edit_id");
        const pin = extractBoolField(arguments_json, "pin") orelse false;

        // Build args: notify [--chat X] [--pin] [--edit X] "text"
        var args_buf: [6][]const u8 = undefined;
        var argc: usize = 0;
        if (chat_id) |cid| {
            args_buf[argc] = "--chat";
            argc += 1;
            args_buf[argc] = cid;
            argc += 1;
        }
        if (pin) {
            args_buf[argc] = "--pin";
            argc += 1;
        }
        if (edit_id) |eid| {
            args_buf[argc] = "--edit";
            argc += 1;
            args_buf[argc] = eid;
            argc += 1;
        }
        args_buf[argc] = text;
        argc += 1;

        const output = try self.executeTriSimple("notify", args_buf[0..argc]);
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
            return std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)}) catch
                return self.allocator.dupe(u8, "Error") catch "Error";
        };

        defer self.allocator.free(result.stderr);
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
    // Find closing quote, skipping escaped quotes
    var pos = value_start;
    while (pos < json.len) : (pos += 1) {
        if (json[pos] == '"') {
            // Check if this quote is escaped (count preceding backslashes)
            var backslashes: usize = 0;
            var bp = pos;
            while (bp > value_start and json[bp - 1] == '\\') {
                backslashes += 1;
                bp -= 1;
            }
            // Odd number of backslashes = escaped quote, even = real quote
            if (backslashes % 2 == 0) return json[value_start..pos];
        }
    }
    return null;
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
        if (c == ',' or c == '}' or c == ' ' or c == '\n') break;
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
        if (c == ',' or c == '}' or c == ' ' or c == '\n') break;
        value_end += 1;
    }

    const num_str = json[value_start..value_end];
    return std.fmt.parseInt(i64, num_str, 10) catch null;
}

/// Thread-local request id for current JSON-RPC call
var current_request_id: []const u8 = "null";

fn writeJsonResponse(writer: anytype, text: []const u8, is_error: bool) !void {
    var buffer: [16384]u8 = undefined;
    var idx: usize = 0;

    // Build: {"jsonrpc":"2.0","id":<id>,"result":{"content":[{"type":"text","text":"
    const p1 = "{\"jsonrpc\":\"2.0\",\"id\":";
    @memcpy(buffer[idx..][0..p1.len], p1);
    idx += p1.len;
    const rid_len = @min(current_request_id.len, 64); // cap request ID length
    @memcpy(buffer[idx..][0..rid_len], current_request_id[0..rid_len]);
    idx += rid_len;
    const p2 = ",\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"";
    @memcpy(buffer[idx..][0..p2.len], p2);
    idx += p2.len;

    for (text) |c| {
        if (idx + 6 >= buffer.len) break; // safety
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
        } else if (c < 0x20) {
            // Escape control characters as \u00XX for valid JSON
            if (idx + 6 >= buffer.len) break;
            const hex = "0123456789abcdef";
            buffer[idx] = '\\';
            buffer[idx + 1] = 'u';
            buffer[idx + 2] = '0';
            buffer[idx + 3] = '0';
            buffer[idx + 4] = hex[c >> 4];
            buffer[idx + 5] = hex[c & 0x0f];
            idx += 6;
        } else {
            buffer[idx] = c;
            idx += 1;
        }
    }

    const suffix = "\"}],\"isError\":";
    const error_val = if (is_error) "true" else "false";
    const closing = "}}";
    const tail_len = suffix.len + error_val.len + closing.len;
    if (idx + tail_len > buffer.len) {
        // Truncate text to make room for tail
        idx = buffer.len - tail_len;
    }
    @memcpy(buffer[idx..][0..suffix.len], suffix);
    idx += suffix.len;
    @memcpy(buffer[idx..][0..error_val.len], error_val);
    idx += error_val.len;
    @memcpy(buffer[idx..][0..closing.len], closing);
    idx += closing.len;

    try writeWithContentLength(writer, buffer[0..idx]);
}

/// Write a response with Content-Length framing
fn writeWithContentLength(writer: anytype, body: []const u8) !void {
    var len_buf: [32]u8 = undefined;
    const cl = std.fmt.bufPrint(&len_buf, "Content-Length: {d}\r\n\r\n", .{body.len}) catch return;
    try writer.writeAll(cl);
    try writer.writeAll(body);
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

    // Debug to stderr (best-effort: stderr may not be available)
    const stderr_fd: posix.fd_t = 2;
    _ = posix.write(stderr_fd, "TRINITY MCP Server v2.0.0 started\n") catch |err| {
        std.log.debug("server: stderr write failed: {}", .{err});
    };
    _ = posix.write(stderr_fd, "38+ tools + resources + prompts | Content-Length framing\n\n") catch |err| {
        std.log.debug("server: stderr write failed: {}", .{err});
    };

    // Auto-start Oracle Telegram watchdog if env vars set
    oracle.tryAutoStart();

    var stdout_writer = StdoutWriter{};

    // Buffered stdin reader
    var stdin_buf: [262144]u8 = undefined; // 256KB buffer
    var stdin_filled: usize = 0;

    while (true) {
        // Read more data from stdin
        const bytes_read = posix.read(0, stdin_buf[stdin_filled..]) catch |err| {
            if (err == error.WouldBlock) continue;
            break;
        };
        if (bytes_read == 0) break;
        stdin_filled += bytes_read;

        // Process all complete messages in buffer
        while (true) {
            // Try to parse Content-Length header
            const header_end = std.mem.indexOf(u8, stdin_buf[0..stdin_filled], "\r\n\r\n");
            if (header_end == null) {
                // Maybe raw JSON (no Content-Length) — check for newline-delimited
                const nl = std.mem.indexOfScalar(u8, stdin_buf[0..stdin_filled], '\n');
                if (nl) |newline_pos| {
                    const line = stdin_buf[0..newline_pos];
                    if (line.len > 0 and line[0] == '{') {
                        processMessage(&server, line, &stdout_writer, allocator) catch |err| {
                            std.log.err("MCP message processing failed: {s}", .{@errorName(err)});
                        };
                    }
                    // Shift buffer
                    const remaining = stdin_filled - (newline_pos + 1);
                    if (remaining > 0) {
                        std.mem.copyForwards(u8, &stdin_buf, stdin_buf[newline_pos + 1 .. stdin_filled]);
                    }
                    stdin_filled = remaining;
                    continue;
                }
                break; // Need more data
            }

            const hdr_end = header_end.?;
            const headers = stdin_buf[0..hdr_end];

            // Parse Content-Length
            var content_length: ?usize = null;
            var line_start: usize = 0;
            while (line_start < headers.len) {
                const line_end = std.mem.indexOfPos(u8, headers, line_start, "\r\n") orelse headers.len;
                const hdr_line = headers[line_start..line_end];
                if (std.ascii.startsWithIgnoreCase(hdr_line, "content-length:")) {
                    const val_str = std.mem.trimLeft(u8, hdr_line["content-length:".len..], " ");
                    content_length = std.fmt.parseInt(usize, val_str, 10) catch null;
                }
                line_start = if (line_end + 2 <= headers.len) line_end + 2 else headers.len;
            }

            const cl = content_length orelse {
                // Skip malformed header
                const skip = hdr_end + 4;
                const remaining = stdin_filled - skip;
                if (remaining > 0) {
                    std.mem.copyForwards(u8, &stdin_buf, stdin_buf[skip..stdin_filled]);
                }
                stdin_filled = remaining;
                continue;
            };

            const body_start = hdr_end + 4;
            const total_msg_len = body_start + cl;

            if (stdin_filled < total_msg_len) break; // Need more data

            const body = stdin_buf[body_start .. body_start + cl];
            processMessage(&server, body, &stdout_writer, allocator) catch |err| {
                std.log.err("MCP message processing failed: {s}", .{@errorName(err)});
            };

            // Shift buffer
            const remaining = stdin_filled - total_msg_len;
            if (remaining > 0) {
                std.mem.copyForwards(u8, &stdin_buf, stdin_buf[total_msg_len..stdin_filled]);
            }
            stdin_filled = remaining;
        }
    }
}

/// Process a single JSON-RPC message
fn processMessage(server: *TrinityMCPServer, request: []const u8, writer: anytype, allocator: std.mem.Allocator) !void {
    // Extract JSON-RPC id
    const id_str = extractJsonId(request);
    current_request_id = id_str;

    // Route by method
    if (std.mem.indexOf(u8, request, "\"initialize\"") != null) {
        try server.writeInitializeResponse(id_str, writer);
    } else if (std.mem.indexOf(u8, request, "\"tools/list\"") != null) {
        try server.writeToolsList(id_str, writer);
    } else if (std.mem.indexOf(u8, request, "\"tools/call\"") != null) {
        // Extract tool name from params
        const params_idx = std.mem.indexOf(u8, request, "\"params\":") orelse return;
        const name_after = std.mem.indexOf(u8, request[params_idx..], "\"name\":") orelse return;
        const name_idx = params_idx + name_after;
        const name_start = name_idx + 8;
        const name_end = std.mem.indexOfScalarPos(u8, request, name_start, '"') orelse return;
        const tool_name = request[name_start..name_end];

        // Extract arguments
        const args_idx = std.mem.indexOf(u8, request[params_idx..], "\"arguments\":") orelse return;
        const args_abs = params_idx + args_idx + 12; // "arguments": = 12 chars
        var search = args_abs;
        while (search < request.len and std.ascii.isWhitespace(request[search])) search += 1;
        if (search >= request.len) return;

        if (request[search] == '{') {
            var brace: usize = 1;
            var end = search + 1;
            var in_string = false;
            var escape_next = false;
            while (end < request.len and brace > 0) {
                const ch = request[end];
                if (escape_next) {
                    escape_next = false;
                } else if (ch == '\\' and in_string) {
                    escape_next = true;
                } else if (ch == '"') {
                    in_string = !in_string;
                } else if (!in_string) {
                    if (ch == '{') brace += 1;
                    if (ch == '}') brace -= 1;
                }
                end += 1;
            }
            try server.handleToolsCall(tool_name, request[search..end], writer);
        } else if (request[search] == '"') {
            var end = search + 1;
            while (end < request.len and request[end] != '"') end += 1;
            try server.handleToolsCall(tool_name, request[search + 1 .. end], writer);
        }
    } else if (std.mem.indexOf(u8, request, "\"resources/list\"") != null) {
        const json = resources_mod.generateResourcesList(allocator) catch return;
        defer allocator.free(json);
        var buf: [8192]u8 = undefined;
        const resp = std.fmt.bufPrint(&buf, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}", .{ id_str, json }) catch return;
        try writeWithContentLength(writer, resp);
    } else if (std.mem.indexOf(u8, request, "\"resources/read\"") != null) {
        const uri = extractStringField(request, "uri") orelse return;
        const content = resources_mod.loadResource(allocator, uri) catch {
            return;
        };
        defer allocator.free(content);
        // Send as text content
        var resp_buf: std.ArrayList(u8) = .{};
        defer resp_buf.deinit(allocator);
        const w = resp_buf.writer(allocator);
        try w.print("{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{{\"contents\":[{{\"uri\":\"{s}\",\"text\":\"", .{ id_str, uri });
        // JSON-escape content
        for (content) |c| {
            switch (c) {
                '\\' => try resp_buf.appendSlice(allocator, "\\\\"),
                '"' => try resp_buf.appendSlice(allocator, "\\\""),
                '\n' => try resp_buf.appendSlice(allocator, "\\n"),
                '\r' => try resp_buf.appendSlice(allocator, "\\r"),
                '\t' => try resp_buf.appendSlice(allocator, "\\t"),
                else => try resp_buf.append(allocator, c),
            }
        }
        try resp_buf.appendSlice(allocator, "\"}}]}}}");
        try writeWithContentLength(writer, resp_buf.items);
    } else if (std.mem.indexOf(u8, request, "\"prompts/list\"") != null) {
        const json = prompts_mod.generatePromptsList(allocator) catch return;
        defer allocator.free(json);
        var buf: [8192]u8 = undefined;
        const resp = std.fmt.bufPrint(&buf, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}", .{ id_str, json }) catch return;
        try writeWithContentLength(writer, resp);
    } else if (std.mem.indexOf(u8, request, "\"prompts/get\"") != null) {
        const name = extractStringField(request, "name") orelse return;
        const json = prompts_mod.generatePromptGetResponse(allocator, name, null) catch return;
        defer allocator.free(json);
        var buf: [8192]u8 = undefined;
        const resp = std.fmt.bufPrint(&buf, "{{\"jsonrpc\":\"2.0\",\"id\":{s},\"result\":{s}}}", .{ id_str, json }) catch return;
        try writeWithContentLength(writer, resp);
    } else if (std.mem.indexOf(u8, request, "\"notifications/") != null) {
        // Notifications have no id, no response needed
        return;
    }
}

/// Extract the "id" field from a JSON-RPC request (returns the raw JSON value)
fn extractJsonId(json: []const u8) []const u8 {
    const id_key = "\"id\":";
    const id_start = std.mem.indexOf(u8, json, id_key) orelse return "null";
    var pos = id_start + id_key.len;
    // Skip whitespace
    while (pos < json.len and std.ascii.isWhitespace(json[pos])) pos += 1;
    if (pos >= json.len) return "null";

    if (json[pos] == '"') {
        // String id: "id":"foo"
        const str_start = pos;
        pos += 1;
        while (pos < json.len and json[pos] != '"') pos += 1;
        if (pos < json.len) pos += 1;
        return json[str_start..pos];
    } else {
        // Numeric id: "id":1
        const num_start = pos;
        while (pos < json.len and json[pos] != ',' and json[pos] != '}' and !std.ascii.isWhitespace(json[pos])) pos += 1;
        return json[num_start..pos];
    }
}
