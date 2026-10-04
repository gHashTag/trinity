// What --sync writes into specs/catalog/onboarding.t27, and what it leaves for a person.
//
// The world scan rebuilds public/t27/manifest.json every night and the corpus moves almost
// every day, so the counts the onboarding spec states go stale and check:onboarding stops the
// scan. --sync writes the manifest's counts into the spec before the gate runs. These tests hold
// the four things that make that safe: a matching manifest changes nothing, a moved corpus is
// written and dated and then passes the same gate, a value the declared type cannot hold is
// refused, and what the sync does not own (BACKENDS) still stops the gate.
//
//   node --test scripts/onboarding-from-spec.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, loadCompiler } from './agents-from-specs.mjs'
import { ONBOARDING_SPEC, buildOnboarding, syncSpecCounts } from './onboarding-from-spec.mjs'

const wasmBytes = readFileSync(join(SITE, 'public/t27/t27_compiler.wasm'))
const analyze = await loadCompiler(wasmBytes)
const { instance } = await WebAssembly.instantiate(wasmBytes, {})
const shippedExports = Object.keys(instance.exports)
const spec = readFileSync(join(SITE, ONBOARDING_SPEC), 'utf8')
const manifest = JSON.parse(readFileSync(join(SITE, 'public/t27/manifest.json'), 'utf8'))

// The corpus grew by one healthy spec of 40 lines: the shape of an ordinary night.
const grown = () => {
  const m = structuredClone(manifest)
  m.specs.push({ ...structuredClone(m.specs.find((s) => s.health === 'ok')), path: 'specs/sync_probe.t27' })
  m.specCount += 1
  m.totalLines += 40
  m.health.ok += 1
  return m
}

test('the committed spec and manifest agree, so --sync changes nothing', async () => {
  const { text, changed } = syncSpecCounts(spec, manifest, '2099-12-31')
  assert.deepEqual(changed, [])
  assert.equal(text, spec, 'not even MEASURED_AT moves when no count did')
  const out = await buildOnboarding({ specText: text, analyze, shippedExports, manifest })
  assert.deepEqual(out.problems, [])
})

test('a moved corpus fails the gate, and after --sync the same gate passes', async () => {
  const m = grown()
  const before = await buildOnboarding({ specText: spec, analyze, shippedExports, manifest: m })
  assert.ok(before.problems.some((p) => p.includes('SPEC_COUNT says')), 'the stale spec is refused')
  const { text, changed } = syncSpecCounts(spec, m, '2099-12-31')
  assert.deepEqual(changed.map(([k]) => k).sort(), ['HEALTH_OK', 'SPEC_COUNT', 'SPEC_LINES'])
  assert.match(text, /^pub const MEASURED_AT : str = "2099-12-31";/m)
  const after = await buildOnboarding({ specText: text, analyze, shippedExports, manifest: m })
  assert.deepEqual(after.problems, [], 'the synced spec passes the gate it failed, own tests included')
})

test('a count its declared type cannot hold is refused, not truncated', () => {
  const m = structuredClone(manifest)
  m.repos = Array.from({ length: 256 }, (_, i) => ({ name: `r${i}` }))
  assert.throws(() => syncSpecCounts(spec, m, '2099-12-31'), /REPO_COUNT = 256 does not fit its declared u8/)
})

test('a new backend is not the sync\'s to name: BACKENDS still stops the gate', async () => {
  const m = grown()
  m.specs[0] = { ...m.specs[0], outBytes: { ...(m.specs[0].outBytes ?? {}), wgsl: 1 } }
  const { text } = syncSpecCounts(spec, m, '2099-12-31')
  const out = await buildOnboarding({ specText: text, analyze, shippedExports, manifest: m })
  assert.ok(out.problems.some((p) => p.includes('BACKENDS is')), out.problems.join('\n'))
})
