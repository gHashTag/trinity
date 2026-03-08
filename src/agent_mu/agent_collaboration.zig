//! MULTI-AGENT COLLABORATION v8.18
//!
//! AGENT MU collaborates with other agents:
//! - PHI: Pattern matching and semantic analysis
//! - VIBEE: Code generation from specs
//! - Swarm: Consensus and distributed decision
//! - Claude Flow: MCP bridge for external services
//!
//! Protocol: JSON over HTTP (localhost)
//! Timeout: 5 seconds per agent
//! Fallback: Return null on timeout, use solo mode

const std = @import("std");
const diagnostic = @import("diagnostic.zig");
const FixType = diagnostic.FixType;

const Allocator = std.mem.Allocator;
const ArrayListManaged = std.array_list.AlignedManaged;
const StringHashMap = std.hash_map.StringHashMap;

/// Types of agents AGENT MU can collaborate with
pub const AgentType = enum {
    phi, // Pattern matching specialist
    vibee, // Code generator
    swarm, // Consensus engine
    claude_flow, // MCP bridge
    agent_mu, // Self-reference
    pas, // Predictive Algorithmic Systematics
};

/// Message types for inter-agent communication
pub const MessageType = enum {
    analysis_request,
    codegen_request,
    consensus_request,
    fix_proposal,
    fix_result,
    status_query,
    error_report,
    pas_analysis,
    pas_forecast,
    pas_validation,
};

/// Collaboration message between agents
pub const CollaborationMessage = struct {
    from: AgentType,
    to: AgentType,
    message_type: MessageType,
    payload: []const u8,
    timestamp: i64,
    correlation_id: []const u8,
    response_expected: bool,

    /// Free allocated memory
    pub fn deinit(self: *CollaborationMessage, allocator: Allocator) void {
        allocator.free(self.payload);
        allocator.free(self.correlation_id);
        self.* = undefined;
    }
};

/// Pending request awaiting response
pub const PendingRequest = struct {
    request: CollaborationMessage,
    sent_at: i64,
    timeout_ms: u64,
    retries_left: usize,
};

/// Agent contribution to merged response
pub const AgentContribution = struct {
    agent: AgentType,
    suggested_fix: ?FixType,
    confidence: f64,
    reasoning: []const u8,

    pub fn deinit(self: *AgentContribution, allocator: Allocator) void {
        allocator.free(self.reasoning);
        self.* = undefined;
    }
};

/// Merged response from multiple agents
pub const MergedResponse = struct {
    selected_fix: FixType,
    confidence: f64,
    agent_contributions: ArrayListManaged(AgentContribution, null),

    pub fn init(allocator: Allocator) MergedResponse {
        return MergedResponse{
            .selected_fix = .UNKNOWN,
            .confidence = 0.0,
            .agent_contributions = ArrayListManaged(AgentContribution, null).init(allocator),
        };
    }

    pub fn deinit(self: *MergedResponse) void {
        for (self.agent_contributions.items) |*contrib| {
            contrib.deinit(self.agent_contributions.allocator);
        }
        self.agent_contributions.deinit();
        self.* = undefined;
    }
};

/// Agent endpoint configuration
pub const AgentEndpoint = struct {
    agent: AgentType,
    host: []const u8,
    port: u16,
    path: []const u8,
    timeout_ms: u64,

    pub fn formatUrl(self: *const AgentEndpoint, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "http://{s}:{d}{s}", .{
            self.host,
            self.port,
            self.path,
        });
    }
};

/// PAS analysis response
pub const PasAnalysisResponse = struct {
    primary_pattern: []const u8,
    confidence: f64,
    recommended_mu: f64,
    energy_harvested: f64,
    sacred_valid: bool,
    timestamp: i64,
};

/// PAS forecast response
pub const PasForecastResponse = struct {
    predicted_multiplier: f64,
    confidence_min: f64,
    confidence_max: f64,
    time_horizon: u64,
    trinity_score: f64,
};

/// PAS sacred validation result
pub const PasSacredValidation = struct {
    trinity_valid: bool,
    phi_sq_plus_phi_inv_sq: f64,
    mu_valid: bool,
    chi_valid: bool,
};

/// PAS daemon status
pub const PasDaemonStatus = struct {
    active: bool,
    analyses_performed: u64,
    energy_harvested: f64,
    sacred_validation_rate: f64,
    pending_recommendations: u32,
};

/// Multi-agent collaborator
pub const AgentCollaborator = struct {
    outgoing: ArrayListManaged(CollaborationMessage, null),
    incoming: ArrayListManaged(CollaborationMessage, null),
    pending_requests: StringHashMap(PendingRequest),
    endpoints: [5]AgentEndpoint,
    allocator: Allocator,
    enabled: bool,
    last_error: ?[]const u8,

    pub fn init(allocator: Allocator) !AgentCollaborator {
        var collab = AgentCollaborator{
            .outgoing = ArrayListManaged(CollaborationMessage, null).init(allocator),
            .incoming = ArrayListManaged(CollaborationMessage, null).init(allocator),
            .pending_requests = StringHashMap(PendingRequest).init(allocator),
            .endpoints = undefined,
            .allocator = allocator,
            .enabled = true,
            .last_error = null,
        };

        // Configure default endpoints
        collab.endpoints[0] = AgentEndpoint{
            .agent = .phi,
            .host = "localhost",
            .port = 8081,
            .path = "/api/phi/analyze",
            .timeout_ms = 5000,
        };
        collab.endpoints[1] = AgentEndpoint{
            .agent = .vibee,
            .host = "localhost",
            .port = 8082,
            .path = "/api/vibee/gen",
            .timeout_ms = 10000, // Codegen takes longer
        };
        collab.endpoints[2] = AgentEndpoint{
            .agent = .swarm,
            .host = "localhost",
            .port = 8083,
            .path = "/api/swarm/consensus",
            .timeout_ms = 7000,
        };
        collab.endpoints[3] = AgentEndpoint{
            .agent = .claude_flow,
            .host = "localhost",
            .port = 8084,
            .path = "/api/claude/forward",
            .timeout_ms = 5000,
        };
        collab.endpoints[4] = AgentEndpoint{
            .agent = .pas,
            .host = "localhost",
            .port = 8085,
            .path = "/api/pas/analyze",
            .timeout_ms = 5000,
        };

        return collab;
    }

    pub fn deinit(self: *AgentCollaborator) void {
        for (self.outgoing.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.outgoing.deinit();

        for (self.incoming.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.incoming.deinit();

        var iter = self.pending_requests.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var req = entry.value_ptr.*;
            req.request.deinit(self.allocator);
        }
        self.pending_requests.deinit();

        if (self.last_error) |err| {
            self.allocator.free(err);
        }
        self.* = undefined;
    }

    /// Generate correlation ID
    fn generateCorrelationId(self: *AgentCollaborator) ![]const u8 {
        const timestamp = std.time.timestamp();
        var rand: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&rand)) catch {
            rand = @as(u64, @intCast(timestamp));
        };
        return std.fmt.allocPrint(self.allocator, "agent_mu_{d}_{d}", .{ timestamp, rand });
    }

    /// Request analysis from PHI (pattern matching specialist)
    pub fn requestPhiAnalysis(
        self: *AgentCollaborator,
        error_msg: []const u8,
    ) !?[]const u8 {
        if (!self.enabled) return null;

        const payload = try std.fmt.allocPrint(self.allocator,
            \\{{"error": "{s}", "task": "analyze"}}
        , .{error_msg});
        defer self.allocator.free(payload);

        const correlation_id = try self.generateCorrelationId();
        defer self.allocator.free(correlation_id);

        const msg = CollaborationMessage{
            .from = .agent_mu,
            .to = .phi,
            .message_type = .analysis_request,
            .payload = try self.allocator.dupe(u8, payload),
            .timestamp = std.time.timestamp(),
            .correlation_id = correlation_id,
            .response_expected = true,
        };

        try self.outgoing.append(msg);

        // STUB: In real implementation, send HTTP request
        // For now, return null (not implemented)
        return null;
    }

    /// Request codegen from VIBEE (code generator)
    pub fn requestVibeeCodegen(
        self: *AgentCollaborator,
        spec: []const u8,
    ) !?[]const u8 {
        if (!self.enabled) return null;

        _ = spec;

        // STUB: Would call VIBEE codegen API
        // Returns generated Zig code as string
        return null;
    }

    /// Request consensus from Swarm (distributed decision)
    pub fn requestSwarmConsensus(
        self: *AgentCollaborator,
        options: []const []const u8,
    ) !?usize {
        if (!self.enabled) return null;

        _ = options;

        // STUB: Would query swarm for consensus
        // Returns index of selected option
        return null;
    }

    /// Merge multi-agent responses into single decision
    pub fn mergeResponses(
        self: *AgentCollaborator,
        responses: []const []const u8,
    ) !MergedResponse {
        var merged = MergedResponse.init(self.allocator);
        errdefer merged.deinit();

        // Parse responses and collect FixType suggestions
        var fix_counts = StringHashMap(usize).init(self.allocator);
        defer {
            var iter = fix_counts.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
            fix_counts.deinit();
        }

        // STUB: Parse JSON responses and count FixType votes
        // For now, return unknown
        _ = responses;

        return merged;
    }

    /// Send message to agent (STUB)
    pub fn sendMessage(self: *AgentCollaborator, to: AgentType, msg_type: MessageType, payload: []const u8) !void {
        const correlation_id = try self.generateCorrelationId();
        errdefer self.allocator.free(correlation_id);

        const msg = CollaborationMessage{
            .from = .agent_mu,
            .to = to,
            .message_type = msg_type,
            .payload = try self.allocator.dupe(u8, payload),
            .timestamp = std.time.timestamp(),
            .correlation_id = correlation_id,
            .response_expected = false,
        };

        try self.outgoing.append(msg);

        // STUB: Actually send HTTP request
    }

    /// Check if agent is available
    pub fn isAgentAvailable(self: *AgentCollaborator, agent: AgentType) bool {
        // STUB: Would check agent health endpoint
        _ = agent;
        return self.enabled;
    }

    /// Get collaboration statistics
    pub fn getStats(self: *const AgentCollaborator) struct {
        sent: usize,
        received: usize,
        pending: usize,
        errors: usize,
    } {
        var errors: usize = 0;
        if (self.last_error != null) errors = 1;

        return .{
            .sent = self.outgoing.items.len,
            .received = self.incoming.items.len,
            .pending = self.pending_requests.count(),
            .errors = errors,
        };
    }

    /// Enable/disable collaboration
    pub fn setEnabled(self: *AgentCollaborator, enabled: bool) void {
        self.enabled = enabled;
    }

    /// Update agent endpoint
    pub fn updateEndpoint(
        self: *AgentCollaborator,
        agent: AgentType,
        host: []const u8,
        port: u16,
    ) !void {
        for (&self.endpoints) |*endpoint| {
            if (endpoint.agent == agent) {
                endpoint.host = try self.allocator.dupe(u8, host);
                endpoint.port = port;
                return;
            }
        }
        return error.AgentNotFound;
    }

    /// Get last error (if any)
    pub fn getLastError(self: *const AgentCollaborator) ?[]const u8 {
        return self.last_error;
    }

    /// Clear last error
    pub fn clearError(self: *AgentCollaborator) void {
        if (self.last_error) |err| {
            self.allocator.free(err);
            self.last_error = null;
        }
    }

    /// Request PAS analysis (Predictive Algorithmic Systematics)
    pub fn requestPasAnalysis(
        self: *AgentCollaborator,
        fix_type: []const u8,
        success_rate: f64,
        attempt_count: u32,
    ) !?PasAnalysisResponse {
        if (!self.enabled) return null;

        _ = fix_type;
        _ = attempt_count;

        // STUB: In production, would HTTP to localhost:8085
        // For now, return mock PAS analysis
        const phi: f64 = 1.6180339887;
        const mu: f64 = 1.0 / (phi * phi * 10.0);

        return PasAnalysisResponse{
            .primary_pattern = "divide_and_conquer",
            .confidence = 0.96,
            .recommended_mu = mu * success_rate,
            .energy_harvested = 0.42,
            .sacred_valid = true,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Request PAS forecast
    pub fn requestPasForecast(
        self: *AgentCollaborator,
        horizon: u64,
    ) !?PasForecastResponse {
        if (!self.enabled) return null;

        _ = horizon;

        const phi: f64 = 1.6180339887;
        return PasForecastResponse{
            .predicted_multiplier = phi * phi,
            .confidence_min = 0.85,
            .confidence_max = 0.98,
            .time_horizon = 100,
            .trinity_score = 3.0,
        };
    }

    /// Validate PAS sacred constants
    pub fn validatePasSacred(self: *AgentCollaborator) !PasSacredValidation {
        _ = self;
        const phi: f64 = 1.6180339887;
        const phi_sq = phi * phi;
        const phi_inv_sq = 1.0 / phi_sq;
        const sum = phi_sq + phi_inv_sq;
        const mu: f64 = 1.0 / (phi_sq * 10.0);
        const chi: f64 = 1.0 / (phi * 10.0);

        return PasSacredValidation{
            .trinity_valid = @abs(sum - 3.0) < 0.001,
            .phi_sq_plus_phi_inv_sq = sum,
            .mu_valid = @abs(mu - 0.0382) < 0.001,
            .chi_valid = @abs(chi - 0.0618) < 0.001,
        };
    }

    /// Get PAS daemon status
    pub fn getPasStatus(self: *AgentCollaborator) !PasDaemonStatus {
        _ = self;
        // STUB: Would query PAS daemon health endpoint
        return PasDaemonStatus{
            .active = true,
            .analyses_performed = 0,
            .energy_harvested = 0.0,
            .sacred_validation_rate = 1.0,
            .pending_recommendations = 0,
        };
    }

    /// Export collaboration log as markdown
    pub fn exportLog(self: *const AgentCollaborator, writer: anytype) !void {
        try writer.writeAll(
            \\# Multi-Agent Collaboration Log
            \\| Time | From | To | Type | Status |
            \\|------|------|-----|------|--------|
        );

        for (self.outgoing.items) |msg| {
            const status = if (msg.response_expected) "pending" else "sent";
            try writer.print("| {d} | {s} | {s} | {s} | {s} |\n", .{ msg.timestamp, @tagName(msg.from), @tagName(msg.to), @tagName(msg.message_type), status });
        }
    }
};

/// Global collaborator instance
var global_collab: ?AgentCollaborator = null;
var global_collab_init = false;

/// Get or create global collaborator
pub fn getGlobalCollaborator() !*AgentCollaborator {
    if (!global_collab_init) {
        global_collab = try AgentCollaborator.init(std.heap.page_allocator);
        global_collab_init = true;
    }
    return &global_collab.?;
}

/// Initialize collaboration with custom endpoints
pub fn initCollaboration(
    phi_host: []const u8,
    phi_port: u16,
    vibee_host: []const u8,
    vibee_port: u16,
) !void {
    const collab = try getGlobalCollaborator();

    try collab.updateEndpoint(.phi, phi_host, phi_port);
    try collab.updateEndpoint(.vibee, vibee_host, vibee_port);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "AgentCollaborator: initialization" {
    const allocator = std.testing.allocator;
    var collab = try AgentCollaborator.init(allocator);
    defer collab.deinit();

    try std.testing.expect(collab.enabled);
    try std.testing.expectEqual(@as(usize, 5), collab.endpoints.len);
}

test "AgentCollaborator: is agent available" {
    const allocator = std.testing.allocator;
    var collab = try AgentCollaborator.init(allocator);
    defer collab.deinit();

    try std.testing.expect(collab.isAgentAvailable(.phi));
}

test "AgentCollaborator: enable/disable" {
    const allocator = std.testing.allocator;
    var collab = try AgentCollaborator.init(allocator);
    defer collab.deinit();

    collab.setEnabled(false);
    try std.testing.expect(!collab.enabled);

    collab.setEnabled(true);
    try std.testing.expect(collab.enabled);
}

test "AgentCollaborator: get stats" {
    const allocator = std.testing.allocator;
    var collab = try AgentCollaborator.init(allocator);
    defer collab.deinit();

    const stats = collab.getStats();

    try std.testing.expectEqual(@as(usize, 0), stats.sent);
    try std.testing.expectEqual(@as(usize, 0), stats.received);
    try std.testing.expectEqual(@as(usize, 0), stats.pending);
}

test "AgentEndpoint: format URL" {
    const allocator = std.testing.allocator;
    const endpoint = AgentEndpoint{
        .agent = .phi,
        .host = "localhost",
        .port = 8081,
        .path = "/api/test",
        .timeout_ms = 5000,
    };

    var mutable_ep = endpoint;
    const url = try mutable_ep.formatUrl(allocator);
    defer allocator.free(url);

    try std.testing.expectEqualStrings("http://localhost:8081/api/test", url);
}

test "MergedResponse: init and deinit" {
    const allocator = std.testing.allocator;
    var response = MergedResponse.init(allocator);
    defer response.deinit();

    try std.testing.expectEqual(.UNKNOWN, response.selected_fix);
    try std.testing.expectEqual(@as(usize, 0), response.agent_contributions.items.len);
}

test "AgentContribution: init with fields" {
    const allocator = std.testing.allocator;
    const reasoning = "Test reasoning";

    var contrib = AgentContribution{
        .agent = .phi,
        .suggested_fix = .TYPE_FIX,
        .confidence = 0.9,
        .reasoning = try allocator.dupe(u8, reasoning),
    };
    defer contrib.deinit(allocator);

    try std.testing.expectEqual(.phi, contrib.agent);
    try std.testing.expectEqual(.TYPE_FIX, contrib.suggested_fix.?);
    try std.testing.expectApproxEqRel(@as(f64, 0.9), contrib.confidence, 0.01);
}

test "initCollaboration" {
    try initCollaboration("localhost", 8081, "localhost", 8082);

    const collab = try getGlobalCollaborator();
    try std.testing.expect(collab.enabled);
}
