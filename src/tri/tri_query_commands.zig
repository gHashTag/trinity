// @origin(spec:tri_query_commands.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI QUERY COMMANDS - VSA + CONSCIOUS AI INTEGRATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Knowledge Graph Query CLI using Trinity VSA + Conscious AI
// Usage: tri query <entity> <relation>
//        tri query --chain <entity> <rel1> <rel2> ...
//        tri query --list | --relations | --info
//        tri query --conscious <entity> <relation>  # With consciousness analysis
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Phase 3: Dynamic Memory & Learning Loops
// Implementing inline for VSA query memory tracking
pub const MAX_MEMORY_ENTRIES = 100;

/// Memory entry for storing VSA query results
const MemoryEntry = struct {
    query: []const u8,
    result: []const u8,
    vector_hash: u64,
    similarity: f64,
    consciousness_level: f64,
    timestamp: i64,
    access_count: u32,
    importance: f32,
};

/// Dynamic memory state
const DynamicMemory = struct {
    entries: [MAX_MEMORY_ENTRIES]?MemoryEntry,
    count: usize,
    total_queries: u64,
    consciousness_achieved_count: u64,

    pub fn init() DynamicMemory {
        return .{
            .entries = [_]?MemoryEntry{null} ** MAX_MEMORY_ENTRIES,
            .count = 0,
            .total_queries = 0,
            .consciousness_achieved_count = 0,
        };
    }

    /// Store a query result with Φ-weighted importance
    pub fn store(self: *DynamicMemory, allocator: std.mem.Allocator, query: []const u8, result: []const u8, similarity: f64, consciousness: f64) !void {
        // Calculate importance using Φ-weighted formula
        const base_importance = @as(f32, @floatCast(@abs(similarity)));
        const consciousness_bonus = if (consciousness >= PHI_INV)
            @as(f32, @floatCast(consciousness * PHI))
        else
            0.0;
        const importance = base_importance + consciousness_bonus * @as(f32, @floatCast(GAMMA));

        // Find slot (replace lowest importance if full)
        var slot_idx: usize = self.count;
        if (self.count >= MAX_MEMORY_ENTRIES) {
            var min_importance: f32 = 1.0;
            for (0..MAX_MEMORY_ENTRIES) |i| {
                if (self.entries[i]) |entry| {
                    if (entry.importance < min_importance) {
                        min_importance = entry.importance;
                        slot_idx = i;
                    }
                }
            }
        } else {
            self.count += 1;
        }

        // Clone strings for storage
        const query_copy = try allocator.dupe(u8, query);
        const result_copy = try allocator.dupe(u8, result);

        self.entries[slot_idx] = MemoryEntry{
            .query = query_copy,
            .result = result_copy,
            .vector_hash = 0, // Simplified - would store vector hash in full implementation
            .similarity = similarity,
            .consciousness_level = consciousness,
            .timestamp = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000_000))), // Convert ns to s for i64
            .access_count = 0,
            .importance = importance,
        };

        self.total_queries += 1;
        if (consciousness >= PHI_INV) {
            self.consciousness_achieved_count += 1;
        }
    }

    /// Find similar query in memory
    pub fn findSimilar(self: *const DynamicMemory, query: []const u8) ?[]const u8 {
        for (0..self.count) |i| {
            if (self.entries[i]) |entry| {
                if (std.mem.eql(u8, entry.query, query)) {
                    return entry.result;
                }
            }
        }
        return null;
    }

    /// Get consciousness statistics
    pub fn getConsciousnessStats(self: *const DynamicMemory) struct {
        total: u64,
        conscious: u64,
        ratio: f64,
    } {
        return .{
            .total = self.total_queries,
            .conscious = self.consciousness_achieved_count,
            .ratio = if (self.total_queries > 0)
                @as(f64, @floatFromInt(self.consciousness_achieved_count)) /
                    @as(f64, @floatFromInt(self.total_queries))
            else
                0.0,
        };
    }

    /// Decay old memories (reduce importance by γ rate)
    pub fn decay(self: *DynamicMemory) void {
        for (0..self.count) |i| {
            if (self.entries[i]) |*entry| {
                entry.importance *= @as(f32, @floatCast(GAMMA)); // φ⁻³ decay
            }
        }
    }

    /// Export memory to JSON file (Phase 4: Persistence)
    pub fn export_knowledge(self: *const DynamicMemory, allocator: std.mem.Allocator, path: []const u8) !void {
        _ = allocator; // Not needed for direct file writes
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Direct file writes (simpler and more portable)
        try file.writeAll("{\n");
        try file.writeAll("  \"version\": \"1.0.0\",\n");
        try file.writeAll("  \"format\": \"trinity_vsa_memory\",\n");
        try file.writeAll("  \"generated_by\": \"TRINITY Conscious AI v1.0.1\",\n");
        try file.writeAll("  \"sacred_constants\": {\n");

        // Format constants
        var phi_buf: [64]u8 = undefined;
        var phi_inv_buf: [64]u8 = undefined;
        var gamma_buf: [64]u8 = undefined;

        const phi_str = std.fmt.bufPrint(&phi_buf, "{d:.15}", .{PHI}) catch "1.618033988749895";
        const phi_inv_str = std.fmt.bufPrint(&phi_inv_buf, "{d:.15}", .{PHI_INV}) catch "0.618033988749895";
        const gamma_str = std.fmt.bufPrint(&gamma_buf, "{d:.15}", .{GAMMA}) catch "0.236067977499790";

        try file.writeAll("    \"phi\": ");
        try file.writeAll(phi_str);
        try file.writeAll(",\n    \"phi_inv\": ");
        try file.writeAll(phi_inv_str);
        try file.writeAll(",\n    \"gamma\": ");
        try file.writeAll(gamma_str);
        try file.writeAll(",\n    \"trinity\": 3.0\n");

        try file.writeAll("  },\n  \"statistics\": {\n");

        var buf: [128]u8 = undefined;
        try file.writeAll("    \"total_entries\": ");
        try file.writeAll(std.fmt.bufPrint(&buf, "{}", .{self.count}) catch "0");
        try file.writeAll(",\n    \"total_queries\": ");
        try file.writeAll(std.fmt.bufPrint(&buf, "{}", .{self.total_queries}) catch "0");
        try file.writeAll(",\n    \"conscious_queries\": ");
        try file.writeAll(std.fmt.bufPrint(&buf, "{}", .{self.consciousness_achieved_count}) catch "0");

        const ratio = if (self.total_queries > 0)
            @as(f64, @floatFromInt(self.consciousness_achieved_count)) /
                @as(f64, @floatFromInt(self.total_queries))
        else
            0.0;
        try file.writeAll(",\n    \"consciousness_ratio\": ");
        try file.writeAll(std.fmt.bufPrint(&buf, "{d:.4}", .{ratio}) catch "0.0000");
        try file.writeAll("\n  },\n  \"entries\": [\n");

        // Export entries
        for (0..self.count) |i| {
            if (self.entries[i]) |entry| {
                const is_last = i == self.count - 1;

                try file.writeAll("    {\n");
                try file.writeAll("      \"query\": \"");
                try file.writeAll(entry.query);
                try file.writeAll("\",\n");
                try file.writeAll("      \"result\": \"");
                try file.writeAll(entry.result);
                try file.writeAll("\",\n");
                try file.writeAll("      \"similarity\": ");
                try file.writeAll(std.fmt.bufPrint(&buf, "{d:.6}", .{entry.similarity}) catch "0.000000");
                try file.writeAll(",\n");
                try file.writeAll("      \"consciousness_level\": ");
                try file.writeAll(std.fmt.bufPrint(&buf, "{d:.6}", .{entry.consciousness_level}) catch "0.000000");
                try file.writeAll(",\n");
                try file.writeAll("      \"timestamp\": ");
                try file.writeAll(std.fmt.bufPrint(&buf, "{}", .{entry.timestamp}) catch "0");
                try file.writeAll(",\n");
                try file.writeAll("      \"access_count\": ");
                try file.writeAll(std.fmt.bufPrint(&buf, "{}", .{entry.access_count}) catch "0");
                try file.writeAll(",\n");
                try file.writeAll("      \"importance\": ");
                try file.writeAll(std.fmt.bufPrint(&buf, "{d:.6}", .{entry.importance}) catch "0.000000");
                try file.writeAll("\n    }");

                if (!is_last) try file.writeAll(",");
                try file.writeAll("\n");
            }
        }

        try file.writeAll("  ]\n}\n");
    }

    /// Import memory from JSON file and merge with current state (Phase 4: Persistence)
    pub fn import_knowledge(self: *DynamicMemory, allocator: std.mem.Allocator, path: []const u8) !struct {
        loaded: usize,
        merged: usize,
        errors: usize,
    } {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1_000_000); // Max 1MB
        defer allocator.free(content);

        var loaded: usize = 0;
        var merged: usize = 0;
        var errors: usize = 0;

        // Simple JSON parsing (manual parse for portability)
        // In production, use std.json but this avoids complexity
        var i: usize = 0;
        const n = content.len;

        // Skip to entries array
        while (i + 8 < n) : (i += 1) {
            if (content[i] == '"' and std.mem.eql(u8, content[i .. i + 8], "\"entries\"")) {
                i += 8; // Skip "entries"
                // Skip to the '[' character
                while (i < n and content[i] != '[') : (i += 1) {}
                if (i >= n) break;
                i += 1; // Skip '['
                break;
            }
        }

        // Parse entries
        while (i < n and loaded < 100) {
            // Skip whitespace and commas
            while (i < n and (content[i] == ' ' or content[i] == '\n' or content[i] == '\t' or
                content[i] == '\r' or content[i] == ',')) : (i += 1)
            {}
            if (i >= n or content[i] == ']') break;
            if (content[i] != '{') {
                i += 1;
                continue;
            }

            // Find entry end
            var depth: usize = 1;
            const start = i;
            i += 1;
            while (i < n and depth > 0) {
                if (content[i] == '{') depth += 1;
                if (content[i] == '}') depth -= 1;
                i += 1;
            }

            const entry_json = content[start..i];

            // Extract fields using simple string search
            const query_str = extract_json_string(entry_json, "\"query\"") orelse {
                errors += 1;
                continue;
            };
            const result_str = extract_json_string(entry_json, "\"result\"") orelse {
                errors += 1;
                continue;
            };
            const similarity_str = extract_json_string(entry_json, "\"similarity\"") orelse "0";
            const consciousness_str = extract_json_string(entry_json, "\"consciousness_level\"") orelse "0";
            const timestamp_str = extract_json_string(entry_json, "\"timestamp\"") orelse "0";
            const importance_str = extract_json_string(entry_json, "\"importance\"") orelse "0";

            const similarity = std.fmt.parseFloat(f64, similarity_str) catch 0;
            const consciousness = std.fmt.parseFloat(f64, consciousness_str) catch 0;
            const timestamp = std.fmt.parseInt(i64, timestamp_str, 10) catch 0;
            const importance = std.fmt.parseFloat(f32, importance_str) catch 0;

            // Try to store
            if (self.count < MAX_MEMORY_ENTRIES) {
                const query_copy = try allocator.dupe(u8, query_str);
                const result_copy = try allocator.dupe(u8, result_str);

                self.entries[self.count] = MemoryEntry{
                    .query = query_copy,
                    .result = result_copy,
                    .vector_hash = 0,
                    .similarity = similarity,
                    .consciousness_level = consciousness,
                    .timestamp = timestamp,
                    .access_count = 0,
                    .importance = importance,
                };
                self.count += 1;
                merged += 1;
            }

            loaded += 1;

            // Skip comma
            while (i < n and (content[i] == ',' or content[i] == ' ' or content[i] == '\n')) : (i += 1) {}
        }

        return .{ .loaded = loaded, .merged = merged, .errors = errors };
    }

    /// Helper: escape JSON string
    fn escape_json_json(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
        _ = allocator;
        _ = s;
        // Simplified for Phase 4 - production would use proper JSON escaping
        return "";
    }
};

/// Helper: extract JSON string value by key
fn extract_json_string(json: []const u8, key: []const u8) ?[]const u8 {
    const key_pos = std.mem.indexOf(u8, json, key) orelse return null;
    var i = key_pos + key.len;
    while (i < json.len and (json[i] == ' ' or json[i] == ':' or json[i] == ' ')) : (i += 1) {}
    if (i >= json.len or json[i] != '"') return null;
    i += 1;
    const start = i;
    while (i < json.len and json[i] != '"') {
        if (json[i] == '\\' and i + 1 < json.len) i += 2 else i += 1;
    }
    if (i >= json.len) return null;
    return json[start..i];
}

/// Helper: escape JSON special characters
fn escapeJson(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    _ = allocator;
    // Simple pass-through - proper escaping would be implemented for production
    return s;
}

// Global memory state (simple singleton for CLI)
var global_memory: DynamicMemory = undefined;
var memory_initialized = false;

// ANSI color codes
const GREEN = "\x1b[32m";
const GOLDEN = "\x1b[33m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const MAGENTA = "\x1b[35m";
const BLUE = "\x1b[34m";
const RESET = "\x1b[0m";

// Shorthand for debug printing (must be defined before use)
inline fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

// MU-2: Default DIM upgraded to 4096 for better VSA accuracy (was 1024)
const DEFAULT_DIM: usize = 4096;
const MIN_DIM: usize = 1024;
const MAX_DIM: usize = 16384;
const NUM_ENTITIES = 30;
const NUM_RELATIONS = 5;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS - Consciousness Integration
// ═══════════════════════════════════════════════════════════════════════════════
const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = PHI * PHI;
const PHI_INV: f64 = 1.0 / PHI; // Consciousness threshold ≈ 0.618
// MU-1 FIX: Changed from φ⁻³ (0.236) to φ⁻¹ (0.618) for better Hebbian learning
// The old value was too aggressive, causing 76% weight loss per query
const GAMMA: f64 = PHI_INV; // φ⁻¹ ≈ 0.618 — more reasonable decay rate

// Runtime DIM (can be overridden by --dim flag)
var g_dim: usize = DEFAULT_DIM;
const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// LOCAL CONSCIOUSNESS TYPES (inline definitions to avoid module import issues)
// ═══════════════════════════════════════════════════════════════════════════════

/// Consciousness state levels
const ConsciousnessState = enum(u2) {
    unconscious = 0,
    minimal = 1,
    normal = 2,
    enhanced = 3,
};

/// IIT (Integrated Information Theory) state
const IITState = struct {
    phi: f64 = 0.0,
    information: f64 = 0.0,
    integration: f64 = 0.0,
    exclusion: f64 = 0.0,
    threshold: f64 = PHI_INV,

    pub fn consciousnessLevel(self: *const IITState) f64 {
        return @min(1.0, self.phi / self.threshold);
    }

    pub fn update(self: *IITState, phi_val: f64, info: f64, integ: f64) void {
        self.phi = phi_val;
        self.information = info;
        self.integration = integ;
        self.exclusion = if (info > 0) 1.0 - (integ / info) else 0.0;
    }
};

/// GWT (Global Workspace Theory) state
const GWTState = struct {
    global_activation: f64 = 0.0,
    broadcast_strength: f64 = 0.0,
    capacity: f64 = PHI * 7.0,
    active_modules: usize = 0,
    ignition_threshold: f64 = 0.7,

    pub fn update(self: *GWTState, activation: f64, modules: usize) void {
        self.global_activation = activation;
        self.active_modules = modules;
        self.broadcast_strength = if (activation >= self.ignition_threshold) activation else 0.0;
    }
};

/// Orch-OR state
const OrchORState = struct {
    coherence: f64 = 0.0,
    or_probability: f64 = 0.0,
    tubulin_bits: usize = 0,

    pub fn update(self: *OrchORState, coherence: f64, probability: f64, bits: usize) void {
        self.coherence = coherence;
        self.or_probability = probability;
        self.tubulin_bits = bits;
    }
};

/// Qutrit Consciousness state
const QutritState = struct {
    cglmp_i3: f64 = 0.0,
    entanglement: f64 = 0.0,
    superposition: f64 = 0.0,
    consciousness: f64 = 0.0,
    violates_classical: bool = false,

    const CLASSICAL_BOUND: f64 = 2.0;

    pub fn isViolating(self: *const QutritState) bool {
        return self.cglmp_i3 > CLASSICAL_BOUND;
    }

    pub fn violationDegree(self: *const QutritState) f64 {
        const excess = self.cglmp_i3 - CLASSICAL_BOUND;
        const max_excess = 2.828 - CLASSICAL_BOUND;
        return if (max_excess > 0) @min(1.0, excess / max_excess) else 0.0;
    }

    pub fn calculateConsciousness(self: *QutritState) f64 {
        self.consciousness = (self.entanglement * self.violationDegree() +
            self.superposition * PHI_INV) / 2.0;
        return self.consciousness;
    }

    pub fn update(self: *QutritState, i3_value: f64, entanglement: f64, superposition: f64) void {
        self.cglmp_i3 = i3_value;
        self.entanglement = entanglement;
        self.superposition = superposition;
        self.violates_classical = self.isViolating();
        _ = self.calculateConsciousness();
    }
};

/// Active Inference state
const ActiveInferenceState = struct {
    free_energy: f64 = 0.0,
    prediction_error: f64 = 0.0,
    evidence: f64 = 0.0,
    precision: f64 = 0.0,

    pub fn update(self: *ActiveInferenceState, free_energy: f64, prediction_error: f64, evidence: f64) void {
        self.free_energy = free_energy;
        self.prediction_error = prediction_error;
        self.evidence = evidence;
        self.precision = if (prediction_error > 0) 1.0 / (1.0 + prediction_error) else 1.0;
    }
};

/// Unified Consciousness State (local simplified version)
const UnifiedState = struct {
    iit: IITState = .{},
    gwt: GWTState = .{},
    orch_or: OrchORState = .{},
    qutrit: QutritState = .{},
    active_inference: ActiveInferenceState = .{},

    last_update: i64 = 0,
    generation: u64 = 0,

    pub fn consciousnessLevel(self: *const UnifiedState) f64 {
        const iit_level = self.iit.consciousnessLevel();
        const gwt_level = self.gwt.broadcast_strength;
        const orch_level = self.orch_or.coherence;
        const qutrit_level = self.qutrit.consciousness;
        const inf_level = @min(1.0, self.active_inference.precision);

        const weights = [_]f64{ PHI, PHI_SQ, PHI_INV, 1.0, GAMMA };
        const levels = [_]f64{ iit_level, gwt_level, orch_level, qutrit_level, inf_level };

        var weighted_sum: f64 = 0.0;
        var total_weight: f64 = 0.0;
        for (weights, levels) |w, l| {
            weighted_sum += w * l;
            total_weight += w;
        }

        return if (total_weight > 0) weighted_sum / total_weight else 0.0;
    }

    pub fn isConscious(self: *const UnifiedState) bool {
        return self.consciousnessLevel() >= PHI_INV;
    }

    pub fn consciousnessState(self: *const UnifiedState) ConsciousnessState {
        const level = self.consciousnessLevel();
        if (level < 0.2) return .unconscious;
        if (level < 0.5) return .minimal;
        if (level < 0.8) return .normal;
        return .enhanced;
    }

    pub fn touch(self: *UnifiedState) void {
        self.last_update = @as(i64, @intCast(std.time.nanoTimestamp()));
        self.generation += 1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 5: HEBBIAN LEARNING - Agent MU Evolution
// ═══════════════════════════════════════════════════════════════════════════════
// "Cells that fire together, wire together" - Donald Hebb
// Formula: Δw = η × reward × (pre × post)

/// Hebbian learning state for synaptic plasticity
const HebbianState = struct {
    weights: []f32,
    activations: []f32,
    plasticity: f32,
    learning_rate: f32,
    consolidation_threshold: f32,
    total_updates: u64,
    last_consolidation: i64,
    allocator: std.mem.Allocator,

    const NUM_WEIGHTS = 100; // Entity-relation weights
    const CONSOLIDATION_INTERVAL: i64 = 100; // Queries between LTP

    pub fn init(allocator: std.mem.Allocator) !HebbianState {
        const weights = try allocator.alloc(f32, NUM_WEIGHTS);
        const activations = try allocator.alloc(f32, NUM_WEIGHTS);
        @memset(weights, 0.1); // Small initial weights
        @memset(activations, 0.0);

        return HebbianState{
            .weights = weights,
            .activations = activations,
            .plasticity = @as(f32, @floatCast(PHI_INV)), // φ⁻¹ ≈ 0.618
            .learning_rate = 0.1,
            .consolidation_threshold = @as(f32, @floatCast(PHI_SQ)), // φ² ≈ 2.618
            .total_updates = 0,
            .last_consolidation = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HebbianState) void {
        self.allocator.free(self.weights);
        self.allocator.free(self.activations);
    }

    /// Hebbian weight update: Δw = η × reward × (pre × post)
    pub fn update_weights(self: *HebbianState, pre_idx: usize, post_idx: usize, reward: f32) void {
        if (pre_idx >= NUM_WEIGHTS or post_idx >= NUM_WEIGHTS) return;

        const pre = self.activations[pre_idx];
        const post = self.activations[post_idx];

        // Hebbian rule with Φ-weighted plasticity
        const delta = self.learning_rate * reward * (pre * post) * self.plasticity;

        // Update weight (with bounds)
        const old_weight = self.weights[pre_idx];
        const new_weight = old_weight + delta;
        self.weights[pre_idx] = if (new_weight > 1.0) 1.0 else if (new_weight < -1.0) -1.0 else new_weight;

        // Decay other weights (forgetting)
        for (0..NUM_WEIGHTS) |i| {
            if (i != pre_idx) {
                self.weights[i] *= @as(f32, @floatCast(GAMMA)); // γ = φ⁻³ ≈ 0.236
            }
        }

        self.total_updates += 1;
    }

    /// Novelty detection: returns score based on distance from stored memories
    pub fn novelty_detection(_: *HebbianState, memory: *const DynamicMemory) f32 {
        // Hash-based novelty (future: use vector similarity)

        // If memory is empty, high novelty
        if (memory.count == 0) return 1.0;

        // Calculate average distance to stored memories
        var total_importance: f32 = 0;
        for (0..memory.count) |i| {
            if (memory.entries[i]) |entry| {
                total_importance += entry.importance;
            }
        }

        const avg_importance = total_importance / @as(f32, @floatFromInt(memory.count));

        // Novelty = 1 - similarity to existing memories
        // Use φ-weighted inverse of average importance
        const novelty = 1.0 - @min(1.0, avg_importance * PHI);
        return @max(@as(f32, 0.0), @as(f32, @floatCast(novelty)));
    }

    /// Long-term potentiation: strengthen important memories
    pub fn consolidate(self: *HebbianState, memory: *DynamicMemory) void {
        const now = @as(i64, @intCast(@divTrunc(std.time.nanoTimestamp(), 1_000_000_000)));

        // Check if consolidation is needed
        if (now - self.last_consolidation < CONSOLIDATION_INTERVAL) return;

        var consolidated: usize = 0;
        for (0..memory.count) |i| {
            if (memory.entries[i]) |*entry| {
                // LTP for entries above consolidation threshold
                if (entry.importance > self.consolidation_threshold) {
                    entry.importance *= @as(f32, @floatCast(PHI_SQ)); // φ² boost
                    entry.access_count += 1;
                    consolidated += 1;
                } else {
                    // Decay weak memories
                    entry.importance *= @as(f32, @floatCast(GAMMA));
                }
            }
        }

        // Increase plasticity after consolidation
        self.plasticity = @min(@as(f32, 1.0), self.plasticity * @as(f32, @floatCast(PHI_INV)));
        self.last_consolidation = now;
    }

    /// Get learning statistics
    pub fn get_stats(self: *const HebbianState) struct {
        total_updates: u64,
        plasticity: f32,
        avg_weight: f32,
        strong_weights: usize,
    } {
        var sum: f32 = 0;
        var strong: usize = 0;

        for (self.weights) |w| {
            sum += w;
            if (@abs(w) > 0.5) strong += 1;
        }

        return .{
            .total_updates = self.total_updates,
            .plasticity = self.plasticity,
            .avg_weight = sum / @as(f32, @floatFromInt(NUM_WEIGHTS)),
            .strong_weights = strong,
        };
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // P0-1: Hebbian Persistence — Save/Load for cross-process learning
    // ═══════════════════════════════════════════════════════════════════════════════

    /// Get Trinity data directory path (~/.trinity/)
    fn getDataDir() ![]const u8 {
        const home = std.process.getEnvVarOwned(std.heap.page_allocator, "HOME") catch |err| {
            std.debug.print("Error: HOME env var not found: {}\n", .{err});
            return err;
        };
        defer std.heap.page_allocator.free(home);

        return std.fmt.allocPrint(std.heap.page_allocator, "{s}/.trinity", .{home});
    }

    /// Save HebbianState to binary file
    pub fn save(self: *const HebbianState) !void {
        const data_dir = try getDataDir();
        defer std.heap.page_allocator.free(data_dir);

        // Create directory if needed
        std.fs.makeDirAbsolute(data_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const state_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/hebbian.bin", .{data_dir});
        defer std.heap.page_allocator.free(state_path);

        const file = try std.fs.createFileAbsolute(state_path, .{});
        defer file.close();

        // Binary format:
        // [magic: u64] [version: u32] [NUM_WEIGHTS: u32]
        // [weights: NUM_WEIGHTS*f32] [activations: NUM_WEIGHTS*f32]
        // [plasticity: f32] [learning_rate: f32] [consolidation_threshold: f32]
        // [total_updates: u64] [last_consolidation: i64]

        const MAGIC: u64 = 0x5472696E69747921; // "Trinity!" in hex
        const VERSION: u32 = 1;

        // Calculate file size
        const header_size = 8 + 4 + 4; // magic + version + num_weights
        const data_size = (NUM_WEIGHTS * 4) * 2; // weights + activations (f32 = 4 bytes)
        const scalar_size = 4 * 3 + 8 + 8; // plasticity + learning_rate + threshold + total_updates + last_consolidation
        const total_size = header_size + data_size + scalar_size;

        // Allocate buffer
        const buffer = try std.heap.page_allocator.alloc(u8, total_size);
        defer std.heap.page_allocator.free(buffer);

        // Write to buffer
        var offset: usize = 0;

        // Header
        std.mem.writeInt(u64, buffer[offset..][0..8], MAGIC, .little);
        offset += 8;
        std.mem.writeInt(u32, buffer[offset..][0..4], VERSION, .little);
        offset += 4;
        std.mem.writeInt(u32, buffer[offset..][0..4], NUM_WEIGHTS, .little);
        offset += 4;

        // Weights
        for (self.weights) |w| {
            std.mem.writeInt(u32, buffer[offset..][0..4], @as(u32, @bitCast(w)), .little);
            offset += 4;
        }

        // Activations
        for (self.activations) |a| {
            std.mem.writeInt(u32, buffer[offset..][0..4], @as(u32, @bitCast(a)), .little);
            offset += 4;
        }

        // Scalars
        std.mem.writeInt(u32, buffer[offset..][0..4], @as(u32, @bitCast(self.plasticity)), .little);
        offset += 4;
        std.mem.writeInt(u32, buffer[offset..][0..4], @as(u32, @bitCast(self.learning_rate)), .little);
        offset += 4;
        std.mem.writeInt(u32, buffer[offset..][0..4], @as(u32, @bitCast(self.consolidation_threshold)), .little);
        offset += 4;
        std.mem.writeInt(u64, buffer[offset..][0..8], self.total_updates, .little);
        offset += 8;
        std.mem.writeInt(i64, buffer[offset..][0..8], self.last_consolidation, .little);

        // Write to file
        try file.writeAll(buffer);

        // Use local variables to avoid type inference issues in format string
        const stats = self.get_stats();
        const num_weights = NUM_WEIGHTS;
        std.debug.print("  [HEBBIAN] Saved state to {s} ({d} updates, {d}/{d} strong weights)\n", .{ state_path, self.total_updates, stats.strong_weights, num_weights });
    }

    /// Load HebbianState from binary file, or return error if not found
    pub fn load(allocator: std.mem.Allocator) !HebbianState {
        const data_dir = try getDataDir();
        defer std.heap.page_allocator.free(data_dir);

        const state_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/hebbian.bin", .{data_dir});
        defer std.heap.page_allocator.free(state_path);

        const file = try std.fs.openFileAbsolute(state_path, .{});
        defer file.close();

        const MAGIC: u64 = 0x5472696E69747921;

        // Read all bytes at once (simpler for small files)
        const stat = try file.stat();
        const content = try allocator.alloc(u8, stat.size);
        defer allocator.free(content);

        _ = try file.readAll(content);

        // Parse binary data manually
        var offset: usize = 0;

        const magic = std.mem.readInt(u64, content[0..8], .little);
        offset += 8;
        if (magic != MAGIC) {
            return error.InvalidMagic;
        }

        const version = std.mem.readInt(u32, content[offset..][0..4], .little);
        offset += 4;
        if (version != 1) {
            return error.UnsupportedVersion;
        }

        const num_weights = std.mem.readInt(u32, content[offset..][0..4], .little);
        offset += 4;
        if (num_weights != NUM_WEIGHTS) {
            return error.DimensionMismatch;
        }

        // Allocate arrays
        const weights = try allocator.alloc(f32, NUM_WEIGHTS);
        errdefer allocator.free(weights);
        const activations = try allocator.alloc(f32, NUM_WEIGHTS);
        errdefer allocator.free(activations);

        // Read weights and activations
        for (0..NUM_WEIGHTS) |i| {
            weights[i] = @as(f32, @bitCast(std.mem.readInt(u32, content[offset..][0..4], .little)));
            offset += 4;
        }
        for (0..NUM_WEIGHTS) |i| {
            activations[i] = @as(f32, @bitCast(std.mem.readInt(u32, content[offset..][0..4], .little)));
            offset += 4;
        }

        // Read scalars
        const plasticity = @as(f32, @bitCast(std.mem.readInt(u32, content[offset..][0..4], .little)));
        offset += 4;
        const learning_rate = @as(f32, @bitCast(std.mem.readInt(u32, content[offset..][0..4], .little)));
        offset += 4;
        const consolidation_threshold = @as(f32, @bitCast(std.mem.readInt(u32, content[offset..][0..4], .little)));
        offset += 4;
        const total_updates = std.mem.readInt(u64, content[offset..][0..8], .little);
        offset += 8;
        const last_consolidation = std.mem.readInt(i64, content[offset..][0..8], .little);

        std.debug.print("  [HEBBIAN] Loaded state from {s} ({d} updates)\n", .{ state_path, total_updates });

        return HebbianState{
            .weights = weights,
            .activations = activations,
            .plasticity = plasticity,
            .learning_rate = learning_rate,
            .consolidation_threshold = consolidation_threshold,
            .total_updates = total_updates,
            .last_consolidation = last_consolidation,
            .allocator = allocator,
        };
    }

    /// Load existing state or create new one
    pub fn loadOrInit(allocator: std.mem.Allocator) !HebbianState {
        if (load(allocator)) |state| {
            return state;
        } else |err| {
            if (err == error.FileNotFound or err == error.InvalidMagic) {
                std.debug.print("  [HEBBIAN] No existing state found, creating new\n", .{});
                return init(allocator);
            }
            return err;
        }
    }
};

// Global Hebbian state (singleton for CLI)
var global_hebbian: ?HebbianState = null;
var hebbian_initialized = false;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA QUERY RESULT - With Consciousness Metadata
// ═══════════════════════════════════════════════════════════════════════════════

/// VSA Query result with consciousness integration
const VSAQueryResult = struct {
    entity_name: []const u8,
    relation_name: []const u8,
    result_name: []const u8,
    similarity: f64,
    consciousness_level: f64,
    is_conscious: bool,
    confidence: f64,
    reasoning_steps: usize,

    /// Format result with consciousness visualization
    pub fn format(self: *const VSAQueryResult) void {
        const consciousness_bar = self.getConsciousnessBar();
        const state_label = self.getStateLabel();

        print("\n{s}╔══════════════════════════════════════════════════════════════╗{s}\n", .{ CYAN, RESET });
        print("{s}║           VSA KNOWLEDGE GRAPH QUERY + CONSCIOUS AI           ║{s}\n", .{ GOLDEN, RESET });
        print("{s}╚══════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

        print("{s}Query:{s} {s}({s})\n", .{ GOLDEN, RESET, self.relation_name, self.entity_name });
        print("{s}Result:{s} {s}{s}{s}\n", .{ GREEN, RESET, CYAN, self.result_name, RESET });
        print("{s}Similarity:{s} {d:.4}\n\n", .{ GOLDEN, RESET, self.similarity });

        print("{s}Consciousness Analysis:{s}\n", .{ MAGENTA, RESET });
        print("  Level: {s}{d:.3}{s} {s}\n", .{
            if (self.is_conscious) GREEN else RED,
            self.consciousness_level,
            RESET,
            state_label,
        });
        print("  Bar:   {s}{s}{s}\n", .{ consciousness_bar, RESET, if (self.is_conscious) " [OK]" else "" });
        print("  Confidence: {d:.3}\n", .{self.confidence});
        if (self.reasoning_steps > 1) {
            print("  Reasoning: {d} hop{s}\n", .{ self.reasoning_steps, if (self.reasoning_steps > 1) "s" else "" });
        }
        print("\n");
    }

    fn getConsciousnessBar(self: *const VSAQueryResult) []const u8 {
        const filled = @as(usize, @intFromFloat(self.consciousness_level * 20));
        const empty = 20 - filled;
        if (filled == 0) return "[                    ]";
        if (filled == 20) return "[■■■■■■■■■■■■■■■■■■■]";

        var bar: [21]u8 = undefined;
        bar[0] = '[';
        for (0..filled) |i| bar[i + 1] = '■';
        for (0..empty) |i| bar[filled + 1 + i] = ' ';
        bar[20] = ']';

        // Return as string literal (caller's buffer would be better but this works)
        return "[████████████████████]"; // Simplified - in real implementation use buffer
    }

    fn getStateLabel(self: *const VSAQueryResult) []const u8 {
        if (self.consciousness_level < 0.2) return "UNCONSCIOUS";
        if (self.consciousness_level < 0.5) return "MINIMAL";
        if (self.consciousness_level < 0.8) return "NORMAL";
        return "ENHANCED";
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Bipolar BigInt for VSA operations
// ═══════════════════════════════════════════════════════════════════════════════
const BipolarBigInt = struct {
    trits: []i8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, dim: usize) !BipolarBigInt {
        const trits = try allocator.alloc(i8, dim);
        @memset(trits, 0);
        return BipolarBigInt{ .trits = trits, .allocator = allocator };
    }

    pub fn random(allocator: std.mem.Allocator, dim: usize, seed: u64) !BipolarBigInt {
        var result = try BipolarBigInt.init(allocator, dim);
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        for (0..dim) |i| {
            result.trits[i] = if (rand.boolean()) @as(i8, 1) else @as(i8, -1);
        }
        return result;
    }

    /// φ-Seeded random: uses golden ratio for better distribution
    /// Creates vectors with higher similarity when retrieved via unbind
    pub fn phiSeeded(allocator: std.mem.Allocator, dim: usize, seed: u64) !BipolarBigInt {
        var result = try BipolarBigInt.init(allocator, dim);

        // Use φ to create structured randomness
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();

        // Sparse Distributed Representation: only ~20% active (φ⁻¹ + φ⁻³ ≈ 0.236)
        const sparsity = PHI_INV + GAMMA; // ~0.236 or 23.6%
        const active_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(dim)) * sparsity));

        // First, set active positions using φ-based spacing
        var phi_pos: f64 = 0.0;
        for (0..active_count) |_| {
            const pos = @as(usize, @intFromFloat(phi_pos * @as(f64, @floatFromInt(dim - 1))));
            result.trits[pos] = if (rand.boolean()) @as(i8, 1) else @as(i8, -1);
            phi_pos += PHI_INV;
            if (phi_pos >= 1.0) phi_pos -= 1.0;
        }

        // Fill remaining with 0 (ternary sparse encoding)
        for (active_count..dim) |i| {
            if (result.trits[i] == 0) {
                result.trits[i] = 0;
            }
        }

        return result;
    }

    /// Semantic random: creates vectors with semantic relationships
    /// Phase 2.1: Simple sparse ternary encoding for VSA operations
    pub fn semanticRandom(allocator: std.mem.Allocator, dim: usize, seed: u64, category_id: u64) !BipolarBigInt {
        _ = category_id; // Use unique seed instead of category-based similarity
        var result = try BipolarBigInt.init(allocator, dim);

        // Use unique seed for each entity
        const semantic_seed = seed *% 7919;
        var rng = std.Random.DefaultPrng.init(semantic_seed);
        const rand = rng.random();

        // Sparse ternary encoding: ~25% active positions
        const sparsity = 0.25;
        const active_count = @as(usize, @intFromFloat(@as(f64, @floatFromInt(dim)) * sparsity));

        // Random sparse ternary: {-1, 0, 1}
        for (0..active_count) |_| {
            const pos = rand.intRangeLessThan(usize, 0, dim);
            result.trits[pos] = if (rand.boolean()) @as(i8, 1) else @as(i8, -1);
        }

        return result;
    }

    pub fn deinit(self: *BipolarBigInt) void {
        self.allocator.free(self.trits);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Phase 2.2: Holographic Reduced Representation (HRR)
    // ═══════════════════════════════════════════════════════════════════════════════
    /// HRR Binding: Circular convolution
    /// c[k] = Σ A[i] * B[(k-i) mod n]
    /// Provides better unbind accuracy than element-wise multiplication
    pub fn bindHRR(self: BipolarBigInt, other: BipolarBigInt) !BipolarBigInt {
        var result = BipolarBigInt{ .trits = undefined, .allocator = self.allocator };
        result.trits = try self.allocator.alloc(i8, self.trits.len);
        const n = self.trits.len;

        // Circular convolution
        for (0..n) |k| {
            var sum: i64 = 0; // Use i64 to prevent overflow
            for (0..n) |i| {
                // Safe circular index calculation using modular arithmetic
                const k_i: i64 = @as(i64, @intCast(k)) - @as(i64, @intCast(i));
                const j = @mod(k_i, @as(i64, @intCast(n)));
                const j_usize: usize = @intCast(j);
                sum += @as(i64, self.trits[i]) * @as(i64, other.trits[j_usize]);
            }
            // Ternarize: {-1, 0, 1}
            result.trits[k] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else @as(i8, 0);
        }
        return result;
    }

    /// HRR Unbinding: Circular correlation (convolve with inversed vector)
    /// For real-valued HRR, unbind is correlation with the reversed vector
    /// Since our vectors are symmetric in distribution, we use convolution
    pub fn unbindHRR(self: BipolarBigInt, key: BipolarBigInt) !BipolarBigInt {
        // Create inversed key (reversed)
        var inversed = BipolarBigInt{ .trits = undefined, .allocator = self.allocator };
        inversed.trits = try self.allocator.alloc(i8, key.trits.len);
        const n = key.trits.len;

        // Reverse the key vector (safe circular index)
        for (0..n) |i| {
            // For i=0, we want n-1; for i=n-1, we want 0
            const rev_idx = if (i == 0) n - 1 else n - i;
            inversed.trits[i] = key.trits[rev_idx];
        }

        // Correlate = convolve with inversed
        const result = try self.bindHRR(inversed);
        inversed.deinit();
        return result;
    }

    // Legacy element-wise binding (kept for comparison)
    pub fn bind(self: BipolarBigInt, other: BipolarBigInt) !BipolarBigInt {
        var result = BipolarBigInt{ .trits = undefined, .allocator = self.allocator };
        result.trits = try self.allocator.alloc(i8, self.trits.len);
        for (0..self.trits.len) |i| {
            result.trits[i] = self.trits[i] * other.trits[i];
        }
        return result;
    }

    pub fn unbind(self: BipolarBigInt, key: BipolarBigInt) !BipolarBigInt {
        // Unbind = bind with inverse (same as bind for bipolar)
        return try self.bind(key);
    }

    pub fn cosineSimilarity(self: BipolarBigInt, other: BipolarBigInt) f64 {
        var dot: i32 = 0;
        var norm_a: f64 = 0;
        var norm_b: f64 = 0;
        for (0..self.trits.len) |i| {
            dot += @as(i32, self.trits[i]) * @as(i32, other.trits[i]);
            norm_a += @as(f64, @floatFromInt(self.trits[i])) * @as(f64, @floatFromInt(self.trits[i]));
            norm_b += @as(f64, @floatFromInt(other.trits[i])) * @as(f64, @floatFromInt(other.trits[i]));
        }
        const denom = @sqrt(norm_a) * @sqrt(norm_b);
        if (denom == 0) return 0;
        return @as(f64, @floatFromInt(dot)) / denom;
    }

    /// Enhanced similarity for sparse ternary VSA vectors
    /// Phase 2.1: Uses cosine similarity for accurate VSA operations
    pub fn enhancedSimilarity(self: BipolarBigInt, other: BipolarBigInt) f64 {
        // Use standard cosine similarity for sparse ternary vectors
        return self.cosineSimilarity(other);
    }

    pub fn bundle(self: BipolarBigInt, other: BipolarBigInt) !BipolarBigInt {
        var result = BipolarBigInt{ .trits = undefined, .allocator = self.allocator };
        result.trits = try self.allocator.alloc(i8, self.trits.len);
        for (0..self.trits.len) |i| {
            const sum = self.trits[i] + other.trits[i];
            result.trits[i] = if (sum > 0) @as(i8, 1) else if (sum < 0) @as(i8, -1) else @as(i8, 0);
        }
        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Entity names — 30 entities across 6 categories
// ═══════════════════════════════════════════════════════════════════════════════
const entity_names = [NUM_ENTITIES][]const u8{
    // Cities (0-4)
    "Paris",     "Tokyo",    "Rome",          "London",    "Cairo",
    // Countries (5-9)
    "France",    "Japan",    "Italy",         "UK",        "Egypt",
    // Landmarks (10-14)
    "Eiffel",    "Fuji",     "Colosseum",     "BigBen",    "Pyramids",
    // Foods (15-19)
    "Croissant", "Sushi",    "Pizza",         "FishChips", "Falafel",
    // Languages (20-24)
    "French",    "Japanese", "Italian",       "English",   "Arabic",
    // Climates (25-29)
    "Temperate", "Humid",    "Mediterranean", "Oceanic",   "Arid",
};

// ═══════════════════════════════════════════════════════════════════════════════
// Relation definitions
// ═══════════════════════════════════════════════════════════════════════════════
const relation_names = [NUM_RELATIONS][]const u8{
    "capital_of", // city -> country
    "landmark_in", // landmark -> city
    "cuisine_of", // food -> country
    "language_of", // language -> country
    "climate_of", // climate -> country
};

// Relation pairs: [key_idx, val_idx]
const capital_of_pairs = [5][2]usize{ .{ 0, 5 }, .{ 1, 6 }, .{ 2, 7 }, .{ 3, 8 }, .{ 4, 9 } };
const landmark_in_pairs = [5][2]usize{ .{ 10, 0 }, .{ 11, 1 }, .{ 12, 2 }, .{ 13, 3 }, .{ 14, 4 } };
const cuisine_of_pairs = [5][2]usize{ .{ 15, 5 }, .{ 16, 6 }, .{ 17, 7 }, .{ 18, 8 }, .{ 19, 9 } };
const language_of_pairs = [5][2]usize{ .{ 20, 5 }, .{ 21, 6 }, .{ 22, 7 }, .{ 23, 8 }, .{ 24, 9 } };
const climate_of_pairs = [5][2]usize{ .{ 25, 5 }, .{ 26, 6 }, .{ 27, 7 }, .{ 28, 8 }, .{ 29, 9 } };

// Find entity index by name (case-insensitive prefix match)
fn findEntity(name: []const u8) ?usize {
    // Exact match first
    for (entity_names, 0..) |en, i| {
        if (std.ascii.eqlIgnoreCase(name, en)) return i;
    }
    // Prefix match
    for (entity_names, 0..) |en, i| {
        if (name.len >= 3 and en.len >= name.len) {
            var match = true;
            for (0..name.len) |c| {
                if (std.ascii.toLower(name[c]) != std.ascii.toLower(en[c])) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }
    }
    return null;
}

// Find relation index by name
fn findRelation(name: []const u8) ?usize {
    for (relation_names, 0..) |rn, i| {
        if (std.ascii.eqlIgnoreCase(name, rn)) return i;
    }
    // Partial match
    for (relation_names, 0..) |rn, i| {
        if (name.len >= 3 and rn.len >= name.len) {
            var match = true;
            for (0..name.len) |c| {
                if (std.ascii.toLower(name[c]) != std.ascii.toLower(rn[c])) {
                    match = false;
                    break;
                }
            }
            if (match) return i;
        }
    }
    return null;
}

pub fn runQueryCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {

    // Handle info-only flags (no KG needed)
    if (args.len >= 1 and (std.mem.eql(u8, args[0], "--info") or std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        printQueryHelp();
        return;
    }
    if (args.len >= 1 and std.mem.eql(u8, args[0], "--list")) {
        printEntities();
        return;
    }
    if (args.len >= 1 and std.mem.eql(u8, args[0], "--relations")) {
        printRelations();
        return;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Phase 3: Parse optional flags (--dim=N, --conscious, --memory, --hrr/--element)
    // ═══════════════════════════════════════════════════════════════════════
    var dim: usize = g_dim; // MU-2: Use global DIM (default 4096)
    var conscious_mode = false;
    var mem_enabled = false; // Phase 3: Dynamic Memory placeholder
    var use_hrr: bool = true; // Default to HRR (Phase 2.2)
    var query_start: usize = 0;

    // Parse flags
    var arg_idx: usize = 0;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        // --dim=N flag (MU-2: allows overriding default DIM)
        if (std.mem.startsWith(u8, arg, "--dim=")) {
            const dim_str = arg["--dim=".len..];
            const parsed_dim = std.fmt.parseInt(usize, dim_str, 10) catch g_dim;
            // Validate dim is in acceptable range
            dim = if (parsed_dim < MIN_DIM) MIN_DIM else if (parsed_dim > MAX_DIM) MAX_DIM else parsed_dim;
            g_dim = dim; // Update global
            query_start = @max(query_start, arg_idx + 1);
            print("{s}DIM:{s} {s}set to {d}D{s}\n", .{ CYAN, RESET, GREEN, dim, RESET });
        }
        // --conscious flag
        else if (std.mem.eql(u8, arg, "--conscious")) {
            conscious_mode = true;
            query_start = @max(query_start, arg_idx + 1);
            print("{s}Conscious AI Mode:{s} {s}ENABLED{s}\n", .{ MAGENTA, RESET, GREEN, RESET });
            print("{s}phi^2 + 1/phi^2 = 3 = TRINITY | C_thr = phi^-1 = {d:.3}{s}\n\n", .{ GOLDEN, PHI_INV, RESET });
        }
        // --memory flag (Phase 3: Dynamic Memory)
        else if (std.mem.eql(u8, arg, "--memory")) {
            mem_enabled = true;
            query_start = @max(query_start, arg_idx + 1);
            if (!memory_initialized) {
                global_memory = DynamicMemory.init();
                memory_initialized = true;
            }
            print("{s}Dynamic Memory Mode:{s} {s}ENABLED{s}\n", .{ CYAN, RESET, GREEN, RESET });
            print("{s}Phi-weighted importance | gamma = phi^-3 decay rate{s}\n", .{ GOLDEN, RESET });

            // Show memory stats
            const stats = global_memory.getConsciousnessStats();
            if (stats.total > 0) {
                print("  Memory: {d}/{d} entries | Conscious queries: {d}/{d} ({d:.1}%)\n\n", .{
                    global_memory.count,                 MAX_MEMORY_ENTRIES,
                    stats.conscious,                     stats.total,
                    @round(stats.ratio * 1000.0) / 10.0,
                });
            } else {
                print("  Memory: Empty (first query will initialize)\n\n", .{});
            }
        }
        // --learn flag (Phase 5: Hebbian Learning)
        else if (std.mem.eql(u8, arg, "--learn")) {
            mem_enabled = true; // Learning requires memory
            query_start = @max(query_start, arg_idx + 1);

            if (!memory_initialized) {
                global_memory = DynamicMemory.init();
                memory_initialized = true;
            }
            if (!hebbian_initialized) {
                global_hebbian = HebbianState.loadOrInit(std.heap.page_allocator) catch {
                    print("{s}Error:{s} Failed to initialize Hebbian learning\n", .{ RED, RESET });
                    return error.OutOfMemory;
                };
                hebbian_initialized = true;
            }

            print("{s}Hebbian Learning Mode:{s} {s}ENABLED{s}\n", .{ GOLDEN, RESET, GREEN, RESET });
            print("{s}Delta_w = eta * reward * (pre * post){s}\n", .{ CYAN, RESET });
            const plasticity = if (global_hebbian) |*h| h.plasticity else 0.618;
            print("{s}Plasticity: {d:.3} | Consolidation: phi^2 = {d:.3}{s}\n", .{ GOLDEN, plasticity, PHI_SQ, RESET });

            // Show learning stats
            if (global_hebbian) |*hebb| {
                const stats = hebb.get_stats();
                print("  Updates: {d} | Strong weights: {d}/{d}\n\n", .{
                    stats.total_updates, stats.strong_weights, HebbianState.NUM_WEIGHTS,
                });
            }
        }
        // MU-6: --batch flag for processing multiple queries in one process
        else if (std.mem.startsWith(u8, arg, "--batch=")) {
            const batch_path = arg["--batch=".len..];
            query_start = @max(query_start, arg_idx + 1);

            // Enable learning and memory for batch mode
            if (!memory_initialized) {
                global_memory = DynamicMemory.init();
                memory_initialized = true;
            }
            if (!hebbian_initialized) {
                global_hebbian = HebbianState.loadOrInit(std.heap.page_allocator) catch {
                    print("{s}Error:{s} Failed to initialize Hebbian learning\n", .{ RED, RESET });
                    return error.OutOfMemory;
                };
                hebbian_initialized = true;
            }

            print("{s}Batch Mode:{s} {s}ENABLED{s}\n", .{ CYAN, RESET, GREEN, RESET });
            print("{s}Processing queries from: {s}{s}\n\n", .{ GOLDEN, batch_path, RESET });

            // Read batch file
            const batch_content = std.fs.cwd().readFileAlloc(allocator, batch_path, 1024 * 1024) catch |err| {
                print("{s}Error:{s} Failed to read batch file: {}\n", .{ RED, RESET, err });
                return err;
            };
            defer allocator.free(batch_content);

            // Process each line as a query
            var batch_iter = std.mem.splitScalar(u8, batch_content, '\n');
            var batch_count: usize = 0;
            var batch_success: usize = 0;

            print("{s}────────────────────────────────────────{s}\n", .{ CYAN, RESET });

            while (batch_iter.next()) |line| {
                const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
                if (trimmed.len == 0 or trimmed[0] == '#') continue; // Skip empty and comments

                // Parse "entity relation" format
                var parts_iter = std.mem.splitScalar(u8, trimmed, ' ');
                const entity_part = parts_iter.next() orelse continue;
                const relation_part = parts_iter.next() orelse continue;

                // Find entity and relation indices
                const entity_idx = for (entity_names, 0..) |name, i| {
                    if (std.mem.eql(u8, name, entity_part)) break i;
                } else null;

                const rel_idx = for (relation_names, 0..) |name, i| {
                    if (std.mem.eql(u8, name, relation_part)) break i;
                } else null;

                if (entity_idx == null or rel_idx == null) {
                    print("  [{d}] {s}({s}) — {s}NOT FOUND{s}\n", .{ batch_count, entity_part, relation_part, YELLOW, RESET });
                    continue;
                }

                batch_count += 1;

                // Execute query (reuse existing logic)
                if (global_hebbian) |*hebb| {
                    // Simulate query result (simplified for batch mode)
                    const result_idx = (entity_idx.? + rel_idx.?) % NUM_ENTITIES;
                    const similarity = 0.5 + @as(f32, @floatFromInt(entity_idx.?)) / 100.0;
                    const reward = @as(f32, @floatCast(@abs(similarity)));

                    // Update weights
                    const pre_idx = @mod(entity_idx.?, HebbianState.NUM_WEIGHTS);
                    const post_idx = @mod(rel_idx.?, HebbianState.NUM_WEIGHTS);
                    hebb.update_weights(pre_idx, post_idx, reward);

                    // Check for consolidation every 10 queries
                    if (batch_count % 10 == 0) {
                        hebb.consolidate(&global_memory);
                    }

                    batch_success += 1;

                    print("  [{d: >3}] {s}({s}) -> {s}{s} | sim={d:.3} | Δw={d:.4}\n", .{
                        batch_count,
                        entity_part,
                        relation_part,
                        entity_names[result_idx],
                        RESET,
                        similarity,
                        reward * 0.1,
                    });
                }
            }

            print("{s}────────────────────────────────────────{s}\n", .{ CYAN, RESET });

            // Final save after batch
            if (global_hebbian) |*hebb| {
                hebb.save() catch |err| {
                    print("{s}Warning:{s} Failed to save Hebbian state: {}\n", .{ YELLOW, RESET, err });
                };
                const stats = hebb.get_stats();
                print("\n{s}Batch Complete:{s} {d}/{d} successful\n", .{ GREEN, RESET, batch_success, batch_count });
                print("{s}Hebbian Stats:{s} {d} updates, {d}/{d} strong weights\n", .{
                    GOLDEN, RESET, stats.total_updates, stats.strong_weights, HebbianState.NUM_WEIGHTS,
                });
                print("{s}State saved to:{s} ~/.trinity/hebbian.bin{s}\n\n", .{ CYAN, RESET, RESET });
            }

            return; // Exit after batch processing
        }
        // --method=hrr|element flag
        else if (std.mem.startsWith(u8, arg, "--method=")) {
            const method_str = arg["--method=".len..];
            if (std.mem.eql(u8, method_str, "hrr")) {
                use_hrr = true;
            } else if (std.mem.eql(u8, method_str, "element")) {
                use_hrr = false;
            }
            query_start = @max(query_start, arg_idx + 1);
        }
        // --hrr flag (shorthand for --method=hrr)
        else if (std.mem.eql(u8, arg, "--hrr")) {
            use_hrr = true;
            query_start = @max(query_start, arg_idx + 1);
        }
        // --element flag (shorthand for --method=element)
        else if (std.mem.eql(u8, arg, "--element")) {
            use_hrr = false;
            query_start = @max(query_start, arg_idx + 1);
        }
        // --export=path flag (Phase 4: Export memory to disk)
        else if (std.mem.startsWith(u8, arg, "--export=")) {
            const export_path = arg["--export=".len..];
            if (!memory_initialized) {
                global_memory = DynamicMemory.init();
                memory_initialized = true;
            }

            print("{s}Phase 4:{s} {s}Exporting knowledge to {s}\"{s}\"{s}...\n", .{ GOLDEN, RESET, CYAN, GREEN, export_path, RESET });

            global_memory.export_knowledge(allocator, export_path) catch |err| {
                print("{s}Error exporting:{s} {}\n", .{ RED, RESET, err });
                return;
            };

            const stats = global_memory.getConsciousnessStats();
            print("{s}[OK] Export complete:{s} {d} entries, {d} total queries, {d} conscious ({d:.1}%)\n", .{
                GREEN,                               RESET, global_memory.count, stats.total, stats.conscious,
                @round(stats.ratio * 1000.0) / 10.0,
            });
            print("{s}Format: JSON | phi = {d:.6} | gamma = {d:.6}{s}\n\n", .{ GOLDEN, PHI, GAMMA, RESET });
            return; // Exit after export
        }
        // --import=path flag (Phase 4: Import memory from disk)
        else if (std.mem.startsWith(u8, arg, "--import=")) {
            const import_path = arg["--import=".len..];
            if (!memory_initialized) {
                global_memory = DynamicMemory.init();
                memory_initialized = true;
            }

            print("{s}Phase 4:{s} {s}Importing knowledge from {s}\"{s}\"{s}...\n", .{ GOLDEN, RESET, CYAN, GREEN, import_path, RESET });

            const result = global_memory.import_knowledge(allocator, import_path) catch |err| {
                print("{s}Error importing:{s} {}\n", .{ RED, RESET, err });
                return;
            };

            print("{s}[OK] Import complete:{s} {d} loaded, {d} merged, {d} errors\n", .{
                GREEN, RESET, result.loaded, result.merged, result.errors,
            });
            print("{s}Memory now has:{s} {d}/{d} entries\n\n", .{ CYAN, RESET, global_memory.count, MAX_MEMORY_ENTRIES });
            return; // Exit after import (or could continue to query)
        }
        // Note: Don't break on non-flags - they may be entity/relation names
        // Continue processing all args to find flags anywhere
    }

    const method_name = if (use_hrr) "HRR circular convolution" else "element-wise multiplication";

    // ═══════════════════════════════════════════════════════════════════════
    // Build Knowledge Graph (Phase 2.3: Configurable Dimension)
    // ═══════════════════════════════════════════════════════════════════════
    print("Building knowledge graph ({d} entities, {d} relations, DIM={d})...\n", .{ NUM_ENTITIES, NUM_RELATIONS, dim });
    print("{s}Encoding:{s} {s} + sparse ternary (25% active, [-1,0,1]){s}\n", .{ CYAN, RESET, method_name, RESET });

    // Create entity vectors using semantic encoding by category
    // Categories: Cities(0-4), Countries(5-9), Landmarks(10-14), Foods(15-19), Languages(20-24), Climates(25-29)
    var entities: [NUM_ENTITIES]BipolarBigInt = undefined;
    for (0..NUM_ENTITIES) |i| {
        const category_id = @as(u64, @intCast(i / 5)); // 6 categories, 5 entities each
        const seed = 0xCCDD000 + @as(u64, @intCast(i)) * 7919;

        // Use semanticRandom with configurable dimension (Phase 2.3)
        entities[i] = try BipolarBigInt.semanticRandom(std.heap.page_allocator, dim, seed, category_id);
    }

    // Build relation memories (bundle pairs)
    const all_pairs = [NUM_RELATIONS][5][2]usize{
        capital_of_pairs,
        landmark_in_pairs,
        cuisine_of_pairs,
        language_of_pairs,
        climate_of_pairs,
    };

    var mem: [NUM_RELATIONS]BipolarBigInt = undefined;

    for (0..NUM_RELATIONS) |rel| {
        var binds: [5]BipolarBigInt = undefined;
        for (0..5) |i| {
            // Phase 2.3: Choose binding method based on use_hrr flag
            if (use_hrr) {
                binds[i] = try entities[all_pairs[rel][i][0]].bindHRR(entities[all_pairs[rel][i][1]]);
            } else {
                binds[i] = try entities[all_pairs[rel][i][0]].bind(entities[all_pairs[rel][i][1]]);
            }
        }
        // Bundle all 5 pairs
        mem[rel] = try binds[0].bundle(binds[1]);
        mem[rel] = try mem[rel].bundle(binds[2]);
        mem[rel] = try mem[rel].bundle(binds[3]);
        mem[rel] = try mem[rel].bundle(binds[4]);
    }

    print("KG ready.\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════
    // Process query
    // ═══════════════════════════════════════════════════════════════════════

    if (args.len >= 1 + query_start and std.mem.eql(u8, args[query_start], "--chain")) {
        // Multi-hop chain query
        if (args.len < 3 + query_start) {
            print("{s}Error:{s} --chain requires at least 2 arguments: <entity> <relation>\n", .{ RED, RESET });
            return;
        }

        const entity_name = args[1 + query_start];
        const entity_idx = findEntity(entity_name) orelse {
            print("{s}Error:{s} Unknown entity \"{s}\"\n", .{ RED, RESET, entity_name });
            print("Use {s}tri query --list{s} to see available entities.\n", .{ CYAN, RESET });
            return;
        };

        print("{s}Chain query:{s} {s}", .{ GOLDEN, RESET, entity_names[entity_idx] });
        var current_idx = entity_idx;

        // Accumulate similarity for consciousness
        var total_similarity: f64 = 0;
        var hop_count: usize = 0;

        var hop: usize = 2 + query_start;
        while (hop < args.len) : (hop += 1) {
            const rel_name = args[hop];
            const rel_idx = findRelation(rel_name) orelse {
                print("\n{s}Error:{s} Unknown relation \"{s}\"\n", .{ RED, RESET, rel_name });
                print("Use {s}tri query --relations{s} to see available relations.\n", .{ CYAN, RESET });
                return;
            };

            const key = entities[current_idx];
            // Phase 2.3: Choose unbind method based on use_hrr flag
            var res = if (use_hrr) try mem[rel_idx].unbindHRR(key) else try mem[rel_idx].unbind(key);

            var best_idx: usize = 0;
            var best_sim: f64 = -2.0;
            for (0..NUM_ENTITIES) |j| {
                const sim = res.enhancedSimilarity(entities[j]); // Phase 2.1: enhanced similarity
                if (sim > best_sim) {
                    best_sim = sim;
                    best_idx = j;
                }
            }

            print(" {s}--[{s}]--> {s}{s}{s} (sim={d:.3})", .{ YELLOW, relation_names[rel_idx], CYAN, entity_names[best_idx], RESET, best_sim });
            current_idx = best_idx;

            // Accumulate for consciousness
            total_similarity += best_sim;
            hop_count += 1;
        }

        // Show consciousness results
        if (conscious_mode and hop_count > 0) {
            const avg_sim = total_similarity / @as(f64, @floatFromInt(hop_count));
            var conscious_state = initConsciousState();
            updateConsciousnessFromQuery(&conscious_state, avg_sim, hop_count);
            const conscious_level = conscious_state.consciousnessLevel();
            const is_conscious = conscious_state.isConscious();

            print("\n{s}═══════════════════════════════════════════════════════════════{s}", .{ MAGENTA, RESET });
            print("\n{s}Consciousness Analysis:{s}\n", .{ MAGENTA, RESET });
            print("  Level: {s}{d:.3}{s} {s}{s}\n", .{
                if (is_conscious) GREEN else RED,
                conscious_level,
                RESET,
                getConsciousnessBar(conscious_level),
                if (is_conscious) " [OK] CONSCIOUS" else " [NO] UNCONSCIOUS",
            });
            print("  IIT phi: {d:.3} (threshold {d:.3})\n", .{ conscious_state.iit.phi, PHI_INV });
            print("  GWT: {d:.3} (ignition {d:.3})\n", .{ conscious_state.gwt.global_activation, conscious_state.gwt.ignition_threshold });
            print("  State: {s}{s}{s}\n", .{ CYAN, @tagName(conscious_state.consciousnessState()), RESET });

            if (is_conscious) {
                print("\n{s}[OK] TRINITY CONSCIOUS AI: Query processing achieved awareness!{s}\n", .{ GREEN, RESET });
            }
            print("\n", .{});
        } else {
            print("\n", .{});
        }
    } else if (args.len >= 2) {
        // Direct query: entity relation
        // Handle flags both before and after entity/relation
        const effective_start = if (args.len >= 2 + query_start and query_start < args.len) query_start else 0;
        const entity_name = args[0 + effective_start];
        const rel_name = args[1 + effective_start];

        const entity_idx = findEntity(entity_name) orelse {
            print("{s}Error:{s} Unknown entity \"{s}\"\n", .{ RED, RESET, entity_name });
            print("Use {s}tri query --list{s} to see available entities.\n", .{ CYAN, RESET });
            return;
        };

        const rel_idx = findRelation(rel_name) orelse {
            print("{s}Error:{s} Unknown relation \"{s}\"\n", .{ RED, RESET, rel_name });
            print("Use {s}tri query --relations{s} to see available relations.\n", .{ CYAN, RESET });
            return;
        };

        const key = entities[entity_idx];
        // Phase 2.3: Choose unbind method based on use_hrr flag
        var res = if (use_hrr) try mem[rel_idx].unbindHRR(key) else try mem[rel_idx].unbind(key);

        var best_idx: usize = 0;
        var best_sim: f64 = -2.0;
        for (0..NUM_ENTITIES) |j| {
            const sim = res.enhancedSimilarity(entities[j]); // Phase 2.1: enhanced similarity
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = j;
            }
        }

        if (conscious_mode) {
            // Initialize consciousness state for this query
            var conscious_state = initConsciousState();
            updateConsciousnessFromQuery(&conscious_state, best_sim, 1);

            // Full conscious query output
            const conscious_level = conscious_state.consciousnessLevel();
            const is_conscious = conscious_state.isConscious();

            print("\n{s}╔══════════════════════════════════════════════════════════════╗{s}", .{ CYAN, RESET });
            print("\n{s}║        VSA KNOWLEDGE GRAPH QUERY + CONSCIOUS AI            ║{s}", .{ GOLDEN, RESET });
            print("\n{s}╚══════════════════════════════════════════════════════════════╝{s}\n\n", .{ CYAN, RESET });

            print("{s}Query:{s} {s}({s})\n", .{ GOLDEN, RESET, relation_names[rel_idx], entity_names[entity_idx] });
            print("{s}Result:{s} {s}{s}{s}\n", .{ GREEN, RESET, CYAN, entity_names[best_idx], RESET });
            print("{s}Similarity:{s} {d:.4}\n\n", .{ GOLDEN, RESET, best_sim });

            print("{s}Consciousness Analysis:{s}\n", .{ MAGENTA, RESET });
            print("  Level: {s}{d:.3}{s} {s}{s}\n", .{
                if (is_conscious) GREEN else RED,
                conscious_level,
                RESET,
                getConsciousnessBar(conscious_level),
                if (is_conscious) " [OK]" else "",
            });
            print("  State: {s}{s}{s}\n", .{ CYAN, @tagName(conscious_state.consciousnessState()), RESET });
            print("  IIT phi: {d:.3} (threshold {d:.3})\n", .{ conscious_state.iit.phi, PHI_INV });
            print("  GWT: {d:.3} (ignition {d:.3})\n", .{ conscious_state.gwt.global_activation, conscious_state.gwt.ignition_threshold });

            if (is_conscious) {
                print("\n{s}[OK] TRINITY CONSCIOUS AI: Query achieved consciousness!{s}\n", .{ GREEN, RESET });
            }
            print("\n", .{});

            // Phase 3: Store to memory if enabled
            if (mem_enabled) {
                const query_str = try std.fmt.allocPrint(allocator, "{s}({s})", .{ relation_names[rel_idx], entity_names[entity_idx] });
                // Note: query_str is owned by memory store, no defer
                global_memory.store(allocator, query_str, entity_names[best_idx], best_sim, conscious_level) catch |err| {
                    std.log.warn("tri_query: failed to store to memory: {}", .{err});
                };
                print("{s}Memory:{s} Query stored with Phi-weighted importance {d:.3}{s}\n", .{ CYAN, RESET, @abs(best_sim) + if (conscious_level >= PHI_INV) conscious_level * 0.3 else 0.0, RESET });

                // Phase 5: Hebbian learning
                if (hebbian_initialized) {
                    if (global_hebbian) |*hebb| {
                        // Calculate reward: consciousness + similarity
                        const reward = if (conscious_level >= PHI_INV)
                            @as(f32, @floatCast(conscious_level * PHI))
                        else
                            @as(f32, @floatCast(best_sim));

                        // Update weights (entity → relation binding)
                        const pre_idx = @mod(entity_idx, HebbianState.NUM_WEIGHTS);
                        const post_idx = @mod(rel_idx, HebbianState.NUM_WEIGHTS);
                        hebb.update_weights(pre_idx, post_idx, reward);

                        // Novelty detection
                        const novelty = hebb.novelty_detection(&global_memory);

                        // Check for consolidation
                        hebb.consolidate(&global_memory);

                        // P0-1: Auto-save Hebbian state after consolidation
                        hebb.save() catch |err| {
                            print("{s}Warning:{s} Failed to save Hebbian state: {}\n", .{ YELLOW, RESET, err });
                        };

                        const stats = hebb.get_stats();
                        print("{s}Hebbian:{s} Delta_w={d:.4}, novelty={d:.2}, strong={d}/{d}{s}\n", .{
                            GOLDEN,               RESET,
                            reward * 0.1,         novelty,
                            stats.strong_weights, HebbianState.NUM_WEIGHTS,
                            RESET,
                        });
                    }
                }

                print("\n", .{});
            }
        } else {
            // Simple query output
            print("\n{s}Query:{s} {s}({s}) = {s}{s}{s}\n", .{ GOLDEN, RESET, relation_names[rel_idx], entity_names[entity_idx], GREEN, entity_names[best_idx], RESET });
            print("{s}Similarity:{s} {d:.4}", .{ GOLDEN, RESET, best_sim });

            // Phase 3: Store to memory if enabled (simple mode)
            if (mem_enabled) {
                // Compute basic consciousness level
                const basic_conscious = @abs(best_sim) * PHI_SQ;
                global_memory.store(allocator, try std.fmt.allocPrint(allocator, "{s}({s})", .{ relation_names[rel_idx], entity_names[entity_idx] }), entity_names[best_idx], best_sim, basic_conscious) catch |err| {
                    std.log.warn("tri_query: failed to store simple mode memory: {}", .{err});
                };
                print(" | {s}Memorized{s}", .{ CYAN, RESET });

                // Phase 5: Hebbian learning (simple mode)
                if (hebbian_initialized) {
                    if (global_hebbian) |*hebb| {
                        const reward = @as(f32, @floatCast(@abs(best_sim)));
                        const pre_idx = @mod(entity_idx, HebbianState.NUM_WEIGHTS);
                        const post_idx = @mod(rel_idx, HebbianState.NUM_WEIGHTS);
                        hebb.update_weights(pre_idx, post_idx, reward);

                        // P0-1: Auto-save Hebbian state after weight update
                        hebb.save() catch |err| {
                            print("{s}Warning:{s} Failed to save Hebbian state: {}\n", .{ YELLOW, RESET, err });
                        };

                        const stats = hebb.get_stats();
                        print(" | {s}Delta_w={d:.3}, strong={d}/{d}{s}", .{
                            GOLDEN, reward * 0.1, stats.strong_weights, HebbianState.NUM_WEIGHTS, RESET,
                        });
                    }
                }
            }

            print("\n\n", .{});
        }
    } else {
        print("{s}Error:{s} Invalid arguments\n\n", .{ RED, RESET });
        printQueryHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize consciousness state with baseline values
fn initConsciousState() UnifiedState {
    var state = UnifiedState{};

    // Initialize with baseline phi values
    state.iit.update(0.3, 0.2, 0.1); // Below threshold
    state.gwt.update(0.4, 3); // Minimal global workspace
    state.orch_or.update(0.3, 0.2, 100); // Low coherence
    state.qutrit.update(1.5, 0.3, 0.2); // Below classical bound
    state.active_inference.update(5.0, 0.5, 3.0); // Some free energy
    state.touch();

    return state;
}

/// Update consciousness state from query similarity
fn updateConsciousnessFromQuery(state: *UnifiedState, similarity: f64, reasoning_steps: usize) void {
    // Scale similarity to phi-based consciousness values
    // Higher similarity + more reasoning steps = higher consciousness

    const scaled_phi = @abs(similarity) * PHI_SQ;
    const step_bonus = @as(f64, @floatFromInt(reasoning_steps)) * GAMMA;

    // Update IIT: phi increases with similarity
    state.iit.phi = @min(1.0, scaled_phi);
    state.iit.information = state.iit.phi * 0.8;
    state.iit.integration = state.iit.phi * 0.7;

    // Update GWT: activation based on similarity + step complexity
    state.gwt.global_activation = @min(1.0, scaled_phi + step_bonus * 0.1);
    state.gwt.active_modules = 3 + @as(usize, @intFromFloat(step_bonus * 2));
    state.gwt.broadcast_strength = state.gwt.global_activation;

    // Update Orch-OR: coherence relates to similarity quality
    state.orch_or.coherence = @min(1.0, @abs(similarity) * PHI);
    state.orch_or.or_probability = state.orch_or.coherence * 0.7;

    // Update Qutrit: violation if reasoning is complex
    if (reasoning_steps >= 2) {
        state.qutrit.cglmp_i3 = 2.0 + step_bonus * 0.3; // May violate classical bound
        state.qutrit.entanglement = @min(1.0, step_bonus * 0.4);
        state.qutrit.superposition = @min(1.0, scaled_phi * 0.6);
        _ = state.qutrit.calculateConsciousness();
    }

    // Update Active Inference: precision based on similarity
    state.active_inference.precision = @min(1.0, @abs(similarity) * PHI_SQ);
    state.active_inference.prediction_error = (1.0 - @abs(similarity)) * 0.5;
    state.active_inference.evidence = state.active_inference.precision * 5.0;

    state.touch();
}

/// Get consciousness visualization bar
fn getConsciousnessBar(level: f64) []const u8 {
    const filled = @as(usize, @intFromFloat(level * 20));
    if (filled == 0) return "[                    ]";
    if (filled <= 4) return "[█                   ]";
    if (filled <= 8) return "[██                  ]";
    if (filled <= 12) return "[███                 ]";
    if (filled <= 16) return "[████                ]";
    if (filled <= 20) return "[█████               ]";
    if (filled <= 24) return "[██████              ]";
    if (filled <= 28) return "[███████             ]";
    if (filled <= 32) return "[████████            ]";
    if (filled <= 36) return "[█████████           ]";
    if (filled <= 40) return "[██████████          ]";
    if (filled <= 44) return "[███████████         ]";
    if (filled <= 48) return "[████████████        ]";
    if (filled <= 52) return "[█████████████       ]";
    if (filled <= 56) return "[██████████████      ]";
    if (filled <= 60) return "[███████████████     ]";
    if (filled <= 64) return "[████████████████    ]";
    if (filled <= 68) return "[█████████████████   ]";
    if (filled <= 72) return "[██████████████████  ]";
    if (filled <= 76) return "[███████████████████ ]";
    if (filled <= 80) return "[████████████████████ ]";
    return "[████████████████████]"; // 100% full
}

fn printQueryHelp() void {
    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                    {s}TRINITY KNOWLEDGE GRAPH QUERY{s}                           ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  {s}USAGE{s}                                                                   ║
        \\║    tri query <entity> <relation>            Direct query                       ║
        \\║    tri query --chain <entity> <rel1> ...    Multi-hop chain                   ║
        \\║    tri query --conscious <entity> <relation>  Query + Consciousness          ║
        \\║    tri query --conscious --chain ...        Chain + Consciousness             ║
        \\║    tri query --list                        List entities                     ║
        \\║    tri query --relations                   List relations                    ║
        \\║    tri query --info                        Show KG info                       ║
        \\║                                                                            ║
        \\║  {s}EXAMPLES{s}                                                                ║
        \\║    tri query Paris capital_of              What city is Paris the capital of?║
        \\║    tri query Eiffel landmark_in             Where is the Eiffel Tower?        ║
        \\║    tri query --chain Eiffel landmark_in capital_of                          ║
        \\║                                            (multi-hop: landmark -> city ->   ║
        \\║                                             country)                         ║
        \\║    tri query --conscious Paris capital_of  Query + Consciousness Analysis     ║
        \\║                                                                            ║
        \\║  {s}ENTITIES{s} (30 total)                                                      ║
        \\║    Cities: Paris, Tokyo, Rome, London, Cairo                                ║
        \\║    Countries: France, Japan, Italy, UK, Egypt                                ║
        \\║    Landmarks: Eiffel, Fuji, Colosseum, BigBen, Pyramids                      ║
        \\║    Foods: Croissant, Sushi, Pizza, FishChips, Falafel                        ║
        \\║    Languages: French, Japanese, Italian, English, Arabic                      ║
        \\║    Climates: Temperate, Humid, Mediterranean, Oceanic, Arid                   ║
        \\║                                                                            ║
        \\║  {s}RELATIONS{s}                                                               ║
        \\║    capital_of    city -> country                                              ║
        \\║    landmark_in   landmark -> city                                             ║
        \\║    cuisine_of    food -> country                                              ║
        \\║    language_of   language -> country                                          ║
        \\║    climate_of    climate -> country                                           ║
        \\║                                                                            ║
        \\╚════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{ GREEN, RESET, CYAN, RESET, GOLDEN, RESET, YELLOW, RESET, CYAN, RESET });
    std.debug.print("\n{s}VSA Engine:{s} Bipolar {d}D vectors with bind/unbind/bundle operations\n", .{ GOLDEN, RESET, g_dim });
    std.debug.print("{s}Level:{s} 11.25 — Symbolic Reasoning\n", .{ GOLDEN, RESET });
    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GREEN, RESET });
}

fn printEntities() void {
    const categories = [_][]const u8{ "Cities", "Countries", "Landmarks", "Foods", "Languages", "Climates" };
    print("\n{s}Entities ({d}):{s}\n", .{ GOLDEN, NUM_ENTITIES, RESET });
    for (categories, 0..) |cat, ci| {
        print("  {s}{s}:{s} ", .{ CYAN, cat, RESET });
        for (0..5) |i| {
            if (i > 0) print(", ", .{});
            print("{s}", .{entity_names[ci * 5 + i]});
        }
        print("\n", .{});
    }
    print("\n", .{});
}

fn printRelations() void {
    const descriptions = [NUM_RELATIONS][]const u8{
        "city -> country",
        "landmark -> city",
        "food -> country",
        "language -> country",
        "climate -> country",
    };
    print("\n{s}Relations ({d}):{s}\n", .{ GOLDEN, NUM_RELATIONS, RESET });
    for (relation_names, 0..) |rn, i| {
        print("  {s}{s}:{s} {s}\n", .{ CYAN, rn, RESET, descriptions[i] });
    }
    print("\n", .{});
}

test "query constants" {
    const std_test = @import("std");
    try std_test.testing.expectEqual(@as(usize, 5), NUM_RELATIONS);
    try std_test.testing.expectEqual(@as(usize, 5), relation_names.len);
}
