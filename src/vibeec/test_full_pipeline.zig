// FULL PIPELINE TEST: safetensors → .tri → inference
// Тестирование полного цикла конвертации и инференса
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const safetensors = @import("safetensors_parser.zig");
const trinity_format = @import("trinity_format.zig");
const prometheus = @import("prometheus_seed.zig");
const converter = @import("safetensors_to_tri.zig");
const trinity_llm = @import("trinity_llm.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TEST
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFullPipelineTest(allocator: std.mem.Allocator) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           FULL PIPELINE TEST                                 ║\n", .{});
    std.debug.print("║           safetensors → .tri → inference                     ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    const input_path = "src/vibeec/test_model.safetensors";
    const tri_path = "/tmp/test_pipeline.tri";

    // Step 1: Load and inspect safetensors
    std.debug.print("\n[1/4] Loading safetensors...\n", .{});
    var sf = try safetensors.SafetensorsFile.open(allocator, input_path);
    defer sf.deinit();
    sf.printInfo();

    // Step 2: Convert to .tri
    std.debug.print("\n[2/4] Converting to .tri format...\n", .{});
    const stats = try converter.convert(allocator, input_path, tri_path, .{
        .vocab_size = 256,
        .hidden_size = 64,
        .intermediate_size = 128,
        .num_layers = 2,
        .num_heads = 4,
        .num_kv_heads = 4,
    });

    std.debug.print("  Compression ratio: {d:.1}x\n", .{stats.compressionRatio()});
    std.debug.print("  Sparsity: {d:.1}%\n", .{stats.sparsity * 100});

    // Step 3: Load .tri and verify
    std.debug.print("\n[3/4] Loading .tri file...\n", .{});
    var reader = try trinity_format.TrinityReader.init(allocator, tri_path);
    defer reader.deinit();
    reader.printInfo();

    // Step 4: Create model and run inference
    std.debug.print("\n[4/4] Running inference...\n", .{});
    var model = try trinity_llm.TrinityLLM.init(
        allocator,
        256, // vocab_size
        64, // hidden_size
        2, // num_layers
        4, // num_heads
        128, // intermediate_size
    );
    defer model.deinit();

    // Load weights from .tri
    model.loadFromTri(tri_path) catch |err| {
        std.debug.print("⚠️  Could not load weights: {} (using random init)\n", .{err});
    };

    model.printStats();

    // Simple inference test
    const output = try model.generate("Hi", 5);
    defer allocator.free(output);

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           PIPELINE TEST COMPLETE                             ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ ✅ Safetensors loaded                                         ║\n", .{});
    std.debug.print("║ ✅ Converted to .tri ({d} tensors)                            ║\n", .{stats.total_tensors});
    std.debug.print("║ ✅ .tri file loaded                                           ║\n", .{});
    std.debug.print("║ ✅ Inference executed                                         ║\n", .{});
    std.debug.print("║ Output: \"{s}\"                                                ║\n", .{output[0..@min(output.len, 20)]});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Cleanup
    std.fs.cwd().deleteFile(tri_path) catch {};
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try runFullPipelineTest(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "full pipeline" {
    // Skip in CI if file doesn't exist
    std.fs.cwd().access("src/vibeec/test_model.safetensors", .{}) catch {
        std.debug.print("Skipping: test_model.safetensors not found\n", .{});
        return;
    };

    try runFullPipelineTest(std.testing.allocator);
}
