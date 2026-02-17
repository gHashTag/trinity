// ═══════════════════════════════════════════════════════════════════════════════
// WORLD DOCS — Embedded documentation for 27 Sacred World panels
// Each world maps to a docsite markdown file via @embedFile
// Markdown is rendered as plain text with runtime line-by-line filtering
// ═══════════════════════════════════════════════════════════════════════════════

pub const WorldDoc = struct {
    raw: []const u8, // Raw markdown content (comptime embedded)
    subtitle: []const u8, // Short description shown under header
};

// ═══════════════════════════════════════════════════════════════════════════════
// 27 EMBEDDED DOCS — one per sacred world
// ═══════════════════════════════════════════════════════════════════════════════

pub const WORLD_DOCS: [27]WorldDoc = .{
    // ── Realm 1: RAZUM (phi) — AI & Communication, blocks 0-8 ──
    .{ .raw = @embedFile("docs_embed/intro.md"), .subtitle = "Trinity AI Assistant" },
    .{ .raw = @embedFile("docs_embed/getting-started/quickstart.md"), .subtitle = "AI Code Generation" },
    .{ .raw = @embedFile("docs_embed/concepts/glossary.md"), .subtitle = "Code Explainer" },
    .{ .raw = @embedFile("docs_embed/api/vsa.md"), .subtitle = "Debug Assistant" },
    .{ .raw = @embedFile("docs_embed/concepts/balanced-ternary.md"), .subtitle = "Code Review" },
    .{ .raw = @embedFile("docs_embed/troubleshooting.md"), .subtitle = "Multi-Language Translation" },
    .{ .raw = @embedFile("docs_embed/vibee/specification.md"), .subtitle = "VIBEE Spec to Code" },
    .{ .raw = @embedFile("docs_embed/architecture/overview.md"), .subtitle = "Voice Input/Output" },
    .{ .raw = @embedFile("docs_embed/vibee/examples.md"), .subtitle = "Multi-Step Composer" },

    // ── Realm 2: MATERIYA (pi) — Tools & System, blocks 9-17 ──
    .{ .raw = @embedFile("docs_embed/benchmarks/index.md"), .subtitle = "File Browser" },
    .{ .raw = @embedFile("docs_embed/getting-started/installation.md"), .subtitle = "Code Editor" },
    .{ .raw = @embedFile("docs_embed/deployment/index.md"), .subtitle = "Build Runner" },
    .{ .raw = @embedFile("docs_embed/getting-started/development-setup.md"), .subtitle = "Test Runner" },
    .{ .raw = @embedFile("docs_embed/benchmarks/competitor-comparison.md"), .subtitle = "Terminal Shell" },
    .{ .raw = @embedFile("docs_embed/deployment/runpod.md"), .subtitle = "Git Version Control" },
    .{ .raw = @embedFile("docs_embed/vibee/theorems.md"), .subtitle = "Deployment Manager" },
    .{ .raw = @embedFile("docs_embed/benchmarks/gpu-inference.md"), .subtitle = "Network Admin — Distributed Nodes" },
    .{ .raw = @embedFile("docs_embed/benchmarks/memory-efficiency.md"), .subtitle = "App Settings" },

    // ── Realm 3: DUKH (e) — Content & Knowledge, blocks 18-26 ──
    .{ .raw = @embedFile("docs_embed/math-foundations/formulas.md"), .subtitle = "All Documentation" },
    .{ .raw = @embedFile("docs_embed/concepts/trinity-identity.md"), .subtitle = "Create Reels" },
    .{ .raw = @embedFile("docs_embed/api/hybrid.md"), .subtitle = "Content Feed" },
    .{ .raw = @embedFile("docs_embed/hdc/applications.md"), .subtitle = "Project Roadmap" },
    .{ .raw = @embedFile("docs_embed/hdc/igla-glove-comparison.md"), .subtitle = "Performance Benchmarks" },
    .{ .raw = @embedFile("docs_embed/research/bitnet-report.md"), .subtitle = "Research Reports" },
    .{ .raw = @embedFile("docs_embed/math-foundations/proofs.md"), .subtitle = "Sacred Formulas" },
    .{ .raw = @embedFile("docs_embed/overview/roadmap.md"), .subtitle = "Community Hub" },
    .{ .raw = @embedFile("docs_embed/overview/tech-tree.md"), .subtitle = "About Trinity" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// RUNTIME MARKDOWN LINE FILTER
// Determines if a line should be skipped during rendering
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if a line is markdown noise that should be skipped in the panel view.
/// Returns true if the line should be hidden.
pub fn isNoiseLine(line: []const u8) bool {
    const trimmed = trimLeft(line);
    if (trimmed.len == 0) return false; // keep blank lines (paragraph spacing)

    // YAML frontmatter delimiters
    if (trimmed.len >= 3 and trimmed[0] == '-' and trimmed[1] == '-' and trimmed[2] == '-') return true;

    // Code fence
    if (trimmed.len >= 3 and trimmed[0] == '`' and trimmed[1] == '`' and trimmed[2] == '`') return true;

    // HTML tags / Docusaurus admonitions
    if (trimmed[0] == '<') return true;
    if (trimmed.len >= 3 and trimmed[0] == ':' and trimmed[1] == ':' and trimmed[2] == ':') return true;

    // import statements (MDX)
    if (startsWith(trimmed, "import ")) return true;

    // Table separator lines (|---|---|)
    if (isTableSeparator(trimmed)) return true;

    // YAML frontmatter key-value lines (sidebar_position:, title:, etc.)
    // Only skip if it looks like "key: value" at start (no spaces before colon)
    if (looksLikeFrontmatter(trimmed)) return true;

    return false;
}

/// Strip heading markers (# ## ### etc.) and return just the text.
/// Returns the original line if not a heading.
pub fn stripHeading(line: []const u8) []const u8 {
    const trimmed = trimLeft(line);
    if (trimmed.len == 0) return line;
    if (trimmed[0] != '#') return line;

    var i: usize = 0;
    while (i < trimmed.len and trimmed[i] == '#') : (i += 1) {}
    // skip space after #
    if (i < trimmed.len and trimmed[i] == ' ') i += 1;
    return trimmed[i..];
}

// ═══════════════════════════════════════════════════════════════════════════════
// LINE ITERATOR — iterate over raw text line by line
// ═══════════════════════════════════════════════════════════════════════════════

pub const LineIterator = struct {
    data: []const u8,
    pos: usize,

    pub fn init(data: []const u8) LineIterator {
        return .{ .data = data, .pos = 0 };
    }

    pub fn next(self: *LineIterator) ?[]const u8 {
        if (self.pos >= self.data.len) return null;
        const start = self.pos;
        while (self.pos < self.data.len and self.data[self.pos] != '\n') {
            self.pos += 1;
        }
        const end = self.pos;
        if (self.pos < self.data.len) self.pos += 1; // skip \n
        return self.data[start..end];
    }
};

/// Count total visible lines (non-noise, after heading strip) for scroll calculation
pub fn countVisibleLines(raw: []const u8) u32 {
    var iter = LineIterator.init(raw);
    var count: u32 = 0;
    var in_frontmatter = false;
    while (iter.next()) |line| {
        const trimmed = trimLeft(line);
        // Track frontmatter block (between first two ---)
        if (trimmed.len >= 3 and trimmed[0] == '-' and trimmed[1] == '-' and trimmed[2] == '-') {
            in_frontmatter = !in_frontmatter;
            continue;
        }
        if (in_frontmatter) continue;
        if (isNoiseLine(line)) continue;
        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE MARKDOWN STRIPPING
// Removes **bold**, *italic*, `code`, [link](url), | table pipes
// ═══════════════════════════════════════════════════════════════════════════════

/// Strip inline markdown formatting from a line into a buffer.
/// Returns the number of bytes written.
pub fn stripInline(line: []const u8, out: []u8) usize {
    var i: usize = 0;
    var o: usize = 0;
    while (i < line.len and o < out.len - 1) {
        const c = line[i];

        // ** bold ** — skip the ** delimiters
        if (c == '*' and i + 1 < line.len and line[i + 1] == '*') {
            i += 2;
            continue;
        }
        // * italic * — skip single * when between word chars
        if (c == '*') {
            i += 1;
            continue;
        }
        // `` inline code `` — skip double backtick
        if (c == '`' and i + 1 < line.len and line[i + 1] == '`') {
            i += 2;
            continue;
        }
        // ` inline code ` — skip single backtick
        if (c == '`') {
            i += 1;
            continue;
        }
        // [link text](url) — keep link text, skip url
        if (c == '[') {
            i += 1;
            // Copy text until ]
            while (i < line.len and line[i] != ']' and o < out.len - 1) {
                out[o] = line[i];
                o += 1;
                i += 1;
            }
            if (i < line.len and line[i] == ']') i += 1;
            // Skip (url)
            if (i < line.len and line[i] == '(') {
                i += 1;
                while (i < line.len and line[i] != ')') : (i += 1) {}
                if (i < line.len) i += 1; // skip )
            }
            continue;
        }
        // | table separator — replace with space
        if (c == '|') {
            if (o > 0 and out[o - 1] != ' ') {
                out[o] = ' ';
                o += 1;
            }
            i += 1;
            // skip spaces after |
            while (i < line.len and line[i] == ' ') : (i += 1) {}
            continue;
        }
        // $$ LaTeX — skip
        if (c == '$') {
            i += 1;
            continue;
        }

        out[o] = c;
        o += 1;
        i += 1;
    }
    return o;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn trimLeft(s: []const u8) []const u8 {
    var i: usize = 0;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t')) : (i += 1) {}
    return s[i..];
}

fn startsWith(s: []const u8, prefix: []const u8) bool {
    if (s.len < prefix.len) return false;
    return std.mem.eql(u8, s[0..prefix.len], prefix);
}

fn isTableSeparator(line: []const u8) bool {
    // Lines like |---|---|---| or |:---|:---:|
    if (line.len < 3) return false;
    if (line[0] != '|') return false;
    for (line) |c| {
        if (c != '|' and c != '-' and c != ':' and c != ' ') return false;
    }
    return true;
}

fn looksLikeFrontmatter(line: []const u8) bool {
    // Lines like "sidebar_position: 1" or "title: Something"
    // Must have a colon before any space, and be short-ish
    if (line.len > 80) return false;
    for (line, 0..) |c, i| {
        if (c == ' ' or c == '\t') return false; // space before colon = not frontmatter
        if (c == ':') {
            // Must be followed by space or end
            if (i + 1 >= line.len or line[i + 1] == ' ') return true;
            return false;
        }
    }
    return false;
}

const std = @import("std");
