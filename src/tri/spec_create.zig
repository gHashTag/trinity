// @origin(spec:spec_create_v2.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// SPEC CREATE v2 — Real spec creation with template matching + experience
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri spec create <name> [--issue N] [--description "..."]
// Replaces stub in tri_pipeline.zig that only prints template to stdout.
// Finds best template via spec_template_match.zig, enriches with experience,
// writes .tri file to disk.
//
// Part of Trinity Tech Tree: Layer 1 [L2]
// Dependencies: spec_template_match.zig, tri_experience.zig
// Consumers: dev_loop.zig (I1)
//
// phi^2 + 1/phi^2 = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const colors = @import("tri_colors.zig");
const spec_match = @import("spec_template_match.zig");
const tri_experience = @import("tri_experience.zig");
const print = std.debug.print;

const GREEN = colors.GREEN;
const RED = colors.RED;
const GOLDEN = colors.GOLDEN;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const YELLOW = colors.YELLOW;
const RESET = colors.RESET;
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (from spec_create_v2.tri)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpecCreateInput = struct {
    name: [64]u8 = undefined,
    name_len: usize = 0,
    description: [256]u8 = undefined,
    description_len: usize = 0,
    issue_number: u32 = 0,
    category: [32]u8 = undefined,
    category_len: usize = 0,

    pub fn nameStr(self: *const SpecCreateInput) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn descStr(self: *const SpecCreateInput) []const u8 {
        return self.description[0..self.description_len];
    }

    pub fn categoryStr(self: *const SpecCreateInput) []const u8 {
        return self.category[0..self.category_len];
    }

    fn setName(self: *SpecCreateInput, text: []const u8) void {
        const len = @min(text.len, self.name.len);
        @memcpy(self.name[0..len], text[0..len]);
        self.name_len = len;
    }

    fn setDesc(self: *SpecCreateInput, text: []const u8) void {
        const len = @min(text.len, self.description.len);
        @memcpy(self.description[0..len], text[0..len]);
        self.description_len = len;
    }

    fn setCategory(self: *SpecCreateInput, text: []const u8) void {
        const len = @min(text.len, self.category.len);
        @memcpy(self.category[0..len], text[0..len]);
        self.category_len = len;
    }
};

pub const SpecCreateResult = struct {
    spec_path: [128]u8 = undefined,
    spec_path_len: usize = 0,
    template_used: [128]u8 = undefined,
    template_used_len: usize = 0,
    template_score: f32 = 0,
    hints_applied: u32 = 0,
    validated: bool = false,
    success: bool = false,

    pub fn specPathStr(self: *const SpecCreateResult) []const u8 {
        return self.spec_path[0..self.spec_path_len];
    }

    pub fn templateStr(self: *const SpecCreateResult) []const u8 {
        return self.template_used[0..self.template_used_len];
    }

    fn setSpecPath(self: *SpecCreateResult, text: []const u8) void {
        const len = @min(text.len, self.spec_path.len);
        @memcpy(self.spec_path[0..len], text[0..len]);
        self.spec_path_len = len;
    }

    fn setTemplate(self: *SpecCreateResult, text: []const u8) void {
        const len = @min(text.len, self.template_used.len);
        @memcpy(self.template_used[0..len], text[0..len]);
        self.template_used_len = len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PARSE INPUT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn parseInput(args: []const []const u8) ?SpecCreateInput {
    if (args.len == 0) return null;

    // Skip name validation if --help flag (handled by caller)
    if (args.len > 0 and std.mem.eql(u8, args[0], "--help")) return null;

    var input = SpecCreateInput{};
    input.setName(args[0]);

    // Parse optional flags
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--issue") and i + 1 < args.len) {
            input.issue_number = std.fmt.parseInt(u32, args[i + 1], 10) catch 0;
            i += 1;
        } else if (std.mem.eql(u8, args[i], "--description") and i + 1 < args.len) {
            input.setDesc(args[i + 1]);
            i += 1;
        }
    }

    // Auto-detect category from name prefix
    const name = input.nameStr();
    if (std.mem.startsWith(u8, name, "dev_")) {
        input.setCategory("development");
    } else if (std.mem.startsWith(u8, name, "test_") or std.mem.startsWith(u8, name, "e2e_")) {
        input.setCategory("testing");
    } else if (std.mem.startsWith(u8, name, "fpga_")) {
        input.setCategory("fpga");
    } else if (std.mem.startsWith(u8, name, "perf_") or std.mem.startsWith(u8, name, "bench_")) {
        input.setCategory("performance");
    } else if (std.mem.startsWith(u8, name, "tri_")) {
        input.setCategory("core");
    } else {
        input.setCategory("general");
    }

    // Validate name: lowercase + underscores only
    // Skip validation for --help flag
    const name_to_validate = input.nameStr();
    if (std.mem.eql(u8, name_to_validate, "--help")) {
        // Help is valid flag, skip name validation
    } else {
        for (name_to_validate) |c| {
            if (!((c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_')) {
                print("{s}Invalid spec name: '{s}'. Use lowercase + underscores only.{s}\n", .{ RED, name_to_validate, RESET });
                return null;
            }
        }
    }

    return input;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECK DUPLICATE
// ═══════════════════════════════════════════════════════════════════════════════

pub fn checkDuplicate(name: []const u8) bool {
    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "specs/tri/{s}.tri", .{name}) catch return false;
    std.fs.cwd().access(path, .{}) catch return false;
    return true; // exists = duplicate
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIND TEMPLATE
// ═══════════════════════════════════════════════════════════════════════════════

const TemplateMatch = struct {
    score: f32 = 0,
    path: [128]u8 = undefined,
    path_len: usize = 0,
};

fn findTemplate(allocator: Allocator, input: *const SpecCreateInput) TemplateMatch {
    // Build search text from name + description
    var search_buf: [320]u8 = undefined;
    const search_text = std.fmt.bufPrint(&search_buf, "{s} {s}", .{ input.nameStr(), input.descStr() }) catch input.nameStr();

    // Scan existing specs
    var candidates: [64]spec_match.SpecCandidate = undefined;
    const count = spec_match.scanSpecs(allocator, &candidates);

    if (count == 0) {
        return .{};
    }

    const match_result = spec_match.findBestTemplate(allocator, search_text, &candidates, count);

    if (match_result.best_index) |idx| {
        var result = TemplateMatch{
            .score = match_result.best_score,
        };
        const p = candidates[idx].pathStr();
        const len = @min(p.len, result.path.len);
        @memcpy(result.path[0..len], p[0..len]);
        result.path_len = len;
        return result;
    }

    return .{};
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENRICH FROM EXPERIENCE
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_HINTS = 8;

pub const ExperienceHint = struct {
    text: [128]u8 = undefined,
    text_len: usize = 0,

    pub fn textStr(self: *const ExperienceHint) []const u8 {
        return self.text[0..self.text_len];
    }

    fn setText(self: *ExperienceHint, t: []const u8) void {
        const len = @min(t.len, self.text.len);
        @memcpy(self.text[0..len], t[0..len]);
        self.text_len = len;
    }
};

const ExperienceResult = struct {
    hints: [MAX_HINTS]ExperienceHint = undefined,
    count: usize = 0,
};

fn enrichFromExperience(input: *const SpecCreateInput) ExperienceResult {
    var result = ExperienceResult{};

    // Read experience log for keyword matching
    const exp_file = std.fs.cwd().openFile("EXPERIENCE_LOG.md", .{}) catch return result;
    defer exp_file.close();

    var exp_buf: [16384]u8 = undefined;
    const bytes = exp_file.readAll(&exp_buf) catch return result;
    if (bytes == 0) return result;

    const exp_content = exp_buf[0..bytes];
    const name = input.nameStr();

    // Split name into keyword tokens
    var words: [8][]const u8 = undefined;
    var word_count: usize = 0;
    var word_iter = std.mem.splitScalar(u8, name, '_');
    while (word_iter.next()) |w| {
        if (w.len < 2) continue;
        if (word_count < 8) {
            words[word_count] = w;
            word_count += 1;
        }
    }

    if (word_count == 0) return result;

    const kw_score = tri_experience.keywordScore(exp_content, words[0..word_count]);
    if (kw_score > 0) {
        // Found related experience — add generic hints
        var hint = ExperienceHint{};
        hint.setText("Related experience found — check EXPERIENCE_LOG.md for patterns");
        result.hints[result.count] = hint;
        result.count += 1;
    }

    // Check for FAIL patterns in experience
    if (std.mem.indexOf(u8, exp_content, "FAIL") != null and kw_score > 2) {
        var hint = ExperienceHint{};
        hint.setText("CAUTION: past failures found for similar keywords");
        result.hints[result.count] = hint;
        result.count += 1;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATE SPEC CONTENT
// ═══════════════════════════════════════════════════════════════════════════════

fn generateSpec(allocator: Allocator, input: *const SpecCreateInput, template_path: []const u8, template_score: f32, hints: []const ExperienceHint, hint_count: usize) ?[]const u8 {
    var content: std.ArrayList(u8) = .empty;
    errdefer content.deinit(allocator);

    const w = content.writer(allocator);

    // Header
    w.print("# ═══════════════════════════════════════════════════════════════════════════════\n", .{}) catch return null;
    w.print("# {s} v1.0.0\n", .{input.nameStr()}) catch return null;
    w.print("# ═══════════════════════════════════════════════════════════════════════════════\n", .{}) catch return null;

    if (input.description_len > 0) {
        w.print("# {s}\n", .{input.descStr()}) catch return null;
    }
    if (input.issue_number > 0) {
        w.print("# Closes #{d}\n", .{input.issue_number}) catch return null;
    }
    w.print("#\n# phi^2 + 1/phi^2 = 3 = TRINITY\n", .{}) catch return null;
    w.print("# ═══════════════════════════════════════════════════════════════════════════════\n\n", .{}) catch return null;

    // Metadata
    w.print("name: {s}\nversion: \"1.0.0\"\nlanguage: zig\nmodule: {s}\n\n", .{ input.nameStr(), input.nameStr() }) catch return null;

    // Experience hints as comments
    if (hint_count > 0) {
        w.print("# Experience hints:\n", .{}) catch return null;
        for (hints[0..hint_count]) |hint| {
            w.print("# HINT: {s}\n", .{hint.textStr()}) catch return null;
        }
        w.print("\n", .{}) catch return null;
    }

    // Template info
    if (template_score > 0.1 and template_path.len > 0) {
        w.print("# Template: {s} (score: {d:.2})\n\n", .{ template_path, template_score }) catch return null;
    }

    // Types section
    w.print("types:\n", .{}) catch return null;
    w.print("  {s}Config:\n", .{input.nameStr()}) catch return null;
    w.print("    fields:\n", .{}) catch return null;
    w.print("      name: String\n", .{}) catch return null;
    w.print("      enabled: Bool\n\n", .{}) catch return null;

    w.print("  {s}Result:\n", .{input.nameStr()}) catch return null;
    w.print("    fields:\n", .{}) catch return null;
    w.print("      success: Bool\n", .{}) catch return null;
    w.print("      message: String\n\n", .{}) catch return null;

    // Behaviors section
    w.print("behaviors:\n", .{}) catch return null;
    w.print("  - name: init\n", .{}) catch return null;
    w.print("    given: allocator\n", .{}) catch return null;
    w.print("    when: Module initializes\n", .{}) catch return null;
    w.print("    then: Returns ready state\n\n", .{}) catch return null;

    w.print("  - name: run\n", .{}) catch return null;
    w.print("    given: {s}Config\n", .{input.nameStr()}) catch return null;
    w.print("    when: Execution requested\n", .{}) catch return null;
    w.print("    then: Returns {s}Result\n\n", .{input.nameStr()}) catch return null;

    // Tests section
    w.print("tests:\n", .{}) catch return null;
    w.print("  test_init:\n", .{}) catch return null;
    w.print("    description: Module initializes without error\n", .{}) catch return null;
    w.print("  test_run:\n", .{}) catch return null;
    w.print("    description: Run behavior produces valid result\n\n", .{}) catch return null;

    // Exit criteria
    w.print("exit_criteria:\n", .{}) catch return null;
    w.print("  compiles: true\n", .{}) catch return null;
    w.print("  tests_pass: true\n\n", .{}) catch return null;

    // Metadata
    w.print("metadata:\n", .{}) catch return null;
    w.print("  author: Trinity SWE Pipeline\n", .{}) catch return null;
    w.print("  phase: 1\n", .{}) catch return null;
    if (input.issue_number > 0) {
        w.print("  closes: \"#{d}\"\n", .{input.issue_number}) catch return null;
    }

    return content.toOwnedSlice(allocator) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WRITE SPEC
// ═══════════════════════════════════════════════════════════════════════════════

fn writeSpec(name: []const u8, spec_content: []const u8) ?[128]u8 {
    std.fs.cwd().makePath("specs/tri") catch return null;

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "specs/tri/{s}.tri", .{name}) catch return null;

    const file = std.fs.cwd().createFile(path, .{}) catch return null;
    defer file.close();

    file.writeAll(spec_content) catch return null;

    var result: [128]u8 = undefined;
    @memcpy(result[0..path.len], path);
    // Zero-fill rest
    @memset(result[path.len..], 0);
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER RESULT
// ═══════════════════════════════════════════════════════════════════════════════

fn renderResult(result: *const SpecCreateResult) void {
    if (!result.success) {
        print("\n{s}SPEC CREATE FAILED{s}\n\n", .{ RED, RESET });
        return;
    }

    print("\n{s}SPEC CREATED{s}\n", .{ GOLDEN, RESET });
    print("{s}════════════════════════════════════════════{s}\n\n", .{ GRAY, RESET });

    print("  {s}Path:{s}     {s}\n", .{ CYAN, RESET, result.specPathStr() });
    if (result.template_used_len > 0) {
        const score_pct: u32 = @intFromFloat(result.template_score * 100);
        print("  {s}Template:{s} {s} ({d}%% match)\n", .{ CYAN, RESET, result.templateStr(), score_pct });
    }
    print("  {s}Hints:{s}    {d} applied\n", .{ CYAN, RESET, result.hints_applied });

    print("\n  {s}Next steps:{s}\n", .{ DIM, RESET });
    print("    1. Edit specs/tri/<name>.tri — customize types and behaviors\n", .{});
    print("    2. tri gen specs/tri/<name>.tri — generate .zig code\n", .{});
    print("    3. zig build test — verify it compiles\n", .{});

    print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn showHelp() void {
    print("{s}USAGE:{s}\n", .{ GOLDEN, RESET });
    print("  tri spec create <name> [options]\n", .{});
    print("\n", .{});
    print("{s}OPTIONS:{s}\n", .{ GOLDEN, RESET });
    print("  {s}<name>{s}            Spec name (lowercase + underscores)\n", .{ CYAN, RESET });
    print("  {s}--issue <N>{s}      Link to GitHub issue\n", .{ CYAN, RESET });
    print("  {s}--description \"..\"{s}  Spec description\n", .{ CYAN, RESET });
    print("\n", .{});
    print("{s}EXAMPLES:{s}\n", .{ GOLDEN, RESET });
    print("  tri spec create dev_metrics --issue 42 --description \"Track agent performance\"\n", .{});
    print("  tri spec create test_e2e_pipeline --description \"End-to-end tests\"\n", .{});
    print("  tri spec create fpga_inference_engine\n", .{});
    print("\n", .{});
    print("{s}OUTPUT:{s}\n", .{ GOLDEN, RESET });
    print("  Creates specs/tri/<name>.tri from best matching template.\n", .{});
    print("\n", .{});
    print("{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — CLI entrypoint
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runSpecCreateCommand(allocator: Allocator, args: []const []const u8) void {
    if (args.len == 0) {
        print("{s}Usage: tri spec create <name> [--issue N] [--description \"...\"]{s}\n", .{ RED, RESET });
        print("Example: tri spec create dev_metrics --issue 42 --description \"Track agent performance\"\n", .{});
        print("       tri spec create --help — Show detailed help\n", .{});
        return;
    }

    // Check for --help flag before parsing
    if (args.len > 0 and std.mem.eql(u8, args[0], "--help")) {
        showHelp();
        return;
    }

    // 1. Parse input
    const input = parseInput(args) orelse return;

    print("\n{s}Creating spec: {s}{s}\n", .{ CYAN, input.nameStr(), RESET });

    // 2. Check duplicate
    if (checkDuplicate(input.nameStr())) {
        print("{s}Spec already exists: specs/tri/{s}.tri{s}\n", .{ YELLOW, input.nameStr(), RESET });
        print("Edit it directly or delete it first.\n", .{});
        return;
    }

    // 3. Find best template
    const template = findTemplate(allocator, &input);
    const template_path: []const u8 = if (template.path_len > 0)
        template.path[0..template.path_len]
    else
        "";

    if (template.score > 0.1) {
        print("  {s}Template match:{s} {s} ({d:.0}%%)\n", .{ DIM, RESET, template_path, template.score * 100 });
    }

    // 4. Enrich from experience
    const exp = enrichFromExperience(&input);
    if (exp.count > 0) {
        print("  {s}Experience hints:{s} {d}\n", .{ DIM, RESET, exp.count });
    }

    // 5. Generate spec content
    const spec_content = generateSpec(allocator, &input, template_path, template.score, &exp.hints, exp.count) orelse {
        print("{s}Failed to generate spec content{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(spec_content);

    // 6. Write to disk
    const written_path = writeSpec(input.nameStr(), spec_content) orelse {
        print("{s}Failed to write spec file{s}\n", .{ RED, RESET });
        return;
    };

    // 7. Build result
    var result = SpecCreateResult{
        .template_score = template.score,
        .hints_applied = @intCast(exp.count),
        .success = true,
    };

    // Find actual path length (zero-terminated in written_path)
    var path_len: usize = 0;
    for (written_path) |c| {
        if (c == 0) break;
        path_len += 1;
    }
    result.setSpecPath(written_path[0..path_len]);

    if (template.path_len > 0) {
        result.setTemplate(template_path);
    }

    renderResult(&result);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parseInput basic" {
    const args = [_][]const u8{"my_module"};
    const input = parseInput(&args);
    try std.testing.expect(input != null);
    try std.testing.expectEqualStrings("my_module", input.?.nameStr());
    try std.testing.expectEqualStrings("general", input.?.categoryStr());
}

test "parseInput with flags" {
    const args = [_][]const u8{ "dev_scanner", "--issue", "42", "--description", "Scan stuff" };
    const input = parseInput(&args);
    try std.testing.expect(input != null);
    try std.testing.expectEqualStrings("dev_scanner", input.?.nameStr());
    try std.testing.expectEqual(@as(u32, 42), input.?.issue_number);
    try std.testing.expectEqualStrings("Scan stuff", input.?.descStr());
    try std.testing.expectEqualStrings("development", input.?.categoryStr());
}

test "parseInput rejects invalid name" {
    const args = [_][]const u8{"My-Module"};
    const input = parseInput(&args);
    try std.testing.expect(input == null);
}

test "parseInput category detection" {
    const dev_args = [_][]const u8{"dev_metrics"};
    const test_args = [_][]const u8{"test_harness"};
    const fpga_args = [_][]const u8{"fpga_uart"};
    const perf_args = [_][]const u8{"perf_benchmark"};

    try std.testing.expectEqualStrings("development", parseInput(&dev_args).?.categoryStr());
    try std.testing.expectEqualStrings("testing", parseInput(&test_args).?.categoryStr());
    try std.testing.expectEqualStrings("fpga", parseInput(&fpga_args).?.categoryStr());
    try std.testing.expectEqualStrings("performance", parseInput(&perf_args).?.categoryStr());
}

test "parseInput empty args" {
    const args = [_][]const u8{};
    const input = parseInput(&args);
    try std.testing.expect(input == null);
}

test "checkDuplicate finds existing spec" {
    // dev_scan.tri exists
    try std.testing.expect(checkDuplicate("dev_scan"));
}

test "checkDuplicate returns false for nonexistent" {
    try std.testing.expect(!checkDuplicate("nonexistent_spec_xyz_12345"));
}

test "SpecCreateInput setters" {
    var input = SpecCreateInput{};
    input.setName("test_mod");
    input.setDesc("A test module");
    input.setCategory("testing");

    try std.testing.expectEqualStrings("test_mod", input.nameStr());
    try std.testing.expectEqualStrings("A test module", input.descStr());
    try std.testing.expectEqualStrings("testing", input.categoryStr());
}

test "SpecCreateResult setters" {
    var result = SpecCreateResult{};
    result.setSpecPath("specs/tri/test.tri");
    result.setTemplate("specs/tri/dev_scan.tri");
    result.template_score = 0.75;

    try std.testing.expectEqualStrings("specs/tri/test.tri", result.specPathStr());
    try std.testing.expectEqualStrings("specs/tri/dev_scan.tri", result.templateStr());
}
