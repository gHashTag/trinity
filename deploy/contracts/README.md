# Trinity Token ($TRI) -- Smart Contracts

ERC20 + Permit + Vesting token for the Trinity ternary AI network.

**Total Supply:** 3^21 = 10,460,353,203 TRI (Phoenix Number)

**Sacred Formula:** phi^2 + 1/phi^2 = 3 (Trinity Identity)

---

## Prerequisites

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify installation:

```bash
forge --version
cast --version
anvil --version
```

### Install Dependencies

```bash
cd contracts

# Install OpenZeppelin v5.x
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Install forge-std (if not already present)
forge install foundry-rs/forge-std --no-commit
```

---

## Build

```bash
forge build
```

---

## Test

```bash
# Run all tests
forge test

# Run with verbosity (show logs)
forge test -vvv

# Run a specific test
forge test --match-test test_PhiIdentity -vvv

# Gas report
forge test --gas-report
```

---

## Deploy to Sepolia

1. Copy and fill in environment variables:

```bash
cp .env.example .env
# Edit .env with your values
```

2. Load environment:

```bash
source .env
```

3. Deploy:

```bash
forge script script/Deploy.s.sol:DeployTrinityToken \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

4. Save the deployed contract address to `.env`:

```bash
# Add to .env after deployment
TRI_TOKEN_ADDRESS=0x...
```

---

## Verify on Etherscan

If verification did not happen automatically during deployment:

```bash
forge verify-contract \
    <DEPLOYED_ADDRESS> \
    src/TrinityToken.sol:TrinityToken \
    --chain sepolia \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" \
        $FOUNDER_ADDRESS \
        $NODE_REWARDS_ADDRESS \
        $COMMUNITY_ADDRESS \
        $TREASURY_ADDRESS \
        $LIQUIDITY_ADDRESS) \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Claim Vested Tokens

```bash
source .env

forge script script/ClaimRewards.s.sol:ClaimRewards \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    -vvvv
```

---

## Local Development (Anvil)

```bash
# Start local node
anvil

# Deploy locally (in another terminal)
forge script script/Deploy.s.sol:DeployTrinityToken \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    -vvvv
```

---

## Contract Addresses

| Network | Address | Status |
|---------|---------|--------|
| Sepolia | `TBD` | Pending |
| Mainnet | `TBD` | Pending |

---

## Tokenomics

| Allocation | Share | Amount (TRI) | Vesting | Cliff |
|------------|-------|-------------|---------|-------|
| Founder & Team | 20% | 2,092,070,640 | 4 years | 1 year |
| Node Rewards | 40% | 4,184,141,281 | 10 years | None |
| Community | 20% | 2,092,070,640 | 3 years | None |
| Treasury | 10% | 1,046,035,320 | 5 years | 6 months |
| Liquidity | 10% | 1,046,035,320 | Immediate | None |

---

## Project Structure

```
contracts/
  foundry.toml          # Foundry configuration
  .env.example          # Environment variable template
  src/
    TrinityToken.sol    # Main token contract
  script/
    Deploy.s.sol        # Deployment script
    ClaimRewards.s.sol  # Vesting claim script
  test/
    TrinityToken.t.sol  # Foundry test suite
  lib/
    forge-std/          # Forge standard library
    openzeppelin-contracts/  # OpenZeppelin v5.x
```
