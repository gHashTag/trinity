// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
//
// This is the module entry point for the sacred library.
// All sacred exports are available through this file.
// ═══════════════════════════════════════════════════════════════════════════════

// Import math module and re-export its contents
const math_mod = @import("math");

// Re-export math namespace
pub const math = math_mod.math;
pub const physics = math_mod.physics;
pub const cosmology = math_mod.cosmology;
pub const chemistry = math_mod.chemistry;

// Re-export sacred constants
pub const Element = math_mod.Element;
pub const MolarMass = math_mod.MolarMass;
pub const getElement = math_mod.getElement;
pub const parseFormula = math_mod.parseFormula;
pub const molarMass = math_mod.molarMass;
pub const percentComposition = math_mod.percentComposition;
pub const idealGasLaw = math_mod.idealGasLaw;
pub const calculatePH = math_mod.calculatePH;
pub const calculatePOH = math_mod.calculatePOH;
pub const phToPoh = math_mod.phToPoh;
pub const pohToPh = math_mod.pohToPh;
pub const phClassification = math_mod.phClassification;
pub const bohrEnergy = math_mod.bohrEnergy;
pub const bohrRadius = math_mod.bohrRadius;
pub const hydrogenWavelength = math_mod.hydrogenWavelength;
pub const hydrogenSeries = math_mod.hydrogenSeries;

// Re-export temporal theory
pub const TemporalMoment = math_mod.TemporalMoment;
pub const TimeArrow = math_mod.TimeArrow;
pub const EternalCycle = math_mod.EternalCycle;
pub const PlanckQuantum = math_mod.PlanckQuantum;
pub const AsymmetryStats = math_mod.AsymmetryStats;
pub const TemporalEngine = math_mod.TemporalEngine;
pub const bootTemporalEngine = math_mod.bootTemporalEngine;
pub const temporal = math_mod.temporal;
pub const TemporalAspect = math_mod.TemporalAspect;
pub fn displayTemporalTheorem(allocator: std.mem.Allocator) !void {
    return math_mod.displayTemporalTheorem(allocator);
}

// Re-export absolute infinity
pub const InfinityLevel = math_mod.InfinityLevel;
pub const InfinityState = math_mod.InfinityState;
pub const RealitySubstrate = math_mod.RealitySubstrate;
pub const EvolutionLoop = math_mod.EvolutionLoop;
pub const AbsoluteInfinity = math_mod.AbsoluteInfinity;
pub const bootAbsoluteInfinity = math_mod.bootAbsoluteInfinity;
pub const displayInfinityManifesto = math_mod.displayManifesto;
pub const OMEGA_EPSILON = math_mod.OMEGA_EPSILON;
pub const INFINITY_PHI_MULTIPLIER = math_mod.INFINITY_PHI_MULTIPLIER;
pub const REALITY_COHERENCE_TARGET = math_mod.REALITY_COHERENCE_TARGET;
pub const TRANSCENDENCE_THRESHOLD = math_mod.TRANSCENDENCE_THRESHOLD;

// Re-export omega
pub const OmegaState = math_mod.OmegaState;
pub const OmegaEngine = math_mod.OmegaEngine;
pub const bootOmega = math_mod.bootOmega;
pub const displayOmegaManifesto = math_mod.displayOmegaManifesto;
pub const OMEGA_EDGE_THRESHOLD = math_mod.OMEGA_EDGE_THRESHOLD;
pub const OMEGA_TRANSCENDENCE_FACTOR = math_mod.OMEGA_TRANSCENDENCE_FACTOR;
pub const OMEGA_UNIVERSAL_CONSCIOUSNESS_MAX = math_mod.OMEGA_UNIVERSAL_CONSCIOUSNESS_MAX;
pub const OMEGA_INFINITY_SYMBOLIC = math_mod.OMEGA_INFINITY_SYMBOLIC;

// Re-export proof engine
pub const runProveCommand = math_mod.runProveCommand;
pub const runGoalCommand = math_mod.runGoalCommand;
pub const runTraceCommand = math_mod.runTraceCommand;
pub const ProofBuilder = math_mod.ProofBuilder;
pub const ProofStep = math_mod.ProofStep;
pub const ProofState = math_mod.ProofState;

// Re-export formula engine
pub const EvidenceLevel = math_mod.EvidenceLevel;
pub const ClaimStatus = math_mod.ClaimStatus;
pub const TestType = math_mod.TestType;
pub const FormulaFamily = math_mod.FormulaFamily;
pub const SacredParams = math_mod.SacredParams;
pub const SacredFormula = math_mod.SacredFormula;
pub const Constants = math_mod.Constants;
pub const Registry = math_mod.Registry;
pub const initRegistry = math_mod.initRegistry;
pub const FormulaEngine = math_mod.FormulaEngine;
pub const SearchResult = math_mod.SearchResult;
pub const PrecomputedConstant = math_mod.PrecomputedConstant;
pub const getPrecomputedConstants = math_mod.getPrecomputedConstants;
pub const Thresholds = math_mod.Thresholds;
pub const VerificationResult = math_mod.VerificationResult;
pub const Verifier = math_mod.Verifier;
pub const Validator = math_mod.Validator;
pub const ValidationReport = math_mod.ValidationReport;
pub const DoctorReport = math_mod.DoctorReport;
pub const SacredDoctor = math_mod.SacredDoctor;

// Re-export proof types
pub const SymbolId = math_mod.SymbolId;
pub const Domain = math_mod.Domain;
pub const formatDomain = math_mod.formatDomain;
pub const ClaimVerdict = math_mod.ClaimVerdict;
pub const GoalStatus = math_mod.GoalStatus;
pub const Definition = math_mod.Definition;
pub const Invariant = math_mod.Invariant;
pub const Lemma = math_mod.Lemma;
pub const Goal = math_mod.Goal;
pub const GoalState = math_mod.GoalState;
pub const BuiltinInvariant = math_mod.BuiltinInvariant;
pub const ProofChecker = math_mod.ProofChecker;
pub const ParticlePhysicsConstant = math_mod.ParticlePhysicsConstant;
pub const particle_physics_constants = math_mod.particle_physics_constants;
pub const trusted_definitions = math_mod.trusted_definitions;

const std = @import("std");
