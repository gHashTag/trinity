// Trinity Knowledge Graph CLI
// [CYR:[TRANSLATED]]to[EN]andin[CYR:ny] and[CYR:[TRANSLATED]]with for [CYR:work]fromy with [CYR:[TRANSLATED]] [EN]on[EN]and[EN]
//
// USAGE: trinity-kg [command] [args...]
// REPL:  trinity-kg ([CYR:without] argument[EN]in)
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const kg = @import("knowledge_graph.zig");

const KnowledgeGraph = kg.KnowledgeGraph;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[TRANSLATED]A[TRANSLATED]] [CYR:[TRANSLATED]]
// ═══════════════════════════════════════════════════════════════════════════════

var graph: KnowledgeGraph = KnowledgeGraph.init();
var name_buffer: [16384]u8 = undefined; // [CYR:[TRANSLATED]] for and[CYR:[TRANSLATED]] [EN]and [CYR:[TRANSLATED]]to[EN]
var string_pool: [32768]u8 = undefined; // [CYR:[TRANSLATED]] for [CYR:[TRANSLATED]]not[EN]andI with[CYR:[TRANSLATED]]to
var string_pool_offset: usize = 0;
var current_file: ?[]const u8 = null;

/// [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] with[CYR:[TRANSLATED]]to[EN] in [CYR:[TRANSLATED]] and in[EN]in[CYR:[TRANSLATED]acts] slice
fn internString(s: []const u8) []const u8 {
    if (string_pool_offset + s.len > string_pool.len) {
        return s; // [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]not[EN], in[EN]in[CYR:[TRANSLATED]] [EN]and[EN]andon[EN]
    }
    const start = string_pool_offset;
    @memcpy(string_pool[start .. start + s.len], s);
    string_pool_offset += s.len;
    return string_pool[start .. start + s.len];
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var args = std.process.args();
    _ = args.skip(); // [CYR:[TRANSLATED]]withto[CYR:[TRANSLATED]] and[EN]I [CYR:pro[TRANSLATED]y]

    // [EN]with[EN]and [EN]with[EN] argumenty - in[CYR:y[TRANSLATED]I[EN]] to[CYR:[TRANSLATED]] and in[CYR:y[TRANSLATED]]and[EN]
    if (args.next()) |cmd| {
        var arg_list: [10][]const u8 = undefined;
        var arg_count: usize = 0;

        while (args.next()) |arg| {
            if (arg_count < 10) {
                arg_list[arg_count] = arg;
                arg_count += 1;
            }
        }

        try executeCommand(cmd, arg_list[0..arg_count], stdout);
        return;
    }

    // REPL [CYR:[TRANSLATED]]and[EN]
    try printBanner(stdout);

    var line_buf: [1024]u8 = undefined;

    while (true) {
        try stdout.print("\n\x1b[36mtrinity-kg>\x1b[0m ", .{});

        const line = stdin.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        } orelse break;

        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        // [CYR:[TRANSLATED]]withand[EN] to[CYR:[TRANSLATED]]
        var tokens = std.mem.tokenizeAny(u8, trimmed, " \t");
        const cmd = tokens.next() orelse continue;

        var arg_list: [10][]const u8 = undefined;
        var arg_count: usize = 0;

        while (tokens.next()) |arg| {
            if (arg_count < 10) {
                arg_list[arg_count] = arg;
                arg_count += 1;
            }
        }

        if (std.mem.eql(u8, cmd, "exit") or std.mem.eql(u8, cmd, "quit")) {
            try stdout.print("\x1b[33m[CYR:[TRANSLATED]]! φ² + 1/φ² = 3\x1b[0m\n", .{});
            break;
        }

        executeCommand(cmd, arg_list[0..arg_count], stdout) catch |err| {
            try stdout.print("\x1b[31mError: {}\x1b[0m\n", .{err});
        };
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:[TRANSLATED]A[TRANSLATED]]
// ═══════════════════════════════════════════════════════════════════════════════

fn executeCommand(cmd: []const u8, args: [][]const u8, writer: anytype) !void {
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "?")) {
        try printHelp(writer);
    } else if (std.mem.eql(u8, cmd, "add")) {
        try cmdAdd(args, writer);
    } else if (std.mem.eql(u8, cmd, "query") or std.mem.eql(u8, cmd, "q")) {
        try cmdQuery(args, writer);
    } else if (std.mem.eql(u8, cmd, "save")) {
        try cmdSave(args, writer);
    } else if (std.mem.eql(u8, cmd, "load")) {
        try cmdLoad(args, writer);
    } else if (std.mem.eql(u8, cmd, "stats")) {
        try cmdStats(writer);
    } else if (std.mem.eql(u8, cmd, "list")) {
        try cmdList(writer);
    } else if (std.mem.eql(u8, cmd, "clear")) {
        graph = KnowledgeGraph.init();
        try writer.print("\x1b[32m[CYR:[TRANSLATED]] [EN]and[CYR:[TRANSLATED]].\x1b[0m\n", .{});
    } else {
        try writer.print("\x1b[31m[EN]and[EN]in[EN]with[EN]onI to[CYR:[TRANSLATED]]: {s}\x1b[0m\n", .{cmd});
        try writer.print("[EN]in[EN]and[EN] 'help' for with[CYR:law]intoand.\n", .{});
    }
}

/// [CYR:[TRANSLATED]] add: [CYR:[TRANSLATED]]inand[EN] [EN]to[EN]
fn cmdAdd(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31m[EN]with[CYR:[EN]l[EN]]in[EN]and[EN]: add <subject> <predicate> <object>\x1b[0m\n", .{});
        try writer.print("[EN]and[CYR:[TRANSLATED]]: add Paris capital_of France\n", .{});
        return;
    }

    // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] with[CYR:[TRANSLATED]]toand that[EN]y [EN]and [EN]or in [CYR:[TRANSLATED]I[EN]]and
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    graph.addTriple(subject, predicate, object);

    try writer.print("\x1b[32m✓ [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]:\x1b[0m {s} \x1b[33m{s}\x1b[0m {s}\n", .{ subject, predicate, object });
}

/// [CYR:[TRANSLATED]] query: [CYR:[EN]pro]with to [CYR:[TRANSLATED]]
fn cmdQuery(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31m[EN]with[CYR:[EN]l[EN]]in[EN]and[EN]: query <subject|?> <predicate> <object|?>\x1b[0m\n", .{});
        try writer.print("[EN]and[CYR:[TRANSLATED]]: query Paris capital_of ?\n", .{});
        try writer.print("[EN]and[CYR:[TRANSLATED]]: query ? capital_of France\n", .{});
        return;
    }

    // [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] with[CYR:[TRANSLATED]]toand for [EN]andwithto[EN]
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    const is_subject_query = std.mem.eql(u8, subject, "?");
    const is_object_query = std.mem.eql(u8, object, "?");

    if (is_subject_query and is_object_query) {
        try writer.print("\x1b[31m[CYR:[TRANSLATED]] andwithto[CYR:ate] [CYR:[EN]l]to[EN] subject [CYR:[TRANSLATED]] object, not [CYR:[TRANSLATED]].\x1b[0m\n", .{});
        return;
    }

    if (!is_subject_query and !is_object_query) {
        try writer.print("\x1b[31m[CYR:[TRANSLATED]] [EN]to[CYR:[EN]ate] ? for andwithto[CYR:[TRANSLATED]go] element[EN].\x1b[0m\n", .{});
        return;
    }

    try writer.print("\x1b[36m[CYR:[EN]pro]with:\x1b[0m {s} {s} {s}\n", .{ subject, predicate, object });

    if (is_object_query) {
        // [CYR:[TRANSLATED]] object: query(subject, predicate, ?)
        const result = graph.queryObject(subject, predicate);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗ [EN] on[CYR:[TRANSLATED]]\x1b[0m\n", .{});
        }
    } else {
        // [CYR:[TRANSLATED]] subject: query(?, predicate, object)
        const result = graph.querySubject(predicate, object);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗ [EN] on[CYR:[TRANSLATED]]\x1b[0m\n", .{});
        }
    }
}

/// [CYR:[TRANSLATED]] save: with[CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]]
fn cmdSave(args: [][]const u8, writer: anytype) !void {
    const path = if (args.len > 0) args[0] else (current_file orelse "graph.trkg");

    try graph.save(path);
    current_file = path;

    try writer.print("\x1b[32m✓ [CYR:[TRANSLATED]] with[CYR:[TRANSLATED]]:\x1b[0m {s}\n", .{path});
}

/// [CYR:[TRANSLATED]] load: [CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]]
fn cmdLoad(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31m[EN]with[CYR:[EN]l[EN]]in[EN]and[EN]: load <path>\x1b[0m\n", .{});
        return;
    }

    const path = args[0];

    graph = try KnowledgeGraph.load(path, &name_buffer);
    current_file = path;

    const s = graph.stats();
    try writer.print("\x1b[32m✓ [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]:\x1b[0m {s}\n", .{path});
    try writer.print("  [CYR:[TRANSLATED]]with[CYR:[TRANSLATED]]: {d}, [CYR:[TRANSLATED]]and[EN]: {d}, [EN]to[EN]in: {d}\n", .{ s.entities, s.relations, s.triples });
}

/// [CYR:[TRANSLATED]] stats: with[CYR:[TRANSLATED]]andwith[EN]andto[EN]
fn cmdStats(writer: anytype) !void {
    const s = graph.stats();

    try writer.print("\n\x1b[36m╔═══════════════════════════════════════╗\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m       TRINITY KNOWLEDGE GRAPH         \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m╠═══════════════════════════════════════╣\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m  [CYR:[TRANSLATED]]with[CYR:[TRANSLATED]]:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.entities});
    try writer.print("\x1b[36m║\x1b[0m  [CYR:[TRANSLATED]]and[EN]:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.relations});
    try writer.print("\x1b[36m║\x1b[0m  [EN]to[EN]in:     \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.triples});
    try writer.print("\x1b[36m╚═══════════════════════════════════════╝\x1b[0m\n", .{});

    if (current_file) |f| {
        try writer.print("  [CYR:[TRANSLATED]]: {s}\n", .{f});
    }
}

/// [CYR:[TRANSLATED]] list: with[EN]andwith[EN]to with[CYR:[TRANSLATED]]with[CYR:[TRANSLATED]]
fn cmdList(writer: anytype) !void {
    try writer.print("\n\x1b[36m[CYR:[TRANSLATED]]with[EN]and:\x1b[0m\n", .{});
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            try writer.print("  [{d}] {s}\n", .{ e.id, e.name });
        }
    }

    try writer.print("\n\x1b[36m[CYR:[TRANSLATED]]andI:\x1b[0m\n", .{});
    for (0..graph.relation_count) |i| {
        if (graph.relations[i]) |r| {
            try writer.print("  [{d}] {s}\n", .{ r.id, r.name });
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI
// ═══════════════════════════════════════════════════════════════════════════════

fn printBanner(writer: anytype) !void {
    try writer.print("\n", .{});
    try writer.print("\x1b[36m╔═══════════════════════════════════════════════════════════════╗\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m     \x1b[33m████████╗██████╗ ██╗███╗   ██╗██╗████████╗██╗   ██╗\x1b[0m     \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m     \x1b[33m╚══██╔══╝██╔══██╗██║████╗  ██║██║╚══██╔══╝╚██╗ ██╔╝\x1b[0m     \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m        \x1b[33m██║   ██████╔╝██║██╔██╗ ██║██║   ██║    ╚████╔╝\x1b[0m      \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m        \x1b[33m██║   ██╔══██╗██║██║╚██╗██║██║   ██║     ╚██╔╝\x1b[0m       \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m        \x1b[33m██║   ██║  ██║██║██║ ╚████║██║   ██║      ██║\x1b[0m        \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m        \x1b[33m╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝      ╚═╝\x1b[0m        \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m                                                               \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m              \x1b[35mKNOWLEDGE GRAPH CLI v1.0\x1b[0m                       \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m              \x1b[90mφ² + 1/φ² = 3\x1b[0m                                  \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m╚═══════════════════════════════════════════════════════════════╝\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("[EN]in[EN]and[EN] \x1b[33mhelp\x1b[0m for with[CYR:law]intoand, \x1b[33mexit\x1b[0m for in[CYR:y[TRANSLATED]].\n", .{});
}

fn printHelp(writer: anytype) !void {
    try writer.print("\n\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\x1b[33m[CYR:[TRANSLATED]A[TRANSLATED]]:\x1b[0m\n", .{});
    try writer.print("\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32madd\x1b[0m <subject> <predicate> <object>\n", .{});
    try writer.print("      [CYR:[TRANSLATED]]inand[EN] [EN]to[EN] in [CYR:[TRANSLATED]]\n", .{});
    try writer.print("      [EN]and[CYR:[TRANSLATED]]: \x1b[90madd Paris capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mquery\x1b[0m <subject|?> <predicate> <object|?>\n", .{});
    try writer.print("      [CYR:[EN]pro]with to [CYR:[TRANSLATED]] (? = andwithto[CYR:[TRANSLATED]])\n", .{});
    try writer.print("      [EN]and[CYR:[TRANSLATED]]: \x1b[90mquery Paris capital_of ?\x1b[0m\n", .{});
    try writer.print("      [EN]and[CYR:[TRANSLATED]]: \x1b[90mquery ? capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32msave\x1b[0m [path]\n", .{});
    try writer.print("      [CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]] in file\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mload\x1b[0m <path>\n", .{});
    try writer.print("      [CYR:[TRANSLATED]]and[EN] [CYR:[TRANSLATED]] and[EN] file[EN]\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mstats\x1b[0m\n", .{});
    try writer.print("      [EN]to[CYR:[EN]ate] with[CYR:[TRANSLATED]]andwith[EN]andto[EN] [CYR:[TRANSLATED]]\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mlist\x1b[0m\n", .{});
    try writer.print("      [EN]to[CYR:[EN]ate] inwith[EN] with[CYR:[TRANSLATED]]with[EN]and and from[CYR:[TRANSLATED]]andI\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mclear\x1b[0m\n", .{});
    try writer.print("      [EN]andwith[EN]and[EN] [CYR:[TRANSLATED]]\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mexit\x1b[0m\n", .{});
    try writer.print("      [CYR:Vy[EN]]and and[EN] [CYR:pro[TRANSLATED]y]\n", .{});
    try writer.print("\n", .{});
}
