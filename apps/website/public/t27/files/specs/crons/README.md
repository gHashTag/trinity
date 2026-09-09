# specs/crons — scheduled jobs as first-class `.t27` specs

One file per scheduled job the site publishes (`apps/website/public/crons/manifest.json`):
GitHub Actions schedules, Inngest functions, Railway cron services and in-process
`setInterval` timers. The `.t27` file is the source of truth for the job card on
t27.ai; `public/crons/spec-crons.json` is generated from it by the real compiler.

File name: `<repo>-<job slug>.t27`; module name: `cron_<file name with underscores>`.

## Schema (every constant is `pub const`)

| constant        | type     | meaning                                                                                   |
|-----------------|----------|-------------------------------------------------------------------------------------------|
| `KIND`          | `str`    | always `"cron"`                                                                           |
| `ID`            | `str`    | `<host>/<repo>/<slug>`; must equal the id in the code manifest                            |
| `NAME`          | `str`    | display name                                                                              |
| `HOST`          | `str`    | `github-actions` \| `inngest` \| `railway-cron` \| `timer`                                |
| `REPO`          | `str`    | short repo name                                                                           |
| `SERVICE`       | `str`    | workflow file / Inngest function file / Railway service / `file:line` of the timer         |
| `SUMMARY_EN`    | `str`    | what the job does, English                                                                |
| `SUMMARY_RU`    | `str`    | the same, Russian                                                                         |
| `SCHEDULE`      | `str`    | cron expression (absent for timers; `""` when only a dashboard holds it, see `SCHEDULE_NOTE`) |
| `INTERVAL_MS`   | `u32`    | period of an in-process timer (timers only, instead of `SCHEDULE`)                        |
| `TZ`            | `str`    | timezone of the schedule                                                                  |
| `RUNS`          | `[N]str` | skill IDs this job launches — **the control link**; only when the source evidently invokes one |
| `RUNS_NOTE`     | `str`    | why `RUNS` is what it is (e.g. `"no skill invocation found in source"`)                    |
| `ENABLED`       | `bool`   | whether the job is meant to fire                                                           |
| `NOTE`          | `str`    | optional caveat carried from the code catalog                                             |
| `ON_FAILURE`    | `str`    | `issue` \| `log` \| `unknown`                                                             |
| `CONTROL`       | `str`    | `github-actions-dispatch` \| `railway-dashboard` \| `inngest-dashboard` \| `code-only`     |

## Rules the generator enforces

- duplicate `ID` → build fails;
- a `RUNS` entry that names no skill spec → the job is marked `health: "fail"`;
- an `ID` absent from the code manifest → `witness: "spec-only"` (warn);
- every file must pass `typecheck.ok === true` with nothing discarded by the compiler.

As of the first commit every `RUNS` is empty: none of the 33 jobs was found to
invoke a Claude Code skill by name (checked in the workflow files and the code
catalog annotations). The link exists so that the day a job does, the spec says so.
