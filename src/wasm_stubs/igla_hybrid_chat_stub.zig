// WASM stub for igla_hybrid_chat — replaces system-dependent hybrid chat
// Provides same interface: IglaHybridChat, HybridConfig, g_last_wave_state
// All API/network calls stubbed out

const std = @import("std");
const local_chat = @import("igla_chat");
const tvc = @import("tvc_corpus");

pub const ReflectionStatus = enum {
    Saved, FilteredLength, FilteredConfidence, FilteredError,
    FilteredDedup, NoCorpus, Disabled, NotApplicable,

    pub fn getName(self: ReflectionStatus) []const u8 {
        return switch (self) {
            .Saved => "Saved",
            .FilteredLength => "FilteredLength",
            .FilteredConfidence => "FilteredConfidence",
            .FilteredError => "FilteredError",
            .FilteredDedup => "FilteredDedup",
            .NoCorpus => "NoCorpus",
            .Disabled => "Disabled",
            .NotApplicable => "N/A",
        };
    }

    pub fn wasLearned(self: ReflectionStatus) bool {
        return self == .Saved;
    }
};

pub const RoutingDecision = enum {
    RouteSymbolic, RouteTVC, RouteMemory, RouteLocalLLM, RouteGroq, RouteClaude, RouteFallback,

    pub fn getName(self: RoutingDecision) []const u8 {
        return switch (self) {
            .RouteSymbolic => "Symbolic",
            .RouteTVC => "TVC",
            .RouteMemory => "Memory",
            .RouteLocalLLM => "LocalLLM",
            .RouteGroq => "Groq",
            .RouteClaude => "Claude",
            .RouteFallback => "Fallback",
        };
    }

    pub fn getSourceHue(self: RoutingDecision) f32 {
        return switch (self) {
            .RouteSymbolic => 45.0,
            .RouteTVC => 180.0,
            .RouteMemory => 270.0,
            .RouteLocalLLM => 120.0,
            .RouteGroq => 30.0,
            .RouteClaude => 200.0,
            .RouteFallback => 0.0,
        };
    }
};

pub const WaveState = struct {
    similarity: f32 = 0.0,
    source_hue: f32 = 0.0,
    confidence: f32 = 0.0,
    latency_normalized: f32 = 0.0,
    memory_load: f32 = 0.0,
    is_learning: bool = false,
    routing: RoutingDecision = .RouteSymbolic,
    provider_health_avg: f32 = 1.0,
};

pub var g_last_wave_state: WaveState = WaveState{};

pub const HybridResponse = struct {
    response: []const u8 = "WASM mode",
    source: Source = .Symbolic,
    language: local_chat.Language = .English,
    confidence: f32 = 0.5,
    latency_us: u64 = 100,
    tvc_similarity: f64 = 0.0,
    tool_name: ?[]const u8 = null,
    reflection: ReflectionStatus = .NotApplicable,

    pub const Source = enum {
        Symbolic, TVCCorpus, Tool, Vision, LocalLLM, GroqAPI, ClaudeAPI, Error,
    };

    pub fn format(_: HybridResponse) []const u8 {
        return "WASM";
    }

    pub fn isCached(_: HybridResponse) bool {
        return false;
    }
};

pub const ProviderHealth = struct {
    total_calls: u32 = 0,
    successful_calls: u32 = 0,
    failed_calls: u32 = 0,

    pub fn getSuccessRate(self: ProviderHealth) f32 {
        if (self.total_calls == 0) return 1.0;
        return @as(f32, @floatFromInt(self.successful_calls)) / @as(f32, @floatFromInt(self.total_calls));
    }
};

pub const EnergyMetrics = struct {
    total_joules: f64 = 0,
    query_count: u64 = 0,
};

pub const HybridConfig = struct {
    symbolic_confidence_threshold: f32 = 0.3,
    max_tokens: u32 = 32,
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,
    use_ternary: bool = false,
    system_prompt: []const u8 = "Be concise.",
    tvc_similarity_threshold: f64 = 0.55,
    tvc_corpus_path: ?[]const u8 = null,
    tvc_autosave_interval: u32 = 5,
    groq_api_key: ?[]const u8 = null,
    groq_model: []const u8 = "llama-3.3-70b-versatile",
    claude_api_key: ?[]const u8 = null,
    claude_model: []const u8 = "claude-3-5-sonnet-20241022",
    enable_reflection: bool = true,
    enable_energy_metrics: bool = true,
    openai_api_key: ?[]const u8 = null,
    whisper_model: []const u8 = "whisper-1",
    enable_tools: bool = false,
    enable_context: bool = true,
    max_context_prompt_length: usize = 2048,
    min_response_length: usize = 10,
    min_save_confidence: f32 = 0.7,
    max_save_similarity: f64 = 0.85,
};

pub const IglaHybridChat = struct {
    allocator: std.mem.Allocator,
    config: HybridConfig,
    symbolic: local_chat.IglaLocalChat = local_chat.IglaLocalChat.init(),
    model: ?*anyopaque = null,
    tokenizer: ?*anyopaque = null,
    model_path: ?[]const u8 = null,
    llm_loaded: bool = false,
    corpus: ?*tvc.TVCCorpus = null,
    tvc_stores_since_save: u32 = 0,
    total_queries: usize = 0,
    symbolic_hits: usize = 0,
    llm_calls: usize = 0,
    energy: EnergyMetrics = EnergyMetrics{},
    groq_health: ProviderHealth = ProviderHealth{},
    claude_health: ProviderHealth = ProviderHealth{},
    last_routing: RoutingDecision = .RouteSymbolic,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, _: ?[]const u8) !Self {
        return Self{
            .allocator = allocator,
            .config = HybridConfig{},
        };
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, _: ?[]const u8, config: HybridConfig) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn initWithCorpus(allocator: std.mem.Allocator, _: ?[]const u8, corpus: *tvc.TVCCorpus) !Self {
        var s = Self{
            .allocator = allocator,
            .config = HybridConfig{},
        };
        s.corpus = corpus;
        return s;
    }

    pub fn deinit(_: *Self) void {}

    pub fn respond(self: *Self, _: []const u8) !HybridResponse {
        self.total_queries += 1;
        self.symbolic_hits += 1;
        g_last_wave_state = WaveState{
            .similarity = 0.5,
            .source_hue = 45.0,
            .confidence = 0.5,
            .routing = .RouteSymbolic,
            .provider_health_avg = 1.0,
        };
        return HybridResponse{
            .response = "WASM mode — Trinity Canvas running in browser via WebGL.",
            .source = .Symbolic,
            .confidence = 0.5,
            .latency_us = 100,
            .reflection = .Disabled,
        };
    }
};
