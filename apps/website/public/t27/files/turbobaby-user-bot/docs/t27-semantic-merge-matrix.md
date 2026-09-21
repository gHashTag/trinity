# TurboBaby `.t27` semantic merge matrix

Measured against the working tree on 2026-09-13. This document is the HISTORY of one merge: the
six same-named drafts that once lived directly under `specs/` against the canonical files that
absorbed them. Its counts describe that moment and are deliberately not updated as the corpus
grows -- for the corpus as it stands today (43 tracked specs on 2026-09-21) read
[`t27-contract-map.md`](t27-contract-map.md), which is the index this file is not.

At the time of the merge, ten files under `specs/turbobaby/` were the canonical contract owners;
`specs/agents/turbobaby.t27` is the independently namespaced owner card. The six same-named drafts that previously lived directly under `specs/` were exhaustively
mapped below and then removed. They were never a second authority, and keeping them after the
merge would recreate the ambiguity this review was intended to eliminate.

Status meanings:

- **Merged** — the canonical file carries the behavior, sometimes under the clearer name
  shown here.
- **Superseded** — the declaration is deliberately not copied because the canonical model
  expresses the same rule without the legacy representation or chooses one documented side
  of a conflict.
- **Deferred follow-up** — the draft exposed a useful requirement, but the available evidence
  is insufficient for executable domain arithmetic. The requirement is retained here and in
  the relevant epic; the duplicate draft is still removed.

The source ranges below refer to the final pre-merge working-tree drafts and are exhaustive over
every top-level declaration in each one; comments and function-local declarations are covered by
their containing range.

## Availability

Canonical owner: `specs/turbobaby/availability.t27`.

| Root declaration range | Outcome |
| --- | --- |
| `specs/availability.t27:42-52` module and identity | **Superseded** by canonical module/identity. |
| `:65-97` unit predicate and four reason outcomes | **Merged** as `has_an_available_unit`, `is_bookable`, `unbookable_reason`, and the four reason constants. |
| `:103-167` measured bookability, CLICK lifecycle/stale rate, redirects and price-list-only guard | **Merged**. The misleading root name `FAMILIES_OFFERED_WITH_NO_STOCK` is **renamed** `OFFERED_WITH_ZERO_AVAILABLE_FAMILIES`; CLICK is explicitly rented/unavailable, not at the office. |
| `:185-238` live-check authority, answer record and partition helpers | The authority and `may_confirm` rule are **Merged**. The packed answer record and duplicate partition arithmetic are **Superseded** by the direct policy plus canonical status arrays. |
| `:250-397` tests and invariants | **Superseded** by canonical predicate, CLICK, redirect, live-check, partition and count tests/invariants. |

## Bike catalog

Canonical owner: `specs/turbobaby/bike_catalog.t27`; it names availability through
`REUSES_AVAILABILITY_ID` and consumes its abstract bookability result rather than declaring
the formula or status names twice. Brace imports are intentionally absent because the pinned
compiler currently lowers them to an empty import.

| Root declaration range | Outcome |
| --- | --- |
| `specs/bike_catalog.t27:34-42` module and identity | **Superseded** by canonical module/identity. |
| `:51-118` family/unit distinction, class/body/status domains and measured fleet totals | Family/unit identity is **Merged**. Class/body taxonomy and row consistency are **Merged** in catalog; status/fleet availability facts are **Superseded** by the availability owner and seed-derived row tests. The root's five-body list is superseded by the measured six-body canonical list, including `cruiser`. |
| `:131-154` CLICK, Forza and XMAX worked rows | **Merged** as canonical row fixtures and availability facts. CLICK is one rented unit and zero available. |
| `:165-207` honest kilometre name, public fields, D14 forbidden fields and service privacy | **Merged** verbatim in meaning as `KM_FIELD`, `FORBIDDEN_KM_ALIASES`, `PUBLISHABLE_UNIT_FIELDS`, `FORBIDDEN_UNIT_FIELDS`, and `SERVICE_RECORDS_ARE_PUBLIC`. |
| `:213-318` tests and invariants | **Superseded** by canonical taxonomy, row, availability-boundary and privacy tests/invariants. The incorrect 38-unit header remains evidence only; 37 seed rows are authoritative. |

## Deposit tiers

Canonical owner: `specs/turbobaby/deposit_tiers.t27`; it validates the lengths/totals of its
own deposit tables and names availability ownership through `REUSES_AVAILABILITY_ID`, without
copying shared availability declarations.

| Root declaration range | Outcome |
| --- | --- |
| `specs/deposit_tiers.t27:36-46` module and identity | **Superseded** by canonical module/identity. |
| `:56-127` tiers, client-message evidence, counterexample to rate monotonicity, lookup and unmatched-value policy | **Merged** into the six measured seed tiers, histogram, direct family lookup, `publishable_deposit`, and `deposit_needs_tier_log`. A positive unmatched value is published and logged, never snapped. |
| `:136-192` money/passport XOR record and amount consistency | The XOR rule is **Merged** as `DEPOSIT_FORMS`, `DEPOSIT_FORM_RULE`, and `deposit_form_is_legal`. The legacy packed transaction record is **Superseded** because individual renter deposits are prohibited repository data. |
| `:201-257` payment methods, unpublished FX conversion, hundred rounding and fixed refund | The public policy is **Merged** in `DEPOSIT_FOREIGN_CURRENCY_RULE`. Executable FX/refund transaction state is a **Deferred follow-up** for the commerce runtime; it cannot be promoted without a published FX authority and private transaction boundary. |
| `:266-416` tests and invariants | Tier/form/zero/unmatched behaviors are **Superseded** by canonical tests. FX/refund examples remain a **Deferred follow-up** with the arithmetic above. |

## Pricing honesty

Canonical owner: `specs/turbobaby/pricing_honesty.t27`; it accepts a `bookable: bool` already
decided by availability and names that owner through `REUSES_AVAILABILITY_ID`.

| Root declaration range | Outcome |
| --- | --- |
| `specs/pricing_honesty.t27:40-54` identity and copy-count evidence | Identity is **Superseded**. Single implementation ownership remains documented in canonical pricing/rental terms; historical copy counts remain review evidence, not a contract. |
| `:62-127` source enum, latency, forbidden answers, finite optional money/fraction filters | Source provenance is **Merged** as `SOURCE_NONE`, `SOURCE_DOOR`, `SOURCE_FILE_REFERENCE` in `OptionalRate`. Positive door values alone are client prices; zero and negatives are invalid. Float-specific filters and latency are **Superseded** by the exact integer/tagged representation. |
| `:152-269` rounding, answer record, door/referral honesty and divergence helpers | Door/referral/render/cart behavior is **Merged**. Float answer and divergence records are **Deferred follow-ups** for commerce reconciliation/logging; file-reference values are audit-only and cannot reach the client. |
| `:283-293` reconciliation fixtures and known wrong-rate evidence | **Merged** as canonical measured fixtures and source-aware tests; the legacy step factors remain audit evidence only. |
| `:299-476` tests, invariants and latency bench | **Superseded** by canonical zero/absence/source/render/cart/bookability tests and invariants. Divergence logging and performance remain **Deferred follow-ups** with the helpers above. |

## Rental terms

Canonical owner: `specs/turbobaby/rental_terms.t27`; `REUSES_PRICING_ID` records that pricing
honesty owns the live price authority, without an unsupported import or a duplicate constant.
`TWIN_IS_RESOLVED` means every root declaration below has an explicit outcome, not that the
review snapshot has already been deleted.

| Root declaration range | Outcome |
| --- | --- |
| `specs/rental_terms.t27:40-50` module and identity | **Superseded** by canonical module/identity. |
| `:56-90` class-discount values, base-rate meaning and overstatement diagnostic | Exact measured discount fixtures are **Merged** in basis points. The root helper that implicitly composes a class discount is **Superseded**: source data does not specify class/term composition, so canonical leaves composition open. |
| `:103-242` three day bands, interval algebra and discount validation | **Merged** as exact basis-point bands and canonical day-band lookup/coverage invariants. |
| `:279-300` non-publishable term range and audit bounds | **Merged**: a range yields no client number; the door/human is authoritative. |
| `:325-343` monthly presence counts and diagnostic | Monthly/non-derivation semantics are **Merged** as canonical measured monthly fixtures. The root float diagnostic is **Superseded** by integer audit arithmetic. |
| `:356-525` tests and invariants | **Superseded** by canonical band, rounding, non-publication, monthly and open-composition tests/invariants. Where arithmetic differed, canonical chooses round-daily-first then multiply (5070), not legacy round-total (5055). |

## Ride game

Canonical owners: `specs/turbobaby/ride_game.t27` for the inventory/handling boundary and
`specs/turbobaby/ride_runtime.t27` for the browser lifecycle. This split keeps a live catalog
decision separate from collision, submission and cleanup state.

| Root declaration range | Outcome |
| --- | --- |
| `specs/ride_game.t27:41-64` identity, Garden replacement and forbidden side effects | Identity is **Superseded** by the canonical module/identity. No order write, no fallback rider and no price surface are **Merged** into the canonical game/runtime contracts. |
| `:75-171` four-slot fixture, a deliberately drifted roster and subset helpers | The useful subset law is **Merged** as `family_is_rideable`, the measured catalog witness and its subset invariants. The four-slot roster and duplicated availability calculation are **Superseded**: the game reads `/api/bikes?available_only=true` at mount time and consumes availability's decision. |
| `:192-213` empty-roster behavior | **Merged** as explicit empty/unavailable states. No synthetic family is mounted when fetch, import, engine or roster readiness fails. |
| `:221-317` tests and invariants | **Superseded** by canonical inventory-subset, no-fallback, no-price, no-order-write and empty-state checks, plus runtime once-only submission and lifecycle checks. |

## New boundary contracts

These owners fill gaps found after the six-draft merge; they do not copy domain formulas:

| Canonical file | Sole responsibility |
| --- | --- |
| `catalog_api.t27` | Query/filter composition, bounded pagination, opaque cursors, DTO release and HTTP outcomes. It consumes abstract catalog, availability and privacy proofs. |
| `commerce.t27` | Deal discriminants, cart transitions, immutable quote snapshots, fulfillment gates, checkout and atomic idempotent replay. It consumes price and availability decisions and carries no customer data or price fixture. |
| `ride_runtime.t27` | Control bounds, collision/end classification, once-only score/award requests, generation guards and teardown. |
| `publication.t27` | Evidence required for repository discovery, compiler verification, spec-browser publication, the namespaced agent and a multi-repository Queen board. It explicitly makes no live-publication claim. |

## Ownership graph and remaining contracts

`bike_catalog -> availability`, `pricing_honesty -> availability`,
`deposit_tiers -> availability`, and `rental_terms -> pricing_honesty` were the four explicit
ownership metadata edges at the time of the merge. The pinned compiler does not yet provide a
sound cross-file import form, so the contracts exchange abstract inputs and do not pretend that
brace imports resolve. The graph has since grown to 210 edge mentions across 43 specs, every one
resolving to a declared `ID`; it is tabulated in [`t27-contract-map.md`](t27-contract-map.md)
rather than maintained here, because a four-edge list in a history document reads as the whole
graph and stopped being one.

The deferred FX/refund and divergence/logging rows above remain follow-ups because neither the
Drive evidence nor the published `.t27` corpus supplies a safe executable formula. They are not
smuggled into `commerce.t27`: that contract owns transaction sequencing and accepts authoritative
decisions as inputs.

## Compiler evidence

Run `T27C=/absolute/path/to/t27c python3 scripts/verify_t27_specs.py -v`. The manifest contained
all ten canonical contracts and the tracked owner-agent card when this was written; measured
2026-09-21 it contains 43 entries, and the gate's rules below are unchanged. Recursive discovery rejects an
unmanifested nested spec instead of silently skipping it. For every entry the gate enforces
ASCII, tracking (unless local `--allow-untracked` is explicit), unique non-empty module and ID,
no malformed use declaration, a per-file declaration floor, successful JSON typechecking with
zero errors or warnings, at least one test/invariant/bench, and non-empty clean output from
`gen`, `gen-c`, `gen-rust`, `gen-verilog`, and `gen-verilog-hir`.

This is a front-end and generator-emission gate. Current `t27c test` enumerates declarations;
it does not execute every assertion, and this repository does not compile the five emitted
target languages. Those are explicit compiler/publication follow-ups, not claims made here.
