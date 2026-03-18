// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrinityToken.sol";

/**
 * @title TrinityToken Test Suite
 * @notice Foundry tests for TrinityToken ($TRI) covering deployment,
 *         supply, allocations, vesting, cliff enforcement, and the
 *         phi identity verification.
 */
contract TrinityTokenTest is Test {
    TrinityToken public token;

    address public founder       = makeAddr("founder");
    address public nodeRewards   = makeAddr("nodeRewards");
    address public community     = makeAddr("community");
    address public treasury      = makeAddr("treasury");
    address public liquidity     = makeAddr("liquidity");

    /// @notice Phoenix Number: 3^21
    uint256 constant PHOENIX_NUMBER = 10_460_353_203;
    uint256 constant TOTAL_SUPPLY   = PHOENIX_NUMBER * 1e18;

    uint256 constant FOUNDER_ALLOC      = TOTAL_SUPPLY * 20 / 100;
    uint256 constant NODE_REWARDS_ALLOC = TOTAL_SUPPLY * 40 / 100;
    uint256 constant COMMUNITY_ALLOC    = TOTAL_SUPPLY * 20 / 100;
    uint256 constant TREASURY_ALLOC     = TOTAL_SUPPLY * 10 / 100;
    uint256 constant LIQUIDITY_ALLOC    = TOTAL_SUPPLY * 10 / 100;

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public {
        token = new TrinityToken(
            founder,
            nodeRewards,
            community,
            treasury,
            liquidity
        );
    }

    // ---------------------------------------------------------------
    // Deployment
    // ---------------------------------------------------------------

    function test_DeploymentSucceeds() public view {
        assertEq(token.name(), "Trinity");
        assertEq(token.symbol(), "TRI");
        assertTrue(address(token) != address(0), "Token address must not be zero");
    }

    function test_DeploymentRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid founder");
        new TrinityToken(address(0), nodeRewards, community, treasury, liquidity);

        vm.expectRevert("Invalid nodeRewards");
        new TrinityToken(founder, address(0), community, treasury, liquidity);

        vm.expectRevert("Invalid community");
        new TrinityToken(founder, nodeRewards, address(0), treasury, liquidity);

        vm.expectRevert("Invalid treasury");
        new TrinityToken(founder, nodeRewards, community, address(0), liquidity);

        vm.expectRevert("Invalid liquidity");
        new TrinityToken(founder, nodeRewards, community, treasury, address(0));
    }

    // ---------------------------------------------------------------
    // Total Supply
    // ---------------------------------------------------------------

    function test_TotalSupplyAfterDeploy() public view {
        // Only liquidity allocation is minted at deployment;
        // the rest is minted on claim.
        assertEq(token.totalSupply(), LIQUIDITY_ALLOC);
    }

    function test_PhoenixNumber() public view {
        assertEq(token.PHOENIX_NUMBER(), PHOENIX_NUMBER);
        assertEq(token.TOTAL_SUPPLY(), TOTAL_SUPPLY);
    }

    function test_AllocationsSumToTotalSupply() public pure {
        assertEq(
            FOUNDER_ALLOC + NODE_REWARDS_ALLOC + COMMUNITY_ALLOC + TREASURY_ALLOC + LIQUIDITY_ALLOC,
            TOTAL_SUPPLY
        );
    }

    // ---------------------------------------------------------------
    // Liquidity allocation is immediate
    // ---------------------------------------------------------------

    function test_LiquidityAllocationImmediate() public view {
        assertEq(token.balanceOf(liquidity), LIQUIDITY_ALLOC);
    }

    function test_LiquidityHasNoVesting() public view {
        assertEq(token.totalVested(liquidity), 0);
    }

    // ---------------------------------------------------------------
    // Vesting schedule setup
    // ---------------------------------------------------------------

    function test_FounderVestingParams() public view {
        assertEq(token.totalVested(founder), FOUNDER_ALLOC);
        assertEq(token.vestingDuration(founder), 48 * 30 days);   // 4 years
        assertEq(token.cliffDuration(founder), 12 * 30 days);     // 1 year cliff
    }

    function test_NodeRewardsVestingParams() public view {
        assertEq(token.totalVested(nodeRewards), NODE_REWARDS_ALLOC);
        assertEq(token.vestingDuration(nodeRewards), 120 * 30 days); // 10 years
        assertEq(token.cliffDuration(nodeRewards), 0);               // no cliff
    }

    function test_CommunityVestingParams() public view {
        assertEq(token.totalVested(community), COMMUNITY_ALLOC);
        assertEq(token.vestingDuration(community), 36 * 30 days);  // 3 years
        assertEq(token.cliffDuration(community), 0);                // no cliff
    }

    function test_TreasuryVestingParams() public view {
        assertEq(token.totalVested(treasury), TREASURY_ALLOC);
        assertEq(token.vestingDuration(treasury), 60 * 30 days);   // 5 years
        assertEq(token.cliffDuration(treasury), 6 * 30 days);      // 6 month cliff
    }

    // ---------------------------------------------------------------
    // Cliff enforcement: claim before cliff must fail
    // ---------------------------------------------------------------

    function test_ClaimBeforeCliffReverts_Founder() public {
        // Warp to just before the 1-year cliff
        vm.warp(block.timestamp + 12 * 30 days - 1);

        vm.prank(founder);
        vm.expectRevert("Nothing to claim");
        token.claimVested();
    }

    function test_ClaimBeforeCliffReverts_Treasury() public {
        // Warp to just before the 6-month cliff
        vm.warp(block.timestamp + 6 * 30 days - 1);

        vm.prank(treasury);
        vm.expectRevert("Nothing to claim");
        token.claimVested();
    }

    // ---------------------------------------------------------------
    // Claiming after cliff works
    // ---------------------------------------------------------------

    function test_ClaimAfterCliff_Founder() public {
        // Warp past the founder cliff (1 year)
        vm.warp(block.timestamp + 12 * 30 days + 1);

        vm.prank(founder);
        token.claimVested();

        assertTrue(token.balanceOf(founder) > 0, "Founder should have tokens after cliff");
        assertTrue(token.claimed(founder) > 0, "Claimed should be updated");
    }

    function test_ClaimAfterCliff_Treasury() public {
        // Warp past the treasury cliff (6 months)
        vm.warp(block.timestamp + 6 * 30 days + 1);

        vm.prank(treasury);
        token.claimVested();

        assertTrue(token.balanceOf(treasury) > 0, "Treasury should have tokens after cliff");
    }

    // ---------------------------------------------------------------
    // Node rewards vest without cliff
    // ---------------------------------------------------------------

    function test_NodeRewardsClaimWithoutCliff() public {
        // Even 1 day after genesis, some tokens should be claimable
        vm.warp(block.timestamp + 1 days);

        vm.prank(nodeRewards);
        token.claimVested();

        assertTrue(token.balanceOf(nodeRewards) > 0, "Node rewards should vest from day 1");
    }

    // ---------------------------------------------------------------
    // Full vesting
    // ---------------------------------------------------------------

    function test_FullVesting_Founder() public {
        // Warp past entire founder vesting period (4 years)
        vm.warp(block.timestamp + 48 * 30 days + 1);

        vm.prank(founder);
        token.claimVested();

        assertEq(token.balanceOf(founder), FOUNDER_ALLOC);
        assertEq(token.remainingVesting(founder), 0);
    }

    function test_FullVesting_NodeRewards() public {
        // Warp past entire node rewards vesting (10 years)
        vm.warp(block.timestamp + 120 * 30 days + 1);

        vm.prank(nodeRewards);
        token.claimVested();

        assertEq(token.balanceOf(nodeRewards), NODE_REWARDS_ALLOC);
    }

    // ---------------------------------------------------------------
    // Multiple claims accumulate correctly
    // ---------------------------------------------------------------

    function test_MultipleClaims() public {
        // Community has no cliff, 3 year vesting

        // Claim at 1 year
        vm.warp(block.timestamp + 12 * 30 days);
        vm.prank(community);
        token.claimVested();
        uint256 balance1 = token.balanceOf(community);

        // Claim at 2 years
        vm.warp(block.timestamp + 12 * 30 days);
        vm.prank(community);
        token.claimVested();
        uint256 balance2 = token.balanceOf(community);

        assertTrue(balance2 > balance1, "Second claim should increase balance");

        // Claim at full vesting (3 years from genesis)
        vm.warp(block.timestamp + 12 * 30 days + 1);
        vm.prank(community);
        token.claimVested();

        assertEq(token.balanceOf(community), COMMUNITY_ALLOC);
    }

    // ---------------------------------------------------------------
    // Non-beneficiary cannot claim
    // ---------------------------------------------------------------

    function test_NonBeneficiaryCannotClaim() public {
        address nobody = makeAddr("nobody");

        vm.warp(block.timestamp + 365 days);

        vm.prank(nobody);
        vm.expectRevert("Nothing to claim");
        token.claimVested();
    }

    // ---------------------------------------------------------------
    // Phi identity verification
    // ---------------------------------------------------------------

    function test_PhiIdentity() public view {
        // phi = 1.618033988749895 * 1e18
        uint256 phi = token.PHI_SCALED();
        assertEq(phi, 1_618033988749895000);

        // Compute phi^2 + 1/phi^2 and verify it approximates 3
        uint256 phiSquared = (phi * phi) / 1e18;
        uint256 invPhiSquared = 1e36 / phiSquared;
        uint256 result = phiSquared + invPhiSquared;

        // Must be within 0.01% of 3e18
        assertTrue(result > 2_999_000_000_000_000_000, "phi identity too low");
        assertTrue(result < 3_001_000_000_000_000_000, "phi identity too high");
    }

    // ---------------------------------------------------------------
    // Circulating supply reflects claims
    // ---------------------------------------------------------------

    function test_CirculatingSupplyIncreases() public {
        uint256 supplyBefore = token.circulatingSupply();
        assertEq(supplyBefore, LIQUIDITY_ALLOC);

        // Community claims after 1 year
        vm.warp(block.timestamp + 12 * 30 days);
        vm.prank(community);
        token.claimVested();

        uint256 supplyAfter = token.circulatingSupply();
        assertTrue(supplyAfter > supplyBefore, "Circulating supply should increase after claim");
    }

    // ---------------------------------------------------------------
    // Genesis timestamp
    // ---------------------------------------------------------------

    function test_GenesisTimestamp() public view {
        assertEq(token.genesisTimestamp(), block.timestamp);
    }

    // ---------------------------------------------------------------
    // Immutable addresses
    // ---------------------------------------------------------------

    function test_ImmutableAddresses() public view {
        assertEq(token.founderAddress(), founder);
        assertEq(token.nodeRewardsAddress(), nodeRewards);
        assertEq(token.communityAddress(), community);
        assertEq(token.treasuryAddress(), treasury);
        assertEq(token.liquidityAddress(), liquidity);
    }
}
