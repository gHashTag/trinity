// =============================================================================
// TRINITY PRICE ORACLE - CAPO Integration
// Correlated-Assets Price Oracle for flashloan manipulation protection
// v3.1: Liquidity-aware TWAP, price movement caps, reference prices
//
// Research sources:
// - OpenZeppelin 2025: ERC-4626 security best practices
// - Venus Protocol exploit (Feb 2025): Flashloan price manipulation
// - Aave November 2025: CAPO timestamp mismatch incident
// - October 2025: Circuit breaker improvements
//
// phi^2 + 1/phi^2 = 3 (Trinity Identity)
// 3^21 = 10,460,353,203 (Sacred Token Supply)
// KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// SACRED CONSTANTS
// =============================================================================

/// SACRED: Total $TRI supply
pub const SACRED_SUPPLY: u256 = 10_460_353_203 * 1_000_000_000_000_000_000;

/// Default USD price for TRI (used when oracle unavailable)
pub const DEFAULT_TRI_PRICE_USD: u128 = 1 * 1e18; // $1.00

/// v3.1: Minimum liquidity threshold ($50K USD)
pub const MIN_LIQUIDITY_USD: u128 = 50_000 * 1e18;

/// v3.1: Maximum price movement per update (10%)
pub const MAX_PRICE_MOVE_PER_UPDATE_BPS: u256 = 1000;

/// v3.1: Maximum yearly growth for correlated assets (8%)
pub const MAX_YEARLY_RATIO_GROWTH_BPS: u256 = 800;

// =============================================================================
// ORACLE CONFIGURATION v3.1
// =============================================================================

pub const OracleConfig = struct {
    /// Maximum deviation before price is rejected (basis points, 500 = 5%)
    max_deviation_bps: u256 = 500,

    /// TWAP window duration (seconds)
    twap_window_secs: u64 = 3600, // 1 hour

    /// Price staleness threshold (seconds)
    staleness_threshold_secs: u64 = 300, // 5 minutes

    /// Minimum number of data points for valid TWAP
    min_twap_points: usize = 2,

    /// v3.1: Minimum liquidity threshold (USD, 18 decimals)
    min_liquidity_usd: u128 = MIN_LIQUIDITY_USD,

    /// v3.1: Maximum price movement per update (basis points)
    max_price_move_per_update_bps: u256 = MAX_PRICE_MOVE_PER_UPDATE_BPS,

    /// v3.1: Require liquidity validation
    require_liquidity_check: bool = true,
};

// =============================================================================
// PRICE DATA POINT v3.1
// =============================================================================

pub const PricePoint = struct {
    price: u128, // Price in USD (18 decimals)
    timestamp: i64,
    volume: u128, // Trading volume (optional, for VWAP)

    /// v3.1: Liquidity at this price point (USD, 18 decimals)
    liquidity: u128,

    pub fn isValid(self: PricePoint, now: i64, staleness_secs: u64) bool {
        const age = now - self.timestamp;
        return @as(i64, @intCast(staleness_secs)) >= age and self.price > 0;
    }
};

// =============================================================================
// REFERENCE PRICE for Yearly Growth Calculation
// =============================================================================

pub const ReferencePrice = struct {
    price: u128,
    timestamp: i64,
};

// =============================================================================
// ORACLE STATE v3.1
// =============================================================================

pub const PriceOracle = struct {
    allocator: std.mem.Allocator,
    config: OracleConfig,

    /// Price history for TWAP calculation
    price_history: std.ArrayListUnmanaged(PricePoint),

    /// Current cached price
    current_price: u128,

    /// Last price update timestamp
    last_update: i64,

    /// Whether oracle is operational
    operational: bool,

    /// v3.1: Reference price for yearly growth calculation
    reference_price: ReferencePrice,

    /// v3.1: Current liquidity (USD, 18 decimals)
    current_liquidity: u128,

    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) PriceOracle {
        return .{
            .allocator = allocator,
            .config = .{},
            .price_history = .{},
            .current_price = DEFAULT_TRI_PRICE_USD,
            .last_update = std.time.timestamp(),
            .operational = true,
            .reference_price = .{ .price = DEFAULT_TRI_PRICE_USD, .timestamp = std.time.timestamp() },
            .current_liquidity = MIN_LIQUIDITY_USD, // Default liquidity
            .mutex = .{},
        };
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: OracleConfig) PriceOracle {
        var oracle = PriceOracle.init(allocator);
        oracle.config = config;
        return oracle;
    }

    pub fn deinit(self: *PriceOracle) void {
        self.price_history.deinit(self.allocator);
    }

    // =========================================================================
    // PRICE QUERIES v3.1
    // =========================================================================

    /// v3.1: Get current TWAP price with timestamp
    pub fn getTwiPriceWithTimestamp(self: *PriceOracle) struct {
        price: u128,
        valid: bool,
        timestamp: i64,
    } {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.operational or self.price_history.items.len < self.config.min_twap_points) {
            return .{
                .price = DEFAULT_TRI_PRICE_USD,
                .valid = false,
                .timestamp = self.last_update,
            };
        }

        const now = std.time.timestamp();

        // v3.1: Check liquidity first
        if (self.config.require_liquidity_check) {
            if (self.current_liquidity < self.config.min_liquidity_usd) {
                // Low liquidity = invalid
                return .{
                    .price = self.current_price,
                    .valid = false,
                    .timestamp = self.last_update,
                };
            }
        }

        // Check if prices are stale
        var valid_count: usize = 0;
        for (self.price_history.items) |point| {
            if (point.isValid(now, self.config.staleness_threshold_secs)) {
                valid_count += 1;
            }
        }

        if (valid_count == 0) {
            return .{
                .price = self.current_price,
                .valid = false,
                .timestamp = self.last_update,
            };
        }

        // v3.1: Check price movement cap
        if (self.price_history.items.len >= 2) {
            const last_price = self.price_history.items[self.price_history.items.len - 1].price;
            if (self.current_price > last_price) {
                const increase_bps = (@as(u256, self.current_price) -% @as(u256, last_price)) * 10000 / @as(u256, last_price);
                if (increase_bps > self.config.max_price_move_per_update_bps) {
                    // Price moved too much - cap at last valid price
                    return .{
                        .price = last_price,
                        .valid = false,
                        .timestamp = self.last_update,
                    };
                }
            }
        }

        return .{
            .price = self.current_price,
            .valid = true,
            .timestamp = self.last_update,
        };
    }

    /// Get current TWAP price
    pub fn getTwiPrice(self: *PriceOracle) struct { price: u128, valid: bool } {
        const result = self.getTwiPriceWithTimestamp();
        return .{ .price = result.price, .valid = result.valid };
    }

    /// v3.1: Get reference price for yearly growth calculation
    pub fn getReferencePrice(self: *PriceOracle) struct { price: u128, timestamp: i64 } {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .price = self.reference_price.price,
            .timestamp = self.reference_price.timestamp,
        };
    }

    /// v3.1: Get current liquidity (USD)
    pub fn getCurrentLiquidity(self: *PriceOracle) u128 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.current_liquidity;
    }

    /// v3.1: Update current liquidity (called from DEX integration)
    pub fn updateLiquidity(self: *PriceOracle, liquidity_usd: u128) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.current_liquidity = liquidity_usd;
    }

    /// v3.1: Update reference price for yearly growth tracking
    pub fn updateReferencePrice(self: *PriceOracle, price: u128) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (price == 0) return error.InvalidPrice;
        self.reference_price = .{
            .price = price,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Check if observed price deviates from expected
    pub fn checkDeviation(self: *PriceOracle, observed_price: u256, expected_price: u256) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (expected_price == 0) return true; // Can't calculate deviation

        const diff = if (observed_price > expected_price)
            observed_price - expected_price
        else
            expected_price - observed_price;

        const deviation_bps = (diff * 10000) / expected_price;
        return deviation_bps <= self.config.max_deviation_bps;
    }

    /// Get maximum deviation in basis points
    pub fn maxDeviationBps(self: *PriceOracle) u256 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.config.max_deviation_bps;
    }

    /// Check if oracle is operational
    pub fn isOperational(self: *PriceOracle) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.operational;
    }

    // =========================================================================
    // PRICE UPDATES v3.1
    // =========================================================================

    /// v3.1: Update price feed with liquidity data
    pub fn updatePrice(self: *PriceOracle, price: u128, liquidity: u128) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (price == 0) return error.InvalidPrice;

        const now = std.time.timestamp();

        // Add to history with liquidity
        try self.price_history.append(self.allocator, .{
            .price = price,
            .timestamp = now,
            .volume = 0,
            .liquidity = liquidity,
        });

        // Update current liquidity
        self.current_liquidity = liquidity;

        // Trim old history outside TWAP window
        const cutoff_time = now - @as(i64, @intCast(self.config.twap_window_secs));
        while (self.price_history.items.len > 0 and
            self.price_history.items[0].timestamp < cutoff_time)
        {
            _ = self.price_history.orderedRemove(0);
        }

        // Update current price (TWAP average)
        if (self.price_history.items.len > 0) {
            var sum: u256 = 0;
            for (self.price_history.items) |point| {
                sum += point.price;
            }
            self.current_price = @intCast(sum / self.price_history.items.len);
        } else {
            self.current_price = price;
        }

        self.last_update = now;
        self.operational = true;
    }

    /// Update price feed (legacy, without liquidity - uses current liquidity)
    pub fn updatePriceLegacy(self: *PriceOracle, price: u128) !void {
        try self.updatePrice(price, self.current_liquidity);
    }

    /// Mark oracle as non-operational (emergency)
    pub fn pause(self: *PriceOracle) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.operational = false;
    }

    /// Resume oracle operation (unpause)
    pub fn unpause(self: *PriceOracle) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.operational = true;
    }

    // =========================================================================
    // USD CONVERSION HELPERS
    // =========================================================================

    /// Convert TRI amount to USD (18 decimals)
    pub fn triToUsd(self: *PriceOracle, tri_amount: u128) u128 {
        const result = self.getTwiPrice();
        const price = if (result.valid) result.price else DEFAULT_TRI_PRICE_USD;

        // USD = TRI * price
        const result_usd: u256 = @as(u256, tri_amount) * @as(u256, price);
        return @intCast(result_usd / 1_000_000_000_000_000_000);
    }

    /// Convert USD amount to TRI (18 decimals)
    pub fn usdToTri(self: *PriceOracle, usd_amount: u128) u128 {
        const result = self.getTwiPrice();
        const price = if (result.valid) result.price else DEFAULT_TRI_PRICE_USD;

        if (price == 0) return 0;

        // TRI = USD / price
        const result_tri: u256 = (@as(u256, usd_amount) * 1_000_000_000_000_000_000) / @as(u256, price);
        return @intCast(result_tri);
    }

    /// Get oracle statistics
    pub const Stats = struct {
        current_price: u128,
        last_update: i64,
        operational: bool,
        history_size: usize,
        twap_window_secs: u64,
    };

    pub fn getStats(self: *PriceOracle) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();

        return .{
            .current_price = self.current_price,
            .last_update = self.last_update,
            .operational = self.operational,
            .history_size = self.price_history.items.len,
            .twap_window_secs = self.config.twap_window_secs,
        };
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "oracle initialization" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    try std.testing.expect(oracle.isOperational());
    try std.testing.expectEqual(DEFAULT_TRI_PRICE_USD, oracle.current_price);
}

test "oracle price update" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    // Update price to $2.00
    try oracle.updatePriceLegacy(2 * 1e18);

    const stats = oracle.getStats();
    try std.testing.expectEqual(@as(u128, 2 * 1e18), stats.current_price);
    try std.testing.expectEqual(@as(usize, 1), stats.history_size);
}

test "oracle twap calculation" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.initWithConfig(allocator, .{
        .max_deviation_bps = 500,
        .twap_window_secs = 3600,
        .staleness_threshold_secs = 300,
        .min_twap_points = 2,
    });
    defer oracle.deinit();

    // Add multiple price points
    try oracle.updatePriceLegacy(1 * 1e18);
    try oracle.updatePriceLegacy(2 * 1e18);
    try oracle.updatePriceLegacy(3 * 1e18);

    // TWAP should be average: (1 + 2 + 3) / 3 = 2
    const result = oracle.getTwiPrice();
    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u128, 2 * 1e18), result.price);
}

test "oracle deviation check - within tolerance" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    try oracle.updatePriceLegacy(100 * 1e18); // $100

    // 5% deviation = $105, should pass
    const within = oracle.checkDeviation(105 * 1e18, 100 * 1e18);
    try std.testing.expect(within);
}

test "oracle deviation check - exceeds tolerance" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    try oracle.updatePriceLegacy(100 * 1e18); // $100

    // 6% deviation = $106, should fail (max 5%)
    const exceeds = oracle.checkDeviation(106 * 1e18, 100 * 1e18);
    try std.testing.expect(!exceeds);
}

test "oracle tri to usd conversion" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    // Need at least 2 price points for valid TWAP
    try oracle.updatePriceLegacy(2 * 1_000_000_000_000_000_000); // $2 per TRI
    try oracle.updatePriceLegacy(2 * 1_000_000_000_000_000_000); // $2 per TRI

    // 100 TRI @ $2 = $200
    const usd = oracle.triToUsd(100 * 1_000_000_000_000_000_000);
    try std.testing.expectEqual(@as(u128, 200) * 1_000_000_000_000_000_000, usd);
}

test "oracle usd to tri conversion" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    // Need at least 2 price points for valid TWAP
    try oracle.updatePriceLegacy(2 * 1_000_000_000_000_000_000); // $2 per TRI
    try oracle.updatePriceLegacy(2 * 1_000_000_000_000_000_000); // $2 per TRI

    // $200 @ $2/TRI = 100 TRI
    const tri = oracle.usdToTri(200 * 1_000_000_000_000_000_000);
    try std.testing.expectEqual(@as(u128, 100) * 1_000_000_000_000_000_000, tri);
}

test "oracle pause and resume" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.init(allocator);
    defer oracle.deinit();

    try std.testing.expect(oracle.isOperational());

    oracle.pause();
    try std.testing.expect(!oracle.isOperational());

    oracle.unpause();
    try std.testing.expect(oracle.isOperational());
}

test "oracle stale price handling" {
    const allocator = std.testing.allocator;

    var oracle = PriceOracle.initWithConfig(allocator, .{
        .staleness_threshold_secs = 1, // 1 second staleness
        .min_twap_points = 1,
    });
    defer oracle.deinit();

    try oracle.updatePriceLegacy(100 * 1e18);

    // Immediately check - should be valid
    var result = oracle.getTwiPrice();
    try std.testing.expect(result.valid);

    // Wait 2 seconds - price should be stale
    std.Thread.sleep(2 * std.time.ns_per_s);

    result = oracle.getTwiPrice();
    try std.testing.expect(!result.valid); // Stale, not valid
}
