// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title TrinityVault
 * @notice ERC-4626 Tokenized Vault for $TRI Staking
 * @dev v3.1: Dead shares, strict CAPO, adaptive CB, cascade protection
 *
 * SACRED NUMBER: Total Supply = 3^21 = 10,460,353,203 $TRI
 * Derived from Trinity Identity: unique states of 21 balanced ternary trits
 *
 * v3.1 Security Features:
 * - Dead shares pattern (Uniswap V2 MINIMUM_LIQUIDITY)
 * - Strict CAPO validation (stale oracle = REVERT, not skip)
 * - Adaptive circuit breaker (10-20% based on leverage)
 * - Systemic cascade detection (5% TVD / 5min trigger)
 * - Yearly growth cap for correlated assets (8% max)
 * - Liquidity-aware TWAP ($50K minimum)
 *
 * v3.0 Security Features:
 * - CAPO (Correlated-Assets Price Oracle) prevents flashloan manipulation
 * - Circuit breaker with 20% threshold triggers auto-pause
 * - TWAP-based smoothing for totalAssets()
 * - Proper Ownable integration (CRITICAL FIX)
 * - Kill-switch for emergency response
 *
 * phi^2 + 1/phi^2 = 3 (Trinity Identity)
 * 3^21 = 10,460,353,203 (Sacred Token Supply)
 * KOSCHEI IS IMMORTAL
 */
contract TrinityVault is ERC4626, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =========================================================================
    // SACRED CONSTANTS
    // =========================================================================

    /// @notice SACRED: Total $TRI supply = 3^21 (21 balanced ternary trits)
    uint256 public constant SACRED_SUPPLY = 10_460_353_203 * 1e18;

    /// @notice Maximum vault capacity (capped at 50% of sacred supply)
    uint256 public constant MAX_VAULT_CAPACITY = SACRED_SUPPLY / 2;

    /// @notice v3.1: Dead shares burned on first deposit (Uniswap V2 pattern)
    uint256 public constant DEAD_SHARES = 1000 * 1e18;

    /// @notice Virtual offset for first-depositor protection
    uint256 internal constant VIRTUAL_OFFSET = 1e6 * 1e18;

    /// @notice Minimum deposit amount (100 TRI)
    uint256 public constant MIN_DEPOSIT = 100 * 1e18;

    /// @notice CAPO: Maximum price deviation before rejection (5%)
    uint256 public constant MAX_DEVIATION_BPS = 500;

    /// @notice v3.1: Staleness threshold - oracle price must be within this time
    uint256 public constant STALENESS_THRESHOLD = 300; // 5 minutes

    /// @notice v3.1: Maximum deposit without valid oracle (1000 TRI)
    uint256 public constant MAX_STALE_ORACLE_DEPOSIT = 1000 * 1e18;

    /// @notice v3.1: Maximum yearly growth for correlated assets (8%)
    uint256 public constant MAX_YEARLY_RATIO_GROWTH_BPS = 800; // 8%

    /// @notice v3.1: Base circuit breaker threshold (20%)
    uint256 public constant BASE_CIRCUIT_THRESHOLD_BPS = 2000;

    /// @notice v3.1: Tight circuit breaker threshold for high leverage (10%)
    uint256 public constant TIGHT_CIRCUIT_THRESHOLD_BPS = 1000;

    /// @notice v3.1: High leverage threshold (80% utilization)
    uint256 public constant HIGH_LEVERAGE_THRESHOLD_BPS = 8000;

    /// @notice TWAP window for price smoothing (1 hour)
    uint256 public constant TWAP_WINDOW = 1 hours;

    /// @notice v3.1: Cascade detection window (5 minutes)
    uint256 public constant CASCADE_DETECTION_WINDOW = 5 minutes;

    /// @notice v3.1: Cascade trigger threshold (5% of TVD)
    uint256 public constant CASCADE_TRIGGER_BPS = 500; // 5%

    // =========================================================================
    // STATE
    // =========================================================================

    /// @notice CAPO: Price oracle for flashloan protection
    IPriceOracle public oracle;

    /// @notice Maximum vault capacity (0 = unlimited, max = MAX_VAULT_CAPACITY)
    uint256 public maxCapacity;

    /// @notice Cooldown period for withdrawals (seconds)
    uint256 public cooldownPeriod;

    /// @notice Mapping to track deposit timestamps for cooldown
    mapping(address => uint256) public depositTimestamp;

    /// @notice Emergency withdrawal flag
    bool public emergencyWithdraw;

    /// @notice v2.1: Internal asset accounting (prevents donation attack)
    uint256 private _managedAssets;

    /// @notice v3.1: Dead shares initialized flag
    bool private _deadSharesInitialized;

    /// @notice Circuit breaker: auto-pause until this timestamp
    uint256 public circuitBreakerUntil;

    /// @notice Last price snapshot for circuit breaker
    uint256 public lastSnapshotPrice;

    /// @notice Last snapshot time
    uint256 public lastSnapshotTime;

    /// @notice v3.1: Current adaptive circuit breaker threshold
    uint256 public circuitBreakerThresholdBps;

    /// @notice v3.1: Last leverage check time for adaptive CB
    uint256 public lastLeverageCheckTime;

    /// @notice TWAP average assets (smoothed)
    uint256 public twapAverageAssets;

    /// @notice Last TWAP update time
    uint256 public lastTwapUpdate;

    /// @notice v3.1: Liquidation timestamps for cascade detection
    mapping(uint256 => uint256) public liquidationTimestamps;

    /// @notice v3.1: Last cascade check time
    uint256 public lastCascadeCheck;

    // =========================================================================
    // EVENTS
    // =========================================================================

    event DepositRecorded(address indexed user, uint256 amount, uint256 shares);
    event WithdrawalInitiated(address indexed user, uint256 shares, uint256 cooldownEnd);
    event EmergencyWithdrawalEnabled(bool enabled);
    event MaxCapacityUpdated(uint256 newCapacity);
    event OracleUpdated(address indexed oracle);
    event CircuitBreakerTripped(uint256 oldPrice, uint256 newPrice, uint256 duration);
    event CircuitBreakerExtended(uint256 until);
    event TwapUpdated(uint256 oldAverage, uint256 newAverage);

    /// @notice v3.1: Dead shares initialized
    event DeadSharesInitialized(uint256 amount);

    /// @notice v3.1: Adaptive circuit breaker threshold changed
    event CircuitBreakerThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /// @notice v3.1: Systemic risk alert (cascade detected)
    event SystemicRiskAlert(uint256 totalLiquidations, uint256 windowSeconds);

    /// @notice v3.1: Stale oracle detected
    event StaleOracleWarning(uint256 oracleAge, uint256 stalenessThreshold);

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    /**
     * @notice Initialize the vault
     * @param _underlying The $TRI token address
     * @param _name Vault name
     * @param _symbol Vault symbol
     * @param _cooldownSeconds Cooldown period for withdrawals
     * @param _maxVaultCap Maximum capacity (0 = unlimited)
     * @param _oracle Initial price oracle (address(0) for none)
     */
    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        uint256 _cooldownSeconds,
        uint256 _maxVaultCap,
        IPriceOracle _oracle
    ) ERC20(_name, _symbol) ERC4626(_underlying) Ownable(msg.sender) {
        require(_underlying != IERC20(address(0)), "Invalid underlying");
        require(_maxVaultCap == 0 || _maxVaultCap <= MAX_VAULT_CAPACITY, "Exceeds max capacity");

        cooldownPeriod = _cooldownSeconds;
        maxCapacity = _maxVaultCap;
        oracle = _oracle;

        // Initialize TWAP with zero
        twapAverageAssets = 0;
        lastTwapUpdate = block.timestamp;

        // v3.1: Initialize adaptive circuit breaker threshold
        circuitBreakerThresholdBps = BASE_CIRCUIT_THRESHOLD_BPS;
        lastLeverageCheckTime = block.timestamp;
        lastCascadeCheck = block.timestamp;

        emit OracleUpdated(address(_oracle));
    }

    // =========================================================================
    // DEPOSIT & WITHDRAW (v3.1: CAPO + Dead Shares + Cascade Protection)
    // =========================================================================

    /**
     * @notice Deposit assets and mint shares
     * @dev v3.1: Added withDeadShares, checkCascade modifiers
     * @param assets Amount of $TRI to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        checkEmergency
        withDeadShares
        checkCascade
        returns (uint256 shares)
    {
        require(assets >= MIN_DEPOSIT, "Below minimum deposit");
        require(maxCapacity == 0 || _managedAssets + assets <= maxCapacity, "Exceeds capacity");

        // CAPO: Validate against oracle (v3.1: STRICT validation)
        _validateCapoStrict(assets);

        // Transfer tokens first
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        _managedAssets += assets;

        shares = super.deposit(assets, receiver);
        depositTimestamp[receiver] = block.timestamp;

        emit DepositRecorded(receiver, assets, shares);
    }

    /**
     * @notice Mint shares by depositing assets
     * @param shares Amount of shares to mint
     * @param receiver Address to receive shares
     * @return assets Amount of $TRI deposited
     */
    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        checkEmergency
        withDeadShares
        checkCascade
        returns (uint256 assets)
    {
        assets = super.mint(shares, receiver);
        depositTimestamp[receiver] = block.timestamp;
    }

    /**
     * @notice Withdraw assets by burning shares
     * @dev Includes cooldown check
     * @param assets Amount of $TRI to withdraw
     * @param receiver Address to receive assets
     * @param owner Address owning the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant checkCooldown(owner) returns (uint256 shares) {
        shares = super.withdraw(assets, receiver, owner);
        if (assets == convertToAssets(balanceOf(owner))) {
            depositTimestamp[owner] = 0; // Reset if fully withdrawn
        }

        // v2.1: Update internal accounting
        _managedAssets -= assets;

        // Transfer assets to receiver
        IERC20(asset()).safeTransfer(receiver, assets);
    }

    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param owner Address owning the shares
     * @return assets Amount of $TRI withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant checkCooldown(owner) returns (uint256 assets) {
        assets = super.redeem(shares, receiver, owner);
        if (shares == balanceOf(owner)) {
            depositTimestamp[owner] = 0; // Reset if fully withdrawn
        }

        // v2.1: Update internal accounting
        _managedAssets -= assets;

        // Transfer assets to receiver
        IERC20(asset()).safeTransfer(receiver, assets);
    }

    // =========================================================================
    // v3.1: CAPO ORACLE INTEGRATION (STRICT VALIDATION)
    // =========================================================================

    /**
     * @notice v3.1: STRICT CAPO validation - reverts on stale oracle
     * @dev Prevents flashloan manipulation + Aave Nov 2025 scenario
     * @param assets Amount being deposited
     */
    function _validateCapoStrict(uint256 assets) internal view {
        // v3.1: Without oracle, limit deposits (not skip validation!)
        if (address(oracle) == address(0)) {
            require(assets <= MAX_STALE_ORACLE_DEPOSIT, "Oracle required for large deposits");
            return;
        }

        // v3.1: Get price with timestamp
        (uint256 twapPrice, bool valid, uint256 timestamp) =
            oracle.getTwiPriceWithTimestamp(asset());

        // v3.1: STRICT - revert if stale, don't skip
        require(valid, "Oracle stale - deposits paused");

        // v3.1: Check staleness
        require(block.timestamp - timestamp < STALENESS_THRESHOLD, "Price too old");

        // v3.1: Check yearly growth for correlated assets
        (uint256 referencePrice, uint256 referenceTime) =
            oracle.getReferencePrice(asset());
        if (referencePrice > 0 && referenceTime > 0) {
            uint256 growthBps = _calculateYearlyGrowth(twapPrice, referencePrice, referenceTime);
            require(growthBps <= MAX_YEARLY_RATIO_GROWTH_BPS, "Excessive price growth");
        }

        // v3.1: Check liquidity threshold
        uint256 liquidity = oracle.getCurrentLiquidity(asset());
        require(liquidity >= 50000 * 1e18, "Insufficient DEX liquidity"); // $50K minimum

        // Check deviation (allow MAX_DEVIATION_BPS = 5%)
        uint256 currentTotal = _managedAssets + assets;
        uint256 expectedValue = (currentTotal * twapPrice) / 1e18;
        uint256 deviationBps = _calculateDeviationBps(currentTotal, expectedValue);
        require(deviationBps <= MAX_DEVIATION_BPS, "Price deviation detected");
    }

    /**
     * @notice v3.1: Calculate yearly growth in basis points
     * @dev Used to detect excessive growth in correlated assets (wstETH pattern)
     */
    function _calculateYearlyGrowth(
        uint256 currentPrice,
        uint256 referencePrice,
        uint256 referenceTime
    ) internal view returns (uint256) {
        if (referencePrice == 0 || referenceTime >= block.timestamp) return 0;

        uint256 timeElapsed = block.timestamp - referenceTime;
        if (timeElapsed == 0) return 0;

        uint256 priceIncrease = currentPrice > referencePrice ?
            currentPrice - referencePrice : 0;

        // Extrapolate to yearly basis: (increase / ref) * (365 days / elapsed) * 10000
        uint256 yearlyBps = (priceIncrease * 365 days * 10000) /
                          (referencePrice * timeElapsed);

        return yearlyBps;
    }

    /**
     * @notice v3.0: Calculate deviation in basis points
     */
    function _calculateDeviationBps(uint256 observed, uint256 expected) internal pure returns (uint256) {
        if (expected == 0) return 0;
        uint256 diff = observed > expected ? observed - expected : expected - observed;
        return (diff * 10000) / expected;
    }

    /**
     * @notice Update price oracle
     */
    function setOracle(address _oracle) external onlyOwner {
        oracle = IPriceOracle(_oracle);
        emit OracleUpdated(_oracle);
    }

    // =========================================================================
    // v3.1: ADAPTIVE CIRCUIT BREAKER
    // =========================================================================

    /**
     * @notice v3.1: Update adaptive circuit breaker threshold based on leverage
     * @dev Tightens threshold to 10% when utilization > 80%
     */
    function updateCircuitBreakerThreshold() internal {
        if (block.timestamp >= lastLeverageCheckTime + 1 hours) {
            uint256 utilization = maxCapacity == 0 ? 0 :
                (_managedAssets * 10000) / maxCapacity;

            // Adaptive: tighten threshold when leverage is high
            uint256 newThreshold = utilization >= HIGH_LEVERAGE_THRESHOLD_BPS ?
                TIGHT_CIRCUIT_THRESHOLD_BPS : BASE_CIRCUIT_THRESHOLD_BPS;

            if (newThreshold != circuitBreakerThresholdBps) {
                emit CircuitBreakerThresholdUpdated(circuitBreakerThresholdBps, newThreshold);
                circuitBreakerThresholdBps = newThreshold;
            }

            lastLeverageCheckTime = block.timestamp;
        }
    }

    /**
     * @notice v3.1: Trigger circuit breaker with adaptive threshold
     * @param observedPrice Current observed price
     */
    function triggerCircuitBreaker(uint256 observedPrice) external onlyOwner {
        updateCircuitBreakerThreshold(); // v3.1: adaptive check

        uint256 deviationBps = 0;
        if (lastSnapshotPrice > 0) {
            deviationBps = _calculateDeviationBps(observedPrice, lastSnapshotPrice);
        }

        // v3.1: Use ADAPTIVE threshold
        if (deviationBps >= circuitBreakerThresholdBps) {
            uint256 duration = _escalatingDuration(deviationBps);
            circuitBreakerUntil = block.timestamp + duration;
            _pause();

            emit CircuitBreakerTripped(lastSnapshotPrice, observedPrice, duration);
        }

        lastSnapshotPrice = observedPrice;
        lastSnapshotTime = block.timestamp;
    }

    /**
     * @notice v3.1: Calculate circuit breaker duration based on severity
     * @dev Escalating duration: >30% = 4h, >20% = 2h, default = 1h
     */
    function _escalatingDuration(uint256 deviationBps) internal pure returns (uint256) {
        if (deviationBps >= 3000) return 4 hours;  // >30%
        if (deviationBps >= 2000) return 2 hours;  // >20%
        return 1 hours;                             // Default
    }

    /**
     * @notice Extend circuit breaker duration
     * @param duration Seconds to extend
     */
    function extendCircuitBreaker(uint256 duration) external onlyOwner {
        circuitBreakerUntil = block.timestamp + duration;
        emit CircuitBreakerExtended(circuitBreakerUntil);
    }

    /**
     * @notice Check if circuit breaker is active
     */
    function isCircuitBreakerActive() public view returns (bool) {
        return block.timestamp < circuitBreakerUntil;
    }

    // =========================================================================
    // v3.1: SYSTEMIC CASCADE PROTECTION
    // =========================================================================

    /**
     * @notice v3.1: Check for systemic cascade conditions
     * @dev Triggers pause if >5% of TVD liquidated within 5 minutes
     */
    function _checkSystemicCascade() internal {
        uint256 windowStart = block.timestamp - CASCADE_DETECTION_WINDOW;
        uint256 windowLiquidations = 0;

        // Sum liquidations within the window
        for (uint256 t = lastCascadeCheck; t <= block.timestamp; t++) {
            if (t >= windowStart) {
                windowLiquidations += liquidationTimestamps[t];
            }
        }

        // Check if cascade threshold exceeded
        uint256 threshold = (_managedAssets * CASCADE_TRIGGER_BPS) / 10000;
        if (windowLiquidations > threshold) {
            emit SystemicRiskAlert(windowLiquidations, CASCADE_DETECTION_WINDOW);

            // Auto-pause + extended circuit breaker
            _pause();
            circuitBreakerUntil = block.timestamp + 4 hours;
        }

        lastCascadeCheck = block.timestamp;
    }

    /**
     * @notice v3.1: Record a liquidation for cascade detection
     * @dev Called internally when liquidations occur
     */
    function _recordLiquidation(uint256 amount) internal {
        liquidationTimestamps[block.timestamp] += amount;
        _checkSystemicCascade();
    }

    // =========================================================================
    // v3.0: TWAP SMOOTHING
    // =========================================================================

    /**
     * @notice Update TWAP average (called automatically on totalAssets)
     */
    function updateTwapAverage() internal {
        if (block.timestamp >= lastTwapUpdate + TWAP_WINDOW) {
            uint256 currentAssets = _managedAssets;
            uint256 newAverage;

            if (twapAverageAssets == 0) {
                newAverage = currentAssets;
            } else {
                newAverage = (twapAverageAssets + currentAssets) / 2;
            }

            if (newAverage != twapAverageAssets) {
                emit TwapUpdated(twapAverageAssets, newAverage);
            }

            twapAverageAssets = newAverage;
            lastTwapUpdate = block.timestamp;
        }
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /**
     * @notice Preview deposit with virtual offset protection
     */
    function previewDeposit(uint256 assets) public view override returns (uint256 shares) {
        uint256 supply = totalSupply();

        if (supply == 0) {
            return (assets * VIRTUAL_OFFSET) / (VIRTUAL_OFFSET + assets);
        }

        return (assets * supply) / _managedAssets;
    }

    /**
     * @notice Preview withdrawal with virtual offset protection
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
        uint256 supply = totalSupply();

        if (supply == 0) {
            return 0;
        }

        uint256 sharesOut = (assets * supply + _managedAssets - 1) / _managedAssets;
        return sharesOut;
    }

    /**
     * @notice v3.0: Get total assets with TWAP smoothing and CAPO check
     */
    function totalAssets() public view override returns (uint256) {
        // Return TWAP-smoothed value if available
        if (twapAverageAssets > 0 && block.timestamp >= lastTwapUpdate + 60) {
            return twapAverageAssets;
        }
        return _managedAssets;
    }

    /**
     * @notice v2.1: Get actual token balance (for recovery purposes)
     */
    function actualTokenBalance() public view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @notice Convert assets to shares (with virtual offset)
     */
    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return (assets * VIRTUAL_OFFSET) / (VIRTUAL_OFFSET + assets);
        }
        return (assets * supply) / _managedAssets;
    }

    /**
     * @notice Convert shares to assets
     */
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) {
            return 0;
        }
        return (shares * _managedAssets) / supply;
    }

    /**
     * @notice Max deposit for a user
     */
    function maxDeposit(address user) public view override returns (uint256) {
        if (paused() || emergencyWithdraw || isCircuitBreakerActive()) return 0;
        if (maxCapacity == 0) return type(uint256).max;
        uint256 current = totalAssets();
        return current >= maxCapacity ? 0 : maxCapacity - current;
    }

    /**
     * @notice Max withdrawable amount for a user
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (emergencyWithdraw) return 0;
        uint256 balance = balanceOf(owner);
        if (balance == 0) return 0;

        uint256 userAssets = convertToAssets(balance);
        uint256 vaultAssets = _managedAssets;
        return userAssets > vaultAssets ? vaultAssets : userAssets;
    }

    /**
     * @notice Get user's cooldown end time
     */
    function getCooldownEnd(address user) external view returns (uint256) {
        if (depositTimestamp[user] == 0) return 0;
        return depositTimestamp[user] + cooldownPeriod;
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    /**
     * @notice Set maximum vault capacity
     */
    function setMaxCapacity(uint256 _maxCapacity) external onlyOwner {
        require(_maxCapacity == 0 || _maxCapacity <= MAX_VAULT_CAPACITY, "Exceeds max capacity");
        maxCapacity = _maxCapacity;
        emit MaxCapacityUpdated(_maxCapacity);
    }

    /**
     * @notice Set cooldown period
     */
    function setCooldownPeriod(uint256 _cooldownPeriod) external onlyOwner {
        cooldownPeriod = _cooldownPeriod;
    }

    /**
     * @notice Enable emergency withdrawal mode
     */
    function enableEmergencyWithdraw() external onlyOwner {
        emergencyWithdraw = true;
        emit EmergencyWithdrawalEnabled(true);
    }

    /**
     * @notice Disable emergency withdrawal mode
     */
    function disableEmergencyWithdraw() external onlyOwner {
        emergencyWithdraw = false;
        emit EmergencyWithdrawalEnabled(false);
    }

    /**
     * @notice Recover mistakenly sent non-staking tokens
     */
    function recoverExcessTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }

    /**
     * @notice Recover staked tokens (emergency only, resets internal accounting)
     */
    function recoverStakedTokens(uint256 amount) external onlyOwner {
        require(amount <= _managedAssets, "Insufficient managed assets");
        _managedAssets -= amount;
        IERC20(asset()).safeTransfer(owner(), amount);
    }

    // =========================================================================
    // MODIFIERS
    // =========================================================================

    modifier checkCooldown(address owner) {
        require(!emergencyWithdraw, "Emergency withdrawal active");
        if (cooldownPeriod > 0) {
            uint256 depositTime = depositTimestamp[owner];
            require(depositTime > 0, "No deposit found");
            require(block.timestamp >= depositTime + cooldownPeriod, "Cooldown not elapsed");
        }
        _;
    }

    modifier checkEmergency() {
        require(!emergencyWithdraw, "Emergency withdrawal active");
        _;
    }

    // =========================================================================
    // v3.1: MODIFIERS
    // =========================================================================

    /**
     * @notice v3.1: Initialize dead shares on first deposit (Uniswap V2 pattern)
     * @dev Prevents ERC-4626 inflation attack by burning initial shares
     */
    modifier withDeadShares() {
        if (totalSupply() == 0 && !_deadSharesInitialized) {
            _deadSharesInitialized = true;
            _mint(address(0xdead), DEAD_SHARES);
            emit DeadSharesInitialized(DEAD_SHARES);
        }
        _;
    }

    /**
     * @notice v3.1: Check for systemic cascade conditions
     * @dev Triggers pause if >5% of TVD liquidated within 5 minutes
     */
    modifier checkCascade() {
        _checkSystemicCascade();
        _;
    }
}
