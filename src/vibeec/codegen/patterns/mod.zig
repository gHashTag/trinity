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
pub const tensor = @import("tensor.zig"); // Tensor operations (NEW)
pub const inference = @import("inference.zig"); // Inference operations (NEW)
pub const model = @import("model.zig"); // Model operations (NEW)
pub const economic = @import("economic.zig"); // $TRI Economic patterns (NEW v10)
pub const dsl = @import("dsl.zig"); // DSL patterns
pub const chat = @import("chat.zig"); // Chat patterns (fluent responses)
pub const rl = @import("rl.zig"); // RL: raylib GUI/rendering patterns

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
    tensor,
    inference,
    model,
    economic,
    rl,
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

    // Economic: earnTaskReward, stakeTRI, spendTRI, depinStaking, etc.
    // Marketplace: createMarketplaceListing, searchMarketplace, matchAgentToTask, etc.
    // Multi-tenant: multiTenantIsolate, tenantResourceLimit, tenantBilling, etc.
    // Must be checked BEFORE generic patterns to avoid interception
    if (std.mem.indexOf(u8, name, "earn") != null or
        std.mem.indexOf(u8, name, "stake") != null or
        std.mem.indexOf(u8, name, "spend") != null or
        std.mem.indexOf(u8, name, "depin") != null or
        std.mem.indexOf(u8, name, "treasury") != null or
        std.mem.indexOf(u8, name, "reward") != null or
        std.mem.indexOf(u8, name, "fee") != null or
        std.mem.indexOf(u8, name, "governance") != null or
        std.mem.indexOf(u8, name, "hire") != null or
        std.mem.indexOf(u8, name, "terminate") != null or
        std.mem.indexOf(u8, name, "create") != null or
        std.mem.indexOf(u8, name, "marketplace") != null or
        std.mem.indexOf(u8, name, "search") != null or
        std.mem.indexOf(u8, name, "match") != null or
        std.mem.indexOf(u8, name, "accept") != null or
        std.mem.indexOf(u8, name, "reject") != null or
        std.mem.indexOf(u8, name, "multi") != null or
        std.mem.indexOf(u8, name, "tenant") != null or
        std.mem.indexOf(u8, name, "isolate") != null or
        std.mem.indexOf(u8, name, "resource") != null or
        std.mem.indexOf(u8, name, "limit") != null or
        std.mem.indexOf(u8, name, "billing") != null)
    {
        if (try economic.match(builder, b)) return true;
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

    // RL: raylib GUI patterns — draw_*, render_*, handle_mouse, init_window, with_alpha, etc.
    // Must be BEFORE lifecycle to catch init_window before init*
    if (first_char == 'd' or first_char == 'r' or first_char == 'h' or
        first_char == 'i' or first_char == 's' or first_char == 'e' or
        first_char == 'c' or first_char == 'm' or first_char == 'l' or
        first_char == 'u' or first_char == 'g' or first_char == 'w')
    {
        if (rl.isRlBehavior(name)) {
            if (try rl.match(builder, b)) return true;
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

    // Tensor: tensor_create, tensor_add, tensor_mul, tensor_matmul
    if (std.mem.startsWith(u8, name, "tensor")) {
        if (try tensor.match(builder, b)) return true;
    }

    // Inference: forward_pass, backward_pass, attention, feedforward
    if (std.mem.indexOf(u8, name, "forward") != null or
        std.mem.indexOf(u8, name, "backward") != null or
        std.mem.indexOf(u8, name, "attention") != null or
        std.mem.indexOf(u8, name, "feedforward") != null)
    {
        if (try inference.match(builder, b)) return true;
    }

    // Model: load_model, save_model, predict, sample_token
    if (std.mem.startsWith(u8, name, "load_model") or
        std.mem.startsWith(u8, name, "save_model") or
        std.mem.startsWith(u8, name, "sample"))
    {
        if (try model.match(builder, b)) return true;
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

    // RL patterns before lifecycle (to catch init_window before init*)
    if (rl.isRlBehavior(b.name)) {
        if (try rl.match(builder, b)) return .{ .matched = true, .category = .rl };
    }

    // PAS frequency order
    if (try lifecycle.match(builder, b)) return .{ .matched = true, .category = .lifecycle };
    if (try generic.match(builder, b)) return .{ .matched = true, .category = .generic };
    if (try io.match(builder, b)) return .{ .matched = true, .category = .io };
    if (try data.match(builder, b)) return .{ .matched = true, .category = .data };
    if (try ml.match(builder, b)) return .{ .matched = true, .category = .ml };
    if (try vsa.match(builder, b)) return .{ .matched = true, .category = .vsa };
    if (try tensor.match(builder, b)) return .{ .matched = true, .category = .tensor };
    if (try inference.match(builder, b)) return .{ .matched = true, .category = .inference };
    if (try model.match(builder, b)) return .{ .matched = true, .category = .model };
    if (try economic.match(builder, b)) return .{ .matched = true, .category = .economic };

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
    tensor: u32,
    inference: u32,
    model: u32,
    economic: u32,
    rl: u32,
    total: u32,
} {
    return .{
        .dsl = 6, // $fs, $http, $json, $crypto, $db, $env
        .chat = 45, // respondGreeting/Farewell/Thanks/Feelings/Weather/Humor/AboutSelf/Unknown (8 × 3 langs = 24 responses) + detectLanguage/Topic/Intent/Mood (4) + context ops (6) + validators (3) + response arrays (8)
        .lifecycle = 18, // init, deinit, start, stop, pause, resume, cancel, reset, cleanup, clear, flush, shutdown, create, destroy, delete, enable, disable, register, unregister
        .generic = 35, // get, set, add, remove, update, find, search, filter, sort, compare, merge, apply, compute, calculate, measure, process, execute, run, build, validate, verify, check, test, benchmark, simulate, handle, list, query, step, sync, task, invoke
        .io = 23, // read, write, load, save, store, retrieve, cache, fetch, import, export, open, close, connect, disconnect, send, receive, stream, mmap, prefetch, memory, recall + http_client, websocket, sqlite
        .data = 23, // encode, decode, quantize, dequantize, pack, unpack, compress, serialize, deserialize, transform, convert, normalize, format, parse, token, translate, explain, summarize, extract, split, chunk, fallback, honest, unknown
        .ml = 29, // predict, train, evaluate, learn, adapt, fit, infer, calibrate, accuracy, loss, gradient, backward, forward, weight, evolve, mutate, llm, layer, softmax, relu, gelu, embed, flash, prune, online + optimizer_step, kv_cache, rotary_embedding, rms_norm, scheduler
        .vsa = 19, // bind, bundle, unbind, similarity, permute, dot, hamming, cosine, distance, random, ones, zeros, sparsity, vector, analogy + map, reduce, sequence, permute_optimized
        .tensor = 4, // tensor_create, tensor_add, tensor_mul, tensor_matmul
        .inference = 4, // forward_pass, backward_pass, attention, feedforward
        .model = 4, // load_model, save_model, predict, sample_token
        .economic = 18, // earnTaskReward, stakeTRI, spendTRI, depinStaking, triTreasury, rewardDistribution, feeForTask, governanceVote, hireAgent, terminateAgent, createMarketplaceListing, searchMarketplace, matchAgentToTask, acceptMarketplaceOffer, rejectMarketplaceOffer, multiTenantIsolate, tenantResourceLimit, tenantBilling
        .rl = 57, // Drawing(10) + Text(7) + Input(7) + Window(15) + Color(4) + Audio(2) + Cursor(2) + Texture(1) + Composites(9)
        .total = 285, // Previous 267 + 18 economic patterns (+8 marketplace/multi-tenant)
    };
}

fn testBehavior(name: []const u8) Behavior {
    return Behavior{
        .name = name,
        .given = "test",
        .when = "test",
        .then = "test",
        .implementation = "",
        .test_cases = .{},
    };
}

test "matchAll basic" {
    const testing = std.testing;
    var builder = CodeBuilder.init(testing.allocator);
    defer builder.deinit();

    const b = testBehavior("init");
    const matched = try matchAll(&builder, &b);
    try testing.expect(matched);
}

test "matchWithCategory" {
    const testing = std.testing;
    var builder = CodeBuilder.init(testing.allocator);
    defer builder.deinit();

    const b = testBehavior("predict");
    const result = try matchWithCategory(&builder, &b);
    try testing.expect(result.matched);
    try testing.expectEqual(Category.ml, result.category);
}

test "matchWithCategory: rl patterns dispatched before lifecycle" {
    const testing = std.testing;

    // init_window should match rl, NOT lifecycle
    {
        var builder = CodeBuilder.init(testing.allocator);
        defer builder.deinit();
        const b = testBehavior("init_window");
        const result = try matchWithCategory(&builder, &b);
        try testing.expect(result.matched);
        try testing.expectEqual(Category.rl, result.category);
    }

    // draw_rect should match rl
    {
        var builder = CodeBuilder.init(testing.allocator);
        defer builder.deinit();
        const b = testBehavior("draw_rect");
        const result = try matchWithCategory(&builder, &b);
        try testing.expect(result.matched);
        try testing.expectEqual(Category.rl, result.category);
    }

    // render_panel should match rl
    {
        var builder = CodeBuilder.init(testing.allocator);
        defer builder.deinit();
        const b = testBehavior("render_panel");
        const result = try matchWithCategory(&builder, &b);
        try testing.expect(result.matched);
        try testing.expectEqual(Category.rl, result.category);
    }

    // handle_mouse should match rl, NOT generic
    {
        var builder = CodeBuilder.init(testing.allocator);
        defer builder.deinit();
        const b = testBehavior("handle_mouse");
        const result = try matchWithCategory(&builder, &b);
        try testing.expect(result.matched);
        try testing.expectEqual(Category.rl, result.category);
    }

    // with_alpha should match rl
    {
        var builder = CodeBuilder.init(testing.allocator);
        defer builder.deinit();
        const b = testBehavior("with_alpha");
        const result = try matchWithCategory(&builder, &b);
        try testing.expect(result.matched);
        try testing.expectEqual(Category.rl, result.category);
    }
}

test "matchAll: rl output contains rl.* calls" {
    const testing = std.testing;
    var builder = CodeBuilder.init(testing.allocator);
    defer builder.deinit();

    const b = testBehavior("init_window");
    const matched = try matchAll(&builder, &b);
    try testing.expect(matched);

    const output = builder.getOutput();
    try testing.expect(std.mem.indexOf(u8, output, "rl.InitWindow(") != null);
    try testing.expect(std.mem.indexOf(u8, output, "rl.SetTargetFPS(") != null);
}
