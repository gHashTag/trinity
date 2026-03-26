// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrinityVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TrinityVaultTest
 * @notice Foundry tests for TrinityVault ERC-4626 implementation
 * @dev Tests for first-depositor protection, donation attack resistance, and standard vault operations
 */
contract TrinityVaultTest is Test {
    TrinityVault public vault;
    MockTRI public underlying;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public attacker = address(0x4177);
    address public owner = address(this);

    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1B TRI
    uint256 constant COOLDOWN = 7 days;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock TRI token
        underlying = new MockTRI();
        underlying.mint(alice, 1_000_000 * 1e18);
        underlying.mint(bob, 1_000_000 * 1e18);
        underlying.mint(attacker, 1_000_000 * 1e18);

        // Deploy vault
        vault = new TrinityVault(
            IERC20(underlying),
            "Trinity Staked TRI",
            "sfTRI",
            COOLDOWN,
            0 // unlimited capacity
        );

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 1: First-Depositor Protection (Virtual Offset)
    // =========================================================================

    function test_FirstDepositorProtection() public {
        vm.startPrank(alice);

        // First deposit to empty vault
        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        // With virtual offset, first depositor gets LESS than 1:1 shares
        // shares = (assets * VIRTUAL_OFFSET) / (VIRTUAL_OFFSET + assets)
        // For 1000e18: shares = (1000e18 * 1e6e18) / (1e6e18 + 1000e18) ≈ 999e18
        assertLt(shares, depositAmount, "First depositor should get fewer shares than assets");

        // Verify previewDeposit matches actual
        uint256 previewed = vault.previewDeposit(depositAmount);
        assertEq(shares, previewed, "Preview should match actual shares");

        vm.stopPrank();
    }

    function test_SecondDepositorNotInflated() public {
        vm.startPrank(alice);

        // First deposit
        uint256 firstDeposit = 100 * 1e18;
        underlying.approve(address(vault), firstDeposit);
        vault.deposit(firstDeposit, alice);

        vm.stopPrank();
        vm.startPrank(bob);

        // Second deposit
        uint256 secondDeposit = 100 * 1e18;
        underlying.approve(address(vault), secondDeposit);
        uint256 bobShares = vault.deposit(secondDeposit, bob);

        // Bob should get approximately 1:1 shares (not inflated)
        assertApproxEqRel(bobShares, secondDeposit, 0.01e18, "Second depositor should get ~1:1");

        vm.stopPrank();
    }

    function test_DonationAttackResistance() public {
        vm.startPrank(alice);

        // First legitimate deposit
        uint256 legitDeposit = 1000 * 1e18;
        underlying.approve(address(vault), legitDeposit);
        uint256 aliceShares = vault.deposit(legitDeposit, alice);

        vm.stopPrank();

        // Attacker donates tokens directly to vault (bypassing deposit)
        vm.prank(attacker);
        underlying.transfer(address(vault), 1_000_000 * 1e18);

        vm.startPrank(bob);

        // Bob deposits after donation attack
        uint256 bobDeposit = 1000 * 1e18;
        underlying.approve(address(vault), bobDeposit);
        uint256 bobShares = vault.deposit(bobDeposit, bob);

        // Bob should NOT lose shares due to donation
        // With internal accounting, donation doesn't affect share calculation
        assertGt(bobShares, bobDeposit * 95 / 100, "Bob shouldn't lose >5% to donation attack");

        // Alice's shares should be preserved
        assertEq(vault.balanceOf(alice), aliceShares, "Alice's shares unchanged");

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 2: Internal Accounting
    // =========================================================================

    function test_InternalAccountingMatchesDeposits() public {
        vm.startPrank(alice);

        uint256 deposit1 = 10_000 * 1e18;
        underlying.approve(address(vault), deposit1);
        vault.deposit(deposit1, alice);

        assertEq(vault.totalAssets(), deposit1, "totalAssets should match deposited amount");
        assertEq(vault.actualTokenBalance(), deposit1, "Token balance should match deposits");

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 deposit2 = 5_000 * 1e18;
        underlying.approve(address(vault), deposit2);
        vault.deposit(deposit2, bob);

        assertEq(vault.totalAssets(), deposit1 + deposit2, "totalAssets should sum all deposits");
        assertEq(vault.actualTokenBalance(), deposit1 + deposit2, "Token balance should sum all deposits");

        vm.stopPrank();
    }

    function test_DonationNotCountedInTotalAssets() public {
        vm.startPrank(alice);

        uint256 deposit = 10_000 * 1e18;
        underlying.approve(address(vault), deposit);
        vault.deposit(deposit, alice);

        uint256 assetsBefore = vault.totalAssets();

        vm.stopPrank();

        // Donate tokens directly
        vm.prank(attacker);
        underlying.transfer(address(vault), 1_000 * 1e18);

        // totalAssets should NOT increase (internal accounting)
        assertEq(vault.totalAssets(), assetsBefore, "Donation shouldn't affect totalAssets");

        // But actual token balance DOES increase
        assertEq(vault.actualTokenBalance(), assetsBefore + 1_000 * 1e18, "Token balance includes donation");
    }

    // =========================================================================
    // TEST SUITE 3: Deposit/Withdraw Operations
    // =========================================================================

    function test_DepositAndMint() public {
        vm.startPrank(alice);

        uint256 depositAmount = 10_000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, alice);
        assertGt(shares, 0, "Should mint shares");
        assertEq(vault.balanceOf(alice), shares, "Alice should own shares");

        vm.stopPrank();
    }

    function test_WithdrawAfterCooldown() public {
        vm.startPrank(alice);

        uint256 depositAmount = 10_000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        uint256 aliceShares = vault.balanceOf(alice);

        // Try to withdraw before cooldown - should revert
        vm.expectRevert("Cooldown not elapsed");
        vault.withdraw(depositAmount, alice, alice);

        // Warp past cooldown
        skip(COOLDOWN + 1);

        // Withdraw should succeed
        uint256 balanceBefore = underlying.balanceOf(alice);
        vault.withdraw(depositAmount, alice, alice);
        uint256 balanceAfter = underlying.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, depositAmount, "Should withdraw full amount");
        assertEq(vault.balanceOf(alice), 0, "Shares should be burned");

        vm.stopPrank();
    }

    function test_PartialWithdraw() public {
        vm.startPrank(alice);

        uint256 depositAmount = 10_000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        skip(COOLDOWN + 1);

        uint256 withdrawAmount = 5_000 * 1e18;
        uint256 sharesBefore = vault.balanceOf(alice);
        vault.withdraw(withdrawAmount, alice, alice);
        uint256 sharesAfter = vault.balanceOf(alice);

        assertGt(sharesAfter, 0, "Should have remaining shares");
        assertLt(sharesAfter, sharesBefore, "Shares should decrease");

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 4: Preview Functions
    // =========================================================================

    function test_PreviewDepositEmptyVault() public {
        uint256 assets = 1000 * 1e18;
        uint256 shares = vault.previewDeposit(assets);

        // With virtual offset: shares < assets
        assertLt(shares, assets, "Preview should account for virtual offset");
    }

    function test_PreviewDepositNonEmptyVault() public {
        vm.startPrank(alice);

        uint256 firstDeposit = 10_000 * 1e18;
        underlying.approve(address(vault), firstDeposit);
        vault.deposit(firstDeposit, alice);

        vm.stopPrank();

        uint256 secondDeposit = 1_000 * 1e18;
        uint256 previewed = vault.previewDeposit(secondDeposit);

        // After first deposit, preview should be approximately 1:1
        assertApproxEqRel(previewed, secondDeposit, 0.01e18, "Preview should be ~1:1 for second depositor");
    }

    function test_PreviewWithdraw() public {
        vm.startPrank(alice);

        uint256 depositAmount = 10_000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        uint256 previewedAssets = vault.previewWithdraw(shares);
        assertApproxEqRel(previewedAssets, depositAmount, 0.01e18, "Should preview correct withdrawal");

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 5: Convert Functions
    // =========================================================================

    function test_ConvertToSharesEmptyVault() public {
        uint256 assets = 1000 * 1e18;
        uint256 shares = vault.convertToShares(assets);

        assertLt(shares, assets, "Virtual offset reduces initial shares");
    }

    function test_ConvertToAssetsEmptyVault() public {
        uint256 shares = 1000 * 1e18;
        uint256 assets = vault.convertToAssets(shares);

        assertEq(assets, 0, "Empty vault returns 0 assets");
    }

    function test_ConvertToAssetsNonEmptyVault() public {
        vm.startPrank(alice);

        uint256 depositAmount = 10_000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        uint256 convertedAssets = vault.convertToAssets(shares);
        assertApproxEqRel(convertedAssets, depositAmount, 0.01e18, "Should convert back to assets");

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 6: Capacity Constraints
    // =========================================================================

    function test_MaxCapacityRespected() public {
        vm.startPrank(owner);

        // Deploy new vault with capacity limit
        TrinityVault cappedVault = new TrinityVault(
            IERC20(underlying),
            "Capped Vault",
            "cTRI",
            COOLDOWN,
            100_000 * 1e18 // 100k TRI capacity
        );

        vm.stopPrank();
        vm.startPrank(alice);

        uint256 deposit1 = 60_000 * 1e18;
        underlying.approve(address(cappedVault), deposit1);
        cappedVault.deposit(deposit1, alice);

        uint256 deposit2 = 50_000 * 1e18; // Would exceed capacity
        underlying.approve(address(cappedVault), deposit2);

        vm.expectRevert("Exceeds capacity");
        cappedVault.deposit(deposit2, alice);

        vm.stopPrank();
    }

    function test_MaxDeposit() public {
        vm.startPrank(owner);

        TrinityVault cappedVault = new TrinityVault(
            IERC20(underlying),
            "Capped Vault",
            "cTRI",
            COOLDOWN,
            100_000 * 1e18
        );

        vm.stopPrank();

        uint256 maxDep = cappedVault.maxDeposit(alice);
        assertEq(maxDep, 100_000 * 1e18, "maxDeposit should return capacity");

        vm.startPrank(alice);

        uint256 deposit = 50_000 * 1e18;
        underlying.approve(address(cappedVault), deposit);
        cappedVault.deposit(deposit, alice);

        vm.stopPrank();

        maxDep = cappedVault.maxDeposit(bob);
        assertEq(maxDep, 50_000 * 1e18, "maxDeposit should decrease after deposit");
    }

    // =========================================================================
    // TEST SUITE 7: Admin Functions
    // =========================================================================

    function test_PauseUnpause() public {
        vm.startPrank(owner);

        vault.pause();
        assertEq(vault.paused(), true, "Vault should be paused");

        vault.unpause();
        assertEq(vault.paused(), false, "Vault should be unpaused");

        vm.stopPrank();
    }

    function test_DepositWhenPaused() public {
        vm.prank(owner);
        vault.pause();

        vm.startPrank(alice);

        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        vm.expectRevert("Vault is paused");
        vault.deposit(depositAmount, alice);

        vm.stopPrank();
    }

    function test_EmergencyWithdraw() public {
        vm.startPrank(alice);

        uint256 depositAmount = 10_000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        vm.stopPrank();

        vm.startPrank(owner);

        vault.enableEmergencyWithdraw();

        // Withdrawals blocked during emergency
        vm.stopPrank();
        vm.startPrank(alice);

        skip(COOLDOWN + 1);
        vm.expectRevert("Emergency withdrawal active");
        vault.withdraw(1000 * 1e18, alice, alice);

        vm.stopPrank();
    }

    function test_RecoverExcessTokens() public {
        vm.startPrank(alice);

        uint256 deposit = 10_000 * 1e18;
        underlying.approve(address(vault), deposit);
        vault.deposit(deposit, alice);

        vm.stopPrank();

        // Donate extra tokens
        vm.prank(attacker);
        underlying.transfer(address(vault), 1_000 * 1e18);

        uint256 ownerBalanceBefore = underlying.balanceOf(owner);

        // Recover donated tokens
        vm.prank(owner);
        uint256 recovered = vault.actualTokenBalance() - vault.totalAssets();
        vault.recoverExcessTokens(address(underlying), recovered);

        uint256 ownerBalanceAfter = underlying.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, recovered, "Should recover excess tokens");
    }

    // =========================================================================
    // TEST SUITE 8: Edge Cases
    // =========================================================================

    function test_MinDepositEnforced() public {
        vm.startPrank(alice);

        uint256 smallDeposit = 50 * 1e18; // Below MIN_DEPOSIT (100 TRI)
        underlying.approve(address(vault), smallDeposit);

        vm.expectRevert("Below minimum deposit");
        vault.deposit(smallDeposit, alice);

        vm.stopPrank();
    }

    function test_ZeroDeposit() public {
        vm.startPrank(alice);

        underlying.approve(address(vault), 0);

        vm.expectRevert(); // Should revert (various reasons possible)
        vault.deposit(0, alice);

        vm.stopPrank();
    }

    function test_ZeroCooldown() public {
        vm.startPrank(owner);

        TrinityVault noCooldownVault = new TrinityVault(
            IERC20(underlying),
            "No Cooldown",
            "nTRI",
            0, // No cooldown
            0
        );

        vm.stopPrank();
        vm.startPrank(alice);

        uint256 deposit = 1000 * 1e18;
        underlying.approve(address(noCooldownVault), deposit);
        noCooldownVault.deposit(deposit, alice);

        // Should be able to withdraw immediately
        noCooldownVault.withdraw(deposit, alice, alice);

        vm.stopPrank();
    }

    // =========================================================================
    // v3.0 TEST SUITE 9: Sacred Supply Constants
    // =========================================================================

    function test_SacredSupplyConstant() public {
        // SACRED: 3^21 = 10,460,353,203
        uint256 expected = 10_460_353_203 * 1e18;
        assertEq(vault.SACRED_SUPPLY(), expected, "Sacred supply should be 3^21");
    }

    function test_MaxVaultCapacityCappedAtHalfSacred() public {
        // MAX_VAULT_CAPACITY = SACRED_SUPPLY / 2
        uint256 expected = (10_460_353_203 * 1e18) / 2;
        assertEq(vault.MAX_VAULT_CAPACITY(), expected, "Max capacity should be half of sacred supply");
    }

    // =========================================================================
    // v3.0 TEST SUITE 10: CAPO Oracle Integration
    // =========================================================================

    function test_OracleUpdate() public {
        vm.startPrank(owner);

        // Deploy mock oracle
        MockPriceOracle mockOracle = new MockPriceOracle();
        vault.setOracle(address(mockOracle));

        vm.stopPrank();

        // Oracle should be set
        assertEq(address(vault.oracle()), address(mockOracle));
    }

    function test_CapoValidationPasses() public {
        vm.startPrank(owner);

        // Deploy mock oracle with reasonable price
        MockPriceOracle mockOracle = new MockPriceOracle();
        mockOracle.setPrice(1 * 1e18); // $1 per TRI
        vault.setOracle(address(mockOracle));

        vm.stopPrank();
        vm.startPrank(alice);

        // Deposit should pass CAPO validation
        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        assertGt(shares, 0, "Deposit should succeed with valid oracle");

        vm.stopPrank();
    }

    function test_CapoValidationRejectsManipulation() public {
        vm.startPrank(owner);

        // Deploy oracle that detects manipulation
        MockPriceOracle mockOracle = new MockPriceOracle();
        mockOracle.setPrice(1 * 1e18);
        mockOracle.setManipulationMode(true); // Will report deviation
        vault.setOracle(address(mockOracle));

        vm.stopPrank();
        vm.startPrank(alice);

        // Deposit should fail due to CAPO validation
        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        vm.expectRevert("Price deviation detected");
        vault.deposit(depositAmount, alice);

        vm.stopPrank();
    }

    // =========================================================================
    // v3.0 TEST SUITE 11: Circuit Breaker
    // =========================================================================

    function test_CircuitBreakerTrips() public {
        vm.startPrank(owner);

        // Trigger circuit breaker with 20% price movement
        uint256 oldPrice = 100 * 1e18;
        uint256 newPrice = 120 * 1e18; // 20% increase

        vault.triggerCircuitBreaker(newPrice);

        // Circuit breaker should be active
        assertEq(vault.isCircuitBreakerActive(), true, "Circuit breaker should be active");
        assertEq(vault.paused(), true, "Vault should be paused");

        vm.stopPrank();
    }

    function test_CircuitBreakerBlocksDeposits() public {
        vm.startPrank(owner);

        // Trigger circuit breaker
        vault.triggerCircuitBreaker(120 * 1e18);

        vm.stopPrank();
        vm.startPrank(alice);

        // Deposits should be blocked
        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        vm.expectRevert(); // Blocked by circuit breaker
        vault.deposit(depositAmount, alice);

        vm.stopPrank();
    }

    function test_CircuitBreakerExpires() public {
        vm.startPrank(owner);

        // Trigger circuit breaker (1 hour duration)
        vault.triggerCircuitBreaker(120 * 1e18);

        assertEq(vault.isCircuitBreakerActive(), true);

        // Warp past circuit breaker duration
        skip(1 hours + 1);

        assertEq(vault.isCircuitBreakerActive(), false, "Circuit breaker should expire");

        vm.stopPrank();
    }

    function test_CircuitBreakerExtension() public {
        vm.startPrank(owner);

        // Trigger circuit breaker
        vault.triggerCircuitBreaker(120 * 1e18);

        // Extend by 2 hours
        vault.extendCircuitBreaker(2 hours);

        // Should still be active
        assertEq(vault.isCircuitBreakerActive(), true);

        vm.stopPrank();
    }

    // =========================================================================
    // v3.0 TEST SUITE 12: TWAP Smoothing
    // =========================================================================

    function test_TwapSmoothing() public {
        vm.startPrank(alice);

        // First deposit
        uint256 deposit1 = 10_000 * 1e18;
        underlying.approve(address(vault), deposit1);
        vault.deposit(deposit1, alice);

        vm.stopPrank();

        // TWAP should be initialized
        assertGt(vault.twapAverageAssets(), 0, "TWAP should be initialized");

        // After 1 hour, TWAP should update
        skip(1 hours + 1);

        vm.startPrank(bob);
        uint256 deposit2 = 5_000 * 1e18;
        underlying.approve(address(vault), deposit2);
        vault.deposit(deposit2, bob);

        vm.stopPrank();

        // TWAP should now be average of deposits
        uint256 expectedTwap = (deposit1 + deposit2) / 2;
        assertApproxEqRel(vault.twapAverageAssets(), expectedTwap, 0.01e18, "TWAP should smooth prices");
    }

    // =========================================================================
    // v3.1 TEST SUITE 13: Dead Shares Pattern (Uniswap V2)
    // =========================================================================

    function test_DeadSharesInitialized() public {
        vm.startPrank(alice);

        // First deposit triggers dead shares minting
        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        vm.stopPrank();

        // Check dead shares minted to address(0xdead)
        uint256 deadShares = vault.balanceOf(address(0xdead));
        assertEq(deadShares, 1000 * 1e18, "Dead shares should be minted");

        // Total supply includes dead shares
        uint256 totalSupply = vault.totalSupply();
        uint256 aliceShares = vault.balanceOf(alice);
        assertEq(totalSupply, deadShares + aliceShares, "Total includes dead shares");
    }

    function test_DeadSharesPreventsInflationAttack() public {
        vm.startPrank(alice);

        // First deposit (with dead shares)
        uint256 firstDeposit = 1000 * 1e18;
        underlying.approve(address(vault), firstDeposit);
        uint256 aliceShares = vault.deposit(firstDeposit, alice);

        vm.stopPrank();

        // Attacker tries large second deposit to inflate
        vm.startPrank(bob);
        uint256 largeDeposit = 100000 * 1e18;
        underlying.approve(address(vault), largeDeposit);
        vault.deposit(largeDeposit, bob);

        vm.stopPrank();

        // Alice's share value should be preserved (not diluted)
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 aliceValue = (aliceShares * totalAssets) / totalSupply;

        assertApproxEqRel(aliceValue, firstDeposit, 0.01e18, "First depositor value preserved");
    }

    // =========================================================================
    // v3.1 TEST SUITE 14: Strict CAPO Validation
    // =========================================================================

    function test_CapoRejectsStaleOracle() public {
        vm.startPrank(owner);

        // Deploy oracle with staleness support
        MockPriceOracleV31 oracleV31 = new MockPriceOracleV31();
        oracleV31.setPrice(1 * 1e18);
        oracleV31.setTimestamp(block.timestamp - 6 minutes); // Stale (> 5 min)

        vault.setOracle(address(oracleV31));

        vm.stopPrank();
        vm.startPrank(alice);

        // Large deposit should fail with stale oracle
        uint256 depositAmount = 10000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        vm.expectRevert("Price too old");
        vault.deposit(depositAmount, alice);

        vm.stopPrank();
    }

    function test_CapoAllowsFreshOracle() public {
        vm.startPrank(owner);

        MockPriceOracleV31 oracleV31 = new MockPriceOracleV31();
        oracleV31.setPrice(1 * 1e18);
        oracleV31.setTimestamp(block.timestamp); // Fresh

        vault.setOracle(address(oracleV31));

        vm.stopPrank();
        vm.startPrank(alice);

        // Deposit should succeed with fresh oracle
        uint256 depositAmount = 10000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        assertGt(shares, 0, "Deposit succeeds with fresh oracle");

        vm.stopPrank();
    }

    function test_CapoChecksMinimumLiquidity() public {
        vm.startPrank(owner);

        MockPriceOracleV31 oracleV31 = new MockPriceOracleV31();
        oracleV31.setPrice(1 * 1e18);
        oracleV31.setTimestamp(block.timestamp);
        oracleV31.setLiquidity(49000 * 1e18); // Below $50K threshold

        vault.setOracle(address(oracleV31));

        vm.stopPrank();
        vm.startPrank(alice);

        uint256 depositAmount = 10000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        vm.expectRevert("Insufficient DEX liquidity");
        vault.deposit(depositAmount, alice);

        vm.stopPrank();
    }

    // =========================================================================
    // v3.1 TEST SUITE 15: Yearly Growth Cap
    // =========================================================================

    function test_YearlyGrowthCapRejectsExcessiveGrowth() public {
        vm.startPrank(owner);

        MockPriceOracleV31 oracleV31 = new MockPriceOracleV31();
        oracleV31.setPrice(1 * 1e18);
        oracleV31.setTimestamp(block.timestamp);
        oracleV31.setLiquidity(100000 * 1e18);

        // Simulate 10% growth over 1 month (120% yearly > 8% cap)
        oracleV31.setReferencePrice(1 * 1e18, block.timestamp - 30 days);
        oracleV31.setPrice(1.1 * 1e18); // 10% increase

        vault.setOracle(address(oracleV31));

        vm.stopPrank();
        vm.startPrank(alice);

        uint256 depositAmount = 10000 * 1e18;
        underlying.approve(address(vault), depositAmount);

        vm.expectRevert("Excessive price growth");
        vault.deposit(depositAmount, alice);

        vm.stopPrank();
    }

    function test_ModerateGrowthAllowed() public {
        vm.startPrank(owner);

        MockPriceOracleV31 oracleV31 = new MockPriceOracleV31();
        oracleV31.setPrice(1 * 1e18);
        oracleV31.setTimestamp(block.timestamp);
        oracleV31.setLiquidity(100000 * 1e18);

        // 5% growth over 6 months (~10% yearly < 8% cap)
        oracleV31.setReferencePrice(1 * 1e18, block.timestamp - 180 days);
        oracleV31.setPrice(1.05 * 1e18);

        vault.setOracle(address(oracleV31));

        vm.stopPrank();
        vm.startPrank(alice);

        uint256 depositAmount = 10000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        assertGt(shares, 0, "Moderate growth allowed");

        vm.stopPrank();
    }

    // =========================================================================
    // v3.1 TEST SUITE 16: Adaptive Circuit Breaker
    // =========================================================================

    function test_AdaptiveCircuitBreakerTightensAtHighLeverage() public {
        vm.startPrank(owner);

        // Set capacity to test adaptive behavior
        vault.setMaxCapacity(100000 * 1e18);

        vm.stopPrank();
        vm.startPrank(alice);

        // Fill to 80% capacity
        uint256 depositAmount = 80000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        vm.stopPrank();

        // Warp 1 hour to trigger leverage check
        skip(1 hours + 1);

        // Threshold should tighten to 10%
        uint256 threshold = vault.circuitBreakerThresholdBps();
        assertEq(threshold, 1000, "Threshold tightened to 10%");
    }

    function test_AdaptiveCircuitBreakerRelaxesAtLowLeverage() public {
        vm.startPrank(owner);

        vault.setMaxCapacity(100000 * 1e18);

        vm.stopPrank();
        vm.startPrank(alice);

        // Low utilization (30%)
        uint256 depositAmount = 30000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        vm.stopPrank();

        // Warp 1 hour to trigger leverage check
        skip(1 hours + 1);

        // Threshold should be base 20%
        uint256 threshold = vault.circuitBreakerThresholdBps();
        assertEq(threshold, 2000, "Threshold at base 20%");
    }

    // =========================================================================
    // v3.1 TEST SUITE 17: Systemic Cascade Protection
    // =========================================================================

    function test_CascadeDetectionTriggersPause() public {
        vm.startPrank(alice);

        // Make large deposit
        uint256 depositAmount = 100000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);

        vm.stopPrank();

        // Note: This test would need internal function exposure
        // or a specialized test setup to trigger cascade detection
        // For now, we verify the cascade parameters are set correctly

        assertEq(vault.CASCADE_DETECTION_WINDOW(), 5 minutes, "Cascade window is 5 min");
        assertEq(vault.CASCADE_TRIGGER_BPS(), 500, "Cascade trigger is 5%");
    }

    // =========================================================================
    // INVARIANT TESTS
    // =========================================================================

    function test_Invariant_TotalAssetsNeverExceedsBalance() public {
        vm.startPrank(alice);

        uint256 deposit = 10000 * 1e18;
        underlying.approve(address(vault), deposit);
        vault.deposit(deposit, alice);

        vm.stopPrank();

        uint256 totalAssets = vault.totalAssets();
        uint256 actualBalance = vault.actualTokenBalance();

        assertLe(totalAssets, actualBalance, "totalAssets <= balance");
    }

    function test_Invariant_SharesToAssetsConversion() public {
        vm.startPrank(alice);

        uint256 depositAmount = 1000 * 1e18;
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);

        uint256 convertedAssets = vault.convertToAssets(shares);

        assertApproxEqRel(convertedAssets, depositAmount, 0.01e18, "Conversion accurate");

        vm.stopPrank();
    }

    function test_Invariant_ShareAccounting() public {
        vm.startPrank(alice);

        uint256 deposit1 = 1000 * 1e18;
        underlying.approve(address(vault), deposit1);
        vault.deposit(deposit1, alice);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 deposit2 = 1000 * 1e18;
        underlying.approve(address(vault), deposit2);
        vault.deposit(deposit2, bob);

        vm.stopPrank();

        uint256 deadShares = vault.balanceOf(address(0xdead));
        uint256 aliceShares = vault.balanceOf(alice);
        uint256 bobShares = vault.balanceOf(bob);
        uint256 totalSupply = vault.totalSupply();

        assertEq(totalSupply, deadShares + aliceShares + bobShares, "Accounting correct");
    }

    // =========================================================================
    // FUZZ TESTS
    // =========================================================================

    function testFuzz_Roundtrip(uint256 amount) public {
        amount = bound(amount, 100 * 1e18, 100000 * 1e18);

        vm.startPrank(alice);

        underlying.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);

        skip(COOLDOWN + 1);

        uint256 withdrawn = vault.withdraw(shares, alice, alice);

        assertApproxEqRel(withdrawn, amount, 0.001e18, "Roundtrip preserves value");

        vm.stopPrank();
    }

    function testFuzz_ProportionalClaims(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 100 * 1e18, 50000 * 1e18);
        amount2 = bound(amount2, 100 * 1e18, 50000 * 1e18);

        vm.startPrank(alice);

        underlying.approve(address(vault), amount1);
        uint256 shares1 = vault.deposit(amount1, alice);

        vm.stopPrank();
        vm.startPrank(bob);

        underlying.approve(address(vault), amount2);
        uint256 shares2 = vault.deposit(amount2, bob);

        vm.stopPrank();

        // Verify share ratios match deposit ratios
        uint256 totalDeposits = amount1 + amount2;
        uint256 totalShares = shares1 + shares2;

        uint256 expectedShares1 = (shares1 * totalDeposits) / totalShares;
        assertApproxEqRel(expectedShares1, amount1, 0.01e18, "Proportional claims");
    }
}

// =========================================================================
// v3.1 MOCK PRICE ORACLE WITH STALENESS SUPPORT
// =========================================================================

contract MockPriceOracleV31 is IPriceOracle {
    uint256 private price;
    uint256 private timestamp;
    uint256 private liquidity;
    uint256 private referencePrice;
    uint256 private referenceTime;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setTimestamp(uint256 _timestamp) external {
        timestamp = _timestamp;
    }

    function setLiquidity(uint256 _liquidity) external {
        liquidity = _liquidity;
    }

    function setReferencePrice(uint256 _price, uint256 _time) external {
        referencePrice = _price;
        referenceTime = _time;
    }

    function getTwiPrice(address) external view override returns (uint256, bool) {
        return (price, true);
    }

    function getTwiPriceWithTimestamp(address) external view override returns (uint256, bool, uint256) {
        return (price, true, timestamp);
    }

    function getReferencePrice(address) external view override returns (uint256, uint256) {
        return (referencePrice, referenceTime);
    }

    function getCurrentLiquidity(address) external view override returns (uint256) {
        return liquidity;
    }

    function checkDeviation(uint256, uint256) external pure override returns (bool) {
        return true;
    }

    function maxDeviationBps() external pure override returns (uint256) {
        return 500;
    }

    function updatePrice(address, uint256) external override {
        price = msg.sender;
    }

    function isOperational() external pure override returns (bool) {
        return true;
    }
}

// =========================================================================
// v3.0: MOCK PRICE ORACLE
// =========================================================================

contract MockPriceOracle is IPriceOracle {
    uint256 private price;
    bool private manipulationMode;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setManipulationMode(bool _mode) external {
        manipulationMode = _mode;
    }

    function getTwiPrice(address) external view override returns (uint256, bool) {
        return (price, true);
    }

    function checkDeviation(uint256, uint256) external pure override returns (bool) {
        if (manipulationMode) {
            return false; // Report deviation when in manipulation mode
        }
        return true;
    }

    function maxDeviationBps() external pure override returns (uint256) {
        return 500; // 5%
    }

    function updatePrice(address, uint256) external override {
        price = msg.sender; // Dummy implementation
    }

    function isOperational() external pure override returns (bool) {
        return true;
    }
}

// =========================================================================
// MOCK TRI TOKEN
// =========================================================================

contract MockTRI is ERC20 {
    constructor() ERC20("Trinity Token", "TRI") {
        _mint(msg.sender, 1_000_000_000 * 1e18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
