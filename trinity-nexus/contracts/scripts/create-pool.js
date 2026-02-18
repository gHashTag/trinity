/**
 * Create Uniswap V3 Pool for $TRI/ETH
 *
 * Pool Configuration:
 *   - Token: $TRI
 *   - Pair: TRI/WETH
 *   - Fee: 0.3% (3000)
 *   - Initial Price: $0.01 per TRI
 *
 * Usage:
 *   npx hardhat run scripts/create-pool.js --network mainnet
 */

const hre = require("hardhat");
require("dotenv").config();

// Uniswap V3 Addresses (Ethereum Mainnet)
const UNISWAP_V3_FACTORY = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const UNISWAP_V3_POSITION_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// Pool parameters
const FEE_TIER = 3000; // 0.3%
const INITIAL_PRICE = 0.01; // $0.01 per TRI
const ETH_PRICE_USD = 3500; // Assumed ETH price

// TRI allocation for pool
const TRI_FOR_POOL = 523_017_660n * 10n ** 18n; // 523M TRI

// Calculate ETH needed
// At $0.01/TRI and $3500/ETH: 523M * 0.01 / 3500 = ~1494 ETH
const ETH_FOR_POOL = hre.ethers.parseEther("1494");

async function main() {
  console.log("═".repeat(70));
  console.log("UNISWAP V3 POOL CREATION");
  console.log("═".repeat(70));

  const [deployer] = await hre.ethers.getSigners();
  console.log("\nDeployer:", deployer.address);

  // Load deployment info
  const fs = require("fs");
  let tokenAddress;

  try {
    const deployment = JSON.parse(fs.readFileSync(`deployment-${hre.network.name}.json`));
    tokenAddress = deployment.tokenAddress;
  } catch (e) {
    tokenAddress = process.env.TRI_TOKEN_ADDRESS;
  }

  if (!tokenAddress) {
    throw new Error("TRI token address not found. Deploy token first or set TRI_TOKEN_ADDRESS");
  }

  console.log("TRI Token:", tokenAddress);
  console.log("WETH:", WETH_ADDRESS);

  // Get contracts
  const token = await hre.ethers.getContractAt("IERC20", tokenAddress);
  const weth = await hre.ethers.getContractAt("IWETH9", WETH_ADDRESS);
  const factory = await hre.ethers.getContractAt("IUniswapV3Factory", UNISWAP_V3_FACTORY);
  const positionManager = await hre.ethers.getContractAt(
    "INonfungiblePositionManager",
    UNISWAP_V3_POSITION_MANAGER
  );

  // Check balances
  const triBalance = await token.balanceOf(deployer.address);
  const ethBalance = await hre.ethers.provider.getBalance(deployer.address);

  console.log("\n" + "─".repeat(70));
  console.log("Balances:");
  console.log("─".repeat(70));
  console.log("  TRI:", hre.ethers.formatEther(triBalance));
  console.log("  ETH:", hre.ethers.formatEther(ethBalance));

  // Verify sufficient balance
  if (triBalance < TRI_FOR_POOL) {
    throw new Error(`Insufficient TRI. Need ${hre.ethers.formatEther(TRI_FOR_POOL)}, have ${hre.ethers.formatEther(triBalance)}`);
  }
  if (ethBalance < ETH_FOR_POOL) {
    throw new Error(`Insufficient ETH. Need ${hre.ethers.formatEther(ETH_FOR_POOL)}, have ${hre.ethers.formatEther(ethBalance)}`);
  }

  // Calculate sqrtPriceX96
  // price = TRI per ETH = ETH_PRICE_USD / TRI_PRICE_USD = 3500 / 0.01 = 350000
  // sqrtPrice = sqrt(price) * 2^96
  const priceRatio = BigInt(Math.floor(ETH_PRICE_USD / INITIAL_PRICE));
  const sqrtPrice = BigInt(Math.floor(Math.sqrt(Number(priceRatio))));
  const sqrtPriceX96 = sqrtPrice * (2n ** 96n);

  console.log("\n" + "─".repeat(70));
  console.log("Pool Parameters:");
  console.log("─".repeat(70));
  console.log("  Initial Price:", INITIAL_PRICE, "USD/TRI");
  console.log("  TRI for Pool:", hre.ethers.formatEther(TRI_FOR_POOL), "TRI");
  console.log("  ETH for Pool:", hre.ethers.formatEther(ETH_FOR_POOL), "ETH");
  console.log("  Fee Tier:", FEE_TIER / 10000, "%");

  // Sort tokens (Uniswap requires token0 < token1)
  const [token0, token1] = tokenAddress.toLowerCase() < WETH_ADDRESS.toLowerCase()
    ? [tokenAddress, WETH_ADDRESS]
    : [WETH_ADDRESS, tokenAddress];

  console.log("  Token0:", token0);
  console.log("  Token1:", token1);

  // Check if pool exists
  let poolAddress = await factory.getPool(tokenAddress, WETH_ADDRESS, FEE_TIER);

  if (poolAddress === "0x0000000000000000000000000000000000000000") {
    console.log("\n" + "─".repeat(70));
    console.log("Creating pool...");
    console.log("─".repeat(70));

    // Create and initialize pool
    const tx = await positionManager.createAndInitializePoolIfNecessary(
      token0,
      token1,
      FEE_TIER,
      sqrtPriceX96
    );
    await tx.wait();

    poolAddress = await factory.getPool(tokenAddress, WETH_ADDRESS, FEE_TIER);
    console.log("✅ Pool created:", poolAddress);
  } else {
    console.log("\n✅ Pool already exists:", poolAddress);
  }

  // Wrap ETH to WETH
  console.log("\n" + "─".repeat(70));
  console.log("Wrapping ETH...");
  console.log("─".repeat(70));

  const wrapTx = await weth.deposit({ value: ETH_FOR_POOL });
  await wrapTx.wait();
  console.log("✅ Wrapped", hre.ethers.formatEther(ETH_FOR_POOL), "ETH to WETH");

  // Approve tokens
  console.log("\n" + "─".repeat(70));
  console.log("Approving tokens...");
  console.log("─".repeat(70));

  const approveTri = await token.approve(UNISWAP_V3_POSITION_MANAGER, TRI_FOR_POOL);
  await approveTri.wait();
  console.log("✅ Approved TRI");

  const approveWeth = await weth.approve(UNISWAP_V3_POSITION_MANAGER, ETH_FOR_POOL);
  await approveWeth.wait();
  console.log("✅ Approved WETH");

  // Save pool info
  const poolInfo = {
    network: hre.network.name,
    poolAddress: poolAddress,
    token0: token0,
    token1: token1,
    feeTier: FEE_TIER,
    initialPrice: INITIAL_PRICE,
    triAmount: TRI_FOR_POOL.toString(),
    ethAmount: ETH_FOR_POOL.toString(),
    timestamp: new Date().toISOString()
  };

  fs.writeFileSync(
    `pool-${hre.network.name}.json`,
    JSON.stringify(poolInfo, null, 2)
  );

  console.log("\n" + "═".repeat(70));
  console.log("POOL CREATED - READY FOR LIQUIDITY");
  console.log("═".repeat(70));
  console.log(JSON.stringify(poolInfo, null, 2));
  console.log("\nNext: Run add-liquidity.js to add initial liquidity");

  console.log("\n" + "═".repeat(70));
  console.log("KOSCHEI IS IMMORTAL | $TRI POOL READY | φ² + 1/φ² = 3");
  console.log("═".repeat(70));

  return poolInfo;
}

// Minimal interfaces
const IERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address, uint256) returns (bool)"
];

const IWETH9_ABI = [
  "function deposit() payable",
  "function approve(address, uint256) returns (bool)"
];

const IUniswapV3Factory_ABI = [
  "function getPool(address, address, uint24) view returns (address)"
];

const INonfungiblePositionManager_ABI = [
  "function createAndInitializePoolIfNecessary(address, address, uint24, uint160) payable returns (address)"
];

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
