// @origin manual

// ═══════════════════════════════════════════════════════════════════════════════
// CSV PARSER — Read and write cognitive benchmark CSV files
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CsvRow = struct {
    id: []const u8,
    task: []const u8,
    question: []const u8,
    answer: []const u8,
    difficulty: f64 = 5.0,
    brain_zone: []const u8 = "",
    neural_analog: []const u8 = "",
};

pub const CsvStats = struct {
    total_rows: usize = 0,
    open_ended: usize = 0,
    factual: usize = 0,
    avg_difficulty: f64 = 0.0,
    tasks: std.StringHashMap(usize),
    brain_zones: std.StringHashMap(usize),

    pub fn init(allocator: Allocator) CsvStats {
        return .{
            .tasks = std.StringHashMap(usize).init(allocator),
            .brain_zones = std.StringHashMap(usize).init(allocator),
        };
    }

    pub fn deinit(self: *CsvStats) void {
        self.tasks.deinit();
        self.brain_zones.deinit();
    }
};

pub const CsvParser = struct {
    allocator: Allocator,
    path: []const u8,

    pub fn init(allocator: Allocator, path: []const u8) CsvParser {
        return .{
            .allocator = allocator,
            .path = path,
        };
    }

    pub fn parse(self: *const CsvParser) !struct { rows: []CsvRow, stats: CsvStats } {
        const file = try std.fs.cwd().openFile(self.path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024);
        defer self.allocator.free(data);

        var rows = try std.ArrayList(CsvRow).initCapacity(self.allocator, 0);
        var stats = CsvStats.init(self.allocator);

        // Parse CSV line by line
        var line_iter = std.mem.splitScalar(u8, data, '\n');
        var line_num: usize = 0;

        while (line_iter.next()) |line| {
            line_num += 1;
            if (line.len == 0) continue;

            // Skip header
            if (line_num == 1 and std.mem.indexOf(u8, line, "id") != null) {
                continue;
            }

            // Parse CSV fields (handle quoted fields)
            var fields = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
            defer {
                for (fields.items) |f| self.allocator.free(f);
                fields.deinit(self.allocator);
            }

            var field_start: usize = 0;
            var in_quotes = false;
            var i: usize = 0;

            while (i < line.len) : (i += 1) {
                const c = line[i];

                if (c == '"') {
                    in_quotes = !in_quotes;
                } else if (c == ',' and !in_quotes) {
                    const field = line[field_start..i];
                    const trimmed = try trimField(self.allocator, field);
                    try fields.append(self.allocator, trimmed);
                    field_start = i + 1;
                }
            }

            // Last field
            const field = line[field_start..];
            const trimmed = try trimField(self.allocator, field);
            try fields.append(self.allocator, trimmed);

            // Need at least id, task, question, answer
            if (fields.items.len < 4) continue;

            const row = CsvRow{
                .id = try self.allocator.dupe(u8, fields.items[0]),
                .task = try self.allocator.dupe(u8, fields.items[1]),
                .question = try self.allocator.dupe(u8, fields.items[2]),
                .answer = try self.allocator.dupe(u8, fields.items[3]),
                .difficulty = if (fields.items.len > 4)
                    try std.fmt.parseFloat(f64, fields.items[4])
                else
                    5.0,
                .brain_zone = if (fields.items.len > 5)
                    try self.allocator.dupe(u8, fields.items[5])
                else
                    "",
                .neural_analog = if (fields.items.len > 6)
                    try self.allocator.dupe(u8, fields.items[6])
                else
                    "",
            };

            try rows.append(self.allocator, row);
            stats.total_rows += 1;

            // Track task types
            const task_count = try stats.tasks.getOrPut(row.task);
            task_count.value_ptr.* += 1;

            // Track brain zones
            if (row.brain_zone.len > 0) {
                const zone_count = try stats.brain_zones.getOrPut(row.brain_zone);
                zone_count.value_ptr.* += 1;
            }

            // Detect question type
            const answer_words = std.mem.count(u8, row.answer, " ") + 1;
            const has_brackets = std.mem.indexOf(u8, row.answer, "(") != null or
                                 std.mem.indexOf(u8, row.answer, "[") != null;

            if (answer_words > 4 or has_brackets) {
                stats.open_ended += 1;
            } else {
                stats.factual += 1;
            }
        }

        // Calculate average difficulty
        if (rows.items.len > 0) {
            var total_diff: f64 = 0;
            for (rows.items) |r| {
                total_diff += r.difficulty;
            }
            stats.avg_difficulty = total_diff / @as(f64, @floatFromInt(rows.items.len));
        }

        return .{
            .rows = try rows.toOwnedSlice(self.allocator),
            .stats = stats,
        };
    }

    fn trimField(allocator: Allocator, field: []const u8) ![]const u8 {
        var trimmed = std.mem.trim(u8, field, " \t\r\n");
        // Remove quotes if present
        if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len-1] == '"') {
            trimmed = trimmed[1 .. trimmed.len-1];
        }
        return allocator.dupe(u8, trimmed);
    }
};

pub const CsvWriter = struct {
    allocator: Allocator,
    file: std.fs.File,

    pub fn init(allocator: Allocator, path: []const u8) !CsvWriter {
        const file = try std.fs.cwd().createFile(path, .{});
        return .{
            .allocator = allocator,
            .file = file,
        };
    }

    pub fn deinit(self: *CsvWriter) void {
        self.file.close();
    }

    pub fn writeHeader(self: *CsvWriter) !void {
        try self.file.writeAll("id,task,question,answer,difficulty,brain_zone,neural_analog\n");
    }

    pub fn writeRow(self: *CsvWriter, row: CsvRow) !void {
        // Escape fields with commas or quotes
        const writer = self.file.writer();

        try writeField(writer, row.id);
        try writer.writeAll(",");

        try writeField(writer, row.task);
        try writer.writeAll(",");

        try writeField(writer, row.question);
        try writer.writeAll(",");

        try writeField(writer, row.answer);
        try writer.writeAll(",");

        try writer.print("{d}", .{row.difficulty});
        try writer.writeAll(",");

        try writeField(writer, row.brain_zone);
        try writer.writeAll(",");

        try writeField(writer, row.neural_analog);
        try writer.writeAll("\n");
    }

    fn writeField(writer: anytype, field: []const u8) !void {
        const needs_quotes = std.mem.indexOf(u8, field, ",") != null or
                            std.mem.indexOf(u8, field, "\"") != null or
                            std.mem.indexOf(u8, field, "\n") != null;

        if (needs_quotes) {
            try writer.writeAll("\"");
            for (field) |c| {
                if (c == '"') {
                    try writer.writeAll("\"\"");
                } else {
                    try writer.writeByte(c);
                }
            }
            try writer.writeAll("\"");
        } else {
            try writer.writeAll(field);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parse CSV row" {
    const allocator = std.testing.allocator;

    const csv_data =
        \\id,task,question,answer,difficulty,brain_zone,neural_analog
        \\test_001,Confidence Calibration,What is 2+2?,4,3.0,ofc,OFC value judgment
    ;

    // Write temp file
    const tmp_path = "test_csv_parser_temp.csv";
    {
        const file = try std.fs.cwd().createFile(tmp_path, .{});
        defer file.close();
        try file.writeAll(csv_data);
    }
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    const parser = CsvParser.init(allocator, tmp_path);
    var result = try parser.parse();
    defer {
        allocator.free(result.rows);
        for (result.rows) |r| {
            allocator.free(r.id);
            allocator.free(r.task);
            allocator.free(r.question);
            allocator.free(r.answer);
            if (r.brain_zone.len > 0) allocator.free(r.brain_zone);
            if (r.neural_analog.len > 0) allocator.free(r.neural_analog);
        }
        result.stats.deinit();
    }

    try std.testing.expectEqual(@as(usize, 1), result.stats.total_rows);
    try std.testing.expectEqual(@as(usize, 1), result.stats.factual);
    try std.testing.expectEqual(@as(usize, 0), result.stats.open_ended);
}

test "detect open-ended vs factual" {
    try std.testing.expectEqual(@as(usize, 1), countWords("Tashkent"));
    try std.testing.expectEqual(@as(usize, 5), countWords("A quantum system exists in multiple states"));
}

fn countWords(s: []const u8) usize {
    var count: usize = 0;
    var in_word = false;
    for (s) |c| {
        if (c == ' ' or c == '\t' or c == '\n') {
            in_word = false;
        } else if (!in_word) {
            count += 1;
            in_word = true;
        }
    }
    return count;
}
