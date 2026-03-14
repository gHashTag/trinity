// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - REPL Functions
// ═══════════════════════════════════════════════════════════════════════════════
//
// REPL commands, prompt, input processing, and interactive mode.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("../tri_colors.zig");
const print_utils = @import("print.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const RESET = colors.RESET;

const Command = print_utils.Command;

pub fn printPrompt(state: anytype) void {
    const mode_name = state.mode.getName();
    const lang_ext = state.language.getExtension();
    std.debug.print("{s}[{s}]{s} {s}[{s}]{s} > ", .{ GREEN, mode_name, RESET, GOLDEN, lang_ext, RESET });
}

pub fn processREPLCommand(state: anytype, cmd: []const u8) void {
    if (std.mem.eql(u8, cmd, "/chat")) {
        state.mode = .Chat;
        std.debug.print("{s}Mode: Chat{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/code")) {
        state.mode = .CodeGen;
        std.debug.print("{s}Mode: Code Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/fix")) {
        state.mode = .BugFix;
        std.debug.print("{s}Mode: Bug Fix{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/explain")) {
        state.mode = .Explain;
        std.debug.print("{s}Mode: Explain{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/test")) {
        state.mode = .Test;
        std.debug.print("{s}Mode: Test Generation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/doc")) {
        state.mode = .Document;
        std.debug.print("{s}Mode: Documentation{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/refactor")) {
        state.mode = .Refactor;
        std.debug.print("{s}Mode: Refactor{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/reason")) {
        state.mode = .Reason;
        std.debug.print("{s}Mode: Chain-of-Thought Reasoning{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/zig")) {
        state.language = .Zig;
        std.debug.print("{s}Language: Zig{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/python")) {
        state.language = .Python;
        std.debug.print("{s}Language: Python{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/rust")) {
        state.language = .Rust;
        std.debug.print("{s}Language: Rust{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/js") or std.mem.eql(u8, cmd, "/javascript")) {
        state.language = .JavaScript;
        std.debug.print("{s}Language: JavaScript{s}\n", .{ GREEN, RESET });
    } else if (std.mem.eql(u8, cmd, "/stats")) {
        print_utils.printStats(state);
    } else if (std.mem.eql(u8, cmd, "/verbose")) {
        state.verbose = !state.verbose;
        std.debug.print("{s}Verbose: {s}{s}\n", .{ GREEN, if (state.verbose) "ON" else "OFF", RESET });
    } else if (std.mem.eql(u8, cmd, "/help")) {
        print_utils.printREPLHelp();
    } else if (std.mem.eql(u8, cmd, "/quit") or std.mem.eql(u8, cmd, "/exit") or std.mem.eql(u8, cmd, "/q")) {
        state.running = false;
        std.debug.print("{s}Goodbye! phi^2 + 1/phi^2 = 3{s}\n", .{ GOLDEN, RESET });
    } else {
        std.debug.print("{s}Unknown command. Type /help for commands.{s}\n", .{ RED, RESET });
    }
}

pub fn detectMode(input: []const u8) ?std.meta.DeclEnum(@import("../trinity_swe").SWETaskType) {
    const lower_input = std.ascii.allocLowerPrint(std.heap.page_allocator, input) catch return null;
    defer std.heap.page_allocator.free(lower_input);

    if (std.mem.indexOf(u8, lower_input, "fix") != null or
        std.mem.indexOf(u8, lower_input, "bug") != null)
    {
        return .BugFix;
    }
    if (std.mem.indexOf(u8, lower_input, "explain") != null or
        std.mem.indexOf(u8, lower_input, "what") != null or
        std.mem.indexOf(u8, lower_input, "how") != null)
    {
        return .Explain;
    }
    if (std.mem.indexOf(u8, lower_input, "test") != null or
        std.mem.indexOf(u8, lower_input, "unit") != null)
    {
        return .Test;
    }
    if (std.mem.indexOf(u8, lower_input, "doc") != null or
        std.mem.indexOf(u8, lower_input, "document") != null)
    {
        return .Document;
    }
    if (std.mem.indexOf(u8, lower_input, "refactor") != null or
        std.mem.indexOf(u8, lower_input, "improve") != null or
        std.mem.indexOf(u8, lower_input, "clean") != null)
    {
        return .Refactor;
    }
    if (std.mem.indexOf(u8, lower_input, "reason") != null or
        std.mem.indexOf(u8, lower_input, "why") != null or
        std.mem.indexOf(u8, lower_input, "step") != null)
    {
        return .Reason;
    }

    return null;
}

pub fn processInput(state: anytype, input: []const u8) void {
    const trimmed = std.mem.trim(u8, input, " \t\n\r");
    if (trimmed.len == 0) return;

    // Check for REPL commands
    if (trimmed[0] == '/') {
        processREPLCommand(state, trimmed);
        return;
    }

    // Detect mode from input
    const detected_mode = detectMode(trimmed);
    const actual_mode = if (detected_mode != null) detected_mode.? else state.mode;

    // Process based on mode
    switch (actual_mode) {
        .Chat => {
            if (state.chat_agent.respond(trimmed)) |chat_response| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, chat_response.response, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .CodeGen => {
            if (state.coder.generate(trimmed)) |code| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, code, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .BugFix => {
            if (state.agent.fix(trimmed)) |result| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, result, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .Explain => {
            if (state.agent.explain(trimmed)) |explanation| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, explanation, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .Test => {
            if (state.agent.test(trimmed)) |tests| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, tests, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .Document => {
            if (state.agent.document(trimmed)) |docs| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, docs, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .Refactor => {
            if (state.agent.refactor(trimmed)) |suggestions| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, suggestions, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
        .Reason => {
            if (state.agent.reason(trimmed)) |reasoning| {
                std.debug.print("\n{s}{s}{s}\n\n", .{ WHITE, reasoning, RESET });
            } else |err| {
                std.debug.print("{s}Error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            }
        },
    }
}

pub fn runInteractiveMode(state: anytype) !void {
    print_utils.printBanner();

    const reader = std.io.getStdIn().reader();
    var buffer: [4096]u8 = undefined;

    std.debug.print("{s}Type /help for commands, /quit to exit.{s}\n\n", .{ GRAY, RESET });

    while (state.running) {
        printPrompt(state);

        const line = reader.readUntilDelimiterOrEof(&buffer, '\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        const input = std.mem.trim(u8, line, " \t\r");

        if (input.len == 0) continue;

        processInput(state, input);
    }
}
