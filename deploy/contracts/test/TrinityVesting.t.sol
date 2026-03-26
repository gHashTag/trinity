// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TrinityVesting.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TrinityVestingTest
 * @notice Foundry tests for TrinityVesting streaming vesting
 * @dev Tests for overflow protection, curve calculations, NFT transfers, and cancellation
 */
contract TrinityVestingTest is Test {
    TrinityVesting public vesting;
    MockTRI public token;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xC4R0L);
    address public owner = address(this);

    uint256 constant INITIAL_SUPPLY = 1_000_000_000 * 1e18;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock TRI token
        token = new MockTRI();
        token.mint(alice, 10_000_000 * 1e18);
        token.mint(bob, 10_000_000 * 1e18);
        token.mint(carol, 10_000_000 * 1e18);

        // Deploy vesting contract
        vesting = new TrinityVesting(
            IERC20(token),
            "Trinity Vesting NFT",
            "vTRI"
        );

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 1: Stream Creation
    // =========================================================================

    function test_CreateStreamLinear() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 365 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp + 1,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        // Verify stream created
        (
            uint256 id,
            address sender,
            address recipient,
            uint256 streamAmount,
            uint256 startTime,
            uint256 endTime,
            TrinityVesting.StreamCurve curve,
            TrinityVesting.StreamStatus status,
            ,
            ,
        ) = vesting.getStream(streamId);

        assertEq(id, streamId, "Stream ID should match");
        assertEq(sender, alice, "Sender should be alice");
        assertEq(recipient, bob, "Recipient should be bob");
        assertEq(streamAmount, amount, "Amount should match");
        assertEq(startTime, block.timestamp + 1, "Start time should match");
        assertEq(endTime, block.timestamp + 1 + duration, "End time should be start + duration");
        assertEq(uint(curve), uint(TrinityVesting.StreamCurve.LINEAR), "Curve should be LINEAR");
        assertEq(uint(status), uint(TrinityVesting.StreamStatus.PENDING), "Status should be PENDING");

        vm.stopPrank();
    }

    function test_CreateStreamExponential() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 180 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.EXP,
            ""
        );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            TrinityVesting.StreamCurve curve,
            ,
            ,
            ,
        ) = vesting.getStream(streamId);

        assertEq(uint(curve), uint(TrinityVesting.StreamCurve.EXP), "Curve should be EXP");

        vm.stopPrank();
    }

    function test_CreateStreamLogarithmic() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 90 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LOG,
            ""
        );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            TrinityVesting.StreamCurve curve,
            ,
            ,
            ,
        ) = vesting.getStream(streamId);

        assertEq(uint(curve), uint(TrinityVesting.StreamCurve.LOG), "Curve should be LOG");

        vm.stopPrank();
    }

    function test_CreateStreamBackweighted() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 365 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.BACKWEIGHTED,
            ""
        );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            TrinityVesting.StreamCurve curve,
            ,
            ,
            ,
        ) = vesting.getStream(streamId);

        assertEq(uint(curve), uint(TrinityVesting.StreamCurve.BACKWEIGHTED), "Curve should be BACKWEIGHTED");

        vm.stopPrank();
    }

    function test_CreateStreamInvalidRecipient() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        token.approve(address(vesting), amount);

        vm.expectRevert("Invalid recipient");
        vesting.createStream(
            address(0),
            amount,
            block.timestamp,
            365 days,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();
    }

    function test_CreateStreamInvalidAmount() public {
        vm.startPrank(alice);

        token.approve(address(vesting), 0);

        vm.expectRevert("Invalid amount");
        vesting.createStream(
            bob,
            0,
            block.timestamp,
            365 days,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();
    }

    function test_MaxAmountConstraint() public {
        vm.startPrank(alice);

        uint256 tooLargeAmount = 1e36 * 1e18; // Exceeds MAX_AMOUNT
        token.approve(address(vesting), tooLargeAmount);

        vm.expectRevert("Invalid amount");
        vesting.createStream(
            bob,
            tooLargeAmount,
            block.timestamp,
            365 days,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();
    }

    function test_MaxDurationConstraint() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 tooLongDuration = 4000 days; // Exceeds MAX_DURATION

        token.approve(address(vesting), amount);

        vm.expectRevert("Invalid duration");
        vesting.createStream(
            bob,
            amount,
            block.timestamp,
            tooLongDuration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();
    }

    // =========================================================================
    // TEST SUITE 2: Vesting Calculations
    // =========================================================================

    function test_LinearVestingHalfway() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Warp to 50% through vesting
        skip(50 days);

        uint256 vested = vesting.vestedAmount(streamId);
        assertApproxEqRel(vested, amount / 2, 0.001e18, "Linear: 50% time = 50% vested");
    }

    function test_LinearVestingComplete() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Warp to end of vesting
        skip(duration + 1);

        uint256 vested = vesting.vestedAmount(streamId);
        assertEq(vested, amount, "Linear: End time = 100% vested");
    }

    function test_ExponentialVestingAccelerates() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.EXP,
            ""
        );

        vm.stopPrank();

        // At 25% time
        skip(25 days);
        uint256 vested25 = vesting.vestedAmount(streamId);

        // At 50% time
        skip(25 days);
        uint256 vested50 = vesting.vestedAmount(streamId);

        // At 75% time
        skip(25 days);
        uint256 vested75 = vesting.vestedAmount(streamId);

        // EXP curve: f(t) = (t/d)^2
        // 25% -> 6.25%, 50% -> 25%, 75% -> 56.25%
        assertLt(vested25, vested50 * 13 / 25, "EXP: 25% should be much less than 50%");
        assertLt(vested50, vested75 * 25 / 56, "EXP: 50% should be less than 75%");
        assertLt(vested50 * 2, vested75, "EXP: Accelerating - second half > first half");
    }

    function test_LogarithmicVestingDecelerates() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LOG,
            ""
        );

        vm.stopPrank();

        // At 25% time
        skip(25 days);
        uint256 vested25 = vesting.vestedAmount(streamId);

        // At 50% time
        skip(25 days);
        uint256 vested50 = vesting.vestedAmount(streamId);

        // At 75% time
        skip(25 days);
        uint256 vested75 = vesting.vestedAmount(streamId);

        // LOG curve: f(t) = 1 - (1 - t/d)^2
        // 25% -> 43.75%, 50% -> 75%, 75% -> 93.75%
        assertGt(vested25, vested50 / 2, "LOG: 25% should be significant");
        assertGt(vested50, vested75 * 3 / 4, "LOG: Decelerating - first half > second half");
    }

    function test_BackweightedVestingSCurve() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.BACKWEIGHTED,
            ""
        );

        vm.stopPrank();

        // Early: less vested
        skip(25 days);
        uint256 vestedEarly = vesting.vestedAmount(streamId);

        // Middle
        skip(25 days);
        uint256 vestedMid = vesting.vestedAmount(streamId);

        // Late: more vested
        skip(25 days);
        uint256 vestedLate = vesting.vestedAmount(streamId);

        // S-curve: less early, more late
        assertLt(vestedEarly, vestedMid, "S-curve: early < mid");
        assertLt(vestedMid, vestedLate, "S-curve: mid < late");

        // First 25% should be less than 20% (weighted to end)
        assertLt(vestedEarly, amount * 20 / 100, "S-curve: early should be < 20%");
    }

    // =========================================================================
    // TEST SUITE 3: Claim Operations
    // =========================================================================

    function test_ClaimLinearStream() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Warp to 50% and claim
        skip(50 days);

        uint256 claimableBefore = vesting.claimableAmount(streamId);
        assertGt(claimableBefore, 0, "Should have claimable amount");

        uint256 balanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        uint256 claimed = vesting.claim(streamId);
        uint256 balanceAfter = token.balanceOf(bob);

        assertEq(claimed, balanceAfter - balanceBefore, "Claimed amount should match balance increase");
        assertEq(claimed, claimableBefore, "Should claim all available");

        // Second claim should fail (nothing new)
        vm.prank(bob);
        vm.expectRevert();
        vesting.claim(streamId);
    }

    function test_ClaimMultipleTimes() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // First claim at 25%
        skip(25 days);
        vm.prank(bob);
        uint256 claim1 = vesting.claim(streamId);

        // Second claim at 50%
        skip(25 days);
        vm.prank(bob);
        uint256 claim2 = vesting.claim(streamId);

        // Third claim at 100%
        skip(50 days);
        vm.prank(bob);
        uint256 claim3 = vesting.claim(streamId);

        assertGt(claim1, 0, "First claim should succeed");
        assertGt(claim2, 0, "Second claim should succeed");
        assertGt(claim3, 0, "Third claim should succeed");

        assertApproxEqRel(claim1 + claim2 + claim3, amount, 0.001e18, "Total claims should equal amount");
    }

    function test_ClaimedByNonRecipient() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        skip(50 days);

        // Carol (not recipient) tries to claim
        vm.prank(carol);
        // The contract doesn't restrict who calls claim, only sends to recipient
        // So this should succeed and send tokens to bob
        uint256 balanceBefore = token.balanceOf(bob);
        vesting.claim(streamId);
        uint256 balanceAfter = token.balanceOf(bob);

        assertGt(balanceAfter, balanceBefore, "Tokens go to recipient regardless of caller");
    }

    // =========================================================================
    // TEST SUITE 4: Cancellation
    // =========================================================================

    function test_CancelStreamWithPenalty() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Warp to 50% vesting
        skip(50 days);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Cancel with 10% penalty
        vm.prank(alice);
        uint256 refunded = vesting.cancelStream(streamId, 1000); // 10% = 1000 bps

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);

        // Alice should get refund
        assertEq(aliceBalanceAfter - aliceBalanceBefore, refunded, "Alice should get refund");
        assertGt(refunded, amount * 40 / 100, "Refund should be > 40% (unvested + portion of vested)");

        // Bob should get vested amount minus penalty
        uint256 bobReceived = bobBalanceAfter - bobBalanceBefore;
        assertGt(bobReceived, 0, "Bob should get something");

        // Status should be CANCELED
        assertEq(
            uint(vesting.getStreamStatus(streamId)),
            uint(TrinityVesting.StreamStatus.CANCELED),
            "Status should be CANCELED"
        );
    }

    function test_CancelAfterEndTime() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Warp past end time
        skip(duration + 1);

        // Should not be able to cancel after end
        vm.prank(alice);
        vm.expectRevert("Stream ended");
        vesting.cancelStream(streamId, 1000);
    }

    function test_CancelByNonSender() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        skip(50 days);

        // Bob (recipient) tries to cancel
        vm.prank(bob);
        vm.expectRevert();
        vesting.cancelStream(streamId, 1000);
    }

    function test_MaxPenaltyConstraint() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        skip(50 days);

        // Try to cancel with > 50% penalty
        vm.prank(alice);
        vm.expectRevert("Penalty too high");
        vesting.cancelStream(streamId, 6000); // 60% > MAX_CANCEL_PENALTY (50%)
    }

    // =========================================================================
    // TEST SUITE 5: NFT Transfers
    // =========================================================================

    function test_NFTMintedOnCreate() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        uint256 tokenId = vesting.getStreamIdByToken(streamId);
        assertEq(vesting.ownerOf(tokenId), alice, "NFT should be minted to sender");

        vm.stopPrank();
    }

    function test_TransferActiveStreamNFT() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        uint256 tokenId = vesting.getStreamIdByToken(streamId);

        // Transfer NFT to carol
        vesting.safeTransferFrom(alice, carol, tokenId);
        assertEq(vesting.ownerOf(tokenId), carol, "NFT should transfer");

        vm.stopPrank();
    }

    function test_TransferCanceledStreamNFT() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        uint256 tokenId = vesting.getStreamIdByToken(streamId);

        vm.stopPrank();

        // Cancel the stream
        skip(50 days);
        vm.prank(alice);
        vesting.cancelStream(streamId, 1000);

        // Try to transfer NFT
        vm.prank(alice);
        vm.expectRevert();
        vesting.safeTransferFrom(alice, carol, tokenId);
    }

    // =========================================================================
    // TEST SUITE 6: Overflow Protection
    // =========================================================================

    function test_NoOverflowLargeAmountLongDuration() public {
        vm.startPrank(alice);

        // Max allowed amount with max duration
        uint256 amount = 1e35; // Just under MAX_AMOUNT
        uint256 duration = 3650 days; // MAX_DURATION

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Warp to halfway
        skip(duration / 2);

        // Should not overflow
        uint256 vested = vesting.vestedAmount(streamId);
        assertGt(vested, 0, "Should calculate vested amount");
        assertLt(vested, amount, "Vested should be less than total");
    }

    function test_NoOverflowBackweightedCurve() public {
        vm.startPrank(alice);

        uint256 amount = 10_000 * 1e18;
        uint256 duration = 365 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.BACKWEIGHTED,
            ""
        );

        vm.stopPrank();

        // Test at various points - no overflow
        skip(100 days);
        uint256 v1 = vesting.vestedAmount(streamId);

        skip(100 days);
        uint256 v2 = vesting.vestedAmount(streamId);

        skip(165 days);
        uint256 v3 = vesting.vestedAmount(streamId);

        assertGt(v1, 0);
        assertGt(v2, v1);
        assertLe(v3, amount);
    }

    // =========================================================================
    // TEST SUITE 7: View Functions
    // =========================================================================

    function test_VestedAmountBeforeStart() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp + 100, // Start in future
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Before start time
        uint256 vested = vesting.vestedAmount(streamId);
        assertEq(vested, 0, "No vesting before start time");
    }

    function test_ClaimableAmount() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        skip(50 days);

        uint256 claimable = vesting.claimableAmount(streamId);
        uint256 vested = vesting.vestedAmount(streamId);

        assertEq(claimable, vested, "Claimable should equal vested when nothing claimed yet");

        // Claim some
        vm.prank(bob);
        vesting.claim(streamId);

        // Claimable should now be 0
        claimable = vesting.claimableAmount(streamId);
        assertEq(claimable, 0, "Nothing claimable immediately after claim");
    }

    function test_GetStream() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;
        uint256 startTime = block.timestamp;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            startTime,
            duration,
            TrinityVesting.StreamCurve.EXP,
            "ipfs://metadata"
        );

        vm.stopPrank();

        (
            uint256 id,
            address sender,
            address recipient,
            uint256 streamAmount,
            uint256 streamStartTime,
            uint256 endTime,
            TrinityVesting.StreamCurve curve,
            TrinityVesting.StreamStatus status,
            uint256 claimed,
            uint256 canceledAt,
            uint256 cancelPenalty
        ) = vesting.getStream(streamId);

        assertEq(id, streamId);
        assertEq(sender, alice);
        assertEq(recipient, bob);
        assertEq(streamAmount, amount);
        assertEq(streamStartTime, startTime);
        assertEq(endTime, startTime + duration);
        assertEq(uint(curve), uint(TrinityVesting.StreamCurve.EXP));
        assertEq(uint(status), uint(TrinityVesting.StreamStatus.PENDING));
        assertEq(claimed, 0);
        assertEq(canceledAt, 0);
        assertEq(cancelPenalty, 0);
    }

    // =========================================================================
    // v3.0 TEST SUITE 8: Sacred Supply Constants
    // =========================================================================

    function test_SacredSupplyConstant() public {
        // SACRED: 3^21 = 10,460,353,203
        uint256 expected = 10_460_353_203 * 1e18;
        assertEq(vesting.SACRED_SUPPLY(), expected, "Sacred supply should be 3^21");
    }

    function test_MaxStreamAmountCappedAtOnePercent() public {
        // MAX_STREAM_AMOUNT = SACRED_SUPPLY / 100
        uint256 expected = (10_460_353_203 * 1e18) / 100;
        assertEq(vesting.MAX_STREAM_AMOUNT(), expected, "Max stream amount should be 1% of sacred supply");
    }

    function test_StreamAmountExceedsSacredCap() public {
        vm.startPrank(alice);

        // Try to create stream exceeding 1% of sacred supply
        uint256 tooLargeAmount = vesting.MAX_STREAM_AMOUNT() + 1;
        token.mint(alice, tooLargeAmount);

        token.approve(address(vesting), tooLargeAmount);

        vm.expectRevert("Exceeds max stream amount");
        vesting.createStream(
            bob,
            tooLargeAmount,
            block.timestamp,
            365 days,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();
    }

    // =========================================================================
    // v3.0 TEST SUITE 9: Reorg Protection
    // =========================================================================

    function test_ReorgProtectionBlocksImmediateClaim() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Try to claim immediately (before REORG_DELAY)
        vm.prank(bob);
        vm.expectRevert("Reorg protection active");
        vesting.claim(streamId);
    }

    function test_ReorgProtectionExpiresAfterDelay() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        // Wait past REORG_DELAY (1 minute)
        skip(1 minutes + 1);

        // Claim should succeed now
        vm.prank(bob);
        uint256 claimed = vesting.claim(streamId);
        assertGt(claimed, 0, "Claim should succeed after reorg delay");
    }

    function test_GetStreamIncludesCreatedAt() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.LINEAR,
            ""
        );

        vm.stopPrank();

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 createdAt
        ) = vesting.getStream(streamId);

        assertGt(createdAt, 0, "createdAt should be set");
        assertEq(createdAt, block.timestamp, "createdAt should match creation time");
    }

    // =========================================================================
    // v3.0 TEST SUITE 10: EXP Curve Overflow Cap
    // =========================================================================

    function test_ExpCurveCappedAt99Percent() public {
        vm.startPrank(alice);

        uint256 amount = 100_000 * 1e18;
        uint256 duration = 100 days;

        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.EXP,
            ""
        );

        vm.stopPrank();

        // At 99% time (99 days), EXP curve would square 9900/10000
        // v3.0: This is capped to prevent overflow
        skip(99 days);

        uint256 vested = vesting.vestedAmount(streamId);

        // Should be close to but not exceed amount
        assertLe(vested, amount, "Vested should not exceed total amount");
        assertGt(vested, amount * 98 / 100, "Vested should be >98% at 99% time");
    }

    function test_ExpCurveNoOverflow() public {
        vm.startPrank(alice);

        uint256 amount = 1e30; // Very large amount
        uint256 duration = 365 days;

        token.mint(alice, amount);
        token.approve(address(vesting), amount);
        uint256 streamId = vesting.createStream(
            bob,
            amount,
            block.timestamp,
            duration,
            TrinityVesting.StreamCurve.EXP,
            ""
        );

        vm.stopPrank();

        // At 50% time - should not overflow
        skip(duration / 2);

        // Should calculate without reverting
        uint256 vested = vesting.vestedAmount(streamId);
        assertGt(vested, 0, "Should calculate vested amount");
        assertLt(vested, amount, "Vested should be less than total");
    }

    // =========================================================================
    // v3.0 TEST SUITE 11: Hooks Configuration
    // =========================================================================

    function test_ConfigureHooks() public {
        vm.startPrank(owner);

        // Enable hooks with custom gas requirement
        vesting.configureHooks(true, 150000);

        assertEq(vesting.hooksEnabled(), true, "Hooks should be enabled");
        assertEq(vesting.minHooksGas(), 150000, "Min hooks gas should be set");

        // Disable hooks
        vesting.configureHooks(false, 100000);

        assertEq(vesting.hooksEnabled(), false, "Hooks should be disabled");

        vm.stopPrank();
    }

    function test_HooksOnlyOwner() public {
        vm.startPrank(alice);

        vm.expectRevert();
        vesting.configureHooks(true, 100000);

        vm.stopPrank();
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
