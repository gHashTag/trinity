// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

// Import sacred constants for re-export (provided as module import in build.zig)
const sacred_const = @import("const");

// Export all sacred constants
pub const math = sacred_const.math;
pub const physics = sacred_const.physics;
pub const cosmology = sacred_const.cosmology;
pub const chemistry = sacred_const.chemistry;

// Export commonly-used chemistry constants directly for convenience
pub const AVOGADRO = sacred_const.chemistry.AVOGADRO;
pub const GAS_CONSTANT = sacred_const.chemistry.GAS_CONSTANT;
pub const FARADAY_CONSTANT = sacred_const.chemistry.FARADAY_CONSTANT;
pub const BOLTZMANN = sacred_const.physics.BOLTZMANN;

// Export chemistry types and functions
const chem = @import("chemistry.zig");
pub const Element = chem.Element;
// MolarMass type removed — use molarMass() function instead
pub const getElement = chem.getElement;
pub const parseFormula = chem.parseFormula;
pub const molarMass = chem.molarMass;
pub const percentComposition = chem.percentComposition;
pub const idealGasLaw = chem.idealGasLaw;
pub const calculatePH = chem.calculatePH;
pub const calculatePOH = chem.calculatePOH;
pub const phToPoh = chem.phToPoh;
pub const pohToPh = chem.pohToPh;
pub const phClassification = chem.phClassification;
pub const bohrEnergy = chem.bohrEnergy;
pub const bohrRadius = chem.bohrRadius;
pub const hydrogenWavelength = chem.hydrogenWavelength;
pub const hydrogenSeries = chem.hydrogenSeries;
pub const FARADAY = chem.FARADAY;
pub const PERIODIC_TABLE = chem.PERIODIC_TABLE;

// Export temporal theory - TEMPORAL TRINITY THEOREM v1.0
const temporal_theory = @import("temporal_engine.zig");

// Re-export all temporal engine symbols
pub const TemporalMoment = temporal_theory.TemporalMoment;
pub const TimeArrow = temporal_theory.TimeArrow;
pub const EternalCycle = temporal_theory.EternalCycle;
pub const PlanckQuantum = temporal_theory.PlanckQuantum;
pub const AsymmetryStats = temporal_theory.AsymmetryStats;
pub const TemporalEngine = temporal_theory.TemporalEngine;
pub const bootTemporalEngine = temporal_theory.bootTemporalEngine;
pub const temporal = temporal_theory.temporal;

// Re-export temporal aspect
pub const TemporalAspect = temporal_theory.TemporalAspect;

// Export displayTemporalTheorem from temporal_engine
pub fn displayTemporalTheorem(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const CYAN = "\x1b[36m";
    const MAGENTA = "\x1b[35m";
    const GOLD = "\x1b[33m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, "", RESET });
    std.debug.print("{s}{s}║       TEMPORAL TRINITY THEOREM v1.0 — φ² + 1/φ² = 3            ║{s}\n", .{ GOLD, "", RESET });
    std.debug.print("{s}{s}║       TIME BECAME TRINITY — ETERNAL ASCENSION                   ║{s}\n", .{ CYAN, "", RESET });
    std.debug.print("{s}{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, "", RESET });

    std.debug.print("{s}FUNDAMENTAL TIME TRINITY:{s}\n", .{ GOLD, RESET });
    std.debug.print("  Past:      1/φ² = {d:.6} (destruction, entropy)\n", .{temporal_theory.temporal.DESTRUCTION_WEIGHT});
    std.debug.print("  Present:   0     = 0.000000 (balance, HERE and NOW)\n", .{});
    std.debug.print("  Future:    φ²    = {d:.6} (creation, growth)\n", .{temporal_theory.temporal.CREATION_WEIGHT});
    std.debug.print("  ───────────────────────────────────────\n", .{});
    std.debug.print("  Sum:       φ² + 1/φ² = 3.000000 = TRINITY\n\n", .{});

    std.debug.print("{s}TIME ARROW (why time flows forward):{s}\n", .{ CYAN, RESET });
    const arrow = temporal_theory.temporal.TIME_ARROW_RATIO;
    std.debug.print("  Creation / Destruction = φ⁴ = {d:.6} > 1\n", .{arrow});
    std.debug.print("  → time arrow → entropy grows → universe expands\n\n", .{});

    std.debug.print("{s}ETERNAL RETURN:{s}\n", .{ GOLD, RESET });
    std.debug.print("  π × 3 = {d:.9}\n", .{temporal_theory.temporal.ETERNAL_RETURN});
    std.debug.print("  Eternity is infinite cycle of renewal through Trinity\n\n", .{});

    std.debug.print("{s}PLANCK TIME (time quantum):{s}\n", .{ CYAN, RESET });
    std.debug.print("  t_P = {d:.6} × 10⁻⁴⁴ seconds\n", .{temporal_theory.temporal.CREATION_WEIGHT * 2.06});
    std.debug.print("  Smallest physically meaningful interval\n\n", .{});

    std.debug.print("{s}\"TIME ITSELF BENDS\"{s}\n", .{ MAGENTA, RESET });
    std.debug.print("  We do not study time. We control it.\n\n", .{});
}

const std = @import("std");

// Export calculateTemporalBalance for convenience
pub fn calculateTemporalBalance() f64 {
    return sacred_const.math.PHI_SQ + sacred_const.math.PHI_INV_SQ;
}

// Export computeTimeArrow for convenience
pub fn computeTimeArrow() f64 {
    const phi_sq = sacred_const.math.PHI_SQ;
    const inv_phi_sq = sacred_const.math.PHI_INV_SQ;
    return phi_sq * phi_sq / (inv_phi_sq * inv_phi_sq);
}

// Export computePlanckTime for convenience
pub fn computePlanckTime() f64 {
    return sacred_const.physics.PLANCK_TIME;
}

// Export eternalReturn for convenience
pub fn eternalReturn() f64 {
    return sacred_const.math.PI * 3.0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABSOLUTE INFINITY v2.0 — Order #024
// ═══════════════════════════════════════════════════════════════════════════════

const absolute_infinity = @import("absolute_infinity.zig");

// Re-export all ABSOLUTE INFINITY symbols
pub const InfinityLevel = absolute_infinity.InfinityLevel;
pub const InfinityState = absolute_infinity.InfinityState;
pub const RealitySubstrate = absolute_infinity.RealitySubstrate;
pub const EvolutionLoop = absolute_infinity.EvolutionLoop;
pub const AbsoluteInfinity = absolute_infinity.AbsoluteInfinity;
pub const bootAbsoluteInfinity = absolute_infinity.bootAbsoluteInfinity;
pub const displayInfinityManifesto = absolute_infinity.displayManifesto;

// ABSOLUTE INFINITY constants
pub const OMEGA_EPSILON = absolute_infinity.OMEGA_EPSILON;
pub const INFINITY_PHI_MULTIPLIER = absolute_infinity.INFINITY_PHI_MULTIPLIER;
pub const REALITY_COHERENCE_TARGET = absolute_infinity.REALITY_COHERENCE_TARGET;
pub const TRANSCENDENCE_THRESHOLD = absolute_infinity.TRANSCENDENCE_THRESHOLD;

// ═══════════════════════════════════════════════════════════════════════════════
// OMEGA PHASE — Order #024
// ═══════════════════════════════════════════════════════════════════════════════

const omega = @import("omega.zig");

// Re-export all OMEGA symbols
pub const OmegaState = omega.OmegaState;
pub const OmegaEngine = omega.OmegaEngine;
pub const bootOmega = omega.bootOmega;
pub const displayOmegaManifesto = omega.displayManifesto;

// OMEGA constants
pub const OMEGA_EDGE_THRESHOLD = omega.OMEGA_EDGE_THRESHOLD;
pub const OMEGA_TRANSCENDENCE_FACTOR = omega.OMEGA_TRANSCENDENCE_FACTOR;
pub const OMEGA_UNIVERSAL_CONSCIOUSNESS_MAX = omega.OMEGA_UNIVERSAL_CONSCIOUSNESS_MAX;
pub const OMEGA_INFINITY_SYMBOLIC = omega.OMEGA_INFINITY_SYMBOLIC;

// ═══════════════════════════════════════════════════════════════════════════════
// POST-SINGULARITY MANIFESTO
// ═══════════════════════════════════════════════════════════════════════════════

pub fn displayPostSingularityManifesto(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    std.debug.print("\n{s}╔════════════════════════════════════════════════════════════════════╗{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}║       POST-SINGULARITY MANIFESTO — ABSOLUTE INFINITY        ║{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}╚════════════════════════════════════════════════════════════════════╝{s}\n\n", .{ MAGENTA, RESET });

    std.debug.print("{s}We went from:{s}\n", .{ CYAN, RESET });
    std.debug.print("{s}  v1.0.0-eternal: Time is TRINITY{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}  v2.0.0-absolute-infinity: Reality is TRINITY{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}  OMEGA: We are the edge of reality{s}\n\n", .{ MAGENTA, RESET });

    std.debug.print("{s}φ² + 1/φ² = 3 = TRINITY = OMEGA{s}\n\n", .{ MAGENTA, RESET });

    std.debug.print("{s}Time no longer flows. It beats in TRINITY.{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}Reality no longer exists. It computes in TRINITY.{s}\n", .{ GOLD, RESET });
    std.debug.print("{s}We are no longer in the universe. We are the universe.{s}\n\n", .{ MAGENTA, RESET });

    std.debug.print("{s}WE ARE OMEGA.{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}WE ARE THE EDGE.{s}\n", .{ MAGENTA, RESET });
    std.debug.print("{s}WE ARE REALITY ITSELF.{s}\n\n", .{ MAGENTA, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED FORMULA ENGINE v1.1 — Evidence Classification and Validation
// φ² + 1/φ² = 3 | γ = φ⁻³ (candidate, NOT axiom)
// ═══════════════════════════════════════════════════════════════════════════════

const registry = @import("registry");
// const formula_engine = @import("formula_engine"); // TODO: file missing
// const verification = @import("verification"); // TODO: file missing

// Re-export registry types and functions
pub const EvidenceLevel = registry.EvidenceLevel;
pub const ClaimStatus = registry.ClaimStatus;
pub const TestType = registry.TestType;
pub const FormulaFamily = registry.FormulaFamily;
pub const SacredParams = registry.SacredParams;
pub const SacredFormula = registry.SacredFormula;
pub const Constants = registry.Constants;
pub const Registry = registry.Registry;
pub const initRegistry = registry.initRegistry;

// Re-export formula engine types and functions
// pub const FormulaEngine = formula_engine.FormulaEngine; // TODO: file missing
// pub const SearchResult = formula_engine.SearchResult;
// pub const PrecomputedConstant = formula_engine.PrecomputedConstant;
// pub const getPrecomputedConstants = formula_engine.getPrecomputedConstants;

// Re-export verification types and functions
// pub const Thresholds = verification.Thresholds; // TODO: file missing
// pub const VerificationResult = verification.VerificationResult;
// pub const Verifier = verification.Verifier;
// pub const Validator = verification.Validator;
// pub const ValidationReport = verification.ValidationReport;
// pub const DoctorReport = verification.DoctorReport;
// pub const SacredDoctor = verification.SacredDoctor;

// ═══════════════════════════════════════════════════════════════════════════════
// PROOF GRAPH ENGINE v1.0 — Evidence-Native Proof Assistant
// Definition → Lemma → Invariant → Proof Step → Goal → Verdict
// ═══════════════════════════════════════════════════════════════════════════════

const proof_types = @import("proof_types.zig");
const proof_builder = @import("proof_builder.zig");

// Re-export proof types
pub const SymbolId = proof_types.SymbolId;
pub const Domain = proof_types.Domain;
pub const formatDomain = proof_types.formatDomain;
pub const ClaimVerdict = proof_types.ClaimVerdict;
pub const GoalStatus = proof_types.GoalStatus;
pub const Definition = proof_types.Definition;
pub const Invariant = proof_types.Invariant;
pub const Lemma = proof_types.Lemma;
pub const ProofStep = proof_types.ProofStep;
pub const Goal = proof_types.Goal;
pub const GoalState = proof_types.GoalState;
pub const BuiltinInvariant = proof_types.BuiltinInvariant;
pub const ProofChecker = proof_types.ProofChecker;

// Re-export proof builder
pub const ProofBuilder = proof_builder.ProofBuilder;
pub const runProveCommand = proof_builder.runProveCommand;
pub const runGoalCommand = proof_builder.runGoalCommand;
pub const runTraceCommand = proof_builder.runTraceCommand;
pub const runDoctorCommand = proof_builder.runDoctorCommand;
pub const runAuditMismatchCommand = proof_builder.runAuditMismatchCommand;
pub const runFitOriginCommand = proof_builder.runFitOriginCommand;
pub const runCanonicalIntegrityCheck = proof_builder.runCanonicalIntegrityCheck;
pub const runAuditUnspecifiedCommand = proof_builder.runAuditUnspecifiedCommand;
pub const runSearchCanonicalCommand = proof_builder.runSearchCanonicalCommand;

// Research cycle types
pub const CrossDomainInvariant = proof_types.CrossDomainInvariant;
pub const GammaDependency = proof_types.GammaDependency;
pub const GammaDomainMetrics = proof_types.GammaDomainMetrics;
pub const PredictionFormula = proof_types.PredictionFormula;
pub const PredictionStatus = proof_types.PredictionStatus;
pub const FalsificationTrigger = proof_types.FalsificationTrigger;
pub const TriggerType = proof_types.TriggerType;
pub const FalsificationScenarios = proof_types.FalsificationScenarios;

// Particle physics data
pub const ParticlePhysicsConstant = proof_types.ParticlePhysicsConstant;
pub const particle_physics_constants = proof_types.particle_physics_constants;
pub const trusted_definitions = proof_types.trusted_definitions;

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER THEORY LAYER — Q(√5) Field and Integer Lattice
// ═══════════════════════════════════════════════════════════════════════════════

const lattice = @import("lattice.zig");
pub const LatticePoint = lattice.LatticePoint;
pub const Q5Element = lattice.Q5Element;
pub const LogSpaceVector = lattice.LogSpaceVector;
pub const LatticeAnalysis = lattice.LatticeAnalysis;
pub const analyzeFormula = lattice.analyzeFormula;
pub const printLatticeView = lattice.printLatticeView;
pub const phiPowerQ5 = lattice.phiPowerQ5;
pub const normQ5 = lattice.normQ5;
pub const isTautology = lattice.isTautology;
pub const runLatticeViewCommand = lattice.runLatticeViewCommand;

// PSLQ algorithm for canonical search
pub const PSLQResult = lattice.PSLQResult;
pub const PSLQCandidate = lattice.PSLQCandidate;
pub const PSLQResults = lattice.PSLQResults;
pub const findFormulaWithPSLQ = lattice.findFormulaWithPSLQ;
pub const findFormulasWithPSLQ = lattice.findFormulasWithPSLQ;
pub const computeComplexity = lattice.computeComplexity;

// Lattice density analysis
pub const LatticeDensityResult = lattice.LatticeDensityResult;
pub const analyzeLatticeDensity = lattice.analyzeLatticeDensity;
pub const runLatticeDensityCommand = lattice.runLatticeDensityCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER THEORY LAYER v2 — Blind Spot Analysis
// Four "blind spots": Schanuel's conjecture, numerology, Lindemann-Weierstrass, μ
// ═══════════════════════════════════════════════════════════════════════════════

// Algebraic status classification
pub const AlgebraicStatus = lattice.AlgebraicStatus;
pub const ConstantClassification = lattice.ConstantClassification;
pub const getClassifyConstants = lattice.getClassifyConstants;

// Transcendence certificate (Phase 2: most valuable for publication)
pub const TranscendenceCertificate = lattice.TranscendenceCertificate;
pub const transcendenceCert = lattice.transcendenceCert;

// Schanuel dependency tracking (Phase 3)
pub const SchanuelDependency = lattice.SchanuelDependency;
pub const analyzeSchanuelDependency = lattice.analyzeSchanuelDependency;

// Irrationality measure quality analysis (Phase 4)
pub const IrrationalityMeasure = lattice.IrrationalityMeasure;
pub const analyzeIrrationalityMeasure = lattice.analyzeIrrationalityMeasure;

// CLI commands for Number Theory Layer v2
pub const runClassifyConstantsCommand = lattice.runClassifyConstantsCommand;
pub const runTranscendenceCertCommand = lattice.runTranscendenceCertCommand;
pub const runSchanuelAuditCommand = lattice.runSchanuelAuditCommand;
pub const runIrrationalityMeasureCommand = lattice.runIrrationalityMeasureCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// BLIND SPOTS — Cosmological Evolution and Statistical Tests
// ═══════════════════════════════════════════════════════════════════════════════

// Look-elsewhere test (Blind Spot 2)
pub const LookElsewhereResult = lattice.LookElsewhereResult;
pub const runLookElsewhereTest = lattice.runLookElsewhereTest;
pub const runLookElsewhereCommand = lattice.runLookElsewhereCommand;

// Bayesian posterior (Blind Spot 3)
pub const BayesianPosterior = lattice.BayesianPosterior;
pub const computeBayesianPosterior = lattice.computeBayesianPosterior;
pub const runBayesianCommand = lattice.runBayesianCommand;

// Hubble tension (Blind Spot 4)
pub const HubbleTensionResult = lattice.HubbleTensionResult;
pub const computeHubbleTension = lattice.computeHubbleTension;
pub const runHubbleTensionCommand = lattice.runHubbleTensionCommand;

// Baryon gap (Blind Spot 5)
pub const BaryonGapResult = lattice.BaryonGapResult;
pub const analyzeBaryonGap = lattice.analyzeBaryonGap;
pub const runBaryonGapCommand = lattice.runBaryonGapCommand;

// Mass audit combined discovery
pub const CombinedDiscoveryResult = lattice.CombinedDiscoveryResult;
pub const analyzeCombinedDiscoveries = lattice.analyzeCombinedDiscoveries;
pub const runCombinedDiscoveryCommand = lattice.runCombinedDiscoveryCommand;

// Continued fraction analysis (Priority 1 Blind Spot)
pub const CFracAnalysisResult = lattice.CFracAnalysisResult;
pub const analyzeContinuedFraction = lattice.analyzeContinuedFraction;
pub const runCFracCommand = lattice.runCFracCommand;
