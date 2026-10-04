# specs/providers -- who sells compute, and what a person could rent out for $TRI

> **Where this lives.** This directory in `gHashTag/t27` is the canonical home of these
> specs; edit them here. `gHashTag/trinity` keeps a byte-identical copy under
> `apps/website/public/t27/files/specs/providers/`, and its generator
> (`scripts/agents-from-specs.mjs`) compiles that copy with the vendored compiler wasm and
> checks every card against the schema in `catalog.t27`. Not to be confused with
> `specs/provider/` (singular), which holds the LLM adapter message types.

Layer 7 of the spec ladder:

```
Specs -> Skills -> Crons -> Agents -> Tools -> Functions -> Providers
                                                            specs/providers
                                                            who sells compute, at what
                                                            price, checked how, paid in what
```

Two families of card:

* `gonka/<slug>.t27`, FAMILY `model`: one card per model the Gonka chain lists in
  `models_all`. Every number is copied from a public chain endpoint on `CHECKED`; the
  site re-reads the chain in the browser and prints any distance between card and chain.
* `trinet/<slug>.t27`, FAMILY `host-class`: one card per class of hardware a person
  could rent out to our own network (TRI-NET) for $TRI. A card whose `WITNESS` is
  `bench-measured` names the record that measured it; a `design-only` card has
  `MEASURED = []` and says what is missing in `GAPS`.

`tri_gnk_pair.t27` is the study behind the cards: how Gonka pays its hosts, the routes a
$TRI/GNK pair could take, and where our network differs. Its `test` blocks check the
arithmetic it states.

## Schema and rules

**`catalog.t27` is the schema.** The field lists (`COMMON_FIELDS`, `MODEL_FIELDS`,
`HOST_FIELDS`), the vocabularies (`STATUSES`, `WITNESSES`, `CALLS`), the rule that says
where each model field is copied from (`FIELD_SOURCE_RULE`) and the module-name rule
(`ID_RULE`) are stated there once; this file does not repeat them.

## Calling a model

Every Gonka model card has `CALL = "needs-key"`: the endpoint answers OpenAI-compatible
requests, but each request is paid and signed by a funded Gonka account. The site shows how
to call it and never calls it; it never asks for, stores or forwards a key.

## Language

English-only and ASCII-only (t27 LANG-EN, L3). Russian names travel through
`specs/i18n/agents-ru.t27` once its `SCOPE` names `specs/providers`.

## Editing

Edit here, re-vendor the byte-identical copy into `gHashTag/trinity`, then run
`node scripts/agents-from-specs.mjs` and `npm run check:agents` in `apps/website`. When the
chain changes (a new model, a removed one, a different host count), change the card in the
same commit as its `CHECKED` date.
