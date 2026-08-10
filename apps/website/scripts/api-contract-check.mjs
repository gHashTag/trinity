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
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

// Every Zig source that emits JSON, not one of them. Comparing against a
// single server file reported 129 missing fields, most of which are emitted
// by a different service -- swarm, DHT and TRI token metrics do not come from
// the consciousness endpoint. "Not emitted" must mean "by anything", or the
// checker manufactures its own findings. See anomaly-register A06.
const SRC = '../../src';
if (!existsSync(SRC)) {
  console.log('  server sources not found — skipping (nothing to compare against)');
  process.exit(0);
}
function zigFiles(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) { if (!/^(\.|zig-out|node_modules)/.test(e.name)) zigFiles(p, out); }
    else if (e.name.endsWith('.zig')) out.push(p);
  }
  return out;
}
const SERVERS = zigFiles(SRC);
// Zig writes escaped quotes inside print strings. A plain "key": pattern
// matches nothing here and reports a false all-clear -- it did, once.
const emitted = new Set();
for (const f of SERVERS)
  for (const m of readFileSync(f, 'utf8').matchAll(/\\"([a-z_][a-z0-9_]*)\\"\s*:/g))
    emitted.add(m[1]);
if (emitted.size === 0) {
  console.error('  0 fields parsed from the server. That is a parser failure, not an empty API.');
  process.exit(1);
}

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
const LIST = process.argv.includes('--list');
if (LIST) {
  for (const [field, where] of [...missing].sort())
    console.log(`    ${field.padEnd(32)} ${[...where].join(', ')}`);
}
if (missing.size > BASELINE) {
  console.error(`\n  ${missing.size} fields read but never emitted, baseline ${BASELINE}:`);
  for (const [field, where] of [...missing].sort())
    console.error(`    ${field.padEnd(32)} ${[...where].join(', ')}`);
  console.error('\n  Either the server should send it, or the UI should stop drawing it.');
  process.exit(1);
}
console.log(`  ${missing.size} read-but-never-emitted — at baseline ${BASELINE}, not worse.`);

// ── Second check: no fallback may be indistinguishable from a measurement ──
//
// A36. getMockMetrics() runs whenever a fetch fails, and the deployed BASE_URL
// is localhost, so on t27.ai it always runs. Unlabelled, `novelty: 0.342`
// renders as a measurement. claim-guard cannot see this: no sentence
// overstates -- a number does, by sitting in a slot that implies measurement.
//
// Every `return mockX()` must be wrapped in sample(), which tags the object so
// SampleBadge can mark it on screen.
const svc = 'src/services/chatApi.ts';
if (existsSync(svc)) {
  const src = readFileSync(svc, 'utf8');
  const bare = [...src.matchAll(/return\s+(mock[A-Za-z]\w*)\s*\(/g)].map(m => m[1]);
  if (bare.length) {
    console.error(`\n  ${bare.length} fallback return(s) not wrapped in sample():`);
    for (const n of [...new Set(bare)]) console.error(`    return ${n}(...)`);
    console.error('\n  A fallback indistinguishable from real data is a claim. Wrap it.');
    process.exit(1);
  }
  console.log('  all service fallbacks tagged as sample data');
}

