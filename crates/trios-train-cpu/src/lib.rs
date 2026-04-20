//! trios-train-cpu — CPU-based training with Trinity 3ᵏ architecture
//!
//! Research findings from EXP-001 to EXP-025:
//! - EXP-001: ctx=27 (3³) → PPL 2.96 vs ctx=18 → PPL 5.58
//! - EXP-012: Square Attention Theorem — ctx must equal head_dim
//! - EXP-014: Resonance Law — optimal 3ᵏ dimensions (9, 27, 81)
//! - EXP-025: Early kill thresholds, cosine LR schedule
//!
//! ## Modules
//!
//! - `forward`: Trinity architecture constants and operations
//! - `optimizer`: LAMB, AdamW optimizers and LR schedules
//! - `bench`: Training configuration with research-backed defaults
//! - `tjepa`: Ternary Joint-Embedding Predictive Architecture
//! - `nca`: Neural Cellular Automata for pre-pre-training
//! - `objective`: Multi-objective training (NTP, JEPA, NCA, hybrid)
//! - `model`: IglaConfig and model definition

pub mod forward;
pub mod optimizer;
pub mod bench;
pub mod tjepa;
pub mod nca;
pub mod objective;
pub mod model;

// Re-exports for convenience
pub use forward::{
    LayerDims,
    TRINITY_VOCAB_SIZE,
    TRINITY_HIDDEN_DIM,
    TRINITY_EMBED_DIM,
    TRINITY_CONTEXT_LEN,
    TRINITY_NUM_BLOCKS,
    TRINITY_HEADS,
    TRINITY_HEAD_DIM,
    matmul,
    gelu,
    gelu_inplace,
    layer_norm,
    layer_norm_inplace,
    softmax,
    transpose_inplace,
};

pub use optimizer::{
    LAMBCpu,
    AdamWCpu,
    cosine_lr_schedule,
    phi_lr_schedule,
    LrSchedule,
};

pub use bench::{
    TrainConfig,
    RunConfig,
    KillThresholds,
    BenchMetrics,
    cosine_lr_schedule as bench_cosine_lr_schedule,
    should_kill,
};

pub use tjepa::{
    MaskConfig,
    EmaSync,
    TjepaPredictor,
    ema_decay,
    l2_normalized_mse,
};

pub use nca::{
    NcaConfig,
    NcaTrainer,
};

pub use objective::{
    Objective,
    ObjectiveWeights,
    TrainingScenario,
    TrainingPhase,
    CombinedLoss,
    scenario_s4,
    scenario_s5,
    get_phases_for_objective,
};

pub use model::{
    IglaConfig,
    IglaModel,
};

/// Crate version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Crate name
pub const CRATE_NAME: &str = "trios_train_cpu";
