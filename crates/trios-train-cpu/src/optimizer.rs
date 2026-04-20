//! Optimizers: AdamW and LAMB (Layer-wise Adaptive Moments)
//!
//! EXP-005: LAMB performs similarly to AdamW at same ctx,
//! but with better layer-wise adaptive behavior.

/// AdamW optimizer (legacy)
///
/// Weight decay is decoupled from gradient updates.
#[derive(Debug, Clone)]
pub struct AdamWCpu {
    pub lr: f64,
    pub beta1: f64,
    pub beta2: f64,
    pub weight_decay: f64,
    pub eps: f64,
    pub step: usize,
    m: Vec<f64>,
    v: Vec<f64>,
}

impl AdamWCpu {
    pub fn new(param_count: usize, lr: f64) -> Self {
        Self {
            lr,
            beta1: 0.9,
            beta2: 0.999,
            weight_decay: 0.01,
            eps: 1e-8,
            step: 0,
            m: vec![0.0; param_count],
            v: vec![0.0; param_count],
        }
    }

    pub fn step(&mut self, params: &mut [f32], gradients: &[f32]) {
        assert_eq!(params.len(), gradients.len());
        assert_eq!(params.len(), self.m.len());

        // Update biased moments
        for i in 0..params.len() {
            self.m[i] = self.beta1 * self.m[i] + (1.0 - self.beta1) * gradients[i] as f64;
            let g_sq = (gradients[i] as f64).powi(2);
            self.v[i] = self.beta2 * self.v[i] + (1.0 - self.beta2) * g_sq;
        }

        // Bias correction
        let bias_correction = 1.0 - self.beta2.powi(self.step as i32);

        // Update parameters with decoupled weight decay
        for i in 0..params.len() {
            // L2 weight decay
            params[i] -= (self.lr * (self.weight_decay * params[i] as f64)) as f32;

            // Adam update
            let m_hat = self.m[i] / bias_correction;
            let v_hat = self.v[i] / bias_correction;
            params[i] -= (self.lr * m_hat / (v_hat.sqrt() + self.eps)) as f32;
        }

        self.step += 1;
    }

    pub fn step_count(&self) -> usize {
        self.step
    }
}

/// LAMB optimizer (Layer-wise Adaptive Moments)
///
/// From "Large Batch Optimization of Deep Learning" paper.
/// EXP-005: Similar to AdamW at same ctx, better adaptive behavior.
#[derive(Debug, Clone)]
pub struct LAMBCpu {
    pub lr: f64,
    pub beta1: f64,
    pub beta2: f64,
    pub weight_decay: f64,
    pub clamp: f32,
    pub stable_ratio: f32,
    pub eps: f64,
    pub step: usize,
    m: Vec<f64>,
    v: Vec<f64>,
}

impl LAMBCpu {
    pub fn new(param_count: usize, lr: f64) -> Self {
        Self {
            lr,
            beta1: 0.9,
            beta2: 0.999,
            weight_decay: 0.01,
            clamp: 10.0,
            stable_ratio: 0.02,
            eps: 1e-8,
            step: 0,
            m: vec![0.0; param_count],
            v: vec![0.0; param_count],
        }
    }

    pub fn step(&mut self, params: &mut [f32], gradients: &[f32]) {
        assert_eq!(params.len(), gradients.len());
        assert_eq!(params.len(), self.m.len());

        // Update biased moments
        for i in 0..params.len() {
            self.m[i] = self.beta1 * self.m[i] + (1.0 - self.beta1) * gradients[i] as f64;
            let g_sq = (gradients[i] as f64).powi(2);
            self.v[i] = self.beta2 * self.v[i] + (1.0 - self.beta2) * g_sq;
        }

        // Bias correction
        let bias_correction = 1.0 - self.beta2.powi(self.step as i32);
        let m_hat_denom = 1.0 - self.beta1.powi(self.step as i32);

        for i in 0..params.len() {
            // Apply weight decay to gradient
            let g = (gradients[i] as f64) + (self.weight_decay as f64 * params[i] as f64);

            // Compute bias-corrected moments
            let m_hat = self.m[i] / m_hat_denom;
            let v_hat = self.v[i] / bias_correction;

            // Compute trust ratio (LAMB-specific)
            let v_sqrt = v_hat.sqrt() + self.eps;
            let r_norm = m_hat / v_sqrt;
            let w_norm = params[i] as f64;
            let stable_ratio = self.stable_ratio as f64;

            let trust_ratio = if w_norm.abs() < stable_ratio {
                r_norm / w_norm
            } else {
                r_norm
            };

            // Clip trust ratio
            let trust_ratio_clamped = trust_ratio.clamp(-(self.clamp as f64), self.clamp as f64);

            // Update parameter (cast to f64 for calculation, then back to f32)
            let update = self.lr * params[i] as f64 * trust_ratio_clamped;
            params[i] -= update as f32;
        }

        self.step += 1;
    }

    pub fn step_count(&self) -> usize {
        self.step
    }
}

/// Phi-based learning rate schedule function
///
/// Used for warm restarts and long training runs.
pub fn phi_lr_schedule(
    step: usize,
    base_lr: f64,
    warmup_steps: usize,
    phi: f64,
) -> f64 {
    if step < warmup_steps {
        // Linear warmup
        base_lr * (step as f64 / warmup_steps as f64)
    } else {
        // Phi decay
        let t = (step - warmup_steps) as f64;
        base_lr * (t / (t + phi))
    }
}

/// Cosine learning rate schedule function
///
/// LR(t) = lr_min + 0.5 * (lr_base - lr_min) * (1 + cos(π * progress))
pub fn cosine_lr_schedule(
    step: usize,
    base_lr: f64,
    warmup_steps: usize,
    min_lr: f64,
    max_steps: usize,
) -> f64 {
    if step < warmup_steps {
        // Linear warmup
        base_lr * (step as f64 / warmup_steps as f64)
    } else {
        // Cosine decay
        let progress = (step - warmup_steps) as f64 / (max_steps - warmup_steps) as f64;
        min_lr + 0.5 * (base_lr - min_lr) * (1.0 + (std::f64::consts::PI * progress).cos())
    }
}

/// Gradient clipping
///
/// Clips gradients to [-max_norm, max_norm] using L2 norm.
pub fn clip_gradients(gradients: &mut [f32], max_norm: f32) -> f32 {
    let sum_sq: f32 = gradients.iter().map(|&x| x * x).sum();
    let norm = sum_sq.sqrt();

    if norm > max_norm {
        let scale = max_norm / norm;
        for g in gradients.iter_mut() {
            *g *= scale;
        }
        max_norm
    } else {
        norm
    }
}

/// Learning rate schedule type
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum LrSchedule {
    Cosine { lr_min: f64, restart_period: usize },
    Phi,
}

impl Default for LrSchedule {
    fn default() -> Self {
        Self::Cosine {
            lr_min: 1e-5,
            restart_period: 0,
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_adamw_step() {
        let mut optimizer = AdamWCpu::new(3, 1e-3);
        let mut params = [1.0_f32, 2.0_f32, 3.0_f32];
        let grads = [0.1_f32, 0.2_f32, 0.3_f32];

        optimizer.step(&mut params, &grads);

        assert!(params[0] < 1.0);
        assert!(params[1] < 2.0);
        assert!(params[2] < 3.0);
        assert_eq!(optimizer.step, 1);
    }

    #[test]
    fn test_lamb_step() {
        let mut optimizer = LAMBCpu::new(3, 1e-3);
        let mut params = [1.0_f32, 2.0_f32, 3.0_f32];
        let grads = [0.1_f32, 0.2_f32, 0.3_f32];

        optimizer.step(&mut params, &grads);

        assert!(params[0] < 1.0);
        assert!(params[1] < 2.0);
        assert!(params[2] < 3.0);
        assert_eq!(optimizer.step, 1);
    }

    #[test]
    fn test_cosine_lr_schedule() {
        let lr_base = 1e-3;
        let lr_min = 1e-5;
        let max_steps = 1000;
        let warmup = 100;

        let lr_0 = cosine_lr_schedule(0, lr_base, warmup, lr_min, max_steps);
        assert!((lr_0 - 0.0).abs() < 1e-9);

        let lr_50 = cosine_lr_schedule(warmup / 2, lr_base, warmup, lr_min, max_steps);
        assert!(lr_50 > lr_0 && lr_50 < lr_base);

        let lr_500 = cosine_lr_schedule(500, lr_base, warmup, lr_min, max_steps);
        assert!(lr_500 > lr_min && lr_500 < lr_base);

        let lr_1000 = cosine_lr_schedule(max_steps, lr_base, warmup, lr_min, max_steps);
        assert!((lr_1000 - lr_min).abs() < 1e-9);
    }

    #[test]
    fn test_phi_lr_schedule() {
        let lr_base = 1e-3;
        let warmup = 100;
        let phi = 3.0;

        let lr_0 = phi_lr_schedule(0, lr_base, warmup, phi);
        assert!((lr_0 - 0.0).abs() < 1e-9);

        let lr_100 = phi_lr_schedule(warmup, lr_base, warmup, phi);
        assert!((lr_100 - lr_base).abs() < 1e-9);

        let lr_200 = phi_lr_schedule(200, lr_base, warmup, phi);
        assert!(lr_200 < lr_base);
    }

    #[test]
    fn test_clip_gradients() {
        let mut grads = [10.0_f32, 20.0_f32, 30.0_f32];
        let max_norm = 1.0;

        clip_gradients(&mut grads, max_norm);

        let norm = (grads[0].powi(2) + grads[1].powi(2) + grads[2].powi(2)).sqrt();
        assert!(norm <= max_norm + 1e-6);
    }
}
