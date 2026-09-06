# Queen Hive gameplay

Queen Hive is not an ornament around the repository. It is the operational game
whose win condition is the repository's migration: replace hand-written code
with T27 specifications while fixing real bugs in parallel.

## Campaign objective and priority

The first campaign target is **`trios`**. Its modules are the first ring of
manual code to claim, specify, generate, test and review. Other repositories may
join only after `trios` has an auditable spec-to-evidence trail. No visual state
may claim progress without a wire event, merged diff, test result or dated
snapshot behind it.

The full cycle is:

1. **Issue** — a real bug, missing behaviour or manual-code boundary.
2. **Spec** — write the `.t27` source of truth and its acceptance criteria.
3. **Bee** — an isolated worker makes the smallest generated change.
4. **Review** — Queen examines the diff, tests and invariants.
5. **Evidence** — accepted work records the proof and seals the corresponding
   cell.

A cell becomes capped only when its issue is closed. A pretty yellow rim never
substitutes for an accepted spec and evidence.

## The field

The comb is a vertical wall floating directly in front of the player. It is not
a horizontal board. The Queen is the Trinity logo drawn inside the hub cell; she
is not a 3D character or a separate object. Every module, issue and event is a
honeycomb cell.

The pointer is part of the game language. Hover or tap raises the cell and draws
the honey-colored nectar ring. A click selects it and opens its context. Pan,
wheel zoom and FIT VIEW use the same wall-plane geometry as picking, so the cell
under the hand remains the cell the game reads.

## Colour law

There are exactly three claim colors:

- **Yellow `#FFD45A`** — functionality is covered by a T27 specification.
- **Neon blue `#64DCFF`** — no code module is claimed yet; the cell awaits its
  T27 boundary.
- **Red `#FF4D5E`** — hand-written/manual code that T27 does not yet generate.

Honey `#FFC24D` is reserved for pointer hover. It is not a progress state.

The manifest is the source for yellow: only `repo: "trinity"` spec claims may
turn a module yellow. A missing, stale or unparseable manifest never becomes
zero coverage; it remains unknown coverage.

## Hive display

The latest wire event per module becomes a compact card on its cell, bounded by
the hexagon: issue number, event kind, module path and age. The display is
capped at twelve newest cards so the wall remains readable. Older facts remain
available through the feed and the repository record.

Event cards use the existing hive architecture: a dark cell face, one event-tone
border and monospaced slots. KIE.AI may generate optional card/frame textures
through `apps/website/scripts/queen-kie-assets.mjs`, but generated art may never
add a state or number that the wire did not send. The current KIE key returns
401 “Organization access is disabled”; no generated asset is shipped or claimed.

## Progression

Each round Queen prioritizes:

1. an open `trios` bug whose module is red, so repair and migration proceed
   together;
2. a manual module with the highest real blast radius;
3. a review that can unblock a capped cell;
4. only then work outside `trios`.

Bees are real worker slots. They fly toward the module named by their current
event, never toward decorative targets. An event without a resolvable module
lights nothing rather than guessing.

## Winning and losing

A module is won when its behaviour has a `.t27` spec, generated implementation,
passing tests, Queen acceptance and no orphaned hand-written implementation
left behind. A ring is won when every module it owns is won and its epics are
closed with evidence. The first campaign is won when every `trios` module
satisfies that rule.

The hive loses honesty, not a match: if a number, color, cap or bee cannot be
traced to a source, it must be removed or shown as unknown. That honesty rule
overrides every visual choice.
