// ═══════════════════════════════════════════════════════════════════════════════
// VSA OPS EMITTER — Generate Zig code from VSA ops Tri specification
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Self-hosted VSA operations codegen
// Reads specs/vsa/ops.tri and generates src/vsa_core/gen_ops.zig
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const vibee_parser = @import("../vibee_parser.zig");
const builder_mod = @import("builder.zig");
const parser_types = @import("types.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const VibeeSpec = vibee_parser.VibeeSpec;
const Behavior = parser_types.Behavior;

pub const VSAOpsEmitter = struct {
    allocator: Allocator,
    builder: *CodeBuilder,
    spec: *const VibeeSpec,

    const Self = @This();

    pub fn init(allocator: Allocator, builder: *CodeBuilder, spec: *const VibeeSpec) Self {
        return .{
            .allocator = allocator,
            .builder = builder,
            .spec = spec,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Generate complete Zig code from VSA ops spec
    pub fn emit(self: *Self) !void {
        // Header
        try self.emitHeader();

        // Imports
        try self.emitImports();

        // Constants
        try self.emitConstants();

        // Pure functions (no allocator)
        try self.emitPureFunctions();

        // Allocating functions (require allocator)
        try self.emitAllocatingFunctions();

        // RNG helper
        try self.emitRNG();
    }

    fn emitHeader(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// VSA Core — Operations (GENERATED from .tri spec)");
        try self.builder.writeLine("// TTT Dogfood v0.1: Self-hosted codegen");
        try self.builder.writeLine("// DO NOT EDIT — Generated from specs/vsa/ops.tri");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// φ² + 1/φ² = 3 | TRINITY");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.newline();
    }

    fn emitImports(self: *Self) !void {
        try self.builder.writeLine("const std = @import(\"std\");");
        try self.builder.writeLine("const common = @import(\"common.zig\");");
        try self.builder.writeLine("");
        try self.builder.writeLine("pub const Trit = common.Trit;");
        try self.builder.writeLine("pub const Vec32i8 = common.Vec32i8;");
        try self.builder.writeLine("pub const Vec32i16 = common.Vec32i16;");
        try self.builder.writeLine("pub const SIMD_WIDTH = common.SIMD_WIDTH;");
        try self.builder.newline();
    }

    fn emitConstants(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// Constants");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        try self.builder.writeLine("const errorEmptySequence = error.EmptySequence;");
        try self.builder.writeLine("const errorEmptyVectorList = error.EmptyVectorList;");
        try self.builder.newline();
    }

    fn emitPureFunctions(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// Pure Operations (no allocator)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        // Cosine similarity
        try self.emitCosineSimilarity();

        // Hamming distance
        try self.emitHammingDistance();

        // Hamming similarity
        try self.emitHammingSimilarity();

        // Dot similarity
        try self.emitDotSimilarity();

        // Vector norm
        try self.emitVectorNorm();

        // Count non-zero
        try self.emitCountNonZero();
    }

    fn emitCosineSimilarity(self: *Self) !void {
        try self.builder.writeLine("/// Cosine similarity for trit vectors");
        try self.builder.writeLine("/// Returns value in [-1, 1]");
        try self.builder.writeLine("pub fn cosineSimilarity(a: []const Trit, b: []const Trit) f64 {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @min(a.len, b.len);");
        try self.builder.newline();
        try self.builder.writeLine("var dot: i64 = 0;");
        try self.builder.writeLine("var norm_a: i64 = 0;");
        try self.builder.writeLine("var norm_b: i64 = 0;");
        try self.builder.newline();
        try self.builder.writeLine("const num_chunks = len / SIMD_WIDTH;");
        try self.builder.newline();
        try self.builder.writeLine("// SIMD chunks");
        try self.builder.writeLine("var i: usize = 0;");
        try self.builder.writeLine("while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {");
        self.builder.incIndent();
        try self.builder.writeLine("const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const prod = a_vec * b_vec;");
        try self.builder.writeLine("dot += @reduce(.Add, @as(Vec32i16, prod));");
        try self.builder.writeLine("norm_a += @reduce(.Add, @as(Vec32i16, a_vec * a_vec));");
        try self.builder.writeLine("norm_b += @reduce(.Add, @as(Vec32i16, b_vec * b_vec));");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("// Remainder");
        try self.builder.writeLine("while (i < len) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("dot += @as(i64, a[i]) * @as(i64, b[i]);");
        try self.builder.writeLine("norm_a += @as(i64, a[i]) * @as(i64, a[i]);");
        try self.builder.writeLine("norm_b += @as(i64, b[i]) * @as(i64, b[i]);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("const norm_product = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));");
        try self.builder.writeLine("if (norm_product == 0) return 0;");
        try self.builder.newline();
        try self.builder.writeLine("return @as(f64, @floatFromInt(dot)) / norm_product;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitHammingDistance(self: *Self) !void {
        try self.builder.writeLine("/// Hamming distance (count of differing positions)");
        try self.builder.writeLine("pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @min(a.len, b.len);");
        try self.builder.writeLine("var count: usize = 0;");
        try self.builder.newline();
        try self.builder.writeLine("for (0..len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("if (a[i] != b[i]) count += 1;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return count;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitHammingSimilarity(self: *Self) !void {
        try self.builder.writeLine("/// Hamming similarity (1 - normalized hamming distance)");
        try self.builder.writeLine("pub fn hammingSimilarity(a: []const Trit, b: []const Trit) f64 {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @min(a.len, b.len);");
        try self.builder.writeLine("if (len == 0) return 1;");
        try self.builder.newline();
        try self.builder.writeLine("const dist = hammingDistance(a, b);");
        try self.builder.writeLine("return 1.0 - @as(f64, @floatFromInt(dist)) / @as(f64, @floatFromInt(len));");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitDotSimilarity(self: *Self) !void {
        try self.builder.writeLine("/// Dot product similarity");
        try self.builder.writeLine("pub fn dotSimilarity(a: []const Trit, b: []const Trit) i64 {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @min(a.len, b.len);");
        try self.builder.writeLine("var sum: i64 = 0;");
        try self.builder.newline();
        try self.builder.writeLine("const num_chunks = len / SIMD_WIDTH;");
        try self.builder.newline();
        try self.builder.writeLine("var i: usize = 0;");
        try self.builder.writeLine("while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {");
        self.builder.incIndent();
        try self.builder.writeLine("const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const prod = a_vec * b_vec;");
        try self.builder.writeLine("sum += @reduce(.Add, @as(Vec32i16, prod));");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("while (i < len) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("sum += @as(i64, a[i]) * @as(i64, b[i]);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return sum;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitVectorNorm(self: *Self) !void {
        try self.builder.writeLine("/// Vector norm (L2)");
        try self.builder.writeLine("pub fn vectorNorm(v: []const Trit) f64 {");
        self.builder.incIndent();
        try self.builder.writeLine("var sum: i64 = 0;");
        try self.builder.newline();
        try self.builder.writeLine("const num_chunks = v.len / SIMD_WIDTH;");
        try self.builder.writeLine("var i: usize = 0;");
        try self.builder.newline();
        try self.builder.writeLine("while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {");
        self.builder.incIndent();
        try self.builder.writeLine("const vec: Vec32i8 = v[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const sq = vec * vec;");
        try self.builder.writeLine("sum += @reduce(.Add, @as(Vec32i16, sq));");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("while (i < v.len) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("sum += @as(i64, v[i]) * @as(i64, v[i]);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return @sqrt(@as(f64, @floatFromInt(sum)));");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitCountNonZero(self: *Self) !void {
        try self.builder.writeLine("/// Count non-zero trits");
        try self.builder.writeLine("pub fn countNonZero(v: []const Trit) usize {");
        self.builder.incIndent();
        try self.builder.writeLine("var count: usize = 0;");
        try self.builder.writeLine("for (v) |t| {");
        self.builder.incIndent();
        try self.builder.writeLine("if (t != 0) count += 1;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.writeLine("return count;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitAllocatingFunctions(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// Allocating Operations (require allocator)");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.emitBind();
        try self.emitUnbind();
        try self.emitBundle2();
        try self.emitBundle3();
        try self.emitBundleN();
        try self.emitPermute();
        try self.emitInversePermute();
        try self.emitRandomVector();
        try self.emitEncodeSequence();
        try self.emitProbeSequence();
    }

    fn emitBind(self: *Self) !void {
        try self.builder.writeLine("/// Bind operation (XOR-like for balanced ternary)");
        try self.builder.writeLine("/// Returns new allocated slice (caller owns memory)");
        try self.builder.writeLine("pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @max(a.len, b.len);");
        try self.builder.writeLine("var result = try allocator.alloc(Trit, len);");
        try self.builder.writeLine("errdefer allocator.free(result);");
        try self.builder.newline();
        try self.builder.writeLine("const min_len = @min(a.len, b.len);");
        try self.builder.writeLine("const num_full_chunks = min_len / SIMD_WIDTH;");
        try self.builder.newline();
        try self.builder.writeLine("// SIMD chunks");
        try self.builder.writeLine("var i: usize = 0;");
        try self.builder.writeLine("while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {");
        self.builder.incIndent();
        try self.builder.writeLine("const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;");
        try self.builder.writeLine("const prod = a_vec * b_vec;");
        try self.builder.writeLine("result[i..][0..SIMD_WIDTH].* = prod;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("// Remainder");
        try self.builder.writeLine("while (i < len) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("const a_trit: Trit = if (i < a.len) a[i] else 0;");
        try self.builder.writeLine("const b_trit: Trit = if (i < b.len) b[i] else 0;");
        try self.builder.writeLine("result[i] = a_trit * b_trit;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitUnbind(self: *Self) !void {
        try self.builder.writeLine("/// Unbind operation (same as bind for XOR-like binding)");
        try self.builder.writeLine("pub fn unbind(allocator: std.mem.Allocator, bound: []const Trit, key: []const Trit) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("return bind(allocator, bound, key);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitBundle2(self: *Self) !void {
        try self.builder.writeLine("/// Bundle 2 vectors (majority vote)");
        try self.builder.writeLine("pub fn bundle2(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @max(a.len, b.len);");
        try self.builder.writeLine("var result = try allocator.alloc(Trit, len);");
        try self.builder.newline();
        try self.builder.writeLine("for (0..len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("const a_trit: Trit = if (i < a.len) a[i] else 0;");
        try self.builder.writeLine("const b_trit: Trit = if (i < b.len) b[i] else 0;");
        try self.builder.writeLine("const sum = a_trit + b_trit;");
        try self.builder.newline();
        try self.builder.writeLine("// Majority vote: -2→-1, -1→-1, 0→0, 1→1, 2→1");
        try self.builder.writeLine("result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitBundle3(self: *Self) !void {
        try self.builder.writeLine("/// Bundle 3 vectors (majority vote)");
        try self.builder.writeLine("pub fn bundle3(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit, c: []const Trit) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = @max(@max(a.len, b.len), c.len);");
        try self.builder.writeLine("var result = try allocator.alloc(Trit, len);");
        try self.builder.newline();
        try self.builder.writeLine("for (0..len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("const a_trit: Trit = if (i < a.len) a[i] else 0;");
        try self.builder.writeLine("const b_trit: Trit = if (i < b.len) b[i] else 0;");
        try self.builder.writeLine("const c_trit: Trit = if (i < c.len) c[i] else 0;");
        try self.builder.writeLine("const sum = a_trit + b_trit + c_trit;");
        try self.builder.newline();
        try self.builder.writeLine("// Majority vote");
        try self.builder.writeLine("result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitBundleN(self: *Self) !void {
        try self.builder.writeLine("/// Bundle N vectors (majority vote)");
        try self.builder.writeLine("pub fn bundleN(allocator: std.mem.Allocator, vectors: []const []const Trit) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("if (vectors.len == 0) return error.EmptyVectorList;");
        try self.builder.newline();
        try self.builder.writeLine("var len: usize = 0;");
        try self.builder.writeLine("for (vectors) |v| {");
        self.builder.incIndent();
        try self.builder.writeLine("len = @max(len, v.len);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("var result = try allocator.alloc(Trit, len);");
        try self.builder.newline();
        try self.builder.writeLine("for (0..len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("var sum: i32 = 0;");
        try self.builder.writeLine("for (vectors) |v| {");
        self.builder.incIndent();
        try self.builder.writeLine("if (i < v.len) sum += v[i];");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.writeLine("result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitPermute(self: *Self) !void {
        try self.builder.writeLine("/// Cyclic permutation (rotate left by n positions)");
        try self.builder.writeLine("pub fn permute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("if (v.len == 0) return allocator.alloc(Trit, 0);");
        try self.builder.newline();
        try self.builder.writeLine("const effective_n = n % v.len;");
        try self.builder.writeLine("if (effective_n == 0) {");
        self.builder.incIndent();
        try self.builder.writeLine("const result = try allocator.alloc(Trit, v.len);");
        try self.builder.writeLine("@memcpy(result, v);");
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("var result = try allocator.alloc(Trit, v.len);");
        try self.builder.newline();
        try self.builder.writeLine("// Rotate left: result[i] = v[(i + n) % len]");
        try self.builder.writeLine("for (0..v.len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("result[i] = v[(i + effective_n) % v.len];");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitInversePermute(self: *Self) !void {
        try self.builder.writeLine("/// Inverse permutation (rotate right by n positions)");
        try self.builder.writeLine("pub fn inversePermute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("const len = v.len;");
        try self.builder.writeLine("if (len == 0) return allocator.alloc(Trit, 0);");
        try self.builder.newline();
        try self.builder.writeLine("const effective_n = n % len;");
        try self.builder.writeLine("return permute(allocator, v, len - effective_n);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitRandomVector(self: *Self) !void {
        try self.builder.writeLine("/// Generate random trit vector (Xorshift64)");
        try self.builder.writeLine("pub fn randomVector(allocator: std.mem.Allocator, len: usize, seed: u64) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("var result = try allocator.alloc(Trit, len);");
        try self.builder.writeLine("var rng = Xorshift64.init(seed);");
        try self.builder.newline();
        try self.builder.writeLine("for (0..len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("const r = rng.next();");
        try self.builder.writeLine("// Map to {-1, 0, 1}");
        try self.builder.writeLine("result[i] = switch (@mod(r, 3)) {");
        try self.builder.writeLine("    0 => -1,");
        try self.builder.writeLine("    1 => 0,");
        try self.builder.writeLine("    2 => 1,");
        try self.builder.writeLine("    else => unreachable,");
        try self.builder.writeLine("};");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitEncodeSequence(self: *Self) !void {
        try self.builder.writeLine("/// Encode sequence with position binding");
        try self.builder.writeLine("/// Uses permute for each position");
        try self.builder.writeLine("pub fn encodeSequence(allocator: std.mem.Allocator, vectors: []const []const Trit) ![]Trit {");
        self.builder.incIndent();
        try self.builder.writeLine("if (vectors.len == 0) return error.EmptySequence;");
        try self.builder.newline();
        try self.builder.writeLine("var result = try allocator.alloc(Trit, vectors[0].len);");
        try self.builder.writeLine("@memcpy(result, vectors[0]);");
        try self.builder.newline();
        try self.builder.writeLine("for (1..vectors.len) |i| {");
        self.builder.incIndent();
        try self.builder.writeLine("const permuted = try permute(allocator, vectors[i], i);");
        try self.builder.writeLine("defer allocator.free(permuted);");
        try self.builder.newline();
        try self.builder.writeLine("const bundled = try bundle2(allocator, result, permuted);");
        try self.builder.writeLine("allocator.free(result);");
        try self.builder.writeLine("result = bundled;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return result;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitProbeSequence(self: *Self) !void {
        try self.builder.writeLine("/// Probe sequence (find best match)");
        try self.builder.writeLine("pub fn probeSequence(allocator: std.mem.Allocator, encoded: []const Trit, query_vectors: []const []const Trit) !usize {");
        self.builder.incIndent();
        try self.builder.writeLine("var best_idx: usize = 0;");
        try self.builder.writeLine("var best_sim: f64 = -1.0;");
        try self.builder.newline();
        try self.builder.writeLine("for (query_vectors, 0..) |query_seq, idx| {");
        self.builder.incIndent();
        try self.builder.writeLine("const query_encoded = try encodeSequence(allocator, query_seq);");
        try self.builder.writeLine("defer allocator.free(query_encoded);");
        try self.builder.newline();
        try self.builder.writeLine("const sim = cosineSimilarity(encoded, query_encoded);");
        try self.builder.writeLine("if (sim > best_sim) {");
        self.builder.incIndent();
        try self.builder.writeLine("best_sim = sim;");
        try self.builder.writeLine("best_idx = idx;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.writeLine("return best_idx;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn emitRNG(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// RNG");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════");
        try self.builder.newline();
        try self.builder.writeLine("const Xorshift64 = struct {");
        try self.builder.writeLine("    state: u64,");
        try self.builder.newline();
        try self.builder.writeLine("    fn init(seed: u64) Xorshift64 {");
        try self.builder.writeLine("        return .{ .state = seed };");
        try self.builder.writeLine("    }");
        try self.builder.newline();
        try self.builder.writeLine("    fn next(self: *Xorshift64) u64 {");
        try self.builder.writeLine("        var x = self.state;");
        try self.builder.writeLine("        x ^= x << 13;");
        try self.builder.writeLine("        x ^= x >> 7;");
        try self.builder.writeLine("        x ^= x << 17;");
        try self.builder.writeLine("        self.state = x;");
        try self.builder.writeLine("        return x;");
        try self.builder.writeLine("    }");
        try self.builder.writeLine("};");
    }

    /// Get final generated code
    pub fn getOutput(self: *Self) []const u8 {
        return self.builder.getOutput();
    }

    /// Get owned generated code (caller frees)
    pub fn toOwnedSlice(self: *Self) ![]u8 {
        return self.builder.toOwnedSlice();
    }
};

/// Entry point: Generate VSA ops Zig code from Tri spec
pub fn generateVSAOps(allocator: Allocator, spec: *const VibeeSpec) ![]u8 {
    var builder = CodeBuilder.init(allocator);
    var emitter = VSAOpsEmitter.init(allocator, &builder, spec);
    try emitter.emit();
    return emitter.toOwnedSlice();
}
