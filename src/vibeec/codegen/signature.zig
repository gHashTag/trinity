// ═══════════════════════════════════════════════════════════════════════════════
// SIGNATURE INFERENCE — Infer function signatures from behavior specs
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const type_resolver = @import("type_resolver.zig");

/// Common return type for signature inference functions
pub const SignatureInfo = struct { params: []const u8, ret: []const u8 };

/// Extract parameter names from phrase like "a and b" or "x, y, z"
pub fn extractParamNames(phrase: []const u8, count: usize) []const []const u8 {
    _ = phrase;
    _ = count;
    // TODO: Implement proper name extraction
    // For now, return default names
    return &[_][]const u8{ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" };
}

/// Parse complex multi-param given patterns
/// Examples: "two Vec3 vectors a and b", "list of probabilities", "multiple agents"
pub fn parseMultiParamGiven(allocator: std.mem.Allocator, given: []const u8, name: []const u8) SignatureInfo {
    // 1. Check for "list of {semantic}" patterns
    if (containsCI(given, "list of")) {
        // SAFE: Only create slice if "list of" is found AND bounds are valid
        if (std.mem.indexOf(u8, given, "list of")) |idx| {
            if (idx + 7 < given.len) {
                const semantic = given[idx + 7 ..]; // Skip "list of "
                const mapped_type = type_resolver.mapSemanticType(semantic);
                return .{ .params = "items: anytype", .ret = mapped_type };
            }
        }
        // Fall through to other patterns if bounds check fails
    }

    // 2. Check for multi-param patterns ("two X", "three Y", etc.)
    if (type_resolver.extractCount(given)) |count| {
        const base_type = type_resolver.extractBaseType(given);

        // Build params string
        if (count == 2) {
            // Try to extract parameter names
            if (containsCI(given, " and ")) {
                // Pattern: "two Vec3 vectors a and b"
                const params = extractNamedParams(allocator, given, base_type, 2) catch null orelse
                    buildDefaultParams(base_type, 2);
                return .{ .params = params, .ret = base_type };
            }
            return .{ .params = buildDefaultParams(base_type, 2), .ret = base_type };
        }

        if (count == 3) {
            // Return array of base_type
            if (containsCI(base_type, "anytype")) {
                return .{ .params = buildDefaultParams(base_type, 3), .ret = "[]anytype" };
            }
            return .{ .params = buildDefaultParams(base_type, 3), .ret = "[]const anytype" };
        }

        return .{ .params = "items: anytype", .ret = "usize" };
    }

    // 3. Fall back to original keyword-based inference
    return inferSignatureFromSpecLegacy(given, name);
}

/// Build default params for given type and count
pub fn buildDefaultParams(base_type: []const u8, count: usize) []const u8 {
    _ = base_type;
    if (count == 1) return "a: anytype";
    if (count == 2) return "a: anytype, b: anytype";
    if (count == 3) return "a: anytype, b: anytype, c: anytype";
    return "items: []const anytype";
}

/// Extract named parameters from given phrase
pub fn extractNamedParams(allocator: std.mem.Allocator, given: []const u8, base_type: []const u8, count: usize) !?[]const u8 {
    _ = count;
    // Look for patterns like "a and b", "x, y, z", etc.
    if (std.mem.indexOf(u8, given, " and ")) |_| {
        // Extract names before and after " and "
        var iter = std.mem.tokenizeScalar(u8, given, ' ');
        var names: [2][]const u8 = undefined;

        var i: usize = 0;
        while (iter.next()) |word| : (i += 1) {
            const trimmed = std.mem.trim(u8, word, &std.ascii.whitespace);
            if (trimmed.len == 0 or containsCI(trimmed, "and")) continue;
            if (i >= 2) break;
            names[i] = trimmed;
        }

        if (names[1].len > 0) {
            // Build params with extracted names
            const param1 = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ names[0], base_type });
            const param2 = try std.fmt.allocPrint(allocator, "{s}: {s}", .{ names[1], base_type });
            defer allocator.free(param1);
            defer allocator.free(param2);
            return try std.fmt.allocPrint(allocator, "{s}, {s}", .{ param1, param2 });
        }
    }
    return null;
}

/// Advanced signature inference with v10.1 complex pattern support
/// Tries new patterns first, falls back to keyword-based matching
pub fn inferSignatureFromSpecAdvanced(allocator: std.mem.Allocator, given: []const u8, then: []const u8, name: []const u8) SignatureInfo {
    // v10.1: Try complex pattern parsing first
    const complex_result = parseMultiParamGiven(allocator, given, name);

    // If complex parsing found a meaningful result (not empty/default), use it
    if (complex_result.params.len > 0 and
        !std.mem.eql(u8, complex_result.params, ""))
    {
        // Use advanced params, but improve return type inference
        const improved_ret = inferReturnTypeAdvanced(then, complex_result.ret);
        return .{ .params = complex_result.params, .ret = improved_ret };
    }

    // Fallback to keyword-based inference (original logic)
    return inferSignatureFromSpecFallback(given, then, name);
}

/// Enhanced return type inference (v10.1)
pub fn inferReturnTypeAdvanced(then: []const u8, default_ret: []const u8) []const u8 {
    // If default is already specific, use it
    if (!std.mem.eql(u8, default_ret, "!void")) {
        return default_ret;
    }

    // Action verbs → void
    if (containsAnyCI(then, &.{ "add to", "send to", "update", "store", "saved", "written" })) {
        return "!void";
    }

    // Result indicators
    if (containsCI(then, "resulting")) {
        // Try to extract type after "resulting"
        if (std.mem.indexOf(u8, then, "resulting")) |idx| {
            const rest = std.mem.trim(u8, then[idx + 9..], " .");
            if (rest.len > 0) {
                const mapped = type_resolver.mapSemanticType(rest);
                if (!std.mem.eql(u8, mapped, rest)) return mapped;
            }
        }
    }

    // Similarity/score → f32
    if (containsAnyCI(then, &.{ "similarity", "score", "accuracy", "probability", "confidence" })) {
        return "f32";
    }

    // Count/size → usize
    if (containsAnyCI(then, &.{ "count", "number of", "size", "length" })) {
        return "usize";
    }

    return default_ret;
}

/// Fallback keyword-based signature inference (original logic preserved)
pub fn inferSignatureFromSpecFallback(given: []const u8, then: []const u8, name: []const u8) SignatureInfo {
    // Import for backward compatibility with original code
    const mem = std.mem;

    // --- Infer params from `given` field keywords ---
    const params: []const u8 = params_blk: {
        if (containsAnyCI(given, &.{ "two vectors", "two ternary vectors", "two hypervectors", "pair of vectors" }))
            break :params_blk "a: []const i8, b_vec: []const i8";
        if (containsAnyCI(given, &.{ "vector and scalar", "vector with threshold" }))
            break :params_blk "vec: []const i8, scalar: i8";
        if (containsAnyCI(given, &.{ "array of", "batch of", "list of", "multiple" }))
            break :params_blk "items: anytype";
        if (containsAnyCI(given, &.{ "input vector", "ternary vector", "hypervector", "a vector" }))
            break :params_blk "input: []const i8";
        if (containsAnyCI(given, &.{ "float array", "weight", "embedding", "float values", "f32" }))
            break :params_blk "values: []const f32";
        if (containsAnyCI(given, &.{ "trained model", "neural network", "model" }))
            break :params_blk "model: anytype";
        if (containsAnyCI(given, &.{ "file path", "file", "path" }))
            break :params_blk "path: []const u8";
        if (containsAnyCI(given, &.{ "allocator" }))
            break :params_blk "allocator: std.mem.Allocator";
        if (containsAnyCI(given, &.{ "queue", "request", "connection", "http" }))
            break :params_blk "request: anytype";
        if (containsAnyCI(given, &.{ "config", "setting", "option", "parameter" }))
            break :params_blk "config: anytype";
        if (containsAnyCI(given, &.{ "token" }))
            break :params_blk "token_ids: []const u32";
        // Cycle 76: Integer exponent / power parameter
        if (containsAnyCI(given, &.{ "exponent", "integer n" }))
            break :params_blk "n: u32";
        if (containsAnyCI(given, &.{ "text", "string", "input", "query", "prompt", "dimension" }))
            break :params_blk "input: []const u8";
        if (containsAnyCI(given, &.{ "data", "bytes", "buffer", "memory" }))
            break :params_blk "data: []const u8";
        if (containsAnyCI(given, &.{ "matrix", "tensor" }))
            break :params_blk "matrix: []const f32, rows: usize, cols: usize";
        if (containsAnyCI(given, &.{ "key" }))
            break :params_blk "key: []const u8";
        if (containsAnyCI(given, &.{ "chainmessage", "from the pipeline" }))
            break :params_blk "msg: ChainMessage";
        if (containsAnyCI(given, &.{ "chatmsgtype", "chat display", "chain-type" }))
            break :params_blk "msg: ChatMsgType";
        if (containsAnyCI(given, &.{ "monitor reports", "adapt node", "min_quality" }))
            break :params_blk "self: *GoldenChainAgent";
        if (containsAnyCI(given, &.{ "no input" }))
            break :params_blk "";
        if (mem.startsWith(u8, name, "get") or mem.startsWith(u8, name, "set") or
            mem.startsWith(u8, name, "is_") or mem.startsWith(u8, name, "has_") or
            mem.startsWith(u8, name, "update") or mem.startsWith(u8, name, "process") or
            mem.startsWith(u8, name, "compute") or mem.startsWith(u8, name, "calculate"))
            break :params_blk "self: *@This()";
        break :params_blk "";
    };

    // --- Infer return type from `then` field keywords ---
    const ret: []const u8 = ret_blk: {
        if (containsAnyCI(then, &.{ "resulting vector", "hypervector", "ternary vector", "output vector", "bound vector", "f32 vector" }))
            break :ret_blk "[]i8";
        if (containsAnyCI(then, &.{ "similarity", "score", "ratio", "accuracy", "probability", "confidence", "compression" }))
            break :ret_blk "f32";
        if (containsAnyCI(then, &.{ "distance", "loss", "error rate" }))
            break :ret_blk "f32";
        if (containsAnyCI(then, &.{ "count", "index", "number of", "size", "length" }))
            break :ret_blk "usize";
        if (containsAnyCI(then, &.{ "encoded", "packed", "compressed", "bytes" }))
            break :ret_blk "[]u8";
        if (containsAnyCI(then, &.{ "float array", "weights", "embeddings", "probabilities", "activations", "quantize", "scale", "dequantiz" }))
            break :ret_blk "[]f32";
        if (containsAnyCI(then, &.{ "boolean", "true or false", "valid", "flag", "returns true", "returns false" }))
            break :ret_blk "bool";
        if (containsAnyCI(then, &.{ "array of", "batch", "responses", "results" }))
            break :ret_blk "!void";
        if (containsAnyCI(then, &.{ "add to", "send ", "update ", "return immediately", "stored", "saved", "written", "completed", "success" }))
            break :ret_blk "!void";
        if (containsAnyCI(then, &.{ "text", "string", "name", "label", "identifier", "response" }))
            break :ret_blk "[]const u8";
        // Cycle 75: Known spec-defined struct returns
        if (containsAnyCI(then, &.{"PhiResult"}))
            break :ret_blk "PhiResult";
        if (containsAnyCI(then, &.{"TritVector"}))
            break :ret_blk "TritVector";
        if (containsAnyCI(then, &.{ "return " }))
            break :ret_blk "!void";
        break :ret_blk "!void";
    };

    return .{ .params = params, .ret = ret };
}

/// Legacy signature inference (original keyword-based, params only)
pub fn inferSignatureFromSpecLegacy(given: []const u8, name: []const u8) SignatureInfo {
    _ = name;
    // Use existing keyword-based logic from below
    const params: []const u8 = params_blk: {
        if (containsAnyCI(given, &.{ "two vectors", "two ternary vectors", "two hypervectors", "pair of vectors" }))
            break :params_blk "a: []const i8, b_vec: []const i8";
        if (containsAnyCI(given, &.{ "vector and scalar", "vector with threshold" }))
            break :params_blk "vec: []const i8, scalar: i8";
        if (containsAnyCI(given, &.{ "array of", "batch of", "list of", "multiple" }))
            break :params_blk "items: anytype";
        if (containsAnyCI(given, &.{ "input vector", "ternary vector", "hypervector", "a vector" }))
            break :params_blk "input: []const i8";
        break :params_blk "";
    };
    return .{ .params = params, .ret = "!void" };
}

/// Infer function signature from behavior given/then fields.
/// Enhanced with types: section support and complex type parsing.
pub fn inferSignatureFromSpec(given: []const u8, then: []const u8, name: []const u8) SignatureInfo {
    const mem = std.mem;

    // --- Infer params from `given` field keywords (case-insensitive via lowercase check) ---
    const params: []const u8 = params_blk: {
        // Two vectors / pair of vectors
        if (containsAnyCI(given, &.{ "two vectors", "two ternary vectors", "two hypervectors", "pair of vectors" }))
            break :params_blk "a: []const i8, b_vec: []const i8";

        // Vector and scalar
        if (containsAnyCI(given, &.{ "vector and scalar", "vector with threshold" }))
            break :params_blk "vec: []const i8, scalar: i8";

        // Array of items / batch
        if (containsAnyCI(given, &.{ "array of", "batch of", "list of", "multiple" }))
            break :params_blk "items: anytype";

        // Input vector / single vector
        if (containsAnyCI(given, &.{ "input vector", "ternary vector", "hypervector", "a vector" }))
            break :params_blk "input: []const i8";

        // Float arrays / weights / embeddings / f32
        if (containsAnyCI(given, &.{ "float array", "weight", "embedding", "float values", "f32" }))
            break :params_blk "values: []const f32";

        // Model / neural network
        if (containsAnyCI(given, &.{ "trained model", "neural network", "model" }))
            break :params_blk "model: anytype";

        // File path
        if (containsAnyCI(given, &.{ "file path", "file", "path" }))
            break :params_blk "path: []const u8";

        // Allocator-based
        if (containsAnyCI(given, &.{ "allocator" }))
            break :params_blk "allocator: std.mem.Allocator";

        // Queue / request / connection
        if (containsAnyCI(given, &.{ "queue", "request", "connection", "http" }))
            break :params_blk "request: anytype";

        // Configuration / settings
        if (containsAnyCI(given, &.{ "config", "setting", "option", "parameter" }))
            break :params_blk "config: anytype";

        // Token / tokens
        if (containsAnyCI(given, &.{ "token" }))
            break :params_blk "token_ids: []const u32";

        // Cycle 76: Integer exponent / power parameter
        if (containsAnyCI(given, &.{ "exponent", "integer n" }))
            break :params_blk "n: u32";

        // Text / string input
        if (containsAnyCI(given, &.{ "text", "string", "input", "query", "prompt", "dimension" }))
            break :params_blk "input: []const u8";

        // Data / bytes / memory
        if (containsAnyCI(given, &.{ "data", "bytes", "buffer", "memory" }))
            break :params_blk "data: []const u8";

        // Matrix / tensor
        if (containsAnyCI(given, &.{ "matrix", "tensor" }))
            break :params_blk "matrix: []const f32, rows: usize, cols: usize";

        // Key-value
        if (containsAnyCI(given, &.{ "key" }))
            break :params_blk "key: []const u8";

        // ChainMessage (golden_chain specific) - exact substrings
        if (containsAnyCI(given, &.{ "chainmessage", "from the pipeline" }))
            break :params_blk "msg: ChainMessage";

        // ChatMsgType / chain-type message
        if (containsAnyCI(given, &.{ "chatmsgtype", "chat display", "chain-type" }))
            break :params_blk "msg: ChatMsgType";

        // GoldenChainAgent (method calls)
        if (containsAnyCI(given, &.{ "monitor reports", "adapt node", "min_quality" }))
            break :params_blk "self: *GoldenChainAgent";

        // No input
        if (containsAnyCI(given, &.{ "no input" }))
            break :params_blk "";

        // Self-based (method naming convention)
        if (mem.startsWith(u8, name, "get") or
            mem.startsWith(u8, name, "set") or
            mem.startsWith(u8, name, "is_") or
            mem.startsWith(u8, name, "has_") or
            mem.startsWith(u8, name, "update") or
            mem.startsWith(u8, name, "process") or
            mem.startsWith(u8, name, "compute") or
            mem.startsWith(u8, name, "calculate"))
            break :params_blk "self: *@This()";

        break :params_blk "";
    };

    // --- Infer return type from `then` field keywords ---
    const ret: []const u8 = ret_blk: {
        // Vector / hypervector result
        if (containsAnyCI(then, &.{ "resulting vector", "hypervector", "ternary vector", "output vector", "bound vector", "f32 vector" }))
            break :ret_blk "[]i8";

        // Similarity / score / ratio
        if (containsAnyCI(then, &.{ "similarity", "score", "ratio", "accuracy", "probability", "confidence", "compression" }))
            break :ret_blk "f32";

        // Distance / loss / error
        if (containsAnyCI(then, &.{ "distance", "loss", "error rate" }))
            break :ret_blk "f32";

        // Integer / count / index
        if (containsAnyCI(then, &.{ "count", "index", "number of", "size", "length" }))
            break :ret_blk "usize";

        // Cycle 76: Known spec-defined struct returns (check BEFORE generic keywords)
        if (containsAnyCI(then, &.{"PhiResult"}))
            break :ret_blk "PhiResult";
        if (containsAnyCI(then, &.{"TritVector"}))
            break :ret_blk "TritVector";

        // Bytes / encoded data
        if (containsAnyCI(then, &.{ "encoded", "packed", "compressed", "bytes" }))
            break :ret_blk "[]u8";

        // Float array / weights / embeddings / quantize / scale
        if (containsAnyCI(then, &.{ "float array", "weights", "embeddings", "probabilities", "activations", "quantize", "scale", "dequantiz" }))
            break :ret_blk "[]f32";

        // Boolean / flag / valid
        if (containsAnyCI(then, &.{ "boolean", "true or false", "valid", "flag", "returns true", "returns false" }))
            break :ret_blk "bool";

        // Array / batch of results
        if (containsAnyCI(then, &.{ "array of", "batch", "responses", "results" }))
            break :ret_blk "!void";

        // Return as void actions (queue/send/update/add/store)
        if (containsAnyCI(then, &.{ "add to", "send ", "update ", "return immediately", "stored", "saved", "written", "completed", "success" }))
            break :ret_blk "!void";

        // Text / string result / metrics
        if (containsAnyCI(then, &.{ "text", "string", "name", "label", "identifier", "response" }))
            break :ret_blk "[]const u8";

        // Return struct (contains "Return X")
        if (containsAnyCI(then, &.{ "return " }))
            break :ret_blk "!void";

        break :ret_blk "!void";
    };

    return .{ .params = params, .ret = ret };
}

// ═══════════════════════════════════════════════════════════════════════════════
// String utilities (used internally)
// ═══════════════════════════════════════════════════════════════════════════════

/// Case-insensitive substring check: does `haystack` contain any of the `needles`?
pub fn containsAnyCI(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (containsCI(haystack, needle)) return true;
    }
    return false;
}

/// Case-insensitive substring search (ASCII only)
pub fn containsCI(haystack: []const u8, needle: []const u8) bool {
    return type_resolver.containsCI(haystack, needle);
}

pub fn toLowerASCII(c: u8) u8 {
    return type_resolver.toLowerASCII(c);
}
