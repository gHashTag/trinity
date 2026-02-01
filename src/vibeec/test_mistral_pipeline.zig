// MISTRAL PIPELINE TEST
// Полный цикл: safetensors → .tri → inference
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const mistral_converter = @import("mistral_converter.zig");
const mistral_trinity = @import("mistral_trinity.zig");
const trinity_format = @import("trinity_format.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runPipelineTest(allocator);
}

pub fn runPipelineTest(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           MISTRAL TRINITY PIPELINE TEST                      ║\n", .{});
    std.debug.print("║           safetensors → .tri → inference                     ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    const input_path = "src/vibeec/test_mistral_mini.safetensors";
    const tri_path = "/tmp/mistral_mini.tri";

    // Step 1: Convert safetensors to .tri
    std.debug.print("\n[1/3] Converting safetensors → .tri...\n", .{});

    const config = mistral_converter.MistralConfig{
        .vocab_size = 256,
        .hidden_size = 64,
        .intermediate_size = 128,
        .num_hidden_layers = 2,
        .num_attention_heads = 4,
        .num_key_value_heads = 2,
    };

    const stats = try mistral_converter.convertSingleFile(allocator, input_path, tri_path, config);

    std.debug.print("  ✓ Converted {d} tensors\n", .{stats.total_tensors});
    std.debug.print("  ✓ Compression: {d:.1}x\n", .{stats.compressionRatio()});

    // Step 2: Load .tri into MistralTrinity
    std.debug.print("\n[2/3] Loading .tri into MistralTrinity...\n", .{});

    const model_config = mistral_trinity.MistralConfig{
        .vocab_size = 256,
        .hidden_size = 64,
        .intermediate_size = 128,
        .num_hidden_layers = 2,
        .num_attention_heads = 4,
        .num_key_value_heads = 2,
        .head_dim = 16,
        .max_position_embeddings = 512,
    };

    var model = try mistral_trinity.MistralTrinity.init(allocator, model_config);
    defer model.deinit();

    try model.loadFromTri(tri_path);
    model.printStats();

    // Step 3: Run inference
    std.debug.print("\n[3/3] Running inference...\n", .{});

    // Generate a few tokens
    var token: u32 = 1; // Start token
    std.debug.print("  Tokens: {d}", .{token});

    for (0..5) |pos| {
        token = try model.forward(token, pos);
        std.debug.print(" → {d}", .{token});
    }
    std.debug.print("\n", .{});

    // Cleanup
    std.fs.cwd().deleteFile(tri_path) catch {};

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           PIPELINE TEST COMPLETE                             ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ ✅ Safetensors converted to .tri                              ║\n", .{});
    std.debug.print("║ ✅ .tri loaded into MistralTrinity                            ║\n", .{});
    std.debug.print("║ ✅ Inference executed successfully                            ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

test "mistral pipeline" {
    // Skip if test file doesn't exist
    std.fs.cwd().access("src/vibeec/test_mistral_mini.safetensors", .{}) catch {
        std.debug.print("Skipping: test_mistral_mini.safetensors not found\n", .{});
        return;
    };

    try runPipelineTest(std.testing.allocator);
}
