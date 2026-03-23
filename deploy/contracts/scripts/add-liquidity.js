/**
 * Add Liquidity to Uniswap V3 TRI/ETH Pool
 *
 * Adds concentrated liquidity position:
 *   - 523M TRI
 *   - 1,494 ETH
 *   - Price range: $0.001 - $1.00 (wide for discovery)
 *
 * Usage:
 *   npx hardhat run scripts/add-liquidity.js --network mainnet
 */

const hre = require("hardhat");
require("dotenv").config();

// Uniswap V3 Addresses (Ethereum Mainnet)
const UNISWAP_V3_POSITION_MANAGER = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// Pool parameters
const FEE_TIER = 3000; // 0.3%

// Price range (wide for initial discovery)
const MIN_PRICE = 0.001; // $0.001/TRI
const MAX_PRICE = 1.0;   // $1.00/TRI
const ETH_PRICE_USD = 3500;

// Amounts
const TRI_AMOUNT = 523_017_660n * 10n ** 18n; // 523M TRI
const ETH_AMOUNT = hre.ethers.parseEther("1494");

// Tick spacing for 0.3% fee tier
const TICK_SPACING = 60;

async function main() {
  console.log("═".repeat(70));
  console.log("ADD LIQUIDITY TO TRI/ETH POOL");
  console.log("═".repeat(70));

  const [deployer] = await hre.ethers.getSigners();
  console.log("\nDeployer:", deployer.address);

  // Load deployment info
  const fs = require("fs");
  let tokenAddress, poolAddress;

  try {
    const deployment = JSON.parse(fs.readFileSync(`deployment-${hre.network.name}.json`));
    tokenAddress = deployment.tokenAddress;
  } catch (e) {
    tokenAddress = process.env.TRI_TOKEN_ADDRESS;
  }

  try {
    const poolInfo = JSON.parse(fs.readFileSync(`pool-${hre.network.name}.json`));
    poolAddress = poolInfo.poolAddress;
  } catch (e) {
    poolAddress = process.env.POOL_ADDRESS;
  }

  if (!tokenAddress || !poolAddress) {
    throw new Error("Token or pool address not found. Deploy token and create pool first.");
  }

  console.log("TRI Token:", tokenAddress);
  console.log("Pool:", poolAddress);

  // Sort tokens
  const [token0, token1] = tokenAddress.toLowerCase() < WETH_ADDRESS.toLowerCase()
    ? [tokenAddress, WETH_ADDRESS]
    : [WETH_ADDRESS, tokenAddress];

  const triIsToken0 = token0.toLowerCase() === tokenAddress.toLowerCase();

  // Calculate tick range
  // Price = token1/token0, tick = log1.0001(price)
  const minPriceRatio = triIsToken0
    ? ETH_PRICE_USD / MAX_PRICE   // If TRI is token0, price is WETH/TRI
    : MAX_PRICE / ETH_PRICE_USD;  // If WETH is token0, price is TRI/WETH

  const maxPriceRatio = triIsToken0
    ? ETH_PRICE_USD / MIN_PRICE
    : MIN_PRICE / ETH_PRICE_USD;

  const tickLower = Math.floor(Math.log(minPriceRatio) / Math.log(1.0001) / TICK_SPACING) * TICK_SPACING;
  const tickUpper = Math.ceil(Math.log(maxPriceRatio) / Math.log(1.0001) / TICK_SPACING) * TICK_SPACING;

  console.log("\n" + "─".repeat(70));
  console.log("Position Parameters:");
  console.log("─".repeat(70));
  console.log("  TRI Amount:", hre.ethers.formatEther(TRI_AMOUNT), "TRI");
  console.log("  ETH Amount:", hre.ethers.formatEther(ETH_AMOUNT), "ETH");
  console.log("  Price Range: $", MIN_PRICE, "-", MAX_PRICE, "per TRI");
  console.log("  Tick Range:", tickLower, "to", tickUpper);
  console.log("  Token0:", token0, triIsToken0 ? "(TRI)" : "(WETH)");
  console.log("  Token1:", token1, triIsToken0 ? "(WETH)" : "(TRI)");

  // Get position manager
  const positionManager = await hre.ethers.getContractAt(
    "INonfungiblePositionManager",
    UNISWAP_V3_POSITION_MANAGER
  );

  // Calculate amounts based on token order
  const amount0 = triIsToken0 ? TRI_AMOUNT : ETH_AMOUNT;
  const amount1 = triIsToken0 ? ETH_AMOUNT : TRI_AMOUNT;

  // Mint position
  console.log("\n" + "─".repeat(70));
  console.log("Minting LP position...");
  console.log("─".repeat(70));

  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour

  const mintParams = {
    token0: token0,
    token1: token1,
    fee: FEE_TIER,
    tickLower: tickLower,
    tickUpper: tickUpper,
    amount0Desired: amount0,
    amount1Desired: amount1,
    amount0Min: 0, // No slippage protection for now
    amount1Min: 0,
    recipient: deployer.address,
    deadline: deadline
  };

  console.log("Mint params:", JSON.stringify(mintParams, (k, v) =>
    typeof v === 'bigint' ? v.toString() : v
  , 2));

  const tx = await positionManager.mint(mintParams, { gasLimit: 5000000 });
  const receipt = await tx.wait();

  // Parse events to get tokenId and liquidity
  let tokenId, liquidity, amount0Used, amount1Used;

  for (const log of receipt.logs) {
    try {
      const parsed = positionManager.interface.parseLog(log);
      if (parsed && parsed.name === "IncreaseLiquidity") {
        tokenId = parsed.args.tokenId;
        liquidity = parsed.args.liquidity;
        amount0Used = parsed.args.amount0;
        amount1Used = parsed.args.amount1;
      }
    } catch (e) {}
  }

  console.log("\n✅ Liquidity added!");
  console.log("   Token ID:", tokenId?.toString());
  console.log("   Liquidity:", liquidity?.toString());
  console.log("   Amount0 used:", hre.ethers.formatEther(amount0Used || 0n));
  console.log("   Amount1 used:", hre.ethers.formatEther(amount1Used || 0n));
  console.log("   Tx hash:", receipt.hash);

  // Calculate pool value
  const triValue = Number(hre.ethers.formatEther(triIsToken0 ? amount0Used : amount1Used)) * 0.01;
  const ethValue = Number(hre.ethers.formatEther(triIsToken0 ? amount1Used : amount0Used)) * ETH_PRICE_USD;
  const totalValue = triValue + ethValue;

  console.log("\n" + "─".repeat(70));
  console.log("Pool Value:");
  console.log("─".repeat(70));
  console.log("  TRI value: $", triValue.toLocaleString());
  console.log("  ETH value: $", ethValue.toLocaleString());
  console.log("  Total:     $", totalValue.toLocaleString());

  // Save liquidity info
  const liquidityInfo = {
    network: hre.network.name,
    poolAddress: poolAddress,
    tokenId: tokenId?.toString(),
    liquidity: liquidity?.toString(),
    amount0: amount0Used?.toString(),
    amount1: amount1Used?.toString(),
    tickLower: tickLower,
    tickUpper: tickUpper,
    priceRange: { min: MIN_PRICE, max: MAX_PRICE },
    totalValueUSD: totalValue,
    txHash: receipt.hash,
    timestamp: new Date().toISOString()
  };

  fs.writeFileSync(
    `liquidity-${hre.network.name}.json`,
    JSON.stringify(liquidityInfo, null, 2)
  );

  console.log("\n" + "═".repeat(70));
  console.log("LIQUIDITY ADDED - $TRI NOW TRADEABLE!");
  console.log("═".repeat(70));
  console.log(JSON.stringify(liquidityInfo, null, 2));

  // Trading links
  console.log("\n" + "─".repeat(70));
  console.log("Trade $TRI:");
  console.log("─".repeat(70));
  console.log("  Uniswap: https://app.uniswap.org/swap?outputCurrency=" + tokenAddress);
  console.log("  DEXTools: https://www.dextools.io/app/ether/pair-explorer/" + poolAddress);
  console.log("  Etherscan: https://etherscan.io/token/" + tokenAddress);

  console.log("\n" + "═".repeat(70));
  console.log("KOSCHEI IS IMMORTAL | $TRI TRADING LIVE | φ² + 1/φ² = 3");
  console.log("═".repeat(70));

  return liquidityInfo;
}

const INonfungiblePositionManager_ABI = [
  "function mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256)) returns (uint256,uint128,uint256,uint256)",
  "event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)"
];

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
