// Maxwell Daemon - Spec Generator
// Генерация .vibee спецификаций из описания задачи
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const code_analyzer = @import("code_analyzer.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Тип поля в спецификации
pub const FieldType = enum {
    String,
    Int,
    Float,
    Bool,
    List,
    Option,
    Custom,

    pub fn toString(self: FieldType) []const u8 {
        return switch (self) {
            .String => "String",
            .Int => "Int",
            .Float => "Float",
            .Bool => "Bool",
            .List => "List",
            .Option => "Option",
            .Custom => "Custom",
        };
    }
};

/// Поле типа
pub const SpecField = struct {
    name: []const u8,
    field_type: FieldType,
    inner_type: ?[]const u8, // For List<T> or Option<T>
    description: ?[]const u8,
};

/// Тип в спецификации
pub const SpecType = struct {
    name: []const u8,
    fields: std.ArrayList(SpecField),
    description: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) SpecType {
        return SpecType{
            .name = name,
            .fields = std.ArrayList(SpecField).init(allocator),
            .description = null,
        };
    }

    pub fn deinit(self: *SpecType) void {
        self.fields.deinit();
    }

    pub fn addField(self: *SpecType, name: []const u8, field_type: FieldType) !void {
        try self.fields.append(SpecField{
            .name = name,
            .field_type = field_type,
            .inner_type = null,
            .description = null,
        });
    }

    pub fn addListField(self: *SpecType, name: []const u8, inner_type: []const u8) !void {
        try self.fields.append(SpecField{
            .name = name,
            .field_type = .List,
            .inner_type = inner_type,
            .description = null,
        });
    }

    pub fn addOptionField(self: *SpecType, name: []const u8, inner_type: []const u8) !void {
        try self.fields.append(SpecField{
            .name = name,
            .field_type = .Option,
            .inner_type = inner_type,
            .description = null,
        });
    }
};

/// Поведение в спецификации
pub const SpecBehavior = struct {
    name: []const u8,
    given: []const u8,
    when: []const u8,
    then: []const u8,
};

/// Полная спецификация
pub const Specification = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8,
    module: []const u8,
    types: std.ArrayList(SpecType),
    behaviors: std.ArrayList(SpecBehavior),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Specification {
        return Specification{
            .name = name,
            .version = "1.0.0",
            .language = "zig",
            .module = name,
            .types = std.ArrayList(SpecType).init(allocator),
            .behaviors = std.ArrayList(SpecBehavior).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Specification) void {
        for (self.types.items) |*t| {
            t.deinit();
        }
        self.types.deinit();
        self.behaviors.deinit();
    }

    pub fn addType(self: *Specification, spec_type: SpecType) !void {
        try self.types.append(spec_type);
    }

    pub fn addBehavior(self: *Specification, name: []const u8, given: []const u8, when: []const u8, then: []const u8) !void {
        try self.behaviors.append(SpecBehavior{
            .name = name,
            .given = given,
            .when = when,
            .then = then,
        });
    }

    /// Сериализовать в .vibee формат
    pub fn toVibee(self: *Specification) ![]const u8 {
        var output = std.ArrayList(u8).init(self.allocator);
        const writer = output.writer();

        // Header
        try writer.print("name: {s}\n", .{self.name});
        try writer.print("version: \"{s}\"\n", .{self.version});
        try writer.print("language: {s}\n", .{self.language});
        try writer.print("module: {s}\n", .{self.module});
        try writer.writeAll("\n");

        // Types
        if (self.types.items.len > 0) {
            try writer.writeAll("types:\n");
            for (self.types.items) |spec_type| {
                try writer.print("  {s}:\n", .{spec_type.name});
                try writer.writeAll("    fields:\n");
                for (spec_type.fields.items) |field| {
                    const type_str: []const u8 = switch (field.field_type) {
                        .List => if (field.inner_type) |_| "List<T>" else "List<String>",
                        .Option => if (field.inner_type) |_| "Option<T>" else "Option<String>",
                        else => field.field_type.toString(),
                    };
                    try writer.print("      {s}: {s}\n", .{ field.name, type_str });
                }
                try writer.writeAll("\n");
            }
        }

        // Behaviors
        if (self.behaviors.items.len > 0) {
            try writer.writeAll("behaviors:\n");
            for (self.behaviors.items) |behavior| {
                try writer.print("  - name: {s}\n", .{behavior.name});
                try writer.print("    given: {s}\n", .{behavior.given});
                try writer.print("    when: {s}\n", .{behavior.when});
                try writer.print("    then: {s}\n", .{behavior.then});
                try writer.writeAll("\n");
            }
        }

        return output.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPEC GENERATOR
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpecGenerator = struct {
    allocator: std.mem.Allocator,
    templates: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) SpecGenerator {
        var gen = SpecGenerator{
            .allocator = allocator,
            .templates = std.StringHashMap([]const u8).init(allocator),
        };
        gen.loadDefaultTemplates();
        return gen;
    }

    pub fn deinit(self: *SpecGenerator) void {
        self.templates.deinit();
    }

    fn loadDefaultTemplates(self: *SpecGenerator) void {
        // CRUD template
        self.templates.put("crud", 
            \\name: {name}
            \\version: "1.0.0"
            \\language: zig
            \\module: {name}
            \\
            \\types:
            \\  {Entity}:
            \\    fields:
            \\      id: Int
            \\      created_at: Int
            \\      updated_at: Int
            \\
            \\behaviors:
            \\  - name: create
            \\    given: {Entity} data
            \\    when: User creates new {entity}
            \\    then: Returns created {Entity} with id
            \\
            \\  - name: read
            \\    given: {Entity} id
            \\    when: User requests {entity}
            \\    then: Returns {Entity} or error
            \\
            \\  - name: update
            \\    given: {Entity} id and data
            \\    when: User updates {entity}
            \\    then: Returns updated {Entity}
            \\
            \\  - name: delete
            \\    given: {Entity} id
            \\    when: User deletes {entity}
            \\    then: Returns success or error
        ) catch {};

        // Service template
        self.templates.put("service",
            \\name: {name}_service
            \\version: "1.0.0"
            \\language: zig
            \\module: {name}_service
            \\
            \\types:
            \\  Request:
            \\    fields:
            \\      data: String
            \\
            \\  Response:
            \\    fields:
            \\      success: Bool
            \\      result: Option<String>
            \\      error: Option<String>
            \\
            \\behaviors:
            \\  - name: process
            \\    given: Request
            \\    when: Service receives request
            \\    then: Returns Response
        ) catch {};

        // Test template
        self.templates.put("test",
            \\name: {name}_test
            \\version: "1.0.0"
            \\language: zig
            \\module: {name}_test
            \\
            \\behaviors:
            \\  - name: test_{name}
            \\    given: Test setup
            \\    when: Test runs
            \\    then: Assertions pass
        ) catch {};
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GENERATION
    // ═══════════════════════════════════════════════════════════════════════════

    /// Сгенерировать спецификацию из описания задачи
    pub fn generateFromDescription(self: *SpecGenerator, description: []const u8, name: []const u8) !Specification {
        var spec = Specification.init(self.allocator, name);

        // Analyze description to determine what to generate
        const lower_desc = try self.toLower(description);
        defer self.allocator.free(lower_desc);

        // Detect patterns in description
        if (std.mem.indexOf(u8, lower_desc, "crud") != null or
            std.mem.indexOf(u8, lower_desc, "create") != null and std.mem.indexOf(u8, lower_desc, "delete") != null)
        {
            try self.applyCrudPattern(&spec, name);
        } else if (std.mem.indexOf(u8, lower_desc, "service") != null or
            std.mem.indexOf(u8, lower_desc, "api") != null)
        {
            try self.applyServicePattern(&spec, name);
        } else if (std.mem.indexOf(u8, lower_desc, "test") != null) {
            try self.applyTestPattern(&spec, name);
        } else {
            // Default: simple module
            try self.applyDefaultPattern(&spec, name, description);
        }

        return spec;
    }

    /// Сгенерировать из шаблона
    pub fn generateFromTemplate(self: *SpecGenerator, template_name: []const u8, name: []const u8) ![]const u8 {
        const template = self.templates.get(template_name) orelse return error.TemplateNotFound;

        // Simple template substitution
        var result = std.ArrayList(u8).init(self.allocator);
        var i: usize = 0;

        while (i < template.len) {
            if (template[i] == '{') {
                const end = std.mem.indexOf(u8, template[i..], "}") orelse {
                    try result.append(template[i]);
                    i += 1;
                    continue;
                };

                const var_name = template[i + 1 .. i + end];
                if (std.mem.eql(u8, var_name, "name")) {
                    try result.appendSlice(name);
                } else if (std.mem.eql(u8, var_name, "Entity")) {
                    // Capitalize first letter
                    if (name.len > 0) {
                        try result.append(std.ascii.toUpper(name[0]));
                        if (name.len > 1) {
                            try result.appendSlice(name[1..]);
                        }
                    }
                } else if (std.mem.eql(u8, var_name, "entity")) {
                    try result.appendSlice(name);
                } else {
                    try result.appendSlice(template[i .. i + end + 1]);
                }
                i += end + 1;
            } else {
                try result.append(template[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice();
    }

    /// Сгенерировать из анализа существующего кода
    pub fn generateFromAnalysis(self: *SpecGenerator, module: *const code_analyzer.ModuleInfo) !Specification {
        var spec = Specification.init(self.allocator, module.path);

        // Convert types
        for (module.types.items) |type_info| {
            var spec_type = SpecType.init(self.allocator, type_info.name);

            for (type_info.fields.items) |field| {
                try spec_type.addField(field.name, self.inferFieldType(field.field_type));
            }

            try spec.addType(spec_type);
        }

        // Convert functions to behaviors
        for (module.functions.items) |func| {
            if (!func.is_test) {
                try spec.addBehavior(
                    func.name,
                    "Input parameters",
                    "Function is called",
                    "Returns result",
                );
            }
        }

        return spec;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PATTERNS
    // ═══════════════════════════════════════════════════════════════════════════

    fn applyCrudPattern(self: *SpecGenerator, spec: *Specification, name: []const u8) !void {
        // Entity type
        var entity = SpecType.init(self.allocator, name);
        try entity.addField("id", .Int);
        try entity.addField("created_at", .Int);
        try entity.addField("updated_at", .Int);
        try spec.addType(entity);

        // CRUD behaviors
        try spec.addBehavior("create", "Entity data", "User creates new entity", "Returns created entity with id");
        try spec.addBehavior("read", "Entity id", "User requests entity", "Returns entity or error");
        try spec.addBehavior("update", "Entity id and data", "User updates entity", "Returns updated entity");
        try spec.addBehavior("delete", "Entity id", "User deletes entity", "Returns success or error");
        try spec.addBehavior("list", "Filter options", "User lists entities", "Returns list of entities");
    }

    fn applyServicePattern(self: *SpecGenerator, spec: *Specification, name: []const u8) !void {
        _ = name;

        // Request type
        var request = SpecType.init(self.allocator, "Request");
        try request.addField("data", .String);
        try request.addField("timestamp", .Int);
        try spec.addType(request);

        // Response type
        var response = SpecType.init(self.allocator, "Response");
        try response.addField("success", .Bool);
        try response.addOptionField("result", "String");
        try response.addOptionField("error", "String");
        try spec.addType(response);

        // Service behaviors
        try spec.addBehavior("process", "Request", "Service receives request", "Returns Response");
        try spec.addBehavior("validate", "Request", "Before processing", "Returns validation result");
        try spec.addBehavior("handle_error", "Error", "When error occurs", "Returns error Response");
    }

    fn applyTestPattern(_: *SpecGenerator, spec: *Specification, _: []const u8) !void {
        try spec.addBehavior("test_init", "Test setup", "Test initializes", "Setup completes");
        try spec.addBehavior("test_main", "Test input", "Test runs", "Assertions pass");
        try spec.addBehavior("test_cleanup", "Test teardown", "Test completes", "Cleanup done");
    }

    fn applyDefaultPattern(self: *SpecGenerator, spec: *Specification, _: []const u8, _: []const u8) !void {
        // Default result type
        var result = SpecType.init(self.allocator, "Result");
        try result.addField("value", .Int);
        try result.addField("success", .Bool);
        try spec.addType(result);

        // Default behavior
        try spec.addBehavior("process", "Input", "Called", "Returns Result");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn toLower(self: *SpecGenerator, str: []const u8) ![]u8 {
        const result = try self.allocator.alloc(u8, str.len);
        for (str, 0..) |c, i| {
            result[i] = std.ascii.toLower(c);
        }
        return result;
    }

    fn inferFieldType(self: *SpecGenerator, zig_type: []const u8) FieldType {
        _ = self;
        if (std.mem.indexOf(u8, zig_type, "i32") != null or
            std.mem.indexOf(u8, zig_type, "i64") != null or
            std.mem.indexOf(u8, zig_type, "u32") != null or
            std.mem.indexOf(u8, zig_type, "usize") != null)
        {
            return .Int;
        }
        if (std.mem.indexOf(u8, zig_type, "f32") != null or
            std.mem.indexOf(u8, zig_type, "f64") != null)
        {
            return .Float;
        }
        if (std.mem.indexOf(u8, zig_type, "bool") != null) {
            return .Bool;
        }
        if (std.mem.indexOf(u8, zig_type, "[]") != null) {
            return .String;
        }
        return .Custom;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Specification toVibee" {
    var spec = Specification.init(std.testing.allocator, "test_module");
    defer spec.deinit();

    var my_type = SpecType.init(std.testing.allocator, "MyType");
    try my_type.addField("name", .String);
    try my_type.addField("count", .Int);
    try spec.addType(my_type);

    try spec.addBehavior("process", "Input", "Called", "Returns result");

    const vibee = try spec.toVibee();
    defer std.testing.allocator.free(vibee);

    try std.testing.expect(std.mem.indexOf(u8, vibee, "name: test_module") != null);
    try std.testing.expect(std.mem.indexOf(u8, vibee, "MyType:") != null);
    try std.testing.expect(std.mem.indexOf(u8, vibee, "behaviors:") != null);
}

test "SpecGenerator generateFromDescription CRUD" {
    var gen = SpecGenerator.init(std.testing.allocator);
    defer gen.deinit();

    var spec = try gen.generateFromDescription("Create a CRUD API for users", "user");
    defer spec.deinit();

    try std.testing.expect(spec.behaviors.items.len >= 4);
}

test "SpecGenerator generateFromTemplate" {
    var gen = SpecGenerator.init(std.testing.allocator);
    defer gen.deinit();

    const result = try gen.generateFromTemplate("service", "payment");
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "payment_service") != null);
}
