---
name: queen-continuation
applyTo: "apps/website/src/pages/Queen*.tsx,apps/website/src/pages/Queen*.css,apps/website/src/components/Queen*.tsx,apps/website/src/components/Queen*.css,apps/website/src/components/queen*.ts,apps/website/src/components/queen*.tsx,.claude/skills/queen-hive-visuals/SKILL.md"
---

# QUEEN continuation handoff

Use this file before continuing work in another chat.

## Repository and runtime

- Canonical source repo: `/Users/playra/Documents/Codex/2026-09-01/new-chat-2/work/queen-hive-coverage-2026-09-07/trinity`.
- Website package: `apps/website`.
- Local game URL: `http://127.0.0.1:4179/#/queen`.
- The active local page is the source of truth for current UI work. Do not inspect the old public apex page first.
- Work on the existing browser page only. Do not open another browser tab for QA, issue inspection, Specs, or collaboration.
- The current branch is `codex/queen-hive-status-fill`; latest published checkpoint is `3eb06200`.
- Do not force-push or merge into `main`. Publish through the existing branch/PR workflow and verify the green publish workflow before claiming that `t27.ai` has changed.

## Canonical product rules

This is a game, not a dashboard.

- One black Babylon hive scene contains the shared core, repository worlds, .t27 source cells, GitHub issue cells, provenance links, hover state, and one dynamic context/detail panel.
- The original point-down TRINITY symbol is the only game logo. Keep `withLabel={false}`. Do not add a wordmark to the game HUD.
- The central shared core is golden and translucent. Repository portals are outer regions. Provenance edges are thin. Catalog stars remain black-space background data.
- Yellow spec cells are transparent outlines. Never add a gradient, blur, matte frosting, stacked honey GPU volume, or second card over a cell. Do not restyle red issue cells or repository portals while fixing spec transparency.
- Hover is outline/lift only. Selection can show a temporary interaction rim. Do not replace status fills with hover colors.
- Every canonical spec may have a shared-core placement and source-repository placements. Count unique spec IDs, not placements. Selecting either endpoint highlights all same-ID placements and their provenance links.
- GitHub issue identity must stay visible at repository level and in the selected issue context. Preserve canonical `https://github.com/<repo>/issues/<number>` links.
- Source GitHub titles are quoted upstream data. Do not mutate or silently translate upstream issue text. Interface controls and Queen copy remain English by policy; the global site language controls localization.
- Use the existing `/specs?spec=<exact manifest path>` Spec Explorer as the central source surface. Do not create another compiler/source viewer.
- Do not infer T27 proof from a closed issue, lexical match, title, position, or gold color. Honey requires verified completion plus T27 proof.

## UX rules

- Keep the viewport focused on the field. Buttons are secondary chrome and should not consume the map.
- Use one context window/panel at a time. Selecting an issue or spec replaces the current context in the same game screen.
- On narrow screens, the Specs tab stays in the bottom command rail, has at least a 44px touch target, and has an explicit `Specs` label. The rail may scroll horizontally; do not shrink controls to unreadable icons.
- On phones, prioritize the field over metrics and search controls. Keep search behind the visible `Find cells` action and preserve pan, pinch zoom, hover, tap, and fit-view behavior.
- The homepage mounts the hive itself below the Hero, not a picture of it: the block
  renders the same `QueenCatalogHive` the `#/queen` route renders, lazily, and keeps the
  links to `#/queen`, `#/specs` and `#/queen?view=core`. One instance is ever mounted,
  because the homepage and `#/queen` are different routes. Reuse that component and the
  shared atlas — never fork atlas logic or write a second Babylon scene.
- The homepage and game must not acquire generic gradients, nested cards, purple defaults, or a redesigned global header.
- The language selector is global. Never add a local `RU / EN` switch inside QueenUniverse or Queen.
- Existing local browser page must remain the page used for visual QA. Refresh or resize it; do not open a new tab.

## Current implementation checkpoint

Recent published branch commits, newest first:

- `3eb06200`: removed Queen's duplicate local language switcher; Queen now reads global I18n only.
- `7a60868b`: field-first mobile shell; compact world nav, reduced top HUD, collapsed catalog search, larger map body.
- `8b352fc1`: visible/touchable mobile Specs tab and compact homepage Queen launch block below Hero.
- `5e1024dc`: translucent shared spec contours; removed stacked honey GPU cap and lowered spec contour alpha.

The current local UI has been visually checked at `390x844`. The map body is approximately `556px` high, the mobile `Find cells` action is visible, and the local language button is absent.

## Validation order

From `apps/website` run the narrowest relevant checks first:

```sh
npm run check:queen-responsive
npm run check:queen-displays
npm run check:queen-continuous
npm run check:queen-spec-mirrors
npm run check:spec-catalog
npm run build
```

`npm run check:queen-foundation` may report `no Chrome found - skipping the pick check`; that is an environment limitation, not proof that pointer picking passed.

Use browser QA on the already-open local page at these viewports when possible:

- 390x844 phone: field-first shell, no local language button, visible Specs label, 44px controls.
- 320x568 phone: Specs remains reachable through the horizontal rail.
- 768x1024 tablet: no clipped nav, no overlap, map remains dominant.
- 1440x900 desktop: original full hive composition, logo orientation, repo labels, links and transparent spec cells.

## Publication and blockers

- A successful local build does not mean the apex site is updated.
- Verify the GitHub Actions run for the exact published commit. Do not claim `t27.ai` is updated while publish is pending or failed.
- Known unrelated CI blocker: S3AI Brain CI can fail because `tri stress --health` is still a TODO and emits no `Score:` line. Do not change Queen code to fix that unrelated gate.
- Claude Code Review may fail from the Bun `tsconfig directory mismatch` infrastructure error before reviewing code. Rerun the failed job once; report it as infrastructure if it repeats.
- Local 4179 may show CORS errors when calling the production Railway health endpoint because Railway allows `https://t27.ai`, not `http://127.0.0.1:4179`. This does not justify changing the Queen visual or data model without a backend task.

## First action in a new chat

1. Read this file and `.claude/skills/queen-hive-visuals/SKILL.md`.
2. Check `git status --short --branch` and `git log -5 --oneline --decorate` in the Trinity repo.
3. Inspect the already-open `127.0.0.1:4179/#/queen` page; do not open a new tab.
4. State one local hypothesis and one cheap browser or contract check before editing.
5. Make the smallest reversible edit, run a focused validation immediately, then build.
6. Leave unrelated backend, global navigation, logo, source-title, and public-deployment behavior untouched unless the task explicitly asks for it.
