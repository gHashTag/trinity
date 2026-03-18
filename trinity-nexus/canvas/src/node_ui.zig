// =============================================================================
// TRINITY NODE UI - Raylib Dashboard
// Native desktop UI for decentralized inference node
// V = n x 3^k x pi^m x phi^p x e^q
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const wallet_mod = @import("wallet.zig");
const network_mod = @import("network.zig");
const config_mod = @import("config.zig");

// =============================================================================
// WINDOW CONSTANTS
// =============================================================================

pub const WINDOW_WIDTH: c_int = 1280;
pub const WINDOW_HEIGHT: c_int = 800;
const SIDEBAR_WIDTH: c_int = 220;
const TITLE_BAR_HEIGHT: c_int = 50;
const PADDING: c_int = 16;
const CARD_HEIGHT: c_int = 80;
const CARD_GAP: c_int = 12;

// =============================================================================
// TRINITY WEBSITE THEME (from website/src/index.css)
// Pure black + green accent (#00FF88) - matches trinity-site-one.vercel.app
// =============================================================================

pub const THEME = struct {
    // Backgrounds (from CSS: --bg: #000000, cards: rgba(255,255,255,0.03))
    pub const BG_WINDOW = rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF }; // Pure black
    pub const BG_SIDEBAR = rl.Color{ .r = 0x05, .g = 0x05, .b = 0x05, .a = 0xFF }; // Slightly lighter
    pub const BG_PANEL = rl.Color{ .r = 0x08, .g = 0x08, .b = 0x08, .a = 0xFF }; // Glass effect base
    pub const BG_CARD = rl.Color{ .r = 0x0A, .g = 0x0A, .b = 0x0A, .a = 0xFF }; // rgba(255,255,255,0.03)
    pub const BG_CARD_HOVER = rl.Color{ .r = 0x12, .g = 0x12, .b = 0x12, .a = 0xFF }; // Hover state
    pub const BG_INPUT = rl.Color{ .r = 0x08, .g = 0x08, .b = 0x08, .a = 0xFF }; // Input fields

    // Accent Colors (from CSS: --accent: #00FF88, --accent-dark: #00CC66)
    pub const ACCENT = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = 0xFF }; // #00FF88 green
    pub const ACCENT_DARK = rl.Color{ .r = 0x00, .g = 0xCC, .b = 0x66, .a = 0xFF }; // #00CC66
    pub const GOLDEN = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF }; // #FFD700
    pub const PURPLE = rl.Color{ .r = 0x8B, .g = 0x5C, .b = 0xF6, .a = 0xFF }; // Secondary

    // Text Colors (from CSS: --text: #FFFFFF, --muted: #888888)
    pub const TEXT_PRIMARY = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF }; // Pure white
    pub const TEXT_SECONDARY = rl.Color{ .r = 0xAA, .g = 0xAA, .b = 0xAA, .a = 0xFF }; // Light gray
    pub const TEXT_MUTED = rl.Color{ .r = 0x88, .g = 0x88, .b = 0x88, .a = 0xFF }; // #888888

    // Status Colors (traffic lights + status indicators)
    pub const TRAFFIC_RED = rl.Color{ .r = 0xFF, .g = 0x5F, .b = 0x57, .a = 0xFF };
    pub const TRAFFIC_YELLOW = rl.Color{ .r = 0xFE, .g = 0xBC, .b = 0x2E, .a = 0xFF };
    pub const TRAFFIC_GREEN = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = 0xFF }; // Match accent

    pub const STATUS_SUCCESS = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = 0xFF }; // #00FF88
    pub const STATUS_WARNING = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF }; // Golden
    pub const STATUS_ERROR = rl.Color{ .r = 0xEF, .g = 0x44, .b = 0x44, .a = 0xFF };

    // Borders (from CSS: --border: rgba(255,255,255,0.08))
    pub const BORDER = rl.Color{ .r = 0x14, .g = 0x14, .b = 0x14, .a = 0xFF }; // ~8% white on black
    pub const BORDER_HOVER = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = 0xFF }; // Accent on hover

    // Legacy alias for compatibility
    pub const TEAL = ACCENT;
};

// =============================================================================
// FONT SIZES - Single Source of Truth (Apple SF Pro style)
// =============================================================================

pub const FONTS = struct {
    // Titles
    pub const TITLE_LARGE: c_int = 36; // Page titles (Dashboard, Settings, etc)
    pub const TITLE_MEDIUM: c_int = 28; // Section titles
    pub const TITLE_SMALL: c_int = 24; // Panel titles

    // Headers
    pub const HEADER: c_int = 20; // Card headers, panel headers
    pub const SUBHEADER: c_int = 18; // Sub-sections

    // Body text
    pub const BODY_LARGE: c_int = 16; // Primary content
    pub const BODY: c_int = 14; // Regular text
    pub const BODY_SMALL: c_int = 12; // Secondary content

    // Special
    pub const STAT_VALUE: c_int = 32; // Big numbers (balance, etc)
    pub const STAT_LABEL: c_int = 14; // Labels for stats
    pub const NAV_ITEM: c_int = 16; // Sidebar navigation
    pub const FOOTER: c_int = 14; // Footer text
    pub const HINT: c_int = 12; // Hints, timestamps
};

// =============================================================================
// SCREEN ENUM
// =============================================================================

pub const Screen = enum {
    dashboard,
    settings,
    wallet,
    logs,
};

// =============================================================================
// NAV ITEMS
// =============================================================================

const NavItem = struct {
    icon: [*:0]const u8,
    label: [*:0]const u8,
    screen: Screen,
};

const NAV_ITEMS = [_]NavItem{
    .{ .icon = "[D]", .label = "Dashboard", .screen = .dashboard },
    .{ .icon = "[S]", .label = "Settings", .screen = .settings },
    .{ .icon = "[W]", .label = "Wallet", .screen = .wallet },
    .{ .icon = "[L]", .label = "Logs", .screen = .logs },
};

// =============================================================================
// LOG ENTRY
// =============================================================================

pub const LogEntry = struct {
    timestamp: i64,
    level: LogLevel,
    message: [256]u8,
    message_len: usize,

    pub const LogLevel = enum {
        info,
        warning,
        error_level,
        success,

        pub fn getColor(self: LogLevel) rl.Color {
            return switch (self) {
                .info => THEME.TEXT_SECONDARY,
                .warning => THEME.STATUS_WARNING,
                .error_level => THEME.STATUS_ERROR,
                .success => THEME.STATUS_SUCCESS,
            };
        }

        pub fn getPrefix(self: LogLevel) [*:0]const u8 {
            return switch (self) {
                .info => "[INFO]",
                .warning => "[WARN]",
                .error_level => "[ERR]",
                .success => "[OK]",
            };
        }
    };
};

// =============================================================================
// TRINITY NODE UI
// =============================================================================

pub const TrinityNodeUI = struct {
    allocator: std.mem.Allocator,
    wallet: *wallet_mod.Wallet,
    network: *network_mod.NetworkNode,
    config: config_mod.Config,

    // UI State
    current_screen: Screen,
    selected_nav: usize,

    // Logs ring buffer
    logs: [100]LogEntry,
    log_head: usize,
    log_count: usize,

    // Settings input
    port_input: [8]u8,
    port_input_len: usize,
    model_path_input: [256]u8,
    model_path_len: usize,

    // Animation
    pulse_time: f32,

    // Custom font (loaded at runtime)
    custom_font: rl.Font,
    font_loaded: bool,

    // Screen dimensions (updated for fullscreen)
    screen_width: c_int,
    screen_height: c_int,

    pub fn init(
        allocator: std.mem.Allocator,
        wallet: *wallet_mod.Wallet,
        network: *network_mod.NetworkNode,
    ) TrinityNodeUI {
        var ui = TrinityNodeUI{
            .allocator = allocator,
            .wallet = wallet,
            .network = network,
            .config = config_mod.Config{},
            .current_screen = .dashboard,
            .selected_nav = 0,
            .logs = undefined,
            .log_head = 0,
            .log_count = 0,
            .port_input = undefined,
            .port_input_len = 0,
            .model_path_input = undefined,
            .model_path_len = 0,
            .pulse_time = 0,
            .custom_font = undefined,
            .font_loaded = false,
            .screen_width = WINDOW_WIDTH,
            .screen_height = WINDOW_HEIGHT,
        };

        // Initialize port input with default
        const port_str = std.fmt.bufPrint(&ui.port_input, "{d}", .{ui.config.job_port}) catch "9334";
        ui.port_input_len = port_str.len;

        // Initialize model path
        const model_path = ui.config.model_path;
        @memcpy(ui.model_path_input[0..model_path.len], model_path);
        ui.model_path_len = model_path.len;

        // Add startup log
        ui.addLog(.success, "Trinity Node UI initialized");

        return ui;
    }

    pub fn addLog(self: *TrinityNodeUI, level: LogEntry.LogLevel, message: []const u8) void {
        const idx = (self.log_head + self.log_count) % 100;
        self.logs[idx] = LogEntry{
            .timestamp = std.time.timestamp(),
            .level = level,
            .message = undefined,
            .message_len = @min(message.len, 255),
        };
        @memcpy(self.logs[idx].message[0..self.logs[idx].message_len], message[0..self.logs[idx].message_len]);

        if (self.log_count < 100) {
            self.log_count += 1;
        } else {
            self.log_head = (self.log_head + 1) % 100;
        }
    }

    pub fn run(self: *TrinityNodeUI) void {
        // Get monitor native resolution BEFORE creating window
        const monitor = rl.GetCurrentMonitor();
        const monitor_width = rl.GetMonitorWidth(monitor);
        const monitor_height = rl.GetMonitorHeight(monitor);

        // Use borderless fullscreen for native resolution + MSAA for quality
        rl.SetConfigFlags(rl.FLAG_BORDERLESS_WINDOWED_MODE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
        rl.InitWindow(monitor_width, monitor_height, "TRINITY NODE | phi^2 + 1/phi^2 = 3");
        defer rl.CloseWindow();

        // Set to native resolution
        self.screen_width = monitor_width;
        self.screen_height = monitor_height;

        // Load Apple SF Pro font at HIGH resolution for crisp rendering
        // SF Pro = Apple's standard system font (best for macOS apps)
        // Using 128px base size for extra high quality scaling on Retina displays
        const font_paths = [_][*:0]const u8{
            "assets/fonts/SFPro.ttf", // Apple SF Pro - BEST
            "assets/fonts/SFCompact.ttf", // Apple SF Compact
            "assets/fonts/Outfit-Regular.ttf", // Website font
            "assets/fonts/Roboto-Regular.ttf", // Fallback
        };
        for (font_paths) |path| {
            // LoadFontEx: path, baseSize, codepoints, codepointCount
            // Using 128px base for Retina quality (2x scale)
            const font = rl.LoadFontEx(path, 128, null, 0);
            if (font.texture.id != 0) {
                self.custom_font = font;
                self.font_loaded = true;
                // Trilinear filtering for best quality with mipmaps
                rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_TRILINEAR);
                break;
            }
        }
        defer if (self.font_loaded) rl.UnloadFont(self.custom_font);

        rl.SetTargetFPS(60);

        // Main loop
        while (!rl.WindowShouldClose()) {
            // Update screen dimensions on resize
            self.screen_width = rl.GetScreenWidth();
            self.screen_height = rl.GetScreenHeight();

            // Toggle borderless windowed with F11
            if (rl.IsKeyPressed(rl.KEY_F11)) {
                rl.ToggleBorderlessWindowed();
            }

            self.update();
            self.draw();
        }
    }

    fn update(self: *TrinityNodeUI) void {
        // Update animation time
        self.pulse_time += rl.GetFrameTime();
        if (self.pulse_time > 2.0) self.pulse_time = 0;

        // Handle navigation clicks
        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();

        if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            // Check nav items - must match drawSidebar() positioning
            for (NAV_ITEMS, 0..) |item, i| {
                const item_y = TITLE_BAR_HEIGHT + PADDING + @as(c_int, @intCast(i)) * 44;
                if (mouse_x >= 0 and mouse_x < SIDEBAR_WIDTH and
                    mouse_y >= item_y and mouse_y < item_y + 40)
                {
                    self.selected_nav = i;
                    self.current_screen = item.screen;
                }
            }
        }

        // Poll network
        self.network.poll();
    }

    /// Draw text with custom font if available (high quality)
    fn drawText(self: *TrinityNodeUI, text: [*:0]const u8, x: c_int, y: c_int, size: c_int, color: rl.Color) void {
        if (self.font_loaded) {
            const font_size: f32 = @floatFromInt(size);
            // Spacing proportional to font size for clean look
            const spacing: f32 = font_size * 0.05;
            rl.DrawTextEx(self.custom_font, text, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, font_size, spacing, color);
        } else {
            rl.DrawText(text, x, y, size, color);
        }
    }

    fn draw(self: *TrinityNodeUI) void {
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(THEME.BG_WINDOW);

        // Draw components using dynamic screen size
        self.drawTitleBar();
        self.drawSidebar();

        // Draw current screen
        switch (self.current_screen) {
            .dashboard => self.drawDashboard(),
            .settings => self.drawSettings(),
            .wallet => self.drawWalletScreen(),
            .logs => self.drawLogsScreen(),
        }

        // Footer
        self.drawFooter();
    }

    fn drawTitleBar(self: *TrinityNodeUI) void {
        rl.DrawRectangle(0, 0, self.screen_width, TITLE_BAR_HEIGHT, THEME.BG_SIDEBAR);

        // Title centered - clean design without traffic lights
        self.drawText("TRINITY NODE", PADDING, TITLE_BAR_HEIGHT / 2 - 12, 26, THEME.ACCENT);
        self.drawText("v0.1.0", 200, TITLE_BAR_HEIGHT / 2 - 8, 18, THEME.TEXT_MUTED);

        // Status indicator
        const status_color = THEME.TRAFFIC_GREEN;
        rl.DrawCircle(self.screen_width - 100, TITLE_BAR_HEIGHT / 2, 5, status_color);
        self.drawText("Ready", self.screen_width - 90, TITLE_BAR_HEIGHT / 2 - 6, 14, THEME.TEXT_SECONDARY);

        // Border
        rl.DrawLine(0, TITLE_BAR_HEIGHT, self.screen_width, TITLE_BAR_HEIGHT, THEME.BORDER);
    }

    fn drawSidebar(self: *TrinityNodeUI) void {
        const y_start = TITLE_BAR_HEIGHT;
        const height = self.screen_height - TITLE_BAR_HEIGHT - 40;

        rl.DrawRectangle(0, y_start, SIDEBAR_WIDTH, height, THEME.BG_SIDEBAR);

        // Nav items - no logo duplication, title is in header
        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();

        for (NAV_ITEMS, 0..) |item, i| {
            const item_y = y_start + PADDING + @as(c_int, @intCast(i)) * 44;
            const is_selected = self.selected_nav == i;
            const is_hovered = mouse_x >= 0 and mouse_x < SIDEBAR_WIDTH and
                mouse_y >= item_y and mouse_y < item_y + 40;

            const bg_color = if (is_selected) THEME.BG_CARD else if (is_hovered) THEME.BG_CARD_HOVER else THEME.BG_SIDEBAR;
            const text_color = if (is_selected) THEME.ACCENT else THEME.TEXT_SECONDARY;

            rl.DrawRectangle(0, item_y, SIDEBAR_WIDTH, 40, bg_color);

            // Active indicator
            if (is_selected) {
                rl.DrawRectangle(0, item_y, 3, 40, THEME.ACCENT);
            }

            self.drawText(item.icon, PADDING, item_y + 12, FONTS.NAV_ITEM, text_color);
            self.drawText(item.label, PADDING + 40, item_y + 12, FONTS.NAV_ITEM, text_color);
        }

        // Vertical border
        rl.DrawLine(SIDEBAR_WIDTH - 1, y_start, SIDEBAR_WIDTH - 1, y_start + height, THEME.BORDER);
    }

    fn drawDashboard(self: *TrinityNodeUI) void {
        const x_start = SIDEBAR_WIDTH + PADDING;
        const y_start = TITLE_BAR_HEIGHT + PADDING;
        const width = self.screen_width - SIDEBAR_WIDTH - PADDING * 2;

        // Title with custom font - LARGE
        self.drawText("Dashboard", x_start, y_start, 36, THEME.TEXT_PRIMARY);

        // Stats cards row
        const card_width = @divTrunc(width - CARD_GAP * 3, 4);
        var card_x = x_start;
        const card_y = y_start + 50;

        // Card 1: Balance
        self.drawStatCard(card_x, card_y, card_width, "Balance", self.formatBalance(), THEME.GOLDEN);
        card_x += card_width + CARD_GAP;

        // Card 2: Peers
        var peers_buf: [32]u8 = undefined;
        const peers_str = std.fmt.bufPrintZ(&peers_buf, "{d}", .{self.network.discovery_service.getPeerCount()}) catch "0";
        self.drawStatCard(card_x, card_y, card_width, "Peers", peers_str, THEME.ACCENT);
        card_x += card_width + CARD_GAP;

        // Card 3: Jobs Completed
        var jobs_buf: [32]u8 = undefined;
        const jobs_str = std.fmt.bufPrintZ(&jobs_buf, "{d}", .{self.network.jobs_completed}) catch "0";
        self.drawStatCard(card_x, card_y, card_width, "Jobs Done", jobs_str, THEME.STATUS_SUCCESS);
        card_x += card_width + CARD_GAP;

        // Card 4: Uptime
        const stats = self.network.getStats();
        var uptime_buf: [32]u8 = undefined;
        const uptime_str = std.fmt.bufPrintZ(&uptime_buf, "{d}s", .{stats.uptime_seconds}) catch "0s";
        self.drawStatCard(card_x, card_y, card_width, "Uptime", uptime_str, THEME.PURPLE);

        // Network Status Panel
        const panel_y = card_y + CARD_HEIGHT + PADDING * 2;
        self.drawNetworkPanel(x_start, panel_y, @divTrunc(width, 2) - PADDING, 200);

        // Earnings Panel
        self.drawEarningsPanel(x_start + @divTrunc(width, 2) + PADDING, panel_y, @divTrunc(width, 2) - PADDING, 200);

        // Recent Activity
        const activity_y = panel_y + 200 + PADDING;
        self.drawActivityPanel(x_start, activity_y, width, 200);
    }

    fn drawStatCard(self: *TrinityNodeUI, x: c_int, y: c_int, w: c_int, label: [*:0]const u8, value: [*:0]const u8, accent: rl.Color) void {
        // Background
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(CARD_HEIGHT),
        }, 0.1, 8, THEME.BG_CARD);

        // Accent bar
        rl.DrawRectangle(x, y, 4, CARD_HEIGHT, accent);

        // Label - using FONTS config
        self.drawText(label, x + PADDING, y + 12, FONTS.STAT_LABEL, THEME.TEXT_MUTED);

        // Value - using FONTS config
        self.drawText(value, x + PADDING, y + 38, FONTS.TITLE_SMALL, THEME.TEXT_PRIMARY);
    }

    fn drawNetworkPanel(self: *TrinityNodeUI, x: c_int, y: c_int, w: c_int, h: c_int) void {
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        }, 0.05, 8, THEME.BG_PANEL);

        self.drawText("Network Status", x + PADDING, y + PADDING, FONTS.HEADER, THEME.ACCENT);

        const stats = self.network.getStats();

        // Status
        var status_buf: [32]u8 = undefined;
        const status_str = std.fmt.bufPrintZ(&status_buf, "Status: {s}", .{@tagName(stats.status)}) catch "Status: unknown";
        self.drawText(status_str, x + PADDING, y + 50, FONTS.BODY, THEME.TEXT_SECONDARY);

        // Peers
        var peers_buf: [32]u8 = undefined;
        const peers_str = std.fmt.bufPrintZ(&peers_buf, "Connected Peers: {d}", .{stats.peer_count}) catch "Peers: 0";
        self.drawText(peers_str, x + PADDING, y + 75, FONTS.BODY, THEME.TEXT_SECONDARY);

        // Jobs
        var jobs_buf: [64]u8 = undefined;
        const jobs_str = std.fmt.bufPrintZ(&jobs_buf, "Jobs: {d} received / {d} completed", .{ stats.jobs_received, stats.jobs_completed }) catch "Jobs: 0";
        self.drawText(jobs_str, x + PADDING, y + 100, FONTS.BODY, THEME.TEXT_SECONDARY);

        // Pending
        var pending_buf: [32]u8 = undefined;
        const pending_str = std.fmt.bufPrintZ(&pending_buf, "Pending: {d}", .{stats.pending_jobs}) catch "Pending: 0";
        self.drawText(pending_str, x + PADDING, y + 125, FONTS.BODY, THEME.TEXT_SECONDARY);

        // Port
        var port_buf: [32]u8 = undefined;
        const port_str = std.fmt.bufPrintZ(&port_buf, "Port: {d}", .{self.network.listen_port}) catch "Port: 9334";
        self.drawText(port_str, x + PADDING, y + 150, FONTS.BODY, THEME.TEXT_MUTED);
    }

    fn drawEarningsPanel(self: *TrinityNodeUI, x: c_int, y: c_int, w: c_int, h: c_int) void {
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        }, 0.05, 8, THEME.BG_PANEL);

        self.drawText("Earnings", x + PADDING, y + PADDING, FONTS.HEADER, THEME.GOLDEN);

        const wallet_stats = self.wallet.getStats();

        // Balance
        var balance_buf: [64]u8 = undefined;
        const balance_str = std.fmt.bufPrintZ(&balance_buf, "Balance: {d:.6} $TRI", .{self.wallet.getBalanceFormatted()}) catch "Balance: 0";
        self.drawText(balance_str, x + PADDING, y + 50, FONTS.BODY, THEME.TEXT_PRIMARY);

        // Pending
        var pending_buf: [64]u8 = undefined;
        const pending_str = std.fmt.bufPrintZ(&pending_buf, "Pending: {d:.6} $TRI", .{self.wallet.getPendingFormatted()}) catch "Pending: 0";
        self.drawText(pending_str, x + PADDING, y + 75, FONTS.BODY, THEME.STATUS_WARNING);

        // Total earned
        var total_buf: [64]u8 = undefined;
        const total_str = std.fmt.bufPrintZ(&total_buf, "Total Earned: {d:.6} $TRI", .{self.wallet.getTotalEarnedFormatted()}) catch "Total: 0";
        self.drawText(total_str, x + PADDING, y + 100, FONTS.BODY, THEME.STATUS_SUCCESS);

        // Jobs completed
        var jobs_buf: [32]u8 = undefined;
        const jobs_str = std.fmt.bufPrintZ(&jobs_buf, "Jobs Completed: {d}", .{wallet_stats.jobs_completed}) catch "Jobs: 0";
        self.drawText(jobs_str, x + PADDING, y + 125, FONTS.BODY, THEME.TEXT_SECONDARY);

        // Tokens generated
        var tokens_buf: [32]u8 = undefined;
        const tokens_str = std.fmt.bufPrintZ(&tokens_buf, "Tokens Generated: {d}", .{wallet_stats.tokens_generated}) catch "Tokens: 0";
        self.drawText(tokens_str, x + PADDING, y + 150, FONTS.BODY, THEME.TEXT_MUTED);
    }

    fn drawActivityPanel(self: *TrinityNodeUI, x: c_int, y: c_int, w: c_int, h: c_int) void {
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        }, 0.05, 8, THEME.BG_PANEL);

        self.drawText("Recent Activity", x + PADDING, y + PADDING, FONTS.HEADER, THEME.ACCENT);

        // Show last 5 logs
        var line_y = y + 50;
        const max_logs = @min(self.log_count, 5);
        var i: usize = 0;
        while (i < max_logs) : (i += 1) {
            const log_idx = if (self.log_count >= 100)
                (self.log_head + self.log_count - 1 - i) % 100
            else if (self.log_count > i)
                self.log_count - 1 - i
            else
                break;

            const entry = &self.logs[log_idx];
            const prefix = entry.level.getPrefix();
            const color = entry.level.getColor();

            self.drawText(prefix, x + PADDING, line_y, FONTS.BODY_SMALL, color);

            var msg_buf: [256]u8 = undefined;
            const msg_len = @min(entry.message_len, 255);
            @memcpy(msg_buf[0..msg_len], entry.message[0..msg_len]);
            msg_buf[msg_len] = 0;
            self.drawText(@ptrCast(&msg_buf), x + PADDING + 60, line_y, FONTS.BODY_SMALL, THEME.TEXT_SECONDARY);

            line_y += 24;
        }
    }

    fn drawSettings(self: *TrinityNodeUI) void {
        const x_start = SIDEBAR_WIDTH + PADDING;
        const y_start = TITLE_BAR_HEIGHT + PADDING;
        const width = WINDOW_WIDTH - SIDEBAR_WIDTH - PADDING * 2;

        self.drawText("Settings", x_start, y_start, FONTS.TITLE_LARGE, THEME.TEXT_PRIMARY);

        // Network Settings Panel
        const panel_y = y_start + 50;
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x_start),
            .y = @floatFromInt(panel_y),
            .width = @floatFromInt(width),
            .height = 200,
        }, 0.05, 8, THEME.BG_PANEL);

        self.drawText("Network", x_start + PADDING, panel_y + PADDING, FONTS.HEADER, THEME.ACCENT);

        // Port setting
        self.drawText("Job Port:", x_start + PADDING, panel_y + 50, FONTS.BODY, THEME.TEXT_SECONDARY);

        // Port input field
        const input_x = x_start + PADDING + 120;
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(input_x),
            .y = @floatFromInt(panel_y + 45),
            .width = 100,
            .height = 28,
        }, 0.2, 8, THEME.BG_INPUT);

        var port_display: [8]u8 = undefined;
        @memcpy(port_display[0..self.port_input_len], self.port_input[0..self.port_input_len]);
        port_display[self.port_input_len] = 0;
        self.drawText(@ptrCast(&port_display), input_x + 10, panel_y + 52, FONTS.BODY, THEME.TEXT_PRIMARY);

        // Model path
        self.drawText("Model Path:", x_start + PADDING, panel_y + 90, FONTS.BODY, THEME.TEXT_SECONDARY);

        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(input_x),
            .y = @floatFromInt(panel_y + 85),
            .width = @floatFromInt(width - 150),
            .height = 28,
        }, 0.2, 8, THEME.BG_INPUT);

        var model_display: [256]u8 = undefined;
        @memcpy(model_display[0..self.model_path_len], self.model_path_input[0..self.model_path_len]);
        model_display[self.model_path_len] = 0;
        self.drawText(@ptrCast(&model_display), input_x + 10, panel_y + 92, FONTS.BODY, THEME.TEXT_PRIMARY);

        // Resource limits
        self.drawText("Max CPU:", x_start + PADDING, panel_y + 130, FONTS.BODY, THEME.TEXT_SECONDARY);
        var cpu_buf: [16]u8 = undefined;
        const cpu_str = std.fmt.bufPrintZ(&cpu_buf, "{d}%", .{self.config.max_cpu_percent}) catch "80%";
        self.drawText(cpu_str, input_x + 10, panel_y + 130, FONTS.BODY, THEME.TEXT_PRIMARY);

        self.drawText("Max Memory:", x_start + PADDING, panel_y + 155, FONTS.BODY, THEME.TEXT_SECONDARY);
        var mem_buf: [16]u8 = undefined;
        const mem_str = std.fmt.bufPrintZ(&mem_buf, "{d} MB", .{self.config.max_memory_mb}) catch "4096 MB";
        self.drawText(mem_str, input_x + 10, panel_y + 155, FONTS.BODY, THEME.TEXT_PRIMARY);
    }

    fn drawWalletScreen(self: *TrinityNodeUI) void {
        const x_start = SIDEBAR_WIDTH + PADDING;
        const y_start = TITLE_BAR_HEIGHT + PADDING;
        const width = WINDOW_WIDTH - SIDEBAR_WIDTH - PADDING * 2;

        self.drawText("Wallet", x_start, y_start, FONTS.TITLE_LARGE, THEME.TEXT_PRIMARY);

        // Address panel
        const panel_y = y_start + 50;
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x_start),
            .y = @floatFromInt(panel_y),
            .width = @floatFromInt(width),
            .height = 120,
        }, 0.05, 8, THEME.BG_PANEL);

        self.drawText("Address", x_start + PADDING, panel_y + PADDING, FONTS.HEADER, THEME.ACCENT);

        const addr_hex = self.wallet.getAddressHex();
        self.drawText(@ptrCast(&addr_hex), x_start + PADDING, panel_y + 50, FONTS.SUBHEADER, THEME.GOLDEN);

        self.drawText("Click to copy", x_start + PADDING, panel_y + 85, FONTS.HINT, THEME.TEXT_MUTED);

        // Balance panel
        const balance_y = panel_y + 140;
        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x_start),
            .y = @floatFromInt(balance_y),
            .width = @floatFromInt(width),
            .height = 180,
        }, 0.05, 8, THEME.BG_PANEL);

        self.drawText("Balance", x_start + PADDING, balance_y + PADDING, FONTS.HEADER, THEME.ACCENT);

        // Main balance - BIG
        var balance_buf: [64]u8 = undefined;
        const balance_str = std.fmt.bufPrintZ(&balance_buf, "{d:.6} $TRI", .{self.wallet.getBalanceFormatted()}) catch "0.000000 $TRI";
        self.drawText(balance_str, x_start + PADDING, balance_y + 50, FONTS.STAT_VALUE, THEME.GOLDEN);

        // Pending
        var pending_buf: [64]u8 = undefined;
        const pending_str = std.fmt.bufPrintZ(&pending_buf, "Pending: {d:.6} $TRI", .{self.wallet.getPendingFormatted()}) catch "Pending: 0";
        self.drawText(pending_str, x_start + PADDING, balance_y + 100, FONTS.BODY, THEME.STATUS_WARNING);

        // Total earned
        var total_buf: [64]u8 = undefined;
        const total_str = std.fmt.bufPrintZ(&total_buf, "Total Earned: {d:.6} $TRI", .{self.wallet.getTotalEarnedFormatted()}) catch "Total: 0";
        self.drawText(total_str, x_start + PADDING, balance_y + 125, FONTS.BODY, THEME.STATUS_SUCCESS);

        // Stats
        const stats = self.wallet.getStats();
        var jobs_buf: [32]u8 = undefined;
        const jobs_str = std.fmt.bufPrintZ(&jobs_buf, "Jobs: {d}", .{stats.jobs_completed}) catch "Jobs: 0";
        self.drawText(jobs_str, x_start + PADDING, balance_y + 150, FONTS.HINT, THEME.TEXT_MUTED);
    }

    fn drawLogsScreen(self: *TrinityNodeUI) void {
        const x_start = SIDEBAR_WIDTH + PADDING;
        const y_start = TITLE_BAR_HEIGHT + PADDING;
        const width = WINDOW_WIDTH - SIDEBAR_WIDTH - PADDING * 2;

        self.drawText("Logs", x_start, y_start, FONTS.TITLE_LARGE, THEME.TEXT_PRIMARY);

        var log_count_buf: [32]u8 = undefined;
        const log_count_str = std.fmt.bufPrintZ(&log_count_buf, "({d} entries)", .{self.log_count}) catch "";
        self.drawText(log_count_str, x_start + 100, y_start + 8, FONTS.BODY, THEME.TEXT_MUTED);

        // Logs panel
        const panel_y = y_start + 60;
        const panel_h = WINDOW_HEIGHT - panel_y - 80;

        rl.DrawRectangleRounded(.{
            .x = @floatFromInt(x_start),
            .y = @floatFromInt(panel_y),
            .width = @floatFromInt(width),
            .height = @floatFromInt(panel_h),
        }, 0.02, 8, THEME.BG_PANEL);

        // Show logs
        var line_y = panel_y + PADDING;
        const max_visible = @min(self.log_count, @as(usize, @intCast(@divFloor(panel_h - PADDING * 2, 24))));

        var i: usize = 0;
        while (i < max_visible) : (i += 1) {
            const log_idx = if (self.log_count >= 100)
                (self.log_head + self.log_count - 1 - i) % 100
            else if (self.log_count > i)
                self.log_count - 1 - i
            else
                break;

            const entry = &self.logs[log_idx];
            const prefix = entry.level.getPrefix();
            const color = entry.level.getColor();

            // Timestamp
            var time_buf: [16]u8 = undefined;
            const time_str = std.fmt.bufPrintZ(&time_buf, "{d}", .{@as(u32, @intCast(@mod(entry.timestamp, 86400)))}) catch "0";
            self.drawText(time_str, x_start + PADDING, line_y, FONTS.HINT, THEME.TEXT_MUTED);

            // Level
            self.drawText(prefix, x_start + PADDING + 70, line_y, FONTS.BODY_SMALL, color);

            // Message
            var msg_buf: [256]u8 = undefined;
            const msg_len = @min(entry.message_len, 255);
            @memcpy(msg_buf[0..msg_len], entry.message[0..msg_len]);
            msg_buf[msg_len] = 0;
            self.drawText(@ptrCast(&msg_buf), x_start + PADDING + 140, line_y, FONTS.BODY_SMALL, THEME.TEXT_SECONDARY);

            line_y += 24;
        }
    }

    fn drawFooter(self: *TrinityNodeUI) void {
        const y = self.screen_height - 40;

        rl.DrawRectangle(0, y, self.screen_width, 40, THEME.BG_SIDEBAR);
        rl.DrawLine(0, y, self.screen_width, y, THEME.BORDER);

        // Footer text with custom font
        self.drawText("phi^2 + 1/phi^2 = 3 = TRINITY", PADDING, y + 12, 12, THEME.TEXT_MUTED);
        self.drawText("KOSCHEI IS IMMORTAL", self.screen_width - 180, y + 12, 12, THEME.GOLDEN);

        // F11 hint
        self.drawText("F11: Toggle Fullscreen", self.screen_width - 380, y + 12, 12, THEME.TEXT_MUTED);
    }

    fn formatBalance(self: *TrinityNodeUI) [*:0]const u8 {
        // Static buffer for balance formatting
        const Static = struct {
            var buf: [32]u8 = undefined;
        };

        const balance = self.wallet.getBalanceFormatted();
        const result = std.fmt.bufPrintZ(&Static.buf, "{d:.4}", .{balance}) catch "0.0000";
        return @ptrCast(result.ptr);
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "ui theme colors" {
    // Website theme: #00FF88 green accent on #000000 black
    try std.testing.expect(THEME.ACCENT.r == 0x00);
    try std.testing.expect(THEME.ACCENT.g == 0xFF);
    try std.testing.expect(THEME.ACCENT.b == 0x88);
    try std.testing.expect(THEME.BG_WINDOW.r == 0x00); // Pure black
    try std.testing.expect(THEME.GOLDEN.r == 0xFF); // #FFD700
}

test "screen enum" {
    const screen: Screen = .dashboard;
    try std.testing.expect(screen == .dashboard);
}
