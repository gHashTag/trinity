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

/// All available resources
pub const resources = [_]Resource{
    .{ .uri = "trinity://constants/all", .name = "All Sacred Constants", .description = "All sacred mathematical constants from V = n * 3^k * pi^m * phi^p * e^q", .mime_type = "application/json" },
    .{ .uri = "trinity://constants/particle_physics", .name = "Particle Physics Constants", .description = "Fundamental particle physics constants with sacred formula fits", .mime_type = "application/json" },
    .{ .uri = "trinity://constants/cosmology", .name = "Cosmology Constants", .description = "Universal constants from sacred formula", .mime_type = "application/json" },
    .{ .uri = "trinity://constants/sacred", .name = "Sacred Mathematics", .description = "phi, pi, e and their relationships", .mime_type = "application/json" },
    .{ .uri = "trinity://papers/temporal_phi", .name = "Time and the Golden Ratio", .description = "Research paper: temporal_phi.tex - Planck time, specious present", .mime_type = "text/plain" },
    .{ .uri = "trinity://papers/consciousness_trinity", .name = "Consciousness and TRINITY", .description = "Research paper: neural gamma, consciousness threshold", .mime_type = "text/plain" },
    .{ .uri = "trinity://papers/gravity_phi", .name = "Gravitational Constants from phi", .description = "Research paper: G, Omega_Lambda, Omega_DM from golden ratio", .mime_type = "text/plain" },
    .{ .uri = "trinity://papers/unified", .name = "Unified Framework", .description = "Research paper: complete TRINITY unified theory", .mime_type = "text/plain" },
    .{ .uri = "file://CLAUDE.md", .name = "CLI Documentation", .description = "Complete Trinity CLI command reference (280+ commands)", .mime_type = "text/markdown" },
    .{ .uri = "trinity://docs/architecture", .name = "Architecture Overview", .description = "Trinity system architecture documentation", .mime_type = "text/markdown" },
};

/// Generate JSON list of all available resources (MCP format)
pub fn generateResourcesList(allocator: std.mem.Allocator) ![]const u8 {
    var buf: std.ArrayList(u8) = .{};
    errdefer buf.deinit(allocator);

    try buf.appendSlice(allocator, "{\"resources\":[");

    for (resources, 0..) |r, i| {
        if (i > 0) try buf.appendSlice(allocator, ",");
        const writer = buf.writer(allocator);
        try writer.print(
            "{{\"uri\":\"{s}\",\"name\":\"{s}\",\"description\":\"{s}\",\"mimeType\":\"{s}\"}}",
            .{ r.uri, r.name, r.description, r.mime_type },
        );
    }

    try buf.appendSlice(allocator, "]}");
    return buf.toOwnedSlice(allocator);
}

/// Check if a resource URI exists
pub fn hasResource(uri: []const u8) bool {
    if (std.mem.startsWith(u8, uri, "trinity://constants/")) return true;
    if (std.mem.startsWith(u8, uri, "trinity://papers/")) return true;
    if (std.mem.startsWith(u8, uri, "trinity://docs/")) return true;
    if (std.mem.startsWith(u8, uri, "file://")) return true;
    return false;
}

/// Load and return resource content as JSON string
pub fn loadResource(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, uri, "trinity://constants/")) {
        return formatConstantsJson(allocator, uri);
    }
    if (std.mem.startsWith(u8, uri, "trinity://papers/")) {
        return loadPaper(allocator, uri);
    }
    if (std.mem.startsWith(u8, uri, "trinity://docs/")) {
        return loadDocs(allocator, uri);
    }
    if (std.mem.startsWith(u8, uri, "file://")) {
        return loadFile(allocator, uri[7..]);
    }
    return error.ResourceNotFound;
}

fn formatConstantsJson(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    const prefix = "trinity://constants/";
    const category = if (uri.len > prefix.len) uri[prefix.len..] else "all";

    if (std.mem.eql(u8, category, "all") or std.mem.eql(u8, category, "sacred")) {
        return std.fmt.allocPrint(allocator,
            \\{{"phi":{d},"phi_squared":{d},"phi_inverse":{d},"pi":{d},"e":{d},"trinity":"phi^2 + 1/phi^2 = 3"}}
        , .{ PHI, PHI * PHI, 1.0 / PHI, PI, E });
    }
    if (std.mem.eql(u8, category, "particle_physics")) {
        return allocator.dupe(u8,
            \\{"fine_structure":137.036,"proton_electron_mass":1836.152673,"electron_g_factor":2.002319}
        );
    }
    if (std.mem.eql(u8, category, "cosmology")) {
        return allocator.dupe(u8,
            \\{"cosmological_constant_omega_lambda":0.69,"dark_matter_omega_dm":0.26,"hubble_constant_h0":70.0}
        );
    }
    return error.ResourceNotFound;
}

fn loadPaper(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    const prefix = "trinity://papers/";
    const topic = if (uri.len > prefix.len) uri[prefix.len..] else return error.ResourceNotFound;

    const rel_path = if (std.mem.eql(u8, topic, "temporal_phi"))
        "docs/papers/TEMPORAL_PHI.tex"
    else if (std.mem.eql(u8, topic, "consciousness_trinity"))
        "docs/papers/CONSCIOUSNESS_TRINITY.tex"
    else if (std.mem.eql(u8, topic, "gravity_phi"))
        "docs/papers/GRAVITY_PHI.tex"
    else if (std.mem.eql(u8, topic, "unified"))
        "docs/papers/TRINITY_UNIFIED.tex"
    else
        return error.ResourceNotFound;

    return std.fs.cwd().readFileAlloc(allocator, rel_path, 1_000_000) catch {
        return std.fmt.allocPrint(allocator, "Paper not found: {s}", .{topic});
    };
}

fn loadDocs(allocator: std.mem.Allocator, uri: []const u8) ![]const u8 {
    const prefix = "trinity://docs/";
    const page = if (uri.len > prefix.len) uri[prefix.len..] else return error.ResourceNotFound;

    const rel_path = if (std.mem.eql(u8, page, "architecture"))
        "docsite/docs/architecture/overview.md"
    else if (std.mem.eql(u8, page, "api"))
        "docsite/docs/api/index.md"
    else if (std.mem.eql(u8, page, "sacred"))
        "docsite/docs/research/index.md"
    else
        return error.ResourceNotFound;

    return std.fs.cwd().readFileAlloc(allocator, rel_path, 100_000) catch {
        return std.fmt.allocPrint(allocator, "Documentation not found: {s}", .{page});
    };
}

fn loadFile(allocator: std.mem.Allocator, file_path: []const u8) ![]const u8 {
    return std.fs.cwd().readFileAlloc(allocator, file_path, 1_000_000) catch {
        return std.fmt.allocPrint(allocator, "File not found: {s}", .{file_path});
    };
}
