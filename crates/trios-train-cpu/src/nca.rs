//! Neural Cellular Automata (NCA) for pre-pre-training
//!
//! Research: MIT arXiv 2603.10055, EXP-015+

use std::collections::HashMap;
use rand::SeedableRng;

// ============================================================================
// NCA Configuration
// ============================================================================

/// NCA configuration with Trinity constants
#[derive(Debug, Clone, Copy)]
pub struct NcaConfig {
    pub grid_size: u8,
    pub num_states: u8,
    pub rollout_steps: u16,
    pub token_offset: u16,
    pub min_entropy: f32,
    pub max_entropy: f32,
    pub seed: u64,
}

impl Default for NcaConfig {
    fn default() -> Self {
        Self {
            grid_size: 9,
            num_states: 9,
            rollout_steps: 128,
            token_offset: 4,
            min_entropy: 1.5,
            max_entropy: 2.8,
            seed: 42,
        }
    }
}

// ============================================================================
// NCA State
// ============================================================================

pub type NcaState = u8;

pub struct NcaGrid {
    pub size: u8,
    cells: Vec<NcaState>,
}

impl NcaGrid {
    pub fn new(size: u8) -> Self {
        let total_cells = (size as usize) * (size as usize);
        Self {
            size,
            cells: vec![0; total_cells],
        }
    }

    pub fn get(&self, x: u8, y: u8) -> NcaState {
        let idx = (y as usize) * (self.size as usize) + (x as usize);
        self.cells[idx]
    }

    pub fn set(&mut self, x: u8, y: u8, value: NcaState) {
        let idx = (y as usize) * (self.size as usize) + (x as usize);
        self.cells[idx] = value;
    }

    /// Reset all cells to a given state
    pub fn reset(&mut self, value: NcaState) {
        self.cells.fill(value);
    }
}

// ============================================================================
// NCA Rules
// ============================================================================

pub struct NcaRules {
    num_states: u8,
}

impl NcaRules {
    pub fn new(num_states: u8) -> Self {
        Self { num_states }
    }

    pub fn count_neighbors(&self, grid: &NcaGrid, x: u8, y: u8) -> Vec<usize> {
        let mut counts = vec![0; self.num_states as usize];
        let size = grid.size;

        for dy in -1i8..=1i8 {
            for dx in -1i8..=1i8 {
                if dx == 0 && dy == 0 {
                    continue;
                }
                let nx = ((x as i16 + dx as i16 + size as i16) % size as i16) as u8;
                let ny = ((y as i16 + dy as i16 + size as i16) % size as i16) as u8;
                let state = grid.get(nx, ny);
                counts[state as usize] += 1;
            }
        }

        counts
    }

    pub fn transition(&self, grid: &NcaGrid, x: u8, y: u8) -> NcaState {
        let counts = self.count_neighbors(grid, x, y);
        let mut max_count: usize = 0;
        let mut max_state: NcaState = 0;

        for (state, count) in counts.iter().enumerate() {
            if *count > max_count as usize {
                max_count = *count;
                max_state = state as NcaState;
            }
        }

        max_state
    }

    pub fn step(&self, grid: &mut NcaGrid) {
        let new_cells = grid.cells.clone();
        let new_grid = NcaGrid {
            size: grid.size,
            cells: new_cells,
        };

        for y in 0..grid.size {
            for x in 0..grid.size {
                let new_state = self.transition(&new_grid, x, y);
                grid.set(x, y, new_state);
            }
        }
    }
}

// ============================================================================
// NCA Trainer
// ============================================================================

#[allow(dead_code)]
pub struct NcaTrainer {
    config: NcaConfig,
    rules: NcaRules,
    rng: rand::rngs::StdRng,
}

impl NcaTrainer {
    pub fn new(config: NcaConfig) -> Self {
        Self {
            rules: NcaRules::new(config.num_states),
            config,
            rng: rand::rngs::StdRng::seed_from_u64(config.seed),
        }
    }

    pub fn generate_trajectory(&mut self, tokens: &[usize]) -> Vec<Vec<f32>> {
        let mut grid = NcaGrid::new(self.config.grid_size);

        for (i, token) in tokens.iter().enumerate() {
            if *token >= self.config.num_states as usize {
                continue;
            }
            let x = (i as u8) % self.config.grid_size;
            let y = (i as u8) / self.config.grid_size;
            grid.set(x, y, *token as NcaState);
        }

        let mut trajectory = Vec::with_capacity(self.config.rollout_steps as usize);

        for _ in 0..self.config.rollout_steps {
            self.rules.step(&mut grid);

            let flat_grid: Vec<f32> = grid.cells
                .iter()
                .map(|s| *s as f32)
                .collect();

            trajectory.push(flat_grid);
        }

        trajectory
    }

    pub fn compute_entropy(&self, trajectory: &[Vec<f32>]) -> f32 {
        let mut state_counts: HashMap<NcaState, usize> = HashMap::new();

        for grid in trajectory {
            for state in grid.iter() {
                let state_key = *state as NcaState;
                *state_counts.entry(state_key).or_insert(0) += 1;
            }
        }

        let grid_len = trajectory.get(0).map(|g| g.len()).unwrap_or(0);
        let total: usize = trajectory.len() * grid_len;
        let mut entropy: f64 = 0.0;

        for count in state_counts.values() {
            let p = *count as f64 / total as f64;
            entropy -= p * p.log2();
        }

        entropy as f32
    }

    pub fn is_valid_trajectory(&self, trajectory: &[Vec<f32>]) -> bool {
        let entropy = self.compute_entropy(trajectory);
        entropy >= self.config.min_entropy && entropy <= self.config.max_entropy
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_nca_config_default() {
        let config = NcaConfig::default();
        assert_eq!(config.grid_size, 9);
        assert_eq!(config.num_states, 9);
        assert_eq!(config.rollout_steps, 128);
        assert_eq!(config.token_offset, 4);
        assert_eq!(config.min_entropy, 1.5);
        assert_eq!(config.max_entropy, 2.8);
        assert_eq!(config.seed, 42);
    }

    #[test]
    fn test_nca_grid() {
        let mut grid = NcaGrid::new(3);

        grid.set(0, 0, 1);
        grid.set(1, 1, 2);
        grid.set(2, 2, 3);

        assert_eq!(grid.get(0, 0), 1);
        assert_eq!(grid.get(1, 1), 2);
        assert_eq!(grid.get(2, 2), 3);

        grid.reset(0);
        assert_eq!(grid.get(0, 0), 0);
    }

    #[test]
    fn test_nca_rules() {
        let rules = NcaRules::new(3);
        let mut grid = NcaGrid::new(3);

        for x in 0..3 {
            for y in 0..3 {
                grid.set(x, y, 1);
            }
        }
        grid.set(1, 1, 0);

        let counts = rules.count_neighbors(&grid, 1, 1);
        assert_eq!(counts[1], 8);

        let new_state = rules.transition(&grid, 1, 1);
        assert_eq!(new_state, 1);
    }

    #[test]
    fn test_generate_trajectory() {
        let config = NcaConfig {
            grid_size: 3,
            num_states: 3,
            rollout_steps: 10,
            token_offset: 0,
            min_entropy: 0.0,
            max_entropy: 3.0,
            seed: 42,
        };
        let mut trainer = NcaTrainer::new(config);

        let tokens = vec![0, 1, 2, 0, 1, 2, 0, 1, 2];
        let trajectory = trainer.generate_trajectory(&tokens);

        assert_eq!(trajectory.len(), 10);

        for step in &trajectory {
            assert_eq!(step.len(), 9);
        }
    }

    #[test]
    fn test_compute_entropy() {
        let config = NcaConfig::default();
        let trainer = NcaTrainer::new(config);

        // Uniform distribution over 9 states (each appears 4 times)
        // Entropy should be log2(9) ≈ 3.17
        let uniform_grid: Vec<Vec<f32>> = vec![
            vec![0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
            vec![0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
            vec![0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
            vec![0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
        ];
        let entropy = trainer.compute_entropy(&uniform_grid);

        // log2(9) ≈ 3.1699
        assert!((entropy - 3.17).abs() < 0.01);

        let single_grid: Vec<Vec<f32>> = vec![
            vec![1.0; 9],
            vec![1.0; 9],
            vec![1.0; 9],
        ];
        let zero_entropy = trainer.compute_entropy(&single_grid);
        assert!((zero_entropy - 0.0).abs() < 0.01);
    }

    #[test]
    fn test_is_valid_trajectory() {
        let config = NcaConfig::default();
        let trainer = NcaTrainer::new(config);

        let uniform_grid: Vec<Vec<f32>> = vec![
            vec![0.0, 1.0, 2.0, 0.0, 1.0, 2.0],
            vec![1.0, 2.0, 0.0, 1.0, 2.0, 0.0],
            vec![2.0, 0.0, 1.0, 2.0, 0.0, 1.0, 2.0],
        ];

        assert!(trainer.is_valid_trajectory(&uniform_grid));

        let single_grid: Vec<Vec<f32>> = vec![
            vec![1.0; 9],
            vec![1.0; 9],
            vec![1.0; 9],
        ];
        assert!(!trainer.is_valid_trajectory(&single_grid));
    }
}
