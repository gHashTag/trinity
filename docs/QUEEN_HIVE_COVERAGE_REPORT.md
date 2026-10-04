# Queen hive continuation — 2026-09-07

## Outcome

Inspected merged agent work (PR #960 and subsequent main at
`323b569024e5b7e71ffbcb448e4db789010b68f7`). Continued with one verified local
correction: repository-scoped, explicit coverage provenance. No deployment,
branch push, worker-capacity change, secret change or scheduler was performed.

OBSERVED: the production field shows the `gHashTag/trios` snapshot but labels
2 module cells T27-covered and 113 manual. The old hook borrowed `trinity`
claims; path-name heuristics could create yellow without evidence. The producer
also uses `module` as a display label, not a mapping to a code directory.

Now the consumer requires a versioned explicit `modulePath` mapping. Legacy or
unavailable corpus data remains UNKNOWN, visibly localized in RU/EN. No names,
basenames or folder prefixes manufacture coverage. Current local result:
**115 module cells UNKNOWN, zero falsely yellow/manual cells**. Empty cells stay
blue. Hover text names the module separately from the colocated closed issue;
scene changes clear previous coverage text.

SOURCE-CLAIM: even a future valid manifest is not proof of generated-code parity
or Queen acceptance. TARGET: teach the producer to emit evidence-backed mappings
for `trios`; this patch does not fabricate those mappings.

## Verification

Working directory: `apps/website` in this isolated checkout.

- `npm ci --no-audit --no-fund`: 247 packages installed.
- `npm run check:queen-coverage`: initial RED 10/12; review regressions RED10/34;
  final GREEN **34 checks**.
- `npm run check:queen-honesty`: **113 checks**.
- `npm run check:queen-languages`: **246 EN / 246 RU keys**.
- `npx eslint src/components/queenHud.ts src/components/QueenCombBabylon.tsx src/pages/Queen.tsx`: exit0.
- `npm run typecheck:ratchet`: no increase; **179 existing errors in26 files**.
- `npm run build`: exit0, final build20.42s; inherited font/import/chunk warnings.
- `git diff --check`: exit0.
- Independent read-only review: initial blockers reproduced and fixed; final
  review has no blocking findings, tests and independent probes passed.
- BrowserOS Neo on the relaunched production preview: desktop1440×1000 DPR2,
  mobile390×844 DPR2 and reduced-motion media. Correct unknown legend, no
  horizontal overflow, original logo/facing wall/models0,12 event cards.
  Hover names issue/module; language rebuild clears the old tooltip. A120ms
  touch gesture selects the module. Desktop/mobile screenshots inspected.

Exact artifact: `index-BnanlRBx.js`, `Queen-B3tb7_0h.js`,
`QueenCombBabylon-CeHqHYyD.js`, `Queen-i3Cbtdey.css`.
SHA256 `dist/index.html`:
`ccb22ae3bcf9fed4aa9c248d52601487343c3963b5b09948858c4d60c6fe6413`.
SHA256 Babylon chunk:
`bfdc8727cf3563881909a95278206eb5541a9eb2b2a88bdfdd813659fb0211c9`.

## Limits and resume point

Preview: <http://127.0.0.1:4178/#/queen>. These changes are local and uncommitted.
The user's older dirty worktrees and append-only ledgers were preserved.

The root workspace's `tri_core.py` and state files are iCloud dataless.
Both `./tri factory --json` and `./tri doctor --json`, run with a5-second bound,
timed out (exit142). No `tri wave` or `tri learn` completion is claimed. This
checkout's evidence JSONL is the continuation record; do not reconstruct or
overwrite inaccessible historical ledgers.

The first zero-duration touch injection did not produce a pick; the subsequent
120ms gesture did. Reduced-motion layout renders correctly, but the existing
Babylon drift is unconditional: do not claim full reduced-motion compliance.
The live worker readout was0/4 during inspection; this correction does not launch
Bees and visual events are not worker throughput.

Next continuation starts from this checkout, this contract and the evidence
JSONL. Do not replay the old cabinet prototype or overwrite the merged hive.

## Three distinct next waves

1. **Real migration evidence:** generate a versioned `trios` module-path ledger
   from specifications, generated artifacts and test/review proof.
2. **Bee execution and review:** diagnose the observed0/4 and waiting-review
   state from scheduler decisions and real worker logs; fix one dispatch blocker.
3. **Hive interaction/accessibility:** stop canvas drift under reduced motion
   and verify touch/hover lifecycle across repeated scene rebuilds.
