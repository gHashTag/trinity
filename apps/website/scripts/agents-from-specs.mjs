#!/usr/bin/env node
// Skills and crons, generated FROM their .t27 specs by the real compiler.
//
// The spec is the source of truth: public/t27/files/specs/skills/*.t27 and
// public/t27/files/specs/crons/*.t27 are read here, analysed with the vendored
// t27_compiler.wasm (the same bytes the browser runs), and the constants are
// taken from the AST it returns. Nothing in a .t27 file is parsed with a regex.
// The code catalogs (public/skills/manifest.json, public/crons/manifest.json)
// are the WITNESS side: a spec whose ID they also list is `spec+code`; a spec
// they do not list is `spec-only` (warn); a catalog entry with no spec is
// `code-only` and is listed, not invented.
//
//   node scripts/agents-from-specs.mjs            write both JSON files
//   node scripts/agents-from-specs.mjs --check    regenerate in memory and diff
//
// Outputs: public/skills/spec-skills.json, public/crons/spec-crons.json,
// public/agents/spec-agents.json (layer 4: specs/agents/<letter>.t27 x 27, with
// skills resolved, crons derived from RUNS, and experience joined by LETTER from
// public/agents/experience.json -- see scripts/sync-agents-experience.mjs),
// public/functions/spec-functions.json (layer 5: specs/functions/<id>.t27 x 28,
// the Inngest functions of 999-multibots-telegraf, witnessed by a vendored copy
// of the functions manifest at public/functions/manifest.json: spec+code /
// spec-only / code-only exactly like skills; a spec whose TRIGGER, EVENT, CRON,
// RETRIES, ON_FAILURE, STEPS or SIDE_EFFECTS differ from the manifest entry is
// not a failure -- the distance is written on the card and health drops to warn).
// Live run counts are NOT here: the page polls the bot's status endpoint at
// runtime and says "offline" when it cannot.
//
// Language: the specs are English-only (t27 LANG-EN; bootstrap/build.rs on
// gHashTag/t27 fails the build on any Cyrillic in specs/). A Cyrillic character
// in a spec is a problem here too, so the vendored copy can never drift from
// what the canonical repository accepts. Translations are CONNECTED THROUGH A
// SPEC: every public/t27/files/specs/i18n/*.t27 (KIND "i18n", one per locale)
// declares the locale, the spec directories in SCOPE, the FIELDS a bundle may
// translate, and the BUNDLE_PATH (repo-relative, in BUNDLE_REPO) of the JSON
// that carries the translated text. This file discovers those specs, loads each
// bundle, checks it against its contract (locale matches, entry keys within
// FIELDS, every entry ID resolves to a spec in SCOPE unless ORPHANS_ALLOWED,
// full coverage if COVERAGE_REQUIRED) and emits summary/name as {en, <locale>}
// plus an `i18n` list with the coverage per catalog. No locale is hardcoded.
//
// Compiler quirks this file depends on (verified against the vendored wasm):
//   * a string literal comes back as ExprLiteral{value:'"..."'} -- the value
//     keeps its quotes, so it is JSON-parsed, not trimmed;
//   * an array literal comes back as ExprIdentifier{name:'["a","b"]'} -- the
//     whole literal in the identifier's name, again JSON-parseable;
//   * the JSON the wasm returns carries every non-ASCII byte as a separate
//     char code < 256 (UTF-8 bytes read as Latin-1). `decodeBytes` undoes that
//     only when every char code fits a byte, so already-correct text is left
//     alone. Round-trip is exact for Cyrillic and the ✓ ⟲ ◷ glyphs;
//   * `typecheck.ok` from this wasm is NECESSARY, NOT SUFFICIENT: it stays true
//     for `pub const X : str = 5;`, for `[2]str = ["a"]` and for a u16 of
//     70000 (measured, see the test file). So the gate that actually holds is
//     `checkSchema` below -- every constant's annotation, value shape, array
//     length and integer range are checked here, from the AST, and a spec is
//     only "ok" when both the compiler and the schema accept it.

import { createHash } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
export const SKILL_SPEC_DIR = 'specs/skills'
export const CRON_SPEC_DIR = 'specs/crons'
const CORPUS = 'public/t27/files'
const WASM = 'public/t27/t27_compiler.wasm'
export const SKILLS_OUT = 'public/skills/spec-skills.json'
export const CRONS_OUT = 'public/crons/spec-crons.json'
export const I18N_SPEC_DIR = 'specs/i18n'
// Layer 4: the 27-agent alphabet (specs/agents/<letter>.t27), joined to the
// experience snapshot scripts/sync-agents-experience.mjs writes.
export const AGENT_SPEC_DIR = 'specs/agents'
export const AGENTS_OUT = 'public/agents/spec-agents.json'
// Layer 5: the tri CLI and the MCP servers (specs/tools/tri/*.t27, specs/tools/mcp/*.t27).
// The three corpus specs at the top of specs/tools/ are not tool cards and are not read.
export const TOOL_SPEC_DIR = 'specs/tools'
export const TOOL_SPEC_SUBDIRS = ['tri', 'mcp']
export const TOOLS_OUT = 'public/tools/spec-tools.json'
export const TOOL_FAMILIES = { tri: 'tri-cli', mcp: 'mcp' }
export const TOOL_WITNESSES = ['source-parse', 'help-output']
export const CATALOG_SPEC_DIRS = new Set([SKILL_SPEC_DIR, CRON_SPEC_DIR, AGENT_SPEC_DIR, TOOL_SPEC_DIR])
export const EXPERIENCE_PATH = 'public/agents/experience.json'
export const AGENT_LAYERS = ['Archetypal', 'Spiritual', 'Physical']
export const AGENT_COUNT = 27
// Layer 5: the Inngest functions of 999-multibots-telegraf (specs/functions/<id>.t27),
// witnessed by the vendored functions manifest.
export const FUNCTION_SPEC_DIR = 'specs/functions'
export const FUNCTIONS_OUT = 'public/functions/spec-functions.json'
export const FUNCTIONS_MANIFEST = 'public/functions/manifest.json'
export const FN_TRIGGERS = ['event', 'cron']
export const FN_ON_FAILURE = ['admin-telegram', 'log', 'refund+notify']
export const FN_SIDE_EFFECTS = ['charges-balance', 'paid-api', 'messages-user', 'messages-owners', 'messages-admin', 'db-write', 'external-webhook', 'none']
export const FN_PROBE_RESULTS = ['COMPLETED', 'FAILED-at-guard', 'skipped', 'not-deployed']
export const FN_CONTROLS = ['spec+code', 'spec-only', 'code-only']
export const T27_REPO_URL = 'https://github.com/gHashTag/t27'
// Repo root of gHashTag/trinity (BUNDLE_PATH is repo-relative).
export const REPO_ROOT = resolve(SITE, '..', '..')
export const VERSION = 1

export const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')

// ---------------------------------------------------------------------------
// The compiler.
// ---------------------------------------------------------------------------
export async function loadCompiler(wasmBytes) {
  const { instance } = await WebAssembly.instantiate(wasmBytes, {})
  const w = instance.exports
  return function analyze(source) {
    const bytes = new TextEncoder().encode(source)
    const inPtr = w.t27_alloc(bytes.length)
    new Uint8Array(w.memory.buffer, inPtr, bytes.length).set(bytes)
    const outPtr = w.t27_analyze(inPtr, bytes.length)
    const len = new DataView(w.memory.buffer).getUint32(outPtr, true)
    const json = new TextDecoder().decode(new Uint8Array(w.memory.buffer, outPtr + 4, len))
    w.t27_free(outPtr, 4 + len)
    return JSON.parse(json)
  }
}

export function decodeBytes(text) {
  if (typeof text !== 'string') return text
  let allBytes = true
  for (const ch of text) {
    if (ch.charCodeAt(0) > 255) { allBytes = false; break }
  }
  if (!allBytes) return text
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(text, (c) => c.charCodeAt(0)))
  } catch {
    return text
  }
}

/** Every `pub const` of the module, from the AST, as `{ name: { type, value } }`. */
export function constsOf(analysis) {
  const out = {}
  const decls = (analysis.ast?.children ?? []).filter((n) => n.kind === 'ConstDecl')
  for (const d of decls) {
    const expr = d.children?.[0]
    if (!expr) continue
    let value
    if (expr.kind === 'ExprLiteral') {
      const raw = decodeBytes(expr.value)
      if (raw === 'true') value = true
      else if (raw === 'false') value = false
      else if (/^-?\d+$/.test(raw)) value = Number(raw)
      else value = JSON.parse(raw)
    } else if (expr.kind === 'ExprIdentifier') {
      value = JSON.parse(decodeBytes(expr.name))
    } else {
      throw new Error(`${d.name}: unsupported expression kind ${expr.kind}`)
    }
    if (d.name in out) throw new Error(`duplicate constant ${d.name}`)
    out[d.name] = { type: d.type, value, pub: d.pub === true }
  }
  return out
}

export function verdictOf(analysis) {
  const discarded = (analysis.discarded?.length ?? 0) + (analysis.lexerDiscarded?.length ?? 0) + (analysis.swallowed?.length ?? 0)
  return {
    typecheckOk: analysis.typecheck?.ok === true,
    errors: analysis.typecheck?.errorCount ?? (analysis.typecheck?.errors?.length ?? 0),
    discarded,
    hirOk: analysis.hir?.ok !== false,
  }
}

// ---------------------------------------------------------------------------
// Schema.
// ---------------------------------------------------------------------------
// Shapes: 'str' | 'bool' | 'arr' (of str) | 'u16' | 'u32'.
const SKILL_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', REPO: 'str', SOURCE: 'str', SUMMARY_EN: 'str',
  COMMAND: 'str', SPECS: 'arr', TAGS: 'arr', ENABLED: 'bool', TIMEOUT_MIN: 'u16',
}
const CRON_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', HOST: 'str', REPO: 'str', SERVICE: 'str', SUMMARY_EN: 'str',
  TZ: 'str', RUNS: 'arr', RUNS_NOTE: 'str', ENABLED: 'bool', ON_FAILURE: 'str', CONTROL: 'str',
}
const CRON_OPTIONAL = { SCHEDULE: 'str', SCHEDULE_NOTE: 'str', INTERVAL_MS: 'u32', NOTE: 'str' }
const AGENT_REQUIRED = {
  KIND: 'str', ID: 'str', LETTER: 'str', ORDINAL: 'u8', LETTER_NAME: 'str', NAME: 'str', DOMAIN: 'str', ARCHETYPE: 'str',
  REGISTER: 'str', LAYER: 'str', SUMMARY_EN: 'str', SOUL: 'str', AGENTS_DOC: 'str', ALPHABET: 'str', KEY_FILES: 'arr',
  ENTRY_INVARIANT: 'str', EXIT_INVARIANT: 'str', CLARA_ROLE: 'str', SKILLS: 'arr', SKILLS_NOTE: 'str',
  EXPERIENCE_LOG: 'str', ENABLED: 'bool',
}
// TOOLS arrived with layer 5 (specs/tools); an agent spec written before it may still omit it.
const AGENT_OPTIONAL = { TOOLS: 'arr', TOOLS_NOTE: 'str' }
const FUNCTION_REQUIRED = {
  KIND: 'str', ID: 'str', LEGACY_ID: 'str', NAME: 'str', REPO: 'str', SERVICE: 'str', DOMAIN: 'str', TRIGGER: 'str',
  EVENT: 'str', LEGACY_EVENTS: 'arr', CRON: 'str', TZ: 'str', SUMMARY_EN: 'str', STEPS: 'arr', RETRIES: 'u8',
  ON_FAILURE: 'str', SIDE_EFFECTS: 'arr', GUARD: 'str', SAFE_PROBE: 'str', PROBE_RESULT: 'str', CONTROL: 'str', NOTE: 'str',
}
const TOOL_TRI_REQUIRED = {
  KIND: 'str', FAMILY: 'str', ID: 'str', COMMAND: 'str', VARIANT: 'str', SOURCE: 'str', ENTRY: 'str', ABOUT: 'str', ABOUT_SOURCE: 'str',
  ACTIONS: 'arr', ACTIONS_ABOUT: 'arr', ARGS: 'arr', AGENTS: 'arr', AGENTS_NOTE: 'str', WHEN_TO_USE: 'str', WITNESS: 'str', ENABLED: 'bool',
}
const TOOL_MCP_REQUIRED = {
  KIND: 'str', FAMILY: 'str', ID: 'str', SERVER: 'str', SERVER_VERSION: 'str', TRANSPORT: 'str', LAUNCH: 'str', ENV: 'arr', CONFIG: 'str',
  REPO: 'str', SOURCE: 'str', ABOUT: 'str', ABOUT_SOURCE: 'str', TOOLS: 'arr', TOOLS_ABOUT: 'arr', TOOLS_INPUTS: 'arr', RESOURCES: 'arr',
  RESOURCES_ABOUT: 'arr', TOOLS_NOTE: 'str', EXTERNAL: 'bool', AGENTS: 'arr', AGENTS_NOTE: 'str', WITNESS: 'str', ENABLED: 'bool',
}
const INT_MAX = { u8: 0xff, u16: 0xffff, u32: 0xffffffff }
export const CYRILLIC = /[\u0400-\u04ff]/

// Translation contracts (specs/i18n/agents-<locale>.t27).
const I18N_REQUIRED = {
  KIND: 'str', LOCALE: 'str', SOURCE_LOCALE: 'str', SCOPE: 'arr', FIELDS: 'arr', BUNDLE_REPO: 'str', BUNDLE_PATH: 'str',
  BUNDLE_FORMAT: 'str', KEY: 'str', FALLBACK: 'str', COVERAGE_REQUIRED: 'bool', ORPHANS_ALLOWED: 'bool', ENABLED: 'bool',
}
// Bundle field -> spec constant it translates. Tool specs have no SUMMARY_EN; for them
// SUMMARY translates ABOUT (see summarySourceOf), and NAME is not used.
export const I18N_FIELD_SOURCE = { SUMMARY: 'SUMMARY_EN', NAME: 'NAME' }
export const summarySourceOf = (fields) => (fields.KIND === 'tool' ? fields.ABOUT : fields.SUMMARY_EN)
export const LOCALE_RE = /^[a-z]{2,3}(-[A-Za-z0-9]{2,8})*$/

/**
 * Check one i18n spec + its bundle against the contract the spec declares.
 * `specsById` maps a spec ID to `{dir, fields}` for every skill and cron spec.
 * Returns `{entry, translations, problems}` where `translations` is
 * `Map<ID, {FIELD: text}>` (empty when disabled or broken) and `entry` is what
 * goes into the catalog's `i18n` list.
 */
export function checkI18n(spec, bundle, specsById) {
  const problems = []
  const file = spec.path
  const f = spec.fields
  if (!spec.verdict.typecheckOk || spec.verdict.discarded > 0 || !spec.verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(spec.verdict)})`)
  problems.push(...checkSchema(spec.consts, I18N_REQUIRED, {}, file))
  if (f.KIND !== 'i18n') problems.push(`${file}: KIND must be "i18n"`)
  if (typeof f.LOCALE === 'string' && !LOCALE_RE.test(f.LOCALE)) problems.push(`${file}: LOCALE ${JSON.stringify(f.LOCALE)} is not a BCP-47-shaped tag`)
  if (f.SOURCE_LOCALE !== 'en') problems.push(`${file}: SOURCE_LOCALE must be "en" (the specs are English-only)`)
  if (f.FALLBACK !== 'en') problems.push(`${file}: FALLBACK must be "en"`)
  if (f.KEY !== 'ID') problems.push(`${file}: KEY must be "ID" (bundles are keyed by the spec ID)`)
  if (f.BUNDLE_FORMAT !== 'json') problems.push(`${file}: BUNDLE_FORMAT ${JSON.stringify(f.BUNDLE_FORMAT)} is not supported (json)`)
  const expectModule = `i18n_${file.replace(/^specs\/i18n\//, '').replace(/\.t27$/, '').replace(/[^A-Za-z0-9]+/g, '_')}`
  if (spec.moduleName && spec.moduleName !== expectModule) problems.push(`${file}: module must be ${expectModule}, is ${spec.moduleName}`)
  const fields = Array.isArray(f.FIELDS) ? f.FIELDS : []
  for (const name of fields) if (!(name in I18N_FIELD_SOURCE)) problems.push(`${file}: FIELDS names ${JSON.stringify(name)}, which no spec constant backs (${Object.keys(I18N_FIELD_SOURCE).join(', ')})`)
  const scope = new Set(Array.isArray(f.SCOPE) ? f.SCOPE : [])
  const inScope = [...specsById.entries()].filter(([, v]) => scope.has(v.dir))
  const entry = {
    locale: f.LOCALE, spec: file, sha256: spec.sha256, bundle: f.BUNDLE_REPO === 'trinity' ? f.BUNDLE_PATH : `${f.BUNDLE_REPO}:${f.BUNDLE_PATH}`,
    enabled: f.ENABLED === true, fields, scope: [...scope], coverage: { n: 0, total: inScope.length }, missing: [],
  }
  const translations = new Map()
  if (f.ENABLED !== true) return { entry, translations, problems }
  if (f.BUNDLE_REPO !== 'trinity') { problems.push(`${file}: BUNDLE_REPO ${JSON.stringify(f.BUNDLE_REPO)} -- only a bundle in this repository can be loaded at build time`); return { entry, translations, problems } }
  if (!bundle) { problems.push(`${file}: bundle ${f.BUNDLE_PATH} is missing or not JSON`); return { entry, translations, problems } }
  if (bundle.$spec !== file) problems.push(`${f.BUNDLE_PATH}: $spec is ${JSON.stringify(bundle.$spec)}, the contract is ${file}`)
  if (bundle.locale !== f.LOCALE) problems.push(`${f.BUNDLE_PATH}: locale ${JSON.stringify(bundle.locale)} does not match the spec's LOCALE ${JSON.stringify(f.LOCALE)}`)
  const entries = bundle.entries && typeof bundle.entries === 'object' && !Array.isArray(bundle.entries) ? bundle.entries : null
  if (!entries) { problems.push(`${f.BUNDLE_PATH}: entries must be an object keyed by spec ID`); return { entry, translations, problems } }
  for (const [id, value] of Object.entries(entries)) {
    const target = specsById.get(id)
    if (!target || !scope.has(target.dir)) {
      if (f.ORPHANS_ALLOWED !== true) problems.push(`${f.BUNDLE_PATH}: entry ${JSON.stringify(id)} matches no spec in SCOPE (${[...scope].join(', ')}) and ORPHANS_ALLOWED is false`)
      continue
    }
    if (!value || typeof value !== 'object' || Array.isArray(value)) { problems.push(`${f.BUNDLE_PATH}: entry ${JSON.stringify(id)} must be an object of FIELDS`); continue }
    const clean = {}
    for (const [k, v] of Object.entries(value)) {
      if (!fields.includes(k)) { problems.push(`${f.BUNDLE_PATH}: entry ${JSON.stringify(id)} carries ${JSON.stringify(k)}, which is not in FIELDS (${fields.join(', ')})`); continue }
      if (typeof v !== 'string' || !v.trim()) { problems.push(`${f.BUNDLE_PATH}: entry ${JSON.stringify(id)}.${k} must be a non-empty string`); continue }
      clean[k] = v
    }
    if (Object.keys(clean).length) translations.set(id, clean)
  }
  for (const [id] of inScope) if (!translations.has(id)) entry.missing.push(id)
  entry.missing.sort()
  entry.coverage.n = inScope.length - entry.missing.length
  if (f.COVERAGE_REQUIRED === true && entry.missing.length) problems.push(`${file}: COVERAGE_REQUIRED and ${entry.missing.length} spec(s) have no ${f.LOCALE} entry in ${f.BUNDLE_PATH}: ${entry.missing.slice(0, 5).join(', ')}${entry.missing.length > 5 ? ', ...' : ''}`)
  return { entry, translations, problems }
}

/** `{en, <locale>...}` for one field of one spec from every loaded locale. */
export function localized(en, id, field, locales) {
  const out = { en }
  for (const { locale, translations } of locales) {
    const t = translations.get(id)?.[field]
    if (t) out[locale] = t
  }
  return out
}
export const HOSTS = ['github-actions', 'inngest', 'railway-cron', 'timer']
export const CONTROLS = ['github-actions-dispatch', 'railway-dashboard', 'inngest-dashboard', 'code-only']
export const ON_FAILURE = ['issue', 'log', 'unknown']

/** Inngest's own dashboard on Railway; the only outside handle an Inngest function has. */
export const INNGEST_DASHBOARD_URL = 'https://inngestinngest-production-6a21.up.railway.app'

/**
 * Where "run now" goes for a job, per host. Resolved at build time so the page
 * never has to know Railway's ids: they live in scripts/railway-services.json,
 * beside the service list the crons manifest is already built from. A timer
 * inside a process has no outside handle, and the strip says so.
 */
export function runNowTarget(fields, railway) {
  switch (fields.HOST) {
    case 'github-actions': {
      const file = fields.SERVICE.split('/').pop() ?? fields.SERVICE
      return { kind: 'link', via: 'github-actions', url: `https://github.com/gHashTag/${fields.REPO}/actions/workflows/${file}` }
    }
    case 'railway-cron': {
      const svc = (railway?.services ?? []).find((s) => s.name === fields.SERVICE)
      if (!railway?.projectId || !svc?.serviceId) return { kind: 'disabled', reason: 'unknown-service' }
      return { kind: 'link', via: 'railway', url: `https://railway.com/project/${railway.projectId}/service/${svc.serviceId}` }
    }
    case 'inngest':
      return { kind: 'link', via: 'inngest', url: INNGEST_DASHBOARD_URL }
    default:
      return { kind: 'disabled', reason: 'timer' }
  }
}

/** Annotation + value agree with the shape; null when they do, a reason when they do not. */
export function shapeProblem(decl, shape) {
  const { type, value } = decl
  switch (shape) {
    case 'str':
      if (type !== 'str') return `annotated ${type}, must be str`
      if (typeof value !== 'string') return 'value is not a string literal'
      return null
    case 'bool':
      if (type !== 'bool') return `annotated ${type}, must be bool`
      if (typeof value !== 'boolean') return 'value is not true/false'
      return null
    case 'u8':
    case 'u16':
    case 'u32':
      if (type !== shape) return `annotated ${type}, must be ${shape}`
      if (!Number.isInteger(value) || value < 0 || value > INT_MAX[shape]) return `value ${value} is not in ${shape} range`
      return null
    case 'arr': {
      if (!Array.isArray(value) || !value.every((x) => typeof x === 'string')) return 'value is not an array of strings'
      if (type !== `[${value.length}]str`) return `annotated ${type}, holds ${value.length} string(s)`
      return null
    }
    default:
      return `unknown shape ${shape}`
  }
}

export function checkSchema(consts, required, optional, file) {
  const problems = []
  for (const [name, shape] of Object.entries(required)) {
    if (!(name in consts)) { problems.push(`${file}: missing ${name}`); continue }
    const bad = shapeProblem(consts[name], shape)
    if (bad) problems.push(`${file}: ${name}: ${bad}`)
    if (!consts[name].pub) problems.push(`${file}: ${name} must be pub`)
  }
  for (const [name, shape] of Object.entries(optional)) {
    if (!(name in consts)) continue
    const bad = shapeProblem(consts[name], shape)
    if (bad) problems.push(`${file}: ${name}: ${bad}`)
    if (!consts[name].pub) problems.push(`${file}: ${name} must be pub`)
  }
  for (const name of Object.keys(consts)) {
    if (!(name in required) && !(name in optional)) problems.push(`${file}: unknown constant ${name}`)
  }
  return problems
}

const plain = (consts) => Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))

// ---------------------------------------------------------------------------
// Build. `files` = [{ path (corpus-relative), text }], `code` = the two manifests.
// ---------------------------------------------------------------------------
export function analyzeSpecFiles(analyze, files) {
  return files.map((f) => {
    const analysis = analyze(f.text)
    return { path: f.path, text: f.text, sha256: sha256(Buffer.from(f.text, 'utf8')), consts: constsOf(analysis), verdict: verdictOf(analysis), moduleName: analysis.ast?.name ?? null }
  })
}

export function buildSpecCatalogs({ skillSpecs, cronSpecs, agentSpecs = [], functionSpecs = [], toolSpecs = [], i18nSpecs = [], bundles = new Map(), experience = null, skillsManifest, cronsManifest, functionsManifest = null, t27Manifest, railway, compilerWasmSha256, generatedAt }) {
  const problems = []
  for (const s of [...skillSpecs, ...cronSpecs, ...agentSpecs, ...functionSpecs, ...toolSpecs, ...i18nSpecs]) {
    if (s.text !== undefined && CYRILLIC.test(s.text)) problems.push(`${s.path}: Cyrillic in a .t27 spec (t27 LANG-EN; translated text belongs in the bundle a specs/i18n/*.t27 contract points to)`)
  }
  const corpusPaths = new Set((t27Manifest?.specs ?? []).map((s) => s.path))
  const codeSkills = new Map((skillsManifest?.skills ?? []).map((s) => [s.id, s]))
  const codeCrons = new Map((cronsManifest?.crons ?? []).map((c) => [c.id, c]))

  const skills = []
  const seenSkill = new Map()
  for (const s of skillSpecs) {
    const file = s.path
    if (!s.verdict.typecheckOk || s.verdict.discarded > 0 || !s.verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(s.verdict)})`)
    problems.push(...checkSchema(s.consts, SKILL_REQUIRED, {}, file))
    const f = plain(s.consts)
    if (f.KIND !== 'skill') problems.push(`${file}: KIND must be "skill"`)
    if (typeof f.ID === 'string') {
      if (seenSkill.has(f.ID)) problems.push(`${file}: duplicate skill ID ${f.ID} (also ${seenSkill.get(f.ID)})`)
      seenSkill.set(f.ID, file)
    }
    const expectModule = `skill_${file.replace(/^specs\/skills\//, '').replace(/\.t27$/, '').replace(/[^A-Za-z0-9]+/g, '_')}`
    if (s.moduleName && s.moduleName !== expectModule) problems.push(`${file}: module must be ${expectModule}, is ${s.moduleName}`)
    const code = codeSkills.get(f.ID)
    const specsMissing = (Array.isArray(f.SPECS) ? f.SPECS : []).filter((p) => !corpusPaths.has(p))
    skills.push({
      id: f.ID,
      specPath: file,
      summary: { en: f.SUMMARY_EN },
      name: { en: f.NAME },
      sha256: s.sha256,
      typecheckOk: s.verdict.typecheckOk,
      discarded: s.verdict.discarded,
      moduleName: s.moduleName,
      inSpecCorpus: corpusPaths.has(file),
      fields: f,
      code: code ? { path: code.path, sha256: code.sha256, health: code.health, link: code.link } : null,
      witness: code ? 'spec+code' : 'spec-only',
      runBy: [],
      health: code ? (specsMissing.length ? 'warn' : 'ok') : 'warn',
      messages: [
        ...(code ? [] : [`no skill ${f.ID} in public/skills/manifest.json`]),
        ...specsMissing.map((p) => `SPECS names ${p}, which is not in the vendored corpus manifest`),
      ],
    })
  }

  const crons = []
  const seenCron = new Map()
  for (const c of cronSpecs) {
    const file = c.path
    if (!c.verdict.typecheckOk || c.verdict.discarded > 0 || !c.verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(c.verdict)})`)
    problems.push(...checkSchema(c.consts, CRON_REQUIRED, CRON_OPTIONAL, file))
    const f = plain(c.consts)
    if (f.KIND !== 'cron') problems.push(`${file}: KIND must be "cron"`)
    if (typeof f.ID === 'string') {
      if (seenCron.has(f.ID)) problems.push(`${file}: duplicate cron ID ${f.ID} (also ${seenCron.get(f.ID)})`)
      seenCron.set(f.ID, file)
    }
    const expectModule = `cron_${file.replace(/^specs\/crons\//, '').replace(/\.t27$/, '').replace(/[^A-Za-z0-9]+/g, '_')}`
    if (c.moduleName && c.moduleName !== expectModule) problems.push(`${file}: module must be ${expectModule}, is ${c.moduleName}`)
    if (f.HOST && !HOSTS.includes(f.HOST)) problems.push(`${file}: HOST ${f.HOST} is not one of ${HOSTS.join('|')}`)
    if (f.CONTROL && !CONTROLS.includes(f.CONTROL)) problems.push(`${file}: CONTROL ${f.CONTROL} is not one of ${CONTROLS.join('|')}`)
    if (f.ON_FAILURE && !ON_FAILURE.includes(f.ON_FAILURE)) problems.push(`${file}: ON_FAILURE ${f.ON_FAILURE} is not one of ${ON_FAILURE.join('|')}`)
    const isTimer = f.HOST === 'timer'
    if (isTimer && !('INTERVAL_MS' in f)) problems.push(`${file}: a timer needs INTERVAL_MS`)
    if (isTimer && 'SCHEDULE' in f) problems.push(`${file}: a timer has INTERVAL_MS, not SCHEDULE`)
    if (!isTimer && !('SCHEDULE' in f)) problems.push(`${file}: a scheduled job needs SCHEDULE`)
    if (!isTimer && 'INTERVAL_MS' in f) problems.push(`${file}: only a timer has INTERVAL_MS`)
    if (f.SCHEDULE === '' && !f.SCHEDULE_NOTE) problems.push(`${file}: an empty SCHEDULE needs SCHEDULE_NOTE`)
    const code = codeCrons.get(f.ID)
    const runs = Array.isArray(f.RUNS) ? f.RUNS : []
    const runsResolved = runs.map((id) => ({ id, ok: seenSkill.has(id) }))
    const unresolved = runsResolved.filter((r) => !r.ok)
    const messages = [
      ...(code ? [] : [`no job ${f.ID} in public/crons/manifest.json`]),
      ...unresolved.map((r) => `RUNS names ${r.id}, which has no skill spec`),
    ]
    let health = 'ok'
    if (!code) health = 'warn'
    if (unresolved.length) health = 'fail'
    // The code catalog knows the schedule it read from the file; when the spec
    // disagrees, that is a fact the reader must see, not a build failure.
    if (code) {
      const codeExpr = code.schedule?.expr ?? null
      const codeMs = code.schedule?.everyMs ?? null
      if (codeExpr && f.SCHEDULE !== undefined && f.SCHEDULE !== codeExpr) { messages.push(`SCHEDULE ${JSON.stringify(f.SCHEDULE)} differs from the code catalog (${codeExpr})`); if (health === 'ok') health = 'warn' }
      if (codeMs && f.INTERVAL_MS !== undefined && f.INTERVAL_MS !== codeMs) { messages.push(`INTERVAL_MS ${f.INTERVAL_MS} differs from the code catalog (${codeMs})`); if (health === 'ok') health = 'warn' }
      if (code.kind !== f.HOST) { messages.push(`HOST ${f.HOST} differs from the code catalog (${code.kind})`); if (health === 'ok') health = 'warn' }
    }
    crons.push({
      id: f.ID,
      specPath: file,
      summary: { en: f.SUMMARY_EN },
      name: { en: f.NAME },
      sha256: c.sha256,
      typecheckOk: c.verdict.typecheckOk,
      discarded: c.verdict.discarded,
      moduleName: c.moduleName,
      inSpecCorpus: corpusPaths.has(file),
      fields: f,
      code: code ? { where: code.where, sourceUrl: code.sourceUrl ?? null, health: code.health, kind: code.kind, repoPrivate: code.repoPrivate === true } : null,
      witness: code ? 'spec+code' : 'spec-only',
      runs,
      runsResolved,
      control: f.CONTROL,
      runNow: runNowTarget(f, railway),
      health,
      messages,
    })
  }

  // The reverse link, from the crons' RUNS.
  for (const cr of crons) for (const r of cr.runsResolved) {
    if (!r.ok) continue
    const sk = skills.find((s) => s.id === r.id)
    if (sk && !sk.runBy.includes(cr.id)) sk.runBy.push(cr.id)
  }
  for (const sk of skills) sk.runBy.sort()

  const byId = (a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0)
  skills.sort(byId)
  crons.sort(byId)
  const codeOnlySkills = [...codeSkills.keys()].filter((id) => !seenSkill.has(id)).sort()
  const codeOnlyCrons = [...codeCrons.keys()].filter((id) => !seenCron.has(id)).sort()

  // Layer 4: agents. Skills resolve against the skill specs (an unknown ID is a
  // build failure: the spec would claim a skill nobody wrote), crons are derived
  // from the crons' RUNS, experience is joined by LETTER from the snapshot, and
  // the SOUL / AGENTS.md / alphabet links are pinned to the t27 commit that
  // snapshot was read from. An agent's witness is `spec+experience` when at
  // least one episode names its letter, else `spec-only`; nothing is assumed.
  const pin = agentPin(experience)
  const agents = []
  const seenAgent = new Map()
  const seenOrdinal = new Map()
  for (const a of agentSpecs) {
    const file = a.path
    if (!a.verdict.typecheckOk || a.verdict.discarded > 0 || !a.verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(a.verdict)})`)
    problems.push(...checkSchema(a.consts, AGENT_REQUIRED, AGENT_OPTIONAL, file))
    const f = plain(a.consts)
    if (f.KIND !== 'agent') problems.push(`${file}: KIND must be "agent"`)
    if (typeof f.LETTER === 'string' && !/^([A-Z]|TI)$/.test(f.LETTER)) problems.push(`${file}: LETTER ${JSON.stringify(f.LETTER)} is not A-Z or TI`)
    if (typeof f.LETTER === 'string' && f.ID !== `t27/${f.LETTER}`) problems.push(`${file}: ID must be t27/${f.LETTER}, is ${JSON.stringify(f.ID)}`)
    if (typeof f.ID === 'string') {
      if (seenAgent.has(f.ID)) problems.push(`${file}: duplicate agent ID ${f.ID} (also ${seenAgent.get(f.ID)})`)
      seenAgent.set(f.ID, file)
    }
    if (Number.isInteger(f.ORDINAL)) {
      if (f.ORDINAL < 1 || f.ORDINAL > AGENT_COUNT) problems.push(`${file}: ORDINAL ${f.ORDINAL} is not 1..${AGENT_COUNT}`)
      if (seenOrdinal.has(f.ORDINAL)) problems.push(`${file}: duplicate ORDINAL ${f.ORDINAL} (also ${seenOrdinal.get(f.ORDINAL)})`)
      seenOrdinal.set(f.ORDINAL, file)
    }
    if (f.LAYER !== undefined && !AGENT_LAYERS.includes(f.LAYER)) problems.push(`${file}: LAYER ${JSON.stringify(f.LAYER)} is not one of ${AGENT_LAYERS.join('|')}`)
    const expectModule = `agent_${file.replace(/^specs\/agents\//, '').replace(/\.t27$/, '').replace(/[^A-Za-z0-9]+/g, '_')}`
    if (a.moduleName && a.moduleName !== expectModule) problems.push(`${file}: module must be ${expectModule}, is ${a.moduleName}`)
    if (typeof f.LETTER === 'string' && expectModule !== `agent_${f.LETTER.toLowerCase()}`) problems.push(`${file}: file name must be ${f.LETTER.toLowerCase()}.t27 for LETTER ${f.LETTER}`)
    const skillIds = Array.isArray(f.SKILLS) ? f.SKILLS : []
    for (const id of skillIds) if (!seenSkill.has(id)) problems.push(`${file}: SKILLS names ${id}, which has no skill spec`)
    if (skillIds.length === 0 && !(typeof f.SKILLS_NOTE === 'string' && f.SKILLS_NOTE.trim())) problems.push(`${file}: empty SKILLS needs a SKILLS_NOTE`)
    const toolIds = Array.isArray(f.TOOLS) ? f.TOOLS : []
    if ('TOOLS' in f && toolIds.length === 0 && !(typeof f.TOOLS_NOTE === 'string' && f.TOOLS_NOTE.trim())) problems.push(`${file}: empty TOOLS needs a TOOLS_NOTE`)
    const agentCrons = crons.filter((c) => c.runsResolved.some((r) => r.ok && skillIds.includes(r.id))).map((c) => c.id).sort()
    const ex = experience?.agents?.[f.LETTER] ?? null
    const exp = ex
      ? { episodes: ex.episodes, first: ex.first ?? null, last: ex.last ?? null, lastTask: ex.lastTask ?? null, outcomes: ex.outcomes ?? {}, lessons: ex.lessons ?? [], files: ex.files ?? [] }
      : { episodes: 0, first: null, last: null, lastTask: null, outcomes: {}, lessons: [], files: [] }
    agents.push({
      id: f.ID,
      letter: f.LETTER,
      ordinal: f.ORDINAL,
      specPath: file,
      summary: { en: f.SUMMARY_EN },
      name: { en: f.NAME },
      sha256: a.sha256,
      typecheckOk: a.verdict.typecheckOk,
      discarded: a.verdict.discarded,
      moduleName: a.moduleName,
      inSpecCorpus: corpusPaths.has(file),
      fields: f,
      skills: skillIds.map((id) => ({ id, ok: seenSkill.has(id) })),
      crons: agentCrons,
      tools: toolIds,
      experience: exp,
      links: {
        soul: `${T27_REPO_URL}/blob/${pin.ref}/${f.SOUL}`,
        agentsDoc: `${T27_REPO_URL}/blob/${pin.ref}/${f.AGENTS_DOC}`,
        alphabet: `${T27_REPO_URL}/blob/${pin.ref}/${f.ALPHABET}`,
        experienceLog: f.EXPERIENCE_LOG ? `${T27_REPO_URL}/tree/${pin.ref}/${f.EXPERIENCE_LOG.replace(/\/$/, '')}` : null,
        pinnedAt: pin.ref,
        pinSource: pin.source,
      },
      witness: exp.episodes > 0 ? 'spec+experience' : 'spec-only',
      health: skillIds.every((id) => seenSkill.has(id)) ? 'ok' : 'fail',
      messages: [
        ...(exp.episodes === 0 ? ['no attributed episodes in the experience snapshot'] : []),
        ...skillIds.filter((id) => !seenSkill.has(id)).map((id) => `SKILLS names ${id}, which has no skill spec`),
      ],
    })
  }
  agents.sort((x, y) => (x.ordinal ?? 0) - (y.ordinal ?? 0) || String(x.id).localeCompare(String(y.id)))
  if (agentSpecs.length && agents.length !== AGENT_COUNT) problems.push(`${AGENT_SPEC_DIR}: ${agents.length} agent spec(s), the alphabet has ${AGENT_COUNT}`)

  // Layer 5: functions. The witness is the vendored functions manifest, keyed
  // by the canonical id exactly as skills are keyed by theirs. A manifest field
  // the extractor left empty (file "", steps [], retries null) is "not read",
  // never "disagrees"; a filled field that differs from the spec is written on
  // the card. A cron function is joined to its cron card by REPO + LEGACY_ID =
  // the cron spec's NAME with HOST inngest -- an evidence join, not a name guess.
  const { functions, codeOnlyFunctions } = buildFunctions({ functionSpecs, functionsManifest, crons, corpusPaths, problems })
  // Tools, the layer after agents on this site's ladder (the t27 README of
  // specs/tools also calls itself "Layer 5", as does specs/functions -- a
  // source discrepancy recorded in the report, not resolved here). Two families read from two sub-directories, never merged
  // into one list: specs/tools/tri (the tri CLI, one file per clap variant) and
  // specs/tools/mcp (one file per MCP server). AGENTS on a tool and TOOLS on an
  // agent must agree in both directions and name only letters / IDs that exist;
  // a skill is cross-linked when its COMMAND names the tri command. The witness
  // is what the spec says it is (`source-parse` = read from the source, `help-output`
  // = diffed against `tri --help`); the generator does not upgrade it.
  const tools = []
  const seenTool = new Map()
  const seenLetter = new Map(agents.map((a) => [a.letter, a]))
  for (const t of toolSpecs) {
    const file = t.path
    const m = /^specs\/tools\/(tri|mcp)\/([^/]+)\.t27$/.exec(file)
    if (!m) { problems.push(`${file}: a tool spec must live in specs/tools/tri/ or specs/tools/mcp/`); continue }
    const [, sub, base] = m
    if (!t.verdict.typecheckOk || t.verdict.discarded > 0 || !t.verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(t.verdict)})`)
    problems.push(...checkSchema(t.consts, sub === 'tri' ? TOOL_TRI_REQUIRED : TOOL_MCP_REQUIRED, {}, file))
    const f = plain(t.consts)
    if (f.KIND !== 'tool') problems.push(`${file}: KIND must be "tool"`)
    if (f.FAMILY !== TOOL_FAMILIES[sub]) problems.push(`${file}: FAMILY must be ${JSON.stringify(TOOL_FAMILIES[sub])} under ${sub}/, is ${JSON.stringify(f.FAMILY)}`)
    const expectId = `${sub}/${base}`
    if (f.ID !== expectId) problems.push(`${file}: ID must be ${expectId}, is ${JSON.stringify(f.ID)}`)
    if (typeof f.ID === 'string') {
      if (seenTool.has(f.ID)) problems.push(`${file}: duplicate tool ID ${f.ID} (also ${seenTool.get(f.ID)})`)
      seenTool.set(f.ID, file)
    }
    const expectModule = `tool_${sub}_${base.replace(/[^A-Za-z0-9]+/g, '_')}`
    if (t.moduleName && t.moduleName !== expectModule) problems.push(`${file}: module must be ${expectModule}, is ${t.moduleName}`)
    if (!TOOL_WITNESSES.includes(f.WITNESS)) problems.push(`${file}: WITNESS ${JSON.stringify(f.WITNESS)} is not one of ${TOOL_WITNESSES.join('|')}`)
    if (typeof f.ABOUT === 'string' && !f.ABOUT.trim()) problems.push(`${file}: ABOUT is empty`)
    if (typeof f.ABOUT_SOURCE === 'string' && !f.ABOUT_SOURCE.trim()) problems.push(`${file}: ABOUT_SOURCE is empty`)
    const letters = Array.isArray(f.AGENTS) ? f.AGENTS : []
    for (const l of letters) if (!seenLetter.has(l)) problems.push(`${file}: AGENTS names ${JSON.stringify(l)}, which is not a letter of the alphabet`)
    if (letters.length === 0 && !(typeof f.AGENTS_NOTE === 'string' && f.AGENTS_NOTE.trim())) problems.push(`${file}: empty AGENTS needs an AGENTS_NOTE`)
    const same = (a, b, na, nb) => { if (Array.isArray(f[a]) && Array.isArray(f[b]) && f[a].length !== f[b].length) problems.push(`${file}: ${na} has ${f[a].length} entries, ${nb} has ${f[b].length}`) }
    let card
    if (sub === 'tri') {
      if (f.COMMAND !== `tri ${base}`) problems.push(`${file}: COMMAND must be "tri ${base}", is ${JSON.stringify(f.COMMAND)}`)
      same('ACTIONS', 'ACTIONS_ABOUT', 'ACTIONS', 'ACTIONS_ABOUT')
      const actions = (Array.isArray(f.ACTIONS) ? f.ACTIONS : []).map((name, i) => ({ name, about: f.ACTIONS_ABOUT?.[i] ?? '' }))
      const args = (Array.isArray(f.ARGS) ? f.ARGS : []).map((x) => { const k = x.indexOf(': '); return k === -1 ? { name: x, about: '' } : { name: x.slice(0, k), about: x.slice(k + 2) } })
      // Skills whose own spec names this tri command (COMMAND or SUMMARY_EN text -- the
      // skill's fields, not a guess); the matched field is recorded beside the skill ID.
      const cmdRe = new RegExp(`(^|[^A-Za-z0-9_-])tri\\s+${base.replace(/[-/\\\\^$*+?.()|[\]{}]/g, '\\$&')}(?![A-Za-z0-9_-])`)
      const skillIds = skills.flatMap((sk) => {
        const via = ['COMMAND', 'SUMMARY_EN'].filter((k) => typeof sk.fields[k] === 'string' && cmdRe.test(sk.fields[k]))
        return via.length ? [{ id: sk.id, via }] : []
      }).sort((x, y) => (x.id < y.id ? -1 : 1))
      card = { family: 'tri-cli', command: f.COMMAND, variant: f.VARIANT, actions, args, whenToUse: f.WHEN_TO_USE, skills: skillIds, aboutSource: f.ABOUT_SOURCE, repo: 'gHashTag/t27', source: f.SOURCE, entry: f.ENTRY }
    } else {
      same('TOOLS', 'TOOLS_ABOUT', 'TOOLS', 'TOOLS_ABOUT'); same('TOOLS', 'TOOLS_INPUTS', 'TOOLS', 'TOOLS_INPUTS'); same('RESOURCES', 'RESOURCES_ABOUT', 'RESOURCES', 'RESOURCES_ABOUT')
      if (!['stdio', 'http'].includes(f.TRANSPORT)) problems.push(`${file}: TRANSPORT ${JSON.stringify(f.TRANSPORT)} is not stdio|http`)
      if (!['gHashTag/t27', 'gHashTag/trinity'].includes(f.REPO)) problems.push(`${file}: REPO ${JSON.stringify(f.REPO)} is not gHashTag/t27|gHashTag/trinity`)
      const mcpTools = (Array.isArray(f.TOOLS) ? f.TOOLS : []).map((name, i) => ({ name, about: f.TOOLS_ABOUT?.[i] ?? '', inputs: (f.TOOLS_INPUTS?.[i] ?? '').split(',').filter(Boolean) }))
      if (mcpTools.length === 0 && !(typeof f.TOOLS_NOTE === 'string' && f.TOOLS_NOTE.trim())) problems.push(`${file}: empty TOOLS needs a TOOLS_NOTE`)
      if (mcpTools.length === 0 && f.EXTERNAL !== true) problems.push(`${file}: an in-repo server with no tools listed (set EXTERNAL or list its tools)`)
      const resources = (Array.isArray(f.RESOURCES) ? f.RESOURCES : []).map((path, i) => ({ path, about: f.RESOURCES_ABOUT?.[i] ?? '' }))
      card = { family: 'mcp', server: f.SERVER, serverVersion: f.SERVER_VERSION, transport: f.TRANSPORT, launch: f.LAUNCH, env: f.ENV ?? [], config: f.CONFIG, tools: mcpTools, resources, toolsNote: f.TOOLS_NOTE, external: f.EXTERNAL === true, skills: [], aboutSource: f.ABOUT_SOURCE, repo: f.REPO, source: f.SOURCE }
    }
    const repoUrl = card.repo === 'gHashTag/t27' ? T27_REPO_URL : 'https://github.com/gHashTag/trinity'
    const ref = card.repo === 'gHashTag/t27' ? pin.ref : (experience?.sources ?? []).find((x) => x.repo === 'trinity' && /^[0-9a-f]{40}$/.test(x.commit ?? ''))?.commit ?? 'main'
    tools.push({
      id: f.ID,
      specPath: file,
      summary: { en: f.ABOUT },
      name: { en: sub === 'tri' ? f.COMMAND : f.SERVER },
      sha256: t.sha256,
      typecheckOk: t.verdict.typecheckOk,
      discarded: t.verdict.discarded,
      moduleName: t.moduleName,
      inSpecCorpus: corpusPaths.has(file),
      fields: f,
      ...card,
      agents: letters.map((l) => ({ letter: l, ok: seenLetter.has(l) })),
      links: {
        source: `${repoUrl}/blob/${ref}/${card.source}`,
        config: card.config ? `${repoUrl}/blob/${ref}/${card.config}` : null,
        pinnedAt: ref,
      },
      witness: f.WITNESS,
      health: letters.every((l) => seenLetter.has(l)) ? 'ok' : 'fail',
      messages: [
        ...(letters.length === 0 ? ['no agent letter bound by a source'] : []),
        ...(sub === 'mcp' && card.external ? ['external package: tool list not in the repository'] : []),
      ],
    })
  }
  tools.sort(byId)
  // Both directions must agree: an agent's TOOLS name existing tools that name the agent back.
  for (const a of agents) {
    const ids = a.tools
    a.tools = ids.map((id) => ({ id, ok: seenTool.has(id) }))
    for (const id of ids) {
      if (!seenTool.has(id)) { problems.push(`${a.specPath}: TOOLS names ${id}, which has no tool spec`); continue }
      const tl = tools.find((x) => x.id === id)
      if (!tl.agents.some((x) => x.letter === a.letter)) problems.push(`${a.specPath}: TOOLS names ${id}, but ${tl.specPath} AGENTS does not name ${a.letter}`)
    }
  }
  for (const tl of tools) for (const { letter } of tl.agents) {
    const a = seenLetter.get(letter)
    if (a && !a.tools.some((x) => x.id === tl.id)) problems.push(`${tl.specPath}: AGENTS names ${letter}, but ${a.specPath} TOOLS does not name ${tl.id}`)
  }
  // Full-text index: one lowercase string per tool the explorer's search box filters on.
  for (const tl of tools) {
    const parts = [tl.id, tl.name.en, tl.summary.en, tl.whenToUse ?? '', ...(tl.actions ?? []).flatMap((x) => [x.name, x.about]), ...(tl.tools ?? []).flatMap((x) => [x.name, x.about]), ...tl.agents.map((x) => x.letter)]
    tl.searchText = parts.join(' ').toLowerCase().replace(/\s+/g, ' ').trim()
  }

  // Translations, connected through their contract specs. Every locale comes
  // from a specs/i18n/*.t27; nothing here knows which locales exist.
  const specsById = new Map()
  for (const s of skills) specsById.set(s.id, { dir: SKILL_SPEC_DIR, fields: s.fields })
  for (const c of crons) specsById.set(c.id, { dir: CRON_SPEC_DIR, fields: c.fields })
  for (const a of agents) specsById.set(a.id, { dir: AGENT_SPEC_DIR, fields: a.fields })
  for (const fn of functions) specsById.set(fn.id, { dir: FUNCTION_SPEC_DIR, fields: fn.fields })
  for (const tl of tools) specsById.set(tl.id, { dir: TOOL_SPEC_DIR, fields: tl.fields })
  const locales = []
  const seenLocale = new Map()
  // A translation contract belongs to this generator when its SCOPE names one of the
  // four catalog directories; contracts scoped elsewhere (specs/docs -> docs-from-specs.mjs)
  // are validated by their own generator and only Cyrillic-checked here.
  const ownI18n = i18nSpecs.filter((spec) => {
    const scope = plain(spec.consts).SCOPE
    return !Array.isArray(scope) || scope.some((d) => CATALOG_SPEC_DIRS.has(d))
  })
  for (const spec of [...ownI18n].sort((a, b) => a.path.localeCompare(b.path))) {
    const fields = plain(spec.consts)
    const r = checkI18n({ ...spec, fields }, bundles.get(fields.BUNDLE_PATH) ?? null, specsById)
    problems.push(...r.problems)
    if (typeof fields.LOCALE === 'string') {
      if (seenLocale.has(fields.LOCALE)) problems.push(`${spec.path}: duplicate LOCALE ${fields.LOCALE} (also ${seenLocale.get(fields.LOCALE)})`)
      seenLocale.set(fields.LOCALE, spec.path)
    }
    locales.push({ locale: fields.LOCALE, entry: r.entry, translations: r.translations, scope: new Set(r.entry.scope) })
  }
  const i18nFor = (dir, list) => [...locales].sort((a, b) => String(a.locale).localeCompare(String(b.locale))).filter((l) => l.scope.has(dir)).map((l) => {
    const ids = new Set(list.map((e) => e.id))
    const missing = l.entry.missing.filter((id) => ids.has(id))
    const { missing: _all, ...rest } = l.entry
    return { ...rest, coverage: { n: list.length - missing.length, total: list.length }, missing }
  })
  for (const e of [...skills, ...crons, ...agents, ...functions]) {
    e.summary = localized(e.fields.SUMMARY_EN, e.id, 'SUMMARY', locales)
    e.name = localized(e.fields.NAME, e.id, 'NAME', locales)
  }
  for (const tl of tools) tl.summary = localized(summarySourceOf(tl.fields), tl.id, 'SUMMARY', locales)
  const base = { version: VERSION, compilerWasmSha256 }
  const ladder = { specs: t27Manifest?.specCount ?? null, skills: skills.length, crons: crons.length, agents: agents.length, tools: tools.length, functions: functions.length }
  const skillsOut = sortKeys({
    ...base,
    generatedAt,
    counts: { specs: skills.length, specPlusCode: skills.filter((s) => s.witness === 'spec+code').length, specOnly: skills.filter((s) => s.witness === 'spec-only').length, codeOnly: codeOnlySkills.length, typecheckOk: skills.filter((s) => s.typecheckOk).length, runBy: skills.filter((s) => s.runBy.length).length },
    skills,
    codeOnly: codeOnlySkills,
    i18n: i18nFor(SKILL_SPEC_DIR, skills),
  })
  const cronsOut = sortKeys({
    ...base,
    generatedAt,
    counts: { specs: crons.length, specPlusCode: crons.filter((c) => c.witness === 'spec+code').length, specOnly: crons.filter((c) => c.witness === 'spec-only').length, codeOnly: codeOnlyCrons.length, typecheckOk: crons.filter((c) => c.typecheckOk).length, withRuns: crons.filter((c) => c.runs.length).length, byHost: Object.fromEntries(HOSTS.map((h) => [h, crons.filter((c) => c.fields.HOST === h).length])) },
    crons,
    codeOnly: codeOnlyCrons,
    i18n: i18nFor(CRON_SPEC_DIR, crons),
  })
  const agentsOut = sortKeys({
    ...base,
    generatedAt,
    counts: {
      specs: agents.length,
      enabled: agents.filter((a) => a.fields.ENABLED === true).length,
      typecheckOk: agents.filter((a) => a.typecheckOk).length,
      withSkills: agents.filter((a) => a.skills.length).length,
      withCrons: agents.filter((a) => a.crons.length).length,
      withTools: agents.filter((a) => a.tools.length).length,
      withExperience: agents.filter((a) => a.experience.episodes > 0).length,
      withClaraRole: agents.filter((a) => a.fields.CLARA_ROLE).length,
      specPlusExperience: agents.filter((a) => a.witness === 'spec+experience').length,
      specOnly: agents.filter((a) => a.witness === 'spec-only').length,
      byLayer: Object.fromEntries(AGENT_LAYERS.map((l) => [l, agents.filter((a) => a.fields.LAYER === l).length])),
      episodesAttributed: agents.reduce((n, a) => n + a.experience.episodes, 0),
      episodesUnattributed: experience?.unattributed?.episodes ?? null,
      episodesTotal: experience?.counts?.episodes ?? null,
    },
    // The ladder the explorers share: Specs -> Skills -> Crons -> Agents -> Tools -> Functions.
    // Every count is the length of a spec catalog built above (functions from specs/functions), never typed.
    ladder,
    pin,
    experienceSnapshot: experience ? { generatedAt: experience.generatedAt, sources: (experience.sources ?? []).map((x) => ({ repo: x.repo, commit: x.commit, files: x.files, episodes: x.episodes, unreadable: x.unreadable })), counts: experience.counts ?? null, attribution: experience.attribution ?? null } : null,
    agents,
    i18n: i18nFor(AGENT_SPEC_DIR, agents),
  })
  const triTools = tools.filter((x) => x.family === 'tri-cli'), mcpTools = tools.filter((x) => x.family === 'mcp')
  const toolsOut = sortKeys({
    ...base,
    generatedAt,
    counts: {
      specs: tools.length,
      tri: triTools.length,
      mcp: mcpTools.length,
      typecheckOk: tools.filter((x) => x.typecheckOk).length,
      enabled: tools.filter((x) => x.fields.ENABLED === true).length,
      withAgents: tools.filter((x) => x.agents.length).length,
      withSkills: tools.filter((x) => x.skills.length).length,
      triWithActions: triTools.filter((x) => x.actions.length).length,
      triActions: triTools.reduce((n, x) => n + x.actions.length, 0),
      mcpWithTools: mcpTools.filter((x) => x.tools.length).length,
      mcpTools: mcpTools.reduce((n, x) => n + x.tools.length, 0),
      mcpExternal: mcpTools.filter((x) => x.external).length,
      byWitness: Object.fromEntries(TOOL_WITNESSES.map((w) => [w, tools.filter((x) => x.witness === w).length])),
      byRepo: { 'gHashTag/t27': tools.filter((x) => x.repo === 'gHashTag/t27').length, 'gHashTag/trinity': tools.filter((x) => x.repo === 'gHashTag/trinity').length },
    },
    // Grouping the navigator shows: tri commands by owning letter (unbound under '-'), MCP servers by repo.
    groups: {
      triByAgent: Object.fromEntries([...new Set(triTools.flatMap((x) => (x.agents.length ? x.agents.map((a) => a.letter) : ['-'])))].sort().map((l) => [l, triTools.filter((x) => (l === '-' ? x.agents.length === 0 : x.agents.some((a) => a.letter === l))).map((x) => x.id)])),
      mcpByRepo: Object.fromEntries(['gHashTag/t27', 'gHashTag/trinity'].map((r) => [r, mcpTools.filter((x) => x.repo === r).map((x) => x.id)])),
    },
    ladder,
    pin,
    tools,
    i18n: i18nFor(TOOL_SPEC_DIR, tools),
  })
  // A hash of everything but the clock, so a checker can compare committed and
  // regenerated output without the timestamp getting in the way.
  const functionsOut = sortKeys({
    ...base,
    generatedAt,
    counts: {
      specs: functions.length,
      specPlusCode: functions.filter((f) => f.witness === 'spec+code').length,
      specOnly: functions.filter((f) => f.witness === 'spec-only').length,
      codeOnly: codeOnlyFunctions.length,
      typecheckOk: functions.filter((f) => f.typecheckOk).length,
      deployed: functions.filter((f) => f.code?.deployed === true).length,
      notDeployed: functions.filter((f) => f.code?.deployed === false).length,
      deployUnknown: functions.filter((f) => f.code == null || typeof f.code.deployed !== 'boolean').length,
      withCronSpec: functions.filter((f) => f.cronSpec).length,
      withDifferences: functions.filter((f) => f.differences.length).length,
      byTrigger: Object.fromEntries(FN_TRIGGERS.map((t) => [t, functions.filter((f) => f.fields.TRIGGER === t).length])),
      byDomain: Object.fromEntries([...new Set(functions.map((f) => f.fields.DOMAIN))].sort().map((d) => [d, functions.filter((f) => f.fields.DOMAIN === d).length])),
      bySideEffect: Object.fromEntries(FN_SIDE_EFFECTS.map((s) => [s, functions.filter((f) => (f.fields.SIDE_EFFECTS ?? []).includes(s)).length])),
      byProbeResult: Object.fromEntries(FN_PROBE_RESULTS.map((p) => [p, functions.filter((f) => f.fields.PROBE_RESULT === p).length])),
    },
    ladder,
    manifest: functionsManifest
      ? { repo: functionsManifest.repo ?? null, generatedFrom: functionsManifest.generatedFrom ?? null, probedAt: functionsManifest.probedAt ?? null, deployedApp: functionsManifest.deployedApp ?? null, entries: (functionsManifest.functions ?? []).length }
      : null,
    functions,
    codeOnly: codeOnlyFunctions,
    i18n: i18nFor(FUNCTION_SPEC_DIR, functions),
  })
  // A hash of everything but the clock, so a checker can compare committed and
  // regenerated output without the timestamp getting in the way.
  skillsOut.contentSha256 = sha256(JSON.stringify({ ...skillsOut, generatedAt: null }))
  cronsOut.contentSha256 = sha256(JSON.stringify({ ...cronsOut, generatedAt: null }))
  agentsOut.contentSha256 = sha256(JSON.stringify({ ...agentsOut, generatedAt: null }))
  functionsOut.contentSha256 = sha256(JSON.stringify({ ...functionsOut, generatedAt: null }))
  toolsOut.contentSha256 = sha256(JSON.stringify({ ...toolsOut, generatedAt: null }))
  return { skills: sortKeys(skillsOut), crons: sortKeys(cronsOut), agents: sortKeys(agentsOut), functions: sortKeys(functionsOut), tools: sortKeys(toolsOut), problems }
}

/** The fields of a manifest entry the spec repeats, and how each is compared. */
const sameList = (a, b) => Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => x === b[i])
const sameSet = (a, b) => Array.isArray(a) && Array.isArray(b) && a.length === b.length && [...a].sort().every((x, i) => x === [...b].sort()[i])

/**
 * Compare one function spec with its manifest entry. Returns the list of
 * differences as `{field, spec, code}`; a manifest field the extractor left
 * empty ("" / [] / null) is "not read" and produces no difference.
 */
export function functionDifferences(fields, code) {
  if (!code) return []
  const out = []
  const push = (field, spec, value) => out.push({ field, spec, code: value })
  if (code.trigger && fields.TRIGGER !== code.trigger) push('TRIGGER', fields.TRIGGER, code.trigger)
  if (code.event && fields.EVENT !== code.event) push('EVENT', fields.EVENT, code.event)
  if (Array.isArray(code.legacy_events) && code.legacy_events.length && !sameList(fields.LEGACY_EVENTS, code.legacy_events)) push('LEGACY_EVENTS', fields.LEGACY_EVENTS, code.legacy_events)
  if (code.cron && fields.CRON !== code.cron) push('CRON', fields.CRON, code.cron)
  if (code.tz && fields.TZ !== code.tz) push('TZ', fields.TZ, code.tz)
  if (code.legacy_id && fields.LEGACY_ID !== code.legacy_id) push('LEGACY_ID', fields.LEGACY_ID, code.legacy_id)
  if (code.domain && fields.DOMAIN !== code.domain) push('DOMAIN', fields.DOMAIN, code.domain)
  if (Number.isInteger(code.retries) && fields.RETRIES !== code.retries) push('RETRIES', fields.RETRIES, code.retries)
  if (code.on_failure && fields.ON_FAILURE !== code.on_failure) push('ON_FAILURE', fields.ON_FAILURE, code.on_failure)
  if (Array.isArray(code.steps) && code.steps.length && !sameList(fields.STEPS, code.steps)) push('STEPS', fields.STEPS, code.steps)
  if (Array.isArray(code.side_effects) && code.side_effects.length && !sameSet(fields.SIDE_EFFECTS, code.side_effects)) push('SIDE_EFFECTS', fields.SIDE_EFFECTS, code.side_effects)
  if (code.guard && fields.GUARD !== code.guard) push('GUARD', fields.GUARD, code.guard)
  if (code.probe_result && fields.PROBE_RESULT !== code.probe_result) push('PROBE_RESULT', fields.PROBE_RESULT, code.probe_result)
  if (code.control && fields.CONTROL !== code.control) push('CONTROL', fields.CONTROL, code.control)
  if (code.file && typeof fields.SERVICE === 'string' && fields.SERVICE.split(':')[0] !== code.file) push('SERVICE', fields.SERVICE, code.file)
  return out
}

function buildFunctions({ functionSpecs, functionsManifest, crons, corpusPaths, problems }) {
  const codeFns = new Map((functionsManifest?.functions ?? []).filter((f) => f && typeof f.id === 'string').map((f) => [f.id, f]))
  const functions = []
  const seen = new Map()
  for (const s of functionSpecs) {
    const file = s.path
    if (!s.verdict.typecheckOk || s.verdict.discarded > 0 || !s.verdict.hirOk) problems.push(`${file}: compiler verdict not clean (${JSON.stringify(s.verdict)})`)
    problems.push(...checkSchema(s.consts, FUNCTION_REQUIRED, {}, file))
    const f = plain(s.consts)
    if (f.KIND !== 'function') problems.push(`${file}: KIND must be "function"`)
    const slug = file.replace(/^specs\/functions\//, '').replace(/\.t27$/, '')
    if (typeof f.ID === 'string') {
      if (seen.has(f.ID)) problems.push(`${file}: duplicate function ID ${f.ID} (also ${seen.get(f.ID)})`)
      seen.set(f.ID, file)
      if (f.ID !== slug) problems.push(`${file}: ID must equal the file name (${slug}), is ${JSON.stringify(f.ID)}`)
    }
    const expectModule = `fn_${slug.replace(/[^A-Za-z0-9]+/g, '_')}`
    if (s.moduleName && s.moduleName !== expectModule) problems.push(`${file}: module must be ${expectModule}, is ${s.moduleName}`)
    if (f.TRIGGER !== undefined && !FN_TRIGGERS.includes(f.TRIGGER)) problems.push(`${file}: TRIGGER ${JSON.stringify(f.TRIGGER)} is not one of ${FN_TRIGGERS.join('|')}`)
    if (f.ON_FAILURE !== undefined && !FN_ON_FAILURE.includes(f.ON_FAILURE)) problems.push(`${file}: ON_FAILURE ${JSON.stringify(f.ON_FAILURE)} is not one of ${FN_ON_FAILURE.join('|')}`)
    if (f.PROBE_RESULT !== undefined && !FN_PROBE_RESULTS.includes(f.PROBE_RESULT)) problems.push(`${file}: PROBE_RESULT ${JSON.stringify(f.PROBE_RESULT)} is not one of ${FN_PROBE_RESULTS.join('|')}`)
    if (f.CONTROL !== undefined && !FN_CONTROLS.includes(f.CONTROL)) problems.push(`${file}: CONTROL ${JSON.stringify(f.CONTROL)} is not one of ${FN_CONTROLS.join('|')}`)
    for (const se of Array.isArray(f.SIDE_EFFECTS) ? f.SIDE_EFFECTS : []) if (!FN_SIDE_EFFECTS.includes(se)) problems.push(`${file}: SIDE_EFFECTS names ${JSON.stringify(se)}, not one of ${FN_SIDE_EFFECTS.join('|')}`)
    if (Array.isArray(f.SIDE_EFFECTS) && f.SIDE_EFFECTS.length === 0) problems.push(`${file}: SIDE_EFFECTS must name at least one value ("none" when a run touches nothing outside)`)
    if (f.TRIGGER === 'event') {
      if (f.EVENT === '') problems.push(`${file}: an event function needs EVENT`)
      if (f.CRON !== undefined && f.CRON !== '') problems.push(`${file}: an event function has EVENT, not CRON`)
    }
    if (f.TRIGGER === 'cron') {
      if (f.CRON === '') problems.push(`${file}: a cron function needs CRON`)
      if (f.EVENT !== undefined && f.EVENT !== '') problems.push(`${file}: a cron function has CRON, not EVENT`)
      if (Array.isArray(f.LEGACY_EVENTS) && f.LEGACY_EVENTS.length) problems.push(`${file}: a cron function has no LEGACY_EVENTS`)
    }
    if (typeof f.SAFE_PROBE === 'string' && f.SAFE_PROBE !== '') {
      try { JSON.parse(f.SAFE_PROBE) } catch { problems.push(`${file}: SAFE_PROBE is neither "" nor JSON`) }
    }
    const code = codeFns.get(f.ID) ?? null
    const differences = functionDifferences(f, code)
    // The cron card for the same schedule, when specs/crons states one.
    const cronSpec = f.TRIGGER === 'cron'
      ? (crons.find((c) => c.fields.HOST === 'inngest' && c.fields.REPO === f.REPO && c.fields.NAME === f.LEGACY_ID)?.id ?? null)
      : null
    const messages = [
      ...(code ? [] : [`no function ${f.ID} in ${FUNCTIONS_MANIFEST}`]),
      ...differences.map((d) => `${d.field} ${JSON.stringify(d.spec)} differs from the manifest (${JSON.stringify(d.code)})`),
      ...(code && code.deployed_2026_09_09 === false ? [`not on the production build probed ${functionsManifest?.probedAt ?? '2026-09-09'} (deployed_2026_09_09 false)`] : []),
      ...(f.TRIGGER === 'cron' && !cronSpec ? ['no cron card in specs/crons states this schedule'] : []),
    ]
    let health = 'ok'
    if (!code || differences.length) health = 'warn'
    functions.push({
      id: f.ID,
      specPath: file,
      summary: { en: f.SUMMARY_EN },
      name: { en: f.NAME },
      sha256: s.sha256,
      typecheckOk: s.verdict.typecheckOk,
      discarded: s.verdict.discarded,
      moduleName: s.moduleName,
      inSpecCorpus: corpusPaths.has(file),
      fields: f,
      code: code
        ? { legacyId: code.legacy_id ?? null, file: code.file || null, deployed: typeof code.deployed_2026_09_09 === 'boolean' ? code.deployed_2026_09_09 : null, probeResult: code.probe_result ?? null, retries: Number.isInteger(code.retries) ? code.retries : null, steps: Array.isArray(code.steps) ? code.steps.length : null, control: code.control ?? null }
        : null,
      witness: code ? 'spec+code' : 'spec-only',
      differences,
      cronSpec,
      health,
      messages,
    })
  }
  functions.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
  const codeOnlyFunctions = [...codeFns.keys()].filter((id) => !seen.has(id)).sort()
  return { functions, codeOnlyFunctions }
}

/**
 * The t27 ref the agents' SOUL / AGENTS.md / alphabet links point at: the commit
 * the experience snapshot was read from (its `sources` carry `repo: 't27'`), or
 * the default branch when no snapshot pins one. The source is recorded so the
 * page can say which it is.
 */
export function agentPin(experience) {
  const t27 = (experience?.sources ?? []).find((x) => x.repo === 't27' && /^[0-9a-f]{40}$/.test(x.commit ?? ''))
  if (t27) return { ref: t27.commit, source: `${EXPERIENCE_PATH} sources[t27].commit` }
  return { ref: 'master', source: 'default branch (no t27 commit in the experience snapshot)' }
}

export function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys)
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((k) => [k, sortKeys(value[k])]))
  }
  return value
}

// ---------------------------------------------------------------------------
// The site.
// ---------------------------------------------------------------------------
function readSpecDir(dir) {
  const abs = join(SITE, CORPUS, dir)
  if (!existsSync(abs)) return []
  return readdirSync(abs)
    .filter((f) => f.endsWith('.t27'))
    .sort()
    .map((f) => ({ path: `${dir}/${f}`, text: readFileSync(join(abs, f), 'utf8') }))
}

function readToolSpecs() {
  return TOOL_SPEC_SUBDIRS.flatMap((sub) => readSpecDir(`${TOOL_SPEC_DIR}/${sub}`))
}

const readJson = (rel) => (existsSync(join(SITE, rel)) ? JSON.parse(readFileSync(join(SITE, rel), 'utf8')) : null)

export async function generate({ generatedAt } = {}) {
  const wasmBytes = readFileSync(join(SITE, WASM))
  const analyze = await loadCompiler(wasmBytes)
  const skillSpecs = analyzeSpecFiles(analyze, readSpecDir(SKILL_SPEC_DIR))
  const cronSpecs = analyzeSpecFiles(analyze, readSpecDir(CRON_SPEC_DIR))
  const agentSpecs = analyzeSpecFiles(analyze, readSpecDir(AGENT_SPEC_DIR))
  const functionSpecs = analyzeSpecFiles(analyze, readSpecDir(FUNCTION_SPEC_DIR))
  const toolSpecs = analyzeSpecFiles(analyze, readToolSpecs())
  const i18nSpecs = analyzeSpecFiles(analyze, readSpecDir(I18N_SPEC_DIR))
  // Each contract names its bundle; load exactly those, repo-relative.
  const bundles = new Map()
  for (const s of i18nSpecs) {
    const path = plain(s.consts).BUNDLE_PATH
    if (typeof path !== 'string' || path.includes('..')) continue
    const abs = join(REPO_ROOT, path)
    if (existsSync(abs)) { try { bundles.set(path, JSON.parse(readFileSync(abs, 'utf8'))) } catch { bundles.set(path, null) } }
  }
  const epoch = process.env.SOURCE_DATE_EPOCH
  const stamp = generatedAt ?? (epoch ? new Date(Number(epoch) * 1000).toISOString() : new Date().toISOString())
  return buildSpecCatalogs({
    skillSpecs,
    cronSpecs,
    agentSpecs,
    functionSpecs,
    toolSpecs,
    experience: readJson(EXPERIENCE_PATH),
    skillsManifest: readJson('public/skills/manifest.json'),
    cronsManifest: readJson('public/crons/manifest.json'),
    functionsManifest: readJson(FUNCTIONS_MANIFEST),
    t27Manifest: readJson('public/t27/manifest.json'),
    railway: readJson('scripts/railway-services.json'),
    i18nSpecs,
    bundles,
    compilerWasmSha256: sha256(wasmBytes),
    generatedAt: stamp,
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
  const { skills, crons, agents, functions, tools, problems } = await generate()
  if (problems.length) {
    console.error(`agents-from-specs: ${problems.length} problem(s)`)
    for (const p of problems) console.error('  ' + p)
    process.exit(1)
  }
  if (check) {
    const prior = { skills: readJson(SKILLS_OUT), crons: readJson(CRONS_OUT), agents: readJson(AGENTS_OUT), functions: readJson(FUNCTIONS_OUT), tools: readJson(TOOLS_OUT) }
    const drift = []
    if (prior.skills?.contentSha256 !== skills.contentSha256) drift.push(SKILLS_OUT)
    if (prior.crons?.contentSha256 !== crons.contentSha256) drift.push(CRONS_OUT)
    if (prior.agents?.contentSha256 !== agents.contentSha256) drift.push(AGENTS_OUT)
    if (prior.functions?.contentSha256 !== functions.contentSha256) drift.push(FUNCTIONS_OUT)
    if (prior.tools?.contentSha256 !== tools.contentSha256) drift.push(TOOLS_OUT)
    if (drift.length) {
      console.error(`agents-from-specs: committed output is stale: ${drift.join(', ')} -- run node scripts/agents-from-specs.mjs`)
      process.exit(1)
    }
    console.log(`agents-from-specs: ${SKILLS_OUT}, ${CRONS_OUT}, ${AGENTS_OUT} ${FUNCTIONS_OUT} and ${TOOLS_OUT} match the specs`)
    return
  }
  writeAtomic(SKILLS_OUT, skills)
  writeAtomic(CRONS_OUT, crons)
  writeAtomic(AGENTS_OUT, agents)
  writeAtomic(FUNCTIONS_OUT, functions)
  writeAtomic(TOOLS_OUT, tools)
  const s = skills.counts, c = crons.counts, a = agents.counts, fn = functions.counts, t = tools.counts
  console.log(`agents-from-specs: skills ${s.specs} specs (typecheck ok ${s.typecheckOk}/${s.specs}; spec+code ${s.specPlusCode}, spec-only ${s.specOnly}, code-only ${s.codeOnly}) -> ${SKILLS_OUT}`)
  console.log(`agents-from-specs: crons  ${c.specs} specs (typecheck ok ${c.typecheckOk}/${c.specs}; spec+code ${c.specPlusCode}, spec-only ${c.specOnly}, code-only ${c.codeOnly}; with RUNS ${c.withRuns}) -> ${CRONS_OUT}`)
  console.log(`agents-from-specs: agents ${a.specs} specs (typecheck ok ${a.typecheckOk}/${a.specs}; enabled ${a.enabled}; with skills ${a.withSkills}, with crons ${a.withCrons}, with tools ${a.withTools}; spec+experience ${a.specPlusExperience}, spec-only ${a.specOnly}; episodes attributed ${a.episodesAttributed}, unattributed ${a.episodesUnattributed ?? 'n/a'}; links pinned at ${agents.pin.ref.slice(0, 7)}) -> ${AGENTS_OUT}`)
  console.log(`agents-from-specs: functions ${fn.specs} specs (typecheck ok ${fn.typecheckOk}/${fn.specs}; spec+code ${fn.specPlusCode}, spec-only ${fn.specOnly}, code-only ${fn.codeOnly}; deployed ${fn.deployed}, not deployed ${fn.notDeployed}, unknown ${fn.deployUnknown}; with differences from the manifest ${fn.withDifferences}; cron cards joined ${fn.withCronSpec}/${fn.byTrigger.cron}) -> ${FUNCTIONS_OUT}`)
  console.log(`agents-from-specs: tools  ${t.specs} specs (tri ${t.tri} commands, ${t.triActions} actions; mcp ${t.mcp} servers, ${t.mcpTools} tools, ${t.mcpExternal} external; typecheck ok ${t.typecheckOk}/${t.specs}; with agents ${t.withAgents}, with skills ${t.withSkills}; witness ${Object.entries(t.byWitness).map(([k, v]) => `${k} ${v}`).join(', ')}) -> ${TOOLS_OUT}`)
  for (const l of skills.i18n) console.log(`agents-from-specs: i18n ${l.locale} via ${l.spec} -> ${l.bundle}: skills ${l.coverage.n}/${l.coverage.total}, crons ${crons.i18n.find((x) => x.locale === l.locale)?.coverage.n ?? 0}/${crons.counts.specs}, agents ${agents.i18n.find((x) => x.locale === l.locale)?.coverage.n ?? 0}/${agents.counts.specs}, functions ${functions.i18n.find((x) => x.locale === l.locale)?.coverage.n ?? 0}/${functions.counts.specs}, tools ${tools.i18n.find((x) => x.locale === l.locale)?.coverage.n ?? 0}/${tools.counts.specs}${l.enabled ? '' : ' (disabled)'}`)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch((e) => { console.error(e); process.exit(1) })
}
