// Queen HUD honesty contract - executable, not a regex. Runs the pure
// functions the round line and the A2A copy depend on, then checks the two
// source facts a regex CAN state. Node 22 needs --experimental-strip-types
// to import the TypeScript module; package.json passes it.
import { readFileSync } from "node:fs";
import { alertCount, alertSpan, beeSilence, buildingPlan, castlePlaces, epicProgress, familyTint, feedCoverage, ringFamily, ringOfEpic, ringSummary, towerStage, wallBetween, ringOfModulePath, epicOfIssue, hexRingCells, foundationCells, foundationOrder, hexCellCount, hexCentres, hexCorners, hexField, hexIndexAt, hexRing, hexRingStart, hexToWorld, honeyTone, layersFromSearch, spiralAxial, spiralIndex, spiralOrder, HEX_R, S_CELL, buildingTint, cellGeometry, countdownFor, eventIdentity, mergeActivity, serverOffsetMs, decisionDetail, fieldShape, moduleColumn, moduleFor, moduleId, pathInTitle, placeCards, rewriteEndpoints, ringOrder, ringTone, roundStrip, skipReasonWords, staleAge, territoryOf, planHash, withOpenIssues } from "../src/components/queenHud.ts";

const fails = [];
let checks = 0;
const check = (cond, msg) => { checks += 1; if (!cond) fails.push(msg); };
const L = { queueMeaning: "QUEUE-MEANING", executing: "executing now" };

check(decisionDetail({ allowed: true, refusal: null }, 4, 1386, L) === "4 executing now · #1386", "allow: running + latest");
check(decisionDetail({ allowed: true, refusal: null }, null, null, L) === "— executing now", "allow with no status: dash, no latest");
check(decisionDetail({ allowed: true, refusal: "stale text" }, 2, 7, L) === "2 executing now · #7", "allow never prints a refusal");
check(decisionDetail({ allowed: false, refusal: "nothing to choose" }, 0, 1, L) === "nothing to choose", "refusal text wins");
check(decisionDetail({ allowed: false, refusal: null }, 0, 1, L) === "QUEUE-MEANING", "refusal fallback only on a refusal");

const rewritten = rewriteEndpoints(
  { research: "https://api.t27.ai/queen/public-research", board: "https://api.t27.ai/queen/public-board?x=1", odd: "not a url" },
  "https://trios-agent-server-production.up.railway.app/",
);
check(rewritten.research === "https://trios-agent-server-production.up.railway.app/queen/public-research", "origin swapped, path kept");
check(rewritten.board === "https://trios-agent-server-production.up.railway.app/queen/public-board?x=1", "query kept");
check(rewritten.odd === "not a url", "a non-URL is left alone");

const combSrc = readFileSync(new URL('../src/components/QueenCombBabylon.tsx', import.meta.url), 'utf8');
const src = readFileSync(new URL("../src/pages/Queen.tsx", import.meta.url), "utf8");
check(/rounds:\s*null,/.test(src), "rounds / 24h is a dash (pulse.rounds is a lease-row count)");
check(!/c\.hudAccepted\b/.test(src), "no tile is labelled ACCEPTED");
check(/stat-verdicts[\s\S]{0,260}c\.hud24h/.test(src) && /beesStarted:\s*"[^"]*\/ 24h"/.test(src) && /beesStarted:\s*"[^"]*\/ 24ч"/.test(src), "24h figures name their window (in both languages; the wording may shorten, the window may not)");
check(/summary\.online\}\/\$\{hardware\.summary\.total\}/.test(src), "FOUNDRY tile is online/total");
check(/rewriteEndpoints\(bootstrap\.endpoints, QUEEN_API\)/.test(src), "the copied bootstrap names the page's own origin");

const RL = { allow: "ALLOW", refuse: "REFUSE", executing: "executing now", queueMeaning: "QUEUE-MEANING", reasons: "skipped" };
const stripA = roundStrip({ decidedAt: "2026-09-04T03:44:42Z", allowed: true, refusal: null, skippedCount: 33 }, 4, 1386, RL, "en");
check(/^\d\d:\d\d · ALLOW · 4 executing now · #1386 · 33 skipped$/.test(stripA), "round strip on ALLOW: clock, verdict, detail, skips");
const stripR = roundStrip({ decidedAt: "2026-09-04T02:59:42Z", allowed: false, refusal: "nothing to choose", skippedCount: 51 }, 0, 1373, RL, "en");
check(/^\d\d:\d\d · REFUSE · nothing to choose · 51 skipped$/.test(stripR), "round strip on a refusal");
check(roundStrip({ decidedAt: "not a date", allowed: false, refusal: null, skippedCount: 0 }, null, null, RL, "en").startsWith("— · REFUSE · QUEUE-MEANING"), "round strip with a bad date reads a dash");
check(skipReasonWords("missingBoundary") === "missing boundary" && skipReasonWords("notFirst") === "not first" && skipReasonWords("claimed") === "claimed", "skip reasons spaced, nothing added");
check(/skipReasonWords\(reason\)/.test(src) && /roundStrip\(/.test(src), "the page uses the strip and the spaced reasons");

// self-test: the contract must be able to fail
const A = [{ number: 5 }, { number: 4 }, { number: 3 }];
const pa = placeCards(new Map(), A, hexField(A.length).cellCount);
check(pa.placed.slice(0, 3).map((c) => c && c.number).join(",") === "5,4,3" && pa.placed.length === hexField(3).cellCount, "first placement is wire order on a field of the right size");
const pb = placeCards(pa.ledger, [{ number: 6 }, ...A], hexField(4).cellCount);
check(pb.placed[0]?.number === 5 && pb.placed[1]?.number === 4 && pb.placed[2]?.number === 3 && pb.placed[3]?.number === 6, "a head insert leaves every known card on its cell; the new card takes the first free cell");
const pc = placeCards(pb.ledger, [{ number: 6 }, { number: 3 }, { number: 5 }], hexField(3).cellCount);
check(pc.placed[0]?.number === 5 && pc.placed[1] === null && pc.placed[2]?.number === 3 && pc.placed[3]?.number === 6 && pa.ledger.size === 3, "a departed card frees its cell, nobody moves, the input ledger is untouched");
check(placeCards(new Map([[7, 500]]), [{ number: 7 }], 27).placed[0]?.number === 7, "an index outside the field is re-placed");
const t0 = Date.parse("2026-09-04T09:00:00Z");
check(staleAge(t0 + 42_000, new Date(t0), "Failed to fetch") === 42, "stale age is seconds since the last success once a poll fails");
check(staleAge(t0 + 42_000, new Date(t0), null) === null && staleAge(t0, null, "Failed to fetch") === null, "no badge while polls succeed or before the first success");
check(ringTone("held") === "#00FF88" && ringTone("fog") === "#FF6B6B" && ringTone("neutral") === "#64DCFF", "ring colours follow the territory (held green, fog cold, neutral cyan)");
check(ringTone(territoryOf("running")) === "#00FF88" && ringTone(territoryOf("blocked")) === "#FF6B6B" && ringTone(territoryOf("review")) === "#64DCFF", "a column's ring colour is its territory's");
check(/data-pick-territory=\{livePick\?\.territory/.test(src), "the viewport section names the picked territory for probes");
// modules as the unit of place (M-2)
check(moduleId("agent-server/apps/server/src") === moduleId("agent-server/apps/server/src") && moduleId("a") !== moduleId("b") && moduleId("x") > 0, "a module id is a stable positive hash of its path");
const M = (over) => ({ path: "p", depth: 1, language: "typescript", files: 1, lines: 1, functions: 1, imports: 0, exports: 0, lastTouched: null, openIssues: [], ...over });
const T = Date.parse("2026-09-04T09:00:00Z");
check(moduleColumn(M({ openIssues: [5] }), T, new Set([5])) === "running" && moduleColumn(M({ openIssues: [5] }), T, new Set()) === "review", "an issue in progress makes a module running; an open one, review");
check(moduleColumn(M({ lastTouched: "2026-09-01T00:00:00Z" }), T, new Set()) === "done" && moduleColumn(M({ lastTouched: "2026-01-01T00:00:00Z" }), T, new Set()) === "dropped" && moduleColumn(M({ lastTouched: "2026-06-01T00:00:00Z" }), T, new Set()) === "backlog", "touched within 30 days is alive, 180 days dormant, between is backlog");
check(moduleFor("trios/agent-server/apps/server/src/lib/agents/x.ts", [M({ path: "agent-server" }), M({ path: "agent-server/apps/server/src" })])?.path === "agent-server/apps/server/src" && moduleFor("nowhere/x.ts", [M({ path: "agent-server" })]) === null, "a file belongs to the longest module path that prefixes it");
check(pathInTitle("trios/agent-server/apps/server/src/api/x.ts breaks L3") === "trios/agent-server/apps/server/src/api/x.ts" && pathInTitle("no path here") === null, "the first path in a title, or none");
// the hex spiral (the honeycomb foundation, 2026-09-05): pointy-top, cell 0 is the hub, ring k holds 6k cells
check(hexCellCount(18) === 1027 && hexField(1010).rings === 18 && hexField(1010).cellCount === 1027 && hexField(165).rings === 7 && hexField(165).cellCount === 169 && hexField(114).cellCount === 127 && hexField(3).cellCount === 37, "1009 closed issues plus the hub fill 18 rings of 1027 cells; 165 cards 7 rings; 114 cards 6 rings; the smallest field has 37 cells");
const anchors = [[1, 1, 0], [6, 0, 1], [7, 2, 0], [18, 1, 1], [19, 3, 0], [1026, 17, 1]];
check(anchors.every(([i, q, r]) => spiralAxial(i).q === q && spiralAxial(i).r === r) && spiralAxial(0).q === 0 && spiralAxial(0).r === 0, "the spiral's anchors: cell 1 due east, each ring starts due east, the last cell of ring 18 is (17,1)");
check(Array.from({ length: 1027 }, (_, i) => i).every((i) => spiralIndex(spiralAxial(i)) === i), "spiral index and spiral axial are inverses for every cell of 18 rings");
check(Array.from({ length: 1027 }, (_, i) => hexRing(spiralAxial(i))).every((k, i, a) => i === 0 || k >= a[i - 1]) && Array.from({ length: 18 }, (_, k) => k + 1).every((k) => hexRing(spiralAxial(hexRingStart(k))) === k), "the spiral never moves inward and ring k begins at 3k(k-1)+1");
check(Math.abs(hexToWorld({ q: 1, r: 0 }).x - S_CELL) < 1e-9 && Math.abs(HEX_R * Math.sqrt(3) - S_CELL) < 1e-9, "neighbours stand 150 apart, today's cell side, so every building scale holds");
check(Array.from({ length: 1027 }, (_, i) => i).every((i) => { const w = hexToWorld(spiralAxial(i)); return hexIndexAt(w.x, w.y, 1027) === i; }), "a world point at a cell's centre reads back as that cell, for all 1027");
const c31 = hexToWorld({ q: 3, r: -1 }), c41 = hexToWorld({ q: 4, r: -1 });
check(hexIndexAt(c31.x + (c41.x - c31.x) * 0.4, c31.y, 1027) === spiralIndex({ q: 3, r: -1 }) && hexIndexAt(c31.x + (c41.x - c31.x) * 0.6, c31.y, 1027) === spiralIndex({ q: 4, r: -1 }), "a point four tenths of the way to the neighbour still reads its own cell; six tenths reads the neighbour");
check(hexIndexAt(hexToWorld({ q: 19, r: 0 }).x, 0, 1027) === -1 && hexCorners({ q: 0, r: 0 }).length === 6 && hexCorners({ q: 0, r: 0 }).every((p) => Math.abs(Math.hypot(p.x, p.y) - HEX_R) < 1e-9), "a point beyond the last ring reads no cell; a hex has six corners at the circumradius");
check(hexCentres(127).length === 127 && spiralOrder(37).length === 36 && spiralOrder(37)[0] === 1 && !spiralOrder(37).includes(0) && new Set(spiralOrder(37)).size === 36, "one centre per cell; the spiral order visits every cell but the hub, cell 1 first");
const ringed = placeCards(new Map(), [{ number: 1 }, { number: 2 }, { number: 3 }], 37, spiralOrder(37));
check(ringed.ledger.get(1) === 1 && ringed.placed[0] === null && ringed.placed[1]?.number === 1 && ringed.placed[2]?.number === 2, "with the spiral order the first card takes cell 1; cell 0 is the hub and never a card's");
check(placeCards(new Map(), [{ number: 8 }, { number: 9 }], 37, [5, 6]).ledger.size === 2 && placeCards(new Map(), [{ number: 8 }, { number: 9 }], 37, [5, 6]).placed[6]?.number === 9, "an order shorter than the field is honoured as far as it goes");
// the foundation: one cell per closed issue, in closed_at order, from a dated snapshot
const fdIssues = [{ number: 5, title: "b", closedAt: "2026-09-05T00:00:02Z", labels: [], epicRefs: [] }, { number: 4, title: "a", closedAt: "2026-09-05T00:00:01Z", labels: [], epicRefs: [] }, { number: 9, title: "c", closedAt: "not a date", labels: [], epicRefs: [] }];
check(foundationOrder(fdIssues).map((i) => i.number).join(",") === "4,5,9" && foundationCells(fdIssues, 37)[0] === null && foundationCells(fdIssues, 37)[1]?.number === 4 && foundationCells(fdIssues, 37)[2]?.number === 5, "closed_at ascending, an undatable close last; index i+1 holds the i-th; the hub holds nothing");
const fdNow = Date.parse("2026-09-05T12:00:00Z");
check(honeyTone("2026-09-05T11:00:00Z", fdNow)[0] > honeyTone("2026-09-01T00:00:00Z", fdNow)[0] && honeyTone("2026-09-01T00:00:00Z", fdNow)[0] > honeyTone("2026-05-01T00:00:00Z", fdNow)[0] && honeyTone("bad", fdNow)[3] === 1, "fresh honey is brightest, a week old warmer than a season old; an undatable close still reads as honey");
check(layersFromSearch("").foundation && layersFromSearch("").castle && layersFromSearch("").code && layersFromSearch("?layers=castle").castle && !layersFromSearch("?layers=castle").foundation && !layersFromSearch("?layers=none").code && layersFromSearch("?layers=bogus,code").code, "no parameter: every layer on; a list: exactly those; none: none; unknown names ignored");
// the shape grammar (M-3): the building is a pure function of the signature
const sig = M({ path: "agent-server/apps/server/src", language: "typescript", lines: 12000, functions: 900, imports: 60, exports: 40 });
check(planHash(buildingPlan(sig)) === planHash(buildingPlan({ ...sig })), "the same signature yields the same building");
check(planHash(buildingPlan(sig)) !== planHash(buildingPlan(M({ ...sig, lines: 200 }))), "a different size yields a different building");
check(buildingPlan(sig).parts.filter((p) => p.model === "annex").length === 2 && buildingPlan(M({ ...sig, exports: 0 })).parts.filter((p) => p.model === "annex").length === 0, "wings follow the export bands");
check(buildingPlan(sig).parts.filter((p) => p.model === "antenna").length === 2 && buildingPlan(M({ ...sig, imports: 200 })).parts.filter((p) => p.model === "antenna").length === 3, "antennae follow the import bands, capped at three");
check(buildingPlan(M({ ...sig, functions: 3000 })).parts[0].height > buildingPlan(M({ ...sig, functions: 30 })).parts[0].height && buildingPlan(M({ ...sig, functions: 30000 })).parts[0].height <= 1.6, "height follows function density, capped at 1.6");
check(buildingPlan(M({ language: "rust" })).core === "doneSilo" && buildingPlan(M({ language: "klingon" })).core === "dropped", "the core follows the language, unknown languages a ruin");
// the tint (M-4): recency and wear, deterministic
const T2 = Date.parse("2026-09-04T09:00:00Z");
const fresh = buildingTint(M({ lastTouched: "2026-09-03T00:00:00Z" }), T2), old = buildingTint(M({ lastTouched: "2025-01-01T00:00:00Z" }), T2);
check(fresh[0] > old[0] && fresh[2] > old[2] && old[2] > old[0], "a fresh module is warm and bright, a dormant one cold and dim");
check(buildingTint(M({ lastTouched: "2026-09-03T00:00:00Z", openIssues: [1, 2] }), T2)[0] < fresh[0] && buildingTint(M({ lastTouched: "2026-09-03T00:00:00Z", openIssues: [1, 2, 3, 4, 5] }), T2)[0] >= 0.5, "open issues wear the paint down, never below a floor");
check(buildingPlan(M({ functions: 700, lines: 5000 })).parts.filter((p) => p.model === "band").length === 3 && buildingPlan(M({ functions: 10, lines: 100 })).parts.filter((p) => p.model === "band").length === 0, "window bands follow the function bands, capped at three");
// open issues come from the board, for the wire's rows and the snapshot alike (M-1)
const enriched = withOpenIssues([M({ path: "agent-server" }), M({ path: "agent-server/apps/server/src" })], [
  { number: 7, title: "trios/agent-server/apps/server/src/lib/x.ts breaks L3", column: "review" },
  { number: 8, title: "trios/agent-server/apps/server/src/lib/x.ts again", column: "done" },
  { number: 9, title: "agent-server/README.md is stale", column: "backlog" },
  { number: 10, title: "no path at all", column: "running" },
]);
check(enriched[1].openIssues.join(",") === "7" && enriched[0].openIssues.join(",") === "9", "an open issue lands on the longest module its path names; done cards and pathless titles do not");
// the round clock follows the server's Date header, not the client's clock (P1-30)
const srv = Date.parse("2026-09-04T18:00:00Z");
check(serverOffsetMs("Thu, 04 Sep 2026 18:00:00 GMT", srv + 120_000) === -120_000 && serverOffsetMs("Thu, 04 Sep 2026 18:00:00 GMT", srv + 119_900, srv + 120_100) === -120_000 && serverOffsetMs(null, srv) === null && serverOffsetMs("not a date", srv) === null, "the offset is server minus the request's midpoint (NTP); absent or bad headers give null");
const fastClient = srv + 120_000; // the client runs two minutes fast
const withOffset = countdownFor(fastClient, -120_000, "2026-09-04T17:56:00Z", 300);
const noOffset = countdownFor(fastClient, null, "2026-09-04T17:56:00Z", 300);
check(withOffset.known && !withOffset.overdue && Math.round(withOffset.remaining) === 60, "a client two minutes fast still reads the server's 60 s remaining");
check(noOffset.known && noOffset.overdue, "without the header the same client would read OVERDUE (the defect P1-30 removes)");
check(!countdownFor(srv, 0, null, 300).known && !countdownFor(srv, 0, "2026-09-04T17:56:00Z", 0).known, "no round length or no last round: unknown, never a fabricated clock");
// the activity merge is pure and the newest poll's wire order wins same-second ties (P0-9)
const TIE = "2026-09-04T18:00:00.000Z";
const evAt = (id, at = TIE, kind = "tool") => ({ id, kind, at, issue: null, title: id, state: null });
const prevBuf = { events: [evAt("p1"), evAt("p2", "2026-09-04T17:59:00.000Z")], alerts: [evAt("a-old", "2026-09-04T16:30:00.000Z", "error")] };
const merged = mergeActivity(prevBuf, { cursor: 9, events: [evAt("n1"), evAt("n2"), evAt("p1", TIE, "review")] }, Date.parse("2026-09-04T18:00:30.000Z"));
check(merged.events.map((e) => e.id).join(",") === "n1,n2,p1,p2", "same-second ties keep the newest poll's wire order, then the older buffer, then by time");
check(merged.events.find((e) => e.id === "p1")?.kind === "review" && merged.events.length === 4, "an event in both polls keeps the newest copy, once");
check(merged.alerts.map((e) => e.id).join(",") === "p1" && merged.cursor === 9, "the bell keeps alert kinds inside the window and drops the hour-old one; the cursor is the wire's");
check(mergeActivity(null, { cursor: 1, events: Array.from({ length: 130 }, (_, i) => evAt(`e${i}`, new Date(Date.parse(TIE) - i * 1000).toISOString())) }, Date.parse(TIE)).events.length === 120, "the feed keeps 120 by count, newest first");
// a review verdict's identity is (issue, state): the tick re-stamps it every round (P0-10)
const rv = (id, at, state = "wait", kind = "review") => ({ id, kind, at, issue: 1471, title: "t", state });
check(eventIdentity(rv("review-1471-1788552916000-0", "2026-09-04T20:15:16Z")) === eventIdentity(rv("review-1471-1788553216000-0", "2026-09-04T20:20:16Z")) && eventIdentity(rv("a", "x", "accepted")) !== eventIdentity(rv("b", "x", "wait")) && eventIdentity({ id: "tool-1", kind: "tool", issue: 1471, state: null }) === "tool-1", "same issue and state is one identity across stamps; a state change is a new one; other kinds keep their id");
const restamped = mergeActivity({ events: [rv("review-1471-1788552916000-0", "2026-09-04T20:15:16Z")], alerts: [rv("review-1471-1788552916000-0", "2026-09-04T20:15:16Z")] }, { cursor: 2, events: [rv("review-1471-1788553216000-0", "2026-09-04T20:20:16Z")] }, Date.parse("2026-09-04T20:20:30Z"));
check(restamped.events.length === 1 && restamped.events[0].id === "review-1471-1788553216000-0" && restamped.alerts.length === 1, "a re-stamped verdict replaces its older feed row and alert instead of adding one");
check(alertCount([rv("review-1471-1788552916000-0", "2026-09-04T20:15:16Z"), rv("review-1471-1788553216000-0", "2026-09-04T20:20:16Z"), rv("review-1471-1788553216000-1", "2026-09-04T20:20:16Z", "accepted")], Date.parse("2026-09-04T20:21:00Z")) === 2, "the bell counts identities: one pending verdict re-stamped twice plus its acceptance is two, not three");
// the bell names the span it observed, not the hour its window implies (P0-11)
const seenFrom = mergeActivity(null, { cursor: 1, events: [evAt("s1", "2026-09-04T20:41:00Z"), evAt("s2", "2026-09-04T20:50:00Z")] }, Date.parse("2026-09-04T20:55:00Z"));
check(seenFrom.observedFrom === "2026-09-04T20:41:00Z" && mergeActivity(seenFrom, { cursor: 2, events: [evAt("s3", "2026-09-04T20:56:00Z")] }, Date.parse("2026-09-04T20:57:00Z")).observedFrom === "2026-09-04T20:41:00Z", "observedFrom is the oldest moment any poll showed and never moves later");
const spanEarly = alertSpan("2026-09-04T20:41:00Z", Date.parse("2026-09-04T20:55:00Z"));
const spanFull = alertSpan("2026-09-04T19:00:00Z", Date.parse("2026-09-04T20:55:00Z"));
check(spanEarly && spanEarly.clipped && spanEarly.seconds === 14 * 60 && spanFull && !spanFull.clipped && spanFull.seconds === 3600 && alertSpan(null, 0) === null, "a wire that began 14 min ago yields a 14-min span; an older one yields the hour; no wire yet yields nothing");
// the round tile reads one endpoint and labels its interval as a bound (P1-29)
check(/const roundSeconds = board\?\.pulse\.roundSeconds \?\? 0;/.test(src) && /const lastRoundAt = board\?\.pulse\.lastRoundAt \?\? null;/.test(src), "the round tile's two inputs come from public-board's pulse only; no fallback to the status interval or the last decision");
check(/`\$\{c\.hudSince\} \$\{formatMoment\(lastRoundAt, lang\)\} · ≤ \$\{formatCountdown\(roundSeconds\)\}`/.test(src) && /hudSince:\s*"since"/.test(src) && /hudSince:\s*"с"/.test(src), "the sub-line names the last round's moment and the interval as a bound (≤) in both languages");
check(/schedulerOff \|\| !roundKnown \? "—" : `\+\$\{formatCountdown\(elapsedSeconds\)\}`/.test(src), "the value counts up since the last round; no countdown promises the next round at a second");
// the status pill reads swarmState through COPY keys; the VERDICTS tile adds the unreviewed count only when the wire has it (P1-28)
check(/data\?\.swarmState === "working"[\s\S]{0,40}c\.swarmWorking[\s\S]{0,120}c\.swarmIdle[\s\S]{0,120}c\.swarmPaused[\s\S]{0,80}data\.swarmState\.toUpperCase\(\)[\s\S]{0,40}c\.swarmUnknown/.test(src), "the pill maps working/idle/paused to COPY keys, prints an unfamiliar wire state as itself, and a missing one as the unknown key");
check(/swarmWorking:\s*"WORKING"/.test(src) && /swarmWorking:\s*"РАБОТАЕТ"/.test(src) && /hudReady:\s*"ready"/.test(src) && /hudReady:\s*"готово"/.test(src), "the four swarm words and the ready word exist in both languages");
check(/typeof data\?\.dispatches\.unreviewed === "number" \? ` · \$\{data\.dispatches\.unreviewed\} \$\{c\.hudReady\}` : ""/.test(src), "the VERDICTS sub-line prints the unreviewed count only when the wire carries the field, never 0 for an absent one");
check(/`\$\{decisionInfo\} · \$\{decision\.allowed \? c\.chose : c\.stoodDown\}`/.test(src), "the gold block's decision line leads with the wire field (the refusal or what the round did), the verb follows");
// the INTEL FEED header states what it holds, from its rows (P1-27)
const cov = feedCoverage([{ at: "2026-09-05T00:40:00Z" }, { at: "2026-09-05T00:41:02Z" }, { at: "2026-09-05T00:40:30Z" }]);
check(cov.rows === 3 && cov.spanSeconds === 62 && cov.oldestAt === "2026-09-05T00:40:00Z" && cov.newestAt === "2026-09-05T00:41:02Z", "three rows over 62 s: the header says 3 rows · 62 s from the rows themselves");
check(feedCoverage([{ at: "2026-09-05T00:40:00Z" }]).spanSeconds === null && feedCoverage([]).rows === 0 && feedCoverage([{ at: "bad" }, { at: "2026-09-05T00:40:00Z" }]).spanSeconds === null, "one row, no rows or an undatable row: no span is printed, never a fabricated 0 s");
// review and finished rows print their wire state after the kind word (P1-24)
check(/return \(event\.kind === "review" \|\| event\.kind === "finished"\) && event\.state && event\.state !== event\.kind \? `\$\{word\} · \$\{event\.state\}` : word;/.test(src), "a verdict or a finish carries its wire state after the kind word; no state or a state equal to the kind (finished · finished) adds no suffix");
// a bee's silence is measured against the round (P1-23)
const nowB = Date.parse("2026-09-05T02:05:00Z");
check(beeSilence("2026-09-05T02:04:18Z", nowB, 300)?.seconds === 42 && beeSilence("2026-09-05T02:04:18Z", nowB, 300)?.cold === false && beeSilence("2026-09-05T01:59:59Z", nowB, 300)?.cold === true, "42 s of silence under a 300 s round is warm; 301 s is cold");
check(beeSilence("2026-09-05T01:00:00Z", nowB, null)?.cold === false && beeSilence(null, nowB, 300) === null && beeSilence("bad", nowB, 300) === null, "no round length: never cold; no last word or an undatable one: no age at all");
check(/\$\{QUEEN_API\}\/queen\/public-foundation/.test(src) && /"\.\/queen\/foundation\.json"/.test(src) && /data-foundation=\{foundationState\.data \?/.test(src), "the honeycomb's GitHub facts come from the server's route first and the loop's dated snapshot second, named on the viewport (H-C1)");
check((src.match(/hexField\(fieldNeed\)/g) || []).length >= 2 && /const fieldNeed = Math\.max\(moduleCards\.length \+ 1, closedCount \+ 1, \(foundationState\.data\?\.rings\.length \?\? 0\) > 0 \? hexCellCount\(CASTLE_RING\) \+ 1 : 0\)/.test(src), "the field is as large as the honey and the castle need (the hub plus modules or closed issues, at least ring 7 when rings exist), the modules keep their inner cells (H-C2, K-2)");
check(/data-pick-kind=\{livePick\?\.kind/.test(src) && /data-pick-issue=\{livePick\?\.kind === "issue"/.test(src) && /if \(pick\.kind === "issue" && pick\.issue\)/.test(src), "a pick is (kind, number): an issue pick follows its number through the snapshot, the viewport names the kind and the issue (H-E)");
// the castle of the rings (K-1): places on spiral ring 7, epics to rings, towers by stage
const ksRings = ["SR-00", "RUST-13", "T27-00", "RUST-04"];
const ksPlaces = castlePlaces(ksRings);
check(ksPlaces.length === 4 && ksPlaces.map((p) => p.ring).join(",") === "RUST-04,RUST-13,SR-00,T27-00" && ksPlaces.every((p) => hexRingCells(7).includes(p.plinth) && hexRingCells(7).includes(p.wall) && p.plinth % 2 === 1 && p.wall % 2 === 0) && new Set(ksPlaces.map((p) => p.plinth)).size === 4, "the plinths take ring 7's cells in name order, one per ring, walls on the cells between; a permuted input gives the same places");
check(castlePlaces(["T27-00", "SR-00", "RUST-13", "RUST-04"]).map((p) => p.plinth).join(",") === ksPlaces.map((p) => p.plinth).join(","), "the places do not depend on the input's order");
check(ringFamily("RUST-13") === "RUST" && ringFamily("SR-00") === "SR" && ringFamily("T27-01") === "T27" && ringFamily("weird") === "other" && familyTint("RUST")[0] > familyTint("SR")[0] && familyTint("other")[3] === 1, "a ring's family is its prefix; each family has a tint, an unknown one a grey");
const ksEpic = (over) => ({ number: 9001, title: "EPIC: RING-SR-00 has one source", state: "open", closedAt: null, labels: [], ring: null, ringBy: null, children: [], ...over });
check(ringOfEpic(ksEpic({ labels: ["ring:RUST-13"] }), ksRings).ring === "RUST-13" && ringOfEpic(ksEpic({ labels: ["ring:RUST-13"] }), ksRings).by === "label" && ringOfEpic(ksEpic({}), ksRings).ring === "SR-00" && ringOfEpic(ksEpic({}), ksRings).by === "title" && ringOfEpic(ksEpic({ title: "EPIC: RING-00 is generated", labels: ["ring:NOPE"] }), ksRings).ring === null, "an epic's ring: the ring:<NAME> label first, then a directory name in the title, else unassigned; an unknown label name and RING-00 bind nothing");
const ksKids = (closed, open) => [...Array.from({ length: closed }, (_, i) => ({ number: 100 + i, title: "c", state: "closed", closedAt: "2026-09-05T00:00:00Z" })), ...Array.from({ length: open }, (_, i) => ({ number: 200 + i, title: "o", state: "open", closedAt: null }))];
check(epicProgress(ksEpic({ children: ksKids(3, 2) })).closed === 3 && epicProgress(ksEpic({ children: ksKids(3, 2) })).total === 5 && Math.abs(epicProgress(ksEpic({ children: ksKids(3, 2) })).ratio - 0.6) < 1e-9 && epicProgress(ksEpic({})).ratio === null, "progress is closed children over all children; no children means no ratio, never 0");
check(towerStage(ksEpic({})) === "plinth" && towerStage(ksEpic({ children: ksKids(1, 4) })) === "walls" && towerStage(ksEpic({ children: ksKids(3, 2) })) === "tower" && towerStage(ksEpic({ state: "closed", closedAt: "2026-09-05T00:00:00Z", children: ksKids(5, 0) })) === "wizardTower" && towerStage(ksEpic({ state: "open", children: ksKids(5, 0) })) === "tower", "the stages: no children a plinth, a closed child walls, half a tower, a closed epic with every child closed the wizard tower");
const ksSummary = ringSummary("SR-00", [ksEpic({ children: ksKids(3, 2) }), ksEpic({ number: 9002, labels: ["ring:RUST-13"], children: ksKids(0, 1) })], ksRings);
check(ksSummary.epics === 1 && ksSummary.closed === 3 && ksSummary.total === 5 && ringSummary("T27-00", [], ksRings).epics === 0 && ringSummary("T27-00", [], ksRings).ratio === null, "a ring's summary counts only the epics bound to it; a ring with no epic has no ratio");
check(wallBetween([ksEpic({ state: "closed", closedAt: "x", children: ksKids(2, 0) })], [ksEpic({ state: "closed", closedAt: "x", children: ksKids(1, 0) })]) === true && wallBetween([ksEpic({ children: ksKids(3, 2) })], [ksEpic({ state: "closed", closedAt: "x", children: ksKids(1, 0) })]) === false && wallBetween([], [ksEpic({ state: "closed", closedAt: "x", children: ksKids(1, 0) })]) === false, "a wall rises only between two rings whose every epic is a keep");
check(ringOfModulePath("rings/SR-00") === "SR-00" && ringOfModulePath("rings/RUST-13/clade-meshd/src") === "RUST-13" && ringOfModulePath("rings") === null && ringOfModulePath("apps/rings/SR-00") === null && ringOfModulePath(".") === null, "ringOfModulePath: rings/<NAME> and anything beneath it; nothing else");
check(epicOfIssue(101, [ksEpic({ number: 9001, children: ksKids(3, 2) }), ksEpic({ number: 9002, children: [] })])?.number === 9001 && epicOfIssue(1, [ksEpic({ children: ksKids(3, 2) })]) === null, "epicOfIssue: the first epic listing the issue among its children, else null");
check(/data-working/.test(combSrc) && /WORK_WINDOW_MS/.test(combSrc) && /const i = cellOfPath\(e\.title\);/.test(combSrc) && /if \(i >= 0\) seen\.add\(i\)/.test(combSrc), "the working cells come from the wire's own file paths: an event whose path resolves to no module marks nothing (the user, 2026-09-06)");
check(/if \(hover >= 0 && hover !== p && cells\[hover\]\) placeDashed/.test(combSrc), "every cell under the pointer lights up, not only the ones carrying a card");
const SPACE_KIT = ["platform_small", "machine_generatorLarge", "satelliteDish_large", "hangar_smallA", "hangar_roundA", "structure_closed", "gate_complex", "crater", "hangar_largeA", "rock_crystalsLargeA", "astronautA", "astronautB", "rover", "alien"];
check(SPACE_KIT.every((m) => !combSrc.includes(m)), `the field draws one kit: no space-kit model may be named (${SPACE_KIT.filter((m) => combSrc.includes(m)).join(", ") || "none"})`);
check(/host\.setAttribute\("data-foundation-shape", "outline"\)/.test(combSrc) && /CreateLineSystem\("cells"/.test(combSrc) && !/CreateCylinder\("honey"/.test(combSrc) && !/hex-sand/.test(combSrc), "the cells are outlines: a line system per cell, no honey disc and no filled tile model (the user, 2026-09-06)");
check(/host\.setAttribute\("data-hover-issue"/.test(combSrc) && /queen27-hover-card/.test(combSrc), "a hovered cell names its GitHub issue on the host and in the card");
check(/host\.setAttribute\("data-castle-source", fdNow \? fdNow\.source : "none"\)/.test(combSrc) && /data-castle-stages/.test(combSrc) && /data-castle-unassigned/.test(combSrc), "the castle's testimony on the host comes from the snapshot's source, never a guess; stages and unassigned epics are named (K-2)");
check(decisionDetail({ allowed: false, refusal: null }, 0, 1, L) !== "0 executing now", "self-test");

if (fails.length) { for (const f of fails) console.log("  ✗ " + f); console.log(`Queen honesty contract: FAIL (${fails.length})`); process.exit(1); }
console.log(`Queen honesty contract: PASS (${checks} checks)`);
