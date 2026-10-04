# QUEEN space display — user-requested release additions

## Observed / source evidence

The user supplied a screenshot with a dead right-hand strip and opaque cell
cards. Homepage inspection confirms body and headings use the site's Outfit
font. Its self-hosted font assets also include JetBrains Mono for technical
readouts. Reuse these assets and black/white/neon-green tokens, not a new theme.

HYG v4.1 is a public catalog snapshot, not a live view of tonight's sky. Source:
https://github.com/astronexus/HYG-Database/blob/main/hyg/README.md (archived mirror,
commit c7f7f883fe678cc7680169a50ccd7dcc49b060ce). Its x/y/z are equatorial Cartesian
coordinates in parsecs, epoch/equinox2000.0. dist>=100000 denotes missing/dubious
parallax and must not enter the3D sample. Data license CC BY-SA4.0, David Nash /
Astronexus. Preserve attribution and share the derived catalog under that license.

## Acceptance before implementation

1. Field/canvas/overlay boxes fill their viewport after resize, fullscreen and
   phone layout; no reserved right-hand strip. At close-up, neighboring cells
   naturally cross the viewport edge; Whole hive restores the complete field.
2. Body/card titles use var(--font), matching homepage Outfit; technical numbers
   use the existing JetBrains Mono. UI remains RU/EN, keyboard/touch accessible.
3. Card surfaces are translucent, with a readable text scrim and restrained
   honey focus; underlying3D caps must not form an opaque lid over the stars.
4. Bundle a reproducible, bounded HYG subset with original xyz/distance/magnitude,
   source commit, source digest, exact filter and license. Reject nonfinite or
   dubious distance rows. No random particles may be called catalog stars.
5. Project the real3D positions as a space background, with subtle view parallax
   disabled by reduced-motion and no extra animation loop while idle/hidden.
   Explicitly label HYG4.1 / J2000 and source. This is a styled catalog view,
   not current sky ephemerides, telescope imagery or game-task locations in space.
6. Test data/projection/width/font/transparency behavior, build, independent
   review, desktop/mobile exact artifact, then repeat CI before publication.

Previous release authorization still applies to this requested extension.
No worker scheduling, secrets, DNS or new recurring automation is included.

## Exact-artifact checks

Observed clipping: outer viewport 832 px, implicit grid track/body only
756.273 px. A failing regression required the outer viewport track to use
minmax(0, 1fr); after correction, its 830 px inner width, body and both canvases
agree. Setting width only on the child did not fix the parent track.

Observed background-tab defect: the catalog loaded but canvas stayed 300x150
without a paint because document.hidden gated structural redraw. Data, resize
and reduced-motion changes now draw once even while hidden; only pointer RAF
is visibility-gated. The bitmap is resized only on a real size/DPR change.

Final local artifact: index-D5f5alzV.js, Queen-DkVys0TV.js,
QueenCombBabylon-BCtPNXkn.js, Queen-tRuWT4YQ.css and
hyg-v41-bright-DtBO8j0_.json. Desktop shows stars through the readable native
issue display. Mobile 390x844/DPR2/reduced-motion: no document overflow;
viewport inner width/body/canvases all 372 px; focused issue #33 is 293.727 by
339.164 px with Outfit text and canonical gHashTag/trios/issues/33 link.
The 4,965 source rows project to 898 stars in the tested desktop view and 1,079
in the phone view. These are renderer counts, not work throughput.

Independent read-only review reproduced the entire catalog from the pinned
CSV exactly and found no scoped blocker in orientation, projection, cleanup,
transparency or final structural-redraw/width fix. Release still requires a
fresh Website CI run and production artifact verification.
