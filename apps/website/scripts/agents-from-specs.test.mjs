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

// ---------------------------------------------------------------------------
// Layer 4: agents.
// ---------------------------------------------------------------------------
const agentSrc = (letter, { ordinal = 1, module = `agent_${letter.toLowerCase()}`, skills = [], skillsNote = 'no source binds a skill to this agent', layer = 'Archetypal', id = `t27/${letter}`, extra = '' } = {}) => `module ${module};
pub const KIND : str = "agent";
pub const ID : str = ${q(id)};
pub const LETTER : str = ${q(letter)};
pub const ORDINAL : u8 = ${ordinal};
pub const LETTER_NAME : str = "Alpha";
pub const NAME : str = "Alpha (Architecture)";
pub const DOMAIN : str = "Architecture / ADR / SOUL";
pub const ARCHETYPE : str = "Bull - leader, primary force";
pub const REGISTER : str = "R0";
pub const LAYER : str = ${q(layer)};
pub const SUMMARY_EN : str = "Architecture / ADR / SOUL. SOUL.md is the primary cause.";
pub const SOUL : str = "SOUL.md";
pub const AGENTS_DOC : str = "AGENTS.md";
pub const ALPHABET : str = "docs/agents/AGENTS_ALPHABET.md";
pub const KEY_FILES : [1]str = ["SOUL.md"];
pub const ENTRY_INVARIANT : str = "SOUL.md exists";
pub const EXIT_INVARIANT : str = "All ADRs reviewed";
pub const CLARA_ROLE : str = "";
pub const SKILLS : [${skills.length}]str = ${q(skills)};
pub const SKILLS_NOTE : str = ${q(skillsNote)};
pub const EXPERIENCE_LOG : str = ".trinity/experience/";
pub const ENABLED : bool = true;
${extra}`
const agentFiles = (...pairs) => pairs.map(([letter, text]) => ({ path: `specs/agents/${letter.toLowerCase()}.t27`, text }))
const withAgents = (agentSpecs, over = {}) => build(
  files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })),
  files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0', runs: ['trinity/x'] })),
  { agentSpecs: analyzeSpecFiles(analyze, agentSpecs), ...over },
)
const experience = {
  generatedAt: '2026-01-01T00:00:00.000Z',
  sources: [{ repo: 'trinity', commit: 'b'.repeat(40), files: 2, episodes: 2, unreadable: 0 }, { repo: 't27', commit: 'c'.repeat(40), files: 1, episodes: 1, unreadable: 0 }],
  counts: { episodes: 3, attributed: 1, unattributed: 2, agentsWithEpisodes: 1, unreadableFiles: 0 },
  attribution: { fields: ['agent'], letters: ['A'], rule: 'test' },
  agents: { A: { episodes: 1, first: '2026-01-01T00:00:00.000Z', last: '2026-01-01T00:00:00.000Z', lastTask: 't', outcomes: { PASS: 1 }, lessons: ['l'], files: ['trinity:.trinity/experience/episodes/a.json'] } },
  unattributed: { episodes: 2 },
}

test('an agent spec typechecks, resolves its skills, derives its crons from RUNS and joins experience by LETTER', () => {
  const r = withAgents(agentFiles(['A', agentSrc('A', { skills: ['trinity/x'], skillsNote: 'test binding' })]), { experience })
  // Only the 27-count rule complains; the single agent itself is clean.
  assert.deepEqual(r.problems, ['specs/agents: 1 agent spec(s), the alphabet has 27'])
  const a = r.agents.agents[0]
  assert.equal(a.id, 't27/A')
  assert.equal(a.letter, 'A')
  assert.equal(a.ordinal, 1)
  assert.deepEqual(a.skills, [{ id: 'trinity/x', ok: true }])
  assert.deepEqual(a.crons, ['github-actions/trinity/x'])
  assert.equal(a.experience.episodes, 1)
  assert.deepEqual(a.experience.outcomes, { PASS: 1 })
  assert.equal(a.witness, 'spec+experience')
  assert.equal(a.health, 'ok')
  assert.deepEqual(a.messages, [])
  assert.equal(a.links.soul, `https://github.com/gHashTag/t27/blob/${'c'.repeat(40)}/SOUL.md`)
  assert.equal(a.links.agentsDoc, `https://github.com/gHashTag/t27/blob/${'c'.repeat(40)}/AGENTS.md`)
  assert.equal(a.links.alphabet, `https://github.com/gHashTag/t27/blob/${'c'.repeat(40)}/docs/agents/AGENTS_ALPHABET.md`)
  assert.equal(a.links.experienceLog, `https://github.com/gHashTag/t27/tree/${'c'.repeat(40)}/.trinity/experience`)
  assert.equal(r.agents.pin.ref, 'c'.repeat(40))
  assert.deepEqual(r.agents.ladder, { specs: null, skills: 1, crons: 1, agents: 1 })
  assert.equal(r.agents.counts.episodesUnattributed, 2)
  assert.equal(r.agents.counts.withCrons, 1)
})

test('no experience snapshot: zero episodes, spec-only, a plain message, links pinned to the default branch', () => {
  const r = withAgents(agentFiles(['A', agentSrc('A')]))
  const a = r.agents.agents[0]
  assert.equal(a.experience.episodes, 0)
  assert.equal(a.witness, 'spec-only')
  assert.deepEqual(a.messages, ['no attributed episodes in the experience snapshot'])
  assert.equal(r.agents.pin.ref, 'master')
  assert.equal(a.links.soul, 'https://github.com/gHashTag/t27/blob/master/SOUL.md')
  assert.equal(r.agents.counts.episodesUnattributed, null)
})

test('an unknown skill ID, an empty SKILLS without a note, a wrong ID, a bad LAYER and a duplicate ORDINAL are problems', () => {
  const r = withAgents(agentFiles(
    ['A', agentSrc('A', { skills: ['trinity/nope'], skillsNote: 'x' })],
    ['B', agentSrc('B', { ordinal: 1, skillsNote: '', layer: 'Cosmic', id: 't27/X' })],
  ))
  const p = r.problems.join('\n')
  assert.match(p, /a\.t27: SKILLS names trinity\/nope, which has no skill spec/)
  assert.match(p, /b\.t27: empty SKILLS needs a SKILLS_NOTE/)
  assert.match(p, /b\.t27: ID must be t27\/B, is "t27\/X"/)
  assert.match(p, /b\.t27: LAYER "Cosmic" is not one of Archetypal\|Spiritual\|Physical/)
  assert.match(p, /b\.t27: duplicate ORDINAL 1 \(also specs\/agents\/a\.t27\)/)
  assert.equal(r.agents.agents.find((x) => x.letter === 'A').health, 'fail')
})

test('the module and file name follow the letter; ORDINAL is a u8 in 1..27; TOOLS is optional but an empty one needs a note', () => {
  const r = withAgents([
    { path: 'specs/agents/a.t27', text: agentSrc('A', { module: 'agent_b' }) },
    { path: 'specs/agents/c.t27', text: agentSrc('C', { ordinal: 28 }) },
    { path: 'specs/agents/d.t27', text: agentSrc('D', { ordinal: 3, extra: 'pub const TOOLS : [0]str = [];' }) },
    { path: 'specs/agents/e.t27', text: agentSrc('E', { ordinal: 4, extra: 'pub const TOOLS : [1]str = ["tri/cell"];\npub const TOOLS_NOTE : str = "alphabet Key files";' }) },
  ])
  const p = r.problems.join('\n')
  assert.match(p, /a\.t27: module must be agent_a, is agent_b/)
  assert.match(p, /c\.t27: ORDINAL 28 is not 1\.\.27/)
  assert.match(p, /d\.t27: empty TOOLS needs a TOOLS_NOTE/)
  assert.ok(!/e\.t27/.test(p), `e.t27 must be clean:\n${p}`)
  assert.deepEqual(r.agents.agents.find((x) => x.letter === 'E').tools, ['tri/cell'])
})

test('agent translations come through the same i18n contract once SCOPE names specs/agents', () => {
  const spec = i18nFiles(i18nSrc({ scope: ['specs/skills', 'specs/crons', 'specs/agents'] }))
  const bundles = new Map([['apps/website/i18n/agents.ru.json', ruBundle({ 't27/A': { SUMMARY: 'Архитектура.' } })]])
  const r = withAgents(agentFiles(['A', agentSrc('A')]), { i18nSpecs: analyzeSpecFiles(analyze, spec), bundles })
  const a = r.agents.agents[0]
  assert.equal(a.summary.ru, 'Архитектура.')
  assert.equal(r.agents.i18n[0].coverage.n, 1)
  assert.equal(r.agents.i18n[0].coverage.total, 1)
})

test('the committed agent catalog: 27 specs, every skill link resolved, experience counts add up', async () => {
  const { generate, EXPERIENCE_PATH } = await import('./agents-from-specs.mjs')
  const r = await generate({ generatedAt: '2026-01-01T00:00:00.000Z' })
  assert.deepEqual(r.problems, [])
  assert.equal(r.agents.agents.length, 27)
  assert.deepEqual(r.agents.agents.map((a) => a.letter), [...'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TI'])
  for (const a of r.agents.agents) {
    assert.ok(a.skills.every((s) => s.ok), `${a.id}: unresolved skill`)
    assert.ok(a.summary.ru && /[\u0400-\u04ff]/.test(a.summary.ru), `${a.id}: no Russian summary`)
  }
  const snap = JSON.parse(readFileSync(join(SITE, EXPERIENCE_PATH), 'utf8'))
  assert.equal(r.agents.counts.episodesAttributed, snap.counts.attributed)
  assert.equal(r.agents.counts.episodesUnattributed, snap.unattributed.episodes)
  assert.equal(r.agents.counts.episodesAttributed + r.agents.counts.episodesUnattributed, snap.counts.episodes)
})

// ---- layer 5: functions ----------------------------------------------------

const fnSrc = (id, { module = `fn_${id.replace(/[^A-Za-z0-9]+/g, '_')}`, trigger = 'event', event = 'neuro/image.generate', legacyEvents = ['neuro/photo.generate'], cron = '', retries = 3, onFailure = 'admin-telegram', steps = ['get-bot', 'check-user'], sideEffects = ['paid-api', 'db-write'], probeResult = 'FAILED-at-guard', safeProbe = '{\\"telegram_id\\": \\"0\\"}', legacyId = 'neuro-image-generation', extra = '' } = {}) => `module ${module};
pub const KIND : str = "function";
pub const ID : str = ${q(id)};
pub const LEGACY_ID : str = ${q(legacyId)};
pub const NAME : str = "Neuro image";
pub const REPO : str = "999-multibots-telegraf";
pub const SERVICE : str = "src/inngest_app/functions/neuroImageGeneration.ts:25";
pub const DOMAIN : str = "neuro";
pub const TRIGGER : str = ${q(trigger)};
pub const EVENT : str = ${q(event)};
pub const LEGACY_EVENTS : [${legacyEvents.length}]str = ${q(legacyEvents)};
pub const CRON : str = ${q(cron)};
pub const TZ : str = "UTC";
pub const SUMMARY_EN : str = "Generates an image.";
pub const STEPS : [${steps.length}]str = ${q(steps)};
pub const RETRIES : u8 = ${retries};
pub const ON_FAILURE : str = ${q(onFailure)};
pub const SIDE_EFFECTS : [${sideEffects.length}]str = ${q(sideEffects)};
pub const GUARD : str = "check-user";
pub const SAFE_PROBE : str = "${safeProbe}";
pub const PROBE_RESULT : str = ${q(probeResult)};
pub const CONTROL : str = "spec+code";
pub const NOTE : str = "";
${extra}`
const fnFiles = (...pairs) => pairs.map(([id, text]) => ({ path: `specs/functions/${id}.t27`, text }))
const fnManifestEntry = (id, over = {}) => ({
  id, legacy_id: 'neuro-image-generation', domain: 'neuro', trigger: 'event', event: 'neuro/image.generate', legacy_events: ['neuro/photo.generate'], cron: '', tz: 'UTC',
  file: 'src/inngest_app/functions/neuroImageGeneration.ts', steps: ['get-bot', 'check-user'], retries: 3, on_failure: 'admin-telegram',
  side_effects: ['paid-api', 'db-write'], guard: 'check-user', safe_probe: '{"telegram_id": "0"}', probe_result: 'FAILED-at-guard', deployed_2026_09_09: true, control: 'spec+code', ...over,
})
const inngestCron = (name) => cronSrc(`inngest/999-multibots-telegraf/${name}`, { module: 'cron_x1', host: 'inngest', extra: '' }).replace('pub const NAME : str = "x";', `pub const NAME : str = ${q(name)};`).replace('pub const REPO : str = "trinity";', 'pub const REPO : str = "999-multibots-telegraf";')
const withFunctions = (functionSpecs, manifestFns, over = {}) => build(
  files('specs/skills', skillSrc('trinity/x', { module: 'skill_x0' })),
  [...files('specs/crons', cronSrc('github-actions/trinity/x', { module: 'cron_x0', runs: ['trinity/x'] })), { path: 'specs/crons/x1.t27', text: inngestCron('check-stuck-trainings') }],
  { functionSpecs: analyzeSpecFiles(analyze, functionSpecs), functionsManifest: manifestFns ? { probedAt: '2026-09-09', functions: manifestFns } : null, ...over },
)

test('a function spec typechecks, is spec+code when the manifest lists its id, and carries the deployed flag from the witness', () => {
  const r = withFunctions(fnFiles(['neuro-image-generate', fnSrc('neuro-image-generate')]), [fnManifestEntry('neuro-image-generate')])
  assert.deepEqual(r.problems, [])
  const f = r.functions.functions[0]
  assert.equal(f.id, 'neuro-image-generate')
  assert.equal(f.moduleName, 'fn_neuro_image_generate')
  assert.equal(f.typecheckOk, true)
  assert.equal(f.witness, 'spec+code')
  assert.equal(f.health, 'ok')
  assert.equal(f.code.deployed, true)
  assert.equal(f.fields.RETRIES, 3)
  assert.deepEqual(f.fields.STEPS, ['get-bot', 'check-user'])
  assert.deepEqual(f.differences, [])
  assert.equal(f.cronSpec, null)
  assert.equal(r.functions.counts.specPlusCode, 1)
  assert.equal(r.functions.counts.byTrigger.event, 1)
  assert.equal(r.functions.ladder.functions, 1)
})

test('a function the manifest does not list is spec-only (warn); a manifest id with no spec is code-only, listed not invented', () => {
  const r = withFunctions(fnFiles(['neuro-image-generate', fnSrc('neuro-image-generate')]), [fnManifestEntry('ghost-function')])
  assert.deepEqual(r.problems, [])
  const f = r.functions.functions[0]
  assert.equal(f.witness, 'spec-only')
  assert.equal(f.health, 'warn')
  assert.equal(f.code, null)
  assert.ok(f.messages.some((m) => m.includes('no function neuro-image-generate')))
  assert.deepEqual(r.functions.codeOnly, ['ghost-function'])
  assert.equal(r.functions.counts.codeOnly, 1)
  assert.equal(r.functions.counts.deployUnknown, 1)
})

test('no manifest at all: every function is spec-only and nothing is invented', () => {
  const r = withFunctions(fnFiles(['neuro-image-generate', fnSrc('neuro-image-generate')]), null)
  assert.deepEqual(r.problems, [])
  assert.equal(r.functions.functions[0].witness, 'spec-only')
  assert.equal(r.functions.manifest, null)
})

test('a spec that differs from what the manifest read is shown as warn with the distance named; an unread manifest field is not a difference', () => {
  const r = withFunctions(
    fnFiles(['neuro-image-generate', fnSrc('neuro-image-generate', { onFailure: 'log', retries: 4 })]),
    [fnManifestEntry('neuro-image-generate', { retries: null, steps: [], file: '', deployed_2026_09_09: false })],
  )
  assert.deepEqual(r.problems, [])
  const f = r.functions.functions[0]
  assert.equal(f.health, 'warn')
  assert.deepEqual(f.differences, [{ field: 'ON_FAILURE', spec: 'log', code: 'admin-telegram' }])
  assert.ok(f.messages.some((m) => m === 'ON_FAILURE "log" differs from the manifest ("admin-telegram")'))
  assert.ok(f.messages.some((m) => m.includes('not on the production build probed 2026-09-09')))
  assert.equal(f.code.deployed, false)
  assert.equal(f.code.retries, null)
  assert.equal(r.functions.counts.notDeployed, 1)
})

test('a cron function carries CRON not EVENT, joins its cron card by REPO + LEGACY_ID, and an event function the other way round', () => {
  const ok = withFunctions(
    fnFiles(['training-stuck-check', fnSrc('training-stuck-check', { trigger: 'cron', event: '', legacyEvents: [], cron: '*/30 * * * *', legacyId: 'check-stuck-trainings' })]),
    [fnManifestEntry('training-stuck-check', { trigger: 'cron', event: '', legacy_events: [], cron: '*/30 * * * *', legacy_id: 'check-stuck-trainings' })],
  )
  assert.deepEqual(ok.problems, [])
  assert.equal(ok.functions.functions[0].cronSpec, 'inngest/999-multibots-telegraf/check-stuck-trainings')
  assert.equal(ok.functions.counts.withCronSpec, 1)
  const unjoined = withFunctions(
    fnFiles(['x-check', fnSrc('x-check', { trigger: 'cron', event: '', legacyEvents: [], cron: '*/30 * * * *', legacyId: 'no-such-cron' })]),
    [fnManifestEntry('x-check', { trigger: 'cron', event: '', legacy_events: [], cron: '*/30 * * * *', legacy_id: 'no-such-cron' })],
  )
  assert.equal(unjoined.functions.functions[0].cronSpec, null)
  assert.ok(unjoined.functions.functions[0].messages.some((m) => m.includes('no cron card')))
  const bad = withFunctions(
    fnFiles(
      ['a-cron', fnSrc('a-cron', { trigger: 'cron', cron: '' })],
      ['b-event', fnSrc('b-event', { trigger: 'event', cron: '0 0 * * *' })],
      ['c-event', fnSrc('c-event', { trigger: 'event', event: '' })],
    ),
    [],
  )
  assert.ok(bad.problems.some((p) => p.includes('a-cron.t27: a cron function needs CRON')))
  assert.ok(bad.problems.some((p) => p.includes('a-cron.t27: a cron function has CRON, not EVENT')))
  assert.ok(bad.problems.some((p) => p.includes('a-cron.t27: a cron function has no LEGACY_EVENTS')))
  assert.ok(bad.problems.some((p) => p.includes('b-event.t27: an event function has EVENT, not CRON')))
  assert.ok(bad.problems.some((p) => p.includes('c-event.t27: an event function needs EVENT')))
})

test('function vocabularies, module, file name, KIND, duplicate ID and SAFE_PROBE JSON are gates', () => {
  const r = withFunctions(
    fnFiles(
      ['neuro-image-generate', fnSrc('neuro-image-generate', { module: 'fn_wrong', onFailure: 'shrug', probeResult: 'MAYBE', sideEffects: ['teleport'], safeProbe: 'not json' })],
      ['other-id', fnSrc('neuro-image-generate')],
      ['no-effects', fnSrc('no-effects', { sideEffects: [], trigger: 'webhook' }).replace('"function"', '"cron"')],
    ),
    [],
  )
  const p = r.problems.join('\n')
  assert.match(p, /module must be fn_neuro_image_generate, is fn_wrong/)
  assert.match(p, /ON_FAILURE "shrug" is not one of/)
  assert.match(p, /PROBE_RESULT "MAYBE" is not one of/)
  assert.match(p, /SIDE_EFFECTS names "teleport"/)
  assert.match(p, /SAFE_PROBE is neither "" nor JSON/)
  assert.match(p, /other-id\.t27: duplicate function ID neuro-image-generate/)
  assert.match(p, /other-id\.t27: ID must equal the file name \(other-id\)/)
  assert.match(p, /no-effects\.t27: KIND must be "function"/)
  assert.match(p, /no-effects\.t27: SIDE_EFFECTS must name at least one value/)
  assert.match(p, /no-effects\.t27: TRIGGER "webhook" is not one of event\|cron/)
  const missing = withFunctions([{ path: 'specs/functions/m.t27', text: fnSrc('m').replace(/pub const RETRIES[^\n]*\n/, '') }], [])
  assert.ok(missing.problems.some((x) => x.includes('m.t27') && x.includes('RETRIES')))
})

test('function translations come through the same i18n contract once SCOPE names specs/functions', () => {
  const spec = i18nFiles(i18nSrc({ scope: ['specs/skills', 'specs/crons', 'specs/functions'] }))
  const bundles = new Map([['apps/website/i18n/agents.ru.json', ruBundle({ 'neuro-image-generate': { SUMMARY: 'Генерирует изображение.', NAME: 'Нейро-картинка' } })]])
  const r = withFunctions(fnFiles(['neuro-image-generate', fnSrc('neuro-image-generate')]), [fnManifestEntry('neuro-image-generate')], { i18nSpecs: analyzeSpecFiles(analyze, spec), bundles })
  assert.deepEqual(r.problems, [])
  const f = r.functions.functions[0]
  assert.equal(f.summary.ru, 'Генерирует изображение.')
  assert.equal(f.name.ru, 'Нейро-картинка')
  assert.deepEqual(r.functions.i18n[0].coverage, { n: 1, total: 1 })
})

test('the committed function catalog: 28 specs, every one witnessed by the manifest, five cron cards joined, four not deployed, Russian on each', async () => {
  const { generate, FUNCTIONS_MANIFEST } = await import('./agents-from-specs.mjs')
  const r = await generate({ generatedAt: '2026-01-01T00:00:00.000Z' })
  assert.deepEqual(r.problems, [])
  const fns = r.functions.functions
  assert.equal(fns.length, 28)
  assert.equal(r.functions.counts.specPlusCode, 28)
  assert.deepEqual(r.functions.codeOnly, [])
  assert.equal(r.functions.counts.byTrigger.cron, 5)
  assert.equal(r.functions.counts.withCronSpec, 5)
  assert.equal(r.functions.counts.notDeployed, 4)
  const manifest = JSON.parse(readFileSync(join(SITE, FUNCTIONS_MANIFEST), 'utf8'))
  assert.equal(manifest.functions.length, 28)
  for (const f of fns) {
    assert.equal(f.id, f.specPath.replace(/^specs\/functions\//, '').replace(/\.t27$/, ''))
    assert.ok(f.summary.ru && /[\u0400-\u04ff]/.test(f.summary.ru), `${f.id}: no Russian summary`)
    assert.ok(f.name.ru && /[\u0400-\u04ff]/.test(f.name.ru), `${f.id}: no Russian name`)
  }
  // The one known distance between spec and manifest is kept visible, not resolved.
  const pay = fns.find((f) => f.id === 'payment-ai-server-process')
  assert.deepEqual(pay.differences, [{ field: 'ON_FAILURE', spec: 'admin-telegram', code: 'log' }])
  assert.equal(pay.health, 'warn')
})
