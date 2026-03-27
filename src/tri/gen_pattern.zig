//! TRI Pattern — Generated from specs/tri/tri_pattern.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const MatchResult = struct {
    matches: bool,
    captured: []const u8,
};

pub fn globMatch(pattern: []const u8, text: []const u8) bool {
    return wildcardMatch(pattern, text);
}

pub fn wildcardMatch(pattern: []const u8, text: []const u8) bool {
    // Simple * and ? wildcard matching
    if (pattern.len == 0) return text.len == 0;

    var p_idx: usize = 0;
    var t_idx: usize = 0;
    var last_star_p: usize = 0;
    var last_star_t: usize = 0;
    var found_star: bool = false;

    while (t_idx < text.len) {
        if (p_idx < pattern.len and (pattern[p_idx] == text[t_idx] or pattern[p_idx] == '?')) {
            p_idx += 1;
            t_idx += 1;
        } else if (p_idx < pattern.len and pattern[p_idx] == '*') {
            last_star_p = p_idx;
            last_star_t = t_idx;
            found_star = true;
            p_idx += 1;
        } else if (found_star) {
            p_idx = last_star_p + 1;
            last_star_t += 1;
            t_idx = last_star_t;
        } else {
            return false;
        }
    }

    // Skip trailing stars
    while (p_idx < pattern.len and pattern[p_idx] == '*') {
        p_idx += 1;
    }

    return p_idx == pattern.len;
}

test "Pattern: wildcardMatch exact" {
    try std.testing.expect(wildcardMatch("hello", "hello"));
    try std.testing.expect(!wildcardMatch("hello", "world"));
}

test "Pattern: wildcardMatch star" {
    try std.testing.expect(wildcardMatch("*", "anything"));
    try std.testing.expect(wildcardMatch("h*", "hello"));
    try std.testing.expect(!wildcardMatch("x*", "hello"));
}

test "Pattern: wildcardMatch question" {
    try std.testing.expect(wildcardMatch("h?llo", "hallo"));
    try std.testing.expect(wildcardMatch("h?llo", "hello"));
    try std.testing.expect(!wildcardMatch("h?llo", "hell"));
}
