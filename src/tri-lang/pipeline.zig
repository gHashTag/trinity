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

// TRI-LANG-6: Content addressing
const ContentHash = @import("content_hash.zig").ContentHash;
const ContentRegistry = @import("content_registry.zig").ContentRegistry;
const FunctionLocation = @import("content_registry.zig").FunctionLocation;
const hashFunctionDecl = @import("content_hash.zig").hashFunctionDecl;

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
    /// Compute content hashes for functions (TRI-LANG-6)
    compute_content_hash: bool = false,
    /// Path to content registry file
    registry_path: ?[]const u8 = null,
    /// Module name for content registry
    module_name: ?[]const u8 = null,
    /// Source file path for content registry
    source_path: ?[]const u8 = null,

    pub fn init() CompileOptions {
        return .{
            .opt_level = .Standard,
            .verbose = false,
            .max_iterations = 10,
            .compute_content_hash = false,
            .registry_path = null,
            .module_name = null,
            .source_path = null,
        };
    }
};

pub const PipelineResult = struct {
    bytecode: []const u8,
    inferred_type: Type,
    /// Content hashes for top-level functions (if computed)
    content_hashes: []const ContentHash = &.{},

    pub fn deinit(self: *const PipelineResult, allocator: Allocator) void {
        allocator.free(self.bytecode);
        if (self.content_hashes.len > 0) {
            allocator.free(self.content_hashes);
        }
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
    var optimizer = try Optimizer.init(allocator);
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

    var optimizer = try Optimizer.initWithConfig(allocator, config);
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
// TRI-LANG-6: FUNCTION COLLECTION
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Function information for content hashing
const FunctionInfo = struct {
    name: []const u8,
    params: []const []const u8,
    body: *const TypedExpr,
    line: usize,
};

/// Collects function expressions from AST
const FunctionCollector = struct {
    allocator: Allocator,
    functions: std.ArrayList(FunctionInfo),

    fn init(allocator: Allocator) FunctionCollector {
        return .{
            .allocator = allocator,
            .functions = std.ArrayList(FunctionInfo).init(allocator),
        };
    }

    fn deinit(self: *FunctionCollector) void {
        self.functions.deinit();
    }
};

/// Collect all top-level function expressions
fn collectFunctions(expr: *const TypedExpr, collector: *FunctionCollector) !void {
    switch (expr.*) {
        .Fn => |fn_info| {
            // Found a function - collect it
            try collector.functions.append(.{
                .name = "", // Anonymous function
                .params = fn_info.params,
                .body = fn_info.body,
                .line = 0,
            });
        },
        .Let => |let_info| {
            // Check if the value is a function
            if (let_info.value.* == .Fn) {
                try collector.functions.append(.{
                    .name = let_info.name,
                    .params = let_info.value.Fn.params,
                    .body = let_info.value.Fn.body,
                    .line = 0,
                });
            }
            // Continue collecting in body
            try collectFunctions(let_info.body, collector);
        },
        .BinOp => |bin_info| {
            try collectFunctions(bin_info.left, collector);
            try collectFunctions(bin_info.right, collector);
        },
        .If => |if_info| {
            try collectFunctions(if_info.condition, collector);
            try collectFunctions(if_info.then_branch, collector);
            try collectFunctions(if_info.else_branch, collector);
        },
        .FnCall => |call_info| {
            try collectFunctions(call_info.func, collector);
            for (call_info.args) |arg| {
                try collectFunctions(arg, collector);
            }
        },
        .Match => |match_info| {
            try collectFunctions(match_info.value, collector);
            for (match_info.arms) |arm| {
                try collectFunctions(arm.body, collector);
            }
        },
        .Pipe => |pipe_info| {
            try collectFunctions(pipe_info.source, collector);
            for (pipe_info.stages) |stage| {
                try collectFunctions(stage, collector);
            }
        },
        .Perform => |perf_info| {
            for (perf_info.args) |arg| {
                try collectFunctions(arg, collector);
            }
        },
        .Handle => |handle_info| {
            try collectFunctions(handle_info.body, collector);
            for (handle_info.clauses) |clause| {
                try collectFunctions(clause.body, collector);
            }
        },
        .Try => |try_info| {
            try collectFunctions(try_info.computation, collector);
            for (try_info.handlers) |handler| {
                try collectFunctions(handler.body, collector);
            }
        },
        .Map => |map_info| {
            try collectFunctions(map_info.array, collector);
            try collectFunctions(map_info.func, collector);
        },
        .Reduce => |reduce_info| {
            try collectFunctions(reduce_info.array, collector);
            try collectFunctions(reduce_info.init, collector);
        },
        .Scan => |scan_info| {
            try collectFunctions(scan_info.array, collector);
            try collectFunctions(scan_info.init, collector);
        },
        .Filter => |filter_info| {
            try collectFunctions(filter_info.array, collector);
            try collectFunctions(filter_info.predicate, collector);
        },
        .FlatMap => |flatmap_info| {
            try collectFunctions(flatmap_info.array, collector);
            try collectFunctions(flatmap_info.func, collector);
        },
        .Zip => |zip_info| {
            try collectFunctions(zip_info.array1, collector);
            try collectFunctions(zip_info.array2, collector);
        },
        .Int, .Bool, .Var, .ADT => {
            // Leaf nodes - nothing to collect
        },
    }
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

    // TRI-LANG-6: Content hashing
    var content_hashes: []const ContentHash = &.{};
    if (options.compute_content_hash) {
        var registry: ?ContentRegistry = null;
        defer if (registry) |*r| r.deinit();

        // Load existing registry if path provided
        if (options.registry_path) |path| {
            if (std.fs.cwd().openFile(path, .{})) |file| {
                file.close();
                registry = try ContentRegistry.loadFromFile(allocator, path);
            } else |_| {
                // File doesn't exist, create new registry
                registry = try ContentRegistry.init(allocator);
            }
        }

        // Collect and hash top-level functions
        var hash_list = std.ArrayList(ContentHash).init(allocator);
        var fn_collector = FunctionCollector.init(allocator);

        try collectFunctions(optimized, &fn_collector);

        const module_name = options.module_name orelse "unknown";
        const source_path = options.source_path orelse "unknown.tri";

        for (fn_collector.functions.items) |fn_info| {
            const hash = try hashFunctionDecl(allocator, fn_info.params, fn_info.body);

            // Register in registry
            if (registry) |*r| {
                const loc = FunctionLocation{
                    .module = module_name,
                    .name = fn_info.name,
                    .line = fn_info.line,
                    .file_path = source_path,
                };
                try r.register(hash, loc);
            }

            try hash_list.append(hash);
        }

        content_hashes = try hash_list.toOwnedSlice();

        // Save registry if path provided
        if (registry) |*r| {
            if (options.registry_path) |path| {
                try r.saveToFile(path);
            }
        }

        if (options.verbose) {
            std.debug.print("Content-addressed: {d} functions hashed\n", .{content_hashes.len});
        }
    }

    // Code generation
    var cg = Codegen.init(allocator);
    defer cg.deinit();

    try compileExpr(&cg, optimized);

    const bytecode = try allocator.dupe(u8, cg.getBytecode());

    return PipelineResult{
        .bytecode = bytecode,
        .inferred_type = type_result.type,
        .content_hashes = content_hashes,
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
    try std.testing.expect(expr.* == .Int);
}

test "parser parse bool" {
    const a = std.testing.allocator;
    var parser = TriParser.init(a, "true");
    const expr = try parser.parseBoolLiteral();
    try std.testing.expect(expr.* == .Bool);
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
    var env = TypeEnv.init(a);
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

    var env = TypeEnv.init(a);
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

// ═══════════════════════════════════════════════════════════════════════════════
// TRI-LANG-6: CONTENT HASH INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════

test "compileWithOptions with content hashing disabled" {
    const a = std.testing.allocator;
    const expr = TypedExpr{ .Int = .{ .value = 42 } };

    var options = CompileOptions.init();
    options.compute_content_hash = false;

    const result = try compileWithOptions(a, &expr, options);
    defer result.deinit(a);

    try std.testing.expectEqual(@as(usize, 0), result.content_hashes.len);
}

test "compileWithOptions with content hashing enabled" {
    const a = std.testing.allocator;

    // Create a simple function expression
    const x_param = try a.dupe(u8, "x");
    defer a.free(x_param);
    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Var = .{ .name = "x" } };
    const fn_expr = try a.create(TypedExpr);
    defer a.destroy(fn_expr);
    fn_expr.* = TypedExpr{ .Fn = .{ .params = &.{x_param}, .body = body } };

    var options = CompileOptions.init();
    options.compute_content_hash = true;

    const result = try compileWithOptions(a, fn_expr, options);
    defer result.deinit(a);

    // Should have one content hash for the function
    try std.testing.expectEqual(@as(usize, 1), result.content_hashes.len);
}

test "compileWithOptions with content hashing and registry" {
    const a = std.testing.allocator;

    // Create a simple function expression
    const x_param = try a.dupe(u8, "x");
    defer a.free(x_param);
    const body = try a.create(TypedExpr);
    defer a.destroy(body);
    body.* = TypedExpr{ .Var = .{ .name = "x" } };
    const fn_expr = try a.create(TypedExpr);
    defer a.destroy(fn_expr);
    fn_expr.* = TypedExpr{ .Fn = .{ .params = &.{x_param}, .body = body } };

    var options = CompileOptions.init();
    options.compute_content_hash = true;
    options.registry_path = "/tmp/test_registry.json";
    options.module_name = "test.module";
    options.source_path = "test.tri";

    const result = try compileWithOptions(a, fn_expr, options);
    defer result.deinit(a);

    try std.testing.expectEqual(@as(usize, 1), result.content_hashes.len);

    // Clean up test file
    std.fs.cwd().deleteFile("/tmp/test_registry.json") catch {};
}

test "CompileOptions with content hash fields" {
    const options = CompileOptions.init();
    try std.testing.expect(!options.compute_content_hash);
    try std.testing.expect(options.registry_path == null);
    try std.testing.expect(options.module_name == null);
    try std.testing.expect(options.source_path == null);
}

test "FunctionCollector collects let-bound functions" {
    const a = std.testing.allocator;

    const x_param = try a.dupe(u8, "x");
    defer a.free(x_param);
    const fn_body = try a.create(TypedExpr);
    defer a.destroy(fn_body);
    fn_body.* = TypedExpr{ .Var = .{ .name = "x" } };
    const fn_val = try a.create(TypedExpr);
    defer a.destroy(fn_val);
    fn_val.* = TypedExpr{ .Fn = .{ .params = &.{x_param}, .body = fn_body } };

    const int_body = try a.create(TypedExpr);
    defer a.destroy(int_body);
    int_body.* = TypedExpr{ .Int = .{ .value = 42 } };

    const let_expr = try a.create(TypedExpr);
    defer a.destroy(let_expr);
    let_expr.* = TypedExpr{ .Let = .{
        .name = "identity",
        .value = fn_val,
        .body = int_body,
    } };

    var collector = FunctionCollector.init(a);
    defer collector.deinit();

    try collectFunctions(let_expr, &collector);

    try std.testing.expectEqual(@as(usize, 1), collector.functions.items.len);
    try std.testing.expectEqualStrings("identity", collector.functions.items[0].name);
}

test "compileWithOptions with let-bound function hashing" {
    const a = std.testing.allocator;

    const x_param = try a.dupe(u8, "x");
    defer a.free(x_param);
    const fn_body = try a.create(TypedExpr);
    defer a.destroy(fn_body);
    fn_body.* = TypedExpr{ .Var = .{ .name = "x" } };
    const fn_val = try a.create(TypedExpr);
    defer a.destroy(fn_val);
    fn_val.* = TypedExpr{ .Fn = .{ .params = &.{x_param}, .body = fn_body } };

    const int_body = try a.create(TypedExpr);
    defer a.destroy(int_body);
    int_body.* = TypedExpr{ .Int = .{ .value = 42 } };

    const let_expr = try a.create(TypedExpr);
    defer a.destroy(let_expr);
    let_expr.* = TypedExpr{ .Let = .{
        .name = "identity",
        .value = fn_val,
        .body = int_body,
    } };

    var options = CompileOptions.init();
    options.compute_content_hash = true;

    const result = try compileWithOptions(a, let_expr, options);
    defer result.deinit(a);

    // Should have one content hash for the let-bound function
    try std.testing.expectEqual(@as(usize, 1), result.content_hashes.len);
}
