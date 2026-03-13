// ═══════════════════════════════════════════════════════════════════════════════
// TRI WORKFLOW EXECUTOR — Variable Substitution & Execution Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// Sacred Formula: φ² + 1/φ² = 3
// Variable substitution engine ($var) and workflow execution
//
// Author: TRI ORCHESTRATOR
// Version: 1.0.0
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const StringHashMap = std.StringHashMapUnmanaged;
const regex = @import("regex");

const workflow = @import("workflow.zig");
const Workflow = workflow.Workflow;
const WorkflowStep = workflow.WorkflowStep;
const ExecutionState = workflow.ExecutionState;
const ExecutorConfig = workflow.ExecutorConfig;
const ExecutionOptions = workflow.ExecutionOptions;

// ═══════════════════════════════════════════════════════════════════════════════
// VARIABLE SUBSTITUTION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Variable substitution context
pub const VariableContext = struct {
    variables: StringHashMap([]const u8),
    workflow_vars: StringHashMap([]const u8),
    step_vars: StringHashMap([]const u8),
    environment: ?StringHashMap([]const u8),

    pub fn init(allocator: Allocator) VariableContext {
        return VariableContext{
            .variables = StringHashMap([]const u8).init(allocator),
            .workflow_vars = StringHashMap([]const u8).init(allocator),
            .step_vars = StringHashMap([]const u8).init(allocator),
            .environment = null,
        };
    }

    pub fn deinit(self: *VariableContext) void {
        var var_it = self.variables.iterator();
        while (var_it.next()) |entry| {
            self.variables.allocator.free(entry.key_ptr.*);
            self.variables.allocator.free(entry.value_ptr.*);
        }
        self.variables.deinit();

        var workflow_it = self.workflow_vars.iterator();
        while (workflow_it.next()) |entry| {
            self.workflow_vars.allocator.free(entry.key_ptr.*);
            self.workflow_vars.allocator.free(entry.value_ptr.*);
        }
        self.workflow_vars.deinit();

        var step_it = self.step_vars.iterator();
        while (step_it.next()) |entry| {
            self.step_vars.allocator.free(entry.key_ptr.*);
            self.step_vars.allocator.free(entry.value_ptr.*);
        }
        self.step_vars.deinit();

        if (self.environment) |env| {
            var env_it = env.iterator();
            while (env_it.next()) |entry| {
                env.allocator.free(entry.key_ptr.*);
                env.allocator.free(entry.value_ptr.*);
            }
            env.deinit();
        }
    }

    pub fn setVariable(self: *VariableContext, name: []const u8, value: []const u8) !void {
        try self.variables.put(name, try self.variables.allocator.dupe(u8, value));
    }

    pub fn setWorkflowVariable(self: *VariableContext, name: []const u8, value: []const u8) !void {
        try self.workflow_vars.put(name, try self.workflow_vars.allocator.dupe(u8, value));
    }

    pub fn setStepVariable(self: *VariableContext, name: []const u8, value: []const u8) !void {
        try self.step_vars.put(name, try self.step_vars.allocator.dupe(u8, value));
    }

    pub fn getVariable(self: *const VariableContext, name: []const u8) ?[]const u8 {
        // Priority: step vars > workflow vars > global vars > environment
        if (self.step_vars.get(name)) |value| return value;
        if (self.workflow_vars.get(name)) |value| return value;
        if (self.variables.get(name)) |value| return value;
        if (self.environment) |env| return env.get(name);
        return null;
    }

    pub fn hasVariable(self: *const VariableContext, name: []const u8) bool {
        return self.getVariable(name) != null;
    }
};

/// Variable substitution pattern: ${variable_name} or $variable_name
pub const VariablePattern = struct {
    full_match: []const u8,
    variable_name: []const u8,
    start_pos: usize,
    end_pos: usize,

    pub fn init(full_match: []const u8, variable_name: []const u8, start_pos: usize, end_pos: usize) VariablePattern {
        return .{
            .full_match = full_match,
            .variable_name = variable_name,
            .start_pos = start_pos,
            .end_pos = end_pos,
        };
    }
};

/// Variable substitution engine
pub const VariableSubstitutor = struct {
    allocator: Allocator,
    variable_regex: *regex.Regex,

    pub fn init(allocator: Allocator) !VariableSubstitutor {
        // Pattern: ${var} or $var, but not escaped \$var or \${var}
        const pattern = "\\$(?:\\{([^}]+)\\}|([a-zA-Z_][a-zA-Z0-9_]*))";
        const compiled_regex = try regex.Regex.compile(allocator, pattern);
        return VariableSubstitutor{
            .allocator = allocator,
            .variable_regex = compiled_regex,
        };
    }

    pub fn deinit(self: *VariableSubstitutor) void {
        self.variable_regex.deinit();
    }

    /// Find all variable patterns in text
    pub fn findVariables(self: *VariableSubstitutor, text: []const u8) !ArrayList(VariablePattern) {
        const allocator = self.allocator;
        var results = ArrayList(VariablePattern).init(allocator);

        var it = self.variable_regex.captures(text);
        while (it.next()) |captures| {
            if (captures.len >= 2) {
                // Group 1: ${var} (named capture)
                // Group 2: $var (simple capture)
                const full_match = if (captures[0]) |full| full else "";
                const var_name = if (captures[1]) |named| named else captures[2] orelse "";

                if (var_name.len > 0) {
                    const start_pos = if (captures[0]) |full| std.mem.indexOf(u8, text, full) orelse 0 else 0;
                    const end_pos = start_pos + full_match.len;

                    const pattern = VariablePattern.init(
                        try allocator.dupe(u8, full_match),
                        try allocator.dupe(u8, var_name),
                        start_pos,
                        end_pos
                    );
                    try results.append(pattern);
                }
            }
        }

        return results;
    }

    /// Substitute all variables in text with context values
    pub fn substitute(self: *VariableSubstitutor, text: []const u8, context: *const VariableContext) ![]const u8 {
        const allocator = self.allocator;
        var result = try allocator.dupe(u8, text);
        var modified = false;

        var patterns = try self.findVariables(text);
        defer {
            for (patterns.items) |pattern| {
                allocator.free(pattern.full_match);
                allocator.free(pattern.variable_name);
            }
            patterns.deinit();
        }

        // Sort patterns by position (descending) to avoid index shifting
        std.sort.backward(VariablePattern, patterns.items, {}, struct {
            fn lessThan(_: void, a: VariablePattern, b: VariablePattern) bool {
                return a.start_pos < b.start_pos;
            }
        }.lessThan);

        for (patterns.items) |pattern| {
            if (context.getVariable(pattern.variable_name)) |value| {
                // Replace the pattern with the variable value
                const before = result[0..pattern.start_pos];
                const after = result[pattern.end_pos..];

                const new_result = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
                    before, value, after
                });

                allocator.free(result);
                result = new_result;
                modified = true;
            }
        }

        return result;
    }

    /// Validate that all variables in text are defined in context
    pub fn validateVariables(self: *VariableSubstitutor, text: []const u8, context: *const VariableContext) !ArrayList([]const u8) {
        const allocator = self.allocator;
        var missing = ArrayList([]const u8).init(allocator);

        var patterns = try self.findVariables(text);
        defer {
            for (patterns.items) |pattern| {
                allocator.free(pattern.full_match);
                allocator.free(pattern.variable_name);
            }
            patterns.deinit();
        }

        var seen = StringHashMap(void).init(allocator);
        defer seen.deinit();

        for (patterns.items) |pattern| {
            if (!context.hasVariable(pattern.variable_name) and !seen.contains(pattern.variable_name)) {
                try seen.put(pattern.variable_name, {});
                try missing.append(try allocator.dupe(u8, pattern.variable_name));
            }
        }

        return missing;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKFLOW VALIDATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Workflow validation engine
pub const WorkflowValidator = struct {
    allocator: Allocator,
    substitutor: VariableSubstitutor,

    pub fn init(allocator: Allocator) !WorkflowValidator {
        var sub = try VariableSubstitutor.init(allocator);
        return WorkflowValidator{
            .allocator = allocator,
            .substitutor = sub,
        };
    }

    pub fn deinit(self: *WorkflowValidator) void {
        self.substitutor.deinit();
    }

    /// Validate workflow definition
    pub fn validateWorkflow(self: *WorkflowValidator, workflow: *const Workflow, context: *const VariableContext) !workflow.ValidationResult {
        const allocator = self.allocator;
        var result = workflow.ValidationResult.init(allocator);

        // Basic structural validation
        try self.validateWorkflowStructure(workflow, &result);

        // Variable validation
        try self.validateVariables(workflow, context, &result);

        // Step validation
        try self.validateSteps(workflow, context, &result);

        // Sacred validation
        if (workflow.sacred_validation) {
            try self.validateSacred(workflow, &result);
        }

        return result;
    }

    /// Validate workflow structure
    fn validateWorkflowStructure(self: *WorkflowValidator, workflow: *const Workflow, result: *workflow.ValidationResult) !void {
        // Check required fields
        if (workflow.name.len == 0) {
            try result.addError("name", "Workflow name is required", .error);
        }

        // Check step count limits
        if (workflow.steps.items.len > workflow.MAX_WORKFLOW_STEPS) {
            try result.addError("steps",
                std.fmt.allocPrint(self.allocator, "Maximum step count exceeded: {d} > {d}", .{
                    workflow.steps.items.len, workflow.MAX_WORKFLOW_STEPS
                }) catch "Maximum step count exceeded",
                .error
            );
        }

        // Check strategy validity
        if (@as(usize, @intFromEnum(workflow.strategy)) >= 4) {
            try result.addError("strategy", "Invalid workflow strategy", .error);
        }

        // Check timeout limits
        if (workflow.timeout_ms) |timeout| {
            if (timeout > workflow.MAX_WORKFLOW_DURATION_MS) {
                try result.addError("timeout_ms",
                    std.fmt.allocPrint(self.allocator, "Workflow timeout exceeds maximum: {d} > {d}", .{
                        timeout, workflow.MAX_WORKFLOW_DURATION_MS
                    }) catch "Workflow timeout exceeds maximum",
                    .error
                );
            }
        }
    }

    /// Validate variables in workflow
    fn validateVariables(self: *WorkflowValidator, workflow: *const Workflow, context: *const VariableContext, result: *workflow.ValidationResult) !void {
        // Check for circular references in variable definitions
        var defined_vars = StringHashMap(void).init(self.allocator);
        defer defined_vars.deinit();

        var var_it = workflow.variables.iterator();
        while (var_it.next()) |entry| {
            const var_name = entry.key_ptr.*;
            try defined_vars.put(var_name, {});

            // Check if variable value contains references to itself
            const value = entry.value_ptr.*;
            var patterns = try self.substitutor.findVariables(value);
            defer {
                for (patterns.items) |pattern| {
                    self.allocator.free(pattern.full_match);
                    self.allocator.free(pattern.variable_name);
                }
                patterns.deinit();
            }

            for (patterns.items) |pattern| {
                if (std.mem.eql(u8, pattern.variable_name, var_name)) {
                    var path_buf: [256]u8 = undefined;
                    const path = std.fmt.bufPrint(&path_buf, "variables.{s}", .{var_name}) catch "variables";
                    try result.addError(path,
                        "Circular reference in variable definition", .error);
                    break;
                }
            }
        }

        // Check variable name constraints
        var_it = workflow.variables.iterator();
        while (var_it.next()) |entry| {
            const var_name = entry.key_ptr.*;
            var vpath_buf: [256]u8 = undefined;
            if (var_name.len > workflow.MAX_VARIABLE_NAME_LENGTH) {
                const vpath = std.fmt.bufPrint(&vpath_buf, "variables.{s}.name", .{var_name}) catch "variables";
                try result.addError(vpath,
                    "Variable name too long", .error);
            }

            // Validate variable name format
            if (!isValidVariableName(var_name)) {
                const vpath = std.fmt.bufPrint(&vpath_buf, "variables.{s}.name", .{var_name}) catch "variables";
                try result.addError(vpath,
                    "Invalid variable name format", .error);
            }
        }
    }

    /// Validate workflow steps
    fn validateSteps(self: *WorkflowValidator, workflow: *const Workflow, context: *const VariableContext, result: *workflow.ValidationResult) !void {
        for (workflow.steps.items, 0..) |step, index| {
            const step_path = try std.fmt.allocPrint(self.allocator, "steps[{d}]", .{index});
            defer self.allocator.free(step_path);

            // Validate step ID uniqueness
            for (workflow.steps.items[index + 1 ..], index + 1..) |other_step, other_index| {
                if (std.mem.eql(u8, step.id, other_step.id)) {
                    const dup_path = try std.fmt.allocPrint(self.allocator, "steps[{d}].id", .{other_index});
                    defer self.allocator.free(dup_path);

                    var dup_msg_buf: [256]u8 = undefined;
                    const dup_msg = std.fmt.bufPrint(&dup_msg_buf, "Duplicate step ID: {s}", .{step.id}) catch "Duplicate step ID";
                    try result.addError(dup_path, dup_msg, .error);
                    break;
                }
            }

            // Validate step fields
            if (step.id.len == 0) {
                try result.addError(step_path ++ ".id", "Step ID is required", .error);
            }

            if (step.name.len == 0) {
                try result.addError(step_path ++ ".name", "Step name is required", .error);
            }

            if (step.command.len == 0) {
                try result.addError(step_path ++ ".command", "Step command is required", .error);
            } else if (step.command.len > workflow.MAX_COMMAND_LENGTH) {
                try result.addError(step_path ++ ".command",
                    "Step command too long", .error);
            }

            // Validate command arguments
            for (step.args, 0..) |arg, arg_index| {
                const arg_path = try std.fmt.allocPrint(self.allocator, "{s}.args[{d}]", .{step_path, arg_index});
                defer self.allocator.free(arg_path);

                if (arg.len == 0) {
                    try result.addError(arg_path, "Argument cannot be empty", .warning);
                }

                // Check for variable references in arguments
                var patterns = try self.substitutor.findVariables(arg);
                defer {
                    for (patterns.items) |pattern| {
                        self.allocator.free(pattern.full_match);
                        self.allocator.free(pattern.variable_name);
                    }
                    patterns.deinit();
                }

                for (patterns.items) |pattern| {
                    if (!context.hasVariable(pattern.variable_name)) {
                        var undef_buf: [256]u8 = undefined;
                        const undef_msg = std.fmt.bufPrint(&undef_buf, "Undefined variable: {s}", .{pattern.variable_name}) catch "Undefined variable";
                        try result.addError(arg_path, undef_msg, .error);
                    }
                }
            }

            // Validate dependencies
            for (step.depends_on) |dep| {
                var found = false;
                for (workflow.steps.items) |other_step| {
                    if (std.mem.eql(u8, dep, other_step.id)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const dep_path = try std.fmt.allocPrint(self.allocator, "{s}.depends_on", .{step_path});
                    defer self.allocator.free(dep_path);

                    var dep_msg_buf: [256]u8 = undefined;
                    const dep_msg = std.fmt.bufPrint(&dep_msg_buf, "Unknown dependency: {s}", .{dep}) catch "Unknown dependency";
                    try result.addError(dep_path, dep_msg, .error);
                }
            }

            // Validate condition
            if (step.condition) |condition| {
                // DEFERRED (v12): Implement condition syntax validation (operators, parentheses, functions)
                // Requires: expression parser, operator precedence, type checking
                const missing_vars = try self.substitutor.validateVariables(condition, context);
                defer {
                    for (missing_vars.items) |var| {
                        self.allocator.free(var);
                    }
                    missing_vars.deinit();
                }

                if (missing_vars.items.len > 0) {
                    const cond_path = try std.fmt.allocPrint(self.allocator, "{s}.condition", .{step_path});
                    defer self.allocator.free(cond_path);

                    try result.addError(cond_path,
                        std.fmt.allocPrint(self.allocator, "Undefined variables in condition: {s}", .{
                            std.mem.join(self.allocator, ", ", missing_vars.items) catch ""
                        }) catch "",
                        .error);
                }
            }

            // Validate retry policy
            if (step.retry_policy) |retry| {
                if (retry.max_attempts == 0) {
                    const retry_path = try std.fmt.allocPrint(self.allocator, "{s}.retry_policy", .{step_path});
                    defer self.allocator.free(retry_path);

                    try result.addError(retry_path, "Max retry attempts must be greater than 0", .error);
                }

                if (retry.initial_delay_ms == 0) {
                    const retry_path = try std.fmt.allocPrint(self.allocator, "{s}.retry_policy", .{step_path});
                    defer self.allocator.free(retry_path);

                    try result.addWarning(retry_path, "Initial delay is 0", "Consider setting a small delay");
                }
            }
        }
    }

    /// Validate sacred workflow properties
    fn validateSacred(self: *WorkflowValidator, workflow: *const Workflow, result: *workflow.ValidationResult) !void {
        const sacred_score = workflow.calculateSacredScore(workflow);

        if (sacred_score < workflow.SACRED_THRESHOLD) {
            try result.addError("",
                std.fmt.allocPrint(self.allocator, "Sacred score too low: {d:.3} < {d:.3}", .{
                    sacred_score, workflow.SACRED_THRESHOLD
                }) catch "",
                .warning
            );
        }

        // Verify Trinity identity
        if (!workflow.verifyTrinityIdentity()) {
            try result.addError("", "Trinity identity verification failed", .warning);
        }

        result.sacred_score = sacred_score;
    }

    /// Check if variable name is valid
    fn isValidVariableName(name: []const u8) bool {
        if (name.len == 0) return false;

        // First character must be letter or underscore
        const first_char = name[0];
        if (!(std.ascii.isAlphabetic(first_char) or first_char == '_')) {
            return false;
        }

        // Remaining characters must be alphanumeric, underscore, or hyphen
        for (name[1..]) |char| {
            if (!(std.ascii.isAlphanumeric(char) or char == '_' or char == '-')) {
                return false;
            }
        }

        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONDITION EVALUATION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Condition evaluator for workflow steps
pub const ConditionEvaluator = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) ConditionEvaluator {
        return ConditionEvaluator{
            .allocator = allocator,
        };
    }

    /// Evaluate condition expression
    pub fn evaluate(self: *ConditionEvaluator, condition: []const u8, context: *const VariableContext) !bool {
        // DEFERRED (v12): Implement full condition syntax with operators:
        // - Equality: ${var} == "value", ${var} != "value"
        // - Comparison: ${var} > 10, ${var} <= 5.5
        // - Logical: ${var1} && ${var2}, ${var1} || ${var2}, !${var}
        // - Existence: defined(${var}), undefined(${var})
        // - String matches: ${var} =~ pattern, ${var} !~ pattern
        // Requires: expression tokenizer, operator precedence, type coercion

        // For now, implement basic existence check and simple comparisons
        const substituted = try self.substituteVariables(condition, context);

        return try self.evaluateExpression(substituted);
    }

    fn substituteVariables(self: *ConditionEvaluator, condition: []const u8, context: *const VariableContext) ![]const u8 {
        // Simple substitution for now - replace ${var} with values
        var result = try self.allocator.dupe(u8, condition);

        // Handle ${variable} syntax
        var start = std.mem.indexOf(u8, result, "${");
        while (start) |s| {
            const end = std.mem.indexOf(u8, result[s+2..], "}") orelse break;
            const var_name = result[s+2 .. s+2+end];

            if (context.getVariable(var_name)) |value| {
                const before = result[0..s];
                const after = result[s+2+end+1..];
                const old_result = result;
                result = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}", .{
                    before, value, after
                });
                self.allocator.free(old_result);
                start = std.mem.indexOf(u8, result, "${");
            } else {
                // Variable not found, leave as is
                start = std.mem.indexOf(u8, result[s+2+end+1..], "${");
                if (start) |new_start| {
                    start = s + 2 + end + 1 + new_start;
                }
            }
        }

        return result;
    }

    fn evaluateExpression(self: *ConditionEvaluator, expr: []const u8) !bool {
        const trimmed = std.mem.trim(u8, expr, " \t\n\r");

        // Handle basic boolean expressions
        if (std.mem.eql(u8, trimmed, "true")) return true;
        if (std.mem.eql(u8, trimmed, "false")) return false;

        // Handle truthy/falsy values
        if (std.mem.eql(u8, trimmed, "1") or std.mem.eql(u8, trimmed, "yes")) return true;
        if (std.mem.eql(u8, trimmed, "0") or std.mem.eql(u8, trimmed, "no")) return false;

        // Handle "defined(var)" syntax
        if (std.mem.startsWith(u8, trimmed, "defined(") and std.mem.endsWith(u8, trimmed, ")")) {
            const var_name = trimmed[8 .. trimmed.len - 1];
            return var_name.len > 0;
        }

        // Handle "undefined(var)" syntax
        if (std.mem.startsWith(u8, trimmed, "undefined(") and std.mem.endsWith(u8, trimmed, ")")) {
            const var_name = trimmed[10 .. trimmed.len - 1];
            return var_name.len == 0;
        }

        // Handle != operator (check before == to avoid matching != as ==)
        if (std.mem.indexOf(u8, trimmed, "!=")) |pos| {
            const lhs = std.mem.trim(u8, trimmed[0..pos], " \t");
            const rhs = std.mem.trim(u8, trimmed[pos + 2 ..], " \t");
            const rhs_clean = stripQuotes(rhs);
            const lhs_clean = stripQuotes(lhs);
            return !std.mem.eql(u8, lhs_clean, rhs_clean);
        }

        // Handle == operator
        if (std.mem.indexOf(u8, trimmed, "==")) |pos| {
            const lhs = std.mem.trim(u8, trimmed[0..pos], " \t");
            const rhs = std.mem.trim(u8, trimmed[pos + 2 ..], " \t");
            const rhs_clean = stripQuotes(rhs);
            const lhs_clean = stripQuotes(lhs);
            return std.mem.eql(u8, lhs_clean, rhs_clean);
        }

        // Non-empty substituted value is truthy
        if (trimmed.len > 0) return true;

        return error.UnsupportedConditionSyntax;
    }

    /// Strip surrounding single or double quotes from a string
    fn stripQuotes(s: []const u8) []const u8 {
        if (s.len >= 2) {
            if ((s[0] == '\'' and s[s.len - 1] == '\'') or
                (s[0] == '"' and s[s.len - 1] == '"'))
            {
                return s[1 .. s.len - 1];
            }
        }
        return s;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "VariableContext management" {
    const allocator = std.testing.allocator;
    var context = VariableContext.init(allocator);
    defer context.deinit();

    // Test variable setting and getting
    try context.setVariable("global_var", "global_value");
    try context.setWorkflowVariable("workflow_var", "workflow_value");
    try context.setStepVariable("step_var", "step_value");

    // Test variable priority (step > workflow > global)
    try context.setVariable("conflict", "global");
    try context.setWorkflowVariable("conflict", "workflow");
    try context.setStepVariable("conflict", "step");

    try std.testing.expectEqualStrings("step", context.getVariable("conflict").?);
    try std.testing.expectEqualStrings("step_value", context.getVariable("step_var").?);
    try std.testing.expectEqualStrings("workflow_value", context.getVariable("workflow_var").?);
    try std.testing.expectEqualStrings("global_value", context.getVariable("global_var").?);
}

test "VariableSubstitutor pattern matching" {
    const allocator = std.testing.allocator;
    var substitutor = try VariableSubstitutor.init(allocator);
    defer substitutor.deinit();

    // Test pattern finding
    const text = "Hello ${name}, run $command with ${args}";
    var patterns = try substitutor.findVariables(text);
    defer {
        for (patterns.items) |pattern| {
            allocator.free(pattern.full_match);
            allocator.free(pattern.variable_name);
        }
        patterns.deinit();
    }

    try std.testing.expectEqual(@as(usize, 3), patterns.items.len);
    try std.testing.expect(std.mem.eql(u8, patterns.items[0].variable_name, "name"));
    try std.testing.expect(std.mem.eql(u8, patterns.items[1].variable_name, "command"));
    try std.testing.expect(std.mem.eql(u8, patterns.items[2].variable_name, "args"));
}

test "Variable substitution" {
    const allocator = std.testing.allocator;
    var substitutor = try VariableSubstitutor.init(allocator);
    defer substitutor.deinit();

    var context = VariableContext.init(allocator);
    defer context.deinit();

    // Set up variables
    try context.setVariable("name", "Alice");
    try context.setVariable("count", "42");
    try context.setVariable("greeting", "Hello ${name}");

    // Test substitution
    const text = "Welcome ${name}, you have ${count} messages. ${greeting}";
    const result = try substitutor.substitute(text, &context);

    try std.testing.expect(std.mem.indexOf(u8, result, "Alice") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "42") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello Alice") != null);

    allocator.free(result);
}

test "Variable validation" {
    const allocator = std.testing.allocator;
    var substitutor = try VariableSubstitutor.init(allocator);
    defer substitutor.deinit();

    var context = VariableContext.init(allocator);
    defer context.deinit();

    try context.setVariable("existing_var", "value");

    // Test valid variables
    const valid_text = "Use ${existing_var} and $existing_var";
    var missing = try substitutor.validateVariables(valid_text, &context);
    defer {
        for (missing.items) |var| {
            allocator.free(var);
        }
        missing.deinit();
    }
    try std.testing.expectEqual(@as(usize, 0), missing.items.len);

    // Test missing variables
    const invalid_text = "Use ${missing_var} and $another_var";
    missing = try substitutor.validateVariables(invalid_text, &context);
    defer {
        for (missing.items) |var| {
            allocator.free(var);
        }
        missing.deinit();
    }
    try std.testing.expectEqual(@as(usize, 2), missing.items.len);
    try std.testing.expect(std.mem.indexOf(u8, missing.items[0], "missing_var") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing.items[1], "another_var") != null);
}

test "Condition evaluator" {
    const allocator = std.testing.allocator;
    var evaluator = ConditionEvaluator.init(allocator);

    var context = VariableContext.init(allocator);
    defer context.deinit();

    try context.setVariable("status", "ready");
    try context.setVariable("count", "5");
    try context.setVariable("env", "production");

    // Test equality
    const result1 = try evaluator.evaluate("${status} == 'ready'", &context);
    try std.testing.expect(result1);

    // Test inequality (not equal)
    const result_ne = try evaluator.evaluate("${status} != 'done'", &context);
    try std.testing.expect(result_ne);

    // Test equality failure
    const result_eq_fail = try evaluator.evaluate("${status} == 'done'", &context);
    try std.testing.expect(!result_eq_fail);

    // Test inequality failure (values are equal)
    const result_ne_fail = try evaluator.evaluate("${status} != 'ready'", &context);
    try std.testing.expect(!result_ne_fail);

    // Test double-quoted strings
    const result_dq = try evaluator.evaluate("${env} == \"production\"", &context);
    try std.testing.expect(result_dq);

    // Test defined()
    const result3 = try evaluator.evaluate("defined(${status})", &context);
    try std.testing.expect(result3);

    // Test undefined()
    const result4 = try evaluator.evaluate("undefined(${missing_var})", &context);
    try std.testing.expect(result4);

    // Test boolean literals
    const result_true = try evaluator.evaluate("true", &context);
    try std.testing.expect(result_true);
    const result_false = try evaluator.evaluate("false", &context);
    try std.testing.expect(!result_false);
}

test "Workflow validation" {
    const allocator = std.testing.allocator;
    var validator = try WorkflowValidator.init(allocator);
    defer validator.deinit();

    var context = VariableContext.init(allocator);
    defer context.deinit();

    try context.setVariable("global_var", "value");

    // Create a test workflow
    var workflow = Workflow.init(allocator);
    defer workflow.deinit();

    workflow.name = "Test Workflow";
    workflow.strategy = .sequential;

    // Add a valid step
    const valid_step = WorkflowStep{
        .id = "step1",
        .name = "Test Step",
        .command = "echo ${global_var}",
        .args = &[_][]const u8{"arg1", "arg2"},
        .depends_on = &[_][]const u8{},
    };
    try workflow.steps.append(valid_step);

    // Add a step with invalid dependency
    const invalid_step = WorkflowStep{
        .id = "step2",
        .name = "Invalid Step",
        .command = "echo hello",
        .depends_on = &[_][]const u8{"nonexistent_step"},
    };
    try workflow.steps.append(invalid_step);

    // Validate workflow
    var result = try validator.validateWorkflow(&workflow, &context);
    defer result.deinit();

    // Should have errors for invalid dependency
    try std.testing.expect(!result.isValid());
    try std.testing.expect(result.errors.items.len > 0);
}