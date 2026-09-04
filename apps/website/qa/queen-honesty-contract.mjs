// Queen HUD honesty contract - executable, not a regex. Runs the pure
// functions the round line and the A2A copy depend on, then checks the two
// source facts a regex CAN state. Node 22 needs --experimental-strip-types
// to import the TypeScript module; package.json passes it.
import { readFileSync } from "node:fs";
import { decisionDetail, rewriteEndpoints } from "../src/components/queenHud.ts";

const fails = [];
const check = (cond, msg) => { if (!cond) fails.push(msg); };
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

// self-test: the contract must be able to fail
check(decisionDetail({ allowed: false, refusal: null }, 0, 1, L) !== "0 executing now", "self-test");

if (fails.length) { for (const f of fails) console.log("  ✗ " + f); console.log(`Queen honesty contract: FAIL (${fails.length})`); process.exit(1); }
console.log("Queen honesty contract: PASS (13 checks)");
