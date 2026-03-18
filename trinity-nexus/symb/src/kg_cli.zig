// Trinity Knowledge Graph CLI
// toandin[CYR:ny] andwith for [CYR:work]fromy with  onand
//
// USAGE: trinity-kg [command] [args...]
// REPL:  trinity-kg ([CYR:without] argumentin)
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const kg = @import("knowledge_graph.zig");

const KnowledgeGraph = kg.KnowledgeGraph;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:A] 
// ═══════════════════════════════════════════════════════════════════════════════

var graph: KnowledgeGraph = KnowledgeGraph.init();
var name_buffer: [16384]u8 = undefined; //  for and and to
var string_pool: [32768]u8 = undefined; //  for notandI withto
var string_pool_offset: usize = 0;
var current_file: ?[]const u8 = null;

/// and withto in  and inin[CYR:acts] slice
fn internString(s: []const u8) []const u8 {
    if (string_pool_offset + s.len > string_pool.len) {
        return s; //  not, inin andon
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
    _ = args.skip(); // withto andI [CYR:proy]

    // withand with argumenty - in[CYR:yI] to and in[CYR:y]and
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

    // REPL and
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

        // withand to
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
            try stdout.print("\x1b[33m! φ² + 1/φ² = 3\x1b[0m\n", .{});
            break;
        }

        executeCommand(cmd, arg_list[0..arg_count], stdout) catch |err| {
            try stdout.print("\x1b[31mError: {}\x1b[0m\n", .{err});
        };
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:A]
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
        try writer.print("\x1b[32m and.\x1b[0m\n", .{});
    } else {
        try writer.print("\x1b[31mandinwithonI to: {s}\x1b[0m\n", .{cmd});
        try writer.print("inand 'help' for withlaw]intoand.\n", .{});
    }
}

///  add: inand to
fn cmdAdd(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mwithl]inand: add <subject> <predicate> <object>\x1b[0m\n", .{});
        try writer.print("and: add Paris capital_of France\n", .{});
        return;
    }

    // and withtoand thaty and or in [CYR:I]and
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    graph.addTriple(subject, predicate, object);

    try writer.print("\x1b[32m✓ in:\x1b[0m {s} \x1b[33m{s}\x1b[0m {s}\n", .{ subject, predicate, object });
}

///  query: [CYR:pro]with to 
fn cmdQuery(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mwithl]inand: query <subject|?> <predicate> <object|?>\x1b[0m\n", .{});
        try writer.print("and: query Paris capital_of ?\n", .{});
        try writer.print("and: query ? capital_of France\n", .{});
        return;
    }

    // and withtoand for andwithto
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    const is_subject_query = std.mem.eql(u8, subject, "?");
    const is_object_query = std.mem.eql(u8, object, "?");

    if (is_subject_query and is_object_query) {
        try writer.print("\x1b[31m andwithforate] [CYR:l]to subject  object, not .\x1b[0m\n", .{});
        return;
    }

    if (!is_subject_query and !is_object_query) {
        try writer.print("\x1b[31m forate] ? for andwithforgo] element.\x1b[0m\n", .{});
        return;
    }

    try writer.print("\x1b[36m[CYR:pro]with:\x1b[0m {s} {s} {s}\n", .{ subject, predicate, object });

    if (is_object_query) {
        //  object: query(subject, predicate, ?)
        const result = graph.queryObject(subject, predicate);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗  on\x1b[0m\n", .{});
        }
    } else {
        //  subject: query(?, predicate, object)
        const result = graph.querySubject(predicate, object);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗  on\x1b[0m\n", .{});
        }
    }
}

///  save: withand 
fn cmdSave(args: [][]const u8, writer: anytype) !void {
    const path = if (args.len > 0) args[0] else (current_file orelse "graph.trkg");

    try graph.save(path);
    current_file = path;

    try writer.print("\x1b[32m✓  with:\x1b[0m {s}\n", .{path});
}

///  load: and 
fn cmdLoad(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31mwithl]inand: load <path>\x1b[0m\n", .{});
        return;
    }

    const path = args[0];

    graph = try KnowledgeGraph.load(path, &name_buffer);
    current_file = path;

    const s = graph.stats();
    try writer.print("\x1b[32m✓  :\x1b[0m {s}\n", .{path});
    try writer.print("  with: {d}, and: {d}, toin: {d}\n", .{ s.entities, s.relations, s.triples });
}

///  stats: withandwithandto
fn cmdStats(writer: anytype) !void {
    const s = graph.stats();

    try writer.print("\n\x1b[36m╔═══════════════════════════════════════╗\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m       TRINITY KNOWLEDGE GRAPH         \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m╠═══════════════════════════════════════╣\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m  with:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.entities});
    try writer.print("\x1b[36m║\x1b[0m  and:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.relations});
    try writer.print("\x1b[36m║\x1b[0m  toin:     \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.triples});
    try writer.print("\x1b[36m╚═══════════════════════════════════════╝\x1b[0m\n", .{});

    if (current_file) |f| {
        try writer.print("  : {s}\n", .{f});
    }
}

///  list: withandwithto with
fn cmdList(writer: anytype) !void {
    try writer.print("\n\x1b[36mwithand:\x1b[0m\n", .{});
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            try writer.print("  [{d}] {s}\n", .{ e.id, e.name });
        }
    }

    try writer.print("\n\x1b[36mandI:\x1b[0m\n", .{});
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
    try writer.print("inand \x1b[33mhelp\x1b[0m for withlaw]intoand, \x1b[33mexit\x1b[0m for in[CYR:y].\n", .{});
}

fn printHelp(writer: anytype) !void {
    try writer.print("\n\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\x1b[33m[CYR:A]:\x1b[0m\n", .{});
    try writer.print("\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32madd\x1b[0m <subject> <predicate> <object>\n", .{});
    try writer.print("      inand to in \n", .{});
    try writer.print("      and: \x1b[90madd Paris capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mquery\x1b[0m <subject|?> <predicate> <object|?>\n", .{});
    try writer.print("      [CYR:pro]with to  (? = andwithto)\n", .{});
    try writer.print("      and: \x1b[90mquery Paris capital_of ?\x1b[0m\n", .{});
    try writer.print("      and: \x1b[90mquery ? capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32msave\x1b[0m [path]\n", .{});
    try writer.print("      and  in file\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mload\x1b[0m <path>\n", .{});
    try writer.print("      and  and file\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mstats\x1b[0m\n", .{});
    try writer.print("      forate] withandwithandto \n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mlist\x1b[0m\n", .{});
    try writer.print("      forate] inwith withand and fromandI\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mclear\x1b[0m\n", .{});
    try writer.print("      andwithand \n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mexit\x1b[0m\n", .{});
    try writer.print("      [CYR:Vy]and and [CYR:proy]\n", .{});
    try writer.print("\n", .{});
}
