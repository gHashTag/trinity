// tui.zig — Terminal UI for tri-api interactive mode
// ANSI colored output, prompt input, streaming support.
// Issue #66: Phase 7A TUI
const std = @import("std");

// ANSI escape codes
const esc_reset = "\x1b[0m";
const esc_bold = "\x1b[1m";
const esc_dim = "\x1b[2m";
const esc_cyan = "\x1b[36m";
const esc_yellow = "\x1b[33m";
const esc_red = "\x1b[31m";
const esc_green = "\x1b[32m";
const esc_magenta = "\x1b[35m";
const esc_clear_line = "\x1b[2K\r";

pub const Tui = struct {
    allocator: std.mem.Allocator,
    use_color: bool,
    stdout: std.fs.File,
    stdin: std.fs.File,

    pub fn init(allocator: std.mem.Allocator) Tui {
        const stdout = std.fs.File.stdout();
        const stdin = std.fs.File.stdin();
        // Detect if stdout is a TTY for color support
        const use_color = stdout.isTty();
        return .{
            .allocator = allocator,
            .use_color = use_color,
            .stdout = stdout,
            .stdin = stdin,
        };
    }

    // ─── Output ──────────────────────────────────────────────────────────

    /// Print welcome banner on startup.
    pub fn printBanner(self: *Tui, model: []const u8, perm_count: u32) void {
        self.writeColor(esc_bold);
        self.writeColor(esc_cyan);
        self.writeStr("TRI-API");
        self.writeColor(esc_reset);
        self.writeStr(" v1.0 \xe2\x80\x94 Direct Anthropic API Agent\n");
        self.writeColor(esc_dim);
        var buf: [256]u8 = undefined;
        const info = std.fmt.bufPrint(&buf, "model: {s} | permissions: {d} rules | /quit to exit\n", .{ model, perm_count }) catch return;
        self.writeStr(info);
        self.writeColor(esc_reset);
        self.writeStr("\n");
        self.flush();
    }

    /// Print assistant text (cyan).
    pub fn printAssistant(self: *Tui, text: []const u8) void {
        self.writeColor(esc_cyan);
        self.writeStr(text);
        self.writeStr("\n");
        self.writeColor(esc_reset);
        self.flush();
    }

    /// Print tool invocation (yellow).
    pub fn printTool(self: *Tui, name: []const u8, arg: []const u8) void {
        self.writeColor(esc_yellow);
        self.writeStr("\xe2\x9a\x99 ");
        self.writeStr(name);
        self.writeColor(esc_dim);
        if (arg.len > 0) {
            self.writeStr(": ");
            const truncated = if (arg.len > 80) arg[0..80] else arg;
            self.writeStr(truncated);
            if (arg.len > 80) self.writeStr("...");
        }
        self.writeStr("\n");
        self.writeColor(esc_reset);
        self.flush();
    }

    /// Print error (red).
    pub fn printError(self: *Tui, text: []const u8) void {
        self.writeColor(esc_red);
        self.writeStr("\xe2\x9d\x8c ");
        self.writeStr(text);
        self.writeStr("\n");
        self.writeColor(esc_reset);
        self.flush();
    }

    /// Print permission denied (red + bold).
    pub fn printDenied(self: *Tui, tool: []const u8, arg: []const u8) void {
        self.writeColor(esc_red);
        self.writeColor(esc_bold);
        self.writeStr("\xe2\x9b\x94 DENIED: ");
        self.writeStr(tool);
        self.writeStr("(");
        self.writeStr(arg);
        self.writeStr(")\n");
        self.writeColor(esc_reset);
        self.flush();
    }

    /// Print token stats (dim).
    pub fn printTokens(self: *Tui, input_tokens: u32, output_tokens: u32) void {
        self.writeColor(esc_dim);
        var buf: [128]u8 = undefined;
        const stats = std.fmt.bufPrint(&buf, "   [{d} in / {d} out tokens]\n", .{ input_tokens, output_tokens }) catch return;
        self.writeStr(stats);
        self.writeColor(esc_reset);
        self.flush();
    }

    /// Print session info (green).
    pub fn printSession(self: *Tui, text: []const u8) void {
        self.writeColor(esc_green);
        self.writeStr(text);
        self.writeStr("\n");
        self.writeColor(esc_reset);
        self.flush();
    }

    /// Print MCP server connection (magenta).
    pub fn printMcp(self: *Tui, server_name: []const u8, tool_count: u32) void {
        self.writeColor(esc_magenta);
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "\xe2\x9a\xa1 MCP: {s} ({d} tools)\n", .{ server_name, tool_count }) catch return;
        self.writeStr(msg);
        self.writeColor(esc_reset);
        self.flush();
    }

    // ─── Input ───────────────────────────────────────────────────────────

    /// Display prompt and read a line. Returns null on EOF.
    /// Caller owns returned memory.
    pub fn readPrompt(self: *Tui) ?[]const u8 {
        self.writeColor(esc_bold);
        self.writeColor(esc_green);
        self.writeStr("tri> ");
        self.writeColor(esc_reset);
        self.flush();

        return self.readLine();
    }

    /// Read a line from stdin. Caller owns memory. Returns null on EOF.
    fn readLine(self: *Tui) ?[]const u8 {
        var line_buf: std.ArrayList(u8) = .empty;
        var read_buf: [1]u8 = undefined;

        while (true) {
            const bytes_read = self.stdin.read(&read_buf) catch return null;
            if (bytes_read == 0) {
                // EOF
                if (line_buf.items.len == 0) {
                    line_buf.deinit(self.allocator);
                    return null;
                }
                break;
            }
            if (read_buf[0] == '\n') break;
            if (read_buf[0] == '\r') continue; // skip CR
            line_buf.append(self.allocator, read_buf[0]) catch return null;
        }

        // Trim trailing whitespace
        var end = line_buf.items.len;
        while (end > 0 and (line_buf.items[end - 1] == ' ' or line_buf.items[end - 1] == '\t')) : (end -= 1) {}

        if (end == 0) {
            line_buf.deinit(self.allocator);
            return null;
        }

        // Transfer ownership
        return line_buf.toOwnedSlice(self.allocator) catch null;
    }

    // ─── Internal ────────────────────────────────────────────────────────

    fn writeStr(self: *Tui, s: []const u8) void {
        _ = self.stdout.write(s) catch {};
    }

    fn writeColor(self: *Tui, code: []const u8) void {
        if (self.use_color) {
            _ = self.stdout.write(code) catch {};
        }
    }

    fn flush(self: *Tui) void {
        // stdout is unbuffered for File, but sync just in case
        _ = self.stdout.sync() catch {};
    }
};
