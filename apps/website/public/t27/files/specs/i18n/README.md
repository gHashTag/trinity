# specs/i18n -- translation contracts for the agent specs

> **Where this lives.** This directory is canonical in gHashTag/t27; gHashTag/trinity
> vendors a byte-identical copy at `apps/website/public/t27/files/specs/i18n/` and the
> bundle files the contracts point to live in trinity only.

Specs are English-only (t27 `LANG-EN`: `bootstrap/build.rs` fails the build on any
Cyrillic under `specs/`). A translation is therefore never inside a `.t27`. It is
**connected through** a `.t27`: one module per locale under this directory declares
the contract, and a bundle file outside the spec corpus carries the text.

| File | Module | Locale | Bundle |
| --- | --- | --- | --- |
| `agents-ru.t27` | `i18n_agents_ru` | `ru` | `trinity:apps/website/i18n/agents.ru.json` |

Add a locale by copying `agents-ru.t27` to `agents-<locale>.t27`, renaming the module
to `i18n_agents_<locale>` and changing `LOCALE` and `BUNDLE_PATH`. Nothing else knows
the locale list: the site's generator (`apps/website/scripts/agents-from-specs.mjs`
in gHashTag/trinity) discovers every `specs/i18n/*.t27`, so `de`, `es`, `zh` (locales
the site already speaks) are one file each.

## Schema

Every constant is required and `pub`.

| Constant | Type | Meaning |
| --- | --- | --- |
| `KIND` | `str` | Always `"i18n"`. |
| `LOCALE` | `str` | The locale this bundle provides (BCP-47-shaped, e.g. `ru`). |
| `SOURCE_LOCALE` | `str` | Always `"en"`: the specs are the English source. |
| `SCOPE` | `[N]str` | Spec directories whose modules may be translated, e.g. `["specs/skills", "specs/crons"]`. An entry `ID` must resolve to a spec in one of them. |
| `FIELDS` | `[N]str` | Spec fields a bundle entry may carry. `SUMMARY` maps to the spec's `SUMMARY_EN`, `NAME` to `NAME`. Any other key in a bundle entry is a build failure. |
| `BUNDLE_REPO` | `str` | Repository that holds the bundle (`"trinity"`). Only a bundle in the building repository is loaded. |
| `BUNDLE_PATH` | `str` | Repo-relative path of the bundle. |
| `BUNDLE_FORMAT` | `str` | `"json"`. |
| `KEY` | `str` | `"ID"`: bundle entries are keyed by the spec's `ID` constant. |
| `FALLBACK` | `str` | `"en"`: what the site shows for a spec (or a field) with no translation. |
| `COVERAGE_REQUIRED` | `bool` | `true`: every spec in `SCOPE` must have an entry, or the build fails. `false`: missing entries are reported as coverage `n/total`, not failed. |
| `ORPHANS_ALLOWED` | `bool` | `false`: an entry whose `ID` matches no spec in `SCOPE` fails the build. |
| `ENABLED` | `bool` | `false` lists the contract but loads nothing. |

## Bundle shape

```json
{
  "$spec": "specs/i18n/agents-ru.t27",
  "locale": "ru",
  "entries": {
    "<ID>": { "SUMMARY": "...", "NAME": "..." }
  }
}
```

`$spec` must name the contract, `locale` must equal its `LOCALE`, and every key of an
entry must be in `FIELDS`. An entry may carry a subset of `FIELDS`; the rest fall
back to English.

## What the site emits

`public/skills/spec-skills.json` and `public/crons/spec-crons.json` carry, per entry,
`summary: {en, <locale>...}` and `name: {en, <locale>...}`, and per catalog
`i18n: [{locale, spec, sha256, bundle, enabled, fields, scope, coverage: {n, total}, missing}]`.
The Skill and Cron Explorers read the current locale from `summary`/`name` and the
SPEC panel prints `translations: ru via specs/i18n/agents-ru.t27 (n/total)`.
`npm run check:agents` (`qa/agents-spec-contract.mjs`) checks the contract: the
bundle exists at the declared path, names its contract, matches the locale, has no
orphan entry and no key outside `FIELDS`; coverage is printed.

Validity: the file must pass `typecheck.ok === true` with empty `discarded` /
`lexerDiscarded` / `swallowed` under the vendored wasm compiler, like every other
spec here.
