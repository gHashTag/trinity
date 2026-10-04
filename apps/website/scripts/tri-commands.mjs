#!/usr/bin/env node
// tri-commands.mjs -- the command list of each program called `tri`, read from its source at a commit.
//
// Three programs answer to `tri`, and the tools page owes every command of each a card:
//   t27      gHashTag/t27        cli/tri/src/main.rs   the clap `enum Commands` (kebab-case, as clap derives it)
//   trinity  gHashTag/trinity    src/tri + src/registry  the flat parser and the command registry (below)
//   trios    gHashTag/BrowserOS  trios/bin/tri         case arms + names `tri help` documents (tools-from-trios-tri.mjs)
//
// Each list is written to qa/tri-commands/<cli>.json with the commit it was read at, so the gate
// (qa/tools-coverage-contract.mjs) needs no external checkout: it holds the cards to the snapshot.
// gHashTag/trinity is this repository, so its snapshot is also re-read from the tree on every check;
// a new command in src/tri fails the gate until the snapshot and the cards are regenerated.
//
// Every `help` is the command's own text (a /// doc, a registry description, a help line, a comment).
// '' means the source carries none; a card then says "no help text in <cli>@<sha>", never a guess.
//
// Run:   node scripts/tri-commands.mjs --cli t27 --src FILE --commit SHA        FILE = cli/tri/src/main.rs at SHA
//        node scripts/tri-commands.mjs --cli trios --src FILE --commit SHA      FILE = trios/bin/tri at SHA
//        node scripts/tri-commands.mjs --cli trinity [--commit SHA]             reads ../../src (this repository)
//        add --check to exit 1 when the snapshot differs instead of writing it.
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { commandSet, helpOf } from './tools-from-trios-tri.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..')
export const REPO_ROOT = join(SITE, '..', '..')
export const SNAPSHOT_DIR = 'qa/tri-commands'
export const CLIS = {
  t27: { repo: 'gHashTag/t27', source: 'cli/tri/src/main.rs', cardDirs: ['tri'] },
  trinity: { repo: 'gHashTag/trinity', source: 'src/tri/main.zig + src/tri/tri_namespace.zig + src/tri/tri_utils.zig + src/registry/command_table.zig', cardDirs: ['trinity/tri', 'trinity/cli'] },
  trios: { repo: 'gHashTag/BrowserOS', source: 'trios/bin/tri', cardDirs: ['trios/tri'] },
}
export const TRINITY_FILES = { main: 'src/tri/main.zig', namespace: 'src/tri/tri_namespace.zig', utils: 'src/tri/tri_utils.zig', table: 'src/registry/command_table.zig', register: 'src/tri/tri_register.zig' }

// ---------------------------------------------------------------------------
// t27: the variants of `enum Commands` in cli/tri/src/main.rs, named the way clap derives them.
// help = the first paragraph of the variant's /// doc ('' when it has none).
export function kebab(variant) {
  // heck's kebab-case, as clap derives it: XBoard -> x-board, HTTPServer -> http-server.
  return variant.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/([A-Z])([A-Z][a-z])/g, '$1-$2').toLowerCase()
}
export function t27Commands(mainRs) {
  const lines = mainRs.split('\n')
  const start = lines.findIndex((l) => /^(pub )?enum Commands \{/.test(l))
  if (start === -1) throw new Error('cli/tri/src/main.rs: no `enum Commands {`')
  const out = []
  let doc = []
  for (let i = start + 1; i < lines.length && !/^\}/.test(lines[i]); i++) {
    const l = lines[i]
    const d = /^    \/\/\/ ?(.*)$/.exec(l)
    if (d) { doc.push(d[1]); continue }
    const v = /^    ([A-Z][A-Za-z0-9]*)\b/.exec(l)
    if (v) {
      const blank = doc.indexOf('')
      const help = (blank === -1 ? doc : doc.slice(0, blank)).join(' ').replace(/\s+/g, ' ').trim()
      out.push({ name: kebab(v[1]), aliases: [], help, helpSource: help ? `/// doc of Commands::${v[1]}, line ${i + 1}` : '', route: `Commands::${v[1]}` })
      doc = []
      continue
    }
    if (!/^\s*#\[/.test(l)) doc = doc.length && /^\s{8}/.test(l) ? doc : []
  }
  if (!out.length) throw new Error('cli/tri/src/main.rs: `enum Commands` has no variants')
  return out
}

// ---------------------------------------------------------------------------
// trios: the set tools-from-trios-tri.mjs makes its cards from.
export function triosCommands(src) {
  const set = commandSet(src)
  return set.all.map((name) => {
    const { helpAbout, comment, text } = helpOf(name, set)
    const helpSource = helpAbout ? '`tri help`' : comment ? `first comment of the \`${name})\` case arm, line ${set.arms.get(name).line}` : ''
    return { name, aliases: [], help: text, helpSource, route: set.arms.has(name) ? `case arm, line ${set.arms.get(name).line}` : 'tri help only' }
  })
}

// ---------------------------------------------------------------------------
// trinity: every first word a user can type as `tri <word>` that the source names, in src/tri/main.zig's order:
//   early          main.zig: `if (std.mem.eql(u8, first_arg, "x") ...)` routes taken before any parser
//   namespace      src/tri/tri_namespace.zig Namespace.fromString(): `tri <namespace> <command>`
//   parse_command  src/tri/tri_utils.zig parseCommand(): every `eql(u8, arg, "x")` returning a variant;
//                  the tokens of one variant are one command (first token = name, the rest aliases)
//   registry       src/registry/command_table.zig all_commands: every top-level `.name` (exported to MCP);
//                  one no layer above names is counted, and its card says `tri <name>` does not reach it
// Not counted (recorded in notCounted): execute_map handlers no layer and no registry entry names.
// help is the registry description, else the `tri help` line, else printCommandHelp's first prose line;
// a source comment above an early route is kept as `comment`, never promoted to help.

// A Zig string literal body -> text (\xNN byte escapes are UTF-8, as the source writes them).
export function zigString(s) {
  const bytes = []
  const cs = Array.from(s)
  for (let i = 0; i < cs.length; i++) {
    const c = cs[i]
    if (c !== '\\') { bytes.push(...Buffer.from(c, 'utf8')); continue }
    const n = cs[++i]
    if (n === 'x') { bytes.push(parseInt(cs.slice(i + 1, i + 3).join(''), 16)); i += 2; continue }
    if (n === 'u') {
      const m = /^\{([0-9a-fA-F]+)\}/.exec(cs.slice(i + 1).join(''))
      bytes.push(...Buffer.from(String.fromCodePoint(parseInt(m[1], 16)), 'utf8'))
      i += m[0].length
      continue
    }
    const simple = { n: 10, t: 9, r: 13 }[n]
    if (simple !== undefined) { bytes.push(simple); continue }
    bytes.push(...Buffer.from(n, 'utf8'))
  }
  return Buffer.from(bytes).toString('utf8')
}
const STR = '"((?:[^"\\\\]|\\\\.)*)"'
const strs = (s) => [...s.matchAll(new RegExp(STR, 'g'))].map((m) => zigString(m[1]))

function fnBody(lines, header) {
  const start = lines.findIndex((l) => l.startsWith(header))
  if (start === -1) throw new Error(`no \`${header}\``)
  let end = start + 1
  while (end < lines.length && !lines[end].startsWith('}')) end++
  return { start, body: lines.slice(start + 1, end) }
}

// parseCommand: variant -> tokens, in source order.
export function parserGroups(utils) {
  const lines = utils.split('\n')
  const { start, body } = fnBody(lines, 'pub fn parseCommand(')
  const groups = new Map()
  const claimed = new Set()
  body.forEach((l, k) => {
    const ret = /return \.(\w+);/.exec(l)
    if (!ret || ret[1] === 'none') return
    // The first `if` that matches a token wins: a later one never sees it (src/tri/tri_utils.zig tests
    // "omega" for .omega before .omega_cmd, so only "omega-phase" reaches .omega_cmd).
    const toks = [...l.matchAll(new RegExp(`eql\\(u8, arg, ${STR}\\)`, 'g'))].map((m) => zigString(m[1])).filter((t) => !t.startsWith('-') && !claimed.has(t))
    for (const t of toks) claimed.add(t)
    if (!toks.length) return
    const g = groups.get(ret[1]) ?? { variant: ret[1], tokens: [], line: start + 2 + k }
    for (const t of toks) if (!g.tokens.includes(t)) g.tokens.push(t)
    groups.set(ret[1], g)
  })
  return [...groups.values()]
}

// printHelp(): `  {s}names{s} args   description` -> token -> { text, line }.
export function helpLines(utils) {
  const lines = utils.split('\n')
  const { start, body } = fnBody(lines, 'pub fn printHelp(')
  const out = new Map()
  const prints = body.map((l, k) => ({ k, m: new RegExp(`std\\.debug\\.print\\(${STR}`).exec(l) })).filter((x) => x.m)
  prints.forEach(({ k, m }, idx) => {
    const fmt = zigString(m[1]).replace(/\n+$/, '').replace(/%%/g, '%')
    const h = /^\s+\{s\}([^{]+)\{s\}(.*)$/.exec(fmt)
    if (!h) return
    const parts = h[2].trim().split(/\s{2,}/).filter(Boolean)
    let text = parts.length > 1 ? parts.slice(1).join(' ') : parts.length === 1 && !/^[<[-]/.test(parts[0]) ? parts[0] : ''
    if (!text) {
      const next = prints[idx + 1] ? zigString(prints[idx + 1].m[1]).replace(/\n+$/, '') : ''
      if (/^\s{5,}\S/.test(next) && !next.includes('{s}')) text = next.trim()
    }
    if (!text) return
    const names = h[1].trim()
    const sub = names.includes(' ') && !names.includes(',')
    for (const tok of names.split(/,\s*/)) {
      const first = tok.trim().split(/\s+/)[0]
      const entry = { text: sub ? `${names}: ${text}` : text, line: start + 2 + k, exact: !sub && !names.includes(',') }
      const had = out.get(first)
      const better = !had || (!had.exact && entry.exact)
      if (better) out.set(first, entry)
    }
  })
  return out
}

// printCommandHelp(cmd): the first prose line of the variant's switch arm (not usage, not a heading).
export function commandHelpProse(utils) {
  const lines = utils.split('\n')
  const { start, body } = fnBody(lines, 'pub fn printCommandHelp(')
  const out = new Map()
  let arm = null
  body.forEach((l, k) => {
    const a = /^        \.(\w+)(?:,\s*\.\w+)* => \{/.exec(l)
    if (a) { arm = a[1]; return }
    if (/^        \},?$/.test(l)) { arm = null; return }
    if (!arm || out.has(arm)) return
    const m = new RegExp(`std\\.debug\\.print\\(${STR}`).exec(l)
    if (!m) return
    const text = zigString(m[1]).replace(/\n+$/, '').trim()
    const prose = text && !text.includes('{s}') && !/^tri\b/.test(text) && !/^#/.test(text)
    if (prose) out.set(arm, { text, line: start + 2 + k })
  })
  return out
}

// all_commands: the top-level entries (four-space `.{` ... `},`), their name, aliases and description.
export function registryEntries(table) {
  const lines = table.split('\n')
  const out = []
  let cur = null
  lines.forEach((l, i) => {
    if (/^    \.\{\s*$/.test(l)) { cur = { line: i + 1, name: null, aliases: [], description: '' }; return }
    if (!cur) return
    if (/^    \},?\s*$/.test(l)) { if (cur.name) out.push(cur); cur = null; return }
    const f = /^        \.(name|aliases|description) = (.*)$/.exec(l)
    if (!f) return
    if (f[1] === 'name') cur.name = strs(f[2])[0]
    if (f[1] === 'aliases') cur.aliases = strs(f[2])
    if (f[1] === 'description') cur.description = strs(f[2])[0] ?? ''
  })
  return out
}

// execute_map: the names with a live (uncommented) entry.
export function executeMapNames(register) {
  const lines = register.split('\n')
  const start = lines.findIndex((l) => /^const execute_map = /.test(l))
  if (start === -1) return new Set()
  const names = new Set()
  for (let i = start + 1; i < lines.length && !/^\};/.test(lines[i]); i++) {
    const m = new RegExp(`^    \\.\\{ \\.name = ${STR}`).exec(lines[i])
    if (m) names.add(zigString(m[1]))
  }
  return names
}

// src/tri/main.zig routes some first words before any parser: `if (std.mem.eql(u8, first_arg, "x") or ...) {`.
// One `if` is one route; the // line right above it is kept as a note (a source comment, not help text).
export function earlyRoutes(main) {
  const lines = main.split('\n')
  const out = []
  for (let i = 0; i < lines.length; i++) {
    const opens = /^\s*if \(std\.mem\.eql\(u8, first_arg, /.test(lines[i])
    if (!opens) continue
    let j = i
    while (j < lines.length - 1 && !/\{\s*$/.test(lines[j])) j++
    const span = lines.slice(i, j + 1).join(' ')
    const tokens = [...span.matchAll(new RegExp(`eql\\(u8, first_arg, ${STR}\\)`, 'g'))].map((m) => zigString(m[1])).filter((t) => !t.startsWith('-'))
    // Only the line right above: a block of comments above an `if` often belongs to the route before it.
    const above = /^\s*\/\/\s?(.*)$/.exec(lines[i - 1] ?? '')
    if (tokens.length) out.push({ tokens: [...new Set(tokens)], line: i + 1, comment: above ? above[1].trim() : '' })
    i = j
  }
  return out
}

// src/tri/tri_namespace.zig Namespace.fromString(): the words that make `tri <word> <command>` a namespaced call.
export function namespaceWords(ns) {
  const lines = ns.split('\n')
  const { start, body } = fnBody(lines.map((l) => l.replace(/^    /, '')), 'pub fn fromString(')
  return body.flatMap((l, k) => {
    const m = new RegExp(`eql\\(u8, str, ${STR}\\)`).exec(l)
    return m ? [{ word: zigString(m[1]), line: start + 2 + k }] : []
  })
}

// The dispatch order of src/tri/main.zig: early routes, then namespaces, then parseCommand. A registry
// name none of them knows falls to parseCommand's .none (`tri <name>` becomes a chat message).
export const TRINITY_LAYERS = ['early', 'namespace', 'parse_command', 'registry']

export function trinityCommands({ utils, table, register, main, namespace }) {
  const groups = parserGroups(utils)
  const help = helpLines(utils)
  const prose = commandHelpProse(utils)
  const registry = registryEntries(table)
  const exec = executeMapNames(register)
  const byToken = new Map()
  const commands = []
  const add = (name, aliases) => {
    const c = { name, aliases: [], layers: {} }
    for (const t of [name, ...aliases]) if (!byToken.has(t)) { if (t !== name) c.aliases.push(t); byToken.set(t, c) }
    commands.push(c)
    return c
  }
  for (const g of groups) {
    const name = g.tokens.find((t) => /^[a-z0-9][a-z0-9-]*$/.test(t)) ?? g.tokens[0]
    const c = add(name, g.tokens.filter((t) => t !== name))
    c.layers.parse_command = `parseCommand returns .${g.variant}, ${TRINITY_FILES.utils}:${g.line}`
    c.variant = g.variant
  }
  for (const r of earlyRoutes(main)) {
    for (const t of r.tokens) {
      const c = byToken.get(t) ?? add(t, [])
      c.layers.early ??= `routed by src/tri/main.zig before any parser, line ${r.line}${byToken.get(t) && c.layers.parse_command ? ' (for the forms that \`if\` matches; the rest reach parseCommand)' : ''}`
      if (r.comment && !c.comment) c.comment = `${TRINITY_FILES.main}:${r.line - 1}: ${r.comment}`
    }
  }
  for (const { word, line } of namespaceWords(namespace)) {
    const c = byToken.get(word) ?? add(word, [])
    c.layers.namespace = `a namespace word (\`tri ${word} <command>\`), ${TRINITY_FILES.namespace}:${line}`
  }
  for (const r of registry) {
    const c = byToken.get(r.name) ?? add(r.name, [])
    c.registry = r
    const routedOnly = Object.keys(c.layers).length === 0
    if (routedOnly) c.layers.registry = `registry entry only, ${TRINITY_FILES.table}:${r.line}${exec.has(r.name) ? `, with an execute_map handler in ${TRINITY_FILES.register}` : ', no live execute_map entry'}; no early route, namespace word or parseCommand token names it, so \`tri ${r.name}\` reaches parseCommand .none`
  }
  for (const c of commands) {
    for (const a of c.registry?.aliases ?? []) if (!byToken.has(a)) { c.aliases.push(a); byToken.set(a, c) }
    const fromRegistry = c.registry?.description ? { text: c.registry.description, src: `registry description, ${TRINITY_FILES.table}:${c.registry.line}` } : null
    const h = [c.name, ...c.aliases].map((t) => help.get(t)).find(Boolean)
    const fromHelp = h ? { text: h.text, src: `\`tri help\` line, ${TRINITY_FILES.utils}:${h.line}` } : null
    const p = c.variant ? prose.get(c.variant) : null
    const fromProse = p ? { text: p.text, src: `\`tri ${c.name} --help\` (printCommandHelp .${c.variant}), ${TRINITY_FILES.utils}:${p.line}` } : null
    const best = fromRegistry ?? fromHelp ?? fromProse
    c.help = best?.text ?? ''
    c.helpSource = best?.src ?? ''
    const kinds = TRINITY_LAYERS.filter((k) => c.layers[k])
    c.routeKind = kinds[0]
    c.routed = c.routeKind !== 'registry'
    c.route = kinds.map((k) => c.layers[k]).join('; then ')
    c.inRegistry = Boolean(c.registry)
    c.comment ??= ''
    delete c.layers
    delete c.registry
    delete c.variant
  }
  const notCounted = [...exec].filter((n) => !byToken.has(n)).sort()
  const order = ['name', 'aliases', 'help', 'helpSource', 'route', 'routeKind', 'routed', 'inRegistry', 'comment']
  const sorted = commands.map((c) => Object.fromEntries(order.map((k) => [k, c[k]]))).sort((a, b) => (a.name < b.name ? -1 : 1))
  return { commands: sorted, notCounted }
}

export function trinityFromTree(root = REPO_ROOT) {
  const read = (p) => readFileSync(join(root, p), 'utf8')
  return trinityCommands(Object.fromEntries(Object.entries(TRINITY_FILES).map(([k, p]) => [k, read(p)])))
}

// ---------------------------------------------------------------------------
export function snapshotPath(cli, site = SITE) { return join(site, SNAPSHOT_DIR, `${cli}.json`) }
export function readSnapshot(cli, site = SITE) {
  const p = snapshotPath(cli, site)
  return existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : null
}

export function snapshot(cli, { src, commit }) {
  if (!/^[0-9a-f]{40}$/.test(commit ?? '')) throw new Error(`--commit must be a full 40-hex SHA, is ${JSON.stringify(commit)}`)
  const meta = CLIS[cli]
  if (!meta) throw new Error(`--cli must be one of ${Object.keys(CLIS).join('|')}`)
  let commands, notCounted = []
  if (cli === 't27') commands = t27Commands(src)
  if (cli === 'trios') commands = triosCommands(src)
  if (cli === 'trinity') ({ commands, notCounted } = src)
  const rule = {
    t27: 'every variant of the clap `enum Commands` in cli/tri/src/main.rs, kebab-case as clap derives it',
    trinity: 'every first word src/tri/main.zig routes before any parser, every namespace word of src/tri/tri_namespace.zig, every command src/tri/tri_utils.zig parseCommand() returns (its tokens: name + aliases) and every top-level entry of src/registry/command_table.zig all_commands',
    trios: 'every top-level case arm of trios/bin/tri and every name `tri help` documents (tools-from-trios-tri.mjs commandSet)',
  }[cli]
  const notCountedNote = cli === 'trinity'
    ? 'execute_map handlers (src/tri/tri_register.zig) that no early route, namespace word, parseCommand token or registry entry names; `tri <name>` does not reach them (src/tri/main.zig dispatchNamespacedCommand may)'
    : ''
  return {
    cli, repo: meta.repo, source: meta.source, commit, rule,
    extractedBy: 'apps/website/scripts/tri-commands.mjs',
    cardDirs: meta.cardDirs,
    count: commands.length,
    withHelp: commands.filter((c) => c.help).length,
    notCounted, notCountedNote,
    commands,
  }
}

const json = (x) => `${JSON.stringify(x, null, 2)}\n`

function main() {
  const argv = process.argv.slice(2)
  const opt = (k) => { const i = argv.indexOf(k); return i === -1 ? null : argv[i + 1] }
  const cli = opt('--cli'), check = argv.includes('--check')
  let commit = opt('--commit'), src
  if (cli === 'trinity') {
    src = trinityFromTree()
    commit ??= execFileSync('git', ['-C', REPO_ROOT, 'log', '-1', '--format=%H', '--', ...Object.values(TRINITY_FILES)], { encoding: 'utf8' }).trim()
  } else {
    const p = opt('--src')
    if (!p || !commit) { console.error('usage: tri-commands.mjs --cli t27|trios --src FILE --commit SHA [--check] | --cli trinity [--commit SHA] [--check]'); process.exit(2) }
    src = readFileSync(p, 'utf8')
  }
  const want = json(snapshot(cli, { src, commit }))
  const path = snapshotPath(cli)
  const have = existsSync(path) ? readFileSync(path, 'utf8') : null
  const s = JSON.parse(want)
  if (check) {
    if (have !== want) { console.error(`tri-commands ${cli}: ${path} differs from ${s.repo}@${commit.slice(0, 12)}; run without --check`); process.exit(1) }
    console.log(`tri-commands ${cli}: ${s.count} commands in step with ${s.repo}@${commit.slice(0, 12)} (${s.withHelp} with help text)`)
    return
  }
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, want)
  console.log(`tri-commands ${cli}: wrote ${s.count} commands of ${s.repo}@${commit.slice(0, 12)} to ${SNAPSHOT_DIR}/${cli}.json (${s.withHelp} with help text${s.notCounted.length ? `, ${s.notCounted.length} not counted` : ''})`)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main()
