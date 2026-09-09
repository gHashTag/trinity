# Agent control API (optional control plane for skills and crons)

Status: **contract only — no server implements this today.** The Skill and Cron
Explorers on t27.ai read their catalogs from `.t27` specs
(`public/t27/files/specs/{skills,crons}/*.t27` → `scripts/agents-from-specs.mjs`
→ `public/skills/spec-skills.json`, `public/crons/spec-crons.json`). The
management strip on each card works without any server: `ENABLED` is read from
the spec and changed by editing the spec (GitHub edit link), and "run now"
points at the host that actually owns the job (GitHub Actions workflow page,
Railway service, Inngest dashboard). A timer inside a process has no outside
handle and the strip says so.

When `VITE_AGENT_CONTROL_URL` is set at build time, the strip additionally gets
live buttons that call the endpoints below. When it is unset the strip shows
"Контур управления не подключён — действия идут через спеку и панели хостов" /
"No control plane connected — actions go through the spec and the hosts' panels".

## Endpoints

All requests are `POST`, body `application/json`:

```json
{ "id": "<catalog id>", "requestedAt": "<ISO-8601 timestamp>" }
```

| Endpoint                                  | Meaning                                                        |
|-------------------------------------------|----------------------------------------------------------------|
| `POST {url}/crons/<id>/run`               | Start the job now (`<id>` e.g. `github-actions/trinity/site-live-gate`) |
| `POST {url}/crons/<id>/enable`            | Ask the plane to set the job's `ENABLED` to `true`             |
| `POST {url}/crons/<id>/disable`           | Ask the plane to set the job's `ENABLED` to `false`            |
| `POST {url}/skills/<id>/run`              | Launch the skill once (`<id>` e.g. `trinity/doctor`)           |

`<id>` is the catalog id with each `/`-separated segment URL-encoded; the
segments themselves are kept as path segments.

## Responses

- `202 Accepted` — the request was queued; body may carry `{ "runId": "..." }`.
- `200 OK` — for `enable`/`disable`, the new state was recorded.
- `404 Not Found` — the id names no known skill or job.
- `409 Conflict` — the job is a timer or otherwise has no outside handle.
- `501 Not Implemented` — the plane knows the id but cannot act on that host.

Any non-2xx is shown verbatim (status and body) in the strip; nothing is
retried and nothing is reported as done that the server did not confirm.

## Honesty rules the client keeps

- `enable`/`disable` never edit the spec themselves; the spec remains the
  source of truth and a plane that flips state must land the change as a
  commit to `specs/crons/<slug>.t27`, or the site will keep showing the spec's
  value.
- No credentials are sent by the browser (`credentials: 'omit'`); a plane that
  needs auth must sit behind its own gateway.
- The URL is public (it is in the bundle); it must not embed a token.
