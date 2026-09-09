# specs/functions — Inngest functions of 999-multibots-telegraf as first-class `.t27` specs

> **Where this lives.** This directory in `gHashTag/t27` is the canonical home of these
> specs — edit them here. `gHashTag/trinity` keeps a vendored copy under
> `apps/website/public/t27/files/specs/functions/` and its build reads that copy through the
> vendored compiler wasm (`t27_compiler.wasm`). The wasm's `typecheck.ok` is necessary,
> not sufficient: it stays `true` for a wrong annotation such as `str = 5`, so the site's
> generator (`scripts/agents-from-specs.mjs`) also checks the field schema below. The
> bootstrap compiler on `master` was not run against these files in the commit that
> added them; all 28 were compiled with the vendored wasm (sha256 `4d9c0447b5ca2887...`),
> typecheck ok, nothing discarded.

One file per Inngest function the bot `999-multibots-telegraf` registers (28 at `main
@a9c08b4`). The `.t27` file is the source of truth for the function card on t27.ai
(`#/functions?function=<ID>`); `public/functions/spec-functions.json` is generated from it by
the real compiler. The code witness is a vendored copy of the functions manifest
(`public/functions/manifest.json`, the same 28 entries), extracted from the source tree — a
card with a spec and a manifest entry is labelled `spec+code`, a spec without one `spec-only`,
a manifest entry without a spec `code-only`.

File name: `<ID>.t27` (the canonical id, e.g. `neuro-image-generate.t27`); module name:
`fn_<ID with underscores>` (`fn_neuro_image_generate`).

## The ladder

```
Specs  ->  Skills  ->  Crons  ->  Agents  ->  Functions
specs/**   specs/skills specs/crons specs/agents specs/functions
                       what starts              what one Inngest run does, step by
                       a run and when           step, and what it touches outside
```

A cron-triggered function (`TRIGGER = "cron"`) is also a scheduled job, so five of them are
stated twice: as a cron card in `specs/crons` (`inngest/999-multibots-telegraf/<LEGACY_ID>`)
and as a function card here. The site joins the two by `REPO` + `LEGACY_ID` = the cron's
`NAME`; nothing is inferred from a domain or a file name.

## Schema (every constant is `pub const`)

| constant        | type     | meaning                                                                                                    |
|-----------------|----------|------------------------------------------------------------------------------------------------------------|
| `KIND`          | `str`    | always `"function"`                                                                                        |
| `ID`            | `str`    | canonical id (`<domain>-<object>-<verb>`), equals the file name; must equal `id` in the manifest           |
| `LEGACY_ID`     | `str`    | the id the deployed code still registers (`legacy_id` in the manifest)                                     |
| `NAME`          | `str`    | display name                                                                                               |
| `REPO`          | `str`    | `999-multibots-telegraf`                                                                                   |
| `SERVICE`       | `str`    | `file:line` of `inngest.createFunction(` in that repo                                                      |
| `DOMAIN`        | `str`    | `neuro` \| `reels` \| `training` \| `morph` \| `render` \| `payment` \| `broadcast` \| `instagram` \| `content` \| `monitoring` \| `analytics` \| `webhook` \| `welcome` |
| `TRIGGER`       | `str`    | `event` \| `cron`                                                                                          |
| `EVENT`         | `str`    | canonical event name; `""` for a cron function                                                             |
| `LEGACY_EVENTS` | `[N]str` | event names the code still listens to (multi-trigger); `[0]str = []` for a cron function                   |
| `CRON`          | `str`    | five-field cron expression; `""` for an event function                                                     |
| `TZ`            | `str`    | time zone of `CRON` (`UTC`); carried for event functions too                                               |
| `SUMMARY_EN`    | `str`    | what one run does (English)                                                                                |
| `STEPS`         | `[N]str` | `step.run` names in source order; `${...}` in a name is a template the code expands per item               |
| `RETRIES`       | `u8`     | `retries` declared on the function; when none is declared, `4` (Inngest JS SDK v3 default) and `NOTE` says so |
| `ON_FAILURE`    | `str`    | `admin-telegram` (an `onFailure` handler messages the admin chat) \| `log` (no handler) \| `refund+notify`  |
| `SIDE_EFFECTS`  | `[N]str` | from `charges-balance`, `paid-api`, `messages-user`, `messages-owners`, `messages-admin`, `db-write`, `external-webhook`, `none` |
| `GUARD`         | `str`    | first step that stops a bad payload (`zod-schema`, `check-user`, `validate-input`, `amount-match`, …); `none` when the first step already acts; `unknown` when the function could not be probed |
| `SAFE_PROBE`    | `str`    | JSON payload sent in the 2026-09-09 safe probe; `""` when none was sent                                    |
| `PROBE_RESULT`  | `str`    | `COMPLETED` \| `FAILED-at-guard` \| `skipped` (no probe sent) \| `not-deployed` (function absent from the probed build) |
| `CONTROL`       | `str`    | `spec+code` \| `spec-only` \| `code-only` — what the author expects the site to find                      |
| `NOTE`          | `str`    | anything a reader must know that the fields above cannot say                                               |

The generator fails the build when: the compiler verdict is not clean; a constant is
missing, not `pub`, or has the wrong annotation / array length / integer range; `KIND` is not
`"function"`; `ID` does not equal the file name; the module name is not `fn_<ID>`; `TRIGGER`,
`ON_FAILURE`, `PROBE_RESULT` or `CONTROL` is outside its vocabulary; a `SIDE_EFFECTS` value is
outside the list; an event function has `CRON` or no `EVENT`; a cron function has `EVENT`,
`LEGACY_EVENTS` or no `CRON`; or `SAFE_PROBE` is neither `""` nor JSON. A spec whose
`TRIGGER`, `EVENT`, `CRON`, `RETRIES`, `ON_FAILURE`, `STEPS` or `SIDE_EFFECTS` differ from the
manifest entry with the same `ID` is not a build failure: the difference is written on the
card as a message, and the card's health drops to `warn`.

## What was read from where (honesty)

* Source: `999-multibots-telegraf` `main @a9c08b4`. The manifest was extracted from that tree;
  where it carries no `file`, no `steps` or `retries: null` (three functions: `training-model-v2-start`,
  `payment-ai-server-process`, `broadcast-message-send`, and eight functions with undeclared
  `retries`), the spec reads the same checkout directly and says so in `NOTE`.
* `payment-ai-server-process`: the code declares `onFailure: createInngestFailureHandler(...)`,
  which logs and messages the admin chat; the manifest says `log`. The spec says
  `admin-telegram` and keeps the disagreement in `NOTE`; the site shows it as a message.
* `RETRIES = 4` for undeclared retries is the SDK default, not a declaration. The 2026-09-09
  probe saw such functions reach attempt 5, which is consistent with four retries.
* Four functions are **not on the production Railway build** as of 2026-09-09
  (`training-model-complete`, `training-stuck-check`, `webhook-generation-validate`,
  `welcome-avatar-generate`): the deployed app registers 24 base functions, `main` registers
  28. Their `PROBE_RESULT` is `not-deployed`, `GUARD` is `unknown`, and `NOTE` says so. The
  site reads the `deployed_2026_09_09` flag from the manifest and shows it on the card.
* Unregistered code in the tree (`test-simple`, `test-simple-message`, `test-advanced-loop`,
  `kie-ai-webhook-manual-check`, `voice-training-*`, `webhook-health-check`,
  `periodic-webhook-health-check`, the duplicate `morphImages.ts`) has no spec: nothing is
  registered silently.
* Live run counts are not in the spec and not in the manifest. The site polls a read-only
  status endpoint of the bot; when it is unreachable the card says "status source offline",
  and an unknown state is labelled unknown.

## Language

Specs are English-only (t27 LANG-EN; `bootstrap/build.rs` fails the build on Cyrillic) and
ASCII-only. Russian `NAME` / `SUMMARY` travel through the contract
`specs/i18n/agents-ru.t27`, whose `SCOPE` names `specs/functions`; the bundle lives in
`gHashTag/trinity` at `apps/website/i18n/agents.ru.json`, keyed by `ID`.

## Editing

Edit in `gHashTag/t27` (`specs/functions/<ID>.t27`), re-vendor the byte-identical copy into
`gHashTag/trinity` `apps/website/public/t27/files/specs/functions/`, then run
`node scripts/agents-from-specs.mjs` and `npm run check:agents` in `apps/website`. When the
code changes (a rename, a new step, a different `retries`), update the manifest copy and the
spec in the same change; the card shows any distance between the two.
