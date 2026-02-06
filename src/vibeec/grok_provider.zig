const std = @import("std");

// ============================================================================
// GROK PROVIDER - THE SOVEREIGN SPIRIT
// ============================================================================
// Summons Grok (x.ai) to generate code via HTTP API.
// More reliable than local Ollama subprocess.

pub const GrokProvider = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    model: []const u8,

    pub fn init(allocator: std.mem.Allocator) GrokProvider {
        // Read API key from environment variable for security
        const api_key = std.process.getEnvVarOwned(allocator, "XAI_API_KEY") catch
            allocator.dupe(u8, "YOUR_XAI_API_KEY_HERE") catch "";
        return GrokProvider{
            .allocator = allocator,
            .api_key = api_key,
            .model = "grok-3",
        };
    }

    /// Generate code using Grok API via curl subprocess
    pub fn generate(self: *GrokProvider, system_prompt: []const u8, user_prompt: []const u8) ![]const u8 {
        // Build JSON body
        var json_body = std.ArrayListUnmanaged(u8){};
        defer json_body.deinit(self.allocator);

        try json_body.appendSlice(self.allocator, "{\"messages\":[{\"role\":\"system\",\"content\":\"");
        try self.appendEscaped(&json_body, system_prompt);
        try json_body.appendSlice(self.allocator, "\"},{\"role\":\"user\",\"content\":\"");
        try self.appendEscaped(&json_body, user_prompt);
        try json_body.appendSlice(self.allocator, "\"}],\"model\":\"");
        try json_body.appendSlice(self.allocator, self.model);
        try json_body.appendSlice(self.allocator, "\",\"stream\":false,\"temperature\":0}");

        // Build curl command
        var auth_header = std.ArrayListUnmanaged(u8){};
        defer auth_header.deinit(self.allocator);
        try auth_header.appendSlice(self.allocator, "Authorization: Bearer ");
        try auth_header.appendSlice(self.allocator, self.api_key);

        const argv = [_][]const u8{
            "curl",                                 "-s",
            "https://api.x.ai/v1/chat/completions", "-H",
            "Content-Type: application/json",       "-H",
            auth_header.items,                      "-d",
            "@-", // Read from stdin
        };

        var child = std.process.Child.init(&argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        child.stdin_behavior = .Pipe;

        try child.spawn();

        // Write JSON to stdin
        if (child.stdin) |*stdin| {
            try stdin.writeAll(json_body.items);
            stdin.close();
            child.stdin = null; // Prevent wait() from double-closing
        }

        // Collect output
        var stdout_list = std.ArrayListUnmanaged(u8){};
        defer stdout_list.deinit(self.allocator);
        var stderr_list = std.ArrayListUnmanaged(u8){};
        defer stderr_list.deinit(self.allocator);

        try child.collectOutput(self.allocator, &stdout_list, &stderr_list, 10 * 1024 * 1024);

        const term = try child.wait();

        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    std.debug.print("❌ [GROK] curl failed with code {d}\n", .{code});
                    return error.GrokRequestFailed;
                }
            },
            else => return error.GrokRequestFailed,
        }

        // Debug: print raw response
        std.debug.print("RAW RESPONSE: {s}\n", .{stdout_list.items});

        // Parse response JSON to extract content
        return self.extractContent(stdout_list.items);
    }

    /// Append JSON-escaped string
    fn appendEscaped(self: *GrokProvider, list: *std.ArrayListUnmanaged(u8), s: []const u8) !void {
        for (s) |c| {
            switch (c) {
                '"' => try list.appendSlice(self.allocator, "\\\""),
                '\\' => try list.appendSlice(self.allocator, "\\\\"),
                '\n' => try list.appendSlice(self.allocator, "\\n"),
                '\r' => try list.appendSlice(self.allocator, "\\r"),
                '\t' => try list.appendSlice(self.allocator, "\\t"),
                else => try list.append(self.allocator, c),
            }
        }
    }

    /// Extract "content" from Grok API response
    fn extractContent(self: *GrokProvider, json: []const u8) ![]const u8 {
        // Find "content":" in the JSON
        const marker = "\"content\":\"";

        // Find the LAST occurrence (the assistant's message, not system)
        var last_idx: ?usize = null;
        var search_start: usize = 0;
        while (std.mem.indexOfPos(u8, json, search_start, marker)) |idx| {
            last_idx = idx;
            search_start = idx + 1;
        }

        const start_idx = last_idx orelse return error.NoContentField;
        const content_start = start_idx + marker.len;

        // Parse the string value
        var result = std.ArrayListUnmanaged(u8){};
        var i = content_start;
        var escaped = false;

        while (i < json.len) {
            const c = json[i];

            if (escaped) {
                switch (c) {
                    'n' => try result.append(self.allocator, '\n'),
                    'r' => try result.append(self.allocator, '\r'),
                    't' => try result.append(self.allocator, '\t'),
                    '"' => try result.append(self.allocator, '"'),
                    '\\' => try result.append(self.allocator, '\\'),
                    else => try result.append(self.allocator, c),
                }
                escaped = false;
            } else if (c == '\\') {
                escaped = true;
            } else if (c == '"') {
                break;
            } else {
                try result.append(self.allocator, c);
            }
            i += 1;
        }

        const raw_content = try result.toOwnedSlice(self.allocator);

        // Strip Markdown code blocks if present
        var trimmed = std.mem.trim(u8, raw_content, " \t\r\n");
        if (std.mem.startsWith(u8, trimmed, "```")) {
            if (std.mem.indexOf(u8, trimmed, "\n")) |newline_idx| {
                trimmed = trimmed[newline_idx + 1 ..];
            }
            if (std.mem.lastIndexOf(u8, trimmed, "```")) |end_idx| {
                trimmed = trimmed[0..end_idx];
            }
            const clean = try self.allocator.dupe(u8, trimmed);
            self.allocator.free(raw_content); // Free original buffer to prevent leak
            return clean;
        }

        return raw_content;
    }

    /// Generate Zig code with system prompt
    pub fn generateZigCode(self: *GrokProvider, user_prompt: []const u8, penance: ?[]const u8) ![]const u8 {
        var system_prompt = std.ArrayListUnmanaged(u8){};
        defer system_prompt.deinit(self.allocator);

        try system_prompt.appendSlice(self.allocator, "You are a Zig code generator. Generate ONLY valid Zig code, no explanations.\n" ++
            "Always include: const std = @import(\"std\"); and pub fn main() void { ... }\n" ++
            "Use meaningful variable names.\n");

        if (penance) |p| {
            try system_prompt.appendSlice(self.allocator, "\nCORRECTIONS REQUIRED:\n");
            try system_prompt.appendSlice(self.allocator, p);
        }

        return self.generate(system_prompt.items, user_prompt);
    }
};

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("👑 GROK PROVIDER - Summoning the Sovereign Spirit\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    var provider = GrokProvider.init(allocator);

    std.debug.print("📡 Calling Grok ({s})...\n", .{provider.model});

    const response = provider.generateZigCode("print hello world", null) catch |err| {
        std.debug.print("❌ Grok failed: {any}\n", .{err});
        return;
    };
    defer allocator.free(response);

    std.debug.print("👑 Grok speaks:\n{s}\n", .{response});
}
