// GGUF CHAT - Interactive Chat Interface
// Chat with LLM using GGUF model
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const model_mod = @import("gguf_model.zig");
const tokenizer_mod = @import("gguf_tokenizer.zig");
const inference = @import("gguf_inference.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/tinyllama-1.1b-q8_0.gguf";

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRINITY CHAT - LLM in Pure Zig                     ║\n", .{});
    std.debug.print("║           phi^2 + 1/phi^2 = 3 = TRINITY                      ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Load model
    std.debug.print("Loading model: {s}\n", .{path});
    var model = model_mod.FullModel.init(allocator, path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    model.printConfig();

    std.debug.print("\nLoading weights...\n", .{});
    var timer = try std.time.Timer.start();
    model.loadWeights() catch |err| {
        std.debug.print("Error loading weights: {}\n", .{err});
        return;
    };
    const load_time = timer.read();
    std.debug.print("Weights loaded in {d:.2} seconds\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

    // Initialize tokenizer
    std.debug.print("\nInitializing tokenizer...\n", .{});
    var tokenizer = tokenizer_mod.Tokenizer.init(allocator, &model.reader) catch |err| {
        std.debug.print("Error initializing tokenizer: {}\n", .{err});
        return;
    };
    defer tokenizer.deinit();
    tokenizer.printInfo();

    // Demo prompts
    const prompts = [_][]const u8{
        "Write a Python function to calculate fibonacci:",
        "What is the capital of France?",
        "Explain quantum computing in simple terms:",
    };

    const system_prompt = "You are a helpful AI assistant.";
    const max_tokens: usize = 50;
    const temperature: f32 = 0.7;

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    CHAT DEMO                                 ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    for (prompts) |user_prompt| {
        std.debug.print("\n", .{});
        std.debug.print("USER: {s}\n", .{user_prompt});
        std.debug.print("\n", .{});

        // Format prompt with chat template
        const formatted = try tokenizer_mod.ChatTemplate.TINYLLAMA.formatPrompt(
            allocator,
            system_prompt,
            user_prompt,
        );
        defer allocator.free(formatted);

        // Encode prompt
        const prompt_tokens = try tokenizer.encode(allocator, formatted);
        defer allocator.free(prompt_tokens);

        std.debug.print("Prompt tokens: {d}\n", .{prompt_tokens.len});

        // Reset KV cache for new conversation
        model.resetKVCache();

        // Process prompt tokens (prefill)
        std.debug.print("Processing prompt...\n", .{});
        timer.reset();

        var last_token: u32 = prompt_tokens[0];
        for (prompt_tokens, 0..) |token, pos| {
            _ = model.forward(token, pos) catch |err| {
                std.debug.print("Prefill error: {}\n", .{err});
                break;
            };
            last_token = token;
        }

        const prefill_time = timer.read();
        std.debug.print("Prefill: {d:.2}s ({d:.1} tok/s)\n", .{
            @as(f64, @floatFromInt(prefill_time)) / 1e9,
            @as(f64, @floatFromInt(prompt_tokens.len)) / (@as(f64, @floatFromInt(prefill_time)) / 1e9),
        });

        // Generate response
        std.debug.print("\nASSISTANT: ", .{});
        timer.reset();

        var generated: usize = 0;
        var pos = prompt_tokens.len;

        while (generated < max_tokens) {
            const next_token = model.generate(last_token, pos, temperature) catch |err| {
                std.debug.print("\nGeneration error: {}\n", .{err});
                break;
            };

            // Check for EOS
            if (next_token == tokenizer.eos_token) {
                break;
            }

            // Print token (streaming)
            const token_str = tokenizer.getToken(next_token);
            // Replace special space with regular space
            for (token_str) |c| {
                if (c == 0xE2) {
                    std.debug.print(" ", .{});
                } else if (c != 0x96 and c != 0x81) {
                    std.debug.print("{c}", .{c});
                }
            }

            last_token = next_token;
            pos += 1;
            generated += 1;
        }

        const gen_time = timer.read();
        std.debug.print("\n\n", .{});
        std.debug.print("Generated {d} tokens in {d:.2}s ({d:.2} tok/s)\n", .{
            generated,
            @as(f64, @floatFromInt(gen_time)) / 1e9,
            @as(f64, @floatFromInt(generated)) / (@as(f64, @floatFromInt(gen_time)) / 1e9),
        });
        std.debug.print("─────────────────────────────────────────────────────────────\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
