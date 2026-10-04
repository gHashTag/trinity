# QUEEN Construction Game Contract

The construction layer turns research progress into a strategy-game view without
inventing resources, completion percentages, or work.

## Observable behavior

- `researched` nodes are completed structures.
- `researching` nodes are assembling structures and may animate at a bounded
  frame rate when reduced motion is not requested.
- `available` nodes are buildable blueprints.
- `locked` nodes remain sealed and cannot be presented as buildable.
- Dependency readiness is computed from canonical graph edges. It is not a
  fictional currency.
- Logistics routes use canonical dependency edges and expose whether the source
  structure is complete, assembling, or unavailable.
- The city exposes both a world view and a construction queue; both select the
  same canonical node and evidence inspector.
- Shared laboratory foundations use instanced rendering.
- Invalid or stale graph input produces no construction plan.

## Performance and accessibility

- The normal scene remains demand-rendered.
- Construction animation is capped at 12 frames per second and stops for
  reduced-motion users.
- Native buttons operate the construction queue and expose selection with
  `aria-pressed`.

