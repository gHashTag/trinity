// @origin(manual) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI BATTLE — LLM Battle Arena CLI Wrapper
// ═══════════════════════════════════════════════════════════════════════════════
//
// Routes `tri battle <cmd>` to the arena binary.
// Pattern: same as tri_infer.zig (subprocess delegation)
//
// Commands:
//   tri battle serve           Start arena HTTP server on :8080
//   tri battle battle <prompt> Run CLI battle
//   tri battle leaderboard     Show ELO rankings
//   tri battle bench <cat>     Run benchmark suite
//   tri battle tasks           List task catalog
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const print = std.debug.print;
const RESET = "\x1b[0m";
const GOLDEN = "\x1b[38;5;220m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";

pub fn runBattleCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printUsage();
        return;
    }

    // Build argv: "zig-out/bin/arena" + all passthrough args
    var argv_buf: [66][]const u8 = undefined;
    argv_buf[0] = "zig-out/bin/arena";
    const pass_len = @min(args.len, 64);
    for (0..pass_len) |i| {
        argv_buf[1 + i] = args[i];
    }
    const argv = argv_buf[0 .. 1 + pass_len];

    print("{s}\xe2\x9a\x94 Trinity Arena 2.0{s}\n", .{ GOLDEN, RESET });
    print("{s}   Launching arena...{s}\n\n", .{ GRAY, RESET });

    var child = std.process.Child.init(argv, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                print("\n{s}\xe2\x9c\x97 arena exited with code {d}{s}\n", .{ "\x1b[31m", code, RESET });
            }
        },
        else => {
            print("\n{s}\xe2\x9c\x97 arena terminated abnormally{s}\n", .{ "\x1b[31m", RESET });
        },
    }
}

fn printUsage() void {
    print(
        \\{s}tri battle{s} — LLM Battle Arena (Trinity Arena 2.0)
        \\
        \\{s}Commands:{s}
        \\  tri battle serve                Start HTTP server on :8080
        \\  tri battle battle <prompt>      Run a CLI battle
        \\  tri battle leaderboard          Show ELO rankings
        \\  tri battle bench <category>     Run benchmark suite
        \\  tri battle tasks                List task catalog
        \\  tri battle register <n> <kind>  Register a fighter
        \\
        \\{s}Examples:{s}
        \\  tri battle battle "What is 2+2?" --a trinity-hslm --b echo
        \\  tri battle bench math
        \\  tri battle serve
        \\
    , .{ GOLDEN, RESET, CYAN, RESET, CYAN, RESET });
}
