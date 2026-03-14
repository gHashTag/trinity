// @origin(spec:tri_search.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI SEARCH COMMAND
// ═══════════════════════════════════════════════════════════════════════════════
//
// TVC-powered code search command for TRI CLI.
// Usage: tri search <query> [--top-k N] [--min-sim X] [--format json|pretty]
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const colors = @import("tri_colors.zig");

// Simplified output format enum (Phase 1)
const OutputFormat = enum {
    pretty,
    json,
    markdown,
};

// Simplified search result (Phase 1)
const SearchResult = struct {
    symbol_name: []const u8,
    file_path: []const u8,
    line_number: u32,
    similarity: f32,
    symbol_kind: []const u8,
    snippet: []const u8,
};

// Simplified search results (Phase 1)
const SearchResults = struct {
    count: usize,
    query_time_ms: u64,
    total_indexed: usize,
    results: []const SearchResult,
};

pub fn runSearchCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;

    const GREEN = colors.GREEN;
    const GOLDEN = colors.GOLDEN;
    const CYAN = colors.CYAN;
    const YELLOW = colors.YELLOW;
    const GRAY = colors.GRAY;
    const RED = colors.RED;
    const RESET = colors.RESET;

    // Default options
    var top_k: usize = 10;
    var min_sim: f32 = 0.3;
    var format: OutputFormat = .pretty;
    var reindex: bool = false;
    var show_stats: bool = false;

    // Parse arguments
    var i: usize = 0;
    var query: ?[]const u8 = null;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--top-k") or std.mem.eql(u8, arg, "-k")) {
            if (i + 1 >= args.len) {
                std.debug.print("{s}Error:{s} --top-k requires a value\n", .{ RED, RESET });
                return;
            }
            i += 1;
            top_k = std.fmt.parseInt(usize, args[i], 10) catch 10;
        } else if (std.mem.eql(u8, arg, "--min-sim") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 >= args.len) {
                std.debug.print("{s}Error:{s} --min-sim requires a value\n", .{ RED, RESET });
                return;
            }
            i += 1;
            min_sim = std.fmt.parseFloat(f32, args[i]) catch 0.3;
        } else if (std.mem.eql(u8, arg, "--format") or std.mem.eql(u8, arg, "-f")) {
            if (i + 1 >= args.len) {
                std.debug.print("{s}Error:{s} --format requires a value\n", .{ RED, RESET });
                return;
            }
            i += 1;
            format = if (std.mem.eql(u8, args[i], "json"))
                .json
            else if (std.mem.eql(u8, args[i], "markdown"))
                .markdown
            else
                .pretty;
        } else if (std.mem.eql(u8, arg, "--reindex") or std.mem.eql(u8, arg, "-r")) {
            reindex = true;
        } else if (std.mem.eql(u8, arg, "--stats")) {
            show_stats = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printSearchHelp();
            return;
        } else if (query == null) {
            query = arg;
        } else {
            std.debug.print("{s}Warning:{s} Unexpected argument: {s}\n", .{ YELLOW, RESET, arg });
        }
    }

    // Show stats only
    if (show_stats) {
        std.debug.print("{s}TVC Indexer Statistics{s}\n", .{ GOLDEN, RESET });
        std.debug.print("═════════════════════════════════\n", .{});
        std.debug.print("{s}Phase 1 implementation{s} - Full indexer coming in Cycle 71\n\n", .{ YELLOW, RESET });
        std.debug.print("To enable TVC-powered indexing:\n", .{});
        std.debug.print("  1. Install tree-sitter: {s}brew install tree-sitter{s}\n", .{ CYAN, RESET });
        std.debug.print("  2. Build tree-sitter-zig grammar\n", .{});
        std.debug.print("  3. Rebuild tri with: {s}zig build tri{s}\n\n", .{ CYAN, RESET });
        return;
    }

    // Require query
    if (query == null) {
        std.debug.print("{s}Error:{s} Query required\n\n", .{ RED, RESET });
        printSearchHelp();
        return;
    }

    // Phase 1: Show placeholder message with demo functionality
    std.debug.print("{s}═══════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}TVC-Powered Search: '{s}'{s}\n", .{ GREEN, query.?, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("{s}Phase 1 implementation{s} - TVC Indexer Cycle 70\n\n", .{ YELLOW, RESET });
    std.debug.print("Features coming in Cycle 71:\n", .{});
    std.debug.print("  {s}✓{s} Tree-sitter AST parsing for Zig/VIBEE\n", .{ GREEN, RESET });
    std.debug.print("  {s}✓{s} Ternary Vector Computing embeddings (1.58 bits/trit!)\n", .{ GREEN, RESET });
    std.debug.print("  {s}✓{s} HNSW indexing for O(log n) search\n", .{ GREEN, RESET });
    std.debug.print("  {s}✓{s} Real-time file watching\n", .{ GREEN, RESET });
    std.debug.print("  {s}✓{s} Symbol-level semantic search\n\n", .{ GREEN, RESET });

    std.debug.print("To enable full TVC indexing:\n", .{});
    std.debug.print("  1. Install tree-sitter: {s}brew install tree-sitter{s}\n", .{ CYAN, RESET });
    std.debug.print("  2. Clone and build tree-sitter-zig:\n", .{});
    std.debug.print("     {s}git clone https://github.com/ziglang/tree-sitter-zig{s}\n", .{ GRAY, RESET });
    std.debug.print("     {s}cd tree-sitter-zig && make{s}\n", .{ GRAY, RESET });
    std.debug.print("  3. Rebuild tri with: {s}zig build tri{s}\n\n", .{ CYAN, RESET });
}

fn printSearchHelp() void {
    const GREEN = colors.GREEN;
    const CYAN = colors.CYAN;
    const GOLDEN = colors.GOLDEN;
    const RESET = colors.RESET;

    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                    {s}TVC-POWERED CODE SEARCH{s}                                    ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  {s}USAGE{s}                                                                   ║
        \\║    tri search <query> [options]                                             ║
        \\║                                                                            ║
        \\║  {s}OPTIONS{s}                                                                 ║
        \\║    -k, --top-k <n>        Maximum results to return (default: 10)            ║
        \\║    -m, --min-sim <f>      Minimum similarity threshold (default: 0.3)        ║
        \\║    -f, --format <fmt>     Output format: pretty, json, markdown             ║
        \\║    -r, --reindex          Re-index before searching                         ║
        \\║    --stats                Show index statistics                            ║
        \\║    -h, --help             Show this help message                           ║
        \\║                                                                            ║
        \\║  {s}EXAMPLES{s}                                                                ║
        \\║    tri search "vector similarity"                                          ║
        \\║    tri search "hash map" --top-k 20 --min-sim 0.6                          ║
        \\║    tri search --format json "async"                                        ║
        \\║    tri search --stats                                                      ║
        \\╚════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{ GREEN, RESET, CYAN, RESET, GOLDEN, RESET, CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDEX COMMAND
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runIndexCommand(allocator: std.mem.Allocator, args: []const []const u8) void {
    _ = allocator;

    const GREEN = colors.GREEN;
    const GOLDEN = colors.GOLDEN;
    const CYAN = colors.CYAN;
    const YELLOW = colors.YELLOW;
    const GRAY = colors.GRAY;
    const RESET = colors.RESET;

    const recursive = true;
    var show_stats: bool = false;
    var watch: bool = false;
    var clear: bool = false;

    // Parse arguments
    var i: usize = 0;
    var target_path: ?[]const u8 = null;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printIndexHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--stats")) {
            show_stats = true;
        } else if (std.mem.eql(u8, arg, "--watch") or std.mem.eql(u8, arg, "-w")) {
            watch = true;
        } else if (std.mem.eql(u8, arg, "--clear")) {
            clear = true;
        } else if (target_path == null) {
            target_path = arg;
        }
    }

    // Default to current directory
    if (target_path == null) {
        target_path = ".";
    }

    std.debug.print("{s}═══════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}TVC Code Indexer{s}\n", .{ GREEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════{s}\n\n", .{ GOLDEN, RESET });

    std.debug.print("Target: {s}{s}{s}\n", .{ CYAN, target_path.?, RESET });
    std.debug.print("Recursive: {s}{}{s}\n", .{ CYAN, recursive, RESET });
    std.debug.print("Watch mode: {s}{}{s}\n", .{ CYAN, watch, RESET });
    std.debug.print("Clear: {s}{}{s}\n\n", .{ CYAN, clear, RESET });

    std.debug.print("{s}Phase 1 implementation{s} - TVC Indexer Cycle 70\n\n", .{ YELLOW, RESET });
    std.debug.print("To enable full TVC indexing:\n", .{});
    std.debug.print("  1. Install tree-sitter: {s}brew install tree-sitter{s}\n", .{ CYAN, RESET });
    std.debug.print("  2. Clone and build tree-sitter-zig:\n", .{});
    std.debug.print("     {s}git clone https://github.com/ziglang/tree-sitter-zig{s}\n", .{ GRAY, RESET });
    std.debug.print("     {s}cd tree-sitter-zig && make{s}\n", .{ GRAY, RESET });
    std.debug.print("  3. Rebuild tri with: {s}zig build tri{s}\n\n", .{ CYAN, RESET });

    if (show_stats) {
        std.debug.print("{s}Index Statistics{s}\n", .{ GOLDEN, RESET });
        std.debug.print("  Files indexed: {s}0{s} (Phase 1)\n", .{ GRAY, RESET });
        std.debug.print("  Symbols indexed: {s}0{s} (Phase 1)\n", .{ GRAY, RESET });
        std.debug.print("  Memory usage: {s}N/A{s}\n", .{ GRAY, RESET });
    }
}

fn printIndexHelp() void {
    const GREEN = colors.GREEN;
    const CYAN = colors.CYAN;
    const GOLDEN = colors.GOLDEN;
    const RESET = colors.RESET;

    std.debug.print(
        \\╔════════════════════════════════════════════════════════════════════════════╗
        \\║                    {s}TVC-POWERED CODE INDEXER{s}                                  ║
        \\╠════════════════════════════════════════════════════════════════════════════╣
        \\║  {s}USAGE{s}                                                                   ║
        \\║    tri index [path] [options]                                               ║
        \\║                                                                            ║
        \\║  {s}OPTIONS{s}                                                                 ║
        \\║    --stats                Show index statistics                            ║
        \\║    -w, --watch            Start file watcher for auto-reindex                ║
        \\║    --clear                Clear the index                                   ║
        \\║    -h, --help             Show this help message                           ║
        \\║                                                                            ║
        \\║  {s}EXAMPLES{s}                                                                ║
        \\║    tri index .                    # Index current directory                ║
        \\║    tri index src/ --watch        # Index and watch for changes             ║
        \\║    tri index . --stats            # Show index statistics                   ║
        \\║    tri index . --clear --stats    # Clear and show empty stats              ║
        \\╚════════════════════════════════════════════════════════════════════════════╝
        \\
    , .{ GREEN, RESET, CYAN, RESET, GOLDEN, RESET, CYAN, RESET });
}
