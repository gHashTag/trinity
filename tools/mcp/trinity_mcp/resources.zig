//! Trinity MCP Resources - Sacred Constants, Papers, Documentation
//! V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY
const std = @import("std");

/// Sacred mathematical constants
const PHI: f64 = 1.6180339887498948482;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.71828182845904523536;

/// Resource metadata
pub const Resource = struct {
    uri: []const u8,
    name: []const u8,
    description: []const u8,
    mime_type: []const u8,
};

/// Generate JSON list of all available resources
pub fn generateResourcesList(allocator: std.mem.Allocator) ![]const u8 {
    const resources = [_]Resource{
        .{
            .uri = "trinity://constants/all",
            .name = "All Sacred Constants",
            .description = "All sacred mathematical constants from V = n × 3^k × π^m × φ^p × e^q",
            .mime_type = "application/json",
        },
        .{
            .uri = "trinity://constants/particle_physics",
            .name = "Particle Physics Constants",
            .description = "Fundamental particle physics constants with sacred formula fits",
            .mime_type = "application/json",
        },
        .{
            .uri = "trinity://constants/cosmology",
            .name = "Cosmology Constants",
            .description = "Universal constants from sacred formula",
            .mime_type = "application/json",
        },
        .{
            .uri = "trinity://constants/sacred",
            .name = "Sacred Mathematics",
            .description = "φ, π, e and their relationships",
            .mime_type = "application/json",
        },
        .{
            .uri = "trinity://papers/temporal_phi",
            .name = "Time and the Golden Ratio",
            .description = "Research paper: temporal_phi.tex - Planck time, specious present",
            .mime_type = "text/plain",
        },
        .{
            .uri = "trinity://papers/consciousness_trinity",
            .name = "Consciousness and TRINITY",
            .description = "Research paper: neural gamma, consciousness threshold",
            .mime_type = "text/plain",
        },
        .{
            .uri = "trinity://papers/gravity_phi",
            .name = "Gravitational Constants from φ",
            .description = "Research paper: G, Ω_Λ, Ω_DM from golden ratio",
            .mime_type = "text/plain",
        },
        .{
            .uri = "trinity://papers/unified",
            .name = "Unified Framework",
            .description = "Research paper: complete TRINITY unified theory",
            .mime_type = "text/plain",
        },
        .{
            .uri = "file://CLAUDE.md",
            .name = "CLI Documentation",
            .description = "Complete Trinity CLI command reference (280+ commands)",
            .mime_type = "text/markdown",
        },
        .{
            .uri = "trinity://docs/architecture",
            .name = "Architecture Overview",
            .description = "Trinity system architecture documentation",
            .mime_type = "text/markdown",
        },
    };

    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();

    try json_buffer.appendSlice("{\"resources\":[");

    for (resources, 0..) |r, i| {
        if (i > 0) try json_buffer.appendSlice(",");
        try json_buffer.print(
            \\{{"uri":"{s}","name":"{s}","description":"{s}","mimeType":"{s}"}}
        , .{ r.uri, r.name, r.description, r.mime_type });
    }

    try json_buffer.appendSlice("]}");

    return json_buffer.toOwnedSlice();
}

/// Check if a resource URI exists
pub fn hasResource(uri: []const u8) bool {
    if (std.mem.startsWith(u8, uri, "trinity://constants/")) return true;
    if (std.mem.startsWith(u8, uri, "trinity://papers/")) return true;
    if (std.mem.startsWith(u8, uri, "trinity://docs/")) return true;
    if (std.mem.startsWith(u8, uri, "file://")) return true;
    return false;
}

/// Load and return resource content as JSON
pub fn loadResource(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    // Sacred constants resources
    if (std.mem.startsWith(u8, uri, "trinity://constants/")) {
        return formatConstantsJson(allocator, uri);
    }

    // Papers resources
    if (std.mem.startsWith(u8, uri, "trinity://papers/")) {
        return loadPaper(allocator, uri);
    }

    // Documentation resources
    if (std.mem.startsWith(u8, uri, "trinity://docs/")) {
        return loadDocs(allocator, uri);
    }

    // File resources
    if (std.mem.startsWith(u8, uri, "file://")) {
        return loadFile(allocator, uri[7..]);
    }

    return error.ResourceNotFound;
}

/// Format sacred constants as JSON
fn formatConstantsJson(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    const category = std.mem.trimLeft(u8, uri, "trinity://constants/");

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try buffer.appendSlice("{");

    if (std.mem.eql(u8, category, "all") or std.mem.eql(u8, category, "sacred")) {
        try buffer.print(
            \\\"phi\":{d},\"phi_squared\":{d},\"phi_inverse\":{d},\"pi\":{d},\"e\":{d},\"trinity\":\"φ² + 1/φ² = 3\"
        , .{ PHI, PHI * PHI, 1.0 / PHI, PI, E });
    }

    if (std.mem.eql(u8, category, "particle_physics")) {
        try buffer.print(
            \\\"fine_structure\":137.036,\"proton_electron_mass\":1836.152673,\"electron_g_factor\":2.002319
        , .{});
    }

    if (std.mem.eql(u8, category, "cosmology")) {
        try buffer.print(
            \\\"cosmological_constant_omega_lambda\":0.69,\"dark_matter_omega_dm\":0.26,\"hubble_constant_h0\":70.0
        , .{});
    }

    try buffer.appendSlice("}");

    return buffer.toOwnedSlice();
}

/// Load research paper content
fn loadPaper(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    const topic = std.mem.trimLeft(u8, uri, "trinity://papers/");

    const project_root = std.process.getCwdAlloc(allocator) catch "/Users/playra/trinity-w1";

    const papers = std.ComptimeStringMap([]const u8, .{
        .{ "temporal_phi", "docs/papers/TEMPORAL_PHI.tex" },
        .{ "consciousness_trinity", "docs/papers/CONSCIOUSNESS_TRINITY.tex" },
        .{ "gravity_phi", "docs/papers/GRAVITY_PHI.tex" },
        .{ "unified", "docs/papers/TRINITY_UNIFIED.tex" },
    });

    const rel_path = papers.get(topic) orelse return error.PaperNotFound;

    const path = try std.fs.path.join(allocator, &[_][]const u8{ project_root, rel_path });
    defer allocator.free(path);

    return std.fs.cwd().readFileAlloc(allocator, path, 1_000_000) catch error.PaperNotFound;
}

/// Load documentation content
fn loadDocs(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    const page = std.mem.trimLeft(u8, uri, "trinity://docs/");

    const project_root = std.process.getCwdAlloc(allocator) catch "/Users/playra/trinity-w1";

    const docs = std.ComptimeStringMap([]const u8, .{
        .{ "architecture", "docsite/docs/architecture/overview.md" },
        .{ "api", "docsite/docs/api/index.md" },
        .{ "sacred", "docsite/docs/research/index.md" },
    });

    const rel_path = docs.get(page) orelse return error.DocNotFound;

    const path = try std.fs.path.join(allocator, &[_][]const u8{ project_root, rel_path });
    defer allocator.free(path);

    return std.fs.cwd().readFileAlloc(allocator, path, 100_000) catch error.DocNotFound;
}

/// Load file from project root
fn loadFile(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    const project_root = std.process.getCwdAlloc(allocator) catch "/Users/playra/trinity-w1";

    const path = try std.fs.path.join(allocator, &[_][]const u8{ project_root, file_path });
    defer allocator.free(path);

    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1_000_000);

    // Add sacred formula footer
    var result = try allocator.alloc(u8, content.len + 100);
    std.mem.copy(u8, result, content);
    const footer = "\n\n---\nV = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY";
    std.mem.copy(u8, result[content.len..], footer);

    return result;
}
