// Maxwell Daemon - Code Analyzer
// Анализ кодовой базы для понимания структуры и паттернов
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const codebase = @import("codebase.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Информация о функции
pub const FunctionInfo = struct {
    name: []const u8,
    file_path: []const u8,
    line_start: u32,
    line_end: u32,
    params: std.ArrayList([]const u8),
    return_type: ?[]const u8,
    is_public: bool,
    is_test: bool,
    complexity: u32, // Cyclomatic complexity estimate
    calls: std.ArrayList([]const u8), // Functions this calls

    pub fn init(allocator: std.mem.Allocator) FunctionInfo {
        return FunctionInfo{
            .name = "",
            .file_path = "",
            .line_start = 0,
            .line_end = 0,
            .params = std.ArrayList([]const u8).init(allocator),
            .return_type = null,
            .is_public = false,
            .is_test = false,
            .complexity = 1,
            .calls = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *FunctionInfo) void {
        self.params.deinit();
        self.calls.deinit();
    }
};

/// Информация о структуре/типе
pub const TypeInfo = struct {
    name: []const u8,
    file_path: []const u8,
    line_start: u32,
    kind: TypeKind,
    fields: std.ArrayList(FieldInfo),
    methods: std.ArrayList([]const u8),
    is_public: bool,

    pub const TypeKind = enum {
        Struct,
        Enum,
        Union,
        ErrorSet,
    };

    pub const FieldInfo = struct {
        name: []const u8,
        field_type: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) TypeInfo {
        return TypeInfo{
            .name = "",
            .file_path = "",
            .line_start = 0,
            .kind = .Struct,
            .fields = std.ArrayList(FieldInfo).init(allocator),
            .methods = std.ArrayList([]const u8).init(allocator),
            .is_public = false,
        };
    }

    pub fn deinit(self: *TypeInfo) void {
        self.fields.deinit();
        self.methods.deinit();
    }
};

/// Информация о модуле/файле
pub const ModuleInfo = struct {
    path: []const u8,
    imports: std.ArrayList([]const u8),
    functions: std.ArrayList(FunctionInfo),
    types: std.ArrayList(TypeInfo),
    lines_of_code: u32,
    comment_lines: u32,
    blank_lines: u32,

    pub fn init(allocator: std.mem.Allocator) ModuleInfo {
        return ModuleInfo{
            .path = "",
            .imports = std.ArrayList([]const u8).init(allocator),
            .functions = std.ArrayList(FunctionInfo).init(allocator),
            .types = std.ArrayList(TypeInfo).init(allocator),
            .lines_of_code = 0,
            .comment_lines = 0,
            .blank_lines = 0,
        };
    }

    pub fn deinit(self: *ModuleInfo) void {
        self.imports.deinit();
        for (self.functions.items) |*f| {
            f.deinit();
        }
        self.functions.deinit();
        for (self.types.items) |*t| {
            t.deinit();
        }
        self.types.deinit();
    }
};

/// Метрики кодовой базы
pub const CodebaseMetrics = struct {
    total_files: u32,
    total_lines: u32,
    total_functions: u32,
    total_types: u32,
    total_tests: u32,
    avg_complexity: f32,
    max_complexity: u32,
    test_coverage_estimate: f32,
};

/// Паттерн в коде
pub const CodePattern = struct {
    name: []const u8,
    description: []const u8,
    occurrences: u32,
    files: std.ArrayList([]const u8),
    confidence: f32, // 0.0 - 1.0

    pub fn init(allocator: std.mem.Allocator, name: []const u8) CodePattern {
        return CodePattern{
            .name = name,
            .description = "",
            .occurrences = 0,
            .files = std.ArrayList([]const u8).init(allocator),
            .confidence = 0.0,
        };
    }

    pub fn deinit(self: *CodePattern) void {
        self.files.deinit();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CODE ANALYZER
// ═══════════════════════════════════════════════════════════════════════════════

pub const CodeAnalyzer = struct {
    allocator: std.mem.Allocator,
    codebase_interface: *codebase.Codebase,
    
    // Cached analysis results
    modules: std.StringHashMap(ModuleInfo),
    patterns: std.ArrayList(CodePattern),
    metrics: ?CodebaseMetrics,

    pub fn init(allocator: std.mem.Allocator, cb: *codebase.Codebase) CodeAnalyzer {
        return CodeAnalyzer{
            .allocator = allocator,
            .codebase_interface = cb,
            .modules = std.StringHashMap(ModuleInfo).init(allocator),
            .patterns = std.ArrayList(CodePattern).init(allocator),
            .metrics = null,
        };
    }

    pub fn deinit(self: *CodeAnalyzer) void {
        var iter = self.modules.iterator();
        while (iter.next()) |entry| {
            var module = entry.value_ptr.*;
            module.deinit();
        }
        self.modules.deinit();
        
        for (self.patterns.items) |*p| {
            p.deinit();
        }
        self.patterns.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ANALYSIS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Анализировать файл
    pub fn analyzeFile(self: *CodeAnalyzer, path: []const u8) !ModuleInfo {
        const result = self.codebase_interface.readFile(path);
        if (!result.success) {
            return error.FileNotFound;
        }

        const content = result.content.?;
        var module = ModuleInfo.init(self.allocator);
        module.path = try self.allocator.dupe(u8, path);

        // Parse content
        try self.parseZigFile(content, &module);

        // Cache result
        try self.modules.put(module.path, module);

        return module;
    }

    /// Анализировать всю кодовую базу
    pub fn analyzeCodebase(self: *CodeAnalyzer, patterns_to_find: []const []const u8) !CodebaseMetrics {
        // Find all Zig files
        const files = try self.codebase_interface.findFiles("*.zig");
        defer {
            for (files.items) |f| {
                self.allocator.free(f);
            }
            files.deinit();
        }

        var total_lines: u32 = 0;
        var total_functions: u32 = 0;
        var total_types: u32 = 0;
        var total_tests: u32 = 0;
        var total_complexity: u32 = 0;
        var max_complexity: u32 = 0;

        for (files.items) |file| {
            const module = self.analyzeFile(file) catch continue;
            
            total_lines += module.lines_of_code;
            total_functions += @intCast(module.functions.items.len);
            total_types += @intCast(module.types.items.len);
            
            for (module.functions.items) |func| {
                if (func.is_test) total_tests += 1;
                total_complexity += func.complexity;
                if (func.complexity > max_complexity) {
                    max_complexity = func.complexity;
                }
            }
        }

        // Detect patterns
        for (patterns_to_find) |pattern_name| {
            try self.detectPattern(pattern_name);
        }

        const avg_complexity = if (total_functions > 0)
            @as(f32, @floatFromInt(total_complexity)) / @as(f32, @floatFromInt(total_functions))
        else
            0.0;

        const test_coverage = if (total_functions > 0)
            @as(f32, @floatFromInt(total_tests)) / @as(f32, @floatFromInt(total_functions)) * 100.0
        else
            0.0;

        self.metrics = CodebaseMetrics{
            .total_files = @intCast(files.items.len),
            .total_lines = total_lines,
            .total_functions = total_functions,
            .total_types = total_types,
            .total_tests = total_tests,
            .avg_complexity = avg_complexity,
            .max_complexity = max_complexity,
            .test_coverage_estimate = test_coverage,
        };

        return self.metrics.?;
    }

    /// Найти функции по имени/паттерну
    pub fn findFunctions(self: *CodeAnalyzer, pattern: []const u8) !std.ArrayList(FunctionInfo) {
        var result = std.ArrayList(FunctionInfo).init(self.allocator);

        var iter = self.modules.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.functions.items) |func| {
                if (std.mem.indexOf(u8, func.name, pattern) != null) {
                    try result.append(func);
                }
            }
        }

        return result;
    }

    /// Найти типы по имени/паттерну
    pub fn findTypes(self: *CodeAnalyzer, pattern: []const u8) !std.ArrayList(TypeInfo) {
        var result = std.ArrayList(TypeInfo).init(self.allocator);

        var iter = self.modules.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.types.items) |t| {
                if (std.mem.indexOf(u8, t.name, pattern) != null) {
                    try result.append(t);
                }
            }
        }

        return result;
    }

    /// Получить зависимости модуля
    pub fn getDependencies(self: *CodeAnalyzer, path: []const u8) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(self.allocator);

        if (self.modules.get(path)) |module| {
            for (module.imports.items) |import_path| {
                try result.append(import_path);
            }
        }

        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PARSING
    // ═══════════════════════════════════════════════════════════════════════════

    fn parseZigFile(self: *CodeAnalyzer, content: []const u8, module: *ModuleInfo) !void {
        var lines = std.mem.splitScalar(u8, content, '\n');
        var line_num: u32 = 0;
        var in_function = false;
        var current_func: ?FunctionInfo = null;
        var brace_depth: u32 = 0;

        while (lines.next()) |line| {
            line_num += 1;
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Count line types
            if (trimmed.len == 0) {
                module.blank_lines += 1;
            } else if (std.mem.startsWith(u8, trimmed, "//")) {
                module.comment_lines += 1;
            } else {
                module.lines_of_code += 1;
            }

            // Parse imports
            if (std.mem.startsWith(u8, trimmed, "const ") and std.mem.indexOf(u8, trimmed, "@import") != null) {
                if (self.extractImport(trimmed)) |import_name| {
                    try module.imports.append(import_name);
                }
            }

            // Parse function definitions
            if (std.mem.indexOf(u8, trimmed, "fn ") != null or std.mem.indexOf(u8, trimmed, "pub fn ") != null) {
                if (current_func) |*func| {
                    func.line_end = line_num - 1;
                    try module.functions.append(func.*);
                }

                var func = FunctionInfo.init(self.allocator);
                func.line_start = line_num;
                func.is_public = std.mem.startsWith(u8, trimmed, "pub ");
                func.is_test = std.mem.indexOf(u8, trimmed, "test \"") != null;
                func.file_path = module.path;

                if (self.extractFunctionName(trimmed)) |name| {
                    func.name = name;
                }

                current_func = func;
                in_function = true;
                brace_depth = 0;
            }

            // Track brace depth for function end
            if (in_function) {
                for (trimmed) |c| {
                    if (c == '{') brace_depth += 1;
                    if (c == '}') {
                        if (brace_depth > 0) brace_depth -= 1;
                        if (brace_depth == 0) {
                            if (current_func) |*func| {
                                func.line_end = line_num;
                                try module.functions.append(func.*);
                                current_func = null;
                                in_function = false;
                            }
                        }
                    }
                }

                // Estimate complexity (count control flow)
                if (current_func) |*func| {
                    if (std.mem.indexOf(u8, trimmed, "if ") != null or
                        std.mem.indexOf(u8, trimmed, "else ") != null or
                        std.mem.indexOf(u8, trimmed, "while ") != null or
                        std.mem.indexOf(u8, trimmed, "for ") != null or
                        std.mem.indexOf(u8, trimmed, "switch ") != null or
                        std.mem.indexOf(u8, trimmed, "catch ") != null)
                    {
                        func.complexity += 1;
                    }
                }
            }

            // Parse struct/enum definitions
            if (std.mem.indexOf(u8, trimmed, "struct {") != null or
                std.mem.indexOf(u8, trimmed, "enum {") != null or
                std.mem.indexOf(u8, trimmed, "union {") != null)
            {
                var type_info = TypeInfo.init(self.allocator);
                type_info.line_start = line_num;
                type_info.file_path = module.path;
                type_info.is_public = std.mem.startsWith(u8, trimmed, "pub ");

                if (std.mem.indexOf(u8, trimmed, "struct") != null) {
                    type_info.kind = .Struct;
                } else if (std.mem.indexOf(u8, trimmed, "enum") != null) {
                    type_info.kind = .Enum;
                } else {
                    type_info.kind = .Union;
                }

                if (self.extractTypeName(trimmed)) |name| {
                    type_info.name = name;
                }

                try module.types.append(type_info);
            }
        }

        // Handle last function if file doesn't end with }
        if (current_func) |*func| {
            func.line_end = line_num;
            try module.functions.append(func.*);
        }
    }

    fn extractImport(self: *CodeAnalyzer, line: []const u8) ?[]const u8 {
        _ = self;
        // const foo = @import("bar.zig");
        const start = std.mem.indexOf(u8, line, "\"") orelse return null;
        const end = std.mem.lastIndexOf(u8, line, "\"") orelse return null;
        if (end <= start + 1) return null;
        return line[start + 1 .. end];
    }

    fn extractFunctionName(self: *CodeAnalyzer, line: []const u8) ?[]const u8 {
        _ = self;
        // pub fn foo(args) ReturnType {
        const fn_pos = std.mem.indexOf(u8, line, "fn ") orelse return null;
        const name_start = fn_pos + 3;
        const paren_pos = std.mem.indexOf(u8, line[name_start..], "(") orelse return null;
        return line[name_start .. name_start + paren_pos];
    }

    fn extractTypeName(self: *CodeAnalyzer, line: []const u8) ?[]const u8 {
        _ = self;
        // const Foo = struct {
        // pub const Bar = enum {
        const eq_pos = std.mem.indexOf(u8, line, " = ") orelse return null;
        const const_pos = std.mem.indexOf(u8, line, "const ") orelse return null;
        const name_start = const_pos + 6;
        if (name_start >= eq_pos) return null;
        return line[name_start..eq_pos];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PATTERN DETECTION
    // ═══════════════════════════════════════════════════════════════════════════

    fn detectPattern(self: *CodeAnalyzer, pattern_name: []const u8) !void {
        var pattern = CodePattern.init(self.allocator, pattern_name);

        if (std.mem.eql(u8, pattern_name, "singleton")) {
            try self.detectSingletonPattern(&pattern);
        } else if (std.mem.eql(u8, pattern_name, "factory")) {
            try self.detectFactoryPattern(&pattern);
        } else if (std.mem.eql(u8, pattern_name, "builder")) {
            try self.detectBuilderPattern(&pattern);
        }

        if (pattern.occurrences > 0) {
            try self.patterns.append(pattern);
        } else {
            pattern.deinit();
        }
    }

    fn detectSingletonPattern(self: *CodeAnalyzer, pattern: *CodePattern) !void {
        var iter = self.modules.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.functions.items) |func| {
                if (std.mem.eql(u8, func.name, "getInstance") or
                    std.mem.eql(u8, func.name, "instance"))
                {
                    pattern.occurrences += 1;
                    try pattern.files.append(func.file_path);
                }
            }
        }
        pattern.description = "Singleton pattern detected via getInstance/instance methods";
        pattern.confidence = if (pattern.occurrences > 0) 0.8 else 0.0;
    }

    fn detectFactoryPattern(self: *CodeAnalyzer, pattern: *CodePattern) !void {
        var iter = self.modules.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.functions.items) |func| {
                if (std.mem.startsWith(u8, func.name, "create") or
                    std.mem.startsWith(u8, func.name, "make") or
                    std.mem.startsWith(u8, func.name, "new"))
                {
                    pattern.occurrences += 1;
                    try pattern.files.append(func.file_path);
                }
            }
        }
        pattern.description = "Factory pattern detected via create/make/new methods";
        pattern.confidence = if (pattern.occurrences > 0) 0.7 else 0.0;
    }

    fn detectBuilderPattern(self: *CodeAnalyzer, pattern: *CodePattern) !void {
        var iter = self.modules.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.functions.items) |func| {
                if (std.mem.eql(u8, func.name, "build") or
                    std.mem.indexOf(u8, func.name, "Builder") != null)
                {
                    pattern.occurrences += 1;
                    try pattern.files.append(func.file_path);
                }
            }
        }
        pattern.description = "Builder pattern detected via build methods or Builder types";
        pattern.confidence = if (pattern.occurrences > 0) 0.75 else 0.0;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // REPORTING
    // ═══════════════════════════════════════════════════════════════════════════

    /// Сгенерировать отчёт об анализе
    pub fn generateReport(self: *CodeAnalyzer) ![]const u8 {
        var report = std.ArrayList(u8).init(self.allocator);
        const writer = report.writer();

        try writer.writeAll("═══════════════════════════════════════════════════════════════\n");
        try writer.writeAll("                    MAXWELL CODE ANALYSIS REPORT\n");
        try writer.writeAll("═══════════════════════════════════════════════════════════════\n\n");

        if (self.metrics) |m| {
            try writer.print("METRICS:\n", .{});
            try writer.print("  Total files:      {d}\n", .{m.total_files});
            try writer.print("  Total lines:      {d}\n", .{m.total_lines});
            try writer.print("  Total functions:  {d}\n", .{m.total_functions});
            try writer.print("  Total types:      {d}\n", .{m.total_types});
            try writer.print("  Total tests:      {d}\n", .{m.total_tests});
            try writer.print("  Avg complexity:   {d:.2}\n", .{m.avg_complexity});
            try writer.print("  Max complexity:   {d}\n", .{m.max_complexity});
            try writer.print("  Test coverage:    {d:.1}%\n", .{m.test_coverage_estimate});
        }

        try writer.writeAll("\nPATTERNS DETECTED:\n");
        for (self.patterns.items) |p| {
            try writer.print("  - {s}: {d} occurrences (confidence: {d:.0}%)\n", .{ p.name, p.occurrences, p.confidence * 100 });
        }

        try writer.writeAll("\n═══════════════════════════════════════════════════════════════\n");

        return report.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CodeAnalyzer init and deinit" {
    var cb = codebase.Codebase.init(std.testing.allocator, "/tmp");
    defer cb.deinit();

    var analyzer = CodeAnalyzer.init(std.testing.allocator, &cb);
    defer analyzer.deinit();
}

test "CodeAnalyzer parse function" {
    var cb = codebase.Codebase.init(std.testing.allocator, "/tmp");
    defer cb.deinit();

    var analyzer = CodeAnalyzer.init(std.testing.allocator, &cb);
    defer analyzer.deinit();

    var module = ModuleInfo.init(std.testing.allocator);
    defer module.deinit();

    const code =
        \\const std = @import("std");
        \\
        \\pub fn add(a: i32, b: i32) i32 {
        \\    return a + b;
        \\}
        \\
        \\fn helper() void {
        \\    if (true) {
        \\        // do something
        \\    }
        \\}
    ;

    try analyzer.parseZigFile(code, &module);

    try std.testing.expectEqual(@as(usize, 1), module.imports.items.len);
    try std.testing.expectEqual(@as(usize, 2), module.functions.items.len);
    try std.testing.expect(module.functions.items[0].is_public);
    try std.testing.expect(!module.functions.items[1].is_public);
}
