// @origin(spec:kg_cli.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// Trinity Knowledge Graph CLI
// Interactive Knowledge Graph interface with KG-INSIGHT inspector (DEV-002)
//
// USAGE: trinity-kg [command] [args...]
// REPL:  trinity-kg (no arguments)
//
// KG-INSIGHT commands: triples, inspect, export, find
// Ά² + 1/Ά² = 3

const std = @import("std");
const kg = @import("knowledge_graph.zig");

const KnowledgeGraph = kg.KnowledgeGraph;

// =============================================================================
// GLOBAL STATE
// =============================================================================

var graph: KnowledgeGraph = KnowledgeGraph.init();
var name_buffer: [16384]u8 = undefined;
var string_pool: [32768]u8 = undefined;
var string_pool_offset: usize = 0;
var current_file: ?[]const u8 = null;

/// Copy string into pool and return slice
fn internString(s: []const u8) []const u8 {
    if (string_pool_offset + s.len > string_pool.len) {
        return s;
    }
    const start = string_pool_offset;
    @memcpy(string_pool[start .. start + s.len], s);
    string_pool_offset += s.len;
    return string_pool[start .. start + s.len];
}

// =============================================================================
// MAIN
// =============================================================================

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var args = std.process.args();
    _ = args.skip();

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

    // REPL mode
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
            try stdout.print("\x1b[33mGoodbye! \xCF\x86\xC2\xB2 + 1/\xCF\x86\xC2\xB2 = 3\x1b[0m\n", .{});
            break;
        }

        executeCommand(cmd, arg_list[0..arg_count], stdout) catch |err| {
            try stdout.print("\x1b[31mError: {}\x1b[0m\n", .{err});
        };
    }
}

// =============================================================================
// COMMAND DISPATCH
// =============================================================================

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
    } else if (std.mem.eql(u8, cmd, "triples") or std.mem.eql(u8, cmd, "t")) {
        try cmdTriples(writer);
    } else if (std.mem.eql(u8, cmd, "inspect") or std.mem.eql(u8, cmd, "i")) {
        try cmdInspect(args, writer);
    } else if (std.mem.eql(u8, cmd, "export")) {
        try cmdExport(args, writer);
    } else if (std.mem.eql(u8, cmd, "find") or std.mem.eql(u8, cmd, "f")) {
        try cmdFind(args, writer);
    } else if (std.mem.eql(u8, cmd, "clear")) {
        graph = KnowledgeGraph.init();
        try writer.print("\x1b[32mGraph cleared.\x1b[0m\n", .{});
    } else {
        try writer.print("\x1b[31mUnknown command: {s}\x1b[0m\n", .{cmd});
        try writer.print("Type 'help' for available commands.\n", .{});
    }
}

// =============================================================================
// ORIGINAL COMMANDS
// =============================================================================

/// Command add: add a fact
fn cmdAdd(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mUsage: add <subject> <predicate> <object>\x1b[0m\n", .{});
        try writer.print("Example: add Paris capital_of France\n", .{});
        return;
    }

    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    graph.addTriple(subject, predicate, object);

    try writer.print("\x1b[32m+ Added:\x1b[0m {s} \x1b[33m{s}\x1b[0m {s}\n", .{ subject, predicate, object });
}

/// Command query: query the graph
fn cmdQuery(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mUsage: query <subject|?> <predicate> <object|?>\x1b[0m\n", .{});
        try writer.print("Example: query Paris capital_of ?\n", .{});
        try writer.print("Example: query ? capital_of France\n", .{});
        return;
    }

    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    const is_subject_query = std.mem.eql(u8, subject, "?");
    const is_object_query = std.mem.eql(u8, object, "?");

    if (is_subject_query and is_object_query) {
        try writer.print("\x1b[31mCan only query subject OR object, not both.\x1b[0m\n", .{});
        return;
    }

    if (!is_subject_query and !is_object_query) {
        try writer.print("\x1b[31mUse ? for the element to search.\x1b[0m\n", .{});
        return;
    }

    try writer.print("\x1b[36mQuery:\x1b[0m {s} {s} {s}\n", .{ subject, predicate, object });

    if (is_object_query) {
        const result = graph.queryObject(subject, predicate);
        if (result) |entity| {
            try writer.print("\x1b[32m+ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33mx Not found\x1b[0m\n", .{});
        }
    } else {
        const result = graph.querySubject(predicate, object);
        if (result) |entity| {
            try writer.print("\x1b[32m+ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33mx Not found\x1b[0m\n", .{});
        }
    }
}

/// Command save: save the graph
fn cmdSave(args: [][]const u8, writer: anytype) !void {
    const path = if (args.len > 0) args[0] else (current_file orelse "graph.trkg");

    try graph.save(path);
    current_file = path;

    try writer.print("\x1b[32m+ Graph saved:\x1b[0m {s}\n", .{path});
}

/// Command load: load the graph
fn cmdLoad(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31mUsage: load <path>\x1b[0m\n", .{});
        return;
    }

    const path = args[0];

    graph = try KnowledgeGraph.load(path, &name_buffer);
    current_file = path;

    const s = graph.stats();
    try writer.print("\x1b[32m+ Graph loaded:\x1b[0m {s}\n", .{path});
    try writer.print("  Entities: {d}, Relations: {d}, Triples: {d}\n", .{ s.entities, s.relations, s.triples });
}

/// Command stats: show statistics
fn cmdStats(writer: anytype) !void {
    const s = graph.stats();

    try writer.print("\n\x1b[36m+---------------------------------------+\x1b[0m\n", .{});
    try writer.print("\x1b[36m|\x1b[0m       TRINITY KNOWLEDGE GRAPH         \x1b[36m|\x1b[0m\n", .{});
    try writer.print("\x1b[36m+---------------------------------------+\x1b[0m\n", .{});
    try writer.print("\x1b[36m|\x1b[0m  Entities:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m|\x1b[0m\n", .{s.entities});
    try writer.print("\x1b[36m|\x1b[0m  Relations: \x1b[33m{d:5}\x1b[0m                    \x1b[36m|\x1b[0m\n", .{s.relations});
    try writer.print("\x1b[36m|\x1b[0m  Triples:   \x1b[33m{d:5}\x1b[0m                    \x1b[36m|\x1b[0m\n", .{s.triples});
    try writer.print("\x1b[36m+---------------------------------------+\x1b[0m\n", .{});

    if (current_file) |f| {
        try writer.print("  File: {s}\n", .{f});
    }
}

/// Command list: list entities and relations
fn cmdList(writer: anytype) !void {
    try writer.print("\n\x1b[36mEntities:\x1b[0m\n", .{});
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            try writer.print("  [{d}] {s}\n", .{ e.id, e.name });
        }
    }

    try writer.print("\n\x1b[36mRelations:\x1b[0m\n", .{});
    for (0..graph.relation_count) |i| {
        if (graph.relations[i]) |r| {
            try writer.print("  [{d}] {s}\n", .{ r.id, r.name });
        }
    }
}

// =============================================================================
// KG-INSIGHT COMMANDS (DEV-002)
// =============================================================================

/// Command triples: enumerate all stored triples as (S, P, O) table
fn cmdTriples(writer: anytype) !void {
    if (graph.triple_count == 0) {
        try writer.print("\x1b[33mGraph is empty. Use 'add' to create triples.\x1b[0m\n", .{});
        return;
    }

    try writer.print("\n\x1b[36mTriples ({d}):\x1b[0m\n", .{graph.triple_count});
    try writer.print("  \x1b[90m{s: >4}  {s: <20} {s: <16} {s: <20}\x1b[0m\n", .{ "ID", "Subject", "Predicate", "Object" });
    try writer.print("  \x1b[90m{s:->4}  {s:-<20} {s:-<16} {s:-<20}\x1b[0m\n", .{ "", "", "", "" });

    for (0..graph.triple_count) |i| {
        if (graph.triples[i]) |t| {
            const subj = if (graph.entities[t.subject_id]) |e| e.name else "?";
            const pred = if (graph.relations[t.predicate_id]) |r| r.name else "?";
            const obj = if (graph.entities[t.object_id]) |e| e.name else "?";
            try writer.print("  {d:4}  \x1b[32m{s: <20}\x1b[0m \x1b[33m{s: <16}\x1b[0m \x1b[32m{s: <20}\x1b[0m\n", .{ i, subj, pred, obj });
        }
    }
}

/// Command inspect: show all triples involving an entity
fn cmdInspect(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31mUsage: inspect <entity_name>\x1b[0m\n", .{});
        return;
    }

    const name = args[0];
    var entity_id: ?u32 = null;

    // Find entity by exact name (case insensitive)
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            if (asciiEqlIgnoreCase(e.name, name)) {
                entity_id = e.id;
                break;
            }
        }
    }

    // Fallback: prefix match
    if (entity_id == null) {
        for (0..graph.entity_count) |i| {
            if (graph.entities[i]) |e| {
                if (asciiStartsWithIgnoreCase(e.name, name)) {
                    entity_id = e.id;
                    break;
                }
            }
        }
    }

    if (entity_id == null) {
        try writer.print("\x1b[31mEntity not found: {s}\x1b[0m\n", .{name});
        return;
    }

    const eid = entity_id.?;
    const ename = if (graph.entities[eid]) |e| e.name else name;
    try writer.print("\n\x1b[36mInspecting entity: \x1b[32m{s}\x1b[36m (id={d})\x1b[0m\n", .{ ename, eid });

    var as_subject: u32 = 0;
    var as_object: u32 = 0;

    // Triples where entity is subject
    try writer.print("\n  \x1b[33mAs subject:\x1b[0m\n", .{});
    for (0..graph.triple_count) |i| {
        if (graph.triples[i]) |t| {
            if (t.subject_id == eid) {
                const pred = if (graph.relations[t.predicate_id]) |r| r.name else "?";
                const obj = if (graph.entities[t.object_id]) |e| e.name else "?";
                try writer.print("    {s} \x1b[33m{s}\x1b[0m {s}\n", .{ ename, pred, obj });
                as_subject += 1;
            }
        }
    }
    if (as_subject == 0) try writer.print("    (none)\n", .{});

    // Triples where entity is object
    try writer.print("\n  \x1b[33mAs object:\x1b[0m\n", .{});
    for (0..graph.triple_count) |i| {
        if (graph.triples[i]) |t| {
            if (t.object_id == eid) {
                const subj = if (graph.entities[t.subject_id]) |e| e.name else "?";
                const pred = if (graph.relations[t.predicate_id]) |r| r.name else "?";
                try writer.print("    {s} \x1b[33m{s}\x1b[0m {s}\n", .{ subj, pred, ename });
                as_object += 1;
            }
        }
    }
    if (as_object == 0) try writer.print("    (none)\n", .{});

    try writer.print("\n  \x1b[90mTotal: {d} as subject, {d} as object\x1b[0m\n", .{ as_subject, as_object });
}

/// Command export: write all triples to JSON file
fn cmdExport(args: [][]const u8, writer: anytype) !void {
    const path = if (args.len > 0) args[0] else "triples.json";

    if (graph.triple_count == 0) {
        try writer.print("\x1b[33mNo triples to export.\x1b[0m\n", .{});
        return;
    }

    var file = std.fs.cwd().createFile(path, .{}) catch |err| {
        try writer.print("\x1b[31mCannot create file: {s} ({})\x1b[0m\n", .{ path, err });
        return;
    };
    defer file.close();
    var fw = file.writer();

    try fw.print("[\n", .{});
    var written: u32 = 0;
    for (0..graph.triple_count) |i| {
        if (graph.triples[i]) |t| {
            const subj = if (graph.entities[t.subject_id]) |e| e.name else "?";
            const pred = if (graph.relations[t.predicate_id]) |r| r.name else "?";
            const obj = if (graph.entities[t.object_id]) |e| e.name else "?";
            if (written > 0) try fw.print(",\n", .{});
            try fw.print("  {{\"subject\": \"{s}\", \"predicate\": \"{s}\", \"object\": \"{s}\"}}", .{ subj, pred, obj });
            written += 1;
        }
    }
    try fw.print("\n]\n", .{});

    try writer.print("\x1b[32mExported {d} triples to {s}\x1b[0m\n", .{ written, path });
}

/// Command find: search entities by name
fn cmdFind(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31mUsage: find <pattern>\x1b[0m\n", .{});
        return;
    }

    const pattern = args[0];
    var found: u32 = 0;

    try writer.print("\n\x1b[36mEntities matching \"{s}\":\x1b[0m\n", .{pattern});
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            if (asciiStartsWithIgnoreCase(e.name, pattern) or asciiContainsIgnoreCase(e.name, pattern)) {
                try writer.print("  [{d}] {s}\n", .{ e.id, e.name });
                found += 1;
            }
        }
    }

    if (found == 0) {
        try writer.print("  \x1b[33mNo matches found.\x1b[0m\n", .{});
    } else {
        try writer.print("  \x1b[90m({d} matches)\x1b[0m\n", .{found});
    }
}

// =============================================================================
// STRING UTILITIES (case-insensitive matching)
// =============================================================================

fn asciiToLower(ch: u8) u8 {
    return if (ch >= 'A' and ch <= 'Z') ch + 32 else ch;
}

fn asciiEqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (asciiToLower(ca) != asciiToLower(cb)) return false;
    }
    return true;
}

fn asciiStartsWithIgnoreCase(haystack: []const u8, prefix: []const u8) bool {
    if (prefix.len > haystack.len) return false;
    for (0..prefix.len) |i| {
        if (asciiToLower(haystack[i]) != asciiToLower(prefix[i])) return false;
    }
    return true;
}

fn asciiContainsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (asciiStartsWithIgnoreCase(haystack[i..], needle)) return true;
    }
    return false;
}

// =============================================================================
// UI
// =============================================================================

fn printBanner(writer: anytype) !void {
    try writer.print("\n", .{});
    try writer.print("\x1b[36m+===============================================================+\x1b[0m\n", .{});
    try writer.print("\x1b[36m|\x1b[0m     \x1b[33mTRINITY KNOWLEDGE GRAPH\x1b[0m                            \x1b[36m|\x1b[0m\n", .{});
    try writer.print("\x1b[36m|\x1b[0m     \x1b[35mKG-INSIGHT Inspector v2.0\x1b[0m                          \x1b[36m|\x1b[0m\n", .{});
    try writer.print("\x1b[36m+==============================================================+\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("Type \x1b[33mhelp\x1b[0m for commands, \x1b[33mexit\x1b[0m to quit.\n", .{});
}

fn printHelp(writer: anytype) !void {
    try writer.print("\n\x1b[36m===============================================================\x1b[0m\n", .{});
    try writer.print("\x1b[33mCOMMANDS:\x1b[0m\n", .{});
    try writer.print("\x1b[36m===============================================================\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32madd\x1b[0m <subject> <predicate> <object>\n", .{});
    try writer.print("      Add a fact to the graph\n", .{});
    try writer.print("      Example: \x1b[90madd Paris capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mquery\x1b[0m (q) <subject|?> <predicate> <object|?>\n", .{});
    try writer.print("      Query the graph (? = unknown)\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32msave\x1b[0m [path]\n", .{});
    try writer.print("      Save graph to .trkg file\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mload\x1b[0m <path>\n", .{});
    try writer.print("      Load graph from .trkg file\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mstats\x1b[0m\n", .{});
    try writer.print("      Show graph statistics\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mlist\x1b[0m\n", .{});
    try writer.print("      List all entities and relations\n", .{});
    try writer.print("\n", .{});
    try writer.print("\x1b[36m--- KG-INSIGHT (DEV-002) ---\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mtriples\x1b[0m (t)\n", .{});
    try writer.print("      Show all triples as (S, P, O) table\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32minspect\x1b[0m (i) <entity_name>\n", .{});
    try writer.print("      Show all triples involving an entity\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mexport\x1b[0m [path]\n", .{});
    try writer.print("      Export all triples to JSON (default: triples.json)\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mfind\x1b[0m (f) <pattern>\n", .{});
    try writer.print("      Search entities by name (case insensitive)\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mclear\x1b[0m\n", .{});
    try writer.print("      Clear the graph\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mexit\x1b[0m\n", .{});
    try writer.print("      Exit the program\n", .{});
    try writer.print("\n", .{});
}
