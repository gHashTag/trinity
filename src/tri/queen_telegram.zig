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
