// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @notice Correlated-Assets Price Oracle (CAPO) interface v3.1
 * @dev Prevents ERC-4626 totalAssets() manipulation via flashloans
 *
 * v3.1 UPDATES:
 * - Added getTwiPriceWithTimestamp for staleness detection
 * - Added getReferencePrice for yearly growth calculation
 * - Added getCurrentLiquidity for liquidity-aware TWAP
 *
 * Research sources:
 * - OpenZeppelin 2025: ERC-4626 security best practices
 * - Aave November 2025: CAPO timestamp mismatch incident
 * - October 2025: Circuit breaker improvements
 *
 * phi^2 + 1/phi^2 = 3 (Trinity Identity)
 * KOSCHEI IS IMMORTAL
 */
interface IPriceOracle {
    /**
     * @notice Get TWAP price for an asset
     * @param asset Address of the asset
     * @return price Price in USD (18 decimals, e.g., 1e18 = $1.00)
     * @return valid Whether the price is valid (not stale)
     */
    function getTwiPrice(address asset) external view returns (uint256 price, bool valid);

    /**
     * @notice v3.1: Get TWAP price with timestamp for staleness validation
     * @param asset Address of the asset
     * @return price Price in USD (18 decimals)
     * @return valid Whether the price is valid
     * @return timestamp When the price was last updated
     */
    function getTwiPriceWithTimestamp(address asset) external view returns (
        uint256 price,
        bool valid,
        uint256 timestamp
    );

    /**
     * @notice v3.1: Get reference price for yearly growth calculation
     * Used to detect excessive growth in correlated assets (e.g., wstETH)
     * @param asset Address of the asset
     * @return referencePrice Reference price for growth calculation
     * @return referenceTime Timestamp of reference price
     */
    function getReferencePrice(address asset) external view returns (
        uint256 referencePrice,
        uint256 referenceTime
    );

    /**
     * @notice v3.1: Get current liquidity in the underlying DEX pool
     * Used to validate minimum liquidity threshold ($50K minimum)
     * @param asset Address of the asset
     * @return liquidityUSD Current pool liquidity in USD (18 decimals)
     */
    function getCurrentLiquidity(address asset) external view returns (uint256 liquidityUSD);

    /**
     * @notice Check if observed price deviates from expected
     * @param observedPrice Price from vault's totalAssets()
     * @param expectedPrice Price from oracle
     * @return withinTolerance True if deviation acceptable
     */
    function checkDeviation(uint256 observedPrice, uint256 expectedPrice) external view returns (bool);

    /**
     * @notice Get maximum acceptable deviation in basis points
     * @return maxDeviationBps Max deviation (e.g., 500 = 5%)
     */
    function maxDeviationBps() external view returns (uint256);

    /**
     * @notice v3.1: Get maximum price movement per update (basis points)
     * Used to cap single-update price spikes
     * @return maxMoveBps Maximum movement per update (e.g., 1000 = 10%)
     */
    function maxPriceMovePerUpdateBps() external view returns (uint256);

    /**
     * @notice Update price feed (oracle only)
     * @param asset Asset address
     * @param price New price
     */
    function updatePrice(address asset, uint256 price) external;

    /**
     * @notice Check if oracle is operational
     * @return isOperational True if oracle functioning
     */
    function isOperational() external view returns (bool);

    /**
     * @notice v3.1: Get oracle configuration for validation
     * @return minLiquidityUSD Minimum liquidity threshold
     * @return stalenessThreshold Seconds before price considered stale
     * @return maxYearlyGrowthBps Maximum yearly growth for correlated assets
     */
    function getOracleConfig() external view returns (
        uint256 minLiquidityUSD,
        uint256 stalenessThreshold,
        uint256 maxYearlyGrowthBps
    );
}
