// ═══════════════════════════════════════════════════════════════════════════════
// PARSER SECTIONS — Leaf Section Parsers
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cycle 85: IGLA Phase 5 — Parser section extractors
// Source of truth: specs/tri/igla_parser_phase2.tri
//
// Pure section parsers extracted from vibee_parser.zig.
// Each function takes (source, pos, line, allocator, list) → ScanState.
// Uses parser_utils for all scanning operations.
//
// IGLA ([CYR:[EN]]) — [EN]to[EN], [EN]andin[CYR:[EN]]and[EN] [CYR:[EN]] code
//
// φ² + 1/φ² = 3
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const pu = @import("parser_utils.zig");
const ScanState = pu.ScanState;

const StringHashMap = std.StringHashMap;

// Import types from parser_types (no circular dependency)
const parser_types = @import("parser_types.zig");
const Constant = parser_types.Constant;
const Import = parser_types.Import;
const Field = parser_types.Field;
const CreationPattern = parser_types.CreationPattern;
const Signal = parser_types.Signal;
const ResetDef = parser_types.ResetDef;
const FSMTransition = parser_types.FSMTransition;
const FSMOutput = parser_types.FSMOutput;
const FSMTimer = parser_types.FSMTimer;
const MemoryExport = parser_types.MemoryExport;
const PasPrediction = parser_types.PasPrediction;
const TestCase = parser_types.TestCase;

// ═══════════════════════════════════════════════════════════════════════════════
// LEAF LIST PARSERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse type field definitions (indent 6+): field_name: field_type
pub fn parseFields(source: []const u8, pos: usize, line: usize, allocator: Allocator, fields: *ArrayList(Field)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        const kr = pu.readKey(source, s.pos);
        if (kr.key.len == 0) break;
        s.pos = kr.new_pos;
        s.pos = pu.skipColon(source, s.pos);

        const vr = pu.readValue(source, s.pos);
        try fields.append(allocator, Field{
            .name = kr.key,
            .type_name = vr.value,
        });
        s.pos = vr.new_pos;
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;
    }
    return s;
}

/// Parse enum variant list (indent 6+, dash items)
pub fn parseEnum(source: []const u8, pos: usize, line: usize, allocator: Allocator, enum_variants: *ArrayList([]const u8)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (source[s.pos] == '-') {
            s.pos += 1;
            s.pos = pu.skipInlineWhitespace(source, s.pos);
            const vr = pu.readValue(source, s.pos);
            if (vr.value.len > 0) {
                try enum_variants.append(allocator, vr.value);
            }
            s.pos = vr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
        } else {
            s.pos -= indent;
            break;
        }
    }
    return s;
}

/// Parse constraint strings (indent 6+, dash items)
pub fn parseConstraints(source: []const u8, pos: usize, line: usize, allocator: Allocator, constraints: *ArrayList([]const u8)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        const qr = pu.readQuotedOrValue(source, s.pos, s.line);
        if (qr.value.len > 0) {
            try constraints.append(allocator, qr.value);
        }
        s.pos = qr.new_pos;
        s.line = qr.new_line;
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;
    }
    return s;
}

/// Parse constant definitions (indent 2+, inline or nested format)
pub fn parseConstants(source: []const u8, pos: usize, line: usize, allocator: Allocator, constants: *ArrayList(Constant)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;
        if (indent > 4) {
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
            continue;
        }
        s.pos += indent;

        const kr = pu.readKey(source, s.pos);
        if (kr.key.len == 0) break;
        s.pos = kr.new_pos;

        // Section boundary check
        if (indent == 0 and (std.mem.eql(u8, kr.key, "types") or
            std.mem.eql(u8, kr.key, "creation_patterns") or
            std.mem.eql(u8, kr.key, "behaviors")))
        {
            s.pos -= kr.key.len;
            break;
        }

        s.pos = pu.skipColon(source, s.pos);
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        const inline_vr = pu.readValue(source, s.pos);
        s.pos = inline_vr.new_pos;

        var constant = Constant{
            .name = kr.key,
            .value = 0,
            .description = "",
        };

        if (inline_vr.value.len > 0) {
            constant.value = std.fmt.parseFloat(f64, inline_vr.value) catch 0;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
        } else {
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;

            while (s.pos < source.len) {
                const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
                s = fsk;
                if (s.pos >= source.len) break;

                const field_indent = pu.countIndent(source, s.pos);
                if (field_indent < 4) break;
                s.pos += field_indent;

                const fkr = pu.readKey(source, s.pos);
                if (fkr.key.len == 0) break;
                s.pos = fkr.new_pos;
                s.pos = pu.skipColon(source, s.pos);

                if (std.mem.eql(u8, fkr.key, "value")) {
                    const fvr = pu.readValue(source, s.pos);
                    constant.value = std.fmt.parseFloat(f64, fvr.value) catch 0;
                    s.pos = fvr.new_pos;
                } else if (std.mem.eql(u8, fkr.key, "description")) {
                    const fvr = pu.readQuotedValue(source, s.pos);
                    constant.description = fvr.value;
                    s.pos = fvr.new_pos;
                }
                const fns = pu.skipToNextLine(source, s.pos, s.line);
                s = fns;
            }
        }

        try constants.append(allocator, constant);
    }
    return s;
}

/// Parse import definitions (dash items, indent 2+)
pub fn parseImports(source: []const u8, pos: usize, line: usize, allocator: Allocator, imports: *ArrayList(Import)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;
        s.pos += indent;

        if (source[s.pos] == '-') {
            s.pos += 1;
            s.pos = pu.skipInlineWhitespace(source, s.pos);

            var imp = Import{ .name = "", .path = "" };

            const fkr = pu.readKey(source, s.pos);
            if (fkr.key.len > 0) {
                s.pos = fkr.new_pos;
                s.pos = pu.skipColon(source, s.pos);
                s.pos = pu.skipInlineWhitespace(source, s.pos);

                if (std.mem.eql(u8, fkr.key, "name")) {
                    const vr = pu.readValue(source, s.pos);
                    imp.name = vr.value;
                    s.pos = vr.new_pos;
                } else if (std.mem.eql(u8, fkr.key, "path")) {
                    const vr = pu.readQuotedValue(source, s.pos);
                    imp.path = vr.value;
                    s.pos = vr.new_pos;
                }
            }
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;

            // Read remaining fields
            while (s.pos < source.len) {
                const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
                s = fsk;
                if (s.pos >= source.len) break;

                const field_indent = pu.countIndent(source, s.pos);
                if (field_indent < 4) break;
                s.pos += field_indent;

                const field_kr = pu.readKey(source, s.pos);
                if (field_kr.key.len == 0) break;
                s.pos = field_kr.new_pos;
                s.pos = pu.skipColon(source, s.pos);
                s.pos = pu.skipInlineWhitespace(source, s.pos);

                if (std.mem.eql(u8, field_kr.key, "name")) {
                    const vr = pu.readValue(source, s.pos);
                    imp.name = vr.value;
                    s.pos = vr.new_pos;
                } else if (std.mem.eql(u8, field_kr.key, "path")) {
                    const vr = pu.readQuotedValue(source, s.pos);
                    imp.path = vr.value;
                    s.pos = vr.new_pos;
                }
                const fns = pu.skipToNextLine(source, s.pos, s.line);
                s = fns;
            }

            if (imp.name.len > 0 and imp.path.len > 0) {
                try imports.append(allocator, imp);
            }
        } else {
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
        }
    }
    return s;
}

/// Parse creation pattern definitions (indent 2+)
pub fn parseCreationPatterns(source: []const u8, pos: usize, line: usize, allocator: Allocator, patterns: *ArrayList(CreationPattern)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;
        s.pos += indent;

        const kr = pu.readKey(source, s.pos);
        if (kr.key.len == 0) break;
        s.pos = kr.new_pos;

        // Section boundary check
        if (std.mem.eql(u8, kr.key, "behaviors") or
            std.mem.eql(u8, kr.key, "algorithms") or
            std.mem.eql(u8, kr.key, "wasm_exports") or
            std.mem.eql(u8, kr.key, "types"))
        {
            s.pos -= kr.key.len + indent;
            break;
        }

        s.pos = pu.skipColon(source, s.pos);
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;

        var pattern = CreationPattern{
            .name = kr.key,
            .source = "",
            .transformer = "",
            .result = "",
        };

        while (s.pos < source.len) {
            const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
            s = fsk;
            if (s.pos >= source.len) break;

            const field_indent = pu.countIndent(source, s.pos);
            if (field_indent < 4) break;
            s.pos += field_indent;

            const fkr = pu.readKey(source, s.pos);
            if (fkr.key.len == 0) break;
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);

            if (std.mem.eql(u8, fkr.key, "source")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                pattern.source = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            } else if (std.mem.eql(u8, fkr.key, "transformer")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                pattern.transformer = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            } else if (std.mem.eql(u8, fkr.key, "result")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                pattern.result = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            }
            const fns = pu.skipToNextLine(source, s.pos, s.line);
            s = fns;
        }

        try patterns.append(allocator, pattern);
    }
    return s;
}

/// Parse HDL signal definitions (dash items, indent 2+)
pub fn parseSignals(source: []const u8, pos: usize, line: usize, allocator: Allocator, signals: *ArrayList(Signal)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var signal = Signal{
            .name = "",
            .width = 1,
            .direction = "wire",
            .signed = false,
            .default_value = null,
        };

        const fkr = pu.readKey(source, s.pos);
        if (std.mem.eql(u8, fkr.key, "name")) {
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            const vr = pu.readValue(source, s.pos);
            signal.name = vr.value;
            s.pos = vr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;

            while (s.pos < source.len) {
                const psk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
                s = psk;
                if (s.pos >= source.len) break;

                const prop_indent = pu.countIndent(source, s.pos);
                if (prop_indent < 4) break;
                s.pos += prop_indent;

                const pkr = pu.readKey(source, s.pos);
                if (pkr.key.len == 0) break;
                s.pos = pkr.new_pos;
                s.pos = pu.skipColon(source, s.pos);

                if (std.mem.eql(u8, pkr.key, "width")) {
                    const pvr = pu.readValue(source, s.pos);
                    signal.width = std.fmt.parseInt(u32, pvr.value, 10) catch 1;
                    s.pos = pvr.new_pos;
                } else if (std.mem.eql(u8, pkr.key, "direction")) {
                    const pvr = pu.readValue(source, s.pos);
                    signal.direction = pvr.value;
                    s.pos = pvr.new_pos;
                } else if (std.mem.eql(u8, pkr.key, "signed")) {
                    const pvr = pu.readValue(source, s.pos);
                    signal.signed = std.mem.eql(u8, pvr.value, "true");
                    s.pos = pvr.new_pos;
                } else if (std.mem.eql(u8, pkr.key, "default")) {
                    const pvr = pu.readValue(source, s.pos);
                    signal.default_value = std.fmt.parseInt(i64, pvr.value, 10) catch null;
                    s.pos = pvr.new_pos;
                }
                const pns = pu.skipToNextLine(source, s.pos, s.line);
                s = pns;
            }
        } else {
            s.pos = fkr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
            continue;
        }

        if (signal.name.len > 0) {
            try signals.append(allocator, signal);
        }
    }
    return s;
}

/// Parse reset configuration (indent 2+)
pub fn parseReset(source: []const u8, pos: usize, line: usize, reset: *ResetDef) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;

        s.pos += indent;
        const kr = pu.readKey(source, s.pos);
        if (kr.key.len == 0) {
            s.pos -= indent;
            break;
        }
        s.pos = kr.new_pos;

        if (std.mem.eql(u8, kr.key, "types") or std.mem.eql(u8, kr.key, "behaviors") or std.mem.eql(u8, kr.key, "algorithms")) {
            s.pos -= (indent + kr.key.len);
            break;
        }

        s.pos = pu.skipColon(source, s.pos);

        if (std.mem.eql(u8, kr.key, "type")) {
            const vr = pu.readValue(source, s.pos);
            reset.reset_type = vr.value;
            s.pos = vr.new_pos;
        } else if (std.mem.eql(u8, kr.key, "level")) {
            const vr = pu.readValue(source, s.pos);
            reset.level = vr.value;
            s.pos = vr.new_pos;
        }
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;
    }
    return s;
}

/// Parse FSM transition definitions (indent 6+)
pub fn parseFSMTransitions(source: []const u8, pos: usize, line: usize, allocator: Allocator, transitions: *ArrayList(FSMTransition)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var trans = FSMTransition{
            .from_state = "",
            .to_state = "",
            .condition = "",
        };

        const fkr = pu.readKey(source, s.pos);
        if (std.mem.eql(u8, fkr.key, "from")) {
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            const vr = pu.readValue(source, s.pos);
            trans.from_state = vr.value;
            s.pos = vr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;

            while (s.pos < source.len) {
                const psk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
                s = psk;
                if (s.pos >= source.len) break;

                const prop_indent = pu.countIndent(source, s.pos);
                if (prop_indent < 8) break;
                s.pos += prop_indent;

                const pkr = pu.readKey(source, s.pos);
                if (pkr.key.len == 0) break;
                s.pos = pkr.new_pos;
                s.pos = pu.skipColon(source, s.pos);

                if (std.mem.eql(u8, pkr.key, "to")) {
                    const pvr = pu.readValue(source, s.pos);
                    trans.to_state = pvr.value;
                    s.pos = pvr.new_pos;
                } else if (std.mem.eql(u8, pkr.key, "when") or std.mem.eql(u8, pkr.key, "condition")) {
                    const pvr = pu.readQuotedValue(source, s.pos);
                    trans.condition = pvr.value;
                    s.pos = pvr.new_pos;
                }
                const pns = pu.skipToNextLine(source, s.pos, s.line);
                s = pns;
            }
        } else {
            s.pos = fkr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
            continue;
        }

        if (trans.from_state.len > 0 and trans.to_state.len > 0) {
            try transitions.append(allocator, trans);
        }
    }
    return s;
}

/// Parse FSM timer definitions (indent 6+)
pub fn parseFSMTimers(source: []const u8, pos: usize, line: usize, allocator: Allocator, timers: *ArrayList(FSMTimer)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var timer = FSMTimer{
            .state = "",
            .timeout_constant = "",
            .timeout_value = 0,
        };

        const fkr = pu.readKey(source, s.pos);
        if (std.mem.eql(u8, fkr.key, "state")) {
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            const vr = pu.readValue(source, s.pos);
            timer.state = vr.value;
            s.pos = vr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;

            while (s.pos < source.len) {
                const psk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
                s = psk;
                if (s.pos >= source.len) break;

                const prop_indent = pu.countIndent(source, s.pos);
                if (prop_indent < 8) break;
                s.pos += prop_indent;

                const pkr = pu.readKey(source, s.pos);
                if (pkr.key.len == 0) break;
                s.pos = pkr.new_pos;
                s.pos = pu.skipColon(source, s.pos);

                if (std.mem.eql(u8, pkr.key, "timeout_constant")) {
                    const pvr = pu.readValue(source, s.pos);
                    timer.timeout_constant = pvr.value;
                    s.pos = pvr.new_pos;
                } else if (std.mem.eql(u8, pkr.key, "timeout_value")) {
                    const pvr = pu.readValue(source, s.pos);
                    timer.timeout_value = std.fmt.parseInt(i64, pvr.value, 10) catch 0;
                    s.pos = pvr.new_pos;
                }
                const pns = pu.skipToNextLine(source, s.pos, s.line);
                s = pns;
            }
        } else {
            s.pos = fkr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
            continue;
        }

        if (timer.state.len > 0) {
            try timers.append(allocator, timer);
        }
    }
    return s;
}

/// Parse algorithm step list (indent 6+, dash items)
pub fn parseAlgorithmSteps(source: []const u8, pos: usize, line: usize, allocator: Allocator, steps: *ArrayList([]const u8)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        const qr = pu.readQuotedOrValue(source, s.pos, s.line);
        if (qr.value.len > 0) {
            try steps.append(allocator, qr.value);
        }
        s.pos = qr.new_pos;
        s.line = qr.new_line;
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;
    }
    return s;
}

/// Parse WASM export function list (indent 4+, dash items)
pub fn parseWasmFunctionList(source: []const u8, pos: usize, line: usize, allocator: Allocator, functions: *ArrayList([]const u8)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 4) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        const vr = pu.readValue(source, s.pos);
        if (vr.value.len > 0) {
            try functions.append(allocator, vr.value);
        }
        s.pos = vr.new_pos;
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;
    }
    return s;
}

/// Parse WASM memory export definitions (indent 4+)
pub fn parseWasmMemoryExports(source: []const u8, pos: usize, line: usize, allocator: Allocator, memory: *ArrayList(MemoryExport)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 4) break;
        s.pos += indent;

        const kr = pu.readKey(source, s.pos);
        if (kr.key.len == 0) break;
        s.pos = kr.new_pos;
        s.pos = pu.skipColon(source, s.pos);
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;

        var mem_export = MemoryExport{
            .name = kr.key,
            .size = 0,
            .type_name = null,
            .alignment = 8,
        };

        while (s.pos < source.len) {
            const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
            s = fsk;
            if (s.pos >= source.len) break;

            const field_indent = pu.countIndent(source, s.pos);
            if (field_indent < 6) break;
            s.pos += field_indent;

            const fkr = pu.readKey(source, s.pos);
            if (fkr.key.len == 0) break;
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);

            if (std.mem.eql(u8, fkr.key, "size")) {
                const fvr = pu.readValue(source, s.pos);
                mem_export.size = std.fmt.parseInt(usize, fvr.value, 10) catch 0;
                s.pos = fvr.new_pos;
            } else if (std.mem.eql(u8, fkr.key, "type")) {
                const fvr = pu.readValue(source, s.pos);
                mem_export.type_name = fvr.value;
                s.pos = fvr.new_pos;
            } else if (std.mem.eql(u8, fkr.key, "alignment")) {
                const fvr = pu.readValue(source, s.pos);
                mem_export.alignment = std.fmt.parseInt(usize, fvr.value, 10) catch 8;
                s.pos = fvr.new_pos;
            }
            const fns = pu.skipToNextLine(source, s.pos, s.line);
            s = fns;
        }

        try memory.append(allocator, mem_export);
    }
    return s;
}

/// Parse PAS prediction entries (dash items, indent 2+)
pub fn parsePasPredictions(source: []const u8, pos: usize, line: usize, allocator: Allocator, predictions: *ArrayList(PasPrediction)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var prediction = PasPrediction{
            .target = "",
            .current = "",
            .predicted = "",
            .confidence = 0.0,
            .pattern = "",
            .status = null,
            .timeline = null,
        };

        const fkr = pu.readKey(source, s.pos);
        if (fkr.key.len > 0) {
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            if (std.mem.eql(u8, fkr.key, "target")) {
                const vr = pu.readValue(source, s.pos);
                prediction.target = vr.value;
                s.pos = vr.new_pos;
            }
        }
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;

        while (s.pos < source.len) {
            const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
            s = fsk;
            if (s.pos >= source.len) break;

            const field_indent = pu.countIndent(source, s.pos);
            if (field_indent < 4) break;
            s.pos += field_indent;

            const field_kr = pu.readKey(source, s.pos);
            if (field_kr.key.len == 0) break;
            s.pos = field_kr.new_pos;
            s.pos = pu.skipColon(source, s.pos);

            if (std.mem.eql(u8, field_kr.key, "target")) {
                const pvr = pu.readValue(source, s.pos);
                prediction.target = pvr.value;
                s.pos = pvr.new_pos;
            } else if (std.mem.eql(u8, field_kr.key, "current")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                prediction.current = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            } else if (std.mem.eql(u8, field_kr.key, "predicted")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                prediction.predicted = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            } else if (std.mem.eql(u8, field_kr.key, "confidence")) {
                const pvr = pu.readValue(source, s.pos);
                prediction.confidence = std.fmt.parseFloat(f64, pvr.value) catch 0.0;
                s.pos = pvr.new_pos;
            } else if (std.mem.eql(u8, field_kr.key, "pattern")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                prediction.pattern = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            } else if (std.mem.eql(u8, field_kr.key, "status")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                prediction.status = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            } else if (std.mem.eql(u8, field_kr.key, "timeline")) {
                const qr = pu.readQuotedOrValue(source, s.pos, s.line);
                prediction.timeline = qr.value;
                s.pos = qr.new_pos;
                s.line = qr.new_line;
            }
            const pns = pu.skipToNextLine(source, s.pos, s.line);
            s = pns;
        }

        if (prediction.target.len > 0) {
            try predictions.append(allocator, prediction);
        }
    }
    return s;
}

/// Parse test case definitions (indent 6+, dash items)
pub fn parseTestCases(source: []const u8, pos: usize, line: usize, allocator: Allocator, test_cases: *ArrayList(TestCase)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1;
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var test_case = TestCase{
            .name = "",
            .input = "",
            .expected = "",
            .tolerance = null,
        };

        const fkr = pu.readKey(source, s.pos);
        if (fkr.key.len > 0) {
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            if (std.mem.eql(u8, fkr.key, "input")) {
                const br = pu.readBraceValue(source, s.pos, s.line);
                test_case.input = br.value;
                s.pos = br.new_pos;
                s.line = br.new_line;
            } else if (std.mem.eql(u8, fkr.key, "name")) {
                const vr = pu.readValue(source, s.pos);
                test_case.name = vr.value;
                s.pos = vr.new_pos;
            }
        }
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;

        while (s.pos < source.len) {
            const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
            s = fsk;
            if (s.pos >= source.len) break;

            const field_indent = pu.countIndent(source, s.pos);
            if (field_indent < 8) break;
            s.pos += field_indent;

            const field_kr = pu.readKey(source, s.pos);
            if (field_kr.key.len == 0) break;
            s.pos = field_kr.new_pos;
            s.pos = pu.skipColon(source, s.pos);

            if (std.mem.eql(u8, field_kr.key, "name")) {
                const pvr = pu.readValue(source, s.pos);
                test_case.name = pvr.value;
                s.pos = pvr.new_pos;
            } else if (std.mem.eql(u8, field_kr.key, "input")) {
                const br = pu.readBraceValue(source, s.pos, s.line);
                test_case.input = br.value;
                s.pos = br.new_pos;
                s.line = br.new_line;
            } else if (std.mem.eql(u8, field_kr.key, "expected")) {
                const pvr = pu.readValue(source, s.pos);
                test_case.expected = pvr.value;
                s.pos = pvr.new_pos;
            } else if (std.mem.eql(u8, field_kr.key, "tolerance")) {
                const pvr = pu.readValue(source, s.pos);
                test_case.tolerance = std.fmt.parseFloat(f64, pvr.value) catch null;
                s.pos = pvr.new_pos;
            }
            const pns = pu.skipToNextLine(source, s.pos, s.line);
            s = pns;
        }

        try test_cases.append(allocator, test_case);
    }
    return s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parseFields reads field definitions" {
    const source = "      name: String\n      age: Int\n  next:";
    var fields: ArrayList(Field) = .{};
    defer fields.deinit(std.testing.allocator);
    const s = try parseFields(source, 0, 1, std.testing.allocator, &fields);
    try std.testing.expectEqual(@as(usize, 2), fields.items.len);
    try std.testing.expectEqualStrings("name", fields.items[0].name);
    try std.testing.expectEqualStrings("String", fields.items[0].type_name);
    try std.testing.expectEqualStrings("age", fields.items[1].name);
    _ = s;
}

test "parseEnum reads variant list" {
    const source = "      - red\n      - green\n      - blue\n  end:";
    var variants: ArrayList([]const u8) = .{};
    defer variants.deinit(std.testing.allocator);
    const s = try parseEnum(source, 0, 1, std.testing.allocator, &variants);
    try std.testing.expectEqual(@as(usize, 3), variants.items.len);
    try std.testing.expectEqualStrings("red", variants.items[0]);
    _ = s;
}

test "parseConstraints reads constraint strings" {
    const source = "      - \"value >= 0\"\n      - \"is_valid(value)\"\n  end:";
    var constraints: ArrayList([]const u8) = .{};
    defer constraints.deinit(std.testing.allocator);
    const s = try parseConstraints(source, 0, 1, std.testing.allocator, &constraints);
    try std.testing.expectEqual(@as(usize, 2), constraints.items.len);
    try std.testing.expectEqualStrings("value >= 0", constraints.items[0]);
    _ = s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CYCLE 86 — PHASE 3: FINAL LEAF PARSERS
// ═══════════════════════════════════════════════════════════════════════════════
// Source of truth: specs/tri/igla_parser_phase3.tri

/// Parse const definitions (indent 6+): key: "value"
/// Uses StringHashMap — keys are owned (allocator.dupe), values reference source.
pub fn parseConsts(source: []const u8, pos: usize, line: usize, allocator: Allocator, consts: *StringHashMap([]const u8)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        const kr = pu.readKey(source, s.pos);
        if (kr.key.len == 0) break;
        s.pos = kr.new_pos;
        s.pos = pu.skipColon(source, s.pos);

        const vr = pu.readValue(source, s.pos);
        const name_owned = try allocator.dupe(u8, kr.key);
        try consts.put(name_owned, vr.value);
        s.pos = vr.new_pos;

        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;
    }
    return s;
}

/// Parse FSM output definitions (indent 6+, dash items).
/// Each output has a state and signal HashMap (signal_name -> value).
pub fn parseFSMOutputs(source: []const u8, pos: usize, line: usize, allocator: Allocator, outputs: *ArrayList(FSMOutput)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 6) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1; // skip '-'
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var out = FSMOutput.init(allocator);

        // Read first key (should be 'state')
        const kr = pu.readKey(source, s.pos);
        if (std.mem.eql(u8, kr.key, "state")) {
            s.pos = kr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            const vr = pu.readValue(source, s.pos);
            out.state = vr.value;
            s.pos = vr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;

            // Read output signal values at indent 8+
            while (s.pos < source.len) {
                const sk2 = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
                s = sk2;
                if (s.pos >= source.len) break;

                const prop_indent = pu.countIndent(source, s.pos);
                if (prop_indent < 8) break;
                s.pos += prop_indent;

                const pk = pu.readKey(source, s.pos);
                if (pk.key.len == 0) break;
                s.pos = pk.new_pos;
                s.pos = pu.skipColon(source, s.pos);

                const pvr = pu.readQuotedOrValue(source, s.pos, s.line);
                try out.signals.put(pk.key, pvr.value);
                s.pos = pvr.new_pos;
                s.line = pvr.new_line;

                const ns2 = pu.skipToNextLine(source, s.pos, s.line);
                s = ns2;
            }
        } else {
            s.pos = kr.new_pos;
            const ns = pu.skipToNextLine(source, s.pos, s.line);
            s = ns;
            continue;
        }

        if (out.state.len > 0) {
            try outputs.append(allocator, out);
        }
    }
    return s;
}

/// Parse top-level test_cases section (indent 2+, dash items).
/// Fields: name, given/input, expected, tolerance.
pub fn parseTopLevelTestCases(source: []const u8, pos: usize, line: usize, allocator: Allocator, test_cases: *ArrayList(TestCase)) !ScanState {
    var s = ScanState{ .pos = pos, .line = line };
    while (s.pos < source.len) {
        const sk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
        s = sk;
        if (s.pos >= source.len) break;

        const indent = pu.countIndent(source, s.pos);
        if (indent < 2) break;
        s.pos += indent;

        if (s.pos >= source.len or source[s.pos] != '-') {
            s.pos -= indent;
            break;
        }
        s.pos += 1; // skip '-'
        s.pos = pu.skipInlineWhitespace(source, s.pos);

        var test_case = TestCase{
            .name = "",
            .input = "",
            .expected = "",
            .tolerance = null,
        };

        // First field on same line
        const first_kr = pu.readKey(source, s.pos);
        if (first_kr.key.len > 0) {
            s.pos = first_kr.new_pos;
            s.pos = pu.skipColon(source, s.pos);
            if (std.mem.eql(u8, first_kr.key, "name")) {
                const vr = pu.readValue(source, s.pos);
                test_case.name = vr.value;
                s.pos = vr.new_pos;
            } else if (std.mem.eql(u8, first_kr.key, "given")) {
                const vr = pu.readValue(source, s.pos);
                test_case.input = vr.value;
                s.pos = vr.new_pos;
            } else if (std.mem.eql(u8, first_kr.key, "input")) {
                const br = pu.readBraceValue(source, s.pos, s.line);
                test_case.input = br.value;
                s.pos = br.new_pos;
                s.line = br.new_line;
            }
        }
        const ns = pu.skipToNextLine(source, s.pos, s.line);
        s = ns;

        // Read remaining fields at indent 4+
        while (s.pos < source.len) {
            const fsk = pu.skipEmptyLinesAndComments(source, s.pos, s.line);
            s = fsk;
            if (s.pos >= source.len) break;

            const field_indent = pu.countIndent(source, s.pos);
            if (field_indent < 4) break;
            s.pos += field_indent;

            const fkr = pu.readKey(source, s.pos);
            if (fkr.key.len == 0) {
                s.pos -= field_indent;
                break;
            }
            s.pos = fkr.new_pos;
            s.pos = pu.skipColon(source, s.pos);

            if (std.mem.eql(u8, fkr.key, "name")) {
                const vr = pu.readValue(source, s.pos);
                test_case.name = vr.value;
                s.pos = vr.new_pos;
            } else if (std.mem.eql(u8, fkr.key, "given") or std.mem.eql(u8, fkr.key, "input")) {
                if (s.pos < source.len and source[s.pos] == '"') {
                    const vr = pu.readValue(source, s.pos);
                    test_case.input = vr.value;
                    s.pos = vr.new_pos;
                } else {
                    const br = pu.readBraceValue(source, s.pos, s.line);
                    test_case.input = br.value;
                    s.pos = br.new_pos;
                    s.line = br.new_line;
                }
            } else if (std.mem.eql(u8, fkr.key, "expected")) {
                const vr = pu.readValue(source, s.pos);
                test_case.expected = vr.value;
                s.pos = vr.new_pos;
            } else if (std.mem.eql(u8, fkr.key, "tolerance")) {
                const vr = pu.readValue(source, s.pos);
                test_case.tolerance = std.fmt.parseFloat(f64, vr.value) catch null;
                s.pos = vr.new_pos;
            }
            const fns = pu.skipToNextLine(source, s.pos, s.line);
            s = fns;
        }

        try test_cases.append(allocator, test_case);
    }
    return s;
}

/// Parse bracketed language array: [zig, python, typescript]
/// Returns updated position only (no line tracking — single-line construct).
pub fn parseLanguageArray(source: []const u8, pos: usize, allocator: Allocator, languages: *ArrayList([]const u8)) !usize {
    var p = pos;
    if (p >= source.len or source[p] != '[') return p;
    p += 1; // skip '['

    while (p < source.len) {
        p = pu.skipInlineWhitespace(source, p);
        if (p >= source.len) break;

        if (source[p] == ']') {
            p += 1;
            break;
        }

        if (source[p] == ',') {
            p += 1;
            continue;
        }

        // Read language name
        const start = p;
        while (p < source.len) {
            const c = source[p];
            if (c == ',' or c == ']' or c == ' ' or c == '\t' or c == '\n' or c == '\r') break;
            p += 1;
        }
        const lang = std.mem.trim(u8, source[start..p], " \t");
        if (lang.len > 0) {
            try languages.append(allocator, lang);
        }
    }
    return p;
}

/// Parse targets section (dash-prefixed items).
pub fn parseTargets(source: []const u8, pos: usize, line: usize, allocator: Allocator, targets: *ArrayList([]const u8)) !ScanState {
    var s = pu.skipWhitespaceAndComments(source, pos, line);
    while (s.pos < source.len) {
        s = pu.skipWhitespaceAndComments(source, s.pos, s.line);
        if (s.pos >= source.len) break;

        if (source[s.pos] != '-') break;
        s.pos += 1; // skip '-'
        s = pu.skipWhitespaceAndComments(source, s.pos, s.line);

        const vr = pu.readValue(source, s.pos);
        if (vr.value.len > 0) {
            try targets.append(allocator, vr.value);
        }
        s.pos = vr.new_pos;
    }
    return s;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS — Phase 3
// ═══════════════════════════════════════════════════════════════════════════════

test "parseConsts reads key-value pairs" {
    const source = "      PHI: 1.618\n      TAU: 6.283\n  end:";
    var consts = StringHashMap([]const u8).init(std.testing.allocator);
    defer consts.deinit();
    const s = try parseConsts(source, 0, 1, std.testing.allocator, &consts);
    try std.testing.expectEqual(@as(usize, 2), consts.count());
    try std.testing.expectEqualStrings("1.618", consts.get("PHI").?);
    try std.testing.expectEqualStrings("6.283", consts.get("TAU").?);
    // Free owned keys
    var it = consts.keyIterator();
    while (it.next()) |key| {
        std.testing.allocator.free(key.*);
    }
    _ = s;
}

test "parseTopLevelTestCases reads test entries" {
    const source = "  - name: test1\n    input: {a: 1}\n    expected: 42\n  - name: test2\n    given: hello\n    expected: world\n";
    var cases: ArrayList(TestCase) = .{};
    defer cases.deinit(std.testing.allocator);
    const s = try parseTopLevelTestCases(source, 0, 1, std.testing.allocator, &cases);
    try std.testing.expectEqual(@as(usize, 2), cases.items.len);
    try std.testing.expectEqualStrings("test1", cases.items[0].name);
    try std.testing.expectEqualStrings("test2", cases.items[1].name);
    _ = s;
}

test "parseLanguageArray reads bracketed list" {
    const source = "[zig, python, typescript]";
    var langs: ArrayList([]const u8) = .{};
    defer langs.deinit(std.testing.allocator);
    const p = try parseLanguageArray(source, 0, std.testing.allocator, &langs);
    try std.testing.expectEqual(@as(usize, 3), langs.items.len);
    try std.testing.expectEqualStrings("zig", langs.items[0]);
    try std.testing.expectEqualStrings("python", langs.items[1]);
    try std.testing.expectEqualStrings("typescript", langs.items[2]);
    _ = p;
}

test "parseTargets reads dash items" {
    const source = "- zig\n- varlog\n- python\n";
    var targets: ArrayList([]const u8) = .{};
    defer targets.deinit(std.testing.allocator);
    const s = try parseTargets(source, 0, 1, std.testing.allocator, &targets);
    try std.testing.expectEqual(@as(usize, 3), targets.items.len);
    try std.testing.expectEqualStrings("zig", targets.items[0]);
    try std.testing.expectEqualStrings("varlog", targets.items[1]);
    _ = s;
}

test "parseAlgorithmSteps reads step list" {
    const source = "      - \"Step one\"\n      - \"Step two\"\n  end:";
    var steps: ArrayList([]const u8) = .{};
    defer steps.deinit(std.testing.allocator);
    const s = try parseAlgorithmSteps(source, 0, 1, std.testing.allocator, &steps);
    try std.testing.expectEqual(@as(usize, 2), steps.items.len);
    try std.testing.expectEqualStrings("Step one", steps.items[0]);
    _ = s;
}

test "parseWasmFunctionList reads function names" {
    const source = "    - phi_power\n    - fibonacci\n  end:";
    var functions: ArrayList([]const u8) = .{};
    defer functions.deinit(std.testing.allocator);
    const s = try parseWasmFunctionList(source, 0, 1, std.testing.allocator, &functions);
    try std.testing.expectEqual(@as(usize, 2), functions.items.len);
    try std.testing.expectEqualStrings("phi_power", functions.items[0]);
    _ = s;
}
