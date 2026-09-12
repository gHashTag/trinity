// t27-corpus.mjs -- what one vendored .t27 file becomes in public/t27/manifest.json.
//
// Two writers share this: scripts/sync-t27-specs.mjs, which rebuilds the whole corpus from a
// local t27 checkout plus the founding tarballs, and scripts/discover-t27-worlds.mjs, which
// adds the repositories a GitHub scan finds. An entry, a tag, a summary or an aggregate must
// mean the same thing whichever of the two wrote it, so the code that derives them lives
// here once. Nothing in this file reads GitHub or the file system; callers hand it bytes.

import { readFileSync, writeFileSync, existsSync } from 'node:fs'

/**
 * A spec's own header comments, as its description.
 *
 * Specs open with either `//` or `;` comment lines. SPDX, decorative rules and
 * the φ banner are dropped -- they are boilerplate on nearly every file and say
 * nothing about the individual spec.
 */
export function describe(text) {
  const out = []
  for (const raw of text.split('\n')) {
    const line = raw.trim()
    if (line === '') { if (out.length) break; else continue }
    const m = line.match(/^(?:\/\/|;)\s?(.*)$/)
    if (!m) break
    const body = m[1].trim()
    if (!body) continue
    if (/^SPDX-License-Identifier/i.test(body)) continue
    if (/^[=\-_*#~]{4,}$/.test(body)) continue
    if (/φ|phi\^?2/i.test(body) && /TRINITY/i.test(body)) continue
    if (/^DO NOT EDIT/i.test(body)) continue
    out.push(body)
    if (out.length >= 6) break
  }
  return out.join(' ').replace(/\s+/g, ' ').trim() || null
}

/**
 * Tags, derived from what a spec actually is rather than hand-applied.
 *
 * 760 specs cannot be tagged by hand and stay correct, so every tag here comes
 * from a signal already in the file: its path, the node kinds its AST really
 * contains, and what the backends produced. Nothing is inferred from the
 * filename alone, and nothing is invented.
 *
 * Three families, kept deliberately separate so combining them means something:
 *   domain/    what the spec is about        (fpga, ml, numeric …)
 *   has/       what it structurally contains (tests, structs, functions …)
 *   size/, src/, plus a bare health tag.
 */
export const DOMAIN_BY_SEGMENT = {
  fpga: 'fpga', boards: 'fpga', testbench: 'fpga', pins: 'fpga',
  ml: 'ml', nn: 'ml', layers: 'ml', activation: 'ml', transformer: 'ml',
  recurrent: 'ml', rl: 'ml', loss: 'ml', optimizer: 'ml', hslm: 'ml',
  numeric: 'numeric', math: 'math', physics: 'physics', sacred: 'sacred',
  isa: 'isa', compiler: 'compiler', parser: 'compiler', codegen: 'compiler',
  lsp: 'compiler', vm: 'compiler', jit: 'compiler', runtime: 'compiler',
  crypto: 'crypto', vsa: 'vsa', brain: 'brain', agent: 'agent',
  net: 'network', server: 'network', api: 'network', interop: 'network',
  storage: 'storage', memory: 'storage', file: 'storage', io: 'storage',
  collections: 'collections', trees: 'collections', sort: 'collections',
  search: 'collections', graph: 'graph',
  test_framework: 'testing', conformance: 'testing', benchmarks: 'testing',
  tutorial: 'tutorial', demos: 'tutorial', examples: 'tutorial',
  github: 'tools', git: 'tools', tools: 'tools', shell: 'tools', cli: 'tools',
  encoding: 'encoding', ternary: 'ternary', tri27: 'ternary',
  // Added after checking what actually landed in domain/other: these five
  // segments accounted for most of it.
  utils: 'utils', pipeline: 'pipeline', ar: 'reasoning', base: 'base',
  sandbox: 'tools', config: 'tools', provider: 'network', account: 'network',
  auth: 'network', queen: 'agent', bus: 'network', sync: 'network',
  enrichment: 'tools', contrib: 'other',
}

export function deriveTags(rel, repo, kinds, entry) {
  const tags = new Set()
  const segs = rel.split('/').slice(0, -1)

  for (const s of segs) {
    const d = DOMAIN_BY_SEGMENT[s.toLowerCase()]
    if (d) tags.add(`domain/${d}`)
  }
  // A spec with no recognised segment is still a spec; say so rather than
  // leaving it untagged and unfindable.
  if (![...tags].some((t) => t.startsWith('domain/'))) tags.add('domain/other')

  // Structure, straight from the tree the compiler produced.
  if (kinds.TestBlock) tags.add('has/tests')
  if (kinds.InvariantBlock) tags.add('has/invariants')
  if (kinds.BenchBlock) tags.add('has/benches')
  if (kinds.StructDecl) tags.add('has/structs')
  if (kinds.EnumDecl) tags.add('has/enums')
  if (kinds.FnDecl) tags.add('has/functions')
  if (kinds.UseDecl) tags.add('has/imports')
  if (kinds.ConstDecl && !kinds.FnDecl) tags.add('has/constants-only')
  if (kinds.StmtWhile || kinds.StmtFor) tags.add('has/loops')
  if (kinds.ExprSwitch) tags.add('has/switch')

  const lines = entry.lines
  tags.add(lines < 50 ? 'size/tiny' : lines < 150 ? 'size/small' : lines < 400 ? 'size/medium' : 'size/large')

  tags.add(`src/${repo}`)
  tags.add(`health/${entry.health}`)
  if (entry.loss > 0) tags.add('issue/dropped-content')
  if (entry.tcErrors > 0) tags.add('issue/type-errors')
  if (entry.failedBackends.length) tags.add('issue/backend-rejected')

  return [...tags].sort()
}

/**
 * A written-out description of what a spec actually is.
 *
 * The header comment alone is whatever its author felt like typing -- often
 * good, sometimes one word, missing on 42 of them. This adds a second sentence
 * built from measured facts: what the spec declares, what the compiler makes of
 * it, and what it emits. Every number here came from running the compiler, so
 * the prose cannot drift from the artifact the way a hand-written blurb would.
 */
export function summarise(kinds, entry, health) {
  const parts = []

  const decl = []
  if (kinds.FnDecl) decl.push(`${kinds.FnDecl} function${kinds.FnDecl > 1 ? 's' : ''}`)
  if (kinds.StructDecl) decl.push(`${kinds.StructDecl} struct${kinds.StructDecl > 1 ? 's' : ''}`)
  if (kinds.EnumDecl) decl.push(`${kinds.EnumDecl} enum${kinds.EnumDecl > 1 ? 's' : ''}`)
  if (kinds.ConstDecl) decl.push(`${kinds.ConstDecl} constant${kinds.ConstDecl > 1 ? 's' : ''}`)
  parts.push(decl.length ? `Declares ${listy(decl)}.` : 'Declares no top-level items.')

  const claims = []
  if (kinds.TestBlock) claims.push(`${kinds.TestBlock} test${kinds.TestBlock > 1 ? 's' : ''}`)
  if (kinds.InvariantBlock) claims.push(`${kinds.InvariantBlock} invariant${kinds.InvariantBlock > 1 ? 's' : ''}`)
  if (kinds.BenchBlock) claims.push(`${kinds.BenchBlock} bench${kinds.BenchBlock > 1 ? 'es' : ''}`)
  if (claims.length) parts.push(`Carries ${listy(claims)}.`)

  parts.push(`${entry.lines} lines compile to ${entry.tokens.toLocaleString()} tokens and ${entry.nodes.toLocaleString()} AST nodes, depth ${entry.depth}.`)

  const emitted = Object.entries(entry.outBytes).filter(([, v]) => v !== null && v > 0)
  if (emitted.length) {
    const biggest = emitted.sort((a, b) => b[1] - a[1])[0]
    parts.push(`Emits ${emitted.length} of 5 backends; largest is ${TARGET_LABEL[biggest[0]] || biggest[0]} at ${fmtBytes(biggest[1])}.`)
  }

  if (health === 'fail') {
    parts.push(`Rejected by ${listy(entry.failedBackends.map((b) => TARGET_LABEL[b] || b))}.`)
  } else if (health === 'warn') {
    const w = []
    if (entry.loss > 0) w.push(`${entry.loss} item${entry.loss > 1 ? 's' : ''} dropped by error recovery`)
    if (entry.tcErrors > 0) w.push(`${entry.tcErrors} type error${entry.tcErrors > 1 ? 's' : ''}`)
    parts.push(`Compiles with ${listy(w)}.`)
  } else {
    parts.push('Clean through every layer.')
  }

  return parts.join(' ')
}

export const TARGET_LABEL = { zig: 'Zig', verilog: 'Verilog', verilog_hir: 'Verilog (HIR)', c: 'C', rust: 'Rust' }

export function listy(a) {
  if (a.length <= 1) return a[0] || ''
  return `${a.slice(0, -1).join(', ')} and ${a[a.length - 1]}`
}

export function fmtBytes(n) {
  return n >= 1024 ? `${(n / 1024).toFixed(1)} KB` : `${n} B`
}

/** The node-kind histogram of an analysis; tags and the UI histogram both read from it. */
export function kindsOf(analysis) {
  const kinds = {}
  if (analysis?.ast) {
    const walk = (n) => { kinds[n.kind] = (kinds[n.kind] || 0) + 1; n.children.forEach(walk) }
    walk(analysis.ast)
  }
  return kinds
}

/**
 * One manifest entry for the file at corpus path `rel`, attributed to `repo` (the bare name
 * for gHashTag repositories, `owner/name` for any other owner), from its exact bytes and the
 * vendored compiler. Health is decided here so the page never has to compile a corpus to
 * colour a list.
 */
export function corpusEntry(rel, repo, text, analyze) {
  let a = null
  try { a = analyze(text) } catch { a = null }

  const kinds = kindsOf(a)
  const failedBackends = a ? Object.entries(a.targets).filter(([, v]) => !v.ok).map(([k]) => k) : []
  const loss = a ? a.discarded.length + a.swallowed.length + a.lexerDiscarded.length : 0
  const tcErrors = a?.typecheck?.errorCount ?? 0
  // Three states, worst-wins. "fail" means something refused to produce output
  // at all; "warn" means it produced output but the compiler flagged or dropped
  // something on the way.
  const health = !a || a.astError || failedBackends.length ? 'fail' : loss > 0 || tcErrors > 0 ? 'warn' : 'ok'

  const parts = rel.split('/')
  // Two segments, not one: with the corpus widened past specs/, a single
  // segment would lump all 497 specs under "specs" and all 147 chip specs
  // under "chips", throwing away the grouping that makes the list navigable.
  const category = parts.length > 2 ? `${parts[0]}/${parts[1]}` : parts.length > 1 ? parts[0] : 'root'
  // A spec's `module X {` line is a better label than its filename when the two
  // disagree, which they often do.
  const moduleMatch = text.match(/^\s*module\s+([A-Za-z0-9_-]+)/m)
  const entry = {
    path: rel,
    category,
    name: parts[parts.length - 1].replace(/\.t27$/, ''),
    module: moduleMatch ? moduleMatch[1] : null,
    lines: text.split('\n').length,
    bytes: Buffer.byteLength(text, 'utf8'),
    description: describe(text),
    health,
    tokens: a?.tokenCount ?? 0,
    nodes: a?.nodeCount ?? 0,
    depth: a?.astDepth ?? 0,
    loss,
    tcErrors,
    failedBackends,
    // Output size per backend, so the library can show what a spec actually
    // produces without re-running the compiler.
    outBytes: a ? Object.fromEntries(Object.entries(a.targets).map(([k, v]) => [k, v.ok ? v.bytes : null])) : {},
    repo,
    kinds,
  }
  entry.tags = deriveTags(rel, repo, kinds, entry)
  entry.summary = summarise(kinds, entry, health)
  return entry
}

/** The corpus-wide counts the manifest carries, from the entries in their manifest order. */
export function corpusAggregates(entries) {
  const byCategory = {}
  for (const e of entries) byCategory[e.category] = (byCategory[e.category] || 0) + 1
  const health = { ok: 0, warn: 0, fail: 0 }
  for (const e of entries) health[e.health]++
  const backendFailures = {}
  for (const e of entries) for (const b of e.failedBackends) backendFailures[b] = (backendFailures[b] || 0) + 1
  return {
    totalLines: entries.reduce((a, e) => a + e.lines, 0),
    categories: Object.fromEntries(Object.entries(byCategory).sort((a, b) => b[1] - a[1])),
    // Every tag with its count, so the UI can render facets without walking 760
    // entries on each keystroke.
    tags: Object.fromEntries(
      Object.entries(
        entries.reduce((acc, e) => {
          for (const t of e.tags) acc[t] = (acc[t] || 0) + 1
          return acc
        }, {}),
      ).sort((a, b) => (a[0] === b[0] ? 0 : b[1] - a[1] || a[0].localeCompare(b[0]))),
    ),
    health,
    backendFailures,
    totals: {
      tokens: entries.reduce((a, e) => a + e.tokens, 0),
      nodes: entries.reduce((a, e) => a + e.nodes, 0),
      lossAffected: entries.filter((e) => e.loss > 0).length,
      tcAffected: entries.filter((e) => e.tcErrors > 0).length,
    },
  }
}

/**
 * Language-audit exceptions.
 *
 * `qa/ru_audit.mjs` fails the build on any English sentence over 45 characters
 * that renders under ?lang=ru. That gate is right, and it should stay strict:
 * it exists to catch untranslated UI.
 *
 * Spec descriptions are not UI. They are comments quoted verbatim out of the
 * source files, in the language their authors wrote them in. Translating them
 * would misrepresent the files; hiding them would gut the page. So they are
 * registered as exceptions -- the same treatment the site already gives
 * bibliography entries and code samples.
 *
 * Generated rather than hand-maintained, so the list cannot drift from
 * what the page actually renders. Returns the number registered, or null when
 * the exceptions file does not exist.
 */
export function registerDescriptionExceptions(entries, excPath) {
  if (!existsSync(excPath)) return null
  const exc = JSON.parse(readFileSync(excPath, 'utf8'))
  exc.ru = exc.ru || {}
  const descs = [...new Set(entries.map((e) => e.description).filter(Boolean))]
  // Only the ones the audit would actually flag; anything shorter passes on
  // its own and does not belong in an exception list.
  exc.ru.specs = descs.filter((d) => d.length > 45).sort()
  writeFileSync(excPath, JSON.stringify(exc, null, 2) + '\n')
  return exc.ru.specs.length
}
