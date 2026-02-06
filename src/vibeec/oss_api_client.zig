// ═══════════════════════════════════════════════════════════════════════════════
// OSS API CLIENT - Hybrid IGLA + External LLM Integration
// Supports: Groq, OpenAI, GPT-OSS-120B compatible endpoints
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHOENIX: u32 = 999;
pub const MAX_TOKENS: u32 = 4096;
pub const DEFAULT_TEMPERATURE: f32 = 0.7;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ApiProvider = enum {
    groq,
    zhipu,
    anthropic,
    cohere,
    openai,
    custom,

    pub fn getBaseUrl(self: ApiProvider) []const u8 {
        return switch (self) {
            .groq => "https://api.groq.com/openai/v1",
            .zhipu => "https://open.bigmodel.cn/api/coding/paas/v4",
            .anthropic => "https://api.anthropic.com/v1",
            .cohere => "https://api.cohere.ai/v1",
            .openai => "https://api.openai.com/v1",
            .custom => "",
        };
    }

    pub fn getDefaultModel(self: ApiProvider) []const u8 {
        return switch (self) {
            .groq => "llama-3.3-70b-versatile",
            .zhipu => "glm-4",
            .anthropic => "claude-3-5-sonnet-20241022",
            .cohere => "command-r-plus",
            .openai => "gpt-4o-mini",
            .custom => "gpt-oss-120b",
        };
    }

    pub fn getContextLimit(self: ApiProvider) u32 {
        return switch (self) {
            .groq => 128000, // 128K
            .zhipu => 200000, // 200K
            .anthropic => 200000, // 200K
            .cohere => 128000, // 128K
            .openai => 128000, // 128K
            .custom => 32000, // 32K default
        };
    }

    pub fn getAvgSpeed(self: ApiProvider) u32 {
        return switch (self) {
            .groq => 227, // tok/s (tested)
            .zhipu => 70, // tok/s (tested)
            .anthropic => 80, // tok/s (estimated)
            .cohere => 100, // tok/s (estimated)
            .openai => 80, // tok/s (estimated)
            .custom => 50, // tok/s (estimated)
        };
    }

    pub fn getCostPer1MTokens(self: ApiProvider) f32 {
        return switch (self) {
            .groq => 0.59, // FREE tier available
            .zhipu => 1.0, // Estimated
            .anthropic => 15.0, // Claude 3.5 Sonnet
            .cohere => 3.0, // Command R+
            .openai => 15.0, // GPT-4o-mini
            .custom => 0.0, // Custom/local
        };
    }

    pub fn hasFreeTier(self: ApiProvider) bool {
        return switch (self) {
            .groq => true, // 1K req/day
            .zhipu => false,
            .anthropic => false,
            .cohere => true, // Limited free tier
            .openai => false,
            .custom => true, // Local = free
        };
    }
};

pub const ApiConfig = struct {
    provider: ApiProvider,
    api_key: []const u8,
    base_url: []const u8,
    model: []const u8,
    timeout_ms: u32 = 30000,

    pub fn forGroq(api_key: []const u8) ApiConfig {
        return .{
            .provider = .groq,
            .api_key = api_key,
            .base_url = ApiProvider.groq.getBaseUrl(),
            .model = ApiProvider.groq.getDefaultModel(),
        };
    }

    pub fn forOpenAI(api_key: []const u8) ApiConfig {
        return .{
            .provider = .openai,
            .api_key = api_key,
            .base_url = ApiProvider.openai.getBaseUrl(),
            .model = ApiProvider.openai.getDefaultModel(),
        };
    }

    pub fn forCustom(api_key: []const u8, base_url: []const u8, model: []const u8) ApiConfig {
        return .{
            .provider = .custom,
            .api_key = api_key,
            .base_url = base_url,
            .model = model,
        };
    }

    pub fn forZhipu(api_key: []const u8) ApiConfig {
        return .{
            .provider = .zhipu,
            .api_key = api_key,
            .base_url = ApiProvider.zhipu.getBaseUrl(),
            .model = ApiProvider.zhipu.getDefaultModel(),
        };
    }

    pub fn forAnthropic(api_key: []const u8) ApiConfig {
        return .{
            .provider = .anthropic,
            .api_key = api_key,
            .base_url = ApiProvider.anthropic.getBaseUrl(),
            .model = ApiProvider.anthropic.getDefaultModel(),
        };
    }

    pub fn forCohere(api_key: []const u8) ApiConfig {
        return .{
            .provider = .cohere,
            .api_key = api_key,
            .base_url = ApiProvider.cohere.getBaseUrl(),
            .model = ApiProvider.cohere.getDefaultModel(),
        };
    }
};

/// Detected language type
pub const Language = enum {
    english,
    chinese,
    japanese,
    korean,
    russian,
    arabic,
    other,

    pub fn needsSpecialProvider(self: Language) bool {
        return switch (self) {
            .chinese => true, // Zhipu preferred
            .japanese, .korean => true, // CJK models preferred
            .russian, .arabic => false, // Standard providers OK
            .english, .other => false,
        };
    }
};

/// Check if text contains Chinese characters (CJK Unified Ideographs)
pub fn containsChinese(text: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        // UTF-8 Chinese characters start with 0xE4-0xE9
        if (c >= 0xE4 and c <= 0xE9 and i + 2 < text.len) {
            // CJK Unified Ideographs: U+4E00 to U+9FFF
            // In UTF-8: E4 B8 80 to E9 BF BF
            return true;
        }
        // Advance to next character
        if (c < 0x80) {
            i += 1;
        } else if (c < 0xE0) {
            i += 2;
        } else if (c < 0xF0) {
            i += 3;
        } else {
            i += 4;
        }
    }
    return false;
}

/// Check if text contains Japanese Hiragana/Katakana
pub fn containsJapanese(text: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        // Hiragana: U+3040-U+309F (E3 81 80 - E3 82 9F)
        // Katakana: U+30A0-U+30FF (E3 82 A0 - E3 83 BF)
        if (c == 0xE3 and i + 2 < text.len) {
            const c2 = text[i + 1];
            if ((c2 >= 0x81 and c2 <= 0x83)) {
                return true;
            }
        }
        if (c < 0x80) {
            i += 1;
        } else if (c < 0xE0) {
            i += 2;
        } else if (c < 0xF0) {
            i += 3;
        } else {
            i += 4;
        }
    }
    return false;
}

/// Check if text contains Korean Hangul
pub fn containsKorean(text: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        // Hangul Syllables: U+AC00-U+D7A3 (EA B0 80 - ED 9E A3)
        if ((c >= 0xEA and c <= 0xED) and i + 2 < text.len) {
            return true;
        }
        if (c < 0x80) {
            i += 1;
        } else if (c < 0xE0) {
            i += 2;
        } else if (c < 0xF0) {
            i += 3;
        } else {
            i += 4;
        }
    }
    return false;
}

/// Check if text contains Cyrillic (Russian, etc.)
pub fn containsCyrillic(text: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        // Cyrillic: U+0400-U+04FF (D0 80 - D3 BF)
        if ((c == 0xD0 or c == 0xD1 or c == 0xD2 or c == 0xD3) and i + 1 < text.len) {
            return true;
        }
        if (c < 0x80) {
            i += 1;
        } else if (c < 0xE0) {
            i += 2;
        } else if (c < 0xF0) {
            i += 3;
        } else {
            i += 4;
        }
    }
    return false;
}

/// Detect primary language in text
pub fn detectLanguage(text: []const u8) Language {
    if (containsChinese(text)) return .chinese;
    if (containsJapanese(text)) return .japanese;
    if (containsKorean(text)) return .korean;
    if (containsCyrillic(text)) return .russian;
    return .english; // Default
}

/// Estimate tokens in text (rough: 4 chars = 1 token English, 2 chars = 1 token Chinese)
pub fn estimateTokens(text: []const u8) u32 {
    // Simplified: count UTF-8 characters
    var char_count: u32 = 0;
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        char_count += 1;
        if (c < 0x80) {
            i += 1;
        } else if (c < 0xE0) {
            i += 2;
        } else if (c < 0xF0) {
            i += 3;
        } else {
            i += 4;
        }
    }
    return char_count / 3; // Rough average
}

/// Provider selection criteria
pub const SelectionCriteria = struct {
    prefer_speed: bool = true,
    prefer_free: bool = true,
    prefer_quality: bool = false,
    max_cost_per_1m: f32 = 100.0,
};

/// Select best provider based on prompt characteristics
pub fn selectProvider(text: []const u8, context_length: u32) ApiProvider {
    return selectProviderAdvanced(text, context_length, .{});
}

/// Advanced provider selection with criteria
pub fn selectProviderAdvanced(text: []const u8, context_length: u32, criteria: SelectionCriteria) ApiProvider {
    const lang = detectLanguage(text);
    const total_tokens = estimateTokens(text) + context_length;

    // CJK languages → Zhipu (native support)
    if (lang == .chinese or lang == .japanese or lang == .korean) {
        return .zhipu;
    }

    // Long context → Zhipu or Anthropic (200K)
    if (total_tokens > ApiProvider.groq.getContextLimit()) {
        if (criteria.prefer_free or criteria.prefer_speed) {
            return .zhipu; // 200K, cheaper
        } else {
            return .anthropic; // 200K, higher quality
        }
    }

    // Quality preference → Anthropic
    if (criteria.prefer_quality and !criteria.prefer_free) {
        return .anthropic;
    }

    // Free tier preference → Groq or Cohere
    if (criteria.prefer_free) {
        if (criteria.prefer_speed) {
            return .groq; // 227 tok/s, FREE
        } else {
            return .cohere; // FREE tier available
        }
    }

    // Default: Groq (fastest: 227 tok/s)
    return .groq;
}

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatRequest = struct {
    messages: []const Message,
    max_tokens: u32 = 1024,
    temperature: f32 = DEFAULT_TEMPERATURE,
    stream: bool = false,
};

pub const ChatResponse = struct {
    content: []const u8,
    tokens_used: u32,
    model: []const u8,
    finish_reason: []const u8,
};

pub const HybridRequest = struct {
    task: []const u8,
    use_igla_planning: bool = true,
    use_oss_generation: bool = true,
    phi_precision: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Verify φ² + 1/φ² = 3 (Trinity Identity)
pub fn verifyPhiIdentity() f64 {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    return phi_sq + inv_phi_sq; // Should be 3.0
}

/// Check if text is coherent (not garbage)
pub fn verifyCoherence(text: []const u8) bool {
    if (text.len < 10) return false;

    // Count valid ASCII characters
    var valid_chars: usize = 0;
    var spaces: usize = 0;
    for (text) |c| {
        if (c >= 32 and c <= 126) valid_chars += 1;
        if (c == ' ') spaces += 1;
    }

    const valid_ratio = @as(f64, @floatFromInt(valid_chars)) / @as(f64, @floatFromInt(text.len));
    const space_ratio = @as(f64, @floatFromInt(spaces)) / @as(f64, @floatFromInt(text.len));

    // Coherent text should have >90% valid ASCII and 5-35% spaces
    return valid_ratio > 0.9 and space_ratio > 0.05 and space_ratio < 0.35;
}

/// Build JSON request body for chat completion (uses fixed buffer)
pub fn buildChatRequestJson(
    buffer: []u8,
    model: []const u8,
    messages: []const Message,
    max_tokens: u32,
    temperature: f32,
) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try writer.print("{{\"model\":\"{s}\",\"messages\":[", .{model});

    for (messages, 0..) |msg, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.print("{{\"role\":\"{s}\",\"content\":\"", .{msg.role});
        // Escape content
        for (msg.content) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
        try writer.writeAll("\"}");
    }

    try writer.print("],\"max_tokens\":{d},\"temperature\":{d:.2}}}", .{ max_tokens, temperature });

    return stream.getWritten();
}

/// Generate IGLA symbolic plan (uses fixed buffer)
pub fn generateIglaPlan(buffer: []u8, task: []const u8) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try writer.writeAll("## IGLA Symbolic Plan\n\n");
    try writer.print("Task: {s}\n\n", .{task});
    try writer.writeAll("### Steps:\n");
    try writer.writeAll("1. Parse input requirements\n");
    try writer.writeAll("2. Apply φ-constraints if needed\n");
    try writer.writeAll("3. Execute symbolic reasoning\n");
    try writer.writeAll("4. Validate output coherence\n");
    try writer.writeAll("\n### Sacred Formula: φ² + 1/φ² = 3\n");

    return stream.getWritten();
}

/// Parse content from JSON response
pub fn parseContentFromJson(response: []const u8, buffer: []u8) ![]u8 {
    // Find "content":"..." pattern
    const content_marker = "\"content\":\"";
    const start_idx = std.mem.indexOf(u8, response, content_marker) orelse return error.ContentNotFound;
    const content_start = start_idx + content_marker.len;

    // Find closing quote (handling escapes)
    var i: usize = content_start;
    var out_idx: usize = 0;
    while (i < response.len and out_idx < buffer.len) {
        if (response[i] == '\\' and i + 1 < response.len) {
            // Handle escape sequence
            switch (response[i + 1]) {
                'n' => buffer[out_idx] = '\n',
                'r' => buffer[out_idx] = '\r',
                't' => buffer[out_idx] = '\t',
                '"' => buffer[out_idx] = '"',
                '\\' => buffer[out_idx] = '\\',
                else => {
                    buffer[out_idx] = response[i + 1];
                },
            }
            i += 2;
            out_idx += 1;
        } else if (response[i] == '"') {
            break;
        } else {
            buffer[out_idx] = response[i];
            i += 1;
            out_idx += 1;
        }
    }

    return buffer[0..out_idx];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "phi identity equals 3" {
    const result = verifyPhiIdentity();
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), result, 0.0001);
}

test "coherence check passes for valid text" {
    try std.testing.expect(verifyCoherence("The future of AI is bright and promising."));
}

test "coherence check fails for short text" {
    try std.testing.expect(!verifyCoherence("xyz"));
}

test "coherence check fails for no spaces" {
    try std.testing.expect(!verifyCoherence("abcdefghijklmnopqrstuvwxyz1234567890"));
}

test "api config for groq" {
    const config = ApiConfig.forGroq("test-key");
    try std.testing.expectEqualStrings("llama-3.3-70b-versatile", config.model);
    try std.testing.expectEqualStrings("https://api.groq.com/openai/v1", config.base_url);
}

test "api config for openai" {
    const config = ApiConfig.forOpenAI("test-key");
    try std.testing.expectEqualStrings("gpt-4o-mini", config.model);
    try std.testing.expectEqualStrings("https://api.openai.com/v1", config.base_url);
}

test "igla plan generation" {
    var buffer: [4096]u8 = undefined;
    const plan = try generateIglaPlan(&buffer, "solve 2+2");

    try std.testing.expect(std.mem.indexOf(u8, plan, "IGLA") != null);
    try std.testing.expect(std.mem.indexOf(u8, plan, "solve 2+2") != null);
}

test "chat request json building" {
    var buffer: [4096]u8 = undefined;
    const messages = [_]Message{
        .{ .role = "user", .content = "Hello" },
    };

    const json = try buildChatRequestJson(&buffer, "gpt-4", &messages, 100, 0.7);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"model\":\"gpt-4\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"content\":\"Hello\"") != null);
}

test "parse content from json" {
    const response =
        \\{"choices":[{"message":{"content":"Hello world!"}}]}
    ;
    var buffer: [1024]u8 = undefined;
    const content = try parseContentFromJson(response, &buffer);
    try std.testing.expectEqualStrings("Hello world!", content);
}

test "api config for zhipu" {
    const config = ApiConfig.forZhipu("test-key");
    try std.testing.expectEqualStrings("glm-4", config.model);
    try std.testing.expectEqualStrings("https://open.bigmodel.cn/api/coding/paas/v4", config.base_url);
}

test "zhipu context limit is 200K" {
    try std.testing.expectEqual(@as(u32, 200000), ApiProvider.zhipu.getContextLimit());
}

test "groq is faster than zhipu" {
    try std.testing.expect(ApiProvider.groq.getAvgSpeed() > ApiProvider.zhipu.getAvgSpeed());
}

test "chinese detection" {
    // Chinese text (你好 = hello in Chinese)
    try std.testing.expect(containsChinese("你好世界"));
    // English only
    try std.testing.expect(!containsChinese("Hello world"));
    // Mixed
    try std.testing.expect(containsChinese("Hello 你好"));
}

test "provider selection for chinese" {
    try std.testing.expectEqual(ApiProvider.zhipu, selectProvider("用中文解释", 0));
}

test "provider selection for english" {
    try std.testing.expectEqual(ApiProvider.groq, selectProvider("explain in english", 0));
}

test "provider selection for long context" {
    // Force long context by setting context_length > 128K
    try std.testing.expectEqual(ApiProvider.zhipu, selectProvider("short prompt", 150000));
}

test "api config for anthropic" {
    const config = ApiConfig.forAnthropic("test-key");
    try std.testing.expectEqualStrings("claude-3-5-sonnet-20241022", config.model);
    try std.testing.expectEqualStrings("https://api.anthropic.com/v1", config.base_url);
}

test "api config for cohere" {
    const config = ApiConfig.forCohere("test-key");
    try std.testing.expectEqualStrings("command-r-plus", config.model);
    try std.testing.expectEqualStrings("https://api.cohere.ai/v1", config.base_url);
}

test "groq has free tier" {
    try std.testing.expect(ApiProvider.groq.hasFreeTier());
    try std.testing.expect(ApiProvider.cohere.hasFreeTier());
    try std.testing.expect(!ApiProvider.anthropic.hasFreeTier());
}

test "anthropic context is 200K" {
    try std.testing.expectEqual(@as(u32, 200000), ApiProvider.anthropic.getContextLimit());
}

test "language detection chinese" {
    try std.testing.expectEqual(Language.chinese, detectLanguage("你好世界"));
}

test "language detection russian" {
    try std.testing.expectEqual(Language.russian, detectLanguage("Привет мир"));
}

test "language detection english" {
    try std.testing.expectEqual(Language.english, detectLanguage("Hello world"));
}

test "advanced provider selection quality" {
    const criteria = SelectionCriteria{ .prefer_quality = true, .prefer_free = false };
    try std.testing.expectEqual(ApiProvider.anthropic, selectProviderAdvanced("high quality task", 0, criteria));
}

test "advanced provider selection free" {
    const criteria = SelectionCriteria{ .prefer_free = true, .prefer_speed = true };
    try std.testing.expectEqual(ApiProvider.groq, selectProviderAdvanced("fast task", 0, criteria));
}
