// GGUF TEXT GENERATION DEMO
// Generate text using GGUF quantized model
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const inference = @import("gguf_inference.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/tinyllama-1.1b-q8_0.gguf";

    std.debug.print("\n", .{});
    std.debug.print("GGUF TEXT GENERATION\n", .{});
    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Loading model: {s}\n", .{path});

    var model = inference.GGUFModel.init(allocator, path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    model.printConfig();

    std.debug.print("\n", .{});
    std.debug.print("Loading embeddings...\n", .{});

    var timer = try std.time.Timer.start();
    model.loadEmbeddings() catch |err| {
        std.debug.print("Error loading embeddings: {}\n", .{err});
        return;
    };
    const load_time = timer.read();
    std.debug.print("Embeddings loaded in {d:.2} ms\n", .{@as(f64, @floatFromInt(load_time)) / 1e6});

    // Load tokenizer from GGUF metadata
    std.debug.print("\n", .{});
    std.debug.print("Loading tokenizer from GGUF...\n", .{});

    var tokens: ?[][]const u8 = null;
    if (model.reader.metadata.get("tokenizer.ggml.tokens")) |v| {
        if (v == .array) {
            const arr = v.array;
            const tok_list = allocator.alloc([]const u8, arr.len) catch null;
            if (tok_list) |list| {
                for (arr, 0..) |item, i| {
                    if (item == .string) {
                        list[i] = item.string;
                    } else {
                        list[i] = "";
                    }
                }
                tokens = list;
                std.debug.print("Loaded {d} tokens from GGUF\n", .{arr.len});
            }
        }
    }
    defer if (tokens) |t| allocator.free(t);

    // Simple generation demo
    std.debug.print("\n", .{});
    std.debug.print("GENERATION DEMO (simplified - embedding lookup only)\n", .{});
    std.debug.print("Note: Full transformer layers not implemented yet\n", .{});
    std.debug.print("\n", .{});

    // Start with token 1 (usually BOS or common token)
    var current_token: u32 = 1;
    const num_tokens: usize = 10;
    const temperature: f32 = 0.8;

    std.debug.print("Generating {d} tokens (temp={d:.1}):\n", .{ num_tokens, temperature });
    std.debug.print("Tokens: ", .{});

    timer.reset();
    var generated_tokens: [20]u32 = undefined;
    var i: usize = 0;
    while (i < num_tokens) : (i += 1) {
        const next_token = model.generateToken(current_token, temperature) catch |err| {
            std.debug.print("\nGeneration error: {}\n", .{err});
            break;
        };
        generated_tokens[i] = next_token;
        current_token = next_token;
    }
    const gen_time = timer.read();

    // Print token IDs
    std.debug.print("Token IDs: ", .{});
    for (generated_tokens[0..num_tokens]) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n", .{});

    // Print decoded text if tokenizer available
    if (tokens) |tok_list| {
        std.debug.print("Decoded:   ", .{});
        for (generated_tokens[0..num_tokens]) |t| {
            if (t < tok_list.len) {
                std.debug.print("{s}", .{tok_list[t]});
            }
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n\n", .{});
    std.debug.print("STATS\n", .{});
    std.debug.print("  Tokens generated: {d}\n", .{num_tokens});
    std.debug.print("  Time: {d:.2} ms\n", .{@as(f64, @floatFromInt(gen_time)) / 1e6});
    std.debug.print("  Speed: {d:.1} tokens/sec\n", .{@as(f64, @floatFromInt(num_tokens)) / (@as(f64, @floatFromInt(gen_time)) / 1e9)});

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
