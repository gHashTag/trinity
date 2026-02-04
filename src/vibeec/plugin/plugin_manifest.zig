// Trinity Plugin Manifest Parser
// Generated from: specs/tri/plugin/plugin_manifest.vibee
// Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
// Golden Identity: phi^2 + 1/phi^2 = 3

const std = @import("std");
const Allocator = std.mem.Allocator;
const interface = @import("plugin_interface.zig");

const PluginKind = interface.PluginKind;
const PluginCapability = interface.PluginCapability;

// ============================================================================
// CONSTANTS
// ============================================================================

pub const MANIFEST_FILENAME = "plugin.vibee";
pub const LOCKFILE_FILENAME = "plugin-lock.yaml";
pub const MAX_DEPENDENCIES: usize = 256;
pub const MAX_KEYWORDS: usize = 32;

// ============================================================================
// TYPES
// ============================================================================

/// Semantic version
pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,
    prerelease: ?[]const u8 = null,

    pub fn parse(str: []const u8) !Version {
        var iter = std.mem.splitScalar(u8, str, '.');
        const major_str = iter.next() orelse return error.InvalidVersion;
        const minor_str = iter.next() orelse return error.InvalidVersion;
        const patch_str = iter.next() orelse "0";

        // Handle prerelease suffix (e.g., "1.0.0-alpha")
        var patch_iter = std.mem.splitScalar(u8, patch_str, '-');
        const patch_num = patch_iter.next() orelse return error.InvalidVersion;
        const prerelease = patch_iter.next();

        return .{
            .major = std.fmt.parseInt(u32, major_str, 10) catch return error.InvalidVersion,
            .minor = std.fmt.parseInt(u32, minor_str, 10) catch return error.InvalidVersion,
            .patch = std.fmt.parseInt(u32, patch_num, 10) catch return error.InvalidVersion,
            .prerelease = prerelease,
        };
    }

    pub fn format(self: Version, writer: anytype) !void {
        try writer.print("{}.{}.{}", .{ self.major, self.minor, self.patch });
        if (self.prerelease) |pre| {
            try writer.print("-{s}", .{pre});
        }
    }

    pub fn compare(a: Version, b: Version) std.math.Order {
        if (a.major != b.major) return std.math.order(a.major, b.major);
        if (a.minor != b.minor) return std.math.order(a.minor, b.minor);
        return std.math.order(a.patch, b.patch);
    }
};

/// Version comparison operator
pub const VersionOp = enum {
    exact, // "=1.0.0"
    gte, // ">=1.0.0"
    lte, // "<=1.0.0"
    gt, // ">1.0.0"
    lt, // "<1.0.0"
    compatible, // "^1.0.0" (>=1.0.0 <2.0.0)
    tilde, // "~1.0.0" (>=1.0.0 <1.1.0)
};

/// Semantic version constraint
pub const VersionConstraint = struct {
    op: VersionOp,
    version: Version,

    pub fn parse(str: []const u8) !VersionConstraint {
        var s = str;
        var op: VersionOp = .exact;

        if (std.mem.startsWith(u8, s, ">=")) {
            op = .gte;
            s = s[2..];
        } else if (std.mem.startsWith(u8, s, "<=")) {
            op = .lte;
            s = s[2..];
        } else if (std.mem.startsWith(u8, s, ">")) {
            op = .gt;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "<")) {
            op = .lt;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "^")) {
            op = .compatible;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "~")) {
            op = .tilde;
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "=")) {
            op = .exact;
            s = s[1..];
        }

        const version = try Version.parse(s);
        return .{ .op = op, .version = version };
    }

    pub fn satisfies(self: VersionConstraint, v: Version) bool {
        return switch (self.op) {
            .exact => Version.compare(v, self.version) == .eq,
            .gte => Version.compare(v, self.version) != .lt,
            .lte => Version.compare(v, self.version) != .gt,
            .gt => Version.compare(v, self.version) == .gt,
            .lt => Version.compare(v, self.version) == .lt,
            .compatible => {
                // ^1.2.3 means >=1.2.3 and <2.0.0
                if (Version.compare(v, self.version) == .lt) return false;
                return v.major == self.version.major;
            },
            .tilde => {
                // ~1.2.3 means >=1.2.3 and <1.3.0
                if (Version.compare(v, self.version) == .lt) return false;
                return v.major == self.version.major and v.minor == self.version.minor;
            },
        };
    }
};

/// Plugin dependency
pub const Dependency = struct {
    id: []const u8,
    version_constraint: VersionConstraint,
};

/// Type of sandbox
pub const SandboxType = enum {
    wasm, // WASM sandbox (default)
    native, // Native code (requires trust level 3)
    hybrid, // WASM with native extensions
};

/// Permission granted to plugin
pub const Permission = enum {
    file_read, // Read files
    file_write, // Write files
    codegen_output, // Write to trinity/output/
    spec_read, // Read specs/tri/
    network, // Network access (rare)
};

/// Sandbox configuration
pub const SandboxConfig = struct {
    type: SandboxType = .wasm,
    permissions: []const Permission = &[_]Permission{},
    memory_limit_mb: usize = 256,
    timeout_ms: u32 = 30000,
};

/// Trinity-specific sacred metadata
pub const SacredMetadata = struct {
    phoenix_compatible: bool = true,
    trinity_score: f64 = 1.0,
    golden_chain_verified: bool = false,
};

/// Complete plugin manifest
pub const PluginManifest = struct {
    allocator: Allocator,

    // Identity
    id: []const u8,
    name: []const u8,
    version: Version,
    description: []const u8,
    author: []const u8,
    license: []const u8,
    repository: ?[]const u8,
    homepage: ?[]const u8,
    keywords: []const []const u8,

    // Classification
    kind: PluginKind,
    capabilities: []const PluginCapability,

    // Dependencies
    trinity_version: VersionConstraint,
    dependencies: []const Dependency,
    dev_dependencies: []const Dependency,
    optional_dependencies: []const Dependency,
    peer_dependencies: []const Dependency,

    // Entry points
    entry_point: []const u8,
    exports: []const []const u8,

    // Execution environment
    sandbox: SandboxConfig,

    // Configuration schema
    config_schema: ?[]const u8,

    // Sacred metadata
    sacred: SacredMetadata,

    pub fn deinit(self: *PluginManifest) void {
        _ = self;
        // Free allocated strings if needed
    }
};

/// Result of parsing manifest
pub const ParsedManifest = struct {
    manifest: ?PluginManifest,
    errors: []const []const u8,
    warnings: []const []const u8,

    pub fn ok(manifest: PluginManifest) ParsedManifest {
        return .{
            .manifest = manifest,
            .errors = &[_][]const u8{},
            .warnings = &[_][]const u8{},
        };
    }

    pub fn err(errors: []const []const u8) ParsedManifest {
        return .{
            .manifest = null,
            .errors = errors,
            .warnings = &[_][]const u8{},
        };
    }
};

// ============================================================================
// MANIFEST PARSER
// ============================================================================

/// Parse plugin manifest from YAML string
pub fn parseManifest(allocator: Allocator, source: []const u8) !ParsedManifest {
    // Simple YAML-like parser for plugin manifests
    // In production, would use proper YAML parser

    var manifest = PluginManifest{
        .allocator = allocator,
        .id = "",
        .name = "",
        .version = .{ .major = 0, .minor = 0, .patch = 0 },
        .description = "",
        .author = "",
        .license = "MIT",
        .repository = null,
        .homepage = null,
        .keywords = &[_][]const u8{},
        .kind = .codegen,
        .capabilities = &[_]PluginCapability{},
        .trinity_version = .{ .op = .gte, .version = .{ .major = 22, .minor = 0, .patch = 0 } },
        .dependencies = &[_]Dependency{},
        .dev_dependencies = &[_]Dependency{},
        .optional_dependencies = &[_]Dependency{},
        .peer_dependencies = &[_]Dependency{},
        .entry_point = "plugin.wasm",
        .exports = &[_][]const u8{},
        .sandbox = .{},
        .config_schema = null,
        .sacred = .{},
    };

    // Parse line by line
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        // Parse key: value
        if (std.mem.indexOf(u8, trimmed, ":")) |colon_pos| {
            const key = std.mem.trim(u8, trimmed[0..colon_pos], " ");
            const value = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \"'");

            if (std.mem.eql(u8, key, "name")) {
                manifest.name = value;
                if (manifest.id.len == 0) {
                    manifest.id = value;
                }
            } else if (std.mem.eql(u8, key, "id")) {
                manifest.id = value;
            } else if (std.mem.eql(u8, key, "version")) {
                manifest.version = Version.parse(value) catch .{ .major = 0, .minor = 0, .patch = 0 };
            } else if (std.mem.eql(u8, key, "description")) {
                manifest.description = value;
            } else if (std.mem.eql(u8, key, "author")) {
                manifest.author = value;
            } else if (std.mem.eql(u8, key, "license")) {
                manifest.license = value;
            } else if (std.mem.eql(u8, key, "entry_point")) {
                manifest.entry_point = value;
            } else if (std.mem.eql(u8, key, "kind")) {
                manifest.kind = parseKind(value);
            }
        }
    }

    return ParsedManifest.ok(manifest);
}

/// Parse manifest from file
pub fn parseManifestFromFile(allocator: Allocator, path: []const u8) !ParsedManifest {
    const file = std.fs.cwd().openFile(path, .{}) catch {
        return ParsedManifest.err(&[_][]const u8{"Failed to open manifest file"});
    };
    defer file.close();

    const source = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return ParsedManifest.err(&[_][]const u8{"Failed to read manifest file"});
    };
    defer allocator.free(source);

    return parseManifest(allocator, source);
}

/// Validate manifest
pub fn validateManifest(manifest: *const PluginManifest) !void {
    if (manifest.id.len == 0) return error.MissingId;
    if (manifest.name.len == 0) return error.MissingName;
    if (manifest.version.major == 0 and manifest.version.minor == 0 and manifest.version.patch == 0) {
        return error.InvalidVersion;
    }
    if (manifest.entry_point.len == 0) return error.MissingEntryPoint;
}

/// Check if version satisfies constraint
pub fn checkVersionConstraint(version: Version, constraint: VersionConstraint) bool {
    return constraint.satisfies(version);
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

fn parseKind(value: []const u8) PluginKind {
    if (std.mem.eql(u8, value, "codegen")) return .codegen;
    if (std.mem.eql(u8, value, "validator")) return .validator;
    if (std.mem.eql(u8, value, "vsa_op")) return .vsa_op;
    if (std.mem.eql(u8, value, "firebird_ext")) return .firebird_ext;
    if (std.mem.eql(u8, value, "optimizer")) return .optimizer;
    if (std.mem.eql(u8, value, "backend")) return .backend;
    return .codegen; // default
}

/// Serialize manifest to YAML
pub fn serializeManifest(allocator: Allocator, manifest: *const PluginManifest) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    try writer.print("# Trinity Plugin Manifest\n", .{});
    try writer.print("# phi^2 + 1/phi^2 = 3\n\n", .{});
    try writer.print("name: {s}\n", .{manifest.name});
    try writer.print("id: {s}\n", .{manifest.id});
    try writer.print("version: \"{}.{}.{}\"\n", .{ manifest.version.major, manifest.version.minor, manifest.version.patch });
    try writer.print("description: {s}\n", .{manifest.description});
    try writer.print("author: {s}\n", .{manifest.author});
    try writer.print("license: {s}\n", .{manifest.license});
    try writer.print("kind: {s}\n", .{manifest.kind.toString()});
    try writer.print("entry_point: {s}\n", .{manifest.entry_point});

    return buffer.toOwnedSlice();
}

// ============================================================================
// TESTS
// ============================================================================

test "version parse" {
    const v = try Version.parse("1.2.3");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 2), v.minor);
    try std.testing.expectEqual(@as(u32, 3), v.patch);
}

test "version parse with prerelease" {
    const v = try Version.parse("1.0.0-alpha");
    try std.testing.expectEqual(@as(u32, 1), v.major);
    try std.testing.expectEqual(@as(u32, 0), v.minor);
    try std.testing.expectEqual(@as(u32, 0), v.patch);
    try std.testing.expectEqualStrings("alpha", v.prerelease.?);
}

test "version compare" {
    const v1 = try Version.parse("1.0.0");
    const v2 = try Version.parse("1.0.1");
    const v3 = try Version.parse("2.0.0");

    try std.testing.expectEqual(std.math.Order.lt, Version.compare(v1, v2));
    try std.testing.expectEqual(std.math.Order.lt, Version.compare(v2, v3));
    try std.testing.expectEqual(std.math.Order.eq, Version.compare(v1, v1));
}

test "version constraint parse gte" {
    const c = try VersionConstraint.parse(">=1.0.0");
    try std.testing.expectEqual(VersionOp.gte, c.op);
    try std.testing.expectEqual(@as(u32, 1), c.version.major);
}

test "version constraint parse compatible" {
    const c = try VersionConstraint.parse("^1.2.0");
    try std.testing.expectEqual(VersionOp.compatible, c.op);
    try std.testing.expectEqual(@as(u32, 1), c.version.major);
    try std.testing.expectEqual(@as(u32, 2), c.version.minor);
}

test "version constraint satisfies" {
    const c = try VersionConstraint.parse("^1.0.0");
    const v1 = try Version.parse("1.5.0");
    const v2 = try Version.parse("2.0.0");
    const v3 = try Version.parse("0.9.0");

    try std.testing.expect(c.satisfies(v1)); // 1.5.0 satisfies ^1.0.0
    try std.testing.expect(!c.satisfies(v2)); // 2.0.0 doesn't satisfy ^1.0.0
    try std.testing.expect(!c.satisfies(v3)); // 0.9.0 doesn't satisfy ^1.0.0
}

test "parse simple manifest" {
    const allocator = std.testing.allocator;
    const source =
        \\name: test-plugin
        \\version: "1.0.0"
        \\kind: codegen
        \\author: Test Author
    ;

    const result = try parseManifest(allocator, source);
    try std.testing.expect(result.manifest != null);

    const m = result.manifest.?;
    try std.testing.expectEqualStrings("test-plugin", m.name);
    try std.testing.expectEqual(@as(u32, 1), m.version.major);
    try std.testing.expectEqual(PluginKind.codegen, m.kind);
}

test "parse kind" {
    try std.testing.expectEqual(PluginKind.codegen, parseKind("codegen"));
    try std.testing.expectEqual(PluginKind.validator, parseKind("validator"));
    try std.testing.expectEqual(PluginKind.vsa_op, parseKind("vsa_op"));
}
