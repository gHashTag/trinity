// VSA Associative Memory Example
// withand andwithbyinand VSA for withandin and
//
// withto: zig run vsa_memory_example.zig

const std = @import("std");
const tvc_vsa = @import("../tvc_vsa.zig");
const HybridBigInt = tvc_vsa.HybridBigInt;

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         VSA Associative Memory Example                       ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. yes within toin (with into)
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("1. yesand within toin...\n", .{});

    // to
    var apple = tvc_vsa.randomVector(256, 1001);
    var banana = tvc_vsa.randomVector(256, 1002);
    var car = tvc_vsa.randomVector(256, 1003);

    // inwithin
    var red = tvc_vsa.randomVector(256, 2001);
    var yellow = tvc_vsa.randomVector(256, 2002);
    var fast = tvc_vsa.randomVector(256, 2003);

    std.debug.print("   to: apple, banana, car\n", .{});
    std.debug.print("   inwithin: red, yellow, fast\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. yes withandand via bind
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("2. yesand withand (bind)...\n", .{});

    // apple + red = "towith to"
    var red_apple = tvc_vsa.bind(&apple, &red);
    std.debug.print("   red_apple = bind(apple, red)\n", .{});

    // banana + yellow = " on"
    var yellow_banana = tvc_vsa.bind(&banana, &yellow);
    std.debug.print("   yellow_banana = bind(banana, yellow)\n", .{});

    // car + fast = "fast andon"
    var fast_car = tvc_vsa.bind(&car, &fast);
    std.debug.print("   fast_car = bind(car, fast)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. and in memory via bundle
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("3. yesand and (bundle)...\n", .{});

    // and all withandand in  memory
    var temp = tvc_vsa.bundle2(&red_apple, &yellow_banana);
    var memory = tvc_vsa.bundle3(&temp, &fast_car, &temp);

    std.debug.print("   memory = bundle(red_apple, yellow_banana, fast_car)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. with to and
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("4. with to and...\n\n", .{});

    // with: " towith?" (unbind with red)
    std.debug.print("   with: ' towith?'\n", .{});
    var query_red = tvc_vsa.bind(&memory, &red);

    const sim_apple_red = tvc_vsa.cosineSimilarity(&query_red, &apple);
    const sim_banana_red = tvc_vsa.cosineSimilarity(&query_red, &banana);
    const sim_car_red = tvc_vsa.cosineSimilarity(&query_red, &car);

    std.debug.print("   within with apple:  {d:.4}\n", .{sim_apple_red});
    std.debug.print("   within with banana: {d:.4}\n", .{sim_banana_red});
    std.debug.print("   within with car:    {d:.4}\n", .{sim_car_red});
    std.debug.print("   in: apple (towithand within)\n\n", .{});

    // with: " ?" (unbind with yellow)
    std.debug.print("   with: ' ?'\n", .{});
    var query_yellow = tvc_vsa.bind(&memory, &yellow);

    const sim_apple_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &apple);
    const sim_banana_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &banana);
    const sim_car_yellow = tvc_vsa.cosineSimilarity(&query_yellow, &car);

    std.debug.print("   within with apple:  {d:.4}\n", .{sim_apple_yellow});
    std.debug.print("   within with banana: {d:.4}\n", .{sim_banana_yellow});
    std.debug.print("   within with car:    {d:.4}\n", .{sim_car_yellow});
    std.debug.print("   in: banana (towithand within)\n\n", .{});

    // with: "to property  to?" (unbind with apple)
    std.debug.print("   with: 'to withinwithin  to?'\n", .{});
    var query_apple = tvc_vsa.bind(&memory, &apple);

    const sim_red_apple = tvc_vsa.cosineSimilarity(&query_apple, &red);
    const sim_yellow_apple = tvc_vsa.cosineSimilarity(&query_apple, &yellow);
    const sim_fast_apple = tvc_vsa.cosineSimilarity(&query_apple, &fast);

    std.debug.print("   within with red:    {d:.4}\n", .{sim_red_apple});
    std.debug.print("   within with yellow: {d:.4}\n", .{sim_yellow_apple});
    std.debug.print("   within with fast:   {d:.4}\n", .{sim_fast_apple});
    std.debug.print("   in: red (towithand within)\n\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. andwithandto and
    // ═══════════════════════════════════════════════════════════════════════════

    std.debug.print("5. andwithandto and...\n", .{});

    memory.pack();
    const mem_bytes = memory.memoryUsage();
    const unpacked_bytes = memory.trit_len;

    std.debug.print("    into: {} andin\n", .{memory.trit_len});
    std.debug.print("   Memory (packed): {} \n", .{mem_bytes});
    std.debug.print("   Memory (unpacked): {} \n", .{unpacked_bytes});
    std.debug.print("   toand: {d:.1}x\n\n", .{@as(f64, @floatFromInt(unpacked_bytes)) / @as(f64, @floatFromInt(mem_bytes))});

    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    and in                           ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}
