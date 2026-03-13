// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Sacred Music v1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ-based acoustics, sacred frequencies, harmonic analysis
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_colors = @import("tri_colors.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden ratio
pub const PHI: f64 = 1.6180339887498948482;

/// φ²
pub const PHI_SQUARED: f64 = PHI * PHI; // = 2.6180339887498948482

/// 1/φ
pub const PHI_INVERSE: f64 = 1.0 / PHI; // = 0.6180339887498948482

/// A4 standard pitch (Hz)
pub const A4_STANDARD: f64 = 440.0;

/// A4 sacred pitch (Verdi tuning, Hz)
pub const A4_SACRED: f64 = 432.0;

/// C5 sacred frequency (Hz) - DNA repair
pub const C5_MIRACLE: f64 = 528.0;

/// UT sacred frequency (Hz)
pub const UT_SOLFEGGIO: f64 = 396.0;

/// Base frequency for calculations (A4 = 440Hz standard)
pub const BASE_FREQ: f64 = 440.0;

// ═══════════════════════════════════════════════════════════════════════════════
// NOTE ENUMERATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Note = enum(u4) {
    C = 0,
    C_SHARP = 1,
    D = 2,
    D_SHARP = 3,
    E = 4,
    F = 5,
    F_SHARP = 6,
    G = 7,
    G_SHARP = 8,
    A = 9,
    A_SHARP = 10,
    B = 11,

    pub fn name(self: Note) []const u8 {
        return switch (self) {
            .C => "C",
            .C_SHARP => "C#",
            .D => "D",
            .D_SHARP => "D#",
            .E => "E",
            .F => "F",
            .F_SHARP => "F#",
            .G => "G",
            .G_SHARP => "G#",
            .A => "A",
            .A_SHARP => "A#",
            .B => "B",
        };
    }

    pub fn fromString(s: []const u8) ?Note {
        // Handle note with octave (e.g., "A4", "C#5")
        const note_part = if (s.len > 1) s[0..@min(3, s.len)] else s;

        if (std.mem.eql(u8, note_part, "C") or std.mem.eql(u8, note_part, "c")) return .C;
        if (std.mem.eql(u8, note_part, "C#") or std.mem.eql(u8, note_part, "c#") or std.mem.eql(u8, note_part, "Db")) return .C_SHARP;
        if (std.mem.eql(u8, note_part, "D") or std.mem.eql(u8, note_part, "d")) return .D;
        if (std.mem.eql(u8, note_part, "D#") or std.mem.eql(u8, note_part, "d#") or std.mem.eql(u8, note_part, "Eb")) return .D_SHARP;
        if (std.mem.eql(u8, note_part, "E") or std.mem.eql(u8, note_part, "e")) return .E;
        if (std.mem.eql(u8, note_part, "F") or std.mem.eql(u8, note_part, "f")) return .F;
        if (std.mem.eql(u8, note_part, "F#") or std.mem.eql(u8, note_part, "f#") or std.mem.eql(u8, note_part, "Gb")) return .F_SHARP;
        if (std.mem.eql(u8, note_part, "G") or std.mem.eql(u8, note_part, "g")) return .G;
        if (std.mem.eql(u8, note_part, "G#") or std.mem.eql(u8, note_part, "g#") or std.mem.eql(u8, note_part, "Ab")) return .G_SHARP;
        if (std.mem.eql(u8, note_part, "A") or std.mem.eql(u8, note_part, "a")) return .A;
        if (std.mem.eql(u8, note_part, "A#") or std.mem.eql(u8, note_part, "a#") or std.mem.eql(u8, note_part, "Bb")) return .A_SHARP;
        if (std.mem.eql(u8, note_part, "B") or std.mem.eql(u8, note_part, "b")) return .B;
        return null;
    }

    /// Get semitone offset from C
    pub fn semitones(self: Note) u4 {
        return @intFromEnum(self);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCALE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ScaleType = enum {
    major,
    minor,
    pentatonic_major,
    pentatonic_minor,
    blues,
    phi_scale, // φ-based scale
    solfeggio, // Solfeggio frequencies
    raga_bhairavi, // Indian raga
    raga_yaman, // Indian raga
};

/// Scale interval patterns (semitones from root)
pub const ScalePatterns = struct {
    pub const MAJOR = [_]u4{ 0, 2, 4, 5, 7, 9, 11 };
    pub const MINOR = [_]u4{ 0, 2, 3, 5, 7, 8, 10 };
    pub const PENTATONIC_MAJOR = [_]u4{ 0, 2, 4, 7, 9 };
    pub const PENTATONIC_MINOR = [_]u4{ 0, 3, 5, 7, 10 };
    pub const BLUES = [_]u4{ 0, 3, 5, 6, 7, 10 };
    pub const PHI_SCALE = [_]u4{ 0, 2, 4, 7, 9, 11 }; // Similar to major but with φ-based intervals
    pub const SOLFEGGIO = [_]u4{ 0, 2, 4, 6, 8, 10, 12 }; // Augmented-like pattern
};

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FREQUENCIES (Solfeggio + Earth resonance)
// ═══════════════════════════════════════════════════════════════════════════════

pub const SacredFrequency = struct {
    name: []const u8,
    frequency: f64,
    description: []const u8,

    pub fn init(name: []const u8, freq: f64, desc: []const u8) SacredFrequency {
        return .{
            .name = name,
            .frequency = freq,
            .description = desc,
        };
    }
};

/// Solfeggio frequencies (sacred sound)
pub const SOLFEGGIO_FREQUENCIES = [_]SacredFrequency{
    SacredFrequency.init("UT", 396.0, "Liberating guilt and fear"),
    SacredFrequency.init("RE", 417.0, "Transmuting negative energy"),
    SacredFrequency.init("MI", 528.0, "DNA repair, miracle tone"),
    SacredFrequency.init("FA", 639.0, "Connecting relationships"),
    SacredFrequency.init("SOL", 741.0, "Awakening intuition"),
    SacredFrequency.init("LA", 852.0, "Returning to spiritual order"),
};

/// Earth resonance frequencies
pub const EARTH_FREQUENCIES = [_]SacredFrequency{
    SacredFrequency.init("Schumann Resonance", 7.83, "Earth's electromagnetic heartbeat"),
    SacredFrequency.init("Alpha State", 10.0, "Relaxed awareness"),
    SacredFrequency.init("Theta State", 6.0, "Deep meditation"),
    SacredFrequency.init("Delta State", 2.0, "Deep sleep"),
};

/// Fibonacci-based frequencies (φ relationship)
pub const FIBONACCI_FREQUENCIES = [_]SacredFrequency{
    SacredFrequency.init("Fib(1)", 1.0, "Unity"),
    SacredFrequency.init("Fib(2)", 1.0, "Duality"),
    SacredFrequency.init("Fib(3)", 2.0, "Balance"),
    SacredFrequency.init("Fib(4)", 3.0, "Harmony"),
    SacredFrequency.init("Fib(5)", 5.0, "Growth"),
    SacredFrequency.init("Fib(6)", 8.0, "Power"),
    SacredFrequency.init("Fib(7)", 13.0, "Transformation"),
    SacredFrequency.init("Fib(8)", 21.0, "Ascension"),
    SacredFrequency.init("Fib(9)", 34.0, "Creation"),
    SacredFrequency.init("Fib(10)", 55.0, "Infinite"),
    SacredFrequency.init("Fib(11)", 89.0, "Universal"),
    SacredFrequency.init("Fib(12)", 144.0, "Sacred completion"),
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHORD TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChordType = enum {
    major, // 1-3-5 (major third + perfect fifth)
    minor, // 1-3b-5 (minor third + perfect fifth)
    diminished, // 1-3b-5b (minor third + diminished fifth)
    augmented, // 1-3-5# (major third + augmented fifth)
    seventh, // 1-3-5-7b (dominant 7th)
    major_seventh, // 1-3-5-7 (major 7th)
    minor_seventh, // 1-3b-5-7b (minor 7th)
    phi_chord, // φ-based chord (sacred proportions)
    power, // 1-5 (power chord)
    sus2, // 1-2-5 (suspended 2nd)
    sus4, // 1-4-5 (suspended 4th)
};

pub const ChordIntervals = struct {
    pub const MAJOR = [_]u4{ 0, 4, 7 };
    pub const MINOR = [_]u4{ 0, 3, 7 };
    pub const DIMINISHED = [_]u4{ 0, 3, 6 };
    pub const AUGMENTED = [_]u4{ 0, 4, 8 };
    pub const SEVENTH = [_]u4{ 0, 4, 7, 10 };
    pub const MAJOR_SEVENTH = [_]u4{ 0, 4, 7, 11 };
    pub const MINOR_SEVENTH = [_]u4{ 0, 3, 7, 10 };
    pub const PHI_CHORD = [_]u4{ 0, 4, 7, 11 }; // Major 7th (φ proportions)
    pub const POWER = [_]u4{ 0, 7 };
    pub const SUS2 = [_]u4{ 0, 2, 7 };
    pub const SUS4 = [_]u4{ 0, 5, 7 };
};

// ═══════════════════════════════════════════════════════════════════════════════
// WAVEFORM TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const WaveformType = enum {
    sine,
    square,
    triangle,
    sawtooth,
    phi_spiral, // φ-modulated sine
    sacred_pulse, // Special sacred pulse pattern
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate frequency from note using equal temperament
pub fn noteToFrequency(note: Note, octave: i4) f64 {
    const semitones_from_a4 = (@as(i16, octave) * 12 + @as(i16, note.semitones())) - @as(i16, 9 + 48); // A4 = octave 4, semitone 9, 4*12=48
    return A4_STANDARD * std.math.pow(f64, 2.0, @as(f64, @floatFromInt(semitones_from_a4)) / 12.0);
}

/// Calculate frequency from note using sacred A4 = 432Hz
pub fn noteToFrequencySacred(note: Note, octave: i4) f64 {
    const semitones_from_a4 = (@as(i16, octave) * 12 + @as(i16, note.semitones())) - @as(i16, 9 + 48);
    return A4_SACRED * std.math.pow(f64, 2.0, @as(f64, @floatFromInt(semitones_from_a4)) / 12.0);
}

/// Calculate note from frequency (equal temperament)
pub fn frequencyToNote(freq: f64) struct { note: Note, octave: i4, cents: i5 } {
    const semitones_from_a4 = 12.0 * std.math.log2(freq / A4_STANDARD);
    const absolute_semitone = @as(i5, @intFromFloat(@round(semitones_from_a4))) + @as(i5, 9) + @as(i5, 4 * 12);
    const octave = @as(i4, @intCast((absolute_semitone - 9) / 12));
    const semitone = @as(u4, @intCast(absolute_semitone - @as(i5, octave * 12)));
    const cents = @as(i5, @intFromFloat((semitones_from_a4 - @round(semitones_from_a4)) * 100.0));

    return .{
        .note = @as(Note, @enumFromInt(semitone % 12)),
        .octave = octave,
        .cents = cents,
    };
}

/// Calculate cents between two frequencies
pub fn frequencyToCents(freq1: f64, freq2: f64) f64 {
    return 1200.0 * std.math.log2(freq2 / freq1);
}

/// Generate φ-based frequency series
pub fn phiFrequencySeries(base_freq: f64, n: usize) f64 {
    return base_freq * std.math.pow(f64, PHI, @as(f64, @floatFromInt(n)));
}

/// Check if interval is φ-harmonic (within tolerance)
pub fn isPhiHarmonic(freq1: f64, freq2: f64, tolerance: f64) bool {
    const ratio = freq2 / freq1;
    return @abs(ratio - PHI) < tolerance or @abs(ratio - PHI_SQUARED) < tolerance or @abs(ratio - PHI_INVERSE) < tolerance;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAVEFORM GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate sine wave sample
pub fn sineWave(phase: f64) f64 {
    return std.math.sin(phase * 2.0 * std.math.pi);
}

/// Generate square wave sample
pub fn squareWave(phase: f64) f64 {
    return if (phase < 0.5) 1.0 else -1.0;
}

/// Generate triangle wave sample
pub fn triangleWave(phase: f64) f64 {
    if (phase < 0.25) return 4.0 * phase;
    if (phase < 0.75) return 2.0 - 4.0 * phase;
    return -4.0 + 4.0 * phase;
}

/// Generate sawtooth wave sample
pub fn sawtoothWave(phase: f64) f64 {
    return 2.0 * phase - 1.0;
}

/// Generate φ-spiral wave (φ-modulated sine)
pub fn phiSpiralWave(phase: f64, harmonics: usize) f64 {
    var result: f64 = 0.0;
    var amplitude: f64 = 1.0;

    for (0..harmonics) |i| {
        const harmonic_freq = @as(f64, @floatFromInt(i + 1));
        result += amplitude * std.math.sin(phase * harmonic_freq * 2.0 * std.math.pi);
        amplitude /= PHI; // Each harmonic decays by φ
    }

    return result;
}

/// Generate waveform sample
pub fn generateWaveform(waveform: WaveformType, phase: f64) f64 {
    return switch (waveform) {
        .sine => sineWave(phase),
        .square => squareWave(phase),
        .triangle => triangleWave(phase),
        .sawtooth => sawtoothWave(phase),
        .phi_spiral => phiSpiralWave(phase, 7), // 7 φ-harmonics
        .sacred_pulse => phiSpiralWave(phase, 3), // 3 φ-harmonics for sacred pulse
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHORD ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub const Chord = struct {
    root: Note,
    chord_type: ChordType,
    frequencies: []const f64,
    intervals: []const u4,

    pub fn init(root: Note, chord_type: ChordType, allocator: std.mem.Allocator) !Chord {
        const intervals = switch (chord_type) {
            .major => &ChordIntervals.MAJOR,
            .minor => &ChordIntervals.MINOR,
            .diminished => &ChordIntervals.DIMINISHED,
            .augmented => &ChordIntervals.AUGMENTED,
            .seventh => &ChordIntervals.SEVENTH,
            .major_seventh => &ChordIntervals.MAJOR_SEVENTH,
            .minor_seventh => &ChordIntervals.MINOR_SEVENTH,
            .phi_chord => &ChordIntervals.PHI_CHORD,
            .power => &ChordIntervals.POWER,
            .sus2 => &ChordIntervals.SUS2,
            .sus4 => &ChordIntervals.SUS4,
        };

        const frequencies = try allocator.alloc(f64, intervals.len);
        for (intervals, 0..) |interval, i| {
            frequencies[i] = noteToFrequency(root, 4) * std.math.pow(f64, 2.0, @as(f64, @floatFromInt(interval)) / 12.0);
        }

        return .{
            .root = root,
            .chord_type = chord_type,
            .frequencies = frequencies,
            .intervals = intervals,
        };
    }

    pub fn deinit(self: *const Chord, allocator: std.mem.Allocator) void {
        allocator.free(self.frequencies);
    }

    pub fn isPhiHarmonic(self: *const Chord) bool {
        if (self.frequencies.len < 2) return false;

        for (self.frequencies[1..]) |freq| {
            // Check if interval is φ-harmonic using the standalone function
            const ratio = freq / self.frequencies[0];
            if (!(@abs(ratio - PHI) < 0.1 or @abs(ratio - PHI_SQUARED) < 0.1 or @abs(ratio - PHI_INVERSE) < 0.1)) {
                return false;
            }
        }
        return true;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SCALE GENERATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const Scale = struct {
    root: Note,
    scale_type: ScaleType,
    notes: []const Note,

    pub fn init(root: Note, scale_type: ScaleType, allocator: std.mem.Allocator) !Scale {
        const intervals = switch (scale_type) {
            .major => &ScalePatterns.MAJOR,
            .minor => &ScalePatterns.MINOR,
            .pentatonic_major => &ScalePatterns.PENTATONIC_MAJOR,
            .pentatonic_minor => &ScalePatterns.PENTATONIC_MINOR,
            .blues => &ScalePatterns.BLUES,
            .phi_scale => &ScalePatterns.PHI_SCALE,
            .solfeggio => &ScalePatterns.SOLFEGGIO,
            .raga_bhairavi => &ScalePatterns.MINOR, // Bhairavi ~ minor
            .raga_yaman => &ScalePatterns.MAJOR, // Yaman ~ major
        };

        const notes = try allocator.alloc(Note, intervals.len);
        for (intervals, 0..) |interval, i| {
            const semitone = (@as(u4, @intFromEnum(root)) + interval) % 12;
            notes[i] = @as(Note, @enumFromInt(semitone));
        }

        return .{
            .root = root,
            .scale_type = scale_type,
            .notes = notes,
        };
    }

    pub fn deinit(self: *const Scale, allocator: std.mem.Allocator) void {
        allocator.free(self.notes);
    }

    pub fn getFrequencies(self: *const Scale, octave: i4, allocator: std.mem.Allocator) ![]const f64 {
        const frequencies = try allocator.alloc(f64, self.notes.len);
        for (self.notes, 0..) |note, i| {
            frequencies[i] = noteToFrequency(note, octave);
        }
        return frequencies;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RESONANCE CALCULATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ResonanceResult = struct {
    fundamental: f64,
    harmonics: []const f64,
    phi_harmonics: []const f64,
    is_sacred: bool,

    pub fn deinit(self: *const ResonanceResult, allocator: std.mem.Allocator) void {
        allocator.free(self.harmonics);
        allocator.free(self.phi_harmonics);
    }
};

/// Calculate resonance pattern for a frequency
pub fn calculateResonance(freq: f64, n_harmonics: usize, allocator: std.mem.Allocator) !ResonanceResult {
    const harmonics = try allocator.alloc(f64, n_harmonics);
    const phi_harmonics = try allocator.alloc(f64, n_harmonics);
    var is_sacred = false;

    for (0..n_harmonics) |i| {
        const n = @as(f64, @floatFromInt(i + 1));
        harmonics[i] = freq * n;
        phi_harmonics[i] = freq * std.math.pow(f64, PHI, n);
    }

    // Check if fundamental matches sacred frequencies
    for (SOLFEGGIO_FREQUENCIES) |sacred| {
        if (@abs(freq - sacred.frequency) < 1.0) {
            is_sacred = true;
            break;
        }
    }

    return .{
        .fundamental = freq,
        .harmonics = harmonics,
        .phi_harmonics = phi_harmonics,
        .is_sacred = is_sacred,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HARMONIC ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════

pub const HarmonyAnalysis = struct {
    intervals: []const f64, // Ratios between frequencies
    phi_ratios: usize, // Count of φ-based ratios
    consonance: f64, // 0-1 consonance score
    sacred_match: ?[]const u8, // Matching sacred frequency name

    pub fn deinit(self: *const HarmonyAnalysis, allocator: std.mem.Allocator) void {
        allocator.free(self.intervals);
        if (self.sacred_match) |s| allocator.free(s);
    }
};

/// Analyze harmonic relationship between frequencies
pub fn analyzeHarmony(frequencies: []const f64, allocator: std.mem.Allocator) !HarmonyAnalysis {
    if (frequencies.len < 2) {
        return .{
            .intervals = &.{},
            .phi_ratios = 0,
            .consonance = 1.0,
            .sacred_match = null,
        };
    }

    const intervals = try allocator.alloc(f64, frequencies.len - 1);
    var phi_ratios: usize = 0;
    var total_consonance: f64 = 0.0;
    var sacred_match: ?[]const u8 = null;

    for (frequencies[1..], 0..) |freq, i| {
        const ratio = freq / frequencies[0];
        intervals[i] = ratio;

        // Check for φ ratio
        if (isPhiHarmonic(frequencies[0], freq, 0.05)) {
            phi_ratios += 1;
        }

        // Simple consonance measure (small integer ratios = consonant)
        const inverted = @abs(ratio - @round(ratio));
        total_consonance += 1.0 - @as(f64, @min(1.0, inverted));

        // Check sacred frequency match
        if (sacred_match == null) {
            for (SOLFEGGIO_FREQUENCIES) |sacred| {
                if (@abs(freq - sacred.frequency) < 5.0) {
                    sacred_match = try allocator.dupe(u8, sacred.name);
                    break;
                }
            }
        }
    }

    const avg_consonance = if (intervals.len > 0) total_consonance / @as(f64, @floatFromInt(intervals.len)) else 1.0;

    return .{
        .intervals = intervals,
        .phi_ratios = phi_ratios,
        .consonance = avg_consonance,
        .sacred_match = sacred_match,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Show all sacred frequencies
pub fn cmdShowSacredFrequencies(_: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║              SACRED FREQUENCIES                              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("Solfeggio Frequencies:\n", .{});
    for (SOLFEGGIO_FREQUENCIES) |freq| {
        tri_colors.printGreen("  {s} {d:.2} Hz", .{ freq.name, freq.frequency });
        tri_colors.printWhite(" — {s}\n", .{freq.description});
    }

    tri_colors.printCyan("\nEarth Resonance:\n", .{});
    for (EARTH_FREQUENCIES) |freq| {
        tri_colors.printGreen("  {s} {d:.2} Hz", .{ freq.name, freq.frequency });
        tri_colors.printWhite(" — {s}\n", .{freq.description});
    }

    tri_colors.printCyan("\nFibonacci Frequencies:\n", .{});
    for (FIBONACCI_FREQUENCIES) |freq| {
        tri_colors.printGreen("  {s} {d:.2} Hz", .{ freq.name, freq.frequency });
        tri_colors.printWhite(" — {s}\n", .{freq.description});
    }

    tri_colors.printWhite("\nφ = {d:.15}...\n", .{PHI});
    tri_colors.printWhite("φ² = {d:.15}...\n", .{PHI_SQUARED});
    tri_colors.printWhite("1/φ = {d:.15}...\n", .{PHI_INVERSE});
}

/// Calculate frequency from note
pub fn cmdNoteToFrequency(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 1) {
        tri_colors.printRed("Error: Missing note argument\n", .{});
        tri_colors.printGray("Usage: tri music note <note> [octave] [--sacred]\n", .{});
        tri_colors.printGray("Example: tri music note A 4\n", .{});
        tri_colors.printGray("         tri music note C 5 --sacred\n", .{});
        return;
    }

    const note_str = args[0];

    // Try to parse note+octave from first arg (e.g., "A4"), or note only (e.g., "A")
    var note_part: []const u8 = note_str;
    var octave_from_input: ?i4 = null;

    // Check if the input ends with a digit (octave number)
    if (note_str.len > 1) {
        const last_char = note_str[note_str.len - 1];
        if (last_char >= '0' and last_char <= '9') {
            // Input includes octave like "A4" or "C#5"
            var end_idx: usize = note_str.len;
            while (end_idx > 0) : (end_idx -= 1) {
                const c = note_str[end_idx - 1];
                if (c < '0' or c > '9') break;
            }
            note_part = note_str[0..end_idx];
            octave_from_input = std.fmt.parseInt(i4, note_str[end_idx..], 10) catch 4;
        }
    }

    const note = Note.fromString(note_part) orelse {
        tri_colors.printRed("Error: Invalid note '{s}'\n", .{note_str});
        tri_colors.printGray("Valid notes: C, C#, D, D#, E, F, F#, G, G#, A, A#, B (with optional octave)\n", .{});
        tri_colors.printGray("Examples: A4, C#5, Bb3\n", .{});
        return;
    };

    var octave: i4 = octave_from_input orelse 4;
    var use_sacred = false;

    // Check for additional arguments
    var arg_idx: usize = 1;
    while (arg_idx < args.len) : (arg_idx += 1) {
        if (std.mem.eql(u8, args[arg_idx], "--sacred")) {
            use_sacred = true;
        } else if (octave_from_input == null) {
            // Second argument could be octave if not already parsed
            octave = std.fmt.parseInt(i4, args[arg_idx], 10) catch octave;
        }
    }

    const freq = if (use_sacred) noteToFrequencySacred(note, octave) else noteToFrequency(note, octave);

    tri_colors.printGold("\n╔═ FREQUENCY ═\n\n", .{});
    tri_colors.printGreen("Note: {s}{d}\n", .{ note.name(), octave });
    tri_colors.printCyan("Frequency: {d:.2} Hz\n", .{freq});

    if (use_sacred) {
        tri_colors.printGold(" (Sacred A4 = 432 Hz)\n", .{});
    } else {
        tri_colors.printGray(" (Standard A4 = 440 Hz)\n", .{});
    }

    // Find closest sacred frequency
    var closest: ?SacredFrequency = null;
    var closest_diff: f64 = 1000.0;

    for (SOLFEGGIO_FREQUENCIES) |sacred| {
        const diff = @abs(freq - sacred.frequency);
        if (diff < closest_diff) {
            closest_diff = diff;
            closest = sacred;
        }
    }

    if (closest) |s| {
        if (closest_diff < 100.0) {
            tri_colors.printCyan("Closest sacred: {s} ({d:.2} Hz) — {d:.1} cents\n", .{ s.name, s.frequency, (freq - s.frequency) / s.frequency * 1200.0 });
        }
    }

    tri_colors.printWhite("\n", .{});
}

/// Show scale notes and frequencies
pub fn cmdShowScale(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        tri_colors.printRed("Error: Missing scale arguments\n", .{});
        tri_colors.printGray("Usage: tri music scale <note> <type>\n", .{});
        tri_colors.printGray("Types: major, minor, pentatonic-major, pentatonic-minor, blues, phi, solfeggio\n", .{});
        tri_colors.printGray("Example: tri music scale C major\n", .{});
        return;
    }

    const note_str = args[0];
    const note = Note.fromString(note_str) orelse {
        tri_colors.printRed("Error: Invalid note '{s}'\n", .{note_str});
        return;
    };

    const scale_type_str = args[1];
    const scale_type = parseScaleType(scale_type_str) orelse {
        tri_colors.printRed("Error: Invalid scale type '{s}'\n", .{scale_type_str});
        tri_colors.printGray("Valid types: major, minor, pentatonic-major, pentatonic-minor, blues, phi, solfeggio\n", .{});
        return;
    };

    var scale = try Scale.init(note, scale_type, allocator);
    defer scale.deinit(allocator);

    const octave: i4 = 4;
    const frequencies = try scale.getFrequencies(octave, allocator);
    defer allocator.free(frequencies);

    tri_colors.printGold("\n╔═ {s} {s} SCALE ═\n\n", .{ note.name(), @tagName(scale_type) });

    for (scale.notes, frequencies, 0..) |n, freq, i| {
        tri_colors.printGreen("{d}. {s}", .{ i + 1, n.name() });
        tri_colors.printCyan(" — {d:.2} Hz", .{freq});

        // Check for sacred match
        for (SOLFEGGIO_FREQUENCIES) |sacred| {
            if (@abs(freq - sacred.frequency) < 5.0) {
                tri_colors.printGold(" [{s}]", .{sacred.name});
            }
        }

        tri_colors.printWhite("\n", .{});
    }

    tri_colors.printWhite("\n", .{});
}

/// Analyze a chord
pub fn cmdAnalyzeChord(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        tri_colors.printRed("Error: Missing chord arguments\n", .{});
        tri_colors.printGray("Usage: tri music chord <note> <type>\n", .{});
        tri_colors.printGray("Types: major, minor, seventh, major-7th, minor-7th, phi, power\n", .{});
        tri_colors.printGray("Example: tri music chord C major\n", .{});
        return;
    }

    const note_str = args[0];
    const note = Note.fromString(note_str) orelse {
        tri_colors.printRed("Error: Invalid note '{s}'\n", .{note_str});
        return;
    };

    const chord_type_str = args[1];
    const chord_type = parseChordType(chord_type_str) orelse {
        tri_colors.printRed("Error: Invalid chord type '{s}'\n", .{chord_type_str});
        tri_colors.printGray("Valid types: major, minor, diminished, augmented, seventh, major-7th, minor-7th, phi, power, sus2, sus4\n", .{});
        return;
    };

    var chord = try Chord.init(note, chord_type, allocator);
    defer chord.deinit(allocator);

    tri_colors.printGold("\n╔═ {s} {s} CHORD ═\n\n", .{ note.name(), @tagName(chord_type) });

    for (chord.frequencies, chord.intervals, 0..) |freq, interval, i| {
        const note_name = @as(Note, @enumFromInt((note.semitones() + interval) % 12)).name();
        tri_colors.printGreen("{d}. {s} (+{d} st)", .{ i + 1, note_name, interval });
        tri_colors.printCyan(" — {d:.2} Hz\n", .{freq});
    }

    // Check φ-harmonicity
    if (chord.isPhiHarmonic()) {
        tri_colors.printGold("\n✓ φ-HARMONIC CHORD\n", .{});
    }

    // Analyze harmony
    const analysis = try analyzeHarmony(chord.frequencies, allocator);
    defer analysis.deinit(allocator);

    tri_colors.printCyan("\nConsonance: {d:.1}%\n", .{analysis.consonance * 100.0});
    if (analysis.phi_ratios > 0) {
        tri_colors.printGold("φ ratios: {d}\n", .{analysis.phi_ratios});
    }

    tri_colors.printWhite("\n", .{});
}

/// Calculate resonance for a frequency
pub fn cmdCalculateResonance(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        tri_colors.printRed("Error: Missing frequency argument\n", .{});
        tri_colors.printGray("Usage: tri music resonance <frequency> [harmonics]\n", .{});
        tri_colors.printGray("Example: tri music resonance 432 10\n", .{});
        return;
    }

    const freq = std.fmt.parseFloat(f64, args[0]) catch {
        tri_colors.printRed("Error: Invalid frequency '{s}'\n", .{args[0]});
        return;
    };

    var n_harmonics: usize = 12;
    if (args.len >= 2) {
        n_harmonics = std.fmt.parseInt(usize, args[1], 10) catch 12;
    }

    var result = try calculateResonance(freq, n_harmonics, allocator);
    defer result.deinit(allocator);

    tri_colors.printGold("\n╔═ RESONANCE ANALYSIS: {d:.2} Hz ═\n\n", .{freq});

    tri_colors.printCyan("Fundamental: {d:.2} Hz", .{result.fundamental});
    if (result.is_sacred) {
        tri_colors.printGold(" ✓ SACRED\n", .{});
    } else {
        tri_colors.printWhite("\n", .{});
    }

    tri_colors.printCyan("\nHarmonics (n × f):\n", .{});
    for (result.harmonics, 0..) |h, i| {
        if (i < 12) {
            tri_colors.printGray("  {d:2}. {d:.2} Hz\n", .{ i + 1, h });
        }
    }

    tri_colors.printCyan("\nφ-Harmonics (f × φⁿ):\n", .{});
    for (result.phi_harmonics, 0..) |h, i| {
        if (i < 12) {
            const phi_pow = std.math.pow(f64, PHI, @as(f64, @floatFromInt(i + 1)));
            tri_colors.printGold("  {d:2}. {d:.2} Hz (φ^{d} = {d:.3})\n", .{ i + 1, h, i + 1, phi_pow });
        }
    }

    tri_colors.printWhite("\n", .{});
}

/// Generate waveform samples
pub fn cmdGenerateWaveform(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    if (args.len < 1) {
        tri_colors.printRed("Error: Missing waveform type\n", .{});
        tri_colors.printGray("Usage: tri music waveform <type> [samples]\n", .{});
        tri_colors.printGray("Types: sine, square, triangle, sawtooth, phi-spiral, sacred-pulse\n", .{});
        tri_colors.printGray("Example: tri music waveform phi-spiral 32\n", .{});
        return;
    }

    const waveform_type = parseWaveformType(args[0]) orelse {
        tri_colors.printRed("Error: Invalid waveform type '{s}'\n", .{args[0]});
        tri_colors.printGray("Valid types: sine, square, triangle, sawtooth, phi-spiral, sacred-pulse\n", .{});
        return;
    };

    var n_samples: usize = 16;
    if (args.len >= 2) {
        n_samples = std.fmt.parseInt(usize, args[1], 10) catch 16;
    }

    tri_colors.printGold("\n╔═ {s} WAVEFORM ═\n\n", .{@tagName(waveform_type)});

    for (0..n_samples) |i| {
        const phase = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n_samples));
        const sample = generateWaveform(waveform_type, phase);

        // Visual bar representation
        const bar_len = @as(usize, @intFromFloat(@abs(sample) * 20));
        const bar_char = if (sample >= 0) "█" else "░";
        var bar: [21]u8 = undefined;
        @memset(&bar, ' ');
        for (0..bar_len) |j| bar[j] = bar_char[0];
        bar[bar_len] = 0;

        tri_colors.printCyan("[{d:.2}] ", .{phase});
        tri_colors.printGreen("{s}", .{bar[0..bar_len]});
        const sign_str = if (sample >= 0) "+" else "";
        tri_colors.printWhite(" {s}{d:.3}\n", .{ sign_str, sample });
    }

    tri_colors.printWhite("\n", .{});
}

/// Analyze harmony between frequencies
pub fn cmdAnalyzeHarmony(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        tri_colors.printRed("Error: Missing frequency arguments\n", .{});
        tri_colors.printGray("Usage: tri music harmony <freq1> <freq2> [freq3...]\n", .{});
        tri_colors.printGray("Example: tri music harmony 432 528 639\n", .{});
        return;
    }

    var frequencies_list = try std.ArrayList(f64).initCapacity(allocator, args.len);
    defer frequencies_list.deinit(allocator);

    for (args) |arg| {
        const freq = std.fmt.parseFloat(f64, arg) catch continue;
        try frequencies_list.append(allocator, freq);
    }

    if (frequencies_list.items.len < 2) {
        tri_colors.printRed("Error: At least 2 valid frequencies required\n", .{});
        return;
    }

    const analysis = try analyzeHarmony(frequencies_list.items, allocator);
    defer analysis.deinit(allocator);

    tri_colors.printGold("\n╔═ HARMONIC ANALYSIS ═\n\n", .{});

    for (frequencies_list.items, 0..) |freq, i| {
        tri_colors.printGreen("{d}. {d:.2} Hz\n", .{ i + 1, freq });
    }

    tri_colors.printCyan("\nIntervals (ratios to fundamental):\n", .{});
    for (analysis.intervals, 0..) |ratio, i| {
        const percent = ratio * 100.0;
        const is_phi = isPhiHarmonic(frequencies_list.items[0], frequencies_list.items[i + 1], 0.05);

        tri_colors.printGray("  f{d}/f1 = ", .{i + 2});
        if (is_phi) {
            tri_colors.printGold("{d:.4}", .{ratio});
            tri_colors.printGold(" (φ-ratio!)\n", .{});
        } else {
            tri_colors.printWhite("{d:.4} ({d:.1}%)", .{ ratio, percent });
            tri_colors.printWhite("\n", .{});
        }
    }

    tri_colors.printCyan("\nConsonance Score: {d:.1}%\n", .{analysis.consonance * 100.0});
    if (analysis.phi_ratios > 0) {
        tri_colors.printGold("φ-Based Ratios: {d}\n", .{analysis.phi_ratios});
    }
    if (analysis.sacred_match) |sacred| {
        tri_colors.printGold("Sacred Match: {s}\n", .{sacred});
    }

    tri_colors.printWhite("\n", .{});
}

/// Show φ frequency series
pub fn cmdPhiSeries(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    var base_freq: f64 = 1.0;
    var n_terms: usize = 12;

    if (args.len >= 1) {
        base_freq = std.fmt.parseFloat(f64, args[0]) catch 1.0;
    }
    if (args.len >= 2) {
        n_terms = std.fmt.parseInt(usize, args[1], 10) catch 12;
    }

    tri_colors.printGold("\n╔═ φ FREQUENCY SERIES ═\n\n", .{});
    tri_colors.printCyan("Base: {d:.2} Hz | φ = {d:.15}\n\n", .{ base_freq, PHI });

    for (0..n_terms) |i| {
        const freq = phiFrequencySeries(base_freq, i);
        const phi_power = std.math.pow(f64, PHI, @as(f64, @floatFromInt(i)));

        tri_colors.printGreen("{d:2}. f x phi^{d} = ", .{ i + 1, i });
        tri_colors.printCyan("{d:.6} Hz", .{freq});
        tri_colors.printGray(" (phi^{d} = {d:.6})\n", .{ i, phi_power });
    }

    tri_colors.printWhite("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARSER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

fn parseScaleType(s: []const u8) ?ScaleType {
    if (std.mem.eql(u8, s, "major") or std.mem.eql(u8, s, "maj")) return .major;
    if (std.mem.eql(u8, s, "minor") or std.mem.eql(u8, s, "min")) return .minor;
    if (std.mem.eql(u8, s, "pentatonic-major") or std.mem.eql(u8, s, "pent-maj")) return .pentatonic_major;
    if (std.mem.eql(u8, s, "pentatonic-minor") or std.mem.eql(u8, s, "pent-min")) return .pentatonic_minor;
    if (std.mem.eql(u8, s, "blues")) return .blues;
    if (std.mem.eql(u8, s, "phi") or std.mem.eql(u8, s, "phi-scale")) return .phi_scale;
    if (std.mem.eql(u8, s, "solfeggio") or std.mem.eql(u8, s, "sol")) return .solfeggio;
    if (std.mem.eql(u8, s, "bhairavi") or std.mem.eql(u8, s, "raga-bhairavi")) return .raga_bhairavi;
    if (std.mem.eql(u8, s, "yaman") or std.mem.eql(u8, s, "raga-yaman")) return .raga_yaman;
    return null;
}

fn parseChordType(s: []const u8) ?ChordType {
    if (std.mem.eql(u8, s, "major") or std.mem.eql(u8, s, "maj")) return .major;
    if (std.mem.eql(u8, s, "minor") or std.mem.eql(u8, s, "min")) return .minor;
    if (std.mem.eql(u8, s, "diminished") or std.mem.eql(u8, s, "dim")) return .diminished;
    if (std.mem.eql(u8, s, "augmented") or std.mem.eql(u8, s, "aug")) return .augmented;
    if (std.mem.eql(u8, s, "seventh") or std.mem.eql(u8, s, "7") or std.mem.eql(u8, s, "dom7")) return .seventh;
    if (std.mem.eql(u8, s, "major-7th") or std.mem.eql(u8, s, "maj7")) return .major_seventh;
    if (std.mem.eql(u8, s, "minor-7th") or std.mem.eql(u8, s, "min7")) return .minor_seventh;
    if (std.mem.eql(u8, s, "phi") or std.mem.eql(u8, s, "phi-chord")) return .phi_chord;
    if (std.mem.eql(u8, s, "power") or std.mem.eql(u8, s, "5")) return .power;
    if (std.mem.eql(u8, s, "sus2")) return .sus2;
    if (std.mem.eql(u8, s, "sus4")) return .sus4;
    return null;
}

fn parseWaveformType(s: []const u8) ?WaveformType {
    if (std.mem.eql(u8, s, "sine")) return .sine;
    if (std.mem.eql(u8, s, "square")) return .square;
    if (std.mem.eql(u8, s, "triangle")) return .triangle;
    if (std.mem.eql(u8, s, "sawtooth") or std.mem.eql(u8, s, "saw")) return .sawtooth;
    if (std.mem.eql(u8, s, "phi-spiral") or std.mem.eql(u8, s, "phi")) return .phi_spiral;
    if (std.mem.eql(u8, s, "sacred-pulse") or std.mem.eql(u8, s, "pulse")) return .sacred_pulse;
    return null;
}
