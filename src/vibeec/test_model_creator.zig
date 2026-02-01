// TEST MODEL CREATOR - Создание тестовой модели
// Генерирует маленький safetensors файл для тестирования
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "test_model.safetensors";

    std.debug.print("Creating test model: {s}\n", .{path});

    // Создаём JSON заголовок
    const header =
        \\{"model.embed_tokens.weight":{"dtype":"F32","shape":[256,64],"data_offsets":[0,65536]},"model.layers.0.self_attn.q_proj.weight":{"dtype":"F32","shape":[64,64],"data_offsets":[65536,81920]},"model.layers.0.self_attn.k_proj.weight":{"dtype":"F32","shape":[32,64],"data_offsets":[81920,90112]},"model.layers.0.self_attn.v_proj.weight":{"dtype":"F32","shape":[32,64],"data_offsets":[90112,98304]},"model.layers.0.self_attn.o_proj.weight":{"dtype":"F32","shape":[64,64],"data_offsets":[98304,114688]},"model.layers.0.mlp.gate_proj.weight":{"dtype":"F32","shape":[128,64],"data_offsets":[114688,147456]},"model.layers.0.mlp.up_proj.weight":{"dtype":"F32","shape":[128,64],"data_offsets":[147456,180224]},"model.layers.0.mlp.down_proj.weight":{"dtype":"F32","shape":[64,128],"data_offsets":[180224,212992]},"lm_head.weight":{"dtype":"F32","shape":[256,64],"data_offsets":[212992,278528]}}
    ;

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const writer = file.writer();

    // Размер заголовка
    try writer.writeInt(u64, header.len, .little);

    // Заголовок
    try writer.writeAll(header);

    // Данные (случайные float32)
    var rng = std.rand.DefaultPrng.init(42);
    const random = rng.random();

    const total_floats = 278528 / 4; // 69632 floats
    for (0..total_floats) |_| {
        const value = random.float(f32) * 2.0 - 1.0; // [-1, 1]
        try writer.writeAll(std.mem.asBytes(&value));
    }

    std.debug.print("Created test model with {d} parameters\n", .{total_floats});
    std.debug.print("File size: {d} bytes\n", .{8 + header.len + 278528});

    // Проверяем
    const stat = try std.fs.cwd().statFile(path);
    std.debug.print("Actual file size: {d} bytes\n", .{stat.size});

    // Тестируем загрузку
    const safetensors = @import("safetensors_parser.zig");
    var sf = try safetensors.SafetensorsFile.open(allocator, path);
    defer sf.deinit();

    sf.printInfo();

    std.debug.print("\n✓ Test model created successfully!\n", .{});
}
