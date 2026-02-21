//! PREDICTIVE INTELLIGENCE FORECASTING v8.18
//!
//! Fits exponential growth model to intelligence history.
//! Predicts future I(t) with confidence intervals.
//!
//! Mathematical Foundation:
//!   I(t) = I₀ × e^(λt + ε)
//!   where λ = fitted_growth_rate, ε ~ N(0, σ²)
//!
//! Uses linear regression on log-transformed data:
//!   ln(I(t)) = ln(I₀) + λt
//!
//! PAS v8.18 Integration:
//!   Ensemble forecasting with PAS Trinity Formula:
//!     V = n × 3^k × π^m × φ^p × e^q

const std = @import("std");
const mu_tracker = @import("mu_tracker.zig");
const IntelligenceSnapshot = mu_tracker.IntelligenceSnapshot;

// Import PAS forecasting
const pas_forecast = @import("pas_forecast.zig");
const PasForecastModel = pas_forecast.PasForecastModel;
const PasForecast = pas_forecast.PasForecast;
const EnsembleForecaster = pas_forecast.EnsembleForecaster;

const Allocator = std.mem.Allocator;
const ArrayListManaged = std.array_list.AlignedManaged;

/// Forecasting parameters
pub const ForecastParams = struct {
    confidence_level: f64 = 0.95, // 95% confidence interval
    max_horizon: usize = 1000, // Maximum steps to forecast
    min_samples: usize = 5, // Minimum samples for fitting
};

/// Intelligence forecast result
pub const IntelligenceForecast = struct {
    predicted_multiplier: f64,
    confidence_min: f64,
    confidence_max: f64,
    time_horizon: usize,
    model_quality: f64, // R²
    growth_rate: f64, // λ per step
    std_error: f64, // Standard error of prediction

    /// Format forecast as human-readable string
    pub fn format(self: *const IntelligenceForecast, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\Forecast
            \\  Horizon: {d} steps
            \\  Predicted: ×{d:.2}
            \\  Range: ×{d:.2} - ×{d:.2} (95% CI)
            \\  Growth Rate: {d:.6} per step
            \\  Model Quality: R² = {d:.3}
        , .{
            self.time_horizon,
            self.predicted_multiplier,
            self.confidence_min,
            self.confidence_max,
            self.growth_rate,
            self.model_quality,
        });
    }
};

/// Exponential growth forecast model
pub const ForecastModel = struct {
    base_intelligence: f64, // I₀
    growth_rate: f64, // λ in I(t) = I₀ × e^(λt)
    fit_quality: f64, // R²
    last_fit_time: i64,
    std_error: f64, // Standard error of the estimate
    sample_count: usize,

    /// Initialize empty model
    pub fn init() ForecastModel {
        return ForecastModel{
            .base_intelligence = 1.0,
            .growth_rate = 0.0,
            .fit_quality = 0.0,
            .last_fit_time = 0,
            .std_error = 0.0,
            .sample_count = 0,
        };
    }

    /// Fit exponential model to intelligence history
    /// Uses linear regression on ln(intelligence) vs step
    pub fn fit(self: *ForecastModel, history: []const IntelligenceSnapshot) !void {
        if (history.len < 3) return error.TooFewSamples;

        const n = @as(f64, @floatFromInt(history.len));

        // Transform to log space: ln(I) = ln(I₀) + λt
        // We'll use step index as t (starting from 0)
        var sum_x: f64 = 0.0; // Σt
        var sum_y: f64 = 0.0; // Σln(I)
        var sum_xx: f64 = 0.0; // Σt²
        var sum_xy: f64 = 0.0; // Σt·ln(I)
        var sum_yy: f64 = 0.0; // Σln(I)²

        for (history, 0..) |snap, i| {
            const t = @as(f64, @floatFromInt(i));
            const y = @log(snap.intelligence_multiplier);

            sum_x += t;
            sum_y += y;
            sum_xx += t * t;
            sum_xy += t * y;
            sum_yy += y * y;
        }

        // Calculate regression coefficients
        const denom = n * sum_xx - sum_x * sum_x;
        if (@abs(denom) < 1e-10) return error.CannotFit;

        // Slope (λ) = (nΣxy - ΣxΣy) / (nΣx² - (Σx)²)
        const lambda = (n * sum_xy - sum_x * sum_y) / denom;

        // Intercept (ln(I₀)) = (Σy - λΣx) / n
        const intercept = (sum_y - lambda * sum_x) / n;

        self.base_intelligence = std.math.exp(intercept);
        self.growth_rate = lambda;
        self.sample_count = history.len;
        self.last_fit_time = std.time.timestamp();

        // Calculate R² and standard error
        const mean_y = sum_y / n;
        var ss_res: f64 = 0.0; // Residual sum of squares
        var ss_tot: f64 = 0.0; // Total sum of squares

        for (history, 0..) |snap, i| {
            const t = @as(f64, @floatFromInt(i));
            const y = @log(snap.intelligence_multiplier);
            const y_pred = intercept + lambda * t;

            ss_res += (y - y_pred) * (y - y_pred);
            ss_tot += (y - mean_y) * (y - mean_y);
        }

        self.std_error = if (history.len > 2)
            @sqrt(ss_res / @as(f64, @floatFromInt(history.len - 2)))
        else
            0.0;

        self.fit_quality = if (ss_tot > 1e-10)
            1.0 - (ss_res / ss_tot)
        else
            1.0; // Perfect fit if no variance
    }

    /// Predict intelligence at t + horizon steps
    pub fn predict(self: *const ForecastModel, horizon_steps: usize) f64 {
        const t = @as(f64, @floatFromInt(horizon_steps));
        return self.base_intelligence * std.math.exp(self.growth_rate * t);
    }

    /// Get 95% confidence interval for prediction
    /// Uses standard error of the estimate
    pub fn confidenceInterval(self: *const ForecastModel, horizon_steps: usize, confidence_level: f64) [2]f64 {
        const t = @as(f64, @floatFromInt(horizon_steps));
        const point_estimate = self.predict(horizon_steps);

        // Student's t-value for confidence intervals (approximate with normal)
        // Use runtime comparison
        const z_value: f64 = if (confidence_level >= 0.99)
            2.576 // 99% CI
        else if (confidence_level >= 0.95)
            1.96 // 95% CI
        else if (confidence_level >= 0.90)
            1.645 // 90% CI
        else
            1.0; // Default ~68% CI

        // Standard error increases with horizon (prediction uncertainty)
        const prediction_se = self.std_error * @sqrt(1.0 + 1.0 / @as(f64, @floatFromInt(self.sample_count)) + t * t / (@as(f64, @floatFromInt(self.sample_count))));

        // Multiplicative error in log space becomes multiplicative in linear space
        const log_error = z_value * prediction_se;
        const lower = point_estimate * std.math.exp(-log_error);
        const upper = point_estimate * std.math.exp(log_error);

        return .{ lower, upper };
    }

    /// Check if prediction is bounded (not exploding)
    pub fn isBounded(self: *const ForecastModel, max_multiplier: f64, horizon_steps: usize) bool {
        const prediction = self.predict(horizon_steps);
        return prediction < max_multiplier and prediction > 0.0;
    }

    /// Get model summary
    pub fn getSummary(self: *const ForecastModel, allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator,
            \\Forecast Model Summary
            \\  Base Intelligence: I₀ = {d:.4}
            \\  Growth Rate: λ = {d:.6} per step
            \\  Fit Quality: R² = {d:.3}
            \\  Standard Error: σ = {d:.4}
            \\  Sample Count: n = {d}
            \\  Last Fit: {d}
        , .{
            self.base_intelligence,
            self.growth_rate,
            self.fit_quality,
            self.std_error,
            self.sample_count,
            self.last_fit_time,
        });
    }
};

/// Generate forecasts for multiple time horizons
pub fn generateForecasts(
    tracker: *mu_tracker.MuTracker,
    allocator: Allocator,
    horizons: []const usize,
    params: ForecastParams,
) ![]const IntelligenceForecast {
    const history = try tracker.snapshots.toOwnedSlice();
    defer allocator.free(history);

    if (history.len < params.min_samples) return error.TooFewSamples;

    var model = ForecastModel.init();
    try model.fit(history);

    var forecasts = try allocator.alloc(IntelligenceForecast, horizons.len);

    for (horizons, 0..) |horizon, i| {
        const predicted = model.predict(horizon);
        const ci = model.confidenceInterval(horizon, params.confidence_level);

        forecasts[i] = IntelligenceForecast{
            .predicted_multiplier = predicted,
            .confidence_min = ci[0],
            .confidence_max = ci[1],
            .time_horizon = horizon,
            .model_quality = model.fit_quality,
            .growth_rate = model.growth_rate,
            .std_error = model.std_error,
        };
    }

    return forecasts;
}

/// Generate single forecast with default parameters
pub fn generateForecast(
    tracker: *mu_tracker.MuTracker,
    horizon_steps: usize,
) !IntelligenceForecast {
    const allocator = std.heap.page_allocator;
    const horizons = [_]usize{horizon_steps};

    const forecasts = try generateForecasts(tracker, allocator, &horizons, .{});
    defer allocator.free(forecasts);

    return forecasts[0];
}

/// Get forecast for dashboard (with sensible defaults)
pub fn getDashboardForecast(
    tracker: *const mu_tracker.MuTracker,
    allocator: Allocator,
) ![][]const u8 {
    const horizons = [_]usize{ 10, 50, 100 };
    const forecasts = try generateForecasts(tracker, allocator, &horizons, .{});
    defer allocator.free(forecasts);

    var lines = ArrayListManaged([]const u8).init(allocator);

    try lines.append(try allocator.dupe(u8,
        \\# INTELLIGENCE FORECAST
        \\| Horizon | Predicted | Min (95% CI) | Max (95% CI) | Growth Rate |
        \\|----------|-----------|--------------|--------------|-------------|
    ));

    for (forecasts) |fc| {
        const line = try std.fmt.allocPrint(allocator,
            "| {d} steps | ×{d:.2} | ×{d:.2} | ×{d:.2} | {d:.6} |\n",
            .{ fc.time_horizon, fc.predicted_multiplier, fc.confidence_min, fc.confidence_max, fc.growth_rate }
        );
        try lines.append(line);
    }

    try lines.append(try std.fmt.allocPrint(allocator, "\nModel Quality: R² = {d:.3}\n", .{forecasts[0].model_quality}));

    return lines.toOwnedSlice();
}

/// Quick sanity check on forecast
pub fn validateForecast(forecast: *const IntelligenceForecast) bool {
    // Check for reasonable values
    if (forecast.predicted_multiplier < 0.0) return false;
    if (forecast.predicted_multiplier > 1e15) return false; // Excessive growth
    if (forecast.confidence_min > forecast.predicted_multiplier) return false;
    if (forecast.confidence_max < forecast.predicted_multiplier) return false;
    if (forecast.model_quality < 0.0 or forecast.model_quality > 1.0) return false;

    return true;
}

/// Global forecast model (cached)
var global_model: ?ForecastModel = null;
var global_model_time: i64 = 0;

/// Get or create cached forecast model
pub fn getGlobalModel(tracker: *const mu_tracker.MuTracker) !*ForecastModel {
    const current_time = std.time.timestamp();

    // Refresh if older than 1 minute
    if (global_model == null or (current_time - global_model_time) > 60) {
        const allocator = std.heap.page_allocator;
        const history = try tracker.snapshots.toOwnedSlice();
        defer allocator.free(history);

        var model = ForecastModel.init();
        model.fit(history) catch {
            // Fallback to default model
            model = ForecastModel.init();
        };

        if (global_model == null) {
            global_model = model;
        } else {
            global_model.?.base_intelligence = model.base_intelligence;
            global_model.?.growth_rate = model.growth_rate;
            global_model.?.fit_quality = model.fit_quality;
            global_model.?.std_error = model.std_error;
            global_model.?.sample_count = model.sample_count;
            global_model.?.last_fit_time = model.last_fit_time;
        }

        global_model_time = current_time;
    }

    return &global_model.?;
}

// ═══════════════════════════════════════════════════════════════
// PAS v8.18 ENSEMBLE FORECASTING
// ═══════════════════════════════════════════════════════════════

/// PAS-enhanced forecast result
pub const PasIntelligenceForecast = struct {
    /// Standard exponential forecast
    exponential: IntelligenceForecast,
    /// PAS Trinity forecast
    pas: PasForecast,
    /// Ensemble recommendation
    recommendation: enum {
        accelerate,
        maintain,
        decelerate,
        explore,
    },
    /// Combined confidence
    combined_confidence: f64,
};

/// Generate ensemble forecast combining exponential and PAS models
pub fn generateEnsembleForecast(
    tracker: *mu_tracker.MuTracker,
    allocator: Allocator,
    horizon_steps: usize,
) !PasIntelligenceForecast {
    // Get history
    const history = try tracker.snapshots.toOwnedSlice();
    defer allocator.free(history);

    if (history.len < 5) return error.TooFewSamples;

    // Standard exponential forecast
    const exp_forecast = try generateForecast(tracker, horizon_steps);

    // PAS Trinity forecast
    var pas_model = PasForecastModel.init();
    try pas_model.fitPas(history);
    const pas_fc = try pas_model.forecast(horizon_steps);

    // Ensemble recommendation
    var forecaster = EnsembleForecaster.init(allocator);
    try forecaster.fit(history);
    const recommendation = forecaster.recommend();

    // Combined confidence (geometric mean)
    const combined_confidence = std.math.sqrt(exp_forecast.model_quality * pas_fc.model_quality);

    return PasIntelligenceForecast{
        .exponential = exp_forecast,
        .pas = pas_fc,
        .recommendation = recommendation,
        .combined_confidence = combined_confidence,
    };
}

/// Generate PAS-only forecast
pub fn generatePasForecast(
    tracker: *mu_tracker.MuTracker,
    horizon_steps: usize,
) !PasForecast {
    const allocator = std.heap.page_allocator;
    const history = try tracker.snapshots.toOwnedSlice();
    defer allocator.free(history);

    var pas_model = PasForecastModel.init();
    try pas_model.fitPas(history);
    return pas_model.forecast(horizon_steps);
}

/// Check if forecast respects PAS sacred bounds
pub fn validatePasBounds(forecast: *const PasForecast) bool {
    return pas_forecast.checkSacredBounds(forecast.*;
}

/// Get Trinity score from history
pub fn getTrinityScore(tracker: *mu_tracker.MuTracker) !f64 {
    const allocator = std.heap.page_allocator;
    const history = try tracker.snapshots.toOwnedSlice();
    defer allocator.free(history);

    var values = try allocator.alloc(f64, history.len);
    defer allocator.free(values);

    for (history, 0..) |snap, i| {
        values[i] = snap.intelligence_multiplier;
    }

    return pas_forecast.calculateTrinityScore(values);
}

/// Global ensemble forecaster (cached)
var global_ensemble: ?EnsembleForecaster = null;
var global_ensemble_time: i64 = 0;

/// Get or create cached ensemble forecaster
pub fn getGlobalEnsemble(tracker: *const mu_tracker.MuTracker, allocator: Allocator) !*EnsembleForecaster {
    const current_time = std.time.timestamp();

    // Refresh if older than 1 minute
    if (global_ensemble == null or (current_time - global_ensemble_time) > 60) {
        const history = try tracker.snapshots.toOwnedSlice();
        defer allocator.free(history);

        var forecaster = EnsembleForecaster.init(allocator);
        forecaster.fit(history) catch {
            // Fallback
            forecaster = EnsembleForecaster.init(allocator);
        };

        if (global_ensemble == null) {
            global_ensemble = forecaster;
        }

        global_ensemble_time = current_time;
    }

    return &global_ensemble.?;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "ForecastModel: initialization" {
    const model = ForecastModel.init();

    try std.testing.expectEqual(@as(f64, 1.0), model.base_intelligence);
    try std.testing.expectEqual(@as(f64, 0.0), model.growth_rate);
}

test "ForecastModel: fit exponential growth" {
    const allocator = std.testing.allocator;

    // Create synthetic exponential growth data
    var snapshots = ArrayListManaged(IntelligenceSnapshot, null).init(allocator);
    defer snapshots.deinit();

    const I0: f64 = 1.0;
    const lambda: f64 = 0.0382; // μ growth rate

    for (0..10) |i| {
        const t = @as(f64, @floatFromInt(i));
        const I = I0 * std.math.exp(lambda * t);

        const snap = IntelligenceSnapshot{
            .timestamp = @intCast(i),
            .total_fixes = i,
            .successful_fixes = i,
            .failed_fixes = 0,
            .current_mu = 0.0,
            .intelligence_multiplier = I,
            .success_rate = 1.0,
        };
        try snapshots.append(snap);
    }

    var model = ForecastModel.init();
    try model.fit(snapshots.items);

    // Growth rate should be close to lambda
    try std.testing.expectApproxEqRel(lambda, model.growth_rate, 0.01);

    // Fit quality should be excellent (R² > 0.95)
    try std.testing.expect(model.fit_quality > 0.95);
}

test "ForecastModel: predict future" {
    const allocator = std.testing.allocator;

    var snapshots = ArrayListManaged(IntelligenceSnapshot, null).init(allocator);
    defer snapshots.deinit();

    // Simple exponential: I = e^(0.04t)
    for (0..5) |i| {
        const t = @as(f64, @floatFromInt(i));
        const I = std.math.exp(0.04 * t);

        try snapshots.append(IntelligenceSnapshot{
            .timestamp = @intCast(i),
            .total_fixes = i,
            .successful_fixes = i,
            .failed_fixes = 0,
            .current_mu = 0.0,
            .intelligence_multiplier = I,
            .success_rate = 1.0,
        });
    }

    var model = ForecastModel.init();
    try model.fit(snapshots.items);

    // Predict 10 steps ahead
    const predicted = model.predict(10);
    const expected = std.math.exp(0.04 * 10);

    try std.testing.expectApproxEqRel(expected, predicted, 0.1);
}

test "ForecastModel: confidence interval" {
    const allocator = std.testing.allocator;

    var snapshots = ArrayListManaged(IntelligenceSnapshot, null).init(allocator);
    defer snapshots.deinit();

    // Create data with some noise
    for (0..20) |i| {
        const t = @as(f64, @floatFromInt(i));
        const base = std.math.exp(0.03 * t);
        const noise = 1.0 + @rem(@as(f64, @floatFromInt(i)), 3.0) * 0.05; // ±5% noise
        const I = base * noise;

        try snapshots.append(IntelligenceSnapshot{
            .timestamp = @intCast(i),
            .total_fixes = i,
            .successful_fixes = i,
            .failed_fixes = 0,
            .current_mu = 0.0,
            .intelligence_multiplier = I,
            .success_rate = 1.0,
        });
    }

    var model = ForecastModel.init();
    try model.fit(snapshots.items);

    const ci = model.confidenceInterval(10, 0.95);

    // Min < point < Max
    try std.testing.expect(ci[0] < ci[1]);
}

test "ForecastModel: isBounded" {
    var model = ForecastModel.init();
    model.base_intelligence = 1.0;
    model.growth_rate = 0.0382;
    model.sample_count = 10;

    // Reasonable prediction should be bounded
    try std.testing.expect(model.isBounded(1000.0, 100));

    // Very far ahead might exceed bound
    try std.testing.expect(!model.isBounded(10.0, 1000));
}

test "IntelligenceForecast: format" {
    const allocator = std.testing.allocator;

    const forecast = IntelligenceForecast{
        .predicted_multiplier = 47.0,
        .confidence_min = 40.0,
        .confidence_max = 55.0,
        .time_horizon = 100,
        .model_quality = 0.95,
        .growth_rate = 0.0382,
        .std_error = 0.01,
    };

    const formatted = try forecast.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "100 steps") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "47.00") != null);
}

test "validateForecast: reasonable values" {
    const forecast = IntelligenceForecast{
        .predicted_multiplier = 50.0,
        .confidence_min = 40.0,
        .confidence_max = 60.0,
        .time_horizon = 100,
        .model_quality = 0.95,
        .growth_rate = 0.0382,
        .std_error = 0.01,
    };

    try std.testing.expect(validateForecast(&forecast));
}

test "validateForecast: rejects invalid values" {
    // Negative prediction
    var forecast = IntelligenceForecast{
        .predicted_multiplier = -1.0,
        .confidence_min = 0.0,
        .confidence_max = 0.0,
        .time_horizon = 0,
        .model_quality = 0.5,
        .growth_rate = 0.0,
        .std_error = 0.0,
    };
    try std.testing.expect(!validateForecast(&forecast));

    // Min > Max
    forecast.predicted_multiplier = 50.0;
    forecast.confidence_min = 60.0;
    forecast.confidence_max = 40.0;
    try std.testing.expect(!validateForecast(&forecast));
}

test "generateForecasts: multiple horizons" {
    const allocator = std.testing.allocator;

    var tracker = try mu_tracker.MuTracker.init(allocator);
    defer tracker.deinit();

    // Generate synthetic growth
    for (0..20) |_| {
        try tracker.recordFix("TEST_FIX", true, "test", 100, 1.0);
    }

    const horizons = [_]usize{ 10, 50 };
    const forecasts = try generateForecasts(&tracker, allocator, &horizons, .{});
    defer allocator.free(forecasts);

    try std.testing.expectEqual(@as(usize, 2), forecasts.len);

    // Longer horizon should have higher prediction
    try std.testing.expect(forecasts[1].predicted_multiplier > forecasts[0].predicted_multiplier);
}
