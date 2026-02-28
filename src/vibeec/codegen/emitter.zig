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
const type_resolver = @import("type_resolver.zig");
const zig_idioms_mod = @import("zig_idioms.zig");
const signature_mod = @import("signature.zig");
const body_emitter = @import("body_emitter.zig");
const vsa_emitter = @import("vsa_emitter.zig");
const struct_emitters = @import("struct_emitters.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const PatternMatcher = patterns_mod.PatternMatcher;
const TestGenerator = tests_gen_mod.TestGenerator;
const VibeeSpec = types.VibeeSpec;
const Constant = types.Constant;
const TypeDef = types.TypeDef;
const CreationPattern = types.CreationPattern;
const Behavior = types.Behavior;
const Allocator = std.mem.Allocator;

pub const CodegenError = error{
    UnmatchedBrackets,
    InvalidMapType,
    InvalidHashMapType,
};

pub const ZigCodeGen = struct {
    allocator: Allocator,
    builder: CodeBuilder,
    emission_state: vsa_emitter.EmissionState,
    /// Cached reference to spec types for signature inference
    spec_types: []const TypeDef = &.{},
    /// Zig idiom transforms (Cycle 74)
    idioms: ?zig_idioms_mod.ZigIdioms = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .builder = CodeBuilder.init(allocator),
            .emission_state = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.builder.deinit();
    }


    // ═══════════════════════════════════════════════════════════════════════════════
    // STRUCT EMITTERS — Delegated to struct_emitters module
    // ═══════════════════════════════════════════════════════════════════════════════

    fn emitShardNetworkStruct(self: *Self) !void {
        if (self.emission_state.network_emitted) return;
        self.emission_state.network_emitted = true;
        try struct_emitters.emitShardNetwork(&self.builder);
    }

    fn emitReedSolomonStruct(self: *Self) !void {
        if (self.emission_state.erasure_emitted) return;
        self.emission_state.erasure_emitted = true;
        try struct_emitters.emitReedSolomon(&self.builder);
    }

    fn emitDiscoveryStructs(self: *Self) !void {
        if (self.emission_state.discovery_emitted) return;
        self.emission_state.discovery_emitted = true;
        try struct_emitters.emitDiscovery(&self.builder);
    }

    fn emitProofOfStorageStruct(self: *Self) !void {
        if (self.emission_state.pos_emitted) return;
        self.emission_state.pos_emitted = true;
        try struct_emitters.emitProofOfStorage(&self.builder);
    }

    fn emitDhtStruct(self: *Self) !void {
        if (self.emission_state.dht_emitted) return;
        self.emission_state.dht_emitted = true;
        try struct_emitters.emitDht(&self.builder);
    }

    fn emitSwarmStruct(self: *Self) !void {
        if (self.emission_state.swarm_emitted) return;
        self.emission_state.swarm_emitted = true;
        try struct_emitters.emitSwarm(&self.builder);
    }

    fn emitRewardsStruct(self: *Self) !void {
        if (self.emission_state.rewards_emitted) return;
        self.emission_state.rewards_emitted = true;
        try struct_emitters.emitRewards(&self.builder);
    }

    pub fn generate(self: *Self, spec: *const VibeeSpec) ![]const u8 {
        // Store spec types for signature inference
        self.spec_types = spec.types.items;
        // Initialize Zig idioms from spec (Cycle 74)
        self.idioms = zig_idioms_mod.ZigIdioms.fromSpec(spec);

        try self.writeHeader(spec);
        try self.writeImports(spec);
        try self.writeConstants(spec.constants.items);
        try self.writeTypes(spec.types.items, spec.behaviors.items);
        // Cycle 76: Only emit WASM memory buffers in wasm/standard mode (not idiomatic)
        if (spec.zig_mode == .wasm or spec.zig_mode == .standard) {
            try self.writeMemoryBuffers();
        }
        try self.writeCreationPatterns(spec.creation_patterns.items, spec.types.items);
        try self.writeBehaviorFunctions(spec.behaviors.items);
        // NOTE: snake_case aliases disabled - use camelCase function names in tests
        // try self.writeBehaviorAliases(spec.behaviors.items);

        var test_gen = TestGenerator.withSpec(&self.builder, self.allocator, spec.name, spec.zig_mode);
        // Behavior-level tests (one per behavior)
        try test_gen.writeTests(spec.behaviors.items);
        // Spec-level tests (integration tests from test_cases:)
        try test_gen.writeSpecLevelTests(spec.test_cases.items);

        return self.builder.toOwnedSlice();
    }

    fn writeHeader(self: *Self, spec: *const VibeeSpec) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeFmt("// {s} v{s} - Generated from .tri specification\n", .{ spec.name, spec.version });
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("//");
        try self.builder.writeLine("// Sacred formula: V = n × 3^k × π^m × φ^p × e^q");
        try self.builder.writeLine("// Золfromая andдентandчноwithть: φ² + 1/φ² = 3");
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
        try self.builder.writeLine("const Allocator = std.mem.Allocator;");

        // Emit custom imports from spec (uses module names for build.zig integration)
        if (spec.imports.items.len > 0) {
            try self.builder.newline();
            try self.builder.writeLine("// Custom imports from .vibee spec");
            for (spec.imports.items) |imp| {
                // Special handling for raylib: emit @cImport instead of @import
                if (std.mem.eql(u8, imp.name, "raylib")) {
                    try self.builder.writeLine("const rl = @cImport({");
                    self.builder.incIndent();
                    try self.builder.writeLine("@cInclude(\"raylib.h\");");
                    self.builder.decIndent();
                    try self.builder.writeLine("});");
                } else {
                    // Use module name for @import - build.zig provides modules by name
                    try self.builder.writeFmt("const {s} = @import(\"{s}\");\n", .{ imp.name, imp.name });
                }
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

        try self.builder.writeLine("// Базоinые φ-toонwithтанты (Sacred Formula)");
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

    fn writeTypes(self: *Self, type_defs: []const TypeDef, behaviors: []const Behavior) !void {
        if (type_defs.len == 0) return;

        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// ТИПЫ");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        for (type_defs) |t| {
            try self.builder.writeFmt("/// {s}\n", .{t.description});

            if (t.base) |base| {
                try self.builder.writeFmt("pub const {s} = {s};\n", .{ t.name, base });
            } else if (t.enum_variants.items.len > 0) {
                try self.builder.writeFmt("pub const {s} = enum {{\n", .{t.name});
                self.builder.incIndent();
                for (t.enum_variants.items) |variant| {
                    try self.builder.writeIndent();
                    try self.builder.writeFmt("{s},\n", .{variant});
                }
                self.builder.decIndent();
                try self.builder.writeLine("};");
            } else {
                try self.builder.writeFmt("pub const {s} = struct {{\n", .{t.name});
                self.builder.incIndent();

                // VIBEE Generator v2: Write const definitions inside struct
                var consts_iter = t.consts.iterator();
                while (consts_iter.next()) |entry| {
                    try self.builder.writeIndent();
                    // Strip quotes from const value (YAML "8" -> 8)
                    const clean_value = if (entry.value_ptr.*.len >= 2 and
                        entry.value_ptr.*[0] == '"' and entry.value_ptr.*[entry.value_ptr.*.len - 1] == '"')
                        entry.value_ptr.*[1 .. entry.value_ptr.*.len - 1]
                    else
                        entry.value_ptr.*;
                    try self.builder.writeFmt("const {s} = {s};\n", .{ entry.key_ptr.*, clean_value });
                }
                if (t.consts.count() > 0) try self.builder.newline();

                for (t.fields.items) |field| {
                    try self.builder.writeIndent();
                    const clean_type = utils.cleanTypeName(field.type_name);
                    const safe_name = utils.escapeReservedWord(field.name);
                    // Try parseComplexTypeNoAlloc for nested generics, fallback to utils.mapType
                    const zig_type = self.parseComplexTypeNoAlloc(clean_type) orelse utils.mapType(clean_type);
                    try self.builder.writeFmt("{s}: {s},\n", .{ safe_name, zig_type });
                }

                // VIBEE Generator v2: Write methods inside struct (behaviors with owner == type.name)
                for (behaviors) |b| {
                    if (b.owner) |owner| {
                        if (std.mem.eql(u8, owner, t.name)) {
                            try self.writeStructMethod(&b);
                        }
                    }
                }

                self.builder.decIndent();
                try self.builder.writeLine("};");
            }
            try self.builder.newline();
        }
    }

    /// VIBEE Generator v2: Write a behavior as a method inside a struct
    fn writeStructMethod(self: *Self, b: *const Behavior) !void {
        try self.builder.newline();
        // Write method implementation
        var pattern_matcher = PatternMatcher.init(&self.builder);
        try self.generateBehaviorImplementation(&pattern_matcher, b);
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
        try self.builder.writeLine("/// Check TRINITY identity: φ² + 1/φ² = 3");
        try self.builder.writeLine("fn verify_trinity() f64 {");
        try self.builder.writeLine("    return PHI * PHI + 1.0 / (PHI * PHI);");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // phi_lerp
        try self.builder.writeLine("/// φ-andнтерbyляцandя");
        try self.builder.writeLine("fn phi_lerp(a: f64, b: f64, t: f64) f64 {");
        try self.builder.writeLine("    const phi_t = math.pow(f64, t, PHI_INV);");
        try self.builder.writeLine("    return a + (b - a) * phi_t;");
        try self.builder.writeLine("}");
        try self.builder.newline();

        // generate_phi_spiral (only when WASM buffers are available — not in idiomatic mode)
        const skip_spiral = if (self.idioms) |_| true else false; // Cycle 76: idiomatic always skips
        if (!skip_spiral) {
            try self.builder.writeLine("/// Генерацandя φ-withпandралand");
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
    }

    fn writeBehaviorFunctions(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// BEHAVIOR FUNCTIONS - Generated from behaviors");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.newline();

        var pattern_matcher = PatternMatcher.init(&self.builder);

        for (behaviors) |b| {
            // VIBEE Generator v2: Skip behaviors with owner (already written as struct methods)
            if (b.owner != null) continue;

            try self.generateBehaviorImplementation(&pattern_matcher, &b);
        }
    }

    /// Write snake_case aliases for behavior functions (for test compatibility)
    /// Tests reference snake_case names like check_recovery_cooldown but functions are camelCase
    fn writeBehaviorAliases(self: *Self, behaviors: []const Behavior) !void {
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// SNAKE_CASE ALIASES - For test compatibility");
        try self.builder.writeLine("// ═══════════════════════════════════════════════════════════════════════════════");
        try self.builder.writeLine("// CYCLE_49_FIX: Adding aliases for snake_case test references");
        try self.builder.newline();

        for (behaviors) |b| {
            // VIBEE Generator v2: Skip behaviors with owner (struct methods don't need aliases)
            if (b.owner != null) continue;

            // b.name may be snake_case (e.g., "check_recovery_cooldown") or camelCase
            // Generated function is always camelCase (e.g., "checkRecoveryCooldown")
            // Create alias ONLY if snake_case != camel_case (skip self-referential aliases)
            const snake = b.name;

            // Skip if name is already camelCase (no underscores)
            if (std.mem.indexOf(u8, snake, "_") == null) {
                continue; // Already camelCase, no alias needed
            }

            var camel_buf: [256]u8 = undefined;
            var camel_idx: usize = 0;
            var capitalize_next = false;

            for (snake) |c| {
                if (c == '_') {
                    capitalize_next = true;
                } else {
                    camel_buf[camel_idx] = if (capitalize_next and c >= 'a' and c <= 'z')
                        c - 32  // Convert to uppercase
                    else
                        c;
                    camel_idx += 1;
                    capitalize_next = false;
                }
            }
            const camel_name = camel_buf[0..camel_idx];

            // Write alias
            try self.builder.writeFmt("const {s} = {s};\n", .{ snake, camel_name });
        }

        try self.builder.newline();
    }

    fn generateBehaviorImplementation(self: *Self, pattern_matcher: *PatternMatcher, b: *const Behavior) !void {
        // ALWAYS write this marker to verify we're using the latest emitter code
        // IMPORTANT: Check for custom implementation FIRST, before any pattern matching
        // If a behavior has an implementation field, use it instead of pattern-generated stubs
        if (b.implementation.len > 0) {
            // If implementation contains full function definition, write as-is
            if (std.mem.indexOf(u8, b.implementation, "pub fn ") != null or
                std.mem.indexOf(u8, b.implementation, "fn ") != null)
            {
                // Full function — write as-is (includes signature)
                try self.builder.writeLine(b.implementation);
                try self.builder.newline();
                return;
            } else {
                // Body only — wrap in inferred signature
                const sig = signature_mod.inferSignatureFromSpecAdvanced(self.allocator, b.given, b.then, b.name);
                try self.builder.writeFmt("pub fn {s}({s}) {s} {{\n", .{ b.name, sig.params, sig.ret });
                self.builder.incIndent();
                try self.builder.writeLine(b.implementation);
                self.builder.decIndent();
                try self.builder.writeLine("}");
                try self.builder.newline();
                return;
            }
        }

        // Try DSL patterns first (these are spec-level patterns)
        if (try pattern_matcher.generateFromDsLPattern(b)) {
            try self.builder.newline();
            return;
        }

        // Try when/then patterns (chat, lifecycle, etc.)
        // Only use if the pattern is safe (doesn't reference undefined types)
        const name = b.name;

        // RL patterns are self-contained (only reference rl.* types and primitives)
        const patterns_rl = @import("patterns/rl.zig");
        if (patterns_rl.isRlBehavior(name)) {
            if (try pattern_matcher.generateFromWhenThenPattern(b)) {
                try self.builder.newline();
                return;
            }
        }

        // Only use pattern system for behaviors where it generates self-contained code
        // (no references to undefined types like ChatTopicReal, InputLanguage)
        const is_safe_pattern = std.mem.eql(u8, name, "detectInputLanguage") or
            std.mem.eql(u8, name, "detectLanguage") or
            std.mem.startsWith(u8, name, "tensor_") or
            std.mem.startsWith(u8, name, "forward_") or
            std.mem.startsWith(u8, name, "backward_") or
            std.mem.indexOf(u8, name, "attention") != null or
            std.mem.indexOf(u8, name, "feedforward") != null or
            std.mem.startsWith(u8, name, "load_model") or
            std.mem.startsWith(u8, name, "save_model") or
            std.mem.startsWith(u8, name, "sample_token") or
            std.mem.startsWith(u8, name, "predict") or
            std.mem.startsWith(u8, name, "earn") or
            std.mem.startsWith(u8, name, "stake") or
            std.mem.startsWith(u8, name, "spend") or
            std.mem.startsWith(u8, name, "depin") or
            std.mem.indexOf(u8, name, "treasury") != null or
            std.mem.startsWith(u8, name, "reward") or
            std.mem.startsWith(u8, name, "fee") or
            std.mem.indexOf(u8, name, "governance") != null or
            std.mem.startsWith(u8, name, "hire") or
            std.mem.startsWith(u8, name, "terminate") or
            std.mem.indexOf(u8, name, "marketplace") != null or
            std.mem.startsWith(u8, name, "search") or
            std.mem.indexOf(u8, name, "match") != null or
            std.mem.startsWith(u8, name, "accept") or
            std.mem.startsWith(u8, name, "reject") or
            std.mem.indexOf(u8, name, "tenant") != null or
            std.mem.indexOf(u8, name, "billing") != null or
            std.mem.startsWith(u8, name, "save") or
            std.mem.startsWith(u8, name, "load") or
            std.mem.startsWith(u8, name, "init") or
            std.mem.startsWith(u8, name, "route") or
            std.mem.startsWith(u8, name, "scale") or
            std.mem.startsWith(u8, name, "multi") or
            std.mem.startsWith(u8, name, "emit") or
            std.mem.startsWith(u8, name, "record") or
            std.mem.startsWith(u8, name, "update") or
            std.mem.startsWith(u8, name, "health");


        if (is_safe_pattern) {
            if (try pattern_matcher.generateFromWhenThenPattern(b)) {
                try self.builder.newline();
                return;
            }
        }

        // Try VSA behavior patterns (real VSA calls) — delegated to vsa_emitter module
        if (try vsa_emitter.tryGenerateVSABehavior(&self.builder, &self.emission_state, b)) {
            try self.builder.newline();
            return;
        }

        // Generate real implementation from given/when/then semantics
        // Cycle 77: Mark comptime-evaluable pure functions
        if (zig_idioms_mod.isPureFunction(b.given, b.then, b.name)) {
            try self.builder.writeLine("// comptime-evaluable: pure function with no side effects");
        }
        try self.builder.writeFmt("/// {s}\n", .{b.given});
        try self.builder.writeFmt("/// When: {s}\n", .{b.when});
        try self.builder.writeFmt("/// Then: {s}\n", .{b.then});

        // No implementation — use pattern matching or auto-body
        const sig = signature_mod.inferSignatureFromSpec(b.given, b.then, b.name);

        // Cycle 76: Idiomatic idioms always applied (no mode gate)
        if (self.idioms) |idioms| {
            // Cycle 75: Strip self param for free functions (no owner)
            const base_params = if (b.owner == null and std.mem.eql(u8, sig.params, "self: *@This()"))
                ""
            else
                sig.params;
            const params = idioms.transformParams(base_params, b.given, b.then);
            const has_alloc = idioms.needsAllocator(b.given, b.then);
            const wrap_err = idioms.shouldWrapErrorUnion();
            // Prevent double error union: don't wrap if ret already starts with '!'
            const already_error = sig.ret.len > 0 and sig.ret[0] == '!';
            // Cycle 76: Don't wrap error union for pure functions (no allocator needed)
            const do_wrap = wrap_err and !already_error and has_alloc;
            // Cycle 77: Infer specific error set when wrapping
            const error_set: ?[]const u8 = if (do_wrap) zig_idioms_mod.inferErrorSet(b.given, b.then, b.name) else null;

            // Write function signature with idiom transforms
            if (idioms.hasOriginalParams(base_params, b.given, b.then)) {
                // Allocator + original params
                if (error_set) |es| {
                    try self.builder.writeFmt("pub fn {s}({s}, {s}) {s}!{s} {{\n", .{ b.name, params, base_params, es, sig.ret });
                } else if (do_wrap) {
                    try self.builder.writeFmt("pub fn {s}({s}, {s}) !{s} {{\n", .{ b.name, params, base_params, sig.ret });
                } else {
                    try self.builder.writeFmt("pub fn {s}({s}, {s}) {s} {{\n", .{ b.name, params, base_params, sig.ret });
                }
            } else if (has_alloc) {
                // Allocator only (no original params)
                if (error_set) |es| {
                    try self.builder.writeFmt("pub fn {s}({s}) {s}!{s} {{\n", .{ b.name, params, es, sig.ret });
                } else if (do_wrap) {
                    try self.builder.writeFmt("pub fn {s}({s}) !{s} {{\n", .{ b.name, params, sig.ret });
                } else {
                    try self.builder.writeFmt("pub fn {s}({s}) {s} {{\n", .{ b.name, params, sig.ret });
                }
            } else {
                // No allocator needed
                if (do_wrap) {
                    try self.builder.writeFmt("pub fn {s}({s}) !{s} {{\n", .{ b.name, base_params, sig.ret });
                } else {
                    try self.builder.writeFmt("pub fn {s}({s}) {s} {{\n", .{ b.name, base_params, sig.ret });
                }
            }
            self.builder.incIndent();
            try idioms.emitCleanup(&self.builder, has_alloc);
            try idioms.emitAllocatorSetup(&self.builder);
            try body_emitter.generateRealBody(&self.builder, b);
            self.builder.decIndent();
            try self.builder.writeLine("}");
            try self.builder.newline();
            try self.builder.newline();
            return;
        }

        // Fallback (idioms not initialized — shouldn't happen in normal flow)
        try self.builder.writeFmt("pub fn {s}({s}) {s} {{\n", .{ b.name, sig.params, sig.ret });
        self.builder.incIndent();
        try body_emitter.generateRealBody(&self.builder, b);
        self.builder.decIndent();
        try self.builder.writeLine("}");
        try self.builder.newline();
        try self.builder.newline();
    }

    /// Generate real function body from behavior given/when/then fields
    /// Delegated to body_emitter module
    fn generateRealBody(self: *Self, b: *const Behavior) !void {
        try body_emitter.generateRealBody(&self.builder, b);
    }

    /// Resolve a type name from the spec's types: section.
    /// Returns the Zig type representation for a custom type.
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn resolveTypeName(self: *Self, type_name: []const u8) []const u8 {
        return type_resolver.resolveTypeName(self.spec_types, type_name);
    }

    /// Find matching closing bracket for nested generics
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn findMatchingBracket(str: []const u8, start_pos: usize) ?usize {
        return type_resolver.findMatchingBracket(str, start_pos);
    }

    /// Parse complex type syntax (no-alloc fast path)
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn parseComplexTypeNoAlloc(self: *Self, type_str: []const u8) ?[]const u8 {
        return type_resolver.parseComplexTypeNoAlloc(self.spec_types, type_str);
    }

    /// Parse complex type syntax (allocating path)
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn parseComplexType(self: *Self, type_str: []const u8) ![]const u8 {
        return type_resolver.parseComplexType(self.allocator, self.spec_types, type_str);
    }

    /// Map semantic type names to concrete Zig types
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn mapSemanticType(type_name: []const u8) []const u8 {
        return type_resolver.mapSemanticType(type_name);
    }

    /// Resolve type from spec.types or semantic mapping
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn resolveTypeFromSpec(self: *Self, type_name: []const u8) []const u8 {
        return type_resolver.resolveTypeFromSpec(self.spec_types, type_name);
    }

    /// Extract count from phrase
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn extractCount(phrase: []const u8) ?usize {
        return type_resolver.extractCount(phrase);
    }

    /// Extract base type from phrase
    /// Delegated to type_resolver module (VIBEE-first, Cycle 79)
    fn extractBaseType(phrase: []const u8) []const u8 {
        return type_resolver.extractBaseType(phrase);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SIGNATURE INFERENCE — Delegated to signature module
    // ═══════════════════════════════════════════════════════════════════════════════

    const SignatureInfo = signature_mod.SignatureInfo;

    fn inferSignatureFromSpecAdvanced(self: *Self, given: []const u8, then: []const u8, name: []const u8) SignatureInfo {
        return signature_mod.inferSignatureFromSpecAdvanced(self.allocator, given, then, name);
    }

    fn inferSignatureFromSpec(given: []const u8, then: []const u8, name: []const u8) SignatureInfo {
        return signature_mod.inferSignatureFromSpec(given, then, name);
    }

    fn containsAnyCI(haystack: []const u8, needles: []const []const u8) bool {
        return signature_mod.containsAnyCI(haystack, needles);
    }

    fn containsCI(haystack: []const u8, needle: []const u8) bool {
        return signature_mod.containsCI(haystack, needle);
    }

    fn toLowerASCII(c: u8) u8 {
        return signature_mod.toLowerASCII(c);
    }
};
