# Queen issue displays — #890

## Outcome

Implemented and independently reviewed in the isolated checkout based on
`trinity@323b569024e5b7e71ffbcb448e4db789010b68f7`. Local built preview:
http://127.0.0.1:4179/#/queen. This report does not claim production publication.

- Native, sharp issue/epic screens replace the old256px event textures.
- Semantic zoom: overview, number, title, full display. Maximum manual zoom128x;
  Inspect frames a real issue at reading size. Whole hive restores the overview.
- At most32 visible displays, memoized options and unchanged projections;
  no per-frame regeneration of the whole backlog.
- Real issue events, canonical GitHub links and explicit epic child progress.
  Live board state overrides dated closure; same-second events keep wire order.
- RU/EN, native keyboard controls, mobile tap/inner scrolling, reduced-motion,
  original logo, Kanban/Mission Map/Factory/Technology Tree retained.
- No foreign-repository foundation, positional coverage transfer, synthetic
  tasks, generated activity or module-index Bee fallback.

The earlier coverage correction is preserved. The issue ledger supplies no
issue-to-module coverage proof: all issue displays explicitly remain unknown,
even when a module corpus is known. Closure and T27 coverage are separate facts.

## Research decision

Keep the current Babylon scene and use native DOM text outside its bloom.
[Babylon GUI documentation](https://doc.babylonjs.com/features/featuresDeepDive/gui/gui/)
describes texture resolution separately; enlarging a256px texture cannot recover
detail. [MDN devicePixelRatio](https://developer.mozilla.org/en-US/docs/Web/API/Window/devicePixelRatio)
explains CSS/backing pixels. [W3C pointer gesture guidance](https://www.w3.org/WAI/WCAG21/Understanding/pointer-gestures.html)
supports single-pointer/keyboard controls alongside zoom gestures.
Choosing the DOM overlay and culling strategy is our engineering inference.
No hosting migration or decorative bitmap generation is needed for live text.

## Commands and results

Run from `apps/website`:

```sh
npm run check:queen-displays
npm run check:queen-coverage
npm run check:queen-honesty
npm run check:queen-languages
npx eslint src/components/QueenHiveDisplays.tsx src/components/queenHiveDisplay.ts src/components/QueenCombBabylon.tsx src/components/queenHud.ts src/pages/Queen.tsx
npm run typecheck:ratchet
npm run build
git diff --check
npm run preview -- --host 127.0.0.1 --port 4179 --strictPort
```

Initial display model test was RED before implementation (missing module,
exit1). The final model/scene contract passes; coverage34, honesty113 and
RU/EN246/246 checks pass. Changed-file lint and diff check pass. Type ratchet:
179 existing errors in26 files, no increase. This is not a clean full typecheck.
Build passed in24.66s. Existing large chunk and unresolved font-path warnings
remain; card text uses the system monospace fallback and was inspected visually.

Independent review found and rechecked fixes for swallowed body interactions,
module-vs-issue event identity, camera refocus, coverage leakage, foreign
foundation fallback and unmapped Bee targets. Final review: no scoped blockers.

## Exact artifact / observed UI

| Artifact | SHA-256 |
| --- | --- |
| `dist/index.html` | `dc51177d575faca19f584aeb87133864a472a2395b1cc47357189bf02ac543f8` |
| `index-DUONrynA.js` | `16bd7cbe563ba4d308663ee524ca42b5831f208197d1319b78bbdabde7ecacc1` |
| `Queen-qf8uYWJb.js` | `fec595fd373f81371d5272542f9b45f85cd3500793d4d9168a25d3913ab77265` |
| `QueenCombBabylon-Cmt3JeB4.js` | `85eee3ff8bb8ac309a12d537e8a5052a0dbf4c39788d1a6c3b7a6b22421bd6a7` |
| `Queen-he5fMj8H.css` | `239914468305e304cf4c8171249ba0c80ea3db0f1379a9dbd277e9a2c3a4b7f0` |

BrowserOS Neo loaded these exact assets. Desktop1440x1000 and mobile390x844,
both DPR2, were visually inspected. The current public ledger produced1206
issue/epic displays, seven visible close-up screens, zero claimed T27/manual
issue cells. These are observed public-ledger counts, not verified engineering
completion or worker throughput.

- Epic1334: Closed, explicit children5/7, empty recent feed, correct trios URL.
- Issue1540: title, state, its own wire events and canonical GitHub URL.
- Mobile:294x339 CSS close-up;120ms touch on neighbour selects1541; overflowing
  content scrolls internally (observed scrollTop181.5), selection retained.
- Whole hive: zoom1.00 and no detail overlays. Shift+Tab then Enter activates
  Inspect. Reduced-motion flag confirmed. No horizontal document overflow.
- Earlier built preview verified card-body wheel zoom28.27 to35.37 and EN/RU
  scene rebuild preserving35.37 and selected1540; the relevant code is unchanged
  in the final artifact. Some background browser gesture/wait calls timed out;
  subsequent DOM observations confirmed their effects. No instant-latency or
  FPS claim is made.

## Risks / resume point

Production is unchanged. Publish only through the existing authorized workflow
after release approval; do not recreate the site with another hosting service.
Source files, QA, append-only evidence and this report are the resume point.
Root `data/status.json` is still iCloud compressed/dataless; the earlier bounded
TRI diagnostics timed out. No doctor/wave/learn success or historical ledger
rewrite is claimed for this UI work. No new automation was created.

The public feed is a bounded recent window; empty does not mean no historical
work. The foundation can be dated. Anonymous slots do not prove persistent Bee
identity. Existing global type debt, bundle size and GPU/FPS profiling remain
outside this slice. The skill's spec-first RED/review/exact-artifact gates drove
the corrections above; no new global skill or CLI command was needed.

## Three distinct next slices

1. Release: approve publication, then verify the exact live t27.ai asset hashes.
2. Provenance: produce versioned issue-to-module-to-T27 evidence for real colors.
3. Navigation: epic dependency links, issue search and large-backlog performance
   profiling, without changing worker counts or inventing game events.
