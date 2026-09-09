// The system documentation (#/docs), checked against what it claims.
//
// public/docs/system-docs.json is written by scripts/docs-from-specs.mjs from
// public/t27/files/specs/docs/system.t27 and specs/docs/chapters/*.t27 -- through
// the real compiler, not a regex -- plus the English bodies under docs/system/, the
// Russian bundle named by specs/i18n/docs-ru.t27, the two canon documents the laws
// and phases tables are read from, and the four generated catalogs. This gate asks
// what a generated document can still fail: is the committed JSON what the specs
// produce today; does every chapter have a body whose sections are exactly its
// SECTIONS; does every SOURCES path exist (vendored, or in a t27 checkout) with the
// sha the JSON records; is every generated table non-empty and every figure fed;
// does the prose avoid the ranking words the canon forbids, in both languages; and
// does the Queen open the PROJECT view on the promised key.
//
//   node --experimental-strip-types qa/docs-spec-contract.mjs

import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import { join, resolve } from 'node:path'
import {
  CHAPTER_DIR, DIAGRAMS, DOCS_OUT, DOCS_SPEC, FORBIDDEN_EN, FORBIDDEN_RU, I18N_FIELDS, STATUS_TAGS, TABLES, generate, parseLawTable, parsePhases, t27CheckoutRoot,
} from '../scripts/docs-from-specs.mjs'
import { REPO_ROOT } from '../scripts/agents-from-specs.mjs'
import { MODULES } from '../src/lib/queenModules.ts'
import { HUD_VIEWS, HUD_KEYS } from '../src/components/queenHud.ts'

const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')
const CORPUS = 'public/t27/files'
const CYRILLIC = /[\u0400-\u04ff]/
const HOME_PATH = /(^|[\s"'=:(])(\/Users\/|\/home\/|[A-Z]:\\Users\\)/
const docs = JSON.parse(readFileSync(DOCS_OUT, 'utf8'))

// 1. The committed output is what the specs produce today, through the vendored compiler.
const fresh = await generate({ generatedAt: docs.generatedAt })
assert.deepEqual(fresh.problems, [], 'the generator reports problems:\n' + fresh.problems.join('\n'))
assert.equal(docs.contentSha256, fresh.docs.contentSha256, `${DOCS_OUT} is stale or hand-edited; run node scripts/docs-from-specs.mjs`)
assert.equal(docs.compilerWasmSha256, sha256(readFileSync('public/t27/t27_compiler.wasm')), 'the document names a compiler other than the vendored one')
assert.match(docs.pin.ref, /^[0-9a-f]{40}$/, 'links pin at a t27 commit')

// 2. Exactly the vendored chapter specs, in the order the document declares.
const vendored = readdirSync(join(CORPUS, CHAPTER_DIR)).filter((f) => f.endsWith('.t27')).map((f) => f.replace(/\.t27$/, '')).sort()
assert.deepEqual([...docs.document.chapters].sort(), vendored, 'CHAPTERS is exactly the vendored specs/docs/chapters files')
assert.deepEqual(docs.chapters.map((c) => c.stem), docs.document.chapters, 'chapters are in CHAPTERS order')
assert.equal(docs.document.id, 'docs/system')
assert.equal(docs.document.specPath, DOCS_SPEC)
assert.equal(sha256(readFileSync(join(CORPUS, DOCS_SPEC))), docs.document.sha256, 'system.t27 bytes changed under the document')
assert.ok(!CYRILLIC.test(readFileSync(join(CORPUS, DOCS_SPEC), 'utf8')), `${DOCS_SPEC}: Cyrillic in a .t27 spec (LANG-EN)`)
assert.equal(docs.document.typecheckOk, true)
assert.deepEqual(docs.document.locales[0], 'en')
for (const d of docs.document.diagrams) assert.ok(DIAGRAMS.includes(d), `DIAGRAMS names ${d}, which the site cannot draw`)
assert.ok(docs.chapters.length >= 5, `${docs.chapters.length} chapters`)

// 3. Every chapter: right bytes, English spec, body present, sections == SECTIONS, sources resolve with the recorded sha, table non-empty, figure known.
const checkout = t27CheckoutRoot()
const seenTables = new Set(), seenDiagrams = new Set()
const forbidden = (text, locale) => { const re = locale === 'ru' ? FORBIDDEN_RU : FORBIDDEN_EN; re.lastIndex = 0; return re.exec(text.replace(/```[\s\S]*?```/g, ' ').replace(/`[^`]*`/g, ' ')) }
const textOf = (blocks) => blocks.flatMap((b) => b.type === 'p' || b.type === 'quote' ? b.runs : b.type === 'ul' || b.type === 'ol' ? b.items.flat() : b.type === 'h' ? [{ t: 'text', v: b.text }] : []).filter((r) => r.t !== 'code').map((r) => r.v).join(' ')
for (const [i, c] of docs.chapters.entries()) {
  const specFile = join(CORPUS, c.specPath)
  assert.ok(existsSync(specFile), `${c.id}: ${c.specPath} is not vendored`)
  assert.equal(sha256(readFileSync(specFile)), c.sha256, `${c.id}: spec bytes changed under the document`)
  const specText = readFileSync(specFile, 'utf8')
  assert.ok(!CYRILLIC.test(specText), `${c.specPath}: Cyrillic in a .t27 spec (LANG-EN)`)
  assert.ok(!HOME_PATH.test(specText), `${c.specPath}: a developer home path in a spec`)
  assert.equal(c.typecheckOk, true, `${c.id}: typecheck`)
  assert.equal(c.discarded, 0)
  assert.equal(c.order, i + 1, `${c.id}: ORDER is its position`)
  assert.equal(c.moduleName, `docs_chapter_${c.stem}`)
  assert.equal(c.id, `docs/${c.stem}`)
  assert.equal(c.bodyPath, `docs/system/${c.stem}.md`)
  const bodyFile = join(CORPUS, c.bodyPath)
  assert.ok(existsSync(bodyFile), `${c.id}: body ${c.bodyPath} is not vendored`)
  const body = readFileSync(bodyFile, 'utf8')
  assert.equal(sha256(Buffer.from(body, 'utf8')), c.bodySha256, `${c.id}: body bytes changed under the document`)
  assert.ok(!CYRILLIC.test(body), `${c.bodyPath}: Cyrillic in the English body`)
  assert.ok(!HOME_PATH.test(body), `${c.bodyPath}: a developer home path`)
  assert.ok(body.startsWith(`# ${c.title.en}\n`), `${c.bodyPath}: starts with "# ${c.title.en}"`)
  // Sections: the body's level-2 headings are exactly SECTIONS, each with a body.
  const h2 = body.split('\n').filter((l) => /^## /.test(l)).map((l) => l.replace(/^## /, '').trim())
  assert.deepEqual(h2, c.sections.map((s) => s.heading.en), `${c.id}: level-2 headings equal SECTIONS`)
  assert.equal(c.body.en.sections.length, c.sections.length)
  assert.ok(c.sections.length >= 3, `${c.id}: ${c.sections.length} sections; a chapter has at least three`)
  for (const [j, s] of c.body.en.sections.entries()) {
    assert.equal(s.heading, c.sections[j].heading.en)
    assert.equal(s.id, c.sections[j].id)
    assert.ok(s.blocks.length > 0, `${c.id}: section "${s.heading}" has no body`)
    assert.ok(textOf(s.blocks).length > 80, `${c.id}: section "${s.heading}" is a stub`)
  }
  // A lead paragraph before the first heading is optional (six of seven
  // chapters open on their first section); the body as a whole must not be empty.
  assert.ok(c.body.en.lead.length + c.body.en.sections.reduce((n, s) => n + s.blocks.length, 0) > 0, `${c.id}: empty body`)
  // Ranking words: none in the EN body, none in any translation.
  assert.equal(forbidden(body, 'en'), null, `${c.bodyPath}: ranking word ${JSON.stringify(forbidden(body, 'en')?.[0])}`)
  for (const [locale, b] of Object.entries(c.body)) {
    if (locale === 'en') continue
    assert.ok(docs.document.locales.includes(locale), `${c.id}: body.${locale} has no LOCALES entry`)
    assert.equal(b.sections.length, c.sections.length, `${c.id}: ${locale} body has ${b.sections.length} sections, EN has ${c.sections.length}`)
    const txt = textOf([...b.lead, ...b.sections.flatMap((s) => [{ type: 'h', text: s.heading }, ...s.blocks])])
    assert.ok(CYRILLIC.test(txt) || locale !== 'ru', `${c.id}: body.ru is not Russian`)
    assert.equal(forbidden(txt, locale), null, `${c.id}: ${locale} ranking word ${JSON.stringify(forbidden(txt, locale)?.[0])}`)
    for (const [j, s] of b.sections.entries()) {
      assert.ok(s.blocks.length > 0, `${c.id}: ${locale} section ${j + 1} has no body`)
      assert.equal(c.sections[j].heading[locale], s.heading)
    }
  }
  for (const locale of Object.keys(c.title)) assert.ok(locale === 'en' || docs.document.locales.includes(locale), `${c.id}: title.${locale} has no LOCALES entry`)
  // Sources: every path exists where the record says, with the sha the record says.
  assert.ok(c.sources.length > 0, `${c.id}: no SOURCES`)
  for (const s of c.sources) {
    assert.ok(['vendored', 'checkout'].includes(s.where), `${c.id}: source ${s.path} is ${s.where}`)
    const abs = s.repo === 'trinity' ? join(REPO_ROOT, s.rel) : s.where === 'vendored' ? join(CORPUS, s.rel) : checkout ? join(checkout, s.rel) : null
    if (s.where === 'checkout' && s.repo === 't27' && !checkout) continue // recorded from a checkout this machine does not have; the sha stays as recorded
    assert.ok(abs && existsSync(abs), `${c.id}: source ${s.path} (${s.where}) does not exist at ${abs}`)
    if (s.kind === 'dir') { assert.ok(statSync(abs).isDirectory()); assert.equal(s.sha256, null) } else {
      assert.equal(s.kind, 'file')
      if (s.where === 'vendored' || s.repo === 'trinity') assert.equal(sha256(readFileSync(abs)), s.sha256, `${c.id}: source ${s.path} bytes differ from the recorded sha`)
    }
    assert.match(s.url, /^https:\/\/github\.com\/gHashTag\/(t27|trinity)\/(blob|tree)\/[0-9a-f]{40}\//, `${c.id}: source ${s.path} url is not pinned`)
    assert.ok(!s.rel.startsWith('.github/'), `${c.id}: ${s.path} would vendor a dot-directory under public/`)
  }
  // Table and figure.
  if (c.table) {
    assert.ok(TABLES.includes(c.table.kind), `${c.id}: table ${c.table.kind}`)
    assert.ok(!seenTables.has(c.table.kind), `${c.id}: table ${c.table.kind} is used by two chapters`)
    seenTables.add(c.table.kind)
    assert.ok(c.table.rows.length > 0, `${c.id}: table ${c.table.kind} is empty`)
    assert.ok(c.table.columns.length > 1)
    assert.ok(c.table.source.length > 0, `${c.id}: table without a data source line`)
    for (const r of c.table.rows) for (const col of c.table.columns) assert.ok(col in r, `${c.id}: table ${c.table.kind} row misses ${col}`)
  }
  if (c.diagram) {
    assert.ok(docs.document.diagrams.includes(c.diagram), `${c.id}: DIAGRAM ${c.diagram} not declared`)
    assert.ok(!seenDiagrams.has(c.diagram), `${c.id}: figure ${c.diagram} is used by two chapters`)
    seenDiagrams.add(c.diagram)
    assert.ok(docs.figures[c.diagram], `${c.id}: no figure data for ${c.diagram}`)
    assert.ok(docs.figures[c.diagram].source.length > 0, `${c.id}: figure ${c.diagram} without a data source line`)
  }
  assert.equal(c.links.spec, `https://github.com/gHashTag/t27/blob/${docs.pin.ref}/${c.specPath}`)
  assert.equal(c.links.body, `https://github.com/gHashTag/t27/blob/${docs.pin.ref}/${c.bodyPath}`)
}
assert.deepEqual([...seenDiagrams].sort(), [...docs.document.diagrams].sort(), 'every declared diagram is drawn by exactly one chapter')

// 4. Generated tables and figures carry the numbers the catalogs carry.
const agents = JSON.parse(readFileSync('public/agents/spec-agents.json', 'utf8'))
const tools = JSON.parse(readFileSync('public/tools/spec-tools.json', 'utf8'))
const skills = JSON.parse(readFileSync('public/skills/spec-skills.json', 'utf8'))
const crons = JSON.parse(readFileSync('public/crons/spec-crons.json', 'utf8'))
const manifest = JSON.parse(readFileSync('public/t27/manifest.json', 'utf8'))
assert.deepEqual(docs.ladder, { specs: manifest.specs.length, skills: skills.counts.specs, crons: crons.counts.specs, agents: agents.counts.specs, tools: tools.counts.specs, docsChapters: docs.chapters.length })
assert.deepEqual(docs.figures.ladder.counts, docs.ladder)
assert.equal(docs.figures['agent-ring'].agents.length, agents.agents.length)
assert.deepEqual(docs.figures['agent-ring'].agents.map((a) => a.letter), agents.agents.slice().sort((a, b) => a.ordinal - b.ordinal).map((a) => a.letter))
for (const a of docs.figures['agent-ring'].agents) assert.ok(['Archetypal', 'Spiritual', 'Physical'].includes(a.layer), `${a.letter}: layer ${a.layer}`)
const tableOf = (kind) => docs.chapters.find((c) => c.table?.kind === kind)?.table
const agentsTable = tableOf('agents'), toolsTable = tableOf('tools'), lawsTable = tableOf('laws'), phasesTable = tableOf('phases'), claimsTable = tableOf('claims'), ladderTable = tableOf('ladder-counts'), witnessTable = tableOf('witnesses')
if (agentsTable) { assert.equal(agentsTable.rows.length, agents.agents.length); for (const r of agentsTable.rows) { const a = agents.agents.find((x) => x.letter === r.letter); assert.ok(a, r.letter); assert.deepEqual(r.skills, a.skills.map((s) => s.id)); assert.deepEqual(r.tools, a.tools.map((t) => t.id)) } }
if (toolsTable) { assert.equal(toolsTable.rows.length, tools.tools.length); for (const r of toolsTable.rows) { const t = tools.tools.find((x) => x.id === r.id); assert.ok(t, r.id); assert.equal(r.witness, t.fields.WITNESS); assert.deepEqual(r.agents, t.agents.map((a) => a.letter)) } }
if (ladderTable) assert.deepEqual(ladderTable.rows.map((r) => r.count), [docs.ladder.specs, docs.ladder.skills, docs.ladder.crons, docs.ladder.agents, docs.ladder.tools])
if (witnessTable) {
  const row = (layer, label) => witnessTable.rows.find((r) => r.layer === layer && r.label === label)?.count
  assert.equal(row('Skills', 'spec+code'), skills.counts.specPlusCode)
  assert.equal(row('Crons', 'spec+code'), crons.counts.specPlusCode)
  assert.equal(row('Agents', 'spec-only'), agents.counts.specOnly)
  assert.equal(row('Experience', 'episodes unattributed'), agents.counts.episodesUnattributed)
  for (const [w, n] of Object.entries(tools.counts.byWitness)) assert.equal(row('Tools', w), n)
}
// Laws and phases: read again from the vendored canon documents, must agree.
const constitution = readFileSync(join(CORPUS, 'docs/T27-CONSTITUTION.md'), 'utf8')
const alphabet = readFileSync(join(CORPUS, 'docs/agents/AGENTS_ALPHABET.md'), 'utf8')
const laws = parseLawTable(constitution), phases = parsePhases(alphabet)
assert.equal(laws.rows.length, 7, 'the constitution defines L1-L7')
assert.deepEqual(laws.rows.map((l) => l.law), ['L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7'])
if (lawsTable) assert.deepEqual(lawsTable.rows, laws.rows)
assert.deepEqual(docs.figures['law-hierarchy'].laws.map((l) => l.law), laws.rows.map((l) => l.law))
assert.equal(phases.length, 7, 'the alphabet draws six phases plus GIT WORKFLOW')
assert.deepEqual(phases.map((p) => p.n), [1, 2, 3, 4, 5, 6, 7])
for (const p of phases) assert.ok(p.steps.length > 0, `phase ${p.n} without steps`)
if (phasesTable) assert.deepEqual(phasesTable.rows, phases)
assert.equal(docs.figures['phase-cycle'].phases.length, 7)
// Claims: every row carries one of the five tags, and the tags in use are a subset of the glossary.
if (claimsTable) { assert.ok(claimsTable.rows.length >= 4); for (const r of claimsTable.rows) { assert.ok(STATUS_TAGS.includes(r.tag), r.tag); assert.ok(r.claim.length > 20) } }
// Graph: every edge endpoint exists in a catalog.
const skillIds = new Set(skills.skills.map((s) => s.id)), toolIds = new Set(tools.tools.map((t) => t.id)), agentIds = new Set(agents.agents.map((a) => a.id)), cronIds = new Set(crons.crons.map((c) => c.id))
for (const e of docs.figures['skills-crons-agents'].edges) {
  if (e.kind === 'cron-runs-skill') { assert.ok(cronIds.has(e.from), e.from); assert.ok(skillIds.has(e.to), e.to) } else if (e.kind === 'agent-holds-skill') { assert.ok(agentIds.has(e.from), e.from); assert.ok(skillIds.has(e.to), e.to) } else { assert.equal(e.kind, 'agent-holds-tool'); assert.ok(agentIds.has(e.from), e.from); assert.ok(toolIds.has(e.to), e.to) }
}
assert.equal(docs.figures['skills-crons-agents'].edges.filter((e) => e.kind === 'agent-holds-skill').length, agents.agents.reduce((n, a) => n + a.skills.filter((s) => s.ok).length, 0))
assert.equal(docs.figures['skills-crons-agents'].edges.filter((e) => e.kind === 'agent-holds-tool').length, agents.agents.reduce((n, a) => n + a.tools.filter((s) => s.ok).length, 0))
assert.deepEqual(docs.figures['tools-map'].triByAgent, tools.groups.triByAgent)
assert.deepEqual(docs.figures['tools-map'].mcpByRepo, tools.groups.mcpByRepo)

// 5. Translations: contract scope, coverage adds up, fields are TITLE/BODY only, bundle is the file the contract names.
for (const l of docs.i18n) {
  assert.ok(l.scope.includes('specs/docs') || l.scope.includes(CHAPTER_DIR), `${l.spec}: SCOPE must name specs/docs`)
  for (const f of l.fields) assert.ok(I18N_FIELDS.includes(f), `${l.spec}: FIELDS ${f}`)
  assert.equal(l.coverage.total, docs.chapters.length)
  assert.equal(l.coverage.n, docs.chapters.filter((c) => c.body[l.locale]).length)
  assert.equal(l.missing.length, l.coverage.total - l.coverage.n)
  const bundleAbs = resolve(REPO_ROOT, l.bundle)
  assert.ok(existsSync(bundleAbs), `${l.spec}: bundle ${l.bundle} missing`)
  const bundle = JSON.parse(readFileSync(bundleAbs, 'utf8'))
  assert.equal(bundle.$spec, l.spec)
  assert.equal(bundle.locale, l.locale)
  assert.ok(!HOME_PATH.test(readFileSync(bundleAbs, 'utf8')), `${l.bundle}: a developer home path`)
  assert.equal(docs.counts[`${l.locale}Chapters`], l.coverage.n)
}

// 6. Counts are sums of the list.
assert.equal(docs.counts.chapters, docs.chapters.length)
assert.equal(docs.counts.enabled, docs.chapters.filter((c) => c.enabled).length)
assert.equal(docs.counts.sections, docs.chapters.reduce((n, c) => n + c.sections.length, 0))
assert.equal(docs.counts.sources, docs.chapters.reduce((n, c) => n + c.sources.length, 0))
assert.equal(docs.counts.sourcesVendored + docs.counts.sourcesCheckout, docs.counts.sources)
assert.equal(docs.counts.tables, docs.chapters.filter((c) => c.table).length)
assert.equal(docs.counts.diagrams, docs.chapters.filter((c) => c.diagram).length)
assert.equal(docs.counts.typecheckOk, docs.chapters.length + 1)
assert.equal(docs.counts.laws, laws.rows.length)
assert.equal(docs.counts.phases, phases.length)

// 7. The Queen opens the PROJECT view on the promised key, and the site routes #/docs.
const m = MODULES.find((x) => x.tab === 'project')
assert.ok(m, 'queenModules has no project entry')
assert.ok(HUD_VIEWS.includes('project'))
assert.equal(HUD_KEYS[HUD_VIEWS.indexOf('project')], m.key)
assert.equal(m.key, 'p', 'PROJECT opens on p (the digits are spent)')
for (const lang of ['en', 'ru']) assert.ok(m[lang].name && m[lang].hint && m[lang].body.length > 40, `project: ${lang} copy missing`)
// the router is src/main.tsx (HashRouter); both #/docs and #/docs/<chapter> resolve
const router = readFileSync('src/main.tsx', 'utf8')
assert.match(router, /path="\/docs"/, 'main.tsx routes #/docs')
assert.match(router, /path="\/docs\/:chapter"/, 'main.tsx routes #/docs/<chapter>')
assert.ok(existsSync('src/pages/SystemDocs.tsx'), 'src/pages/SystemDocs.tsx exists')
assert.ok(existsSync('src/components/SystemDocsFigures.tsx'), 'src/components/SystemDocsFigures.tsx exists')
// every declared diagram is a figure the page can draw: the figure file names
// each kind once as a string, and the page hands every kind to it
const figures = readFileSync('src/components/SystemDocsFigures.tsx', 'utf8')
const systemDocs = readFileSync('src/pages/SystemDocs.tsx', 'utf8')
for (const d of DIAGRAMS) {
  assert.ok(figures.includes(`'${d}'`) || figures.includes(`"${d}"`), `SystemDocsFigures.tsx does not draw ${d}`)
  assert.ok(systemDocs.includes(`'${d}'`) || systemDocs.includes(`"${d}"`), `SystemDocs.tsx does not name ${d}`)
}
assert.match(figures, /<figcaption/, 'every figure carries a caption')
assert.match(systemDocs, /@media print/, 'SystemDocs.tsx has print CSS')
// the PROJECT view frames the page and jumps to the six promised chapters
const queenAgents = readFileSync('src/components/QueenAgents.tsx', 'utf8')
for (const stem of ['project', 'rules', 'layers', 'alphabet', 'tooling', 'evidence']) assert.ok(queenAgents.includes(`stem: '${stem}'`), `QueenAgents PROJECT_JUMPS lacks ${stem}`)
for (const label of ['Проект', 'Правила игры', 'Система', 'Алфавит', 'Инструменты', 'Свидетели']) assert.ok(queenAgents.includes(`'${label}'`), `QueenAgents PROJECT_JUMPS lacks the RU label ${label}`)
assert.ok(new Set(docs.chapters.map((c) => c.stem)).size >= 6 && ['project', 'rules', 'layers', 'alphabet', 'tooling', 'evidence'].every((s) => docs.chapters.some((c) => c.stem === s)), 'every quick jump names a real chapter')
// the rail documents the key: the hint the rail prints mentions p in both languages
for (const lang of ['en', 'ru']) assert.match(m[lang].hint, /\bp\b|клавиша p/, `project: ${lang} hint does not name the key p`)
// the old GitHub Pages docs link is gone from every place that linked it
for (const f of ['src/components/Footer.tsx', 'src/components/Navigation.tsx', 'src/components/ProductionDashboard.tsx']) assert.ok(!/https:\/\/t27\.ai\/docs\//.test(readFileSync(f, 'utf8')), `${f}: still links the GitHub Pages docs instead of #/docs`)
assert.match(readFileSync('src/components/Navigation.tsx', 'utf8'), /DOCS_URL = '#\/docs'/, 'Navigation DOCS_URL is #/docs')

console.log(
  `docs-spec-contract: ${docs.chapters.length} chapters, ${docs.counts.sections} sections; tables ${docs.counts.tables}, figures ${docs.counts.diagrams}; ` +
  `laws ${docs.counts.laws}, phases ${docs.counts.phases}; sources ${docs.counts.sources} (vendored ${docs.counts.sourcesVendored}, checkout ${docs.counts.sourcesCheckout}); ` +
  `ru ${docs.counts.ruChapters ?? 0}/${docs.chapters.length}; typecheck ok ${docs.counts.typecheckOk}/${docs.chapters.length + 1}; pinned at ${docs.pin.ref.slice(0, 7)}; PROJECT on key ${m.key}`,
)
