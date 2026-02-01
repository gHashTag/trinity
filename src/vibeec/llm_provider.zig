const std = @import("std");

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const CompletionOptions = struct {
    model: []const u8,
    temperature: f32 = 0.7,
    max_tokens: u32 = 4096,
};

pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    base_url: []const u8,

    pub fn init(allocator: std.mem.Allocator, api_key: []const u8, base_url: []const u8) LLMClient {
        return LLMClient{
            .allocator = allocator,
            .api_key = api_key,
            .base_url = base_url,
        };
    }

    pub fn deinit(self: *LLMClient) void {
        _ = self;
    }

    pub fn chat(self: *LLMClient, messages: []const Message, options: CompletionOptions) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        const Payload = struct {
            model: []const u8,
            messages: []const Message,
            temperature: f32,
            max_tokens: u32,
            stream: bool = false,
        };

        const payload = Payload{
            .model = options.model,
            .messages = messages,
            .temperature = options.temperature,
            .max_tokens = options.max_tokens,
        };

        const json_body = try std.fmt.allocPrint(arena_allocator, "{f}", .{std.json.fmt(payload, .{})});

        // Write payload to temp file
        const cwd = std.fs.cwd();
        const req_file_name = "llm_request.json";
        const req_file = try cwd.createFile(req_file_name, .{});
        try req_file.writeAll(json_body);
        req_file.close();

        const auth_header = try std.fmt.allocPrint(arena_allocator, "Authorization: Bearer {s}", .{self.api_key});

        // Execute curl
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "curl", "-s", "-X", "POST", self.base_url, "-H", "Content-Type: application/json", "-H", auth_header, "-d", "@llm_request.json" },
        });

        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("CURL Error: {s}\n", .{result.stderr});
            return error.ApiRequestFailed;
        }

        const response_body = try self.allocator.dupe(u8, result.stdout);
        errdefer self.allocator.free(response_body);

        // Parse Response
        const ResponseRoot = struct {
            // Optional because error response might NOT satisfy it
            choices: ?[]struct {
                message: struct {
                    content: []const u8,
                },
            } = null,
            // Handle error response from API
            @"error": ?struct {
                message: []const u8,
                code: ?[]const u8,
            } = null,
        };

        const unique_alloc = self.allocator;

        var parse_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer parse_arena.deinit();

        const parsed = try std.json.parseFromSlice(ResponseRoot, parse_arena.allocator(), response_body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        if (parsed.value.@"error") |err| {
            std.debug.print("API Error: {s}\n", .{err.message});
            return error.ApiReturnedError;
        }

        if (parsed.value.choices) |choices| {
            if (choices.len == 0) {
                std.debug.print("Response empty: {s}\n", .{response_body});
                return error.NoChoicesReturned;
            }
            const content = try unique_alloc.dupe(u8, choices[0].message.content);
            self.allocator.free(response_body);
            return content;
        } else {
            std.debug.print("Response format invalid (no choices or error): {s}\n", .{response_body});
            return error.NoChoicesReturned;
        }
    }
};
