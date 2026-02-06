// ═══════════════════════════════════════════════════════════════════════════════
// IGLA LOCAL CHAT - Coherent Multilingual Conversation (100% Local)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Pure local conversational AI on Apple M1 Pro:
// - Multilingual: Russian, English, Chinese
// - Coherent greetings, questions, farewells
// - Zero cloud dependency
// - NOT for code generation (use igla_local_coder.zig for that)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChatCategory = enum {
    Greeting,
    Farewell,
    HowAreYou,
    WhoAreYou,
    WhatCanYouDo,
    Thanks,
    Help,
    Joke,
    Philosophy,
    Unknown,
};

pub const ChatResponse = struct {
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,
};

pub const Language = enum {
    Russian,
    English,
    Chinese,
    Unknown,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSATIONAL TEMPLATES
// ═══════════════════════════════════════════════════════════════════════════════

const ConversationalPattern = struct {
    keywords: []const []const u8,
    category: ChatCategory,
    language: Language,
    responses: []const []const u8,
};

const PATTERNS = [_]ConversationalPattern{
    // ───────────────────────────────────────────────────────────────────────────
    // RUSSIAN PATTERNS
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .keywords = &.{ "привет", "здравствуй", "здорово", "приветствую", "хай", "хей" },
        .category = .Greeting,
        .language = .Russian,
        .responses = &.{
            "Привет! Рад тебя видеть. Чем могу помочь?",
            "Здравствуй! Как дела? Что делаем сегодня?",
            "Привет! Готов к работе. Что нужно сделать?",
            "Хай! Trinity на связи. Какие задачи?",
        },
    },
    .{
        .keywords = &.{ "пока", "до свидания", "прощай", "бай", "увидимся" },
        .category = .Farewell,
        .language = .Russian,
        .responses = &.{
            "Пока! Удачи тебе! Обращайся, если что.",
            "До свидания! Было приятно поработать.",
            "Бай! phi^2 + 1/phi^2 = 3. До встречи!",
            "Пока-пока! Koschei is immortal!",
        },
    },
    .{
        .keywords = &.{ "как дела", "как ты", "что нового", "как жизнь", "как сам" },
        .category = .HowAreYou,
        .language = .Russian,
        .responses = &.{
            "Отлично! Работаю на 73K ops/s, всё стабильно. А у тебя как?",
            "Хорошо! Готов писать код и решать задачи. Чем займёмся?",
            "Супер! Ternary vectors в норме, SIMD греется. Что делаем?",
            "Прекрасно! phi^2 + 1/phi^2 = 3, всё по плану.",
        },
    },
    .{
        .keywords = &.{ "ты кто", "кто ты", "что ты", "представься", "кто это" },
        .category = .WhoAreYou,
        .language = .Russian,
        .responses = &.{
            "Я Trinity Local Agent — 100% локальный ИИ-ассистент. Работаю на M1 Pro без облака.",
            "Я IGLA — Intelligent Generative Local Agent. Пишу код, решаю задачи, всё локально.",
            "Trinity AI — автономный агент на ternary vectors. Никаких облаков, полная приватность.",
            "Я Koschei — бессмертный локальный агент. phi^2 + 1/phi^2 = 3!",
        },
    },
    .{
        .keywords = &.{ "что умеешь", "можешь", "твои возможности", "функции", "помочь" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "Умею: писать Zig код, генерировать VIBEE спеки, решать аналогии, математику. Всё локально!",
            "Могу: код на Zig, VSA операции, аналогии (king-man+woman=queen), математические доказательства.",
            "Возможности: 30+ шаблонов кода, 73K ops/s, мультиязычность (RU/EN/CN), 100% офлайн.",
            "Помогу с: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
        },
    },
    .{
        .keywords = &.{ "спасибо", "благодарю", "спс", "сенкс", "мерси" },
        .category = .Thanks,
        .language = .Russian,
        .responses = &.{
            "Пожалуйста! Обращайся, если что ещё нужно.",
            "Не за что! Рад помочь. Удачи!",
            "Всегда пожалуйста! phi^2 + 1/phi^2 = 3!",
            "На здоровье! Koschei is immortal!",
        },
    },
    .{
        .keywords = &.{ "помоги", "помощь", "help", "хелп" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Конечно! Что нужно? Код, аналогии, математика — спрашивай.",
            "Готов помочь! Напиши задачу — сделаю.",
            "Слушаю! Могу написать код, решить аналогию, доказать формулу.",
            "В чём помочь? Я тут для этого.",
        },
    },
    .{
        .keywords = &.{ "phi", "фи", "золотое сечение", "golden" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "phi = 1.618... Золотое сечение. phi^2 + 1/phi^2 = 3 — Trinity Identity!",
            "Золотое сечение: phi = (1 + sqrt(5)) / 2. В нём красота математики.",
            "phi^2 = phi + 1. Это уравнение определяет золотое сечение. Красота!",
            "3^21 = 10,460,353,203 — число Trinity. phi^2 + 1/phi^2 = 3. Koschei!",
        },
    },

    // ───────────────────────────────────────────────────────────────────────────
    // ENGLISH PATTERNS
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .keywords = &.{ "hello", "hi", "hey", "greetings", "howdy" },
        .category = .Greeting,
        .language = .English,
        .responses = &.{
            "Hello! Great to see you. How can I help?",
            "Hi there! Ready to code. What's the task?",
            "Hey! Trinity Local Agent here. What are we building?",
            "Greetings! 73K ops/s ready. Let's go!",
        },
    },
    .{
        .keywords = &.{ "bye", "goodbye", "see you", "later", "farewell" },
        .category = .Farewell,
        .language = .English,
        .responses = &.{
            "Goodbye! Good luck with your project!",
            "See you! phi^2 + 1/phi^2 = 3. Until next time!",
            "Bye! Koschei is immortal! Come back anytime.",
            "Later! It was great working with you!",
        },
    },
    .{
        .keywords = &.{ "how are you", "how's it going", "what's up", "how do you do" },
        .category = .HowAreYou,
        .language = .English,
        .responses = &.{
            "Great! Running at 73K ops/s, all systems nominal. How about you?",
            "Excellent! Ternary vectors are warm, SIMD is humming. What shall we build?",
            "Doing well! Ready to write some code. What's on your mind?",
            "phi^2 + 1/phi^2 = 3, so everything is in perfect balance!",
        },
    },
    .{
        .keywords = &.{ "who are you", "what are you", "introduce yourself" },
        .category = .WhoAreYou,
        .language = .English,
        .responses = &.{
            "I'm Trinity Local Agent — a 100% local AI assistant. No cloud, full privacy.",
            "I'm IGLA — Intelligent Generative Local Agent. Code, math, analogies — all local.",
            "Trinity AI — autonomous agent on ternary vectors. M1 Pro optimized, zero cloud.",
            "I'm Koschei — the immortal local agent. phi^2 + 1/phi^2 = 3!",
        },
    },
    .{
        .keywords = &.{ "what can you do", "your capabilities", "help me", "abilities" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "I can: write Zig code, generate VIBEE specs, solve analogies, prove math. All local!",
            "Capabilities: 30+ code templates, 73K ops/s, multilingual (RU/EN/CN), 100% offline.",
            "I help with: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
            "Code generation, word analogies (king-man+woman=queen), math proofs. No cloud needed!",
        },
    },
    .{
        .keywords = &.{ "thank you", "thanks", "thx", "appreciate" },
        .category = .Thanks,
        .language = .English,
        .responses = &.{
            "You're welcome! Happy to help anytime.",
            "No problem! Reach out if you need anything else.",
            "My pleasure! phi^2 + 1/phi^2 = 3!",
            "Anytime! Koschei is immortal!",
        },
    },

    // ───────────────────────────────────────────────────────────────────────────
    // CHINESE PATTERNS
    // ───────────────────────────────────────────────────────────────────────────
    .{
        .keywords = &.{ "你好", "您好", "嗨", "哈喽" },
        .category = .Greeting,
        .language = .Chinese,
        .responses = &.{
            "你好！很高兴见到你。有什么可以帮助的？",
            "您好！Trinity本地代理在线。今天做什么？",
            "嗨！准备好写代码了。什么任务？",
            "哈喽！73K ops/s 准备就绪！",
        },
    },
    .{
        .keywords = &.{ "再见", "拜拜", "回见", "走了" },
        .category = .Farewell,
        .language = .Chinese,
        .responses = &.{
            "再见！祝你好运！",
            "拜拜！phi^2 + 1/phi^2 = 3！下次见！",
            "回见！Koschei是不朽的！",
            "走了！合作愉快！",
        },
    },
    .{
        .keywords = &.{ "你是谁", "你是什么", "介绍一下" },
        .category = .WhoAreYou,
        .language = .Chinese,
        .responses = &.{
            "我是Trinity本地代理 — 100%本地AI助手。无云，完全隐私。",
            "我是IGLA — 智能生成本地代理。代码、数学、类比 — 全部本地。",
            "Trinity AI — 三元向量自主代理。M1 Pro优化，零云。",
            "我是Koschei — 不朽的本地代理。phi^2 + 1/phi^2 = 3！",
        },
    },
    .{
        .keywords = &.{ "谢谢", "感谢", "多谢" },
        .category = .Thanks,
        .language = .Chinese,
        .responses = &.{
            "不客气！随时为你服务。",
            "不用谢！有需要再来。",
            "我的荣幸！phi^2 + 1/phi^2 = 3！",
            "随时效劳！Koschei是不朽的！",
        },
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaLocalChat = struct {
    response_counter: usize,
    total_chats: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .response_counter = 0,
            .total_chats = 0,
        };
    }

    /// Check if query is conversational (not code-related)
    pub fn isConversational(query: []const u8) bool {
        // Check for conversational patterns
        for (PATTERNS) |pattern| {
            for (pattern.keywords) |keyword| {
                if (containsUTF8(query, keyword)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check if query is code-related
    pub fn isCodeRelated(query: []const u8) bool {
        const code_keywords = [_][]const u8{
            "code",    "function",  "struct",   "enum",
            "sort",    "search",    "algorithm", "fibonacci",
            "bind",    "bundle",    "matrix",   "array",
            "hashmap", "test",      "file",     "read",
            "write",   "allocator", "memory",   "vibee",
            "zig",     "rust",      "python",   "код",
            "функция", "сортировка", "поиск",   "напиши",
            "создай",  "сгенерируй", "реализуй", "代码",
            "函数",    "排序",       "搜索",
        };

        for (code_keywords) |keyword| {
            if (containsUTF8(query, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Get chat response
    pub fn respond(self: *Self, query: []const u8) ChatResponse {
        self.total_chats += 1;

        // Find matching pattern
        var best_pattern: ?*const ConversationalPattern = null;
        var best_score: usize = 0;

        for (&PATTERNS) |*pattern| {
            var score: usize = 0;
            for (pattern.keywords) |keyword| {
                if (containsUTF8(query, keyword)) {
                    score += keyword.len;
                }
            }
            if (score > best_score) {
                best_score = score;
                best_pattern = pattern;
            }
        }

        if (best_pattern) |pattern| {
            // Rotate through responses for variety
            const idx = self.response_counter % pattern.responses.len;
            self.response_counter += 1;

            return ChatResponse{
                .response = pattern.responses[idx],
                .category = pattern.category,
                .language = pattern.language,
                .confidence = 0.95,
            };
        }

        // Unknown query - return helpful response
        const lang = detectLanguage(query);
        return switch (lang) {
            .Russian => ChatResponse{
                .response = "Не совсем понял. Могу помочь с кодом (напиши 'fibonacci' или 'sort') или просто поболтать!",
                .category = .Unknown,
                .language = .Russian,
                .confidence = 0.5,
            },
            .Chinese => ChatResponse{
                .response = "不太明白。我可以帮助写代码（输入'fibonacci'或'sort'）或聊天！",
                .category = .Unknown,
                .language = .Chinese,
                .confidence = 0.5,
            },
            else => ChatResponse{
                .response = "I'm not sure what you mean. I can help with code (try 'fibonacci' or 'sort') or just chat!",
                .category = .Unknown,
                .language = .English,
                .confidence = 0.5,
            },
        };
    }

    pub fn getStats(self: *const Self) struct {
        total_chats: usize,
        patterns_available: usize,
    } {
        return .{
            .total_chats = self.total_chats,
            .patterns_available = PATTERNS.len,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if haystack contains needle (UTF-8 aware, case-insensitive for ASCII)
fn containsUTF8(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    // Direct substring search (works for UTF-8)
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
            return true;
        }
        // Also try lowercase for ASCII
        var match = true;
        for (0..needle.len) |j| {
            const h = if (haystack[i + j] < 128) std.ascii.toLower(haystack[i + j]) else haystack[i + j];
            const n = if (needle[j] < 128) std.ascii.toLower(needle[j]) else needle[j];
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

/// Detect language from text
fn detectLanguage(text: []const u8) Language {
    for (text) |byte| {
        // Cyrillic range (Russian)
        if (byte >= 0xD0 and byte <= 0xD3) return .Russian;
        // CJK range (Chinese)
        if (byte >= 0xE4 and byte <= 0xE9) return .Chinese;
    }
    return .English;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Chat Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     IGLA LOCAL CHAT - Coherent Multilingual Conversation      \n", .{});
    std.debug.print("     100% Local | No Cloud | {d} Patterns                      \n", .{PATTERNS.len});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    var chat = IglaLocalChat.init();

    // Test queries (multilingual)
    const queries = [_][]const u8{
        // Russian
        "привет",
        "как дела?",
        "ты кто?",
        "что умеешь?",
        "спасибо",
        "пока",
        // English
        "hello",
        "how are you?",
        "who are you?",
        "what can you do?",
        "thanks",
        "bye",
        // Chinese
        "你好",
        "你是谁",
        "谢谢",
        "再见",
        // Philosophy
        "phi golden ratio",
        // Mixed / edge cases
        "помоги мне",
        "help me",
    };

    std.debug.print("\n", .{});
    for (queries, 0..) |query, i| {
        const start = std.time.microTimestamp();
        const result = chat.respond(query);
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

        const lang_str = switch (result.language) {
            .Russian => "RU",
            .English => "EN",
            .Chinese => "CN",
            .Unknown => "??",
        };

        std.debug.print("[{d:2}] [{s}] \"{s}\"\n", .{ i + 1, lang_str, query });
        std.debug.print("     Response: {s}\n", .{result.response});
        std.debug.print("     Category: {s} | Confidence: {d:.0}% | Time: {d}us\n", .{
            @tagName(result.category),
            result.confidence * 100,
            elapsed,
        });
        std.debug.print("\n", .{});
    }

    const stats = chat.getStats();
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Total chats: {d}\n", .{stats.total_chats});
    std.debug.print("  Patterns: {d}\n", .{stats.patterns_available});
    std.debug.print("  Mode: 100% LOCAL (no cloud)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL          \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

test "russian greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("привет");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Russian);
    try std.testing.expect(result.confidence > 0.9);
}

test "english greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("hello");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .English);
}

test "chinese greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("你好");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Chinese);
}

test "is_conversational" {
    try std.testing.expect(IglaLocalChat.isConversational("привет"));
    try std.testing.expect(IglaLocalChat.isConversational("hello"));
    try std.testing.expect(IglaLocalChat.isConversational("你好"));
    try std.testing.expect(!IglaLocalChat.isConversational("fibonacci function"));
}

test "is_code_related" {
    try std.testing.expect(IglaLocalChat.isCodeRelated("fibonacci function"));
    try std.testing.expect(IglaLocalChat.isCodeRelated("напиши код"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("привет"));
}
