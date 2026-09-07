# Central specification catalog — QUEEN integration

Bound issue: gHashTag/trinity#890. User designated
`https://t27.ai/#/specs?spec=specs%2Fdemos%2Fhello_world.t27` as the central
specification surface. This does not make draft edits accepted source changes.

## 📜 [SPEC] Contract

- One manifest (`public/t27/manifest.json`), vendored source corpus and existing
  Spec Explorer/compiler. The hive and atlas are derived navigation/issue views.
- Every hive spec source resolves to one exact manifest path and source repo.
  Basenames, fuzzy issue matches and map positions never establish identity.
- A cell opens the existing `/specs` route in embedded mode inside the current
  game. Returning closes that view without replacing the map or its camera.
- Canonical share/contribution/agent URLs use `https://t27.ai/#/specs?spec=…`.
  Embedded navigation preserves `embed=1`; the initial map revision is SHA-pinned.
- A missing/ambiguous path, invalid SHA pin or source hash mismatch fails visibly.
  It must not fall back to hello_world or display another file's compiler result.
- Embedded mode omits outbound social/contribution controls and disallows popups;
  exact-spec copy remains available with a selectable fallback.

## ⚙️ [CODE] Changes

`specCatalog.ts` owns canonical URLs and manifest resolution. QueenCatalogSpec
now hosts the existing Spec Explorer instead of maintaining a second raw-source
fetcher/viewer. Spec Explorer handles source validation and revision pins through
the shared compiler driver. Agent evidence includes canonical catalog URLs.

Compiler caches compare source bytes as well as path. Async selection requests
are generation-guarded; another spec's old source/results are cleared on selection.
The wrapper does not duplicate the Explorer's current-selection label or share
button, so browsing another spec inside it cannot leave a misleading outer link.

## 🧪 [TEST] Evidence

- Exact cross-check: 760 atlas sources / 760 manifest entries, matching paths,
  source repositories and SHA-256 values. No missing catalog mappings.
- RED: packets lacked canonical links. A separate real-WASM regression also
  reproduced a stale result for changed bytes under the same path (3666 instead
  of 3685 source bytes). Both pass after implementation.
- `npm run check:spec-catalog`: PASS, including all 760 identities, malformed and
  missing paths, SHA mismatch, same-source cache reuse and changed-source analysis
  using the shipped real compiler WASM, not a compiler mock.
- `check:queen-catalog`, `check:queen-atlas`, `check:queen-displays`,
  `check:queen-languages`: PASS. Focused ESLint and `git diff --check`: PASS.
- Typecheck ratchet: 179 existing errors across 26 files, no file gained errors.
- Local Vite build: PASS with `emptyOutDir:false,copyPublicDir:false`, retaining
  unchanged public catalog assets from the preceding complete build.
- Exact entry: `assets/index-hDdXjmRV.js`, SHA-256
  `fdc6764ae05e0dfd977150e2e8639dc01fe7ad92dc558b1f392c507cc1d144a8`.
  Reachable artifacts include `SpecExplorer-BxQHCMeJ.js`,
  `QueenCatalogHive-BPlLT5td.js` and `specCatalog-ONQ2RJG4.js`. Built identity
  gates and embedded-view policy were checked; public/dist manifests agree.
- Personal and project visual skills now preserve the central-catalog contract;
  both passed the skill validator.

## ☣️ [VERDICT] Remaining gates

No public deployment, corpus resync, DNS, credentials, workers or issue state
changes. The public URL was not visually verified as this new local artifact.
BrowserOS inventory contains no task-owned preview tab; the user forbids new tabs,
so no user/other-agent tab was taken over. Desktop/mobile embedded layout, clipboard
and return-to-map still require final browser visual acceptance. This follows the
BrowserOS task-owned-tab boundary, not evidence of a visual pass.

Future corpus updates must run `check:spec-catalog`: atlas/manifest drift cannot
be called synchronized merely because the two views show the same total count.
Existing issue/spec matches remain unverified; canonical links do not establish
generated-code coverage or permission to close a GitHub issue.
