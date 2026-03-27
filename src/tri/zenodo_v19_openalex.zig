//! Zenodo V19: OpenAlex Classification & COAR Notification
//! φ² + 1/φ² = 3 | TRINITY
//!
//! Implements OpenAlex work type classification and COAR notification system
//! References:
//! - OpenAlex: https://docs.openalex.org/
//! - COAR: https://www.coar-repositories.org/notifications/
//!
//! Features:
//! - Work type classification (publication, dataset, software, preprint)
//! - COAR notification payload generation
//! - Indexing service integration

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// OPENALEX WORK TYPE CLASSIFICATION
// ============================================================================

/// OpenAlex work type classification
pub const OpenAlexWorkType = enum(u8) {
    /// Peer-reviewed paper
    publication,
    /// Training data or dataset
    dataset,
    /// Code repository or software
    software,
    /// arXiv preprint
    preprint,
    /// Conference proceeding
    conference,
    /// Book or chapter
    book,
    /// Technical report
    report,

    /// Get OpenAlex type string
    pub fn toString(self: OpenAlexWorkType) []const u8 {
        return switch (self) {
            .publication => "publication",
            .dataset => "dataset",
            .software => "software",
            .preprint => "preprint",
            .conference => "conference",
            .book => "book",
            .report => "report",
        };
    }

    /// Get type from string
    pub fn fromString(s: []const u8) ?OpenAlexWorkType {
        if (std.mem.eql(u8, s, "publication")) return .publication;
        if (std.mem.eql(u8, s, "dataset")) return .dataset;
        if (std.mem.eql(u8, s, "software")) return .software;
        if (std.mem.eql(u8, s, "preprint")) return .preprint;
        if (std.mem.eql(u8, s, "conference")) return .conference;
        if (std.mem.eql(u8, s, "book")) return .book;
        if (std.mem.eql(u8, s, "report")) return .report;
        return null;
    }
};

/// VIBEE spec classification result
pub const SpecClassification = struct {
    work_type: OpenAlexWorkType,
    confidence: f32, // 0.0 to 1.0
    reasoning: []const u8,

    pub fn deinit(self: *const SpecClassification, allocator: Allocator) void {
        allocator.free(self.reasoning);
    }
};

/// Classify VIBEE spec to determine OpenAlex work type
/// Based on spec contents (behaviors, algorithms, data, etc.)
pub fn classifySpec(
    has_behaviors: bool,
    has_algorithms: bool,
    has_data: bool,
    has_tests: bool,
    allocator: Allocator,
) !SpecClassification {
    // Software: has executable behaviors or algorithms
    if (has_behaviors or has_algorithms) {
        return .{
            .work_type = .software,
            .confidence = 0.9,
            .reasoning = try allocator.dupe(u8, "Spec contains executable behaviors or algorithms"),
        };
    }

    // Dataset: primarily data without behaviors
    if (has_data and !has_algorithms) {
        return .{
            .work_type = .dataset,
            .confidence = 0.8,
            .reasoning = try allocator.dupe(u8, "Spec contains data definitions without algorithms"),
        };
    }

    // Publication: has tests but minimal behaviors (likely test suite for paper)
    if (has_tests and !has_behaviors) {
        return .{
            .work_type = .publication,
            .confidence = 0.7,
            .reasoning = try allocator.dupe(u8, "Spec contains tests but no executable behaviors"),
        };
    }

    // Default to software for VIBEE specs
    return .{
        .work_type = .software,
        .confidence = 0.5,
        .reasoning = try allocator.dupe(u8, "Default classification for VIBEE specs"),
    };
}

/// OpenAlex concepts (topics) for Trinity
pub const TrinityConcepts = &[_][]const u8{
    "Neural networks",
    "Ternary computing",
    "FPGA",
    "Vector Symbolic Architectures",
    "Hyperdimensional computing",
    "Artificial intelligence",
    "Machine learning",
    "Balanced ternary",
};

// ============================================================================
// COAR NOTIFICATION SYSTEM
// ============================================================================

/// COAR notification types
pub const CoarNotificationType = enum {
    /// New resource added
    create,
    /// Resource updated
    update,
    /// Resource deleted
    delete,
};

/// COAR notification payload
pub const CoarNotification = struct {
    /// Notification type
    notification_type: CoarNotificationType,
    /// Resource ID (e.g., Zenodo DOI)
    resource_id: []const u8,
    /// Resource URL
    resource_url: []const u8,
    /// Repository name
    repository: []const u8 = "Zenodo",
    /// Timestamp (ISO 8601)
    timestamp: []const u8,
    /// Work type
    work_type: OpenAlexWorkType,
    /// Topics/concepts
    topics: []const []const u8 = &.{},

    /// Generate COAR notification JSON-LD
    pub fn toJsonLd(self: *const CoarNotification, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        const writer = buffer.writer(allocator);

        try writer.writeAll("{\n");

        // Context
        try writer.print("  \"@context\": \"https://coar-repositories.org/contexts/notification.jsonld\",\n", .{});

        // ID (unique notification ID)
        try writer.print("  \"id\": \"{s}/notification/{s}\",\n", .{ self.resource_url, self.timestamp });

        // Type
        const type_str = switch (self.notification_type) {
            .create => "Create",
            .update => "Update",
            .delete => "Delete",
        };
        try writer.print("  \"type\": \"{s}\",\n", .{type_str});

        // Object (the resource being notified about)
        try writer.writeAll("  \"object\": {\n");
        try writer.print("    \"id\": \"{s}\",\n", .{self.resource_id});
        try writer.print("    \"type\": \"{s}\",\n", .{self.work_type.toString()});
        try writer.print("    \"ietf:cite-as\": \"{s}\"\n", .{self.resource_url});
        try writer.writeAll("  },\n");

        // Origin (repository)
        try writer.writeAll("  \"origin\": {\n");
        try writer.print("    \"id\": \"https://{s}\",\n", .{self.repository});
        try writer.writeAll("    \"type\": \"Service\",\n");
        try writer.print("    \"name\": \"{s}\"\n", .{self.repository});
        try writer.writeAll("  },\n");

        // Target (indexing service)
        try writer.writeAll("  \"target\": {\n");
        try writer.writeAll("    \"id\": \"https://openalex.org\",\n");
        try writer.writeAll("    \"type\": \"Service\",\n");
        try writer.writeAll("    \"name\": \"OpenAlex\"\n");
        try writer.writeAll("  },\n");

        // Timestamp
        try writer.print("  \"published\": \"{s}\",\n", .{self.timestamp});

        // Topics (if any)
        if (self.topics.len > 0) {
            try writer.writeAll("  \"topics\": [\n");
            for (self.topics, 0..) |topic, i| {
                const comma = if (i < self.topics.len - 1) "," else "";
                try writer.writeAll("    {\"id\": \"https://openalex.org/topics/");
                try writer.print("{s}", .{topic});
                try writer.writeAll("\", \"name\": \"");
                try writer.print("{s}", .{topic});
                try writer.writeAll("\"}");
                try writer.print("{s}\n", .{comma});
            }
            try writer.writeAll("  ],\n");
        }

        try writer.writeAll("  \"actor\": {\n");
        try writer.writeAll("    \"id\": \"https://github.com/gHashTag/trinity\",\n");
        try writer.writeAll("    \"type\": \"Software\",\n");
        try writer.writeAll("    \"name\": \"Trinity S³AI\"\n");
        try writer.writeAll("  }\n");

        try writer.writeAll("}\n");

        return buffer.toOwnedSlice(allocator);
    }
};

/// Create COAR notification for Zenodo deposit
pub fn createZenodoNotification(
    doi: []const u8,
    work_type: OpenAlexWorkType,
    notification_type: CoarNotificationType,
    allocator: Allocator,
) !CoarNotification {
    // Generate timestamp (ISO 8601)
    const timestamp = try getCurrentTimestamp(allocator);
    errdefer allocator.free(timestamp);

    const url = try std.fmt.allocPrint(allocator, "https://doi.org/{s}", .{doi});
    errdefer allocator.free(url);

    return .{
        .notification_type = notification_type,
        .resource_id = try allocator.dupe(u8, doi),
        .resource_url = url,
        .timestamp = timestamp,
        .work_type = work_type,
        .topics = TrinityConcepts,
    };
}

/// Get current timestamp in ISO 8601 format
fn getCurrentTimestamp(allocator: Allocator) ![]const u8 {
    // Get current time
    const now = std.time.nanoTimestamp();
    const seconds = @divFloor(now, 1_000_000_000);

    // Format as ISO 8601 (simplified - Zig doesn't have datetime formatting yet)
    // For now, return a simplified format
    return std.fmt.allocPrint(allocator, "{d}", .{seconds});
}

/// Send COAR notification (HTTP POST stub)
/// In production, this would send to indexing services
pub fn sendCoarNotification(notification: *const CoarNotification, allocator: Allocator) ![]const u8 {
    _ = allocator;
    _ = notification;

    // TODO: Implement HTTP POST to COAR notification endpoints
    // - OpenAlex: https://api.openalex.org/works
    // - CrossRef: https://api.crossref.org/works

    return error.NotImplemented;
}

// ============================================================================
// OPENALEX INTEGRATION
// ============================================================================

/// OpenAlex work metadata
pub const OpenAlexWork = struct {
    /// OpenAlex ID (https://openalex.org/W123456789)
    id: ?[]const u8 = null,
    /// DOI
    doi: ?[]const u8 = null,
    /// Title
    title: []const u8,
    /// Work type
    type: OpenAlexWorkType,
    /// Publication year
    year: u32,
    /// Concepts (topics)
    concepts: []const []const u8 = &.{},
    /// Citation count
    citation_count: u32 = 0,
    /// Authors
    authors: []const []const u8 = &.{},

    /// Generate OpenAlex JSON
    pub fn toJson(self: *const OpenAlexWork, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayListUnmanaged(u8){};
        defer buffer.deinit(allocator);

        const writer = buffer.writer(allocator);

        try writer.writeAll("{\n");
        try writer.print("  \"title\": \"{s}\",\n", .{self.title});
        try writer.print("  \"type\": \"{s}\",\n", .{self.type.toString()});
        try writer.print("  \"year\": {d},\n", .{self.year});
        try writer.print("  \"citation_count\": {d},\n", .{self.citation_count});

        if (self.doi) |doi| {
            try writer.print("  \"doi\": \"{s}\",\n", .{doi});
        }

        if (self.id) |id| {
            try writer.print("  \"id\": \"{s}\",\n", .{id});
        }

        if (self.concepts.len > 0) {
            try writer.writeAll("  \"concepts\": [\n");
            for (self.concepts, 0..) |concept, i| {
                const comma = if (i < self.concepts.len - 1) "," else "";
                try writer.writeAll("    {\"name\": \"");
                try writer.print("{s}", .{concept});
                try writer.print("\"}}{s}\n", .{comma});
            }
            try writer.writeAll("  ],\n");
        }

        try writer.writeAll("}\n");

        return buffer.toOwnedSlice(allocator);
    }
};

/// Create OpenAlex work for Trinity
pub fn createTrinityOpenAlexWork(
    title: []const u8,
    doi: []const u8,
    year: u32,
    work_type: OpenAlexWorkType,
    allocator: Allocator,
) !OpenAlexWork {
    return .{
        .title = try allocator.dupe(u8, title),
        .doi = try allocator.dupe(u8, doi),
        .type = work_type,
        .year = year,
        .concepts = TrinityConcepts,
    };
}

// ============================================================================
// TESTS
// ============================================================================

test "OpenAlex: WorkType toString/fromString" {
    const wt = OpenAlexWorkType.software;
    try std.testing.expectEqualStrings("software", wt.toString());

    const parsed = OpenAlexWorkType.fromString("software");
    try std.testing.expect(parsed != null);
    try std.testing.expectEqual(wt, parsed.?);
}

test "OpenAlex: classifySpec software" {
    const allocator = std.testing.allocator;

    const result = try classifySpec(true, false, false, false, allocator);
    defer result.deinit(allocator);

    try std.testing.expectEqual(OpenAlexWorkType.software, result.work_type);
    try std.testing.expect(result.confidence > 0.8);
}

test "OpenAlex: classifySpec dataset" {
    const allocator = std.testing.allocator;

    const result = try classifySpec(false, false, true, false, allocator);
    defer result.deinit(allocator);

    try std.testing.expectEqual(OpenAlexWorkType.dataset, result.work_type);
}

test "COAR: createZenodoNotification" {
    const allocator = std.testing.allocator;

    const notification = try createZenodoNotification(
        "10.5281/zenodo.19227879",
        .software,
        .create,
        allocator,
    );
    defer {
        allocator.free(notification.resource_id);
        allocator.free(notification.resource_url);
        allocator.free(notification.timestamp);
    }

    try std.testing.expectEqualStrings("10.5281/zenodo.19227879", notification.resource_id);
    try std.testing.expectEqual(CoarNotificationType.create, notification.notification_type);
}

test "COAR: CoarNotification toJsonLd" {
    const allocator = std.testing.allocator;

    const topics = [_][]const u8{ "Neural networks", "FPGA" };

    const notification = CoarNotification{
        .notification_type = .create,
        .resource_id = "10.5281/zenodo.19227879",
        .resource_url = "https://doi.org/10.5281/zenodo.19227879",
        .timestamp = "2026-03-27T00:00:00Z",
        .work_type = .software,
        .topics = &topics,
    };

    const json = try notification.toJsonLd(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "@context") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Create") != null);
}

test "OpenAlex: createTrinityOpenAlexWork" {
    const allocator = std.testing.allocator;

    const work = try createTrinityOpenAlexWork(
        "Trinity S³AI",
        "10.5281/zenodo.19227879",
        2026,
        .software,
        allocator,
    );
    defer {
        allocator.free(work.title);
        allocator.free(work.doi.?);
    }

    try std.testing.expectEqualStrings("Trinity S³AI", work.title);
    try std.testing.expectEqual(@as(u32, 2026), work.year);
    try std.testing.expectEqual(OpenAlexWorkType.software, work.type);
}

// φ² + 1/φ² = 3 | TRINITY
