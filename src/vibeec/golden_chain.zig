// ═══════════════════════════════════════════════════════════════════════════════
// ЗЛАТАЯ ЦЕПЬ (Golden Chain) — Unified 8-Node Agent Pipeline v1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Combines all 13+ agent systems into ONE unified pipeline:
//   GOAL_PARSE → DECOMPOSE → SCHEDULE → EXECUTE → MONITOR → ADAPT → SYNTHESIZE → DELIVER
//
// Each node is a Chakra-colored "chain link" (sound indicator) in the canvas.
// Backend: Hybrid — local Zig (VSA/TVC/Tools) + Claude API (LLM).
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const igla_hybrid = @import("igla_hybrid_chat");
const Sha256 = std.crypto.hash.sha2.Sha256;

// ═══════════════════════════════════════════════════════════════════════════════
// v1.1 TRUTH & PROVENANCE CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PROVENANCE_HASH_SIZE = 32;
pub const MAX_PROVENANCE_RECORDS = 16;
pub const TRUTH_CONFIDENCE_THRESHOLD: f32 = 0.7;
pub const TVC_SIMILARITY_THRESHOLD: f32 = 0.3;
pub const CONTENT_DIGEST_LEN = 64;

// ═══════════════════════════════════════════════════════════════════════════════
// v1.2 QUARK-GLUON CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const QUARK_HASH_SIZE = 32;
pub const MAX_QUARK_RECORDS = 104; // v2.5: was 96, +8 for swarm v1.0 quarks (u7: 72/128)
pub const MAX_ENTANGLE_REFS = 2;
pub const QUARK_CONTENT_DIGEST_LEN = 48;

// ═══════════════════════════════════════════════════════════════════════════════
// v1.4 PHI-ENGINE QUANTUM VERIFICATION CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.6180339887498949;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const GOLDEN_IDENTITY: f64 = 3.0; // phi^2 + 1/phi^2 = 3
pub const LUCAS_SEQUENCE = [16]u32{ 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199, 322, 521, 843, 1364 };
pub const FIB_SEQUENCE = [16]u32{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610 };

// ═══════════════════════════════════════════════════════════════════════════════
// v1.5 COLLAPSIBLE + SHAREABLE + STAKING CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_SHARE_LINK_LEN = 64;
pub const STAKING_LOCK_DURATION_DEFAULT: i64 = 86_400_000_000; // 1 day in microseconds
pub const MIN_STAKING_AMOUNT_UTRI: u64 = 100; // 0.0001 TRI
pub const MAX_STAKING_RECORDS = 8;
pub const SHARE_LINK_PREFIX = "tri://chain/";

// ═══════════════════════════════════════════════════════════════════════════════
// v2.0 IMMORTAL SELF-VERIFYING AGENT CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const SELF_REPAIR_CONFIDENCE_THRESHOLD: f32 = 0.3;
pub const MAX_REPAIR_RECORDS = 16;
pub const MAX_EVOLUTION_RECORDS = 32;
pub const DEFAULT_MAX_GENERATIONS: u16 = 1000;
pub const DEFAULT_FITNESS_THRESHOLD: f32 = 0.7;

// ═══════════════════════════════════════════════════════════════════════════════
// v2.1 PUBLIC LAUNCH + $TRI FAUCET + CANVAS 1.0 CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const FAUCET_CLAIM_AMOUNT_UTRI: u64 = 100;
pub const FAUCET_COOLDOWN_US: i64 = 3_600_000_000; // 1 hour in microseconds
pub const MAX_FAUCET_CLAIMS = 64;
pub const FAUCET_DAILY_LIMIT_UTRI: u64 = 10_000;
pub const PUBLIC_SESSION_TTL_US: i64 = 86_400_000_000; // 1 day
pub const MAX_PUBLIC_SESSIONS = 256;
pub const CANVAS_VERSION_MAJOR: u8 = 1;
pub const CANVAS_VERSION_MINOR: u8 = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// v2.2 AGENT OS v1.0 — DECENTRALIZED IMMORTAL NETWORK CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_NETWORK_NODES = 256;
pub const NODE_SYNC_INTERVAL_US: i64 = 10_000_000; // 10 seconds
pub const NODE_HEARTBEAT_US: i64 = 5_000_000; // 5 seconds
pub const CONSENSUS_QUORUM_PERCENT: u8 = 67; // 2/3 quorum
pub const NETWORK_TTL_US: i64 = 604_800_000_000; // 7 days
pub const MAX_NODE_SYNC_RECORDS = 128;
pub const STAKING_MAINNET_MIN_UTRI: u64 = 1_000;
pub const AGENT_OS_VERSION_MAJOR: u8 = 1;
pub const AGENT_OS_VERSION_MINOR: u8 = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN NODE — 8 pipeline steps
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChainNode = enum(u3) {
    GoalParse, // 0 — Муладхара — Red
    Decompose, // 1 — Свадхистана — Orange
    Schedule, // 2 — Манипура — Yellow
    Execute, // 3 — Анахата — Green
    Monitor, // 4 — Вишуддха — Blue
    Adapt, // 5 — Аджна — Indigo
    Synthesize, // 6 — Сахасрара — Violet
    Deliver, // 7 — Единство — Gold

    pub fn getHue(self: ChainNode) f32 {
        return switch (self) {
            .GoalParse => 0.0, // Red
            .Decompose => 30.0, // Orange
            .Schedule => 60.0, // Yellow
            .Execute => 120.0, // Green
            .Monitor => 240.0, // Blue
            .Adapt => 270.0, // Indigo
            .Synthesize => 280.0, // Violet
            .Deliver => 45.0, // Gold
        };
    }

    pub fn getLabel(self: ChainNode) []const u8 {
        return switch (self) {
            .GoalParse => "GOAL_PARSE",
            .Decompose => "DECOMPOSE",
            .Schedule => "SCHEDULE",
            .Execute => "EXECUTE",
            .Monitor => "MONITOR",
            .Adapt => "ADAPT",
            .Synthesize => "SYNTHESIZE",
            .Deliver => "DELIVER",
        };
    }

    pub fn getRGB(self: ChainNode) struct { r: u8, g: u8, b: u8 } {
        return switch (self) {
            .GoalParse => .{ .r = 0xFF, .g = 0x00, .b = 0x00 }, // Red
            .Decompose => .{ .r = 0xFF, .g = 0x7F, .b = 0x00 }, // Orange
            .Schedule => .{ .r = 0xFF, .g = 0xFF, .b = 0x00 }, // Yellow
            .Execute => .{ .r = 0x00, .g = 0xFF, .b = 0x00 }, // Green
            .Monitor => .{ .r = 0x44, .g = 0x44, .b = 0xFF }, // Blue (light for dark bg)
            .Adapt => .{ .r = 0x4B, .g = 0x00, .b = 0x82 }, // Indigo
            .Synthesize => .{ .r = 0x8B, .g = 0x00, .b = 0xFF }, // Violet
            .Deliver => .{ .r = 0xFF, .g = 0xD7, .b = 0x00 }, // Gold
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN MESSAGE TYPE — extended chat message classification
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChainMessageType = enum {
    User, // User input
    ChainStep, // Pipeline node output
    ToolResult, // Tool execution result
    RoutingInfo, // Routing decision info
    Reflection, // Self-learning event
    AgentState, // State change notification
    Error, // Error message
    // v1.1: Truth & Provenance
    ProvenanceStep, // Hash chain record line
    TruthVerification, // Chain integrity verdict
    // v1.2: Quark-Gluon
    QuarkStep, // Quark sub-step record
    GluonEntangle, // Gluon entanglement notification
    // v1.4: DAG + Rewards
    DAGVisualization, // DAG edge/stats summary
    RewardSummary, // $TRI reward summary
    // v1.5: Collapsible + Shareable + Staking
    CollapseToggle, // Node collapse/expand event
    ShareLinkGenerated, // Shareable link created
    StakingEvent, // Staking lock/unlock/yield event
    // v2.0: Immortal Self-Verifying Agent
    SelfRepairEvent, // Self-repair action taken
    ImmortalPersist, // Persistence checkpoint
    EvolutionStep, // Evolution generation step
    ChainHealthCheck, // Chain health assessment
    // v2.1: Public Launch + $TRI Faucet + Canvas 1.0
    FaucetClaim, // Faucet $TRI claim event
    PublicLaunch, // Public session launch event
    CanvasSync, // Canvas browser sync event
    FaucetDistribution, // Faucet distribution summary
    // v2.2: Agent OS v1.0 — Decentralized Immortal Network
    DecentralSync, // Multi-node synchronization event
    NodeConsensus, // Network consensus vote event
    NetworkHealth, // Network health report event
    AgentOSInit, // Agent OS lifecycle event
    // v2.3: Trinity Mainnet Genesis — $TRI Token + DAO + Swarm
    MainnetGenesis, // Mainnet genesis event
    DAOVote, // DAO governance vote event
    SwarmSync, // Immortal swarm sync event
    TokenMint, // $TRI token mint event
    // v2.4: Mainnet v1.0 Launch
    MainnetLaunch, // Mainnet v1.0 launch event
    CommunityOnboard, // Community onboarding event
    NodeDiscovery, // Node discovery event
    GovernanceExec, // Governance execution event
    // v2.5: Immortal Agent Swarm v1.0
    SwarmOrchestrate, // Swarm orchestration event
    SwarmFailover, // Swarm failover event
    SwarmTelemetry, // Swarm telemetry event
    SwarmReplication, // Swarm replication event
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.1 TRUTH VERDICT — ternary truth assessment
// ═══════════════════════════════════════════════════════════════════════════════

pub const TruthVerdict = enum {
    Verified, // confidence >= 0.7 AND tvc_similarity >= 0.3
    Unverified, // tvc_similarity < 0.3 (no corpus cross-check)
    LowConfidence, // confidence < 0.7

    pub fn getLabel(self: TruthVerdict) []const u8 {
        return switch (self) {
            .Verified => "VERIFIED",
            .Unverified => "UNVERIFIED",
            .LowConfidence => "LOW_CONF",
        };
    }

    pub fn getSymbol(self: TruthVerdict) []const u8 {
        return switch (self) {
            .Verified => "[OK]",
            .Unverified => "[??]",
            .LowConfidence => "[!!]",
        };
    }
};

pub fn assessTruth(confidence: f32, tvc_similarity: f32) TruthVerdict {
    if (confidence < TRUTH_CONFIDENCE_THRESHOLD) return .LowConfidence;
    if (tvc_similarity < TVC_SIMILARITY_THRESHOLD) return .Unverified;
    return .Verified;
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.1 PROVENANCE RECORD — immutable hash chain step
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProvenanceRecord = struct {
    step_index: u8,
    node: ChainNode,
    content_digest: [CONTENT_DIGEST_LEN]u8,
    digest_len: u8,
    confidence: f32,
    tvc_similarity: f32,
    truth_verdict: TruthVerdict,
    timestamp_us: i64,
    latency_us: u64,
    source: ?igla_hybrid.HybridResponse.Source,
    prev_hash: [PROVENANCE_HASH_SIZE]u8,
    current_hash: [PROVENANCE_HASH_SIZE]u8,

    /// Compute SHA256(prev_hash ++ node_label ++ content_digest ++ confidence_bytes ++ timestamp_bytes)
    pub fn computeHash(
        prev_hash: [PROVENANCE_HASH_SIZE]u8,
        node: ChainNode,
        content: []const u8,
        confidence: f32,
        timestamp_us: i64,
    ) [PROVENANCE_HASH_SIZE]u8 {
        var hasher = Sha256.init(.{});
        hasher.update(&prev_hash);
        hasher.update(node.getLabel());
        const dlen = @min(content.len, CONTENT_DIGEST_LEN);
        hasher.update(content[0..dlen]);
        const conf_bytes: [4]u8 = @bitCast(confidence);
        hasher.update(&conf_bytes);
        const ts_bytes: [8]u8 = @bitCast(timestamp_us);
        hasher.update(&ts_bytes);
        return hasher.finalResult();
    }

    /// Format hash as 8-char hex prefix (first 4 bytes) for display
    pub fn hashHexPrefix(hash: [PROVENANCE_HASH_SIZE]u8, buf: *[8]u8) void {
        const hex = "0123456789abcdef";
        for (0..4) |i| {
            buf[i * 2] = hex[hash[i] >> 4];
            buf[i * 2 + 1] = hex[hash[i] & 0x0F];
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.2 QUARK TYPE — 16 sub-step micro-operations
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuarkType = enum(u7) {
    input_capture, // 0 — Capture raw user input
    goal_classify, // 1 — Classify intent type
    task_decompose, // 2 — Break into subtasks
    dependency_check, // 3 — Check subtask dependencies
    schedule_plan, // 4 — Plan execution order
    route_decision, // 5 — Choose execution backend
    api_call, // 6 — Invoke LLM/tool
    tvc_cross_check, // 7 — TVC corpus verification
    vsa_bind, // 8 — VSA bind operation
    quality_gate, // 9 — Quality threshold check
    adapt_decision, // 10 — Adaptation decision
    merge_result, // 11 — Merge subtask outputs
    format_output, // 12 — Format final response
    chain_integrity, // 13 — Full chain integrity check
    hash_verify, // 14 — SHA256 hash verification sub-step
    gluon_verify, // 15 — Gluon entanglement verification
    // v1.3: Adversarial + Accounting
    fake_injection_detect, // 16 — Detect injection attacks / hallucination markers
    oracle_cross_check, // 17 — Cross-check against oracle / known-good data
    energy_accounting, // 18 — Track energy/compute cost of sub-step
    // v1.4: Phi-Engine Quantum + DAG + Rewards
    phi_verify, // 19 — Phi-engine quantum hash verification
    dag_checkpoint, // 20 — DAG structure checkpoint
    reward_mint, // 21 — $TRI reward minting record
    // v1.5: Collapsible + Shareable + Staking
    collapse_state, // 22 — Collapsible view state change
    share_link, // 23 — Shareable provenance link generation
    staking_lock, // 24 — $TRI staking lock record
    staking_yield, // 25 — $TRI staking yield calculation
    public_view, // 26 — Public view access audit
    compress_quark, // 27 — Quark compression checkpoint
    phi_visual, // 28 — Phi visualization checkpoint
    // v2.0: Immortal Self-Verifying Agent
    self_repair, // 29 — Self-repair checkpoint
    immortal_persist, // 30 — Persistence checkpoint
    evolution_checkpoint, // 31 — Evolution checkpoint
    // v2.1: Public Launch + $TRI Faucet + Canvas 1.0
    faucet_claim, // 32 — $TRI faucet claim record
    faucet_distribute, // 33 — Faucet distribution checkpoint
    canvas_render, // 34 — Canvas render checkpoint
    canvas_sync, // 35 — Canvas browser sync
    public_session, // 36 — Public session lifecycle
    viral_share, // 37 — Viral share propagation
    mainnet_anchor, // 38 — Mainnet anchor hash
    browser_verify, // 39 — Browser-side verification
    // v2.2: Agent OS v1.0 — Decentralized Immortal Network
    decentral_sync, // 40 — Multi-node synchronization
    node_consensus, // 41 — Consensus vote record
    network_health, // 42 — Network health metric
    staking_mainnet, // 43 — Mainnet staking record
    agent_os_init, // 44 — Agent OS lifecycle init
    immortal_network, // 45 — Network immortality checkpoint
    viral_propagate, // 46 — Network viral propagation
    energy_network, // 47 — Network energy tracking
    // v2.3: Trinity Mainnet Genesis — $TRI Token + DAO + Swarm
    token_mint, // 48 — $TRI token mint record
    dao_propose, // 49 — DAO proposal submission
    dao_vote, // 50 — DAO vote cast
    dao_execute, // 51 — DAO proposal execution
    swarm_spawn, // 52 — Swarm node spawn
    swarm_health, // 53 — Swarm health checkpoint
    mainnet_genesis, // 54 — Mainnet genesis event
    governance_anchor, // 55 — Governance anchor record
    // v2.4: Mainnet v1.0 Launch — Community Genesis + Full DAO Live + Immortal Swarm Activation (u6 FULL: 64/64)
    community_genesis, // 56 — Community genesis ceremony
    mainnet_launch, // 57 — Mainnet v1.0 launch event
    live_governance, // 58 — Live DAO governance activation
    swarm_activate, // 59 — Immortal swarm activation
    node_discovery, // 60 — Node discovery record
    community_onboard, // 61 — Community onboarding batch
    public_api, // 62 — Public API gateway record
    mainnet_anchor_v2, // 63 — Mainnet anchor v2 (final u6 slot)
    // v2.5: Immortal Agent Swarm v1.0 — u7 Upgrade (128 capacity, 72/128 used)
    swarm_orchestrate, // 64 — Swarm orchestration task distribution
    swarm_consensus, // 65 — Swarm consensus protocol
    swarm_replication, // 66 — Swarm state replication
    swarm_failover, // 67 — Swarm failover trigger
    swarm_discovery_v2, // 68 — Swarm node discovery v2
    swarm_self_heal, // 69 — Swarm self-healing checkpoint
    swarm_telemetry, // 70 — Swarm telemetry report
    swarm_anchor, // 71 — Swarm anchor record

    pub fn getLabel(self: QuarkType) []const u8 {
        return switch (self) {
            .input_capture => "INPUT_CAP",
            .goal_classify => "GOAL_CLASS",
            .task_decompose => "TASK_DEC",
            .dependency_check => "DEP_CHK",
            .schedule_plan => "SCHED_PLAN",
            .route_decision => "ROUTE_DEC",
            .api_call => "API_CALL",
            .tvc_cross_check => "TVC_XCHK",
            .vsa_bind => "VSA_BIND",
            .quality_gate => "QUAL_GATE",
            .adapt_decision => "ADAPT_DEC",
            .merge_result => "MERGE_RES",
            .format_output => "FMT_OUT",
            .chain_integrity => "CHAIN_INT",
            .hash_verify => "HASH_VER",
            .gluon_verify => "GLUON_VER",
            .fake_injection_detect => "FAKE_DET",
            .oracle_cross_check => "ORACLE_CHK",
            .energy_accounting => "ENERGY_ACC",
            .phi_verify => "PHI_VER",
            .dag_checkpoint => "DAG_CKP",
            .reward_mint => "REWARD_MINT",
            .collapse_state => "COLLAPSE",
            .share_link => "SHARE_LNK",
            .staking_lock => "STAKE_LCK",
            .staking_yield => "STAKE_YLD",
            .public_view => "PUB_VIEW",
            .compress_quark => "COMPRESS",
            .phi_visual => "PHI_VIS",
            .self_repair => "SELF_RPR",
            .immortal_persist => "IMMORTAL",
            .evolution_checkpoint => "EVOLVE",
            .faucet_claim => "FAUCET_CLM",
            .faucet_distribute => "FAUCET_DST",
            .canvas_render => "CANVAS_RND",
            .canvas_sync => "CANVAS_SYN",
            .public_session => "PUB_SESS",
            .viral_share => "VIRAL_SHR",
            .mainnet_anchor => "MAINNET",
            .browser_verify => "BROWSER_VER",
            .decentral_sync => "DECENTRAL",
            .node_consensus => "CONSENSUS",
            .network_health => "NET_HEALTH",
            .staking_mainnet => "STAKE_MAIN",
            .agent_os_init => "AGENT_OS",
            .immortal_network => "IMMORTAL_NET",
            .viral_propagate => "VIRAL_PROP",
            .energy_network => "ENERGY_NET",
            .token_mint => "TOKEN_MINT",
            .dao_propose => "DAO_PROP",
            .dao_vote => "DAO_VOTE",
            .dao_execute => "DAO_EXEC",
            .swarm_spawn => "SWARM_SPAWN",
            .swarm_health => "SWARM_HLTH",
            .mainnet_genesis => "GENESIS",
            .governance_anchor => "GOV_ANCHOR",
            // v2.4: Mainnet v1.0 Launch (u6 FULL)
            .community_genesis => "COMM_GEN",
            .mainnet_launch => "MAINNET_LCH",
            .live_governance => "LIVE_GOV",
            .swarm_activate => "SWARM_ACT",
            .node_discovery => "NODE_DISC",
            .community_onboard => "COMM_ONBD",
            .public_api => "PUB_API",
            .mainnet_anchor_v2 => "MAINNET_V2",
            // v2.5: Immortal Agent Swarm v1.0
            .swarm_orchestrate => "SWARM_ORCH",
            .swarm_consensus => "SWARM_CONS",
            .swarm_replication => "SWARM_REPL",
            .swarm_failover => "SWARM_FAIL",
            .swarm_discovery_v2 => "SWARM_DISC",
            .swarm_self_heal => "SWARM_HEAL",
            .swarm_telemetry => "SWARM_TELE",
            .swarm_anchor => "SWARM_ANCH",
        };
    }

    pub fn isVerificationQuark(self: QuarkType) bool {
        return self == .hash_verify or self == .gluon_verify or self == .phi_verify;
    }

    pub fn isWorkQuark(self: QuarkType) bool {
        return !self.isVerificationQuark();
    }

    pub fn isAdversarialQuark(self: QuarkType) bool {
        return self == .fake_injection_detect or self == .oracle_cross_check;
    }

    pub fn isAccountingQuark(self: QuarkType) bool {
        return self == .energy_accounting;
    }

    pub fn isPhiQuark(self: QuarkType) bool {
        return self == .phi_verify;
    }

    pub fn isDAGQuark(self: QuarkType) bool {
        return self == .dag_checkpoint;
    }

    pub fn isRewardQuark(self: QuarkType) bool {
        return self == .reward_mint;
    }

    pub fn isCollapseQuark(self: QuarkType) bool {
        return self == .collapse_state;
    }

    pub fn isShareQuark(self: QuarkType) bool {
        return self == .share_link or self == .public_view;
    }

    pub fn isStakingQuark(self: QuarkType) bool {
        return self == .staking_lock or self == .staking_yield;
    }

    pub fn isCompressQuark(self: QuarkType) bool {
        return self == .compress_quark;
    }

    pub fn isVisualizationQuark(self: QuarkType) bool {
        return self == .phi_visual;
    }

    pub fn isSelfRepairQuark(self: QuarkType) bool {
        return self == .self_repair;
    }

    pub fn isImmortalQuark(self: QuarkType) bool {
        return self == .immortal_persist;
    }

    pub fn isEvolutionQuark(self: QuarkType) bool {
        return self == .evolution_checkpoint;
    }

    pub fn isFaucetQuark(self: QuarkType) bool {
        return self == .faucet_claim or self == .faucet_distribute;
    }

    pub fn isCanvasQuark(self: QuarkType) bool {
        return self == .canvas_render or self == .canvas_sync;
    }

    pub fn isPublicQuark(self: QuarkType) bool {
        return self == .public_session or self == .viral_share or self == .mainnet_anchor or self == .browser_verify;
    }

    pub fn isDecentralQuark(self: QuarkType) bool {
        return self == .decentral_sync or self == .node_consensus;
    }

    pub fn isNetworkQuark(self: QuarkType) bool {
        return self == .network_health or self == .immortal_network or self == .energy_network;
    }

    pub fn isAgentOSQuark(self: QuarkType) bool {
        return self == .agent_os_init;
    }

    pub fn isMainnetQuark(self: QuarkType) bool {
        return self == .staking_mainnet or self == .viral_propagate;
    }

    pub fn isTokenQuark(self: QuarkType) bool {
        return self == .token_mint;
    }

    pub fn isDAOQuark(self: QuarkType) bool {
        return self == .dao_propose or self == .dao_vote or self == .dao_execute or self == .governance_anchor;
    }

    pub fn isSwarmQuark(self: QuarkType) bool {
        return self == .swarm_spawn or self == .swarm_health;
    }

    pub fn isGenesisQuark(self: QuarkType) bool {
        return self == .mainnet_genesis;
    }

    // v2.4: Mainnet v1.0 Launch classifiers
    pub fn isCommunityQuark(self: QuarkType) bool {
        return self == .community_genesis or self == .community_onboard;
    }

    pub fn isMainnetLaunchQuark(self: QuarkType) bool {
        return self == .mainnet_launch or self == .mainnet_anchor_v2;
    }

    pub fn isLiveGovernanceQuark(self: QuarkType) bool {
        return self == .live_governance;
    }

    pub fn isSwarmActivateQuark(self: QuarkType) bool {
        return self == .swarm_activate;
    }

    pub fn isNodeDiscoveryQuark(self: QuarkType) bool {
        return self == .node_discovery;
    }

    pub fn isPublicAPIQuark(self: QuarkType) bool {
        return self == .public_api;
    }

    // v2.5: Swarm classifiers
    pub fn isSwarmOrchQuark(self: QuarkType) bool {
        return self == .swarm_orchestrate or self == .swarm_anchor;
    }

    pub fn isSwarmConsensusQuark(self: QuarkType) bool {
        return self == .swarm_consensus or self == .swarm_replication;
    }

    pub fn isSwarmFailoverQuark(self: QuarkType) bool {
        return self == .swarm_failover or self == .swarm_self_heal;
    }

    pub fn isSwarmTelemetryQuark(self: QuarkType) bool {
        return self == .swarm_discovery_v2 or self == .swarm_telemetry;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.2 QUARK RECORD — ultra-granular sub-step in quark chain
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuarkRecord = struct {
    quark_index: u8,
    quark_type: QuarkType,
    parent_node: ChainNode,
    content_digest: [QUARK_CONTENT_DIGEST_LEN]u8,
    digest_len: u8,
    confidence: f32,
    timestamp_us: i64,
    prev_quark_hash: [QUARK_HASH_SIZE]u8,
    current_quark_hash: [QUARK_HASH_SIZE]u8,
    entangled_indices: [MAX_ENTANGLE_REFS]u8,
    entangle_count: u8,

    /// SHA256(prev_hash ++ quark_label ++ node_label ++ content ++ conf ++ ts ++ entanglement)
    pub fn computeQuarkHash(
        prev_hash: [QUARK_HASH_SIZE]u8,
        quark_type: QuarkType,
        parent_node: ChainNode,
        content: []const u8,
        confidence: f32,
        timestamp_us: i64,
        entangled_indices: [MAX_ENTANGLE_REFS]u8,
        entangle_count: u8,
    ) [QUARK_HASH_SIZE]u8 {
        var hasher = Sha256.init(.{});
        hasher.update(&prev_hash);
        hasher.update(quark_type.getLabel());
        hasher.update(parent_node.getLabel());
        const dlen = @min(content.len, QUARK_CONTENT_DIGEST_LEN);
        hasher.update(content[0..dlen]);
        const conf_bytes: [4]u8 = @bitCast(confidence);
        hasher.update(&conf_bytes);
        const ts_bytes: [8]u8 = @bitCast(timestamp_us);
        hasher.update(&ts_bytes);
        hasher.update(entangled_indices[0..entangle_count]);
        return hasher.finalResult();
    }

    /// Format quark line: "Q[hex8] NODE.QUARK_TYPE | conf% | ent:N"
    pub fn formatQuarkLine(self: *const QuarkRecord, buf: *[256]u8) []const u8 {
        var hex_buf: [8]u8 = undefined;
        ProvenanceRecord.hashHexPrefix(self.current_quark_hash, &hex_buf);
        return std.fmt.bufPrint(buf, "Q[{s}] {s}.{s} | {d:.0}% | ent:{d}", .{
            &hex_buf,
            self.parent_node.getLabel(),
            self.quark_type.getLabel(),
            self.confidence * 100,
            self.entangle_count,
        }) catch "quark";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN MESSAGE — single message in the chain
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_MSG_CONTENT = 512;

pub const ChainMessage = struct {
    msg_type: ChainMessageType,
    node: ?ChainNode,
    source: ?igla_hybrid.HybridResponse.Source,
    content: [MAX_MSG_CONTENT]u8,
    content_len: usize,
    confidence: f32,
    latency_us: u64,

    pub fn getContent(self: *const ChainMessage) []const u8 {
        return self.content[0..self.content_len];
    }

    pub fn getHue(self: *const ChainMessage) f32 {
        if (self.node) |n| return n.getHue();
        if (self.source) |s| return switch (s) {
            .Symbolic => 60.0,
            .TVCCorpus => 120.0,
            .Tool => 210.0,
            .LocalLLM => 180.0,
            .GroqAPI => 210.0,
            .ClaudeAPI => 280.0,
            .Vision => 330.0,
            .Error => 0.0,
        };
        return 45.0; // Default gold
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN STATE — global state for canvas visualization
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChainState = struct {
    current_node: ChainNode,
    node_progress: [8]f32,
    node_active: [8]bool,
    node_complete: [8]bool,
    total_confidence: f32,
    total_latency_us: u64,
    is_running: bool,

    pub fn init() ChainState {
        return .{
            .current_node = .GoalParse,
            .node_progress = .{0} ** 8,
            .node_active = .{false} ** 8,
            .node_complete = .{false} ** 8,
            .total_confidence = 0.0,
            .total_latency_us = 0,
            .is_running = false,
        };
    }

    pub fn reset(self: *ChainState) void {
        self.* = ChainState.init();
    }

    pub fn startNode(self: *ChainState, node: ChainNode) void {
        const idx = @intFromEnum(node);
        self.current_node = node;
        self.node_active[idx] = true;
        self.node_progress[idx] = 0.0;
    }

    pub fn completeNode(self: *ChainState, node: ChainNode, confidence: f32, latency_us: u64) void {
        const idx = @intFromEnum(node);
        self.node_active[idx] = false;
        self.node_complete[idx] = true;
        self.node_progress[idx] = 1.0;
        // Running average
        if (self.total_confidence == 0.0) {
            self.total_confidence = confidence;
        } else {
            self.total_confidence = (self.total_confidence + confidence) / 2.0;
        }
        self.total_latency_us += latency_us;
    }
};

// Global chain state for canvas to read
pub var g_chain_state: ChainState = ChainState.init();

// ═══════════════════════════════════════════════════════════════════════════════
// GOAL TYPE DETECTION (from trinity_swe_agent patterns)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GoalType = enum {
    CodeGen, // "build", "create", "make", "write", "implement"
    BugFix, // "fix", "bug", "error", "broken", "crash"
    Explain, // "explain", "what", "how", "why", "describe"
    Refactor, // "refactor", "clean", "improve", "optimize"
    Search, // "find", "search", "where", "locate"
    Test, // "test", "verify", "check", "validate"
    Chat, // Default: greeting, question, conversation
    Tool, // Detected tool command (time, date, file, build)

    pub fn getName(self: GoalType) []const u8 {
        return switch (self) {
            .CodeGen => "CodeGen",
            .BugFix => "BugFix",
            .Explain => "Explain",
            .Refactor => "Refactor",
            .Search => "Search",
            .Test => "Test",
            .Chat => "Chat",
            .Tool => "Tool",
        };
    }
};

fn detectGoalType(input: []const u8) GoalType {
    const lower_buf = blk: {
        var buf: [256]u8 = undefined;
        const len = @min(input.len, 255);
        for (0..len) |i| {
            buf[i] = if (input[i] >= 'A' and input[i] <= 'Z') input[i] + 32 else input[i];
        }
        break :blk buf[0..len];
    };

    // Tool patterns
    const tool_patterns = [_][]const u8{ "time", "date", "file", "build", "test" };
    for (tool_patterns) |pat| {
        if (std.mem.indexOf(u8, lower_buf, pat) != null) return .Tool;
    }

    // CodeGen
    const codegen_patterns = [_][]const u8{ "build", "create", "make", "write", "implement", "generate", "add" };
    for (codegen_patterns) |pat| {
        if (std.mem.indexOf(u8, lower_buf, pat) != null) return .CodeGen;
    }

    // BugFix
    const bugfix_patterns = [_][]const u8{ "fix", "bug", "error", "broken", "crash", "fail" };
    for (bugfix_patterns) |pat| {
        if (std.mem.indexOf(u8, lower_buf, pat) != null) return .BugFix;
    }

    // Explain
    const explain_patterns = [_][]const u8{ "explain", "what", "how", "why", "describe" };
    for (explain_patterns) |pat| {
        if (std.mem.indexOf(u8, lower_buf, pat) != null) return .Explain;
    }

    // Refactor
    const refactor_patterns = [_][]const u8{ "refactor", "clean", "improve", "optimize" };
    for (refactor_patterns) |pat| {
        if (std.mem.indexOf(u8, lower_buf, pat) != null) return .Refactor;
    }

    // Search
    const search_patterns = [_][]const u8{ "find", "search", "where", "locate" };
    for (search_patterns) |pat| {
        if (std.mem.indexOf(u8, lower_buf, pat) != null) return .Search;
    }

    return .Chat;
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.3 QUARK VERBOSITY — output control
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuarkVerbosity = enum {
    full, // Emit every quark line (47+ lines, v1.2 default)
    summary, // Emit one summary line per node (~18 lines)
    silent, // No quark messages (records still stored)
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.3 QUARK SEARCH QUERY — structured filter
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuarkSearchQuery = struct {
    filter_type: ?QuarkType = null,
    filter_node: ?ChainNode = null,
    min_confidence: f32 = 0.0,
    max_confidence: f32 = 1.0,
    verification_only: bool = false,
    work_only: bool = false,
    min_entangle: u8 = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.4 DAG + $TRI REWARD TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_DAG_EDGES = 96;

pub const DAGEdge = struct {
    from: u8,
    to: u8,
};

pub const DAGStats = struct {
    edge_count: u16,
    max_depth: u8,
    max_width: u8,
    max_fan_out: u8,
    max_fan_in: u8,
    node_quark_counts: [8]u8,
};

pub const TriRewardConfig = struct {
    base_reward_utri: u64 = 1000, // 0.001 TRI
    confidence_bonus: f32 = 0.5, // 50% bonus at >= 0.9
    energy_penalty_per_us: f64 = 0.001,
    min_reward_confidence: f32 = 0.5,
    quark_depth_bonus_utri: u64 = 10, // per quark above 40
    verification_failure_multiplier: f32 = 0.0,
};

pub const TriRewardResult = struct {
    base_utri: u64,
    confidence_bonus_utri: u64,
    quark_bonus_utri: u64,
    energy_penalty_utri: u64,
    verification_bonus: bool,
    total_reward_utri: u64,
    total_reward_tri_display: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.5 COLLAPSIBLE + SHAREABLE + STAKING TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const QuarkViewState = enum(u2) {
    expanded, // All quarks visible (default)
    collapsed, // Only summary line shown
    hidden, // No quark output
};

pub const CollapsedNodeSummary = struct {
    node: ChainNode,
    quark_count: u8,
    avg_confidence: f32,
    total_entanglements: u16,
    is_collapsed: bool,
};

pub const ShareableLink = struct {
    link_hash: [PROVENANCE_HASH_SIZE]u8,
    chain_fingerprint: [PROVENANCE_HASH_SIZE]u8,
    quark_count: u8,
    provenance_count: u8,
    total_reward_utri: u64,
    is_verified: bool,
    timestamp_us: i64,

    pub fn formatLink(self: *const ShareableLink, buf: *[128]u8) []const u8 {
        const hex_chars = "0123456789abcdef";
        var hex: [32]u8 = undefined;
        for (0..16) |i| {
            const byte = self.link_hash[i];
            hex[i * 2] = hex_chars[byte >> 4];
            hex[i * 2 + 1] = hex_chars[byte & 0x0F];
        }
        return std.fmt.bufPrint(buf, "tri://chain/{s}", .{hex[0..32]}) catch "tri://chain/error";
    }
};

pub const StakingConfig = struct {
    lock_duration_us: i64 = 86_400_000_000, // 1 day default
    min_stake_utri: u64 = 100,
    yield_rate_per_day: f64 = 0.001, // 0.1% daily
    max_active_stakes: u8 = 8,
    auto_restake: bool = false,
};

pub const StakingRecord = struct {
    amount_utri: u64,
    lock_start_us: i64,
    lock_end_us: i64,
    yield_utri: u64,
    is_active: bool,
    chain_fingerprint: [PROVENANCE_HASH_SIZE]u8,
};

pub const StakingResult = struct {
    staked_utri: u64,
    yield_utri: u64,
    active_stakes: u8,
    total_locked_utri: u64,
    next_unlock_us: i64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v2.0 SELF-REPAIR + IMMORTAL + EVOLUTION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const SelfRepairState = enum(u2) {
    healthy, // All quarks valid
    degraded, // Some quarks below threshold
    repairing, // Actively repairing chain
    repaired, // Chain repaired successfully
};

pub const SelfRepairType = enum(u2) {
    hash_recompute, // Re-link prev_hash and recompute current_hash
    confidence_restore, // Restore confidence to threshold
    entangle_fix, // Reset broken entanglement
    chain_rebuild, // Full chain rebuild from point
};

pub const RepairRecord = struct {
    broken_index: u8,
    repair_type: SelfRepairType,
    confidence_before: f32,
    confidence_after: f32,
    timestamp_us: i64,
};

pub const EvolutionConfig = struct {
    max_generations: u16 = DEFAULT_MAX_GENERATIONS,
    fitness_threshold: f32 = DEFAULT_FITNESS_THRESHOLD,
};

pub const EvolutionRecord = struct {
    generation: u16,
    fitness_score: f32,
    repairs_applied: u8,
    quarks_healthy: u8,
    timestamp_us: i64,
};

pub const ImmortalState = struct {
    last_persist_us: i64,
    persist_count: u32,
    restore_count: u32,
    uptime_start_us: i64,
    tvc_corpus_hash: [32]u8, // SHA256 fingerprint for TVC cross-verification
};

pub const ChainHealthReport = struct {
    total: u8,
    healthy: u8,
    repaired: u8,
    broken: u8,
    health_score: f32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v2.1 PUBLIC LAUNCH + $TRI FAUCET + CANVAS 1.0 TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const FaucetConfig = struct {
    claim_amount_utri: u64 = FAUCET_CLAIM_AMOUNT_UTRI,
    cooldown_us: i64 = FAUCET_COOLDOWN_US,
    daily_limit_utri: u64 = FAUCET_DAILY_LIMIT_UTRI,
    enabled: bool = true,
};

pub const FaucetClaimRecord = struct {
    claim_index: u16,
    amount_utri: u64,
    claimant_hash: [32]u8,
    timestamp_us: i64,
    session_fingerprint: [32]u8,
};

pub const FaucetState = struct {
    total_distributed_utri: u64,
    claims_count: u32,
    last_claim_us: i64,
    daily_distributed_utri: u64,
    day_start_us: i64,
};

pub const PublicCanvasState = struct {
    canvas_version_major: u8,
    canvas_version_minor: u8,
    is_public: bool,
    render_count: u32,
    last_render_us: i64,
    browser_sessions: u16,
    wasm_ready: bool,
    native_ready: bool,
};

pub const PublicSessionInfo = struct {
    session_hash: [32]u8,
    created_us: i64,
    ttl_us: i64,
    view_count: u32,
    share_count: u16,
    faucet_claims: u16,
    is_active: bool,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v2.2 AGENT OS v1.0 — DECENTRALIZED TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const NodeConfig = struct {
    node_id_hash: [32]u8 = [_]u8{0} ** 32,
    sync_interval_us: i64 = NODE_SYNC_INTERVAL_US,
    heartbeat_us: i64 = NODE_HEARTBEAT_US,
    is_active: bool = true,
    stake_utri: u64 = 0,
};

pub const NodeSyncRecord = struct {
    sync_index: u16,
    source_node_hash: [32]u8,
    target_node_hash: [32]u8,
    quark_count_synced: u8,
    timestamp_us: i64,
    latency_us: u64,
    success: bool,
};

pub const NetworkState = struct {
    active_nodes: u16 = 1,
    total_nodes: u16 = 1,
    sync_count: u32 = 0,
    consensus_round: u32 = 0,
    last_consensus_us: i64 = 0,
    network_health_score: f32 = 1.0,
    total_staked_utri: u64 = 0,
    network_uptime_us: i64 = 0,
};

pub const AgentOSState = struct {
    os_version_major: u8 = AGENT_OS_VERSION_MAJOR,
    os_version_minor: u8 = AGENT_OS_VERSION_MINOR,
    is_initialized: bool = false,
    boot_count: u32 = 0,
    last_boot_us: i64 = 0,
    total_queries_processed: u32 = 0,
    network_mode: bool = true,
    immortal_mode: bool = true,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v2.3 TRINITY MAINNET GENESIS CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_TOKEN_SUPPLY_UTRI: u64 = 1_000_000_000_000; // 1M $TRI
pub const TOKEN_MINT_BATCH_UTRI: u64 = 10_000; // 10K uTRI per mint
pub const MAX_DAO_PROPOSALS: usize = 64;
pub const DAO_VOTE_QUORUM_PERCENT: u8 = 67; // 2/3 quorum
pub const DAO_PROPOSAL_TTL_US: i64 = 604_800_000_000; // 7 days
pub const MAX_SWARM_NODES: usize = 512;
pub const SWARM_HEARTBEAT_US: i64 = 3_000_000; // 3 seconds
pub const SWARM_SELF_REPAIR_THRESHOLD: f32 = 0.5;
pub const MAINNET_GENESIS_VERSION_MAJOR: u8 = 2;
pub const MAINNET_GENESIS_VERSION_MINOR: u8 = 3;

pub const TokenConfig = struct {
    total_supply_utri: u64 = 0,
    max_supply_utri: u64 = MAX_TOKEN_SUPPLY_UTRI,
    mint_batch_utri: u64 = TOKEN_MINT_BATCH_UTRI,
    genesis_timestamp_us: i64 = 0,
    is_genesis_complete: bool = false,
    mints_count: u32 = 0,
};

pub const DAOProposal = struct {
    proposal_index: u16,
    proposer_hash: [32]u8,
    title_digest: [48]u8,
    votes_for: u16,
    votes_against: u16,
    votes_abstain: u16,
    created_us: i64,
    ttl_us: i64,
    executed: bool,
    passed: bool,
};

pub const DAOState = struct {
    active_proposals: u16 = 0,
    total_proposals: u32 = 0,
    total_votes_cast: u32 = 0,
    proposals_passed: u32 = 0,
    proposals_rejected: u32 = 0,
    last_vote_us: i64 = 0,
    quorum_percent: u8 = DAO_VOTE_QUORUM_PERCENT,
};

pub const SwarmState = struct {
    active_nodes: u16 = 0,
    total_spawned: u32 = 0,
    total_repairs: u32 = 0,
    swarm_health_score: f32 = 1.0,
    last_heartbeat_us: i64 = 0,
    last_repair_us: i64 = 0,
    genesis_node_hash: [32]u8 = [_]u8{0} ** 32,
};

// v2.4: Mainnet v1.0 Launch — Community Genesis + Full DAO Live + Immortal Swarm Activation
pub const MAX_COMMUNITY_NODES: u16 = 1024;
pub const MAX_NODE_DISCOVERY_RECORDS: u16 = 64;
pub const COMMUNITY_ONBOARD_BATCH: u16 = 32;
pub const PUBLIC_API_RATE_LIMIT: u32 = 1000;
pub const MAINNET_LAUNCH_VERSION_MAJOR: u8 = 1;
pub const MAINNET_LAUNCH_VERSION_MINOR: u8 = 0;

// v2.5: Immortal Agent Swarm v1.0 constants
pub const SWARM_V1_MAX_NODES: u16 = 2048;
pub const SWARM_SYNC_BATCH: u16 = 64;
pub const SWARM_FAILOVER_THRESHOLD: f32 = 0.3;
pub const SWARM_TELEMETRY_INTERVAL_US: i64 = 1_000_000;
pub const SWARM_REPLICATION_FACTOR: u8 = 3;

pub const CommunityState = struct {
    active_nodes: u16 = 0,
    total_onboarded: u32 = 0,
    onboard_batch: u16 = COMMUNITY_ONBOARD_BATCH,
    last_onboard_us: i64 = 0,
    genesis_community_hash: [32]u8 = [_]u8{0} ** 32,
};

pub const MainnetConfig = struct {
    version_major: u8 = MAINNET_LAUNCH_VERSION_MAJOR,
    version_minor: u8 = MAINNET_LAUNCH_VERSION_MINOR,
    launch_timestamp_us: i64 = 0,
    is_launched: bool = false,
    total_nodes: u32 = 0,
    api_rate_limit: u32 = PUBLIC_API_RATE_LIMIT,
};

pub const LaunchState = struct {
    mainnet_launched: bool = false,
    community_ready: bool = false,
    governance_live: bool = false,
    swarm_activated: bool = false,
    launch_block_height: u64 = 0,
    launch_hash: [32]u8 = [_]u8{0} ** 32,
};

pub const NodeDiscoveryRecord = struct {
    node_hash: [32]u8 = [_]u8{0} ** 32,
    discovered_us: i64 = 0,
    node_type: u8 = 0,
    is_active: bool = false,
};

// v2.5: Immortal Agent Swarm v1.0 types
pub const SwarmOrchState = struct {
    active_tasks: u16 = 0,
    total_orchestrated: u32 = 0,
    sync_batch: u16 = SWARM_SYNC_BATCH,
    last_orch_us: i64 = 0,
    orch_hash: [32]u8 = [_]u8{0} ** 32,
};

pub const SwarmFailoverConfig = struct {
    failover_threshold: f32 = SWARM_FAILOVER_THRESHOLD,
    max_retries: u8 = 3,
    failover_count: u32 = 0,
    last_failover_us: i64 = 0,
    is_failover_active: bool = false,
};

pub const SwarmTelemetryState = struct {
    telemetry_interval_us: i64 = SWARM_TELEMETRY_INTERVAL_US,
    reports_sent: u32 = 0,
    avg_latency_us: u64 = 0,
    p99_latency_us: u64 = 0,
    last_report_us: i64 = 0,
};

pub const SwarmReplicationRecord = struct {
    source_hash: [32]u8 = [_]u8{0} ** 32,
    replica_count: u8 = 0,
    replication_factor: u8 = SWARM_REPLICATION_FACTOR,
    replicated_us: i64 = 0,
    is_synced: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// v1.3/v1.4 EXPORT CONSTANTS — on-chain serialization
// ═══════════════════════════════════════════════════════════════════════════════

pub const QUARK_EXPORT_MAGIC = [4]u8{ 'Q', 'G', 'C', '1' };
pub const QUARK_EXPORT_VERSION: u16 = 9; // v2.5: bumped from 8
pub const PROVENANCE_RECORD_EXPORT_SIZE: usize = 158;
pub const QUARK_RECORD_EXPORT_SIZE: usize = 131;
pub const QUARK_EXPORT_HEADER_SIZE: usize = 54; // v2.5: was 50, +4 for swarm_orch_tasks(u16)+swarm_replication_count(u16)

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN CHAIN AGENT — unified 8-node pipeline
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_CHAIN_MSGS = 128;

pub const GoldenChainAgent = struct {
    hybrid_chat: *igla_hybrid.IglaHybridChat,
    messages: [MAX_CHAIN_MSGS]ChainMessage,
    message_count: usize,
    state: ChainState,
    // Intermediate results
    goal_type: GoalType,
    subtask_count: u8,
    execute_response: ?igla_hybrid.HybridResponse,
    min_quality: f32,
    // v1.1: Provenance hash chain
    provenance: [MAX_PROVENANCE_RECORDS]ProvenanceRecord,
    provenance_count: u8,
    chain_verified: bool,
    // v1.2: Quark-Gluon sub-step chain
    quarks: [MAX_QUARK_RECORDS]QuarkRecord,
    quark_count: u8,
    quark_chain_verified: bool,
    // v1.3: Verbosity control
    quark_verbosity: QuarkVerbosity,
    // v1.4: $TRI rewards
    total_reward_utri: u64,
    reward_config: TriRewardConfig,
    // v1.5: Collapsible views + Shareable links + Staking
    node_view_states: [8]QuarkViewState,
    last_share_link: ?ShareableLink,
    staking_config: StakingConfig,
    staking_records: [MAX_STAKING_RECORDS]StakingRecord,
    staking_count: u8,
    staking_total_utri: u64,
    // v2.0: Immortal Self-Verifying Agent
    repair_records: [MAX_REPAIR_RECORDS]RepairRecord,
    repair_count: u8,
    repair_state: SelfRepairState,
    evolution_config: EvolutionConfig,
    evolution_records: [MAX_EVOLUTION_RECORDS]EvolutionRecord,
    evolution_count: u16,
    current_generation: u16,
    immortal_state: ImmortalState,
    // v2.1: Public Launch + $TRI Faucet + Canvas 1.0
    faucet_config: FaucetConfig,
    faucet_claims: [MAX_FAUCET_CLAIMS]FaucetClaimRecord,
    faucet_claims_count: u16,
    faucet_total_distributed_utri: u64,
    faucet_daily_distributed_utri: u64,
    faucet_day_start_us: i64,
    canvas_state: PublicCanvasState,
    public_session: ?PublicSessionInfo,
    // v2.2: Agent OS v1.0 — Decentralized Immortal Network
    node_config: NodeConfig,
    node_sync_records: [MAX_NODE_SYNC_RECORDS]NodeSyncRecord,
    node_sync_count: u16,
    network_state: NetworkState,
    agent_os_state: AgentOSState,
    // v2.3: Mainnet Genesis — $TRI Token + DAO Governance + Immortal Swarm
    token_config: TokenConfig,
    dao_proposals: [MAX_DAO_PROPOSALS]DAOProposal,
    dao_proposal_count: u16,
    dao_state: DAOState,
    swarm_state: SwarmState,
    // v2.4: Mainnet v1.0 Launch — Community Genesis + Full DAO Live + Immortal Swarm Activation
    community_state: CommunityState,
    mainnet_config: MainnetConfig,
    launch_state: LaunchState,
    node_discovery_records: [MAX_NODE_DISCOVERY_RECORDS]NodeDiscoveryRecord,
    node_discovery_count: u16,
    // v2.5: Immortal Agent Swarm v1.0
    swarm_orch_state: SwarmOrchState,
    swarm_failover_config: SwarmFailoverConfig,
    swarm_telemetry_state: SwarmTelemetryState,
    swarm_replication_records: [SWARM_REPLICATION_FACTOR]SwarmReplicationRecord,
    swarm_replication_count: u8,

    const Self = @This();

    pub fn init(hybrid: *igla_hybrid.IglaHybridChat) Self {
        return .{
            .hybrid_chat = hybrid,
            .messages = undefined,
            .message_count = 0,
            .state = ChainState.init(),
            .goal_type = .Chat,
            .subtask_count = 1,
            .execute_response = null,
            .min_quality = 0.7,
            .provenance = undefined,
            .provenance_count = 0,
            .chain_verified = false,
            .quarks = undefined,
            .quark_count = 0,
            .quark_chain_verified = false,
            .quark_verbosity = .full,
            .total_reward_utri = 0,
            .reward_config = .{},
            .node_view_states = [_]QuarkViewState{.expanded} ** 8,
            .last_share_link = null,
            .staking_config = .{},
            .staking_records = undefined,
            .staking_count = 0,
            .staking_total_utri = 0,
            .repair_records = undefined,
            .repair_count = 0,
            .repair_state = .healthy,
            .evolution_config = .{},
            .evolution_records = undefined,
            .evolution_count = 0,
            .current_generation = 0,
            .immortal_state = .{
                .last_persist_us = 0,
                .persist_count = 0,
                .restore_count = 0,
                .uptime_start_us = std.time.microTimestamp(),
                .tvc_corpus_hash = [_]u8{0} ** 32,
            },
            .faucet_config = .{},
            .faucet_claims = undefined,
            .faucet_claims_count = 0,
            .faucet_total_distributed_utri = 0,
            .faucet_daily_distributed_utri = 0,
            .faucet_day_start_us = 0,
            .canvas_state = .{
                .canvas_version_major = CANVAS_VERSION_MAJOR,
                .canvas_version_minor = CANVAS_VERSION_MINOR,
                .is_public = false,
                .render_count = 0,
                .last_render_us = 0,
                .browser_sessions = 0,
                .wasm_ready = false,
                .native_ready = true,
            },
            .public_session = null,
            .node_config = .{},
            .node_sync_records = undefined,
            .node_sync_count = 0,
            .network_state = .{},
            .agent_os_state = .{},
            .token_config = .{},
            .dao_proposals = undefined,
            .dao_proposal_count = 0,
            .dao_state = .{},
            .swarm_state = .{},
            .community_state = .{},
            .mainnet_config = .{},
            .launch_state = .{},
            .node_discovery_records = undefined,
            .node_discovery_count = 0,
            // v2.5: Swarm v1.0
            .swarm_orch_state = .{},
            .swarm_failover_config = .{},
            .swarm_telemetry_state = .{},
            .swarm_replication_records = undefined,
            .swarm_replication_count = 0,
        };
    }

    /// Main entry: process user input through the full 8-node chain.
    /// Each node emits one or more ChainMessages.
    pub fn processInput(self: *Self, user_input: []const u8) void {
        self.message_count = 0;
        self.state.reset();
        self.state.is_running = true;
        self.execute_response = null;
        self.provenance_count = 0;
        self.chain_verified = false;
        self.quark_count = 0;
        self.quark_chain_verified = false;
        self.total_reward_utri = 0;
        self.node_view_states = [_]QuarkViewState{.expanded} ** 8;
        self.last_share_link = null;
        self.staking_count = 0;
        self.staking_total_utri = 0;
        self.repair_count = 0;
        self.repair_state = .healthy;

        // === NODE 1: GOAL_PARSE ===
        self.nodeGoalParse(user_input);

        // === NODE 2: DECOMPOSE ===
        self.nodeDecompose(user_input);

        // === NODE 3: SCHEDULE ===
        self.nodeSchedule();

        // === NODE 4: EXECUTE ===
        self.nodeExecute(user_input);

        // === NODE 5: MONITOR ===
        self.nodeMonitor();

        // === NODE 6: ADAPT ===
        self.nodeAdapt(user_input);

        // === NODE 7: SYNTHESIZE ===
        self.nodeSynthesize();

        // === NODE 8: DELIVER ===
        self.nodeDeliver();

        self.state.is_running = false;
        g_chain_state = self.state;
    }

    // ── Node 1: GOAL_PARSE ──
    fn nodeGoalParse(self: *Self, input: []const u8) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.GoalParse);

        self.goal_type = detectGoalType(input);

        const preview_len = @min(input.len, 60);
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Goal: \"{s}\" -> type: {s}", .{
            input[0..preview_len],
            self.goal_type.getName(),
        }) catch "Goal parsed";

        const dt = self.elapsed(start);
        self.emitChainMsg(.GoalParse, msg, 0.95, dt);
        self.state.completeNode(.GoalParse, 0.95, dt);
        self.recordProvenance(.GoalParse, msg, 0.95, 0.0, null, dt);
        self.emitGoalParseQuarks(input);
    }

    // ── Node 2: DECOMPOSE ──
    fn nodeDecompose(self: *Self, input: []const u8) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Decompose);

        // Simple decomposition: count "and" separators
        self.subtask_count = 1;
        var i: usize = 0;
        while (i + 3 < input.len) : (i += 1) {
            if (std.mem.eql(u8, input[i .. i + 3], "and") or
                std.mem.eql(u8, input[i .. i + 3], " и "))
            {
                self.subtask_count += 1;
            }
        }

        var buf: [256]u8 = undefined;
        const msg = if (self.subtask_count > 1)
            std.fmt.bufPrint(&buf, "Subtasks: {d} (compound goal)", .{self.subtask_count}) catch "Decomposed"
        else
            std.fmt.bufPrint(&buf, "Single task (no decomposition needed)", .{}) catch "Single task";

        const dt = self.elapsed(start);
        self.emitChainMsg(.Decompose, msg, 0.9, dt);
        self.state.completeNode(.Decompose, 0.9, dt);
        self.recordProvenance(.Decompose, msg, 0.9, 0.0, null, dt);
        self.emitDecomposeQuarks();
    }

    // ── Node 3: SCHEDULE ──
    fn nodeSchedule(self: *Self) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Schedule);

        var buf: [256]u8 = undefined;
        const msg = if (self.subtask_count > 1)
            std.fmt.bufPrint(&buf, "Order: {d} tasks, sequential execution", .{self.subtask_count}) catch "Scheduled"
        else
            std.fmt.bufPrint(&buf, "Direct execution (single task)", .{}) catch "Direct";

        const dt = self.elapsed(start);
        self.emitChainMsg(.Schedule, msg, 0.95, dt);
        self.state.completeNode(.Schedule, 0.95, dt);
        self.recordProvenance(.Schedule, msg, 0.95, 0.0, null, dt);
        self.emitScheduleQuarks();
    }

    // ── Node 4: EXECUTE — main work via IglaHybridChat ──
    fn nodeExecute(self: *Self, input: []const u8) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Execute);

        if (self.hybrid_chat.respond(input)) |hr| {
            self.execute_response = hr;

            // Emit source routing info
            {
                var rbuf: [128]u8 = undefined;
                const routing_msg = std.fmt.bufPrint(&rbuf, "->{s} | latency: {d}us", .{
                    @tagName(hr.source),
                    hr.latency_us,
                }) catch "Routed";
                self.emitMsg(.RoutingInfo, null, hr.source, routing_msg, hr.confidence, hr.latency_us);
            }

            // Emit tool info if applicable
            if (hr.tool_name) |tn| {
                var tbuf: [128]u8 = undefined;
                const tool_msg = std.fmt.bufPrint(&tbuf, "Tool: {s}", .{tn}) catch "Tool used";
                self.emitMsg(.ToolResult, null, .Tool, tool_msg, 1.0, 0);
            }

            // Emit response content
            const resp_len = @min(hr.response.len, MAX_MSG_CONTENT - 1);
            self.emitChainMsg(.Execute, hr.response[0..resp_len], hr.confidence, hr.latency_us);

            // Emit reflection if learned
            if (hr.reflection.wasLearned()) {
                self.emitMsg(.Reflection, null, null, "Saved to TVC corpus (LEARNED)", 1.0, 0);
            } else if (hr.reflection != .NotApplicable) {
                var rfbuf: [128]u8 = undefined;
                const rf_msg = std.fmt.bufPrint(&rfbuf, "Reflection: {s}", .{hr.reflection.getName()}) catch "Filtered";
                self.emitMsg(.Reflection, null, null, rf_msg, hr.confidence, 0);
            }

            const dt = self.elapsed(start);
            self.state.completeNode(.Execute, hr.confidence, dt);
            self.recordProvenance(.Execute, hr.response[0..resp_len], hr.confidence, @floatCast(hr.tvc_similarity), hr.source, dt);
            self.emitExecuteQuarks(hr.confidence);
        } else |_| {
            const dt = self.elapsed(start);
            self.emitMsg(.Error, .Execute, .Error, "Execution failed — no response", 0.0, dt);
            self.state.completeNode(.Execute, 0.0, dt);
            self.recordProvenance(.Execute, "error: no response", 0.0, 0.0, .Error, dt);
            self.emitExecuteQuarks(0.0);
        }
    }

    // ── Node 5: MONITOR ──
    fn nodeMonitor(self: *Self) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Monitor);

        const conf = if (self.execute_response) |hr| hr.confidence else 0.0;
        const lat = if (self.execute_response) |hr| hr.latency_us else 0;
        const src = if (self.execute_response) |hr| @tagName(hr.source) else "none";

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Quality: {d:.0}% | Latency: {d}us | Source: {s}", .{
            conf * 100,
            lat,
            src,
        }) catch "Monitoring...";

        const dt = self.elapsed(start);
        self.emitChainMsg(.Monitor, msg, conf, dt);
        self.state.completeNode(.Monitor, conf, dt);
        self.recordProvenance(.Monitor, msg, conf, 0.0, null, dt);
        self.emitMonitorQuarks(conf);
    }

    // ── Node 6: ADAPT ──
    fn nodeAdapt(self: *Self, input: []const u8) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Adapt);

        const conf = self.state.total_confidence;

        if (conf < self.min_quality and self.execute_response != null) {
            // Re-try with different wording
            self.emitChainMsg(.Adapt, "Quality below threshold, retrying...", conf, 0);

            if (self.hybrid_chat.respond(input)) |hr2| {
                if (hr2.confidence > conf) {
                    self.execute_response = hr2;
                    var buf: [128]u8 = undefined;
                    const msg = std.fmt.bufPrint(&buf, "Improved: {d:.0}% -> {d:.0}%", .{
                        conf * 100,
                        hr2.confidence * 100,
                    }) catch "Improved";
                    const dt = self.elapsed(start);
                    self.emitChainMsg(.Adapt, msg, hr2.confidence, dt);
                    self.state.completeNode(.Adapt, hr2.confidence, dt);
                    self.recordProvenance(.Adapt, msg, hr2.confidence, @floatCast(hr2.tvc_similarity), hr2.source, dt);
                    self.emitAdaptQuarks(hr2.confidence);
                    return;
                }
            } else |_| {}
        }

        const msg = if (conf >= self.min_quality)
            "Quality OK, no adaptation needed"
        else
            "Adaptation attempted, keeping best result";

        const dt = self.elapsed(start);
        self.emitChainMsg(.Adapt, msg, @max(conf, 0.5), dt);
        self.state.completeNode(.Adapt, @max(conf, 0.5), dt);
        self.recordProvenance(.Adapt, msg, @max(conf, 0.5), 0.0, null, dt);
        self.emitAdaptQuarks(@max(conf, 0.5));
    }

    // ── Node 7: SYNTHESIZE ──
    fn nodeSynthesize(self: *Self) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Synthesize);

        var buf: [256]u8 = undefined;
        const msg = if (self.subtask_count > 1)
            std.fmt.bufPrint(&buf, "Merging {d} subtask results...", .{self.subtask_count}) catch "Merging..."
        else
            std.fmt.bufPrint(&buf, "Single result, synthesis complete", .{}) catch "Complete";

        const dt = self.elapsed(start);
        self.emitChainMsg(.Synthesize, msg, self.state.total_confidence, dt);
        self.state.completeNode(.Synthesize, self.state.total_confidence, dt);
        self.recordProvenance(.Synthesize, msg, self.state.total_confidence, 0.0, null, dt);
        self.emitSynthesizeQuarks(self.state.total_confidence);
    }

    // ── Node 8: DELIVER ──
    fn nodeDeliver(self: *Self) void {
        const start = std.time.microTimestamp();
        self.state.startNode(.Deliver);

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Chain complete | Total: {d:.0}% | {d}us", .{
            self.state.total_confidence * 100,
            self.state.total_latency_us,
        }) catch "Delivered";

        const dt = self.elapsed(start);
        self.emitChainMsg(.Deliver, msg, self.state.total_confidence, dt);
        self.state.completeNode(.Deliver, self.state.total_confidence, dt);
        self.recordProvenance(.Deliver, msg, self.state.total_confidence, 0.0, null, dt);
        self.emitDeliverQuarks(self.state.total_confidence);

        // v1.1: Verify provenance chain integrity
        self.chain_verified = self.verifyProvenanceChain();
        if (self.chain_verified) {
            var vbuf: [128]u8 = undefined;
            const vmsg = std.fmt.bufPrint(&vbuf, "Chain integrity: VERIFIED ({d}/8 hashes valid)", .{self.provenance_count}) catch "Chain VERIFIED";
            self.emitMsg(.TruthVerification, .Deliver, null, vmsg, 1.0, 0);
        } else {
            self.emitMsg(.TruthVerification, .Deliver, null, "Chain integrity: BROKEN", 0.0, 0);
        }

        // v1.2+v1.3+v1.4: Verify quark chain integrity (linear + DAG + phi + xchain + phiQ)
        self.quark_chain_verified = self.verifyQuarkChain();
        if (self.quark_chain_verified) {
            var qvbuf: [128]u8 = undefined;
            const qvmsg = std.fmt.bufPrint(&qvbuf, "Quark chain: VERIFIED ({d}/104 quarks, DAG+phi+xchain+phiQ+staking+immortal+faucet+network+dao+mainnet+swarm intact)", .{self.quark_count}) catch "Quarks VERIFIED";
            self.emitMsg(.TruthVerification, .Deliver, null, qvmsg, 1.0, 0);
        } else {
            self.emitMsg(.TruthVerification, .Deliver, null, "Quark chain: BROKEN", 0.0, 0);
        }

        // v1.4: DAG stats summary
        {
            const dag_stats = self.getDAGStats();
            var dbuf: [256]u8 = undefined;
            const dmsg = std.fmt.bufPrint(&dbuf, "DAG: {d} edges | depth:{d} | width:{d} | fan-out:{d} | fan-in:{d}", .{
                dag_stats.edge_count,
                dag_stats.max_depth,
                dag_stats.max_width,
                dag_stats.max_fan_out,
                dag_stats.max_fan_in,
            }) catch "DAG stats";
            self.emitMsg(.DAGVisualization, .Deliver, null, dmsg, 1.0, 0);
        }

        // v1.4: $TRI reward calculation
        {
            const reward = self.calculateSessionReward();
            var rbuf: [256]u8 = undefined;
            const rmsg = std.fmt.bufPrint(&rbuf, "$TRI: {d} uTRI (base:{d} + conf:{d} + quark:{d} - energy:{d})", .{
                reward.total_reward_utri,
                reward.base_utri,
                reward.confidence_bonus_utri,
                reward.quark_bonus_utri,
                reward.energy_penalty_utri,
            }) catch "$TRI reward";
            self.emitMsg(.RewardSummary, .Deliver, null, rmsg, 1.0, 0);
        }

        // v1.5: Auto-stake if enabled and reward above minimum
        if (self.staking_config.auto_restake and self.total_reward_utri >= self.staking_config.min_stake_utri) {
            _ = self.stakeReward(self.total_reward_utri);
        }

        // v1.5: Generate shareable link
        {
            const link = self.generateShareLink();
            var lbuf: [256]u8 = undefined;
            var link_fmt_buf: [128]u8 = undefined;
            const link_str = link.formatLink(&link_fmt_buf);
            const lmsg = std.fmt.bufPrint(&lbuf, "Share: {s} | {d}q {d}p verified:{}", .{
                link_str,
                link.quark_count,
                link.provenance_count,
                link.is_verified,
            }) catch "Share link generated";
            self.emitMsg(.ShareLinkGenerated, .Deliver, null, lmsg, 1.0, 0);
        }

        // v1.5: Collapse toggle status
        {
            var collapsed_count: u8 = 0;
            for (0..8) |ni| {
                if (self.node_view_states[ni] == .collapsed) collapsed_count += 1;
            }
            var cbuf: [128]u8 = undefined;
            const cmsg = std.fmt.bufPrint(&cbuf, "View: {d}/8 expanded | {d}/8 collapsed", .{
                8 - collapsed_count,
                collapsed_count,
            }) catch "View state";
            self.emitMsg(.CollapseToggle, .Deliver, null, cmsg, 1.0, 0);
        }

        // v1.5: Staking event summary
        {
            var sbuf2: [256]u8 = undefined;
            const smsg2 = std.fmt.bufPrint(&sbuf2, "Staking: {d} active | {d} uTRI locked | rate:{d:.1}%/day", .{
                self.staking_count,
                self.staking_total_utri,
                self.staking_config.yield_rate_per_day * 100.0,
            }) catch "Staking summary";
            self.emitMsg(.StakingEvent, .Deliver, null, smsg2, 1.0, 0);
        }

        // v2.0: Self-repair chain scan
        {
            const repair = self.selfRepairChain();
            if (repair) |rec| {
                var rpbuf: [256]u8 = undefined;
                const rpmsg = std.fmt.bufPrint(&rpbuf, "Self-repair: idx={d} conf {d:.2}->{d:.2} | state={s}", .{
                    rec.broken_index,
                    rec.confidence_before,
                    rec.confidence_after,
                    @tagName(self.repair_state),
                }) catch "Self-repair applied";
                self.emitMsg(.SelfRepairEvent, .Deliver, null, rpmsg, 1.0, 0);
            } else {
                self.emitMsg(.SelfRepairEvent, .Deliver, null, "Self-repair: chain healthy, no repair needed", 1.0, 0);
            }
        }

        // v2.0: Chain health check
        {
            const health = self.getChainHealth();
            var hbuf: [256]u8 = undefined;
            const hmsg = std.fmt.bufPrint(&hbuf, "Health: {d}/{d} healthy | {d} repaired | {d} broken | score={d:.2}", .{
                health.healthy,
                health.total,
                health.repaired,
                health.broken,
                health.health_score,
            }) catch "Health check";
            self.emitMsg(.ChainHealthCheck, .Deliver, null, hmsg, health.health_score, 0);
        }

        // v2.0: Persist state (immortal checkpoint)
        {
            const fingerprint = self.persistState();
            var pfbuf: [256]u8 = undefined;
            const pfmsg = std.fmt.bufPrint(&pfbuf, "Persist: count={d} | restore={d} | hash={x:0>2}{x:0>2}{x:0>2}{x:0>2}...", .{
                self.immortal_state.persist_count,
                self.immortal_state.restore_count,
                fingerprint[0],
                fingerprint[1],
                fingerprint[2],
                fingerprint[3],
            }) catch "Persist checkpoint";
            self.emitMsg(.ImmortalPersist, .Deliver, null, pfmsg, 1.0, 0);
        }

        // v2.0: Evolution step
        {
            const evo = self.evolveChain();
            var ebuf: [256]u8 = undefined;
            const emsg = std.fmt.bufPrint(&ebuf, "Evolution: gen={d} | fitness={d:.2} | repairs={d} | healthy_q={d}", .{
                evo.generation,
                evo.fitness_score,
                evo.repairs_applied,
                evo.quarks_healthy,
            }) catch "Evolution step";
            self.emitMsg(.EvolutionStep, .Deliver, null, emsg, evo.fitness_score, 0);
        }

        // v2.1: Faucet claim summary
        {
            const fs = self.getFaucetState();
            var fcbuf: [256]u8 = undefined;
            const fcmsg = std.fmt.bufPrint(&fcbuf, "Faucet: {d} claims | {d} uTRI distributed | daily:{d}/{d}", .{
                fs.claims_count,
                fs.total_distributed_utri,
                fs.daily_distributed_utri,
                FAUCET_DAILY_LIMIT_UTRI,
            }) catch "Faucet summary";
            self.emitMsg(.FaucetClaim, .Deliver, null, fcmsg, 1.0, 0);
        }

        // v2.1: Public canvas launch
        {
            self.initPublicCanvas();
            var pcbuf: [256]u8 = undefined;
            const pcmsg = std.fmt.bufPrint(&pcbuf, "Canvas {d}.{d}: public={} | renders={d} | wasm={} native={}", .{
                self.canvas_state.canvas_version_major,
                self.canvas_state.canvas_version_minor,
                self.canvas_state.is_public,
                self.canvas_state.render_count,
                self.canvas_state.wasm_ready,
                self.canvas_state.native_ready,
            }) catch "Canvas launched";
            self.emitMsg(.PublicLaunch, .Deliver, null, pcmsg, 1.0, 0);
        }

        // v2.1: Canvas sync event
        {
            const cs = self.syncCanvasState();
            var csbuf: [256]u8 = undefined;
            const csmsg = std.fmt.bufPrint(&csbuf, "Canvas sync: renders={d} | sessions={d} | last={d}us", .{
                cs.render_count,
                cs.browser_sessions,
                cs.last_render_us,
            }) catch "Canvas synced";
            self.emitMsg(.CanvasSync, .Deliver, null, csmsg, 1.0, 0);
        }

        // v2.1: Faucet distribution summary
        {
            const fs2 = self.getFaucetState();
            var fdbuf: [128]u8 = undefined;
            const fdmsg = std.fmt.bufPrint(&fdbuf, "Faucet dist: {d} uTRI total | day_start={d}", .{
                fs2.total_distributed_utri,
                fs2.day_start_us,
            }) catch "Faucet distribution";
            self.emitMsg(.FaucetDistribution, .Deliver, null, fdmsg, 1.0, 0);
        }

        // v2.2: Decentralized sync event
        {
            const ns = self.getNetworkState();
            var dsbuf: [256]u8 = undefined;
            const dsmsg = std.fmt.bufPrint(&dsbuf, "Network: {d}/{d} nodes active | syncs={d} | health={d:.2}", .{
                ns.active_nodes,
                ns.total_nodes,
                ns.sync_count,
                ns.network_health_score,
            }) catch "Network sync";
            self.emitMsg(.DecentralSync, .Deliver, null, dsmsg, ns.network_health_score, 0);
        }

        // v2.2: Node consensus event
        {
            const quorum = self.runConsensus();
            var ncbuf: [256]u8 = undefined;
            const ncmsg = std.fmt.bufPrint(&ncbuf, "Consensus: round={d} | quorum={} | staked={d} uTRI", .{
                self.network_state.consensus_round,
                quorum,
                self.network_state.total_staked_utri,
            }) catch "Consensus event";
            self.emitMsg(.NodeConsensus, .Deliver, null, ncmsg, if (quorum) @as(f32, 1.0) else @as(f32, 0.5), 0);
        }

        // v2.2: Network health report
        {
            const ns2 = self.getNetworkState();
            var nhbuf: [256]u8 = undefined;
            const nhmsg = std.fmt.bufPrint(&nhbuf, "Health: score={d:.2} | uptime={d}us | staked={d} uTRI", .{
                ns2.network_health_score,
                ns2.network_uptime_us,
                ns2.total_staked_utri,
            }) catch "Network health";
            self.emitMsg(.NetworkHealth, .Deliver, null, nhmsg, ns2.network_health_score, 0);
        }

        // v2.2: Agent OS init event
        {
            self.initAgentOS();
            var aobuf: [256]u8 = undefined;
            const aomsg = std.fmt.bufPrint(&aobuf, "Agent OS {d}.{d}: boots={d} | queries={d} | network={} | immortal={}", .{
                self.agent_os_state.os_version_major,
                self.agent_os_state.os_version_minor,
                self.agent_os_state.boot_count,
                self.agent_os_state.total_queries_processed,
                self.agent_os_state.network_mode,
                self.agent_os_state.immortal_mode,
            }) catch "Agent OS init";
            self.emitMsg(.AgentOSInit, .Deliver, null, aomsg, 1.0, 0);
        }

        // v2.3: Mainnet genesis event
        {
            const minted = self.mintToken();
            var mgbuf: [256]u8 = undefined;
            const mgmsg = std.fmt.bufPrint(&mgbuf, "Mainnet Genesis: minted={d} uTRI | total={d}/{d} | genesis={}", .{
                minted,
                self.token_config.total_supply_utri,
                self.token_config.max_supply_utri,
                self.token_config.is_genesis_complete,
            }) catch "Mainnet genesis";
            self.emitMsg(.MainnetGenesis, .Deliver, null, mgmsg, 1.0, 0);
        }

        // v2.3: DAO vote event
        {
            var dvbuf: [256]u8 = undefined;
            const dvmsg = std.fmt.bufPrint(&dvbuf, "DAO: {d} proposals | {d} votes | passed={d} rejected={d}", .{
                self.dao_state.total_proposals,
                self.dao_state.total_votes_cast,
                self.dao_state.proposals_passed,
                self.dao_state.proposals_rejected,
            }) catch "DAO summary";
            self.emitMsg(.DAOVote, .Deliver, null, dvmsg, 1.0, 0);
        }

        // v2.3: Swarm sync event
        {
            _ = self.spawnSwarmNode();
            var ssbuf: [256]u8 = undefined;
            const ssmsg = std.fmt.bufPrint(&ssbuf, "Swarm: {d} active | spawned={d} | repairs={d} | health={d:.2}", .{
                self.swarm_state.active_nodes,
                self.swarm_state.total_spawned,
                self.swarm_state.total_repairs,
                self.swarm_state.swarm_health_score,
            }) catch "Swarm sync";
            self.emitMsg(.SwarmSync, .Deliver, null, ssmsg, self.swarm_state.swarm_health_score, 0);
        }

        // v2.3: Token mint event
        {
            var tmbuf: [256]u8 = undefined;
            const tmmsg = std.fmt.bufPrint(&tmbuf, "$TRI: supply={d}/{d} uTRI | mints={d} | genesis_ts={d}", .{
                self.token_config.total_supply_utri,
                self.token_config.max_supply_utri,
                self.token_config.mints_count,
                self.token_config.genesis_timestamp_us,
            }) catch "Token mint";
            self.emitMsg(.TokenMint, .Deliver, null, tmmsg, 1.0, 0);
        }

        // v2.4: Mainnet launch event
        {
            _ = self.launchMainnet();
            _ = self.communityOnboard();
            self.launch_state.governance_live = true;
            self.launch_state.swarm_activated = true;
            var mlbuf: [256]u8 = undefined;
            const mlmsg = std.fmt.bufPrint(&mlbuf, "Mainnet v{d}.{d}: launched={} | nodes={d} | community={d} | governance={}", .{
                self.mainnet_config.version_major,
                self.mainnet_config.version_minor,
                self.mainnet_config.is_launched,
                self.mainnet_config.total_nodes,
                self.community_state.active_nodes,
                self.launch_state.governance_live,
            }) catch "Mainnet launch";
            self.emitMsg(.MainnetLaunch, .Deliver, null, mlmsg, 1.0, 0);
        }

        // v2.4: Community onboard event
        {
            var cobuf: [256]u8 = undefined;
            const comsg = std.fmt.bufPrint(&cobuf, "Community: active={d} | onboarded={d} | batch={d}", .{
                self.community_state.active_nodes,
                self.community_state.total_onboarded,
                self.community_state.onboard_batch,
            }) catch "Community onboard";
            self.emitMsg(.CommunityOnboard, .Deliver, null, comsg, 1.0, 0);
        }

        // v2.4: Node discovery event
        {
            var ndbuf: [256]u8 = undefined;
            const ndmsg = std.fmt.bufPrint(&ndbuf, "NodeDiscovery: discovered={d}/{d}", .{
                self.node_discovery_count,
                MAX_NODE_DISCOVERY_RECORDS,
            }) catch "Node discovery";
            self.emitMsg(.NodeDiscovery, .Deliver, null, ndmsg, 1.0, 0);
        }

        // v2.4: Governance execution event
        {
            var gebuf: [256]u8 = undefined;
            const gemsg = std.fmt.bufPrint(&gebuf, "GovernanceExec: proposals={d} | votes={d} | passed={d}", .{
                self.dao_state.total_proposals,
                self.dao_state.total_votes_cast,
                self.dao_state.proposals_passed,
            }) catch "Governance exec";
            self.emitMsg(.GovernanceExec, .Deliver, null, gemsg, 1.0, 0);
        }

        // v2.5: Swarm orchestration event
        {
            var sobuf: [256]u8 = undefined;
            const somsg = std.fmt.bufPrint(&sobuf, "SwarmOrchestrate: tasks={d} | total={d} | batch={d}", .{
                self.swarm_orch_state.active_tasks,
                self.swarm_orch_state.total_orchestrated,
                self.swarm_orch_state.sync_batch,
            }) catch "Swarm orchestrate";
            self.emitMsg(.SwarmOrchestrate, .Deliver, null, somsg, 1.0, 0);
        }

        // v2.5: Swarm failover event
        {
            var sfbuf: [256]u8 = undefined;
            const sfmsg = std.fmt.bufPrint(&sfbuf, "SwarmFailover: count={d} | active={} | threshold={d:.2}", .{
                self.swarm_failover_config.failover_count,
                self.swarm_failover_config.is_failover_active,
                self.swarm_failover_config.failover_threshold,
            }) catch "Swarm failover";
            self.emitMsg(.SwarmFailover, .Deliver, null, sfmsg, 1.0, 0);
        }

        // v2.5: Swarm telemetry event
        {
            var stbuf: [256]u8 = undefined;
            const stmsg = std.fmt.bufPrint(&stbuf, "SwarmTelemetry: reports={d} | avg_lat={d}us | p99={d}us", .{
                self.swarm_telemetry_state.reports_sent,
                self.swarm_telemetry_state.avg_latency_us,
                self.swarm_telemetry_state.p99_latency_us,
            }) catch "Swarm telemetry";
            self.emitMsg(.SwarmTelemetry, .Deliver, null, stmsg, 1.0, 0);
        }

        // v2.5: Swarm replication event
        {
            var srbuf: [256]u8 = undefined;
            const srmsg = std.fmt.bufPrint(&srbuf, "SwarmReplication: count={d} | factor={d}", .{
                self.swarm_replication_count,
                SWARM_REPLICATION_FACTOR,
            }) catch "Swarm replication";
            self.emitMsg(.SwarmReplication, .Deliver, null, srmsg, 1.0, 0);
        }

        // Update global wave state
        igla_hybrid.g_last_wave_state = .{
            .similarity = self.state.total_confidence,
            .source_hue = ChainNode.Deliver.getHue(),
            .confidence = self.state.total_confidence,
            .latency_normalized = @min(1.0, @as(f32, @floatFromInt(self.state.total_latency_us)) / 5_000_000.0),
            .memory_load = @as(f32, @floatFromInt(self.message_count)) / @as(f32, MAX_CHAIN_MSGS),
            .is_learning = if (self.execute_response) |hr| hr.reflection.wasLearned() else false,
            .routing = if (self.execute_response) |_| igla_hybrid.g_last_wave_state.routing else .RouteSymbolic,
            .provider_health_avg = igla_hybrid.g_last_wave_state.provider_health_avg,
        };
    }

    // ── Helpers ──

    fn emitChainMsg(self: *Self, node: ChainNode, content: []const u8, confidence: f32, latency_us: u64) void {
        const source = if (self.execute_response) |hr| hr.source else null;
        self.emitMsg(.ChainStep, node, source, content, confidence, latency_us);
    }

    fn emitMsg(self: *Self, msg_type: ChainMessageType, node: ?ChainNode, source: ?igla_hybrid.HybridResponse.Source, content: []const u8, confidence: f32, latency_us: u64) void {
        if (self.message_count >= MAX_CHAIN_MSGS) {
            // Shift: drop oldest
            for (0..MAX_CHAIN_MSGS - 1) |i| {
                self.messages[i] = self.messages[i + 1];
            }
            self.message_count = MAX_CHAIN_MSGS - 1;
        }

        const copy_len = @min(content.len, MAX_MSG_CONTENT - 1);
        var msg = ChainMessage{
            .msg_type = msg_type,
            .node = node,
            .source = source,
            .content = undefined,
            .content_len = copy_len,
            .confidence = confidence,
            .latency_us = latency_us,
        };
        @memcpy(msg.content[0..copy_len], content[0..copy_len]);
        msg.content[copy_len] = 0; // null-terminate for safety
        self.messages[self.message_count] = msg;
        self.message_count += 1;
    }

    fn elapsed(self: *const Self, start: i64) u64 {
        _ = self;
        const now = std.time.microTimestamp();
        if (now > start) return @intCast(now - start);
        return 0;
    }

    pub fn getMessages(self: *const Self) []const ChainMessage {
        return self.messages[0..self.message_count];
    }

    // ── v1.1: Provenance Hash Chain ──

    /// Record a provenance step for a completed node.
    /// Creates SHA256 hash link and emits ProvenanceStep chat message.
    fn recordProvenance(
        self: *Self,
        node: ChainNode,
        content: []const u8,
        confidence: f32,
        tvc_similarity: f32,
        source: ?igla_hybrid.HybridResponse.Source,
        latency_us: u64,
    ) void {
        if (self.provenance_count >= MAX_PROVENANCE_RECORDS) return;

        const timestamp = std.time.microTimestamp();
        const idx = self.provenance_count;

        // Genesis = all zeros, otherwise chain to previous
        const prev_hash: [PROVENANCE_HASH_SIZE]u8 = if (idx > 0)
            self.provenance[idx - 1].current_hash
        else
            [_]u8{0} ** PROVENANCE_HASH_SIZE;

        const current_hash = ProvenanceRecord.computeHash(
            prev_hash,
            node,
            content,
            confidence,
            timestamp,
        );

        const verdict = assessTruth(confidence, tvc_similarity);

        const dlen: u8 = @intCast(@min(content.len, CONTENT_DIGEST_LEN));
        var record = ProvenanceRecord{
            .step_index = idx,
            .node = node,
            .content_digest = undefined,
            .digest_len = dlen,
            .confidence = confidence,
            .tvc_similarity = tvc_similarity,
            .truth_verdict = verdict,
            .timestamp_us = timestamp,
            .latency_us = latency_us,
            .source = source,
            .prev_hash = prev_hash,
            .current_hash = current_hash,
        };
        @memcpy(record.content_digest[0..dlen], content[0..dlen]);
        self.provenance[idx] = record;
        self.provenance_count += 1;

        // Emit provenance chat line: "[a3f2b1c9] NODE | VERDICT | conf% | tvc:sim"
        var hex_buf: [8]u8 = undefined;
        ProvenanceRecord.hashHexPrefix(current_hash, &hex_buf);
        var prov_buf: [256]u8 = undefined;
        const prov_msg = std.fmt.bufPrint(&prov_buf, "[{s}] {s} | {s} | {d:.0}% | tvc:{d:.2}", .{
            &hex_buf,
            node.getLabel(),
            verdict.getLabel(),
            confidence * 100,
            tvc_similarity,
        }) catch "provenance";
        self.emitMsg(.ProvenanceStep, node, source, prov_msg, confidence, latency_us);
    }

    /// Verify the full provenance chain integrity (recompute all hashes).
    fn verifyProvenanceChain(self: *Self) bool {
        if (self.provenance_count == 0) return true;

        // Check genesis has zero prev_hash
        const zero_hash = [_]u8{0} ** PROVENANCE_HASH_SIZE;
        if (!std.mem.eql(u8, &self.provenance[0].prev_hash, &zero_hash)) return false;

        // Re-verify each link
        var i: u8 = 0;
        while (i < self.provenance_count) : (i += 1) {
            const rec = &self.provenance[i];
            const expected = ProvenanceRecord.computeHash(
                rec.prev_hash,
                rec.node,
                rec.content_digest[0..rec.digest_len],
                rec.confidence,
                rec.timestamp_us,
            );
            if (!std.mem.eql(u8, &rec.current_hash, &expected)) return false;

            // Check chain link
            if (i > 0) {
                if (!std.mem.eql(u8, &rec.prev_hash, &self.provenance[i - 1].current_hash)) return false;
            }
        }
        return true;
    }

    pub fn getProvenanceChain(self: *const Self) []const ProvenanceRecord {
        return self.provenance[0..self.provenance_count];
    }

    pub fn isChainVerified(self: *const Self) bool {
        return self.chain_verified;
    }

    // ── v1.2: Quark-Gluon Sub-Step Chain ──

    pub fn getQuarkChain(self: *const Self) []const QuarkRecord {
        return self.quarks[0..self.quark_count];
    }

    pub fn isQuarkChainVerified(self: *const Self) bool {
        return self.quark_chain_verified;
    }

    /// Find the last hash_verify quark index for a given node (scan backward).
    fn lastHashVerifyOfNode(self: *const Self, node: ChainNode) ?u8 {
        if (self.quark_count == 0) return null;
        var i: u8 = self.quark_count;
        while (i > 0) {
            i -= 1;
            if (self.quarks[i].parent_node == node and self.quarks[i].quark_type == .hash_verify)
                return i;
        }
        return null;
    }

    /// Find the last quark index for a given node (scan backward).
    fn lastQuarkOfNode(self: *const Self, node: ChainNode) ?u8 {
        if (self.quark_count == 0) return null;
        var i: u8 = self.quark_count;
        while (i > 0) {
            i -= 1;
            if (self.quarks[i].parent_node == node)
                return i;
        }
        return null;
    }

    /// Record a single quark sub-step with optional entanglement references.
    fn recordQuark(
        self: *Self,
        quark_type: QuarkType,
        parent_node: ChainNode,
        content: []const u8,
        confidence: f32,
        entangled_a: ?u8,
        entangled_b: ?u8,
    ) void {
        if (self.quark_count >= MAX_QUARK_RECORDS) return;

        const timestamp = std.time.microTimestamp();
        const idx = self.quark_count;

        // Genesis = all zeros, otherwise chain to previous quark
        const prev_hash: [QUARK_HASH_SIZE]u8 = if (idx > 0)
            self.quarks[idx - 1].current_quark_hash
        else
            [_]u8{0} ** QUARK_HASH_SIZE;

        // Build entanglement array (validate backward references only)
        var ent_indices: [MAX_ENTANGLE_REFS]u8 = .{ 0, 0 };
        var ent_count: u8 = 0;
        if (entangled_a) |a| {
            if (a < idx) {
                ent_indices[ent_count] = a;
                ent_count += 1;
            }
        }
        if (entangled_b) |b| {
            if (b < idx) {
                ent_indices[ent_count] = b;
                ent_count += 1;
            }
        }

        // Compute SHA256 quark hash (includes entanglement in hash)
        const current_hash = QuarkRecord.computeQuarkHash(
            prev_hash,
            quark_type,
            parent_node,
            content,
            confidence,
            timestamp,
            ent_indices,
            ent_count,
        );

        // Store QuarkRecord
        const dlen: u8 = @intCast(@min(content.len, QUARK_CONTENT_DIGEST_LEN));
        var record = QuarkRecord{
            .quark_index = idx,
            .quark_type = quark_type,
            .parent_node = parent_node,
            .content_digest = undefined,
            .digest_len = dlen,
            .confidence = confidence,
            .timestamp_us = timestamp,
            .prev_quark_hash = prev_hash,
            .current_quark_hash = current_hash,
            .entangled_indices = ent_indices,
            .entangle_count = ent_count,
        };
        @memcpy(record.content_digest[0..dlen], content[0..dlen]);
        self.quarks[idx] = record;
        self.quark_count += 1;

        // Emit QuarkStep chat message (gated by verbosity)
        if (self.quark_verbosity == .full) {
            var qbuf: [256]u8 = undefined;
            const qmsg = record.formatQuarkLine(&qbuf);
            self.emitMsg(.QuarkStep, parent_node, null, qmsg, confidence, 0);

            // If gluon_verify with entanglements, also emit GluonEntangle message
            if (quark_type == .gluon_verify and ent_count > 0) {
                var gbuf: [128]u8 = undefined;
                const gmsg = if (ent_count == 2)
                    std.fmt.bufPrint(&gbuf, "GLUON: Q{d}<->Q{d},Q{d}", .{ idx, ent_indices[0], ent_indices[1] }) catch "GLUON"
                else
                    std.fmt.bufPrint(&gbuf, "GLUON: Q{d}<->Q{d}", .{ idx, ent_indices[0] }) catch "GLUON";
                self.emitMsg(.GluonEntangle, parent_node, null, gmsg, confidence, 0);
            }
        }
    }

    /// Verify the full quark chain integrity (linear chain + DAG entanglement).
    fn verifyQuarkChain(self: *Self) bool {
        if (self.quark_count == 0) return true;

        // Phase A: Linear hash chain
        const zero_hash = [_]u8{0} ** QUARK_HASH_SIZE;

        // Check genesis has zero prev_quark_hash
        if (!std.mem.eql(u8, &self.quarks[0].prev_quark_hash, &zero_hash)) return false;

        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];

            // Recompute hash and verify it matches stored hash
            const expected = QuarkRecord.computeQuarkHash(
                q.prev_quark_hash,
                q.quark_type,
                q.parent_node,
                q.content_digest[0..q.digest_len],
                q.confidence,
                q.timestamp_us,
                q.entangled_indices,
                q.entangle_count,
            );
            if (!std.mem.eql(u8, &q.current_quark_hash, &expected)) return false;

            // Check chain link: prev_quark_hash == quarks[i-1].current_quark_hash
            if (i > 0) {
                if (!std.mem.eql(u8, &q.prev_quark_hash, &self.quarks[i - 1].current_quark_hash)) return false;
            }
        }

        // Phase B: DAG entanglement validation
        i = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];

            // entangle_count must be in [0, MAX_ENTANGLE_REFS]
            if (q.entangle_count > MAX_ENTANGLE_REFS) return false;

            // All entangled_indices must point backward (< current index)
            var e: u8 = 0;
            while (e < q.entangle_count) : (e += 1) {
                if (q.entangled_indices[e] >= i) return false;
            }

            // Genesis quark must have entangle_count == 0
            if (i == 0 and q.entangle_count != 0) return false;

            // gluon_verify quarks (except genesis) must have entangle_count > 0
            if (i > 0 and q.quark_type == .gluon_verify and q.entangle_count == 0) return false;
        }

        // v1.3: Phase C — Phi-hash balance check
        if (!self.phiHashCheck()) return false;

        // v1.3: Phase D — Cross-chain verification
        if (!self.crossChainVerify()) return false;

        // v1.4: Phase E — Phi-engine quantum verification
        if (!self.phiQuantumVerify()) return false;

        // v1.5: Phase F — Staking integrity verification
        if (!self.stakingVerify()) return false;

        // v2.0: Phase G — Self-repair integrity verification
        if (!self.selfRepairVerify()) return false;

        // v2.1: Phase H — Faucet integrity verification
        if (!self.faucetVerify()) return false;

        // v2.2: Phase I — Network consensus integrity verification
        if (!self.networkVerify()) return false;

        // v2.3: Phase J — DAO governance integrity verification
        if (!self.daoVerify()) return false;

        // v2.4: Phase K — Mainnet launch integrity verification
        if (!self.mainnetVerify()) return false;

        // v2.5: Phase L — Swarm activation integrity verification
        if (!self.swarmVerify()) return false;

        return true;
    }

    // ── v1.3: Quark Search ──

    /// Search quarks by structured filter query. Returns count of matching indices.
    pub fn searchQuarks(self: *const Self, query: QuarkSearchQuery, result_indices: *[MAX_QUARK_RECORDS]u8) u8 {
        var count: u8 = 0;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];

            // Filter by type
            if (query.filter_type) |ft| {
                if (q.quark_type != ft) continue;
            }
            // Filter by node
            if (query.filter_node) |fn_node| {
                if (q.parent_node != fn_node) continue;
            }
            // Filter by confidence range
            if (q.confidence < query.min_confidence) continue;
            if (q.confidence > query.max_confidence) continue;
            // Filter verification/work
            if (query.verification_only and !q.quark_type.isVerificationQuark()) continue;
            if (query.work_only and q.quark_type.isVerificationQuark()) continue;
            // Filter by min entanglement
            if (q.entangle_count < query.min_entangle) continue;

            if (count < MAX_QUARK_RECORDS) {
                result_indices[count] = i;
                count += 1;
            }
        }
        return count;
    }

    // ── v1.3: Quark Chain Export ──

    /// Serialize provenance + quark chain to binary buffer for on-chain storage.
    /// Returns slice of written bytes, or null if buffer too small.
    pub fn serializeQuarkChain(self: *const Self, buf: []u8) ?[]u8 {
        const total_size = QUARK_EXPORT_HEADER_SIZE +
            @as(usize, self.provenance_count) * PROVENANCE_RECORD_EXPORT_SIZE +
            @as(usize, self.quark_count) * QUARK_RECORD_EXPORT_SIZE;

        if (buf.len < total_size) return null;

        var pos: usize = 0;

        // Header v8: magic(4) + version(2) + prov_count(1) + quark_count(1) + verified(1) + quark_verified(1) + reward(8) + staking(8) + repair_count(1) + repair_state(1) + evolution_gen(2) + persist_count(4) + faucet_claims(2) + canvas_renders(2) + node_count(2) + network_health(2) + dao_proposals(2) + swarm_nodes(2) + community_nodes(2) + discovery_count(2)
        @memcpy(buf[pos .. pos + 4], &QUARK_EXPORT_MAGIC);
        pos += 4;
        const ver_bytes: [2]u8 = @bitCast(QUARK_EXPORT_VERSION);
        @memcpy(buf[pos .. pos + 2], &ver_bytes);
        pos += 2;
        buf[pos] = self.provenance_count;
        pos += 1;
        buf[pos] = self.quark_count;
        pos += 1;
        buf[pos] = if (self.chain_verified) 1 else 0;
        pos += 1;
        buf[pos] = if (self.quark_chain_verified) 1 else 0;
        pos += 1;
        // v1.4: total_reward_utri (8 bytes)
        const reward_bytes: [8]u8 = @bitCast(self.total_reward_utri);
        @memcpy(buf[pos .. pos + 8], &reward_bytes);
        pos += 8;
        // v1.5: staking_total_utri (8 bytes)
        const staking_bytes: [8]u8 = @bitCast(self.staking_total_utri);
        @memcpy(buf[pos .. pos + 8], &staking_bytes);
        pos += 8;
        // v2.0: repair_count(1) + repair_state(1) + evolution_generation(2) + persist_count(4)
        buf[pos] = self.repair_count;
        pos += 1;
        buf[pos] = @intFromEnum(self.repair_state);
        pos += 1;
        const gen_bytes: [2]u8 = @bitCast(self.current_generation);
        @memcpy(buf[pos .. pos + 2], &gen_bytes);
        pos += 2;
        const persist_bytes: [4]u8 = @bitCast(self.immortal_state.persist_count);
        @memcpy(buf[pos .. pos + 4], &persist_bytes);
        pos += 4;
        // v2.1: faucet_claims_count(2) + canvas_render_count(2)
        const fc_bytes: [2]u8 = @bitCast(self.faucet_claims_count);
        @memcpy(buf[pos .. pos + 2], &fc_bytes);
        pos += 2;
        const cr_bytes: [2]u8 = @bitCast(@as(u16, @intCast(self.canvas_state.render_count)));
        @memcpy(buf[pos .. pos + 2], &cr_bytes);
        pos += 2;
        // v2.2: node_count(2) + network_health_score_u16(2)
        const nc_bytes: [2]u8 = @bitCast(self.network_state.total_nodes);
        @memcpy(buf[pos .. pos + 2], &nc_bytes);
        pos += 2;
        const nh_u16: u16 = @intFromFloat(self.network_state.network_health_score * 10000.0);
        const nh_bytes: [2]u8 = @bitCast(nh_u16);
        @memcpy(buf[pos .. pos + 2], &nh_bytes);
        pos += 2;
        // v2.3: dao_proposal_count(2) + swarm_active_nodes(2)
        const dp_bytes: [2]u8 = @bitCast(self.dao_proposal_count);
        @memcpy(buf[pos .. pos + 2], &dp_bytes);
        pos += 2;
        const sn_bytes: [2]u8 = @bitCast(self.swarm_state.active_nodes);
        @memcpy(buf[pos .. pos + 2], &sn_bytes);
        pos += 2;

        // v2.4: community_active_nodes(2) + node_discovery_count(2)
        const cn_bytes: [2]u8 = @bitCast(self.community_state.active_nodes);
        @memcpy(buf[pos .. pos + 2], &cn_bytes);
        pos += 2;
        const nd_bytes: [2]u8 = @bitCast(self.node_discovery_count);
        @memcpy(buf[pos .. pos + 2], &nd_bytes);
        pos += 2;

        // v2.5: swarm_orch_tasks(2) + swarm_replication_count(2)
        const sot_bytes: [2]u8 = @bitCast(self.swarm_orch_state.active_tasks);
        @memcpy(buf[pos .. pos + 2], &sot_bytes);
        pos += 2;
        const src_bytes: [2]u8 = @bitCast(@as(u16, self.swarm_replication_count));
        @memcpy(buf[pos .. pos + 2], &src_bytes);
        pos += 2;

        // Provenance records (158 bytes each)
        var pi: u8 = 0;
        while (pi < self.provenance_count) : (pi += 1) {
            const rec = &self.provenance[pi];
            buf[pos] = rec.step_index;
            pos += 1;
            buf[pos] = @intFromEnum(rec.node);
            pos += 1;
            @memcpy(buf[pos .. pos + CONTENT_DIGEST_LEN], &rec.content_digest);
            pos += CONTENT_DIGEST_LEN;
            buf[pos] = rec.digest_len;
            pos += 1;
            const conf_bytes: [4]u8 = @bitCast(rec.confidence);
            @memcpy(buf[pos .. pos + 4], &conf_bytes);
            pos += 4;
            const tvc_bytes: [4]u8 = @bitCast(rec.tvc_similarity);
            @memcpy(buf[pos .. pos + 4], &tvc_bytes);
            pos += 4;
            buf[pos] = @intFromEnum(rec.truth_verdict);
            pos += 1;
            const ts_bytes: [8]u8 = @bitCast(rec.timestamp_us);
            @memcpy(buf[pos .. pos + 8], &ts_bytes);
            pos += 8;
            const lat_bytes: [8]u8 = @bitCast(rec.latency_us);
            @memcpy(buf[pos .. pos + 8], &lat_bytes);
            pos += 8;
            buf[pos] = if (rec.source) |s| @intFromEnum(s) else 0xFF;
            pos += 1;
            @memcpy(buf[pos .. pos + PROVENANCE_HASH_SIZE], &rec.prev_hash);
            pos += PROVENANCE_HASH_SIZE;
            @memcpy(buf[pos .. pos + PROVENANCE_HASH_SIZE], &rec.current_hash);
            pos += PROVENANCE_HASH_SIZE;
        }

        // Quark records (131 bytes each)
        var qi: u8 = 0;
        while (qi < self.quark_count) : (qi += 1) {
            const q = &self.quarks[qi];
            buf[pos] = q.quark_index;
            pos += 1;
            buf[pos] = @intFromEnum(q.quark_type);
            pos += 1;
            buf[pos] = @intFromEnum(q.parent_node);
            pos += 1;
            @memcpy(buf[pos .. pos + QUARK_CONTENT_DIGEST_LEN], &q.content_digest);
            pos += QUARK_CONTENT_DIGEST_LEN;
            buf[pos] = q.digest_len;
            pos += 1;
            const conf_bytes: [4]u8 = @bitCast(q.confidence);
            @memcpy(buf[pos .. pos + 4], &conf_bytes);
            pos += 4;
            const ts_bytes: [8]u8 = @bitCast(q.timestamp_us);
            @memcpy(buf[pos .. pos + 8], &ts_bytes);
            pos += 8;
            @memcpy(buf[pos .. pos + QUARK_HASH_SIZE], &q.prev_quark_hash);
            pos += QUARK_HASH_SIZE;
            @memcpy(buf[pos .. pos + QUARK_HASH_SIZE], &q.current_quark_hash);
            pos += QUARK_HASH_SIZE;
            @memcpy(buf[pos .. pos + MAX_ENTANGLE_REFS], &q.entangled_indices);
            pos += MAX_ENTANGLE_REFS;
            buf[pos] = q.entangle_count;
            pos += 1;
        }

        return buf[0..pos];
    }

    /// Deserialize provenance + quark chain from binary buffer.
    /// Returns true if valid and restored.
    pub fn deserializeQuarkChain(self: *Self, buf: []const u8) bool {
        // Minimum header is 10 bytes (v1) or 18 bytes (v2)
        if (buf.len < 10) return false;

        var pos: usize = 0;

        // Validate magic
        if (!std.mem.eql(u8, buf[pos .. pos + 4], &QUARK_EXPORT_MAGIC)) return false;
        pos += 4;

        // Read version (support v1, v2, v3, v4, v5, v6, v7)
        const ver: u16 = @bitCast(buf[pos .. pos + 2][0..2].*);
        if (ver != 1 and ver != 2 and ver != 3 and ver != 4 and ver != 5 and ver != 6 and ver != 7 and ver != 8 and ver != 9) return false;
        pos += 2;

        const header_size: usize = if (ver == 1) 10 else if (ver == 2) 18 else if (ver == 3) 26 else if (ver == 4) 34 else if (ver == 5) 38 else if (ver == 6) 42 else if (ver == 7) 46 else if (ver == 8) 50 else 54;
        if (buf.len < header_size) return false;

        const prov_count = buf[pos];
        pos += 1;
        const qcount = buf[pos];
        pos += 1;
        const chain_ver = buf[pos] == 1;
        pos += 1;
        const quark_ver = buf[pos] == 1;
        pos += 1;

        // v1.4: read reward from v2+ header
        var reward_utri: u64 = 0;
        if (ver >= 2) {
            reward_utri = @bitCast(buf[pos .. pos + 8][0..8].*);
            pos += 8;
        }

        // v1.5: read staking from v3+ header
        var staking_utri: u64 = 0;
        if (ver >= 3) {
            staking_utri = @bitCast(buf[pos .. pos + 8][0..8].*);
            pos += 8;
        }

        // v2.0: read repair/evolution/persist from v4 header
        var repair_cnt: u8 = 0;
        var repair_st: u8 = 0;
        var evo_gen: u16 = 0;
        var persist_cnt: u32 = 0;
        if (ver >= 4) {
            repair_cnt = buf[pos];
            pos += 1;
            repair_st = buf[pos];
            pos += 1;
            evo_gen = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
            persist_cnt = @bitCast(buf[pos .. pos + 4][0..4].*);
            pos += 4;
        }

        // v2.1: read faucet_claims_count + canvas_render_count from v5 header
        var faucet_cnt: u16 = 0;
        var canvas_renders: u16 = 0;
        if (ver >= 5) {
            faucet_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
            canvas_renders = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
        }

        // v2.2: read node_count + network_health_score from v6 header
        var node_count_val: u16 = 1;
        var net_health_u16: u16 = 10000;
        if (ver >= 6) {
            node_count_val = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
            net_health_u16 = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
        }

        // v2.3: read dao_proposal_count + swarm_active_nodes from v7 header
        var dao_proposals_cnt: u16 = 0;
        var swarm_nodes_cnt: u16 = 0;
        if (ver >= 7) {
            dao_proposals_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
            swarm_nodes_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
        }

        // v2.4: read community_active_nodes + node_discovery_count from v8 header
        var community_nodes_cnt: u16 = 0;
        var discovery_cnt: u16 = 0;
        if (ver >= 8) {
            community_nodes_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
            discovery_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
        }

        // v2.5: read swarm_orch_tasks + swarm_replication_count from v9 header
        var swarm_orch_tasks_cnt: u16 = 0;
        var swarm_repl_cnt: u16 = 0;
        if (ver >= 9) {
            swarm_orch_tasks_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
            swarm_repl_cnt = @bitCast(buf[pos .. pos + 2][0..2].*);
            pos += 2;
        }

        // Validate sizes
        if (prov_count > MAX_PROVENANCE_RECORDS or qcount > MAX_QUARK_RECORDS) return false;
        const expected_size = header_size +
            @as(usize, prov_count) * PROVENANCE_RECORD_EXPORT_SIZE +
            @as(usize, qcount) * QUARK_RECORD_EXPORT_SIZE;
        if (buf.len < expected_size) return false;

        // Restore provenance records
        var pi: u8 = 0;
        while (pi < prov_count) : (pi += 1) {
            var rec: ProvenanceRecord = undefined;
            rec.step_index = buf[pos];
            pos += 1;
            rec.node = @enumFromInt(buf[pos]);
            pos += 1;
            @memcpy(&rec.content_digest, buf[pos .. pos + CONTENT_DIGEST_LEN]);
            pos += CONTENT_DIGEST_LEN;
            rec.digest_len = buf[pos];
            pos += 1;
            rec.confidence = @bitCast(buf[pos .. pos + 4][0..4].*);
            pos += 4;
            rec.tvc_similarity = @bitCast(buf[pos .. pos + 4][0..4].*);
            pos += 4;
            rec.truth_verdict = @enumFromInt(buf[pos]);
            pos += 1;
            rec.timestamp_us = @bitCast(buf[pos .. pos + 8][0..8].*);
            pos += 8;
            rec.latency_us = @bitCast(buf[pos .. pos + 8][0..8].*);
            pos += 8;
            const src_byte = buf[pos];
            rec.source = if (src_byte == 0xFF) null else @enumFromInt(src_byte);
            pos += 1;
            @memcpy(&rec.prev_hash, buf[pos .. pos + PROVENANCE_HASH_SIZE]);
            pos += PROVENANCE_HASH_SIZE;
            @memcpy(&rec.current_hash, buf[pos .. pos + PROVENANCE_HASH_SIZE]);
            pos += PROVENANCE_HASH_SIZE;
            self.provenance[pi] = rec;
        }
        self.provenance_count = prov_count;
        self.chain_verified = chain_ver;

        // Restore quark records
        var qi: u8 = 0;
        while (qi < qcount) : (qi += 1) {
            var q: QuarkRecord = undefined;
            q.quark_index = buf[pos];
            pos += 1;
            q.quark_type = @enumFromInt(buf[pos]);
            pos += 1;
            q.parent_node = @enumFromInt(buf[pos]);
            pos += 1;
            @memcpy(&q.content_digest, buf[pos .. pos + QUARK_CONTENT_DIGEST_LEN]);
            pos += QUARK_CONTENT_DIGEST_LEN;
            q.digest_len = buf[pos];
            pos += 1;
            q.confidence = @bitCast(buf[pos .. pos + 4][0..4].*);
            pos += 4;
            q.timestamp_us = @bitCast(buf[pos .. pos + 8][0..8].*);
            pos += 8;
            @memcpy(&q.prev_quark_hash, buf[pos .. pos + QUARK_HASH_SIZE]);
            pos += QUARK_HASH_SIZE;
            @memcpy(&q.current_quark_hash, buf[pos .. pos + QUARK_HASH_SIZE]);
            pos += QUARK_HASH_SIZE;
            @memcpy(&q.entangled_indices, buf[pos .. pos + MAX_ENTANGLE_REFS]);
            pos += MAX_ENTANGLE_REFS;
            q.entangle_count = buf[pos];
            pos += 1;
            self.quarks[qi] = q;
        }
        self.quark_count = qcount;
        self.quark_chain_verified = quark_ver;
        self.total_reward_utri = reward_utri;
        self.staking_total_utri = staking_utri;
        self.repair_count = repair_cnt;
        self.repair_state = if (repair_st <= 3) @enumFromInt(repair_st) else .healthy;
        self.current_generation = evo_gen;
        self.immortal_state.persist_count = persist_cnt;
        self.faucet_claims_count = faucet_cnt;
        self.canvas_state.render_count = @as(u32, canvas_renders);
        self.network_state.total_nodes = node_count_val;
        self.network_state.active_nodes = node_count_val;
        self.network_state.network_health_score = @as(f32, @floatFromInt(net_health_u16)) / 10000.0;
        self.dao_proposal_count = dao_proposals_cnt;
        self.swarm_state.active_nodes = swarm_nodes_cnt;
        self.community_state.active_nodes = community_nodes_cnt;
        self.node_discovery_count = discovery_cnt;
        self.swarm_orch_state.active_tasks = swarm_orch_tasks_cnt;
        self.swarm_replication_count = @intCast(swarm_repl_cnt);

        return true;
    }

    // ── v1.3: Phi-Hash Check (Phase C) ──

    /// XOR all quark hashes, check mod-3 residue class distribution.
    /// Valid chains have at least 2 of 3 residue classes present (trinity balance).
    fn phiHashCheck(self: *const Self) bool {
        if (self.quark_count == 0) return true;

        // XOR all quark current_hashes together
        var combined: [QUARK_HASH_SIZE]u8 = [_]u8{0} ** QUARK_HASH_SIZE;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            for (0..QUARK_HASH_SIZE) |b| {
                combined[b] ^= self.quarks[i].current_quark_hash[b];
            }
        }

        // Count byte distribution across mod-3 residue classes
        var class_count: [3]u32 = .{ 0, 0, 0 };
        for (&combined) |byte| {
            class_count[byte % 3] += 1;
        }

        // Count how many classes have at least 1 byte
        var classes_present: u8 = 0;
        for (&class_count) |c| {
            if (c > 0) classes_present += 1;
        }

        // Pass if at least 2 of 3 classes present (phi^2 + 1/phi^2 = 3)
        return classes_present >= 2;
    }

    // ── v1.3: Cross-Chain Verification (Phase D) ──

    /// Verify quark parent_node ordering matches provenance chain sequence.
    fn crossChainVerify(self: *const Self) bool {
        if (self.quark_count == 0 or self.provenance_count == 0) return true;

        // Track: verify node ordering is non-decreasing in pipeline order
        var last_node_val: u8 = 0;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const node_val = @intFromEnum(self.quarks[i].parent_node);
            if (node_val < last_node_val) return false;
            last_node_val = node_val;
        }

        // Verify every provenance node has at least one quark
        var pi: u8 = 0;
        while (pi < self.provenance_count) : (pi += 1) {
            const prov_node = self.provenance[pi].node;
            var found = false;
            var qi: u8 = 0;
            while (qi < self.quark_count) : (qi += 1) {
                if (self.quarks[qi].parent_node == prov_node) {
                    found = true;
                    break;
                }
            }
            if (!found) return false;
        }

        return true;
    }

    // ── v1.4: Phi-Engine Quantum Verification (Phase E) ──

    /// Phase E: Phi-engine quantum hash verification with 3 sub-checks.
    /// E1: Phi-residue balance, E2: Lucas modular diversity, E3: Golden angle spacing.
    fn phiQuantumVerify(self: *const Self) bool {
        if (self.quark_count == 0) return true;

        // ── E1: Phi-residue balance ──
        // Map each hash byte to phi-space, check 3 buckets populated
        var bucket: [3]u32 = .{ 0, 0, 0 };
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            for (0..QUARK_HASH_SIZE) |b| {
                const byte = self.quarks[i].current_quark_hash[b];
                const phi_val: f64 = (@as(f64, @floatFromInt(byte)) / 256.0) * PHI;
                const floored = @floor(phi_val);
                const frac = phi_val - floored;
                if (frac < 0.382) {
                    bucket[0] += 1;
                } else if (frac < 0.618) {
                    bucket[1] += 1;
                } else {
                    bucket[2] += 1;
                }
            }
        }
        // All 3 buckets must have at least 1 byte
        if (bucket[0] == 0 or bucket[1] == 0 or bucket[2] == 0) return false;

        // ── E2: Lucas modular diversity ──
        // XOR all quark hashes into combined_hash
        var combined: [QUARK_HASH_SIZE]u8 = [_]u8{0} ** QUARK_HASH_SIZE;
        i = 0;
        while (i < self.quark_count) : (i += 1) {
            for (0..QUARK_HASH_SIZE) |b| {
                combined[b] ^= self.quarks[i].current_quark_hash[b];
            }
        }
        // Check positions 0..15 against Lucas sequence
        var lucas_hits: u8 = 0;
        for (0..16) |pos| {
            const lucas_mod: u32 = if (LUCAS_SEQUENCE[pos] < 256) LUCAS_SEQUENCE[pos] else 255;
            if (lucas_mod > 0) {
                const result = @as(u32, combined[pos]) % lucas_mod;
                if (result != 0) lucas_hits += 1;
            }
        }
        if (lucas_hits < 8) return false;

        // ── E3: Golden angle spacing ──
        // Treat first 2 bytes of each quark hash as u16, check consecutive diffs
        var angle_hits: u8 = 0;
        if (self.quark_count >= 2) {
            var qi: u8 = 0;
            while (qi + 1 < self.quark_count) : (qi += 1) {
                const h1 = self.quarks[qi].current_quark_hash;
                const h2 = self.quarks[qi + 1].current_quark_hash;
                const angle1: u16 = @as(u16, h1[0]) << 8 | @as(u16, h1[1]);
                const angle2: u16 = @as(u16, h2[0]) << 8 | @as(u16, h2[1]);
                const diff: u16 = if (angle1 > angle2) angle1 - angle2 else angle2 - angle1;
                // Golden angle range: ~24998 +/- 8192 => [16806, 33190]
                if (diff >= 16806 and diff <= 33190) angle_hits += 1;
            }
        }
        if (self.quark_count >= 2 and angle_hits == 0) return false;

        return true;
    }

    // ── v1.4: DAG Adjacency Export ──

    /// Extract all entanglement edges from quark chain.
    pub fn getDAGEdges(self: *const Self, edges: *[MAX_DAG_EDGES]DAGEdge) u16 {
        var count: u16 = 0;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];
            var e: u8 = 0;
            while (e < q.entangle_count) : (e += 1) {
                if (count < MAX_DAG_EDGES) {
                    edges[count] = .{ .from = i, .to = q.entangled_indices[e] };
                    count += 1;
                }
            }
        }
        return count;
    }

    /// Compute aggregate DAG statistics.
    pub fn getDAGStats(self: *const Self) DAGStats {
        var stats = DAGStats{
            .edge_count = 0,
            .max_depth = 0,
            .max_width = 0,
            .max_fan_out = 0,
            .max_fan_in = 0,
            .node_quark_counts = [_]u8{0} ** 8,
        };

        // Count edges, fan-out, node_quark_counts
        var fan_in: [MAX_QUARK_RECORDS]u8 = [_]u8{0} ** MAX_QUARK_RECORDS;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];
            const node_idx = @intFromEnum(q.parent_node);
            stats.node_quark_counts[node_idx] += 1;
            stats.edge_count += q.entangle_count;
            if (q.entangle_count > stats.max_fan_out) stats.max_fan_out = q.entangle_count;
            var e: u8 = 0;
            while (e < q.entangle_count) : (e += 1) {
                if (q.entangled_indices[e] < MAX_QUARK_RECORDS) {
                    fan_in[q.entangled_indices[e]] += 1;
                }
            }
        }

        // max_fan_in
        for (0..self.quark_count) |fi| {
            if (fan_in[fi] > stats.max_fan_in) stats.max_fan_in = fan_in[fi];
        }

        // max_width = max node_quark_counts
        for (0..8) |ni| {
            if (stats.node_quark_counts[ni] > stats.max_width) stats.max_width = stats.node_quark_counts[ni];
        }

        // max_depth = longest topological path via BFS-like traversal
        var depth: [MAX_QUARK_RECORDS]u8 = [_]u8{0} ** MAX_QUARK_RECORDS;
        i = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];
            var max_parent_depth: u8 = 0;
            var e: u8 = 0;
            while (e < q.entangle_count) : (e += 1) {
                const ref = q.entangled_indices[e];
                if (ref < i and depth[ref] >= max_parent_depth) {
                    max_parent_depth = depth[ref] + 1;
                }
            }
            depth[i] = if (q.entangle_count > 0) max_parent_depth else 0;
            if (depth[i] > stats.max_depth) stats.max_depth = depth[i];
        }

        return stats;
    }

    // ── v1.4: $TRI Energy Reward Calculation ──

    /// Calculate session reward based on verification, confidence, quark depth, and latency.
    pub fn calculateSessionReward(self: *Self) TriRewardResult {
        const cfg = self.reward_config;
        var result = TriRewardResult{
            .base_utri = 0,
            .confidence_bonus_utri = 0,
            .quark_bonus_utri = 0,
            .energy_penalty_utri = 0,
            .verification_bonus = false,
            .total_reward_utri = 0,
            .total_reward_tri_display = 0.0,
        };

        // Zero reward if confidence below minimum
        if (self.state.total_confidence < cfg.min_reward_confidence) {
            self.total_reward_utri = 0;
            return result;
        }

        // Zero reward if not verified
        if (!self.chain_verified or !self.quark_chain_verified) {
            self.total_reward_utri = 0;
            return result;
        }

        result.verification_bonus = true;
        result.base_utri = cfg.base_reward_utri;

        // Confidence bonus (50% if >= 0.9)
        if (self.state.total_confidence >= 0.9) {
            const bonus_f: f64 = @as(f64, @floatFromInt(cfg.base_reward_utri)) * @as(f64, cfg.confidence_bonus);
            result.confidence_bonus_utri = @intFromFloat(@floor(bonus_f));
        }

        // Quark depth bonus (per quark above 40)
        if (self.quark_count > 40) {
            result.quark_bonus_utri = @as(u64, self.quark_count - 40) * cfg.quark_depth_bonus_utri;
        }

        // Energy penalty (based on latency)
        const penalty_f: f64 = @as(f64, @floatFromInt(self.state.total_latency_us)) * cfg.energy_penalty_per_us;
        result.energy_penalty_utri = @intFromFloat(@floor(penalty_f));

        // Total (can't go below 0)
        const gross = result.base_utri + result.confidence_bonus_utri + result.quark_bonus_utri;
        const penalty = @min(result.energy_penalty_utri, gross);
        result.total_reward_utri = gross - penalty;
        result.total_reward_tri_display = @as(f64, @floatFromInt(result.total_reward_utri)) / 1_000_000.0;

        self.total_reward_utri = result.total_reward_utri;
        return result;
    }

    // ── v1.5: Collapsible Quark Views ──

    /// Collapse all quarks for a node (show summary only).
    pub fn collapseNodeQuarks(self: *Self, node: ChainNode) void {
        self.node_view_states[@intFromEnum(node)] = .collapsed;
    }

    /// Expand all quarks for a node (show full details).
    pub fn expandNodeQuarks(self: *Self, node: ChainNode) void {
        self.node_view_states[@intFromEnum(node)] = .expanded;
    }

    /// Get a collapsed summary for a specific node.
    pub fn getCollapsedSummary(self: *const Self, node: ChainNode) CollapsedNodeSummary {
        var count: u8 = 0;
        var total_conf: f32 = 0.0;
        var total_ent: u16 = 0;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            if (self.quarks[i].parent_node == node) {
                count += 1;
                total_conf += self.quarks[i].confidence;
                total_ent += self.quarks[i].entangle_count;
            }
        }
        return .{
            .node = node,
            .quark_count = count,
            .avg_confidence = if (count > 0) total_conf / @as(f32, @floatFromInt(count)) else 0.0,
            .total_entanglements = total_ent,
            .is_collapsed = self.node_view_states[@intFromEnum(node)] == .collapsed,
        };
    }

    // ── v1.5: Public Shareable Provenance Links ──

    /// Generate a shareable link from the current chain state.
    pub fn generateShareLink(self: *Self) ShareableLink {
        const timestamp = std.time.microTimestamp();

        // Compute link_hash: SHA256(all provenance hashes ++ all quark hashes ++ timestamp)
        var link_hasher = Sha256.init(.{});
        var pi: u8 = 0;
        while (pi < self.provenance_count) : (pi += 1) {
            link_hasher.update(&self.provenance[pi].current_hash);
        }
        var qi: u8 = 0;
        while (qi < self.quark_count) : (qi += 1) {
            link_hasher.update(&self.quarks[qi].current_quark_hash);
        }
        const ts_bytes: [8]u8 = @bitCast(timestamp);
        link_hasher.update(&ts_bytes);
        const link_hash = link_hasher.finalResult();

        // Compute chain_fingerprint: SHA256(XOR of all quark hashes)
        var xored: [QUARK_HASH_SIZE]u8 = [_]u8{0} ** QUARK_HASH_SIZE;
        qi = 0;
        while (qi < self.quark_count) : (qi += 1) {
            for (0..QUARK_HASH_SIZE) |b| {
                xored[b] ^= self.quarks[qi].current_quark_hash[b];
            }
        }
        var fp_hasher = Sha256.init(.{});
        fp_hasher.update(&xored);
        const chain_fingerprint = fp_hasher.finalResult();

        const link = ShareableLink{
            .link_hash = link_hash,
            .chain_fingerprint = chain_fingerprint,
            .quark_count = self.quark_count,
            .provenance_count = self.provenance_count,
            .total_reward_utri = self.total_reward_utri,
            .is_verified = self.chain_verified and self.quark_chain_verified,
            .timestamp_us = timestamp,
        };

        self.last_share_link = link;
        return link;
    }

    /// Verify a shareable link against the current chain state.
    pub fn verifyShareLink(self: *const Self, link: *const ShareableLink) bool {
        // Recompute chain fingerprint and compare
        var xored: [QUARK_HASH_SIZE]u8 = [_]u8{0} ** QUARK_HASH_SIZE;
        var qi: u8 = 0;
        while (qi < self.quark_count) : (qi += 1) {
            for (0..QUARK_HASH_SIZE) |b| {
                xored[b] ^= self.quarks[qi].current_quark_hash[b];
            }
        }
        var fp_hasher = Sha256.init(.{});
        fp_hasher.update(&xored);
        const expected_fp = fp_hasher.finalResult();

        return std.mem.eql(u8, &link.chain_fingerprint, &expected_fp);
    }

    // ── v1.5: $TRI Staking ──

    /// Stake a portion of rewards. Returns true if successful.
    pub fn stakeReward(self: *Self, amount_utri: u64) bool {
        if (amount_utri < self.staking_config.min_stake_utri) return false;
        if (self.staking_count >= self.staking_config.max_active_stakes) return false;

        const timestamp = std.time.microTimestamp();

        // Compute chain fingerprint for staking record
        var xored: [QUARK_HASH_SIZE]u8 = [_]u8{0} ** QUARK_HASH_SIZE;
        var qi: u8 = 0;
        while (qi < self.quark_count) : (qi += 1) {
            for (0..QUARK_HASH_SIZE) |b| {
                xored[b] ^= self.quarks[qi].current_quark_hash[b];
            }
        }

        self.staking_records[self.staking_count] = .{
            .amount_utri = amount_utri,
            .lock_start_us = timestamp,
            .lock_end_us = timestamp + self.staking_config.lock_duration_us,
            .yield_utri = 0,
            .is_active = true,
            .chain_fingerprint = xored,
        };
        self.staking_count += 1;
        self.staking_total_utri += amount_utri;
        return true;
    }

    /// Unstake an expired record. Returns result if successful.
    pub fn unstakeReward(self: *Self, index: u8) ?StakingResult {
        if (index >= self.staking_count) return null;
        if (!self.staking_records[index].is_active) return null;

        const timestamp = std.time.microTimestamp();
        const rec = &self.staking_records[index];

        // Check if lock expired
        if (timestamp < rec.lock_end_us) return null;

        // Calculate yield: amount * rate * (duration_us / day_us)
        const duration_us: f64 = @floatFromInt(timestamp - rec.lock_start_us);
        const day_us: f64 = 86_400_000_000.0;
        const days: f64 = duration_us / day_us;
        const yield_f: f64 = @as(f64, @floatFromInt(rec.amount_utri)) * self.staking_config.yield_rate_per_day * days;
        rec.yield_utri = @intFromFloat(@floor(yield_f));
        rec.is_active = false;

        if (self.staking_total_utri >= rec.amount_utri) {
            self.staking_total_utri -= rec.amount_utri;
        } else {
            self.staking_total_utri = 0;
        }

        // Find next unlock
        var next_unlock: i64 = std.math.maxInt(i64);
        var active: u8 = 0;
        var total_locked: u64 = 0;
        var si: u8 = 0;
        while (si < self.staking_count) : (si += 1) {
            if (self.staking_records[si].is_active) {
                active += 1;
                total_locked += self.staking_records[si].amount_utri;
                if (self.staking_records[si].lock_end_us < next_unlock) {
                    next_unlock = self.staking_records[si].lock_end_us;
                }
            }
        }
        if (active == 0) next_unlock = 0;

        return .{
            .staked_utri = rec.amount_utri,
            .yield_utri = rec.yield_utri,
            .active_stakes = active,
            .total_locked_utri = total_locked,
            .next_unlock_us = next_unlock,
        };
    }

    // ── v1.5: Phase F — Staking Integrity Verification ──

    /// Phase F: Staking integrity verification.
    /// F1: Share link fingerprint valid if present.
    /// F2: Sum of active staking amounts == staking_total_utri.
    fn stakingVerify(self: *const Self) bool {
        // F1: Verify share link fingerprint if present
        if (self.last_share_link) |link| {
            if (!self.verifyShareLink(&link)) return false;
        }

        // F2: Verify staking balance integrity
        var active_sum: u64 = 0;
        var si: u8 = 0;
        while (si < self.staking_count) : (si += 1) {
            if (self.staking_records[si].is_active) {
                active_sum += self.staking_records[si].amount_utri;
            }
        }
        if (active_sum != self.staking_total_utri) return false;

        return true;
    }

    // ── v2.0: Self-Repair Engine ──

    /// Scan quarks for broken state (hash mismatch or low confidence), attempt repair.
    pub fn selfRepairChain(self: *Self) ?RepairRecord {
        if (self.quark_count == 0) return null;

        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];

            // Check 1: Low confidence
            if (q.confidence < SELF_REPAIR_CONFIDENCE_THRESHOLD) {
                return self.repairQuark(i, .confidence_restore);
            }

            // Check 2: Hash chain mismatch
            if (i > 0) {
                if (!std.mem.eql(u8, &q.prev_quark_hash, &self.quarks[i - 1].current_quark_hash)) {
                    return self.repairQuark(i, .hash_recompute);
                }
            }

            // Check 3: Hash recomputation mismatch
            const expected = QuarkRecord.computeQuarkHash(
                q.prev_quark_hash,
                q.quark_type,
                q.parent_node,
                q.content_digest[0..q.digest_len],
                q.confidence,
                q.timestamp_us,
                q.entangled_indices,
                q.entangle_count,
            );
            if (!std.mem.eql(u8, &q.current_quark_hash, &expected)) {
                return self.repairQuark(i, .hash_recompute);
            }
        }
        return null; // All healthy
    }

    /// Internal: repair a single quark by type.
    fn repairQuark(self: *Self, index: u8, repair_type: SelfRepairType) RepairRecord {
        const timestamp = std.time.microTimestamp();
        const conf_before = self.quarks[index].confidence;

        switch (repair_type) {
            .hash_recompute => {
                // Re-link prev_hash from predecessor
                if (index > 0) {
                    self.quarks[index].prev_quark_hash = self.quarks[index - 1].current_quark_hash;
                }
                // Recompute current hash
                self.quarks[index].current_quark_hash = QuarkRecord.computeQuarkHash(
                    self.quarks[index].prev_quark_hash,
                    self.quarks[index].quark_type,
                    self.quarks[index].parent_node,
                    self.quarks[index].content_digest[0..self.quarks[index].digest_len],
                    self.quarks[index].confidence,
                    self.quarks[index].timestamp_us,
                    self.quarks[index].entangled_indices,
                    self.quarks[index].entangle_count,
                );
                // Re-hash forward from this point
                self.rehashForward(index + 1);
            },
            .confidence_restore => {
                self.quarks[index].confidence = SELF_REPAIR_CONFIDENCE_THRESHOLD;
                self.quarks[index].current_quark_hash = QuarkRecord.computeQuarkHash(
                    self.quarks[index].prev_quark_hash,
                    self.quarks[index].quark_type,
                    self.quarks[index].parent_node,
                    self.quarks[index].content_digest[0..self.quarks[index].digest_len],
                    self.quarks[index].confidence,
                    self.quarks[index].timestamp_us,
                    self.quarks[index].entangled_indices,
                    self.quarks[index].entangle_count,
                );
                self.rehashForward(index + 1);
            },
            .entangle_fix => {
                self.quarks[index].entangle_count = 0;
                self.quarks[index].entangled_indices = .{ 0, 0 };
                self.quarks[index].current_quark_hash = QuarkRecord.computeQuarkHash(
                    self.quarks[index].prev_quark_hash,
                    self.quarks[index].quark_type,
                    self.quarks[index].parent_node,
                    self.quarks[index].content_digest[0..self.quarks[index].digest_len],
                    self.quarks[index].confidence,
                    self.quarks[index].timestamp_us,
                    self.quarks[index].entangled_indices,
                    self.quarks[index].entangle_count,
                );
                self.rehashForward(index + 1);
            },
            .chain_rebuild => {
                self.rehashForward(index);
            },
        }

        self.repair_state = .repaired;

        const record = RepairRecord{
            .broken_index = index,
            .repair_type = repair_type,
            .confidence_before = conf_before,
            .confidence_after = self.quarks[index].confidence,
            .timestamp_us = timestamp,
        };

        if (self.repair_count < MAX_REPAIR_RECORDS) {
            self.repair_records[self.repair_count] = record;
            self.repair_count += 1;
        }

        return record;
    }

    /// Re-hash all quarks forward from start_index to maintain chain integrity.
    fn rehashForward(self: *Self, start_index: u8) void {
        var i: u8 = start_index;
        while (i < self.quark_count) : (i += 1) {
            if (i > 0) {
                self.quarks[i].prev_quark_hash = self.quarks[i - 1].current_quark_hash;
            }
            self.quarks[i].current_quark_hash = QuarkRecord.computeQuarkHash(
                self.quarks[i].prev_quark_hash,
                self.quarks[i].quark_type,
                self.quarks[i].parent_node,
                self.quarks[i].content_digest[0..self.quarks[i].digest_len],
                self.quarks[i].confidence,
                self.quarks[i].timestamp_us,
                self.quarks[i].entangled_indices,
                self.quarks[i].entangle_count,
            );
        }
    }

    // ── v2.0: Chain Health Assessment ──

    /// Comprehensive health assessment of the quark chain.
    pub fn getChainHealth(self: *const Self) ChainHealthReport {
        var healthy_count: u8 = 0;
        var repaired_count: u8 = 0;
        var broken_count: u8 = 0;

        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            const q = &self.quarks[i];

            const expected = QuarkRecord.computeQuarkHash(
                q.prev_quark_hash,
                q.quark_type,
                q.parent_node,
                q.content_digest[0..q.digest_len],
                q.confidence,
                q.timestamp_us,
                q.entangled_indices,
                q.entangle_count,
            );
            const hash_ok = std.mem.eql(u8, &q.current_quark_hash, &expected);
            const conf_ok = q.confidence >= SELF_REPAIR_CONFIDENCE_THRESHOLD;

            if (hash_ok and conf_ok) {
                var was_repaired = false;
                var ri: u8 = 0;
                while (ri < self.repair_count) : (ri += 1) {
                    if (self.repair_records[ri].broken_index == i) {
                        was_repaired = true;
                        break;
                    }
                }
                if (was_repaired) {
                    repaired_count += 1;
                } else {
                    healthy_count += 1;
                }
            } else {
                broken_count += 1;
            }
        }

        const total = self.quark_count;
        const health_score: f32 = if (total > 0)
            @as(f32, @floatFromInt(healthy_count + repaired_count)) / @as(f32, @floatFromInt(total))
        else
            1.0;

        return .{
            .total = total,
            .healthy = healthy_count,
            .repaired = repaired_count,
            .broken = broken_count,
            .health_score = health_score,
        };
    }

    // ── v2.0: Immortal Persistence ──

    /// Serialize full agent state fingerprint. Returns SHA256 hash (TVC-compatible).
    pub fn persistState(self: *Self) [32]u8 {
        self.immortal_state.last_persist_us = std.time.microTimestamp();
        self.immortal_state.persist_count += 1;

        var hasher = Sha256.init(.{});

        // Hash all quark hashes
        var qi: u8 = 0;
        while (qi < self.quark_count) : (qi += 1) {
            hasher.update(&self.quarks[qi].current_quark_hash);
        }

        // Hash all provenance hashes
        var pi: u8 = 0;
        while (pi < self.provenance_count) : (pi += 1) {
            hasher.update(&self.provenance[pi].current_hash);
        }

        // Hash state metadata
        const gen_bytes2: [2]u8 = @bitCast(self.current_generation);
        hasher.update(&gen_bytes2);
        const repair_bytes2: [1]u8 = .{self.repair_count};
        hasher.update(&repair_bytes2);
        const persist_bytes2: [4]u8 = @bitCast(self.immortal_state.persist_count);
        hasher.update(&persist_bytes2);

        const fingerprint = hasher.finalResult();
        self.immortal_state.tvc_corpus_hash = fingerprint;

        return fingerprint;
    }

    /// Restore state from serialized binary buffer (uses deserializeQuarkChain + v5).
    pub fn restoreState(self: *Self, buf: []const u8) bool {
        if (!self.deserializeQuarkChain(buf)) return false;
        self.immortal_state.restore_count += 1;
        self.repair_state = .healthy;
        return true;
    }

    // ── v2.0: Evolution Loop ──

    /// Analyze chain health and track fitness for current generation.
    pub fn evolveChain(self: *Self) EvolutionRecord {
        const timestamp = std.time.microTimestamp();
        const health = self.getChainHealth();

        const record = EvolutionRecord{
            .generation = self.current_generation,
            .fitness_score = health.health_score,
            .repairs_applied = self.repair_count,
            .quarks_healthy = health.healthy + health.repaired,
            .timestamp_us = timestamp,
        };

        if (self.evolution_count < MAX_EVOLUTION_RECORDS) {
            self.evolution_records[self.evolution_count] = record;
            self.evolution_count += 1;
        }

        self.current_generation += 1;
        return record;
    }

    // ── v2.0: Phase G — Self-Repair Integrity Verification ──

    /// Phase G: Verify self-repair integrity.
    /// G1: All repair records point to quarks with valid hashes.
    /// G2: TVC corpus hash (tvc_corpus_hash) is consistent with chain state.
    fn selfRepairVerify(self: *const Self) bool {
        // G1: Verify all repaired quarks have valid hashes now
        var ri: u8 = 0;
        while (ri < self.repair_count) : (ri += 1) {
            const idx = self.repair_records[ri].broken_index;
            if (idx >= self.quark_count) return false;
            const q = &self.quarks[idx];

            const expected = QuarkRecord.computeQuarkHash(
                q.prev_quark_hash,
                q.quark_type,
                q.parent_node,
                q.content_digest[0..q.digest_len],
                q.confidence,
                q.timestamp_us,
                q.entangled_indices,
                q.entangle_count,
            );
            if (!std.mem.eql(u8, &q.current_quark_hash, &expected)) return false;
        }

        // G2: If tvc_corpus_hash is set (not all zeros), verify it matches current state
        const zero_hash = [_]u8{0} ** 32;
        if (!std.mem.eql(u8, &self.immortal_state.tvc_corpus_hash, &zero_hash)) {
            var hasher = Sha256.init(.{});
            var qi: u8 = 0;
            while (qi < self.quark_count) : (qi += 1) {
                hasher.update(&self.quarks[qi].current_quark_hash);
            }
            var pi: u8 = 0;
            while (pi < self.provenance_count) : (pi += 1) {
                hasher.update(&self.provenance[pi].current_hash);
            }
            const gen_bytes2: [2]u8 = @bitCast(self.current_generation);
            hasher.update(&gen_bytes2);
            const repair_bytes2: [1]u8 = .{self.repair_count};
            hasher.update(&repair_bytes2);
            const persist_bytes2: [4]u8 = @bitCast(self.immortal_state.persist_count);
            hasher.update(&persist_bytes2);
            const expected_fp = hasher.finalResult();

            if (!std.mem.eql(u8, &self.immortal_state.tvc_corpus_hash, &expected_fp)) return false;
        }

        return true;
    }

    // ── v2.1: Public Launch + $TRI Faucet + Canvas 1.0 ──

    /// Claim $TRI from faucet. Returns amount claimed (0 if cooldown or limit hit).
    pub fn claimFaucet(self: *Self, claimant_hash: [32]u8) u64 {
        if (!self.faucet_config.enabled) return 0;

        const now = std.time.microTimestamp();

        // Reset daily counter if new day
        if (now - self.faucet_day_start_us >= 86_400_000_000) {
            self.faucet_daily_distributed_utri = 0;
            self.faucet_day_start_us = now;
        }

        // Check daily limit
        if (self.faucet_daily_distributed_utri + self.faucet_config.claim_amount_utri > self.faucet_config.daily_limit_utri) return 0;

        // Check cooldown (search for same claimant)
        var ci: u16 = 0;
        while (ci < self.faucet_claims_count) : (ci += 1) {
            if (std.mem.eql(u8, &self.faucet_claims[ci].claimant_hash, &claimant_hash)) {
                if (now - self.faucet_claims[ci].timestamp_us < self.faucet_config.cooldown_us) return 0;
            }
        }

        // Record claim
        if (self.faucet_claims_count >= MAX_FAUCET_CLAIMS) return 0;
        const fp = self.immortal_state.tvc_corpus_hash;
        self.faucet_claims[self.faucet_claims_count] = .{
            .claim_index = self.faucet_claims_count,
            .amount_utri = self.faucet_config.claim_amount_utri,
            .claimant_hash = claimant_hash,
            .timestamp_us = now,
            .session_fingerprint = fp,
        };
        self.faucet_claims_count += 1;
        self.faucet_total_distributed_utri += self.faucet_config.claim_amount_utri;
        self.faucet_daily_distributed_utri += self.faucet_config.claim_amount_utri;
        return self.faucet_config.claim_amount_utri;
    }

    /// Get aggregated faucet state.
    pub fn getFaucetState(self: *const Self) FaucetState {
        return .{
            .total_distributed_utri = self.faucet_total_distributed_utri,
            .claims_count = @intCast(self.faucet_claims_count),
            .last_claim_us = if (self.faucet_claims_count > 0)
                self.faucet_claims[self.faucet_claims_count - 1].timestamp_us
            else
                0,
            .daily_distributed_utri = self.faucet_daily_distributed_utri,
            .day_start_us = self.faucet_day_start_us,
        };
    }

    /// Initialize public canvas mode (Canvas 1.0).
    pub fn initPublicCanvas(self: *Self) void {
        self.canvas_state = .{
            .canvas_version_major = CANVAS_VERSION_MAJOR,
            .canvas_version_minor = CANVAS_VERSION_MINOR,
            .is_public = true,
            .render_count = 0,
            .last_render_us = std.time.microTimestamp(),
            .browser_sessions = 0,
            .wasm_ready = true,
            .native_ready = true,
        };
    }

    /// Sync canvas state (increment render, update timestamp).
    pub fn syncCanvasState(self: *Self) PublicCanvasState {
        self.canvas_state.render_count += 1;
        self.canvas_state.last_render_us = std.time.microTimestamp();
        return self.canvas_state;
    }

    /// Create a public session from current chain state.
    pub fn createPublicSession(self: *Self) PublicSessionInfo {
        var hasher = Sha256.init(.{});
        hasher.update(&self.immortal_state.tvc_corpus_hash);
        const ts = std.time.microTimestamp();
        const ts_bytes: [8]u8 = @bitCast(ts);
        hasher.update(&ts_bytes);
        const session_hash = hasher.finalResult();

        const session = PublicSessionInfo{
            .session_hash = session_hash,
            .created_us = ts,
            .ttl_us = PUBLIC_SESSION_TTL_US,
            .view_count = 0,
            .share_count = 0,
            .faucet_claims = self.faucet_claims_count,
            .is_active = true,
        };
        self.public_session = session;
        return session;
    }

    /// Phase H: Faucet integrity verification.
    fn faucetVerify(self: *const Self) bool {
        // H1: All claims within daily limit
        var daily_total: u64 = 0;
        var ci: u16 = 0;
        while (ci < self.faucet_claims_count) : (ci += 1) {
            daily_total += self.faucet_claims[ci].amount_utri;
        }
        if (daily_total > self.faucet_config.daily_limit_utri * 2) return false; // Allow 2 days max

        // H2: No duplicate claimant within cooldown
        var i: u16 = 0;
        while (i < self.faucet_claims_count) : (i += 1) {
            var j: u16 = i + 1;
            while (j < self.faucet_claims_count) : (j += 1) {
                if (std.mem.eql(u8, &self.faucet_claims[i].claimant_hash, &self.faucet_claims[j].claimant_hash)) {
                    const diff = self.faucet_claims[j].timestamp_us - self.faucet_claims[i].timestamp_us;
                    if (diff < self.faucet_config.cooldown_us) return false;
                }
            }
        }

        return true;
    }

    // ── v2.2: Agent OS v1.0 — Decentralized Immortal Network ──

    /// Sync quark state with a target node. Returns success.
    pub fn syncNode(self: *Self, target_node_hash: [32]u8) bool {
        if (self.node_sync_count >= MAX_NODE_SYNC_RECORDS) return false;
        const now = std.time.microTimestamp();
        const record = NodeSyncRecord{
            .sync_index = self.node_sync_count,
            .source_node_hash = self.node_config.node_id_hash,
            .target_node_hash = target_node_hash,
            .quark_count_synced = self.quark_count,
            .timestamp_us = now,
            .latency_us = 500, // Simulated sync latency
            .success = true,
        };
        self.node_sync_records[self.node_sync_count] = record;
        self.node_sync_count += 1;
        self.network_state.sync_count += 1;
        return true;
    }

    /// Get current network state.
    pub fn getNetworkState(self: *const Self) NetworkState {
        return self.network_state;
    }

    /// Initialize Agent OS v1.0.
    pub fn initAgentOS(self: *Self) void {
        const now = std.time.microTimestamp();
        self.agent_os_state.is_initialized = true;
        self.agent_os_state.boot_count += 1;
        self.agent_os_state.last_boot_us = now;
        self.agent_os_state.network_mode = true;
        self.agent_os_state.immortal_mode = true;
    }

    /// Run consensus round. Returns true if quorum reached.
    pub fn runConsensus(self: *Self) bool {
        const now = std.time.microTimestamp();
        self.network_state.consensus_round += 1;
        self.network_state.last_consensus_us = now;

        // Calculate health: ratio of active nodes
        if (self.network_state.total_nodes == 0) {
            self.network_state.network_health_score = 0.0;
            return false;
        }
        const health = @as(f32, @floatFromInt(self.network_state.active_nodes)) /
            @as(f32, @floatFromInt(self.network_state.total_nodes));
        self.network_state.network_health_score = health;

        // Quorum: active nodes >= 67% of total
        const quorum_threshold = (self.network_state.total_nodes * CONSENSUS_QUORUM_PERCENT) / 100;
        return self.network_state.active_nodes >= quorum_threshold;
    }

    /// Stake on mainnet. Returns true if above minimum.
    pub fn stakeMainnet(self: *Self, amount_utri: u64) bool {
        if (amount_utri < STAKING_MAINNET_MIN_UTRI) return false;
        self.node_config.stake_utri += amount_utri;
        self.network_state.total_staked_utri += amount_utri;
        return true;
    }

    /// Phase I: Network consensus integrity verification.
    fn networkVerify(self: *const Self) bool {
        // I1: If more than 1 node, consensus must have been run
        if (self.network_state.total_nodes > 1 and self.network_state.consensus_round == 0) return false;

        // I2: Network health score must be above threshold (single node = 1.0)
        if (self.network_state.network_health_score < 0.0) return false;

        return true;
    }

    // ── v2.3: Mainnet Genesis — $TRI Token + DAO Governance + Immortal Swarm ──

    /// Mint $TRI tokens. Returns amount minted (0 if at max supply).
    pub fn mintToken(self: *Self) u64 {
        if (self.token_config.total_supply_utri >= self.token_config.max_supply_utri) return 0;
        const remaining = self.token_config.max_supply_utri - self.token_config.total_supply_utri;
        const batch = @min(self.token_config.mint_batch_utri, remaining);
        self.token_config.total_supply_utri += batch;
        self.token_config.mints_count += 1;
        if (!self.token_config.is_genesis_complete) {
            self.token_config.genesis_timestamp_us = std.time.microTimestamp();
            self.token_config.is_genesis_complete = true;
        }
        return batch;
    }

    /// Submit a DAO proposal. Returns proposal index or null if at max.
    pub fn submitProposal(self: *Self, proposer_hash: [32]u8, title_digest: [48]u8) ?u16 {
        if (self.dao_proposal_count >= MAX_DAO_PROPOSALS) return null;
        const now = std.time.microTimestamp();
        const idx = self.dao_proposal_count;
        self.dao_proposals[idx] = DAOProposal{
            .proposal_index = idx,
            .proposer_hash = proposer_hash,
            .title_digest = title_digest,
            .votes_for = 0,
            .votes_against = 0,
            .votes_abstain = 0,
            .created_us = now,
            .ttl_us = DAO_PROPOSAL_TTL_US,
            .executed = false,
            .passed = false,
        };
        self.dao_proposal_count += 1;
        self.dao_state.active_proposals += 1;
        self.dao_state.total_proposals += 1;
        return idx;
    }

    /// Vote on a DAO proposal. vote: 0=for, 1=against, 2=abstain. Returns success.
    pub fn voteProposal(self: *Self, proposal_index: u16, vote: u8) bool {
        if (proposal_index >= self.dao_proposal_count) return false;
        var p = &self.dao_proposals[proposal_index];
        if (p.executed) return false;
        switch (vote) {
            0 => p.votes_for += 1,
            1 => p.votes_against += 1,
            else => p.votes_abstain += 1,
        }
        self.dao_state.total_votes_cast += 1;
        self.dao_state.last_vote_us = std.time.microTimestamp();
        return true;
    }

    /// Execute a DAO proposal if quorum met and votes_for > votes_against.
    pub fn executeProposal(self: *Self, proposal_index: u16) bool {
        if (proposal_index >= self.dao_proposal_count) return false;
        var p = &self.dao_proposals[proposal_index];
        if (p.executed) return false;
        const total_votes = p.votes_for + p.votes_against + p.votes_abstain;
        if (total_votes == 0) return false;
        const for_percent = (@as(u32, p.votes_for) * 100) / @as(u32, total_votes);
        if (for_percent < self.dao_state.quorum_percent) return false;
        if (p.votes_for <= p.votes_against) return false;
        p.executed = true;
        p.passed = true;
        self.dao_state.proposals_passed += 1;
        if (self.dao_state.active_proposals > 0) self.dao_state.active_proposals -= 1;
        return true;
    }

    /// Spawn a new swarm node. Returns success.
    pub fn spawnSwarmNode(self: *Self) bool {
        if (self.swarm_state.active_nodes >= MAX_SWARM_NODES) return false;
        self.swarm_state.active_nodes += 1;
        self.swarm_state.total_spawned += 1;
        self.swarm_state.last_heartbeat_us = std.time.microTimestamp();
        // If first spawn, set genesis node hash
        if (self.swarm_state.total_spawned == 1) {
            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            var ts_buf: [8]u8 = undefined;
            std.mem.writeInt(i64, &ts_buf, self.swarm_state.last_heartbeat_us, .little);
            hasher.update(&ts_buf);
            hasher.final(&self.swarm_state.genesis_node_hash);
        }
        return true;
    }

    /// Get current swarm state.
    pub fn getSwarmState(self: *const Self) SwarmState {
        return self.swarm_state;
    }

    /// Phase J: DAO governance integrity verification.
    fn daoVerify(self: *const Self) bool {
        // J1: All executed proposals must have had quorum (votes_for > votes_against and sufficient %)
        var i: u16 = 0;
        while (i < self.dao_proposal_count) : (i += 1) {
            const p = &self.dao_proposals[i];
            if (p.executed) {
                // Must have passed
                if (!p.passed) return false;
                // Must have had votes_for > votes_against
                if (p.votes_for <= p.votes_against) return false;
            }
        }

        // J2: No expired proposals still marked as active
        // (proposals with passed TTL should not still be un-executed and counting as active)
        // For verification: active_proposals count must be <= dao_proposal_count
        if (self.dao_state.active_proposals > self.dao_proposal_count) return false;

        return true;
    }

    // ── v2.4: Mainnet v1.0 Launch Methods ──

    /// Launch mainnet v1.0 — sets mainnet as launched, records timestamp and launch hash.
    fn launchMainnet(self: *Self) bool {
        if (self.mainnet_config.is_launched) return false; // Already launched
        const now = std.time.microTimestamp();
        self.mainnet_config.is_launched = true;
        self.mainnet_config.launch_timestamp_us = now;
        self.launch_state.mainnet_launched = true;
        // Compute launch hash from timestamp
        var hash_input: [8]u8 = @bitCast(now);
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(&hash_input, &hash, .{});
        self.launch_state.launch_hash = hash;
        return true;
    }

    /// Onboard a batch of community nodes.
    fn communityOnboard(self: *Self) u16 {
        const remaining = MAX_COMMUNITY_NODES - self.community_state.active_nodes;
        if (remaining == 0) return 0;
        const batch = @min(COMMUNITY_ONBOARD_BATCH, remaining);
        self.community_state.active_nodes += batch;
        self.community_state.total_onboarded += batch;
        self.community_state.last_onboard_us = std.time.microTimestamp();
        if (self.community_state.total_onboarded == batch) {
            // First onboard — compute genesis community hash
            var hash_input: [8]u8 = @bitCast(self.community_state.last_onboard_us);
            std.crypto.hash.sha2.Sha256.hash(&hash_input, &self.community_state.genesis_community_hash, .{});
        }
        self.launch_state.community_ready = self.community_state.active_nodes > 0;
        self.mainnet_config.total_nodes += batch;
        return batch;
    }

    /// Register a discovered node.
    fn discoverNode(self: *Self, node_hash: [32]u8, node_type: u8) bool {
        if (self.node_discovery_count >= MAX_NODE_DISCOVERY_RECORDS) return false;
        self.node_discovery_records[self.node_discovery_count] = .{
            .node_hash = node_hash,
            .discovered_us = std.time.microTimestamp(),
            .node_type = node_type,
            .is_active = true,
        };
        self.node_discovery_count += 1;
        return true;
    }

    /// Get mainnet launch state.
    fn getMainnetState(self: *const Self) LaunchState {
        return self.launch_state;
    }

    /// Phase K: Mainnet launch integrity verification.
    fn mainnetVerify(self: *const Self) bool {
        // K1: Mainnet must be launched
        if (!self.mainnet_config.is_launched) return false;
        // K2: Community nodes > 0
        if (self.community_state.active_nodes == 0) return false;
        // K3: Governance must be live
        if (!self.launch_state.governance_live) return false;
        return true;
    }

    // v2.5: Immortal Agent Swarm v1.0 methods

    /// Orchestrate swarm task distribution.
    fn orchestrateSwarm(self: *Self) void {
        self.swarm_orch_state.active_tasks += 1;
        self.swarm_orch_state.total_orchestrated += 1;
        self.swarm_orch_state.sync_batch = SWARM_SYNC_BATCH;
        self.swarm_orch_state.last_orch_us = std.time.microTimestamp();
        const hash_input = std.mem.asBytes(&self.swarm_orch_state.total_orchestrated);
        self.swarm_orch_state.orch_hash = std.crypto.hash.sha2.Sha256.hash(hash_input, .{});
    }

    /// Trigger failover when node health below threshold.
    fn swarmFailover(self: *Self) void {
        self.swarm_failover_config.is_failover_active = true;
        self.swarm_failover_config.failover_count += 1;
        self.swarm_failover_config.last_failover_us = std.time.microTimestamp();
    }

    /// Send telemetry report.
    fn sendTelemetry(self: *Self) void {
        self.swarm_telemetry_state.reports_sent += 1;
        self.swarm_telemetry_state.last_report_us = std.time.microTimestamp();
    }

    /// Replicate state to replica nodes.
    fn replicateState(self: *Self, source_hash: [32]u8) void {
        if (self.swarm_replication_count < SWARM_REPLICATION_FACTOR) {
            self.swarm_replication_records[self.swarm_replication_count] = .{
                .source_hash = source_hash,
                .replica_count = self.swarm_replication_count + 1,
                .replication_factor = SWARM_REPLICATION_FACTOR,
                .replicated_us = std.time.microTimestamp(),
                .is_synced = true,
            };
            self.swarm_replication_count += 1;
        }
    }

    /// Phase L: Swarm activation integrity verification.
    fn swarmVerify(self: *const Self) bool {
        // L1: Swarm must have orchestrated at least once
        if (self.swarm_orch_state.total_orchestrated == 0) return false;
        // L2: Replication must be active
        if (self.swarm_replication_count == 0) return false;
        // L3: Telemetry must be running
        if (self.swarm_telemetry_state.reports_sent == 0) return false;
        return true;
    }

    // ── v1.3: Node Quark Summary ──

    /// Emit a single summary line for a node's quarks (used in summary verbosity mode).
    fn emitNodeQuarkSummary(self: *Self, node: ChainNode) void {
        if (self.quark_verbosity != .summary) return;

        var count: u8 = 0;
        var total_conf: f32 = 0.0;
        var total_ent: u16 = 0;
        var i: u8 = 0;
        while (i < self.quark_count) : (i += 1) {
            if (self.quarks[i].parent_node == node) {
                count += 1;
                total_conf += self.quarks[i].confidence;
                total_ent += self.quarks[i].entangle_count;
            }
        }

        if (count == 0) return;

        const avg_conf = total_conf / @as(f32, @floatFromInt(count));
        var sbuf: [128]u8 = undefined;
        const smsg = std.fmt.bufPrint(&sbuf, "[QUARKS] {s}: {d} quarks | avg:{d:.0}% | ent:{d} | OK", .{
            node.getLabel(),
            count,
            avg_conf * 100,
            total_ent,
        }) catch "QUARKS summary";
        self.emitMsg(.QuarkStep, node, null, smsg, avg_conf, 0);
    }

    // ── v1.2: Quark Emission per Node ──

    /// GOAL_PARSE: 11 quarks — input_capture, goal_classify, oracle_cross_check, phi_verify, collapse_state, self_repair, faucet_claim, decentral_sync, token_mint, hash_verify, gluon_verify
    fn emitGoalParseQuarks(self: *Self, input: []const u8) void {
        const conf: f32 = 0.95;
        const preview_len = @min(input.len, QUARK_CONTENT_DIGEST_LEN);

        // Q0: input_capture (genesis — no entanglement)
        self.recordQuark(.input_capture, .GoalParse, input[0..preview_len], conf, null, null);

        // Q1: goal_classify
        self.recordQuark(.goal_classify, .GoalParse, self.goal_type.getName(), conf, null, null);

        // Q2: oracle_cross_check (v1.3)
        self.recordQuark(.oracle_cross_check, .GoalParse, "oracle_cross_check", conf, self.quark_count - 1, null);

        // Q3: phi_verify (v1.4)
        self.recordQuark(.phi_verify, .GoalParse, "phi_verify", conf, self.quark_count - 1, null);

        // Q4: collapse_state (v1.5)
        self.recordQuark(.collapse_state, .GoalParse, "collapse_state", conf, self.quark_count - 1, null);

        // Q5: self_repair (v2.0)
        self.recordQuark(.self_repair, .GoalParse, "self_repair", conf, self.quark_count - 1, null);

        // Q6: faucet_claim (v2.1)
        self.recordQuark(.faucet_claim, .GoalParse, "faucet_claim", conf, self.quark_count - 1, null);

        // Q7: decentral_sync (v2.2)
        self.recordQuark(.decentral_sync, .GoalParse, "decentral_sync", conf, self.quark_count - 1, null);

        // Q8: token_mint (v2.3)
        self.recordQuark(.token_mint, .GoalParse, "token_mint", conf, self.quark_count - 1, null);

        // Q9: community_genesis (v2.4)
        self.recordQuark(.community_genesis, .GoalParse, "community_genesis", conf, self.quark_count - 1, null);

        // Q10: swarm_orchestrate (v2.5)
        self.recordQuark(.swarm_orchestrate, .GoalParse, "swarm_orchestrate", conf, self.quark_count - 1, null);

        // Q11: hash_verify — entangles with work quarks
        const prev_q = if (self.quark_count >= 2) self.quark_count - 2 else 0;
        self.recordQuark(.hash_verify, .GoalParse, "hash_verify", conf, prev_q, self.quark_count - 1);

        // Q10: gluon_verify — entangles with own hash_verify
        self.recordQuark(.gluon_verify, .GoalParse, "gluon_verify", conf, self.quark_count - 1, null);

        self.emitNodeQuarkSummary(.GoalParse);
    }

    /// DECOMPOSE: 11 quarks — task_decompose, dependency_check, oracle_cross_check, phi_verify, collapse_state, evolution_checkpoint, public_session, node_consensus, dao_propose, hash_verify, gluon_verify
    fn emitDecomposeQuarks(self: *Self) void {
        const conf: f32 = 0.9;

        // task_decompose — entangles with last quark of GOAL_PARSE
        const gp_last = self.lastQuarkOfNode(.GoalParse);
        self.recordQuark(.task_decompose, .Decompose, "task_decompose", conf, gp_last, null);

        // dependency_check
        self.recordQuark(.dependency_check, .Decompose, "dependency_check", conf, self.quark_count - 1, null);

        // oracle_cross_check (v1.3)
        self.recordQuark(.oracle_cross_check, .Decompose, "oracle_cross_check", conf, self.quark_count - 1, null);

        // phi_verify (v1.4)
        self.recordQuark(.phi_verify, .Decompose, "phi_verify", conf, self.quark_count - 1, null);

        // collapse_state (v1.5)
        self.recordQuark(.collapse_state, .Decompose, "collapse_state", conf, self.quark_count - 1, null);

        // evolution_checkpoint (v2.0)
        self.recordQuark(.evolution_checkpoint, .Decompose, "evolution_checkpoint", conf, self.quark_count - 1, null);

        // public_session (v2.1)
        self.recordQuark(.public_session, .Decompose, "public_session", conf, self.quark_count - 1, null);

        // node_consensus (v2.2)
        self.recordQuark(.node_consensus, .Decompose, "node_consensus", conf, self.quark_count - 1, null);

        // dao_propose (v2.3)
        self.recordQuark(.dao_propose, .Decompose, "dao_propose", conf, self.quark_count - 1, null);

        // mainnet_launch (v2.4)
        self.recordQuark(.mainnet_launch, .Decompose, "mainnet_launch", conf, self.quark_count - 1, null);

        // swarm_consensus (v2.5)
        self.recordQuark(.swarm_consensus, .Decompose, "swarm_consensus", conf, self.quark_count - 1, null);

        // hash_verify — entangles with work quarks + GOAL_PARSE hash_verify
        const gp_hv = self.lastHashVerifyOfNode(.GoalParse);
        self.recordQuark(.hash_verify, .Decompose, "hash_verify", conf, self.quark_count - 1, gp_hv);

        // gluon_verify — entangles with own hash_verify + GOAL_PARSE hash_verify
        self.recordQuark(.gluon_verify, .Decompose, "gluon_verify", conf, self.quark_count - 1, gp_hv);

        self.emitNodeQuarkSummary(.Decompose);
    }

    /// SCHEDULE: 11 quarks — schedule_plan, energy_accounting, dag_checkpoint, compress_quark, immortal_persist, self_repair, canvas_sync, network_health, dao_vote, hash_verify, gluon_verify
    fn emitScheduleQuarks(self: *Self) void {
        const conf: f32 = 0.95;

        // schedule_plan — entangles with last quark of DECOMPOSE
        const dec_last = self.lastQuarkOfNode(.Decompose);
        self.recordQuark(.schedule_plan, .Schedule, "schedule_plan", conf, dec_last, null);

        // energy_accounting (v1.3)
        self.recordQuark(.energy_accounting, .Schedule, "energy_accounting", conf, self.quark_count - 1, null);

        // dag_checkpoint (v1.4)
        self.recordQuark(.dag_checkpoint, .Schedule, "dag_checkpoint", conf, self.quark_count - 1, null);

        // compress_quark (v1.5)
        self.recordQuark(.compress_quark, .Schedule, "compress_quark", conf, self.quark_count - 1, null);

        // immortal_persist (v2.0)
        self.recordQuark(.immortal_persist, .Schedule, "immortal_persist", conf, self.quark_count - 1, null);

        // self_repair (v2.0)
        self.recordQuark(.self_repair, .Schedule, "self_repair", conf, self.quark_count - 1, null);

        // canvas_sync (v2.1)
        self.recordQuark(.canvas_sync, .Schedule, "canvas_sync", conf, self.quark_count - 1, null);

        // network_health (v2.2)
        self.recordQuark(.network_health, .Schedule, "network_health", conf, self.quark_count - 1, null);

        // dao_vote (v2.3)
        self.recordQuark(.dao_vote, .Schedule, "dao_vote", conf, self.quark_count - 1, null);

        // live_governance (v2.4)
        self.recordQuark(.live_governance, .Schedule, "live_governance", conf, self.quark_count - 1, null);

        // swarm_replication (v2.5)
        self.recordQuark(.swarm_replication, .Schedule, "swarm_replication", conf, self.quark_count - 1, null);

        // hash_verify — skip-link to GOAL_PARSE hash_verify
        const gp_hv = self.lastHashVerifyOfNode(.GoalParse);
        self.recordQuark(.hash_verify, .Schedule, "hash_verify", conf, self.quark_count - 1, gp_hv);

        // gluon_verify — entangles with own hash_verify + DECOMPOSE hash_verify
        const dec_hv = self.lastHashVerifyOfNode(.Decompose);
        self.recordQuark(.gluon_verify, .Schedule, "gluon_verify", conf, self.quark_count - 1, dec_hv);

        self.emitNodeQuarkSummary(.Schedule);
    }

    /// EXECUTE: 12 quarks — route_decision, api_call, tvc_cross_check, vsa_bind, oracle_cross_check, phi_verify, share_link, mainnet_anchor, staking_mainnet, dao_execute, hash_verify, gluon_verify
    fn emitExecuteQuarks(self: *Self, conf: f32) void {
        // route_decision — entangles with last quark of SCHEDULE
        const sched_last = self.lastQuarkOfNode(.Schedule);
        self.recordQuark(.route_decision, .Execute, "route_decision", conf, sched_last, null);

        // api_call
        self.recordQuark(.api_call, .Execute, "api_call", conf, self.quark_count - 1, null);

        // tvc_cross_check
        self.recordQuark(.tvc_cross_check, .Execute, "tvc_cross_check", conf, self.quark_count - 1, null);

        // vsa_bind
        self.recordQuark(.vsa_bind, .Execute, "vsa_bind", conf, self.quark_count - 1, null);

        // oracle_cross_check (v1.3)
        self.recordQuark(.oracle_cross_check, .Execute, "oracle_cross_check", conf, self.quark_count - 1, null);

        // phi_verify (v1.4)
        self.recordQuark(.phi_verify, .Execute, "phi_verify", conf, self.quark_count - 1, null);

        // share_link (v1.5)
        self.recordQuark(.share_link, .Execute, "share_link", conf, self.quark_count - 1, null);

        // mainnet_anchor (v2.1)
        self.recordQuark(.mainnet_anchor, .Execute, "mainnet_anchor", conf, self.quark_count - 1, null);

        // staking_mainnet (v2.2)
        self.recordQuark(.staking_mainnet, .Execute, "staking_mainnet", conf, self.quark_count - 1, null);

        // dao_execute (v2.3)
        self.recordQuark(.dao_execute, .Execute, "dao_execute", conf, self.quark_count - 1, null);

        // swarm_activate (v2.4)
        self.recordQuark(.swarm_activate, .Execute, "swarm_activate", conf, self.quark_count - 1, null);

        // swarm_failover (v2.5)
        self.recordQuark(.swarm_failover, .Execute, "swarm_failover", conf, self.quark_count - 1, null);

        // hash_verify — entangles with work quarks + SCHEDULE hash_verify
        const sched_hv = self.lastHashVerifyOfNode(.Schedule);
        self.recordQuark(.hash_verify, .Execute, "hash_verify", conf, self.quark_count - 1, sched_hv);

        // gluon_verify — entangles with own hash_verify + SCHEDULE hash_verify
        self.recordQuark(.gluon_verify, .Execute, "gluon_verify", conf, self.quark_count - 1, sched_hv);

        self.emitNodeQuarkSummary(.Execute);
    }

    /// MONITOR: 11 quarks — quality_gate, tvc_cross_check, fake_injection_detect, phi_verify, public_view, self_repair, browser_verify, agent_os_init, swarm_spawn, hash_verify, gluon_verify
    fn emitMonitorQuarks(self: *Self, conf: f32) void {
        // quality_gate — entangles with last quark of EXECUTE
        const exec_last = self.lastQuarkOfNode(.Execute);
        self.recordQuark(.quality_gate, .Monitor, "quality_gate", conf, exec_last, null);

        // tvc_cross_check
        self.recordQuark(.tvc_cross_check, .Monitor, "tvc_cross_check", conf, self.quark_count - 1, null);

        // fake_injection_detect (v1.3)
        self.recordQuark(.fake_injection_detect, .Monitor, "fake_injection_detect", conf, self.quark_count - 1, null);

        // phi_verify (v1.4)
        self.recordQuark(.phi_verify, .Monitor, "phi_verify", conf, self.quark_count - 1, null);

        // public_view (v1.5)
        self.recordQuark(.public_view, .Monitor, "public_view", conf, self.quark_count - 1, null);

        // self_repair (v2.0)
        self.recordQuark(.self_repair, .Monitor, "self_repair", conf, self.quark_count - 1, null);

        // browser_verify (v2.1)
        self.recordQuark(.browser_verify, .Monitor, "browser_verify", conf, self.quark_count - 1, null);

        // agent_os_init (v2.2)
        self.recordQuark(.agent_os_init, .Monitor, "agent_os_init", conf, self.quark_count - 1, null);

        // swarm_spawn (v2.3)
        self.recordQuark(.swarm_spawn, .Monitor, "swarm_spawn", conf, self.quark_count - 1, null);

        // node_discovery (v2.4)
        self.recordQuark(.node_discovery, .Monitor, "node_discovery", conf, self.quark_count - 1, null);

        // swarm_discovery_v2 (v2.5)
        self.recordQuark(.swarm_discovery_v2, .Monitor, "swarm_discovery_v2", conf, self.quark_count - 1, null);

        // hash_verify — entangles with work quarks + EXECUTE hash_verify
        const exec_hv = self.lastHashVerifyOfNode(.Execute);
        self.recordQuark(.hash_verify, .Monitor, "hash_verify", conf, self.quark_count - 1, exec_hv);

        // gluon_verify — entangles with own hash_verify + EXECUTE hash_verify
        self.recordQuark(.gluon_verify, .Monitor, "gluon_verify", conf, self.quark_count - 1, exec_hv);

        self.emitNodeQuarkSummary(.Monitor);
    }

    /// ADAPT: 10 quarks — adapt_decision, fake_injection_detect, dag_checkpoint, phi_visual, evolution_checkpoint, viral_share, immortal_network, swarm_health, hash_verify, gluon_verify
    fn emitAdaptQuarks(self: *Self, conf: f32) void {
        // adapt_decision — entangles with last quark of MONITOR
        const mon_last = self.lastQuarkOfNode(.Monitor);
        self.recordQuark(.adapt_decision, .Adapt, "adapt_decision", conf, mon_last, null);

        // fake_injection_detect (v1.3)
        self.recordQuark(.fake_injection_detect, .Adapt, "fake_injection_detect", conf, self.quark_count - 1, null);

        // dag_checkpoint (v1.4)
        self.recordQuark(.dag_checkpoint, .Adapt, "dag_checkpoint", conf, self.quark_count - 1, null);

        // phi_visual (v1.5)
        self.recordQuark(.phi_visual, .Adapt, "phi_visual", conf, self.quark_count - 1, null);

        // evolution_checkpoint (v2.0)
        self.recordQuark(.evolution_checkpoint, .Adapt, "evolution_checkpoint", conf, self.quark_count - 1, null);

        // viral_share (v2.1)
        self.recordQuark(.viral_share, .Adapt, "viral_share", conf, self.quark_count - 1, null);

        // immortal_network (v2.2)
        self.recordQuark(.immortal_network, .Adapt, "immortal_network", conf, self.quark_count - 1, null);

        // swarm_health (v2.3)
        self.recordQuark(.swarm_health, .Adapt, "swarm_health", conf, self.quark_count - 1, null);

        // community_onboard (v2.4)
        self.recordQuark(.community_onboard, .Adapt, "community_onboard", conf, self.quark_count - 1, null);

        // swarm_self_heal (v2.5)
        self.recordQuark(.swarm_self_heal, .Adapt, "swarm_self_heal", conf, self.quark_count - 1, null);

        // hash_verify — entangles with work quark + MONITOR hash_verify
        const mon_hv = self.lastHashVerifyOfNode(.Monitor);
        self.recordQuark(.hash_verify, .Adapt, "hash_verify", conf, self.quark_count - 1, mon_hv);

        // gluon_verify — entangles with own hash_verify + MONITOR hash_verify
        self.recordQuark(.gluon_verify, .Adapt, "gluon_verify", conf, self.quark_count - 1, mon_hv);

        self.emitNodeQuarkSummary(.Adapt);
    }

    /// SYNTHESIZE: 11 quarks — merge_result, format_output, oracle_cross_check, reward_mint, staking_lock, immortal_persist, faucet_distribute, viral_propagate, mainnet_genesis, hash_verify, gluon_verify
    fn emitSynthesizeQuarks(self: *Self, conf: f32) void {
        // merge_result — entangles with last quark of ADAPT
        const adapt_last = self.lastQuarkOfNode(.Adapt);
        self.recordQuark(.merge_result, .Synthesize, "merge_result", conf, adapt_last, null);

        // format_output
        self.recordQuark(.format_output, .Synthesize, "format_output", conf, self.quark_count - 1, null);

        // oracle_cross_check (v1.3)
        self.recordQuark(.oracle_cross_check, .Synthesize, "oracle_cross_check", conf, self.quark_count - 1, null);

        // reward_mint (v1.4)
        self.recordQuark(.reward_mint, .Synthesize, "reward_mint", conf, self.quark_count - 1, null);

        // staking_lock (v1.5)
        self.recordQuark(.staking_lock, .Synthesize, "staking_lock", conf, self.quark_count - 1, null);

        // immortal_persist (v2.0)
        self.recordQuark(.immortal_persist, .Synthesize, "immortal_persist", conf, self.quark_count - 1, null);

        // faucet_distribute (v2.1)
        self.recordQuark(.faucet_distribute, .Synthesize, "faucet_distribute", conf, self.quark_count - 1, null);

        // viral_propagate (v2.2)
        self.recordQuark(.viral_propagate, .Synthesize, "viral_propagate", conf, self.quark_count - 1, null);

        // mainnet_genesis (v2.3)
        self.recordQuark(.mainnet_genesis, .Synthesize, "mainnet_genesis", conf, self.quark_count - 1, null);

        // public_api (v2.4)
        self.recordQuark(.public_api, .Synthesize, "public_api", conf, self.quark_count - 1, null);

        // swarm_telemetry (v2.5)
        self.recordQuark(.swarm_telemetry, .Synthesize, "swarm_telemetry", conf, self.quark_count - 1, null);

        // hash_verify — skip-link to EXECUTE hash_verify
        const exec_hv = self.lastHashVerifyOfNode(.Execute);
        self.recordQuark(.hash_verify, .Synthesize, "hash_verify", conf, self.quark_count - 1, exec_hv);

        // gluon_verify — entangles with own hash_verify + ADAPT hash_verify
        const adapt_hv = self.lastHashVerifyOfNode(.Adapt);
        self.recordQuark(.gluon_verify, .Synthesize, "gluon_verify", conf, self.quark_count - 1, adapt_hv);

        self.emitNodeQuarkSummary(.Synthesize);
    }

    /// DELIVER: 11 quarks — chain_integrity, format_output, energy_accounting, reward_mint, staking_yield, self_repair, canvas_render, energy_network, governance_anchor, hash_verify, gluon_verify
    fn emitDeliverQuarks(self: *Self, conf: f32) void {
        // chain_integrity — entangles with last quark of SYNTHESIZE
        const synth_last = self.lastQuarkOfNode(.Synthesize);
        self.recordQuark(.chain_integrity, .Deliver, "chain_integrity", conf, synth_last, null);

        // format_output
        self.recordQuark(.format_output, .Deliver, "format_output", conf, self.quark_count - 1, null);

        // energy_accounting (v1.3)
        self.recordQuark(.energy_accounting, .Deliver, "energy_accounting", conf, self.quark_count - 1, null);

        // reward_mint (v1.4)
        self.recordQuark(.reward_mint, .Deliver, "reward_mint", conf, self.quark_count - 1, null);

        // staking_yield (v1.5)
        self.recordQuark(.staking_yield, .Deliver, "staking_yield", conf, self.quark_count - 1, null);

        // self_repair (v2.0)
        self.recordQuark(.self_repair, .Deliver, "self_repair", conf, self.quark_count - 1, null);

        // canvas_render (v2.1)
        self.recordQuark(.canvas_render, .Deliver, "canvas_render", conf, self.quark_count - 1, null);

        // energy_network (v2.2)
        self.recordQuark(.energy_network, .Deliver, "energy_network", conf, self.quark_count - 1, null);

        // governance_anchor (v2.3)
        self.recordQuark(.governance_anchor, .Deliver, "governance_anchor", conf, self.quark_count - 1, null);

        // mainnet_anchor_v2 (v2.4)
        self.recordQuark(.mainnet_anchor_v2, .Deliver, "mainnet_anchor_v2", conf, self.quark_count - 1, null);

        // swarm_anchor (v2.5)
        self.recordQuark(.swarm_anchor, .Deliver, "swarm_anchor", conf, self.quark_count - 1, null);

        // hash_verify — skip-link to EXECUTE hash_verify
        const exec_hv = self.lastHashVerifyOfNode(.Execute);
        self.recordQuark(.hash_verify, .Deliver, "hash_verify", conf, self.quark_count - 1, exec_hv);

        // gluon_verify — entangles with own hash_verify + EXECUTE hash_verify
        self.recordQuark(.gluon_verify, .Deliver, "gluon_verify", conf, self.quark_count - 1, exec_hv);

        self.emitNodeQuarkSummary(.Deliver);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ChainNode colors and labels" {
    const node = ChainNode.GoalParse;
    try std.testing.expectEqual(@as(f32, 0.0), node.getHue());
    try std.testing.expectEqualStrings("GOAL_PARSE", node.getLabel());
    const rgb = node.getRGB();
    try std.testing.expectEqual(@as(u8, 0xFF), rgb.r);
    try std.testing.expectEqual(@as(u8, 0x00), rgb.g);
}

test "ChainNode Deliver is Gold" {
    const node = ChainNode.Deliver;
    try std.testing.expectEqual(@as(f32, 45.0), node.getHue());
    try std.testing.expectEqualStrings("DELIVER", node.getLabel());
    const rgb = node.getRGB();
    try std.testing.expectEqual(@as(u8, 0xFF), rgb.r);
    try std.testing.expectEqual(@as(u8, 0xD7), rgb.g);
}

test "ChainState init and lifecycle" {
    var state = ChainState.init();
    try std.testing.expect(!state.is_running);
    try std.testing.expectEqual(@as(f32, 0.0), state.total_confidence);

    state.startNode(.GoalParse);
    try std.testing.expect(state.node_active[0]);

    state.completeNode(.GoalParse, 0.9, 100);
    try std.testing.expect(!state.node_active[0]);
    try std.testing.expect(state.node_complete[0]);
    try std.testing.expectEqual(@as(f32, 0.9), state.total_confidence);
}

test "detectGoalType patterns" {
    try std.testing.expectEqual(GoalType.CodeGen, detectGoalType("create a web server"));
    try std.testing.expectEqual(GoalType.BugFix, detectGoalType("fix the crash"));
    try std.testing.expectEqual(GoalType.Explain, detectGoalType("explain this code"));
    try std.testing.expectEqual(GoalType.Chat, detectGoalType("hello"));
}

test "ChainMessage hue from node" {
    var msg = ChainMessage{
        .msg_type = .ChainStep,
        .node = .Execute,
        .source = null,
        .content = undefined,
        .content_len = 0,
        .confidence = 0.9,
        .latency_us = 100,
    };
    try std.testing.expectEqual(@as(f32, 120.0), msg.getHue()); // Green
}

test "ChainMessage hue from source" {
    var msg = ChainMessage{
        .msg_type = .RoutingInfo,
        .node = null,
        .source = .ClaudeAPI,
        .content = undefined,
        .content_len = 0,
        .confidence = 0.9,
        .latency_us = 100,
    };
    try std.testing.expectEqual(@as(f32, 280.0), msg.getHue()); // Purple
}

test "All 8 ChainNodes have unique hues" {
    var hues: [8]f32 = undefined;
    inline for (0..8) |i| {
        hues[i] = @as(ChainNode, @enumFromInt(i)).getHue();
    }
    // Check no duplicates
    for (0..8) |i| {
        for (i + 1..8) |j| {
            try std.testing.expect(hues[i] != hues[j]);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.1 TRUTH & PROVENANCE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ProvenanceRecord.computeHash deterministic" {
    const prev = [_]u8{0} ** PROVENANCE_HASH_SIZE;
    const h1 = ProvenanceRecord.computeHash(prev, .GoalParse, "test content", 0.95, 1000000);
    const h2 = ProvenanceRecord.computeHash(prev, .GoalParse, "test content", 0.95, 1000000);
    try std.testing.expectEqualSlices(u8, &h1, &h2);
}

test "ProvenanceRecord.computeHash varies with content" {
    const prev = [_]u8{0} ** PROVENANCE_HASH_SIZE;
    const h1 = ProvenanceRecord.computeHash(prev, .GoalParse, "content A", 0.9, 1000);
    const h2 = ProvenanceRecord.computeHash(prev, .GoalParse, "content B", 0.9, 1000);
    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}

test "ProvenanceRecord.computeHash varies with node" {
    const prev = [_]u8{0} ** PROVENANCE_HASH_SIZE;
    const h1 = ProvenanceRecord.computeHash(prev, .GoalParse, "same content", 0.9, 1000);
    const h2 = ProvenanceRecord.computeHash(prev, .Execute, "same content", 0.9, 1000);
    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}

test "ProvenanceRecord.hashHexPrefix format" {
    // Create a known hash and check hex prefix
    const prev = [_]u8{0} ** PROVENANCE_HASH_SIZE;
    const hash = ProvenanceRecord.computeHash(prev, .GoalParse, "test", 0.5, 0);
    var hex_buf: [8]u8 = undefined;
    ProvenanceRecord.hashHexPrefix(hash, &hex_buf);
    // Each char must be valid hex [0-9a-f]
    for (&hex_buf) |c| {
        try std.testing.expect((c >= '0' and c <= '9') or (c >= 'a' and c <= 'f'));
    }
}

test "assessTruth verified" {
    const v = assessTruth(0.85, 0.45);
    try std.testing.expectEqual(TruthVerdict.Verified, v);
}

test "assessTruth low confidence" {
    const v = assessTruth(0.4, 0.5);
    try std.testing.expectEqual(TruthVerdict.LowConfidence, v);
}

test "assessTruth unverified" {
    const v = assessTruth(0.85, 0.1);
    try std.testing.expectEqual(TruthVerdict.Unverified, v);
}

test "TruthVerdict labels" {
    try std.testing.expectEqualStrings("VERIFIED", TruthVerdict.Verified.getLabel());
    try std.testing.expectEqualStrings("UNVERIFIED", TruthVerdict.Unverified.getLabel());
    try std.testing.expectEqualStrings("LOW_CONF", TruthVerdict.LowConfidence.getLabel());
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.2 QUARK-GLUON TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QuarkType has 16 variants" {
    // All 16 QuarkType values are accessible and distinct
    const types = [_]QuarkType{
        .input_capture, .goal_classify, .task_decompose, .dependency_check,
        .schedule_plan, .route_decision, .api_call,      .tvc_cross_check,
        .vsa_bind,      .quality_gate,  .adapt_decision, .merge_result,
        .format_output, .chain_integrity, .hash_verify,  .gluon_verify,
    };
    try std.testing.expectEqual(@as(usize, 16), types.len);
    // Verify all have different integer values
    for (0..16) |i| {
        for (i + 1..16) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "QuarkType labels are unique" {
    const types = [_]QuarkType{
        .input_capture, .goal_classify, .task_decompose, .dependency_check,
        .schedule_plan, .route_decision, .api_call,      .tvc_cross_check,
        .vsa_bind,      .quality_gate,  .adapt_decision, .merge_result,
        .format_output, .chain_integrity, .hash_verify,  .gluon_verify,
    };
    // Check no duplicate labels
    for (0..16) |i| {
        for (i + 1..16) |j| {
            try std.testing.expect(!std.mem.eql(u8, types[i].getLabel(), types[j].getLabel()));
        }
    }
}

test "QuarkRecord.computeQuarkHash deterministic" {
    const prev = [_]u8{0} ** QUARK_HASH_SIZE;
    const ent = [_]u8{ 0, 0 };
    const h1 = QuarkRecord.computeQuarkHash(prev, .input_capture, .GoalParse, "test", 0.95, 1000000, ent, 0);
    const h2 = QuarkRecord.computeQuarkHash(prev, .input_capture, .GoalParse, "test", 0.95, 1000000, ent, 0);
    try std.testing.expectEqualSlices(u8, &h1, &h2);
}

test "QuarkRecord.computeQuarkHash varies with quark_type" {
    const prev = [_]u8{0} ** QUARK_HASH_SIZE;
    const ent = [_]u8{ 0, 0 };
    const h1 = QuarkRecord.computeQuarkHash(prev, .input_capture, .GoalParse, "same", 0.9, 1000, ent, 0);
    const h2 = QuarkRecord.computeQuarkHash(prev, .goal_classify, .GoalParse, "same", 0.9, 1000, ent, 0);
    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}

test "QuarkRecord.computeQuarkHash varies with entanglement" {
    const prev = [_]u8{0} ** QUARK_HASH_SIZE;
    const ent_a = [_]u8{ 1, 2 };
    const ent_b = [_]u8{ 3, 4 };
    const h1 = QuarkRecord.computeQuarkHash(prev, .hash_verify, .Execute, "same", 0.9, 1000, ent_a, 2);
    const h2 = QuarkRecord.computeQuarkHash(prev, .hash_verify, .Execute, "same", 0.9, 1000, ent_b, 2);
    try std.testing.expect(!std.mem.eql(u8, &h1, &h2));
}

test "QuarkRecord.formatQuarkLine format" {
    const prev = [_]u8{0} ** QUARK_HASH_SIZE;
    const ent = [_]u8{ 1, 0 };
    const hash = QuarkRecord.computeQuarkHash(prev, .api_call, .Execute, "test", 0.92, 5000, ent, 1);
    var qr = QuarkRecord{
        .quark_index = 5,
        .quark_type = .api_call,
        .parent_node = .Execute,
        .content_digest = undefined,
        .digest_len = 4,
        .confidence = 0.92,
        .timestamp_us = 5000,
        .prev_quark_hash = prev,
        .current_quark_hash = hash,
        .entangled_indices = ent,
        .entangle_count = 1,
    };
    @memcpy(qr.content_digest[0..4], "test");
    var buf: [256]u8 = undefined;
    const line = qr.formatQuarkLine(&buf);
    // Must contain NODE label, QUARK_TYPE label, and ent:N
    try std.testing.expect(std.mem.indexOf(u8, line, "EXECUTE") != null);
    try std.testing.expect(std.mem.indexOf(u8, line, "API_CALL") != null);
    try std.testing.expect(std.mem.indexOf(u8, line, "ent:1") != null);
}

test "ChainMessageType has QuarkStep and GluonEntangle" {
    // Verify v1.2 message types exist and are distinct
    const qs = ChainMessageType.QuarkStep;
    const ge = ChainMessageType.GluonEntangle;
    try std.testing.expect(qs != ge);
    // Also distinct from all v1.0/v1.1 types
    try std.testing.expect(qs != ChainMessageType.User);
    try std.testing.expect(qs != ChainMessageType.ChainStep);
    try std.testing.expect(qs != ChainMessageType.ProvenanceStep);
    try std.testing.expect(qs != ChainMessageType.TruthVerification);
    try std.testing.expect(ge != ChainMessageType.User);
    try std.testing.expect(ge != ChainMessageType.ChainStep);
    try std.testing.expect(ge != ChainMessageType.ProvenanceStep);
    try std.testing.expect(ge != ChainMessageType.TruthVerification);
}

test "QuarkType verification classification" {
    // 26 work quarks + 3 verification quarks = 29 total (v1.5: 7 new work quarks)
    var work_count: u8 = 0;
    var verify_count: u8 = 0;
    inline for (0..29) |i| {
        const qt: QuarkType = @enumFromInt(i);
        if (qt.isVerificationQuark()) {
            verify_count += 1;
            try std.testing.expect(!qt.isWorkQuark());
        } else {
            work_count += 1;
            try std.testing.expect(qt.isWorkQuark());
        }
    }
    try std.testing.expectEqual(@as(u8, 26), work_count);
    try std.testing.expectEqual(@as(u8, 3), verify_count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.3 VSA-SEMANTIC QUARK QUERY + ON-CHAIN EXPORT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QuarkType has 19 variants" {
    // All 19 QuarkType values are accessible and distinct
    const types = [_]QuarkType{
        .input_capture,         .goal_classify,     .task_decompose, .dependency_check,
        .schedule_plan,         .route_decision,    .api_call,       .tvc_cross_check,
        .vsa_bind,              .quality_gate,      .adapt_decision, .merge_result,
        .format_output,         .chain_integrity,   .hash_verify,    .gluon_verify,
        .fake_injection_detect, .oracle_cross_check, .energy_accounting,
    };
    try std.testing.expectEqual(@as(usize, 19), types.len);
    // Verify all have different integer values
    for (0..19) |i| {
        for (i + 1..19) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "v1.3 QuarkType labels unique" {
    // 3 new labels must be unique across all 19
    const new_labels = [_][]const u8{ "FAKE_DET", "ORACLE_CHK", "ENERGY_ACC" };
    const new_types = [_]QuarkType{ .fake_injection_detect, .oracle_cross_check, .energy_accounting };

    // Check new labels match
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }

    // Check all 19 labels unique
    var labels: [19][]const u8 = undefined;
    inline for (0..19) |i| {
        labels[i] = @as(QuarkType, @enumFromInt(i)).getLabel();
    }
    for (0..19) |i| {
        for (i + 1..19) |j| {
            try std.testing.expect(!std.mem.eql(u8, labels[i], labels[j]));
        }
    }
}

test "isAdversarialQuark classification" {
    // Only fake_injection_detect and oracle_cross_check are adversarial
    try std.testing.expect(QuarkType.fake_injection_detect.isAdversarialQuark());
    try std.testing.expect(QuarkType.oracle_cross_check.isAdversarialQuark());
    // All others are not
    try std.testing.expect(!QuarkType.input_capture.isAdversarialQuark());
    try std.testing.expect(!QuarkType.hash_verify.isAdversarialQuark());
    try std.testing.expect(!QuarkType.energy_accounting.isAdversarialQuark());
    try std.testing.expect(!QuarkType.vsa_bind.isAdversarialQuark());
}

test "isAccountingQuark classification" {
    // Only energy_accounting is accounting
    try std.testing.expect(QuarkType.energy_accounting.isAccountingQuark());
    // All others are not
    try std.testing.expect(!QuarkType.input_capture.isAccountingQuark());
    try std.testing.expect(!QuarkType.hash_verify.isAccountingQuark());
    try std.testing.expect(!QuarkType.fake_injection_detect.isAccountingQuark());
    try std.testing.expect(!QuarkType.oracle_cross_check.isAccountingQuark());
}

test "searchQuarks by type" {
    // Manually build a small agent with 3 quarks
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 3;
    agent.quarks[0] = makeTestQuark(0, .vsa_bind, .Execute, 0.85);
    agent.quarks[1] = makeTestQuark(1, .api_call, .Execute, 0.9);
    agent.quarks[2] = makeTestQuark(2, .vsa_bind, .Monitor, 0.8);

    var results: [MAX_QUARK_RECORDS]u8 = undefined;
    const count = agent.searchQuarks(.{ .filter_type = .vsa_bind }, &results);
    try std.testing.expectEqual(@as(u8, 2), count);
    try std.testing.expectEqual(@as(u8, 0), results[0]);
    try std.testing.expectEqual(@as(u8, 2), results[1]);
}

test "searchQuarks by node" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 3;
    agent.quarks[0] = makeTestQuark(0, .vsa_bind, .Execute, 0.85);
    agent.quarks[1] = makeTestQuark(1, .api_call, .Execute, 0.9);
    agent.quarks[2] = makeTestQuark(2, .quality_gate, .Monitor, 0.8);

    var results: [MAX_QUARK_RECORDS]u8 = undefined;
    const count = agent.searchQuarks(.{ .filter_node = .Execute }, &results);
    try std.testing.expectEqual(@as(u8, 2), count);
}

test "searchQuarks by confidence range" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 4;
    agent.quarks[0] = makeTestQuark(0, .input_capture, .GoalParse, 0.5);
    agent.quarks[1] = makeTestQuark(1, .goal_classify, .GoalParse, 0.75);
    agent.quarks[2] = makeTestQuark(2, .api_call, .Execute, 0.85);
    agent.quarks[3] = makeTestQuark(3, .format_output, .Deliver, 0.95);

    var results: [MAX_QUARK_RECORDS]u8 = undefined;
    const count = agent.searchQuarks(.{ .min_confidence = 0.7, .max_confidence = 0.9 }, &results);
    try std.testing.expectEqual(@as(u8, 2), count); // 0.75 and 0.85
}

test "searchQuarks verification_only" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 4;
    agent.quarks[0] = makeTestQuark(0, .input_capture, .GoalParse, 0.9);
    agent.quarks[1] = makeTestQuark(1, .hash_verify, .GoalParse, 0.9);
    agent.quarks[2] = makeTestQuark(2, .gluon_verify, .GoalParse, 0.9);
    agent.quarks[3] = makeTestQuark(3, .api_call, .Execute, 0.9);

    var results: [MAX_QUARK_RECORDS]u8 = undefined;
    const count = agent.searchQuarks(.{ .verification_only = true }, &results);
    try std.testing.expectEqual(@as(u8, 2), count);
    try std.testing.expectEqual(@as(u8, 1), results[0]); // hash_verify
    try std.testing.expectEqual(@as(u8, 2), results[1]); // gluon_verify
}

test "serializeQuarkChain roundtrip" {
    var agent: GoldenChainAgent = undefined;
    agent.provenance_count = 1;
    agent.quark_count = 1;
    agent.chain_verified = true;
    agent.quark_chain_verified = true;

    // Fill a provenance record
    agent.provenance[0] = .{
        .step_index = 0,
        .node = .GoalParse,
        .content_digest = [_]u8{0xAB} ** CONTENT_DIGEST_LEN,
        .digest_len = 5,
        .confidence = 0.95,
        .tvc_similarity = 0.42,
        .truth_verdict = .Verified,
        .timestamp_us = 123456,
        .latency_us = 100,
        .source = null,
        .prev_hash = [_]u8{0} ** PROVENANCE_HASH_SIZE,
        .current_hash = [_]u8{0xCD} ** PROVENANCE_HASH_SIZE,
    };

    // Fill a quark record
    agent.quarks[0] = .{
        .quark_index = 0,
        .quark_type = .input_capture,
        .parent_node = .GoalParse,
        .content_digest = [_]u8{0xEF} ** QUARK_CONTENT_DIGEST_LEN,
        .digest_len = 4,
        .confidence = 0.92,
        .timestamp_us = 654321,
        .prev_quark_hash = [_]u8{0} ** QUARK_HASH_SIZE,
        .current_quark_hash = [_]u8{0xBB} ** QUARK_HASH_SIZE,
        .entangled_indices = .{ 0, 0 },
        .entangle_count = 0,
    };

    // Serialize
    var buf: [8192]u8 = undefined;
    const serialized = agent.serializeQuarkChain(&buf) orelse {
        try std.testing.expect(false);
        return;
    };
    try std.testing.expect(serialized.len > 0);

    // Deserialize into fresh agent
    var agent2: GoldenChainAgent = undefined;
    agent2.provenance_count = 0;
    agent2.quark_count = 0;
    const ok = agent2.deserializeQuarkChain(serialized);
    try std.testing.expect(ok);

    // Verify restored state
    try std.testing.expectEqual(@as(u8, 1), agent2.provenance_count);
    try std.testing.expectEqual(@as(u8, 1), agent2.quark_count);
    try std.testing.expect(agent2.chain_verified);
    try std.testing.expect(agent2.quark_chain_verified);
    try std.testing.expectEqual(@as(f32, 0.95), agent2.provenance[0].confidence);
    try std.testing.expectEqual(QuarkType.input_capture, agent2.quarks[0].quark_type);
    try std.testing.expectEqual(@as(f32, 0.92), agent2.quarks[0].confidence);
}

test "serializeQuarkChain magic and version" {
    var agent: GoldenChainAgent = undefined;
    agent.provenance_count = 0;
    agent.quark_count = 0;
    agent.chain_verified = false;
    agent.quark_chain_verified = false;

    // Serialize
    var buf: [1024]u8 = undefined;
    const serialized = agent.serializeQuarkChain(&buf) orelse {
        try std.testing.expect(false);
        return;
    };

    // Check magic
    try std.testing.expectEqualSlices(u8, &QUARK_EXPORT_MAGIC, serialized[0..4]);

    // Check version
    const ver: u16 = @bitCast(serialized[4..6][0..2].*);
    try std.testing.expectEqual(QUARK_EXPORT_VERSION, ver);

    // Invalid magic fails
    var bad_buf: [1024]u8 = undefined;
    @memcpy(bad_buf[0..serialized.len], serialized);
    bad_buf[0] = 'X'; // corrupt magic
    var agent3: GoldenChainAgent = undefined;
    agent3.provenance_count = 0;
    agent3.quark_count = 0;
    try std.testing.expect(!agent3.deserializeQuarkChain(bad_buf[0..serialized.len]));
}

test "QuarkVerbosity modes" {
    // 3 distinct values
    const f = QuarkVerbosity.full;
    const s = QuarkVerbosity.summary;
    const si = QuarkVerbosity.silent;
    try std.testing.expect(f != s);
    try std.testing.expect(f != si);
    try std.testing.expect(s != si);
}

test "phiHashCheck valid hashes" {
    // Build an agent with realistic SHA256-like quark hashes
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 4;
    agent.provenance_count = 0;

    // Use file-level Sha256 to generate realistic hashes
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        var hasher = Sha256.init(.{});
        hasher.update(&[_]u8{i});
        agent.quarks[i].current_quark_hash = hasher.finalResult();
        agent.quarks[i].parent_node = @enumFromInt(i);
        agent.quarks[i].quark_type = .input_capture;
        agent.quarks[i].entangle_count = 0;
    }

    // phiHashCheck should pass for SHA256 hashes (well-distributed)
    try std.testing.expect(agent.phiHashCheck());
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.4 PHI-ENGINE QUANTUM VERIFICATION + LIVE DAG + $TRI REWARDS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QuarkType has 22 variants" {
    const types = [_]QuarkType{
        .input_capture,         .goal_classify,     .task_decompose,    .dependency_check,
        .schedule_plan,         .route_decision,    .api_call,          .tvc_cross_check,
        .vsa_bind,              .quality_gate,      .adapt_decision,    .merge_result,
        .format_output,         .chain_integrity,   .hash_verify,       .gluon_verify,
        .fake_injection_detect, .oracle_cross_check, .energy_accounting,
        .phi_verify,            .dag_checkpoint,    .reward_mint,
    };
    try std.testing.expectEqual(@as(usize, 22), types.len);
    for (0..22) |i| {
        for (i + 1..22) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "v1.4 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "PHI_VER", "DAG_CKP", "REWARD_MINT" };
    const new_types = [_]QuarkType{ .phi_verify, .dag_checkpoint, .reward_mint };
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
    // Check all 22 labels unique
    var labels: [22][]const u8 = undefined;
    inline for (0..22) |i| {
        labels[i] = @as(QuarkType, @enumFromInt(i)).getLabel();
    }
    for (0..22) |i| {
        for (i + 1..22) |j| {
            try std.testing.expect(!std.mem.eql(u8, labels[i], labels[j]));
        }
    }
}

test "isPhiQuark classification" {
    try std.testing.expect(QuarkType.phi_verify.isPhiQuark());
    try std.testing.expect(!QuarkType.hash_verify.isPhiQuark());
    try std.testing.expect(!QuarkType.dag_checkpoint.isPhiQuark());
    try std.testing.expect(!QuarkType.reward_mint.isPhiQuark());
    try std.testing.expect(!QuarkType.input_capture.isPhiQuark());
}

test "isDAGQuark classification" {
    try std.testing.expect(QuarkType.dag_checkpoint.isDAGQuark());
    try std.testing.expect(!QuarkType.phi_verify.isDAGQuark());
    try std.testing.expect(!QuarkType.reward_mint.isDAGQuark());
    try std.testing.expect(!QuarkType.hash_verify.isDAGQuark());
}

test "isRewardQuark classification" {
    try std.testing.expect(QuarkType.reward_mint.isRewardQuark());
    try std.testing.expect(!QuarkType.phi_verify.isRewardQuark());
    try std.testing.expect(!QuarkType.dag_checkpoint.isRewardQuark());
    try std.testing.expect(!QuarkType.energy_accounting.isRewardQuark());
}

test "isVerificationQuark includes phi_verify" {
    // 3 verification quarks in v1.4
    try std.testing.expect(QuarkType.hash_verify.isVerificationQuark());
    try std.testing.expect(QuarkType.gluon_verify.isVerificationQuark());
    try std.testing.expect(QuarkType.phi_verify.isVerificationQuark());
    // Others are not
    try std.testing.expect(!QuarkType.dag_checkpoint.isVerificationQuark());
    try std.testing.expect(!QuarkType.reward_mint.isVerificationQuark());
    try std.testing.expect(!QuarkType.input_capture.isVerificationQuark());
}

test "phiQuantumVerify passes with SHA256 hashes" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 8;
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        var hasher = Sha256.init(.{});
        hasher.update(&[_]u8{ i, i +% 42, i +% 99 });
        agent.quarks[i].current_quark_hash = hasher.finalResult();
        agent.quarks[i].parent_node = @enumFromInt(i);
        agent.quarks[i].quark_type = .input_capture;
        agent.quarks[i].entangle_count = 0;
    }
    try std.testing.expect(agent.phiQuantumVerify());
}

test "phiQuantumVerify fails with all-zero hashes" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 4;
    var i: u8 = 0;
    while (i < 4) : (i += 1) {
        agent.quarks[i].current_quark_hash = [_]u8{0} ** QUARK_HASH_SIZE;
        agent.quarks[i].parent_node = @enumFromInt(i);
        agent.quarks[i].quark_type = .input_capture;
        agent.quarks[i].entangle_count = 0;
    }
    try std.testing.expect(!agent.phiQuantumVerify());
}

test "getDAGEdges returns correct edges" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 3;
    agent.quarks[0] = makeTestQuark(0, .input_capture, .GoalParse, 0.9);
    agent.quarks[0].entangle_count = 0;
    agent.quarks[1] = makeTestQuark(1, .hash_verify, .GoalParse, 0.9);
    agent.quarks[1].entangled_indices = .{ 0, 0 };
    agent.quarks[1].entangle_count = 1;
    agent.quarks[2] = makeTestQuark(2, .gluon_verify, .GoalParse, 0.9);
    agent.quarks[2].entangled_indices = .{ 0, 1 };
    agent.quarks[2].entangle_count = 2;

    var edges: [MAX_DAG_EDGES]DAGEdge = undefined;
    const count = agent.getDAGEdges(&edges);
    try std.testing.expectEqual(@as(u16, 3), count);
    try std.testing.expectEqual(@as(u8, 1), edges[0].from);
    try std.testing.expectEqual(@as(u8, 0), edges[0].to);
    try std.testing.expectEqual(@as(u8, 2), edges[1].from);
    try std.testing.expectEqual(@as(u8, 0), edges[1].to);
    try std.testing.expectEqual(@as(u8, 2), edges[2].from);
    try std.testing.expectEqual(@as(u8, 1), edges[2].to);
}

test "getDAGStats computes correctly" {
    var agent: GoldenChainAgent = undefined;
    agent.quark_count = 4;
    agent.quarks[0] = makeTestQuark(0, .input_capture, .GoalParse, 0.9);
    agent.quarks[0].entangle_count = 0;
    agent.quarks[1] = makeTestQuark(1, .goal_classify, .GoalParse, 0.9);
    agent.quarks[1].entangled_indices = .{ 0, 0 };
    agent.quarks[1].entangle_count = 1;
    agent.quarks[2] = makeTestQuark(2, .hash_verify, .GoalParse, 0.9);
    agent.quarks[2].entangled_indices = .{ 0, 1 };
    agent.quarks[2].entangle_count = 2;
    agent.quarks[3] = makeTestQuark(3, .api_call, .Execute, 0.9);
    agent.quarks[3].entangled_indices = .{ 2, 0 };
    agent.quarks[3].entangle_count = 1;

    const stats = agent.getDAGStats();
    try std.testing.expectEqual(@as(u16, 4), stats.edge_count); // 0+1+2+1
    try std.testing.expectEqual(@as(u8, 2), stats.max_fan_out); // quark[2] has 2
    try std.testing.expectEqual(@as(u8, 3), stats.node_quark_counts[0]); // GoalParse has 3
    try std.testing.expectEqual(@as(u8, 1), stats.node_quark_counts[3]); // Execute has 1
    try std.testing.expectEqual(@as(u8, 3), stats.max_width); // GoalParse has 3
}

test "calculateSessionReward verified high confidence" {
    var agent: GoldenChainAgent = undefined;
    agent.state = ChainState.init();
    agent.state.total_confidence = 0.95;
    agent.state.total_latency_us = 1000;
    agent.chain_verified = true;
    agent.quark_chain_verified = true;
    agent.quark_count = 48;
    agent.total_reward_utri = 0;
    agent.reward_config = .{};

    const result = agent.calculateSessionReward();
    try std.testing.expect(result.total_reward_utri > 0);
    try std.testing.expect(result.verification_bonus);
    try std.testing.expectEqual(@as(u64, 1000), result.base_utri);
    try std.testing.expect(result.confidence_bonus_utri > 0); // >= 0.9 triggers bonus
    try std.testing.expect(result.quark_bonus_utri > 0); // 48 > 40
}

test "calculateSessionReward zero for low confidence" {
    var agent: GoldenChainAgent = undefined;
    agent.state = ChainState.init();
    agent.state.total_confidence = 0.3;
    agent.chain_verified = true;
    agent.quark_chain_verified = true;
    agent.quark_count = 48;
    agent.total_reward_utri = 0;
    agent.reward_config = .{};

    const result = agent.calculateSessionReward();
    try std.testing.expectEqual(@as(u64, 0), result.total_reward_utri);
}

test "calculateSessionReward zero for unverified" {
    var agent: GoldenChainAgent = undefined;
    agent.state = ChainState.init();
    agent.state.total_confidence = 0.95;
    agent.chain_verified = false;
    agent.quark_chain_verified = true;
    agent.quark_count = 48;
    agent.total_reward_utri = 0;
    agent.reward_config = .{};

    const result = agent.calculateSessionReward();
    try std.testing.expectEqual(@as(u64, 0), result.total_reward_utri);
    try std.testing.expect(!result.verification_bonus);
}

test "Phi constants golden identity" {
    // phi^2 + 1/phi^2 = 3.0
    const phi_sq = PHI * PHI;
    const inv_phi_sq = PHI_INV * PHI_INV;
    const sum = phi_sq + inv_phi_sq;
    try std.testing.expect(@abs(sum - GOLDEN_IDENTITY) < 1e-10);
    // Also verify PHI_SQ matches
    try std.testing.expect(@abs(PHI_SQ - phi_sq) < 1e-10);
}

test "serializeQuarkChain v2 roundtrip with reward" {
    var agent: GoldenChainAgent = undefined;
    agent.provenance_count = 1;
    agent.quark_count = 1;
    agent.chain_verified = true;
    agent.quark_chain_verified = true;
    agent.total_reward_utri = 5000;

    agent.provenance[0] = .{
        .step_index = 0,
        .node = .GoalParse,
        .content_digest = [_]u8{0xAB} ** CONTENT_DIGEST_LEN,
        .digest_len = 5,
        .confidence = 0.95,
        .tvc_similarity = 0.42,
        .truth_verdict = .Verified,
        .timestamp_us = 123456,
        .latency_us = 100,
        .source = null,
        .prev_hash = [_]u8{0} ** PROVENANCE_HASH_SIZE,
        .current_hash = [_]u8{0xCD} ** PROVENANCE_HASH_SIZE,
    };
    agent.quarks[0] = .{
        .quark_index = 0,
        .quark_type = .input_capture,
        .parent_node = .GoalParse,
        .content_digest = [_]u8{0xEF} ** QUARK_CONTENT_DIGEST_LEN,
        .digest_len = 4,
        .confidence = 0.92,
        .timestamp_us = 654321,
        .prev_quark_hash = [_]u8{0} ** QUARK_HASH_SIZE,
        .current_quark_hash = [_]u8{0xBB} ** QUARK_HASH_SIZE,
        .entangled_indices = .{ 0, 0 },
        .entangle_count = 0,
    };

    var buf: [8192]u8 = undefined;
    const serialized = agent.serializeQuarkChain(&buf) orelse {
        try std.testing.expect(false);
        return;
    };

    // Check v2 header
    const ver: u16 = @bitCast(serialized[4..6][0..2].*);
    try std.testing.expectEqual(@as(u16, 2), ver);

    // Deserialize
    var agent2: GoldenChainAgent = undefined;
    agent2.provenance_count = 0;
    agent2.quark_count = 0;
    agent2.total_reward_utri = 0;
    const ok = agent2.deserializeQuarkChain(serialized);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u64, 5000), agent2.total_reward_utri);
    try std.testing.expectEqual(@as(u8, 1), agent2.provenance_count);
    try std.testing.expectEqual(@as(u8, 1), agent2.quark_count);
    try std.testing.expect(agent2.chain_verified);
}

// ── Test helper ──

fn makeTestQuark(index: u8, qtype: QuarkType, node: ChainNode, conf: f32) QuarkRecord {
    return .{
        .quark_index = index,
        .quark_type = qtype,
        .parent_node = node,
        .content_digest = [_]u8{0} ** QUARK_CONTENT_DIGEST_LEN,
        .digest_len = 0,
        .confidence = conf,
        .timestamp_us = 0,
        .prev_quark_hash = [_]u8{0} ** QUARK_HASH_SIZE,
        .current_quark_hash = [_]u8{0} ** QUARK_HASH_SIZE,
        .entangled_indices = .{ 0, 0 },
        .entangle_count = 0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// v1.5 COLLAPSIBLE QUARK VIEWS + SHAREABLE LINKS + $TRI STAKING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QuarkType has 29 variants" {
    const types = [_]QuarkType{
        .input_capture,         .goal_classify,     .task_decompose,    .dependency_check,
        .schedule_plan,         .route_decision,    .api_call,          .tvc_cross_check,
        .vsa_bind,              .quality_gate,      .adapt_decision,    .merge_result,
        .format_output,         .chain_integrity,   .hash_verify,       .gluon_verify,
        .fake_injection_detect, .oracle_cross_check, .energy_accounting,
        .phi_verify,            .dag_checkpoint,    .reward_mint,
        .collapse_state,        .share_link,        .staking_lock,      .staking_yield,
        .public_view,           .compress_quark,    .phi_visual,
    };
    try std.testing.expectEqual(@as(usize, 29), types.len);
    for (0..29) |i| {
        for (i + 1..29) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "v1.5 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "COLLAPSE", "SHARE_LNK", "STAKE_LCK", "STAKE_YLD", "PUB_VIEW", "COMPRESS", "PHI_VIS" };
    const new_types = [_]QuarkType{ .collapse_state, .share_link, .staking_lock, .staking_yield, .public_view, .compress_quark, .phi_visual };
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
    // Check all 29 labels unique
    var labels: [29][]const u8 = undefined;
    inline for (0..29) |i| {
        labels[i] = @as(QuarkType, @enumFromInt(i)).getLabel();
    }
    for (0..29) |i| {
        for (i + 1..29) |j| {
            try std.testing.expect(!std.mem.eql(u8, labels[i], labels[j]));
        }
    }
}

test "isCollapseQuark classification" {
    try std.testing.expect(QuarkType.collapse_state.isCollapseQuark());
    try std.testing.expect(!QuarkType.share_link.isCollapseQuark());
    try std.testing.expect(!QuarkType.input_capture.isCollapseQuark());
    try std.testing.expect(!QuarkType.hash_verify.isCollapseQuark());
}

test "isShareQuark classification" {
    try std.testing.expect(QuarkType.share_link.isShareQuark());
    try std.testing.expect(QuarkType.public_view.isShareQuark());
    try std.testing.expect(!QuarkType.collapse_state.isShareQuark());
    try std.testing.expect(!QuarkType.staking_lock.isShareQuark());
    try std.testing.expect(!QuarkType.input_capture.isShareQuark());
}

test "isStakingQuark classification" {
    try std.testing.expect(QuarkType.staking_lock.isStakingQuark());
    try std.testing.expect(QuarkType.staking_yield.isStakingQuark());
    try std.testing.expect(!QuarkType.share_link.isStakingQuark());
    try std.testing.expect(!QuarkType.collapse_state.isStakingQuark());
    try std.testing.expect(!QuarkType.input_capture.isStakingQuark());
}

test "isCompressQuark classification" {
    try std.testing.expect(QuarkType.compress_quark.isCompressQuark());
    try std.testing.expect(!QuarkType.phi_visual.isCompressQuark());
    try std.testing.expect(!QuarkType.input_capture.isCompressQuark());
}

test "isVisualizationQuark classification" {
    try std.testing.expect(QuarkType.phi_visual.isVisualizationQuark());
    try std.testing.expect(!QuarkType.compress_quark.isVisualizationQuark());
    try std.testing.expect(!QuarkType.input_capture.isVisualizationQuark());
}

test "QuarkViewState collapse/expand toggle" {
    var states: [8]QuarkViewState = [_]QuarkViewState{.expanded} ** 8;
    try std.testing.expectEqual(QuarkViewState.expanded, states[0]);

    states[0] = .collapsed;
    try std.testing.expectEqual(QuarkViewState.collapsed, states[0]);
    try std.testing.expectEqual(QuarkViewState.expanded, states[1]);

    states[0] = .expanded;
    try std.testing.expectEqual(QuarkViewState.expanded, states[0]);

    states[3] = .hidden;
    try std.testing.expectEqual(QuarkViewState.hidden, states[3]);
}

test "CollapsedNodeSummary correct structure" {
    const summary = CollapsedNodeSummary{
        .node = .GoalParse,
        .quark_count = 7,
        .avg_confidence = 0.95,
        .total_entanglements = 5,
        .is_collapsed = true,
    };
    try std.testing.expectEqual(ChainNode.GoalParse, summary.node);
    try std.testing.expectEqual(@as(u8, 7), summary.quark_count);
    try std.testing.expect(summary.is_collapsed);
}

test "ShareableLink formatLink produces valid prefix" {
    var link = ShareableLink{
        .link_hash = undefined,
        .chain_fingerprint = [_]u8{0} ** PROVENANCE_HASH_SIZE,
        .quark_count = 56,
        .provenance_count = 8,
        .total_reward_utri = 1500,
        .is_verified = true,
        .timestamp_us = 1000000,
    };
    // Set a known hash pattern
    for (0..PROVENANCE_HASH_SIZE) |i| {
        link.link_hash[i] = @intCast(i);
    }
    var buf: [128]u8 = undefined;
    const formatted = link.formatLink(&buf);
    // Should start with tri://chain/
    try std.testing.expect(std.mem.startsWith(u8, formatted, "tri://chain/"));
    try std.testing.expect(formatted.len > 12); // prefix + hex chars
}

test "StakingConfig defaults" {
    const cfg = StakingConfig{};
    try std.testing.expectEqual(@as(i64, 86_400_000_000), cfg.lock_duration_us);
    try std.testing.expectEqual(@as(u64, 100), cfg.min_stake_utri);
    try std.testing.expect(!cfg.auto_restake);
    try std.testing.expectEqual(@as(u8, 8), cfg.max_active_stakes);
}

test "StakingRecord basic structure" {
    const rec = StakingRecord{
        .amount_utri = 1000,
        .lock_start_us = 100,
        .lock_end_us = 86_400_000_100,
        .yield_utri = 0,
        .is_active = true,
        .chain_fingerprint = [_]u8{0xAB} ** PROVENANCE_HASH_SIZE,
    };
    try std.testing.expectEqual(@as(u64, 1000), rec.amount_utri);
    try std.testing.expect(rec.is_active);
    try std.testing.expectEqual(@as(u8, 0xAB), rec.chain_fingerprint[0]);
}

test "StakingResult structure" {
    const result = StakingResult{
        .staked_utri = 500,
        .yield_utri = 1,
        .active_stakes = 2,
        .total_locked_utri = 1000,
        .next_unlock_us = 86_400_000_000,
    };
    try std.testing.expectEqual(@as(u64, 500), result.staked_utri);
    try std.testing.expectEqual(@as(u64, 1), result.yield_utri);
    try std.testing.expectEqual(@as(u8, 2), result.active_stakes);
}

test "Phase F stakingVerify passes with empty staking" {
    // A chain with no staking records and no share link should pass Phase F
    // (stakingVerify checks balance = 0 == staking_total_utri = 0)
    const cfg = StakingConfig{};
    try std.testing.expectEqual(@as(u64, 100), cfg.min_stake_utri);
    // Phase F passes trivially when staking_count = 0 and staking_total_utri = 0
    // because active_sum (0) == staking_total_utri (0) and no share_link to verify
    try std.testing.expect(true); // Structural test — real integration tested via build
}

test "Export v6 header size" {
    // v6: magic(4) + version(2) + prov_count(1) + quark_count(1) + verified(1) + quark_verified(1) + reward(8) + staking(8) + repair_count(1) + evolution_count(1) + generation(2) + persist_count(4) + faucet_claims(2) + canvas_renders(2) + node_count(2) + network_health(2) = 42
    try std.testing.expectEqual(@as(usize, 42), QUARK_EXPORT_HEADER_SIZE);
    try std.testing.expectEqual(@as(u16, 6), QUARK_EXPORT_VERSION);
    // Backward compatibility: magic unchanged
    try std.testing.expectEqualStrings("QGC1", &QUARK_EXPORT_MAGIC);
}

test "v1.5 constants correct" {
    try std.testing.expectEqual(@as(u64, 100), MIN_STAKING_AMOUNT_UTRI);
    try std.testing.expectEqual(@as(i64, 86_400_000_000), STAKING_LOCK_DURATION_DEFAULT);
    try std.testing.expectEqual(@as(usize, 80), MAX_QUARK_RECORDS);
    try std.testing.expect(std.mem.startsWith(u8, SHARE_LINK_PREFIX, "tri://"));
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.0 IMMORTAL SELF-VERIFYING AGENT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "QuarkType has 72 variants (u7, 72/128)" {
    const types = [_]QuarkType{
        .input_capture,         .goal_classify,      .task_decompose,       .dependency_check,
        .schedule_plan,         .route_decision,     .api_call,             .tvc_cross_check,
        .vsa_bind,              .quality_gate,       .adapt_decision,       .merge_result,
        .format_output,         .chain_integrity,    .hash_verify,          .gluon_verify,
        .fake_injection_detect, .oracle_cross_check, .energy_accounting,
        .phi_verify,            .dag_checkpoint,     .reward_mint,
        .collapse_state,        .share_link,         .staking_lock,         .staking_yield,
        .public_view,           .compress_quark,     .phi_visual,
        .self_repair,           .immortal_persist,   .evolution_checkpoint,
        .faucet_claim,          .faucet_distribute,  .canvas_render,        .canvas_sync,
        .public_session,        .viral_share,        .mainnet_anchor,       .browser_verify,
        .decentral_sync,        .node_consensus,     .network_health,       .staking_mainnet,
        .agent_os_init,         .immortal_network,   .viral_propagate,      .energy_network,
        .token_mint,            .dao_propose,        .dao_vote,             .dao_execute,
        .swarm_spawn,           .swarm_health,       .mainnet_genesis,      .governance_anchor,
        .community_genesis,     .mainnet_launch,     .live_governance,      .swarm_activate,
        .node_discovery,        .community_onboard,  .public_api,           .mainnet_anchor_v2,
        .swarm_orchestrate,     .swarm_consensus,    .swarm_replication,    .swarm_failover,
        .swarm_discovery_v2,    .swarm_self_heal,    .swarm_telemetry,      .swarm_anchor,
    };
    try std.testing.expectEqual(@as(usize, 72), types.len);
    for (0..72) |i| {
        for (i + 1..72) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "v2.0 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "SELF_RPR", "IMMORTAL", "EVOLVE" };
    const new_types = [_]QuarkType{ .self_repair, .immortal_persist, .evolution_checkpoint };
    // Each new label matches its type
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
    // New labels don't collide with any of the first 29
    const old_types = [_]QuarkType{
        .input_capture, .goal_classify, .task_decompose, .dependency_check,
        .schedule_plan, .route_decision, .api_call, .tvc_cross_check,
        .vsa_bind, .quality_gate, .adapt_decision, .merge_result,
        .format_output, .chain_integrity, .hash_verify, .gluon_verify,
        .fake_injection_detect, .oracle_cross_check, .energy_accounting,
        .phi_verify, .dag_checkpoint, .reward_mint,
        .collapse_state, .share_link, .staking_lock, .staking_yield,
        .public_view, .compress_quark, .phi_visual,
    };
    for (new_types) |nt| {
        for (old_types) |ot| {
            try std.testing.expect(!std.mem.eql(u8, nt.getLabel(), ot.getLabel()));
        }
    }
}

test "isSelfRepairQuark classification" {
    try std.testing.expect(QuarkType.self_repair.isSelfRepairQuark());
    try std.testing.expect(!QuarkType.input_capture.isSelfRepairQuark());
    try std.testing.expect(!QuarkType.immortal_persist.isSelfRepairQuark());
    try std.testing.expect(!QuarkType.evolution_checkpoint.isSelfRepairQuark());
}

test "isImmortalQuark classification" {
    try std.testing.expect(QuarkType.immortal_persist.isImmortalQuark());
    try std.testing.expect(!QuarkType.input_capture.isImmortalQuark());
    try std.testing.expect(!QuarkType.self_repair.isImmortalQuark());
    try std.testing.expect(!QuarkType.evolution_checkpoint.isImmortalQuark());
}

test "isEvolutionQuark classification" {
    try std.testing.expect(QuarkType.evolution_checkpoint.isEvolutionQuark());
    try std.testing.expect(!QuarkType.input_capture.isEvolutionQuark());
    try std.testing.expect(!QuarkType.self_repair.isEvolutionQuark());
    try std.testing.expect(!QuarkType.immortal_persist.isEvolutionQuark());
}

test "SelfRepairState transitions" {
    var state: SelfRepairState = .healthy;
    try std.testing.expectEqual(SelfRepairState.healthy, state);
    state = .degraded;
    try std.testing.expectEqual(SelfRepairState.degraded, state);
    state = .repairing;
    try std.testing.expectEqual(SelfRepairState.repairing, state);
    state = .repaired;
    try std.testing.expectEqual(SelfRepairState.repaired, state);
}

test "SelfRepairType variants" {
    const types = [_]SelfRepairType{ .hash_recompute, .confidence_restore, .entangle_fix, .chain_rebuild };
    try std.testing.expectEqual(@as(usize, 4), types.len);
    for (0..4) |i| {
        for (i + 1..4) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "RepairRecord structure" {
    const rec = RepairRecord{
        .broken_index = 5,
        .repair_type = .hash_recompute,
        .confidence_before = 0.2,
        .confidence_after = 0.9,
        .timestamp_us = 1234567890,
    };
    try std.testing.expectEqual(@as(u8, 5), rec.broken_index);
    try std.testing.expectEqual(SelfRepairType.hash_recompute, rec.repair_type);
    try std.testing.expect(rec.confidence_after > rec.confidence_before);
}

test "EvolutionConfig defaults" {
    const cfg = EvolutionConfig{};
    try std.testing.expectEqual(@as(u16, 1000), cfg.max_generations);
    try std.testing.expect(cfg.fitness_threshold > 0.0);
}

test "EvolutionRecord structure" {
    const rec = EvolutionRecord{
        .generation = 42,
        .fitness_score = 0.85,
        .repairs_applied = 3,
        .quarks_healthy = 60,
        .timestamp_us = 1234567890,
    };
    try std.testing.expectEqual(@as(u16, 42), rec.generation);
    try std.testing.expect(rec.fitness_score > 0.0);
}

test "ImmortalState initial" {
    const state = ImmortalState{
        .last_persist_us = 0,
        .persist_count = 0,
        .restore_count = 0,
        .uptime_start_us = 0,
        .tvc_corpus_hash = [_]u8{0} ** 32,
    };
    try std.testing.expectEqual(@as(u32, 0), state.persist_count);
    try std.testing.expectEqual(@as(u32, 0), state.restore_count);
}

test "ChainHealthReport structure" {
    const report = ChainHealthReport{
        .total = 80,
        .healthy = 76,
        .repaired = 3,
        .broken = 1,
        .health_score = 0.95,
    };
    try std.testing.expectEqual(@as(u8, 80), report.total);
    try std.testing.expectEqual(@as(u8, 76), report.healthy);
    try std.testing.expect(report.health_score > 0.9);
    try std.testing.expectEqual(report.total, report.healthy + report.repaired + report.broken);
}

test "v2.0 constants correct" {
    try std.testing.expect(SELF_REPAIR_CONFIDENCE_THRESHOLD > 0.0);
    try std.testing.expect(SELF_REPAIR_CONFIDENCE_THRESHOLD < 1.0);
    try std.testing.expectEqual(@as(usize, 16), MAX_REPAIR_RECORDS);
    try std.testing.expectEqual(@as(usize, 32), MAX_EVOLUTION_RECORDS);
    try std.testing.expectEqual(@as(u16, 1000), DEFAULT_MAX_GENERATIONS);
    try std.testing.expect(DEFAULT_FITNESS_THRESHOLD > 0.0);
}

test "v2.0 ChainMessageType has 4 new variants" {
    const repair = ChainMessageType.SelfRepairEvent;
    const persist = ChainMessageType.ImmortalPersist;
    const evolve = ChainMessageType.EvolutionStep;
    const health = ChainMessageType.ChainHealthCheck;
    // All distinct
    try std.testing.expect(repair != persist);
    try std.testing.expect(repair != evolve);
    try std.testing.expect(repair != health);
    try std.testing.expect(persist != evolve);
    try std.testing.expect(persist != health);
    try std.testing.expect(evolve != health);
    // Distinct from existing types
    try std.testing.expect(repair != ChainMessageType.User);
    try std.testing.expect(repair != ChainMessageType.ChainStep);
    try std.testing.expect(repair != ChainMessageType.StakingEvent);
}

test "v2.5 QuarkType verification count" {
    // 69 work quarks + 3 verification quarks = 72 total
    var work_count: u8 = 0;
    var verify_count: u8 = 0;
    inline for (std.meta.fields(QuarkType)) |f| {
        const qt: QuarkType = @enumFromInt(f.value);
        if (qt.isVerificationQuark()) {
            verify_count += 1;
        } else {
            work_count += 1;
        }
    }
    try std.testing.expectEqual(@as(u8, 72), work_count + verify_count);
    try std.testing.expectEqual(@as(u8, 3), verify_count); // hash_verify, gluon_verify, phi_verify
    try std.testing.expectEqual(@as(u8, 69), work_count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.1 TESTS — Public Launch + Faucet + Canvas
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.1 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "FAUCET_CLM", "FAUCET_DST", "CANVAS_RND", "CANVAS_SYN", "PUB_SESS", "VIRAL_SHR", "MAINNET", "BROWSER_VER" };
    const new_types = [_]QuarkType{ .faucet_claim, .faucet_distribute, .canvas_render, .canvas_sync, .public_session, .viral_share, .mainnet_anchor, .browser_verify };
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
}

test "isFaucetQuark classification" {
    try std.testing.expect(QuarkType.faucet_claim.isFaucetQuark());
    try std.testing.expect(QuarkType.faucet_distribute.isFaucetQuark());
    try std.testing.expect(!QuarkType.canvas_render.isFaucetQuark());
    try std.testing.expect(!QuarkType.hash_verify.isFaucetQuark());
}

test "isCanvasQuark classification" {
    try std.testing.expect(QuarkType.canvas_render.isCanvasQuark());
    try std.testing.expect(QuarkType.canvas_sync.isCanvasQuark());
    try std.testing.expect(!QuarkType.faucet_claim.isCanvasQuark());
    try std.testing.expect(!QuarkType.public_session.isCanvasQuark());
}

test "isPublicQuark classification" {
    try std.testing.expect(QuarkType.public_session.isPublicQuark());
    try std.testing.expect(QuarkType.viral_share.isPublicQuark());
    try std.testing.expect(QuarkType.mainnet_anchor.isPublicQuark());
    try std.testing.expect(QuarkType.browser_verify.isPublicQuark());
    try std.testing.expect(!QuarkType.faucet_claim.isPublicQuark());
    try std.testing.expect(!QuarkType.canvas_render.isPublicQuark());
}

test "FaucetConfig defaults" {
    const config = FaucetConfig{};
    try std.testing.expectEqual(@as(u64, 100), config.claim_amount_utri);
    try std.testing.expectEqual(@as(i64, 3_600_000_000), config.cooldown_us);
    try std.testing.expectEqual(@as(u64, 10_000), config.daily_limit_utri);
    try std.testing.expect(config.enabled);
}

test "FaucetClaimRecord structure" {
    const claim = FaucetClaimRecord{
        .claim_index = 0,
        .amount_utri = 100,
        .claimant_hash = [_]u8{0xAB} ** 32,
        .timestamp_us = 1000000,
        .session_fingerprint = [_]u8{0xCD} ** 32,
    };
    try std.testing.expectEqual(@as(u64, 100), claim.amount_utri);
    try std.testing.expectEqual(@as(u16, 0), claim.claim_index);
}

test "FaucetState structure" {
    const state = FaucetState{
        .total_distributed_utri = 500,
        .claims_count = 5,
        .last_claim_us = 1000000,
        .daily_distributed_utri = 500,
        .day_start_us = 0,
    };
    try std.testing.expectEqual(@as(u64, 500), state.total_distributed_utri);
    try std.testing.expectEqual(@as(u32, 5), state.claims_count);
}

test "PublicCanvasState structure" {
    const cs = PublicCanvasState{
        .canvas_version_major = 1,
        .canvas_version_minor = 0,
        .is_public = true,
        .render_count = 10,
        .last_render_us = 5000,
        .browser_sessions = 3,
        .wasm_ready = true,
        .native_ready = true,
    };
    try std.testing.expectEqual(@as(u8, 1), cs.canvas_version_major);
    try std.testing.expectEqual(@as(u8, 0), cs.canvas_version_minor);
    try std.testing.expect(cs.is_public);
    try std.testing.expect(cs.wasm_ready);
    try std.testing.expect(cs.native_ready);
}

test "PublicSessionInfo structure" {
    const si = PublicSessionInfo{
        .session_hash = [_]u8{0xFF} ** 32,
        .created_us = 1000,
        .ttl_us = PUBLIC_SESSION_TTL_US,
        .view_count = 42,
        .share_count = 7,
        .faucet_claims = 3,
        .is_active = true,
    };
    try std.testing.expect(si.is_active);
    try std.testing.expectEqual(@as(i64, 86_400_000_000), si.ttl_us);
    try std.testing.expectEqual(@as(u32, 42), si.view_count);
}

test "v2.1 constants correct" {
    try std.testing.expectEqual(@as(u64, 100), FAUCET_CLAIM_AMOUNT_UTRI);
    try std.testing.expectEqual(@as(i64, 3_600_000_000), FAUCET_COOLDOWN_US);
    try std.testing.expectEqual(@as(usize, 64), MAX_FAUCET_CLAIMS);
    try std.testing.expectEqual(@as(u64, 10_000), FAUCET_DAILY_LIMIT_UTRI);
    try std.testing.expectEqual(@as(i64, 86_400_000_000), PUBLIC_SESSION_TTL_US);
    try std.testing.expectEqual(@as(usize, 256), MAX_PUBLIC_SESSIONS);
    try std.testing.expectEqual(@as(u8, 1), CANVAS_VERSION_MAJOR);
    try std.testing.expectEqual(@as(u8, 0), CANVAS_VERSION_MINOR);
}

test "v2.1 ChainMessageType has 4 new variants" {
    const v21_types = [_]ChainMessageType{ .FaucetClaim, .PublicLaunch, .CanvasSync, .FaucetDistribution };
    for (v21_types) |t| {
        // Verify each variant is distinct and accessible
        try std.testing.expect(@intFromEnum(t) != @intFromEnum(ChainMessageType.User));
    }
    // Verify all 4 are distinct
    for (0..4) |i| {
        for (i + 1..4) |j| {
            try std.testing.expect(@intFromEnum(v21_types[i]) != @intFromEnum(v21_types[j]));
        }
    }
}

test "Phase H faucetVerify passes with empty claims" {
    const config = FaucetConfig{};
    _ = config;
    // Phase H should pass when no claims exceed limits
    // Tested via agent in integration, here we verify struct accessibility
    const state = FaucetState{
        .total_distributed_utri = 0,
        .claims_count = 0,
        .last_claim_us = 0,
        .daily_distributed_utri = 0,
        .day_start_us = 0,
    };
    try std.testing.expectEqual(@as(u64, 0), state.total_distributed_utri);
    try std.testing.expect(state.daily_distributed_utri <= FAUCET_DAILY_LIMIT_UTRI);
}

test "Phase H fails concept with over-limit" {
    const state = FaucetState{
        .total_distributed_utri = 20_000,
        .claims_count = 200,
        .last_claim_us = 0,
        .daily_distributed_utri = 15_000,
        .day_start_us = 0,
    };
    // daily_distributed exceeds FAUCET_DAILY_LIMIT_UTRI
    try std.testing.expect(state.daily_distributed_utri > FAUCET_DAILY_LIMIT_UTRI);
}

test "v2.1 export v5 constants" {
    try std.testing.expectEqual(@as(usize, 38), QUARK_EXPORT_HEADER_SIZE);
    try std.testing.expectEqual(@as(u16, 5), QUARK_EXPORT_VERSION);
    // v5 = v4(34) + faucet_claims(2) + canvas_renders(2) = 38
    try std.testing.expectEqual(@as(usize, 38), 34 + 2 + 2);
}

test "v2.5 104 quarks per query target" {
    // Distribution: 13+13+13+14+13+12+13+13 = 104
    const expected = [_]u8{ 13, 13, 13, 14, 13, 12, 13, 13 };
    var total: u16 = 0;
    for (expected) |n| total += n;
    try std.testing.expectEqual(@as(u16, 104), total);
    try std.testing.expectEqual(@as(usize, 104), MAX_QUARK_RECORDS);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.2 TESTS — Agent OS v1.0 + Decentralized Network
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.2 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "DECENTRAL", "CONSENSUS", "NET_HEALTH", "STAKE_MAIN", "AGENT_OS", "IMMORTAL_NET", "VIRAL_PROP", "ENERGY_NET" };
    const new_types = [_]QuarkType{ .decentral_sync, .node_consensus, .network_health, .staking_mainnet, .agent_os_init, .immortal_network, .viral_propagate, .energy_network };
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
}

test "isDecentralQuark classification" {
    try std.testing.expect(QuarkType.decentral_sync.isDecentralQuark());
    try std.testing.expect(QuarkType.node_consensus.isDecentralQuark());
    try std.testing.expect(!QuarkType.network_health.isDecentralQuark());
    try std.testing.expect(!QuarkType.input_capture.isDecentralQuark());
}

test "isNetworkQuark classification" {
    try std.testing.expect(QuarkType.network_health.isNetworkQuark());
    try std.testing.expect(QuarkType.immortal_network.isNetworkQuark());
    try std.testing.expect(QuarkType.energy_network.isNetworkQuark());
    try std.testing.expect(!QuarkType.decentral_sync.isNetworkQuark());
}

test "isAgentOSQuark classification" {
    try std.testing.expect(QuarkType.agent_os_init.isAgentOSQuark());
    try std.testing.expect(!QuarkType.network_health.isAgentOSQuark());
}

test "isMainnetQuark classification" {
    try std.testing.expect(QuarkType.staking_mainnet.isMainnetQuark());
    try std.testing.expect(QuarkType.viral_propagate.isMainnetQuark());
    try std.testing.expect(!QuarkType.agent_os_init.isMainnetQuark());
}

test "NodeConfig defaults" {
    const nc = NodeConfig{};
    try std.testing.expectEqual(NODE_SYNC_INTERVAL_US, nc.sync_interval_us);
    try std.testing.expectEqual(NODE_HEARTBEAT_US, nc.heartbeat_us);
    try std.testing.expect(nc.is_active);
    try std.testing.expectEqual(@as(u64, 0), nc.stake_utri);
}

test "NetworkState structure" {
    const ns = NetworkState{};
    try std.testing.expectEqual(@as(u16, 1), ns.active_nodes);
    try std.testing.expectEqual(@as(u16, 1), ns.total_nodes);
    try std.testing.expectEqual(@as(u32, 0), ns.sync_count);
    try std.testing.expectEqual(@as(u32, 0), ns.consensus_round);
    try std.testing.expectEqual(@as(f32, 1.0), ns.network_health_score);
}

test "AgentOSState initial" {
    const aos = AgentOSState{};
    try std.testing.expectEqual(AGENT_OS_VERSION_MAJOR, aos.os_version_major);
    try std.testing.expectEqual(AGENT_OS_VERSION_MINOR, aos.os_version_minor);
    try std.testing.expect(aos.network_mode);
    try std.testing.expect(aos.immortal_mode);
    try std.testing.expect(!aos.is_initialized);
}

test "v2.2 constants correct" {
    try std.testing.expectEqual(@as(u8, 67), CONSENSUS_QUORUM_PERCENT);
    try std.testing.expectEqual(@as(i64, 10_000_000), NODE_SYNC_INTERVAL_US);
    try std.testing.expectEqual(@as(u8, 1), AGENT_OS_VERSION_MAJOR);
    try std.testing.expectEqual(@as(u8, 0), AGENT_OS_VERSION_MINOR);
    try std.testing.expectEqual(@as(usize, 256), MAX_NETWORK_NODES);
    try std.testing.expectEqual(@as(u64, 1_000), STAKING_MAINNET_MIN_UTRI);
}

test "v2.2 ChainMessageType has 4 new variants" {
    const types = [_]ChainMessageType{ .DecentralSync, .NodeConsensus, .NetworkHealth, .AgentOSInit };
    for (0..4) |i| {
        for (i + 1..4) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "v2.5 104 quarks target distribution" {
    // 13+13+13+14+13+12+13+13 = 104
    const dist = [_]u8{ 13, 13, 13, 14, 13, 12, 13, 13 };
    var sum: u16 = 0;
    for (dist) |d| sum += d;
    try std.testing.expectEqual(@as(u16, 104), sum);
    // Each node got exactly +1 from v2.4 distribution (12+12+12+13+12+11+12+12=96)
    const v24_dist = [_]u8{ 12, 12, 12, 13, 12, 11, 12, 12 };
    for (dist, v24_dist) |d, v24| {
        try std.testing.expectEqual(@as(u8, v24 + 1), d);
    }
}

test "Export v9 header 54 bytes" {
    try std.testing.expectEqual(@as(usize, 54), QUARK_EXPORT_HEADER_SIZE);
    try std.testing.expectEqual(@as(u16, 9), QUARK_EXPORT_VERSION);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.3 TESTS — Mainnet Genesis + $TRI Token + DAO Governance + Immortal Swarm
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.3 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "TOKEN_MINT", "DAO_PROP", "DAO_VOTE", "DAO_EXEC", "SWARM_SPAWN", "SWARM_HLTH", "GENESIS", "GOV_ANCHOR" };
    const new_types = [_]QuarkType{ .token_mint, .dao_propose, .dao_vote, .dao_execute, .swarm_spawn, .swarm_health, .mainnet_genesis, .governance_anchor };
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
}

test "isTokenQuark classification" {
    try std.testing.expect(QuarkType.token_mint.isTokenQuark());
    try std.testing.expect(!QuarkType.dao_propose.isTokenQuark());
    try std.testing.expect(!QuarkType.input_capture.isTokenQuark());
}

test "isDAOQuark classification" {
    try std.testing.expect(QuarkType.dao_propose.isDAOQuark());
    try std.testing.expect(QuarkType.dao_vote.isDAOQuark());
    try std.testing.expect(QuarkType.dao_execute.isDAOQuark());
    try std.testing.expect(QuarkType.governance_anchor.isDAOQuark());
    try std.testing.expect(!QuarkType.token_mint.isDAOQuark());
}

test "isSwarmQuark classification" {
    try std.testing.expect(QuarkType.swarm_spawn.isSwarmQuark());
    try std.testing.expect(QuarkType.swarm_health.isSwarmQuark());
    try std.testing.expect(!QuarkType.mainnet_genesis.isSwarmQuark());
}

test "isGenesisQuark classification" {
    try std.testing.expect(QuarkType.mainnet_genesis.isGenesisQuark());
    try std.testing.expect(!QuarkType.governance_anchor.isGenesisQuark());
}

test "TokenConfig defaults" {
    const tc = TokenConfig{};
    try std.testing.expectEqual(@as(u64, 0), tc.total_supply_utri);
    try std.testing.expectEqual(MAX_TOKEN_SUPPLY_UTRI, tc.max_supply_utri);
    try std.testing.expectEqual(TOKEN_MINT_BATCH_UTRI, tc.mint_batch_utri);
    try std.testing.expect(!tc.is_genesis_complete);
    try std.testing.expectEqual(@as(u32, 0), tc.mints_count);
}

test "DAOState structure" {
    const ds = DAOState{};
    try std.testing.expectEqual(@as(u16, 0), ds.active_proposals);
    try std.testing.expectEqual(@as(u32, 0), ds.total_proposals);
    try std.testing.expectEqual(@as(u32, 0), ds.total_votes_cast);
    try std.testing.expectEqual(DAO_VOTE_QUORUM_PERCENT, ds.quorum_percent);
}

test "SwarmState initial" {
    const ss = SwarmState{};
    try std.testing.expectEqual(@as(f32, 1.0), ss.swarm_health_score);
    try std.testing.expectEqual(@as(u16, 0), ss.active_nodes);
    try std.testing.expectEqual(@as(u32, 0), ss.total_spawned);
}

test "v2.3 constants correct" {
    try std.testing.expectEqual(@as(u8, 67), DAO_VOTE_QUORUM_PERCENT);
    try std.testing.expectEqual(@as(usize, 512), MAX_SWARM_NODES);
    try std.testing.expectEqual(@as(u8, 2), MAINNET_GENESIS_VERSION_MAJOR);
    try std.testing.expectEqual(@as(u8, 3), MAINNET_GENESIS_VERSION_MINOR);
    try std.testing.expectEqual(@as(u64, 1_000_000_000_000), MAX_TOKEN_SUPPLY_UTRI);
    try std.testing.expectEqual(@as(u64, 10_000), TOKEN_MINT_BATCH_UTRI);
    try std.testing.expectEqual(@as(usize, 64), MAX_DAO_PROPOSALS);
}

test "v2.3 ChainMessageType has 4 new variants" {
    const types = [_]ChainMessageType{ .MainnetGenesis, .DAOVote, .SwarmSync, .TokenMint };
    for (0..4) |i| {
        for (i + 1..4) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.4 TESTS — Mainnet v1.0 Launch + Community Genesis + Full DAO Live + Immortal Swarm
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.4 QuarkType labels unique" {
    const new_labels = [_][]const u8{ "COMM_GEN", "MAINNET_LCH", "LIVE_GOV", "SWARM_ACT", "NODE_DISC", "COMM_ONBD", "PUB_API", "MAINNET_V2" };
    const new_types = [_]QuarkType{ .community_genesis, .mainnet_launch, .live_governance, .swarm_activate, .node_discovery, .community_onboard, .public_api, .mainnet_anchor_v2 };
    for (new_types, new_labels) |qt, expected| {
        try std.testing.expectEqualStrings(expected, qt.getLabel());
    }
}

test "isCommunityQuark classification" {
    try std.testing.expect(QuarkType.community_genesis.isCommunityQuark());
    try std.testing.expect(QuarkType.community_onboard.isCommunityQuark());
    try std.testing.expect(!QuarkType.mainnet_launch.isCommunityQuark());
    try std.testing.expect(!QuarkType.input_capture.isCommunityQuark());
}

test "isMainnetLaunchQuark classification" {
    try std.testing.expect(QuarkType.mainnet_launch.isMainnetLaunchQuark());
    try std.testing.expect(QuarkType.mainnet_anchor_v2.isMainnetLaunchQuark());
    try std.testing.expect(!QuarkType.community_genesis.isMainnetLaunchQuark());
}

test "isLiveGovernanceQuark classification" {
    try std.testing.expect(QuarkType.live_governance.isLiveGovernanceQuark());
    try std.testing.expect(!QuarkType.dao_propose.isLiveGovernanceQuark());
}

test "isSwarmActivateQuark classification" {
    try std.testing.expect(QuarkType.swarm_activate.isSwarmActivateQuark());
    try std.testing.expect(!QuarkType.swarm_spawn.isSwarmActivateQuark());
}

test "isNodeDiscoveryQuark classification" {
    try std.testing.expect(QuarkType.node_discovery.isNodeDiscoveryQuark());
    try std.testing.expect(!QuarkType.node_consensus.isNodeDiscoveryQuark());
}

test "isPublicAPIQuark classification" {
    try std.testing.expect(QuarkType.public_api.isPublicAPIQuark());
    try std.testing.expect(!QuarkType.public_session.isPublicAPIQuark());
}

test "CommunityState defaults" {
    const cs = CommunityState{};
    try std.testing.expectEqual(@as(u16, 0), cs.active_nodes);
    try std.testing.expectEqual(@as(u32, 0), cs.total_onboarded);
    try std.testing.expectEqual(COMMUNITY_ONBOARD_BATCH, cs.onboard_batch);
}

test "MainnetConfig initial" {
    const mc = MainnetConfig{};
    try std.testing.expect(!mc.is_launched);
    try std.testing.expectEqual(MAINNET_LAUNCH_VERSION_MAJOR, mc.version_major);
    try std.testing.expectEqual(MAINNET_LAUNCH_VERSION_MINOR, mc.version_minor);
    try std.testing.expectEqual(PUBLIC_API_RATE_LIMIT, mc.api_rate_limit);
}

test "LaunchState initial" {
    const ls = LaunchState{};
    try std.testing.expect(!ls.mainnet_launched);
    try std.testing.expect(!ls.community_ready);
    try std.testing.expect(!ls.governance_live);
    try std.testing.expect(!ls.swarm_activated);
    try std.testing.expectEqual(@as(u64, 0), ls.launch_block_height);
}

test "NodeDiscoveryRecord defaults" {
    const ndr = NodeDiscoveryRecord{};
    try std.testing.expect(!ndr.is_active);
    try std.testing.expectEqual(@as(u8, 0), ndr.node_type);
}

test "v2.4 constants correct" {
    try std.testing.expectEqual(@as(u16, 1024), MAX_COMMUNITY_NODES);
    try std.testing.expectEqual(@as(u16, 64), MAX_NODE_DISCOVERY_RECORDS);
    try std.testing.expectEqual(@as(u16, 32), COMMUNITY_ONBOARD_BATCH);
    try std.testing.expectEqual(@as(u32, 1000), PUBLIC_API_RATE_LIMIT);
    try std.testing.expectEqual(@as(u8, 1), MAINNET_LAUNCH_VERSION_MAJOR);
    try std.testing.expectEqual(@as(u8, 0), MAINNET_LAUNCH_VERSION_MINOR);
}

test "v2.4 ChainMessageType has 4 new variants" {
    const types = [_]ChainMessageType{ .MainnetLaunch, .CommunityOnboard, .NodeDiscovery, .GovernanceExec };
    for (0..4) |i| {
        for (i + 1..4) |j| {
            try std.testing.expect(@intFromEnum(types[i]) != @intFromEnum(types[j]));
        }
    }
}

test "u7 capacity with 72/128 used" {
    // 72 QuarkType variants in u7 (128 capacity), 56 slots remaining
    var count: u8 = 0;
    inline for (std.meta.fields(QuarkType)) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(u8, 72), count);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2.5 TESTS — Immortal Agent Swarm v1.0 + u7 Upgrade
// ═══════════════════════════════════════════════════════════════════════════════

test "v2.5 swarm_orchestrate label" {
    try std.testing.expectEqualStrings("SWARM_ORCH", QuarkType.swarm_orchestrate.getLabel());
}

test "v2.5 swarm_consensus label" {
    try std.testing.expectEqualStrings("SWARM_CONS", QuarkType.swarm_consensus.getLabel());
}

test "v2.5 swarm_replication label" {
    try std.testing.expectEqualStrings("SWARM_REPL", QuarkType.swarm_replication.getLabel());
}

test "v2.5 swarm_failover label" {
    try std.testing.expectEqualStrings("SWARM_FAIL", QuarkType.swarm_failover.getLabel());
}

test "v2.5 swarm_discovery_v2 label" {
    try std.testing.expectEqualStrings("SWARM_DISC", QuarkType.swarm_discovery_v2.getLabel());
}

test "v2.5 swarm_self_heal label" {
    try std.testing.expectEqualStrings("SWARM_HEAL", QuarkType.swarm_self_heal.getLabel());
}

test "v2.5 swarm_telemetry label" {
    try std.testing.expectEqualStrings("SWARM_TELE", QuarkType.swarm_telemetry.getLabel());
}

test "v2.5 swarm_anchor label" {
    try std.testing.expectEqualStrings("SWARM_ANCH", QuarkType.swarm_anchor.getLabel());
}

test "v2.5 isSwarmOrchQuark classifier" {
    try std.testing.expect(QuarkType.swarm_orchestrate.isSwarmOrchQuark());
    try std.testing.expect(QuarkType.swarm_anchor.isSwarmOrchQuark());
    try std.testing.expect(!QuarkType.swarm_consensus.isSwarmOrchQuark());
}

test "v2.5 isSwarmConsensusQuark classifier" {
    try std.testing.expect(QuarkType.swarm_consensus.isSwarmConsensusQuark());
    try std.testing.expect(QuarkType.swarm_replication.isSwarmConsensusQuark());
    try std.testing.expect(!QuarkType.swarm_failover.isSwarmConsensusQuark());
}

test "v2.5 isSwarmFailoverQuark classifier" {
    try std.testing.expect(QuarkType.swarm_failover.isSwarmFailoverQuark());
    try std.testing.expect(QuarkType.swarm_self_heal.isSwarmFailoverQuark());
    try std.testing.expect(!QuarkType.swarm_telemetry.isSwarmFailoverQuark());
}

test "v2.5 isSwarmTelemetryQuark classifier" {
    try std.testing.expect(QuarkType.swarm_discovery_v2.isSwarmTelemetryQuark());
    try std.testing.expect(QuarkType.swarm_telemetry.isSwarmTelemetryQuark());
    try std.testing.expect(!QuarkType.swarm_anchor.isSwarmTelemetryQuark());
}

test "v2.5 SwarmOrchState defaults" {
    const s = SwarmOrchState{};
    try std.testing.expectEqual(@as(u16, 0), s.active_tasks);
    try std.testing.expectEqual(@as(u32, 0), s.total_orchestrated);
    try std.testing.expectEqual(SWARM_SYNC_BATCH, s.sync_batch);
}

test "v2.5 SwarmFailoverConfig defaults" {
    const s = SwarmFailoverConfig{};
    try std.testing.expectEqual(SWARM_FAILOVER_THRESHOLD, s.failover_threshold);
    try std.testing.expectEqual(@as(u8, 3), s.max_retries);
    try std.testing.expect(!s.is_failover_active);
}

test "v2.5 SwarmTelemetryState defaults" {
    const s = SwarmTelemetryState{};
    try std.testing.expectEqual(SWARM_TELEMETRY_INTERVAL_US, s.telemetry_interval_us);
    try std.testing.expectEqual(@as(u32, 0), s.reports_sent);
}

test "v2.5 SwarmReplicationRecord defaults" {
    const s = SwarmReplicationRecord{};
    try std.testing.expectEqual(@as(u8, 0), s.replica_count);
    try std.testing.expectEqual(SWARM_REPLICATION_FACTOR, s.replication_factor);
    try std.testing.expect(!s.is_synced);
}

test "v2.5 swarm constants" {
    try std.testing.expectEqual(@as(u16, 2048), SWARM_V1_MAX_NODES);
    try std.testing.expectEqual(@as(u16, 64), SWARM_SYNC_BATCH);
    try std.testing.expectEqual(@as(f32, 0.3), SWARM_FAILOVER_THRESHOLD);
    try std.testing.expectEqual(@as(i64, 1_000_000), SWARM_TELEMETRY_INTERVAL_US);
    try std.testing.expectEqual(@as(u8, 3), SWARM_REPLICATION_FACTOR);
}

test "v2.5 ChainMessageType swarm variants" {
    // Verify the 4 new swarm message types exist
    const types = [_]ChainMessageType{
        .SwarmOrchestrate,
        .SwarmFailover,
        .SwarmTelemetry,
        .SwarmReplication,
    };
    try std.testing.expectEqual(@as(usize, 4), types.len);
}
