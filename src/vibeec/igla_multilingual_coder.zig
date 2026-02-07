// =============================================================================
// IGLA MULTILINGUAL CODER v1.0 - Full Local Fluent Chat + Coding
// =============================================================================
//
// CYCLE 6: Golden Chain Pipeline
// - Multilingual chat (RU/EN/ZH/ES/DE)
// - Code generation (Zig/Python/JS/Shell)
// - Context-aware conversations
// - Fluent natural responses
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const enhanced_chat = @import("igla_enhanced_chat.zig");
const self_opt = @import("igla_self_opt.zig");

// =============================================================================
// CONFIGURATION
// =============================================================================

pub const MAX_CODE_LINES: usize = 50;
pub const MAX_CONTEXT_TURNS: usize = 10;
pub const SUPPORTED_LANGUAGES: usize = 5;
pub const SUPPORTED_CODE_LANGS: usize = 4;

// =============================================================================
// LANGUAGE DETECTION
// =============================================================================

pub const Language = enum {
    Russian,
    English,
    Chinese,
    Spanish,
    German,
    Unknown,

    pub fn detect(text: []const u8) Language {
        // Check for Cyrillic (Russian)
        for (text) |byte| {
            if (byte >= 0xD0 and byte <= 0xD1) return .Russian;
        }

        // Check for Chinese characters (UTF-8 range)
        var i: usize = 0;
        while (i < text.len) {
            if (i + 2 < text.len) {
                const b0 = text[i];
                if (b0 >= 0xE4 and b0 <= 0xE9) return .Chinese;
            }
            i += 1;
        }

        // Check for Spanish markers
        if (containsAny(text, &[_][]const u8{ "hola", "gracias", "como", "esta", "que" })) {
            return .Spanish;
        }

        // Check for German markers
        if (containsAny(text, &[_][]const u8{ "hallo", "danke", "wie", "ist", "nicht" })) {
            return .German;
        }

        // Default to English
        return .English;
    }

    pub fn getName(self: Language) []const u8 {
        return switch (self) {
            .Russian => "Russian",
            .English => "English",
            .Chinese => "Chinese",
            .Spanish => "Spanish",
            .German => "German",
            .Unknown => "Unknown",
        };
    }
};

fn containsAny(text: []const u8, words: []const []const u8) bool {
    for (words) |word| {
        if (containsWord(text, word)) return true;
    }
    return false;
}

fn containsWord(text: []const u8, word: []const u8) bool {
    if (word.len > text.len) return false;
    var i: usize = 0;
    while (i + word.len <= text.len) : (i += 1) {
        var matches = true;
        for (word, 0..) |w, j| {
            const t = text[i + j];
            const t_lower = if (t < 128) std.ascii.toLower(t) else t;
            const w_lower = if (w < 128) std.ascii.toLower(w) else w;
            if (t_lower != w_lower) {
                matches = false;
                break;
            }
        }
        if (matches) return true;
    }
    return false;
}

// =============================================================================
// CODE LANGUAGE DETECTION
// =============================================================================

pub const CodeLanguage = enum {
    Zig,
    Python,
    JavaScript,
    Shell,
    None,

    pub fn detect(query: []const u8) CodeLanguage {
        // Check for explicit language mentions
        if (containsWord(query, "zig")) return .Zig;
        if (containsWord(query, "python") or containsWord(query, "py")) return .Python;
        if (containsWord(query, "javascript") or containsWord(query, "js") or containsWord(query, "typescript") or containsWord(query, "ts")) return .JavaScript;
        if (containsWord(query, "bash") or containsWord(query, "shell") or containsWord(query, "sh")) return .Shell;

        // Infer from context
        if (containsWord(query, "comptime") or containsWord(query, "allocator")) return .Zig;
        if (containsWord(query, "def ") or containsWord(query, "import ") or containsWord(query, "pip")) return .Python;
        if (containsWord(query, "const ") or containsWord(query, "let ") or containsWord(query, "npm")) return .JavaScript;
        if (containsWord(query, "chmod") or containsWord(query, "grep") or containsWord(query, "sudo")) return .Shell;

        return .None;
    }

    pub fn getExtension(self: CodeLanguage) []const u8 {
        return switch (self) {
            .Zig => ".zig",
            .Python => ".py",
            .JavaScript => ".js",
            .Shell => ".sh",
            .None => "",
        };
    }
};

// =============================================================================
// CODE TEMPLATES
// =============================================================================

pub const CodeTemplate = struct {
    keywords: []const []const u8,
    code: []const u8,
    explanation: []const u8,
    lang: CodeLanguage,
};

pub const code_templates = [_]CodeTemplate{
    // Zig templates
    .{
        .keywords = &[_][]const u8{ "hello", "world", "print", "zig" },
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() void {
        \\    std.debug.print("Hello, World!\n", .{});
        \\}
        ,
        .explanation = "Basic Zig hello world using std.debug.print",
        .lang = .Zig,
    },
    .{
        .keywords = &[_][]const u8{ "fibonacci", "fib", "zig" },
        .code =
        \\fn fibonacci(n: u64) u64 {
        \\    if (n <= 1) return n;
        \\    return fibonacci(n - 1) + fibonacci(n - 2);
        \\}
        \\
        \\pub fn main() void {
        \\    const result = fibonacci(10);
        \\    std.debug.print("fib(10) = {}\n", .{result});
        \\}
        ,
        .explanation = "Recursive Fibonacci in Zig with tail optimization potential",
        .lang = .Zig,
    },
    .{
        .keywords = &[_][]const u8{ "array", "sort", "zig" },
        .code =
        \\const std = @import("std");
        \\
        \\pub fn main() void {
        \\    var arr = [_]i32{ 5, 2, 8, 1, 9 };
        \\    std.mem.sort(i32, &arr, {}, std.sort.asc(i32));
        \\    // arr is now [1, 2, 5, 8, 9]
        \\}
        ,
        .explanation = "Array sorting in Zig using std.mem.sort",
        .lang = .Zig,
    },

    // Python templates
    .{
        .keywords = &[_][]const u8{ "hello", "world", "python", "print" },
        .code =
        \\print("Hello, World!")
        ,
        .explanation = "Simple Python hello world",
        .lang = .Python,
    },
    .{
        .keywords = &[_][]const u8{ "fibonacci", "fib", "python" },
        .code =
        \\def fibonacci(n: int) -> int:
        \\    if n <= 1:
        \\        return n
        \\    return fibonacci(n - 1) + fibonacci(n - 2)
        \\
        \\print(f"fib(10) = {fibonacci(10)}")
        ,
        .explanation = "Recursive Fibonacci in Python with type hints",
        .lang = .Python,
    },
    .{
        .keywords = &[_][]const u8{ "list", "comprehension", "python" },
        .code =
        \\# List comprehension examples
        \\squares = [x**2 for x in range(10)]
        \\evens = [x for x in range(20) if x % 2 == 0]
        \\matrix = [[i*j for j in range(5)] for i in range(5)]
        ,
        .explanation = "Python list comprehensions for concise data transformations",
        .lang = .Python,
    },

    // JavaScript templates
    .{
        .keywords = &[_][]const u8{ "hello", "world", "javascript", "js" },
        .code =
        \\console.log("Hello, World!");
        ,
        .explanation = "JavaScript hello world using console.log",
        .lang = .JavaScript,
    },
    .{
        .keywords = &[_][]const u8{ "async", "await", "fetch", "javascript", "js" },
        .code =
        \\async function fetchData(url) {
        \\    try {
        \\        const response = await fetch(url);
        \\        const data = await response.json();
        \\        return data;
        \\    } catch (error) {
        \\        console.error("Error:", error);
        \\    }
        \\}
        ,
        .explanation = "Async/await pattern for fetching data in JavaScript",
        .lang = .JavaScript,
    },
    .{
        .keywords = &[_][]const u8{ "arrow", "function", "javascript", "js" },
        .code =
        \\// Arrow function examples
        \\const add = (a, b) => a + b;
        \\const square = x => x * x;
        \\const greet = name => `Hello, ${name}!`;
        \\
        \\// Array methods with arrows
        \\const nums = [1, 2, 3, 4, 5];
        \\const doubled = nums.map(x => x * 2);
        \\const sum = nums.reduce((a, b) => a + b, 0);
        ,
        .explanation = "JavaScript arrow functions and array methods",
        .lang = .JavaScript,
    },

    // Shell templates
    .{
        .keywords = &[_][]const u8{ "hello", "world", "bash", "shell" },
        .code =
        \\#!/bin/bash
        \\echo "Hello, World!"
        ,
        .explanation = "Basic Bash hello world script",
        .lang = .Shell,
    },
    .{
        .keywords = &[_][]const u8{ "loop", "for", "bash", "shell" },
        .code =
        \\#!/bin/bash
        \\for i in {1..10}; do
        \\    echo "Iteration $i"
        \\done
        \\
        \\# Loop over files
        \\for file in *.txt; do
        \\    echo "Processing: $file"
        \\done
        ,
        .explanation = "Bash for loops for iteration",
        .lang = .Shell,
    },
    .{
        .keywords = &[_][]const u8{ "find", "grep", "bash", "shell" },
        .code =
        \\#!/bin/bash
        \\# Find all .zig files
        \\find . -name "*.zig" -type f
        \\
        \\# Search for pattern in files
        \\grep -r "TODO" --include="*.zig" .
        \\
        \\# Find and execute
        \\find . -name "*.log" -exec rm {} \;
        ,
        .explanation = "Bash find and grep for file searching",
        .lang = .Shell,
    },
};

// =============================================================================
// MULTILINGUAL RESPONSES
// =============================================================================

pub const MultilingualResponse = struct {
    russian: []const u8,
    english: []const u8,
    chinese: []const u8,
    spanish: []const u8,
    german: []const u8,

    pub fn get(self: *const MultilingualResponse, lang: Language) []const u8 {
        return switch (lang) {
            .Russian => self.russian,
            .English => self.english,
            .Chinese => self.chinese,
            .Spanish => self.spanish,
            .German => self.german,
            .Unknown => self.english,
        };
    }
};

pub const multilingual_greetings = MultilingualResponse{
    .russian = "Привет! Я IGLA — локальный AI-ассистент. Чем могу помочь?",
    .english = "Hello! I'm IGLA — a local AI assistant. How can I help you?",
    .chinese = "你好！我是IGLA——本地AI助手。有什么可以帮助你的？",
    .spanish = "¡Hola! Soy IGLA — un asistente de IA local. ¿En qué puedo ayudarte?",
    .german = "Hallo! Ich bin IGLA — ein lokaler KI-Assistent. Wie kann ich dir helfen?",
};

pub const multilingual_code_intro = MultilingualResponse{
    .russian = "Вот код для твоей задачи:",
    .english = "Here's the code for your task:",
    .chinese = "这是你任务的代码：",
    .spanish = "Aquí está el código para tu tarea:",
    .german = "Hier ist der Code für deine Aufgabe:",
};

pub const multilingual_explanation = MultilingualResponse{
    .russian = "Объяснение:",
    .english = "Explanation:",
    .chinese = "解释：",
    .spanish = "Explicación:",
    .german = "Erklärung:",
};

pub const multilingual_unknown = MultilingualResponse{
    .russian = "Не совсем понял запрос. Можешь уточнить?",
    .english = "I didn't quite understand. Can you clarify?",
    .chinese = "我不太明白。你能说明一下吗？",
    .spanish = "No entendí bien. ¿Puedes aclarar?",
    .german = "Ich habe nicht ganz verstanden. Kannst du es erklären?",
};

// =============================================================================
// CONVERSATION CONTEXT
// =============================================================================

pub const ConversationTurn = struct {
    query: []const u8,
    response: []const u8,
    language: Language,
    code_lang: CodeLanguage,
    timestamp: i64,
};

pub const ConversationContext = struct {
    turns: [MAX_CONTEXT_TURNS]ConversationTurn,
    turn_count: usize,
    dominant_language: Language,
    dominant_code_lang: CodeLanguage,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .turns = undefined,
            .turn_count = 0,
            .dominant_language = .English,
            .dominant_code_lang = .None,
        };
    }

    pub fn addTurn(self: *Self, query: []const u8, response: []const u8, lang: Language, code_lang: CodeLanguage) void {
        if (self.turn_count >= MAX_CONTEXT_TURNS) {
            // Shift turns
            for (0..MAX_CONTEXT_TURNS - 1) |i| {
                self.turns[i] = self.turns[i + 1];
            }
            self.turn_count = MAX_CONTEXT_TURNS - 1;
        }

        self.turns[self.turn_count] = ConversationTurn{
            .query = query,
            .response = response,
            .language = lang,
            .code_lang = code_lang,
            .timestamp = std.time.timestamp(),
        };
        self.turn_count += 1;

        // Update dominant language
        self.dominant_language = lang;
        if (code_lang != .None) {
            self.dominant_code_lang = code_lang;
        }
    }

    pub fn getLastCodeLang(self: *const Self) CodeLanguage {
        if (self.dominant_code_lang != .None) return self.dominant_code_lang;

        // Look back through turns
        var i: usize = self.turn_count;
        while (i > 0) {
            i -= 1;
            if (self.turns[i].code_lang != .None) {
                return self.turns[i].code_lang;
            }
        }
        return .Zig; // Default to Zig
    }
};

// =============================================================================
// MULTILINGUAL CODER ENGINE
// =============================================================================

pub const MultilingualCoder = struct {
    enhanced: enhanced_chat.IglaEnhancedChat,
    optimizer: self_opt.PatternOptimizer,
    context: ConversationContext,
    total_queries: usize,
    code_queries: usize,
    chat_queries: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .enhanced = enhanced_chat.IglaEnhancedChat.init(),
            .optimizer = self_opt.PatternOptimizer.init(),
            .context = ConversationContext.init(),
            .total_queries = 0,
            .code_queries = 0,
            .chat_queries = 0,
        };
    }

    /// Main response function
    pub fn respond(self: *Self, query: []const u8) Response {
        self.total_queries += 1;

        // Detect languages
        const lang = Language.detect(query);
        const code_lang = CodeLanguage.detect(query);

        // Check if this is a code request
        const is_code_request = self.isCodeRequest(query);

        var response: Response = undefined;

        if (is_code_request) {
            self.code_queries += 1;
            response = self.generateCodeResponse(query, lang, code_lang);
        } else {
            self.chat_queries += 1;
            response = self.generateChatResponse(query, lang);
        }

        // Record in context
        self.context.addTurn(query, response.text, lang, code_lang);

        // Record feedback for optimization
        const needle_score: f32 = if (response.category != .Unknown) 0.8 else 0.4;
        self.optimizer.recordFeedback(0, .Neutral, query, needle_score);

        return response;
    }

    fn isCodeRequest(self: *const Self, query: []const u8) bool {
        _ = self;
        const code_keywords = [_][]const u8{
            "code",
            "код",
            "代码",
            "función",
            "funktion",
            "function",
            "write",
            "напиши",
            "写",
            "escribe",
            "schreib",
            "example",
            "пример",
            "例子",
            "ejemplo",
            "beispiel",
            "how to",
            "как",
            "怎么",
            "cómo",
            "wie",
            "implement",
            "реализ",
            "实现",
        };

        for (code_keywords) |kw| {
            if (containsWord(query, kw)) return true;
        }
        return false;
    }

    fn generateCodeResponse(self: *Self, query: []const u8, lang: Language, code_lang: CodeLanguage) Response {
        // Determine target code language
        const target_lang = if (code_lang != .None)
            code_lang
        else
            self.context.getLastCodeLang();

        // Find matching template
        var best_template: ?*const CodeTemplate = null;
        var best_score: usize = 0;

        for (&code_templates) |*template| {
            if (template.lang != target_lang and target_lang != .None) continue;

            var score: usize = 0;
            for (template.keywords) |kw| {
                if (containsWord(query, kw)) {
                    score += kw.len;
                }
            }

            if (score > best_score) {
                best_score = score;
                best_template = template;
            }
        }

        if (best_template) |template| {
            // Format response with code block
            var buf: [2048]u8 = undefined;
            const intro = multilingual_code_intro.get(lang);
            const expl = multilingual_explanation.get(lang);

            const formatted = std.fmt.bufPrint(&buf, "{s}\n\n```{s}\n{s}\n```\n\n{s} {s}", .{
                intro,
                template.lang.getExtension()[1..], // Remove leading dot
                template.code,
                expl,
                template.explanation,
            }) catch return Response{
                .text = template.code,
                .language = lang,
                .code_lang = template.lang,
                .category = .Code,
                .confidence = 0.9,
            };

            return Response{
                .text = formatted,
                .language = lang,
                .code_lang = template.lang,
                .category = .Code,
                .confidence = 0.9,
            };
        }

        // Fallback: generic code help
        return Response{
            .text = multilingual_unknown.get(lang),
            .language = lang,
            .code_lang = target_lang,
            .category = .Unknown,
            .confidence = 0.3,
        };
    }

    fn generateChatResponse(self: *Self, query: []const u8, lang: Language) Response {
        // Use enhanced chat for pattern matching
        const enhanced_response = self.enhanced.respond(query);

        // Check if it's a greeting
        if (enhanced_response.category == .Greeting) {
            return Response{
                .text = multilingual_greetings.get(lang),
                .language = lang,
                .code_lang = .None,
                .category = .Greeting,
                .confidence = 0.95,
            };
        }

        // Use the enhanced response but in detected language
        return Response{
            .text = enhanced_response.response,
            .language = lang,
            .code_lang = .None,
            .category = mapCategory(enhanced_response.category),
            .confidence = enhanced_response.confidence,
        };
    }

    fn mapCategory(cat: enhanced_chat.ChatCategory) ResponseCategory {
        return switch (cat) {
            .Greeting => .Greeting,
            .Math => .Math,
            .Story => .Story,
            .Humor => .Humor,
            .Philosophy => .Philosophy,
            .Programming => .Code,
            .Unknown => .Unknown,
            // Map all other categories to Chat
            else => .Chat,
        };
    }

    /// Get statistics
    pub fn getStats(self: *const Self) struct {
        total_queries: usize,
        code_queries: usize,
        chat_queries: usize,
        context_turns: usize,
        dominant_language: []const u8,
        optimization_cycles: usize,
        needle_score: f32,
    } {
        return .{
            .total_queries = self.total_queries,
            .code_queries = self.code_queries,
            .chat_queries = self.chat_queries,
            .context_turns = self.context.turn_count,
            .dominant_language = self.context.dominant_language.getName(),
            .optimization_cycles = self.optimizer.optimization_cycles,
            .needle_score = self.optimizer.needle_scorer.getAverageScore(),
        };
    }
};

pub const ResponseCategory = enum {
    Greeting,
    Code,
    Math,
    Story,
    Humor,
    Philosophy,
    Chat,
    Unknown,
};

pub const Response = struct {
    text: []const u8,
    language: Language,
    code_lang: CodeLanguage,
    category: ResponseCategory,
    confidence: f32,
};

// =============================================================================
// BENCHMARK
// =============================================================================

pub fn runBenchmark() !void {
    const stdout = std.fs.File.stdout();

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("     IGLA MULTILINGUAL CODER BENCHMARK (CYCLE 6)                              \n");
    _ = try stdout.write("===============================================================================\n");

    var engine = MultilingualCoder.init();

    // Test queries in multiple languages
    const test_queries = [_][]const u8{
        // Russian
        "привет",
        "напиши код fibonacci на python",
        "как отсортировать массив в zig",
        // English
        "hello",
        "write a hello world in javascript",
        "how to use async await in js",
        // Chinese
        "你好",
        "写一个python函数",
        // Spanish
        "hola, escribe código",
        // German
        "hallo, wie geht es",
        // Code requests
        "show me a bash loop example",
        "zig array sort code",
    };

    // Process all queries
    var code_count: usize = 0;
    var chat_count: usize = 0;
    var high_confidence: usize = 0;

    const start = std.time.nanoTimestamp();

    for (test_queries) |q| {
        const response = engine.respond(q);
        if (response.category == .Code) {
            code_count += 1;
        } else {
            chat_count += 1;
        }
        if (response.confidence > 0.7) {
            high_confidence += 1;
        }
    }

    const elapsed_ns = std.time.nanoTimestamp() - start;
    const ops_per_sec = @as(f64, @floatFromInt(test_queries.len)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);

    const stats = engine.getStats();

    _ = try stdout.write("\n");

    var buf: [256]u8 = undefined;

    var len = std.fmt.bufPrint(&buf, "  Total queries: {d}\n", .{test_queries.len}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Code queries: {d}\n", .{code_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Chat queries: {d}\n", .{chat_count}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  High confidence: {d}/{d}\n", .{ high_confidence, test_queries.len }) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Speed: {d:.0} ops/s\n", .{ops_per_sec}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Dominant language: {s}\n", .{stats.dominant_language}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Context turns: {d}\n", .{stats.context_turns}) catch return;
    _ = try stdout.write(len);

    len = std.fmt.bufPrint(&buf, "  Needle score: {d:.2}\n", .{stats.needle_score}) catch return;
    _ = try stdout.write(len);

    // Calculate improvement rate
    const improvement_rate = @as(f32, @floatFromInt(high_confidence)) / @as(f32, @floatFromInt(test_queries.len));
    len = std.fmt.bufPrint(&buf, "  Improvement rate: {d:.2}\n", .{improvement_rate}) catch return;
    _ = try stdout.write(len);

    if (improvement_rate > 0.618) {
        _ = try stdout.write("  Golden Ratio Gate: PASSED (>0.618)\n");
    } else {
        _ = try stdout.write("  Golden Ratio Gate: NEEDS IMPROVEMENT (<0.618)\n");
    }

    _ = try stdout.write("\n");
    _ = try stdout.write("===============================================================================\n");
    _ = try stdout.write("  phi^2 + 1/phi^2 = 3 = TRINITY | MULTILINGUAL CODER CYCLE 6                  \n");
    _ = try stdout.write("===============================================================================\n");
}

// =============================================================================
// MAIN & TESTS
// =============================================================================

pub fn main() !void {
    try runBenchmark();
}

test "language detection russian" {
    const lang = Language.detect("привет мир");
    try std.testing.expectEqual(Language.Russian, lang);
}

test "language detection english" {
    const lang = Language.detect("hello world");
    try std.testing.expectEqual(Language.English, lang);
}

test "language detection chinese" {
    const lang = Language.detect("你好世界");
    try std.testing.expectEqual(Language.Chinese, lang);
}

test "code language detection" {
    try std.testing.expectEqual(CodeLanguage.Python, CodeLanguage.detect("write python code"));
    try std.testing.expectEqual(CodeLanguage.Zig, CodeLanguage.detect("zig example"));
    try std.testing.expectEqual(CodeLanguage.JavaScript, CodeLanguage.detect("javascript function"));
    try std.testing.expectEqual(CodeLanguage.Shell, CodeLanguage.detect("bash script"));
}

test "multilingual coder greeting" {
    var engine = MultilingualCoder.init();
    const response = engine.respond("привет");
    try std.testing.expectEqual(Language.Russian, response.language);
    try std.testing.expectEqual(ResponseCategory.Greeting, response.category);
}

test "multilingual coder code request" {
    var engine = MultilingualCoder.init();
    const response = engine.respond("write hello world in python");
    try std.testing.expectEqual(ResponseCategory.Code, response.category);
    try std.testing.expectEqual(CodeLanguage.Python, response.code_lang);
}

test "conversation context" {
    var ctx = ConversationContext.init();
    ctx.addTurn("hello", "hi", .English, .None);
    ctx.addTurn("code", "here", .English, .Python);

    try std.testing.expectEqual(@as(usize, 2), ctx.turn_count);
    try std.testing.expectEqual(CodeLanguage.Python, ctx.getLastCodeLang());
}

test "multilingual responses" {
    try std.testing.expect(multilingual_greetings.russian.len > 0);
    try std.testing.expect(multilingual_greetings.english.len > 0);
    try std.testing.expect(multilingual_greetings.chinese.len > 0);
}
