#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum number of plots in a garden
 */
#define MAX_PLOTS 64

/**
 * Maximum number of seeds per plot
 */
#define MAX_SEEDS 256

/**
 * Maximum number of growth records
 */
#define MAX_GROWTH_RECORDS 1024

/**
 * Maximum generations for evolution
 */
#define MAX_GENERATIONS 1000

/**
 * Maximum name length
 */
#define MAX_NAME_LEN 128

/**
 * Maximum tag length
 */
#define MAX_TAG_LEN 64

/**
 * Evolution operation
 */
typedef enum EvolutionOp {
  /**
   * Mutation — small random change
   */
  Mutate = 0,
  /**
   * Crossover — combine two parents
   */
  Crossover = 1,
  /**
   * Selection — keep top performers
   */
  Select = 2,
  /**
   * Culling — remove worst performers
   */
  Cull = 3,
  /**
   * Reset — start fresh generation
   */
  Reset = 4,
} EvolutionOp;

/**
 * Growth phase
 */
typedef enum GrowthPhase {
  /**
   * Seed planted, not yet germinated
   */
  Planted = 0,
  /**
   * Initial training epoch
   */
  Germinating = 1,
  /**
   * Active training
   */
  Growing = 2,
  /**
   * Training converged
   */
  Mature = 3,
  /**
   * Ready for deployment
   */
  Harvestable = 4,
  /**
   * Deprecated / superseded
   */
  Deprecated = 5,
} GrowthPhase;

/**
 * Plot health status
 */
typedef enum PlotHealth {
  /**
   * Plot is thriving — all metrics green
   */
  Thriving = 0,
  /**
   * Plot is healthy — minor issues
   */
  Healthy = 1,
  /**
   * Plot needs attention — metrics degrading
   */
  NeedsAttention = 2,
  /**
   * Plot is wilting — significant degradation
   */
  Wilting = 3,
  /**
   * Plot is dead — should be culled
   */
  Dead = 4,
} PlotHealth;

/**
 * Seed type
 */
typedef enum SeedType {
  /**
   * Neural network model
   */
  NeuralNet = 0,
  /**
   * VSA (Vector Symbolic Architecture) model
   */
  Vsa = 1,
  /**
   * HSLM (Hierarchical Sparse Language Model)
   */
  Hslm = 2,
  /**
   * Ternary quantized model
   */
  Ternary = 3,
  /**
   * Custom model
   */
  Custom = 4,
} SeedType;

/**
 * Garden plot — a data container with health metrics
 */
typedef struct GardenPlot {
  /**
   * Plot name (null-terminated)
   */
  char name[MAX_NAME_LEN];
  /**
   * Plot ID
   */
  uintptr_t id;
  /**
   * Health status
   */
  enum PlotHealth health;
  /**
   * Current growth phase
   */
  enum GrowthPhase phase;
  /**
   * Number of seeds in this plot
   */
  uintptr_t seed_count;
  /**
   * Fitness score [0.0, 1.0]
   */
  double fitness;
  /**
   * Loss value (lower is better)
   */
  double loss;
  /**
   * Accuracy [0.0, 1.0]
   */
  double accuracy;
  /**
   * Training epoch
   */
  uintptr_t epoch;
  /**
   * Generation number
   */
  uintptr_t generation;
  /**
   * Timestamp of last update (epoch seconds)
   */
  long last_updated;
  /**
   * Tags for categorization
   */
  char tags[4][MAX_TAG_LEN];
  /**
   * Number of active tags
   */
  uintptr_t tag_count;
} GardenPlot;

/**
 * Evolution entry — tracks one generation
 */
typedef struct EvolutionEntry {
  /**
   * Generation number
   */
  uintptr_t generation;
  /**
   * Operation that created this generation
   */
  enum EvolutionOp operation;
  /**
   * Population size
   */
  uintptr_t population_size;
  /**
   * Best fitness in this generation
   */
  double best_fitness;
  /**
   * Average fitness in this generation
   */
  double avg_fitness;
  /**
   * Worst fitness in this generation
   */
  double worst_fitness;
  /**
   * Diversity metric [0.0, 1.0]
   */
  double diversity;
  /**
   * Number of elites preserved
   */
  uintptr_t elites;
  /**
   * Timestamp (epoch seconds)
   */
  long timestamp;
} EvolutionEntry;

/**
 * Garden — top-level container for all plots
 */
typedef struct Garden {
  /**
   * Plots
   */
  struct GardenPlot plots[MAX_PLOTS];
  /**
   * Number of plots
   */
  uintptr_t plot_count;
  /**
   * Current generation
   */
  uintptr_t generation;
  /**
   * Best fitness across all plots
   */
  double best_fitness;
  /**
   * Average fitness across all plots
   */
  double avg_fitness;
  /**
   * Total number of seeds across all plots
   */
  uintptr_t total_seeds;
  /**
   * Evolution history
   */
  struct EvolutionEntry evolution[MAX_GENERATIONS];
  /**
   * Number of evolution entries
   */
  uintptr_t evolution_count;
} Garden;

/**
 * Seed — model initializer
 */
typedef struct Seed {
  /**
   * Seed name (null-terminated)
   */
  char name[MAX_NAME_LEN];
  /**
   * Seed type
   */
  enum SeedType seed_type;
  /**
   * Learning rate
   */
  double learning_rate;
  /**
   * Batch size
   */
  uintptr_t batch_size;
  /**
   * Number of layers
   */
  uintptr_t layers;
  /**
   * Hidden dimension
   */
  uintptr_t hidden_dim;
  /**
   * Dropout rate [0.0, 1.0]
   */
  double dropout;
  /**
   * Weight decay
   */
  double weight_decay;
  /**
   * Random seed for reproducibility
   */
  long rng_seed;
  /**
   * Whether this seed is active
   */
  bool active;
  /**
   * Initial fitness score
   */
  double initial_fitness;
} Seed;

/**
 * Growth record — a snapshot of training progress
 */
typedef struct GrowthRecord {
  /**
   * Epoch number
   */
  uintptr_t epoch;
  /**
   * Training loss
   */
  double train_loss;
  /**
   * Validation loss
   */
  double val_loss;
  /**
   * Training accuracy
   */
  double train_accuracy;
  /**
   * Validation accuracy
   */
  double val_accuracy;
  /**
   * Learning rate at this epoch
   */
  double learning_rate;
  /**
   * Time elapsed in ms
   */
  long elapsed_ms;
  /**
   * Memory usage in bytes
   */
  uintptr_t memory_bytes;
  /**
   * Growth phase at this epoch
   */
  enum GrowthPhase phase;
} GrowthRecord;

/**
 * Create a new empty garden
 */
struct Garden trios_garden_new(void);

/**
 * Add a plot to the garden
 */
bool trios_garden_add_plot(struct Garden *garden, struct GardenPlot plot);

/**
 * Recompute aggregate fitness metrics
 */
void trios_garden_recompute_fitness(struct Garden *garden);

/**
 * Create a new garden plot
 */
struct GardenPlot trios_garden_plot_new(const char *name, uintptr_t id);

/**
 * Update plot health based on metrics
 */
void trios_garden_plot_update_health(struct GardenPlot *plot);

/**
 * Advance plot to next growth phase
 */
enum GrowthPhase trios_garden_plot_advance_phase(struct GardenPlot *plot);

/**
 * Create a new seed with default hyperparameters
 */
struct Seed trios_garden_seed_new(const char *name, enum SeedType seed_type);

/**
 * Create a growth record from training metrics
 */
struct GrowthRecord trios_garden_growth_record(uintptr_t epoch,
                                               double train_loss,
                                               double val_loss,
                                               double train_accuracy,
                                               double val_accuracy,
                                               double learning_rate,
                                               long elapsed_ms);

/**
 * Determine growth phase from metrics
 */
enum GrowthPhase trios_garden_determine_phase(uintptr_t epoch,
                                              double val_accuracy,
                                              double val_loss);

/**
 * Record an evolution event
 */
bool trios_garden_record_evolution(struct Garden *garden,
                                   enum EvolutionOp operation,
                                   uintptr_t population_size,
                                   double best_fitness,
                                   double avg_fitness,
                                   double worst_fitness,
                                   double diversity,
                                   uintptr_t elites,
                                   long timestamp);

/**
 * Get the best plot by fitness
 */
uintptr_t trios_garden_best_plot(const struct Garden *garden);

/**
 * Cull plots below a fitness threshold — returns number culled
 */
uintptr_t trios_garden_cull(struct Garden *garden, double threshold);
