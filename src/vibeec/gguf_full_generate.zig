// GGUF FULL TEXT GENERATION
// Generate text using complete transformer model
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const model_mod = @import("gguf_model.zig");
const inference = @import("gguf_inference.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/tinyllama-1.1b-q8_0.gguf";

    std.debug.print("\n", .{});
    std.debug.print("GGUF FULL TEXT GENERATION\n", .{});
    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
    std.debug.print("\n", .{});

    var model = model_mod.FullModel.init(allocator, path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    model.printConfig();

    std.debug.print("\nLoading all weights (this may take a while)...\n", .{});
    var timer = try std.time.Timer.start();

    model.loadWeights() catch |err| {
        std.debug.print("Error loading weights: {}\n", .{err});
        return;
    };

    const load_time = timer.read();
    std.debug.print("Weights loaded in {d:.2} seconds\n", .{@as(f64, @floatFromInt(load_time)) / 1e9});

    // Load tokenizer
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
                std.debug.print("Loaded {d} tokens\n", .{arr.len});
            }
        }
    }
    defer if (tokens) |t| allocator.free(t);

    // Generation
    std.debug.print("\n", .{});
    std.debug.print("GENERATING TEXT\n", .{});
    std.debug.print("================\n", .{});

    // Start with BOS token (usually 1)
    var current_token: u32 = 1;
    const num_tokens: usize = 20;
    const temperature: f32 = 0.7;

    std.debug.print("Prompt: <BOS>\n", .{});
    std.debug.print("Generating {d} tokens (temp={d:.1})...\n\n", .{ num_tokens, temperature });

    model.resetKVCache();
    timer.reset();

    var generated: [32]u32 = undefined;
    var i: usize = 0;
    while (i < num_tokens) : (i += 1) {
        const next_token = model.generate(current_token, i, temperature) catch |err| {
            std.debug.print("\nGeneration error at token {d}: {}\n", .{ i, err });
            break;
        };
        generated[i] = next_token;
        current_token = next_token;

        // Print progress
        if ((i + 1) % 5 == 0) {
            std.debug.print("  Generated {d}/{d} tokens...\r", .{ i + 1, num_tokens });
        }
    }

    const gen_time = timer.read();

    std.debug.print("\n\nGenerated tokens: ", .{});
    for (generated[0..i]) |t| {
        std.debug.print("{d} ", .{t});
    }
    std.debug.print("\n", .{});

    // Decode
    if (tokens) |tok_list| {
        std.debug.print("\nDecoded text: ", .{});
        for (generated[0..i]) |t| {
            if (t < tok_list.len) {
                std.debug.print("{s}", .{tok_list[t]});
            }
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("STATS\n", .{});
    std.debug.print("  Tokens generated: {d}\n", .{i});
    std.debug.print("  Time: {d:.2} seconds\n", .{@as(f64, @floatFromInt(gen_time)) / 1e9});
    std.debug.print("  Speed: {d:.2} tokens/sec\n", .{@as(f64, @floatFromInt(i)) / (@as(f64, @floatFromInt(gen_time)) / 1e9)});

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
