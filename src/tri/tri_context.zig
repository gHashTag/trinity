// =============================================================================
// TRI CONTEXT - Codebase Context System (Cycle 92)
// =============================================================================
//
// Self-contained ContextManager for repository-wide code search.
// Pattern-based symbol extraction + character n-gram embeddings +
// linear cosine similarity search + sacred phi-scoring.
//
// Commands: tri analyze | tri search <query> | tri context
//
// Sacred Formula: V = n * 3^k * pi^m * phi^p * e^q
// Golden Identity: phi^2 + 1/phi^2 = 3
// =============================================================================

const std = @import("std");
const colors = @import("tri_colors.zig");

// Sacred constants
const PHI: f64 = 1.618033988749895;
const PHI_SQ: f64 = 2.618033988749895;
const PHI_INV_SQ: f64 = 0.381966011250105;

const gematria_engine = @import("gematria.zig");
const sacred_formula = @import("math/sacred_formula.zig");

// Sacred constants for recognition (42 constants from sacred_formula.zig)
pub const SACRED_CONSTANTS = sacred_formula.sacred_constants;

// Embedding dimensions
const EMBEDDING_DIM: usize = 384;
const MAX_SNIPPET_LEN: usize = 256;
const MAX_SYMBOLS: usize = 50000;

// Symbol kinds
const SymbolKind = enum(u8) {
    function = 0,
    structure = 1,
    enumeration = 2,
    constant = 3,
    test_case = 4,
    import = 5,
};

// Sacred Analysis structures
pub const SacredSymbolAnalysis = struct {
    name: []const u8,
    gematria_value: u32,
    gematria_glyphs: []const u8,
    formula_fit: ?sacred_formula.SacredFormulaFit,
    formula_string: []const u8,
    recognized_constant: ?[]const u8,
};

/// Matched sacred constant result
pub const ConstantMatch = struct {
    constant_name: []const u8,
    target_value: f64,
    actual_value: f64,
    error_pct: f64,
};

pub const SacredConstant = struct {
    value: f64,
    name: []const u8,
    symbol: []const u8,
    tolerance_pct: f64,
};

pub const SacredSymbolEntry = struct {
    symbol_name: []const u8,
    gematria_value: i64,
    glyphs: []const u8,
};

// Indexed symbol
pub const IndexedSymbol = struct {
    name: []const u8,
    file_path: []const u8,
    line: u32,
    kind: SymbolKind,
    snippet: []const u8,
};

// Search result
pub const SearchHit = struct {
    symbol_idx: usize,
    score: f64,
    sacred_score: f64,
};

pub const CodebaseIntelligence = struct {
    total_symbols: usize,
    sacred_symbols: usize,
    sacred_constants_found: []const ConstantMatch,
};

// Context statistics
pub const ContextStats = struct {
    files_indexed: u32,
    symbols_indexed: u32,
    index_size_bytes: u64,
    last_scan_ms: i64,
    is_loaded: bool,
};

// ContextManager
pub const ContextManager = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    symbols: std.ArrayListUnmanaged(IndexedSymbol),
    embeddings: std.ArrayListUnmanaged([EMBEDDING_DIM]f32),
    stats: ContextStats,
    is_dirty: bool,

    const Self = @This();
    const INDEX_PATH = ".trinity-nexus/.context_index";
    const TCTX_MAGIC = [4]u8{ 'T', 'C', 'T', 'X' };

    // Directories to exclude from scanning
    const EXCLUDED_DIRS = [_][]const u8{
        "zig-out",
        ".zig-cache",
        "zig-cache",
        ".git",
        "node_modules",
        "trinity-nexus/output",
        "target",
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .symbols = .{},
            .embeddings = .{},
            .stats = .{
                .files_indexed = 0,
                .symbols_indexed = 0,
                .index_size_bytes = 0,
                .last_scan_ms = 0,
                .is_loaded = false,
            },
            .is_dirty = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.symbols.deinit(self.allocator);
        self.embeddings.deinit(self.allocator);
        self.arena.deinit();
    }

    // =========================================================================
    // SCAN REPOSITORY
    // =========================================================================

    pub fn scanRepository(self: *Self) !void {
        const timer = std.time.milliTimestamp();

        // Clear existing data
        self.symbols.clearRetainingCapacity();
        self.embeddings.clearRetainingCapacity();
        _ = self.arena.reset(.retain_capacity);
        self.stats.files_indexed = 0;

        // Walk current directory
        var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch return;
        defer dir.close();
        try self.walkDirectory(dir, ".");

        self.stats.symbols_indexed = @intCast(self.symbols.items.len);
        self.stats.last_scan_ms = std.time.milliTimestamp() - timer;
        self.stats.is_loaded = true;
        self.is_dirty = true;
    }

    fn walkDirectory(self: *Self, parent: std.fs.Dir, prefix: []const u8) !void {
        var iter = parent.iterate();
        while (try iter.next()) |entry| {
            // Build full path
            const full_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ prefix, entry.name });

            if (entry.kind == .directory) {
                // Skip excluded directories
                if (isExcludedDir(entry.name)) continue;

                var subdir = parent.openDir(entry.name, .{ .iterate = true }) catch continue;
                defer subdir.close();
                try self.walkDirectory(subdir, full_path);
            } else if (entry.kind == .file) {
                // Process .zig and .vibee files
                if (std.mem.endsWith(u8, entry.name, ".zig") or
                    std.mem.endsWith(u8, entry.name, ".vibee"))
                {
                    self.indexFile(parent, entry.name, full_path) catch continue;
                }
            }
        }
    }

    fn isExcludedDir(name: []const u8) bool {
        for (EXCLUDED_DIRS) |excluded| {
            if (std.mem.eql(u8, name, excluded)) return true;
        }
        return false;
    }

    fn indexFile(self: *Self, dir: std.fs.Dir, name: []const u8, full_path: []const u8) !void {
        const file = dir.openFile(name, .{}) catch return;
        defer file.close();

        // Read up to 256KB per file
        const content = file.readToEndAllocOptions(self.arena.allocator(), 256 * 1024, null, .@"1", null) catch return;

        self.stats.files_indexed += 1;

        // Extract symbols line-by-line
        var line_num: u32 = 1;
        var line_start: usize = 0;
        for (content, 0..) |c, i| {
            if (c == '\n' or i == content.len - 1) {
                const line = content[line_start..i];
                self.extractSymbolFromLine(line, full_path, line_num) catch {};
                line_start = i + 1;
                line_num += 1;
            }
        }
    }

    fn extractSymbolFromLine(self: *Self, line: []const u8, path: []const u8, line_num: u32) !void {
        if (self.symbols.items.len >= MAX_SYMBOLS) return;

        const trimmed = std.mem.trim(u8, line, " \t");

        // Pattern: pub fn name(
        if (std.mem.startsWith(u8, trimmed, "pub fn ") or std.mem.startsWith(u8, trimmed, "fn ")) {
            const offset: usize = if (std.mem.startsWith(u8, trimmed, "pub fn ")) 7 else 3;
            const rest = trimmed[offset..];
            if (std.mem.indexOf(u8, rest, "(")) |paren| {
                const name = rest[0..paren];
                if (name.len > 0 and name.len < 128) {
                    try self.addSymbol(name, path, line_num, .function, trimmed);
                }
            }
        }
        // Pattern: pub const Name = struct {
        else if (std.mem.startsWith(u8, trimmed, "pub const ") or std.mem.startsWith(u8, trimmed, "const ")) {
            const offset: usize = if (std.mem.startsWith(u8, trimmed, "pub const ")) 10 else 6;
            const rest = trimmed[offset..];
            if (std.mem.indexOf(u8, rest, " = struct")) |_| {
                if (std.mem.indexOf(u8, rest, " ")) |space| {
                    const name = rest[0..space];
                    if (name.len > 0 and name.len < 128) {
                        try self.addSymbol(name, path, line_num, .structure, trimmed);
                    }
                }
            } else if (std.mem.indexOf(u8, rest, " = enum")) |_| {
                if (std.mem.indexOf(u8, rest, " ")) |space| {
                    const name = rest[0..space];
                    if (name.len > 0 and name.len < 128) {
                        try self.addSymbol(name, path, line_num, .enumeration, trimmed);
                    }
                }
            }
        }
        // Pattern: test "name" {
        else if (std.mem.startsWith(u8, trimmed, "test \"")) {
            if (std.mem.indexOf(u8, trimmed[5..], "\"")) |end| {
                const name = trimmed[5..][0 .. end + 1];
                if (name.len > 0 and name.len < 128) {
                    try self.addSymbol(name, path, line_num, .test_case, trimmed);
                }
            }
        }
    }

    fn addSymbol(self: *Self, name: []const u8, path: []const u8, line_num: u32, kind: SymbolKind, snippet: []const u8) !void {
        // Copy strings to arena
        const arena = self.arena.allocator();
        const name_copy = try arena.dupe(u8, name);
        const path_copy = try arena.dupe(u8, path);
        const snip_len = @min(snippet.len, MAX_SNIPPET_LEN);
        const snippet_copy = try arena.dupe(u8, snippet[0..snip_len]);

        try self.symbols.append(self.allocator, .{
            .name = name_copy,
            .file_path = path_copy,
            .line = line_num,
            .kind = kind,
            .snippet = snippet_copy,
        });

        // Generate embedding for this symbol
        var emb: [EMBEDDING_DIM]f32 = undefined;
        generateEmbedding(name, snippet, &emb);
        try self.embeddings.append(self.allocator, emb);
    }

    // =========================================================================
    // SEARCH
    // =========================================================================

    pub fn search(self: *Self, query: []const u8, top_k: usize, results_buf: []SearchHit) usize {
        if (self.symbols.items.len == 0) return 0;

        // Generate query embedding
        var query_emb: [EMBEDDING_DIM]f32 = undefined;
        generateEmbedding(query, query, &query_emb);

        const k = @min(top_k, @min(results_buf.len, self.symbols.items.len));

        // Linear scan with top-k tracking (insertion sort into results_buf)
        var count: usize = 0;
        for (self.embeddings.items, 0..) |*emb, idx| {
            const sim = cosineSimilarity(&query_emb, emb);
            const name_match = nameMatchScore(query, self.symbols.items[idx].name);
            const sacred = sacredScore(sim, name_match, 0.5);

            // Insert into sorted results
            if (count < k) {
                // Still filling buffer — insert in sorted position
                var insert_pos: usize = count;
                while (insert_pos > 0 and results_buf[insert_pos - 1].sacred_score < sacred) : (insert_pos -= 1) {}
                // Shift down
                var j: usize = count;
                while (j > insert_pos) : (j -= 1) {
                    results_buf[j] = results_buf[j - 1];
                }
                results_buf[insert_pos] = .{
                    .symbol_idx = idx,
                    .score = sim,
                    .sacred_score = sacred,
                };
                count += 1;
            } else if (sacred > results_buf[count - 1].sacred_score) {
                // Better than worst result — replace and re-sort
                results_buf[count - 1] = .{
                    .symbol_idx = idx,
                    .score = sim,
                    .sacred_score = sacred,
                };
                // Bubble up
                var j: usize = count - 1;
                while (j > 0 and results_buf[j].sacred_score > results_buf[j - 1].sacred_score) : (j -= 1) {
                    const tmp = results_buf[j];
                    results_buf[j] = results_buf[j - 1];
                    results_buf[j - 1] = tmp;
                }
            }
        }

        return count;
    }

    // =========================================================================
    // CONTEXT FOR PROMPT (auto-inject into SWE commands)
    // =========================================================================

    pub fn getContextForPrompt(self: *Self, prompt: []const u8) ?[]u8 {
        if (self.symbols.items.len == 0) return null;

        var hits_buf: [5]SearchHit = undefined;
        const hit_count = self.search(prompt, 5, &hits_buf);
        if (hit_count == 0) return null;

        // Format context header
        var buf: [8192]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        writer.writeAll("// === CODEBASE CONTEXT (auto-retrieved) ===\n") catch return null;
        writer.writeAll("// Relevant code from repository:\n") catch return null;

        // === SACRED ANALYSIS ===
        for (hits_buf[0..hit_count]) |hit| {
            const sym = self.symbols.items[hit.symbol_idx];
            const analysis = self.analyzeSacredSymbol(sym.name);
            if (analysis) |sacred| {
                std.fmt.format(writer, "//   {s}: gematria={d}\n", .{ sym.name, sacred.gematria_value }) catch {};
                if (sacred.recognized_constant) |rc| {
                    std.fmt.format(writer, "//   {s}: recognized as {s}\n", .{ sym.name, rc }) catch {};
                }
            }
            std.fmt.format(writer, "//   {s}\n", .{sym.snippet}) catch break;
        }

        writer.writeAll("// === END CONTEXT ===\n\n") catch return null;

        const written = fbs.getWritten();
        const result = self.allocator.alloc(u8, written.len) catch return null;
        @memcpy(result, written);
        return result;
    }

    // =========================================================================
    // SACRED ANALYSIS FUNCTIONS (ContextManager methods)
    // =========================================================================

    /// Analyze a symbol name for sacred properties (gematria + formula)
    pub fn analyzeSacredSymbol(self: *Self, name: []const u8) ?SacredSymbolAnalysis {
        // Compute gematria value
        const gem_value = gematria_engine.textToGematriaValue(name);

        // Get formula fit if numeric
        var maybe_fit: ?sacred_formula.SacredFormulaFit = null;
        if (gem_value > 0) {
            const target: f64 = @floatFromInt(gem_value);
            maybe_fit = sacred_formula.fitSacredFormula(target);
        }

        // Format glyphs
        var glyphs_buf: [128]u8 = undefined;
        const glyphs = gematria_engine.numberToGlyphs(self.allocator, gem_value) catch {
            return SacredSymbolAnalysis{
                .name = name,
                .gematria_value = gem_value,
                .gematria_glyphs = "",
                .formula_fit = maybe_fit,
                .formula_string = "",
                .recognized_constant = null,
            };
        };
        defer self.allocator.free(glyphs);
        var glyph_len: usize = 0;
        for (glyphs) |g| {
            const src = g.glyph[0..g.glyph_len];
            @memcpy(glyphs_buf[glyph_len..][0..src.len], src);
            glyph_len += g.glyph_len;
        }

        // Format formula string (kept for sacred display)
        var formula_buf: [128]u8 = undefined;
        _ = if (maybe_fit) |sf|
            sacred_formula.formatFormulaString(&formula_buf, sf)
        else
            @as([]const u8, "none");

        // Check for constant recognition
        var recognized: ?[]const u8 = null;
        if (maybe_fit) |sf| {
            for (SACRED_CONSTANTS) |c| {
                if (c.target != 0) {
                    const err_pct = @abs(sf.computed - c.target) / @abs(c.target) * 100.0;
                    if (err_pct <= 1.0) {
                        recognized = c.name;
                        break;
                    }
                }
            }
        }

        return SacredSymbolAnalysis{
            .name = name,
            .gematria_value = gem_value,
            .gematria_glyphs = glyphs_buf[0..glyph_len],
            .formula_fit = maybe_fit,
            .formula_string = "",
            .recognized_constant = recognized,
        };
    }

    /// Recognize a value as sacred constant (returns name or null)
    pub fn recognizeSacredConstant(value: f64) ?[]const u8 {
        for (SACRED_CONSTANTS) |c| {
            if (c.target != 0) {
                const err_pct = @abs(c.target - value) / @abs(c.target) * 100.0;
                if (err_pct <= 1.0) {
                    return c.name;
                }
            }
        }
        return null;
    }

    // =========================================================================
    // STATS
    // =========================================================================

    pub fn showStats(self: *Self) void {
        std.debug.print("\n{s}=== Codebase Context Index ==={s}\n", .{ colors.GOLDEN, colors.RESET });
        std.debug.print("  Files indexed:   {d}\n", .{self.stats.files_indexed});
        std.debug.print("  Symbols indexed: {d}\n", .{self.stats.symbols_indexed});
        std.debug.print("  Index size:      {d} bytes\n", .{self.stats.index_size_bytes});
        std.debug.print("  Last scan:       {d}ms\n", .{self.stats.last_scan_ms});
        std.debug.print("  Status:          {s}\n", .{if (self.stats.is_loaded) "LOADED" else "NOT LOADED"});

        if (self.symbols.items.len > 0) {
            // Count by kind
            var fn_count: u32 = 0;
            var struct_count: u32 = 0;
            var enum_count: u32 = 0;
            var test_count: u32 = 0;
            var const_count: u32 = 0;
            for (self.symbols.items) |sym| {
                switch (sym.kind) {
                    .function => fn_count += 1,
                    .structure => struct_count += 1,
                    .enumeration => enum_count += 1,
                    .test_case => test_count += 1,
                    .constant => const_count += 1,
                    .import => {},
                }
            }
            std.debug.print("\n  {s}Symbol Breakdown:{s}\n", .{ colors.CYAN, colors.RESET });
            std.debug.print("    Functions:  {d}\n", .{fn_count});
            std.debug.print("    Structs:    {d}\n", .{struct_count});
            std.debug.print("    Enums:      {d}\n", .{enum_count});
            std.debug.print("    Tests:      {d}\n", .{test_count});
            std.debug.print("    Constants:  {d}\n", .{const_count});
        }

        std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });
    }

    // =========================================================================
    // PERSISTENCE (TCTX binary format)
    // =========================================================================

    pub fn saveIndex(self: *Self) !void {
        // Ensure directory exists
        std.fs.cwd().makePath(".trinity-nexus") catch {};

        const file = try std.fs.cwd().createFile(INDEX_PATH, .{});
        defer file.close();

        // Build index in memory, then write at once
        var buf = std.ArrayListUnmanaged(u8){};
        defer buf.deinit(self.allocator);

        // Header (32 bytes)
        try buf.appendSlice(self.allocator, &TCTX_MAGIC);
        try buf.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, 1))); // version
        try buf.appendSlice(self.allocator, &std.mem.toBytes(@as(u32, @intCast(self.symbols.items.len))));
        try buf.appendSlice(self.allocator, &std.mem.toBytes(self.stats.files_indexed));
        try buf.appendSlice(self.allocator, &std.mem.toBytes(self.stats.last_scan_ms));
        try buf.appendNTimes(self.allocator, 0, 8); // padding

        // Symbol entries
        for (self.symbols.items, 0..) |sym, idx| {
            // Name
            try buf.appendSlice(self.allocator, &std.mem.toBytes(@as(u16, @intCast(sym.name.len))));
            try buf.appendSlice(self.allocator, sym.name);
            // Path
            try buf.appendSlice(self.allocator, &std.mem.toBytes(@as(u16, @intCast(sym.file_path.len))));
            try buf.appendSlice(self.allocator, sym.file_path);
            // Line + kind
            try buf.appendSlice(self.allocator, &std.mem.toBytes(sym.line));
            try buf.append(self.allocator, @intFromEnum(sym.kind));
            // Snippet
            try buf.appendSlice(self.allocator, &std.mem.toBytes(@as(u16, @intCast(sym.snippet.len))));
            try buf.appendSlice(self.allocator, sym.snippet);
            // Embedding (384 * 4 = 1536 bytes)
            const emb = &self.embeddings.items[idx];
            try buf.appendSlice(self.allocator, std.mem.sliceAsBytes(emb));
        }

        // Write all at once
        try file.writeAll(buf.items);

        self.stats.index_size_bytes = buf.items.len;
        self.is_dirty = false;
    }

    pub fn loadIndex(self: *Self) !void {
        const file = std.fs.cwd().openFile(INDEX_PATH, .{}) catch return;
        defer file.close();

        // Read entire file into memory for parsing
        const content = file.readToEndAllocOptions(self.allocator, 128 * 1024 * 1024, null, .@"1", null) catch return;
        defer self.allocator.free(content);

        if (content.len < 32) return; // Too small for header

        // Verify magic
        if (!std.mem.eql(u8, content[0..4], &TCTX_MAGIC)) return;

        var pos: usize = 4;
        const version = std.mem.readInt(u32, content[pos..][0..4], .little);
        pos += 4;
        if (version != 1) return;

        const symbol_count = std.mem.readInt(u32, content[pos..][0..4], .little);
        pos += 4;
        const files_indexed = std.mem.readInt(u32, content[pos..][0..4], .little);
        pos += 4;
        const last_scan_ms = std.mem.readInt(i64, content[pos..][0..8], .little);
        pos += 8;
        pos += 8; // padding

        // Read symbols
        self.symbols.clearRetainingCapacity();
        self.embeddings.clearRetainingCapacity();
        _ = self.arena.reset(.retain_capacity);
        const arena = self.arena.allocator();

        var i: u32 = 0;
        while (i < symbol_count) : (i += 1) {
            if (pos + 2 > content.len) break;
            // Name
            const name_len = std.mem.readInt(u16, content[pos..][0..2], .little);
            pos += 2;
            if (pos + name_len > content.len) break;
            const name = try arena.dupe(u8, content[pos..][0..name_len]);
            pos += name_len;
            // Path
            if (pos + 2 > content.len) break;
            const path_len = std.mem.readInt(u16, content[pos..][0..2], .little);
            pos += 2;
            if (pos + path_len > content.len) break;
            const path = try arena.dupe(u8, content[pos..][0..path_len]);
            pos += path_len;
            // Line + kind
            if (pos + 5 > content.len) break;
            const line = std.mem.readInt(u32, content[pos..][0..4], .little);
            pos += 4;
            const kind: SymbolKind = @enumFromInt(content[pos]);
            pos += 1;
            // Snippet
            if (pos + 2 > content.len) break;
            const snip_len = std.mem.readInt(u16, content[pos..][0..2], .little);
            pos += 2;
            if (pos + snip_len > content.len) break;
            const snippet = try arena.dupe(u8, content[pos..][0..snip_len]);
            pos += snip_len;
            // Embedding (384 * 4 = 1536 bytes)
            if (pos + EMBEDDING_DIM * 4 > content.len) break;
            var emb: [EMBEDDING_DIM]f32 = undefined;
            @memcpy(std.mem.sliceAsBytes(&emb), content[pos..][0 .. EMBEDDING_DIM * 4]);
            pos += EMBEDDING_DIM * 4;

            try self.symbols.append(self.allocator, .{
                .name = name,
                .file_path = path,
                .line = line,
                .kind = kind,
                .snippet = snippet,
            });
            try self.embeddings.append(self.allocator, emb);
        }

        self.stats = .{
            .files_indexed = files_indexed,
            .symbols_indexed = symbol_count,
            .index_size_bytes = content.len,
            .last_scan_ms = last_scan_ms,
            .is_loaded = true,
        };
    }
};

// =============================================================================
// EMBEDDING GENERATION (character n-gram, 384-dim)
// Replicates src/tvc/embeddings.zig:241-275
// =============================================================================

fn generateEmbedding(name: []const u8, text: []const u8, output: *[EMBEDDING_DIM]f32) void {
    @memset(output, 0.0);

    var ngram_count: f32 = 0.0;

    // Unigrams from name (weighted higher)
    for (name) |c| {
        const idx = @as(usize, @intCast(c)) % EMBEDDING_DIM;
        output[idx] += 2.0; // name chars weighted 2x
        ngram_count += 2.0;
    }

    // Unigrams from text
    for (text) |c| {
        const idx = @as(usize, @intCast(c)) % EMBEDDING_DIM;
        output[idx] += 1.0;
        ngram_count += 1.0;
    }

    // Bigrams from text
    if (text.len >= 2) {
        for (0..text.len - 1) |i| {
            const bigram_val = @as(u16, @intCast(text[i])) *% 256 +% @as(u16, @intCast(text[i + 1]));
            const idx = @as(usize, @intCast(bigram_val)) % EMBEDDING_DIM;
            output[idx] += 0.5;
            ngram_count += 0.5;
        }
    }

    // L2 normalize
    var norm: f32 = 0.0;
    for (output) |v| {
        norm += v * v;
    }
    if (norm > 0.0) {
        const inv_norm = 1.0 / @sqrt(norm);
        for (output) |*v| {
            v.* *= inv_norm;
        }
    }
}

fn cosineSimilarity(a: *const [EMBEDDING_DIM]f32, b: *const [EMBEDDING_DIM]f32) f64 {
    var dot: f64 = 0.0;
    var norm_a: f64 = 0.0;
    var norm_b: f64 = 0.0;
    for (a, b) |av, bv| {
        dot += @as(f64, av) * @as(f64, bv);
        norm_a += @as(f64, av) * @as(f64, av);
        norm_b += @as(f64, bv) * @as(f64, bv);
    }
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom < 1e-10) return 0.0;
    return dot / denom;
}

fn nameMatchScore(query: []const u8, name: []const u8) f64 {
    // Simple substring match scoring
    if (std.mem.eql(u8, query, name)) return 1.0;

    // Case-insensitive contains check
    var query_lower: [256]u8 = undefined;
    var name_lower: [256]u8 = undefined;
    const ql = @min(query.len, 256);
    const nl = @min(name.len, 256);
    for (query[0..ql], 0..) |c, i| query_lower[i] = std.ascii.toLower(c);
    for (name[0..nl], 0..) |c, i| name_lower[i] = std.ascii.toLower(c);

    if (std.mem.indexOf(u8, name_lower[0..nl], query_lower[0..ql]) != null) return 0.8;
    if (std.mem.indexOf(u8, query_lower[0..ql], name_lower[0..nl]) != null) return 0.6;

    // Prefix match
    const min_len = @min(ql, nl);
    var prefix_match: usize = 0;
    for (0..min_len) |i| {
        if (query_lower[i] == name_lower[i]) {
            prefix_match += 1;
        } else break;
    }
    if (prefix_match > 0) {
        return @as(f64, @floatFromInt(prefix_match)) / @as(f64, @floatFromInt(@max(ql, nl))) * 0.5;
    }

    return 0.0;
}

fn sacredScore(similarity: f64, name_match: f64, recency: f64) f64 {
    // phi-weighted scoring: semantic 60% + name 30% + recency 10%
    const base = similarity * 0.6 + name_match * 0.3 + recency * 0.1;
    return base * PHI_SQ + (similarity * name_match) * PHI_INV_SQ;
}

// =============================================================================
// CLI COMMAND HANDLERS
// =============================================================================

pub fn runAnalyzeCommand(state: anytype) void {
    std.debug.print("\n{s}=== TRI ANALYZE — Scanning Repository ==={s}\n\n", .{ colors.GOLDEN, colors.RESET });

    if (state.context_mgr) |mgr| {
        mgr.scanRepository() catch |err| {
            std.debug.print("{s}Scan error: {}{s}\n", .{ colors.RED, err, colors.RESET });
            return;
        };

        std.debug.print("{s}Scan complete!{s}\n", .{ colors.GREEN, colors.RESET });
        std.debug.print("  Files:   {d}\n", .{mgr.stats.files_indexed});
        std.debug.print("  Symbols: {d}\n", .{mgr.stats.symbols_indexed});
        std.debug.print("  Time:    {d}ms\n", .{mgr.stats.last_scan_ms});

        // Auto-save
        mgr.saveIndex() catch |err| {
            std.debug.print("{s}Save error: {}{s}\n", .{ colors.RED, err, colors.RESET });
            return;
        };
        std.debug.print("  Index saved to: {s}\n", .{ContextManager.INDEX_PATH});
        std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });
    } else {
        std.debug.print("{s}Context manager not initialized.{s}\n", .{ colors.RED, colors.RESET });
    }
}

pub fn runSearchCommand(state: anytype, args: []const []const u8) void {
    if (args.len < 1) {
        std.debug.print("{s}Usage: tri search <query>{s}\n", .{ colors.RED, colors.RESET });
        return;
    }

    // Join args into query
    var query_buf: [512]u8 = undefined;
    var pos: usize = 0;
    for (args, 0..) |arg, i| {
        if (i > 0 and pos < query_buf.len) {
            query_buf[pos] = ' ';
            pos += 1;
        }
        const copy_len = @min(arg.len, query_buf.len - pos);
        @memcpy(query_buf[pos..][0..copy_len], arg[0..copy_len]);
        pos += copy_len;
    }
    const query = query_buf[0..pos];

    std.debug.print("\n{s}=== TRI SEARCH: \"{s}\" ==={s}\n\n", .{ colors.GOLDEN, query, colors.RESET });

    if (state.context_mgr) |mgr| {
        if (mgr.symbols.items.len == 0) {
            std.debug.print("{s}No index loaded. Run 'tri analyze' first.{s}\n", .{ colors.RED, colors.RESET });
            return;
        }

        var hits: [10]SearchHit = undefined;
        const count = mgr.search(query, 10, &hits);

        if (count == 0) {
            std.debug.print("No results found.\n", .{});
            return;
        }

        std.debug.print("Found {d} results:\n\n", .{count});
        for (hits[0..count], 0..) |hit, i| {
            const sym = mgr.symbols.items[hit.symbol_idx];
            std.debug.print("  {d}. [{s}] {s}{s}{s}:{d}  (score: {d:.3})\n", .{
                i + 1,
                @tagName(sym.kind),
                colors.CYAN,
                sym.file_path,
                colors.RESET,
                sym.line,
                hit.sacred_score,
            });
            std.debug.print("     {s}{s}{s}\n", .{ colors.GREEN, sym.name, colors.RESET });
            std.debug.print("     {s}{s}{s}\n\n", .{ colors.GRAY, sym.snippet, colors.RESET });
        }

        std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });
    } else {
        std.debug.print("{s}Context manager not initialized.{s}\n", .{ colors.RED, colors.RESET });
    }
}

pub fn runContextInfoCommand(state: anytype) void {
    if (state.context_mgr) |mgr| {
        mgr.showStats();
    } else {
        std.debug.print("{s}Context manager not initialized.{s}\n", .{ colors.RED, colors.RESET });
    }
}

/// Run sacred intelligence analysis on codebase
pub fn runIntelligenceCommand(allocator_: std.mem.Allocator, state: anytype, args: []const []const u8) !void {
    _ = allocator_;
    std.debug.print("\n{s}=== SACRED INTELLIGENCE ANALYSIS ==={s}\n", .{ colors.GOLDEN, colors.RESET });
    std.debug.print("{s}V = n × 3^k × π^m × φ^p × e^q{s}\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });

    if (state.context_mgr) |mgr| {
        if (mgr.symbols.items.len == 0) {
            std.debug.print("{s}No index loaded. Run 'tri analyze' first.{s}\n", .{ colors.RED, colors.RESET });
            return;
        }

        // Parse optional query or symbol name
        const query = if (args.len > 0 and !std.mem.eql(u8, args[0], "--help"))
            args[0]
        else
            null;

        if (query) |q| {
            // Targeted symbol analysis
            std.debug.print("{s}Analyzing symbol: {s}{s}\n\n", .{ colors.CYAN, q, colors.RESET });

            const analysis = mgr.analyzeSacredSymbol(q);
            if (analysis) |sacred| {
                // Print gematria value
                std.debug.print("  {s}Symbol:{s}      {s}{s}{s}\n", .{ colors.GRAY, colors.RESET, colors.WHITE, sacred.name, colors.RESET });
                std.debug.print("  {s}Gematria Value:{s} {s}{d}{s}\n", .{ colors.GRAY, colors.RESET, colors.GOLDEN, sacred.gematria_value, colors.RESET });

                // Print glyphs
                if (sacred.gematria_glyphs.len > 0) {
                    std.debug.print("  {s}Coptic Glyphs:{s} {s}\n", .{ colors.GRAY, colors.RESET, sacred.gematria_glyphs });
                } else {
                    std.debug.print("  {s}Coptic Glyphs:{s} {s}none (no Coptic chars){s}\n", .{ colors.GRAY, colors.RESET, colors.GRAY, colors.RESET });
                }

                // Print formula fit
                if (sacred.formula_fit) |fit| {
                    var formula_buf: [128]u8 = undefined;
                    const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);
                    std.debug.print("  {s}Formula Fit:{s}  {s}V = {s}{s}\n", .{ colors.GRAY, colors.RESET, colors.GOLDEN, formula_str, colors.RESET });
                    std.debug.print("  {s}Computed:{s}    {s}{d:.6}{s}\n", .{ colors.GRAY, colors.RESET, colors.WHITE, fit.computed, colors.RESET });
                    std.debug.print("  {s}Error:{s}        {s}{d:.4}%{s}\n", .{ colors.GRAY, colors.RESET, if (fit.error_pct < 1.0) colors.GREEN else if (fit.error_pct < 5.0) colors.CYAN else colors.RED, fit.error_pct, colors.RESET });
                    std.debug.print("  {s}Parameters:{s}    n={d} k={d} m={d} p={d} q={d}\n", .{
                        colors.GRAY, colors.RESET,
                        fit.n,       fit.k,        fit.m,
                        fit.p,       fit.q,
                    });
                } else {
                    std.debug.print("  {s}Formula Fit:{s}  {s}none (value=0){s}\n", .{ colors.GRAY, colors.RESET, colors.GRAY, colors.RESET });
                }

                // Print recognized constant
                if (sacred.recognized_constant) |rc| {
                    std.debug.print("  {s}Sacred Constant:{s} {s}{s}{s}\n", .{ colors.GRAY, colors.RESET, colors.GREEN, rc, colors.RESET });
                } else if (sacred.formula_fit != null) {
                    std.debug.print("  {s}Sacred Constant:{s} {s}none (no match in 75 constants){s}\n", .{ colors.GRAY, colors.RESET, colors.GRAY, colors.RESET });
                }

                // Check for special values
                if (sacred.gematria_value == 42) {
                    std.debug.print("\n  {s}>>> ANSWER TO EVERYTHING DETECTED <<<{s}\n", .{ colors.GREEN, colors.RESET });
                } else if (sacred.gematria_value == 137) {
                    std.debug.print("\n  {s}>>> FINE STRUCTURE INVERSE DETECTED <<<{s}\n", .{ colors.GREEN, colors.RESET });
                } else if (sacred.gematria_value == 3) {
                    std.debug.print("\n  {s}>>> TRINITY CONSTANT DETECTED <<<{s}\n", .{ colors.GREEN, colors.RESET });
                } else if (sacred.gematria_value == 7) {
                    std.debug.print("\n  {s}>>> PERFECT NUMBER DETECTED <<<{s}\n", .{ colors.GREEN, colors.RESET });
                }
            } else {
                std.debug.print("  {s}Error:{s} No analysis generated\n", .{ colors.RED, colors.RESET });
            }
        } else {
            // Codebase-wide intelligence report
            std.debug.print("{s}Codebase Intelligence Report{s}\n", .{ colors.CYAN, colors.RESET });
            std.debug.print("{s}══════════════════════════════{s}\n\n", .{ colors.GRAY, colors.RESET });

            std.debug.print("  {s}Total Symbols:{s}   {d}\n", .{ colors.GRAY, colors.RESET, mgr.symbols.items.len });
            std.debug.print("  {s}Index Files:{s}    {d}\n", .{ colors.GRAY, colors.RESET, mgr.stats.files_indexed });

            // Count symbols with non-zero gematria
            var sacred_count: u32 = 0;
            var total_gematria: u32 = 0;

            // Find top gematria values
            var top_symbols: [5]struct { name: []const u8, value: u32 } = undefined;
            var top_count: usize = 0;

            for (mgr.symbols.items) |sym| {
                const gem_value = gematria_engine.textToGematriaValue(sym.name);
                if (gem_value > 0) {
                    sacred_count += 1;
                    total_gematria += gem_value;

                    // Track top values
                    var min_idx: ?usize = null;
                    for (0..@min(top_count, 5)) |i| {
                        if (top_symbols[i].value < gem_value) {
                            min_idx = i;
                        }
                    }
                    if (min_idx) |idx| {
                        if (top_count < 5) {
                            top_symbols[top_count] = .{ .name = sym.name, .value = gem_value };
                            top_count += 1;
                        } else {
                            top_symbols[idx] = .{ .name = sym.name, .value = gem_value };
                        }
                    }
                }
            }

            const sacred_ratio = if (mgr.symbols.items.len > 0)
                @as(f64, @floatFromInt(sacred_count)) / @as(f64, @floatFromInt(mgr.symbols.items.len)) * 100.0
            else
                0.0;

            const avg_gematria = if (sacred_count > 0)
                @as(f64, @floatFromInt(total_gematria)) / @as(f64, @floatFromInt(sacred_count))
            else
                0.0;

            std.debug.print("\n  {s}Sacred Symbols:{s}  {d} / {d} ({d:.1}%)\n", .{
                colors.GOLDEN, colors.RESET, sacred_count, mgr.symbols.items.len, sacred_ratio,
            });
            std.debug.print("  {s}Avg Gematria:{s}    {d:.2}\n\n", .{ colors.GRAY, colors.RESET, avg_gematria });

            // Print top symbols
            std.debug.print("  {s}Top Gematria Values:{s}\n", .{ colors.CYAN, colors.RESET });
            for (0..top_count) |i| {
                const ts = top_symbols[i];
                const analysis = mgr.analyzeSacredSymbol(ts.name);
                std.debug.print("    {s}{d}{s}. {d} {s}{s}{s}\n", .{
                    colors.WHITE,
                    i + 1, colors.RESET,
                    ts.value,
                    colors.CYAN, ts.name, colors.RESET,
                });

                if (analysis) |sacred| {
                    if (sacred.recognized_constant) |rc| {
                        std.debug.print("      {s}({s}{s}{s})\n", .{
                            colors.GRAY, colors.GREEN, rc, colors.RESET,
                        });
                    }
                    if (sacred.formula_fit) |fit| {
                        var formula_buf: [128]u8 = undefined;
                        const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);
                        std.debug.print("      {s}{s}{s}\n", .{
                            colors.GRAY, formula_str, colors.RESET,
                        });
                    }
                }
            }
            if (top_count == 0) {
                std.debug.print("    {s}none (no sacred symbols found){s}\n", .{ colors.GRAY, colors.RESET });
            }

            std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });
        }

        if (args.len > 0 and std.mem.eql(u8, args[0], "--help")) {
            printIntelligenceHelp();
        }
    } else {
        std.debug.print("{s}Context manager not initialized.{s}\n", .{ colors.RED, colors.RESET });
    }
}

/// Print help for intelligence command
fn printIntelligenceHelp() void {
    std.debug.print("\n{s}SACRED INTELLIGENCE HELP{s}\n", .{ colors.GOLDEN, colors.RESET });
    std.debug.print("{s}Usage:{s}  tri intelligence [symbol-name|--help]\n\n", .{ colors.CYAN, colors.RESET });
    std.debug.print("  {s}symbol-name{s}  Analyze specific symbol for sacred properties\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("  {s}--help{s}       Show this help message\n\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("  {s}Analysis includes:{s}\n", .{ colors.CYAN, colors.RESET });
    std.debug.print("    {s}- Coptic gematria value{s}\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("    {s}- Coptic glyph decomposition{s}\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("    {s}- Sacred formula V = n x 3^k x pi^m x phi^p x e^q{s}\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("    {s}- Recognition against 75 sacred constants{s}\n\n", .{ colors.GRAY, colors.RESET });
    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });
}

// =============================================================================
// TESTS
// =============================================================================

test "generate_embedding_deterministic" {
    var emb1: [EMBEDDING_DIM]f32 = undefined;
    var emb2: [EMBEDDING_DIM]f32 = undefined;
    generateEmbedding("test", "pub fn test()", &emb1);
    generateEmbedding("test", "pub fn test()", &emb2);
    // Same input = same output
    for (emb1, emb2) |a, b| {
        try std.testing.expectApproxEqAbs(a, b, 1e-6);
    }
}

test "cosine_similarity_self" {
    var emb: [EMBEDDING_DIM]f32 = undefined;
    generateEmbedding("bind", "pub fn bind(a, b)", &emb);
    const sim = cosineSimilarity(&emb, &emb);
    try std.testing.expectApproxEqAbs(sim, 1.0, 1e-6);
}

test "cosine_similarity_different" {
    var emb1: [EMBEDDING_DIM]f32 = undefined;
    var emb2: [EMBEDDING_DIM]f32 = undefined;
    generateEmbedding("bind", "pub fn bind(a, b)", &emb1);
    generateEmbedding("process", "pub fn process(input)", &emb2);
    const sim = cosineSimilarity(&emb1, &emb2);
    // Different but not orthogonal (share common characters)
    try std.testing.expect(sim > 0.0 and sim < 1.0);
}

test "name_match_exact" {
    const score = nameMatchScore("bind", "bind");
    try std.testing.expectApproxEqAbs(score, 1.0, 1e-6);
}

test "sacred_score_formula" {
    const score = sacredScore(1.0, 1.0, 1.0);
    // base = 1.0*0.6 + 1.0*0.3 + 1.0*0.1 = 1.0
    // sacred = 1.0 * PHI_SQ + (1.0*1.0) * PHI_INV_SQ = 2.618 + 0.382 = 3.0
    try std.testing.expectApproxEqAbs(score, 3.0, 0.001);
}

test "context_manager_init_deinit" {
    var mgr = ContextManager.init(std.testing.allocator);
    defer mgr.deinit();
    try std.testing.expectEqual(mgr.stats.symbols_indexed, 0);
    try std.testing.expectEqual(mgr.stats.is_loaded, false);
}
