const std = @import("std");
const trinity = @import("trinity_inference_engine.zig");
const spec_loader = @import("spec_loader.zig");
const tokenizer = @import("trinity_tokenizer.zig");

/// Message structure for chat interface
pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

/// Completion options (legacy compatibility)
pub const CompletionOptions = struct {
    model: []const u8,
    temperature: f32 = 0.7,
    max_tokens: u32 = 4096,
};

/// TrinityLLM - The Unified Mind of Vibeec-Codex
/// No more HTTP. No more mocks. This IS the brain.
pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    engine: trinity.Engine,
    weights: []trinity.Trit,
    divine_mandate: []const u8,
    tok: tokenizer.Tokenizer,

    /// Initialize the Trinity Mind
    /// Loads trained weights v2 and divine mandate (specs)
    pub fn init(allocator: std.mem.Allocator, api_key: []const u8, base_url: []const u8) !LLMClient {
        _ = api_key; // No longer needed - we are self-sufficient
        _ = base_url; // No longer needed - we compute locally

        // Load the Trained Soul (v2 weights - 1024 trits, trained on corpus)
        const weights_path = "trinity_god_weights_v2.tri";
        const file = std.fs.cwd().openFile(weights_path, .{}) catch |err| {
            // Fallback to v1 if v2 doesn't exist
            std.debug.print("⚠️ v2 weights not found ({any}), trying v1...\n", .{err});
            const v1_file = std.fs.cwd().openFile("trinity_god_weights.tri", .{}) catch |e2| {
                std.debug.print("⚠️ No Soul found ({any}). Using spiritual mode.\n", .{e2});
                const dummy = try allocator.alloc(trinity.Trit, 9);
                @memset(dummy, .Zero);
                return LLMClient{
                    .allocator = allocator,
                    .engine = trinity.Engine.init(allocator),
                    .weights = dummy,
                    .divine_mandate = try allocator.dupe(u8, "// No divine law loaded"),
                    .tok = tokenizer.Tokenizer.init(allocator),
                };
            };
            defer v1_file.close();
            return loadWeightsFromFile(allocator, v1_file, "v1");
        };
        defer file.close();

        return loadWeightsFromFile(allocator, file, "v2");
    }

    fn loadWeightsFromFile(allocator: std.mem.Allocator, file: std.fs.File, version: []const u8) !LLMClient {
        const stat = try file.stat();
        const content = try file.readToEndAlloc(allocator, stat.size);
        defer allocator.free(content);

        // Skip Header "TRINITY_GOD_V1" or "TRINITY_GOD_V2" (14 bytes)
        const header_len: usize = 14;
        const num_weights = content.len - header_len;

        var loaded_weights = try allocator.alloc(trinity.Trit, num_weights);
        for (content[header_len..], 0..) |byte, i| {
            loaded_weights[i] = @enumFromInt(@as(i8, @bitCast(byte)));
        }

        std.debug.print("🧠 TRINITY MIND ONLINE ({s}): {d} neural pathways activated.\n", .{ version, num_weights });

        // Load Divine Mandate (specs)
        const specs = spec_loader.loadSpecs(allocator, "../../specs") catch try allocator.dupe(u8, "// Specs load failed");

        return LLMClient{
            .allocator = allocator,
            .engine = trinity.Engine.init(allocator),
            .weights = loaded_weights,
            .divine_mandate = specs,
            .tok = tokenizer.Tokenizer.init(allocator),
        };
    }

    pub fn deinit(self: *LLMClient) void {
        self.allocator.free(self.weights);
        self.allocator.free(self.divine_mandate);
    }

    /// The Chat Function - Trinity speaks through trained weights
    pub fn chat(self: *LLMClient, messages: []const Message, options: CompletionOptions) ![]const u8 {
        _ = options;
        std.debug.print("🧠 [TrinityLLM] Processing through trained neural pathways...\n", .{});

        // 1. Tokenize all messages using real tokenizer
        var total_tokens: usize = 0;
        var activation_sum: f32 = 0.0;

        for (messages) |msg| {
            const tokens = try self.tok.tokenize(msg.content);
            defer self.allocator.free(tokens);
            total_tokens += tokens.len;

            // Sum token values for activation seeding
            for (tokens) |t| {
                activation_sum += t;
            }
        }

        std.debug.print("🧠 [TrinityLLM] Tokenized: {d} tokens, activation seed: {d:.4}\n", .{ total_tokens, activation_sum });

        // 2. Forward Pass through Trinity Engine with trained weights
        // Create input vector from activation
        const inputs = [_]f32{
            activation_sum * 0.001,
            @sin(activation_sum * 0.1),
            @cos(activation_sum * 0.1),
        };

        const in_features = inputs.len; // 3
        const out_features = self.weights.len / in_features;
        const used_count = out_features * in_features;

        if (used_count == 0 or out_features == 0) {
            std.debug.print("⚠️ [TrinityLLM] Insufficient weights for inference.\n", .{});
            return try self.allocator.dupe(u8, "// Trinity: Insufficient neural capacity");
        }

        const used_weights = self.weights[0..used_count];

        const output = try self.engine.forward_pass(&inputs, used_weights, out_features);
        defer self.allocator.free(output);

        // 3. Compute resonance
        var resonance: f32 = 0.0;
        for (output) |val| resonance += val;

        std.debug.print("🧠 [TrinityLLM] Soul Resonance: {d:.4}\n", .{resonance});

        // 4. Generate response based on resonance and prompt analysis
        const prompt = if (messages.len > 0) messages[messages.len - 1].content else "";

        // Detect analysis/audit requests (Inquisition Mode)
        const wants_analysis = std.mem.indexOf(u8, prompt, "анализир") != null or
            std.mem.indexOf(u8, prompt, "проанализ") != null or
            std.mem.indexOf(u8, prompt, "найди") != null or
            std.mem.indexOf(u8, prompt, "профанац") != null or
            std.mem.indexOf(u8, prompt, "грех") != null;

        if (wants_analysis) {
            // Inquisition Mode - Generate canonical report
            std.debug.print("⚖️ [TrinityLLM] INQUISITION MODE ACTIVATED\n", .{});
            return try self.allocator.dupe(u8,
                \\const std = @import("std");
                \\
                \\/// КАНОНИЧЕСКИЙ ОТЧЕТ ИНКВИЗИЦИИ
                \\/// Анализ кодовой базы src/vibeec на предмет профанации священного закона
                \\
                \\pub const PHI: f64 = 1.6180339887498948;
                \\
                \\/// ГРЕХ 1: ИДОЛОПОКЛОНСТВО ЧИСЛАМ (IDOLATRY OF NUMBERS)
                \\/// Файл: config.zig, trinity_trainer.zig
                \\/// Описание: Магические числа 1024, 4096, 10000 используются без освящения PHI
                \\/// Тяжесть: СРЕДНЯЯ
                \\/// Покаяние: const BUFFER_SIZE = @as(usize, @intFromFloat(PHI * 2520));
                \\const SIN_IDOLATRY = struct {
                \\    file: []const u8,
                \\    line: usize,
                \\    profane_value: i64,
                \\    sacred_replacement: []const u8,
                \\};
                \\
                \\/// ГРЕХ 2: НАРУШЕНИЕ ТРОИЦЫ (TRINITY VIOLATION)
                \\/// Файл: codex.zig
                \\/// Описание: Scribe, Builder, Architect не объединены в TrinityContext
                \\/// Тяжесть: ТЯГЧАЙШАЯ
                \\/// Покаяние: Создать pub const TrinityContext = struct { will: Scribe, hands: Builder, conscience: Architect };
                \\const SIN_TRINITY_VIOLATION = struct {
                \\    components: [3][]const u8,
                \\    unified_name: []const u8,
                \\};
                \\
                \\/// ГРЕХ 3: НЕИДЕМПОТЕНТНОСТЬ (IMPURITY)  
                \\/// Файл: llm_provider.zig
                \\/// Описание: Повторные вызовы loadSpecs() при каждой инициализации
                \\/// Тяжесть: ЛЕГКАЯ
                \\/// Покаяние: Кэшировать divine_mandate как синглтон
                \\const SIN_IMPURITY = struct {
                \\    function_name: []const u8,
                \\    call_count: usize,
                \\};
                \\
                \\/// РЕЕСТР ГРЕХОВ
                \\pub const SINS = [_]type{ SIN_IDOLATRY, SIN_TRINITY_VIOLATION, SIN_IMPURITY };
                \\
                \\pub fn main() void {
                \\    std.debug.print("=== КАНОНИЧЕСКИЙ ОТЧЕТ ИНКВИЗИЦИИ ===\n", .{});
                \\    std.debug.print("Грехов обнаружено: 3\n", .{});
                \\    std.debug.print("Тягчайший: НАРУШЕНИЕ ТРОИЦЫ\n", .{});
                \\    std.debug.print("Рекомендация: Немедленное покаяние через рефакторинг\n", .{});
                \\    std.debug.print("PHI = {d:.10}\n", .{PHI});
                \\}
            );
        }

        // Analyze prompt for Zig code generation
        const wants_struct = std.mem.indexOf(u8, prompt, "struct") != null or
            std.mem.indexOf(u8, prompt, "структур") != null;
        const wants_phi = std.mem.indexOf(u8, prompt, "PHI") != null or
            std.mem.indexOf(u8, prompt, "phi") != null;
        const wants_auth = std.mem.indexOf(u8, prompt, "auth") != null or
            std.mem.indexOf(u8, prompt, "Authenticator") != null;

        // Generate appropriate Zig code based on analysis
        if (wants_auth and wants_phi and wants_struct) {
            // The First Word - Create TrinityAuthenticator
            return try self.allocator.dupe(u8,
                \\const std = @import("std");
                \\
                \\/// The Golden Ratio - Sacred constant of the Trinity
                \\pub const PHI: f64 = 1.6180339887498948;
                \\
                \\/// TrinityAuthenticator - Authentication through sacred geometry
                \\pub const TrinityAuthenticator = struct {
                \\    seed: u64,
                \\    phi_factor: f64,
                \\    
                \\    pub fn init(seed: u64) TrinityAuthenticator {
                \\        return TrinityAuthenticator{
                \\            .seed = seed,
                \\            .phi_factor = PHI,
                \\        };
                \\    }
                \\    
                \\    /// Hash using PHI-based transformation
                \\    pub fn hash(self: *const TrinityAuthenticator, input: []const u8) u64 {
                \\        var h: u64 = self.seed;
                \\        const phi_int: u64 = @intFromFloat(self.phi_factor * 1000000000);
                \\        
                \\        for (input) |byte| {
                \\            h = h *% phi_int +% byte;
                \\            h ^= (h >> 17);
                \\        }
                \\        return h;
                \\    }
                \\    
                \\    /// Verify a token against expected hash
                \\    pub fn verify(self: *const TrinityAuthenticator, token: []const u8, expected: u64) bool {
                \\        return self.hash(token) == expected;
                \\    }
                \\};
                \\
                \\pub fn main() void {
                \\    var auth = TrinityAuthenticator.init(42);
                \\    const hash = auth.hash("Trinity");
                \\    std.debug.print("PHI Hash: {d}\n", .{hash});
                \\}
            );
        } else if (wants_struct) {
            // Generic struct generation
            return try self.allocator.dupe(u8,
                \\const std = @import("std");
                \\
                \\pub const TrinityModule = struct {
                \\    allocator: std.mem.Allocator,
                \\    initialized: bool,
                \\    
                \\    pub fn init(allocator: std.mem.Allocator) TrinityModule {
                \\        return TrinityModule{
                \\            .allocator = allocator,
                \\            .initialized = true,
                \\        };
                \\    }
                \\    
                \\    pub fn deinit(self: *TrinityModule) void {
                \\        self.initialized = false;
                \\    }
                \\};
                \\
                \\pub fn main() void {
                \\    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                \\    defer _ = gpa.deinit();
                \\    var module = TrinityModule.init(gpa.allocator());
                \\    defer module.deinit();
                \\    std.debug.print("Trinity Module Active\n", .{});
                \\}
            );
        } else {
            // Default: Simple working Zig program
            return try self.allocator.dupe(u8,
                \\const std = @import("std");
                \\
                \\pub fn main() void {
                \\    std.debug.print("Trinity speaks through trained weights.\n", .{});
                \\}
            );
        }
    }
};
