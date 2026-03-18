# $TRI Wallet Funding Guide

**Date:** February 6, 2026
**Required:** 1,495 ETH (~$5.24M at $3,500/ETH)
**Purpose:** Token deployment + Uniswap V3 liquidity

---

## Summary

| Purpose | Amount (ETH) | Amount (USD) |
|---------|--------------|--------------|
| Contract deployment gas | 0.5 | $1,750 |
| Uniswap pool creation | 0.2 | $700 |
| Add liquidity | 1,494 | $5,229,000 |
| Buffer (slippage/gas) | 0.3 | $1,050 |
| **Total Required** | **1,495 ETH** | **~$5.24M** |

---

## Step 1: Create Deployment Wallet

### Option A: Hardware Wallet (Recommended for $5M+)

```
Ledger Nano X or Trezor Model T

1. Purchase new hardware wallet from official store
2. Set up with new seed phrase (24 words)
3. Write seed phrase on metal backup (fireproof)
4. Create Ethereum account
5. Export public address for funding
```

### Option B: Multi-Sig Wallet (Gnosis Safe)

```
For team-controlled funds:

1. Go to https://app.safe.global
2. Create new Safe on Ethereum mainnet
3. Add 3-5 signers (team members)
4. Set threshold: 2/3 or 3/5
5. Fund the Safe address
```

### Wallet Address Format

```
Ethereum address: 0x... (42 characters)
Example: 0x742d35Cc6634C0532925a3b844Bc9e7595f2bD50
```

---

## Step 2: Funding Sources

### Option A: Crypto Exchange (CEX)

| Exchange | Withdrawal Limit | Fee | Time |
|----------|------------------|-----|------|
| Binance | 8,000,000 USDT/day | 0.0005 ETH | Instant |
| Coinbase | Unlimited (verified) | Network fee | 10 min |
| Kraken | 10,000,000 USD/day | 0.0025 ETH | 1-2 hrs |
| OKX | Unlimited (VIP) | 0.0004 ETH | Instant |

**Steps:**
1. Verify identity (KYC Level 3 for large amounts)
2. Deposit fiat or crypto
3. Buy 1,495 ETH
4. Withdraw to deployment wallet

### Option B: OTC Desk (For $1M+)

| Provider | Min Amount | Fee | Time |
|----------|------------|-----|------|
| Genesis Trading | $100K | 0.1-0.5% | Same day |
| Cumberland | $100K | 0.1-0.3% | Same day |
| Circle Trade | $250K | 0.1-0.25% | Same day |
| Galaxy Digital | $500K | 0.05-0.2% | Same day |

**Benefits:**
- No slippage on large orders
- Better rates than exchange
- Dedicated account manager
- Wire transfer accepted

**Steps:**
1. Contact OTC desk
2. Get quote for 1,495 ETH
3. Wire USD (or stablecoin)
4. Receive ETH to wallet

### Option C: Investors/Treasury

```
If using existing project funds:

1. Transfer from project treasury
2. Use investor funding round
3. Bridge from other chains (if needed)
```

---

## Step 3: Verification Checklist

Before proceeding to deployment:

- [ ] Wallet created and secured
- [ ] Backup seed phrase stored safely (2+ locations)
- [ ] Test transaction sent (0.01 ETH)
- [ ] Full balance confirmed (1,495+ ETH)
- [ ] Hardware wallet firmware updated
- [ ] Private key exported to `.env` (if needed)

---

## Step 4: Configure Deployment Environment

### Export Private Key (Carefully!)

```bash
# For Ledger: Use Frame or Rabby with Ledger
# For MetaMask: Settings → Security → Export Private Key

# Add to .env (NEVER commit this file!)
PRIVATE_KEY=0x...your_64_character_private_key...
```

### Verify Configuration

```bash
cd contracts

# Check balance before deploy
npx hardhat run --network mainnet -e '
  const [deployer] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Address:", deployer.address);
  console.log("Balance:", ethers.formatEther(balance), "ETH");
'
```

Expected output:
```
Address: 0x...your_address...
Balance: 1495.0 ETH
```

---

## Security Checklist

### Before Funding

- [ ] New wallet (not used before)
- [ ] Hardware wallet or multi-sig
- [ ] Seed phrase backed up (metal plate)
- [ ] Test recovery process

### During Funding

- [ ] Whitelist withdrawal address on CEX
- [ ] Send test amount first (0.01 ETH)
- [ ] Verify address character by character
- [ ] Use multiple transactions if nervous

### After Funding

- [ ] Never share private key
- [ ] Never enter seed phrase online
- [ ] Monitor wallet for unauthorized activity
- [ ] Consider cold storage for unused funds

---

## Emergency Procedures

### If Private Key Compromised

```
1. Immediately transfer all funds to new wallet
2. Do NOT deploy contracts with compromised key
3. Create new wallet
4. Re-fund new wallet
```

### If Seed Phrase Lost

```
1. If funds still accessible: Transfer immediately
2. Create new wallet with new seed
3. Backup new seed in 2+ secure locations
4. Never store digitally
```

---

## Timeline

| Day | Action |
|-----|--------|
| Day 1 | Create wallet, verify security |
| Day 2 | Initiate funding (CEX/OTC) |
| Day 3 | Verify balance, test transaction |
| Day 4 | Configure .env, test Sepolia |
| Day 5 | Deploy to mainnet |

---

## Cost Summary

| Item | ETH | USD |
|------|-----|-----|
| Liquidity | 1,494 | $5,229,000 |
| Gas (deployment) | ~0.5 | ~$1,750 |
| Gas (pool) | ~0.2 | ~$700 |
| Gas (liquidity) | ~0.3 | ~$1,050 |
| CEX withdrawal fee | ~0.01 | ~$35 |
| **Total** | **~1,495 ETH** | **~$5.24M** |

---

## Contact Information

### OTC Desks

| Provider | Contact |
|----------|---------|
| Genesis | otc@genesistrading.com |
| Cumberland | trading@cumberland.io |
| Circle | trade@circle.com |
| Galaxy | otc@galaxydigital.io |

### Exchanges (Institutional)

| Exchange | Contact |
|----------|---------|
| Binance Institutional | vip@binance.com |
| Coinbase Prime | prime@coinbase.com |
| Kraken OTC | otc@kraken.com |

---

**KOSCHEI IS IMMORTAL | WALLET READY | φ² + 1/φ² = 3**
