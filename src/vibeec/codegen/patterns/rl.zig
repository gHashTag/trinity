// ═══════════════════════════════════════════════════════════════════════════════
// RL PATTERNS - Raylib GUI/rendering operations
// ═══════════════════════════════════════════════════════════════════════════════
//
// Drawing primitives, text, input handling, window management, composite UI.
// Covers all raylib APIs used in trinity-canvas:
//   DrawRectangle, DrawCircle, DrawLine, DrawTriangle, DrawText,
//   BeginDrawing/EndDrawing, BeginScissorMode, IsKeyPressed, GetMouseX/Y, etc.
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const types = @import("../types.zig");
const builder_mod = @import("../builder.zig");

const CodeBuilder = builder_mod.CodeBuilder;
const Behavior = types.Behavior;

/// Quick guard: returns true if the behavior name is an rl-domain pattern.
/// Used to skip rl matching early and prevent collisions with lifecycle/generic/io.
pub fn isRlBehavior(name: []const u8) bool {
    // Unique prefixes — no collision with other pattern modules
    if (std.mem.startsWith(u8, name, "draw_")) return true;
    if (std.mem.startsWith(u8, name, "render_")) return true;
    if (std.mem.startsWith(u8, name, "setup_frame")) return true;
    if (std.mem.startsWith(u8, name, "setup_scissor")) return true;
    if (std.mem.startsWith(u8, name, "end_frame")) return true;
    if (std.mem.startsWith(u8, name, "end_scissor")) return true;

    // Exact matches — prevent collision with lifecycle (init*), io (load*, close*),
    // generic (handle*, measure*, get*)
    const exact_matches = [_][]const u8{
        "init_window",
        "init_audio",
        "close_window",
        "close_audio",
        "should_close",
        "handle_mouse",
        "handle_keyboard",
        "handle_scroll",
        "handle_drag",
        "load_font",
        "load_font_ex",
        "unload_font",
        "measure_text",
        "measure_text_ex",
        "measure_fps",
        "get_screen_size",
        "get_frame_time",
        "get_time",
        "get_dpi_scale",
        "get_monitor_size",
        "get_char_pressed",
        "is_key_down",
        "is_mouse_released",
        "set_exit_key",
        "set_window_min_size",
        "set_window_focused",
        "set_texture_filter",
        "hide_cursor",
        "show_cursor",
        "with_alpha",
        "color_from_hsv",
        "color_tint",
        "color_brightness",
    };
    for (exact_matches) |em| {
        if (std.mem.eql(u8, name, em)) return true;
    }

    return false;
}

/// Match raylib GUI/rendering patterns
pub fn match(builder: *CodeBuilder, b: *const Behavior) !bool {

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 1: Drawing Primitives (draw_*)
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: draw_rect* → DrawRectangle / DrawRectangleRounded / DrawRectangleLines
    if (std.mem.startsWith(u8, b.name, "draw_rect")) {
        const is_rounded = std.mem.indexOf(u8, b.name, "rounded") != null;
        const is_lines = std.mem.indexOf(u8, b.name, "lines") != null or
            std.mem.indexOf(u8, b.name, "outline") != null;

        if (is_rounded and is_lines) {
            // DrawRectangleRoundedLinesEx
            try builder.writeFmt("pub fn {s}(rect: rl.Rectangle, roundness: f32, segments: c_int, thick: f32, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawRectangleRoundedLinesEx(rect, roundness, segments, thick, color);");
            builder.decIndent();
            try builder.writeLine("}");
        } else if (is_rounded) {
            // DrawRectangleRounded
            try builder.writeFmt("pub fn {s}(rect: rl.Rectangle, roundness: f32, segments: c_int, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawRectangleRounded(rect, roundness, segments, color);");
            builder.decIndent();
            try builder.writeLine("}");
        } else if (is_lines) {
            // DrawRectangleLines
            try builder.writeFmt("pub fn {s}(x: c_int, y: c_int, w: c_int, h: c_int, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawRectangleLines(x, y, w, h, color);");
            builder.decIndent();
            try builder.writeLine("}");
        } else {
            // DrawRectangle (default)
            try builder.writeFmt("pub fn {s}(x: c_int, y: c_int, w: c_int, h: c_int, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawRectangle(x, y, w, h, color);");
            builder.decIndent();
            try builder.writeLine("}");
        }
        return true;
    }

    // Pattern: draw_circle* → DrawCircle / DrawCircleLines
    if (std.mem.startsWith(u8, b.name, "draw_circle")) {
        const is_lines = std.mem.indexOf(u8, b.name, "lines") != null or
            std.mem.indexOf(u8, b.name, "outline") != null;

        if (is_lines) {
            try builder.writeFmt("pub fn {s}(x: c_int, y: c_int, radius: f32, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawCircleLines(x, y, radius, color);");
            builder.decIndent();
            try builder.writeLine("}");
        } else {
            try builder.writeFmt("pub fn {s}(x: c_int, y: c_int, radius: f32, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawCircle(x, y, radius, color);");
            builder.decIndent();
            try builder.writeLine("}");
        }
        return true;
    }

    // Pattern: draw_triangle → DrawTriangle
    if (std.mem.startsWith(u8, b.name, "draw_triangle")) {
        try builder.writeFmt("pub fn {s}(v1: rl.Vector2, v2: rl.Vector2, v3: rl.Vector2, color: rl.Color) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("rl.DrawTriangle(v1, v2, v3, color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: draw_line* → DrawLine / DrawLineEx
    if (std.mem.startsWith(u8, b.name, "draw_line")) {
        const is_ex = std.mem.indexOf(u8, b.name, "ex") != null or
            std.mem.indexOf(u8, b.name, "thick") != null;

        if (is_ex) {
            try builder.writeFmt("pub fn {s}(start: rl.Vector2, end_pos: rl.Vector2, thick: f32, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawLineEx(start, end_pos, thick, color);");
            builder.decIndent();
            try builder.writeLine("}");
        } else {
            try builder.writeFmt("pub fn {s}(x1: c_int, y1: c_int, x2: c_int, y2: c_int, color: rl.Color) void {{\n", .{b.name});
            builder.incIndent();
            try builder.writeLine("rl.DrawLine(x1, y1, x2, y2, color);");
            builder.decIndent();
            try builder.writeLine("}");
        }
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 2: Text Rendering
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: draw_text_ex → DrawTextEx (must check before draw_text)
    if (std.mem.eql(u8, b.name, "draw_text_ex")) {
        try builder.writeLine("pub fn draw_text_ex(font: rl.Font, text: [*:0]const u8, pos: rl.Vector2, size: f32, spacing: f32, color: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("rl.DrawTextEx(font, text, pos, size, spacing, color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: draw_text → DrawText
    if (std.mem.startsWith(u8, b.name, "draw_text")) {
        try builder.writeFmt("pub fn {s}(text: [*:0]const u8, x: c_int, y: c_int, size: c_int, color: rl.Color) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("rl.DrawText(text, x, y, size, color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: measure_text_ex → MeasureTextEx (must check before measure_text)
    if (std.mem.eql(u8, b.name, "measure_text_ex")) {
        try builder.writeLine("pub fn measure_text_ex(font: rl.Font, text: [*:0]const u8, size: f32, spacing: f32) rl.Vector2 {");
        builder.incIndent();
        try builder.writeLine("return rl.MeasureTextEx(font, text, size, spacing);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: measure_text → MeasureText
    if (std.mem.eql(u8, b.name, "measure_text")) {
        try builder.writeLine("pub fn measure_text(text: [*:0]const u8, size: c_int) c_int {");
        builder.incIndent();
        try builder.writeLine("return rl.MeasureText(text, size);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: measure_fps → GetFrameTime-based FPS
    if (std.mem.eql(u8, b.name, "measure_fps")) {
        try builder.writeLine("pub fn measure_fps() f32 {");
        builder.incIndent();
        try builder.writeLine("const dt = rl.GetFrameTime();");
        try builder.writeLine("return if (dt > 0.0) 1.0 / dt else 0.0;");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: load_font* → LoadFontEx
    if (std.mem.eql(u8, b.name, "load_font") or std.mem.eql(u8, b.name, "load_font_ex")) {
        try builder.writeFmt("pub fn {s}(path: [*:0]const u8, size: c_int) rl.Font {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("return rl.LoadFontEx(path, size, null, 0);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: unload_font → UnloadFont
    if (std.mem.eql(u8, b.name, "unload_font")) {
        try builder.writeLine("pub fn unload_font(font: rl.Font) void {");
        builder.incIndent();
        try builder.writeLine("rl.UnloadFont(font);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 3: Input Handling
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: handle_mouse → capture full mouse state
    if (std.mem.eql(u8, b.name, "handle_mouse")) {
        try builder.writeLine("pub const MouseState = struct {");
        builder.incIndent();
        try builder.writeLine("x: c_int,");
        try builder.writeLine("y: c_int,");
        try builder.writeLine("left_down: bool,");
        try builder.writeLine("left_pressed: bool,");
        try builder.writeLine("right_down: bool,");
        try builder.writeLine("right_pressed: bool,");
        try builder.writeLine("wheel: f32,");
        builder.decIndent();
        try builder.writeLine("};");
        try builder.newline();
        try builder.writeLine("pub fn handle_mouse() MouseState {");
        builder.incIndent();
        try builder.writeLine("return MouseState{");
        builder.incIndent();
        try builder.writeLine(".x = rl.GetMouseX(),");
        try builder.writeLine(".y = rl.GetMouseY(),");
        try builder.writeLine(".left_down = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT),");
        try builder.writeLine(".left_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT),");
        try builder.writeLine(".right_down = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_RIGHT),");
        try builder.writeLine(".right_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT),");
        try builder.writeLine(".wheel = rl.GetMouseWheelMove(),");
        builder.decIndent();
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: handle_keyboard → key press detection
    if (std.mem.eql(u8, b.name, "handle_keyboard")) {
        try builder.writeLine("pub fn handle_keyboard(key: c_int) bool {");
        builder.incIndent();
        try builder.writeLine("return rl.IsKeyPressed(key);");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.newline();
        try builder.writeLine("pub fn get_char_pressed() c_int {");
        builder.incIndent();
        try builder.writeLine("return rl.GetCharPressed();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: handle_scroll → mouse wheel
    if (std.mem.eql(u8, b.name, "handle_scroll")) {
        try builder.writeLine("pub fn handle_scroll() f32 {");
        builder.incIndent();
        try builder.writeLine("return rl.GetMouseWheelMove();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: handle_drag → drag state machine
    if (std.mem.eql(u8, b.name, "handle_drag")) {
        try builder.writeLine("pub const DragState = struct {");
        builder.incIndent();
        try builder.writeLine("active: bool,");
        try builder.writeLine("start_x: c_int,");
        try builder.writeLine("start_y: c_int,");
        try builder.writeLine("delta_x: c_int,");
        try builder.writeLine("delta_y: c_int,");
        builder.decIndent();
        try builder.writeLine("};");
        try builder.newline();
        try builder.writeLine("pub fn handle_drag(state: *DragState) void {");
        builder.incIndent();
        try builder.writeLine("const mx = rl.GetMouseX();");
        try builder.writeLine("const my = rl.GetMouseY();");
        try builder.writeLine("if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {");
        builder.incIndent();
        try builder.writeLine("state.active = true;");
        try builder.writeLine("state.start_x = mx;");
        try builder.writeLine("state.start_y = my;");
        try builder.writeLine("state.delta_x = 0;");
        try builder.writeLine("state.delta_y = 0;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("if (state.active and rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {");
        builder.incIndent();
        try builder.writeLine("state.delta_x = mx - state.start_x;");
        try builder.writeLine("state.delta_y = my - state.start_y;");
        builder.decIndent();
        try builder.writeLine("}");
        try builder.writeLine("if (!rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {");
        builder.incIndent();
        try builder.writeLine("state.active = false;");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 4: Window Management
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: init_window → SetConfigFlags + InitWindow + SetTargetFPS
    if (std.mem.eql(u8, b.name, "init_window")) {
        try builder.writeLine("pub fn init_window(width: c_int, height: c_int, title: [*:0]const u8) void {");
        builder.incIndent();
        try builder.writeLine("rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);");
        try builder.writeLine("rl.InitWindow(width, height, title);");
        try builder.writeLine("rl.SetTargetFPS(60);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: close_window → CloseWindow
    if (std.mem.eql(u8, b.name, "close_window")) {
        try builder.writeLine("pub fn close_window() void {");
        builder.incIndent();
        try builder.writeLine("rl.CloseWindow();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: should_close → WindowShouldClose
    if (std.mem.eql(u8, b.name, "should_close")) {
        try builder.writeLine("pub fn should_close() bool {");
        builder.incIndent();
        try builder.writeLine("return rl.WindowShouldClose();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: setup_frame → BeginDrawing + ClearBackground
    if (std.mem.eql(u8, b.name, "setup_frame")) {
        try builder.writeLine("pub fn setup_frame(bg: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("rl.BeginDrawing();");
        try builder.writeLine("rl.ClearBackground(bg);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: end_frame → EndDrawing
    if (std.mem.eql(u8, b.name, "end_frame")) {
        try builder.writeLine("pub fn end_frame() void {");
        builder.incIndent();
        try builder.writeLine("rl.EndDrawing();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: setup_scissor → BeginScissorMode
    if (std.mem.eql(u8, b.name, "setup_scissor")) {
        try builder.writeLine("pub fn setup_scissor(x: c_int, y: c_int, w: c_int, h: c_int) void {");
        builder.incIndent();
        try builder.writeLine("rl.BeginScissorMode(x, y, w, h);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: end_scissor → EndScissorMode
    if (std.mem.eql(u8, b.name, "end_scissor")) {
        try builder.writeLine("pub fn end_scissor() void {");
        builder.incIndent();
        try builder.writeLine("rl.EndScissorMode();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: get_screen_size → GetScreenWidth/Height
    if (std.mem.eql(u8, b.name, "get_screen_size")) {
        try builder.writeLine("pub const ScreenSize = struct { width: c_int, height: c_int };");
        try builder.newline();
        try builder.writeLine("pub fn get_screen_size() ScreenSize {");
        builder.incIndent();
        try builder.writeLine("return ScreenSize{");
        builder.incIndent();
        try builder.writeLine(".width = rl.GetScreenWidth(),");
        try builder.writeLine(".height = rl.GetScreenHeight(),");
        builder.decIndent();
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: get_frame_time → GetFrameTime
    if (std.mem.eql(u8, b.name, "get_frame_time")) {
        try builder.writeLine("pub fn get_frame_time() f32 {");
        builder.incIndent();
        try builder.writeLine("return rl.GetFrameTime();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 5: Composite Rendering (render_*)
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: render_panel → glassmorphism panel (bg + border + title)
    if (std.mem.eql(u8, b.name, "render_panel")) {
        try builder.writeLine("pub fn render_panel(x: f32, y: f32, w: f32, h: f32, title: [*:0]const u8, bg: rl.Color, border: rl.Color, text_color: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("const rect = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };");
        try builder.writeLine("// Background");
        try builder.writeLine("rl.DrawRectangleRounded(rect, 0.02, 8, bg);");
        try builder.writeLine("// Border");
        try builder.writeLine("rl.DrawRectangleRoundedLinesEx(rect, 0.02, 8, 1.0, border);");
        try builder.writeLine("// Title");
        try builder.writeLine("rl.DrawText(title, @intFromFloat(x + 16.0), @intFromFloat(y + 8.0), 14, text_color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_button → interactive button
    if (std.mem.eql(u8, b.name, "render_button")) {
        try builder.writeLine("pub fn render_button(x: f32, y: f32, w: f32, h: f32, label: [*:0]const u8, bg: rl.Color, hover_bg: rl.Color, text_color: rl.Color) bool {");
        builder.incIndent();
        try builder.writeLine("const mx = @as(f32, @floatFromInt(rl.GetMouseX()));");
        try builder.writeLine("const my = @as(f32, @floatFromInt(rl.GetMouseY()));");
        try builder.writeLine("const hovered = mx >= x and mx <= x + w and my >= y and my <= y + h;");
        try builder.writeLine("const color = if (hovered) hover_bg else bg;");
        try builder.writeLine("const rect = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };");
        try builder.writeLine("rl.DrawRectangleRounded(rect, 0.1, 8, color);");
        try builder.writeLine("const tw = rl.MeasureText(label, 14);");
        try builder.writeLine("rl.DrawText(label, @intFromFloat(x + (w - @as(f32, @floatFromInt(tw))) / 2.0), @intFromFloat(y + (h - 14.0) / 2.0), 14, text_color);");
        try builder.writeLine("return hovered and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_scroll_indicator → scroll bar
    if (std.mem.startsWith(u8, b.name, "render_scroll")) {
        try builder.writeFmt("pub fn {s}(x: f32, y: f32, h: f32, scroll_ratio: f32, visible_ratio: f32, color: rl.Color) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("// Track");
        try builder.writeLine("const track_w: f32 = 4.0;");
        try builder.writeLine("rl.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(track_w), @intFromFloat(h), rl.Color{ .r = 255, .g = 255, .b = 255, .a = 20 });");
        try builder.writeLine("// Thumb");
        try builder.writeLine("const thumb_h = h * visible_ratio;");
        try builder.writeLine("const thumb_y = y + (h - thumb_h) * scroll_ratio;");
        try builder.writeLine("rl.DrawRectangle(@intFromFloat(x), @intFromFloat(thumb_y), @intFromFloat(track_w), @intFromFloat(thumb_h), color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_tab_bar → horizontal tab bar with selection
    if (std.mem.eql(u8, b.name, "render_tab_bar")) {
        try builder.writeLine("pub fn render_tab_bar(x: f32, y: f32, w: f32, h: f32, tabs: []const [*:0]const u8, selected: usize, bg: rl.Color, active_bg: rl.Color, text_color: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("const count = @as(f32, @floatFromInt(tabs.len));");
        try builder.writeLine("const tab_w = w / count;");
        try builder.writeLine("for (tabs, 0..) |label, i| {");
        builder.incIndent();
        try builder.writeLine("const tx = x + @as(f32, @floatFromInt(i)) * tab_w;");
        try builder.writeLine("const is_active = i == selected;");
        try builder.writeLine("const color = if (is_active) active_bg else bg;");
        try builder.writeLine("const rect = rl.Rectangle{ .x = tx, .y = y, .width = tab_w, .height = h };");
        try builder.writeLine("rl.DrawRectangleRounded(rect, 0.05, 4, color);");
        try builder.writeLine("const tw = rl.MeasureText(label, 12);");
        try builder.writeLine("rl.DrawText(label, @intFromFloat(tx + (tab_w - @as(f32, @floatFromInt(tw))) / 2.0), @intFromFloat(y + (h - 12.0) / 2.0), 12, text_color);");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_tooltip → tooltip popup near mouse
    if (std.mem.eql(u8, b.name, "render_tooltip")) {
        try builder.writeLine("pub fn render_tooltip(text: [*:0]const u8, bg: rl.Color, text_color: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("const mx = @as(f32, @floatFromInt(rl.GetMouseX()));");
        try builder.writeLine("const my = @as(f32, @floatFromInt(rl.GetMouseY()));");
        try builder.writeLine("const tw = @as(f32, @floatFromInt(rl.MeasureText(text, 12)));");
        try builder.writeLine("const pad: f32 = 8.0;");
        try builder.writeLine("const rect = rl.Rectangle{ .x = mx + 12.0, .y = my - 28.0, .width = tw + pad * 2.0, .height = 24.0 };");
        try builder.writeLine("rl.DrawRectangleRounded(rect, 0.15, 6, bg);");
        try builder.writeLine("rl.DrawText(text, @intFromFloat(rect.x + pad), @intFromFloat(rect.y + 6.0), 12, text_color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_progress_bar → horizontal progress bar
    if (std.mem.startsWith(u8, b.name, "render_progress")) {
        try builder.writeFmt("pub fn {s}(x: f32, y: f32, w: f32, h: f32, progress: f32, bg: rl.Color, fill: rl.Color) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("const outer = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };");
        try builder.writeLine("rl.DrawRectangleRounded(outer, 0.3, 6, bg);");
        try builder.writeLine("const clamped = @max(0.0, @min(1.0, progress));");
        try builder.writeLine("if (clamped > 0.01) {");
        builder.incIndent();
        try builder.writeLine("const inner = rl.Rectangle{ .x = x, .y = y, .width = w * clamped, .height = h };");
        try builder.writeLine("rl.DrawRectangleRounded(inner, 0.3, 6, fill);");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_divider → horizontal line divider
    if (std.mem.eql(u8, b.name, "render_divider")) {
        try builder.writeLine("pub fn render_divider(x: f32, y: f32, w: f32, color: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("rl.DrawLineEx(.{ .x = x, .y = y }, .{ .x = x + w, .y = y }, 1.0, color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_badge → small pill/badge with text
    if (std.mem.eql(u8, b.name, "render_badge")) {
        try builder.writeLine("pub fn render_badge(x: f32, y: f32, text: [*:0]const u8, bg: rl.Color, text_color: rl.Color) void {");
        builder.incIndent();
        try builder.writeLine("const tw = @as(f32, @floatFromInt(rl.MeasureText(text, 10)));");
        try builder.writeLine("const pad: f32 = 6.0;");
        try builder.writeLine("const rect = rl.Rectangle{ .x = x, .y = y, .width = tw + pad * 2.0, .height = 18.0 };");
        try builder.writeLine("rl.DrawRectangleRounded(rect, 0.5, 8, bg);");
        try builder.writeLine("rl.DrawText(text, @intFromFloat(x + pad), @intFromFloat(y + 4.0), 10, text_color);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: render_gradient → vertical gradient
    if (std.mem.startsWith(u8, b.name, "render_gradient")) {
        try builder.writeFmt("pub fn {s}(x: c_int, y: c_int, w: c_int, h: c_int, top: rl.Color, bottom: rl.Color) void {{\n", .{b.name});
        builder.incIndent();
        try builder.writeLine("var i: c_int = 0;");
        try builder.writeLine("while (i < h) : (i += 1) {");
        builder.incIndent();
        try builder.writeLine("const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(h));");
        try builder.writeLine("const r: u8 = @intFromFloat(@as(f32, @floatFromInt(top.r)) * (1.0 - t) + @as(f32, @floatFromInt(bottom.r)) * t);");
        try builder.writeLine("const g: u8 = @intFromFloat(@as(f32, @floatFromInt(top.g)) * (1.0 - t) + @as(f32, @floatFromInt(bottom.g)) * t);");
        try builder.writeLine("const b_c: u8 = @intFromFloat(@as(f32, @floatFromInt(top.b)) * (1.0 - t) + @as(f32, @floatFromInt(bottom.b)) * t);");
        try builder.writeLine("const a: u8 = @intFromFloat(@as(f32, @floatFromInt(top.a)) * (1.0 - t) + @as(f32, @floatFromInt(bottom.a)) * t);");
        try builder.writeLine("rl.DrawLine(x, y + i, x + w, y + i, rl.Color{ .r = r, .g = g, .b = b_c, .a = a });");
        builder.decIndent();
        try builder.writeLine("}");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 6: Color Helpers
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: with_alpha → color with modified alpha
    if (std.mem.eql(u8, b.name, "with_alpha")) {
        try builder.writeLine("pub fn with_alpha(color: rl.Color, alpha: u8) rl.Color {");
        builder.incIndent();
        try builder.writeLine("return rl.Color{ .r = color.r, .g = color.g, .b = color.b, .a = alpha };");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: color_from_hsv → ColorFromHSV
    if (std.mem.eql(u8, b.name, "color_from_hsv")) {
        try builder.writeLine("pub fn color_from_hsv(hue: f32, saturation: f32, value: f32) rl.Color {");
        builder.incIndent();
        try builder.writeLine("return rl.ColorFromHSV(hue, saturation, value);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: color_tint → ColorTint
    if (std.mem.eql(u8, b.name, "color_tint")) {
        try builder.writeLine("pub fn color_tint(color: rl.Color, tint: rl.Color) rl.Color {");
        builder.incIndent();
        try builder.writeLine("return rl.ColorTint(color, tint);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: color_brightness → ColorBrightness
    if (std.mem.eql(u8, b.name, "color_brightness")) {
        try builder.writeLine("pub fn color_brightness(color: rl.Color, factor: f32) rl.Color {");
        builder.incIndent();
        try builder.writeLine("return rl.ColorBrightness(color, factor);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 7: Audio
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: init_audio → InitAudioDevice
    if (std.mem.eql(u8, b.name, "init_audio")) {
        try builder.writeLine("pub fn init_audio() void {");
        builder.incIndent();
        try builder.writeLine("rl.InitAudioDevice();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: close_audio → CloseAudioDevice
    if (std.mem.eql(u8, b.name, "close_audio")) {
        try builder.writeLine("pub fn close_audio() void {");
        builder.incIndent();
        try builder.writeLine("rl.CloseAudioDevice();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 8: Window State
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: set_window_min_size → SetWindowMinSize
    if (std.mem.eql(u8, b.name, "set_window_min_size")) {
        try builder.writeLine("pub fn set_window_min_size(w: c_int, h: c_int) void {");
        builder.incIndent();
        try builder.writeLine("rl.SetWindowMinSize(w, h);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: set_window_focused → SetWindowFocused
    if (std.mem.eql(u8, b.name, "set_window_focused")) {
        try builder.writeLine("pub fn set_window_focused() void {");
        builder.incIndent();
        try builder.writeLine("rl.SetWindowFocused();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: get_dpi_scale → GetWindowScaleDPI
    if (std.mem.eql(u8, b.name, "get_dpi_scale")) {
        try builder.writeLine("pub fn get_dpi_scale() rl.Vector2 {");
        builder.incIndent();
        try builder.writeLine("return rl.GetWindowScaleDPI();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: get_monitor_size → GetCurrentMonitor + GetMonitorWidth/Height
    if (std.mem.eql(u8, b.name, "get_monitor_size")) {
        try builder.writeLine("pub const MonitorSize = struct { width: c_int, height: c_int };");
        try builder.newline();
        try builder.writeLine("pub fn get_monitor_size() MonitorSize {");
        builder.incIndent();
        try builder.writeLine("const monitor = rl.GetCurrentMonitor();");
        try builder.writeLine("return MonitorSize{");
        builder.incIndent();
        try builder.writeLine(".width = rl.GetMonitorWidth(monitor),");
        try builder.writeLine(".height = rl.GetMonitorHeight(monitor),");
        builder.decIndent();
        try builder.writeLine("};");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: set_exit_key → SetExitKey
    if (std.mem.eql(u8, b.name, "set_exit_key")) {
        try builder.writeLine("pub fn set_exit_key(key: c_int) void {");
        builder.incIndent();
        try builder.writeLine("rl.SetExitKey(key);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: get_time → GetTime
    if (std.mem.eql(u8, b.name, "get_time")) {
        try builder.writeLine("pub fn get_time() f64 {");
        builder.incIndent();
        try builder.writeLine("return rl.GetTime();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 9: Cursor
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: hide_cursor → HideCursor
    if (std.mem.eql(u8, b.name, "hide_cursor")) {
        try builder.writeLine("pub fn hide_cursor() void {");
        builder.incIndent();
        try builder.writeLine("rl.HideCursor();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: show_cursor → ShowCursor
    if (std.mem.eql(u8, b.name, "show_cursor")) {
        try builder.writeLine("pub fn show_cursor() void {");
        builder.incIndent();
        try builder.writeLine("rl.ShowCursor();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 10: Texture
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: set_texture_filter → SetTextureFilter
    if (std.mem.eql(u8, b.name, "set_texture_filter")) {
        try builder.writeLine("pub fn set_texture_filter(texture: rl.Texture2D, filter: c_int) void {");
        builder.incIndent();
        try builder.writeLine("rl.SetTextureFilter(texture, filter);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 11: Additional Input
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: is_key_down → IsKeyDown
    if (std.mem.eql(u8, b.name, "is_key_down")) {
        try builder.writeLine("pub fn is_key_down(key: c_int) bool {");
        builder.incIndent();
        try builder.writeLine("return rl.IsKeyDown(key);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: is_mouse_released → IsMouseButtonReleased
    if (std.mem.eql(u8, b.name, "is_mouse_released")) {
        try builder.writeLine("pub fn is_mouse_released(button: c_int) bool {");
        builder.incIndent();
        try builder.writeLine("return rl.IsMouseButtonReleased(button);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // Pattern: get_char_pressed → GetCharPressed
    if (std.mem.eql(u8, b.name, "get_char_pressed")) {
        try builder.writeLine("pub fn get_char_pressed() c_int {");
        builder.incIndent();
        try builder.writeLine("return rl.GetCharPressed();");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SECTION 12: Additional Drawing
    // ═══════════════════════════════════════════════════════════════════════

    // Pattern: draw_fps → DrawFPS
    if (std.mem.eql(u8, b.name, "draw_fps")) {
        try builder.writeLine("pub fn draw_fps(x: c_int, y: c_int) void {");
        builder.incIndent();
        try builder.writeLine("rl.DrawFPS(x, y);");
        builder.decIndent();
        try builder.writeLine("}");
        return true;
    }

    return false; // No rl pattern matched
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — E2E: behavior name → match() → generated rl.* code
// ═══════════════════════════════════════════════════════════════════════════════

fn makeBehavior(name: []const u8) Behavior {
    return Behavior{
        .name = name,
        .given = "test",
        .when = "test",
        .then = "test",
        .implementation = "",
        .test_cases = .{},
    };
}

fn matchAndGetOutput(name: []const u8) !?[]const u8 {
    const allocator = std.testing.allocator;
    var builder = CodeBuilder.init(allocator);
    defer builder.deinit();

    var b = makeBehavior(name);
    const matched = try match(&builder, &b);
    if (!matched) return null;

    const output = builder.getOutput();
    const copy = try allocator.alloc(u8, output.len);
    @memcpy(copy, output);
    return copy;
}

fn freeOutput(output: ?[]const u8) void {
    if (output) |o| {
        std.testing.allocator.free(o);
    }
}

// ─── isRlBehavior guard tests ───

test "isRlBehavior: unique prefixes" {
    const t = std.testing;
    try t.expect(isRlBehavior("draw_rect"));
    try t.expect(isRlBehavior("draw_circle_lines"));
    try t.expect(isRlBehavior("draw_text"));
    try t.expect(isRlBehavior("draw_fps"));
    try t.expect(isRlBehavior("render_panel"));
    try t.expect(isRlBehavior("render_tab_bar"));
    try t.expect(isRlBehavior("render_gradient"));
    try t.expect(isRlBehavior("setup_frame"));
    try t.expect(isRlBehavior("setup_scissor"));
    try t.expect(isRlBehavior("end_frame"));
    try t.expect(isRlBehavior("end_scissor"));
}

test "isRlBehavior: exact matches prevent collision" {
    const t = std.testing;
    try t.expect(isRlBehavior("init_window"));
    try t.expect(isRlBehavior("init_audio"));
    try t.expect(isRlBehavior("close_window"));
    try t.expect(isRlBehavior("close_audio"));
    try t.expect(isRlBehavior("handle_mouse"));
    try t.expect(isRlBehavior("handle_keyboard"));
    try t.expect(isRlBehavior("load_font"));
    try t.expect(isRlBehavior("measure_text"));
    try t.expect(isRlBehavior("get_screen_size"));
    try t.expect(isRlBehavior("get_frame_time"));
    try t.expect(isRlBehavior("get_time"));
    try t.expect(isRlBehavior("get_dpi_scale"));
    try t.expect(isRlBehavior("get_monitor_size"));
    try t.expect(isRlBehavior("set_exit_key"));
    try t.expect(isRlBehavior("hide_cursor"));
    try t.expect(isRlBehavior("show_cursor"));
    try t.expect(isRlBehavior("with_alpha"));
    try t.expect(isRlBehavior("color_from_hsv"));
}

test "isRlBehavior: non-rl names rejected" {
    const t = std.testing;
    try t.expect(!isRlBehavior("init"));
    try t.expect(!isRlBehavior("init_system"));
    try t.expect(!isRlBehavior("close"));
    try t.expect(!isRlBehavior("handle"));
    try t.expect(!isRlBehavior("load"));
    try t.expect(!isRlBehavior("get"));
    try t.expect(!isRlBehavior("predict"));
    try t.expect(!isRlBehavior("bind"));
    try t.expect(!isRlBehavior("encode"));
    try t.expect(!isRlBehavior("fooBar"));
}

// ─── Drawing e2e ───

test "e2e: draw_rect generates rl.DrawRectangle" {
    const output = try matchAndGetOutput("draw_rect");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangle(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "pub fn draw_rect(") != null);
}

test "e2e: draw_rect_rounded generates rl.DrawRectangleRounded" {
    const output = try matchAndGetOutput("draw_rect_rounded");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRounded(") != null);
}

test "e2e: draw_rect_rounded_lines generates rl.DrawRectangleRoundedLinesEx" {
    const output = try matchAndGetOutput("draw_rect_rounded_lines");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRoundedLinesEx(") != null);
}

test "e2e: draw_circle generates rl.DrawCircle" {
    const output = try matchAndGetOutput("draw_circle");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawCircle(") != null);
}

test "e2e: draw_line generates rl.DrawLine" {
    const output = try matchAndGetOutput("draw_line");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawLine(") != null);
}

test "e2e: draw_line_ex generates rl.DrawLineEx" {
    const output = try matchAndGetOutput("draw_line_ex");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawLineEx(") != null);
}

test "e2e: draw_triangle generates rl.DrawTriangle" {
    const output = try matchAndGetOutput("draw_triangle");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawTriangle(") != null);
}

test "e2e: draw_fps generates rl.DrawFPS" {
    const output = try matchAndGetOutput("draw_fps");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawFPS(") != null);
}

// ─── Text e2e ───

test "e2e: draw_text generates rl.DrawText" {
    const output = try matchAndGetOutput("draw_text");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawText(") != null);
}

test "e2e: draw_text_ex generates rl.DrawTextEx" {
    const output = try matchAndGetOutput("draw_text_ex");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawTextEx(") != null);
}

test "e2e: measure_text generates rl.MeasureText" {
    const output = try matchAndGetOutput("measure_text");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.MeasureText(") != null);
}

test "e2e: load_font generates rl.LoadFontEx" {
    const output = try matchAndGetOutput("load_font");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.LoadFontEx(") != null);
}

// ─── Input e2e ───

test "e2e: handle_mouse generates MouseState + GetMouseX/Y" {
    const output = try matchAndGetOutput("handle_mouse");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "MouseState") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetMouseX()") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetMouseY()") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.IsMouseButtonDown(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetMouseWheelMove()") != null);
}

test "e2e: handle_keyboard generates IsKeyPressed + GetCharPressed" {
    const output = try matchAndGetOutput("handle_keyboard");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.IsKeyPressed(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetCharPressed()") != null);
}

test "e2e: handle_drag generates DragState + state machine" {
    const output = try matchAndGetOutput("handle_drag");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "DragState") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.IsMouseButtonPressed(") != null);
}

test "e2e: is_key_down generates rl.IsKeyDown" {
    const output = try matchAndGetOutput("is_key_down");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.IsKeyDown(") != null);
}

test "e2e: is_mouse_released generates rl.IsMouseButtonReleased" {
    const output = try matchAndGetOutput("is_mouse_released");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.IsMouseButtonReleased(") != null);
}

// ─── Window e2e ───

test "e2e: init_window generates SetConfigFlags + InitWindow + SetTargetFPS" {
    const output = try matchAndGetOutput("init_window");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.SetConfigFlags(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.InitWindow(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.SetTargetFPS(") != null);
}

test "e2e: should_close generates rl.WindowShouldClose" {
    const output = try matchAndGetOutput("should_close");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.WindowShouldClose()") != null);
}

test "e2e: setup_frame generates BeginDrawing + ClearBackground" {
    const output = try matchAndGetOutput("setup_frame");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.BeginDrawing()") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.ClearBackground(") != null);
}

test "e2e: get_screen_size generates ScreenSize + GetScreenWidth/Height" {
    const output = try matchAndGetOutput("get_screen_size");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "ScreenSize") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetScreenWidth()") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetScreenHeight()") != null);
}

test "e2e: get_monitor_size generates MonitorSize + GetCurrentMonitor" {
    const output = try matchAndGetOutput("get_monitor_size");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "MonitorSize") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetCurrentMonitor()") != null);
}

test "e2e: set_exit_key generates rl.SetExitKey" {
    const output = try matchAndGetOutput("set_exit_key");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.SetExitKey(") != null);
}

test "e2e: get_time generates rl.GetTime" {
    const output = try matchAndGetOutput("get_time");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetTime()") != null);
}

// ─── Composites e2e ───

test "e2e: render_panel generates glassmorphism (bg+border+title)" {
    const output = try matchAndGetOutput("render_panel");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRounded(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRoundedLinesEx(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawText(") != null);
}

test "e2e: render_button generates hover detection + click" {
    const output = try matchAndGetOutput("render_button");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetMouseX()") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.IsMouseButtonPressed(") != null);
}

test "e2e: render_tab_bar generates tab selection" {
    const output = try matchAndGetOutput("render_tab_bar");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRounded(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawText(") != null);
}

test "e2e: render_tooltip generates popup near mouse" {
    const output = try matchAndGetOutput("render_tooltip");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.GetMouseX()") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRounded(") != null);
}

test "e2e: render_progress_bar generates bg + fill" {
    const output = try matchAndGetOutput("render_progress_bar");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRounded(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "clamped") != null);
}

test "e2e: render_divider generates DrawLineEx" {
    const output = try matchAndGetOutput("render_divider");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawLineEx(") != null);
}

test "e2e: render_badge generates pill with text" {
    const output = try matchAndGetOutput("render_badge");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.DrawRectangleRounded(") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.MeasureText(") != null);
}

// ─── Color helpers e2e ───

test "e2e: with_alpha generates Color with alpha" {
    const output = try matchAndGetOutput("with_alpha");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.Color{") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, ".a = alpha") != null);
}

test "e2e: color_from_hsv generates rl.ColorFromHSV" {
    const output = try matchAndGetOutput("color_from_hsv");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.ColorFromHSV(") != null);
}

test "e2e: init_audio generates rl.InitAudioDevice" {
    const output = try matchAndGetOutput("init_audio");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.InitAudioDevice()") != null);
}

test "e2e: hide_cursor generates rl.HideCursor" {
    const output = try matchAndGetOutput("hide_cursor");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.HideCursor()") != null);
}

test "e2e: set_texture_filter generates rl.SetTextureFilter" {
    const output = try matchAndGetOutput("set_texture_filter");
    defer freeOutput(output);
    try std.testing.expect(output != null);
    try std.testing.expect(std.mem.indexOf(u8, output.?, "rl.SetTextureFilter(") != null);
}

// ─── Negative tests ───

test "e2e: unknown behavior returns no match" {
    const output = try matchAndGetOutput("fooBarBaz");
    defer freeOutput(output);
    try std.testing.expect(output == null);
}

test "e2e: lifecycle name rejected by rl guard" {
    const output = try matchAndGetOutput("init_system");
    defer freeOutput(output);
    try std.testing.expect(output == null);
}

// ─── Total count test ───

test "all rl patterns match" {
    const all_patterns = [_][]const u8{
        "draw_rect",             "draw_rect_rounded",     "draw_rect_rounded_lines",
        "draw_rect_lines",       "draw_circle",           "draw_circle_lines",
        "draw_triangle",         "draw_line",             "draw_line_ex",
        "draw_fps",              "draw_text",             "draw_text_ex",
        "measure_text",          "measure_text_ex",       "measure_fps",
        "load_font",             "load_font_ex",          "unload_font",
        "handle_mouse",          "handle_keyboard",       "handle_scroll",
        "handle_drag",           "is_key_down",           "is_mouse_released",
        "get_char_pressed",      "init_window",           "close_window",
        "should_close",          "setup_frame",           "end_frame",
        "setup_scissor",         "end_scissor",           "get_screen_size",
        "get_frame_time",        "get_time",              "set_window_min_size",
        "set_window_focused",    "get_dpi_scale",         "get_monitor_size",
        "set_exit_key",          "with_alpha",            "color_from_hsv",
        "color_tint",            "color_brightness",      "init_audio",
        "close_audio",           "hide_cursor",           "show_cursor",
        "set_texture_filter",    "render_panel",          "render_button",
        "render_scroll_indicator", "render_gradient",     "render_tab_bar",
        "render_tooltip",        "render_progress_bar",   "render_divider",
        "render_badge",
    };

    // Every pattern in the list must match
    for (all_patterns) |name| {
        const allocator = std.testing.allocator;
        var builder = CodeBuilder.init(allocator);
        defer builder.deinit();
        var b = makeBehavior(name);
        const matched = try match(&builder, &b);
        if (!matched) {
            std.debug.print("FAILED: pattern '{s}' did not match\n", .{name});
        }
        try std.testing.expect(matched);

        // Every match must generate rl.* code
        const output = builder.getOutput();
        try std.testing.expect(output.len > 0);
    }
}
