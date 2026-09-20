# Orchestrator decisions

Decisions that span more than one subsystem, with the evidence that forced each one.
Recorded here because a worker touching one file cannot make them and must not guess.

Parent epic: #1

---

## D1 — Bike migrations start at 077, contiguous

`migration_numbers_are_sequential_and_unique` (`src/db/mod.rs:1021-1047`) asserts the
numeric prefixes form a **gap-free** run from 001. A reserved gap is therefore not an
option. Highest top-level migration is `076_promo_broadcast.sql`, so bikes take 077 onward.

`migrations/wip/077_quest_progress.sql` already claims 077, but it sits in a
subdirectory and `migration_files()` uses a non-recursive `read_dir`, so it is invisible
to both fitness tests and does not collide today. **It must be renumbered when it is
promoted**, not the bike migrations.

## D2 — Forward migrations only; never edit 001-076

`run_migrations()` backfills `_schema_migrations` for an established database
(`src/db/mod.rs:488-520`), so history is replayed only on fresh installs. Editing 001 or
008 in place would therefore change fresh installs only and leave any established
database holding the cannabis catalog for ever. Forward migrations are correct in both
worlds.

## D3 — Repoint the established-database probe away from `strains`

`src/db/mod.rs:495` reads:

```sql
SELECT to_regclass('public.strains') IS NOT NULL AS est
```

This is the highest-consequence single line in the change. If `strains` is dropped
while this line stands, the probe returns false on a populated production database, the
backfill branch is skipped, the runner concludes the database is FRESH, and it attempts
to apply 001-076 against live data.

Repoint to `public.orders` — created in `001_initial.sql:57`, and orders survive the
rebrand because a rental is still an order.

## D4 — Rename the crate

`woody-weed-bot` is the most visible remaining cannabis string: it is in the binary name.

| from | to |
| --- | --- |
| `woody-weed-bot` (package) | `turbobaby-bot` |
| `woody_weed_bot` (lib) | `turbobaby_bot` |
| `woody-weed-bot-server` (bin) | `turbobaby-bot-server` |

Touches `Cargo.toml`, the doctest at `src/db/macros.rs:14`, and the import root in
~40 `tests/*.rs` files. Mechanical, but atomic — it cannot be split across workers.

## D5 — The garden mechanic is removed, not repointed

`src/trios/garden.rs`, the six-catalog EXISTS gate at `src/db/orders.rs:379-386`, and
7 integration tests exist to plant a virtual seed when someone buys cannabis. A
motorbike rental has no botanical analogue, and the user's replacement game is the biker
ride game (#12-#15). Drop the tables in a forward migration, delete the Rust and its
tests. Migrations 004/026/036/037/041 stay on disk untouched per D2.

## D6 — `lab_certificates` becomes `bike_service_records`

This one has a real counterpart rather than a forced analogy. The fleet register tracks
oil and gear service, ABS and air filter; the ops sheet tracks `current_km`,
`last_service_km`, `interval_km`, `next_km` and an `overdue` status per unit.

**Admin-only.** Service state is not surfaced in the public catalog: two units currently
read `overdue`, and a public "serviced" badge we cannot keep accurate is exactly the kind
of number the data-honesty rule forbids.

## D7 — `fulfillment`, two l's

`OrderItem` at `src/db/orders.rs:502-525` already spells it `fulfillment`, pinned by
tests at 1667 and 1692. Matching the shipped spelling avoids a serde split. The spec's
`fulfilment` is overruled by the code.

## D8 — Cart rental lines

`migrations/059_cart_tables.sql:24` declares `UNIQUE (cart_id, kind, catalog_id)`, which
would stop a customer renting two bikes of the same family for different dates.

- `kind` = `bike_rental`
- `catalog_id` = the **family** key, not a unit — a customer books a model, the shop
  assigns the unit
- `quantity` = how many units of that family
- `rental_start` / `rental_end` on the line
- the constraint widens to `UNIQUE (cart_id, kind, catalog_id, rental_start, rental_end)`

### D8 amendment — two things the decision above missed

Recorded because D8 as first written would have shipped a defect.

**1. There is a second constraint, and it is unnamed.** `059_cart_tables.sql:16` declares
`kind TEXT NOT NULL CHECK (kind IN ('strain', 'set', 'accessory', 'tea'))` **inline**, so its
name is whatever Postgres generated. `bike_rental` violates it and every add-to-cart would fail
at the database with a `23514`. It must be dropped by looking the constraint up by the column
it constrains — a guessed name aborts the migration on any database ever patched by hand — and
the four cannabis kinds must stay in the replacement list, because `ADD CONSTRAINT` validates
existing rows and would abort on a live cart still holding one.

**2. Widening the UNIQUE constraint silently un-does what 059 was written to prevent.**
Postgres treats NULLs in a UNIQUE constraint as **distinct**, so once the dates join the key,
`(cart, 'accessory', id, NULL, NULL)` no longer conflicts with itself and every legacy kind can
be added to a cart twice. The widened constraint therefore needs a companion partial unique
index on `(cart_id, kind, catalog_id) WHERE rental_start IS NULL AND rental_end IS NULL`.
`UNIQUE NULLS NOT DISTINCT` expresses this in one clause but requires Postgres 15 and nothing
in this repository pins the server version, so the portable form is used.

Both are implemented in `migrations/081_cart_rental_lines.sql`.

## D9 — Money fields are nullable, and absent stays absent

Three separate constructs in this tree turn an unknown number into a confident zero:

| construct | location | what it does |
| --- | --- | --- |
| the `clamp` closure | `src/db/strains.rs:123-129, 165-171` | NaN/Inf becomes `0.0` — a price of 0 reads as FREE |
| `NOT NULL DEFAULT 0` | `migrations/008_strains_full_seed.sql:21` | an unpriced row is priced at zero |
| `try_get_warn!` | `src/db/macros.rs:28-44` | a renamed column yields the default and only a `tracing::warn` |

`rate_day_thb`, `deposit_thb` and `monthly_low_season_thb` are therefore **NULLABLE**,
mapped as `Option<f64>` filtered with `.is_finite()`, and routed through **none** of the
three constructs above. Absent renders as a dash — never 0, never an average, never a
"from" price.

`try_get_warn!` is the single most dangerous construct during this rename: it is
fail-open by design, so a half-migrated column renders as `0` / `false` / `""` with a log
line as the only evidence. Grep every call site before renaming any column it reads.

### A fourth construct, found while widening the cart

`059_cart_tables.sql:19` declares `unit_price DOUBLE PRECISION NOT NULL CHECK (unit_price >= 0)`.
A cart line **cannot** hold an absent price: the column rejects NULL, and the only value that
satisfies the constraint without inventing a number is `0`, which renders as free.

The resolution is not a schema change. A family with no published rate is **not addable to a
cart** — the call refuses, and the catalog says a human quotes this price (D11). That is the
honest behaviour anyway: a machine whose price nobody has set is a machine we cannot yet take
money for. CLICK 125 is the live instance, and it is already closed to new rentals by D12.

What this forbids is the tempting shortcut of inserting `0.0` to get past the constraint and
"fixing up the display later". The zero would then be a real row in a real cart.

## D10 — `bikes` and `bike_units` join `CRITICAL_COLUMNS`

`CRITICAL_COLUMNS` (`src/db/mod.rs:340-353`) currently guards only `accessory_sets`,
`tea_sets` and `sets`. Without an entry, a bike table missing a column produces no
startup warning at all and the first symptom is a `try_get_warn!` default served to a
customer.

## D11 — Price authority: the door, never the file

The owner's ruling of 2026-09-12. Full text and the arithmetic that reconciles the three
competing price sets is in [`data/fleet_seed.json`](data/fleet_seed.json).

- The client-facing price is the number the **door** (the owner's live sheet) returns. It
  is never computed from a file when the door can be asked.
- **If the door is silent the bot must not compute.** It says a human quotes this price
  and emits no number at all — not exact, not "from", not an average, not a range.
  Invention and silence are forbidden equally.
- Every priced answer logs any divergence of >= 1 baht between door and file, and the
  logging never blocks or delays the answer.
- One measured door call took 21.4 s, so the timeout path is the common path, not the
  edge case.

The published tariff in the seed is **pre**-class-discount (scooters -25%, motorcycles
-15%). Rendering it without applying the discount overstates every scooter by 33%.

## D12 — CLICK 125 is not offered

Owner, 2026-09-12: not rented for now. `KB_faq` says the same independently and redirects
the request to PCX 150 / ADV 150 / NMAX 155. One unit is still out on a contract that
predates the decision; the family is closed to **new** rentals and that existing rental
is not cancelled.

## D13 — Two locales: ru, en. No Thai

`KB_faq`: clients are handled only by Russian-speaking managers; the Thai team does not
deal with clients. Russian is primary.

## D14 — What must never enter this repository

The internal sources carry, and the public repo must never contain in any form:

- renter names, Telegram handles, phone numbers
- outstanding debts
- physical key codes
- TAX and insurance dates
- per-unit purchase cost, and any sale price derived from it
- plate numbers
- the free-text personal notes in the rental-history sheet

Only aggregate, de-identified signal is used: published tariffs, deposit tiers, term
patterns, unit counts, model years, colours, and the scooter/motorcycle class split.

## D15 — One implementation of the price arithmetic, and it is shared

Found by compiling, not by reading: `cargo check --features backend` reports
`unused import: bikes::*` and then 14 more never-used items from `src/db/bikes.rs`. The
694-line typed data-access layer for the bike domain is reached by **nothing**.
`src/api/bikes.rs` — the code that actually answers customers — issues its own raw
`Statement`s and carries its own `publishable_money` / `publishable_fraction`.

Both are correct. That is precisely the problem: D9 and D11 are now asserted in three
separate places, each with its own tests and its own chance to drift.

| copy | location | what it holds |
| --- | --- | --- |
| server, typed | `src/db/bikes.rs` | `round_half_up_baht`, `apply_class_discount`, `usable_discount`, `discount_for_class` — all unreachable |
| server, HTTP | `src/api/bikes.rs` | `publishable_money`, `publishable_fraction`; deliberately computes **no** client rate (D11) |
| client, WASM | `src/ui/screens/catalog_screen.rs` | `discount_fraction` plus its own half-up client rate |

The rule, and it binds every worker touching a price:

- The arithmetic — class discount, term discount, half-up rounding to the baht — lives
  **once**, in `src/trios/pricing.rs`. That module is already the shared, dependency-free
  home both the Axum server and the Dioxus/WASM client compile against; `src/db/bikes.rs`
  cannot be it, because it pulls in `sea_orm` and the UI cannot link that.
- The **honesty filters** (absent stays absent; NaN, infinity and negatives become absent,
  never `0.0`) live there too, as one pair of functions, not three.
- A `.t27` spec pins the arithmetic, so the two language runtimes are checked against one
  written contract rather than against each other.

Why this is worth a decision rather than a cleanup ticket: the recurring defect in this
kind of tree is the hand-copied computation. Three copies of a *price* is the worst place
to have it — D11 makes price provenance the most sensitive rule in the repository, and a
drift between the number the API serves and the number the catalog screen renders is
invisible to every test that only ever exercises one of them.

## D16 — A gate whose input can reach zero must pin a floor

`src/api/mod.rs::route_wiring_tests::every_routes_fn_is_declared_and_merged` was added on
**2026-06-02** to catch "added a routes file but forgot to wire it". It finds its subjects
by matching the source text `pub fn routes(`.

On **2026-06-06**, `baf77cc` ("refactor(api): tighten 59 pub items to pub(crate)") rewrote
every one of those declarations to `pub(crate) fn routes(`. The needle matched nothing from
that day on. `modules_with_pub_fn_routes()` returned an empty vector, both assertions ran
against empty vectors, and the test passed — for three months, while checking nothing.
Measured today: **0 of 19** route modules were visible to it.

The gate had been made blind by exactly the bug class it existed to catch, and nothing
reported it, because a passing test and a vacuous test look identical from the outside.

Two fixes, both landed:

1. The recogniser accepts any visibility on the declaration.
2. A companion test, `routes_fns_are_found`, asserts the subject list holds at least 10
   modules. The floor is well below the real 19 so that deleting a module is not a failure;
   only *losing the ability to see modules* is.

The general rule for this repository: **every source-walking gate must assert that it found
something.** `orphan_table_tests` and `entity_wiring_tests` already do (`assert!(!
tables.is_empty())`, `assert!(!entities.is_empty())`) — this one did not, and it is the one
that broke. A count is not a decision, but a count of zero is always a bug.

---

## D17 — Where an issue and the seed disagree, the seed wins, and the disagreement is recorded

The six spec issues (#16–#21) were written before `data/fleet_seed.json` was reconciled.
Three of them state a premise the seed refutes. Writing the spec the issue asked for would
have published a false claim in a file whose whole purpose is to be citable, so in each
case the spec was written against the measurement and the issue's figure was recorded
inside the spec's `WHY` paragraph rather than quietly dropped.

**#18 asked for a function that cannot exist.** It specifies
`deposit_for(engine_cc, class)` and tiers of "3,000 / 5,000 / 10,000–20,000". Measured:

| family | class | `displacement_cc` | `deposit_thb` |
| --- | --- | --- | --- |
| `xmax-300` | scooter | 300 | 5000 |
| `xmax-300-new` | scooter | 300 | **7000** |

Two families agreeing on both arguments and disagreeing on the result. A function of
`(class, displacement_cc)` cannot return two values, so the signature the issue asks for
is not implementable against this fleet — not difficult, *impossible*. The real distinct
deposits are 3,000 / 5,000 / 7,000 / 15,000 / 20,000 / 25,000; **10,000 never appears.**
The deposit is therefore modelled as a per-family published attribute with a closed set of
legal tier values, and the totality invariant runs over the family-key domain — every
offered family maps to exactly one tier — not over a displacement band that provably does
not exist. Also, the field is `displacement_cc`; `engine_cc` appears nowhere in the seed.

**#21's count is off by four.** It says "five of thirteen families have no measured rate".
Exactly **one** of fourteen in-stock families lacks a rate — `click-125`, whose
`base_rate_thb_day` is null and whose `offered` is `false`, so it is not bookable either.
The seed's own `totals.families_without_published_rate` is `1`. The larger and more
interesting absence is the **mirror** defect the issue did not mention: **seven**
price-list-only families carry a published rate and **zero** stock. Both failure modes are
real and they point opposite ways — stock without a rate (1), a rate without stock (7) —
and the spec that exists to forbid "an absent measurement rendered as a confident number"
is the wrong place to carry an unreproducible number of its own.

**#17's bands are not disjoint.** The published term discounts are ranges, not multipliers:
week `[0.06, 0.15]`, two weeks `[0.15, 0.25]`, month `[0.35, 0.5]`. Consecutive bands
**touch at 0.15**, so "a longer term carries a strictly larger discount" is false exactly
at that edge. Monotonicity is stated on a well-defined representative of each band instead,
and the touching edge is named in the header so a later reader does not file it as a bug in
the tariff. The term ladder itself checks out: `observed_terms_days` is
`[7, 30, 90, 120, 150, 180]`, which is the issue's "7 days, 1, 3, 4, 5, 6 months".

The rule: **an issue is a brief, not a measurement.** A spec may not inherit a number from
the prose that commissioned it. Where they differ the spec cites the seed, states the
issue's figure, and says which one was reproducible — because the alternative is a
published number whose only provenance is that someone typed it into a ticket, which is
the defect [D9](#d9) and [D11](#d11) exist to forbid, arriving through the front door.

## D18 — The market is a declared profile, not ambient Thailand

The owner's standing instruction (2026-09-13) is that this agent runs on **any market,
country and currency**. Measured before this decision, the deployment's market was ambient
in the code rather than declared anywhere: the money formatter hardcoded the baht glyph,
the comma group separator and whole-baht display (`format_baht`), the i18n templates baked
the glyph into customer-facing sentences, the shop timezone was a hardcoded +7 in five
files (measured 2026-09-13: `api/happy_hour.rs`, `api/share.rs`, `promo.rs`, `api/orders.rs`,
`ui/screens/events_screen.rs`), and the checkout phone default was +66. No file stated a
market; several stated facts of one. Under that shape, a second market could only arrive
as a second fork of the formatter — exactly the duplication [D15](#d15) removed for price
arithmetic.

A market is therefore a **profile**: thirteen named fields (`country_code` through
`default_calling_code`), owned as follows —

- the **contract** (field set, bounds, refusals) is `specs/turbobaby/market_profile.t27`
  (`turbobaby/market`);
- the **deployment instance** is the `market` block in `data/fleet_seed.json`, and
  `scripts/verify_fleet_seed.py` fails if the block disagrees with the spec's `TH_*`
  consts, carries a field outside the contract, or violates a bound;
- the **formatter instance** is `MarketMoneyFormat` / `THB_MARKET` in
  `src/trios/pricing.rs`; `format_baht` is its named shortcut so no call site names a
  currency.

Three copies is one more than [D15](#d15) would like, and each copy is pinned to the
others: the Rust tests pin the formatter to the THB profile, the seed verifier pins the
block to the spec, and the spec's own tests run every rule over a **second, proof profile**
(EUR — suffix symbol, two minor digits, swapped separators, DST-true) that exists solely so
a contract shaped like one currency cannot pass as a contract for all of them. No shop
exists at the proof profile; every value in it is a public ISO/IANA fact.

Two refusals ride with the profile. A market may *display* fewer minor digits than its
ISO exponent (Thailand: satang exist, shop prices are whole baht) but never more —
invented precision is a lie in the other direction. And no exchange rate enters this
repository without a source ([D11](#d11)): the deposit's foreign-currency equivalents are
agreed by a human at the door, so the spec's rate table is empty and its length is pinned.
What remains hardcoded (the glyph inside i18n templates, the +7 literals in five files, the
+66 default) is unwired debt tracked in #35, not a second market's problem: the profile it
must read now exists.

## D19 — The Woody WeedPecker heritage is hidden, not deleted

Owner mandate, 2026-09-14: «из WOODY идут события рассылки, а надо чтобы у каждого
своя!! сейчас все путается!», «раздели и почини всё», «замени все названия woody наша
turbobaby». This database forked from the woody bot carrying its live catalogue, and
two shops ran through one bot: 30 Woody WeedPecker events in the calendar (DJ sets,
cannabis sommelier nights) with the promo sweep drafting posts about them and the
24-hour reminder loop mailing customers; 70 accessories, 30 teas and 8 sets on sale;
the menu button and share links pointing at the other bot (`WEB_APP_URL` unset fell
back to the woody production URL; `BOT_USERNAME` defaulted to `Woody_WeedPecker_bot`).

Migration **085** flips visibility flags — `events.is_public = FALSE`,
`*.is_available = FALSE` — and rebrands the pickup zone. No row is deleted and no
table is dropped: old orders and bookings still resolve their item names, and the
separation is reversible by flipping the flags back. The screens and endpoints stay
so a future TurboBaby event (a ride day, a community meet) starts from a clean
public slate rather than from a code resurrection.

What this decision does *not* settle: the fate of the legacy screens (`/sets`,
`/tea`, `/sommelier`, `/accessories`, `/garden`, the games) and the Phangan delivery
zones (Thong Sala, Haad Rin, …) in a shop that README places in Kamala, Phuket.
Those are product calls; the data waits, hidden, until the owner makes them.

The string rebrand that rides with it (`Woody Weed` → `TurboBaby` in payment QR
text, pickup names, share/referral texts, profile contacts, i18n) is cosmetic and
total: no customer-visible surface keeps the old shop's name. Internal keys keep
their names — `woody_last_*` localStorage entries hold customers' saved checkout
drafts, and renaming the key would silently discard their data, which is a worse
bug than an invisible legacy word.

## D20 — The logo is the owner's own channel avatar

Owner mandate, 2026-09-14: «ты логотип найди и замени на реальные данные» (with the
«Актуальная Система Учета» Drive folder as the pointer). The folder holds no logo
file — it is sheets, agreements and passports — and the Wix site turbophuket.com has
a text-only header (its sole uploaded media is the og:image hero photo). The one
brand image the owner actually publishes is the avatar of his manager channel
t.me/turbophuket («TURBOBABY manager аренда мото байки»), fetched at its full
320×320 and installed as `assets/logo.jpg` (the bot itself has no avatar set).

The cannabis-era trust block on the home screen (GACP certification, medical-use
warning, 20+ badge) was retargeted to verifiable rental facts: legal entity and
location, Thai helmet law, license requirement. No invented product claims
(insurance, deposit terms) — those stay the owner's to make. The cannabis shop
address in checkout (Koh Phangan pickup) became TurboBaby / Kamala, matching README
and the migration 085 zone rename.
