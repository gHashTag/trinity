//! Zenodo V19: ORCID Integration Module
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Implements ORCID iD validation and integration per ISO 7064:1983.MOD 11-2
//! Reference: https://info.orcid.org/documentation/developer-guides/
//!
//! Features:
//! - ORCID format validation (XXXX-XXXX-XXXX-XXXX)
//! - ISO 7064:1983.MOD 11-2 checksum verification
//! - HTTPS URL generation
//! - Author metadata structure

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// ORCID AUTHOR STRUCTURE
// ============================================================================

/// Author with ORCID integration
pub const Author = struct {
    /// Full name (e.g., "Vasilev, Dmitrii")
    name: []const u8,
    /// ORCID iD (e.g., "0000-0002-1825-0097")
    orcid: ?[]const u8 = null,
    /// Institution affiliations
    affiliations: []const []const u8 = &.{},
    /// Email address
    email: ?[]const u8 = null,
    /// Corresponding author flag
    corresponding: bool = false,

    /// Validate author has required fields
    pub fn isValid(self: *const Author) bool {
        return self.name.len > 0;
    }

    /// Get ORCID URL (https://orcid.org/XXXX-XXXX-XXXX-XXXX)
    pub fn getOrcidUrl(self: *const Author, allocator: Allocator) ![]const u8 {
        if (self.orcid) |orcid| {
            return std.fmt.allocPrint(allocator, "https://orcid.org/{s}", .{orcid});
        }
        return error.NoOrcidId;
    }

    /// Format author for citation (Vasilev, D.)
    pub fn formatCitation(self: *const Author, allocator: Allocator) ![]const u8 {
        // Parse name: "Last, First" or "First Last"
        var parts = std.mem.splitScalar(u8, self.name, ' ');
        var last_name: []const u8 = "";
        var first_initial: u8 = 0;

        var i: usize = 0;
        while (parts.next()) |part| {
            if (i == 0) {
                // Check if comma-separated (Last, First)
                if (std.mem.indexOfScalar(u8, part, ',')) |comma_idx| {
                    last_name = part[0..comma_idx];
                    if (part.len > comma_idx + 2) {
                        first_initial = part[comma_idx + 2];
                    }
                } else {
                    last_name = part;
                }
            } else if (first_initial == 0 and part.len > 0) {
                first_initial = part[0];
            }
            i += 1;
        }

        if (last_name.len == 0) {
            return std.fmt.allocPrint(allocator, "{s}", .{self.name});
        }

        if (first_initial == 0) {
            return std.fmt.allocPrint(allocator, "{s}", .{last_name});
        }

        return std.fmt.allocPrint(allocator, "{s}, {c}", .{ last_name, first_initial });
    }
};

// ============================================================================
// ORCID VALIDATION
// ============================================================================

/// ORCID validation result
pub const OrcidValidation = struct {
    valid: bool,
    err_msg: ?[]const u8,

    pub fn format(self: *const OrcidValidation, allocator: Allocator) ![]const u8 {
        if (self.valid) {
            return allocator.dupe(u8, "✅ Valid ORCID iD");
        }
        if (self.err_msg) |err| {
            return std.fmt.allocPrint(allocator, "❌ Invalid: {s}", .{err});
        }
        return allocator.dupe(u8, "❌ Invalid ORCID iD");
    }
};

/// Validate ORCID format: XXXX-XXXX-XXXX-XXXX (16 digits, 3 hyphens)
pub fn validateOrcidFormat(orcid: []const u8) OrcidValidation {
    // Check length: 16 digits + 3 hyphens = 19 characters
    if (orcid.len != 19) {
        return .{ .valid = false, .err_msg = "ORCID must be 19 characters (XXXX-XXXX-XXXX-XXXX)" };
    }

    // Check hyphen positions
    if (orcid[4] != '-' or orcid[9] != '-' or orcid[14] != '-') {
        return .{ .valid = false, .err_msg = "Hyphens must be at positions 4, 9, 14" };
    }

    // Check all other characters are digits
    var digit_count: usize = 0;
    for (orcid, 0..) |c, i| {
        if (i == 4 or i == 9 or i == 14) continue; // Skip hyphens
        if (c < '0' or c > '9') {
            return .{ .valid = false, .err_msg = "All non-hyphen characters must be digits" };
        }
        digit_count += 1;
    }

    if (digit_count != 16) {
        return .{ .valid = false, .err_msg = "Must have exactly 16 digits" };
    }

    return .{ .valid = true, .err_msg = null };
}

/// Verify ORCID checksum using ISO 7064:1983.MOD 11-2
/// Reference: https://support.orcid.org/hc/en-us/articles/360006872674
pub fn verifyOrcidChecksum(orcid: []const u8) OrcidValidation {
    // First validate format
    const format_valid = validateOrcidFormat(orcid);
    if (!format_valid.valid) {
        return format_valid;
    }

    // Extract digits (remove hyphens)
    var digits: [16]u8 = undefined;
    var digit_idx: usize = 0;

    for (orcid) |c| {
        if (c == '-') continue;
        digits[digit_idx] = c - '0';
        digit_idx += 1;
    }

    // ISO 7064:1983.MOD 11-2 checksum algorithm
    // 1. Process first 15 digits
    var total: u32 = 0;
    for (digits[0..15]) |d| {
        total = (total + d) * 2;
    }

    // 2. Compute checksum
    const remainder = total % 11;
    const result = (12 - remainder) % 11;

    // 3. Result 10 is represented as 'X'
    const checksum_digit: u8 = if (result == 10) 'X' else @as(u8, @intCast('0')) + @as(u8, @intCast(result));

    // 4. Compare with last digit
    const expected: u8 = if (checksum_digit == 'X') 'X' else digits[15] + '0';

    if (checksum_digit != expected) {
        return .{ .valid = false, .err_msg = "Checksum verification failed" };
    }

    return .{ .valid = true, .err_msg = null };
}

/// Full ORCID validation (format + checksum)
pub fn validateOrcid(orcid: []const u8) OrcidValidation {
    return verifyOrcidChecksum(orcid);
}

/// Check if ORCID belongs to known Trinity contributors
pub const KnownContributor = enum {
    dmitrii_vasilev,
    /// Add more contributors as needed
    pub fn orcid(self: KnownContributor) []const u8 {
        return switch (self) {
            .dmitrii_vasilev => "0000-0002-1825-0097",
        };
    }

    pub fn name(self: KnownContributor) []const u8 {
        return switch (self) {
            .dmitrii_vasilev => "Vasilev, Dmitrii",
        };
    }
};

/// Get Author struct for known contributor
pub fn getKnownContributor(contributor: KnownContributor) Author {
    return .{
        .name = contributor.name(),
        .orcid = contributor.orcid(),
        .corresponding = true,
    };
}

// ============================================================================
// ORCID URL GENERATION
// ============================================================================

/// Generate ORCID HTTPS URL
pub fn orcidUrl(orcid: []const u8, allocator: Allocator) ![]const u8 {
    const valid = validateOrcid(orcid);
    if (!valid.valid) {
        return error.InvalidOrcid;
    }

    return std.fmt.allocPrint(allocator, "https://orcid.org/{s}", .{orcid});
}

/// Parse ORCID from URL (https://orcid.org/XXXX-XXXX-XXXX-XXXX)
pub fn parseOrcidFromUrl(url: []const u8, allocator: Allocator) ![]const u8 {
    const prefix = "https://orcid.org/";
    const orcid_start = std.mem.indexOf(u8, url, prefix) orelse return error.InvalidOrcidUrl;
    const orcid = url[orcid_start + prefix.len ..];

    // Validate extracted ORCID
    const valid = validateOrcid(orcid);
    if (!valid.valid) {
        return error.InvalidOrcid;
    }

    return allocator.dupe(u8, orcid);
}

// ============================================================================
// AUTHOR LIST MANAGEMENT
// ============================================================================

/// List of authors with ORCID support
pub const AuthorList = struct {
    authors: std.ArrayListUnmanaged(Author),
    corresponding_idx: ?usize = null,

    /// Initialize empty author list
    pub fn init(_: Allocator) AuthorList {
        return .{
            .authors = .{},
        };
    }

    /// Deallocate author list and all owned strings
    pub fn deinit(self: *AuthorList, allocator: Allocator) void {
        for (self.authors.items) |author| {
            allocator.free(author.name);
            if (author.orcid) |orcid| allocator.free(orcid);
            if (author.email) |email| allocator.free(email);
            for (author.affiliations) |aff| {
                allocator.free(aff);
            }
            allocator.free(author.affiliations);
        }
        self.authors.deinit(allocator);
    }

    /// Add author to list
    pub fn add(self: *AuthorList, allocator: Allocator, author: Author) !void {
        if (author.corresponding) {
            self.corresponding_idx = self.authors.items.len;
        }

        // Duplicate strings to owned memory
        var owned = author;
        owned.name = try allocator.dupe(u8, author.name);
        if (author.orcid) |orcid| {
            owned.orcid = try allocator.dupe(u8, orcid);
        }
        if (author.email) |email| {
            owned.email = try allocator.dupe(u8, email);
        }

        // Duplicate affiliations
        var owned_affiliations = try allocator.alloc([]const u8, author.affiliations.len);
        for (author.affiliations, 0..) |aff, i| {
            owned_affiliations[i] = try allocator.dupe(u8, aff);
        }
        owned.affiliations = owned_affiliations;

        try self.authors.append(allocator, owned);
    }

    /// Get corresponding author
    pub fn getCorresponding(self: *const AuthorList) ?*const Author {
        if (self.corresponding_idx) |idx| {
            if (idx < self.authors.items.len) {
                return &self.authors.items[idx];
            }
        }
        return null;
    }

    /// Format authors for citation
    pub fn formatCitation(self: *const AuthorList, allocator: Allocator) ![]const u8 {
        if (self.authors.items.len == 0) {
            return allocator.dupe(u8, "");
        }

        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        for (self.authors.items, 0..) |author, i| {
            if (i > 0) {
                if (i == self.authors.items.len - 1) {
                    try buffer.appendSlice(allocator, ", and ");
                } else {
                    try buffer.appendSlice(allocator, ", ");
                }
            }

            const formatted = try author.formatCitation(allocator);
            defer allocator.free(formatted);
            try buffer.appendSlice(allocator, formatted);
        }

        return buffer.toOwnedSlice(allocator);
    }

    /// Validate all ORCIDs in list
    pub fn validateAllOrcids(self: *const AuthorList) !OrcidValidation {
        for (self.authors.items) |author| {
            if (author.orcid) |orcid| {
                const valid = validateOrcid(orcid);
                if (!valid.valid) {
                    // Return static error message (no allocation)
                    return .{ .valid = false, .err_msg = "Invalid ORCID found in author list" };
                }
            }
        }
        return .{ .valid = true, .err_msg = null };
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "ORCID: validateOrcidFormat valid" {
    const result = validateOrcidFormat("0000-0002-1825-0097");
    try std.testing.expect(result.valid);
}

test "ORCID: validateOrcidFormat invalid length" {
    const result = validateOrcidFormat("0000-0002-1825-009");
    try std.testing.expect(!result.valid);
}

test "ORCID: validateOrcidFormat missing hyphens" {
    const result = validateOrcidFormat("0000000218250097");
    try std.testing.expect(!result.valid);
}

test "ORCID: verifyOrcidChecksum valid" {
    const result = verifyOrcidChecksum("0000-0002-1825-0097");
    try std.testing.expect(result.valid);
}

test "ORCID: verifyOrcidChecksum invalid" {
    const result = verifyOrcidChecksum("0000-0002-1825-0098");
    try std.testing.expect(!result.valid);
}

test "ORCID: known contributor ORCID" {
    const contributor = getKnownContributor(.dmitrii_vasilev);
    try std.testing.expectEqualStrings("Vasilev, Dmitrii", contributor.name);
    try std.testing.expectEqualStrings("0000-0002-1825-0097", contributor.orcid.?);
}

test "ORCID: Author formatCitation" {
    const author = Author{
        .name = "Vasilev, Dmitrii",
        .orcid = "0000-0002-1825-0097",
    };

    const citation = try author.formatCitation(std.testing.allocator);
    defer std.testing.allocator.free(citation);

    try std.testing.expectEqualStrings("Vasilev, D", citation);
}

test "ORCID: AuthorList formatCitation" {
    const allocator = std.testing.allocator;

    var list = AuthorList.init(allocator);
    defer list.deinit(allocator);

    try list.add(allocator, .{ .name = "Smith, John" });
    try list.add(allocator, .{ .name = "Doe, Jane" });
    try list.add(allocator, .{ .name = "Johnson, Bob" });

    const citation = try list.formatCitation(allocator);
    defer allocator.free(citation);

    try std.testing.expectEqualStrings("Smith, J, Doe, J, and Johnson, B", citation);
}

test "ORCID: AuthorList validateAllOrcids" {
    const allocator = std.testing.allocator;

    var list = AuthorList.init(allocator);
    defer list.deinit(allocator);

    try list.add(allocator, .{
        .name = "Vasilev, Dmitrii",
        .orcid = "0000-0002-1825-0097",
    });

    try list.add(allocator, .{
        .name = "Invalid Author",
        .orcid = "0000-0002-1825-0098", // Invalid checksum
    });

    const result = try list.validateAllOrcids();
    try std.testing.expect(!result.valid);
}

// φ² + 1/φ² = 3 | TRINITY
