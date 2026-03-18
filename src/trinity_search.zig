// @origin(spec:trinity_search.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// trinity-search — Semantic search CLI using Trinity VSA
//
// Usage:
//   trinity-search "query" data.txt          # top-10 similar lines
//   trinity-search "query" data.txt -n 5     # top-5 similar lines
//   trinity-search --info                    # show engine info
//
// Each line in data.txt is encoded to a hypervector.
// The query is compared against all lines using cosine similarity.
// Results are sorted by similarity (highest first).

const std = @import("std");
const vsa = @import("vsa.zig");
const hybrid = @import("hybrid.zig");

const HybridBigInt = hybrid.HybridBigInt;

const MAX_RESULTS = 100;
const MAX_LINES = 10000;

const SearchResult = struct {
    line_idx: usize,
    similarity: f64,
    line_start: usize,
    line_len: usize,
};

fn compareResults(_: void, a: SearchResult, b: SearchResult) bool {
    return a.similarity > b.similarity; // descending
}

fn print(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse arguments
    if (args.len < 2) {
        printUsage();
        std.process.exit(1);
    }

    // Handle --info flag
    if (std.mem.eql(u8, args[1], "--info")) {
        print("trinity-search v0.2.0\n", .{});
        print("Engine: Trinity VSA (Ternary Vector Symbolic Architecture)\n", .{});
        print("Encoding: Balanced ternary {{-1, 0, +1}}\n", .{});
        print("Max dimension: {d} trits\n", .{vsa.MAX_TRITS});
        print("SIMD: ARM64 NEON (32 trits/cycle)\n", .{});
        print("Memory per vector: ~{d} KB\n", .{@sizeOf(HybridBigInt) / 1024});
        print("Max corpus: {d} lines\n", .{MAX_LINES});
        return;
    }

    if (args.len < 3) {
        printUsage();
        std.process.exit(1);
    }

    const query_text = args[1];
    const file_path = args[2];

    // Parse -n flag
    var top_n: usize = 10;
    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-n") and i + 1 < args.len) {
            top_n = std.fmt.parseInt(usize, args[i + 1], 10) catch 10;
            i += 1;
        }
    }
    top_n = @min(top_n, MAX_RESULTS);

    // Read file
    const file_data = std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024) catch {
        print("Error: cannot read '{s}'\n", .{file_path});
        std.process.exit(1);
    };
    defer allocator.free(file_data);

    // Split into lines using static arrays
    var line_starts: [MAX_LINES]usize = undefined;
    var line_lens: [MAX_LINES]usize = undefined;
    var total_lines: usize = 0;

    var line_begin: usize = 0;
    for (file_data, 0..) |c, idx| {
        if (c == '\n') {
            const line_len = idx - line_begin;
            if (line_len > 0 and total_lines < MAX_LINES) {
                line_starts[total_lines] = line_begin;
                line_lens[total_lines] = line_len;
                total_lines += 1;
            }
            line_begin = idx + 1;
        }
    }
    // Handle last line without newline
    if (line_begin < file_data.len and total_lines < MAX_LINES) {
        const line_len = file_data.len - line_begin;
        if (line_len > 0) {
            line_starts[total_lines] = line_begin;
            line_lens[total_lines] = line_len;
            total_lines += 1;
        }
    }

    if (total_lines == 0) {
        print("Error: file '{s}' has no content\n", .{file_path});
        std.process.exit(1);
    }

    print("Indexing {d} lines from '{s}'...\n", .{ total_lines, file_path });

    // Encode query
    var timer = try std.time.Timer.start();
    var query_vec = vsa.encodeTextWords(query_text);

    // Encode all lines and compute similarity (use heap for results array)
    const results = try allocator.alloc(SearchResult, total_lines);
    defer allocator.free(results);

    for (0..total_lines) |line_idx| {
        const start = line_starts[line_idx];
        const len = @min(line_lens[line_idx], 4096);
        const line_text = file_data[start .. start + len];

        var line_vec = vsa.encodeTextWords(line_text);
        const sim = vsa.cosineSimilarity(&query_vec, &line_vec);

        results[line_idx] = .{
            .line_idx = line_idx,
            .similarity = sim,
            .line_start = start,
            .line_len = len,
        };
    }

    const elapsed_ns = timer.read();
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;

    // Sort by similarity (descending)
    std.mem.sort(SearchResult, results, {}, compareResults);

    // Print results
    const show_n = @min(top_n, total_lines);
    print("\nQuery: \"{s}\"\n", .{query_text});
    print("Results: top {d} of {d} lines ({d:.1} ms)\n", .{ show_n, total_lines, elapsed_ms });
    print("────────────────────────────────────────────────────────────\n", .{});

    for (0..show_n) |rank| {
        const r = results[rank];
        const line_text = file_data[r.line_start .. r.line_start + r.line_len];

        // Truncate long lines for display
        const display_len = @min(line_text.len, 80);
        const display = line_text[0..display_len];
        const ellipsis: []const u8 = if (line_text.len > 80) "..." else "";

        print("  {d:>3}. [{d:.4}] {s}{s}\n", .{
            rank + 1,
            r.similarity,
            display,
            ellipsis,
        });
    }

    print("────────────────────────────────────────────────────────────\n", .{});
    print("Engine: Trinity VSA | {d} trits/vector | {d:.1} ms total\n", .{
        vsa.MAX_TRITS,
        elapsed_ms,
    });
}

fn printUsage() void {
    print("trinity-search v0.2.0 — Semantic search using ternary hypervectors\n\n", .{});
    print("Usage: trinity-search <query> <file> [-n count]\n\n", .{});
    print("  Each line in <file> is encoded to a hypervector and compared\n", .{});
    print("  to the query using cosine similarity.\n\n", .{});
    print("Arguments:\n", .{});
    print("  <query>    Search query text\n", .{});
    print("  <file>     Text file (one item per line)\n", .{});
    print("  -n count   Number of results (default: 10)\n", .{});
    print("  --info     Show engine information\n\n", .{});
    print("Examples:\n", .{});
    print("  trinity-search \"machine learning\" papers.txt\n", .{});
    print("  trinity-search \"error\" log.txt -n 5\n", .{});
}
