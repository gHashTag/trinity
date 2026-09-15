// Queen idle-reason contract. BEES read 0/4 on 2026-09-15 and the owner asked
// why the bees were broken: the swarm was healthy_idle and the last round said
// "nothing to choose" - 449 of 488 candidates had no ## Boundary. The status
// the page already fetched carried the reason; the HUD did not say it. This
// runs the pure reader and formatter on real /queen/status snapshots
// (qa/fixtures/queen-status) and on malformed ones, then checks the page uses
// them. Pure, no browser. Node 22 needs --experimental-strip-types.
import { readFileSync } from "node:fs";
import { idleLine, idleReason, skipCounts } from "../src/components/queenHud.ts";

const fails = [];
let checks = 0;
const check = (cond, msg) => { checks += 1; if (!cond) fails.push(msg); };
const fixture = (name) => JSON.parse(readFileSync(new URL(`./fixtures/queen-status/${name}`, import.meta.url), "utf8"));
const at = (status, seconds) => Date.parse(status.lastTick.decidedAt) + seconds * 1000;
const clone = (value) => structuredClone(value);

const EN = {
  idle: "idle", nothingToChoose: "nothing to choose", of: "of", issues: "issues",
  stale: "round stale", staleDetail: "last decision {age} ago, rounds every {interval}",
  unitS: "s", unitMin: "min", unitH: "h",
  reasons: { missingBoundary: "lack a ## Boundary", claimed: "claimed", completed: "done but open", fileConflict: "touch held files", incompleteSpec: "incomplete spec", notFirst: "not first", other: "other" },
};
const RU = {
  idle: "свободно", nothingToChoose: "нечего выбрать", of: "из", issues: "задач",
  stale: "раунд устарел", staleDetail: "последнее решение {age} назад, раунды каждые {interval}",
  unitS: "с", unitMin: "мин", unitH: "ч",
  reasons: { missingBoundary: "без ## Boundary", claimed: "заняты", completed: "сделаны и не закрыты", fileConflict: "задевают занятые файлы", incompleteSpec: "спека неполная", notFirst: "не первые", other: "прочие" },
};
const line = (status, nowMs, words = EN) => { const r = idleReason(status, nowMs); return r ? idleLine(r, words) : null; };

// 1. the real healthy_idle snapshot: every number comes from the file
const idle = fixture("healthy-idle-2026-09-15T1250Z.json");
const t = idle.lastTick, sum = t.skipSummary, free = idle.workers.capacity - idle.workers.active;
const en = line(idle, at(idle, 60));
check(en !== null && en.text === `${free} idle: nothing to choose — ${sum.missingBoundary.count} of ${t.skippedCount} issues lack a ## Boundary, ${sum.completed.count} done but open, ${sum.claimed.count} claimed`, `healthy_idle (en): the refusal, then the three reasons by size, numbers from the wire (got "${en?.text}")`);
check(en?.text === "4 idle: nothing to choose — 449 of 488 issues lack a ## Boundary, 27 done but open, 12 claimed", `healthy_idle (en) literal, so a reader sees the sentence the owner will see (got "${en?.text}")`);
check(en?.head === "4 idle: nothing to choose" && en?.example === true, "healthy_idle: the tile's short head is the free count and the refusal; the example link is offered");
const ru = line(idle, at(idle, 60), RU);
check(ru?.text === "4 свободно: нечего выбрать — 449 из 488 задач без ## Boundary, 27 сделаны и не закрыты, 12 заняты", `healthy_idle (ru) (got "${ru?.text}")`);
check(!/\d/.test(RU.nothingToChoose + EN.nothingToChoose) && !/[А-яЁё]/.test(en?.text ?? ""), "no digit lives in the copy, no Cyrillic leaks into English");

// 2. working snapshots: the round dispatched, so there is no idle line
const working = fixture("working-2026-09-15T1400Z.json");
const cap12 = fixture("working-capacity12-2026-09-15T1533Z.json");
check(line(working, at(working, 60)) === null, "working (allowed, 2 of 4 busy): no idle line");
check(line(cap12, at(cap12, 60)) === null, "working (allowed, capacity 12): no idle line");
// a real snapshot where one bee works and the round still refused: three slots are idle and it says why
const busyRefused = fixture("working-refused-2026-09-15T1350Z.json");
check(line(busyRefused, at(busyRefused, 60))?.text === "3 idle: nothing to choose — 448 of 487 issues lack a ## Boundary, 27 done but open, 12 claimed", `1 of 4 busy, round refused: the three idle slots are explained (got "${line(busyRefused, at(busyRefused, 60))?.text}")`);

// 3. staleness: older than two intervals says the round is stale, never the reasons
check(line(idle, at(idle, 600))?.head === "4 idle: nothing to choose", "exactly two intervals old is still fresh (the server's own bound)");
const stale = line(idle, at(idle, 601));
check(stale?.text === "4 idle: round stale — last decision 10 min ago, rounds every 5 min" && stale.example === false, `601 s past a 300 s round: stale, no reasons (got "${stale?.text}")`);
check(line(idle, at(idle, 11 * 3600 + 5), RU)?.text === "4 свободно: раунд устарел — последнее решение 11 ч назад, раунды каждые 5 мин", "stale in Russian, hours");
check(line(cap12, at(cap12, 3600))?.text === "11 idle: round stale — last decision 60 min ago, rounds every 5 min", "a stale ALLOW with idle slots is stale too: its dispatch is no longer news");
check(line(idle, at(idle, 90))?.text.startsWith("4 idle: nothing to choose") && line(idle, at(idle, -30)) !== null, "a tick a little in the future (clock skew) is fresh, not negative");

// 4. missing or malformed skipSummary: the refusal alone, no fabricated zeros
const without = (mutate) => { const s = clone(idle); mutate(s); return line(s, at(s, 60)); };
const bare = "4 idle: nothing to choose";
for (const [label, mutate] of [
  ["absent", (s) => { delete s.lastTick.skipSummary; }],
  ["null", (s) => { s.lastTick.skipSummary = null; }],
  ["a string", (s) => { s.lastTick.skipSummary = "449 missing"; }],
  ["an array", (s) => { s.lastTick.skipSummary = [449, 12, 27]; }],
  ["a count as text", (s) => { s.lastTick.skipSummary.claimed.count = "12"; }],
  ["a negative count", (s) => { s.lastTick.skipSummary.missingBoundary.count = -1; }],
  ["a fractional count", (s) => { s.lastTick.skipSummary.completed.count = 27.5; }],
  ["an entry without count", (s) => { s.lastTick.skipSummary.claimed = { issues: [1] }; }],
  ["a count above skippedCount", (s) => { s.lastTick.skipSummary.missingBoundary.count = 489; }],
  ["empty", (s) => { s.lastTick.skipSummary = {}; }],
  ["all zero", (s) => { s.lastTick.skipSummary = { claimed: { count: 0, issues: [], more: 0 } }; }],
]) {
  const got = without(mutate);
  check(got?.text === bare && got.tail === null && got.example === true, `skipSummary ${label}: "${bare}" and nothing about reasons (got "${got?.text}")`);
}
check(without((s) => { delete s.lastTick.skippedCount; })?.text === "4 idle: nothing to choose — 449 issues lack a ## Boundary, 27 done but open, 12 claimed", "no skippedCount: the counts stand, no 'of N' is invented");
check(skipCounts({ claimed: 17, missingBoundary: 2 }, 33)?.map((r) => `${r.key}=${r.count}`).join(",") === "claimed=17,missingBoundary=2", "the older wire shape (bare numbers) reads as the same counts, in wire order");
check(skipCounts(idle.lastTick.skipSummary, 488)?.map((r) => r.count).join(",") === "12,27,449" && skipCounts(undefined) === null && skipCounts({ x: { count: 1 } }, 0) === null, "skipCounts: wire order; absent or contradictory is null");
const many = clone(idle);
many.lastTick.skipSummary = { notFirst: { count: 3 }, claimed: { count: 40 }, other: { count: 0 }, fileConflict: { count: 40 }, oddNewReason: { count: 41 } };
check(line(many, at(many, 60))?.tail === "41 of 488 issues odd new reason, 40 claimed, 40 touch held files", `only the three largest, ties in wire order, an unknown key spaced not invented (got "${line(many, at(many, 60))?.tail}")`);

// 5. other refusals: the refusal text itself, no reasons, no example
const refusing = (refusal, workers) => { const s = clone(idle); s.lastTick.refusal = refusal; if (workers) s.workers = { ...s.workers, ...workers }; return line(s, at(s, 60)); };
check(refusing("no registry mirror published yet")?.text === "4 idle: no registry mirror published yet", "no registry mirror: verbatim");
const capacity = refusing("4 workers already running (limit 4)", { capacity: 12, active: 4 });
check(capacity?.text === "8 idle: 4 workers already running (limit 4)" && capacity.tail === null && capacity.example === false, `the policy limit under a larger capacity: verbatim, eight slots idle (got "${capacity?.text}")`);
const s1 = clone(idle); s1.lastTick.refusal = "daily cap reached: $20.00 of $20.00";
check(line(s1, at(s1, 60), RU)?.text === "4 свободно: daily cap reached: $20.00 of $20.00", "the daily cap in Russian: the wire's words, not a translation guessed from them");

// 6. nothing to explain, or nothing trustworthy to explain it with
const gate = (mutate) => { const s = clone(idle); mutate(s); return line(s, at(idle, 60)); };
for (const [label, value] of [
  ["null status", line(null, 0)], ["a string status", line("ok", 0)], ["an empty object", line({}, 0)],
  ["no lastTick", gate((s) => { s.lastTick = null; })],
  ["an undatable decidedAt", gate((s) => { s.lastTick.decidedAt = "yesterday"; })],
  ["allowed not a boolean", gate((s) => { s.lastTick.allowed = "false"; })],
  ["a refusal of null", gate((s) => { s.lastTick.refusal = null; })],
  ["an empty refusal", gate((s) => { s.lastTick.refusal = "  "; })],
  ["the scheduler off", gate((s) => { s.scheduler.enabled = false; })],
  ["no interval", gate((s) => { s.scheduler.intervalSeconds = 0; })],
  ["no workers", gate((s) => { delete s.workers; })],
  ["workers as text", gate((s) => { s.workers.capacity = "4"; })],
  ["every slot busy", gate((s) => { s.workers.active = 4; })],
  ["no capacity", gate((s) => { s.workers = { capacity: 0, active: 0, idle: 0, utilization: 0 }; })],
]) check(value === null, `${label}: no line`);

// 7. the page uses the reader, and says what "ready" counted
const src = readFileSync(new URL("../src/pages/Queen.tsx", import.meta.url), "utf8");
check(/idleReason\(data, now \+ \(state\.offsetMs \?\? 0\)\)/.test(src) && /idleLine\(/.test(src), "Queen.tsx reads the idle reason from the status it already fetched, on the server's clock");
check(/className="queen27-hud-idle"/.test(src) && /href="https:\/\/github\.com\/gHashTag\/t27\/issues\/3587"/.test(src), "the line has its own element and links the example work order");
check(/idleExample:\s*"example of an issue bees can take"/.test(src) && /idleExample:\s*"пример задачи, которую пчёлы могут взять"/.test(src), "the link is labelled as an example in both languages");
check(/skipCounts\(decision\?\.skipSummary\)/.test(src) && !/skipEntries\.map\(\(\[reason, count\]\)/.test(src), "the round popover lists counts read through skipCounts: the wire's {count, issues, more} objects crashed it (React #31)");
check(/hudNoVerdict:\s*"finished, no verdict"/.test(src) && /hudNoVerdict:\s*"без вердикта"/.test(src) && !/hudReady/.test(src), "dispatches.unreviewed is named for what it counts: finished rows with no verdict, not issues ready");

// self-test: a changed wire number changes the sentence, so the numbers are read, not written
const moved = clone(idle); moved.lastTick.skipSummary.missingBoundary.count = 448;
check(line(moved, at(moved, 60))?.text.includes("448 of 488") && !line(moved, at(moved, 60))?.text.includes("449"), "self-test: 448 in the wire reads 448 on the page");

if (fails.length) { for (const f of fails) console.log("  ✗ " + f); console.log(`Queen idle-reason contract: FAIL (${fails.length} of ${checks})`); process.exit(1); }
console.log(`Queen idle-reason contract: PASS (${checks} checks)`);
