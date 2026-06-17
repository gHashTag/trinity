//! TRIOS Garden — Data Cultivation and Model Growth FFI
//!
//! This crate provides FFI bindings for TRIOS garden operations including
//! data plot management, model seed initialization, growth tracking,
//! evolutionary metrics, and harvest/culling operations.
//!
//! ## Features
//!
//! - **GardenPlot**: Data container with metadata and health metrics
//! - **Seed**: Model initializer with hyperparameters
//! - **Growth Metrics**: Track model training progress over time
//! - **Evolution**: Generation tracking with fitness scores
//! - **Harvest**: Select best models, cull underperformers
//!
//! ## Symbol: `🌱`

use std::os::raw::{c_char, c_double, c_long};

// ─── Constants ────────────────────────────────────────────────────────

/// Maximum number of plots in a garden
pub const MAX_PLOTS: usize = 64;

/// Maximum number of seeds per plot
pub const MAX_SEEDS: usize = 256;

/// Maximum number of growth records
pub const MAX_GROWTH_RECORDS: usize = 1024;

/// Maximum generations for evolution
pub const MAX_GENERATIONS: usize = 1000;

/// Maximum name length
pub const MAX_NAME_LEN: usize = 128;

/// Maximum tag length
pub const MAX_TAG_LEN: usize = 64;

// ─── Enums ────────────────────────────────────────────────────────────

/// Plot health status
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PlotHealth {
    /// Plot is thriving — all metrics green
    Thriving = 0,
    /// Plot is healthy — minor issues
    Healthy = 1,
    /// Plot needs attention — metrics degrading
    NeedsAttention = 2,
    /// Plot is wilting — significant degradation
    Wilting = 3,
    /// Plot is dead — should be culled
    Dead = 4,
}

/// Seed type
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SeedType {
    /// Neural network model
    NeuralNet = 0,
    /// VSA (Vector Symbolic Architecture) model
    Vsa = 1,
    /// HSLM (Hierarchical Sparse Language Model)
    Hslm = 2,
    /// Ternary quantized model
    Ternary = 3,
    /// Custom model
    Custom = 4,
}

/// Growth phase
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GrowthPhase {
    /// Seed planted, not yet germinated
    Planted = 0,
    /// Initial training epoch
    Germinating = 1,
    /// Active training
    Growing = 2,
    /// Training converged
    Mature = 3,
    /// Ready for deployment
    Harvestable = 4,
    /// Deprecated / superseded
    Deprecated = 5,
}

/// Evolution operation
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EvolutionOp {
    /// Mutation — small random change
    Mutate = 0,
    /// Crossover — combine two parents
    Crossover = 1,
    /// Selection — keep top performers
    Select = 2,
    /// Culling — remove worst performers
    Cull = 3,
    /// Reset — start fresh generation
    Reset = 4,
}

// ─── Structs ──────────────────────────────────────────────────────────

/// Garden plot — a data container with health metrics
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct GardenPlot {
    /// Plot name (null-terminated)
    pub name: [c_char; MAX_NAME_LEN],
    /// Plot ID
    pub id: usize,
    /// Health status
    pub health: PlotHealth,
    /// Current growth phase
    pub phase: GrowthPhase,
    /// Number of seeds in this plot
    pub seed_count: usize,
    /// Fitness score [0.0, 1.0]
    pub fitness: c_double,
    /// Loss value (lower is better)
    pub loss: c_double,
    /// Accuracy [0.0, 1.0]
    pub accuracy: c_double,
    /// Training epoch
    pub epoch: usize,
    /// Generation number
    pub generation: usize,
    /// Timestamp of last update (epoch seconds)
    pub last_updated: c_long,
    /// Tags for categorization
    pub tags: [[c_char; MAX_TAG_LEN]; 4],
    /// Number of active tags
    pub tag_count: usize,
}

/// Seed — model initializer
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Seed {
    /// Seed name (null-terminated)
    pub name: [c_char; MAX_NAME_LEN],
    /// Seed type
    pub seed_type: SeedType,
    /// Learning rate
    pub learning_rate: c_double,
    /// Batch size
    pub batch_size: usize,
    /// Number of layers
    pub layers: usize,
    /// Hidden dimension
    pub hidden_dim: usize,
    /// Dropout rate [0.0, 1.0]
    pub dropout: c_double,
    /// Weight decay
    pub weight_decay: c_double,
    /// Random seed for reproducibility
    pub rng_seed: c_long,
    /// Whether this seed is active
    pub active: bool,
    /// Initial fitness score
    pub initial_fitness: c_double,
}

/// Growth record — a snapshot of training progress
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct GrowthRecord {
    /// Epoch number
    pub epoch: usize,
    /// Training loss
    pub train_loss: c_double,
    /// Validation loss
    pub val_loss: c_double,
    /// Training accuracy
    pub train_accuracy: c_double,
    /// Validation accuracy
    pub val_accuracy: c_double,
    /// Learning rate at this epoch
    pub learning_rate: c_double,
    /// Time elapsed in ms
    pub elapsed_ms: c_long,
    /// Memory usage in bytes
    pub memory_bytes: usize,
    /// Growth phase at this epoch
    pub phase: GrowthPhase,
}

/// Evolution entry — tracks one generation
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct EvolutionEntry {
    /// Generation number
    pub generation: usize,
    /// Operation that created this generation
    pub operation: EvolutionOp,
    /// Population size
    pub population_size: usize,
    /// Best fitness in this generation
    pub best_fitness: c_double,
    /// Average fitness in this generation
    pub avg_fitness: c_double,
    /// Worst fitness in this generation
    pub worst_fitness: c_double,
    /// Diversity metric [0.0, 1.0]
    pub diversity: c_double,
    /// Number of elites preserved
    pub elites: usize,
    /// Timestamp (epoch seconds)
    pub timestamp: c_long,
}

/// Garden — top-level container for all plots
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Garden {
    /// Plots
    pub plots: [GardenPlot; MAX_PLOTS],
    /// Number of plots
    pub plot_count: usize,
    /// Current generation
    pub generation: usize,
    /// Best fitness across all plots
    pub best_fitness: c_double,
    /// Average fitness across all plots
    pub avg_fitness: c_double,
    /// Total number of seeds across all plots
    pub total_seeds: usize,
    /// Evolution history
    pub evolution: [EvolutionEntry; MAX_GENERATIONS],
    /// Number of evolution entries
    pub evolution_count: usize,
}

// ─── Garden Lifecycle ─────────────────────────────────────────────────

/// Create a new empty garden
#[no_mangle]
pub extern "C" fn trios_garden_new() -> Garden {
    Garden {
        plots: unsafe { std::mem::zeroed() },
        plot_count: 0,
        generation: 0,
        best_fitness: 0.0,
        avg_fitness: 0.0,
        total_seeds: 0,
        evolution: unsafe { std::mem::zeroed() },
        evolution_count: 0,
    }
}

/// Add a plot to the garden
#[no_mangle]
pub extern "C" fn trios_garden_add_plot(garden: *mut Garden, plot: GardenPlot) -> bool {
    if garden.is_null() {
        return false;
    }
    unsafe {
        if (*garden).plot_count >= MAX_PLOTS {
            return false;
        }
        (*garden).plots[(*garden).plot_count] = plot;
        (*garden).plot_count += 1;
        (*garden).total_seeds += plot.seed_count;
        trios_garden_recompute_fitness(garden);
        true
    }
}

/// Recompute aggregate fitness metrics
#[no_mangle]
pub extern "C" fn trios_garden_recompute_fitness(garden: *mut Garden) {
    if garden.is_null() {
        return;
    }
    unsafe {
        let n = (*garden).plot_count;
        if n == 0 {
            (*garden).best_fitness = 0.0;
            (*garden).avg_fitness = 0.0;
            return;
        }
        let mut best = 0.0_f64;
        let mut sum = 0.0_f64;
        for i in 0..n {
            let f = (*garden).plots[i].fitness;
            if f > best {
                best = f;
            }
            sum += f;
        }
        (*garden).best_fitness = best;
        (*garden).avg_fitness = sum / n as c_double;
    }
}

// ─── Plot Lifecycle ───────────────────────────────────────────────────

/// Create a new garden plot
#[no_mangle]
pub extern "C" fn trios_garden_plot_new(
    name: *const c_char,
    id: usize,
) -> GardenPlot {
    let mut plot: GardenPlot = unsafe { std::mem::zeroed() };
    plot.id = id;
    plot.health = PlotHealth::Healthy;
    plot.phase = GrowthPhase::Planted;
    plot.fitness = 0.0;
    plot.loss = f64::MAX;

    if !name.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(name) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_NAME_LEN - 1);
        plot.name[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        plot.name[len] = 0;
    }

    plot
}

/// Update plot health based on metrics
#[no_mangle]
pub extern "C" fn trios_garden_plot_update_health(plot: *mut GardenPlot) {
    if plot.is_null() {
        return;
    }
    unsafe {
        let fitness = (*plot).fitness;
        let loss = (*plot).loss;

        (*plot).health = if fitness >= 0.9 && loss < 0.1 {
            PlotHealth::Thriving
        } else if fitness >= 0.7 && loss < 0.3 {
            PlotHealth::Healthy
        } else if fitness >= 0.5 && loss < 0.5 {
            PlotHealth::NeedsAttention
        } else if fitness >= 0.2 {
            PlotHealth::Wilting
        } else {
            PlotHealth::Dead
        };
    }
}

/// Advance plot to next growth phase
#[no_mangle]
pub extern "C" fn trios_garden_plot_advance_phase(plot: *mut GardenPlot) -> GrowthPhase {
    if plot.is_null() {
        return GrowthPhase::Planted;
    }
    unsafe {
        (*plot).phase = match (*plot).phase {
            GrowthPhase::Planted => GrowthPhase::Germinating,
            GrowthPhase::Germinating => GrowthPhase::Growing,
            GrowthPhase::Growing => GrowthPhase::Mature,
            GrowthPhase::Mature => GrowthPhase::Harvestable,
            _ => (*plot).phase,
        };
        (*plot).phase
    }
}

// ─── Seed Lifecycle ───────────────────────────────────────────────────

/// Create a new seed with default hyperparameters
#[no_mangle]
pub extern "C" fn trios_garden_seed_new(
    name: *const c_char,
    seed_type: SeedType,
) -> Seed {
    let mut seed: Seed = unsafe { std::mem::zeroed() };
    seed.seed_type = seed_type;
    seed.learning_rate = 0.001;
    seed.batch_size = 32;
    seed.layers = 3;
    seed.hidden_dim = 256;
    seed.dropout = 0.1;
    seed.weight_decay = 0.0001;
    seed.rng_seed = 42;
    seed.active = true;
    seed.initial_fitness = 0.0;

    if !name.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(name) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(MAX_NAME_LEN - 1);
        seed.name[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        seed.name[len] = 0;
    }

    seed
}

// ─── Growth Tracking ──────────────────────────────────────────────────

/// Create a growth record from training metrics
#[no_mangle]
pub extern "C" fn trios_garden_growth_record(
    epoch: usize,
    train_loss: c_double,
    val_loss: c_double,
    train_accuracy: c_double,
    val_accuracy: c_double,
    learning_rate: c_double,
    elapsed_ms: c_long,
) -> GrowthRecord {
    let phase = if epoch == 0 {
        GrowthPhase::Germinating
    } else if val_accuracy < 0.5 {
        GrowthPhase::Growing
    } else if val_accuracy < 0.9 {
        GrowthPhase::Mature
    } else {
        GrowthPhase::Harvestable
    };

    GrowthRecord {
        epoch,
        train_loss,
        val_loss,
        train_accuracy,
        val_accuracy,
        learning_rate,
        elapsed_ms,
        memory_bytes: 0,
        phase,
    }
}

/// Determine growth phase from metrics
#[no_mangle]
pub extern "C" fn trios_garden_determine_phase(
    epoch: usize,
    val_accuracy: c_double,
    val_loss: c_double,
) -> GrowthPhase {
    if epoch == 0 {
        GrowthPhase::Germinating
    } else if val_loss > 1.0 || val_accuracy < 0.3 {
        GrowthPhase::Growing
    } else if val_accuracy < 0.85 {
        GrowthPhase::Mature
    } else {
        GrowthPhase::Harvestable
    }
}

// ─── Evolution Tracking ───────────────────────────────────────────────

/// Record an evolution event
#[no_mangle]
pub extern "C" fn trios_garden_record_evolution(
    garden: *mut Garden,
    operation: EvolutionOp,
    population_size: usize,
    best_fitness: c_double,
    avg_fitness: c_double,
    worst_fitness: c_double,
    diversity: c_double,
    elites: usize,
    timestamp: c_long,
) -> bool {
    if garden.is_null() {
        return false;
    }
    unsafe {
        if (*garden).evolution_count >= MAX_GENERATIONS {
            return false;
        }
        let current_gen = (*garden).generation;
        (*garden).evolution[(*garden).evolution_count] = EvolutionEntry {
            generation: current_gen,
            operation,
            population_size,
            best_fitness,
            avg_fitness,
            worst_fitness,
            diversity,
            elites,
            timestamp,
        };
        (*garden).evolution_count += 1;
        (*garden).generation += 1;
        true
    }
}

/// Get the best plot by fitness
#[no_mangle]
pub extern "C" fn trios_garden_best_plot(garden: *const Garden) -> usize {
    if garden.is_null() {
        return 0;
    }
    unsafe {
        let mut best_idx = 0;
        let mut best_fitness = -1.0_f64;
        for i in 0..(*garden).plot_count {
            if (*garden).plots[i].fitness > best_fitness {
                best_fitness = (*garden).plots[i].fitness;
                best_idx = i;
            }
        }
        best_idx
    }
}

/// Cull plots below a fitness threshold — returns number culled
#[no_mangle]
pub extern "C" fn trios_garden_cull(garden: *mut Garden, threshold: c_double) -> usize {
    if garden.is_null() {
        return 0;
    }
    unsafe {
        let mut culled = 0;
        for i in 0..(*garden).plot_count {
            if (*garden).plots[i].fitness < threshold {
                (*garden).plots[i].health = PlotHealth::Dead;
                (*garden).plots[i].phase = GrowthPhase::Deprecated;
                culled += 1;
            }
        }
        culled
    }
}

// ─── Unit Tests ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_garden_new() {
        let garden = trios_garden_new();
        assert_eq!(garden.plot_count, 0);
        assert_eq!(garden.generation, 0);
        assert_eq!(garden.best_fitness, 0.0);
    }

    #[test]
    fn test_plot_new() {
        let plot = trios_garden_plot_new(
            b"test_plot\0".as_ptr() as *const c_char,
            1,
        );
        assert_eq!(plot.id, 1);
        assert_eq!(plot.health, PlotHealth::Healthy);
        assert_eq!(plot.phase, GrowthPhase::Planted);
    }

    #[test]
    fn test_plot_health_update() {
        let mut plot = trios_garden_plot_new(
            b"test\0".as_ptr() as *const c_char,
            0,
        );
        plot.fitness = 0.95;
        plot.loss = 0.05;
        trios_garden_plot_update_health(&mut plot);
        assert_eq!(plot.health, PlotHealth::Thriving);

        plot.fitness = 0.1;
        plot.loss = 2.0;
        trios_garden_plot_update_health(&mut plot);
        assert_eq!(plot.health, PlotHealth::Dead);
    }

    #[test]
    fn test_plot_advance_phase() {
        let mut plot = trios_garden_plot_new(
            b"test\0".as_ptr() as *const c_char,
            0,
        );
        assert_eq!(plot.phase, GrowthPhase::Planted);
        trios_garden_plot_advance_phase(&mut plot);
        assert_eq!(plot.phase, GrowthPhase::Germinating);
        trios_garden_plot_advance_phase(&mut plot);
        assert_eq!(plot.phase, GrowthPhase::Growing);
    }

    #[test]
    fn test_seed_new() {
        let seed = trios_garden_seed_new(
            b"model_v1\0".as_ptr() as *const c_char,
            SeedType::NeuralNet,
        );
        assert_eq!(seed.seed_type, SeedType::NeuralNet);
        assert_eq!(seed.learning_rate, 0.001);
        assert_eq!(seed.batch_size, 32);
        assert!(seed.active);
    }

    #[test]
    fn test_garden_add_plot() {
        let mut garden = trios_garden_new();
        let plot = trios_garden_plot_new(
            b"plot1\0".as_ptr() as *const c_char,
            0,
        );
        assert!(trios_garden_add_plot(&mut garden, plot));
        assert_eq!(garden.plot_count, 1);
    }

    #[test]
    fn test_growth_record() {
        let record = trios_garden_growth_record(
            10, 0.5, 0.6, 0.8, 0.75, 0.001, 5000,
        );
        assert_eq!(record.epoch, 10);
        assert_eq!(record.train_loss, 0.5);
    }

    #[test]
    fn test_determine_phase() {
        assert_eq!(trios_garden_determine_phase(0, 0.0, 1.0), GrowthPhase::Germinating);
        assert_eq!(trios_garden_determine_phase(5, 0.2, 2.0), GrowthPhase::Growing);
        assert_eq!(trios_garden_determine_phase(50, 0.8, 0.3), GrowthPhase::Mature);
        assert_eq!(trios_garden_determine_phase(100, 0.95, 0.05), GrowthPhase::Harvestable);
    }

    #[test]
    fn test_cull() {
        let mut garden = trios_garden_new();
        let mut plot1 = trios_garden_plot_new(b"good\0".as_ptr() as *const c_char, 0);
        plot1.fitness = 0.9;
        let mut plot2 = trios_garden_plot_new(b"bad\0".as_ptr() as *const c_char, 1);
        plot2.fitness = 0.1;

        trios_garden_add_plot(&mut garden, plot1);
        trios_garden_add_plot(&mut garden, plot2);

        let culled = trios_garden_cull(&mut garden, 0.5);
        assert_eq!(culled, 1);
        assert_eq!(garden.plots[0].health, PlotHealth::Healthy);
        assert_eq!(garden.plots[1].health, PlotHealth::Dead);
    }
}
