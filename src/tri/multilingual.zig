// ============================================================================
// MULTILINGUAL CODE GENERATION - Russian/Chinese/English to Zig
// Generated from specs/tri/multilingual_codegen.vibee via Golden Chain
// phi^2 + 1/phi^2 = 3 = TRINITY
// ============================================================================

const std = @import("std");

// ============================================================================
// TYPES
// ============================================================================

pub const Language = enum {
    russian,
    chinese,
    english,
    unknown,

    pub fn getName(self: Language) []const u8 {
        return switch (self) {
            .russian => "Russian",
            .chinese => "Chinese",
            .english => "English",
            .unknown => "Unknown",
        };
    }

    pub fn getFlag(self: Language) []const u8 {
        return switch (self) {
            .russian => "[RU]",
            .chinese => "[ZH]",
            .english => "[EN]",
            .unknown => "[??]",
        };
    }
};

pub const LanguageDetectionResult = struct {
    language: Language,
    confidence: f64,
    cyrillic_count: u32,
    cjk_count: u32,
    ascii_count: u32,
};

pub const KeywordMapping = struct {
    original: []const u8,
    english: []const u8,
};

// ============================================================================
// RUSSIAN KEYWORD MAPPINGS
// ============================================================================

pub const russian_keywords = [_]KeywordMapping{
    .{ .original = "[CYR:[EN]]to[EN]and[EN]", .english = "function" },
    .{ .original = "[CYR:[EN]]to[EN]and[EN]", .english = "function" },
    .{ .original = "[CYR:[EN]]on[EN]", .english = "variable" },
    .{ .original = "[EN]andto[EN]", .english = "loop" },
    .{ .original = "[EN]with[EN]and", .english = "if" },
    .{ .original = "andon[EN]", .english = "else" },
    .{ .original = "in[EN]in[CYR:[EN]]", .english = "return" },
    .{ .original = "with[CYR:[EN]]to[CYR:[EN]]", .english = "struct" },
    .{ .original = "[EN]withwithandin", .english = "array" },
    .{ .original = "with[CYR:[EN]]to[EN]", .english = "string" },
    .{ .original = "[EN]andwith[EN]", .english = "number" },
    .{ .original = "[CYR:[EN]]", .english = "print" },
    .{ .original = "with[CYR:[EN]]and[EN]into[EN]", .english = "sort" },
    .{ .original = "with[CYR:[EN]]and[EN]into[EN]", .english = "sort" },
    .{ .original = "byandwithto", .english = "search" },
    .{ .original = "[EN]and[EN]on[EN]and", .english = "fibonacci" },
    .{ .original = "[EN]to[CYR:[EN]]and[EN]", .english = "factorial" },
    .{ .original = "on[EN]and[EN]and", .english = "write" },
    .{ .original = "with[CYR:[EN]]", .english = "create" },
    .{ .original = "with[CYR:[EN]]", .english = "make" },
    .{ .original = "[EN]andin[EN]", .english = "hello" },
    .{ .original = "[EN]and[EN]", .english = "world" },
    .{ .original = "for", .english = "for" },
    .{ .original = "byto[EN]", .english = "while" },
    .{ .original = "with[EN]andwith[EN]to", .english = "list" },
    .{ .original = "with[EN]in[CYR:[EN]]", .english = "dictionary" },
    .{ .original = "to[EN]withwith", .english = "class" },
    .{ .original = "method", .english = "method" },
    .{ .original = "[CYR:[EN]]to[EN]", .english = "object" },
    .{ .original = "file", .english = "file" },
    .{ .original = "[EN]and[CYR:[EN]]", .english = "read" },
    .{ .original = "[EN]andwith[CYR:[EN]]", .english = "write" },
    .{ .original = "with[CYR:[EN]]", .english = "sum" },
    .{ .original = "[EN]towithand[CYR:[EN]]", .english = "max" },
    .{ .original = "[EN]and[EN]and[CYR:[EN]]", .english = "min" },
    .{ .original = "[CYR:[EN]]in[EN]to[EN]", .english = "check" },
    .{ .original = "[EN]with[EN]", .english = "test" },
    .{ .original = "to[EN]", .english = "code" },
    .{ .original = "program", .english = "program" },
    .{ .original = "[CYR:[EN]]and[EN]", .english = "algorithm" },
};

// ============================================================================
// CHINESE KEYWORD MAPPINGS
// ============================================================================

pub const chinese_keywords = [_]KeywordMapping{
    .{ .original = "函数", .english = "function" },
    .{ .original = "变量", .english = "variable" },
    .{ .original = "循环", .english = "loop" },
    .{ .original = "如果", .english = "if" },
    .{ .original = "否则", .english = "else" },
    .{ .original = "返回", .english = "return" },
    .{ .original = "结构", .english = "struct" },
    .{ .original = "数组", .english = "array" },
    .{ .original = "字符串", .english = "string" },
    .{ .original = "数字", .english = "number" },
    .{ .original = "打印", .english = "print" },
    .{ .original = "排序", .english = "sort" },
    .{ .original = "搜索", .english = "search" },
    .{ .original = "斐波那契", .english = "fibonacci" },
    .{ .original = "阶乘", .english = "factorial" },
    .{ .original = "写", .english = "write" },
    .{ .original = "创建", .english = "create" },
    .{ .original = "你好", .english = "hello" },
    .{ .original = "世界", .english = "world" },
    .{ .original = "列表", .english = "list" },
    .{ .original = "字典", .english = "dictionary" },
    .{ .original = "类", .english = "class" },
    .{ .original = "方法", .english = "method" },
    .{ .original = "对象", .english = "object" },
    .{ .original = "文件", .english = "file" },
    .{ .original = "读取", .english = "read" },
    .{ .original = "求和", .english = "sum" },
    .{ .original = "最大", .english = "max" },
    .{ .original = "最小", .english = "min" },
    .{ .original = "检查", .english = "check" },
    .{ .original = "测试", .english = "test" },
    .{ .original = "代码", .english = "code" },
    .{ .original = "程序", .english = "program" },
    .{ .original = "算法", .english = "algorithm" },
    .{ .original = "一个", .english = "a" },
};

// ============================================================================
// LANGUAGE DETECTION
// ============================================================================

/// Check if a codepoint is Cyrillic (Russian)
pub fn isCyrillic(codepoint: u21) bool {
    // Cyrillic: U+0400-U+04FF
    // Cyrillic Supplement: U+0500-U+052F
    return (codepoint >= 0x0400 and codepoint <= 0x04FF) or
        (codepoint >= 0x0500 and codepoint <= 0x052F);
}

/// Check if a codepoint is CJK (Chinese/Japanese/Korean)
pub fn isCJK(codepoint: u21) bool {
    // CJK Unified Ideographs: U+4E00-U+9FFF
    // CJK Extension A: U+3400-U+4DBF
    // CJK Extension B: U+20000-U+2A6DF
    return (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or
        (codepoint >= 0x3400 and codepoint <= 0x4DBF) or
        (codepoint >= 0x20000 and codepoint <= 0x2A6DF);
}

/// Detect language from UTF-8 text
pub fn detectLanguage(text: []const u8) LanguageDetectionResult {
    var cyrillic_count: u32 = 0;
    var cjk_count: u32 = 0;
    var ascii_count: u32 = 0;
    var total_chars: u32 = 0;

    var i: usize = 0;
    while (i < text.len) {
        const len = std.unicode.utf8ByteSequenceLength(text[i]) catch {
            i += 1;
            continue;
        };

        if (i + len > text.len) break;

        const codepoint = std.unicode.utf8Decode(text[i .. i + len]) catch {
            i += 1;
            continue;
        };

        if (isCyrillic(codepoint)) {
            cyrillic_count += 1;
        } else if (isCJK(codepoint)) {
            cjk_count += 1;
        } else if (codepoint >= 0x20 and codepoint <= 0x7E) {
            ascii_count += 1;
        }

        total_chars += 1;
        i += len;
    }

    // Determine language based on character counts
    var language: Language = .english;
    var confidence: f64 = 0.5;

    if (total_chars > 0) {
        const total_f: f64 = @floatFromInt(total_chars);
        const cyrillic_ratio = @as(f64, @floatFromInt(cyrillic_count)) / total_f;
        const cjk_ratio = @as(f64, @floatFromInt(cjk_count)) / total_f;

        if (cyrillic_count > cjk_count and cyrillic_count > 0) {
            language = .russian;
            confidence = cyrillic_ratio + 0.3;
        } else if (cjk_count > cyrillic_count and cjk_count > 0) {
            language = .chinese;
            confidence = cjk_ratio + 0.3;
        } else if (ascii_count > 0) {
            language = .english;
            confidence = 0.8;
        } else {
            language = .unknown;
            confidence = 0.3;
        }

        if (confidence > 1.0) confidence = 1.0;
    }

    return .{
        .language = language,
        .confidence = confidence,
        .cyrillic_count = cyrillic_count,
        .cjk_count = cjk_count,
        .ascii_count = ascii_count,
    };
}

// ============================================================================
// KEYWORD EXTRACTION
// ============================================================================

/// Check if text contains a keyword and return its English equivalent
pub fn findKeyword(text: []const u8, mappings: []const KeywordMapping) ?[]const u8 {
    for (mappings) |mapping| {
        if (containsSubstring(text, mapping.original)) {
            return mapping.english;
        }
    }
    return null;
}

/// Simple substring check for UTF-8 text
fn containsSubstring(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    if (needle.len == 0) return true;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
            return true;
        }
    }
    return false;
}

/// Extract programming keywords from multilingual text
pub fn extractKeywords(allocator: std.mem.Allocator, text: []const u8, language: Language) ![][]const u8 {
    var keywords = std.ArrayListUnmanaged([]const u8){};
    errdefer keywords.deinit(allocator);

    const mappings: []const KeywordMapping = switch (language) {
        .russian => &russian_keywords,
        .chinese => &chinese_keywords,
        else => &[_]KeywordMapping{},
    };

    // Check each mapping
    for (mappings) |mapping| {
        if (containsSubstring(text, mapping.original)) {
            // Check if already added
            var found = false;
            for (keywords.items) |kw| {
                if (std.mem.eql(u8, kw, mapping.english)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try keywords.append(allocator, mapping.english);
            }
        }
    }

    // Also extract English words from the text
    var word_start: ?usize = null;
    for (text, 0..) |c, idx| {
        const is_ascii_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
        if (is_ascii_alpha) {
            if (word_start == null) word_start = idx;
        } else {
            if (word_start) |start| {
                const word = text[start..idx];
                if (word.len >= 3) {
                    // Check if it's a programming keyword
                    const lower = try std.ascii.allocLowerString(allocator, word);
                    defer allocator.free(lower);

                    const prog_keywords = [_][]const u8{
                        "function",  "write", "create", "make",   "sort",
                        "search",    "print", "hello",  "world",  "fibonacci",
                        "factorial", "array", "list",   "struct", "class",
                        "loop",      "if",    "else",   "return", "for",
                        "while",     "var",   "const",  "pub",    "fn",
                    };

                    for (prog_keywords) |kw| {
                        if (std.mem.eql(u8, lower, kw)) {
                            var found = false;
                            for (keywords.items) |existing| {
                                if (std.mem.eql(u8, existing, kw)) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                try keywords.append(allocator, kw);
                            }
                            break;
                        }
                    }
                }
                word_start = null;
            }
        }
    }

    return keywords.toOwnedSlice(allocator);
}

// ============================================================================
// PROMPT NORMALIZATION
// ============================================================================

/// Normalize multilingual prompt for code generation
pub fn normalizePrompt(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    const detection = detectLanguage(text);

    // If English, return as-is
    if (detection.language == .english) {
        return try allocator.dupe(u8, text);
    }

    // Extract keywords and build normalized prompt
    const keywords = try extractKeywords(allocator, text, detection.language);
    defer allocator.free(keywords);

    // Build normalized English prompt
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    // Add keywords as English prompt
    for (keywords, 0..) |kw, i| {
        if (i > 0) try result.appendSlice(allocator, " ");
        try result.appendSlice(allocator, kw);
    }

    // If no keywords found, return original
    if (result.items.len == 0) {
        result.deinit(allocator);
        return try allocator.dupe(u8, text);
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// OUTPUT FORMATTING
// ============================================================================

/// Format language detection result for display
pub fn formatDetection(detection: LanguageDetectionResult) [256]u8 {
    var buf: [256]u8 = undefined;
    const len = std.fmt.bufPrint(&buf, "{s} {s} (confidence: {d:.0}%, cyrillic: {d}, cjk: {d}, ascii: {d})", .{
        detection.language.getFlag(),
        detection.language.getName(),
        detection.confidence * 100,
        detection.cyrillic_count,
        detection.cjk_count,
        detection.ascii_count,
    }) catch return buf;
    _ = len;
    return buf;
}

// ============================================================================
// TESTS
// ============================================================================

test "detect Russian" {
    const result = detectLanguage("on[EN]and[EN]and [CYR:[EN]]to[EN]and[EN] [EN]and[EN]on[EN]and");
    try std.testing.expectEqual(Language.russian, result.language);
    try std.testing.expect(result.cyrillic_count > 0);
}

test "detect Chinese" {
    const result = detectLanguage("写一个斐波那契函数");
    try std.testing.expectEqual(Language.chinese, result.language);
    try std.testing.expect(result.cjk_count > 0);
}

test "detect English" {
    const result = detectLanguage("write fibonacci function");
    try std.testing.expectEqual(Language.english, result.language);
    try std.testing.expect(result.ascii_count > 0);
}

test "isCyrillic" {
    try std.testing.expect(isCyrillic(0x0410)); // [EN]
    try std.testing.expect(isCyrillic(0x0430)); // [EN]
    try std.testing.expect(!isCyrillic(0x0041)); // A (Latin)
}

test "isCJK" {
    try std.testing.expect(isCJK(0x4E00)); // 一
    try std.testing.expect(isCJK(0x51FD)); // 函
    try std.testing.expect(!isCJK(0x0041)); // A (Latin)
}

test "extractKeywords Russian" {
    const allocator = std.testing.allocator;
    const keywords = try extractKeywords(allocator, "on[EN]and[EN]and [CYR:[EN]]to[EN]and[EN] [EN]and[EN]on[EN]and", .russian);
    defer allocator.free(keywords);

    try std.testing.expect(keywords.len >= 2);
}

test "containsSubstring" {
    try std.testing.expect(containsSubstring("hello world", "world"));
    try std.testing.expect(containsSubstring("[CYR:[EN]]to[EN]and[EN]", "[CYR:[EN]]to[EN]and[EN]"));
    try std.testing.expect(!containsSubstring("hello", "world"));
}
