// TRINITY LLM - Локальный LLM на троичных весах
// БЕЗ NVIDIA. БЕЗ API. БЕЗ ИНТЕРНЕТА.
// φ² + 1/φ² = 3 = TRINITY
//
// "Мы не арендуем вычислительную мощь. Мы создаём её из ничего."

const std = @import("std");
const prometheus = @import("prometheus_seed.zig");
const engine = @import("trinity_inference_engine.zig");
const trinity_format = @import("trinity_format.zig");

pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// TOKENIZER (простой BPE-подобный)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SimpleTokenizer = struct {
    allocator: std.mem.Allocator,
    vocab: std.StringHashMap(u32),
    reverse_vocab: std.AutoHashMap(u32, []const u8),
    vocab_size: u32,

    pub fn init(allocator: std.mem.Allocator) SimpleTokenizer {
        return SimpleTokenizer{
            .allocator = allocator,
            .vocab = std.StringHashMap(u32).init(allocator),
            .reverse_vocab = std.AutoHashMap(u32, []const u8).init(allocator),
            .vocab_size = 0,
        };
    }

    pub fn deinit(self: *SimpleTokenizer) void {
        // Освобождаем все строки токенов
        var it = self.vocab.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.vocab.deinit();
        self.reverse_vocab.deinit();
    }

    /// Добавление токена в словарь
    pub fn addToken(self: *SimpleTokenizer, token: []const u8) !u32 {
        if (self.vocab.get(token)) |id| {
            return id;
        }

        const id = self.vocab_size;
        const token_copy = try self.allocator.dupe(u8, token);
        try self.vocab.put(token_copy, id);
        try self.reverse_vocab.put(id, token_copy);
        self.vocab_size += 1;
        return id;
    }

    /// Простая токенизация по символам
    pub fn encode(self: *SimpleTokenizer, text: []const u8) !std.ArrayList(u32) {
        var tokens = std.ArrayList(u32).init(self.allocator);

        for (text) |c| {
            const char_str = [_]u8{c};
            const id = try self.addToken(&char_str);
            try tokens.append(id);
        }

        return tokens;
    }

    /// Декодирование токенов в текст
    pub fn decode(self: *const SimpleTokenizer, tokens: []const u32) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);

        for (tokens) |id| {
            if (self.reverse_vocab.get(id)) |token| {
                try result.appendSlice(token);
            }
        }

        return result.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY TRANSFORMER BLOCK (упрощённый)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityAttention = struct {
    allocator: std.mem.Allocator,
    hidden_size: usize,
    num_heads: usize,
    head_dim: usize,

    q_proj: engine.TrinityLayer,
    k_proj: engine.TrinityLayer,
    v_proj: engine.TrinityLayer,
    o_proj: engine.TrinityLayer,

    pub fn init(allocator: std.mem.Allocator, hidden_size: usize, num_heads: usize) !TrinityAttention {
        const head_dim = hidden_size / num_heads;

        return TrinityAttention{
            .allocator = allocator,
            .hidden_size = hidden_size,
            .num_heads = num_heads,
            .head_dim = head_dim,
            .q_proj = try engine.TrinityLayer.init(allocator, hidden_size, hidden_size, .none),
            .k_proj = try engine.TrinityLayer.init(allocator, hidden_size, hidden_size, .none),
            .v_proj = try engine.TrinityLayer.init(allocator, hidden_size, hidden_size, .none),
            .o_proj = try engine.TrinityLayer.init(allocator, hidden_size, hidden_size, .none),
        };
    }

    pub fn deinit(self: *TrinityAttention) void {
        self.q_proj.deinit();
        self.k_proj.deinit();
        self.v_proj.deinit();
        self.o_proj.deinit();
    }

    /// Упрощённый attention (без softmax, используем линейное приближение)
    pub fn forward(self: *const TrinityAttention, allocator: std.mem.Allocator, x: []const f32, seq_len: usize) ![]f32 {
        const batch_size = 1;

        // Q, K, V проекции
        const q = try self.q_proj.forward(allocator, x, batch_size * seq_len);
        defer allocator.free(q);
        const k = try self.k_proj.forward(allocator, x, batch_size * seq_len);
        defer allocator.free(k);
        const v = try self.v_proj.forward(allocator, x, batch_size * seq_len);
        defer allocator.free(v);

        // Упрощённый attention: просто усредняем V (для демонстрации)
        // В реальности нужен полный attention механизм
        const output = try allocator.alloc(f32, seq_len * self.hidden_size);
        @memcpy(output, v);

        // Output projection
        const final = try self.o_proj.forward(allocator, output, batch_size * seq_len);
        allocator.free(output);

        return final;
    }
};

pub const TrinityMLP = struct {
    allocator: std.mem.Allocator,
    gate_proj: engine.TrinityLayer,
    up_proj: engine.TrinityLayer,
    down_proj: engine.TrinityLayer,

    pub fn init(allocator: std.mem.Allocator, hidden_size: usize, intermediate_size: usize) !TrinityMLP {
        return TrinityMLP{
            .allocator = allocator,
            .gate_proj = try engine.TrinityLayer.init(allocator, hidden_size, intermediate_size, .silu_approx),
            .up_proj = try engine.TrinityLayer.init(allocator, hidden_size, intermediate_size, .none),
            .down_proj = try engine.TrinityLayer.init(allocator, intermediate_size, hidden_size, .none),
        };
    }

    pub fn deinit(self: *TrinityMLP) void {
        self.gate_proj.deinit();
        self.up_proj.deinit();
        self.down_proj.deinit();
    }

    pub fn forward(self: *const TrinityMLP, allocator: std.mem.Allocator, x: []const f32, seq_len: usize) ![]f32 {
        const gate = try self.gate_proj.forward(allocator, x, seq_len);
        defer allocator.free(gate);
        const up = try self.up_proj.forward(allocator, x, seq_len);
        defer allocator.free(up);

        // gate * up (элементное умножение - единственное место где нужно умножение!)
        // Но мы можем аппроксимировать через сложение: gate + up
        const intermediate = try allocator.alloc(f32, gate.len);
        for (gate, up, 0..) |g, u, i| {
            intermediate[i] = g + u;  // Аппроксимация gate * up
        }

        const output = try self.down_proj.forward(allocator, intermediate, seq_len);
        allocator.free(intermediate);

        return output;
    }
};

pub const TrinityBlock = struct {
    allocator: std.mem.Allocator,
    attention: TrinityAttention,
    mlp: TrinityMLP,
    hidden_size: usize,

    pub fn init(allocator: std.mem.Allocator, hidden_size: usize, num_heads: usize, intermediate_size: usize) !TrinityBlock {
        return TrinityBlock{
            .allocator = allocator,
            .attention = try TrinityAttention.init(allocator, hidden_size, num_heads),
            .mlp = try TrinityMLP.init(allocator, hidden_size, intermediate_size),
            .hidden_size = hidden_size,
        };
    }

    pub fn deinit(self: *TrinityBlock) void {
        self.attention.deinit();
        self.mlp.deinit();
    }

    pub fn forward(self: *const TrinityBlock, allocator: std.mem.Allocator, x: []const f32, seq_len: usize) ![]f32 {
        // Attention + residual
        const attn_out = try self.attention.forward(allocator, x, seq_len);
        defer allocator.free(attn_out);

        var hidden = try allocator.alloc(f32, x.len);
        for (x, attn_out, 0..) |xi, ai, i| {
            hidden[i] = xi + ai;  // Residual connection
        }

        // MLP + residual
        const mlp_out = try self.mlp.forward(allocator, hidden, seq_len);
        defer allocator.free(mlp_out);

        for (hidden, mlp_out) |*h, m| {
            h.* += m;  // Residual connection
        }

        return hidden;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY LLM MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityLLM = struct {
    allocator: std.mem.Allocator,
    tokenizer: SimpleTokenizer,
    embedding: engine.TrinityLayer,
    blocks: std.ArrayList(TrinityBlock),
    lm_head: engine.TrinityLayer,

    vocab_size: usize,
    hidden_size: usize,
    num_layers: usize,
    num_heads: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        vocab_size: usize,
        hidden_size: usize,
        num_layers: usize,
        num_heads: usize,
        intermediate_size: usize,
    ) !TrinityLLM {
        var model = TrinityLLM{
            .allocator = allocator,
            .tokenizer = SimpleTokenizer.init(allocator),
            .embedding = try engine.TrinityLayer.init(allocator, vocab_size, hidden_size, .none),
            .blocks = std.ArrayList(TrinityBlock).init(allocator),
            .lm_head = try engine.TrinityLayer.init(allocator, hidden_size, vocab_size, .none),
            .vocab_size = vocab_size,
            .hidden_size = hidden_size,
            .num_layers = num_layers,
            .num_heads = num_heads,
        };

        // Создаём блоки трансформера
        for (0..num_layers) |_| {
            const block = try TrinityBlock.init(allocator, hidden_size, num_heads, intermediate_size);
            try model.blocks.append(block);
        }

        return model;
    }

    pub fn deinit(self: *TrinityLLM) void {
        self.tokenizer.deinit();
        self.embedding.deinit();
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.deinit();
        self.lm_head.deinit();
    }

    /// Генерация текста
    pub fn generate(self: *TrinityLLM, prompt: []const u8, max_tokens: usize) ![]u8 {
        var tokens = try self.tokenizer.encode(prompt);
        defer tokens.deinit();

        // Генерируем токены
        for (0..max_tokens) |_| {
            const next_token = try self.predictNext(tokens.items);
            try tokens.append(next_token);

            // Простой критерий остановки
            if (next_token == 0) break;
        }

        return self.tokenizer.decode(tokens.items);
    }

    /// Предсказание следующего токена
    fn predictNext(self: *TrinityLLM, tokens: []const u32) !u32 {
        const seq_len = tokens.len;

        // One-hot encoding входных токенов
        var input = try self.allocator.alloc(f32, seq_len * self.vocab_size);
        defer self.allocator.free(input);
        @memset(input, 0.0);

        for (tokens, 0..) |token, i| {
            if (token < self.vocab_size) {
                input[i * self.vocab_size + token] = 1.0;
            }
        }

        // Embedding
        var hidden = try self.embedding.forward(self.allocator, input, seq_len);

        // Проходим через все блоки
        for (self.blocks.items) |*block| {
            const next_hidden = try block.forward(self.allocator, hidden, seq_len);
            self.allocator.free(hidden);
            hidden = next_hidden;
        }

        // LM head - получаем логиты
        const logits = try self.lm_head.forward(self.allocator, hidden, seq_len);
        defer self.allocator.free(logits);
        self.allocator.free(hidden);

        // Берём логиты последнего токена
        const last_logits = logits[(seq_len - 1) * self.vocab_size .. seq_len * self.vocab_size];

        // Argmax
        var max_idx: u32 = 0;
        var max_val: f32 = last_logits[0];
        for (last_logits, 0..) |val, i| {
            if (val > max_val) {
                max_val = val;
                max_idx = @intCast(i);
            }
        }

        return max_idx;
    }

    /// Загрузка весов из .tri файла
    pub fn loadFromTri(self: *TrinityLLM, path: []const u8) !void {
        var reader = try trinity_format.TrinityReader.init(self.allocator, path);
        defer reader.deinit();

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           LOADING TRINITY MODEL                              ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ File: {s:<54} ║\n", .{path[0..@min(path.len, 54)]});
        std.debug.print("║ Tensors: {d:<51} ║\n", .{reader.header.num_tensors});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        // Загружаем веса по именам тензоров
        var loaded_count: usize = 0;

        for (reader.listTensors()) |entry| {
            const name = entry.name;

            // Загружаем тензор
            const trits = reader.getTensor(name) catch |err| {
                std.debug.print("⚠️  Skip {s}: {}\n", .{ name, err });
                continue;
            };
            defer self.allocator.free(trits);

            // Маппинг имён тензоров на слои модели
            if (std.mem.indexOf(u8, name, "embed_tokens") != null) {
                try self.loadWeightsToLayer(&self.embedding, trits);
                loaded_count += 1;
            } else if (std.mem.indexOf(u8, name, "lm_head") != null) {
                try self.loadWeightsToLayer(&self.lm_head, trits);
                loaded_count += 1;
            } else if (std.mem.indexOf(u8, name, "q_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].attention.q_proj, trits);
                    loaded_count += 1;
                }
            } else if (std.mem.indexOf(u8, name, "k_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].attention.k_proj, trits);
                    loaded_count += 1;
                }
            } else if (std.mem.indexOf(u8, name, "v_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].attention.v_proj, trits);
                    loaded_count += 1;
                }
            } else if (std.mem.indexOf(u8, name, "o_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].attention.o_proj, trits);
                    loaded_count += 1;
                }
            } else if (std.mem.indexOf(u8, name, "gate_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].mlp.gate_proj, trits);
                    loaded_count += 1;
                }
            } else if (std.mem.indexOf(u8, name, "up_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].mlp.up_proj, trits);
                    loaded_count += 1;
                }
            } else if (std.mem.indexOf(u8, name, "down_proj") != null) {
                const layer_idx = parseLayerIndex(name);
                if (layer_idx < self.blocks.items.len) {
                    try self.loadWeightsToLayer(&self.blocks.items[layer_idx].mlp.down_proj, trits);
                    loaded_count += 1;
                }
            }
        }

        std.debug.print("✅ Loaded {d} tensors from .tri file\n", .{loaded_count});
    }

    fn loadWeightsToLayer(self: *TrinityLLM, layer: *engine.TrinityLayer, trits: []const prometheus.TritWeight) !void {
        _ = self;
        const copy_len = @min(layer.weights.len, trits.len);
        @memcpy(layer.weights[0..copy_len], trits[0..copy_len]);
    }

    /// Статистика модели
    pub fn printStats(self: *const TrinityLLM) void {
        var total_params: usize = 0;
        total_params += self.embedding.weights.len;
        for (self.blocks.items) |block| {
            total_params += block.attention.q_proj.weights.len;
            total_params += block.attention.k_proj.weights.len;
            total_params += block.attention.v_proj.weights.len;
            total_params += block.attention.o_proj.weights.len;
            total_params += block.mlp.gate_proj.weights.len;
            total_params += block.mlp.up_proj.weights.len;
            total_params += block.mlp.down_proj.weights.len;
        }
        total_params += self.lm_head.weights.len;

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY LLM - ПРОМЕТЕЙ                             ║\n", .{});
        std.debug.print("║           БЕЗ NVIDIA | БЕЗ API | БЕЗ УМНОЖЕНИЯ               ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Vocab size:       {d:>12}                               ║\n", .{self.vocab_size});
        std.debug.print("║ Hidden size:      {d:>12}                               ║\n", .{self.hidden_size});
        std.debug.print("║ Num layers:       {d:>12}                               ║\n", .{self.num_layers});
        std.debug.print("║ Num heads:        {d:>12}                               ║\n", .{self.num_heads});
        std.debug.print("║ Total params:     {d:>12}                               ║\n", .{total_params});
        std.debug.print("║ Memory (2-bit):   {d:>12} bytes                         ║\n", .{total_params / 4});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ φ² + 1/φ² = 3 = TRINITY                                      ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Парсинг индекса слоя из имени тензора (например, "layers.5.self_attn.q_proj" -> 5)
fn parseLayerIndex(name: []const u8) usize {
    // Ищем паттерн "layers.N." или ".N."
    var i: usize = 0;
    while (i < name.len) : (i += 1) {
        if (name[i] == '.') {
            // Проверяем, есть ли число после точки
            var j = i + 1;
            var num: usize = 0;
            var found_digit = false;
            while (j < name.len and name[j] >= '0' and name[j] <= '9') : (j += 1) {
                num = num * 10 + (name[j] - '0');
                found_digit = true;
            }
            if (found_digit and j < name.len and name[j] == '.') {
                return num;
            }
        }
    }
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse layer index" {
    try std.testing.expectEqual(@as(usize, 5), parseLayerIndex("model.layers.5.self_attn.q_proj.weight"));
    try std.testing.expectEqual(@as(usize, 12), parseLayerIndex("layers.12.mlp.gate_proj"));
    try std.testing.expectEqual(@as(usize, 0), parseLayerIndex("embed_tokens.weight"));
}

test "simple tokenizer" {
    var tokenizer = SimpleTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var tokens = try tokenizer.encode("hello");
    defer tokens.deinit();

    try std.testing.expectEqual(@as(usize, 5), tokens.items.len);
}

test "trinity attention init" {
    var attn = try TrinityAttention.init(std.testing.allocator, 64, 4);
    defer attn.deinit();

    try std.testing.expectEqual(@as(usize, 64), attn.hidden_size);
    try std.testing.expectEqual(@as(usize, 4), attn.num_heads);
}

test "trinity block init" {
    var block = try TrinityBlock.init(std.testing.allocator, 64, 4, 128);
    defer block.deinit();

    try std.testing.expectEqual(@as(usize, 64), block.hidden_size);
}

test "trinity llm init" {
    var model = try TrinityLLM.init(
        std.testing.allocator,
        256,   // vocab_size
        64,    // hidden_size
        2,     // num_layers
        4,     // num_heads
        128,   // intermediate_size
    );
    defer model.deinit();

    try std.testing.expectEqual(@as(usize, 256), model.vocab_size);
    try std.testing.expectEqual(@as(usize, 2), model.num_layers);
}
