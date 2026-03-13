// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// gematria.zig — Coptic Gematria Engine
// 27 = 3³ glyphs × isopsephy values (1–900)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Coptic alphabet numerals (isopsephy):
//   Units  (matter):   Ⲁ=1 Ⲃ=2 Ⲅ=3 Ⲇ=4 Ⲉ=5 Ⲋ=6 Ⲍ=7 Ⲏ=8 Ⲑ=9
//   Tens   (energy):   Ⲓ=10 Ⲕ=20 Ⲗ=30 Ⲙ=40 Ⲛ=50 Ⲝ=60 Ⲟ=70 Ⲡ=80 Ⲣ=90
//   Hundreds (info):   Ⲥ=100 Ⲧ=200 Ⲩ=300 Ⲫ=400 Ⲭ=500 Ⲯ=600 Ⲱ=700 Ϣ=800 Ϥ=900
//
// Functions:
//   textToGematriaValue(text)  — sum of glyph values in text
//   numberToGlyphs(value)      — decompose number into hundreds+tens+units glyphs
//   glyphToValue(codepoint)    — single glyph → numeric value
//   gematriaToJson(allocator)  — JSON serialization
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════════
// Coptic Glyph Table — 27 entries
// ═══════════════════════════════════════════════════════════════════════════════

pub const GlyphEntry = struct {
    codepoint: u21,
    value: u16,
    index: u8,
};

pub const COPTIC_TABLE = [27]GlyphEntry{
    // Units (matter) — indices 0..8
    .{ .codepoint = 0x2C80, .value = 1, .index = 0 }, // Ⲁ
    .{ .codepoint = 0x2C82, .value = 2, .index = 1 }, // Ⲃ
    .{ .codepoint = 0x2C84, .value = 3, .index = 2 }, // Ⲅ
    .{ .codepoint = 0x2C86, .value = 4, .index = 3 }, // Ⲇ
    .{ .codepoint = 0x2C88, .value = 5, .index = 4 }, // Ⲉ
    .{ .codepoint = 0x2C8A, .value = 6, .index = 5 }, // Ⲋ
    .{ .codepoint = 0x2C8C, .value = 7, .index = 6 }, // Ⲍ
    .{ .codepoint = 0x2C8E, .value = 8, .index = 7 }, // Ⲏ
    .{ .codepoint = 0x2C90, .value = 9, .index = 8 }, // Ⲑ
    // Tens (energy) — indices 9..17
    .{ .codepoint = 0x2C92, .value = 10, .index = 9 }, // Ⲓ
    .{ .codepoint = 0x2C94, .value = 20, .index = 10 }, // Ⲕ
    .{ .codepoint = 0x2C96, .value = 30, .index = 11 }, // Ⲗ
    .{ .codepoint = 0x2C98, .value = 40, .index = 12 }, // Ⲙ
    .{ .codepoint = 0x2C9A, .value = 50, .index = 13 }, // Ⲛ
    .{ .codepoint = 0x2C9C, .value = 60, .index = 14 }, // Ⲝ
    .{ .codepoint = 0x2C9E, .value = 70, .index = 15 }, // Ⲟ
    .{ .codepoint = 0x2CA0, .value = 80, .index = 16 }, // Ⲡ
    .{ .codepoint = 0x2CA2, .value = 90, .index = 17 }, // Ⲣ
    // Hundreds (information) — indices 18..26
    .{ .codepoint = 0x2CA4, .value = 100, .index = 18 }, // Ⲥ
    .{ .codepoint = 0x2CA6, .value = 200, .index = 19 }, // Ⲧ
    .{ .codepoint = 0x2CA8, .value = 300, .index = 20 }, // Ⲩ
    .{ .codepoint = 0x2CAA, .value = 400, .index = 21 }, // Ⲫ
    .{ .codepoint = 0x2CAC, .value = 500, .index = 22 }, // Ⲭ
    .{ .codepoint = 0x2CAE, .value = 600, .index = 23 }, // Ⲯ
    .{ .codepoint = 0x2CB0, .value = 700, .index = 24 }, // Ⲱ
    .{ .codepoint = 0x03E2, .value = 800, .index = 25 }, // Ϣ
    .{ .codepoint = 0x03E4, .value = 900, .index = 26 }, // Ϥ
};

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

pub const GlyphBreakdown = struct {
    glyph: [4]u8, // UTF-8 encoded glyph (max 3 bytes for BMP + null)
    glyph_len: u8,
    index: u8,
    value: u16,
};

pub const GematriaResult = struct {
    input: []const u8,
    mode: Mode,
    glyphs: []GlyphBreakdown,
    total: u32,
    // Optional Sacred Formula fit (filled by caller if desired)
    has_sacred_fit: bool = false,
    sacred_n: i8 = 0,
    sacred_k: i8 = 0,
    sacred_m: i8 = 0,
    sacred_p: i8 = 0,
    sacred_q: i8 = 0,
    sacred_computed: f64 = 0,
    sacred_error_pct: f64 = 0,
};

pub const Mode = enum {
    number_to_glyphs,
    text_to_number,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Core Functions
// ═══════════════════════════════════════════════════════════════════════════════

/// Look up a single codepoint → numeric value. Returns null if not Coptic.
pub fn glyphToValue(codepoint: u21) ?u16 {
    for (COPTIC_TABLE) |entry| {
        if (entry.codepoint == codepoint) return entry.value;
    }
    // Also check lowercase variants (Coptic lowercase = uppercase + 1)
    for (COPTIC_TABLE) |entry| {
        if (entry.codepoint + 1 == codepoint) return entry.value;
    }
    return null;
}

/// Look up a single codepoint → table index. Returns null if not Coptic.
pub fn glyphToIndex(codepoint: u21) ?u8 {
    for (COPTIC_TABLE) |entry| {
        if (entry.codepoint == codepoint) return entry.index;
    }
    for (COPTIC_TABLE) |entry| {
        if (entry.codepoint + 1 == codepoint) return entry.index;
    }
    return null;
}

/// Sum all Coptic glyph values in a UTF-8 text string.
pub fn textToGematriaValue(text: []const u8) u32 {
    var total: u32 = 0;
    var i: usize = 0;
    while (i < text.len) {
        const len = std.unicode.utf8ByteSequenceLength(text[i]) catch {
            i += 1;
            continue;
        };
        if (i + len > text.len) break;
        const cp = std.unicode.utf8Decode(text[i..][0..len]) catch {
            i += 1;
            continue;
        };
        if (glyphToValue(cp)) |val| {
            total += val;
        }
        i += len;
    }
    return total;
}

/// Collect all Coptic glyphs from text as GlyphBreakdown array.
pub fn textToGlyphs(allocator: Allocator, text: []const u8) ![]GlyphBreakdown {
    var list: std.ArrayListUnmanaged(GlyphBreakdown) = .{};
    errdefer list.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        const len = std.unicode.utf8ByteSequenceLength(text[i]) catch {
            i += 1;
            continue;
        };
        if (i + len > text.len) break;
        const cp = std.unicode.utf8Decode(text[i..][0..len]) catch {
            i += 1;
            continue;
        };
        if (glyphToIndex(cp)) |idx| {
            var glyph_buf: [4]u8 = .{ 0, 0, 0, 0 };
            const glyph_len = std.unicode.utf8Encode(COPTIC_TABLE[idx].codepoint, &glyph_buf) catch 0;
            try list.append(allocator, .{
                .glyph = glyph_buf,
                .glyph_len = @intCast(glyph_len),
                .index = idx,
                .value = COPTIC_TABLE[idx].value,
            });
        }
        i += len;
    }

    return list.toOwnedSlice(allocator);
}

/// Decompose a number into Coptic glyphs (hundreds + tens + units).
/// E.g. 137 → Ⲥ(100) + Ⲗ(30) + Ⲍ(7)
/// Handles values up to 999. For larger values, repeats hundreds.
pub fn numberToGlyphs(allocator: Allocator, value: u32) ![]GlyphBreakdown {
    var list: std.ArrayListUnmanaged(GlyphBreakdown) = .{};
    errdefer list.deinit(allocator);

    if (value == 0) return list.toOwnedSlice(allocator);

    var remaining = value;

    // Decompose hundreds (100–900), then tens (10–90), then units (1–9)
    // For values > 900, repeat the largest glyphs
    while (remaining >= 100) {
        // Find the largest hundred that fits
        var best_idx: ?usize = null;
        for (0..27) |j| {
            const idx = 26 - j; // scan from 900 down
            if (COPTIC_TABLE[idx].value <= remaining and COPTIC_TABLE[idx].value >= 100) {
                best_idx = idx;
                break;
            }
        }
        if (best_idx) |idx| {
            var glyph_buf: [4]u8 = .{ 0, 0, 0, 0 };
            const glyph_len = std.unicode.utf8Encode(COPTIC_TABLE[idx].codepoint, &glyph_buf) catch 0;
            try list.append(allocator, .{
                .glyph = glyph_buf,
                .glyph_len = @intCast(glyph_len),
                .index = @intCast(idx),
                .value = COPTIC_TABLE[idx].value,
            });
            remaining -= COPTIC_TABLE[idx].value;
        } else break;
    }

    // Tens
    if (remaining >= 10) {
        // Find the largest ten that fits
        var best_idx: ?usize = null;
        for (0..9) |j| {
            const idx = 17 - j; // scan from 90 down
            if (COPTIC_TABLE[idx].value <= remaining) {
                best_idx = idx;
                break;
            }
        }
        if (best_idx) |idx| {
            var glyph_buf: [4]u8 = .{ 0, 0, 0, 0 };
            const glyph_len = std.unicode.utf8Encode(COPTIC_TABLE[idx].codepoint, &glyph_buf) catch 0;
            try list.append(allocator, .{
                .glyph = glyph_buf,
                .glyph_len = @intCast(glyph_len),
                .index = @intCast(idx),
                .value = COPTIC_TABLE[idx].value,
            });
            remaining -= COPTIC_TABLE[idx].value;
        }
    }

    // Units
    if (remaining >= 1 and remaining <= 9) {
        const idx = remaining - 1; // 1→index 0, 9→index 8
        var glyph_buf: [4]u8 = .{ 0, 0, 0, 0 };
        const glyph_len = std.unicode.utf8Encode(COPTIC_TABLE[idx].codepoint, &glyph_buf) catch 0;
        try list.append(allocator, .{
            .glyph = glyph_buf,
            .glyph_len = @intCast(glyph_len),
            .index = @intCast(idx),
            .value = COPTIC_TABLE[idx].value,
        });
    }

    return list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Serialization
// ═══════════════════════════════════════════════════════════════════════════════

/// Serialize gematria result to JSON
pub fn gematriaToJson(allocator: Allocator, input: []const u8, mode: Mode, glyphs: []const GlyphBreakdown, total: u32) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    const mode_str = switch (mode) {
        .number_to_glyphs => "number_to_glyphs",
        .text_to_number => "text_to_number",
    };

    w.writeAll("{\"input\":\"") catch return error.OutOfMemory;
    // Escape input for JSON
    for (input) |c| {
        switch (c) {
            '"' => w.writeAll("\\\"") catch return error.OutOfMemory,
            '\\' => w.writeAll("\\\\") catch return error.OutOfMemory,
            else => w.writeByte(c) catch return error.OutOfMemory,
        }
    }
    std.fmt.format(w, "\",\"mode\":\"{s}\",\"glyphs\":[", .{mode_str}) catch return error.OutOfMemory;

    for (glyphs, 0..) |g, i| {
        if (i > 0) w.writeAll(",") catch return error.OutOfMemory;
        w.writeAll("{\"glyph\":\"") catch return error.OutOfMemory;
        w.writeAll(g.glyph[0..g.glyph_len]) catch return error.OutOfMemory;
        std.fmt.format(w, "\",\"index\":{d},\"value\":{d}}}", .{ g.index, g.value }) catch return error.OutOfMemory;
    }

    std.fmt.format(w, "],\"total\":{d}}}", .{total}) catch return error.OutOfMemory;

    return buf.toOwnedSlice(allocator);
}

/// Serialize gematria result with Sacred Formula fit to JSON
pub fn gematriaWithFitToJson(
    allocator: Allocator,
    input: []const u8,
    mode: Mode,
    glyphs: []const GlyphBreakdown,
    total: u32,
    fit_n: i8,
    fit_k: i8,
    fit_m: i8,
    fit_p: i8,
    fit_q: i8,
    computed: f64,
    error_pct: f64,
) ![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const w = buf.writer(allocator);

    const mode_str = switch (mode) {
        .number_to_glyphs => "number_to_glyphs",
        .text_to_number => "text_to_number",
    };

    w.writeAll("{\"input\":\"") catch return error.OutOfMemory;
    for (input) |c| {
        switch (c) {
            '"' => w.writeAll("\\\"") catch return error.OutOfMemory,
            '\\' => w.writeAll("\\\\") catch return error.OutOfMemory,
            else => w.writeByte(c) catch return error.OutOfMemory,
        }
    }
    std.fmt.format(w, "\",\"mode\":\"{s}\",\"glyphs\":[", .{mode_str}) catch return error.OutOfMemory;

    for (glyphs, 0..) |g, i| {
        if (i > 0) w.writeAll(",") catch return error.OutOfMemory;
        w.writeAll("{\"glyph\":\"") catch return error.OutOfMemory;
        w.writeAll(g.glyph[0..g.glyph_len]) catch return error.OutOfMemory;
        std.fmt.format(w, "\",\"index\":{d},\"value\":{d}}}", .{ g.index, g.value }) catch return error.OutOfMemory;
    }

    std.fmt.format(w,
        \\],"total":{d},"sacred_fit":{{"n":{d},"k":{d},"m":{d},"p":{d},"q":{d}}},"sacred_computed":{d:.6},"sacred_error_pct":{d:.6}}}
    , .{ total, fit_n, fit_k, fit_m, fit_p, fit_q, computed, error_pct }) catch return error.OutOfMemory;

    return buf.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI Output
// ═══════════════════════════════════════════════════════════════════════════════

/// Print gematria result to stdout (for CLI)
pub fn printGematriaResult(mode: Mode, glyphs: []const GlyphBreakdown, total: u32) void {
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const RESET = "\x1b[0m";

    switch (mode) {
        .number_to_glyphs => {
            std.debug.print("\n{s}Coptic Gematria{s} {s}(Number \xe2\x86\x92 Glyphs){s}\n", .{ GOLDEN, RESET, GRAY, RESET });
            std.debug.print("{s}================================{s}\n\n", .{ GRAY, RESET });
            std.debug.print("  {s}Number:{s} {s}{d}{s}\n\n", .{ GRAY, RESET, WHITE, total, RESET });

            std.debug.print("  {s}Decomposition:{s}\n", .{ CYAN, RESET });
            for (glyphs, 0..) |g, i| {
                if (i > 0) std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
                const kingdom = if (g.value >= 100) "info" else if (g.value >= 10) "energy" else "matter";
                std.debug.print("    {s}{s}{s} = {s}{d}{s}  {s}({s}){s}\n", .{
                    GOLDEN, g.glyph[0..g.glyph_len], RESET,
                    WHITE,  g.value,                 RESET,
                    GRAY,   kingdom,                 RESET,
                });
            }
            std.debug.print("\n  {s}Total:{s} {s}{d}{s}\n", .{ GRAY, RESET, GOLDEN, total, RESET });
        },
        .text_to_number => {
            std.debug.print("\n{s}Coptic Gematria{s} {s}(Text \xe2\x86\x92 Number){s}\n", .{ GOLDEN, RESET, GRAY, RESET });
            std.debug.print("{s}================================{s}\n\n", .{ GRAY, RESET });

            std.debug.print("  {s}Glyphs:{s}\n", .{ CYAN, RESET });
            for (glyphs, 0..) |g, i| {
                if (i > 0) std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
                std.debug.print("    {s}{s}{s} = {s}{d}{s}\n", .{
                    GOLDEN, g.glyph[0..g.glyph_len], RESET,
                    WHITE,  g.value,                 RESET,
                });
            }
            std.debug.print("\n  {s}Sum:{s} {s}{d}{s}\n", .{ GRAY, RESET, GOLDEN, total, RESET });
        },
    }
    std.debug.print("\n{s}\xcf\x86\xc2\xb2 + 1/\xcf\x86\xc2\xb2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "glyphToValue basic lookups" {
    // Ⲁ = 1
    try std.testing.expectEqual(@as(?u16, 1), glyphToValue(0x2C80));
    // Ⲑ = 9
    try std.testing.expectEqual(@as(?u16, 9), glyphToValue(0x2C90));
    // Ⲓ = 10
    try std.testing.expectEqual(@as(?u16, 10), glyphToValue(0x2C92));
    // Ⲥ = 100
    try std.testing.expectEqual(@as(?u16, 100), glyphToValue(0x2CA4));
    // Ϥ = 900
    try std.testing.expectEqual(@as(?u16, 900), glyphToValue(0x03E4));
    // Non-coptic = null
    try std.testing.expectEqual(@as(?u16, null), glyphToValue('A'));
}

test "textToGematriaValue sums correctly" {
    // Ⲁ(1) + Ⲃ(2) + Ⲅ(3) + Ⲇ(4) = 10
    const text = "\xe2\xb2\x80\xe2\xb2\x82\xe2\xb2\x84\xe2\xb2\x86"; // ⲀⲂⲄⲆ
    try std.testing.expectEqual(@as(u32, 10), textToGematriaValue(text));
}

test "textToGematriaValue ignores non-coptic" {
    // "A" is ASCII, not Coptic — should return 0
    try std.testing.expectEqual(@as(u32, 0), textToGematriaValue("ABC"));
}

test "numberToGlyphs decomposes 137" {
    const allocator = std.testing.allocator;
    const glyphs = try numberToGlyphs(allocator, 137);
    defer allocator.free(glyphs);

    // 137 = 100 + 30 + 7
    try std.testing.expectEqual(@as(usize, 3), glyphs.len);
    try std.testing.expectEqual(@as(u16, 100), glyphs[0].value); // Ⲥ
    try std.testing.expectEqual(@as(u16, 30), glyphs[1].value); // Ⲗ
    try std.testing.expectEqual(@as(u16, 7), glyphs[2].value); // Ⲍ
}

test "numberToGlyphs decomposes 999" {
    const allocator = std.testing.allocator;
    const glyphs = try numberToGlyphs(allocator, 999);
    defer allocator.free(glyphs);

    // 999 = 900 + 90 + 9
    try std.testing.expectEqual(@as(usize, 3), glyphs.len);
    try std.testing.expectEqual(@as(u16, 900), glyphs[0].value); // Ϥ
    try std.testing.expectEqual(@as(u16, 90), glyphs[1].value); // Ⲣ
    try std.testing.expectEqual(@as(u16, 9), glyphs[2].value); // Ⲑ
}

test "numberToGlyphs decomposes 42" {
    const allocator = std.testing.allocator;
    const glyphs = try numberToGlyphs(allocator, 42);
    defer allocator.free(glyphs);

    // 42 = 40 + 2
    try std.testing.expectEqual(@as(usize, 2), glyphs.len);
    try std.testing.expectEqual(@as(u16, 40), glyphs[0].value); // Ⲙ
    try std.testing.expectEqual(@as(u16, 2), glyphs[1].value); // Ⲃ
}

test "numberToGlyphs zero returns empty" {
    const allocator = std.testing.allocator;
    const glyphs = try numberToGlyphs(allocator, 0);
    defer allocator.free(glyphs);
    try std.testing.expectEqual(@as(usize, 0), glyphs.len);
}

test "gematriaToJson produces valid JSON" {
    const allocator = std.testing.allocator;
    const glyphs = try numberToGlyphs(allocator, 137);
    defer allocator.free(glyphs);

    const json = try gematriaToJson(allocator, "137", .number_to_glyphs, glyphs, 137);
    defer allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"total\":137") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"number_to_glyphs\"") != null);
}

test "table has 27 entries with correct values" {
    // Verify sum of all values = 1+2+...+9 + 10+20+...+90 + 100+200+...+900
    // = 45 + 450 + 4500 = 4995
    var sum: u32 = 0;
    for (COPTIC_TABLE) |entry| {
        sum += entry.value;
    }
    try std.testing.expectEqual(@as(u32, 4995), sum);
}
