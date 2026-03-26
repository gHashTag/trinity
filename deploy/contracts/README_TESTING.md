# Trinity Smart Contracts — Testing Guide

## Prerequisites

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

## Running Tests

### All Tests

```bash
cd deploy/contracts
forge test
```

### Specific Contract

```bash
forge test --match-path test/TrinityVault.t.sol
forge test --match-path test/TrinityVesting.t.sol
```

### With Gas Reporting

```bash
forge test --gas-report
```

### Detailed Output

```bash
forge test -vvv
```

## Test Coverage

### TrinityVault.t.sol (13 test suites, ~40 tests)

| Suite | Tests | Coverage |
|-------|-------|----------|
| First-Depositor Protection | 3 | Virtual offset, donation attack resistance |
| Internal Accounting | 2 | _managedAssets vs balanceOf |
| Deposit/Withdraw | 3 | Cooldown, partial withdraw |
| Preview Functions | 3 | Empty/non-empty vault |
| Convert Functions | 3 | Assets <-> shares |
| Capacity Constraints | 2 | Max deposit, capacity limit |
| Admin Functions | 3 | Pause, emergency, recovery |
| Edge Cases | 3 | Min deposit, zero deposit, no cooldown |

### TrinityVesting.t.sol (7 test suites, ~35 tests)

| Suite | Tests | Coverage |
|-------|-------|----------|
| Stream Creation | 7 | All 4 curves, validation, constraints |
| Vesting Calculations | 5 | Linear, EXP, LOG, BACKWEIGHTED |
| Claim Operations | 3 | Single, multiple, non-recipient |
| Cancellation | 4 | Penalty, timing, permissions |
| NFT Transfers | 3 | Mint, transfer, cancel restriction |
| Overflow Protection | 2 | Large amounts, long durations |
| View Functions | 3 | Vested, claimable, getStream |

## Key Security Tests

### First-Depositor Attack (TrinityVault)
```solidity
test_FirstDepositorProtection()
test_DonationAttackResistance()
```

### Arithmetic Overflow (TrinityVesting)
```solidity
test_NoOverflowLargeAmountLongDuration()
test_NoOverflowBackweightedCurve()
```

### Cancellation Penalties (TrinityVesting)
```solidity
test_CancelStreamWithPenalty()
test_MaxPenaltyConstraint()
```

### Internal Accounting (TrinityVault)
```solidity
test_InternalAccountingMatchesDeposits()
test_DonationNotCountedInTotalAssets()
```

## Gas Optimization

View gas usage:
```bash
forge test --gas-report
```

## Coverage Report

```bash
forge coverage
```

## CI/CD

Tests run automatically on:
- Pull request to `main`
- Push to `feat/*` branches

## v2.1 Security Improvements Verified

1. ✅ Virtual offset (1e6 * 1e18) prevents first-depositor attacks
2. ✅ Internal accounting prevents donation attacks
3. ✅ SafeCast prevents uint128 overflow
4. ✅ Math.mulDiv prevents arithmetic overflow
5. ✅ Max duration (10 years) prevents timestamp overflow
6. ✅ Per-stream claim tracking prevents double-claim
7. ✅ Slash during unbonding vulnerability fixed
8. ✅ Reputation hysteresis prevents oscillation

## References

- [ERC-4626 Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [Sablier V2 Audit](https://github.com/sablier-labs/v2-core/blob/main/audits/2023-04-peckshield.pdf)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
