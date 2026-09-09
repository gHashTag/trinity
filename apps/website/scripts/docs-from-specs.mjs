#!/usr/bin/env node
// docs-from-specs.mjs -- the system documentation (`#/docs`) from `specs/docs/**.t27`.
//
// Reads the vendored `specs/docs/system.t27` and `specs/docs/chapters/<id>.t27` through the
// real compiler (`t27_compiler.wasm`), reads the English bodies the chapters name (Markdown
// under `docs/system/`), the Russian bundle the `specs/i18n/docs-<locale>.t27` contract
// names, and the four generated catalogs (skills, crons, agents, tools), and writes
// `public/docs/system-docs.json`: chapters with pre-rendered blocks, generated tables,
// figure data, counts, and every source with its sha256 and a link pinned at a commit.
//
// Nothing here parses a `.t27` with a regular expression; the constants come from the
// compiler's AST. Regular expressions are used on Markdown (the bodies and the two canon
// documents the laws and phases tables are read from) only.
//
// Run:      node scripts/docs-from-specs.mjs            (write)
//           node scripts/docs-from-specs.mjs --check    (fail if the committed JSON is stale)
// Produces: public/docs/system-docs.json
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  CYRILLIC, REPO_ROOT, SITE, T27_REPO_URL, agentPin, analyzeSpecFiles, checkSchema, loadCompiler, sha256, sortKeys,
} from './agents-from-specs.mjs'

const CORPUS = 'public/t27/files'
const WASM = 'public/t27/t27_compiler.wasm'
export const DOCS_SPEC = 'specs/docs/system.t27'
export const CHAPTER_DIR = 'specs/docs/chapters'
export const I18N_SPEC_DIR = 'specs/i18n'
export const DOCS_OUT = 'public/docs/system-docs.json'
export const DOCS_SCOPE = new Set(['specs/docs', CHAPTER_DIR])
export const VERSION = 1
const TRINITY_REPO_URL = 'https://github.com/gHashTag/trinity'

export const DOCS_REQUIRED = { KIND: 'str', ID: 'str', TITLE: 'str', CHAPTERS: 'arr', SOURCES: 'arr', DIAGRAMS: 'arr', LOCALES: 'arr', ENABLED: 'bool' }
export const CHAPTER_REQUIRED = { KIND: 'str', ID: 'str', DOCUMENT: 'str', ORDER: 'u8', TITLE: 'str', SOURCES: 'arr', SECTIONS: 'arr', DIAGRAM: 'str', TABLE: 'str', BODY_EN: 'str', ENABLED: 'bool' }
const I18N_REQUIRED = {
  KIND: 'str', LOCALE: 'str', SOURCE_LOCALE: 'str', SCOPE: 'arr', FIELDS: 'arr', BUNDLE_REPO: 'str', BUNDLE_PATH: 'str',
  BUNDLE_FORMAT: 'str', KEY: 'str', FALLBACK: 'str', COVERAGE_REQUIRED: 'bool', ORPHANS_ALLOWED: 'bool', ENABLED: 'bool',
}
export const I18N_FIELDS = ['TITLE', 'BODY']
/** Figures the site can draw from data (src/pages/SystemDocs.tsx). */
export const DIAGRAMS = ['ladder', 'agent-ring', 'phase-cycle', 'law-hierarchy', 'skills-crons-agents', 'tools-map']
/** Tables this generator can produce from the catalogs and canon documents. */
export const TABLES = ['claims', 'laws', 'ladder-counts', 'agents', 'phases', 'tools', 'witnesses']
export const STATUS_TAGS = ['measured', 'declared', 'specified', 'external', 'not claimed']

// Ranking words the canon forbids in first-party prose. English: phrases, so that the
// adverb "only" and ordinals such as "first-party" or "first line" do not trip it.
// Russian: stems (the words are inflected).
export const FORBIDDEN_EN = /\b(the first|world'?s first|first[- ]ever|the only|one of a kind|the best|best[- ]in[- ]class|industry[- ]leading|market[- ]leading|unrivall?ed|unparalleled|revolutionary|groundbreaking|breakthrough)(?![-\w])/gi
export const FORBIDDEN_RU = /(?<![\u0400-\u04ff-])(перв(ый|ая|ое|ые|ым|ыми|ого|ой|ую|ых)|единственн[\u0400-\u04ff]*|лучш[\u0400-\u04ff]*|уникальн[\u0400-\u04ff]*|революционн[\u0400-\u04ff]*|прорывн[\u0400-\u04ff]*|непревзойд[\u0400-\u04ff]*)(?![\u0400-\u04ff])/gi

const plain = (consts) => Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
const readJson = (rel) => (existsSync(join(SITE, rel)) ? JSON.parse(readFileSync(join(SITE, rel), 'utf8')) : null)
export const slug = (text) => text.toLowerCase().replace(/[`*_]/g, '').replace(/[^a-z0-9\u0400-\u04ff]+/g, '-').replace(/^-|-$/g, '')

// ---------------------------------------------------------------------------
// Markdown -> blocks. The bodies use a small dialect: `#`/`##`/`###` headings,
// paragraphs, `-` and `1.` lists (continuation lines indented), `>` quotes, fenced
// code, and inline `code`, **strong**, [text](url).
// ---------------------------------------------------------------------------
export function inlineRuns(text) {
  const runs = []
  const re = /`([^`]+)`|\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)\s]+)\)/g
  let last = 0
  let m
  while ((m = re.exec(text))) {
    if (m.index > last) runs.push({ t: 'text', v: text.slice(last, m.index) })
    if (m[1] !== undefined) runs.push({ t: 'code', v: m[1] })
    else if (m[2] !== undefined) runs.push({ t: 'strong', v: m[2] })
    else runs.push({ t: 'link', v: m[3], href: m[4] })
    last = re.lastIndex
  }
  if (last < text.length) runs.push({ t: 'text', v: text.slice(last) })
  return runs
}

export function parseMarkdown(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n')
  const blocks = []
  let title = null
  let i = 0
  const flushPara = (buf) => { if (buf.length) blocks.push({ type: 'p', runs: inlineRuns(buf.join(' ').trim()) }) }
  let para = []
  while (i < lines.length) {
    const line = lines[i]
    if (/^```/.test(line)) {
      flushPara(para); para = []
      const code = []
      i++
      while (i < lines.length && !/^```/.test(lines[i])) code.push(lines[i++])
      i++
      blocks.push({ type: 'code', text: code.join('\n') })
      continue
    }
    const h = /^(#{1,3})\s+(.*)$/.exec(line)
    if (h) {
      flushPara(para); para = []
      const level = h[1].length
      const text = h[2].trim()
      if (level === 1 && title === null) title = text
      else blocks.push({ type: 'h', level, text, id: slug(text) })
      i++
      continue
    }
    if (/^>\s?/.test(line)) {
      flushPara(para); para = []
      const q = []
      while (i < lines.length && /^>\s?/.test(lines[i])) q.push(lines[i++].replace(/^>\s?/, ''))
      blocks.push({ type: 'quote', runs: inlineRuns(q.join(' ').trim()) })
      continue
    }
    const li = /^(-|\d+\.)\s+(.*)$/.exec(line)
    if (li) {
      flushPara(para); para = []
      const ordered = li[1] !== '-'
      const items = []
      while (i < lines.length) {
        const m = /^(-|\d+\.)\s+(.*)$/.exec(lines[i])
        if (!m || (m[1] !== '-') !== ordered) break
        const buf = [m[2]]
        i++
        while (i < lines.length && /^\s{2,}\S/.test(lines[i])) buf.push(lines[i++].trim())
        items.push(inlineRuns(buf.join(' ').trim()))
      }
      blocks.push({ type: ordered ? 'ol' : 'ul', items })
      continue
    }
    if (!line.trim()) { flushPara(para); para = []; i++; continue }
    para.push(line.trim())
    i++
  }
  flushPara(para)
  return { title, blocks }
}

/** Split blocks into `lead` (before the first h2) and `sections` (one per h2). */
export function sectionize(blocks) {
  const lead = []
  const sections = []
  let cur = null
  for (const b of blocks) {
    if (b.type === 'h' && b.level === 2) { cur = { id: b.id, heading: b.text, blocks: [] }; sections.push(cur); continue }
    if (cur) cur.blocks.push(b)
    else lead.push(b)
  }
  return { lead, sections }
}

const runsText = (runs) => runs.map((r) => (r.t === 'link' ? r.v : r.v)).join('')
const stripCode = (md) => md.replace(/```[\s\S]*?```/g, ' ').replace(/`[^`]*`/g, ' ')

export function forbiddenIn(md, locale) {
  const re = locale === 'ru' ? FORBIDDEN_RU : FORBIDDEN_EN
  const text = stripCode(md)
  const hits = []
  let m
  re.lastIndex = 0
  while ((m = re.exec(text))) {
    const start = Math.max(0, m.index - 30)
    hits.push({ word: m[0], context: text.slice(start, m.index + m[0].length + 30).replace(/\s+/g, ' ').trim() })
  }
  return hits
}

// ---------------------------------------------------------------------------
// Sources. `path` is t27-root-relative, or trinity-root-relative with a `trinity:` prefix.
// Vendored copies under public/t27/files win; a t27 checkout (T27_ROOT, or a sibling of
// the trinity checkout) is the fallback; the record says which one was read.
// ---------------------------------------------------------------------------
export function t27CheckoutRoot() {
  const env = process.env.T27_ROOT
  if (env && existsSync(env)) return env
  const sibling = resolve(REPO_ROOT, '..', 't27')
  return existsSync(sibling) ? sibling : null
}

export function resolveSource(path, { pin, trinityPin }) {
  const isTrinity = path.startsWith('trinity:')
  const rel = isTrinity ? path.slice('trinity:'.length) : path
  const candidates = isTrinity
    ? [{ where: 'checkout', abs: join(REPO_ROOT, rel) }]
    : [{ where: 'vendored', abs: join(SITE, CORPUS, rel) }, ...(t27CheckoutRoot() ? [{ where: 'checkout', abs: join(t27CheckoutRoot(), rel) }] : [])]
  const repo = isTrinity ? 'trinity' : 't27'
  const ref = isTrinity ? trinityPin : pin
  const base = isTrinity ? TRINITY_REPO_URL : T27_REPO_URL
  for (const c of candidates) {
    if (!existsSync(c.abs)) continue
    const st = statSync(c.abs)
    if (st.isDirectory()) return { path, repo, rel, kind: 'dir', where: c.where, sha256: null, url: `${base}/tree/${ref}/${rel}` }
    return { path, repo, rel, kind: 'file', where: c.where, sha256: sha256(readFileSync(c.abs)), url: `${base}/blob/${ref}/${rel}` }
  }
  return { path, repo, rel, kind: null, where: 'missing', sha256: null, url: `${base}/blob/${ref}/${rel}` }
}

export function readSourceText(path) {
  if (path.startsWith('trinity:')) { const abs = join(REPO_ROOT, path.slice(8)); return existsSync(abs) ? readFileSync(abs, 'utf8') : null }
  const vend = join(SITE, CORPUS, path)
  if (existsSync(vend)) return readFileSync(vend, 'utf8')
  const root = t27CheckoutRoot()
  if (root && existsSync(join(root, path))) return readFileSync(join(root, path), 'utf8')
  return null
}

// ---------------------------------------------------------------------------
// Tables read from canon documents (Markdown, regex is fine here).
// ---------------------------------------------------------------------------
/** `### Law Table (L1-L7)` of docs/T27-CONSTITUTION.md -> rows {law, name, body, enforcement}. */
export function parseLawTable(md) {
  const lines = md.split('\n')
  const start = lines.findIndex((l) => /^###\s+Law Table/.test(l))
  if (start < 0) return { rows: [], heading: null, priority: null }
  const rows = []
  for (let i = start + 1; i < lines.length; i++) {
    const l = lines[i]
    if (/^#{1,3}\s/.test(l)) break
    const m = /^\|\s*\*\*(L\d+)\*\*\s*\|\s*\*\*([^*|]+)\*\*\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$/.exec(l)
    if (m) rows.push({ law: m[1], name: m[2].trim(), body: m[3].trim(), enforcement: m[4].trim() })
  }
  const pm = /(L1\s*>\s*L2[^\n]*?L\d+)/.exec(md)
  return { rows, heading: lines[start].replace(/^###\s+/, ''), priority: pm ? pm[1].replace(/\s+/g, ' ') : null }
}

/** `PHASE N: NAME` boxes of the alphabet's "6-Phase Cycle of AGENT T" -> rows {n, name, note, steps[]}. */
export function parsePhases(md) {
  const lines = md.split('\n')
  const start = lines.findIndex((l) => /^###\s+6-Phase Cycle/.test(l))
  if (start < 0) return []
  const phases = []
  let cur = null
  for (let i = start + 1; i < lines.length; i++) {
    const l = lines[i]
    if (/^#{1,3}\s/.test(l)) break
    const raw = l.replace(/^[\u2502|]\s*/, '').replace(/\s*[\u2502|]\s*$/, '').trim()
    const pm = /^PHASE\s+(\d+):\s+(.+?)\s*$/.exec(raw)
    if (pm) {
      const name = pm[2].replace(/\s*\((.*)\)\s*$/, '')
      const note = /\((.*)\)\s*$/.exec(pm[2])?.[1] ?? ''
      cur = { n: Number(pm[1]), name: name.trim(), note, steps: [] }
      phases.push(cur)
      continue
    }
    if (cur && /^[\u2022*-]\s+/.test(raw)) cur.steps.push(raw.replace(/^[\u2022*-]\s+/, '').trim())
  }
  return phases
}

/** Bullets carrying a status tag in a body -> rows {tag, claim, sources[]}. */
export function claimsFrom(md) {
  const rows = []
  // Tags are written as code spans, `[measured]`; a bullet that *starts* with one is the
  // glossary entry that defines the tag, not a claim.
  const tagRe = new RegExp(`\`\\[(${STATUS_TAGS.join('|')})\\]\``)
  const items = []
  const lines = md.split('\n')
  for (let i = 0; i < lines.length; i++) {
    const m = /^-\s+(.*)$/.exec(lines[i])
    if (!m) continue
    const buf = [m[1]]
    while (i + 1 < lines.length && /^\s{2,}\S/.test(lines[i + 1])) buf.push(lines[++i].trim())
    items.push(buf.join(' '))
  }
  for (const it of items) {
    const t = tagRe.exec(it)
    if (!t || t.index === 0) continue
    const claim = it.replace(tagRe, '').replace(/\*\*/g, '').replace(/\s+/g, ' ').replace(/\s+([:,.])/g, '$1').trim()
    const sources = [...it.matchAll(/`([^`]+)`/g)].map((x) => x[1]).filter((x) => /^[\w.:@-]*\/[\w./@-]+$|^[\w-]+\.(md|ts|tsx|json|t27|rs|mjs|yml|toml)$/.test(x))
    rows.push({ tag: t[1], claim: claim.length > 220 ? `${claim.slice(0, 217)}...` : claim, sources: [...new Set(sources)].slice(0, 4) })
  }
  return rows
}

// ---------------------------------------------------------------------------
// Build.
// ---------------------------------------------------------------------------
export function buildDocs({ docsSpec, chapterSpecs, i18nSpecs = [], bundles = new Map(), bodies = new Map(), catalogs, sourceTexts = new Map(), pin, trinityPin, compilerWasmSha256, generatedAt }) {
  const problems = []
  const warn = []
  for (const s of [docsSpec, ...chapterSpecs, ...i18nSpecs].filter(Boolean)) {
    if (s.text !== undefined && CYRILLIC.test(s.text)) problems.push(`${s.path}: Cyrillic in a .t27 spec (t27 LANG-EN; translated text belongs in the bundle a specs/i18n/*.t27 contract points to)`)
  }
  if (!docsSpec) { problems.push(`${DOCS_SPEC}: missing`); return { docs: null, problems } }
  const clean = (s) => { if (!s.verdict.typecheckOk || s.verdict.discarded > 0 || !s.verdict.hirOk) problems.push(`${s.path}: compiler verdict not clean (${JSON.stringify(s.verdict)})`) }

  clean(docsSpec)
  problems.push(...checkSchema(docsSpec.consts, DOCS_REQUIRED, {}, docsSpec.path))
  const D = plain(docsSpec.consts)
  if (D.KIND !== 'docs') problems.push(`${docsSpec.path}: KIND must be "docs"`)
  if (D.ID !== 'docs/system') problems.push(`${docsSpec.path}: ID must be "docs/system"`)
  if (docsSpec.moduleName && docsSpec.moduleName !== 'docs_system') problems.push(`${docsSpec.path}: module must be docs_system, is ${docsSpec.moduleName}`)
  const diagrams = Array.isArray(D.DIAGRAMS) ? D.DIAGRAMS : []
  for (const d of diagrams) if (!DIAGRAMS.includes(d)) problems.push(`${docsSpec.path}: DIAGRAMS names ${JSON.stringify(d)}, which the site cannot draw (${DIAGRAMS.join(', ')})`)
  const locales = Array.isArray(D.LOCALES) ? D.LOCALES : []
  if (locales[0] !== 'en') problems.push(`${docsSpec.path}: LOCALES[0] must be "en"`)

  // Translation contracts in scope.
  const localeSets = []
  for (const spec of [...i18nSpecs].sort((a, b) => a.path.localeCompare(b.path))) {
    const f = plain(spec.consts)
    const scope = Array.isArray(f.SCOPE) ? f.SCOPE : []
    if (!scope.some((d) => DOCS_SCOPE.has(d))) continue
    clean(spec)
    problems.push(...checkSchema(spec.consts, I18N_REQUIRED, {}, spec.path))
    if (f.KIND !== 'i18n') problems.push(`${spec.path}: KIND must be "i18n"`)
    if (f.SOURCE_LOCALE !== 'en' || f.FALLBACK !== 'en') problems.push(`${spec.path}: SOURCE_LOCALE and FALLBACK must be "en"`)
    if (f.KEY !== 'ID') problems.push(`${spec.path}: KEY must be "ID"`)
    if (f.BUNDLE_FORMAT !== 'json') problems.push(`${spec.path}: BUNDLE_FORMAT must be "json"`)
    const expectModule = `i18n_${spec.path.replace(/^specs\/i18n\//, '').replace(/\.t27$/, '').replace(/[^A-Za-z0-9]+/g, '_')}`
    if (spec.moduleName && spec.moduleName !== expectModule) problems.push(`${spec.path}: module must be ${expectModule}, is ${spec.moduleName}`)
    const fields = Array.isArray(f.FIELDS) ? f.FIELDS : []
    for (const name of fields) if (!I18N_FIELDS.includes(name)) problems.push(`${spec.path}: FIELDS names ${JSON.stringify(name)}; docs bundles carry ${I18N_FIELDS.join(', ')}`)
    if (!locales.includes(f.LOCALE)) problems.push(`${spec.path}: LOCALE ${JSON.stringify(f.LOCALE)} is not in ${docsSpec.path} LOCALES (${locales.join(', ')})`)
    const entry = { locale: f.LOCALE, spec: spec.path, sha256: spec.sha256, bundle: f.BUNDLE_REPO === 'trinity' ? f.BUNDLE_PATH : `${f.BUNDLE_REPO}:${f.BUNDLE_PATH}`, enabled: f.ENABLED === true, fields, scope, coverage: { n: 0, total: 0 }, missing: [] }
    let entries = null
    if (f.ENABLED === true) {
      if (f.BUNDLE_REPO !== 'trinity') problems.push(`${spec.path}: BUNDLE_REPO must be "trinity" (only a bundle in this repository can be loaded at build time)`)
      const bundle = bundles.get(f.BUNDLE_PATH) ?? null
      if (!bundle) problems.push(`${spec.path}: bundle ${f.BUNDLE_PATH} is missing or not JSON`)
      else {
        if (bundle.$spec !== spec.path) problems.push(`${f.BUNDLE_PATH}: $spec is ${JSON.stringify(bundle.$spec)}, the contract is ${spec.path}`)
        if (bundle.locale !== f.LOCALE) problems.push(`${f.BUNDLE_PATH}: locale ${JSON.stringify(bundle.locale)} does not match LOCALE ${JSON.stringify(f.LOCALE)}`)
        entries = bundle.entries && typeof bundle.entries === 'object' && !Array.isArray(bundle.entries) ? bundle.entries : null
        if (!entries) problems.push(`${f.BUNDLE_PATH}: entries must be an object keyed by spec ID`)
      }
    }
    localeSets.push({ locale: f.LOCALE, fields, contract: f, entry, entries, bundlePath: f.BUNDLE_PATH })
  }
  for (const l of locales.slice(1)) if (!localeSets.some((x) => x.locale === l)) problems.push(`${docsSpec.path}: LOCALES names ${JSON.stringify(l)} but no specs/i18n/docs-${l}.t27 contract is in scope`)

  // Chapters.
  const byId = new Map()
  for (const s of chapterSpecs) {
    clean(s)
    problems.push(...checkSchema(s.consts, CHAPTER_REQUIRED, {}, s.path))
    const f = plain(s.consts)
    const stem = s.path.replace(/^.*\//, '').replace(/\.t27$/, '')
    if (f.KIND !== 'docs-chapter') problems.push(`${s.path}: KIND must be "docs-chapter"`)
    if (f.ID !== `docs/${stem}`) problems.push(`${s.path}: ID must be "docs/${stem}", is ${JSON.stringify(f.ID)}`)
    if (f.DOCUMENT !== D.ID) problems.push(`${s.path}: DOCUMENT must be ${JSON.stringify(D.ID)}`)
    if (s.moduleName && s.moduleName !== `docs_chapter_${stem}`) problems.push(`${s.path}: module must be docs_chapter_${stem}, is ${s.moduleName}`)
    if (typeof f.DIAGRAM === 'string' && f.DIAGRAM !== '' && !diagrams.includes(f.DIAGRAM)) problems.push(`${s.path}: DIAGRAM ${JSON.stringify(f.DIAGRAM)} is not in ${docsSpec.path} DIAGRAMS`)
    if (typeof f.TABLE === 'string' && f.TABLE !== '' && !TABLES.includes(f.TABLE)) problems.push(`${s.path}: TABLE ${JSON.stringify(f.TABLE)} is not one the generator produces (${TABLES.join(', ')})`)
    if (typeof f.BODY_EN === 'string' && f.BODY_EN !== `docs/system/${stem}.md`) problems.push(`${s.path}: BODY_EN must be docs/system/${stem}.md`)
    byId.set(stem, { spec: s, f })
  }
  const order = Array.isArray(D.CHAPTERS) ? D.CHAPTERS : []
  for (const id of order) if (!byId.has(id)) problems.push(`${docsSpec.path}: CHAPTERS names ${JSON.stringify(id)} but ${CHAPTER_DIR}/${id}.t27 is missing`)
  for (const id of byId.keys()) if (!order.includes(id)) problems.push(`${CHAPTER_DIR}/${id}.t27 is not listed in ${docsSpec.path} CHAPTERS`)

  // Catalog-derived tables and figure data.
  const { skills, crons, agents, tools, t27Manifest } = catalogs
  const constitution = sourceTexts.get('docs/T27-CONSTITUTION.md') ?? ''
  const alphabet = sourceTexts.get('docs/agents/AGENTS_ALPHABET.md') ?? ''
  const laws = parseLawTable(constitution)
  const phases = parsePhases(alphabet)
  const agentRows = (agents?.agents ?? []).map((a) => ({
    letter: a.letter, ordinal: a.ordinal, letterName: a.fields.LETTER_NAME, name: a.fields.NAME, domain: a.fields.DOMAIN, archetype: a.fields.ARCHETYPE,
    register: a.fields.REGISTER, layer: a.fields.LAYER, enabled: a.fields.ENABLED === true, skills: (a.skills ?? []).map((x) => x.id), tools: (a.tools ?? []).map((x) => x.id), episodes: a.experience?.episodes ?? 0,
  })).sort((a, b) => a.ordinal - b.ordinal)
  const toolRows = (tools?.tools ?? []).map((t) => ({
    id: t.id, family: t.family, name: t.family === 'tri-cli' ? t.command : t.fields.SERVER, repo: t.repo, items: t.family === 'tri-cli' ? (t.actions ?? []).length : (t.fields.TOOLS ?? []).length,
    agents: (t.agents ?? []).map((x) => x.letter), witness: t.fields.WITNESS, external: t.external === true,
  })).sort((a, b) => a.id.localeCompare(b.id))
  const ladder = {
    specs: t27Manifest?.specs?.length ?? 0, skills: skills?.counts?.specs ?? 0, crons: crons?.counts?.specs ?? 0, agents: agents?.counts?.specs ?? 0, tools: tools?.counts?.specs ?? 0, docsChapters: order.length,
  }
  const ladderRows = [
    { layer: 'Specs', dir: 'specs/**', count: ladder.specs, typecheckOk: t27Manifest?.health?.typecheckOk ?? null, source: 'public/t27/manifest.json' },
    { layer: 'Skills', dir: 'specs/skills', count: ladder.skills, typecheckOk: skills?.counts?.typecheckOk ?? null, source: 'public/skills/spec-skills.json' },
    { layer: 'Crons', dir: 'specs/crons', count: ladder.crons, typecheckOk: crons?.counts?.typecheckOk ?? null, source: 'public/crons/spec-crons.json' },
    { layer: 'Agents', dir: 'specs/agents', count: ladder.agents, typecheckOk: agents?.counts?.typecheckOk ?? null, source: 'public/agents/spec-agents.json' },
    { layer: 'Tools', dir: 'specs/tools/{tri,mcp}', count: ladder.tools, typecheckOk: tools?.counts?.typecheckOk ?? null, source: 'public/tools/spec-tools.json' },
  ]
  const witnessRows = [
    ...['specPlusCode', 'specOnly', 'codeOnly'].map((k) => ({ layer: 'Skills', label: { specPlusCode: 'spec+code', specOnly: 'spec-only', codeOnly: 'code-only' }[k], count: skills?.counts?.[k] ?? 0, source: 'public/skills/spec-skills.json counts' })),
    ...['specPlusCode', 'specOnly', 'codeOnly'].map((k) => ({ layer: 'Crons', label: { specPlusCode: 'spec+code', specOnly: 'spec-only', codeOnly: 'code-only' }[k], count: crons?.counts?.[k] ?? 0, source: 'public/crons/spec-crons.json counts' })),
    { layer: 'Crons', label: 'with RUNS', count: crons?.counts?.withRuns ?? 0, source: 'public/crons/spec-crons.json counts' },
    { layer: 'Agents', label: 'with skills (source-bound)', count: agents?.counts?.withSkills ?? 0, source: 'public/agents/spec-agents.json counts' },
    { layer: 'Agents', label: 'with tools (bound both ways)', count: agents?.counts?.withTools ?? 0, source: 'public/agents/spec-agents.json counts' },
    { layer: 'Agents', label: 'spec+experience', count: agents?.counts?.specPlusExperience ?? 0, source: 'public/agents/spec-agents.json counts' },
    { layer: 'Agents', label: 'spec-only', count: agents?.counts?.specOnly ?? 0, source: 'public/agents/spec-agents.json counts' },
    { layer: 'Experience', label: 'episodes attributed', count: agents?.counts?.episodesAttributed ?? 0, source: 'public/agents/experience.json' },
    { layer: 'Experience', label: 'episodes unattributed', count: agents?.counts?.episodesUnattributed ?? 0, source: 'public/agents/experience.json' },
    ...Object.entries(tools?.counts?.byWitness ?? {}).map(([label, count]) => ({ layer: 'Tools', label, count, source: 'public/tools/spec-tools.json counts.byWitness' })),
    { layer: 'Tools', label: 'external (tool list not in either repository)', count: tools?.counts?.mcpExternal ?? 0, source: 'public/tools/spec-tools.json counts' },
    { layer: 'All catalogs', label: 'typecheck ok', count: (skills?.counts?.typecheckOk ?? 0) + (crons?.counts?.typecheckOk ?? 0) + (agents?.counts?.typecheckOk ?? 0) + (tools?.counts?.typecheckOk ?? 0), source: 'counts.typecheckOk of the four catalogs' },
  ]
  const tables = {
    laws: { columns: ['law', 'name', 'body', 'enforcement'], rows: laws.rows, source: 'docs/T27-CONSTITUTION.md, section 2', note: laws.priority ? `Priority: ${laws.priority}` : '' },
    phases: { columns: ['n', 'name', 'steps'], rows: phases, source: 'docs/agents/AGENTS_ALPHABET.md, "6-Phase Cycle of AGENT T"', note: '' },
    'ladder-counts': { columns: ['layer', 'dir', 'count', 'typecheckOk', 'source'], rows: ladderRows, source: 'the four catalog JSON files and public/t27/manifest.json', note: '' },
    agents: { columns: ['letter', 'ordinal', 'letterName', 'domain', 'archetype', 'register', 'layer', 'skills', 'tools'], rows: agentRows, source: 'public/agents/spec-agents.json', note: '' },
    tools: { columns: ['id', 'family', 'name', 'repo', 'items', 'agents', 'witness', 'external'], rows: toolRows, source: 'public/tools/spec-tools.json', note: '' },
    witnesses: { columns: ['layer', 'label', 'count', 'source'], rows: witnessRows, source: 'counts of the four catalog JSON files and public/agents/experience.json', note: '' },
    claims: { columns: ['tag', 'claim', 'sources'], rows: [], source: 'status-tagged bullets of docs/system/project.md', note: '' },
  }
  const projectBody = bodies.get('docs/system/project.md')
  if (projectBody) tables.claims.rows = claimsFrom(projectBody)

  // Figure data.
  const graphEdges = []
  for (const c of crons?.crons ?? []) for (const r of c.runs ?? []) if (r.ok) graphEdges.push({ from: c.id, to: r.id, kind: 'cron-runs-skill' })
  for (const a of agents?.agents ?? []) {
    for (const s of a.skills ?? []) if (s.ok) graphEdges.push({ from: a.id, to: s.id, kind: 'agent-holds-skill' })
    for (const t of a.tools ?? []) if (t.ok) graphEdges.push({ from: a.id, to: t.id, kind: 'agent-holds-tool' })
  }
  const figures = {
    ladder: { counts: ladder, source: 'public/*/spec-*.json counts and public/t27/manifest.json' },
    'agent-ring': { agents: agentRows.map((a) => ({ letter: a.letter, ordinal: a.ordinal, layer: a.layer, name: a.name, skills: a.skills.length, tools: a.tools.length })), source: 'public/agents/spec-agents.json' },
    'phase-cycle': { phases: phases.map((p) => ({ n: p.n, name: p.name, note: p.note, steps: p.steps.length })), source: 'docs/agents/AGENTS_ALPHABET.md' },
    'law-hierarchy': { laws: laws.rows.map((l) => ({ law: l.law, name: l.name })), priority: laws.priority, source: 'docs/T27-CONSTITUTION.md' },
    'skills-crons-agents': { edges: graphEdges, counts: { skills: ladder.skills, crons: ladder.crons, agents: ladder.agents, tools: ladder.tools }, source: 'public/crons/spec-crons.json RUNS, public/agents/spec-agents.json SKILLS/TOOLS' },
    'tools-map': { triByAgent: tools?.groups?.triByAgent ?? {}, mcpByRepo: tools?.groups?.mcpByRepo ?? {}, external: toolRows.filter((t) => t.external).map((t) => t.id), source: 'public/tools/spec-tools.json groups' },
  }
  if (!laws.rows.length) problems.push('docs/T27-CONSTITUTION.md: no rows read from the Law Table (the laws table and law-hierarchy figure would be empty)')
  if (!phases.length) problems.push('docs/agents/AGENTS_ALPHABET.md: no PHASE N: lines read from the 6-Phase Cycle (the phases table would be empty)')

  // Sources of the document.
  const docSources = (Array.isArray(D.SOURCES) ? D.SOURCES : []).map((p) => resolveSource(p, { pin, trinityPin }))
  for (const s of docSources) if (s.where === 'missing') problems.push(`${docsSpec.path}: SOURCES names ${s.path}, which is neither vendored under ${CORPUS} nor in the t27 checkout`)

  // Assemble chapters.
  const chapters = []
  for (const id of order) {
    const ch = byId.get(id)
    if (!ch) continue
    const { spec, f } = ch
    const sections = Array.isArray(f.SECTIONS) ? f.SECTIONS : []
    const md = bodies.get(f.BODY_EN) ?? null
    let en = { title: null, lead: [], sections: [] }
    if (md === null) problems.push(`${spec.path}: BODY_EN ${f.BODY_EN} is missing from ${CORPUS}`)
    else {
      const parsed = parseMarkdown(md)
      const { lead, sections: secs } = sectionize(parsed.blocks)
      if (!parsed.title) problems.push(`${f.BODY_EN}: must start with a level-1 heading`)
      else if (parsed.title !== f.TITLE) problems.push(`${f.BODY_EN}: level-1 heading ${JSON.stringify(parsed.title)} differs from TITLE ${JSON.stringify(f.TITLE)}`)
      const heads = secs.map((s) => s.heading)
      if (JSON.stringify(heads) !== JSON.stringify(sections)) problems.push(`${f.BODY_EN}: level-2 headings ${JSON.stringify(heads)} must equal SECTIONS ${JSON.stringify(sections)}`)
      for (const s of secs) if (!s.blocks.length) problems.push(`${f.BODY_EN}: section ${JSON.stringify(s.heading)} has no body`)
      if (!secs.length) problems.push(`${f.BODY_EN}: no sections`)
      if (CYRILLIC.test(md)) problems.push(`${f.BODY_EN}: Cyrillic in the English body (LANG-EN)`)
      for (const hit of forbiddenIn(md, 'en')) problems.push(`${f.BODY_EN}: ranking word ${JSON.stringify(hit.word)}: "...${hit.context}..."`)
      en = { title: parsed.title, lead, sections: secs }
    }
    const translations = {}
    for (const L of localeSets) {
      const e = L.entries?.[f.ID]
      L.entry.coverage.total += 1
      if (!e) { L.entry.missing.push(f.ID); continue }
      const tr = {}
      for (const [k, v] of Object.entries(e)) {
        if (!L.fields.includes(k)) { problems.push(`${L.bundlePath}: entry ${f.ID} carries ${JSON.stringify(k)}, which is not in FIELDS (${L.fields.join(', ')})`); continue }
        if (typeof v !== 'string' || !v.trim()) { problems.push(`${L.bundlePath}: entry ${f.ID}.${k} must be a non-empty string`); continue }
        tr[k] = v
      }
      if (tr.BODY) {
        const parsed = parseMarkdown(tr.BODY)
        const { lead, sections: secs } = sectionize(parsed.blocks)
        if (secs.length !== sections.length) problems.push(`${L.bundlePath}: entry ${f.ID}.BODY has ${secs.length} level-2 heading(s), the English body has ${sections.length}`)
        for (const hit of forbiddenIn(tr.BODY, L.locale)) problems.push(`${L.bundlePath}: entry ${f.ID}.BODY ranking word ${JSON.stringify(hit.word)}: "...${hit.context}..."`)
        translations[L.locale] = { title: tr.TITLE ?? null, lead, sections: secs }
      } else if (tr.TITLE) translations[L.locale] = { title: tr.TITLE, lead: [], sections: [] }
      if (tr.TITLE && forbiddenIn(tr.TITLE, L.locale).length) problems.push(`${L.bundlePath}: entry ${f.ID}.TITLE carries a ranking word`)
      L.entry.coverage.n += 1
    }
    const srcs = (Array.isArray(f.SOURCES) ? f.SOURCES : []).map((p) => resolveSource(p, { pin, trinityPin }))
    for (const s of srcs) if (s.where === 'missing') problems.push(`${spec.path}: SOURCES names ${s.path}, which is neither vendored under ${CORPUS} nor in the t27 checkout`)
    const table = f.TABLE && tables[f.TABLE] ? { kind: f.TABLE, ...tables[f.TABLE] } : null
    if (f.TABLE && table && !table.rows.length) problems.push(`${spec.path}: TABLE ${f.TABLE} generated no rows`)
    chapters.push({
      id: f.ID, stem: id, order: f.ORDER, enabled: f.ENABLED === true, specPath: spec.path, sha256: spec.sha256, moduleName: spec.moduleName, typecheckOk: spec.verdict.typecheckOk, discarded: spec.verdict.discarded,
      title: { en: f.TITLE, ...Object.fromEntries(Object.entries(translations).filter(([, v]) => v.title).map(([k, v]) => [k, v.title])) },
      sections: sections.map((h, i) => ({ id: slug(h), heading: { en: h, ...Object.fromEntries(Object.entries(translations).filter(([, v]) => v.sections[i]).map(([k, v]) => [k, v.sections[i].heading])) } })),
      body: { en, ...Object.fromEntries(Object.entries(translations).filter(([, v]) => v.sections.length).map(([k, v]) => [k, { lead: v.lead, sections: v.sections }])) },
      bodyPath: f.BODY_EN, bodySha256: md === null ? null : sha256(Buffer.from(md, 'utf8')), diagram: f.DIAGRAM || null, table, sources: srcs,
      links: { spec: `${T27_REPO_URL}/blob/${pin}/${spec.path}`, body: `${T27_REPO_URL}/blob/${pin}/${f.BODY_EN}` },
    })
    if (f.ORDER !== order.indexOf(id) + 1) problems.push(`${spec.path}: ORDER ${f.ORDER} does not match its position ${order.indexOf(id) + 1} in CHAPTERS`)
  }
  // Orphans and coverage per locale.
  for (const L of localeSets) {
    for (const id of Object.keys(L.entries ?? {})) {
      if (id === D.ID) continue
      if (!chapters.some((c) => c.id === id)) { if (L.contract.ORPHANS_ALLOWED !== true) problems.push(`${L.bundlePath}: entry ${JSON.stringify(id)} matches no chapter and ORPHANS_ALLOWED is false`) }
    }
    if (L.contract.COVERAGE_REQUIRED === true && L.entry.missing.length) problems.push(`${L.entry.spec}: COVERAGE_REQUIRED and ${L.entry.missing.length} chapter(s) have no ${L.locale} entry`)
    L.entry.missing.sort()
  }
  const docTitle = { en: D.TITLE }
  for (const L of localeSets) { const t = L.entries?.[D.ID]?.TITLE; if (typeof t === 'string' && t.trim()) docTitle[L.locale] = t }

  const counts = {
    chapters: chapters.length, enabled: chapters.filter((c) => c.enabled).length, sections: chapters.reduce((n, c) => n + c.sections.length, 0), typecheckOk: chapters.filter((c) => c.typecheckOk).length + (docsSpec.verdict.typecheckOk ? 1 : 0),
    specs: chapters.length + 1 + localeSets.length, sources: chapters.reduce((n, c) => n + c.sources.length, 0), sourcesVendored: chapters.reduce((n, c) => n + c.sources.filter((s) => s.where === 'vendored').length, 0),
    sourcesCheckout: chapters.reduce((n, c) => n + c.sources.filter((s) => s.where === 'checkout').length, 0), tables: chapters.filter((c) => c.table).length, diagrams: chapters.filter((c) => c.diagram).length,
    laws: laws.rows.length, phases: phases.length, ...Object.fromEntries(localeSets.map((L) => [`${L.locale}Chapters`, L.entry.coverage.n])),
  }
  const docs = sortKeys({
    version: VERSION, compilerWasmSha256, generatedAt,
    pin: { ref: pin, trinity: trinityPin, source: 'public/agents/experience.json sources[t27].commit / sources[trinity].commit' },
    document: { id: D.ID, title: docTitle, specPath: docsSpec.path, sha256: docsSpec.sha256, typecheckOk: docsSpec.verdict.typecheckOk, chapters: order, diagrams, locales, enabled: D.ENABLED === true, sources: docSources, link: `${T27_REPO_URL}/blob/${pin}/${docsSpec.path}` },
    chapters, figures, ladder, counts, i18n: localeSets.map((L) => L.entry), warnings: warn,
  })
  const { generatedAt: _g, ...rest } = docs
  docs.contentSha256 = sha256(Buffer.from(JSON.stringify(rest)))
  return { docs, problems }
}

// ---------------------------------------------------------------------------
// IO.
// ---------------------------------------------------------------------------
function readSpecDir(dir) {
  const abs = join(SITE, CORPUS, dir)
  if (!existsSync(abs)) return []
  return readdirSync(abs).filter((f) => f.endsWith('.t27')).sort().map((f) => ({ path: `${dir}/${f}`, text: readFileSync(join(abs, f), 'utf8') }))
}

export async function generate({ generatedAt } = {}) {
  const wasmBytes = readFileSync(join(SITE, WASM))
  const analyze = await loadCompiler(wasmBytes)
  const sysAbs = join(SITE, CORPUS, DOCS_SPEC)
  const docsSpec = existsSync(sysAbs) ? analyzeSpecFiles(analyze, [{ path: DOCS_SPEC, text: readFileSync(sysAbs, 'utf8') }])[0] : null
  const chapterSpecs = analyzeSpecFiles(analyze, readSpecDir(CHAPTER_DIR))
  const i18nSpecs = analyzeSpecFiles(analyze, readSpecDir(I18N_SPEC_DIR))
  const bundles = new Map()
  for (const s of i18nSpecs) {
    const path = plain(s.consts).BUNDLE_PATH
    if (typeof path !== 'string' || path.includes('..')) continue
    const abs = join(REPO_ROOT, path)
    if (existsSync(abs)) { try { bundles.set(path, JSON.parse(readFileSync(abs, 'utf8'))) } catch { bundles.set(path, null) } }
  }
  const bodies = new Map()
  for (const s of chapterSpecs) {
    const p = plain(s.consts).BODY_EN
    if (typeof p !== 'string') continue
    const abs = join(SITE, CORPUS, p)
    if (existsSync(abs)) bodies.set(p, readFileSync(abs, 'utf8'))
  }
  const sourceTexts = new Map()
  for (const p of ['docs/T27-CONSTITUTION.md', 'docs/agents/AGENTS_ALPHABET.md']) { const t = readSourceText(p); if (t !== null) sourceTexts.set(p, t) }
  const experience = readJson('public/agents/experience.json')
  const pin = agentPin(experience).ref
  const trinity = (experience?.sources ?? []).find((x) => x.repo === 'trinity' && /^[0-9a-f]{40}$/.test(x.commit ?? ''))
  const trinityPin = trinity ? trinity.commit : 'main'
  const epoch = process.env.SOURCE_DATE_EPOCH
  const stamp = generatedAt ?? (epoch ? new Date(Number(epoch) * 1000).toISOString() : new Date().toISOString())
  return buildDocs({
    docsSpec, chapterSpecs, i18nSpecs, bundles, bodies, sourceTexts, pin, trinityPin,
    catalogs: { skills: readJson('public/skills/spec-skills.json'), crons: readJson('public/crons/spec-crons.json'), agents: readJson('public/agents/spec-agents.json'), tools: readJson('public/tools/spec-tools.json'), t27Manifest: readJson('public/t27/manifest.json') },
    compilerWasmSha256: sha256(wasmBytes), generatedAt: stamp,
  })
}

function writeAtomic(rel, data) {
  const dest = join(SITE, rel)
  mkdirSync(dirname(dest), { recursive: true })
  const temp = `${dest}.${process.pid}.tmp`
  writeFileSync(temp, `${JSON.stringify(data)}\n`, { flag: 'wx' })
  renameSync(temp, dest)
}

async function main(argv) {
  const check = argv.includes('--check')
  const { docs, problems } = await generate()
  if (problems.length) {
    console.error(`docs-from-specs: ${problems.length} problem(s)`)
    for (const p of problems) console.error('  ' + p)
    process.exit(1)
  }
  if (check) {
    const prior = readJson(DOCS_OUT)
    if (prior?.contentSha256 !== docs.contentSha256) { console.error(`docs-from-specs: committed output is stale: ${DOCS_OUT} -- run node scripts/docs-from-specs.mjs`); process.exit(1) }
    console.log(`docs-from-specs: ${DOCS_OUT} matches the specs`)
    return
  }
  writeAtomic(DOCS_OUT, docs)
  const c = docs.counts
  console.log(`docs-from-specs: ${c.chapters} chapters (${c.sections} sections; typecheck ok ${c.typecheckOk}/${c.chapters + 1}; tables ${c.tables}, figures ${c.diagrams}; laws ${c.laws}, phases ${c.phases}; sources ${c.sources}: vendored ${c.sourcesVendored}, checkout ${c.sourcesCheckout}; pinned at ${docs.pin.ref.slice(0, 7)}) -> ${DOCS_OUT}`)
  for (const l of docs.i18n) console.log(`docs-from-specs: i18n ${l.locale} via ${l.spec} -> ${l.bundle}: chapters ${l.coverage.n}/${l.coverage.total}${l.missing.length ? ` (missing ${l.missing.join(', ')})` : ''}${l.enabled ? '' : ' (disabled)'}`)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch((e) => { console.error(e); process.exit(1) })
}
