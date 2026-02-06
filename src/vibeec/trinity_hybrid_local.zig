// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY HYBRID LOCAL CODER v1.0.2
// ═══════════════════════════════════════════════════════════════════════════════
//
// Production-ready hybrid local coder with:
// 1. IGLA Symbolic: 100+ patterns, 2-45μs (instant)
// 2. Ollama LLM: qwen2.5-coder:7b for fluent code/chat (4-30s)
// 3. 100% Local - No cloud, full privacy
//
// USAGE:
//   trinity-hybrid [query]     - One-shot query
//   trinity-hybrid             - Interactive mode
//   trinity-hybrid --help      - Show help
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const local_chat = @import("igla_local_chat.zig");

const VERSION = "1.0.2";
const MODEL = "qwen2.5-coder:7b";
const OLLAMA_URL = "http://localhost:11434/api/generate";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse arguments
    if (args.len > 1) {
        const arg = args[1];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        }
        if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            std.debug.print("Trinity Hybrid Local Coder v{s}\n", .{VERSION});
            return;
        }
        // One-shot mode
        try processQuery(allocator, arg);
        return;
    }

    // Interactive mode
    printBanner();
    try interactiveMode(allocator);
}

fn printBanner() void {
    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TRINITY HYBRID LOCAL CODER v{s}                             ║\n", .{VERSION});
    std.debug.print("║     IGLA Symbolic (instant) + Ollama LLM (fluent)                ║\n", .{});
    std.debug.print("║     100% Local | No Cloud | M1 Pro Optimized                     ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Commands: /help, /quit, /stats                                  ║\n", .{});
    std.debug.print("║  Model: {s:<30}                       ║\n", .{MODEL});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
}

fn printHelp() void {
    std.debug.print(
        \\Trinity Hybrid Local Coder v{s}
        \\
        \\USAGE:
        \\  trinity-hybrid              Interactive mode
        \\  trinity-hybrid [query]      One-shot query
        \\  trinity-hybrid --help       Show this help
        \\  trinity-hybrid --version    Show version
        \\
        \\ARCHITECTURE:
        \\  1. IGLA Symbolic: 100+ patterns, instant (2-45μs)
        \\  2. Ollama LLM: qwen2.5-coder:7b, fluent (4-30s)
        \\
        \\REQUIREMENTS:
        \\  - Ollama installed and running (ollama serve)
        \\  - qwen2.5-coder:7b model pulled (ollama pull qwen2.5-coder:7b)
        \\
        \\EXAMPLES:
        \\  trinity-hybrid "hello"                   # Symbolic (instant)
        \\  trinity-hybrid "write factorial in zig"  # LLM (fluent code)
        \\  trinity-hybrid "explain recursion"       # LLM (fluent text)
        \\
        \\phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
        \\
    , .{VERSION});
}

fn interactiveMode(allocator: std.mem.Allocator) !void {
    var symbolic = local_chat.IglaLocalChat.init();
    var total_queries: usize = 0;
    var symbolic_hits: usize = 0;
    var llm_calls: usize = 0;

    const stdin_file = std.fs.File.stdin();
    var buf: [4096]u8 = undefined;

    while (true) {
        std.debug.print("[You] > ", .{});

        // Read line using low-level read
        var line_len: usize = 0;
        while (line_len < buf.len - 1) {
            const read_result = stdin_file.read(buf[line_len .. line_len + 1]) catch break;
            if (read_result == 0) break; // EOF
            if (buf[line_len] == '\n') break;
            line_len += 1;
        }

        if (line_len == 0) {
            if (buf[0] == '\n') continue; // Empty line
            break; // EOF
        }
        const input = std.mem.trim(u8, buf[0..line_len], &std.ascii.whitespace);
        if (input.len == 0) continue;

        // Handle commands
        if (input[0] == '/') {
            if (std.mem.eql(u8, input, "/quit") or std.mem.eql(u8, input, "/exit")) {
                break;
            }
            if (std.mem.eql(u8, input, "/help")) {
                std.debug.print("Commands: /help, /quit, /stats\n", .{});
                std.debug.print("Just type your question to chat!\n", .{});
                continue;
            }
            if (std.mem.eql(u8, input, "/stats")) {
                const hit_rate = if (total_queries > 0) 
                    @as(f32, @floatFromInt(symbolic_hits)) / @as(f32, @floatFromInt(total_queries)) * 100
                else 0;
                std.debug.print("Stats: {d} queries, {d} symbolic ({d:.0}%), {d} LLM\n", .{
                    total_queries, symbolic_hits, hit_rate, llm_calls
                });
                continue;
            }
            std.debug.print("Unknown command. Try /help\n", .{});
            continue;
        }

        total_queries += 1;
        const start = std.time.microTimestamp();

        // Try symbolic first
        const sym_result = symbolic.respond(input);

        if (sym_result.category != .Unknown and sym_result.confidence >= 0.3) {
            // Symbolic hit
            symbolic_hits += 1;
            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
            std.debug.print("[Trinity] (Symbolic, {d:.0}%, {d}μs)\n", .{sym_result.confidence * 100, elapsed});
            std.debug.print("{s}\n\n", .{sym_result.response});
        } else {
            // LLM fallback
            llm_calls += 1;
            std.debug.print("[Trinity] Calling Ollama...\n", .{});

            const llm_response = callOllama(allocator, input) catch |err| {
                const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
                std.debug.print("[Trinity] (Error: {}, {d}ms)\n", .{err, elapsed / 1000});
                std.debug.print("Fallback: {s}\n\n", .{sym_result.response});
                continue;
            };
            defer allocator.free(llm_response);

            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
            std.debug.print("[Trinity] (LLM, {d}ms)\n", .{elapsed / 1000});
            std.debug.print("{s}\n\n", .{llm_response});
        }
    }

    std.debug.print("\nGoodbye! phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
}

fn processQuery(allocator: std.mem.Allocator, query: []const u8) !void {
    var symbolic = local_chat.IglaLocalChat.init();
    const start = std.time.microTimestamp();

    // Try symbolic first
    const sym_result = symbolic.respond(query);

    if (sym_result.category != .Unknown and sym_result.confidence >= 0.3) {
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
        std.debug.print("[Symbolic, {d:.0}%, {d}μs]\n", .{sym_result.confidence * 100, elapsed});
        std.debug.print("{s}\n", .{sym_result.response});
    } else {
        // LLM fallback
        const llm_response = callOllama(allocator, query) catch |err| {
            std.debug.print("[Error: {}]\n", .{err});
            std.debug.print("{s}\n", .{sym_result.response});
            return;
        };
        defer allocator.free(llm_response);

        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
        std.debug.print("[LLM, {d}ms]\n", .{elapsed / 1000});
        std.debug.print("{s}\n", .{llm_response});
    }
}

fn callOllama(allocator: std.mem.Allocator, prompt: []const u8) ![]u8 {
    const json_payload = try std.fmt.allocPrint(allocator,
        \\{{"model":"{s}","prompt":"{s}","stream":false,"options":{{"num_predict":256}}}}
    , .{MODEL, prompt});
    defer allocator.free(json_payload);

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", OLLAMA_URL, "-d", json_payload },
    });
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return error.CurlFailed;
    }

    // Parse "response" field from JSON
    if (std.mem.indexOf(u8, result.stdout, "\"response\":\"")) |start_idx| {
        const response_start = start_idx + 12;
        var end_idx = response_start;
        var in_escape = false;
        while (end_idx < result.stdout.len) {
            if (in_escape) {
                in_escape = false;
            } else if (result.stdout[end_idx] == '\\') {
                in_escape = true;
            } else if (result.stdout[end_idx] == '"') {
                break;
            }
            end_idx += 1;
        }

        const response = result.stdout[response_start..end_idx];
        var unescaped = try allocator.alloc(u8, response.len);
        var j: usize = 0;
        var k: usize = 0;
        while (k < response.len) {
            if (response[k] == '\\' and k + 1 < response.len) {
                k += 1;
                unescaped[j] = switch (response[k]) {
                    'n' => '\n',
                    't' => '\t',
                    'r' => '\r',
                    '\\' => '\\',
                    '"' => '"',
                    else => response[k],
                };
            } else {
                unescaped[j] = response[k];
            }
            k += 1;
            j += 1;
        }

        allocator.free(result.stdout);
        return allocator.realloc(unescaped, j) catch unescaped[0..j];
    }

    allocator.free(result.stdout);
    return error.ParseFailed;
}
