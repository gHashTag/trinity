// Maxwell Daemon - LLM Client
// Интеграция с LLM API для reasoning
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

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

pub const LLMConfig = struct {
    api_key: []const u8,
    model: []const u8,
    max_tokens: u32,
    temperature: f32,
    base_url: []const u8,

    pub fn claude() LLMConfig {
        return LLMConfig{
            .api_key = "",
            .model = "claude-3-opus-20240229",
            .max_tokens = 4096,
            .temperature = 0.7,
            .base_url = "https://api.anthropic.com/v1",
        };
    }

    pub fn openai() LLMConfig {
        return LLMConfig{
            .api_key = "",
            .model = "gpt-4-turbo-preview",
            .max_tokens = 4096,
            .temperature = 0.7,
            .base_url = "https://api.openai.com/v1",
        };
    }
};

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
    // API CALL (MOCK)
    // ═══════════════════════════════════════════════════════════════════════════

    fn callAPI(self: *LLMClient) !LLMResponse {
        // TODO: Implement actual HTTP call to LLM API
        // For now, return a mock response

        _ = self;

        // Mock response for testing
        return LLMResponse{
            .content = "name: generated_module\nversion: \"1.0.0\"\nlanguage: zig\nmodule: generated_module\n\ntypes:\n  Result:\n    fields:\n      value: Int\n\nbehaviors:\n  - name: process\n    given: Input\n    when: Called\n    then: Returns Result",
            .tokens_used = 100,
            .model = "mock",
            .finish_reason = "stop",
        };
    }

    // Real API call would look like this:
    // fn callAPIReal(self: *LLMClient) !LLMResponse {
    //     var client = std.http.Client{ .allocator = self.allocator };
    //     defer client.deinit();
    //
    //     const uri = std.Uri.parse(self.config.base_url ++ "/messages") catch unreachable;
    //     var request = try client.request(.POST, uri, .{}, .{});
    //     defer request.deinit();
    //
    //     // Set headers
    //     request.headers.append("Content-Type", "application/json");
    //     request.headers.append("x-api-key", self.config.api_key);
    //
    //     // Build request body
    //     // ...
    //
    //     try request.wait();
    //     const body = try request.reader().readAllAlloc(self.allocator, 1024 * 1024);
    //
    //     // Parse response
    //     // ...
    // }
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
