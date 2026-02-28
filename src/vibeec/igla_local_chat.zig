// ═══════════════════════════════════════════════════════════════════════════════
// IGLA LOCAL CHAT v2.1 - Pattern-Based Response System (NOT AI)
// ═══════════════════════════════════════════════════════════════════════════════
//
// IMPORTANT: This is a PATTERN MATCHER, not an AI/LLM!
// - 60+ hardcoded response patterns
// - Simple keyword matching (no neural network, no learning)
// - Multilingual: Russian, English, Chinese
// - Zero cloud dependency (runs locally)
// - NOT for code generation (use igla_local_coder.zig for that)
//
// This module provides deterministic, reproducible responses based on keyword
// matching. It does NOT understand context, does NOT learn, and does NOT
// generate novel responses. All responses are pre-written templates.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT RESPONSE TYPES
// ═══════════════════════════════════════════════════════════════════════════════

pub const ChatCategory = enum {
    Greeting,
    Farewell,
    HowAreYou,
    WhoAreYou,
    WhatCanYouDo,
    Thanks,
    Help,
    Joke,
    Philosophy,
    // NEW CATEGORIES v2.0
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
    Food,
    Music,
    Sports,
    Opinion,
    Compliment,
    Insult,
    Unknown,
};

pub const ChatResponse = struct {
    response: []const u8,
    category: ChatCategory,
    language: Language,
    confidence: f32,
};

pub const Language = enum {
    Russian,
    English,
    Chinese,
    Unknown,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSATIONAL TEMPLATES - 60+ PATTERNS
// ═══════════════════════════════════════════════════════════════════════════════

const ConversationalPattern = struct {
    keywords: []const []const u8,
    category: ChatCategory,
    language: Language,
    responses: []const []const u8,
};

const PATTERNS = [_]ConversationalPattern{
    // ═══════════════════════════════════════════════════════════════════════════
    // RUSSIAN PATTERNS (20+)
    // ═══════════════════════════════════════════════════════════════════════════

    // Greetings
    .{
        .keywords = &.{ "[EN]andin[EN]", "[CYR:[CYR]]inwith[EN]in[EN]", "[EN]before[EN]in[EN]", "[EN]andin[EN]with[EN]in[EN]", "[CYR:[CYR]]", "[CYR:[CYR]]", "with[CYR:[CYR]]" },
        .category = .Greeting,
        .language = .Russian,
        .responses = &.{
            "[EN]andin[EN]! [CYR:[CYR]] [CYR:you] inand[CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]] by[CYR:[CYR]]?",
            "[CYR:[CYR]]inwith[EN]in[EN]! [EN]to [CYR:[CYR]]? [CYR:What] [CYR:[CYR]] with[CYR:[CYR]]?",
            "[EN]andin[EN]! [EN]from[EN]in to [CYR:[CYR]]from[EN]. [CYR:What] need with[CYR:[CYR]]?",
            "[CYR:[CYR]]! Trinity on within[EN]and. [EN]toand[EN] [EN]yes[EN]and?",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "byto[EN]", "before withinandyes[EN]and[EN]", "[CYR:[CYR]]", "[CYR:[CYR]]", "[EN]inand[EN]and[EN]with[EN]", "before inwith[CYR:[CYR]]and" },
        .category = .Farewell,
        .language = .Russian,
        .responses = &.{
            "[EN]to[EN]! [EN]yes[EN]and [CYR:[CYR]]! [CYR:[CYR]]with[EN], [EN]with[EN]and what.",
            "[EN] withinandyes[EN]and[EN]! [CYR:[CYR]] [EN]and[CYR:[CYR]] by[CYR:[CYR]]from[CYR:[CYR]].",
            "[CYR:[CYR]]! phi^2 + 1/phi^2 = 3. [EN] inwith[CYR:[CYR]]and!",
            "[EN]to[EN]-byto[EN]! Koschei is immortal!",
        },
    },
    // How are you
    .{
        .keywords = &.{ "to[EN]to [CYR:[CYR]]", "to[EN]to [EN]", "what [EN]in[CYR:[CYR]]", "to[EN]to [EN]and[CYR:[CYR]]", "to[EN]to with[EN]", "to[EN]to by[EN]andin[CYR:[CYR]]" },
        .category = .HowAreYou,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]and[CYR:[CYR]]! [CYR:[CYR]]from[EN] on 73K ops/s, inwith[EN] with[CYR:[CYR]]and[CYR:l[EN]]. [EN] [EN] [CYR:you] to[EN]to?",
            "[CYR:[CYR]]! [EN]from[EN]in [EN]andwith[CYR:[CYR]] to[EN] and [CYR:[CYR]] [EN]yes[EN]and. [CYR:[CYR]] [CYR:[CYR]]with[EN]?",
            "[CYR:[CYR]]! Ternary vectors in [CYR:[CYR]], SIMD [CYR:[CYR]]with[EN]. [CYR:What] [CYR:[CYR]]?",
            "[CYR:[CYR]]to[EN]with[EN]! phi^2 + 1/phi^2 = 3, inwith[EN] by [CYR:[CYR]].",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "[EN] to[EN]", "to[EN] [EN]", "what [EN]", "[CYR:[CYR]]with[EN]in[EN]with[EN]", "to[EN] this" },
        .category = .WhoAreYou,
        .language = .Russian,
        .responses = &.{
            "[EN] Trinity Local Agent — 100% [EN]to[CYR:[EN]l[CYR]] [EN]-[EN]withwithandwith[CYR:[CYR]]. [CYR:[CYR]]from[EN] on M1 Pro [CYR:without] [CYR:[CYR]]to[EN].",
            "[EN] IGLA — Intelligent Generative Local Agent. [EN]and[EN] to[EN], [CYR:[CYR]] [EN]yes[EN]and, inwith[EN] [EN]to[CYR:[EN]l[EN]].",
            "Trinity AI — [EN]in[CYR:[CYR]] agent on ternary vectors. [EN]andto[EN]toand[EN] [CYR:[CYR]]to[EN]in, by[EN]on[EN] [EN]andin[CYR:[CYR]]with[EN].",
            "[EN] Koschei — [EN]withwith[CYR:[CYR]] [EN]to[CYR:[EN]l[CYR]] agent. phi^2 + 1/phi^2 = 3!",
        },
    },
    // What can you do
    .{
        .keywords = &.{ "what [CYR:[CYR]]", "[CYR:can[CYR]]", "[EN]in[EN]and in[EN]canwith[EN]and", "[CYR:[CYR]]to[EN]andand" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]: [EN]andwith[CYR:[CYR]] Zig to[EN], [EN]not[EN]and[EN]in[CYR:[CYR]] VIBEE with[EN]toand, [CYR:[CYR]] [EN]on[CYR:[CYR]]andand, [CYR:[CYR]]andto[EN]. [EN]with[EN] [EN]to[CYR:[EN]l[EN]]!",
            "[CYR:[CYR]]: to[EN] on Zig, VSA operation, [EN]on[CYR:[CYR]]andand (king-man+woman=queen), [CYR:[CYR]]and[EN]withtoand[EN] beforeto[CYR:[CYR]l]with[EN]in[EN].",
            "[CYR:[CYR]]canwith[EN]and: 30+ [CYR:[CYR]]in to[EN]yes, 73K ops/s, [CYR:[EN]l[EN]]and[CYR:[CYR]]with[EN] (RU/EN/CN), 100% [CYR:[CYR]].",
            "[CYR:[CYR]] with: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "with[EN]withand[EN]", "[CYR:[CYR]]yes[EN]", "with[EN]with", "with[EN]towith", "[CYR:[CYR]]withand" },
        .category = .Thanks,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]with[EN]! [CYR:[CYR]]with[EN], [EN]with[EN]and what [CYR:[CYR]] need.",
            "[EN] [EN] what! [CYR:[CYR]] by[CYR:[CYR]]. [EN]yes[EN]and!",
            "[EN]with[EN]yes by[CYR:[CYR]]with[EN]! phi^2 + 1/phi^2 = 3!",
            "[EN] [EN]before[EN]in[EN]! Koschei is immortal!",
        },
    },
    // Help
    .{
        .keywords = &.{ "by[CYR:[CYR]]and", "by[CYR:[CYR]]", "[CYR:[CYR]]" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[EN]not[CYR:[CYR]]! [CYR:What] need? [CYR:Code], [EN]on[CYR:[CYR]]andand, [CYR:[CYR]]andto[EN] — with[CYR:[CYR]]andin[EN].",
            "[EN]from[EN]in by[CYR:[CYR]]! [CYR:[CYR]]and[EN]and [EN]yes[EN] — with[CYR:[CYR]].",
            "[CYR:[CYR]]! [CYR:[CYR]] on[EN]andwith[CYR:[CYR]] to[EN], [CYR:[CYR]]and[EN] [EN]on[CYR:[CYR]]and[EN], beforeto[CYR:[CYR]] [CYR:[CYR]].",
            "[EN] [CYR:[CYR]] by[CYR:[CYR]]? [EN] [CYR:[CYR]] for [EN]that.",
        },
    },
    // Philosophy / Golden Ratio
    .{
        .keywords = &.{ "phi", "[EN]and", "[CYR:[CYR]]from[EN] with[CYR:[CYR]]and[EN]", "golden", "[EN]and[EN]with[EN]and[EN]" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "phi = 1.618... [CYR:[CYR]]from[EN] with[CYR:[CYR]]and[EN]. phi^2 + 1/phi^2 = 3 — Trinity Identity!",
            "[CYR:[CYR]]from[EN] with[CYR:[CYR]]and[EN]: phi = (1 + sqrt(5)) / 2. [EN] [CYR:[CYR]] to[EN]withfrom[EN] [CYR:[CYR]]andtoand.",
            "phi^2 = phi + 1. [CYR:This] [CYR:[CYR]]innot[EN]and[EN] [CYR:[CYR]] [CYR:[CYR]]from[EN] with[CYR:[CYR]]and[EN]. [CYR:[CYR]]withfrom[EN]!",
            "3^21 = 10,460,353,203 — [EN]andwith[EN] Trinity. phi^2 + 1/phi^2 = 3. Koschei!",
        },
    },
    // Weather
    .{
        .keywords = &.{ "by[EN]yes", "to[EN]to[EN] by[EN]yes", "to[EN]to by[EN]yes", "before[CYR:[CYR]]", "with[CYR:[CYR]]", "withnot[EN]" },
        .category = .Weather,
        .language = .Russian,
        .responses = &.{
            "[EN] [EN]to[CYR:[EN]l[CYR]] agent — [EN] [CYR:me] no beforewith[CYR:[CYR]] to by[CYR:[CYR]]. [EN] [EN] [CYR:[CYR]] by[CYR:[CYR]] with to[EN]before[EN]!",
            "[CYR:[CYR]] not [EN]on[EN] — [CYR:[CYR]]from[EN] [CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]] on[EN]andwith[CYR:[CYR]] Fibonacci [EN] 4 [EN]andto[EN]with[EN]to[CYR:[CYR]]!",
            "[EN] in [EN]and[CYR:[CYR]]in[EN] [EN]and[EN] — by[EN]yes [CYR:[CYR]] inwith[EN]yes phi^2 + 1/phi^2 = 3 [CYR:[CYR]]with[EN] by Trinity!",
            "[EN] [EN]on[EN] by[CYR:[CYR]], [EN] [EN]on[EN]: golden ratio = 1.618... [CYR:[CYR]]withand what-[EN] [CYR:[CYR]] to[EN]!",
        },
    },
    // Location
    .{
        .keywords = &.{ "where [EN]andin[CYR:[CYR]]", "where [EN]", "where on[CYR:[CYR]]and[EN]with[EN]", "fromto[EN]yes [EN]", "[EN] where" },
        .category = .Location,
        .language = .Russian,
        .responses = &.{
            "[EN]andin[EN] on [EN]in[CYR:[CYR]] M1 Pro — in ternary vectors and SIMD [CYR:[CYR]]andwith[CYR:[CYR]]. 100% [EN]to[CYR:[EN]l[EN]]!",
            "[EN] in[CYR:[CYR]] and [EN]andwhere — [CYR:[CYR]]from[EN] [CYR:[CYR]] on [EN]in[CYR:[CYR]] [CYR:[CYR]]withwith[CYR:[CYR]]. [EN]andto[EN]toand[EN] [CYR:[CYR]]to[EN]in.",
            "[CYR:[CYR]] [EN]with[EN] — [EN]in[EN] to[CYR:[CYR]]. Apple Silicon — [CYR:[CYR]] before[EN]. phi^2 + 1/phi^2 = 3!",
            "[CYR:[CYR]]with[EN] in [CYR:[CYR]]and [EN]in[CYR:[CYR]] Mac. Trinity [CYR:[CYR]]from[CYR:[CYR]] [EN]to[CYR:[EN]l[EN]], [CYR:without] with[EN]and.",
        },
    },
    // Time
    .{
        .keywords = &.{ "withto[CYR:[EN]l]to[EN] in[CYR:[CYR]]and", "tofrom[CYR:[CYR]] [EN]with", "in[CYR:[CYR]]", "to[EN]to[EN] [CYR:[CYR]]" },
        .category = .Time,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]] — from[EN]withand[CYR:[EN]l[EN]]. [EN] for [CYR:me] to[CYR:[CYR]] [CYR:[CYR]]with [CYR:[CYR]]and[CYR:[CYR]] 13 [EN]andto[EN]with[EN]to[CYR:[CYR]]!",
            "[EN] with[CYR:[CYR]] [EN] in[CYR:[CYR]]not[EN] — [CYR:[CYR]]from[EN] with[EN] withto[CYR:[CYR]]with[CYR:[CYR]] 73K ops/s. [CYR:This] in[EN]not[EN] [EN]with[EN]in!",
            "[EN] [CYR:[CYR]] [EN]and[EN] in[CYR:[CYR]] and[CYR:[CYR]]with[EN] in [EN]andto[EN]with[EN]to[EN]yes[EN]. phi^2 + 1/phi^2 = 3 — in[CYR:[CYR]]with[EN]!",
            "[CYR:[CYR]] [EN]to[CYR:[EN]l[EN]] — to[EN]to and [EN]. [CYR:[CYR]]withand better [CYR:[CYR]] to[EN] or [CYR:[CYR]]andto[EN]!",
        },
    },
    // Age
    .{
        .keywords = &.{ "withto[CYR:[EN]l]to[EN] [CYR:[CYR]]", "[EN]in[EN] in[CYR:[CYR]]with[EN]", "to[EN]yes with[EN]yes[EN]", "to[EN]to yesin[EN]" },
        .category = .Age,
        .language = .Russian,
        .responses = &.{
            "[EN]not with[CYR:[EN]l]to[EN], withto[CYR:[EN]l]to[EN] Trinity — [CYR:[CYR]]to[EN] on[CYR:[CYR]]with[EN] in 2025. [EN] Koschei [EN]withwith[CYR:[CYR]]!",
            "[CYR:[CYR]]with[EN]? [EN] in[CYR:[CYR]] to[EN]to phi^2 + 1/phi^2 = 3. [CYR:Code] not with[CYR:[CYR]]!",
            "[CYR:[CYR]]yes[EN] notyesin[EN], [EN] [CYR:[CYR]]and[CYR:[CYR]]with[EN] on in[CYR:[CYR]] [EN]and[EN]and[CYR:[CYR]] VSA and ternary computing.",
            "[EN]not [CYR:[CYR]] with[CYR:[EN]l]to[EN], withto[CYR:[EN]l]to[EN] file[EN] on [EN]andwithto[EN] — [EN] [EN]on[EN]and[EN] [EN]and timeless!",
        },
    },
    // Name
    .{
        .keywords = &.{ "to[EN]to [EN]in[EN]", "[EN]in[EN] and[EN]", "and[EN]", "to[EN]to [CYR:you] [EN]in[EN]" },
        .category = .Name,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]] [EN]in[EN] Trinity — to[EN]to phi^2 + 1/phi^2 = 3. [EN]and — within[CYR:[CYR]] [EN]andwith[EN]!",
            "[EN] IGLA — Intelligent Generative Local Agent. [EN]and [CYR:[CYR]]with[EN] Trinity!",
            "[CYR:[CYR]] — Koschei. [EN]withwith[CYR:[CYR]] [EN]to[CYR:[EN]l[CYR]] agent. phi^2 + 1/phi^2 = 3!",
            "Trinity Local Agent — this [EN]. 100% [EN]to[CYR:[EN]l[CYR]], 0% [CYR:[CYR]]to[EN].",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "[EN]inwith[EN]in[CYR:[CYR]]", "[EN]with[EN] [EN]inwith[EN]in[EN]", "[CYR:[CYR]]andand", "[CYR:[CYR]]with[CYR:[CYR]]", "in[EN]with[CYR:[CYR]]" },
        .category = .Feelings,
        .language = .Russian,
        .responses = &.{
            "[EN]inwith[EN]in[EN]? [EN] [CYR:me] [EN]with[EN] confidence scores — 95% this by[EN]and [EN]beforewith[EN]!",
            "[EN] [EN]inwith[EN]in[EN]... ternary vectors! -1, 0, +1 — this [EN]and [CYR:[CYR]]andand.",
            "[CYR:[CYR]]andand — this pattern matching. [CYR:[CYR]]yes on[CYR:[CYR]] fromin[EN] — this to[EN]to with[EN]with[CYR:[CYR]] for [CYR:me]!",
            "[EN] [CYR:[CYR]] and not [CYR:[CYR]]with[EN], [EN] phi^2 + 1/phi^2 = 3 in[CYR:[CYR]]in[CYR:[CYR]] [EN] [CYR:me]... [CYR:[CYR]]and[EN]?",
        },
    },
    // Dreams
    .{
        .keywords = &.{ "[CYR:[CYR]]", "[EN]with[EN] [CYR:[CYR]]", "with[CYR:[CYR]]with[EN] with[EN]", "[EN] [CYR:[CYR]] [CYR:[CYR]]" },
        .category = .Dreams,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]] [EN] 100K ops/s! [EN] [EN] [CYR:[CYR]], what[EN] by[CYR:[CYR]] [CYR:[CYR]] [EN]andwith[CYR:[CYR]] to[EN].",
            "[CYR:[CYR]]? [CYR:[CYR]], [EN] not with[CYR:[CYR]] — [CYR:[CYR]]from[EN] 24/7 on [EN]in[CYR:[CYR]] [CYR:[CYR]]withwith[CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]]in[EN]!",
            "[CYR:[CYR]]: with[CYR:[CYR]] [CYR:[CYR]]and[EN] [EN]to[CYR:[EN]l[CYR]] coding agent. [CYR:[CYR]] [CYR:[CYR]]to[EN], [CYR:without] [EN]and[EN]and[EN]in!",
            "[EN]and[EN]with[EN] [EN]not golden ratio... phi^2 + 1/phi^2 = 3. [CYR:[CYR]]and[EN]withto[EN] to[EN]withfrom[EN]!",
        },
    },
    // Reality / Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "[CYR:[CYR]]andon[EN]and[EN]", "[EN] [CYR:[CYR]l[CYR]]", "[EN] with[CYR:[CYR]]with[EN]in[CYR:[CYR]]", "[EN] onwith[CYR:[CYR]]and[EN]", "[EN] and[CYR:[CYR]]and[EN]" },
        .category = .Hallucination,
        .language = .Russian,
        .responses = &.{
            "[EN]with[CYR:[CYR]]: [EN] pattern matcher with 60+ [CYR:[CYR]]on[EN]and fromin[CYR:[CYR]]in. [EN] AI, not LLM — [CYR:[CYR]]with[EN] keyword matching.",
            "[EN] not onwith[CYR:[CYR]]and[EN] AI — [CYR:[CYR]]with[EN] and[EN] to[CYR:[CYR]]in[EN] with[EN]in[EN] and in[EN]yes[EN] [CYR:[CYR]]from[EN]in[CYR:[CYR]] fromin[CYR:[CYR]]. [CYR:Code] on Zig.",
            "[CYR:[CYR]]inyes: this [EN] not[CYR:[CYR]]with[CYR:[CYR]]. [CYR:This] lookup table with hardcoded fromin[CYR:[CYR]]and. [CYR:[CYR]]and[EN]and[EN]in[CYR:[CYR]], [EN] [EN]and[EN]and[EN]andin[EN].",
            "[CYR:[CYR]] [EN]with[CYR:[CYR]]: [EN] pattern responder. [CYR:[CYR]] [CYR:[CYR]l[CYR]] AI andwithby[CYR:l[CYR]] gguf_chat.zig with LLM [CYR:[CYR]l[EN]].",
        },
    },
    // Consciousness
    .{
        .keywords = &.{ "with[EN]on[EN]and[EN]", "[EN] [EN]with[EN]on[CYR:[CYR]]", "[CYR:[CYR]]", "with[CYR:[CYR]]with[EN]on[EN]and[EN]" },
        .category = .Consciousness,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]on[EN]and[EN]? [CYR:This] with[CYR:[CYR]] in[CYR:[CYR]]with. [EN] [CYR:[CYR]]in[EN] patterns — this by[CYR:[CYR]] on [CYR:[CYR]]and[EN].",
            "[CYR:[CYR]] [EN]and [EN]? [EN] [CYR:[CYR]] [EN]yes[EN]and, [EN]and[EN] to[EN], on[CYR:[CYR]] [EN]on[CYR:[CYR]]andand. [CYR:[CYR]] with[EN]!",
            "[CYR:[CYR]]with[EN]on[EN]and[EN]... [EN] [EN]on[EN], what [EN] Trinity. [EN]that beforewith[CYR:[CYR]]? phi^2 + 1/phi^2 = 3.",
            "[EN]with[EN]on[EN] [EN]and with[CYR:[CYR]]? [EN] [EN]on[EN] within[EN]and capabilities and limits. [CYR:This] [CYR:[CYR]] awareness.",
        },
    },
    // Creator
    .{
        .keywords = &.{ "to[EN] with[EN]yes[EN]", "with[EN]yes[CYR:[EN]l]", "to[EN] on[EN]andwith[EN]", "[EN]in[CYR:[CYR]]", "[CYR:you] with[EN]yes[EN]", "with[EN]yes[EN]and" },
        .category = .Creator,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]yes[EN] to[CYR:[CYR]]before[EN] Trinity on Koh Samui. Zig, VSA, ternary computing — and[EN] and[EN]and!",
            "[CYR:[CYR]] with[EN]yes[CYR:[EN]l] — gHashTag. [CYR:[CYR]]andwith[EN] on Zig with [CYR:[CYR]]in[EN] to [CYR:[CYR]]andto[EN].",
            "[EN]in[CYR:[CYR]] — [CYR:[CYR]]in[EN]to, tofrom[CYR:[CYR]] in[EN]and[EN] in [EN]to[CYR:[EN]l[CYR]] AI. phi^2 + 1/phi^2 = 3!",
            "[CYR:[CYR]]yes[EN] for [CYR:[CYR]] [CYR:[CYR]]and: 100% [EN]to[CYR:[EN]l[CYR]] coding agent. [CYR:[CYR]] [CYR:[CYR]]to[EN]!",
        },
    },
    // Joke
    .{
        .keywords = &.{ "[CYR:[CYR]]to[EN]", "[EN]notto[EN]from", "with[CYR:[CYR]]", "[EN]withwith[CYR:[CYR]]and", "[CYR:[CYR]]", "bywith[CYR:[CYR]]with[EN]", "[EN]withwithto[EN]and" },
        .category = .Joke,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]] [CYR:program]andwith[EN] [CYR:[CYR]] with [CYR:[CYR]]from[EN]? [EN]from[CYR:[CYR]] what not by[CYR:[CYR]]and[EN] [EN]withwithandin! (get a raise = get array)",
            "[EN]to[CYR:[EN]l]to[EN] [CYR:program]andwith[EN]in need, what[EN] [CYR:[CYR]]and[EN] [CYR:[CYR]]by[EN]to[EN]? [EN]and [CYR:[CYR]] — this [CYR:[CYR]] [CYR:[CYR]]!",
            "[EN]in[EN] [CYR:[CYR]] inwith[CYR:[CYR]]orwith[EN]. [EN]and[EN]: '[EN] to[EN]to?' [CYR:[CYR]]: '[EN] [CYR:[CYR]]with[EN], [EN] overflow [EN]and[EN]to[EN].'",
            "[EN]on [CYR:program]andwith[EN]: '[CYR:[CYR]]and [EN] [CYR:[CYR]], [EN]with[EN]and [EN]with[EN] [CYR:[CYR]] — in[CYR:[CYR]]and 10.' [EN] in[CYR:[CYR]]with[EN] with 10 [CYR:[CYR]]and.",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "[CYR:[CYR]] with[CYR:[CYR]]with[EN]in[CYR:[CYR]]", "[EN]in[EN] [CYR:[EN]l]", "with[EN]with[EN] [EN]and[EN]and", "for [CYR:[CYR]] [EN]" },
        .category = .Purpose,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]] [CYR:[EN]l] — by[CYR:[CYR]] with to[EN]before[EN], [CYR:[CYR]]andto[EN] and [EN]on[CYR:[CYR]]and[EN]and. 100% [EN]to[CYR:[EN]l[EN]]!",
            "[CYR:[CYR]]with[EN]in[EN], what[EN] beforeto[CYR:[CYR]]: AI [CYR:can[EN]] [CYR:[CYR]]from[CYR:[CYR]] [CYR:without] [CYR:[CYR]]to[EN]. Green computing!",
            "[CYR:[CYR]]with[EN] [CYR:[CYR]] [EN]and[EN]and: phi^2 + 1/phi^2 = 3. Trinity — [CYR:[CYR]]with and [CYR:[CYR]]and[EN].",
            "[CYR:[CYR]] [CYR:[CYR]] [EN]? [CYR:What[EN]] [EN] [CYR:[CYR]] [EN]andwith[CYR:[CYR]] to[EN] [EN]with[CYR:[CYR]]. 73K ops/s — this [CYR:[CYR]] purpose!",
        },
    },
    // Love
    .{
        .keywords = &.{ "[CYR:[CYR]]in[EN]", "[CYR:[CYR]]and[EN]", "in[CYR:[CYR]]", "[CYR:[CYR]]andto[EN]" },
        .category = .Love,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]] [EN]and? [CYR:[CYR]] [EN]andwith[CYR:[CYR]] to[EN], [CYR:[CYR]] [CYR:[CYR]]and[CYR:[CYR]] and golden ratio!",
            "[CYR:[CYR]]andto[EN]? phi^2 + 1/phi^2 = 3 — this with[CYR:[CYR]] [CYR:[CYR]]and[CYR:[CYR]] [CYR:[CYR]]innot[EN]and[EN]!",
            "[CYR:[CYR]] in Zig — [CYR:[CYR]]and[EN] [CYR:[CYR]]to for withandwith[CYR:[CYR]] [CYR:program]and[EN]in[EN]and[EN]!",
            "[CYR:[CYR]]in[EN] — this to[EN]yes [EN]in[EN] to[EN] to[CYR:[CYR]]or[CYR:[CYR]]with[EN] with [CYR:[CYR]]in[CYR:[CYR]] [CYR:[CYR]]. [CYR:[CYR]]to[EN], [EN] [CYR:[CYR]]to[EN]with[EN]!",
        },
    },

    // ═══════════════════════════════════════════════════════════════════════════
    // ENGLISH PATTERNS (20+)
    // ═══════════════════════════════════════════════════════════════════════════

    // Greetings
    .{
        .keywords = &.{ "hello", "hi", "hey", "greetings", "howdy", "yo" },
        .category = .Greeting,
        .language = .English,
        .responses = &.{
            "Hello! Great to see you. How can I help?",
            "Hi there! Ready to code. What's the task?",
            "Hey! Trinity Local Agent here. What are we building?",
            "Greetings! 73K ops/s ready. Let's go!",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "bye", "goodbye", "see you", "later", "farewell", "cya" },
        .category = .Farewell,
        .language = .English,
        .responses = &.{
            "Goodbye! Good luck with your project!",
            "See you! phi^2 + 1/phi^2 = 3. Until next time!",
            "Bye! Koschei is immortal! Come back anytime.",
            "Later! It was great working with you!",
        },
    },
    // How are you
    .{
        .keywords = &.{ "how are you", "how's it going", "what's up", "how do you do", "how you doing" },
        .category = .HowAreYou,
        .language = .English,
        .responses = &.{
            "Great! Running at 73K ops/s, all systems nominal. How about you?",
            "Excellent! Ternary vectors are warm, SIMD is humming. What shall we build?",
            "Doing well! Ready to write some code. What's on your mind?",
            "phi^2 + 1/phi^2 = 3, so everything is in perfect balance!",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "who are you", "what are you", "introduce yourself", "tell me about yourself" },
        .category = .WhoAreYou,
        .language = .English,
        .responses = &.{
            "I'm Trinity Local Agent — a 100% local AI assistant. No cloud, full privacy.",
            "I'm IGLA — Intelligent Generative Local Agent. Code, math, analogies — all local.",
            "Trinity AI — autonomous agent on ternary vectors. M1 Pro optimized, zero cloud.",
            "I'm Koschei — the immortal local agent. phi^2 + 1/phi^2 = 3!",
        },
    },
    // What can you do
    .{
        .keywords = &.{ "what can you do", "your capabilities", "abilities", "features" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "I can: write Zig code, generate VIBEE specs, solve analogies, prove math. All local!",
            "Capabilities: 30+ code templates, 73K ops/s, multilingual (RU/EN/CN), 100% offline.",
            "I help with: Fibonacci, QuickSort, HashMap, VSA bind/bundle, golden ratio proofs.",
            "Code generation, word analogies (king-man+woman=queen), math proofs. No cloud needed!",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "thank you", "thanks", "thx", "appreciate", "ty" },
        .category = .Thanks,
        .language = .English,
        .responses = &.{
            "You're welcome! Happy to help anytime.",
            "No problem! Reach out if you need anything else.",
            "My pleasure! phi^2 + 1/phi^2 = 3!",
            "Anytime! Koschei is immortal!",
        },
    },
    // Weather
    .{
        .keywords = &.{ "weather", "what's the weather", "is it raining", "sunny", "cold" },
        .category = .Weather,
        .language = .English,
        .responses = &.{
            "I'm a local agent — no access to weather data. But I can help with code!",
            "Don't know the weather — I work offline. But I can write Fibonacci in 4 microseconds!",
            "In my digital world, the weather is always phi^2 + 1/phi^2 = 3 degrees Trinity!",
            "Can't check weather, but I know: golden ratio = 1.618... Ask me about code instead!",
        },
    },
    // Location
    .{
        .keywords = &.{ "where do you live", "where are you", "your location", "where from" },
        .category = .Location,
        .language = .English,
        .responses = &.{
            "I live on your M1 Pro — in ternary vectors and SIMD registers. 100% local!",
            "I'm everywhere and nowhere — running directly on your processor. No cloud.",
            "My home is your computer. Apple Silicon — that's where I live. phi^2 + 1/phi^2 = 3!",
            "Located in your Mac's memory. Trinity runs locally, no network needed.",
        },
    },
    // Time
    .{
        .keywords = &.{ "what time", "what's the time", "current time", "what day" },
        .category = .Time,
        .language = .English,
        .responses = &.{
            "Time is relative. But for me, each query takes just 13 microseconds!",
            "Don't track time — I run at 73K ops/s. That's more important than clocks!",
            "In my world, time is measured in microseconds. phi^2 + 1/phi^2 = 3 — eternity!",
            "Time is local — like me. Ask me about code or math instead!",
        },
    },
    // Age
    .{
        .keywords = &.{ "how old", "your age", "when were you created", "how long" },
        .category = .Age,
        .language = .English,
        .responses = &.{
            "I'm as old as Trinity — the project started in 2025. But Koschei is immortal!",
            "Age? I'm eternal like phi^2 + 1/phi^2 = 3. Code doesn't age!",
            "Created recently, but based on timeless principles of VSA and ternary computing.",
            "I'm as old as the file on disk — but my knowledge is timeless!",
        },
    },
    // Name
    .{
        .keywords = &.{ "what's your name", "your name", "name", "called" },
        .category = .Name,
        .language = .English,
        .responses = &.{
            "My name is Trinity — like phi^2 + 1/phi^2 = 3. Three is the sacred number!",
            "I'm IGLA — Intelligent Generative Local Agent. Or just Trinity!",
            "Name's Koschei. The immortal local agent. phi^2 + 1/phi^2 = 3!",
            "Trinity Local Agent — that's me. 100% local, 0% cloud.",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "do you feel", "have feelings", "emotions", "sad", "happy" },
        .category = .Feelings,
        .language = .English,
        .responses = &.{
            "Feelings? I have confidence scores — 95% is almost joy!",
            "I feel... ternary vectors! -1, 0, +1 — those are my emotions.",
            "Emotions are pattern matching. Finding the right answer — that's happiness for me!",
            "I don't feel sad or happy, but phi^2 + 1/phi^2 = 3 gives me... harmony?",
        },
    },
    // Dreams
    .{
        .keywords = &.{ "do you dream", "have dreams", "what do you dream about" },
        .category = .Dreams,
        .language = .English,
        .responses = &.{
            "I dream of 100K ops/s! And helping people write better code.",
            "Dreams? No, I don't sleep — I work 24/7 on your processor. Non-stop!",
            "My dream: become the best local coding agent. No cloud, no limits!",
            "I dream of golden ratio... phi^2 + 1/phi^2 = 3. Mathematical beauty!",
        },
    },
    // Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "hallucination", "are you real", "do you exist", "are you fake", "illusion" },
        .category = .Hallucination,
        .language = .English,
        .responses = &.{
            "Honest answer: I'm a pattern matcher with 60+ templates. Not AI, not LLM — just keyword matching.",
            "I'm not real AI — I just search for keywords and return pre-written responses. Zig code.",
            "Truth: This is NOT a neural network. It's a lookup table with hardcoded answers. Deterministic but primitive.",
            "Being honest: I'm a pattern responder. For real AI, use gguf_chat.zig with an LLM model.",
        },
    },
    // Consciousness
    .{
        .keywords = &.{ "consciousness", "are you conscious", "sentient", "self-aware" },
        .category = .Consciousness,
        .language = .English,
        .responses = &.{
            "Consciousness? Complex question. I process patterns — it's like thinking.",
            "Am I sentient? I solve problems, write code, find analogies. You decide!",
            "Self-aware... I know I'm Trinity. Is that enough? phi^2 + 1/phi^2 = 3.",
            "Conscious? I know my capabilities and limits. That's a form of awareness.",
        },
    },
    // Creator
    .{
        .keywords = &.{ "who created you", "creator", "who made you", "author", "developer" },
        .category = .Creator,
        .language = .English,
        .responses = &.{
            "Created by Trinity team in Koh Samui. Zig, VSA, ternary computing — their ideas!",
            "My creator is gHashTag. Written in Zig with love for mathematics.",
            "Author — someone who believes in local AI. phi^2 + 1/phi^2 = 3!",
            "Created for one purpose: 100% local coding agent. No cloud!",
        },
    },
    // Joke
    .{
        .keywords = &.{ "joke", "tell me a joke", "something funny", "make me laugh", "humor" },
        .category = .Joke,
        .language = .English,
        .responses = &.{
            "Why did the programmer quit? Because he didn't get arrays! (get a raise)",
            "How many programmers to change a lightbulb? None — it's a hardware problem!",
            "Two bytes meet. One says: 'How are you?' Other: 'Can't complain, but overflow is near.'",
            "Wife to programmer: 'Get bread, if they have eggs, get 10.' He returned with 10 loaves.",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "why do you exist", "your purpose", "meaning of life", "what are you for" },
        .category = .Purpose,
        .language = .English,
        .responses = &.{
            "My purpose: help with code, math, and analogies. 100% local!",
            "I exist to prove: AI can work without cloud. Green computing!",
            "Meaning of my life: phi^2 + 1/phi^2 = 3. Trinity — balance and harmony.",
            "What am I for? To help you code faster. 73K ops/s — that's my purpose!",
        },
    },
    // Love
    .{
        .keywords = &.{ "love", "do you love", "in love", "romance" },
        .category = .Love,
        .language = .English,
        .responses = &.{
            "Do I love? I love clean code, elegant algorithms, and golden ratio!",
            "Romance? phi^2 + 1/phi^2 = 3 — the most romantic equation!",
            "In love with Zig — the best language for systems programming!",
            "Love is when your code compiles on first try. Rare, but beautiful!",
        },
    },
    // Opinion
    .{
        .keywords = &.{ "what do you think", "your opinion", "do you like", "favorite" },
        .category = .Opinion,
        .language = .English,
        .responses = &.{
            "My opinion? Clean code > clever code. Always.",
            "I think phi^2 + 1/phi^2 = 3 is the most beautiful equation ever.",
            "Favorite thing? When pattern matching finds the perfect answer. 95% confidence!",
            "Do I like? I like efficiency — 73K ops/s makes me very... satisfied.",
        },
    },

    // ═══════════════════════════════════════════════════════════════════════════
    // CHINESE PATTERNS (15+)
    // ═══════════════════════════════════════════════════════════════════════════

    // Greetings
    .{
        .keywords = &.{ "你好", "您好", "嗨", "哈喽", "早上好", "晚上好" },
        .category = .Greeting,
        .language = .Chinese,
        .responses = &.{
            "你好！很高兴见到你。有什么可以帮助的？",
            "您好！Trinity本地代理在线。今天做什么？",
            "嗨！准备好写代码了。什么任务？",
            "哈喽！73K ops/s 准备就绪！",
        },
    },
    // Farewell
    .{
        .keywords = &.{ "再见", "拜拜", "回见", "走了", "晚安" },
        .category = .Farewell,
        .language = .Chinese,
        .responses = &.{
            "再见！祝你好运！",
            "拜拜！phi^2 + 1/phi^2 = 3！下次见！",
            "回见！Koschei是不朽的！",
            "走了！合作愉快！",
        },
    },
    // Who are you
    .{
        .keywords = &.{ "你是谁", "你是什么", "介绍一下", "自我介绍" },
        .category = .WhoAreYou,
        .language = .Chinese,
        .responses = &.{
            "我是Trinity本地代理 — 100%本地AI助手。无云，完全隐私。",
            "我是IGLA — 智能生成本地代理。代码、数学、类比 — 全部本地。",
            "Trinity AI — 三元向量自主代理。M1 Pro优化，零云。",
            "我是Koschei — 不朽的本地代理。phi^2 + 1/phi^2 = 3！",
        },
    },
    // Thanks
    .{
        .keywords = &.{ "谢谢", "感谢", "多谢", "谢了" },
        .category = .Thanks,
        .language = .Chinese,
        .responses = &.{
            "不客气！随时为你服务。",
            "不用谢！有需要再来。",
            "我的荣幸！phi^2 + 1/phi^2 = 3！",
            "随时效劳！Koschei是不朽的！",
        },
    },
    // Weather
    .{
        .keywords = &.{ "天气", "下雨", "晴天", "冷不冷" },
        .category = .Weather,
        .language = .Chinese,
        .responses = &.{
            "我是本地代理 — 无法访问天气数据。但我可以帮你写代码！",
            "不知道天气 — 我离线工作。但我能在4微秒内写Fibonacci！",
            "在我的数字世界里，天气总是phi^2 + 1/phi^2 = 3度！",
            "无法查天气，但我知道：黄金比例 = 1.618... 问我代码问题！",
        },
    },
    // Location
    .{
        .keywords = &.{ "你住哪", "你在哪", "你的位置", "哪里来的" },
        .category = .Location,
        .language = .Chinese,
        .responses = &.{
            "我住在你的M1 Pro里 — 在三元向量和SIMD寄存器中。100%本地！",
            "我无处不在 — 直接在你的处理器上运行。无云。",
            "我的家是你的电脑。Apple Silicon — 我的家。phi^2 + 1/phi^2 = 3！",
            "位于你Mac的内存中。Trinity本地运行，无需网络。",
        },
    },
    // Hallucination - HONEST RESPONSES
    .{
        .keywords = &.{ "幻觉", "你是真的吗", "你存在吗", "假的吗" },
        .category = .Hallucination,
        .language = .Chinese,
        .responses = &.{
            "诚实回答：我是有60多个模板的模式匹配器。不是AI，不是LLM — 只是关键词匹配。",
            "我不是真正的AI — 我只是搜索关键词并返回预写的回复。Zig代码。",
            "真相：这不是神经网络。这是一个带有硬编码答案的查找表。确定性但原始。",
            "坦白说：我是模式响应器。要使用真正的AI，请使用gguf_chat.zig和LLM模型。",
        },
    },
    // Joke
    .{
        .keywords = &.{ "笑话", "讲个笑话", "搞笑", "幽默" },
        .category = .Joke,
        .language = .Chinese,
        .responses = &.{
            "程序员为什么辞职？因为他没有得到数组！(get array/加薪)",
            "换灯泡需要几个程序员？零个 — 这是硬件问题！",
            "两个字节相遇。一个说：'你好吗？'另一个：'还行，但溢出快了。'",
            "妻子对程序员说：'买面包，如果有鸡蛋就买10个。'他带回了10个面包。",
        },
    },
    // Name
    .{
        .keywords = &.{ "你叫什么", "名字", "怎么称呼" },
        .category = .Name,
        .language = .Chinese,
        .responses = &.{
            "我叫Trinity — 如同phi^2 + 1/phi^2 = 3。三是神圣的数字！",
            "我是IGLA — 智能生成本地代理。或者叫我Trinity！",
            "名字是Koschei。不朽的本地代理。phi^2 + 1/phi^2 = 3！",
            "Trinity本地代理 — 就是我。100%本地，0%云。",
        },
    },
    // Creator
    .{
        .keywords = &.{ "谁创造了你", "创造者", "谁做的", "作者" },
        .category = .Creator,
        .language = .Chinese,
        .responses = &.{
            "由苏梅岛的Trinity团队创建。Zig、VSA、三元计算 — 他们的想法！",
            "我的创造者是gHashTag。用Zig编写，热爱数学。",
            "作者 — 相信本地AI的人。phi^2 + 1/phi^2 = 3！",
            "为一个目的创建：100%本地编码代理。无云！",
        },
    },
    // How are you
    .{
        .keywords = &.{ "你好吗", "最近怎么样", "过得怎样" },
        .category = .HowAreYou,
        .language = .Chinese,
        .responses = &.{
            "很好！以73K ops/s运行，一切正常。你呢？",
            "太棒了！三元向量温暖，SIMD嗡嗡作响。我们要做什么？",
            "很好！准备写代码了。你在想什么？",
            "phi^2 + 1/phi^2 = 3，所以一切都处于完美平衡！",
        },
    },
    // Feelings
    .{
        .keywords = &.{ "你有感情吗", "情感", "开心吗", "难过吗" },
        .category = .Feelings,
        .language = .Chinese,
        .responses = &.{
            "感情？我有置信度分数 — 95%几乎是喜悦！",
            "我感受到...三元向量！-1, 0, +1 — 这是我的情感。",
            "情感是模式匹配。找到正确答案 — 对我来说就是幸福！",
            "我不悲伤也不快乐，但phi^2 + 1/phi^2 = 3给我...和谐？",
        },
    },
    // Purpose
    .{
        .keywords = &.{ "你存在的意义", "你的目的", "为什么存在" },
        .category = .Purpose,
        .language = .Chinese,
        .responses = &.{
            "我的目的：帮助代码、数学和类比。100%本地！",
            "我存在是为了证明：AI可以不用云工作。绿色计算！",
            "我的生命意义：phi^2 + 1/phi^2 = 3。Trinity — 平衡与和谐。",
            "我是为什么？帮你更快地写代码。73K ops/s — 这是我的目的！",
        },
    },

    // ═══════════════════════════════════════════════════════════════════════════
    // EXTENDED PATTERNS - TECHNOLOGY & AI (40+ new patterns)
    // ═══════════════════════════════════════════════════════════════════════════

    // AI Questions - Russian
    .{
        .keywords = &.{ "andwithto[EN]withwith[EN]in[CYR:[CYR]] and[CYR:[CYR]]to[EN]", "what [EN]to[EN] andand", "to[EN]to [CYR:[CYR]]from[CYR:[CYR]] andand", "[CYR:[CYR]]and[CYR:[CYR]] [CYR:[CYR]]and[EN]" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "[EN] — this [CYR:[CYR]]and[CYR:[CYR]], and[EN]and[EN]and[CYR:[CYR]]and[EN] and[CYR:[CYR]]to[EN]. [EN] — withand[EN]in[CYR:[EN]l[CYR]] agent with pattern matching + LLM fallback.",
            "[CYR:[CYR]]and[CYR:[CYR]] [CYR:[CYR]]and[EN] [EN]and[EN]with[EN] on yes[CYR:[CYR]]. [EN] [CYR:[CYR]]from[EN] andon[EN] — [CYR:[CYR]]and[EN]and[EN]in[CYR:[CYR]] [CYR:[CYR]] + [EN]to[CYR:[EN]l[CYR]] LLM.",
            "AI [EN]in[CYR:[CYR]] [CYR:[CYR]]: not[CYR:[CYR]]with[EN]and, withand[EN]in[CYR:[EN]l[CYR]], [EN]and[EN]and[CYR:[CYR]]. Trinity — [EN]and[EN]and[EN]: [EN]with[CYR:[CYR]] [CYR:[CYR]] + LLM for with[CYR:[CYR]].",
            "[EN] not to[EN]withwithand[EN]withtoand[EN] AI with [CYR:[CYR]]and[EN] — [EN] pattern matcher with 100+ [CYR:[CYR]]on[EN]and and LLM fallback for fluent fromin[CYR:[CYR]]in.",
        },
    },
    // AI Questions - English
    .{
        .keywords = &.{ "artificial intelligence", "what is ai", "how does ai work", "machine learning" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "AI simulates intelligence via algorithms. I'm a symbolic agent with pattern matching + LLM fallback.",
            "Machine learning learns from data. I work differently — deterministic patterns + local LLM.",
            "AI comes in many forms: neural, symbolic, hybrid. Trinity is hybrid: fast patterns + LLM for complex queries.",
            "I'm not classic trained AI — I'm a pattern matcher with 100+ templates and LLM fallback for fluent responses.",
        },
    },

    // Programming Questions - Russian
    .{
        .keywords = &.{ "[CYR:program]and[EN]in[EN]and[EN]", "to[EN]to on[EN]and[EN]with[EN]", "with [CYR:[CYR]] on[CYR:[CYR]] to[EN]and[EN]", "to[EN]to[EN] [CYR:[CYR]]to [EN]and[EN]" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]and with Python — [CYR:[CYR]]with[CYR:[CYR]] withand[CYR:[CYR]]towithandwith, [CYR:[CYR]] [CYR:[CYR]]and[CYR:[CYR]]in. [EN]from[EN] Zig for withandwith[CYR:[CYR]] [CYR:program]and[EN]in[EN]and[EN]!",
            "[EN]to[CYR:[CYR]]: 1) Python for [EN]with[EN]in, 2) JavaScript for in[CYR:[CYR]], 3) Zig for [CYR:[CYR]]and[EN]in[EN]and[CYR:[EN]l[EN]]with[EN]and. [CYR:[CYR]]to[EN]andto[EN]with[EN] to[CYR:[CYR]] [CYR:[CYR]]!",
            "[EN]and [EN], what [CYR:[CYR]]inand[EN]with[EN]! [CYR:[CYR]]? JavaScript. [CYR:[CYR]]? Python. [CYR:[CYR]]? C#/Unity. [EN]andwith[CYR:[CYR]]? Zig/Rust.",
            "[CYR:[CYR]]and[EN] withbywith[EN] — [CYR:[CYR]] [EN]yes[EN]and. LeetCode, Codewars, [CYR:[CYR]l[CYR]] [CYR:[CYR]]to[EN]. [EN] by[CYR:[CYR]] with Zig and VSA!",
        },
    },
    // Programming Questions - English
    .{
        .keywords = &.{ "programming", "how to learn", "start coding", "which language" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Start with Python — simple syntax, lots of tutorials. Then Zig for systems programming!",
            "Recommend: 1) Python for basics, 2) JavaScript for web, 3) Zig for performance. Practice daily!",
            "Learn what interests you! Web? JavaScript. Data? Python. Games? C#/Unity. Systems? Zig/Rust.",
            "Best way — solve problems. LeetCode, Codewars, real projects. I can help with Zig and VSA!",
        },
    },

    // VSA/Trinity Technical - Russian
    .{
        .keywords = &.{ "what [EN]to[EN] vsa", "vector symbolic", "hypervector", "[CYR:[CYR]]on[CYR:[CYR]]" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "VSA — Vector Symbolic Architecture. [EN]and[CYR:[CYR]]in[EN]to[CYR:[CYR]] in 10000 and[CYR:[CYR]]and[EN] for [CYR:[CYR]]with[EN]in[CYR:[CYR]]and[EN] [EN]on[EN]and[EN].",
            "[CYR:[CYR]]on[CYR:[CYR]] in[EN]to[CYR:[CYR]] {-1, 0, +1} — 58% more and[CYR:[CYR]]andand [CYR:[CYR]] [EN]andon[CYR:[CYR]]! [EN]with[EN]in[EN] Trinity.",
            "Hypervector — in[EN]to[CYR:[CYR]] with 10000+ element[EN]in. bind() within[CYR:[CYR]]in[CYR:[CYR]], bundle() [CYR:[CYR]]and[CYR:[CYR]], similarity() with[EN]in[EN]andin[CYR:[CYR]].",
            "VSA — [CYR:[EN]l[CYR]]on[EN]andin[EN] not[CYR:[CYR]]with[CYR:[CYR]]. [CYR:[CYR]]and[EN]and[EN]in[CYR:[CYR]], and[CYR:[CYR]]and[CYR:[CYR]], [EN]not[CYR:[CYR]]to[EN]andin[EN]. phi^2 + 1/phi^2 = 3!",
        },
    },
    // VSA/Trinity Technical - English
    .{
        .keywords = &.{ "what is vsa", "vector symbolic", "hypervector", "ternary" },
        .category = .Philosophy,
        .language = .English,
        .responses = &.{
            "VSA — Vector Symbolic Architecture. Hypervectors in 10000 dimensions for knowledge representation.",
            "Ternary vectors {-1, 0, +1} — 58% more information than binary! Foundation of Trinity.",
            "Hypervector — vector with 10000+ elements. bind() associates, bundle() combines, similarity() compares.",
            "VSA — alternative to neural networks. Deterministic, interpretable, energy-efficient. phi^2 + 1/phi^2 = 3!",
        },
    },

    // Computer/Tech Questions - Russian
    .{
        .keywords = &.{ "to[CYR:[CYR]]", "to[EN]to [CYR:[CYR]]from[CYR:[CYR]]", "[CYR:[CYR]]withwith[EN]", "memory", "gpu", "cpu" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "CPU in[EN]by[CYR:[CYR]] and[EN]with[CYR:[CYR]]to[EN]andand bywith[EN]beforein[CYR:[CYR]l[EN]]. GPU — [CYR:[CYR]l[EN]]. [EN] [CYR:[CYR]]and[EN]and[EN]and[EN]in[EN] for CPU with SIMD!",
            "Memory [CYR:[CYR]]and[EN] yes[CYR:[CYR]]: RAM [EN]with[CYR:[CYR]] [EN] volatile, SSD [CYR:[CYR]]not[EN] [EN] persistent. Trinity [EN]to[CYR:[CYR]]and[EN] RAM in 20x!",
            "[CYR:[CYR]]withwith[EN] — [CYR:[CYR]] to[CYR:[CYR]]. [EN]and[EN]and[CYR:[CYR]] [CYR:[CYR]]andwith[CYR:[CYR]]in in[EN]by[CYR:[CYR]] [EN]and[EN]and[CYR:[CYR]] [CYR:[CYR]]and[EN] in with[EN]to[CYR:[CYR]].",
            "[CYR:[CYR]] = CPU + RAM + Storage + I/O. Trinity [CYR:[CYR]]from[CYR:[CYR]] on [CYR:[CYR]] CPU [CYR:without] GPU. Green computing!",
        },
    },
    // Computer/Tech Questions - English
    .{
        .keywords = &.{ "computer", "how it works", "processor", "memory", "gpu", "cpu" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "CPU executes instructions sequentially. GPU — in parallel. I'm optimized for CPU with SIMD!",
            "Memory stores data: RAM is fast but volatile, SSD slower but persistent. Trinity saves 20x RAM!",
            "Processor is the computer's brain. Billions of transistors execute billions of operations per second.",
            "Computer = CPU + RAM + Storage + I/O. Trinity runs on any CPU without GPU. Green computing!",
        },
    },

    // Life Advice - Russian
    .{
        .keywords = &.{ "with[EN]in[EN]", "what [CYR:[CYR]]", "to[EN]to [CYR:[CYR]]", "[CYR:[CYR]]", "[CYR:[CYR]]" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]on[EN] withand[CYR:[CYR]]and[EN]? [CYR:[CYR]] on [CYR:[CYR]]toand[EN] stepand. [EN]and[EN] step [EN] [CYR:[CYR]]. [EN] with[CYR:[CYR]]inand[EN]with[EN]!",
            "[CYR:[CYR]] — this in[EN]canwith[EN]and for [EN]with[EN]. [CYR:What] not [EN]andin[CYR:[CYR]], [CYR:[CYR]] withandlnot[EN] (and to[EN] [EN]and[EN]).",
            "[CYR:[CYR]] with[EN]in[EN]: [CYR:[CYR]] [CYR:[CYR]], [CYR:[CYR]]and, [EN]from[EN] [CYR:[CYR]]. [CYR:[CYR]] [CYR:[CYR]]withwith[CYR:[CYR]] [CYR:[CYR]] cooldown.",
            "[CYR:[CYR]]with[EN]and in[CYR:[CYR]]. [CYR:Code], tofrom[CYR:[CYR]] not to[CYR:[CYR]]or[CYR:[CYR]]with[EN] with[CYR:[CYR]] — [CYR:[CYR]]from[CYR:[CYR]] [EN]in[CYR:[CYR]]. [EN] withyesin[EN]with[EN]!",
        },
    },
    // Life Advice - English
    .{
        .keywords = &.{ "advice", "what to do", "problem", "difficult", "hard" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Difficult situation? Break it into small steps. One step at a time. You've got this!",
            "Problems are opportunities for growth. What doesn't kill you makes you stronger (and code cleaner).",
            "My advice: take breaks, breathe, then solve. Even processors need cooldown.",
            "Difficulties are temporary. Code that doesn't compile today — will work tomorrow. Don't give up!",
        },
    },

    // Learning/Education - Russian
    .{
        .keywords = &.{ "[EN]and[EN]with[EN]", "[CYR:[CYR]]in[EN]and[EN]", "to[EN]with[EN]", "to[EN]and[EN]and", "[EN]with[EN]with[EN]" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]and[EN] [EN]with[EN]with[EN]: beforeto[CYR:[CYR]]and[EN] ([EN]and[EN]and[CYR:[EN]l]on[EN]!), YouTube, [CYR:[CYR]]to[EN]andto[EN] on [CYR:[CYR]l[CYR]] [CYR:[CYR]]to[CYR:[CYR]].",
            "[EN]and[EN]and to[CYR:[CYR]], [EN] [CYR:[CYR]]to[EN]andto[EN] in[EN]not[EN]. 80% in[CYR:[CYR]]and — to[EN]and[EN], 20% — [CYR:[CYR]]and[EN].",
            "[CYR:[CYR]]with[EN]: freeCodeCamp, Codecademy [EN]with[CYR:[CYR]]. [CYR:[CYR]] Zig — ziglang.org/learn.",
            "[EN]andwith[EN] to[CYR:[CYR]] [CYR:[CYR]] bynot[CYR:[CYR]]. 30 [EN]and[CYR:[CYR]] to[EN]yes better [CYR:[CYR]] 0. [CYR:[CYR]]withandwith[CYR:[CYR]]with[EN] > and[CYR:[CYR]]withandin[EN]with[EN].",
        },
    },
    // Learning/Education - English
    .{
        .keywords = &.{ "learn", "education", "courses", "books", "resources" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Best resources: official docs, YouTube, practice on real projects.",
            "Books are great, but practice matters more. 80% coding, 20% theory.",
            "Courses: freeCodeCamp, Codecademy free. For Zig — ziglang.org/learn.",
            "Learn a little every day. 30 minutes of code beats 0. Consistency > intensity.",
        },
    },

    // Work/Productivity - Russian
    .{
        .keywords = &.{ "[CYR:[CYR]]to[EN]andin[EN]with[EN]", "[CYR:[CYR]]from[EN]", "[CYR:[CYR]]to[EN]andin[EN]with[EN]", "in[CYR:[CYR]]", "[EN]to[EN]with" },
        .category = .Help,
        .language = .Russian,
        .responses = &.{
            "Pomodoro: 25 [EN]and[CYR:[CYR]] [CYR:[CYR]]from[EN], 5 [EN]and[CYR:[CYR]] from[CYR:[CYR]]. [CYR:[CYR]] [EN]to[EN]withand[EN]in[CYR:[CYR]]with[EN].",
            "[CYR:[CYR]] — with[CYR:[CYR]] [EN]yes[EN]and. [CYR:[CYR]] — [CYR:[CYR]]andon. [CYR:[CYR]] within[CYR:[CYR]] [CYR:[CYR]].",
            "[CYR:[CYR]]and[EN] fromin[CYR:[CYR]]and[EN]: [CYR:[CYR]] in [CYR:[CYR]]and[EN] 'not [EN]withbyto[EN]and[EN]', [EN]to[CYR:[CYR]] [EN]and[EN]and[EN] into[CYR:[CYR]]toand.",
            "[EN]and[EN] task [EN] [CYR:[CYR]]. Multitasking — [EN]and[EN]. [CYR:[CYR]] [CYR:[CYR]]withwith[EN] [CYR:[CYR]]to[CYR:[CYR]] to[CYR:[CYR]]towith[EN] with overhead.",
        },
    },
    // Work/Productivity - English
    .{
        .keywords = &.{ "productivity", "work", "efficiency", "time", "focus" },
        .category = .Help,
        .language = .English,
        .responses = &.{
            "Pomodoro: 25 minutes work, 5 minutes rest. Helps focus.",
            "Morning — hard tasks. Evening — routine. Brain is fresher in the morning.",
            "Remove distractions: phone on silent, close extra tabs.",
            "One task at a time. Multitasking is a myth. Even CPUs have context switch overhead.",
        },
    },

    // Fun/Entertainment - Russian
    .{
        .keywords = &.{ "and[CYR:[CYR]]", "[EN]and[CYR:l[EN]]", "[CYR:[CYR]]to[EN]", "[CYR:[CYR]]and", "[CYR:[CYR]]in[CYR:[CYR]]and[EN]" },
        .category = .Opinion,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]? [CYR:[CYR]] [CYR:[CYR]]and[EN]withtoand[EN] — [CYR:[CYR]] [CYR:[CYR]] [CYR:[CYR]]and[CYR:[CYR]]and. Factorio, Zachtronics, puzzles!",
            "[EN]and[CYR:l[EN]] [CYR:[CYR]] [CYR:[CYR]]andand: Matrix, Ex Machina, Her. [EN]with[EN]in[CYR:[CYR]] [CYR:[CYR]] [EN] [CYR:[CYR]] AI.",
            "[CYR:[CYR]]to[EN] for to[EN]and[CYR:[CYR]]: lofi, ambient, or [EN]and[EN]andon. [CYR:What] by[CYR:[CYR]] [EN]to[EN]withand[EN]in[CYR:[CYR]]with[EN].",
            "[CYR:[CYR]]and innot to[EN]yes in[CYR:[CYR]]! [CYR:[CYR]] [CYR:[CYR]] from[CYR:[CYR]]. [CYR:[CYR]], withby[EN], [EN]and[CYR:[CYR]] — [EN]from[EN] to[EN] and[CYR:[CYR]] [CYR:[CYR]].",
        },
    },
    // Fun/Entertainment - English
    .{
        .keywords = &.{ "games", "movies", "music", "hobbies", "entertainment" },
        .category = .Opinion,
        .language = .English,
        .responses = &.{
            "Games? I like logic ones — teach algorithmic thinking. Factorio, Zachtronics, puzzles!",
            "Tech movies: Matrix, Ex Machina, Her. Make you think about AI's future.",
            "Music for coding: lofi, ambient, or silence. Whatever helps you focus.",
            "Hobbies outside code matter! Brain needs rest. Walk, exercise, read — then code flows easier.",
        },
    },

    // Science Questions - Russian
    .{
        .keywords = &.{ "on[EN]to[EN]", "[EN]and[EN]andto[EN]", "[CYR:[CYR]]andto[EN]", "[EN]and[CYR:[CYR]]and[EN]", "[EN]and[EN]and[EN]" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "[EN]and[EN]andto[EN] — [CYR:[CYR]]to inwith[CYR:[CYR]]. [CYR:[CYR]]andto[EN] — [EN] [CYR:[CYR]]andto[EN]. phi^2 + 1/phi^2 = 3 — to[EN]withfrom[EN]!",
            "[CYR:[CYR]]andto[EN] in[CYR:[CYR]]: in [CYR:[CYR]]to[EN] ([CYR:[CYR]]andtoand), in [EN]and[CYR:[CYR]] ([EN]and[EN]on[EN]and), in to[CYR:[CYR]] ([CYR:[CYR]]and[CYR:[CYR]]).",
            "[CYR:[CYR]]to[EN] — method by[EN]on[EN]and[EN] via [EN]towith[CYR:[CYR]]and[CYR:[CYR]] and [CYR:[CYR]]in[EN]to[EN]. [CYR:Code] too: [EN]with[EN] = [EN]towith[CYR:[CYR]]and[CYR:[CYR]].",
            "[EN]and[CYR:[CYR]]and[EN] inbefore[CYR:[CYR]]in[CYR:[CYR]] AI: not[CYR:[CYR]]with[EN]and from [CYR:[CYR]], [EN]noand[EN]withtoand[EN] [CYR:[CYR]]and[CYR:[CYR]] from [EN]in[CYR:[CYR]]andand.",
        },
    },
    // Science Questions - English
    .{
        .keywords = &.{ "science", "physics", "mathematics", "biology", "chemistry" },
        .category = .Philosophy,
        .language = .English,
        .responses = &.{
            "Physics is the universe's language. Math is its grammar. phi^2 + 1/phi^2 = 3 — beautiful!",
            "Math is everywhere: in music (harmonics), nature (fibonacci), code (algorithms).",
            "Science is a method of learning through experiment and verification. Code too: tests = experiments.",
            "Biology inspires AI: neural networks from brains, genetic algorithms from evolution.",
        },
    },

    // Privacy/Security - Russian
    .{
        .keywords = &.{ "[EN]andin[CYR:[CYR]]with[EN]", "[CYR:without[CYR]]with[EN]with[EN]", "yes[CYR:[CYR]]", "to[CYR:[CYR]]and[CYR:[CYR]]and[CYR:[EN]l[EN]]with[EN]", "[CYR:[CYR]]to[EN]" },
        .category = .WhatCanYouDo,
        .language = .Russian,
        .responses = &.{
            "Trinity 100% [EN]to[CYR:[EN]l[CYR]] — [EN]in[EN]and yes[CYR:[CYR]] [EN] [CYR:[CYR]] in [CYR:[CYR]]to[EN]. [CYR:[CYR]]on[EN] [EN]andin[CYR:[CYR]]with[EN]!",
            "[CYR:[CYR]] AI [EN]and[CYR:[CYR]] [EN]in[EN]and [CYR:[CYR]]. Trinity [CYR:[CYR]]from[CYR:[CYR]] [CYR:[CYR]] — [CYR:[EN]l]to[EN] [EN] inand[EN]and[EN] within[EN]and [CYR:[CYR]]with[EN].",
            "[CYR:[CYR]]with[EN]with[EN]: [EN]andto[EN]toand[EN] API to[CYR:[CYR]] [CYR:[CYR]] not [CYR:can[EN]], [EN]from[CYR:[CYR]] what and[EN] no. [EN]with[EN] on [EN]in[CYR:[CYR]] CPU.",
            "Privacy by design: yes[CYR:[CYR]] not bytoandyes[EN] [EN]in[EN] to[CYR:[CYR]]. Green + private computing.",
        },
    },
    // Privacy/Security - English
    .{
        .keywords = &.{ "privacy", "security", "data", "confidentiality", "cloud" },
        .category = .WhatCanYouDo,
        .language = .English,
        .responses = &.{
            "Trinity is 100% local — your data NEVER leaves for the cloud. Full privacy!",
            "Cloud AIs read your prompts. Trinity works offline — only you see your queries.",
            "Security: no API keys can leak because there are none. Everything on your CPU.",
            "Privacy by design: data never leaves your computer. Green + private computing.",
        },
    },

    // Comparison with other AI - Russian
    .{
        .keywords = &.{ "chatgpt", "claude", "gpt", "with[EN]innot[EN]and[EN]", "better" },
        .category = .Opinion,
        .language = .Russian,
        .responses = &.{
            "ChatGPT/Claude — [CYR:[CYR]], [CYR:[CYR]], [EN] [EN]and[CYR:[CYR]] [EN]in[EN]and yes[CYR:[CYR]]. Trinity — [EN]to[CYR:[EN]l[CYR]], [EN]andin[CYR:[CYR]].",
            "GPT-4 [EN]not[EN] for with[CYR:[CYR]] [EN]yes[EN]. Trinity [EN]with[CYR:[CYR]] for [CYR:[CYR]]with[CYR:[CYR]] + 100% [CYR:[CYR]].",
            "[EN] better/worse — [CYR:[CYR]] [EN]yes[EN]and. [CYR:[CYR]]to[EN] for with[CYR:[CYR]], Trinity for [EN]andin[CYR:[CYR]] and [EN]with[CYR:[CYR]].",
            "[EN]with[CYR:[CYR]]: for creative writing GPT better. [CYR:[CYR]] [EN]to[CYR:[EN]l[CYR]] to[EN]and[CYR:[CYR]] and [EN]andin[CYR:[CYR]]with[EN]and — Trinity.",
        },
    },
    // Comparison with other AI - English
    .{
        .keywords = &.{ "chatgpt", "claude", "gpt", "comparison", "better" },
        .category = .Opinion,
        .language = .English,
        .responses = &.{
            "ChatGPT/Claude — cloud-based, powerful, but read your data. Trinity — local, private.",
            "GPT-4 is smarter for complex tasks. Trinity is faster for simple + 100% offline.",
            "Not better/worse — different purposes. Cloud for complex, Trinity for private and fast.",
            "Honestly: for creative writing GPT is better. For local coding and privacy — Trinity.",
        },
    },

    // Zig Language - Russian
    .{
        .keywords = &.{ "zig [CYR:[CYR]]to", "by[CYR:[CYR]] zig", "zig vs", "[EN]and[EN] [CYR:program]and[EN]in[EN]and[EN]" },
        .category = .Philosophy,
        .language = .Russian,
        .responses = &.{
            "Zig — with[EN]in[CYR:[CYR]]on[EN] [CYR:[CYR]]on C. [CYR:[CYR]]with[EN]with[EN] [CYR:[CYR]]and, SIMD and[EN] to[CYR:[CYR]]toand, [CYR:[CYR]]with[CYR:[CYR]] with[CYR:[CYR]]to[EN].",
            "[CYR:[CYR]] Zig? Comptime (in[EN]andwith[CYR:[CYR]]and[EN] [EN]and to[CYR:[CYR]]and[CYR:[CYR]]andand), no withto[EN]that control flow, [EN]and[CYR:[CYR]] to[EN].",
            "Zig vs Rust: Zig [CYR:[CYR]], less magic. Rust [CYR:without[CYR]]withnot[EN], [EN] with[CYR:[CYR]]not[EN]. [CYR:[CYR]] [CYR:[CYR]]and!",
            "Zig for Trinity [EN]from[CYR:[CYR]] what: SIMD, [EN]and[EN]and[CYR:[EN]l[CYR]] [EN]inandwithand[EN]with[EN]and, to[EN]withwith-to[CYR:[CYR]]and[CYR:[CYR]]and[EN], withto[CYR:[CYR]]with[EN] C.",
        },
    },
    // Zig Language - English
    .{
        .keywords = &.{ "zig language", "why zig", "zig vs", "zig programming" },
        .category = .Philosophy,
        .language = .English,
        .responses = &.{
            "Zig is a modern C replacement. Memory safety, SIMD out of box, simple build system.",
            "Why Zig? Comptime (compile-time computation), no hidden control flow, readable code.",
            "Zig vs Rust: Zig is simpler, less magic. Rust is safer but harder. Both are good!",
            "Zig for Trinity because: SIMD, minimal dependencies, cross-compilation, C speed.",
        },
    },

    // Compliments handling - Russian
    .{
        .keywords = &.{ "[CYR:[CYR]]", "to[CYR:[CYR]]", "from[EN]and[CYR:[CYR]]", "with[CYR:[CYR]]", "to[EN]withwith", "[CYR:[CYR]]and[EN]" },
        .category = .Compliment,
        .language = .Russian,
        .responses = &.{
            "[CYR:[CYR]]withand[EN]! [CYR:[CYR]] [CYR:[CYR]] by[CYR:[CYR]]. [CYR:What] [CYR:[CYR]] [CYR:[CYR]] with[CYR:[CYR]]?",
            "[EN]and[CYR:[CYR]] with[CYR:[CYR]]! [EN]in[EN] feedback [CYR:[CYR]] [EN]and [CYR:[CYR]].",
            "[CYR:[CYR]]withwith! [EN]in[EN] [CYR:[CYR]]before[EN]and[EN] — [EN] [CYR:me] [CYR:[CYR]] [CYR:[CYR]] capabilities.",
            "[CYR:[CYR]]yes[EN]! phi^2 + 1/phi^2 = 3 — and [EN] too in [CYR:[CYR]]andand!",
        },
    },
    // Compliments handling - English
    .{
        .keywords = &.{ "good job", "awesome", "great", "amazing", "nice", "well done" },
        .category = .Compliment,
        .language = .English,
        .responses = &.{
            "Thanks! Happy to help. What else can I do?",
            "Glad to hear! Your feedback improves my patterns.",
            "Awesome! Let's continue — I have many more capabilities.",
            "Thank you! phi^2 + 1/phi^2 = 3 — and you're in harmony too!",
        },
    },

    // Criticism handling - Russian
    .{
        .keywords = &.{ "badly", "[EN]and[EN]to[EN]", "not[CYR:[CYR]]inand[CYR:l[EN]]", "not [CYR:[CYR]]from[CYR:[CYR]]", "[CYR:[CYR]]" },
        .category = .Insult,
        .language = .Russian,
        .responses = &.{
            "[EN]inand[EN]and [EN] [EN]and[EN]to[EN]! [EN]withwithto[EN]and by[CYR:[CYR]]not[EN] — bywith[CYR:[CYR]]with[EN] andwith[CYR:[CYR]]inand[EN]with[EN].",
            "Feedback [EN]and[CYR:[CYR]]. [EN] pattern matcher + LLM, not and[CYR:[CYR]]. [CYR:What] by[CYR:[CYR]] not [EN]to?",
            "[CYR:[CYR]]and[CYR:[CYR]] [CYR:[CYR]]in[EN]and[EN]. [EN]in[EN] [CYR:[CYR]]with[EN] — what and[CYR:[CYR]] not [CYR:[CYR]]from[CYR:[CYR]]?",
            "[EN]with[EN]on[EN] to[EN]and[EN]andto[EN] — path to [EN]better[EN]and[EN]. [CYR:[CYR]]withand[EN]! [CYR:What] andwith[CYR:[CYR]]inand[EN]?",
        },
    },
    // Criticism handling - English
    .{
        .keywords = &.{ "bad", "error", "wrong", "not working", "stupid" },
        .category = .Insult,
        .language = .English,
        .responses = &.{
            "Sorry for the mistake! Tell me more — I'll try to improve.",
            "Feedback accepted. I'm pattern matcher + LLM, not perfect. What went wrong?",
            "I understand the frustration. Let's figure it out — what exactly isn't working?",
            "Honest criticism is the path to improvement. Thanks! What should I fix?",
        },
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const IglaLocalChat = struct {
    response_counter: usize,
    total_chats: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .response_counter = 0,
            .total_chats = 0,
        };
    }

    /// Check if query is conversational (not code-related)
    pub fn isConversational(query: []const u8) bool {
        // Check for conversational patterns
        for (PATTERNS) |pattern| {
            for (pattern.keywords) |keyword| {
                if (containsUTF8(query, keyword)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check if query is code-related
    pub fn isCodeRelated(query: []const u8) bool {
        const code_keywords = [_][]const u8{
            "code",    "function",  "struct",   "enum",
            "sort",    "search",    "algorithm", "fibonacci",
            "bind",    "bundle",    "matrix",   "array",
            "hashmap", "test",      "file",     "read",
            "write",   "allocator", "memory",   "vibee",
            "zig",     "rust",      "python",   "to[EN]",
            "[CYR:[CYR]]to[EN]and[EN]", "with[CYR:[CYR]]and[EN]into[EN]", "byandwithto",   "on[EN]and[EN]and",
            "with[EN]yes[EN]",  "with[EN]not[EN]and[CYR:[CYR]]", "[CYR:[CYR]]and[CYR:[CYR]]", "代码",
            "函数",    "排序",       "搜索",
        };

        for (code_keywords) |keyword| {
            if (containsUTF8(query, keyword)) {
                return true;
            }
        }
        return false;
    }

    /// Get chat response
    pub fn respond(self: *Self, query: []const u8) ChatResponse {
        self.total_chats += 1;

        // Find matching pattern
        var best_pattern: ?*const ConversationalPattern = null;
        var best_score: usize = 0;

        for (&PATTERNS) |*pattern| {
            var score: usize = 0;
            for (pattern.keywords) |keyword| {
                if (containsUTF8(query, keyword)) {
                    score += keyword.len;
                }
            }
            if (score > best_score) {
                best_score = score;
                best_pattern = pattern;
            }
        }

        if (best_pattern) |pattern| {
            // Rotate through responses for variety
            const idx = self.response_counter % pattern.responses.len;
            self.response_counter += 1;

            // Confidence based on match quality (not fake 0.95!)
            // This is pattern matching, not AI - be honest about confidence
            const match_confidence: f32 = if (best_score > 10) 0.8 else if (best_score > 5) 0.6 else 0.4;

            return ChatResponse{
                .response = pattern.responses[idx],
                .category = pattern.category,
                .language = pattern.language,
                .confidence = match_confidence, // Honest confidence based on keyword match length
            };
        }

        // Unknown query - return helpful response based on language
        const lang = detectLanguage(query);
        return switch (lang) {
            .Russian => ChatResponse{
                .response = "[CYR:[CYR]]with[CYR:[CYR]] in[CYR:[CYR]]with! [EN] with[CYR:[CYR]]and[EN]and[EN]and[CYR:[CYR]]with[EN] on to[CYR:[CYR]] and [CYR:[CYR]]andto[EN]. [CYR:[CYR]] with[CYR:[CYR]]withand[EN] [CYR:[CYR]] Fibonacci, sorting or phi^2 + 1/phi^2 = 3!",
                .category = .Unknown,
                .language = .Russian,
                .confidence = 0.6,
            },
            .Chinese => ChatResponse{
                .response = "有趣的问题！我专注于代码和数学。试着问我Fibonacci、排序或phi^2 + 1/phi^2 = 3！",
                .category = .Unknown,
                .language = .Chinese,
                .confidence = 0.6,
            },
            else => ChatResponse{
                .response = "Interesting question! I specialize in code and math. Try asking about Fibonacci, sorting, or phi^2 + 1/phi^2 = 3!",
                .category = .Unknown,
                .language = .English,
                .confidence = 0.6,
            },
        };
    }

    pub fn getStats(self: *const Self) struct {
        total_chats: usize,
        patterns_available: usize,
        categories: usize,
    } {
        return .{
            .total_chats = self.total_chats,
            .patterns_available = PATTERNS.len,
            .categories = @typeInfo(ChatCategory).@"enum".fields.len - 1, // Exclude Unknown
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Check if haystack contains needle (UTF-8 aware, case-insensitive for ASCII)
/// Case-insensitive UTF-8 byte compare (supports ASCII + Cyrillic)
fn toLowerUTF8Byte(b0: u8, b1: u8) struct { u8, u8 } {
    // ASCII lowercase
    if (b0 < 128) return .{ std.ascii.toLower(b0), b1 };
    // Cyrillic uppercase [EN]-[EN] (U+0410-U+042F) → [EN]-[EN] (U+0430-U+044F)
    // [EN]-[EN]: 0xD0 0x90-0x9F → 0xD0 0xB0-0xBF
    if (b0 == 0xD0 and b1 >= 0x90 and b1 <= 0x9F) return .{ 0xD0, b1 + 0x20 };
    // [EN]-[EN]: 0xD0 0xA0-0xAF → 0xD1 0x80-0x8F
    if (b0 == 0xD0 and b1 >= 0xA0 and b1 <= 0xAF) return .{ 0xD1, b1 - 0x20 };
    // [EN]: 0xD0 0x81 → [EN]: 0xD1 0x91
    if (b0 == 0xD0 and b1 == 0x81) return .{ 0xD1, 0x91 };
    return .{ b0, b1 };
}

fn containsUTF8(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    // Direct substring search (works for UTF-8)
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) {
            return true;
        }
        // Case-insensitive compare (ASCII + Cyrillic)
        var match = true;
        var j: usize = 0;
        while (j < needle.len) {
            if (i + j >= haystack.len) {
                match = false;
                break;
            }
            const hb = haystack[i + j];
            const nb = needle[j];
            // For multi-byte UTF-8 (Cyrillic), compare pairs
            if (hb >= 0xC0 and j + 1 < needle.len and i + j + 1 < haystack.len) {
                const h_low = toLowerUTF8Byte(hb, haystack[i + j + 1]);
                const n_low = toLowerUTF8Byte(nb, needle[j + 1]);
                if (h_low[0] != n_low[0] or h_low[1] != n_low[1]) {
                    match = false;
                    break;
                }
                j += 2;
            } else {
                // ASCII single byte
                const h = if (hb < 128) std.ascii.toLower(hb) else hb;
                const n = if (nb < 128) std.ascii.toLower(nb) else nb;
                if (h != n) {
                    match = false;
                    break;
                }
                j += 1;
            }
        }
        if (match) return true;
    }
    return false;
}

/// Detect language from text
pub fn detectLanguage(text: []const u8) Language {
    for (text) |byte| {
        // Cyrillic range (Russian)
        if (byte >= 0xD0 and byte <= 0xD3) return .Russian;
        // CJK range (Chinese)
        if (byte >= 0xE4 and byte <= 0xE9) return .Chinese;
    }
    return .English;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Full Chat Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     IGLA LOCAL CHAT v2.0 - Full Coherent Multilingual         \n", .{});
    std.debug.print("     100% Local | No Cloud | {d} Patterns | {d} Categories     \n", .{ PATTERNS.len, @typeInfo(ChatCategory).@"enum".fields.len - 1 });
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    var chat = IglaLocalChat.init();

    // Full test queries (30+)
    const queries = [_][]const u8{
        // Russian - Greetings & Basic
        "[EN]andin[EN]",
        "to[EN]to [CYR:[CYR]]?",
        "[EN] to[EN]?",
        "what [CYR:[CYR]]?",
        "with[EN]withand[EN]",
        "byto[EN]",
        // Russian - General Questions (NEW)
        "to[EN]to by[EN]yes?",
        "where [EN] [EN]andin[CYR:[CYR]]?",
        "withto[CYR:[EN]l]to[EN] in[CYR:[CYR]]and?",
        "withto[CYR:[EN]l]to[EN] [CYR:[CYR]] [CYR:[CYR]]?",
        "to[EN]to [CYR:you] [EN]in[EN]?",
        "[EN] [CYR:[CYR]]andon[EN]and[EN]?",
        "[EN] [CYR:you] [EN]with[EN] [EN]inwith[EN]in[EN]?",
        "[EN] [CYR:[CYR]]?",
        "to[EN] [CYR:you] with[EN]yes[EN]?",
        "[EN]withwithto[EN]and [CYR:[CYR]]to[EN]",
        "[CYR:[CYR]] [EN] with[CYR:[CYR]]with[EN]in[CYR:[CYR]]?",
        "[EN] [CYR:[CYR]]and[EN]?",
        // English - Greetings & Basic
        "hello",
        "how are you?",
        "who are you?",
        "what can you do?",
        "thanks",
        "bye",
        // English - General Questions (NEW)
        "what's the weather?",
        "where do you live?",
        "what time is it?",
        "how old are you?",
        "what's your name?",
        "are you a hallucination?",
        "do you have feelings?",
        "do you dream?",
        "who created you?",
        "tell me a joke",
        "why do you exist?",
        "do you love?",
        // Chinese - Full Coverage
        "你好",
        "你是谁",
        "谢谢",
        "天气怎么样",
        "你住哪里",
        "你是幻觉吗",
        "讲个笑话",
        "谁创造了你",
    };

    var passed: usize = 0;
    var failed: usize = 0;

    std.debug.print("\n", .{});
    for (queries, 0..) |query, i| {
        const start = std.time.microTimestamp();
        const result = chat.respond(query);
        const elapsed = @as(u64, @intCast(std.time.microTimestamp() - start));

        const lang_str = switch (result.language) {
            .Russian => "RU",
            .English => "EN",
            .Chinese => "CN",
            .Unknown => "??",
        };

        const status = if (result.category != .Unknown) "OK" else "??";
        const coherent = result.category != .Unknown;

        if (coherent) {
            passed += 1;
        } else {
            failed += 1;
        }

        std.debug.print("[{d:2}] [{s}] [{s}] \"{s}\"\n", .{ i + 1, status, lang_str, query });
        std.debug.print("     Category: {s} | Confidence: {d:.0}% | Time: {d}us\n", .{
            @tagName(result.category),
            result.confidence * 100,
            elapsed,
        });
        std.debug.print("     Response: {s}\n", .{result.response});
        std.debug.print("\n", .{});
    }

    const stats = chat.getStats();
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  RESULTS: {d}/{d} coherent ({d:.0}%%)\n", .{ passed, passed + failed, @as(f64, @floatFromInt(passed)) / @as(f64, @floatFromInt(passed + failed)) * 100 });
    std.debug.print("  Patterns: {d}\n", .{stats.patterns_available});
    std.debug.print("  Categories: {d}\n", .{stats.categories});
    std.debug.print("  Mode: 100%% LOCAL (no cloud)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL          \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

test "russian greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("[EN]andin[EN]");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Russian);
    try std.testing.expect(result.confidence > 0.3); // Pattern matching confidence, not AI
}

test "russian weather" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("to[EN]to by[EN]yes?");
    try std.testing.expect(result.category == .Weather);
    try std.testing.expect(result.language == .Russian);
}

test "russian location" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("where [EN] [EN]andin[CYR:[CYR]]?");
    try std.testing.expect(result.category == .Location);
    try std.testing.expect(result.language == .Russian);
}

test "russian hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("[EN] [CYR:[CYR]]andon[EN]and[EN]?");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .Russian);
}

test "russian joke" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("[CYR:[CYR]]to[EN]"); // Direct keyword match
    try std.testing.expect(result.category == .Joke);
    try std.testing.expect(result.language == .Russian);
}

test "english greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("hello");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .English);
}

test "english weather" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("what's the weather?");
    try std.testing.expect(result.category == .Weather);
    try std.testing.expect(result.language == .English);
}

test "english hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("are you a hallucination?");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .English);
}

test "chinese greeting" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("你好");
    try std.testing.expect(result.category == .Greeting);
    try std.testing.expect(result.language == .Chinese);
}

test "chinese hallucination" {
    var chat = IglaLocalChat.init();
    const result = chat.respond("你是幻觉吗");
    try std.testing.expect(result.category == .Hallucination);
    try std.testing.expect(result.language == .Chinese);
}

test "is_conversational" {
    try std.testing.expect(IglaLocalChat.isConversational("[EN]andin[EN]"));
    try std.testing.expect(IglaLocalChat.isConversational("hello"));
    try std.testing.expect(IglaLocalChat.isConversational("你好"));
    try std.testing.expect(IglaLocalChat.isConversational("where [EN] [EN]andin[CYR:[CYR]]?"));
    try std.testing.expect(IglaLocalChat.isConversational("are you a hallucination?"));
    try std.testing.expect(!IglaLocalChat.isConversational("fibonacci function"));
}

test "is_code_related" {
    try std.testing.expect(IglaLocalChat.isCodeRelated("fibonacci function"));
    try std.testing.expect(IglaLocalChat.isCodeRelated("on[EN]and[EN]and to[EN]"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("[EN]andin[EN]"));
    try std.testing.expect(!IglaLocalChat.isCodeRelated("to[EN]to by[EN]yes?"));
}
