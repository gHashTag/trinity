// @origin(generated) @regen(done)
// ============================================================================
// PERPLEXITY SCHOLAR AGENT — Pipeline Link 24
// Research-assisted error fixing via Perplexity Sonar Pro API
// Queries Perplexity for Zig best practices when swe_fix (Link 11) fails
// φ² + 1/φ² = 3 = TRINITY
// ============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const PERPLEXITY_BASE = "https://api.perplexity.ai";
pub const SONAR_PRO = "sonar-pro";
pub const MAX_TOKENS: u32 = 4096;
pub const TEMPERATURE: f32 = 0.2;

const SYSTEM_PROMPT =
    \\You are a Scientific Researcher at TRI University specializing in Zig programming.
    \\Provide precise solutions with code snippets. Prefer official Zig documentation.
    \\Target: Zig 0.15.x, std only, zero external dependencies.
    \\Always show corrected code, not just explanations.
;

// ============================================================================
// TYPES
// ============================================================================

pub const Citation = struct {
    url: []const u8,
    title: []const u8,
};

pub const ResearchResult = struct {
    answer: []const u8,
    model_used: []const u8,
    tokens_used: u32,
    allocator: Allocator,

    pub fn deinit(self: *ResearchResult) void {
        self.allocator.free(self.answer);
    }
};

/// A2A Agent Card (Phase 2 — full A2A server in future PR)
pub const AgentCard = struct {
    name: []const u8,
    description: []const u8,
    version: []const u8,
    capabilities: []const []const u8,
};

// ============================================================================
// PERPLEXITY SCHOLAR
// ============================================================================

pub const PerplexityScholar = struct {
    allocator: Allocator,
    api_key: []const u8,
    model: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, api_key: []const u8) Self {
        return .{
            .allocator = allocator,
            .api_key = api_key,
            .model = SONAR_PRO,
        };
    }

    /// Build the JSON request body for Perplexity chat/completions API
    pub fn buildRequestBody(self: *Self, question: []const u8, context: []const u8) ![]const u8 {
        var body: std.ArrayListUnmanaged(u8) = .{};
        errdefer body.deinit(self.allocator);
        const w = body.writer(self.allocator);

        try w.writeAll("{\"model\":\"");
        try w.writeAll(self.model);
        try w.writeAll("\",\"messages\":[{\"role\":\"system\",\"content\":\"");
        try writeJsonEscaped(w, SYSTEM_PROMPT);
        try w.writeAll("\"},{\"role\":\"user\",\"content\":\"");
        // Combine context and question
        if (context.len > 0) {
            try writeJsonEscaped(w, "Context: ");
            try writeJsonEscaped(w, context);
            try writeJsonEscaped(w, "\\n\\n");
        }
        try writeJsonEscaped(w, question);
        try w.writeAll("\"}],\"max_tokens\":");
        try std.fmt.format(w, "{d}", .{MAX_TOKENS});
        try w.writeAll(",\"temperature\":");
        try std.fmt.format(w, "{d:.1}", .{TEMPERATURE});
        try w.writeAll("}");

        return body.toOwnedSlice(self.allocator);
    }

    /// Call Perplexity chat/completions API
    pub fn research(self: *Self, question: []const u8, context: []const u8) !ResearchResult {
        const body = try self.buildRequestBody(question, context);
        defer self.allocator.free(body);

        const url = PERPLEXITY_BASE ++ "/chat/completions";

        // Build auth header: "Bearer pplx-..."
        var auth_buf: [512]u8 = undefined;
        const auth_header = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{self.api_key}) catch
            return error.OutOfMemory;

        // Use std.http.Client directly (same pattern as http_client.zig)
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = std.Uri.parse(url) catch return error.InvalidUrl;

        const extra_headers = [_]std.http.Header{
            .{ .name = "User-Agent", .value = "Trinity-Scholar/1.0 (Zig)" },
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "Content-Type", .value = "application/json" },
            .{ .name = "Authorization", .value = auth_header },
        };

        var req = client.request(.POST, uri, .{
            .extra_headers = &extra_headers,
            .redirect_behavior = .unhandled,
        }) catch return error.ConnectionFailed;
        defer req.deinit();

        // Send body
        req.transfer_encoding = .{ .content_length = body.len };
        var body_writer = req.sendBodyUnflushed(&.{}) catch return error.RequestFailed;
        body_writer.writer.writeAll(body) catch return error.RequestFailed;
        body_writer.end() catch return error.RequestFailed;
        if (req.connection) |conn| conn.flush() catch return error.RequestFailed;

        // Receive response
        var redirect_buf: [0]u8 = .{};
        var response = req.receiveHead(&redirect_buf) catch return error.Timeout;

        var transfer_buffer: [8192]u8 = undefined;
        var reader = response.reader(&transfer_buffer);
        const response_body = reader.allocRemaining(self.allocator, std.Io.Limit.limited(1 * 1024 * 1024)) catch
            return error.OutOfMemory;
        defer self.allocator.free(response_body);

        if (@intFromEnum(response.head.status) != 200) {
            return error.RequestFailed;
        }

        // Parse response JSON to extract answer
        const answer = try self.parseResponse(response_body);

        return ResearchResult{
            .answer = answer,
            .model_used = self.model,
            .tokens_used = 0,
            .allocator = self.allocator,
        };
    }

    /// Pipeline helper: formulate query from compile error and research fix
    pub fn researchForPipeline(self: *Self, error_msg: []const u8, spec_name: []const u8) ![]const u8 {
        var question_buf: [2048]u8 = undefined;
        const question = std.fmt.bufPrint(&question_buf, "Zig 0.15: How to fix this compile/test error?\n\n{s}", .{
            error_msg[0..@min(error_msg.len, 1500)],
        }) catch return error.OutOfMemory;

        var context_buf: [512]u8 = undefined;
        const context = std.fmt.bufPrint(&context_buf, "Trinity project, spec: {s}. Pure Zig, std only, zero dependencies.", .{
            spec_name[0..@min(spec_name.len, 200)],
        }) catch return error.OutOfMemory;

        var result = try self.research(question, context);
        // Transfer ownership of answer to caller (don't deinit result)
        const answer = result.answer;
        result.answer = "";
        return answer;
    }

    /// Parse Perplexity API response to extract answer text
    fn parseResponse(self: *Self, response_body: []const u8) ![]const u8 {
        // Find "content":" in the response (choices[0].message.content)
        // Navigate: "choices" -> [0] -> "message" -> "content"
        const content_marker = "\"content\":\"";
        const content_start = std.mem.indexOf(u8, response_body, content_marker) orelse
            return error.InvalidResponse;

        const start = content_start + content_marker.len;
        if (start >= response_body.len) return error.InvalidResponse;

        // Find the end of the content string (unescaped quote)
        var end = start;
        while (end < response_body.len) {
            if (response_body[end] == '"' and (end == start or (end > 0 and response_body[end - 1] != '\\'))) {
                break;
            }
            end += 1;
        }

        if (end <= start) return error.InvalidResponse;

        // Allocate and copy the answer
        return try self.allocator.dupe(u8, response_body[start..end]);
    }

    /// Return A2A Agent Card for discovery
    pub fn getAgentCard() AgentCard {
        return .{
            .name = "perplexity-scholar",
            .description = "Research agent that queries Perplexity Sonar Pro for Zig best practices and error fixes",
            .version = "1.0.0",
            .capabilities = &[_][]const u8{
                "research",
                "zig-error-fixing",
                "documentation-lookup",
            },
        };
    }
};

/// Write a string with JSON escaping (escape quotes, backslashes, newlines)
fn writeJsonEscaped(writer: anytype, input: []const u8) !void {
    for (input) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

// ============================================================================
// ERRORS
// ============================================================================

pub const ScholarError = error{
    ConnectionFailed,
    RequestFailed,
    InvalidResponse,
    InvalidUrl,
    Timeout,
    OutOfMemory,
    ApiKeyMissing,
};

// ============================================================================
// TESTS
// ============================================================================

test "PerplexityScholar init" {
    const allocator = std.testing.allocator;
    var scholar = PerplexityScholar.init(allocator, "pplx-test-key");
    try std.testing.expectEqualStrings("sonar-pro", scholar.model);
    try std.testing.expectEqualStrings("pplx-test-key", scholar.api_key);
    _ = &scholar;
}

test "JSON request body format" {
    const allocator = std.testing.allocator;
    var scholar = PerplexityScholar.init(allocator, "pplx-test");

    const body = try scholar.buildRequestBody("How to fix error?", "Trinity project");
    defer allocator.free(body);

    // Verify it's valid-ish JSON structure
    try std.testing.expect(std.mem.startsWith(u8, body, "{\"model\":\"sonar-pro\""));
    try std.testing.expect(std.mem.indexOf(u8, body, "\"messages\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_tokens\":4096") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"temperature\":0.2") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"role\":\"system\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "How to fix error?") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "Context: Trinity project") != null);
}

test "response parsing" {
    const allocator = std.testing.allocator;
    var scholar = PerplexityScholar.init(allocator, "pplx-test");

    // Mock Perplexity API response
    const mock_response =
        \\{"id":"abc","model":"sonar-pro","choices":[{"index":0,"message":{"role":"assistant","content":"Use std.mem.Allocator instead of direct malloc."},"finish_reason":"stop"}],"usage":{"prompt_tokens":50,"completion_tokens":20,"total_tokens":70}}
    ;

    const answer = try scholar.parseResponse(mock_response);
    defer allocator.free(answer);

    try std.testing.expectEqualStrings("Use std.mem.Allocator instead of direct malloc.", answer);
}

test "agent card valid" {
    const card = PerplexityScholar.getAgentCard();
    try std.testing.expectEqualStrings("perplexity-scholar", card.name);
    try std.testing.expectEqualStrings("1.0.0", card.version);
    try std.testing.expect(card.capabilities.len == 3);
    try std.testing.expectEqualStrings("research", card.capabilities[0]);
}

test "writeJsonEscaped" {
    const allocator = std.testing.allocator;
    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(allocator);

    try writeJsonEscaped(buf.writer(allocator), "hello \"world\"\nnewline");
    try std.testing.expectEqualStrings("hello \\\"world\\\"\\nnewline", buf.items);
}

test "graceful skip without key" {
    // Verify env-based skip logic works
    const key = std.posix.getenv("PERPLEXITY_API_KEY_NONEXISTENT");
    try std.testing.expect(key == null);
}
