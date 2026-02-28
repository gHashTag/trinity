// Trinity Knowledge Graph CLI
// [CYR:Интера]toтandin[CYR:ный] and[CYR:нтерфей]with for [CYR:раб]fromы with [CYR:графом] зonнandй
//
// USAGE: trinity-kg [command] [args...]
// REPL:  trinity-kg ([CYR:без] argumentоin)
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const kg = @import("knowledge_graph.zig");

const KnowledgeGraph = kg.KnowledgeGraph;

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:ГЛОБАЛЬНОЕ] [CYR:СОСТОЯНИЕ]
// ═══════════════════════════════════════════════════════════════════════════════

var graph: KnowledgeGraph = KnowledgeGraph.init();
var name_buffer: [16384]u8 = undefined; // [CYR:Буфер] for and[CYR:мён] прand [CYR:загруз]toе
var string_pool: [32768]u8 = undefined; // [CYR:Буфер] for [CYR:хра]notнandя with[CYR:тро]to
var string_pool_offset: usize = 0;
var current_file: ?[]const u8 = null;

/// [CYR:Коп]and[CYR:рует] with[CYR:тро]toу in [CYR:пул] and inозin[CYR:ращает] slice
fn internString(s: []const u8) []const u8 {
    if (string_pool_offset + s.len > string_pool.len) {
        return s; // [CYR:Пул] [CYR:перепол]notн, inозin[CYR:ращаем] орandгandonл
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
    _ = args.skip(); // [CYR:Пропу]withto[CYR:аем] andмя [CYR:программы]

    // Еwithлand еwithть argumentы - in[CYR:ыполняем] to[CYR:оманду] and in[CYR:ыход]andм
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

    // REPL [CYR:реж]andм
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

        // [CYR:Пар]withandм to[CYR:оманду]
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
            try stdout.print("\x1b[33m[CYR:Гудбай]! φ² + 1/φ² = 3\x1b[0m\n", .{});
            break;
        }

        executeCommand(cmd, arg_list[0..arg_count], stdout) catch |err| {
            try stdout.print("\x1b[31mError: {}\x1b[0m\n", .{err});
        };
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// [CYR:КОМАНДЫ]
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
        try writer.print("\x1b[32m[CYR:Граф] очand[CYR:щен].\x1b[0m\n", .{});
    } else {
        try writer.print("\x1b[31mНеandзinеwithтonя to[CYR:оманда]: {s}\x1b[0m\n", .{cmd});
        try writer.print("Вinедandте 'help' for with[CYR:пра]intoand.\n", .{});
    }
}

/// [CYR:Команда] add: [CYR:доба]inandть фаtoт
fn cmdAdd(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mИwith[CYR:пользо]inанandе: add <subject> <predicate> <object>\x1b[0m\n", .{});
        try writer.print("Прand[CYR:мер]: add Paris capital_of France\n", .{});
        return;
    }

    // [CYR:Интерн]and[CYR:руем] with[CYR:тро]toand thatбы онand жor in [CYR:памят]and
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    graph.addTriple(subject, predicate, object);

    try writer.print("\x1b[32m✓ [CYR:Доба]in[CYR:лено]:\x1b[0m {s} \x1b[33m{s}\x1b[0m {s}\n", .{ subject, predicate, object });
}

/// [CYR:Команда] query: [CYR:запро]with to [CYR:графу]
fn cmdQuery(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mИwith[CYR:пользо]inанandе: query <subject|?> <predicate> <object|?>\x1b[0m\n", .{});
        try writer.print("Прand[CYR:мер]: query Paris capital_of ?\n", .{});
        try writer.print("Прand[CYR:мер]: query ? capital_of France\n", .{});
        return;
    }

    // [CYR:Интерн]and[CYR:руем] with[CYR:тро]toand for поandwithtoа
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    const is_subject_query = std.mem.eql(u8, subject, "?");
    const is_object_query = std.mem.eql(u8, object, "?");

    if (is_subject_query and is_object_query) {
        try writer.print("\x1b[31m[CYR:Можно] andwithto[CYR:ать] [CYR:толь]toо subject [CYR:ИЛИ] object, not [CYR:оба].\x1b[0m\n", .{});
        return;
    }

    if (!is_subject_query and !is_object_query) {
        try writer.print("\x1b[31m[CYR:Нужно] уto[CYR:азать] ? for andwithto[CYR:омого] elementа.\x1b[0m\n", .{});
        return;
    }

    try writer.print("\x1b[36m[CYR:Запро]with:\x1b[0m {s} {s} {s}\n", .{ subject, predicate, object });

    if (is_object_query) {
        // [CYR:Ищем] object: query(subject, predicate, ?)
        const result = graph.queryObject(subject, predicate);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗ Не on[CYR:йдено]\x1b[0m\n", .{});
        }
    } else {
        // [CYR:Ищем] subject: query(?, predicate, object)
        const result = graph.querySubject(predicate, object);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗ Не on[CYR:йдено]\x1b[0m\n", .{});
        }
    }
}

/// [CYR:Команда] save: with[CYR:охран]andть [CYR:граф]
fn cmdSave(args: [][]const u8, writer: anytype) !void {
    const path = if (args.len > 0) args[0] else (current_file orelse "graph.trkg");

    try graph.save(path);
    current_file = path;

    try writer.print("\x1b[32m✓ [CYR:Граф] with[CYR:охранён]:\x1b[0m {s}\n", .{path});
}

/// [CYR:Команда] load: [CYR:загруз]andть [CYR:граф]
fn cmdLoad(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31mИwith[CYR:пользо]inанandе: load <path>\x1b[0m\n", .{});
        return;
    }

    const path = args[0];

    graph = try KnowledgeGraph.load(path, &name_buffer);
    current_file = path;

    const s = graph.stats();
    try writer.print("\x1b[32m✓ [CYR:Граф] [CYR:загружен]:\x1b[0m {s}\n", .{path});
    try writer.print("  [CYR:Сущно]with[CYR:тей]: {d}, [CYR:Отношен]andй: {d}, Фаtoтоin: {d}\n", .{ s.entities, s.relations, s.triples });
}

/// [CYR:Команда] stats: with[CYR:тат]andwithтandtoа
fn cmdStats(writer: anytype) !void {
    const s = graph.stats();

    try writer.print("\n\x1b[36m╔═══════════════════════════════════════╗\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m       TRINITY KNOWLEDGE GRAPH         \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m╠═══════════════════════════════════════╣\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m  [CYR:Сущно]with[CYR:тей]:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.entities});
    try writer.print("\x1b[36m║\x1b[0m  [CYR:Отношен]andй:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.relations});
    try writer.print("\x1b[36m║\x1b[0m  Фаtoтоin:     \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.triples});
    try writer.print("\x1b[36m╚═══════════════════════════════════════╝\x1b[0m\n", .{});

    if (current_file) |f| {
        try writer.print("  [CYR:Файл]: {s}\n", .{f});
    }
}

/// [CYR:Команда] list: withпandwithоto with[CYR:ущно]with[CYR:тей]
fn cmdList(writer: anytype) !void {
    try writer.print("\n\x1b[36m[CYR:Сущно]withтand:\x1b[0m\n", .{});
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            try writer.print("  [{d}] {s}\n", .{ e.id, e.name });
        }
    }

    try writer.print("\n\x1b[36m[CYR:Отношен]andя:\x1b[0m\n", .{});
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
    try writer.print("Вinедandте \x1b[33mhelp\x1b[0m for with[CYR:пра]intoand, \x1b[33mexit\x1b[0m for in[CYR:ыхода].\n", .{});
}

fn printHelp(writer: anytype) !void {
    try writer.print("\n\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\x1b[33m[CYR:КОМАНДЫ]:\x1b[0m\n", .{});
    try writer.print("\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32madd\x1b[0m <subject> <predicate> <object>\n", .{});
    try writer.print("      [CYR:Доба]inandть фаtoт in [CYR:граф]\n", .{});
    try writer.print("      Прand[CYR:мер]: \x1b[90madd Paris capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mquery\x1b[0m <subject|?> <predicate> <object|?>\n", .{});
    try writer.print("      [CYR:Запро]with to [CYR:графу] (? = andwithto[CYR:омое])\n", .{});
    try writer.print("      Прand[CYR:мер]: \x1b[90mquery Paris capital_of ?\x1b[0m\n", .{});
    try writer.print("      Прand[CYR:мер]: \x1b[90mquery ? capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32msave\x1b[0m [path]\n", .{});
    try writer.print("      [CYR:Сохран]andть [CYR:граф] in file\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mload\x1b[0m <path>\n", .{});
    try writer.print("      [CYR:Загруз]andть [CYR:граф] andз fileа\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mstats\x1b[0m\n", .{});
    try writer.print("      Поto[CYR:азать] with[CYR:тат]andwithтandtoу [CYR:графа]\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mlist\x1b[0m\n", .{});
    try writer.print("      Поto[CYR:азать] inwithе with[CYR:ущно]withтand and from[CYR:ношен]andя\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mclear\x1b[0m\n", .{});
    try writer.print("      Очandwithтandть [CYR:граф]\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mexit\x1b[0m\n", .{});
    try writer.print("      [CYR:Выйт]and andз [CYR:программы]\n", .{});
    try writer.print("\n", .{});
}
