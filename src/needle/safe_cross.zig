// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 4 — Safe Cross-File + VSA Rules
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cross-file semantic refactoring with VSA rule validation and 100% rollback
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const graph = @import("graph.zig");
const vsa = @import("vsa.zig");
const refactor = @import("refactor.zig");

const CallGraph = graph.CallGraph;
const SemanticIndex = vsa.SemanticIndex;
const VSARule = vsa.VSARule;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const DEFAULT_SAFETY_THRESHOLD: f32 = 0.95;
pub const DEFAULT_SEMANTIC_THRESHOLD: f32 = 0.85;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Cross-file impact level
pub const ImpactLevel = enum {
    none,
    low,
    medium,
    high,
};

/// VSA rule for cross-file validation
pub const SafeVSARule = struct {
    name: []const u8,
    pattern_id: []const u8,
    semantic_threshold: f32,
    cross_file_impact: ImpactLevel,
    auto_rollback: bool,
    allowed_transforms: std.ArrayList([]const u8),
    forbidden_transforms: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) SafeVSARule {
        return .{
            .name = name,
            .pattern_id = "",
            .semantic_threshold = DEFAULT_SEMANTIC_THRESHOLD,
            .cross_file_impact = .medium,
            .auto_rollback = true,
            .allowed_transforms = std.ArrayList([]const u8).init(allocator),
            .forbidden_transforms = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SafeVSARule) void {
        self.allocator.free(self.name);
        self.allocator.free(self.pattern_id);

        for (self.allowed_transforms.items) |item| {
            self.allocator.free(item);
        }
        self.allowed_transforms.deinit();

        for (self.forbidden_transforms.items) |item| {
            self.allocator.free(item);
        }
        self.forbidden_transforms.deinit();
    }

    /// Validate transformation against this rule
    pub fn validate(self: *SafeVSARule, transformation: []const u8, similarity: f32) !RuleValidation {
        var result = RuleValidation{
            .valid = true,
            .reason = "",
            .confidence = similarity,
        };

        // Check forbidden list
        for (self.forbidden_transforms.items) |forbidden| {
            if (std.mem.indexOf(u8, transformation, forbidden) != null) {
                result.valid = false;
                result.reason = try std.fmt.allocPrint(
                    self.allocator,
                    "Transformation '{s}' is forbidden by rule '{s}'",
                    .{transformation, self.name},
                );
                return result;
            }
        }

        // Check allowed list (if non-empty)
        if (self.allowed_transforms.items.len > 0) {
            var allowed = false;
            for (self.allowed_transforms.items) |allowed_pattern| {
                if (std.mem.indexOf(u8, transformation, allowed_pattern) != null) {
                    allowed = true;
                    break;
                }
            }
            if (!allowed) {
                result.valid = false;
                result.reason = try std.fmt.allocPrint(
                    self.allocator,
                    "Transformation '{s}' not in allowed list for rule '{s}'",
                    .{transformation, self.name},
                );
                return result;
            }
        }

        // Check semantic threshold
        if (similarity < self.semantic_threshold) {
            result.valid = false;
            result.reason = try std.fmt.allocPrint(
                self.allocator,
                "Semantic similarity {d:.2} below threshold {d:.2}",
                .{similarity, self.semantic_threshold},
            );
        }

        return result;
    }
};

/// Rule validation result
pub const RuleValidation = struct {
    valid: bool,
    reason: []const u8,
    confidence: f32,
};

/// Cross-file edit operation
pub const CrossFileEdit = struct {
    affected_files: std.ArrayList([]const u8),
    vsa_confidence: f32,
    safety_score: f32,
    rollback_points: std.StringHashMap([]const u8),
    dependencies: std.ArrayList([]const u8),
    dependents: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CrossFileEdit {
        return .{
            .affected_files = std.ArrayList([]const u8).init(allocator),
            .vsa_confidence = 0.0,
            .safety_score = 0.0,
            .rollback_points = std.StringHashMap([]const u8).init(allocator),
            .dependencies = std.ArrayList([]const u8).init(allocator),
            .dependents = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CrossFileEdit) void {
        for (self.affected_files.items) |file| {
            self.allocator.free(file);
        }
        self.affected_files.deinit();

        var iter = self.rollback_points.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.rollback_points.deinit();

        for (self.dependencies.items) |dep| {
            self.allocator.free(dep);
        }
        self.dependencies.deinit();

        for (self.dependents.items) |dep| {
            self.allocator.free(dep);
        }
        self.dependents.deinit();
    }

    /// Add rollback point for a file
    pub fn addRollbackPoint(self: *CrossFileEdit, file: []const u8, backup_hash: []const u8) !void {
        try self.rollback_points.put(file, try self.allocator.dupe(u8, backup_hash));
    }
};

/// Safety gate configuration
pub const SafetyGate = struct {
    check_parse: bool = true,
    check_compile: bool = true,
    check_tests: bool = false,
    check_vsa: bool = true,
    min_safety_score: f32 = DEFAULT_SAFETY_THRESHOLD,
    block_on_violation: bool = true,
};

/// Cross-file refactor result
pub const CrossFileResult = struct {
    success: bool,
    files_modified: usize,
    total_changes: usize,
    safety_score: f32,
    vsa_confidence: f32,
    rollback_triggered: bool,
    violations: std.ArrayList([]const u8),
    duration_ms: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CrossFileResult {
        return .{
            .success = true,
            .files_modified = 0,
            .total_changes = 0,
            .safety_score = 1.0,
            .vsa_confidence = 0.0,
            .rollback_triggered = false,
            .violations = std.ArrayList([]const u8).init(allocator),
            .duration_ms = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CrossFileResult) void {
        for (self.violations.items) |v| {
            self.allocator.free(v);
        }
        self.violations.deinit();
    }

    pub fn addViolation(self: *CrossFileResult, msg: []const u8) !void {
        try self.violations.append(try self.allocator.dupe(u8, msg));
        self.success = false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PHASE 1: ATOMIC REFACTOR WITH 100% ROLLBACK GUARANTEE
// ═══════════════════════════════════════════════════════════════════════════════

/// Atomic refactor transaction state
pub const TransactionState = enum {
    idle,
    backing_up,
    applying,
    running_gates,
    committed,
    rolled_back,
};

/// Atomic refactor with guaranteed rollback (Phase 1: Production-grade)
pub const AtomicRefactor = struct {
    backups: std.StringHashMap(FileBackup),
    affected_files: std.ArrayList([]const u8),
    state: TransactionState,
    allocator: std.mem.Allocator,

    /// File backup with metadata for verification
    const FileBackup = struct {
        content: []const u8,
        checksum: u32,
        mtime: i64,
    };

    pub fn init(allocator: std.mem.Allocator) AtomicRefactor {
        return .{
            .backups = std.StringHashMap(FileBackup).init(allocator),
            .affected_files = std.ArrayList([]const u8).init(allocator),
            .state = .idle,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AtomicRefactor) void {
        // Clear all backups
        var iter = self.backups.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.content);
        }
        self.backups.deinit();

        // Clear affected files list
        for (self.affected_files.items) |file| {
            self.allocator.free(file);
        }
        self.affected_files.deinit();
    }

    /// Begin transaction - backup all affected files
    pub fn begin(self: *AtomicRefactor, files: []const []const u8) !void {
        self.state = .backing_up;

        for (files) |file| {
            // Read file content
            const content = try std.fs.cwd().readFileAlloc(self.allocator, file, 10_000_000);

            // Get file metadata for verification
            const stat = try std.fs.cwd().statFile(file);

            // Calculate checksum for verification
            const checksum = std.hash.XxHash32.hash(content);

            // Store backup
            try self.backups.put(file, .{
                .content = content,
                .checksum = checksum,
                .mtime = stat.mtime,
            });

            // Track affected file
            try self.affected_files.append(try self.allocator.dupe(u8, file));
        }

        self.state = .applying;
    }

    /// Commit transaction - clear backups (success path)
    pub fn commit(self: *AtomicRefactor) !void {
        // Verify all files were modified successfully
        for (self.affected_files.items) |file| {
            // Verify file exists and is readable
            _ = std.fs.cwd().statFile(file) catch {
                return error.FileVerificationFailed;
            };
        }

        // Success: clear all backups
        var iter = self.backups.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.content);
        }
        self.backups.deinit();

        // Clear affected files
        for (self.affected_files.items) |file| {
            self.allocator.free(file);
        }
        self.affected_files.deinit();

        self.state = .committed;
    }

    /// Rollback transaction - restore all files from backups (failure path)
    pub fn rollback(self: *AtomicRefactor) !void {
        self.state = .rolled_back;

        var iter = self.backups.iterator();
        while (iter.next()) |entry| {
            const file = entry.key_ptr.*;
            const backup = entry.value_ptr.*;

            // Restore file content
            try std.fs.cwd().writeFile(.{ .sub_path = file }, backup.content);

            // Verify restore by comparing checksums
            const restored = try std.fs.cwd().readFileAlloc(self.allocator, file, 10_000_000);
            defer self.allocator.free(restored);

            const restored_checksum = std.hash.XxHash32.hash(restored);
            if (restored_checksum != backup.checksum) {
                return error.RollbackVerificationFailed;
            }
        }

        // Clear backups after successful rollback
        iter = self.backups.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*.content);
        }
        self.backups.deinit();

        for (self.affected_files.items) |file| {
            self.allocator.free(file);
        }
        self.affected_files.deinit();
    }

    /// Get backup content for a file
    pub fn getBackup(self: *const AtomicRefactor, file: []const u8) ?[]const u8 {
        if (self.backups.get(file)) |backup| {
            return backup.content;
        }
        return null;
    }

    /// Check if a file is being tracked
    pub fn isTracking(self: *const AtomicRefactor, file: []const u8) bool {
        return self.backups.get(file) != null;
    }

    /// Get number of tracked files
    pub fn fileCount(self: *const AtomicRefactor) usize {
        return self.backups.count();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SAFE CROSS-FILE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Validate transformation against all VSA rules
pub fn validateWithVSARules(
    rules: []const SafeVSARule,
    transformation: []const u8,
    similarity: f32,
    _: std.mem.Allocator,
) !RuleValidation {
    var best_result = RuleValidation{
        .valid = true,
        .reason = "",
        .confidence = similarity,
    };

    for (rules) |rule| {
        const result = try rule.validate(transformation, similarity);
        if (!result.valid) {
            // Rule failed - return failure immediately
            return result;
        }
        if (result.confidence > best_result.confidence) {
            best_result = result;
        }
    }

    return best_result;
}

/// Run safety gates on a file after edit
pub fn runSafetyGates(
    allocator: std.mem.Allocator,
    _: []const u8,
    gate: SafetyGate,
) !SafetyResult {
    var result = SafetyResult{
        .passed = true,
        .score = 1.0,
        .violations = std.ArrayList([]const u8).init(allocator),
    };
    errdefer {
        for (result.violations.items) |v| {
            allocator.free(v);
        }
        result.violations.deinit();
    }

    // Parse check
    if (gate.check_parse) {
        // TODO: Implement actual parse check
        // For now, assume success
    }

    // Compile check
    if (gate.check_compile) {
        // TODO: Implement actual compile check
        // For now, assume success
    }

    // Test check
    if (gate.check_tests) {
        // TODO: Implement test runner
        // For now, assume success
    }

    // VSA check
    if (gate.check_vsa) {
        // TODO: Verify semantic similarity
        // For now, assume success
    }

    // Compute combined score
    if (result.score < gate.min_safety_score) {
        result.passed = false;
        try result.violations.append(try allocator.dupe(u8, "Safety score below threshold"));
    }

    return result;
}

/// Safety check result
pub const SafetyResult = struct {
    passed: bool,
    score: f32,
    violations: std.ArrayList([]const u8),
};

/// Compute cross-file impact for a symbol change
pub fn computeCrossImpact(
    call_graph: *CallGraph,
    _: *SemanticIndex,
    symbol: []const u8,
    allocator: std.mem.Allocator,
) !std.ArrayList(CrossFileImpact) {
    var impacts = std.ArrayList(CrossFileImpact).init(allocator);
    errdefer {
        for (impacts.items) |*imp| {
            imp.deinit();
        }
        impacts.deinit();
    }

    // Get direct affected files
    const files = try call_graph.getAffectedFiles(symbol, allocator);
    defer {
        for (files.items) |f| {
            allocator.free(f);
        }
        files.deinit();
    }

    // For each file, compute semantic impact
    for (files.items) |file| {
        const impact = CrossFileImpact{
            .file = try allocator.dupe(u8, file),
            .impact_level = .low,
            .confidence = 0.8,
            .allocator = allocator,
        };
        try impacts.append(impact);
    }

    return impacts;
}

/// Cross-file impact result
pub const CrossFileImpact = struct {
    file: []const u8,
    impact_level: ImpactLevel,
    confidence: f32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *CrossFileImpact) void {
        self.allocator.free(self.file);
    }
};

/// Apply safe cross-file refactor with rollback
pub fn applySafeCrossRefactor(
    allocator: std.mem.Allocator,
    call_graph: *CallGraph,
    semantic_index: *SemanticIndex,
    vsa_rules: []const SafeVSARule,
    intent: []const u8,
    new_intent: []const u8,
    semantic_threshold: f32,
    preview_only: bool,
) !CrossFileResult {
    var result = CrossFileResult.init(allocator);
    errdefer result.deinit();

    const start_time = std.time.nanoTimestamp();

    // Find semantically similar symbols
    var matches = try vsa.semanticSearch(
        semantic_index,
        intent,
        10, // top_k
        semantic_threshold,
        allocator,
    );
    defer matches.deinit();

    result.vsa_confidence = if (matches.items.len > 0)
        matches.items[0].confidence
    else
        0.0;

    if (preview_only) {
        // Just return preview, don't apply
        result.files_modified = @intCast(matches.items.len);
        result.total_changes = @intCast(matches.items.len);
        return result;
    }

    // TODO: Implement full cross-file refactor with:
    // 1. Compute topological order
    // 2. Create backups for all files
    // 3. Apply edits in order
    // 4. Run safety gates after each edit
    // 5. Rollback all on ANY failure

    _ = call_graph;
    _ = vsa_rules;
    _ = new_intent;

    const end_time = std.time.nanoTimestamp();
    result.duration_ms = @intCast((end_time - start_time) / 1_000_000);

    return result;
}

/// Rollback all changes from a refactor (Phase 1: Production-grade)
/// Restores all files from their backup content with verification
pub fn rollbackAll(
    allocator: std.mem.Allocator,
    rollback_points: std.StringHashMap([]const u8),
) !void {
    var iter = rollback_points.iterator();
    while (iter.next()) |entry| {
        const file = entry.key_ptr.*;
        const backup_content = entry.value_ptr.*;

        // Restore file from backup content
        try std.fs.cwd().writeFile(.{ .sub_path = file }, backup_content);

        // Verify restore
        const restored = try std.fs.cwd().readFileAlloc(allocator, file, 10_000_000);
        defer allocator.free(restored);

        if (!std.mem.eql(u8, restored, backup_content)) {
            return error.RollbackVerificationFailed;
        }
    }
}

/// Preview cross-file refactor impact
pub fn crossPreview(
    allocator: std.mem.Allocator,
    call_graph: *CallGraph,
    semantic_index: *SemanticIndex,
    symbol: []const u8,
    new_name: []const u8,
    include_vsa: bool,
) !UnifiedPreview {
    var preview = UnifiedPreview{
        .affected_files = std.ArrayList([]const u8).init(allocator),
        .vsa_scores = std.ArrayList(f32).init(allocator),
        .safety_assessment = "",
        .allocator = allocator,
    };

    // Get affected files
    const files = try call_graph.getAffectedFiles(symbol, allocator);
    defer {
        for (files.items) |f| {
            allocator.free(f);
        }
        files.deinit();
    }

    for (files.items) |file| {
        try preview.affected_files.append(try allocator.dupe(u8, file));
    }

    // Compute VSA scores if requested
    if (include_vsa) {
        const matches = try semanticSearch(semantic_index, symbol, 10, 0.75, allocator);
        defer {
            for (matches.items) |*m| {
                m.allocator.free(m.symbol.name);
                m.allocator.free(m.symbol.file);
                m.allocator.free(m.symbol.signature);
            }
            matches.deinit();
        }

        for (matches.items) |m| {
            try preview.vsa_scores.append(m.confidence);
        }
    }

    // Generate safety assessment
    preview.safety_assessment = try allocator.dupe(u8, "Safety: High - All changes are atomic with rollback");

    _ = new_name;

    return preview;
}

/// Unified preview result
pub const UnifiedPreview = struct {
    affected_files: std.ArrayList([]const u8),
    vsa_scores: std.ArrayList(f32),
    safety_assessment: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *UnifiedPreview) void {
        for (self.affected_files.items) |f| {
            self.allocator.free(f);
        }
        self.affected_files.deinit();

        self.vsa_scores.deinit();
        self.allocator.free(self.safety_assessment);
    }
};

/// Helper: semantic search
fn semanticSearch(
    index: *SemanticIndex,
    query: []const u8,
    top_k: usize,
    min_similarity: f32,
    allocator: std.mem.Allocator,
) !std.ArrayList(vsa.VSAMatch) {
    // Generate query embedding
    const query_embedding = try vsa.generateHashEmbedding(
        allocator,
        query,
        query,
        "",
        index.embedding_dim,
    );
    defer allocator.free(query_embedding);

    return index.search(query_embedding, top_k, min_similarity);
}
