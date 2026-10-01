# SUPERSEDED: token sale, SAFT and pre-allocation documents

**Status: superseded on 2026-09-24. Kept as history. Do not use, sign or send.**

The $TRI design of record is in
[`gHashTag/trinity-fpga`](https://github.com/gHashTag/trinity-fpga) at commit
`d7e9718e9`:

- `docs/docs/depin/principles.md` -- owner decision of 2026-09-24: "100% of it
  is mined by accepted work -- there is no pre-mine and no sale."
- `docs/docs/depin/tokenomics.md` -- "There is no allocation." Founder/team 0%,
  treasury / pre-sale / liquidity 0%.
- `specs/trinet/mint_on_acceptance.t27` -- `GENESIS_MINTED 0 // no pre-mine, no
  allocation, no sale`; cap 3^21 = 10,460,353,203 TRI; chains TON and Solana;
  trust model V1 M-of-N attestor quorum, then V2 optimistic challenge, then V3
  zk receipt.
- `contracts/README.md` -- reference minters only; nothing is deployed.

A token sale or a SAFT (a promise of future tokens in exchange for money)
directly contradicts "no sale", and every pre-allocation table (founder, team,
treasury, public sale, liquidity) contradicts "100% mined by accepted work".

## Files in this directory that this note covers

| File | What it proposes |
|---|---|
| `SAFT_AGREEMENT.md` | a Simple Agreement for Future Tokens for $TRI |
| `SALE_PREP_REPORT.md` | preparation of a $TRI token sale |
| `SALE_EXECUTION_REPORT.md` | execution plan for a seed round using the SAFT |
| `TOKENOMICS.md` | a pre-allocated $TRI distribution |
| `3M_STRATEGY.md` | a $1M token sale channel and public-sale allocation |
| `BUSINESS_MODEL.md` | a 15% public sale / liquidity allocation |
| `INVESTOR_OUTREACH.md` | SAFT terms in investor messaging |

Any statement in these files about selling, pre-allocating or vesting $TRI is
not the current design. Equity-financing material for the company is a separate
matter and is not addressed by this note.
