// ═══════════════════════════════════════════════════════════════════════════════
// ZIG IDIOMS — Idiomatic Zig code generation transforms (Cycle 74→76)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Transforms generated Zig code to follow community best practices:
// - Explicit allocator parameters (ziggit.dev/14043 naming conventions)
// - defer/errdefer cleanup (ziggit.dev/11489 diagnostics pattern)
// - Error unions !T (no anyerror — community best practice)
//
// Cycle 76: Idiomatic mode is now the default — transforms always apply.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("types.zig");
const builder_mod = @import("builder.zig");

const VibeeSpec = types.VibeeSpec;
const ZigMode = types.ZigMode;
const AllocatorStrategy = types.AllocatorStrategy;
const CodeBuilder = builder_mod.CodeBuilder;

/// Zig idiom transformation engine
/// Controls how generated code follows Zig community conventions
pub const ZigIdioms = struct {
    mode: ZigMode,
    allocator_strategy: AllocatorStrategy,
    error_set_names: []const []const u8,

    const Self = @This();

    /// Create ZigIdioms from parsed spec
    pub fn fromSpec(spec: *const VibeeSpec) Self {
        return .{
            .mode = spec.zig_mode,
            .allocator_strategy = spec.allocator_strategy,
            .error_set_names = spec.error_sets.items,
        };
    }

    /// Returns true if idioms should be applied
    /// Cycle 76: Always active — idiomatic is the default
    pub fn isActive(self: Self) bool {
        _ = self;
        return true;
    }

    /// Check if behavior works with heap-allocated data (needs allocator param)
    /// Scans given/then descriptions for allocation-related keywords
    /// Cycle 76: Removed mode check — always scan keywords
    pub fn needsAllocator(self: Self, given: []const u8, then: []const u8) bool {
        if (self.allocator_strategy == .none) return false;

        // Check given description
        if (containsAllocKeyword(given)) return true;
        // Check then description
        if (containsAllocKeyword(then)) return true;

        return false;
    }

    /// Transform function parameters: prepend allocator if needed
    /// Returns new params string (or original if no transform)
    /// Cycle 76: Always applies — "allocator: Allocator, <original_params>"
    pub fn transformParams(self: Self, params: []const u8, given: []const u8, then: []const u8) []const u8 {
        if (self.allocator_strategy == .none) return params;
        if (!self.needsAllocator(given, then)) return params;

        // Return the allocator-prefixed version
        // Since we can't allocate here (no allocator available), we use comptime strings
        if (params.len == 0) {
            return "allocator: std.mem.Allocator";
        }
        // For non-empty params, the emitter will handle the concatenation
        return "allocator: std.mem.Allocator";
    }

    /// Check if original params should be appended after allocator
    /// Cycle 76: Removed mode check
    pub fn hasOriginalParams(self: Self, params: []const u8, given: []const u8, then: []const u8) bool {
        if (self.allocator_strategy == .none) return false;
        if (!self.needsAllocator(given, then)) return false;
        return params.len > 0;
    }

    /// Wrap return type with error union: T → !T
    /// Cycle 76: Always wrap — idiomatic is the default
    pub fn shouldWrapErrorUnion(self: Self) bool {
        _ = self;
        return true;
    }

    /// Emit defer/errdefer cleanup after function opening brace
    /// - defer: cleanup resources on normal exit
    /// - errdefer: diagnostic logging on error exit
    /// Cycle 76: Removed mode check — always emit when has_alloc
    pub fn emitCleanup(self: Self, builder: *CodeBuilder, has_alloc: bool) !void {
        _ = self;
        if (!has_alloc) return;

        // Emit errdefer for error diagnostics (ziggit.dev/11489 pattern)
        try builder.writeLine("// Idiomatic Zig: errdefer for error diagnostics");
        try builder.writeLine("errdefer |err| {");
        builder.incIndent();
        try builder.writeLine("std.debug.print(\"Error in behavior: {}\\n\", .{err});");
        builder.decIndent();
        try builder.writeLine("}");
    }

    /// Emit allocator-specific setup code
    pub fn emitAllocatorSetup(self: Self, builder: *CodeBuilder) !void {
        switch (self.allocator_strategy) {
            .arena => {
                try builder.writeLine("// Arena allocator setup");
                try builder.writeLine("var arena = std.heap.ArenaAllocator.init(allocator);");
                try builder.writeLine("defer arena.deinit();");
                try builder.writeLine("const alloc = arena.allocator();");
            },
            .gpa => {
                try builder.writeLine("// GPA allocator (debug mode)");
                try builder.writeLine("_ = allocator; // GPA passed from caller");
            },
            .param => {
                // No extra setup — allocator used directly
            },
            .none => {},
        }
    }

    /// Get the allocator variable name for the current strategy
    pub fn allocatorName(self: Self) []const u8 {
        return switch (self.allocator_strategy) {
            .arena => "alloc",
            .gpa, .param => "allocator",
            .none => "",
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if a description string contains allocation-related keywords
fn containsAllocKeyword(text: []const u8) bool {
    const keywords = [_][]const u8{
        "String",
        "string",
        "List",
        "list",
        "ArrayList",
        "Vector",
        "vector",
        "Buffer",
        "buffer",
        "Array",
        "array",
        "allocat",
        "slice",
        "Slice",
        "dynamic",
        "heap",
        "encoded",
        "representation",
    };
    for (keywords) |kw| {
        if (std.mem.indexOf(u8, text, kw) != null) return true;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "zig_idioms_always_active" {
    // Cycle 76: Idioms always active regardless of mode
    const idioms = ZigIdioms{
        .mode = .standard,
        .allocator_strategy = .none,
        .error_set_names = &.{},
    };
    try std.testing.expect(idioms.isActive());
    // With allocator_strategy = .none, no allocator is prepended
    try std.testing.expect(!idioms.needsAllocator("input", "output"));
    try std.testing.expectEqualStrings("self: *@This()", idioms.transformParams("self: *@This()", "input", "output"));
}

test "zig_idioms_idiomatic_allocator" {
    // Idiomatic mode with param strategy
    const idioms = ZigIdioms{
        .mode = .idiomatic,
        .allocator_strategy = .param,
        .error_set_names = &.{},
    };
    try std.testing.expect(idioms.isActive());
    try std.testing.expect(idioms.needsAllocator("A float value", "Returns TritVector with encoded representation"));
    try std.testing.expect(idioms.shouldWrapErrorUnion());
}

test "zig_idioms_alloc_none_skips" {
    // With allocator_strategy = .none, allocator checks are skipped
    const idioms = ZigIdioms{
        .mode = .wasm,
        .allocator_strategy = .none,
        .error_set_names = &.{},
    };
    try std.testing.expect(idioms.isActive());
    try std.testing.expect(!idioms.needsAllocator("input", "Returns slice"));
    // Cycle 76: shouldWrapErrorUnion is always true now
    try std.testing.expect(idioms.shouldWrapErrorUnion());
}

test "containsAllocKeyword_detects_keywords" {
    try std.testing.expect(containsAllocKeyword("Returns ArrayList of items"));
    try std.testing.expect(containsAllocKeyword("A string value"));
    try std.testing.expect(containsAllocKeyword("Returns TritVector with encoded representation"));
    try std.testing.expect(!containsAllocKeyword("An integer exponent n >= 0"));
    try std.testing.expect(!containsAllocKeyword("Returns true if identity holds"));
}
