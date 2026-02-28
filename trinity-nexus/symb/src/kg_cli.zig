// Trinity Knowledge Graph CLI
// Интераtoтandinный andнтерфейwith for рабfromы with графом зonнandй
//
// USAGE: trinity-kg [command] [args...]
// REPL:  trinity-kg (без аргументоin)
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const kg = @import("knowledge_graph.zig");

const KnowledgeGraph = kg.KnowledgeGraph;

// ═══════════════════════════════════════════════════════════════════════════════
// ГЛОБАЛЬНОЕ СОСТОЯНИЕ
// ═══════════════════════════════════════════════════════════════════════════════

var graph: KnowledgeGraph = KnowledgeGraph.init();
var name_buffer: [16384]u8 = undefined; // Буфер for andмён прand загрузtoе
var string_pool: [32768]u8 = undefined; // Буфер for храненandя withтроto
var string_pool_offset: usize = 0;
var current_file: ?[]const u8 = null;

/// Копandрует withтроtoу in пул and inозinращает slice
fn internString(s: []const u8) []const u8 {
    if (string_pool_offset + s.len > string_pool.len) {
        return s; // Пул переполнен, inозinращаем орandгandonл
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
    _ = args.skip(); // Пропуwithtoаем andмя программы

    // Еwithлand еwithть аргументы - inыполняем toоманду and inыходandм
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

    // REPL режandм
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

        // Парwithandм toоманду
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
            try stdout.print("\x1b[33mГудбай! φ² + 1/φ² = 3\x1b[0m\n", .{});
            break;
        }

        executeCommand(cmd, arg_list[0..arg_count], stdout) catch |err| {
            try stdout.print("\x1b[31mError: {}\x1b[0m\n", .{err});
        };
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// КОМАНДЫ
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
        try writer.print("\x1b[32mГраф очandщен.\x1b[0m\n", .{});
    } else {
        try writer.print("\x1b[31mНеandзinеwithтonя toоманда: {s}\x1b[0m\n", .{cmd});
        try writer.print("Вinедandте 'help' for withпраintoand.\n", .{});
    }
}

/// Команда add: добаinandть фаtoт
fn cmdAdd(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mИwithпользоinанandе: add <subject> <predicate> <object>\x1b[0m\n", .{});
        try writer.print("Прandмер: add Paris capital_of France\n", .{});
        return;
    }

    // Интернandруем withтроtoand чтобы онand жor in памятand
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    graph.addTriple(subject, predicate, object);

    try writer.print("\x1b[32m✓ Добаinлено:\x1b[0m {s} \x1b[33m{s}\x1b[0m {s}\n", .{ subject, predicate, object });
}

/// Команда query: запроwith to графу
fn cmdQuery(args: [][]const u8, writer: anytype) !void {
    if (args.len < 3) {
        try writer.print("\x1b[31mИwithпользоinанandе: query <subject|?> <predicate> <object|?>\x1b[0m\n", .{});
        try writer.print("Прandмер: query Paris capital_of ?\n", .{});
        try writer.print("Прandмер: query ? capital_of France\n", .{});
        return;
    }

    // Интернandруем withтроtoand for поandwithtoа
    const subject = internString(args[0]);
    const predicate = internString(args[1]);
    const object = internString(args[2]);

    const is_subject_query = std.mem.eql(u8, subject, "?");
    const is_object_query = std.mem.eql(u8, object, "?");

    if (is_subject_query and is_object_query) {
        try writer.print("\x1b[31mМожно andwithtoать тольtoо subject ИЛИ object, не оба.\x1b[0m\n", .{});
        return;
    }

    if (!is_subject_query and !is_object_query) {
        try writer.print("\x1b[31mНужно уtoазать ? for andwithtoомого элемента.\x1b[0m\n", .{});
        return;
    }

    try writer.print("\x1b[36mЗапроwith:\x1b[0m {s} {s} {s}\n", .{ subject, predicate, object });

    if (is_object_query) {
        // Ищем object: query(subject, predicate, ?)
        const result = graph.queryObject(subject, predicate);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗ Не onйдено\x1b[0m\n", .{});
        }
    } else {
        // Ищем subject: query(?, predicate, object)
        const result = graph.querySubject(predicate, object);
        if (result) |entity| {
            try writer.print("\x1b[32m✓ Result:\x1b[0m {s}\n", .{entity.name});
        } else {
            try writer.print("\x1b[33m✗ Не onйдено\x1b[0m\n", .{});
        }
    }
}

/// Команда save: withохранandть граф
fn cmdSave(args: [][]const u8, writer: anytype) !void {
    const path = if (args.len > 0) args[0] else (current_file orelse "graph.trkg");

    try graph.save(path);
    current_file = path;

    try writer.print("\x1b[32m✓ Граф withохранён:\x1b[0m {s}\n", .{path});
}

/// Команда load: загрузandть граф
fn cmdLoad(args: [][]const u8, writer: anytype) !void {
    if (args.len < 1) {
        try writer.print("\x1b[31mИwithпользоinанandе: load <path>\x1b[0m\n", .{});
        return;
    }

    const path = args[0];

    graph = try KnowledgeGraph.load(path, &name_buffer);
    current_file = path;

    const s = graph.stats();
    try writer.print("\x1b[32m✓ Граф загружен:\x1b[0m {s}\n", .{path});
    try writer.print("  Сущноwithтей: {d}, Отношенandй: {d}, Фаtoтоin: {d}\n", .{ s.entities, s.relations, s.triples });
}

/// Команда stats: withтатandwithтandtoа
fn cmdStats(writer: anytype) !void {
    const s = graph.stats();

    try writer.print("\n\x1b[36m╔═══════════════════════════════════════╗\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m       TRINITY KNOWLEDGE GRAPH         \x1b[36m║\x1b[0m\n", .{});
    try writer.print("\x1b[36m╠═══════════════════════════════════════╣\x1b[0m\n", .{});
    try writer.print("\x1b[36m║\x1b[0m  Сущноwithтей:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.entities});
    try writer.print("\x1b[36m║\x1b[0m  Отношенandй:  \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.relations});
    try writer.print("\x1b[36m║\x1b[0m  Фаtoтоin:     \x1b[33m{d:5}\x1b[0m                    \x1b[36m║\x1b[0m\n", .{s.triples});
    try writer.print("\x1b[36m╚═══════════════════════════════════════╝\x1b[0m\n", .{});

    if (current_file) |f| {
        try writer.print("  Файл: {s}\n", .{f});
    }
}

/// Команда list: withпandwithоto withущноwithтей
fn cmdList(writer: anytype) !void {
    try writer.print("\n\x1b[36mСущноwithтand:\x1b[0m\n", .{});
    for (0..graph.entity_count) |i| {
        if (graph.entities[i]) |e| {
            try writer.print("  [{d}] {s}\n", .{ e.id, e.name });
        }
    }

    try writer.print("\n\x1b[36mОтношенandя:\x1b[0m\n", .{});
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
    try writer.print("Вinедandте \x1b[33mhelp\x1b[0m for withпраintoand, \x1b[33mexit\x1b[0m for inыхода.\n", .{});
}

fn printHelp(writer: anytype) !void {
    try writer.print("\n\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\x1b[33mКОМАНДЫ:\x1b[0m\n", .{});
    try writer.print("\x1b[36m═══════════════════════════════════════════════════════════════\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32madd\x1b[0m <subject> <predicate> <object>\n", .{});
    try writer.print("      Добаinandть фаtoт in граф\n", .{});
    try writer.print("      Прandмер: \x1b[90madd Paris capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mquery\x1b[0m <subject|?> <predicate> <object|?>\n", .{});
    try writer.print("      Запроwith to графу (? = andwithtoомое)\n", .{});
    try writer.print("      Прandмер: \x1b[90mquery Paris capital_of ?\x1b[0m\n", .{});
    try writer.print("      Прandмер: \x1b[90mquery ? capital_of France\x1b[0m\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32msave\x1b[0m [path]\n", .{});
    try writer.print("      Сохранandть граф in файл\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mload\x1b[0m <path>\n", .{});
    try writer.print("      Загрузandть граф andз файла\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mstats\x1b[0m\n", .{});
    try writer.print("      Поtoазать withтатandwithтandtoу графа\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mlist\x1b[0m\n", .{});
    try writer.print("      Поtoазать inwithе withущноwithтand and fromношенandя\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mclear\x1b[0m\n", .{});
    try writer.print("      Очandwithтandть граф\n", .{});
    try writer.print("\n", .{});
    try writer.print("  \x1b[32mexit\x1b[0m\n", .{});
    try writer.print("      Выйтand andз программы\n", .{});
    try writer.print("\n", .{});
}
