// context.zig — Context window management for tri-api
// Token estimation, auto-compaction (truncate tool outputs → summarize).
// Issue #67: Phase 8 Context Management
const std = @import("std");
const proto = @import("tool_protocol.zig");

// ─── Config ──────────────────────────────────────────────────────────────────

pub const ContextConfig = struct {
    max_tokens: u32 = 180_000, // Claude Sonnet context window
    compact_threshold: u32 = 144_000, // 80% — trigger compaction
    keep_turns: u32 = 3, // preserve last N turns during truncation
};

// ─── Token estimation ────────────────────────────────────────────────────────

/// Estimate token count from byte length (~4 bytes/token average for cl100k_base).
pub fn estimateTokens(text: []const u8) u32 {
    return @intCast(@max(1, text.len / 4));
}

// ─── Context Manager ─────────────────────────────────────────────────────────

pub const ContextManager = struct {
    allocator: std.mem.Allocator,
    config: ContextConfig,
    api_input_tokens: u32, // accurate count from API responses
    api_output_tokens: u32,

    pub fn init(allocator: std.mem.Allocator) ContextManager {
        return .{
            .allocator = allocator,
            .config = .{},
            .api_input_tokens = 0,
            .api_output_tokens = 0,
        };
    }

    /// Track tokens reported by the API (more accurate than estimation).
    pub fn trackApiUsage(self: *ContextManager, input_tokens: u32, output_tokens: u32) void {
        self.api_input_tokens += input_tokens;
        self.api_output_tokens += output_tokens;
    }

    /// Quick check: are we near the limit?
    pub fn isNearLimit(self: *ContextManager, messages: *const std.ArrayList(u8)) bool {
        return estimateTokens(messages.items) >= self.config.compact_threshold;
    }

    /// Format context usage for TUI display. Caller owns memory.
    pub fn formatUsage(self: *ContextManager, messages: *const std.ArrayList(u8)) [64]u8 {
        const est = estimateTokens(messages.items);
        var buf: [64]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "[~{d}K/{d}K tokens]", .{ est / 1000, self.config.max_tokens / 1000 }) catch {
            @memcpy(buf[0..12], "[ctx ?/?K]  ");
        };
        return buf;
    }

    /// Phase 1: Truncate old tool_result content, keeping last N turns.
    /// Returns true if any truncation happened.
    pub fn truncateOldToolOutputs(self: *ContextManager, messages: *std.ArrayList(u8)) bool {
        // Count turns from the end to find the cutoff point.
        // A "turn" = one assistant message. Count "role":"assistant" from the end.
        const data = messages.items;
        const assistant_marker = "\"role\":\"assistant\"";
        var turn_count: u32 = 0;
        var cutoff_pos: usize = data.len;

        // Walk backwards to find position of the Nth assistant message from end
        var search_end = data.len;
        while (search_end > assistant_marker.len) {
            // Search backwards for the marker
            var pos = search_end - 1;
            var found = false;
            while (pos >= assistant_marker.len) : (pos -= 1) {
                if (std.mem.startsWith(u8, data[pos - assistant_marker.len + 1 ..], assistant_marker)) {
                    turn_count += 1;
                    if (turn_count == self.config.keep_turns) {
                        // Everything before this position is eligible for truncation
                        cutoff_pos = pos - assistant_marker.len + 1;
                        found = true;
                        break;
                    }
                    search_end = pos - assistant_marker.len + 1;
                    found = true;
                    break;
                }
                if (pos == 0) break;
            }
            if (!found) break;
            if (cutoff_pos < data.len) break;
        }

        if (cutoff_pos >= data.len) return false; // Not enough turns to truncate

        // Now scan the region [0..cutoff_pos] for "type":"tool_result" blocks
        // and replace their "content":"..." with truncation marker
        const tool_marker = "\"type\":\"tool_result\"";
        const content_marker = "\"content\":\"";
        var modified = false;

        var result = std.ArrayList(u8).empty;
        var i: usize = 0;

        while (i < data.len) {
            if (i < cutoff_pos) {
                // In the truncatable region — look for tool_result content
                if (i + tool_marker.len <= data.len and
                    std.mem.eql(u8, data[i .. i + tool_marker.len], tool_marker))
                {
                    // Found a tool_result. Copy up to and including tool_result marker
                    result.appendSlice(self.allocator, data[i .. i + tool_marker.len]) catch return false;
                    const j = i + tool_marker.len;

                    // Find the "content":" field after it
                    if (std.mem.indexOfPos(u8, data, j, content_marker)) |ci| {
                        if (ci < cutoff_pos and ci - j < 200) {
                            // Copy everything between tool_result marker and content value
                            result.appendSlice(self.allocator, data[j..ci]) catch return false;
                            result.appendSlice(self.allocator, content_marker) catch return false;

                            // Find the end of the content string value
                            const val_start = ci + content_marker.len;
                            var val_end = val_start;
                            while (val_end < data.len) : (val_end += 1) {
                                if (data[val_end] == '"' and (val_end == val_start or data[val_end - 1] != '\\')) break;
                            }
                            const original_len = val_end - val_start;

                            if (original_len > 200) {
                                // Replace with truncation marker
                                var trunc_buf: [64]u8 = undefined;
                                const trunc_msg = std.fmt.bufPrint(&trunc_buf, "[truncated {d} bytes]", .{original_len}) catch "[truncated]";
                                result.appendSlice(self.allocator, trunc_msg) catch return false;
                                modified = true;
                            } else {
                                // Short content — keep it
                                result.appendSlice(self.allocator, data[val_start..val_end]) catch return false;
                            }

                            i = val_end;
                            continue;
                        }
                    }
                    i = j;
                    continue;
                }
            }
            result.append(self.allocator, data[i]) catch return false;
            i += 1;
        }

        if (modified) {
            // Replace messages content
            messages.clearRetainingCapacity();
            messages.appendSlice(self.allocator, result.items) catch {};
        }
        result.deinit(self.allocator);

        return modified;
    }

    /// Build a compaction request body for API summarization.
    /// Returns the JSON request body (caller owns memory), or null if not needed.
    /// The caller should POST this to the API, parse the text response,
    /// then call applySummary() with the result.
    pub fn buildCompactionRequest(self: *ContextManager, messages: *const std.ArrayList(u8), model: []const u8) ?[]const u8 {
        if (!self.isNearLimit(messages)) return null;

        var body = std.ArrayList(u8).empty;
        body.appendSlice(self.allocator, "{\"model\":\"") catch return null;
        body.appendSlice(self.allocator, model) catch return null;
        body.appendSlice(self.allocator, "\",\"max_tokens\":2048,\"messages\":[{\"role\":\"user\",\"content\":\"") catch return null;

        // Inject summary prompt + conversation excerpt
        const prompt_prefix = "Summarize the following conversation concisely in 2-3 paragraphs. Preserve: all file paths mentioned, key decisions made, current task state, and any errors encountered. Conversation:\\n\\n";
        body.appendSlice(self.allocator, prompt_prefix) catch return null;

        // Include first portion of messages (up to ~100K chars)
        const max_excerpt = @min(messages.items.len, 400_000);
        proto.writeJsonEscaped(body.writer(self.allocator), messages.items[0..max_excerpt]) catch return null;

        body.appendSlice(self.allocator, "\"}]}") catch return null;

        return body.toOwnedSlice(self.allocator) catch null;
    }

    /// Apply a summary: replace old messages with summary + keep recent turns.
    pub fn applySummary(self: *ContextManager, messages: *std.ArrayList(u8), summary: []const u8) void {
        // Find the start of the last N turns
        const data = messages.items;
        const assistant_marker = "\"role\":\"assistant\"";
        var turn_count: u32 = 0;
        var keep_from: usize = data.len;

        var search_pos = data.len;
        while (search_pos > 0) {
            const region = data[0..search_pos];
            if (std.mem.lastIndexOf(u8, region, assistant_marker)) |pos| {
                turn_count += 1;
                if (turn_count == self.config.keep_turns) {
                    // Walk back to the start of this message object
                    var msg_start = pos;
                    while (msg_start > 0 and data[msg_start] != ',') : (msg_start -= 1) {}
                    keep_from = if (data[msg_start] == ',') msg_start else msg_start;
                    break;
                }
                search_pos = pos;
            } else break;
        }

        // Build new messages: [{"role":"user","content":"[Context Summary]\n{summary}"},...recent turns...]
        var new_msgs = std.ArrayList(u8).empty;
        new_msgs.appendSlice(self.allocator, "[{\"role\":\"user\",\"content\":\"[Previous context summary]\\n") catch return;
        proto.writeJsonEscaped(new_msgs.writer(self.allocator), summary) catch return;
        new_msgs.appendSlice(self.allocator, "\"}") catch return;

        // Append recent turns
        if (keep_from < data.len) {
            new_msgs.appendSlice(self.allocator, data[keep_from..]) catch return;
        }

        // Replace
        messages.clearRetainingCapacity();
        messages.appendSlice(self.allocator, new_msgs.items) catch {};
        new_msgs.deinit(self.allocator);
    }
};

// ─── Tests ───────────────────────────────────────────────────────────────────

test "estimateTokens" {
    try std.testing.expect(estimateTokens("hello world") > 0);
    try std.testing.expectEqual(@as(u32, 2), estimateTokens("12345678"));
    try std.testing.expectEqual(@as(u32, 1), estimateTokens("hi"));
}

test "ContextManager isNearLimit" {
    var ctx = ContextManager.init(std.testing.allocator);
    ctx.config.compact_threshold = 10; // 10 tokens = 40 bytes

    // 20 bytes = 5 tokens < 10 threshold
    var small = std.ArrayList(u8).empty;
    defer small.deinit(std.testing.allocator);
    try small.appendSlice(std.testing.allocator, "12345678901234567890");
    try std.testing.expect(!ctx.isNearLimit(&small));

    // 100 bytes = 25 tokens > 10 threshold
    var large = std.ArrayList(u8).empty;
    defer large.deinit(std.testing.allocator);
    try large.appendSlice(std.testing.allocator, "a" ** 100);
    try std.testing.expect(ctx.isNearLimit(&large));
}

test "truncateOldToolOutputs" {
    const allocator = std.testing.allocator;
    var ctx = ContextManager.init(allocator);
    ctx.config.keep_turns = 1;

    // Build a messages array with 2 assistant turns and a long tool_result in the first
    const msgs_data =
        \\[{"role":"user","content":"do something"},{"role":"assistant","content":"ok"},{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}]},{"role":"assistant","content":"done"},{"role":"user","content":"thanks"}]
    ;

    var messages = std.ArrayList(u8).empty;
    defer messages.deinit(allocator);
    try messages.appendSlice(allocator, msgs_data);

    const modified = ctx.truncateOldToolOutputs(&messages);
    try std.testing.expect(modified);
    // The truncated version should be shorter
    try std.testing.expect(messages.items.len < msgs_data.len);
    // Should contain truncation marker
    try std.testing.expect(std.mem.indexOf(u8, messages.items, "[truncated") != null);
}
