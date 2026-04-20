//! Multi-objective training: NTP, JEPA, NCA, hybrid
//!
//! Research: EXP-012 to EXP-025, evolution_simulation.zig scenarios

// ============================================================================
// Training Objectives
// ============================================================================

/// Training objective type
///
/// Defines what loss function to optimize.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Objective {
    /// Next Token Prediction (baseline NTP)
    Ntp,

    /// T-JEPA only (embedding prediction)
    Jepa,

    /// NCA pre-pre-training → NTP
    ///
    /// NCA 15K steps → NTP fine-tuning.
    NcaNtp,

    /// NCA 15K → JEPA 40K → NTP
    ///
    /// V1: 15K NCA, 40K JEPA, then NTP.
    NcaJepaNtp,

    /// NCA 15K → JEPA 20K → NTP (faster)
    ///
    /// V2: 15K NCA, 20K JEPA, then NTP.
    NcaJepaNtpV2,

    /// Hybrid: 3-way training (ntp + jepa + nca-ntp)
    ///
    /// W8-hybrid objective.
    Hybrid,
}

impl Default for Objective {
    fn default() -> Self {
        Self::Ntp  // Baseline: next token prediction
    }
}

impl std::fmt::Display for Objective {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Self::Ntp => write!(f, "ntp"),
            Self::Jepa => write!(f, "jepa"),
            Self::NcaNtp => write!(f, "nca-ntp"),
            Self::NcaJepaNtp => write!(f, "nca-jepa-ntp"),
            Self::NcaJepaNtpV2 => write!(f, "nca-jepa-ntp-v2"),
            Self::Hybrid => write!(f, "hybrid"),
        }
    }
}

impl Objective {
    /// Get human-readable description for this objective
    pub fn description(&self) -> &'static str {
        match self {
            Self::Ntp => "Next Token Prediction (baseline NTP)",
            Self::Jepa => "Ternary Joint-Embedding Predictive Architecture",
            Self::NcaNtp => "NCA pre-pre-training → NTP",
            Self::NcaJepaNtp => "NCA 15K → JEPA 40K → NTP",
            Self::NcaJepaNtpV2 => "NCA 15K → JEPA 20K → NTP (faster)",
            Self::Hybrid => "3-way hybrid (ntp + jepa + nca-ntp)",
        }
    }
}

// ============================================================================
// Objective Weights (for Hybrid Training)
// ============================================================================

/// Objective weights for hybrid training
///
/// Controls contribution of each loss to total loss.
#[derive(Debug, Clone, Copy)]
pub struct ObjectiveWeights {
    /// Next Token Prediction weight
    pub ntp: f32,

    /// T-JEPA weight
    pub jepa: f32,

    /// NCA-NTP weight
    pub nca_ntp: f32,
}

impl Default for ObjectiveWeights {
    fn default() -> Self {
        Self {
            ntp: 0.50,  // 50% weight
            jepa: 0.25,  // 25% weight
            nca_ntp: 0.25,  // 25% weight
        }
    }
}

impl ObjectiveWeights {
    /// Check if weights sum to 1.0
    pub fn is_normalized(&self) -> bool {
        let sum = self.ntp + self.jepa + self.nca_ntp;
        (sum - 1.0).abs() < 1e-6
    }

    /// Normalize weights to sum to 1.0
    pub fn normalize(&mut self) {
        let sum = self.ntp + self.jepa + self.nca_ntp;
        if sum > 0.0 {
            self.ntp /= sum;
            self.jepa /= sum;
            self.nca_ntp /= sum;
        }
    }

    /// Get weights for a specific objective
    pub fn for_objective(&self, obj: Objective) -> Option<(f32, f32, f32)> {
        match obj {
            Objective::Ntp => Some((1.0, 0.0, 0.0)),
            Objective::Jepa => Some((0.0, 1.0, 0.0)),
            Objective::NcaNtp => Some((1.0, 0.0, 0.0)),
            Objective::NcaJepaNtp => Some((0.0, 1.0, 0.0)),
            Objective::NcaJepaNtpV2 => Some((0.0, 1.0, 0.0)),
            Objective::Hybrid => Some((self.ntp, self.jepa, self.nca_ntp)),
        }
    }
}

// ============================================================================
// Training Scenario (Simulation Scenarios S1-S10)
// ============================================================================

/// Training scenario from evolution_simulation.zig
///
/// Defines crash rate, byzantine rate, and microglia interval.
#[derive(Debug, Clone)]
pub struct TrainingScenario {
    /// Training objectives (weights for hybrid)
    pub objectives: ObjectiveWeights,

    /// Token crash rate (0.10 default)
    pub crash_rate: f32,

    /// Byzantine (adversarial) rate (0.05 default)
    pub byzantine_rate: f32,

    /// Microglia immunity interval (0 = no immunity)
    ///
    /// 30 = immunity every 30 tokens.
    pub microglia_interval: u32,
}

impl Default for TrainingScenario {
    fn default() -> Self {
        Self {
            objectives: ObjectiveWeights::default(),
            crash_rate: 0.10,
            byzantine_rate: 0.05,
            microglia_interval: 30,
        }
    }
}

/// S4 dePIN (Byzantine + Microglia)
///
/// Evolution scenario S4: multi-objective with immunity.
pub fn scenario_s4() -> TrainingScenario {
    TrainingScenario {
        objectives: ObjectiveWeights::default(),  // ntp=0.50, jepa=0.25, nca-ntp=0.25
        crash_rate: 0.10,
        byzantine_rate: 0.05,
        microglia_interval: 30,  // Microglia immunity
    }
}

/// S5 dePIN NoImmunity (Byzantine only)
///
/// Evolution scenario S5: multi-objective without immunity.
pub fn scenario_s5() -> TrainingScenario {
    TrainingScenario {
        objectives: ObjectiveWeights::default(),  // ntp=0.50, jepa=0.25, nca-ntp=0.25
        crash_rate: 0.10,
        byzantine_rate: 0.05,
        microglia_interval: 0,  // No immunity
    }
}

/// Training phase for multi-objective training
///
/// Defines which objective is active at each phase.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrainingPhase {
    /// NCA pre-pre-training phase
    Nca,

    /// JEPA training phase
    Jepa,

    /// NTP (next token prediction) phase
    Ntp,
}

/// Get training phases for a specific objective
///
/// Returns ordered list of phases to execute.
pub fn get_phases_for_objective(obj: Objective) -> Vec<TrainingPhase> {
    match obj {
        Objective::Ntp => vec![TrainingPhase::Ntp],
        Objective::Jepa => vec![TrainingPhase::Jepa],
        Objective::NcaNtp => vec![TrainingPhase::Nca, TrainingPhase::Ntp],
        Objective::NcaJepaNtp => vec![TrainingPhase::Nca, TrainingPhase::Jepa, TrainingPhase::Ntp],
        Objective::NcaJepaNtpV2 => vec![TrainingPhase::Nca, TrainingPhase::Jepa, TrainingPhase::Ntp],
        Objective::Hybrid => vec![TrainingPhase::Nca, TrainingPhase::Jepa, TrainingPhase::Ntp],
    }
}

/// Combined loss for multi-objective training
///
/// Weighted sum of individual losses.
#[derive(Debug, Clone)]
pub struct CombinedLoss {
    /// NTP loss (next token prediction)
    pub ntp_loss: f32,

    /// JEPA loss (embedding prediction)
    pub jepa_loss: f32,

    /// NCA loss (trajectory generation)
    pub nca_loss: f32,

    /// Total weighted loss
    pub total_loss: f32,
}

impl Default for CombinedLoss {
    fn default() -> Self {
        Self {
            ntp_loss: 0.0,
            jepa_loss: 0.0,
            nca_loss: 0.0,
            total_loss: 0.0,
        }
    }
}

impl CombinedLoss {
    /// Compute weighted total loss
    pub fn compute_total(&mut self, weights: &ObjectiveWeights) {
        self.total_loss = weights.ntp * self.ntp_loss
            + weights.jepa * self.jepa_loss
            + weights.nca_ntp * self.nca_loss;
    }

    /// Create from individual losses and weights
    pub fn from_losses(
        ntp_loss: f32,
        jepa_loss: f32,
        nca_loss: f32,
        weights: &ObjectiveWeights,
    ) -> Self {
        let total = weights.ntp * ntp_loss
            + weights.jepa * jepa_loss
            + weights.nca_ntp * nca_loss;

        Self {
            ntp_loss,
            jepa_loss,
            nca_loss,
            total_loss: total,
        }
    }
}

// ============================================================================
// Objective multipliers (from simulation)
// ============================================================================

/// Objective training time multipliers
///
/// EXP-025: Different objectives converge at different rates.
pub fn objective_multiplier(obj: Objective) -> f64 {
    match obj {
        Objective::Ntp => 1.0,           // Baseline
        Objective::Jepa => 1.4,          // 40% slower convergence
        Objective::NcaNtp => 1.6,      // 60% slower
        Objective::NcaJepaNtp => 1.5,    // Average
        Objective::NcaJepaNtpV2 => 1.4,  // Similar to JEPA
        Objective::Hybrid => 1.2,         // 20% slower
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_objective_default() {
        let obj = Objective::default();
        assert_eq!(obj, Objective::Ntp);
    }

    #[test]
    fn test_objective_display() {
        assert_eq!(format!("{}", Objective::Ntp), "ntp");
        assert_eq!(format!("{}", Objective::Jepa), "jepa");
        assert_eq!(format!("{}", Objective::Hybrid), "hybrid");
    }

    #[test]
    fn test_objective_weights_default() {
        let weights = ObjectiveWeights::default();
        assert_eq!(weights.ntp, 0.50);
        assert_eq!(weights.jepa, 0.25);
        assert_eq!(weights.nca_ntp, 0.25);
        assert!(weights.is_normalized());
    }

    #[test]
    fn test_objective_weights_normalize() {
        let mut weights = ObjectiveWeights {
            ntp: 2.0,
            jepa: 1.0,
            nca_ntp: 1.0,
        };
        weights.normalize();
        assert!(weights.is_normalized());
        // Check they're normalized to sum to 1.0
        let sum = weights.ntp + weights.jepa + weights.nca_ntp;
        assert!((sum - 1.0).abs() < 1e-6);
    }

    #[test]
    fn test_scenario_s4() {
        let scenario = scenario_s4();
        assert_eq!(scenario.crash_rate, 0.10);
        assert_eq!(scenario.byzantine_rate, 0.05);
        assert_eq!(scenario.microglia_interval, 30);
        assert_eq!(format!("{}", Objective::Ntp), "ntp");
    }

    #[test]
    fn test_scenario_s5() {
        let scenario = scenario_s5();
        assert_eq!(scenario.crash_rate, 0.10);
        assert_eq!(scenario.byzantine_rate, 0.05);
        assert_eq!(scenario.microglia_interval, 0);  // No immunity
    }

    #[test]
    fn test_get_phases() {
        assert_eq!(get_phases_for_objective(Objective::Ntp), vec![TrainingPhase::Ntp]);
        assert_eq!(get_phases_for_objective(Objective::Jepa), vec![TrainingPhase::Jepa]);
        assert_eq!(get_phases_for_objective(Objective::NcaNtp), vec![TrainingPhase::Nca, TrainingPhase::Ntp]);
        assert_eq!(get_phases_for_objective(Objective::Hybrid), vec![TrainingPhase::Nca, TrainingPhase::Jepa, TrainingPhase::Ntp]);
    }

    #[test]
    fn test_combined_loss() {
        let weights = ObjectiveWeights::default();
        let mut loss = CombinedLoss {
            ntp_loss: 1.0,
            jepa_loss: 2.0,
            nca_loss: 4.0,
            total_loss: 0.0,
        };

        loss.compute_total(&weights);

        // 0.5*1 + 0.25*2 + 0.25*4 = 0.5 + 0.5 + 1.0 = 2.0
        assert_eq!(loss.total_loss, 2.0);
    }

    #[test]
    fn test_objective_multiplier() {
        assert_eq!(objective_multiplier(Objective::Ntp), 1.0);
        assert_eq!(objective_multiplier(Objective::Jepa), 1.4);
        assert_eq!(objective_multiplier(Objective::NcaNtp), 1.6);
        assert_eq!(objective_multiplier(Objective::Hybrid), 1.2);
    }
}
