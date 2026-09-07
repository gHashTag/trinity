# QUEEN responsive interaction contract — 2026-09-07

Bound issue: gHashTag/trinity#890. Preserve the approved continuous Babylon map,
point-down original mark, black space, near-transparent gold spec faces, source/core
identity links, and Outfit / JetBrains Mono. This is not a redesign.

## Sources and decisions

- [W3C target size enhanced](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html): use 44×44 CSS-pixel map and context controls, with equivalent chooser access for tiny overview cells. This is a design target, not a claim of whole-site AAA conformance.
- [W3C reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html): the spatial map retains two-dimensional navigation; its surrounding controls and text must reflow at 320 CSS pixels without information loss.
- [MDN touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/touch-action): scope custom pan/pinch to map surfaces; preserve normal document zoom and text scrolling outside the map.
- [MDN env](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/env): reserve safe-area insets; use dynamic viewport height and measured header height rather than guessed mobile offsets.

## Observable acceptance before code

1. Toolbar rows never overlap the map/each other, including RU labels and 320px width. Canvas fits the available stage, including short landscape; DPR stays capped at 2.
2. Controls have readable text; mobile inputs/selects use at least 16px. Detail text does not shrink to 10px simply because the screen is narrow. Existing font files remain the same.
3. One-pointer pan and two-pointer pinch work from canvas AND spec faces. A drag, pinch or cancelled gesture never opens a cell. A normal tap still selects it; keyboard activation still works. Wheel works over the same surfaces.
4. A hovered cell answers with the honey outline without changing its semantic fill. Clicking a spec opens its dynamic card in the same screen, with source/core links and canonical Spec Explorer access.
5. Only one context window is visible: repository, issue, spec card or embedded canonical Explorer. Legacy runtime context must not compete with the shared catalog; copying does not create another window.
6. Verify desktop, tablet, narrow portrait, short landscape and reduced-motion in the actual browser, and independently review the exact diff before publishing.

GitHub language is audited separately from RU/EN interface text. A snapshot without
Cyrillic is not proof that every issue body is English; do not silently translate
quoted source text only in the UI or equate a spec match with completed work.
