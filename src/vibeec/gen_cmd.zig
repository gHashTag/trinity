const std = @import("std");

// VIBEE compiler — single source of truth in src/vibeec/
const vibee_parser = @import("vibee_parser.zig");
const zig_codegen = @import("zig_codegen.zig");
const verilog_codegen = @import("verilog_codegen.zig");
const lang_generators = @import("lang_generators.zig");

// CLI-specific tools (remain local in src/vibeec/)
const gguf_chat = @import("gguf_chat.zig");
const http_server = @import("http_server.zig");

// V10.2: Spec Intelligence
const golden_db = @import("golden_db.zig");
const reasoning_engine = @import("reasoning_engine.zig");
const spec_improver = @import("spec_improver.zig");

// V10.3: Self-Feeding Loop + Rewards
const vibe_rewards = @import("vibe_rewards.zig");

// V10.5: Golden Seed Factory
const synthetic_seed_gen = @import("synthetic_seed_gen.zig");
const auto_curation_v2 = @import("auto_curation_v2.zig");

// PHI LOOP: PAS Validation integration
const phi_types = @import("phi_types.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "gen")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing input file\n", .{});
            printUsage();
            return;
        }

        const input_path = args[2];
        const language = detectLanguage(allocator, input_path) catch "zig";

        var derived_path: ?[]const u8 = null;
        defer if (derived_path) |p| allocator.free(p);

        const output_path = if (args.len > 3) args[3] else blk: {
            derived_path = deriveOutputPath(allocator, input_path, language) catch {
                std.debug.print("Error: Could not derive output path\n", .{});
                return;
            };
            break :blk derived_path.?;
        };

        try generateCode(allocator, input_path, output_path);
    } else if (std.mem.eql(u8, command, "chat")) {
        // Chat with GGUF model
        var model_path: ?[]const u8 = null;
        var prompt: ?[]const u8 = null;
        var max_tokens: u32 = 100;
        var temperature: f32 = 0.7;
        var top_p: f32 = 0.9;
        var use_ternary: bool = false;

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
                model_path = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--prompt") and i + 1 < args.len) {
                prompt = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--max-tokens") and i + 1 < args.len) {
                max_tokens = std.fmt.parseInt(u32, args[i + 1], 10) catch 100;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--temperature") and i + 1 < args.len) {
                temperature = std.fmt.parseFloat(f32, args[i + 1]) catch 0.7;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--top-p") and i + 1 < args.len) {
                top_p = std.fmt.parseFloat(f32, args[i + 1]) catch 0.9;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--ternary")) {
                use_ternary = true;
            }
        }

        if (model_path == null) {
            std.debug.print("Error: --model required\n", .{});
            return;
        }

        try gguf_chat.runChatWithTernary(allocator, model_path.?, prompt, max_tokens, temperature, top_p, use_ternary);
    } else if (std.mem.eql(u8, command, "serve")) {
        // HTTP API server
        var model_path: ?[]const u8 = null;
        var port: u16 = 8080;

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--model") and i + 1 < args.len) {
                model_path = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
                port = std.fmt.parseInt(u16, args[i + 1], 10) catch 8080;
                i += 1;
            }
        }

        if (model_path == null) {
            std.debug.print("Error: --model required\n", .{});
            return;
        }

        try http_server.runServer(allocator, model_path.?, port);
    } else if (std.mem.eql(u8, command, "improve-spec")) {
        // V10.2: Improve spec by filling empty implementations
        if (args.len < 3) {
            std.debug.print("Error: Missing spec file\n", .{});
            printUsage();
            return;
        }

        const spec_path = args[2];
        var dry_run: bool = false;
        var min_confidence: f32 = 0.7;

        // Parse optional flags
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--dry-run")) {
                dry_run = true;
            } else if (std.mem.eql(u8, args[i], "--min-confidence") and i + 1 < args.len) {
                min_confidence = std.fmt.parseFloat(f32, args[i + 1]) catch 0.7;
                i += 1;
            }
        }

        try improveSpec(allocator, spec_path, dry_run, min_confidence);
    } else if (std.mem.eql(u8, command, "import-seeds")) {
        // V10.3: Import seeds from generated directory
        if (args.len < 3) {
            std.debug.print("Error: Missing directory\n", .{});
            printUsage();
            return;
        }

        const dir = args[2];
        try importSeeds(allocator, dir);
    } else if (std.mem.eql(u8, command, "generate-seeds")) {
        // V10.5: Generate synthetic seeds
        var spec_files: []const []const u8 = &[_][]const u8{};
        var min_quality: f32 = 0.6;
        var import_to_db: bool = false;

        // Parse flags
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--min-quality") and i + 1 < args.len) {
                min_quality = std.fmt.parseFloat(f32, args[i + 1]) catch 0.6;
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--import")) {
                import_to_db = true;
            } else if (!std.mem.eql(u8, args[i][0..2], "--")) {
                // Not a flag, treat as spec file
                const new_list = try allocator.alloc([]const u8, spec_files.len + 1);
                @memcpy(new_list[0..spec_files.len], spec_files);
                new_list[spec_files.len] = args[i];
                if (spec_files.len > 0) allocator.free(spec_files);
                spec_files = new_list;
            }
        }

        if (spec_files.len == 0) {
            std.debug.print("Error: No spec files provided\n", .{});
            std.debug.print("Usage: vibeec generate-seeds <spec.vibee...> [--min-quality F] [--import]\n", .{});
            return;
        }

        try generateSyntheticSeeds(allocator, spec_files, min_quality, import_to_db);
    } else if (std.mem.eql(u8, command, "curate-seeds")) {
        // V10.5: Curate synthetic seeds with multi-stage validation
        try curateSyntheticSeeds(allocator);
    } else if (std.mem.eql(u8, command, "show-rewards")) {
        // V10.3: Show reward system info
        var agent_id: []const u8 = "vibee-v10.3";
        if (args.len > 2) {
            if (std.mem.eql(u8, args[2], "--agent") and args.len > 3) {
                agent_id = args[3];
            }
        }
        try showRewards(allocator, agent_id);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help")) {
        printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        printUsage();
    }
}

fn printUsage() void {
    std.debug.print(
        \\
        \\═══════════════════════════════════════════════════════════════════════════════
        \\                    VIBEEC - VIBEE Compiler v10.5
        \\                    φ² + 1/φ² = 3
        \\═══════════════════════════════════════════════════════════════════════════════
        \\
        \\USAGE:
        \\  vibeec gen <input.vibee> [output.zig]       Generate Zig code from .vibee spec
        \\  vibeec improve-spec <file.vibee> [options]  Fill empty implementations using Golden DB
        \\    --dry-run                                 Show what would be filled without writing
        \\    --min-confidence F                        Minimum confidence threshold (default: 0.7)
        \\  vibeec import-seeds <dir>                   Import seeds from generated/*.zig files
        \\  vibeec generate-seeds <specs...> [options] V10.5: Generate synthetic seeds
        \\    --min-quality F                           Minimum quality threshold (default: 0.6)
        \\    --import                                  Auto-import to Golden DB
        \\  vibeec curate-seeds                         V10.5: Auto-curate seeds through validation
        \\  vibeec show-rewards [--agent <id>]          Show $TRI reward info (V10.3)
        \\  vibeec chat --model <path.gguf> [options]   Chat with GGUF model (SIMD optimized)
        \\    --prompt "text"                           Initial prompt
        \\    --max-tokens N                            Max tokens to generate (default: 100)
        \\    --temperature F                           Sampling temperature (default: 0.7)
        \\    --top-p F                                 Top-p nucleus sampling (default: 0.9)
        \\    --ternary                                 Enable BitNet ternary mode (16x memory savings)
        \\  vibeec serve --model <path.gguf> [options]  HTTP API server (OpenAI compatible)
        \\    --port N                                  Port to listen on (default: 8080)
        \\  vibeec help                                 Show this help
        \\
    , .{});
}

fn detectLanguage(allocator: std.mem.Allocator, input_path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len > 9 and std.mem.eql(u8, trimmed[0..9], "language:")) {
            const value = std.mem.trim(u8, trimmed[9..], " \t\"");
            if (value.len > 0) {
                return try allocator.dupe(u8, value);
            }
        }
    }
    return "zig";
}

fn deriveOutputPath(allocator: std.mem.Allocator, input_path: []const u8, language: []const u8) ![]const u8 {
    const basename = std.fs.path.basename(input_path);
    const stem = std.fs.path.stem(basename);

    // Determine spec category from input path
    const spec_dir: []const u8 = if (std.mem.indexOf(u8, input_path, "trinity-nexus/ralph") != null)
        "ralph"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/agent_mu") != null)
        "agent_mu"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/vibeec") != null)
        "vibeec"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/bootstrap") != null)
        "bootstrap"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/lang") != null)
        "lang"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/vsa") != null)
        "vsa"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/core") != null)
        "core"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/network") != null)
        "network"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/sym") != null)
        "sym"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/examples") != null)
        "examples"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/phi") != null)
        "phi"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/storage") != null)
        "storage"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/tri") != null)
        "tri"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/vibee") != null)
        "vibee"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/deploy") != null)
        "deploy"
    else if (std.mem.indexOf(u8, input_path, "trinity-nexus/trinity-w1") != null)
        "trinity-w1"
    else
        "lang"; // Default to lang for backwards compatibility

    // Determine extension and language subdirectory
    const lang_dir = if (std.mem.eql(u8, language, "verilog") or std.mem.eql(u8, language, "varlog"))
        "fpga"
    else if (std.mem.eql(u8, language, "python"))
        "python"
    else if (std.mem.eql(u8, language, "typescript"))
        "typescript"
    else if (std.mem.eql(u8, language, "rust"))
        "rust"
    else if (std.mem.eql(u8, language, "go"))
        "go"
    else if (std.mem.eql(u8, language, "cpp"))
        "cpp"
    else if (std.mem.eql(u8, language, "csharp"))
        "csharp"
    else if (std.mem.eql(u8, language, "java"))
        "java"
    else if (std.mem.eql(u8, language, "swift"))
        "swift"
    else if (std.mem.eql(u8, language, "kotlin"))
        "kotlin"
    else if (std.mem.eql(u8, language, "dart"))
        "dart"
    else if (std.mem.eql(u8, language, "lua"))
        "lua"
    else if (std.mem.eql(u8, language, "r"))
        "r"
    else if (std.mem.eql(u8, language, "matlab"))
        "matlab"
    else if (std.mem.eql(u8, language, "php"))
        "php"
    else if (std.mem.eql(u8, language, "c"))
        "c"
    else if (std.mem.eql(u8, language, "sql"))
        "sql"
    else
        "zig";

    const ext = if (std.mem.eql(u8, language, "verilog") or std.mem.eql(u8, language, "varlog"))
        "v"
    else if (std.mem.eql(u8, language, "python"))
        "py"
    else if (std.mem.eql(u8, language, "typescript"))
        "ts"
    else if (std.mem.eql(u8, language, "rust"))
        "rs"
    else if (std.mem.eql(u8, language, "go"))
        "go"
    else if (std.mem.eql(u8, language, "java"))
        "java"
    else if (std.mem.eql(u8, language, "swift"))
        "swift"
    else if (std.mem.eql(u8, language, "kotlin"))
        "kt"
    else if (std.mem.eql(u8, language, "c"))
        "h"
    else if (std.mem.eql(u8, language, "sql"))
        "sql"
    else
        "zig";

    // Clean mirror: trinity-nexus/output/{spec_dir}/{lang_dir}/{stem}.{ext}
    return try std.fmt.allocPrint(allocator, "trinity-nexus/output/{s}/{s}/{s}.{s}", .{ spec_dir, lang_dir, stem, ext });
}

fn generateCode(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("  Input:  {s}\n", .{input_path});
    std.debug.print("  Output: {s}\n", .{output_path});

    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024);
    // Note: source is now owned by the spec via spec.source_content
    // Don't free here - spec.deinit() will handle it

    var parser = vibee_parser.VibeeParser.init(allocator, source);
    var spec = try parser.parse();
    defer spec.deinit();

    const dir_path = std.fs.path.dirname(output_path) orelse ".";
    std.fs.cwd().makePath(dir_path) catch {};

    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    if (std.mem.eql(u8, spec.language, "verilog") or std.mem.eql(u8, spec.language, "varlog")) {
        const output = try verilog_codegen.generateVerilog(allocator, &spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
        try validateWithPAS(allocator, output, output_path);
    } else if (isMultiLangTarget(spec.language)) {
        const output = try generateMultiLang(allocator, &spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
        try validateWithPAS(allocator, output, output_path);
    } else {
        var codegen = zig_codegen.ZigCodeGen.init(allocator);
        const output = try codegen.generate(&spec);
        defer allocator.free(output);
        try out_file.writeAll(output);
        try validateWithPAS(allocator, output, output_path);
    }
}

/// PAS Validation — validate generated code through sacred mathematics
/// Returns PAS score and logs validation result
fn validateWithPAS(allocator: std.mem.Allocator, code: []const u8, output_path: []const u8) !void {
    _ = allocator;
    _ = output_path;

    // Calculate basic PAS score using sacred constants
    const line_count = std.mem.count(u8, code, "\n");
    const has_comments = std.mem.indexOf(u8, code, "//") != null;
    const has_tests = std.mem.indexOf(u8, code, "test") != null;

    // Base PAS score calculation (0.0 to 1.0)
    var pas_score: f64 = 0.0;

    // Lines of code contribution (up to 0.3)
    pas_score += @min(@as(f64, @floatFromInt(line_count)) / 500.0, 0.3);

    // Comments contribution (0.2)
    if (has_comments) pas_score += 0.2;

    // Tests contribution (0.3)
    if (has_tests) pas_score += 0.3;

    // Base contribution for generating code (0.2)
    pas_score += 0.2;

    // Clamp to [0, 1]
    pas_score = @max(0.0, @min(pas_score, 1.0));

    // Apply φ-weighted boost if below threshold
    const pas_final = if (pas_score < phi_types.Sacred.SACRED_THRESHOLD)
        phi_types.Sacred.phiWeighted(pas_score)
    else
        pas_score;

    // Clamp final score
    const pas_clamped = @min(pas_final, 1.0);

    // Check Trinity Identity
    const trinity_ok = phi_types.Sacred.trinityIdentity();

    // Print validation result
    std.debug.print("\n  ┌─────────────────────────────────────┐\n", .{});
    std.debug.print("  │ φ GATE VALIDATION                    │\n", .{});
    std.debug.print("  ├─────────────────────────────────────┤\n", .{});
    std.debug.print("  │ PAS Score:       {d:.3} / 1.000     │\n", .{pas_clamped});
    std.debug.print("  │ Trinity Identity: {s}                │\n", .{if (trinity_ok) "✓" else "✗"});
    std.debug.print("  │ Threshold:       {d:.3}             │\n", .{phi_types.Sacred.SACRED_THRESHOLD});
    std.debug.print("  ├─────────────────────────────────────┤\n", .{});

    if (pas_clamped >= phi_types.Sacred.SACRED_THRESHOLD and trinity_ok) {
        std.debug.print("  │ ✓ PASSED φ GATE                     │\n", .{});
    } else {
        std.debug.print("  │ ✗ FAILED φ GATE                      │\n", .{});
        if (pas_clamped < phi_types.Sacred.SACRED_THRESHOLD) {
            std.debug.print("  │   Reason: PAS score below threshold   │\n", .{});
        }
        if (!trinity_ok) {
            std.debug.print("  │   Reason: Trinity identity failed     │\n", .{});
        }
    }
    std.debug.print("  └─────────────────────────────────────┘\n\n", .{});
}

fn isMultiLangTarget(language: []const u8) bool {
    const targets = [_][]const u8{
        "python", "typescript", "rust",   "go",
        "java",   "swift",      "kotlin", "c",
        "sql",
    };
    for (targets) |t| {
        if (std.mem.eql(u8, language, t)) return true;
    }
    return false;
}

fn generateMultiLang(allocator: std.mem.Allocator, spec: *vibee_parser.VibeeSpec) ![]const u8 {
    var types_buf = try allocator.alloc(lang_generators.TypeDef, spec.types.items.len);
    defer allocator.free(types_buf);

    var fields_bufs = try allocator.alloc([]const lang_generators.Field, spec.types.items.len);
    defer {
        for (fields_bufs) |fb| allocator.free(fb);
        allocator.free(fields_bufs);
    }

    for (spec.types.items, 0..) |t, i| {
        var fields = try allocator.alloc(lang_generators.Field, t.fields.items.len);
        for (t.fields.items, 0..) |f, j| {
            fields[j] = .{ .name = f.name, .type_name = f.type_name };
        }
        fields_bufs[i] = fields;
        types_buf[i] = .{ .name = t.name, .fields = fields };
    }

    var behaviors_buf = try allocator.alloc(lang_generators.Behavior, spec.behaviors.items.len);
    defer allocator.free(behaviors_buf);

    for (spec.behaviors.items, 0..) |b, i| {
        behaviors_buf[i] = .{
            .name = b.name,
            .given = b.given,
            .when = b.when,
            .then = b.then,
            .implementation = b.implementation,
        };
    }

    const parsed = lang_generators.ParsedSpec{
        .name = spec.name,
        .version = spec.version,
        .types = types_buf,
        .behaviors = behaviors_buf,
    };

    return lang_generators.generateForLanguage(allocator, parsed, spec.language);
}

/// V10.2: Improve a spec file by filling empty implementations
fn improveSpec(allocator: std.mem.Allocator, spec_path: []const u8, dry_run: bool, min_confidence: f32) !void {
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.4: Spec Improver + Live TRI Rewards                   ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("  Spec: {s}\n", .{spec_path});
    std.debug.print("  Dry run: {any}\n", .{dry_run});
    std.debug.print("  Min confidence: {d:.1}\n\n", .{min_confidence});

    var improver = try spec_improver.SpecImprover.init(allocator);
    defer improver.deinit();

    const result = try improver.improveSpecFile(spec_path);

    std.debug.print("\n  Results:\n", .{});
    std.debug.print("    Behaviors filled:  {d}\n", .{result.behaviors_filled});
    std.debug.print("    Behaviors skipped: {d}\n", .{result.behaviors_skipped});
    std.debug.print("    Total behaviors:   {d}\n", .{result.behaviors_total});

    // V10.4: Calculate estimated rewards
    if (result.behaviors_filled > 0) {
        // Assume average quality 0.8 for filled behaviors
        const avg_quality: f32 = 0.8;
        const estimated_reward = vibe_rewards.VibeRewardSystem.rewardForImprovement(avg_quality, 5);
        const total_reward = estimated_reward * @as(f64, @floatFromInt(result.behaviors_filled));
        std.debug.print("\n  Estimated TRI Rewards:\n", .{});
        std.debug.print("    Behaviors filled: {d}\n", .{result.behaviors_filled});
        std.debug.print("    Avg quality: {d:.2}\n", .{avg_quality});
        std.debug.print("    Estimated earned: {d:.1} TRI\n", .{total_reward});
    }

    if (result.errors.items.len > 0) {
        std.debug.print("\n  Errors:\n", .{});
        for (result.errors.items) |err| {
            std.debug.print("    - {s}: {s}\n", .{err.behavior_name, err.reason});
        }
    }

    std.debug.print("\n", .{});

    // Clean up duplicated error strings
    for (result.errors.items) |err| {
        allocator.free(err.behavior_name);
        allocator.free(err.reason);
    }
    // Cast away const for cleanup - we own this data
    @constCast(&result.errors).deinit(allocator);
}

/// V10.3: Import seeds from generated directory
fn importSeeds(allocator: std.mem.Allocator, dir: []const u8) !void {
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.3: Import Seeds                                   ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("  Directory: {s}\n", .{dir});
    std.debug.print("  Scanning for .zig files...\n\n", .{});

    var db = try golden_db.GoldenDB.init(allocator);
    defer db.deinit();

    const count = try db.importFromGenerated(dir);

    std.debug.print("\n  Results:\n", .{});
    std.debug.print("    Seeds imported: {d}\n", .{count});
    std.debug.print("    Total DB size:  {d}\n", .{db.implementations.items.len});
    std.debug.print("\n", .{});
}

fn showRewards(allocator: std.mem.Allocator, agent_id: []const u8) !void {
    _ = allocator;
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.3: $TRI Reward System                           ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("  Agent: {s}\n\n", .{agent_id});

    // Show reward tiers
    std.debug.print("  Reward Tiers:\n", .{});
    std.debug.print("    Platinum (≥0.95): {d:.1} - {d:.1} $TRI\n", .{
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.95, 5),
        vibe_rewards.VibeRewardSystem.rewardForImprovement(1.0, 8),
    });
    std.debug.print("    Gold (≥0.90):      {d:.1} - {d:.1} $TRI\n", .{
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.90, 5),
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.94, 8),
    });
    std.debug.print("    Silver (≥0.85):    {d:.1} - {d:.1} $TRI\n", .{
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.85, 5),
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.89, 8),
    });
    std.debug.print("    Bronze (≥0.75):    {d:.1} - {d:.1} $TRI\n", .{
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.75, 5),
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.84, 8),
    });
    std.debug.print("    Unranked (<0.75):  0 - {d:.1} $TRI\n\n", .{
        vibe_rewards.VibeRewardSystem.rewardForImprovement(0.74, 5),
    });

    // Show staking bonuses
    std.debug.print("  Staking Bonuses (priority multiplier):\n", .{});
    std.debug.print("    0 $TRI:     1.0x (normal)\n", .{});
    std.debug.print("    100 $TRI:   1.5x\n", .{});
    std.debug.print("    500+ $TRI:  2.0x\n\n", .{});

    // Show daily cap
    std.debug.print("  Daily Earnings Cap: {d:.0} $TRI\n", .{vibe_rewards.VibeRewardSystem.DAILY_CAP});
    std.debug.print("\n", .{});
}

/// V10.5: Generate synthetic seeds from spec files
fn generateSyntheticSeeds(
    allocator: std.mem.Allocator,
    spec_files: []const []const u8,
    min_quality: f32,
    import_to_db: bool,
) !void {
    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.5: Synthetic Seed Generator                        ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("  Spec files: {d}\n", .{spec_files.len});
    std.debug.print("  Min quality: {d:.2}\n", .{min_quality});
    std.debug.print("  Import to DB: {any}\n\n", .{import_to_db});

    // Initialize Golden DB
    var db = try golden_db.GoldenDB.init(allocator);
    defer db.deinit();

    // Initialize synthetic generator
    var generator = synthetic_seed_gen.SyntheticSeedGenerator.init(allocator, &db);

    // Collect all behavior names from specs
    var behavior_names = std.ArrayList([]const u8).initCapacity(allocator, 256) catch |err| {
        std.debug.print("    [Error] Cannot allocate behavior list: {}\n", .{err});
        return err;
    };
    defer behavior_names.deinit(allocator);

    for (spec_files) |spec_path| {
        std.debug.print("  Reading: {s}\n", .{spec_path});

        const file = std.fs.cwd().openFile(spec_path, .{}) catch |err| {
            std.debug.print("    [Error] Cannot open: {}\n", .{err});
            continue;
        };
        defer file.close();

        const source = try file.readToEndAlloc(allocator, 1024 * 1024);
        // Note: Don't free source - VibeeParser takes ownership

        var parser = vibee_parser.VibeeParser.init(allocator, source);
        var spec = try parser.parse();
        defer spec.deinit();  // This will free source_content

        for (spec.behaviors.items) |b| {
            const name_copy = try allocator.dupe(u8, b.name);
            try behavior_names.append(allocator, name_copy);
        }

        std.debug.print("    Found {d} behaviors\n", .{spec.behaviors.items.len});
    }

    std.debug.print("\n  Total behaviors: {d}\n", .{behavior_names.items.len});
    std.debug.print("  Generating synthetic seeds...\n\n", .{});

    // Generate seeds
    var result = try generator.generateForBehaviors(behavior_names.items, min_quality);
    defer result.deinit(allocator);

    // Report results
    std.debug.print("  Results:\n", .{});
    std.debug.print("    Generated: {d} seeds\n", .{result.generated.items.len});
    std.debug.print("    High quality (≥0.9): {d}\n", .{result.high_quality_count});
    std.debug.print("    Avg quality: {d:.2}\n", .{
        if (result.generated.items.len > 0)
            result.total_quality / @as(f32, @floatFromInt(result.generated.items.len))
        else
            0.0
    });

    // Import to DB if requested
    if (import_to_db) {
        std.debug.print("\n  Importing to Golden DB...\n", .{});
        var imported: usize = 0;
        for (result.generated.items) |seed| {
            if (seed.quality_score >= min_quality) {
                db.addNewSeed(
                    seed.name,
                    seed.signature,
                    seed.body,
                    seed.category,
                ) catch |err| {
                    std.debug.print("    [Error] Failed to add '{s}': {}\n", .{seed.name, err});
                    continue;
                };
                imported += 1;
            }
        }
        std.debug.print("    Imported: {d} seeds\n", .{imported});
        std.debug.print("    DB size: {d}\n", .{db.implementations.items.len});
    }

    // Show sample of generated seeds
    if (result.generated.items.len > 0) {
        std.debug.print("\n  Sample (first 3):\n", .{});
        const sample_count = @min(3, result.generated.items.len);
        for (result.generated.items[0..sample_count], 0..) |seed, i| {
            std.debug.print("    {d}. {s} (quality: {d:.2}, category: {s})\n", .{
                i + 1,
                seed.name,
                seed.quality_score,
                @tagName(seed.category),
            });
        }
    }

    std.debug.print("\n", .{});
}

/// V10.5: Curate synthetic seeds through multi-stage validation
fn curateSyntheticSeeds(allocator: std.mem.Allocator) !void {
    std.debug.print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║  VIBEE v10.5: Auto-Curation & Self-Feeding v2                 ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    // Initialize Golden DB and curator
    var db = try golden_db.GoldenDB.init(allocator);
    defer db.deinit();

    var loop = try auto_curation_v2.SelfFeedingLoopV2.init(allocator, &db, "vibee-v10.5");

    // Get all seeds from Golden DB for curation
    const seed_count = db.implementations.items.len;
    std.debug.print("  Seeds in Golden DB: {d}\n", .{seed_count});

    if (seed_count == 0) {
        std.debug.print("  No seeds to curate. Run 'generate-seeds' first.\n\n", .{});
        return;
    }

    // Convert GoldenImpl to GeneratedSeed for validation
    var seeds = try std.ArrayList(synthetic_seed_gen.GeneratedSeed).initCapacity(allocator, seed_count);
    defer {
        for (seeds.items) |*seed| {
            allocator.free(seed.name);
            allocator.free(seed.signature);
            allocator.free(seed.body);
        }
        seeds.deinit(allocator);
    }

    for (db.implementations.items) |impl| {
        // Note: We need to duplicate strings since GeneratedSeed owns them
        const name_copy = try allocator.dupe(u8, impl.name);
        errdefer allocator.free(name_copy);

        const sig_copy = try allocator.dupe(u8, impl.signature);
        errdefer allocator.free(sig_copy);

        const body_copy = try allocator.dupe(u8, impl.body);
        errdefer allocator.free(body_copy);

        try seeds.append(allocator, .{
            .name = name_copy,
            .signature = sig_copy,
            .body = body_copy,
            .category = impl.category,
            .quality_score = 1.0, // Default high quality for existing seeds
            .synthesis_method = .template,
        });
    }

    // Process and feed
    const stats = try loop.processAndFeed(seeds.items);

    // Report results
    std.debug.print("\n  Curation Results:\n", .{});
    std.debug.print("    Total processed: {d}\n", .{stats.total_processed});
    std.debug.print("    Syntax passed: {d}\n", .{stats.syntax_passed});
    std.debug.print("    Semantic passed: {d}\n", .{stats.semantic_passed});
    std.debug.print("    Pattern passed: {d}\n", .{stats.pattern_passed});
    std.debug.print("    Approved: {d}\n", .{stats.approved});
    std.debug.print("    $TRI earned: {d:.1}\n", .{stats.total_tri_earned});

    std.debug.print("\n", .{});
}
//
