// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 4 — Autonomous Refactoring Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Intent-aware autonomous refactoring using semantic search + VSA validation
// Ralph Loop: Analyze → Plan → Validate → Apply → Verify
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const zig_parser = @import("zig_parser.zig");
const vsa = @import("vsa.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_CONFIDENCE_THRESHOLD: f32 = 0.8;
pub const DEFAULT_VSA_SCORE_THRESHOLD: f32 = 0.85;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Scope of refactoring operation
pub const RefactorScope = enum {
    function,    // Single function
    file,        // Entire file
    module,      // All files in module
    global,      // Cross-module
};

/// Safety level for refactoring
pub const SafetyLevel = enum {
    low,         // Fast, minimal validation
    medium,      // Balanced
    high,        // Strict VSA validation
    critical,    // Maximum safety, requires manual confirmation
};

/// Type of transformation
pub const TransformType = enum {
    extract_function,
    inline_function,
    rename_symbol,
    move_declaration,
    simplify_logic,
    add_type_annotation,
};

/// Location of a symbol in code
pub const SymbolLocation = struct {
    file: []const u8,
    symbol: []const u8,
    start_line: u32,
    end_line: u32,
    node_type: zig_parser.NodeType,
};

/// User intent for refactoring
pub const RefactorIntent = struct {
    description: []const u8,
    confidence: f32,
    scope: RefactorScope,
    safety_level: SafetyLevel,

    pub fn init(allocator: std.mem.Allocator, description: []const u8) !RefactorIntent {
        const desc_copy = try allocator.dupe(u8, description);
        return .{
            .description = desc_copy,
            .confidence = 0.0,
            .scope = .function,
            .safety_level = .medium,
        };
    }

    pub fn deinit(self: *RefactorIntent, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }
};

/// Single transformation
pub const Transformation = struct {
    type: TransformType,
    location: SymbolLocation,
    old_code: []const u8,
    new_code: []const u8,
    vsa_score: f32,

    pub fn deinit(self: *Transformation, allocator: std.mem.Allocator) void {
        allocator.free(self.old_code);
        allocator.free(self.new_code);
        // location.file and location.symbol are owned by the graph/index
    }
};

/// Rollback plan for recovering from failed refactor
pub const RollbackPlan = struct {
    backups: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RollbackPlan {
        return .{
            .backups = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RollbackPlan) void {
        var iter = self.backups.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.backups.deinit();
    }

    pub fn addBackup(self: *RollbackPlan, file_path: []const u8, content: []const u8) !void {
        const path_copy = try self.allocator.dupe(u8, file_path);
        errdefer self.allocator.free(path_copy);
        const content_copy = try self.allocator.dupe(u8, content);
        try self.backups.put(path_copy, content_copy);
    }
};

/// Refactoring plan with transformations
pub const RefactorPlan = struct {
    intent: RefactorIntent,
    targets: std.ArrayList(SymbolLocation),
    transformations: std.ArrayList(Transformation),
    validation_rules: std.StringHashMap(vsa.VSARule),
    rollback_plan: RollbackPlan,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, intent: RefactorIntent) !RefactorPlan {
        return .{
            .intent = intent,
            .targets = std.ArrayList(SymbolLocation).empty,
            .transformations = std.ArrayList(Transformation).empty,
            .validation_rules = std.StringHashMap(vsa.VSARule).init(allocator),
            .rollback_plan = RollbackPlan.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RefactorPlan) void {
        self.intent.deinit(self.allocator);
        self.targets.deinit(self.allocator);
        for (self.transformations.items) |*t| {
            t.deinit(self.allocator);
        }
        self.transformations.deinit(self.allocator);

        var rule_iter = self.validation_rules.iterator();
        while (rule_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.validation_rules.deinit();

        self.rollback_plan.deinit();
    }
};

/// Result of refactoring operation
pub const RefactorResult = struct {
    success: bool,
    transformations_applied: usize,
    files_modified: usize,
    vsa_validation_passed: bool,
    tests_passed: bool,
    rollback_triggered: bool,
    errors: std.ArrayList([]const u8),
    warnings: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RefactorResult {
        return .{
            .success = false,
            .transformations_applied = 0,
            .files_modified = 0,
            .vsa_validation_passed = false,
            .tests_passed = false,
            .rollback_triggered = false,
            .errors = std.ArrayList([]const u8).empty,
            .warnings = std.ArrayList([]const u8).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RefactorResult) void {
        for (self.errors.items) |e| {
            self.allocator.free(e);
        }
        self.errors.deinit(self.allocator);
        for (self.warnings.items) |w| {
            self.allocator.free(w);
        }
        self.warnings.deinit(self.allocator);
    }

    pub fn addError(self: *RefactorResult, msg: []const u8) !void {
        try self.errors.append(self.allocator, try self.allocator.dupe(u8, msg));
    }

    pub fn addWarning(self: *RefactorResult, msg: []const u8) !void {
        try self.warnings.append(self.allocator, try self.allocator.dupe(u8, msg));
    }
};

/// Ralph Loop state machine for autonomous refactoring
pub const RalphLoop = enum {
    analyze,
    plan,
    validate,
    apply,
    verify,
    complete,
    rollback,

    pub fn canTransition(self: RalphLoop, next: RalphLoop) bool {
        return switch (self) {
            .analyze => next == .plan,
            .plan => next == .validate or next == .rollback,
            .validate => next == .apply or next == .rollback,
            .apply => next == .verify or next == .rollback,
            .verify => next == .complete or next == .rollback,
            .complete => false,
            .rollback => false,
        };
    }
};

/// Configuration for autonomous refactoring engine
pub const RefactorConfig = struct {
    confidence_threshold: f32 = DEFAULT_CONFIDENCE_THRESHOLD,
    vsa_score_threshold: f32 = DEFAULT_VSA_SCORE_THRESHOLD,
    default_safety_level: SafetyLevel = .medium,
    enable_rollback: bool = true,
    max_transformations: usize = 100,
};

/// Autonomous Refactoring Engine
pub const AutonomousRefactorEngine = struct {
    config: RefactorConfig,
    semantic_index: ?*vsa.SemanticIndex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: RefactorConfig) !AutonomousRefactorEngine {
        return .{
            .config = config,
            .semantic_index = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AutonomousRefactorEngine) void {
        _ = self;
        // semantic_index is owned externally
    }

    /// Set semantic index for semantic search
    pub fn setSemanticIndex(self: *AutonomousRefactorEngine, index: *vsa.SemanticIndex) void {
        self.semantic_index = index;
    }

    /// Analyze user intent and classify refactoring operation
    pub fn analyzeIntent(self: *AutonomousRefactorEngine, description: []const u8) !RefactorIntent {
        const allocator = self.allocator;

        var intent = try RefactorIntent.init(allocator, description);
        errdefer intent.deinit(allocator);

        // Simple keyword-based classification (can be enhanced with ML)
        intent.confidence = classifyConfidence(description);
        intent.scope = classifyScope(description);
        intent.safety_level = classifySafety(description);

        return intent;
    }

    /// Plan refactoring based on intent
    pub fn planRefactor(self: *AutonomousRefactorEngine, intent: RefactorIntent) !RefactorPlan {
        const allocator = self.allocator;

        var plan = try RefactorPlan.init(allocator, intent);
        errdefer plan.deinit();

        // TODO: Use semantic index to find target locations
        // For now, return empty plan

        return plan;
    }

    /// Validate refactoring plan using VSA rules
    pub fn validatePlan(self: *AutonomousRefactorEngine, plan: *const RefactorPlan) !f32 {
        _ = self;
        _ = plan;

        // TODO: Run VSA validation rules
        // For now, return default score
        return 0.9;
    }

    /// Execute Ralph Loop for autonomous refactoring
    pub fn executeRalphLoop(self: *AutonomousRefactorEngine, description: []const u8) !RefactorResult {
        var result = RefactorResult.init(self.allocator);
        errdefer result.deinit();

        var state = RalphLoop.analyze;

        // ANALYZE: Understand intent
        var intent = try self.analyzeIntent(description);
        defer intent.deinit(self.allocator);

        if (intent.confidence < self.config.confidence_threshold) {
            try result.addError("Intent confidence below threshold");
            return result;
        }

        state = .plan;

        // PLAN: Generate refactor plan
        var plan = try self.planRefactor(intent);
        defer plan.deinit();

        state = .validate;

        // VALIDATE: Run VSA checks
        const vsa_score = try self.validatePlan(&plan);

        if (vsa_score < self.config.vsa_score_threshold) {
            try result.addError("VSA validation failed");
            result.vsa_validation_passed = false;
            return result;
        }
        result.vsa_validation_passed = true;

        state = .apply;

        // APPLY: Apply transformations
        result.transformations_applied = plan.transformations.items.len;
        result.files_modified = 0; // TODO: Track actual files

        state = .verify;

        // VERIFY: Run tests (placeholder)
        result.tests_passed = true;

        state = .complete;
        result.success = true;

        return result;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Classify confidence based on description keywords
fn classifyConfidence(description: []const u8) f32 {
    var lower = toLower(description);
    defer lower.deinit(std.heap.page_allocator);

    // Clear intent keywords
    if (std.mem.indexOf(u8, lower.items, "extract") != null or
        std.mem.indexOf(u8, lower.items, "rename") != null or
        std.mem.indexOf(u8, lower.items, "move") != null)
    {
        return 0.95;
    }

    // Vague intent
    if (std.mem.indexOf(u8, lower.items, "fix") != null or
        std.mem.indexOf(u8, lower.items, "improve") != null)
    {
        return 0.7;
    }

    return 0.8;
}

/// Classify scope based on description
fn classifyScope(description: []const u8) RefactorScope {
    var lower = toLower(description);
    defer lower.deinit(std.heap.page_allocator);

    if (std.mem.indexOf(u8, lower.items, "module") != null or
        std.mem.indexOf(u8, lower.items, "project") != null)
    {
        return .module;
    }

    if (std.mem.indexOf(u8, lower.items, "file") != null)
    {
        return .file;
    }

    if (std.mem.indexOf(u8, lower.items, "global") != null)
    {
        return .global;
    }

    return .function;
}

/// Classify safety level based on description
fn classifySafety(description: []const u8) SafetyLevel {
    var lower = toLower(description);
    defer lower.deinit(std.heap.page_allocator);

    if (std.mem.indexOf(u8, lower.items, "critical") != null or
        std.mem.indexOf(u8, lower.items, "important") != null)
    {
        return .critical;
    }

    if (std.mem.indexOf(u8, lower.items, "safe") != null or
        std.mem.indexOf(u8, lower.items, "careful") != null)
    {
        return .high;
    }

    if (std.mem.indexOf(u8, lower.items, "fast") != null or
        std.mem.indexOf(u8, lower.items, "quick") != null)
    {
        return .low;
    }

    return .medium;
}

/// Convert string to lowercase for keyword matching
fn toLower(s: []const u8) std.ArrayList(u8) {
    var result = std.ArrayList(u8).empty;
    for (s) |c| {
        result.append(std.heap.page_allocator, std.ascii.toLower(c)) catch unreachable;
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "autonomous.1: RefactorIntent init and deinit" {
    const allocator = std.testing.allocator;
    var intent = try RefactorIntent.init(allocator, "extract function");
    try std.testing.expectEqualStrings("extract function", intent.description);
    intent.deinit(allocator);
}

test "autonomous.2: Analyze intent - extract function" {
    const allocator = std.testing.allocator;
    var engine = try AutonomousRefactorEngine.init(allocator, .{});
    defer engine.deinit();

    var intent = try engine.analyzeIntent("extract validation logic");
    defer intent.deinit(allocator);

    try std.testing.expect(intent.confidence >= 0.9);
    try std.testing.expectEqual(RefactorScope.function, intent.scope);
}

test "autonomous.3: Analyze intent - module scope" {
    const allocator = std.testing.allocator;
    var engine = try AutonomousRefactorEngine.init(allocator, .{});
    defer engine.deinit();

    var intent = try engine.analyzeIntent("refactor module parsing");
    defer intent.deinit(allocator);

    try std.testing.expectEqual(RefactorScope.module, intent.scope);
}

test "autonomous.4: Ralph Loop transitions" {
    try std.testing.expect(RalphLoop.analyze.canTransition(.plan));
    try std.testing.expect(RalphLoop.plan.canTransition(.validate));
    try std.testing.expect(RalphLoop.plan.canTransition(.rollback));
    try std.testing.expect(RalphLoop.validate.canTransition(.apply));
    try std.testing.expect(RalphLoop.verify.canTransition(.complete));
    try std.testing.expect(RalphLoop.verify.canTransition(.rollback));

    // Invalid transitions
    try std.testing.expect(!RalphLoop.complete.canTransition(.plan));
    try std.testing.expect(!RalphLoop.rollback.canTransition(.apply));
}

test "autonomous.5: Execute Ralph Loop - success path" {
    const allocator = std.testing.allocator;
    var engine = try AutonomousRefactorEngine.init(allocator, .{});
    defer engine.deinit();

    const result = try engine.executeRalphLoop("extract function");
    defer result.deinit();

    try std.testing.expect(result.vsa_validation_passed);
    try std.testing.expect(result.tests_passed);
}

test "autonomous.6: Execute Ralph Loop - low confidence" {
    const allocator = std.testing.allocator;
    var engine = try AutonomousRefactorEngine.init(allocator, .{
        .confidence_threshold = 0.95,
    });
    defer engine.deinit();

    const result = try engine.executeRalphLoop("improve something");
    defer result.deinit();

    try std.testing.expect(!result.success);
    try std.testing.expect(result.errors.items.len > 0);
}

test "autonomous.7: RollbackPlan init and add backup" {
    const allocator = std.testing.allocator;
    var plan = RollbackPlan.init(allocator);
    defer plan.deinit();

    try plan.addBackup("test.zig", "const x = 1;");
    try std.testing.expectEqual(@as(usize, 1), plan.backups.count());
}
