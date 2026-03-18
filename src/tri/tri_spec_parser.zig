// @origin(spec:tri_spec_parser.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// tri_spec_parser.zig — Parser for .tri Sacred Spec format (sacred-spec-v1)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Format: YAML-like, simpler than .tri (no types/behaviors/FSMs)
// Header: format: sacred-spec-v1
// Sections: bases, search, constants, predictions
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

// ═══════════════════════════════════════════════════════════════════════════════
// Data Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredConstant = struct {
    name: []const u8,
    symbol: []const u8,
    value: f64,
    category: []const u8,
    description: []const u8,
};

pub const SacredPrediction = struct {
    name: []const u8,
    formula: []const u8,
    n: i8,
    k: i8,
    m: i8,
    p: i8,
    q: i8,
    unit: []const u8,
};

pub const SearchBounds = struct {
    n_range: [2]i8 = .{ 1, 9 },
    k_range: [2]i8 = .{ -4, 4 },
    m_range: [2]i8 = .{ -3, 3 },
    p_range: [2]i8 = .{ -4, 4 },
    q_range: [2]i8 = .{ -3, 3 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// sacred-spec-v2 Data Types (Sacred Language Model)
// ═══════════════════════════════════════════════════════════════════════════════

pub const GematriaGlyph = struct {
    glyph: []const u8, // UTF-8 encoded glyph
    codepoint: u21, // Unicode codepoint
    value: u16, // Numeric value (1-900)
    kingdom: []const u8, // "matter", "energy", "information"
};

pub const TokenType = struct {
    name: []const u8,
    id: u8,
    description: []const u8,
};

pub const TokenizerConfig = struct {
    max_token_length: u16 = 128,
    token_types: ArrayList(TokenType) = .{},
};

pub const EmbeddingConfig = struct {
    dimension: u16 = 64,
    sacred_formula_dims: u8 = 5,
    kingdom_dims: u8 = 3,
    positional_dims: u8 = 8,
    proximity_dims: u8 = 16,
    distributional_dims: u8 = 32,
    normalization: []const u8 = "l2",
};

// ═══════════════════════════════════════════════════════════════════════════════
// sacred-spec-v3 Data Types (Sacred Reasoning + Attention)
// ═══════════════════════════════════════════════════════════════════════════════

pub const ReasoningStrategy = struct {
    name: []const u8,
    description: []const u8,
};

pub const ReasoningAxiom = struct {
    name: []const u8,
    rule: []const u8,
    weight: f64,
};

pub const ReasoningConfig = struct {
    strategies: ArrayList(ReasoningStrategy) = .{},
    axioms: ArrayList(ReasoningAxiom) = .{},
};

pub const AttentionConfig = struct {
    heads: u8 = 1,
    key_dim: u16 = 64,
    value_dim: u16 = 64,
    temperature: f64 = 8.0,
    source: []const u8 = "sacred_constants",
};

pub const CacheConfig = struct {
    precompute_formulas: bool = true,
    precompute_embeddings: bool = true,
    sorted_table: bool = true,
};

pub const SacredSpec = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    format_version: u8, // 1 = sacred-spec-v1, 2 = sacred-spec-v2, 3 = sacred-spec-v3
    bases: [4]f64, // TRINITY, PI, PHI, E (fixed order)
    search: SearchBounds,
    constants: ArrayList(SacredConstant),
    predictions: ArrayList(SacredPrediction),
    // v2 fields (Sacred Language Model)
    gematria_table: ArrayList(GematriaGlyph),
    tokenizer: TokenizerConfig,
    embedding: EmbeddingConfig,
    // v3 fields (Sacred Reasoning + Attention)
    reasoning: ReasoningConfig,
    attention: AttentionConfig,
    cache: CacheConfig,
    allocator: Allocator,

    pub fn init(allocator: Allocator) SacredSpec {
        return .{
            .name = "",
            .version = "",
            .description = "",
            .format_version = 1,
            .bases = .{ 3.0, std.math.pi, 1.6180339887498948482, std.math.e },
            .search = .{},
            .constants = .{},
            .predictions = .{},
            .gematria_table = .{},
            .tokenizer = .{},
            .embedding = .{},
            .reasoning = .{},
            .attention = .{},
            .cache = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SacredSpec) void {
        self.constants.deinit(self.allocator);
        self.predictions.deinit(self.allocator);
        self.gematria_table.deinit(self.allocator);
        self.tokenizer.token_types.deinit(self.allocator);
        self.reasoning.strategies.deinit(self.allocator);
        self.reasoning.axioms.deinit(self.allocator);
    }

    pub fn constantCount(self: *const SacredSpec) usize {
        return self.constants.items.len;
    }

    pub fn predictionCount(self: *const SacredSpec) usize {
        return self.predictions.items.len;
    }

    pub fn glyphCount(self: *const SacredSpec) usize {
        return self.gematria_table.items.len;
    }

    pub fn isV2(self: *const SacredSpec) bool {
        return self.format_version >= 2;
    }

    pub fn isV3(self: *const SacredSpec) bool {
        return self.format_version >= 3;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Parser
// ═══════════════════════════════════════════════════════════════════════════════

pub const TriSpecParser = struct {
    const Self = @This();

    allocator: Allocator,
    source: []const u8,
    pos: usize,
    line: usize,

    pub fn init(allocator: Allocator, source: []const u8) TriSpecParser {
        return .{
            .allocator = allocator,
            .source = source,
            .pos = 0,
            .line = 1,
        };
    }

    pub fn parse(self: *Self) !SacredSpec {
        var spec = SacredSpec.init(self.allocator);

        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const key = self.readKey();
            if (key.len == 0) {
                self.pos += 1;
                continue;
            }

            // Skip colon after key
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }

            if (std.mem.eql(u8, key, "format")) {
                self.skipInlineWhitespace();
                const val = self.readValue();
                if (std.mem.eql(u8, val, "sacred-spec-v1")) {
                    spec.format_version = 1;
                } else if (std.mem.eql(u8, val, "sacred-spec-v2")) {
                    spec.format_version = 2;
                } else if (std.mem.eql(u8, val, "sacred-spec-v3")) {
                    spec.format_version = 3;
                } else {
                    return error.UnsupportedFormat;
                }
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "name")) {
                self.skipInlineWhitespace();
                spec.name = self.readValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "version")) {
                self.skipInlineWhitespace();
                spec.version = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "description")) {
                self.skipInlineWhitespace();
                spec.description = self.readQuotedValue();
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "bases")) {
                self.skipToNextLine();
                self.parseBases(&spec);
            } else if (std.mem.eql(u8, key, "search")) {
                self.skipToNextLine();
                self.parseSearch(&spec.search);
            } else if (std.mem.eql(u8, key, "constants")) {
                self.skipToNextLine();
                try self.parseConstants(&spec.constants);
            } else if (std.mem.eql(u8, key, "predictions")) {
                self.skipToNextLine();
                try self.parsePredictions(&spec.predictions);
            } else if (std.mem.eql(u8, key, "gematria_table")) {
                self.skipToNextLine();
                try self.parseGematriaTable(&spec.gematria_table);
            } else if (std.mem.eql(u8, key, "tokenizer")) {
                self.skipToNextLine();
                self.parseTokenizerConfig(&spec.tokenizer);
            } else if (std.mem.eql(u8, key, "embedding")) {
                self.skipToNextLine();
                self.parseEmbeddingConfig(&spec.embedding);
            } else if (std.mem.eql(u8, key, "reasoning")) {
                self.skipToNextLine();
                try self.parseReasoningConfig(&spec.reasoning);
            } else if (std.mem.eql(u8, key, "attention")) {
                self.skipToNextLine();
                self.parseAttentionConfig(&spec.attention);
            } else if (std.mem.eql(u8, key, "cache")) {
                self.skipToNextLine();
                self.parseCacheConfig(&spec.cache);
            } else {
                self.skipToNextLine();
            }
        }

        return spec;
    }

    // ─── Section Parsers ─────────────────────────────────────────────────────

    fn parseBases(self: *Self, spec: *SacredSpec) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const val_str = self.readValue();
            const val = std.fmt.parseFloat(f64, val_str) catch 0;

            if (std.mem.eql(u8, key, "TRINITY")) {
                spec.bases[0] = val;
            } else if (std.mem.eql(u8, key, "PI")) {
                spec.bases[1] = val;
            } else if (std.mem.eql(u8, key, "PHI")) {
                spec.bases[2] = val;
            } else if (std.mem.eql(u8, key, "E")) {
                spec.bases[3] = val;
            }
            self.skipToNextLine();
        }
    }

    fn parseSearch(self: *Self, search: *SearchBounds) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const range = self.parseRange();

            if (std.mem.eql(u8, key, "n_range")) {
                search.n_range = range;
            } else if (std.mem.eql(u8, key, "k_range")) {
                search.k_range = range;
            } else if (std.mem.eql(u8, key, "m_range")) {
                search.m_range = range;
            } else if (std.mem.eql(u8, key, "p_range")) {
                search.p_range = range;
            } else if (std.mem.eql(u8, key, "q_range")) {
                search.q_range = range;
            }
            self.skipToNextLine();
        }
    }

    fn parseConstants(self: *Self, constants: *ArrayList(SacredConstant)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            // Expect "- " prefix for list items
            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2; // skip "- "
                var constant = SacredConstant{
                    .name = "",
                    .symbol = "",
                    .value = 0,
                    .category = "",
                    .description = "",
                };

                // First field on same line as "-"
                self.parseField(&constant);
                self.skipToNextLine();

                // Remaining fields (deeper indent)
                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 4) break;
                    self.pos += field_indent;

                    // Check if this is a new list item
                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parseField(&constant);
                    self.skipToNextLine();
                }

                try constants.append(self.allocator, constant);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parsePredictions(self: *Self, predictions: *ArrayList(SacredPrediction)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2;
                var pred = SacredPrediction{
                    .name = "",
                    .formula = "",
                    .n = 0,
                    .k = 0,
                    .m = 0,
                    .p = 0,
                    .q = 0,
                    .unit = "",
                };

                self.parsePredField(&pred);
                self.skipToNextLine();

                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 4) break;
                    self.pos += field_indent;

                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parsePredField(&pred);
                    self.skipToNextLine();
                }

                try predictions.append(self.allocator, pred);
            } else {
                self.skipToNextLine();
            }
        }
    }

    // ─── v2 Section Parsers ────────────────────────────────────────────────

    fn parseGematriaTable(self: *Self, table: *ArrayList(GematriaGlyph)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2;
                var glyph_entry = GematriaGlyph{
                    .glyph = "",
                    .codepoint = 0,
                    .value = 0,
                    .kingdom = "",
                };

                self.parseGlyphField(&glyph_entry);
                self.skipToNextLine();

                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 4) break;
                    self.pos += field_indent;
                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parseGlyphField(&glyph_entry);
                    self.skipToNextLine();
                }

                try table.append(self.allocator, glyph_entry);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parseTokenizerConfig(self: *Self, config: *TokenizerConfig) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();

            if (std.mem.eql(u8, key, "max_token_length")) {
                const val_str = self.readValue();
                config.max_token_length = std.fmt.parseInt(u16, val_str, 10) catch 128;
                self.skipToNextLine();
            } else if (std.mem.eql(u8, key, "token_types")) {
                self.skipToNextLine();
                self.parseTokenTypes(&config.token_types);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parseTokenTypes(self: *Self, types: *ArrayList(TokenType)) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;
            self.pos += indent;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2;
                var tt = TokenType{ .name = "", .id = 0, .description = "" };

                self.parseTokenTypeField(&tt);
                self.skipToNextLine();

                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 6) break;
                    self.pos += field_indent;
                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parseTokenTypeField(&tt);
                    self.skipToNextLine();
                }

                types.append(self.allocator, tt) catch |err| {
                    std.log.warn("tri_spec_parser: failed to append type: {}", .{err});
                };
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parseEmbeddingConfig(self: *Self, config: *EmbeddingConfig) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const val_str = self.readValue();

            if (std.mem.eql(u8, key, "dimension")) {
                config.dimension = std.fmt.parseInt(u16, val_str, 10) catch 64;
            } else if (std.mem.eql(u8, key, "sacred_formula_dims")) {
                config.sacred_formula_dims = std.fmt.parseInt(u8, val_str, 10) catch 5;
            } else if (std.mem.eql(u8, key, "kingdom_dims")) {
                config.kingdom_dims = std.fmt.parseInt(u8, val_str, 10) catch 3;
            } else if (std.mem.eql(u8, key, "positional_dims")) {
                config.positional_dims = std.fmt.parseInt(u8, val_str, 10) catch 8;
            } else if (std.mem.eql(u8, key, "proximity_dims")) {
                config.proximity_dims = std.fmt.parseInt(u8, val_str, 10) catch 16;
            } else if (std.mem.eql(u8, key, "distributional_dims")) {
                config.distributional_dims = std.fmt.parseInt(u8, val_str, 10) catch 32;
            } else if (std.mem.eql(u8, key, "normalization")) {
                config.normalization = val_str;
            }
            self.skipToNextLine();
        }
    }

    // ─── v3 Section Parsers ────────────────────────────────────────────────

    fn parseReasoningConfig(self: *Self, config: *ReasoningConfig) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();

            if (std.mem.eql(u8, key, "strategies")) {
                self.skipToNextLine();
                try self.parseReasoningStrategies(&config.strategies);
            } else if (std.mem.eql(u8, key, "axioms")) {
                self.skipToNextLine();
                try self.parseReasoningAxioms(&config.axioms);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parseReasoningStrategies(self: *Self, strategies: *ArrayList(ReasoningStrategy)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;
            self.pos += indent;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2;
                var strategy = ReasoningStrategy{ .name = "", .description = "" };

                self.parseStrategyField(&strategy);
                self.skipToNextLine();

                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 6) break;
                    self.pos += field_indent;
                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parseStrategyField(&strategy);
                    self.skipToNextLine();
                }

                try strategies.append(self.allocator, strategy);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parseReasoningAxioms(self: *Self, axioms: *ArrayList(ReasoningAxiom)) Allocator.Error!void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 4) break;
            self.pos += indent;

            if (self.pos + 1 < self.source.len and self.source[self.pos] == '-' and self.source[self.pos + 1] == ' ') {
                self.pos += 2;
                var axiom = ReasoningAxiom{ .name = "", .rule = "", .weight = 0 };

                self.parseAxiomField(&axiom);
                self.skipToNextLine();

                while (self.pos < self.source.len) {
                    self.skipEmptyLinesAndComments();
                    if (self.pos >= self.source.len) break;

                    const field_indent = self.countIndent();
                    if (field_indent < 6) break;
                    self.pos += field_indent;
                    if (self.pos < self.source.len and self.source[self.pos] == '-') break;

                    self.parseAxiomField(&axiom);
                    self.skipToNextLine();
                }

                try axioms.append(self.allocator, axiom);
            } else {
                self.skipToNextLine();
            }
        }
    }

    fn parseAttentionConfig(self: *Self, config: *AttentionConfig) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const val_str = self.readValue();

            if (std.mem.eql(u8, key, "heads")) {
                config.heads = std.fmt.parseInt(u8, val_str, 10) catch 1;
            } else if (std.mem.eql(u8, key, "key_dim")) {
                config.key_dim = std.fmt.parseInt(u16, val_str, 10) catch 64;
            } else if (std.mem.eql(u8, key, "value_dim")) {
                config.value_dim = std.fmt.parseInt(u16, val_str, 10) catch 64;
            } else if (std.mem.eql(u8, key, "temperature")) {
                config.temperature = std.fmt.parseFloat(f64, val_str) catch 8.0;
            } else if (std.mem.eql(u8, key, "source")) {
                config.source = val_str;
            }
            self.skipToNextLine();
        }
    }

    fn parseCacheConfig(self: *Self, config: *CacheConfig) void {
        while (self.pos < self.source.len) {
            self.skipEmptyLinesAndComments();
            if (self.pos >= self.source.len) break;

            const indent = self.countIndent();
            if (indent < 2) break;
            self.pos += indent;

            const key = self.readKey();
            if (self.pos < self.source.len and self.source[self.pos] == ':') {
                self.pos += 1;
            }
            self.skipInlineWhitespace();
            const val_str = self.readValue();

            if (std.mem.eql(u8, key, "precompute_formulas")) {
                config.precompute_formulas = std.mem.eql(u8, val_str, "true");
            } else if (std.mem.eql(u8, key, "precompute_embeddings")) {
                config.precompute_embeddings = std.mem.eql(u8, val_str, "true");
            } else if (std.mem.eql(u8, key, "sorted_table")) {
                config.sorted_table = std.mem.eql(u8, val_str, "true");
            }
            self.skipToNextLine();
        }
    }

    // ─── v3 Field Parsers ───────────────────────────────────────────────────

    fn parseStrategyField(self: *Self, s: *ReasoningStrategy) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            s.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "description")) {
            s.description = self.readQuotedValue();
        }
    }

    fn parseAxiomField(self: *Self, a: *ReasoningAxiom) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            a.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "rule")) {
            a.rule = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "weight")) {
            const val_str = self.readValue();
            a.weight = std.fmt.parseFloat(f64, val_str) catch 0;
        }
    }

    // ─── v2 Field Parsers ───────────────────────────────────────────────────

    fn parseGlyphField(self: *Self, g: *GematriaGlyph) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "glyph")) {
            g.glyph = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "codepoint")) {
            const val_str = self.readValue();
            // Parse hex codepoint (0x2C80 format)
            if (val_str.len > 2 and val_str[0] == '0' and (val_str[1] == 'x' or val_str[1] == 'X')) {
                g.codepoint = std.fmt.parseInt(u21, val_str[2..], 16) catch 0;
            } else {
                g.codepoint = std.fmt.parseInt(u21, val_str, 10) catch 0;
            }
        } else if (std.mem.eql(u8, key, "value")) {
            const val_str = self.readValue();
            g.value = std.fmt.parseInt(u16, val_str, 10) catch 0;
        } else if (std.mem.eql(u8, key, "kingdom")) {
            g.kingdom = self.readQuotedValue();
        }
    }

    fn parseTokenTypeField(self: *Self, tt: *TokenType) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            tt.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "id")) {
            const val_str = self.readValue();
            tt.id = std.fmt.parseInt(u8, val_str, 10) catch 0;
        } else if (std.mem.eql(u8, key, "description")) {
            tt.description = self.readQuotedValue();
        }
    }

    // ─── Field Parsers ───────────────────────────────────────────────────────

    fn parseField(self: *Self, c: *SacredConstant) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            c.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "symbol")) {
            c.symbol = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "value")) {
            const val_str = self.readValue();
            c.value = std.fmt.parseFloat(f64, val_str) catch 0;
        } else if (std.mem.eql(u8, key, "category")) {
            c.category = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "description")) {
            c.description = self.readQuotedValue();
        }
    }

    fn parsePredField(self: *Self, p: *SacredPrediction) void {
        const key = self.readKey();
        if (self.pos < self.source.len and self.source[self.pos] == ':') {
            self.pos += 1;
        }
        self.skipInlineWhitespace();

        if (std.mem.eql(u8, key, "name")) {
            p.name = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "formula")) {
            p.formula = self.readQuotedValue();
        } else if (std.mem.eql(u8, key, "n")) {
            p.n = self.readI8();
        } else if (std.mem.eql(u8, key, "k")) {
            p.k = self.readI8();
        } else if (std.mem.eql(u8, key, "m")) {
            p.m = self.readI8();
        } else if (std.mem.eql(u8, key, "p")) {
            p.p = self.readI8();
        } else if (std.mem.eql(u8, key, "q")) {
            p.q = self.readI8();
        } else if (std.mem.eql(u8, key, "unit")) {
            p.unit = self.readQuotedValue();
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    fn readKey(self: *Self) []const u8 {
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ':' or c == ' ' or c == '\n' or c == '\r') break;
            self.pos += 1;
        }
        return self.source[start..self.pos];
    }

    fn readValue(self: *Self) []const u8 {
        self.skipInlineWhitespace();
        const start = self.pos;
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '\n' or c == '\r') break;
            if (c == '#') break;
            self.pos += 1;
        }
        return std.mem.trim(u8, self.source[start..self.pos], &[_]u8{ ' ', '\t' });
    }

    fn readQuotedValue(self: *Self) []const u8 {
        self.skipInlineWhitespace();
        if (self.pos < self.source.len and self.source[self.pos] == '"') {
            self.pos += 1;
            const start = self.pos;
            while (self.pos < self.source.len and self.source[self.pos] != '"') {
                self.pos += 1;
            }
            const value = self.source[start..self.pos];
            if (self.pos < self.source.len) self.pos += 1;
            return value;
        }
        return self.readValue();
    }

    fn readI8(self: *Self) i8 {
        const val_str = self.readValue();
        return std.fmt.parseInt(i8, val_str, 10) catch 0;
    }

    fn parseRange(self: *Self) [2]i8 {
        // Parse "[min, max]" format
        var result: [2]i8 = .{ 0, 0 };
        const val = self.readValue();

        // Find numbers between [ and ]
        var idx: usize = 0;
        // Skip to first number
        while (idx < val.len and (val[idx] == '[' or val[idx] == ' ')) : (idx += 1) {}
        const start1 = idx;
        while (idx < val.len and val[idx] != ',' and val[idx] != ']') : (idx += 1) {}
        const num1 = std.mem.trim(u8, val[start1..idx], &[_]u8{ ' ', '\t' });
        result[0] = std.fmt.parseInt(i8, num1, 10) catch 0;

        // Skip comma
        if (idx < val.len and val[idx] == ',') idx += 1;
        while (idx < val.len and val[idx] == ' ') : (idx += 1) {}
        const start2 = idx;
        while (idx < val.len and val[idx] != ']' and val[idx] != ' ') : (idx += 1) {}
        const num2 = std.mem.trim(u8, val[start2..idx], &[_]u8{ ' ', '\t', ']' });
        result[1] = std.fmt.parseInt(i8, num2, 10) catch 0;

        return result;
    }

    fn countIndent(self: *Self) usize {
        var count: usize = 0;
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] == ' ') {
            count += 1;
            self.pos += 1;
        }
        self.pos = start; // Rewind
        return count;
    }

    fn skipInlineWhitespace(self: *Self) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t') {
                self.pos += 1;
            } else break;
        }
    }

    fn skipToNextLine(self: *Self) void {
        while (self.pos < self.source.len and self.source[self.pos] != '\n') {
            self.pos += 1;
        }
        if (self.pos < self.source.len) {
            self.pos += 1;
            self.line += 1;
        }
    }

    fn skipEmptyLinesAndComments(self: *Self) void {
        while (self.pos < self.source.len) {
            const line_start = self.pos;

            // Skip whitespace at start of line
            while (self.pos < self.source.len and (self.source[self.pos] == ' ' or self.source[self.pos] == '\t')) {
                self.pos += 1;
            }

            if (self.pos >= self.source.len) break;

            const c = self.source[self.pos];
            if (c == '\n' or c == '\r') {
                // Empty line
                self.pos += 1;
                if (c == '\r' and self.pos < self.source.len and self.source[self.pos] == '\n') {
                    self.pos += 1;
                }
                self.line += 1;
                continue;
            }

            if (c == '#') {
                // Comment line
                self.skipToNextLine();
                continue;
            }

            // Non-empty, non-comment line — rewind to line start
            self.pos = line_start;
            break;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Load spec from file
// ═══════════════════════════════════════════════════════════════════════════════

pub fn loadSpecFromFile(allocator: Allocator, path: []const u8) !struct { spec: SacredSpec, source: []const u8 } {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    var parser = TriSpecParser.init(allocator, source);
    const spec = try parser.parse();

    return .{ .spec = spec, .source = source };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parse sacred spec header" {
    const source =
        \\format: sacred-spec-v1
        \\name: sacred_formula
        \\version: "1.0.0"
        \\description: "Test spec"
        \\
        \\bases:
        \\  TRINITY: 3.0
        \\  PI: 3.14159265358979323846
        \\  PHI: 1.6180339887498948482
        \\  E: 2.71828182845904523536
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqualStrings("sacred_formula", spec.name);
    try std.testing.expectEqualStrings("1.0.0", spec.version);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), spec.bases[0], 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1.618033988749894), spec.bases[2], 1e-6);
}

test "parse search bounds" {
    const source =
        \\format: sacred-spec-v1
        \\name: test
        \\
        \\search:
        \\  n_range: [1, 9]
        \\  k_range: [-4, 4]
        \\  m_range: [-3, 3]
        \\  p_range: [-4, 4]
        \\  q_range: [-3, 3]
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(i8, 1), spec.search.n_range[0]);
    try std.testing.expectEqual(@as(i8, 9), spec.search.n_range[1]);
    try std.testing.expectEqual(@as(i8, -4), spec.search.k_range[0]);
    try std.testing.expectEqual(@as(i8, 4), spec.search.k_range[1]);
}

test "parse constants" {
    const source =
        \\format: sacred-spec-v1
        \\name: test
        \\
        \\constants:
        \\  - name: "1/alpha"
        \\    symbol: "FINE_STRUCTURE_INV"
        \\    value: 137.036
        \\    category: "particle_physics"
        \\    description: "Inverse fine-structure constant"
        \\
        \\  - name: "H_0"
        \\    symbol: "HUBBLE"
        \\    value: 67.4
        \\    category: "cosmology"
        \\    description: "Hubble constant"
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 2), spec.constantCount());
    try std.testing.expectEqualStrings("1/alpha", spec.constants.items[0].name);
    try std.testing.expectApproxEqAbs(@as(f64, 137.036), spec.constants.items[0].value, 1e-6);
    try std.testing.expectEqualStrings("cosmology", spec.constants.items[1].category);
}

test "parse predictions" {
    const source =
        \\format: sacred-spec-v1
        \\name: test
        \\
        \\predictions:
        \\  - name: "Neutrino mass hint"
        \\    formula: "1*3^-1*pi^-1*phi^-4*e^-1"
        \\    n: 1
        \\    k: -1
        \\    m: -1
        \\    p: -4
        \\    q: -1
        \\    unit: "eV"
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(usize, 1), spec.predictionCount());
    try std.testing.expectEqualStrings("Neutrino mass hint", spec.predictions.items[0].name);
    try std.testing.expectEqual(@as(i8, -4), spec.predictions.items[0].p);
    try std.testing.expectEqual(@as(i8, -1), spec.predictions.items[0].q);
}

test "reject wrong format" {
    const source =
        \\format: wrong-format
        \\name: test
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    const result = parser.parse();
    try std.testing.expectError(error.UnsupportedFormat, result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v2 Tests (Sacred Language Model)
// ═══════════════════════════════════════════════════════════════════════════════

test "parse v2 gematria table" {
    const source =
        \\format: sacred-spec-v2
        \\name: sacred_language_model
        \\version: "1.0.0"
        \\
        \\gematria_table:
        \\  - glyph: "A"
        \\    codepoint: 0x2C80
        \\    value: 1
        \\    kingdom: "matter"
        \\
        \\  - glyph: "B"
        \\    codepoint: 0x2C82
        \\    value: 2
        \\    kingdom: "matter"
        \\
        \\  - glyph: "S"
        \\    codepoint: 0x2CA4
        \\    value: 100
        \\    kingdom: "information"
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expect(spec.isV2());
    try std.testing.expectEqual(@as(usize, 3), spec.glyphCount());
    try std.testing.expectEqual(@as(u21, 0x2C80), spec.gematria_table.items[0].codepoint);
    try std.testing.expectEqual(@as(u16, 1), spec.gematria_table.items[0].value);
    try std.testing.expectEqualStrings("matter", spec.gematria_table.items[0].kingdom);
    try std.testing.expectEqual(@as(u16, 100), spec.gematria_table.items[2].value);
    try std.testing.expectEqualStrings("information", spec.gematria_table.items[2].kingdom);
}

test "parse v2 embedding config" {
    const source =
        \\format: sacred-spec-v2
        \\name: test_embed
        \\
        \\embedding:
        \\  dimension: 128
        \\  sacred_formula_dims: 5
        \\  kingdom_dims: 3
        \\  positional_dims: 16
        \\  proximity_dims: 32
        \\  distributional_dims: 72
        \\  normalization: l2
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(u16, 128), spec.embedding.dimension);
    try std.testing.expectEqual(@as(u8, 5), spec.embedding.sacred_formula_dims);
    try std.testing.expectEqual(@as(u8, 3), spec.embedding.kingdom_dims);
    try std.testing.expectEqual(@as(u8, 16), spec.embedding.positional_dims);
    try std.testing.expectEqual(@as(u8, 32), spec.embedding.proximity_dims);
    try std.testing.expectEqual(@as(u8, 72), spec.embedding.distributional_dims);
}

test "parse v2 tokenizer config" {
    const source =
        \\format: sacred-spec-v2
        \\name: test_tok
        \\
        \\tokenizer:
        \\  max_token_length: 256
        \\  token_types:
        \\    - name: "coptic_glyph"
        \\      id: 1
        \\      description: "Coptic letter"
        \\    - name: "word"
        \\      id: 2
        \\      description: "Word token"
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(u16, 256), spec.tokenizer.max_token_length);
    try std.testing.expectEqual(@as(usize, 2), spec.tokenizer.token_types.items.len);
    try std.testing.expectEqualStrings("coptic_glyph", spec.tokenizer.token_types.items[0].name);
    try std.testing.expectEqual(@as(u8, 1), spec.tokenizer.token_types.items[0].id);
    try std.testing.expectEqual(@as(u8, 2), spec.tokenizer.token_types.items[1].id);
}

test "v2 with constants and gematria together" {
    const source =
        \\format: sacred-spec-v2
        \\name: combined
        \\version: "1.0.0"
        \\
        \\bases:
        \\  TRINITY: 3.0
        \\  PI: 3.14159265358979323846
        \\  PHI: 1.6180339887498948482
        \\  E: 2.71828182845904523536
        \\
        \\gematria_table:
        \\  - glyph: "A"
        \\    codepoint: 0x2C80
        \\    value: 1
        \\    kingdom: "matter"
        \\
        \\constants:
        \\  - name: "alpha"
        \\    symbol: "ALPHA"
        \\    value: 137.036
        \\    category: "physics"
        \\    description: "Fine structure"
        \\
        \\embedding:
        \\  dimension: 64
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expect(spec.isV2());
    try std.testing.expectEqual(@as(usize, 1), spec.glyphCount());
    try std.testing.expectEqual(@as(usize, 1), spec.constantCount());
    try std.testing.expectEqual(@as(u16, 64), spec.embedding.dimension);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), spec.bases[0], 1e-10);
}

// ═══════════════════════════════════════════════════════════════════════════════
// v3 Tests (Sacred Reasoning + Attention)
// ═══════════════════════════════════════════════════════════════════════════════

test "parse v3 reasoning config" {
    const source =
        \\format: sacred-spec-v3
        \\name: test_reasoning
        \\version: "1.1.0"
        \\
        \\reasoning:
        \\  strategies:
        \\    - name: "decompose"
        \\      description: "Break into formula"
        \\    - name: "compare"
        \\      description: "Find relationships"
        \\    - name: "chain"
        \\      description: "Thread through sequence"
        \\  axioms:
        \\    - name: "trinity_identity"
        \\      rule: "phi^2 + 1/phi^2 = 3"
        \\      weight: 1.0
        \\    - name: "kingdom_resonance"
        \\      rule: "same kingdom resonates"
        \\      weight: 0.8
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expect(spec.isV3());
    try std.testing.expect(spec.isV2()); // v3 implies v2
    try std.testing.expectEqual(@as(usize, 3), spec.reasoning.strategies.items.len);
    try std.testing.expectEqualStrings("decompose", spec.reasoning.strategies.items[0].name);
    try std.testing.expectEqualStrings("chain", spec.reasoning.strategies.items[2].name);
    try std.testing.expectEqual(@as(usize, 2), spec.reasoning.axioms.items.len);
    try std.testing.expectEqualStrings("trinity_identity", spec.reasoning.axioms.items[0].name);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), spec.reasoning.axioms.items[0].weight, 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), spec.reasoning.axioms.items[1].weight, 1e-10);
}

test "parse v3 attention config" {
    const source =
        \\format: sacred-spec-v3
        \\name: test_attn
        \\
        \\attention:
        \\  heads: 4
        \\  key_dim: 128
        \\  value_dim: 128
        \\  temperature: 16.0
        \\  source: sacred_constants
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expectEqual(@as(u8, 4), spec.attention.heads);
    try std.testing.expectEqual(@as(u16, 128), spec.attention.key_dim);
    try std.testing.expectEqual(@as(u16, 128), spec.attention.value_dim);
    try std.testing.expectApproxEqAbs(@as(f64, 16.0), spec.attention.temperature, 1e-10);
}

test "parse v3 cache config" {
    const source =
        \\format: sacred-spec-v3
        \\name: test_cache
        \\
        \\cache:
        \\  precompute_formulas: true
        \\  precompute_embeddings: false
        \\  sorted_table: true
    ;

    var parser = TriSpecParser.init(std.testing.allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    try std.testing.expect(spec.cache.precompute_formulas);
    try std.testing.expect(!spec.cache.precompute_embeddings);
    try std.testing.expect(spec.cache.sorted_table);
}
