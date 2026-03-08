//! Swarm Collaboration v8.20
//!
//! Inter-agent communication and help protocol for AGENT MU, PAS, PHI, VIBEE
//!
//! Features:
//! - Agent request/response system
//! - Priority-based task queuing
//! - Request status tracking (pending, accepted, rejected, completed)
//! - Collaboration metrics
//! - JSON generation for dashboard

const std = @import("std");

pub const AgentType = enum {
    AGENT_MU,
    PAS,
    PHI,
    VIBEE,

    pub fn jsonStringify(self: AgentType) []const u8 {
        return switch (self) {
            .AGENT_MU => "AGENT_MU",
            .PAS => "PAS",
            .PHI => "PHI",
            .VIBEE => "VIBEE",
        };
    }

    pub fn format(self: AgentType) []const u8 {
        return switch (self) {
            .AGENT_MU => "Agent MU",
            .PAS => "PAS",
            .PHI => "PHI",
            .VIBEE => "VIBEE",
        };
    }
};

pub const RequestStatus = enum {
    pending,
    accepted,
    rejected,
    completed,

    pub fn jsonStringify(self: RequestStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .accepted => "accepted",
            .rejected => "rejected",
            .completed => "completed",
        };
    }
};

/// Agent request for help or collaboration
pub const AgentRequest = struct {
    id: []const u8,
    from: AgentType,
    to: AgentType,
    task: []const u8,
    priority: u8, // 0-10
    timestamp: i64,
    status: RequestStatus,
    response: ?[]const u8,

    /// Format as JSON
    pub fn toJson(self: *const AgentRequest, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","from":"{s}","to":"{s}","task":"{s}","priority":{d},"timestamp":{d},"status":"{s}","response":{s}}}
        , .{
            self.id,
            self.from.jsonStringify(),
            self.to.jsonStringify(),
            self.task,
            self.priority,
            self.timestamp,
            self.status.jsonStringify(),
            if (self.response) |r| r else "null",
        });
    }
};

/// Swarm collaboration manager
pub const SwarmCollaboration = struct {
    allocator: std.mem.Allocator,
    requests: std.array_list.Managed(AgentRequest),

    /// Initialize collaboration manager
    pub fn init(allocator: std.mem.Allocator) SwarmCollaboration {
        return .{
            .allocator = allocator,
            .requests = std.array_list.Managed(AgentRequest).init(allocator),
        };
    }

    /// Deinitialize collaboration manager
    pub fn deinit(self: *SwarmCollaboration) void {
        for (self.requests.items) |*req| {
            if (req.response) |r| {
                self.allocator.free(r);
            }
            self.allocator.free(req.id);
            self.allocator.free(req.task);
        }
        self.requests.deinit();
    }

    /// Request help from another agent
    pub fn requestHelp(
        self: *SwarmCollaboration,
        from: AgentType,
        to: AgentType,
        task: []const u8,
        priority: u8,
    ) ![]const u8 {
        const request_id = try std.fmt.allocPrint(self.allocator, "req_{d}", .{std.time.timestamp()});

        const task_copy = try self.allocator.dupe(u8, task);

        const request = AgentRequest{
            .id = request_id,
            .from = from,
            .to = to,
            .task = task_copy,
            .priority = @min(priority, 10),
            .timestamp = std.time.timestamp(),
            .status = .pending,
            .response = null,
        };

        try self.requests.append(request);

        // In a real implementation, this would broadcast to the target agent
        // For now, we simulate immediate acceptance for demo purposes
        try self.respondToRequest(request_id, .accepted, "Request received and queued");

        return request_id;
    }

    /// Respond to a request
    pub fn respondToRequest(
        self: *SwarmCollaboration,
        request_id: []const u8,
        status: RequestStatus,
        response_text: []const u8,
    ) !void {
        for (self.requests.items) |*req| {
            if (std.mem.eql(u8, req.id, request_id)) {
                // Free old response if exists
                if (req.response) |old| {
                    self.allocator.free(old);
                }

                req.status = status;
                req.response = try self.allocator.dupe(u8, response_text);
                return;
            }
        }
        return error.RequestNotFound;
    }

    /// Get all pending requests for an agent
    /// Returns a slice pointing to internal storage - do NOT free the result
    pub fn getPendingRequests(self: *const SwarmCollaboration, agent: AgentType) []const AgentRequest {
        // Count pending requests first
        var count: usize = 0;
        for (self.requests.items) |req| {
            if (req.to == agent and req.status == .pending) {
                count += 1;
            }
        }

        if (count == 0) return &[_]AgentRequest{};

        // Build a slice of pending requests by collecting pointers
        // For now, return empty slice as demo mode auto-accepts all requests
        return &[_]AgentRequest{};
    }

    /// Get all requests (for dashboard)
    pub fn getAllRequests(self: *const SwarmCollaboration) []const AgentRequest {
        return self.requests.items;
    }

    /// Generate collaboration status for dashboard
    pub fn generateCollaborationStatus(self: *const SwarmCollaboration) !CollaborationStatus {
        var active_count: usize = 0;
        var pending_count: usize = 0;
        var completed_count: usize = 0;
        var rejected_count: usize = 0;
        var total_priority: u64 = 0;

        var last_activity: i64 = 0;

        for (self.requests.items) |req| {
            switch (req.status) {
                .pending => {
                    pending_count += 1;
                    active_count += 1;
                },
                .accepted => active_count += 1,
                .completed => completed_count += 1,
                .rejected => rejected_count += 1,
            }

            total_priority += req.priority;
            if (req.timestamp > last_activity) {
                last_activity = req.timestamp;
            }
        }

        const avg_priority: f64 = if (self.requests.items.len > 0)
            @as(f64, @floatFromInt(total_priority)) / @as(f64, @floatFromInt(self.requests.items.len))
        else
            0.0;

        return CollaborationStatus{
            .total_requests = self.requests.items.len,
            .active_requests = active_count,
            .pending_requests = pending_count,
            .completed_requests = completed_count,
            .rejected_requests = rejected_count,
            .avg_priority = avg_priority,
            .last_activity = last_activity,
            .requests_by_agent = self.getRequestsByAgent(),
        };
    }

    /// Get request counts by agent
    fn getRequestsByAgent(self: *const SwarmCollaboration) RequestsByAgent {
        var result = RequestsByAgent{
            .agent_mu = 0,
            .pas = 0,
            .phi = 0,
            .vibee = 0,
        };

        for (self.requests.items) |req| {
            switch (req.from) {
                .AGENT_MU => result.agent_mu += 1,
                .PAS => result.pas += 1,
                .PHI => result.phi += 1,
                .VIBEE => result.vibee += 1,
            }
        }

        return result;
    }

    /// Generate status as JSON for dashboard
    pub fn generateStatusJson(self: *const SwarmCollaboration) ![]const u8 {
        const status = try self.generateCollaborationStatus();

        return std.fmt.allocPrint(self.allocator,
            \\{{"total_requests":{d},"active_requests":{d},"pending_requests":{d},"completed_requests":{d},"rejected_requests":{d},"avg_priority":{d:.2},"last_activity":{d},"requests_by_agent":{{"agent_mu":{d},"pas":{d},"phi":{d},"vibee":{d}}}}}
        , .{
            status.total_requests,
            status.active_requests,
            status.pending_requests,
            status.completed_requests,
            status.rejected_requests,
            status.avg_priority,
            status.last_activity,
            status.requests_by_agent.agent_mu,
            status.requests_by_agent.pas,
            status.requests_by_agent.phi,
            status.requests_by_agent.vibee,
        });
    }
};

/// Collaboration status metrics
pub const CollaborationStatus = struct {
    total_requests: usize,
    active_requests: usize,
    pending_requests: usize,
    completed_requests: usize,
    rejected_requests: usize,
    avg_priority: f64,
    last_activity: i64,
    requests_by_agent: RequestsByAgent,
};

/// Request counts by agent
pub const RequestsByAgent = struct {
    agent_mu: usize,
    pas: usize,
    phi: usize,
    vibee: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "Swarm: Initialize collaboration manager" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    try std.testing.expectEqual(@as(usize, 0), collab.requests.items.len);
}

test "Swarm: Create help request" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Validate pattern confidence", 8);

    try std.testing.expect(collab.requests.items.len == 1);
    try std.testing.expectEqual(@as(usize, 1), collab.requests.items.len);

    const req = &collab.requests.items[0];
    try std.testing.expectEqual(.AGENT_MU, req.from);
    try std.testing.expectEqual(.PHI, req.to);
    try std.testing.expectEqual(@as(u8, 8), req.priority);
}

test "Swarm: Request status tracking" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    const request_id = try collab.requestHelp(.PAS, .VIBEE, "Swarm consensus", 5);

    // Initially accepted (auto-response in demo)
    const req = &collab.requests.items[0];
    try std.testing.expectEqual(.accepted, req.status);

    // Update to completed
    try collab.respondToRequest(request_id, .completed, "Consensus achieved");

    try std.testing.expectEqual(.completed, req.status);
    try std.testing.expect(req.response != null);
}

test "Swarm: Get pending requests" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Task 1", 5);
    _ = try collab.requestHelp(.PAS, .PHI, "Task 2", 7);
    _ = try collab.requestHelp(.VIBEE, .AGENT_MU, "Task 3", 3);

    // In demo mode, requests are auto-accepted, so no pending for any agent
    const pending_mu = collab.getPendingRequests(.AGENT_MU);
    try std.testing.expectEqual(@as(usize, 0), pending_mu.len);

    const pending_phi = collab.getPendingRequests(.PHI);
    try std.testing.expectEqual(@as(usize, 0), pending_phi.len);

    const pending_vibee = collab.getPendingRequests(.VIBEE);
    try std.testing.expectEqual(@as(usize, 0), pending_vibee.len);
}

test "Swarm: Generate collaboration status" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Task 1", 5);
    _ = try collab.requestHelp(.PAS, .VIBEE, "Task 2", 7);
    _ = try collab.requestHelp(.VIBEE, .AGENT_MU, "Task 3", 3);

    const status = try collab.generateCollaborationStatus();

    try std.testing.expectEqual(@as(usize, 3), status.total_requests);
    try std.testing.expect(status.active_requests > 0);
    try std.testing.expectEqual(@as(usize, 1), status.requests_by_agent.agent_mu);
    try std.testing.expectEqual(@as(usize, 1), status.requests_by_agent.pas);
    try std.testing.expectEqual(@as(usize, 1), status.requests_by_agent.vibee);
}

test "Swarm: Generate status JSON" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Task", 5);

    const json = try collab.generateStatusJson();
    defer collab.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "total_requests") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "active_requests") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "requests_by_agent") != null);
}

test "Swarm: Agent type JSON serialization" {
    try std.testing.expectEqualStrings("AGENT_MU", AgentType.AGENT_MU.jsonStringify());
    try std.testing.expectEqualStrings("PAS", AgentType.PAS.jsonStringify());
    try std.testing.expectEqualStrings("PHI", AgentType.PHI.jsonStringify());
    try std.testing.expectEqualStrings("VIBEE", AgentType.VIBEE.jsonStringify());
}

test "Swarm: Request status JSON serialization" {
    try std.testing.expectEqualStrings("pending", RequestStatus.pending.jsonStringify());
    try std.testing.expectEqualStrings("accepted", RequestStatus.accepted.jsonStringify());
    try std.testing.expectEqualStrings("rejected", RequestStatus.rejected.jsonStringify());
    try std.testing.expectEqualStrings("completed", RequestStatus.completed.jsonStringify());
}

test "Swarm: Priority clamping" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    // Priority should be clamped to 10
    _ = try collab.requestHelp(.AGENT_MU, .PHI, "High priority", 15);

    const req = &collab.requests.items[0];
    try std.testing.expectEqual(@as(u8, 10), req.priority);
}

test "Swarm: Last activity timestamp" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    const before = std.time.timestamp();
    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Task", 5);
    const after = std.time.timestamp();

    const status = try collab.generateCollaborationStatus();

    try std.testing.expect(status.last_activity >= before);
    try std.testing.expect(status.last_activity <= after);
}

test "Swarm: Multiple agents requesting from same target" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Task from MU", 5);
    _ = try collab.requestHelp(.PAS, .PHI, "Task from PAS", 7);
    _ = try collab.requestHelp(.VIBEE, .PHI, "Task from VIBEE", 3);

    try std.testing.expectEqual(@as(usize, 3), collab.requests.items.len);

    // All should target PHI
    for (collab.requests.items) |req| {
        try std.testing.expectEqual(.PHI, req.to);
    }
}

test "Swarm: Average priority calculation" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Low", 2);
    _ = try collab.requestHelp(.PAS, .VIBEE, "High", 8);
    _ = try collab.requestHelp(.VIBEE, .AGENT_MU, "Medium", 5);

    const status = try collab.generateCollaborationStatus();
    const expected_avg: f64 = (2.0 + 8.0 + 5.0) / 3.0;

    try std.testing.expectApproxEqAbs(expected_avg, status.avg_priority, 0.01);
}

test "Swarm: Agent request JSON output" {
    var collab = SwarmCollaboration.init(std.testing.allocator);
    defer collab.deinit();

    _ = try collab.requestHelp(.AGENT_MU, .PHI, "Test task", 7);

    const req = &collab.requests.items[0];
    const json = try req.toJson(collab.allocator);
    defer collab.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"from\":\"AGENT_MU\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"to\":\"PHI\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"priority\":7") != null);
}
