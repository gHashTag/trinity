# Corona issue proof in the public map

Issue: https://github.com/gHashTag/trinity/issues/1360
Dependency: https://github.com/gHashTag/tt-trinity-corona/pull/13

The GitHub issue adapter formerly assigned `coverage: unknown` to every issue.
Closing Corona #1 therefore left a red cell even if a native proof was added.
The reader now implements `apps/website/specs/queen/issue_proof.t27` for the
explicitly supported Corona issues #1 and #12. Other repositories stay unknown.

Acceptance requires a closed issue, exact SHA-256 pins for the spec, native
seal, vectors, replay tool, Makefile and CI workflow, plus successful canonical
push CI and GDS at the current default-branch SHA. PR/fork runs cannot substitute
for that accepted source. The latest matching failed run overrides an older
successful run. A failed refresh clears a cached positive result. Public reads
omit credentials; the successful proof cache lasts one minute.

The selected small Corona world is read from GitHub so dated open issue rows do
not override observed closure. Only a complete first page can update the portal
backlog count. A single inspected issue cannot establish the repository total.
Accepted cells show the immutable spec and exact CI/GDS source links and the
observation timestamp in the inspector.

## Reproduce

From `apps/website`:

```sh
npm ci
npm run check:queen-issue-proof
npm run check:queen-worlds
npm run check:queen-displays
npm run check:queen-continuous
npm run typecheck:ratchet
npm run build:ci
```

The checked generator analyzes/types the `.t27` with the vendored compiler,
executes its two tests (19 assertions), and verifies generated policy and all
16 conformance vectors. The reader test uses real SHA-256 over isolated HTTP
fixtures for acceptance, tampering, missing files, reopen, CI identity/failure,
rate limits and cache invalidation. The `.trinity/seals` receipt is created by
native t27c, not assembled by the reader.

To update evidence, first review the upstream accepted source and CI, then edit
the spec pins, regenerate with `node scripts/issue-proof-from-spec.mjs`, recreate
the native seal and run all checks. Do not weaken the reader to make a cell gold.

## Boundaries

Until Corona PR13 is accepted with successful canonical push CI/GDS, this reader
must leave its cells unverified. Unit fixtures are not live acceptance evidence.
The existing TypeScript ratchet has 179 baseline errors across 26 files; the
new change must add none. The game embedding at app.t27.ai has a separate Queen
source pin and requires deployment verification after the source PR is accepted.
This change establishes neither a fabricated chip nor reward/payment settlement.
