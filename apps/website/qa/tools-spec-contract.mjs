// Layer 5: the tools catalog, checked against what it claims.
//
// public/tools/spec-tools.json is written by scripts/agents-from-specs.mjs
// from the .t27 files under public/t27/files/specs/tools/{tri,mcp,trinity/tri}/ --
// through the real compiler, not a regex. The tri family is one card per clap variant
// of `tri` (gHashTag/t27 cli/tri/src/main.rs) plus, since S06 of gHashTag/trinity#988,
// one card per command the gHashTag/trinity tri exports (.trinity/registry.json); the
// mcp family one card per MCP server registered in either repository. Schema 2
// (specs/tools/catalog.t27): every card carries REPO, QUALIFIED_ID and SCHEMA = 2, a
// legacy card keeps its short ID and the catalog's legacy table maps it, a Trinity card
// is qualified only, and a same-named command of the two binaries is a recorded collision. This gate asks what a generated file
// can still fail: is the committed JSON what the specs produce today; does every
// card point at a vendored file whose bytes hash to what it says; is every
// ABOUT and every in-repo TOOLS list non-empty (an external package says so in
// TOOLS_NOTE instead); does every AGENTS letter exist and does that agent name
// the tool back; is every skill cross-link backed by the skill's own text; does
// the witness stay one of the two honest labels; is the search index the card;
// and does the Queen open the view on the promised key.
//
//   node --experimental-strip-types qa/tools-spec-contract.mjs

import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { generate, TOOLS_OUT, AGENTS_OUT, SKILLS_OUT, TOOL_SPEC_DIR, TOOL_SPEC_SUBDIRS, TOOL_FAMILIES, TOOL_WITNESSES, TOOL_SCHEMA, TOOL_REPO_OF_SUBDIR, summarySourceOf } from '../scripts/agents-from-specs.mjs'
import { canonicalSpecEditUrl, vendoredSpecUrl } from '../src/lib/agentSpecs.ts'
import { MODULES } from '../src/lib/queenModules.ts'
import { HUD_VIEWS, HUD_KEYS } from '../src/components/queenHud.ts'

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')
const tools = JSON.parse(readFileSync(TOOLS_OUT, 'utf8'))
const agents = JSON.parse(readFileSync(AGENTS_OUT, 'utf8'))
const skills = JSON.parse(readFileSync(SKILLS_OUT, 'utf8'))
const CYRILLIC = /[\u0400-\u04ff]/
const HOME_PATH = /(^|[\s"'=:(])(\/Users\/|\/home\/|[A-Z]:\\Users\\)/

// 1. The committed output is what the specs produce today.
const fresh = await generate({ generatedAt: tools.generatedAt })
assert.deepEqual(fresh.problems, [], 'the generator reports problems:\n' + fresh.problems.join('\n'))
assert.equal(tools.contentSha256, fresh.tools.contentSha256, `${TOOLS_OUT} is stale or hand-edited; run node scripts/agents-from-specs.mjs`)
assert.equal(tools.compilerWasmSha256, sha256(readFileSync('public/t27/t27_compiler.wasm')), 'the catalog names a compiler other than the vendored one')

// 2. Exactly the vendored files, one card each; the three corpus specs at the top of specs/tools/ are not cards.
const vendored = TOOL_SPEC_SUBDIRS.flatMap((sub) => readdirSync(join('public/t27/files', TOOL_SPEC_DIR, sub)).filter((f) => f.endsWith('.t27')).map((f) => `${TOOL_SPEC_DIR}/${sub}/${f}`)).sort()
assert.deepEqual(tools.tools.map((t) => t.specPath).sort(), vendored, 'the catalog is exactly the vendored specs/tools/{tri,mcp,trinity/tri} files')
assert.ok(tools.tools.length >= 50, `${tools.tools.length} tool cards; the tri CLI alone has more than 50 commands`)
const ids = new Set(tools.tools.map((t) => t.id))
assert.equal(ids.size, tools.tools.length, 'duplicate tool ids')
assert.deepEqual(tools.tools.map((t) => t.id), [...ids].sort(), 'cards are sorted by id')

// 3. Every card: the right bytes, English-only spec, non-empty ABOUT, honest witness, resolved links.
const letters = new Set(agents.agents.map((a) => a.letter))
const skillById = new Map(skills.skills.map((s) => [s.id, s]))
const locales = new Set(tools.i18n.map((l) => l.locale))
for (const t of tools.tools) {
  const file = join('public/t27/files', t.specPath)
  assert.ok(existsSync(file), `${t.id}: ${t.specPath} is not in the vendored corpus`)
  const text = readFileSync(file, 'utf8')
  assert.equal(sha256(readFileSync(file)), t.sha256, `${t.id}: the spec bytes changed under the catalog`)
  assert.ok(!CYRILLIC.test(text), `${t.specPath}: Cyrillic in a .t27 spec (LANG-EN)`)
  assert.ok(!HOME_PATH.test(text), `${t.specPath}: a developer home path in a spec`)
  assert.equal(t.typecheckOk, true)
  assert.equal(t.discarded, 0)
  assert.equal(t.fields.KIND, 'tool')
  assert.equal(t.fields.ID, t.id)
  const pm = new RegExp(`^${TOOL_SPEC_DIR}/(tri|mcp|trinity/tri)/([^/]+)\\.t27$`).exec(t.specPath)
  assert.ok(pm, `${t.id}: ${t.specPath} is not under a tools sub-directory`)
  const [, sub, base] = pm
  assert.equal(t.family, TOOL_FAMILIES[sub])
  assert.equal(t.fields.FAMILY, t.family)
  assert.equal(t.moduleName, `tool_${sub.replace('/', '_')}_${base.replace(/[^A-Za-z0-9]+/g, '_')}`)
  // Schema 2: REPO, QUALIFIED_ID = REPO:<family>/<name>, SCHEMA = 2; a legacy card keeps the short ID.
  assert.equal(t.schema, TOOL_SCHEMA, `${t.id}: schema ${t.schema}`)
  assert.equal(t.fields.SCHEMA, TOOL_SCHEMA)
  assert.equal(t.repo, sub === 'mcp' ? t.fields.REPO : TOOL_REPO_OF_SUBDIR[sub])
  assert.equal(t.fields.REPO, t.repo)
  const shortId = `${sub === 'trinity/tri' ? 'tri' : sub}/${base}`
  assert.equal(t.qualifiedId, `${t.repo}:${shortId}`)
  assert.equal(t.fields.QUALIFIED_ID, t.qualifiedId)
  if (sub === 'trinity/tri') assert.equal(t.id, t.qualifiedId, `${t.id}: a Trinity card is qualified only`)
  else { assert.equal(t.id, shortId); assert.equal(tools.legacy[t.id], t.qualifiedId, `${t.id}: the legacy table must map it`) }
  assert.ok(TOOL_WITNESSES.includes(t.witness), `${t.id}: witness ${t.witness}`)
  assert.equal(t.witness, t.fields.WITNESS)
  assert.ok(t.fields.ABOUT.trim().length > 10, `${t.id}: ABOUT is empty`)
  assert.ok(t.fields.ABOUT_SOURCE.trim().length > 0, `${t.id}: ABOUT_SOURCE is empty (where did the text come from?)`)
  assert.equal(t.summary.en, summarySourceOf(t.fields))
  for (const k of Object.keys(t.summary)) assert.ok(k === 'en' || locales.has(k), `${t.id}: summary.${k} has no contract spec`)
  if (t.summary.ru) assert.ok(CYRILLIC.test(t.summary.ru), `${t.id}: summary.ru is not Russian`)
  // Agents: letters exist and point back.
  assert.deepEqual(t.agents.map((a) => a.letter), t.fields.AGENTS)
  for (const a of t.agents) {
    assert.equal(a.ok, true, `${t.id}: AGENTS ${a.letter} unresolved`)
    assert.ok(letters.has(a.letter), `${t.id}: AGENTS ${a.letter} is not in the alphabet`)
    const agent = agents.agents.find((x) => x.letter === a.letter)
    assert.ok(agent.tools.some((x) => x.id === t.id), `${t.id}: ${a.letter} does not name it back in TOOLS`)
  }
  if (t.agents.length === 0) assert.ok(t.fields.AGENTS_NOTE.length > 0, `${t.id}: empty AGENTS without AGENTS_NOTE`)
  assert.equal(t.health, 'ok', `${t.id}: health ${t.health}: ${t.messages.join('; ')}`)
  // Skills: each cross-link is backed by the skill's own COMMAND/SUMMARY_EN naming the command.
  for (const s of t.skills) {
    const sk = skillById.get(s.id)
    assert.ok(sk, `${t.id}: skills names ${s.id}, which has no skill spec`)
    assert.ok(s.via.length > 0)
    for (const via of s.via) assert.ok(new RegExp(`tri\\s+${base.replace(/[-/\\\\^$*+?.()|[\]{}]/g, '\\$&')}(?![A-Za-z0-9_-])`).test(sk.fields[via]), `${t.id}: ${s.id}.${via} does not name ${t.command ?? t.id}`)
  }
  // Links: source at the pinned ref, config only when the spec names one.
  const repoUrl = `https://github.com/${t.repo}`
  assert.equal(t.links.source, `${repoUrl}/blob/${t.links.pinnedAt}/${t.fields.SOURCE}`)
  assert.match(t.links.pinnedAt, /^([0-9a-f]{40}|master|main)$/)
  if (t.family === 'tri-cli' && sub === 'trinity/tri') {
    assert.equal(t.repo, 'gHashTag/trinity')
    assert.equal(t.command, `tri ${base}`)
    assert.equal(t.fields.COMMAND, t.command)
    assert.equal(t.fields.SOURCE, 'src/registry/command_table.zig')
    assert.equal(t.witness, 'registry-export', `${t.id}: a Trinity card's witness is the registry export`)
    assert.ok(t.witnessSource.includes('.trinity/registry.json'), `${t.id}: WITNESS_SOURCE names the export`)
    assert.equal(t.routing.routed, t.routing.kind !== 'none')
    assert.ok(['execute_map', 'parse_command', 'main_chain', 'cell_map', 'none'].includes(t.routing.kind))
    assert.equal(t.registry.mcpEnabled, true, `${t.id}: the export keeps mcp_enabled commands only`)
    assert.match(t.registry.mcpName, /^tri_[a-z0-9_]+$/)
    assert.ok(t.exitCodes.length >= 1 && t.result.length > 0)
    assert.deepEqual(t.skills, [], `${t.id}: skills name the t27 tri, never a Trinity command`)
    assert.equal(t.links.config, null)
    if (t.collidesWith) { assert.ok(ids.has(t.collidesWith.split(':')[1]), `${t.id}: COLLIDES_WITH ${t.collidesWith} names no t27 card`); assert.ok(tools.collisions.some((c) => c.trinity === t.id), `${t.id}: collision not in the table`) }
  } else if (t.family === 'tri-cli') {
    assert.equal(t.repo, 'gHashTag/t27')
    assert.equal(t.links.pinnedAt, tools.pin.ref, `${t.id}: t27 links pin to the catalog ref`)
    assert.equal(t.command, `tri ${base}`)
    assert.equal(t.fields.COMMAND, t.command)
    assert.match(t.fields.SOURCE, /^cli\/tri\/src\/.+\.rs$/)
    assert.equal(t.actions.length, t.fields.ACTIONS.length)
    assert.equal(t.fields.ACTIONS_ABOUT.length, t.fields.ACTIONS.length)
    assert.equal(t.links.config, null)
    assert.ok(t.whenToUse.length > 0, `${t.id}: WHEN_TO_USE empty`)
  } else {
    assert.ok(['gHashTag/t27', 'gHashTag/trinity'].includes(t.repo))
    assert.ok(['stdio', 'http'].includes(t.transport))
    assert.equal(t.tools.length, t.fields.TOOLS.length)
    assert.equal(t.fields.TOOLS_ABOUT.length, t.fields.TOOLS.length)
    assert.equal(t.fields.TOOLS_INPUTS.length, t.fields.TOOLS.length)
    assert.equal(t.resources.length, t.fields.RESOURCES.length)
    if (t.tools.length === 0) {
      assert.equal(t.external, true, `${t.id}: an in-repo server must list its tools`)
      assert.ok(t.fields.TOOLS_NOTE.length > 0, `${t.id}: empty TOOLS without TOOLS_NOTE`)
    }
    if (t.fields.CONFIG) assert.equal(t.links.config, `${repoUrl}/blob/${t.links.pinnedAt}/${t.fields.CONFIG}`)
    else assert.equal(t.links.config, null)
    assert.ok(t.launch.length > 0, `${t.id}: LAUNCH empty`)
    assert.ok(!HOME_PATH.test(t.launch), `${t.id}: LAUNCH carries a home path`)
  }
  // The search index is the card, lowercased: id, name, about, actions, tools, letters.
  for (const part of [t.id, t.name.en, t.summary.en, ...(t.actions ?? []).map((x) => x.name), ...(t.tools ?? []).map((x) => x.name), ...t.agents.map((x) => x.letter)]) {
    assert.ok(t.searchText.includes(part.toLowerCase().replace(/\s+/g, ' ').trim()), `${t.id}: searchText misses ${JSON.stringify(part)}`)
  }
  // Management strip facts.
  assert.equal(canonicalSpecEditUrl(t.specPath), `https://github.com/gHashTag/t27/edit/master/${t.specPath}`)
  assert.equal(vendoredSpecUrl(t.specPath), `https://github.com/gHashTag/trinity/blob/main/apps/website/public/t27/files/${t.specPath}`)
}

// 4. Counts are sums of the list; groups partition the families; the ladder is the catalogs.
const tri = tools.tools.filter((t) => t.family === 'tri-cli'), mcp = tools.tools.filter((t) => t.family === 'mcp')
assert.equal(tools.counts.specs, tools.tools.length)
assert.equal(tools.counts.tri, tri.length)
assert.equal(tools.counts.mcp, mcp.length)
assert.equal(tools.counts.tri + tools.counts.mcp, tools.counts.specs)
assert.equal(tools.counts.trinityTri, tri.filter((t) => t.repo === 'gHashTag/trinity').length)
assert.equal(tools.counts.schema2, tools.tools.length, 'every card is at schema 2')
assert.equal(tools.schema, TOOL_SCHEMA)
// The legacy table is exactly the short-ID cards, and every collision is a name both binaries dispatch.
assert.deepEqual(Object.keys(tools.legacy).sort(), tools.tools.filter((t) => t.id !== t.qualifiedId).map((t) => t.id).sort())
for (const [id, q] of Object.entries(tools.legacy)) assert.ok(ids.has(id) && !ids.has(q) === (q.startsWith('gHashTag/t27:') || !tools.tools.some((t) => t.id === q)), `${id} -> ${q}`)
const t27Names = new Set(tri.filter((t) => t.repo === 'gHashTag/t27').map((t) => t.id.slice(4)))
assert.deepEqual(tools.collisions.map((c) => c.name), tri.filter((t) => t.repo === 'gHashTag/trinity' && t27Names.has(t.qualifiedId.split(':tri/')[1])).map((t) => t.qualifiedId.split(':tri/')[1]).sort())
for (const c of tools.collisions) { assert.ok(ids.has(`tri/${c.name}`) && ids.has(c.trinity)); assert.equal(c.t27, `gHashTag/t27:tri/${c.name}`) }
assert.equal(tools.counts.collisions, tools.collisions.length)
assert.deepEqual(Object.values(tools.groups.triByRepo).flat().sort(), tri.map((t) => t.id).sort())
assert.equal(tools.counts.typecheckOk, tools.tools.length)
assert.equal(tools.counts.withAgents, tools.tools.filter((t) => t.agents.length).length)
assert.equal(tools.counts.withSkills, tools.tools.filter((t) => t.skills.length).length)
assert.equal(tools.counts.triActions, tri.reduce((n, t) => n + t.actions.length, 0))
assert.equal(tools.counts.triWithActions, tri.filter((t) => t.actions.length).length)
assert.equal(tools.counts.mcpTools, mcp.reduce((n, t) => n + t.tools.length, 0))
assert.equal(tools.counts.mcpWithTools, mcp.filter((t) => t.tools.length).length)
assert.equal(tools.counts.mcpExternal, mcp.filter((t) => t.external).length)
assert.equal(tools.counts.mcpWithTools + tools.counts.mcpExternal, mcp.length, 'every MCP server either lists tools or is external')
for (const w of TOOL_WITNESSES) assert.equal(tools.counts.byWitness[w], tools.tools.filter((t) => t.witness === w).length)
assert.equal(Object.values(tools.groups.triByAgent).flat().length, tri.length + tri.reduce((n, t) => n + Math.max(0, t.agents.length - 1), 0), 'triByAgent lists every tri command once per bound letter, unbound under "-"')
assert.deepEqual(tools.groups.triByAgent['-'], tri.filter((t) => t.agents.length === 0).map((t) => t.id))
for (const [l, list] of Object.entries(tools.groups.triByAgent)) if (l !== '-') { assert.ok(letters.has(l)); assert.deepEqual(list, tri.filter((t) => t.agents.some((a) => a.letter === l)).map((t) => t.id)) }
assert.deepEqual(Object.values(tools.groups.mcpByRepo).flat().sort(), mcp.map((t) => t.id).sort())
assert.deepEqual(tools.ladder, agents.ladder, 'both catalogs show the same ladder')
assert.equal(tools.ladder.tools, tools.tools.length)
// Every agent's TOOLS resolves into this catalog.
for (const a of agents.agents) for (const x of a.tools) assert.ok(ids.has(x.id), `${a.id}: TOOLS ${x.id} has no card`)
assert.equal(agents.counts.withTools, agents.agents.filter((a) => a.tools.length).length)

// 5. The Queen opens the view on the promised key.
const m = MODULES.find((x) => x.tab === 'tools')
assert.ok(m, 'queenModules has no tools entry')
assert.ok(HUD_VIEWS.includes('tools'))
assert.equal(HUD_KEYS[HUD_VIEWS.indexOf('tools')], m.key)
assert.equal(m.key, 't', 'TOOLS opens on t: FUNCTIONS took 0, the last digit')
assert.ok(m.en.hint.includes('(key t)') && m.ru.hint.includes('(клавиша t)'), 'the rail hint names the letter key, since a letter is not a position')
for (const lang of ['en', 'ru']) assert.ok(m[lang].name && m[lang].hint && m[lang].body.length > 40, `tools: ${lang} copy missing`)

// 6. Translations: the contract's SCOPE names specs/tools and coverage adds up.
for (const l of tools.i18n) {
  assert.ok(l.scope.includes(TOOL_SPEC_DIR), `${l.spec}: SCOPE must name ${TOOL_SPEC_DIR}`)
  assert.equal(l.coverage.total, tools.tools.length)
  assert.equal(l.coverage.n, tools.tools.filter((t) => t.summary[l.locale]).length)
  assert.equal(l.missing.length, l.coverage.total - l.coverage.n)
}

console.log(
  `tools-spec-contract: ${tools.tools.length} cards (tri ${tri.length} commands of which ${tools.counts.trinityTri} Trinity, ${tools.counts.triActions} actions; mcp ${mcp.length} servers, ${tools.counts.mcpTools} tools, ${tools.counts.mcpExternal} external; schema ${tools.schema}, ${Object.keys(tools.legacy).length} legacy ids, ${tools.collisions.length} collisions); ` +
  `with agents ${tools.counts.withAgents}, with skills ${tools.counts.withSkills}; witness ${Object.entries(tools.counts.byWitness).map(([k, v]) => `${k} ${v}`).join(', ')}; ` +
  `links pinned at ${tools.pin.ref.slice(0, 7)}; Queen key ${m.key}; ` +
  `i18n [${tools.i18n.map((l) => `${l.locale} ${l.coverage.n}/${l.coverage.total}`).join('; ')}]`,
)
