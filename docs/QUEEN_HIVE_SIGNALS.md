# QUEEN visual signal protocol — 2026-09-07

Issue #890. This extends the status-fill contract, without rewriting its evidence.
Scope: local hive UI, not deployment, worker capacity or invented telemetry.

## Signal grammar (contract before code)

Permanent fill answers **what state is the task in?** A temporary inner ring
answers **what just happened?** Honey outer rim/lift answers **what am I pointing
at?** A separate link-health badge answers **can I trust this as current?**
The channels never overwrite one another. Text/symbols repeat every color.

| Signal | Color / shape | Real source | Operator decision |
|---|---|---|---|
| Initial/open/backlog | red · circle | board lifecycle | pick work |
| Blocked/error/refused | bright red · ! / stronger fill | board lifecycle | resolve obstacle |
| Running | neon cyan · → | board running column only | inspect execution |
| Queen review | violet · ◇ | board review column | inspect review |
| Paused/dropped/cancelled | slate · pause bars | board lifecycle | resume or leave parked |
| Closed, T27 unknown | red · ? | terminal lifecycle without proof | request coverage proof |
| Honey | gold · check | terminal + T27 proof | inspect provenance |
| Dispatch/progress/tool/usage | cyan event marker | exact issue event | inspect activity |
| Result/finished | white event marker | exact issue event | inspect artifact, not assume acceptance |
| Approved review | green event marker | review accepted/approved/pass state | inspect verdict, not assume T27 |
| Waiting review | violet event marker | review wait/unknown state | inspect queue |
| Failure/refusal | bright red event marker | error kind or explicit failure state | inspect failure |
| Empty cell | no task fill | no canonical issue | no invented task |
| Hover/selection | honey outer rim/lift only | pointer/tap/focus | inspect selection |
| Board/feed unavailable | grey badge, last known fills retained | respective fetch data/error | retry connection; don't infer empty backlog |

Blocked beats completion within a lifecycle; failed event state beats nominal
result/finished/review kind. Event rings use fresh records (0–15 seconds old),
deduplicate by semantic identity, and expire in 3 seconds. No history replay on
initial load/reconnect. At most one newest event per issue, ties prefer failure;
no more than 24 effects. Tool/usage remain visible in the event list without
rapid repeated ring flashes. Reduced-motion makes rings static, suppresses
breathing/orbit, and preserves labels. Never strobe full-cell red.

Working rings MUST use the running board state, not review/tool history. Stale
board suppresses live-work animation; stale activity suppresses event effects.
No new claims about worker throughput, token quota, FPGA state or scheduler
health are inferred. Those existing panels keep their observed data; new signals
there require their own explicit source mapping rather than reusing task colors.

All real issue records still have coverage unknown until a public proof adapter
exists. Tests may use explicit proof fixtures, never public synthetic tasks.

## Plan

1. [done] Inspect previous owned diff and actual signal sources; identify review
   events incorrectly counted as live work.
2. [done] RED tests: palette states, failure precedence, live-work source,
   event freshness/deduplication and independent board/feed health.
3. [done] Shared resolver; GPU fill/event/work rings; localized card signals
   and expandable color guide; connection badge and motion preference.
4. [done] Regression/build, exact desktop/mobile visual verification and
   independent review; durable evidence and skill update.

## Verified local artifact

Root `index-DWmqLBld.js`, Queen `Queen-DwAgC4OG.js`,
scene `QueenCombBabylon-DNxDYlmF.js`, stylesheet `Queen-C9RsfDFr.css`.
Build passed in 39.13 seconds; independent read-only review found no remaining
blocker after fixing snapshot replay, late-event ordering, recovery color,
accessible refusal labels and false selection event flares.

Desktop 1400×900 and mobile 390×844, both DPR 2, were checked in BrowserOS neo.
Reduced-motion and RU/EN labels were checked. Page-local blocked board/activity
requests produced two stale badges without losing task fills; restoring requests
returned both feeds to live and removed the badges. The test never changed the
server. The final observed board projection had 1206 issues: 1007 goal-pending,
192 review, 7 paused, 0 running and 0 proven-honey. Counts can change on each poll.

The implementation is local, not published. T27 proof ingestion and worker
scheduling are outside this change. Existing type/API ratchet debt remains.

Accessibility basis: W3C WCAG2.2 Understanding
[Use of Color](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html) and
[Three Flashes or Below Threshold](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html).
This is a design constraint, not a claim of a complete WCAG audit.
