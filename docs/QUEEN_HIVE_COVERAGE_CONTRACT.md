# Hive coverage provenance — continuation of #960

## Observed / scope

Baseline: `323b569024e5b7e71ffbcb448e4db789010b68f7`.
PR #960 is merged. The module snapshot names `gHashTag/trios`, while the
coverage hook selects `trinity`. The manifest does not list `trios`. Folder
prefixes and punctuation-stripped basenames can nevertheless turn cells yellow.
This is one bounded correction to coverage provenance, not a migration or deploy.

## Observable contract (before implementation)

1. Coverage belongs to the module snapshot's repository, never the board's
   repository or a hard-coded other repository. Missing repo or missing corpus
   is UNKNOWN, not a measured zero or manual-code verdict.
2. Yellow requires an exact repository-relative `modulePath` explicitly claimed
   by a `.t27` manifest row in that repository, with `coverageSchemaVersion: 1`.
   The current producer's `module` is a display label, not this mapping. Until
   explicit mappings exist, the legacy corpus remains UNKNOWN. Neither folder naming, a spec
   display name, another module's basename nor punctuation removal is evidence.
3. A known corpus with no exact claim leaves a module red (migration debt,
   not proof of how all its code was authored). An empty cell stays blue.
   Unknown coverage is blue with an explicit RU/EN unknown label, not red/yellow.
4. A repository change must not retain another repository's claims. A changed
   claim set of the same size must invalidate the scene's coverage signature.
5. Keep the original logo, facing wall, retina scaling, honey hover/tap lift,
   live event cards, all navigation modes and public-read-only boundary.

Review refinement: source paths also must be canonical relative paths (no `..`,
empty segments, absolute paths or backslashes). The primary `t27` corpus uses
unprefixed paths; other repositories use `<repo>/...`, as the producer does.
Scene cleanup must hide and clear old hover text before new coverage is drawn.

The explicit mapping schema is a **consumer contract / TARGET**, not a claim
that the generator already supplies it. No mapping data is fabricated here.

## Plan

- [x] Inspect merged GitHub work and current artifact; isolate clean checkout.
- [x] Record this contract before production changes.
- [x] Reproduce false yellow with an executable RED test (10/12 failed).
- [x] Implement repository-scoped parsing and exact matching; GREEN tests (24 checks initially).
- [x] Build and verify the exact artifact on desktop/mobile/reduced motion.
- [x] Independent read-only review; record evidence and remaining risks.

Final: scoped coverage correction verified locally. The reduced-motion audit
also found an inherited limitation: Babylon canvas drift is unconditional;
it is recorded for the next UI wave, not claimed as accessibility compliance.
There is no production deployment and no completed root TRI wave.

## Boundaries

Manifest coverage is SOURCE-CLAIM, not generated-code parity or Queen acceptance.
Module and closed-issue layers share positions, not identities: do not label an
unrelated closed issue as covered merely because a module occupies that position.
No production publication, scheduler, worker capacity, secret or KIE changes.
The old workspace TRI runtime is unavailable (iCloud dataless `tri_core.py`;
bounded `./tri factory --json` exited 142 after five seconds). Do not rewrite its
history or report a completed TRI wave without running it.
