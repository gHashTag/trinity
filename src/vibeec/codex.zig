// VIBEEC CODEX — Первосвященный Скриб
// CLI инструмент для автономной генерации и исправления кода WITH REAL SOUL
// Фаза 1: Писец (The Scribe)
// Фаза 2: Архитектор (The Architect)
// Фаза 3: Строитель (The Builder)
// Фаза 4: Душа (The Soul - LLM Integration)

const std = @import("std");
const llm = @import("llm_provider.zig");

// ============================================================================
// CONFIGURATION MANAGEMENT
// ============================================================================

pub const Config = struct {
    api_key: []const u8,
    base_url: []const u8,
    model: []const u8,

    pub fn deinit(self: Config, allocator: std.mem.Allocator) void {
        // All strings in Config are now guaranteed to be allocated by `allocator`
        // due to the changes in `load()`.
        allocator.free(self.api_key);
        allocator.free(self.base_url);
        allocator.free(self.model);
    }

    pub fn load(allocator: std.mem.Allocator) !Config {
        // 1. Start with Defaults (Static Literals)
        const default_config = Config.default();

        // We need to duplicate defaults so we can free them uniformly later.
        // Let's DUP defaults immediately to ensure uniform ownership.
        var api_key_owned = try allocator.dupe(u8, default_config.api_key);
        var base_url_owned = try allocator.dupe(u8, default_config.base_url);
        var model_owned = try allocator.dupe(u8, default_config.model);

        // 2. Try Config File (JSON)
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch null;
        if (home) |h| {
            defer allocator.free(h);
            const config_path = try std.fs.path.join(allocator, &[_][]const u8{ h, ".vibeec", "config.json" });
            defer allocator.free(config_path);

            if (std.fs.cwd().openFile(config_path, .{})) |file| {
                defer file.close();
                if (file.readToEndAlloc(allocator, 1024 * 1024)) |content| {
                    defer allocator.free(content);

                    const ParsedConfig = struct {
                        api_key: []const u8,
                        base_url: []const u8 = "https://api.z.ai/api/paas/v4/chat/completions",
                        model: []const u8 = "glm-4.7",
                    };

                    var arena = std.heap.ArenaAllocator.init(allocator);
                    defer arena.deinit();

                    if (std.json.parseFromSlice(ParsedConfig, arena.allocator(), content, .{ .ignore_unknown_fields = true })) |parsed| {
                        // Free old defaults before overwriting
                        allocator.free(api_key_owned);
                        allocator.free(base_url_owned);
                        allocator.free(model_owned);

                        api_key_owned = try allocator.dupe(u8, parsed.value.api_key);
                        base_url_owned = try allocator.dupe(u8, parsed.value.base_url);
                        model_owned = try allocator.dupe(u8, parsed.value.model);
                    } else |_| {}
                } else |_| {}
            } else |_| {}
        }

        // 3. Try Environment Variables (Highest Priority)
        // We use process.getEnvVarOwned which uses allocator.
        // We assign directly after freeing the previous owned value.
        if (std.process.getEnvVarOwned(allocator, "VIBEEC_API_KEY")) |env_key| {
            allocator.free(api_key_owned);
            api_key_owned = env_key;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "VIBEEC_MODEL")) |env_model| {
            allocator.free(model_owned);
            model_owned = env_model;
        } else |_| {}

        if (std.process.getEnvVarOwned(allocator, "VIBEEC_BASE_URL")) |env_url| {
            allocator.free(base_url_owned);
            base_url_owned = env_url;
        } else |_| {}

        return Config{
            .api_key = api_key_owned,
            .base_url = base_url_owned,
            .model = model_owned,
        };
    }

    pub fn save(allocator: std.mem.Allocator, new_api_key: ?[]const u8, new_model: ?[]const u8, new_base_url: ?[]const u8) !void {
        const home = try std.process.getEnvVarOwned(allocator, "HOME");
        defer allocator.free(home);

        const dir_path = try std.fs.path.join(allocator, &[_][]const u8{ home, ".vibeec" });
        defer allocator.free(dir_path);

        std.fs.cwd().makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };

        const config_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, "config.json" });
        defer allocator.free(config_path);

        // Load existing to preserve values
        const current = Config.load(allocator) catch blk: {
            // If load fails, we still need owned strings/struct for consistency or a default
            // default() returns literals. load() handles duping.
            // We can just call load with fresh state? NO.
            // Let's make load() handle failure by retrying default logic.
            // Current logic: Config.default() returns literals.
            // If load fails, we need to manually create a Config with owned strings from default().
            const def = Config.default();
            break :blk Config{
                .api_key = try allocator.dupe(u8, def.api_key),
                .base_url = try allocator.dupe(u8, def.base_url),
                .model = try allocator.dupe(u8, def.model),
            };
        };
        defer current.deinit(allocator);

        // Update fields if provided
        var final_key = current.api_key;
        if (new_api_key) |k| final_key = k;

        var final_model = current.model;
        if (new_model) |m| final_model = m;

        var final_url = current.base_url;
        if (new_base_url) |u| final_url = u;

        const JsonConfig = struct {
            api_key: []const u8,
            base_url: []const u8,
            model: []const u8,
        };

        const cfg = JsonConfig{
            .api_key = final_key,
            .base_url = final_url,
            .model = final_model,
        };

        const file = try std.fs.cwd().createFile(config_path, .{});
        defer file.close();

        // Use {f} for formatter logic
        const json_str = try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(cfg, .{ .whitespace = .indent_2 })});
        defer allocator.free(json_str);
        try file.writeAll(json_str);
    }

    fn default() Config {
        // ⚠️ FALLBACK ONLY: This is used ONLY if ~/.vibeec/config.json is missing AND env vars are unset.
        // Real keys are loaded from disk or VIBEEC_API_KEY. Do not commit real keys here!
        return Config{
            .api_key = "mock_key",
            .base_url = "https://api.z.ai/api/paas/v4/chat/completions",
            .model = "glm-4.7",
        };
    }

    pub fn isMock(self: Config) bool {
        return std.mem.eql(u8, self.api_key, "mock_key");
    }
};

// ============================================================================
// CONTEXT SCANNER (THE ARCHITECT)
// ============================================================================

pub const Architect = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Architect {
        return Architect{ .allocator = allocator };
    }

    pub fn scanProject(self: *Architect, root_path: []const u8) ![]const u8 {
        var context = std.ArrayListUnmanaged(u8){};
        defer context.deinit(self.allocator);

        try context.appendSlice(self.allocator, "Project Context:\n");

        var dir = std.fs.cwd().openDir(root_path, .{ .iterate = true }) catch {
            return try self.allocator.dupe(u8, "Error opening root dir.");
        };
        defer dir.close();

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        var file_count: u32 = 0;
        while (try walker.next()) |entry| {
            if (file_count > 500) break;
            if (std.mem.indexOf(u8, entry.path, ".git") != null) continue;
            if (std.mem.indexOf(u8, entry.path, "zig-cache") != null) continue;
            if (std.mem.indexOf(u8, entry.path, "temp_generated") != null) continue;
            if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

            try context.appendSlice(self.allocator, "- ");
            try context.appendSlice(self.allocator, entry.path);
            try context.appendSlice(self.allocator, ":\n```zig\n");

            if (dir.readFileAlloc(self.allocator, entry.path, 50 * 1024)) |content| {
                defer self.allocator.free(content);
                try context.appendSlice(self.allocator, content);
            } else |_| {
                try context.appendSlice(self.allocator, "// Error reading file content");
            }
            try context.appendSlice(self.allocator, "\n```\n\n");

            file_count += 1;
        }
        return context.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// SCRIBE (LLM INTERFACE)
// ============================================================================

pub const Scribe = struct {
    config: Config,
    allocator: std.mem.Allocator,
    llm_client: llm.LLMClient,

    pub fn init(allocator: std.mem.Allocator, config: Config) Scribe {
        return Scribe{
            .config = config,
            .allocator = allocator,
            .llm_client = llm.LLMClient.init(allocator, config.api_key, config.base_url),
        };
    }

    pub fn deinit(self: *Scribe) void {
        self.llm_client.deinit();
    }

    pub fn generateCode(self: *Scribe, prompt: []const u8, context: []const u8) ![]const u8 {
        if (self.config.isMock()) {
            std.debug.print("📜 [Scribe] Using Mock (No API Key found). Set key with `config set api_key`\n", .{});
            if (std.mem.indexOf(u8, prompt, "buggy") != null) return "error";
            return 
            \\const std = @import("std");
            \\pub fn main() void {
            \\    std.debug.print("Hello Mock World\n", .{});
            \\}
            ;
        }

        std.debug.print("📜 [Scribe] Sending prompt to {s}...\n", .{self.config.model});

        // Prepare User Content
        var user_content = std.ArrayListUnmanaged(u8){};
        defer user_content.deinit(self.allocator);
        try user_content.appendSlice(self.allocator, "Context:\n");
        try user_content.appendSlice(self.allocator, context);
        try user_content.appendSlice(self.allocator, "\nTask: ");
        try user_content.appendSlice(self.allocator, prompt);

        const system_prompt = "You are Vibeec Codex, an expert Zig programmer. Provide ONLY the Zig code block in your response. No explanation.";

        var messages_arr = try self.createChatRequest(system_prompt, user_content.items);
        defer messages_arr.deinit(self.allocator);

        const response_content = try self.llm_client.chat(messages_arr.items, .{
            .model = self.config.model,
        });

        return cleanCode(self.allocator, response_content);
    }

    pub fn fixCode(self: *Scribe, code: []const u8, errors: []const u8) ![]const u8 {
        if (self.config.isMock()) return code;

        std.debug.print("🚑 [Scribe] Requesting fix from LLM...\n", .{});

        var prompt = std.ArrayListUnmanaged(u8){};
        defer prompt.deinit(self.allocator);
        try prompt.writer(self.allocator).print("Code:\n```zig\n{s}\n```\nErrors:\n{s}\n", .{ code, errors });

        const system_prompt = "Fix the Zig code based on the compiler errors. Return ONLY the fixed code.";

        var messages_arr = try self.createChatRequest(system_prompt, prompt.items);
        defer messages_arr.deinit(self.allocator);

        const response = try self.llm_client.chat(messages_arr.items, .{ .model = self.config.model });
        return cleanCode(self.allocator, response);
    }

    fn createChatRequest(self: *Scribe, system_prompt: []const u8, user_prompt: []const u8) !std.ArrayListUnmanaged(llm.Message) {
        var messages = std.ArrayListUnmanaged(llm.Message){};

        try messages.append(self.allocator, .{
            .role = "system",
            .content = system_prompt, // Literal, no ownership issues for now if static
        });

        try messages.append(self.allocator, .{
            .role = "user",
            .content = user_prompt, // Caller owns this memory
        });

        return messages;
    }

    fn cleanCode(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
        const start_marker = "```zig";
        const end_marker = "```";

        const start = std.mem.indexOf(u8, content, start_marker);
        if (start) |s| {
            const code_start = s + start_marker.len;
            const end = std.mem.indexOf(u8, content[code_start..], end_marker);
            if (end) |e| {
                const raw = content[code_start..][0..e];
                return try allocator.dupe(u8, std.mem.trim(u8, raw, " \n\r"));
            }
        }
        return try allocator.dupe(u8, content);
    }
};

// ============================================================================
// BUILDER
// ============================================================================

pub const Builder = struct {
    allocator: std.mem.Allocator,
    scribe: *Scribe,

    pub fn init(allocator: std.mem.Allocator, scribe: *Scribe) Builder {
        return Builder{ .allocator = allocator, .scribe = scribe };
    }

    pub fn compileAndFix(self: *Builder, initial_code: []const u8) ![]const u8 {
        var current_code: []const u8 = try self.allocator.dupe(u8, initial_code);
        const max_retries = 3;
        var attempt: u32 = 0;

        while (attempt < max_retries) : (attempt += 1) {
            std.debug.print("🔨 [Builder] Compilation Attempt {d}/{d}...\n", .{ attempt + 1, max_retries });

            const temp_file_name = "temp_generated.zig";
            const file = try std.fs.cwd().createFile(temp_file_name, .{});
            try file.writeAll(current_code);
            file.close();

            const result = try std.process.Child.run(.{
                .allocator = self.allocator,
                .argv = &[_][]const u8{ "zig", "build-obj", temp_file_name },
            });
            defer self.allocator.free(result.stdout);
            defer self.allocator.free(result.stderr);

            if (result.term.Exited == 0) {
                std.debug.print("✅ [Builder] Compilation Success!\n", .{});
                return current_code;
            } else {
                std.debug.print("❌ [Builder] Compilation Failed (Code {d})\n", .{result.term.Exited});
                const new_code = try self.scribe.fixCode(current_code, result.stderr);
                self.allocator.free(current_code);
                current_code = new_code;
            }
        }
        return error.CompilationFailedAfterRetries;
    }
};

// ============================================================================
// MAIN
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage:\n  vibeec-codex config set api_key <KEY>\n  vibeec-codex <prompt>\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[1], "config") and args.len >= 5) {
        if (std.mem.eql(u8, args[2], "set")) {
            if (std.mem.eql(u8, args[3], "api_key")) {
                const key = args[4];
                try Config.save(allocator, key, null, null);
                std.debug.print("✅ API Key saved to ~/.vibeec/config.json\n", .{});
                return;
            }
            if (std.mem.eql(u8, args[3], "model")) {
                const model = args[4];
                try Config.save(allocator, null, model, null);
                std.debug.print("✅ Model saved to ~/.vibeec/config.json: {s}\n", .{model});
                return;
            }
            if (std.mem.eql(u8, args[3], "base_url")) {
                const url = args[4];
                try Config.save(allocator, null, null, url);
                std.debug.print("✅ Base URL saved to ~/.vibeec/config.json: {s}\n", .{url});
                return;
            }
        }
    }

    var prompt_list = std.ArrayListUnmanaged(u8){};
    defer prompt_list.deinit(allocator);
    for (args[1..]) |arg| {
        try prompt_list.appendSlice(allocator, arg);
        try prompt_list.append(allocator, ' ');
    }
    const prompt = try prompt_list.toOwnedSlice(allocator);
    defer allocator.free(prompt);

    const config = try Config.load(allocator);
    defer config.deinit(allocator);

    var scribe = Scribe.init(allocator, config);
    defer scribe.deinit();

    var architect = Architect.init(allocator);
    var builder = Builder.init(allocator, &scribe);

    std.debug.print("\n🤖 Vibeec Codex (Phase 4: Soul)\n", .{});
    std.debug.print("-------------------------------\n", .{});

    if (config.isMock()) {
        std.debug.print("⚠️  Running in Mock Mode. Set API key to unleash full power.\n\n", .{});
    }

    const context = try architect.scanProject(".");
    defer allocator.free(context);

    // Initial code generation
    const initial_code = try scribe.generateCode(prompt, context);

    // Compile and fix loop
    const final_code = try builder.compileAndFix(initial_code);
    defer allocator.free(final_code);

    std.debug.print("\nFinal Code:\n```zig\n{s}\n```\n", .{final_code});
    std.debug.print("\n✅ Process Complete.\n", .{});
}
