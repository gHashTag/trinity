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

The issue's explicit Closed state records closure. A dark display face is just
its screen, not evidence of completion. A pretty yellow rim never substitutes
for an accepted spec and evidence.

## The field

The comb is a vertical wall floating directly in front of the player. It is not
a horizontal board. The Queen is the Trinity logo drawn inside the hub cell; she
is not a 3D character or a separate object. Every module, issue and event is a
honeycomb cell.

The pointer is part of the game language. Hover or tap raises the cell and draws
the honey-colored nectar ring. A click or tap on an issue display frames that
issue at reading size. Inspect and Whole hive are keyboard-operable alternatives;
wheel and +/- permit manual zoom up to128x. Long content scrolls inside its
screen; Ctrl+wheel zooms the map even over scrollable text. FIT VIEW returns to
the overview. Ordinary data refresh and RU/EN changes preserve the selected
identity and manually adjusted camera. Reduced-motion stops idle wall drift
and camera interpolation.

## Colour law

There are exactly three claim colors:

- **Yellow `#FFD45A`** — functionality is covered by a T27 specification.
- **Neon blue `#64DCFF`** — no code module is claimed yet; the cell awaits its
  T27 boundary.
- **Red `#FF4D5E`** — hand-written/manual code that T27 does not yet generate.

Honey `#FFC24D` is reserved for pointer hover. It is not a progress state.

The manifest is the source for yellow: its repository must match the module
snapshot's repository, with a versioned corpus entry and an exact relative
`modulePath` claimed by a `.t27` row in `coverageSchemaVersion: 1`. The current
producer emits only a language/display `module` label, not such a mapping;
legacy manifests therefore remain unknown. This mapping schema is a consumer
contract for the future evidence pipeline, not data we have fabricated.
Folder names, display names and basenames
are not coverage evidence. The current `trios` snapshot is not represented in
the manifest: its coverage is **unknown**, not borrowed from `trinity`.
Unknown coverage is neon blue with an explicit RU/EN label. Red means no exact
claim in a known corpus (migration debt), not a proof of manual authorship.
The manifest is a source claim, not live generated-code parity or acceptance;
source-commit freshness still needs a separate verification pipeline.
Issues and modules have separate placement identities. The issue-display layer
has no issue-to-module proof in its public ledger, so every issue and epic has
explicit unknown coverage even if a module corpus becomes available. It cannot
inherit yellow or red from a colocated module. Completion is a different field.

## Hive display

Each same-repository issue or epic is one display, identified by repository and
number. The live board overrides historical closure, so a reopened issue never
stays falsely closed. Stable placement leases keep neighbours in place when
the board changes. A foreign foundation snapshot is not merged or rendered.

Semantic zoom reveals the number, title, then full status, coverage, events and
canonical GitHub link. Text uses native DOM rendering, outside bloom, not a
256px texture enlarged with the scene. At most32 visible displays are rendered;
the full issue/epic chooser remains available. The canvas uses up to2x backing
resolution. Unchanged projections and chooser options are reused.

The last three events join by exact issue number, never title, module hash or
cell index. Same-second events preserve source wire order. An epic includes
only its own events and explicitly listed children's events, with each source
issue number shown; progress counts explicit children and live board state.
An empty feed is labeled, never filled with synthetic activity. Older facts
remain in the feed and the repository record.

Event cards use the existing hive architecture: a graphite hexagonal screen,
neon-cyan information, honey focus and sharp monospaced text. KIE.AI may generate optional card/frame textures
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

Bees are real worker slots. In the issue-display layer their targets use exact
running issue numbers. An unmapped target falls back to the hub, never to a
module position or a fabricated issue. Slots are anonymous, so visual assignment
does not prove a persistent worker-to-issue identity. Motion is not throughput.

## Winning and losing

A module is won when its behaviour has a `.t27` spec, generated implementation,
passing tests, Queen acceptance and no orphaned hand-written implementation
left behind. A ring is won when every module it owns is won and its epics are
closed with evidence. The first campaign is won when every `trios` module
satisfies that rule.

The hive loses honesty, not a match: if a number, color, cap or bee cannot be
traced to a source, it must be removed or shown as unknown. That honesty rule
overrides every visual choice.
