// Does every ARIA reference point at something that exists?
//
// `aria-controls`, `aria-labelledby` and `aria-describedby` are ID references.
// A reference to an id nobody declares is not a warning — assistive technology
// follows it, finds nothing, and the control silently loses its relationship.
// Nothing in a build catches it: the JSX is valid, the page renders, the visual
// result is identical.
//
// It happened here. The hamburger declared aria-controls="mobile-menu" while the
// menu carried only a className, so a screen reader following the reference found
// no menu. That shipped, and was found by a browser sweep that only looks at
// triggers visible on the pages it happens to visit — which is most of them,
// but not the ones behind a route or a state the sweep never reaches.
//
// This is the cheap half: no browser, no build, no server, so it can run on
// every push and cover every file.
//
//   node scripts/aria-refs-check.mjs
//
// Dynamic ids — `id={`lang-option-${l}`}` — are matched by prefix, because the
// suffix is only known at runtime. A reference built the same way is accepted if
// some declaration shares its literal prefix; that is weaker than an exact match
// and it is the honest limit of a static check.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = new URL('../src/', import.meta.url).pathname;
const REF_ATTRS = ['aria-controls', 'aria-labelledby', 'aria-describedby'];

const files = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(tsx|ts)$/.test(p)) files.push(p);
  }
})(ROOT);

const declared = new Set();
const dynamicPrefixes = [];
const refs = [];

for (const p of files) {
  const src = readFileSync(p, 'utf8');
  const rel = relative(ROOT, p);

  for (const m of src.matchAll(/\bid="([^"]+)"/g)) declared.add(m[1]);
  for (const m of src.matchAll(/\bid=\{`([^`$]*)\$/g)) dynamicPrefixes.push(m[1]);

  for (const attr of REF_ATTRS) {
    // literal only: a reference built from a template shares the dynamic-prefix
    // treatment below and cannot be checked exactly.
    for (const m of src.matchAll(new RegExp(`\\b${attr}="([^"]+)"`, 'g'))) {
      for (const id of m[1].trim().split(/\s+/)) refs.push({ attr, id, rel });
    }
    for (const m of src.matchAll(new RegExp(`\\b${attr}=\\{\`([^\`$]*)\\$`, 'g'))) {
      refs.push({ attr, id: m[1], rel, dynamic: true });
    }
  }
}

const resolves = ({ id, dynamic }) =>
  declared.has(id) ||
  dynamicPrefixes.some(p => (dynamic ? p === id : id.startsWith(p)));

const broken = refs.filter(r => !resolves(r));
const seen = new Set();
const unique = broken.filter(r => {
  const k = `${r.attr}=${r.id}`;
  if (seen.has(k)) return false;
  seen.add(k);
  return true;
});

console.log(`  ${files.length} source file(s), ${declared.size} declared id(s), ` +
            `${dynamicPrefixes.length} dynamic id pattern(s), ${refs.length} ARIA reference(s)`);

if (unique.length) {
  console.error('\n  ARIA references that point at nothing:\n');
  for (const r of unique) console.error(`    ${r.rel}: ${r.attr}="${r.id}"`);
  console.error('\n  Assistive technology follows these and finds no element. Either declare');
  console.error('  the id on the target, or drop the attribute — a dangling reference is');
  console.error('  worse than none, because it asserts a relationship that is not there.');
  process.exit(1);
}

console.log('  every ARIA reference resolves to a declared id.');
