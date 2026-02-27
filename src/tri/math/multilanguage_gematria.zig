// ═══════════════════════════════════════════════════════════════════════════════
// MULTILANGUAGE GEMATRIA ENGINE v1.0
// Hebrew • Greek Isopsephy • Arabic Abjad • Coptic Gematria
// ═══════════════════════════════════════════════════════════════════════════════
//
// Ancient numeral systems where letters have numerical values.
// Calculate sacred values from UTF-8 text in multiple languages.
// Detect TRINITY, PHI, PI, and Fibonacci patterns.
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const math = std.math;
const mem = std.mem;
const unicode = std.unicode;
const ArrayListManaged = std.array_list.Managed;

// Sacred constants from sacred_formula.zig
pub const PHI: f64 = 1.6180339887498948482;
pub const PI: f64 = 3.14159265358979323846;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const LanguageGlyph = struct {
    glyph: []const u8,
    codepoint: u21,
    value: u16,
    language: []const u8,
};

pub const SacredPattern = struct {
    name: []const u8,
    value: u32,
    pattern_type: []const u8,
    confidence: f64,
};

pub const MultiLanguageGematria = struct {
    text: []const u8,
    hebrew_value: ?u32,
    greek_value: ?u32,
    arabic_value: ?u32,
    coptic_value: ?u32,
    combined_sacred_score: f64,
    trinity_alignment: f64,
    detected_patterns: []const SacredPattern,
};

// ═══════════════════════════════════════════════════════════════════════════════
// HEBREW GEMATRIA (22 letters + 5 final forms)
// ═══════════════════════════════════════════════════════════════════════════════

// Standard Hebrew gematria values
const hebrew_glyphs = [_]LanguageGlyph{
    // Aleph (1)
    .{ .glyph = "א", .codepoint = 0x05D0, .value = 1, .language = "Hebrew" },
    // Bet (2)
    .{ .glyph = "ב", .codepoint = 0x05D1, .value = 2, .language = "Hebrew" },
    // Gimel (3)
    .{ .glyph = "ג", .codepoint = 0x05D2, .value = 3, .language = "Hebrew" },
    // Dalet (4)
    .{ .glyph = "ד", .codepoint = 0x05D3, .value = 4, .language = "Hebrew" },
    // He (5)
    .{ .glyph = "ה", .codepoint = 0x05D4, .value = 5, .language = "Hebrew" },
    // Vav (6)
    .{ .glyph = "ו", .codepoint = 0x05D5, .value = 6, .language = "Hebrew" },
    // Zayin (7)
    .{ .glyph = "ז", .codepoint = 0x05D6, .value = 7, .language = "Hebrew" },
    // Het (8)
    .{ .glyph = "ח", .codepoint = 0x05D7, .value = 8, .language = "Hebrew" },
    // Tet (9)
    .{ .glyph = "ט", .codepoint = 0x05D8, .value = 9, .language = "Hebrew" },
    // Yod (10)
    .{ .glyph = "י", .codepoint = 0x05D9, .value = 10, .language = "Hebrew" },
    // Kaf (20)
    .{ .glyph = "כ", .codepoint = 0x05DB, .value = 20, .language = "Hebrew" },
    // Lamed (30)
    .{ .glyph = "ל", .codepoint = 0x05DC, .value = 30, .language = "Hebrew" },
    // Mem (40)
    .{ .glyph = "מ", .codepoint = 0x05DE, .value = 40, .language = "Hebrew" },
    // Nun (50)
    .{ .glyph = "נ", .codepoint = 0x05E0, .value = 50, .language = "Hebrew" },
    // Samekh (60)
    .{ .glyph = "ס", .codepoint = 0x05E1, .value = 60, .language = "Hebrew" },
    // Ayin (70)
    .{ .glyph = "ע", .codepoint = 0x05E2, .value = 70, .language = "Hebrew" },
    // Pe (80)
    .{ .glyph = "פ", .codepoint = 0x05E4, .value = 80, .language = "Hebrew" },
    // Tsade (90)
    .{ .glyph = "צ", .codepoint = 0x05E6, .value = 90, .language = "Hebrew" },
    // Qof (100)
    .{ .glyph = "ק", .codepoint = 0x05E7, .value = 100, .language = "Hebrew" },
    // Resh (200)
    .{ .glyph = "ר", .codepoint = 0x05E8, .value = 200, .language = "Hebrew" },
    // Shin (300)
    .{ .glyph = "ש", .codepoint = 0x05E9, .value = 300, .language = "Hebrew" },
    // Tav (400)
    .{ .glyph = "ת", .codepoint = 0x05EA, .value = 400, .language = "Hebrew" },
    // Final forms (sofit)
    // Final Kaf (500)
    .{ .glyph = "ך", .codepoint = 0x05DA, .value = 500, .language = "Hebrew" },
    // Final Mem (600)
    .{ .glyph = "ם", .codepoint = 0x05DD, .value = 600, .language = "Hebrew" },
    // Final Nun (700)
    .{ .glyph = "ן", .codepoint = 0x05DF, .value = 700, .language = "Hebrew" },
    // Final Pe (800)
    .{ .glyph = "ף", .codepoint = 0x05E3, .value = 800, .language = "Hebrew" },
    // Final Tsade (900)
    .{ .glyph = "ץ", .codepoint = 0x05E5, .value = 900, .language = "Hebrew" },
};

pub fn computeHebrewGematria(text: []const u8) u32 {
    var total: u32 = 0;
    var i: usize = 0;

    while (i < text.len) {
        const cp_len = unicode.utf8ByteSequenceLength(text[i]) catch break;
        if (i + cp_len > text.len) break;

        const cp = unicode.utf8Decode(text[i..][0..cp_len]) catch break;

        // Look up codepoint in Hebrew glyphs
        for (hebrew_glyphs) |glyph| {
            if (glyph.codepoint == cp) {
                total += glyph.value;
                break;
            }
        }

        i += cp_len;
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GREEK ISOPSEPHY (24 letters + 3 ancient letters)
// ═══════════════════════════════════════════════════════════════════════════════

const greek_glyphs = [_]LanguageGlyph{
    // Alpha (1)
    .{ .glyph = "Α", .codepoint = 0x0391, .value = 1, .language = "Greek" },
    .{ .glyph = "α", .codepoint = 0x03B1, .value = 1, .language = "Greek" },
    // Beta (2)
    .{ .glyph = "Β", .codepoint = 0x0392, .value = 2, .language = "Greek" },
    .{ .glyph = "β", .codepoint = 0x03B2, .value = 2, .language = "Greek" },
    // Gamma (3)
    .{ .glyph = "Γ", .codepoint = 0x0393, .value = 3, .language = "Greek" },
    .{ .glyph = "γ", .codepoint = 0x03B3, .value = 3, .language = "Greek" },
    // Delta (4)
    .{ .glyph = "Δ", .codepoint = 0x0394, .value = 4, .language = "Greek" },
    .{ .glyph = "δ", .codepoint = 0x03B4, .value = 4, .language = "Greek" },
    // Epsilon (5)
    .{ .glyph = "Ε", .codepoint = 0x0395, .value = 5, .language = "Greek" },
    .{ .glyph = "ε", .codepoint = 0x03B5, .value = 5, .language = "Greek" },
    // Digamma (6) - ancient
    .{ .glyph = "Ϝ", .codepoint = 0x03DC, .value = 6, .language = "Greek" },
    .{ .glyph = "ϝ", .codepoint = 0x03DD, .value = 6, .language = "Greek" },
    // Zeta (7)
    .{ .glyph = "Ζ", .codepoint = 0x0396, .value = 7, .language = "Greek" },
    .{ .glyph = "ζ", .codepoint = 0x03B6, .value = 7, .language = "Greek" },
    // Eta (8)
    .{ .glyph = "Η", .codepoint = 0x0397, .value = 8, .language = "Greek" },
    .{ .glyph = "η", .codepoint = 0x03B7, .value = 8, .language = "Greek" },
    // Theta (9)
    .{ .glyph = "Θ", .codepoint = 0x0398, .value = 9, .language = "Greek" },
    .{ .glyph = "θ", .codepoint = 0x03B8, .value = 9, .language = "Greek" },
    // Iota (10)
    .{ .glyph = "Ι", .codepoint = 0x0399, .value = 10, .language = "Greek" },
    .{ .glyph = "ι", .codepoint = 0x03B9, .value = 10, .language = "Greek" },
    // Kappa (20)
    .{ .glyph = "Κ", .codepoint = 0x039A, .value = 20, .language = "Greek" },
    .{ .glyph = "κ", .codepoint = 0x03BA, .value = 20, .language = "Greek" },
    // Lambda (30)
    .{ .glyph = "Λ", .codepoint = 0x039B, .value = 30, .language = "Greek" },
    .{ .glyph = "λ", .codepoint = 0x03BB, .value = 30, .language = "Greek" },
    // Mu (40)
    .{ .glyph = "Μ", .codepoint = 0x039C, .value = 40, .language = "Greek" },
    .{ .glyph = "μ", .codepoint = 0x03BC, .value = 40, .language = "Greek" },
    // Nu (50)
    .{ .glyph = "Ν", .codepoint = 0x039D, .value = 50, .language = "Greek" },
    .{ .glyph = "ν", .codepoint = 0x03BD, .value = 50, .language = "Greek" },
    // Xi (60)
    .{ .glyph = "Ξ", .codepoint = 0x039E, .value = 60, .language = "Greek" },
    .{ .glyph = "ξ", .codepoint = 0x03BE, .value = 60, .language = "Greek" },
    // Omicron (70)
    .{ .glyph = "Ο", .codepoint = 0x039F, .value = 70, .language = "Greek" },
    .{ .glyph = "ο", .codepoint = 0x03BF, .value = 70, .language = "Greek" },
    // Pi (80)
    .{ .glyph = "Π", .codepoint = 0x03A0, .value = 80, .language = "Greek" },
    .{ .glyph = "π", .codepoint = 0x03C0, .value = 80, .language = "Greek" },
    // Koppa (90) - ancient
    .{ .glyph = "Ϙ", .codepoint = 0x03D8, .value = 90, .language = "Greek" },
    .{ .glyph = "ϙ", .codepoint = 0x03D9, .value = 90, .language = "Greek" },
    // Rho (100)
    .{ .glyph = "Ρ", .codepoint = 0x03A1, .value = 100, .language = "Greek" },
    .{ .glyph = "ρ", .codepoint = 0x03C1, .value = 100, .language = "Greek" },
    // Sigma (200)
    .{ .glyph = "Σ", .codepoint = 0x03A3, .value = 200, .language = "Greek" },
    .{ .glyph = "σ", .codepoint = 0x03C3, .value = 200, .language = "Greek" },
    .{ .glyph = "ς", .codepoint = 0x03C2, .value = 200, .language = "Greek" }, // final sigma
    // Tau (300)
    .{ .glyph = "Τ", .codepoint = 0x03A4, .value = 300, .language = "Greek" },
    .{ .glyph = "τ", .codepoint = 0x03C4, .value = 300, .language = "Greek" },
    // Upsilon (400)
    .{ .glyph = "Υ", .codepoint = 0x03A5, .value = 400, .language = "Greek" },
    .{ .glyph = "υ", .codepoint = 0x03C5, .value = 400, .language = "Greek" },
    // Phi (500)
    .{ .glyph = "Φ", .codepoint = 0x03A6, .value = 500, .language = "Greek" },
    .{ .glyph = "φ", .codepoint = 0x03C6, .value = 500, .language = "Greek" },
    // Chi (600)
    .{ .glyph = "Χ", .codepoint = 0x03A7, .value = 600, .language = "Greek" },
    .{ .glyph = "χ", .codepoint = 0x03C7, .value = 600, .language = "Greek" },
    // Psi (700)
    .{ .glyph = "Ψ", .codepoint = 0x03A8, .value = 700, .language = "Greek" },
    .{ .glyph = "ψ", .codepoint = 0x03C8, .value = 700, .language = "Greek" },
    // Omega (800)
    .{ .glyph = "Ω", .codepoint = 0x03A9, .value = 800, .language = "Greek" },
    .{ .glyph = "ω", .codepoint = 0x03C9, .value = 800, .language = "Greek" },
    // Sampi (900) - ancient
    .{ .glyph = "Ϡ", .codepoint = 0x03E0, .value = 900, .language = "Greek" },
    .{ .glyph = "ϡ", .codepoint = 0x03E1, .value = 900, .language = "Greek" },
};

pub fn computeGreekGematria(text: []const u8) u32 {
    var total: u32 = 0;
    var i: usize = 0;

    while (i < text.len) {
        const cp_len = unicode.utf8ByteSequenceLength(text[i]) catch break;
        if (i + cp_len > text.len) break;

        const cp = unicode.utf8Decode(text[i..][0..cp_len]) catch break;

        for (greek_glyphs) |glyph| {
            if (glyph.codepoint == cp) {
                total += glyph.value;
                break;
            }
        }

        i += cp_len;
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ARABIC ABJAD (28 letters)
// ═══════════════════════════════════════════════════════════════════════════════

const arabic_glyphs = [_]LanguageGlyph{
    // Alif (1)
    .{ .glyph = "ا", .codepoint = 0x0627, .value = 1, .language = "Arabic" },
    // Ba (2)
    .{ .glyph = "ب", .codepoint = 0x0628, .value = 2, .language = "Arabic" },
    // Jim (3)
    .{ .glyph = "ج", .codepoint = 0x062C, .value = 3, .language = "Arabic" },
    // Dal (4)
    .{ .glyph = "د", .codepoint = 0x062F, .value = 4, .language = "Arabic" },
    // Ha (5)
    .{ .glyph = "ه", .codepoint = 0x0647, .value = 5, .language = "Arabic" },
    // Waw (6)
    .{ .glyph = "و", .codepoint = 0x0648, .value = 6, .language = "Arabic" },
    // Zay (7)
    .{ .glyph = "ز", .codepoint = 0x0632, .value = 7, .language = "Arabic" },
    // Ha (8)
    .{ .glyph = "ح", .codepoint = 0x062D, .value = 8, .language = "Arabic" },
    // Ta (9)
    .{ .glyph = "ط", .codepoint = 0x0637, .value = 9, .language = "Arabic" },
    // Ya (10)
    .{ .glyph = "ي", .codepoint = 0x064A, .value = 10, .language = "Arabic" },
    // Kaf (20)
    .{ .glyph = "ك", .codepoint = 0x0643, .value = 20, .language = "Arabic" },
    // Lam (30)
    .{ .glyph = "ل", .codepoint = 0x0644, .value = 30, .language = "Arabic" },
    // Mim (40)
    .{ .glyph = "م", .codepoint = 0x0645, .value = 40, .language = "Arabic" },
    // Nun (50)
    .{ .glyph = "ن", .codepoint = 0x0646, .value = 50, .language = "Arabic" },
    // Sin (60)
    .{ .glyph = "س", .codepoint = 0x0633, .value = 60, .language = "Arabic" },
    // Ayin (70)
    .{ .glyph = "ع", .codepoint = 0x0639, .value = 70, .language = "Arabic" },
    // Fa (80)
    .{ .glyph = "ف", .codepoint = 0x0641, .value = 80, .language = "Arabic" },
    // Sad (90)
    .{ .glyph = "ص", .codepoint = 0x0635, .value = 90, .language = "Arabic" },
    // Qaf (100)
    .{ .glyph = "ق", .codepoint = 0x0642, .value = 100, .language = "Arabic" },
    // Ra (200)
    .{ .glyph = "ر", .codepoint = 0x0631, .value = 200, .language = "Arabic" },
    // Shin (300)
    .{ .glyph = "ش", .codepoint = 0x0634, .value = 300, .language = "Arabic" },
    // Ta (400)
    .{ .glyph = "ت", .codepoint = 0x062A, .value = 400, .language = "Arabic" },
    // Tha (500)
    .{ .glyph = "ث", .codepoint = 0x062B, .value = 500, .language = "Arabic" },
    // Kha (600)
    .{ .glyph = "خ", .codepoint = 0x062E, .value = 600, .language = "Arabic" },
    // Dhal (700)
    .{ .glyph = "ذ", .codepoint = 0x0630, .value = 700, .language = "Arabic" },
    // Dad (800)
    .{ .glyph = "ض", .codepoint = 0x0636, .value = 800, .language = "Arabic" },
    // Zha (900)
    .{ .glyph = "ظ", .codepoint = 0x0638, .value = 900, .language = "Arabic" },
    // Ghayn (1000)
    .{ .glyph = "غ", .codepoint = 0x063A, .value = 1000, .language = "Arabic" },
};

pub fn computeArabicGematria(text: []const u8) u32 {
    var total: u32 = 0;
    var i: usize = 0;

    while (i < text.len) {
        const cp_len = unicode.utf8ByteSequenceLength(text[i]) catch break;
        if (i + cp_len > text.len) break;

        const cp = unicode.utf8Decode(text[i..][0..cp_len]) catch break;

        for (arabic_glyphs) |glyph| {
            if (glyph.codepoint == cp) {
                total += glyph.value;
                break;
            }
        }

        i += cp_len;
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COPTIC GEMATRIA (27 glyphs) - integration with existing system
// ═══════════════════════════════════════════════════════════════════════════════

const coptic_glyphs = [_]LanguageGlyph{
    // Alpha (1)
    .{ .glyph = "Ⲁ", .codepoint = 0x2C80, .value = 1, .language = "Coptic" },
    .{ .glyph = "ⲁ", .codepoint = 0x2C81, .value = 1, .language = "Coptic" },
    // Beta (2)
    .{ .glyph = "Ⲃ", .codepoint = 0x2C82, .value = 2, .language = "Coptic" },
    .{ .glyph = "ⲃ", .codepoint = 0x2C83, .value = 2, .language = "Coptic" },
    // Gamma (3)
    .{ .glyph = "Ⲅ", .codepoint = 0x2C84, .value = 3, .language = "Coptic" },
    .{ .glyph = "ⲅ", .codepoint = 0x2C85, .value = 3, .language = "Coptic" },
    // Delta (4)
    .{ .glyph = "Ⲇ", .codepoint = 0x2C86, .value = 4, .language = "Coptic" },
    .{ .glyph = "ⲇ", .codepoint = 0x2C87, .value = 4, .language = "Coptic" },
    // Epsilon (5)
    .{ .glyph = "Ⲉ", .codepoint = 0x2C88, .value = 5, .language = "Coptic" },
    .{ .glyph = "ⲉ", .codepoint = 0x2C89, .value = 5, .language = "Coptic" },
    // Digamma (6)
    .{ .glyph = "Ⲋ", .codepoint = 0x2C8A, .value = 6, .language = "Coptic" },
    .{ .glyph = "ⲋ", .codepoint = 0x2C8B, .value = 6, .language = "Coptic" },
    // Zeta (7)
    .{ .glyph = "Ⲍ", .codepoint = 0x2C8C, .value = 7, .language = "Coptic" },
    .{ .glyph = "ⲍ", .codepoint = 0x2C8D, .value = 7, .language = "Coptic" },
    // Eta (8)
    .{ .glyph = "Ⲏ", .codepoint = 0x2C8E, .value = 8, .language = "Coptic" },
    .{ .glyph = "ⲏ", .codepoint = 0x2C8F, .value = 8, .language = "Coptic" },
    // Theta (9)
    .{ .glyph = "Ⲑ", .codepoint = 0x2C90, .value = 9, .language = "Coptic" },
    .{ .glyph = "ⲑ", .codepoint = 0x2C91, .value = 9, .language = "Coptic" },
    // Iota (10)
    .{ .glyph = "Ⲓ", .codepoint = 0x2C92, .value = 10, .language = "Coptic" },
    .{ .glyph = "ⲓ", .codepoint = 0x2C93, .value = 10, .language = "Coptic" },
    // Kappa (20)
    .{ .glyph = "Ⲕ", .codepoint = 0x2C94, .value = 20, .language = "Coptic" },
    .{ .glyph = "ⲕ", .codepoint = 0x2C95, .value = 20, .language = "Coptic" },
    // Laula (30)
    .{ .glyph = "Ⲗ", .codepoint = 0x2C96, .value = 30, .language = "Coptic" },
    .{ .glyph = "ⲗ", .codepoint = 0x2C97, .value = 30, .language = "Coptic" },
    // Mi (40)
    .{ .glyph = "Ⲙ", .codepoint = 0x2C98, .value = 40, .language = "Coptic" },
    .{ .glyph = "ⲙ", .codepoint = 0x2C99, .value = 40, .language = "Coptic" },
    // Ni (50)
    .{ .glyph = "Ⲛ", .codepoint = 0x2C9A, .value = 50, .language = "Coptic" },
    .{ .glyph = "ⲛ", .codepoint = 0x2C9B, .value = 50, .language = "Coptic" },
    // Ksi (60)
    .{ .glyph = "Ⲝ", .codepoint = 0x2C9C, .value = 60, .language = "Coptic" },
    .{ .glyph = "ⲝ", .codepoint = 0x2C9D, .value = 60, .language = "Coptic" },
    // O (70)
    .{ .glyph = "Ⲟ", .codepoint = 0x2C9E, .value = 70, .language = "Coptic" },
    .{ .glyph = "ⲟ", .codepoint = 0x2C9F, .value = 70, .language = "Coptic" },
    // Pi (80)
    .{ .glyph = "Ⲡ", .codepoint = 0x2CA0, .value = 80, .language = "Coptic" },
    .{ .glyph = "ⲡ", .codepoint = 0x2CA1, .value = 80, .language = "Coptic" },
    // Rho (100)
    .{ .glyph = "Ⲣ", .codepoint = 0x2CA2, .value = 100, .language = "Coptic" },
    .{ .glyph = "ⲣ", .codepoint = 0x2CA3, .value = 100, .language = "Coptic" },
    // Sima (200)
    .{ .glyph = "Ⲥ", .codepoint = 0x2CA4, .value = 200, .language = "Coptic" },
    .{ .glyph = "ⲥ", .codepoint = 0x2CA5, .value = 200, .language = "Coptic" },
    // Tau (300)
    .{ .glyph = "Ⲧ", .codepoint = 0x2CA6, .value = 300, .language = "Coptic" },
    .{ .glyph = "ⲧ", .codepoint = 0x2CA7, .value = 300, .language = "Coptic" },
    // Epsilon (U) - special (400)
    .{ .glyph = "Ⲩ", .codepoint = 0x2CA8, .value = 400, .language = "Coptic" },
    .{ .glyph = "ⲩ", .codepoint = 0x2CA9, .value = 400, .language = "Coptic" },
    // Phi (500)
    .{ .glyph = "Ⲫ", .codepoint = 0x2CAA, .value = 500, .language = "Coptic" },
    .{ .glyph = "ⲫ", .codepoint = 0x2CAB, .value = 500, .language = "Coptic" },
    // Khi (600)
    .{ .glyph = "Ⲭ", .codepoint = 0x2CAC, .value = 600, .language = "Coptic" },
    .{ .glyph = "ⲭ", .codepoint = 0x2CAD, .value = 600, .language = "Coptic" },
    // Psi (700)
    .{ .glyph = "Ⲯ", .codepoint = 0x2CAE, .value = 700, .language = "Coptic" },
    .{ .glyph = "ⲯ", .codepoint = 0x2CAF, .value = 700, .language = "Coptic" },
    // Oou (800)
    .{ .glyph = "Ⲱ", .codepoint = 0x2CB0, .value = 800, .language = "Coptic" },
    .{ .glyph = "ⲱ", .codepoint = 0x2CB1, .value = 800, .language = "Coptic" },
    // Sampi (900)
    .{ .glyph = "Ⲳ", .codepoint = 0x2CB2, .value = 900, .language = "Coptic" },
    .{ .glyph = "ⲳ", .codepoint = 0x2CB3, .value = 900, .language = "Coptic" },
};

pub fn computeCopticGematria(text: []const u8) u32 {
    var total: u32 = 0;
    var i: usize = 0;

    while (i < text.len) {
        const cp_len = unicode.utf8ByteSequenceLength(text[i]) catch break;
        if (i + cp_len > text.len) break;

        const cp = unicode.utf8Decode(text[i..][0..cp_len]) catch break;

        for (coptic_glyphs) |glyph| {
            if (glyph.codepoint == cp) {
                total += glyph.value;
                break;
            }
        }

        i += cp_len;
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED PATTERN RECOGNITION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn findSacredPattern(value: u32) ?SacredPattern {
    const fval: f64 = @floatFromInt(value);

    // Check TRINITY_27 pattern (most specific)
    if (value % 27 == 0) {
        return SacredPattern{
            .name = "Trinity 27",
            .value = value,
            .pattern_type = "TRINITY_27",
            .confidence = 1.0,
        };
    }

    // Check Fibonacci relationship (specific mathematical property)
    if (isFibonacci(value)) {
        return SacredPattern{
            .name = "Fibonacci",
            .value = value,
            .pattern_type = "FIBONACCI",
            .confidence = 1.0,
        };
    }

    // Check PHI patterns (ratio close to 1.618)
    const phi_ratio = fval / PHI;
    if (@abs(phi_ratio - @floor(phi_ratio)) < 0.01) {
        return SacredPattern{
            .name = "Phi Multiple",
            .value = value,
            .pattern_type = "PHI",
            .confidence = 0.9,
        };
    }

    // Check PI patterns (ratio close to 3.14159)
    const pi_ratio = fval / PI;
    if (@abs(pi_ratio - @floor(pi_ratio)) < 0.01) {
        return SacredPattern{
            .name = "Pi Multiple",
            .value = value,
            .pattern_type = "PI",
            .confidence = 0.9,
        };
    }

    // Check TRINITY_3 pattern (most general - check last)
    if (value % 3 == 0) {
        return SacredPattern{
            .name = "Trinity 3",
            .value = value,
            .pattern_type = "TRINITY_3",
            .confidence = 0.8,
        };
    }

    return null;
}

fn isFibonacci(n: u32) bool {
    // A number is Fibonacci if and only if one or both of (5*n^2 + 4) or (5*n^2 - 4) is a perfect square
    const fn64: f64 = @floatFromInt(n);
    const val1 = 5.0 * fn64 * fn64 + 4.0;
    const val2 = 5.0 * fn64 * fn64 - 4.0;

    return isPerfectSquare(@as(u64, @intFromFloat(val1))) or
           isPerfectSquare(@as(u64, @intFromFloat(val2)));
}

fn isPerfectSquare(n: u64) bool {
    if (n == 0) return true;
    const root = @as(u64, @intFromFloat(@sqrt(@as(f64, @floatFromInt(n)))));
    return root * root == n or (root + 1) * (root + 1) == n;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMBINED ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub fn computeAllGematria(allocator: mem.Allocator, text: []const u8) !MultiLanguageGematria {
    const hebrew_val = computeHebrewGematria(text);
    const greek_val = computeGreekGematria(text);
    const arabic_val = computeArabicGematria(text);
    const coptic_val = computeCopticGematria(text);

    // Detect which language(s) are present
    const has_hebrew = hebrew_val > 0;
    const has_greek = greek_val > 0;
    const has_arabic = arabic_val > 0;
    const has_coptic = coptic_val > 0;

    // Calculate combined sacred score
    var sacred_sum: f64 = 0.0;
    var count: f64 = 0.0;

    if (has_hebrew) {
        sacred_sum += @as(f64, @floatFromInt(hebrew_val));
        count += 1.0;
    }
    if (has_greek) {
        sacred_sum += @as(f64, @floatFromInt(greek_val));
        count += 1.0;
    }
    if (has_arabic) {
        sacred_sum += @as(f64, @floatFromInt(arabic_val));
        count += 1.0;
    }
    if (has_coptic) {
        sacred_sum += @as(f64, @floatFromInt(coptic_val));
        count += 1.0;
    }

    const avg_value = if (count > 0) sacred_sum / count else 0.0;

    // Calculate TRINITY alignment (how close to being divisible by 3)
    const trinity_align = if (count > 0)
        1.0 - (@mod(avg_value, 3.0) / 3.0)
    else 0.0;

    // Collect patterns from all detected languages
    var patterns_list = ArrayListManaged(SacredPattern).init(allocator);
    defer patterns_list.deinit();

    if (has_hebrew) {
        if (findSacredPattern(hebrew_val)) |p| try patterns_list.append(p);
    }
    if (has_greek) {
        if (findSacredPattern(greek_val)) |p| try patterns_list.append(p);
    }
    if (has_arabic) {
        if (findSacredPattern(arabic_val)) |p| try patterns_list.append(p);
    }
    if (has_coptic) {
        if (findSacredPattern(coptic_val)) |p| try patterns_list.append(p);
    }

    // Combined sacred score: average value * trinity alignment * pattern count bonus
    const pattern_bonus = 1.0 + (@as(f64, @floatFromInt(patterns_list.items.len)) * 0.1);
    const combined_score = avg_value * trinity_align * pattern_bonus;

    return MultiLanguageGematria{
        .text = text,
        .hebrew_value = if (has_hebrew) hebrew_val else null,
        .greek_value = if (has_greek) greek_val else null,
        .arabic_value = if (has_arabic) arabic_val else null,
        .coptic_value = if (has_coptic) coptic_val else null,
        .combined_sacred_score = combined_score,
        .trinity_alignment = trinity_align,
        .detected_patterns = try patterns_list.toOwnedSlice(),
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMATTING
// ═══════════════════════════════════════════════════════════════════════════════

pub fn formatGematriaReport(allocator: mem.Allocator, result: MultiLanguageGematria) ![]const u8 {
    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const GREEN = "\x1b[32m";
    const RESET = "\x1b[0m";

    var buffer = ArrayListManaged(u8).init(allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    try writer.print("\n{s}{s}MULTILANGUAGE GEMATRIA ANALYSIS{s}\n", .{ GOLDEN, "════════════════════════════", RESET });
    try writer.print("{s}Text: \"{s}\"{s}\n\n", .{ GRAY, result.text, RESET });

    // Print values for each detected language
    if (result.hebrew_value) |v| {
        try writer.print("  {s}Hebrew Gematria:{s}    {s}{d}{s}\n", .{ CYAN, RESET, WHITE, v, RESET });
    }
    if (result.greek_value) |v| {
        try writer.print("  {s}Greek Isopsephy:{s}    {s}{d}{s}\n", .{ CYAN, RESET, WHITE, v, RESET });
    }
    if (result.arabic_value) |v| {
        try writer.print("  {s}Arabic Abjad:{s}       {s}{d}{s}\n", .{ CYAN, RESET, WHITE, v, RESET });
    }
    if (result.coptic_value) |v| {
        try writer.print("  {s}Coptic Gematria:{s}    {s}{d}{s}\n", .{ CYAN, RESET, WHITE, v, RESET });
    }

    try writer.print("\n", .{});

    // Print sacred metrics
    try writer.print("  {s}Trinity Alignment:{s}  {s}{d:.2}%{s}\n", .{
        GRAY, RESET, GREEN, result.trinity_alignment * 100.0, RESET,
    });
    try writer.print("  {s}Sacred Score:{s}       {s}{d:.2}{s}\n", .{
        GRAY, RESET, WHITE, result.combined_sacred_score, RESET,
    });

    // Print detected patterns
    if (result.detected_patterns.len > 0) {
        try writer.print("\n  {s}Detected Patterns:{s}\n", .{ CYAN, RESET });
        for (result.detected_patterns) |pattern| {
            try writer.print("    {s}{s}{s} ({s}) - {d:.0}% confidence\n", .{
                GOLDEN, pattern.name, RESET, pattern.pattern_type, pattern.confidence * 100.0,
            });
        }
    }

    try writer.print("\n{s}φ² + 1/φ² = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });

    return buffer.toOwnedSlice();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hebrew gematria - chai (life)" {
    // חי (Chet + Yod) = 8 + 10 = 18
    const text = "חי";
    const value = computeHebrewGematria(text);
    try std.testing.expectEqual(@as(u32, 18), value);
}

test "hebrew gematria - yhwh" {
    // יהוה (Yod + He + Vav + He) = 10 + 5 + 6 + 5 = 26
    const text = "יהוה";
    const value = computeHebrewGematria(text);
    try std.testing.expectEqual(@as(u32, 26), value);
}

test "greek isopsephy - iesous" {
    // Ιησους = 10 + 8 + 200 + 70 + 400 + 200 = 888
    const text = "Ιησους";
    const value = computeGreekGematria(text);
    try std.testing.expectEqual(@as(u32, 888), value);
}

test "greek isopsephy - logos" {
    // Λογος = 30 + 70 + 3 + 70 + 200 = 373
    const text = "Λογος";
    const value = computeGreekGematria(text);
    try std.testing.expectEqual(@as(u32, 373), value);
}

test "arabic abjad - allah" {
    // الله (Alif + Lam + Lam + Ha) = 1 + 30 + 30 + 5 = 66
    const text = "الله";
    const value = computeArabicGematria(text);
    try std.testing.expectEqual(@as(u32, 66), value);
}

test "arabic abjad - muhammad" {
    // محمد (Mim + Ha + Mim + Dal) = 40 + 8 + 40 + 4 = 92
    const text = "محمد";
    const value = computeArabicGematria(text);
    try std.testing.expectEqual(@as(u32, 92), value);
}

test "coptic gematria - basic" {
    // ⲀⲂⲄ (Alpha + Beta + Gamma) = 1 + 2 + 3 = 6
    const text = "ⲀⲂⲄ";
    const value = computeCopticGematria(text);
    try std.testing.expectEqual(@as(u32, 6), value);
}

test "sacred pattern - trinity 27" {
    const result = findSacredPattern(27);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("TRINITY_27", result.?.pattern_type);
}

test "sacred pattern - trinity 3" {
    const result = findSacredPattern(6);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("TRINITY_3", result.?.pattern_type);
}

test "sacred pattern - fibonacci" {
    const result = findSacredPattern(144);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("FIBONACCI", result.?.pattern_type);
}

test "fibonacci detection" {
    try std.testing.expect(isFibonacci(0));
    try std.testing.expect(isFibonacci(1));
    try std.testing.expect(isFibonacci(1));
    try std.testing.expect(isFibonacci(2));
    try std.testing.expect(isFibonacci(3));
    try std.testing.expect(isFibonacci(5));
    try std.testing.expect(isFibonacci(8));
    try std.testing.expect(isFibonacci(13));
    try std.testing.expect(isFibonacci(21));
    try std.testing.expect(isFibonacci(34));
    try std.testing.expect(isFibonacci(55));
    try std.testing.expect(isFibonacci(89));
    try std.testing.expect(isFibonacci(144));
    try std.testing.expect(isFibonacci(233));
    try std.testing.expect(!isFibonacci(4));
    try std.testing.expect(!isFibonacci(6));
    try std.testing.expect(!isFibonacci(100));
}

test "compute all gematria - hebrew" {
    const text = "חי";
    const result = try computeAllGematria(std.testing.allocator, text);
    defer std.testing.allocator.free(result.detected_patterns);

    try std.testing.expectEqual(@as(u32, 18), result.hebrew_value.?);
    try std.testing.expect(result.greek_value == null);
    try std.testing.expect(result.arabic_value == null);
    try std.testing.expect(result.coptic_value == null);
}

test "compute all gematria - greek" {
    const text = "Λογος";
    const result = try computeAllGematria(std.testing.allocator, text);
    defer std.testing.allocator.free(result.detected_patterns);

    try std.testing.expect(result.hebrew_value == null);
    try std.testing.expectEqual(@as(u32, 373), result.greek_value.?);
    try std.testing.expect(result.arabic_value == null);
    try std.testing.expect(result.coptic_value == null);
}

test "empty text returns zero" {
    const text = "";
    try std.testing.expectEqual(@as(u32, 0), computeHebrewGematria(text));
    try std.testing.expectEqual(@as(u32, 0), computeGreekGematria(text));
    try std.testing.expectEqual(@as(u32, 0), computeArabicGematria(text));
    try std.testing.expectEqual(@as(u32, 0), computeCopticGematria(text));
}

test "format gematria report" {
    const text = "חי";
    const result = try computeAllGematria(std.testing.allocator, text);
    defer std.testing.allocator.free(result.detected_patterns);

    const report = try formatGematriaReport(std.testing.allocator, result);
    defer std.testing.allocator.free(report);

    try std.testing.expect(report.len > 0);
    // Check that key terms are in the report
    try std.testing.expect(mem.indexOf(u8, report, "Gematria") != null);
    try std.testing.expect(mem.indexOf(u8, report, "Trinity") != null);
}

test "trinity alignment calculation" {
    const text = "אבג"; // Aleph + Bet + Gimel = 1 + 2 + 3 = 6 (divisible by 3)
    const result = try computeAllGematria(std.testing.allocator, text);
    defer std.testing.allocator.free(result.detected_patterns);

    // 6 is divisible by 3, so alignment should be 1.0
    try std.testing.expectApproxEqAbs(1.0, result.trinity_alignment, 0.01);
}

test "combined sacred score" {
    const text = "חי"; // 18 = divisible by 3, should have high score
    const result = try computeAllGematria(std.testing.allocator, text);
    defer std.testing.allocator.free(result.detected_patterns);

    try std.testing.expect(result.combined_sacred_score > 0);
}
