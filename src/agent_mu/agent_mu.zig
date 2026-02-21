//! AGENT MU — Post-Generation Guard & Auto-Fixer
//! μ = 1/φ²/10 = 0.0382 — sacred mutation that transforms errors into advantages
//!
//! Runs after every TRI GEN to verify generated code quality.
//! If generation fails → automatically fixes generator and retries.
//! Every failure becomes SUCCESS_HISTORY entry.
//!
//! Phase 2-4: Pattern matching, auto-fixing, and logging.

const std = @import("std");

// Import submodules
const verifier = @import("verifier.zig");
const diagnostic = @import("diagnostic.zig");
const pattern_matcher = @import("pattern_matcher.zig");
const fixer = @import("fixer.zig");
const logger = @import("logger.zig");

pub const std_lib = std;

/// Configuration for AGENT MU verification and fixing
pub const Config = struct {
    /// Maximum number of fix attempts before giving up
    max_retries: u32 = 3,
    /// Timeout for each verification step (seconds)
    timeout_seconds: u32 = 120,
    /// Enable verbose logging
    verbose: bool = false,
    /// Enable auto-fixing (set to false for verification-only mode)
    enable_auto_fix: bool = true,
};

/// Result of verification and fix attempt
pub const Result = struct {
    success: bool,
    attempts_made: u32,
    error_message: []const u8,
    fix_applied: bool,
};

/// Verify and fix generated code
///
/// Phase 2-4: Full self-evolution loop
/// - V01: Verification (build + test + format)
/// - Phi02: Pattern Search (REGRESSION_PATTERNS.md)
/// - Pi03: Diagnostic (FixType classification)
/// - Mu05: Auto-Fix (apply correction)
/// - Sigma07: Success (log to SUCCESS_HISTORY.md)
/// - Chi06: Regress (log to REGRESSION_PATTERNS.md)
///
/// Parameters:
///   - allocator: Memory allocator for all operations
///   - generated_file: Path to the generated .zig file
///   - config: Configuration options
///
/// Returns: Result struct with success status and details
pub fn verifyAndFix(
    allocator: std.mem.Allocator,
    generated_file: []const u8,
    config: Config,
) !Result {
    var attempt: u32 = 0;
    var fix_applied = false;
    var last_error: diagnostic.ErrorInfo = undefined;

    while (attempt < config.max_retries) : (attempt += 1) {
        // V01: Verification
        const verify_result = try verifier.verify(allocator, generated_file);

        if (verify_result.success) {
            // Sigma07: Log success
            if (config.verbose) {
                std.log.info("AGENT MU: All checks passed on attempt {d}", .{attempt});
            }

            if (fix_applied) {
                const success_err = diagnostic.ErrorInfo{
                    .fix_type = .UNKNOWN,
                    .message = "",
                    .file = generated_file,
                    .line = 0,
                    .column = 0,
                    .code = "success",
                };
                try logger.logSuccess(
                    allocator,
                    &success_err,
                    "All checks passed after auto-fix",
                    @constCast(&[_][]const u8{generated_file}),
                );
            }

            return Result{
                .success = true,
                .attempts_made = attempt,
                .error_message = "",
                .fix_applied = fix_applied,
            };
        }

        // Pi03: Parse error
        const err_info = diagnostic.parse(allocator, verify_result.stderr) catch |e| {
            if (config.verbose) {
                std.log.warn("AGENT MU: Failed to parse error: {}", .{e});
            }
            // Continue with generic error info
            last_error = diagnostic.ErrorInfo{
                .fix_type = .UNKNOWN,
                .message = verify_result.stderr,
                .file = generated_file,
                .line = 0,
                .column = 0,
                .code = "unknown",
            };
            continue;
        };

        last_error = err_info;

        if (config.verbose) {
            std.log.info("AGENT MU: Error detected: {s}", .{err_info.message});
            std.log.info("AGENT MU: FixType: {}", .{err_info.fix_type});
            std.log.info("AGENT MU: Location: {s}:{}:{}", .{ err_info.file, err_info.line, err_info.column });
        }

        // Phi02: Search patterns
        const pattern = pattern_matcher.searchRegressionPatterns(
            allocator,
            err_info.fix_type,
            err_info.message,
        ) catch |e| blk: {
            if (config.verbose) {
                std.log.warn("AGENT MU: Pattern search failed: {}", .{e});
            }
            break :blk null;
        };

        if (pattern) |*p| {
            if (config.verbose) {
                std.log.info("AGENT MU: Found pattern match", .{});
            }
            p.deinit(allocator);
        }

        // Mu05: Attempt fix
        if (!config.enable_auto_fix) {
            // Verification-only mode - return failure
            return Result{
                .success = false,
                .attempts_made = attempt + 1,
                .error_message = err_info.message,
                .fix_applied = false,
            };
        }

        const fix_result = fixer.applyFix(allocator, &err_info, generated_file) catch |e| blk: {
            if (config.verbose) {
                std.log.warn("AGENT MU: Fix attempt failed: {}", .{e});
            }
            break :blk fixer.FixResult{
                .success = false,
                .description = "Fix execution failed",
                .files_modified = &[_][]const u8{},
            };
        };

        if (fix_result.success) {
            if (config.verbose) {
                std.log.info("AGENT MU: Fix applied: {s}", .{fix_result.description});
            }
            fix_applied = true;
            continue; // Retry verification
        }

        if (config.verbose) {
            std.log.warn("AGENT MU: Fix failed: {s}", .{fix_result.description});
        }

        // If fix failed and we have more retries, try again
        // Otherwise break to log regression
        if (attempt + 1 >= config.max_retries) {
            break;
        }
    }

    // Chi06: Log regression
    if (!fix_applied and attempt > 0) {
        try logger.logRegression(allocator, &last_error, @constCast(&[_][]const u8{"Auto-fix attempted"}));
    }

    return Result{
        .success = false,
        .attempts_made = attempt,
        .error_message = last_error.message,
        .fix_applied = fix_applied,
    };
}

/// Quick verification check (no fixing, single attempt)
///
/// Use this when you only want to verify code quality without auto-fixing.
pub fn verifyOnly(allocator: std.mem.Allocator, generated_file: []const u8) !bool {
    const result = try verifier.verify(allocator, generated_file);
    return result.success;
}

test "AGENT MU: verifyAndFix - successful verification" {
    const allocator = std.testing.allocator;

    // This test requires a valid .zig file to verify
    // For now, we just test the function signature
    const config = Config{};
    _ = allocator;
    _ = config;
    // TODO: Add actual test with mock generated file
}

test "AGENT MU: verifyOnly" {
    const allocator = std.testing.allocator;
    _ = allocator;
    // TODO: Add actual test
}
