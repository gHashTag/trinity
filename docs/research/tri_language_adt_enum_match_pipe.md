// ═══════════════════════════════════════════════════════════════════════════════════
// adt_enum_demo.tri - Tri Language ADT Enum + Match + Pipe Demo (Issue #408)
// ═══════════════════════════════════════════════════════════════════════════════════
//
// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
// Golden identity: φ² + 1/φ² = 3
//
// Demonstrates:
// - ADT enum (data-carrying enums like Rust)
// - Exhaustive match (compiler checks all variants)
// - Pipe operator |> (Elixir-style)
// - Named pipelines
// - Guards (Haskell-style | condition)
//
// ═════════════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════
// ADT ENUM - Simple enums (VIBEE compatible)
// ═════════════════════════════════════════════════════════════════════════════════════

/// Quality classification
const Quality = enum {
    Good,
    Unstable,
    Bad,
    Unknown,
};

/// Neuron state
const NeuronState = enum {
    Active,
    Inhibited,
    Resting,
};

/// Signal polarity
const SignalPolarity = enum {
    Positive,
    Zero,
    Negative,
};

/// Category
const Category = enum {
    Low,
    Medium,
    High,
    Extreme,
};

// ═══════════════════════════════════════════════════════════════════════
// STRUCTS - Data containers
// ═════════════════════════════════════════════════════════════════════════════════════

/// 3D vector
const Vec3 = struct {
    x: gf16,
    y: gf16,
    z: gf16,
};

/// Signal with polarity
const Signal = struct {
    polarity: SignalPolarity,
    level: gf16,
};

/// Episode data
const Episode = struct {
    id: tword,
    quality: Quality,
    timestamp: i64,
};

/// Window evaluation result
const WindowEvaluation = struct {
    total: u32,
    successful: u32,
    failed: u32,
    crashed: u32,
    quality: Quality,
};

// ═══════════════════════════════════════════════════════════════════════
// EXHAUSTIVE MATCH - Pattern matching on all variants
// ═════════════════════════════════════════════════════════════════════════════════════

/// Match on signal polarity - 3-way exhaustive match
fn classify_signal(polarity: SignalPolarity) Quality {
    match polarity {
        .Positive => .Good,
        .Zero => .Unknown,
        .Negative => .Bad,
    }
}

/// Match on neuron state
fn process_neuron(state: NeuronState) trit {
    match state {
        .Active => activate(),
        .Inhibited => decay(phi),
        .Resting => hold(),
    }
}

/// Match with guards - Haskell-style | condition
fn classify_with_guard(value: i32) Category {
    match value {
        _ | value > 90 => .High,
        _ | value > 50 => .Medium,
        _ | value > 10 => .Low,
        _ => .Extreme,
    }
}

/// Match with complex guard
fn classify_ppl(ppl: f64) Quality {
    match ppl {
        _ | ppl < 5.0 => .Good,
        _ | ppl < 20.0 => .Unstable,
        _ | ppl < 50.0 => .Bad,
        _ => .Unknown,
    }
}

// ═══════════════════════════════════════════════════════════════════════
// PIPE OPERATOR - Elixir-style |> for function chaining
// ═════════════════════════════════════════════════════════════════════════════════════

/// Single pipe: input |> func
fn process_single(input: []trit) []gf16 {
    return input |> encode_to_gf16
}

/// Multi-stage pipe: input |> f1 |> f2 |> f3
fn process_pipeline(input: []trit) Quality {
    return input
        |> encode_to_gf16
        |> normalize
        |> classify
}

/// Complex neuroanatomic flow (Phase 0.5 diagram as executable)
fn neuro_flow(input: Signal) Response {
    return input
        |> vlpfc_filter       // attention filter
        |> dlpfc_hold         // working memory
        |> vmpfc_evaluate     // value assessment
        |> dmpfc_monitor      // self-check
        |> ofc_respond        // form response
}

// ═══════════════════════════════════════════════════════════════════════
// NAMED PIPELINES - Reusable pipe chains
// ═════════════════════════════════════════════════════════════════════════════════════

/// Define named pipeline for PPL stabilization
pipeline ppl_stabilize = input
    |> phi_decay
    |> clamp
    |> validate

/// Define named pipeline for episode processing
pipeline episode_process = episode
    |> extract_features
    |> classify_quality
    |> update_window

// ═══════════════════════════════════════════════════════════════════════
// PATTERN MATCHING - On literals, wildcards, ranges
// ═════════════════════════════════════════════════════════════════════════════════════

/// Match on literal values
fn decode_trit(value: i32) SignalPolarity {
    match value {
        1 => .Positive,
        0 => .Zero,
        -1 => .Negative,
        _ => .Zero,
    }
}

/// Match with wildcard
fn is_positive(value: i32) bool {
    match value {
        _ | value > 0 => true,
        _ => false,
    }
}

/// Match on ranges
fn classify_value(value: i32) Category {
    match value {
        0..=10 => .Low,
        11..=50 => .Medium,
        51..=100 => .High,
        _ => .Extreme,
    }
}

/// Exclusive range
fn check_index(idx: usize) bool {
    match idx {
        0..10 => true,
        _ => false,
    }
}

// ═══════════════════════════════════════════════════════════════════════
// STRUCT PATTERNS
// ═════════════════════════════════════════════════════════════════════════════════════

/// Match on struct fields
fn normalize_vec3(vec: Vec3) Vec3 {
    match vec {
        Vec3 { .x = 0, .y = 0, .z = 0 } => Vec3 { .x = 0, .y = 0, .z = 0 },
        Vec3 { .x = x, .y = y, .z = z } => {
            const len = sqrt(x*x + y*y + z*z)
            Vec3 { .x = x/len, .y = y/len, .z = z/len }
        },
    }
}

/// Extract quality from window evaluation
fn get_quality(window: WindowEvaluation) Quality {
    match window {
        WindowEvaluation { .quality = q } => q,
    }
}
