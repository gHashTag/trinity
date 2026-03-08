// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

// Import sacred math for re-export (provided as module import in build.zig)
const sacred_math = @import("math.zig");

// Export all sacred constants
pub const math = sacred_math.math;
pub const physics = sacred_math.physics;
pub const cosmology = sacred_math.cosmology;
pub const chemistry = sacred_math.chemistry;

// Export commonly-used constants directly
pub const PHI = sacred_math.math.PHI;
pub const PI = sacred_math.math.PI;
pub const E = sacred_math.math.E;
pub const TRINITY = 3.0;

// Export chemistry types and functions
pub const Element = sacred_math.Element;
pub const getElement = sacred_math.getElement;
pub const parseFormula = sacred_math.parseFormula;
pub const molarMass = sacred_math.molarMass;
pub const percentComposition = sacred_math.percentComposition;
pub const idealGasLaw = sacred_math.idealGasLaw;
pub const calculatePH = sacred_math.calculatePH;
pub const calculatePOH = sacred_math.calculatePOH;
pub const phToPoh = sacred_math.phToPoh;
pub const pohToPh = sacred_math.pohToPh;
pub const phClassification = sacred_math.phClassification;
pub const bohrEnergy = sacred_math.bohrEnergy;
pub const bohrRadius = sacred_math.bohrRadius;
pub const hydrogenWavelength = sacred_math.hydrogenWavelength;
pub const hydrogenSeries = sacred_math.hydrogenSeries;
pub const AVOGADRO = sacred_math.AVOGADRO;
pub const GAS_CONSTANT = sacred_math.GAS_CONSTANT;
pub const FARADAY = sacred_math.FARADAY;
pub const PERIODIC_TABLE = sacred_math.PERIODIC_TABLE;

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF GRAPH ENGINE v1.0 — Evidence-Native Proof Assistant
// ═══════════════════════════════════════════════════════════════════════════════

// Re-export proof types
pub const SymbolId = sacred_math.SymbolId;
pub const Domain = sacred_math.Domain;
pub const formatDomain = sacred_math.formatDomain;
pub const ClaimVerdict = sacred_math.ClaimVerdict;
pub const GoalStatus = sacred_math.GoalStatus;
pub const Definition = sacred_math.Definition;
pub const Invariant = sacred_math.Invariant;
pub const Lemma = sacred_math.Lemma;
pub const ProofStep = sacred_math.ProofStep;
pub const Goal = sacred_math.Goal;
pub const GoalState = sacred_math.GoalState;
pub const BuiltinInvariant = sacred_math.BuiltinInvariant;
pub const ProofChecker = sacred_math.ProofChecker;

// Registry types
pub const EvidenceLevel = sacred_math.EvidenceLevel;
pub const ClaimStatus = sacred_math.ClaimStatus;
pub const SacredFormula = sacred_math.SacredFormula;
pub const Registry = sacred_math.Registry;

// Proof builder
pub const ProofBuilder = sacred_math.ProofBuilder;
pub const runProveCommand = sacred_math.runProveCommand;
pub const runGoalCommand = sacred_math.runGoalCommand;
pub const runTraceCommand = sacred_math.runTraceCommand;
pub const runDoctorCommand = sacred_math.runDoctorCommand;
pub const runAuditMismatchCommand = sacred_math.runAuditMismatchCommand;
pub const runFitOriginCommand = sacred_math.runFitOriginCommand;
pub const runCanonicalIntegrityCheck = sacred_math.runCanonicalIntegrityCheck;
pub const runAuditUnspecifiedCommand = sacred_math.runAuditUnspecifiedCommand;
pub const runSearchCanonicalCommand = sacred_math.runSearchCanonicalCommand;

// Research cycle types
pub const CrossDomainInvariant = sacred_math.CrossDomainInvariant;
pub const GammaDependency = sacred_math.GammaDependency;
pub const GammaDomainMetrics = sacred_math.GammaDomainMetrics;
pub const PredictionFormula = sacred_math.PredictionFormula;
pub const PredictionStatus = sacred_math.PredictionStatus;
pub const FalsificationTrigger = sacred_math.FalsificationTrigger;
pub const TriggerType = sacred_math.TriggerType;
pub const FalsificationScenarios = sacred_math.FalsificationScenarios;

// Particle physics data
pub const ParticlePhysicsConstant = sacred_math.ParticlePhysicsConstant;
pub const particle_physics_constants = sacred_math.particle_physics_constants;
pub const trusted_definitions = sacred_math.trusted_definitions;
