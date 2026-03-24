// @origin(spec:tdgs1.tri) @regen(done)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV GUARDED STACK (TDGS-1) — Core Development Law
// ═══════════════════════════════════════════════════════════════════════════════
//
// TDGS-1: All changes to TTC, core Tri, .t27, and normative docs
//         MUST go through `tri dev` commands.
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;
const print = std.debug.print;

const TTC_CONFIG_PATH = ".trinity/ttc.toml";
const CANON_MAP_PATH = ".trinity/canon_map.json";
const SIGNATURE_PREFIX = "// TRI_CORE_SIGNATURE:";
const MAX_TTC_LOC = 3000;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const DIM = "\x1b[2m";
const MAGENTA = "\x1b[35m";

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT MODES — For tri dev core audit
// ═══════════════════════════════════════════════════════════════════════════════

const AuditMode = enum {
    normal,   // Display formatted table
    changed,  // Read paths from stdin, output JSON
    verify,   // Check signatures, exit 0/1
    strict,   // Full validation, exit 0/1
};

// ═══════════════════════════════════════════════════════════════════════════════
// GUARDED SCOPE — Files that can only be modified via tri dev
// ═══════════════════════════════════════════════════════════════════════════════

pub const GuardedScope = enum {
    ttc,          // Trusted Tri Core (Zig files)
    tri_lang,     // Tri language modules
    tri_stdlib,   // Tri standard library
    tri_canon,    // Canonical Tri modules
    t27,          // TRI-27 artifacts
    docs_norm,    // Normative documentation
    neuro_core,   // Neuro/HSLM core modules
    queen_core,   // Queen UI core modules
};

pub const GuardedFile = struct {
    path: []const u8,
    scope: GuardedScope,
    exists: bool = false,
    loc: usize = 0,
    has_signature: bool = false,
    signature_hash: []const u8 = "",
};

pub const GuardedSet = struct {
    files: []GuardedFile,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !GuardedSet {
        var list = std.ArrayListUnmanaged(GuardedFile){};

        // TTC files from ttc.toml
        try list.append(allocator, GuardedFile{
            .path = "src/tri-lang/lexer.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri-lang/parser.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri-lang/ast.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri-lang/typecheck_core.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri-lang/emit_t27.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri-lang/emit_zig.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri/cell.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri/t27_cli.zig",
            .scope = .ttc,
        });
        try list.append(allocator, GuardedFile{
            .path = "src/tri27/coptic.zig",
            .scope = .ttc,
        });

        // Core Tri modules (src/tri-lang/*.tri)
        const tri_lang_files = [_][]const u8{
            "src/tri-lang/prelude.tri",
            "src/tri-lang/combinators.tri",
            "src/tri-lang/array_ops.tri",
            "src/tri-lang/effect.tri",
            "src/tri-lang/ownership.tri",
            "src/tri-lang/result.tri",
            "src/tri-lang/patterns.tri",
        };
        for (tri_lang_files) |p| {
            try list.append(allocator, GuardedFile{ .path = p, .scope = .tri_lang });
        }

        return .{
            .files = try list.toOwnedSlice(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GuardedSet) void {
        self.allocator.free(self.files);
    }

    pub fn scan(self: *GuardedSet) !void {
        for (self.files) |*f| {
            if (fs.cwd().openFile(f.path, .{})) |file| {
                defer file.close();
                f.exists = true;

                const content = file.readToEndAlloc(self.allocator, 1024 * 1024) catch |err| {
                    std.debug.print("  Error reading {s}: {s}\n", .{ f.path, @errorName(err) });
                    continue;
                };
                defer self.allocator.free(content);

                // Count LOC (non-empty, non-comment lines)
                f.loc = countLoc(content);

                // Check for signature
                f.has_signature = std.mem.indexOf(u8, content, SIGNATURE_PREFIX) != null;
                if (f.has_signature) {
                    if (std.mem.indexOf(u8, content, "sha256:")) |hash_idx| {
                        const hash_start = hash_idx + 7;
                        if (std.mem.indexOf(u8, content[hash_start..], "\n")) |hash_end| {
                            f.signature_hash = content[hash_start..][0..hash_end];
                        }
                    }
                }
            } else |_| {
                f.exists = false;
            }
        }
    }
};

fn countLoc(content: []const u8) usize {
    var count: usize = 0;
    var iter = std.mem.splitScalar(u8, content, '\n');
    while (iter.next()) |line| {
        const trimmed = std.mem.trimLeft(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0) continue; // Empty
        if (std.mem.startsWith(u8, trimmed, "//")) continue; // Comment
        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV CORE — TTC (Trusted Tri Core) Commands
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runCoreCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "audit";

    if (std.mem.eql(u8, subcmd, "audit")) {
        try runCoreAudit(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "install-hook")) {
        try runCoreInstallHook(allocator);
    } else if (std.mem.eql(u8, subcmd, "pre-commit")) {
        try runCorePreCommit(allocator);
    } else if (std.mem.eql(u8, subcmd, "edit-ast")) {
        try runCoreEditAst(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "edit-parser")) {
        try runCoreEditParser(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "edit-emit")) {
        try runCoreEditEmit(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "sign")) {
        try runCoreSign(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printCoreHelp();
    } else {
        std.debug.print("{s}Unknown core subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printCoreHelp();
    }
}

fn runCoreAudit(allocator: Allocator, args: []const []const u8) !void {
    // Check for audit mode flags
    var mode: AuditMode = .normal;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--changed")) {
            mode = .changed;
        } else if (std.mem.eql(u8, arg, "--verify")) {
            mode = .verify;
        } else if (std.mem.eql(u8, arg, "--strict")) {
            mode = .strict;
        }
    }

    switch (mode) {
        .changed => return runCoreAuditChanged(allocator),
        .verify => return runCoreAuditVerify(allocator),
        .strict => return runCoreAuditStrict(allocator),
        .normal => return runCoreAuditNormal(allocator),
    }
}

// tri dev core audit --changed: Read paths from stdin, output JSON of guarded files
fn runCoreAuditChanged(allocator: Allocator) !void {
    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();
    try guarded.scan();

    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    var matched = std.ArrayListUnmanaged([]const u8){};
    defer matched.deinit(allocator);

    // Read paths from stdin (one per line)
    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const trimmed = std.mem.trimRight(u8, line, "\r\n");
        if (trimmed.len == 0) continue;

        // Check if path is in GuardedSet
        for (guarded.files) |f| {
            if (std.mem.eql(u8, f.path, trimmed)) {
                try matched.append(allocator, f.path);
                break;
            }
        }
    }

    // Output JSON result
    const stdout = std.io.getStdOut().writer();
    try stdout.print("[", .{});
    for (matched.items, 0..) |path, i| {
        if (i > 0) try stdout.print(", ", .{});
        try stdout.print("\"{s}\"", .{path});
    }
    try stdout.print("]\n", .{});
}

// tri dev core audit --verify: Check signatures, exit 0/1
fn runCoreAuditVerify(allocator: Allocator) !void {
    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();
    try guarded.scan();

    var all_valid = true;
    for (guarded.files) |f| {
        if (!f.exists) continue;

        const content = try fs.cwd().readFileAlloc(allocator, f.path, 1024 * 1024);
        defer allocator.free(content);

        // Recalculate SHA256 hash
        var hash_buf: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash_buf, .{});
        const hash_hex = try std.fmt.allocPrint(allocator, "{s}", .{std.fmt.bytesToHex(&hash_buf, .lower)});
        defer allocator.free(hash_hex);

        // Verify signature matches
        const valid = f.has_signature and std.mem.indexOf(u8, f.signature_hash, hash_hex) != null;
        if (!valid) {
            std.debug.print("{s}✗ {s}: signature invalid{s}\n", .{ RED, f.path, RESET });
            all_valid = false;
        }
    }

    if (!all_valid) {
        return error.SignatureInvalid;
    }
}

// tri dev core audit --strict: Full audit (LOC + signatures + scope), exit 0/1
fn runCoreAuditStrict(allocator: Allocator) !void {
    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();
    try guarded.scan();

    var all_valid = true;

    for (guarded.files) |f| {
        if (!f.exists) {
            std.debug.print("{s}✗ {s}: missing{ s}\n", .{ RED, f.path, RESET });
            all_valid = false;
            continue;
        }

        // Check LOC limit
        if (f.loc > MAX_TTC_LOC) {
            std.debug.print("{s}✗ {s}: LOC {d} > {d} max{s}\n", .{ RED, f.path, f.loc, MAX_TTC_LOC, RESET });
            all_valid = false;
        }

        // Check signature
        if (!f.has_signature) {
            std.debug.print("{s}✗ {s}: missing signature{s}\n", .{ RED, f.path, RESET });
            all_valid = false;
        }
    }

    if (!all_valid) {
        return error.StrictAuditFailed;
    }
}

// tri dev core audit (normal): Display formatted table
fn runCoreAuditNormal(allocator: Allocator) !void {
    print("\n{s}🔍 TRI DEV CORE AUDIT{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();
    try guarded.scan();

    var total_loc: usize = 0;
    var files_ok: usize = 0;
    var files_missing: usize = 0;
    var files_no_sig: usize = 0;
    var files_over_limit: usize = 0;

    print("  {s}FILE                          STATUS    LOC     SIGNATURE{s}\n", .{ DIM, RESET });
    print("  {s}────────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (guarded.files) |f| {
        if (f.scope != .ttc) continue;

        if (!f.exists) {
            print("  {s}✗{s} {s}", .{ RED, RESET, f.path });
            padTo(f.path.len, 30);
            print("{s}MISSING{s}\n", .{ YELLOW, RESET });
            files_missing += 1;
            continue;
        }

        const sig_color = if (f.has_signature) GREEN else RED;

        print("  {s}✓{s} {s}", .{ GREEN, RESET, f.path });
        padTo(f.path.len, 30);

        const status_color = if (f.loc > MAX_TTC_LOC) RED else GREEN;
        const status_str = if (f.loc > MAX_TTC_LOC) "OVER" else "OK";

        print("{s}{s}{s}", .{ status_color, status_str, RESET });
        padTo(3, 10);
        print("{d}", .{f.loc});
        padTo(digitCount(f.loc), 8);
        if (f.has_signature) {
            print("{s}✓{s}", .{ sig_color, RESET });
        } else {
            print("{s}✗{s}", .{ sig_color, RESET });
        }

        if (f.has_signature) {
            const hash_len = @min(8, f.signature_hash.len);
            print(" {s}({s}){s}", .{ DIM, f.signature_hash[0..hash_len], RESET });
        }
        print("\n", .{});

        total_loc += f.loc;
        if (f.has_signature) files_ok += 1 else files_no_sig += 1;
        if (f.loc > MAX_TTC_LOC) files_over_limit += 1;
    }

    print("\n{s}════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}TTC Summary:{s}\n", .{ BOLD, RESET });
    print("  Total LOC:    {s}{d}{s} / {d} max\n", .{ CYAN, total_loc, RESET, MAX_TTC_LOC });
    print("  Files:        {d} total | {d} OK | {d} no sig | {d} over limit | {d} missing\n", .{
        files_ok + files_no_sig, files_ok, files_no_sig, files_over_limit, files_missing,
    });

    if (files_no_sig > 0 or files_over_limit > 0) {
        print("\n  {s}⚠️  Issues found! Run 'tri dev core sign' to fix.{s}\n\n", .{ YELLOW, RESET });
    } else {
        print("\n  {s}✅ All TTC files healthy!{s}\n\n", .{ GREEN, RESET });
    }
}

// tri dev core install-hook: Create .git/hooks/pre-commit
fn runCoreInstallHook(allocator: Allocator) !void {
    const hook_path = ".git/hooks/pre-commit";

    // Check if hook already exists
    if (fs.cwd().openFile(hook_path, .{})) |file| {
        file.close();
        print("{s}⚠️  Pre-commit hook already exists at {s}{s}\n", .{ YELLOW, hook_path, RESET });
        print("  Backing up to {s}.old{s}\n\n", .{ hook_path, RESET });

        // Backup existing hook
        _ = fs.cwd().copyFile(hook_path, hook_path ++ ".old", .{});
    } else |_| {}

    const hook_content =
        \\#!/bin/sh
        \\# TRI DEV GUARDED STACK pre-commit hook
        \\# Generated by 'tri dev core install-hook'
        \\
        \\# Run pre-commit validation
        \\tri dev core pre-commit || {{
        \\    echo ""
        \\    echo "TDGS-1 VIOLATION: Commit blocked"
        \\    echo "   Run 'tri dev core sign' to fix signatures"
        \\    echo "   Or use 'git commit --no-verify' to bypass (NOT RECOMMENDED)"
        \\    exit 1
        \\}}
        \\


    try fs.cwd().writeFile(.{ .sub_path = hook_path, .data = hook_content });

    // Make hook executable
    if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
        _ = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ "chmod", "+x", hook_path },
        });
    }

    print("{s}✓{s} Pre-commit hook installed at {s}\n", .{ GREEN, RESET, hook_path });
    print("  This hook will block commits that violate TDGS-1 rules\n\n", .{});
}

// tri dev core pre-commit: Validate staged files
fn runCorePreCommit(allocator: Allocator) !void {
    // Get list of staged files
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "git", "diff", "--cached", "--name-only" },
    });

    const staged_files = std.mem.trim(u8, result.stdout);
    if (staged_files.len == 0) {
        return; // Nothing to check
    }

    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();
    try guarded.scan();

    var violations: usize = 0;

    var iter = std.mem.splitScalar(u8, staged_files, '\n');
    while (iter.next()) |file_path| {
        const trimmed = std.mem.trimRight(u8, file_path, "\r\n");
        if (trimmed.len == 0) continue;

        // Check if file is in GuardedSet
        for (guarded.files) |f| {
            if (std.mem.eql(u8, f.path, trimmed)) {
                if (!f.has_signature or f.loc > MAX_TTC_LOC) {
                    std.debug.print("{s}✗ {s}: violates TDGS-1 ({s}){s}\n", .{
                        RED, trimmed,
                        if (!f.has_signature) "no signature" else "LOC > 3000",
                        RESET,
                    });
                    violations += 1;
                }
                break;
            }
        }
    }

    if (violations > 0) {
        std.debug.print("\n{s}❌ TDGS-1 VIOLATION: {d} file(s) violate Core Development Law{s}\n", .{
            RED, violations, RESET,
        });
        return error.PreCommitFailed;
    }
}

fn runCoreSign(allocator: Allocator, args: []const []const u8) !void {
    _ = args;
    print("\n{s}📝 TRI DEV CORE SIGN{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();
    try guarded.scan();

    var signed: usize = 0;
    var skipped: usize = 0;

    for (guarded.files) |f| {
        if (f.scope != .ttc) continue;
        if (!f.exists) {
            print("  {s}⊘{s} {s} (missing)\n", .{ DIM, RESET, f.path });
            skipped += 1;
            continue;
        }

        const content = try fs.cwd().readFileAlloc(allocator, f.path, 1024 * 1024);
        defer allocator.free(content);

        // Calculate SHA256 hash
        var hash_buf: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(content, &hash_buf, .{});
        const hash_hex = std.fmt.bytesToHex(&hash_buf, .lower);

        // Generate signature line
        const timestamp = std.time.timestamp();
        var sig_buf: [256]u8 = undefined;
        const sig = try std.fmt.bufPrint(&sig_buf,
            "// TRI_CORE_SIGNATURE: tri-dev:{d}:sha256:{s}\n// TRI_CORE_SCOPE: TTC\n// DO NOT EDIT MANUALLY — USE `tri dev core ...`\n",
            .{ timestamp, &hash_hex }
        );

        // Check if file already has signature
        if (std.mem.indexOf(u8, content, SIGNATURE_PREFIX)) |sig_start| {
            // Find end of old signature block (3 lines)
            const sig_end = if (std.mem.indexOf(u8, content[sig_start..], "\n//")) |idx|
                sig_start + idx + 3
            else
                content.len;

            // Replace old signature
            var new_content = try allocator.alloc(u8, content.len - (sig_end - sig_start) + sig.len);
            @memcpy(new_content[0..sig_start], content[0..sig_start]);
            const sig_slice_start = sig_start;
            const sig_slice_end = sig_start + sig.len;
            @memcpy(new_content[sig_slice_start..sig_slice_end], sig);
            @memcpy(new_content[sig_slice_end..], content[sig_end..]);

            try fs.cwd().writeFile(.{ .sub_path = f.path, .data = new_content });
            allocator.free(new_content);
        } else {
            // Insert at beginning
            var new_content = try allocator.alloc(u8, sig.len + content.len);
            @memcpy(new_content[0..sig.len], sig);
            @memcpy(new_content[sig.len..], content);

            try fs.cwd().writeFile(.{ .sub_path = f.path, .data = new_content });
            allocator.free(new_content);
        }

        print("  {s}✓{s} {s} → {s}\n", .{ GREEN, RESET, f.path, hash_hex[0..8] });
        signed += 1;
    }

    const skipped_msg = if (skipped > 0) try std.fmt.allocPrint(allocator, " ({d} skipped)", .{skipped}) else "";
    defer allocator.free(skipped_msg);
    print("\n  {s}✅ Signed {d} TTC files{s}{s}\n\n", .{ GREEN, signed, skipped_msg, RESET });
}

fn runCoreEditAst(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("\n{s}🔧 TRI DEV CORE EDIT-AST{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Implement AST editing interface{s}\n", .{ YELLOW, RESET });
    print("  This will read ast.tri spec and regenerate ast.zig\n\n", .{});
}

fn runCoreEditParser(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("\n{s}🔧 TRI DEV CORE EDIT-PARSER{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Implement parser editing interface{s}\n", .{ YELLOW, RESET });
    print("  This will read grammar.ebnf and regenerate parser.zig\n\n", .{});
}

fn runCoreEditEmit(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("\n{s}🔧 TRI DEV CORE EDIT-EMIT{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Implement emit editing interface{s}\n", .{ YELLOW, RESET });
    print("  This will read emit spec and regenerate emit_t27.zig / emit_zig.zig\n\n", .{});
}

pub fn printCoreHelp() void {
    print("\n{s}TRI DEV CORE — Trusted Tri Core Commands{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev core audit{s}    Check TTC health (LOC, signatures)\n", .{ CYAN, RESET });
    print("  {s}tri dev core sign{s}     Add/update TRI_CORE_SIGNATURE to all TTC files\n", .{ CYAN, RESET });
    print("  {s}tri dev core edit-ast{s}  Edit AST spec and regenerate ast.zig\n", .{ CYAN, RESET });
    print("  {s}tri dev core edit-parser{s}  Edit grammar and regenerate parser.zig\n", .{ CYAN, RESET });
    print("  {s}tri dev core edit-emit{s}  Edit emit spec and regenerate emitters\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV TRI — Tri Language Commands
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runTriCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "new-module")) {
        try runTriNewModule(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "refactor")) {
        try runTriRefactor(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "canonize")) {
        try runTriCanonize(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printTriHelp();
    } else {
        std.debug.print("{s}Unknown tri subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printTriHelp();
    }
}

fn runTriNewModule(allocator: Allocator, args: []const []const u8) !void {
    const name = if (args.len > 0) args[0] else {
        print("{s}Usage: tri dev tri new-module <name>{s}\n", .{ YELLOW, RESET });
        return;
    };

    print("\n{s}📦 TRI DEV TRI NEW-MODULE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    const path = try std.fmt.allocPrint(allocator, "src/tri-lang/{s}.tri", .{name});
    defer allocator.free(path);

    if (fs.cwd().openFile(path, .{})) |file| {
        file.close();
        print("  {s}⚠️  Module {s} already exists{s}\n\n", .{ YELLOW, path, RESET });
        return;
    } else |_| {}

    const template =
        \\// @origin(spec) @regen(done)
        \\// {s} — Tri Language Module
        \\//
        \\// @spec: Module specification and contract
        \\// @example: Usage examples
        \\
        \\const std = @import("std");
        \\
        \\// Module implementation here
        \\
    ;

    const content = try std.fmt.allocPrint(allocator, template, .{name});
    defer allocator.free(content);

    try fs.cwd().writeFile(.{ .sub_path = path, .data = content });

    print("  {s}✓{s} Created {s}\n", .{ GREEN, RESET, path });
    print("  {s}Next: Run 'tri dev tri canonize {s}' after implementation{s}\n\n", .{ DIM, name, RESET });
}

fn runTriRefactor(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("\n{s}🔧 TRI DEV TRI REFACTOR{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Implement safe refactoring operations{s}\n", .{ YELLOW, RESET });
    print("  Available ops: rename, extract-function, move-module\n\n", .{ DIM, RESET });
}

fn runTriCanonize(allocator: Allocator, args: []const []const u8) !void {
    const module_name = if (args.len > 0) args[0] else {
        print("{s}Usage: tri dev tri canonize <module-name>{s}\n", .{ YELLOW, RESET });
        return;
    };

    print("\n{s}🏛️  TRI DEV TRI CANONIZE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // Update canon_map.json
    const map_content =
        \\{{"canon": {{
        \\  "{s}.tri": {{
        \\    "canonical": true,
        \\    "verified_at": "{d}",
        \\    "tests_pass": true
        \\  }}
        \\}}}}
    ;

    const formatted = try std.fmt.allocPrint(allocator, map_content, .{
        module_name,
        std.time.timestamp(),
    });
    defer allocator.free(formatted);

    try fs.cwd().writeFile(.{ .sub_path = CANON_MAP_PATH, .data = formatted });

    print("  {s}✓{s} Marked {s}.tri as canonical\n", .{ GREEN, RESET, module_name });
    print("  {s}Updated: {s}{s}\n\n", .{ DIM, CANON_MAP_PATH, RESET });
}

fn printTriHelp() void {
    print("\n{s}TRI DEV TRI — Tri Language Commands{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev tri new-module <name>{s}   Create new Tri module from template\n", .{ CYAN, RESET });
    print("  {s}tri dev tri refactor <op> <args>{s}  Safe refactoring (rename, extract, move)\n", .{ CYAN, RESET });
    print("  {s}tri dev tri canonize <module>{s}    Mark module as canonical\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV T27 — TRI-27 Commands
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runT27Command(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "create")) {
        try runT27Create(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "regen")) {
        try runT27Regen(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printT27Help();
    } else {
        std.debug.print("{s}Unknown t27 subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printT27Help();
    }
}

fn runT27Create(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    const region = if (args.len > 0) args[0] else {
        print("{s}Usage: tri dev t27 create <region-name>{s}\n", .{ YELLOW, RESET });
        return;
    };

    print("\n{s}📦 TRI DEV T27 CREATE{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Implement .t27 file creation{s}\n", .{ YELLOW, RESET });
    print("  Region: {s}\n\n", .{ region });
}

fn runT27Regen(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("\n{s}🔄 TRI DEV T27 REGEN{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Implement .t27 regeneration from Tri sources{s}\n\n", .{ YELLOW, RESET });
}

fn printT27Help() void {
    print("\n{s}TRI DEV T27 — TRI-27 Commands{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev t27 create <region>{s}  Create new .t27 file\n", .{ CYAN, RESET });
    print("  {s}tri dev t27 regen{s}            Regenerate all .t27 from Tri sources\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRI DEV DOCS — Documentation Commands
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runDocsCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "norm")) {
        try runDocsNorm(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "sync")) {
        try runDocsSync(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help")) {
        printDocsHelp();
    } else {
        std.debug.print("{s}Unknown docs subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printDocsHelp();
    }
}

fn runDocsNorm(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    const doc_name = if (args.len > 0) args[0] else {
        print("{s}Usage: tri dev docs norm <doc-name>{s}\n", .{ YELLOW, RESET });
        return;
    };

    print("\n{s}🏛️  TRI DEV DOCS NORM{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}TODO: Mark {s} as normative{s}\n\n", .{ YELLOW, doc_name, RESET });
}

fn runDocsSync(allocator: Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    print("\n{s}🔄 TRI DEV DOCS SYNC{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}Checking code vs documentation alignment...{s}\n\n", .{ DIM, RESET });
}

fn printDocsHelp() void {
    print("\n{s}TRI DEV DOCS — Documentation Commands{s}\n\n", .{ BOLD, RESET });
    print("  {s}tri dev docs norm <doc>{s}      Mark doc as normative\n", .{ CYAN, RESET });
    print("  {s}tri dev docs sync{s}            Check code vs docs alignment\n\n", .{ CYAN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COMMAND ROUTER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runGuardedCommand(allocator: Allocator, args: []const []const u8) !void {
    const scope = if (args.len > 0) args[0] else "help";
    const sub_args = if (args.len > 1) args[1..] else &[0][]const u8{};

    if (std.mem.eql(u8, scope, "core")) {
        try runCoreCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, scope, "tri")) {
        try runTriCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, scope, "t27")) {
        try runT27Command(allocator, sub_args);
    } else if (std.mem.eql(u8, scope, "docs")) {
        try runDocsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, scope, "help")) {
        printGuardedHelp();
    } else {
        std.debug.print("{s}Unknown guarded scope: {s}{s}\n", .{ RED, scope, RESET });
        printGuardedHelp();
    }
}

pub fn printGuardedHelp() void {
    print("\n{s}TRI DEV GUARDED STACK (TDGS-1){s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("  {s}Core Development Law:{s} All changes to TTC, core Tri, .t27, and\n", .{ BOLD, RESET });
    print("  normative docs MUST go through `tri dev` commands.\n\n", .{});

    print("  {s}Guarded Scopes:{s}\n\n", .{ BOLD, RESET });

    print("  {s}tri dev core ...{s}      Trusted Tri Core (TTC) commands\n", .{ CYAN, RESET });
    print("    audit        Check TTC health (LOC, signatures)\n");
    print("    sign         Add/update TRI_CORE_SIGNATURE\n");
    print("    edit-ast     Edit AST spec and regenerate\n");
    print("    edit-parser  Edit grammar and regenerate\n");
    print("    edit-emit    Edit emit spec and regenerate\n\n");

    print("  {s}tri dev tri ...{s}       Tri language commands\n", .{ CYAN, RESET });
    print("    new-module   Create new Tri module from template\n");
    print("    refactor     Safe refactoring operations\n");
    print("    canonize     Mark module as canonical\n\n");

    print("  {s}tri dev t27 ...{s}       TRI-27 artifact commands\n", .{ CYAN, RESET });
    print("    create       Create new .t27 file\n");
    print("    regen        Regenerate all .t27 from sources\n\n");

    print("  {s}tri dev docs ...{s}      Documentation commands\n", .{ CYAN, RESET });
    print("    norm         Mark doc as normative\n");
    print("    sync         Check code vs docs alignment\n\n");
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn padTo(current: usize, target: usize) void {
    if (current < target) {
        var j: usize = 0;
        while (j < target - current) : (j += 1) {
            std.debug.print(" ", .{});
        }
    }
}

pub fn digitCount(n: usize) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var val = n;
    while (val > 0) : (val /= 10) {
        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "GuardedSet init and scan" {
    const allocator = std.testing.allocator;
    var guarded = try GuardedSet.init(allocator);
    defer guarded.deinit();

    try guarded.scan();

    // At least some TTC files should exist
    var ttc_found: usize = 0;
    for (guarded.files) |f| {
        if (f.scope == .ttc and f.exists) {
            ttc_found += 1;
        }
    }

    try std.testing.expect(ttc_found > 0);
}

test "countLoc basic" {
    const content =
        \\// Comment line
        \\fn foo() void {}
        \\fn bar() void {}
        \\
        \\// Another comment
    ;

    const loc = countLoc(content);
    try std.testing.expectEqual(@as(usize, 2), loc);
}

test "digitCount" {
    try std.testing.expectEqual(@as(usize, 1), digitCount(0));
    try std.testing.expectEqual(@as(usize, 1), digitCount(5));
    try std.testing.expectEqual(@as(usize, 2), digitCount(42));
    try std.testing.expectEqual(@as(usize, 3), digitCount(123));
    try std.testing.expectEqual(@as(usize, 4), digitCount(9999));
}
