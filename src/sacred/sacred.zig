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

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER THEORY LAYER — Q(√5) Field and Integer Lattice
// ═══════════════════════════════════════════════════════════════════════════════

pub const LatticePoint = sacred_math.LatticePoint;
pub const Q5Element = sacred_math.Q5Element;
pub const LogSpaceVector = sacred_math.LogSpaceVector;
pub const LatticeAnalysis = sacred_math.LatticeAnalysis;
pub const analyzeFormula = sacred_math.analyzeFormula;
pub const printLatticeView = sacred_math.printLatticeView;
pub const phiPowerQ5 = sacred_math.phiPowerQ5;
pub const normQ5 = sacred_math.normQ5;
pub const isTautology = sacred_math.isTautology;
pub const runLatticeViewCommand = sacred_math.runLatticeViewCommand;
pub const runLatticeDensityCommand = sacred_math.runLatticeDensityCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// NUMBER THEORY LAYER v2 — Blind Spot Analysis
// Four "blind spots": Schanuel's conjecture, numerology, Lindemann-Weierstrass, μ
// ═══════════════════════════════════════════════════════════════════════════════

// Algebraic status classification
pub const AlgebraicStatus = sacred_math.AlgebraicStatus;
pub const ConstantClassification = sacred_math.ConstantClassification;
pub const getClassifyConstants = sacred_math.getClassifyConstants;

// Transcendence certificate (Phase 2: most valuable for publication)
pub const TranscendenceCertificate = sacred_math.TranscendenceCertificate;
pub const transcendenceCert = sacred_math.transcendenceCert;

// Schanuel dependency tracking (Phase 3)
pub const SchanuelDependency = sacred_math.SchanuelDependency;
pub const analyzeSchanuelDependency = sacred_math.analyzeSchanuelDependency;

// Irrationality measure quality analysis (Phase 4)
pub const IrrationalityMeasure = sacred_math.IrrationalityMeasure;
pub const analyzeIrrationalityMeasure = sacred_math.analyzeIrrationalityMeasure;

// CLI commands for Number Theory Layer v2
pub const runClassifyConstantsCommand = sacred_math.runClassifyConstantsCommand;
pub const runTranscendenceCertCommand = sacred_math.runTranscendenceCertCommand;
pub const runSchanuelAuditCommand = sacred_math.runSchanuelAuditCommand;
pub const runIrrationalityMeasureCommand = sacred_math.runIrrationalityMeasureCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// BLIND SPOTS — Cosmological Evolution and Statistical Tests
// ═══════════════════════════════════════════════════════════════════════════════

// Look-elsewhere test (Blind Spot 2)
pub const LookElsewhereResult = sacred_math.LookElsewhereResult;
pub const runLookElsewhereTest = sacred_math.runLookElsewhereTest;
pub const runLookElsewhereCommand = sacred_math.runLookElsewhereCommand;

// Bayesian posterior (Blind Spot 3)
pub const BayesianPosterior = sacred_math.BayesianPosterior;
pub const computeBayesianPosterior = sacred_math.computeBayesianPosterior;
pub const runBayesianCommand = sacred_math.runBayesianCommand;

// Hubble tension (Blind Spot 4)
pub const HubbleTensionResult = sacred_math.HubbleTensionResult;
pub const computeHubbleTension = sacred_math.computeHubbleTension;
pub const runHubbleTensionCommand = sacred_math.runHubbleTensionCommand;

// Baryon gap (Blind Spot 5)
pub const BaryonGapResult = sacred_math.BaryonGapResult;
pub const analyzeBaryonGap = sacred_math.analyzeBaryonGap;
pub const runBaryonGapCommand = sacred_math.runBaryonGapCommand;

// Mass audit combined discovery
pub const CombinedDiscoveryResult = sacred_math.CombinedDiscoveryResult;
pub const analyzeCombinedDiscoveries = sacred_math.analyzeCombinedDiscoveries;
pub const runCombinedDiscoveryCommand = sacred_math.runCombinedDiscoveryCommand;

// Continued fraction analysis (Priority 1 Blind Spot)
pub const CFracAnalysisResult = sacred_math.CFracAnalysisResult;
pub const analyzeContinuedFraction = sacred_math.analyzeContinuedFraction;
pub const runCFracCommand = sacred_math.runCFracCommand;

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

// ═══════════════════════════════════════════════════════════════════════════════
// PALANTIR PIPELINE v1.1 — Continued Fraction Analysis (6 Stages)
// Consolidated implementation in cfrac_palantir.zig
// ═══════════════════════════════════════════════════════════════════════════════

// Import Palantir consolidated module
const cfrac_palantir = @import("cfrac_palantir.zig");

// Re-export types (v1.1 adds irrationality_mu to CFStats)
pub const CFStats = cfrac_palantir.CFStats;
pub const Convergent = cfrac_palantir.Convergent;
pub const PrimeFactorization = cfrac_palantir.PrimeFactorization;
pub const PrimeFactor = cfrac_palantir.PrimeFactor;

// Re-export command functions
pub const runCFracExpandCommand = cfrac_palantir.runCFracExpandCommand;
pub const runCFracStatsCommand = cfrac_palantir.runCFracStatsCommand;
pub const runCFracCompareCommand = cfrac_palantir.runCFracCompareCommand;
pub const runCFracApproxCommand = cfrac_palantir.runCFracApproxCommand;
pub const runCFracDetectCommand = cfrac_palantir.runCFracDetectCommand;
pub const runCFracVerdictCommand = cfrac_palantir.runCFracVerdictCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// COSMOLOGY LAYER — DESI DR2 w(z) Analysis
// Testing w₀ = -1 + γ = -0.764 against DESI BAO data
// ═══════════════════════════════════════════════════════════════════════════════

// Import cosmology DESI module
const cosmology_desi = @import("desi_wz.zig");

// Re-export DESI types and functions
pub const cosmology_desi_wz = cosmology_desi;

pub const BAODataPoint = cosmology_desi.BAODataPoint;
pub const WParams = cosmology_desi.WParams;
pub const Chi2Result = cosmology_desi.Chi2Result;

// DESI constants
pub const c = cosmology_desi.c;
pub const H0_base = cosmology_desi.H0_base;
pub const Omega_m_base = cosmology_desi.Omega_m_base;
pub const gamma_trinity = cosmology_desi.gamma_trinity;
pub const w0_trinity = cosmology_desi.w0_trinity;

// DESI data
pub const desi_dr2_bao = cosmology_desi.desi_dr2_bao;
pub const DESI_BEST_FIT = cosmology_desi.DESI_BEST_FIT;
pub const DESI_UNCERTAINTY = cosmology_desi.DESI_UNCERTAINTY;
pub const TRINITY_PREDICTION = cosmology_desi.TRINITY_PREDICTION;

// CPL functions
pub const w_CPL = cosmology_desi.w_CPL;
pub const f_DE = cosmology_desi.f_DE;
pub const E_z = cosmology_desi.E_z;
pub const comoving_distance = cosmology_desi.comoving_distance;
pub const D_M = cosmology_desi.D_M;
pub const D_H = cosmology_desi.D_H;
pub const F_AP = cosmology_desi.F_AP;

// Analysis functions
pub const compute_bao_chi2 = cosmology_desi.compute_bao_chi2;
pub const compare_trinity_vs_lcdm = cosmology_desi.compare_trinity_vs_lcdm;
pub const sigmaDeviation = cosmology_desi.sigmaDeviation;
pub const honestComparison = cosmology_desi.honestComparison;

// ═══════════════════════════════════════════════════════════════════════════════
// DEGENERACY TEST — Blind Spot #1: Is Ω_DM = φ²/π² unique?
// ═══════════════════════════════════════════════════════════════════════════════

// Import degeneracy module
const degeneracy_module = @import("degeneracy.zig");

// Re-export degeneracy types and functions
pub const FormulaParams = degeneracy_module.FormulaParams;
pub const FormulaHit = degeneracy_module.FormulaHit;
pub const DegeneracyResult = degeneracy_module.DegeneracyResult;
pub const computeV = degeneracy_module.computeV;
pub const generateFormulas = degeneracy_module.generateFormulas;
pub const runDegeneracyTest = degeneracy_module.runDegeneracyTest;
pub const runDegeneracyCommand = degeneracy_module.runDegeneracyCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// V_CB TENSION TEST — Blind Spot #2: Inclusive vs Exclusive
// ═══════════════════════════════════════════════════════════════════════════════

// Import V_cb tension module
const vcb_tension_module = @import("vcb_tension.zig");

// Re-export V_cb tension types and functions
pub const VcbMethod = vcb_tension_module.VcbMethod;
pub const TensionResult = vcb_tension_module.TensionResult;
pub const runVcbTensionTest = vcb_tension_module.runVcbTensionTest;
pub const runVcbTensionCommand = vcb_tension_module.runVcbTensionCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// PSLQ TEST — Blind Spot #4: Is Ω_Λ formula unique?
// ═══════════════════════════════════════════════════════════════════════════════

// Import PSLQ module
const pslq_module = @import("pslq_omega.zig");

// Re-export PSLQ types and functions
pub const PslqRelation = pslq_module.PslqRelation;
pub const PslqResult = pslq_module.PslqResult;
pub const runPslqTest = pslq_module.runPslqTest;
pub const runPslqCommand = pslq_module.runPslqCommand;

// ═══════════════════════════════════════════════════════════════════════════════
// ZETA ANALYSIS — Session 9: Riemann Hypothesis via Continued Fractions
// ═══════════════════════════════════════════════════════════════════════════════

// Import Zeta command module
const zeta_commands = @import("zeta_commands.zig");

// Re-export Zeta command functions
pub const runZetaCommand = zeta_commands.runZetaCommand;
pub const runZetaImportCommand = zeta_commands.runZetaImportCommand;
pub const runZetaSpacingCommand = zeta_commands.runZetaSpacingCommand;
pub const runZetaCFCommand = zeta_commands.runZetaCFCommand;
pub const runZetaPSLQCommand = zeta_commands.runZetaPSLQCommand;
pub const runZetaVerdictCommandDirect = zeta_commands.runZetaVerdictCommandDirect;

// Re-export Zeta types
pub const ZerosData = zeta_commands.ZerosData;
pub const Spacings = zeta_commands.Spacings;
pub const ZetaCFResult = zeta_commands.ZetaCFResult;
pub const ZetaVerdict = zeta_commands.ZetaVerdict;
pub const PSLQSearchResult = zeta_commands.PSLQSearchResult;
