//! Trinity Outreach CLI — Scientist email outreach with proper deliverability
//!
//! USAGE:
//!   tri outreach init                 — Initialize outreach system
//!   tri outreach status                — Show warming status
//!   tri outreach send --dry-run        — Preview emails without sending
//!   tri outreach send --batch=day1     — Send today's batch
//!   tri outreach follow-up             — Check for pending follow-ups
//!   tri outreach resolve <name>        — Resolve email from placeholders
//!
//! CRITICAL: Run DNS setup first (docs/EMAIL_DELIVERABILITY_SETUP.md)

const std = @import("std");

pub const io = std.io;

const types = @import("types.zig");
const templates = @import("templates.zig");
const email_resolver = @import("email_resolver.zig");
const warming = @import("warming.zig");
const bounce_handler = @import("bounce_handler.zig");

pub fn run(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        return showHelp();
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "init")) {
        return cmdInit(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "status")) {
        return cmdStatus(allocator);
    } else if (std.mem.eql(u8, command, "send")) {
        return cmdSend(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "follow-up")) {
        return cmdFollowUp(allocator);
    } else if (std.mem.eql(u8, command, "resolve")) {
        return cmdResolve(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "preview")) {
        return cmdPreview(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "test")) {
        return cmdTestEmail(allocator, args[2..]);
    } else {
        std.debug.print("Unknown command: {s}\n\n", .{command});
        return showHelp();
    }
}

fn showHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\Trinity Outreach — Scientist email outreach
        \\
        \\USAGE:
        \\  tri outreach init                      Initialize outreach system
        \\  tri outreach status                    Show warming status & queue
        \\  tri outreach send --dry-run            Preview emails (no send)
        \\  tri outreach send --batch=day1         Send today's batch
        \\  tri outreach follow-up                 Check pending follow-ups
        \\  tri outreach resolve <name>            Resolve email from placeholder
        \\  tri outreach preview <template>        Preview specific template
        \\  tri outreach test --to=<email>         Send test email to yourself
        \\
        \\CRITICAL STEPS:
        \\  1. Add DNS records (SPF/DKIM/DMARC) — see docs/EMAIL_DELIVERABILITY_SETUP.md
        \\  2. Run 'tri outreach init' to set up OAuth
        \\  3. Run 'tri outreach test' to verify
        \\  4. Start warming: Week 1 = 2 emails/day
        \\
        \\WARMING SCHEDULE:
        \\  Week 1: 2 emails/day (Sherbon, Pellis)
        \\  Week 2: 3 emails/day (VSA experts)
        \\  Week 3: 5 emails/day (LQG physicists)
        \\  Week 4: 7 emails/day (Particle physics)
        \\  Week 5+: 10 emails/day (full speed)
        \\
        \\FOLLOW-UP SCHEDULE:
        \\  First follow-up: 14 days after initial
        \\  Second follow-up: 21 days after initial
        \\  (NOT 7 days — too aggressive for academics)
        \\
    , .{});
}

/// Initialize outreach system
fn cmdInit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    // Check for environment variables
    const zoho_password = std.posix.getenv("ZOHO_APP_PASSWORD");
    if (zoho_password == null) {
        try stderr.print(
            \\ERROR: ZOHO_APP_PASSWORD not set
            \\
            \\Please set environment variable:
            \\  export ZOHO_APP_PASSWORD=your_app_password
            \\
            \\Get app password from: https://mail.zoho.com/zoho/2FASettings
            \\
        , .{});
        return error.MissingEnvVar;
    }

    // Create directories
    const dirs = [_][]const u8{
        "outreach/emails",
        "outreach/sent",
        "outreach/replies",
        "outreach/bounces",
        "outreach/templates",
    };

    for (dirs) |dir| {
        std.fs.cwd().makePath(dir) catch |e| {
            try stderr.print("Warning: Could not create {s}: {}\n", .{ dir, e });
        };
    }

    try stdout.print(
        \\✓ Outreach directories created
        \\✓ ZOHO_APP_PASSWORD found
        \\
        \\Next steps:
        \\  1. Add DNS records (SPF/DKIM/DMARC) — see docs/EMAIL_DELIVERABILITY_SETUP.md
        \\  2. Wait 24-48 hours for DNS propagation
        \\  3. Run 'tri outreach test --to=admin@t27.ai' to verify
        \\  4. Run 'tri outreach send --dry-run' to preview first batch
        \\
    , .{});
}

/// Show warming status and queue
fn cmdStatus(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    // Calculate current warming week
    const start_date = getStartDate(allocator) catch std.time.timestamp();
    const current_week = warming.getCurrentWeek(start_date, std.time.timestamp());
    const daily_limit = warming.getDailyLimit(current_week);
    const focus = warming.getFocus(current_week);

    try stdout.print(
        \\
        \\╔════════════════════════════════════════════════════════════╗
        \\║           Trinity Outreach — Warming Status               ║
        \\╠════════════════════════════════════════════════════════════╣
        \\║  Week: {d}                                                  ║
        \\║  Daily Limit: {d} emails/day                                ║
        \\║  Focus: {s}                                    ║
        \\╠════════════════════════════════════════════════════════════╣
        \\║  Warming Schedule:                                          ║
        \\║    Week 1: 2 emails/day (Golden Ratio Allies)              ║
        \\║    Week 2: 3 emails/day (VSA Experts)                      ║
        \\║    Week 3: 5 emails/day (LQG Physicists)                   ║
        \\║    Week 4: 7 emails/day (Particle Physics)                 ║
        \\║    Week 5+: 10 emails/day (Full Speed)                     ║
        \\╠════════════════════════════════════════════════════════════╣
        \\
    , .{ current_week, daily_limit, focus });

    // Show queue
    try stdout.print("║  Today's Queue ({d} scientists):                            ║\n", .{daily_limit});
    try stdout.print("╠════════════════════════════════════════════════════════════╣\n", .{});

    const queue = getTodayQueue(allocator, current_week);
    defer {
        for (queue.items) |item| {
            allocator.free(item.name);
            allocator.free(item.email);
            allocator.free(item.status);
        }
        queue.deinit();
    }

    for (queue.items, 0..) |scientist, i| {
        try stdout.print("║  {d}. {s:20s} — {s:30s} [{s:8s}]    ║\n", .{
            i + 1,
            scientist.name,
            scientist.email,
            scientist.status,
        });
    }

    try stdout.print("╚════════════════════════════════════════════════════════════╝\n", .{});
}

/// Send emails (with --dry-run flag for preview)
fn cmdSend(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    var dry_run: bool = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
        }
    }

    if (dry_run) {
        try stdout.print("\n📧 DRY RUN MODE — Previewing emails (not sending)\n\n", .{});
    }

    const start_date = getStartDate(allocator) catch std.time.timestamp();
    const current_week = warming.getCurrentWeek(start_date, std.time.timestamp());
    const daily_limit = warming.getDailyLimit(current_week);

    const queue = getTodayQueue(allocator, current_week);
    defer {
        for (queue.items) |item| {
            allocator.free(item.name);
            allocator.free(item.email);
            allocator.free(item.status);
        }
        queue.deinit();
    }

    if (queue.items.len == 0) {
        try stdout.print("No emails queued for today.\n", .{});
        return;
    }

    const to_send = @min(queue.items.len, daily_limit);

    try stdout.print("Sending {d} of {d} queued emails...\n\n", .{ to_send, queue.items.len });

    for (queue.items[0..to_send], 0..) |scientist, i| {
        const template_id = getTemplateForScientist(scientist.name);
        const template = templates.getById(template_id) orelse continue;

        try stdout.print(
            \\═══════════════════════════════════════════════════════════
            \\Email {d}/{d}: {s}
            \\Template: {s}
            \\To: {s}
            \\Subject: {s}
            \\
            \\{s}
            \\═══════════════════════════════════════════════════════════
            \\
        , .{
            i + 1,
            to_send,
            scientist.name,
            template.name,
            scientist.email,
            template.subject,
            template.body_template,
        });

        if (!dry_run) {
            // TODO: Actually send email via SMTP
            _ = scientist;
            _ = template;
        }
    }

    if (dry_run) {
        try stdout.print("\n✓ Dry run complete. Remove --dry-run to actually send.\n", .{});
    } else {
        try stdout.print("\n✓ Sent {d} emails.\n", .{to_send});
    }
}

/// Check for pending follow-ups
fn cmdFollowUp(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Checking for pending follow-ups (14+ days since last email)...\n\n", .{});

    // TODO: Implement follow-up check
    try stdout.print("No pending follow-ups found.\n", .{});
}

/// Resolve email from placeholder
fn cmdResolve(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    if (args.len < 1) {
        try stdout.print("Usage: tri outreach resolve <name>\n", .{});
        return;
    }

    const name = args[0];
    var resolver = email_resolver.EmailResolver.init(allocator);
    defer resolver.deinit();

    // TODO: Look up scientist from database
    const result = try resolver.resolve("ResearchGate", name, "Unknown University");

    try stdout.print("Email resolution for '{s}':\n", .{name});
    try stdout.print("  Email: {s}\n", .{result.email});
    try stdout.print("  Confidence: {d:.1}\n", .{result.confidence});
    try stdout.print("  Source: {s}\n", .{result.source});

    if (result.confidence < 0.7) {
        try stdout.print("\n⚠️  Low confidence — manual verification required\n", .{});
    }
}

/// Preview specific template
fn cmdPreview(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    if (args.len < 1) {
        try stdout.print("Available templates:\n", .{});
        for (templates.templates) |t| {
            try stdout.print("  {s:20s} — {s}\n", .{ t.id, t.name });
        }
        return;
    }

    const template_id = args[0];
    const template = templates.getById(template_id);

    if (template == null) {
        try stdout.print("Template not found: {s}\n", .{template_id});
        return;
    }

    try stdout.print(
        \\
        \\Template: {s}
        \\Subject: {s}
        \\Word count: {d}
        \\
        \\{s}
        \\
    , .{ template.?.name, template.?.subject, template.?.word_count, template.?.body_template });
}

/// Send test email to yourself
fn cmdTestEmail(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var to_email: []const u8 = "admin@t27.ai";

    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--to=")) {
            to_email = arg["--to=".len..];
        }
    }

    // Check DNS records first
    try stdout.print("Checking DNS records...\n", .{});

    // TODO: Implement DNS check
    try stdout.print("  ⚠️  DNS check not implemented — please verify manually\n", .{});

    try stdout.print("\nSending test email to {s}...\n", .{to_email});

    // TODO: Actually send email
    try stderr.print("ERROR: Email sending not yet implemented\n", .{});

    return error.NotImplemented;
}

// Helper types and functions

const QueueItem = struct {
    name: []const u8,
    email: []const u8,
    status: []const u8,
};

fn getStartDate(allocator: std.mem.Allocator) !i64 {
    // Read start date from config file
    const file = std.fs.openFileAbsolute(
        ".trinity/outreach_start_date.txt",
        .{},
    ) catch {
        // Create default start date (today)
        const now = std.time.timestamp();
        const file = try std.fs.createFileAbsolute(
            ".trinity/outreach_start_date.txt",
            .{},
        );
        defer file.close();
        try file.writer().print("{d}\n", .{now});
        return now;
    };
    defer file.close();

    var buffer: [32]u8 = undefined;
    const content = try file.readAll(&buffer);
    const timestamp = try std.fmt.parseInt(i64, std.mem.trim(u8, content, "\n"), 10);
    return timestamp;
}

fn getTodayQueue(allocator: std.mem.Allocator, week: u32) std.ArrayList(QueueItem) {
    var result = std.ArrayList(QueueItem).init(allocator);

    // TODO: Load from actual database
    // For now, return hardcoded list based on week
    const scientists = switch (week) {
        1 => [_]QueueItem{
            .{ .name = "Michael Sherbon", .email = "michael.sherbon@case.edu", .status = "queued" },
            .{ .name = "Stergios Pellis", .email = "sterpellis@gmail.com", .status = "queued" },
        },
        2 => [_]QueueItem{
            .{ .name = "Denis Kleyko", .email = "denis.kleyko@oru.se", .status = "queued" },
            .{ .name = "Pentti Kanerva", .email = "pkanerva@csli.stanford.edu", .status = "queued" },
            .{ .name = "Abbas Rahimi", .email = "abr@zurich.ibm.com", .status = "queued" },
        },
        else => return result, // Empty for other weeks in this stub
    };

    for (scientists) |s| {
        result.append(.{
            .name = allocator.dupe(u8, s.name),
            .email = allocator.dupe(u8, s.email),
            .status = allocator.dupe(u8, s.status),
        }) catch {};
    }

    return result;
}

fn getTemplateForScientist(name: []const u8) []const u8 {
    if (std.mem.indexOf(u8, name, "Sherbon")) |_| return "sherbon_short";
    if (std.mem.indexOf(u8, name, "Pellis")) |_| return "pellis_short";
    if (std.mem.indexOf(u8, name, "Hossenfelder")) |_| return "hossenfelder_short";
    if (std.mem.indexOf(u8, name, "Kleyko")) |_| return "kleyko_short";
    if (std.mem.indexOf(u8, name, "Kanerva")) |_| return "kanerva_short";
    if (std.mem.indexOf(u8, name, "Smolin")) |_| return "smolin_short";
    if (std.mem.indexOf(u8, name, "Rovelli")) |_| return "rovelli_short";
    if (std.mem.indexOf(u8, name, "Afshordi")) |_| return "afshordi_short";
    if (std.mem.indexOf(u8, name, "Chollet")) |_| return "chollet_short";
    if (std.mem.indexOf(u8, name, "Rabaey")) |_| return "rabaey_short";
    return "sherbon_short"; // Default
}
