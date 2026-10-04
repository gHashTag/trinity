# Issue displays and close-up — #890

One vertical slice: a hive cell is a readable display of an actual GitHub issue
or epic, with exact-number events and operator-controlled close-up.

## Research / design decision

- Babylon GUI has a separate texture resolution/renderScale; a256px event
  texture enlarged with the scene cannot recover missing text detail.
  Source: https://doc.babylonjs.com/features/featuresDeepDive/gui/gui/
- CSS and backing-store pixels differ on high-DPI screens. Keep scene rendering
  capped at2x, but use browser-native DOM text for the displays, outside bloom.
  Source: https://developer.mozilla.org/en-US/docs/Web/API/Window/devicePixelRatio
- Provide zoom/inspect/reset buttons and keyboard access, not a gesture-only
  interface. Source: https://www.w3.org/WAI/WCAG21/Understanding/pointer-gestures.html

Chosen visual: graphite hexagonal instrument displays, neon cyan information,
honey hover/focus, original hub logo. No generated artwork or invented metrics.
Do not migrate this existing t27.ai/GitHub Pages site to another hosting system.

## Acceptance before code

1. Merge public board, foundation and epics only within the same repository.
   Identity is repo+issue number; live board state wins over historical closure.
   Keep existing issue positions across polls. The hub remains reserved.
2. A cell's events join by issue number, never by module title or cell position.
   Epics show explicit child completion and recent own/child events, with the
   original event issue number visible. No events means an explicit empty state.
3. Semantic zoom: overview -> number/state -> title -> full issue/epic display.
   Native text stays sharp at close-up; render only a bounded visible subset.
   Full title/events remain accessible in the selected display without clipping.
4. A click/tap on a cell and a keyboard-operable Inspect control can frame it
  at useful reading size on phone and desktop. Wheel/buttons reach beyond the
   old8x cap. Fit restores the overview. Close-up survives ordinary polls.
5. Reduced-motion stops idle wall drift and camera interpolation. Dispose old
   event listeners and overlays on scene rebuild. Preserve other views,
   RU/EN, original logo and the previously corrected coverage provenance.

## Plan

- [x] Read current source and previous local corrections; remote main unchanged.
- [x] Research primary docs and record this observable contract.
- [x] Deterministic RED for identities/events/zoom/epic counts.
- [x] Implement issue display model, bounded DOM rendering and camera controls.
- [x] GREEN/regressions, exact build, interaction review and independent review.
- [x] Record outcome and production boundary; no fabricated deployment claim.

## Review-driven clarifications

An issue display cannot inherit module coverage or a historical issue by cell
position. It is explicitly unknown until the public ledger supplies a real
issue-to-module proof. Gate the entire foundation, not just the card merge, by
repository. Anonymous Bee slots without an exact running-issue target stay at
the hub. Their display motion does not prove worker identity or throughput.

Verification and remaining delivery boundary: `QUEEN_HIVE_DISPLAY_REPORT.md`.

The earlier coverage patch is preserved. The root TRI runtime is still known
to have dataless iCloud files; no historical ledger rewrite is authorized.
