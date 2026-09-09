// What the viewport generator refuses, and what it lets through.
//
// The interesting cases are the refusals: a spec whose own `test` block does not
// hold (the analyzer's typecheck.ok stays true for `assert 1 > 2`), a `;` comment
// inside a test block (the parser reads it as a statement, so it must be
// reported, not skipped), a matrix whose declared tiers disagree with the
// bounds, a non-ASCII byte. The vendored spec itself must build, and the two
// emitted files must be a pure function of the spec bytes.
//
//   node --test scripts/viewport-from-spec.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler, sha256 } from './agents-from-specs.mjs'
import { CSS_OUT, TS_OUT, VIEWPORT_SPEC, buildViewport, tierOf } from './viewport-from-spec.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const vendored = readFileSync(join(SITE, VIEWPORT_SPEC), 'utf8')

// Edit the vendored spec's constants by text substitution on one declaration line;
// the result is fed to the real compiler, never parsed here.
const withConst = (src, name, value) => {
  const re = new RegExp(`^(pub const ${name} : [a-z0-9\\[\\]]+ = )[^;]+;`, 'm')
  assert.match(src, re, `${name} is declared once in the spec`)
  return src.replace(re, `$1${value};`)
}

test('the vendored spec builds: clean verdict, tests evaluated, two files rendered', async () => {
  const out = await buildViewport({ specText: vendored, analyze })
  assert.deepEqual(out.problems, [])
  assert.equal(out.verdict.typecheckOk, true)
  assert.ok(out.tests.tests >= 6, `test blocks: ${out.tests.tests}`)
  assert.ok(out.tests.asserts >= 40, `asserts: ${out.tests.asserts}`)
  assert.deepEqual(out.tests.failures, [])
  assert.equal(out.specSha, sha256(Buffer.from(vendored, 'utf8')))
  assert.match(out.ts, new RegExp(`spec sha256 ${out.specSha}`))
  assert.match(out.css, new RegExp(`spec sha256 ${out.specSha}`))
  assert.equal(out.fields.PHONE_MAX, 600)
  assert.equal(out.fields.TABLET_MAX, 1024)
  assert.equal(out.fields.TOUCH_TARGET_MIN_PX, 44)
  assert.equal(out.fields.VIEWPORTS.length, 6)
})

test('the committed generated files are the ones the vendored spec produces', async () => {
  const out = await buildViewport({ specText: vendored, analyze })
  assert.equal(readFileSync(join(SITE, TS_OUT), 'utf8'), out.ts, `${TS_OUT} is stale; run node scripts/viewport-from-spec.mjs`)
  assert.equal(readFileSync(join(SITE, CSS_OUT), 'utf8'), out.css, `${CSS_OUT} is stale; run node scripts/viewport-from-spec.mjs`)
})

test('emission is deterministic: same bytes in, same bytes out', async () => {
  const a = await buildViewport({ specText: vendored, analyze })
  const b = await buildViewport({ specText: vendored, analyze })
  assert.equal(a.ts, b.ts)
  assert.equal(a.css, b.css)
})

test('a false assert in the spec is a build failure even though typecheck.ok stays true', async () => {
  // TOUCH_TARGET_MIN_PX = 40 breaks `assert TOUCH_TARGET_MIN_PX >= 44` and the
  // back-control test; nothing about it is a type error.
  const src = withConst(vendored, 'TOUCH_TARGET_MIN_PX', '40')
  const out = await buildViewport({ specText: src, analyze })
  assert.equal(out.verdict.typecheckOk, true, 'typecheck alone would have passed this')
  assert.ok(out.problems.some((p) => /test .*assert #\d+ is false/.test(p)), out.problems.join('\n'))
  assert.equal(out.ts, null)
})

test('a `;` comment inside a test block is reported, not silently skipped', async () => {
  const src = vendored.replace('test breakpoints_are_monotone {\n', 'test breakpoints_are_monotone {\n    ; this is a comment the parser reads as a statement\n')
  assert.notEqual(src, vendored)
  const out = await buildViewport({ specText: src, analyze })
  assert.ok(out.problems.some((p) => /not an assert/.test(p)), out.problems.join('\n'))
})

test('a matrix tier that disagrees with the bounds is refused', async () => {
  // 600 is PHONE_MAX, so 600x900 is phone; moving PHONE_MAX below it makes the
  // declared VIEWPORT_TIERS wrong and the spec's own tests fail too.
  const src = withConst(vendored, 'PHONE_MAX', '599')
  const out = await buildViewport({ specText: src, analyze })
  assert.ok(out.problems.some((p) => /VIEWPORT_TIERS\[\d+\] says phone, the bounds say tablet/.test(p)), out.problems.join('\n'))
})

test('a non-ASCII byte is refused (L3)', async () => {
  const src = vendored.replace('// SPDX-License-Identifier: Apache-2.0', '// SPDX-License-Identifier: Apache-2.0 \u2014 nope')
  assert.notEqual(src, vendored)
  const out = await buildViewport({ specText: src, analyze })
  assert.ok(out.problems.some((p) => /non-ASCII/.test(p)), out.problems.join('\n'))
})

test('tierOf follows the inclusive bounds', () => {
  const f = { PHONE_MAX: 600, TABLET_MAX: 1024, DESKTOP_MAX: 1600 }
  assert.equal(tierOf(390, f), 'phone')
  assert.equal(tierOf(600, f), 'phone')
  assert.equal(tierOf(601, f), 'tablet')
  assert.equal(tierOf(1024, f), 'tablet')
  assert.equal(tierOf(1025, f), 'desktop')
  assert.equal(tierOf(1600, f), 'desktop')
  assert.equal(tierOf(1601, f), 'wide')
})
