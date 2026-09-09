// What the spec→catalog generator refuses, and what it lets through.
//
// The interesting cases are the failures: two specs claiming one ID, a cron
// whose RUNS names a skill that has no spec, a spec with no code behind it, a
// spec the compiler does not accept. And the two quirks the generator leans
// on -- array literals arriving as identifiers and UTF-8 arriving as bytes --
// are pinned here against the REAL wasm so a compiler update that changes
// either shape fails loudly instead of shipping mojibake.
//
//   node --test scripts/agents-from-specs.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import {
  SITE, analyzeSpecFiles, buildSpecCatalogs, constsOf, decodeBytes, loadCompiler, runNowTarget, sortKeys, verdictOf,
} from './agents-from-specs.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))

const q = JSON.stringify
const skillSrc = (id, { module = 'skill_x', specs = [], extra = '' } = {}) => `module ${module};
pub const KIND : str = "skill";
pub const ID : str = ${q(id)};
pub const NAME : str = "x";
pub const REPO : str = "trinity";
pub const SOURCE : str = "SKILL.md";
pub const SUMMARY_EN : str = "en";
pub const SUMMARY_RU : str = "Проверка ✓ ⟲ ◷";
pub const COMMAND : str = "/x";
pub const SPECS : [${specs.length}]str = ${q(specs)};
pub const TAGS : [1]str = ["t"];
pub const ENABLED : bool = true;
pub const TIMEOUT_MIN : u16 = 30;
${extra}`
const cronSrc = (id, { module = 'cron_x', runs = [], host = 'github-actions', schedule = '"0 0 * * *"', extra = '' } = {}) => `module ${module};
pub const KIND : str = "cron";
pub const ID : str = ${q(id)};
pub const NAME : str = "x";
pub const HOST : str = ${q(host)};
pub const REPO : str = "trinity";
pub const SERVICE : str = ".github/workflows/x.yml";
pub const SUMMARY_EN : str = "en";
pub const SUMMARY_RU : str = "ru";
${host === 'timer' ? 'pub const INTERVAL_MS : u32 = 5000;' : `pub const SCHEDULE : str = ${schedule};`}
pub const TZ : str = "UTC";
pub const RUNS : [${runs.length}]str = ${q(runs)};
pub const RUNS_NOTE : str = "test";
pub const ENABLED : bool = true;
pub const ON_FAILURE : str = "log";
pub const CONTROL : str = "code-only";
${extra}`

const files = (dir, ...srcs) => srcs.map((text, i) => ({ path: `${dir}/x${i}.t27`, text }))
const skillsManifest = { skills: [{ id: 'trinity/x', path: 'trinity/x/SKILL.md', sha256: 'a'.repeat(64), health: 'ok', link: 'unbound' }] }
const cronsManifest = { crons: [{ id: 'github-actions/trinity/x', kind: 'github-actions', schedule: { kind: 'cron', expr: '0 0 * * *' }, where: { file: 'w.yml', line: 1 }, health: 'ok' }] }
const build = (skillSpecs, cronSpecs, over = {}) => buildSpecCatalogs({
  skillSpecs: analyzeSpecFiles(analyze, skillSpecs),
  cronSpecs: analyzeSpecFiles(analyze, cronSpecs),
  skillsManifest, cronsManifest, t27Manifest: { specs: [{ path: 'specs/demos/hello_world.t27' }] },
  compilerWasmSha256: 'w', generatedAt: '2026-01-01T00:00:00.000Z', ...over,
})

test('the compiler accepts the schema, including an empty array, and constants come back typed', () => {
  const a = analyze(skillSrc('trinity/x', { module: 'skill_x0' }))
  const v = verdictOf(a)
  assert.equal(v.typecheckOk, true)
  assert.equal(v.discarded, 0)
  const c = constsOf(a)
  assert.equal(c.ID.value, 'trinity/x')
  assert.deepEqual(c.SPECS.value, [])
  assert.equal(c.ENABLED.value, true)
  assert.equal(c.TIMEOUT_MIN.value, 30)
  assert.equal(c.TIMEOUT_MIN.type, 'u16')
})

test('array literals arrive as identifiers and UTF-8 arrives as bytes; both are undone exactly', () => {
  const a = analyze(skillSrc('trinity/x', { module: 'skill_x0', specs: ['specs/a.t27', 'specs/б.t27'] }))
  const arr = a.ast.children.find((n) => n.name === 'SPECS').children[0]
  assert.equal(arr.kind, 'ExprIdentifier', 'the quirk this generator documents: array literal in an identifier name')
  const c = constsOf(a)
  assert.deepEqual(c.SPECS.value, ['specs/a.t27', 'specs/б.t27'])
  assert.equal(c.SUMMARY_RU.value, 'Проверка ✓ ⟲ ◷')
  assert.equal(decodeBytes('plain ascii'), 'plain ascii')
  assert.equal(decodeBytes('уже верно'), 'уже верно', 'text that is already decoded is left alone')
})

test('a clean pair is spec+code, healthy, with the reverse link filled in', () => {
  const r = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })), files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0', runs: ['trinity/x'] })))
  assert.deepEqual(r.problems, [])
  assert.equal(r.skills.skills[0].witness, 'spec+code')
  assert.equal(r.crons.crons[0].witness, 'spec+code')
  assert.equal(r.crons.crons[0].health, 'ok')
  assert.deepEqual(r.crons.crons[0].runsResolved, [{ id: 'trinity/x', ok: true }])
  assert.deepEqual(r.skills.skills[0].runBy, ['github-actions/trinity/x'])
  assert.deepEqual(r.skills.codeOnly, [])
  assert.equal(r.skills.counts.runBy, 1)
})

test('duplicate IDs fail the build', () => {
  const r = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' }), skillSrc('trinity/x', { module: 'skill_x1' })), [])
  assert.ok(r.problems.some((p) => p.includes('duplicate skill ID trinity/x')), r.problems.join('\n'))
})

test('a RUNS entry with no skill spec marks the cron fail, with a message', () => {
  const r = build([], files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0', runs: ['trinity/ghost'] })))
  assert.deepEqual(r.problems, [])
  const c = r.crons.crons[0]
  assert.equal(c.health, 'fail')
  assert.deepEqual(c.runsResolved, [{ id: 'trinity/ghost', ok: false }])
  assert.ok(c.messages.some((m) => m.includes('trinity/ghost')))
})

test('a spec the code catalog does not know is spec-only and warns; a code entry with no spec is code-only', () => {
  const r = build(files('specs/skills', skillSrc('trinity/only-in-spec', { module: 'skill_x0' })), [])
  assert.equal(r.skills.skills[0].witness, 'spec-only')
  assert.equal(r.skills.skills[0].health, 'warn')
  assert.deepEqual(r.skills.codeOnly, ['trinity/x'])
  assert.deepEqual(r.crons.codeOnly, ['github-actions/trinity/x'])
  assert.equal(r.crons.counts.codeOnly, 1)
})

test('the module name must follow the file name', () => {
  const r = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_wrong' })), [])
  assert.ok(r.problems.some((p) => p.includes('module must be skill_x0')))
})

test('a timer carries INTERVAL_MS, a schedule carries SCHEDULE, never both', () => {
  const r = build([], files('specs/crons',
    cronSrc('timer/trinity/t', { module: 'cron_x0', host: 'timer', extra: 'pub const SCHEDULE : str = "* * * * *";' }),
    cronSrc('github-actions/trinity/x', { module: 'cron_x1', extra: 'pub const INTERVAL_MS : u32 = 1;' }),
  ))
  assert.ok(r.problems.some((p) => p.includes('x0.t27: a timer has INTERVAL_MS, not SCHEDULE')), r.problems.join('\n'))
  assert.ok(r.problems.some((p) => p.includes('x1.t27: only a timer has INTERVAL_MS')), r.problems.join('\n'))
})

test('a spec that disagrees with the schedule the code catalog read is shown, as warn', () => {
  const r = build([], files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0', schedule: '"5 5 * * *"' })))
  assert.deepEqual(r.problems, [])
  assert.equal(r.crons.crons[0].health, 'warn')
  assert.ok(r.crons.crons[0].messages.some((m) => m.includes('differs from the code catalog')))
})

test('unknown constants, wrong shapes and bad enums are problems, not silently dropped', () => {
  const r = build(
    files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0', extra: 'pub const EXTRA : str = "x";' })),
    files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0', extra: '' }).replace('"code-only"', '"telepathy"')),
  )
  assert.ok(r.problems.some((p) => p.includes('unknown constant EXTRA')))
  assert.ok(r.problems.some((p) => p.includes('CONTROL telepathy')))
})

test('the wasm typecheck is lenient, so the schema is the gate: wrong annotation, shape, length and range are all problems', () => {
  // Measured against the vendored wasm: each of these still gets typecheck.ok === true.
  const src = `module skill_x0;
pub const KIND : str = 5;
pub const ID : str = "trinity/x";
pub const NAME : str = "x";
pub const REPO : str = "trinity";
pub const SOURCE : str = "SKILL.md";
pub const SUMMARY_EN : str = "en";
pub const SUMMARY_RU : str = "ru";
pub const COMMAND : str = ;
pub const SPECS : [2]str = ["a"];
pub const TAGS : [1]str = ["t"];
pub const ENABLED : bool = "yes";
pub const TIMEOUT_MIN : u16 = 70000;
`
  const a = analyze(src)
  assert.equal(a.typecheck.ok, true, 'if this starts failing the compiler got stricter; the schema gate below stays')
  const r = build(files('specs/skills', src), [])
  const text = r.problems.join('\n')
  assert.match(text, /KIND: value is not a string literal/)
  assert.match(text, /missing COMMAND/)
  assert.match(text, /SPECS: annotated \[2\]str, holds 1 string/)
  assert.match(text, /ENABLED: value is not true\/false/)
  assert.match(text, /TIMEOUT_MIN: value 70000 is not in u16 range/)
})

test('output is deterministic: sorted keys, sorted ids, content hash independent of the clock', () => {
  const a = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })), [])
  const b = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })), [], { generatedAt: '2030-01-01T00:00:00.000Z' })
  assert.equal(a.skills.contentSha256, b.skills.contentSha256)
  assert.deepEqual(Object.keys(a.skills), Object.keys(a.skills).slice().sort())
  assert.deepEqual(sortKeys({ b: 1, a: [{ d: 1, c: 2 }] }), { a: [{ c: 2, d: 1 }], b: 1 })
})

test('runNowTarget: every host resolves to the panel that owns it, and a timer to nothing', () => {
  const railway = { projectId: 'P', services: [{ name: 'jobsearch-cron', serviceId: 'S' }] }
  assert.deepEqual(runNowTarget({ HOST: 'github-actions', REPO: 'trinity', SERVICE: '.github/workflows/site-live-gate.yml' }, railway), {
    kind: 'link', via: 'github-actions', url: 'https://github.com/gHashTag/trinity/actions/workflows/site-live-gate.yml',
  })
  assert.deepEqual(runNowTarget({ HOST: 'railway-cron', REPO: 'x', SERVICE: 'jobsearch-cron' }, railway), {
    kind: 'link', via: 'railway', url: 'https://railway.com/project/P/service/S',
  })
  assert.deepEqual(runNowTarget({ HOST: 'railway-cron', REPO: 'x', SERVICE: 'nobody' }, railway), { kind: 'disabled', reason: 'unknown-service' })
  assert.deepEqual(runNowTarget({ HOST: 'railway-cron', REPO: 'x', SERVICE: 'jobsearch-cron' }, null), { kind: 'disabled', reason: 'unknown-service' })
  assert.equal(runNowTarget({ HOST: 'inngest', REPO: 'x', SERVICE: 'y' }, railway).via, 'inngest')
  assert.deepEqual(runNowTarget({ HOST: 'timer', REPO: 'x', SERVICE: 'y' }, railway), { kind: 'disabled', reason: 'timer' })
})
