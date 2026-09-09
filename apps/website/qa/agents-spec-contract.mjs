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
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { generate, SKILLS_OUT, CRONS_OUT, HOSTS, CONTROLS, ON_FAILURE } from '../scripts/agents-from-specs.mjs'
import { canonicalSpecEditUrl, vendoredSpecUrl, specSlug } from '../src/lib/agentSpecs.ts'
import { MODULES } from '../src/lib/queenModules.ts'
import { HUD_VIEWS } from '../src/components/queenHud.ts'

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')
const skills = JSON.parse(readFileSync(SKILLS_OUT, 'utf8'))
const crons = JSON.parse(readFileSync(CRONS_OUT, 'utf8'))
const skillsCode = JSON.parse(readFileSync('public/skills/manifest.json', 'utf8'))
const cronsCode = JSON.parse(readFileSync('public/crons/manifest.json', 'utf8'))
const t27Manifest = JSON.parse(readFileSync('public/t27/manifest.json', 'utf8'))
const corpusPaths = new Set(t27Manifest.specs.map((s) => s.path))

// 1. The committed output is what the specs produce today.
const fresh = await generate({ generatedAt: skills.generatedAt })
assert.deepEqual(fresh.problems, [], 'the generator reports problems:\n' + fresh.problems.join('\n'))
assert.equal(skills.contentSha256, fresh.skills.contentSha256, `${SKILLS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
assert.equal(crons.contentSha256, fresh.crons.contentSha256, `${CRONS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
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
for (const [name, text] of [['spec-skills', JSON.stringify(skills)], ['spec-crons', JSON.stringify(crons)]]) {
  for (const f of FORBIDDEN) {
    const hit = f.re.exec(text)
    assert.ok(!hit, `${name} carries something shaped like a ${f.name} (${hit ? hit[0].slice(0, 4) : ''}…)`)
  }
}

// 3. Every entry: a real file, the right bytes, an honest witness.
const WITNESS = new Set(['spec+code', 'spec-only'])
const HEALTH = new Set(['ok', 'warn', 'fail'])
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
  assert.ok(s.fields.SUMMARY_RU.length > 10 && s.fields.SUMMARY_EN.length > 10, `${s.id}: a summary is missing`)
  assert.ok(/[а-яА-ЯёЁ]/.test(s.fields.SUMMARY_RU), `${s.id}: SUMMARY_RU is not Russian`)
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
  assert.ok(/[а-яА-ЯёЁ]/.test(c.fields.SUMMARY_RU), `${c.id}: SUMMARY_RU is not Russian`)
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

// 5. The Queen knows both views, at the keys the modules list promises.
for (const tab of ['skills', 'crons']) {
  const m = MODULES.find((x) => x.tab === tab)
  assert.ok(m, `queenModules has no ${tab} entry`)
  assert.ok(HUD_VIEWS.includes(tab), `HUD_VIEWS does not include ${tab}`)
  assert.equal(String(HUD_VIEWS.indexOf(tab) + 1), m.key, `${tab}: the key on the card (${m.key}) is not the keyboard digit`)
  for (const lang of ['en', 'ru']) assert.ok(m[lang].name && m[lang].hint && m[lang].body.length > 40, `${tab}: ${lang} copy missing`)
}
assert.equal(MODULES.length, HUD_VIEWS.length, 'every module is a view and every view a module')
for (const [i, m] of MODULES.entries()) assert.equal(m.key, String(i + 1), `module ${m.tab} carries key ${m.key} at position ${i + 1}`)

console.log(
  `agents-spec-contract: skills ${skills.skills.length} (spec+code ${skills.counts.specPlusCode}, spec-only ${skills.counts.specOnly}, code-only ${skills.counts.codeOnly}, run by a cron ${skills.counts.runBy}); ` +
  `crons ${crons.crons.length} (spec+code ${crons.counts.specPlusCode}, spec-only ${crons.counts.specOnly}, code-only ${crons.counts.codeOnly}, with RUNS ${crons.counts.withRuns}); ` +
  `in vendored corpus manifest: ${skills.skills.filter((s) => s.inSpecCorpus).length + crons.crons.filter((c) => c.inSpecCorpus).length}/${skills.skills.length + crons.crons.length}; ` +
  `Queen views ${HUD_VIEWS.length}, modules ${MODULES.length}`,
)
