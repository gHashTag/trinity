// Every field the UI reads off an API response must be one the server emits.
//
// Four loops of debugging produced one failure shape, repeatedly: a component
// formats `metrics.some_field` that no interface declares, no mock defines and
// no server sends. It renders blank, or throws when a method is called on the
// undefined. `vite build` is green throughout, and `tsc` reports it as TS2339
// among 180 others -- true, but buried.
//
// The right check is a render check: build, open /canvas, expand every panel,
// fail on the first console error. That needs a headless browser, which this
// repo does not have and which is a separate decision. This is the cheap
// static half: it catches the same class in a second, with no dependency.
//
//   node scripts/api-contract-check.mjs
//
// It compares field names only. It cannot see units, nesting depth or whether
// a value means what the label says -- see anomaly-register A34, where five
// fields DO have a server counterpart and wiring them would have relabelled a
// dimensionless score as microseconds.
//
// Three checks live here now, and the third (the Inngest status wire) reads a
// different server in a different language. They share one home because they
// share one failure: the UI and the server disagree about a field, and every
// other instrument in the build is green while they do.
//
//   node --experimental-strip-types scripts/api-contract-check.mjs
//   ... --list        name every read-but-never-emitted field
//   ... --self-test   prove the wire check can fail, then run it
//   ... --live        refetch the live status endpoint and diff its shape
//   ... --record      rewrite the recorded body from the live one
import { readFileSync, readdirSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// A failing check must not hide the checks after it. The first version of this
// file exited on the first finding AND exited 0 when the Zig tree was absent,
// so adding a second server's check below the first would have made it
// unreachable from apps/website alone -- a gate that is skipped is a gate that
// does not exist, which is the whole subject of anomaly-register A48.
let failed = false;
const fail = (msg) => { console.error(msg); failed = true; };

// Every Zig source that emits JSON, not one of them. Comparing against a
// single server file reported 129 missing fields, most of which are emitted
// by a different service -- swarm, DHT and TRI token metrics do not come from
// the consciousness endpoint. "Not emitted" must mean "by anything", or the
// checker manufactures its own findings. See anomaly-register A06.
const SRC = '../../src';
function zigFiles(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) { if (!/^(\.|zig-out|node_modules)/.test(e.name)) zigFiles(p, out); }
    else if (e.name.endsWith('.zig')) out.push(p);
  }
  return out;
}
const LIST = process.argv.includes('--list');
if (!existsSync(SRC)) {
  console.log('  server sources not found — skipping the Zig field check (nothing to compare against)');
} else {
  const SERVERS = zigFiles(SRC);
  // Zig writes escaped quotes inside print strings. A plain "key": pattern
  // matches nothing here and reports a false all-clear -- it did, once.
  const emitted = new Set();
  for (const f of SERVERS)
    for (const m of readFileSync(f, 'utf8').matchAll(/\\"([a-z_][a-z0-9_]*)\\"\s*:/g))
      emitted.add(m[1]);
  if (emitted.size === 0) {
    fail('  0 fields parsed from the server. That is a parser failure, not an empty API.');
  } else {
    // Fields the UI reads off a *metrics* object, i.e. the ones the server owns.
    const READ = /\b(\w*[Mm]etrics)\.([a-z_][a-z0-9_]*)/g;
    const files = [];
    for (const dir of ['src/pages', 'src/components/sections']) {
      if (existsSync(dir)) for (const f of readdirSync(dir).filter(f => f.endsWith('.tsx')))
        files.push(join(dir, f));
    }
    const missing = new Map();
    for (const f of files) {
      for (const [, , field] of readFileSync(f, 'utf8').matchAll(READ)) {
        if (emitted.has(field)) continue;
        if (!missing.has(field)) missing.set(field, new Set());
        missing.get(field).add(f);
      }
    }

    console.log(`  ${SERVERS.length} zig sources emit ${emitted.size} distinct fields; ${files.length} components read from metrics`);
    const BASELINE = 110;  // 2026-08-10 — measured against all 2216 zig sources; see A33/A34/A35
    if (LIST) {
      for (const [field, where] of [...missing].sort())
        console.log(`    ${field.padEnd(32)} ${[...where].join(', ')}`);
    }
    if (missing.size > BASELINE) {
      fail(`\n  ${missing.size} fields read but never emitted, baseline ${BASELINE}:`);
      for (const [field, where] of [...missing].sort())
        console.error(`    ${field.padEnd(32)} ${[...where].join(', ')}`);
      console.error('\n  Either the server should send it, or the UI should stop drawing it.');
    } else {
      console.log(`  ${missing.size} read-but-never-emitted — at baseline ${BASELINE}, not worse.`);
    }
  }
}

// ── Second check: no fallback may be indistinguishable from a measurement ──
//
// A36. getMockMetrics() runs whenever a fetch fails, and the deployed BASE_URL
// is localhost, so on t27.ai it always runs. Unlabelled, `novelty: 0.342`
// renders as a measurement. claim-guard cannot see this: no sentence
// overstates -- a number does, by sitting in a slot that implies measurement.
//
// The first version of this rule matched `return mockX(` only. The codebase
// names most of them `generateMockX`, so it reported 'all fallbacks tagged'
// while 22 were untagged -- a false all-clear from the checker built to prevent
// exactly this class. Fifth instance of absent-is-not-zero; see A38.
//
// Every `return mockX()` / `return generateMockX()` must be wrapped in sample(),
// SampleBadge can mark it on screen.
const svc = 'src/services/chatApi.ts';
if (existsSync(svc)) {
  const src = readFileSync(svc, 'utf8');
  const bare = [...src.matchAll(/return\s+((?:generate)?[Mm]ock[A-Za-z]\w*)\s*\(/g)].map(m => m[1]);
  if (bare.length) {
    fail(`\n  ${bare.length} fallback return(s) not wrapped in sample():`);
    for (const n of [...new Set(bare)]) console.error(`    return ${n}(...)`);
    console.error('\n  A fallback indistinguishable from real data is a claim. Wrap it.');
  } else {
    console.log('  all service fallbacks tagged as sample data');
  }
}


// -- Third check: the Inngest functions status wire ----------------------
//
// A second API and the mirror-image failure. Not "the UI formats a field no
// server emits", but "the server emits a field the UI's parser throws away".
//
// Measured 2026-09-22 against the live endpoint:
//   lastError  wire sends {runId, endedAt, eventName}, the parser declared
//              `string | null` and narrowed with `typeof v === 'string'`, so
//              it returned null for all 33 functions on every poll. The one
//              field that names a problem was discarded in transit and the
//              page drew an em dash where the failing run id belonged.
//   triggers   wire sends [{type, value}], the parser declared `string[]` and
//              kept only strings, so the list was empty for every function.
//
// Neither is visible at runtime and neither is visible to tsc. The parser's
// input is `unknown` by construction -- it has to be, the body crossed a
// network -- so every narrowing helper typechecks perfectly against a wire it
// has never read. Only a recorded body can settle it.
//
// The check runs the site's REAL parser over that body. It does not
// re-implement the shape: a second copy of the shape would drift from the
// first, and a shape drifting from another shape IS the defect.
//
//   wire -> parsed   every non-null value the endpoint sent must survive the
//                    trip with an equal value, arrays element by element
//   parsed -> wire   every key the parser declares must exist on the wire, so
//                    a field that can never arrive cannot be quietly carried
//   parsed -> page   every field that survives must be drawn somewhere, or be
//                    listed below WITH the reason it is deliberately not
//
// The fixture is the live 200 of 2026-09-22T16:30Z, 33 functions, verbatim
// except source.gqlUrl: that is the bot's private-network address and this
// repo is public, so it is stored REDACTED. Its value is never read, only its
// presence and its type.
const HERE = dirname(fileURLToPath(import.meta.url));
const WIRE_DIR = join(HERE, '..', 'qa', 'fixtures', 'inngest-functions-status');
const WIRE_FIXTURE = join(WIRE_DIR, 'live-2026-09-22T1630Z.json');
const STATUS_ENDPOINT = 'https://999-multibots-telegraf-production-2008.up.railway.app/api/inngest/functions/status';
const PAGE = join(HERE, '..', 'src', 'pages', 'FunctionExplorer.tsx');

// Keys the parser owns rather than receives, and keys it receives but must not
// republish. Anything not listed here has to arrive from the wire AND reach
// the page; an entry added here is a decision that has to carry its reason.
const DERIVED = new Map([
  ['byId', 'an index over functions[], built after parsing so the page can join a manifest card to its live record'],
]);
const NOT_DRAWN = new Map([
  ['id', 'the join key between a manifest card and its live record, not a value to print'],
  ['control', 'a constant: the endpoint filters the manifest to spec+code before building, so a column could only ever show one value'],
  ['source.gqlUrl', "the bot's private-network address; parsed so the shape is accounted for, never republished on a public page"],
]);

const typeOf = (v) => (v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v);
const show = (v) => (typeof v === 'string' && v.length > 40 ? JSON.stringify(v.slice(0, 37) + '...') : JSON.stringify(v));

/** Every non-null leaf the endpoint sent must come out of the parser unchanged. */
function carried(wire, parsed, path, problems) {
  for (const [k, v] of Object.entries(wire)) {
    const at = path ? `${path}.${k}` : k;
    // Absence is carried as null by design ("anything the endpoint did not
    // send is null, not zero"), so a null on the wire proves nothing.
    if (v === null || v === undefined) continue;
    const got = parsed === null || typeof parsed !== 'object' ? undefined : parsed[k];
    if (Array.isArray(v)) {
      if (!Array.isArray(got)) { problems.push(`${at}: wire sends an array of ${v.length}, the parser produced ${typeOf(got)}`); continue; }
      if (got.length !== v.length) { problems.push(`${at}: wire sends ${v.length} item(s), the parser kept ${got.length}`); continue; }
      v.forEach((item, i) => {
        if (item !== null && typeof item === 'object') carried(item, got[i], `${at}[${i}]`, problems);
        else if (got[i] !== item) problems.push(`${at}[${i}]: wire sends ${show(item)}, the parser produced ${show(got[i] ?? null)}`);
      });
      continue;
    }
    if (typeof v === 'object') {
      if (got === null || typeof got !== 'object') { problems.push(`${at}: wire sends an object, the parser produced ${typeOf(got)}`); continue; }
      carried(v, got, at, problems);
      continue;
    }
    if (got !== v) problems.push(`${at}: wire sends ${show(v)}, the parser produced ${show(got === undefined ? null : got)}`);
  }
}

/** Every key the parser declares must be a key the endpoint can actually send. */
function declared(parsed, wire, path, problems) {
  if (parsed === null || typeof parsed !== 'object' || parsed instanceof Map) return;
  for (const [k, v] of Object.entries(parsed)) {
    const at = path ? `${path}.${k}` : k;
    if (DERIVED.has(k)) continue;
    if (wire === null || typeof wire !== 'object' || !(k in wire)) {
      problems.push(`${at}: the parser declares it, the endpoint never sends it`);
      continue;
    }
    if (Array.isArray(v) && Array.isArray(wire[k])) v.forEach((item, i) => declared(item, wire[k][i], `${at}[${i}]`, problems));
    else if (v !== null && typeof v === 'object') declared(v, wire[k], at, problems);
  }
}

/** Fields that survive the parser and then reach nobody are a slower version of the same loss. */
function drawn(source, problems) {
  const check = (label, re, why) => { if (!re.test(source)) problems.push(`${label}: ${why}`); };
  const fnKeys = ['slug', 'name', 'domain', 'triggers', 'deployed', 'runs24h', 'runs7d', 'lastRun', 'lastProbe', 'probeExpect', 'lastError'];
  for (const k of fnKeys)
    check(`functions[].${k}`, new RegExp(`selectedLive\\??\\.${k}\\b`), 'parsed off the wire and never read by the page');
  // runs24h is summed fleet-wide through totalRuns(); the per-function panel
  // prints the 7 d window, so that is where all six counters have to appear.
  for (const c of ['completed', 'failed', 'running', 'cancelled', 'invoked', 'total'])
    check(`runs7d.${c}`, new RegExp(`runs7d\\.${c}\\b`), 'counter parsed and never printed');
  for (const p of ['generatedAt', 'source.cached', 'app.name', 'app.sdk', 'app.url', 'app.connected', 'unknownInApp'])
    check(p, new RegExp(`live\\.status\\.${p.replace(/\./g, '\\.')}\\b`), 'parsed off the wire and never read by the page');
  // functions[] is never indexed directly: the page joins each manifest card
  // to its record through byId, and sums the fleet through totalRuns().
  check('functions', /live\.status\.byId\b/, 'the array is parsed and its index is never used to join a card to its record');
  check('functions (fleet)', /totalRuns\(live\.status/, 'nothing sums the fleet, so the counters are per-function only');
}

if (!existsSync(WIRE_FIXTURE)) {
  fail(`\n  recorded status body missing: ${WIRE_FIXTURE}`);
  console.error('  Re-record it with --record. A wire check with no wire is not a check.');
} else {
  const { parseFunctionsStatus, parseStatusError } = await import('../src/lib/functionsStatus.ts');
  let wire = JSON.parse(readFileSync(WIRE_FIXTURE, 'utf8'));

  if (process.argv.includes('--live') || process.argv.includes('--record')) {
    const r = await fetch(STATUS_ENDPOINT, { headers: { accept: 'application/json' } });
    const live = await r.json();
    const shape = (o, p = '') => (o === null || typeof o !== 'object' ? [] : Object.entries(o).flatMap(([k, v]) => [p + k, ...shape(Array.isArray(v) ? v[0] : v, `${p}${k}.`)]));
    const a = new Set(shape(wire)), b = new Set(shape(live));
    for (const k of b) if (!a.has(k)) console.log(`  live: NEW key not in the recording: ${k}`);
    for (const k of a) if (!b.has(k)) console.log(`  live: key gone from the endpoint: ${k}`);
    if (process.argv.includes('--record')) {
      live.source.gqlUrl = 'http://REDACTED.railway.internal:8288/v0/gql';
      mkdirSync(WIRE_DIR, { recursive: true });
      writeFileSync(WIRE_FIXTURE, JSON.stringify(live, null, 2) + '\n');
      console.log(`  recorded ${live.functions?.length ?? 0} functions to ${WIRE_FIXTURE}`);
      wire = live;
    }
  }

  // A gate nobody has watched fail is not trusted on the day it matters. This
  // replays the two defects the check was written for -- an emptied trigger
  // list and a lastError coerced to null -- and requires both to be reported.
  if (process.argv.includes('--self-test')) {
    const hurt = parseFunctionsStatus(wire);
    // Break the two fields on functions that actually carry them today: a
    // self-test that empties an already-empty list proves nothing, and that is
    // how a gate ends up green over the bug it was written for.
    const ti = wire.functions.findIndex((f) => Array.isArray(f.triggers) && f.triggers.length > 0);
    const ei = wire.functions.findIndex((f) => f.lastError !== null && f.lastError !== undefined);
    if (ti < 0 || ei < 0) fail(`  --self-test: the recording carries no triggers (${ti}) or no lastError (${ei}); re-record before trusting this`);
    hurt.functions[ti].triggers = [];
    hurt.functions[ei].lastError = null;
    const seen = [];
    carried(wire, hurt, '', seen);
    const wantsTriggers = seen.some((p) => p.includes(`functions[${ti}].triggers`));
    const wantsError = seen.some((p) => p.includes(`functions[${ei}].lastError`));
    if (!wantsTriggers || !wantsError) fail(`  --self-test: the wire check did NOT report the historic defects (triggers:${wantsTriggers} lastError:${wantsError})`);
    else console.log(`  --self-test: the wire check reports both historic defects (${seen.length} findings on a deliberately broken parse)`);
  }

  const parsed = parseFunctionsStatus(wire);
  if (!parsed) {
    fail('  the recorded body does not parse at all. The endpoint changed shape, or the parser broke.');
  } else {
    const problems = [];
    carried(wire, parsed, '', problems);
    declared(parsed, wire, '', problems);
    drawn(readFileSync(PAGE, 'utf8'), problems);
    // The 503 carries a different shape and `detail` is the only text naming
    // why Inngest was unreachable; reading the status line alone threw it away.
    // Transcribed from the bot's routes/inngestStatus.ts, not observed live.
    if (typeof parseStatusError !== 'function') {
      problems.push('503 body: functionsStatus.ts exports no parseStatusError, so `detail` has nowhere to go');
    } else {
      const detail = parseStatusError({ generatedAt: '2026-09-22T00:00:00.000Z', error: 'inngest-unreachable', detail: 'fetch failed', gqlUrl: 'http://REDACTED' });
      if (!detail || !detail.includes('fetch failed')) problems.push(`503 body: detail is dropped, parseStatusError returned ${show(detail)}`);
    }

    if (problems.length) {
      fail(`\n  ${problems.length} wire/parser disagreement(s) on ${STATUS_ENDPOINT}:`);
      for (const p of problems.slice(0, 40)) console.error(`    ${p}`);
      if (problems.length > 40) console.error(`    ... ${problems.length - 40} more`);
      console.error('\n  A field declared at the wrong type is not a cosmetic error: it is silent data loss.');
      console.error('  Fix src/lib/functionsStatus.ts, or --record a body if the endpoint really changed.');
      for (const [k, why] of NOT_DRAWN) console.error(`  (deliberately not drawn: ${k} -- ${why})`);
    } else {
      console.log(`  inngest status: ${parsed.functions.length} functions, every wire value survives the parser and reaches the page`);
    }
  }
}

process.exit(failed ? 1 : 0);
