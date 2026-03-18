const std = @import("std");

pub const ValidationResult = struct {
    passed: bool,
    violations: std.ArrayListUnmanaged([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ValidationResult) void {
        self.violations.deinit(self.allocator);
    }
};

pub const Validator = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Validator {
        return Validator{
            .allocator = allocator,
        };
    }

    pub fn validate(self: *Validator, code: []const u8) !ValidationResult {
        var violations = std.ArrayListUnmanaged([]const u8){};
        var passed = true;

        // Law 1: All code must have a 'main' entry point (The Alpha)
        if (std.mem.indexOf(u8, code, "main") == null) {
            try violations.append(self.allocator, "Law Violation: Code lacks a 'main' entry point (The Alpha).");
            passed = false;
        }

        // Law 2: No Forbidden Binary Logic (Mock)
        if (std.mem.indexOf(u8, code, "cursed_binary_hack") != null) {
            try violations.append(self.allocator, "Law Violation: Usage of 'cursed_binary_hack' detected. Heresy!");
            passed = false;
        }

        // Law 3: Code must not be empty
        if (code.len < 10) {
            try violations.append(self.allocator, "Law Violation: Code is too sparse (Void).");
            passed = false;
        }

        return ValidationResult{
            .passed = passed,
            .violations = violations,
            .allocator = self.allocator,
        };
    }
};
