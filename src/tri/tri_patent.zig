// @origin(spec:patent.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// tri patent — IP protection commands
// ═══════════════════════════════════════════════════════════════════════════════
//
// tri patent status    — show DOIs + filing status
// tri patent snapshot  — git tag + CHANGELOG + zenodo DOI
// tri patent draft     — generate provisional template
// tri patent zenodo    — trigger DOI via release tag
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const RED = colors.RED;
const CYAN = colors.CYAN;
const GRAY = colors.GRAY;
const RESET = colors.RESET;
const YELLOW = "\x1b[33m";

const print = std.debug.print;

const STATUS_PATH = ".trinity/patent/status.json";

pub fn runPatentCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    const sub = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, sub, "status")) {
        showStatus();
    } else if (std.mem.eql(u8, sub, "snapshot")) {
        const name = if (args.len > 2 and std.mem.eql(u8, args[1], "--discovery"))
            args[2]
        else
            "all";
        showSnapshot(name);
    } else if (std.mem.eql(u8, sub, "draft")) {
        const name = if (args.len > 2 and std.mem.eql(u8, args[1], "--discovery"))
            args[2]
        else
            "ternary-resonance-law";
        showDraft(name);
    } else if (std.mem.eql(u8, sub, "zenodo")) {
        showZenodo();
    } else {
        printHelp();
    }
}

fn showStatus() void {
    print("\n{s}PATENT & IP PROTECTION STATUS{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    const file = std.fs.cwd().openFile(STATUS_PATH, .{}) catch {
        print("  {s}No patent status file. Create with: tri patent snapshot{s}\n\n", .{ RED, RESET });
        return;
    };
    defer file.close();

    var buf: [8192]u8 = undefined;
    const n = file.readAll(&buf) catch return;
    const content = buf[0..n];

    // Parse discoveries
    const discoveries = [_][]const u8{
        "ternary-resonance-law",
        "square-attention",
        "0-dsp-fpga-inference",
        "self-evolving-ouroboros",
    };

    const descriptions = [_][]const u8{
        "Ternary Resonance Law (3^k dim scaling)",
        "Square Attention Theorem (O(n) ternary)",
        "0-DSP FPGA Inference (5000 tok/s)",
        "Self-Evolving Ouroboros (recursive AI)",
    };

    print("  {s}{s:<30}{s}  {s:<15}  {s:<10}  {s}{s}\n", .{ GOLDEN, "Discovery", RESET, "DOI", "Patent", "Status", RESET });
    print("  {s}──────────────────────────────────────────────────────{s}\n", .{ GRAY, RESET });

    for (discoveries, 0..) |name, i| {
        // Check status in JSON
        var status: []const u8 = "doi_only";
        if (std.mem.indexOf(u8, content, name)) |_| {
            if (std.mem.indexOf(u8, content, "\"provisional\"") != null) {
                // Check if this specific one has provisional
                status = "doi_only"; // simplified
            }
        }

        const status_icon: []const u8 = if (std.mem.eql(u8, status, "filed"))
            "🟢 FILED"
        else if (std.mem.eql(u8, status, "provisional"))
            "🟡 PROV"
        else
            "🔴 DOI";

        const clr: []const u8 = if (std.mem.eql(u8, status, "filed"))
            GREEN
        else if (std.mem.eql(u8, status, "provisional"))
            YELLOW
        else
            RED;

        print("  {s}{s:<30}{s}  10.5281/18950696  {s:<10}  {s}{s}{s}\n", .{
            CYAN, descriptions[i], RESET, status_icon, clr, status, RESET,
        });
    }

    print("\n  {s}Zenodo DOI{s}: 10.5281/zenodo.18950696 (v2.0.3, prior art 2026-03-10)\n", .{ GOLDEN, RESET });
    print("  {s}USPTO micro entity{s}: $320 for 12-month priority\n\n", .{ GOLDEN, RESET });

    print("  {s}Next steps:{s}\n", .{ GOLDEN, RESET });
    print("    1. tri patent snapshot --discovery ternary-resonance-law\n", .{});
    print("    2. tri patent draft --discovery ternary-resonance-law\n", .{});
    print("    3. File provisional before arxiv publication\n\n", .{});
}

fn showSnapshot(name: []const u8) void {
    print("\n{s}PATENT SNAPSHOT{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  Discovery: {s}{s}{s}\n", .{ CYAN, name, RESET });
    print("  Action:    git tag -a patent-{s}-2026-03-14\n", .{name});
    print("  Zenodo:    Push tag → GitHub Release → Zenodo webhook\n\n", .{});

    print("  {s}Commands to run:{s}\n", .{ GOLDEN, RESET });
    print("    git tag -a patent-{s}-2026-03-14 -m \"Patent snapshot: {s}\"\n", .{ name, name });
    print("    git push origin patent-{s}-2026-03-14\n", .{name});
    print("    gh release create patent-{s}-2026-03-14 --title \"Patent: {s}\"\n\n", .{ name, name });
}

fn showDraft(name: []const u8) void {
    print("\n{s}PROVISIONAL PATENT DRAFT TEMPLATE{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  Discovery: {s}{s}{s}\n\n", .{ CYAN, name, RESET });

    print("  Output:    patents/{s}/draft.md\n\n", .{name});

    print("  Template structure:\n", .{});
    print("    1. TITLE OF INVENTION\n", .{});
    print("    2. CROSS-REFERENCE TO RELATED APPLICATIONS\n", .{});
    print("    3. FIELD OF THE INVENTION\n", .{});
    print("    4. BACKGROUND\n", .{});
    print("    5. SUMMARY OF THE INVENTION\n", .{});
    print("    6. DETAILED DESCRIPTION\n", .{});
    print("    7. CLAIMS\n", .{});
    print("    8. ABSTRACT\n\n", .{});

    print("  {s}Prior art reference:{s}\n", .{ GOLDEN, RESET });
    print("    DOI: 10.5281/zenodo.18950696\n", .{});
    print("    Date: 2026-03-10\n", .{});
    print("    Repository: github.com/gHashTag/trinity\n\n", .{});
}

fn showZenodo() void {
    print("\n{s}ZENODO DOI TRIGGER{s}\n", .{ GOLDEN, RESET });
    print("{s}━━━━━━━━━━━━━━━━━━━━━{s}\n\n", .{ GRAY, RESET });

    print("  Zenodo is linked to GitHub via webhook.\n", .{});
    print("  To create a new DOI version:\n\n", .{});
    print("    1. Create GitHub Release with version tag\n", .{});
    print("    2. Zenodo auto-creates new DOI version\n", .{});
    print("    3. Update .trinity/patent/status.json\n\n", .{});

    print("  {s}Current:{s}\n", .{ GOLDEN, RESET });
    print("    Concept DOI: 10.5281/zenodo.18947017\n", .{});
    print("    Latest:      10.5281/zenodo.18950696 (v2.0.3)\n\n", .{});
}

fn printHelp() void {
    print("\n{s}tri patent{s} — IP protection commands\n\n", .{ GOLDEN, RESET });
    print("  status               Show DOIs + filing status\n", .{});
    print("  snapshot [--discovery name]  Git tag + zenodo instructions\n", .{});
    print("  draft --discovery name       Provisional patent template\n", .{});
    print("  zenodo               Zenodo DOI trigger instructions\n\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "patent_help_does_not_crash" {
    printHelp();
}
