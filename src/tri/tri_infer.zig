// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI INFER — HSLM Inference CLI Wrapper
// ═══════════════════════════════════════════════════════════════════════════════
//
// Commands:
//   tri infer --checkpoint <path>                   Generate text (default prompts)
//   tri infer --checkpoint <path> --prompt "Hello"   Generate with custom prompt
//   tri infer --checkpoint <path> --eval <data>      Evaluate perplexity
//   tri infer --checkpoint <path> --eval <data> --eval-lines 500
//   tri infer --checkpoint <path> --temperature 0.6 --top-k 10
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const print = std.debug.print;
const RESET = "\x1b[0m";
const GOLDEN = "\x1b[38;5;220m";
const CYAN = "\x1b[36m";
const GRAY = "\x1b[90m";

pub fn runInferCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        printUsage();
        return;
    }

    // Check that --checkpoint was provided
    var has_checkpoint = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--checkpoint")) {
            has_checkpoint = true;
            break;
        }
    }

    if (!has_checkpoint) {
        print("{s}\xe2\x9a\xa0 --checkpoint is required{s}\n\n", .{ "\x1b[33m", RESET });
        printUsage();
        return;
    }

    // Build argv: "hslm-train" "generate" + all passthrough args
    // Max 64 args should be more than enough
    var argv_buf: [66][]const u8 = undefined;
    argv_buf[0] = "zig-out/bin/hslm-train";
    argv_buf[1] = "generate";
    const pass_len = @min(args.len, 64);
    for (0..pass_len) |i| {
        argv_buf[2 + i] = args[i];
    }
    const argv = argv_buf[0 .. 2 + pass_len];

    print("{s}\xf0\x9f\x94\xae HSLM Inference{s}\n", .{ GOLDEN, RESET });
    print("{s}   Launching hslm-train generate...{s}\n\n", .{ GRAY, RESET });

    var child = std.process.Child.init(argv, allocator);
    child.stderr_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                print("\n{s}\xe2\x9c\x97 hslm-train exited with code {d}{s}\n", .{ "\x1b[31m", code, RESET });
            }
        },
        else => {
            print("\n{s}\xe2\x9c\x97 hslm-train terminated abnormally{s}\n", .{ "\x1b[31m", RESET });
        },
    }
}

fn printUsage() void {
    print(
        \\{s}tri infer{s} — HSLM Inference & Evaluation
        \\
        \\{s}Usage:{s}
        \\  tri infer --checkpoint <path>                    Generate text
        \\  tri infer --checkpoint <path> --prompt "Hello"   Custom prompt
        \\  tri infer --checkpoint <path> --eval <data>      PPL evaluation
        \\
        \\{s}Options:{s}
        \\  --checkpoint <path>   Checkpoint file (required)
        \\  --prompt <text>       Custom prompt text
        \\  --eval <path>         Data file for PPL evaluation
        \\  --eval-lines <N>      Max lines to load (default: 1000)
        \\  --temperature <f>     Sampling temperature (default: 0.8)
        \\  --top-k <N>           Top-K sampling (default: 27)
        \\  --rep-penalty <f>     Repetition penalty (default: 1.2)
        \\  --max-tokens <N>      Max tokens to generate (default: 200)
        \\  --context <N>         Context length (default: 27)
        \\
    , .{ GOLDEN, RESET, CYAN, RESET, CYAN, RESET });
}
