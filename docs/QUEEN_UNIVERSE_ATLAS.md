# QUEEN universe atlas — observable contract

Issue: gHashTag/trinity#890. Status: implementation contract, before code.

## Latest user correction — supersedes the default-home proposal

2026-09-07: The user rejected the dashboard-style atlas replacing the game and
explicitly requested an immediate return to the original map on a black
background. `#/queen` MUST render the original full-screen Queen hive again,
defaulting to the original runtime world. The new atlas is a retained draft at
the explicit `view=atlas` route only, never the default or a promoted home view.
Do not re-enable it on a future wave without user approval. Preserve the existing
hive's appearance, logo, camera, status fills and controls. Future shared-core
source links must be designed on that map, not by replacing it with a dashboard.
The requested roster rule remains: only actual `.t27` contributing repositories
belong on a future shared map. This is an inventory rule, not evidence of AGI.

Follow-up approved by user: render every contributing repository together in
the SAME Babylon.js map and apply the requested shared-source relationships,
without changing the overall design. Implemented as the optional catalog layer
inside `QueenCombBabylon`, mounted in the original Queen HUD, NOT as the draft
atlas page. See `QUEEN_CATALOG_HIVE.md`. The original logo has no wordmark.

## Scope and authority

Discover related **public** repositories, connect their existing open GitHub
issues to the already-vendored shared `.t27` catalog, and make every discovered
world navigable from one atlas. Do not move source, close issues, change worker
capacity, expose private repositories, deploy, or grant repository access.

The user's three Strands are a navigation taxonomy. README/descriptions are
SOURCE-CLAIM; repository metadata, public issue snapshots and catalog hashes are
OBSERVED; automatic Strand placement and spec matches are INFERENCE. Neither the
identity phi^2 + phi^-2 = 3 nor an architecture diagram establishes AGI.

## Acceptance contract

Latest user scope refinement: the game home and primary picker show only key
worlds with actual `.t27` source bytes in the shared catalog. Broad discovery
stays in the append-only research report, not in the game roster. `#/queen` is
the home atlas; `#/queen?repo=owner/repo` is that repository's existing hive.

1. Discovery scans all pages of the configured owner's public repository inventory.
   Include explicit seed worlds, existing catalog sources, repositories whose
   public descriptions or explicit TRIOS/TRINITY repository namespace identify the
   project, and same-owner links from related READMEs (bounded to four expansion
   rounds). Record inclusion reasons and source URLs. Never infer relation
   from common ownership alone. Record discovery boundaries and failed reads.
2. Repository identity is normalized `owner/repo`; issue identity is
   `owner/repo#number`. Reject private/mismatched metadata and noncanonical URLs.
   No PRs in issue counts. Archived repos stay visible and labeled.
3. Scan actual open issues, paginate with a declared cap, record per-repository
   observation time, total, loaded count, completeness and errors. Failure is
   UNKNOWN, never zero. Keep report creation append-only; publishable derived
   atlas updates atomically only after report/catalog validation.
4. Reuse the single sharedSpecCore matcher. Display path/symbol references
   separately from lexical candidates, always UNVERIFIED. No match means no
   defensible discovered link, not proof of absence. Keep hashes, evidence and
   canonical spec/issue links. No automatic honey, acceptance or issue closing.
5. Show GitHub owners separately from registered players, migration commitments
   and online presence. With no enrollment/presence ledger those remain UNKNOWN,
   not fake accounts or zero players. Saved local worlds are device preferences,
   not public commitments. No public contributor enumeration implies consent.
6. Each discovered world opens its own Hive or Shared Core. An issue can open the
   matching issue in Core directly, preserving repo scope. The atlas explains how
   one shared spec can help multiple worlds without claiming that it fixes them.
7. Preserve downward original logo, Outfit/JetBrains Mono, RU/EN, keyboard/touch,
   no page-width overflow on mobile, and reduced-motion. No simulated throughput.

## Verification

Pure tests first: unrelated/private exclusion, identity isolation, unknown/error
states, duplicate repo/issue rejection, no coverage from matching, stale catalog
rejection, shared opportunities spanning real repositories. Then focused lint,
typecheck ratchet, build, existing hive/world/core tests, exact desktop/mobile
browser checks. Production remains unchanged until explicitly authorized.
