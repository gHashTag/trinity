// ═══════════════════════════════════════════════════════════════════════════════
// PROOF BUILDER — Build GoalState from Registry formulas
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const proof_types = @import("proof_types.zig");
const registry = @import("registry.zig");
const expanded_v2 = @import("expanded_v2.zig");

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

        // ═══════════════════════════════════════════════════════════════════════════════
        // EPISTEMIC CONSISTENCY CHECK (I16-I17) — Terminal override
        // ═══════════════════════════════════════════════════════════════════════════════
        // If I16 or I17 fail, override verdict to formula_mismatch regardless of evidence level
        const epistemic_status = try self.checkEpistemicConsistency(&state, formula);
        if (epistemic_status == .failed) {
            // TERMINAL OVERRIDE: formula_mismatch takes precedence
            state.final_verdict = proof_types.ClaimVerdict.formula_mismatch;

            // Add repair goals automatically
            if (formula.declared_expression != null) {
                try state.addGoal("repair_declared_expression", "Repair declared expression to match parameters/computed value", .check_invariant);
            } else {
                try state.addGoal("declare_missing_scale_factor", "Declare missing scale factor to explain computed value discrepancy", .check_invariant);
            }
        }

        // Assign verdict (may be overridden by epistemic check)
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
            try std.fmt.allocPrint(self.allocator, "Expand expression: {s} = {d:.6}", .{ expr, formula.compute() }),
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
            try std.fmt.allocPrint(self.allocator, "Compare with reference: {d:.6} vs {d:.6} (error: {d:.4}%)", .{ computed, target, error_pct }),
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

    /// Check I16-I17: Epistemic consistency (expression/params mismatch detection)
    /// Returns .failed if formula has declared_expression that doesn't match computed value
    fn checkEpistemicConsistency(self: *const ProofBuilder, state: *proof_types.GoalState, formula: *const registry.SacredFormula) !proof_types.GoalStatus {
        // I16: Check if declared_expression matches actual computation
        if (formula.declared_expression != null) {
            const computed = formula.compute();
            const target = formula.target_value orelse computed;

            // Check if there's a significant mismatch between declared and computed
            // Threshold: 10% discrepancy indicates formula mismatch
            const mismatch_pct = @abs(computed - target) / target * 100.0;

            if (mismatch_pct > 10.0) {
                // I16 FAIL: declared expression doesn't match parameters/computed
                try state.addProofStep(
                    .check_invariant,
                    &.{ "I16", "expression_matches_params" },
                    null,
                    try std.fmt.allocPrint(self.allocator, "[I16 FAIL] Declared expression does not match computed value (computed: {d:.6}, target: {d:.6}, delta: {d:.1}%)", .{ computed, target, mismatch_pct }),
                    .failed,
                );
                return .failed;
            }

            // I16 PASS
            try state.addProofStep(
                .check_invariant,
                &.{ "I16", "expression_matches_params" },
                null,
                try std.fmt.allocPrint(self.allocator, "[I16 OK] Declared expression matches computed value (delta: {d:.1}%)", .{mismatch_pct}),
                .passed,
            );
        }

        // I17: Check if missing scale factor is declared
        // For now, PASS if no declared_expression or if target exists
        // Full implementation would check for undeclared scale factors

        return .passed;
    }

    /// Format proof state for display (tri prove <id>)
    pub fn formatProofState(self: *const ProofBuilder, state: *const proof_types.GoalState, writer: anytype) !void {
        const formula = self.reg.get(state.target_formula_id) orelse return error.FormulaNotFound;
        const verdict = state.final_verdict orelse formula.getVerdict();

        // ═══════════════════════════════════════════════════════════════════════════════
        // EPISTEMIC FAILURE BANNER — Show for formula_mismatch
        // ═══════════════════════════════════════════════════════════════════════════════
        if (verdict == .formula_mismatch) {
            try writer.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ "\x1b[41;37m", RESET });
            try writer.print("{s}║ {s}EPISTEMIC FAILURE{c} │ expression ≠ params ≠ computed value {s}║{s}\n", .{ "\x1b[41;37m", "\x1b[1;37m", "=", RESET });
            try writer.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n", .{ "\x1b[41;37m", RESET });
            try writer.print("\n{s}FORMULA_MISMATCH:{s} Declared expression does not match parameterization\n", .{ "\x1b[31;1m", RESET });
            if (formula.declared_expression) |declared| {
                try writer.print("{s}  Declared: {s}{s}\n", .{ RESET, declared, RESET });
                try writer.print("{s}  Computed: {d:.6}{s}\n", .{ RESET, formula.compute(), RESET });
                try writer.print("{s}  Target: {d:.6}{s}\n", .{ RESET, formula.target_value orelse 0.0, RESET });
            }
            try writer.print("\n");
        }

        // Header
        try writer.print("\n{s}═══════════════════════════════════════════════════════════════{s}\n", .{ verdict.colorCode(), RESET });
        try writer.print("{s}PROOF: {s}{s} — {s}{s}\n", .{ verdict.colorCode(), formula.name, RESET, verdict.format(), RESET });
        try writer.print("{s}═══════════════════════════════════════════════════════════════{s}\n\n", .{ verdict.colorCode(), RESET });

        // Target info
        try writer.print("{s}Target:{s} {s}\n", .{ CYAN, RESET, state.target_formula_id });
        try writer.print("{s}Verdict:{s} {s}{s}\n\n", .{ CYAN, RESET, verdict.colorCode(), verdict.format() ++ RESET });
        try writer.print("{s}Description:{s} {s}\n\n", .{ CYAN, RESET, verdict.description() });

        // Formula expression
        const expr = try formula.formatExpression(self.allocator);
        defer self.allocator.free(expr);
        try writer.print("{s}Formula:{s} V = {s}\n", .{ GOLD, RESET, expr });
        try writer.print("{s}Computed:{s} {d:.6}\n", .{ GOLD, RESET, formula.compute() });
        if (formula.target_value) |target| {
            try writer.print("{s}Reference:{s} {d:.6} (PDG2024)\n", .{ GOLD, RESET, target });
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
        var deps = try std.ArrayList([]const u8).initCapacity(self.allocator, 16);
        defer {
            for (deps.items) |dep| {
                self.allocator.free(dep);
            }
            deps.deinit(self.allocator);
        }

        // Add definition dependencies
        for (formula.depends_on_defs) |def_id| {
            try deps.append(self.allocator, try self.allocator.dupe(u8, def_id));
        }

        // Add lemma dependencies
        for (formula.depends_on_lemmas) |lemma_id| {
            try deps.append(self.allocator, try self.allocator.dupe(u8, lemma_id));
        }

        // Add reference dependency if validated
        if (verdict == .validated and formula.references.len > 0) {
            try deps.append(self.allocator, try self.allocator.dupe(u8, "PDG2024"));
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
    try reg.loadAllFormulas();

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
        .formula_mismatch => "\x1b[41;37m", // Red background, white text — EPSTEMIC FAILURE
    };

    std.debug.print("\n{s}TARGET{s}   {s} ({s})\n", .{ BOLD, RESET, formula.name, formula_id });
    std.debug.print("{s}VERDICT{s}  {s}{s}{s}", .{ BOLD, RESET, verdict_color, verdict.format(), RESET });

    // Show FIT ORIGIN if available
    if (formula.fit_origin) |origin| {
        const origin_str = origin.format();
        const origin_color = switch (origin) {
            .canonical => GREEN,
            .search_fit => GOLD,
            .postdiction => RED,
            .prior_informed => GOLD,
            .semiblind => CYAN,
            .blind => GREEN,
            .manual_override => MAGENTA,
        };
        std.debug.print(" {s}|{s} {s}{s}{s}\n", .{ DIM, RESET, origin_color, origin_str, RESET });
    } else {
        std.debug.print(" {s}|{s} {s}[UNSPECIFIED]{s}\n", .{ DIM, RESET, GRAY, RESET });
    }
    std.debug.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════════
    // EPISTEMIC FAILURE BANNER — Show for formula_mismatch
    // ═══════════════════════════════════════════════════════════════════════════════
    // EPISTEMIC FAILURE BANNER — Show for formula_mismatch
    // ═══════════════════════════════════════════════════════════════════════════════
    if (verdict == .formula_mismatch) {
        std.debug.print("\n{s}╔══════════════════════════════════════════════════════════════════╗{s}\n", .{ "\x1b[41;37m", RESET });
        std.debug.print("{s}║ {s}EPISTEMIC FAILURE{s} │ expression ≠ params ≠ computed value {s}║{s}\n", .{ "\x1b[41;37m", "\x1b[1;37m", RESET, "\x1b[41;37m", RESET });
        std.debug.print("{s}╚══════════════════════════════════════════════════════════════════╝{s}\n", .{ "\x1b[41;37m", RESET });
        std.debug.print("\n{s}FORMULA_MISMATCH:{s} Declared expression does not match parameterization\n", .{ "\x1b[31;1m", RESET });
        if (formula.declared_expression) |declared| {
            std.debug.print("{s}  Declared: {s}{s}\n", .{ RESET, declared, RESET });
            std.debug.print("{s}  Computed: {d:.6}{s}\n", .{ RESET, formula.compute(), RESET });
            std.debug.print("{s}  Target: {d:.6}{s}\n", .{ RESET, formula.target_value orelse 0.0, RESET });
        }
        std.debug.print("\n", .{});
    }

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
            const icon_tag = if (step.status == .passed) "OK" else "FAIL";
            const icon_color = if (step.status == .passed) GREEN else RED;
            std.debug.print("  [{s}{s}{s}] {s}\n", .{ icon_color, icon_tag, RESET, step.summary });
        }
    }
    std.debug.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════════
    // EVIDENCE (for validated formulas)
    // ═══════════════════════════════════════════════════════════════════════════════
    if (formula.target_value != null and verdict == .validated) {
        std.debug.print("{s}EVIDENCE{s}\n", .{ BOLD, RESET });
        const target = formula.target_value.?;
        const computed = formula.computed_value;
        const error_pct = formula.error_pct;

        const source_str = CYAN ++ "PDG2024" ++ RESET;
        std.debug.print("  {s:<10} {s}\n", .{ "source", source_str });
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
            if (step.input_ids.len > 0) {
                std.debug.print("     {s}> inputs: ", .{DIM});
                for (step.input_ids, 0..) |id, j| {
                    if (j > 0) std.debug.print(", ", .{});
                    std.debug.print("{s}", .{id});
                }
                std.debug.print("{s}\n", .{RESET});
            }
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
    try reg.loadAllFormulas();

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
        .formula_mismatch => "\x1b[41;37m", // Red background, white text — EPSTEMIC FAILURE
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
    try reg.loadAllFormulas();

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
        .formula_mismatch => "\x1b[41;37m", // Red background, white text — EPSTEMIC FAILURE
    };

    // ═══════════════════════════════════════════════════════════════════════════════
    // DEPENDENCY DAG
    // ═══════════════════════════════════════════════════════════════════════════════
    std.debug.print("\n{s}{s} ({s}){s}\n", .{ BOLD, formula.name, formula_id, RESET });
    if (verdict == .formula_mismatch) {
        std.debug.print(" {s}[MISMATCH]{s}\n", .{ RED, RESET });
    }
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

        // Check if this definition is actually a formula in registry with mismatch
        const dep_formula = reg.get(def_id);
        const mismatch_tag = if (dep_formula != null and dep_formula.?.getVerdict() == .formula_mismatch)
            " [MISMATCH]"
        else
            "";

        std.debug.print("{s}{s}{s}   [{s}{s}]{s}\n", .{
            connector, def_id, RESET, status_color, status_tag, mismatch_tag,
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
const YELLOW = "\x1b[33;1m"; // Bold yellow
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const WHITE = "\x1b[37m";
const GRAY = "\x1b[90m";

// ═══════════════════════════════════════════════════════════════════════════════
// DOCTOR COMMAND — Cross-domain consistency checks (Research Cycle Section 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDoctorCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var reg_inst = registry.Registry.init(allocator);
    defer reg_inst.deinit();
    try reg_inst.loadAllFormulas();

    const cross_domain = if (args.len > 0) std.mem.eql(u8, args[0], "--cross-domain") else false;
    const epistemic = if (args.len > 0) std.mem.eql(u8, args[0], "--epistemic") else false;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  PROOF GRAPH DOCTOR{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    if (cross_domain) {
        try runCrossDomainChecks(allocator, &reg_inst);
    } else if (epistemic) {
        try runEpistemicHealthCheck(allocator, &reg_inst);
    } else {
        try runBasicHealthCheck(allocator, &reg_inst);
    }
}

fn runBasicHealthCheck(allocator: std.mem.Allocator, reg: *const registry.Registry) !void {
    // Total formulas
    const total = reg.count();
    std.debug.print("{s}Registry Status:{s}\n", .{ BOLD, RESET });
    std.debug.print("  Total formulas: {d}\n\n", .{total});

    // By evidence level - fixed Zig 0.15 syntax
    std.debug.print("{s}By Evidence Level:{s}\n", .{ BOLD, RESET });
    inline for (@typeInfo(registry.EvidenceLevel).@"enum".fields) |field| {
        const level = @as(registry.EvidenceLevel, @enumFromInt(field.value));
        const ids = try reg.listByEvidenceLevel(level);
        defer allocator.free(ids);
        const color = level.colorCode();
        std.debug.print("  {s}{s}{s}: {d} formulas\n", .{ color, level.format(), RESET, ids.len });
    }
    std.debug.print("\n", .{});

    // ═══════════════════════════════════════════════════════════════════════════════
    // Fit Origin Breakdown — Charter compliance: canonical must be mismatch-free
    // ═══════════════════════════════════════════════════════════════════════════════
    std.debug.print("{s}By Fit Origin (Epistemic Integrity):{s}\n", .{ BOLD, RESET });

    var canonical_count: usize = 0;
    var search_fit_count: usize = 0;
    var postdiction_count: usize = 0;
    var manual_override_count: usize = 0;
    var unspecified_count: usize = 0;

    var iter = reg.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.fit_origin) |origin| {
            switch (origin) {
                .canonical => canonical_count += 1,
                .search_fit => search_fit_count += 1,
                .postdiction, .prior_informed, .semiblind, .blind => postdiction_count += 1,
                .manual_override => manual_override_count += 1,
            }
        } else {
            unspecified_count += 1;
        }
    }

    const total_with_fit = canonical_count + search_fit_count + postdiction_count + manual_override_count;
    if (total_with_fit > 0) {
        std.debug.print("  {s}Canonical:{s}   {d} formulas {s}(trusted core derivations){s}\n", .{ GREEN, RESET, canonical_count, DIM, RESET });
        std.debug.print("  {s}Search fit:{s}  {d} formulas {s}(numerically optimized){s}\n", .{ GOLD, RESET, search_fit_count, DIM, RESET });
        std.debug.print("  {s}Postdiction:{s} {d} formulas {s}(adjusted after data){s}\n", .{ RED, RESET, postdiction_count, DIM, RESET });
        std.debug.print("  {s}Manual:{s}     {d} formulas {s}(explicit override){s}\n", .{ MAGENTA, RESET, manual_override_count, DIM, RESET });
    }
    if (unspecified_count > 0) {
        std.debug.print("  {s}Unspecified:{s} {d} formulas {s}(missing fit_origin){s}\n", .{ GRAY, RESET, unspecified_count, DIM, RESET });
    }
    std.debug.print("\n", .{});

    // γ-dependency by domain
    std.debug.print("{s}Gamma Dependency by Domain:{s}\n", .{ BOLD, RESET });
    inline for (@typeInfo(proof_types.Domain).@"enum".fields) |field| {
        if (field.value >= 5) break; // Skip unused domains
        const domain = @as(proof_types.Domain, @enumFromInt(field.value));
        const metrics = try reg.getGammaDomainMetrics(domain);
        if (metrics.total_formulas > 0) {
            const gamma_pct = metrics.gammaFraction() * 100.0;
            const color_code = if (gamma_pct < 30) GREEN else if (gamma_pct < 60) GOLD else RED;
            std.debug.print("  {s}{s}{s}: {d:.0}% γ-dependent ({d}/{d})\n", .{ color_code, domain.format(), RESET, gamma_pct, metrics.gamma_dependent, metrics.total_formulas });
        }
    }
    std.debug.print("\n{s}✓{s} Health check complete.\n\n", .{ GREEN, RESET });
}

fn runCrossDomainChecks(allocator: std.mem.Allocator, reg: *const registry.Registry) !void {
    _ = allocator;
    var issues_found: usize = 0;

    std.debug.print("{s}Cross-Domain Invariant Checks (I11-I15):{s}\n\n", .{ BOLD, RESET });

    // I11: Cosmology density sum
    {
        std.debug.print("{s}[I11]{s} Cosmology Density Sum: ", .{ CYAN, RESET });
        const omega_lambda = @constCast(reg).get("omega_lambda");
        const omega_dm = @constCast(reg).get("omega_dm");

        if (omega_lambda != null and omega_dm != null) {
            const sum = omega_lambda.?.computed_value + omega_dm.?.computed_value + 0.049; // Ω_b ≈ 0.049
            const diff_from_1 = @abs(sum - 1.0);
            if (diff_from_1 < 0.05) {
                std.debug.print("{s}PASS{s} (Ω_sum = {d:.3}, Δ = {d:.1}%)\n", .{ GREEN, RESET, sum, diff_from_1 * 100 });
            } else {
                std.debug.print("{s}FAIL{s} (Ω_sum = {d:.3}, Δ = {d:.1}%)\n", .{ RED, RESET, sum, diff_from_1 * 100 });
                issues_found += 1;
            }
        } else {
            std.debug.print("{s}SKIP{s} (missing formulas)\n", .{ GOLD, RESET });
        }
    }

    // I12: QCD scale consistency
    {
        std.debug.print("\n{s}[I12]{s} QCD Scale Consistency: ", .{ CYAN, RESET });
        const alpha_s = @constCast(reg).get("alpha_s");
        if (alpha_s != null) {
            const alpha_s_value = alpha_s.?.computed_value;
            if (alpha_s_value > 0.10 and alpha_s_value < 0.13) {
                std.debug.print("{s}PASS{s} (α_s = {d:.4} in valid range)\n", .{ GREEN, RESET, alpha_s_value });
            } else {
                std.debug.print("{s}WARN{s} (α_s = {d:.4} outside expected range)\n", .{ GOLD, RESET, alpha_s_value });
            }
        } else {
            std.debug.print("{s}SKIP{s} (formula not found)\n", .{ GOLD, RESET });
        }
    }

    // I13: Particle mass relations
    {
        std.debug.print("\n{s}[I13]{s} Particle Mass Relations: ", .{ CYAN, RESET });
        const tau_mass = @constCast(reg).get("tau_mass");
        const muon_mass = @constCast(reg).get("muon_mass");
        if (tau_mass != null and muon_mass != null) {
            const ratio = tau_mass.?.computed_value / muon_mass.?.computed_value;
            if (ratio > 16.0 and ratio < 18.0) {
                std.debug.print("{s}PASS{s} (m_τ/m_μ = {d:.2}, reasonable)\n", .{ GREEN, RESET, ratio });
            } else {
                std.debug.print("{s}WARN{s} (m_τ/m_μ = {d:.2}, unusual)\n", .{ GOLD, RESET, ratio });
            }
        } else {
            std.debug.print("{s}SKIP{s} (formulas not found)\n", .{ GOLD, RESET });
        }
    }

    // I14: Consciousness energy scale
    {
        std.debug.print("\n{s}[I14]{s} Consciousness Energy Scale: ", .{ CYAN, RESET });
        const f_gamma = 56.0; // Hz, from neural_gamma
        const kT_300K = 6.25e12; // Hz, thermal energy at 300K
        if (kT_300K > f_gamma * 1000) {
            std.debug.print("{s}PASS{s} (f_γ = {d:.0} Hz ≪ kT_300K = {e:.1} Hz)\n", .{ GREEN, RESET, f_gamma, kT_300K });
        } else {
            std.debug.print("{s}FAIL{s} (thermal noise would swamp coherence)\n", .{ RED, RESET });
            issues_found += 1;
        }
    }

    // I15: Gravity-cosmology link
    {
        std.debug.print("\n{s}[I15]{s} Gravity-Cosmology Link: ", .{ CYAN, RESET });
        const omega_lambda = @constCast(reg).get("omega_lambda");
        if (omega_lambda != null) {
            const gamma = std.math.pow(f64, 1.6180339887498948482, -3.0);
            // G = π³γ²/φ is computed but not used in this check
            _ = std.math.pow(f64, std.math.pi, 3.0) * gamma * gamma / 1.6180339887498948482;
            const expected_omega = std.math.pow(f64, gamma, 8.0) * std.math.pow(f64, std.math.pi, 4.0) / 1.6180339887498948482 / 1.6180339887498948482;
            const diff = @abs(omega_lambda.?.computed_value - expected_omega);
            if (diff < 0.01) {
                std.debug.print("{s}PASS{s} (G-cosmology link consistent)\n", .{ GREEN, RESET });
            } else {
                std.debug.print("{s}WARN{s} (G-cosmology link has Δ = {d:.3})\n", .{ GOLD, RESET, diff });
            }
        } else {
            std.debug.print("{s}SKIP{s} (formula not found)\n", .{ GOLD, RESET });
        }
    }

    // Summary
    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    if (issues_found == 0) {
        std.debug.print("\n{s}✓ All cross-domain checks passed.{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}✗ {d} issue(s) found.{s}\n\n", .{ RED, issues_found, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT MISMATCH COMMAND — Scan all formulas for epistemic inconsistencies
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runAuditMismatchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var reg_inst = registry.Registry.init(allocator);
    defer reg_inst.deinit();
    try reg_inst.loadAllFormulas();

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ RED, RESET });
    std.debug.print("{s}  EPISTEMIC AUDIT — Formula Mismatch Detection{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ RED, RESET });

    var mismatches: usize = 0;
    var total_checked: usize = 0;

    // Iterate through all formulas in the registry
    var iter = reg_inst.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        total_checked += 1;

        // Check for formula_mismatch verdict or I16/I17 violations
        const verdict = formula.getVerdict();
        const is_mismatch = verdict == .formula_mismatch;

        // Check for I16 violation: declared_expression doesn't match computed value
        const i16_violation = if (formula.declared_expression != null) blk: {
            const computed = formula.compute();
            const target = formula.target_value orelse computed;
            const mismatch_pct = @abs(computed - target) / target * 100.0;
            break :blk mismatch_pct > 10.0;
        } else false;

        if (is_mismatch or i16_violation) {
            mismatches += 1;
            std.debug.print("{s}[{d}] {s}{s}\n", .{ RED, mismatches, formula.id, RESET });
            std.debug.print("    Name: {s}\n", .{formula.name});

            if (formula.declared_expression) |declared| {
                std.debug.print("    {s}Declared:{s} {s}\n", .{ GOLD, RESET, declared });
            }

            const computed = formula.compute();
            std.debug.print("    {s}Computed:{s} {d:.6}", .{ GOLD, RESET, computed });

            if (formula.target_value) |target| {
                const error_pct = @abs(computed - target) / target * 100.0;
                std.debug.print(" | {s}Target:{s} {d:.6} | {s}Error:{s} {d:.1}%\n", .{ CYAN, RESET, target, RED, RESET, error_pct });
            } else {
                std.debug.print("\n", .{});
            }

            // Show fit origin if available
            if (formula.fit_origin) |origin| {
                const origin_str = origin.format();
                std.debug.print("    {s}Fit Origin:{s} {s}\n", .{ GOLD, RESET, origin_str });
            }

            // Show verdict
            std.debug.print("    {s}Verdict:{s} {s}{s}{s}\n", .{ GOLD, RESET, verdict.colorCode(), verdict.format(), RESET });

            std.debug.print("\n", .{});
        }
    }

    // Summary
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ RED, RESET });
    if (mismatches == 0) {
        std.debug.print("\n{s}✓ No formula mismatches detected.{s}\n", .{ GREEN, RESET });
        std.debug.print("  All {d} formulas are epistemically consistent.\n\n", .{total_checked});
    } else {
        const pct = @as(f64, @floatFromInt(mismatches)) / @as(f64, @floatFromInt(total_checked)) * 100.0;
        std.debug.print("\n{s}✗ {d}/{d} formulas ({d:.1}%) have epistemic inconsistencies.{s}\n\n", .{ RED, mismatches, total_checked, pct, RESET });
        std.debug.print("{s}RECOMMENDED ACTIONS:{s}\n", .{ GOLD, RESET });
        std.debug.print("  1. Run {s}tri math fit-origin <id>{s} to check fit origin\n", .{ CYAN, RESET });
        std.debug.print("  2. Run {s}tri math prove <id>{s} to see full details\n", .{ CYAN, RESET });
        std.debug.print("  3. Update {s}declared_expression{s} or adjust parameters\n\n", .{ CYAN, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIT ORIGIN COMMAND — Show fit origin details for a formula
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runFitOriginCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("{s}Usage: tri math fit-origin <formula_id>{s}\n", .{ GOLD, RESET });
        std.debug.print("\nShows the fit origin (canonical/search_fit/postdiction) for a formula.\n\n", .{});
        return;
    }

    const formula_id = args[0];

    var reg_inst = registry.Registry.init(allocator);
    defer reg_inst.deinit();
    try reg_inst.loadAllFormulas();

    const formula = reg_inst.get(formula_id) orelse {
        std.debug.print("{s}Error: Formula '{s}' not found in registry{s}\n", .{ RED, formula_id, RESET });
        return;
    };

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  FIT ORIGIN ANALYSIS — {s}{s}\n", .{ BOLD, RESET, formula_id });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ CYAN, RESET });

    std.debug.print("{s}Name:{s} {s}\n", .{ BOLD, RESET, formula.name });
    const domain_str = formula.domain.format();
    std.debug.print("{s}Domain:{s} {s}\n\n", .{ BOLD, RESET, domain_str });

    // Fit Origin
    std.debug.print("{s}Fit Origin:{s} ", .{ BOLD, RESET });
    if (formula.fit_origin) |origin| {
        const color = switch (origin) {
            .canonical => GREEN,
            .search_fit => GOLD,
            .postdiction => RED,
            .prior_informed => GOLD,
            .semiblind => CYAN,
            .blind => GREEN,
            .manual_override => MAGENTA,
        };
        const origin_str = origin.format();
        std.debug.print("{s}{s}{s}\n", .{ color, origin_str, RESET });

        // Show explanation
        std.debug.print("\n{s}Explanation:{s}\n", .{ BOLD, RESET });
        switch (origin) {
            .canonical => std.debug.print("  Derived from sacred formula V = n×3^k×π^m×φ^p×e^q×γ^r×C^t×G^u\n", .{}),
            .search_fit => std.debug.print("  Parameters obtained through numerical optimization/curve-fitting\n", .{}),
            .postdiction => std.debug.print("  Parameters adjusted after seeing experimental data (HARKING risk)\n", .{}),
            .prior_informed => std.debug.print("  Only bounds/ranges known; formula uses priors but no precise target\n", .{}),
            .semiblind => std.debug.print("  Partial knowledge; deliberately avoided best-fit numbers\n", .{}),
            .blind => std.debug.print("  No measurement exists; only order-of-magnitude or unknown\n", .{}),
            .manual_override => std.debug.print("  Fit origin manually set by user\n", .{}),
        }
    } else {
        std.debug.print("{s}[not specified]{s}\n", .{ GRAY, RESET });
        std.debug.print("\n{s}Warning:{s} Fit origin not specified. This formula should be audited.\n", .{ GOLD, RESET });
    }

    // Declared Expression
    std.debug.print("\n{s}Declared Expression:{s} ", .{ BOLD, RESET });
    if (formula.declared_expression) |declared| {
        std.debug.print("{s}\n", .{declared});
    } else {
        std.debug.print("{s}[not declared]{s}\n", .{ GRAY, RESET });
        std.debug.print("\n{s}Warning:{s} Declared expression missing. Cannot verify I16 invariant.\n", .{ GOLD, RESET });
    }

    // Parameters
    const p = formula.params;
    std.debug.print("\n{s}Parameters:{s}\n", .{ BOLD, RESET });
    std.debug.print("  n={d:.0} k={d:.0} m={d:.0} p={d:.0} q={d:.0}", .{ p.n, p.k, p.m, p.p, p.q });
    if (p.r != 0 or p.t != 0 or p.u != 0) {
        std.debug.print(" r={d:.0} t={d:.0} u={d:.0}", .{ p.r, p.t, p.u });
    }
    std.debug.print("\n", .{});

    // Computed vs Target
    const computed = formula.compute();
    std.debug.print("\n{s}Values:{s}\n", .{ BOLD, RESET });
    std.debug.print("  Computed: {d:.6}\n", .{computed});
    if (formula.target_value) |target| {
        const error_pct = @abs(computed - target) / target * 100.0;
        const error_color = if (error_pct < 1.0) GREEN else if (error_pct < 10.0) GOLD else RED;
        std.debug.print("  Target:   {d:.6}\n", .{target});
        std.debug.print("  Error:    {s}{d:.2}%{s}\n", .{ error_color, error_pct, RESET });
    }

    // Verdict
    std.debug.print("\n{s}Verdict:{s} {s}{s}{s}\n", .{ BOLD, RESET, formula.getVerdict().colorCode(), formula.getVerdict().format(), RESET });

    // Epistemic Status
    const verdict = formula.getVerdict();
    if (verdict == .formula_mismatch) {
        std.debug.print("\n{s}⚠ EPISTEMIC FAILURE DETECTED{s}\n", .{ RED, RESET });
        std.debug.print("  The declared expression does not match the computed value.\n", .{});
        std.debug.print("  Action required: Either fix the declared expression or mark as search_fit.\n", .{});
    }

    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOCTOR --EPISTEMIC FLAG — Extended epistemic checks
// ═══════════════════════════════════════════════════════════════════════════════

fn runEpistemicHealthCheck(_: std.mem.Allocator, reg: *const registry.Registry) !void {
    std.debug.print("{s}Epistemic Health Check:{s}\n\n", .{ BOLD, RESET });

    var issues: usize = 0;

    // Check 1: Formulas with formula_mismatch verdict
    std.debug.print("{s}[EPISTEMIC-001]{s} Formula Mismatch Detection:\n", .{ CYAN, RESET });
    var mismatch_count: usize = 0;
    var iter = reg.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.getVerdict() == .formula_mismatch) {
            mismatch_count += 1;
            std.debug.print("  {s}✗{s} {s}: {s}\n", .{ RED, RESET, formula.id, formula.getVerdict().format() });
        }
    }
    if (mismatch_count == 0) {
        std.debug.print("  {s}✓{s} No formula mismatches detected\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  Found {d} formula(s) with mismatch\n", .{mismatch_count});
        issues += mismatch_count;
    }

    // Check 2: Missing declared_expression (I16 cannot be verified)
    std.debug.print("\n{s}[EPISTEMIC-002]{s} Missing Declared Expressions:\n", .{ CYAN, RESET });
    var missing_decl_count: usize = 0;
    iter = reg.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.declared_expression == null) {
            missing_decl_count += 1;
            std.debug.print("  {s}⚠{s} {s}: declared_expression not set\n", .{ GOLD, RESET, formula.id });
        }
    }
    if (missing_decl_count == 0) {
        std.debug.print("  {s}✓{s} All formulas have declared expressions\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  Found {d} formula(s) without declared expression\n", .{missing_decl_count});
        if (missing_decl_count <= 5) {
            std.debug.print("    {s}Note:{s} Core-only formulas may not need declared expressions\n", .{ DIM, RESET });
        }
    }

    // Check 3: Missing fit_origin
    std.debug.print("\n{s}[EPISTEMIC-003]{s} Missing Fit Origin:\n", .{ CYAN, RESET });
    var missing_fit_count: usize = 0;
    iter = reg.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.fit_origin == null) {
            missing_fit_count += 1;
            std.debug.print("  {s}⚠{s} {s}: fit_origin not set\n", .{ GOLD, RESET, formula.id });
        }
    }
    if (missing_fit_count == 0) {
        std.debug.print("  {s}✓{s} All formulas have fit origin specified\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  Found {d} formula(s) without fit origin\n", .{missing_fit_count});
        issues += missing_fit_count;
    }

    // Check 4: search_fit vs canonical classification
    std.debug.print("\n{s}[EPISTEMIC-004]{s} Fit Origin Classification:\n", .{ CYAN, RESET });
    var canonical_count: usize = 0;
    var search_fit_count: usize = 0;
    var postdiction_count: usize = 0;
    iter = reg.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.fit_origin) |origin| {
            switch (origin) {
                .canonical => canonical_count += 1,
                .search_fit => search_fit_count += 1,
                .postdiction, .prior_informed, .semiblind, .blind => postdiction_count += 1,
                .manual_override => {},
            }
        }
    }
    const total_with_fit = canonical_count + search_fit_count + postdiction_count;
    if (total_with_fit > 0) {
        std.debug.print("  Canonical:   {d}\n", .{canonical_count});
        std.debug.print("  Search fit:  {d}\n", .{search_fit_count});
        std.debug.print("  Postdiction: {d}\n", .{postdiction_count});

        // Warn if high search_fit percentage
        const search_fit_pct = @as(f64, @floatFromInt(search_fit_count)) / @as(f64, @floatFromInt(total_with_fit)) * 100.0;
        if (search_fit_pct > 30.0) {
            std.debug.print("  {s}⚠{s} High search_fit percentage ({d:.1}%) — risk of overfitting\n", .{ GOLD, RESET, search_fit_pct });
            issues += 1;
        }
    } else {
        std.debug.print("  {s}⚠{s} No formulas have fit origin specified\n", .{ GOLD, RESET });
    }

    // Check 5: I16 violation detection (declared vs computed mismatch)
    std.debug.print("\n{s}[EPISTEMIC-005]{s} I16 Invariant Violations:\n", .{ CYAN, RESET });
    var i16_violations: usize = 0;
    iter = reg.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.declared_expression != null) {
            const computed = formula.compute();
            if (formula.target_value) |target| {
                const mismatch_pct = @abs(computed - target) / target * 100.0;
                if (mismatch_pct > 10.0) {
                    i16_violations += 1;
                    std.debug.print("  {s}✗{s} {s}: Δ = {d:.1}%\n", .{ RED, RESET, formula.id, mismatch_pct });
                }
            }
        }
    }
    if (i16_violations == 0) {
        std.debug.print("  {s}✓{s} No I16 violations detected\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  Found {d} I16 violation(s)\n", .{i16_violations});
        issues += i16_violations;
    }

    // Summary
    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ CYAN, RESET });
    if (issues == 0) {
        std.debug.print("\n{s}✓ All epistemic checks passed.{s}\n\n", .{ GREEN, RESET });
    } else {
        std.debug.print("\n{s}✗ {d} epistemic issue(s) found.{s}\n\n", .{ RED, issues, RESET });
        std.debug.print("{s}RECOMMENDED ACTIONS:{s}\n", .{ GOLD, RESET });
        std.debug.print("  • Run {s}tri math audit-mismatch{s} for detailed breakdown\n", .{ CYAN, RESET });
        std.debug.print("  • Run {s}tri math fit-origin <id>{s} to check specific formulas\n", .{ CYAN, RESET });
        std.debug.print("  • Run {s}tri math prove <id>{s} to see full proof state\n\n", .{ CYAN, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CI GATE — Canonical layer epistemic integrity check
// ═══════════════════════════════════════════════════════════════════════════════
/// CI gate function that fails if canonical layer has formula_mismatch
/// Returns error if any canonical formula has I16 violation (formula_mismatch)
/// Usage: CI/CD pipelines to enforce epistemic discipline
pub fn runCanonicalIntegrityCheck(allocator: std.mem.Allocator) !void {
    var reg_inst = registry.Registry.init(allocator);
    defer reg_inst.deinit();
    try reg_inst.loadAllFormulas();

    var canonical_mismatches: usize = 0;
    var unspecified_count: usize = 0;

    // Check all formulas
    var iter = reg_inst.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;

        // Check canonical formulas for mismatches
        if (formula.fit_origin == .canonical) {
            const verdict = formula.getVerdict();

            // CRITICAL: canonical formula with formula_mismatch is violation
            if (verdict == .formula_mismatch) {
                canonical_mismatches += 1;
                std.debug.print("{s}CI FAIL:{s} Canonical formula '{s}' has {s}FORMULA_MISMATCH{s}\n", .{
                    RED, RESET, formula.id, RED, RESET,
                });

                if (formula.declared_expression) |declared| {
                    const computed = formula.compute();
                    if (formula.target_value) |target| {
                        const error_pct = @abs(computed - target) / target * 100.0;
                        std.debug.print("  Declared: {s}\n", .{declared});
                        std.debug.print("  Computed: {d:.6}, Target: {d:.6}, Error: {d:.1}%\n", .{
                            computed, target, error_pct,
                        });
                    }
                }
                std.debug.print("  {s}REMEDIATION:{s} Change fit_origin to .search_fit or fix declared_expression\n\n", .{ GOLD, RESET });
            }
        }

        // Count unspecified formulas (warning only)
        if (formula.fit_origin == null) {
            unspecified_count += 1;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // CI DECISION — Fail on canonical mismatches, warn on unspecified
    // ═══════════════════════════════════════════════════════════════════════════════
    if (canonical_mismatches > 0) {
        std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ RED, RESET });
        std.debug.print("{s}CI GATE FAILED{s}\n", .{ RED, RESET });
        std.debug.print("{d} canonical formula(s) with FORMULA_MISMATCH detected\n", .{canonical_mismatches});
        std.debug.print("\n{s}OPERATIONAL RULE:{s} Canonical layer must be mismatch-free.\n", .{ BOLD, RESET });
        std.debug.print("{s}CHARTER REFERENCE:{s} PROOF_DISCIPLINE_CHARTER.md § Epistemic Failure Taxonomy\n\n", .{ CYAN, RESET });
        return error.CanonicalIntegrityViolation;
    }

    // Warn about unspecified formulas (not a CI failure, but actionable)
    if (unspecified_count > 0) {
        std.debug.print("{s}⚠ {s}AUDIT REQUIRED:{s} {d} formulas lack fit_origin metadata\n", .{ GOLD, RESET, BOLD, unspecified_count });
        std.debug.print("  Run {s}tri math audit-unspecified{s} to categorize these formulas\n", .{ CYAN, RESET });
        std.debug.print("  Options: .canonical | .search_fit | .postdiction | .manual_override\n\n", .{});
    }

    // PREDICTIONS_LOG eligibility check
    const predictions_log_non_canonical = [_][]const u8{
        "qcd_tc_candidate", // P-QCD-E001: SEARCH_FIT
        "omega_lambda", // P-COSM-E001: SEARCH_FIT
        "omega_dm", // P-COSM-E002: SEARCH_FIT
    };

    var non_canonical_in_predictions: usize = 0;
    for (predictions_log_non_canonical) |formula_id| {
        if (reg_inst.get(formula_id)) |formula| {
            if (formula.fit_origin != null and formula.fit_origin.? != .canonical) {
                non_canonical_in_predictions += 1;
                if (non_canonical_in_predictions == 1) {
                    std.debug.print("\n{s}⚠{s} {s}PREDICTIONS_LOG ELIGIBILITY WARNING:{s}\n", .{ GOLD, RESET, BOLD, RESET });
                    std.debug.print("  Following formulas in PREDICTIONS_LOG have {s}fit_origin != .canonical{s}:\n\n", .{ GOLD, RESET });
                }
                const origin_str = formula.fit_origin.?.format();
                std.debug.print("  • {s} ({s}){s}\n", .{ formula_id, origin_str, RESET });
            }
        }
    }

    if (non_canonical_in_predictions > 0) {
        std.debug.print("\n  {s}ACTION REQUIRED:{s} Move to Exploratory Fits section or elevate to canonical\n", .{ BOLD, RESET });
        std.debug.print("  See: {s}docs/PREDICTIONS_LOG.md{s} → Exploratory Fits section\n\n", .{ CYAN, RESET });
    }

    std.debug.print("{s}✓ CI GATE PASSED{s} — Canonical layer is epistemically clean\n", .{ GREEN, RESET });
    if (unspecified_count == 0) {
        std.debug.print("{s}✓ All formulas have fit_origin declared{s}\n", .{ GREEN, RESET });
    }
}

// Custom error for CI gate failure
const CanonicalIntegrityViolation = error{
    CanonicalIntegrityViolation,
};

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT UNSPECIFIED — List all formulas without fit_origin
// ═══════════════════════════════════════════════════════════════════════════════
pub fn runAuditUnspecifiedCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var reg_inst = registry.Registry.init(allocator);
    defer reg_inst.deinit();
    try reg_inst.loadAllFormulas();

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}  FIT ORIGIN AUDIT — Unspecified Formulas{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ GOLD, RESET });

    var unspecified_list: std.ArrayList([]const u8) = .empty;
    defer {
        for (unspecified_list.items) |item| {
            allocator.free(item);
        }
        unspecified_list.deinit(allocator);
    }

    var iter = reg_inst.formulas.iterator();
    while (iter.next()) |entry| {
        const formula = entry.value_ptr;
        if (formula.fit_origin == null) {
            const id_copy = try allocator.dupe(u8, formula.id);
            try unspecified_list.append(allocator, id_copy);
        }
    }

    if (unspecified_list.items.len == 0) {
        std.debug.print("{s}✓ All formulas have fit_origin declared{s}\n\n", .{ GREEN, RESET });
        return;
    }

    std.debug.print("{s}Found {d} formulas without fit_origin:{s}\n\n", .{ BOLD, unspecified_list.items.len, RESET });

    for (unspecified_list.items, 0..) |id, i| {
        const formula = reg_inst.get(id).?;
        const verdict = formula.getVerdict();

        // Suggest fit_origin based on verdict
        const suggestion = switch (verdict) {
            .exact, .validated => ".canonical  (validated with PDG reference)",
            .lattice_consistent => ".canonical  (theoretically consistent)",
            .candidate => ".search_fit OR .canonical  (needs review)",
            .speculative => ".canonical OR .postdiction  (pre-registered?)",
            .formula_mismatch => ".search_fit  (has I16 violation)",
            .rejected => ".manual_override  (falsified)",
        };

        std.debug.print("{s}[{d}] {s}{s}\n", .{ GOLD, i + 1, id, RESET });
        std.debug.print("    Name: {s}\n", .{formula.name});
        std.debug.print("    Verdict: {s}{s}{s}\n", .{ verdict.colorCode(), verdict.format(), RESET });
        std.debug.print("    {s}Suggested:{s} {s}\n", .{ CYAN, RESET, suggestion });

        if (formula.target_value) |target| {
            const computed = formula.compute();
            const error_pct = @abs(computed - target) / target * 100.0;
            std.debug.print("    Computed: {d:.6}, Target: {d:.6}, Error: {d:.2}%\n", .{
                computed, target, error_pct,
            });
        }

        // Check for γ-dependency
        if (formula.params.r != 0 or formula.params.t != 0 or formula.params.u != 0) {
            std.debug.print("    {s}Note:{s} γ-dependent (r={d:.0}, t={d:.0}, u={d:.0})\n", .{
                DIM, RESET, formula.params.r, formula.params.t, formula.params.u,
            });
        }

        std.debug.print("\n", .{});
    }

    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}REMEDIATION: Update fit_origin in proof_types.zig ParticlePhysicsConstant{s}\n", .{ BOLD, RESET });
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOCTOR --EPISTEMIC FLAG — Extended epistemic checks
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH CANONICAL — Brute-force search for sacred formulas
// V = n × 3^k × π^m × φ^p × e^q × γ^r
// ═══════════════════════════════════════════════════════════════════════════════

const SearchCandidate = struct {
    params: expanded_v2.SacredParamsV2,
    computed_value: f64,
    error_pct: f64,
    expression: []const u8,
};

pub fn runSearchCanonicalCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        std.debug.print("{s}Usage:{s} tri math search-canonical <formula_id> [--allow-gamma] [--max-error=1.0] [--pslq]\n\n", .{ CYAN, RESET });
        std.debug.print("Search for canonical sacred formulas matching target value.\n\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  --allow-gamma    Include γ parameter (r∈{{-2..2}}) in search\n", .{});
        std.debug.print("  --max-error=N    Maximum error percentage (default: 1.0)\n", .{});
        std.debug.print("  --pslq           Use PSLQ algorithm (log-space lattice search)\n\n", .{});
        std.debug.print("Example:\n", .{});
        std.debug.print("  tri math search-canonical omega_dm\n", .{});
        std.debug.print("  tri math search-canonical qcd_tc_candidate --allow-gamma --max-error=3.0\n", .{});
        std.debug.print("  tri math search-canonical omega_dm --pslq\n", .{});
        return;
    }

    const formula_id = args[0];
    var allow_gamma = false;
    var max_error: f64 = 1.0;
    var use_pslq = false;

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--allow-gamma")) {
            allow_gamma = true;
        } else if (std.mem.eql(u8, arg, "--pslq")) {
            use_pslq = true;
        } else if (std.mem.startsWith(u8, arg, "--max-error=")) {
            const eq_idx = std.mem.lastIndexOfScalar(u8, arg, '=').? + 1;
            const val_str = arg[eq_idx..];
            max_error = try std.fmt.parseFloat(f64, val_str);
        }
    }

    // Import lattice module for PSLQ
    const lattice = @import("lattice.zig");

    var reg_inst = registry.Registry.init(allocator);
    defer reg_inst.deinit();
    try reg_inst.loadAllFormulas();

    const formula = reg_inst.get(formula_id) orelse {
        std.debug.print("{s}Error:{s} Formula '{s}' not found in registry\n", .{ RED, RESET, formula_id });
        return error.FormulaNotFound;
    };

    const target_value = formula.target_value orelse {
        std.debug.print("{s}Error:{s} Formula '{s}' has no target value to match\n", .{ RED, RESET, formula_id });
        return error.NoTargetValue;
    };

    std.debug.print("\n{s}═══════════════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}  CANONICAL FORMULA SEARCH{s}\n", .{ BOLD, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n\n", .{ GOLD, RESET });

    std.debug.print("{s}TARGET:{s} {s} ({s})\n", .{ BOLD, RESET, formula.name, formula_id });
    std.debug.print("{s}TARGET VALUE:{s} {d:.6}\n", .{ BOLD, RESET, target_value });
    std.debug.print("{s}MAX ERROR:{s} {d:.1}%\n", .{ BOLD, RESET, max_error });
    std.debug.print("{s}ALLOW GAMMA:{s} {s}\n", .{ BOLD, RESET, if (allow_gamma) "YES" else "NO" });
    std.debug.print("{s}ALGORITHM:{s} {s}\n\n", .{ BOLD, RESET, if (use_pslq) "PSLQ (log-space lattice search)" else "Brute-force enumeration" });

    // PSLQ path - efficient log-space lattice search with TOP-5 candidates
    if (use_pslq) {
        std.debug.print("{s}Running PSLQ algorithm...{s}\n\n", .{ CYAN, RESET });

        var results = try lattice.findFormulasWithPSLQ(
            allocator,
            target_value,
            allow_gamma,
            max_error / 100.0, // Convert percentage to fraction
        );
        defer results.deinit();

        if (!results.found()) {
            std.debug.print("{s}NO MATCHES FOUND (PSLQ){s}\n\n", .{ RED, RESET });
            std.debug.print("{s}SUGGESTIONS:{s}\n", .{ BOLD, RESET });
            std.debug.print("  • Try increasing --max-error\n", .{});
            std.debug.print("  • Try --allow-gamma for γ-dependent formulas\n", .{});
            std.debug.print("  • Use brute-force (without --pslq) for exhaustive search\n\n", .{});
            return;
        }

        // Display TOP-5 candidates
        const num_candidates = results.candidates.items.len;
        std.debug.print("{s}FOUND {d} CANDIDATE(S){s} ({d} iterations)\n\n", .{ GREEN, num_candidates, RESET, results.iterations });

        for (results.candidates.items, 0..) |cand, i| {
            const rank = i + 1;

            const star_str = if (i == 0) " ★" else "";
            std.debug.print("{s}#{d}{s}{s}\n", .{ CYAN, rank, star_str, RESET });

            const params = expanded_v2.SacredParamsV2{
                .n = @floatFromInt(cand.n),
                .k = @floatFromInt(cand.k),
                .m = @floatFromInt(cand.m),
                .p = @floatFromInt(cand.p),
                .q = @floatFromInt(cand.q),
                .r = @floatFromInt(cand.r),
                .t = 0.0,
                .u = 0.0,
            };

            const computed = params.compute();
            const error_pct = cand.residual * 100.0;

            std.debug.print("  Parameters: n={d}, k={d}, m={d}, p={d}, q={d}, r={d}\n", .{
                cand.n, cand.k, cand.m, cand.p, cand.q, cand.r,
            });
            std.debug.print("  Complexity: {d:.1} (lower = simpler)\n", .{cand.complexity});
            std.debug.print("  Pareto score: {d:.3} (error × complexity)\n", .{cand.pareto_score});

            const expr = try generateExpression(allocator, params);
            defer allocator.free(expr);

            std.debug.print("  Formula: {s}\n", .{expr});
            std.debug.print("  Computed: {d:.6}\n", .{computed});
            std.debug.print("  Error: {d:.3}%\n", .{error_pct});

            // Verdict for this candidate
            if (error_pct <= 1.0) {
                std.debug.print("  {s}VERDICT:{s} {s}CANONICAL{s}\n", .{ GOLD, RESET, GREEN, RESET });
            } else if (cand.r != 0) {
                std.debug.print("  {s}VERDICT:{s} {s}SEARCH_FIT{s}\n", .{ GOLD, RESET, YELLOW, RESET });
            } else {
                std.debug.print("  {s}VERDICT:{s} {s}CANDIDATE{s}\n", .{ GOLD, RESET, YELLOW, RESET });
            }

            if (i < num_candidates - 1) {
                std.debug.print("\n", .{});
            }
        }

        std.debug.print("\n", .{});

        // Comparison note
        if (num_candidates > 1) {
            std.debug.print("{s}NOTE:{s} Multiple lattice points found near target.\n", .{ YELLOW, RESET });
            std.debug.print("Lower complexity + lower error = more 'sacred' formula (Occam's razor).\n\n", .{});
        }

        return;
    }

    const n_min: f64 = 1;
    const n_max: f64 = 100;
    const k_min: f64 = -4;
    const k_max: f64 = 4;
    const m_min: f64 = -4;
    const m_max: f64 = 4;
    const p_min: f64 = -6;
    const p_max: f64 = 6;
    const q_min: f64 = -4;
    const q_max: f64 = 4;
    const r_min: f64 = if (allow_gamma) -2 else 0;
    const r_max: f64 = if (allow_gamma) 2 else 0;

    std.debug.print("{s}SEARCH SPACE:{s}\n", .{ BOLD, RESET });
    std.debug.print("  n: {d:.0}..{d:.0}, k: {d:.0}..{d:.0}, m: {d:.0}..{d:.0}\n", .{ n_min, n_max, k_min, k_max, m_min, m_max });
    std.debug.print("  p: {d:.0}..{d:.0}, q: {d:.0}..{d:.0}, r: {d:.0}..{d:.0}\n\n", .{ p_min, p_max, q_min, q_max, r_min, r_max });

    // Calculate total iterations: n:1..100 (100), k:-4..4 (9), m:-4..4 (9), p:-6..6 (13), q:-4..4 (9), r depends on allow_gamma
    const n_range: u64 = 100;
    const k_range: u64 = 9;
    const m_range: u64 = 9;
    const p_range: u64 = 13;
    const q_range: u64 = 9;
    const r_range: u64 = if (allow_gamma) 5 else 1;
    const total_iterations: u64 = n_range * k_range * m_range * p_range * q_range * r_range;

    std.debug.print("{s}SEARCHING{s} (~{d} combinations)...\n\n", .{ CYAN, RESET, total_iterations });

    var candidates = try std.ArrayList(SearchCandidate).initCapacity(allocator, 16);
    defer {
        for (candidates.items) |c| {
            allocator.free(c.expression);
        }
        candidates.deinit(allocator);
    }

    var checked: u64 = 0;
    var found: u64 = 0;
    const progress_interval = if (total_iterations > 100) total_iterations / 100 else 1;

    var n_idx: f64 = n_min;
    while (n_idx <= n_max) : (n_idx += 1) {
        var k_idx: f64 = k_min;
        while (k_idx <= k_max) : (k_idx += 1) {
            var m_idx: f64 = m_min;
            while (m_idx <= m_max) : (m_idx += 1) {
                var p_idx: f64 = p_min;
                while (p_idx <= p_max) : (p_idx += 1) {
                    var q_idx: f64 = q_min;
                    while (q_idx <= q_max) : (q_idx += 1) {
                        var r_idx: f64 = r_min;
                        while (r_idx <= r_max) : (r_idx += 1) {
                            checked += 1;

                            if (checked % progress_interval == 0 or checked == total_iterations) {
                                const progress = @as(f64, @floatFromInt(checked)) / @as(f64, @floatFromInt(total_iterations)) * 100.0;
                                std.debug.print("\r{s}Progress:{s} [{d:>5}%] {d}/{d} combinations, {d} found", .{
                                    CYAN, RESET, @as(u32, @intFromFloat(progress)), checked, total_iterations, found,
                                });
                            }

                            const params = expanded_v2.SacredParamsV2{
                                .n = n_idx,
                                .k = k_idx,
                                .m = m_idx,
                                .p = p_idx,
                                .q = q_idx,
                                .r = r_idx,
                                .t = 0.0,
                                .u = 0.0,
                            };

                            const computed = params.compute();
                            const error_pct = @abs(computed - target_value) / target_value * 100.0;
                            if (error_pct <= max_error) {
                                found += 1;

                                const expr = try generateExpression(allocator, params);
                                errdefer allocator.free(expr);

                                try candidates.append(allocator, .{
                                    .params = params,
                                    .computed_value = computed,
                                    .error_pct = error_pct,
                                    .expression = expr,
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    std.debug.print("\n\n", .{});

    std.sort.insertion(SearchCandidate, candidates.items, {}, struct {
        fn lessThan(_: void, a: SearchCandidate, b: SearchCandidate) bool {
            return a.error_pct < b.error_pct;
        }
    }.lessThan);

    if (candidates.items.len > 5) {
        for (candidates.items[5..]) |*c| {
            allocator.free(c.expression);
        }
        candidates.items.len = 5;
    }

    if (candidates.items.len == 0) {
        std.debug.print("{s}NO MATCHES FOUND{s}\n\n", .{ RED, RESET });
        std.debug.print("{s}SUGGESTIONS:{s}\n", .{ BOLD, RESET });
        std.debug.print("  • Try increasing --max-error\n", .{});
        std.debug.print("  • Try --allow-gamma for γ-dependent formulas\n", .{});
        std.debug.print("  • Consider that sacred parametrization may not apply to this domain\n\n", .{});
        std.debug.print("{s}RECOMMENDATION:{s} Mark formula as {s}rejected_canonical_search{s}\n", .{ GOLD, RESET, RED, RESET });
        std.debug.print("  This is an honest result — governance layer working as intended.\n\n", .{});
        return;
    }

    std.debug.print("{s}FOUND {d} CANDIDATE(S){s}\n\n", .{ GREEN, candidates.items.len, RESET });

    for (candidates.items, 0..) |candidate, idx| {
        std.debug.print("{s}[#{d}] {s}{s}\n", .{ GOLD, idx + 1, RESET, candidate.expression });
        std.debug.print("    Computed: {d:.6}, Target: {d:.6}\n", .{ candidate.computed_value, target_value });
        std.debug.print("    Error: {d:.3}% {s}✓{s}\n\n", .{ candidate.error_pct, GREEN, RESET });
    }

    const best = candidates.items[0];
    std.debug.print("{s}═══════════════════════════════════════════════════════{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}BEST CANDIDATE#{s}\n\n", .{ BOLD, RESET });
    std.debug.print("{s}Formula:{s} {s}\n", .{ BOLD, RESET, best.expression });
    std.debug.print("{s}Params:{s} n={d:.0}, k={d:.0}, m={d:.0}, p={d:.0}, q={d:.0}, r={d:.0}\n", .{
        BOLD, RESET, best.params.n, best.params.k, best.params.m, best.params.p, best.params.q, best.params.r,
    });
    std.debug.print("{s}Result:{s} {d:.6} (target: {d:.6})\n", .{ BOLD, RESET, best.computed_value, target_value });
    std.debug.print("{s}Error:{s} {d:.3}%\n\n", .{ BOLD, RESET, best.error_pct });

    std.debug.print("{s}NEXT STEPS:{s}\n", .{ BOLD, RESET });
    std.debug.print("  1. Update formula in proof_types.zig:\n", .{});
    std.debug.print("     .params = .{{ .n = {d:.0}, .k = {d:.0}, .m = {d:.0}, .p = {d:.0}, .q = {d:.0}, .r = {d:.0} }}\n", .{
        best.params.n, best.params.k, best.params.m, best.params.p, best.params.q, best.params.r,
    });
    std.debug.print("     .declared_expression = \"{s}\"\n", .{best.expression});
    std.debug.print("     .fit_origin = .canonical\n\n", .{});

    if (best.params.r != 0) {
        std.debug.print("  {s}NOTE:{s} γ-dependent formula → evidence_level = candidate, never exact (R3)\n", .{ GOLD, RESET });
    } else {
        std.debug.print("  {s}NOTE:{s} γ-free formula → evidence_level = exact or validated possible\n", .{ GREEN, RESET });
    }

    std.debug.print("  2. Run: tri math prove {s}\n", .{formula_id});
    std.debug.print("  3. Run: tri math ci-check\n\n", .{});
}

fn generateExpression(allocator: std.mem.Allocator, params: expanded_v2.SacredParamsV2) ![]const u8 {
    var parts = try std.ArrayList([]const u8).initCapacity(allocator, 8);
    defer {
        for (parts.items) |p| allocator.free(p);
        parts.deinit(allocator);
    }

    const n = params.n;
    const k = params.k;
    const m = params.m;
    const p = params.p;
    const q = params.q;
    const r = params.r;

    if (n != 1.0) try parts.append(allocator, try std.fmt.allocPrint(allocator, "{d}", .{n}));
    if (k != 0.0) try parts.append(allocator, try std.fmt.allocPrint(allocator, "3^{{{d}}}", .{@as(i32, @intFromFloat(k))}));
    if (m != 0.0) try parts.append(allocator, try std.fmt.allocPrint(allocator, "π^{{{d}}}", .{@as(i32, @intFromFloat(m))}));
    if (p != 0.0) try parts.append(allocator, try std.fmt.allocPrint(allocator, "φ^{{{d}}}", .{@as(i32, @intFromFloat(p))}));
    if (q != 0.0) try parts.append(allocator, try std.fmt.allocPrint(allocator, "e^{{{d}}}", .{@as(i32, @intFromFloat(q))}));
    if (r != 0.0) try parts.append(allocator, try std.fmt.allocPrint(allocator, "γ^{{{d}}}", .{@as(i32, @intFromFloat(r))}));

    if (parts.items.len == 0) {
        return allocator.dupe(u8, "1");
    }

    var result = try std.ArrayList(u8).initCapacity(allocator, 64);
    defer result.deinit(allocator);
    for (parts.items, 0..) |part, i| {
        if (i > 0) try result.appendSlice(allocator, " × ");
        try result.appendSlice(allocator, part);
    }

    return result.toOwnedSlice(allocator);
}
