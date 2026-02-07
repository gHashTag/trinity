// ═══════════════════════════════════════════════════════════════════════════════
// ZIG CODE EMITTER - Main code generation engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const builder_mod = @import("builder.zig");
const patterns_mod = @import("patterns.zig");
const tests_gen_mod = @import("tests_gen.zig");
const utils = @import("utils.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const PatternMatcher = patterns_mod.PatternMatcher;
const TestGenerator = tests_gen_mod.TestGenerator;
const VibeeSpec = types.VibeeSpec;
const Constant = types.Constant;
const TypeDef = types.TypeDef;
const CreationPattern = types.CreationPattern;
const Behavior = types.Behavior;
const Allocator = std.mem.Allocator;

pub const ZigCodeGen = struct {
    allocator: Allocator,
    builder: CodeBuilder,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .builder = CodeBuilder.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }

    pub fn generate(self: *Self, spec: *const VibeeSpec) ![]const u8 {
        try self.writeHeader(spec);
        try self.writeImports(spec);
        try self.writeConstants(spec.constants.items);
        try self.writeTypes(spec.types.items);
        try self.writeMemoryBuffers();
        try self.writeCreationPatterns(spec.creation_patterns.items, spec.types.items);
        try self.writeBehaviorFunctions(spec.behaviors.items);

        var test_gen = TestGenerator.init(&self.builder, self.allocator);
        try test_gen.writeTests(spec.behaviors.items);

        return self.builder.getOutput();
    }

    fn writeHeader(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated from .vibee specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Священная формула: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Золотая идентичность: φ² + 1/φ² = 3");
        try self.builder.writeLine("//");
        try self.builder.writeFmt("// Author: {s}\n", .{spec.author});
        try self.builder.writeLine("// DO NOT EDIT - This file is auto-generated");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();
    }

    fn writeImports(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("const std = @import(\"std\");");
        try self.builder.writeLine("const math = std.math;");

        // Emit custom imports from spec (uses module names for build.zig integration)
        if (spec.imports.items.len > 0) {
            try self.builder.newline();
            try self.builder.writeLine("// Custom imports from .vibee spec");
            for (spec.imports.items) |imp| {
                // Use module name for @import - build.zig provides modules by name
                try self.builder.writeFmt("const {s} = @import(\"{s}\");\n", .{ imp.name, imp.name });
            }
        }

        try self.builder.newline();
    }

    fn writeConstants(self: *Self, constants: []const Constant) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// КОНСТАНТЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (constants) |c| {
            if (c.description.len > 0) {
                try self.builder.writeFmt("/// {s}\n", .{c.description});
            }
            try self.builder.writeFmt("pub const {s}: f64 = {d};\n", .{ c.name, c.value });
            try self.builder.newline();
        }

        // Add base φ-constants if not in spec
        var has_phi = false;
        var has_phi_inv = false;
        var has_phi_sq = false;
        var has_trinity = false;
        var has_sqrt5 = false;
        var has_tau = false;
        var has_pi = false;
        var has_e = false;
        var has_phoenix = false;

        for (constants) |c| {
            if (std.mem.eql(u8, c.name, "PHI")) has_phi = true;
            if (std.mem.eql(u8, c.name, "PHI_INV")) has_phi_inv = true;
            if (std.mem.eql(u8, c.name, "PHI_SQ")) has_phi_sq = true;
            if (std.mem.eql(u8, c.name, "TRINITY")) has_trinity = true;
            if (std.mem.eql(u8, c.name, "SQRT5")) has_sqrt5 = true;
            if (std.mem.eql(u8, c.name, "TAU")) has_tau = true;
            if (std.mem.eql(u8, c.name, "PI")) has_pi = true;
            if (std.mem.eql(u8, c.name, "E")) has_e = true;
            if (std.mem.eql(u8, c.name, "PHOENIX")) has_phoenix = true;
        }

        try self.builder.writeLine("// Базовые φ-константы (Sacred Formula)");
        if (!has_phi) try self.builder.writeLine("pub const PHI: f64 = 1.618033988749895;");
        if (!has_phi_inv) try self.builder.writeLine("pub const PHI_INV: f64 = 0.618033988749895;");
        if (!has_phi_sq) try self.builder.writeLine("pub const PHI_SQ: f64 = 2.618033988749895;");
        if (!has_trinity) try self.builder.writeLine("pub const TRINITY: f64 = 3.0;");
        if (!has_sqrt5) try self.builder.writeLine("pub const SQRT5: f64 = 2.2360679774997896;");
        if (!has_tau) try self.builder.writeLine("pub const TAU: f64 = 6.283185307179586;");
        if (!has_pi) try self.builder.writeLine("pub const PI: f64 = 3.141592653589793;");
        if (!has_e) try self.builder.writeLine("pub const E: f64 = 2.718281828459045;");
        if (!has_phoenix) try self.builder.writeLine("pub const PHOENIX: i64 = 999;");
        try self.builder.newline();
    }

    fn writeTypes(self: *Self, type_defs: []const TypeDef) !void {
        if (type_defs.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ТИПЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (type_defs) |t| {
            try self.builder.writeFmt("/// {s}\n", .{t.description});

            if (t.base) |base| {
                try self.builder.writeFmt("pub const {s} = {s};\n", .{ t.name, base });
            } else {
                try self.builder.writeFmt("pub const {s} = struct {{\n", .{t.name});
                self.builder.incIndent();

                for (t.fields.items) |field| {
                    try self.builder.writeIndent();
                    const clean_type = utils.cleanTypeName(field.type_name);
                    const safe_name = utils.escapeReservedWord(field.name);
                    try self.builder.writeFmt("{s}: {s},\n", .{ safe_name, utils.mapType(clean_type) });
                }

                self.builder.decIndent();
                try self.builder.writeLine("};");
            }
            try self.builder.newline();
        }
    }

    fn writeMemoryBuffers(self: *Self) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ПАМЯТЬ ДЛЯ WASM");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        try self.builder.writeLine("var global_buffer: [65536]u8 align(16) = undefined;");
        try self.builder.writeLine("var f64_buffer: [8192]f64 align(16) = undefined;");
        try self.builder.newline();

        try self.builder.writeLine("export fn get_global_buffer_ptr() [*]u8 {");
        try self.builder.writeLine("    return &global_buffer;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        try self.builder.writeLine("export fn get_f64_buffer_ptr() [*]f64 {");
        try self.builder.writeLine("    return &f64_buffer;");
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn writeCreationPatterns(self: *Self, patterns: []const CreationPattern, type_defs: []const TypeDef) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// CREATION PATTERNS");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (patterns) |p| {
            try self.builder.writeFmt("/// {s}\n", .{p.transformer});
            try self.builder.writeFmt("/// Source: {s} -> Result: {s}\n", .{ p.source, p.result });
            try self.generatePatternFunction(p);
            try self.builder.newline();
        }

        try self.generateStandardFunctions(type_defs);
    }

    fn generatePatternFunction(self: *Self, pattern: CreationPattern) !void {
        if (std.mem.eql(u8, pattern.name, "phi_power")) {
            try self.builder.writeLine("fn phi_power(n: i32) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 1.0;");
            try self.builder.writeLine("if (n == 1) return PHI;");
            try self.builder.writeLine("if (n == -1) return PHI_INV;");
            try self.builder.newline();
            try self.builder.writeLine("var result: f64 = 1.0;");
            try self.builder.writeLine("var base: f64 = if (n < 0) PHI_INV else PHI;");
            try self.builder.writeLine("var exp: u32 = if (n < 0) @intCast(-n) else @intCast(n);");
            try self.builder.newline();
            try self.builder.writeLine("while (exp > 0) {");
            self.builder.incIndent();
            try self.builder.writeLine("if (exp & 1 == 1) result *= base;");
            try self.builder.writeLine("base *= base;");
            try self.builder.writeLine("exp >>= 1;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "fibonacci")) {
            try self.builder.writeLine("fn fibonacci(n: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("if (n <= 2) return 1;");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.writeLine("return @intFromFloat(@round((phi_n - psi_n) / SQRT5));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lucas")) {
            try self.builder.writeLine("fn lucas(n: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 2;");
            try self.builder.writeLine("if (n == 1) return 1;");
            try self.builder.writeLine("const phi_n = phi_power(@intCast(n));");
            try self.builder.writeLine("const psi: f64 = -PHI_INV;");
            try self.builder.writeLine("var psi_n: f64 = 1.0;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < n) : (i += 1) psi_n *= psi;");
            try self.builder.writeLine("return @intFromFloat(@round(phi_n + psi_n));");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "factorial")) {
            try self.builder.writeLine("/// Factorial n! - O(n)");
            try self.builder.writeLine("fn factorial(n: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n <= 1) return 1;");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u64 = 2;");
            try self.builder.writeLine("while (i <= n) : (i += 1) result *%= i;");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "gcd")) {
            try self.builder.writeLine("/// GCD using Euclidean algorithm - O(log(min(a,b)))");
            try self.builder.writeLine("fn gcd(a: u64, b: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("var x = a;");
            try self.builder.writeLine("var y = b;");
            try self.builder.writeLine("while (y != 0) {");
            self.builder.incIndent();
            try self.builder.writeLine("const t = y;");
            try self.builder.writeLine("y = x % y;");
            try self.builder.writeLine("x = t;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return x;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "lcm")) {
            try self.builder.writeLine("/// LCM using GCD - O(log(min(a,b)))");
            try self.builder.writeLine("fn lcm(a: u64, b: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (a == 0 or b == 0) return 0;");
            try self.builder.writeLine("return (a / gcd(a, b)) * b;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "digital_root")) {
            try self.builder.writeLine("/// Digital root (repeated digit sum until single digit) - O(1)");
            try self.builder.writeLine("fn digital_root(n: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (n == 0) return 0;");
            try self.builder.writeLine("const r = n % 9;");
            try self.builder.writeLine("return if (r == 0) 9 else r;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "trinity_power")) {
            try self.builder.writeLine("/// Trinity power 3^k with lookup table - O(1) for k < 20");
            try self.builder.writeLine("fn trinity_power(k: u32) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("const powers = [_]u64{ 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049, 177147, 531441, 1594323, 4782969, 14348907, 43046721, 129140163, 387420489, 1162261467 };");
            try self.builder.writeLine("if (k < powers.len) return powers[k];");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u32 = 0;");
            try self.builder.writeLine("while (i < k) : (i += 1) result *= 3;");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "sacred_formula")) {
            try self.builder.writeLine("/// Sacred formula: V = n × 3^k × π^m × φ^p × e^q");
            try self.builder.writeLine("fn sacred_formula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return n * math.pow(f64, 3.0, k) * math.pow(f64, PI, m) * math.pow(f64, PHI, p) * math.pow(f64, E, q);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "golden_identity")) {
            try self.builder.writeLine("/// Golden identity: φ² + 1/φ² = 3");
            try self.builder.writeLine("fn golden_identity() f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return PHI * PHI + 1.0 / (PHI * PHI);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        } else if (std.mem.eql(u8, pattern.name, "binomial")) {
            try self.builder.writeLine("/// Binomial coefficient C(n,k) = n! / (k! * (n-k)!)");
            try self.builder.writeLine("fn binomial(n: u64, k: u64) u64 {");
            self.builder.incIndent();
            try self.builder.writeLine("if (k > n) return 0;");
            try self.builder.writeLine("if (k == 0 or k == n) return 1;");
            try self.builder.writeLine("var result: u64 = 1;");
            try self.builder.writeLine("var i: u64 = 0;");
            try self.builder.writeLine("while (i < k) : (i += 1) {");
            self.builder.incIndent();
            try self.builder.writeLine("result = result * (n - i) / (i + 1);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.writeLine("return result;");
            self.builder.decIndent();
            try self.builder.writeLine("}");
        }
    }

    fn generateStandardFunctions(self: *Self, type_defs: []const TypeDef) !void {
        // Check if Trit is already defined
        var has_trit = false;
        for (type_defs) |t| {
            if (std.mem.eql(u8, t.name, "Trit")) {
                has_trit = true;
                break;
            }
        }

        if (!has_trit) {
            try self.builder.writeLine("/// Trit - ternary digit (-1, 0, +1)");
            try self.builder.writeLine("pub const Trit = enum(i8) {");
            try self.builder.writeLine("    negative = -1, // FALSE");
            try self.builder.writeLine("    zero = 0,      // UNKNOWN");
            try self.builder.writeLine("    positive = 1,  // TRUE");
            try self.builder.newline();
            try self.builder.writeLine("    pub fn trit_and(a: Trit, b: Trit) Trit {");
            try self.builder.writeLine("        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));");
            try self.builder.writeLine("    }");
            try self.builder.newline();
            try self.builder.writeLine("    pub fn trit_or(a: Trit, b: Trit) Trit {");
            try self.builder.writeLine("        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));");
            try self.builder.writeLine("    }");
            try self.builder.newline();
            try self.builder.writeLine("    pub fn trit_not(a: Trit) Trit {");
            try self.builder.writeLine("        return @enumFromInt(-@intFromEnum(a));");
            try self.builder.writeLine("    }");
            try self.builder.newline();
            try self.builder.writeLine("    pub fn trit_xor(a: Trit, b: Trit) Trit {");
            try self.builder.writeLine("        const av = @intFromEnum(a);");
            try self.builder.writeLine("        const bv = @intFromEnum(b);");
            try self.builder.writeLine("        if (av == 0 or bv == 0) return .zero;");
            try self.builder.writeLine("        if (av == bv) return .negative;");
            try self.builder.writeLine("        return .positive;");
            try self.builder.writeLine("    }");
            try self.builder.writeLine("};");
            try self.builder.newline();
        }

        // verify_trinity
        try self.builder.writeLine("/// Проверка TRINITY identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("fn verify_trinity() f64 {");
        try self.builder.writeLine("    return PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // phi_lerp
        try self.builder.writeLine("/// φ-интерполяция");
        try self.builder.writeLine("fn phi_lerp(a: f64, b: f64, t: f64) f64 {");
        try self.builder.writeLine("    const phi_t = math.pow(f64, t, PHI_INV);");
        try self.builder.writeLine("    return a + (b - a) * phi_t;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // generate_phi_spiral
        try self.builder.writeLine("/// Генерация φ-спирали");
        try self.builder.writeLine("fn generate_phi_spiral(n: u32, scale: f64, cx: f64, cy: f64) u32 {");
        self.builder.incIndent();
        try self.builder.writeLine("const max_points = f64_buffer.len / 2;");
        try self.builder.writeLine("const count = if (n > max_points) @as(u32, @intCast(max_points)) else n;");
        try self.builder.writeLine("var i: u32 = 0;");
        try self.builder.writeLine("while (i < count) : (i += 1) {");
        self.builder.incIndent();
        try self.builder.writeLine("const fi: f64 = @floatFromInt(i);");
        try self.builder.writeLine("const angle = fi * TAU * PHI_INV;");
        try self.builder.writeLine("const radius = scale * math.pow(f64, PHI, fi * 0.1);");
        try self.builder.writeLine("f64_buffer[i * 2] = cx + radius * @cos(angle);");
        try self.builder.writeLine("f64_buffer[i * 2 + 1] = cy + radius * @sin(angle);");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.writeLine("return count;");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    fn writeBehaviorFunctions(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BEHAVIOR FUNCTIONS - Generated from behaviors");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        var pattern_matcher = PatternMatcher.init(&self.builder);

        for (behaviors) |b| {
            try self.generateBehaviorImplementation(&pattern_matcher, &b);
        }
    }

    fn generateBehaviorImplementation(self: *Self, pattern_matcher: *PatternMatcher, b: *const Behavior) !void {
        // Try DSL patterns first
        if (try pattern_matcher.generateFromDsLPattern(b)) {
            try self.builder.newline();
            return;
        }

        // Try when/then patterns
        if (try pattern_matcher.generateFromWhenThenPattern(b)) {
            try self.builder.newline();
            return;
        }

        // Try VSA behavior patterns (real VSA calls)
        if (try self.tryGenerateVSABehavior(b)) {
            try self.builder.newline();
            return;
        }

        // Fallback: generate stub
        try self.builder.writeFmt("/// {s}\n", .{b.given});
        try self.builder.writeFmt("pub fn {s}() void {{\n", .{b.name});
        self.builder.incIndent();
        try self.builder.writeFmt("// When: {s}\n", .{b.when});
        try self.builder.writeFmt("// Then: {s}\n", .{b.then});
        try self.builder.writeLine("// TODO: Implement behavior");
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
    }

    /// Generate real VSA function calls for VSA-related behaviors
    fn tryGenerateVSABehavior(self: *Self, b: *const Behavior) !bool {
        const std_mem = std.mem;

        // Check for VSA behavior patterns
        if (std_mem.eql(u8, b.name, "realBind")) {
            try self.builder.writeLine("/// Bind two hypervectors (creates association)");
            try self.builder.writeLine("pub fn realBind(a: *vsa.HybridBigInt, b_vec: *vsa.HybridBigInt) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.bind(a, b_vec);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realUnbind")) {
            try self.builder.writeLine("/// Unbind to retrieve associated vector");
            try self.builder.writeLine("pub fn realUnbind(bound: *vsa.HybridBigInt, key: *vsa.HybridBigInt) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.unbind(bound, key);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realBundle2")) {
            try self.builder.writeLine("/// Bundle two hypervectors (superposition)");
            try self.builder.writeLine("pub fn realBundle2(a: *vsa.HybridBigInt, b_vec: *vsa.HybridBigInt) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.bundle2(a, b_vec);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realBundle3")) {
            try self.builder.writeLine("/// Bundle three hypervectors (superposition)");
            try self.builder.writeLine("pub fn realBundle3(a: *vsa.HybridBigInt, b_vec: *vsa.HybridBigInt, c: *vsa.HybridBigInt) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.bundle3(a, b_vec, c);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realPermute")) {
            try self.builder.writeLine("/// Permute hypervector (position encoding)");
            try self.builder.writeLine("pub fn realPermute(v: *vsa.HybridBigInt, k: usize) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.permute(v, k);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realCosineSimilarity")) {
            try self.builder.writeLine("/// Compute cosine similarity between hypervectors");
            try self.builder.writeLine("pub fn realCosineSimilarity(a: *vsa.HybridBigInt, b_vec: *vsa.HybridBigInt) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.cosineSimilarity(a, b_vec);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realHammingDistance")) {
            try self.builder.writeLine("/// Compute Hamming distance between hypervectors");
            try self.builder.writeLine("pub fn realHammingDistance(a: *vsa.HybridBigInt, b_vec: *vsa.HybridBigInt) usize {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.hammingDistance(a, b_vec);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realRandomVector")) {
            try self.builder.writeLine("/// Generate random hypervector");
            try self.builder.writeLine("pub fn realRandomVector(len: usize, seed: u64) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.randomVector(len, seed);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Text encoding functions
        if (std_mem.eql(u8, b.name, "realCharToVector")) {
            try self.builder.writeLine("/// Convert character to hypervector");
            try self.builder.writeLine("pub fn realCharToVector(char: u8) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.charToVector(char);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realEncodeText")) {
            try self.builder.writeLine("/// Encode text string to hypervector");
            try self.builder.writeLine("pub fn realEncodeText(text: []const u8) vsa.HybridBigInt {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.encodeText(text);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realDecodeText")) {
            try self.builder.writeLine("/// Decode hypervector back to text");
            try self.builder.writeLine("pub fn realDecodeText(encoded: *vsa.HybridBigInt, max_len: usize, buffer: []u8) []u8 {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.decodeText(encoded, max_len, buffer);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realTextRoundtrip")) {
            try self.builder.writeLine("/// Test text encode/decode roundtrip");
            try self.builder.writeLine("pub fn realTextRoundtrip(text: []const u8, buffer: []u8) []u8 {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.textRoundtrip(text, buffer);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Semantic similarity functions
        if (std_mem.eql(u8, b.name, "realTextSimilarity")) {
            try self.builder.writeLine("/// Compare semantic similarity between two texts");
            try self.builder.writeLine("pub fn realTextSimilarity(text1: []const u8, text2: []const u8) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.textSimilarity(text1, text2);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realTextsAreSimilar")) {
            try self.builder.writeLine("/// Check if two texts are semantically similar");
            try self.builder.writeLine("pub fn realTextsAreSimilar(text1: []const u8, text2: []const u8, threshold: f64) bool {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.textsAreSimilar(text1, text2, threshold);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realSearchCorpus")) {
            try self.builder.writeLine("/// Search corpus for similar texts");
            try self.builder.writeLine("pub fn realSearchCorpus(corpus: *vsa.TextCorpus, query: []const u8, results: []vsa.SearchResult) usize {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.searchCorpus(corpus, query, results);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Corpus persistence functions
        if (std_mem.eql(u8, b.name, "realSaveCorpus")) {
            try self.builder.writeLine("/// Save corpus to file");
            try self.builder.writeLine("pub fn realSaveCorpus(corpus: *vsa.TextCorpus, path: []const u8) !void {");
            self.builder.incIndent();
            try self.builder.writeLine("try corpus.save(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realLoadCorpus")) {
            try self.builder.writeLine("/// Load corpus from file");
            try self.builder.writeLine("pub fn realLoadCorpus(path: []const u8) !vsa.TextCorpus {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.TextCorpus.load(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        // Compressed corpus persistence (5x smaller)
        if (std_mem.eql(u8, b.name, "realSaveCorpusCompressed")) {
            try self.builder.writeLine("/// Save corpus with 5x compression");
            try self.builder.writeLine("pub fn realSaveCorpusCompressed(corpus: *vsa.TextCorpus, path: []const u8) !void {");
            self.builder.incIndent();
            try self.builder.writeLine("try corpus.saveCompressed(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realLoadCorpusCompressed")) {
            try self.builder.writeLine("/// Load compressed corpus");
            try self.builder.writeLine("pub fn realLoadCorpusCompressed(path: []const u8) !vsa.TextCorpus {");
            self.builder.incIndent();
            try self.builder.writeLine("return vsa.TextCorpus.loadCompressed(path);");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        if (std_mem.eql(u8, b.name, "realCompressionRatio")) {
            try self.builder.writeLine("/// Get compression ratio (uncompressed/compressed)");
            try self.builder.writeLine("pub fn realCompressionRatio(corpus: *vsa.TextCorpus) f64 {");
            self.builder.incIndent();
            try self.builder.writeLine("return corpus.compressionRatio();");
            self.builder.decIndent();
            try self.builder.writeLine("}");
            return true;
        }

        return false;
    }
};
