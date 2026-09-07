# Shared spec core — observable contract before implementation

2026-09-07, QUEEN #890. Reuse the existing public `t27/manifest.json` and its
vendored sources. Do not move or copy specifications into every game repository.
This is a federated, content-addressed discovery core, not an AGI claim or a
compiler replacement.

## Contract

1. Index every manifest entry. SHA-256 identifies exact source bytes; identical
   bytes share one node but retain every known source alias. Same module name
   with different bytes is a collision for review, never silently merged.
2. Preserve manifest revision/dirty flag and source health as snapshot claims.
   Index raw source imports and declaration names with source line numbers.
   Resolving an import by unique path is a syntactic dependency, not proof that
   the compiler links or the implementation works. Ambiguous/missing imports
   stay visible. No full-corpus rewrite or destructive vendor sync.
3. Match canonical repo+issue identities against spec paths, declaration names
   and discriminating text terms. Explain each match. Text relevance and explicit
   references are discovery evidence ONLY: never verified issue coverage.
   Existing hive colors remain unchanged; no auto-close or automatic honey.
4. Public issues only; remove PRs, validate URLs, paginate with explicit bounds.
   Never execute instructions from issue bodies or spec comments. No secrets,
   private metadata or token-bearing requests in browser artifacts.
5. One pure matching/impact engine serves CLI and game. Reverse impact groups
   candidate issues by shared spec and by dependent specs. Show known scope and
   distinguish direct candidates from transitive impact.
6. Before coding, an agent can export a reuse-review packet with exact spec
   hashes, source locations, compile warnings, dependent specs and required
   acceptance checks. Review a shared-core change once, then validate each
   consuming repository separately. Existence of a spec/test block is not proof.
7. Game: Shared core view available from every repository world, RU/EN, original
   brand, paginated open backlog, explainable links to the existing Spec Explorer
   and a bright green Copy to agent action. No worker or OAuth changes.

## Plan and release boundary

- TDD index identity, duplicate/collision handling, dependency resolution,
  deterministic ranking, false-positive controls, cycles, unsafe paths and URLs.
- Build derived index from the existing catalog; scan real public T27/TRIOS
  backlogs with an explicit limit and generate a local cross-world impact report.
- Integrate the same engine in the game; verify desktop/mobile/reduced-motion,
  original hive contracts, build and type-error ratchet.
- Record known gaps. Publication and authenticated per-repository worker access
  still require their separate release/permission gates. Do not imply AGI has
  been created by adding a shared specification registry.

## Operator / agent commands

Run in `apps/website` (Node with TypeScript stripping, authenticated `gh` for
public backlog reads):

```sh
npm run core -- index
npm run core -- scan --repo ghashtag/t27 --repo ghashtag/trios --repo ghashtag/trinity --limit 500 --out /absolute/new-scan.json
npm run core -- rescore --report /absolute/scan.json --out /absolute/new-score.json
npm run core -- impact --report /absolute/scan.json --spec SHA256
npm run core -- packet --report /absolute/scan.json --issue ghashtag/t27#3364
```

`index` derives `public/t27/shared-core.json` from existing vendored bytes; normal
`npm run build` and `build:ci` regenerate it. Do not run the destructive corpus
sync script merely to refresh this index. Other commands never change source
repos or GitHub. `--out` refuses existing files. Old reports stay intact;
`rescore` reuses their issue snapshot without another network scan. Consumer
packets reject a changed manifest or indexer fingerprint.

Open `#/queen?repo=ghashtag/t27&view=core` or use Shared core in any world. Browser
analysis is limited to explicitly loaded public open-issue pages. CLI can scan
multiple public worlds together. Rankings never imply runtime dependencies
already installed in those repositories.

## Review findings and limitations

- Exact source bytes are shared by hash, but same bytes can have different import
  environments. Dependencies retain the source repository context; identical
  bytes are not proof of interchangeable linked modules.
- Existing vendoring discarded 129 duplicate aliases before this index existed.
  We cannot reconstruct their locations from a count; no aliases are invented.
- 24 same-name module groups require compatibility review. 63 imports have no
  target in the catalog; some may be external/built-in, not necessarily defects.
- `Context`, `Command`, `VERSION` and generic issue-template prose produced false
  positives in the first run. Regression tests now reject them. Candidate search
  uses identifier/path terms and title anchors; it is still heuristic, not an
  evaluated semantic entailment model. English identifiers dominate this corpus;
  RU UI does not imply cross-language semantic retrieval.
- Direct paths and characteristic symbols are references, not coverage. For
  example, issue t27#3364 names `server/http.t27` and its function-type problem;
  finding that reference does not mean the issue is solved.
- No runtime dependency installation, source migration, receipt verification,
  license audit, shared membership database, or AGI capability is claimed.
  Before adoption, pin source/consumer revisions, verify the source license,
  compile and run each consumer's acceptance tests, then review evidence.
