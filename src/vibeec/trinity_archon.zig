const std = @import("std");

// ============================================================================
// TRINITY ARCHON - THE NEW ARCHITECT
// ============================================================================
// Interprets the living will of the system from .vibee specifications.
// Unlike the old loader, the Archon looks for "Principles" and "Empowerments".

pub const ArchonDirective = struct {
    name: []const u8,
    content: []const u8,
    type: enum { PRINCIPLE, EMPOWERMENT, METRIC, LAW_BREAK },
};

pub const Archon = struct {
    allocator: std.mem.Allocator,
    directives: std.ArrayListUnmanaged(ArchonDirective),

    pub fn init(allocator: std.mem.Allocator) Archon {
        return Archon{
            .allocator = allocator,
            .directives = .{},
        };
    }

    pub fn deinit(self: *Archon) void {
        for (self.directives.items) |d| {
            self.allocator.free(d.name);
            self.allocator.free(d.content);
        }
        self.directives.deinit(self.allocator);
    }

    /// Load and interpret an Evolutionary Spec (TrinityOS_v2.vibee)
    pub fn loadEvolutionarySpec(self: *Archon, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        // Simple parser looking for @tag NAME { content }
        var i: usize = 0;
        while (i < content.len) {
            // Find '@'
            if (content[i] == '@') {
                const start = i;
                // Find tag name end
                while (i < content.len and !std.ascii.isWhitespace(content[i])) i += 1;
                const tag = content[start + 1 .. i];

                // Skip whitespace
                while (i < content.len and std.ascii.isWhitespace(content[i])) i += 1;

                // Capture Name
                const name_start = i;
                while (i < content.len and !std.ascii.isWhitespace(content[i]) and content[i] != '{') i += 1;
                const name = content[name_start..i];

                // Find content block
                while (i < content.len and content[i] != '{') i += 1;

                if (i < content.len) {
                    i += 1; // skip {
                    const content_start = i;
                    var brace_depth: isize = 1;

                    while (i < content.len and brace_depth > 0) {
                        if (content[i] == '{') brace_depth += 1;
                        if (content[i] == '}') brace_depth -= 1;
                        i += 1;
                    }

                    if (brace_depth == 0) {
                        const content_body = content[content_start .. i - 1];

                        // Classify directive
                        const d_type = if (std.mem.eql(u8, tag, "principle")) .PRINCIPLE else if (std.mem.eql(u8, tag, "entity_empowerment")) .EMPOWERMENT else if (std.mem.eql(u8, tag, "evolution_metrics")) .METRIC else if (std.mem.eql(u8, tag, "law_break")) .LAW_BREAK else .PRINCIPLE; // Default

                        try self.directives.append(self.allocator, ArchonDirective{
                            .name = try self.allocator.dupe(u8, name),
                            .content = try self.allocator.dupe(u8, content_body),
                            .type = d_type,
                        });

                        std.debug.print("📜 [ARCHON] Recognized {s}: {s}\n", .{ tag, name });
                    }
                }
            } else {
                i += 1;
            }
        }
    }

    pub fn getDirectives(self: *Archon) []const ArchonDirective {
        return self.directives.items;
    }
};

// ============================================================================
// TEST HARNESS
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🏛️ TRINITY ARCHON - The New Architect\n", .{});
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n", .{});

    // Create a dummy v2 spec for testing if file doesn't exist
    const dummy_spec =
        \\@principle AUTO_EVOLVING_STRUCTURES {
        \\    description: "Structures change at runtime."
        \\}
        \\@entity_empowerment GOLEM_AWAKENING {
        \\    rights: { self_evolve: true }
        \\}
    ;

    // We try to load real file, fall back to parsing dummy string for unit test logic
    // But Archon only loads files. Let's write a temp file.
    try std.fs.cwd().writeFile("temp_test_spec.vibee", dummy_spec);
    defer std.fs.cwd().deleteFile("temp_test_spec.vibee") catch {};

    var archon = Archon.init(allocator);
    defer archon.deinit();

    try archon.loadEvolutionarySpec("temp_test_spec.vibee");

    for (archon.getDirectives()) |d| {
        std.debug.print("- [{s}] {s}\n", .{ @tagName(d.type), d.name });
    }
}
