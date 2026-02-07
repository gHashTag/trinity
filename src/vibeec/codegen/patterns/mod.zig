// ═══════════════════════════════════════════════════════════════════════════════
// PATTERNS MODULE - Modular Pattern Matching System
// ═══════════════════════════════════════════════════════════════════════════════
//
// PAS (Predictive Algorithmic Systematics) Distribution:
//   D&C (Lifecycle/Control): 31%
//   ALG (Generic/Algorithms): 22%
//   PRE (I/O/Preprocessing): 16%
//   FDT (Data Transform): 13%
//   MLS (ML/Statistics): 6%
//   TEN (VSA/Tensors): 6%
//   HSH (Hashing): 4%
//   PRB (Probabilistic): 2%
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

// Category modules (ordered by PAS frequency)
pub const lifecycle = @import("lifecycle.zig"); // D&C: 31%
pub const generic = @import("generic.zig"); // ALG: 22%
pub const io = @import("io.zig"); // PRE: 16%
pub const data = @import("data.zig"); // FDT: 13%
pub const ml = @import("ml.zig"); // MLS: 6%
pub const vsa = @import("vsa.zig"); // TEN: 6%
pub const dsl = @import("dsl.zig"); // DSL patterns
pub const chat = @import("chat.zig"); // Chat patterns (fluent responses)

// Optimization modules
pub const registry = @import("registry.zig"); // Hash-based lookup
pub const templates = @import("templates.zig"); // Pattern templates
pub const cache = @import("cache.zig"); // Result caching

/// Pattern categories for statistics
pub const Category = enum {
    dsl,
    chat,
    lifecycle,
    generic,
    io,
    data,
    ml,
    vsa,
    unknown,
};

/// Match result with category information
pub const MatchResult = struct {
    matched: bool,
    category: Category,
};

/// Match behavior against all pattern categories
/// Returns true if any pattern matched
/// Optimized: PAS frequency order with early-exit checks
pub fn matchAll(builder: *CodeBuilder, b: *const Behavior) !bool {
    const name = b.name;
    const when_text = b.when;

    // Early-exit: DSL patterns only if '$' in when text
    if (std.mem.indexOf(u8, when_text, "$") != null) {
        if (try dsl.match(builder, b)) return true;
    }

    // PAS frequency order (31% → 22% → 16% → 13% → 6% → 6%)
    // Early-exit hints for common prefixes
    const first_char = if (name.len > 0) name[0] else 0;

    // Chat: respond*, detect*, init/update/maintain Context, processChat
    // Must be checked BEFORE generic patterns to generate fluent responses
    if (first_char == 'r' or first_char == 'd' or first_char == 'i' or
        first_char == 'u' or first_char == 'm' or first_char == 'p' or
        first_char == 'g' or first_char == 'v' or first_char == 'f' or
        first_char == 's' or first_char == 'h')
    {
        if (chat.isChatBehavior(name)) {
            if (try chat.match(builder, b)) return true;
        }
    }

    // Lifecycle: 31% — init, start, stop, reset, create, destroy, enable, disable
    if (first_char == 'i' or first_char == 's' or first_char == 'r' or
        first_char == 'c' or first_char == 'd' or first_char == 'e' or
        first_char == 'p' or first_char == 'f' or first_char == 'u')
    {
        if (try lifecycle.match(builder, b)) return true;
    }

    // Generic: 22% — get, set, add, find, sort, compare, run, build, validate
    if (first_char == 'g' or first_char == 's' or first_char == 'a' or
        first_char == 'f' or first_char == 'r' or first_char == 'b' or
        first_char == 'v' or first_char == 'c' or first_char == 'm' or
        first_char == 'p' or first_char == 'e' or first_char == 'h' or
        first_char == 'l' or first_char == 'q' or first_char == 't' or first_char == 'i')
    {
        if (try generic.match(builder, b)) return true;
    }

    // I/O: 16% — read, write, load, save, store, cache, fetch, send, receive
    if (first_char == 'r' or first_char == 'w' or first_char == 'l' or
        first_char == 's' or first_char == 'c' or first_char == 'f' or
        first_char == 'o' or first_char == 'm' or first_char == 'p')
    {
        if (try io.match(builder, b)) return true;
    }

    // Data: 13% — encode, decode, quantize, pack, compress, serialize, transform
    if (first_char == 'e' or first_char == 'd' or first_char == 'q' or
        first_char == 'p' or first_char == 'c' or first_char == 's' or
        first_char == 't' or first_char == 'n' or first_char == 'f' or
        first_char == 'h' or first_char == 'u')
    {
        if (try data.match(builder, b)) return true;
    }

    // ML: 6% — predict, train, evaluate, learn, infer, forward, backward
    if (first_char == 'p' or first_char == 't' or first_char == 'e' or
        first_char == 'l' or first_char == 'i' or first_char == 'f' or
        first_char == 'b' or first_char == 'a' or first_char == 'c' or
        first_char == 'g' or first_char == 'w' or first_char == 'm' or
        first_char == 's' or first_char == 'r' or first_char == 'o')
    {
        if (try ml.match(builder, b)) return true;
    }

    // VSA: 6% — bind, bundle, unbind, similarity, permute, dot, hamming
    if (first_char == 'b' or first_char == 'u' or first_char == 's' or
        first_char == 'p' or first_char == 'd' or first_char == 'h' or
        first_char == 'c' or first_char == 'r' or first_char == 'o' or
        first_char == 'z' or first_char == 'v' or first_char == 'a')
    {
        if (try vsa.match(builder, b)) return true;
    }

    return false;
}

/// Match behavior and return category information
/// Optimized: Same early-exit logic as matchAll
pub fn matchWithCategory(builder: *CodeBuilder, b: *const Behavior) !MatchResult {
    const when_text = b.when;

    // DSL first if '$' in when
    if (std.mem.indexOf(u8, when_text, "$") != null) {
        if (try dsl.match(builder, b)) return .{ .matched = true, .category = .dsl };
    }

    // Chat patterns first (fluent responses)
    if (chat.isChatBehavior(b.name)) {
        if (try chat.match(builder, b)) return .{ .matched = true, .category = .chat };
    }

    // PAS frequency order
    if (try lifecycle.match(builder, b)) return .{ .matched = true, .category = .lifecycle };
    if (try generic.match(builder, b)) return .{ .matched = true, .category = .generic };
    if (try io.match(builder, b)) return .{ .matched = true, .category = .io };
    if (try data.match(builder, b)) return .{ .matched = true, .category = .data };
    if (try ml.match(builder, b)) return .{ .matched = true, .category = .ml };
    if (try vsa.match(builder, b)) return .{ .matched = true, .category = .vsa };

    return .{ .matched = false, .category = .unknown };
}

/// Get pattern count per category (approximate)
pub fn getPatternCounts() struct {
    dsl: u32,
    chat: u32,
    lifecycle: u32,
    generic: u32,
    io: u32,
    data: u32,
    ml: u32,
    vsa: u32,
    total: u32,
} {
    return .{
        .dsl = 6, // $fs, $http, $json, $crypto, $db, $env
        .chat = 45, // respondGreeting/Farewell/Thanks/Feelings/Weather/Humor/AboutSelf/Unknown (8 × 3 langs = 24 responses) + detectLanguage/Topic/Intent/Mood (4) + context ops (6) + validators (3) + response arrays (8)
        .lifecycle = 18, // init, deinit, start, stop, pause, resume, cancel, reset, cleanup, clear, flush, shutdown, create, destroy, delete, enable, disable, register, unregister
        .generic = 35, // get, set, add, remove, update, find, search, filter, sort, compare, merge, apply, compute, calculate, measure, process, execute, run, build, validate, verify, check, test, benchmark, simulate, handle, list, query, step, sync, task, invoke
        .io = 20, // read, write, load, save, store, retrieve, cache, fetch, import, export, open, close, connect, disconnect, send, receive, stream, mmap, prefetch, memory, recall
        .data = 23, // encode, decode, quantize, dequantize, pack, unpack, compress, serialize, deserialize, transform, convert, normalize, format, parse, token, translate, explain, summarize, extract, split, chunk, fallback, honest, unknown
        .ml = 24, // predict, train, evaluate, learn, adapt, fit, infer, calibrate, accuracy, loss, gradient, backward, forward, weight, evolve, mutate, llm, layer, softmax, relu, gelu, embed, flash, prune, online
        .vsa = 15, // bind, bundle, unbind, similarity, permute, dot, hamming, cosine, distance, random, ones, zeros, sparsity, vector, analogy
        .total = 186, // 141 + 45 chat patterns
    };
}

test "matchAll basic" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);

    const b = Behavior{
        .name = "init",
        .given = "system",
        .when = "start",
        .then = "ready",
    };

    const matched = try matchAll(&builder, &b);
    try testing.expect(matched);
}

test "matchWithCategory" {
    const testing = std.testing;
    var buffer: [4096]u8 = undefined;
    var builder = CodeBuilder.init(&buffer);

    const b = Behavior{
        .name = "predict",
        .given = "input",
        .when = "model ready",
        .then = "output",
    };

    const result = try matchWithCategory(&builder, &b);
    try testing.expect(result.matched);
    try testing.expectEqual(Category.ml, result.category);
}
