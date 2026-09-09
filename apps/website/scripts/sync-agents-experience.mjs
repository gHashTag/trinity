#!/usr/bin/env node
// sync-agents-experience.mjs -- the agents' experience, joined to the alphabet by evidence.
//
// Reads every episode under `.trinity/experience/**` of two checkouts -- this repo
// (gHashTag/trinity, the repo root above apps/website) and gHashTag/t27 (T27_ROOT,
// default /home/user/workspace/t27 on the build box; the owner's checkout is
// /Users/playom/t27) -- and writes public/agents/experience.json: per agent letter the
// episode count, first/last timestamps, outcome mix, lessons, and the files plus commit
// shas the numbers came from. An episode that names no agent letter is counted under
// `unattributed` and never assigned to anyone.
//
// ATTRIBUTION RULE (also in public/t27/files/specs/agents/README.md; keep the two in step)
//   1. An episode is one JSON object: a `*.json` file holding an object, each object of a
//      `*.json` array, or each line of a `*.jsonl` file. `*.md` files are listed as notes,
//      not counted as episodes. Files that do not parse are counted as `unreadable`.
//   2. The agent is read from the first of these fields that is present:
//      agent_letter, letter, agent, agent_id, agents (array: every member), owner.
//   3. A value attributes to a letter when, case-insensitively, it is one letter A-Z; or
//      "ti" / "27th" (the 27th letter, ID t27/TI); or "t27/<letter>"; or it starts with
//      "agent-<letter>" / "agent_<letter>" / "agent <letter>" followed by a non-letter
//      (so `agent-e-experience` -> E, `Agent V - Verification` -> V). Anything else --
//      a model name such as `claude-opus-4.6`, a person, a repo -- is NOT a letter: the
//      episode goes to `unattributed` and the raw value is tallied in
//      `unattributed.agentValues` so the gap is visible instead of guessed away.
//   4. Timestamp: `timestamp` (unix seconds, unix milliseconds, or ISO-8601) else `date`.
//      Outcome: `verdict`, else `status`, else `outcome`, else `success` (true -> PASS,
//      false -> FAIL); upper-cased; missing -> "UNKNOWN".
//      Lessons: strings of `learnings`, `lessons`, `lessons_learned`, then `mistakes`
//      prefixed "mistake: "; each trimmed to 160 characters; at most 12 per agent,
//      most recent first.
//   5. Output is sorted (letters, files, outcome keys) so two runs over the same trees
//      differ only in `generatedAt` (SOURCE_DATE_EPOCH pins it).
//
// Usage: node scripts/sync-agents-experience.mjs [--check]
//   --check  validates the committed experience.json against this schema and prints the
//            counts; it does not require either checkout and does not rewrite the file.
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'

export const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
export const REPO_ROOT = resolve(SITE, '..', '..')
export const OUT = 'public/agents/experience.json'
export const EXPERIENCE_DIR = '.trinity/experience'
export const T27_ROOT_DEFAULT = '/home/user/workspace/t27'
export const OWNER_T27_ROOT = '/Users/playom/t27'
export const VERSION = 1
export const LETTERS = [...'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TI']
export const AGENT_FIELDS = ['agent_letter', 'letter', 'agent', 'agent_id', 'agents', 'owner']
export const MAX_LESSONS = 12
export const LESSON_CHARS = 160

/** The letter a raw agent value attributes to, or null. */
export function letterOf(value) {
  if (typeof value !== 'string') return null
  const v = value.trim().toLowerCase()
  if (/^[a-z]$/.test(v)) return v.toUpperCase()
  if (v === 'ti' || v === '27th') return 'TI'
  let m = /^t27\/([a-z]|ti)$/.exec(v)
  if (m) return m[1].toUpperCase()
  m = /^agent[-_ ]([a-z]|ti)(?:[^a-z]|$)/.exec(v)
  if (m) return m[1].toUpperCase()
  return null
}

/** The raw agent values an episode carries, in field order. */
export function agentValuesOf(ep) {
  for (const f of AGENT_FIELDS) {
    if (!(f in ep)) continue
    const v = ep[f]
    if (Array.isArray(v)) return v.filter((x) => typeof x === 'string')
    if (typeof v === 'string') return [v]
  }
  return []
}

export function timestampOf(ep) {
  const raw = ep.timestamp ?? ep.date ?? null
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    const ms = raw > 1e12 ? raw : raw * 1000
    return new Date(ms).toISOString()
  }
  if (typeof raw === 'string') {
    const d = new Date(raw)
    if (!Number.isNaN(d.getTime())) return d.toISOString()
  }
  return null
}

export function outcomeOf(ep) {
  for (const f of ['verdict', 'status', 'outcome']) {
    if (typeof ep[f] === 'string' && ep[f].trim()) return ep[f].trim().toUpperCase()
  }
  if (typeof ep.success === 'boolean') return ep.success ? 'PASS' : 'FAIL'
  return 'UNKNOWN'
}

export function lessonsOf(ep) {
  const out = []
  for (const f of ['learnings', 'lessons', 'lessons_learned']) {
    if (Array.isArray(ep[f])) for (const s of ep[f]) if (typeof s === 'string' && s.trim()) out.push(s.trim().slice(0, LESSON_CHARS))
  }
  if (Array.isArray(ep.mistakes)) for (const s of ep.mistakes) if (typeof s === 'string' && s.trim()) out.push(`mistake: ${s.trim()}`.slice(0, LESSON_CHARS))
  return out
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir).sort()) {
    const abs = join(dir, name)
    const st = statSync(abs)
    if (st.isDirectory()) walk(abs, out)
    else out.push(abs)
  }
  return out
}

/** Episodes of one file: `{ episodes: [...] }` or `{ unreadable: true }`. */
export function episodesOfFile(text, name) {
  if (name.endsWith('.jsonl')) {
    const episodes = []
    for (const line of text.split('\n')) {
      if (!line.trim()) continue
      try { const o = JSON.parse(line); if (o && typeof o === 'object') episodes.push(o) } catch { return { unreadable: true } }
    }
    return { episodes }
  }
  try {
    const o = JSON.parse(text)
    if (Array.isArray(o)) return { episodes: o.filter((x) => x && typeof x === 'object') }
    if (o && typeof o === 'object') return { episodes: [o] }
    return { unreadable: true }
  } catch {
    return { unreadable: true }
  }
}

function gitHead(root) {
  try { return execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim() } catch { return null }
}

/** Read one checkout; pure apart from the file system. */
export function readRepo({ repo, root }) {
  const dir = join(root, EXPERIENCE_DIR)
  const source = { repo, root, commit: gitHead(root), dir: EXPERIENCE_DIR, files: 0, episodes: 0, unreadable: [], notes: [] }
  const episodes = []
  if (!existsSync(dir)) return { source: { ...source, missing: true }, episodes }
  for (const abs of walk(dir)) {
    const rel = relative(root, abs).split('\\').join('/')
    source.files++
    if (abs.endsWith('.md')) { source.notes.push(rel); continue }
    if (!abs.endsWith('.json') && !abs.endsWith('.jsonl')) continue
    const parsed = episodesOfFile(readFileSync(abs, 'utf8'), abs)
    if (parsed.unreadable) { source.unreadable.push(rel); continue }
    for (const ep of parsed.episodes) {
      source.episodes++
      episodes.push({ repo, file: rel, ep })
    }
  }
  return { source, episodes }
}

/** The join, pure: takes what readRepo returned. */
export function buildExperience({ repos, generatedAt }) {
  const agents = {}
  const unattributed = { episodes: 0, outcomes: {}, agentValues: {}, byRepo: {} }
  const bump = (obj, key) => { obj[key] = (obj[key] ?? 0) + 1 }
  const all = []
  for (const { source, episodes } of repos) {
    for (const e of episodes) {
      const values = agentValuesOf(e.ep)
      const letters = [...new Set(values.map(letterOf).filter(Boolean))]
      const rec = { repo: e.repo, file: e.file, ts: timestampOf(e.ep), outcome: outcomeOf(e.ep), lessons: lessonsOf(e.ep), task: typeof e.ep.task === 'string' ? e.ep.task.slice(0, LESSON_CHARS) : (typeof e.ep.summary === 'string' ? e.ep.summary.slice(0, LESSON_CHARS) : null) }
      if (letters.length === 0) {
        unattributed.episodes++
        bump(unattributed.outcomes, rec.outcome)
        bump(unattributed.byRepo, e.repo)
        for (const v of values) bump(unattributed.agentValues, v)
        if (values.length === 0) bump(unattributed.agentValues, '(no agent field)')
        continue
      }
      for (const L of letters) {
        all.push({ L, rec })
      }
    }
    void source
  }
  all.sort((a, b) => (a.rec.ts ?? '').localeCompare(b.rec.ts ?? '') || a.rec.file.localeCompare(b.rec.file))
  for (const { L, rec } of all) {
    const a = (agents[L] ??= { letter: L, id: `t27/${L}`, episodes: 0, first: null, last: null, lastTask: null, outcomes: {}, lessons: [], files: [] })
    a.episodes++
    if (rec.ts) {
      if (!a.first || rec.ts < a.first) a.first = rec.ts
      if (!a.last || rec.ts >= a.last) { a.last = rec.ts; a.lastTask = rec.task }
    }
    bump(a.outcomes, rec.outcome)
    for (const l of rec.lessons) a.lessons.unshift(l)
    const key = `${rec.repo}:${rec.file}`
    if (!a.files.includes(key)) a.files.push(key)
  }
  for (const a of Object.values(agents)) {
    a.lessons = [...new Set(a.lessons)].slice(0, MAX_LESSONS)
    a.files.sort()
    a.outcomes = sortKeys(a.outcomes)
  }
  const ordered = {}
  for (const L of LETTERS) if (agents[L]) ordered[L] = agents[L]
  for (const L of Object.keys(agents).sort()) if (!ordered[L]) ordered[L] = agents[L]
  unattributed.outcomes = sortKeys(unattributed.outcomes)
  unattributed.agentValues = sortKeys(unattributed.agentValues)
  unattributed.byRepo = sortKeys(unattributed.byRepo)
  const sources = repos.map(({ source }) => ({ ...source, unreadable: source.unreadable.length, unreadableFiles: source.unreadable.slice(0, 5), notes: source.notes }))
  return {
    version: VERSION,
    generatedAt,
    attribution: {
      fields: AGENT_FIELDS,
      letters: LETTERS,
      rule: 'A letter is assigned only from an agent field that is one letter A-Z, "ti"/"27th", "t27/<letter>", or "agent-<letter>..."; everything else is unattributed. See scripts/sync-agents-experience.mjs and specs/agents/README.md.',
    },
    counts: {
      episodes: all.length + unattributed.episodes,
      attributed: all.length,
      unattributed: unattributed.episodes,
      agentsWithEpisodes: Object.keys(ordered).length,
      unreadableFiles: sources.reduce((n, s) => n + s.unreadable, 0),
    },
    sources,
    agents: ordered,
    unattributed,
  }
}

export function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys)
  if (value && typeof value === 'object') {
    const out = {}
    for (const k of Object.keys(value).sort()) out[k] = sortKeys(value[k])
    return out
  }
  return value
}

/** Schema check of a committed experience.json; returns problems. */
export function checkExperience(doc) {
  const problems = []
  if (!doc || typeof doc !== 'object') return ['experience.json is not an object']
  if (doc.version !== VERSION) problems.push(`version ${doc.version} != ${VERSION}`)
  if (typeof doc.generatedAt !== 'string' || Number.isNaN(Date.parse(doc.generatedAt))) problems.push('generatedAt is not a date')
  if (!Array.isArray(doc.sources) || doc.sources.length === 0) problems.push('sources missing')
  for (const s of doc.sources ?? []) {
    if (typeof s.repo !== 'string') problems.push('source without repo')
    if (s.commit !== null && !/^[0-9a-f]{40}$/.test(s.commit ?? '')) problems.push(`source ${s.repo}: commit is not a sha`)
  }
  if (!doc.agents || typeof doc.agents !== 'object') problems.push('agents missing')
  let attributed = 0
  for (const [L, a] of Object.entries(doc.agents ?? {})) {
    if (!LETTERS.includes(L)) problems.push(`agents.${L}: not an alphabet letter`)
    if (!Number.isInteger(a.episodes) || a.episodes < 1) problems.push(`agents.${L}: episodes must be a positive integer`)
    attributed += a.episodes ?? 0
  }
  const u = doc.unattributed
  if (!u || !Number.isInteger(u.episodes)) problems.push('unattributed.episodes missing')
  const c = doc.counts
  if (!c || c.attributed !== attributed || c.unattributed !== (u?.episodes ?? -1) || c.episodes !== attributed + (u?.episodes ?? 0)) problems.push('counts do not add up')
  return problems
}

function writeAtomic(rel, data) {
  const dest = join(SITE, rel)
  mkdirSync(dirname(dest), { recursive: true })
  const temp = `${dest}.${process.pid}.tmp`
  writeFileSync(temp, `${JSON.stringify(data, null, 1)}\n`, { flag: 'wx' })
  renameSync(temp, dest)
}

export async function main(argv) {
  if (argv.includes('--check')) {
    const abs = join(SITE, OUT)
    if (!existsSync(abs)) { console.error(`sync-agents-experience: ${OUT} missing`); process.exit(1) }
    const doc = JSON.parse(readFileSync(abs, 'utf8'))
    const problems = checkExperience(doc)
    if (problems.length) { for (const p of problems) console.error('  ' + p); process.exit(1) }
    console.log(`sync-agents-experience: ${OUT} ok -- ${doc.counts.episodes} episodes, ${doc.counts.attributed} attributed to ${doc.counts.agentsWithEpisodes} agent(s), ${doc.counts.unattributed} unattributed, ${doc.counts.unreadableFiles} unreadable file(s); sources ${doc.sources.map((s) => `${s.repo}@${(s.commit ?? 'no-git').slice(0, 7)}`).join(', ')}`)
    return
  }
  const t27Root = process.env.T27_ROOT ?? T27_ROOT_DEFAULT
  const repos = [readRepo({ repo: 'trinity', root: REPO_ROOT }), readRepo({ repo: 't27', root: t27Root })]
  const epoch = process.env.SOURCE_DATE_EPOCH
  const generatedAt = epoch ? new Date(Number(epoch) * 1000).toISOString() : new Date().toISOString()
  const doc = buildExperience({ repos, generatedAt })
  writeAtomic(OUT, doc)
  for (const s of doc.sources) console.log(`sync-agents-experience: ${s.repo} ${s.root}${s.missing ? ' (no .trinity/experience)' : ''} @ ${(s.commit ?? 'no-git').slice(0, 7)}: ${s.files} files, ${s.episodes} episodes, ${s.unreadable} unreadable, ${s.notes.length} notes`)
  console.log(`sync-agents-experience: ${doc.counts.attributed} attributed to ${doc.counts.agentsWithEpisodes} agent(s), ${doc.counts.unattributed} unattributed -> ${OUT}`)
  if (doc.counts.unattributed) console.log(`sync-agents-experience: unattributed agent values: ${Object.entries(doc.unattributed.agentValues).map(([k, v]) => `${k} x${v}`).join(', ')}`)
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch((e) => { console.error(e); process.exit(1) })
}
