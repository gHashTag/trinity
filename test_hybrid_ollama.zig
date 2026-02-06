// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID IGLA + OLLAMA LOCAL CODER
// ═══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
// 1. Symbolic (IGLA): 100+ patterns, 2-30μs
// 2. LLM (Ollama qwen2.5-coder): Fluent code/chat via HTTP
// 3. 100% local - no cloud
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const local_chat = @import("src/vibeec/igla_local_chat.zig");

const MODEL = "qwen2.5-coder:7b";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     HYBRID IGLA + OLLAMA LOCAL CODER v1.0                                     \n", .{});
    std.debug.print("     Symbolic (IGLA) + qwen2.5-coder:7b (Ollama)                               \n", .{});
    std.debug.print("     100% Local | No Cloud | M1 Pro Optimized                                  \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // Initialize symbolic chat
    var symbolic = local_chat.IglaLocalChat.init();

    // Test queries
    const queries = [_][]const u8{
        // Symbolic hits
        "привет",
        "hello",
        "как дела?",
        "tell me a joke",
        "кто тебя создал?",
        // LLM fallback
        "write factorial in zig",
        "what is recursion",
    };

    std.debug.print("╔═════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    HYBRID IGLA + OLLAMA DEMO                                ║\n", .{});
    std.debug.print("╠═════════════════════════════════════════════════════════════════════════════╣\n", .{});

    for (queries, 0..) |query, i| {
        const start = std.time.microTimestamp();
        
        // Try symbolic first
        const sym_result = symbolic.respond(query);
        
        if (sym_result.category != .Unknown and sym_result.confidence >= 0.3) {
            // Symbolic hit
            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
            const lang = switch (sym_result.language) {
                .Russian => "RU",
                .English => "EN",
                .Chinese => "CN",
                .Unknown => "??",
            };
            std.debug.print("║ [{d}] [SYM] [{s}] \"{s}\"\n", .{i + 1, lang, query});
            std.debug.print("║     Conf: {d:.0}% | Time: {d}μs\n", .{sym_result.confidence * 100, elapsed});
            
            const display_len = @min(70, sym_result.response.len);
            std.debug.print("║     → {s}...\n", .{sym_result.response[0..display_len]});
        } else {
            // LLM fallback via Ollama (using curl)
            std.debug.print("║ [{d}] [LLM] [EN] \"{s}\"\n", .{i + 1, query});
            std.debug.print("║     Calling qwen2.5-coder:7b via Ollama...\n", .{});
            
            const llm_response = callOllamaCurl(allocator, query) catch |err| {
                const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
                std.debug.print("║     ERROR: {} | Time: {d}ms\n", .{err, elapsed / 1000});
                std.debug.print("║     Fallback: {s}\n", .{sym_result.response[0..@min(60, sym_result.response.len)]});
                continue;
            };
            defer allocator.free(llm_response);
            
            const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));
            std.debug.print("║     Time: {d}ms\n", .{elapsed / 1000});
            
            // Print first 200 chars, clean up newlines for display
            const display_len = @min(250, llm_response.len);
            std.debug.print("║     → {s}\n", .{llm_response[0..display_len]});
        }
        std.debug.print("║\n", .{});
    }

    std.debug.print("╠═════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL                        ║\n", .{});
    std.debug.print("╚═════════════════════════════════════════════════════════════════════════════╝\n", .{});
}

fn callOllamaCurl(allocator: std.mem.Allocator, prompt: []const u8) ![]u8 {
    // Use curl to call Ollama API
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "curl", "-s", "http://localhost:11434/api/generate",
            "-d", try std.fmt.allocPrint(allocator, 
                \\{{"model":"{s}","prompt":"{s}","stream":false,"options":{{"num_predict":100}}}}
            , .{MODEL, prompt}),
        },
    });
    defer allocator.free(result.stderr);
    
    if (result.term.Exited != 0) {
        allocator.free(result.stdout);
        return error.CurlFailed;
    }

    // Parse JSON to extract "response" field
    if (std.mem.indexOf(u8, result.stdout, "\"response\":\"")) |start_idx| {
        const response_start = start_idx + 12;
        // Find closing quote (handle escapes simply)
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
        
        // Unescape
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
