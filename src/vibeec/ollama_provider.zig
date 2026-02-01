const std = @import("std");

// ============================================================================
// OLLAMA PROVIDER - THE PROFANE SPIRIT
// ============================================================================
// Summons the external spirit (Ollama LLM) to generate code.
// Uses CLI invocation for simplicity and reliability.

pub const OllamaProvider = struct {
    allocator: std.mem.Allocator,
    model: []const u8,

    pub fn init(allocator: std.mem.Allocator) OllamaProvider {
        return OllamaProvider{
            .allocator = allocator,
            .model = "qwen2.5-coder:7b",
        };
    }

    /// Summon the spirit to generate code via CLI
    pub fn generate(self: *OllamaProvider, prompt: []const u8) ![]const u8 {
        // Build the command
        const argv = [_][]const u8{ "ollama", "run", self.model, prompt };

        var child = std.process.Child.init(&argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        // Collect output using Zig 0.15 API with ArrayListUnmanaged
        var stdout_list = std.ArrayListUnmanaged(u8){};
        defer stdout_list.deinit(self.allocator);
        var stderr_list = std.ArrayListUnmanaged(u8){};
        defer stderr_list.deinit(self.allocator);

        try child.collectOutput(self.allocator, &stdout_list, &stderr_list, 10 * 1024 * 1024);

        const term = try child.wait();

        // Check exit status
        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    return error.OllamaFailed;
                }
            },
            else => return error.OllamaFailed,
        }

        // Return owned copy of stdout
        return try self.allocator.dupe(u8, stdout_list.items);
    }

    /// Generate Zig code with system prompt
    pub fn generateZigCode(self: *OllamaProvider, user_prompt: []const u8, penance: ?[]const u8) ![]const u8 {
        var full_prompt = std.ArrayListUnmanaged(u8){};
        defer full_prompt.deinit(self.allocator);

        // System instruction
        try full_prompt.appendSlice(self.allocator, "You are a Zig code generator. Generate ONLY valid Zig code, no explanations.\n" ++
            "Always include: const std = @import(\"std\"); and pub fn main() void { ... }\n" ++
            "Use meaningful variable names.\n\n");

        // Add penance if provided
        if (penance) |p| {
            try full_prompt.appendSlice(self.allocator, "CORRECTIONS REQUIRED:\n");
            try full_prompt.appendSlice(self.allocator, p);
            try full_prompt.appendSlice(self.allocator, "\n\n");
        }

        try full_prompt.appendSlice(self.allocator, "Generate Zig code for: ");
        try full_prompt.appendSlice(self.allocator, user_prompt);
        try full_prompt.appendSlice(self.allocator, "\n\nRespond with ONLY the Zig code:");

        return self.generate(full_prompt.items);
    }
};

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("👻 OLLAMA PROVIDER - Summoning the Spirit\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    var provider = OllamaProvider.init(allocator);

    std.debug.print("📡 Calling Ollama ({s})...\n", .{provider.model});

    const response = provider.generateZigCode("print hello world", null) catch |err| {
        std.debug.print("❌ Spirit failed to respond: {any}\n", .{err});
        return;
    };
    defer allocator.free(response);

    std.debug.print("👻 Spirit speaks:\n{s}\n", .{response});
}
