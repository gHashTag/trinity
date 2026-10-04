# QUEEN continuous repository map

Issue: gHashTag/trinity#890. Local implementation only; no publication.

## Observable contract (before implementation)

- The shared Babylon scene contains the spec core, every contributing repository and every issue from the public atlas simultaneously.
- Repository selection changes camera focus and the in-game inspector, not the scene identity or the set of rendered repositories. `world` and `task` are shareable focus coordinates, not separate worlds.
- Each issue is identified by `owner/repo#number`. Equal issue numbers in different repositories never collide. Existing source edges and the central Spec Explorer remain intact.
- Repository issue regions do not cover the core or one another. Geometry, picking, projection and close-up use the same positions and scales.
- Whole map restores the complete scene; selecting an issue reveals its actual public details in the existing inspector. Search includes repository-qualified issues.
- Distant issue cells retain status fills; readable native cards appear at close range. Snapshot counts are not presented as live activity or throughput.
- Preserve black space, downward original logo, transparent spec cells, current typography, RU/EN, and one-window interaction.

## Verification plan

RED: continuous-map contract against the previous implementation. GREEN: all atlas identities, geometry/picking round trips, region separation, observation updates, and one-scene wiring. Run existing catalog, issue-display, orientation, language and central-spec gates; typecheck ratchet, focused lint and exact local production build. Browser acceptance is a separate gate and must not be inferred from static tests.

## Implementation and evidence

- `catalogUniverse` keeps the original 760 spec cells and their 760 source edges. Five repository issue regions add all 651 actual atlas issues in the same coordinate space.
- `QueenCatalogHive` always supplies both catalog and issue layers with `sceneKey="shared-universe"`. URL selection does not filter membership. Search includes exact repository-qualified issue titles; issue inspection and the central embedded Spec Explorer remain in-game.
- Cell rims, instanced caps, hover lift, ray-plane picking, native projection and focus use region positions/scales. Repository headings remain legible outside the issue field at overview. Native issue cards remain bounded to 32 visible displays.
- RED confirmed the absent continuous map implementation. A second RED demonstrated the cross-repository epic bug: a closed child number in another repository incorrectly completed the local epic. GREEN scopes progress to the repository.
- `npm run check:queen-continuous`: PASS — all identities, core preservation, non-overlapping regions, coordinate/picking round trips, unchanged positions after observations/appended historical issues, and camera sizing for 1440×800, 390×600 and 390×300.
- `npm run check:queen-displays`: PASS, including point-down geometry, stars, status colors and signal lifecycle.
- `npm run check:queen-catalog`, `npm run check:queen-languages`, `npm run check:spec-catalog`: PASS (760 central source identities, 246 EN/RU keys).
- Focused ESLint: PASS. Typecheck ratchet: unchanged 179 pre-existing errors across 26 files; no file gained errors.
- Personal and project `queen-hive-visuals` skills now preserve the one-scene contract. Both passed `quick_validate.py`.
- `npm run check:queen-atlas` and `npm run check:queen-worlds`: PASS.
- Final `npx vite build`: PASS (1148 modules, 2m 16s). Existing large-chunk and mixed-import warnings remain. The three referenced font files are present in `dist/fonts`.
- Exact local artifact: `assets/index-CZFHTLxu.js`, SHA-256 `43ecf1e535b6c3fafcbd0f8ea8cea7f93515fd896de659d14f68445549fc985c`; catalog `QueenCatalogHive-WIuZqjIM.js`; renderer `QueenCombBabylon-Aw3-siI5.js`. Built catalog contains the continuous scene and region headings. Dist atlas exactly matches the source snapshot (760 specs / 5 repos / 651 issues).

## Remaining acceptance gate

BrowserOS inventory contains no task-owned preview tab. The existing local preview is user-owned; no new tab was opened. Permission to test the existing tab was requested. Desktop/mobile/reduced-motion visual acceptance and actual click walkthrough remain unverified until that access is available. The geometry checks above are not a substitute for visual acceptance. No deployment, DNS, secret or worker changes were made.
