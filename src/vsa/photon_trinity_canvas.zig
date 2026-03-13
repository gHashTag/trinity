// =============================================================================
// TRINITY CANVAS v2.1 - MIRROR OF THREE WORLDS
// No side panels — everything inside canvas as wave patterns
// Shift+1 Chat | Shift+2 Code | Shift+3 Tools | Shift+4 Settings | Shift+5 Vision | Shift+6 Voice
// ESC = return to idle (27 petals logo)
// phi^2 + 1/phi^2 = 3 = TRINITY
// =============================================================================

const std = @import("std");
const builtin = @import("builtin");
const is_emscripten = builtin.os.tag == .emscripten;
const photon = @import("photon.zig");
const wave_scroll = @import("wave_scroll.zig"); // Emergent Wave ScrollView v1.0
const theme = @import("trinity_canvas/theme.zig"); // SINGLE SOURCE OF TRUTH
const world_docs = @import("trinity_canvas/world_docs.zig");
const igla_chat = @import("igla_chat");
const fluent_chat = @import("igla_fluent_chat");
const igla_hybrid_chat = @import("igla_hybrid_chat");
const golden_chain = @import("golden_chain");
const tvc = @import("tvc_corpus");
const auto_shard = @import("auto_shard");
const world_dots = @import("world_dots.zig");
const math = std.math;
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
});
// v8.4: raygui shortcut
const rg = rl;

// Emscripten API for browser yield (emscripten_sleep)
const emc = if (is_emscripten) @cImport(@cInclude("emscripten/emscripten.h")) else struct {};

// Global chat engines
var g_chat_engine: igla_chat.IglaLocalChat = igla_chat.IglaLocalChat.init();
var g_fluent_engine: fluent_chat.FluentChatEngine = undefined;
var g_fluent_engine_inited: bool = false;

// v2.4: Hybrid chat engine (4-level cache: Tools → Symbolic → TVC → LLM)
var g_hybrid_engine: ?igla_hybrid_chat.IglaHybridChat = null;
var g_hybrid_corpus: ?*tvc.TVCCorpus = null;
var g_hybrid_inited: bool = false;
// GPA for hybrid engine allocations (page_allocator on WASM)
var g_hybrid_gpa: if (is_emscripten) u8 else std.heap.GeneralPurposeAllocator(.{}) = if (is_emscripten) 0 else std.heap.GeneralPurposeAllocator(.{}){};

// v3.0: Golden Chain Agent (8-node unified pipeline)
var g_chain_agent: ?golden_chain.GoldenChainAgent = null;

// =============================================================================
// COSMIC CONSTANTS (from theme.zig)
// =============================================================================

const PHI: f32 = theme.PHI;
const PHI_INV: f32 = theme.PHI_INV;
const TAU: f32 = theme.TAU;

// Grid fills ENTIRE screen
var g_width: c_int = 1512;
var g_height: c_int = 982;
var g_pixel_size: c_int = 4;
// Adaptive font scale: proportional to screen width (reference: 1280px)
var g_font_scale: f32 = 1.0;
// HiDPI scale factor (2.0 on Retina, 1.0 on standard displays)
var g_dpi_scale: f32 = 1.0;
// Chat font (Montserrat with Cyrillic) — set in main()
var g_font_chat: rl.Font = undefined;
// v8.6: Emoji font for tool pills and UI elements
var g_font_emoji: rl.Font = undefined;

// ── Persistent chat state (survives panel close/reopen) ──
const MAX_CHAT_MSGS = 128; // v3.0: increased for Golden Chain (8+ msgs per query)
const ChatMsgType = enum {
    user,
    ai,
    log,
    //   — 8 chain nodes (Chakra colors)
    chain_goal_parse, // Red —
    chain_decompose, // Orange — inandwithon
    chain_schedule, // Yellow — and
    chain_execute, // Green — on
    chain_monitor, // Blue — and
    chain_adapt, // Indigo — on
    chain_synthesize, // Violet — with
    chain_deliver, // Gold — andwithin
    // Additional feedback types
    tool_result, // Tool execution
    routing_info, // Routing decision
    reflection, // Self-learning event
    agent_error, // Error
    // v1.1: Truth & Provenance
    provenance_step, // Hash chain record (steel blue)
    truth_verification, // Chain integrity verdict (bright teal)
    // v1.2: Quark-Gluon
    quark_step, // Quark sub-step record (light steel blue)
    gluon_entangle, // Gluon entanglement notification (magenta)
    // v1.4: DAG + Rewards
    dag_visualization, // DAG edge/stats summary (cyan)
    reward_summary, // $TRI reward summary (gold)
    // v1.5: Collapsible + Shareable + Staking
    collapse_toggle, // Node collapse/expand event (slate)
    share_link_generated, // Shareable link created (electric blue)
    staking_event, // Staking lock/unlock/yield event (emerald)
    // v2.0: Immortal Self-Verifying Agent
    self_repair_event, // Self-repair action (warm orange)
    immortal_persist, // Persistence checkpoint (deep teal)
    evolution_step, // Evolution generation step (aurora green)
    chain_health_check, // Chain health assessment (sky blue)
    // v2.1: Public Launch + Faucet + Canvas
    faucet_claim, // Faucet $TRI claim event (gold)
    public_launch, // Public session launch event (bright cyan)
    canvas_sync, // Canvas browser sync event (violet)
    faucet_distribution, // Faucet distribution summary (amber)
    // v2.2: Agent OS + Decentralized Network
    decentral_sync, // Multi-node sync event (electric purple)
    node_consensus, // Network consensus vote (lime green)
    network_health, // Network health report (ocean blue)
    agent_os_init, // Agent OS lifecycle event (bright coral)
    // v2.3: Mainnet Genesis + DAO + Swarm
    mainnet_genesis, // Mainnet genesis event (gold)
    dao_vote, // DAO governance vote (royal blue)
    swarm_sync, // Swarm node sync (neon green)
    token_mint, // $TRI token mint (amber)
    // v2.4: Mainnet v1.0 Launch
    mainnet_launch, // Mainnet v1.0 launch (crimson)
    community_onboard, // Community onboarding (lime)
    node_discovery, // Node discovery (cyan)
    governance_exec, // Governance execution (magenta)
    // v2.5: Immortal Agent Swarm v1.0
    swarm_orchestrate, // Swarm orchestration (electric purple)
    swarm_failover, // Swarm failover (red-orange)
    swarm_telemetry, // Swarm telemetry (teal)
    swarm_replication, // Swarm replication (sky blue)
    // v2.6: Swarm Scaling + Live Rewards + DAO Governance
    swarm_scale, // Swarm scale (gold)
    reward_distribute, // Reward distribution (amber)
    dao_governance_live, // DAO governance live (royal blue)
    node_scaling, // Node scaling (spring green)
    // v2.7: Community Nodes v1.0 + Gossip Protocol + DHT 10k+
    community_node, // Community node (lime green)
    gossip_broadcast, // Gossip broadcast (coral)
    dht_lookup, // DHT lookup (dodger blue)
    community_sync, // Community sync (medium orchid)
    // v2.8: DAO Full Governance v1.0
    dao_delegate, // DAO delegation (gold)
    timelock_vote, // Time-locked voting (crimson)
    proposal_exec, // Proposal execution (sea green)
    yield_farming, // Yield farming (dark orange)
    // v2.9: Cross-Chain Bridge v1.0
    cross_chain_bridge, // Cross-chain bridge (deep sky blue)
    atomic_swap, // Atomic swap (orange red)
    state_replicate, // State replication (medium sea green)
    bridge_sync, // Bridge sync (royal blue)
    // v2.10: Trinity DAO Full Governance v1.0 + $TRI Staking Rewards
    dao_full_governance, // DAO full governance (gold)
    tri_staking, // $TRI staking (lime green)
    reward_distribute_v2, // Reward distribution v2 (hot pink)
    staking_validate, // Staking validation (steel blue)
    // v2.11: Swarm 100k + Community 50k (Sharded Gossip + Hierarchical DHT)
    swarm_100k, // Swarm 100k (orange)
    gossip_shard, // Gossip shard (dark turquoise)
    dht_sync, // DHT hierarchical (medium purple)
    community_50k, // Community 50k (spring green)
    // v2.12: Zero-Knowledge Bridge v1.0 (ZK-Proof Verification + Privacy Transfers)
    zk_bridge, // ZK bridge (crimson)
    zk_proof, // ZK proof (electric blue)
    privacy_transfer, // Privacy transfer (indigo)
    cross_chain_sync_v2, // Cross-chain sync (emerald)
    // v2.13: Layer-2 Rollup v1.0 (u8 Upgrade)
    l2_rollup, // L2 rollup (coral)
    optimistic_verify, // Optimistic verify (cyan)
    state_channel, // State channel (orchid)
    batch_compress, // Batch compress (turquoise)
    // v2.14: Dynamic Shard Rebalancing v1.0
    dynamic_shard, // Dynamic shard (gold)
    shard_split, // Shard split (lime)
    shard_merge, // Shard merge (salmon)
    dht_adapt, // DHT adapt (steel blue)
    // v2.15: Swarm 1M + Community 500k
    swarm_million, // Swarm million (orange red)
    community_node_v2, // Community node v2 (medium purple)
    hierarchical_gossip, // Hierarchical gossip (dark cyan)
    geographic_shard, // Geographic shard (indian red)
    // v2.16: ZK-Rollup v2.0
    zk_snark_proof, // ZK-SNARK proof (lime green)
    recursive_proof, // Recursive proof (deep pink)
    l2_scaling, // L2 scaling (dodger blue)
    rollup_batch, // Rollup batch (dark orange)
    // v2.17: Cross-Shard Transactions v1.0
    cross_shard_tx, // Cross-shard transaction (spring green)
    atomic_2pc, // Atomic 2PC (hot pink)
    shard_fee, // Shard fee (steel blue)
    tx_coordinator, // Transaction coordinator (golden rod)
    // v2.18: Network Partition Recovery v1.0
    partition_detect, // Partition detection (coral #FF7F50)
    split_brain, // Split-brain detection (medium orchid #BA55D3)
    auto_heal, // Auto-healing (medium sea green #3CB371)
    partition_tolerance, // Partition tolerance (slate blue #6A5ACD)
    // v2.19: Swarm 10M + Community 5M
    swarm_10m, // Swarm 10M (lime green #32CD32)
    community_5m, // Community 5M (deep pink #FF1493)
    earning_boost, // Earning boost (dodger blue #1E90FF)
    massive_gossip, // Massive gossip (dark orange #FF8C00)
    // v2.20: ZK-Rollup v2.0
    zk_rollup_v2, // ZK-Rollup v2 (medium spring green #00FA9A)
    snark_generate, // SNARK generation (hot pink #FF69B4)
    recursive_compose, // Recursive composition (royal blue #4169E1)
    l2_fee_collect, // L2 fee collection (gold #FFD700)
    // v2.21: Cross-Shard Transactions v1.0
    cross_shard_tx_v2, // Cross-shard tx v2 (cyan #00FFFF)
    atomic_2pc_v2, // Atomic 2PC v2 (magenta #FF00FF)
    shard_fee_v2, // Shard fee v2 (orange red #FF4500)
    inter_shard_sync_v2, // Inter-shard sync v2 (spring green #00FF7F)
    // v2.22: Formal Verification v1.0
    formal_verify_v2, // Formal verify v2 (deep sky blue #00BFFF)
    property_test_v2, // Property test v2 (deep pink #FF1493)
    invariant_check_v2, // Invariant check v2 (lime green #32CD32)
    proof_generate_v2, // Proof generate v2 (orange #FFA500)
    // v2.23: Swarm 100M + Community 50M
    swarm_100m_v2,
    community_50m_v2,
    earning_moonshot_v2,
    gossip_v3_v2,
    // v2.24: Trinity Global Dominance v1.0
    global_dominance_v2,
    world_adoption_v2,
    tri_to_one_v2,
    ecosystem_complete_v2,

    // v2.25: Trinity Eternal v1.0
    ouroboros_evolve_v2,
    infinite_scale_v2,
    universal_reserve_v2,
    eternal_uptime_v2,

    // v2.26: $TRI to $10
    tri_to_ten_v2,
    mass_adoption_v2,
    exchange_listing_v2,
    universal_wallet_v2,

    // v2.27: Trinity Beyond v1.0
    tri_to_hundred_v2,
    universal_adoption_v2,
    exchange_v2_v2,
    global_wallet_v2,
    // v2.28: Swarm 10M + u8 FULL
    swarm_10m_v2,
    community_5m_v2,
    earning_ultimate_v2,
    node_discovery_10m_v2,
    // v2.29: u16 Upgrade canvas types
    swarm_1b_v2,
    community_500m_v2,
    earning_god_mode_v2,
    node_discovery_1b_v2,
    // v2.30: Trinity Neural Network v1.0
    ternary_nn_v2,
    recursive_self_train_v2,
    contribution_reward_v2,
    neural_consensus_v2,
    // v2.31: $TRI to $1000 + Eternal Dominance
    tri_to_1000_v2,
    universal_reserve_v2_v2,
    global_dominance_v2_v2,
    eternal_governance_v2_v2,
    // v2.32: Trinity Beyond v1.0
    trinity_beyond_v2,
    infinite_scale_v2_v2,
    multiverse_dominance_v2,
    eternal_evolution_v2,
    // v3.0: Trinity Absolute v1.0
    trinity_absolute_v3,
    infinite_tri_v3,
    eternal_victory_v3,
    multiverse_complete_v3,
};
var g_chat_messages: [MAX_CHAT_MSGS][512]u8 = undefined; // v3.0: 512 bytes per msg
var g_chat_msg_lens: [MAX_CHAT_MSGS]usize = .{0} ** MAX_CHAT_MSGS;
var g_chat_msg_types: [MAX_CHAT_MSGS]ChatMsgType = .{.ai} ** MAX_CHAT_MSGS;
var g_chat_msg_count: usize = 0;
var g_chat_input: [256]u8 = undefined;
var g_chat_input_len: usize = 0;
var g_backspace_timer: f32 = 0;
var g_chat_scroll_y: f32 = 0;
var g_chat_scroll_target: f32 = 0;

// ── v1.9: Emergent Wave Mode (replaces panel system) ──
const WaveMode = enum {
    idle, // 27 petals logo — main menu
    chat, // Fullscreen chat wave field
    code, // Fullscreen code editor wave field
    tools, // Fullscreen tools wave field
    settings, // Fullscreen settings wave field
    vision, // Fullscreen vision wave field
    voice, // Fullscreen voice wave field
    finder, // Fullscreen finder wave field
    docs, // Fullscreen docs wave field
    mirror, // v2.1: Mirror of Three Worlds dashboard
    depin, // v2.4: DePIN Node control panel
    ralph, // v2.9: Ralph Autonomous Monitor panel

    pub fn getLabel(self: WaveMode) [*:0]const u8 {
        return switch (self) {
            .idle => "TRINITY",
            .chat => "CHAT",
            .code => "CODE",
            .tools => "TOOLS",
            .settings => "SETTINGS",
            .vision => "VISION",
            .voice => "VOICE",
            .finder => "FINDER",
            .docs => "DOCS",
            .mirror => "MIRROR",
            .depin => "DEPIN",
            .ralph => "RALPH",
        };
    }

    pub fn getHue(self: WaveMode) f32 {
        return switch (self) {
            .idle => 45.0, // Gold
            .chat => 150.0, // Green
            .code => 210.0, // Blue
            .tools => 30.0, // Orange
            .settings => 270.0, // Purple
            .vision => 180.0, // Cyan
            .voice => 330.0, // Pink
            .finder => 60.0, // Yellow
            .docs => 120.0, // Green-light
            .mirror => 45.0, // Gold (Trinity)
            .depin => 90.0, // Green-yellow (earning)
            .ralph => 200.0, // Cyan-blue (autonomous)
        };
    }
};
var g_wave_mode: WaveMode = .idle;
var g_wave_transition: f32 = 0; // 0..1 animation progress
var g_wave_mode_prev: WaveMode = .idle;

// v2.4: DePIN Node state
var g_depin_running: bool = false;
var g_depin_docker_ok: bool = false;
var g_depin_earned_tri: f64 = 0.0;
var g_depin_pending_tri: f64 = 0.0;
var g_depin_operations: u64 = 0;
var g_depin_uptime_hours: f32 = 0.0;
var g_depin_shards: u64 = 0;
var g_depin_peers: u32 = 0;
var g_depin_poll_timer: f32 = 0.0;
var g_depin_auto_started: bool = false;
// Docker commands use /bin/sh -c to inherit user PATH

// v2.0: Finder mode — real directory listing cache
const FINDER_MAX_ENTRIES: usize = 32;
var g_finder_names: [FINDER_MAX_ENTRIES][64:0]u8 = undefined;
var g_finder_is_dir: [FINDER_MAX_ENTRIES]bool = [_]bool{false} ** FINDER_MAX_ENTRIES;
var g_finder_count: usize = 0;
var g_finder_last_scan: i64 = 0; // timestamp of last scan
var g_finder_scanned: bool = false;

// v2.1: Mirror live log buffer
const LIVE_LOG_MAX: usize = 16;
var g_live_log_text: [LIVE_LOG_MAX][96:0]u8 = undefined;
var g_live_log_lens: [LIVE_LOG_MAX]usize = [_]usize{0} ** LIVE_LOG_MAX;
var g_live_log_hues: [LIVE_LOG_MAX]f32 = [_]f32{0} ** LIVE_LOG_MAX;
var g_live_log_count: usize = 0;
var g_last_reflection_name: [32:0]u8 = undefined;
var g_last_reflection_len: usize = 0;

// v2.9: Circuit breaker tri-state (RALPH-CANVAS-004)
const CircuitBreakerState = enum {
    closed, // Normal operation (green)
    degraded, // Warning state (yellow)
    cb_open, // Circuit open, halted (red)

    pub fn getColor(self: CircuitBreakerState, a: u8) rl.Color {
        return switch (self) {
            .closed => rl.Color{ .r = 0x00, .g = 0xCC, .b = 0x66, .a = a },
            .degraded => rl.Color{ .r = 0xFF, .g = 0xCC, .b = 0x00, .a = a },
            .cb_open => rl.Color{ .r = 0xFF, .g = 0x33, .b = 0x33, .a = a },
        };
    }

    pub fn getLabel(self: CircuitBreakerState) [*:0]const u8 {
        return switch (self) {
            .closed => "CLOSED",
            .degraded => "DEGRADED",
            .cb_open => "OPEN",
        };
    }
};

// v3.0: Multi-agent Ralph Monitor (RALPH-CANVAS-005)
const MAX_RALPH_AGENTS = 4;

// v8.6: Aceternity Glassmorphism Neon Palette (global)
const GLASS_NEON_PURPLE = rl.Color{ .r = 0x88, .g = 0x44, .b = 0xFF, .a = 255 };
const GLASS_NEON_CYAN = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = 255 };
const GLASS_NEON_MAGENTA = rl.Color{ .r = 0xFF, .g = 0x14, .b = 0x93, .a = 255 };
const GLASS_NEON_LIME = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x66, .a = 255 };
const GLASS_BG_DARK = rl.Color{ .r = 20, .g = 20, .b = 35, .a = 180 };
const GLASS_BG_LIGHT = rl.Color{ .r = 40, .g = 40, .b = 60, .a = 160 };

pub const RalphAgent = struct {
    // Identity
    name: [32:0]u8 = [_:0]u8{0} ** 32,
    name_len: usize = 0,
    branch: [64:0]u8 = [_:0]u8{0} ** 64,
    branch_len: usize = 0,
    // Metrics (from status_report.json + circuit_breaker_state)
    loop: usize = 0,
    total_calls: usize = 0,
    is_healthy: bool = true,
    goal: [128:0]u8 = [_:0]u8{0} ** 128,
    goal_len: usize = 0,
    last_action: [64:0]u8 = [_:0]u8{0} ** 64,
    last_action_len: usize = 0,
    log_ptr: usize = 0,
    // Per-agent state
    cb_state: CircuitBreakerState = .closed,
    running: bool = false,
    reachable: bool = false,
    // Ralph loop logs (ralph.log — left pane)
    logs: [30][128:0]u8 = undefined,
    log_count: usize = 0,
    // Live Claude Code output (from latest claude_output_*.log — right-top pane)
    live_result: [4096:0]u8 = [_:0]u8{0} ** 4096,
    live_result_len: usize = 0,
    live_num_turns: usize = 0,
    live_duration_ms: usize = 0,
    live_cost_usd: [16:0]u8 = [_:0]u8{0} ** 16, // formatted as string
    live_cost_len: usize = 0,
    live_is_error: bool = false,
    live_session_id: [40:0]u8 = [_:0]u8{0} ** 40,
    live_session_len: usize = 0,
    // Status monitor data (status.json — right-bottom pane)
    loop_count_status: usize = 0, // from status.json loop_count
    calls_this_hour: usize = 0, // calls_made_this_hour
    max_calls_hour: usize = 100, // max_calls_per_hour
    status_text: [32:0]u8 = [_:0]u8{0} ** 32, // "running", "idle", etc
    status_text_len: usize = 0,
    next_reset: [16:0]u8 = [_:0]u8{0} ** 16,
    next_reset_len: usize = 0,
    // Progress tracking from status_report.json
    progress_status: [32:0]u8 = [_:0]u8{0} ** 32, // "completed", "in_progress", etc
    progress_status_len: usize = 0,
    recent_commits_count: usize = 0,
    // Data freshness tracking (file modification times as epoch seconds)
    log_mtime: i64 = 0, // ralph.log last modified
    status_mtime: i64 = 0, // status.json last modified
    live_mtime: i64 = 0, // latest claude_output_*.log modified
    data_age_seconds: i64 = 0, // age of newest data source
    rate_limited: bool = false, // detected from live_result
    is_executing: bool = false, // detected from status.json last_action
    // Todo list from TodoWrite (parsed from claude_output log tail)
    todo_items: [10][96:0]u8 = [_][96:0]u8{[_:0]u8{0} ** 96} ** 10,
    todo_statuses: [10]u8 = [_]u8{0} ** 10, // 0=none, 1=pending, 2=in_progress, 3=completed
    todo_count: usize = 0,
    // Per-agent poll timer (staggered)
    update_timer: f32 = 0,
    // Unified chat dialog messages (chronologically sorted)
    chat_msgs: [50]ChatMsg = [_]ChatMsg{ChatMsg{}} ** 50,
    chat_count: usize = 0,
    chat_built_log_mt: i64 = 0,
    chat_built_live_mt: i64 = 0,
};

// ── Unified Chat Message for merged agent dialog ──
const ChatSender = enum { loop, claude };
const ChatMsgKind = enum { log_line, claude_result, task_list, meta_info };

const ChatMsg = struct {
    sender: ChatSender = .loop,
    kind: ChatMsgKind = .log_line,
    timestamp: i64 = 0,
    text: [256:0]u8 = [_:0]u8{0} ** 256,
    text_len: usize = 0,
    result_offset: usize = 0,
    result_len: usize = 0,
    todo_count: usize = 0,
    tag_r: u8 = 0xBB,
    tag_g: u8 = 0xBB,
    tag_b: u8 = 0xBB,
    show_full: bool = false,
};

var g_ralph_agents: [MAX_RALPH_AGENTS]RalphAgent = [_]RalphAgent{RalphAgent{}} ** MAX_RALPH_AGENTS;

var g_ralph_agent_count: usize = 0;
var g_ralph_active_tab: usize = 0;
var g_ralph_prev_tab: usize = 0;
var g_ralph_initialized: bool = false;
// Unified chat scroll state
var g_ralph_chat_scroll_y: f32 = 0;
var g_ralph_chat_scroll_target: f32 = 0;
var g_ralph_prev_chat_count: usize = 0;
var g_ralph_prev_result_len: usize = 0;

// ── v8.1: Collapsible section state ──
const MAX_SECTIONS_PER_MSG = 16;
var g_ralph_section_collapsed: [MAX_RALPH_AGENTS][50][MAX_SECTIONS_PER_MSG]bool =
    [_][50][MAX_SECTIONS_PER_MSG]bool{
        [_][MAX_SECTIONS_PER_MSG]bool{[_]bool{false} ** MAX_SECTIONS_PER_MSG} ** 50,
    } ** MAX_RALPH_AGENTS;
var g_ralph_section_anim: [MAX_RALPH_AGENTS][50][MAX_SECTIONS_PER_MSG]f32 =
    [_][50][MAX_SECTIONS_PER_MSG]f32{
        [_][MAX_SECTIONS_PER_MSG]f32{[_]f32{1.0} ** MAX_SECTIONS_PER_MSG} ** 50,
    } ** MAX_RALPH_AGENTS;
var g_ralph_msg_prev_rlen: [MAX_RALPH_AGENTS][50]usize =
    [_][50]usize{[_]usize{0} ** 50} ** MAX_RALPH_AGENTS;

fn setAgentIdentity(agent: *RalphAgent, name: []const u8, branch: []const u8) void {
    const nl = @min(name.len, 31);
    @memcpy(agent.name[0..nl], name[0..nl]);
    agent.name_len = nl;
    const bl = @min(branch.len, 63);
    @memcpy(agent.branch[0..bl], branch[0..bl]);
    agent.branch_len = bl;
}

// Dynamic worktree paths (discovered at runtime from .git/worktrees/)
var g_ralph_worktree_paths: [MAX_RALPH_AGENTS][256]u8 = undefined;
var g_ralph_worktree_path_lens: [MAX_RALPH_AGENTS]usize = [_]usize{0} ** MAX_RALPH_AGENTS;

fn getWorktreePath(ai: usize) []const u8 {
    if (ai >= g_ralph_agent_count) return "";
    return g_ralph_worktree_paths[ai][0..g_ralph_worktree_path_lens[ai]];
}

// ═══ Ralph Process Control (tmux commands) ═══
const RalphCmd = enum { none, start, stop, restart };
var g_ralph_pending_cmd: RalphCmd = .none;
var g_ralph_tmux_session: [64]u8 = [_]u8{0} ** 64;
var g_ralph_tmux_session_len: usize = 0;

// v8.1.1: Hybrid mode — track external ralph_loop.sh process
var g_ralph_loop_pid: i32 = 0;
var g_ralph_tmux_loop_running: bool = false;
var g_ralph_last_pid_check: f64 = 0;

/// Discover the ralph tmux session name (ralph-XXXXXXXXXX) — picks newest (last sorted)
fn ralphDiscoverTmuxSession() void {
    const allocator = std.heap.page_allocator;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", "tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^ralph-' | sort -r | head -1" },
    }) catch return;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const out = std.mem.trimRight(u8, result.stdout, "\n\r \t");
    if (out.len > 0 and out.len < 64) {
        @memcpy(g_ralph_tmux_session[0..out.len], out);
        g_ralph_tmux_session_len = out.len;
        std.debug.print("[RALPH] discovered tmux session: {s}\n", .{g_ralph_tmux_session[0..out.len]});
    } else {
        std.debug.print("[RALPH] no tmux session found\n", .{});
    }
}

/// Find PID of external ralph_loop.sh process (v8.1.1 hybrid mode)
fn ralphFindLoopPid() i32 {
    const allocator = std.heap.page_allocator;
    // pgrep returns multiple PIDs, take the first one (newest)
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", "pgrep -f 'ralph_loop.sh' 2>/dev/null | head -1" },
    }) catch return 0;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const out = std.mem.trimRight(u8, result.stdout, "\n\r \t");
    if (out.len > 0) {
        const pid = std.fmt.parseInt(i32, out, 10) catch 0;
        if (pid > 0) {
            std.debug.print("[RALPH] found external loop PID: {}\n", .{pid});
            return pid;
        }
    }
    return 0;
}

/// Check if ralph is running INSIDE tmux pane (v8.1.1 hybrid mode)
fn ralphCheckTmuxLoop() bool {
    if (g_ralph_tmux_session_len == 0) return false;
    const sess = g_ralph_tmux_session[0..g_ralph_tmux_session_len];
    const allocator = std.heap.page_allocator;

    // Get pane PID for pane 1.1
    var buf: [128]u8 = undefined;
    const cmd = std.fmt.bufPrint(&buf, "tmux list-panes -t '{s}:1.1' -F '{{pane_pid}}' 2>/dev/null", .{sess}) catch return false;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", cmd },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const pane_pid_str = std.mem.trimRight(u8, result.stdout, "\n\r \t");
    if (pane_pid_str.len == 0) return false;

    const pane_pid = std.fmt.parseInt(i32, pane_pid_str, 10) catch return false;
    if (pane_pid <= 0) return false;

    // Check if that process has 'ralph' in its command line
    var buf2: [256]u8 = undefined;
    const cmd2 = std.fmt.bufPrint(&buf2, "ps -p {} -o command= 2>/dev/null | grep -q ralph", .{pane_pid}) catch return false;
    const result2 = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", cmd2 },
    }) catch return false;
    defer allocator.free(result2.stdout);
    defer allocator.free(result2.stderr);

    const running = (switch (result2.term) {
        .Exited => |code| code,
        else => @as(u32, 1),
    }) == 0;
    if (running) {
        std.debug.print("[RALPH] tmux pane has ralph running (PID {})\n", .{pane_pid});
    }
    return running;
}

/// Update ralph loop detection state (call periodically)
fn ralphUpdateLoopState() void {
    const now = rl.GetTime();
    // Check every 2 seconds
    if (now - g_ralph_last_pid_check < 2.0) return;
    g_ralph_last_pid_check = now;

    g_ralph_loop_pid = ralphFindLoopPid();
    g_ralph_tmux_loop_running = ralphCheckTmuxLoop();
}

/// Quick check if any ralph_loop.sh process is actually running (v8.1.1 fix)
/// Used to override status.json when processes are killed but file not updated
fn ralphProcessRunning() bool {
    const allocator = std.heap.page_allocator;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", "pgrep -f 'ralph_loop.sh' 2>/dev/null | head -1" },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const out = std.mem.trimRight(u8, result.stdout, "\n\r \t");
    return out.len > 0;
}

/// Execute pending ralph command (v8.1.1: hybrid mode — PID signals OR tmux)
fn ralphExecPendingCmd() void {
    const cmd = g_ralph_pending_cmd;
    if (cmd == .none) return;
    std.debug.print("[RALPH] executing cmd: {s}\n", .{if (cmd == .start) "START" else if (cmd == .stop) "STOP" else if (cmd == .restart) "RESTART" else "NONE"});
    g_ralph_pending_cmd = .none;

    // Update detection state
    ralphUpdateLoopState();

    const allocator = std.heap.page_allocator;

    // Hybrid mode: external process takes priority
    if (g_ralph_loop_pid > 0) {
        std.debug.print("[RALPH] STOP: killing external process (PID {})\n", .{g_ralph_loop_pid});
        switch (cmd) {
            .stop => {
                // v8.1.1 fix: Kill monitor, loop processes, AND all their children
                // First kill children, then parents (to avoid orphans)
                const sh_cmd = "pgrep -f 'ralph_loop.sh' 2>/dev/null | xargs -r pkill -9 -P 2>/dev/null; pkill -9 -f 'ralph_monitor.sh' 2>/dev/null; pkill -9 -f 'ralph_loop.sh' 2>/dev/null";
                _ = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &[_][]const u8{ "/bin/sh", "-c", sh_cmd },
                }) catch {};
            },
            .start => {
                // Already running, just log
                std.debug.print("[RALPH] START: already running (PID {})\n", .{g_ralph_loop_pid});
            },
            .restart => {
                // v8.1.1 fix: Kill children first, then parents (same as STOP)
                const cmd1 = "pgrep -f 'ralph_loop.sh' 2>/dev/null | xargs -r pkill -9 -P 2>/dev/null; pkill -9 -f 'ralph_monitor.sh' 2>/dev/null; pkill -9 -f 'ralph_loop.sh' 2>/dev/null; sleep 1";
                _ = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &[_][]const u8{ "/bin/sh", "-c", cmd1 },
                }) catch {};
                std.debug.print("[RALPH] RESTART: killed processes, will restart\n", .{});
            },
            .none => {},
        }
        return;
    }

    // Fallback: tmux mode (if tmux loop is running or session exists)
    if (g_ralph_tmux_loop_running or g_ralph_tmux_session_len > 0) {
        std.debug.print("[RALPH] using tmux mode\n", .{});
        if (g_ralph_tmux_session_len == 0) ralphDiscoverTmuxSession();
        if (g_ralph_tmux_session_len == 0) return; // no tmux session

        const sess = g_ralph_tmux_session[0..g_ralph_tmux_session_len];

        switch (cmd) {
            .stop => {
                var buf: [128]u8 = undefined;
                const sh_cmd = std.fmt.bufPrint(&buf, "tmux send-keys -t '{s}:1.1' C-c 2>/dev/null", .{sess}) catch return;
                _ = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &[_][]const u8{ "/bin/sh", "-c", buf[0..sh_cmd.len] },
                }) catch {};
            },
            .start => {
                var buf: [128]u8 = undefined;
                const sh_cmd = std.fmt.bufPrint(&buf, "tmux send-keys -t '{s}:1.1' 'ralph' Enter 2>/dev/null", .{sess}) catch return;
                _ = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &[_][]const u8{ "/bin/sh", "-c", buf[0..sh_cmd.len] },
                }) catch {};
            },
            .restart => {
                var buf1: [128]u8 = undefined;
                const cmd1 = std.fmt.bufPrint(&buf1, "tmux send-keys -t '{s}:1.1' C-c 2>/dev/null; sleep 1; tmux send-keys -t '{s}:1.1' 'ralph' Enter 2>/dev/null", .{ sess, sess }) catch return;
                _ = std.process.Child.run(.{
                    .allocator = allocator,
                    .argv = &[_][]const u8{ "/bin/sh", "-c", buf1[0..cmd1.len] },
                }) catch {};
            },
            .none => {},
        }
        return;
    }

    std.debug.print("[RALPH] no ralph loop found to control\n", .{});
}

/// Read a git HEAD file and extract the branch name (strip "ref: refs/heads/")
fn readGitBranch(head_path: [:0]const u8, out: []u8) usize {
    const file = std.fs.openFileAbsolute(head_path, .{}) catch return 0;
    defer file.close();
    var buf: [256]u8 = undefined;
    const n = file.readAll(&buf) catch return 0;
    if (n == 0) return 0;
    // Strip trailing newline/whitespace
    var end: usize = n;
    while (end > 0 and (buf[end - 1] == '\n' or buf[end - 1] == '\r' or buf[end - 1] == ' ')) end -= 1;
    const line = buf[0..end];
    const prefix = "ref: refs/heads/";
    const branch = if (std.mem.startsWith(u8, line, prefix)) line[prefix.len..] else line;
    const len = @min(branch.len, out.len);
    @memcpy(out[0..len], branch[0..len]);
    return len;
}

fn initRalphAgents() void {
    if (g_ralph_initialized) return;
    g_ralph_initialized = true;

    // Zero all paths
    for (&g_ralph_worktree_paths) |*p| @memset(p, 0);

    // Agent 0 = main repo (cwd)
    const main_path = "/Users/playra/trinity";
    const main_len = main_path.len;
    @memcpy(g_ralph_worktree_paths[0][0..main_len], main_path);
    g_ralph_worktree_path_lens[0] = main_len;

    // Read main repo branch from .git/HEAD
    var branch_buf: [64]u8 = undefined;
    @memset(&branch_buf, 0);
    const branch_len = readGitBranch("/Users/playra/trinity/.git/HEAD", &branch_buf);
    const main_branch = if (branch_len > 0) branch_buf[0..branch_len] else "main";
    setAgentIdentity(&g_ralph_agents[0], "trinity", main_branch);
    g_ralph_agents[0].update_timer = 0.0;
    g_ralph_agent_count = 1;

    // Discover additional worktrees from .git/worktrees/
    const wt_dir = std.fs.openDirAbsolute("/Users/playra/trinity/.git/worktrees", .{ .iterate = true }) catch {
        return; // No worktrees dir — single repo mode
    };
    // Need mutable for iteration
    var wt_dir_m = wt_dir;
    defer wt_dir_m.close();
    var iter = wt_dir_m.iterate();
    while (iter.next() catch null) |entry| {
        if (g_ralph_agent_count >= MAX_RALPH_AGENTS) break;
        if (entry.kind != .directory) continue;

        const ai = g_ralph_agent_count;
        var gitdir_path_buf: [256]u8 = undefined;
        @memset(&gitdir_path_buf, 0);
        const gitdir_path = std.fmt.bufPrint(&gitdir_path_buf, "/Users/playra/trinity/.git/worktrees/{s}/gitdir", .{entry.name}) catch continue;

        // Read gitdir to get worktree path (contains "<worktree>/.git\n")
        const gf = std.fs.openFileAbsolute(gitdir_path_buf[0..gitdir_path.len :0], .{}) catch continue;
        defer gf.close();
        var gd_buf: [256]u8 = undefined;
        const gd_n = gf.readAll(&gd_buf) catch continue;
        if (gd_n < 5) continue;

        // Strip trailing whitespace and "/.git" suffix
        var gd_end: usize = gd_n;
        while (gd_end > 0 and (gd_buf[gd_end - 1] == '\n' or gd_buf[gd_end - 1] == '\r' or gd_buf[gd_end - 1] == ' ')) gd_end -= 1;
        const gd_line = gd_buf[0..gd_end];
        const wt_path = if (std.mem.endsWith(u8, gd_line, "/.git")) gd_line[0 .. gd_line.len - 5] else gd_line;
        if (wt_path.len == 0 or wt_path.len >= 256) continue;

        @memcpy(g_ralph_worktree_paths[ai][0..wt_path.len], wt_path);
        g_ralph_worktree_path_lens[ai] = wt_path.len;

        // Read branch from .git/worktrees/<name>/HEAD
        var head_path_buf: [256]u8 = undefined;
        @memset(&head_path_buf, 0);
        const head_path = std.fmt.bufPrint(&head_path_buf, "/Users/playra/trinity/.git/worktrees/{s}/HEAD", .{entry.name}) catch continue;

        @memset(&branch_buf, 0);
        const wt_branch_len = readGitBranch(head_path_buf[0..head_path.len :0], &branch_buf);
        const wt_branch = if (wt_branch_len > 0) branch_buf[0..wt_branch_len] else entry.name;

        setAgentIdentity(&g_ralph_agents[ai], entry.name, wt_branch);
        g_ralph_agents[ai].update_timer = @as(f32, @floatFromInt(ai)) * 0.5; // Stagger polls
        g_ralph_agent_count += 1;
    }

    // Discover ralph tmux session for process control
    ralphDiscoverTmuxSession();
}

/// Desktop-only: Read .ralph/ files directly from worktree filesystem
fn pollRalphAgentDesktop(ai: usize) void {
    if (ai >= g_ralph_agent_count) return;
    const agent = &g_ralph_agents[ai];
    const base_path = getWorktreePath(ai);

    std.debug.print("[POLL ai={d}] base_path={s}\n", .{ ai, base_path });

    var path_buf: [256]u8 = undefined;
    @memset(&path_buf, 0);

    // Read status_report.json
    {
        const sr_path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/status_report.json", .{base_path}) catch return;
        const file = std.fs.openFileAbsolute(path_buf[0..sr_path.len :0], .{}) catch {
            std.debug.print("[POLL ai={d}] status_report.json NOT FOUND - unreachable\n", .{ai});
            agent.reachable = false;
            return;
        };
        defer file.close();
        agent.reachable = true;

        var read_buf: [4096]u8 = undefined;
        const bytes_read = file.readAll(&read_buf) catch 0;
        if (bytes_read < 10) return;
        const json = read_buf[0..bytes_read];

        // Parse circuit_breaker.state
        if (std.mem.indexOf(u8, json, "\"state\":")) |idx| {
            const after = json[@min(idx + 9, json.len)..];
            if (std.mem.indexOf(u8, after, "\"")) |q1| {
                const val_start = q1 + 1;
                if (std.mem.indexOfScalar(u8, after[val_start..], '"')) |q2| {
                    const val = after[val_start .. val_start + q2];
                    if (std.mem.eql(u8, val, "CLOSED")) {
                        agent.cb_state = .closed;
                        agent.is_healthy = true;
                    } else if (std.mem.eql(u8, val, "OPEN")) {
                        agent.cb_state = .cb_open;
                        agent.is_healthy = false;
                    } else {
                        agent.cb_state = .degraded;
                        agent.is_healthy = false;
                    }
                }
            }
        }

        // Parse circuit_breaker.loop
        if (std.mem.indexOf(u8, json, "\"loop\":")) |idx| {
            var start = idx + 7;
            while (start < json.len and (json[start] == ' ' or json[start] == '\t' or json[start] == '\n' or json[start] == '\r')) start += 1;
            var end = start;
            while (end < json.len and json[end] >= '0' and json[end] <= '9') end += 1;
            if (end > start) {
                agent.loop = std.fmt.parseInt(usize, json[start..end], 10) catch agent.loop;
            }
        }

        // Parse session.call_count as total_calls
        if (std.mem.indexOf(u8, json, "\"call_count\":")) |idx| {
            var start = idx + 13;
            while (start < json.len and (json[start] == ' ' or json[start] == '\t' or json[start] == '\n' or json[start] == '\r')) start += 1;
            var end = start;
            while (end < json.len and json[end] >= '0' and json[end] <= '9') end += 1;
            if (end > start) {
                agent.total_calls = std.fmt.parseInt(usize, json[start..end], 10) catch agent.total_calls;
            }
        }

        // Parse active_task as goal
        if (std.mem.indexOf(u8, json, "\"active_task\":")) |idx| {
            const after = json[@min(idx + 14, json.len)..];
            if (std.mem.indexOf(u8, after, "\"")) |q1| {
                const val_start = q1 + 1;
                if (std.mem.indexOfScalar(u8, after[val_start..], '"')) |q2| {
                    const val = after[val_start .. val_start + q2];
                    const len = @min(val.len, 127);
                    @memcpy(agent.goal[0..len], val[0..len]);
                    agent.goal[len] = 0;
                    agent.goal_len = len;
                }
            }
        }

        // Parse progress.status
        if (std.mem.indexOf(u8, json, "\"status\":")) |idx| {
            const after = json[@min(idx + 9, json.len)..];
            if (std.mem.indexOf(u8, after, "\"")) |q1| {
                const val_start = q1 + 1;
                if (std.mem.indexOfScalar(u8, after[val_start..], '"')) |q2| {
                    const val = after[val_start .. val_start + q2];
                    const len = @min(val.len, 31);
                    @memcpy(agent.progress_status[0..len], val[0..len]);
                    agent.progress_status[len] = 0;
                    agent.progress_status_len = len;
                }
            }
        }

        // Count recent_commits
        {
            var count: usize = 0;
            if (std.mem.indexOf(u8, json, "\"recent_commits\":")) |idx| {
                const after = json[@min(idx + 17, json.len)..];
                for (after) |ch| {
                    if (ch == '"') count += 1;
                    if (ch == ']') break;
                }
                agent.recent_commits_count = count / 2;
            }
        }

        agent.running = (agent.loop > 0);
        std.debug.print("[POLL ai={d}] status_report: cb={s} loop={d} calls={d} goal_len={d}\n", .{
            ai,
            if (agent.cb_state == .closed) "CLOSED" else if (agent.cb_state == .cb_open) "OPEN" else "DEGRADED",
            agent.loop,
            agent.total_calls,
            agent.goal_len,
        });
    }

    // Read .ralph/internal/.circuit_breaker_state for current_loop (more accurate)
    {
        @memset(&path_buf, 0);
        const cb_path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/internal/.circuit_breaker_state", .{base_path}) catch "";
        if (cb_path.len > 0) {
            if (std.fs.openFileAbsolute(path_buf[0..cb_path.len :0], .{})) |f| {
                defer f.close();
                var cb_buf: [1024]u8 = undefined;
                const bytes = f.readAll(&cb_buf) catch 0;
                if (bytes > 10) {
                    const cb_json = cb_buf[0..bytes];
                    if (std.mem.indexOf(u8, cb_json, "\"current_loop\":")) |idx| {
                        var start = idx + 15;
                        while (start < cb_json.len and (cb_json[start] == ' ' or cb_json[start] == '\t' or cb_json[start] == '\n' or cb_json[start] == '\r')) start += 1;
                        var end = start;
                        while (end < cb_json.len and cb_json[end] >= '0' and cb_json[end] <= '9') end += 1;
                        if (end > start) {
                            agent.loop = std.fmt.parseInt(usize, cb_json[start..end], 10) catch agent.loop;
                            agent.running = true;
                        }
                    }
                }
            } else |_| {}
        }
    }

    // Read last N lines of .ralph/logs/ralph.log (Left pane: Ralph Loop output)
    {
        @memset(&path_buf, 0);
        const log_path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/logs/ralph.log", .{base_path}) catch return;
        const file = std.fs.openFileAbsolute(path_buf[0..log_path.len :0], .{}) catch return;
        defer file.close();

        // Track file modification time
        if (file.stat()) |st| {
            agent.log_mtime = @intCast(@divFloor(st.mtime, std.time.ns_per_s));
            std.debug.print("[POLL ai={d}] ralph.log mtime={d}\n", .{ ai, agent.log_mtime });
        } else |_| {}

        const file_size = file.getEndPos() catch 0;
        if (file_size > 8192) {
            file.seekTo(file_size - 8192) catch {};
        }

        var log_buf: [8192]u8 = undefined;
        const bytes = file.readAll(&log_buf) catch 0;
        if (bytes == 0) return;
        const content = log_buf[0..bytes];

        // Find line boundaries, keep last 30
        var line_starts: [31]usize = undefined;
        var line_count: usize = 0;
        line_starts[0] = 0;
        line_count = 1;
        for (content, 0..) |c, ci| {
            if (c == '\n' and ci + 1 < content.len) {
                if (line_count < 31) {
                    line_starts[line_count] = ci + 1;
                    line_count += 1;
                } else {
                    for (0..30) |si| {
                        line_starts[si] = line_starts[si + 1];
                    }
                    line_starts[30] = ci + 1;
                }
            }
        }

        const first_line = if (line_count > 30) line_count - 30 else 0;
        var li: usize = 0;
        var si: usize = first_line;
        while (si < line_count and li < 30) {
            const start = line_starts[si];
            const end_pos = if (si + 1 < line_count) line_starts[si + 1] -| 1 else content.len;
            const end = if (end_pos > start and content[end_pos - 1] == '\r') end_pos - 1 else end_pos;
            if (end > start) {
                const line_data = content[start..end];
                const len = @min(line_data.len, 127);
                @memset(&agent.logs[li], 0);
                @memcpy(agent.logs[li][0..len], line_data[0..len]);
            } else {
                agent.logs[li][0] = 0;
            }
            si += 1;
            li += 1;
        }
        agent.log_count = li;
    }

    // Read latest .ralph/logs/claude_output_*.log (Right-Top: Claude Code result)
    // Find latest non-stream log by scanning directory for newest timestamp in filename
    {
        @memset(&path_buf, 0);
        const logs_dir_path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/logs", .{base_path}) catch return;
        if (std.fs.openDirAbsolute(logs_dir_path[0..logs_dir_path.len], .{})) |dir_handle| {
            var dir = dir_handle;
            defer dir.close();
            // Find newest and second-newest claude_output_*.log (not _stream.log)
            var newest_name: [64]u8 = undefined;
            var newest_len: usize = 0;
            var second_name: [64]u8 = undefined;
            var second_len: usize = 0;
            var iter = dir.iterate();
            while (iter.next() catch null) |entry| {
                if (entry.kind != .file) continue;
                const name = entry.name;
                if (!std.mem.startsWith(u8, name, "claude_output_")) continue;
                if (std.mem.endsWith(u8, name, "_stream.log")) continue;
                if (!std.mem.endsWith(u8, name, ".log")) continue;
                // Lexicographic compare: later timestamp = larger string
                if (name.len <= 63 and (newest_len == 0 or std.mem.order(u8, name[0..name.len], newest_name[0..newest_len]) == .gt)) {
                    // Demote current newest to second
                    if (newest_len > 0) {
                        @memcpy(second_name[0..newest_len], newest_name[0..newest_len]);
                        second_len = newest_len;
                    }
                    @memcpy(newest_name[0..name.len], name[0..name.len]);
                    newest_len = name.len;
                } else if (name.len <= 63 and (second_len == 0 or std.mem.order(u8, name[0..name.len], second_name[0..second_len]) == .gt)) {
                    @memcpy(second_name[0..name.len], name[0..name.len]);
                    second_len = name.len;
                }
            }
            // Try newest file, fall back to second-newest if newest is empty
            const candidates = [_]struct { name: []const u8 }{
                .{ .name = if (newest_len > 0) newest_name[0..newest_len] else "" },
                .{ .name = if (second_len > 0) second_name[0..second_len] else "" },
            };
            var parsed_output = false;
            for (&candidates) |cand| {
                if (cand.name.len == 0 or parsed_output) continue;
                var full_path: [320]u8 = undefined;
                @memset(&full_path, 0);
                const fp = std.fmt.bufPrint(&full_path, "{s}/.ralph/logs/{s}", .{ base_path, cand.name }) catch "";
                if (fp.len == 0) continue;
                const f = std.fs.openFileAbsolute(full_path[0..fp.len :0], .{}) catch continue;
                defer f.close();
                // Track mtime (from newest candidate only)
                if (!parsed_output) {
                    if (f.stat()) |st| {
                        agent.live_mtime = @intCast(@divFloor(st.mtime, std.time.ns_per_s));
                    } else |_| {}
                }
                // Read last 4KB (the JSON result is at end of file)
                const fsize = f.getEndPos() catch 0;
                if (fsize > 4096) f.seekTo(fsize - 4096) catch {};
                var out_buf: [4096]u8 = undefined;
                const bytes = f.readAll(&out_buf) catch 0;
                if (bytes <= 10) continue; // Empty — try next candidate
                parsed_output = true;
                const json = out_buf[0..bytes];

                // Parse "result":"..." — extract first 500 chars
                if (std.mem.indexOf(u8, json, "\"result\":\"")) |idx| {
                    const vs = idx + 10;
                    // Find closing quote (handle escaped quotes)
                    var end_q: usize = vs;
                    while (end_q < json.len) {
                        if (json[end_q] == '\\' and end_q + 1 < json.len) {
                            end_q += 2;
                            continue;
                        }
                        if (json[end_q] == '"') break;
                        end_q += 1;
                    }
                    const val = json[vs..end_q];
                    const rlen = @min(val.len, 4095);
                    @memset(&agent.live_result, 0);
                    // Copy with ASCII sanitization (replace non-ASCII with -)
                    for (0..rlen) |ci| {
                        agent.live_result[ci] = if (val[ci] >= 0x80) '-' else val[ci];
                    }
                    agent.live_result_len = rlen;
                }

                // Parse "is_error":true/false
                agent.live_is_error = std.mem.indexOf(u8, json, "\"is_error\":true") != null;

                // Parse "num_turns":N
                if (std.mem.indexOf(u8, json, "\"num_turns\":")) |idx| {
                    var start = idx + 12;
                    while (start < json.len and json[start] == ' ') start += 1;
                    var end_n: usize = start;
                    while (end_n < json.len and json[end_n] >= '0' and json[end_n] <= '9') end_n += 1;
                    if (end_n > start) agent.live_num_turns = std.fmt.parseInt(usize, json[start..end_n], 10) catch 0;
                }

                // Parse "duration_ms":N
                if (std.mem.indexOf(u8, json, "\"duration_ms\":")) |idx| {
                    var start = idx + 14;
                    while (start < json.len and json[start] == ' ') start += 1;
                    var end_n: usize = start;
                    while (end_n < json.len and json[end_n] >= '0' and json[end_n] <= '9') end_n += 1;
                    if (end_n > start) agent.live_duration_ms = std.fmt.parseInt(usize, json[start..end_n], 10) catch 0;
                }

                // Parse "total_cost_usd":N.NN
                if (std.mem.indexOf(u8, json, "\"total_cost_usd\":")) |idx| {
                    var start = idx + 17;
                    while (start < json.len and json[start] == ' ') start += 1;
                    var end_n: usize = start;
                    while (end_n < json.len and (json[end_n] >= '0' and json[end_n] <= '9' or json[end_n] == '.')) end_n += 1;
                    if (end_n > start) {
                        const val = json[start..end_n];
                        const clen = @min(val.len, 15);
                        @memset(&agent.live_cost_usd, 0);
                        @memcpy(agent.live_cost_usd[0..clen], val[0..clen]);
                        agent.live_cost_len = clen;
                    }
                }

                // Parse TodoWrite from log tail (last 16KB for last "todos":[)
                {
                    agent.todo_count = 0;
                    for (&agent.todo_items) |*item| @memset(item, 0);
                    @memset(&agent.todo_statuses, 0);
                    f.seekTo(if (fsize > 16384) fsize - 16384 else 0) catch {};
                    var todo_buf: [16384]u8 = undefined;
                    const tbytes = f.readAll(&todo_buf) catch 0;
                    if (tbytes > 20) {
                        const tdata = todo_buf[0..tbytes];
                        // Find LAST occurrence of "todos":[{
                        var last_todos_pos: ?usize = null;
                        var search_pos: usize = 0;
                        while (search_pos < tdata.len) {
                            if (std.mem.indexOf(u8, tdata[search_pos..], "\"todos\":[{")) |found| {
                                last_todos_pos = search_pos + found;
                                search_pos = search_pos + found + 10;
                            } else break;
                        }
                        if (last_todos_pos) |tp| {
                            var tpos = tp + 9; // skip "todos":[
                            while (tpos < tdata.len and agent.todo_count < 10) {
                                // Find "content":"
                                if (std.mem.indexOf(u8, tdata[tpos..], "\"content\":\"")) |ci| {
                                    const cs = tpos + ci + 11;
                                    if (cs < tdata.len) {
                                        if (std.mem.indexOfScalar(u8, tdata[cs..@min(cs + 96, tdata.len)], '"')) |ce| {
                                            const clen = @min(ce, 95);
                                            @memcpy(agent.todo_items[agent.todo_count][0..clen], tdata[cs .. cs + clen]);
                                        }
                                    }
                                    // Find "status":"
                                    const sbase = tpos + ci;
                                    if (std.mem.indexOf(u8, tdata[sbase..@min(sbase + 200, tdata.len)], "\"status\":\"")) |si| {
                                        const ss = sbase + si + 10;
                                        if (ss < tdata.len) {
                                            if (std.mem.indexOfScalar(u8, tdata[ss..@min(ss + 20, tdata.len)], '"')) |se| {
                                                const status = tdata[ss .. ss + se];
                                                if (std.mem.eql(u8, status, "completed")) {
                                                    agent.todo_statuses[agent.todo_count] = 3;
                                                } else if (std.mem.eql(u8, status, "in_progress")) {
                                                    agent.todo_statuses[agent.todo_count] = 2;
                                                } else {
                                                    agent.todo_statuses[agent.todo_count] = 1;
                                                }
                                            }
                                        }
                                    }
                                    agent.todo_count += 1;
                                    tpos = tpos + ci + 20;
                                } else break;
                            }
                        }
                    }
                }
            }
            std.debug.print("[POLL ai={d}] claude_output: parsed={} newest_len={d} second_len={d} result_len={d} is_error={}\n", .{
                ai, parsed_output, newest_len, second_len, agent.live_result_len, agent.live_is_error,
            });
            // Always read live.log — if it's NEWER than claude_output, use streaming content
            {
                var live_path: [320]u8 = undefined;
                @memset(&live_path, 0);
                const lp = std.fmt.bufPrint(&live_path, "{s}/.ralph/logs/live.log", .{base_path}) catch "";
                if (lp.len > 0) {
                    if (std.fs.openFileAbsolute(live_path[0..lp.len :0], .{})) |lf| {
                        defer lf.close();
                        var live_log_mtime: i64 = 0;
                        if (lf.stat()) |st| {
                            live_log_mtime = @intCast(@divFloor(st.mtime, std.time.ns_per_s));
                        } else |_| {}
                        // Read last 8KB of live.log (streaming text, not JSON)
                        const fsize = lf.getEndPos() catch 0;
                        if (fsize > 8192) lf.seekTo(fsize - 8192) catch {};
                        var lb: [8192]u8 = undefined;
                        const lb_n = lf.readAll(&lb) catch 0;
                        // Always use live.log if it has any content — eliminates stale data during loop transitions
                        if (lb_n > 10) {
                            const raw = lb[0..lb_n];
                            var start: usize = 0;
                            if (fsize > 8192) {
                                if (std.mem.indexOfScalar(u8, raw, '\n')) |nl| {
                                    start = nl + 1;
                                }
                            }
                            if (start < raw.len) {
                                const text = raw[start..];
                                var wi: usize = 0;
                                var ri: usize = 0;
                                @memset(&agent.live_result, 0);
                                while (ri < text.len and wi < 4090) {
                                    if (text[ri] == '\n') {
                                        agent.live_result[wi] = '\\';
                                        agent.live_result[wi + 1] = 'n';
                                        wi += 2;
                                    } else if (text[ri] >= 0x80) {
                                        agent.live_result[wi] = '-';
                                        wi += 1;
                                    } else {
                                        agent.live_result[wi] = text[ri];
                                        wi += 1;
                                    }
                                    ri += 1;
                                }
                                agent.live_result_len = wi;
                                agent.live_mtime = live_log_mtime;
                                agent.live_is_error = false;
                                // Clear stale metrics from old completed result
                                agent.live_num_turns = 0;
                                agent.live_duration_ms = 0;
                                agent.live_cost_len = 0;
                                std.debug.print("[POLL ai={d}] live.log STREAMING: {d} bytes, mtime={d}\n", .{ ai, lb_n, live_log_mtime });
                            }
                        }
                    } else |_| {}
                }
            }
        } else |_| {}
    }

    // Read .ralph/logs/status.json (Right-Bottom pane: Status Monitor data)
    {
        @memset(&path_buf, 0);
        const st_path = std.fmt.bufPrint(&path_buf, "{s}/.ralph/logs/status.json", .{base_path}) catch return;
        if (std.fs.openFileAbsolute(path_buf[0..st_path.len :0], .{})) |file| {
            defer file.close();
            // Track mtime
            if (file.stat()) |st| {
                agent.status_mtime = @intCast(@divFloor(st.mtime, std.time.ns_per_s));
            } else |_| {}
            var st_buf: [2048]u8 = undefined;
            const bytes = file.readAll(&st_buf) catch 0;
            if (bytes > 10) {
                const json = st_buf[0..bytes];

                // Parse loop_count
                if (std.mem.indexOf(u8, json, "\"loop_count\":")) |idx| {
                    var start = idx + 13;
                    while (start < json.len and (json[start] == ' ' or json[start] == '\t')) start += 1;
                    var end = start;
                    while (end < json.len and json[end] >= '0' and json[end] <= '9') end += 1;
                    if (end > start) agent.loop_count_status = std.fmt.parseInt(usize, json[start..end], 10) catch 0;
                }

                // Parse calls_made_this_hour
                if (std.mem.indexOf(u8, json, "\"calls_made_this_hour\":")) |idx| {
                    var start = idx + 22;
                    while (start < json.len and (json[start] == ' ' or json[start] == '\t')) start += 1;
                    var end = start;
                    while (end < json.len and json[end] >= '0' and json[end] <= '9') end += 1;
                    if (end > start) agent.calls_this_hour = std.fmt.parseInt(usize, json[start..end], 10) catch 0;
                }

                // Parse max_calls_per_hour
                if (std.mem.indexOf(u8, json, "\"max_calls_per_hour\":")) |idx| {
                    var start = idx + 20;
                    while (start < json.len and (json[start] == ' ' or json[start] == '\t')) start += 1;
                    var end = start;
                    while (end < json.len and json[end] >= '0' and json[end] <= '9') end += 1;
                    if (end > start) agent.max_calls_hour = std.fmt.parseInt(usize, json[start..end], 10) catch 100;
                }

                // Parse status string
                if (std.mem.indexOf(u8, json, "\"status\":")) |idx| {
                    const after = json[@min(idx + 9, json.len)..];
                    if (std.mem.indexOf(u8, after, "\"")) |q1| {
                        const vs = q1 + 1;
                        if (std.mem.indexOfScalar(u8, after[vs..], '"')) |q2| {
                            const val = after[vs .. vs + q2];
                            const len = @min(val.len, 31);
                            @memset(&agent.status_text, 0);
                            @memcpy(agent.status_text[0..len], val[0..len]);
                            agent.status_text_len = len;
                        }
                    }
                }

                // Parse last_action
                if (std.mem.indexOf(u8, json, "\"last_action\":")) |idx| {
                    const after = json[@min(idx + 14, json.len)..];
                    if (std.mem.indexOf(u8, after, "\"")) |q1| {
                        const vs = q1 + 1;
                        if (std.mem.indexOfScalar(u8, after[vs..], '"')) |q2| {
                            const val = after[vs .. vs + q2];
                            const len = @min(val.len, 63);
                            @memset(&agent.last_action, 0);
                            @memcpy(agent.last_action[0..len], val[0..len]);
                            agent.last_action_len = len;
                            // Detect active execution
                            agent.is_executing = std.mem.eql(u8, val, "executing");
                        }
                    }
                }

                // Parse next_reset
                if (std.mem.indexOf(u8, json, "\"next_reset\":")) |idx| {
                    const after = json[@min(idx + 13, json.len)..];
                    if (std.mem.indexOf(u8, after, "\"")) |q1| {
                        const vs = q1 + 1;
                        if (std.mem.indexOfScalar(u8, after[vs..], '"')) |q2| {
                            const val = after[vs .. vs + q2];
                            const len = @min(val.len, 15);
                            @memset(&agent.next_reset, 0);
                            @memcpy(agent.next_reset[0..len], val[0..len]);
                            agent.next_reset_len = len;
                        }
                    }
                }
            }
        } else |_| {}
    }

    // Prefer status.json loop_count over stale circuit_breaker_state loop
    if (agent.loop_count_status > 0) {
        agent.loop = agent.loop_count_status;
    }

    // Compute data freshness: age of newest data source
    {
        const now_secs: i64 = @intCast(@divFloor(std.time.nanoTimestamp(), std.time.ns_per_s));
        const newest_mtime = @max(agent.log_mtime, @max(agent.status_mtime, agent.live_mtime));
        agent.data_age_seconds = if (newest_mtime > 0) now_secs - newest_mtime else 0;
        if (agent.data_age_seconds < 0) agent.data_age_seconds = 0;
        std.debug.print("[POLL ai={d}] freshness: log_mt={d} status_mt={d} live_mt={d} age={d}s rate_lim={}\n", .{
            ai, agent.log_mtime, agent.status_mtime, agent.live_mtime, agent.data_age_seconds, agent.rate_limited,
        });
    }

    // Detect rate limiting from live_result
    {
        if (agent.live_result_len > 0) {
            const result = agent.live_result[0..agent.live_result_len];
            agent.rate_limited = (std.mem.indexOf(u8, result, "hit your limit") != null) or
                (std.mem.indexOf(u8, result, "rate limit") != null);
        } else {
            agent.rate_limited = false;
        }
    }

    // v8.1.1: Update ralph loop detection state before executing commands (all tabs)
    ralphUpdateLoopState();

    // Execute any pending ralph control command (START/STOP/RESTART) (all tabs)
    ralphExecPendingCmd();
}

// ── v8.0: Unified Chat Helpers ──

/// Parse [YYYY-MM-DD HH:MM:SS] from log line into comparable i64 for sorting.
fn parseLogTimestamp(line: []const u8) i64 {
    // Format: [2026-02-18 21:36:35] ...
    if (line.len < 21 or line[0] != '[') return 0;
    const year = std.fmt.parseInt(i64, line[1..5], 10) catch return 0;
    const month = std.fmt.parseInt(i64, line[6..8], 10) catch return 0;
    const day = std.fmt.parseInt(i64, line[9..11], 10) catch return 0;
    const hour = std.fmt.parseInt(i64, line[12..14], 10) catch return 0;
    const min = std.fmt.parseInt(i64, line[15..17], 10) catch return 0;
    const sec = std.fmt.parseInt(i64, line[18..20], 10) catch return 0;
    return (year - 2020) * 31536000 + month * 2678400 + day * 86400 + hour * 3600 + min * 60 + sec;
}

/// Get tag color RGB for a log line (without alpha).
fn getLogTagColor(line: []const u8) struct { r: u8, g: u8, b: u8 } {
    if (line.len < 3) return .{ .r = 0xBB, .g = 0xBB, .b = 0xBB };
    if (containsBytes(line, "[LOOP]") or containsBytes(line, "=== "))
        return .{ .r = 0xFF, .g = 0xAA, .b = 0x00 };
    if (containsBytes(line, "[SUCCESS]"))
        return .{ .r = 0x00, .g = 0xFF, .b = 0x41 };
    if (containsBytes(line, "[INFO]"))
        return .{ .r = 0x88, .g = 0xCC, .b = 0xFF };
    if (containsBytes(line, "[WARN]"))
        return .{ .r = 0xFF, .g = 0xFF, .b = 0x00 };
    if (containsBytes(line, "[ERROR]") or containsBytes(line, "[FAIL]"))
        return .{ .r = 0xFF, .g = 0x33, .b = 0x66 };
    if (containsBytes(line, "Executing Claude"))
        return .{ .r = 0xFF, .g = 0x14, .b = 0x93 };
    if (containsBytes(line, "Completed Loop"))
        return .{ .r = 0x50, .g = 0xFA, .b = 0x7B };
    return .{ .r = 0xBB, .g = 0xBB, .b = 0xBB };
}

/// Build unified chat message array from logs + claude output, sorted chronologically.
fn buildUnifiedChat(ai: usize) void {
    const agent = &g_ralph_agents[ai];

    // Skip rebuild if nothing changed
    if (agent.log_mtime == agent.chat_built_log_mt and
        agent.live_mtime == agent.chat_built_live_mt) return;

    agent.chat_count = 0;

    // 1. Add log lines
    for (0..agent.log_count) |i| {
        if (agent.chat_count >= 50) break;
        const log_slice = std.mem.sliceTo(&agent.logs[i], 0);
        if (log_slice.len == 0) continue;

        var msg = &agent.chat_msgs[agent.chat_count];
        msg.* = ChatMsg{};
        msg.sender = .loop;
        msg.kind = .log_line;
        msg.timestamp = parseLogTimestamp(log_slice);
        const len = @min(log_slice.len, 255);
        @memcpy(msg.text[0..len], log_slice[0..len]);
        msg.text_len = len;
        const tc = getLogTagColor(log_slice);
        msg.tag_r = tc.r;
        msg.tag_g = tc.g;
        msg.tag_b = tc.b;
        agent.chat_count += 1;
    }

    // 2. Add claude metadata
    if (agent.live_result_len > 0 and agent.live_num_turns > 0 and agent.chat_count < 50) {
        var msg = &agent.chat_msgs[agent.chat_count];
        msg.* = ChatMsg{};
        msg.sender = .claude;
        msg.kind = .meta_info;
        msg.timestamp = agent.live_mtime;
        _ = std.fmt.bufPrint(&msg.text, "Turns: {d} | Duration: {d}m{d}s | Cost: ${s}", .{
            agent.live_num_turns,
            agent.live_duration_ms / 60000,
            (agent.live_duration_ms / 1000) % 60,
            std.mem.sliceTo(&agent.live_cost_usd, 0),
        }) catch {};
        msg.text_len = std.mem.sliceTo(&msg.text, 0).len;
        agent.chat_count += 1;
    }

    // 3. Add task list
    if (agent.todo_count > 0 and agent.chat_count < 50) {
        var msg = &agent.chat_msgs[agent.chat_count];
        msg.* = ChatMsg{};
        msg.sender = .claude;
        msg.kind = .task_list;
        msg.timestamp = agent.live_mtime;
        msg.todo_count = agent.todo_count;
        agent.chat_count += 1;
    }

    // 4. Add claude result body
    if (agent.live_result_len > 0 and agent.chat_count < 50) {
        var msg = &agent.chat_msgs[agent.chat_count];
        msg.* = ChatMsg{};
        msg.sender = .claude;
        msg.kind = .claude_result;
        msg.timestamp = agent.live_mtime + 1;
        msg.result_offset = 0;
        msg.result_len = agent.live_result_len;
        agent.chat_count += 1;
    }

    // 5. Insertion sort by timestamp (N<=50)
    var si: usize = 1;
    while (si < agent.chat_count) : (si += 1) {
        const key = agent.chat_msgs[si];
        var j: usize = si;
        while (j > 0 and agent.chat_msgs[j - 1].timestamp > key.timestamp) {
            agent.chat_msgs[j] = agent.chat_msgs[j - 1];
            j -= 1;
        }
        agent.chat_msgs[j] = key;
    }

    agent.chat_built_log_mt = agent.log_mtime;
    agent.chat_built_live_mt = agent.live_mtime;
}

// v2.1: Add entry to live log buffer (ring buffer)
fn addLiveLog(text: []const u8, source_hue: f32) void {
    if (g_live_log_count >= LIVE_LOG_MAX) {
        // Shift entries up (drop oldest)
        for (0..LIVE_LOG_MAX - 1) |i| {
            @memcpy(&g_live_log_text[i], &g_live_log_text[i + 1]);
            g_live_log_lens[i] = g_live_log_lens[i + 1];
            g_live_log_hues[i] = g_live_log_hues[i + 1];
        }
        g_live_log_count = LIVE_LOG_MAX - 1;
    }
    const idx = g_live_log_count;
    const copy_len = @min(text.len, 95);
    @memcpy(g_live_log_text[idx][0..copy_len], text[0..copy_len]);
    g_live_log_text[idx][copy_len] = 0;
    g_live_log_lens[idx] = copy_len;
    g_live_log_hues[idx] = source_hue;
    g_live_log_count += 1;
}

// v2.0: Scan current working directory for finder mode
fn scanDirectory() void {
    g_finder_count = 0;
    if (is_emscripten) {
        // WASM: static demo file list (no filesystem access)
        const demo_names = [_][]const u8{
            "src/",       "assets/",         "build.zig",       "README.md", "specs/",
            "photon.zig", "trinity_canvas/", "wave_scroll.zig",
        };
        const demo_is_dir = [_]bool{ true, true, false, false, true, false, true, false };
        for (demo_names, 0..) |name, i| {
            if (i >= FINDER_MAX_ENTRIES) break;
            const name_len = @min(name.len, 63);
            @memcpy(g_finder_names[i][0..name_len], name[0..name_len]);
            g_finder_names[i][name_len] = 0;
            g_finder_is_dir[i] = demo_is_dir[i];
            g_finder_count += 1;
        }
        g_finder_scanned = true;
        return;
    }
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch return;
    defer dir.close();
    var iter = dir.iterate();
    while (g_finder_count < FINDER_MAX_ENTRIES) {
        const entry = iter.next() catch break;
        if (entry == null) break;
        const e = entry.?;
        const name_len = @min(e.name.len, 63);
        @memcpy(g_finder_names[g_finder_count][0..name_len], e.name[0..name_len]);
        g_finder_names[g_finder_count][name_len] = 0;
        g_finder_is_dir[g_finder_count] = (e.kind == .directory);
        g_finder_count += 1;
    }
    g_finder_scanned = true;
    g_finder_last_scan = std.time.timestamp();
}

fn addGlobalChatMessage(msg: []const u8, msg_type: ChatMsgType) void {
    if (g_chat_msg_count >= MAX_CHAT_MSGS) {
        // Shift messages up (drop oldest)
        for (0..MAX_CHAT_MSGS - 1) |i| {
            @memcpy(&g_chat_messages[i], &g_chat_messages[i + 1]);
            g_chat_msg_lens[i] = g_chat_msg_lens[i + 1];
            g_chat_msg_types[i] = g_chat_msg_types[i + 1];
        }
        g_chat_msg_count = MAX_CHAT_MSGS - 1;
    }
    const idx = g_chat_msg_count;
    const copy_len = @min(msg.len, 511);
    @memcpy(g_chat_messages[idx][0..copy_len], msg[0..copy_len]);
    g_chat_msg_lens[idx] = copy_len;
    g_chat_msg_types[idx] = msg_type;
    g_chat_msg_count += 1;
}

fn addChatLogMessage(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch "...";
    addGlobalChatMessage(text, .log);
}

// =============================================================================
//   — Chakra Colors + Chain Indicator Renderer
// =============================================================================

fn getChainMsgColor(msg_type: ChatMsgType, alpha: u8) rl.Color {
    return switch (msg_type) {
        .chain_goal_parse => .{ .r = 0xFF, .g = 0x30, .b = 0x30, .a = alpha }, // Red
        .chain_decompose => .{ .r = 0xFF, .g = 0x7F, .b = 0x00, .a = alpha }, // Orange
        .chain_schedule => .{ .r = 0xFF, .g = 0xDD, .b = 0x00, .a = alpha }, // Yellow
        .chain_execute => .{ .r = 0x00, .g = 0xEE, .b = 0x44, .a = alpha }, // Green
        .chain_monitor => .{ .r = 0x44, .g = 0x88, .b = 0xFF, .a = alpha }, // Blue
        .chain_adapt => .{ .r = 0x6B, .g = 0x20, .b = 0xA2, .a = alpha }, // Indigo
        .chain_synthesize => .{ .r = 0xAB, .g = 0x30, .b = 0xFF, .a = alpha }, // Violet
        .chain_deliver => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .tool_result => .{ .r = 0x00, .g = 0x88, .b = 0xFF, .a = alpha }, // Tool blue
        .routing_info => .{ .r = 0x00, .g = 0xCC, .b = 0xFF, .a = alpha }, // Cyan
        .reflection => .{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = alpha }, // Learn green
        .agent_error => .{ .r = 0xFF, .g = 0x44, .b = 0x44, .a = alpha }, // Error red
        .provenance_step => .{ .r = 0x88, .g = 0x88, .b = 0xAA, .a = alpha }, // Steel blue
        .truth_verification => .{ .r = 0x00, .g = 0xFF, .b = 0xAA, .a = alpha }, // Bright teal
        .quark_step => .{ .r = 0x99, .g = 0x99, .b = 0xBB, .a = alpha }, // Light steel blue
        .gluon_entangle => .{ .r = 0xCC, .g = 0x44, .b = 0xFF, .a = alpha }, // Magenta
        .dag_visualization => .{ .r = 0x00, .g = 0xDD, .b = 0xCC, .a = alpha }, // Cyan
        .reward_summary => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .collapse_toggle => .{ .r = 0x70, .g = 0x80, .b = 0x90, .a = alpha }, // Slate
        .share_link_generated => .{ .r = 0x00, .g = 0x7B, .b = 0xFF, .a = alpha }, // Electric blue
        .staking_event => .{ .r = 0x50, .g = 0xC8, .b = 0x78, .a = alpha }, // Emerald
        .self_repair_event => .{ .r = 0xFF, .g = 0x99, .b = 0x33, .a = alpha }, // Warm orange
        .immortal_persist => .{ .r = 0x00, .g = 0x99, .b = 0x88, .a = alpha }, // Deep teal
        .evolution_step => .{ .r = 0x33, .g = 0xFF, .b = 0x77, .a = alpha }, // Aurora green
        .chain_health_check => .{ .r = 0x55, .g = 0xBB, .b = 0xFF, .a = alpha }, // Sky blue
        .faucet_claim => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .public_launch => .{ .r = 0x00, .g = 0xEE, .b = 0xFF, .a = alpha }, // Bright cyan
        .canvas_sync => .{ .r = 0x88, .g = 0x44, .b = 0xFF, .a = alpha }, // Violet
        .faucet_distribution => .{ .r = 0xFF, .g = 0xBB, .b = 0x33, .a = alpha }, // Amber
        .decentral_sync => .{ .r = 0x99, .g = 0x33, .b = 0xFF, .a = alpha }, // Electric purple
        .node_consensus => .{ .r = 0x77, .g = 0xFF, .b = 0x33, .a = alpha }, // Lime green
        .network_health => .{ .r = 0x00, .g = 0x77, .b = 0xCC, .a = alpha }, // Ocean blue
        .agent_os_init => .{ .r = 0xFF, .g = 0x66, .b = 0x55, .a = alpha }, // Bright coral
        .mainnet_genesis => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .dao_vote => .{ .r = 0x41, .g = 0x69, .b = 0xE1, .a = alpha }, // Royal blue
        .swarm_sync => .{ .r = 0x39, .g = 0xFF, .b = 0x14, .a = alpha }, // Neon green
        .token_mint => .{ .r = 0xFF, .g = 0xBF, .b = 0x00, .a = alpha }, // Amber
        .mainnet_launch => .{ .r = 0xDC, .g = 0x14, .b = 0x3C, .a = alpha }, // Crimson
        .community_onboard => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime
        .node_discovery => .{ .r = 0x00, .g = 0xCE, .b = 0xD1, .a = alpha }, // Cyan
        .governance_exec => .{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = alpha }, // Magenta
        .swarm_orchestrate => .{ .r = 0x99, .g = 0x33, .b = 0xFF, .a = alpha }, // Electric purple
        .swarm_failover => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = alpha }, // Red-orange
        .swarm_telemetry => .{ .r = 0x00, .g = 0x80, .b = 0x80, .a = alpha }, // Teal
        .swarm_replication => .{ .r = 0x87, .g = 0xCE, .b = 0xEB, .a = alpha }, // Sky blue
        .swarm_scale => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .reward_distribute => .{ .r = 0xFF, .g = 0xBF, .b = 0x00, .a = alpha }, // Amber
        .dao_governance_live => .{ .r = 0x41, .g = 0x69, .b = 0xE1, .a = alpha }, // Royal blue
        .node_scaling => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = alpha }, // Spring green
        // v2.7: Community Nodes v1.0 + Gossip Protocol + DHT 10k+
        .community_node => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime green
        .gossip_broadcast => .{ .r = 0xFF, .g = 0x7F, .b = 0x50, .a = alpha }, // Coral
        .dht_lookup => .{ .r = 0x1E, .g = 0x90, .b = 0xFF, .a = alpha }, // Dodger blue
        .community_sync => .{ .r = 0xBA, .g = 0x55, .b = 0xD3, .a = alpha }, // Medium orchid
        // v2.8: DAO Full Governance v1.0
        .dao_delegate => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .timelock_vote => .{ .r = 0xDC, .g = 0x14, .b = 0x3C, .a = alpha }, // Crimson
        .proposal_exec => .{ .r = 0x2E, .g = 0x8B, .b = 0x57, .a = alpha }, // Sea green
        .yield_farming => .{ .r = 0xFF, .g = 0x8C, .b = 0x00, .a = alpha }, // Dark orange
        // v2.9: Cross-Chain Bridge v1.0
        .cross_chain_bridge => .{ .r = 0x00, .g = 0xBF, .b = 0xFF, .a = alpha }, // Deep sky blue
        .atomic_swap => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = alpha }, // Orange red
        .state_replicate => .{ .r = 0x3C, .g = 0xB3, .b = 0x71, .a = alpha }, // Medium sea green
        .bridge_sync => .{ .r = 0x41, .g = 0x69, .b = 0xE1, .a = alpha }, // Royal blue
        // v2.10: Trinity DAO Full Governance v1.0 + $TRI Staking Rewards
        .dao_full_governance => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .tri_staking => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime green
        .reward_distribute_v2 => .{ .r = 0xFF, .g = 0x69, .b = 0xB4, .a = alpha }, // Hot pink
        .staking_validate => .{ .r = 0x46, .g = 0x82, .b = 0xB4, .a = alpha }, // Steel blue
        // v2.11: Swarm 100k + Community 50k (Sharded Gossip + Hierarchical DHT)
        .swarm_100k => .{ .r = 0xFF, .g = 0xA5, .b = 0x00, .a = alpha }, // Orange
        .gossip_shard => .{ .r = 0x00, .g = 0xCE, .b = 0xD1, .a = alpha }, // Dark turquoise
        .dht_sync => .{ .r = 0x93, .g = 0x70, .b = 0xDB, .a = alpha }, // Medium purple
        .community_50k => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = alpha }, // Spring green
        // v2.12: Zero-Knowledge Bridge v1.0 (ZK-Proof Verification + Privacy Transfers)
        .zk_bridge => .{ .r = 0xDC, .g = 0x14, .b = 0x3C, .a = alpha }, // Crimson
        .zk_proof => .{ .r = 0x7D, .g = 0xF9, .b = 0xFF, .a = alpha }, // Electric blue
        .privacy_transfer => .{ .r = 0x4B, .g = 0x00, .b = 0x82, .a = alpha }, // Indigo
        .cross_chain_sync_v2 => .{ .r = 0x50, .g = 0xC8, .b = 0x78, .a = alpha }, // Emerald
        // v2.13: Layer-2 Rollup v1.0 (u8 Upgrade)
        .l2_rollup => .{ .r = 0xFF, .g = 0x7F, .b = 0x50, .a = alpha }, // Coral
        .optimistic_verify => .{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = alpha }, // Cyan
        .state_channel => .{ .r = 0xDA, .g = 0x70, .b = 0xD6, .a = alpha }, // Orchid
        .batch_compress => .{ .r = 0x40, .g = 0xE0, .b = 0xD0, .a = alpha }, // Turquoise
        // v2.14: Dynamic Shard Rebalancing v1.0
        .dynamic_shard => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .shard_split => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime
        .shard_merge => .{ .r = 0xFA, .g = 0x80, .b = 0x72, .a = alpha }, // Salmon
        .dht_adapt => .{ .r = 0x46, .g = 0x82, .b = 0xB4, .a = alpha }, // Steel Blue
        // v2.15: Swarm 1M + Community 500k
        .swarm_million => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = alpha }, // Orange Red
        .community_node_v2 => .{ .r = 0x93, .g = 0x70, .b = 0xDB, .a = alpha }, // Medium Purple
        .hierarchical_gossip => .{ .r = 0x00, .g = 0x8B, .b = 0x8B, .a = alpha }, // Dark Cyan
        .geographic_shard => .{ .r = 0xCD, .g = 0x5C, .b = 0x5C, .a = alpha }, // Indian Red
        // v2.16: ZK-Rollup v2.0
        .zk_snark_proof => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime Green
        .recursive_proof => .{ .r = 0xFF, .g = 0x14, .b = 0x93, .a = alpha }, // Deep Pink
        .l2_scaling => .{ .r = 0x1E, .g = 0x90, .b = 0xFF, .a = alpha }, // Dodger Blue
        .rollup_batch => .{ .r = 0xFF, .g = 0x8C, .b = 0x00, .a = alpha }, // Dark Orange
        // v2.17: Cross-Shard Transactions v1.0
        .cross_shard_tx => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = alpha }, // Spring Green
        .atomic_2pc => .{ .r = 0xFF, .g = 0x69, .b = 0xB4, .a = alpha }, // Hot Pink
        .shard_fee => .{ .r = 0x46, .g = 0x82, .b = 0xB4, .a = alpha }, // Steel Blue
        .tx_coordinator => .{ .r = 0xDA, .g = 0xA5, .b = 0x20, .a = alpha }, // Golden Rod
        .partition_detect => .{ .r = 0xFF, .g = 0x7F, .b = 0x50, .a = alpha }, // Coral
        .split_brain => .{ .r = 0xBA, .g = 0x55, .b = 0xD3, .a = alpha }, // Medium Orchid
        .auto_heal => .{ .r = 0x3C, .g = 0xB3, .b = 0x71, .a = alpha }, // Medium Sea Green
        .partition_tolerance => .{ .r = 0x6A, .g = 0x5A, .b = 0xCD, .a = alpha }, // Slate Blue
        // v2.19: Swarm 10M + Community 5M colors
        .swarm_10m => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime Green
        .community_5m => .{ .r = 0xFF, .g = 0x14, .b = 0x93, .a = alpha }, // Deep Pink
        .earning_boost => .{ .r = 0x1E, .g = 0x90, .b = 0xFF, .a = alpha }, // Dodger Blue
        .massive_gossip => .{ .r = 0xFF, .g = 0x8C, .b = 0x00, .a = alpha }, // Dark Orange
        // v2.20: ZK-Rollup v2.0 colors
        .zk_rollup_v2 => .{ .r = 0x00, .g = 0xFA, .b = 0x9A, .a = alpha }, // Medium Spring Green
        .snark_generate => .{ .r = 0xFF, .g = 0x69, .b = 0xB4, .a = alpha }, // Hot Pink
        .recursive_compose => .{ .r = 0x41, .g = 0x69, .b = 0xE1, .a = alpha }, // Royal Blue
        .l2_fee_collect => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        // v2.21: Cross-Shard Transactions v1.0
        .cross_shard_tx_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = alpha }, // Cyan
        .atomic_2pc_v2 => .{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = alpha }, // Magenta
        .shard_fee_v2 => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = alpha }, // Orange Red
        .inter_shard_sync_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = alpha }, // Spring Green
        // v2.22: Formal Verification v1.0
        .formal_verify_v2 => .{ .r = 0x00, .g = 0xBF, .b = 0xFF, .a = alpha }, // Deep Sky Blue
        .property_test_v2 => .{ .r = 0xFF, .g = 0x14, .b = 0x93, .a = alpha }, // Deep Pink
        .invariant_check_v2 => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime Green
        .proof_generate_v2 => .{ .r = 0xFF, .g = 0xA5, .b = 0x00, .a = alpha }, // Orange
        // v2.23: Swarm 100M + Community 50M
        .swarm_100m_v2 => .{ .r = 0x00, .g = 0xBF, .b = 0xFF, .a = alpha }, // Deep Sky Blue
        .community_50m_v2 => .{ .r = 0xFF, .g = 0x14, .b = 0x93, .a = alpha }, // Deep Pink
        .earning_moonshot_v2 => .{ .r = 0x32, .g = 0xCD, .b = 0x32, .a = alpha }, // Lime Green
        .gossip_v3_v2 => .{ .r = 0xFF, .g = 0xA5, .b = 0x00, .a = alpha }, // Orange
        // v2.24: Trinity Global Dominance v1.0 colors
        .global_dominance_v2 => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha }, // Gold
        .world_adoption_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = alpha }, // Spring Green
        .tri_to_one_v2 => .{ .r = 0x94, .g = 0x00, .b = 0xD3, .a = alpha }, // Dark Violet
        .ecosystem_complete_v2 => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = alpha }, // Orange Red
        // v2.25: Trinity Eternal v1.0
        .ouroboros_evolve_v2 => .{ .r = 0, .g = 255, .b = 127, .a = 255 }, // spring green
        .infinite_scale_v2 => .{ .r = 138, .g = 43, .b = 226, .a = 255 }, // blue violet
        .universal_reserve_v2 => .{ .r = 255, .g = 215, .b = 0, .a = 255 }, // gold
        .eternal_uptime_v2 => .{ .r = 0, .g = 191, .b = 255, .a = 255 }, // deep sky blue
        // v2.26
        .tri_to_ten_v2 => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = 255 },
        .mass_adoption_v2 => .{ .r = 0x00, .g = 0xBF, .b = 0xFF, .a = 255 },
        .exchange_listing_v2 => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 255 },
        .universal_wallet_v2 => .{ .r = 0x7B, .g = 0x68, .b = 0xEE, .a = 255 },
        // v2.27
        .tri_to_hundred_v2 => .{ .r = 0xDC, .g = 0x14, .b = 0x3C, .a = 255 },
        .universal_adoption_v2 => .{ .r = 0x00, .g = 0xFA, .b = 0x9A, .a = 255 },
        .exchange_v2_v2 => .{ .r = 0xFF, .g = 0x69, .b = 0xB4, .a = 255 },
        .global_wallet_v2 => .{ .r = 0x48, .g = 0xD1, .b = 0xCC, .a = 255 },
        // v2.28
        .swarm_10m_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = 255 },
        .community_5m_v2 => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 255 },
        .earning_ultimate_v2 => .{ .r = 0x7F, .g = 0xFF, .b = 0x00, .a = 255 },
        .node_discovery_10m_v2 => .{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = 255 },
        // v2.29: u16 Upgrade colors
        .swarm_1b_v2 => .{ .r = 0x00, .g = 0xBF, .b = 0xFF, .a = 255 }, // deep sky blue
        .community_500m_v2 => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = 255 }, // orange red
        .earning_god_mode_v2 => .{ .r = 0xAD, .g = 0xFF, .b = 0x2F, .a = 255 }, // green yellow
        .node_discovery_1b_v2 => .{ .r = 0xDA, .g = 0x70, .b = 0xD6, .a = 255 }, // orchid
        // v2.30: Trinity Neural Network v1.0
        .ternary_nn_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = 255 }, // spring green
        .recursive_self_train_v2 => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 255 }, // gold
        .contribution_reward_v2 => .{ .r = 0x7F, .g = 0xFF, .b = 0x00, .a = 255 }, // chartreuse
        .neural_consensus_v2 => .{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = 255 }, // magenta
        // v2.31: $TRI to $1000 + Eternal Dominance
        .tri_to_1000_v2 => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 255 }, // gold
        .universal_reserve_v2_v2 => .{ .r = 0x00, .g = 0xBF, .b = 0xFF, .a = 255 }, // deep sky blue
        .global_dominance_v2_v2 => .{ .r = 0xFF, .g = 0x45, .b = 0x00, .a = 255 }, // orange red
        .eternal_governance_v2_v2 => .{ .r = 0x9A, .g = 0xCD, .b = 0x32, .a = 255 }, // yellow green
        // v2.32: Trinity Beyond v1.0
        .trinity_beyond_v2 => .{ .r = 0xE0, .g = 0x00, .b = 0xFF, .a = 255 }, // electric purple
        .infinite_scale_v2_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0xCC, .a = 255 }, // aqua green
        .multiverse_dominance_v2 => .{ .r = 0xFF, .g = 0x00, .b = 0x80, .a = 255 }, // hot pink
        .eternal_evolution_v2 => .{ .r = 0x00, .g = 0xFF, .b = 0x00, .a = 255 }, // lime green
        // v3.0: Trinity Absolute v1.0
        .trinity_absolute_v3 => .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 255 }, // pure white (absolute)
        .infinite_tri_v3 => .{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 255 }, // gold (infinite $TRI)
        .eternal_victory_v3 => .{ .r = 0x00, .g = 0xFF, .b = 0x7F, .a = 255 }, // spring green (victory)
        .multiverse_complete_v3 => .{ .r = 0xDA, .g = 0x70, .b = 0xD6, .a = 255 }, // orchid (complete)
        .user => .{ .r = 0x70, .g = 0x70, .b = 0x90, .a = alpha },
        .ai => .{ .r = 0x30, .g = 0x80, .b = 0x50, .a = alpha },
        .log => .{ .r = 0x60, .g = 0x60, .b = 0x60, .a = alpha },
    };
}

fn getChainMsgLabel(msg_type: ChatMsgType) [*:0]const u8 {
    return switch (msg_type) {
        .chain_goal_parse => "GOAL_PARSE",
        .chain_decompose => "DECOMPOSE",
        .chain_schedule => "SCHEDULE",
        .chain_execute => "EXECUTE",
        .chain_monitor => "MONITOR",
        .chain_adapt => "ADAPT",
        .chain_synthesize => "SYNTHESIZE",
        .chain_deliver => "DELIVER",
        .tool_result => "TOOL",
        .routing_info => "->",
        .reflection => "LEARNED",
        .agent_error => "ERROR",
        .provenance_step => "HASH",
        .truth_verification => "TRUTH",
        .quark_step => "QUARK",
        .gluon_entangle => "GLUON",
        .dag_visualization => "DAG",
        .reward_summary => "$TRI",
        .collapse_toggle => "VIEW",
        .share_link_generated => "SHARE",
        .staking_event => "STAKE",
        .self_repair_event => "REPAIR",
        .immortal_persist => "PERSIST",
        .evolution_step => "EVOLVE",
        .chain_health_check => "HEALTH",
        .faucet_claim => "FAUCET",
        .public_launch => "PUBLIC",
        .canvas_sync => "CANVAS",
        .faucet_distribution => "FAUCET_D",
        .decentral_sync => "DSYNC",
        .node_consensus => "CONSENSUS",
        .network_health => "NET_HEALTH",
        .agent_os_init => "AGENT_OS",
        .mainnet_genesis => "GENESIS",
        .dao_vote => "DAO",
        .swarm_sync => "SWARM",
        .token_mint => "MINT",
        .mainnet_launch => "LAUNCH",
        .community_onboard => "COMMUNITY",
        .node_discovery => "DISCOVER",
        .governance_exec => "GOV_EXEC",
        .swarm_orchestrate => "SWARM_ORCH",
        .swarm_failover => "SWARM_FAIL",
        .swarm_telemetry => "SWARM_TELE",
        .swarm_replication => "SWARM_REPL",
        .swarm_scale => "SWARM_SCALE",
        .reward_distribute => "REWARD_DIST",
        .dao_governance_live => "DAO_GOV_LV",
        .node_scaling => "NODE_SCALE",
        // v2.7: Community Nodes v1.0 + Gossip Protocol + DHT 10k+
        .community_node => "COMM_NODE",
        .gossip_broadcast => "GOSSIP_BC",
        .dht_lookup => "DHT_LOOKUP",
        .community_sync => "COMM_SYNC",
        // v2.8: DAO Full Governance v1.0
        .dao_delegate => "DAO_DELEG",
        .timelock_vote => "TIMELVOTE",
        .proposal_exec => "PROP_EXEC",
        .yield_farming => "YIELD_FRM",
        // v2.9: Cross-Chain Bridge v1.0
        .cross_chain_bridge => "XCH_BRDG",
        .atomic_swap => "ATOM_SWAP",
        .state_replicate => "ST_REPLIC",
        .bridge_sync => "BRDG_SYNC",
        // v2.10: Trinity DAO Full Governance v1.0 + $TRI Staking Rewards
        .dao_full_governance => "DAO_FGOV",
        .tri_staking => "TRI_STAK",
        .reward_distribute_v2 => "RWD_DIST2",
        .staking_validate => "STK_VLDR",
        // v2.11: Swarm 100k + Community 50k (Sharded Gossip + Hierarchical DHT)
        .swarm_100k => "SWM_100K",
        .gossip_shard => "GSP_SHRD",
        .dht_sync => "DHT_SYNC",
        .community_50k => "COM_50K",
        // v2.12: Zero-Knowledge Bridge v1.0 (ZK-Proof Verification + Privacy Transfers)
        .zk_bridge => "ZK_BRDG",
        .zk_proof => "ZK_PROOF",
        .privacy_transfer => "PRV_XFER",
        .cross_chain_sync_v2 => "XCH_SYNC",
        // v2.13: Layer-2 Rollup v1.0
        .l2_rollup => "L2_ROLL",
        .optimistic_verify => "OPT_VRFY",
        .state_channel => "ST_CHAN",
        .batch_compress => "BCH_COMP",
        // v2.15: Swarm 1M + Community 500k
        .swarm_million => "SWM_1M",
        .community_node_v2 => "COM_ND2",
        .hierarchical_gossip => "HIR_GSP",
        .geographic_shard => "GEO_SHD",
        // v2.16: ZK-Rollup v2.0
        .zk_snark_proof => "ZK_PRF",
        .recursive_proof => "REC_PRF",
        .l2_scaling => "L2_SCL",
        .rollup_batch => "RLP_BAT",
        .cross_shard_tx => "XSH_TX",
        .atomic_2pc => "ATM_2PC",
        .shard_fee => "SHD_FEE",
        .tx_coordinator => "TX_CRD",
        .partition_detect => "PRT_DET",
        .split_brain => "SPL_BRN",
        .auto_heal => "AUT_HEL",
        .partition_tolerance => "PRT_TOL",
        // v2.19
        .swarm_10m => "SWM_10M",
        .community_5m => "COM_5M",
        .earning_boost => "ERN_BST",
        .massive_gossip => "MAS_GSP",
        // v2.20
        .zk_rollup_v2 => "ZKR_V2",
        .snark_generate => "SNK_GEN",
        .recursive_compose => "REC_CMP",
        .l2_fee_collect => "L2_FEE",
        // v2.21
        .cross_shard_tx_v2 => "XSH_V2",
        .atomic_2pc_v2 => "2PC_V2",
        .shard_fee_v2 => "SHF_V2",
        .inter_shard_sync_v2 => "ISS_V2",
        // v2.22: Formal Verification v1.0
        .formal_verify_v2 => "FRM_VRF",
        .property_test_v2 => "PRP_TST",
        .invariant_check_v2 => "INV_CHK",
        .proof_generate_v2 => "PRF_GEN",
        // v2.23: Swarm 100M + Community 50M
        .swarm_100m_v2 => "SWM_100M",
        .community_50m_v2 => "COM_50M",
        .earning_moonshot_v2 => "ERN_MSH",
        .gossip_v3_v2 => "GSP_V3",
        // v2.24: Trinity Global Dominance v1.0
        .global_dominance_v2 => "GLB_DOM",
        .world_adoption_v2 => "WLD_ADP",
        .tri_to_one_v2 => "TRI_$1",
        .ecosystem_complete_v2 => "ECO_CMP",
        // v2.25: Trinity Eternal v1.0
        .ouroboros_evolve_v2 => "ORB_EVO",
        .infinite_scale_v2 => "INF_SCL",
        .universal_reserve_v2 => "UNI_RSV",
        .eternal_uptime_v2 => "ETR_UPT",
        // v2.26
        .tri_to_ten_v2 => "$TRI→$10",
        .mass_adoption_v2 => "MASS_ADP",
        .exchange_listing_v2 => "EXC_LIST",
        .universal_wallet_v2 => "UNI_WALLET",
        // v2.27
        .tri_to_hundred_v2 => "$TRI→$100",
        .universal_adoption_v2 => "UNI_ADOPT",
        .exchange_v2_v2 => "EXC_V2",
        .global_wallet_v2 => "GLB_WALLET",
        // v2.28
        .swarm_10m_v2 => "SWM_10M",
        .community_5m_v2 => "COM_5M",
        .earning_ultimate_v2 => "ERN_ULT",
        .node_discovery_10m_v2 => "NOD_10M",
        .swarm_1b_v2 => "SWM_1B",
        .community_500m_v2 => "COM_500M",
        .earning_god_mode_v2 => "ERN_GOD",
        .node_discovery_1b_v2 => "NOD_1B",
        // v2.30: Trinity Neural Network v1.0
        .ternary_nn_v2 => "TRN_NN",
        .recursive_self_train_v2 => "REC_ST",
        .contribution_reward_v2 => "CTR_RW",
        .neural_consensus_v2 => "NRL_CON",
        .tri_to_1000_v2 => "TRI_1K",
        .universal_reserve_v2_v2 => "UNI_RSV",
        .global_dominance_v2_v2 => "GLB_DOM",
        .eternal_governance_v2_v2 => "ETR_GOV",
        // v2.32: Trinity Beyond v1.0
        .trinity_beyond_v2 => "TRN_BYD",
        .infinite_scale_v2_v2 => "INF_SCL",
        .multiverse_dominance_v2 => "MLT_DOM",
        .eternal_evolution_v2 => "ETR_EVO",
        // v3.0: Trinity Absolute v1.0
        .trinity_absolute_v3 => "TRN_ABS",
        .infinite_tri_v3 => "INF_TRI",
        .eternal_victory_v3 => "ETR_VIC",
        .multiverse_complete_v3 => "MLT_CMP",
        .user => "YOU",
        .ai => "AI",
        .log => "LOG",
        else => "CHAIN",
    };
}

fn isChainType(msg_type: ChatMsgType) bool {
    return switch (msg_type) {
        .chain_goal_parse, .chain_decompose, .chain_schedule, .chain_execute, .chain_monitor, .chain_adapt, .chain_synthesize, .chain_deliver, .tool_result, .routing_info, .reflection, .agent_error, .provenance_step, .truth_verification, .quark_step, .gluon_entangle, .dag_visualization, .reward_summary, .collapse_toggle, .share_link_generated, .staking_event, .self_repair_event, .immortal_persist, .evolution_step, .chain_health_check, .faucet_claim, .public_launch, .canvas_sync, .faucet_distribution, .decentral_sync, .node_consensus, .network_health, .agent_os_init, .mainnet_genesis, .dao_vote, .swarm_sync, .token_mint, .mainnet_launch, .community_onboard, .node_discovery, .governance_exec, .swarm_orchestrate, .swarm_failover, .swarm_telemetry, .swarm_replication, .swarm_scale, .reward_distribute, .dao_governance_live, .node_scaling, .community_node, .gossip_broadcast, .dht_lookup, .community_sync, .dao_delegate, .timelock_vote, .proposal_exec, .yield_farming, .cross_chain_bridge, .atomic_swap, .state_replicate, .bridge_sync, .dao_full_governance, .tri_staking, .reward_distribute_v2, .staking_validate, .swarm_100k, .gossip_shard, .dht_sync, .community_50k, .zk_bridge, .zk_proof, .privacy_transfer, .cross_chain_sync_v2, .l2_rollup, .optimistic_verify, .state_channel, .batch_compress, .dynamic_shard, .shard_split, .shard_merge, .dht_adapt, .swarm_million, .community_node_v2, .hierarchical_gossip, .geographic_shard, .zk_snark_proof, .recursive_proof, .l2_scaling, .rollup_batch, .cross_shard_tx, .atomic_2pc, .shard_fee, .tx_coordinator, .partition_detect, .split_brain, .auto_heal, .partition_tolerance, .swarm_10m, .community_5m, .earning_boost, .massive_gossip, .zk_rollup_v2, .snark_generate, .recursive_compose, .l2_fee_collect, .cross_shard_tx_v2, .atomic_2pc_v2, .shard_fee_v2, .inter_shard_sync_v2, .formal_verify_v2, .property_test_v2, .invariant_check_v2, .proof_generate_v2, .swarm_100m_v2, .community_50m_v2, .earning_moonshot_v2, .gossip_v3_v2, .global_dominance_v2, .world_adoption_v2, .tri_to_one_v2, .ecosystem_complete_v2, .ouroboros_evolve_v2, .infinite_scale_v2, .universal_reserve_v2, .eternal_uptime_v2, .tri_to_ten_v2, .mass_adoption_v2, .exchange_listing_v2, .universal_wallet_v2, .tri_to_hundred_v2, .universal_adoption_v2, .exchange_v2_v2, .global_wallet_v2, .swarm_10m_v2, .community_5m_v2, .earning_ultimate_v2, .node_discovery_10m_v2, .swarm_1b_v2, .community_500m_v2, .earning_god_mode_v2, .node_discovery_1b_v2, .ternary_nn_v2, .recursive_self_train_v2, .contribution_reward_v2, .neural_consensus_v2, .tri_to_1000_v2, .universal_reserve_v2_v2, .global_dominance_v2_v2, .eternal_governance_v2_v2, .trinity_beyond_v2, .infinite_scale_v2_v2, .multiverse_dominance_v2, .eternal_evolution_v2, .trinity_absolute_v3, .infinite_tri_v3, .eternal_victory_v3, .multiverse_complete_v3 => true,
        else => false,
    };
}

/// Convert GoldenChain message to canvas ChatMsgType
fn chainMsgToCanvasType(chain_msg: *const golden_chain.ChainMessage) ChatMsgType {
    return switch (chain_msg.msg_type) {
        .User => .user,
        .ChainStep => if (chain_msg.node) |node| switch (node) {
            .GoalParse => .chain_goal_parse,
            .Decompose => .chain_decompose,
            .Schedule => .chain_schedule,
            .Execute => .chain_execute,
            .Monitor => .chain_monitor,
            .Adapt => .chain_adapt,
            .Synthesize => .chain_synthesize,
            .Deliver => .chain_deliver,
        } else .ai,
        .ToolResult => .tool_result,
        .RoutingInfo => .routing_info,
        .Reflection => .reflection,
        .AgentState => .log,
        .Error => .agent_error,
        .ProvenanceStep => .provenance_step,
        .TruthVerification => .truth_verification,
        .QuarkStep => .quark_step,
        .GluonEntangle => .gluon_entangle,
        .DAGVisualization => .dag_visualization,
        .RewardSummary => .reward_summary,
        .CollapseToggle => .collapse_toggle,
        .ShareLinkGenerated => .share_link_generated,
        .StakingEvent => .staking_event,
        .SelfRepairEvent => .self_repair_event,
        .ImmortalPersist => .immortal_persist,
        .EvolutionStep => .evolution_step,
        .ChainHealthCheck => .chain_health_check,
        .FaucetClaim => .faucet_claim,
        .PublicLaunch => .public_launch,
        .CanvasSync => .canvas_sync,
        .FaucetDistribution => .faucet_distribution,
        .DecentralSync => .decentral_sync,
        .NodeConsensus => .node_consensus,
        .NetworkHealth => .network_health,
        .AgentOSInit => .agent_os_init,
        .MainnetGenesis => .mainnet_genesis,
        .DAOVote => .dao_vote,
        .SwarmSync => .swarm_sync,
        .TokenMint => .token_mint,
        .MainnetLaunch => .mainnet_launch,
        .CommunityOnboard => .community_onboard,
        .NodeDiscovery => .node_discovery,
        .GovernanceExec => .governance_exec,
        .SwarmOrchestrate => .swarm_orchestrate,
        .SwarmFailover => .swarm_failover,
        .SwarmTelemetry => .swarm_telemetry,
        .SwarmReplication => .swarm_replication,
        .SwarmScale => .swarm_scale,
        .RewardDistribute => .reward_distribute,
        .DAOGovernanceLive => .dao_governance_live,
        .NodeScaling => .node_scaling,
        // v2.7: Community Nodes v1.0 + Gossip Protocol + DHT 10k+
        .CommunityNode => .community_node,
        .GossipBroadcast => .gossip_broadcast,
        .DHTLookup => .dht_lookup,
        .CommunitySyncEvent => .community_sync,
        // v2.8: DAO Full Governance v1.0
        .DAODelegation => .dao_delegate,
        .TimelockVote => .timelock_vote,
        .ProposalExecution => .proposal_exec,
        .YieldFarmingEvent => .yield_farming,
        // v2.9: Cross-Chain Bridge v1.0
        .CrossChainBridge => .cross_chain_bridge,
        .AtomicSwap => .atomic_swap,
        .StateReplication => .state_replicate,
        .BridgeSyncEvent => .bridge_sync,
        // v2.10: Trinity DAO Full Governance v1.0 + $TRI Staking Rewards
        .DAOFullGovernance => .dao_full_governance,
        .TRIStaking => .tri_staking,
        .RewardDistribution => .reward_distribute_v2,
        .StakingValidation => .staking_validate,
        // v2.11: Swarm 100k + Community 50k (Sharded Gossip + Hierarchical DHT)
        .Swarm100kScale => .swarm_100k,
        .GossipShardEvent => .gossip_shard,
        .DHTHierarchicalSync => .dht_sync,
        .Community50kOnboard => .community_50k,
        // v2.12: Zero-Knowledge Bridge v1.0 (ZK-Proof Verification + Privacy Transfers)
        .ZKBridgeVerification => .zk_bridge,
        .ZKProofGenerated => .zk_proof,
        .PrivacyTransfer => .privacy_transfer,
        .CrossChainSyncEvent => .cross_chain_sync_v2,
        // v2.13: Layer-2 Rollup v1.0
        .L2RollupSubmission => .l2_rollup,
        .OptimisticVerification => .optimistic_verify,
        .StateChannelUpdate => .state_channel,
        .BatchCompressionEvent => .batch_compress,
        // v2.14: Dynamic Shard Rebalancing v1.0
        .DynamicShardEvent => .dynamic_shard,
        .ShardLoadUpdate => .shard_split,
        .AdaptiveDHTEvent => .dht_adapt,
        .GossipReshardEvent => .shard_merge,
        // v2.15: Swarm 1M + Community 500k
        .SwarmMillionEvent => .swarm_million,
        .CommunityNodeUpdate => .community_node_v2,
        .HierarchicalGossipEvent => .hierarchical_gossip,
        .GeographicShardEvent => .geographic_shard,
        // v2.16: ZK-Rollup v2.0
        .ZkSnarkProofEvent => .zk_snark_proof,
        .RecursiveProofUpdate => .recursive_proof,
        .L2ScalingEvent => .l2_scaling,
        .RollupBatchEvent => .rollup_batch,
        // v2.17: Cross-Shard Transactions v1.0
        .CrossShardTxEvent => .cross_shard_tx,
        .Atomic2pcUpdate => .atomic_2pc,
        .ShardFeeEvent => .shard_fee,
        .TxCoordinatorEvent => .tx_coordinator,
        .PartitionDetectEvent => .partition_detect,
        .SplitBrainUpdate => .split_brain,
        .AutoHealEvent => .auto_heal,
        .PartitionToleranceEvent => .partition_tolerance,
        // v2.19: Swarm 10M + Community 5M
        .Swarm10MEvent => .swarm_10m,
        .Community5MUpdate => .community_5m,
        .EarningBoostEvent => .earning_boost,
        .MassiveGossipEvent => .massive_gossip,
        // v2.20: ZK-Rollup v2.0
        .ZkRollupV2Event => .zk_rollup_v2,
        .SnarkGenerateUpdate => .snark_generate,
        .RecursiveComposeEvent => .recursive_compose,
        .L2FeeCollectEvent => .l2_fee_collect,
        // v2.21: Cross-Shard Transactions v1.0
        .CrossShardTxEventV2 => .cross_shard_tx_v2,
        .Atomic2PCUpdate => .atomic_2pc_v2,
        .ShardFeeEventV2 => .shard_fee_v2,
        .InterShardSyncEvent => .inter_shard_sync_v2,
        // v2.22: Formal Verification v1.0
        .FormalVerifyEvent => .formal_verify_v2,
        .PropertyTestUpdate => .property_test_v2,
        .InvariantCheckEvent => .invariant_check_v2,
        .ProofGenerateEvent => .proof_generate_v2,
        // v2.23: Swarm 100M + Community 50M
        .Swarm100MEvent => .swarm_100m_v2,
        .Community50MUpdate => .community_50m_v2,
        .EarningMoonshotEvent => .earning_moonshot_v2,
        .GossipV3Event => .gossip_v3_v2,
        // v2.24: Trinity Global Dominance v1.0
        .GlobalDominanceEvent => .global_dominance_v2,
        .WorldAdoptionUpdate => .world_adoption_v2,
        .TriToOneEvent => .tri_to_one_v2,
        .EcosystemCompleteEvent => .ecosystem_complete_v2,
        // v2.25: Trinity Eternal v1.0
        .OuroborosEvolveEvent => .ouroboros_evolve_v2,
        .InfiniteScaleUpdate => .infinite_scale_v2,
        .UniversalReserveEvent => .universal_reserve_v2,
        .EternalUptimeEvent => .eternal_uptime_v2,
        // v2.26
        .TriToTenEvent => .tri_to_ten_v2,
        .MassAdoptionUpdate => .mass_adoption_v2,
        .ExchangeListingEvent => .exchange_listing_v2,
        .UniversalWalletEvent => .universal_wallet_v2,
        // v2.27
        .TriToHundredEvent => .tri_to_hundred_v2,
        .UniversalAdoptionUpdate => .universal_adoption_v2,
        .ExchangeV2Event => .exchange_v2_v2,
        .GlobalWalletEvent => .global_wallet_v2,
        // v2.28
        .Swarm10MEventV2 => .swarm_10m_v2,
        .Community5MUpdateV2 => .community_5m_v2,
        .EarningUltimateEvent => .earning_ultimate_v2,
        .NodeDiscovery10MEvent => .node_discovery_10m_v2,
        .Swarm1BEvent => .swarm_1b_v2,
        .Community500MUpdate => .community_500m_v2,
        .EarningGodModeEvent => .earning_god_mode_v2,
        .NodeDiscovery1BEvent => .node_discovery_1b_v2,
        // v2.30: Trinity Neural Network v1.0
        .TernaryNNEvent => .ternary_nn_v2,
        .RecursiveSelfTrainUpdate => .recursive_self_train_v2,
        .ContributionRewardEvent => .contribution_reward_v2,
        .NeuralConsensusEvent => .neural_consensus_v2,
        .TRITo1000Event => .tri_to_1000_v2,
        .UniversalReserveV2Update => .universal_reserve_v2_v2,
        .GlobalDominanceV2Event => .global_dominance_v2_v2,
        .EternalGovernanceV2Event => .eternal_governance_v2_v2,
        // v2.32: Trinity Beyond v1.0
        .TrinityBeyondEvent => .trinity_beyond_v2,
        .InfiniteScaleUpdateV2 => .infinite_scale_v2_v2,
        .MultiVerseDominanceEvent => .multiverse_dominance_v2,
        .EternalEvolutionEvent => .eternal_evolution_v2,
        // v3.0: Trinity Absolute v1.0
        .TrinityAbsoluteEvent => .trinity_absolute_v3,
        .InfiniteTRIUpdate => .infinite_tri_v3,
        .EternalVictoryEvent => .eternal_victory_v3,
        .MultiVerseCompleteEvent => .multiverse_complete_v3,
    };
}

/// Draw a pulsing Chakra-colored circle indicator (sound wave dot)
fn drawChainIndicator(x: f32, y: f32, msg_type: ChatMsgType, time: f32, fs: f32) void {
    const color = getChainMsgColor(msg_type, 200);
    const radius = 5.0 * fs;
    const pulse: f32 = @sin(time * 4.0) * 0.3 + 0.7;

    // Outer glow
    const glow_alpha: u8 = @intFromFloat(@max(0, @min(255, 50.0 * pulse)));
    rl.DrawCircle(@intFromFloat(x), @intFromFloat(y), radius * 1.5, rl.Color{ .r = color.r, .g = color.g, .b = color.b, .a = glow_alpha });

    // Inner solid circle
    rl.DrawCircle(@intFromFloat(x), @intFromFloat(y), radius, color);

    // Center bright dot
    const center_alpha: u8 = @intFromFloat(@max(0, @min(255, 150.0 * pulse)));
    rl.DrawCircle(@intFromFloat(x), @intFromFloat(y), radius * 0.35, rl.Color{ .r = 255, .g = 255, .b = 255, .a = center_alpha });
}

// =============================================================================
// HYPER TERMINAL STYLE COLORS (from theme.zig - SINGLE SOURCE OF TRUTH)
// @bitCast converts theme.Color to rl.Color (same extern struct layout)
// =============================================================================

fn toRl(c: theme.Color) rl.Color {
    return @bitCast(c);
}

// === SWITCHABLE surface colors (var — re-read from theme on toggle) ===
// Initialized with comptime dark defaults; reloadThemeAliases() updates at runtime.
var BG_BLACK: rl.Color = @bitCast(theme.colors.bg);
var TEXT_WHITE: rl.Color = @bitCast(theme.colors.text);
var MUTED_GRAY: rl.Color = @bitCast(theme.colors.text_muted);
var BORDER_SUBTLE: rl.Color = @bitCast(theme.colors.border);
var VOID_BLACK: rl.Color = @bitCast(theme.colors.bg);
var NOVA_WHITE: rl.Color = @bitCast(theme.colors.text);
var GLASS_BG: rl.Color = @bitCast(theme.colors.bg_panel);
var GLASS_BORDER: rl.Color = @bitCast(theme.colors.border);
var BG_SURFACE: rl.Color = @bitCast(theme.colors.bg_surface);
var BG_INPUT: rl.Color = @bitCast(theme.colors.bg_input);
var BG_BAR: rl.Color = @bitCast(theme.colors.bg_bar);
var BG_HOVER: rl.Color = @bitCast(theme.colors.bg_hover);
var SEPARATOR: rl.Color = @bitCast(theme.colors.separator);
var BORDER_LIGHT: rl.Color = @bitCast(theme.colors.border_light);
var TEXT_DIM: rl.Color = @bitCast(theme.colors.text_dim);
var TEXT_HINT: rl.Color = @bitCast(theme.colors.text_hint);
var CONTENT_TEXT: rl.Color = @bitCast(theme.colors.content_text);

// Chat panel colors (theme-switchable)
var CHAT_TEXT: rl.Color = @bitCast(theme.colors.chat_text);
var CHAT_LABEL_USER: rl.Color = @bitCast(theme.colors.chat_label_user);
var CHAT_LABEL_AI: rl.Color = @bitCast(theme.colors.chat_label_ai);
var CHAT_BUBBLE_USER: rl.Color = @bitCast(theme.colors.chat_bubble_user);
var CHAT_BUBBLE_AI: rl.Color = @bitCast(theme.colors.chat_bubble_ai);
var CHAT_BUBBLE_BORDER: rl.Color = @bitCast(theme.colors.chat_bubble_border);
var CHAT_INPUT_BG: rl.Color = @bitCast(theme.colors.chat_input_bg);
var CHAT_INPUT_BORDER: rl.Color = @bitCast(theme.colors.chat_input_border);
var CHAT_INPUT_TEXT: rl.Color = @bitCast(theme.colors.chat_input_text);
var SACRED_HEADER_BG: rl.Color = @bitCast(theme.colors.sacred_header_bg);
var SACRED_HEADER_TEXT: rl.Color = @bitCast(theme.colors.sacred_header_text);

// === ACCENT colors (const — same in dark and light) ===
const HYPER_MAGENTA: rl.Color = @bitCast(theme.accents.magenta);
const HYPER_CYAN: rl.Color = @bitCast(theme.accents.cyan);
const HYPER_GREEN: rl.Color = @bitCast(theme.accents.green);
const HYPER_YELLOW: rl.Color = @bitCast(theme.accents.yellow);
const HYPER_RED: rl.Color = @bitCast(theme.accents.red);
const ACCENT_GREEN: rl.Color = @bitCast(theme.accents.green);
const NEON_CYAN: rl.Color = @bitCast(theme.accents.cyan);
const NEON_MAGENTA: rl.Color = @bitCast(theme.accents.magenta);
const NEON_GREEN: rl.Color = @bitCast(theme.accents.green);
const NEON_GOLD: rl.Color = @bitCast(theme.accents.yellow);
const NEON_PURPLE: rl.Color = @bitCast(theme.accents.magenta);
const SINK_RED: rl.Color = @bitCast(theme.accents.red);
const GLASS_GLOW: rl.Color = @bitCast(theme.accents.glow_magenta);
const RECORDING_RED: rl.Color = @bitCast(theme.accents.recording_red);
const GOLD: rl.Color = @bitCast(theme.accents.gold);
const BLUE: rl.Color = @bitCast(theme.accents.blue);
const ORANGE: rl.Color = @bitCast(theme.accents.orange);
const PURPLE: rl.Color = @bitCast(theme.accents.purple);
const LOGO_GREEN: rl.Color = @bitCast(theme.accents.logo_green);

// Panel traffic light buttons (const — always same)
const BTN_CLOSE: rl.Color = @bitCast(theme.panel.btn_close);
const BTN_MINIMIZE: rl.Color = @bitCast(theme.panel.btn_minimize);
const BTN_MAXIMIZE: rl.Color = @bitCast(theme.panel.btn_maximize);

// File type colors (const — accent-based)
const FILE_FOLDER: rl.Color = @bitCast(theme.accents.file_folder);
const FILE_ZIG: rl.Color = @bitCast(theme.accents.file_zig);
const FILE_CODE: rl.Color = @bitCast(theme.accents.file_code);
const FILE_IMAGE: rl.Color = @bitCast(theme.accents.file_image);
const FILE_AUDIO: rl.Color = @bitCast(theme.accents.file_audio);
const FILE_DOCUMENT: rl.Color = @bitCast(theme.accents.file_document);
const FILE_DATA: rl.Color = @bitCast(theme.accents.file_data);
const FILE_UNKNOWN: rl.Color = @bitCast(theme.accents.file_unknown);

// Helper: apply runtime alpha to a color
fn withAlpha(c: rl.Color, alpha: u8) rl.Color {
    return rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = alpha };
}

fn containsBytes(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

// Accent text color — vivid on dark theme, dark monochrome on light theme
// Use for any text that would be accent-colored; keeps icons/borders/decorative elements vivid.
fn accentText(accent: rl.Color, alpha: u8) rl.Color {
    // Dark theme: vivid accent color. Light theme: pure black for max contrast
    return if (theme.isDark()) withAlpha(accent, alpha) else rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = alpha };
}

// Reload all var aliases from theme after toggle()
fn reloadThemeAliases() void {
    BG_BLACK = @bitCast(theme.bg);
    TEXT_WHITE = @bitCast(theme.text);
    MUTED_GRAY = @bitCast(theme.text_muted);
    BORDER_SUBTLE = @bitCast(theme.border);
    VOID_BLACK = @bitCast(theme.bg);
    NOVA_WHITE = @bitCast(theme.text);
    GLASS_BG = @bitCast(theme.bg_panel);
    GLASS_BORDER = @bitCast(theme.border);
    BG_SURFACE = @bitCast(theme.bg_surface);
    BG_INPUT = @bitCast(theme.bg_input);
    BG_BAR = @bitCast(theme.bg_bar);
    BG_HOVER = @bitCast(theme.bg_hover);
    SEPARATOR = @bitCast(theme.separator);
    BORDER_LIGHT = @bitCast(theme.border_light);
    TEXT_DIM = @bitCast(theme.text_dim);
    TEXT_HINT = @bitCast(theme.text_hint);
    CONTENT_TEXT = @bitCast(theme.content_text);
    CHAT_TEXT = @bitCast(theme.chat_text);
    CHAT_LABEL_USER = @bitCast(theme.chat_label_user);
    CHAT_LABEL_AI = @bitCast(theme.chat_label_ai);
    CHAT_BUBBLE_USER = @bitCast(theme.chat_bubble_user);
    CHAT_BUBBLE_AI = @bitCast(theme.chat_bubble_ai);
    CHAT_BUBBLE_BORDER = @bitCast(theme.chat_bubble_border);
    CHAT_INPUT_BG = @bitCast(theme.chat_input_bg);
    CHAT_INPUT_BORDER = @bitCast(theme.chat_input_border);
    CHAT_INPUT_TEXT = @bitCast(theme.chat_input_text);
    SACRED_HEADER_BG = @bitCast(theme.sacred_header_bg);
    SACRED_HEADER_TEXT = @bitCast(theme.sacred_header_text);
}

// =============================================================================
// TRINITY LOGO ANIMATION — 27 BLOCKS ASSEMBLY
// Logo assembles from 27 triangular blocks flying from all sides
// =============================================================================

const LogoBlock = struct {
    // Polygon vertices (up to 5 points per shape)
    v: [5]rl.Vector2,
    count: u8,
    // Animation state
    offset: rl.Vector2, // Current animated offset from target
    rotation: f32, // Current rotation
    scale: f32, // Current scale
    delay: f32, // Animation start delay
    center: rl.Vector2, // Center of the block for positioning
    // Assembly animation velocity (spring physics)
    anim_vx: f32,
    anim_vy: f32,
    anim_vr: f32,
    // Cursor physics
    push_x: f32, // Current push displacement from cursor
    push_y: f32,
    push_rot: f32, // Rotation from cursor push
    vel_x: f32, // Velocity for spring-back
    vel_y: f32,
    vel_rot: f32,
};

const sacred_worlds = @import("trinity_canvas/sacred_worlds.zig");

const LogoAnimation = struct {
    blocks: [27]LogoBlock,
    time: f32,
    duration: f32,
    is_complete: bool,
    logo_scale: f32, // Scale the logo to fit screen
    logo_offset: rl.Vector2, // Center the logo on screen
    hovered_block: i32, // Index of block under cursor (-1 = none)
    clicked_block: i32, // Block clicked this frame (-1 = none)

    // SVG viewBox: 596 x 526, center at ~298, 263
    const SVG_WIDTH: f32 = 596.0;
    const SVG_HEIGHT: f32 = 526.0;
    const SVG_CENTER_X: f32 = 298.0;
    const SVG_CENTER_Y: f32 = 263.0;

    pub fn init(screen_w: f32, screen_h: f32) LogoAnimation {
        var self = LogoAnimation{
            .blocks = undefined,
            .time = 0,
            .duration = 2.5, // Fast assembly animation
            .is_complete = false,
            .logo_scale = @min(screen_w / SVG_WIDTH, screen_h / SVG_HEIGHT) * 0.35,
            .logo_offset = .{ .x = screen_w / 2, .y = screen_h / 2 },
            .hovered_block = -1,
            .clicked_block = -1,
        };

        // 27 blocks parsed from assets/999.svg
        const raw_blocks = [27][5][2]f32{
            // Block 0
            .{ .{ 296.767, 435.228 }, .{ 236.563, 329.491 }, .{ 211.501, 373.56 }, .{ 296.767, 523.496 }, .{ 0, 0 } },
            // Block 1
            .{ .{ 235.71, 328.065 }, .{ 177.201, 224.57 }, .{ 126.893, 224.57 }, .{ 210.755, 372.182 }, .{ 0, 0 } },
            // Block 2
            .{ .{ 116.304, 118.557 }, .{ 175.824, 223.238 }, .{ 126.022, 223.26 }, .{ 42.177, 74.909 }, .{ 0, 0 } },
            // Block 3
            .{ .{ 43.019, 73.555 }, .{ 117.106, 116.68 }, .{ 235.544, 116.68 }, .{ 211.46, 73.525 }, .{ 0, 0 } },
            // Block 4
            .{ .{ 213.1, 73.52 }, .{ 237.875, 116.409 }, .{ 356.58, 116.741 }, .{ 381.646, 73.509 }, .{ 0, 0 } },
            // Block 5
            .{ .{ 477.724, 116.854 }, .{ 358.701, 116.802 }, .{ 383.404, 73.803 }, .{ 550.969, 73.877 }, .{ 0, 0 } },
            // Block 6
            .{ .{ 477.056, 118.915 }, .{ 418.023, 223.109 }, .{ 468.886, 223.131 }, .{ 553.143, 74.338 }, .{ 0, 0 } },
            // Block 7
            .{ .{ 358.646, 327.197 }, .{ 384.221, 372.152 }, .{ 468.192, 224.521 }, .{ 416.976, 224.579 }, .{ 0, 0 } },
            // Block 8
            .{ .{ 298.138, 434.656 }, .{ 357.793, 328.533 }, .{ 383.376, 373.808 }, .{ 298.138, 523.876 }, .{ 0, 0 } },
            // Block 9
            .{ .{ 297.148, 352.965 }, .{ 260.326, 288.171 }, .{ 237.943, 327.796 }, .{ 297.148, 432.004 }, .{ 0, 0 } },
            // Block 10
            .{ .{ 259.613, 286.78 }, .{ 224.371, 224.818 }, .{ 179.6, 224.818 }, .{ 237.048, 326.301 }, .{ 0, 0 } },
            // Block 11
            .{ .{ 223.536, 223.354 }, .{ 187.285, 159.675 }, .{ 120.085, 120.508 }, .{ 178.781, 223.779 }, .{ 0, 0 } },
            // Block 12
            .{ .{ 121.863, 119.193 }, .{ 187.937, 158.358 }, .{ 260.042, 158.355 }, .{ 237.348, 118.746 }, .{ 0, 0 } },
            // Block 13
            .{ .{ 261.857, 158.313 }, .{ 333.559, 158.29 }, .{ 356.01, 118.829 }, .{ 239.269, 118.829 }, .{ 0, 0 } },
            // Block 14
            .{ .{ 335.294, 158.3 }, .{ 407.736, 158.226 }, .{ 474.496, 118.923 }, .{ 357.761, 118.923 }, .{ 0, 0 } },
            // Block 15
            .{ .{ 408.358, 159.547 }, .{ 372.034, 223.421 }, .{ 416.476, 223.315 }, .{ 475.012, 120.916 }, .{ 0, 0 } },
            // Block 16
            .{ .{ 336.052, 286.778 }, .{ 358.165, 325.872 }, .{ 415.649, 224.808 }, .{ 371.244, 224.759 }, .{ 0, 0 } },
            // Block 17
            .{ .{ 298.893, 352.826 }, .{ 335.156, 288.19 }, .{ 357.382, 327.328 }, .{ 298.893, 430.179 }, .{ 0, 0 } },
            // Block 18
            .{ .{ 296.258, 272.716 }, .{ 282.337, 248.309 }, .{ 260.496, 286.972 }, .{ 296.258, 349.653 }, .{ 0, 0 } },
            // Block 19
            .{ .{ 259.547, 285.675 }, .{ 281.633, 246.705 }, .{ 269.336, 225.016 }, .{ 225.274, 224.996 }, .{ 0, 0 } },
            // Block 20
            .{ .{ 254.956, 199.798 }, .{ 268.406, 223.578 }, .{ 224.465, 223.598 }, .{ 189.037, 161.206 }, .{ 0, 0 } },
            // Block 21
            .{ .{ 255.476, 198.549 }, .{ 282.068, 198.538 }, .{ 260.192, 160.039 }, .{ 189.751, 160.07 }, .{ 0, 0 } },
            // Block 22
            .{ .{ 261.646, 160.062 }, .{ 283.582, 198.505 }, .{ 309.702, 198.505 }, .{ 331.733, 160.062 }, .{ 0, 0 } },
            // Block 23
            .{ .{ 338.542, 198.607 }, .{ 311.435, 198.595 }, .{ 333.423, 160.068 }, .{ 404.244, 160.099 }, .{ 0, 0 } },
            // Block 24
            .{ .{ 338.85, 199.978 }, .{ 325.556, 223.591 }, .{ 369.518, 223.61 }, .{ 404.907, 161.243 }, .{ 0, 0 } },
            // Block 25
            .{ .{ 334.38, 285.625 }, .{ 312.392, 246.733 }, .{ 324.681, 224.989 }, .{ 368.779, 224.969 }, .{ 0, 0 } },
            // Block 26
            .{ .{ 298.025, 272.637 }, .{ 311.561, 248.279 }, .{ 333.297, 287.01 }, .{ 298.025, 349.402 }, .{ 0, 0 } },
        };
        const counts = [27]u8{ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 };

        for (0..27) |i| {
            var center_x: f32 = 0;
            var center_y: f32 = 0;
            const cnt = counts[i];

            // Convert raw vertices to rl.Vector2 and center relative to SVG center
            for (0..cnt) |j| {
                const x = raw_blocks[i][j][0] - SVG_CENTER_X;
                const y = raw_blocks[i][j][1] - SVG_CENTER_Y;
                self.blocks[i].v[j] = .{ .x = x, .y = y };
                center_x += x;
                center_y += y;
            }
            center_x /= @floatFromInt(cnt);
            center_y /= @floatFromInt(cnt);
            self.blocks[i].count = cnt;
            self.blocks[i].center = .{ .x = center_x, .y = center_y };

            // Each block flies straight from its own direction — no chaos
            // Direction = from center through block's position, extended far out
            const dir_len = @sqrt(center_x * center_x + center_y * center_y);
            const norm_x = if (dir_len > 0.1) center_x / dir_len else @cos(@as(f32, @floatFromInt(i)) * TAU / 27.0);
            const norm_y = if (dir_len > 0.1) center_y / dir_len else @sin(@as(f32, @floatFromInt(i)) * TAU / 27.0);
            const distance: f32 = 800.0; // Shorter travel distance — faster entrance
            self.blocks[i].offset = .{
                .x = norm_x * distance,
                .y = norm_y * distance,
            };
            self.blocks[i].rotation = 0; // No rotation — flat, clean
            self.blocks[i].scale = 1.0; // Full size from start
            self.blocks[i].delay = 0; // All start simultaneously
            self.blocks[i].anim_vx = 0;
            self.blocks[i].anim_vy = 0;
            self.blocks[i].anim_vr = 0;
            self.blocks[i].push_x = 0;
            self.blocks[i].push_y = 0;
            self.blocks[i].push_rot = 0;
            self.blocks[i].vel_x = 0;
            self.blocks[i].vel_y = 0;
            self.blocks[i].vel_rot = 0;
        }

        return self;
    }

    pub fn update(self: *LogoAnimation, dt: f32) void {
        if (self.is_complete) return;

        self.time += dt;

        var all_done = true;
        for (&self.blocks) |*block| {
            const t = @max(0, self.time - block.delay);
            const progress = @min(1.0, t / self.duration);

            // Two phases:
            // Phase 1 (0–0.7): straight linear flight toward center
            // Phase 2 (0.7–1.0): spring compression + bounce
            const arrival = 0.7; // when blocks "arrive" and spring kicks in

            if (progress < arrival) {
                // Straight flight — exponential ease-in toward center
                const speed = 4.5 * dt;
                block.offset.x -= block.offset.x * speed;
                block.offset.y -= block.offset.y * speed;

                // Carry momentum into spring phase
                block.anim_vx = -block.offset.x * 0.4;
                block.anim_vy = -block.offset.y * 0.4;
                block.anim_vr = 0;
            } else {
                // Spring phase — snappy elastic settle
                const spring_k: f32 = 28.0;
                const damp: f32 = 0.86;

                // Spring force pulls offset to zero
                block.anim_vx += (-block.offset.x * spring_k) * dt;
                block.anim_vy += (-block.offset.y * spring_k) * dt;
                block.anim_vx *= damp;
                block.anim_vy *= damp;
                block.offset.x += block.anim_vx * dt * 60.0;
                block.offset.y += block.anim_vy * dt * 60.0;

                // Spring on rotation
                block.anim_vr += (-block.rotation * spring_k) * dt;
                block.anim_vr *= damp;
                block.rotation += block.anim_vr * dt * 60.0;

                // Scale settles to 1.0
                block.scale += (1.0 - block.scale) * 0.1;
            }

            // Check if settled
            const dist = @sqrt(block.offset.x * block.offset.x + block.offset.y * block.offset.y);
            const vel = @sqrt(block.anim_vx * block.anim_vx + block.anim_vy * block.anim_vy);
            if (dist > 0.3 or vel > 0.3 or @abs(block.rotation) > 0.003) {
                all_done = false;
            }
        }

        // Brief pause after assembly before transitioning
        if (all_done and self.time > self.duration + 0.5) {
            self.is_complete = true;
        }
    }

    /// Point-in-polygon test (ray casting)
    fn pointInPoly(verts: [5]rl.Vector2, cnt: u8, px: f32, py: f32) bool {
        var inside = false;
        var j: usize = cnt - 1;
        var i: usize = 0;
        while (i < cnt) : (i += 1) {
            const yi = verts[i].y;
            const yj = verts[j].y;
            const xi = verts[i].x;
            const xj = verts[j].x;
            if (((yi > py) != (yj > py)) and
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi))
            {
                inside = !inside;
            }
            j = i;
        }
        return inside;
    }

    /// Highlight block under cursor + detect clicks
    pub fn applyMouse(self: *LogoAnimation, mouse_x: f32, mouse_y: f32, _: f32, mouse_pressed: bool) void {
        const scale = self.logo_scale;
        const ox = self.logo_offset.x;
        const oy = self.logo_offset.y;

        self.hovered_block = -1;
        self.clicked_block = -1;

        for (self.blocks, 0..) |block, i| {
            var verts: [5]rl.Vector2 = undefined;
            const cnt = block.count;

            const cos_r = @cos(block.rotation);
            const sin_r = @sin(block.rotation);

            for (0..cnt) |j| {
                var bx = block.v[j].x * block.scale;
                var by = block.v[j].y * block.scale;

                // Apply rotation around block center (must match draw())
                const ddx = bx - block.center.x * block.scale;
                const ddy = by - block.center.y * block.scale;
                bx = block.center.x * block.scale + ddx * cos_r - ddy * sin_r;
                by = block.center.y * block.scale + ddx * sin_r + ddy * cos_r;

                bx += block.offset.x;
                by += block.offset.y;

                verts[j] = .{
                    .x = ox + bx * scale,
                    .y = oy + by * scale,
                };
            }

            if (pointInPoly(verts, cnt, mouse_x, mouse_y)) {
                self.hovered_block = @intCast(i);
                if (mouse_pressed) {
                    self.clicked_block = @intCast(i);
                }
            }
        }
    }

    pub fn draw(self: *const LogoAnimation) void {
        const scale = self.logo_scale;
        const ox = self.logo_offset.x;
        const oy = self.logo_offset.y;

        // Hover color: highlight petal on hover (switches with theme)
        const highlight_color: rl.Color = @bitCast(theme.logo_highlight);

        // Petals — spider web look (switches with theme: black on dark, white on light)
        const petal_color: rl.Color = @bitCast(theme.logo_petal);

        // Outline — spider web threads (switches with theme)
        const outline_color: rl.Color = @bitCast(theme.logo_outline);

        for (self.blocks, 0..) |block, idx| {
            // v3.0: Block 2 pulses cyan when ANY Ralph agent is active (healthy + loop > 0)
            const is_ralph_active = blk: {
                var rai: usize = 0;
                while (rai < g_ralph_agent_count) : (rai += 1) {
                    if (g_ralph_agents[rai].loop > 0 and g_ralph_agents[rai].is_healthy) break :blk true;
                }
                break :blk false;
            };
            const ralph_petal_glow = if (idx == 2 and is_ralph_active)
                rl.Color{ .r = 0, .g = 0xCC, .b = 0xFF, .a = @intFromFloat(@max(40, @min(120, @sin(frame_time * 3.0) * 40 + 80))) }
            else
                petal_color;
            const fill_color = if (self.hovered_block >= 0 and idx == @as(usize, @intCast(self.hovered_block))) highlight_color else ralph_petal_glow;
            var verts: [5]rl.Vector2 = undefined;
            const cnt = block.count;

            const cos_r = @cos(block.rotation);
            const sin_r = @sin(block.rotation);

            for (0..cnt) |j| {
                var bx = block.v[j].x * block.scale;
                var by = block.v[j].y * block.scale;

                const ddx = bx - block.center.x * block.scale;
                const ddy = by - block.center.y * block.scale;
                bx = block.center.x * block.scale + ddx * cos_r - ddy * sin_r;
                by = block.center.y * block.scale + ddx * sin_r + ddy * cos_r;

                bx += block.offset.x;
                by += block.offset.y;

                verts[j] = .{
                    .x = ox + bx * scale,
                    .y = oy + by * scale,
                };
            }

            // Fill
            if (cnt >= 3) {
                var k: usize = 1;
                while (k < cnt - 1) : (k += 1) {
                    rl.DrawTriangle(verts[0], verts[k], verts[k + 1], fill_color);
                    rl.DrawTriangle(verts[0], verts[k + 1], verts[k], fill_color);
                }
            }

            // Outline — integer-width line to avoid sub-pixel artifacts
            var m: usize = 0;
            while (m < cnt) : (m += 1) {
                const next = (m + 1) % cnt;
                rl.DrawLineEx(verts[m], verts[next], 1.0, outline_color);
            }
        }
    }
};

// =============================================================================
// =============================================================================
// SACRED FORMULA PARTICLES - Fibonacci spiral orbiting formulas
// =============================================================================

const FormulaParticle = struct {
    text: [48:0]u8,
    text_len: u8,
    desc: [80:0]u8,
    desc_len: u8,
    // Fibonacci spiral parameters
    base_angle: f32, // base position on spiral
    orbit_radius: f32, // distance from center
    orbit_speed: f32, // angular velocity (rad/s)
    angle_offset: f32, // current offset from mouse push
    expanded: bool,
    expand_anim: f32,

    fn init(text: []const u8, desc: []const u8, base_angle_val: f32, radius: f32, speed: f32) FormulaParticle {
        var p: FormulaParticle = undefined;
        const tlen = @min(text.len, 47);
        @memcpy(p.text[0..tlen], text[0..tlen]);
        p.text[tlen] = 0;
        p.text_len = @intCast(tlen);
        const dlen = @min(desc.len, 79);
        @memcpy(p.desc[0..dlen], desc[0..dlen]);
        p.desc[dlen] = 0;
        p.desc_len = @intCast(dlen);
        p.base_angle = base_angle_val;
        p.orbit_radius = radius;
        p.orbit_speed = speed;
        p.angle_offset = 0;
        p.expanded = false;
        p.expand_anim = 0;
        return p;
    }

    fn getPos(self: *const FormulaParticle, time_val: f32, cx: f32, cy: f32) struct { x: f32, y: f32 } {
        const angle = self.base_angle + time_val * self.orbit_speed + self.angle_offset;
        return .{
            .x = cx + @cos(angle) * self.orbit_radius,
            .y = cy + @sin(angle) * self.orbit_radius,
        };
    }

    fn update(self: *FormulaParticle, dt: f32, time_val: f32, mouse_x: f32, mouse_y: f32, mouse_pressed: bool, cx: f32, cy: f32) void {
        const pos = self.getPos(time_val, cx, cy);

        // Check if mouse is near this formula
        const ddx = pos.x - mouse_x;
        const ddy = pos.y - mouse_y;
        const dist = @sqrt(ddx * ddx + ddy * ddy + 1.0);
        const hover_radius: f32 = 60.0;

        if (dist < hover_radius) {
            // STOP: counter the orbital rotation so formula stays in place
            self.angle_offset -= self.orbit_speed * dt;
        }

        // Slowly return angle_offset to 0 when not hovered
        if (dist >= hover_radius) {
            self.angle_offset *= (1.0 - 0.8 * dt);
        }

        // Click to expand
        if (mouse_pressed) {
            const tw = @as(f32, @floatFromInt(self.text_len)) * 8.0;
            const half_tw = tw / 2;
            if (mouse_x >= pos.x - half_tw - 5 and mouse_x <= pos.x + half_tw + 5 and
                mouse_y >= pos.y - 10 and mouse_y <= pos.y + 18)
            {
                self.expanded = !self.expanded;
            }
        }

        // Expand animation
        if (self.expanded and self.expand_anim < 1.0) {
            self.expand_anim = @min(1.0, self.expand_anim + dt * 4.0);
        } else if (!self.expanded and self.expand_anim > 0.0) {
            self.expand_anim = @max(0.0, self.expand_anim - dt * 4.0);
        }
    }

    fn draw(self: *const FormulaParticle, time_val: f32, cx: f32, cy: f32, font: rl.Font) void {
        const pos = self.getPos(time_val, cx, cy);
        const text_color = withAlpha(@as(rl.Color, @bitCast(theme.formula_text)), 160);
        const tw = @as(f32, @floatFromInt(self.text_len)) * 8.0;

        // Draw formula text (centered)
        rl.DrawTextEx(font, &self.text, .{ .x = pos.x - tw / 2, .y = pos.y - 7 }, 14, 0.5, text_color);

        // Expanded description (no background rect — clean text only)
        if (self.expand_anim > 0.3) {
            const desc_alpha: u8 = @intFromFloat(@min(self.expand_anim, 1.0) * 200.0);
            // On light theme: dark text (accent green invisible on white)
            const desc_accent = @as(rl.Color, @bitCast(theme.accents.logo_green));
            const desc_color = if (theme.isDark()) withAlpha(desc_accent, desc_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.text)), desc_alpha);
            const dw = @as(f32, @floatFromInt(self.desc_len)) * 7.0;
            rl.DrawTextEx(font, &self.desc, .{ .x = pos.x - dw / 2, .y = pos.y + 12 }, 12, 0.5, desc_color);
        }
    }
};

const MAX_FORMULA_PARTICLES = 42;

// ADVANCED WINDOW SYSTEM - GLASSMORPHISM PANELS
// Floating notinwith windows with phi-based animations
// =============================================================================

const MAX_PANELS = 12;
const PANEL_RADIUS: f32 = 16.0;

const PanelState = enum {
    closed,
    opening,
    open,
    closing,
    minimizing,
    maximizing,
};

const PanelType = enum {
    chat, // Chat with AI - input/output
    code, // Code editor - syntax highlight
    tools, // Tool execution - list + run
    settings, // App settings - toggles
    vision, // Image analysis - load + describe
    voice, // Voice - STT/TTS waves
    finder, // Emergent Finder - wave-based file system
    system, // System monitor - CPU, Memory, Temperature
    sacred_world, // Sacred Mathematics world panel (27 worlds)
};

// =============================================================================
// EMERGENT FINDER - Wave-Based File System Visualization
// Folders = concentric rings, Files = orbiting photons
// =============================================================================

const FileType = enum {
    folder,
    code_zig,
    code_other,
    image,
    audio,
    document,
    data,
    unknown,

    pub fn fromName(name: []const u8) FileType {
        if (name.len < 2) return .unknown;
        // Check extension
        var i: usize = name.len - 1;
        while (i > 0) : (i -= 1) {
            if (name[i] == '.') break;
        }
        if (i == 0) return .folder; // No extension = likely folder
        const ext = name[i..];
        if (std.mem.eql(u8, ext, ".zig")) return .code_zig;
        if (std.mem.eql(u8, ext, ".rs") or std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".cpp") or std.mem.eql(u8, ext, ".h") or std.mem.eql(u8, ext, ".py") or std.mem.eql(u8, ext, ".js") or std.mem.eql(u8, ext, ".ts")) return .code_other;
        if (std.mem.eql(u8, ext, ".png") or std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".gif") or std.mem.eql(u8, ext, ".svg") or std.mem.eql(u8, ext, ".ico")) return .image;
        if (std.mem.eql(u8, ext, ".mp3") or std.mem.eql(u8, ext, ".wav") or std.mem.eql(u8, ext, ".ogg") or std.mem.eql(u8, ext, ".flac")) return .audio;
        if (std.mem.eql(u8, ext, ".md") or std.mem.eql(u8, ext, ".txt") or std.mem.eql(u8, ext, ".pdf") or std.mem.eql(u8, ext, ".doc")) return .document;
        if (std.mem.eql(u8, ext, ".json") or std.mem.eql(u8, ext, ".toml") or std.mem.eql(u8, ext, ".yaml") or std.mem.eql(u8, ext, ".xml")) return .data;
        return .unknown;
    }

    pub fn getColor(self: FileType) rl.Color {
        return switch (self) {
            .folder => FILE_FOLDER,
            .code_zig => FILE_ZIG,
            .code_other => FILE_CODE,
            .image => FILE_IMAGE,
            .audio => FILE_AUDIO,
            .document => FILE_DOCUMENT,
            .data => FILE_DATA,
            .unknown => FILE_UNKNOWN,
        };
    }

    pub fn getIcon(self: FileType) u8 {
        return switch (self) {
            .folder => 'D',
            .code_zig => 'Z',
            .code_other => 'C',
            .image => 'I',
            .audio => 'A',
            .document => 'T',
            .data => 'J',
            .unknown => '?',
        };
    }
};

const FinderEntry = struct {
    name: [128]u8,
    name_len: usize,
    is_dir: bool,
    file_type: FileType,
    orbit_angle: f32, // For wave animation
    orbit_radius: f32, // Distance from center

    pub fn init() FinderEntry {
        return .{
            .name = undefined,
            .name_len = 0,
            .is_dir = false,
            .file_type = .unknown,
            .orbit_angle = 0,
            .orbit_radius = 0,
        };
    }
};

// =============================================================================
// NETWORK ADMIN — Node connection tracking for distributed inference
// =============================================================================

const NodeStatus = enum {
    offline,
    connecting,
    online,
    degraded,
    error_state,

    pub fn label(self: NodeStatus) []const u8 {
        return switch (self) {
            .offline => "OFFLINE",
            .connecting => "CONNECTING",
            .online => "ONLINE",
            .degraded => "DEGRADED",
            .error_state => "ERROR",
        };
    }
};

const NetworkNode = struct {
    name: [32]u8,
    name_len: u8,
    address: [48]u8,
    address_len: u8,
    location: [32]u8,
    location_len: u8,
    geo_lat: f32, // latitude (-90..90)
    geo_lon: f32, // longitude (-180..180)
    status: NodeStatus,
    layers_start: u8,
    layers_end: u8,
    ram_mb: u16,
    latency_ms: u16,
    tokens_processed: u32,
    role: [16]u8,
    role_len: u8,
    session_time_ms: u32,
    is_local: bool,

    pub fn init() NetworkNode {
        return .{
            .name = undefined,
            .name_len = 0,
            .address = undefined,
            .address_len = 0,
            .location = undefined,
            .location_len = 0,
            .geo_lat = 0,
            .geo_lon = 0,
            .status = .offline,
            .layers_start = 0,
            .layers_end = 0,
            .ram_mb = 0,
            .latency_ms = 0,
            .tokens_processed = 0,
            .role = undefined,
            .role_len = 0,
            .session_time_ms = 0,
            .is_local = true,
        };
    }
};

fn mkNode(name: []const u8, addr: []const u8, role: []const u8, loc: []const u8, glat: f32, glon: f32, status: NodeStatus, l_start: u8, l_end: u8, ram: u16, latency: u16, tokens: u32, session: u32, local: bool) NetworkNode {
    var n = NetworkNode.init();
    const nl = @min(name.len, 31);
    @memcpy(n.name[0..nl], name[0..nl]);
    n.name_len = @intCast(nl);
    const al = @min(addr.len, 47);
    @memcpy(n.address[0..al], addr[0..al]);
    n.address_len = @intCast(al);
    const rl2 = @min(role.len, 15);
    @memcpy(n.role[0..rl2], role[0..rl2]);
    n.role_len = @intCast(rl2);
    const ll = @min(loc.len, 31);
    @memcpy(n.location[0..ll], loc[0..ll]);
    n.location_len = @intCast(ll);
    n.geo_lat = glat;
    n.geo_lon = glon;
    n.status = status;
    n.layers_start = l_start;
    n.layers_end = l_end;
    n.ram_mb = ram;
    n.latency_ms = latency;
    n.tokens_processed = tokens;
    n.session_time_ms = session;
    n.is_local = local;
    return n;
}

// Mercator projection: geo coords -> pixel position within map rect
fn geoToMap(lat: f32, lon: f32, map_x: f32, map_y: f32, map_w: f32, map_h: f32) struct { x: f32, y: f32 } {
    // lon: -180..180 -> 0..map_w
    const mx = map_x + ((lon + 180.0) / 360.0) * map_w;
    // lat: 90..-90 -> 0..map_h (simple equirectangular)
    const my = map_y + ((90.0 - lat) / 180.0) * map_h;
    return .{ .x = mx, .y = my };
}

// ── Runtime network state (detected at startup, updated dynamically) ──
const MAX_NETWORK_NODES = 8;
var g_network_nodes: [MAX_NETWORK_NODES]NetworkNode = [_]NetworkNode{NetworkNode.init()} ** MAX_NETWORK_NODES;
var g_network_node_count: usize = 0;
var g_network_total_layers: u8 = 0;
var g_network_model_name: [64]u8 = [_]u8{0} ** 64;
var g_network_model_name_len: usize = 0;
var g_network_initialized: bool = false;
var g_network_uptime_ms: u64 = 0;
var g_network_probe_thread: if (is_emscripten) ?u8 else ?std.Thread = null;
var g_network_probe_done: bool = false;
var g_net_scroll_y: f32 = 0;
var g_net_scroll_target: f32 = 0;

// ── Timezone → Geo mapping (offline, instant, ~country-level accuracy) ──
const TzGeo = struct { tz: []const u8, lat: f32, lon: f32, city: []const u8 };
const TZ_MAP = [_]TzGeo{
    .{ .tz = "Asia/Bangkok", .lat = 13.75, .lon = 100.52, .city = "Bangkok, TH" },
    .{ .tz = "Asia/Ho_Chi_Minh", .lat = 10.82, .lon = 106.63, .city = "Ho Chi Minh, VN" },
    .{ .tz = "Asia/Singapore", .lat = 1.35, .lon = 103.82, .city = "Singapore, SG" },
    .{ .tz = "Asia/Tokyo", .lat = 35.68, .lon = 139.69, .city = "Tokyo, JP" },
    .{ .tz = "Asia/Shanghai", .lat = 31.23, .lon = 121.47, .city = "Shanghai, CN" },
    .{ .tz = "Asia/Kolkata", .lat = 28.61, .lon = 77.23, .city = "Delhi, IN" },
    .{ .tz = "Asia/Dubai", .lat = 25.20, .lon = 55.27, .city = "Dubai, AE" },
    .{ .tz = "Asia/Seoul", .lat = 37.57, .lon = 126.98, .city = "Seoul, KR" },
    .{ .tz = "Asia/Taipei", .lat = 25.03, .lon = 121.57, .city = "Taipei, TW" },
    .{ .tz = "Asia/Jakarta", .lat = -6.21, .lon = 106.85, .city = "Jakarta, ID" },
    .{ .tz = "Asia/Manila", .lat = 14.60, .lon = 120.98, .city = "Manila, PH" },
    .{ .tz = "Europe/Moscow", .lat = 55.76, .lon = 37.62, .city = "Moscow, RU" },
    .{ .tz = "Europe/London", .lat = 51.51, .lon = -0.13, .city = "London, UK" },
    .{ .tz = "Europe/Berlin", .lat = 52.52, .lon = 13.41, .city = "Berlin, DE" },
    .{ .tz = "Europe/Paris", .lat = 48.86, .lon = 2.35, .city = "Paris, FR" },
    .{ .tz = "Europe/Istanbul", .lat = 41.01, .lon = 28.98, .city = "Istanbul, TR" },
    .{ .tz = "Europe/Kyiv", .lat = 50.45, .lon = 30.52, .city = "Kyiv, UA" },
    .{ .tz = "Europe/Warsaw", .lat = 52.23, .lon = 21.01, .city = "Warsaw, PL" },
    .{ .tz = "Europe/Amsterdam", .lat = 52.37, .lon = 4.90, .city = "Amsterdam, NL" },
    .{ .tz = "Europe/Lisbon", .lat = 38.72, .lon = -9.14, .city = "Lisbon, PT" },
    .{ .tz = "America/New_York", .lat = 40.71, .lon = -74.01, .city = "New York, US" },
    .{ .tz = "America/Chicago", .lat = 41.88, .lon = -87.63, .city = "Chicago, US" },
    .{ .tz = "America/Denver", .lat = 39.74, .lon = -104.99, .city = "Denver, US" },
    .{ .tz = "America/Los_Angeles", .lat = 34.05, .lon = -118.24, .city = "Los Angeles, US" },
    .{ .tz = "America/Sao_Paulo", .lat = -23.55, .lon = -46.63, .city = "Sao Paulo, BR" },
    .{ .tz = "America/Toronto", .lat = 43.65, .lon = -79.38, .city = "Toronto, CA" },
    .{ .tz = "America/Mexico_City", .lat = 19.43, .lon = -99.13, .city = "Mexico City, MX" },
    .{ .tz = "America/Argentina/Buenos_Aires", .lat = -34.60, .lon = -58.38, .city = "Buenos Aires, AR" },
    .{ .tz = "Australia/Sydney", .lat = -33.87, .lon = 151.21, .city = "Sydney, AU" },
    .{ .tz = "Pacific/Auckland", .lat = -36.85, .lon = 174.76, .city = "Auckland, NZ" },
    .{ .tz = "Africa/Cairo", .lat = 30.04, .lon = 31.24, .city = "Cairo, EG" },
    .{ .tz = "Africa/Lagos", .lat = 6.52, .lon = 3.38, .city = "Lagos, NG" },
    .{ .tz = "Africa/Johannesburg", .lat = -26.20, .lon = 28.04, .city = "Johannesburg, ZA" },
};

/// Detect local geo coordinates from system timezone (offline, instant).
/// Reads /etc/localtime symlink on macOS/Linux → extracts TZ name → looks up in TZ_MAP.
/// Returns null if timezone cannot be determined.
fn detectTimezoneGeo() ?TzGeo {
    if (is_emscripten) return null;
    // macOS: /etc/localtime -> /var/db/timezone/zoneinfo/Asia/Bangkok
    // Linux: /etc/localtime -> /usr/share/zoneinfo/Asia/Bangkok
    var link_buf: [256]u8 = undefined;
    const link = std.fs.cwd().readLink("/etc/localtime", &link_buf) catch return null;

    // Extract timezone part after "zoneinfo/"
    const marker = "zoneinfo/";
    const idx = std.mem.indexOf(u8, link, marker) orelse return null;
    const tz_name = link[idx + marker.len ..];
    if (tz_name.len == 0) return null;

    // Look up in table
    for (TZ_MAP) |entry| {
        if (std.mem.eql(u8, entry.tz, tz_name)) return entry;
    }
    return null;
}

/// Geo result from IP API
const IpGeoResult = struct {
    lat: f32,
    lon: f32,
    city: [48]u8,
    city_len: usize,
};

/// Fetch geo coordinates via ip-api.com (online, city-level accuracy).
/// Uses curl subprocess with 3-second timeout. Pass null for local public IP.
/// Works from background thread — uses page_allocator.
fn fetchIpGeo(ip: ?[]const u8) ?IpGeoResult {
    if (is_emscripten) return null; // No subprocess in WASM
    const allocator = std.heap.page_allocator;

    // Build URL: ip-api.com/json or ip-api.com/json/{ip}?fields=lat,lon,city,country
    var url_buf: [128]u8 = undefined;
    const url = if (ip) |addr|
        std.fmt.bufPrint(&url_buf, "http://ip-api.com/json/{s}?fields=lat,lon,city,country", .{addr}) catch return null
    else
        std.fmt.bufPrint(&url_buf, "http://ip-api.com/json/?fields=lat,lon,city,country", .{}) catch return null;

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-s", "-m", "3", url },
    }) catch return null;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len == 0) return null;

    // Parse JSON: {"lat":7.8804,"lon":98.3923,"city":"Phuket","country":"Thailand"}
    return parseIpApiJson(result.stdout);
}

/// Simple JSON field extractor — avoids needing full JSON parser.
/// Extracts "lat", "lon", "city", "country" from ip-api.com response.
fn parseIpApiJson(json: []const u8) ?IpGeoResult {
    const lat = parseJsonFloat(json, "\"lat\":") orelse return null;
    const lon = parseJsonFloat(json, "\"lon\":") orelse return null;

    var res = IpGeoResult{ .lat = lat, .lon = lon, .city = [_]u8{0} ** 48, .city_len = 0 };

    // Extract city
    if (extractJsonString(json, "\"city\":\"")) |city| {
        // Extract country
        if (extractJsonString(json, "\"country\":\"")) |country| {
            const cl = @min(city.len, 40);
            @memcpy(res.city[0..cl], city[0..cl]);
            res.city_len = cl;
            // Append ", XX"
            if (cl + 2 + country.len <= 48) {
                res.city[cl] = ',';
                res.city[cl + 1] = ' ';
                const co = @min(country.len, 48 - cl - 2);
                @memcpy(res.city[cl + 2 .. cl + 2 + co], country[0..co]);
                res.city_len = cl + 2 + co;
            }
        } else {
            const cl = @min(city.len, 48);
            @memcpy(res.city[0..cl], city[0..cl]);
            res.city_len = cl;
        }
    }

    return res;
}

fn parseJsonFloat(json: []const u8, key: []const u8) ?f32 {
    const idx = std.mem.indexOf(u8, json, key) orelse return null;
    const start = idx + key.len;
    // Find end: comma, }, or whitespace
    var end = start;
    while (end < json.len) : (end += 1) {
        const c = json[end];
        if (c == ',' or c == '}' or c == ' ' or c == '\n') break;
    }
    if (end == start) return null;
    return std.fmt.parseFloat(f32, json[start..end]) catch return null;
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    const idx = std.mem.indexOf(u8, json, key) orelse return null;
    const start = idx + key.len;
    // Find closing quote
    const end_off = std.mem.indexOfPos(u8, json, start, "\"") orelse return null;
    return json[start..end_off];
}

// ── v2.4: DePIN Node Management ──────────────────────────────────────────

/// Check if Docker is installed using /bin/sh -c to inherit user PATH.
fn depinCheckDocker() bool {
    if (is_emscripten) return false;
    const allocator = std.heap.page_allocator;
    // Use /bin/sh -c so the user's PATH is inherited (Docker Desktop, Homebrew, etc.)
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", "docker --version" },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    return result.stdout.len > 0;
}

/// Check if trinity-node container is running.
fn depinCheckRunning() bool {
    if (is_emscripten) return false;
    const allocator = std.heap.page_allocator;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", "docker ps -q --filter name=trinity-node" },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    for (result.stdout) |c| {
        if (c != ' ' and c != '\n' and c != '\r') return true;
    }
    return false;
}

/// Start the trinity-node Docker container.
fn depinStartNode() void {
    if (is_emscripten) return;
    if (!g_depin_docker_ok) return;
    const allocator = std.heap.page_allocator;

    // Resolve $HOME for volume mount (tilde doesn't expand in argv)
    const home = std.posix.getenv("HOME") orelse "/tmp";
    const run_cmd = std.fmt.allocPrint(allocator, "docker rm -f trinity-node 2>/dev/null; " ++
        "docker pull ghcr.io/ghashtag/trinity-node:latest && " ++
        "docker run -d --name trinity-node " ++
        "-p 8080:8080 -p 9090:9090 -p 9333:9333/udp -p 9334:9334 " ++
        "-v {s}/.trinity:/data " ++
        "ghcr.io/ghashtag/trinity-node:latest", .{home}) catch return;
    defer allocator.free(run_cmd);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", run_cmd },
    }) catch return;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    g_depin_running = result.stdout.len > 0;
}

/// Stop and remove the trinity-node Docker container.
fn depinStopNode() void {
    if (is_emscripten) return;
    const allocator = std.heap.page_allocator;
    if (std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", "docker stop trinity-node && docker rm trinity-node" },
    })) |ok| {
        allocator.free(ok.stdout);
        allocator.free(ok.stderr);
    } else |_| {}
    g_depin_running = false;
    g_depin_earned_tri = 0;
    g_depin_pending_tri = 0;
    g_depin_operations = 0;
    g_depin_uptime_hours = 0;
    g_depin_shards = 0;
    g_depin_peers = 0;
}

/// Poll node stats from HTTP API via curl.
fn depinPollStats() void {
    if (is_emscripten) return;
    const allocator = std.heap.page_allocator;

    // GET /v1/node/stats → {"operations":N,"earned_tri":F,"pending_tri":F}
    const stats = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-s", "-m", "3", "http://localhost:8080/v1/node/stats" },
    }) catch return;
    defer allocator.free(stats.stdout);
    defer allocator.free(stats.stderr);

    if (stats.stdout.len > 0) {
        if (parseJsonFloat(stats.stdout, "\"earned_tri\":")) |v| g_depin_earned_tri = @floatCast(v);
        if (parseJsonFloat(stats.stdout, "\"pending_tri\":")) |v| g_depin_pending_tri = @floatCast(v);
        if (parseJsonFloat(stats.stdout, "\"operations\":")) |v| g_depin_operations = @intFromFloat(@max(0, @as(f64, @floatCast(v))));
    }

    // GET /node/status → {"status":"earning","uptime_hours":F,"peers":N}
    const status = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-s", "-m", "3", "http://localhost:8080/node/status" },
    }) catch return;
    defer allocator.free(status.stdout);
    defer allocator.free(status.stderr);

    if (status.stdout.len > 0) {
        if (parseJsonFloat(status.stdout, "\"uptime_hours\":")) |v| g_depin_uptime_hours = v;
        if (parseJsonFloat(status.stdout, "\"peers\":")) |v| g_depin_peers = @intFromFloat(@max(0, @as(f64, @floatCast(v))));
    }

    // GET /storage/stats → {"shards_hosted":N,...}
    const storage = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-s", "-m", "3", "http://localhost:8080/storage/stats" },
    }) catch return;
    defer allocator.free(storage.stdout);
    defer allocator.free(storage.stderr);

    if (storage.stdout.len > 0) {
        if (parseJsonFloat(storage.stdout, "\"shards_hosted\":")) |v| g_depin_shards = @intFromFloat(@max(0, @as(f64, @floatCast(v))));
    }
}

/// Claim pending $TRI rewards.
fn depinClaimRewards() void {
    if (is_emscripten) return;
    const allocator = std.heap.page_allocator;
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "curl", "-s", "-m", "3", "-X", "POST", "http://localhost:8080/v1/node/claim" },
    }) catch return;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.stdout.len > 0) {
        if (parseJsonFloat(result.stdout, "\"claimed_tri\":")) |v| {
            g_depin_earned_tri += @floatCast(v);
            g_depin_pending_tri = 0;
        }
    }
}

/// Known worker endpoints to probe via TCP
const ProbeTarget = struct {
    host: []const u8,
    port: u16,
    name: []const u8,
    role: []const u8,
    location: []const u8,
    geo_lat: f32,
    geo_lon: f32,
    is_local: bool,
};
const PROBE_TARGETS = [_]ProbeTarget{
    .{ .host = "199.68.196.38", .port = 9335, .name = "VPS Worker", .role = "worker", .location = "Buffalo, US", .geo_lat = 42.89, .geo_lon = -78.88, .is_local = false },
    .{ .host = "127.0.0.1", .port = 9337, .name = "Local Relay", .role = "relay", .location = "local", .geo_lat = 0, .geo_lon = 0, .is_local = true },
    .{ .host = "127.0.0.1", .port = 9335, .name = "Local Worker", .role = "worker", .location = "local", .geo_lat = 0, .geo_lon = 0, .is_local = true },
};

/// Background TCP probe: try connecting to known endpoints + IP geo refinement
fn probeNetworkNodes() void {
    if (is_emscripten) {
        g_network_probe_done = true;
        return; // No sockets in WASM
    }
    // Step 2: Refine local node (index 0) via IP API (city-level accuracy)
    if (fetchIpGeo(null)) |geo| {
        g_network_nodes[0].geo_lat = geo.lat;
        g_network_nodes[0].geo_lon = geo.lon;
        if (geo.city_len > 0) {
            const cl = @min(geo.city_len, 31);
            @memcpy(g_network_nodes[0].location[0..cl], geo.city[0..cl]);
            g_network_nodes[0].location_len = @intCast(cl);
        }
    }

    // Step 3: Probe remote/local endpoints via TCP
    for (PROBE_TARGETS) |target| {
        // Try TCP connect with short timeout
        const addr = std.net.Address.parseIp4(target.host, target.port) catch continue;
        const sock = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0) catch continue;
        defer std.posix.close(sock);

        // Set send timeout to 2 seconds as connect timeout proxy
        const timeout = std.posix.timeval{ .sec = 2, .usec = 0 };
        std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout)) catch {};
        std.posix.setsockopt(sock, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout)) catch {};

        // Attempt connect
        std.posix.connect(sock, &addr.any, addr.getOsSockLen()) catch continue;

        // Connection succeeded — node is alive
        if (g_network_node_count >= MAX_NETWORK_NODES) break;
        var node = NetworkNode.init();
        const nl2 = @min(target.name.len, 31);
        @memcpy(node.name[0..nl2], target.name[0..nl2]);
        node.name_len = @intCast(nl2);

        var addr_str: [48]u8 = [_]u8{0} ** 48;
        const al2 = std.fmt.bufPrint(&addr_str, "{s}:{d}", .{ target.host, target.port }) catch continue;
        @memcpy(node.address[0..al2.len], al2);
        node.address_len = @intCast(al2.len);

        const rl3 = @min(target.role.len, 15);
        @memcpy(node.role[0..rl3], target.role[0..rl3]);
        node.role_len = @intCast(rl3);

        // For remote nodes: use IP API for accurate geo; for local: copy from local node
        if (!target.is_local) {
            if (fetchIpGeo(target.host)) |geo| {
                node.geo_lat = geo.lat;
                node.geo_lon = geo.lon;
                if (geo.city_len > 0) {
                    const cl = @min(geo.city_len, 31);
                    @memcpy(node.location[0..cl], geo.city[0..cl]);
                    node.location_len = @intCast(cl);
                } else {
                    const ll2 = @min(target.location.len, 31);
                    @memcpy(node.location[0..ll2], target.location[0..ll2]);
                    node.location_len = @intCast(ll2);
                }
            } else {
                // Fallback to static coords from probe target
                node.geo_lat = target.geo_lat;
                node.geo_lon = target.geo_lon;
                const ll2 = @min(target.location.len, 31);
                @memcpy(node.location[0..ll2], target.location[0..ll2]);
                node.location_len = @intCast(ll2);
            }
        } else {
            // Local node: copy geo from local coordinator (already refined)
            node.geo_lat = g_network_nodes[0].geo_lat;
            node.geo_lon = g_network_nodes[0].geo_lon;
            const ll3 = g_network_nodes[0].location_len;
            @memcpy(node.location[0..ll3], g_network_nodes[0].location[0..ll3]);
            node.location_len = ll3;
        }

        node.status = .online;
        node.is_local = target.is_local;
        node.latency_ms = if (target.is_local) 1 else 95;

        g_network_nodes[g_network_node_count] = node;
        g_network_node_count += 1;
    }
    g_network_probe_done = true;
}

/// Detect local machine and spawn background probe for remote nodes.
/// Called once when the Network panel is first opened.
fn initNetworkState() void {
    if (g_network_initialized) return;
    g_network_initialized = true;

    // Query real system RAM via auto_shard (sysctl on macOS, /proc/meminfo on Linux)
    const sys_mem = auto_shard.getSystemMemory() catch auto_shard.SystemMemory{
        .total_bytes = 0,
        .available_bytes = 0,
    };
    const ram_mb: u16 = @intCast(@min(sys_mem.total_bytes / (1024 * 1024), 65535));

    // Get hostname
    var hostname_buf: [64]u8 = [_]u8{0} ** 64;
    var hostname_len: usize = 0;
    if (is_emscripten) {
        const wasm_name = "Browser";
        @memcpy(hostname_buf[0..wasm_name.len], wasm_name);
        hostname_len = wasm_name.len;
    } else if (std.c.gethostname(&hostname_buf, hostname_buf.len) == 0) {
        for (hostname_buf, 0..) |c, i| {
            if (c == 0) {
                hostname_len = i;
                break;
            }
        }
        if (hostname_len == 0) hostname_len = hostname_buf.len;
    } else {
        const fallback = "localhost";
        @memcpy(hostname_buf[0..fallback.len], fallback);
        hostname_len = fallback.len;
    }

    // Create local node entry with real detected values
    var local_node = NetworkNode.init();
    const nl = @min(hostname_len, 31);
    @memcpy(local_node.name[0..nl], hostname_buf[0..nl]);
    local_node.name_len = @intCast(nl);
    const addr = "127.0.0.1:9336";
    @memcpy(local_node.address[0..addr.len], addr);
    local_node.address_len = @intCast(addr.len);
    const role = "coordinator";
    @memcpy(local_node.role[0..role.len], role);
    local_node.role_len = @intCast(role.len);

    // Step 1: Detect geo from timezone (instant, offline, ~country-level)
    if (detectTimezoneGeo()) |tz_geo| {
        local_node.geo_lat = tz_geo.lat;
        local_node.geo_lon = tz_geo.lon;
        const cl = @min(tz_geo.city.len, 31);
        @memcpy(local_node.location[0..cl], tz_geo.city[0..cl]);
        local_node.location_len = @intCast(cl);
    } else {
        const loc = "Unknown";
        @memcpy(local_node.location[0..loc.len], loc);
        local_node.location_len = @intCast(loc.len);
    }

    local_node.status = .online;
    local_node.ram_mb = ram_mb;
    local_node.latency_ms = 0;
    local_node.is_local = true;
    local_node.layers_start = 0;
    local_node.layers_end = 0;

    g_network_nodes[0] = local_node;
    g_network_node_count = 1;

    const no_model = if (is_emscripten) "WASM Browser Node" else "Scanning network...";
    @memcpy(g_network_model_name[0..no_model.len], no_model);
    g_network_model_name_len = no_model.len;

    if (is_emscripten) {
        // No background threads in WASM — mark probe as done immediately
        g_network_probe_done = true;
    } else {
        // Spawn background thread to probe known endpoints + refine geo via IP API
        g_network_probe_thread = std.Thread.spawn(.{}, probeNetworkNodes, .{}) catch null;
    }

    // v2.4: DePIN Docker detection on startup
    g_depin_docker_ok = depinCheckDocker();
    g_depin_running = if (g_depin_docker_ok) depinCheckRunning() else false;
}

const GlassPanel = struct {
    // Position & size
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    // Target position (for animations)
    target_x: f32,
    target_y: f32,
    target_w: f32,
    target_h: f32,

    // Animation
    state: PanelState,
    anim_t: f32, // 0..1
    opacity: f32,
    scale: f32,

    // Content
    panel_type: PanelType,
    title: [64]u8,
    title_len: usize,

    // Interaction
    dragging: bool,
    drag_offset_x: f32,
    drag_offset_y: f32,

    // Velocity for swipe inertia
    vel_x: f32,
    vel_y: f32,

    // Resize
    resizing: bool,
    resize_edge: u8, // 0=none, 1=right, 2=bottom, 4=left, 8=top, combos for corners

    // Content data
    content_text: [512]u8,
    content_len: usize,
    scroll_y: f32,
    scroll_target: f32, // Smooth scroll target (lerp toward this)

    // For tools panel
    tool_selected: usize,

    // For voice panel
    voice_amplitude: f32,
    voice_recording: bool,
    voice_wave_phase: f32,

    // For chat panel - multi-modal content
    chat_messages: [32][256]u8,
    chat_msg_lens: [32]usize,
    chat_msg_is_user: [32]bool,
    chat_msg_count: usize,
    chat_input: [256]u8,
    chat_input_len: usize,
    chat_ripple: f32, // Response ripple animation

    // For code panel - syntax waves
    code_wave_phase: f32,
    code_cursor_line: usize,

    // For vision panel
    vision_analyzing: bool,
    vision_progress: f32,
    vision_result: [256]u8,
    vision_result_len: usize,

    // Focus state for full-screen transitions
    is_focused: bool,
    focus_ripple: f32,
    pre_focus_x: f32,
    pre_focus_y: f32,
    pre_focus_w: f32,
    pre_focus_h: f32,

    // JARVIS spherical morph animation
    jarvis_morph: f32, // 0 = sphere, 1 = rectangle
    jarvis_glow_pulse: f32,
    jarvis_ring_rotation: f32,

    // For finder panel
    finder_path: [512]u8,
    finder_path_len: usize,
    finder_entries: [64]FinderEntry,
    finder_entry_count: usize,
    finder_selected: usize,
    finder_animation: f32,
    finder_ripple: f32, // 0-1 ripple animation on folder open

    // For system monitor panel
    sys_cpu_usage: f32, // 0-100%
    sys_mem_used: f32, // GB
    sys_mem_total: f32, // GB
    sys_cpu_temp: f32, // Celsius
    sys_update_timer: f32, // Timer for updates

    // For sacred world panel (27 worlds of 999 kingdom)
    world_id: u8, // Block index 0-26
    world_anim_phase: f32, // phi-spiral animation

    // Emergent Wave ScrollView v1.0
    // When enabled, replaces legacy lerp scroll with phi-damped wave physics
    wave_scroll_enabled: bool,
    wave_sv: wave_scroll.WaveScrollView,

    pub fn init(px: f32, py: f32, pw: f32, ph: f32, ptype: PanelType, title_str: []const u8) GlassPanel {
        var panel = GlassPanel{
            .x = px,
            .y = py,
            .width = pw,
            .height = ph,
            .target_x = px,
            .target_y = py,
            .target_w = pw,
            .target_h = ph,
            .state = .closed,
            .anim_t = 0,
            .opacity = 0,
            .scale = 0.8,
            .panel_type = ptype,
            .title = undefined,
            .title_len = @min(title_str.len, 63),
            .dragging = false,
            .drag_offset_x = 0,
            .drag_offset_y = 0,
            .vel_x = 0,
            .vel_y = 0,
            .resizing = false,
            .resize_edge = 0,
            .content_text = undefined,
            .content_len = 0,
            .scroll_y = 0,
            .scroll_target = 0,
            .tool_selected = 0,
            .voice_amplitude = 0,
            .voice_recording = false,
            .voice_wave_phase = 0,
            .chat_messages = undefined,
            .chat_msg_lens = .{0} ** 32,
            .chat_msg_is_user = .{false} ** 32,
            .chat_msg_count = 0,
            .chat_input = undefined,
            .chat_input_len = 0,
            .chat_ripple = 0,
            .code_wave_phase = 0,
            .code_cursor_line = 0,
            .vision_analyzing = false,
            .vision_progress = 0,
            .vision_result = undefined,
            .vision_result_len = 0,
            .is_focused = false,
            .focus_ripple = 0,
            .pre_focus_x = px,
            .pre_focus_y = py,
            .pre_focus_w = pw,
            .pre_focus_h = ph,
            .jarvis_morph = 1.0, // Start as rectangle
            .jarvis_glow_pulse = 0,
            .jarvis_ring_rotation = 0,
            .finder_path = undefined,
            .finder_path_len = 0,
            .finder_entries = undefined,
            .finder_entry_count = 0,
            .finder_selected = 0,
            .finder_animation = 0,
            .finder_ripple = 0,
            .sys_cpu_usage = 0,
            .sys_mem_used = 0,
            .sys_mem_total = 16.0, // Default 16GB
            .sys_cpu_temp = 45.0, // Default temp
            .sys_update_timer = 0,
            .world_id = 0,
            .world_anim_phase = 0,
            .wave_scroll_enabled = false,
            .wave_sv = wave_scroll.WaveScrollView.init(px, py + 32.0, pw, ph - 32.0),
        };
        @memcpy(panel.title[0..panel.title_len], title_str[0..panel.title_len]);
        panel.title[panel.title_len] = 0;

        // Initialize finder entries
        for (&panel.finder_entries) |*entry| {
            entry.* = FinderEntry.init();
        }

        // Default content based on type
        const default_content = switch (ptype) {
            .chat => "Type a message...",
            .code => "// Your code here\nfn main() void {\n    \n}",
            .tools => "inference\nembedding\nsearch\ngenerate",
            .settings => "Dark Mode: ON\nSound: OFF\nAnimations: ON",
            .vision => "Drop image or click to load...",
            .voice => "Press to speak...",
            .finder => "Loading directory...",
            .system => "System monitor",
            .sacred_world => "Sacred Mathematics",
        };

        // Initialize finder with current directory for finder panels
        if (ptype == .finder) {
            panel.loadDirectory(".");
        }
        const content_copy_len = @min(default_content.len, 511);
        @memcpy(panel.content_text[0..content_copy_len], default_content[0..content_copy_len]);
        panel.content_len = content_copy_len;

        return panel;
    }

    // Phi-based easing (smooth cosmic feel)
    fn easePhiInOut(t: f32) f32 {
        if (t < 0.5) {
            return 2.0 * t * t * PHI_INV;
        } else {
            const f = -2.0 * t + 2.0;
            return 1.0 - (f * f * PHI_INV) / 2.0;
        }
    }

    pub fn open(self: *GlassPanel) void {
        if (self.state == .closed or self.state == .closing) {
            self.state = .opening;
            self.anim_t = 0;
        }
    }

    pub fn close(self: *GlassPanel) void {
        if (self.state == .open or self.state == .opening) {
            self.state = .closing;
            self.anim_t = 0;
        }
    }

    pub fn minimize(self: *GlassPanel) void {
        if (self.state == .open) {
            self.state = .minimizing;
            self.anim_t = 0;
            self.target_y = @as(f32, @floatFromInt(g_height)) + 100;
        }
    }

    // Focus panel to full screen with cosmic transition
    pub fn focus(self: *GlassPanel) void {
        if (!self.is_focused and self.state == .open) {
            // Save current position for restoration
            self.pre_focus_x = self.x;
            self.pre_focus_y = self.y;
            self.pre_focus_w = self.width;
            self.pre_focus_h = self.height;
            // Set target to full screen with margin
            self.target_x = 20;
            self.target_y = 40;
            self.target_w = @as(f32, @floatFromInt(g_width)) - 40;
            self.target_h = @as(f32, @floatFromInt(g_height)) - 100;
            self.is_focused = true;
            self.focus_ripple = 1.0;
        }
    }

    // Unfocus panel - restore to previous position
    pub fn unfocus(self: *GlassPanel) void {
        if (self.is_focused) {
            self.target_x = self.pre_focus_x;
            self.target_y = self.pre_focus_y;
            self.target_w = self.pre_focus_w;
            self.target_h = self.pre_focus_h;
            self.is_focused = false;
            self.focus_ripple = 1.0;
            self.jarvis_morph = 1.0; // Rectangle
        }
    }

    // JARVIS-style focus with spherical morph animation
    pub fn jarvisFocus(self: *GlassPanel) void {
        // Save current position for restoration
        if (!self.is_focused) {
            self.pre_focus_x = self.x;
            self.pre_focus_y = self.y;
            self.pre_focus_w = self.width;
            self.pre_focus_h = self.height;
        }
        // Set target to full screen with margin
        self.target_x = 20;
        self.target_y = 40;
        self.target_w = @as(f32, @floatFromInt(g_width)) - 40;
        self.target_h = @as(f32, @floatFromInt(g_height)) - 100;
        self.is_focused = true;
        self.focus_ripple = 1.0;
        // Start from sphere (0) and morph to rectangle (1)
        self.jarvis_morph = 0;
        self.jarvis_glow_pulse = 1.0;
    }

    // Add chat message with response ripple
    pub fn addChatMessage(self: *GlassPanel, msg: []const u8, is_user: bool) void {
        if (self.chat_msg_count >= 32) {
            // Shift messages up (drop oldest)
            for (0..31) |i| {
                @memcpy(&self.chat_messages[i], &self.chat_messages[i + 1]);
                self.chat_msg_lens[i] = self.chat_msg_lens[i + 1];
                self.chat_msg_is_user[i] = self.chat_msg_is_user[i + 1];
            }
            self.chat_msg_count = 31;
        }
        const idx = self.chat_msg_count;
        const copy_len = @min(msg.len, 255);
        @memcpy(self.chat_messages[idx][0..copy_len], msg[0..copy_len]);
        self.chat_msg_lens[idx] = copy_len;
        self.chat_msg_is_user[idx] = is_user;
        self.chat_msg_count += 1;
        // Trigger response ripple for AI responses
        if (!is_user) {
            self.chat_ripple = 1.0;
        }
    }

    pub fn update(self: *GlassPanel, dt: f32) void {
        const anim_speed: f32 = 3.0; // Animation duration ~0.33s

        switch (self.state) {
            .opening => {
                self.anim_t += dt * anim_speed;
                if (self.anim_t >= 1.0) {
                    self.anim_t = 1.0;
                    self.state = .open;
                }
                const e = easePhiInOut(self.anim_t);
                self.opacity = e;
                self.scale = 0.8 + e * 0.2;
            },
            .closing => {
                self.anim_t += dt * anim_speed;
                if (self.anim_t >= 1.0) {
                    self.anim_t = 1.0;
                    self.state = .closed;
                }
                const e = easePhiInOut(self.anim_t);
                self.opacity = 1.0 - e;
                self.scale = 1.0 - e * 0.2;
            },
            .minimizing => {
                self.anim_t += dt * anim_speed;
                if (self.anim_t >= 1.0) {
                    self.state = .closed;
                }
                const e = easePhiInOut(self.anim_t);
                self.y = self.y + (self.target_y - self.y) * e * 0.3;
                self.opacity = 1.0 - e;
                self.scale = 1.0 - e * 0.5;
            },
            .open => {
                self.opacity = 1.0;
                self.scale = 1.0;

                // === JARVIS FOCUS TRANSITION ANIMATION ===
                const focus_speed: f32 = 4.0; // Phi-smooth transition
                if (self.is_focused or self.focus_ripple > 0) {
                    // Animate position and size towards target
                    const lerp_factor = dt * focus_speed;
                    self.x += (self.target_x - self.x) * lerp_factor;
                    self.y += (self.target_y - self.y) * lerp_factor;
                    self.width += (self.target_w - self.width) * lerp_factor;
                    self.height += (self.target_h - self.height) * lerp_factor;
                    // Decay focus ripple
                    if (self.focus_ripple > 0) {
                        self.focus_ripple -= dt * 1.5;
                        if (self.focus_ripple < 0) self.focus_ripple = 0;
                    }
                }

                // JARVIS spherical morph (0 = sphere → 1 = rectangle)
                if (self.jarvis_morph < 1.0) {
                    self.jarvis_morph += dt * 2.5;
                    if (self.jarvis_morph > 1.0) self.jarvis_morph = 1.0;
                }

                // JARVIS glow pulse decay
                if (self.jarvis_glow_pulse > 0) {
                    self.jarvis_glow_pulse -= dt * 1.2;
                    if (self.jarvis_glow_pulse < 0) self.jarvis_glow_pulse = 0;
                }

                // JARVIS ring rotation (continuous)
                if (self.is_focused) {
                    self.jarvis_ring_rotation += dt * 2.0;
                }

                // === MULTI-MODAL CONTENT ANIMATIONS ===

                // Chat ripple animation
                if (self.chat_ripple > 0) {
                    self.chat_ripple -= dt * 2.0;
                    if (self.chat_ripple < 0) self.chat_ripple = 0;
                }

                // Code wave phase (continuous syntax animation)
                if (self.panel_type == .code) {
                    self.code_wave_phase += dt * 2.0;
                }

                // Vision analyzing progress
                if (self.vision_analyzing) {
                    self.vision_progress += dt * 0.5;
                    if (self.vision_progress >= 1.0) {
                        self.vision_analyzing = false;
                        self.vision_progress = 1.0;
                        // Set result
                        const result = "Cosmic image analyzed: wave patterns detected!";
                        @memcpy(self.vision_result[0..result.len], result);
                        self.vision_result_len = result.len;
                    }
                }

                // Voice wave phase and amplitude
                if (self.panel_type == .voice) {
                    self.voice_wave_phase += dt * 8.0;
                    if (self.voice_recording) {
                        // Simulate audio amplitude
                        self.voice_amplitude = 0.5 + @sin(self.voice_wave_phase) * 0.3;
                    } else {
                        self.voice_amplitude *= 0.9; // Decay
                    }
                }

                // Animate finder entries appearing
                if (self.panel_type == .finder and self.finder_animation < 1.0) {
                    self.finder_animation += dt * 2.0;
                    if (self.finder_animation > 1.0) self.finder_animation = 1.0;
                }

                // Animate finder ripple effect
                if (self.panel_type == .finder and self.finder_ripple > 0) {
                    self.finder_ripple -= dt * 1.5;
                    if (self.finder_ripple < 0) self.finder_ripple = 0;
                }

                // Apply velocity (swipe inertia) - only when not focused
                if (!self.dragging and !self.is_focused) {
                    self.x += self.vel_x * dt;
                    self.y += self.vel_y * dt;
                    // Friction
                    self.vel_x *= 0.92;
                    self.vel_y *= 0.92;

                    // Bounce off edges
                    const fw = @as(f32, @floatFromInt(g_width));
                    const fh = @as(f32, @floatFromInt(g_height));
                    if (self.x < 0) {
                        self.x = 0;
                        self.vel_x = -self.vel_x * 0.5;
                    }
                    if (self.x + self.width > fw) {
                        self.x = fw - self.width;
                        self.vel_x = -self.vel_x * 0.5;
                    }
                    if (self.y < 0) {
                        self.y = 0;
                        self.vel_y = -self.vel_y * 0.5;
                    }
                    if (self.y + self.height > fh - 60) {
                        self.y = fh - 60 - self.height;
                        self.vel_y = -self.vel_y * 0.5;
                    }
                }
            },
            .closed => {},
            .maximizing => {},
        }
    }

    pub fn draw(self: *const GlassPanel, time: f32, font: rl.Font) void {
        if (self.state == .closed) return;

        const cx = self.x + self.width / 2;
        const cy = self.y + self.height / 2;

        // Scale from center
        const sw = self.width * self.scale;
        const sh = self.height * self.scale;
        const sx = cx - sw / 2;
        const sy = cy - sh / 2;

        // Skip drawing if panel is not focused (teleportation effect - only show focused)
        if (!self.is_focused and self.state == .open) {
            return; // Hide unfocused panels completely
        }

        // Smoother rounded corners (Hyper style)
        const roundness = 0.06; // Slightly larger for smoother look

        // === FOCUS TRANSITION RIPPLE === REMOVED (Teleportation effect - instant switch)
        // if (self.focus_ripple > 0) {
        //     const ripple_progress = 1.0 - self.focus_ripple;
        //     const max_radius = @max(sw, sh);
        //     for (0..5) |ring| {
        //         const ring_f = @as(f32, @floatFromInt(ring));
        //         const ring_delay = ring_f * 0.1;
        //         const ring_progress = @max(0, @min(1.0, (ripple_progress - ring_delay) / 0.7));
        //         if (ring_progress > 0) {
        //             const ripple_radius = ring_progress * max_radius;
        //             const ripple_alpha: u8 = @intFromFloat(@max(0, self.opacity * 150 * (1.0 - ring_progress) * self.focus_ripple));
        //             const ripple_color = if (self.is_focused) rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ripple_alpha } else rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = ripple_alpha };
        //             rl.DrawCircleLines(@intFromFloat(cx), @intFromFloat(cy), ripple_radius, ripple_color);
        //         }
        //     }
        // }

        // === FOCUSED GLOW EFFECT === REMOVED (Hyper style - clean borders)
        // if (self.is_focused) {
        //     const glow_pulse = @sin(time * 3) * 0.2 + 0.8;
        //     const glow_alpha: u8 = @intFromFloat(self.opacity * 25 * glow_pulse);
        //     rl.DrawRectangleRounded(
        //         .{ .x = sx - 3, .y = sy - 3, .width = sw + 6, .height = sh + 6 },
        //         roundness, 16,
        //         rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = glow_alpha },
        //     );
        // }

        // === PROFESSIONAL GLASSMORPHISM ===

        // Shadow (soft, offset down-right — darker on light theme for visibility)
        const shadow_offset: f32 = 4.0;
        const shadow_strength: f32 = if (theme.isDark()) 40 else 80;
        const shadow_alpha: u8 = @intFromFloat(self.opacity * shadow_strength);
        const shadow_color = rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = shadow_alpha };
        rl.DrawRectangleRounded(
            .{ .x = sx + shadow_offset, .y = sy + shadow_offset, .width = sw, .height = sh },
            roundness,
            32, // More segments for smoother corners
            shadow_color,
        );

        // Main glass background (Hyper style)
        // Dark theme: semi-transparent glass effect (230 alpha)
        // Light theme: fully opaque (255 alpha) — no dark bleed-through
        const bg_base_alpha: f32 = if (self.panel_type == .sacred_world) 255 else if (theme.isDark()) 230 else 255;
        const bg_alpha: u8 = @intFromFloat(self.opacity * bg_base_alpha);
        const bg_color = if (self.panel_type == .sacred_world) @as(rl.Color, @bitCast(theme.sacred_world_bg)) else BG_SURFACE;
        rl.DrawRectangleRounded(
            .{ .x = sx, .y = sy, .width = sw, .height = sh },
            roundness,
            32,
            withAlpha(bg_color, bg_alpha),
        );

        // Gradient overlay REMOVED (clean Hyper style - no gradient)
        // const grad_alpha: u8 = @intFromFloat(self.opacity * 15);
        // rl.DrawRectangleRounded(
        //     .{ .x = sx, .y = sy, .width = sw, .height = sh / 3 },
        //     roundness, 32,
        //     withAlpha(TEXT_WHITE, grad_alpha),
        // );

        // Border — visible on both themes (stronger on light)
        const border_strength: f32 = if (theme.isDark()) 40 else 180;
        const border_alpha: u8 = @intFromFloat(self.opacity * border_strength);
        rl.DrawRectangleRoundedLinesEx(
            .{ .x = sx, .y = sy, .width = sw, .height = sh },
            roundness,
            32,
            1.0,
            withAlpha(@as(rl.Color, @bitCast(theme.border)), border_alpha),
        );

        // Wave scroll: animated cyan border pulse (Emergent Wave ScrollView v1.0)
        if (self.wave_scroll_enabled) {
            const wave_border_pulse = @sin(self.wave_sv.wave_time * 2.0) * 0.3 + 0.4;
            const wb_alpha: u8 = @intFromFloat(@max(0, @min(255.0, wave_border_pulse * 50.0 * self.opacity)));
            rl.DrawRectangleRoundedLinesEx(
                .{ .x = sx - 1, .y = sy - 1, .width = sw + 2, .height = sh + 2 },
                roundness,
                32,
                1.0,
                rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = wb_alpha },
            );
        }

        // === TITLE BAR (Hyper style - no traffic lights) ===
        // Traffic light buttons REMOVED - use Shift+1-8 for panel switching
        // const btn_y = sy + 14;
        // const btn_spacing: f32 = 20;
        // rl.DrawCircle(@intFromFloat(sx + 16), @intFromFloat(btn_y), 6, withAlpha(BTN_CLOSE, alpha));
        // rl.DrawCircle(@intFromFloat(sx + 16 + btn_spacing), @intFromFloat(btn_y), 6, withAlpha(BTN_MINIMIZE, alpha));
        // rl.DrawCircle(@intFromFloat(sx + 16 + btn_spacing * 2), @intFromFloat(btn_y), 6, withAlpha(BTN_MAXIMIZE, alpha));

        // Title (centered)
        const title_alpha: u8 = @intFromFloat(self.opacity * 200);
        const title_width: f32 = @floatFromInt(rl.MeasureText(&self.title, 14));
        const title_x = sx + (sw - title_width) / 2;
        rl.DrawTextEx(font, &self.title, .{ .x = title_x, .y = sy + 6 }, 16, 0.5, withAlpha(@as(rl.Color, @bitCast(theme.panel_title)), title_alpha));

        // Title bar separator
        const sep_alpha: u8 = @intFromFloat(self.opacity * 30);
        rl.DrawLine(@intFromFloat(sx), @intFromFloat(sy + 32), @intFromFloat(sx + sw), @intFromFloat(sy + 32), withAlpha(@as(rl.Color, @bitCast(theme.panel_title_sep)), sep_alpha));

        // === CONTENT AREA (Multi-Modal) ===
        const content_y = sy + 40;
        const content_h = sh - 50;
        const content_alpha: u8 = @intFromFloat(self.opacity * theme.panel_content_alpha);
        const text_color = withAlpha(CONTENT_TEXT, content_alpha);

        switch (self.panel_type) {
            .chat => {
                // === MULTI-MODAL CHAT PANEL ===
                // Response ripple animation (cosmic wave on new AI message)
                if (self.chat_ripple > 0) {
                    const ripple_center_y = content_y + content_h / 2;
                    const ripple_progress = 1.0 - self.chat_ripple;
                    for (0..3) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = ripple_progress * sw * 0.5 + ring_f * 20;
                        const ring_alpha: u8 = @intFromFloat(@max(0, self.opacity * 120 * self.chat_ripple));
                        rl.DrawCircleLines(@intFromFloat(sx + sw / 2), @intFromFloat(ripple_center_y), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha });
                    }
                }

                // Messages area with scroll support
                const msg_area_h = content_h - 50;
                const msg_y_start = content_y + 5 - self.scroll_y;
                const line_spacing: f32 = 28;

                for (0..self.chat_msg_count) |i| {
                    const msg_y = msg_y_start + @as(f32, @floatFromInt(i)) * line_spacing;
                    // Skip messages outside visible area
                    if (msg_y < content_y - line_spacing) continue;
                    if (msg_y > content_y + msg_area_h) break;

                    const is_user = self.chat_msg_is_user[i];
                    const label_color = if (is_user) withAlpha(TEXT_WHITE, content_alpha) else withAlpha(HYPER_GREEN, content_alpha);
                    const label = if (is_user) "YOU:" else "AI:";

                    rl.DrawTextEx(font, label.ptr, .{ .x = sx + 12, .y = msg_y }, 11, 0.5, label_color);

                    // Message text
                    var msg_buf: [260:0]u8 = undefined;
                    const msg_len = self.chat_msg_lens[i];
                    const show_len = @min(msg_len, @as(usize, @intFromFloat((sw - 60) / 6)));
                    @memcpy(msg_buf[0..show_len], self.chat_messages[i][0..show_len]);
                    msg_buf[show_len] = 0;
                    rl.DrawTextEx(font, &msg_buf, .{ .x = sx + 45, .y = msg_y }, 11, 0.5, text_color);
                }

                // Welcome message if empty
                if (self.chat_msg_count == 0) {
                    rl.DrawTextEx(font, "AI:", .{ .x = sx + 12, .y = content_y + 10 }, 12, 0.5, withAlpha(HYPER_GREEN, content_alpha));
                    rl.DrawTextEx(font, "Hello! Type a message to chat.", .{ .x = sx + 12, .y = content_y + 28 }, 12, 0.5, text_color);
                }

                // Input area (bottom)
                const input_y = sy + sh - 40;
                rl.DrawRectangle(@intFromFloat(sx + 8), @intFromFloat(input_y), @intFromFloat(sw - 16), 30, withAlpha(BG_INPUT, content_alpha));
                rl.DrawRectangleLines(@intFromFloat(sx + 8), @intFromFloat(input_y), @intFromFloat(sw - 16), 30, withAlpha(BORDER_LIGHT, content_alpha));

                // Show current input or placeholder
                if (self.chat_input_len > 0) {
                    var input_buf: [260:0]u8 = undefined;
                    const show_len = @min(self.chat_input_len, 50);
                    @memcpy(input_buf[0..show_len], self.chat_input[0..show_len]);
                    // Cursor blink
                    if (@mod(@as(u32, @intFromFloat(time * 3)), 2) == 0) {
                        input_buf[show_len] = '_';
                        input_buf[show_len + 1] = 0;
                    } else {
                        input_buf[show_len] = 0;
                    }
                    rl.DrawTextEx(font, &input_buf, .{ .x = sx + 16, .y = input_y + 8 }, 12, 0.5, NOVA_WHITE);
                } else {
                    rl.DrawTextEx(font, "Type message... (click to focus)", .{ .x = sx + 16, .y = input_y + 8 }, 11, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                }
            },
            .code => {
                // === MULTI-MODAL CODE EDITOR WITH SYNTAX WAVES ===
                const line_h: f32 = 18;
                const code_lines = [_][]const u8{
                    "// TRINITY COSMIC ENGINE",
                    "const PHI: f32 = 1.618033988;",
                    "",
                    "fn main() !void {",
                    "    const grid = try init();",
                    "    defer grid.deinit();",
                    "",
                    "    // Cosmic infinity loop",
                    "    while (running) {",
                    "        update();",
                    "        render();",
                    "    }",
                    "}",
                };

                for (code_lines, 0..) |line, i| {
                    const fi = @as(f32, @floatFromInt(i));
                    // Wave offset for each line
                    const wave_offset = @sin(self.code_wave_phase + fi * 0.3) * 2;
                    const line_y = content_y + 10 + fi * line_h;
                    if (line_y > sy + sh - 20) break;

                    // Line number with wave glow
                    const ln_glow = @abs(@sin(self.code_wave_phase * 0.5 + fi * 0.5));
                    const ln_alpha: u8 = @intFromFloat(50 + ln_glow * 30);
                    var ln_buf: [8:0]u8 = undefined;
                    _ = std.fmt.bufPrintZ(&ln_buf, "{d:>3}", .{i + 1}) catch {};
                    rl.DrawTextEx(font, &ln_buf, .{ .x = sx + 8, .y = line_y }, 10, 0.5, withAlpha(@as(rl.Color, @bitCast(theme.line_number)), ln_alpha + content_alpha / 2));

                    if (line.len == 0) continue;

                    // Syntax-based coloring with wave brightness modulation
                    const wave_brightness: f32 = 0.8 + @sin(self.code_wave_phase + fi * 0.2) * 0.2;

                    var code_color: rl.Color = undefined;
                    if (line[0] == '/' and line.len > 1 and line[1] == '/') {
                        // Comment - green with wave
                        code_color = rl.Color{ .r = @intFromFloat(0x50 * wave_brightness), .g = @intFromFloat(0xA0 * wave_brightness), .b = @intFromFloat(0x50 * wave_brightness), .a = content_alpha };
                    } else if (std.mem.startsWith(u8, line, "const") or std.mem.startsWith(u8, line, "fn ") or std.mem.startsWith(u8, line, "    const") or std.mem.startsWith(u8, line, "    defer") or std.mem.startsWith(u8, line, "    while")) {
                        // Keyword - green wave
                        code_color = rl.Color{ .r = @intFromFloat(0x00 * wave_brightness), .g = @intFromFloat(0xFF * wave_brightness), .b = @intFromFloat(0x88 * wave_brightness), .a = content_alpha };
                    } else if (std.mem.indexOf(u8, line, "PHI") != null or std.mem.indexOf(u8, line, "1.618") != null) {
                        // PHI constant - golden wave
                        code_color = rl.Color{ .r = @intFromFloat(0xFF * wave_brightness), .g = @intFromFloat(0xD7 * wave_brightness), .b = @intFromFloat(0x00 * wave_brightness), .a = content_alpha };
                    } else {
                        code_color = rl.Color{ .r = @intFromFloat(0xC0 * wave_brightness), .g = @intFromFloat(0xC8 * wave_brightness), .b = @intFromFloat(0xD0 * wave_brightness), .a = content_alpha };
                    }

                    // Draw code with wave offset
                    rl.DrawText(line.ptr, @intFromFloat(sx + 40 + wave_offset), @intFromFloat(line_y), 11, code_color);

                    // Trailing wave particles for active lines
                    if (i == self.code_cursor_line) {
                        const particle_x = sx + 40 + @as(f32, @floatFromInt(line.len)) * 7 + 10;
                        const particle_glow = @abs(@sin(self.code_wave_phase * 3));
                        rl.DrawCircle(@intFromFloat(particle_x), @intFromFloat(line_y + 6), 3 + particle_glow * 2, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 150) });
                    }
                }

                // Bottom status with wave
                const status_y = sy + sh - 25;
                const status_wave = @sin(time * 2) * 0.3 + 0.7;
                rl.DrawText("Zig | UTF-8 | phi^2 + 1/phi^2 = 3", @intFromFloat(sx + 12), @intFromFloat(status_y), 10, rl.Color{ .r = @intFromFloat(0x60 * status_wave), .g = @intFromFloat(0x70 * status_wave), .b = @intFromFloat(0x80 * status_wave), .a = content_alpha });
            },
            .tools => {
                // Tools list
                const tools_list = [_][]const u8{ "inference", "embedding", "search", "generate", "vision", "voice" };
                for (tools_list, 0..) |tool, i| {
                    const tool_y = content_y + 10 + @as(f32, @floatFromInt(i)) * 28;
                    const is_selected = i == self.tool_selected;
                    // Background
                    if (is_selected) {
                        rl.DrawRectangle(@intFromFloat(sx + 8), @intFromFloat(tool_y - 2), @intFromFloat(sw - 16), 24, withAlpha(@as(rl.Color, @bitCast(theme.tool_selected_bg)), content_alpha));
                    }
                    // Icon placeholder
                    rl.DrawCircle(@intFromFloat(sx + 22), @intFromFloat(tool_y + 10), 6, withAlpha(HYPER_GREEN, content_alpha));
                    // Text
                    rl.DrawText(tool.ptr, @intFromFloat(sx + 36), @intFromFloat(tool_y + 4), 12, if (is_selected) withAlpha(TEXT_WHITE, content_alpha) else text_color);
                }
            },
            .settings => {
                // Settings toggles
                const settings = [_]struct { name: []const u8, on: bool }{
                    .{ .name = "Dark Mode", .on = true },
                    .{ .name = "Animations", .on = true },
                    .{ .name = "Sound", .on = false },
                    .{ .name = "Auto-save", .on = true },
                    .{ .name = "Notifications", .on = false },
                };
                for (settings, 0..) |setting, i| {
                    const set_y = content_y + 10 + @as(f32, @floatFromInt(i)) * 32;
                    // Label
                    rl.DrawText(setting.name.ptr, @intFromFloat(sx + 16), @intFromFloat(set_y + 4), 12, text_color);
                    // Toggle
                    const toggle_x = sx + sw - 50;
                    const toggle_color = if (setting.on) withAlpha(@as(rl.Color, @bitCast(theme.settings_toggle_on)), content_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.settings_toggle_off)), content_alpha);
                    rl.DrawRectangleRounded(.{ .x = toggle_x, .y = set_y, .width = 36, .height = 20 }, 0.5, 8, toggle_color);
                    const knob_x = if (setting.on) toggle_x + 20 else toggle_x + 4;
                    rl.DrawCircle(@intFromFloat(knob_x + 6), @intFromFloat(set_y + 10), 8, withAlpha(TEXT_WHITE, content_alpha));
                }
            },
            .vision => {
                // === MULTI-MODAL VISION ANALYZER ===
                const img_size: f32 = @min(sw - 40, content_h - 80);
                const img_x = sx + (sw - img_size) / 2;
                const img_y = content_y + 10;
                const img_h = img_size * 0.6;

                // Image placeholder with scanning effect
                rl.DrawRectangleRounded(.{ .x = img_x, .y = img_y, .width = img_size, .height = img_h }, 0.02, 8, withAlpha(BG_INPUT, content_alpha));

                // Analyzing animation - scanning line + wave burst
                if (self.vision_analyzing) {
                    // Scanning line
                    const scan_y = img_y + (self.vision_progress * img_h);
                    rl.DrawLine(@intFromFloat(img_x + 5), @intFromFloat(scan_y), @intFromFloat(img_x + img_size - 5), @intFromFloat(scan_y), rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 200) });
                    // Glow
                    rl.DrawRectangle(@intFromFloat(img_x), @intFromFloat(scan_y - 2), @intFromFloat(img_size), 4, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 50) });

                    // Wave burst from scan position
                    const burst_rings: usize = 3;
                    for (0..burst_rings) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = 10 + ring_f * 15 + @sin(time * 5) * 5;
                        const ring_alpha: u8 = @intFromFloat(@max(0, self.opacity * 60 * (1.0 - ring_f / 3.0)));
                        rl.DrawCircleLines(@intFromFloat(img_x + img_size / 2), @intFromFloat(scan_y), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha });
                    }

                    // Progress bar
                    const progress_w = (sw - 40) * self.vision_progress;
                    rl.DrawRectangle(@intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 10), @intFromFloat(progress_w), 4, NEON_MAGENTA);
                    rl.DrawRectangleLines(@intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 10), @intFromFloat(sw - 40), 4, rl.Color{ .r = 0x40, .g = 0x40, .b = 0x50, .a = content_alpha });

                    rl.DrawText("Analyzing cosmic patterns...", @intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 20), 11, NEON_CYAN);
                } else if (self.vision_result_len > 0) {
                    // Show result with wave glow
                    const result_wave = @sin(time * 2) * 0.2 + 0.8;
                    var result_buf: [260:0]u8 = undefined;
                    @memcpy(result_buf[0..self.vision_result_len], self.vision_result[0..self.vision_result_len]);
                    result_buf[self.vision_result_len] = 0;
                    rl.DrawText(&result_buf, @intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 15), 11, rl.Color{ .r = @intFromFloat(0x80 * result_wave), .g = @intFromFloat(0xFF * result_wave), .b = @intFromFloat(0x80 * result_wave), .a = content_alpha });

                    // Success burst rings
                    for (0..3) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = 30 + ring_f * 25 + @sin(time * 2 + ring_f) * 10;
                        rl.DrawCircleLines(@intFromFloat(img_x + img_size / 2), @intFromFloat(img_y + img_h / 2), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 30) });
                    }
                } else {
                    // Drop zone
                    rl.DrawRectangleRoundedLinesEx(.{ .x = img_x, .y = img_y, .width = img_size, .height = img_h }, 0.02, 8, 2.0, rl.Color{ .r = 0x40, .g = 0x40, .b = 0x40, .a = @intFromFloat(self.opacity * 100) });
                    rl.DrawText("+", @intFromFloat(img_x + img_size / 2 - 15), @intFromFloat(img_y + img_h / 2 - 20), 40, rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = content_alpha });
                    rl.DrawText("Click to analyze image", @intFromFloat(sx + 20), @intFromFloat(img_y + img_h + 15), 11, withAlpha(MUTED_GRAY, content_alpha));
                }
            },
            .voice => {
                // === MULTI-MODAL VOICE PANEL WITH STT RIPPLE ===
                const wave_center_y = content_y + content_h / 2 - 20;
                const wave_width = sw - 60;

                // Recording button (center top)
                const mic_btn_x = sx + sw / 2;
                const mic_btn_y = content_y + 30;
                const mic_btn_radius: f32 = if (self.voice_recording) 25 else 20;
                const mic_btn_pulse = @sin(self.voice_wave_phase) * 3;

                // Recording glow rings
                if (self.voice_recording) {
                    for (0..4) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_radius = mic_btn_radius + 10 + ring_f * 15 + @sin(self.voice_wave_phase + ring_f) * 5;
                        const ring_alpha: u8 = @intFromFloat(@max(0, self.opacity * 80 * (1.0 - ring_f / 4.0)));
                        rl.DrawCircleLines(@intFromFloat(mic_btn_x), @intFromFloat(mic_btn_y), ring_radius, rl.Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = ring_alpha });
                    }
                }

                // Button
                const mic_btn_color = if (self.voice_recording) rl.Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = content_alpha } else withAlpha(HYPER_GREEN, content_alpha);
                rl.DrawCircle(@intFromFloat(mic_btn_x), @intFromFloat(mic_btn_y), mic_btn_radius + mic_btn_pulse, mic_btn_color);

                // Mic icon
                if (self.voice_recording) {
                    rl.DrawRectangle(@intFromFloat(mic_btn_x - 4), @intFromFloat(mic_btn_y - 8), 8, 12, withAlpha(TEXT_WHITE, content_alpha));
                } else {
                    rl.DrawCircle(@intFromFloat(mic_btn_x), @intFromFloat(mic_btn_y), 8, withAlpha(TEXT_WHITE, content_alpha));
                }

                // === WAVEFORM VISUALIZATION ===
                const num_bars: usize = 48;
                const bar_w = wave_width / @as(f32, @floatFromInt(num_bars));

                for (0..num_bars) |i| {
                    const fi = @as(f32, @floatFromInt(i));
                    // Multiple wave frequencies for complex waveform
                    const wave1 = @sin(fi * 0.3 + self.voice_wave_phase);
                    const wave2 = @sin(fi * 0.7 + self.voice_wave_phase * 1.5) * 0.5;
                    const wave3 = @sin(fi * 0.1 + self.voice_wave_phase * 0.3) * 0.3;
                    const combined = (wave1 + wave2 + wave3) / 1.8;

                    const bar_h = 15.0 + combined * 40.0 * (0.3 + self.voice_amplitude * 0.7);
                    const bar_x = sx + 30 + fi * bar_w;
                    const bar_y = wave_center_y - bar_h / 2;

                    // Color gradient based on position and amplitude
                    const hue = 200.0 + fi * 2.0 + self.voice_amplitude * 60;
                    const saturation = 0.6 + self.voice_amplitude * 0.3;
                    const rgb = hsvToRgb(hue, saturation, 0.9);

                    // Draw bar with glow
                    if (self.voice_amplitude > 0.3) {
                        rl.DrawRectangle(@intFromFloat(bar_x - 1), @intFromFloat(bar_y - 2), @intFromFloat(bar_w), @intFromFloat(bar_h + 4), rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = content_alpha / 4 });
                    }
                    rl.DrawRectangle(@intFromFloat(bar_x), @intFromFloat(bar_y), @intFromFloat(bar_w - 2), @intFromFloat(bar_h), rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = content_alpha });
                }

                // STT Ripple effect when amplitude high
                if (self.voice_amplitude > 0.4) {
                    const ripple_radius = 30 + self.voice_amplitude * 50;
                    for (0..2) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        rl.DrawCircleLines(@intFromFloat(sx + sw / 2), @intFromFloat(wave_center_y), ripple_radius + ring_f * 20, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = @intFromFloat(self.opacity * 40) });
                    }
                }

                // Status text
                const status_y = sy + sh - 35;
                if (self.voice_recording) {
                    const blink = @mod(@as(u32, @intFromFloat(time * 2)), 2);
                    const rec_color = if (blink == 0) rl.Color{ .r = 0xFF, .g = 0x40, .b = 0x40, .a = content_alpha } else rl.Color{ .r = 0x80, .g = 0x20, .b = 0x20, .a = content_alpha };
                    rl.DrawCircle(@intFromFloat(sx + 25), @intFromFloat(status_y + 5), 5, rec_color);
                    rl.DrawText("Recording... (click to stop)", @intFromFloat(sx + 38), @intFromFloat(status_y), 11, rl.Color{ .r = 0xFF, .g = 0x80, .b = 0x80, .a = content_alpha });
                } else {
                    rl.DrawText("Click mic to start recording", @intFromFloat(sx + 20), @intFromFloat(status_y), 11, withAlpha(MUTED_GRAY, content_alpha));
                }
            },
            .finder => {
                // EMERGENT FINDER - Wave-based file system visualization
                const center_x = sx + sw / 2;
                const center_y = content_y + content_h / 2;

                // === CENTRAL WAVE SOURCE (Current Directory) ===
                // Pulsating center representing the root
                const pulse = @sin(time * 3.0) * 0.3 + 0.7;
                const core_radius: f32 = 20 * pulse;

                // Glow rings emanating from center
                for (0..5) |ring| {
                    const ring_f = @as(f32, @floatFromInt(ring));
                    const ring_radius = 30 + ring_f * 20 + @sin(time * 2.0 - ring_f * 0.5) * 5;
                    const ring_alpha: u8 = @intFromFloat(@max(0, @min(255, self.opacity * (80 - ring_f * 15))));
                    rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), ring_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha });
                }

                // Central core
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), core_radius, rl.Color{ .r = 0x00, .g = 0xCC, .b = 0x66, .a = @intFromFloat(self.opacity * 200) });
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), core_radius * 0.6, rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = @intFromFloat(self.opacity * 150) });

                // === COSMIC RIPPLE EFFECT (on folder navigation) ===
                if (self.finder_ripple > 0) {
                    const ripple_progress = 1.0 - self.finder_ripple;
                    const max_ripple_radius = @min(content_h, sw) * 0.8;
                    for (0..4) |ring| {
                        const ring_f = @as(f32, @floatFromInt(ring));
                        const ring_delay = ring_f * 0.15;
                        const ring_progress = @max(0, @min(1.0, (ripple_progress - ring_delay) / 0.6));
                        if (ring_progress > 0) {
                            const ripple_radius = ring_progress * max_ripple_radius;
                            const ripple_alpha: u8 = @intFromFloat(@max(0, self.opacity * 180 * (1.0 - ring_progress)));
                            rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), ripple_radius, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ripple_alpha });
                            rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), ripple_radius + 2, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ripple_alpha / 2 });
                        }
                    }
                }

                // === ORBITING PHOTONS (Files and Folders) ===
                for (0..self.finder_entry_count) |i| {
                    const entry = &self.finder_entries[i];
                    const anim_progress = @min(1.0, self.finder_animation + @as(f32, @floatFromInt(i)) * 0.05);

                    // Calculate orbit position with animation
                    const angle = entry.orbit_angle + time * 0.3;
                    const radius = entry.orbit_radius * anim_progress;

                    const ex = center_x + @cos(angle) * radius;
                    const ey = center_y + @sin(angle) * radius;

                    // Get color based on file type
                    const base_color = entry.file_type.getColor();
                    const entry_alpha: u8 = @intFromFloat(self.opacity * 255 * anim_progress);

                    // Draw orbit trail (faint arc)
                    if (radius > 10) {
                        rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), radius, rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = @intFromFloat(self.opacity * 20) });
                    }

                    // Draw photon (size based on type)
                    const photon_size: f32 = if (entry.is_dir) 12 else 8;
                    const pulsate = @sin(time * 4.0 + entry.orbit_angle) * 2;

                    // Glow
                    rl.DrawCircle(@intFromFloat(ex), @intFromFloat(ey), photon_size + 4 + pulsate, rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = entry_alpha / 3 });
                    // Core
                    rl.DrawCircle(@intFromFloat(ex), @intFromFloat(ey), photon_size + pulsate, rl.Color{ .r = base_color.r, .g = base_color.g, .b = base_color.b, .a = entry_alpha });
                    // Highlight
                    if (i == self.finder_selected) {
                        rl.DrawCircleLines(@intFromFloat(ex), @intFromFloat(ey), photon_size + 6 + pulsate, rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = entry_alpha });
                    }

                    // Draw name on hover (if selected)
                    if (i == self.finder_selected and entry.name_len > 0) {
                        var name_buf: [130:0]u8 = undefined;
                        @memcpy(name_buf[0..entry.name_len], entry.name[0..entry.name_len]);
                        name_buf[entry.name_len] = 0;
                        const name_x = ex + photon_size + 8;
                        const name_y = ey - 6;
                        // Background
                        const name_width: f32 = @as(f32, @floatFromInt(entry.name_len)) * 7 + 4;
                        rl.DrawRectangle(@intFromFloat(name_x - 2), @intFromFloat(name_y - 2), @intFromFloat(@min(name_width, sw - 20)), 16, rl.Color{ .r = 0x10, .g = 0x10, .b = 0x10, .a = @intFromFloat(self.opacity * 200) });
                        rl.DrawText(&name_buf, @intFromFloat(name_x), @intFromFloat(name_y), 11, rl.Color{ .r = 0xE0, .g = 0xE0, .b = 0xE0, .a = entry_alpha });
                    }
                }

                // === PATH DISPLAY ===
                if (self.finder_path_len > 0) {
                    var path_buf: [64:0]u8 = undefined;
                    const show_len = @min(self.finder_path_len, 60);
                    @memcpy(path_buf[0..show_len], self.finder_path[0..show_len]);
                    if (self.finder_path_len > 60) {
                        path_buf[57] = '.';
                        path_buf[58] = '.';
                        path_buf[59] = '.';
                        path_buf[60] = 0;
                    } else {
                        path_buf[show_len] = 0;
                    }
                    rl.DrawText(&path_buf, @intFromFloat(sx + 12), @intFromFloat(content_y + 5), 10, withAlpha(MUTED_GRAY, content_alpha));
                }

                // === LEGEND ===
                const legend_y = sy + sh - 25;
                rl.DrawCircle(@intFromFloat(sx + 15), @intFromFloat(legend_y), 4, withAlpha(HYPER_GREEN, content_alpha));
                rl.DrawText("DIR", @intFromFloat(sx + 22), @intFromFloat(legend_y - 4), 8, withAlpha(MUTED_GRAY, content_alpha));
                rl.DrawCircle(@intFromFloat(sx + 55), @intFromFloat(legend_y), 4, rl.Color{ .r = 0xF7, .g = 0xA4, .b = 0x1D, .a = content_alpha });
                rl.DrawText(".zig", @intFromFloat(sx + 62), @intFromFloat(legend_y - 4), 8, withAlpha(MUTED_GRAY, content_alpha));
                rl.DrawCircle(@intFromFloat(sx + 95), @intFromFloat(legend_y), 4, rl.Color{ .r = 0x80, .g = 0xFF, .b = 0xA0, .a = content_alpha });
                rl.DrawText("code", @intFromFloat(sx + 102), @intFromFloat(legend_y - 4), 8, withAlpha(MUTED_GRAY, content_alpha));

                // Count display
                var count_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&count_buf, "{d} items", .{self.finder_entry_count}) catch {};
                rl.DrawText(&count_buf, @intFromFloat(sx + sw - 70), @intFromFloat(legend_y - 4), 10, withAlpha(MUTED_GRAY, content_alpha));
            },
            .system => {
                // === SYSTEM MONITORING PANEL (Hyper Terminal Style) ===
                const row_h: f32 = 60;
                const bar_h: f32 = 8;
                const margin: f32 = 20;

                // Simulated system stats (computed from time for smooth animation)
                const cpu_usage = 25.0 + @sin(time * 0.5) * 15 + @sin(time * 1.3) * 8;
                const mem_used = 8.2 + @sin(time * 0.3) * 0.5;
                const mem_total: f32 = 16.0;
                const cpu_temp = 45.0 + @sin(time * 0.7) * 8;

                // === CPU Usage ===
                const cpu_y = content_y + 10;
                rl.DrawTextEx(font, "CPU", .{ .x = sx + margin, .y = cpu_y }, 14, 0.5, HYPER_CYAN);
                var cpu_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&cpu_buf, "{d:.1}%", .{cpu_usage}) catch {};
                rl.DrawTextEx(font, &cpu_buf, .{ .x = sx + sw - margin - 50, .y = cpu_y }, 14, 0.5, TEXT_WHITE);

                // CPU bar background (Hyper style)
                const cpu_bar_y = cpu_y + 22;
                const bar_w = sw - margin * 2;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(cpu_bar_y), @intFromFloat(bar_w), @intFromFloat(bar_h), withAlpha(BG_BAR, content_alpha));
                // CPU bar fill
                const cpu_fill = bar_w * (cpu_usage / 100.0);
                const cpu_color = if (cpu_usage > 80) HYPER_RED else if (cpu_usage > 50) HYPER_YELLOW else HYPER_GREEN;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(cpu_bar_y), @intFromFloat(cpu_fill), @intFromFloat(bar_h), cpu_color);

                // === Memory Usage ===
                const mem_y = content_y + row_h + 10;
                rl.DrawTextEx(font, "MEMORY", .{ .x = sx + margin, .y = mem_y }, 14, 0.5, HYPER_MAGENTA);
                var mem_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&mem_buf, "{d:.1} / {d:.0} GB", .{ mem_used, mem_total }) catch {};
                rl.DrawTextEx(font, &mem_buf, .{ .x = sx + sw - margin - 100, .y = mem_y }, 14, 0.5, TEXT_WHITE);

                // Memory bar (Hyper style)
                const mem_bar_y = mem_y + 22;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(mem_bar_y), @intFromFloat(bar_w), @intFromFloat(bar_h), withAlpha(BG_BAR, content_alpha));
                const mem_pct = mem_used / mem_total;
                const mem_fill = bar_w * mem_pct;
                const mem_color = if (mem_pct > 0.8) HYPER_RED else if (mem_pct > 0.5) HYPER_YELLOW else HYPER_MAGENTA;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(mem_bar_y), @intFromFloat(mem_fill), @intFromFloat(bar_h), mem_color);

                // === Temperature ===
                const temp_y = content_y + row_h * 2 + 10;
                rl.DrawTextEx(font, "TEMP", .{ .x = sx + margin, .y = temp_y }, 14, 0.5, HYPER_YELLOW);
                var temp_buf: [32:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&temp_buf, "{d:.0}C", .{cpu_temp}) catch {};
                rl.DrawTextEx(font, &temp_buf, .{ .x = sx + sw - margin - 40, .y = temp_y }, 14, 0.5, TEXT_WHITE);

                // Temperature bar (Hyper style)
                const temp_bar_y = temp_y + 22;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(temp_bar_y), @intFromFloat(bar_w), @intFromFloat(bar_h), withAlpha(BG_BAR, content_alpha));
                const temp_pct = @min(1.0, (cpu_temp - 30) / 70.0); // 30-100C range
                const temp_fill = bar_w * temp_pct;
                const temp_color = if (cpu_temp > 80) HYPER_RED else if (cpu_temp > 60) HYPER_YELLOW else HYPER_CYAN;
                rl.DrawRectangle(@intFromFloat(sx + margin), @intFromFloat(temp_bar_y), @intFromFloat(temp_fill), @intFromFloat(bar_h), temp_color);

                // === System Info ===
                const info_y = content_y + row_h * 3 + 20;
                rl.DrawTextEx(font, "SYSTEM", .{ .x = sx + margin, .y = info_y }, 12, 0.5, MUTED_GRAY);
                rl.DrawTextEx(font, "macOS | Apple M1 Pro", .{ .x = sx + margin, .y = info_y + 18 }, 11, 0.5, withAlpha(SEPARATOR, content_alpha));
                rl.DrawTextEx(font, "TRINITY OS v1.8", .{ .x = sx + margin, .y = info_y + 36 }, 11, 0.5, rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = content_alpha });

                // Pulse effect for active monitoring
                const pulse_alpha: u8 = @intFromFloat(50 + @sin(time * 3) * 20);
                rl.DrawCircle(@intFromFloat(sx + sw - 30), @intFromFloat(content_y + 20), 4, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = pulse_alpha });
            },

            .sacred_world => {
                // === SACRED WORLD PANEL — Route by world_id ===
                const world = sacred_worlds.getWorldByBlock(self.world_id);
                const realm = sacred_worlds.blockToRealm(self.world_id);
                const realm_r = sacred_worlds.realmColorR(realm);
                const realm_g = sacred_worlds.realmColorG(realm);
                const realm_b = sacred_worlds.realmColorB(realm);
                const rc = rl.Color{ .r = realm_r, .g = realm_g, .b = realm_b, .a = content_alpha };
                const margin: f32 = 20 * g_font_scale;
                const fs = g_font_scale;

                // ── Common header for all sacred_world panels ──
                const header_h: f32 = 36 * fs;
                // Header: fully opaque (never transparent)
                rl.DrawRectangle(@intFromFloat(sx), @intFromFloat(content_y), @intFromFloat(sw), @intFromFloat(header_h), SACRED_HEADER_BG);
                rl.DrawCircle(@intFromFloat(sx + 12 * fs), @intFromFloat(content_y + header_h / 2), 4 * fs, rc);
                rl.DrawLine(@intFromFloat(sx), @intFromFloat(content_y + header_h), @intFromFloat(sx + sw), @intFromFloat(content_y + header_h), rc);

                const ri = @intFromEnum(realm);
                const rn_len = sacred_worlds.REALM_NAME_LENS[ri];
                var realm_buf: [16:0]u8 = undefined;
                @memcpy(realm_buf[0..rn_len], sacred_worlds.REALM_NAMES[ri][0..rn_len]);
                realm_buf[rn_len] = 0;
                rl.DrawTextEx(font, &realm_buf, .{ .x = sx + margin + 4, .y = content_y + 10 * fs }, 14 * fs, 0.5, SACRED_HEADER_TEXT);

                const rs_len = sacred_worlds.REALM_SYMBOL_LENS[ri];
                var sym_buf: [8:0]u8 = undefined;
                @memcpy(sym_buf[0..rs_len], sacred_worlds.REALM_SYMBOLS[ri][0..rs_len]);
                sym_buf[rs_len] = 0;
                rl.DrawTextEx(font, &sym_buf, .{ .x = sx + sw - margin - 30 * fs, .y = content_y + 10 * fs }, 14 * fs, 0.5, SACRED_HEADER_TEXT);

                // Content area below header
                const body_y = content_y + header_h + 4 * fs;
                const body_h = content_h - header_h - 4 * fs;

                // ── ROUTE BY WORLD_ID ──
                if (self.world_id == 0) {
                    // ════════════════════════════════════════════
                    // CHAT PANEL (world_id 0) — Trinity Chat
                    // Uses GLOBAL chat state (persistent across panel reopen)
                    // ════════════════════════════════════════════

                    // Smooth scroll (global)
                    const chat_dt = rl.GetFrameTime();
                    g_chat_scroll_y += (g_chat_scroll_target - g_chat_scroll_y) * @min(1.0, 8.0 * chat_dt);

                    const chat_top = body_y + 8 * fs;
                    const input_h: f32 = 48 * fs;
                    const chat_bottom = content_y + content_h - input_h - 8 * fs;
                    const msg_area_h = chat_bottom - chat_top;
                    const line_h: f32 = 22 * fs;
                    const chat_font = g_font_chat;
                    const msg_font_size: f32 = 17 * fs;
                    const bubble_pad: f32 = 14 * fs;
                    const chat_margin: f32 = 70 * fs; // Extra padding for chat messages and input
                    const max_text_w = sw - chat_margin * 2 - bubble_pad * 2;
                    // Chat colors: from theme (dark=white-on-dark, light=dark-on-light)
                    const chat_text_color = withAlpha(CHAT_TEXT, content_alpha);
                    _ = CHAT_BUBBLE_USER; // reserved for future use

                    // Scissor clip for messages
                    rl.BeginScissorMode(@intFromFloat(sx), @intFromFloat(chat_top), @intFromFloat(sw), @intFromFloat(@max(1, msg_area_h)));

                    // Clamp scroll before rendering
                    g_chat_scroll_target = @max(0, g_chat_scroll_target);

                    if (g_chat_msg_count == 0) {
                        // Welcome message
                        const welcome_y = chat_top + msg_area_h * 0.3;
                        rl.DrawTextEx(chat_font, "Trinity AI", .{ .x = sx + chat_margin, .y = welcome_y }, 18 * fs, 0.5, withAlpha(HYPER_GREEN, content_alpha));
                        rl.DrawTextEx(chat_font, "Type a message below to start chatting.", .{ .x = sx + chat_margin, .y = welcome_y + 24 * fs }, 14 * fs, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                        g_chat_scroll_target = 0;
                        g_chat_scroll_y = 0;
                    } else {
                        // Render messages with simple line-based rendering (no word-wrap byte corruption)
                        var render_y: f32 = chat_top + 6 * fs - g_chat_scroll_y;
                        var mi: usize = 0;
                        while (mi < g_chat_msg_count) : (mi += 1) {
                            const msg_type = g_chat_msg_types[mi];
                            const msg_len = g_chat_msg_lens[mi];
                            const msg_data = g_chat_messages[mi][0..msg_len];

                            // Log messages: small dimmed text, no label
                            if (msg_type == .log) {
                                if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                    var log_z: [256:0]u8 = undefined;
                                    @memcpy(log_z[0..msg_len], msg_data);
                                    log_z[msg_len] = 0;
                                    const log_font_size: f32 = 13 * fs;
                                    const log_color = rl.Color{ .r = 120, .g = 120, .b = 140, .a = 180 };
                                    rl.DrawTextEx(chat_font, &log_z, .{ .x = sx + chat_margin, .y = render_y }, log_font_size, 0.3, log_color);
                                }
                                render_y += 18 * fs;
                                continue;
                            }

                            const is_user = msg_type == .user;

                            // Label — user on right, Trinity on left
                            if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                const label_color = if (is_user) withAlpha(CHAT_LABEL_USER, content_alpha) else withAlpha(CHAT_LABEL_AI, content_alpha);
                                if (is_user) {
                                    const you_w = rl.MeasureTextEx(chat_font, "You", 16 * fs, 0.5).x;
                                    rl.DrawTextEx(chat_font, "You", .{ .x = sx + sw - chat_margin - you_w, .y = render_y }, 16 * fs, 0.5, label_color);
                                } else {
                                    rl.DrawTextEx(chat_font, "Trinity", .{ .x = sx + chat_margin, .y = render_y }, 16 * fs, 0.5, label_color);
                                }
                            }
                            render_y += 18 * fs;

                            // Measure actual text width for bubble sizing
                            var full_z: [256:0]u8 = undefined;
                            @memcpy(full_z[0..msg_len], msg_data);
                            full_z[msg_len] = 0;
                            const text_size = rl.MeasureTextEx(chat_font, &full_z, msg_font_size, 0.5);

                            // Bubble alignment: user=right, Trinity=left
                            const needs_wrap = text_size.x > max_text_w;

                            if (!needs_wrap) {
                                if (is_user) {
                                    // User: plain text, right-aligned (no bubble)
                                    const text_x = sx + sw - chat_margin - text_size.x;
                                    if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                        // Fake bold
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = text_x, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = text_x + 0.6, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                    }
                                    render_y += line_h + 8 * fs;
                                } else {
                                    // Trinity: clean text, no bubble, left-aligned
                                    if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = sx + chat_margin, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                        rl.DrawTextEx(chat_font, &full_z, .{ .x = sx + chat_margin + 0.6, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                    }
                                    render_y += line_h + 8 * fs;
                                }
                            } else {
                                // Multi-line: UTF-8-safe word wrap
                                // First pass: count lines
                                var n_lines: f32 = 0;
                                {
                                    var pos: usize = 0;
                                    while (pos < msg_data.len) {
                                        // Find how many bytes fit in max_text_w
                                        var end = pos;
                                        var last_space: usize = pos;
                                        while (end < msg_data.len) {
                                            // Advance one UTF-8 char
                                            var next = end + 1;
                                            while (next < msg_data.len and (msg_data[next] & 0xC0) == 0x80) next += 1;
                                            // Measure width up to 'next'
                                            var tmp: [256:0]u8 = undefined;
                                            const seg_len = @min(next - pos, 255);
                                            @memcpy(tmp[0..seg_len], msg_data[pos .. pos + seg_len]);
                                            tmp[seg_len] = 0;
                                            const w = rl.MeasureTextEx(chat_font, &tmp, msg_font_size, 0.5).x;
                                            if (w > max_text_w and end > pos) break;
                                            if (msg_data[end] == ' ') last_space = end;
                                            end = next;
                                        }
                                        // Wrap at last space if possible
                                        if (end < msg_data.len and last_space > pos) end = last_space + 1 else if (end == pos) end = pos + 1;
                                        n_lines += 1;
                                        pos = end;
                                        // Skip leading space on next line
                                        while (pos < msg_data.len and msg_data[pos] == ' ') pos += 1;
                                    }
                                    if (n_lines == 0) n_lines = 1;
                                }

                                const bubble_h = n_lines * line_h;
                                const bubble_x = sx + chat_margin;

                                // Second pass: render lines (no bubble for either side)
                                var text_y = render_y;
                                var pos2: usize = 0;
                                var line_buf_chat: [256:0]u8 = undefined;
                                while (pos2 < msg_data.len) {
                                    var end2 = pos2;
                                    var last_sp2: usize = pos2;
                                    while (end2 < msg_data.len) {
                                        var next2 = end2 + 1;
                                        while (next2 < msg_data.len and (msg_data[next2] & 0xC0) == 0x80) next2 += 1;
                                        var tmp2: [256:0]u8 = undefined;
                                        const seg_len2 = @min(next2 - pos2, 255);
                                        @memcpy(tmp2[0..seg_len2], msg_data[pos2 .. pos2 + seg_len2]);
                                        tmp2[seg_len2] = 0;
                                        const w2 = rl.MeasureTextEx(chat_font, &tmp2, msg_font_size, 0.5).x;
                                        if (w2 > max_text_w and end2 > pos2) break;
                                        if (msg_data[end2] == ' ') last_sp2 = end2;
                                        end2 = next2;
                                    }
                                    if (end2 < msg_data.len and last_sp2 > pos2) end2 = last_sp2 + 1 else if (end2 == pos2) end2 = pos2 + 1;

                                    if (text_y >= chat_top - line_h and text_y <= chat_bottom + line_h) {
                                        const ln_len = @min(end2 - pos2, 255);
                                        @memcpy(line_buf_chat[0..ln_len], msg_data[pos2 .. pos2 + ln_len]);
                                        // Trim trailing space
                                        var tlen = ln_len;
                                        while (tlen > 0 and line_buf_chat[tlen - 1] == ' ') tlen -= 1;
                                        line_buf_chat[tlen] = 0;
                                        // Fake bold: double draw
                                        rl.DrawTextEx(chat_font, &line_buf_chat, .{ .x = bubble_x + bubble_pad, .y = text_y }, msg_font_size, 0.5, chat_text_color);
                                        rl.DrawTextEx(chat_font, &line_buf_chat, .{ .x = bubble_x + bubble_pad + 0.6, .y = text_y }, msg_font_size, 0.5, chat_text_color);
                                    }

                                    text_y += line_h;
                                    pos2 = end2;
                                    while (pos2 < msg_data.len and msg_data[pos2] == ' ') pos2 += 1;
                                }

                                render_y += bubble_h + 8 * fs;
                            }
                        }

                        // Calculate total content height for scroll clamping
                        const total_content_h = render_y + g_chat_scroll_y - (chat_top + 6 * fs);
                        const max_scroll = @max(0, total_content_h - msg_area_h + 20 * fs);
                        g_chat_scroll_target = @min(g_chat_scroll_target, max_scroll);
                        g_chat_scroll_y = @min(g_chat_scroll_y, max_scroll + 10 * fs);
                    }

                    rl.EndScissorMode();

                    // Mouse wheel scroll in chat
                    {
                        const cmx = @as(f32, @floatFromInt(rl.GetMouseX()));
                        const cmy = @as(f32, @floatFromInt(rl.GetMouseY()));
                        if (cmx >= sx and cmx <= sx + sw and cmy >= chat_top and cmy <= chat_bottom) {
                            g_chat_scroll_target -= rl.GetMouseWheelMove() * 40.0 * fs;
                            g_chat_scroll_target = @max(0, g_chat_scroll_target);
                        }
                    }

                    // Input area (bottom) — terminal style with separator lines
                    const input_y = chat_bottom + 4 * fs;
                    const sep_color = rl.Color{ .r = 100, .g = 100, .b = 110, .a = 120 };

                    // Background fill
                    rl.DrawRectangle(
                        @intFromFloat(sx + chat_margin),
                        @intFromFloat(input_y),
                        @intFromFloat(sw - chat_margin * 2),
                        @intFromFloat(input_h),
                        CHAT_INPUT_BG,
                    );
                    // Top separator line
                    rl.DrawLineEx(
                        .{ .x = sx + chat_margin, .y = input_y },
                        .{ .x = sx + sw - chat_margin, .y = input_y },
                        1.0,
                        sep_color,
                    );
                    // Bottom separator line
                    rl.DrawLineEx(
                        .{ .x = sx + chat_margin, .y = input_y + input_h },
                        .{ .x = sx + sw - chat_margin, .y = input_y + input_h },
                        1.0,
                        sep_color,
                    );

                    // ">" prompt
                    const prompt_color = rl.Color{ .r = 150, .g = 150, .b = 160, .a = 220 };
                    const prompt_y = input_y + 14 * fs;
                    const prompt_sz: f32 = 17 * fs;
                    rl.DrawTextEx(chat_font, ">", .{ .x = sx + chat_margin + 6 * fs, .y = prompt_y }, prompt_sz, 0.5, prompt_color);

                    // "↵ send" hint (right side)
                    const send_sz: f32 = 13 * fs;
                    const send_color = rl.Color{ .r = 140, .g = 140, .b = 150, .a = 180 };
                    const send_w = rl.MeasureTextEx(chat_font, "enter to send", send_sz, 0.5).x;
                    rl.DrawTextEx(chat_font, "enter to send", .{ .x = sx + sw - chat_margin - send_w - 10 * fs, .y = input_y + 16 * fs }, send_sz, 0.5, send_color);

                    if (g_chat_input_len > 0) {
                        var input_disp: [260:0]u8 = undefined;
                        const show_input = @min(g_chat_input_len, 255);
                        @memcpy(input_disp[0..show_input], g_chat_input[0..show_input]);
                        input_disp[show_input] = 0;
                        const ix = sx + chat_margin + 22 * fs;
                        const iy = input_y + 14 * fs;
                        const isz: f32 = 17 * fs;
                        rl.DrawTextEx(chat_font, &input_disp, .{ .x = ix, .y = iy }, isz, 0.5, CHAT_INPUT_TEXT);
                        rl.DrawTextEx(chat_font, &input_disp, .{ .x = ix + 0.5, .y = iy }, isz, 0.5, CHAT_INPUT_TEXT);
                        // Blinking rectangle cursor after text
                        if (@mod(@as(u32, @intFromFloat(time * 3)), 2) == 0) {
                            const text_w = rl.MeasureTextEx(chat_font, &input_disp, isz, 0.5).x;
                            const cur_x: i32 = @intFromFloat(ix + text_w + 2 * fs);
                            const cur_y: i32 = @intFromFloat(iy);
                            const cur_w: i32 = @intFromFloat(2 * fs);
                            const cur_h: i32 = @intFromFloat(isz);
                            rl.DrawRectangle(cur_x, cur_y, cur_w, cur_h, CHAT_INPUT_TEXT);
                        }
                    } else {
                        // Empty input: blinking rect cursor after ">"
                        const ph_x = sx + chat_margin + 22 * fs;
                        const ph_y = input_y + 14 * fs;
                        const ph_sz: f32 = 17 * fs;
                        if (@mod(@as(u32, @intFromFloat(time * 2)), 2) == 0) {
                            rl.DrawRectangle(@intFromFloat(ph_x), @intFromFloat(ph_y), @intFromFloat(2 * fs), @intFromFloat(ph_sz), CHAT_INPUT_TEXT);
                        }
                    }

                    // Status bar below input — real system info
                    {
                        const status_y = input_y + input_h + 3 * fs;
                        const status_sz: f32 = 11 * fs;
                        const status_color = rl.Color{ .r = 100, .g = 100, .b = 115, .a = 160 };
                        const fps_val = rl.GetFPS();

                        // Left: FPS + engine stats
                        var status_buf: [256:0]u8 = undefined;
                        if (g_fluent_engine_inited) {
                            const st = g_fluent_engine.getStats();
                            const sl = std.fmt.bufPrint(status_buf[0..255], "{d}fps | fluent {d:.0}% | {s} | {s} | s:{d:.1}", .{
                                fps_val,
                                st.fluent_rate * 100,
                                st.current_language.getName(),
                                st.current_topic.getName(),
                                st.sentiment,
                            }) catch "...";
                            status_buf[sl.len] = 0;
                        } else {
                            const sl = std.fmt.bufPrint(status_buf[0..255], "{d}fps | trinity v2.0 | ready", .{fps_val}) catch "...";
                            status_buf[sl.len] = 0;
                        }
                        rl.DrawTextEx(chat_font, &status_buf, .{ .x = sx + chat_margin + 4 * fs, .y = status_y }, status_sz, 0.3, status_color);

                        // Right: message count
                        var count_buf: [64:0]u8 = undefined;
                        const ct = std.fmt.bufPrint(count_buf[0..63], "{d} msgs", .{g_chat_msg_count}) catch "0";
                        count_buf[ct.len] = 0;
                        const count_w = rl.MeasureTextEx(chat_font, &count_buf, status_sz, 0.3).x;
                        rl.DrawTextEx(chat_font, &count_buf, .{ .x = sx + sw - chat_margin - count_w - 4 * fs, .y = status_y }, status_sz, 0.3, status_color);
                    }
                } else if (self.world_id == 18) {
                    // ════════════════════════════════════════════
                    // DOCS PANEL (world_id 18) — All 27 docs consolidated
                    // ════════════════════════════════════════════

                    rl.DrawTextEx(font, "ALL DOCUMENTATION", .{ .x = sx + margin, .y = body_y + 4 * fs }, 18 * fs, 0.5, accentText(rc, content_alpha));

                    const doc_top = body_y + 30 * fs;
                    const doc_h = body_h - 34 * fs;
                    const doc_x = sx + margin;
                    const doc_w = sw - margin * 2;
                    const line_h: f32 = 18 * fs;
                    const font_size_doc: f32 = 13 * fs;
                    const char_w: f32 = 7.0 * fs;
                    const chars_per_line: usize = @max(20, @as(usize, @intFromFloat(doc_w / char_w)));

                    rl.BeginScissorMode(@intFromFloat(sx), @intFromFloat(doc_top), @intFromFloat(sw), @intFromFloat(@max(1, doc_h)));

                    var render_y: f32 = doc_top - self.scroll_y;
                    var line_buf: [256:0]u8 = undefined;

                    // Render ALL 27 docs sequentially
                    var doc_idx: usize = 0;
                    while (doc_idx < 27) : (doc_idx += 1) {
                        const doc = world_docs.WORLD_DOCS[doc_idx];
                        const dworld = sacred_worlds.getWorldByBlock(doc_idx);

                        // Section header: "N. WORLD_NAME — subtitle"
                        var section_hdr: [80:0]u8 = undefined;
                        _ = std.fmt.bufPrintZ(&section_hdr, "{d}. {s}", .{ doc_idx + 1, dworld.name[0..dworld.name_len] }) catch {};

                        if (render_y >= doc_top - line_h and render_y <= doc_top + doc_h) {
                            const drealm = sacred_worlds.blockToRealm(doc_idx);
                            const sec_color = rl.Color{
                                .r = sacred_worlds.realmColorR(drealm),
                                .g = sacred_worlds.realmColorG(drealm),
                                .b = sacred_worlds.realmColorB(drealm),
                                .a = content_alpha,
                            };
                            rl.DrawTextEx(font, &section_hdr, .{ .x = doc_x, .y = render_y }, font_size_doc + 4, 0.5, accentText(sec_color, content_alpha));
                        }
                        render_y += line_h * 1.5;

                        // Subtitle
                        var sub_buf: [64:0]u8 = undefined;
                        const slen = @min(doc.subtitle.len, 63);
                        @memcpy(sub_buf[0..slen], doc.subtitle[0..slen]);
                        sub_buf[slen] = 0;
                        if (render_y >= doc_top - line_h and render_y <= doc_top + doc_h) {
                            rl.DrawTextEx(font, &sub_buf, .{ .x = doc_x, .y = render_y }, font_size_doc - 1, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                        }
                        render_y += line_h;

                        // Doc content (markdown rendered)
                        var iter = world_docs.LineIterator.init(doc.raw);
                        var in_fm = false;
                        while (iter.next()) |raw_line| {
                            const trimmed = blk: {
                                var ti: usize = 0;
                                while (ti < raw_line.len and (raw_line[ti] == ' ' or raw_line[ti] == '\t')) : (ti += 1) {}
                                break :blk raw_line[ti..];
                            };
                            if (trimmed.len >= 3 and trimmed[0] == '-' and trimmed[1] == '-' and trimmed[2] == '-') {
                                in_fm = !in_fm;
                                continue;
                            }
                            if (in_fm) continue;
                            if (world_docs.isNoiseLine(raw_line)) continue;

                            const heading_stripped = world_docs.stripHeading(raw_line);
                            const is_heading = (heading_stripped.ptr != raw_line.ptr or heading_stripped.len != raw_line.len);

                            var stripped_buf: [512]u8 = undefined;
                            const stripped_len = world_docs.stripInline(heading_stripped, &stripped_buf);
                            const display_line = stripped_buf[0..stripped_len];

                            var line_start: usize = 0;
                            while (line_start < display_line.len or line_start == 0) {
                                const remaining = if (line_start < display_line.len) display_line[line_start..] else "";
                                const chunk_len = if (remaining.len <= chars_per_line) remaining.len else blk2: {
                                    var best: usize = chars_per_line;
                                    var scan: usize = chars_per_line;
                                    while (scan > 0) {
                                        scan -= 1;
                                        if (remaining[scan] == ' ') {
                                            best = scan;
                                            break;
                                        }
                                    }
                                    break :blk2 best;
                                };

                                if (render_y >= doc_top - line_h and render_y <= doc_top + doc_h) {
                                    const copy_len = @min(chunk_len, 255);
                                    @memcpy(line_buf[0..copy_len], remaining[0..copy_len]);
                                    line_buf[copy_len] = 0;

                                    const doc_text_color = if (is_heading and line_start == 0)
                                        accentText(rc, content_alpha)
                                    else
                                        withAlpha(CONTENT_TEXT, content_alpha);
                                    const fsize: f32 = if (is_heading and line_start == 0) font_size_doc + 3 else font_size_doc;
                                    rl.DrawTextEx(font, &line_buf, .{ .x = doc_x, .y = render_y }, fsize, 0.5, doc_text_color);
                                }

                                render_y += line_h;
                                if (chunk_len == 0) break;
                                line_start += chunk_len;
                                if (line_start < display_line.len and display_line[line_start] == ' ') line_start += 1;
                                if (remaining.len <= chars_per_line) break;
                            }
                        }
                        // Gap between docs
                        render_y += line_h * 2;
                    }

                    rl.EndScissorMode();

                    // Scroll indicator
                    const total_text_h = render_y + self.scroll_y - doc_top;
                    if (total_text_h > doc_h) {
                        const scroll_track_x = sx + sw - 6;
                        const max_scroll_val = total_text_h - doc_h;
                        const scroll_pct = if (max_scroll_val > 0) self.scroll_y / max_scroll_val else 0;
                        const thumb_h = @max(20.0, doc_h * (doc_h / total_text_h));
                        const thumb_y = doc_top + scroll_pct * (doc_h - thumb_h);
                        rl.DrawRectangleRounded(
                            .{ .x = scroll_track_x, .y = thumb_y, .width = 4, .height = thumb_h },
                            1.0,
                            4,
                            withAlpha(rc, 60),
                        );
                    }
                } else if (self.world_id == 16) {
                    // ════════════════════════════════════════════
                    // NETWORK ADMIN PANEL (world_id 16 = monitor)
                    // Runtime-detected node data (no static/fake data)
                    // Ctrl+8 to open
                    // ════════════════════════════════════════════

                    // Initialize network state on first render (detects local machine)
                    initNetworkState();
                    // Update uptime counter
                    g_network_uptime_ms +|= @intFromFloat(rl.GetFrameTime() * 1000);

                    const pad = margin * 1.5;

                    // Update status when probe finishes
                    if (g_network_probe_done and std.mem.eql(u8, g_network_model_name[0..g_network_model_name_len], "Scanning network...")) {
                        if (g_network_node_count > 1) {
                            const done_msg = "Network detected";
                            @memcpy(g_network_model_name[0..done_msg.len], done_msg);
                            g_network_model_name_len = done_msg.len;
                        } else {
                            const done_msg = "No peers found";
                            @memcpy(g_network_model_name[0..done_msg.len], done_msg);
                            g_network_model_name_len = done_msg.len;
                        }
                    }

                    // ── Scrollable content area ──
                    const net_top = body_y + 4 * fs;
                    const net_area_h = content_h - (net_top - content_y) - 4 * fs;

                    // Smooth scroll (uses global vars, draw receives const self)
                    const net_dt = rl.GetFrameTime();
                    g_net_scroll_y += (g_net_scroll_target - g_net_scroll_y) * @min(1.0, 8.0 * net_dt);

                    // Scissor clip — all content clipped to panel body
                    rl.BeginScissorMode(@intFromFloat(sx), @intFromFloat(net_top), @intFromFloat(sw), @intFromFloat(@max(1, net_area_h)));

                    var render_y: f32 = net_top + 8 * fs - g_net_scroll_y;

                    // ── HEADER ──
                    rl.DrawTextEx(font, "NETWORK", .{ .x = sx + pad, .y = render_y }, 22 * fs, 0.5, accentText(rc, content_alpha));
                    var summary_buf: [64:0]u8 = undefined;
                    var online_count: usize = 0;
                    for (0..g_network_node_count) |ni| {
                        if (g_network_nodes[ni].status == .online) online_count += 1;
                    }
                    _ = std.fmt.bufPrintZ(&summary_buf, "{d} nodes | {d} online", .{ g_network_node_count, online_count }) catch {};
                    rl.DrawTextEx(font, &summary_buf, .{ .x = sx + sw - pad - 160 * fs, .y = render_y + 4 * fs }, 11 * fs, 0.5, withAlpha(HYPER_GREEN, content_alpha));
                    if (!g_network_probe_done) {
                        const spin_pulse: u8 = @intFromFloat(120 + @sin(time * 6) * 120);
                        rl.DrawCircle(@intFromFloat(sx + sw - pad - 170 * fs), @intFromFloat(render_y + 12 * fs), 3 * fs, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = spin_pulse });
                    } else {
                        const pulse_a: u8 = @intFromFloat(120 + @sin(time * 4) * 80);
                        rl.DrawCircle(@intFromFloat(sx + sw - pad - 170 * fs), @intFromFloat(render_y + 12 * fs), 3 * fs, rl.Color{ .r = 0x50, .g = 0xFA, .b = 0x7B, .a = pulse_a });
                    }
                    render_y += 32 * fs;

                    // ── 3D GLOBE ──
                    const globe_size = @min(sw - pad * 2, 420 * fs); // cap size for quality
                    const globe_r = globe_size / 2.0;
                    const globe_cx = sx + sw / 2.0;
                    const globe_cy = render_y + globe_r;

                    // Colors (Aceternity GitHub Globe exact palette)
                    const GLOBE_BASE = rl.Color{ .r = 0x06, .g = 0x20, .b = 0x56, .a = 0xFF };
                    const GLOBE_EMISSIVE = rl.Color{ .r = 0x08, .g = 0x28, .b = 0x68, .a = 0xFF };
                    const GLOBE_DOT_LAND = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xB3 }; // rgba(255,255,255,0.7)
                    const ATMO_WHITE = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF }; // atmosphereColor: #FFFFFF
                    const ATMO_BLUE = rl.Color{ .r = 0x38, .g = 0xBD, .b = 0xF8, .a = 0xFF }; // ambientLight: #38bdf8

                    const rot_angle = time * 0.12; // autoRotateSpeed: 0.5

                    // Outer atmosphere glow — wide soft halo (atmosphereAltitude: 0.1)
                    {
                        var ai: u32 = 0;
                        while (ai < 20) : (ai += 1) {
                            const af = @as(f32, @floatFromInt(ai));
                            const ar = globe_r + (af + 1.0) * 1.5 * fs;
                            const falloff = (1.0 - af / 20.0);
                            const aa: u8 = @intFromFloat(@max(0.0, falloff * falloff * 25.0 * @as(f32, @floatFromInt(content_alpha)) / 255.0));
                            rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, ar, withAlpha(ATMO_WHITE, aa));
                        }
                        // Inner blue tint atmosphere
                        var bi: u32 = 0;
                        while (bi < 6) : (bi += 1) {
                            const bf = @as(f32, @floatFromInt(bi));
                            const br = globe_r + (bf + 0.5) * 2.0 * fs;
                            const ba: u8 = @intFromFloat(@max(0.0, (1.0 - bf / 6.0) * 18.0 * @as(f32, @floatFromInt(content_alpha)) / 255.0));
                            rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, br, withAlpha(ATMO_BLUE, ba));
                        }
                    }

                    // Globe sphere: gradient fill (emissive: #062056 center, lighter edges)
                    rl.DrawCircle(@intFromFloat(globe_cx), @intFromFloat(globe_cy), globe_r, withAlpha(GLOBE_BASE, content_alpha));
                    // Emissive inner glow (lighter center)
                    rl.DrawCircle(@intFromFloat(globe_cx - globe_r * 0.15), @intFromFloat(globe_cy - globe_r * 0.15), globe_r * 0.6, withAlpha(GLOBE_EMISSIVE, content_alpha / 5));

                    // Latitude/longitude grid lines on sphere (shininess wireframe effect)
                    {
                        const GRID_COLOR = rl.Color{ .r = 0x20, .g = 0x50, .b = 0x80, .a = 0x18 };
                        // Latitude circles (every 30 deg)
                        var lat_i: i32 = -60;
                        while (lat_i <= 60) : (lat_i += 30) {
                            const lat_r = @as(f32, @floatFromInt(lat_i)) * math.pi / 180.0;
                            const circle_r = globe_r * @cos(lat_r);
                            const circle_y_off = globe_cy - globe_r * @sin(lat_r);
                            // Draw ellipse as line segments
                            var gi: u32 = 0;
                            while (gi < 48) : (gi += 1) {
                                const ga0 = @as(f32, @floatFromInt(gi)) / 48.0 * math.pi * 2.0 + rot_angle;
                                const ga1 = @as(f32, @floatFromInt(gi + 1)) / 48.0 * math.pi * 2.0 + rot_angle;
                                const gz0 = @sin(ga0);
                                const gz1 = @sin(ga1);
                                if (gz0 < -0.05 and gz1 < -0.05) continue;
                                const gx0 = globe_cx + @cos(ga0) * circle_r;
                                const gx1 = globe_cx + @cos(ga1) * circle_r;
                                const d0: u8 = @intFromFloat(@max(0.0, (gz0 + 0.05) / 1.05 * 0.4) * @as(f32, @floatFromInt(content_alpha)));
                                rl.DrawLineEx(.{ .x = gx0, .y = circle_y_off }, .{ .x = gx1, .y = circle_y_off }, 0.8, withAlpha(GRID_COLOR, d0));
                            }
                        }
                        // Longitude meridians (every 30 deg)
                        var lon_i: i32 = 0;
                        while (lon_i < 180) : (lon_i += 30) {
                            const lon_r = @as(f32, @floatFromInt(lon_i)) * math.pi / 180.0 + rot_angle;
                            var gi: u32 = 0;
                            while (gi < 48) : (gi += 1) {
                                const la0 = (@as(f32, @floatFromInt(gi)) / 48.0 - 0.5) * math.pi;
                                const la1 = (@as(f32, @floatFromInt(gi + 1)) / 48.0 - 0.5) * math.pi;
                                const z0 = @cos(la0) * @sin(lon_r);
                                const z1 = @cos(la1) * @sin(lon_r);
                                if (z0 < -0.05 and z1 < -0.05) continue;
                                const mx0 = globe_cx + @cos(la0) * @cos(lon_r) * globe_r;
                                const my0 = globe_cy - @sin(la0) * globe_r;
                                const mx1 = globe_cx + @cos(la1) * @cos(lon_r) * globe_r;
                                const my1 = globe_cy - @sin(la1) * globe_r;
                                const d0: u8 = @intFromFloat(@max(0.0, (z0 + 0.05) / 1.05 * 0.4) * @as(f32, @floatFromInt(content_alpha)));
                                rl.DrawLineEx(.{ .x = mx0, .y = my0 }, .{ .x = mx1, .y = my1 }, 0.8, withAlpha(GRID_COLOR, d0));
                            }
                        }
                    }

                    // Land dots on sphere (pointSize: 4, polygonColor: rgba(255,255,255,0.7))
                    const dot_base_r: f32 = @max(1.5, globe_r / 80.0);
                    {
                        var row: u32 = 0;
                        while (row < world_dots.ROWS) : (row += 2) {
                            const lat_rad = (90.0 - @as(f32, @floatFromInt(row)) * 2.0) * math.pi / 180.0;
                            const cos_lat = @cos(lat_rad);
                            const sin_lat = @sin(lat_rad);
                            var col: u32 = 0;
                            while (col < world_dots.COLS) : (col += 2) {
                                const lon_rad = (-180.0 + @as(f32, @floatFromInt(col)) * 2.0) * math.pi / 180.0 + rot_angle;
                                const gx3 = cos_lat * @cos(lon_rad);
                                const gy3 = sin_lat;
                                const gz3 = cos_lat * @sin(lon_rad);
                                if (gz3 < -0.05) continue;

                                const scr_x = globe_cx + gx3 * globe_r;
                                const scr_y = globe_cy - gy3 * globe_r;
                                const depth = @max(0.0, gz3 + 0.05) / 1.05;

                                if (world_dots.isLand(row, col)) {
                                    const da: u8 = @intFromFloat(depth * @as(f32, @floatFromInt(content_alpha)) * 0.75);
                                    const dr = dot_base_r * (0.7 + depth * 0.6);
                                    rl.DrawCircle(@intFromFloat(scr_x), @intFromFloat(scr_y), dr, withAlpha(GLOBE_DOT_LAND, da));
                                }
                            }
                        }
                    }

                    // Rim light (shininess: 0.9)
                    rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, globe_r, withAlpha(ATMO_WHITE, content_alpha / 8));
                    rl.DrawCircleLinesV(.{ .x = globe_cx, .y = globe_cy }, globe_r - 0.5, withAlpha(ATMO_BLUE, content_alpha / 6));

                    // ── Arc connections (arcTime: 1000, arcLength: 0.9) ──
                    if (g_network_node_count > 1) {
                        const local_nd = g_network_nodes[0];
                        var ci: usize = 1;
                        while (ci < g_network_node_count) : (ci += 1) {
                            const remote_nd = g_network_nodes[ci];
                            if (remote_nd.is_local) continue;

                            const lat1 = local_nd.geo_lat * math.pi / 180.0;
                            const lon1 = local_nd.geo_lon * math.pi / 180.0 + rot_angle;
                            const lat2 = remote_nd.geo_lat * math.pi / 180.0;
                            const lon2 = remote_nd.geo_lon * math.pi / 180.0 + rot_angle;

                            // Arc colors cycle: #06b6d4, #3b82f6, #6366f1
                            const arc_colors = [_][3]u8{ .{ 0x06, 0xB6, 0xD4 }, .{ 0x3B, 0x82, 0xF6 }, .{ 0x63, 0x66, 0xF1 } };
                            const ac = arc_colors[ci % 3];

                            const ARC_SEGS: u32 = 32;
                            const arc_phase = @mod(time * 1.0 + @as(f32, @floatFromInt(ci)) * 1.5, 1.0); // arcTime: 1000ms
                            var seg: u32 = 0;
                            while (seg < ARC_SEGS) : (seg += 1) {
                                const t0 = @as(f32, @floatFromInt(seg)) / @as(f32, @floatFromInt(ARC_SEGS));
                                const t1 = @as(f32, @floatFromInt(seg + 1)) / @as(f32, @floatFromInt(ARC_SEGS));

                                const alt0 = 1.0 + 0.12 * @sin(t0 * math.pi);
                                const alt1 = 1.0 + 0.12 * @sin(t1 * math.pi);
                                const la0 = lat1 + (lat2 - lat1) * t0;
                                const lo0 = lon1 + (lon2 - lon1) * t0;
                                const la1_v = lat1 + (lat2 - lat1) * t1;
                                const lo1_v = lon1 + (lon2 - lon1) * t1;

                                const px0 = globe_cx + @cos(la0) * @cos(lo0) * globe_r * alt0;
                                const py0 = globe_cy - @sin(la0) * globe_r * alt0;
                                const pz0 = @cos(la0) * @sin(lo0);
                                const px1 = globe_cx + @cos(la1_v) * @cos(lo1_v) * globe_r * alt1;
                                const py1 = globe_cy - @sin(la1_v) * globe_r * alt1;
                                const pz1 = @cos(la1_v) * @sin(lo1_v);
                                if (pz0 < -0.15 and pz1 < -0.15) continue;

                                // arcLength: 0.9 — traveling bright band
                                const seg_mid = (t0 + t1) / 2.0;
                                const pulse_d = @abs(seg_mid - arc_phase);
                                const pulse_b = @max(0.0, 1.0 - pulse_d * 4.0); // wide band

                                const ca: u8 = @intFromFloat(@min(255.0, 30.0 + pulse_b * 220.0));
                                const thick = 1.5 * fs + pulse_b * 2.0 * fs;
                                rl.DrawLineEx(.{ .x = px0, .y = py0 }, .{ .x = px1, .y = py1 }, thick, rl.Color{ .r = ac[0], .g = ac[1], .b = ac[2], .a = ca });
                            }
                        }
                    }

                    // ── Node markers (rings: 1, maxRings: 3) ──
                    for (0..g_network_node_count) |ni| {
                        const node = g_network_nodes[ni];
                        const nlat = node.geo_lat * math.pi / 180.0;
                        const nlon = node.geo_lon * math.pi / 180.0 + rot_angle;
                        const nz = @cos(nlat) * @sin(nlon);
                        if (nz < -0.05) continue;
                        const nx_g = globe_cx + @cos(nlat) * @cos(nlon) * globe_r;
                        const ny_g = globe_cy - @sin(nlat) * globe_r;
                        const depth = @max(0.0, nz + 0.05) / 1.05;
                        const nc: rl.Color = switch (node.status) {
                            .online => @bitCast(theme.accents.node_online),
                            .connecting => @bitCast(theme.accents.node_connecting),
                            .degraded => @bitCast(theme.accents.node_degraded),
                            .error_state => @bitCast(theme.accents.node_error),
                            .offline => @bitCast(theme.accents.node_offline),
                        };
                        // Expanding rings
                        var ring: u32 = 0;
                        while (ring < 3) : (ring += 1) {
                            const phase = @mod(time * 1.0 + @as(f32, @floatFromInt(ring)) * 0.33 + @as(f32, @floatFromInt(ni)) * 0.7, 1.0);
                            const rr = 3.0 * fs + phase * 16.0 * fs;
                            const ra: u8 = @intFromFloat(@max(0.0, (1.0 - phase) * 50.0 * depth));
                            rl.DrawCircleLinesV(.{ .x = nx_g, .y = ny_g }, rr, withAlpha(nc, ra));
                        }
                        const dot_a: u8 = @intFromFloat(depth * @as(f32, @floatFromInt(content_alpha)));
                        rl.DrawCircle(@intFromFloat(nx_g), @intFromFloat(ny_g), 5.0 * fs, withAlpha(nc, dot_a));
                        rl.DrawCircle(@intFromFloat(nx_g), @intFromFloat(ny_g), 8.0 * fs, withAlpha(nc, dot_a / 4));
                        // Label
                        if (depth > 0.4) {
                            var loc_buf: [36:0]u8 = undefined;
                            @memcpy(loc_buf[0..node.location_len], node.location[0..node.location_len]);
                            loc_buf[node.location_len] = 0;
                            rl.DrawTextEx(font, &loc_buf, .{ .x = nx_g + 12 * fs, .y = ny_g - 6 * fs }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, dot_a));
                        }
                    }

                    render_y += globe_size + 20 * fs;

                    // ── CONNECTED NODES ──
                    rl.DrawLine(@intFromFloat(sx + pad), @intFromFloat(render_y), @intFromFloat(sx + sw - pad), @intFromFloat(render_y), withAlpha(BORDER_SUBTLE, content_alpha / 3));
                    render_y += 12 * fs;
                    rl.DrawTextEx(font, "CONNECTED NODES", .{ .x = sx + pad, .y = render_y }, 12 * fs, 0.5, withAlpha(MUTED_GRAY, content_alpha));
                    render_y += 20 * fs;

                    for (0..g_network_node_count) |ni| {
                        const node = g_network_nodes[ni];
                        const node_color: rl.Color = switch (node.status) {
                            .online => @bitCast(theme.accents.node_online),
                            .connecting => @bitCast(theme.accents.node_connecting),
                            .degraded => @bitCast(theme.accents.node_degraded),
                            .error_state => @bitCast(theme.accents.node_error),
                            .offline => @bitCast(theme.accents.node_offline),
                        };

                        // Card background
                        rl.DrawRectangleRounded(.{ .x = sx + pad, .y = render_y, .width = sw - pad * 2, .height = 56 * fs }, 0.08, 4, withAlpha(BG_INPUT, content_alpha));
                        rl.DrawRectangleRoundedLinesEx(.{ .x = sx + pad, .y = render_y, .width = sw - pad * 2, .height = 56 * fs }, 0.08, 4, 1.0, withAlpha(node_color, content_alpha / 3));

                        // Status dot
                        rl.DrawCircle(@intFromFloat(sx + pad + 14 * fs), @intFromFloat(render_y + 16 * fs), 4 * fs, withAlpha(node_color, content_alpha));

                        // Name + role
                        var name_buf: [36:0]u8 = undefined;
                        @memcpy(name_buf[0..node.name_len], node.name[0..node.name_len]);
                        name_buf[node.name_len] = 0;
                        rl.DrawTextEx(font, &name_buf, .{ .x = sx + pad + 28 * fs, .y = render_y + 6 * fs }, 12 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));

                        var role_buf: [20:0]u8 = undefined;
                        @memcpy(role_buf[0..node.role_len], node.role[0..node.role_len]);
                        role_buf[node.role_len] = 0;
                        rl.DrawTextEx(font, &role_buf, .{ .x = sx + pad + 28 * fs, .y = render_y + 24 * fs }, 10 * fs, 0.5, withAlpha(HYPER_CYAN, content_alpha));

                        // Location
                        var loc_buf2: [36:0]u8 = undefined;
                        @memcpy(loc_buf2[0..node.location_len], node.location[0..node.location_len]);
                        loc_buf2[node.location_len] = 0;
                        rl.DrawTextEx(font, &loc_buf2, .{ .x = sx + pad + 28 * fs, .y = render_y + 40 * fs }, 9 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                        // Right side: RAM + address
                        var ram_buf: [16:0]u8 = undefined;
                        _ = std.fmt.bufPrintZ(&ram_buf, "{d}MB", .{node.ram_mb}) catch {};
                        rl.DrawTextEx(font, &ram_buf, .{ .x = sx + sw - pad - 70 * fs, .y = render_y + 6 * fs }, 11 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));

                        var addr_buf: [52:0]u8 = undefined;
                        @memcpy(addr_buf[0..node.address_len], node.address[0..node.address_len]);
                        addr_buf[node.address_len] = 0;
                        rl.DrawTextEx(font, &addr_buf, .{ .x = sx + sw - pad - 140 * fs, .y = render_y + 24 * fs }, 9 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                        const lr_text: [*:0]const u8 = if (node.is_local) "LOCAL" else "REMOTE";
                        const lr_c = if (node.is_local) withAlpha(@as(rl.Color, @bitCast(theme.accents.node_local)), content_alpha) else withAlpha(@as(rl.Color, @bitCast(theme.accents.node_remote)), content_alpha);
                        rl.DrawTextEx(font, lr_text, .{ .x = sx + sw - pad - 50 * fs, .y = render_y + 40 * fs }, 9 * fs, 0.5, lr_c);

                        render_y += 62 * fs;
                    }

                    // ── JOIN NETWORK ──
                    render_y += 8 * fs;
                    rl.DrawLine(@intFromFloat(sx + pad), @intFromFloat(render_y), @intFromFloat(sx + sw - pad), @intFromFloat(render_y), withAlpha(BORDER_SUBTLE, content_alpha / 3));
                    render_y += 12 * fs;
                    rl.DrawTextEx(font, "JOIN NETWORK", .{ .x = sx + pad, .y = render_y }, 14 * fs, 0.5, accentText(rc, content_alpha));
                    render_y += 22 * fs;
                    rl.DrawTextEx(font, "1. zig build tri", .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));
                    render_y += 16 * fs;
                    rl.DrawTextEx(font, "2. ./zig-out/bin/tri node --worker", .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));
                    render_y += 16 * fs;
                    rl.DrawTextEx(font, "3. Auto-discover via UDP 9333", .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_WHITE, content_alpha));
                    render_y += 24 * fs;
                    const uptime_s = g_network_uptime_ms / 1000;
                    var uptime_buf: [32:0]u8 = undefined;
                    _ = std.fmt.bufPrintZ(&uptime_buf, "uptime: {d}s", .{uptime_s}) catch {};
                    rl.DrawTextEx(font, &uptime_buf, .{ .x = sx + pad, .y = render_y }, 10 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));
                    render_y += 20 * fs;

                    // Scroll bounds clamping
                    const total_content_ht = render_y + g_net_scroll_y - (net_top + 8 * fs);
                    const max_scroll_net = @max(0, total_content_ht - net_area_h + 20 * fs);
                    g_net_scroll_target = @min(g_net_scroll_target, max_scroll_net);
                    g_net_scroll_target = @max(0, g_net_scroll_target);
                    g_net_scroll_y = @min(g_net_scroll_y, max_scroll_net + 10 * fs);

                    rl.EndScissorMode();

                    // Mouse wheel scroll
                    {
                        const cmx = @as(f32, @floatFromInt(rl.GetMouseX()));
                        const cmy = @as(f32, @floatFromInt(rl.GetMouseY()));
                        if (cmx >= sx and cmx <= sx + sw and cmy >= net_top and cmy <= net_top + net_area_h) {
                            g_net_scroll_target -= rl.GetMouseWheelMove() * 40.0 * fs;
                            g_net_scroll_target = @max(0, g_net_scroll_target);
                        }
                    }

                    // Scrollbar indicator
                    if (total_content_ht > net_area_h) {
                        const scroll_track_x = sx + sw - 6;
                        const scroll_pct = if (max_scroll_net > 0) g_net_scroll_y / max_scroll_net else 0;
                        const thumb_h = @max(20.0, net_area_h * (net_area_h / total_content_ht));
                        const thumb_y = net_top + scroll_pct * (net_area_h - thumb_h);
                        rl.DrawRectangleRounded(.{ .x = scroll_track_x, .y = thumb_y, .width = 4, .height = thumb_h }, 1.0, 4, withAlpha(rc, 60));
                    }
                } else {
                    // ════════════════════════════════════════════
                    // PLACEHOLDER PANEL — Coming Soon
                    // ════════════════════════════════════════════

                    const center_x = sx + sw / 2;
                    const center_y_pos = body_y + body_h * 0.35;

                    // World name (large, centered)
                    var title_buf: [28:0]u8 = undefined;
                    @memcpy(title_buf[0..world.name_len], world.name[0..world.name_len]);
                    title_buf[world.name_len] = 0;
                    const title_w = @as(f32, @floatFromInt(rl.MeasureText(&title_buf, @intFromFloat(24 * fs))));
                    rl.DrawTextEx(font, &title_buf, .{ .x = center_x - title_w / 2, .y = center_y_pos }, 24 * fs, 1, accentText(rc, content_alpha));

                    // Subtitle (description)
                    const doc = world_docs.WORLD_DOCS[self.world_id];
                    var subtitle_buf: [64:0]u8 = undefined;
                    const sub_len = @min(doc.subtitle.len, 63);
                    @memcpy(subtitle_buf[0..sub_len], doc.subtitle[0..sub_len]);
                    subtitle_buf[sub_len] = 0;
                    const sub_w = @as(f32, @floatFromInt(rl.MeasureText(&subtitle_buf, @intFromFloat(13 * fs))));
                    rl.DrawTextEx(font, &subtitle_buf, .{ .x = center_x - sub_w / 2, .y = center_y_pos + 34 * fs }, 13 * fs, 0.5, withAlpha(MUTED_GRAY, content_alpha));

                    // "Coming Soon" badge
                    const badge_y = center_y_pos + 64 * fs;
                    const badge_text = "Coming Soon";
                    const badge_w = @as(f32, @floatFromInt(rl.MeasureText(badge_text, @intFromFloat(12 * fs))));
                    rl.DrawRectangleRounded(
                        .{ .x = center_x - badge_w / 2 - 12 * fs, .y = badge_y - 4 * fs, .width = badge_w + 24 * fs, .height = 24 * fs },
                        0.5,
                        4,
                        withAlpha(BORDER_SUBTLE, content_alpha / 2),
                    );
                    rl.DrawTextEx(font, badge_text, .{ .x = center_x - badge_w / 2, .y = badge_y }, 12 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                    // Domain name
                    const di = @intFromEnum(world.domain);
                    const dn_len = sacred_worlds.DOMAIN_NAME_LENS[di];
                    var domain_buf: [20:0]u8 = undefined;
                    @memcpy(domain_buf[0..dn_len], sacred_worlds.DOMAIN_NAMES[di][0..dn_len]);
                    domain_buf[dn_len] = 0;
                    const dom_w = @as(f32, @floatFromInt(rl.MeasureText(&domain_buf, @intFromFloat(11 * fs))));
                    rl.DrawTextEx(font, &domain_buf, .{ .x = center_x - dom_w / 2, .y = center_y_pos + 100 * fs }, 11 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                    // Formula decoration (bottom)
                    var formula_buf: [52:0]u8 = undefined;
                    @memcpy(formula_buf[0..world.formula_len], world.formula[0..world.formula_len]);
                    formula_buf[world.formula_len] = 0;
                    const formula_w = @as(f32, @floatFromInt(rl.MeasureText(&formula_buf, @intFromFloat(11 * fs))));
                    rl.DrawTextEx(font, &formula_buf, .{ .x = center_x - formula_w / 2, .y = center_y_pos + 130 * fs }, 11 * fs, 0.5, withAlpha(TEXT_HINT, content_alpha));

                    // Block badge
                    var idx_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrintZ(&idx_buf, "Block {d}/27", .{@as(u32, self.world_id) + 1}) catch {};
                    const bidx_w = @as(f32, @floatFromInt(rl.MeasureText(&idx_buf, @intFromFloat(10 * fs))));
                    rl.DrawTextEx(font, &idx_buf, .{ .x = center_x - bidx_w / 2, .y = center_y_pos + 152 * fs }, 10 * fs, 0.5, withAlpha(TEXT_DIM, content_alpha));

                    // Animated realm-color spiral (decorative)
                    const spiral_cx = center_x;
                    const spiral_cy = center_y_pos - 60 * fs;
                    var sp: u32 = 0;
                    while (sp < 20) : (sp += 1) {
                        const n = @as(f32, @floatFromInt(sp));
                        const angle = n * PHI * std.math.pi + time * 0.3;
                        const radius_sp = (5.0 + n * 1.5) * fs;
                        const px = spiral_cx + @cos(angle) * radius_sp;
                        const py = spiral_cy + @sin(angle) * radius_sp;
                        const dot_alpha: u8 = @intFromFloat(@max(20, @as(f32, @floatFromInt(content_alpha)) * (1.0 - n / 20.0)));
                        rl.DrawCircle(@intFromFloat(px), @intFromFloat(py), 2.0 * fs, rl.Color{ .r = realm_r, .g = realm_g, .b = realm_b, .a = dot_alpha });
                    }
                }
            },
        }

        // ═══════════════════════════════════════════════════════════════
        // EMERGENT WAVE SCROLLVIEW v1.0 — Visual Effects on Panel Card
        // phi^2 + 1/phi^2 = 3 = TRINITY
        // ═══════════════════════════════════════════════════════════════
        if (self.wave_scroll_enabled) {
            const wsv = &self.wave_sv;
            const wave_content_y = sy + 34; // Below title bar
            const wave_content_h = sh - 44; // Content area height

            // Velocity-dependent visual intensity: idle=subtle, fast=bright
            const vel_intensity = @min(1.0, @abs(wsv.state.scroll_velocity) / 1000.0);
            const idle_base: f32 = 0.15;
            const visual_intensity = idle_base + (1.0 - idle_base) * vel_intensity;

            // 1. INTERFERENCE GLOW LINES — horizontal wave bands across panel
            if (wsv.interference_rows > 0) {
                const row_scale = wave_content_h / @as(f32, @floatFromInt(wsv.interference_rows));
                for (0..wsv.interference_rows) |row| {
                    const intensity = wsv.interference[row];
                    if (intensity > 0.03) {
                        const iy = wave_content_y + @as(f32, @floatFromInt(row)) * row_scale;
                        if (iy < sy or iy > sy + sh) continue;
                        const glow_a = @min(@as(f32, 80.0), intensity * 100.0 * visual_intensity) * self.opacity;
                        const glow_alpha: u8 = @intFromFloat(@max(0, glow_a));
                        if (glow_alpha > 2) {
                            rl.DrawLineEx(
                                .{ .x = sx + 4, .y = iy },
                                .{ .x = sx + sw - 4, .y = iy },
                                1.0,
                                rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = glow_alpha },
                            );
                        }
                    }
                }
            }

            // 2. WAVE VELOCITY INDICATOR — edge glow when scrolling fast
            const vel = @abs(wsv.state.scroll_velocity);
            if (vel > 50.0) {
                const vel_norm = @min(1.0, vel / 2000.0);
                const edge_alpha: u8 = @intFromFloat(@max(0, vel_norm * 140.0 * self.opacity));
                if (wsv.state.scroll_velocity > 0) {
                    for (0..3) |gi| {
                        const gf = @as(f32, @floatFromInt(gi));
                        const ga: u8 = edge_alpha / (@as(u8, @intCast(gi)) + 1);
                        rl.DrawLineEx(
                            .{ .x = sx + 8, .y = sy + sh - 2 - gf * 2 },
                            .{ .x = sx + sw - 8, .y = sy + sh - 2 - gf * 2 },
                            2.0,
                            rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ga },
                        );
                    }
                } else {
                    for (0..3) |gi| {
                        const gf = @as(f32, @floatFromInt(gi));
                        const ga: u8 = edge_alpha / (@as(u8, @intCast(gi)) + 1);
                        rl.DrawLineEx(
                            .{ .x = sx + 8, .y = sy + 34 + gf * 2 },
                            .{ .x = sx + sw - 8, .y = sy + 34 + gf * 2 },
                            2.0,
                            rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ga },
                        );
                    }
                }
            }

            // 3. BOUNCE GLOW — magenta flash on overscroll
            if (wsv.state.bounce_amplitude > 0.01) {
                const bounce_a: u8 = @intFromFloat(@min(255.0, wsv.state.bounce_amplitude * 400.0 * self.opacity));
                const bounce_pulse = @sin(wsv.state.bounce_phase) * 0.5 + 0.5;
                const bp_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(bounce_a)) * bounce_pulse);
                rl.DrawRectangleRoundedLinesEx(
                    .{ .x = sx + 1, .y = sy + 1, .width = sw - 2, .height = sh - 2 },
                    roundness,
                    32,
                    2.0,
                    rl.Color{ .r = 0xF8, .g = 0x1C, .b = 0xE5, .a = bp_alpha },
                );
            }

            // 4. WAVE SCROLL POSITION INDICATOR
            const max_scroll_w = @max(1.0, wsv.state.total_content_height - wsv.state.viewport_height);
            const scroll_pct = @min(1.0, @max(0.0, wsv.state.scroll_phase / max_scroll_w));
            const indicator_h: f32 = @max(20.0, wave_content_h * (wsv.state.viewport_height / @max(1.0, wsv.state.total_content_height)));
            const indicator_y = wave_content_y + scroll_pct * (wave_content_h - indicator_h);
            const wave_pulse = @sin(wsv.wave_time * 3.0) * 0.3 + 0.7;
            const ind_alpha: u8 = @intFromFloat(@max(0, @min(255.0, wave_pulse * (40.0 + 60.0 * visual_intensity) * self.opacity)));
            rl.DrawRectangleRounded(
                .{ .x = sx + sw - 6, .y = indicator_y, .width = 3, .height = indicator_h },
                0.5,
                8,
                rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ind_alpha },
            );

            // 5. EDGE FADE — gradient masking at top/bottom content edges
            const fade_bg = if (self.panel_type == .sacred_world) @as(rl.Color, @bitCast(theme.sacred_world_bg)) else BG_SURFACE;
            for (0..6) |fi| {
                const fade_f = @as(f32, @floatFromInt(6 - fi));
                const fade_a: u8 = @intFromFloat(@max(0, @min(255.0, self.opacity * fade_f * 40.0)));
                // Top edge fade
                rl.DrawLineEx(
                    .{ .x = sx + 2, .y = sy + 34 + @as(f32, @floatFromInt(fi)) },
                    .{ .x = sx + sw - 2, .y = sy + 34 + @as(f32, @floatFromInt(fi)) },
                    1.0,
                    withAlpha(fade_bg, fade_a),
                );
                // Bottom edge fade
                rl.DrawLineEx(
                    .{ .x = sx + 2, .y = sy + sh - @as(f32, @floatFromInt(fi)) },
                    .{ .x = sx + sw - 2, .y = sy + sh - @as(f32, @floatFromInt(fi)) },
                    1.0,
                    withAlpha(fade_bg, fade_a),
                );
            }
        }

        // Resize handle (bottom-right corner)
        const handle_size: f32 = 12;
        const handle_x = sx + sw - handle_size;
        const handle_y = sy + sh - handle_size;
        for (0..3) |i| {
            const fi = @as(f32, @floatFromInt(i));
            rl.DrawLine(@intFromFloat(handle_x + fi * 4), @intFromFloat(handle_y + handle_size), @intFromFloat(handle_x + handle_size), @intFromFloat(handle_y + fi * 4), rl.Color{ .r = 0x60, .g = 0x60, .b = 0x60, .a = @intFromFloat(self.opacity * 100) });
        }
    }

    pub fn isPointInside(self: *const GlassPanel, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + self.height;
    }

    pub fn isPointInTitleBar(self: *const GlassPanel, px: f32, py: f32) bool {
        return px >= self.x and px <= self.x + self.width and
            py >= self.y and py <= self.y + 36;
    }

    pub fn isPointOnClose(self: *const GlassPanel, px: f32, py: f32) bool {
        // Traffic light close button (left side, red)
        const close_x = self.x + 16;
        const close_y = self.y + 14;
        const dx = px - close_x;
        const dy = py - close_y;
        return dx * dx + dy * dy < 64; // radius 8

    }

    pub fn isPointOnResize(self: *const GlassPanel, px: f32, py: f32) bool {
        // Bottom-right corner resize handle
        const handle_size: f32 = 16;
        return px >= self.x + self.width - handle_size and
            px <= self.x + self.width and
            py >= self.y + self.height - handle_size and
            py <= self.y + self.height;
    }

    // Load directory for finder panel
    pub fn loadDirectory(self: *GlassPanel, path: []const u8) void {
        // Store path
        const path_copy_len = @min(path.len, 511);
        @memcpy(self.finder_path[0..path_copy_len], path[0..path_copy_len]);
        self.finder_path_len = path_copy_len;
        self.finder_entry_count = 0;
        self.finder_animation = 0;

        if (is_emscripten) {
            // WASM: show demo entries (no real filesystem)
            const demo = [_]struct { name: []const u8, is_dir: bool }{
                .{ .name = "src/", .is_dir = true },
                .{ .name = "build.zig", .is_dir = false },
                .{ .name = "assets/", .is_dir = true },
                .{ .name = "README.md", .is_dir = false },
            };
            for (demo, 0..) |d, i| {
                if (i >= 64) break;
                const nl = @min(d.name.len, 127);
                @memcpy(self.finder_entries[i].name[0..nl], d.name[0..nl]);
                self.finder_entries[i].name_len = nl;
                self.finder_entries[i].is_dir = d.is_dir;
                self.finder_entries[i].file_type = if (d.is_dir) .folder else FileType.fromName(d.name);
                const fi = @as(f32, @floatFromInt(i));
                self.finder_entries[i].orbit_angle = fi * 0.618033988 * TAU;
                self.finder_entries[i].orbit_radius = 60 + fi * 8;
                self.finder_entry_count += 1;
            }
            return;
        }

        // Open directory using std.fs
        const dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
            // If can't open, add error entry
            const err_name = "Error: Cannot open directory";
            @memcpy(self.finder_entries[0].name[0..err_name.len], err_name);
            self.finder_entries[0].name_len = err_name.len;
            self.finder_entries[0].is_dir = false;
            self.finder_entries[0].file_type = .unknown;
            self.finder_entry_count = 1;
            return;
        };

        // Add parent directory entry (..)
        if (!std.mem.eql(u8, path, ".") and !std.mem.eql(u8, path, "/")) {
            const parent_name = "..";
            @memcpy(self.finder_entries[0].name[0..2], parent_name);
            self.finder_entries[0].name_len = 2;
            self.finder_entries[0].is_dir = true;
            self.finder_entries[0].file_type = .folder;
            self.finder_entries[0].orbit_angle = 0;
            self.finder_entries[0].orbit_radius = 50;
            self.finder_entry_count = 1;
        }

        // Iterate directory
        var iter = dir.iterate();
        while (iter.next() catch null) |entry| {
            if (self.finder_entry_count >= 64) break;

            const idx = self.finder_entry_count;
            const name_len = @min(entry.name.len, 127);
            @memcpy(self.finder_entries[idx].name[0..name_len], entry.name[0..name_len]);
            self.finder_entries[idx].name_len = name_len;
            self.finder_entries[idx].is_dir = entry.kind == .directory;

            if (entry.kind == .directory) {
                self.finder_entries[idx].file_type = .folder;
            } else {
                self.finder_entries[idx].file_type = FileType.fromName(entry.name);
            }

            // Assign orbit position based on index
            const fi = @as(f32, @floatFromInt(idx));
            self.finder_entries[idx].orbit_angle = fi * 0.618033988 * TAU; // Golden angle
            self.finder_entries[idx].orbit_radius = 60 + fi * 8; // Expanding spiral

            self.finder_entry_count += 1;
        }
    }

    // Get clicked entry in finder
    pub fn getFinderEntryAt(self: *const GlassPanel, px: f32, py: f32, time: f32) ?usize {
        const center_x = self.x + self.width / 2;
        const center_y = self.y + self.height / 2 + 20;

        for (0..self.finder_entry_count) |i| {
            const entry = &self.finder_entries[i];
            const angle = entry.orbit_angle + time * 0.3 + self.finder_animation;
            const radius = entry.orbit_radius * (0.8 + self.finder_animation * 0.2);

            const ex = center_x + @cos(angle) * radius;
            const ey = center_y + @sin(angle) * radius;

            const dx = px - ex;
            const dy = py - ey;
            const dist = @sqrt(dx * dx + dy * dy);

            // Check if click is within entry circle
            const entry_size: f32 = if (entry.is_dir) 14 else 10;
            if (dist < entry_size + 5) {
                return i;
            }
        }
        return null;
    }
};

const PanelSystem = struct {
    panels: [MAX_PANELS]GlassPanel,
    count: usize,
    active_panel: ?usize,

    // Swipe tracking
    swipe_start_x: f32,
    swipe_start_y: f32,
    swiping: bool,

    pub fn init() PanelSystem {
        return .{
            .panels = undefined,
            .count = 0,
            .active_panel = null,
            .swipe_start_x = 0,
            .swipe_start_y = 0,
            .swiping = false,
        };
    }

    pub fn spawn(self: *PanelSystem, x: f32, y: f32, w: f32, h: f32, ptype: PanelType, title: []const u8) void {
        if (self.count >= MAX_PANELS) return;
        self.panels[self.count] = GlassPanel.init(x, y, w, h, ptype, title);
        self.panels[self.count].open();
        self.count += 1;
    }

    // Focus panel by type - if exists, focus it; otherwise spawn new
    pub fn focusByType(self: *PanelSystem, ptype: PanelType, x: f32, y: f32, w: f32, h: f32, title: []const u8) void {
        // First unfocus all panels
        for (0..self.count) |i| {
            if (self.panels[i].is_focused) {
                self.panels[i].unfocus();
            }
        }

        // Find existing panel of this type
        for (0..self.count) |i| {
            if (self.panels[i].panel_type == ptype and self.panels[i].state == .open) {
                self.panels[i].focus();
                self.active_panel = i;
                return;
            }
        }

        // No existing panel - spawn new and focus
        if (self.count < MAX_PANELS) {
            self.panels[self.count] = GlassPanel.init(x, y, w, h, ptype, title);
            self.panels[self.count].open();
            // Focus will be called after opening animation
            self.panels[self.count].is_focused = true;
            self.panels[self.count].focus_ripple = 1.0;
            self.panels[self.count].target_x = 20;
            self.panels[self.count].target_y = 40;
            self.panels[self.count].target_w = @as(f32, @floatFromInt(g_width)) - 40;
            self.panels[self.count].target_h = @as(f32, @floatFromInt(g_height)) - 100;
            self.active_panel = self.count;
            self.count += 1;
        }
    }

    // Unfocus all panels
    pub fn unfocusAll(self: *PanelSystem) void {
        for (0..self.count) |i| {
            if (self.panels[i].is_focused) {
                self.panels[i].unfocus();
            }
        }
    }

    // JARVIS-style focus with spherical morph animation
    // If panel of type exists: bring to front + refocus
    // If not: spawn new with JARVIS sphere → rectangle animation
    pub fn jarvisFocus(self: *PanelSystem, ptype: PanelType, x: f32, y: f32, w: f32, h: f32, title: []const u8) void {
        // First unfocus all panels
        for (0..self.count) |i| {
            if (self.panels[i].is_focused) {
                self.panels[i].unfocus();
            }
        }

        // Find existing panel of this type
        for (0..self.count) |i| {
            if (self.panels[i].panel_type == ptype and self.panels[i].state == .open) {
                // Bring to front by swapping with last panel
                if (i < self.count - 1) {
                    const temp = self.panels[i];
                    // Shift all panels down
                    var j: usize = i;
                    while (j < self.count - 1) : (j += 1) {
                        self.panels[j] = self.panels[j + 1];
                    }
                    self.panels[self.count - 1] = temp;
                }
                // JARVIS focus with spherical morph
                self.panels[self.count - 1].jarvisFocus();
                self.active_panel = self.count - 1;
                return;
            }
        }

        // No existing panel - spawn new with JARVIS animation
        if (self.count < MAX_PANELS) {
            self.panels[self.count] = GlassPanel.init(x, y, w, h, ptype, title);
            self.panels[self.count].open();
            self.panels[self.count].jarvisFocus();
            self.active_panel = self.count;
            self.count += 1;
        }
    }

    pub fn update(self: *PanelSystem, dt: f32, time: f32, mx: f32, my: f32, mouse_pressed: bool, mouse_down: bool, mouse_released: bool, mouse_wheel: f32) void {
        // Handle mouse interactions
        if (mouse_pressed) {
            // Check if clicking on any panel (reverse order for z-order)
            var i: usize = self.count;
            while (i > 0) {
                i -= 1;
                const panel = &self.panels[i];
                if (panel.state != .open) continue;

                // Close button (traffic light red)
                if (panel.isPointOnClose(mx, my)) {
                    panel.close();
                    return;
                }

                // Resize handle (bottom-right)
                if (panel.isPointOnResize(mx, my)) {
                    panel.resizing = true;
                    self.active_panel = i;
                    return;
                }

                // Title bar drag
                if (panel.isPointInTitleBar(mx, my)) {
                    panel.dragging = true;
                    panel.drag_offset_x = mx - panel.x;
                    panel.drag_offset_y = my - panel.y;
                    self.active_panel = i;
                    self.swipe_start_x = mx;
                    self.swipe_start_y = my;
                    return;
                }

                // Click inside panel
                if (panel.isPointInside(mx, my)) {
                    self.active_panel = i;

                    // Handle vision panel clicks - start analyzing
                    if (panel.panel_type == .vision and !panel.vision_analyzing and panel.vision_result_len == 0) {
                        panel.vision_analyzing = true;
                        panel.vision_progress = 0;
                    }

                    // Handle voice panel clicks - toggle recording
                    if (panel.panel_type == .voice) {
                        panel.voice_recording = !panel.voice_recording;
                        if (!panel.voice_recording) {
                            // Finished recording - simulate STT
                            panel.addChatMessage("Voice: [transcribed audio]", false);
                        }
                    }

                    // Handle finder panel clicks
                    if (panel.panel_type == .finder) {
                        // Pass time for calculating positions
                        if (panel.getFinderEntryAt(mx, my, time)) |entry_idx| {
                            const entry = &panel.finder_entries[entry_idx];
                            panel.finder_selected = entry_idx;

                            // Navigate into folder on click
                            if (entry.is_dir and entry.name_len > 0) {
                                // Build new path
                                var new_path: [1024]u8 = undefined;
                                var new_len: usize = 0;

                                // Check for parent directory (..)
                                if (entry.name_len == 2 and entry.name[0] == '.' and entry.name[1] == '.') {
                                    // Go up one level
                                    if (panel.finder_path_len > 0) {
                                        // Find last separator
                                        var sep_idx: usize = panel.finder_path_len;
                                        while (sep_idx > 0) : (sep_idx -= 1) {
                                            if (panel.finder_path[sep_idx - 1] == '/') {
                                                break;
                                            }
                                        }
                                        if (sep_idx > 1) {
                                            @memcpy(new_path[0 .. sep_idx - 1], panel.finder_path[0 .. sep_idx - 1]);
                                            new_len = sep_idx - 1;
                                        } else {
                                            new_path[0] = '.';
                                            new_len = 1;
                                        }
                                    }
                                } else {
                                    // Enter subdirectory
                                    if (panel.finder_path_len > 0 and panel.finder_path[0] != '.') {
                                        @memcpy(new_path[0..panel.finder_path_len], panel.finder_path[0..panel.finder_path_len]);
                                        new_path[panel.finder_path_len] = '/';
                                        new_len = panel.finder_path_len + 1;
                                    }
                                    @memcpy(new_path[new_len .. new_len + entry.name_len], entry.name[0..entry.name_len]);
                                    new_len += entry.name_len;
                                }

                                // Load new directory with ripple effect
                                panel.finder_ripple = 1.0; // Trigger cosmic ripple
                                panel.loadDirectory(new_path[0..new_len]);
                            }
                        }
                    }
                    return;
                }
            }

            // Start swipe on empty area
            self.swiping = true;
            self.swipe_start_x = mx;
            self.swipe_start_y = my;
        }

        if (mouse_down) {
            if (self.active_panel) |idx| {
                const panel = &self.panels[idx];

                // Resizing
                if (panel.resizing) {
                    const new_w = @max(200, mx - panel.x);
                    const new_h = @max(150, my - panel.y);
                    panel.width = new_w;
                    panel.height = new_h;
                }
                // Dragging
                else if (panel.dragging) {
                    const new_x = mx - panel.drag_offset_x;
                    const new_y = my - panel.drag_offset_y;
                    panel.vel_x = (new_x - panel.x) / dt;
                    panel.vel_y = (new_y - panel.y) / dt;
                    panel.x = new_x;
                    panel.y = new_y;
                }
            }
        }

        if (mouse_released) {
            // End dragging/resizing with snap-to-grid
            if (self.active_panel) |idx| {
                const panel = &self.panels[idx];
                panel.dragging = false;
                panel.resizing = false;

                // Snap to grid (32px)
                const grid_size: f32 = 32;
                panel.x = @round(panel.x / grid_size) * grid_size;
                panel.y = @round(panel.y / grid_size) * grid_size;
                panel.width = @round(panel.width / grid_size) * grid_size;
                panel.height = @round(panel.height / grid_size) * grid_size;

                // Ensure minimum size
                panel.width = @max(200, panel.width);
                panel.height = @max(150, panel.height);
            }

            // Check swipe gesture
            if (self.swiping) {
                const dx = mx - self.swipe_start_x;
                const dy = my - self.swipe_start_y;
                const swipe_threshold: f32 = 100;

                if (@abs(dy) > swipe_threshold and dy < 0) {
                    // Swipe UP - minimize all panels
                    for (&self.panels) |*p| {
                        if (p.state == .open) p.minimize();
                    }
                } else if (@abs(dx) > swipe_threshold) {
                    // Swipe LEFT/RIGHT - add velocity to open panels
                    const vel_boost: f32 = dx * 5.0;
                    for (&self.panels) |*p| {
                        if (p.state == .open) p.vel_x += vel_boost;
                    }
                }
            }

            self.swiping = false;
        }

        // Handle mouse wheel scroll for panel under cursor
        if (mouse_wheel != 0) {
            for (0..self.count) |i| {
                const panel = &self.panels[i];
                if (panel.state == .open and panel.isPointInside(mx, my)) {
                    if (panel.wave_scroll_enabled) {
                        // Emergent Wave ScrollView: apply impulse (phi-damped physics)
                        panel.wave_sv.applyImpulse(-mouse_wheel);
                    } else {
                        // Legacy lerp scroll
                        panel.scroll_target -= mouse_wheel * 30.0;
                        // Dynamic max scroll for sacred_world panels
                        const max_scroll: f32 = if (panel.panel_type == .sacred_world) blk_scroll: {
                            if (panel.world_id == 0) {
                                break :blk_scroll 0.0;
                            } else if (panel.world_id == 18) {
                                var total: u32 = 0;
                                var di: usize = 0;
                                while (di < 27) : (di += 1) {
                                    total += world_docs.countVisibleLines(world_docs.WORLD_DOCS[di].raw);
                                    total += 4;
                                }
                                break :blk_scroll @as(f32, @floatFromInt(total)) * 18.0 * g_font_scale;
                            } else {
                                break :blk_scroll 0.0;
                            }
                        } else 500.0;
                        panel.scroll_target = @max(0, @min(panel.scroll_target, max_scroll));
                    }
                    break;
                }
            }
        }

        // Scroll update: wave or legacy
        for (0..self.count) |i| {
            const panel = &self.panels[i];
            if (panel.state == .open) {
                if (panel.wave_scroll_enabled) {
                    // Sync viewport bounds after panel move/resize
                    panel.wave_sv.setViewport(panel.x, panel.y + 32.0, panel.width, panel.height - 32.0);
                    // Emergent Wave ScrollView: phi-damped SIMD physics
                    panel.wave_sv.updatePhysics(dt);
                    // Dirty-flag: skip expensive SIMD when scroll is idle
                    if (panel.wave_sv.needs_eval) {
                        panel.wave_sv.updateVisibleRange();
                        panel.wave_sv.evaluatePacketsSIMD();
                        panel.wave_sv.computeInterference();
                    }
                    // Sync scroll_y for render compatibility (with rubber-band)
                    panel.scroll_y = panel.wave_sv.getScrollYWithRubber();
                } else {
                    // Legacy smooth scroll interpolation (lerp toward target)
                    const diff = panel.scroll_target - panel.scroll_y;
                    if (@abs(diff) > 0.5) {
                        panel.scroll_y += diff * @min(1.0, dt * 12.0);
                    } else {
                        panel.scroll_y = panel.scroll_target;
                    }
                }
            }
        }

        // Adaptive resize: update focused panel targets to current window size
        const cur_w = @as(f32, @floatFromInt(g_width));
        const cur_h = @as(f32, @floatFromInt(g_height));
        const card_margin: f32 = 40; // Card padding from edges
        const card_top: f32 = 50; // Top margin (space for status bar)
        const card_bottom: f32 = 50; // Bottom margin
        for (0..self.count) |i| {
            const p = &self.panels[i];
            if ((p.state == .open or p.state == .opening) and p.is_focused) {
                p.target_x = card_margin;
                p.target_y = card_top;
                p.target_w = cur_w - card_margin * 2;
                p.target_h = cur_h - card_top - card_bottom;
                // Snap sacred_world panels immediately (no animation lag on resize)
                if (p.panel_type == .sacred_world) {
                    p.x = p.target_x;
                    p.y = p.target_y;
                    p.width = p.target_w;
                    p.height = p.target_h;
                }
            }
        }

        // Update all panels
        for (0..self.count) |i| {
            self.panels[i].update(dt);
        }
    }

    pub fn draw(self: *const PanelSystem, time: f32, font: rl.Font) void {
        for (0..self.count) |i| {
            self.panels[i].draw(time, font);
        }
    }
};

// =============================================================================
// TRINITY MODES (Full functionality in canvas)
// =============================================================================

const TrinityMode = enum {
    idle, // Wave exploration
    chat, // Chat emerges as wave clusters
    code, // Code gen as structural spirals
    vision, // Image → wave perturbation
    voice, // Voice → frequency modulation
    tools, // Tool execution as orbiting clusters
    autonomous, // Self-directed emergence
};

// =============================================================================
// WAVE CLUSTER (Chat text as interference patterns)
// =============================================================================

const MAX_CLUSTERS = 32;
const MAX_CLUSTER_CHARS = 256;

const WaveCluster = struct {
    chars: [MAX_CLUSTER_CHARS]u8,
    len: usize,
    x: f32,
    y: f32,
    radius: f32,
    phase: f32,
    life: f32,
    hue: f32,
    is_user: bool, // User message vs AI response

    pub fn spawn(x: f32, y: f32, text: []const u8, is_user: bool) WaveCluster {
        var cluster = WaveCluster{
            .chars = undefined,
            .len = @min(text.len, MAX_CLUSTER_CHARS),
            .x = x,
            .y = y,
            .radius = 50.0,
            .phase = 0,
            .life = 1.0,
            .hue = if (is_user) 180.0 else 120.0, // Cyan for user, green for AI
            .is_user = is_user,
        };
        @memcpy(cluster.chars[0..cluster.len], text[0..cluster.len]);
        return cluster;
    }

    pub fn update(self: *WaveCluster, dt: f32) void {
        self.phase += dt * 2.0;
        self.radius += dt * 10.0; // Expand outward
        self.life -= dt * 0.1; // Slow fade
    }

    pub fn isAlive(self: *const WaveCluster) bool {
        return self.life > 0;
    }

    pub fn draw(self: *const WaveCluster, time: f32) void {
        if (!self.isAlive()) return;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));
        const rgb = hsvToRgb(self.hue, 0.8, 1.0);

        // Draw as concentric rings (wave interference)
        const num_rings: usize = @intFromFloat(@max(1, self.radius / 15.0));
        for (0..num_rings) |i| {
            const ring_r = @as(f32, @floatFromInt(i)) * 15.0 + @sin(time * 3.0 + self.phase) * 5.0;
            const ring_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(alpha)) * (1.0 - @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_rings))));
            rl.DrawCircleLines(
                @intFromFloat(self.x),
                @intFromFloat(self.y),
                ring_r,
                rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = ring_alpha },
            );
        }

        // Draw character glyphs around the cluster
        const chars_to_show = @min(self.len, 32);
        for (0..chars_to_show) |i| {
            const angle = @as(f32, @floatFromInt(i)) * TAU / @as(f32, @floatFromInt(chars_to_show)) + self.phase;
            const char_r = self.radius * 0.7;
            const cx = self.x + @cos(angle) * char_r;
            const cy = self.y + @sin(angle) * char_r;

            // Character as small circle (ASCII-based size)
            const char_val = self.chars[i];
            const char_size = 2.0 + @as(f32, @floatFromInt(char_val % 10)) * 0.3;
            rl.DrawCircle(
                @intFromFloat(cx),
                @intFromFloat(cy),
                char_size,
                rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha },
            );
        }
    }
};

const ClusterSystem = struct {
    clusters: [MAX_CLUSTERS]WaveCluster,
    count: usize,

    pub fn init() ClusterSystem {
        var sys = ClusterSystem{
            .clusters = undefined,
            .count = 0,
        };
        for (&sys.clusters) |*c| {
            c.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *ClusterSystem, x: f32, y: f32, text: []const u8, is_user: bool) void {
        // Find dead slot
        for (&self.clusters) |*c| {
            if (!c.isAlive()) {
                c.* = WaveCluster.spawn(x, y, text, is_user);
                return;
            }
        }
        // Overwrite oldest if full
        if (self.count < MAX_CLUSTERS) {
            self.clusters[self.count] = WaveCluster.spawn(x, y, text, is_user);
            self.count += 1;
        }
    }

    pub fn update(self: *ClusterSystem, dt: f32) void {
        for (&self.clusters) |*c| {
            if (c.isAlive()) {
                c.update(dt);
            }
        }
    }

    pub fn draw(self: *const ClusterSystem, time: f32) void {
        for (&self.clusters) |*c| {
            c.draw(time);
        }
    }
};

// =============================================================================
// CODE SPIRAL (Code gen as structural patterns)
// =============================================================================

const MAX_SPIRALS = 16;

const CodeSpiral = struct {
    x: f32,
    y: f32,
    turns: f32, // Number of spiral turns
    scale: f32,
    rotation: f32,
    life: f32,
    syntax_hue: f32, // Color based on syntax type

    const SyntaxType = enum {
        keyword, // Blue
        function, // Green
        variable, // Yellow
        literal, // Magenta
        operator, // Cyan
    };

    pub fn spawn(x: f32, y: f32, syntax: SyntaxType) CodeSpiral {
        const hue: f32 = switch (syntax) {
            .keyword => 240.0,
            .function => 120.0,
            .variable => 60.0,
            .literal => 300.0,
            .operator => 180.0,
        };
        return .{
            .x = x,
            .y = y,
            .turns = 3.0,
            .scale = 20.0,
            .rotation = 0,
            .life = 1.0,
            .syntax_hue = hue,
        };
    }

    pub fn update(self: *CodeSpiral, dt: f32) void {
        self.rotation += dt * PHI;
        self.scale += dt * 5.0;
        self.turns += dt * 0.5;
        self.life -= dt * 0.15;
    }

    pub fn isAlive(self: *const CodeSpiral) bool {
        return self.life > 0;
    }

    pub fn draw(self: *const CodeSpiral) void {
        if (!self.isAlive()) return;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));
        const rgb = hsvToRgb(self.syntax_hue, 0.9, 1.0);

        // Draw golden spiral
        const steps: usize = @intFromFloat(self.turns * 32);
        var prev_x: c_int = @intFromFloat(self.x);
        var prev_y: c_int = @intFromFloat(self.y);

        for (0..steps) |i| {
            const t = @as(f32, @floatFromInt(i)) * 0.1;
            const r = self.scale * @exp(t * PHI_INV * 0.1);
            const angle = t + self.rotation;

            const px: c_int = @intFromFloat(self.x + @cos(angle) * r);
            const py: c_int = @intFromFloat(self.y + @sin(angle) * r);

            rl.DrawLine(prev_x, prev_y, px, py, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha });

            prev_x = px;
            prev_y = py;
        }
    }
};

const SpiralSystem = struct {
    spirals: [MAX_SPIRALS]CodeSpiral,
    count: usize,

    pub fn init() SpiralSystem {
        var sys = SpiralSystem{
            .spirals = undefined,
            .count = 0,
        };
        for (&sys.spirals) |*s| {
            s.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *SpiralSystem, x: f32, y: f32, syntax: CodeSpiral.SyntaxType) void {
        for (&self.spirals) |*s| {
            if (!s.isAlive()) {
                s.* = CodeSpiral.spawn(x, y, syntax);
                return;
            }
        }
    }

    pub fn update(self: *SpiralSystem, dt: f32) void {
        for (&self.spirals) |*s| {
            if (s.isAlive()) {
                s.update(dt);
            }
        }
    }

    pub fn draw(self: *const SpiralSystem) void {
        for (&self.spirals) |*s| {
            s.draw();
        }
    }
};

// =============================================================================
// TOOL CLUSTER (Orbiting execution indicators)
// =============================================================================

const MAX_TOOLS = 8;

const ToolOrbit = struct {
    name: [32]u8,
    name_len: usize,
    cx: f32,
    cy: f32,
    radius: f32,
    angle: f32,
    speed: f32,
    status: ToolStatus,
    life: f32,

    const ToolStatus = enum {
        pending, // Yellow
        running, // Cyan pulse
        success, // Green nova
        failure, // Red sink
    };

    pub fn spawn(cx: f32, cy: f32, name: []const u8) ToolOrbit {
        var tool = ToolOrbit{
            .name = undefined,
            .name_len = @min(name.len, 32),
            .cx = cx,
            .cy = cy,
            .radius = 100.0 + @as(f32, @floatFromInt(name.len % 5)) * 20.0,
            .angle = @as(f32, @floatFromInt(name.len)) * 0.5,
            .speed = 1.0,
            .status = .pending,
            .life = 1.0,
        };
        @memcpy(tool.name[0..tool.name_len], name[0..tool.name_len]);
        return tool;
    }

    pub fn update(self: *ToolOrbit, dt: f32) void {
        self.angle += self.speed * dt;

        switch (self.status) {
            .running => self.speed = 3.0,
            .success => {
                self.radius += dt * 50.0;
                self.life -= dt * 0.5;
            },
            .failure => {
                self.radius -= dt * 30.0;
                self.life -= dt * 0.5;
            },
            else => {},
        }
    }

    pub fn isAlive(self: *const ToolOrbit) bool {
        return self.life > 0 and self.radius > 0;
    }

    pub fn draw(self: *const ToolOrbit, time: f32) void {
        if (!self.isAlive()) return;

        const x = self.cx + @cos(self.angle) * self.radius;
        const y = self.cy + @sin(self.angle) * self.radius;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));

        const color: rl.Color = switch (self.status) {
            .pending => rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha },
            .running => blk: {
                const pulse: u8 = @intFromFloat(128.0 + @sin(time * 10.0) * 127.0);
                break :blk rl.Color{ .r = 0x00, .g = pulse, .b = 0xFF, .a = alpha };
            },
            .success => rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = alpha },
            .failure => rl.Color{ .r = 0xFF, .g = 0x00, .b = 0x44, .a = alpha },
        };

        // Draw tool as pulsating circle
        const size = 8.0 + @sin(time * 5.0 + self.angle) * 3.0;
        rl.DrawCircle(@intFromFloat(x), @intFromFloat(y), size, color);

        // Draw orbit path (faint)
        rl.DrawCircleLines(@intFromFloat(self.cx), @intFromFloat(self.cy), self.radius, rl.Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha / 4 });
    }
};

const ToolSystem = struct {
    tools: [MAX_TOOLS]ToolOrbit,
    count: usize,

    pub fn init() ToolSystem {
        var sys = ToolSystem{
            .tools = undefined,
            .count = 0,
        };
        for (&sys.tools) |*t| {
            t.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *ToolSystem, cx: f32, cy: f32, name: []const u8) void {
        for (&self.tools) |*t| {
            if (!t.isAlive()) {
                t.* = ToolOrbit.spawn(cx, cy, name);
                return;
            }
        }
    }

    pub fn setStatus(self: *ToolSystem, name: []const u8, status: ToolOrbit.ToolStatus) void {
        for (&self.tools) |*t| {
            if (t.isAlive() and std.mem.eql(u8, t.name[0..t.name_len], name)) {
                t.status = status;
                return;
            }
        }
    }

    pub fn update(self: *ToolSystem, dt: f32) void {
        for (&self.tools) |*t| {
            if (t.isAlive()) {
                t.update(dt);
            }
        }
    }

    pub fn draw(self: *const ToolSystem, time: f32) void {
        for (&self.tools) |*t| {
            t.draw(time);
        }
    }
};

// =============================================================================
// COSMIC FEEDBACK (Nova/Sink effects)
// =============================================================================

const MAX_EFFECTS = 16;

const CosmicEffect = struct {
    x: f32,
    y: f32,
    radius: f32,
    life: f32,
    is_nova: bool, // true = success nova, false = failure sink

    pub fn spawnNova(x: f32, y: f32) CosmicEffect {
        return .{
            .x = x,
            .y = y,
            .radius = 10.0,
            .life = 1.0,
            .is_nova = true,
        };
    }

    pub fn spawnSink(x: f32, y: f32) CosmicEffect {
        return .{
            .x = x,
            .y = y,
            .radius = 100.0,
            .life = 1.0,
            .is_nova = false,
        };
    }

    pub fn update(self: *CosmicEffect, dt: f32) void {
        if (self.is_nova) {
            self.radius += dt * 200.0; // Expand
        } else {
            self.radius -= dt * 80.0; // Contract
        }
        self.life -= dt * 1.5;
    }

    pub fn isAlive(self: *const CosmicEffect) bool {
        return self.life > 0 and self.radius > 0;
    }

    pub fn draw(self: *const CosmicEffect) void {
        if (!self.isAlive()) return;

        const alpha: u8 = @intFromFloat(@max(0, @min(255, self.life * 255)));

        if (self.is_nova) {
            // Success: bright expanding rings
            const num_rings: usize = 5;
            for (0..num_rings) |i| {
                const ring_r = self.radius * (1.0 - @as(f32, @floatFromInt(i)) * 0.15);
                const ring_alpha: u8 = @intFromFloat(@as(f32, @floatFromInt(alpha)) * (1.0 - @as(f32, @floatFromInt(i)) * 0.2));
                rl.DrawCircleLines(
                    @intFromFloat(self.x),
                    @intFromFloat(self.y),
                    ring_r,
                    rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = ring_alpha },
                );
            }
            // Center flash
            rl.DrawCircle(@intFromFloat(self.x), @intFromFloat(self.y), 10.0, rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = alpha });
        } else {
            // Failure: dark collapsing vortex
            const num_rings: usize = 5;
            for (0..num_rings) |i| {
                const ring_r = self.radius * (0.2 + @as(f32, @floatFromInt(i)) * 0.2);
                rl.DrawCircleLines(
                    @intFromFloat(self.x),
                    @intFromFloat(self.y),
                    ring_r,
                    rl.Color{ .r = 0xFF, .g = 0x00, .b = 0x44, .a = alpha },
                );
            }
            // Dark center
            rl.DrawCircle(@intFromFloat(self.x), @intFromFloat(self.y), self.radius * 0.3, rl.Color{ .r = 0x20, .g = 0x00, .b = 0x10, .a = alpha });
        }
    }
};

const EffectSystem = struct {
    effects: [MAX_EFFECTS]CosmicEffect,

    pub fn init() EffectSystem {
        var sys = EffectSystem{
            .effects = undefined,
        };
        for (&sys.effects) |*e| {
            e.life = 0;
        }
        return sys;
    }

    pub fn nova(self: *EffectSystem, x: f32, y: f32) void {
        for (&self.effects) |*e| {
            if (!e.isAlive()) {
                e.* = CosmicEffect.spawnNova(x, y);
                return;
            }
        }
    }

    pub fn sink(self: *EffectSystem, x: f32, y: f32) void {
        for (&self.effects) |*e| {
            if (!e.isAlive()) {
                e.* = CosmicEffect.spawnSink(x, y);
                return;
            }
        }
    }

    pub fn update(self: *EffectSystem, dt: f32) void {
        for (&self.effects) |*e| {
            if (e.isAlive()) {
                e.update(dt);
            }
        }
    }

    pub fn draw(self: *const EffectSystem) void {
        for (&self.effects) |*e| {
            e.draw();
        }
    }
};

// =============================================================================
// AUTONOMOUS GOAL (Self-directed wave growth)
// =============================================================================

const WaveSeed = struct {
    x: usize,
    y: usize,
    active: bool,
};

const AutonomousGoal = struct {
    text: [256]u8,
    len: usize,
    x: f32,
    y: f32,
    progress: f32, // 0.0 to 1.0
    wave_seeds: [8]WaveSeed,
    active: bool,

    pub fn init() AutonomousGoal {
        return .{
            .text = undefined,
            .len = 0,
            .x = 0,
            .y = 0,
            .progress = 0,
            .wave_seeds = [_]WaveSeed{.{ .x = 0, .y = 0, .active = false }} ** 8,
            .active = false,
        };
    }

    pub fn setGoal(self: *AutonomousGoal, goal: []const u8, x: f32, y: f32) void {
        self.len = @min(goal.len, 256);
        @memcpy(self.text[0..self.len], goal[0..self.len]);
        self.x = x;
        self.y = y;
        self.progress = 0;
        self.active = true;

        // Generate wave seeds based on goal text
        for (0..8) |i| {
            if (i < goal.len) {
                const c = goal[i % goal.len];
                self.wave_seeds[i] = .{
                    .x = @intCast((@as(usize, c) * 3 + i * 17) % 378),
                    .y = @intCast((@as(usize, c) * 7 + i * 23) % 245),
                    .active = true,
                };
            }
        }
    }

    pub fn update(self: *AutonomousGoal, grid: *photon.PhotonGrid, dt: f32) void {
        if (!self.active) return;

        // Inject waves at seed points
        for (&self.wave_seeds) |*seed| {
            if (seed.active and seed.x < grid.width and seed.y < grid.height) {
                grid.getMut(seed.x, seed.y).amplitude += @sin(self.progress * TAU) * 0.5;
            }
        }

        // Progress grows based on grid energy
        self.progress += dt * 0.05 * (1.0 + grid.total_energy * 0.0001);

        if (self.progress >= 1.0) {
            self.active = false;
        }
    }

    pub fn draw(self: *const AutonomousGoal, time: f32) void {
        if (!self.active) return;

        const alpha: u8 = @intFromFloat(150.0 + @sin(time * 2.0) * 50.0);

        // Draw progress arc
        const arc_radius: f32 = 150.0;
        const arc_steps: usize = @intFromFloat(self.progress * 64.0);

        for (0..arc_steps) |i| {
            const angle = @as(f32, @floatFromInt(i)) * TAU / 64.0 - TAU / 4.0;
            const px = self.x + @cos(angle) * arc_radius;
            const py = self.y + @sin(angle) * arc_radius;

            rl.DrawCircle(@intFromFloat(px), @intFromFloat(py), 3.0, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha });
        }

        // Draw seed points
        for (&self.wave_seeds) |seed| {
            if (seed.active) {
                const sx: c_int = @intCast(seed.x * @as(usize, @intCast(g_pixel_size)));
                const sy: c_int = @intCast(seed.y * @as(usize, @intCast(g_pixel_size)));
                rl.DrawCircle(sx, sy, 5.0 + @sin(time * 5.0) * 2.0, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 100 });
            }
        }
    }
};

// =============================================================================
// INPUT BUFFER (For text/goal input)
// =============================================================================

const InputBuffer = struct {
    buffer: [512]u8,
    len: usize,
    active: bool,
    mode: InputMode,

    const InputMode = enum {
        chat,
        goal,
        code,
    };

    pub fn init() InputBuffer {
        return .{
            .buffer = undefined,
            .len = 0,
            .active = true, // Start active - ready to type!
            .mode = .chat,
        };
    }

    pub fn start(self: *InputBuffer, mode: InputMode) void {
        self.len = 0;
        self.active = true;
        self.mode = mode;
    }

    pub fn addChar(self: *InputBuffer, c: u8) void {
        if (self.len < 511) {
            self.buffer[self.len] = c;
            self.len += 1;
        }
    }

    pub fn backspace(self: *InputBuffer) void {
        if (self.len > 0) {
            self.len -= 1;
        }
    }

    pub fn getText(self: *const InputBuffer) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn submit(self: *InputBuffer) []const u8 {
        const text = self.getText();
        self.active = false;
        return text;
    }

    pub fn draw(self: *const InputBuffer, time: f32) void {
        // Always draw input box (even when not active, show hint)
        const box_y = g_height - 60;
        rl.DrawRectangle(0, box_y, g_width, 60, withAlpha(BG_INPUT, 220));

        if (!self.active) {
            // Show hint when not active
            rl.DrawText("Press C=Chat, G=Goal, X=Code, ESC=Exit", 20, box_y + 20, 18, MUTED_GRAY);
            return;
        }

        const label = switch (self.mode) {
            .chat => "CHAT> ",
            .goal => "GOAL> ",
            .code => "CODE> ",
        };

        // Label with bright color
        rl.DrawText(label.ptr, 20, box_y + 20, 20, NEON_GREEN);

        // Text
        var display_buf: [520]u8 = undefined;
        const display_len = @min(self.len, 500);
        @memcpy(display_buf[0..display_len], self.buffer[0..display_len]);

        // Cursor blink
        if (@mod(@as(u32, @intFromFloat(time * 3.0)), 2) == 0) {
            display_buf[display_len] = '_';
            display_buf[display_len + 1] = 0;
        } else {
            display_buf[display_len] = 0;
        }

        rl.DrawText(@ptrCast(&display_buf), 90, box_y + 20, 20, NOVA_WHITE);

        // Show Enter hint
        rl.DrawText("Enter=Send | ESC=Cancel", g_width - 220, box_y + 20, 14, TEXT_HINT);
    }
};

// =============================================================================
// FRAME STATE — promoted from main() locals for emscripten_set_main_loop compat
// Same names as the old locals so the 1720-line loop body needs zero changes
// =============================================================================
var frame_grid: photon.PhotonGrid = undefined;
var frame_clusters: ClusterSystem = undefined;
var frame_spirals: SpiralSystem = undefined;
var frame_tools: ToolSystem = undefined;
var frame_effects: EffectSystem = undefined;
var frame_goal: AutonomousGoal = undefined;
var frame_panels: PanelSystem = undefined;
var frame_time: f32 = 0;
var frame_mode: TrinityMode = .idle;
var frame_cursor_hue: f32 = 120;
var frame_logo_anim: LogoAnimation = undefined;
var frame_loading_complete: bool = false;
var frame_formula_particles: [MAX_FORMULA_PARTICLES]FormulaParticle = undefined;
var frame_font: rl.Font = undefined;
var frame_font_small: rl.Font = undefined;
var frame_allocator: std.mem.Allocator = undefined;
var g_should_quit: bool = false;

// =============================================================================
// MAIN TRINITY CANVAS
// =============================================================================

pub fn main() !void {
    // GPA uses mmap internals not available in WASM; use page_allocator for emscripten
    var gpa: if (is_emscripten) u8 else std.heap.GeneralPurposeAllocator(.{}) =
        if (is_emscripten) 0 else std.heap.GeneralPurposeAllocator(.{}){};
    defer if (!is_emscripten) {
        _ = gpa.deinit();
    };
    const allocator = if (is_emscripten) std.heap.page_allocator else gpa.allocator();
    frame_allocator = allocator;

    // Raylib init - RESIZABLE WINDOW (responsive!)
    if (is_emscripten) {
        rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
    } else {
        // High DPI + MSAA + TRANSPARENT background (see desktop through)
        rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT | rl.FLAG_WINDOW_HIGHDPI | rl.FLAG_WINDOW_TRANSPARENT | rl.FLAG_WINDOW_MAXIMIZED);
    }
    rl.InitWindow(1280, 800, "TRINITY v1.7 | Shift+1-7 = Panels | phi^2 + 1/phi^2 = 3");
    defer rl.CloseWindow();

    // Disable ESC auto-close — ESC hides panels, Cmd+Q quits
    rl.SetExitKey(0);

    // Set minimum window size for responsive design
    if (!is_emscripten) rl.SetWindowMinSize(800, 600);

    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // ── HiDPI / Retina detection ──
    // GetWindowScaleDPI returns (sx, sy) — 2.0 on Mac Retina, 1.0 on standard
    const dpi_scale_v = rl.GetWindowScaleDPI();
    g_dpi_scale = @max(dpi_scale_v.x, dpi_scale_v.y);
    if (g_dpi_scale < 1.0) g_dpi_scale = 1.0;

    // Load fonts at physical pixel size for crisp Retina text
    // Base sizes: 48pt (headings), 32pt (body) — on 2x Retina → 96pt, 64pt atlas
    const font_size_large: c_int = @intFromFloat(48.0 * g_dpi_scale);
    const font_size_small: c_int = @intFromFloat(32.0 * g_dpi_scale);

    // UI fonts: Outfit (original, Latin-only, perfect metrics)
    frame_font = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", font_size_large, null, 0);
    defer rl.UnloadFont(frame_font);
    frame_font_small = rl.LoadFontEx("assets/fonts/Outfit-Regular.ttf", font_size_small, null, 0);
    defer rl.UnloadFont(frame_font_small);
    // Enable bilinear filtering for smooth text at all sizes
    rl.SetTextureFilter(frame_font.texture, rl.TEXTURE_FILTER_BILINEAR);
    rl.SetTextureFilter(frame_font_small.texture, rl.TEXTURE_FILTER_BILINEAR);

    // v8.6: Emoji font for tool pills - NotoEmoji has full emoji support
    var emoji_codepoints: [50]c_int = undefined;
    const tool_emoji = [_]u32{
        0x1F50D, // 🔍 Glob/Find
        0x1F4F6, // 📖 Read/Book
        0x1F50E, // 🔎 Grep/Search
        0x26A1, // ⚡ Bash/Power
        0x270F, // ✏️ Write/Pencil
        0x1F504, // 🔄 Edit/Refresh
        0x1F4CB, // 📋 Todo/Clipboard
        0x1F4E1, // 📡 Antenna
        0x1F4BB, // 💻 Computer
        0x1F9E0, // 🧠 Brain
        0x1F680, // 🚀 Rocket
        0x2705, // ✅ Check
        0x274C, // ❌ Cross
        0x26A0, // ⚠️ Warning
        0x1F4A1, // 💡 Bulb
        0x1F525, // 🔥 Fire
        0x2728, // ✨ Sparkles
        0x1F308, // 🌈 Rainbow
        0x1F916, // 🤖 Robot
        0x1F3A8, // 🎨 Palette
        0x1F4CA, // 📊 Chart
        0x1F3AF, // 🎯 Target
        0x1F4B0, // 💰 Bag
        0x2611, // ☑️ Ballot
        0x1F7E2, // 🟢 Green circle
        0x1F535, // 🔵 Blue circle
        0x1F7E3, // 🟣 Purple circle
    };
    for (0..tool_emoji.len) |i| emoji_codepoints[i] = @intCast(tool_emoji[i]);

    // Load NotoEmoji font (installed via brew, has full emoji support)
    g_font_emoji = rl.LoadFontEx("assets/fonts/NotoEmoji.ttf", 32, &emoji_codepoints, emoji_codepoints.len);
    rl.SetTextureFilter(g_font_emoji.texture, rl.TEXTURE_FILTER_BILINEAR);
    // Note: g_font_emoji is NOT unloaded here (used throughout app lifetime)

    // Chat font: SFPro (Latin + Cyrillic + Greek) at LARGE atlas size for crisp rendering
    var chat_codepoints: [95 + 256 + 144]c_int = undefined;
    for (0..95) |i| chat_codepoints[i] = @intCast(32 + i); // ASCII 32-126
    for (0..256) |i| chat_codepoints[95 + i] = @intCast(0x400 + i); // Cyrillic U+0400-U+04FF
    for (0..144) |i| chat_codepoints[95 + 256 + i] = @intCast(0x370 + i); // Greek U+0370-U+03FF (Λ Κ for agent avatars)

    g_font_chat = rl.LoadFontEx("assets/fonts/SFPro.ttf", font_size_large, &chat_codepoints, chat_codepoints.len);
    defer rl.UnloadFont(g_font_chat);
    rl.SetTextureFilter(g_font_chat.texture, rl.TEXTURE_FILTER_BILINEAR);

    // Grid (fixed size - will scale to window)
    const grid_w: usize = 320;
    const grid_h: usize = 200;

    frame_grid = try photon.PhotonGrid.init(allocator, grid_w, grid_h);
    defer frame_grid.deinit();

    // Systems
    frame_clusters = ClusterSystem.init();
    frame_spirals = SpiralSystem.init();
    frame_tools = ToolSystem.init();
    frame_effects = EffectSystem.init();
    frame_goal = AutonomousGoal.init();
    frame_panels = PanelSystem.init();

    // State (file-scope globals)
    frame_time = 0;
    frame_mode = .idle;
    frame_cursor_hue = 120;

    if (!is_emscripten) {
        rl.InitAudioDevice();
    }
    defer if (!is_emscripten) {
        rl.CloseAudioDevice();
    };

    rl.SetTargetFPS(60);
    // Show cursor for window resizing
    rl.ShowCursor();
    // Focus window for keyboard input
    if (!is_emscripten) rl.SetWindowFocused();

    // Initialize logo animation
    frame_logo_anim = LogoAnimation.init(@floatFromInt(g_width), @floatFromInt(g_height));
    frame_loading_complete = false;

    // Sacred formula particles — Fibonacci spiral orbit
    const formula_texts = [42][]const u8{
        // 27 world formulas
        "phi = 1.618",              "pi*phi*e = 13.82",      "L(10) = 123",
        "1/alpha = 137.036",        "phi^2 = 2.618",         "Feigenbaum = 4.669",
        "F(7) = 13",                "sqrt(5) = 2.236",       "999 = 37 x 27",
        "pi = 3.14159",             "27 = 3^3",              "CHSH = 2*sqrt(2)",
        "m_p/m_e = 1836",           "pi^2 = 9.87",           "e^pi = 23.14",
        "E8 = 248 dim",             "603 = 67*9",            "76 photons",
        "phi^2+1/phi^2 = 3",        "tau = 6.283",           "Menger = 2.727",
        "mu = 0.0382",              "chi = 0.0618",          "sigma = phi",
        "e = 2.71828",              "13.82 Gyr",             "H0 = 70.74",
        // 15 extra sacred formulas
        "V = n*3^k*pi^m*phi^p*e^q", "1.58 bits/trit",        "phi = (1+sqrt(5))/2",
        "e^(i*pi) + 1 = 0",         "3 = phi^2 + 1/phi^2",   "F(n) = F(n-1)+F(n-2)",
        "hbar = 1.054e-34",         "c = 299792458 m/s",     "G = 6.674e-11",
        "L(n): 2,1,3,4,7,11,18...", "tau/phi = 3.883",       "pi*e = 8.539",
        "phi^phi = 2.390",          "3^3^3 = 7625597484987", "sqrt(2) = 1.414",
    };
    const formula_descs = [42][]const u8{
        "Golden ratio — nature's proportion", "Product of transcendentals",  "10th Lucas number",
        "Fine structure constant inverse",      "Golden ratio squared",        "Feigenbaum chaos constant",
        "7th Fibonacci number",                 "Square root of five",         "Sacred number 999",
        "Circle ratio",                         "Cube of trinity",             "Quantum Bell bound",
        "Proton-electron mass ratio",           "Basel problem result",        "Euler to pi",
        "E8 Lie group dimension",               "Energy efficiency",           "Quantum advantage",
        "TRINITY IDENTITY",                     "Full turn tau",               "Menger sponge fractal",
        "Mutation rate from phi",               "Crossover rate from phi",     "Selection = phi",
        "Euler's number",                       "Age of universe",             "Hubble constant",
        "Trinity value formula",                "Ternary information density", "Golden ratio definition",
        "Euler's identity",                     "Trinity identity",            "Fibonacci recurrence",
        "Reduced Planck constant",              "Speed of light",              "Gravitational constant",
        "Lucas sequence",                       "Tau over phi",                "Pi times e",
        "Phi to phi power",                     "Tower of threes",             "Pythagoras' constant",
    };
    // formula_particles is file-scope global (frame_formula_particles)
    // Golden angle = 2*pi/phi^2 ~ 137.508 degrees — Fibonacci spiral
    const golden_angle: f32 = 2.0 * std.math.pi / (1.618 * 1.618);
    const min_radius: f32 = 240.0; // avoid overlapping the logo
    for (0..42) |fi| {
        const n = @as(f32, @floatFromInt(fi));
        const angle = n * golden_angle;
        const radius = min_radius + n * 14.0; // Wider spacing — each formula separate
        // Alternate direction: even layers clockwise, odd layers counter-clockwise
        const layer = fi / 9; // 0..4 layers of ~9
        const direction: f32 = if (layer % 2 == 0) 1.0 else -1.0;
        const speed: f32 = direction * (0.03 - n * 0.0003);
        frame_formula_particles[fi] = FormulaParticle.init(
            formula_texts[fi],
            formula_descs[fi],
            angle,
            radius,
            speed,
        );
    }

    // Main loop
    if (is_emscripten) {
        emc.emscripten_set_main_loop(updateDrawFrame, 0, true);
    } else {
        while (!rl.WindowShouldClose() and !g_should_quit) {
            updateDrawFrame();
        }
    }
}

fn updateDrawFrame() callconv(.c) void {
    // === BeginDrawing FIRST — ensures we always see something ===
    rl.BeginDrawing();
    defer rl.EndDrawing();
    rl.ClearBackground(rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 });

    // DEBUG marker removed (was: TRINITY WASM OK)

    const dt = rl.GetFrameTime();
    frame_time += dt;

    // Cmd+Q to quit (desktop only, not in WASM)
    if (!is_emscripten and (rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER)) and rl.IsKeyPressed(rl.KEY_Q)) {
        g_should_quit = true;
        return;
    }

    // Cmd+D = toggle dark/light theme
    if ((rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER)) and rl.IsKeyPressed(rl.KEY_D)) {
        theme.toggle();
        reloadThemeAliases();
    }

    // Click on sun/moon toggle button (top-right)
    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
        const tcx: f32 = @as(f32, @floatFromInt(g_width)) - 35;
        const tcy: f32 = 30;
        const tmx = @as(f32, @floatFromInt(rl.GetMouseX()));
        const tmy = @as(f32, @floatFromInt(rl.GetMouseY()));
        const dx_t = tmx - tcx;
        const dy_t = tmy - tcy;
        if (dx_t * dx_t + dy_t * dy_t <= 14 * 14) {
            theme.toggle();
            reloadThemeAliases();
        }
    }

    // Update window size (adaptive/resizable)
    g_width = rl.GetScreenWidth();
    g_height = rl.GetScreenHeight();

    // Adaptive font scale: proportional to screen width (ref 1280px)
    // Trinity rule: scale by phi^(log3(w/1280)) for ternary harmony
    g_font_scale = @max(0.75, @min(2.0, @as(f32, @floatFromInt(g_width)) / 1280.0));

    // Calculate pixel size to COVER full window (no gaps at edges)
    const grid_w_c: c_int = @intCast(frame_grid.width);
    const grid_h_c: c_int = @intCast(frame_grid.height);
    const px_w = @divTrunc(g_width + grid_w_c - 1, grid_w_c); // ceil division
    const px_h = @divTrunc(g_height + grid_h_c - 1, grid_h_c);
    g_pixel_size = @max(1, @max(px_w, px_h));

    const mouse_x = rl.GetMouseX();
    const mouse_y = rl.GetMouseY();
    const mx = @as(f32, @floatFromInt(mouse_x));
    const my = @as(f32, @floatFromInt(mouse_y));

    const gx = @as(usize, @intCast(@max(0, @min(@as(c_int, @intCast(frame_grid.width - 1)), @divTrunc(mouse_x, g_pixel_size)))));
    const gy = @as(usize, @intCast(@max(0, @min(@as(c_int, @intCast(frame_grid.height - 1)), @divTrunc(mouse_y, g_pixel_size)))));

    frame_cursor_hue = @mod(frame_cursor_hue + dt * 30.0, 360.0);

    // === INPUT HANDLING ===

    // Detect if chat is active (wave mode or legacy panel)
    const chat_is_open: bool = if (g_wave_mode == .chat) true else blk_chat: {
        if (frame_panels.active_panel) |idx| {
            const p = &frame_panels.panels[idx];
            const is_visible = (p.state == .open or p.state == .opening);
            if (is_visible and p.panel_type == .chat) break :blk_chat true;
            if (is_visible and p.panel_type == .sacred_world and p.world_id == 0) break :blk_chat true;
        }
        break :blk_chat false;
    };

    // Sacred Worlds keyboard shortcuts:
    // Shift+1-9 = Realm RAZUM (blocks 0-8)
    // Ctrl+1-9  = Realm MATERIYA (blocks 9-17)
    // Cmd+1-9   = Realm DUKH (blocks 18-26)
    // DISABLED when chat panel is open (so user can type freely)
    const shift_held = rl.IsKeyDown(rl.KEY_LEFT_SHIFT) or rl.IsKeyDown(rl.KEY_RIGHT_SHIFT);
    const ctrl_held = rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL);
    const cmd_held = rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER);

    // Calculate fullscreen panel positions
    const screen_w = @as(f32, @floatFromInt(g_width));
    const screen_h = @as(f32, @floatFromInt(g_height));

    // v1.9: Shift+1-6 = Wave Mode Switch (no panels)
    // Chat mode also allows Shift+keys for wave mode switch
    if (!chat_is_open) {
        if (shift_held) {
            var new_mode: ?WaveMode = null;
            if (rl.IsKeyPressed(rl.KEY_ONE)) new_mode = .chat;
            if (rl.IsKeyPressed(rl.KEY_TWO)) new_mode = .code;
            if (rl.IsKeyPressed(rl.KEY_THREE)) new_mode = .tools;
            if (rl.IsKeyPressed(rl.KEY_FOUR)) new_mode = .settings;
            if (rl.IsKeyPressed(rl.KEY_FIVE)) new_mode = .vision;
            if (rl.IsKeyPressed(rl.KEY_SIX)) new_mode = .voice;
            if (rl.IsKeyPressed(rl.KEY_SEVEN)) new_mode = .finder;
            if (rl.IsKeyPressed(rl.KEY_EIGHT)) new_mode = .docs;
            if (rl.IsKeyPressed(rl.KEY_NINE)) new_mode = .ralph;
            if (rl.IsKeyPressed(rl.KEY_ZERO)) new_mode = .idle;
            if (rl.IsKeyPressed(rl.KEY_D)) new_mode = .depin;
            if (rl.IsKeyPressed(rl.KEY_M)) new_mode = .mirror;

            if (new_mode) |nm| {
                if (nm != g_wave_mode) {
                    g_wave_mode_prev = g_wave_mode;
                    g_wave_mode = nm;
                    g_wave_transition = 0; // Start transition animation
                    // Wave burst on mode change
                    frame_effects.nova(screen_w / 2, screen_h / 2);
                    // Perturb grid with mode's hue
                    const mode_hue = nm.getHue();
                    const freq_shift = mode_hue / 360.0 * TAU;
                    for (0..@min(frame_grid.height, 5)) |wy| {
                        for (0..frame_grid.width) |wx| {
                            frame_grid.getMut(wx, wy).amplitude += @sin(freq_shift + @as(f32, @floatFromInt(wx)) * 0.3) * 0.2;
                        }
                    }
                }
            }
        }
    }

    // Keyboard scroll for active sacred_world panel (docs/chat only)
    if (frame_panels.active_panel) |ap_idx| {
        const ap = &frame_panels.panels[ap_idx];
        if (ap.panel_type == .sacred_world and ap.state == .open and ap.world_id != 0) {
            // Skip keyboard scroll for chat panel (world_id 0) — keys go to text input
            const max_scroll_kb: f32 = if (ap.world_id == 18) blk_ks: {
                var total: u32 = 0;
                var dsi: usize = 0;
                while (dsi < 27) : (dsi += 1) {
                    total += world_docs.countVisibleLines(world_docs.WORLD_DOCS[dsi].raw);
                    total += 4;
                }
                break :blk_ks @as(f32, @floatFromInt(total)) * 18.0 * g_font_scale;
            } else 0.0;
            if (ap.wave_scroll_enabled) {
                // Wave scroll: keyboard impulses
                if (rl.IsKeyPressed(rl.KEY_DOWN) or rl.IsKeyDown(rl.KEY_DOWN)) ap.wave_sv.applyImpulse(0.1);
                if (rl.IsKeyPressed(rl.KEY_UP) or rl.IsKeyDown(rl.KEY_UP)) ap.wave_sv.applyImpulse(-0.1);
                if (rl.IsKeyPressed(rl.KEY_PAGE_DOWN)) ap.wave_sv.applyImpulse(7.5);
                if (rl.IsKeyPressed(rl.KEY_PAGE_UP)) ap.wave_sv.applyImpulse(-7.5);
                if (rl.IsKeyPressed(rl.KEY_HOME)) ap.wave_sv.scrollToItem(0);
                if (rl.IsKeyPressed(rl.KEY_END)) ap.wave_sv.scrollToItem(ap.wave_sv.total_items -| 1);
            } else {
                // Legacy lerp scroll: keyboard targets
                if (rl.IsKeyPressed(rl.KEY_DOWN) or rl.IsKeyDown(rl.KEY_DOWN)) ap.scroll_target += 4.0;
                if (rl.IsKeyPressed(rl.KEY_UP) or rl.IsKeyDown(rl.KEY_UP)) ap.scroll_target -= 4.0;
                if (rl.IsKeyPressed(rl.KEY_PAGE_DOWN)) ap.scroll_target += 300;
                if (rl.IsKeyPressed(rl.KEY_PAGE_UP)) ap.scroll_target -= 300;
                if (rl.IsKeyPressed(rl.KEY_HOME)) ap.scroll_target = 0;
                if (rl.IsKeyPressed(rl.KEY_END)) ap.scroll_target = max_scroll_kb;
                ap.scroll_target = @max(0, @min(ap.scroll_target, max_scroll_kb));
            }
        }
    }

    // ESC = return to idle (27 petals logo)
    if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
        if (g_wave_mode != .idle) {
            if (g_wave_mode == .depin) g_depin_auto_started = false;
            g_wave_mode_prev = g_wave_mode;
            g_wave_mode = .idle;
            g_wave_transition = 0;
            frame_effects.sink(screen_w / 2, screen_h / 2);
        }
        frame_panels.unfocusAll();
        // Close all sacred world panels
        for (0..frame_panels.count) |pi| {
            if (frame_panels.panels[pi].panel_type == .sacred_world) {
                frame_panels.panels[pi].close();
            }
        }
    }

    // Click outside any panel = close all panels (return to logo menu)
    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT) and !shift_held and !ctrl_held and !cmd_held) {
        var clicked_on_panel = false;
        for (0..frame_panels.count) |pi| {
            const p = &frame_panels.panels[pi];
            if (p.state == .open or p.state == .opening) {
                if (mx >= p.x and mx <= p.x + p.width and my >= p.y and my <= p.y + p.height) {
                    clicked_on_panel = true;
                    break;
                }
            }
        }
        // Also check if click is on the logo (don't close if clicking logo)
        const on_logo = frame_logo_anim.hovered_block >= 0;
        if (!clicked_on_panel and !on_logo) {
            // Close all panels — return to main logo menu
            for (0..frame_panels.count) |pi| {
                frame_panels.panels[pi].close();
                frame_panels.panels[pi].is_focused = false;
            }
            frame_panels.unfocusAll();
        }
    }

    // === CHAT INPUT (v1.9: wave mode or legacy panel) ===
    // Routes keyboard to chat when g_wave_mode == .chat or legacy panel
    const wave_chat_active = g_wave_mode == .chat;
    const focused_chat_panel: ?*GlassPanel = if (wave_chat_active) null else blk: {
        if (frame_panels.active_panel) |idx| {
            const p = &frame_panels.panels[idx];
            const is_visible = (p.state == .open or p.state == .opening);
            if (is_visible and p.panel_type == .chat) {
                break :blk p;
            }
            if (is_visible and p.panel_type == .sacred_world and p.world_id == 0) {
                break :blk p;
            }
        }
        break :blk null;
    };

    if (wave_chat_active or focused_chat_panel != null) {
        if (focused_chat_panel) |chat_panel| {
            _ = chat_panel;
        } // legacy compat
        // All panel-switching hotkeys are disabled when chat is open (see chat_is_open above)
        {
            // Text input: Unicode codepoints → UTF-8 encoded into global buffer
            // Skip character input when Ctrl/Cmd is held (prevents Ctrl+O etc from interfering)
            const skip_char_input = (rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL) or
                rl.IsKeyDown(rl.KEY_LEFT_SUPER) or rl.IsKeyDown(rl.KEY_RIGHT_SUPER));
            var char_key = rl.GetCharPressed();
            while (char_key > 0) {
                const cp: u21 = @intCast(char_key);
                if (cp >= 32 and !skip_char_input) {
                    // Encode UTF-8
                    var utf8_buf: [4]u8 = undefined;
                    const utf8_len: usize = if (cp < 0x80) blk_u: {
                        utf8_buf[0] = @intCast(cp);
                        break :blk_u 1;
                    } else if (cp < 0x800) blk_u: {
                        utf8_buf[0] = @intCast(0xC0 | (cp >> 6));
                        utf8_buf[1] = @intCast(0x80 | (cp & 0x3F));
                        break :blk_u 2;
                    } else if (cp < 0x10000) blk_u: {
                        utf8_buf[0] = @intCast(0xE0 | (cp >> 12));
                        utf8_buf[1] = @intCast(0x80 | ((cp >> 6) & 0x3F));
                        utf8_buf[2] = @intCast(0x80 | (cp & 0x3F));
                        break :blk_u 3;
                    } else blk_u: {
                        utf8_buf[0] = @intCast(0xF0 | (cp >> 18));
                        utf8_buf[1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
                        utf8_buf[2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
                        utf8_buf[3] = @intCast(0x80 | (cp & 0x3F));
                        break :blk_u 4;
                    };
                    if (g_chat_input_len + utf8_len < 250) {
                        @memcpy(g_chat_input[g_chat_input_len..][0..utf8_len], utf8_buf[0..utf8_len]);
                        g_chat_input_len += utf8_len;
                        // Typing wave effect
                        frame_effects.sink(screen_w / 2, screen_h * 0.9);
                    }
                }
                char_key = rl.GetCharPressed();
            }
        }

        // Backspace — delete UTF-8 characters (with key repeat for hold)
        {
            const bs_pressed = rl.IsKeyPressed(rl.KEY_BACKSPACE);
            const bs_held = rl.IsKeyDown(rl.KEY_BACKSPACE);
            if (bs_pressed) {
                g_backspace_timer = 0.4; // Initial delay before repeat
            }
            var do_delete = bs_pressed;
            if (bs_held and !bs_pressed) {
                g_backspace_timer -= rl.GetFrameTime();
                if (g_backspace_timer <= 0) {
                    do_delete = true;
                    g_backspace_timer = 0.04; // Repeat rate (25 chars/sec)
                }
            }
            if (!bs_held) g_backspace_timer = 0;
            if (do_delete and g_chat_input_len > 0) {
                var del: usize = 1;
                while (del < g_chat_input_len and
                    (g_chat_input[g_chat_input_len - del] & 0xC0) == 0x80)
                {
                    del += 1;
                }
                g_chat_input_len -= del;
            }
        }

        // Ctrl+O clears the input
        if ((rl.IsKeyDown(rl.KEY_LEFT_CONTROL) or rl.IsKeyDown(rl.KEY_RIGHT_CONTROL)) and rl.IsKeyPressed(rl.KEY_O)) {
            g_chat_input_len = 0;
        }

        // Enter sends message
        if (rl.IsKeyPressed(rl.KEY_ENTER) and g_chat_input_len > 0) {
            // Lazy init IglaHybridChat (v2.4: 4-level cache with self-reflection)
            if (!g_hybrid_inited) {
                const alloc = if (is_emscripten) std.heap.page_allocator else g_hybrid_gpa.allocator();

                // Create TVC corpus on heap
                g_hybrid_corpus = alloc.create(tvc.TVCCorpus) catch null;
                if (g_hybrid_corpus) |c| {
                    c.initInPlace();
                }

                // Create hybrid chat with env API keys
                var hconfig = igla_hybrid_chat.HybridConfig{};
                if (!is_emscripten) {
                    hconfig.groq_api_key = std.posix.getenv("GROQ_API_KEY");
                    hconfig.claude_api_key = std.posix.getenv("ANTHROPIC_API_KEY");
                    hconfig.openai_api_key = std.posix.getenv("OPENAI_API_KEY");
                }
                hconfig.enable_context = true;
                hconfig.system_prompt = "You are Trinity, a helpful AI. Be concise.";

                g_hybrid_engine = igla_hybrid_chat.IglaHybridChat.initWithConfig(alloc, null, hconfig) catch null;
                if (g_hybrid_engine != null and g_hybrid_corpus != null) {
                    g_hybrid_engine.?.corpus = g_hybrid_corpus;
                }
                g_hybrid_inited = true;

                // Also init FluentChatEngine as fallback
                if (!g_fluent_engine_inited) {
                    g_fluent_engine = fluent_chat.FluentChatEngine{
                        .message_store = fluent_chat.LightMessageStore.init(),
                        .context = fluent_chat.ConversationContext.init(),
                        .generator = undefined,
                        .fluent_enabled = true,
                        .total_turns = 0,
                        .fluent_responses = 0,
                        .high_quality_count = 0,
                    };
                    g_fluent_engine.generator = fluent_chat.ResponseGenerator.init(&g_fluent_engine.context);
                    g_fluent_engine_inited = true;
                }
            }

            // 1. Add user message
            addGlobalChatMessage(g_chat_input[0..g_chat_input_len], .user);

            // 2. v3.0: Golden Chain — 8-node pipeline via GoldenChainAgent
            if (g_hybrid_engine != null) {
                // Init chain agent on first use (lazy)
                if (g_chain_agent == null) {
                    g_chain_agent = golden_chain.GoldenChainAgent.init(&g_hybrid_engine.?);
                }

                if (g_chain_agent) |*agent| {
                    agent.processInput(g_chat_input[0..g_chat_input_len]);

                    // Copy all chain messages to canvas chat
                    for (agent.getMessages()) |*chain_msg| {
                        const canvas_type = chainMsgToCanvasType(chain_msg);
                        addGlobalChatMessage(chain_msg.getContent(), canvas_type);
                    }

                    // Feed live log with final chain state
                    {
                        const cs = golden_chain.g_chain_state;
                        var ll_buf: [96]u8 = undefined;
                        const ll_text = std.fmt.bufPrint(&ll_buf, "CHAIN|{d:.0}%|{d}us", .{ cs.total_confidence * 100, cs.total_latency_us }) catch "";
                        addLiveLog(ll_text, igla_hybrid_chat.g_last_wave_state.source_hue);

                        // Update reflection name from chain
                        const rname = "GoldenChain";
                        @memcpy(g_last_reflection_name[0..rname.len], rname);
                        g_last_reflection_name[rname.len] = 0;
                        g_last_reflection_len = rname.len;
                    }

                    frame_effects.nova(screen_w / 2, screen_h / 2);
                } else {
                    // Fallback: direct hybrid (shouldn't reach here)
                    if (g_hybrid_engine.?.respond(g_chat_input[0..g_chat_input_len])) |hr| {
                        addGlobalChatMessage(hr.response, .ai);
                    } else |_| {
                        addGlobalChatMessage("Error: no response", .agent_error);
                    }
                    frame_effects.nova(screen_w / 2, screen_h / 2);
                }
            } else {
                // No hybrid engine — use FluentChatEngine
                const result = g_fluent_engine.respond(g_chat_input[0..g_chat_input_len]);
                addGlobalChatMessage(result.getText(), .ai);
                const stats = g_fluent_engine.getStats();
                const ms = @divFloor(result.execution_time_ns, @as(i64, 1_000_000));
                addChatLogMessage("{s} | {s} | {s} | q:{d:.0}% | {d}ms | s:{d:.2} | e:{d:.2}", .{
                    result.intent.getName(),
                    result.topic.getName(),
                    result.language.getName(),
                    result.quality * 100,
                    ms,
                    stats.sentiment,
                    stats.engagement,
                });
                frame_effects.nova(screen_w / 2, screen_h / 2);
            }

            // Auto-scroll: set to a large value, renderer will clamp
            g_chat_scroll_target = 99999.0;

            // Clear input
            g_chat_input_len = 0;
        }
    } else {
        // Normal controls (no global input - use Shift+N for panels)

        // T = Tool spawn (demo)
        if (rl.IsKeyPressed(rl.KEY_T)) {
            const center_x = @as(f32, @floatFromInt(g_width)) / 2.0;
            const center_y = @as(f32, @floatFromInt(g_height)) / 2.0;
            frame_tools.spawn(center_x, center_y, "inference");
            frame_tools.setStatus("inference", .running);
            frame_mode = .tools;
        }

        // V = Vision (inject image perturbation - demo)
        if (rl.IsKeyPressed(rl.KEY_V)) {
            // Simulate image loading as grid perturbation
            for (0..frame_grid.height) |y| {
                for (0..frame_grid.width) |x| {
                    const px = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(frame_grid.width));
                    const py = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(frame_grid.height));
                    const pattern = @sin(px * TAU * 4.0) * @cos(py * TAU * 4.0);
                    frame_grid.getMut(x, y).amplitude += pattern * 0.3;
                }
            }
            frame_clusters.spawn(mx, my, "VISION INPUT", false);
            frame_mode = .vision;
        }

        // A = Voice/Audio mode (frequency modulation)
        if (rl.IsKeyPressed(rl.KEY_A)) {
            // Simulate voice as frequency modulation
            const freq_mod = @sin(frame_time * 10.0) * 0.5;
            for (frame_grid.photons[0..frame_grid.width]) |*p| {
                p.frequency += freq_mod;
            }
            frame_clusters.spawn(mx, my, "VOICE INPUT", false);
            frame_mode = .voice;
        }

        // N = Nova effect (success)
        if (rl.IsKeyPressed(rl.KEY_N)) {
            frame_effects.nova(mx, my);
        }

        // S = Sink effect (failure)
        if (rl.IsKeyPressed(rl.KEY_S)) {
            frame_effects.sink(mx, my);
        }

        // R = Reset
        if (rl.IsKeyPressed(rl.KEY_R)) {
            for (frame_grid.photons) |*p| {
                p.amplitude = 0;
                p.interference = 0;
            }
            const center_x = @as(f32, @floatFromInt(g_width)) / 2.0;
            const center_y = @as(f32, @floatFromInt(g_height)) / 2.0;
            frame_clusters.spawn(center_x, center_y, "REBIRTH", false);
            frame_mode = .idle;
        }

        // Mouse interactions
        if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            if (gx < frame_grid.width and gy < frame_grid.height) {
                frame_grid.setCursor(@floatFromInt(gx), @floatFromInt(gy), 1.0);
            }
        }

        if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_RIGHT)) {
            if (gx < frame_grid.width and gy < frame_grid.height) {
                frame_grid.getMut(gx, gy).amplitude = -1.0;
            }
        }
    }

    // === UPDATE ===
    frame_grid.stepSIMD();
    frame_clusters.update(dt);
    frame_spirals.update(dt);
    frame_tools.update(dt);
    frame_effects.update(dt);
    frame_goal.update(&frame_grid, dt);

    // Update panels with mouse state
    const mouse_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
    const mouse_down_state = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT);
    const mouse_released = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);
    const mouse_wheel = rl.GetMouseWheelMove();
    frame_panels.update(dt, frame_time, mx, my, mouse_pressed, mouse_down_state, mouse_released, mouse_wheel);

    // Check autonomous goal completion
    if (frame_goal.progress >= 1.0 and frame_mode == .autonomous) {
        frame_effects.nova(frame_goal.x, frame_goal.y);
        frame_clusters.spawn(frame_goal.x, frame_goal.y, "GOAL ACHIEVED", false);
        frame_mode = .idle;
    }

    // === RENDER ===
    // (BeginDrawing/EndDrawing moved to top of updateDrawFrame)

    // Theme-aware background (second clear overrides debug text above — keep for now)
    // rl.ClearBackground(@as(rl.Color, @bitCast(theme.clear_bg)));

    // === LOGO LOADING ANIMATION (Apple-style luxury welcome) ===
    if (!frame_loading_complete) {
        // Update logo animation
        frame_logo_anim.logo_scale = @min(@as(f32, @floatFromInt(g_width)) / LogoAnimation.SVG_WIDTH, @as(f32, @floatFromInt(g_height)) / LogoAnimation.SVG_HEIGHT) * 0.35;
        frame_logo_anim.logo_offset = .{ .x = @as(f32, @floatFromInt(g_width)) / 2, .y = @as(f32, @floatFromInt(g_height)) / 2 };
        frame_logo_anim.update(dt);

        // Draw logo animation
        frame_logo_anim.draw();

        // Check if animation complete
        if (frame_logo_anim.is_complete) {
            frame_loading_complete = true;
        }

        return; // Skip main canvas rendering during loading
    }

    // Grid & visual systems (skip in DePIN/Ralph mode for clean background)
    if (g_wave_mode != .depin and g_wave_mode != .ralph) {
        drawImmersiveGrid(&frame_grid, frame_time);
        frame_clusters.draw(frame_time);
        frame_spirals.draw();
        frame_tools.draw(frame_time);
        frame_effects.draw();
        frame_goal.draw(frame_time);
    }

    // === v2.4: DePIN Node Polling ===
    if (g_wave_mode == .depin or g_depin_running) {
        // Auto-start on first entry to DePIN mode
        if (g_wave_mode == .depin and g_depin_docker_ok and !g_depin_running and !g_depin_auto_started) {
            g_depin_auto_started = true;
            depinStartNode();
            g_depin_poll_timer = 8.0; // Poll soon after start
        }
        // ── v2.4: DePIN polling ──
        g_depin_poll_timer += dt;
        if (g_depin_poll_timer > 5.0) {
            g_depin_poll_timer = 0;
            // In real WASM, we'd use emscripten_run_script to call fetch
            // For now, we simulate or use exported functions
        }

        g_depin_poll_timer += dt;
        if (g_depin_poll_timer >= 10.0) {
            g_depin_poll_timer = 0;
            g_depin_running = depinCheckRunning();
            if (g_depin_running) depinPollStats();
        }
    }

    // ── v3.0: Multi-Agent Ralph Monitor Polling (RALPH-CANVAS-005) ──
    // NOTE: This MUST be outside the DePIN block so it runs in .ralph and .mirror modes
    if (g_wave_mode == .mirror or g_wave_mode == .ralph) {
        if (!g_ralph_initialized) initRalphAgents();

        var ai: usize = 0;
        while (ai < g_ralph_agent_count) : (ai += 1) {
            g_ralph_agents[ai].update_timer += dt;
            if (g_ralph_agents[ai].update_timer > 2.0) {
                g_ralph_agents[ai].update_timer = 0;
                if (is_emscripten) {
                    // WASM: use emscripten fetch (kept for completeness, not active on desktop)
                } else {
                    // Desktop: Read .ralph/ files directly from disk
                    pollRalphAgentDesktop(ai);
                    buildUnifiedChat(ai);
                }
            }
        }
    }

    // === v1.9: Wave Mode Transition ===
    g_wave_transition = @min(1.0, g_wave_transition + dt * 3.0); // 0.33s transition

    // === IDLE MODE: Logo + Formula Particles ===
    if (g_wave_mode == .idle) {
        // Static logo in center (realm-colored, stays after loading)
        frame_logo_anim.logo_scale = @min(@as(f32, @floatFromInt(g_width)) / LogoAnimation.SVG_WIDTH, @as(f32, @floatFromInt(g_height)) / LogoAnimation.SVG_HEIGHT) * 0.35;
        frame_logo_anim.logo_offset = .{ .x = @as(f32, @floatFromInt(g_width)) / 2, .y = @as(f32, @floatFromInt(g_height)) / 2 };
        frame_logo_anim.applyMouse(mx, my, dt, mouse_pressed);
        frame_logo_anim.draw();

        // Sacred formula particles — Fibonacci spiral orbit
        {
            const fcx = @as(f32, @floatFromInt(g_width)) / 2;
            const fcy = @as(f32, @floatFromInt(g_height)) / 2;
            const formula_click = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
            for (&frame_formula_particles) |*fp| {
                fp.update(dt, frame_time, mx, my, formula_click, fcx, fcy);
                fp.draw(frame_time, fcx, fcy, frame_font_small);
            }
        }

        // Handle logo block click — switch to wave mode
        if (frame_logo_anim.clicked_block >= 0) {
            const block_idx = @as(usize, @intCast(frame_logo_anim.clicked_block));
            // Block 0 = Chat, Block 2 = Ralph, Block 16 = DePIN, Block 18 = Docs, others = tools
            const new_wm: WaveMode = if (block_idx == 0) .chat else if (block_idx == 2) .ralph else if (block_idx == 16) .depin else if (block_idx == 18) .docs else .tools;
            g_wave_mode_prev = g_wave_mode;
            g_wave_mode = new_wm;
            g_wave_transition = 0;
            frame_effects.nova(screen_w / 2, screen_h / 2);
        }

        // Hover tooltip: show world name + realm color
        if (frame_logo_anim.hovered_block >= 0) {
            const hi = @as(usize, @intCast(frame_logo_anim.hovered_block));
            const world = sacred_worlds.getWorldByBlock(hi);
            const tw: f32 = @as(f32, @floatFromInt(world.name_len)) * 9.0 + 30;
            const tx = mx + 15;
            const ty = my - 28;
            const tt_bg: rl.Color = @bitCast(theme.tooltip_bg);
            const tt_text: rl.Color = @bitCast(theme.tooltip_text);
            rl.DrawRectangleRounded(.{ .x = tx, .y = ty, .width = tw, .height = 24 }, 0.3, 8, tt_bg);
            rl.DrawCircle(@intFromFloat(tx + 10), @intFromFloat(ty + 12), 4, tt_text);
            var tooltip_buf: [28:0]u8 = undefined;
            @memcpy(tooltip_buf[0..world.name_len], world.name[0..world.name_len]);
            tooltip_buf[world.name_len] = 0;
            rl.DrawTextEx(frame_font_small, &tooltip_buf, .{ .x = tx + 20, .y = ty + 5 }, 13, 0.5, tt_text);
        }
    }

    // === WAVE MODE RENDERERS (fullscreen, no panels) ===
    if (g_wave_mode != .idle) {
        const fs = g_font_scale;
        const chat_font = g_font_chat;
        const sw = @as(f32, @floatFromInt(g_width));
        const sh = @as(f32, @floatFromInt(g_height));
        const alpha_u8: u8 = @intFromFloat(@min(255, g_wave_transition * 255));
        const mode_hue = g_wave_mode.getHue();
        const mode_rgb = hsvToRgb(mode_hue, 0.7, 1.0);
        const mode_color = rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = alpha_u8 };

        // DePIN/Ralph mode: skip all other wave renderers, draw dedicated panel
        if (g_wave_mode != .depin and g_wave_mode != .ralph) {

            // Mode label (top-center)
            const label = g_wave_mode.getLabel();
            const label_w = rl.MeasureTextEx(chat_font, label, 18 * fs, 1.0).x;
            rl.DrawTextEx(chat_font, label, .{ .x = (sw - label_w) / 2, .y = 12 }, 18 * fs, 1.0, mode_color);

            // Subtle wave border ring — v2.1: modulated by g_last_wave_state
            const ring_r = @min(sw, sh) * 0.48;
            const ring_cx = sw / 2;
            const ring_cy = sh / 2;
            const ring_alpha: u8 = @intFromFloat(@max(0, @min(60, @as(f32, @floatFromInt(alpha_u8)) * 0.25)));

            // v2.1: Read wave state from hybrid chat engine
            const ws = igla_hybrid_chat.g_last_wave_state;
            const ws_hue = if (ws.source_hue > 0.01) ws.source_hue else mode_hue;
            const ws_rgb = hsvToRgb(ws_hue, 0.7, @max(0.5, ws.provider_health_avg));
            const ws_pulse = ws.confidence * 0.5 + ws.similarity * 0.5;
            const ring_color = if (ws.source_hue > 0.01)
                rl.Color{ .r = ws_rgb[0], .g = ws_rgb[1], .b = ws_rgb[2], .a = ring_alpha }
            else
                rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = ring_alpha };

            rl.DrawCircleLines(@intFromFloat(ring_cx), @intFromFloat(ring_cy), ring_r + @sin(frame_time * 2.0) * (3 + ws_pulse * 5), ring_color);

            // v2.1: Memory load indicator — inner ring thickness
            if (ws.memory_load > 0.01) {
                const mem_r = ring_r * (0.9 + ws.memory_load * 0.08);
                const mem_alpha: u8 = @intFromFloat(@max(0, @min(40, ws.memory_load * 60)));
                rl.DrawCircleLines(@intFromFloat(ring_cx), @intFromFloat(ring_cy), mem_r, rl.Color{ .r = 100, .g = 200, .b = 100, .a = mem_alpha });
            }

            // v2.1: Learning glow — green pulse when saving to TVC
            if (ws.is_learning) {
                const learn_alpha: u8 = @intFromFloat(@max(0, @min(80, @sin(frame_time * 6.0) * 40 + 40)));
                rl.DrawCircleLines(@intFromFloat(ring_cx), @intFromFloat(ring_cy), ring_r * 0.95 + @sin(frame_time * 4.0) * 2, rl.Color{ .r = 0, .g = 255, .b = 100, .a = learn_alpha });
            }

            // === CHAT WAVE FIELD ===
            if (g_wave_mode == .chat) {
                // Fullscreen chat — same logic as sacred_world chat panel but without GlassPanel frame
                const chat_dt = rl.GetFrameTime();
                g_chat_scroll_y += (g_chat_scroll_target - g_chat_scroll_y) * @min(1.0, 8.0 * chat_dt);

                const chat_margin: f32 = 70 * fs;
                const chat_top: f32 = 40 * fs;
                const input_h: f32 = 48 * fs;
                const chat_bottom: f32 = sh - input_h - 40 * fs;
                const msg_area_h = chat_bottom - chat_top;
                const line_h: f32 = 22 * fs;
                const msg_font_size: f32 = 17 * fs;
                const bubble_pad: f32 = 14 * fs;
                const max_text_w = sw - chat_margin * 2 - bubble_pad * 2;
                const chat_text_color = withAlpha(CHAT_TEXT, alpha_u8);

                // Scissor clip for messages
                rl.BeginScissorMode(0, @intFromFloat(chat_top), @intFromFloat(sw), @intFromFloat(@max(1, msg_area_h)));

                g_chat_scroll_target = @max(0, g_chat_scroll_target);

                if (g_chat_msg_count == 0) {
                    const welcome_y = chat_top + msg_area_h * 0.3;
                    rl.DrawTextEx(chat_font, "Trinity AI", .{ .x = chat_margin, .y = welcome_y }, 18 * fs, 0.5, withAlpha(HYPER_GREEN, alpha_u8));
                    rl.DrawTextEx(chat_font, "Type a message below to start chatting.", .{ .x = chat_margin, .y = welcome_y + 24 * fs }, 14 * fs, 0.5, withAlpha(MUTED_GRAY, alpha_u8));
                    g_chat_scroll_target = 0;
                    g_chat_scroll_y = 0;
                } else {
                    var render_y: f32 = chat_top + 6 * fs - g_chat_scroll_y;
                    var mi: usize = 0;
                    while (mi < g_chat_msg_count) : (mi += 1) {
                        const msg_type = g_chat_msg_types[mi];
                        const msg_len = g_chat_msg_lens[mi];
                        const msg_data = g_chat_messages[mi][0..msg_len];

                        // Log messages
                        if (msg_type == .log) {
                            if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                var log_z: [512:0]u8 = undefined;
                                const log_copy = @min(msg_len, 511);
                                @memcpy(log_z[0..log_copy], msg_data[0..log_copy]);
                                log_z[log_copy] = 0;
                                const log_color = rl.Color{ .r = 120, .g = 120, .b = 140, .a = 180 };
                                rl.DrawTextEx(chat_font, &log_z, .{ .x = chat_margin, .y = render_y }, 13 * fs, 0.3, log_color);
                            }
                            render_y += 18 * fs;
                            continue;
                        }

                        // v3.0: Golden Chain messages — colored indicator + label + text
                        if (isChainType(msg_type)) {
                            if (render_y >= chat_top - line_h * 2 and render_y <= chat_bottom + line_h) {
                                // Draw pulsing Chakra indicator circle
                                drawChainIndicator(chat_margin - 14 * fs, render_y + 8 * fs, msg_type, frame_time, fs);

                                // Draw chain label
                                const chain_label = getChainMsgLabel(msg_type);
                                const chain_color = getChainMsgColor(msg_type, alpha_u8);
                                rl.DrawTextEx(chat_font, chain_label, .{ .x = chat_margin, .y = render_y }, 12 * fs, 0.3, chain_color);

                                // Draw message content below label
                                if (msg_len > 0) {
                                    var chain_z: [512:0]u8 = undefined;
                                    const chain_copy = @min(msg_len, 511);
                                    @memcpy(chain_z[0..chain_copy], msg_data[0..chain_copy]);
                                    chain_z[chain_copy] = 0;
                                    const chain_text_col = rl.Color{ .r = chain_color.r, .g = chain_color.g, .b = chain_color.b, .a = @min(alpha_u8, 200) };
                                    rl.DrawTextEx(chat_font, &chain_z, .{ .x = chat_margin + 8 * fs, .y = render_y + 15 * fs }, 14 * fs, 0.3, chain_text_col);
                                }
                            }
                            render_y += 34 * fs; // label line + content line + spacing
                            continue;
                        }

                        const is_user = msg_type == .user;

                        // Label
                        if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                            const label_color = if (is_user) withAlpha(CHAT_LABEL_USER, alpha_u8) else withAlpha(CHAT_LABEL_AI, alpha_u8);
                            if (is_user) {
                                const you_w = rl.MeasureTextEx(chat_font, "You", 16 * fs, 0.5).x;
                                rl.DrawTextEx(chat_font, "You", .{ .x = sw - chat_margin - you_w, .y = render_y }, 16 * fs, 0.5, label_color);
                            } else {
                                rl.DrawTextEx(chat_font, "Trinity", .{ .x = chat_margin, .y = render_y }, 16 * fs, 0.5, label_color);
                            }
                        }
                        render_y += 18 * fs;

                        // Measure text
                        var full_z: [512:0]u8 = undefined;
                        const full_copy = @min(msg_len, 511);
                        @memcpy(full_z[0..full_copy], msg_data[0..full_copy]);
                        full_z[full_copy] = 0;
                        const text_size = rl.MeasureTextEx(chat_font, &full_z, msg_font_size, 0.5);
                        const needs_wrap = text_size.x > max_text_w;

                        if (!needs_wrap) {
                            if (is_user) {
                                const text_x = sw - chat_margin - text_size.x;
                                if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                    rl.DrawTextEx(chat_font, &full_z, .{ .x = text_x, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                    rl.DrawTextEx(chat_font, &full_z, .{ .x = text_x + 0.6, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                }
                                render_y += line_h + 8 * fs;
                            } else {
                                if (render_y >= chat_top - line_h and render_y <= chat_bottom + line_h) {
                                    rl.DrawTextEx(chat_font, &full_z, .{ .x = chat_margin, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                    rl.DrawTextEx(chat_font, &full_z, .{ .x = chat_margin + 0.6, .y = render_y }, msg_font_size, 0.5, chat_text_color);
                                }
                                render_y += line_h + 8 * fs;
                            }
                        } else {
                            // Multi-line word wrap
                            var n_lines: f32 = 0;
                            {
                                var pos: usize = 0;
                                while (pos < msg_data.len) {
                                    var end = pos;
                                    var last_space: usize = pos;
                                    while (end < msg_data.len) {
                                        var next = end + 1;
                                        while (next < msg_data.len and (msg_data[next] & 0xC0) == 0x80) next += 1;
                                        var tmp: [256:0]u8 = undefined;
                                        const seg_len = @min(next - pos, 255);
                                        @memcpy(tmp[0..seg_len], msg_data[pos .. pos + seg_len]);
                                        tmp[seg_len] = 0;
                                        const w = rl.MeasureTextEx(chat_font, &tmp, msg_font_size, 0.5).x;
                                        if (w > max_text_w and end > pos) break;
                                        if (msg_data[end] == ' ') last_space = end;
                                        end = next;
                                    }
                                    if (end < msg_data.len and last_space > pos) end = last_space + 1 else if (end == pos) end = pos + 1;
                                    n_lines += 1;
                                    pos = end;
                                    while (pos < msg_data.len and msg_data[pos] == ' ') pos += 1;
                                }
                                if (n_lines == 0) n_lines = 1;
                            }

                            const bubble_h = n_lines * line_h;
                            const bubble_x = chat_margin;

                            var text_y = render_y;
                            var pos2: usize = 0;
                            var line_buf_chat: [256:0]u8 = undefined;
                            while (pos2 < msg_data.len) {
                                var end2 = pos2;
                                var last_sp2: usize = pos2;
                                while (end2 < msg_data.len) {
                                    var next2 = end2 + 1;
                                    while (next2 < msg_data.len and (msg_data[next2] & 0xC0) == 0x80) next2 += 1;
                                    var tmp2: [256:0]u8 = undefined;
                                    const seg_len2 = @min(next2 - pos2, 255);
                                    @memcpy(tmp2[0..seg_len2], msg_data[pos2 .. pos2 + seg_len2]);
                                    tmp2[seg_len2] = 0;
                                    const w2 = rl.MeasureTextEx(chat_font, &tmp2, msg_font_size, 0.5).x;
                                    if (w2 > max_text_w and end2 > pos2) break;
                                    if (msg_data[end2] == ' ') last_sp2 = end2;
                                    end2 = next2;
                                }
                                if (end2 < msg_data.len and last_sp2 > pos2) end2 = last_sp2 + 1 else if (end2 == pos2) end2 = pos2 + 1;

                                if (text_y >= chat_top - line_h and text_y <= chat_bottom + line_h) {
                                    const ln_len = @min(end2 - pos2, 255);
                                    @memcpy(line_buf_chat[0..ln_len], msg_data[pos2 .. pos2 + ln_len]);
                                    var tlen = ln_len;
                                    while (tlen > 0 and line_buf_chat[tlen - 1] == ' ') tlen -= 1;
                                    line_buf_chat[tlen] = 0;
                                    rl.DrawTextEx(chat_font, &line_buf_chat, .{ .x = bubble_x + bubble_pad, .y = text_y }, msg_font_size, 0.5, chat_text_color);
                                    rl.DrawTextEx(chat_font, &line_buf_chat, .{ .x = bubble_x + bubble_pad + 0.6, .y = text_y }, msg_font_size, 0.5, chat_text_color);
                                }

                                text_y += line_h;
                                pos2 = end2;
                                while (pos2 < msg_data.len and msg_data[pos2] == ' ') pos2 += 1;
                            }

                            render_y += bubble_h + 8 * fs;
                        }
                    }

                    // Scroll clamping
                    const total_content_h = render_y + g_chat_scroll_y - (chat_top + 6 * fs);
                    const max_scroll = @max(0, total_content_h - msg_area_h + 20 * fs);
                    g_chat_scroll_target = @min(g_chat_scroll_target, max_scroll);
                    g_chat_scroll_y = @min(g_chat_scroll_y, max_scroll + 10 * fs);
                }

                rl.EndScissorMode();

                // Mouse wheel scroll
                {
                    const cmy = @as(f32, @floatFromInt(rl.GetMouseY()));
                    if (cmy >= chat_top and cmy <= chat_bottom) {
                        g_chat_scroll_target -= rl.GetMouseWheelMove() * 40.0 * fs;
                        g_chat_scroll_target = @max(0, g_chat_scroll_target);
                    }
                }

                // Input area (bottom)
                const input_y = chat_bottom + 4 * fs;
                const sep_color = rl.Color{ .r = 100, .g = 100, .b = 110, .a = 120 };

                rl.DrawRectangle(
                    @intFromFloat(chat_margin),
                    @intFromFloat(input_y),
                    @intFromFloat(sw - chat_margin * 2),
                    @intFromFloat(input_h),
                    CHAT_INPUT_BG,
                );
                rl.DrawLineEx(.{ .x = chat_margin, .y = input_y }, .{ .x = sw - chat_margin, .y = input_y }, 1.0, sep_color);
                rl.DrawLineEx(.{ .x = chat_margin, .y = input_y + input_h }, .{ .x = sw - chat_margin, .y = input_y + input_h }, 1.0, sep_color);

                const prompt_y = input_y + 14 * fs;
                const prompt_sz: f32 = 17 * fs;
                const prompt_color = rl.Color{ .r = 150, .g = 150, .b = 160, .a = 220 };
                rl.DrawTextEx(chat_font, ">", .{ .x = chat_margin + 6 * fs, .y = prompt_y }, prompt_sz, 0.5, prompt_color);

                // "enter to send" hint
                const send_sz: f32 = 13 * fs;
                const send_color = rl.Color{ .r = 140, .g = 140, .b = 150, .a = 180 };
                const send_w = rl.MeasureTextEx(chat_font, "enter to send", send_sz, 0.5).x;
                rl.DrawTextEx(chat_font, "enter to send", .{ .x = sw - chat_margin - send_w - 10 * fs, .y = input_y + 16 * fs }, send_sz, 0.5, send_color);

                if (g_chat_input_len > 0) {
                    var input_disp: [260:0]u8 = undefined;
                    const show_input = @min(g_chat_input_len, 255);
                    @memcpy(input_disp[0..show_input], g_chat_input[0..show_input]);
                    input_disp[show_input] = 0;
                    const ix = chat_margin + 22 * fs;
                    const iy = input_y + 14 * fs;
                    const isz: f32 = 17 * fs;
                    rl.DrawTextEx(chat_font, &input_disp, .{ .x = ix, .y = iy }, isz, 0.5, CHAT_INPUT_TEXT);
                    rl.DrawTextEx(chat_font, &input_disp, .{ .x = ix + 0.5, .y = iy }, isz, 0.5, CHAT_INPUT_TEXT);
                    // Blinking cursor
                    if (@mod(@as(u32, @intFromFloat(frame_time * 3)), 2) == 0) {
                        const text_w = rl.MeasureTextEx(chat_font, &input_disp, isz, 0.5).x;
                        rl.DrawRectangle(@intFromFloat(ix + text_w + 2 * fs), @intFromFloat(iy), @intFromFloat(2 * fs), @intFromFloat(isz), CHAT_INPUT_TEXT);
                    }
                } else {
                    // Empty: blinking cursor
                    const ph_x = chat_margin + 22 * fs;
                    const ph_y = input_y + 14 * fs;
                    const ph_sz: f32 = 17 * fs;
                    if (@mod(@as(u32, @intFromFloat(frame_time * 2)), 2) == 0) {
                        rl.DrawRectangle(@intFromFloat(ph_x), @intFromFloat(ph_y), @intFromFloat(2 * fs), @intFromFloat(ph_sz), CHAT_INPUT_TEXT);
                    }
                }

                // Status bar
                {
                    const wstatus_y = input_y + input_h + 3 * fs;
                    const status_sz: f32 = 11 * fs;
                    const status_color = rl.Color{ .r = 100, .g = 100, .b = 115, .a = 160 };
                    const fps_val = rl.GetFPS();
                    var wstatus_buf: [256:0]u8 = undefined;
                    if (g_fluent_engine_inited) {
                        const st = g_fluent_engine.getStats();
                        const sl = std.fmt.bufPrint(wstatus_buf[0..255], "{d}fps | fluent {d:.0}% | {s} | {s} | s:{d:.1}", .{
                            fps_val, st.fluent_rate * 100, st.current_language.getName(), st.current_topic.getName(), st.sentiment,
                        }) catch "...";
                        wstatus_buf[sl.len] = 0;
                    } else {
                        const sl = std.fmt.bufPrint(wstatus_buf[0..255], "{d}fps | trinity v1.9 | ready", .{fps_val}) catch "...";
                        wstatus_buf[sl.len] = 0;
                    }
                    rl.DrawTextEx(chat_font, &wstatus_buf, .{ .x = chat_margin + 4 * fs, .y = wstatus_y }, status_sz, 0.3, status_color);
                    var count_buf: [64:0]u8 = undefined;
                    const ct = std.fmt.bufPrint(count_buf[0..63], "{d} msgs", .{g_chat_msg_count}) catch "0";
                    count_buf[ct.len] = 0;
                    const count_w = rl.MeasureTextEx(chat_font, &count_buf, status_sz, 0.3).x;
                    rl.DrawTextEx(chat_font, &count_buf, .{ .x = sw - chat_margin - count_w - 4 * fs, .y = wstatus_y }, status_sz, 0.3, status_color);
                }
            }

            // === CODE WAVE FIELD === (system info as scrolling code lines)
            if (g_wave_mode == .code) {
                const margin: f32 = 60 * fs;
                const line_h: f32 = 22 * fs;
                const code_font_sz: f32 = 16 * fs;
                const code_dim = withAlpha(rl.Color{ .r = 100, .g = 200, .b = 255, .a = 255 }, alpha_u8);
                const code_green = withAlpha(rl.Color{ .r = 80, .g = 255, .b = 120, .a = 255 }, alpha_u8);
                const code_gray = withAlpha(MUTED_GRAY, alpha_u8);

                // v2.0: LIVE system data formatted as Zig code
                const cws = igla_hybrid_chat.g_last_wave_state;
                const fps_val = rl.GetFPS();
                const ts = std.time.timestamp();

                var buf0: [64:0]u8 = undefined;
                var buf1: [64:0]u8 = undefined;
                var buf2: [64:0]u8 = undefined;
                var buf3: [64:0]u8 = undefined;
                var buf4: [64:0]u8 = undefined;
                var buf5: [64:0]u8 = undefined;
                var buf6: [64:0]u8 = undefined;
                var buf7: [64:0]u8 = undefined;
                var buf8: [64:0]u8 = undefined;
                var buf9: [64:0]u8 = undefined;

                _ = std.fmt.bufPrint(&buf0, "const fps = {d};", .{fps_val}) catch {};
                buf0[@min(63, std.mem.indexOfScalar(u8, &buf0, 0) orelse 63)] = 0;
                _ = std.fmt.bufPrint(&buf1, "const uptime_s = {d};", .{ts}) catch {};
                buf1[@min(63, std.mem.indexOfScalar(u8, &buf1, 0) orelse 63)] = 0;

                const engine_str = if (g_hybrid_engine != null) "IglaHybridChat v2.4" else "FluentChat";
                _ = std.fmt.bufPrint(&buf2, "const engine = \"{s}\";", .{engine_str}) catch {};
                buf2[@min(63, std.mem.indexOfScalar(u8, &buf2, 0) orelse 63)] = 0;

                const queries = if (g_hybrid_engine != null) g_hybrid_engine.?.total_queries else 0;
                _ = std.fmt.bufPrint(&buf3, "const total_queries = {d};", .{queries}) catch {};
                buf3[@min(63, std.mem.indexOfScalar(u8, &buf3, 0) orelse 63)] = 0;

                const routing_name = @tagName(cws.routing);
                _ = std.fmt.bufPrint(&buf4, "const routing = .{s};", .{routing_name}) catch {};
                buf4[@min(63, std.mem.indexOfScalar(u8, &buf4, 0) orelse 63)] = 0;

                _ = std.fmt.bufPrint(&buf5, "const confidence = {d:.2};", .{cws.confidence}) catch {};
                buf5[@min(63, std.mem.indexOfScalar(u8, &buf5, 0) orelse 63)] = 0;

                _ = std.fmt.bufPrint(&buf6, "const is_learning = {s};", .{if (cws.is_learning) "true" else "false"}) catch {};
                buf6[@min(63, std.mem.indexOfScalar(u8, &buf6, 0) orelse 63)] = 0;

                _ = std.fmt.bufPrint(&buf7, "const memory_load = {d:.2};", .{cws.memory_load}) catch {};
                buf7[@min(63, std.mem.indexOfScalar(u8, &buf7, 0) orelse 63)] = 0;

                _ = std.fmt.bufPrint(&buf8, "const provider_health = {d:.2};", .{cws.provider_health_avg}) catch {};
                buf8[@min(63, std.mem.indexOfScalar(u8, &buf8, 0) orelse 63)] = 0;

                _ = std.fmt.bufPrint(&buf9, "const source_hue = {d:.0};", .{cws.source_hue}) catch {};
                buf9[@min(63, std.mem.indexOfScalar(u8, &buf9, 0) orelse 63)] = 0;

                const live_lines = [_][*:0]const u8{
                    "// === TRINITY SYSTEM v2.0 (LIVE) ===",
                    &buf0,
                    &buf1,
                    "const canvas = \"v2.0\";",
                    &buf2,
                    &buf3,
                    "// === WAVE STATE (LIVE) ===",
                    &buf4,
                    &buf5,
                    &buf6,
                    &buf7,
                    &buf8,
                    &buf9,
                    "const vsa_dim = 1024;",
                    "const tvc_max = 10000;",
                    "// phi^2 + 1/phi^2 = 3 = TRINITY",
                };

                var yi: usize = 0;
                while (yi < live_lines.len) : (yi += 1) {
                    const y_pos = 50 * fs + @as(f32, @floatFromInt(yi)) * line_h;
                    const wave_x = @sin(frame_time * 1.5 + @as(f32, @floatFromInt(yi)) * 0.4) * 3;
                    const line_color = if (yi == 0 or yi == 6 or yi == 15) code_green else if (yi < 6) code_dim else code_gray;
                    rl.DrawTextEx(chat_font, live_lines[yi], .{ .x = margin + wave_x, .y = y_pos }, code_font_sz, 0.5, line_color);
                    // Line number
                    var num_buf: [8:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&num_buf, "{d:>3}", .{yi + 1}) catch {};
                    num_buf[3] = 0;
                    rl.DrawTextEx(chat_font, &num_buf, .{ .x = margin - 40 * fs, .y = y_pos }, code_font_sz, 0.5, withAlpha(MUTED_GRAY, @as(u8, @intFromFloat(@max(0, @min(255, @as(f32, @floatFromInt(alpha_u8)) * 0.4))))));
                }

                // Animated wave rings behind
                for (0..3) |ri| {
                    const r = 200.0 + @as(f32, @floatFromInt(ri)) * 80.0 + @sin(frame_time * 1.2 + @as(f32, @floatFromInt(ri)) * 1.0) * 15;
                    const ra: u8 = @intFromFloat(@max(0, @min(30, @as(f32, @floatFromInt(alpha_u8)) * 0.12)));
                    rl.DrawCircleLines(@intFromFloat(sw / 2), @intFromFloat(sh / 2), r, rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = ra });
                }
            }

            // === TOOLS WAVE FIELD === (tool status wheel with LIVE data)
            if (g_wave_mode == .tools) {
                const center_x = sw / 2;
                const center_y = sh / 2;
                const tool_names = [_][*:0]const u8{ "time", "date", "system", "file_read", "file_list", "zig_build", "zig_test" };
                const tool_count = tool_names.len;
                const orbit_r: f32 = @min(sw, sh) * 0.25;

                // v2.0: Live tool status
                const tools_enabled = if (g_hybrid_engine != null) g_hybrid_engine.?.config.enable_tools else false;
                const tws = igla_hybrid_chat.g_last_wave_state;

                // Title with live status
                if (tools_enabled) {
                    rl.DrawTextEx(chat_font, "TOOLS: ACTIVE", .{ .x = center_x - 65, .y = 40 * fs }, 18 * fs, 0.5, mode_color);
                } else {
                    rl.DrawTextEx(chat_font, "TOOLS: OFFLINE", .{ .x = center_x - 65, .y = 40 * fs }, 18 * fs, 0.5, withAlpha(MUTED_GRAY, alpha_u8));
                }

                // v2.0: Show last routing as subtitle
                var route_buf: [48:0]u8 = undefined;
                _ = std.fmt.bufPrint(&route_buf, "Last route: {s}", .{@tagName(tws.routing)}) catch {};
                route_buf[@min(47, std.mem.indexOfScalar(u8, &route_buf, 0) orelse 47)] = 0;
                rl.DrawTextEx(chat_font, &route_buf, .{ .x = center_x - 55, .y = 62 * fs }, 13 * fs, 0.5, withAlpha(MUTED_GRAY, alpha_u8));

                // Tool items in circle
                for (0..tool_count) |ti| {
                    const angle = @as(f32, @floatFromInt(ti)) * (std.math.pi * 2.0 / @as(f32, @floatFromInt(tool_count))) - std.math.pi / 2.0 + frame_time * 0.1;
                    const tx = center_x + @cos(angle) * orbit_r;
                    const ty = center_y + @sin(angle) * orbit_r;
                    const pulse = @sin(frame_time * 3.0 + @as(f32, @floatFromInt(ti)) * 1.2) * 0.3 + 0.7;
                    const tool_alpha: u8 = @intFromFloat(@max(60, @min(255, pulse * @as(f32, @floatFromInt(alpha_u8)))));

                    // Status dot: green if enabled, gray if disabled
                    const dot_color = if (tools_enabled) rl.Color{ .r = 80, .g = 255, .b = 80, .a = tool_alpha } else rl.Color{ .r = 120, .g = 120, .b = 120, .a = tool_alpha };
                    rl.DrawCircle(@intFromFloat(tx - 12), @intFromFloat(ty + 2), 4, dot_color);
                    // Tool name
                    rl.DrawTextEx(chat_font, tool_names[ti], .{ .x = tx - 4, .y = ty - 6 }, 15 * fs, 0.5, withAlpha(mode_color, tool_alpha));

                    // Connecting line
                    rl.DrawLine(@intFromFloat(center_x), @intFromFloat(center_y), @intFromFloat(tx), @intFromFloat(ty), rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = @as(u8, @intFromFloat(@max(0, @min(30, pulse * 40)))) });
                }

                // v2.0: Center shows total queries
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), 18, withAlpha(mode_color, @as(u8, @intFromFloat(@max(20, @as(f32, @floatFromInt(alpha_u8)) * 0.3)))));
                var q_buf: [16:0]u8 = undefined;
                const qcount = if (g_hybrid_engine != null) g_hybrid_engine.?.total_queries else 0;
                _ = std.fmt.bufPrint(&q_buf, "{d}", .{qcount}) catch {};
                q_buf[@min(15, std.mem.indexOfScalar(u8, &q_buf, 0) orelse 15)] = 0;
                rl.DrawTextEx(chat_font, &q_buf, .{ .x = center_x - 8, .y = center_y - 7 }, 14 * fs, 0.5, mode_color);
            }

            // === SETTINGS WAVE FIELD === (LIVE config from HybridConfig)
            if (g_wave_mode == .settings) {
                const margin: f32 = 80 * fs;
                const line_h: f32 = 26 * fs;
                const key_color = withAlpha(mode_color, alpha_u8);
                const val_color = withAlpha(rl.Color{ .r = 200, .g = 200, .b = 220, .a = 255 }, alpha_u8);
                const active_color = withAlpha(rl.Color{ .r = 80, .g = 255, .b = 120, .a = 255 }, alpha_u8);

                rl.DrawTextEx(chat_font, "CONFIGURATION (LIVE)", .{ .x = margin, .y = 40 * fs }, 20 * fs, 0.5, key_color);

                const keys = [_][*:0]const u8{
                    "symbolic_threshold",
                    "tvc_similarity",
                    "max_tokens",
                    "temperature",
                    "enable_reflection",
                    "enable_context",
                    "enable_tools",
                    "groq_model",
                    "claude_model",
                    "GROQ_API_KEY",
                    "ANTHROPIC_API_KEY",
                    "total_queries",
                };

                // v2.0: Read LIVE values from HybridConfig
                var vb0: [32:0]u8 = undefined;
                var vb1: [32:0]u8 = undefined;
                var vb2: [32:0]u8 = undefined;
                var vb3: [32:0]u8 = undefined;
                var vb11: [32:0]u8 = undefined;
                if (g_hybrid_engine != null) {
                    const cfg = g_hybrid_engine.?.config;
                    _ = std.fmt.bufPrint(&vb0, "{d:.2}", .{cfg.symbolic_confidence_threshold}) catch {};
                    vb0[@min(31, std.mem.indexOfScalar(u8, &vb0, 0) orelse 31)] = 0;
                    _ = std.fmt.bufPrint(&vb1, "{d:.2}", .{cfg.tvc_similarity_threshold}) catch {};
                    vb1[@min(31, std.mem.indexOfScalar(u8, &vb1, 0) orelse 31)] = 0;
                    _ = std.fmt.bufPrint(&vb2, "{d}", .{cfg.max_tokens}) catch {};
                    vb2[@min(31, std.mem.indexOfScalar(u8, &vb2, 0) orelse 31)] = 0;
                    _ = std.fmt.bufPrint(&vb3, "{d:.2}", .{cfg.temperature}) catch {};
                    vb3[@min(31, std.mem.indexOfScalar(u8, &vb3, 0) orelse 31)] = 0;
                    _ = std.fmt.bufPrint(&vb11, "{d}", .{g_hybrid_engine.?.total_queries}) catch {};
                    vb11[@min(31, std.mem.indexOfScalar(u8, &vb11, 0) orelse 31)] = 0;
                } else {
                    @memcpy(vb0[0..4], "0.30");
                    vb0[4] = 0;
                    @memcpy(vb1[0..4], "0.55");
                    vb1[4] = 0;
                    @memcpy(vb2[0..2], "32");
                    vb2[2] = 0;
                    @memcpy(vb3[0..4], "0.70");
                    vb3[4] = 0;
                    @memcpy(vb11[0..1], "0");
                    vb11[1] = 0;
                }

                const refl_str: [*:0]const u8 = if (g_hybrid_engine != null and g_hybrid_engine.?.config.enable_reflection) "true" else "false";
                const ctx_str: [*:0]const u8 = if (g_hybrid_engine != null and g_hybrid_engine.?.config.enable_context) "true" else "false";
                const tools_str: [*:0]const u8 = if (g_hybrid_engine != null and g_hybrid_engine.?.config.enable_tools) "true" else "false";
                const groq_key_str: [*:0]const u8 = if (g_hybrid_engine != null and g_hybrid_engine.?.config.groq_api_key != null) "****" else "not set";
                const claude_key_str: [*:0]const u8 = if (g_hybrid_engine != null and g_hybrid_engine.?.config.claude_api_key != null) "****" else "not set";

                const vals = [_][*:0]const u8{
                    &vb0,
                    &vb1,
                    &vb2,
                    &vb3,
                    refl_str,
                    ctx_str,
                    tools_str,
                    "llama-3.3-70b-versatile",
                    "claude-sonnet-4-20250514",
                    groq_key_str,
                    claude_key_str,
                    &vb11,
                };

                var si: usize = 0;
                while (si < keys.len) : (si += 1) {
                    const y_pos = 80 * fs + @as(f32, @floatFromInt(si)) * line_h;
                    const wave_x = @sin(frame_time * 1.0 + @as(f32, @floatFromInt(si)) * 0.5) * 2;
                    rl.DrawTextEx(chat_font, keys[si], .{ .x = margin + wave_x, .y = y_pos }, 15 * fs, 0.5, key_color);
                    // v2.0: Color booleans green/gray
                    const vc = if (si >= 4 and si <= 6) active_color else val_color;
                    rl.DrawTextEx(chat_font, vals[si], .{ .x = margin + 280 * fs + wave_x, .y = y_pos }, 15 * fs, 0.5, vc);
                }

                // Concentric config rings
                for (0..4) |ri| {
                    const r = 100.0 + @as(f32, @floatFromInt(ri)) * 60.0 + @sin(frame_time * 0.8 + @as(f32, @floatFromInt(ri))) * 8;
                    rl.DrawCircleLines(@intFromFloat(sw * 0.7), @intFromFloat(sh * 0.55), r, rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = @as(u8, @intFromFloat(@max(0, @min(25, @as(f32, @floatFromInt(alpha_u8)) * 0.1)))) });
                }
            }

            // === DOCS WAVE FIELD === (all 27 sacred worlds)
            if (g_wave_mode == .docs) {
                const margin: f32 = 60 * fs;
                const line_h: f32 = 28 * fs;
                const title_color = withAlpha(mode_color, alpha_u8);

                rl.DrawTextEx(chat_font, "SACRED WORLDS (27)", .{ .x = margin, .y = 35 * fs }, 18 * fs, 0.5, title_color);

                // v2.0: Display all 27 sacred worlds
                const max_worlds: usize = 27;
                var wi: usize = 0;
                while (wi < max_worlds) : (wi += 1) {
                    const y_pos = 75 * fs + @as(f32, @floatFromInt(wi)) * line_h;
                    if (y_pos > sh - 40) break;

                    const wave_x = @sin(frame_time * 0.8 + @as(f32, @floatFromInt(wi)) * 0.3) * 3;
                    const realm = sacred_worlds.blockToRealm(wi);
                    const rc = rl.Color{
                        .r = sacred_worlds.realmColorR(realm),
                        .g = sacred_worlds.realmColorG(realm),
                        .b = sacred_worlds.realmColorB(realm),
                        .a = alpha_u8,
                    };

                    // Realm color dot
                    rl.DrawCircle(@intFromFloat(margin + wave_x), @intFromFloat(y_pos + 7), 5, rc);

                    // World name
                    const world = sacred_worlds.getWorldByBlock(wi);
                    var wname_buf: [32:0]u8 = undefined;
                    const wname: []const u8 = &world.name;
                    const wname_len = std.mem.indexOfScalar(u8, wname, 0) orelse wname.len;
                    @memcpy(wname_buf[0..wname_len], wname[0..wname_len]);
                    wname_buf[wname_len] = 0;
                    rl.DrawTextEx(chat_font, &wname_buf, .{ .x = margin + 18 + wave_x, .y = y_pos }, 15 * fs, 0.5, withAlpha(rl.Color{ .r = 220, .g = 220, .b = 230, .a = 255 }, alpha_u8));

                    // Realm name
                    const realm_idx = @intFromEnum(realm);
                    const rn_len = sacred_worlds.REALM_NAME_LENS[realm_idx];
                    var rbuf: [64:0]u8 = undefined;
                    @memcpy(rbuf[0..rn_len], sacred_worlds.REALM_NAMES[realm_idx][0..rn_len]);
                    rbuf[rn_len] = 0;
                    rl.DrawTextEx(chat_font, &rbuf, .{ .x = margin + 260 * fs + wave_x, .y = y_pos }, 13 * fs, 0.5, rc);
                }
            }

            // === FINDER WAVE FIELD === (LIVE directory listing via std.fs)
            if (g_wave_mode == .finder) {
                const margin: f32 = 60 * fs;
                const line_h: f32 = 22 * fs;
                const dir_color = withAlpha(mode_color, alpha_u8);
                const file_color = withAlpha(rl.Color{ .r = 180, .g = 200, .b = 220, .a = 255 }, alpha_u8);

                // v2.0: Scan real directory (every 2 seconds)
                const now_ts = std.time.timestamp();
                if (!g_finder_scanned or (now_ts - g_finder_last_scan) > 2) {
                    scanDirectory();
                }

                rl.DrawTextEx(chat_font, "FILE EXPLORER (LIVE)", .{ .x = margin, .y = 35 * fs }, 18 * fs, 0.5, dir_color);

                // v2.0: Show file count
                var count_buf: [48:0]u8 = undefined;
                _ = std.fmt.bufPrint(&count_buf, "cwd: {d} entries", .{g_finder_count}) catch {};
                count_buf[@min(47, std.mem.indexOfScalar(u8, &count_buf, 0) orelse 47)] = 0;
                rl.DrawTextEx(chat_font, &count_buf, .{ .x = margin, .y = 60 * fs }, 14 * fs, 0.5, withAlpha(MUTED_GRAY, alpha_u8));

                // v2.0: Display REAL files from g_finder_names
                var fi: usize = 0;
                while (fi < g_finder_count) : (fi += 1) {
                    const y_pos = 85 * fs + @as(f32, @floatFromInt(fi)) * line_h;
                    if (y_pos > sh - 40) break;
                    const wave_x = @sin(frame_time * 1.2 + @as(f32, @floatFromInt(fi)) * 0.35) * 2;
                    const ic = if (g_finder_is_dir[fi]) dir_color else file_color;
                    // Dir indicator
                    if (g_finder_is_dir[fi]) {
                        var dir_buf: [68:0]u8 = undefined;
                        const nlen = std.mem.indexOfScalar(u8, &g_finder_names[fi], 0) orelse 63;
                        @memcpy(dir_buf[0..nlen], g_finder_names[fi][0..nlen]);
                        dir_buf[nlen] = '/';
                        dir_buf[nlen + 1] = 0;
                        rl.DrawTextEx(chat_font, &dir_buf, .{ .x = margin + wave_x, .y = y_pos }, 14 * fs, 0.5, ic);
                    } else {
                        rl.DrawTextEx(chat_font, &g_finder_names[fi], .{ .x = margin + wave_x, .y = y_pos }, 14 * fs, 0.5, ic);
                    }
                }

                // Spiral decoration
                for (0..20) |si| {
                    const angle = @as(f32, @floatFromInt(si)) * 0.5 + frame_time * 0.3;
                    const r = 30.0 + @as(f32, @floatFromInt(si)) * 8.0;
                    const sx = sw * 0.75 + @cos(angle) * r;
                    const sy = sh * 0.5 + @sin(angle) * r;
                    rl.DrawCircle(@intFromFloat(sx), @intFromFloat(sy), 2, rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = @as(u8, @intFromFloat(@max(0, @min(60, @as(f32, @floatFromInt(alpha_u8)) * 0.2)))) });
                }
            }

            // === VISION WAVE FIELD === (LIVE API status + instructions)
            if (g_wave_mode == .vision) {
                const center_x = sw / 2;
                const center_y = sh / 2;

                // Expanding concentric rings
                for (0..8) |ri| {
                    const base_r = 40.0 + @as(f32, @floatFromInt(ri)) * 35.0;
                    const r = base_r + @sin(frame_time * 2.0 + @as(f32, @floatFromInt(ri)) * 0.8) * 10;
                    const ra: u8 = @intFromFloat(@max(0, @min(80, @as(f32, @floatFromInt(alpha_u8)) * (0.35 - @as(f32, @floatFromInt(ri)) * 0.04))));
                    rl.DrawCircleLines(@intFromFloat(center_x), @intFromFloat(center_y), r, rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = ra });
                }

                // Center icon (eye)
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), 12, mode_color);
                rl.DrawCircle(@intFromFloat(center_x), @intFromFloat(center_y), 6, rl.Color{ .r = 20, .g = 20, .b = 30, .a = alpha_u8 });

                // v2.0: LIVE API status
                rl.DrawTextEx(chat_font, "VISION", .{ .x = center_x - 30, .y = center_y - 80 }, 20 * fs, 0.5, mode_color);

                // Check Claude API key availability
                const has_claude = g_hybrid_engine != null and g_hybrid_engine.?.config.claude_api_key != null;
                if (has_claude) {
                    rl.DrawCircle(@intFromFloat(center_x - 90), @intFromFloat(center_y + 42), 4, rl.Color{ .r = 80, .g = 255, .b = 80, .a = alpha_u8 });
                    rl.DrawTextEx(chat_font, "Claude Vision API: ready", .{ .x = center_x - 80, .y = center_y + 35 }, 14 * fs, 0.5, withAlpha(rl.Color{ .r = 80, .g = 255, .b = 120, .a = 255 }, alpha_u8));
                } else {
                    rl.DrawCircle(@intFromFloat(center_x - 90), @intFromFloat(center_y + 42), 4, rl.Color{ .r = 255, .g = 120, .b = 80, .a = alpha_u8 });
                    rl.DrawTextEx(chat_font, "Claude Vision API: no key", .{ .x = center_x - 80, .y = center_y + 35 }, 14 * fs, 0.5, withAlpha(rl.Color{ .r = 255, .g = 120, .b = 80, .a = 255 }, alpha_u8));
                }

                rl.DrawTextEx(chat_font, "In chat: type 'vision: /path/to/image'", .{ .x = center_x - 150, .y = center_y + 65 }, 14 * fs, 0.5, withAlpha(MUTED_GRAY, alpha_u8));
                rl.DrawTextEx(chat_font, "Supports: PNG, JPG, WEBP, GIF", .{ .x = center_x - 120, .y = center_y + 88 }, 12 * fs, 0.5, withAlpha(MUTED_GRAY, @as(u8, @intFromFloat(@max(0, @min(255, @as(f32, @floatFromInt(alpha_u8)) * 0.5))))));
                rl.DrawTextEx(chat_font, "respondWithImage() -> Claude/GPT-4o", .{ .x = center_x - 145, .y = center_y + 108 }, 12 * fs, 0.5, withAlpha(MUTED_GRAY, @as(u8, @intFromFloat(@max(0, @min(255, @as(f32, @floatFromInt(alpha_u8)) * 0.4))))));
            }

            // === VOICE WAVE FIELD === (wave state modulated waveform)
            if (g_wave_mode == .voice) {
                const center_y = sh / 2;
                const wave_count: usize = 64;
                const bar_w = sw / @as(f32, @floatFromInt(wave_count));

                // v2.0: Modulate waveform with LIVE wave state
                const vws = igla_hybrid_chat.g_last_wave_state;
                const conf_amp = @max(0.3, vws.confidence); // Amplitude from confidence
                const hue_freq = vws.source_hue / 360.0 * 2.0 + 1.5; // Frequency from source hue
                const health_bright = @max(0.4, vws.provider_health_avg); // Brightness from health

                // Audio waveform bars
                for (0..wave_count) |wi| {
                    const fi_f = @as(f32, @floatFromInt(wi));
                    const amp = @sin(frame_time * (2.0 + hue_freq) + fi_f * 0.3) * @sin(frame_time * 1.7 + fi_f * 0.15) * 60 * fs * conf_amp;
                    const bar_x = fi_f * bar_w + bar_w * 0.1;
                    const bar_h = @abs(amp) + 4;
                    const base_intensity = @abs(amp) * 3 + 40;
                    const intensity: u8 = @intFromFloat(@max(40, @min(255, base_intensity * health_bright)));

                    // v2.0: Green glow when learning
                    const bar_color = if (vws.is_learning) rl.Color{ .r = 40, .g = 255, .b = 80, .a = @as(u8, @intFromFloat(@max(0, @min(255, @as(f32, @floatFromInt(intensity)) * @as(f32, @floatFromInt(alpha_u8)) / 255.0)))) } else rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = @as(u8, @intFromFloat(@max(0, @min(255, @as(f32, @floatFromInt(intensity)) * @as(f32, @floatFromInt(alpha_u8)) / 255.0)))) };
                    rl.DrawRectangle(@intFromFloat(bar_x), @intFromFloat(center_y - bar_h / 2), @intFromFloat(@max(1, bar_w * 0.7)), @intFromFloat(@max(1, bar_h)), bar_color);
                }

                // Status with live data
                rl.DrawTextEx(chat_font, "VOICE", .{ .x = sw / 2 - 25, .y = 40 * fs }, 20 * fs, 0.5, mode_color);

                // v2.0: Show whisper model from config
                const whisper_str: [*:0]const u8 = if (g_hybrid_engine != null) "Whisper: whisper-1 (standby)" else "Whisper: not configured";
                rl.DrawTextEx(chat_font, whisper_str, .{ .x = sw / 2 - 100, .y = sh - 80 * fs }, 14 * fs, 0.5, withAlpha(MUTED_GRAY, alpha_u8));

                // v2.0: Show live wave state values
                var voice_info: [64:0]u8 = undefined;
                _ = std.fmt.bufPrint(&voice_info, "conf:{d:.0}% health:{d:.0}% route:{s}", .{ vws.confidence * 100, vws.provider_health_avg * 100, @tagName(vws.routing) }) catch {};
                voice_info[@min(63, std.mem.indexOfScalar(u8, &voice_info, 0) orelse 63)] = 0;
                rl.DrawTextEx(chat_font, &voice_info, .{ .x = sw / 2 - 130, .y = sh - 55 * fs }, 12 * fs, 0.5, withAlpha(MUTED_GRAY, @as(u8, @intFromFloat(@max(0, @min(255, @as(f32, @floatFromInt(alpha_u8)) * 0.5))))));

                // Center line
                rl.DrawLine(0, @intFromFloat(center_y), @intFromFloat(sw), @intFromFloat(center_y), rl.Color{ .r = mode_rgb[0], .g = mode_rgb[1], .b = mode_rgb[2], .a = @as(u8, @intFromFloat(@max(0, @min(30, @as(f32, @floatFromInt(alpha_u8)) * 0.12)))) });
            }

            // === v2.1: MIRROR OF THREE WORLDS ===
            if (g_wave_mode == .mirror) {
                const col_w = sw / 3.0;
                const log_h: f32 = 130 * fs;
                const content_h = sh - log_h;
                const line_h: f32 = 20 * fs;
                const title_sz: f32 = 20 * fs;
                const label_sz: f32 = 13 * fs;
                const val_sz: f32 = 14 * fs;

                // Realm colors
                const razum_color = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha_u8 };
                const materiya_color = rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = alpha_u8 };
                const dukh_color = rl.Color{ .r = 0xBD, .g = 0x93, .b = 0xF9, .a = alpha_u8 };
                const dim_text = withAlpha(MUTED_GRAY, alpha_u8);
                const bright_text = withAlpha(rl.Color{ .r = 220, .g = 220, .b = 230, .a = 255 }, alpha_u8);

                const mws = igla_hybrid_chat.g_last_wave_state;

                // Column separator lines
                rl.DrawLine(@intFromFloat(col_w), 0, @intFromFloat(col_w), @intFromFloat(content_h), rl.Color{ .r = 80, .g = 80, .b = 100, .a = @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.3)) });
                rl.DrawLine(@intFromFloat(col_w * 2), 0, @intFromFloat(col_w * 2), @intFromFloat(content_h), rl.Color{ .r = 80, .g = 80, .b = 100, .a = @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.3)) });
                // Log separator
                rl.DrawLine(0, @intFromFloat(content_h), @intFromFloat(sw), @intFromFloat(content_h), rl.Color{ .r = 80, .g = 80, .b = 100, .a = @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.5)) });

                // ── RAZUM COLUMN (left) ──
                {
                    const x: f32 = 20 * fs;
                    var y: f32 = 25 * fs;
                    rl.DrawTextEx(chat_font, "RAZUM", .{ .x = x, .y = y }, title_sz, 0.5, razum_color);
                    y += title_sz + 4;
                    rl.DrawTextEx(chat_font, "Mind / AI / Chat", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    y += line_h + 8;

                    // Routing
                    rl.DrawTextEx(chat_font, "Routing:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var r_buf: [32:0]u8 = undefined;
                    const r_name = @tagName(mws.routing);
                    _ = std.fmt.bufPrint(&r_buf, "{s}", .{r_name}) catch {};
                    r_buf[@min(31, std.mem.indexOfScalar(u8, &r_buf, 0) orelse 31)] = 0;
                    rl.DrawTextEx(chat_font, &r_buf, .{ .x = x + 80 * fs, .y = y }, val_sz, 0.5, razum_color);
                    y += line_h;

                    // Confidence
                    rl.DrawTextEx(chat_font, "Confidence:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var c_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&c_buf, "{d:.0}%", .{mws.confidence * 100}) catch {};
                    c_buf[@min(15, std.mem.indexOfScalar(u8, &c_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &c_buf, .{ .x = x + 100 * fs, .y = y }, val_sz, 0.5, bright_text);
                    // Confidence bar
                    const bar_w_max = col_w - 50 * fs;
                    const bar_y = y + line_h;
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(bar_y), @intFromFloat(bar_w_max), 4, rl.Color{ .r = 40, .g = 40, .b = 50, .a = alpha_u8 });
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(bar_y), @intFromFloat(bar_w_max * mws.confidence), 4, razum_color);
                    y += line_h + 10;

                    // Total queries
                    rl.DrawTextEx(chat_font, "Queries:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var q_buf: [16:0]u8 = undefined;
                    const qc = if (g_hybrid_engine != null) g_hybrid_engine.?.total_queries else 0;
                    _ = std.fmt.bufPrint(&q_buf, "{d}", .{qc}) catch {};
                    q_buf[@min(15, std.mem.indexOfScalar(u8, &q_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &q_buf, .{ .x = x + 80 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;

                    // Groq health
                    rl.DrawTextEx(chat_font, "Groq:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    if (g_hybrid_engine != null) {
                        var gh_buf: [16:0]u8 = undefined;
                        _ = std.fmt.bufPrint(&gh_buf, "{d:.0}%", .{g_hybrid_engine.?.groq_health.getSuccessRate() * 100}) catch {};
                        gh_buf[@min(15, std.mem.indexOfScalar(u8, &gh_buf, 0) orelse 15)] = 0;
                        rl.DrawTextEx(chat_font, &gh_buf, .{ .x = x + 55 * fs, .y = y }, val_sz, 0.5, bright_text);
                    } else {
                        rl.DrawTextEx(chat_font, "N/A", .{ .x = x + 55 * fs, .y = y }, val_sz, 0.5, dim_text);
                    }
                    y += line_h;

                    // Claude health
                    rl.DrawTextEx(chat_font, "Claude:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    if (g_hybrid_engine != null) {
                        var ch_buf: [16:0]u8 = undefined;
                        _ = std.fmt.bufPrint(&ch_buf, "{d:.0}%", .{g_hybrid_engine.?.claude_health.getSuccessRate() * 100}) catch {};
                        ch_buf[@min(15, std.mem.indexOfScalar(u8, &ch_buf, 0) orelse 15)] = 0;
                        rl.DrawTextEx(chat_font, &ch_buf, .{ .x = x + 65 * fs, .y = y }, val_sz, 0.5, bright_text);
                    } else {
                        rl.DrawTextEx(chat_font, "N/A", .{ .x = x + 65 * fs, .y = y }, val_sz, 0.5, dim_text);
                    }
                    y += line_h;

                    // Last response (truncated)
                    rl.DrawTextEx(chat_font, "Last:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    y += line_h;
                    if (g_chat_msg_count > 0) {
                        const last_idx = g_chat_msg_count - 1;
                        if (g_chat_msg_types[last_idx] == .ai) {
                            const trunc_len = @min(g_chat_msg_lens[last_idx], 60);
                            var last_buf: [64:0]u8 = undefined;
                            @memcpy(last_buf[0..trunc_len], g_chat_messages[last_idx][0..trunc_len]);
                            last_buf[trunc_len] = 0;
                            rl.DrawTextEx(chat_font, &last_buf, .{ .x = x, .y = y }, label_sz, 0.5, withAlpha(rl.Color{ .r = 180, .g = 200, .b = 180, .a = 255 }, alpha_u8));
                        }
                    }

                    // Realm glow: left edge
                    for (0..3) |gi| {
                        const glx: f32 = @as(f32, @floatFromInt(gi)) * 1.0;
                        const ga: u8 = @intFromFloat(@max(0, @min(40, @as(f32, @floatFromInt(alpha_u8)) * (0.15 - @as(f32, @floatFromInt(gi)) * 0.04))));
                        rl.DrawLine(@intFromFloat(glx), 0, @intFromFloat(glx), @intFromFloat(content_h), rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = ga });
                    }
                }

                // ── MATERIYA COLUMN (center) ──
                {
                    const x = col_w + 20 * fs;
                    var y: f32 = 25 * fs;
                    rl.DrawTextEx(chat_font, "MATERIYA", .{ .x = x, .y = y }, title_sz, 0.5, materiya_color);
                    y += title_sz + 4;
                    rl.DrawTextEx(chat_font, "Matter / System / Files", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    y += line_h + 8;

                    // FPS
                    rl.DrawTextEx(chat_font, "FPS:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var fps_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&fps_buf, "{d}", .{rl.GetFPS()}) catch {};
                    fps_buf[@min(15, std.mem.indexOfScalar(u8, &fps_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &fps_buf, .{ .x = x + 45 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;

                    // Engine
                    rl.DrawTextEx(chat_font, "Engine:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    const eng_str: [*:0]const u8 = if (g_hybrid_engine != null) "IglaHybrid v2.4" else "FluentChat";
                    rl.DrawTextEx(chat_font, eng_str, .{ .x = x + 65 * fs, .y = y }, val_sz, 0.5, materiya_color);
                    y += line_h;

                    // Tools
                    rl.DrawTextEx(chat_font, "Tools:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    const tools_on = g_hybrid_engine != null and g_hybrid_engine.?.config.enable_tools;
                    const t_str: [*:0]const u8 = if (tools_on) "enabled" else "disabled";
                    const t_col = if (tools_on) materiya_color else dim_text;
                    rl.DrawTextEx(chat_font, t_str, .{ .x = x + 55 * fs, .y = y }, val_sz, 0.5, t_col);
                    y += line_h;

                    // Memory load bar
                    rl.DrawTextEx(chat_font, "Memory:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var mem_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&mem_buf, "{d:.0}%", .{mws.memory_load * 100}) catch {};
                    mem_buf[@min(15, std.mem.indexOfScalar(u8, &mem_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &mem_buf, .{ .x = x + 70 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;
                    const mem_bar_w = col_w - 50 * fs;
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(mem_bar_w), 4, rl.Color{ .r = 40, .g = 40, .b = 50, .a = alpha_u8 });
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(mem_bar_w * mws.memory_load), 4, materiya_color);
                    y += 10;

                    // File count
                    if (!g_finder_scanned) scanDirectory();
                    rl.DrawTextEx(chat_font, "Files:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var f_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&f_buf, "{d} entries", .{g_finder_count}) catch {};
                    f_buf[@min(15, std.mem.indexOfScalar(u8, &f_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &f_buf, .{ .x = x + 55 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;

                    // TVC corpus
                    rl.DrawTextEx(chat_font, "TVC:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    rl.DrawTextEx(chat_font, "10000 max", .{ .x = x + 45 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;

                    // VSA dim
                    rl.DrawTextEx(chat_font, "VSA:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    rl.DrawTextEx(chat_font, "Active", .{ .x = x + 40 * fs, .y = y }, val_sz, 0.5, withAlpha(rl.Color{ .r = 0, .g = 255, .b = 150, .a = 255 }, alpha_u8));
                    y += line_h + 10;

                    // ── v2.8: RALPH MONITOR (multi-agent) ──
                    rl.DrawLine(@intFromFloat(x), @intFromFloat(y), @intFromFloat(x + col_w - 40 * fs), @intFromFloat(y), rl.Color{ .r = 80, .g = 80, .b = 100, .a = @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.5)) });
                    y += 10;
                    rl.DrawTextEx(chat_font, "RALPH MONITOR", .{ .x = x, .y = y }, title_sz * 0.8, 1.0, withAlpha(rl.Color{ .r = 0, .g = 200, .b = 255, .a = 255 }, alpha_u8));
                    y += title_sz + 4;

                    const mirror_agent = &g_ralph_agents[@min(g_ralph_active_tab, if (g_ralph_agent_count > 0) g_ralph_agent_count - 1 else 0)];

                    // Loop info
                    rl.DrawTextEx(chat_font, "Loop:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var l_buf: [16:0]u8 = undefined;
                    @memset(&l_buf, 0);
                    _ = std.fmt.bufPrint(&l_buf, "{d}", .{mirror_agent.loop}) catch {};
                    rl.DrawTextEx(chat_font, &l_buf, .{ .x = x + 40 * fs, .y = y }, val_sz, 0.5, bright_text);

                    rl.DrawTextEx(chat_font, "Calls:", .{ .x = x + 80 * fs, .y = y }, label_sz, 0.5, dim_text);
                    var tc_buf: [16:0]u8 = undefined;
                    @memset(&tc_buf, 0);
                    _ = std.fmt.bufPrint(&tc_buf, "{d}", .{mirror_agent.total_calls}) catch {};
                    rl.DrawTextEx(chat_font, &tc_buf, .{ .x = x + 125 * fs, .y = y }, val_sz, 0.5, razum_color);
                    y += line_h;

                    // Health (Circuit Breaker)
                    rl.DrawTextEx(chat_font, "Health:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    const h_col = if (mirror_agent.is_healthy) rl.Color{ .r = 0, .g = 255, .b = 150, .a = alpha_u8 } else rl.Color{ .r = 255, .g = 80, .b = 80, .a = alpha_u8 };
                    rl.DrawTextEx(chat_font, if (mirror_agent.is_healthy) "OPTIMAL" else "BREAK", .{ .x = x + 55 * fs, .y = y }, val_sz, 0.5, h_col);
                    y += line_h;

                    // Goal
                    rl.DrawTextEx(chat_font, "Goal:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    y += line_h;
                    rl.DrawTextEx(chat_font, &mirror_agent.goal, .{ .x = x, .y = y }, label_sz * 0.9, 0.5, withAlpha(rl.Color{ .r = 150, .g = 200, .b = 255, .a = 255 }, alpha_u8));
                    y += line_h + 4;

                    // Ralph Logs
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(col_w - 40 * fs), @intFromFloat(70 * fs), rl.Color{ .r = 20, .g = 20, .b = 30, .a = alpha_u8 });
                    var ly = y + 4;
                    for (0..mirror_agent.log_count) |i| {
                        rl.DrawTextEx(chat_font, &mirror_agent.logs[i], .{ .x = x + 4, .y = ly }, 10, 0.5, withAlpha(rl.Color{ .r = 100, .g = 150, .b = 200, .a = 255 }, alpha_u8));
                        ly += 12;
                    }
                    y += 80 * fs;

                    // Realm glow: center
                    for (0..3) |gi| {
                        const glx: f32 = col_w + @as(f32, @floatFromInt(gi)) * 1.0;
                        const ga: u8 = @intFromFloat(@max(0, @min(40, @as(f32, @floatFromInt(alpha_u8)) * (0.15 - @as(f32, @floatFromInt(gi)) * 0.04))));
                        rl.DrawLine(@intFromFloat(glx), 0, @intFromFloat(glx), @intFromFloat(content_h), rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ga });
                    }
                }

                // ── DUKH COLUMN (right) ──
                {
                    const x = col_w * 2 + 20 * fs;
                    var y: f32 = 25 * fs;
                    rl.DrawTextEx(chat_font, "DUKH", .{ .x = x, .y = y }, title_sz, 0.5, dukh_color);
                    y += title_sz + 4;
                    rl.DrawTextEx(chat_font, "Spirit / Knowledge", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    y += line_h + 8;

                    // Source hue (color bar)
                    rl.DrawTextEx(chat_font, "Source hue:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var h_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&h_buf, "{d:.0}", .{mws.source_hue}) catch {};
                    h_buf[@min(15, std.mem.indexOfScalar(u8, &h_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &h_buf, .{ .x = x + 100 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;
                    // Color bar showing source hue
                    const src_rgb = hsvToRgb(mws.source_hue, 0.8, 0.9);
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(col_w - 50 * fs), 6, rl.Color{ .r = src_rgb[0], .g = src_rgb[1], .b = src_rgb[2], .a = alpha_u8 });
                    y += 12;

                    // Reflection status
                    rl.DrawTextEx(chat_font, "Reflection:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    if (g_last_reflection_len > 0) {
                        rl.DrawTextEx(chat_font, &g_last_reflection_name, .{ .x = x + 100 * fs, .y = y }, val_sz, 0.5, dukh_color);
                    } else {
                        rl.DrawTextEx(chat_font, "N/A", .{ .x = x + 100 * fs, .y = y }, val_sz, 0.5, dim_text);
                    }
                    y += line_h;

                    // Learning indicator
                    rl.DrawTextEx(chat_font, "Learning:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    if (mws.is_learning) {
                        rl.DrawCircle(@intFromFloat(x + 85 * fs), @intFromFloat(y + 7), 5, rl.Color{ .r = 80, .g = 255, .b = 80, .a = alpha_u8 });
                        rl.DrawTextEx(chat_font, "ACTIVE", .{ .x = x + 95 * fs, .y = y }, val_sz, 0.5, rl.Color{ .r = 80, .g = 255, .b = 80, .a = alpha_u8 });
                    } else {
                        rl.DrawCircle(@intFromFloat(x + 85 * fs), @intFromFloat(y + 7), 5, rl.Color{ .r = 80, .g = 80, .b = 80, .a = alpha_u8 });
                        rl.DrawTextEx(chat_font, "idle", .{ .x = x + 95 * fs, .y = y }, val_sz, 0.5, dim_text);
                    }
                    y += line_h;

                    // Provider health bar
                    rl.DrawTextEx(chat_font, "Health:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var ph_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&ph_buf, "{d:.0}%", .{mws.provider_health_avg * 100}) catch {};
                    ph_buf[@min(15, std.mem.indexOfScalar(u8, &ph_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &ph_buf, .{ .x = x + 65 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;
                    const hp_bar_w = col_w - 50 * fs;
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(hp_bar_w), 4, rl.Color{ .r = 40, .g = 40, .b = 50, .a = alpha_u8 });
                    rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(hp_bar_w * mws.provider_health_avg), 4, dukh_color);
                    y += 12;

                    // Similarity
                    rl.DrawTextEx(chat_font, "Similarity:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var sim_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&sim_buf, "{d:.2}", .{mws.similarity}) catch {};
                    sim_buf[@min(15, std.mem.indexOfScalar(u8, &sim_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &sim_buf, .{ .x = x + 95 * fs, .y = y }, val_sz, 0.5, bright_text);
                    y += line_h;

                    // Latency
                    rl.DrawTextEx(chat_font, "Latency:", .{ .x = x, .y = y }, label_sz, 0.5, dim_text);
                    var lat_buf: [16:0]u8 = undefined;
                    _ = std.fmt.bufPrint(&lat_buf, "{d:.2}", .{mws.latency_normalized}) catch {};
                    lat_buf[@min(15, std.mem.indexOfScalar(u8, &lat_buf, 0) orelse 15)] = 0;
                    rl.DrawTextEx(chat_font, &lat_buf, .{ .x = x + 80 * fs, .y = y }, val_sz, 0.5, bright_text);

                    // Self-reflection pulsing ring
                    const ref_pulse = @sin(frame_time * 2.5) * 0.3 + 0.7;
                    const ref_r = 30.0 + ref_pulse * 10.0;
                    const ref_a: u8 = @intFromFloat(@max(0, @min(60, ref_pulse * @as(f32, @floatFromInt(alpha_u8)) * 0.25)));
                    rl.DrawCircleLines(@intFromFloat(x + col_w * 0.35), @intFromFloat(content_h * 0.8), ref_r, rl.Color{ .r = 0xBD, .g = 0x93, .b = 0xF9, .a = ref_a });
                }

                // ── TRINITY RING (center intersection) ──
                {
                    const cx = sw / 2;
                    const cy = content_h * 0.85;
                    const ring_base = 15.0 + mws.confidence * 10.0;
                    const ring_pulse = @sin(frame_time * 1.5) * 3.0;
                    const ra: u8 = @intFromFloat(@max(0, @min(50, @as(f32, @floatFromInt(alpha_u8)) * 0.2)));
                    // Gold ring
                    rl.DrawCircleLines(@intFromFloat(cx - 10), @intFromFloat(cy), ring_base + ring_pulse, rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = ra });
                    // Cyan ring
                    rl.DrawCircleLines(@intFromFloat(cx + 10), @intFromFloat(cy), ring_base + ring_pulse, rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = ra });
                    // Purple ring
                    rl.DrawCircleLines(@intFromFloat(cx), @intFromFloat(cy - 12), ring_base + ring_pulse, rl.Color{ .r = 0xBD, .g = 0x93, .b = 0xF9, .a = ra });
                }

                // ── LIVE LOG STRIP (bottom) ──
                {
                    const log_y_start = content_h + 5;
                    const log_line_h: f32 = 15 * fs;
                    // Dark background
                    rl.DrawRectangle(0, @intFromFloat(content_h), @intFromFloat(sw), @intFromFloat(log_h), rl.Color{ .r = 10, .g = 10, .b = 15, .a = @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.7)) });
                    rl.DrawTextEx(chat_font, "LIVE LOG", .{ .x = 10, .y = log_y_start }, label_sz, 0.5, withAlpha(MUTED_GRAY, @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.6))));

                    // Show last N log entries that fit
                    const max_visible: usize = @min(g_live_log_count, 7);
                    const start_idx = if (g_live_log_count > max_visible) g_live_log_count - max_visible else 0;
                    var li: usize = 0;
                    while (li < max_visible) : (li += 1) {
                        const idx = start_idx + li;
                        const ly = log_y_start + 18 * fs + @as(f32, @floatFromInt(li)) * log_line_h;
                        // Source color dot
                        const src_hue = g_live_log_hues[idx];
                        const dot_rgb = hsvToRgb(src_hue, 0.8, 0.9);
                        rl.DrawCircle(@intFromFloat(@as(f32, 15)), @intFromFloat(ly + 6), 3, rl.Color{ .r = dot_rgb[0], .g = dot_rgb[1], .b = dot_rgb[2], .a = alpha_u8 });
                        // Log text
                        rl.DrawTextEx(chat_font, &g_live_log_text[idx], .{ .x = 25, .y = ly }, 12 * fs, 0.5, withAlpha(rl.Color{ .r = 170, .g = 180, .b = 190, .a = 255 }, alpha_u8));
                    }

                    if (g_live_log_count == 0) {
                        rl.DrawTextEx(chat_font, "Send a message in Chat (Shift+1) to see logs here", .{ .x = 25, .y = log_y_start + 20 * fs }, 12 * fs, 0.5, dim_text);
                    }
                }
            }
        } // end: if (g_wave_mode != .depin and g_wave_mode != .ralph) — skip other renderers in DePIN mode

        // === DePIN NODE WAVE FIELD === (v2.4: Docker node management)
        if (g_wave_mode == .depin) {
            // Opaque black background — clean slate
            rl.DrawRectangle(0, 0, @intFromFloat(sw), @intFromFloat(sh), rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 });
            const margin: f32 = 40 * fs;
            const line_h: f32 = 28 * fs;
            const title_sz: f32 = 28 * fs;
            const subtitle_sz: f32 = 16 * fs;
            const label_sz: f32 = 14 * fs;
            const val_sz: f32 = 16 * fs;
            const col_w = (sw - margin * 3) / 2;

            const depin_green = rl.Color{ .r = 0x50, .g = 0xFA, .b = 0x50, .a = alpha_u8 };
            const depin_yellow = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = alpha_u8 };
            const depin_red = rl.Color{ .r = 0xFF, .g = 0x55, .b = 0x55, .a = alpha_u8 };
            const dim_text = withAlpha(MUTED_GRAY, alpha_u8);
            const bright_text = withAlpha(rl.Color{ .r = 220, .g = 220, .b = 230, .a = 255 }, alpha_u8);

            var y: f32 = 30 * fs;

            // Title
            rl.DrawTextEx(chat_font, "TRINITY DePIN NODE", .{ .x = margin, .y = y }, title_sz, 0.5, mode_color);
            y += title_sz + 4;
            rl.DrawTextEx(chat_font, "Earn $TRI for VSA compute & storage", .{ .x = margin, .y = y }, subtitle_sz, 0.5, dim_text);
            y += line_h + 10;

            // Status indicator
            {
                const status_color = if (g_depin_running) depin_green else if (g_depin_docker_ok) depin_yellow else depin_red;
                const status_text: [*:0]const u8 = if (g_depin_running) "RUNNING" else if (g_depin_docker_ok) "STOPPED" else "NO DOCKER";

                // Pulsing status dot
                const pulse = if (g_depin_running) @sin(frame_time * 3.0) * 0.3 + 0.7 else 0.5;
                const dot_a: u8 = @intFromFloat(@max(60, @min(255, pulse * @as(f32, @floatFromInt(alpha_u8)))));
                rl.DrawCircle(@intFromFloat(margin + 8), @intFromFloat(y + 10), 6, rl.Color{ .r = status_color.r, .g = status_color.g, .b = status_color.b, .a = dot_a });

                rl.DrawTextEx(chat_font, "Status:", .{ .x = margin + 22, .y = y }, label_sz, 0.5, dim_text);
                rl.DrawTextEx(chat_font, status_text, .{ .x = margin + 80 * fs, .y = y }, val_sz, 0.5, status_color);
                y += line_h;

                // Uptime bar (if running)
                if (g_depin_running) {
                    const bar_w = col_w;
                    const bar_fill = @min(1.0, g_depin_uptime_hours / 24.0); // Scale to 24h
                    rl.DrawRectangle(@intFromFloat(margin), @intFromFloat(y), @intFromFloat(bar_w), 6, rl.Color{ .r = 40, .g = 40, .b = 50, .a = alpha_u8 });
                    rl.DrawRectangle(@intFromFloat(margin), @intFromFloat(y), @intFromFloat(bar_w * bar_fill), 6, depin_green);
                    y += 14;
                }
            }

            y += 10;

            // Separator
            rl.DrawLine(@intFromFloat(margin), @intFromFloat(y), @intFromFloat(sw - margin), @intFromFloat(y), rl.Color{ .r = 80, .g = 80, .b = 100, .a = @as(u8, @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.3)) });
            y += 15;

            // Two columns: EARNINGS | INFRASTRUCTURE
            const col1_x = margin;
            const col2_x = margin + col_w + margin;
            var y1 = y;
            var y2 = y;

            // Column 1: EARNINGS
            rl.DrawTextEx(chat_font, "EARNINGS", .{ .x = col1_x, .y = y1 }, subtitle_sz, 0.5, depin_yellow);
            y1 += subtitle_sz + 8;

            // Earned
            rl.DrawTextEx(chat_font, "Earned:", .{ .x = col1_x, .y = y1 }, label_sz, 0.5, dim_text);
            var earned_buf: [24:0]u8 = undefined;
            _ = std.fmt.bufPrint(&earned_buf, "{d:.6} TRI", .{g_depin_earned_tri}) catch {};
            earned_buf[@min(23, std.mem.indexOfScalar(u8, &earned_buf, 0) orelse 23)] = 0;
            rl.DrawTextEx(chat_font, &earned_buf, .{ .x = col1_x + 80 * fs, .y = y1 }, val_sz, 0.5, depin_yellow);
            y1 += line_h;

            // Pending
            rl.DrawTextEx(chat_font, "Pending:", .{ .x = col1_x, .y = y1 }, label_sz, 0.5, dim_text);
            var pending_buf: [24:0]u8 = undefined;
            _ = std.fmt.bufPrint(&pending_buf, "{d:.6} TRI", .{g_depin_pending_tri}) catch {};
            pending_buf[@min(23, std.mem.indexOfScalar(u8, &pending_buf, 0) orelse 23)] = 0;
            rl.DrawTextEx(chat_font, &pending_buf, .{ .x = col1_x + 80 * fs, .y = y1 }, val_sz, 0.5, bright_text);
            y1 += line_h;

            // Operations
            rl.DrawTextEx(chat_font, "Ops:", .{ .x = col1_x, .y = y1 }, label_sz, 0.5, dim_text);
            var ops_buf: [16:0]u8 = undefined;
            _ = std.fmt.bufPrint(&ops_buf, "{d}", .{g_depin_operations}) catch {};
            ops_buf[@min(15, std.mem.indexOfScalar(u8, &ops_buf, 0) orelse 15)] = 0;
            rl.DrawTextEx(chat_font, &ops_buf, .{ .x = col1_x + 80 * fs, .y = y1 }, val_sz, 0.5, bright_text);
            y1 += line_h;

            // Column 2: INFRASTRUCTURE
            rl.DrawTextEx(chat_font, "INFRASTRUCTURE", .{ .x = col2_x, .y = y2 }, subtitle_sz, 0.5, withAlpha(rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = 255 }, alpha_u8));
            y2 += subtitle_sz + 8;

            // Peers
            rl.DrawTextEx(chat_font, "Peers:", .{ .x = col2_x, .y = y2 }, label_sz, 0.5, dim_text);
            var peers_buf: [16:0]u8 = undefined;
            _ = std.fmt.bufPrint(&peers_buf, "{d}", .{g_depin_peers}) catch {};
            peers_buf[@min(15, std.mem.indexOfScalar(u8, &peers_buf, 0) orelse 15)] = 0;
            rl.DrawTextEx(chat_font, &peers_buf, .{ .x = col2_x + 100 * fs, .y = y2 }, val_sz, 0.5, bright_text);
            y2 += line_h;

            // Shards
            rl.DrawTextEx(chat_font, "Shards:", .{ .x = col2_x, .y = y2 }, label_sz, 0.5, dim_text);
            var shards_buf: [16:0]u8 = undefined;
            _ = std.fmt.bufPrint(&shards_buf, "{d}", .{g_depin_shards}) catch {};
            shards_buf[@min(15, std.mem.indexOfScalar(u8, &shards_buf, 0) orelse 15)] = 0;
            rl.DrawTextEx(chat_font, &shards_buf, .{ .x = col2_x + 100 * fs, .y = y2 }, val_sz, 0.5, bright_text);
            y2 += line_h;

            // Uptime
            rl.DrawTextEx(chat_font, "Uptime:", .{ .x = col2_x, .y = y2 }, label_sz, 0.5, dim_text);
            var uptime_buf: [16:0]u8 = undefined;
            _ = std.fmt.bufPrint(&uptime_buf, "{d:.1}h", .{g_depin_uptime_hours}) catch {};
            uptime_buf[@min(15, std.mem.indexOfScalar(u8, &uptime_buf, 0) orelse 15)] = 0;
            rl.DrawTextEx(chat_font, &uptime_buf, .{ .x = col2_x + 100 * fs, .y = y2 }, val_sz, 0.5, bright_text);
            y2 += line_h;

            // Buttons area
            const btn_y = @max(y1, y2) + 20;
            const btn_w: f32 = 180;
            const btn_h: f32 = 40;
            const btn_gap: f32 = 20;
            const btn_x_start = margin;

            // Start/Stop button
            {
                const btn_rect = rl.Rectangle{ .x = btn_x_start, .y = btn_y, .width = btn_w, .height = btn_h };
                const btn_label: [*:0]const u8 = if (g_depin_running) "Stop Node" else "Start Node";

                // Draw button manually (no raygui dependency)
                const btn_color = if (g_depin_running) depin_red else depin_green;
                const hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, btn_rect);
                const btn_bg_a: u8 = if (hover) @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.3) else @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.15);
                rl.DrawRectangleRec(btn_rect, rl.Color{ .r = btn_color.r, .g = btn_color.g, .b = btn_color.b, .a = btn_bg_a });
                rl.DrawRectangleLinesEx(btn_rect, 1, btn_color);
                rl.DrawTextEx(chat_font, btn_label, .{ .x = btn_x_start + 30, .y = btn_y + 10 }, val_sz, 0.5, btn_color);

                if (hover and mouse_pressed) {
                    if (g_depin_running) depinStopNode() else depinStartNode();
                }
            }

            // Claim Rewards button
            {
                const btn2_x = btn_x_start + btn_w + btn_gap;
                const btn_rect = rl.Rectangle{ .x = btn2_x, .y = btn_y, .width = btn_w, .height = btn_h };
                const hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, btn_rect);
                const btn_bg_a: u8 = if (hover) @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.3) else @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.15);
                rl.DrawRectangleRec(btn_rect, rl.Color{ .r = depin_yellow.r, .g = depin_yellow.g, .b = depin_yellow.b, .a = btn_bg_a });
                rl.DrawRectangleLinesEx(btn_rect, 1, depin_yellow);
                rl.DrawTextEx(chat_font, "Claim Rewards", .{ .x = btn2_x + 20, .y = btn_y + 10 }, val_sz, 0.5, depin_yellow);

                if (hover and mouse_pressed and g_depin_running) {
                    depinClaimRewards();
                }
            }

            // Dashboard button
            {
                const btn3_x = btn_x_start + (btn_w + btn_gap) * 2;
                const btn_rect = rl.Rectangle{ .x = btn3_x, .y = btn_y, .width = btn_w, .height = btn_h };
                const hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, btn_rect);
                const dash_color = withAlpha(rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = 255 }, alpha_u8);
                const btn_bg_a: u8 = if (hover) @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.3) else @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.15);
                rl.DrawRectangleRec(btn_rect, rl.Color{ .r = 0x50, .g = 0xFA, .b = 0xFA, .a = btn_bg_a });
                rl.DrawRectangleLinesEx(btn_rect, 1, dash_color);
                rl.DrawTextEx(chat_font, "Dashboard", .{ .x = btn3_x + 40, .y = btn_y + 10 }, val_sz, 0.5, dash_color);

                if (hover and mouse_pressed) {
                    rl.OpenURL("https://gHashTag.github.io/trinity/docs/depin");
                }
            }

            // Footer: contract address
            const footer_y = btn_y + btn_h + 30;
            rl.DrawTextEx(chat_font, "Contract: 0xef368e29...F9f469  \xc2\xb7  Sepolia Testnet", .{ .x = margin, .y = footer_y }, 13 * fs, 0.5, dim_text);

            // Docker not found warning
            if (!g_depin_docker_ok) {
                const warn_y = footer_y + line_h;
                rl.DrawTextEx(chat_font, "Docker not found. Install at docker.com to run a node.", .{ .x = margin, .y = warn_y }, label_sz, 0.5, depin_red);
            }
        }

        // === RALPH AUTONOMOUS MONITOR === (v3.0: Multi-agent tabbed panel — RALPH-CANVAS-005)
        if (g_wave_mode == .ralph) {
            if (!g_ralph_initialized) initRalphAgents();
            // Opaque background from theme (dark=black, light=light gray)
            const theme_bg: rl.Color = @bitCast(theme.bg);
            rl.DrawRectangle(0, 0, @intFromFloat(sw), @intFromFloat(sh), rl.Color{ .r = theme_bg.r, .g = theme_bg.g, .b = theme_bg.b, .a = 255 });
            const margin: f32 = 40 * fs;
            const line_h: f32 = 28 * fs;
            const title_sz: f32 = 28 * fs;
            const subtitle_sz: f32 = 16 * fs;

            // Ralph panel colors — from theme system (supports dark/light)
            const ralph_accent = withAlpha(@as(rl.Color, @bitCast(theme.text)), alpha_u8);
            const ralph_green = withAlpha(@as(rl.Color, @bitCast(theme.accents.success)), alpha_u8);
            const ralph_red = withAlpha(@as(rl.Color, @bitCast(theme.accents.error_)), alpha_u8);
            const ralph_card_bg_raw: rl.Color = @bitCast(theme.bg_panel);
            const ralph_card_bg = rl.Color{ .r = ralph_card_bg_raw.r, .g = ralph_card_bg_raw.g, .b = ralph_card_bg_raw.b, .a = 255 }; // force opaque
            const ralph_border = withAlpha(@as(rl.Color, @bitCast(theme.border)), alpha_u8);
            const dim_text = withAlpha(@as(rl.Color, @bitCast(theme.text_muted)), alpha_u8);
            const bright_text = withAlpha(@as(rl.Color, @bitCast(theme.text)), alpha_u8);

            // Tool call neon colors (cyberpunk palette)
            const tool_cyan = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = alpha_u8 }; // [Glob]
            const tool_magenta = rl.Color{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = alpha_u8 }; // [Read]
            const tool_yellow = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0x00, .a = alpha_u8 }; // [Grep]
            const tool_orange = rl.Color{ .r = 0xFF, .g = 0x66, .b = 0x00, .a = alpha_u8 }; // [Bash]
            const tool_lime = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x41, .a = alpha_u8 }; // [Write]
            const tool_pink = rl.Color{ .r = 0xFF, .g = 0x14, .b = 0x93, .a = alpha_u8 }; // [Edit]
            const tool_blue = rl.Color{ .r = 0x44, .g = 0x88, .b = 0xFF, .a = alpha_u8 }; // [TodoWrite]

            // ── v8.4: Configure raygui style with our theme colors ──
            // raygui uses packed 32-bit colors: 0xaabbggrr
            const bg_color = @as(c_int, @bitCast((@as(u32, ralph_card_bg.a) << 24) | (@as(u32, ralph_card_bg.b) << 16) | (@as(u32, ralph_card_bg.g) << 8) | @as(u32, ralph_card_bg.r)));
            const accent_color = @as(c_int, @bitCast((@as(u32, ralph_accent.a) << 24) | (@as(u32, ralph_accent.b) << 16) | (@as(u32, ralph_accent.g) << 8) | @as(u32, ralph_accent.r)));
            const border_color = @as(c_int, @bitCast((@as(u32, ralph_border.a) << 24) | (@as(u32, ralph_border.b) << 16) | (@as(u32, ralph_border.g) << 8) | @as(u32, ralph_border.r)));
            // DEFAULT control (applies to all controls including TabBar)
            rg.GuiSetStyle(0, 0, border_color); // BORDER_COLOR_NORMAL
            rg.GuiSetStyle(0, 1, bg_color); // BASE_COLOR_NORMAL
            rg.GuiSetStyle(0, 2, accent_color); // TEXT_COLOR_NORMAL
            // BUTTON control (2)
            rg.GuiSetStyle(2, 1, bg_color); // BASE_COLOR_NORMAL
            rg.GuiSetStyle(2, 7, @as(c_int, @bitCast(@as(u32, 0xff505060)))); // BASE_COLOR_PRESSED
            rg.GuiSetStyle(2, 2, accent_color); // TEXT_COLOR_NORMAL
            rg.GuiSetStyle(2, 0, border_color); // BORDER_COLOR_NORMAL
            // SCROLLBAR control (15)
            rg.GuiSetStyle(15, 0, border_color); // BORDER_COLOR_NORMAL
            rg.GuiSetStyle(15, 1, @as(c_int, @bitCast(@as(u32, 0xff404050)))); // BASE_COLOR_NORMAL

            var y: f32 = 30 * fs;

            // Title with pulsing dot
            const pulse_a: u8 = @intFromFloat(@max(100, @min(255, @sin(frame_time * 3.0) * 80 + 175)));
            rl.DrawCircle(@intFromFloat(margin + 10), @intFromFloat(y + 16), 6, withAlpha(@as(rl.Color, @bitCast(theme.text)), pulse_a));
            rl.DrawTextEx(chat_font, "RALPH AUTONOMOUS MONITOR", .{ .x = margin + 24, .y = y }, title_sz, 0.5, ralph_accent);
            y += title_sz + 4;
            rl.DrawTextEx(chat_font, "Real-time dev loop telemetry", .{ .x = margin + 24, .y = y }, subtitle_sz, 0.5, dim_text);
            y += line_h + 10;

            // ── v8.4: Agent Tab Bar with raygui (RALPH-CANVAS-005) ──
            {
                const tab_h: f32 = 36 * fs;
                const tabs_w = sw - margin * 2;

                // Prepare tab names for raygui
                var tab_names: [16][32:0]u8 = undefined;
                var name_ptrs: [16][*]const u8 = undefined;
                var ti: usize = 0;
                while (ti < g_ralph_agent_count) : (ti += 1) {
                    const tab_agent = &g_ralph_agents[ti];
                    @memset(&tab_names[ti], 0);
                    _ = std.fmt.bufPrint(&tab_names[ti], "{s} ({s})", .{ tab_agent.name, tab_agent.branch }) catch "Unknown";
                    name_ptrs[ti] = &tab_names[ti];
                }

                // raygui GuiTabBar signature: (bounds, text[*], count, active[*])
                var active_tab: c_int = @intCast(g_ralph_active_tab);
                _ = rg.GuiTabBar(.{ .x = margin, .y = y, .width = tabs_w, .height = tab_h }, @ptrCast(&name_ptrs), @intCast(g_ralph_agent_count), &active_tab);
                g_ralph_active_tab = @intCast(active_tab);
                y += tab_h + 8;
            }

            // Separator
            rl.DrawLine(@intFromFloat(margin), @intFromFloat(y), @intFromFloat(sw - margin), @intFromFloat(y), withAlpha(@as(rl.Color, @bitCast(theme.border)), @intFromFloat(@as(f32, @floatFromInt(alpha_u8)) * 0.5)));
            y += 10;

            // ── Active agent alias ──
            const agent = &g_ralph_agents[@min(g_ralph_active_tab, g_ralph_agent_count -| 1)];

            // Keyboard tab navigation (arrow keys + 1-4 without shift)
            {
                const shift_down = rl.IsKeyDown(rl.KEY_LEFT_SHIFT) or rl.IsKeyDown(rl.KEY_RIGHT_SHIFT);
                if (rl.IsKeyPressed(rl.KEY_LEFT) and g_ralph_active_tab > 0) {
                    g_ralph_active_tab -= 1;
                }
                if (rl.IsKeyPressed(rl.KEY_RIGHT) and g_ralph_active_tab < g_ralph_agent_count -| 1) {
                    g_ralph_active_tab += 1;
                }
                if (!shift_down) {
                    if (rl.IsKeyPressed(rl.KEY_ONE) and g_ralph_agent_count > 0) g_ralph_active_tab = 0;
                    if (rl.IsKeyPressed(rl.KEY_TWO) and g_ralph_agent_count > 1) g_ralph_active_tab = 1;
                    if (rl.IsKeyPressed(rl.KEY_THREE) and g_ralph_agent_count > 2) g_ralph_active_tab = 2;
                    if (rl.IsKeyPressed(rl.KEY_FOUR) and g_ralph_agent_count > 3) g_ralph_active_tab = 3;
                }
            }

            // Scroll smoothing (lerp) — unified chat scroll
            {
                const ralph_dt = rl.GetFrameTime();
                g_ralph_chat_scroll_y += (g_ralph_chat_scroll_target - g_ralph_chat_scroll_y) * @min(1.0, 8.0 * ralph_dt);
            }

            // v8.1: Section collapse animation update
            {
                const sec_dt = rl.GetFrameTime();
                const ai_anim = g_ralph_active_tab;
                if (ai_anim < g_ralph_agent_count) {
                    const ag = &g_ralph_agents[ai_anim];
                    var smi: usize = 0;
                    while (smi < ag.chat_count) : (smi += 1) {
                        if (ag.chat_msgs[smi].kind == .claude_result) {
                            const cur_rlen = ag.chat_msgs[smi].result_len;
                            if (cur_rlen != g_ralph_msg_prev_rlen[ai_anim][smi]) {
                                g_ralph_msg_prev_rlen[ai_anim][smi] = cur_rlen;
                                for (&g_ralph_section_collapsed[ai_anim][smi]) |*v| v.* = false;
                                for (&g_ralph_section_anim[ai_anim][smi]) |*v| v.* = 1.0;
                                ag.chat_msgs[smi].show_full = false;
                            }
                        }
                        var ssi: usize = 0;
                        while (ssi < MAX_SECTIONS_PER_MSG) : (ssi += 1) {
                            const tgt: f32 = if (g_ralph_section_collapsed[ai_anim][smi][ssi]) 0.0 else 1.0;
                            const cur = g_ralph_section_anim[ai_anim][smi][ssi];
                            var nv = cur + (tgt - cur) * @min(1.0, 5.0 * sec_dt);
                            if (nv < 0.01) nv = 0.0;
                            if (nv > 0.99) nv = 1.0;
                            g_ralph_section_anim[ai_anim][smi][ssi] = nv;
                        }
                    }
                }
            }

            // Reset scroll on tab switch
            if (g_ralph_active_tab != g_ralph_prev_tab) {
                g_ralph_chat_scroll_y = 0;
                g_ralph_chat_scroll_target = 0;
                g_ralph_prev_tab = g_ralph_active_tab;
            }

            // ═══ v8.0: UNIFIED AGENT CHAT DIALOG ═══
            const full_w = sw - margin * 2;
            const content_w = @min(full_w, 720 * fs); // Grok-style narrow chat
            const content_x_offset = (full_w - content_w) / 2; // Center offset
            const cx = margin + content_x_offset;
            const pane_top = y;
            const pane_bottom = sh - 32 * fs;

            {
                var ly = pane_top;

                // ── Header Bar: CB Alert + Task + Buttons + Status Pill ──
                // CB Alert banner
                if (agent.cb_state == .cb_open) {
                    const alert_h: f32 = 28 * fs;
                    const cb_pulse: u8 = @intFromFloat(180.0 + 60.0 * @sin(frame_time * 4.0));
                    rl.DrawRectangleRounded(.{ .x = cx, .y = ly, .width = content_w, .height = alert_h }, 0.1, 8, rl.Color{ .r = 0xFF, .g = 0x00, .b = 0x33, .a = cb_pulse / 4 });
                    rl.DrawTextEx(chat_font, "CIRCUIT BREAKER OPEN — Agent paused", .{ .x = cx + 12, .y = ly + 6 }, 14 * fs, 0.5, rl.Color{ .r = 0xFF, .g = 0x33, .b = 0x66, .a = cb_pulse });
                    ly += alert_h + 4;
                } else if (agent.cb_state == .degraded) {
                    const alert_h: f32 = 24 * fs;
                    rl.DrawRectangleRounded(.{ .x = cx, .y = ly, .width = content_w, .height = alert_h }, 0.1, 8, rl.Color{ .r = 0xFF, .g = 0xAA, .b = 0x00, .a = 30 });
                    rl.DrawTextEx(chat_font, "DEGRADED — reduced rate", .{ .x = cx + 12, .y = ly + 4 }, 13 * fs, 0.5, rl.Color{ .r = 0xFF, .g = 0xAA, .b = 0x00, .a = alpha_u8 });
                    ly += alert_h + 4;
                }

                // Task bar + buttons + status pill
                {
                    const bar_h: f32 = 36 * fs;
                    rl.DrawRectangleRoundedLines(.{ .x = cx, .y = ly, .width = content_w, .height = bar_h }, 0.06, 8, rl.Color{ .r = 0x22, .g = 0x22, .b = 0x28, .a = 120 });

                    // Task text (left side, clipped)
                    const task_w = content_w * 0.42;
                    rl.BeginScissorMode(@intFromFloat(cx + 10), @intFromFloat(ly), @intFromFloat(task_w), @intFromFloat(bar_h));
                    rl.DrawTextEx(chat_font, &agent.goal, .{ .x = cx + 12, .y = ly + 10 * fs }, 12 * fs, 0.5, bright_text);
                    rl.EndScissorMode();

                    // Buttons (center)
                    const btn_section_x = cx + task_w + 16;
                    const btn_w: f32 = 70 * fs;
                    const btn_h: f32 = 24 * fs;
                    const btn_y_pos = ly + (bar_h - btn_h) / 2;
                    const btn_gap: f32 = 8;

                    // Hotkey: K = Kill/STOP all ralph processes (emergency stop)
                    if (rl.IsKeyPressed(rl.KEY_K)) {
                        g_ralph_pending_cmd = .stop;
                        ralphExecPendingCmd();
                    }

                    // START
                    {
                        const bx = btn_section_x;
                        const br = rl.Rectangle{ .x = bx, .y = btn_y_pos, .width = btn_w, .height = btn_h };
                        const hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, br);
                        const active = !agent.running;
                        const c = if (active) ralph_green else dim_text;
                        const bg_a: u8 = if (hover and active) 40 else 15;
                        rl.DrawRectangleRounded(br, 0.3, 8, rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = bg_a });
                        rl.DrawRectangleRoundedLines(br, 0.3, 8, c);
                        const start_sz = rl.MeasureTextEx(chat_font, "START", 12 * fs, 0.5);
                        rl.DrawTextEx(chat_font, "START", .{ .x = bx + (btn_w - start_sz.x) / 2, .y = btn_y_pos + (btn_h - start_sz.y) / 2 }, 12 * fs, 0.5, c);
                        if (hover and mouse_pressed and active) {
                            g_ralph_pending_cmd = .start;
                            agent.running = true;
                            agent.is_healthy = true;
                            agent.cb_state = .closed;
                            ralphExecPendingCmd();
                        }
                    }
                    // STOP
                    {
                        const bx = btn_section_x + btn_w + btn_gap;
                        const br = rl.Rectangle{ .x = bx, .y = btn_y_pos, .width = btn_w, .height = btn_h };
                        const hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, br);
                        // STOP is always clickable - check actual processes in handler
                        const c = ralph_red;
                        const bg_a: u8 = if (hover) 40 else 15;
                        rl.DrawRectangleRounded(br, 0.3, 8, rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = bg_a });
                        rl.DrawRectangleRoundedLines(br, 0.3, 8, c);
                        const stop_sz = rl.MeasureTextEx(chat_font, "STOP", 12 * fs, 0.5);
                        rl.DrawTextEx(chat_font, "STOP", .{ .x = bx + (btn_w - stop_sz.x) / 2, .y = btn_y_pos + (btn_h - stop_sz.y) / 2 }, 12 * fs, 0.5, c);
                        if (hover and mouse_pressed) {
                            g_ralph_pending_cmd = .stop;
                            ralphExecPendingCmd();
                        }
                    }
                    // RESTART
                    {
                        const bx = btn_section_x + (btn_w + btn_gap) * 2;
                        const br = rl.Rectangle{ .x = bx, .y = btn_y_pos, .width = btn_w + 10 * fs, .height = btn_h };
                        const hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, br);
                        const c = ralph_accent;
                        const bg_a: u8 = if (hover) 40 else 15;
                        rl.DrawRectangleRounded(br, 0.3, 8, rl.Color{ .r = c.r, .g = c.g, .b = c.b, .a = bg_a });
                        rl.DrawRectangleRoundedLines(br, 0.3, 8, c);
                        const rst_w = btn_w + 10 * fs;
                        const rst_sz = rl.MeasureTextEx(chat_font, "RESTART", 12 * fs, 0.5);
                        rl.DrawTextEx(chat_font, "RESTART", .{ .x = bx + (rst_w - rst_sz.x) / 2, .y = btn_y_pos + (btn_h - rst_sz.y) / 2 }, 12 * fs, 0.5, c);
                        if (hover and mouse_pressed) {
                            g_ralph_pending_cmd = .restart;
                            agent.running = true;
                            agent.is_healthy = true;
                            agent.cb_state = .closed;
                            ralphExecPendingCmd();
                        }
                    }

                    // v8.6: Glassmorphism STATUS pill (right side)
                    {
                        const pill_right = cx + content_w - 8;
                        const pill_w: f32 = 140 * fs;
                        const pill_x = pill_right - pill_w;
                        const pill_y = ly + (bar_h - 28 * fs) / 2;

                        // v8.6: Determine display state for glassmorphism pill
                        const actually_running = ralphProcessRunning();
                        const display_state: CircuitBreakerState = if (agent.rate_limited or agent.cb_state == .cb_open)
                            .cb_open
                        else if (agent.is_executing and actually_running)
                            .closed
                        else
                            .degraded;

                        drawStatusPill(pill_x, pill_y, display_state, fs, chat_font);

                        // v8.6: Loop counter text (small, after status pill)
                        var loop_buf: [32:0]u8 = undefined;
                        @memset(&loop_buf, 0);
                        _ = std.fmt.bufPrint(&loop_buf, "L#{d}", .{agent.loop}) catch {};
                        const loop_sz = rl.MeasureTextEx(chat_font, &loop_buf, 10 * fs, 0.5);
                        const loop_x = pill_x - loop_sz.x - 8;
                        rl.DrawTextEx(chat_font, &loop_buf, .{ .x = loop_x, .y = ly + 11 * fs }, 10 * fs, 0.5, dim_text);

                        // v8.6: LIVE indicator (pulsing dot) — only if actually running
                        if (actually_running and agent.is_executing and agent.data_age_seconds < 30) {
                            const live_pulse: u8 = @intFromFloat(180.0 + 75.0 * @sin(frame_time * 6.0));
                            const live_x = loop_x - 12;
                            rl.DrawCircle(@intFromFloat(live_x), @intFromFloat(ly + bar_h / 2), 3 * fs, rl.Color{ .r = 0xFF, .g = 0x00, .b = 0x00, .a = live_pulse });
                        }

                        // v8.6: Hover popover for full status (use pill_x as left edge)
                        const hover_rect_left = pill_x - 10;
                        const pill_rect = rl.Rectangle{ .x = hover_rect_left, .y = ly, .width = pill_right - hover_rect_left + 10, .height = bar_h };
                        const pill_hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, pill_rect);
                        if (pill_hover) {
                            // v8.6: Status label/color for popover
                            const sm_age = agent.data_age_seconds;
                            const st_label: [*:0]const u8 = if (agent.rate_limited)
                                "RATE LIMITED"
                            else if (agent.cb_state == .cb_open)
                                "ERROR"
                            else if (agent.is_executing and actually_running)
                                "ACTIVE"
                            else if (!actually_running)
                                "STOPPED"
                            else if (sm_age < 120)
                                "IDLE"
                            else if (sm_age < 1800)
                                "PAUSED"
                            else
                                "STOPPED";
                            const st_color = if (agent.rate_limited)
                                ralph_red
                            else if (agent.cb_state == .cb_open)
                                ralph_red
                            else if (agent.is_executing and actually_running)
                                ralph_green
                            else if (!actually_running)
                                ralph_red
                            else if (sm_age < 120)
                                ralph_accent
                            else
                                dim_text;

                            // Draw popover below the bar
                            const pop_x = cx + content_w - 200 * fs;
                            const pop_y = ly + bar_h + 4;
                            const pop_w: f32 = 195 * fs;
                            const pop_h: f32 = 120 * fs;
                            const pop_row: f32 = 15 * fs;
                            rl.DrawRectangleRounded(.{ .x = pop_x, .y = pop_y, .width = pop_w, .height = pop_h }, 0.08, 8, ralph_card_bg);
                            rl.DrawRectangleRoundedLines(.{ .x = pop_x, .y = pop_y, .width = pop_w, .height = pop_h }, 0.08, 8, ralph_border);
                            var py = pop_y + 8;
                            // Status
                            rl.DrawTextEx(chat_font, "Status:", .{ .x = pop_x + 8, .y = py }, 11 * fs, 0.5, dim_text);
                            rl.DrawTextEx(chat_font, st_label, .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, st_color);
                            py += pop_row;
                            // CB
                            rl.DrawTextEx(chat_font, "CB:", .{ .x = pop_x + 8, .y = py }, 11 * fs, 0.5, dim_text);
                            rl.DrawTextEx(chat_font, agent.cb_state.getLabel(), .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, agent.cb_state.getColor(alpha_u8));
                            py += pop_row;
                            // Calls
                            rl.DrawTextEx(chat_font, "Calls:", .{ .x = pop_x + 8, .y = py }, 11 * fs, 0.5, dim_text);
                            {
                                var cbuf2: [32:0]u8 = undefined;
                                @memset(&cbuf2, 0);
                                _ = std.fmt.bufPrint(&cbuf2, "{d}/{d}", .{ agent.calls_this_hour, agent.max_calls_hour }) catch {};
                                rl.DrawTextEx(chat_font, &cbuf2, .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, bright_text);
                            }
                            py += pop_row;
                            // Updated
                            rl.DrawTextEx(chat_font, "Updated:", .{ .x = pop_x + 8, .y = py }, 11 * fs, 0.5, dim_text);
                            {
                                var abuf2: [32:0]u8 = undefined;
                                @memset(&abuf2, 0);
                                if (sm_age <= 0) {
                                    _ = std.fmt.bufPrint(&abuf2, "now", .{}) catch {};
                                } else if (sm_age < 60) {
                                    _ = std.fmt.bufPrint(&abuf2, "{d}s ago", .{@as(u64, @intCast(sm_age))}) catch {};
                                } else if (sm_age < 3600) {
                                    _ = std.fmt.bufPrint(&abuf2, "{d}m ago", .{@as(u64, @intCast(@divFloor(sm_age, 60)))}) catch {};
                                } else {
                                    _ = std.fmt.bufPrint(&abuf2, "{d}h{d}m", .{ @as(u64, @intCast(@divFloor(sm_age, 3600))), @as(u64, @intCast(@mod(@divFloor(sm_age, 60), 60))) }) catch {};
                                }
                                const a_color2 = if (sm_age < 30) ralph_green else if (sm_age < 300) ralph_accent else ralph_red;
                                rl.DrawTextEx(chat_font, &abuf2, .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, a_color2);
                            }
                            py += pop_row;
                            // Progress
                            rl.DrawTextEx(chat_font, "Progress:", .{ .x = pop_x + 8, .y = py }, 11 * fs, 0.5, dim_text);
                            if (agent.progress_status_len > 0) {
                                var psbuf2: [32:0]u8 = undefined;
                                @memset(&psbuf2, 0);
                                const psl2 = @min(agent.progress_status_len, 31);
                                @memcpy(psbuf2[0..psl2], agent.progress_status[0..psl2]);
                                rl.DrawTextEx(chat_font, &psbuf2, .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, bright_text);
                            } else {
                                rl.DrawTextEx(chat_font, "—", .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, dim_text);
                            }
                            py += pop_row;
                            // Commits
                            rl.DrawTextEx(chat_font, "Commits:", .{ .x = pop_x + 8, .y = py }, 11 * fs, 0.5, dim_text);
                            if (agent.recent_commits_count > 0) {
                                var cmbuf2: [32:0]u8 = undefined;
                                @memset(&cmbuf2, 0);
                                _ = std.fmt.bufPrint(&cmbuf2, "{d} recent", .{agent.recent_commits_count}) catch {};
                                rl.DrawTextEx(chat_font, &cmbuf2, .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, ralph_green);
                            } else {
                                rl.DrawTextEx(chat_font, "—", .{ .x = pop_x + 70 * fs, .y = py }, 11 * fs, 0.5, dim_text);
                            }
                        }
                    }

                    ly += bar_h + 8;
                }

                // ── v8.6: Unified Chat Area with Glassmorphism ──
                const chat_top = ly;
                const chat_h = pane_bottom - chat_top;

                // v8.6: Glass card for chat area
                const chat_card = rl.Rectangle{ .x = cx, .y = chat_top, .width = content_w, .height = chat_h };
                drawGlassCard(chat_card, 12, GLASS_NEON_PURPLE);

                rl.BeginScissorMode(@intFromFloat(cx), @intFromFloat(chat_top), @intFromFloat(content_w), @intFromFloat(chat_h));

                const avatar_r: f32 = 14 * fs;
                const msg_font_sz: f32 = 13 * fs;
                const row_h: f32 = 22 * fs;
                const bubble_max_w = content_w * 0.65;

                var cy = chat_top + 8 - g_ralph_chat_scroll_y;

                if (agent.chat_count == 0) {
                    // Empty state
                    rl.DrawTextEx(chat_font, "Waiting for agent output...", .{ .x = cx + content_w / 2 - 100 * fs, .y = chat_top + chat_h / 2 - 10 }, 14 * fs, 0.5, dim_text);
                } else {
                    var mi: usize = 0;
                    while (mi < agent.chat_count) : (mi += 1) {
                        const msg = &agent.chat_msgs[mi];
                        if (cy > chat_top + chat_h + 100) break; // below visible

                        const is_first_in_run = (mi == 0) or (agent.chat_msgs[mi - 1].sender != msg.sender);

                        switch (msg.kind) {
                            .log_line => {
                                // v8.6: Left-aligned bubble for PHI (loop agent)
                                if (cy + row_h > chat_top and cy < chat_top + chat_h) {
                                    const tag_color = rl.Color{ .r = msg.tag_r, .g = msg.tag_g, .b = msg.tag_b, .a = alpha_u8 };

                                    // v8.6: Glass avatar for PHI (only on first msg in run)
                                    if (is_first_in_run) {
                                        const ax = cx + avatar_r + 8;
                                        const ay = cy + row_h / 2;
                                        drawAvatar(ax, ay, avatar_r, true, chat_font, fs);
                                    }

                                    // Message area (no background)
                                    const bubble_x = cx + avatar_r * 2 + 18;

                                    // Colored dot
                                    if (msg.tag_r != 0xBB or msg.tag_g != 0xBB or msg.tag_b != 0xBB) {
                                        rl.DrawCircle(@intFromFloat(bubble_x + 8), @intFromFloat(cy + row_h * 0.4), 3, tag_color);
                                    }

                                    // Text
                                    rl.DrawTextEx(chat_font, &msg.text, .{ .x = bubble_x + 16, .y = cy + 3 }, msg_font_sz, 0.5, tag_color);
                                }
                                cy += row_h;
                            },

                            .meta_info => {
                                // v8.6: Left-aligned metadata line (dim) for VIBEE
                                if (cy + row_h > chat_top and cy < chat_top + chat_h) {
                                    const tx = cx + avatar_r * 2 + 18;
                                    rl.DrawTextEx(chat_font, &msg.text, .{ .x = tx, .y = cy + 4 }, 11 * fs, 0.5, dim_text);

                                    // v8.6: Glass avatar for VIBEE on first
                                    if (is_first_in_run) {
                                        const ax = cx + avatar_r + 8;
                                        const ay = cy + row_h / 2;
                                        drawAvatar(ax, ay, avatar_r, false, chat_font, fs);
                                    }
                                }
                                cy += row_h;
                            },

                            .task_list => {
                                // v8.6: Left-aligned task card for VIBEE
                                const task_row_h: f32 = 16 * fs;
                                const card_h = @as(f32, @floatFromInt(agent.todo_count)) * task_row_h + 24;
                                const card_x = cx + avatar_r * 2 + 18;

                                if (cy + card_h > chat_top and cy < chat_top + chat_h) {
                                    // v8.6: Glass avatar for VIBEE on first
                                    if (is_first_in_run) {
                                        const ax = cx + avatar_r + 8;
                                        const ay = cy + 16;
                                        drawAvatar(ax, ay, avatar_r, false, chat_font, fs);
                                    }

                                    // Task card (no colored bg)

                                    // Header
                                    rl.DrawTextEx(chat_font, "TASKS", .{ .x = card_x + 10, .y = cy + 4 }, 11 * fs, 0.5, ralph_accent);

                                    // Items
                                    var ti: usize = 0;
                                    while (ti < agent.todo_count) : (ti += 1) {
                                        const ty_pos = cy + 20 + @as(f32, @floatFromInt(ti)) * task_row_h;
                                        if (ty_pos + task_row_h > chat_top + chat_h) break;
                                        const ts = agent.todo_statuses[ti];
                                        const ind: [*:0]const u8 = if (ts == 3) "+" else if (ts == 2) ">" else "o";
                                        const ind_c: rl.Color = if (ts == 3) ralph_green else if (ts == 2) tool_cyan else dim_text;
                                        const txt_c: rl.Color = if (ts == 3) dim_text else if (ts == 2) bright_text else dim_text;
                                        rl.DrawTextEx(chat_font, ind, .{ .x = card_x + 12, .y = ty_pos }, 11 * fs, 0.5, ind_c);
                                        rl.DrawTextEx(chat_font, &agent.todo_items[ti], .{ .x = card_x + 24, .y = ty_pos }, 11 * fs, 0.5, txt_c);
                                    }
                                }
                                cy += card_h + 4;
                            },

                            .claude_result => {
                                // Left-aligned markdown bubble
                                const bubble_w = bubble_max_w;
                                const bubble_x = cx + avatar_r * 2 + 18;

                                // v8.6: Glass avatar for VIBEE on first
                                if (is_first_in_run) {
                                    if (cy + row_h > chat_top and cy < chat_top + chat_h) {
                                        const ax = cx + avatar_r + 8;
                                        const ay = cy + avatar_r;
                                        drawAvatar(ax, ay, avatar_r, false, chat_font, fs);
                                    }
                                }

                                // Inline markdown rendering (from live_result)
                                if (msg.result_len > 0 and msg.result_offset + msg.result_len <= agent.live_result_len) {
                                    const result_text = agent.live_result[msg.result_offset .. msg.result_offset + msg.result_len];
                                    const text_color = if (agent.live_is_error) ralph_red else withAlpha(@as(rl.Color, @bitCast(theme.content_text)), alpha_u8);
                                    const base_font = msg_font_sz;
                                    const max_chars: usize = @intFromFloat(@max(20, (bubble_w - 32) / (7.5 * fs)));
                                    var pos: usize = 0;
                                    var in_code_block: bool = false;
                                    var consecutive_empty: u32 = 0;
                                    const ToolId = enum { none, bash, read, glob, grep, write, edit, todo };
                                    var prev_tool_id: ToolId = .none;
                                    var prev_tool_color: rl.Color = dim_text;
                                    var tool_run_count: u32 = 0;
                                    const row_h_md: f32 = 20 * fs;

                                    // v8.1: Collapsible section state
                                    var section_idx: usize = 0;
                                    var in_collapsed: bool = false;
                                    var sec_anim: f32 = 1.0;
                                    var visible_lines: u32 = 0;
                                    const ai_idx = g_ralph_active_tab;

                                    // Claude result area (no colored bg)

                                    while (pos < result_text.len) {
                                        const remaining = result_text[pos..];
                                        var line_end: usize = @min(remaining.len, max_chars);
                                        for (remaining[0..line_end], 0..) |c, ci| {
                                            if (c == '\\' and ci + 1 < line_end and remaining[ci + 1] == 'n') {
                                                line_end = ci;
                                                break;
                                            }
                                        }
                                        const line_data = remaining[0..line_end];

                                        var render_text = line_data;
                                        var line_color = text_color;
                                        var font_sz = base_font;
                                        var x_offset: f32 = 12;
                                        var extra_spacing: f32 = 0;
                                        var is_tool = false;
                                        var cur_tool_id: ToolId = .none;
                                        var is_separator = false;
                                        var draw_underline = false;
                                        var is_code = in_code_block;
                                        var is_header = false;

                                        if (line_data.len >= 3 and line_data[0] == '`' and line_data[1] == '`' and line_data[2] == '`') {
                                            in_code_block = !in_code_block;
                                            is_code = in_code_block;
                                            render_text = if (line_data.len > 3) line_data[3..] else "";
                                        } else if (in_code_block) {
                                            is_code = true;
                                        } else if (line_data.len >= 4 and line_data[0] == '#' and line_data[1] == '#' and line_data[2] == '#' and line_data[3] == ' ') {
                                            render_text = line_data[4..];
                                            font_sz = 16 * fs;
                                            line_color = tool_yellow;
                                            extra_spacing = 4;
                                            is_header = true;
                                        } else if (line_data.len >= 3 and line_data[0] == '#' and line_data[1] == '#' and line_data[2] == ' ') {
                                            render_text = line_data[3..];
                                            font_sz = 18 * fs;
                                            line_color = tool_magenta;
                                            draw_underline = true;
                                            extra_spacing = 6;
                                            is_header = true;
                                        } else if (line_data.len >= 2 and line_data[0] == '#' and line_data[1] == ' ') {
                                            render_text = line_data[2..];
                                            font_sz = 22 * fs;
                                            line_color = tool_cyan;
                                            draw_underline = true;
                                            extra_spacing = 8;
                                            is_header = true;
                                        } else if (line_data.len >= 3) {
                                            const is_pure_sep = blk: {
                                                for (line_data) |ch| {
                                                    if (ch != '-' and ch != '*' and ch != ' ') break :blk false;
                                                }
                                                break :blk true;
                                            };
                                            if (is_pure_sep) {
                                                is_separator = true;
                                            } else if (line_data.len >= 2 and (line_data[0] == '-' or line_data[0] == '*') and line_data[1] == ' ') {
                                                render_text = line_data[2..];
                                                x_offset = 28;
                                                line_color = text_color;
                                            } else {
                                                if (line_data.len > 4) {
                                                    if (containsBytes(line_data, "[Glob]")) {
                                                        line_color = tool_cyan;
                                                        is_tool = true;
                                                        cur_tool_id = .glob;
                                                    } else if (containsBytes(line_data, "[Read]")) {
                                                        line_color = tool_magenta;
                                                        is_tool = true;
                                                        cur_tool_id = .read;
                                                    } else if (containsBytes(line_data, "[Grep]")) {
                                                        line_color = tool_yellow;
                                                        is_tool = true;
                                                        cur_tool_id = .grep;
                                                    } else if (containsBytes(line_data, "[Bash]")) {
                                                        line_color = tool_orange;
                                                        is_tool = true;
                                                        cur_tool_id = .bash;
                                                    } else if (containsBytes(line_data, "[Write]")) {
                                                        line_color = tool_lime;
                                                        is_tool = true;
                                                        cur_tool_id = .write;
                                                    } else if (containsBytes(line_data, "[Edit]")) {
                                                        line_color = tool_pink;
                                                        is_tool = true;
                                                        cur_tool_id = .edit;
                                                    } else if (containsBytes(line_data, "[Todo]")) {
                                                        line_color = tool_blue;
                                                        is_tool = true;
                                                        cur_tool_id = .todo;
                                                    }
                                                }
                                                if (line_data.len > 4 and containsBytes(line_data, "**")) {
                                                    line_color = bright_text;
                                                }
                                            }
                                        } else if (line_data.len >= 2 and (line_data[0] == '-' or line_data[0] == '*') and line_data[1] == ' ') {
                                            render_text = line_data[2..];
                                            x_offset = 28;
                                            line_color = text_color;
                                        } else {
                                            if (line_data.len > 4 and containsBytes(line_data, "**")) {
                                                line_color = bright_text;
                                            }
                                        }

                                        if (is_tool) {
                                            if (std.mem.indexOfScalar(u8, render_text, '[')) |bracket_pos| {
                                                render_text = render_text[bracket_pos..];
                                            }
                                        }

                                        // Collapse empty lines
                                        if (render_text.len == 0 and !is_separator and !is_code) {
                                            consecutive_empty += 1;
                                            if (consecutive_empty > 1) {
                                                pos += line_end;
                                                if (pos < result_text.len and result_text[pos] == '\\' and pos + 1 < result_text.len and result_text[pos + 1] == 'n') pos += 2;
                                                continue;
                                            }
                                            cy += row_h_md * 0.25;
                                            pos += line_end;
                                            if (pos < result_text.len and result_text[pos] == '\\' and pos + 1 < result_text.len and result_text[pos + 1] == 'n') pos += 2;
                                            continue;
                                        }
                                        consecutive_empty = 0;

                                        // v8.1: Section collapse tracking
                                        if (is_header and section_idx < MAX_SECTIONS_PER_MSG) {
                                            in_collapsed = g_ralph_section_collapsed[ai_idx][mi][section_idx];
                                            sec_anim = g_ralph_section_anim[ai_idx][mi][section_idx];
                                        }

                                        // v8.1: Progressive disclosure (show more / show less)
                                        visible_lines += 1;
                                        if (!msg.show_full and visible_lines > 15 and !is_header) {
                                            if (visible_lines == 16) {
                                                if (cy + row_h_md > chat_top and cy < chat_top + chat_h) {
                                                    const sm_rect = rl.Rectangle{ .x = bubble_x + 12, .y = cy, .width = 120 * fs, .height = row_h_md };
                                                    const sm_hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, sm_rect);
                                                    const sm_color = if (sm_hover) tool_cyan else ralph_accent;
                                                    rl.DrawTextEx(chat_font, "Show more...", .{ .x = bubble_x + 12, .y = cy }, base_font, 0.5, sm_color);
                                                    if (sm_hover) rl.DrawRectangle(@intFromFloat(bubble_x + 12), @intFromFloat(cy + base_font + 1), @intFromFloat(80 * fs), 1, sm_color);
                                                    if (sm_hover and mouse_pressed) msg.show_full = true;
                                                }
                                                cy += row_h_md;
                                            }
                                            pos += line_end;
                                            if (pos < result_text.len and result_text[pos] == '\\' and pos + 1 < result_text.len and result_text[pos + 1] == 'n') pos += 2;
                                            continue;
                                        }

                                        // v8.1: Section collapse skip
                                        if (!is_header and in_collapsed and sec_anim < 0.01) {
                                            pos += line_end;
                                            if (pos < result_text.len and result_text[pos] == '\\' and pos + 1 < result_text.len and result_text[pos + 1] == 'n') pos += 2;
                                            continue;
                                        }

                                        // Tool grouping
                                        if (is_tool and cur_tool_id != .none) {
                                            if (cur_tool_id == prev_tool_id) {
                                                tool_run_count += 1;
                                                pos += line_end;
                                                if (pos < result_text.len and result_text[pos] == '\\' and pos + 1 < result_text.len and result_text[pos + 1] == 'n') pos += 2;
                                                continue;
                                            } else {
                                                if (tool_run_count > 1 and prev_tool_id != .none) {
                                                    if (cy + row_h_md > chat_top and cy < chat_top + chat_h) {
                                                        rl.DrawRectangle(@intFromFloat(bubble_x + 4), @intFromFloat(cy + 2), 3, @intFromFloat(row_h_md - 4), prev_tool_color);
                                                        var grp_buf: [48:0]u8 = undefined;
                                                        @memset(&grp_buf, 0);
                                                        _ = std.fmt.bufPrint(&grp_buf, "    ... (x{d} more)", .{tool_run_count}) catch {};
                                                        rl.DrawTextEx(chat_font, &grp_buf, .{ .x = bubble_x + 12, .y = cy }, base_font, 0.5, rl.Color{ .r = prev_tool_color.r, .g = prev_tool_color.g, .b = prev_tool_color.b, .a = 120 });
                                                    }
                                                    cy += row_h_md;
                                                }
                                                prev_tool_id = cur_tool_id;
                                                prev_tool_color = line_color;
                                                tool_run_count = 0;
                                            }
                                        } else {
                                            if (tool_run_count > 1 and prev_tool_id != .none) {
                                                if (cy + row_h_md > chat_top and cy < chat_top + chat_h) {
                                                    rl.DrawRectangle(@intFromFloat(bubble_x + 4), @intFromFloat(cy + 2), 3, @intFromFloat(row_h_md - 4), prev_tool_color);
                                                    var grp_buf2: [48:0]u8 = undefined;
                                                    @memset(&grp_buf2, 0);
                                                    _ = std.fmt.bufPrint(&grp_buf2, "    ... (x{d} more)", .{tool_run_count}) catch {};
                                                    rl.DrawTextEx(chat_font, &grp_buf2, .{ .x = bubble_x + 12, .y = cy }, base_font, 0.5, rl.Color{ .r = prev_tool_color.r, .g = prev_tool_color.g, .b = prev_tool_color.b, .a = 120 });
                                                }
                                                cy += row_h_md;
                                            }
                                            prev_tool_id = .none;
                                            tool_run_count = 0;
                                        }

                                        const md_row_h = row_h_md + extra_spacing;
                                        // v8.1: Animated height for collapsing content
                                        const effective_row_h = if (!is_header and sec_anim < 1.0 and sec_anim > 0.0) md_row_h * sec_anim else md_row_h;

                                        if (cy + effective_row_h > chat_top and cy < chat_top + chat_h) {
                                            // v8.1: Triangle indicator + click for headers
                                            if (is_header and section_idx < MAX_SECTIONS_PER_MSG) {
                                                const tri_x = bubble_x + 2;
                                                const tri_cy = cy + font_sz / 2;
                                                const tri_sz: f32 = 4 * fs;
                                                const tri_color = rl.Color{ .r = line_color.r, .g = line_color.g, .b = line_color.b, .a = 160 };
                                                if (in_collapsed) {
                                                    // Right-pointing triangle (collapsed)
                                                    rl.DrawTriangle(
                                                        .{ .x = tri_x, .y = tri_cy + tri_sz },
                                                        .{ .x = tri_x, .y = tri_cy - tri_sz },
                                                        .{ .x = tri_x + tri_sz * 1.5, .y = tri_cy },
                                                        tri_color,
                                                    );
                                                } else {
                                                    // Down-pointing triangle (expanded)
                                                    rl.DrawTriangle(
                                                        .{ .x = tri_x + tri_sz, .y = tri_cy - tri_sz * 0.5 },
                                                        .{ .x = tri_x - tri_sz * 0.5, .y = tri_cy - tri_sz * 0.5 },
                                                        .{ .x = tri_x + tri_sz * 0.25, .y = tri_cy + tri_sz },
                                                        tri_color,
                                                    );
                                                }
                                                // Click hitbox on header row
                                                const hdr_rect = rl.Rectangle{ .x = bubble_x, .y = cy, .width = bubble_w, .height = md_row_h };
                                                if (rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, hdr_rect) and mouse_pressed) {
                                                    g_ralph_section_collapsed[ai_idx][mi][section_idx] = !g_ralph_section_collapsed[ai_idx][mi][section_idx];
                                                    in_collapsed = g_ralph_section_collapsed[ai_idx][mi][section_idx];
                                                }
                                                // Left border on header
                                                rl.DrawRectangle(@intFromFloat(bubble_x), @intFromFloat(cy), 2, @intFromFloat(md_row_h), rl.Color{ .r = line_color.r, .g = line_color.g, .b = line_color.b, .a = 40 });
                                                section_idx += 1;
                                            }
                                            // v8.1: Section left border for content
                                            if (!is_header and section_idx > 0 and !is_tool and !is_separator) {
                                                rl.DrawRectangle(@intFromFloat(bubble_x), @intFromFloat(cy), 2, @intFromFloat(effective_row_h), rl.Color{ .r = 0x44, .g = 0x44, .b = 0x55, .a = 30 });
                                            }
                                            if (is_separator) {
                                                const sep_y = cy + md_row_h / 2;
                                                rl.DrawRectangle(@intFromFloat(bubble_x + 12), @intFromFloat(sep_y), @intFromFloat(bubble_w - 24), 1, rl.Color{ .r = 0x00, .g = 0xFF, .b = 0xFF, .a = 60 });
                                            } else if (render_text.len > 0) {
                                                if (is_code) {
                                                    rl.DrawRectangle(@intFromFloat(bubble_x + 8), @intFromFloat(cy), @intFromFloat(bubble_w - 16), @intFromFloat(md_row_h), rl.Color{ .r = 0x10, .g = 0x10, .b = 0x18, .a = 200 });
                                                    line_color = tool_lime;
                                                }
                                                // v8.6: Glassmorphism tool pill with emoji
                                                if (is_tool) {
                                                    const tool_name = switch (cur_tool_id) {
                                                        .glob => "Glob",
                                                        .read => "Read",
                                                        .grep => "Grep",
                                                        .bash => "Bash",
                                                        .write => "Write",
                                                        .edit => "Edit",
                                                        .todo => "Todo",
                                                        else => "Tool",
                                                    };
                                                    drawToolPill(bubble_x + 4, cy, tool_name, line_color, fs, chat_font);
                                                }
                                                if (x_offset > 12) {
                                                    rl.DrawCircle(@intFromFloat(bubble_x + 18), @intFromFloat(cy + font_sz / 2), 3, tool_cyan);
                                                }
                                                // Render text (strip ** and tool brackets)
                                                var md_buf: [128:0]u8 = undefined;
                                                @memset(&md_buf, 0);
                                                var stripped2: [128]u8 = undefined;
                                                var s2i: usize = 0;
                                                var r2i: usize = 0;

                                                // v8.6: Skip tool bracket [ToolName] at start
                                                if (is_tool and render_text.len > 0) {
                                                    // Skip past the bracket
                                                    if (std.mem.indexOfScalar(u8, render_text[r2i..], ']')) |close_bracket| {
                                                        r2i += close_bracket + 1;
                                                        // Skip trailing space if present
                                                        if (r2i < render_text.len and render_text[r2i] == ' ') r2i += 1;
                                                    }
                                                }

                                                // v8.6: Adjust text position after tool pill
                                                const text_x_offset = if (is_tool) 92 * fs else x_offset;

                                                while (r2i < render_text.len and s2i < 127) {
                                                    if (r2i + 1 < render_text.len and render_text[r2i] == '*' and render_text[r2i + 1] == '*') {
                                                        r2i += 2;
                                                    } else {
                                                        stripped2[s2i] = render_text[r2i];
                                                        s2i += 1;
                                                        r2i += 1;
                                                    }
                                                }
                                                const cl2 = @min(s2i, 127);
                                                @memcpy(md_buf[0..cl2], stripped2[0..cl2]);
                                                rl.DrawTextEx(chat_font, &md_buf, .{ .x = bubble_x + text_x_offset, .y = cy }, font_sz, 0.5, line_color);
                                                if (draw_underline) {
                                                    const uw2 = @min(bubble_w * 0.6, @as(f32, @floatFromInt(cl2)) * font_sz * 0.55);
                                                    rl.DrawRectangle(@intFromFloat(bubble_x + text_x_offset), @intFromFloat(cy + font_sz + 2), @intFromFloat(uw2), 2, rl.Color{ .r = line_color.r, .g = line_color.g, .b = line_color.b, .a = 80 });
                                                }
                                            }
                                        }
                                        cy += effective_row_h;
                                        pos += line_end;
                                        if (pos < result_text.len and result_text[pos] == '\\' and pos + 1 < result_text.len and result_text[pos + 1] == 'n') pos += 2;
                                    }
                                    // v8.1: "Show less" link
                                    if (msg.show_full and visible_lines > 15) {
                                        if (cy + row_h_md > chat_top and cy < chat_top + chat_h) {
                                            const sl_rect = rl.Rectangle{ .x = bubble_x + 12, .y = cy, .width = 100 * fs, .height = row_h_md };
                                            const sl_hover = rl.CheckCollisionPointRec(.{ .x = mx, .y = my }, sl_rect);
                                            const sl_color = if (sl_hover) tool_cyan else ralph_accent;
                                            rl.DrawTextEx(chat_font, "Show less", .{ .x = bubble_x + 12, .y = cy }, base_font, 0.5, sl_color);
                                            if (sl_hover) rl.DrawRectangle(@intFromFloat(bubble_x + 12), @intFromFloat(cy + base_font + 1), @intFromFloat(65 * fs), 1, sl_color);
                                            if (sl_hover and mouse_pressed) msg.show_full = false;
                                        }
                                        cy += row_h_md;
                                    }
                                } else {
                                    rl.DrawTextEx(chat_font, "Waiting for Claude output...", .{ .x = bubble_x + 12, .y = cy }, msg_font_sz, 0.5, dim_text);
                                    cy += row_h;
                                }
                            },
                        }
                    }
                }

                rl.EndScissorMode();

                // Scroll clamping + auto-scroll
                {
                    const total_chat_h = cy + g_ralph_chat_scroll_y - (chat_top + 8);
                    const max_scroll = @max(0.0, total_chat_h - chat_h + 16);
                    g_ralph_chat_scroll_target = @min(g_ralph_chat_scroll_target, max_scroll);
                    g_ralph_chat_scroll_target = @max(0.0, g_ralph_chat_scroll_target);
                    g_ralph_chat_scroll_y = @min(g_ralph_chat_scroll_y, max_scroll + 10 * fs);

                    // Auto-scroll on new content
                    if (agent.chat_count != g_ralph_prev_chat_count) {
                        if (g_ralph_chat_scroll_target >= max_scroll - 50 or g_ralph_prev_chat_count == 0) {
                            g_ralph_chat_scroll_target = max_scroll;
                        }
                        g_ralph_prev_chat_count = agent.chat_count;
                    }
                }

                // Mouse wheel
                {
                    const cmx = @as(f32, @floatFromInt(rl.GetMouseX()));
                    const cmy = @as(f32, @floatFromInt(rl.GetMouseY()));
                    if (cmx >= margin and cmx <= cx + content_w and cmy >= chat_top and cmy <= chat_top + chat_h) {
                        g_ralph_chat_scroll_target -= rl.GetMouseWheelMove() * 40.0 * fs;
                        g_ralph_chat_scroll_target = @max(0.0, g_ralph_chat_scroll_target);
                    }
                }

                // Stale data overlay
                if (agent.data_age_seconds > 300) {
                    const stale_y = pane_bottom - 30 * fs;
                    const blink_a: u8 = @intFromFloat(120.0 + 80.0 * @sin(frame_time * 3.0));
                    var stale_buf: [64:0]u8 = undefined;
                    @memset(&stale_buf, 0);
                    _ = std.fmt.bufPrint(&stale_buf, "Last activity: {d}m ago", .{@as(u64, @intCast(@divFloor(agent.data_age_seconds, 60)))}) catch {};
                    rl.DrawTextEx(chat_font, &stale_buf, .{ .x = cx + content_w / 2 - 80 * fs, .y = stale_y }, 12 * fs, 0.5, rl.Color{ .r = 0xFF, .g = 0x00, .b = 0xFF, .a = blink_a });
                }
            }

            // Keyboard hint at bottom
            rl.DrawTextEx(chat_font, "1-4: Agent  |  </>: Switch  |  Shift+9: Toggle  |  Shift+0: Home", .{ .x = margin, .y = sh - 28 * fs }, 11 * fs, 0.5, dim_text);
        }
    }

    // Legacy panels (hidden when wave mode active, kept for backward compat)
    if (g_wave_mode == .idle) {
        frame_panels.draw(frame_time, frame_font);
    }

    // Keyboard hint (minimal, top-left) — skip in DePIN for clean UI
    if (g_wave_mode == .idle) {
        rl.DrawTextEx(frame_font_small, "Shift+1 Chat | 2 Code | 3 Tools | 4 Settings | D DePIN | ESC", .{ .x = 10, .y = 10 }, 13, 1, withAlpha(TEXT_DIM, 180));
    } else if (g_wave_mode != .depin and g_wave_mode != .ralph) {
        rl.DrawTextEx(frame_font_small, "ESC = back | Shift+1-6 switch mode", .{ .x = 10, .y = 10 }, 13, 1, withAlpha(TEXT_DIM, 140));
    }

    // === SUN/MOON THEME TOGGLE (top-right, 20px from top) ===
    {
        const toggle_cx: f32 = @as(f32, @floatFromInt(g_width)) - 35;
        const toggle_cy: f32 = 30; // 20px margin from top + radius
        const toggle_r: f32 = 10;
        if (theme.isDark()) {
            // Crescent moon: white circle + bg-colored circle offset
            const moon_color = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 220 };
            rl.DrawCircle(@intFromFloat(toggle_cx), @intFromFloat(toggle_cy), toggle_r, moon_color);
            rl.DrawCircle(@intFromFloat(toggle_cx + 5), @intFromFloat(toggle_cy - 3), toggle_r - 1, @as(rl.Color, @bitCast(theme.clear_bg)));
        } else {
            // Sun: black on light theme (visible on white background)
            const sun_color = rl.Color{ .r = 0x1A, .g = 0x1A, .b = 0x1A, .a = 220 };
            rl.DrawCircle(@intFromFloat(toggle_cx), @intFromFloat(toggle_cy), toggle_r - 2, sun_color);
            var ray: usize = 0;
            while (ray < 8) : (ray += 1) {
                const angle = @as(f32, @floatFromInt(ray)) * (TAU / 8.0);
                const rx1 = toggle_cx + @cos(angle) * (toggle_r + 1);
                const ry1 = toggle_cy + @sin(angle) * (toggle_r + 1);
                const rx2 = toggle_cx + @cos(angle) * (toggle_r + 5);
                const ry2 = toggle_cy + @sin(angle) * (toggle_r + 5);
                rl.DrawLineEx(.{ .x = rx1, .y = ry1 }, .{ .x = rx2, .y = ry2 }, 1.5, sun_color);
            }
        }
    }

    // === STATUS BAR (Hyper terminal style, bottom) ===
    const status_bar_h: f32 = 24;
    const status_y: f32 = @as(f32, @floatFromInt(g_height)) - status_bar_h;

    // Status bar background (Hyper style)
    rl.DrawRectangle(0, @intFromFloat(status_y), g_width, @intFromFloat(status_bar_h), withAlpha(BG_SURFACE, 240));
    rl.DrawLine(0, @intFromFloat(status_y), g_width, @intFromFloat(status_y), BORDER_SUBTLE);

    // Get system stats (simulated with realistic values)
    const cpu_usage: f32 = 15.0 + @sin(frame_time * 0.5) * 10;
    const mem_used: f32 = 8.2 + @sin(frame_time * 0.3) * 0.5;
    _ = @as(f32, 16.0); // mem_total (unused in rainbow mode)
    const cpu_temp: f32 = 42.0 + @sin(frame_time * 0.7) * 5;
    const disk_used: f32 = 256.0;
    _ = @as(f32, 512.0); // disk_total (unused in rainbow mode)
    const net_down: f32 = 1.2 + @abs(@sin(frame_time * 0.8)) * 2;
    const net_up: f32 = 0.3 + @abs(@sin(frame_time * 0.6)) * 0.5;
    const processes: u32 = 234;
    const uptime_sec: u32 = @intFromFloat(frame_time);

    var stat_buf: [64:0]u8 = undefined;
    const sw = @as(f32, @floatFromInt(g_width));

    // Status bar text: rainbow on dark, dark text on light
    const stat_text_color = if (theme.isDark()) @as(?rl.Color, null) else TEXT_WHITE; // null = use per-stat color

    // Left: TRINITY label
    rl.DrawTextEx(frame_font_small, "TRINITY", .{ .x = 12, .y = status_y + 5 }, 13, 0.5, stat_text_color orelse HYPER_GREEN);

    // All stats aligned to RIGHT, close together
    const spacing: f32 = 75;
    var x_pos: f32 = sw - 12; // Start from right edge

    // Time (rightmost)
    var time_buf: [16:0]u8 = undefined;
    const display_time = @mod(@as(u32, @intFromFloat(frame_time)), 86400);
    const hours = display_time / 3600;
    const minutes = (display_time % 3600) / 60;
    const seconds = display_time % 60;
    _ = std.fmt.bufPrintZ(&time_buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch {};
    x_pos -= 70;
    rl.DrawTextEx(frame_font_small, &time_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_MAGENTA);

    // Uptime
    const up_hours = uptime_sec / 3600;
    const up_mins = (uptime_sec % 3600) / 60;
    _ = std.fmt.bufPrintZ(&stat_buf, "UP {d}h{d}m", .{ up_hours, up_mins }) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse PURPLE);

    // Processes
    _ = std.fmt.bufPrintZ(&stat_buf, "PROC {d}", .{processes}) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse BLUE);

    // NET
    _ = std.fmt.bufPrintZ(&stat_buf, "NET {d:.1}M", .{net_down + net_up}) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_CYAN);

    // DISK
    _ = std.fmt.bufPrintZ(&stat_buf, "DISK {d:.0}G", .{disk_used}) catch {};
    x_pos -= spacing + 10;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_GREEN);

    // TEMP
    _ = std.fmt.bufPrintZ(&stat_buf, "{d:.0}C", .{cpu_temp}) catch {};
    x_pos -= spacing - 30;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_YELLOW);

    // MEM
    _ = std.fmt.bufPrintZ(&stat_buf, "MEM {d:.1}G", .{mem_used}) catch {};
    x_pos -= spacing + 5;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse ORANGE);

    // CPU
    _ = std.fmt.bufPrintZ(&stat_buf, "CPU {d:.0}%", .{cpu_usage}) catch {};
    x_pos -= spacing;
    rl.DrawTextEx(frame_font_small, &stat_buf, .{ .x = x_pos, .y = status_y + 5 }, 12, 0.5, stat_text_color orelse HYPER_RED);
} // end updateDrawFrame

// Custom input box with font
fn drawInputBox(input: *const InputBuffer, font: rl.Font, time: f32) void {
    const box_y = g_height - 60;
    rl.DrawRectangle(0, box_y, g_width, 60, withAlpha(BG_INPUT, 220));

    if (!input.active) {
        rl.DrawTextEx(font, "Press C=Chat, G=Goal, X=Code", .{ .x = 20, .y = @floatFromInt(box_y + 18) }, 20, 1, MUTED_GRAY);
        return;
    }

    const label = switch (input.mode) {
        .chat => "CHAT> ",
        .goal => "GOAL> ",
        .code => "CODE> ",
    };

    // Label with bright color
    rl.DrawTextEx(font, label.ptr, .{ .x = 20, .y = @floatFromInt(box_y + 18) }, 22, 1, NEON_GREEN);

    // Text (sentinel-terminated array)
    var display_buf: [520:0]u8 = undefined;
    const display_len = @min(input.len, 500);
    @memcpy(display_buf[0..display_len], input.buffer[0..display_len]);

    // Cursor blink
    if (@mod(@as(u32, @intFromFloat(time * 3.0)), 2) == 0) {
        display_buf[display_len] = '_';
        display_buf[display_len + 1] = 0;
    } else {
        display_buf[display_len] = 0;
    }

    rl.DrawTextEx(font, &display_buf, .{ .x = 100, .y = @floatFromInt(box_y + 18) }, 22, 1, NOVA_WHITE);

    // Hint
    rl.DrawText("Enter=Send", g_width - 100, box_y + 22, 14, TEXT_HINT);
}

fn drawImmersiveGrid(grid: *photon.PhotonGrid, time: f32) void {
    for (0..grid.height) |y| {
        for (0..grid.width) |x| {
            const p = grid.get(x, y);

            if (@abs(p.amplitude) < 0.01) continue;

            const px: c_int = @intCast(x * @as(usize, @intCast(g_pixel_size)));
            const py: c_int = @intCast(y * @as(usize, @intCast(g_pixel_size)));

            const hue = @mod(p.hue + time * 20.0 + p.phase * 10.0, 360.0);
            const brightness = @min(1.0, @abs(p.amplitude));

            const rgb = hsvToRgb(hue, 0.8, brightness);
            const alpha: u8 = @intFromFloat(@min(255.0, @abs(p.amplitude) * 300.0));

            const color = rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = alpha };

            if (@abs(p.amplitude) > 0.5) {
                const glow_alpha: u8 = @intFromFloat(@min(100.0, @abs(p.amplitude) * 100.0));
                rl.DrawRectangle(px - 1, py - 1, g_pixel_size + 2, g_pixel_size + 2, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = glow_alpha });
            }

            rl.DrawRectangle(px, py, g_pixel_size - 1, g_pixel_size - 1, color);
        }
    }
}

fn drawPhotonCursor(x: f32, y: f32, hue: f32, time: f32) void {
    const px: c_int = @intFromFloat(x);
    const py: c_int = @intFromFloat(y);

    const rgb = hsvToRgb(hue, 1.0, 1.0);
    const pulse = (@sin(time * 5.0) + 1.0) * 0.5;

    rl.DrawCircle(px, py, 20 + pulse * 10, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 30 });
    rl.DrawCircle(px, py, 12 + pulse * 5, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 60 });
    rl.DrawCircleLines(px, py, 8 + pulse * 3, rl.Color{ .r = rgb[0], .g = rgb[1], .b = rgb[2], .a = 200 });
    rl.DrawCircleLines(px, py, 4 + pulse * 2, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
    rl.DrawCircle(px, py, 2, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

fn drawModeIndicator(mode: TrinityMode, time: f32) void {
    const label = switch (mode) {
        .idle => "EXPLORE",
        .chat => "CHAT",
        .code => "CODE",
        .vision => "VISION",
        .voice => "VOICE",
        .tools => "TOOLS",
        .autonomous => "AUTONOMOUS",
    };

    const color = switch (mode) {
        .idle => NEON_GREEN,
        .chat => NEON_CYAN,
        .code => NEON_PURPLE,
        .vision => NEON_MAGENTA,
        .voice => NEON_GOLD,
        .tools => NEON_CYAN,
        .autonomous => NEON_GOLD,
    };

    const alpha: u8 = @intFromFloat(150.0 + @sin(time * 2.0) * 50.0);
    const final_color = rl.Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };

    rl.DrawText(label.ptr, g_width - 150, 20, 24, final_color);
}

fn hsvToRgb(h: f32, s: f32, v: f32) [3]u8 {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;

    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    if (h < 60) {
        r = c;
        g = x;
    } else if (h < 120) {
        r = x;
        g = c;
    } else if (h < 180) {
        g = c;
        b = x;
    } else if (h < 240) {
        g = x;
        b = c;
    } else if (h < 300) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }

    return .{
        @intFromFloat((r + m) * 255.0),
        @intFromFloat((g + m) * 255.0),
        @intFromFloat((b + m) * 255.0),
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// v8.6: Aceternity Glassmorphism Helper Functions
// ─────────────────────────────────────────────────────────────────────────────

/// Draw a glassmorphism card with subtle glow and translucent background
fn drawGlassCard(bounds: rl.Rectangle, radius: f32, glow_color: rl.Color) void {
    // Subtle glow layer
    const glow_bounds = rl.Rectangle{ .x = bounds.x - 4, .y = bounds.y - 4, .width = bounds.width + 8, .height = bounds.height + 8 };
    rl.DrawRectangleRounded(glow_bounds, radius, 8, withAlpha(glow_color, 30));

    // Glass background (translucent)
    const glass_bg = rl.Color{ .r = 20, .g = 20, .b = 35, .a = 180 };
    rl.DrawRectangleRounded(bounds, radius, 8, glass_bg);

    // Neon border (top gradient)
    const border_top = rl.Rectangle{ .x = bounds.x, .y = bounds.y, .width = bounds.width, .height = 2 };
    rl.DrawRectangleRec(border_top, rl.Color{ .r = 0x88, .g = 0x44, .b = 0xFF, .a = 200 });
}

/// Draw a chat bubble for PHI (left) or VIBEE (right) messages
fn drawChatBubble(bounds: rl.Rectangle, is_phi: bool) void {
    const radius = 16.0;
    const bg_color = if (is_phi)
        rl.Color{ .r = 0x00, .g = 0x44, .b = 0x54, .a = 200 } // Cyan-dark
    else
        rl.Color{ .r = 0x54, .g = 0x00, .b = 0x54, .a = 200 }; // Purple-dark

    const accent = if (is_phi) GLASS_NEON_CYAN else GLASS_NEON_MAGENTA;

    // Shadow
    const shadow_bounds = rl.Rectangle{ .x = bounds.x + 4, .y = bounds.y + 4, .width = bounds.width, .height = bounds.height };
    rl.DrawRectangleRounded(shadow_bounds, radius, 8, withAlpha(accent, 50));

    // Background
    rl.DrawRectangleRounded(bounds, radius, 8, bg_color);

    // Accent strip (left for PHI, right for VIBEE)
    if (is_phi) {
        rl.DrawRectangleRec(.{ .x = bounds.x, .y = bounds.y, .width = 4, .height = bounds.height }, accent);
    } else {
        rl.DrawRectangleRec(.{ .x = bounds.x + bounds.width - 4, .y = bounds.y, .width = 4, .height = bounds.height }, accent);
    }
}

/// Draw a circular avatar with φ (PHI) or ψ (VIBEE) symbol
fn drawAvatar(center_x: f32, center_y: f32, radius: f32, is_phi: bool, font: rl.Font, fs: f32) void {
    const glow = if (is_phi) GLASS_NEON_CYAN else GLASS_NEON_MAGENTA;

    // v8.6: Glow ring (c_int for x,y, f32 for radius)
    const cx_int: c_int = @intFromFloat(center_x);
    const cy_int: c_int = @intFromFloat(center_y);
    rl.DrawCircle(cx_int, cy_int, radius + 4, withAlpha(glow, 60));

    // Main circle
    const circle_color = if (is_phi) rl.Color{ .r = 0x00, .g = 0x88, .b = 0x88, .a = 255 } else rl.Color{ .r = 0x88, .g = 0x00, .b = 0x88, .a = 255 };
    rl.DrawCircle(cx_int, cy_int, radius, circle_color);

    // Φ or Ψ symbol (v8.6: use .ptr for C string)
    const symbol = if (is_phi) "Φ" else "Ψ";
    const font_size = 14 * fs;
    const text_width = rl.MeasureTextEx(font, symbol.ptr, font_size, 0.5).x;
    rl.DrawTextEx(font, symbol.ptr, .{ .x = center_x - text_width / 2, .y = center_y - 10 * fs }, font_size, 0.5, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
}

/// Draw a tool pill with glass effect (v8.6: emoji icons)
fn drawToolPill(x: f32, y: f32, text: []const u8, tool_color: rl.Color, fs: f32, font: rl.Font) void {
    const pill_w: f32 = 80 * fs;
    const pill_h: f32 = 24 * fs;
    const radius = 12.0;

    // Glass background
    const bg = rl.Color{ .r = 20, .g = 20, .b = 35, .a = 200 };
    rl.DrawRectangleRounded(.{ .x = x, .y = y, .width = pill_w, .height = pill_h }, radius, 8, bg);

    // Accent strip (left side)
    rl.DrawRectangleRec(.{ .x = x, .y = y, .width = 4, .height = pill_h }, tool_color);

    // v8.6: Draw emoji icon using g_font_emoji
    const emoji_str = getToolEmoji(text);
    const emoji_size = 16 * fs;
    // Create null-terminated string for C FFI
    var emoji_buf: [8:0]u8 = undefined;
    @memset(&emoji_buf, 0);
    @memcpy(emoji_buf[0..emoji_str.len], emoji_str);
    rl.DrawTextEx(g_font_emoji, &emoji_buf, .{ .x = x + 10 * fs, .y = y + 4 * fs }, emoji_size, 0.5, tool_color);

    // Draw tool name (after emoji)
    var buf: [16:0]u8 = undefined;
    @memset(&buf, 0);
    const max_len = @min(text.len, 15);
    @memcpy(buf[0..max_len], text[0..max_len]);
    rl.DrawTextEx(font, &buf, .{ .x = x + 32, .y = y + 7 * fs }, 11 * fs, 0.5, rl.Color{ .r = 220, .g = 220, .b = 230, .a = 255 });
}

/// Get emoji icon for tool name (v8.6: UTF-8 emoji for display)
fn getToolEmoji(tool: []const u8) []const u8 {
    if (std.mem.eql(u8, tool, "Glob")) return "🔍"; // U+1F50D
    if (std.mem.eql(u8, tool, "Read")) return "📖"; // U+1F4F6
    if (std.mem.eql(u8, tool, "Grep")) return "🔎"; // U+1F50E
    if (std.mem.eql(u8, tool, "Bash")) return "⚡"; // U+26A1
    if (std.mem.eql(u8, tool, "Write")) return "✏️"; // U+270F
    if (std.mem.eql(u8, tool, "Edit")) return "🔄"; // U+1F504
    if (std.mem.eql(u8, tool, "Todo")) return "📋"; // U+1F4CB
    return "•";
}

/// Draw STATUS pill with pulsing dot and glass effect
fn drawStatusPill(x: f32, y: f32, status: CircuitBreakerState, fs: f32, font: rl.Font) void {
    const pill_w = 120 * fs;
    const pill_h = 32 * fs;

    // Glass background
    const glass_bg = rl.Color{ .r = 20, .g = 20, .b = 35, .a = 180 };
    rl.DrawRectangleRounded(.{ .x = x, .y = y, .width = pill_w, .height = pill_h }, 16, 8, glass_bg);

    // Status indicator (pulsing dot)
    const pulse = @as(u8, @intFromFloat(@max(150, @min(255, @sin(rl.GetTime() * 4) * 60 + 200))));
    const status_color = switch (status) {
        .closed => rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x66, .a = pulse }, // Green
        .degraded => rl.Color{ .r = 0xFF, .g = 0xAA, .b = 0x00, .a = pulse }, // Orange
        .cb_open => rl.Color{ .r = 0xFF, .g = 0x44, .b = 0x66, .a = pulse }, // Red
    };
    rl.DrawCircle(@intFromFloat(x + 20), @intFromFloat(y + pill_h / 2), 6, status_color);

    // Status text
    const status_text = switch (status) {
        .closed => "ONLINE",
        .degraded => "DEGRADED",
        .cb_open => "HALTED",
    };
    rl.DrawTextEx(font, status_text, .{ .x = x + 36, .y = y + 8 * fs }, 10 * fs, 0.5, rl.Color{ .r = 220, .g = 220, .b = 230, .a = 255 });
}

// ─────────────────────────────────────────────────────────────────────────────
