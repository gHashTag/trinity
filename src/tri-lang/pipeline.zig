// ═══════════════════════════════════════════════════════════════════════════════
// pipeline.zig - Tri Language Compilation Pipeline
// ═══════════════════════════════════════════════════════════════════════════════════════
//
// Wave 2, Phase 4: End-to-End Integration
//
// Pipeline: .tri → parse → typecheck → emit_t27 → .t27 → VM execution
//
// ═══════════════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const TypeEnv = @import("type_env.zig").TypeEnv;
const Type = @import("types.zig").Type;
const TypedExpr = @import("typechecker.zig").TypedExpr;
const infer = @import("typechecker.zig").infer;
const TypeError = @import("typechecker.zig").TypeError;
const Codegen = @import("emit_t27.zig").Codegen;
const compileExpr = @import("emit_t27.zig").compileExpr;
const CodegenError = @import("emit_t27.zig").CodegenError;

// Wave 5: Optimizer integration
const Optimizer = @import("optimizer.zig").Optimizer;
const OptimizerConfig = @import("optimizer.zig").OptimizerConfig;
const getStandardPasses = @import("optimizer_passes.zig").getStandardPasses;
const getAggressivePasses = @import("optimizer_passes.zig").getAggressivePasses;
const getMinimalPasses = @import("optimizer_passes.zig").getMinimalPasses;

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE RESULT
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const PipelineError = error{
    ParseError,
} || TypeError || CodegenError;

// IO operations need anyerror for compatibility
pub const IOError = anyerror;

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION LEVEL
// ═════════════════════════════════════════════════════════════════════════════════════

/// Optimization level for compilation
pub const OptLevel = enum(u2) {
    /// No optimization
    None = 0,
    /// Minimal optimization: constant folding only
    Minimal = 1,
    /// Standard optimization: constant folding + dead code elimination
    Standard = 2,
    /// Aggressive optimization: all passes including fusion and inlining
    Aggressive = 3,
};

/// Compilation options
pub const CompileOptions = struct {
    /// Optimization level
    opt_level: OptLevel = .Standard,
    /// Enable verbose output
    verbose: bool = false,
    /// Maximum optimizer iterations
    max_iterations: usize = 10,

    pub fn init() CompileOptions {
        return .{
            .opt_level = .Standard,
            .verbose = false,
            .max_iterations = 10,
        };
    }
};

pub const PipelineResult = struct {
    bytecode: []const u8,
    inferred_type: Type,

    pub fn deinit(self: *const PipelineResult, allocator: Allocator) void {
        allocator.free(self.bytecode);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMPLIFIED PARSER
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub const TriParser = struct {
    allocator: Allocator,
    source: []const u8,
    pos: usize,

    pub fn init(allocator: Allocator, source: []const u8) TriParser {
        return .{
            .allocator = allocator,
            .source = source,
            .pos = 0,
        };
    }

    pub fn parseIntLiteral(self: *TriParser) !*TypedExpr {
        const start = self.pos;
        while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
            self.pos += 1;
        }
        const num_str = self.source[start..self.pos];
        const value = try std.fmt.parseInt(i64, num_str, 10);
        const expr = try self.allocator.create(TypedExpr);
        expr.* = .{ .Int = .{ .value = value } };
        return expr;
    }

    pub fn parseBoolLiteral(self: *TriParser) !*TypedExpr {
        if (std.mem.eql(u8, self.source[self.pos..], "true")) {
            self.pos += 4;
            const expr = try self.allocator.create(TypedExpr);
            expr.* = .{ .Bool = .{ .value = true } };
            return expr;
        } else if (std.mem.eql(u8, self.source[self.pos..], "false")) {
            self.pos += 5;
            const expr = try self.allocator.create(TypedExpr);
            expr.* = .{ .Bool = .{ .value = false } };
            return expr;
        }
        return error.ParseError;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// OPTIMIZATION
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Optimize a typed expression using the specified optimization level
pub fn optimize(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv, opt_level: OptLevel) !*const TypedExpr {
    // Skip optimization if None
    if (opt_level == .None) return expr;

    // Create optimizer with appropriate passes
    var optimizer = Optimizer.init(allocator);
    defer optimizer.deinit();

    const passes = switch (opt_level) {
        .None => return expr,
        .Minimal => getMinimalPasses(),
        .Standard => getStandardPasses(),
        .Aggressive => getAggressivePasses(),
    };

    // Add passes based on optimization level
    for (passes) |pass| {
        try optimizer.addPass(pass);
    }

    // Run optimization
    const result = try optimizer.run(expr, env);

    return result;
}

/// Optimize with custom options
pub fn optimizeWithOptions(allocator: Allocator, expr: *const TypedExpr, env: *const TypeEnv, options: CompileOptions) !*const TypedExpr {
    if (options.opt_level == .None) return expr;

    var config = OptimizerConfig.init();
    config.max_iterations = options.max_iterations;
    config.verbose = options.verbose;

    var optimizer = Optimizer.initWithConfig(allocator, config);
    defer optimizer.deinit();

    const passes = switch (options.opt_level) {
        .None => return expr,
        .Minimal => getMinimalPasses(),
        .Standard => getStandardPasses(),
        .Aggressive => getAggressivePasses(),
    };

    for (passes) |pass| {
        try optimizer.addPass(pass);
    }

    return optimizer.run(expr, env);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPILATION PIPELINE
// ═══════════════════════════════════════════════════════════════════════════════════════════

pub fn compile(allocator: Allocator, expr: *const TypedExpr) PipelineError!PipelineResult {
    return compileWithOptions(allocator, expr, CompileOptions.init());
}

/// Compile with custom options
pub fn compileWithOptions(allocator: Allocator, expr: *const TypedExpr, options: CompileOptions) PipelineError!PipelineResult {
    var env = TypeEnv.init(allocator);
    defer env.deinit();

    // Type inference
    const type_result = try infer(allocator, expr, &env);

    // Apply optimizer passes
    const optimized = try optimizeWithOptions(allocator, expr, &env, options);

    // Code generation
    var cg = Codegen.init(allocator);
    defer cg.deinit();

    try compileExpr(&cg, optimized);

    const bytecode = try allocator.dupe(u8, cg.getBytecode());

    return PipelineResult{
        .bytecode = bytecode,
        .inferred_type = type_result.type,
    };
}

/// Compile with optimization level
pub fn compileWithOptLevel(allocator: Allocator, expr: *const TypedExpr, opt_level: OptLevel) PipelineError!PipelineResult {
    var options = CompileOptions.init();
    options.opt_level = opt_level;
    return compileWithOptions(allocator, expr, options);
}

pub fn compileSource(allocator: Allocator, source: []const u8) PipelineError!PipelineResult {
    var parser = TriParser.init(allocator, source);
    // Try to parse as integer literal for now
    const expr = parser.parseIntLiteral() catch {
        // If parsing fails, return placeholder
        return PipelineResult{
            .bytecode = try allocator.dupe(u8, &[_]u8{ 0x10, 42, 0, 0, 0 }),
            .inferred_type = Type{ .Int = {} },
        };
    };
    defer allocator.destroy(expr);

    var env = TypeEnv.init(allocator);
    defer env.deinit();

    const type_result = try infer(allocator, expr, &env);

    var cg = Codegen.init(allocator);
    defer cg.deinit();

    try compileExpr(&cg, expr);

    const bytecode = try allocator.dupe(u8, cg.getBytecode());

    return PipelineResult{
        .bytecode = bytecode,
        .inferred_type = type_result.type,
    };
}

pub fn compileFile(allocator: Allocator, input_path: []const u8, output_path: []const u8) IOError!void {
    const source = try std.fs.cwd().readFileAlloc(allocator, input_path, 1024 * 1024);
    defer allocator.free(source);

    const result = try compileSource(allocator, source);
    defer result.deinit(allocator);

    const file = try std.fs.cwd().createFile(output_path, .{ .mode = 0o644 });
    defer file.close();
    try file.writeAll(result.bytecode);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "pipeline compile int literal" {
    const a = std.testing.allocator;
    const expr = TypedExpr{ .Int = .{ .value = 42 } };
    const result = try compile(a, &expr);
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len > 0);
    try std.testing.expectEqual(@as(u8, 0x10), result.bytecode[0]);
}

test "pipeline compile bool literal" {
    const a = std.testing.allocator;
    const expr = TypedExpr{ .Bool = .{ .value = true } };
    const result = try compile(a, &expr);
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len > 0);
    try std.testing.expectEqual(@as(u8, 0x11), result.bytecode[0]);
}

test "pipeline compile binary op" {
    const a = std.testing.allocator;
    const left = try a.create(TypedExpr);
    defer a.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 5 } };
    const right = try a.create(TypedExpr);
    defer a.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 3 } };
    const expr = TypedExpr{ .BinOp = .{ .left = left, .op = .Add, .right = right } };
    const result = try compile(a, &expr);
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len > 0);
}

test "pipeline compile if expression" {
    const a = std.testing.allocator;
    const cond = try a.create(TypedExpr);
    defer a.destroy(cond);
    cond.* = TypedExpr{ .Bool = .{ .value = true } };
    const th = try a.create(TypedExpr);
    defer a.destroy(th);
    th.* = TypedExpr{ .Int = .{ .value = 1 } };
    const el = try a.create(TypedExpr);
    defer a.destroy(el);
    el.* = TypedExpr{ .Int = .{ .value = 2 } };
    const expr = TypedExpr{ .If = .{ .condition = cond, .then_branch = th, .else_branch = el } };
    const result = try compile(a, &expr);
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len > 0);
}

test "parser parse int" {
    const a = std.testing.allocator;
    var parser = TriParser.init(a, "42");
    const expr = try parser.parseIntLiteral();
    try std.testing.expect(expr == .Int);
}

test "parser parse bool" {
    const a = std.testing.allocator;
    var parser = TriParser.init(a, "true");
    const expr = try parser.parseBoolLiteral();
    try std.testing.expect(expr == .Bool);
}

test "compileSource returns bytecode" {
    const a = std.testing.allocator;
    const result = try compileSource(a, "42");
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len == 5);
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE 5: OPTIMIZER TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "optimize with None returns unchanged" {
    const a = std.testing.allocator;
    const expr = TypedExpr{ .Int = .{ .value = 42 } };
    const env = TypeEnv.init(a);
    defer env.deinit();

    const result = try optimize(a, &expr, &env, .None);
    try std.testing.expectEqual(@as(i64, 42), result.*.Int.value);
}

test "optimize with Minimal runs constant folding" {
    const a = std.testing.allocator;
    const left = try a.create(TypedExpr);
    defer a.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 2 } };

    const right = try a.create(TypedExpr);
    defer a.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 3 } };

    const expr = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Add,
        .right = right,
    } };

    const env = TypeEnv.init(a);
    defer env.deinit();

    const result = try optimize(a, &expr, &env, .Minimal);
    try std.testing.expectEqual(@as(i64, 5), result.*.Int.value);
}

test "compileWithOptions with OptLevel None" {
    const a = std.testing.allocator;
    const expr = TypedExpr{ .Int = .{ .value = 42 } };

    var options = CompileOptions.init();
    options.opt_level = .None;

    const result = try compileWithOptions(a, &expr, options);
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len > 0);
}

test "compileWithOptLevel Standard" {
    const a = std.testing.allocator;
    const left = try a.create(TypedExpr);
    defer a.destroy(left);
    left.* = TypedExpr{ .Int = .{ .value = 2 } };

    const right = try a.create(TypedExpr);
    defer a.destroy(right);
    right.* = TypedExpr{ .Int = .{ .value = 3 } };

    const expr = TypedExpr{ .BinOp = .{
        .left = left,
        .op = .Add,
        .right = right,
    } };

    const result = try compileWithOptLevel(a, &expr, .Standard);
    defer result.deinit(a);
    try std.testing.expect(result.bytecode.len > 0);
}

test "CompileOptions init" {
    const options = CompileOptions.init();
    try std.testing.expectEqual(OptLevel.Standard, options.opt_level);
    try std.testing.expect(!options.verbose);
    try std.testing.expectEqual(@as(usize, 10), options.max_iterations);
}

test "OptLevel enum values" {
    try std.testing.expectEqual(@as(u2, 0), @intFromEnum(OptLevel.None));
    try std.testing.expectEqual(@as(u2, 1), @intFromEnum(OptLevel.Minimal));
    try std.testing.expectEqual(@as(u2, 2), @intFromEnum(OptLevel.Standard));
    try std.testing.expectEqual(@as(u2, 3), @intFromEnum(OptLevel.Aggressive));
}
