// The spec-first skills and crons catalogs, checked against what they claim.
//
// public/skills/spec-skills.json and public/crons/spec-crons.json are written
// by scripts/agents-from-specs.mjs from the .t27 files under
// public/t27/files/specs/{skills,crons}/ -- through the real compiler, not a
// regex. This gate asks the questions a generated file can still fail: is the
// committed JSON what the specs produce today (no stale output, no hand edit);
// does every entry point at a file whose bytes hash to what it says; does every
// witness label agree with the code catalog it names; does every RUNS link
// resolve both ways; and does the public page carry nothing shaped like a
// secret. It also pins the management-strip facts the page derives -- the
// canonical edit URL and the "run now" target per host -- so the buttons in the
// Explorer cannot silently point somewhere the spec does not.
//
//   node --experimental-strip-types qa/agents-spec-contract.mjs

import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { generate, SKILLS_OUT, CRONS_OUT, AGENTS_OUT, EXPERIENCE_PATH, AGENT_COUNT, AGENT_LAYERS, HOSTS, CONTROLS, ON_FAILURE, I18N_SPEC_DIR, I18N_FIELD_SOURCE, REPO_ROOT } from '../scripts/agents-from-specs.mjs'
import { canonicalSpecEditUrl, vendoredSpecUrl, specSlug } from '../src/lib/agentSpecs.ts'
import { MODULES } from '../src/lib/queenModules.ts'
import { HUD_VIEWS, HUD_KEYS } from '../src/components/queenHud.ts'

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')
const skills = JSON.parse(readFileSync(SKILLS_OUT, 'utf8'))
const crons = JSON.parse(readFileSync(CRONS_OUT, 'utf8'))
const agents = JSON.parse(readFileSync(AGENTS_OUT, 'utf8'))
const experience = JSON.parse(readFileSync(EXPERIENCE_PATH, 'utf8'))
const skillsCode = JSON.parse(readFileSync('public/skills/manifest.json', 'utf8'))
const cronsCode = JSON.parse(readFileSync('public/crons/manifest.json', 'utf8'))
const t27Manifest = JSON.parse(readFileSync('public/t27/manifest.json', 'utf8'))
const corpusPaths = new Set(t27Manifest.specs.map((s) => s.path))

// 1. The committed output is what the specs produce today.
const fresh = await generate({ generatedAt: skills.generatedAt })
assert.deepEqual(fresh.problems, [], 'the generator reports problems:\n' + fresh.problems.join('\n'))
assert.equal(skills.contentSha256, fresh.skills.contentSha256, `${SKILLS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
assert.equal(crons.contentSha256, fresh.crons.contentSha256, `${CRONS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
assert.equal(agents.contentSha256, fresh.agents.contentSha256, `${AGENTS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
assert.equal(agents.compilerWasmSha256, skills.compilerWasmSha256)
assert.equal(skills.compilerWasmSha256, sha256(readFileSync('public/t27/t27_compiler.wasm')), 'the catalog names a compiler other than the vendored one')
assert.equal(crons.compilerWasmSha256, skills.compilerWasmSha256)

// 2. Nothing shaped like a secret on a public page.
const FORBIDDEN = [
  { name: 'telegram id', re: /\b\d{9,10}\b/ },
  { name: 'IPv4 address', re: /\b(?:\d{1,3}\.){3}\d{1,3}\b/ },
  { name: 'bearer token', re: /Bearer\s+[A-Za-z0-9._-]{10,}/ },
  { name: 'bot token', re: /\b\d{8,10}:[A-Za-z0-9_-]{35}\b/ },
  { name: 'url credential', re: /:\/\/[^\s/:@]+:[^\s@]+@/ },
  { name: 'github token', re: /\bgh[pousr]_[A-Za-z0-9]{20,}\b/ },
]
for (const [name, text] of [['spec-skills', JSON.stringify(skills)], ['spec-crons', JSON.stringify(crons)], ['spec-agents', JSON.stringify(agents)], ['experience', JSON.stringify(experience)]]) {
  for (const f of FORBIDDEN) {
    const hit = f.re.exec(text)
    assert.ok(!hit, `${name} carries something shaped like a ${f.name} (${hit ? hit[0].slice(0, 4) : ''}…)`)
  }
}

// 3. Every entry: a real file, the right bytes, an honest witness.
const WITNESS = new Set(['spec+code', 'spec-only'])
const HEALTH = new Set(['ok', 'warn', 'fail'])
const CYRILLIC = /[\u0400-\u04ff]/

// Language policy: a .t27 spec is English-only (t27 LANG-EN; bootstrap/build.rs
// on gHashTag/t27 fails on any Cyrillic under specs/). Every other locale is
// connected through a contract spec in specs/i18n/ (checked in section 6); the
// entry itself carries `en` from the spec plus whatever the loaded bundles gave.
function assertSummary(e, locales) {
  const file = join('public/t27/files', e.specPath)
  assert.ok(!CYRILLIC.test(readFileSync(file, 'utf8')), `${e.specPath}: Cyrillic in a .t27 spec (LANG-EN)`)
  assert.ok(!('SUMMARY_RU' in e.fields), `${e.id}: SUMMARY_RU must not be a spec constant`)
  assert.ok(!('ruSource' in e), `${e.id}: ruSource is gone; locales come from specs/i18n/*.t27`)
  assert.equal(e.summary.en, e.fields.SUMMARY_EN)
  assert.equal(e.name.en, e.fields.NAME)
  assert.ok(e.summary.en.length > 10, `${e.id}: SUMMARY_EN is missing`)
  for (const field of ['summary', 'name']) {
    for (const k of Object.keys(e[field])) assert.ok(k === 'en' || locales.has(k), `${e.id}: ${field}.${k} has no contract spec in ${I18N_SPEC_DIR}`)
  }
  if (e.summary.ru) assert.ok(e.summary.ru.length > 10 && CYRILLIC.test(e.summary.ru), `${e.id}: summary.ru is not Russian`)
}
const localesOf = (cat) => new Set(cat.i18n.map((l) => l.locale))
const skillIds = new Set(skills.skills.map((s) => s.id))
const cronIds = new Set(crons.crons.map((c) => c.id))
assert.equal(skillIds.size, skills.skills.length, 'duplicate skill ids')
assert.equal(cronIds.size, crons.crons.length, 'duplicate cron ids')
const codeSkillIds = new Set(skillsCode.skills.map((s) => s.id))
const codeCronIds = new Set(cronsCode.crons.map((c) => c.id))

for (const s of skills.skills) {
  const file = join('public/t27/files', s.specPath)
  assert.ok(existsSync(file), `${s.id}: ${s.specPath} is not in the vendored corpus`)
  assert.equal(sha256(readFileSync(file)), s.sha256, `${s.id}: the spec bytes changed under the catalog`)
  assert.equal(s.typecheckOk, true)
  assert.equal(s.discarded, 0)
  assert.ok(WITNESS.has(s.witness))
  assert.equal(s.witness, codeSkillIds.has(s.id) ? 'spec+code' : 'spec-only', `${s.id}: witness disagrees with the code catalog`)
  assert.ok(HEALTH.has(s.health))
  if (s.witness === 'spec-only') assert.notEqual(s.health, 'ok', `${s.id}: spec-only must not read ok`)
  assert.equal(s.inSpecCorpus, corpusPaths.has(s.specPath), `${s.id}: inSpecCorpus disagrees with public/t27/manifest.json`)
  assert.equal(s.fields.ID, s.id)
  assert.equal(s.fields.KIND, 'skill')
  assertSummary(s, localesOf(skills))
  for (const id of s.runBy) assert.ok(cronIds.has(id), `${s.id}: runBy names ${id}, which has no cron spec`)
  for (const id of s.runBy) {
    const cron = crons.crons.find((c) => c.id === id)
    assert.ok(cron.runs.includes(s.id), `${s.id}: runBy ${id} but that cron's RUNS does not name it`)
  }
  // Management strip facts.
  assert.equal(canonicalSpecEditUrl(s.specPath), `https://github.com/gHashTag/t27/edit/master/${s.specPath}`)
  assert.equal(vendoredSpecUrl(s.specPath), `https://github.com/gHashTag/trinity/blob/main/apps/website/public/t27/files/${s.specPath}`)
  assert.equal(specSlug(s.specPath), s.specPath.replace(/^specs\/skills\//, '').replace(/\.t27$/, ''))
}
for (const id of skills.codeOnly) assert.ok(codeSkillIds.has(id) && !skillIds.has(id), `codeOnly ${id} is wrong`)
for (const id of codeSkillIds) assert.ok(skillIds.has(id) || skills.codeOnly.includes(id), `${id} is in code but neither spec nor codeOnly`)

for (const c of crons.crons) {
  const file = join('public/t27/files', c.specPath)
  assert.ok(existsSync(file), `${c.id}: ${c.specPath} is not in the vendored corpus`)
  assert.equal(sha256(readFileSync(file)), c.sha256, `${c.id}: the spec bytes changed under the catalog`)
  assert.equal(c.typecheckOk, true)
  assert.equal(c.discarded, 0)
  assert.ok(WITNESS.has(c.witness))
  assert.equal(c.witness, codeCronIds.has(c.id) ? 'spec+code' : 'spec-only', `${c.id}: witness disagrees with the code catalog`)
  assert.ok(HEALTH.has(c.health))
  assert.equal(c.fields.ID, c.id)
  assert.equal(c.fields.KIND, 'cron')
  assert.ok(HOSTS.includes(c.fields.HOST))
  assert.ok(CONTROLS.includes(c.control))
  assert.equal(c.control, c.fields.CONTROL)
  assert.ok(ON_FAILURE.includes(c.fields.ON_FAILURE))
  assertSummary(c, localesOf(crons))
  assert.deepEqual(c.runs, c.fields.RUNS)
  assert.equal(c.runsResolved.length, c.runs.length)
  for (const r of c.runsResolved) {
    assert.equal(r.ok, skillIds.has(r.id), `${c.id}: RUNS ${r.id} resolution is wrong`)
    if (!r.ok) assert.equal(c.health, 'fail', `${c.id}: an unresolved RUNS must read fail`)
    if (r.ok) assert.ok(skills.skills.find((s) => s.id === r.id).runBy.includes(c.id), `${c.id}: RUNS ${r.id} has no reverse runBy`)
  }
  if (c.fields.HOST === 'timer') {
    assert.ok(Number.isInteger(c.fields.INTERVAL_MS) && c.fields.INTERVAL_MS > 0)
    assert.equal(c.fields.SCHEDULE, undefined)
    assert.equal(c.control, 'code-only', `${c.id}: a timer cannot be controlled from outside its process`)
  } else {
    assert.equal(typeof c.fields.SCHEDULE, 'string')
    if (c.fields.SCHEDULE === '') assert.ok(c.fields.SCHEDULE_NOTE, `${c.id}: an empty SCHEDULE needs a note`)
  }
  // A cron that runs no skill must say so in its own words, not stay silent.
  if (c.runs.length === 0) assert.ok(c.fields.RUNS_NOTE.length > 0, `${c.id}: empty RUNS without RUNS_NOTE`)
  // Management strip facts: where "run now" goes, per host, never invented.
  const target = c.runNow
  if (c.fields.HOST === 'github-actions') {
    assert.equal(target.kind, 'link')
    assert.equal(target.url, `https://github.com/gHashTag/${c.fields.REPO}/actions/workflows/${c.fields.SERVICE.split('/').pop()}`)
  } else if (c.fields.HOST === 'railway-cron') {
    assert.equal(target.kind, 'link')
    assert.match(target.url, /^https:\/\/railway\.com\/project\/[0-9a-f-]{36}\/service\/[0-9a-f-]{36}$/)
  } else if (c.fields.HOST === 'inngest') {
    assert.equal(target.kind, 'link')
    assert.equal(target.url, 'https://inngestinngest-production-6a21.up.railway.app')
  } else {
    assert.equal(target.kind, 'disabled')
  }
  assert.equal(canonicalSpecEditUrl(c.specPath), `https://github.com/gHashTag/t27/edit/master/${c.specPath}`)
}
for (const id of crons.codeOnly) assert.ok(codeCronIds.has(id) && !cronIds.has(id), `codeOnly ${id} is wrong`)
for (const id of codeCronIds) assert.ok(cronIds.has(id) || crons.codeOnly.includes(id), `${id} is in code but neither spec nor codeOnly`)

// 4. The counts on the page are sums of the list.
assert.equal(skills.counts.specs, skills.skills.length)
assert.equal(skills.counts.specPlusCode, skills.skills.filter((s) => s.witness === 'spec+code').length)
assert.equal(skills.counts.codeOnly, skills.codeOnly.length)
assert.equal(skills.counts.runBy, skills.skills.filter((s) => s.runBy.length).length)
assert.equal(crons.counts.specs, crons.crons.length)
assert.equal(crons.counts.withRuns, crons.crons.filter((c) => c.runs.length).length)
for (const h of HOSTS) assert.equal(crons.counts.byHost[h], crons.crons.filter((c) => c.fields.HOST === h).length)

// 4b. Layer 4: the agent catalog. Exactly the alphabet, every skill link
//     resolved, crons derived from RUNS (never listed by hand), experience
//     joined by LETTER from the committed snapshot and adding up to it, links
//     pinned to one t27 ref, and the witness honest about zero episodes.
const AGENT_WITNESS = new Set(['spec+experience', 'spec-only'])
assert.equal(agents.agents.length, AGENT_COUNT, `${AGENTS_OUT}: ${agents.agents.length} agents, the alphabet has ${AGENT_COUNT}`)
assert.deepEqual(agents.agents.map((a) => a.letter), [...'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TI'], 'the agents are A..Z then TI, in ORDINAL order')
assert.deepEqual(agents.agents.map((a) => a.ordinal), Array.from({ length: AGENT_COUNT }, (_, i) => i + 1))
const agentIds = new Set(agents.agents.map((a) => a.id))
assert.equal(agentIds.size, agents.agents.length, 'duplicate agent ids')
assert.match(agents.pin.ref, /^([0-9a-f]{40}|master)$/, 'the pin is a commit sha or the default branch')
const t27Src = experience.sources.find((x) => x.repo === 't27')
if (t27Src) assert.equal(agents.pin.ref, t27Src.commit, 'links are pinned to the t27 commit the experience snapshot came from')
let attributedSum = 0
for (const a of agents.agents) {
  const file = join('public/t27/files', a.specPath)
  assert.ok(existsSync(file), `${a.id}: ${a.specPath} is not in the vendored corpus`)
  assert.equal(sha256(readFileSync(file)), a.sha256, `${a.id}: the spec bytes changed under the catalog`)
  assert.equal(a.specPath, `specs/agents/${a.letter.toLowerCase()}.t27`)
  assert.equal(a.typecheckOk, true)
  assert.equal(a.discarded, 0)
  assert.equal(a.fields.ID, a.id)
  assert.equal(a.id, `t27/${a.letter}`)
  assert.equal(a.fields.KIND, 'agent')
  assert.ok(AGENT_LAYERS.includes(a.fields.LAYER), `${a.id}: LAYER ${a.fields.LAYER}`)
  assert.match(a.fields.REGISTER, /^R(\d|1\d|2[0-6])$/, `${a.id}: REGISTER ${a.fields.REGISTER}`)
  assertSummary(a, localesOf(agents))
  for (const k of ['SOUL', 'AGENTS_DOC', 'ALPHABET']) assert.ok(a.fields[k].length > 0, `${a.id}: ${k} empty`)
  assert.equal(a.fields.SOUL, 'SOUL.md')
  assert.equal(a.fields.AGENTS_DOC, 'AGENTS.md')
  assert.equal(a.fields.ALPHABET, 'docs/agents/AGENTS_ALPHABET.md')
  assert.equal(a.links.soul, `https://github.com/gHashTag/t27/blob/${agents.pin.ref}/SOUL.md`)
  assert.equal(a.links.agentsDoc, `https://github.com/gHashTag/t27/blob/${agents.pin.ref}/AGENTS.md`)
  assert.equal(a.links.alphabet, `https://github.com/gHashTag/t27/blob/${agents.pin.ref}/docs/agents/AGENTS_ALPHABET.md`)
  // Skills: every one resolves, and an empty list explains itself.
  assert.deepEqual(a.skills.map((x) => x.id), a.fields.SKILLS)
  for (const x of a.skills) { assert.equal(x.ok, true, `${a.id}: SKILLS ${x.id} unresolved`); assert.ok(skillIds.has(x.id), `${a.id}: SKILLS ${x.id} has no skill spec`) }
  if (a.skills.length === 0) assert.ok(a.fields.SKILLS_NOTE.length > 0, `${a.id}: empty SKILLS without SKILLS_NOTE`)
  assert.equal(a.health, 'ok', `${a.id}: health ${a.health}: ${a.messages.join('; ')}`)
  // Crons: exactly the crons whose RUNS name one of the agent's skills.
  const expectCrons = crons.crons.filter((c) => c.runs.some((id) => a.fields.SKILLS.includes(id))).map((c) => c.id).sort()
  assert.deepEqual(a.crons, expectCrons, `${a.id}: crons are not derived from RUNS`)
  // Tools (layer 5): optional; when present, an empty list explains itself.
  assert.deepEqual(a.tools, a.fields.TOOLS ?? [])
  if ('TOOLS' in a.fields && a.fields.TOOLS.length === 0) assert.ok(a.fields.TOOLS_NOTE, `${a.id}: empty TOOLS without TOOLS_NOTE`)
  // Experience: joined by LETTER, witness follows the count, zero says so.
  const ex = experience.agents?.[a.letter]
  assert.equal(a.experience.episodes, ex?.episodes ?? 0, `${a.id}: experience join disagrees with ${EXPERIENCE_PATH}`)
  attributedSum += a.experience.episodes
  assert.ok(AGENT_WITNESS.has(a.witness))
  assert.equal(a.witness, a.experience.episodes > 0 ? 'spec+experience' : 'spec-only', `${a.id}: witness disagrees with the episode count`)
  if (a.experience.episodes === 0) assert.ok(a.messages.includes('no attributed episodes in the experience snapshot'), `${a.id}: zero episodes must be said`)
  if (a.experience.episodes > 0) assert.ok(a.experience.last && a.experience.files.length > 0, `${a.id}: episodes without last timestamp or files`)
  assert.equal(a.fields.ENABLED, a.letter !== 'TI', `${a.id}: only the reserved seat is disabled`)
  assert.equal(canonicalSpecEditUrl(a.specPath), `https://github.com/gHashTag/t27/edit/master/${a.specPath}`)
}
assert.equal(attributedSum, experience.counts.attributed, 'attributed episodes on the cards do not add up to the snapshot')
assert.equal(agents.counts.episodesAttributed, attributedSum)
assert.equal(agents.counts.episodesUnattributed, experience.unattributed.episodes)
assert.equal(agents.counts.episodesTotal, experience.counts.episodes)
assert.equal(experience.counts.attributed + experience.unattributed.episodes, experience.counts.episodes, 'the snapshot does not add up')
assert.equal(agents.counts.specs, agents.agents.length)
assert.equal(agents.counts.specPlusExperience, agents.agents.filter((a) => a.witness === 'spec+experience').length)
assert.equal(agents.counts.specOnly, agents.agents.filter((a) => a.witness === 'spec-only').length)
assert.equal(agents.counts.withSkills, agents.agents.filter((a) => a.skills.length).length)
assert.equal(agents.counts.withCrons, agents.agents.filter((a) => a.crons.length).length)
assert.equal(agents.counts.withExperience, agents.counts.specPlusExperience)
for (const l of AGENT_LAYERS) assert.equal(agents.counts.byLayer[l], agents.agents.filter((a) => a.fields.LAYER === l).length)
assert.deepEqual(agents.ladder, { specs: t27Manifest.specCount, skills: skills.skills.length, crons: crons.crons.length, agents: agents.agents.length }, 'the ladder counts are the catalogs')
// The snapshot's own attribution rule names the letters it can assign; every agent letter is among them.
for (const a of agents.agents) assert.ok(experience.attribution.letters.includes(a.letter), `${a.letter}: the attribution rule cannot assign this letter`)

// 5. The Queen knows the three explorer views, at the keys the modules list promises.
for (const tab of ['skills', 'crons', 'agents']) {
  const m = MODULES.find((x) => x.tab === tab)
  assert.ok(m, `queenModules has no ${tab} entry`)
  assert.ok(HUD_VIEWS.includes(tab), `HUD_VIEWS does not include ${tab}`)
  assert.equal(HUD_KEYS[HUD_VIEWS.indexOf(tab)], m.key, `${tab}: the key on the card (${m.key}) is not the keyboard key`)
  for (const lang of ['en', 'ru']) assert.ok(m[lang].name && m[lang].hint && m[lang].body.length > 40, `${tab}: ${lang} copy missing`)
}
assert.equal(MODULES.length, HUD_VIEWS.length, 'every module is a view and every view a module')
assert.ok(HUD_KEYS.length >= HUD_VIEWS.length, 'every view has a key')
assert.equal(new Set(HUD_KEYS).size, HUD_KEYS.length, 'keys are unique')
for (const [i, m] of MODULES.entries()) assert.equal(m.key, HUD_KEYS[i], `module ${m.tab} carries key ${m.key} at position ${i + 1} (expected ${HUD_KEYS[i]})`)
assert.equal(MODULES.find((m) => m.tab === 'agents').key, '9', 'AGENTS opens on 9')

// 6. Translations are connected through .t27 contract specs, never hardcoded.
//    Every specs/i18n/*.t27 the corpus carries is in both catalogs' i18n lists
//    (the vendored copy is English-only too); each contract's bundle exists at
//    the declared path, names the contract back, matches the locale, and every
//    entry resolves to a spec whose keys are within FIELDS (ORPHANS_ALLOWED is
//    false in the shipped contract). Coverage is printed, not asserted (the
//    contract says COVERAGE_REQUIRED false), unless the spec says otherwise.
const i18nDir = join('public/t27/files', I18N_SPEC_DIR)
const i18nSpecFiles = existsSync(i18nDir) ? readdirSync(i18nDir).filter((f) => f.endsWith('.t27')).sort() : []
assert.ok(i18nSpecFiles.length >= 1, `${I18N_SPEC_DIR}: at least the Russian contract (agents-ru.t27) must exist`)
assert.ok(i18nSpecFiles.includes('agents-ru.t27'), `${I18N_SPEC_DIR}/agents-ru.t27 is the Russian contract`)
for (const f of i18nSpecFiles) assert.ok(!CYRILLIC.test(readFileSync(join(i18nDir, f), 'utf8')), `${I18N_SPEC_DIR}/${f}: Cyrillic in a .t27 spec (LANG-EN)`)
assert.deepEqual(skills.i18n.map((l) => l.spec), i18nSpecFiles.map((f) => `${I18N_SPEC_DIR}/${f}`).sort((a, b) => a.localeCompare(b)), 'skills.i18n lists exactly the contract specs')
assert.deepEqual(crons.i18n.map((l) => l.spec).sort(), skills.i18n.map((l) => l.spec).sort(), 'both catalogs see the same contracts')
assert.deepEqual(agents.i18n.map((l) => l.spec).sort(), skills.i18n.map((l) => l.spec).sort(), 'the agent catalog sees the same contracts (SCOPE names specs/agents)')
const coverageLine = []
for (const l of skills.i18n) {
  const c = crons.i18n.find((x) => x.locale === l.locale)
  assert.ok(c, `${l.locale}: contract missing from crons.i18n`)
  const ag = agents.i18n.find((x) => x.locale === l.locale)
  assert.ok(ag, `${l.locale}: contract missing from agents.i18n`)
  assert.ok(l.scope.includes('specs/agents'), `${l.spec}: SCOPE must name specs/agents`)
  assert.equal(l.sha256, sha256(readFileSync(join('public/t27/files', l.spec))), `${l.spec}: sha256 in the catalog is not the vendored file`)
  assert.ok(existsSync(join(REPO_ROOT, l.bundle)), `${l.spec}: bundle ${l.bundle} does not exist`)
  const bundle = JSON.parse(readFileSync(join(REPO_ROOT, l.bundle), 'utf8'))
  assert.equal(bundle.$spec, l.spec, `${l.bundle}: $spec must name its contract`)
  assert.equal(bundle.locale, l.locale, `${l.bundle}: locale must match the contract`)
  for (const field of l.fields) assert.ok(field in I18N_FIELD_SOURCE, `${l.spec}: FIELDS ${field} backed by no spec constant`)
  const ids = new Set([...skillIds, ...cronIds, ...agentIds])
  for (const [id, entry] of Object.entries(bundle.entries)) {
    assert.ok(ids.has(id), `${l.bundle}: orphan entry ${id} (ORPHANS_ALLOWED is false)`)
    for (const k of Object.keys(entry)) assert.ok(l.fields.includes(k), `${l.bundle}: ${id}.${k} not in FIELDS ${l.fields.join(',')}`)
  }
  // Coverage in the catalog equals what the bundle actually gives each entry.
  const has = (list) => list.filter((e) => e.summary[l.locale] || e.name[l.locale]).length
  assert.equal(l.coverage.n, has(skills.skills), `${l.locale}: skills coverage n mismatch`)
  assert.equal(l.coverage.total, skills.skills.length)
  assert.equal(c.coverage.n, has(crons.crons), `${l.locale}: crons coverage n mismatch`)
  assert.equal(c.coverage.total, crons.crons.length)
  assert.equal(ag.coverage.n, has(agents.agents), `${l.locale}: agents coverage n mismatch`)
  assert.equal(ag.coverage.total, agents.agents.length)
  assert.equal(l.missing.length, l.coverage.total - l.coverage.n)
  coverageLine.push(`${l.locale} via ${l.spec}${l.enabled ? '' : ' (off)'}: skills ${l.coverage.n}/${l.coverage.total}, crons ${c.coverage.n}/${c.coverage.total}, agents ${ag.coverage.n}/${ag.coverage.total}, orphans 0`)
}

console.log(
  `agents-spec-contract: skills ${skills.skills.length} (spec+code ${skills.counts.specPlusCode}, spec-only ${skills.counts.specOnly}, code-only ${skills.counts.codeOnly}, run by a cron ${skills.counts.runBy}); ` +
  `crons ${crons.crons.length} (spec+code ${crons.counts.specPlusCode}, spec-only ${crons.counts.specOnly}, code-only ${crons.counts.codeOnly}, with RUNS ${crons.counts.withRuns}); ` +
  `in vendored corpus manifest: ${skills.skills.filter((s) => s.inSpecCorpus).length + crons.crons.filter((c) => c.inSpecCorpus).length}/${skills.skills.length + crons.crons.length}; ` +
  `agents ${agents.agents.length} (spec+experience ${agents.counts.specPlusExperience}, spec-only ${agents.counts.specOnly}, with skills ${agents.counts.withSkills}, with crons ${agents.counts.withCrons}; episodes attributed ${agents.counts.episodesAttributed}, unattributed ${agents.counts.episodesUnattributed}, unreadable files ${experience.counts.unreadableFiles}; links pinned at ${agents.pin.ref.slice(0, 7)}); ` +
  `Queen views ${HUD_VIEWS.length}, modules ${MODULES.length}, keys ${HUD_KEYS.slice(0, HUD_VIEWS.length).join('')}; ` +
  `i18n contracts ${skills.i18n.length} [${coverageLine.join('; ')}]`,
)
