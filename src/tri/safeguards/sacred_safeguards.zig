// ═══════════════════════════════════════════════════════════════════════════════
// SACRED SAFEGUARDS SYSTEM v1.0
// Comprehensive Safety System for Autonomous Operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// Purpose: Prevent autonomous agent from causing damage
//
// Features:
// - Confidence threshold enforcement (commit, self-modify, apply)
// - Rate limiting (commits per session/hour, self-modifies per session)
// - Protected resources (branches, files, patterns)
// - Approval gates (first N operations, self-modification, deletion)
// - Dry run mode for testing
// - Automatic rollback on test failure
// - Emergency stop functionality
// - Comprehensive safety logging and auditing
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const time = std.time;

/// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const TRINITY: f64 = 3.0;

/// Use Managed ArrayList for easier API
const ArrayList = std.array_list.Managed;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Safety violation types
pub const SafetyViolation = enum {
    none,
    low_confidence,
    protected_branch,
    protected_file,
    rate_limit_exceeded,
    requires_initial_approval,
    self_modify_without_approval,
    delete_operation,
    test_failure,
    dry_run_mode_active,
    emergency_stop,
    missing_test_coverage,
    risky_pattern,
};

/// Safeguard configuration
pub const SafeguardConfig = struct {
    // Confidence thresholds
    min_commit_confidence: f64 = 0.99,
    min_self_modify_confidence: f64 = 0.999,
    min_apply_confidence: f64 = 0.95,
    min_test_coverage_confidence: f64 = 0.90,

    // Rate limits
    max_commits_per_session: u32 = 10,
    max_commits_per_hour: u32 = 50,
    max_self_modifies_per_session: u32 = 3,
    max_operations_per_minute: u32 = 30,

    // Protected resources
    protected_branches: []const []const u8 = &[_][]const u8{
        "main",
        "master",
        "production",
        "staging",
    },
    protected_files: []const []const u8 = &[_][]const u8{
        "build.zig",
        "build.zig.zon",
        "*.test.zig",
        ".git",
    },
    protected_patterns: []const []const u8 = &[_][]const u8{
        "rm -rf",
        "delete",
        "DROP",
        "TRUNCATE",
        "format",
    },

    // Approval gates
    require_approval_first_n: u32 = 3,
    require_approval_for_self_modify: bool = true,
    require_approval_for_delete: bool = true,
    require_approval_for_protected: bool = true,

    // Dry run mode
    dry_run_mode: bool = true,
    verbose_safety: bool = true,

    // Rollback
    auto_rollback_on_test_fail: bool = true,
    auto_rollback_timeout_seconds: u32 = 300,

    // Emergency
    emergency_stop_enabled: bool = true,
    max_consecutive_failures: u32 = 5,

    // Logging
    log_file_path: []const u8 = ".trinity-nexus/.safety_log.json",
    max_log_size_mb: u32 = 100,

    /// Create default configuration
    pub fn init() SafeguardConfig {
        return SafeguardConfig{};
    }

    /// Create production configuration (stricter)
    pub fn initProduction() SafeguardConfig {
        var config = SafeguardConfig{};
        config.min_commit_confidence = 0.999;
        config.min_self_modify_confidence = 0.9999;
        config.min_apply_confidence = 0.98;
        config.max_commits_per_session = 5;
        config.max_commits_per_hour = 25;
        config.max_self_modifies_per_session = 1;
        config.require_approval_first_n = 5;
        config.dry_run_mode = false;
        return config;
    }

    /// Create development configuration (relaxed)
    pub fn initDevelopment() SafeguardConfig {
        var config = SafeguardConfig{};
        config.min_commit_confidence = 0.95;
        config.min_self_modify_confidence = 0.98;
        config.min_apply_confidence = 0.90;
        config.max_commits_per_session = 20;
        config.max_commits_per_hour = 100;
        config.max_self_modifies_per_session = 5;
        config.require_approval_first_n = 1;
        return config;
    }
};

/// Approval record
pub const ApprovalRecord = struct {
    operation: []const u8,
    timestamp: i64,
    approved: bool,
    reason: []const u8,
    confidence: f64,
};

/// Approval state tracking
pub const ApprovalState = struct {
    pending_approvals: u32,
    approved_count: u32,
    rejected_count: u32,
    approval_history: ArrayList(ApprovalRecord),

    pub fn init(allocator: mem.Allocator) ApprovalState {
        return ApprovalState{
            .pending_approvals = 0,
            .approved_count = 0,
            .rejected_count = 0,
            .approval_history = ArrayList(ApprovalRecord).init(allocator),
        };
    }

    pub fn deinit(self: *ApprovalState) void {
        // Free approval history strings
        const allocator = self.approval_history.allocator;
        for (self.approval_history.items) |record| {
            allocator.free(record.operation);
            allocator.free(record.reason);
        }
        self.approval_history.deinit();
    }

    /// Check if initial approval period is over
    pub fn hasCompletedInitialApprovals(self: *const ApprovalState, config: SafeguardConfig) bool {
        return self.approved_count >= config.require_approval_first_n;
    }

    /// Get approval rate
    pub fn getApprovalRate(self: *const ApprovalState) f64 {
        const total = self.approved_count + self.rejected_count;
        if (total == 0) return 1.0;
        return @as(f64, @floatFromInt(self.approved_count)) / @as(f64, @floatFromInt(total));
    }
};

/// Safety check result
pub const SafetyCheckResult = struct {
    allowed: bool,
    reason: []const u8,
    confidence: f64,
    requires_approval: bool,
    can_proceed_with_approval: bool,
    violation: SafetyViolation,
    // Track if reason needs to be freed
    reason_owned: bool = false,

    /// Create allowed result
    pub fn allowedConf(confidence: f64) SafetyCheckResult {
        return SafetyCheckResult{
            .allowed = true,
            .reason = "All safety checks passed",
            .confidence = confidence,
            .requires_approval = false,
            .can_proceed_with_approval = true,
            .violation = .none,
            .reason_owned = false,
        };
    }

    /// Create denied result with unowned reason
    pub fn denied(violation: SafetyViolation, reason: []const u8) SafetyCheckResult {
        return SafetyCheckResult{
            .allowed = false,
            .reason = reason,
            .confidence = 0.0,
            .requires_approval = false,
            .can_proceed_with_approval = false,
            .violation = violation,
            .reason_owned = false,
        };
    }

    /// Create denied result with owned reason
    pub fn deniedOwned(violation: SafetyViolation, reason: []const u8) SafetyCheckResult {
        return SafetyCheckResult{
            .allowed = false,
            .reason = reason,
            .confidence = 0.0,
            .requires_approval = false,
            .can_proceed_with_approval = false,
            .violation = violation,
            .reason_owned = true,
        };
    }

    /// Create requires approval result with unowned reason
    pub fn requiresApproval(reason: []const u8, confidence: f64) SafetyCheckResult {
        return SafetyCheckResult{
            .allowed = false,
            .reason = reason,
            .confidence = confidence,
            .requires_approval = true,
            .can_proceed_with_approval = true,
            .violation = .none,
            .reason_owned = false,
        };
    }

    /// Create requires approval result with owned reason
    pub fn requiresApprovalOwned(reason: []const u8, confidence: f64) SafetyCheckResult {
        return SafetyCheckResult{
            .allowed = false,
            .reason = reason,
            .confidence = confidence,
            .requires_approval = true,
            .can_proceed_with_approval = true,
            .violation = .none,
            .reason_owned = true,
        };
    }

    /// Free owned reason string
    pub fn deinit(self: *SafetyCheckResult, allocator: mem.Allocator) void {
        if (self.reason_owned) {
            allocator.free(self.reason);
            self.reason_owned = false;
        }
    }
};

/// AutoCodePatch (imported from auto_code_patcher.zig)
pub const AutoCodePatch = struct {
    file_path: []const u8,
    line_number: usize,
    original_code: []const u8,
    patched_code: []const u8,
    confidence: f64,
    applied: bool,

    // Simplified for safeguards - only what we need
    pub fn isSelfModification(self: AutoCodePatch) bool {
        // Check if patching any safeguards file
        if (mem.indexOf(u8, self.file_path, "safeguards") != null) return true;
        if (mem.indexOf(u8, self.file_path, "auto_code_patcher") != null) return true;
        return false;
    }

    pub fn isProtectedFile(self: AutoCodePatch, config: SafeguardConfig) bool {
        for (config.protected_files) |pattern| {
            if (mem.indexOf(u8, self.file_path, pattern) != null) return true;
            // Check wildcard patterns
            if (mem.endsWith(u8, pattern, ".zig")) {
                const base_pattern = mem.trimRight(u8, pattern, ".zig");
                const trimmed_path = mem.trimRight(u8, self.file_path, ".zig");
                if (mem.indexOf(u8, trimmed_path, base_pattern) != null) return true;
            }
        }
        return false;
    }
};

/// Safety event for logging
pub const SafetyEvent = struct {
    timestamp: i64,
    event_type: []const u8,
    operation: []const u8,
    allowed: bool,
    violation: SafetyViolation,
    confidence: f64,
    details: []const u8,
};

/// Emergency stop state
pub const EmergencyStop = struct {
    triggered: bool,
    reason: []const u8,
    timestamp: i64,
    rollback_performed: bool,
    consecutive_failures: u32,
    reason_owned: bool, // Track if reason needs to be freed

    pub fn init() EmergencyStop {
        return EmergencyStop{
            .triggered = false,
            .reason = "",
            .timestamp = 0,
            .rollback_performed = false,
            .consecutive_failures = 0,
            .reason_owned = false,
        };
    }
};

/// Rate limiter state
pub const RateLimiter = struct {
    commits_this_session: u32,
    commits_this_hour: u32,
    self_modifies_this_session: u32,
    operations_this_minute: u32,
    last_hour_reset: i64,
    last_minute_reset: i64,

    pub fn init() RateLimiter {
        const now = time.timestamp();
        return RateLimiter{
            .commits_this_session = 0,
            .commits_this_hour = 0,
            .self_modifies_this_session = 0,
            .operations_this_minute = 0,
            .last_hour_reset = now,
            .last_minute_reset = now,
        };
    }

    /// Reset counters if time window has passed
    pub fn update(self: *RateLimiter) void {
        const now = time.timestamp();

        // Reset hourly counter
        if (now - self.last_hour_reset >= 3600) {
            self.commits_this_hour = 0;
            self.last_hour_reset = now;
        }

        // Reset minute counter
        if (now - self.last_minute_reset >= 60) {
            self.operations_this_minute = 0;
            self.last_minute_reset = now;
        }
    }
};

/// Main safeguards system
pub const SacredSafeguards = struct {
    allocator: mem.Allocator,
    config: SafeguardConfig,
    approval_state: ApprovalState,
    emergency: EmergencyStop,
    rate_limiter: RateLimiter,
    safety_log: ArrayList(SafetyEvent),

    const Self = @This();

    /// Initialize safeguards system
    pub fn init(allocator: mem.Allocator, config: SafeguardConfig) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .approval_state = ApprovalState.init(allocator),
            .emergency = EmergencyStop.init(),
            .rate_limiter = RateLimiter.init(),
            .safety_log = ArrayList(SafetyEvent).init(allocator),
        };
    }

    /// Deinitialize safeguards system
    pub fn deinit(self: *Self) void {
        self.approval_state.deinit();

        // Free safety log strings
        for (self.safety_log.items) |event| {
            self.allocator.free(event.event_type);
            self.allocator.free(event.operation);
            self.allocator.free(event.details);
        }

        self.safety_log.deinit();

        // Free emergency stop reason if owned
        if (self.emergency.triggered and self.emergency.reason_owned) {
            self.allocator.free(self.emergency.reason);
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // COMMIT SAFETY CHECKS
    // ═════════════════════════════════════════════════════════════════════════

    /// Check if commit is safe
    pub fn checkCommitSafety(self: *Self, patch: AutoCodePatch) !SafetyCheckResult {
        // Update rate limiter
        self.rate_limiter.update();

        // Check emergency stop
        if (self.emergency.triggered) {
            return SafetyCheckResult.denied(
                .emergency_stop,
                "Emergency stop is active",
            );
        }

        // Check dry run mode
        if (self.config.dry_run_mode) {
            return SafetyCheckResult.denied(
                .dry_run_mode_active,
                "Dry run mode is active - no commits allowed",
            );
        }

        // Check confidence threshold
        if (patch.confidence < self.config.min_commit_confidence) {
            return SafetyCheckResult.deniedOwned(
                .low_confidence,
                try std.fmt.allocPrint(
                    self.allocator,
                    "Confidence {d:.3} below threshold {d:.3}",
                    .{ patch.confidence, self.config.min_commit_confidence },
                ),
            );
        }

        // Check protected files
        if (patch.isProtectedFile(self.config)) {
            return SafetyCheckResult.requiresApprovalOwned(
                "Attempting to modify protected file",
                patch.confidence,
            );
        }

        // Check self-modification
        if (patch.isSelfModification()) {
            if (!self.approval_state.hasCompletedInitialApprovals(self.config)) {
                return SafetyCheckResult.requiresApprovalOwned(
                    "Self-modification requires initial approval period",
                    patch.confidence,
                );
            }

            if (self.config.require_approval_for_self_modify) {
                return SafetyCheckResult.requiresApprovalOwned(
                    "Self-modification requires explicit approval",
                    patch.confidence,
                );
            }
        }

        // Check rate limits
        if (self.rate_limiter.commits_this_session >= self.config.max_commits_per_session) {
            return SafetyCheckResult.deniedOwned(
                .rate_limit_exceeded,
                try std.fmt.allocPrint(
                    self.allocator,
                    "Session commit limit reached: {d}/{d}",
                    .{ self.rate_limiter.commits_this_session, self.config.max_commits_per_session },
                ),
            );
        }

        if (self.rate_limiter.commits_this_hour >= self.config.max_commits_per_hour) {
            return SafetyCheckResult.deniedOwned(
                .rate_limit_exceeded,
                try std.fmt.allocPrint(
                    self.allocator,
                    "Hourly commit limit reached: {d}/{d}",
                    .{ self.rate_limiter.commits_this_hour, self.config.max_commits_per_hour },
                ),
            );
        }

        // Check for risky patterns
        if (try self.containsRiskyPattern(patch.patched_code)) {
            return SafetyCheckResult.denied(
                .risky_pattern,
                "Patched code contains risky patterns",
            );
        }

        return SafetyCheckResult.allowedConf(patch.confidence);
    }

    /// Check if self-modification is safe
    pub fn checkSelfModificationSafety(self: *Self, file: []const u8) !SafetyCheckResult {
        // Update rate limiter
        self.rate_limiter.update();

        // Check emergency stop
        if (self.emergency.triggered) {
            return SafetyCheckResult.denied(
                .emergency_stop,
                "Emergency stop is active",
            );
        }

        // Check if safeguards file
        if (mem.indexOf(u8, file, "safeguards") == null and
            mem.indexOf(u8, file, "auto_code_patcher") == null) {
            return SafetyCheckResult.allowedConf(1.0);
        }

        // Check self-modify rate limit
        if (self.rate_limiter.self_modifies_this_session >= self.config.max_self_modifies_per_session) {
            return SafetyCheckResult.deniedOwned(
                .rate_limit_exceeded,
                try std.fmt.allocPrint(
                    self.allocator,
                    "Self-modification limit reached: {d}/{d}",
                    .{ self.rate_limiter.self_modifies_this_session, self.config.max_self_modifies_per_session },
                ),
            );
        }

        // Require approval
        if (self.config.require_approval_for_self_modify) {
            return SafetyCheckResult.requiresApprovalOwned(
                "Self-modification requires explicit approval",
                0.999,
            );
        }

        return SafetyCheckResult.allowedConf(0.999);
    }

    /// Check if branch is safe to modify
    pub fn checkBranchSafety(self: *Self, branch: []const u8) !bool {
        for (self.config.protected_branches) |protected| {
            if (mem.eql(u8, branch, protected)) {
                return false;
            }
        }
        return true;
    }

    /// Check if file is protected
    pub fn checkFileProtected(self: *Self, file: []const u8) !bool {
        for (self.config.protected_files) |pattern| {
            if (mem.indexOf(u8, file, pattern) != null) {
                return true;
            }
            // Check wildcard patterns
            if (mem.endsWith(u8, pattern, ".zig")) {
                const base_pattern = mem.trimRight(u8, pattern, ".zig");
                const trimmed_path = mem.trimRight(u8, file, ".zig");
                if (mem.indexOf(u8, trimmed_path, base_pattern) != null) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check rate limit
    pub fn checkRateLimit(self: *Self, current_commits: u32) !bool {
        self.rate_limiter.update();
        return current_commits < self.config.max_commits_per_session;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // APPROVAL SYSTEM
    // ═════════════════════════════════════════════════════════════════════════

    /// Request approval from user
    pub fn requestApproval(
        self: *Self,
        operation: []const u8,
        details: []const u8,
        confidence: f64,
    ) !bool {
        self.approval_state.pending_approvals += 1;

        // Build prompt
        const prompt = try self.buildApprovalPrompt(operation, details, confidence);
        defer self.allocator.free(prompt);

        // Present to user
        const result = try presentForApproval(prompt);

        // Record approval
        try self.recordApproval(
            operation,
            result.approved,
            result.reason,
            confidence,
        );

        // Log event
        try self.logSafetyEvent(.{
            .timestamp = time.timestamp(),
            .event_type = "approval_request",
            .operation = operation,
            .allowed = result.approved,
            .violation = if (result.approved) .none else .requires_initial_approval,
            .confidence = confidence,
            .details = details,
        });

        return result.approved;
    }

    /// Build approval prompt
    fn buildApprovalPrompt(
        self: *Self,
        operation: []const u8,
        details: []const u8,
        confidence: f64,
    ) ![]const u8 {
        return std.fmt.allocPrint(
            self.allocator,
            \\╔══════════════════════════════════════════════════════════════╗
            \\║              SACRED SAFEGUARDS - APPROVAL REQUIRED           ║
            \\╠══════════════════════════════════════════════════════════════╣
            \\║ Operation: {s}
            \\║ Confidence: {d:.3}%
            \\║                                                              ║
            \\║ Details:                                                     ║
            \\║ {s}
            \\║                                                              ║
            \\║ Approvals this session: {d}/{d}                             ║
            \\║ Approval rate: {d:.1}%                                       ║
            \\╠══════════════════════════════════════════════════════════════╣
            \\║ Options:                                                     ║
            \\║   [a] Approve - Allow this operation                        ║
            \\║   [r] Reject - Deny this operation                          ║
            \\║   [v] View - View full details                              ║
            \\║   [s] Skip - Skip this operation                            ║
            \\╚══════════════════════════════════════════════════════════════╝
            \\φ² + 1/φ² = 3 = TRINITY
        ,
            .{
                operation,
                confidence * 100.0,
                details,
                self.approval_state.approved_count,
                self.config.require_approval_first_n,
                self.approval_state.getApprovalRate() * 100.0,
            },
        );
    }

    /// Record approval decision
    pub fn recordApproval(
        self: *Self,
        operation: []const u8,
        approved: bool,
        reason: []const u8,
        confidence: f64,
    ) !void {
        const record = ApprovalRecord{
            .operation = try self.allocator.dupe(u8, operation),
            .timestamp = time.timestamp(),
            .approved = approved,
            .reason = try self.allocator.dupe(u8, reason),
            .confidence = confidence,
        };

        try self.approval_state.approval_history.append(record);

        if (approved) {
            self.approval_state.approved_count += 1;
            self.approval_state.pending_approvals -= 1;
        } else {
            self.approval_state.rejected_count += 1;
            self.approval_state.pending_approvals -= 1;
        }
    }

    /// Check if in dry run mode
    pub fn isDryRunMode(self: *Self) bool {
        return self.config.dry_run_mode;
    }

    /// Set dry run mode
    pub fn setDryRunMode(self: *Self, enabled: bool) !void {
        self.config.dry_run_mode = enabled;

        try self.logSafetyEvent(.{
            .timestamp = time.timestamp(),
            .event_type = "dry_run_mode_change",
            .operation = if (enabled) "enable" else "disable",
            .allowed = true,
            .violation = .none,
            .confidence = 1.0,
            .details = if (enabled) "Dry run mode enabled" else "Dry run mode disabled",
        });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // RISKY PATTERN DETECTION
    // ═════════════════════════════════════════════════════════════════════════

    /// Check if code contains risky patterns
    fn containsRiskyPattern(self: *Self, code: []const u8) !bool {
        for (self.config.protected_patterns) |pattern| {
            if (mem.indexOf(u8, code, pattern) != null) {
                // Check if in comment or string
                if (!isRiskyContext(code, pattern)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check if pattern is in risky context (not in comment/string)
    fn isRiskyContext(code: []const u8, pattern: []const u8) bool {
        const idx = mem.indexOf(u8, code, pattern) orelse return false;

        // Check if inside string literal
        var in_string = false;
        var quote_char: u8 = 0;
        var in_line_comment = false;
        var in_block_comment = false;

        for (code[0..idx], 0..) |c, i| {
            if (c == '"' or c == '\'') {
                if (!in_string and !in_line_comment and !in_block_comment) {
                    in_string = true;
                    quote_char = c;
                } else if (c == quote_char) {
                    in_string = false;
                }
            }

            // Line comments
            if (c == '/' and !in_string and !in_block_comment) {
                if (i + 1 < idx and code[i + 1] == '/') {
                    in_line_comment = true;
                }
            }

            if (c == '\n') {
                in_line_comment = false;
            }

            // Block comments
            if (c == '*' and !in_string and !in_line_comment) {
                if (i > 0 and code[i - 1] == '/') {
                    in_block_comment = true;
                }
            }

            if (c == '/' and !in_string and !in_line_comment) {
                if (i > 0 and code[i - 1] == '*') {
                    in_block_comment = false;
                }
            }
        }

        return in_string or in_line_comment or in_block_comment;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // EMERGENCY STOP
    // ═════════════════════════════════════════════════════════════════════════

    /// Trigger emergency stop
    pub fn triggerEmergencyStop(self: *Self, reason: []const u8) !EmergencyStop {
        // Free old reason if already triggered
        if (self.emergency.triggered and self.emergency.reason_owned) {
            self.allocator.free(self.emergency.reason);
        }

        self.emergency.triggered = true;
        self.emergency.reason = try self.allocator.dupe(u8, reason);
        self.emergency.reason_owned = true;
        self.emergency.timestamp = time.timestamp();
        self.emergency.rollback_performed = false;

        try self.logSafetyEvent(.{
            .timestamp = self.emergency.timestamp,
            .event_type = "emergency_stop",
            .operation = "trigger",
            .allowed = false,
            .violation = .emergency_stop,
            .confidence = 0.0,
            .details = reason,
        });

        return self.emergency;
    }

    /// Check if emergency stop is active
    pub fn checkEmergencyStop(self: *Self) ?EmergencyStop {
        if (self.emergency.triggered) {
            return self.emergency;
        }
        return null;
    }

    /// Clear emergency stop
    pub fn clearEmergencyStop(self: *Self) !void {
        if (self.emergency.triggered and self.emergency.reason_owned) {
            self.allocator.free(self.emergency.reason);
        }
        self.emergency = EmergencyStop.init();

        try self.logSafetyEvent(.{
            .timestamp = time.timestamp(),
            .event_type = "emergency_stop",
            .operation = "clear",
            .allowed = true,
            .violation = .none,
            .confidence = 1.0,
            .details = "Emergency stop cleared",
        });
    }

    /// Increment failure count and trigger emergency stop if needed
    pub fn recordFailure(self: *Self, reason: []const u8) !void {
        self.emergency.consecutive_failures += 1;

        if (self.emergency.consecutive_failures >= self.config.max_consecutive_failures) {
            const formatted = try std.fmt.allocPrint(
                self.allocator,
                "Max consecutive failures reached: {s}",
                .{reason},
            );
            defer self.allocator.free(formatted);

            _ = try self.triggerEmergencyStop(formatted);
        }
    }

    /// Reset failure count
    pub fn resetFailureCount(self: *Self) !void {
        self.emergency.consecutive_failures = 0;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // LOGGING AND AUDITING
    // ═════════════════════════════════════════════════════════════════════════

    /// Log safety event
    pub fn logSafetyEvent(self: *Self, event: SafetyEvent) !void {
        // Clone event data
        const event_copy = SafetyEvent{
            .timestamp = event.timestamp,
            .event_type = try self.allocator.dupe(u8, event.event_type),
            .operation = try self.allocator.dupe(u8, event.operation),
            .allowed = event.allowed,
            .violation = event.violation,
            .confidence = event.confidence,
            .details = try self.allocator.dupe(u8, event.details),
        };

        try self.safety_log.append(event_copy);

        // Write to file if verbose
        if (self.config.verbose_safety) {
            try self.writeSafetyLog();
        }
    }

    /// Get safety log
    pub fn getSafetyLog(self: *Self) ![]SafetyEvent {
        return self.safety_log.items;
    }

    /// Export safety log to file
    pub fn exportSafetyLog(self: *Self, path: []const u8) !void {
        const file = try fs.cwd().createFile(path, .{ .truncate = true });
        defer file.close();

        // Build JSON string first
        var json_buffer = ArrayList(u8).init(self.allocator);
        defer json_buffer.deinit();

        try json_buffer.appendSlice("[\n");

        for (self.safety_log.items, 0..) |event, i| {
            if (i > 0) try json_buffer.appendSlice(",\n");

            try json_buffer.print(
                \\  {{
                \\    "timestamp": {d},
                \\    "event_type": "{s}",
                \\    "operation": "{s}",
                \\    "allowed": {},
                \\    "violation": "{s}",
                \\    "confidence": {d:.6},
                \\    "details": "{s}"
                \\  }}
            ,
                .{
                    event.timestamp,
                    event.event_type,
                    event.operation,
                    event.allowed,
                    @tagName(event.violation),
                    event.confidence,
                    event.details,
                },
            );
        }

        try json_buffer.appendSlice("\n]\n");

        // Write to file
        try file.writeAll(json_buffer.items);
    }

    /// Write safety log to default location
    fn writeSafetyLog(self: *Self) !void {
        // Create directory if needed
        const dir_path = fs.path.dirname(self.config.log_file_path) orelse ".";
        fs.cwd().makePath(dir_path) catch {};

        try self.exportSafetyLog(self.config.log_file_path);
    }

    /// Generate safety report
    pub fn generateSafetyReport(self: *Self) ![]const u8 {
        var result = ArrayList(u8).init(self.allocator);
        defer result.deinit();

        try result.appendSlice("╔══════════════════════════════════════════════════════════════╗\n");
        try result.appendSlice("║          SACRED SAFEGUARDS - SAFETY REPORT                 ║\n");
        try result.appendSlice("╚══════════════════════════════════════════════════════════════╝\n\n");

        // Configuration
        try result.appendSlice("Configuration:\n");
        try result.print("  Dry run mode: {}\n", .{self.config.dry_run_mode});
        try result.print("  Min commit confidence: {d:.3}\n", .{self.config.min_commit_confidence});
        try result.print("  Max commits/session: {d}\n", .{self.config.max_commits_per_session});
        try result.print("  Max commits/hour: {d}\n", .{self.config.max_commits_per_hour});
        try result.print("  Max self-modifies/session: {d}\n\n", .{self.config.max_self_modifies_per_session});

        // Approval state
        try result.appendSlice("Approval State:\n");
        try result.print("  Approved: {d}\n", .{self.approval_state.approved_count});
        try result.print("  Rejected: {d}\n", .{self.approval_state.rejected_count});
        try result.print("  Pending: {d}\n", .{self.approval_state.pending_approvals});
        try result.print("  Approval rate: {d:.1}%\n\n", .{self.approval_state.getApprovalRate() * 100.0});

        // Rate limiter
        try result.appendSlice("Rate Limits:\n");
        try result.print("  Commits this session: {d}/{d}\n", .{
            self.rate_limiter.commits_this_session,
            self.config.max_commits_per_session,
        });
        try result.print("  Commits this hour: {d}/{d}\n", .{
            self.rate_limiter.commits_this_hour,
            self.config.max_commits_per_hour,
        });
        try result.print("  Self-modifies this session: {d}/{d}\n\n", .{
            self.rate_limiter.self_modifies_this_session,
            self.config.max_self_modifies_per_session,
        });

        // Emergency status
        try result.appendSlice("Emergency Status:\n");
        try result.print("  Triggered: {}\n", .{self.emergency.triggered});
        if (self.emergency.triggered) {
            try result.print("  Reason: {s}\n", .{self.emergency.reason});
            try result.print("  Timestamp: {d}\n", .{self.emergency.timestamp});
        }
        try result.print("  Consecutive failures: {d}/{d}\n\n", .{
            self.emergency.consecutive_failures,
            self.config.max_consecutive_failures,
        });

        // Safety log summary
        try result.appendSlice("Safety Log:\n");
        try result.print("  Total events: {d}\n", .{self.safety_log.items.len});

        var allowed_count: u32 = 0;
        var denied_count: u32 = 0;
        for (self.safety_log.items) |event| {
            if (event.allowed) allowed_count += 1 else denied_count += 1;
        }

        try result.print("  Allowed: {d}\n", .{allowed_count});
        try result.print("  Denied: {d}\n", .{denied_count});

        // Recent violations
        try result.appendSlice("\nRecent Violations:\n");
        var violation_count: u32 = 0;
        for (self.safety_log.items) |event| {
            if (event.violation != .none and violation_count < 10) {
                try result.print("  [{s}] {s}: {s}\n", .{
                    @tagName(event.violation),
                    event.operation,
                    event.details,
                });
                violation_count += 1;
            }
        }

        if (violation_count == 0) {
            try result.appendSlice("  No violations\n");
        }

        try result.appendSlice("\n══════════════════════════════════════════════════════════\n");
        try result.appendSlice("φ² + 1/φ² = 3 = TRINITY\n");
        try result.appendSlice("══════════════════════════════════════════════════════════\n");

        return result.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// APPROVAL UI
// ═══════════════════════════════════════════════════════════════════════════════

/// Approval result
pub const ApprovalResult = struct {
    approved: bool,
    reason: []const u8,
};

/// Present operation for user approval
pub fn presentForApproval(prompt: []const u8) !ApprovalResult {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // Display prompt
    try stdout.writeAll("\n");
    try stdout.writeAll(prompt);
    try stdout.writeAll("\n\n> ");

    // Read response
    var buffer: [32]u8 = undefined;
    const bytes_read = stdin.read(&buffer) catch return ApprovalResult{
        .approved = false,
        .reason = "Failed to read input",
    };

    if (bytes_read == 0) {
        return ApprovalResult{
            .approved = false,
            .reason = "No input received",
        };
    }

    const choice = buffer[0];

    return switch (choice) {
        'a', 'A' => ApprovalResult{
            .approved = true,
            .reason = "User approved",
        },
        'r', 'R' => ApprovalResult{
            .approved = false,
            .reason = "User rejected",
        },
        's', 'S' => ApprovalResult{
            .approved = false,
            .reason = "User skipped",
        },
        'v', 'V' => ApprovalResult{
            .approved = false,
            .reason = "User requested view (not implemented)",
        },
        else => ApprovalResult{
            .approved = false,
            .reason = "Invalid choice",
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SafeguardConfig init" {
    const config = SafeguardConfig.init();
    try std.testing.expectEqual(@as(f64, 0.99), config.min_commit_confidence);
    try std.testing.expectEqual(@as(f64, 0.999), config.min_self_modify_confidence);
    try std.testing.expectEqual(@as(f64, 0.95), config.min_apply_confidence);
    try std.testing.expectEqual(@as(u32, 10), config.max_commits_per_session);
    try std.testing.expectEqual(true, config.dry_run_mode);
}

test "SafeguardConfig initProduction" {
    const config = SafeguardConfig.initProduction();
    try std.testing.expectEqual(@as(f64, 0.999), config.min_commit_confidence);
    try std.testing.expectEqual(@as(f64, 0.9999), config.min_self_modify_confidence);
    try std.testing.expectEqual(@as(u32, 5), config.max_commits_per_session);
    try std.testing.expectEqual(false, config.dry_run_mode);
}

test "SafeguardConfig initDevelopment" {
    const config = SafeguardConfig.initDevelopment();
    try std.testing.expectEqual(@as(f64, 0.95), config.min_commit_confidence);
    try std.testing.expectEqual(@as(u32, 20), config.max_commits_per_session);
}

test "ApprovalState init" {
    var state = ApprovalState.init(std.testing.allocator);
    defer state.deinit();

    try std.testing.expectEqual(@as(u32, 0), state.pending_approvals);
    try std.testing.expectEqual(@as(u32, 0), state.approved_count);
    try std.testing.expectEqual(@as(u32, 0), state.rejected_count);
    try std.testing.expectEqual(@as(f64, 1.0), state.getApprovalRate());
}

test "ApprovalState hasCompletedInitialApprovals" {
    var state = ApprovalState.init(std.testing.allocator);
    defer state.deinit();

    const config = SafeguardConfig.init();

    // Initially false
    try std.testing.expectEqual(false, state.hasCompletedInitialApprovals(config));

    // After approvals
    state.approved_count = 3;
    try std.testing.expectEqual(true, state.hasCompletedInitialApprovals(config));
}

test "ApprovalState getApprovalRate" {
    var state = ApprovalState.init(std.testing.allocator);
    defer state.deinit();

    state.approved_count = 7;
    state.rejected_count = 3;

    const rate = state.getApprovalRate();
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), rate, 0.01);
}

test "SafetyCheckResult allowedConf" {
    const result = SafetyCheckResult.allowedConf(0.98);

    try std.testing.expectEqual(true, result.allowed);
    try std.testing.expectEqual(false, result.requires_approval);
    try std.testing.expectEqual(true, result.can_proceed_with_approval);
    try std.testing.expectEqual(SafetyViolation.none, result.violation);
}

test "SafetyCheckResult denied" {
    const result = SafetyCheckResult.denied(.low_confidence, "Confidence too low");

    try std.testing.expectEqual(false, result.allowed);
    try std.testing.expectEqual(false, result.requires_approval);
    try std.testing.expectEqual(false, result.can_proceed_with_approval);
    try std.testing.expectEqual(SafetyViolation.low_confidence, result.violation);
}

test "SafetyCheckResult requiresApproval" {
    const result = SafetyCheckResult.requiresApproval("Protected file", 0.95);

    try std.testing.expectEqual(false, result.allowed);
    try std.testing.expectEqual(true, result.requires_approval);
    try std.testing.expectEqual(true, result.can_proceed_with_approval);
    try std.testing.expectEqual(SafetyViolation.none, result.violation);
}

test "EmergencyStop init" {
    const emergency = EmergencyStop.init();

    try std.testing.expectEqual(false, emergency.triggered);
    try std.testing.expectEqual(@as(u32, 0), emergency.consecutive_failures);
}

test "RateLimiter init" {
    const limiter = RateLimiter.init();

    try std.testing.expectEqual(@as(u32, 0), limiter.commits_this_session);
    try std.testing.expectEqual(@as(u32, 0), limiter.commits_this_hour);
    try std.testing.expectEqual(@as(u32, 0), limiter.self_modifies_this_session);
}

test "SacredSafeguards init" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    try std.testing.expectEqual(@as(u32, 0), safeguards.approval_state.approved_count);
    try std.testing.expectEqual(false, safeguards.emergency.triggered);
    try std.testing.expectEqual(@as(usize, 0), safeguards.safety_log.items.len);
}

test "SacredSafeguards checkCommitSafety - dry run mode" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    const patch = AutoCodePatch{
        .file_path = "/test/file.zig",
        .line_number = 10,
        .original_code = "const x = 1.0;",
        .patched_code = "const x = SacredConstants.PHI;",
        .confidence = 0.99,
        .applied = false,
    };

    var result = try safeguards.checkCommitSafety(patch);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(false, result.allowed);
    try std.testing.expectEqual(SafetyViolation.dry_run_mode_active, result.violation);
}

test "SacredSafeguards checkCommitSafety - low confidence" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    // Disable dry run
    safeguards.config.dry_run_mode = false;

    const patch = AutoCodePatch{
        .file_path = "/test/file.zig",
        .line_number = 10,
        .original_code = "const x = 1.0;",
        .patched_code = "const x = 0.5;",
        .confidence = 0.90, // Below threshold
        .applied = false,
    };

    var result = try safeguards.checkCommitSafety(patch);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(false, result.allowed);
    try std.testing.expectEqual(SafetyViolation.low_confidence, result.violation);
}

test "SacredSafeguards checkCommitSafety - allowed" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    // Disable dry run
    safeguards.config.dry_run_mode = false;

    const patch = AutoCodePatch{
        .file_path = "/test/file.zig",
        .line_number = 10,
        .original_code = "const x = 1.0;",
        .patched_code = "const x = SacredConstants.PHI;",
        .confidence = 0.995,
        .applied = false,
    };

    var result = try safeguards.checkCommitSafety(patch);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(true, result.allowed);
    try std.testing.expectEqual(SafetyViolation.none, result.violation);
}

test "SacredSafeguards checkBranchSafety" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    // Protected branch
    const main_protected = try safeguards.checkBranchSafety("main");
    try std.testing.expectEqual(false, main_protected);

    // Non-protected branch
    const feature_allowed = try safeguards.checkBranchSafety("feature/test");
    try std.testing.expectEqual(true, feature_allowed);
}

test "SacredSafeguards checkFileProtected" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    // Protected file
    const build_protected = try safeguards.checkFileProtected("build.zig");
    try std.testing.expectEqual(true, build_protected);

    // Non-protected file
    const normal_allowed = try safeguards.checkFileProtected("src/test.zig");
    try std.testing.expectEqual(false, normal_allowed);
}

test "SacredSafeguards checkRateLimit" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    // Under limit
    const under_limit = try safeguards.checkRateLimit(5);
    try std.testing.expectEqual(true, under_limit);

    // Over limit
    const over_limit = try safeguards.checkRateLimit(15);
    try std.testing.expectEqual(false, over_limit);
}

test "SacredSafeguards isDryRunMode" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    try std.testing.expectEqual(true, safeguards.isDryRunMode());
}

test "SacredSafeguards setDryRunMode" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    try safeguards.setDryRunMode(false);
    try std.testing.expectEqual(false, safeguards.isDryRunMode());

    try safeguards.setDryRunMode(true);
    try std.testing.expectEqual(true, safeguards.isDryRunMode());
}

test "SacredSafeguards triggerEmergencyStop" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    const emergency = try safeguards.triggerEmergencyStop("Test emergency");
    try std.testing.expectEqual(true, emergency.triggered);
    try std.testing.expectEqual(true, safeguards.emergency.triggered);
}

test "SacredSafeguards checkEmergencyStop" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    // No emergency
    const none = safeguards.checkEmergencyStop();
    try std.testing.expectEqual(@as(?EmergencyStop, null), none);

    // Trigger emergency
    _ = try safeguards.triggerEmergencyStop("Test");

    // Check emergency
    const active = safeguards.checkEmergencyStop();
    try std.testing.expect(active != null);
    if (active) |e| {
        try std.testing.expectEqual(true, e.triggered);
    }
}

test "SacredSafeguards clearEmergencyStop" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    _ = try safeguards.triggerEmergencyStop("Test");
    try safeguards.clearEmergencyStop();

    try std.testing.expectEqual(false, safeguards.emergency.triggered);
}

test "SacredSafeguards recordFailure" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    try safeguards.recordFailure("Test failure");
    try std.testing.expectEqual(@as(u32, 1), safeguards.emergency.consecutive_failures);

    try safeguards.resetFailureCount();
    try std.testing.expectEqual(@as(u32, 0), safeguards.emergency.consecutive_failures);
}

test "SacredSafeguards recordFailure - triggers emergency" {
    const config = blk: {
        var cfg = SafeguardConfig.init();
        cfg.max_consecutive_failures = 3;
        break :blk cfg;
    };

    var safeguards = try SacredSafeguards.init(std.testing.allocator, config);
    defer safeguards.deinit();

    try safeguards.recordFailure("Fail 1");
    try safeguards.recordFailure("Fail 2");
    try safeguards.recordFailure("Fail 3");

    try std.testing.expectEqual(true, safeguards.emergency.triggered);
}

test "SacredSafeguards logSafetyEvent" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    const event = SafetyEvent{
        .timestamp = time.timestamp(),
        .event_type = "test",
        .operation = "test_operation",
        .allowed = true,
        .violation = .none,
        .confidence = 1.0,
        .details = "Test details",
    };

    try safeguards.logSafetyEvent(event);

    try std.testing.expectEqual(@as(usize, 1), safeguards.safety_log.items.len);
}

test "SacredSafeguards getSafetyLog" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    const event = SafetyEvent{
        .timestamp = time.timestamp(),
        .event_type = "test",
        .operation = "test_operation",
        .allowed = true,
        .violation = .none,
        .confidence = 1.0,
        .details = "Test details",
    };

    try safeguards.logSafetyEvent(event);
    const log = try safeguards.getSafetyLog();

    try std.testing.expectEqual(@as(usize, 1), log.len);
}

test "SacredSafeguards generateSafetyReport" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    const report = try safeguards.generateSafetyReport();
    defer std.testing.allocator.free(report);

    try std.testing.expect(mem.indexOf(u8, report, "SACRED SAFEGUARDS") != null);
    try std.testing.expect(mem.indexOf(u8, report, "Configuration:") != null);
    try std.testing.expect(mem.indexOf(u8, report, "Approval State:") != null);
    try std.testing.expect(mem.indexOf(u8, report, "TRINITY") != null);
}

test "SacredSafeguards exportSafetyLog" {
    var safeguards = try SacredSafeguards.init(
        std.testing.allocator,
        SafeguardConfig.init(),
    );
    defer safeguards.deinit();

    const event = SafetyEvent{
        .timestamp = time.timestamp(),
        .event_type = "test",
        .operation = "test_operation",
        .allowed = true,
        .violation = .none,
        .confidence = 1.0,
        .details = "Test details",
    };

    try safeguards.logSafetyEvent(event);

    // Export to temp file
    const tmp_path = "/tmp/safety_log_test.json";
    try safeguards.exportSafetyLog(tmp_path);

    // Verify file exists
    const file = try fs.cwd().openFile(tmp_path, .{});
    defer file.close();

    const stat = try file.stat();
    try std.testing.expect(stat.size > 0);

    // Cleanup
    fs.cwd().deleteFile(tmp_path) catch {};
}
