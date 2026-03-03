// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE — Structural Editor Core Module Exports
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

// Core types and configuration
pub const needle = @import("needle.zig");

// Fuzzy text matcher (Tier 0 fallback)
pub const fuzzy = @import("fuzzy.zig");

// Unified matcher with tier-based fallback
pub const matcher = @import("matcher.zig");

// Structural edit operations
pub const edit = @import("edit.zig");

// Quality gates and safety checks
pub const check = @import("check.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Core Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const EditOperation = needle.EditOperation;
pub const MatchResult = needle.MatchResult;
pub const MatchResultList = needle.MatchResultList;
pub const MatchKind = needle.MatchKind;
pub const NeedleConfig = needle.NeedleConfig;
pub const EditReport = needle.EditReport;
pub const Violation = needle.Violation;
pub const ViolationKind = needle.ViolationKind;
pub const Severity = needle.Severity;
pub const SafetyLevel = needle.SafetyLevel;
pub const EditMode = needle.EditMode;
pub const Query = needle.Query;
pub const QueryKind = needle.QueryKind;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Matchers
// ═══════════════════════════════════════════════════════════════════════════════

pub const FuzzyMatcher = fuzzy.FuzzyMatcher;
pub const Matcher = matcher.Matcher;
pub const Searcher = matcher.Searcher;

// Convenience functions
pub const search = matcher.search;
pub const searchSource = matcher.searchSource;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Edit Operations
// ═══════════════════════════════════════════════════════════════════════════════

pub const TextEditor = edit.TextEditor;
pub const EditEngine = edit.EditEngine;
pub const EditDiff = edit.EditDiff;

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API - Quality Gates
// ═══════════════════════════════════════════════════════════════════════════════

pub const NeedleChecker = check.NeedleChecker;

// Convenience functions
pub const checkSource = check.checkSource;
pub const checkFile = check.checkFile;
