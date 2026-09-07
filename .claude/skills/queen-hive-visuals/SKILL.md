---
name: queen-hive-visuals
description: Maintain QUEEN's floating hive, original point-down TRINITY logo, sharp issue displays and matching camera interactions.
---

# QUEEN hive

- Original TRINITY logo: flat top, apex DOWN, exact27 petals/135 edges, inside
  the hub hexagon. Never substitute a generic triangle or mirror the mark.
  The header SVG and central scene mark must agree on screen orientation.
- The field faces the viewer vertically. Its180-degree turn uses the shared
  `queenHiveOrientation.ts` transform: local(x,height,z)→world(-x,z,height).
  Camera stays at+Z. Changing camera alpha by pi is a back-side view, not a
  half-turn; it reverses horizontal handedness. Do not revive that old patch.
- Match homepage Outfit for prose and JetBrains Mono for technical readouts,
  using existing assets/tokens. Keep cells translucent and the viewport fully
  filled after resize. Catalog stars require source, epoch, units and license;
  the HYG4.1/J2000 projection is not live sky ephemerides or random decoration.
- All input uses the same coordinate convention: inverse ray-plane picking
  including wall drift, pan, cursor zoom, Inspect and bounds. Cell lift still
  comes toward the viewer. Native issue/epic text and HUD remain upright.
- Preserve original logo geometry in `QueenComb.tsx`, the same repo+issue
  identity across polls, exact event joins and canonical GitHub links. Historical
  GitHub titles are quoted source; only their individual nodes may be language
  exempt, never controls or whole cards.
- Honey is hover/focus feedback. T27-yellow needs real coverage provenance;
  red needs evidence of manual code. Missing issue→module proof is UNKNOWN,
  not completed/generated code. Do not invent events or worker throughput.

Before changing orientation, add a failing projection/interaction regression.
Run `npm run check:queen-displays` in `apps/website` (includes Babylon projection
and roundtrip tests), the affected regressions and build. Inspect the actual
logo and cards on desktop/mobile, reduced-motion, and test tap, pan and zoom.
Do not treat a data attribute or old screenshot as proof. Production publication
requires explicit user authority and the existing site release checks.
