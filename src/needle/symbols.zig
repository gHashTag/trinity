// ═══════════════════════════════════════════════════════════════════════════════
// NEEDLE Tier 2 — Symbol Extraction
// ═══════════════════════════════════════════════════════════════════════════════
//
// Extract symbols (fn, struct, enum, const) from Zig source code
// Builds call graph with import tracking
// φ² + 1/φ² = 3 | TRINITY
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const graph = @import("graph.zig");
const Symbol = graph.Symbol;
const SymbolKind = graph.SymbolKind;
const CallGraph = graph.CallGraph;
const GraphNode = graph.GraphNode;
const Edge = graph.Edge;
const EdgeType = graph.EdgeType;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Symbol extraction result
pub const ExtractionResult = struct {
    graph: CallGraph,
    symbols_found: usize,
    files_processed: usize,
    errors: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ExtractionResult {
        return .{
            .graph = CallGraph.init(allocator),
            .symbols_found = 0,
            .files_processed = 0,
            .errors = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ExtractionResult) void {
        self.graph.deinit();
        var iter = self.errors.iterator();
        while (iter.next()) |msg| {
            self.allocator.free(msg.*);
        }
        self.errors.deinit();
    }

    pub fn addError(self: *ExtractionResult, msg: []const u8) !void {
        try self.errors.append(try self.allocator.dupe(u8, msg));
    }
};

/// Zig source parser for symbol extraction
pub const ZigSymbolExtractor = struct {
    allocator: std.mem.Allocator,
    file_path: []const u8,
    source: []const u8,

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8, source: []const u8) ZigSymbolExtractor {
        return .{
            .allocator = allocator,
            .file_path = file_path,
            .source = source,
        };
    }

    /// Extract all symbols from Zig source
    pub fn extractSymbols(self: *ZigSymbolExtractor, result: *ExtractionResult) !void {
        // Get or create node for this file
        const node = try result.graph.getOrCreateNode(self.file_path);

        // Extract different symbol types
        try self.extractFunctions(result, node);
        try self.extractStructs(result, node);
        try self.extractEnums(result, node);
        try self.extractConstants(result, node);
        try self.extractImports(result, node);
    }

    /// Extract function declarations (pub fn and fn)
    fn extractFunctions(self: *ZigSymbolExtractor, result: *ExtractionResult, node: *GraphNode) !void {
        var lines = std.mem.splitScalar(u8, self.source, '\n');
        var line_num: u32 = 1;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

            // Check for pub fn or fn
            const is_pub = std.mem.startsWith(u8, trimmed, "pub ");
            const fn_start = if (is_pub) std.mem.indexOf(u8, trimmed, "fn ") else std.mem.indexOf(u8, trimmed, "fn ");

            if (fn_start) |idx| {
                // Found function declaration
                const name_part = trimmed[idx + 3 ..];
                const name_end = std.mem.indexOfAny(u8, name_part, &[_]u8{ '(', ' ', '\t', '\r' }) orelse name_part.len;
                const func_name = name_part[0..name_end];

                if (func_name.len > 0) {
                    const kind = if (is_pub) SymbolKind.pub_function else .function;

                    const symbol = Symbol{
                        .name = try self.allocator.dupe(u8, func_name),
                        .kind = kind,
                        .file = self.file_path,
                        .line = line_num,
                        .column = @intCast(if (is_pub) idx + 4 else idx + 1),
                        .signature = try self.allocator.dupe(u8, trimmed),
                    };

                    try node.addSymbol(symbol);
                    try result.graph.addSymbol(symbol);
                    result.symbols_found += 1;

                    // Extract function calls within this function
                    try self.extractFunctionCalls(result, func_name, line_num);
                }
            }

            line_num += 1;
        }
    }

    /// Extract struct declarations
    fn extractStructs(self: *ZigSymbolExtractor, result: *ExtractionResult, node: *GraphNode) !void {
        var lines = std.mem.splitScalar(u8, self.source, '\n');
        var line_num: u32 = 1;
        var in_struct = false;
        var struct_name: []const u8 = &.{};

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

            if (!in_struct) {
                // Look for struct declarations
                const is_pub = std.mem.startsWith(u8, trimmed, "pub ");
                const struct_start = if (is_pub)
                    std.mem.indexOf(u8, trimmed, "struct ")
                else
                    std.mem.indexOf(u8, trimmed, "struct ");

                if (struct_start) |idx| {
                    const name_part = trimmed[idx + 7 ..];
                    const name_end = std.mem.indexOfAny(u8, name_part, &[_]u8{ ' ', '{', '\t', '\r' }) orelse name_part.len;
                    struct_name = name_part[0..name_end];

                    if (struct_name.len > 0 and struct_name[0] != '=') {
                        const kind = if (is_pub) SymbolKind.pub_struct_type else .struct_type;

                        const symbol = Symbol{
                            .name = try self.allocator.dupe(u8, struct_name),
                            .kind = kind,
                            .file = self.file_path,
                            .line = line_num,
                            .column = @intCast(if (is_pub) idx + 8 else idx + 5),
                            .signature = try self.allocator.dupe(u8, trimmed),
                        };

                        try node.addSymbol(symbol);
                        try result.graph.addSymbol(symbol);
                        result.symbols_found += 1;
                        in_struct = true;
                    }
                }
            } else {
                // End of struct
                if (std.mem.indexOf(u8, line, "}") != null) {
                    in_struct = false;
                }
            }

            line_num += 1;
        }
    }

    /// Extract enum declarations
    fn extractEnums(self: *ZigSymbolExtractor, result: *ExtractionResult, node: *GraphNode) !void {
        var lines = std.mem.splitScalar(u8, self.source, '\n');
        var line_num: u32 = 1;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

            const is_pub = std.mem.startsWith(u8, trimmed, "pub ");
            const enum_start = if (is_pub)
                std.mem.indexOf(u8, trimmed, "enum ")
            else
                std.mem.indexOf(u8, trimmed, "enum ");

            if (enum_start) |idx| {
                // Check for extern enum (different syntax)
                if (std.mem.indexOf(u8, trimmed, "extern") != null) {
                    line_num += 1;
                    continue;
                }

                const name_part = trimmed[idx + 5 ..];
                const name_end = std.mem.indexOfAny(u8, name_part, &[_]u8{ ' ', '{', '\t', '\r' }) orelse name_part.len;
                const enum_name = name_part[0..name_end];

                if (enum_name.len > 0 and enum_name[0] != '=') {
                    const kind = if (is_pub) SymbolKind.pub_enum_type else .enum_type;

                    const symbol = Symbol{
                        .name = try self.allocator.dupe(u8, enum_name),
                        .kind = kind,
                        .file = self.file_path,
                        .line = line_num,
                        .column = @intCast(if (is_pub) idx + 6 else idx + 3),
                        .signature = try self.allocator.dupe(u8, trimmed),
                    };

                    try node.addSymbol(symbol);
                    try result.graph.addSymbol(symbol);
                    result.symbols_found += 1;
                }
            }

            line_num += 1;
        }
    }

    /// Extract const declarations (top-level constants)
    fn extractConstants(self: *ZigSymbolExtractor, result: *ExtractionResult, node: *GraphNode) !void {
        var lines = std.mem.splitScalar(u8, self.source, '\n');
        var line_num: u32 = 1;

        while (lines.next()) |line| {
            const trimmed = std.mem.trimLeft(u8, line, &std.ascii.whitespace);
            const new_indent = line.len - trimmed.len;

            // Only capture top-level (indent 0 or 1) consts
            if (new_indent > 4) {
                line_num += 1;
                continue;
            }

            const is_pub = std.mem.startsWith(u8, trimmed, "pub ");
            const const_start = if (is_pub)
                std.mem.indexOf(u8, trimmed, "const ")
            else
                std.mem.indexOf(u8, trimmed, "const ");

            if (const_start) |idx| {
                const name_part = trimmed[idx + 6 ..];
                const name_end = std.mem.indexOfAny(u8, name_part, &[_]u8{ ' ', ':', '=', '\t', '\r' }) orelse name_part.len;
                const const_name = name_part[0..name_end];

                if (const_name.len > 0) {
                    const kind = if (is_pub) SymbolKind.pub_constant else .constant;

                    const symbol = Symbol{
                        .name = try self.allocator.dupe(u8, const_name),
                        .kind = kind,
                        .file = self.file_path,
                        .line = line_num,
                        .column = @intCast(if (is_pub) idx + 7 else idx + 4),
                        .signature = try self.allocator.dupe(u8, trimmed),
                    };

                    try node.addSymbol(symbol);
                    try result.graph.addSymbol(symbol);
                    result.symbols_found += 1;
                }
            }

            line_num += 1;
        }
    }

    /// Extract @import() statements
    fn extractImports(self: *ZigSymbolExtractor, result: *ExtractionResult, node: *GraphNode) !void {
        var lines = std.mem.splitScalar(u8, self.source, '\n');
        var line_num: u32 = 1;

        while (lines.next()) |line| {
            // Find @import calls
            var import_start: usize = 0;
            while (std.mem.indexOfPos(u8, line, import_start, "@import")) |idx| {
                import_start = idx + 8;

                // Find opening paren
                const paren_open = std.mem.indexOfPos(u8, line, import_start, "(") orelse continue;
                const paren_close = std.mem.indexOfPos(u8, line, paren_open + 1, ")") orelse continue;

                // Extract import path
                const import_str = line[paren_open + 1 .. paren_close];
                const trimmed = std.mem.trim(u8, import_str, &[_]u8{ ' ', '\t', '"', '\'' });

                if (trimmed.len > 0) {
                    try node.addImport(trimmed);

                    // Add import edge to graph
                    try result.graph.addImport(self.file_path, trimmed);
                }

                import_start = paren_close + 1;
            }

            line_num += 1;
        }
    }

    /// Extract function calls within function body
    fn extractFunctionCalls(self: *ZigSymbolExtractor, result: *ExtractionResult, caller: []const u8, line: u32) !void {
        // This is a simplified version - for full implementation we'd need
        // proper AST traversal to distinguish between function calls and
        // other uses of identifiers
        _ = self;
        _ = result;
        _ = caller;
        _ = line;
        // TODO: Implement full call extraction with AST
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL API
// ═══════════════════════════════════════════════════════════════════════════════

/// Build call graph from directory of Zig files
pub fn buildCallGraph(
    allocator: std.mem.Allocator,
    root_path: []const u8,
) !ExtractionResult {
    var result = ExtractionResult.init(allocator);
    errdefer result.deinit();

    // Walk directory for .zig files
    var walker = try std.fs.cwd().walk(allocator, root_path);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        if (std.mem.endsWith(u8, entry.path, ".zig")) {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ root_path, entry.path });
            defer allocator.free(full_path);

            const source = std.fs.cwd().readFileAlloc(allocator, full_path, 10 * 1024 * 1024) catch |err| {
                try result.addError(try std.fmt.allocPrint(allocator, "Failed to read {s}: {}", .{ full_path, err }));
                continue;
            };
            defer allocator.free(source);

            const extractor = ZigSymbolExtractor.init(allocator, full_path, source);
            extractor.extractSymbols(&result) catch |err| {
                try result.addError(try std.fmt.allocPrint(allocator, "Failed to parse {s}: {}", .{ full_path, err }));
                continue;
            };

            result.files_processed += 1;
        }
    }

    return result;
}

/// Build call graph from single file
pub fn buildCallGraphSingleFile(
    allocator: std.mem.Allocator,
    file_path: []const u8,
) !ExtractionResult {
    var result = ExtractionResult.init(allocator);
    errdefer result.deinit();

    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);
    defer allocator.free(source);

    const extractor = ZigSymbolExtractor.init(allocator, file_path, source);
    try extractor.extractSymbols(&result);
    result.files_processed = 1;

    return result;
}

/// Find all usages of a symbol in the codebase
pub fn findUsages(
    call_graph: *CallGraph,
    symbol_name: []const u8,
    allocator: std.mem.Allocator,
) !graph.UsageList {
    return call_graph.findUsages(symbol_name, allocator);
}
