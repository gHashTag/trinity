// ============================================================================
// GROQ PROVIDER - Fast LLM Inference (FREE 227 tok/s)
// ============================================================================
// Uses Groq API (groq.com) for fast fluent code generation.
// Compatible with OpenAI API format.
// Models: llama-3.3-70b-versatile, mixtral-8x7b-32768

const std = @import("std");

pub const GroqProvider = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    model: []const u8,
    base_url: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        // Read API key from environment
        const api_key = std.process.getEnvVarOwned(allocator, "GROQ_API_KEY") catch
            allocator.dupe(u8, "") catch "";

        return Self{
            .allocator = allocator,
            .api_key = api_key,
            .model = "llama-3.3-70b-versatile",
            .base_url = "https://api.groq.com/openai/v1/chat/completions",
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.api_key.len > 0) {
            self.allocator.free(self.api_key);
        }
    }

    /// Check if API key is configured
    pub fn isConfigured(self: *const Self) bool {
        return self.api_key.len > 0;
    }

    /// Generate code using Groq API via curl
    pub fn generate(self: *Self, system_prompt: []const u8, user_prompt: []const u8) ![]const u8 {
        if (!self.isConfigured()) {
            return error.ApiKeyNotConfigured;
        }

        // Build JSON body
        var json_body = std.ArrayListUnmanaged(u8){};
        defer json_body.deinit(self.allocator);

        try json_body.appendSlice(self.allocator, "{\"model\":\"");
        try json_body.appendSlice(self.allocator, self.model);
        try json_body.appendSlice(self.allocator, "\",\"messages\":[{\"role\":\"system\",\"content\":\"");
        try self.appendEscaped(&json_body, system_prompt);
        try json_body.appendSlice(self.allocator, "\"},{\"role\":\"user\",\"content\":\"");
        try self.appendEscaped(&json_body, user_prompt);
        try json_body.appendSlice(self.allocator, "\"}],\"temperature\":0.3,\"max_tokens\":2048}");

        // Build auth header
        var auth_header = std.ArrayListUnmanaged(u8){};
        defer auth_header.deinit(self.allocator);
        try auth_header.appendSlice(self.allocator, "Authorization: Bearer ");
        try auth_header.appendSlice(self.allocator, self.api_key);

        const argv = [_][]const u8{
            "curl", "-s",
            self.base_url,
            "-H", "Content-Type: application/json",
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
                    std.debug.print("[GROQ] curl failed with code {d}\n", .{code});
                    return error.GroqRequestFailed;
                }
            },
            else => return error.GroqRequestFailed,
        }

        return self.extractContent(stdout_list.items);
    }

    /// Append JSON-escaped string
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

    /// Extract content from Groq API response
    fn extractContent(self: *Self, json: []const u8) ![]const u8 {
        const marker = "\"content\":\"";

        // Find last occurrence (assistant message)
        var last_idx: ?usize = null;
        var search_start: usize = 0;
        while (std.mem.indexOfPos(u8, json, search_start, marker)) |idx| {
            last_idx = idx;
            search_start = idx + 1;
        }

        const start_idx = last_idx orelse return error.NoContentField;
        const content_start = start_idx + marker.len;

        // Parse string value
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

        // Strip markdown code blocks if present
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

    /// Generate Zig code with system prompt
    pub fn generateZigCode(self: *Self, user_prompt: []const u8) ![]const u8 {
        const system_prompt =
            \\You are a Zig code generator for the Trinity project.
            \\Generate ONLY valid Zig code, no explanations or markdown.
            \\Always include: const std = @import("std");
            \\Use meaningful variable names.
            \\Follow Zig best practices: const by default, error handling, defer cleanup.
            \\For VSA operations: Trit = i8, bind = multiply, bundle = majority vote.
        ;
        return self.generate(system_prompt, user_prompt);
    }

    /// Generate code with IGLA context (hybrid mode)
    pub fn generateWithContext(self: *Self, user_prompt: []const u8, igla_analysis: []const u8) ![]const u8 {
        var system_prompt = std.ArrayListUnmanaged(u8){};
        defer system_prompt.deinit(self.allocator);

        try system_prompt.appendSlice(self.allocator,
            \\You are a Zig code generator for the Trinity project.
            \\Generate ONLY valid Zig code, no explanations or markdown.
            \\
            \\IGLA Symbolic Analysis:
            \\
        );
        try system_prompt.appendSlice(self.allocator, igla_analysis);
        try system_prompt.appendSlice(self.allocator,
            \\
            \\Use this analysis to generate precise, correct code.
            \\Follow Zig best practices: const by default, error handling.
        );

        return self.generate(system_prompt.items, user_prompt);
    }
};

// ============================================================================
// TEST
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("  GROQ PROVIDER - Fast LLM (227 tok/s)\n", .{});
    std.debug.print("========================================\n", .{});

    var provider = GroqProvider.init(allocator);
    defer provider.deinit();

    if (!provider.isConfigured()) {
        std.debug.print("\n[ERROR] GROQ_API_KEY not set!\n", .{});
        std.debug.print("Get free key at: https://console.groq.com/keys\n", .{});
        std.debug.print("Then: export GROQ_API_KEY=gsk_...\n", .{});
        return;
    }

    std.debug.print("\n[GROQ] Model: {s}\n", .{provider.model});
    std.debug.print("[GROQ] Generating Zig code...\n\n", .{});

    const code = provider.generateZigCode("Write a hello world program in Zig") catch |err| {
        std.debug.print("[ERROR] Groq failed: {any}\n", .{err});
        return;
    };
    defer allocator.free(code);

    std.debug.print("Generated Code:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    std.debug.print("{s}\n", .{code});
    std.debug.print("----------------------------------------\n", .{});
}
