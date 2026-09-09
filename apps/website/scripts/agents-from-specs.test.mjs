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
  I18N_SPEC_DIR, SITE, analyzeSpecFiles, checkI18n, buildSpecCatalogs, constsOf, decodeBytes, loadCompiler, runNowTarget, sortKeys, verdictOf,
} from './agents-from-specs.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))

const q = JSON.stringify
const skillSrc = (id, { module = 'skill_x', specs = [], summary = 'en', extra = '' } = {}) => `module ${module};
pub const KIND : str = "skill";
pub const ID : str = ${q(id)};
pub const NAME : str = "x";
pub const REPO : str = "trinity";
pub const SOURCE : str = "SKILL.md";
pub const SUMMARY_EN : str = ${q(summary)};
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
  // Specs are English-only (LANG-EN), but English specs still carry non-ASCII
  // glyphs -- arrows, check marks, φ -- and those must round-trip exactly.
  const a = analyze(skillSrc('trinity/x', { module: 'skill_x0', specs: ['specs/a.t27', 'specs/φ.t27'], summary: 'Issue → Spec ✓ ⟲ ◷ φ' }))
  const arr = a.ast.children.find((n) => n.name === 'SPECS').children[0]
  assert.equal(arr.kind, 'ExprIdentifier', 'the quirk this generator documents: array literal in an identifier name')
  const c = constsOf(a)
  assert.deepEqual(c.SPECS.value, ['specs/a.t27', 'specs/φ.t27'])
  assert.equal(c.SUMMARY_EN.value, 'Issue → Spec ✓ ⟲ ◷ φ')
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

test('Cyrillic in a spec is a problem (t27 LANG-EN), even when the compiler accepts the file', () => {
  const r = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0', summary: 'Проверка' })), [])
  assert.ok(r.problems.some((p) => p.includes('Cyrillic in a .t27 spec')), r.problems.join('\n'))
  const clean = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })), [])
  assert.ok(!clean.problems.some((p) => p.includes('Cyrillic')))
})

const i18nSrc = ({ locale = 'ru', module = 'i18n_agents_ru', fields = ['SUMMARY', 'NAME'], scope = ['specs/skills', 'specs/crons'], bundle = 'apps/website/i18n/agents.ru.json', coverageRequired = false, orphans = false, enabled = true, repo = 'trinity', extra = '' } = {}) => `module ${module};
pub const KIND : str = "i18n";
pub const LOCALE : str = ${q(locale)};
pub const SOURCE_LOCALE : str = "en";
pub const SCOPE : [${scope.length}]str = ${q(scope)};
pub const FIELDS : [${fields.length}]str = ${q(fields)};
pub const BUNDLE_REPO : str = ${q(repo)};
pub const BUNDLE_PATH : str = ${q(bundle)};
pub const BUNDLE_FORMAT : str = "json";
pub const KEY : str = "ID";
pub const FALLBACK : str = "en";
pub const COVERAGE_REQUIRED : bool = ${coverageRequired};
pub const ORPHANS_ALLOWED : bool = ${orphans};
pub const ENABLED : bool = ${enabled};
${extra}`
const i18nFiles = (...srcs) => srcs.map((text, i) => ({ path: i === 0 ? `${I18N_SPEC_DIR}/agents-ru.t27` : `${I18N_SPEC_DIR}/agents-x${i}.t27`, text }))
const ruBundle = (entries, over = {}) => ({ $spec: 'specs/i18n/agents-ru.t27', locale: 'ru', entries, ...over })
const withI18n = (i18nSpecs, bundles, over = {}) => build(
  files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })),
  files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0' })),
  { i18nSpecs: analyzeSpecFiles(analyze, i18nSpecs), bundles: new Map(Object.entries(bundles)), ...over },
)

test('the i18n contract spec typechecks and comes back typed', () => {
  const a = analyze(i18nSrc())
  assert.equal(verdictOf(a).typecheckOk, true)
  assert.equal(verdictOf(a).discarded, 0)
  const c = constsOf(a)
  assert.equal(c.KIND.value, 'i18n')
  assert.deepEqual(c.SCOPE.value, ['specs/skills', 'specs/crons'])
  assert.equal(c.COVERAGE_REQUIRED.value, false)
})

test('a translation reaches the catalog only through its contract spec, as {en, <locale>}, with coverage per catalog', () => {
  const r = withI18n(i18nFiles(i18nSrc()), { 'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: 'Проверка ✓', NAME: 'ИКС' } }) })
  assert.deepEqual(r.problems, [])
  assert.deepEqual(r.skills.skills[0].summary, { en: 'en', ru: 'Проверка ✓' })
  assert.deepEqual(r.skills.skills[0].name, { en: 'x', ru: 'ИКС' })
  assert.equal('SUMMARY_RU' in r.skills.skills[0].fields, false)
  assert.equal(r.skills.i18n.length, 1)
  assert.equal(r.skills.i18n[0].locale, 'ru')
  assert.equal(r.skills.i18n[0].spec, 'specs/i18n/agents-ru.t27')
  assert.deepEqual(r.skills.i18n[0].coverage, { n: 1, total: 1 })
  // the cron has no entry: en only, coverage 0/1 and its id listed, but no problem (COVERAGE_REQUIRED false)
  assert.deepEqual(r.crons.crons[0].summary, { en: 'en' })
  assert.deepEqual(r.crons.i18n[0].coverage, { n: 0, total: 1 })
  assert.deepEqual(r.crons.i18n[0].missing, ['github-actions/trinity/x'])
})

test('no i18n spec: en only, empty i18n list -- the site never invents a locale', () => {
  const r = build(files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })), [])
  assert.deepEqual(r.skills.skills[0].summary, { en: 'en' })
  assert.deepEqual(r.skills.i18n, [])
})

test('an orphan bundle entry fails when ORPHANS_ALLOWED is false, and is skipped when true', () => {
  const bundle = ruBundle({ 'trinity/x': { SUMMARY: 'ок' }, 'trinity/gone': { SUMMARY: 'нет' } })
  const strict = withI18n(i18nFiles(i18nSrc()), { 'apps/website/i18n/agents.ru.json': bundle })
  assert.equal(strict.problems.filter((p) => p.includes('matches no spec in SCOPE')).length, 1, strict.problems.join('\n'))
  const loose = withI18n(i18nFiles(i18nSrc({ orphans: true })), { 'apps/website/i18n/agents.ru.json': bundle })
  assert.deepEqual(loose.problems, [])
  assert.deepEqual(loose.skills.skills[0].summary, { en: 'en', ru: 'ок' })
})

test('COVERAGE_REQUIRED turns a missing translation from a warning into a problem', () => {
  const r = withI18n(i18nFiles(i18nSrc({ coverageRequired: true })), { 'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: 'ок' } }) })
  assert.ok(r.problems.some((p) => p.includes('COVERAGE_REQUIRED') && p.includes('github-actions/trinity/x')), r.problems.join('\n'))
})

test('the bundle is checked against the contract: locale, $spec, FIELDS, shapes, missing file, foreign repo, disabled', () => {
  const p = (r) => r.problems.join('\n')
  let r = withI18n(i18nFiles(i18nSrc()), { 'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: 'ок' } }, { locale: 'de' }) })
  assert.ok(p(r).includes('does not match the spec\'s LOCALE'), p(r))
  r = withI18n(i18nFiles(i18nSrc()), { 'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: 'ок' } }, { $spec: 'specs/i18n/other.t27' }) })
  assert.ok(p(r).includes('$spec is'), p(r))
  r = withI18n(i18nFiles(i18nSrc()), { 'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: 'ок', COMMAND: '/х' } }) })
  assert.ok(p(r).includes('not in FIELDS'), p(r))
  assert.deepEqual(r.skills.skills[0].summary, { en: 'en', ru: 'ок' }, 'the good field still lands')
  r = withI18n(i18nFiles(i18nSrc()), { 'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: '' } }) })
  assert.ok(p(r).includes('non-empty string'), p(r))
  r = withI18n(i18nFiles(i18nSrc()), {})
  assert.ok(p(r).includes('is missing or not JSON'), p(r))
  r = withI18n(i18nFiles(i18nSrc({ repo: 't27' })), {})
  assert.ok(p(r).includes('only a bundle in this repository'), p(r))
  r = withI18n(i18nFiles(i18nSrc({ enabled: false })), {})
  assert.deepEqual(r.problems, [])
  assert.equal(r.skills.i18n[0].enabled, false)
  assert.deepEqual(r.skills.skills[0].summary, { en: 'en' })
  r = withI18n(i18nFiles(i18nSrc({ fields: ['SUMMARY', 'COMMAND'] })), { 'apps/website/i18n/agents.ru.json': ruBundle({}) })
  assert.ok(p(r).includes('which no spec constant backs'), p(r))
})

test('locales are discovered, not enumerated: a second contract adds a second key; a duplicate LOCALE is a problem', () => {
  const de = i18nSrc({ locale: 'de', module: 'i18n_agents_x1', bundle: 'apps/website/i18n/agents.de.json' })
  const r = withI18n(i18nFiles(i18nSrc(), de), {
    'apps/website/i18n/agents.ru.json': ruBundle({ 'trinity/x': { SUMMARY: 'ок' } }),
    'apps/website/i18n/agents.de.json': { $spec: 'specs/i18n/agents-x1.t27', locale: 'de', entries: { 'trinity/x': { SUMMARY: 'gut' } } },
  })
  assert.deepEqual(r.problems, [])
  assert.deepEqual(r.skills.skills[0].summary, { en: 'en', ru: 'ок', de: 'gut' })
  assert.deepEqual(r.skills.i18n.map((l) => l.locale), ['de', 'ru'])
  const dup = withI18n(i18nFiles(i18nSrc(), i18nSrc({ module: 'i18n_agents_x1' })), { 'apps/website/i18n/agents.ru.json': ruBundle({}) })
  assert.ok(dup.problems.some((p) => p.includes('duplicate LOCALE ru')), dup.problems.join('\n'))
})

test('Cyrillic in an i18n contract spec is a problem like in any other spec', () => {
  const r = withI18n(i18nFiles(i18nSrc({ extra: '; Русский комментарий' })), { 'apps/website/i18n/agents.ru.json': ruBundle({}) })
  assert.ok(r.problems.some((p) => p.includes('Cyrillic in a .t27 spec')), r.problems.join('\n'))
})

test('checkI18n is usable on its own', () => {
  const spec = analyzeSpecFiles(analyze, i18nFiles(i18nSrc()))[0]
  const fields = Object.fromEntries(Object.entries(spec.consts).map(([k, v]) => [k, v.value]))
  const r = checkI18n({ ...spec, fields }, ruBundle({ 'a/b': { SUMMARY: 'ок' } }), new Map([['a/b', { dir: 'specs/skills' }]]))
  assert.deepEqual(r.problems, [])
  assert.deepEqual(r.entry.coverage, { n: 1, total: 1 })
  assert.deepEqual(r.translations.get('a/b'), { SUMMARY: 'ок' })
})

test('the committed contract and bundle: no problems, every vendored spec English-only, ru coverage reported', async () => {
  const { generate } = await import('./agents-from-specs.mjs')
  const r = await generate({ generatedAt: '2026-01-01T00:00:00.000Z' })
  assert.deepEqual(r.problems, [])
  const ru = r.skills.i18n.find((l) => l.locale === 'ru')
  assert.ok(ru, 'specs/i18n/agents-ru.t27 is the contract for the Russian layer')
  assert.equal(ru.spec, 'specs/i18n/agents-ru.t27')
  for (const e of [...r.skills.skills, ...r.crons.crons]) {
    assert.ok(!/[\u0400-\u04ff]/.test(JSON.stringify(e.fields)), `${e.id}: Cyrillic in spec constants`)
    if (e.summary.ru) assert.ok(/[\u0400-\u04ff]/.test(e.summary.ru), `${e.id}: summary.ru is not Russian`)
  }
})
