// VSA Associative Memory Example
// [CYR:[EN]]with[CYR:[EN]]and[EN] andwithby[CYR:[EN]]in[EN]and[EN] VSA for [EN]withwith[EN]and[EN]andin[CYR:[EN]] [CYR:[EN]]and
//
// [CYR:[EN]]withto: zig run vsa_memory_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Associative Memory Example                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. [CYR:[EN]]yes[EN] with[EN]in[CYR:[EN]] to[CYR:[EN]]in (with[CYR:[EN]] in[EN]to[CYR:[EN]])
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. [CYR:[EN]]yes[EN]and[EN] with[EN]in[CYR:[EN]] to[CYR:[EN]]in...\n", .{});

    // [CYR:[EN]]to[EN]
    var apple = tvc_vsa.randomVector(256, 1001);
    var banana = tvc_vsa.randomVector(256, 1002);
    var car = tvc_vsa.randomVector(256, 1003);

    // [EN]in[EN]with[EN]in[EN]
    var red = tvc_vsa.randomVector(256, 2001);
    var yellow = tvc_vsa.randomVector(256, 2002);
    var fast = tvc_vsa.randomVector(256, 2003);

    std.debug.print("   [CYR:[EN]]to[EN]: apple, banana, car\n", .{});
    std.debug.print("   [EN]in[EN]with[EN]in[EN]: red, yellow, fast\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. [CYR:[EN]]yes[EN] [EN]withwith[EN]and[EN]andand via bind
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. [CYR:[EN]]yes[EN]and[EN] [EN]withwith[EN]and[EN]and[EN] (bind)...\n", .{});

    // apple + red = "to[EN]with[CYR:[EN]] [CYR:[EN]]to[EN]"
    var red_apple = tvc_vsa.bind(&apple, &red);
    std.debug.print("   red_apple = bind(apple, red)\n", .{});

    // banana + yellow = "[CYR:[EN]] [EN]on[EN]"
    var yellow_banana = tvc_vsa.bind(&banana, &yellow);
    std.debug.print("   yellow_banana = bind(banana, yellow)\n", .{});

    // car + fast = "fast [CYR:[EN]]andon"
    var fast_car = tvc_vsa.bind(&car, &fast);
    std.debug.print("   fast_car = bind(car, fast)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. [CYR:[EN]]and[CYR:[EN]] in memory via bundle
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. [CYR:[EN]]yes[EN]and[EN] [CYR:[EN]]and (bundle)...\n", .{});

    // [CYR:[EN]]and[CYR:[EN]] all [EN]withwith[EN]and[EN]andand in [CYR:[EN]] memory
    var temp = tvc_vsa.bundle2(&red_apple, &yellow_banana);
    var memory = tvc_vsa.bundle3(&temp, &fast_car, &temp);

    std.debug.print("   memory = bundle(red_apple, yellow_banana, fast_car)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. [CYR:[EN]]with[EN] to [CYR:[EN]]and
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("4. [CYR:[EN]]with[EN] to [CYR:[EN]]and...\n\n", .{});

    // [CYR:[EN]]with: "[CYR:[EN]] to[EN]with[CYR:[EN]]?" (unbind with red)
    std.debug.print("   [CYR:[EN]]with: '[CYR:[EN]] to[EN]with[CYR:[EN]]?'\n", .{});
    var query_red = tvc_vsa.bind(&memory, &red);

    const sim_apple_red = tvc_vsa.cosineSimilarity(&query_red, &apple);
    const sim_banana_red = tvc_vsa.cosineSimilarity(&query_red, &banana);
    const sim_car_red = tvc_vsa.cosineSimilarity(&query_red, &car);

    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with apple:  {d:.4}\n", .{sim_apple_red});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with banana: {d:.4}\n", .{sim_banana_red});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with car:    {d:.4}\n", .{sim_car_red});
    std.debug.print("   [EN]in[EN]: apple ([EN]towithand[CYR:[EN]] with[CYR:[EN]]with[EN]in[EN])\n\n", .{});

    // [CYR:[EN]]with: "[CYR:[EN]] [CYR:[EN]]?" (unbind with yellow)
    std.debug.print("   [CYR:[EN]]with: '[CYR:[EN]] [CYR:[EN]]?'\n", .{});
    var query_yellow = tvc_vsa.bind(&memory, &yellow);

    const sim_apple_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &apple);
    const sim_banana_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &banana);
    const sim_car_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &car);

    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with apple:  {d:.4}\n", .{sim_apple_yellow});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with banana: {d:.4}\n", .{sim_banana_yellow});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with car:    {d:.4}\n", .{sim_car_yellow});
    std.debug.print("   [EN]in[EN]: banana ([EN]towithand[CYR:[EN]] with[CYR:[EN]]with[EN]in[EN])\n\n", .{});

    // [CYR:[EN]]with: "[EN]to[EN] property [EN] [CYR:[EN]]to[EN]?" (unbind with apple)
    std.debug.print("   [CYR:[EN]]with: '[EN]to[EN] within[EN]with[EN]in[EN] [EN] [CYR:[EN]]to[EN]?'\n", .{});
    var query_apple = tvc_vsa.bind(&memory, &apple);

    const sim_red_apple = tvc_vsa.cosineSimilarity(&query_apple, &red);
    const sim_yellow_apple = tvc_vsa.cosineSimilarity(&query_apple, &yellow);
    const sim_fast_apple = tvc_vsa.cosineSimilarity(&query_apple, &fast);

    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with red:    {d:.4}\n", .{sim_red_apple});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with yellow: {d:.4}\n", .{sim_yellow_apple});
    std.debug.print("   [CYR:[EN]]with[EN]in[EN] with fast:   {d:.4}\n", .{sim_fast_apple});
    std.debug.print("   [EN]in[EN]: red ([EN]towithand[CYR:[EN]] with[CYR:[EN]]with[EN]in[EN])\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. [CYR:[EN]]andwith[EN]andto[EN] [CYR:[EN]]and
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. [CYR:[EN]]andwith[EN]andto[EN] [CYR:[EN]]and...\n", .{});

    memory.pack();
    const mem_bytes = memory.memoryUsage();
    const unpacked_bytes = memory.trit_len;

    std.debug.print("   [CYR:[EN]] in[EN]to[CYR:[EN]]: {} [EN]and[EN]in\n", .{memory.trit_len});
    std.debug.print("   Memory (packed): {} [CYR:[EN]]\n", .{mem_bytes});
    std.debug.print("   Memory (unpacked): {} [CYR:[EN]]\n", .{unpacked_bytes});
    std.debug.print("   [EN]to[CYR:[EN]]and[EN]: {d:.1}x\n\n", .{@as(f64, @floatFromInt(unpacked_bytes)) / @as(f64, @floatFromInt(mem_bytes))});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    [EN]and[CYR:[EN]] [EN]in[CYR:[EN]]                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
