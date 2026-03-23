// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrinityToken.sol";

/**
 * @title Claim Vested $TRI Rewards
 * @notice Calls `claimVested()` on the TrinityToken contract for the caller.
 *
 * Usage:
 *   source .env
 *   forge script script/ClaimRewards.s.sol:ClaimRewards \
 *       --rpc-url $SEPOLIA_RPC_URL \
 *       --broadcast \
 *       -vvvv
 *
 * Prerequisites:
 *   - TRI_TOKEN_ADDRESS must be set in .env
 *   - The PRIVATE_KEY wallet must be one of the allocation beneficiaries
 *   - Sufficient time must have passed beyond the cliff period
 */
contract ClaimRewards is Script {
    function run() external {
        // ---------------------------------------------------------------
        // 1. Load configuration
        // ---------------------------------------------------------------
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(privateKey);
        address tokenAddress = vm.envAddress("TRI_TOKEN_ADDRESS");

        TrinityToken token = TrinityToken(tokenAddress);

        // ---------------------------------------------------------------
        // 2. Display pre-claim state
        // ---------------------------------------------------------------
        uint256 totalVested   = token.totalVested(caller);
        uint256 alreadyClaimed = token.claimed(caller);
        uint256 currentlyVested = token.vestedAmount(caller);
        uint256 claimable     = token.claimableAmount(caller);
        uint256 balanceBefore = token.balanceOf(caller);

        console.log("=== Trinity Token ($TRI) - Claim Rewards ===");
        console.log("Token:              ", tokenAddress);
        console.log("Beneficiary:        ", caller);
        console.log("");
        console.log("--- Before Claim ---");
        console.log("Total vesting:      ", totalVested);
        console.log("Currently vested:   ", currentlyVested);
        console.log("Already claimed:    ", alreadyClaimed);
        console.log("Claimable now:      ", claimable);
        console.log("Token balance:      ", balanceBefore);
        console.log("");

        // ---------------------------------------------------------------
        // 3. Execute claim
        // ---------------------------------------------------------------
        if (claimable == 0) {
            console.log("Nothing to claim. Either cliff has not passed or all vested tokens already claimed.");
            return;
        }

        vm.startBroadcast(privateKey);
        token.claimVested();
        vm.stopBroadcast();

        // ---------------------------------------------------------------
        // 4. Display post-claim state
        // ---------------------------------------------------------------
        uint256 balanceAfter  = token.balanceOf(caller);
        uint256 claimedAfter  = token.claimed(caller);
        uint256 claimableAfter = token.claimableAmount(caller);

        console.log("--- After Claim ---");
        console.log("Tokens received:    ", balanceAfter - balanceBefore);
        console.log("Total claimed:      ", claimedAfter);
        console.log("Remaining claimable:", claimableAfter);
        console.log("New balance:        ", balanceAfter);
        console.log("============================================");
    }
}
