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
// Outputs: public/skills/spec-skills.json, public/crons/spec-crons.json.
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
  KIND: 'str', ID: 'str', NAME: 'str', REPO: 'str', SOURCE: 'str', SUMMARY_EN: 'str', SUMMARY_RU: 'str',
  COMMAND: 'str', SPECS: 'arr', TAGS: 'arr', ENABLED: 'bool', TIMEOUT_MIN: 'u16',
}
const CRON_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', HOST: 'str', REPO: 'str', SERVICE: 'str', SUMMARY_EN: 'str', SUMMARY_RU: 'str',
  TZ: 'str', RUNS: 'arr', RUNS_NOTE: 'str', ENABLED: 'bool', ON_FAILURE: 'str', CONTROL: 'str',
}
const CRON_OPTIONAL = { SCHEDULE: 'str', SCHEDULE_NOTE: 'str', INTERVAL_MS: 'u32', NOTE: 'str' }
const INT_MAX = { u16: 0xffff, u32: 0xffffffff }
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
    return { path: f.path, sha256: sha256(Buffer.from(f.text, 'utf8')), consts: constsOf(analysis), verdict: verdictOf(analysis), moduleName: analysis.ast?.name ?? null }
  })
}

export function buildSpecCatalogs({ skillSpecs, cronSpecs, skillsManifest, cronsManifest, t27Manifest, railway, compilerWasmSha256, generatedAt }) {
  const problems = []
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

  const base = { version: VERSION, compilerWasmSha256 }
  const skillsOut = sortKeys({
    ...base,
    generatedAt,
    counts: { specs: skills.length, specPlusCode: skills.filter((s) => s.witness === 'spec+code').length, specOnly: skills.filter((s) => s.witness === 'spec-only').length, codeOnly: codeOnlySkills.length, typecheckOk: skills.filter((s) => s.typecheckOk).length, runBy: skills.filter((s) => s.runBy.length).length },
    skills,
    codeOnly: codeOnlySkills,
  })
  const cronsOut = sortKeys({
    ...base,
    generatedAt,
    counts: { specs: crons.length, specPlusCode: crons.filter((c) => c.witness === 'spec+code').length, specOnly: crons.filter((c) => c.witness === 'spec-only').length, codeOnly: codeOnlyCrons.length, typecheckOk: crons.filter((c) => c.typecheckOk).length, withRuns: crons.filter((c) => c.runs.length).length, byHost: Object.fromEntries(HOSTS.map((h) => [h, crons.filter((c) => c.fields.HOST === h).length])) },
    crons,
    codeOnly: codeOnlyCrons,
  })
  // A hash of everything but the clock, so a checker can compare committed and
  // regenerated output without the timestamp getting in the way.
  skillsOut.contentSha256 = sha256(JSON.stringify({ ...skillsOut, generatedAt: null }))
  cronsOut.contentSha256 = sha256(JSON.stringify({ ...cronsOut, generatedAt: null }))
  return { skills: sortKeys(skillsOut), crons: sortKeys(cronsOut), problems }
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

const readJson = (rel) => (existsSync(join(SITE, rel)) ? JSON.parse(readFileSync(join(SITE, rel), 'utf8')) : null)

export async function generate({ generatedAt } = {}) {
  const wasmBytes = readFileSync(join(SITE, WASM))
  const analyze = await loadCompiler(wasmBytes)
  const skillSpecs = analyzeSpecFiles(analyze, readSpecDir(SKILL_SPEC_DIR))
  const cronSpecs = analyzeSpecFiles(analyze, readSpecDir(CRON_SPEC_DIR))
  const epoch = process.env.SOURCE_DATE_EPOCH
  const stamp = generatedAt ?? (epoch ? new Date(Number(epoch) * 1000).toISOString() : new Date().toISOString())
  return buildSpecCatalogs({
    skillSpecs,
    cronSpecs,
    skillsManifest: readJson('public/skills/manifest.json'),
    cronsManifest: readJson('public/crons/manifest.json'),
    t27Manifest: readJson('public/t27/manifest.json'),
    railway: readJson('scripts/railway-services.json'),
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
  const { skills, crons, problems } = await generate()
  if (problems.length) {
    console.error(`agents-from-specs: ${problems.length} problem(s)`)
    for (const p of problems) console.error('  ' + p)
    process.exit(1)
  }
  if (check) {
    const prior = { skills: readJson(SKILLS_OUT), crons: readJson(CRONS_OUT) }
    const drift = []
    if (prior.skills?.contentSha256 !== skills.contentSha256) drift.push(SKILLS_OUT)
    if (prior.crons?.contentSha256 !== crons.contentSha256) drift.push(CRONS_OUT)
    if (drift.length) {
      console.error(`agents-from-specs: committed output is stale: ${drift.join(', ')} -- run node scripts/agents-from-specs.mjs`)
      process.exit(1)
    }
    console.log(`agents-from-specs: ${SKILLS_OUT} and ${CRONS_OUT} match the specs`)
    return
  }
  writeAtomic(SKILLS_OUT, skills)
  writeAtomic(CRONS_OUT, crons)
  const s = skills.counts, c = crons.counts
  console.log(`agents-from-specs: skills ${s.specs} specs (typecheck ok ${s.typecheckOk}/${s.specs}; spec+code ${s.specPlusCode}, spec-only ${s.specOnly}, code-only ${s.codeOnly}) -> ${SKILLS_OUT}`)
  console.log(`agents-from-specs: crons  ${c.specs} specs (typecheck ok ${c.typecheckOk}/${c.specs}; spec+code ${c.specPlusCode}, spec-only ${c.specOnly}, code-only ${c.codeOnly}; with RUNS ${c.withRuns}) -> ${CRONS_OUT}`)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch((e) => { console.error(e); process.exit(1) })
}
