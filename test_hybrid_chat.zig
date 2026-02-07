// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID IGLA + LLM LOCAL CODER DEMO
// ═══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
// 1. Symbolic (IGLA) for fast pattern matching (greetings, FAQ, math proofs)
// 2. LLM fallback for fluent code/chat (complex queries)
// 3. 100% local - no cloud, full privacy
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const hybrid = @import("src/vibeec/igla_hybrid_chat.zig");
const local_chat = @import("src/vibeec/igla_local_chat.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     HYBRID IGLA + LLM LOCAL CODER v1.0                                        \n", .{});
    std.debug.print("     Symbolic Pattern Matcher + GGUF LLM Fallback                              \n", .{});
    std.debug.print("     100% Local | No Cloud | M1 Pro Optimized                                  \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // Model path - try BitNet first, fallback to symbolic only
    const model_path: ?[]const u8 = blk: {
        // Check if BitNet model exists
        const bitnet_path = "models/bitnet-2b-fixed.gguf";
        std.fs.cwd().access(bitnet_path, .{}) catch {
            std.debug.print("[INFO] Model not found: {s}\n", .{bitnet_path});
            std.debug.print("[INFO] Running in SYMBOLIC ONLY mode (no LLM fallback)\n\n", .{});
            break :blk null;
        };
        std.debug.print("[INFO] Found model: {s}\n\n", .{bitnet_path});
        break :blk bitnet_path;
    };

    // Initialize hybrid chat
    var chat = try hybrid.IglaHybridChat.init(allocator, model_path);
    defer chat.deinit();

    // Test queries - mix of symbolic hits and LLM fallback
    const queries = [_][]const u8{
        // Symbolic hits (fast patterns)
        "привет",
        "hello",
        "как дела?",
        "who are you?",
        "расскажи шутку",
        "tell me a joke",
        "кто тебя создал?",
        "what can you do?",
        // LLM fallback (complex/unknown queries)
        "explain quantum computing briefly",
        "write factorial function",
        "what is the capital of France?",
    };

    var symbolic_hits: usize = 0;
    var llm_calls: usize = 0;
    var total_latency: u64 = 0;

    std.debug.print("╔═════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                           HYBRID CHAT DEMO                                  ║\n", .{});
    std.debug.print("╠═════════════════════════════════════════════════════════════════════════════╣\n", .{});

    for (queries, 0..) |query, i| {
        const start = std.time.microTimestamp();
        const response = try chat.respond(query);
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
        total_latency += elapsed;

        const source_str = switch (response.source) {
            .Symbolic => "SYM",
            .LLM => "LLM",
            .Error => "ERR",
        };

        const lang_str = switch (response.language) {
            .Russian => "RU",
            .English => "EN",
            .Chinese => "CN",
            .Unknown => "??",
        };

        if (response.source == .Symbolic) {
            symbolic_hits += 1;
        } else if (response.source == .LLM) {
            llm_calls += 1;
        }

        std.debug.print("║ [{d:2}] [{s}] [{s}] \"{s}\"\n", .{
            i + 1,
            source_str,
            lang_str,
            query,
        });

        // Truncate response for display
        const max_response_len: usize = 60;
        const display_response = if (response.response.len > max_response_len)
            response.response[0..max_response_len]
        else
            response.response;

        std.debug.print("║      Conf: {d:.0}% | Time: {d}us\n", .{
            response.confidence * 100,
            elapsed,
        });
        std.debug.print("║      → {s}...\n", .{display_response});
        std.debug.print("║\n", .{});
    }

    // Stats
    const stats = chat.getStats();
    const avg_latency = total_latency / queries.len;

    std.debug.print("╠═════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                              STATISTICS                                     ║\n", .{});
    std.debug.print("╠═════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Total Queries:       {d:<10}\n", .{stats.total_queries});
    std.debug.print("║  Symbolic Hits:       {d:<10} ({d:.0}%)\n", .{
        stats.symbolic_hits,
        stats.symbolic_hit_rate * 100,
    });
    std.debug.print("║  LLM Calls:           {d:<10}\n", .{stats.llm_calls});
    std.debug.print("║  LLM Loaded:          {s:<10}\n", .{
        if (stats.llm_loaded) "YES" else "NO",
    });
    std.debug.print("║  Avg Latency:         {d}us\n", .{avg_latency});
    std.debug.print("╠═════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL                        ║\n", .{});
    std.debug.print("╚═════════════════════════════════════════════════════════════════════════════╝\n", .{});
}
