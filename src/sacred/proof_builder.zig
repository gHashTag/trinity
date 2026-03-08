// ═══════════════════════════════════════════════════════════════════════════════
// PROOF BUILDER — Build GoalState from Registry formulas
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const proof_types = @import("proof_types.zig");
const registry = @import("registry.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF BUILDER — Builds proof states from formulas
// ═══════════════════════════════════════════════════════════════════════════════

pub const ProofBuilder = struct {
    allocator: std.mem.Allocator,
    reg: *registry.Registry,

    pub fn init(allocator: std.mem.Allocator, reg: *registry.Registry) ProofBuilder {
        return .{
            .allocator = allocator,
            .reg = reg,
        };
    }

    /// Build complete GoalState for a formula
    pub fn buildGoalState(self: *const ProofBuilder, formula_id: []const u8) !proof_types.GoalState {
        const formula = self.reg.get(formula_id) orelse return error.FormulaNotFound;
        var state = proof_types.GoalState.init(self.allocator, formula_id);
        errdefer state.deinit();

        // Set final verdict based on evidence level
        state.final_verdict = formula.getVerdict();

        // Add hypothesis
        try state.addHypothesis(try std.fmt.allocPrint(self.allocator, "Formula {s} exists in registry", .{formula_id}));

        // Build definitions used
        try self.buildDefinitions(&state, formula);

        // Build expression expansion
        try self.buildExpression(&state, formula);

        // Build numeric evaluation
        try self.buildNumericEvaluation(&state, formula);

        // Build reference comparison (if applicable)
        if (formula.target_value) |_| {
            try self.buildReferenceComparison(&state, formula);
        }

        // Build invariant checks
        try self.buildInvariantChecks(&state, formula);

        // Assign verdict
        const verdict = formula.getVerdict();
        try state.addProofStep(
            .assign_verdict,
            &.{formula_id},
            null,
            try std.fmt.allocPrint(self.allocator, "Assign verdict: {s}", .{verdict.format()}),
            if (verdict == .rejected or verdict == .speculative) .failed else .passed,
        );

        return state;
    }

    fn buildDefinitions(self: *const ProofBuilder, state: *proof_types.GoalState, formula: *const registry.SacredFormula) !void {
        for (formula.depends_on_defs) |def_id| {
            try state.addProofStep(
                .load_definition,
                &.{def_id},
                def_id,
                try std.fmt.allocPrint(self.allocator, "Load definition: {s}", .{def_id}),
                .passed,
            );
        }
    }

    fn buildExpression(self: *const ProofBuilder, state: *proof_types.GoalState, formula: *const registry.SacredFormula) !void {
        const expr = try formula.formatExpression(self.allocator);
        defer self.allocator.free(expr);

        try state.addProofStep(
            .expand_expression,
            &.{formula.id},
            formula.id,
            try std.fmt.allocPrint(self.allocator, "Expand expression: {s} = {d:.6}", .{expr, formula.compute()}),
            .passed,
        );
    }

    fn buildNumericEvaluation(self: *const ProofBuilder, state: *proof_types.GoalState, formula: *const registry.SacredFormula) !void {
        const value = formula.compute();
        try state.addProofStep(
            .evaluate_numeric,
            &.{formula.id},
            null,
            try std.fmt.allocPrint(self.allocator, "Evaluate numerically: {d:.6}", .{value}),
            .passed,
        );
    }

    fn buildReferenceComparison(self: *const ProofBuilder, state: *proof_types.GoalState, formula: *const registry.SacredFormula) !void {
        const target = formula.target_value orelse return;
        const computed = formula.computed_value;
        const error_pct = formula.error_pct;

        try state.addProofStep(
            .compare_reference,
            &.{formula.id},
            null,
            try std.fmt.allocPrint(self.allocator, "Compare with reference: {d:.6} vs {d:.6} (error: {d:.4}%)", .{computed, target, error_pct}),
            if (error_pct < 1.0) .passed else .failed,
        );
    }

    fn buildInvariantChecks(self: *const ProofBuilder, state: *proof_types.GoalState, formula: *const registry.SacredFormula) !void {
        _ = formula; // Will be used for context-specific invariant checks
        // Check each built-in invariant
        inline for (std.meta.fields(proof_types.BuiltinInvariant)) |field| {
            const invariant = @field(proof_types.BuiltinInvariant, field.name);
            const status = try proof_types.ProofChecker.checkInvariant(state, invariant);

            try state.addProofStep(
                .check_invariant,
                &.{invariant.description()},
                null,
                try std.fmt.allocPrint(self.allocator, "Check invariant: {s}", .{invariant.description()}),
                status,
            );
        }
    }

    /// Format proof state for display (tri prove <id>)
    pub fn formatProofState(self: *const ProofBuilder, state: *const proof_types.GoalState, writer: anytype) !void {
        const formula = self.reg.get(state.target_formula_id) orelse return error.FormulaNotFound;
        const verdict = formula.getVerdict();

        // Header
        try writer.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
        try writer.print("{s}PROOF: {s}{s} — {s}{s}\n", .{ verdict.colorCode(), formula.name, RESET, verdict.format(), RESET });
        try writer.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ verdict.colorCode(), RESET });

        // Target info
        try writer.print("{s}Target:{s} {s}\n", .{ CYAN, RESET, state.target_formula_id});
        try writer.print("{s}Verdict:{s} {s}{s}\n\n", .{ CYAN, RESET, verdict.colorCode(), verdict.format() ++ RESET });
        try writer.print("{s}Description:{s} {s}\n\n", .{ CYAN, RESET, verdict.description() });

        // Formula expression
        const expr = try formula.formatExpression(self.allocator);
        defer self.allocator.free(expr);
        try writer.print("{s}Formula:{s} V = {s}\n", .{ GOLD, RESET, expr });
        try writer.print("{s}Computed:{s} {d:.6}\n", .{ GOLD, RESET, formula.compute() });
        if (formula.target_value) |target| {
            try writer.print("{s}Reference:{s} {d:.6} (PDG2024)\n", .{ GOLD, RESET, target});
            try writer.print("{s}Error:{s} {d:.4}%\n\n", .{ GOLD, RESET, formula.error_pct });
        } else {
            try writer.print("\n");
        }

        // Definitions used
        if (formula.depends_on_defs.len > 0) {
            try writer.print("{s}Definitions used:{s}\n", .{ GOLD, RESET });
            for (formula.depends_on_defs) |def_id| {
                try writer.print("  • {s}\n", .{def_id});
            }
            try writer.print("\n");
        }

        // Lemmas used
        if (formula.depends_on_lemmas.len > 0) {
            try writer.print("{s}Lemmas used:{s}\n", .{ GOLD, RESET });
            for (formula.depends_on_lemmas) |lemma_id| {
                try writer.print("  • {s}\n", .{lemma_id});
            }
            try writer.print("\n");
        }

        // Invariants
        try writer.print("{s}Invariants:{s}\n", .{ GOLD, RESET });
        for (state.proof_trace.items) |step| {
            if (step.kind == .check_invariant) {
                const icon = if (step.status == .passed) "✓" else "✗";
                try writer.print("  [{s}] {s}\n", .{ icon, step.summary });
            }
        }
        try writer.print("\n");

        // Proof steps
        try writer.print("{s}Proof steps:{s}\n", .{ GOLD, RESET });
        for (state.proof_trace.items, 0..) |step, i| {
            const icon = switch (step.status) {
                .passed => "✓",
                .failed => "✗",
                .pending => "○",
                .blocked => "⊘",
            };
            try writer.print("  {d}. [{s}] {s}\n", .{ i + 1, icon, step.summary });
        }

        try writer.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
    }

    /// Show unresolved goals only (tri goal <id>)
    pub fn formatUnresolvedGoals(self: *const ProofBuilder, state: *const proof_types.GoalState, writer: anytype) !void {
        const formula = self.reg.get(state.target_formula_id) orelse return error.FormulaNotFound;
        const verdict = formula.getVerdict();

        // Header
        try writer.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
        try writer.print("{s}GOAL STATE: {s}{s} — {s}{s}\n", .{ verdict.colorCode(), formula.name, RESET, verdict.format() ++ RESET });
        try writer.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ verdict.colorCode(), RESET });

        const open_goals = state.getOpenGoals();
        const failed_goals = state.getFailedGoals();

        // Overall status
        const overall_status: proof_types.GoalStatus = if (verdict == .rejected or verdict == .speculative)
            .failed
        else if (open_goals.len > 0)
            .blocked
        else
            .passed;

        try writer.print("{s}Status:{s} {s}{s}\n\n", .{ CYAN, RESET, overall_status.colorCode(), overall_status.format() ++ RESET });

        // Open goals
        if (open_goals.len > 0) {
            try writer.print("{s}Open goals:{s}\n", .{ GOLD, RESET });
            for (open_goals) |goal| {
                try writer.print("  • {s}\n", .{goal.title});
            }
            try writer.print("\n");
        }

        // Failed goals
        if (failed_goals.len > 0) {
            try writer.print("{s}Failed goals:{s}\n", .{ RED, RESET });
            for (failed_goals) |goal| {
                try writer.print("  • {s}", .{goal.title});
                if (goal.reason) |reason| {
                    try writer.print(" ({s})", .{reason});
                }
                try writer.print("\n");
            }
            try writer.print("\n");
        }

        // Blocked by
        if (overall_status == .blocked) {
            try writer.print("{s}Blocked by:{s}\n", .{ MAGENTA, RESET });
            for (state.proof_trace.items) |step| {
                if (step.status == .failed or step.status == .blocked) {
                    try writer.print("  • {s}\n", .{step.summary});
                }
            }
            try writer.print("\n");
        }

        try writer.print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
    }

    /// Draw DAG dependencies (tri trace <id>)
    pub fn formatTrace(self: *const ProofBuilder, state: *const proof_types.GoalState, writer: anytype) !void {
        const formula = self.reg.get(state.target_formula_id) orelse return error.FormulaNotFound;
        const verdict = formula.getVerdict();

        // Header
        try writer.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
        try writer.print("{s}DEPENDENCY GRAPH: {s}{s}\n", .{ verdict.colorCode(), state.target_formula_id, RESET });
        try writer.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ verdict.colorCode(), RESET });

        // Build dependency tree
        try self.printDependencyTree(writer, state.target_formula_id, "", formula, verdict);

        try writer.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
    }

    fn printDependencyTree(
        self: *const ProofBuilder,
        writer: anytype,
        node_id: []const u8,
        prefix: []const u8,
        formula: *const registry.SacredFormula,
        verdict: proof_types.ClaimVerdict,
    ) !void {
        // Print current node
        const is_last_prefix = std.mem.endsWith(u8, prefix, "└── ");
        try writer.print("{s}{s} {s} {s}{s}\n", .{ prefix, verdict.icon(), node_id, verdict.colorCode(), verdict.format() ++ RESET });

        // Collect dependencies
        var deps = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (deps.items) |dep| {
                self.allocator.free(dep);
            }
            deps.deinit();
        }

        // Add definition dependencies
        for (formula.depends_on_defs) |def_id| {
            try deps.append(try self.allocator.dupe(u8, def_id));
        }

        // Add lemma dependencies
        for (formula.depends_on_lemmas) |lemma_id| {
            try deps.append(try self.allocator.dupe(u8, lemma_id));
        }

        // Add reference dependency if validated
        if (verdict == .validated and formula.references.len > 0) {
            try deps.append(try self.allocator.dupe(u8, "PDG2024"));
        }

        // Print children
        for (deps.items, 0..) |dep, i| {
            const is_last = i == deps.items.len - 1;
            const new_prefix = if (is_last_prefix) "    " else "│   ";
            const connector = if (is_last) "└── " else "├── ";

            // Check if dependency is a formula in registry
            if (self.reg.get(dep)) |dep_formula| {
                const dep_verdict = dep_formula.getVerdict();
                try self.printDependencyTree(writer, dep, new_prefix ++ connector, dep_formula, dep_verdict);
            } else {
                // It's a definition or external reference
                const dep_verdict = if (std.mem.eql(u8, dep, "PDG2024"))
                    proof_types.ClaimVerdict.validated
                else if (std.mem.startsWith(u8, dep, "def."))
                    proof_types.ClaimVerdict.exact
                else
                    proof_types.ClaimVerdict.lattice_consistent;

                try writer.print("{s}{s} {s} {s}{s}\n", .{ new_prefix, connector, dep, dep_verdict.colorCode(), dep_verdict.format() ++ RESET });
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMAND WRAPPERS — Export for use in commands.zig
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runProveCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri math prove <formula_id>{s}\n", .{ GOLD, RESET });
        std.debug.print("\nAvailable formulas:\n", .{});
        std.debug.print("  fine_structure    alpha_s    w_mass    z_mass\n", .{});
        std.debug.print("  higgs_mass       top_mass   tau_mass\n\n", .{});
        return;
    }

    const formula_id = args[0];
    const verbose = if (args.len > 1 and std.mem.eql(u8, args[1], "--verbose")) true else false;

    // Initialize registry
    var reg = registry.Registry.init(allocator);
    defer reg.deinit();

    // Load particle physics data
    try reg.loadParticlePhysicsData();

    // Build proof state
    const builder = ProofBuilder.init(allocator, &reg);
    var state = try builder.buildGoalState(formula_id);
    defer state.deinit();

    // Get formula
    const formula = reg.get(formula_id) orelse {
        std.debug.print("{s}Error: Formula '{s}' not found in registry{s}\n", .{ RED, formula_id, RESET });
        return;
    };

    const verdict = state.final_verdict orelse .candidate;

    // ═══════════════════════════════════════════════════════════════════════════════
    // HEADER: TARGET / VERDICT
    // ═══════════════════════════════════════════════════════════════════════════════
    const verdict_color = switch (verdict) {
        .exact => GREEN,
        .validated => CYAN,
        .lattice_consistent => BLUE,
        .candidate => GOLD,
        .speculative => MAGENTA,
        .rejected => RED,
    };

    std.debug.print("\n{s}TARGET{s}   {s} ({s})\n", .{ BOLD, RESET, formula.name, formula_id });
    std.debug.print("{s}VERDICT{s}  {s}{s}{s}\n\n", .{ BOLD, RESET, verdict_color, verdict.format(), RESET });

    // ═══════════════════════════════════════════════════════════════════════════════
    // DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════════════════
    if (formula.depends_on_defs.len > 0) {
        std.debug.print("{s}DEFINITIONS{s}\n", .{ BOLD, RESET });
        for (formula.depends_on_defs) |def_id| {
            // Check if trusted
            const is_trusted = for (proof_types.trusted_definitions) |def| {
                if (std.mem.eql(u8, def.id, def_id)) break def.trusted;
            } else false;

            const status_tag = if (is_trusted) "[trusted core]" else "[candidate]";
            const status_color = if (is_trusted) GREEN else GOLD;
            std.debug.print("  • {s:<20} {s}{s}{s}\n", .{
                def_id, status_color, status_tag, RESET,
            });
        }
        std.debug.print("\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // LEMMAS (placeholder - no lemmas defined yet)
    // ═══════════════════════════════════════════════════════════════════════════════
    if (formula.depends_on_lemmas.len > 0) {
        std.debug.print("{s}LEMMAS{s}\n", .{ BOLD, RESET });
        for (formula.depends_on_lemmas) |lemma_id| {
            std.debug.print("  • {s}   [{s}symbolic{s}]\n", .{ lemma_id, CYAN, RESET });
        }
        std.debug.print("\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // INVARIANTS
    // ═══════════════════════════════════════════════════════════════════════════════
    std.debug.print("{s}INVARIANTS{s}\n", .{ BOLD, RESET });
    for (state.proof_trace.items) |step| {
        if (step.kind == .check_invariant) {
            const icon = if (step.status == .passed) "[{s}OK{s}]" else "[{s}FAIL{s}]";
            const icon_color = if (step.status == .passed) GREEN else RED;
            std.debug.print("  " ++ icon ++ " {s}\n", .{ icon_color, RESET, step.summary });
        }
    }
    std.debug.print("\n");

    // ═══════════════════════════════════════════════════════════════════════════════
    // EVIDENCE (for validated formulas)
    // ═══════════════════════════════════════════════════════════════════════════════
    if (formula.target_value != null and verdict == .validated) {
        std.debug.print("{s}EVIDENCE{s}\n", .{ BOLD, RESET });
        const target = formula.target_value.?;
        const computed = formula.computed_value;
        const error_pct = formula.error_pct;

        std.debug.print("  {s:<10} {s}\n", .{ "source", CYAN ++ "PDG2024" ++ RESET });
        std.debug.print("  {s:<10} {d:.6}\n", .{ "predicted", computed });
        std.debug.print("  {s:<10} {d:.6}\n", .{ "observed", target });
        const error_color = if (error_pct < 1.0) GREEN else if (error_pct < 5.0) GOLD else RED;
        std.debug.print("  {s:<10} {s}{d:.4} %%{s}   (threshold 1.0 %%)\n\n", .{
            "error", error_color, error_pct, RESET,
        });
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // PROOF STEPS
    // ═══════════════════════════════════════════════════════════════════════════════
    std.debug.print("{s}PROOF STEPS{s}\n", .{ BOLD, RESET });
    for (state.proof_trace.items, 0..) |step, i| {
        const icon_str = switch (step.status) {
            .passed => GREEN ++ "✓" ++ RESET,
            .failed => RED ++ "✗" ++ RESET,
            .pending => GOLD ++ "○" ++ RESET,
            .blocked => MAGENTA ++ "⊘" ++ RESET,
        };

        std.debug.print("  {d:>2} {s} {s}\n", .{ i + 1, icon_str, step.summary });

        if (verbose) {
            // Verbose mode: show step details
            std.debug.print("     {s}> inputs: {s}{s}\n", .{ DIM, step.input_ids, RESET });
        }
    }

    std.debug.print("\n", .{});
}

pub fn runGoalCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri math goal <formula_id>{s}\n", .{ GOLD, RESET });
        std.debug.print("\nExample:\n", .{});
        std.debug.print("  tri math goal alpha_s\n", .{});
        return;
    }

    const formula_id = args[0];

    // Initialize registry
    var reg = registry.Registry.init(allocator);
    defer reg.deinit();

    // Load particle physics data
    try reg.loadParticlePhysicsData();

    // Build proof state
    const builder = ProofBuilder.init(allocator, &reg);
    var state = try builder.buildGoalState(formula_id);
    defer state.deinit();

    // Get formula
    const formula = reg.get(formula_id) orelse {
        std.debug.print("{s}Error: Formula '{s}' not found in registry{s}\n", .{ RED, formula_id, RESET });
        return;
    };

    const verdict = state.final_verdict orelse .candidate;

    // ═══════════════════════════════════════════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════════════════════════════════════════
    const verdict_color = switch (verdict) {
        .exact => GREEN,
        .validated => CYAN,
        .lattice_consistent => BLUE,
        .candidate => GOLD,
        .speculative => MAGENTA,
        .rejected => RED,
    };

    // Determine overall status
    const open_goals = state.getOpenGoals();
    const failed_goals = state.getFailedGoals();
    const overall_status: proof_types.GoalStatus = if (failed_goals.len > 0)
        .failed
    else if (open_goals.len > 0)
        .blocked
    else
        .passed;

    const status_color = switch (overall_status) {
        .passed => GREEN,
        .failed => RED,
        .blocked => GOLD,
        .pending => GRAY,
    };

    std.debug.print("\n{s}TARGET{s}   {s} ({s})\n", .{ BOLD, RESET, formula.name, formula_id });
    std.debug.print("{s}STATUS{s}   {s}{s}{s}\n", .{ BOLD, RESET, status_color, @tagName(overall_status), RESET });
    std.debug.print("{s}VERDICT{s}  {s}{s}{s}\n\n", .{ BOLD, RESET, verdict_color, verdict.format(), RESET });

    // ═══════════════════════════════════════════════════════════════════════════════
    // OPEN GOALS
    // ═══════════════════════════════════════════════════════════════════════════════
    if (open_goals.len > 0) {
        std.debug.print("{s}OPEN GOALS{s}\n", .{ BOLD, RESET });
        for (open_goals) |goal| {
            std.debug.print("  [ ] {s}\n", .{goal.title});
            // Show reason if available
            if (goal.reason) |reason| {
                std.debug.print("     {s}{s}{s}\n", .{ DIM, reason, RESET });
            }
        }
        std.debug.print("\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FAILED GOALS
    // ═══════════════════════════════════════════════════════════════════════════════
    if (failed_goals.len > 0) {
        std.debug.print("{s}FAILED GOALS{s}\n", .{ RED, RESET });
        for (failed_goals) |goal| {
            std.debug.print("  [x] {s}\n", .{goal.title});
            if (goal.reason) |reason| {
                std.debug.print("     {s}{s}{s}\n", .{ DIM, reason, RESET });
            }
        }
        std.debug.print("\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // BLOCKERS
    // ═══════════════════════════════════════════════════════════════════════════════
    if (overall_status == .blocked) {
        std.debug.print("{s}BLOCKERS{s}\n", .{ MAGENTA, RESET });
        for (state.proof_trace.items) |step| {
            if (step.status == .failed or step.status == .blocked) {
                std.debug.print("  • {s}\n", .{step.summary});
            }
        }
        std.debug.print("\n", .{});
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // HINT (for candidate/speculative formulas)
    // ═══════════════════════════════════════════════════════════════════════════════
    if (verdict == .candidate or verdict == .speculative) {
        std.debug.print("{s}HINT{s}\n", .{ DIM, RESET });
        std.debug.print("  Consider adding more lemmas or experimental data\n", .{});
        std.debug.print("  to upgrade evidence level from {s}{s}{s}\n\n", .{ GOLD, @tagName(verdict), RESET });
    }

    std.debug.print("{s}════════════════════════════════════════{s}\n", .{ DIM, RESET });
    std.debug.print("\n", .{});
}

pub fn runTraceCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri math trace <formula_id>{s}\n", .{ GOLD, RESET });
        std.debug.print("\nExample:\n", .{});
        std.debug.print("  tri math trace alpha_s\n", .{});
        return;
    }

    const formula_id = args[0];

    // Initialize registry
    var reg = registry.Registry.init(allocator);
    defer reg.deinit();

    // Load particle physics data
    try reg.loadParticlePhysicsData();

    // Build proof state
    const builder = ProofBuilder.init(allocator, &reg);
    var state = try builder.buildGoalState(formula_id);
    defer state.deinit();

    // Get formula
    const formula = reg.get(formula_id) orelse {
        std.debug.print("{s}Error: Formula '{s}' not found in registry{s}\n", .{ RED, formula_id, RESET });
        return;
    };

    const verdict = state.final_verdict orelse .candidate;
    const verdict_color = switch (verdict) {
        .exact => GREEN,
        .validated => CYAN,
        .lattice_consistent => BLUE,
        .candidate => GOLD,
        .speculative => MAGENTA,
        .rejected => RED,
    };

    // ═══════════════════════════════════════════════════════════════════════════════
    // DEPENDENCY DAG
    // ═══════════════════════════════════════════════════════════════════════════════
    std.debug.print("\n{s}{s} ({s}){s}\n", .{ BOLD, formula.name, formula_id, RESET });
    std.debug.print("└─ ", .{});

    // Print definition dependencies
    for (formula.depends_on_defs, 0..) |def_id, i| {
        if (i > 0) std.debug.print("   ", .{});

        // Check if trusted
        const is_trusted = for (proof_types.trusted_definitions) |def| {
            if (std.mem.eql(u8, def.id, def_id)) break def.trusted;
        } else false;

        const status_tag = if (is_trusted) "definition, trusted core" else "definition, candidate";
        const status_color = if (is_trusted) GREEN else GOLD;

        // Get line connector
        const is_last = i == formula.depends_on_defs.len - 1 and formula.depends_on_lemmas.len == 0;
        const connector = if (is_last) "└─ " else "├─ ";

        std.debug.print("{s}{s}{s}   [{s}{s}]\n", .{
            connector, def_id, RESET, status_color, status_tag,
        });
    }

    // Print lemma dependencies
    for (formula.depends_on_lemmas, 0..) |lemma_id, i| {
        if (formula.depends_on_defs.len > 0 or i > 0) {
            std.debug.print("   ", .{});
        }

        const is_last = i == formula.depends_on_lemmas.len - 1;
        const connector = if (is_last) "└─ " else "├─ ";

        std.debug.print("{s}{s}{s}   [{s}lemma, {s}validated{s}]\n", .{
            connector, lemma_id, RESET, CYAN, CYAN, RESET,
        });
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // INVARIANTS STATUS
    // ═══════════════════════════════════════════════════════════════════════════════
    var invariants_passed: usize = 0;
    var invariants_total: usize = 0;

    for (state.proof_trace.items) |step| {
        if (step.kind == .check_invariant) {
            invariants_total += 1;
            if (step.status == .passed) invariants_passed += 1;
        }
    }

    if (invariants_total > 0) {
        std.debug.print("\n", .{});
        for (state.proof_trace.items) |step| {
            if (step.kind == .check_invariant) {
                const icon = if (step.status == .passed) "✓" else "✗";
                const icon_color = if (step.status == .passed) GREEN else RED;
                std.debug.print("   {s}{s} {s}{s}\n", .{ icon_color, icon, RESET, step.summary });
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FOOTER
    // ═══════════════════════════════════════════════════════════════════════════════
    std.debug.print("\n{s}════════════════════════════════════════{s}\n", .{ DIM, RESET });
    std.debug.print("Verdict: {s}{s}{s} | ", .{ verdict_color, verdict.format(), RESET });
    std.debug.print("Proof steps: {d} | ", .{state.proof_trace.items.len});
    std.debug.print("Invariants: {d}/{d} passed\n\n", .{ invariants_passed, invariants_total });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS — ANSI color codes for terminal output
// ═══════════════════════════════════════════════════════════════════════════════

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

// Colors
const BLACK = "\x1b[30m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const GOLD = "\x1b[33m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const WHITE = "\x1b[37m";
const GRAY = "\x1b[90m";
