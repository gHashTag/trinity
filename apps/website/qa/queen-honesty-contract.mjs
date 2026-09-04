// Queen HUD honesty contract - executable, not a regex. Runs the pure
// functions the round line and the A2A copy depend on, then checks the two
// source facts a regex CAN state. Node 22 needs --experimental-strip-types
// to import the TypeScript module; package.json passes it.
import { readFileSync } from "node:fs";
import { buildingPlan, cellGeometry, decisionDetail, fieldShape, moduleColumn, moduleFor, moduleId, pathInTitle, placeCards, rewriteEndpoints, ringOrder, ringTone, roundStrip, skipReasonWords, staleAge, territoryOf, planHash } from "../src/components/queenHud.ts";

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

const src = readFileSync(new URL("../src/pages/Queen.tsx", import.meta.url), "utf8");
check(/rounds:\s*null,/.test(src), "rounds / 24h is a dash (pulse.rounds is a lease-row count)");
check(!/c\.hudAccepted\b/.test(src), "no tile is labelled ACCEPTED");
check(/stat-verdicts[\s\S]{0,260}c\.hud24h/.test(src) && /beesStarted:\s*"Bees started \/ 24h"/.test(src), "24h figures name their window");
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
const pa = placeCards(new Map(), A, fieldShape(A.length).cellCount);
check(pa.placed.slice(0, 3).map((c) => c && c.number).join(",") === "5,4,3" && pa.placed.length === fieldShape(3).cellCount, "first placement is wire order on a field of the right size");
const pb = placeCards(pa.ledger, [{ number: 6 }, ...A], fieldShape(4).cellCount);
check(pb.placed[0]?.number === 5 && pb.placed[1]?.number === 4 && pb.placed[2]?.number === 3 && pb.placed[3]?.number === 6, "a head insert leaves every known card on its cell; the new card takes the first free cell");
const pc = placeCards(pb.ledger, [{ number: 6 }, { number: 3 }, { number: 5 }], fieldShape(3).cellCount);
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
const geo = cellGeometry(114);
check(geo.length === fieldShape(114).cellCount, "cell geometry has one centre per cell of the field's shape");
const order = ringOrder(geo, Math.floor(geo.length / 2));
check(order[0] === Math.floor(geo.length / 2) && order.length === geo.length && new Set(order).size === geo.length, "ring order starts at home and visits every cell once");
const d = (i) => (geo[i].x - geo[order[0]].x) ** 2 + (geo[i].y - geo[order[0]].y) ** 2;
check(order.every((i, k) => k === 0 || d(i) >= d(order[k - 1])), "ring order never moves inward");
const shape3 = fieldShape(3);
const home3 = Math.floor(shape3.cellCount / 2);
const ringed = placeCards(new Map(), [{ number: 1 }, { number: 2 }, { number: 3 }], shape3.cellCount, ringOrder(cellGeometry(3), home3));
check(ringed.ledger.get(1) === home3 && ringed.placed[home3]?.number === 1, "with a ring order the first card takes the home cell");
check(fieldShape(165).cellCount === 189 && fieldShape(114).cellCount === 138, "the field's cell count is the comb's (189 for 165 cards, not 195)");
// the shape grammar (M-3): the building is a pure function of the signature
const sig = M({ path: "agent-server/apps/server/src", language: "typescript", lines: 12000, functions: 900, imports: 60, exports: 40 });
check(planHash(buildingPlan(sig)) === planHash(buildingPlan({ ...sig })), "the same signature yields the same building");
check(planHash(buildingPlan(sig)) !== planHash(buildingPlan(M({ ...sig, lines: 200 }))), "a different size yields a different building");
check(buildingPlan(sig).parts.filter((p) => p.model === "annex").length === 2 && buildingPlan(M({ ...sig, exports: 0 })).parts.filter((p) => p.model === "annex").length === 0, "wings follow the export bands");
check(buildingPlan(sig).parts.filter((p) => p.model === "antenna").length === 2 && buildingPlan(M({ ...sig, imports: 200 })).parts.filter((p) => p.model === "antenna").length === 3, "antennae follow the import bands, capped at three");
check(buildingPlan(M({ ...sig, functions: 3000 })).parts[0].height > buildingPlan(M({ ...sig, functions: 30 })).parts[0].height && buildingPlan(M({ ...sig, functions: 30000 })).parts[0].height <= 1.6, "height follows function density, capped at 1.6");
check(buildingPlan(M({ language: "rust" })).core === "doneSilo" && buildingPlan(M({ language: "klingon" })).core === "dropped", "the core follows the language, unknown languages a ruin");
check(decisionDetail({ allowed: false, refusal: null }, 0, 1, L) !== "0 executing now", "self-test");

if (fails.length) { for (const f of fails) console.log("  ✗ " + f); console.log(`Queen honesty contract: FAIL (${fails.length})`); process.exit(1); }
console.log(`Queen honesty contract: PASS (${checks} checks)`);
