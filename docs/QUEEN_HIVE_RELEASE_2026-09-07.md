# Queen hive release — synchronization and acceptance

## Authority and scope

The user explicitly requested synchronization with the previous agent and
completion through release. Publish the reviewed issue-display work to the
existing t27.ai GitHub Pages target. No DNS, hosting migration, secrets, worker
capacity or new recurring automation is included.

## Reconciliation

- Previous agent task: QUEEN NEW. Read its handoff, GitHub PR960 and dirty tree.
  PR960 merged as de6187f21c6c8969f30097730ed84ff7e7ff95e9.
- The other agent's only remaining local edit changes camera alpha from pi/2
  to1.5*pi. Its tree remains untouched. Review this against the new native
  displays, not the removed texture cards; do not blindly copy a camera change.
- Requested a read-only handoff; the other task failed with provider429. Its
  recorded history and files remain available; do not retry the disabled work
  loop or allow two publishers to write the same files.
- Candidate86f03f4 includes the reviewed coverage and issue-display changes,
  based on main323b569. Preserve the no-plate, no-models, original-logo, facing
  wall, ray-plane picking and honey-hover decisions from the prior work.

## Plan / observable release contract

- [x] Read handoff, source history, dirty trees and existing publisher workflow.
- [x] Confirm user authorization; resolve target t27.ai, ghio main/root Pages.
- [ ] Re-run focused checks and obtain independent reconciliation review.
- [ ] Push the candidate and integrate it through a traceable GitHub PR.
- [ ] Run the existing apex publisher after source integration; preserve all
      unrelated static pages, CNAME and content-loss checks.
- [ ] Verify actual live entry/chunk/style bytes, issue/epic close-up, language,
      touch, original logo, no models and same-repository data boundaries.
- [ ] Record source/artifact/Pages identities and final outcome append-only.

Use the existing concurrency-controlled publisher in gHashTag/ghashtag.github.io
(`publish-website.yml`). Its workflow blob at inspection is
ef7697a17d2a41a3017a294806f27d72f2976ffa. An older scheduled publish is already
running; do not cancel it or force-push over it. Queue the release normally.
The trinity-side deploy-site workflow requires an absent GHIO_TOKEN; no secret
creation is needed because the apex publisher uses its existing permissions.

Expected validated UI assets: index-DUONrynA.js, Queen-qf8uYWJb.js,
QueenCombBabylon-Cmt3JeB4.js, Queen-he5fMj8H.css. Rebuild-generated changes must
be reconciled by byte/source evidence, not guessed from a green pipeline.
Type baseline remains179 existing errors; native card tests and specific
runtime checks are the scoped release gates, not a claim of a clean whole repo.

Prior RED/GREEN and review evidence: QUEEN_HIVE_DISPLAY_EVIDENCE.jsonl.
Append this release's observations to that ledger without rewriting history.
