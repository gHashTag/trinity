// What the docs generator refuses, and what it lets through.
//
// The failures are the interesting cases: a chapter whose ORDER disagrees with
// CHAPTERS, a body whose headings are not the SECTIONS, a table the generator cannot
// produce, a ranking word in either language, Cyrillic in a spec, a source that does
// not exist. The Markdown reader and the two canon-document parsers are pinned on
// small fixtures so a change in their shape fails here, not on the page.
//
//   node --test scripts/docs-from-specs.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { SITE, analyzeSpecFiles, loadCompiler } from './agents-from-specs.mjs'
import {
  buildDocs, claimsFrom, forbiddenIn, inlineRuns, parseLawTable, parseMarkdown, parsePhases, sectionize, slug,
} from './docs-from-specs.mjs'

const analyze = await loadCompiler(readFileSync(join(SITE, 'public/t27/t27_compiler.wasm')))
const q = JSON.stringify

const systemSrc = ({ chapters = ['one', 'two'], diagrams = ['ladder', 'law-hierarchy'], locales = ['en'], sources = ['SOUL.md'] } = {}) => `module docs_system;
pub const KIND : str = "docs";
pub const ID : str = "docs/system";
pub const TITLE : str = "The system";
pub const CHAPTERS : [${chapters.length}]str = ${q(chapters)};
pub const SOURCES : [${sources.length}]str = ${q(sources)};
pub const DIAGRAMS : [${diagrams.length}]str = ${q(diagrams)};
pub const LOCALES : [${locales.length}]str = ${q(locales)};
pub const ENABLED : bool = true;
`
const chapterSrc = (stem, order, { sections = ['Alpha', 'Beta'], diagram = '', table = '', sources = ['SOUL.md'], title = `Chapter ${stem}`, module = `docs_chapter_${stem}`, extra = '' } = {}) => `module ${module};
pub const KIND : str = "docs-chapter";
pub const ID : str = ${q(`docs/${stem}`)};
pub const DOCUMENT : str = "docs/system";
pub const ORDER : u8 = ${order};
pub const TITLE : str = ${q(title)};
pub const SOURCES : [${sources.length}]str = ${q(sources)};
pub const SECTIONS : [${sections.length}]str = ${q(sections)};
pub const DIAGRAM : str = ${q(diagram)};
pub const TABLE : str = ${q(table)};
pub const BODY_EN : str = ${q(`docs/system/${stem}.md`)};
pub const ENABLED : bool = true;
${extra}`
const i18nSrc = (locale = 'ru') => `module i18n_docs_${locale};
pub const KIND : str = "i18n";
pub const LOCALE : str = ${q(locale)};
pub const SOURCE_LOCALE : str = "en";
pub const SCOPE : [2]str = ["specs/docs", "specs/docs/chapters"];
pub const FIELDS : [2]str = ["TITLE", "BODY"];
pub const BUNDLE_REPO : str = "trinity";
pub const BUNDLE_PATH : str = "apps/website/i18n/docs.${locale}.json";
pub const BUNDLE_FORMAT : str = "json";
pub const KEY : str = "ID";
pub const FALLBACK : str = "en";
pub const COVERAGE_REQUIRED : bool = false;
pub const ORPHANS_ALLOWED : bool = false;
pub const ENABLED : bool = true;
`
const body = (title, sections = ['Alpha', 'Beta']) => `# ${title}\n\nA lead paragraph with \`code\` and **strong** words.\n\n${sections.map((s) => `## ${s}\n\nBody of ${s}, long enough to count as prose rather than a stub, with a [link](https://example.org/x).\n\n- item one\n- item two\n  continued\n`).join('\n')}`

const CONSTITUTION = `# C\n\n## 2. Laws\n\n### Law Table (L1-L7)\n\n| Law # | Name | Body | Enforcement |\n|---|---|---|---|\n| **L1** | **TRACEABILITY** | Every artifact traces | tri verdict |\n| **L2** | **GENERATION** | Generated, not written | codegen |\n\nPriority: L1 > L2 > L7.\n\n## 3. Next\n`
const ALPHABET = `# A\n\n### 6-Phase Cycle of AGENT T\n\n\`\`\`\n│                    PHASE 1: PLAN                           │\n│   • read the issue                                          │\n│   • pick a cell                                             │\n│                 PHASE 2: ASSIGN                           │\n│   • choose a letter                                         │\n│         PHASE 7: GIT WORKFLOW (new — SOUL law)         │\n│   • \`tri git push\`                                          │\n\`\`\`\n\n### Next section\n\n│ PHASE 9: NOT HERE │\n`

const catalogs = () => ({
  skills: { counts: { specs: 2, specPlusCode: 2, specOnly: 0, codeOnly: 0, typecheckOk: 2 }, skills: [{ id: 't27/a' }, { id: 't27/b' }] },
  crons: { counts: { specs: 1, specPlusCode: 1, specOnly: 0, codeOnly: 0, typecheckOk: 1, withRuns: 1 }, crons: [{ id: 't27/c', runs: [{ id: 't27/a', ok: true }] }] },
  agents: { counts: { specs: 1, typecheckOk: 1, withSkills: 1, withTools: 0, specPlusExperience: 0, specOnly: 1, episodesAttributed: 0, episodesUnattributed: 3 }, agents: [{ id: 't27/T', letter: 'T', ordinal: 20, fields: { LETTER_NAME: 'Tau', NAME: 'Tau', DOMAIN: 'Queen', ARCHETYPE: 'x', REGISTER: 'R19', LAYER: 'Physical', ENABLED: true }, skills: [{ id: 't27/a', ok: true }], tools: [], experience: { episodes: 0 } }] },
  tools: { counts: { specs: 1, typecheckOk: 1, byWitness: { 'source-parse': 1, 'help-output': 0 }, mcpExternal: 0 }, tools: [{ id: 'tri/gen', family: 'tri-cli', command: 'tri gen', repo: 'gHashTag/t27', actions: [], agents: [], fields: { WITNESS: 'source-parse' }, external: false }], groups: { triByAgent: { '-': ['tri/gen'] }, mcpByRepo: {} } },
  t27Manifest: { specs: [{}, {}, {}], health: { typecheckOk: 3 } },
})

function build(overrides = {}) {
  const { systemText = systemSrc(), chapterTexts = { one: chapterSrc('one', 1, { diagram: 'ladder', table: 'laws' }), two: chapterSrc('two', 2, { diagram: 'law-hierarchy', table: 'phases' }) }, bodies = new Map([['docs/system/one.md', body('Chapter one')], ['docs/system/two.md', body('Chapter two')]]), i18nTexts = [], bundles = new Map() } = overrides
  const docsSpec = analyzeSpecFiles(analyze, [{ path: 'specs/docs/system.t27', text: systemText }])[0]
  const chapterSpecs = analyzeSpecFiles(analyze, Object.entries(chapterTexts).map(([stem, text]) => ({ path: `specs/docs/chapters/${stem}.t27`, text })))
  const i18nSpecs = analyzeSpecFiles(analyze, i18nTexts.map((text, i) => ({ path: `specs/i18n/docs-${['ru', 'de'][i]}.t27`, text })))
  return buildDocs({
    docsSpec, chapterSpecs, i18nSpecs, bundles, bodies, catalogs: catalogs(), sourceTexts: new Map([['docs/T27-CONSTITUTION.md', CONSTITUTION], ['docs/agents/AGENTS_ALPHABET.md', ALPHABET]]),
    pin: 'a'.repeat(40), trinityPin: 'b'.repeat(40), compilerWasmSha256: 'x', generatedAt: '2026-01-01T00:00:00.000Z',
  })
}

test('markdown: headings, paragraphs, lists, quotes, code, inline runs', () => {
  const { title, blocks } = parseMarkdown('# T\n\nPara one\ncontinues.\n\n## S1\n\n- a `c`\n- b **s**\n  more\n\n1. x\n2. y\n\n> quoted [l](https://e.org)\n\n```\ncode\n```\n\n### Sub\n')
  assert.equal(title, 'T')
  assert.deepEqual(blocks.map((b) => b.type), ['p', 'h', 'ul', 'ol', 'quote', 'code', 'h'])
  assert.deepEqual(blocks[0].runs, [{ t: 'text', v: 'Para one continues.' }])
  assert.deepEqual(blocks[2].items[1], [{ t: 'text', v: 'b ' }, { t: 'strong', v: 's' }, { t: 'text', v: ' more' }])
  assert.deepEqual(blocks[4].runs, [{ t: 'text', v: 'quoted ' }, { t: 'link', v: 'l', href: 'https://e.org' }])
  assert.equal(blocks[5].text, 'code')
  assert.equal(blocks[6].level, 3)
  const { lead, sections } = sectionize(blocks)
  assert.equal(lead.length, 1)
  assert.equal(sections.length, 1)
  assert.equal(sections[0].id, 's1')
  assert.equal(sections[0].blocks.length, 5)
  assert.deepEqual(inlineRuns('plain'), [{ t: 'text', v: 'plain' }])
  assert.equal(slug('The 27-agent alphabet'), 'the-27-agent-alphabet')
})

test('forbidden words: phrases in English, stems in Russian, code spans and hyphen compounds ignored', () => {
  assert.equal(forbiddenIn('the first-party docs; only seven laws; the best-effort path; a first step', 'en').length, 0)
  assert.deepEqual(forbiddenIn('this is the first spec language and a breakthrough', 'en').map((h) => h.word), ['the first', 'breakthrough'])
  assert.equal(forbiddenIn('`the first` in code is fine', 'en').length, 0)
  assert.equal(forbiddenIn('Во-первых, первопричина и первичный ключ', 'ru').length, 0)
  assert.deepEqual(forbiddenIn('первый в мире, единственный и лучший', 'ru').map((h) => h.word), ['первый', 'единственный', 'лучший'])
})

test('law table and phase cycle are read from the canon documents', () => {
  const laws = parseLawTable(CONSTITUTION)
  assert.deepEqual(laws.rows, [{ law: 'L1', name: 'TRACEABILITY', body: 'Every artifact traces', enforcement: 'tri verdict' }, { law: 'L2', name: 'GENERATION', body: 'Generated, not written', enforcement: 'codegen' }])
  assert.equal(laws.priority, 'L1 > L2 > L7')
  assert.deepEqual(parseLawTable('# no table').rows, [])
  const phases = parsePhases(ALPHABET)
  assert.deepEqual(phases.map((p) => [p.n, p.name, p.steps.length]), [[1, 'PLAN', 2], [2, 'ASSIGN', 1], [7, 'GIT WORKFLOW', 1]])
  assert.equal(phases[2].note, 'new — SOUL law')
  assert.equal(phases[2].steps[0], '`tri git push`')
})

test('claims: tagged bullets become rows, the glossary bullets that define the tags do not', () => {
  const rows = claimsFrom('- `[measured]` -- a number produced by running something\n- The catalog holds 83 formats `[declared]` -- `FAMILY_TOTALS.catalog` in\n  `trinity:apps/website/src/data/siliconHistory.ts`.\n- **No silicon.** `[not claimed]` A design was withdrawn.\n- untagged bullet\n')
  assert.deepEqual(rows.map((r) => r.tag), ['declared', 'not claimed'])
  assert.equal(rows[0].claim, 'The catalog holds 83 formats -- `FAMILY_TOTALS.catalog` in `trinity:apps/website/src/data/siliconHistory.ts`.')
  assert.deepEqual(rows[0].sources, ['trinity:apps/website/src/data/siliconHistory.ts'])
  assert.equal(rows[1].claim, 'No silicon. A design was withdrawn.')
})

test('a clean document builds: chapters in order, tables and figures fed, sources resolved, sha stable', () => {
  const { docs, problems } = build()
  assert.deepEqual(problems, [])
  assert.deepEqual(docs.chapters.map((c) => c.stem), ['one', 'two'])
  assert.equal(docs.chapters[0].table.kind, 'laws')
  assert.equal(docs.chapters[0].table.rows.length, 2)
  assert.equal(docs.chapters[1].table.kind, 'phases')
  assert.equal(docs.chapters[1].table.rows.length, 3)
  assert.deepEqual(docs.chapters[0].sections.map((s) => s.heading.en), ['Alpha', 'Beta'])
  assert.equal(docs.chapters[0].body.en.sections[0].blocks.length, 2)
  assert.equal(docs.chapters[0].sources[0].where, 'vendored')
  assert.match(docs.chapters[0].sources[0].url, /^https:\/\/github\.com\/gHashTag\/t27\/blob\/a{40}\/SOUL\.md$/)
  assert.deepEqual(docs.ladder, { specs: 3, skills: 2, crons: 1, agents: 1, tools: 1, docsChapters: 2 })
  assert.deepEqual(docs.figures['skills-crons-agents'].edges, [{ from: 't27/c', to: 't27/a', kind: 'cron-runs-skill' }, { from: 't27/T', to: 't27/a', kind: 'agent-holds-skill' }])
  assert.equal(docs.figures['law-hierarchy'].laws.length, 2)
  assert.equal(docs.counts.typecheckOk, 3)
  const again = build()
  assert.equal(again.docs.contentSha256, docs.contentSha256, 'deterministic')
  assert.equal(build().docs.chapters[0].bodySha256, docs.chapters[0].bodySha256)
})

test('refused: ORDER out of place, headings not equal to SECTIONS, unknown TABLE and DIAGRAM, chapter not listed', () => {
  const r1 = build({ chapterTexts: { one: chapterSrc('one', 2, { table: 'laws' }), two: chapterSrc('two', 1, { table: 'phases' }) } })
  assert.ok(r1.problems.some((p) => /one\.t27: ORDER 2 does not match its position 1/.test(p)), r1.problems.join('\n'))
  const r2 = build({ bodies: new Map([['docs/system/one.md', body('Chapter one', ['Alpha', 'Gamma'])], ['docs/system/two.md', body('Chapter two')]]) })
  assert.ok(r2.problems.some((p) => /one\.md: level-2 headings .* must equal SECTIONS/.test(p)), r2.problems.join('\n'))
  const r3 = build({ chapterTexts: { one: chapterSrc('one', 1, { table: 'nope', diagram: 'agent-ring' }), two: chapterSrc('two', 2, { table: 'phases' }) } })
  assert.ok(r3.problems.some((p) => /TABLE "nope" is not one the generator produces/.test(p)))
  assert.ok(r3.problems.some((p) => /DIAGRAM "agent-ring" is not in specs\/docs\/system\.t27 DIAGRAMS/.test(p)))
  const r4 = build({ systemText: systemSrc({ chapters: ['one'] }) })
  assert.ok(r4.problems.some((p) => /chapters\/two\.t27 is not listed/.test(p)))
  const r5 = build({ systemText: systemSrc({ chapters: ['one', 'two', 'three'] }) })
  assert.ok(r5.problems.some((p) => /CHAPTERS names "three" but .*three\.t27 is missing/.test(p)))
})

test('refused: body missing, title mismatch, empty section, ranking word, Cyrillic in a spec, missing source', () => {
  const r1 = build({ bodies: new Map([['docs/system/two.md', body('Chapter two')]]) })
  assert.ok(r1.problems.some((p) => /BODY_EN docs\/system\/one\.md is missing/.test(p)))
  const r2 = build({ bodies: new Map([['docs/system/one.md', body('Other title')], ['docs/system/two.md', body('Chapter two')]]) })
  assert.ok(r2.problems.some((p) => /level-1 heading "Other title" differs from TITLE/.test(p)))
  const r3 = build({ bodies: new Map([['docs/system/one.md', '# Chapter one\n\nlead\n\n## Alpha\n\n## Beta\n\ntext\n'], ['docs/system/two.md', body('Chapter two')]]) })
  assert.ok(r3.problems.some((p) => /section "Alpha" has no body/.test(p)))
  const r4 = build({ bodies: new Map([['docs/system/one.md', body('Chapter one').replace('A lead paragraph', 'The first spec language ever, a lead paragraph')], ['docs/system/two.md', body('Chapter two')]]) })
  assert.ok(r4.problems.some((p) => /one\.md: ranking word "The first"/.test(p)))
  const r5 = build({ chapterTexts: { one: chapterSrc('one', 1, { table: 'laws', extra: '; комментарий\n' }), two: chapterSrc('two', 2, { table: 'phases' }) } })
  assert.ok(r5.problems.some((p) => /one\.t27: Cyrillic in a \.t27 spec/.test(p)))
  const r6 = build({ chapterTexts: { one: chapterSrc('one', 1, { table: 'laws', sources: ['does/not/exist.md'] }), two: chapterSrc('two', 2, { table: 'phases' }) } })
  assert.ok(r6.problems.some((p) => /SOURCES names does\/not\/exist\.md, which is neither vendored/.test(p)))
  const r7 = build({ chapterTexts: { one: chapterSrc('one', 1, { table: 'laws', module: 'docs_chapter_uno' }), two: chapterSrc('two', 2, { table: 'phases' }) } })
  assert.ok(r7.problems.some((p) => /module must be docs_chapter_one, is docs_chapter_uno/.test(p)))
})

test('translations: bundle entries render, section count must match, orphans and stray fields are refused, coverage is counted', () => {
  const ruBody = '## Альфа\n\nТело альфы.\n\n## Бета\n\nТело беты.\n'
  const bundle = { $spec: 'specs/i18n/docs-ru.t27', locale: 'ru', entries: { 'docs/system': { TITLE: 'Система' }, 'docs/one': { TITLE: 'Глава один', BODY: ruBody } } }
  const ok = build({ systemText: systemSrc({ locales: ['en', 'ru'] }), i18nTexts: [i18nSrc('ru')], bundles: new Map([['apps/website/i18n/docs.ru.json', bundle]]) })
  assert.deepEqual(ok.problems, [])
  assert.equal(ok.docs.document.title.ru, 'Система')
  assert.equal(ok.docs.chapters[0].title.ru, 'Глава один')
  assert.deepEqual(ok.docs.chapters[0].sections.map((s) => s.heading.ru), ['Альфа', 'Бета'])
  assert.equal(ok.docs.chapters[0].body.ru.sections.length, 2)
  assert.equal(ok.docs.chapters[1].body.ru, undefined)
  assert.deepEqual(ok.docs.i18n[0].coverage, { n: 1, total: 2 })
  assert.deepEqual(ok.docs.i18n[0].missing, ['docs/two'])
  assert.equal(ok.docs.counts.ruChapters, 1)
  const short = build({ systemText: systemSrc({ locales: ['en', 'ru'] }), i18nTexts: [i18nSrc('ru')], bundles: new Map([['apps/website/i18n/docs.ru.json', { ...bundle, entries: { 'docs/one': { TITLE: 'x', BODY: '## Одна\n\nтекст\n' } } }]]) })
  assert.ok(short.problems.some((p) => /docs\/one\.BODY has 1 level-2 heading\(s\), the English body has 2/.test(p)), short.problems.join('\n'))
  const orphan = build({ systemText: systemSrc({ locales: ['en', 'ru'] }), i18nTexts: [i18nSrc('ru')], bundles: new Map([['apps/website/i18n/docs.ru.json', { ...bundle, entries: { 'docs/nine': { TITLE: 'x' } } }]]) })
  assert.ok(orphan.problems.some((p) => /entry "docs\/nine" matches no chapter and ORPHANS_ALLOWED is false/.test(p)))
  const stray = build({ systemText: systemSrc({ locales: ['en', 'ru'] }), i18nTexts: [i18nSrc('ru')], bundles: new Map([['apps/website/i18n/docs.ru.json', { ...bundle, entries: { 'docs/one': { TITLE: 'x', SUMMARY: 'y' } } }]]) })
  assert.ok(stray.problems.some((p) => /carries "SUMMARY", which is not in FIELDS/.test(p)))
  const ranking = build({ systemText: systemSrc({ locales: ['en', 'ru'] }), i18nTexts: [i18nSrc('ru')], bundles: new Map([['apps/website/i18n/docs.ru.json', { ...bundle, entries: { 'docs/one': { TITLE: 'x', BODY: ruBody.replace('Тело альфы', 'Единственный в мире язык') } } }]]) })
  assert.ok(ranking.problems.some((p) => /ranking word "Единственный"/.test(p)))
  const noContract = build({ systemText: systemSrc({ locales: ['en', 'ru'] }) })
  assert.ok(noContract.problems.some((p) => /LOCALES names "ru" but no specs\/i18n\/docs-ru\.t27 contract/.test(p)))
  const noBundle = build({ systemText: systemSrc({ locales: ['en', 'ru'] }), i18nTexts: [i18nSrc('ru')] })
  assert.ok(noBundle.problems.some((p) => /bundle apps\/website\/i18n\/docs\.ru\.json is missing/.test(p)))
})
