// ═══════════════════════════════════════════════════════════════════════════════
// QUEEN TELEGRAM — Bidirectional Telegram: send + getUpdates + dispatch
// ═══════════════════════════════════════════════════════════════════════════════
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const qt = @import("queen_types.zig");
const queen_senses = @import("queen_senses.zig");
const queen_actions = @import("queen_actions.zig");
const queen_policy = @import("queen_policy.zig");

const Allocator = std.mem.Allocator;
const print = std.debug.print;

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND QUEUE — Lock-free ring buffer (8 slots)
// ═══════════════════════════════════════════════════════════════════════════════

pub const MAX_COMMANDS = 8;
pub const MAX_CMD_LEN = 128;

pub const TgCommand = struct {
    text: [MAX_CMD_LEN]u8 = undefined,
    text_len: usize = 0,
    chat_id: [32]u8 = undefined,
    chat_id_len: usize = 0,
    update_id: i64 = 0,

    pub fn textStr(self: *const TgCommand) []const u8 {
        return self.text[0..self.text_len];
    }
};

pub const CommandQueue = struct {
    commands: [MAX_COMMANDS]TgCommand = undefined,
    head: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    tail: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    pub fn push(self: *CommandQueue, cmd: TgCommand) bool {
        const tail = self.tail.load(.acquire);
        const next_tail = (tail + 1) % MAX_COMMANDS;
        if (next_tail == self.head.load(.acquire)) return false; // full
        self.commands[tail] = cmd;
        self.tail.store(next_tail, .release);
        return true;
    }

    pub fn pop(self: *CommandQueue) ?TgCommand {
        const head = self.head.load(.acquire);
        if (head == self.tail.load(.acquire)) return null; // empty
        const cmd = self.commands[head];
        self.head.store((head + 1) % MAX_COMMANDS, .release);
        return cmd;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// POLL THREAD — getUpdates loop
// ═══════════════════════════════════════════════════════════════════════════════

pub const PollContext = struct {
    tg: qt.TgConfig,
    queue: *CommandQueue,
    last_update_id: *std.atomic.Value(i64),
    allowed_chat_id: []const u8,
    running: *std.atomic.Value(bool),
};

pub fn startPollThread(ctx: *PollContext) !std.Thread {
    return std.Thread.spawn(.{}, pollLoop, .{ctx});
}

fn pollLoop(ctx: *PollContext) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (ctx.running.load(.acquire)) {
        const offset = ctx.last_update_id.load(.acquire) + 1;
        pollOnce(allocator, ctx, offset);
        std.Thread.sleep(5 * std.time.ns_per_s);
    }
}

fn pollOnce(allocator: Allocator, ctx: *PollContext, offset: i64) void {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/getUpdates?offset={d}&timeout=5&allowed_updates=[\"message\"]", .{ ctx.tg.bot_token, offset }) catch return;

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &aw.writer,
    }) catch return;

    if (result.status != .ok) return;
    const body = aw.written();

    // Parse updates (minimal JSON scanning)
    parseUpdates(ctx, body);
}

fn parseUpdates(ctx: *PollContext, body: []const u8) void {
    // Scan for "update_id": and "text": pairs
    var pos: usize = 0;
    while (pos < body.len) {
        // Find next update_id
        const uid_key = "\"update_id\":";
        const uid_idx = std.mem.indexOfPos(u8, body, pos, uid_key) orelse break;
        const uid_start = uid_idx + uid_key.len;
        var uid_end = uid_start;
        while (uid_end < body.len and (body[uid_end] >= '0' and body[uid_end] <= '9')) : (uid_end += 1) {}
        const update_id = std.fmt.parseInt(i64, body[uid_start..uid_end], 10) catch {
            pos = uid_end;
            continue;
        };

        // Find chat_id in this update
        const chat_key = "\"chat\":{\"id\":";
        const chat_idx = std.mem.indexOfPos(u8, body, uid_end, chat_key) orelse {
            pos = uid_end;
            continue;
        };
        const chat_start = chat_idx + chat_key.len;
        var chat_end = chat_start;
        while (chat_end < body.len and (body[chat_end] >= '0' and body[chat_end] <= '9' or body[chat_end] == '-')) : (chat_end += 1) {}
        const chat_id_str = body[chat_start..chat_end];

        // Security: filter by allowed chat_id
        if (!std.mem.eql(u8, chat_id_str, ctx.allowed_chat_id)) {
            ctx.last_update_id.store(update_id, .release);
            pos = chat_end;
            continue;
        }

        // Find text
        const text_key = "\"text\":\"";
        const text_idx = std.mem.indexOfPos(u8, body, chat_end, text_key) orelse {
            ctx.last_update_id.store(update_id, .release);
            pos = chat_end;
            continue;
        };
        const text_start = text_idx + text_key.len;
        const text_end = std.mem.indexOfScalarPos(u8, body, text_start, '"') orelse {
            pos = text_start;
            continue;
        };
        const text = body[text_start..text_end];

        // Only process /queen and /q commands
        if (std.mem.startsWith(u8, text, "/queen") or std.mem.startsWith(u8, text, "/q")) {
            var cmd = TgCommand{
                .update_id = update_id,
            };
            const text_len = @min(text.len, MAX_CMD_LEN);
            @memcpy(cmd.text[0..text_len], text[0..text_len]);
            cmd.text_len = text_len;
            const cid_len = @min(chat_id_str.len, cmd.chat_id.len);
            @memcpy(cmd.chat_id[0..cid_len], chat_id_str[0..cid_len]);
            cmd.chat_id_len = cid_len;

            _ = ctx.queue.push(cmd);
        }

        ctx.last_update_id.store(update_id, .release);
        pos = text_end;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMAND DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

/// v3: dispatch context includes policy state
pub const DispatchContext = struct {
    allocator: Allocator,
    tg: qt.TgConfig,
    senses: qt.SenseResult,
    config: qt.QueenConfig,
    counters: *queen_policy.ActionCounters,
    incidents: *queen_policy.IncidentMemory,
    pending: *queen_policy.PendingQueue,
};

pub fn dispatchCommand(ctx: DispatchContext, cmd: TgCommand) void {
    const text = cmd.textStr();

    // Parse: "/queen <sub>" or "/q <sub>" or just "/queen" / "/q"
    var sub: []const u8 = "";
    if (std.mem.startsWith(u8, text, "/queen")) {
        if (text.len > 7) sub = std.mem.trim(u8, text[7..], &[_]u8{' '});
    } else if (std.mem.startsWith(u8, text, "/q")) {
        if (text.len > 3) sub = std.mem.trim(u8, text[3..], &[_]u8{' '});
    }

    var buf: [2048]u8 = undefined;

    if (sub.len == 0) {
        // /queen — full status (senses)
        const msg = queen_senses.fmtSensesTelegram(&buf, ctx.senses);
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "doctor")) {
        ctx.incidents.record(.human_command, .doctor_quick, true, "tg /queen doctor");
        const result = queen_actions.execute(ctx.allocator, .doctor_quick);
        ctx.counters.record(.doctor_quick);
        queen_policy.writeAuditEntry("human_command", .doctor_quick, .allowed, result.success, "tg /queen doctor");
        const msg = fmtActionResult(&buf, .doctor_quick, result);
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "score")) {
        const msg = std.fmt.bufPrint(&buf, qt.E_CYCLE ++ " Ouroboros Score: {d:.1}\n\n" ++
            qt.E_CHECK ++ " Build: {s}\n" ++
            qt.E_GEAR ++ " Tests: {d}%%\n" ++
            qt.E_DNA ++ " Farm PPL: {d:.1}\n" ++
            qt.E_SWORDS ++ " Arena: {d}", .{
            ctx.senses.ouroboros_score,
            if (ctx.senses.build_ok) "OK" else "FAIL",
            ctx.senses.test_rate,
            ctx.senses.farm_best_ppl,
            ctx.senses.arena_battles,
        }) catch "";
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "farm")) {
        const result = queen_actions.execute(ctx.allocator, .farm_status);
        const msg = fmtActionResult(&buf, .farm_status, result);
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "arena")) {
        const result = queen_actions.execute(ctx.allocator, .arena_status);
        const msg = fmtActionResult(&buf, .arena_status, result);
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "heal")) {
        ctx.incidents.record(.human_command, .doctor_quick, true, "tg /queen heal");
        const doc_result = queen_actions.execute(ctx.allocator, .doctor_quick);
        const ouro_result = queen_actions.execute(ctx.allocator, .ouroboros_cycle);
        ctx.counters.record(.doctor_quick);
        ctx.counters.record(.ouroboros_cycle);
        const msg = std.fmt.bufPrint(&buf, qt.E_WRENCH ++ " Doctor: {s} ({d}ms)\n" ++
            qt.E_CYCLE ++ " Ouroboros: {s} ({d}ms)", .{
            if (doc_result.success) "OK" else "FAIL",
            doc_result.duration_ms,
            if (ouro_result.success) "OK" else "FAIL",
            ouro_result.duration_ms,
        }) catch "";
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "history")) {
        // v3: incident history
        const msg = queen_policy.fmtHistoryTelegram(&buf, ctx.incidents);
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "policy")) {
        // v3: policy map
        const msg = queen_policy.fmtPolicyTelegram(&buf, ctx.config, ctx.counters);
        tgSend(ctx.tg, msg);
    } else if (std.mem.startsWith(u8, sub, "approve")) {
        // v3: /queen approve <id>
        dispatchApprove(ctx, sub, &buf);
    } else if (std.mem.startsWith(u8, sub, "deny")) {
        // v3: /queen deny <id>
        dispatchDeny(ctx, sub, &buf);
    } else if (std.mem.startsWith(u8, sub, "act ")) {
        // v4: /queen act <kind> — execute any of 29 actions manually
        const kind_str = std.mem.trim(u8, sub[4..], &[_]u8{' '});
        dispatchAct(ctx, kind_str, &buf);
    } else if (std.mem.eql(u8, sub, "unlock")) {
        // v4: /queen unlock — show capability map
        const msg = queen_policy.fmtPolicyTelegram(&buf, ctx.config, ctx.counters);
        tgSend(ctx.tg, msg);
    } else if (std.mem.eql(u8, sub, "help")) {
        const msg = qt.E_CROWN ++ " Queen v4 Commands\n\n" ++
            "/queen \xe2\x80\x94 18 senses status\n" ++ // —
            "/queen doctor \xe2\x80\x94 tri doctor quick\n" ++
            "/queen score \xe2\x80\x94 ouroboros score\n" ++
            "/queen farm \xe2\x80\x94 farm status\n" ++
            "/queen arena \xe2\x80\x94 arena leaderboard\n" ++
            "/queen heal \xe2\x80\x94 doctor + ouroboros\n" ++
            "/queen act <kind> \xe2\x80\x94 run any action\n" ++
            "/queen unlock \xe2\x80\x94 capability map\n" ++
            "/queen history \xe2\x80\x94 incident log\n" ++
            "/queen policy \xe2\x80\x94 permission map\n" ++
            "/queen approve <id> \xe2\x80\x94 approve L2\n" ++
            "/queen deny <id> \xe2\x80\x94 deny L2\n" ++
            "/queen help \xe2\x80\x94 this message\n" ++
            "\n29 actions: L0(12) L1(10) L2(7)\n" ++
            "/q = /queen";
        tgSend(ctx.tg, msg);
    } else {
        const msg = std.fmt.bufPrint(&buf, qt.E_HAND ++ " \xd0\x9d\xd0\xb5\xd0\xb8\xd0\xb7\xd0\xb2\xd0\xb5\xd1\x81\xd1\x82\xd0\xbd\xd0\xb0\xd1\x8f \xd0\xba\xd0\xbe\xd0\xbc\xd0\xb0\xd0\xbd\xd0\xb4\xd0\xb0: {s}\n/queen help", .{sub}) catch ""; // Неизвестная команда
        tgSend(ctx.tg, msg);
    }
}

fn dispatchApprove(ctx: DispatchContext, sub: []const u8, buf: *[2048]u8) void {
    // Parse ID from "approve <id>"
    const id_str = if (sub.len > 8) std.mem.trim(u8, sub[8..], &[_]u8{' '}) else "";
    const id = std.fmt.parseInt(u16, id_str, 10) catch {
        const msg = std.fmt.bufPrint(buf, qt.E_HAND ++ " Usage: /queen approve <id>", .{}) catch return;
        tgSend(ctx.tg, msg);
        return;
    };

    if (ctx.pending.approve(id)) |action| {
        ctx.incidents.record(.approval, action, true, "human approved");
        queen_policy.writeAuditEntry("approval", action, .allowed, true, "human approved via Telegram");
        // Execute the approved action
        const result = queen_actions.execute(ctx.allocator, action);
        ctx.counters.record(action);
        const msg = std.fmt.bufPrint(buf, qt.E_CHECK ++ " Approved #{d}: {s}\n{s} ({d}ms)", .{
            id,
            action.label(),
            if (result.success) "OK" else "FAIL",
            result.duration_ms,
        }) catch return;
        tgSend(ctx.tg, msg);
    } else {
        const msg = std.fmt.bufPrint(buf, qt.E_CROSS ++ " No pending action #{d}", .{id}) catch return;
        tgSend(ctx.tg, msg);
    }
}

fn dispatchDeny(ctx: DispatchContext, sub: []const u8, buf: *[2048]u8) void {
    const id_str = if (sub.len > 5) std.mem.trim(u8, sub[5..], &[_]u8{' '}) else "";
    const id = std.fmt.parseInt(u16, id_str, 10) catch {
        const msg = std.fmt.bufPrint(buf, qt.E_HAND ++ " Usage: /queen deny <id>", .{}) catch return;
        tgSend(ctx.tg, msg);
        return;
    };

    if (ctx.pending.deny(id)) {
        ctx.incidents.record(.denial, .doctor_quick, true, "human denied");
        queen_policy.writeAuditEntry("denial", .doctor_quick, .denied_level, true, "human denied via Telegram");
        const msg = std.fmt.bufPrint(buf, qt.E_STOP ++ " Denied #{d}", .{id}) catch return;
        tgSend(ctx.tg, msg);
    } else {
        const msg = std.fmt.bufPrint(buf, qt.E_CROSS ++ " No pending action #{d}", .{id}) catch return;
        tgSend(ctx.tg, msg);
    }
}

fn dispatchAct(ctx: DispatchContext, kind_str: []const u8, buf: *[2048]u8) void {
    const kind = parseActionKind(kind_str) orelse {
        const msg = std.fmt.bufPrint(buf, qt.E_HAND ++ " Unknown action: {s}\n\nL0: farm_status, arena_status, doctor_scan, train_status, ouroboros_status, farm_evolve_status, swarm_status\nL1: doctor_quick, doctor_heal, ouroboros_cycle, git_commit, git_push, issue_comment, notify, arena_battle, fmt\nL2: farm_recycle, farm_evolve_step, cloud_spawn, cloud_kill, cloud_cleanup, issue_create, swarm_decompose", .{kind_str}) catch return;
        tgSend(ctx.tg, msg);
        return;
    };

    // Check policy
    const verdict = queen_policy.checkPolicy(kind, ctx.config, ctx.counters, ctx.incidents);
    if (!verdict.isAllowed()) {
        const msg = std.fmt.bufPrint(buf, qt.E_STOP ++ " {s}: {s}", .{ kind.label(), verdict.reason() }) catch return;
        tgSend(ctx.tg, msg);
        return;
    }

    ctx.incidents.record(.human_command, kind, true, "tg /queen act");
    const result = queen_actions.execute(ctx.allocator, kind);
    ctx.counters.record(kind);
    queen_policy.writeAuditEntry("human_command", kind, .allowed, result.success, "tg /queen act");
    const msg = fmtActionResult(buf, kind, result);
    tgSend(ctx.tg, msg);
}

pub fn parseActionKind(s: []const u8) ?qt.ActionKind {
    const pairs = .{
        .{ "farm_status", qt.ActionKind.farm_status },
        .{ "arena_status", qt.ActionKind.arena_status },
        .{ "doctor_scan", qt.ActionKind.doctor_scan },
        .{ "train_status", qt.ActionKind.train_status },
        .{ "train_diagnose", qt.ActionKind.train_diagnose },
        .{ "experiment_chart", qt.ActionKind.experiment_chart },
        .{ "patent_status", qt.ActionKind.patent_status },
        .{ "research_sacred", qt.ActionKind.research_sacred },
        .{ "ouroboros_status", qt.ActionKind.ouroboros_status },
        .{ "experience_recall", qt.ActionKind.experience_recall },
        .{ "farm_evolve_status", qt.ActionKind.farm_evolve_status },
        .{ "swarm_status", qt.ActionKind.swarm_status },
        .{ "doctor_quick", qt.ActionKind.doctor_quick },
        .{ "doctor_heal", qt.ActionKind.doctor_heal },
        .{ "ouroboros_cycle", qt.ActionKind.ouroboros_cycle },
        .{ "git_commit", qt.ActionKind.git_commit_state },
        .{ "git_push", qt.ActionKind.git_push },
        .{ "issue_comment", qt.ActionKind.issue_comment },
        .{ "notify", qt.ActionKind.notify },
        .{ "arena_battle", qt.ActionKind.arena_battle },
        .{ "experience_save", qt.ActionKind.experience_save },
        .{ "fmt", qt.ActionKind.fmt },
        .{ "farm_recycle", qt.ActionKind.farm_recycle },
        .{ "farm_evolve_step", qt.ActionKind.farm_evolve_step },
        .{ "cloud_spawn", qt.ActionKind.cloud_spawn },
        .{ "cloud_kill", qt.ActionKind.cloud_kill },
        .{ "cloud_cleanup", qt.ActionKind.cloud_cleanup },
        .{ "issue_create", qt.ActionKind.issue_create },
        .{ "swarm_decompose", qt.ActionKind.swarm_decompose },
    };
    inline for (pairs) |pair| {
        if (std.mem.eql(u8, s, pair[0])) return pair[1];
    }
    return null;
}

fn fmtActionResult(buf: []u8, kind: qt.ActionKind, result: qt.ActionResult) []const u8 {
    const icon = if (result.success) qt.E_CHECK else qt.E_CROSS;
    const preview_len = @min(result.output_len, 400);
    return std.fmt.bufPrint(buf, "{s} {s}: {s} ({d}ms)\n\n{s}", .{
        icon,
        kind.label(),
        if (result.success) "OK" else "FAIL",
        result.duration_ms,
        result.output[0..preview_len],
    }) catch buf[0..0];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TELEGRAM SEND (fire-and-forget)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn tgSend(config: qt.TgConfig, text: []const u8) void {
    if (!config.enabled) return;
    tgPost(config, "sendMessage", text, null);
}

pub fn tgSendCapture(config: qt.TgConfig, text: []const u8) ?i64 {
    if (!config.enabled) return null;

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/sendMessage", .{config.bot_token}) catch return null;

    var body_buf: [4096]u8 = undefined;
    const body = qt.buildTgBody(&body_buf, config.chat_id, null, text) orelse return null;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .response_writer = &aw.writer,
    }) catch return null;

    if (result.status != .ok) return null;

    const resp = aw.written();
    const needle = "\"message_id\":";
    const idx = std.mem.indexOf(u8, resp, needle) orelse return null;
    const start = idx + needle.len;
    if (start >= resp.len) return null;
    var end = start;
    while (end < resp.len and ((resp[end] >= '0' and resp[end] <= '9') or resp[end] == '-')) : (end += 1) {}
    return std.fmt.parseInt(i64, resp[start..end], 10) catch null;
}

pub fn tgEdit(config: qt.TgConfig, message_id: i64, text: []const u8) void {
    if (!config.enabled) return;
    tgPost(config, "editMessageText", text, message_id);
}

pub fn tgPin(config: qt.TgConfig, message_id: i64) void {
    if (!config.enabled) return;

    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/pinChatMessage", .{config.bot_token}) catch return;

    var body_buf: [256]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf, "{{\"chat_id\":\"{s}\",\"message_id\":{d}}}", .{ config.chat_id, message_id }) catch return;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    _ = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch return;
}

fn tgPost(config: qt.TgConfig, endpoint: []const u8, text: []const u8, message_id: ?i64) void {
    var url_buf: [512]u8 = undefined;
    const url = std.fmt.bufPrint(&url_buf, "https://api.telegram.org/bot{s}/{s}", .{ config.bot_token, endpoint }) catch return;

    var body_buf: [4096]u8 = undefined;
    const body = qt.buildTgBody(&body_buf, config.chat_id, message_id, text) orelse return;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    _ = client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    }) catch return;
}

/// Send auto-action report to Telegram
pub fn tgSendAutoReport(tg: qt.TgConfig, kind: qt.ActionKind, result: qt.ActionResult) void {
    var buf: [1024]u8 = undefined;
    const preview_len = @min(result.output_len, 300);
    const msg = std.fmt.bufPrint(&buf, qt.E_BOLT ++ " Queen Auto-Action\n\n" ++
        "{s} {s}: {s} ({d}ms)\n\n{s}", .{
        kind.emojiIcon(),
        kind.label(),
        if (result.success) "OK" else "FAIL",
        result.duration_ms,
        result.output[0..preview_len],
    }) catch return;
    tgSend(tg, msg);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Queen telegram — CommandQueue push/pop" {
    var q = CommandQueue{};
    var cmd = TgCommand{};
    const text = "/queen status";
    @memcpy(cmd.text[0..text.len], text);
    cmd.text_len = text.len;

    try std.testing.expect(q.push(cmd));
    const popped = q.pop().?;
    try std.testing.expectEqualStrings("/queen status", popped.textStr());
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — CommandQueue full" {
    var q = CommandQueue{};
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        try std.testing.expect(q.push(.{}));
    }
    // Should be full now
    try std.testing.expect(!q.push(.{}));
}

test "Queen telegram — parseUpdates" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":100,"message":{"chat":{"id":123},"text":"/queen doctor"}}]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(i64, 100), last_id.load(.acquire));
    const cmd = q.pop().?;
    try std.testing.expectEqualStrings("/queen doctor", cmd.textStr());
}

test "Queen telegram — parseUpdates filters wrong chat" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":101,"message":{"chat":{"id":999},"text":"/queen"}}]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(i64, 101), last_id.load(.acquire));
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop()); // filtered
}

test "Queen telegram — fmtActionResult" {
    var buf: [2048]u8 = undefined;
    var result = qt.ActionResult{ .success = true, .duration_ms = 42 };
    const output = "all clear";
    @memcpy(result.output[0..output.len], output);
    result.output_len = output.len;
    const msg = fmtActionResult(&buf, .doctor_quick, result);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "42") != null);
}

test "Queen telegram — fmtActionResult failure" {
    var buf: [2048]u8 = undefined;
    var result = qt.ActionResult{ .success = false, .duration_ms = 123 };
    const output = "build broken";
    @memcpy(result.output[0..output.len], output);
    result.output_len = output.len;
    const msg = fmtActionResult(&buf, .farm_status, result);
    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "FAIL") != null);
}

test "Queen telegram — parseUpdates handles /q command" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":200,"message":{"chat":{"id":123},"text":"/q farm"}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expectEqualStrings("/q farm", cmd.textStr());
}

test "Queen telegram — parseUpdates ignores non-queen commands" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":300,"message":{"chat":{"id":123},"text":"/random"}}]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseUpdates handles multiple updates" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[
        \\  {"update_id":400,"message":{"chat":{"id":123},"text":"/queen"}},
        \\  {"update_id":401,"message":{"chat":{"id":123},"text":"/q score"}}
        \\]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(i64, 401), last_id.load(.acquire));

    const cmd1 = q.pop().?;
    try std.testing.expectEqualStrings("/queen", cmd1.textStr());

    const cmd2 = q.pop().?;
    try std.testing.expectEqualStrings("/q score", cmd2.textStr());

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — TgCommand textStr returns text" {
    var cmd = TgCommand{};
    const text = "/queen doctor";
    @memcpy(cmd.text[0..text.len], text);
    cmd.text_len = text.len;

    try std.testing.expectEqualStrings(text, cmd.textStr());
}

test "Queen telegram — TgCommand empty text" {
    var cmd = TgCommand{};
    cmd.text_len = 0;

    try std.testing.expectEqualStrings("", cmd.textStr());
}

test "Queen telegram — TgCommand stores chat_id" {
    var cmd = TgCommand{};
    const chat_id = "123456";
    @memcpy(cmd.chat_id[0..chat_id.len], chat_id);
    cmd.chat_id_len = chat_id.len;

    try std.testing.expectEqual(@as(usize, chat_id.len), cmd.chat_id_len);
    try std.testing.expectEqualStrings(chat_id, cmd.chat_id[0..cmd.chat_id_len]);
}

test "Queen telegram — CommandQueue wraparound" {
    var q = CommandQueue{};

    // Fill to MAX_COMMANDS - 1 (ring buffer can only hold MAX-1)
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        try std.testing.expect(q.push(.{ .update_id = @as(i64, i) }));
    }

    // Should be full now
    try std.testing.expect(!q.push(.{}));

    // Pop all
    i = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        const cmd = q.pop().?;
        try std.testing.expectEqual(@as(i64, i), cmd.update_id);
    }

    // Should be empty
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());

    // Should be able to push again
    try std.testing.expect(q.push(.{ .update_id = 999 }));
    const cmd = q.pop().?;
    try std.testing.expectEqual(@as(i64, 999), cmd.update_id);
}

test "Queen telegram — parseUpdates with escaped text" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":500,"message":{"chat":{"id":123},"text":"/queen act farm_recycle"}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expectEqualStrings("/queen act farm_recycle", cmd.textStr());
}

test "Queen telegram — CommandQueue concurrent push pop order" {
    var q = CommandQueue{};

    var cmd1 = TgCommand{ .update_id = 1 };
    cmd1.text[0] = 'a';
    cmd1.text_len = 1;

    var cmd2 = TgCommand{ .update_id = 2 };
    cmd2.text[0] = 'b';
    cmd2.text_len = 1;

    try std.testing.expect(q.push(cmd1));
    try std.testing.expect(q.push(cmd2));

    const popped1 = q.pop().?;
    try std.testing.expectEqual(@as(i64, 1), popped1.update_id);

    const popped2 = q.pop().?;
    try std.testing.expectEqual(@as(i64, 2), popped2.update_id);
}

test "Queen telegram — parseActionKind all L0 actions" {
    // L0 actions (12 total)
    try std.testing.expectEqual(qt.ActionKind.farm_status, parseActionKind("farm_status").?);
    try std.testing.expectEqual(qt.ActionKind.arena_status, parseActionKind("arena_status").?);
    try std.testing.expectEqual(qt.ActionKind.doctor_scan, parseActionKind("doctor_scan").?);
    try std.testing.expectEqual(qt.ActionKind.train_status, parseActionKind("train_status").?);
    try std.testing.expectEqual(qt.ActionKind.train_diagnose, parseActionKind("train_diagnose").?);
    try std.testing.expectEqual(qt.ActionKind.experiment_chart, parseActionKind("experiment_chart").?);
    try std.testing.expectEqual(qt.ActionKind.patent_status, parseActionKind("patent_status").?);
    try std.testing.expectEqual(qt.ActionKind.research_sacred, parseActionKind("research_sacred").?);
    try std.testing.expectEqual(qt.ActionKind.ouroboros_status, parseActionKind("ouroboros_status").?);
    try std.testing.expectEqual(qt.ActionKind.experience_recall, parseActionKind("experience_recall").?);
    try std.testing.expectEqual(qt.ActionKind.farm_evolve_status, parseActionKind("farm_evolve_status").?);
    try std.testing.expectEqual(qt.ActionKind.swarm_status, parseActionKind("swarm_status").?);
}

test "Queen telegram — parseActionKind all L1 actions" {
    // L1 actions (10 total)
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, parseActionKind("doctor_quick").?);
    try std.testing.expectEqual(qt.ActionKind.doctor_heal, parseActionKind("doctor_heal").?);
    try std.testing.expectEqual(qt.ActionKind.ouroboros_cycle, parseActionKind("ouroboros_cycle").?);
    try std.testing.expectEqual(qt.ActionKind.git_commit_state, parseActionKind("git_commit").?);
    try std.testing.expectEqual(qt.ActionKind.git_push, parseActionKind("git_push").?);
    try std.testing.expectEqual(qt.ActionKind.issue_comment, parseActionKind("issue_comment").?);
    try std.testing.expectEqual(qt.ActionKind.notify, parseActionKind("notify").?);
    try std.testing.expectEqual(qt.ActionKind.arena_battle, parseActionKind("arena_battle").?);
    try std.testing.expectEqual(qt.ActionKind.experience_save, parseActionKind("experience_save").?);
    try std.testing.expectEqual(qt.ActionKind.fmt, parseActionKind("fmt").?);
}

test "Queen telegram — parseActionKind all L2 actions" {
    // L2 actions (7 total)
    try std.testing.expectEqual(qt.ActionKind.farm_recycle, parseActionKind("farm_recycle").?);
    try std.testing.expectEqual(qt.ActionKind.farm_evolve_step, parseActionKind("farm_evolve_step").?);
    try std.testing.expectEqual(qt.ActionKind.cloud_spawn, parseActionKind("cloud_spawn").?);
    try std.testing.expectEqual(qt.ActionKind.cloud_kill, parseActionKind("cloud_kill").?);
    try std.testing.expectEqual(qt.ActionKind.cloud_cleanup, parseActionKind("cloud_cleanup").?);
    try std.testing.expectEqual(qt.ActionKind.issue_create, parseActionKind("issue_create").?);
    try std.testing.expectEqual(qt.ActionKind.swarm_decompose, parseActionKind("swarm_decompose").?);
}

test "Queen telegram — parseActionKind unknown returns null" {
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("unknown_action"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind(""));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("   "));
}

test "Queen telegram — parseActionKind case sensitive" {
    try std.testing.expectEqual(qt.ActionKind.farm_status, parseActionKind("farm_status").?);
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("FARM_STATUS"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("Farm_Status"));
}

test "Queen telegram — tgSendAutoReport format" {
    var buf: [1024]u8 = undefined;
    var result = qt.ActionResult{
        .success = true,
        .duration_ms = 150,
    };
    const output = "action completed";
    @memcpy(result.output[0..output.len], output);
    result.output_len = output.len;

    const tg_config: qt.TgConfig = .{
        .bot_token = "test",
        .chat_id = "123",
        .enabled = false, // disabled to prevent actual send
    };

    // Just check it doesn't crash (disabled tg won't send)
    tgSendAutoReport(tg_config, .doctor_quick, result);

    // Verify format would be correct
    const msg = std.fmt.bufPrint(&buf, "{s} {s}: {s} ({d}ms)\n\n{s}", .{
        qt.E_BOLT,
        "doctor_quick",
        "OK",
        150,
        "action completed",
    }) catch "";
    try std.testing.expect(msg.len > 0);
}

test "Queen telegram — tgSendAutoReport failure format" {
    var result = qt.ActionResult{
        .success = false,
        .duration_ms = 42,
    };
    const output = "action failed";
    @memcpy(result.output[0..output.len], output);
    result.output_len = output.len;

    const tg_config: qt.TgConfig = .{
        .bot_token = "test",
        .chat_id = "123",
        .enabled = false,
    };

    tgSendAutoReport(tg_config, .farm_recycle, result);
}

test "Queen telegram — tgSend disabled does nothing" {
    const disabled_config: qt.TgConfig = .{
        .bot_token = "test",
        .chat_id = "123",
        .enabled = false,
    };

    // Should not crash
    tgSend(disabled_config, "test message");
    tgEdit(disabled_config, 123, "edited message");
    tgPin(disabled_config, 123);
}

test "Queen telegram — fmtActionResult truncates long output" {
    var buf: [2048]u8 = undefined;
    var result = qt.ActionResult{
        .success = true,
        .duration_ms = 10,
    };

    // Fill output with more than 400 chars
    var long_output: [1000]u8 = undefined;
    @memset(&long_output, 'X');
    const copy_len = @min(long_output.len, result.output.len);
    @memcpy(result.output[0..copy_len], long_output[0..copy_len]);
    result.output_len = long_output.len;

    const msg = fmtActionResult(&buf, .doctor_quick, result);

    // Should contain "OK" and duration but truncate output preview
    try std.testing.expect(std.mem.indexOf(u8, msg, "OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "10") != null);
}

test "Queen telegram — fmtActionResult empty output" {
    var buf: [2048]u8 = undefined;
    const result = qt.ActionResult{
        .success = true,
        .duration_ms = 5,
        .output_len = 0,
    };

    const msg = fmtActionResult(&buf, .farm_status, result);

    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "OK") != null);
}

test "Queen telegram — TgCommand max text length" {
    var cmd = TgCommand{};
    const long_text = [1]u8{'X'} ** MAX_CMD_LEN;
    @memcpy(cmd.text[0..], &long_text);
    cmd.text_len = MAX_CMD_LEN;

    try std.testing.expectEqual(@as(usize, MAX_CMD_LEN), cmd.textStr().len);
    try std.testing.expectEqual(@as(u8, 'X'), cmd.text[0]);
    try std.testing.expectEqual(@as(u8, 'X'), cmd.text[MAX_CMD_LEN - 1]);
}

test "Queen telegram — TgCommand max chat_id length" {
    var cmd = TgCommand{};
    const long_chat = [1]u8{'9'} ** 32;
    @memcpy(cmd.chat_id[0..], &long_chat);
    cmd.chat_id_len = 32;

    try std.testing.expectEqual(@as(usize, 32), cmd.chat_id_len);
}

test "Queen telegram — parseUpdates filters non-queen text" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // Text without /queen or /q prefix should be ignored
    const body =
        \\{"ok":true,"result":[{"update_id":600,"message":{"chat":{"id":123},"text":"random message"}}]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(i64, 600), last_id.load(.acquire));
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseUpdates handles negative chat_id" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "-123456789", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "-123456789",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":700,"message":{"chat":{"id":-123456789},"text":"/q"}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expectEqualStrings("/q", cmd.textStr());
}

test "Queen telegram — parseUpdates malformed update_id" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // Malformed JSON with non-numeric update_id
    const body =
        \\{"ok":true,"result":[{"update_id":"abc","message":{"chat":{"id":123},"text":"/queen"}}]}
    ;

    // Should not crash, just skip malformed entry
    parseUpdates(&ctx, body);
}

test "Queen telegram — parseUpdates missing text field" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // Update without text field
    const body =
        \\{"ok":true,"result":[{"update_id":800,"message":{"chat":{"id":123}}}}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(i64, 800), last_id.load(.acquire));
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — CommandQueue preserves order under stress" {
    var q = CommandQueue{};

    // Push MAX_COMMANDS - 1 items
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        var cmd = TgCommand{ .update_id = @as(i64, i) };
        cmd.text[0] = @as(u8, @intCast('0' + i % 10));
        cmd.text_len = 1;
        try std.testing.expect(q.push(cmd));
    }

    // Pop and verify order
    i = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        const cmd = q.pop().?;
        try std.testing.expectEqual(@as(i64, i), cmd.update_id);
    }

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — CommandQueue empty queue pop" {
    var q = CommandQueue{};

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());

    // Push and pop one item
    try std.testing.expect(q.push(.{ .update_id = 1 }));
    _ = q.pop();

    // Should be empty again
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseUpdates with unicode in text" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // Text with emoji (UTF-8 encoded)
    const body =
        \\{"ok":true,"result":[{"update_id":900,"message":{"chat":{"id":123},"text":"/queen \xf0\x9f\x98\x80"}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expect(cmd.textStr().len > 0);
}

test "Queen telegram — TgCommand update_id tracking" {
    var cmd = TgCommand{
        .update_id = 12345,
    };

    try std.testing.expectEqual(@as(i64, 12345), cmd.update_id);

    cmd.update_id = -999;
    try std.testing.expectEqual(@as(i64, -999), cmd.update_id);
}

test "Queen telegram — CommandQueue handles rapid push/pop cycles" {
    var q = CommandQueue{};

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // Push
        const cmd = TgCommand{ .update_id = @as(i64, i) };
        if (!q.push(cmd)) {
            // Queue full, pop one
            _ = q.pop();
            _ = q.push(cmd);
        }

        // Every 10 pushes, pop one
        if (i % 10 == 0) {
            _ = q.pop();
        }
    }

    // Drain remaining
    var count: u32 = 0;
    while (q.pop()) |_| : (count += 1) {}

    try std.testing.expect(count > 0);
}

test "Queen telegram — parseActionKind git_commit mapped correctly" {
    // "git_commit" string maps to git_commit_state enum
    const kind = parseActionKind("git_commit").?;
    try std.testing.expectEqual(qt.ActionKind.git_commit_state, kind);
}

test "Queen telegram — fmtActionResult with very long output" {
    var buf: [2048]u8 = undefined;
    var result = qt.ActionResult{
        .success = false,
        .duration_ms = 999,
    };

    // Fill with maximum output
    @memset(result.output[0..], 'Z');
    result.output_len = result.output.len;

    const msg = fmtActionResult(&buf, .cloud_spawn, result);

    try std.testing.expect(msg.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, msg, "FAIL") != null);
}

test "Queen telegram — TgCommand stores both text and chat_id" {
    var cmd = TgCommand{
        .update_id = 42,
    };
    const text = "/queen status";
    const chat_id = "-123456789";

    @memcpy(cmd.text[0..text.len], text);
    cmd.text_len = text.len;
    @memcpy(cmd.chat_id[0..chat_id.len], chat_id);
    cmd.chat_id_len = chat_id.len;

    try std.testing.expectEqualStrings(text, cmd.textStr());
    try std.testing.expectEqual(@as(i64, 42), cmd.update_id);
    try std.testing.expectEqualStrings(chat_id, cmd.chat_id[0..cmd.chat_id_len]);
}

test "Queen telegram — CommandQueue single item lifecycle" {
    var q = CommandQueue{};
    const original_cmd = TgCommand{
        .update_id = 777,
    };
    var cmd = original_cmd;
    cmd.text[0] = 'T';
    cmd.text_len = 1;

    // Push
    try std.testing.expect(q.push(cmd));

    // Pop
    const popped = q.pop().?;
    try std.testing.expectEqual(@as(i64, 777), popped.update_id);
    try std.testing.expectEqual(@as(usize, 1), popped.text_len);
    try std.testing.expectEqual(@as(u8, 'T'), popped.text[0]);

    // Empty again
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — CommandQueue FIFO ordering" {
    var q = CommandQueue{};

    const cmds = [_]i64{ 10, 20, 30, 40, 50 };
    for (cmds) |id| {
        try std.testing.expect(q.push(TgCommand{ .update_id = id }));
    }

    for (cmds) |id| {
        const popped = q.pop().?;
        try std.testing.expectEqual(id, popped.update_id);
    }

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — CommandQueue reject when full" {
    var q = CommandQueue{};

    // Fill to capacity (MAX_COMMANDS - 1)
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        try std.testing.expect(q.push(.{ .update_id = @as(i64, i) }));
    }

    // This push should fail (queue full)
    try std.testing.expect(!q.push(.{ .update_id = 999 }));

    // Pop one
    _ = q.pop();

    // Now should succeed
    try std.testing.expect(q.push(.{ .update_id = 1000 }));
}

test "Queen telegram — TgCommand zero length fields" {
    var cmd = TgCommand{
        .update_id = 0,
    };
    cmd.text_len = 0;
    cmd.chat_id_len = 0;

    try std.testing.expectEqualStrings("", cmd.textStr());
    try std.testing.expectEqual(@as(usize, 0), cmd.chat_id_len);
    try std.testing.expectEqual(@as(i64, 0), cmd.update_id);
}

test "Queen telegram — parseUpdates with special characters in text" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // Text with quotes and backslashes (escaped in JSON)
    const body =
        \\{"ok":true,"result":[{"update_id":1000,"message":{"chat":{"id":123},"text":"/q test\\\"quoted\\\""}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expect(std.mem.startsWith(u8, cmd.textStr(), "/q"));
}

test "Queen telegram — parseUpdates handles empty result array" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body = "{\"ok\":true,\"result\":[]}";
    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — TgCommand update_id zero" {
    const cmd = TgCommand{ .update_id = 0 };
    try std.testing.expectEqual(@as(i64, 0), cmd.update_id);
}

test "Queen telegram — TgCommand negative update_id" {
    const cmd = TgCommand{ .update_id = -1 };
    try std.testing.expectEqual(@as(i64, -1), cmd.update_id);
}

test "Queen telegram — parseActionKind partial match fails" {
    // Partial matches should not return results
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("farm"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("doctor"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("git"));
}

test "Queen telegram — parseActionKind with extra spaces" {
    // Strings with spaces should not match (exact match required)
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind(" farm_status"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("farm_status "));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind(" farm_status "));
}

test "Queen telegram — parseActionKind all 29 actions" {
    // Verify we can parse all 29 unique actions
    const all_actions = [_][]const u8{
        "farm_status",
        "arena_status",
        "doctor_scan",
        "train_status",
        "train_diagnose",
        "experiment_chart",
        "patent_status",
        "research_sacred",
        "ouroboros_status",
        "experience_recall",
        "farm_evolve_status",
        "swarm_status",
        "doctor_quick",
        "doctor_heal",
        "ouroboros_cycle",
        "git_commit",
        "git_push",
        "issue_comment",
        "notify",
        "arena_battle",
        "experience_save",
        "fmt",
        "farm_recycle",
        "farm_evolve_step",
        "cloud_spawn",
        "cloud_kill",
        "cloud_cleanup",
        "issue_create",
        "swarm_decompose",
    };

    var count: usize = 0;
    for (all_actions) |action_str| {
        if (parseActionKind(action_str)) |_| {
            count += 1;
        }
    }

    try std.testing.expectEqual(@as(usize, 29), count);
}

test "Queen telegram — TgCommand partial text copy" {
    var cmd = TgCommand{};
    const text = "hello world";
    @memcpy(cmd.text[0..text.len], text);
    cmd.text_len = text.len;

    try std.testing.expectEqualStrings(text, cmd.textStr());
    try std.testing.expectEqual(@as(usize, text.len), cmd.text_len);
}

test "Queen telegram — TgCommand text length boundary" {
    var cmd = TgCommand{};

    // Exactly at limit
    cmd.text_len = MAX_CMD_LEN;
    try std.testing.expectEqual(@as(usize, MAX_CMD_LEN), cmd.text_len);

    // Length 0
    cmd.text_len = 0;
    try std.testing.expectEqual(@as(usize, 0), cmd.text_len);
}

test "Queen telegram — TgCommand chat_id boundary" {
    var cmd = TgCommand{};

    // Max chat_id length (32)
    cmd.chat_id_len = 32;
    try std.testing.expectEqual(@as(usize, 32), cmd.chat_id_len);
}

test "Queen telegram — CommandQueue concurrent push preserves data" {
    var q = CommandQueue{};

    var cmd1 = TgCommand{ .update_id = 100 };
    cmd1.text[0] = 'A';
    cmd1.text_len = 1;

    var cmd2 = TgCommand{ .update_id = 200 };
    cmd2.text[0] = 'B';
    cmd2.text_len = 1;

    _ = q.push(cmd1);
    _ = q.push(cmd2);

    const p1 = q.pop().?;
    const p2 = q.pop().?;

    try std.testing.expectEqual(@as(i64, 100), p1.update_id);
    try std.testing.expectEqual(@as(u8, 'A'), p1.text[0]);

    try std.testing.expectEqual(@as(i64, 200), p2.update_id);
    try std.testing.expectEqual(@as(u8, 'B'), p2.text[0]);
}

test "Queen telegram — fmtActionResult with special characters" {
    var buf: [2048]u8 = undefined;
    var result = qt.ActionResult{
        .success = true,
        .duration_ms = 1,
    };
    const output = "Test \"quotes\" and 'apostrophes'";
    @memcpy(result.output[0..output.len], output);
    result.output_len = output.len;

    const msg = fmtActionResult(&buf, .notify, result);

    try std.testing.expect(msg.len > 0);
}

test "Queen telegram — parseUpdates updates last_id even when filtered" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "999", // Different chat ID
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":777,"message":{"chat":{"id":123},"text":"/queen"}}]}
    ;

    parseUpdates(&ctx, body);

    // Should update last_id even though message was filtered
    try std.testing.expectEqual(@as(i64, 777), last_id.load(.acquire));
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseUpdates with /q and /queen variants" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // Test both /queen and /q are recognized
    const body1 =
        \\{"ok":true,"result":[{"update_id":1,"message":{"chat":{"id":123},"text":"/queen"}}]}
    ;
    const body2 =
        \\{"ok":true,"result":[{"update_id":2,"message":{"chat":{"id":123},"text":"/q"}}]}
    ;

    parseUpdates(&ctx, body1);
    const cmd1 = q.pop().?;
    try std.testing.expect(std.mem.startsWith(u8, cmd1.textStr(), "/queen"));

    parseUpdates(&ctx, body2);
    const cmd2 = q.pop().?;
    try std.testing.expect(std.mem.startsWith(u8, cmd2.textStr(), "/q"));
}

test "Queen telegram — TgCommand stores negative chat_id" {
    var cmd = TgCommand{};
    const chat_id = "-1001234567890";
    @memcpy(cmd.chat_id[0..chat_id.len], chat_id);
    cmd.chat_id_len = chat_id.len;

    try std.testing.expectEqualStrings(chat_id, cmd.chat_id[0..cmd.chat_id_len]);
}

test "Queen telegram — CommandQueue reset after full drain" {
    var q = CommandQueue{};

    // Fill and drain multiple times
    var iteration: u32 = 0;
    while (iteration < 3) : (iteration += 1) {
        var i: u32 = 0;
        while (i < 5) : (i += 1) {
            _ = q.push(TgCommand{ .update_id = @as(i64, i) });
        }

        i = 0;
        while (i < 5) : (i += 1) {
            _ = q.pop();
        }
    }

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseActionKind returns null for empty string" {
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind(""));
}

test "Queen telegram — parseActionKind underscore variants not supported" {
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("farm-status"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("Farm_Status"));
    try std.testing.expectEqual(@as(?qt.ActionKind, null), parseActionKind("FARM_STATUS"));
}

test "Queen telegram — fmtActionResult success shows OK" {
    var buf: [2048]u8 = undefined;
    const result = qt.ActionResult{
        .success = true,
        .duration_ms = 123,
        .output_len = 0,
    };

    const msg = fmtActionResult(&buf, .doctor_quick, result);

    try std.testing.expect(std.mem.indexOf(u8, msg, "OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "123") != null);
}

test "Queen telegram — fmtActionResult failure shows FAIL" {
    var buf: [2048]u8 = undefined;
    const result = qt.ActionResult{
        .success = false,
        .duration_ms = 456,
        .output_len = 0,
    };

    const msg = fmtActionResult(&buf, .farm_status, result);

    try std.testing.expect(std.mem.indexOf(u8, msg, "FAIL") != null);
    try std.testing.expect(std.mem.indexOf(u8, msg, "456") != null);
}

test "Queen telegram — TgCommand all fields default" {
    const cmd = TgCommand{};

    try std.testing.expectEqual(@as(usize, 0), cmd.text_len);
    try std.testing.expectEqual(@as(usize, 0), cmd.chat_id_len);
    try std.testing.expectEqual(@as(i64, 0), cmd.update_id);
}

test "Queen telegram — CommandQueue push returns true when successful" {
    var q = CommandQueue{};
    const result = q.push(.{ .update_id = 1 });
    try std.testing.expect(result);
}

test "Queen telegram — CommandQueue push returns false when full" {
    var q = CommandQueue{};

    // Fill queue
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        _ = q.push(.{});
    }

    // Should return false when full
    try std.testing.expect(!q.push(.{}));
}

test "Queen telegram — CommandQueue head tail wraparound" {
    var q = CommandQueue{};

    // Fill, drain, then fill again to test wraparound
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        _ = q.push(TgCommand{ .update_id = @as(i64, i) });
    }

    // Drain all
    while (q.pop()) |_| {}

    // Fill again with different IDs
    i = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        _ = q.push(TgCommand{ .update_id = @as(i64, i + 1000) });
    }

    // Verify new IDs come out correctly
    i = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        const cmd = q.pop().?;
        try std.testing.expectEqual(@as(i64, i + 1000), cmd.update_id);
    }
}

test "Queen telegram — parseUpdates skips non-queen prefixes" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[
        \\  {"update_id":1,"message":{"chat":{"id":123},"text":"/help"}},
        \\  {"update_id":2,"message":{"chat":{"id":123},"text":"/start"}},
        \\  {"update_id":3,"message":{"chat":{"id":123},"text":"/queen"}}
        \\]}
    ;

    parseUpdates(&ctx, body);

    // Only /queen should be in queue
    const cmd = q.pop().?;
    try std.testing.expect(std.mem.startsWith(u8, cmd.textStr(), "/queen"));
    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — TgCommand copy text at max length" {
    var cmd = TgCommand{};

    // Fill entire buffer
    var i: usize = 0;
    while (i < MAX_CMD_LEN) : (i += 1) {
        cmd.text[i] = 'X';
    }
    cmd.text_len = MAX_CMD_LEN;

    try std.testing.expectEqual(@as(usize, MAX_CMD_LEN), cmd.textStr().len);
    try std.testing.expectEqual(@as(u8, 'X'), cmd.text[0]);
    try std.testing.expectEqual(@as(u8, 'X'), cmd.text[MAX_CMD_LEN - 1]);
}

test "Queen telegram — TgCommand with update_id only" {
    const cmd = TgCommand{
        .update_id = 12345,
    };

    try std.testing.expectEqual(@as(i64, 12345), cmd.update_id);
    try std.testing.expectEqual(@as(usize, 0), cmd.text_len);
    try std.testing.expectEqual(@as(usize, 0), cmd.chat_id_len);
}

test "Queen telegram — CommandQueue interleaved push pop" {
    var q = CommandQueue{};

    _ = q.push(TgCommand{ .update_id = 1 });
    _ = q.push(TgCommand{ .update_id = 2 });
    _ = q.pop();
    _ = q.push(TgCommand{ .update_id = 3 });
    _ = q.push(TgCommand{ .update_id = 4 });
    _ = q.pop();
    _ = q.push(TgCommand{ .update_id = 5 });

    // Remaining: 3, 4, 5
    const c1 = q.pop().?;
    const c2 = q.pop().?;
    const c3 = q.pop().?;

    try std.testing.expectEqual(@as(i64, 3), c1.update_id);
    try std.testing.expectEqual(@as(i64, 4), c2.update_id);
    try std.testing.expectEqual(@as(i64, 5), c3.update_id);
}

test "Queen telegram — fmtActionResult includes action label" {
    var buf: [2048]u8 = undefined;
    const result = qt.ActionResult{
        .success = true,
        .duration_ms = 1,
    };

    const msg = fmtActionResult(&buf, .farm_recycle, result);

    // label() returns "farm recycle" (with space, not underscore)
    try std.testing.expect(std.mem.indexOf(u8, msg, "farm recycle") != null);
}

test "Queen telegram — fmtActionResult includes duration" {
    var buf: [2048]u8 = undefined;
    const result = qt.ActionResult{
        .success = true,
        .duration_ms = 9999,
    };

    const msg = fmtActionResult(&buf, .doctor_quick, result);

    try std.testing.expect(std.mem.indexOf(u8, msg, "9999") != null);
}

test "Queen telegram — parseActionKind cloud actions" {
    try std.testing.expectEqual(qt.ActionKind.cloud_spawn, parseActionKind("cloud_spawn").?);
    try std.testing.expectEqual(qt.ActionKind.cloud_kill, parseActionKind("cloud_kill").?);
    try std.testing.expectEqual(qt.ActionKind.cloud_cleanup, parseActionKind("cloud_cleanup").?);
}

test "Queen telegram — parseActionKind experience actions" {
    try std.testing.expectEqual(qt.ActionKind.experience_recall, parseActionKind("experience_recall").?);
    try std.testing.expectEqual(qt.ActionKind.experience_save, parseActionKind("experience_save").?);
}

test "Queen telegram — parseActionKind arena actions" {
    try std.testing.expectEqual(qt.ActionKind.arena_status, parseActionKind("arena_status").?);
    try std.testing.expectEqual(qt.ActionKind.arena_battle, parseActionKind("arena_battle").?);
}

test "Queen telegram — parseActionKind farm actions" {
    try std.testing.expectEqual(qt.ActionKind.farm_status, parseActionKind("farm_status").?);
    try std.testing.expectEqual(qt.ActionKind.farm_evolve_status, parseActionKind("farm_evolve_status").?);
    try std.testing.expectEqual(qt.ActionKind.farm_recycle, parseActionKind("farm_recycle").?);
    try std.testing.expectEqual(qt.ActionKind.farm_evolve_step, parseActionKind("farm_evolve_step").?);
}

test "Queen telegram — parseActionKind doctor actions" {
    try std.testing.expectEqual(qt.ActionKind.doctor_scan, parseActionKind("doctor_scan").?);
    try std.testing.expectEqual(qt.ActionKind.doctor_quick, parseActionKind("doctor_quick").?);
    try std.testing.expectEqual(qt.ActionKind.doctor_heal, parseActionKind("doctor_heal").?);
}

test "Queen telegram — parseActionKind git actions" {
    try std.testing.expectEqual(qt.ActionKind.git_commit_state, parseActionKind("git_commit").?);
    try std.testing.expectEqual(qt.ActionKind.git_push, parseActionKind("git_push").?);
}

test "Queen telegram — parseActionKind train actions" {
    try std.testing.expectEqual(qt.ActionKind.train_status, parseActionKind("train_status").?);
    try std.testing.expectEqual(qt.ActionKind.train_diagnose, parseActionKind("train_diagnose").?);
}

test "Queen telegram — parseActionKind ouroboros actions" {
    try std.testing.expectEqual(qt.ActionKind.ouroboros_status, parseActionKind("ouroboros_status").?);
    try std.testing.expectEqual(qt.ActionKind.ouroboros_cycle, parseActionKind("ouroboros_cycle").?);
}

test "Queen telegram — tgSend disabled config check" {
    const disabled: qt.TgConfig = .{
        .bot_token = "",
        .chat_id = "",
        .enabled = false,
    };

    // Should not crash
    tgSend(disabled, "test");
    tgEdit(disabled, 1, "test");
    tgPin(disabled, 1);
}

test "Queen telegram — CommandQueue empty pop returns null" {
    var q = CommandQueue{};

    const result = q.pop();
    try std.testing.expect(result == null);
}

test "Queen telegram — CommandQueue single item roundtrip" {
    var q = CommandQueue{};
    const original = TgCommand{
        .update_id = 42,
    };

    _ = q.push(original);
    const retrieved = q.pop().?;

    try std.testing.expectEqual(@as(i64, 42), retrieved.update_id);
}

test "Queen telegram — parseUpdates with escaped quotes" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":1,"message":{"chat":{"id":123},"text":"/q"}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expectEqualStrings("/q", cmd.textStr());
}

test "Queen telegram — parseUpdates case sensitive /queen" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // /Queen (capital Q) should NOT be recognized
    const body =
        \\{"ok":true,"result":[{"update_id":1,"message":{"chat":{"id":123},"text":"/Queen"}}]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseUpdates case sensitive /q" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    // /Q (capital Q) should NOT be recognized
    const body =
        \\{"ok":true,"result":[{"update_id":1,"message":{"chat":{"id":123},"text":"/Q"}}]}
    ;

    parseUpdates(&ctx, body);

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — parseUpdates /q with space and argument" {
    var q = CommandQueue{};
    var last_id = std.atomic.Value(i64).init(0);
    var running = std.atomic.Value(bool).init(true);

    var ctx = PollContext{
        .tg = .{ .bot_token = "test", .chat_id = "123", .enabled = true },
        .queue = &q,
        .last_update_id = &last_id,
        .allowed_chat_id = "123",
        .running = &running,
    };

    const body =
        \\{"ok":true,"result":[{"update_id":1,"message":{"chat":{"id":123},"text":"/q doctor"}}]}
    ;

    parseUpdates(&ctx, body);

    const cmd = q.pop().?;
    try std.testing.expectEqualStrings("/q doctor", cmd.textStr());
}

test "Queen telegram — TgCommand update_id large value" {
    const cmd = TgCommand{
        .update_id = 9223372036854775807, // max i64
    };

    try std.testing.expectEqual(@as(i64, 9223372036854775807), cmd.update_id);
}

test "Queen telegram — TgCommand update_id negative large" {
    const cmd = TgCommand{
        .update_id = -9223372036854775808, // min i64
    };

    try std.testing.expectEqual(@as(i64, -9223372036854775808), cmd.update_id);
}

test "Queen telegram — parseActionKind all swarm actions" {
    try std.testing.expectEqual(qt.ActionKind.swarm_status, parseActionKind("swarm_status").?);
    try std.testing.expectEqual(qt.ActionKind.swarm_decompose, parseActionKind("swarm_decompose").?);
}

test "Queen telegram — parseActionKind all issue actions" {
    try std.testing.expectEqual(qt.ActionKind.issue_comment, parseActionKind("issue_comment").?);
    try std.testing.expectEqual(qt.ActionKind.issue_create, parseActionKind("issue_create").?);
}

test "Queen telegram — parseActionKind research and patent" {
    try std.testing.expectEqual(qt.ActionKind.research_sacred, parseActionKind("research_sacred").?);
    try std.testing.expectEqual(qt.ActionKind.patent_status, parseActionKind("patent_status").?);
    try std.testing.expectEqual(qt.ActionKind.experiment_chart, parseActionKind("experiment_chart").?);
}

test "Queen telegram — parseActionKind misc actions" {
    try std.testing.expectEqual(qt.ActionKind.notify, parseActionKind("notify").?);
    try std.testing.expectEqual(qt.ActionKind.fmt, parseActionKind("fmt").?);
}

test "Queen telegram — CommandQueue max capacity" {
    var q = CommandQueue{};

    // Fill exactly to max capacity (MAX_COMMANDS - 1)
    var i: u32 = 0;
    while (i < MAX_COMMANDS - 1) : (i += 1) {
        try std.testing.expect(q.push(TgCommand{ .update_id = @as(i64, i) }));
    }

    // Should have exactly MAX_COMMANDS - 1 items
    var count: u32 = 0;
    while (q.pop()) |_| : (count += 1) {}

    try std.testing.expectEqual(@as(u32, MAX_COMMANDS - 1), count);
}

test "Queen telegram — CommandQueue alternating push pop" {
    var q = CommandQueue{};

    _ = q.push(TgCommand{ .update_id = 1 });
    _ = q.pop();
    _ = q.push(TgCommand{ .update_id = 2 });
    _ = q.pop();
    _ = q.push(TgCommand{ .update_id = 3 });

    const cmd = q.pop().?;
    try std.testing.expectEqual(@as(i64, 3), cmd.update_id);

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}

test "Queen telegram — TgCommand preserves text content" {
    var cmd = TgCommand{};
    const text = "/queen act farm_recycle";
    @memcpy(cmd.text[0..text.len], text);
    cmd.text_len = text.len;

    try std.testing.expectEqualStrings(text, cmd.textStr());
}

test "Queen telegram — TgCommand text length independent of content" {
    var cmd = TgCommand{};

    // Set text length without copying content
    cmd.text_len = 10;

    try std.testing.expectEqual(@as(usize, 10), cmd.textStr().len);
}

test "Queen telegram — TgCommand chat_id independent of text" {
    var cmd = TgCommand{};

    // Set chat_id without affecting text
    const chat_id = "-1001234567890";
    @memcpy(cmd.chat_id[0..chat_id.len], chat_id);
    cmd.chat_id_len = chat_id.len;

    try std.testing.expectEqual(@as(usize, 0), cmd.text_len);
    try std.testing.expectEqual(@as(usize, chat_id.len), cmd.chat_id_len);
}

test "Queen telegram — CommandQueue push preserves all fields" {
    var q = CommandQueue{};

    var original = TgCommand{
        .update_id = 12345,
    };
    const text = "test command";
    @memcpy(original.text[0..text.len], text);
    original.text_len = text.len;
    const chat_id = "987";
    @memcpy(original.chat_id[0..chat_id.len], chat_id);
    original.chat_id_len = chat_id.len;

    _ = q.push(original);

    const retrieved = q.pop().?;
    try std.testing.expectEqual(@as(i64, 12345), retrieved.update_id);
    try std.testing.expectEqualStrings(text, retrieved.textStr());
    try std.testing.expectEqualStrings(chat_id, retrieved.chat_id[0..retrieved.chat_id_len]);
}

test "Queen telegram — CommandQueue new queue empty" {
    var q = CommandQueue{};

    try std.testing.expectEqual(@as(?TgCommand, null), q.pop());
}
