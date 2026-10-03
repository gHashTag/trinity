#!/usr/bin/env node
// tools-from-trios-tri.mjs -- one .t27 tool card per command of the trios `tri` CLI.
//
// gHashTag/BrowserOS:trios/bin/tri is the CLI the loop timers run (`tri drift` holds the live
// ~/.local/bin/tri to it). It is a third program called `tri`, beside the Rust tri of
// gHashTag/t27 (specs/tools/tri/) and the Zig tri of gHashTag/trinity (specs/tools/trinity/tri/),
// so its cards live under specs/tools/trios/tri/ with repository-qualified IDs.
//
// Every field is read from the file at a pinned commit, nothing is typed by hand:
//   - the command set is the union of the top-level `case` arms and the names `tri help` prints;
//   - ABOUT is the help line (its continuation lines included), or, for an arm the help never
//     names, the first comment inside that arm -- DOCUMENTED says which;
//   - CATEGORY is the `--- section ---` heading the help line sits under;
//   - DISPATCH is the first line of the arm that does the work.
// The cards are ASCII (L3): the generator maps the punctuation the help uses and refuses
// anything else, so a new symbol in the CLI fails here instead of reaching the compiler.
//
// Run:   node scripts/tools-from-trios-tri.mjs --src FILE --commit SHA          (write)
//        node scripts/tools-from-trios-tri.mjs --src FILE --commit SHA --check  (exit 1 on drift)
// FILE is trios/bin/tri at SHA, e.g. `git -C ~/BrowserOS show SHA:trios/bin/tri > /tmp/tri`.
//
// A card whose command a published recording ran (public/term/<id>/meta.json lists `tri <name> ...`,
// and agents-from-specs.mjs castProblems() accepts it) ends with CAST = "term/<id>/session.cast".
// The witness stays source-parse: the recording shows the command ran, not that the card's text
// describes it. When several recordings ran a command, the most recently recorded one is named.
import { castCommandRuns, castCommands, castProblems, readCasts } from './agents-from-specs.mjs'
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..')
export const OUT_DIR = 'public/t27/files/specs/tools/trios/tri'
export const REPO = 'gHashTag/BrowserOS'
export const SOURCE = 'trios/bin/tri'
// The arms that are not commands: the default arm and the help aliases.
const NOT_COMMANDS = new Set(['*', '-h', '--help'])

const ASCII_MAP = [
  [/—|–/g, '--'], [/→/g, '->'], [/←/g, '<-'], [/≠/g, '!='], [/≥/g, '>='], [/≤/g, '<='],
  [/×/g, 'x'], [/³/g, '3'], [/²/g, '2'], [/…/g, '...'], [/[“”«»]/g, '"'], [/[‘’]/g, "'"],
  [/·/g, '-'], [/≈/g, '~'], [/±/g, '+/-'], [/φ/g, 'phi'], [/✓/g, 'ok'], [/✗/g, 'x'],
  // Greek letters and a superscript the gHashTag/trinity help text uses (scripts/tools-from-trinity-tri.mjs).
  [/π/g, 'pi'], [/μ/g, 'mu'], [/χ/g, 'chi'], [/σ/g, 'sigma'], [/ε/g, 'epsilon'], [/γ/g, 'gamma'], [/ⁿ/g, '^n'],
]
// A developer's home directory is never published (qa/tools-spec-contract.mjs HOME_PATH);
// the source names several absolute paths under it, which read the same as ~/.
const HOME_DIR = /(^|[\s"'=:(;])(?:\/Users|\/home)\/[^/\s"']+\//g
export function ascii(s, where) {
  let out = s.replace(HOME_DIR, '$1~/')
  for (const [re, to] of ASCII_MAP) out = out.replace(re, to)
  const bad = out.match(/[^\x20-\x7e]/)
  if (bad) throw new Error(`${where}: non-ASCII ${JSON.stringify(bad[0])} (U+${bad[0].codePointAt(0).toString(16)}) has no mapping`)
  return out
}

// The help text: the body of the heredoc under the `help|-h|--help)` arm.
export function helpBlock(src) {
  const m = /^  help\|-h\|--help\)\n\s*cat <<'(\w+)'\n([\s\S]*?)\n\1\n/m.exec(src)
  if (!m) throw new Error('no `help|-h|--help)` heredoc in the source')
  return m[2]
}

// One entry per help line that starts with `  tri `; deeper-indented lines continue the one above.
export function parseHelp(help) {
  const entries = []
  let section = 'general'
  for (const raw of help.split('\n')) {
    const sec = /^\s*---\s*(.+?)\s*---\s*$/.exec(raw)
    if (sec) { section = sec[1]; continue }
    if (raw.startsWith('  tri ')) {
      const body = raw.slice(6)
      const k = body.search(/\s(—|--)\s/)
      const head = (k === -1 ? body : body.slice(0, k)).trim()
      const about = k === -1 ? '' : body.slice(k).replace(/^\s(—|--)\s/, '').trim()
      entries.push({ line: raw.trim(), head, about, section })
      continue
    }
    if (/^\s{6,}\S/.test(raw) && entries.length) {
      const e = entries[entries.length - 1]
      e.about = `${e.about} ${raw.trim()}`.trim()
      e.line = `${e.line} ${raw.trim()}`
    }
  }
  return entries
}

// The names one help line documents: `a / b [N] / c` names a, b and c; `(alias: tri x, tri y)` adds aliases.
export function namesOf(entry) {
  const names = []
  for (const seg of entry.head.split(' / ')) {
    const tok = (seg.trim().split(/\s+/)[0] ?? '').replace(/[^a-z0-9-].*$/, '')
    if (tok) names.push(tok)
  }
  const aliases = [...entry.head.matchAll(/alias(?:es)?: ([^)]*)/g)].flatMap((m) => [...m[1].matchAll(/tri ([a-z0-9-]+)/g)].map((x) => x[1]))
  return { names, aliases }
}

// Usage of one name inside a help head: the segment that starts with it, minus the name.
function usageOf(entry, name) {
  for (const seg of entry.head.split(' / ')) {
    const s = seg.trim()
    if (s === name || s.startsWith(`${name} `)) return s.slice(name.length).replace(/\(alias[^)]*\)/, '').trim()
  }
  return ''
}

// `x|y|z` as the first usage token are the actions; the rest are arguments in the order written.
export function splitUsage(usage) {
  const tokens = usage.match(/\[[^\]]*\]|<[^>]*>|"[^"]*"|\S+/g) ?? []
  let actions = []
  if (tokens.length && /^[a-z][a-z0-9-]*(\|[a-z][a-z0-9-]*)+$/.test(tokens[0])) actions = tokens.shift().split('|')
  return { actions, args: tokens }
}

// Top-level case arms of the dispatcher (two-space indent), with their bodies.
export function caseArms(src) {
  const lines = src.split('\n')
  const arms = new Map()
  for (let i = 0; i < lines.length; i++) {
    const m = /^  ([a-z0-9*][a-z0-9|_*-]*|-h\|--help|help\|-h\|--help)\)(.*)$/.exec(lines[i])
    if (!m) continue
    const inline = m[2].trim()
    const body = []
    if (inline && inline !== ';;') body.push(inline.replace(/\s*;;\s*$/, ''))
    if (!/;;\s*$/.test(inline)) {
      for (let j = i + 1; j < lines.length && !/^\s*;;\s*$/.test(lines[j]) && !/^  [a-z0-9*][a-z0-9|_*-]*\)/.test(lines[j]); j++) body.push(lines[j])
    }
    for (const name of m[1].split('|')) if (!NOT_COMMANDS.has(name)) arms.set(name, { line: i + 1, body })
  }
  return arms
}

function firstComment(body) {
  const lines = []
  for (const l of body) {
    const t = l.trim()
    if (t.startsWith('#')) { lines.push(t.replace(/^#+\s?/, '')); continue }
    if (lines.length) break
  }
  return lines.join(' ').trim()
}
function dispatchOf(body) {
  const work = body.map((x) => x.trim().replace(/^shift( \d+)?( 2>\/dev\/null)?( \|\| true)?;\s*/, ''))
  return work.find((t) => t && !t.startsWith('#') && !/^shift\b/.test(t) && !/^\[ -z/.test(t)) ?? ''
}

const q = (s) => `"${s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`
const arr = (xs) => `[${xs.length}]str = [${xs.map(q).join(', ')}]`
const modName = (base) => `tool_trios_tri_${base.replace(/[^A-Za-z0-9]+/g, '_')}`

// The recording a card names: the newest one (meta.recorded, then id) that runs `command` and passes castProblems().
export function castFor(command, casts) {
  const fits = [...casts.values()].filter((c) => {
    const runsCommand = castCommands(c).some((line) => castCommandRuns(line, command))
    const passes = runsCommand && castProblems('-', { cast: `term/${c.id}/session.cast`, witness: 'source-parse', command }, casts).length === 0
    return passes
  })
  fits.sort((a, b) => String(b.meta?.recorded ?? '').localeCompare(String(a.meta?.recorded ?? '')) || (a.id < b.id ? -1 : 1))
  return fits[0] ?? null
}

// The command set: the union of the top-level case arms and the names `tri help` documents, each with
// the help entry that describes it (doc) and its case arm (arms). scripts/tri-commands.mjs snapshots
// the same set, so the coverage gate and the cards can never disagree on what a command is.
export function commandSet(src) {
  const entries = parseHelp(helpBlock(src))
  const arms = caseArms(src)
  const doc = new Map()
  for (const e of entries) {
    const { names, aliases } = namesOf(e)
    // A name can sit on a grouped line with no description and again on its own line with one: keep the described one.
    const better = (n) => !doc.has(n) || (!doc.get(n).e.about && e.about)
    for (const n of names) if (better(n)) doc.set(n, { e, aliasOf: null })
    for (const a of aliases) if (better(a)) doc.set(a, { e, aliasOf: names[0] })
  }
  const all = [...new Set([...arms.keys(), ...doc.keys()])].filter((n) => !NOT_COMMANDS.has(n)).sort()
  return { all, arms, doc }
}

// What a command's own source says it does: the help line, else the first comment of its case arm.
// '' when neither says anything; the card then says so (noHelp) instead of inventing a description.
export function helpOf(name, { arms, doc }) {
  const d = doc.get(name)
  const arm = arms.get(name)
  // A terse help description ("this help") is kept, prefixed with the command so it reads alone on a card.
  const helpAbout = !d ? '' : d.e.about && d.e.about.length <= 10 ? `tri ${name}: ${d.e.about}` : d.e.about
  const comment = arm ? firstComment(arm.body) : ''
  return { helpAbout, comment, text: helpAbout || comment }
}

export const noHelp = (commit) => `no help text in ${REPO}:${SOURCE}@${commit.slice(0, 12)}`

export function cards(src, commit, casts = new Map()) {
  if (!/^[0-9a-f]{40}$/.test(commit)) throw new Error(`--commit must be a full 40-hex SHA, is ${JSON.stringify(commit)}`)
  const set = commandSet(src)
  const { all, arms, doc } = set
  const out = new Map()
  for (const name of all) {
    const where = `tri ${name}`
    const d = doc.get(name)
    const arm = arms.get(name)
    // DOCUMENTED = `tri help` names the command. The description is the help line's own, else the
    // first comment of the case arm, and ABOUT_SOURCE says which one it is.
    const documented = Boolean(d)
    const { helpAbout, comment } = helpOf(name, set)
    const about = ascii(helpAbout || comment || `${noHelp(commit)}: ${documented ? '`tri help` names it without a description and its case arm carries no comment' : 'no line in `tri help` and no comment in its case arm'}`, where)
    const helpSrc = `\`tri help\` (the heredoc under the help arm of ${SOURCE})${d?.aliasOf ? `, as an alias of tri ${d.aliasOf}` : ''}`
    const armSrc = arm ? `first comment of the \`${name})\` case arm of ${SOURCE}, line ${arm.line}` : ''
    const aboutSource = helpAbout ? helpSrc
      : comment ? `${armSrc}: ${documented ? '`tri help` names the command without a description' : '`tri help` does not name this command'}`
      : documented ? `${helpSrc}, which names it without a description` : `${SOURCE}: neither \`tri help\` nor the case arm describes it`
    const { actions, args } = splitUsage(d ? usageOf(d.e, name) : '')
    const dispatch = ascii(arm ? dispatchOf(arm.body) : '', where)
    const routed = Boolean(arm)
    const recording = castFor(`tri ${name}`, casts)
    const castLines = recording === null ? [] : [
      `; public/term/${recording.id}/meta.json lists ${castCommands(recording).filter((line) => castCommandRuns(line, `tri ${name}`)).length} run(s) of \`tri ${name}\`; recorded with the live ~/.local/bin/tri,`,
      `; not a build of SOURCE_COMMIT. The site plays it at the end of this card.`,
      `pub const CAST : str = ${q(`term/${recording.id}/session.cast`)};`,
    ]
    const lines = [
      '// SPDX-License-Identifier: Apache-2.0',
      `; specs/tools/trios/tri/${name}.t27 -- tool ${REPO}:tri/${name}, the \`tri ${name}\` command of the trios loop CLI`,
      `; Generated by apps/website/scripts/tools-from-trios-tri.mjs from ${REPO}:${SOURCE} at ${commit.slice(0, 12)}; do not edit.`,
      '; The CLI the loop timers run (`tri drift` holds ~/.local/bin/tri to the tracked copy). It is another program than',
      '; the Rust tri of gHashTag/t27 and the Zig tri of gHashTag/trinity, so the ID is repository-qualified.',
      '; A card is data and carries no test block. ASCII only (L3). phi^2 + 1/phi^2 = 3 | TRINITY',
      '',
      `module ${modName(name)};`,
      '',
      'pub const KIND : str = "tool";',
      'pub const FAMILY : str = "tri-cli";',
      `pub const ID : str = ${q(`${REPO}:tri/${name}`)};`,
      `pub const REPO : str = ${q(REPO)};`,
      `pub const QUALIFIED_ID : str = ${q(`${REPO}:tri/${name}`)};`,
      'pub const SCHEMA : u32 = 2;',
      `pub const COMMAND : str = ${q(`tri ${name}`)};`,
      '; The case arm of the dispatcher and the first line of it that does the work.',
      `pub const VARIANT : str = ${q(arm ? `case arm \`${name})\`, line ${arm.line}` : 'no case arm: named by `tri help` only')};`,
      `pub const SOURCE : str = ${q(SOURCE)};`,
      `pub const ENTRY : str = ${q(SOURCE)};`,
      `pub const SOURCE_COMMIT : str = ${q(commit)};`,
      `pub const ROUTED : bool = ${routed};`,
      `pub const DISPATCH : str = ${q(dispatch)};`,
      `pub const DOCUMENTED : bool = ${documented};`,
      `pub const HELP_LINE : str = ${q(d ? ascii(d.e.line, where) : '')};`,
      `pub const CATEGORY : str = ${q(ascii(d ? d.e.section : 'undocumented', where))};`,
      `pub const ABOUT : str = ${q(about)};`,
      `pub const ABOUT_SOURCE : str = ${q(ascii(aboutSource, where))};`,
      `pub const ACTIONS : ${arr(actions.map((x) => ascii(x, where)))};`,
      `pub const ACTIONS_ABOUT : ${arr(actions.map(() => ''))};`,
      `pub const ARGS : ${arr(args.map((x) => ascii(x, where)))};`,
      'pub const AGENTS : [0]str = [];',
      `pub const AGENTS_NOTE : str = ${q('No source binds an agent letter to this command: the trios CLI is not named by docs/agents/AGENTS_ALPHABET.md or .claude/agents/*.md of gHashTag/t27.')};`,
      `pub const WHEN_TO_USE : str = ${q(about)};`,
      ...castLines,
      'pub const WITNESS : str = "source-parse";',
      `pub const WITNESS_SOURCE : str = ${q(`${REPO}:${SOURCE} at ${commit}, read as text (the help heredoc and the top-level case arms); the CLI was not run`)};`,
      'pub const ENABLED : bool = true;',
      '',
    ]
    out.set(`${name}.t27`, lines.join('\n'))
  }
  return out
}

function main() {
  const argv = process.argv.slice(2)
  const opt = (k) => { const i = argv.indexOf(k); return i === -1 ? null : argv[i + 1] }
  const srcPath = opt('--src'), commit = opt('--commit'), check = argv.includes('--check')
  if (!srcPath || !commit) { console.error('usage: tools-from-trios-tri.mjs --src FILE --commit SHA [--check]'); process.exit(2) }
  const want = cards(readFileSync(srcPath, 'utf8'), commit, readCasts(SITE))
  const dir = join(SITE, OUT_DIR)
  const have = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.t27')) : []
  const drift = [...[...want].filter(([f, t]) => !existsSync(join(dir, f)) || readFileSync(join(dir, f), 'utf8') !== t).map(([f]) => f), ...have.filter((f) => !want.has(f))]
  const undocumented = [...want.values()].filter((t) => t.includes('DOCUMENTED : bool = false')).length
  const withCast = [...want.values()].filter((t) => t.includes('pub const CAST : str = ')).length
  if (check) {
    if (drift.length) { console.error(`trios tri cards: ${drift.length} drifted (${drift.slice(0, 8).join(', ')}${drift.length > 8 ? ', ...' : ''})`); process.exit(1) }
    console.log(`trios tri cards: ${want.size} in step with ${commit.slice(0, 12)} (${undocumented} undocumented, ${withCast} with a recorded run)`)
    return
  }
  rmSync(dir, { recursive: true, force: true })
  mkdirSync(dir, { recursive: true })
  for (const [f, t] of want) writeFileSync(join(dir, f), t)
  console.log(`trios tri cards: wrote ${want.size} to ${OUT_DIR} from ${commit.slice(0, 12)} (${undocumented} undocumented, ${withCast} with a recorded run, ${drift.length} changed)`)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main()
