// Maxwell Daemon - LLM Client
// Интеграция с LLM API для reasoning
//
// IMPLEMENTATION STATUS:
// - GLM (z.ai): IMPLEMENTED (working)
// - Claude: NOT IMPLEMENTED (returns error)
// - OpenAI: NOT IMPLEMENTED (returns error)
//
// WARNING: If no API key is provided, returns MOCK response (not real LLM!)
//
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const http = std.http;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const Message = struct {
    role: Role,
    content: []const u8,

    pub const Role = enum {
        System,
        User,
        Assistant,

        pub fn toString(self: Role) []const u8 {
            return switch (self) {
                .System => "system",
                .User => "user",
                .Assistant => "assistant",
            };
        }
    };
};

pub const LLMResponse = struct {
    content: []const u8,
    tokens_used: u32,
    model: []const u8,
    finish_reason: []const u8,
};

pub const LLMProvider = enum {
    GLM, // z.ai GLM-4
    Claude, // Anthropic Claude
    OpenAI, // OpenAI GPT-4
};

pub const LLMConfig = struct {
    provider: LLMProvider,
    api_key: []const u8,
    model: []const u8,
    max_tokens: u32,
    temperature: f32,
    base_url: []const u8,

    pub fn glm() LLMConfig {
        return LLMConfig{
            .provider = .GLM,
            .api_key = "",
            .model = "glm-4-flash", // Free tier model
            .max_tokens = 4096,
            .temperature = 0.7,
            .base_url = "https://open.bigmodel.cn/api/paas/v4",
        };
    }

    pub fn claude() LLMConfig {
        return LLMConfig{
            .provider = .Claude,
            .api_key = "",
            .model = "claude-3-opus-20240229",
            .max_tokens = 4096,
            .temperature = 0.7,
            .base_url = "https://api.anthropic.com/v1",
        };
    }

    pub fn openai() LLMConfig {
        return LLMConfig{
            .provider = .OpenAI,
            .api_key = "",
            .model = "gpt-4-turbo-preview",
            .max_tokens = 4096,
            .temperature = 0.7,
            .base_url = "https://api.openai.com/v1",
        };
    }

    /// Load API key from environment variable
    pub fn loadFromEnv(self: *LLMConfig, allocator: std.mem.Allocator) !void {
        const env_var = switch (self.provider) {
            .GLM => "GLM_API_KEY",
            .Claude => "ANTHROPIC_API_KEY",
            .OpenAI => "OPENAI_API_KEY",
        };

        if (std.posix.getenv(env_var)) |key| {
            self.api_key = try allocator.dupe(u8, key);
        }

        // Also try to load from .env file
        if (self.api_key.len == 0) {
            self.api_key = try loadEnvFile(allocator, env_var);
        }
    }
};

/// Load a value from .env file
fn loadEnvFile(allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
    const file = std.fs.cwd().openFile(".env", .{}) catch return "";
    defer file.close();

    var buf: [4096]u8 = undefined;
    const bytes_read = file.readAll(&buf) catch return "";
    const content = buf[0..bytes_read];

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
            const var_name = trimmed[0..eq_pos];
            if (std.mem.eql(u8, var_name, key)) {
                const value = trimmed[eq_pos + 1 ..];
                return try allocator.dupe(u8, value);
            }
        }
    }

    return "";
}

// ═══════════════════════════════════════════════════════════════════════════════
// LLM CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    config: LLMConfig,
    conversation: std.ArrayList(Message),

    // System prompt for Maxwell
    const MAXWELL_SYSTEM_PROMPT =
        \\You are Maxwell, an autonomous coding agent. Your role is to:
        \\1. Analyze code and understand its structure
        \\2. Generate .vibee specifications for new features
        \\3. Fix bugs and improve code quality
        \\4. Write tests and documentation
        \\
        \\IMPORTANT RULES:
        \\- Always generate .vibee specifications, NEVER write code directly
        \\- Follow the Golden Chain development cycle
        \\- Be precise and minimal in your responses
        \\- When generating specs, use proper YAML format
        \\
        \\φ² + 1/φ² = 3 = TRINITY
    ;

    pub fn init(allocator: std.mem.Allocator, config: LLMConfig) LLMClient {
        var client = LLMClient{
            .allocator = allocator,
            .config = config,
            .conversation = std.ArrayList(Message).init(allocator),
        };

        // Add system prompt
        client.conversation.append(Message{
            .role = .System,
            .content = MAXWELL_SYSTEM_PROMPT,
        }) catch {};

        return client;
    }

    pub fn deinit(self: *LLMClient) void {
        self.conversation.deinit();
    }

    /// Отправить сообщение и получить ответ
    pub fn chat(self: *LLMClient, user_message: []const u8) !LLMResponse {
        // Add user message to conversation
        try self.conversation.append(Message{
            .role = .User,
            .content = user_message,
        });

        // Make API call
        const response = try self.callAPI();

        // Add assistant response to conversation
        try self.conversation.append(Message{
            .role = .Assistant,
            .content = response.content,
        });

        return response;
    }

    /// Сгенерировать .vibee спецификацию
    pub fn generateSpec(self: *LLMClient, task_description: []const u8, context: []const u8) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();

        const writer = prompt.writer();
        try writer.writeAll("Generate a .vibee specification for the following task:\n\n");
        try writer.writeAll("TASK: ");
        try writer.writeAll(task_description);
        try writer.writeAll("\n\nCONTEXT:\n");
        try writer.writeAll(context);
        try writer.writeAll("\n\nGenerate ONLY the .vibee specification in YAML format. No explanations.");

        const response = try self.chat(prompt.items);
        return response.content;
    }

    /// Проанализировать ошибку и предложить исправление
    pub fn analyzeError(self: *LLMClient, error_message: []const u8, code_context: []const u8) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();

        const writer = prompt.writer();
        try writer.writeAll("Analyze this error and suggest a fix:\n\n");
        try writer.writeAll("ERROR:\n");
        try writer.writeAll(error_message);
        try writer.writeAll("\n\nCODE CONTEXT:\n");
        try writer.writeAll(code_context);
        try writer.writeAll("\n\nProvide a concise fix. If code changes are needed, generate a .vibee spec.");

        const response = try self.chat(prompt.items);
        return response.content;
    }

    /// Декомпозировать задачу на подзадачи
    pub fn decomposeTask(self: *LLMClient, task_description: []const u8) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();

        const writer = prompt.writer();
        try writer.writeAll("Decompose this task into smaller subtasks:\n\n");
        try writer.writeAll("TASK: ");
        try writer.writeAll(task_description);
        try writer.writeAll("\n\nList subtasks in order of execution. Format:\n");
        try writer.writeAll("1. [subtask]\n2. [subtask]\n...");

        const response = try self.chat(prompt.items);
        return response.content;
    }

    /// Очистить историю разговора
    pub fn clearHistory(self: *LLMClient) void {
        self.conversation.clearRetainingCapacity();
        self.conversation.append(Message{
            .role = .System,
            .content = MAXWELL_SYSTEM_PROMPT,
        }) catch {};
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // API CALL
    // ═══════════════════════════════════════════════════════════════════════════

    fn callAPI(self: *LLMClient) !LLMResponse {
        // Check if we have an API key
        if (self.config.api_key.len == 0) {
            std.debug.print("[LLM] WARNING: No API key provided! Returning MOCK response (not real LLM!)\n", .{});
            return self.mockResponse();
        }

        // Try real API - DO NOT silently fall back to mock!
        const result = switch (self.config.provider) {
            .GLM => self.callGLMAPI() catch |err| {
                std.debug.print("[LLM] GLM API error: {s}\n", .{@errorName(err)});
                return err;
            },
            .Claude => {
                std.debug.print("[LLM] ERROR: Claude API is NOT IMPLEMENTED! Use GLM provider instead.\n", .{});
                return error.NotImplemented;
            },
            .OpenAI => {
                std.debug.print("[LLM] ERROR: OpenAI API is NOT IMPLEMENTED! Use GLM provider instead.\n", .{});
                return error.NotImplemented;
            },
        };

        return result;
    }

    /// Mock response for testing without API key
    /// WARNING: This is NOT a real LLM response! It's a hardcoded template for testing only.
    fn mockResponse(self: *LLMClient) LLMResponse {
        _ = self;
        return LLMResponse{
            // MOCK: This is a hardcoded response, NOT generated by any LLM!
            .content = "# MOCK RESPONSE - NOT REAL LLM!\n# Set GLM_API_KEY environment variable for real responses.\n\nname: generated_module\nversion: \"1.0.0\"\nlanguage: zig\nmodule: generated_module\n\ntypes:\n  Result:\n    fields:\n      value: Int\n\nbehaviors:\n  - name: process\n    given: Input\n    when: Called\n    then: Returns Result",
            .tokens_used = 0, // 0 because no real API call was made
            .model = "MOCK_NOT_REAL_LLM",
            .finish_reason = "mock",
        };
    }

    /// Call GLM API (z.ai)
    fn callGLMAPI(self: *LLMClient) !LLMResponse {
        // Build request body
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const writer = body.writer();
        try writer.writeAll("{\"model\":\"");
        try writer.writeAll(self.config.model);
        try writer.writeAll("\",\"messages\":[");

        for (self.conversation.items, 0..) |msg, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("{\"role\":\"");
            try writer.writeAll(msg.role.toString());
            try writer.writeAll("\",\"content\":\"");
            // Escape content
            for (msg.content) |c| {
                switch (c) {
                    '"' => try writer.writeAll("\\\""),
                    '\\' => try writer.writeAll("\\\\"),
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeAll("\"}");
        }

        try writer.writeAll("],\"max_tokens\":");
        try writer.print("{d}", .{self.config.max_tokens});
        try writer.writeAll(",\"temperature\":");
        try writer.print("{d:.1}", .{self.config.temperature});
        try writer.writeAll("}");

        // Make HTTP request using curl (Zig's HTTP client has issues with HTTPS)
        const result = try self.curlRequest(
            self.config.base_url,
            "/chat/completions",
            body.items,
            self.config.api_key,
        );

        return result;
    }

    /// Call Claude API
    fn callClaudeAPI(self: *LLMClient) !LLMResponse {
        // Similar to GLM but with Anthropic's format
        _ = self;
        return error.NotImplemented;
    }

    /// Call OpenAI API
    fn callOpenAIAPI(self: *LLMClient) !LLMResponse {
        // Similar to GLM but with OpenAI's format
        _ = self;
        return error.NotImplemented;
    }

    /// Generate JWT token for Zhipu API
    fn generateZhipuJWT(self: *LLMClient, api_key: []const u8) ![]const u8 {
        // Zhipu API key format: {id}.{secret}
        // We need to generate a JWT with the id and sign with secret

        const dot_pos = std.mem.indexOf(u8, api_key, ".") orelse return error.InvalidApiKey;
        const api_id = api_key[0..dot_pos];
        const api_secret = api_key[dot_pos + 1 ..];

        // For simplicity, use the raw API key as Bearer token
        // Zhipu also accepts this format for some endpoints
        _ = api_id;
        _ = api_secret;

        return try self.allocator.dupe(u8, api_key);
    }

    /// Make HTTP request using curl (more reliable for HTTPS)
    fn curlRequest(self: *LLMClient, base_url: []const u8, endpoint: []const u8, body: []const u8, api_key: []const u8) !LLMResponse {
        // Build URL
        var url_buf: [512]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ base_url, endpoint });

        // For Zhipu, we might need JWT, but try Bearer first
        var auth_buf: [512]u8 = undefined;
        const auth_header = try std.fmt.bufPrint(&auth_buf, "Authorization: Bearer {s}", .{api_key});

        // Write body to temp file
        const tmp_file = "/tmp/maxwell_request.json";
        {
            const file = try std.fs.cwd().createFile(tmp_file, .{});
            defer file.close();
            try file.writeAll(body);
        }

        // Run curl
        var child = std.process.Child.init(&[_][]const u8{
            "curl",
            "-s",
            "-X",
            "POST",
            url,
            "-H",
            "Content-Type: application/json",
            "-H",
            auth_header,
            "-d",
            "@" ++ tmp_file,
        }, self.allocator);

        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        const stdout = try child.stdout.?.reader().readAllAlloc(self.allocator, 1024 * 1024);
        _ = try child.stderr.?.reader().readAllAlloc(self.allocator, 1024 * 1024);

        const term = try child.wait();
        if (term.Exited != 0) {
            return error.CurlFailed;
        }

        // Parse JSON response
        return self.parseGLMResponse(stdout);
    }

    /// Parse GLM API response
    fn parseGLMResponse(self: *LLMClient, json: []const u8) !LLMResponse {
        // Simple JSON parsing for GLM response format:
        // {"choices":[{"message":{"content":"..."}}],"usage":{"total_tokens":N}}

        // Find content
        const content_start = std.mem.indexOf(u8, json, "\"content\":\"") orelse return error.InvalidResponse;
        const content_begin = content_start + 11;

        var content_end = content_begin;
        var escape = false;
        while (content_end < json.len) {
            if (escape) {
                escape = false;
            } else if (json[content_end] == '\\') {
                escape = true;
            } else if (json[content_end] == '"') {
                break;
            }
            content_end += 1;
        }

        const raw_content = json[content_begin..content_end];

        // Unescape content
        var content = std.ArrayList(u8).init(self.allocator);
        var i: usize = 0;
        while (i < raw_content.len) {
            if (raw_content[i] == '\\' and i + 1 < raw_content.len) {
                switch (raw_content[i + 1]) {
                    'n' => try content.append('\n'),
                    'r' => try content.append('\r'),
                    't' => try content.append('\t'),
                    '"' => try content.append('"'),
                    '\\' => try content.append('\\'),
                    else => {
                        try content.append(raw_content[i]);
                        try content.append(raw_content[i + 1]);
                    },
                }
                i += 2;
            } else {
                try content.append(raw_content[i]);
                i += 1;
            }
        }

        // Find tokens
        var tokens: u32 = 0;
        if (std.mem.indexOf(u8, json, "\"total_tokens\":")) |tok_start| {
            const num_start = tok_start + 15;
            var num_end = num_start;
            while (num_end < json.len and json[num_end] >= '0' and json[num_end] <= '9') {
                num_end += 1;
            }
            tokens = std.fmt.parseInt(u32, json[num_start..num_end], 10) catch 0;
        }

        return LLMResponse{
            .content = try content.toOwnedSlice(),
            .tokens_used = tokens,
            .model = self.config.model,
            .finish_reason = "stop",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "LLMClient init and deinit" {
    const config = LLMConfig.claude();
    var client = LLMClient.init(std.testing.allocator, config);
    defer client.deinit();

    try std.testing.expectEqual(@as(usize, 1), client.conversation.items.len);
}

test "LLMClient chat mock" {
    const config = LLMConfig.claude();
    var client = LLMClient.init(std.testing.allocator, config);
    defer client.deinit();

    const response = try client.chat("Hello");
    try std.testing.expect(response.content.len > 0);
    try std.testing.expectEqual(@as(usize, 3), client.conversation.items.len);
}
