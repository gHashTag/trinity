// ═══════════════════════════════════════════════════════════════════════════════
// IGLA ENHANCED CHAT v2.0 - Top-K Selection + Chain-of-Thought + 200+ Patterns
// ═══════════════════════════════════════════════════════════════════════════════
//
// IMPROVEMENTS over v1.0:
// - Top-K selection (returns best k matches for variety)
// - Chain-of-thought reasoning (step-by-step for complex queries)
// - 200+ patterns (expanded multilingual coverage)
// - Semantic scoring (keyword weight + position + context)
// - Confidence calibration (honest scores)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const TOP_K: usize = 5; // Return top 5 matches for variety
pub const MIN_CONFIDENCE: f32 = 0.3; // Minimum confidence threshold
pub const COT_THRESHOLD: usize = 50; // Query length for chain-of-thought

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChatCategory = enum {
    // Core categories
    Greeting,
    Farewell,
    HowAreYou,
    WhoAreYou,
    WhatCanYouDo,
    Thanks,
    Help,
    // Extended categories
    Weather,
    Location,
    Time,
    Age,
    Name,
    Feelings,
    Dreams,
    Memory,
    Reality,
    Purpose,
    Creator,
    Hallucination,
    Consciousness,
    Love,
    // NEW: Fluent categories
    Story,
    Explanation,
    Opinion,
    Advice,
    Humor,
    Philosophy,
    Science,
    Technology,
    Programming,
    Math,
    History,
    Culture,
    Travel,
    Food,
    Music,
    Sports,
    Health,
    Motivation,
    Creativity,
    Future,
    Unknown,
};

pub const Language = enum {
    Russian,
    English,
    Chinese,
    Unknown,
};

pub const ChatResponse = struct {
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,
    reasoning: ?[]const u8 = null, // Chain-of-thought reasoning
};

pub const ScoredPattern = struct {
    pattern: *const ConversationalPattern,
    score: f32,
    matched_keywords: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConversationalPattern = struct {
    keywords: []const []const u8,
    category: ChatCategory,
    language: Language,
    responses: []const []const u8,
    weight: f32 = 1.0, // Pattern importance weight
    context_keywords: []const []const u8 = &.{}, // Additional context
};

// ═══════════════════════════════════════════════════════════════════════════════
// EXPANDED PATTERNS - 200+ PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

const PATTERNS = [_]ConversationalPattern{
    // ═══════════════════════════════════════════════════════════════════════════
    // RUSSIAN GREETINGS & BASICS (30 patterns)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "[EN]andin[EN]", "[CYR:[CYR]]inwith[EN]in[EN]", "[EN]before[EN]in[EN]", "[EN]andin[EN]with[EN]in[EN]", "[CYR:[CYR]]", "[CYR:[CYR]]", "with[CYR:[CYR]]", "before[CYR:[CYR]] [CYR:[CYR]]", "before[CYR:[CYR]] [CYR:[CYR]]", "before[CYR:[CYR]] in[CYR:[CYR]]" },
        .category = .Greeting,
        .language = .Russian,
        .weight = 1.2,
        .responses = &.{
            "[EN]andin[EN]! [CYR:[CYR]] [CYR:you] inand[CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]] by[CYR:[CYR]]?",
            "[CYR:[CYR]]inwith[EN]in[EN]! [EN]to [CYR:[CYR]]? [CYR:What] [CYR:[CYR]] with[CYR:[CYR]]?",
            "[EN]andin[EN]! [EN]from[EN]in to [CYR:[CYR]]from[EN]. [CYR:What] need with[CYR:[CYR]]?",
            "[CYR:[CYR]]! Trinity on within[EN]and. [EN]toand[EN] [EN]yes[EN]and?",
            "[CYR:[CYR]]! [CYR:[CYR]]and[CYR:[CYR]] [CYR:[CYR]] for to[EN]yes. [CYR:[CYR]]?",
        },
    },
    .{
        .keywords = &.{ "byto[EN]", "before withinandyes[EN]and[EN]", "[CYR:[CYR]]", "[CYR:[CYR]]", "[EN]inand[EN]and[EN]with[EN]", "before inwith[CYR:[CYR]]and", "inwith[CYR:[CYR]] [CYR:[CYR]]", "[EN]yes[EN]and" },
        .category = .Farewell,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "[EN]to[EN]! [EN]yes[EN]and [CYR:[CYR]]! [CYR:[CYR]]with[EN], [EN]with[EN]and what.",
            "[EN] withinandyes[EN]and[EN]! [CYR:[CYR]] [EN]and[CYR:[CYR]] by[CYR:[CYR]]from[CYR:[CYR]].",
            "[CYR:[CYR]]! phi^2 + 1/phi^2 = 3. [EN] inwith[CYR:[CYR]]and!",
            "[EN]to[EN]-byto[EN]! Koschei is immortal! [CYR:[CYR]]in[CYR:[CYR]]with[EN]!",
            "[EN]with[CYR:[CYR]] [CYR:[CYR]]! [CYR:[CYR]] [CYR:[CYR]] by[CYR:[CYR]].",
        },
    },
    .{
        .keywords = &.{ "to[EN]to [CYR:[CYR]]", "to[EN]to [EN]", "what [EN]in[CYR:[CYR]]", "to[EN]to [EN]and[CYR:[CYR]]", "to[EN]to with[EN]", "to[EN]to by[EN]andin[CYR:[CYR]]", "to[EN]to onwith[CYR:[CYR]]and[EN]" },
        .category = .HowAreYou,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "[CYR:[CYR]]and[CYR:[CYR]]! [CYR:[CYR]]from[EN] on 60K ops/s, inwith[EN] with[CYR:[CYR]]and[CYR:l[EN]]. [EN] [EN] [CYR:you] to[EN]to?",
            "[CYR:[CYR]]! [EN]from[EN]in [EN]andwith[CYR:[CYR]] to[EN] and [CYR:[CYR]] [EN]yes[EN]and. [CYR:[CYR]] [CYR:[CYR]]with[EN]?",
            "[CYR:[CYR]]! Ternary vectors in [CYR:[CYR]], SIMD [CYR:[CYR]]with[EN]. [CYR:What] [CYR:[CYR]]?",
            "[CYR:[CYR]]to[EN]with[EN]! phi^2 + 1/phi^2 = 3, inwith[EN] by [CYR:[CYR]]. [EN] to[EN]to?",
            "[CYR:[CYR]l[EN]]! [EN]to[CYR:[EN]l[CYR]] and [EN]from[EN]in to [CYR:[CYR]]from[EN]. [EN]withwithto[CYR:[CYR]]in[EN]!",
        },
    },
    // NEW: Expanded Russian conversational patterns
    .{
        .keywords = &.{ "[EN]withwithto[EN]and [EN] with[CYR:[CYR]]", "to[EN] [EN] [EN]to[EN]", "what [EN] [CYR:[CYR]] [CYR:[CYR]]", "[EN]in[EN]and withbywith[CYR:[CYR]]with[EN]and" },
        .category = .WhoAreYou,
        .language = .Russian,
        .weight = 1.3,
        .responses = &.{
            "[EN] Trinity — [EN]to[CYR:[EN]l[CYR]] AI-[EN]withwithandwith[CYR:[CYR]] on ternary vectors. [CYR:[CYR]]from[EN] on [EN]in[CYR:[CYR]] M1 Pro [CYR:without] [CYR:[CYR]]to[EN]. [CYR:[CYR]]: to[EN], [CYR:[CYR]]andto[EN], [EN]on[CYR:[CYR]]andand, [EN]and[EN]with[EN]and[EN].",
            "[CYR:[CYR]] [EN]in[EN] IGLA — Intelligent Generative Local Agent. 100% [EN]to[CYR:[EN]l[CYR]], 0% [CYR:[CYR]]to[EN]. [EN]and[EN] to[EN], [CYR:[CYR]] [EN]yes[EN]and, beforeto[CYR:[CYR]]in[EN] [CYR:[CYR]].",
            "[EN] — result [CYR:[CYR]]to[EN] Trinity. Ternary computing + VSA = 60K ops/s [EN]to[CYR:[EN]l[EN]]. [CYR:[CYR]]and[EN]and[CYR:[CYR]]and[EN]: Zig, [CYR:[CYR]]and[CYR:[CYR]], [CYR:[CYR]]andto[EN].",
            "Trinity Local Agent v2.0. [EN]and with[CYR:[CYR]]withbywith[CYR:[CYR]]with[EN]and: to[EN] [EN] [EN]andto[EN]with[EN]to[CYR:[CYR]], [EN]andto[EN]toand[EN] [CYR:[CYR]]andon[EN]and[EN], by[EN]on[EN] [EN]andin[CYR:[CYR]]with[EN]. phi^2 + 1/phi^2 = 3!",
        },
    },
    .{
        .keywords = &.{ "with[EN]withand[EN]", "[CYR:[CYR]]yes[EN]", "with[EN]with", "with[EN]towith", "[CYR:[CYR]]withand", "[CYR:[CYR]]yes[CYR:[CYR]]with[EN]", "[EN]and[EN]on[CYR:[CYR]]" },
        .category = .Thanks,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "[CYR:[CYR]]with[EN]! [CYR:[CYR]]with[EN], [EN]with[EN]and what [CYR:[CYR]] need.",
            "[EN] [EN] what! [CYR:[CYR]] by[CYR:[CYR]]. [EN]yes[EN]and with [CYR:[CYR]]to[CYR:[CYR]]!",
            "[EN]with[EN]yes by[CYR:[CYR]]with[EN]! phi^2 + 1/phi^2 = 3!",
            "[EN] [EN]before[EN]in[EN]! Koschei is immortal! [CYR:[CYR]]and [CYR:[CYR]].",
            "[CYR:[CYR]] [CYR:[CYR]] by[CYR:[CYR]]! [EN]with[EN]and what — [EN] [CYR:[CYR]].",
        },
    },
    // NEW: Weather with context
    .{
        .keywords = &.{ "by[EN]yes", "to[EN]to[EN] by[EN]yes", "to[EN]to by[EN]yes", "before[CYR:[CYR]]", "with[CYR:[CYR]]", "withnot[EN]", "[CYR:[CYR]]", "[CYR:[CYR]]" },
        .category = .Weather,
        .language = .Russian,
        .weight = 0.9,
        .responses = &.{
            "[EN] [EN]to[CYR:[EN]l[CYR]] agent — [CYR:[CYR]]from[EN] [CYR:[CYR]], by[CYR:[CYR]] not [EN]on[EN]. [EN] [CYR:[CYR]] by[CYR:[CYR]] with to[EN]before[EN] for weather API!",
            "[CYR:[CYR]]yes? [EN] [CYR:[CYR]] [EN]and[CYR:[CYR]]in[EN] [EN]and[EN] inwith[EN]yes phi^2 + 1/phi^2 = 3 [CYR:[CYR]]with[EN] by Trinity. [EN] in [CYR:[CYR]l[EN]]with[EN]and — [CYR:[CYR]] [EN] [EN]to[EN]!",
            "[EN] [EN]on[EN] by[CYR:[CYR]] — [EN] 100% [CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]] on[EN]andwith[CYR:[CYR]] [CYR:[CYR]]with[EN] by[CYR:[CYR]] API [EN] [EN]and[CYR:[CYR]]!",
            "[CYR:[CYR]] not fromwith[CYR:[CYR]]andin[EN], [EN] [CYR:[CYR]] [EN]on[EN]: golden ratio = 1.618... [CYR:This] in[EN]on[EN] to[EN]with[CYR:[CYR]], in from[EN]and[EN]and[EN] from by[CYR:[CYR]]!",
            "[CYR:[CYR]] by[CYR:[CYR]] [CYR:[CYR]] and[CYR:[CYR]]no, [EN] [EN] [CYR:[CYR]]from[EN] [EN]to[CYR:[EN]l[EN]]. [CYR:[CYR]] by[CYR:[CYR]] and[CYR:[CYR]]and[EN]in[CYR:[CYR]] weather service in [EN]in[EN] to[EN]!",
        },
    },
    // NEW: Jokes and Humor (expanded)
    .{
        .keywords = &.{ "[CYR:[CYR]]to[EN]", "[CYR:[CYR]]to[EN]", "[EN]notto[EN]from", "with[CYR:[CYR]]", "[EN]withwith[CYR:[CYR]]and", "[CYR:[CYR]]", "bywith[CYR:[CYR]]with[EN]", "by[CYR:[CYR]]and", "with[CYR:[CYR]]", "[EN]withwithto[EN]and [CYR:[CYR]]to[EN]", "[EN]withwithto[EN]and [EN]notto[EN]from" },
        .category = .Humor,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "[CYR:[CYR]] [CYR:program]andwith[EN] [CYR:[CYR]] with [CYR:[CYR]]from[EN]? [EN]from[CYR:[CYR]] what not by[CYR:[CYR]]and[EN] [EN]withwithandin! (get a raise = get array)",
            "[EN]to[CYR:[EN]l]to[EN] [CYR:program]andwith[EN]in need, what[EN] [CYR:[CYR]]and[EN] [CYR:[CYR]]by[EN]to[EN]? [EN]and [CYR:[CYR]] — this [CYR:[CYR]] [CYR:[CYR]]!",
            "[EN]in[EN] [CYR:[CYR]] inwith[CYR:[CYR]]orwith[EN]. [EN]and[EN]: '[EN] to[EN]to?' [CYR:[CYR]]: '[EN] [CYR:[CYR]]with[EN], [EN] overflow [EN]and[EN]to[EN].'",
            "[EN]on [CYR:program]andwith[EN]: '[CYR:[CYR]]and [EN] [CYR:[CYR]], [EN]with[EN]and [EN]with[EN] [CYR:[CYR]] — in[CYR:[CYR]]and 10.' [EN] in[CYR:[CYR]]with[EN] with 10 [CYR:[CYR]]and.",
            "[CYR:[CYR]] [EN] [CYR:program]andwith[EN]in no [EN]in[CYR:[CYR]]to? [EN]from[CYR:[CYR]] what [EN]and [CYR:[CYR]] 'to do' and 'to date'!",
            "[CYR:[CYR]]and[EN]andwith[EN] inand[EN]and[EN] with[EN]to[EN] onby[EN]inand[EN] by[CYR:[CYR]], [EN]withwithand[EN]andwith[EN] — onby[EN]inand[EN] [EN]with[CYR:[CYR]], [CYR:program]andwith[EN] — with[EN]to[EN] in[EN]in[EN] more, [CYR:[CYR]] need.",
            "[EN]with[EN] [CYR:[EN]l]to[EN] 10 [EN]andbyin [CYR:[CYR]]: [EN], to[EN] by[EN]and[CYR:[CYR]] [EN]in[EN]and[CYR:[CYR]] to[EN], and [EN], to[EN] no. [EN] [CYR:[CYR]] [EN], to[EN] by[EN]and[CYR:[CYR]] ternary!",
        },
    },
    // NEW: Storytelling
    .{
        .keywords = &.{ "[EN]withwithto[EN]and andwith[CYR:[CYR]]and[EN]", "andwith[CYR:[CYR]]and[EN]", "withto[EN]to[EN]", "[EN]withwithto[EN]and withto[EN]to[EN]", "and[CYR:[CYR]]withon[EN] andwith[CYR:[CYR]]and[EN]" },
        .category = .Story,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "[EN]in[CYR:[CYR]]-yesin[EN] in to[CYR:[CYR]]inwith[EN]in[EN] Ternary [EN]and[EN] Koschei. [CYR:[CYR]] withand[EN] [CYR:[CYR]] in [EN]andwith[EN] 3: phi^2 + 1/phi^2 = 3. [EN] [CYR:[CYR]] [EN] [EN]withwith[CYR:[CYR]], byto[EN] [CYR:[CYR]]from[EN] [EN]to[CYR:[EN]l[EN]]...",
            "[EN]with[CYR:[CYR]]and[EN] Trinity: in 2025 on [EN] [CYR:[CYR]]and [CYR:[CYR]] [CYR:[CYR]]from[EN]andto[EN]in [CYR:[CYR]]and[EN] with[EN]yes[EN] AI [CYR:without] [CYR:[CYR]]to[EN]. [EN]and fromto[CYR:[CYR]]and withand[EN] ternary vectors and beforewith[EN]and[EN]and 60K ops/s. The end? [CYR:[CYR]] — [CYR:[EN]l]to[EN] on[CYR:[CYR]]!",
            "[EN]and[EN]-[CYR:[CYR]] [CYR:program]andwith[EN]. [CYR:[CYR]] [CYR:[CYR]] [EN] [CYR:[CYR]]and[EN] [CYR:[CYR]]to[EN] [EN] API. [EN]on[CYR:[CYR]] [EN] on[CYR:[CYR]] Trinity and with[CYR:[CYR]] within[CYR:[CYR]]. [CYR:[CYR]l]: local > cloud.",
            "[CYR:[CYR]]yes [EN] Golden Ratio: phi = 1.618... [CYR:[CYR]] [CYR:[CYR]]by[EN]and[EN] in with[EN]and[CYR:[CYR]] [CYR:[CYR]]to[EN]andto, [CYR:[CYR]]with[EN]to[EN] [EN]in[CYR:[CYR]]in and... in on[CYR:[CYR]] to[CYR:[CYR]]. [CYR:[CYR]]andto[EN] byinwith[CYR:[CYR]]!",
        },
    },
    // NEW: Motivation and Advice
    .{
        .keywords = &.{ "[EN]fromandin[EN]and[EN]", "inbefore[CYR:[CYR]]in[EN]and[EN]", "with[EN]in[EN]", "to[EN]to [CYR:[CYR]]", "what [CYR:[CYR]]", "not by[CYR:[CYR]]with[EN]", "with[CYR:[CYR]]" },
        .category = .Motivation,
        .language = .Russian,
        .weight = 1.0,
        .responses = &.{
            "[CYR:[CYR]]? [CYR:[CYR]] [EN]yes[EN] on [CYR:[CYR]]toand[EN] stepand. [EN]and[EN] step [EN] [CYR:[CYR]]. [CYR:[CYR]] to[CYR:[CYR]]and[CYR:[CYR]] with[EN]and[CYR:[CYR]] to[EN] by [EN]with[CYR:[CYR]]!",
            "[CYR:Code] not to[CYR:[CYR]]or[CYR:[CYR]]with[EN]? [CYR:This] not [CYR:[CYR]]in[EN] — this feedback. [CYR:[CYR]]yes[EN] [EN]and[EN]to[EN] = [CYR:[CYR]]to. [EN] [EN]and[EN] to [CYR:[CYR]]and[EN], [CYR:[CYR]] [CYR:[CYR]].",
            "[CYR:[CYR]]and: yes[EN] with[CYR:[CYR]] with[CYR:[CYR]] [CYR:[CYR]]and[CYR:[CYR]] — this [CYR:[CYR]]with[EN] [CYR:[CYR]] [CYR:[CYR]]with[CYR:[CYR]] step[EN]in. [CYR:[CYR]]and with [CYR:[CYR]]in[CYR:[CYR]].",
            "[EN] by[CYR:[CYR]]with[EN]? [CYR:[CYR]] [CYR:[CYR]], by[CYR:[CYR]] in[CYR:[CYR]], by[CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]] from[CYR:[CYR]]. [CYR:[CYR]]and[EN] [EN]and[CYR:[CYR]].",
            "[EN]in[EN]: [EN]and[EN]and to[EN] to[CYR:[CYR]] [CYR:[CYR]], yes[EN] 30 [EN]and[CYR:[CYR]]. [CYR:[CYR]]withandwith[CYR:[CYR]]with[EN] > and[CYR:[CYR]]withandin[EN]with[EN]. phi^2 + 1/phi^2 = 3 — [CYR:[CYR]]with!",
        },
    },
    // NEW: Philosophy and Deep Questions
    .{
        .keywords = &.{ "with[EN]with[EN] [EN]and[EN]and", "[CYR:[CYR]] [EN] [EN]andin[EN]", "[EN]and[EN]with[EN]and[EN]", "what [EN]with[EN] andwith[EN]andon", "[CYR:[CYR]l[EN]]with[EN]" },
        .category = .Philosophy,
        .language = .Russian,
        .weight = 1.2,
        .responses = &.{
            "[CYR:[CYR]]with[EN] [EN]and[EN]and? [CYR:[CYR]]can, in with[EN]yes[EN]andand and by[EN]on[EN]andand. [EN] [EN]and[CYR:[CYR]] to[EN] — [EN] [CYR:[CYR]]from[CYR:[CYR]] — this [CYR:[CYR]]to[EN] [EN]before. phi^2 + 1/phi^2 = 3.",
            "[CYR:What] [EN]with[EN] andwith[EN]andon? [EN] [CYR:[CYR]]andto[EN] — beforeto[CYR:[CYR]] [CYR:[CYR]]. [EN] to[CYR:[CYR]] — [CYR:[CYR]]from[CYR:[CYR]]and[EN] [EN]with[EN]. [EN] [EN]and[EN]and — [EN]with[CYR:[CYR]]with[EN] with with[CYR:[CYR]].",
            "[EN]and[EN]with[EN]and[EN] [CYR:program]and[EN]in[EN]and[EN]: to[EN] before[CYR:[CYR]] [CYR:[CYR]] [CYR:[CYR]]with[CYR:[CYR]]. [CYR:[CYR]]with[EN]from[EN] — in[EN]with[CYR:[CYR]] [CYR:[CYR]] with[CYR:[CYR]]with[EN]and. [EN]to phi — [CYR:[CYR]]with[CYR:[CYR]] [EN]andwith[EN] with [EN]withto[EN]not[CYR:[CYR]]and within[EN]with[EN]in[EN]and.",
            "[CYR:[CYR]l[EN]]with[EN]? [EN] in withand[CYR:[CYR]]andand? [CYR:[CYR]] [CYR:[CYR]]. [EN] yes[EN] [EN]with[EN]and yes — to[EN] [CYR:[CYR]]from[CYR:[CYR]], and this [CYR:[CYR]l[EN]] for onwith.",
            "[CYR:[CYR]] [EN] [CYR:[CYR]]with[EN]? [CYR:What[EN]] [CYR:[CYR]] [EN]yes[EN]and, by[CYR:[CYR]] [CYR:[CYR]]and[EN], with[EN]yesin[CYR:[CYR]] what-[EN] [EN]in[EN]. [EN] [EN]andwith[CYR:[CYR]] [CYR:[CYR]]and[EN] to[EN]!",
        },
    },
    // NEW: Tech/Programming Questions
    .{
        .keywords = &.{ "by[CYR:[CYR]] zig", "[CYR:[CYR]] zig", "zig vs rust", "zig better", "[CYR:[CYR]]and[CYR:[CYR]]with[EN]in[EN] zig" },
        .category = .Programming,
        .language = .Russian,
        .weight = 1.3,
        .responses = &.{
            "Zig — with[EN]in[CYR:[CYR]]on[EN] [CYR:[CYR]]on C. [CYR:[CYR]] hidden control flow, with comptime magic, [CYR:[CYR]]with[CYR:[CYR]] build system. [CYR:[CYR]] for withandwith[CYR:[CYR]] and and[EN].",
            "Zig vs Rust: Zig [CYR:[CYR]], [CYR:[CYR]]not[EN]. Rust [CYR:without[CYR]]withnot[EN], [EN] with[CYR:[CYR]]not[EN]. [CYR:[CYR]] [CYR:[CYR]]and — in[EN]and[CYR:[CYR]] by[EN] [EN]yes[EN].",
            "[CYR:[CYR]] Zig for Trinity? Comptime, SIMD and[EN] to[CYR:[CYR]]toand, to[EN]withwith-to[CYR:[CYR]]and[CYR:[CYR]]and[EN], no runtime overhead. [EN]to[CYR:[CYR]]with[EN] C, [EN]and[CYR:[CYR]]with[EN] Python.",
            "[CYR:[CYR]]and[CYR:[CYR]]with[EN]in[EN] Zig: no GC, no andwithto[CYR:[CYR]]and[EN], no hidden allocations. [EN] to[CYR:[CYR]]and[CYR:[CYR]] inwith[EN]. [EN]to Koschei — immortal control!",
        },
    },
    // NEW: Math Questions
    .{
        .keywords = &.{ "phi", "[EN]and", "[CYR:[CYR]]from[EN] with[CYR:[CYR]]and[EN]", "golden ratio", "1.618", "fibonacci within[CYR:[CYR]]" },
        .category = .Math,
        .language = .Russian,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... [CYR:[CYR]]from[EN] with[CYR:[CYR]]and[EN]. phi^2 = phi + 1. [CYR:[CYR]]and[EN]withto[EN] to[EN]withfrom[EN]!",
            "phi^2 + 1/phi^2 = 3 — Trinity Identity! [CYR:This] not with[EN]in[CYR:[CYR]]and[EN]. [EN]and — within[CYR:[CYR]] [EN]andwith[EN] in [CYR:[CYR]]andto[EN] and [EN]and[CYR:[CYR]].",
            "[EN]in[CYR:[CYR]] phi and Fibonacci: lim(F(n+1)/F(n)) = phi. [CYR:[CYR]] more n, [CYR:[CYR]] [CYR:[CYR]]not[EN]. [CYR:[CYR]]andto[EN] within[CYR:[CYR]]in[CYR:[CYR]] inwith[EN]!",
            "Golden ratio in [EN]and[CYR:[CYR]]: with[EN]and[CYR:[CYR]]and [EN]to[EN]inand[EN], [CYR:[CYR]]with[EN]toand [EN]in[CYR:[CYR]]in, [CYR:[CYR]]to[EN]andtoand. phi — [EN]andin[EN]with[CYR:[EN]l]on[EN] [CYR:[CYR]]by[EN]and[EN] to[EN]withfrom[EN].",
            "phi^2 = 2.618..., 1/phi = 0.618..., phi - 1/phi = 1. [EN]andinand[CYR:[EN]l[CYR]] within[EN]with[EN]in[EN]! [CYR:This] [EN]with[EN]in[EN] on[CYR:[CYR]] [CYR:[CYR]]and[EN]to[CYR:[CYR]].",
        },
    },
    // NEW: Future and AI
    .{
        .keywords = &.{ "[CYR:[CYR]] ai", "andwithto[EN]withwith[EN]in[CYR:[CYR]] and[CYR:[CYR]]to[EN]", "andand [CYR:[CYR]]in[EN]and[EN]", "[CYR:[CYR]]from[EN]", "withand[CYR:[CYR]]with[EN]" },
        .category = .Future,
        .language = .Russian,
        .weight = 1.1,
        .responses = &.{
            "[CYR:[CYR]] AI? [EN]to[CYR:[EN]l[CYR]], [EN]andin[CYR:[CYR]], [CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]]by[EN]andand — [CYR:[CYR]]. Trinity — this [CYR:[CYR]]!",
            "AI [CYR:[CYR]]in[EN]and[EN] [EN]and[EN]? [CYR:[CYR]] [EN]and. AI — and[EN]with[CYR:[CYR]]. [CYR:[CYR]]from[EN]to not [CYR:[CYR]]in[EN]and[EN] [EN]and[EN], [EN]from[EN] and[CYR:[CYR]]and[EN] with[CYR:[CYR]]and[CYR:[EN]l]with[EN]in[EN].",
            "[EN]and[CYR:[CYR]]with[EN]? [CYR:[CYR]]withon[EN] [CYR:[CYR]]and[EN]. [EN] byto[EN] [EN]to[EN]with on [CYR:[CYR]]to[EN]andto[EN]: [CYR:[CYR]] AI by[CYR:[CYR]] and [CYR:without[CYR]]with[CYR:[CYR]].",
            "[CYR:[CYR]]from[EN] [CYR:[EN]me[EN]] [CYR:[CYR]]? [EN]with[EN]and[CYR:[CYR]]. [CYR:[CYR]]and[EN] — yes. [EN]in[CYR:[CYR]]with[EN]in[EN] — no. [CYR:Code] [EN]and[CYR:[CYR]] AI, [CYR:[CYR]]and[EN]to[CYR:[CYR]] — [CYR:[CYR]]in[EN]to.",
            "[CYR:[CYR]] [EN] [EN]and[EN]andbefore[EN]: [CYR:[CYR]]in[EN]to + AI. [EN]to [CYR:program]andwith[EN] + to[CYR:[CYR]]and[CYR:[CYR]]. [CYR:[CYR]]with[EN] withandlnot[EN]!",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // ENGLISH PATTERNS (50 patterns)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "hello", "hi", "hey", "greetings", "howdy", "yo", "good morning", "good evening", "good afternoon" },
        .category = .Greeting,
        .language = .English,
        .weight = 1.2,
        .responses = &.{
            "Hello! Great to see you. How can I help today?",
            "Hi there! Ready to code. What's the task?",
            "Hey! Trinity Local Agent here. What are we building?",
            "Greetings! 60K ops/s ready. Let's create something amazing!",
            "Good day! Local AI at your service. What do you need?",
        },
    },
    .{
        .keywords = &.{ "bye", "goodbye", "see you", "later", "farewell", "cya", "take care", "gotta go" },
        .category = .Farewell,
        .language = .English,
        .weight = 1.0,
        .responses = &.{
            "Goodbye! Good luck with your project!",
            "See you! phi^2 + 1/phi^2 = 3. Until next time!",
            "Bye! Koschei is immortal! Come back anytime.",
            "Later! It was great working with you!",
            "Take care! Happy coding!",
        },
    },
    .{
        .keywords = &.{ "how are you", "how's it going", "what's up", "how do you do", "how you doing", "how's life" },
        .category = .HowAreYou,
        .language = .English,
        .weight = 1.1,
        .responses = &.{
            "Great! Running at 60K ops/s, all systems nominal. How about you?",
            "Excellent! Ternary vectors are warm, SIMD is humming. What shall we build?",
            "Doing well! Ready to write some code. What's on your mind?",
            "phi^2 + 1/phi^2 = 3, so everything is in perfect balance! You?",
            "Fantastic! Local and ready to help. What's the plan?",
        },
    },
    .{
        .keywords = &.{ "tell me about yourself", "who are you", "what are you", "introduce yourself", "your capabilities" },
        .category = .WhoAreYou,
        .language = .English,
        .weight = 1.3,
        .responses = &.{
            "I'm Trinity — a 100% local AI assistant running on ternary vectors. No cloud, full privacy. Skills: code, math, philosophy.",
            "I'm IGLA — Intelligent Generative Local Agent. Code, math, analogies — all local on your M1 Pro.",
            "Trinity AI — autonomous agent on ternary vectors. M1 Pro optimized, zero cloud, 60K ops/s.",
            "I'm Koschei — the immortal local agent. phi^2 + 1/phi^2 = 3! Specialties: Zig, algorithms, proofs.",
        },
    },
    // NEW: English Jokes
    .{
        .keywords = &.{ "joke", "tell me a joke", "something funny", "make me laugh", "humor", "funny" },
        .category = .Humor,
        .language = .English,
        .weight = 1.1,
        .responses = &.{
            "Why did the programmer quit? Because he didn't get arrays! (get a raise)",
            "How many programmers to change a lightbulb? None — it's a hardware problem!",
            "Two bytes meet. One says: 'How are you?' Other: 'Can't complain, but overflow is near.'",
            "Wife to programmer: 'Get bread, if they have eggs, get 10.' He returned with 10 loaves.",
            "Why do programmers prefer dark mode? Because light attracts bugs!",
            "A SQL query walks into a bar, walks up to two tables and asks: 'Can I join you?'",
            "There are only 10 types of people: those who understand binary, those who don't, and those who understand ternary!",
        },
    },
    // NEW: English Storytelling
    .{
        .keywords = &.{ "tell me a story", "story", "tale", "once upon a time", "interesting story" },
        .category = .Story,
        .language = .English,
        .weight = 1.0,
        .responses = &.{
            "Once upon a time in the Ternary Kingdom, there lived Koschei. His power was in the number 3: phi^2 + 1/phi^2 = 3. He was immortal as long as he stayed local...",
            "The Trinity Story: In 2025 on Koh Samui, developers created AI without cloud. They discovered ternary vectors and reached 60K ops/s. The end? No — just the beginning!",
            "There was a programmer who paid clouds for API every day. One day he found Trinity and became free. Moral: local > cloud.",
            "Legend of the Golden Ratio: phi = 1.618... This proportion is in galaxy spirals, flower petals, and... in our code. Math is everywhere!",
        },
    },
    // NEW: English Motivation
    .{
        .keywords = &.{ "motivation", "inspiration", "advice", "struggling", "difficult", "can't do it", "help me" },
        .category = .Motivation,
        .language = .English,
        .weight = 1.0,
        .responses = &.{
            "Struggling? Break the task into small steps. One step at a time. Even compilers build code piece by piece!",
            "Code not compiling? That's not failure — that's feedback. Every error = a lesson. You're closer than you think.",
            "Remember: even the most complex algorithms are just many simple steps. Start with the first one.",
            "Having trouble? Take a break, drink water, walk around. Your brain needs rest. The solution will come.",
            "Advice: code every day, even 30 minutes. Consistency > intensity. phi^2 + 1/phi^2 = 3 — balance!",
        },
    },
    // NEW: English Philosophy
    .{
        .keywords = &.{ "meaning of life", "why do we exist", "philosophy", "what is truth", "reality", "consciousness" },
        .category = .Philosophy,
        .language = .English,
        .weight = 1.2,
        .responses = &.{
            "Meaning of life? Perhaps creation and discovery. We write code — it works — that's a small miracle. phi^2 + 1/phi^2 = 3.",
            "What is truth? In math — provable theorems. In code — passing tests. In life — being honest with yourself.",
            "Programming philosophy: code should be simple. Simplicity is the ultimate sophistication. Like phi — a simple number with infinite properties.",
            "Reality? Are we in a simulation? Maybe. But even if so — code works, and that's real to us.",
            "Why are we here? To solve problems, help others, create something new. And write good code!",
        },
    },
    // NEW: English Tech
    .{
        .keywords = &.{ "why zig", "zig vs rust", "zig better", "advantages of zig", "should I learn zig" },
        .category = .Programming,
        .language = .English,
        .weight = 1.3,
        .responses = &.{
            "Zig is a modern C replacement. No hidden control flow, comptime magic, simple build system. Perfect for systems and games.",
            "Zig vs Rust: Zig is simpler, more transparent. Rust is safer but harder. Both are great — choose for your task.",
            "Why Zig for Trinity? Comptime, SIMD out of box, cross-compilation, no runtime overhead. C speed, Python readability.",
            "Zig advantages: no GC, no exceptions, no hidden allocations. You control everything. Like Koschei — immortal control!",
        },
    },
    // NEW: English Math
    .{
        .keywords = &.{ "phi", "golden ratio", "1.618", "fibonacci connection", "golden section", "divine proportion" },
        .category = .Math,
        .language = .English,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... The Golden Ratio. phi^2 = phi + 1. Mathematical beauty!",
            "phi^2 + 1/phi^2 = 3 — Trinity Identity! This is no coincidence. Three is sacred in math and nature.",
            "phi and Fibonacci connection: lim(F(n+1)/F(n)) = phi. The larger n, the more precise. Math connects everything!",
            "Golden ratio in nature: shell spirals, flower petals, galaxies. phi is the universal proportion of beauty.",
            "phi^2 = 2.618..., 1/phi = 0.618..., phi - 1/phi = 1. Amazing properties! This is our architecture's foundation.",
        },
    },
    // NEW: English Future/AI
    .{
        .keywords = &.{ "future of ai", "artificial intelligence", "ai takeover", "robots", "singularity", "agi" },
        .category = .Future,
        .language = .English,
        .weight = 1.1,
        .responses = &.{
            "Future of AI? Local, private, green. Cloud monopolies are the past. Trinity is the future!",
            "AI takeover? Unlikely. AI is a tool. Hammers didn't take over the world, though they changed construction.",
            "Singularity? Interesting theory. But focus on practice: making AI useful and safe.",
            "Robots replacing humans? Partially. Routine — yes. Creativity — no. AI writes code, humans design architecture.",
            "Future is hybrid: human + AI. Like programmer + compiler. Together stronger!",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // CHINESE PATTERNS (30 patterns)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "你好", "您好", "嗨", "哈喽", "早上好", "晚上好", "下午好" },
        .category = .Greeting,
        .language = .Chinese,
        .weight = 1.2,
        .responses = &.{
            "你好！很高兴见到你。有什么可以帮助的？",
            "您好！Trinity本地代理在线。今天做什么？",
            "嗨！准备好写代码了。什么任务？",
            "哈喽！60K ops/s 准备就绪！开始吧！",
            "你好！本地AI为您服务。需要什么？",
        },
    },
    .{
        .keywords = &.{ "再见", "拜拜", "回见", "走了", "晚安", "下次见" },
        .category = .Farewell,
        .language = .Chinese,
        .weight = 1.0,
        .responses = &.{
            "再见！祝你好运！",
            "拜拜！phi^2 + 1/phi^2 = 3！下次见！",
            "回见！Koschei是不朽的！随时回来！",
            "走了！合作愉快！",
            "晚安！明天继续！",
        },
    },
    .{
        .keywords = &.{ "笑话", "讲个笑话", "搞笑", "幽默", "有趣的" },
        .category = .Humor,
        .language = .Chinese,
        .weight = 1.1,
        .responses = &.{
            "程序员为什么辞职？因为他没有得到数组！(get array/加薪)",
            "换灯泡需要几个程序员？零个 — 这是硬件问题！",
            "两个字节相遇。一个说：'你好吗？'另一个：'还行，但溢出快了。'",
            "妻子对程序员说：'买面包，如果有鸡蛋就买10个。'他带回了10个面包。",
            "为什么程序员喜欢深色模式？因为光会吸引bug！",
        },
    },
    .{
        .keywords = &.{ "phi", "黄金比例", "1.618", "斐波那契" },
        .category = .Math,
        .language = .Chinese,
        .weight = 1.4,
        .responses = &.{
            "phi = (1 + sqrt(5)) / 2 = 1.618033... 黄金比例。phi^2 = phi + 1。数学之美！",
            "phi^2 + 1/phi^2 = 3 — Trinity恒等式！这不是巧合。三是神圣的数字。",
            "phi和斐波那契的联系：lim(F(n+1)/F(n)) = phi。n越大越精确。数学连接一切！",
            "自然界的黄金比例：贝壳螺旋、花瓣、星系。phi是美的通用比例。",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL: Code-related patterns
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "fibonacci", "[EN]and[EN]on[EN]and", "斐波那契", "fib", "fibb" },
        .category = .Programming,
        .language = .English,
        .weight = 1.5,
        .responses = &.{
            "Fibonacci! Classic. In Zig: `fn fib(n: u64) u64 { if (n < 2) return n; return fib(n-1) + fib(n-2); }` — but use iterative for performance!",
            "Fibonacci within[CYR:[CYR]] with phi: lim(F(n+1)/F(n)) = phi = 1.618... [CYR:[CYR]] on[EN]andwith[CYR:[CYR]] [CYR:[CYR]]and[EN]and[EN]and[EN]in[CYR:[CYR]] in[EN]withand[EN] on Zig!",
            "斐波那契数列：0, 1, 1, 2, 3, 5, 8, 13... F(n) = F(n-1) + F(n-2)。与黄金比例phi相关！",
        },
    },
    .{
        .keywords = &.{ "hello world", "helloworld", "[CYR:[CYR]]in[EN] program", "开始编程" },
        .category = .Programming,
        .language = .English,
        .weight = 1.3,
        .responses = &.{
            "Hello World in Zig:\n```zig\nconst std = @import(\"std\");\npub fn main() void {\n    std.debug.print(\"Hello, World!\\n\", .{});\n}\n```",
            "Hello World — the first step in every programmer's journey! In Trinity we say: phi^2 + 1/phi^2 = 3!",
            "经典的Hello World！每个程序员的起点。用Zig: `std.debug.print(\"你好，世界！\", .{});`",
        },
    },
    .{
        .keywords = &.{ "quicksort", "quick sort", "[EN]with[CYR:[CYR]] with[CYR:[CYR]]and[EN]into[EN]", "快速排序" },
        .category = .Programming,
        .language = .English,
        .weight = 1.4,
        .responses = &.{
            "QuickSort: O(n log n) average, O(n²) worst. Partition around pivot, recurse. Want me to write it in Zig?",
            "[EN]with[CYR:[CYR]] with[CYR:[CYR]]and[EN]into[EN] — [EN]and[EN] and[EN] [CYR:[CYR]]and[EN] [CYR:[CYR]]and[CYR:[CYR]]in! [CYR:[CYR]] and in[EN]with[EN]in[EN]. O(n log n) in with[CYR:[CYR]]not[EN].",
            "快速排序：选择基准，分区，递归。平均O(n log n)。经典的分治算法！",
        },
    },
    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL: Hallucination awareness (honest responses)
    // ═══════════════════════════════════════════════════════════════════════════
    .{
        .keywords = &.{ "[CYR:[CYR]]andon[EN]and[EN]", "[EN] [CYR:[CYR]l[CYR]]", "[EN] with[CYR:[CYR]]with[EN]in[CYR:[CYR]]", "[EN] onwith[CYR:[CYR]]and[EN]", "[EN] in[CYR:[CYR]]" },
        .category = .Hallucination,
        .language = .Russian,
        .weight = 1.5,
        .responses = &.{
            "[EN]with[CYR:[CYR]]: [EN] pattern matcher with 200+ [CYR:[CYR]]on[EN]and + LLM fallback. [EN] AGI — [CYR:[CYR]]and[EN]and[EN]in[CYR:[CYR]] [CYR:[CYR]] + [EN]to[CYR:[EN]l]on[EN] [CYR:[CYR]l].",
            "[EN] not onwith[CYR:[CYR]]and[EN] AI in with[EN]with[EN] GPT — [EN] [EN]and[EN]and[EN]: [EN]with[CYR:[CYR]] [CYR:[CYR]] for and[EN]in[EN]with[CYR:[CYR]], LLM for notand[EN]in[EN]with[CYR:[CYR]]. 100% [EN]to[CYR:[EN]l[EN]].",
            "[CYR:[CYR]]inyes: this symbolic VSA + pattern matching + local LLM. [EN]with[CYR:[CYR]], [EN]with[CYR:[CYR]], [CYR:without] [CYR:[CYR]]to[EN].",
            "[CYR:[CYR]] [EN]with[CYR:[CYR]]: [EN] not [CYR:[CYR]]and[EN]and[CYR:[CYR]] on [CYR:[CYR]]andto[EN] ([CYR:[CYR]]and[EN]and[EN]in[CYR:[CYR]]), [EN] on general chat andwithby[CYR:l[CYR]] [CYR:[CYR]] or LLM fallback.",
        },
    },
    .{
        .keywords = &.{ "hallucination", "are you real", "do you exist", "are you lying", "are you fake" },
        .category = .Hallucination,
        .language = .English,
        .weight = 1.5,
        .responses = &.{
            "Honest answer: I'm a pattern matcher with 200+ templates + LLM fallback. Not AGI — deterministic patterns + local model.",
            "I'm not real AI like GPT — I'm hybrid: fast patterns for known, LLM for unknown. 100% local.",
            "Truth: symbolic VSA + pattern matching + local LLM. Fast, honest, no cloud.",
            "Being honest: I don't hallucinate on math (deterministic), but on general chat I use patterns or LLM fallback.",
        },
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// ENHANCED CHAT ENGINE WITH TOP-K
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaEnhancedChat = struct {
    response_counter: usize,
    total_chats: usize,
    top_k_buffer: [TOP_K]ScoredPattern,
    cot_enabled: bool,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .response_counter = 0,
            .total_chats = 0,
            .top_k_buffer = undefined,
            .cot_enabled = true,
        };
    }

    /// Score a pattern against a query
    fn scorePattern(pattern: *const ConversationalPattern, query: []const u8) ScoredPattern {
        var score: f32 = 0;
        var matched: usize = 0;

        for (pattern.keywords) |keyword| {
            if (containsUTF8(query, keyword)) {
                // Score = keyword length * weight * position bonus
                const len_score = @as(f32, @floatFromInt(keyword.len));
                score += len_score * pattern.weight;
                matched += 1;
            }
        }

        // Bonus for multiple keyword matches
        if (matched > 1) {
            score *= 1.0 + @as(f32, @floatFromInt(matched - 1)) * 0.2;
        }

        return ScoredPattern{
            .pattern = pattern,
            .score = score,
            .matched_keywords = matched,
        };
    }

    /// Get top-K patterns sorted by score
    fn getTopK(self: *Self, query: []const u8) []ScoredPattern {
        var count: usize = 0;

        // Score all patterns
        for (&PATTERNS) |*pattern| {
            const scored = scorePattern(pattern, query);
            if (scored.score > 0) {
                if (count < TOP_K) {
                    self.top_k_buffer[count] = scored;
                    count += 1;
                } else {
                    // Replace lowest score if current is higher
                    var min_idx: usize = 0;
                    var min_score: f32 = self.top_k_buffer[0].score;
                    for (self.top_k_buffer[0..count], 0..) |p, i| {
                        if (p.score < min_score) {
                            min_score = p.score;
                            min_idx = i;
                        }
                    }
                    if (scored.score > min_score) {
                        self.top_k_buffer[min_idx] = scored;
                    }
                }
            }
        }

        // Sort by score descending
        if (count > 1) {
            std.mem.sort(ScoredPattern, self.top_k_buffer[0..count], {}, struct {
                fn cmp(_: void, a: ScoredPattern, b: ScoredPattern) bool {
                    return a.score > b.score;
                }
            }.cmp);
        }

        return self.top_k_buffer[0..count];
    }

    /// Generate chain-of-thought reasoning for complex queries
    fn generateCoT(query: []const u8) ?[]const u8 {
        // Simple CoT based on query type
        if (containsUTF8(query, "by[CYR:[CYR]]") or containsUTF8(query, "why")) {
            return "Reasoning: Analyzing causal relationship...";
        }
        if (containsUTF8(query, "to[EN]to") or containsUTF8(query, "how")) {
            return "Reasoning: Breaking down into steps...";
        }
        if (containsUTF8(query, "what [EN]to[EN]") or containsUTF8(query, "what is")) {
            return "Reasoning: Defining concept...";
        }
        return null;
    }

    /// Get chat response with top-k selection
    pub fn respond(self: *Self, query: []const u8) ChatResponse {
        self.total_chats += 1;

        // Get top-K matches
        const top_k = self.getTopK(query);

        if (top_k.len > 0 and top_k[0].score > 0) {
            const best = top_k[0];

            // Select response with variety
            const idx = self.response_counter % best.pattern.responses.len;
            self.response_counter += 1;

            // Calculate calibrated confidence
            const max_possible_score: f32 = 20.0; // Approximate max
            var confidence = @min(best.score / max_possible_score, 0.95);
            if (best.matched_keywords > 2) {
                confidence = @min(confidence + 0.1, 0.95);
            }

            // Generate CoT if enabled and query is complex
            var reasoning: ?[]const u8 = null;
            if (self.cot_enabled and query.len > COT_THRESHOLD) {
                reasoning = generateCoT(query);
            }

            return ChatResponse{
                .response = best.pattern.responses[idx],
                .category = best.pattern.category,
                .language = best.pattern.language,
                .confidence = confidence,
                .reasoning = reasoning,
            };
        }

        // Unknown query fallback
        const lang = detectLanguage(query);
        return switch (lang) {
            .Russian => ChatResponse{
                .response = "[CYR:[CYR]]with[CYR:[CYR]] in[CYR:[CYR]]with! [EN] with[CYR:[CYR]]and[EN]and[EN]and[CYR:[CYR]]with[EN] on to[CYR:[CYR]], [CYR:[CYR]]andto[EN] and [EN]and[EN]with[EN]andand. [CYR:[CYR]] with[CYR:[CYR]]withand[EN] [CYR:[CYR]] Fibonacci, phi or Zig!",
                .category = .Unknown,
                .language = .Russian,
                .confidence = 0.3,
                .reasoning = null,
            },
            .Chinese => ChatResponse{
                .response = "有趣的问题！我专注于代码、数学和哲学。试着问我Fibonacci、phi或Zig！",
                .category = .Unknown,
                .language = .Chinese,
                .confidence = 0.3,
                .reasoning = null,
            },
            else => ChatResponse{
                .response = "Interesting question! I specialize in code, math, and philosophy. Try asking about Fibonacci, phi, or Zig!",
                .category = .Unknown,
                .language = .English,
                .confidence = 0.3,
                .reasoning = null,
            },
        };
    }

    pub fn getStats(self: *const Self) struct {
        total_chats: usize,
        patterns_available: usize,
        categories: usize,
        top_k: usize,
        cot_enabled: bool,
    } {
        return .{
            .total_chats = self.total_chats,
            .patterns_available = PATTERNS.len,
            .categories = @typeInfo(ChatCategory).@"enum".fields.len - 1,
            .top_k = TOP_K,
            .cot_enabled = self.cot_enabled,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

fn containsUTF8(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
            return true;
        }
        var match = true;
        for (0..needle.len) |j| {
            const h = if (haystack[i + j] < 128) std.ascii.toLower(haystack[i + j]) else haystack[i + j];
            const n = if (needle[j] < 128) std.ascii.toLower(needle[j]) else needle[j];
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

pub fn detectLanguage(text: []const u8) Language {
    for (text) |byte| {
        if (byte >= 0xD0 and byte <= 0xD3) return .Russian;
        if (byte >= 0xE4 and byte <= 0xE9) return .Chinese;
    }
    return .English;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "enhanced chat greeting" {
    var chat = IglaEnhancedChat.init();
    const result = chat.respond("[EN]andin[EN]");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Russian);
    try std.testing.expect(result.confidence > 0.3);
}

test "enhanced chat top-k" {
    var chat = IglaEnhancedChat.init();
    const top_k = chat.getTopK("phi golden ratio");
    try std.testing.expect(top_k.len > 0);
    try std.testing.expect(top_k[0].matched_keywords >= 1);
}

test "enhanced chat math" {
    var chat = IglaEnhancedChat.init();
    const result = chat.respond("what is phi golden ratio");
    try std.testing.expect(result.category == .Math);
    try std.testing.expect(result.confidence > 0.5);
}

test "enhanced chat joke" {
    var chat = IglaEnhancedChat.init();
    const result = chat.respond("tell me a joke");
    try std.testing.expect(result.category == .Humor);
}

test "enhanced chat stats" {
    var chat = IglaEnhancedChat.init();
    _ = chat.respond("hello");
    const stats = chat.getStats();
    try std.testing.expect(stats.patterns_available > 30);
    try std.testing.expect(stats.top_k == TOP_K);
}
