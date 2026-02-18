// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrinityToken.sol";

/**
 * @title Deploy Trinity Token ($TRI) to Sepolia
 * @notice Deployment script for the TrinityToken contract.
 *
 * Usage:
 *   source .env
 *   forge script script/Deploy.s.sol:DeployTrinityToken \
 *       --rpc-url $SEPOLIA_RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvvv
 *
 * Each allocation address is read from an environment variable.
 * If a variable is not set the deployer address (msg.sender) is used as
 * a fallback so you can run a quick local test without configuring five
 * separate wallets.
 */
contract DeployTrinityToken is Script {
    function run() external {
        // ---------------------------------------------------------------
        // 1. Read the deployer private key and derive the sender address
        // ---------------------------------------------------------------
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // ---------------------------------------------------------------
        // 2. Resolve allocation addresses (fall back to deployer)
        // ---------------------------------------------------------------
        address founder       = _envAddressOr("FOUNDER_ADDRESS",       deployer);
        address nodeRewards   = _envAddressOr("NODE_REWARDS_ADDRESS",  deployer);
        address community     = _envAddressOr("COMMUNITY_ADDRESS",     deployer);
        address treasury      = _envAddressOr("TREASURY_ADDRESS",      deployer);
        address liquidity     = _envAddressOr("LIQUIDITY_ADDRESS",     deployer);

        // ---------------------------------------------------------------
        // 3. Log pre-deployment summary
        // ---------------------------------------------------------------
        console.log("=== Trinity Token ($TRI) Deployment ===");
        console.log("Deployer:       ", deployer);
        console.log("Founder:        ", founder);
        console.log("Node Rewards:   ", nodeRewards);
        console.log("Community:      ", community);
        console.log("Treasury:       ", treasury);
        console.log("Liquidity:      ", liquidity);
        console.log("");
        console.log("Total Supply:    10,460,353,203 TRI (3^21)");
        console.log("Sacred Formula:  phi^2 + 1/phi^2 = 3");
        console.log("========================================");

        // ---------------------------------------------------------------
        // 4. Deploy the contract
        // ---------------------------------------------------------------
        vm.startBroadcast(deployerPrivateKey);

        TrinityToken token = new TrinityToken(
            founder,
            nodeRewards,
            community,
            treasury,
            liquidity
        );

        vm.stopBroadcast();

        // ---------------------------------------------------------------
        // 5. Post-deployment verification
        // ---------------------------------------------------------------
        console.log("");
        console.log("=== Deployment Successful ===");
        console.log("TrinityToken deployed at:", address(token));
        console.log("Genesis timestamp:       ", token.genesisTimestamp());

        // Verify the phi identity holds (contract already checks in constructor,
        // but we log the constant here for human confirmation).
        uint256 phi = token.PHI_SCALED();
        uint256 phiSq = (phi * phi) / 1e18;
        uint256 invPhiSq = 1e36 / phiSq;
        uint256 triIdentity = phiSq + invPhiSq;
        console.log("phi^2 + 1/phi^2 =       ", triIdentity);
        console.log("Expected ~              3000000000000000000");

        // Verify liquidity allocation was minted immediately
        uint256 liqBalance = token.balanceOf(liquidity);
        console.log("Liquidity balance:      ", liqBalance);
        console.log("=============================");
    }

    /// @dev Read an address from an env var; return `fallback_` when unset or zero.
    function _envAddressOr(string memory key, address fallback_) internal view returns (address) {
        try vm.envAddress(key) returns (address val) {
            if (val == address(0)) return fallback_;
            return val;
        } catch {
            return fallback_;
        }
    }
}
