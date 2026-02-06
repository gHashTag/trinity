// ============================================================================
// ANTHROPIC PROVIDER - Advanced Reasoning (Claude)
// ============================================================================
// Uses Anthropic API for advanced reasoning and code generation.
// Best for: Complex reasoning, math proofs, architecture design
// Model: claude-3-haiku-20240307 (fast, cost-effective)

const std = @import("std");

pub const AnthropicProvider = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    model: []const u8,
    base_url: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch
            allocator.dupe(u8, "") catch "";

        return Self{
            .allocator = allocator,
            .api_key = api_key,
            .model = "claude-3-haiku-20240307",
            .base_url = "https://api.anthropic.com/v1/messages",
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.api_key.len > 0) {
            self.allocator.free(self.api_key);
        }
    }

    pub fn isConfigured(self: *const Self) bool {
        return self.api_key.len > 0;
    }

    pub fn generate(self: *Self, system_prompt: []const u8, user_prompt: []const u8) ![]const u8 {
        if (!self.isConfigured()) {
            return error.ApiKeyNotConfigured;
        }

        // Anthropic uses different JSON format
        var json_body = std.ArrayListUnmanaged(u8){};
        defer json_body.deinit(self.allocator);

        try json_body.appendSlice(self.allocator, "{\"model\":\"");
        try json_body.appendSlice(self.allocator, self.model);
        try json_body.appendSlice(self.allocator, "\",\"max_tokens\":2048,\"system\":\"");
        try self.appendEscaped(&json_body, system_prompt);
        try json_body.appendSlice(self.allocator, "\",\"messages\":[{\"role\":\"user\",\"content\":\"");
        try self.appendEscaped(&json_body, user_prompt);
        try json_body.appendSlice(self.allocator, "\"}]}");

        var auth_header = std.ArrayListUnmanaged(u8){};
        defer auth_header.deinit(self.allocator);
        try auth_header.appendSlice(self.allocator, "x-api-key: ");
        try auth_header.appendSlice(self.allocator, self.api_key);

        const argv = [_][]const u8{
            "curl", "-s",
            self.base_url,
            "-H", "Content-Type: application/json",
            "-H", "anthropic-version: 2023-06-01",
            "-H", auth_header.items,
            "-d", json_body.items,
        };

        var child = std.process.Child.init(&argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        var stdout_list = std.ArrayListUnmanaged(u8){};
        defer stdout_list.deinit(self.allocator);
        var stderr_list = std.ArrayListUnmanaged(u8){};
        defer stderr_list.deinit(self.allocator);

        try child.collectOutput(self.allocator, &stdout_list, &stderr_list, 10 * 1024 * 1024);
        const term = try child.wait();

        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    std.debug.print("[ANTHROPIC] curl failed with code {d}\n", .{code});
                    return error.AnthropicRequestFailed;
                }
            },
            else => return error.AnthropicRequestFailed,
        }

        std.debug.print("[ANTHROPIC] RAW: {s}\n", .{stdout_list.items});
        return self.extractContent(stdout_list.items);
    }

    fn appendEscaped(self: *Self, list: *std.ArrayListUnmanaged(u8), s: []const u8) !void {
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

    fn extractContent(self: *Self, json: []const u8) ![]const u8 {
        // Anthropic response format: "content":[{"type":"text","text":"..."}]
        const marker = "\"text\":\"";

        var last_idx: ?usize = null;
        var search_start: usize = 0;
        while (std.mem.indexOfPos(u8, json, search_start, marker)) |idx| {
            last_idx = idx;
            search_start = idx + 1;
        }

        const start_idx = last_idx orelse return error.NoContentField;
        const content_start = start_idx + marker.len;

        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

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

        const content = try result.toOwnedSlice(self.allocator);
        var trimmed = std.mem.trim(u8, content, " \t\r\n");

        if (std.mem.startsWith(u8, trimmed, "```")) {
            if (std.mem.indexOf(u8, trimmed, "\n")) |nl| {
                trimmed = trimmed[nl + 1 ..];
            }
            if (std.mem.lastIndexOf(u8, trimmed, "```")) |end| {
                trimmed = trimmed[0..end];
            }
            const clean = try self.allocator.dupe(u8, std.mem.trim(u8, trimmed, " \t\r\n"));
            self.allocator.free(content);
            return clean;
        }

        return content;
    }

    pub fn generateZigCode(self: *Self, user_prompt: []const u8) ![]const u8 {
        const system_prompt =
            \\You are a Zig code generator for the Trinity project.
            \\Generate ONLY valid Zig code, no explanations or markdown.
            \\Always include: const std = @import("std");
            \\Use meaningful variable names.
            \\Follow Zig best practices: const by default, error handling, defer cleanup.
            \\Think step by step before generating code.
        ;
        return self.generate(system_prompt, user_prompt);
    }

    pub fn generateWithReasoning(self: *Self, user_prompt: []const u8, reasoning_context: []const u8) ![]const u8 {
        var system_prompt = std.ArrayListUnmanaged(u8){};
        defer system_prompt.deinit(self.allocator);

        try system_prompt.appendSlice(self.allocator,
            \\You are an expert reasoning assistant for the Trinity project.
            \\Think step by step. Be precise and accurate.
            \\
            \\Context from IGLA symbolic analysis:
            \\
        );
        try system_prompt.appendSlice(self.allocator, reasoning_context);
        try system_prompt.appendSlice(self.allocator,
            \\
            \\Use this context to provide accurate, well-reasoned responses.
            \\For code: generate valid Zig only, no markdown.
            \\For math: show step-by-step proofs.
        );

        return self.generate(system_prompt.items, user_prompt);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("  ANTHROPIC PROVIDER - Claude Reasoning\n", .{});
    std.debug.print("========================================\n", .{});

    var provider = AnthropicProvider.init(allocator);
    defer provider.deinit();

    if (!provider.isConfigured()) {
        std.debug.print("\n[ERROR] ANTHROPIC_API_KEY not set!\n", .{});
        std.debug.print("Get key at: https://console.anthropic.com/\n", .{});
        std.debug.print("Then: export ANTHROPIC_API_KEY=sk-ant-...\n", .{});
        return;
    }

    std.debug.print("\n[ANTHROPIC] Model: {s}\n", .{provider.model});
    std.debug.print("[ANTHROPIC] Generating with reasoning...\n\n", .{});

    const response = provider.generateWithReasoning(
        "Prove that phi^2 + 1/phi^2 = 3 step by step",
        "Task: Mathematical proof\nConcepts: golden ratio, algebra",
    ) catch |err| {
        std.debug.print("[ERROR] Anthropic failed: {any}\n", .{err});
        return;
    };
    defer allocator.free(response);

    std.debug.print("Response:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    std.debug.print("{s}\n", .{response});
    std.debug.print("----------------------------------------\n", .{});
}
