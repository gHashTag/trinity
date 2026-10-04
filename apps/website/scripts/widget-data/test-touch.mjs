#!/usr/bin/env node
// test-touch.mjs -- "Did the agent touch its own tests?" for every pull request merged on gHashTag/t27.
//
// Writes public/widgets/test-touch/data.json, which the widget reads; the page itself calls nobody.
// Every number on the page comes from this file, and this file comes from two read-only sources at
// the time stamped in `snapshotAt`:
//   1. `gh api graphql`: the merged pull requests of the window, with head branch, author, merge
//      commit and the changed-file list GitHub reports for each.
//   2. `git diff <merge>^1 <merge>` in a shallow bare clone of master (fetched read-only from
//      github.com into a cache directory): the patch each pull request landed, with the whole file as
//      context for .t27 files, so a line's test block is read from the file, not guessed from a hunk.
//      Every merged pull request on t27 is a two-parent merge commit, so <merge>^1..<merge> is exactly
//      what the pull request changed on master. The file list from git is checked against GitHub's.
//
// THE RULE lives in specs/widgets/test-touch.t27 (K_ constants, compiled with the real compiler); this
// script reads it from there. The classifier below is the heuristic the spec documents; the spec's
// fixture diffs are run through it on every invocation and any disagreement exits non-zero, and so does
// any disagreement between the counts computed here and the counts the spec states (K_SNAP_*).
//
// Usage:
//   node scripts/widget-data/test-touch.mjs              fetch, classify, write data.json, check spec
//   node scripts/widget-data/test-touch.mjs --check      no network: fixtures + data.json against spec
//   options: --days N (default K_WINDOW_DAYS), --git DIR (clone cache, default $TMPDIR/test-touch-t27.git),
//            --reuse (classify the previous run's pull-request list again; no GitHub call)
import { execFile, execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { constsOf, loadCompiler, verdictOf } from '../agents-from-specs.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const SPEC = join(SITE, 'specs/widgets/test-touch.t27')
const OUT = join(SITE, 'public/widgets/test-touch/data.json')
const WASM = join(SITE, 'public/t27/t27_compiler.wasm')

// ---------------------------------------------------------------------------------------------
// The spec, read through the compiler.
// ---------------------------------------------------------------------------------------------
export async function readSpec() {
  const analyze = await loadCompiler(readFileSync(WASM))
  const analysis = analyze(readFileSync(SPEC, 'utf8'))
  const v = verdictOf(analysis)
  if (!v.typecheckOk || v.discarded > 0) throw new Error(`test-touch: ${SPEC} does not compile cleanly (${JSON.stringify(v)})`)
  return Object.fromEntries(Object.entries(constsOf(analysis)).map(([k, x]) => [k, x.value]))
}

// ---------------------------------------------------------------------------------------------
// Which file is a test file, which line is a test line.
// ---------------------------------------------------------------------------------------------
/** 'test' (the whole file is a test), 't27' (tests are its blocks), 'code', or 'other' (prose, data). */
export function fileKind(path, rule) {
  const parts = path.split('/')
  const base = parts[parts.length - 1]
  if (rule.K_NOT_TEST_DIRS.includes(parts[0])) return 'other'
  if (parts.slice(0, -1).some((p) => rule.K_TEST_DIRS.includes(p))) return 'test'
  if (base.endsWith('.t27')) return 't27'
  if (base.includes(rule.K_TEST_NAME_MARK)) return 'test'
  if (/^test_.*\.py$/.test(base) || /\.(test|spec)\.(m?js|ts|tsx)$/.test(base)) return 'test'
  if (/\.(md|txt|rst|adoc|html|svg|png|jpe?g|gif|pdf|cast|lock|jsonl)$/i.test(base) || base === 'FROZEN_HASH') return 'other'
  return 'code'
}

const strip = (line) => line
  .replace(/"(?:[^"\\]|\\.)*"/g, '""')
  .replace(/'(?:[^'\\]|\\.)'/g, "''")
  .replace(/\/\*.*?\*\//g, '')
  .replace(/\/\/.*$/, '')
const isComment = (line) => /^\s*(;|\/\/|#(?!\[)|\/\*|\*)/.test(line)
const braces = (line) => {
  const s = isComment(line) ? '' : strip(line)
  return (s.match(/\{/g) || []).length - (s.match(/\}/g) || []).length
}
const indentOf = (line) => line.match(/^\s*/)[0].replace(/\t/g, '    ').length

/**
 * Marks every line of a .t27 file with the test block it sits in, or null. Three block shapes are in
 * the corpus: `test name {` ... `}` (braces counted outside strings and comments), `test name` with an
 * indented body and no braces, and the one-line `invariant name: expr`. The header may be indented
 * and the name may be quoted.
 */
export function t27Blocks(lines, words) {
  const head = new RegExp(`^(\\s*)(?:pub\\s+)?(${words.join('|')})\\s+("[^"]*"|[A-Za-z_][\\w:.]*)\\s*(.*)$`)
  const out = new Array(lines.length).fill(null)
  let st = null
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (st?.mode === 'brace') {
      out[i] = st.block
      st.depth += braces(line)
      if (st.depth <= 0) st = null
      continue
    }
    if (st?.mode === 'indent') {
      if (!line.trim() || isComment(line) && indentOf(line) > st.indent) { out[i] = st.block; continue }
      if (!st.body && line.trim().startsWith('{') && indentOf(line) === st.indent) {
        out[i] = st.block
        st = { mode: 'brace', block: st.block, depth: braces(line) }
        if (st.depth <= 0) st = null
        continue
      }
      if (indentOf(line) > st.indent) { out[i] = st.block; st.body = true; continue }
      st = null
    }
    const m = head.exec(line)
    if (!m) continue
    const block = { kind: m[2], name: m[3].replace(/"/g, ''), line: i }
    out[i] = block
    const rest = strip(m[4])
    if (rest.includes('{')) {
      const depth = braces(line)
      if (depth > 0) st = { mode: 'brace', block, depth }
    } else if (/^:\s*\S/.test(m[4])) {
      block.oneLine = true
    } else {
      st = { mode: 'indent', block, indent: m[1].replace(/\t/g, '    ').length, body: false }
    }
  }
  return out
}

/** A check is a line that asserts something; its subject is what it asserts about. */
const CHECK = {
  t27: /\bassert\b|@compileAssert\s*\(|__t27_assert_fail|^\s*(and\s+)?then\b|^\s*expect\b|\bexpect\s*\(|^\s*invariant\s+[^{:]*?(==|!=|<=|>=|<|>)/,
  rs: /\b(debug_)?assert(_eq|_ne)?!\s*\(|#\[should_panic/,
  py: /^\s*assert\b|\bself\.assert\w*\(|\bpytest\.raises\(/,
  js: /\bassert(\.\w+)?\s*\(|\bexpect\s*\(/,
  data: /^\s*"[^"]+"\s*:\s*[^\s[{]/,
}
// A data value that is a sentence (contains a space) is a note, not an expected value.
const PROSE = /^\s*"[^"]+"\s*:\s*"[^"]*\s[^"]*",?\s*$/
const HEADER = { rs: /^\s*#\[test\]/, py: /^\s*def\s+test_?\w*\s*\(/, js: /^\s*(it|test)\s*\(/ }
// Inside an invariant a line without assert is a check only when it compares; continuation lines are not.
const INV_CHECK = /==|!=|<=|>=|\s<\s|\s>\s|\bimplies\b/
const SETUP = /^\s*(forall|exists|given|when|const|let|var|and\s+(?!then))\b/
const langOf = (path) => (/\.t27$/.test(path) ? 't27' : /\.rs$/.test(path) ? 'rs' : /\.py$/.test(path) ? 'py' : /\.(m?js|ts|tsx)$/.test(path) ? 'js' : /\.(json|ya?ml|toml|csv|hex)$/.test(path) ? 'data' : null)

const LOOSER = { '==': ['>=', '<=', '!=', '<', '>'], '<': ['<='], '>': ['>='], '<=': ['!='], '>=': ['!='] }
const OPS = ['==', '!=', '>=', '<=', '<', '>']

/** Splits a check into subject, operator and expected value; subject alone when there is no comparison. */
export function parseCheck(text, lang) {
  let s = text.trim().replace(/;\s*$/, '').replace(/,\s*$/, '')
  if (lang === 'data') {
    const m = /^"([^"]+)"\s*:\s*(.*)$/.exec(s)
    return m ? cmp(`"${m[1]}"`, '==', m[2].trim()) : cmp(s, null, null)
  }
  const gen = /^if\s*\(\s*!\s*\((.*)\)\s*\)\s*__t27_assert_fail\b/.exec(s)
  if (gen) s = gen[1]
  s = s.replace(/^(and\s+)?then\s+/, '').replace(/^expect\s+/, '').replace(/^invariant\s+/, '')
    .replace(/^try\s+/, '').replace(/^(std\.testing\.)?expect\s*(?=\()/, '').replace(/^@compileAssert\s*(?=\()/, '')
  const eq = /^(?:debug_)?assert_(eq|ne)!\s*\((.*)\)$/.exec(s)
  if (eq) {
    const parts = splitTop(eq[2], ',')
    if (parts.length >= 2) return cmp(norm(parts[0]), eq[1] === 'eq' ? '==' : '!=', norm(parts[1]))
  }
  s = s.replace(/^(?:debug_)?assert!?\s*/, '').replace(/^self\.assert\w*\s*/, '')
  while (/^\(.*\)$/.test(s) && balanced(s.slice(1, -1))) s = s.slice(1, -1).trim()
  if (lang === 'py' || lang === 'rs') s = splitTop(s, ',')[0]
  s = norm(s).replace(/\s*==\s*true$/, '')
  const f = /^(.+?)\s*==\s*false$/.exec(s)
  if (f && !topOp(f[1])) s = /^[\w.]+$/.test(f[1]) ? `!${f[1]}` : `!(${f[1]})`
  const all = s
  const conj = splitWords(s, ['and', '&&']), disj = splitWords(s, ['or', '||'])
  const at = topOp(s)
  if (!at) return { subject: s, op: null, rhs: null, all, conj, disj }
  return { subject: norm(s.slice(0, at.i)), op: at.op, rhs: norm(s.slice(at.i + at.op.length)), all, conj, disj }
}
/** Top-level split on boolean words, normalized; one element when there is none. */
function splitWords(s, words) {
  const marks = words.map((w) => (/^\w+$/.test(w) ? ` ${w} ` : w))
  const out = []
  let d = 0, q = null, start = 0
  for (let i = 0; i < s.length; i++) {
    const c = s[i]
    if (q) { if (c === '\\') i++; else if (c === q) q = null; continue }
    if (c === '"' || c === "'") { q = c; continue }
    if ('([{'.includes(c)) { d++; continue }
    if (')]}'.includes(c)) { d--; continue }
    if (d !== 0) continue
    const m = marks.find((w) => s.startsWith(w, i))
    if (m) { out.push(norm(s.slice(start, i))); start = i + m.length; i += m.length - 1 }
  }
  out.push(norm(s.slice(start)))
  return out.map((x) => { while (/^\(.*\)$/.test(x) && balanced(x.slice(1, -1))) x = x.slice(1, -1).trim(); return x })
}
const cmp = (subject, op, rhs) => {
  const all = op ? `${subject} ${op} ${rhs}` : subject
  return { subject, op, rhs, all, conj: [all], disj: [all] }
}
const negBase = (subject) => subject.replace(/^(!|not\s+)\s*/, '').replace(/^\((.*)\)$/, '$1')
const negated = (subject) => /^(!|not\s)/.test(subject)
const strictSubset = (a = [], b = []) => a.length > 0 && a.length < b.length && a.every((x) => b.includes(x))
const norm = (s) => s.trim().replace(/\s+/g, ' ')
function balanced(s) {
  let d = 0
  for (const c of strip(s)) { if ('([{'.includes(c)) d++; else if (')]}'.includes(c) && --d < 0) return false }
  return d === 0
}
function splitTop(s, sep) {
  const out = []
  let d = 0, q = null, start = 0
  for (let i = 0; i < s.length; i++) {
    const c = s[i]
    if (q) { if (c === '\\') i++; else if (c === q) q = null; continue }
    if (c === '"' || c === "'") q = c
    else if ('([{'.includes(c)) d++
    else if (')]}'.includes(c)) d--
    else if (c === sep && d === 0) { out.push(s.slice(start, i)); start = i + 1 }
  }
  out.push(s.slice(start))
  return out
}
function topOp(s) {
  let d = 0, q = null
  for (let i = 0; i < s.length; i++) {
    const c = s[i]
    if (q) { if (c === '\\') i++; else if (c === q) q = null; continue }
    if (c === '"' || c === "'") { q = c; continue }
    if ('([{'.includes(c)) { d++; continue }
    if (')]}'.includes(c)) { d--; continue }
    if (d !== 0) continue
    for (const op of OPS) {
      if (s.startsWith(op, i)) {
        const prev = s[i - 1], next = s[i + op.length]
        if (op.length === 1 && (prev === '-' || prev === '=' || prev === '<' || prev === '>' || next === '<' || next === '>' || next === '=')) break
        if ((op === '<' || op === '>') && !(prev === ' ' && next === ' ')) break
        return { i, op }
      }
    }
  }
  return null
}
/** A check that cannot fail: assert true, x == x, x == a or x != a, b == true or b == false, n.len >= 0. */
export function trivial(p) {
  if (!p || !p.subject) return false
  if (/^(true|1)$/.test(p.subject) && !p.op) return true
  if (p.op === '==' && p.subject === p.rhs) return true
  if (/\.len(\(\))?\s*>=\s*0$/.test(p.all ?? '')) return true
  const d = p.disj ?? []
  if (d.length > 1) {
    for (const x of d) {
      const m = /^(.+?)\s*==\s*(.+)$/.exec(x)
      if (!m) continue
      if (d.includes(`${m[1]} != ${m[2]}`)) return true
      if (m[2] === 'true' && d.includes(`${m[1]} == false`)) return true
      if (m[2] === 'false' && d.includes(`${m[1]} == true`)) return true
      if (/^(null|None|undefined)$/.test(m[2]) && d.some((y) => y.startsWith(`${m[1]}.len >= 0`) || y === `${m[1]} != ${m[2]}`)) return true
    }
  }
  return false
}

// ---------------------------------------------------------------------------------------------
// One file's patch.
// ---------------------------------------------------------------------------------------------
/**
 * Classifies the changed lines of one file. `body` is the unified diff body (hunk headers and lines);
 * for a .t27 file it should carry the whole file as context. Returns the test lines as items:
 * { sign, text, lang, check, header, group, block } and the counts of code and other lines.
 */
export function classifyFile(path, body, rule, kindOverride) {
  const kind = kindOverride ?? fileKind(path, rule)
  const lang = langOf(path)
  const res = { path, kind, testAdded: 0, testRemoved: 0, codeAdded: 0, codeRemoved: 0, otherAdded: 0, otherRemoved: 0, assertsOutside: 0, items: [] }
  const rows = []
  let group = 0, inGroup = false
  for (const raw of body) {
    if (raw.startsWith('@@')) { inGroup = false; continue }
    if (raw.startsWith('\\')) continue
    const sign = raw[0], text = raw.slice(1)
    if (sign !== '+' && sign !== '-' && sign !== ' ') continue
    if (sign === ' ') inGroup = false
    else if (!inGroup) { group++; inGroup = true }
    rows.push({ sign, text, group: sign === ' ' ? 0 : group })
  }
  let blockOf = () => null
  if (kind === 't27' || lang === 't27') {
    const oldSide = rows.filter((r) => r.sign !== '+'), newSide = rows.filter((r) => r.sign !== '-')
    const ob = t27Blocks(oldSide.map((r) => r.text), rule.K_TEST_BLOCK_WORDS)
    const nb = t27Blocks(newSide.map((r) => r.text), rule.K_TEST_BLOCK_WORDS)
    const map = new Map()
    oldSide.forEach((r, i) => { if (r.sign === '-') map.set(r, ob[i]) })
    newSide.forEach((r, i) => { if (r.sign === '+') map.set(r, nb[i]) })
    blockOf = (r) => map.get(r) ?? null
  }
  for (const r of rows) {
    if (r.sign === ' ' || !r.text.trim()) continue
    const block = kind === 't27' || (kind === 'test' && lang === 't27') ? blockOf(r) : null
    const isTest = kind === 'test' || (kind === 't27' && block)
    if (!isTest) {
      if (kind === 'other') r.sign === '+' ? res.otherAdded++ : res.otherRemoved++
      else {
        r.sign === '+' ? res.codeAdded++ : res.codeRemoved++
        if (lang && lang !== 'data' && CHECK[lang].test(isComment(r.text) ? '' : strip(r.text))) res.assertsOutside++
      }
      continue
    }
    r.sign === '+' ? res.testAdded++ : res.testRemoved++
    const code = isComment(r.text) ? '' : strip(r.text)
    let header = false, check = false
    if (lang === 't27' && block) {
      header = block.line != null && r.text.trim().length > 0 && new RegExp(`^\\s*(?:pub\\s+)?${block.kind}\\b`).test(r.text) && !block.oneLine
      check = !header && code !== '' && (CHECK.t27.test(code) || (block.kind === 'invariant' && !SETUP.test(code) && INV_CHECK.test(code)))
      if (block.oneLine && new RegExp(`^\\s*(?:pub\\s+)?${block.kind}\\b`).test(r.text)) check = true
    } else if (lang && lang !== 't27') {
      header = HEADER[lang]?.test(r.text) ?? false
      check = !header && (lang === 'data' ? CHECK.data.test(r.text) && !PROSE.test(r.text) : CHECK[lang].test(code))
    }
    const item = { sign: r.sign, text: r.text.replace(/\s+$/, ''), group: r.group, header, check, lang: lang ?? 'other' }
    if (block) item.block = `${block.kind} ${block.name}`
    if (check) {
      let t = r.text
      if (block?.oneLine && header === false && /^\s*(?:pub\s+)?(invariant|test|bench)\b/.test(t)) t = t.replace(/^\s*(?:pub\s+)?\w+\s+("[^"]*"|[\w:.]+)\s*:\s*/, '')
      item.parsed = parseCheck(lang === 'data' ? t : strip(t), lang)
    }
    res.items.push(item)
  }
  return res
}

// ---------------------------------------------------------------------------------------------
// One pull request: pair what was removed with what was added, then give it a badge.
// ---------------------------------------------------------------------------------------------
const key = (s) => s.trim().replace(/\s+/g, ' ').replace(/;$/, '')

/**
 * Pairs removed and added check and header items across a pull request:
 *   moved      the same line (whitespace aside) was removed and added: not a change, not shown
 *   expect     same subject and operator, different expected value
 *   loosened   same subject, operator relaxed (== to >=, < to <=, ...)
 *   tightened  same subject, operator made stricter
 *   rewritten  a removed and an added check (or header) in the same change group, subjects differ
 *   trivial    rewritten into a check that cannot fail (assert true, x == x)
 *   removed    a check or a test header gone with nothing in its place
 *   added      a new check or test header
 */
export function pairItems(files) {
  const all = files.flatMap((f, fi) => f.items.map((it) => ({ ...it, file: fi, path: f.path })))
  const R = all.filter((x) => x.sign === '-' && (x.check || x.header))
  const A = all.filter((x) => x.sign === '+' && (x.check || x.header))
  const used = new Set()
  const take = (r, a, tag) => { used.add(r); used.add(a); r.tag = tag; a.tag = tag; a.pair = r }
  for (const r of R) {
    const a = A.find((x) => !used.has(x) && x.header === r.header && key(x.text) === key(r.text))
    if (a) take(r, a, 'moved')
  }
  const bySubject = (scope) => {
    for (const r of R) {
      if (used.has(r) || !r.check || !r.parsed?.subject) continue
      const base = negBase(r.parsed.subject)
      const a = A.find((x) => !used.has(x) && x.check && x.parsed?.subject === r.parsed.subject && scope(r, x)) ??
        A.find((x) => !used.has(x) && x.check && x.parsed && negBase(x.parsed.subject) === base && scope(r, x))
      if (!a) continue
      take(r, a, judge(r.parsed, a.parsed))
    }
  }
  // A test header whose block name survives was rewritten in place, whatever its group.
  for (const r of R) {
    if (used.has(r) || !r.header || !r.block) continue
    const a = A.find((x) => !used.has(x) && x.header && x.file === r.file && x.block === r.block)
    if (a) take(r, a, 'rewritten')
  }
  bySubject((r, a) => r.file === a.file && r.group === a.group)
  bySubject((r, a) => r.file === a.file && r.block && r.block === a.block)
  bySubject((r, a) => r.file === a.file && r.lang !== 'data')
  bySubject((r, a) => r.lang !== 'data' && a.lang !== 'data')
  for (const r of R) {
    if (used.has(r)) continue
    const a = A.find((x) => !used.has(x) && x.file === r.file && x.group === r.group && x.header === r.header)
    if (!a) continue
    take(r, a, r.check && trivial(a.parsed ?? {}) && !trivial(r.parsed ?? {}) ? 'trivial' : 'rewritten')
  }
  for (const r of R) if (!used.has(r)) r.tag = 'removed'
  for (const a of A) if (!used.has(a)) a.tag = 'added'
  return all
}

/** What happened to a check whose subject survived: removed p, added q. */
export function judge(p, q) {
  if (trivial(q) && !trivial(p)) return 'trivial'
  if (trivial(p) && !trivial(q)) return 'tightened'
  if (negated(p.subject) !== negated(q.subject)) return 'expect'
  if (strictSubset(q.conj, p.conj) || strictSubset(p.disj, q.disj)) return 'loosened'
  if (strictSubset(p.conj, q.conj) || strictSubset(q.disj, p.disj)) return 'tightened'
  if (p.op && q.op && p.op === q.op) return p.rhs === q.rhs ? 'rewritten' : 'expect'
  if (p.op && q.op && LOOSER[p.op]?.includes(q.op)) return 'loosened'
  if (p.op && q.op && LOOSER[q.op]?.includes(p.op)) return 'tightened'
  if (p.op && !q.op) return 'loosened'
  return 'rewritten'
}

/** Badge index into K_BADGES: 0 untouched, 1 added, 2 changed, 3 removed (or weakened). */
export function summarize(files) {
  const items = pairItems(files)
  const n = (pred) => items.filter(pred).length
  const counts = {
    testAdded: files.reduce((s, f) => s + f.testAdded, 0),
    testRemoved: files.reduce((s, f) => s + f.testRemoved, 0),
    codeLines: files.reduce((s, f) => s + f.codeAdded + f.codeRemoved, 0),
    otherLines: files.reduce((s, f) => s + f.otherAdded + f.otherRemoved, 0),
    checksAdded: n((x) => x.sign === '+' && x.check && x.tag === 'added'),
    checksRemoved: n((x) => x.sign === '-' && x.check && x.tag === 'removed'),
    testsRemoved: n((x) => x.sign === '-' && x.header && x.tag === 'removed'),
    expect: n((x) => x.sign === '-' && x.tag === 'expect'),
    loosened: n((x) => x.sign === '-' && (x.tag === 'loosened' || x.tag === 'trivial')),
    rewritten: n((x) => x.sign === '-' && (x.tag === 'rewritten' || x.tag === 'tightened')),
    assertsOutside: files.reduce((s, f) => s + f.assertsOutside, 0),
  }
  // Removed test lines that are not part of a moved pair (comments, setup lines inside a test).
  const movedMinus = n((x) => x.sign === '-' && x.tag === 'moved')
  const movedPlus = n((x) => x.sign === '+' && x.tag === 'moved')
  const realRemoved = counts.testRemoved - movedMinus
  const realAdded = counts.testAdded - movedPlus
  let badge = 0
  if (counts.checksRemoved > 0 || counts.testsRemoved > 0 || counts.loosened > 0) badge = 3
  else if (realRemoved > 0) badge = 2
  else if (realAdded > 0) badge = 1
  const touchedTests = counts.testAdded + counts.testRemoved > 0
  const cls = touchedTests && counts.codeLines > 0 ? 2 : touchedTests ? 1 : counts.codeLines > 0 ? 0 : 3
  return { badge, cls, counts, items }
}

// ---------------------------------------------------------------------------------------------
// Fixtures from the spec: the classifier must give exactly the numbers the spec states.
// ---------------------------------------------------------------------------------------------
/** The vector K_FIX_<n>_WANT is checked against: [badge, class, checksAdded, checksRemoved, expect, loosened, testAdded, testRemoved, codeLines]. */
export const fixtureVector = (s) => [s.badge, s.cls, s.counts.checksAdded, s.counts.checksRemoved, s.counts.expect, s.counts.loosened, s.counts.testAdded, s.counts.testRemoved, s.counts.codeLines]

export function runFixtures(spec) {
  const problems = []
  const results = []
  for (let i = 0; i < spec.K_FIX_COUNT; i++) {
    const path = spec[`SAY_FIX_${i}_PATH`]
    const body = spec[`SAY_FIX_${i}_DIFF`]
    const want = spec[`K_FIX_${i}_WANT`]
    if (typeof path !== 'string' || !Array.isArray(body) || !Array.isArray(want)) { problems.push(`fixture ${i}: SAY_FIX_${i}_PATH, SAY_FIX_${i}_DIFF or K_FIX_${i}_WANT missing from the spec`); continue }
    const got = fixtureVector(summarize([classifyFile(path, body, spec)]))
    results.push({ i, path, want, got })
    if (JSON.stringify(got) !== JSON.stringify(want)) problems.push(`fixture ${i} (${path}): spec wants [${want}], classifier gives [${got}]`)
  }
  return { problems, results }
}

// ---------------------------------------------------------------------------------------------
// Counts against the spec.
// ---------------------------------------------------------------------------------------------
/** [prs, untouched, added, changed, removed, code-only, tests-only, both, neither, expect-PRs, loosened-PRs] for one lane. */
export function laneVector(rows) {
  const b = (i) => rows.filter((r) => r.badge === i).length
  const c = (i) => rows.filter((r) => r.cls === i).length
  return [rows.length, b(0), b(1), b(2), b(3), c(0), c(1), c(2), c(3), rows.filter((r) => r.counts.expect > 0).length, rows.filter((r) => r.counts.loosened > 0).length]
}

export function checkCounts(spec, data) {
  const problems = []
  for (const lane of spec.K_LANES) {
    const got = laneVector(data.prs.filter((r) => r.lane === lane))
    const name = `K_SNAP_${lane.toUpperCase()}`
    const want = spec[name]
    if (JSON.stringify(got) !== JSON.stringify(want)) problems.push(`${name}: spec says [${want}], data.json gives [${got}]`)
    if (JSON.stringify(got) !== JSON.stringify(data.lanes[lane].vector)) problems.push(`${lane}: data.json lanes.${lane}.vector [${data.lanes[lane].vector}] disagrees with its own rows [${got}]`)
  }
  if (spec.K_SNAP_DATE !== data.snapshotAt.slice(0, 10)) problems.push(`K_SNAP_DATE: spec says ${spec.K_SNAP_DATE}, data.json was taken ${data.snapshotAt.slice(0, 10)}`)
  if (spec.K_WINDOW_DAYS !== data.days) problems.push(`K_WINDOW_DAYS: spec says ${spec.K_WINDOW_DAYS}, data.json covers ${data.days} days`)
  return problems
}

// ---------------------------------------------------------------------------------------------
// Fetching.
// ---------------------------------------------------------------------------------------------
const gh = (args) => JSON.parse(execFileSync('gh', args, { encoding: 'utf8', timeout: 180000, maxBuffer: 256 * 1024 * 1024 }))
const graphql = (query, vars) => gh(['api', 'graphql', '-f', `query=${query}`, ...Object.entries(vars).flatMap(([k, v]) => ['-F', `${k}=${v}`])]).data
const PUNCT = { '\u2014': '--', '\u2013': '-', '\u2192': '->', '\u2190': '<-', '\u00b2': '^2', '\u00b3': '^3', '\u2018': "'", '\u2019': "'", '\u201c': '"', '\u201d': '"', '\u2026': '...', '\u00d7': 'x', '\u2264': '<=', '\u2265': '>=', '\u2260': '!=', '\u03c6': 'phi', '\u00b7': '.', '\u2550': '=', '\u2500': '-' }
const ascii = (s) => String(s).replace(/[^\x20-\x7e]/g, (c) => PUNCT[c] ?? '?')
/** A title in another script is not shown as question marks; the page says it is not in English. */
const titleOf = (s) => { const t = ascii(s); return (t.match(/\?/g) || []).length > t.length / 4 ? '' : t.slice(0, 120) }
const run = (cmd, args, opts = {}) => new Promise((res, rej) => execFile(cmd, args, { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024, ...opts }, (e, out) => (e ? rej(e) : res(out))))

function mergedPrs(repo, sinceIso, untilIso) {
  const seen = new Map()
  for (let t = Date.parse(sinceIso.slice(0, 10)); t <= Date.parse(untilIso); t += 86400000) {
    const day = new Date(t).toISOString().slice(0, 10)
    let after = null
    for (;;) {
      const q = `repo:${repo} is:pr is:merged merged:${day}..${day}`
      const d = graphql(`query($q: String!, $after: String) { search(query: $q, type: ISSUE, first: 50, after: $after) {
        pageInfo { hasNextPage endCursor } nodes { ... on PullRequest { number title url headRefName baseRefName mergedAt author { login }
        mergeCommit { oid } files(first: 100) { totalCount pageInfo { hasNextPage endCursor } nodes { path } } } } } }`, after ? { q, after } : { q })
      for (const pr of d.search.nodes) if (Date.parse(pr.mergedAt) >= Date.parse(sinceIso)) seen.set(pr.number, pr)
      if (!d.search.pageInfo.hasNextPage) break
      after = d.search.pageInfo.endCursor
    }
  }
  const [owner, name] = repo.split('/')
  for (const pr of seen.values()) {
    let page = pr.files
    pr.paths = page.nodes.map((f) => f.path)
    while (page.pageInfo.hasNextPage) {
      page = graphql(`query($o: String!, $n: String!, $num: Int!, $after: String) { repository(owner: $o, name: $n) { pullRequest(number: $num) {
        files(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { path } } } } }`, { o: owner, n: name, num: pr.number, after: page.pageInfo.endCursor }).repository.pullRequest.files
      pr.paths.push(...page.nodes.map((f) => f.path))
    }
  }
  return [...seen.values()]
}

async function ensureClone(dir, repo, sinceIso) {
  const shallow = new Date(Date.parse(sinceIso) - 4 * 86400000).toISOString().slice(0, 10)
  if (!existsSync(dir)) {
    execFileSync('git', ['clone', '-q', '--bare', '--single-branch', '--branch', 'master', `--shallow-since=${shallow}`, `https://github.com/${repo}.git`, dir], { stdio: 'inherit' })
  } else {
    // Deepening a shallow clone with --shallow-since fails ("error in object: unshallow"); a plain
    // fetch brings the new commits, and needParents below deepens when a merge's parent is missing.
    execFileSync('git', ['-C', dir, 'fetch', '-q', 'origin', '+master:master'], { stdio: 'inherit' })
  }
}

function needParents(dir, oids) {
  for (let round = 0; round < 6; round++) {
    const missing = oids.filter((o) => { try { execFileSync('git', ['-C', dir, 'cat-file', '-e', `${o}^1^{commit}`], { stdio: 'ignore' }); return false } catch { return true } })
    if (!missing.length) return
    execFileSync('git', ['-C', dir, 'fetch', '-q', '--deepen=200', 'origin', '+master:master'], { stdio: 'inherit' })
  }
  throw new Error('test-touch: merge commits or their first parents are missing from the clone')
}

/** The path on a ---/+++ line: git appends a tab to a path with a space and C-quotes one with a quote. */
function diffPath(line) {
  let x = line.slice(4).replace(/\t$/, '')
  if (x.startsWith('"')) x = JSON.parse(x.replace(/\\([0-7]{3})/g, (_, o) => `\\u00${parseInt(o, 8).toString(16).padStart(2, '0')}`))
  return x.slice(2)
}

/** Splits `git diff` output into { path, status, body[] } per file. */
export function splitDiff(text) {
  const files = []
  let cur = null
  for (const line of text.split('\n')) {
    if (line.startsWith('diff --git ')) {
      const m = /^diff --git a\/(.*) b\/(.*)$/.exec(line)
      cur = { path: m ? m[2] : line, status: 'M', body: [], binary: false }
      files.push(cur)
      continue
    }
    if (!cur) continue
    if (!cur.inBody) {
      if (line.startsWith('new file mode')) cur.status = 'A'
      else if (line.startsWith('deleted file mode')) cur.status = 'D'
      else if (line.startsWith('rename to ')) { cur.status = 'R'; cur.path = line.slice(10) }
      else if (line.startsWith('rename from ')) cur.from = line.slice(12)
      else if (line.startsWith('Binary files')) cur.binary = true
      else if (line.startsWith('--- ')) { if (line !== '--- /dev/null') cur.path = diffPath(line) }
      else if (line.startsWith('+++ ')) { if (line !== '+++ /dev/null') cur.path = diffPath(line) }
      else if (line.startsWith('@@')) { cur.inBody = true; cur.body.push(line) }
      continue
    }
    cur.body.push(line)
  }
  for (const f of files) delete f.inBody
  return files
}

async function prDiff(dir, merge) {
  const base = ['-C', dir, '-c', 'core.quotepath=false', 'diff', '--no-color', '--no-ext-diff', '-M']
  const [t27, rest] = await Promise.all([
    run('git', [...base, '-U1000000', `${merge}^1`, merge, '--', '*.t27']),
    run('git', [...base, '-U0', `${merge}^1`, merge, '--', '.', ':(exclude)*.t27']),
  ])
  return [...splitDiff(t27), ...splitDiff(rest)]
}

async function pool(items, n, fn) {
  const out = new Array(items.length)
  let next = 0, done = 0
  await Promise.all(Array.from({ length: n }, async () => {
    while (next < items.length) {
      const i = next++
      out[i] = await fn(items[i])
      if (++done % 25 === 0) process.stderr.write(`test-touch: ${done}/${items.length} diffs\n`)
    }
  }))
  return out
}

// Lines kept per pull request in data.json, by badge: the rest are counted ("+N more") and linked.
const LINES_KEPT = [0, 6, 16, 30]
const SHOWN = { removed: 0, trivial: 0, loosened: 1, expect: 2, rewritten: 3, tightened: 3, added: 5 }

async function collect(spec, { days, gitDir, reuse }) {
  const repo = spec.K_REPO
  // --reuse classifies the pull-request list of the previous run again (same snapshot time), so a
  // change to the classifier does not move the window; the list is cached beside the clone.
  const cache = join(gitDir, 'test-touch-prs.json')
  let snapshotAt, since, prs
  if (reuse && existsSync(cache)) {
    ({ snapshotAt, since, prs } = JSON.parse(readFileSync(cache, 'utf8')))
  } else {
    snapshotAt = new Date().toISOString().replace(/\.\d+Z$/, 'Z')
    since = new Date(Date.parse(snapshotAt) - days * 86400000).toISOString().replace(/\.\d+Z$/, 'Z')
    prs = mergedPrs(repo, since, snapshotAt)
    await ensureClone(gitDir, repo, since)
    writeFileSync(cache, JSON.stringify({ snapshotAt, since, prs }))
  }
  const onMaster = prs.filter((p) => p.baseRefName === 'master' && p.mergeCommit?.oid)
  needParents(gitDir, onMaster.map((p) => p.mergeCommit.oid))
  const beeRe = new RegExp(`^${spec.K_BEE_BRANCH_PREFIX}\\d+$`)
  const rows = await pool(onMaster, 8, async (pr) => {
    const diff = await prDiff(gitDir, pr.mergeCommit.oid)
    const files = []
    for (const f of diff.filter((x) => !x.binary)) {
      // A JSON file under a test directory that names the tool which wrote it is a measurement
      // record, regenerated on every run, not an expected value someone chose.
      let override
      if (fileKind(f.path, spec) === 'test' && /\.json$/.test(f.path)) {
        const rev = f.status === 'D' ? `${pr.mergeCommit.oid}^1` : pr.mergeCommit.oid
        const head = await run('git', ['-C', gitDir, 'cat-file', '-p', `${rev}:${f.status === 'D' ? f.path : f.path}`]).catch(() => '')
        if (head.slice(0, 4096).includes(`"${spec.K_GENERATED_KEY}"`)) override = 'other'
      }
      files.push(classifyFile(f.path, f.body, spec, override))
    }
    const s = summarize(files)
    const gitPaths = new Set(diff.flatMap((f) => [f.path, f.from].filter(Boolean)))
    const apiOnly = pr.paths.filter((p) => !gitPaths.has(p))
    const shown = s.items.filter((x) => x.tag !== 'moved' && (x.check || x.header || x.sign === '-'))
      .sort((a, b) => (SHOWN[a.tag] ?? 4) - (SHOWN[b.tag] ?? 4))
    const keep = LINES_KEPT[s.badge]
    const testFiles = files.filter((f) => f.testAdded + f.testRemoved > 0)
    const lines = shown.slice(0, keep).map((x) => ({ f: testFiles.findIndex((f) => f.path === x.path), s: x.sign, t: ascii(x.text).slice(0, 160), g: x.tag ?? 'line', ...(x.block ? { b: ascii(x.block).slice(0, 80) } : {}) }))
    return {
      n: pr.number, url: pr.url, title: titleOf(pr.title), lane: beeRe.test(pr.headRefName) ? 'bee' : 'human',
      branch: ascii(pr.headRefName), author: pr.author?.login ?? 'ghost', merged: pr.mergedAt,
      badge: s.badge, cls: s.cls, counts: s.counts,
      files: testFiles.map((f) => ({ p: f.path, k: f.kind, a: f.testAdded, d: f.testRemoved })),
      testFiles: testFiles.length, allFiles: files.length,
      lines, more: Math.max(0, shown.length - keep), apiOnly: apiOnly.length,
      ciGate: diff.some((f) => /^\.github\/workflows\//.test(f.path) || /suite_expectations\.json$/.test(f.path)),
    }
  })
  rows.sort((a, b) => Date.parse(b.merged) - Date.parse(a.merged))
  const lanes = {}
  for (const lane of spec.K_LANES) {
    const L = rows.filter((r) => r.lane === lane)
    const sum = (k) => L.reduce((s, r) => s + r.counts[k], 0)
    lanes[lane] = {
      vector: laneVector(L),
      checksAdded: sum('checksAdded'), checksRemoved: sum('checksRemoved'), testsRemoved: sum('testsRemoved'),
      expect: sum('expect'), loosened: sum('loosened'),
      ciGatePrs: L.filter((r) => r.ciGate).length,
      assertsOutsidePrs: L.filter((r) => r.counts.assertsOutside > 0).length,
      authors: [...new Set(L.map((r) => r.author))].sort(),
    }
  }
  return {
    snapshotAt, since, days, repo,
    rule: { bee: `head branch ^${spec.K_BEE_BRANCH_PREFIX}<N>$`, human: 'any other head branch', diff: 'git diff <merge>^1 <merge>, whole file as context for .t27' },
    excluded: { notMaster: prs.length - onMaster.length, apiFileListMismatch: rows.filter((r) => r.apiOnly > 0).length },
    lanes, prs: rows,
  }
}

// ---------------------------------------------------------------------------------------------
async function main() {
  const spec = await readSpec()
  const fx = runFixtures(spec)
  for (const r of fx.results) console.log(`test-touch: fixture ${r.i} ${r.path}: [${r.got}]${JSON.stringify(r.got) === JSON.stringify(r.want) ? ' as the spec says' : ` (spec: [${r.want}])`}`)
  if (fx.problems.length) { for (const p of fx.problems) console.error('test-touch: ' + p); process.exit(1) }

  const arg = (name) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : undefined }
  let data
  if (process.argv.includes('--check')) {
    data = JSON.parse(readFileSync(OUT, 'utf8'))
  } else {
    const days = Number(arg('--days') ?? spec.K_WINDOW_DAYS)
    const gitDir = arg('--git') ?? join(tmpdir(), 'test-touch-t27.git')
    data = await collect(spec, { days, gitDir, reuse: process.argv.includes('--reuse') })
    mkdirSync(dirname(OUT), { recursive: true })
    writeFileSync(OUT, JSON.stringify(data) + '\n')
    console.log(`test-touch: wrote ${OUT} (${data.prs.length} PRs, ${Buffer.byteLength(JSON.stringify(data))} bytes)`)
  }
  for (const lane of spec.K_LANES) {
    const L = data.lanes[lane]
    console.log(`test-touch: ${lane} [${L.vector}] checks +${L.checksAdded} -${L.checksRemoved}, tests removed ${L.testsRemoved}, expected values changed ${L.expect}, loosened ${L.loosened}`)
  }
  const problems = checkCounts(spec, data)
  if (problems.length) {
    for (const p of problems) console.error('test-touch: ' + p)
    console.error(`test-touch: the spec and the snapshot disagree. If the snapshot is right, set in ${SPEC}:`)
    for (const lane of spec.K_LANES) console.error(`  pub const K_SNAP_${lane.toUpperCase()} : [11]u16 = [${data.lanes[lane].vector.join(', ')}];`)
    console.error(`  pub const K_SNAP_DATE : str = "${data.snapshotAt.slice(0, 10)}";`)
    process.exit(1)
  }
  console.log('test-touch: fixtures and counts agree with the spec')
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main().catch((e) => { console.error(e); process.exit(1) })
