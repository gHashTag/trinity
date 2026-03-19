# Trinity Node - Open Questions & Assumptions

This document tracks unresolved questions and assumptions made during the Node Operator Quick Start specification. These items require clarification before production release.

---

## Open Questions

### 1. Tokenomics & Rewards

| Question | Context | Priority |
|----------|---------|----------|
| **Exact reward formula** | Current spec uses 0.9 $TRI per 1M tokens. Is this final? How does it adjust with token price? | High |
| **Reward settlement timing** | Assumed ~24h settlement. What's the actual mechanism? On-chain or off-chain? | High |
| **Minimum payout threshold** | Is there a minimum $TRI balance before withdrawal? | Medium |
| **Gas fees for withdrawal** | Who pays gas? Is there a Trinity L2 to reduce costs? | Medium |
| **Staking lock period** | Can staked $TRI be unstaked immediately? Cooldown period? | Medium |

### 2. Network Infrastructure

| Question | Context | Priority |
|----------|---------|----------|
| **Mainnet coordinator URLs** | Placeholder `trinity.network` used. What are actual endpoints? | High |
| **Bootstrap node addresses** | Need production bootstrap nodes for libp2p discovery | High |
| **Model CDN/distribution** | How are models distributed? CDN? P2P? IPFS? | High |
| **Geographic regions** | Are there regional coordinators? How is latency optimized? | Medium |
| **Rate limiting** | How many jobs can a single node receive? Throttling mechanism? | Medium |

### 3. Security & Compliance

| Question | Context | Priority |
|----------|---------|----------|
| **KYC requirements** | Do node operators need KYC for large withdrawals? | High |
| **Slashing implementation** | On-chain smart contract or off-chain enforcement? | High |
| **Data retention policy** | What data is logged? GDPR compliance? | Medium |
| **Audit status** | Has the node software been security audited? | Medium |

### 4. Technical Implementation

| Question | Context | Priority |
|----------|---------|----------|
| **Tauri vs Electron** | Desktop app architecture confirmed as Tauri? | Medium |
| **Auto-update mechanism** | How are updates distributed? Signed binaries? | Medium |
| **Hardware wallet support** | Ledger/Trezor integration timeline? | Low |
| **Mobile app** | Is there a mobile node app planned? | Low |

### 5. DAO & Governance

| Question | Context | Priority |
|----------|---------|----------|
| **Node registration in DAO** | How do nodes register for governance participation? | Medium |
| **Voting weight** | Is voting power based on stake, contribution, or both? | Medium |
| **Proposal submission** | Can node operators submit governance proposals? | Low |

---

## Assumptions Made

### Assumed True (High Confidence)

| Assumption | Basis |
|------------|-------|
| Tauri 2.0 for desktop app | Documented in DESKTOP_APP_ARCHITECTURE.md |
| libp2p for networking | Industry standard for decentralized networks |
| SQLite for local storage | Common choice for desktop apps |
| ed25519 for wallet keys | Standard for crypto wallets |
| 90% reward to node operators | Documented in TOKENOMICS.md |
| BitNet-7B as initial model | Mentioned in roadmap |

### Assumed True (Medium Confidence)

| Assumption | Basis |
|------------|-------|
| Port 9000 for P2P | Common convention, not confirmed |
| 24h reward settlement | Reasonable for batch processing |
| Auto-reconnect on disconnect | Standard UX expectation |
| Prometheus metrics export | Common for monitoring |

### Assumed True (Low Confidence - Needs Verification)

| Assumption | Basis |
|------------|-------|
| Install script at trinity.network/install.sh | Placeholder URL |
| Docker image at trinitynetwork/node | Placeholder registry |
| Discord at discord.gg/trinity | Placeholder invite |
| Minimum 1,000 $TRI for staking | From TOKENOMICS.md, may change |

---

## Action Items

### Before Alpha Release

- [ ] Confirm reward formula with tokenomics team
- [ ] Set up production bootstrap nodes
- [ ] Create model distribution infrastructure
- [ ] Implement wallet creation flow
- [ ] Security audit of node software

### Before Beta Release

- [ ] Finalize mainnet coordinator URLs
- [ ] Implement staking smart contract
- [ ] Set up monitoring infrastructure
- [ ] Create troubleshooting documentation
- [ ] Test auto-update mechanism

### Before Mainnet

- [ ] Complete security audit
- [ ] Finalize KYC requirements (if any)
- [ ] Launch Discord community
- [ ] Publish API documentation
- [ ] Create video tutorials

---

## Contacts for Clarification

| Topic | Contact |
|-------|---------|
| Tokenomics | @tokenomics-team |
| Infrastructure | @infra-team |
| Security | @security-team |
| Legal/Compliance | @legal-team |

---

## Changelog

| Date | Update |
|------|--------|
| 2025-01-31 | Initial document created |

---

*This document should be updated as questions are resolved.*
