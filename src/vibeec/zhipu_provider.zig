// ============================================================================
// ZHIPU PROVIDER - Chinese LLM (GLM-4)
// ============================================================================
// Uses Zhipu AI API (zhipuai.cn) for Chinese language code generation.
// Best for: Chinese prompts, long context (128K tokens)
// Model: glm-4-flash (fast, free tier available)

const std = @import("std");

pub const ZhipuProvider = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    model: []const u8,
    base_url: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        const api_key = std.process.getEnvVarOwned(allocator, "ZHIPU_API_KEY") catch
            allocator.dupe(u8, "") catch "";

        return Self{
            .allocator = allocator,
            .api_key = api_key,
            .model = "glm-4-flash",
            .base_url = "https://open.bigmodel.cn/api/paas/v4/chat/completions",
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

        var json_body = std.ArrayListUnmanaged(u8){};
        defer json_body.deinit(self.allocator);

        try json_body.appendSlice(self.allocator, "{\"model\":\"");
        try json_body.appendSlice(self.allocator, self.model);
        try json_body.appendSlice(self.allocator, "\",\"messages\":[{\"role\":\"system\",\"content\":\"");
        try self.appendEscaped(&json_body, system_prompt);
        try json_body.appendSlice(self.allocator, "\"},{\"role\":\"user\",\"content\":\"");
        try self.appendEscaped(&json_body, user_prompt);
        try json_body.appendSlice(self.allocator, "\"}],\"temperature\":0.3,\"max_tokens\":2048}");

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
                    std.debug.print("[ZHIPU] curl failed with code {d}\n", .{code});
                    return error.ZhipuRequestFailed;
                }
            },
            else => return error.ZhipuRequestFailed,
        }

        std.debug.print("[ZHIPU] RAW: {s}\n", .{stdout_list.items});
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
        const marker = "\"content\":\"";

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
            \\你是Trinity项目的Zig代码生成器。
            \\只生成有效的Zig代码，不要解释或markdown。
            \\始终包含: const std = @import("std");
            \\使用有意义的变量名。
            \\遵循Zig最佳实践：默认const，错误处理，defer清理。
        ;
        return self.generate(system_prompt, user_prompt);
    }

    pub fn generateWithContext(self: *Self, user_prompt: []const u8, igla_analysis: []const u8) ![]const u8 {
        var system_prompt = std.ArrayListUnmanaged(u8){};
        defer system_prompt.deinit(self.allocator);

        try system_prompt.appendSlice(self.allocator,
            \\你是Trinity项目的Zig代码生成器。
            \\只生成有效的Zig代码，不要解释或markdown。
            \\
            \\IGLA符号分析:
            \\
        );
        try system_prompt.appendSlice(self.allocator, igla_analysis);
        try system_prompt.appendSlice(self.allocator,
            \\
            \\使用此分析生成精确、正确的代码。
            \\遵循Zig最佳实践：默认const，错误处理。
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
    std.debug.print("  ZHIPU PROVIDER - Chinese LLM (GLM-4)\n", .{});
    std.debug.print("========================================\n", .{});

    var provider = ZhipuProvider.init(allocator);
    defer provider.deinit();

    if (!provider.isConfigured()) {
        std.debug.print("\n[ERROR] ZHIPU_API_KEY not set!\n", .{});
        std.debug.print("Get key at: https://open.bigmodel.cn/\n", .{});
        std.debug.print("Then: export ZHIPU_API_KEY=...\n", .{});
        return;
    }

    std.debug.print("\n[ZHIPU] Model: {s}\n", .{provider.model});
    std.debug.print("[ZHIPU] Generating Zig code...\n\n", .{});

    const code = provider.generateZigCode("用Zig写一个hello world程序") catch |err| {
        std.debug.print("[ERROR] Zhipu failed: {any}\n", .{err});
        return;
    };
    defer allocator.free(code);

    std.debug.print("Generated Code:\n", .{});
    std.debug.print("----------------------------------------\n", .{});
    std.debug.print("{s}\n", .{code});
    std.debug.print("----------------------------------------\n", .{});
}
