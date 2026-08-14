// The typecheck must not get worse. It is allowed to stay bad.
//
// `npm run build` used to be `tsc -b && vite build`, which was a lie in both
// directions: it never ran in the deploy path (Pages builds from the committed
// bundle), and it did not actually gate anything -- so 231 errors accumulated
// unseen. Among them, seven React branches whose conditions were statically
// false: a whole interactive panel that rendered nothing, in production, for
// as long as the annotation had been wrong.
//
// Deleting the typecheck would lose that signal. Fixing all 221 in one pass
// would be a rewrite. A ratchet keeps the signal and bounds the work: the
// count may fall, never rise. Lower it whenever it falls.
//
// PER FILE, not a total (2026-08-12). A scalar baseline passes when one file is
// fixed and another breaks by the same amount, which is exactly the shape of a
// refactor that silently trades one bug for another. The counts are per file and
// the check is per file; `--update` rewrites them after a genuine fix.
//
// Two vacuous-pass guards, because this project has been burned by a harness
// reporting its own breakage as data: zero errors is only evidence when tsc
// actually produced output, and only when that output parsed as diagnostics.
//
//   node scripts/typecheck-ratchet.mjs             check
//   node scripts/typecheck-ratchet.mjs --update    rewrite the baseline
//   node scripts/typecheck-ratchet.mjs --selftest  prove the gate can fail
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASELINE = join(HERE, '..', 'typecheck-baseline.json');
const LINE = /^(.+?)\(\d+,\d+\): error TS\d+:/;

const total = (c) => Object.values(c).reduce((a, b) => a + b, 0);

function compare(base, now) {
  const worse = [], better = [];
  for (const f of new Set([...Object.keys(base), ...Object.keys(now)])) {
    const b = base[f] ?? 0, n = now[f] ?? 0;
    if (n > b) worse.push({ file: f, was: b, now: n });
    else if (n < b) better.push({ file: f, was: b, now: n });
  }
  return { worse, better };
}

if (process.argv.includes('--selftest')) {
  // A gate nobody has watched fail is a gate whose behaviour nobody knows.
  const base = { 'a.ts': 3, 'b.ts': 1 };
  const cases = [
    ['unchanged', { 'a.ts': 3, 'b.ts': 1 }, false],
    ['one file worse', { 'a.ts': 4, 'b.ts': 1 }, true],
    ['a newly dirty file', { 'a.ts': 3, 'b.ts': 1, 'c.ts': 1 }, true],
    ['fixed one, broke another — a total would net this out', { 'a.ts': 1, 'b.ts': 3 }, true],
    ['all fixed', {}, false],
  ];
  let bad = 0;
  for (const [name, now, want] of cases) {
    const got = compare(base, now).worse.length > 0;
    if (got !== want) bad++;
    console.log(`  ${got === want ? 'ok  ' : 'FAIL'}  ${name}: fails=${got}, expected=${want}`);
  }
  console.log(bad ? `\n  ${bad} self-test(s) failed` : '\n  the gate fails when it should');
  process.exit(bad ? 1 : 0);
}

let out = '';
try { out = execSync('npx tsc -b --pretty false --force', { cwd: join(HERE, '..'), encoding: 'utf8' }); }
catch (e) { out = (e.stdout || '') + (e.stderr || ''); }

const counts = {};
let parsed = 0;
for (const ln of out.split('\n')) {
  const m = LINE.exec(ln.trim());
  if (!m) continue;
  parsed++;
  counts[m[1]] = (counts[m[1]] ?? 0) + 1;
}

// Zero is a pass only when tsc ran. No output at all means it did not.
const raw = (out.match(/error TS\d+/g) || []).length;
if (!out.trim()) {
  console.error('  tsc produced no output at all — it did not run. Refusing to call that zero errors.');
  process.exit(2);
}
if (raw !== parsed) {
  console.error(`  tsc reported ${raw} error(s) but only ${parsed} line(s) parsed as diagnostics.`);
  console.error('  The parser and the compiler disagree; refusing to pass on a count I cannot attribute.');
  process.exit(2);
}

if (process.argv.includes('--update') || !existsSync(BASELINE)) {
  writeFileSync(BASELINE, `${JSON.stringify({
    note: 'Pre-existing tsc errors per file. This file may only shrink. '
      + 'Run `npm run typecheck:update` after fixing some.',
    total: total(counts),
    files: Object.fromEntries(Object.entries(counts).sort()),
  }, null, 2)}\n`);
  console.log(`  baseline written: ${total(counts)} error(s) across ${Object.keys(counts).length} file(s)`);
  process.exit(0);
}

const base = JSON.parse(readFileSync(BASELINE, 'utf8')).files;
const { worse, better } = compare(base, counts);
console.log(`  ${total(counts)} errors across ${Object.keys(counts).length} files; baseline ${total(base)} across ${Object.keys(base).length}.`);

if (better.length) {
  console.log(`  ${better.length} file(s) improved — run \`npm run typecheck:update\` to lock it in:`);
  for (const b of better.slice(0, 10)) console.log(`    ${b.file}: ${b.was} -> ${b.now}`);
}
if (!worse.length) {
  console.log('  no file gained type errors.');
  process.exit(0);
}
console.error(`\n  ${worse.length} file(s) gained type errors:`);
for (const w of worse.sort((a, b) => (b.now - b.was) - (a.now - a.was))) {
  console.error(`    ${w.file}: ${w.was} -> ${w.now}`);
}
process.exit(1);
