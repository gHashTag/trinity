/**
 * Trinity Token ($TRI) Deployment Script
 * Deploys TrinityToken.sol to Ethereum
 *
 * Usage:
 *   npx hardhat run scripts/deploy.js --network mainnet
 *   npx hardhat run scripts/deploy.js --network sepolia
 *
 * Required .env:
 *   PRIVATE_KEY=0x...
 *   MAINNET_RPC_URL=https://...
 *   FOUNDER_ADDRESS=0x...
 *   NODE_REWARDS_ADDRESS=0x...
 *   COMMUNITY_ADDRESS=0x...
 *   TREASURY_ADDRESS=0x...
 *   LIQUIDITY_ADDRESS=0x...
 */

const hre = require("hardhat");
require("dotenv").config();

// Phoenix Number: 3^21
const PHOENIX_NUMBER = 10_460_353_203n;
const TOTAL_SUPPLY = PHOENIX_NUMBER * 10n ** 18n;

async function main() {
  console.log("═".repeat(70));
  console.log("$TRI TOKEN DEPLOYMENT");
  console.log("Phoenix Number: 3^21 =", PHOENIX_NUMBER.toLocaleString());
  console.log("═".repeat(70));

  // Get deployer
  const [deployer] = await hre.ethers.getSigners();
  console.log("\nDeployer:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Balance:", hre.ethers.formatEther(balance), "ETH");

  // Get allocation addresses from env
  const founderAddress = process.env.FOUNDER_ADDRESS || deployer.address;
  const nodeRewardsAddress = process.env.NODE_REWARDS_ADDRESS || deployer.address;
  const communityAddress = process.env.COMMUNITY_ADDRESS || deployer.address;
  const treasuryAddress = process.env.TREASURY_ADDRESS || deployer.address;
  const liquidityAddress = process.env.LIQUIDITY_ADDRESS || deployer.address;

  console.log("\nAllocation Addresses:");
  console.log("  Founder (20%):", founderAddress);
  console.log("  Node Rewards (40%):", nodeRewardsAddress);
  console.log("  Community (20%):", communityAddress);
  console.log("  Treasury (10%):", treasuryAddress);
  console.log("  Liquidity (10%):", liquidityAddress);

  // Deploy token
  console.log("\n" + "─".repeat(70));
  console.log("Deploying TrinityToken...");
  console.log("─".repeat(70));

  const TrinityToken = await hre.ethers.getContractFactory("TrinityToken");
  const token = await TrinityToken.deploy(
    founderAddress,
    nodeRewardsAddress,
    communityAddress,
    treasuryAddress,
    liquidityAddress
  );

  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();

  console.log("\n✅ TrinityToken deployed!");
  console.log("   Address:", tokenAddress);

  // Verify deployment
  console.log("\n" + "─".repeat(70));
  console.log("Verifying deployment...");
  console.log("─".repeat(70));

  const name = await token.name();
  const symbol = await token.symbol();
  const totalSupply = await token.totalSupply();
  const liquidityBalance = await token.balanceOf(liquidityAddress);

  console.log("  Name:", name);
  console.log("  Symbol:", symbol);
  console.log("  Total Supply:", hre.ethers.formatEther(totalSupply), "TRI");
  console.log("  Liquidity Balance:", hre.ethers.formatEther(liquidityBalance), "TRI");

  // Verify phi identity was checked
  const phoenixNumber = await token.PHOENIX_NUMBER();
  console.log("  Phoenix Number:", phoenixNumber.toString());

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: (await hre.ethers.provider.getNetwork()).chainId.toString(),
    tokenAddress: tokenAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    phoenixNumber: PHOENIX_NUMBER.toString(),
    totalSupply: TOTAL_SUPPLY.toString(),
    allocations: {
      founder: founderAddress,
      nodeRewards: nodeRewardsAddress,
      community: communityAddress,
      treasury: treasuryAddress,
      liquidity: liquidityAddress
    }
  };

  console.log("\n" + "═".repeat(70));
  console.log("DEPLOYMENT COMPLETE");
  console.log("═".repeat(70));
  console.log(JSON.stringify(deploymentInfo, null, 2));

  // Save to file
  const fs = require("fs");
  fs.writeFileSync(
    `deployment-${hre.network.name}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log(`\nSaved to deployment-${hre.network.name}.json`);

  // Verification instructions
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("\n" + "─".repeat(70));
    console.log("To verify on Etherscan:");
    console.log("─".repeat(70));
    console.log(`npx hardhat verify --network ${hre.network.name} ${tokenAddress} \\`);
    console.log(`  ${founderAddress} \\`);
    console.log(`  ${nodeRewardsAddress} \\`);
    console.log(`  ${communityAddress} \\`);
    console.log(`  ${treasuryAddress} \\`);
    console.log(`  ${liquidityAddress}`);
  }

  console.log("\n" + "═".repeat(70));
  console.log("KOSCHEI IS IMMORTAL | $TRI DEPLOYED | φ² + 1/φ² = 3");
  console.log("═".repeat(70));

  return deploymentInfo;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
