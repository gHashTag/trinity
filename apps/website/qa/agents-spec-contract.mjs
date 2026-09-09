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
import { generate, SKILLS_OUT, CRONS_OUT, AGENTS_OUT, FUNCTIONS_OUT, TOOLS_OUT, FUNCTIONS_MANIFEST, EXPERIENCE_PATH, AGENT_COUNT, AGENT_LAYERS, HOSTS, CONTROLS, ON_FAILURE, FN_TRIGGERS, FN_ON_FAILURE, FN_SIDE_EFFECTS, FN_PROBE_RESULTS, FN_CONTROLS, functionDifferences, I18N_SPEC_DIR, I18N_FIELD_SOURCE, REPO_ROOT } from '../scripts/agents-from-specs.mjs'
import { canonicalSpecEditUrl, vendoredSpecUrl, specSlug } from '../src/lib/agentSpecs.ts'
import { MODULES } from '../src/lib/queenModules.ts'
import { HUD_VIEWS, HUD_KEYS } from '../src/components/queenHud.ts'

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')
const skills = JSON.parse(readFileSync(SKILLS_OUT, 'utf8'))
const crons = JSON.parse(readFileSync(CRONS_OUT, 'utf8'))
const agents = JSON.parse(readFileSync(AGENTS_OUT, 'utf8'))
const functions = JSON.parse(readFileSync(FUNCTIONS_OUT, 'utf8'))
const functionsCode = JSON.parse(readFileSync(FUNCTIONS_MANIFEST, 'utf8'))
const tools = JSON.parse(readFileSync(TOOLS_OUT, 'utf8'))
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
assert.equal(functions.contentSha256, fresh.functions.contentSha256, `${FUNCTIONS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
assert.equal(functions.compilerWasmSha256, skills.compilerWasmSha256)
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
for (const [name, text] of [['spec-skills', JSON.stringify(skills)], ['spec-crons', JSON.stringify(crons)], ['spec-agents', JSON.stringify(agents)], ['spec-functions', JSON.stringify(functions)], ['functions-manifest', JSON.stringify(functionsCode)], ['experience', JSON.stringify(experience)]]) {
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
  // Tools (layer 5): every ID resolves to a tool spec that names the letter back; an empty list explains itself.
  assert.deepEqual(a.tools.map((x) => x.id), a.fields.TOOLS ?? [])
  for (const x of a.tools) {
    assert.equal(x.ok, true, `${a.id}: TOOLS ${x.id} unresolved`)
    const tl = tools.tools.find((t) => t.id === x.id)
    assert.ok(tl, `${a.id}: TOOLS ${x.id} has no tool spec`)
    assert.ok(tl.agents.some((g) => g.letter === a.letter), `${a.id}: ${x.id} does not name ${a.letter} in AGENTS`)
  }
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
assert.equal(agents.counts.withTools, agents.agents.filter((a) => a.tools.length).length)
assert.equal(agents.counts.withExperience, agents.counts.specPlusExperience)
for (const l of AGENT_LAYERS) assert.equal(agents.counts.byLayer[l], agents.agents.filter((a) => a.fields.LAYER === l).length)
assert.deepEqual(agents.ladder, { specs: t27Manifest.specCount, skills: skills.skills.length, crons: crons.crons.length, agents: agents.agents.length, tools: tools.tools.length, functions: functions.functions.length }, 'the ladder counts are the catalogs, tools and functions included')
// The snapshot's own attribution rule names the letters it can assign; every agent letter is among them.
for (const a of agents.agents) assert.ok(experience.attribution.letters.includes(a.letter), `${a.letter}: the attribution rule cannot assign this letter`)

// 4b. Layer five: every function spec is a card, witnessed by the vendored
//     functions manifest (public/functions/manifest.json), with the spec first
//     and the manifest's own reading beside it; where they differ the card says so.
const codeFns = new Map(functionsCode.functions.map((f) => [f.id, f]))
assert.equal(functions.functions.length, codeFns.size, `${FUNCTIONS_OUT}: ${functions.functions.length} specs against ${codeFns.size} manifest entries`)
assert.deepEqual(functions.codeOnly, [], 'every manifest function has a spec (none is code-only)')
assert.equal(functions.manifest.repo, functionsCode.repo)
assert.equal(functions.manifest.entries, functionsCode.functions.length)
assert.match(functions.manifest.generatedFrom.commit, /^[0-9a-f]{7,40}$/, 'the manifest names the commit it was read from')
const functionIds = new Set(functions.functions.map((f) => f.id))
assert.equal(functionIds.size, functions.functions.length, 'duplicate function ids')
assert.deepEqual(functions.functions.map((f) => f.id), [...functionIds].sort(), 'functions are sorted by id')
const cronIdSet = new Set(crons.crons.map((c) => c.id))
for (const f of functions.functions) {
  const x = f.fields
  assert.equal(x.KIND, 'function', `${f.id}: KIND`)
  assert.equal(x.ID, f.id, `${f.id}: ID is the file name`)
  assert.equal(f.specPath, `specs/functions/${f.id}.t27`)
  assert.equal(f.moduleName, `fn_${f.id.replace(/-/g, '_')}`)
  assert.equal(specSlug(f.specPath), f.id)
  assert.ok(f.typecheckOk, `${f.id}: the compiler rejected the spec`)
  assert.equal(x.REPO, '999-multibots-telegraf')
  assert.ok(FN_TRIGGERS.includes(x.TRIGGER), `${f.id}: TRIGGER ${x.TRIGGER}`)
  assert.ok(FN_ON_FAILURE.includes(x.ON_FAILURE), `${f.id}: ON_FAILURE ${x.ON_FAILURE}`)
  assert.ok(FN_PROBE_RESULTS.includes(x.PROBE_RESULT), `${f.id}: PROBE_RESULT ${x.PROBE_RESULT}`)
  assert.ok(FN_CONTROLS.includes(x.CONTROL), `${f.id}: CONTROL ${x.CONTROL}`)
  assert.ok(Array.isArray(x.SIDE_EFFECTS) && x.SIDE_EFFECTS.length >= 1, `${f.id}: SIDE_EFFECTS names at least one effect (or none)`)
  for (const se of x.SIDE_EFFECTS) assert.ok(FN_SIDE_EFFECTS.includes(se), `${f.id}: side effect ${se}`)
  assert.ok(Array.isArray(x.STEPS) && x.STEPS.length >= 1, `${f.id}: STEPS in source order`)
  assert.ok(Number.isInteger(x.RETRIES) && x.RETRIES >= 0, `${f.id}: RETRIES`)
  assert.match(x.SERVICE, /^src\/inngest_app\/functions\/.+\.ts:\d+$/, `${f.id}: SERVICE is file:line under src/inngest_app/functions`)
  if (x.TRIGGER === 'event') {
    assert.ok(x.EVENT.length > 0 && x.CRON === '', `${f.id}: an event function has EVENT, not CRON`)
    assert.equal(f.cronSpec, null, `${f.id}: an event function joins no cron card`)
  } else {
    assert.ok(x.CRON.length > 0 && x.EVENT === '', `${f.id}: a cron function has CRON, not EVENT`)
    assert.equal(x.LEGACY_EVENTS.length, 0, `${f.id}: a cron function has no legacy events`)
    assert.ok(f.cronSpec && cronIdSet.has(f.cronSpec), `${f.id}: its cron card ${f.cronSpec} is in the crons catalog`)
    assert.equal(f.cronSpec, `inngest/999-multibots-telegraf/${x.LEGACY_ID}`, `${f.id}: the cron card is joined by host, repo and legacy id`)
  }
  if (x.SAFE_PROBE) JSON.parse(x.SAFE_PROBE)
  assertSummary(f, localesOf(functions))
  // Witness: the manifest entry with the same id, read verbatim; differences are computed, not asserted away.
  const code = codeFns.get(f.id)
  assert.ok(code, `${f.id}: no manifest entry — the generator must have marked it spec-only`)
  assert.equal(f.witness, 'spec+code')
  assert.equal(f.code.legacyId, code.legacy_id)
  assert.equal(f.code.file, code.file || null, `${f.id}: an empty manifest file is null on the card, never an invented path`)
  assert.equal(f.code.deployed, code.deployed_2026_09_09)
  assert.equal(f.code.probeResult, code.probe_result)
  assert.deepEqual(f.differences, functionDifferences(x, code), `${f.id}: differences are exactly what the generator computes`)
  if (f.code.deployed === false) {
    assert.equal(x.PROBE_RESULT, 'not-deployed', `${f.id}: a function not on the production build has PROBE_RESULT not-deployed`)
    assert.ok(f.messages.some((m) => /not on the production build/.test(m)), `${f.id}: the card says it is not deployed`)
  }
  if (f.differences.length) assert.equal(f.health, 'warn', `${f.id}: a difference from the manifest is a warning`)
  for (const d of f.differences) assert.ok(f.messages.some((m) => m.startsWith(d.field)), `${f.id}: difference ${d.field} is stated on the card`)
}
assert.equal(functions.counts.specs, functions.functions.length)
assert.equal(functions.counts.specPlusCode, functions.functions.filter((f) => f.witness === 'spec+code').length)
assert.equal(functions.counts.specOnly, functions.functions.filter((f) => f.witness === 'spec-only').length)
assert.equal(functions.counts.codeOnly, functions.codeOnly.length)
assert.equal(functions.counts.deployed, functions.functions.filter((f) => f.code?.deployed === true).length)
assert.equal(functions.counts.notDeployed, functions.functions.filter((f) => f.code?.deployed === false).length)
assert.equal(functions.counts.deployed + functions.counts.notDeployed + functions.counts.deployUnknown, functions.functions.length)
assert.equal(functions.counts.withCronSpec, functions.functions.filter((f) => f.cronSpec).length)
assert.equal(functions.counts.withCronSpec, functions.counts.byTrigger.cron, 'every cron function has its cron card')
assert.equal(functions.counts.withDifferences, functions.functions.filter((f) => f.differences.length).length)
for (const t of FN_TRIGGERS) assert.equal(functions.counts.byTrigger[t], functions.functions.filter((f) => f.fields.TRIGGER === t).length)
for (const s of FN_SIDE_EFFECTS) assert.equal(functions.counts.bySideEffect[s], functions.functions.filter((f) => f.fields.SIDE_EFFECTS.includes(s)).length)
for (const p of FN_PROBE_RESULTS) assert.equal(functions.counts.byProbeResult[p], functions.functions.filter((f) => f.fields.PROBE_RESULT === p).length)
assert.deepEqual(functions.ladder, agents.ladder, 'the functions catalog shows the same ladder as the agents catalog')
// The deployed app the manifest describes registers as many functions as the manifest lists.
assert.equal(functionsCode.deployedApp.mainRegisters, functionsCode.functions.length, 'main registers every manifest function')
assert.equal(functionsCode.deployedApp.baseFunctions, functions.counts.deployed, 'the production build carries exactly the deployed functions')

// 5. The Queen knows the five explorer views, at the keys the modules list promises.
for (const tab of ['skills', 'crons', 'agents', 'functions', 'tools']) {
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
assert.equal(MODULES.find((m) => m.tab === 'functions').key, '0', 'FUNCTIONS opens on 0, the tenth key')
assert.equal(MODULES.find((m) => m.tab === 'tools').key, 't', 'TOOLS opens on t: the digits are spent after FUNCTIONS on 0')

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
  assert.ok(l.scope.includes('specs/tools'), `${l.spec}: SCOPE must name specs/tools`)
  assert.equal(l.sha256, sha256(readFileSync(join('public/t27/files', l.spec))), `${l.spec}: sha256 in the catalog is not the vendored file`)
  assert.ok(existsSync(join(REPO_ROOT, l.bundle)), `${l.spec}: bundle ${l.bundle} does not exist`)
  const bundle = JSON.parse(readFileSync(join(REPO_ROOT, l.bundle), 'utf8'))
  assert.equal(bundle.$spec, l.spec, `${l.bundle}: $spec must name its contract`)
  assert.equal(bundle.locale, l.locale, `${l.bundle}: locale must match the contract`)
  for (const field of l.fields) assert.ok(field in I18N_FIELD_SOURCE, `${l.spec}: FIELDS ${field} backed by no spec constant`)
  const fn = functions.i18n.find((x) => x.locale === l.locale)
  assert.ok(fn, `${l.locale}: contract missing from functions.i18n`)
  assert.ok(l.scope.includes('specs/functions'), `${l.spec}: SCOPE must name specs/functions`)
  const tl = tools.i18n.find((x) => x.locale === l.locale)
  assert.ok(tl, `${l.locale}: contract missing from tools.i18n`)
  const ids = new Set([...skillIds, ...cronIds, ...agentIds, ...functionIds, ...tools.tools.map((t) => t.id)])
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
  assert.equal(fn.coverage.n, has(functions.functions), `${l.locale}: functions coverage n mismatch`)
  assert.equal(fn.coverage.total, functions.functions.length)
  assert.equal(l.missing.length, l.coverage.total - l.coverage.n)
  coverageLine.push(`${l.locale} via ${l.spec}${l.enabled ? '' : ' (off)'}: skills ${l.coverage.n}/${l.coverage.total}, crons ${c.coverage.n}/${c.coverage.total}, agents ${ag.coverage.n}/${ag.coverage.total}, functions ${fn.coverage.n}/${fn.coverage.total}, orphans 0`)
}

console.log(
  `agents-spec-contract: skills ${skills.skills.length} (spec+code ${skills.counts.specPlusCode}, spec-only ${skills.counts.specOnly}, code-only ${skills.counts.codeOnly}, run by a cron ${skills.counts.runBy}); ` +
  `crons ${crons.crons.length} (spec+code ${crons.counts.specPlusCode}, spec-only ${crons.counts.specOnly}, code-only ${crons.counts.codeOnly}, with RUNS ${crons.counts.withRuns}); ` +
  `in vendored corpus manifest: ${skills.skills.filter((s) => s.inSpecCorpus).length + crons.crons.filter((c) => c.inSpecCorpus).length}/${skills.skills.length + crons.crons.length}; ` +
  `agents ${agents.agents.length} (spec+experience ${agents.counts.specPlusExperience}, spec-only ${agents.counts.specOnly}, with skills ${agents.counts.withSkills}, with crons ${agents.counts.withCrons}; episodes attributed ${agents.counts.episodesAttributed}, unattributed ${agents.counts.episodesUnattributed}, unreadable files ${experience.counts.unreadableFiles}; links pinned at ${agents.pin.ref.slice(0, 7)}); ` +
  `functions ${functions.functions.length} (spec+code ${functions.counts.specPlusCode}, spec-only ${functions.counts.specOnly}, code-only ${functions.counts.codeOnly}; deployed ${functions.counts.deployed}, not deployed ${functions.counts.notDeployed}, unknown ${functions.counts.deployUnknown}; differences from the manifest ${functions.counts.withDifferences}; cron cards ${functions.counts.withCronSpec}/${functions.counts.byTrigger.cron}; manifest ${functions.manifest.repo}@${functions.manifest.generatedFrom.commit.slice(0, 7)}); ` +
  `Queen views ${HUD_VIEWS.length}, modules ${MODULES.length}, keys ${HUD_KEYS.slice(0, HUD_VIEWS.length).join('')}; ` +
  `i18n contracts ${skills.i18n.length} [${coverageLine.join('; ')}]`,
)
