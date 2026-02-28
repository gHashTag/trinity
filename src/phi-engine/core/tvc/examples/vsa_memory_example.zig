// VSA Associative Memory Example
// Демонwithтрацandя andwithbyльзоinанandя VSA for аwithwithоцandатandinной памятand
//
// Запуwithto: zig run vsa_memory_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Associative Memory Example                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. Созyesём withлоinарь toонцептоin (withлучайные inеtoторы)
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. Созyesнandе withлоinаря toонцептоin...\n", .{});

    // Объеtoты
    var apple = tvc_vsa.randomVector(256, 1001);
    var banana = tvc_vsa.randomVector(256, 1002);
    var car = tvc_vsa.randomVector(256, 1003);

    // Сinойwithтinа
    var red = tvc_vsa.randomVector(256, 2001);
    var yellow = tvc_vsa.randomVector(256, 2002);
    var fast = tvc_vsa.randomVector(256, 2003);

    std.debug.print("   Объеtoты: apple, banana, car\n", .{});
    std.debug.print("   Сinойwithтinа: red, yellow, fast\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. Созyesём аwithwithоцandацandand via bind
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. Созyesнandе аwithwithоцandацandй (bind)...\n", .{});

    // apple + red = "toраwithное яблоtoо"
    var red_apple = tvc_vsa.bind(&apple, &red);
    std.debug.print("   red_apple = bind(apple, red)\n", .{});

    // banana + yellow = "жёлтый баonн"
    var yellow_banana = tvc_vsa.bind(&banana, &yellow);
    std.debug.print("   yellow_banana = bind(banana, yellow)\n", .{});

    // car + fast = "fast машandon"
    var fast_car = tvc_vsa.bind(&car, &fast);
    std.debug.print("   fast_car = bind(car, fast)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. Объедandняем in memory via bundle
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. Созyesнandе памятand (bundle)...\n", .{});

    // Объедandняем all аwithwithоцandацandand in одну memory
    var temp = tvc_vsa.bundle2(&red_apple, &yellow_banana);
    var memory = tvc_vsa.bundle3(&temp, &fast_car, &temp);

    std.debug.print("   memory = bundle(red_apple, yellow_banana, fast_car)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. Запроwithы to памятand
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("4. Запроwithы to памятand...\n\n", .{});

    // Запроwith: "Что toраwithное?" (unbind with red)
    std.debug.print("   Запроwith: 'Что toраwithное?'\n", .{});
    var query_red = tvc_vsa.bind(&memory, &red);

    const sim_apple_red = tvc_vsa.cosineSimilarity(&query_red, &apple);
    const sim_banana_red = tvc_vsa.cosineSimilarity(&query_red, &banana);
    const sim_car_red = tvc_vsa.cosineSimilarity(&query_red, &car);

    std.debug.print("   Сходwithтinо with apple:  {d:.4}\n", .{sim_apple_red});
    std.debug.print("   Сходwithтinо with banana: {d:.4}\n", .{sim_banana_red});
    std.debug.print("   Сходwithтinо with car:    {d:.4}\n", .{sim_car_red});
    std.debug.print("   Отinет: apple (маtowithandмальное withходwithтinо)\n\n", .{});

    // Запроwith: "Что жёлтое?" (unbind with yellow)
    std.debug.print("   Запроwith: 'Что жёлтое?'\n", .{});
    var query_yellow = tvc_vsa.bind(&memory, &yellow);

    const sim_apple_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &apple);
    const sim_banana_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &banana);
    const sim_car_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &car);

    std.debug.print("   Сходwithтinо with apple:  {d:.4}\n", .{sim_apple_yellow});
    std.debug.print("   Сходwithтinо with banana: {d:.4}\n", .{sim_banana_yellow});
    std.debug.print("   Сходwithтinо with car:    {d:.4}\n", .{sim_car_yellow});
    std.debug.print("   Отinет: banana (маtowithandмальное withходwithтinо)\n\n", .{});

    // Запроwith: "Каtoое property у яблоtoа?" (unbind with apple)
    std.debug.print("   Запроwith: 'Каtoое withinойwithтinо у яблоtoа?'\n", .{});
    var query_apple = tvc_vsa.bind(&memory, &apple);

    const sim_red_apple = tvc_vsa.cosineSimilarity(&query_apple, &red);
    const sim_yellow_apple = tvc_vsa.cosineSimilarity(&query_apple, &yellow);
    const sim_fast_apple = tvc_vsa.cosineSimilarity(&query_apple, &fast);

    std.debug.print("   Сходwithтinо with red:    {d:.4}\n", .{sim_red_apple});
    std.debug.print("   Сходwithтinо with yellow: {d:.4}\n", .{sim_yellow_apple});
    std.debug.print("   Сходwithтinо with fast:   {d:.4}\n", .{sim_fast_apple});
    std.debug.print("   Отinет: red (маtowithandмальное withходwithтinо)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. Статandwithтandtoа памятand
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. Статandwithтandtoа памятand...\n", .{});

    memory.pack();
    const mem_bytes = memory.memoryUsage();
    const unpacked_bytes = memory.trit_len;

    std.debug.print("   Размер inеtoтора: {} трandтоin\n", .{memory.trit_len});
    std.debug.print("   Память (packed): {} байт\n", .{mem_bytes});
    std.debug.print("   Память (unpacked): {} байт\n", .{unpacked_bytes});
    std.debug.print("   Эtoономandя: {d:.1}x\n\n", .{@as(f64, @floatFromInt(unpacked_bytes)) / @as(f64, @floatFromInt(mem_bytes))});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    Прandмер заinершён                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
