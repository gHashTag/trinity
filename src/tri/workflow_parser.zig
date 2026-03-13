// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI WORKFLOW PARSER — YAML Schema Parser
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred Formula: φ² + 1/φ² = 3
// Parses workflow YAML schema into typed structures
//
// Author: TRI ORCHESTRATOR
// Version: 1.0.0
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringHashMap = std.StringHashMapUnmanaged;

const workflow = @import("workflow.zig");
const Workflow = workflow.Workflow;
const WorkflowStep = workflow.WorkflowStep;
const WorkflowVariable = workflow.WorkflowVariable;
const ExecutorConfig = workflow.ExecutorConfig;
const ExecutionOptions = workflow.ExecutionOptions;

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Parser error type
pub const ParserError = error{
    InvalidYaml,
    MissingRequiredField,
    InvalidFieldType,
    InvalidEnumValue,
    CircularReference,
    WorkflowTooLarge,
    InvalidStepId,
    InvalidVariableName,
    CommandTooLong,
    TooManyArguments,
    TimeoutExceeded,
} || Allocator.Error;

/// YAML value types for parsing
const YamlValue = union(enum) {
    scalar: []const u8,
    array: []const []const u8,
    object: StringHashMap([]const u8),

    pub fn deinit(self: *YamlValue, allocator: Allocator) void {
        switch (self.*) {
            .scalar => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |item| {
                    allocator.free(item);
                }
                allocator.free(arr);
            },
            .object => |obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    allocator.free(entry.value_ptr.*);
                }
                obj.deinit();
            },
        }
    }
};

/// Parsed YAML document
const YamlDocument = struct {
    allocator: Allocator,
    root: YamlValue,

    pub fn init(allocator: Allocator) YamlDocument {
        return YamlDocument{
            .allocator = allocator,
            .root = YamlValue{ .object = StringHashMap([]const u8).init(allocator) },
        };
    }

    pub fn deinit(self: *YamlDocument) void {
        self.root.deinit(self.allocator);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKFLOW PARSER
// ═══════════════════════════════════════════════════════════════════════════════

/// Workflow YAML parser
pub const WorkflowParser = struct {
    allocator: Allocator,
    documents: ArrayList(YamlDocument),

    pub fn init(allocator: Allocator) WorkflowParser {
        return WorkflowParser{
            .allocator = allocator,
            .documents = ArrayList(YamlDocument).init(allocator),
        };
    }

    pub fn deinit(self: *WorkflowParser) void {
        for (self.documents.items) |*doc| {
            doc.deinit();
        }
        self.documents.deinit();
    }

    /// Parse workflow from YAML string
    pub fn parseWorkflow(self: *WorkflowParser, yaml_content: []const u8) !Workflow {
        const allocator = self.allocator;
        var yaml_doc = try self.parseYaml(yaml_content);
        defer yaml_doc.deinit();

        var workflow = Workflow.init(allocator);
        defer workflow.deinit();

        // Parse workflow root object
        if (yaml_doc.root == .object) |root| {
            // Parse name
            if (root.get("name")) |name| {
                workflow.name = try allocator.dupe(u8, name);
            } else {
                return ParserError.MissingRequiredField;
            }

            // Parse description
            if (root.get("description")) |desc| {
                workflow.description = try allocator.dupe(u8, desc);
            }

            // Parse version
            if (root.get("version")) |version| {
                workflow.version = try allocator.dupe(u8, version);
            }

            // Parse strategy
            if (root.get("strategy")) |strategy_str| {
                workflow.strategy = try parseStrategy(strategy_str);
            }

            // Parse rollback_enabled
            if (root.get("rollback_enabled")) |rollback_str| {
                workflow.rollback_enabled = try parseBoolean(rollback_str);
            }

            // Parse sacred_validation
            if (root.get("sacred_validation")) |sacred_str| {
                workflow.sacred_validation = try parseBoolean(sacred_str);
            }

            // Parse timeout_ms
            if (root.get("timeout_ms")) |timeout_str| {
                workflow.timeout_ms = try parseInteger(u64, timeout_str);
                if (workflow.timeout_ms.? > workflow.MAX_WORKFLOW_DURATION_MS) {
                    return ParserError.TimeoutExceeded;
                }
            }

            // Parse variables
            if (root.get("variables")) |vars_str| {
                try self.parseVariables(&workflow, vars_str);
            }

            // Parse steps
            if (root.get("steps")) |steps_str| {
                try self.parseSteps(&workflow, steps_str);
            }
        } else {
            return ParserError.InvalidYaml;
        }

        return workflow;
    }

    /// Parse execution options from YAML
    pub fn parseExecutionOptions(self: *WorkflowParser, yaml_content: []const u8, workflow_id: []const u8) !ExecutionOptions {
        const allocator = self.allocator;
        var yaml_doc = try self.parseYaml(yaml_content);
        defer yaml_doc.deinit();

        var options = ExecutionOptions.init(allocator, workflow_id);
        defer options.deinit();

        if (yaml_doc.root == .object) |root| {
            // Parse variables
            if (root.get("variables")) |vars_str| {
                var it = std.mem.tokenize(u8, vars_str, ",\n");
                while (it.next()) |var_pair| {
                    var kv_it = std.mem.tokenize(u8, var_pair, "=");
                    if (kv_it.next()) |key| {
                        if (kv_it.next()) |value| {
                            try options.variables.put(try allocator.dupe(u8, std.mem.trim(u8, key, " \t\"'")), try allocator.dupe(u8, std.mem.trim(u8, value, " \t\"'")));
                        }
                    }
                }
            }

            // Parse dry_run
            if (root.get("dry_run")) |dry_run_str| {
                options.dry_run = try parseBoolean(dry_run_str);
            }

            // Parse validate_only
            if (root.get("validate_only")) |validate_only_str| {
                options.validate_only = try parseBoolean(validate_only_str);
            }

            // Parse resume_from_step
            if (root.get("resume_from_step")) |resume_str| {
                options.resume_from_step = try allocator.dupe(u8, std.mem.trim(u8, resume_str, " \t\"'"));
            }

            // Parse timeout_ms
            if (root.get("timeout_ms")) |timeout_str| {
                options.timeout_ms = try parseInteger(u64, timeout_str);
                if (options.timeout_ms.? > workflow.MAX_WORKFLOW_DURATION_MS) {
                    return ParserError.TimeoutExceeded;
                }
            }

            // Parse config
            if (root.get("config")) |config_str| {
                try self.parseExecutorConfig(&options.config, config_str);
            }
        }

        return options;
    }

    /// Parse YAML string into document structure
    fn parseYaml(self: *WorkflowParser, yaml_content: []const u8) !YamlDocument {
        const allocator = self.allocator;
        var doc = YamlDocument.init(allocator);

        // Simple YAML parser (simplified - for full YAML parsing, consider using a YAML library)
        // This handles the specific workflow schema format

        var lines = std.mem.tokenize(u8, yaml_content, "\n");
        var current_indent: usize = 0;
        var stack = ArrayList(struct { indent: usize, map: StringHashMap([]const u8) }).init(allocator);
        defer stack.deinit();

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) {
                continue; // Skip empty lines and comments
            }

            const indent = std.mem.trim(u8, line, " \t").ptr - line.ptr;
            const content = trimmed;

            if (std.mem.startsWith(u8, content, "- ")) {
                // Array item
                if (stack.items.len == 0) {
                    return ParserError.InvalidYaml;
                }
                const item_value = content[2..];
                try self.parseArrayItem(&stack.items[stack.items.len - 1].map, item_value, indent);
            } else if (std.mem.indexOf(u8, content, ":") != null) {
                // Object key-value pair
                const colon_pos = std.mem.indexOf(u8, content, ":").?;
                const key = content[0..colon_pos];
                const value = content[colon_pos + 1 ..];

                if (std.mem.trim(u8, value, " \t").len == 0) {
                    // Object - push to stack
                    const new_map = StringHashMap([]const u8).init(allocator);
                    try stack.append(.{ .indent = indent, .map = new_map });
                    try doc.root.object.put(key, try allocator.dupe(u8, ""));
                } else {
                    // Scalar value
                    try doc.root.object.put(key, try allocator.dupe(u8, std.mem.trim(u8, value, " \t\"'")));
                }
            } else {
                return ParserError.InvalidYaml;
            }
        }

        return doc;
    }

    /// Parse workflow strategy from string
    fn parseStrategy(strategy_str: []const u8) !workflow.WorkflowStrategy {
        const normalized = std.mem.trim(u8, strategy_str, " \t\"'");
        if (std.mem.eql(u8, normalized, "sequential")) {
            return .sequential;
        } else if (std.mem.eql(u8, normalized, "parallel")) {
            return .parallel;
        } else if (std.mem.eql(u8, normalized, "conditional")) {
            return .conditional;
        } else if (std.mem.eql(u8, normalized, "adaptive")) {
            return .adaptive;
        } else {
            return ParserError.InvalidEnumValue;
        }
    }

    /// Parse workflow realm from string
    fn parseRealm(realm_str: []const u8) !workflow.WorkflowRealm {
        const normalized = std.mem.trim(u8, realm_str, " \t\"'");
        if (std.mem.eql(u8, normalized, "razum")) {
            return .razum;
        } else if (std.mem.eql(u8, normalized, "materiya")) {
            return .materiya;
        } else if (std.mem.eql(u8, normalized, "dukh")) {
            return .dukh;
        } else if (std.mem.eql(u8, normalized, "universal")) {
            return .universal;
        } else {
            return ParserError.InvalidEnumValue;
        }
    }

    /// Parse boolean value from string
    fn parseBoolean(value_str: []const u8) !bool {
        const normalized = std.mem.trim(u8, value_str, " \t\"'");
        if (std.mem.eql(u8, normalized, "true") or std.mem.eql(u8, normalized, "1")) {
            return true;
        } else if (std.mem.eql(u8, normalized, "false") or std.mem.eql(u8, normalized, "0")) {
            return false;
        } else {
            return ParserError.InvalidFieldType;
        }
    }

    /// Parse integer value from string
    fn parseInteger(comptime T: type, value_str: []const u8) !T {
        const normalized = std.mem.trim(u8, value_str, " \t\"'");
        return std.fmt.parseInt(T, normalized, 10) catch return ParserError.InvalidFieldType;
    }

    /// Parse variables section
    fn parseVariables(self: *WorkflowParser, workflow: *Workflow, vars_str: []const u8) !void {
        const allocator = self.allocator;

        // Simple variables parsing: key=value pairs separated by newlines
        var it = std.mem.tokenize(u8, vars_str, "\n");
        while (it.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0) continue;

            const equal_pos = std.mem.indexOf(u8, trimmed, "=");
            if (equal_pos) |pos| {
                const key = trimmed[0..pos];
                const value = trimmed[pos + 1 ..];

                const var_name = std.mem.trim(u8, key, " \t\"'");
                const var_value = std.mem.trim(u8, value, " \t\"'");

                if (var_name.len > workflow.MAX_VARIABLE_NAME_LENGTH) {
                    return ParserError.InvalidVariableName;
                }

                const variable = WorkflowVariable{
                    .name = try allocator.dupe(u8, var_name),
                    .value = try allocator.dupe(u8, var_value),
                    .type = .string, // Default to string type
                };

                try workflow.variables.put(var_name, variable);
            }
        }
    }

    /// Parse steps section
    fn parseSteps(self: *WorkflowParser, workflow: *Workflow, steps_str: []const u8) !void {
        const allocator = self.allocator;

        // Parse steps as YAML array
        var lines = std.mem.tokenize(u8, steps_str, "\n");
        var step_index: usize = 0;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "#")) {
                continue;
            }

            if (std.mem.startsWith(u8, trimmed, "- ")) {
                // Parse step
                const step_yaml = trimmed[2..];
                const step = try self.parseStep(step_yaml, step_index);
                try workflow.steps.append(step);
                step_index += 1;

                if (workflow.steps.items.len > workflow.MAX_WORKFLOW_STEPS) {
                    return ParserError.WorkflowTooLarge;
                }
            }
        }
    }

    /// Parse individual step
    fn parseStep(self: *WorkflowParser, step_yaml: []const u8, step_index: usize) !WorkflowStep {
        const allocator = self.allocator;

        // Simple step parsing - handles: id, name, command, args, condition, depends_on, realm, etc.
        var step = WorkflowStep{};
        defer {
            allocator.free(step.id);
            allocator.free(step.name);
            allocator.free(step.command);
            for (step.args) |arg| {
                allocator.free(arg);
            }
            if (step.condition) |cond| {
                allocator.free(cond);
            }
            for (step.depends_on) |dep| {
                allocator.free(dep);
            }
            if (step.working_directory) |dir| {
                allocator.free(dir);
            }
            if (step.description) |desc| {
                allocator.free(desc);
            }
        }

        // Parse step properties
        const lines = std.mem.splitScalar(u8, step_yaml, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0) continue;

            if (std.mem.indexOf(u8, trimmed, ":") != null) {
                const colon_pos = std.mem.indexOf(u8, trimmed, ":").?;
                const key = trimmed[0..colon_pos];
                const value = trimmed[colon_pos + 1 ..];

                const normalized_key = std.mem.trim(u8, key, " \t");
                const normalized_value = std.mem.trim(u8, value, " \t\"'");

                if (std.mem.eql(u8, normalized_key, "id")) {
                    step.id = try allocator.dupe(u8, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "name")) {
                    step.name = try allocator.dupe(u8, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "command")) {
                    step.command = try allocator.dupe(u8, normalized_value);
                    if (step.command.len > workflow.MAX_COMMAND_LENGTH) {
                        return ParserError.CommandTooLong;
                    }
                } else if (std.mem.eql(u8, normalized_key, "condition")) {
                    step.condition = try allocator.dupe(u8, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "depends_on")) {
                    var deps = std.mem.tokenize(u8, normalized_value, ", ");
                    while (deps.next()) |dep| {
                        const dep_trimmed = std.mem.trim(u8, dep, " \t\"'");
                        try step.depends_on.append(try allocator.dupe(u8, dep_trimmed));
                    }
                } else if (std.mem.eql(u8, normalized_key, "realm")) {
                    step.realm = try self.parseRealm(normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "timeout_ms")) {
                    step.timeout_ms = try parseInteger(u64, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "continue_on_failure")) {
                    step.continue_on_failure = try parseBoolean(normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "description")) {
                    step.description = try allocator.dupe(u8, normalized_value);
                }
            }
        }

        // Validate required fields
        if (step.id.len == 0) {
            step.id = try std.fmt.allocPrint(allocator, "step_{d}", .{step_index});
        }

        if (step.name.len == 0) {
            step.name = try std.fmt.allocPrint(allocator, "Step {d}", .{step_index});
        }

        if (step.command.len == 0) {
            return ParserError.MissingRequiredField;
        }

        // Process args array
        if (step.args.len > workflow.MAX_ARGS_PER_STEP) {
            return ParserError.TooManyArguments;
        }

        return step;
    }

    /// Parse array item (for steps)
    fn parseArrayItem(self: *WorkflowParser, map: *StringHashMap([]const u8), item: []const u8, indent: usize) !void {
        const allocator = self.allocator;
        const trimmed = std.mem.trim(u8, item, " \t");

        // Handle object array items
        if (std.mem.indexOf(u8, trimmed, ":") != null) {
            const colon_pos = std.mem.indexOf(u8, trimmed, ":").?;
            const key = trimmed[0..colon_pos];
            const value = trimmed[colon_pos + 1 ..];

            const normalized_key = std.mem.trim(u8, key, " \t");
            const normalized_value = std.mem.trim(u8, value, " \t\"'");

            try map.put(normalized_key, normalized_value);
        }
    }

    /// Parse executor configuration
    fn parseExecutorConfig(self: *WorkflowParser, config: *ExecutorConfig, config_str: []const u8) !void {
        const allocator = self.allocator;

        var lines = std.mem.tokenize(u8, config_str, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0) continue;

            if (std.mem.indexOf(u8, trimmed, ":") != null) {
                const colon_pos = std.mem.indexOf(u8, trimmed, ":").?;
                const key = trimmed[0..colon_pos];
                const value = trimmed[colon_pos + 1 ..];

                const normalized_key = std.mem.trim(u8, key, " \t");
                const normalized_value = std.mem.trim(u8, value, " \t\"'");

                if (std.mem.eql(u8, normalized_key, "max_concurrent_steps")) {
                    config.max_concurrent_steps = try parseInteger(u32, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "default_timeout_ms")) {
                    config.default_timeout_ms = try parseInteger(u64, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "max_retry_attempts")) {
                    config.max_retry_attempts = try parseInteger(u32, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "retry_initial_delay_ms")) {
                    config.retry_initial_delay_ms = try parseInteger(u64, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "retry_backoff_multiplier")) {
                    config.retry_backoff_multiplier = try std.fmt.parseFloat(f64, normalized_value) catch return ParserError.InvalidFieldType;
                } else if (std.mem.eql(u8, normalized_key, "enable_sacred_validation")) {
                    config.enable_sacred_validation = try parseBoolean(normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "sacred_threshold")) {
                    config.sacred_threshold = try std.fmt.parseFloat(f64, normalized_value) catch return ParserError.InvalidFieldType;
                } else if (std.mem.eql(u8, normalized_key, "enable_rollback")) {
                    config.enable_rollback = try parseBoolean(normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "rollback_timeout_ms")) {
                    config.rollback_timeout_ms = try parseInteger(u64, normalized_value);
                } else if (std.mem.eql(u8, normalized_key, "log_level")) {
                    if (std.mem.eql(u8, normalized_value, "debug")) {
                        config.log_level = .debug;
                    } else if (std.mem.eql(u8, normalized_value, "info")) {
                        config.log_level = .info;
                    } else if (std.mem.eql(u8, normalized_value, "warn")) {
                        config.log_level = .warn;
                    } else if (std.mem.eql(u8, normalized_value, "err")) {
                        config.log_level = .@"error";
                    }
                }
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKFLOW SERIALIZER
// ═══════════════════════════════════════════════════════════════════════════════

/// Workflow YAML serializer
pub const WorkflowSerializer = struct {
    allocator: Allocator,
    indent_size: usize = 2,

    pub fn init(allocator: Allocator) WorkflowSerializer {
        return WorkflowSerializer{
            .allocator = allocator,
        };
    }

    /// Serialize workflow to YAML string
    pub fn serializeWorkflow(self: *WorkflowSerializer, workflow: *const Workflow) ![]const u8 {
        const allocator = self.allocator;
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        // Write workflow header
        try buffer.appendSlice("workflow:\n");

        // Write basic fields
        try self.writeField(&buffer, "name", workflow.name, 1);
        if (workflow.description) |desc| {
            try self.writeField(&buffer, "description", desc, 1);
        }
        try self.writeField(&buffer, "version", workflow.version, 1);
        try self.writeField(&buffer, "strategy", @tagName(workflow.strategy), 1);
        try self.writeField(&buffer, "rollback_enabled", if (workflow.rollback_enabled) "true" else "false", 1);
        try self.writeField(&buffer, "sacred_validation", if (workflow.sacred_validation) "true" else "false", 1);

        // Write timeout
        if (workflow.timeout_ms) |timeout| {
            try buffer.appendSlice(self.indent(1));
            try buffer.appendSlice("timeout_ms: ");
            try buffer.appendSlice(std.fmt.fmtIntValue(timeout, .{}));
            try buffer.appendSlice("\n");
        }

        // Write variables
        if (workflow.variables.count() > 0) {
            try buffer.appendSlice(self.indent(1));
            try buffer.appendSlice("variables:\n");

            var var_it = workflow.variables.iterator();
            while (var_it.next()) |entry| {
                const var_name = entry.key_ptr.*;
                const var_value = entry.value_ptr.*;
                try buffer.appendSlice(self.indent(2));
                try buffer.appendSlice("- ");
                try buffer.appendSlice(var_name);
                try buffer.appendSlice("=");
                try buffer.appendSlice(var_value.value);
                try buffer.appendSlice("\n");
            }
        }

        // Write steps
        try buffer.appendSlice(self.indent(1));
        try buffer.appendSlice("steps:\n");

        for (workflow.steps.items) |step| {
            try self.writeStep(&buffer, step);
        }

        return try buffer.toOwnedSlice();
    }

    /// Write a field with proper indentation
    fn writeField(self: *WorkflowSerializer, buffer: *std.ArrayList(u8), field_name: []const u8, value: []const u8, indent: usize) !void {
        try buffer.appendSlice(self.indent(indent));
        try buffer.appendSlice(field_name);
        try buffer.appendSlice(": ");
        try buffer.appendSlice(value);
        try buffer.appendSlice("\n");
    }

    /// Write a step to YAML
    fn writeStep(self: *WorkflowSerializer, buffer: *std.ArrayList(u8), step: WorkflowStep) !void {
        try buffer.appendSlice(self.indent(2));
        try buffer.appendSlice("- id: ");
        try buffer.appendSlice(step.id);
        try buffer.appendSlice("\n");

        try buffer.appendSlice(self.indent(2));
        try buffer.appendSlice("  name: ");
        try buffer.appendSlice(step.name);
        try buffer.appendSlice("\n");

        try buffer.appendSlice(self.indent(2));
        try buffer.appendSlice("  command: ");
        try buffer.appendSlice(step.command);
        try buffer.appendSlice("\n");

        if (step.args.len > 0) {
            try buffer.appendSlice(self.indent(2));
            try buffer.appendSlice("  args:\n");
            for (step.args) |arg| {
                try buffer.appendSlice(self.indent(3));
                try buffer.appendSlice("- ");
                try buffer.appendSlice(arg);
                try buffer.appendSlice("\n");
            }
        }

        if (step.condition) |condition| {
            try buffer.appendSlice(self.indent(2));
            try buffer.appendSlice("  condition: ");
            try buffer.appendSlice(condition);
            try buffer.appendSlice("\n");
        }

        if (step.depends_on.len > 0) {
            try buffer.appendSlice(self.indent(2));
            try buffer.appendSlice("  depends_on:\n");
            for (step.depends_on) |dep| {
                try buffer.appendSlice(self.indent(3));
                try buffer.appendSlice("- ");
                try buffer.appendSlice(dep);
                try buffer.appendSlice("\n");
            }
        }

        try buffer.appendSlice(self.indent(2));
        try buffer.appendSlice("  realm: ");
        try buffer.appendSlice(@tagName(step.realm));
        try buffer.appendSlice("\n");

        if (step.timeout_ms) |timeout| {
            try buffer.appendSlice(self.indent(2));
            try buffer.appendSlice("  timeout_ms: ");
            try buffer.appendSlice(std.fmt.fmtIntValue(timeout, .{}));
            try buffer.appendSlice("\n");
        }

        try buffer.appendSlice(self.indent(2));
        try buffer.appendSlice("  continue_on_failure: ");
        try buffer.appendSlice(if (step.continue_on_failure) "true" else "false");
        try buffer.appendSlice("\n");

        if (step.description) |desc| {
            try buffer.appendSlice(self.indent(2));
            try buffer.appendSlice("  description: ");
            try buffer.appendSlice(desc);
            try buffer.appendSlice("\n");
        }
    }

    /// Generate indentation string
    fn indent(self: *WorkflowSerializer, level: usize) []const u8 {
        _ = self;
        // Use precomputed indent levels (max 8 deep) to avoid allocation
        const indents = [_][]const u8{ "", "  ", "    ", "      ", "        ", "          ", "            ", "                " };
        return if (level < indents.len) indents[level] else indents[indents.len - 1];
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Workflow parsing basic" {
    const allocator = std.testing.allocator;
    var parser = WorkflowParser.init(allocator);
    defer parser.deinit();

    const yaml_content =
        \\workflow:
        \\  name: "test_workflow"
        \\  description: "A test workflow"
        \\  version: "1.0.0"
        \\  strategy: "sequential"
        \\  rollback_enabled: false
        \\  sacred_validation: true
        \\
        \\  variables:
        \\    - name="test_var"
        \\    - count="42"
        \\
        \\  steps:
        \\    - id: "step1"
        \\      name: "First Step"
        \\      command: "echo hello"
        \\      realm: "razum"
        \\      timeout_ms: 30000
        \\
    ;

    var workflow = try parser.parseWorkflow(yaml_content);
    defer workflow.deinit();

    try std.testing.expectEqualStrings("test_workflow", workflow.name);
    try std.testing.expectEqualStrings("A test workflow", workflow.description.?);
    try std.testing.expectEqual(workflow.WorkflowStrategy.sequential, workflow.strategy);
    try std.testing.expectEqual(false, workflow.rollback_enabled);
    try std.testing.expectEqual(true, workflow.sacred_validation);
    try std.testing.expectEqual(workflow.WorkflowRealm.razum, workflow.steps.items[0].realm);
}

test "Workflow serialization" {
    const allocator = std.testing.allocator;
    var serializer = WorkflowSerializer.init(allocator);

    var workflow = Workflow.init(allocator);
    defer workflow.deinit();

    workflow.name = "test_workflow";
    workflow.description = "Test description";
    workflow.version = "1.0.0";
    workflow.strategy = .sequential;
    workflow.rollback_enabled = true;
    workflow.sacred_validation = false;

    // Add a variable
    const var_name = try allocator.dupe(u8, "test_var");
    const var_value = try allocator.dupe(u8, "test_value");
    const variable = WorkflowVariable{
        .name = var_name,
        .value = var_value,
        .type = .string,
    };
    try workflow.variables.put("test_var", variable);

    // Add a step
    const step = WorkflowStep{
        .id = "step1",
        .name = "Test Step",
        .command = "echo hello",
        .args = &[_][]const u8{ "arg1", "arg2" },
        .depends_on = &[_][]const u8{},
        .realm = .universal,
    };
    try workflow.steps.append(step);

    const yaml_content = try serializer.serializeWorkflow(&workflow);
    defer allocator.free(yaml_content);

    // Verify the serialized content contains expected fields
    try std.testing.expect(std.mem.indexOf(u8, yaml_content, "name: test_workflow") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml_content, "strategy: sequential") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml_content, "test_var=test_value") != null);
    try std.testing.expect(std.mem.indexOf(u8, yaml_content, "command: echo hello") != null);
}

test "Strategy parsing" {
    const allocator = std.testing.allocator;
    var parser = WorkflowParser.init(allocator);
    defer parser.deinit();

    // Test each strategy
    const strategies = [_][]const u8{ "sequential", "parallel", "conditional", "adaptive" };
    for (strategies) |strategy_str| {
        const result = try parser.parseStrategy(strategy_str);
        try std.testing.expectEqual(@as(usize, @intFromEnum(result)), @import("workflow.zig").WorkflowStrategy.fromInt(@intFromEnum(result)));
    }
}

test "Realm parsing" {
    const allocator = std.testing.allocator;
    var parser = WorkflowParser.init(allocator);
    defer parser.deinit();

    // Test each realm
    const realms = [_][]const u8{ "razum", "materiya", "dukh", "universal" };
    for (realms) |realm_str| {
        const result = try parser.parseRealm(realm_str);
        try std.testing.expectEqual(@as(usize, @intFromEnum(result)), @import("workflow.zig").WorkflowRealm.fromInt(@intFromEnum(result)));
    }
}

test "Boolean parsing" {
    const allocator = std.testing.allocator;
    var parser = WorkflowParser.init(allocator);
    defer parser.deinit();

    try std.testing.expect(true == try parser.parseBoolean("true"));
    try std.testing.expect(true == try parser.parseBoolean("1"));
    try std.testing.expect(false == try parser.parseBoolean("false"));
    try std.testing.expect(false == try parser.parseBoolean("0"));
}

test "Integer parsing" {
    const allocator = std.testing.allocator;
    var parser = WorkflowParser.init(allocator);
    defer parser.deinit();

    try std.testing.expect(42 == try parser.parseInteger(i32, "42"));
    try std.testing.expect(0 == try parser.parseInteger(i32, "0"));
    try std.testing.expect(-1 == try parser.parseInteger(i32, "-1"));
}
