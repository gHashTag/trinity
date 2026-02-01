// PROMETHEUS CLI - Конвертер моделей в троичный формат
// Превращает профанные float32 веса в священные триты
// φ² + 1/φ² = 3 = TRINITY
//
// Использование:
//   prometheus convert <input.safetensors> <output.tri> [--threshold 0.1]
//   prometheus info <model.tri>
//   prometheus test <model.tri>

const std = @import("std");
const safetensors = @import("safetensors_parser.zig");
const prometheus = @import("prometheus_seed.zig");
const mistral = @import("mistral_loader.zig");
const trinity_llm = @import("trinity_llm.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "convert")) {
        try cmdConvert(allocator, args);
    } else if (std.mem.eql(u8, command, "info")) {
        try cmdInfo(allocator, args);
    } else if (std.mem.eql(u8, command, "test")) {
        try cmdTest(allocator, args);
    } else if (std.mem.eql(u8, command, "help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\╔══════════════════════════════════════════════════════════════╗
        \\║           PROMETHEUS - Model Converter                       ║
        \\║           φ² + 1/φ² = 3 = TRINITY                            ║
        \\╠══════════════════════════════════════════════════════════════╣
        \\║                                                              ║
        \\║ USAGE:                                                       ║
        \\║   prometheus convert <input.safetensors> <output.tri>        ║
        \\║   prometheus info <file.safetensors|file.tri>                ║
        \\║   prometheus test <model.tri>                                ║
        \\║   prometheus help                                            ║
        \\║                                                              ║
        \\║ OPTIONS:                                                     ║
        \\║   --threshold <float>  Quantization threshold (default: 0.1)║
        \\║   --config <tiny|7b>   Model config (default: 7b)           ║
        \\║                                                              ║
        \\║ EXAMPLES:                                                    ║
        \\║   prometheus convert mistral.safetensors mistral.tri         ║
        \\║   prometheus info mistral.safetensors                        ║
        \\║   prometheus test mistral.tri                                ║
        \\║                                                              ║
        \\╚══════════════════════════════════════════════════════════════╝
        \\
    , .{});
}

fn cmdConvert(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Error: convert requires input and output paths\n", .{});
        std.debug.print("Usage: prometheus convert <input.safetensors> <output.tri>\n", .{});
        return;
    }

    const input_path = args[2];
    const output_path = args[3];

    // Парсим опции
    var threshold: f32 = 0.1;
    var config = mistral.MistralConfig.mistral7B();

    var i: usize = 4;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--threshold") and i + 1 < args.len) {
            threshold = std.fmt.parseFloat(f32, args[i + 1]) catch 0.1;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--config") and i + 1 < args.len) {
            if (std.mem.eql(u8, args[i + 1], "tiny")) {
                config = mistral.MistralConfig.tiny();
            }
            i += 1;
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           PROMETHEUS: CONVERTING MODEL                       ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Input:     {s:<49} ║\n", .{input_path});
    std.debug.print("║ Output:    {s:<49} ║\n", .{output_path});
    std.debug.print("║ Threshold: {d:<49.2} ║\n", .{threshold});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Загружаем и конвертируем
    var loader = mistral.MistralLoader.init(allocator, config, threshold);
    defer loader.deinit();

    loader.loadFromSafetensors(input_path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };

    // Сохраняем
    loader.save(output_path) catch |err| {
        std.debug.print("Error saving model: {}\n", .{err});
        return;
    };

    std.debug.print("\n✓ Conversion complete!\n", .{});
}

fn cmdInfo(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Error: info requires a file path\n", .{});
        std.debug.print("Usage: prometheus info <file.safetensors|file.tri>\n", .{});
        return;
    }

    const path = args[2];

    if (std.mem.endsWith(u8, path, ".safetensors")) {
        // Safetensors файл
        var sf = safetensors.SafetensorsFile.open(allocator, path) catch |err| {
            std.debug.print("Error opening file: {}\n", .{err});
            return;
        };
        defer sf.deinit();

        sf.printInfo();
    } else if (std.mem.endsWith(u8, path, ".tri")) {
        // Trinity файл
        var model = mistral.TrinityModelFile.load(allocator, path) catch |err| {
            std.debug.print("Error loading model: {}\n", .{err});
            return;
        };
        defer model.deinit();

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TRINITY MODEL INFO                                 ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Vocab size:       {d:<42} ║\n", .{model.config.vocab_size});
        std.debug.print("║ Hidden size:      {d:<42} ║\n", .{model.config.hidden_size});
        std.debug.print("║ Num layers:       {d:<42} ║\n", .{model.config.num_hidden_layers});
        std.debug.print("║ Num heads:        {d:<42} ║\n", .{model.config.num_attention_heads});
        std.debug.print("║ Layers loaded:    {d:<42} ║\n", .{model.layers.items.len});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    } else {
        std.debug.print("Unknown file format. Supported: .safetensors, .tri\n", .{});
    }
}

fn cmdTest(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Error: test requires a model path\n", .{});
        std.debug.print("Usage: prometheus test <model.tri>\n", .{});
        return;
    }

    const path = args[2];

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           PROMETHEUS: TESTING MODEL                          ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ Loading: {s:<51} ║\n", .{path});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

    // Загружаем модель
    var model = mistral.TrinityModelFile.load(allocator, path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();

    // Создаём LLM
    var llm = try trinity_llm.TrinityLLM.init(
        allocator,
        model.config.vocab_size,
        model.config.hidden_size,
        model.config.num_hidden_layers,
        model.config.num_attention_heads,
        model.config.intermediate_size,
    );
    defer llm.deinit();

    llm.printStats();

    // Тестовая генерация
    std.debug.print("\nTest generation:\n", .{});
    std.debug.print("Prompt: \"Hello\"\n", .{});

    const output = llm.generate("Hello", 10) catch |err| {
        std.debug.print("Generation error: {}\n", .{err});
        return;
    };
    defer allocator.free(output);

    std.debug.print("Output: \"{s}\"\n", .{output});
    std.debug.print("\n✓ Test complete!\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cli help" {
    // Просто проверяем, что printUsage не падает
    printUsage();
}
