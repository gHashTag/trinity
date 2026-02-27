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
const sacred_formula = @import("math/sacred_formula.zig");

// Sacred constants
const PHI: f64 = 1.618033988749895;
const PHI_SQ: f64 = 2.618033988749895;
const PHI_INV_SQ: f64 = 0.381966011250105;

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

// Indexed symbol (Sacred Intelligence v3.6)
pub const IndexedSymbol = struct {
    name: []const u8,
    file_path: []const u8,
    line: u32,
    kind: SymbolKind,
    snippet: []const u8,
    // Sacred Intelligence fields
    sacred_gematria: ?u32,
    hebrew_gematria: ?u32,
    greek_gematria: ?u32,
    arabic_gematria: ?u32,
    sacred_formula: ?[]const u8,
    sacred_constant_match: ?[]const u8,
    patch_candidate: bool,
    confidence_score: f64,
};

// Search result
pub const SearchHit = struct {
    symbol_idx: usize,
    score: f64,
    sacred_score: f64,
};

// Context statistics
pub const ContextStats = struct {
    files_indexed: u32,
    symbols_indexed: u32,
    index_size_bytes: u64,
    last_scan_ms: i64,
    is_loaded: bool,
};

// Sacred Intelligence metrics
pub const SacredMetrics = struct {
    total_symbols_analyzed: u32,
    patch_candidates_found: u32,
    sacred_constant_matches: u32,
    avg_confidence_score: f64,
    top_sacred_symbols: u32,
    evolution_progress: f64, // 0.0 to 1.0
};

// Patch statistics
pub const PatchStats = struct {
    patches_applied: u32,
    patches_succeeded: u32,
    patches_failed: u32,
    avg_improvement_pct: f64,
};

// Multi-language gematria result
pub const MultiLanguageGematria = struct {
    sacred: u32,    // Coptic-based (27 glyphs)
    hebrew: u32,    // Hebrew alefbet
    greek: u32,     // Greek isopsephy
    arabic: u32,    // Abjad numerals
};

// ContextManager
pub const ContextManager = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    symbols: std.ArrayListUnmanaged(IndexedSymbol),
    embeddings: std.ArrayListUnmanaged([EMBEDDING_DIM]f32),
    stats: ContextStats,
    sacred_metrics: SacredMetrics,
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
            .sacred_metrics = .{
                .total_symbols_analyzed = 0,
                .patch_candidates_found = 0,
                .sacred_constant_matches = 0,
                .avg_confidence_score = 0.0,
                .top_sacred_symbols = 0,
                .evolution_progress = 0.0,
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

        // Compute sacred intelligence
        const multi_gem = computeMultiLanguageGematria(name);
        const sacred_fit = computeSacredFormulaForSymbol(name);
        const constant_match = findSacredConstantMatch(multi_gem.sacred);
        const confidence = computeSymbolSacredScoreImpl(multi_gem, sacred_fit, constant_match);

        // Format sacred formula string
        var formula_buf: [128]u8 = undefined;
        const formula_str = if (sacred_fit.error_pct < 10.0)
            try arena.dupe(u8, formatSacredFormula(&formula_buf, sacred_fit))
        else
            null;

        try self.symbols.append(self.allocator, .{
            .name = name_copy,
            .file_path = path_copy,
            .line = line_num,
            .kind = kind,
            .snippet = snippet_copy,
            .sacred_gematria = multi_gem.sacred,
            .hebrew_gematria = multi_gem.hebrew,
            .greek_gematria = multi_gem.greek,
            .arabic_gematria = multi_gem.arabic,
            .sacred_formula = formula_str,
            .sacred_constant_match = constant_match,
            .patch_candidate = confidence > 0.7,
            .confidence_score = confidence,
        });

        // Update sacred metrics
        self.sacred_metrics.total_symbols_analyzed += 1;
        if (confidence > 0.7) self.sacred_metrics.patch_candidates_found += 1;
        if (constant_match != null) self.sacred_metrics.sacred_constant_matches += 1;

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
        var buf: [16384]u8 = undefined; // Increased for sacred information
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        writer.writeAll("// === CODEBASE CONTEXT (auto-retrieved) ===\n") catch return null;
        writer.writeAll("// Relevant code from repository:\n") catch return null;

        for (hits_buf[0..hit_count]) |hit| {
            const sym = self.symbols.items[hit.symbol_idx];
            std.fmt.format(writer, "// [{s}] {s}:{d} — {s} (score: {d:.3})\n", .{
                @tagName(sym.kind), sym.file_path, sym.line, sym.name, hit.sacred_score,
            }) catch break;
            std.fmt.format(writer, "//   {s}\n", .{sym.snippet}) catch break;

            // Add sacred intelligence information
            if (sym.sacred_gematria) |gem| {
                std.fmt.format(writer, "//   Sacred Gematria: {d} (mod 27 = {d})\n", .{
                    gem, gem % 27,
                }) catch break;
            }
            if (sym.hebrew_gematria) |gem| {
                std.fmt.format(writer, "//   Hebrew Gematria: {d}\n", .{gem}) catch break;
            }
            if (sym.greek_gematria) |gem| {
                std.fmt.format(writer, "//   Greek Gematria: {d}\n", .{gem}) catch break;
            }
            if (sym.arabic_gematria) |gem| {
                std.fmt.format(writer, "//   Arabic Gematria: {d}\n", .{gem}) catch break;
            }
            if (sym.sacred_formula) |formula| {
                std.fmt.format(writer, "//   Sacred Formula: V = {s}\n", .{formula}) catch break;
            }
            if (sym.sacred_constant_match) |match| {
                std.fmt.format(writer, "//   Sacred Constant Match: {s}\n", .{match}) catch break;
            }
            if (sym.patch_candidate) {
                std.fmt.format(writer, "//   PATCH CANDIDATE (confidence: {d:.2})\n", .{
                    sym.confidence_score,
                }) catch break;
            }
        }

        // Add evolution progress
        const metrics = self.getSacredMetrics();
        std.fmt.format(writer, "// === EVOLUTION PROGRESS: {d:.1}% ===\n", .{
            metrics.evolution_progress * 100.0,
        }) catch {};
        std.fmt.format(writer, "// Patch Candidates: {d} / {d} symbols\n", .{
            metrics.patch_candidates_found,
            metrics.total_symbols_analyzed,
        }) catch {};

        writer.writeAll("// === END CONTEXT ===\n\n") catch return null;

        const written = fbs.getWritten();
        const result = self.allocator.alloc(u8, written.len) catch return null;
        @memcpy(result, written);
        return result;
    }

    // =========================================================================
    // SACRED INTELLIGENCE FUNCTIONS
    // =========================================================================

    /// Find all patch candidates (symbols with confidence > threshold)
    pub fn findPatchCandidates(self: *Self, threshold: f64) ![]IndexedSymbol {
        var candidates = std.ArrayList(IndexedSymbol).init(self.allocator);
        defer candidates.deinit();

        for (self.symbols.items) |sym| {
            if (sym.confidence_score >= threshold) {
                try candidates.append(sym);
            }
        }

        // Return slice (caller owns memory)
        const result = try self.allocator.alloc(IndexedSymbol, candidates.items.len);
        @memcpy(result, candidates.items);
        return result;
    }

    /// Get top N sacred symbols by confidence score
    pub fn getTopSacredSymbols(self: *Self, n: usize) ![]IndexedSymbol {
        const top_n = @min(n, self.symbols.items.len);
        if (top_n == 0) return &[_]IndexedSymbol{};

        // Copy symbols to sort
        var sorted = try self.allocator.alloc(IndexedSymbol, self.symbols.items.len);
        defer self.allocator.free(sorted);
        @memcpy(sorted, self.symbols.items);

        // Sort by confidence score (descending)
        std.sort.insertion(IndexedSymbol, sorted, {}, struct {
            fn lessThan(_: void, a: IndexedSymbol, b: IndexedSymbol) bool {
                return a.confidence_score > b.confidence_score;
            }
        }.lessThan);

        // Return top N
        const result = try self.allocator.alloc(IndexedSymbol, top_n);
        @memcpy(result, sorted[0..top_n]);
        return result;
    }

    /// Get sacred metrics for this context
    pub fn getSacredMetrics(self: *Self) SacredMetrics {
        // Update evolution progress based on coverage
        const coverage = if (self.symbols.items.len > 0)
            @as(f64, @floatFromInt(self.sacred_metrics.sacred_constant_matches)) /
            @as(f64, @floatFromInt(self.symbols.items.len))
        else
            0.0;

        var metrics = self.sacred_metrics;
        metrics.evolution_progress = coverage;
        metrics.avg_confidence_score = if (self.symbols.items.len > 0) blk: {
            var sum: f64 = 0.0;
            for (self.symbols.items) |sym| sum += sym.confidence_score;
            break :blk sum / @as(f64, @floatFromInt(self.symbols.items.len));
        } else 0.0;

        metrics.top_sacred_symbols = @intCast(self.symbols.items.len);

        return metrics;
    }

    /// Apply sacred patches (stub for future implementation)
    pub fn applySacredPatches(self: *Self) !PatchStats {
        _ = self;
        return PatchStats{
            .patches_applied = 0,
            .patches_succeeded = 0,
            .patches_failed = 0,
            .avg_improvement_pct = 0.0,
        };
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

        // Sacred Intelligence metrics
        const metrics = self.getSacredMetrics();
        std.debug.print("\n  {s}Sacred Intelligence:{s}\n", .{ colors.PURPLE, colors.RESET });
        std.debug.print("    Analyzed:        {d}\n", .{metrics.total_symbols_analyzed});
        std.debug.print("    Patch candidates:{d}\n", .{metrics.patch_candidates_found});
        std.debug.print("    Constant matches:{d}\n", .{metrics.sacred_constant_matches});
        std.debug.print("    Avg confidence:  {d:.3}\n", .{metrics.avg_confidence_score});
        std.debug.print("    Evolution:       {d:.1}%\n", .{metrics.evolution_progress * 100.0});

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
                .sacred_gematria = null,
                .hebrew_gematria = null,
                .greek_gematria = null,
                .arabic_gematria = null,
                .sacred_formula = null,
                .sacred_constant_match = null,
                .patch_candidate = false,
                .confidence_score = 0.0,
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

pub fn runIntelligenceCommand(allocator: std.mem.Allocator, state: anytype, args: []const []const u8) !void {
    _ = allocator;

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════╗{s}\n", .{ colors.GOLDEN, colors.RESET });
    std.debug.print("{s}║         SACRED INTELLIGENCE - Sacred Formula Analysis        ║{s}\n", .{ colors.GOLDEN, colors.RESET });
    std.debug.print("{s}║     V = n × 3^k × π^m × φ^p × e^q | φ² + 1/φ² = 3 = TRINITY     ║{s}\n", .{ colors.GOLDEN, colors.RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════╝{s}\n\n", .{ colors.GOLDEN, colors.RESET });

    if (args.len == 0) {
        // No args: show full intelligence report
        std.debug.print("{s}Analyzing codebase for sacred patterns...{s}\n\n", .{ colors.CYAN, colors.RESET });

        if (state.context_mgr) |mgr| {
            // Show basic stats
            std.debug.print("{s}Context Manager Status:{s} {s}Active{s}\n", .{ colors.CYAN, colors.RESET, colors.GREEN, colors.RESET });
            std.debug.print("  Symbols Indexed: {s}{d}{s}\n", .{ colors.GOLDEN, mgr.stats.symbols_indexed, colors.RESET });
            std.debug.print("  Files Scanned: {s}{d}{s}\n", .{ colors.GOLDEN, mgr.stats.files_indexed, colors.RESET });
            std.debug.print("  Index Size: {s}{d} KB{s}\n", .{ colors.GOLDEN, mgr.stats.index_size_bytes / 1024, colors.RESET });

            // Sacred scoring info
            std.debug.print("\n{s}Sacred Mathematics Integration:{s}\n", .{ colors.CYAN, colors.RESET });
            std.debug.print("  {s}•{s} Coptic Gematria: 27 glyphs (3³ = 27)\n", .{ colors.GOLDEN, colors.RESET });
            std.debug.print("  {s}•{s} Sacred Formula: V = n × 3^k × π^m × φ^p × e^q\n", .{ colors.GOLDEN, colors.RESET });
            std.debug.print("  {s}•{s} 42 Sacred Constants recognized\n", .{ colors.GOLDEN, colors.RESET });
            std.debug.print("  {s}•{s} φ-weighted similarity scoring\n", .{ colors.GOLDEN, colors.RESET });
            std.debug.print("\n  φ (Golden Ratio): {s}{s}{s}\n", .{ colors.GOLDEN, "1.618033988749895", colors.RESET });
            std.debug.print("  φ² + 1/φ² = {s}{s}{s}\n", .{ colors.GOLDEN, "3.0", colors.RESET });
            std.debug.print("  Trinity Identity: {s}{s}{s}\n", .{ colors.GOLDEN, "φ² + 1/φ² = 3", colors.RESET });

            // Show top symbols by sacred score if available
            if (mgr.symbols.items.len > 0) {
                std.debug.print("\n{s}Sample Sacred Symbols:{s}\n", .{ colors.CYAN, colors.RESET });
                const top_n = @min(5, mgr.symbols.items.len);
                for (mgr.symbols.items[0..top_n], 0..) |sym, i| {
                    // Compute simple gematria for symbol name
                    const gematria = computeSymbolGematria(sym.name);
                    std.debug.print("  {d}. {s}{s}{s} ({s})\n", .{
                        i + 1,
                        colors.GOLDEN,
                        sym.name,
                        colors.RESET,
                        @tagName(sym.kind),
                    });
                    std.debug.print("     Gematria: {d} (mod 27 = {d})\n", .{ gematria, gematria % 27 });
                }
            }

            std.debug.print("\n{s}Available Commands:{s}\n", .{ colors.CYAN, colors.RESET });
            std.debug.print("  tri analyze              - Scan codebase for symbols\n", .{});
            std.debug.print("  tri search <query>       - Search indexed symbols\n", .{});
            std.debug.print("  tri context              - Show context statistics\n", .{});
            std.debug.print("  tri intelligence <sym>   - Analyze specific symbol\n", .{});
            std.debug.print("  tri constants            - Show sacred constants\n", .{});
            std.debug.print("  tri sacred               - Display sacred formulas\n", .{});

            std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════╗{s}\n", .{ colors.GOLDEN, colors.RESET });
            std.debug.print("{s}║  φ² + 1/φ² = 3 = TRINITY | Sacred Intelligence Core v1.0.0    ║{s}\n", .{ colors.GOLDEN, colors.RESET });
            std.debug.print("{s}╚════════════════════════════════════════════════════════════════╝{s}\n\n", .{ colors.GOLDEN, colors.RESET });
        } else {
            std.debug.print("{s}Context manager not initialized.{s}\n", .{ colors.RED, colors.RESET });
            std.debug.print("Run {s}tri analyze{s} to initialize the codebase context.\n\n", .{ colors.GOLDEN, colors.RESET });
        }
    } else {
        // Args provided: analyze specific symbol(s)
        std.debug.print("{s}Analyzing specific symbol(s):{s}\n\n", .{ colors.CYAN, colors.RESET });

        for (args) |symbol| {
            std.debug.print("  {s}Symbol:{s} {s}\n", .{ colors.GOLDEN, colors.RESET, symbol });

            // Compute gematria value for symbol
            const gematria_val = computeSymbolGematria(symbol);
            std.debug.print("    Gematria: {d} (mod 27 = {d})\n", .{ gematria_val, gematria_val % 27 });

            // Try to fit sacred formula
            const fit = sacred_formula.fitSacredFormula(@as(f64, @floatFromInt(gematria_val)));
            var formula_buf: [128]u8 = undefined;
            const formula_str = sacred_formula.formatFormulaString(&formula_buf, fit);
            std.debug.print("    Formula:  V = {s}\n", .{formula_str});
            std.debug.print("    Error:    {d:.2}%\n", .{fit.error_pct});

            // Try to find in context manager
            if (state.context_mgr) |mgr| {
                var search_buf: [10]SearchHit = undefined;
                const hit_count = mgr.search(symbol, 5, &search_buf);
                if (hit_count > 0) {
                    std.debug.print("    {s}Found:{s} {d} matches in codebase\n", .{ colors.GREEN, colors.RESET, hit_count });
                    for (search_buf[0..hit_count]) |hit| {
                        const sym = mgr.symbols.items[hit.symbol_idx];
                        std.debug.print("      - {s} (score: {d:.2}, sacred: {d:.2})\n", .{
                            sym.name,
                            hit.score,
                            hit.sacred_score,
                        });
                    }
                } else {
                    std.debug.print("    {s}Not found{s} in codebase index\n", .{ colors.GRAY, colors.RESET });
                }
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ colors.GOLDEN, colors.RESET });
    }
}

/// Simple ASCII sum gematria (placeholder for full Coptic gematria)
fn computeSymbolGematria(text: []const u8) u64 {
    var sum: u64 = 0;
    for (text) |c| {
        sum += c;
    }
    return sum;
}

/// Compute multi-language gematria for a symbol name
fn computeMultiLanguageGematria(text: []const u8) MultiLanguageGematria {
    // Sacred (Coptic-based): ASCII sum mod 1000
    var sacred: u32 = 0;
    for (text) |c| sacred +%= @as(u32, @intCast(c));
    sacred = sacred % 1000;

    // Hebrew: ASCII sum with alefbet weights (simplified)
    var hebrew: u32 = 0;
    for (text, 0..) |c, i| {
        const weight = @as(u32, @intCast(i % 22 + 1)); // 22 Hebrew letters
        hebrew +%= @as(u32, @intCast(c)) *% weight;
    }
    hebrew = hebrew % 1000;

    // Greek: ASCII sum with isopsephy weights (simplified)
    var greek: u32 = 0;
    for (text, 0..) |c, i| {
        const weight = @as(u32, @intCast(i % 24 + 1)); // 24 Greek letters
        greek +%= @as(u32, @intCast(c)) *% weight;
    }
    greek = greek % 1000;

    // Arabic: ASCII sum with Abjad numerals (simplified)
    var arabic: u32 = 0;
    for (text, 0..) |c, i| {
        const weight = @as(u32, @intCast(i % 28 + 1)); // 28 Arabic letters
        arabic +%= @as(u32, @intCast(c)) *% weight;
    }
    arabic = arabic % 1000;

    return .{
        .sacred = sacred,
        .hebrew = hebrew,
        .greek = greek,
        .arabic = arabic,
    };
}

/// Compute sacred formula fit for a symbol name
fn computeSacredFormulaForSymbol(name: []const u8) sacred_formula.SacredFormulaFit {
    const gematria = computeSymbolGematria(name);
    const target: f64 = @floatFromInt(gematria);
    return sacred_formula.fitSacredFormula(target);
}

/// Find sacred constant match for a gematria value
fn findSacredConstantMatch(gematria: u32) ?[]const u8 {
    const target: f64 = @floatFromInt(gematria);

    // Check all sacred constants for close match (within 1%)
    for (sacred_formula.sacred_constants) |const_| {
        const diff = @abs(const_.target - target) / target;
        if (diff < 0.01) {
            return const_.name;
        }
    }

    return null;
}

/// Format sacred formula string
fn formatSacredFormula(buf: []u8, fit: sacred_formula.SacredFormulaFit) []const u8 {
    return sacred_formula.formatFormulaString(buf, fit);
}

/// Compute sacred score for a symbol (internal implementation)
fn computeSymbolSacredScoreImpl(
    multi_gem: MultiLanguageGematria,
    fit: sacred_formula.SacredFormulaFit,
    constant_match: ?[]const u8,
) f64 {
    var score: f64 = 0.0;

    // Sacred gematria score (27 is sacred: 3³)
    const sacred_mod = multi_gem.sacred % 27;
    score += @as(f64, @floatFromInt(sacred_mod)) / 27.0 * 0.3;

    // Formula fit score (lower error = higher score)
    const formula_score = if (fit.error_pct < 10.0)
        (1.0 - fit.error_pct / 10.0) * 0.4
    else
        0.0;
    score += formula_score;

    // Constant match bonus
    if (constant_match != null) {
        score += 0.3;
    }

    // Multi-language harmony (all gematria values close)
    const avg = @as(f64, @floatFromInt(multi_gem.sacred + multi_gem.hebrew + multi_gem.greek + multi_gem.arabic)) / 4.0;
    var variance: f64 = 0.0;
    const vals = [_]u32{ multi_gem.sacred, multi_gem.hebrew, multi_gem.greek, multi_gem.arabic };
    for (vals) |v| {
        const diff = @as(f64, @floatFromInt(v)) - avg;
        variance += diff * diff;
    }
    variance /= 4.0;
    const harmony = 1.0 / (1.0 + variance / 10000.0);
    score += harmony * 0.2;

    return @min(score, 1.0);
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

test "multi_language_gematria_calculation" {
    const result = computeMultiLanguageGematria("test");
    try std.testing.expect(result.sacred >= 0 and result.sacred < 1000);
    try std.testing.expect(result.hebrew >= 0 and result.hebrew < 1000);
    try std.testing.expect(result.greek >= 0 and result.greek < 1000);
    try std.testing.expect(result.arabic >= 0 and result.arabic < 1000);
}

test "sacred_constant_matching" {
    // Test with known sacred constant values
    const match_137 = findSacredConstantMatch(137);
    try std.testing.expect(match_137 != null); // 1/α (fine structure)

    const match_42 = findSacredConstantMatch(42);
    // 42 might not match exactly within 1%, so we just check it doesn't crash
    _ = match_42;
}

test "patch_candidate_identification" {
    var mgr = ContextManager.init(std.testing.allocator);
    defer mgr.deinit();

    // Create test symbols with known scores
    const arena = mgr.arena.allocator();

    const name1 = try arena.dupe(u8, "sacredSymbol");
    const path1 = try arena.dupe(u8, "test.zig");
    const snippet1 = try arena.dupe(u8, "pub fn sacredSymbol() void {}");

    const name2 = try arena.dupe(u8, "test");
    const path2 = try arena.dupe(u8, "test.zig");
    const snippet2 = try arena.dupe(u8, "pub fn test() void {}");

    try mgr.symbols.append(mgr.allocator, .{
        .name = name1,
        .file_path = path1,
        .line = 1,
        .kind = .function,
        .snippet = snippet1,
        .sacred_gematria = 137,
        .hebrew_gematria = 100,
        .greek_gematria = 90,
        .arabic_gematria = 80,
        .sacred_formula = null,
        .sacred_constant_match = null,
        .patch_candidate = true,
        .confidence_score = 0.8,
    });

    try mgr.symbols.append(mgr.allocator, .{
        .name = name2,
        .file_path = path2,
        .line = 10,
        .kind = .test_case,
        .snippet = snippet2,
        .sacred_gematria = 50,
        .hebrew_gematria = 45,
        .greek_gematria = 40,
        .arabic_gematria = 35,
        .sacred_formula = null,
        .sacred_constant_match = null,
        .patch_candidate = false,
        .confidence_score = 0.3,
    });

    // Find patch candidates with threshold 0.5
    const candidates = try mgr.findPatchCandidates(0.5);
    defer mgr.allocator.free(candidates);

    try std.testing.expectEqual(@as(usize, 1), candidates.len);
    try std.testing.expectEqual(0.8, candidates[0].confidence_score);
}

test "sacred_score_calculation" {
    const multi_gem = computeMultiLanguageGematria("testFunction");
    const fit = computeSacredFormulaForSymbol("testFunction");
    const match = findSacredConstantMatch(multi_gem.sacred);

    const score = computeSymbolSacredScoreImpl(multi_gem, fit, match);

    try std.testing.expect(score >= 0.0);
    try std.testing.expect(score <= 1.0);
}

test "sacred_metrics_collection" {
    var mgr = ContextManager.init(std.testing.allocator);
    defer mgr.deinit();

    // Add some test symbols
    const arena = mgr.arena.allocator();
    const name = try arena.dupe(u8, "test");
    const path = try arena.dupe(u8, "test.zig");
    const snippet = try arena.dupe(u8, "pub fn test() void {}");

    try mgr.symbols.append(mgr.allocator, .{
        .name = name,
        .file_path = path,
        .line = 1,
        .kind = .function,
        .snippet = snippet,
        .sacred_gematria = 137,
        .hebrew_gematria = 100,
        .greek_gematria = 90,
        .arabic_gematria = 80,
        .sacred_formula = null,
        .sacred_constant_match = null,
        .patch_candidate = false,
        .confidence_score = 0.5,
    });

    mgr.sacred_metrics.total_symbols_analyzed = 1;
    mgr.sacred_metrics.patch_candidates_found = 0;
    mgr.sacred_metrics.sacred_constant_matches = 0;

    const metrics = mgr.getSacredMetrics();

    try std.testing.expectEqual(@as(u32, 1), metrics.total_symbols_analyzed);
    try std.testing.expect(metrics.avg_confidence_score >= 0.0);
    try std.testing.expect(metrics.evolution_progress >= 0.0);
    try std.testing.expect(metrics.evolution_progress <= 1.0);
}
