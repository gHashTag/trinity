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
// Vacuous-pass guards, because this project has been burned by a harness
// reporting its own breakage as data: zero errors is only evidence when tsc
// actually produced output, and only when that output parsed as diagnostics.
//
// And the compiler must be the one this package declares (2026-10-04). This
// used to run `npx tsc`. In a checkout without node_modules, npx resolves `tsc`
// to the unrelated npm package of that name, which prints a banner ("This is
// not the tsc command you are looking for") and no diagnostics. The banner was
// output, so the no-output guard let it through, and the ratchet reported
// "0 errors across 0 files", 26 files improved, run typecheck:update -- which
// would have locked in a zero baseline from a compiler that never ran.
//
//   node scripts/typecheck-ratchet.mjs             check
//   node scripts/typecheck-ratchet.mjs --update    rewrite the baseline
//   node scripts/typecheck-ratchet.mjs --selftest  prove the gate can fail
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASELINE = join(HERE, '..', 'typecheck-baseline.json');
const LINE = /^(.+?)\(\d+,\d+\): error TS\d+:/;

const total = (c) => Object.values(c).reduce((a, b) => a + b, 0);

// The tsc of the typescript this package depends on, found the way Node finds
// an import from `dir`. Null when it is not installed -- never a stand-in.
function localTsc(dir) {
  try {
    const pkg = createRequire(join(dir, 'package.json')).resolve('typescript/package.json');
    return join(dirname(pkg), 'bin', 'tsc');
  } catch {
    return null;
  }
}

// Per-file error counts from what the compiler printed, or the reason that
// output cannot be counted. Kept apart from the run so --selftest can feed it
// the outputs that have fooled this gate.
function readTsc(out) {
  const counts = {};
  let parsed = 0;
  for (const ln of out.split('\n')) {
    const m = LINE.exec(ln.trim());
    if (!m) continue;
    parsed++;
    counts[m[1]] = (counts[m[1]] ?? 0) + 1;
  }
  const raw = (out.match(/error TS\d+/g) || []).length;
  if (!out.trim()) {
    return { refuse: 'tsc produced no output at all — it did not run. Refusing to call that zero errors.' };
  }
  if (raw !== parsed) {
    return { refuse: `tsc reported ${raw} error(s) but only ${parsed} line(s) parsed as diagnostics.\n`
      + '  The parser and the compiler disagree; refusing to pass on a count I cannot attribute.' };
  }
  // A clean tsc -b prints nothing, so output without a single diagnostic came
  // from something else.
  const noDiagnostics = parsed === 0;
  if (noDiagnostics) {
    return { refuse: 'the compiler printed output but not one diagnostic, so it was not tsc:\n'
      + `    ${out.trim().split('\n')[0].slice(0, 120)}\n  Refusing to call that zero errors.` };
  }
  return { counts };
}

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

  // The compiler's output, including the banner that once passed as zero
  // errors (captured from `npx tsc` in a checkout without node_modules).
  const FAKE_TSC = '\n\x1b[41m\x1b[37m                This is not the tsc command you are looking for                \x1b[0m\n\n'
    + 'To get access to the TypeScript compiler, \x1b[34mtsc\x1b[0m, from the command line either:\n';
  const REAL_TSC = "src/a.tsx(3,7): error TS2322: Type 'string' is not assignable to type 'number'.\n"
    + "src/a.tsx(9,1): error TS2304: Cannot find name 'b'.\n"
    + "src/c.ts(1,10): error TS2305: Module './d' has no exported member 'e'.\n";
  const outputs = [
    ['the npm package named tsc, which npx runs when typescript is absent', FAKE_TSC, null],
    ['no output at all', '', null],
    ["an error tsc could not attribute to a file", "error TS5083: Cannot read file 'tsconfig.json'.\n", null],
    ['real diagnostics in two files', REAL_TSC, { 'src/a.tsx': 2, 'src/c.ts': 1 }],
  ];
  for (const [name, out, want] of outputs) {
    const r = readTsc(out);
    const ok = want === null ? Boolean(r.refuse) : !r.refuse && JSON.stringify(r.counts) === JSON.stringify(want);
    if (!ok) bad++;
    console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${name}: ${r.refuse ? 'refused' : JSON.stringify(r.counts)}`);
  }

  // Where typescript is not installed, there is no compiler to run.
  const empty = mkdtempSync(join(tmpdir(), 'ratchet-'));
  const none = localTsc(empty);
  rmSync(empty, { recursive: true });
  if (none !== null) bad++;
  console.log(`  ${none === null ? 'ok  ' : 'FAIL'}  no typescript installed: compiler=${none}`);

  console.log(bad ? `\n  ${bad} self-test(s) failed` : '\n  the gate fails when it should');
  process.exit(bad ? 1 : 0);
}

const tsc = localTsc(join(HERE, '..'));
if (!tsc) {
  console.error('  typescript is not installed here; run `npm ci` first.');
  console.error('  Refusing to count errors from a compiler that is not there.');
  process.exit(2);
}

let out = '';
try {
  out = execFileSync(process.execPath, [tsc, '-b', '--pretty', 'false', '--force'],
    { cwd: join(HERE, '..'), encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
} catch (e) { out = (e.stdout || '') + (e.stderr || ''); }

// Zero is a pass only when tsc ran and said so in diagnostics.
const read = readTsc(out);
if (read.refuse) {
  console.error(`  ${read.refuse}`);
  process.exit(2);
}
const counts = read.counts;

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
