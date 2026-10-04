// The reading half of the cron catalog: pure functions over source text.
//
// Nothing here touches the filesystem, the network or the clock. sync-crons.mjs
// supplies the bytes and the probes; every decision that can be made from a
// string alone lives here, so the test can exercise it against a fixture
// instead of against a checkout that moves under it.
//
// The hard part is not finding the schedules -- a grep finds those. It is
// saying HOW OFTEN each one fires, because half of the periods in the bot are
// written as `intervalMs`, `opts.everyMs` or `this.config.checkInterval` and
// the number lives somewhere else. A catalog that prints the identifier and
// calls it a period would be a catalog of names, not of schedules.

// ---------------------------------------------------------------------------
// Source text
// ---------------------------------------------------------------------------

/**
 * Comments blanked to spaces, with every newline kept.
 *
 * Length-preserving on purpose: the scan reports the LINE a timer sits on, and
 * a stripper that shortens the text would report lines that do not exist in the
 * file the reader opens. Blanking also removes the second hazard -- a
 * `setInterval(` written inside a comment is no longer found at all.
 */
export function maskComments(text) {
  let out = ''
  let quote = null
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (quote) {
      out += c
      if (c === '\\') { out += text[++i] ?? ''; continue }
      if (c === quote) quote = null
      continue
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; out += c; continue }
    // A backslash outside a string is only ever a regex escape here, and
    // `/https:\/\//` must not read as the start of a line comment.
    if (c === '\\') { out += c + (text[++i] ?? ''); continue }
    if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') { out += ' '; i++ }
      out += '\n'
      continue
    }
    if (c === '/' && text[i + 1] === '*') {
      const end = text.indexOf('*/', i + 2)
      const stop = end < 0 ? text.length : end + 2
      for (; i < stop; i++) out += text[i] === '\n' ? '\n' : ' '
      i--
      continue
    }
    out += c
  }
  return out
}

const OPENERS = { '(': ')', '[': ']', '{': '}' }

/**
 * The arguments of the call whose `(` sits at `open`, as raw source text.
 *
 * Brackets and quotes are balanced, so `setInterval(f('a, b'), 60_000)` yields
 * two arguments and not three. Comments are assumed already stripped.
 */
export function callArguments(text, open) {
  const args = []
  let depth = 0
  let quote = null
  let start = open + 1
  for (let i = open; i < text.length; i++) {
    const c = text[i]
    if (quote) {
      if (c === '\\') { i++; continue }
      if (c === quote) quote = null
      continue
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; continue }
    if (OPENERS[c]) { depth++; continue }
    if (c === ')' || c === ']' || c === '}') {
      depth--
      if (depth === 0) { args.push(text.slice(start, i)); return args }
      continue
    }
    if (c === ',' && depth === 1) { args.push(text.slice(start, i)); start = i + 1 }
  }
  return args
}

/** Split on top-level occurrences of `op`, ignoring brackets and strings. */
function splitTop(text, op) {
  const parts = []
  let depth = 0
  let quote = null
  let start = 0
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (quote) {
      if (c === '\\') { i++; continue }
      if (c === quote) quote = null
      continue
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; continue }
    if (OPENERS[c]) { depth++; continue }
    if (c === ')' || c === ']' || c === '}') { depth--; continue }
    if (depth === 0 && text.startsWith(op, i)) {
      parts.push(text.slice(start, i))
      i += op.length - 1
      start = i + 1
    }
  }
  parts.push(text.slice(start))
  return parts
}

// ---------------------------------------------------------------------------
// Periods
// ---------------------------------------------------------------------------

/**
 * A period expression in milliseconds, or undefined when it is not decidable
 * from this text alone.
 *
 * Deliberately small: numeric literals (with `_` separators), `* / + -`,
 * parentheses, `Math.max`/`Math.min`, `Number(...)`, and the two idioms the bot
 * uses to make a period tunable -- `process.env.X ?? '30'` and
 * `Number(process.env.X) || 30 * 60_000`. An unknown identifier evaluates to
 * undefined rather than to a guess; the caller then resolves it and asks again.
 */
export function evalPeriod(text) {
  if (typeof text !== 'string') return undefined
  return evaluate(maskComments(text).trim())
}

function evaluate(raw) {
  const expr = raw.trim()
  if (!expr) return undefined

  // `a ?? b` / `a || b`: the first operand that is decidable wins. For `||` a
  // zero is falsy in JavaScript too, so it does not win.
  for (const op of ['??', '||']) {
    const parts = splitTop(expr, op)
    if (parts.length > 1) {
      for (const part of parts) {
        const value = evaluate(part)
        if (value === undefined) continue
        if (op === '||' && value === 0) continue
        return value
      }
      return undefined
    }
  }

  for (const op of ['+', '-']) {
    const parts = splitTop(expr, op)
    // A leading empty part is a sign, not a binary operator.
    if (parts.length > 1 && parts[0].trim()) {
      const values = parts.map(evaluate)
      if (values.some((v) => v === undefined)) return undefined
      return values.reduce((a, b) => (op === '+' ? a + b : a - b))
    }
  }

  for (const op of ['*', '/']) {
    const parts = splitTop(expr, op)
    if (parts.length > 1) {
      const values = parts.map(evaluate)
      if (values.some((v) => v === undefined)) return undefined
      return values.reduce((a, b) => (op === '*' ? a * b : a / b))
    }
  }

  if (expr.startsWith('(') && expr.endsWith(')')) return evaluate(expr.slice(1, -1))

  const quoted = /^(['"])([^'"]*)\1$/.exec(expr)
  if (quoted) return evaluate(quoted[2])

  if (/^-?\d[\d_]*(\.\d+)?$/.test(expr)) return Number(expr.replace(/_/g, ''))

  const call = /^(Math\.max|Math\.min|Number)\s*\(/.exec(expr)
  if (call) {
    const args = callArguments(expr, expr.indexOf('(')).map(evaluate).filter((v) => v !== undefined)
    if (!args.length) return undefined
    if (call[1] === 'Number') return args[0]
    return call[1] === 'Math.max' ? Math.max(...args) : Math.min(...args)
  }

  return undefined
}

/**
 * Every value bound to `name` in this file, as source text, in file order.
 *
 * All of them, not the first: `everyMs` appears in crmProactive.ts twice, once
 * as the type `everyMs: number` and once as `Math.round(opts.everyMs / 60_000)`
 * inside a log line, and neither is the period. The caller tries candidates
 * until one evaluates, which is why a wrong first match is harmless.
 *
 * One pattern covers the four shapes the periods use: a `const`, a default
 * parameter (`intervalMs = DAY`), an object property (`checkInterval: 300000`)
 * and a plain assignment. A value ends at the first top-level `,` `;` or
 * newline, so a multi-line `Math.max(...)` survives intact.
 */
export function lookupDefinitions(name, text) {
  const source = maskComments(text)
  const re = new RegExp(`(?:^|[^.\\w$])${name}\\s*(?:=|:)\\s*`, 'g')
  const found = []
  let m
  while ((m = re.exec(source))) {
    const value = readValue(source, m.index + m[0].length)
    // A type annotation (`everyMs: number`) is a declaration, not a value.
    if (value && !/^(number|string|boolean|any|unknown)$/.test(value)) found.push(value)
  }
  return found
}

function readValue(text, from) {
  let depth = 0
  let quote = null
  for (let i = from; i < text.length; i++) {
    const c = text[i]
    if (quote) {
      if (c === '\\') { i++; continue }
      if (c === quote) quote = null
      continue
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; continue }
    if (OPENERS[c]) { depth++; continue }
    if (c === ')' || c === ']' || c === '}') {
      if (depth === 0) return text.slice(from, i).trim()
      depth--
      continue
    }
    if (depth === 0 && (c === ',' || c === ';' || c === '\n')) return text.slice(from, i).trim()
  }
  return text.slice(from).trim()
}

const RESERVED = new Set(['Math', 'Number', 'process', 'env', 'max', 'min', 'round', 'new', 'Date'])
const MAX_HOPS = 5

/**
 * A period in milliseconds, resolving identifiers against the files given.
 *
 * `texts` is searched in order: the timer's own file first, then whatever
 * caller the scan was told supplies the default. Substitution is textual and
 * bounded to five hops -- enough for `opts.everyMs` -> `proactiveMinutes *
 * 60_000` -> `Number(process.env.CRM_PROACTIVE_MINUTES ?? '30') * 60_000`, and
 * short of looping forever on a name that refers to itself.
 *
 * Undefined is a real answer. A period the scan cannot read stays undefined and
 * the entry keeps only its raw text, which is honest; inventing a number here
 * would put a schedule on the page that nothing in the source says.
 */
export function resolvePeriod(raw, texts, hop = 0) {
  const expr = maskComments(String(raw)).trim()
  const direct = evaluate(expr)
  if (direct !== undefined) return direct
  if (hop >= MAX_HOPS) return undefined

  // A member expression is resolved by its last segment: `opts.everyMs` is
  // looked up as `everyMs`, which is how the caller spells the argument.
  const member = /^[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)+$/.test(expr)
  const names = member
    ? [expr.split('.').pop()]
    : [...new Set(expr.match(/[A-Za-z_$][\w$]*/g) ?? [])].filter((n) => !RESERVED.has(n))

  for (const name of names) {
    for (const text of texts) {
      for (const candidate of lookupDefinitions(name, text)) {
        const next = member
          ? candidate
          : expr.replace(new RegExp(`(?<![.\\w$])${name}(?![\\w$])`, 'g'), `(${candidate})`)
        if (next === expr) continue
        const value = resolvePeriod(next, texts, hop + 1)
        if (value !== undefined) return value
      }
    }
  }
  return undefined
}

// ---------------------------------------------------------------------------
// Buckets
// ---------------------------------------------------------------------------

/**
 * How often a five-field cron expression fires, as one of the catalog's
 * buckets. Anything outside the four shapes the repositories actually use is
 * `unknown` rather than a guess -- an entry the reader can check beats a
 * confident wrong label.
 */
export function cronBucket(expr) {
  if (!expr) return 'unknown'
  const f = String(expr).trim().split(/\s+/)
  if (f.length !== 5) return 'unknown'
  const [min, hour, dom, mon, dow] = f
  if (dom !== '*' || mon !== '*') return 'unknown'
  if (/^\*\/\d+$/.test(min) && hour === '*') return 'minutes'
  if (/^\d+$/.test(min) && hour === '*') return 'hourly'
  if (/^\d+$/.test(min) && /^\*\/\d+$/.test(hour)) return 'hourly'
  if (/^\d+$/.test(min) && /^\d+$/.test(hour)) return dow === '*' ? 'daily' : 'weekly'
  return 'unknown'
}

const HOUR = 3_600_000
const DAY = 86_400_000

/** The same buckets, for a period given in milliseconds. */
export function intervalBucket(ms) {
  if (!Number.isFinite(ms) || ms <= 0) return 'unknown'
  if (ms < HOUR) return 'minutes'
  if (ms < DAY) return 'hourly'
  if (ms < 7 * DAY) return 'daily'
  return 'weekly'
}

/** The bucket for a whole schedule, whichever kind it is. */
export function scheduleBucket(schedule) {
  if (!schedule) return 'unknown'
  return schedule.kind === 'cron' ? cronBucket(schedule.expr) : intervalBucket(schedule.everyMs)
}

// ---------------------------------------------------------------------------
// Finding the schedules
// ---------------------------------------------------------------------------

const INNGEST_LOOKBACK = 40

/**
 * Every `cron:` in an Inngest module, with the id of the function it belongs to.
 *
 * The id is the nearest `id: '...'` above the cron line and below the
 * `createFunction(` that opens the same call -- not merely the nearest one in
 * the file, which would happily borrow the id of the function above. When the
 * call carries no id, the const it is assigned to names it.
 */
export function extractInngestCrons(text) {
  const lines = text.split('\n')
  const out = []
  for (let i = 0; i < lines.length; i++) {
    const m = /cron:\s*['"]([^'"]+)['"]/.exec(lines[i])
    if (!m) continue
    out.push({ expr: m[1], line: i + 1, functionId: functionIdAbove(lines, i) })
  }
  return out
}

function functionIdAbove(lines, at) {
  const from = Math.max(0, at - INNGEST_LOOKBACK)
  let call = -1
  for (let i = at - 1; i >= from; i--) {
    if (/createFunction\s*\(/.test(lines[i])) { call = i; break }
  }
  if (call < 0) return null
  for (let i = at - 1; i > call; i--) {
    const id = /\bid:\s*['"]([^'"]+)['"]/.exec(lines[i])
    if (id) return id[1]
  }
  const decl = /(?:export\s+)?const\s+([A-Za-z_$][\w$]*)\s*=/.exec(lines[call])
  return decl ? decl[1] : null
}

/** Strip a trailing YAML comment and the surrounding quotes from a scalar. */
function cleanScalar(raw) {
  const s = raw.trim()
  const quoted = /^(['"])(.*?)\1/.exec(s)
  if (quoted) return quoted[2]
  return s.split('#')[0].trim()
}

/**
 * The workflow name and every `- cron:` inside its `schedule:` block.
 *
 * Indentation ends the block, so a `cron:` belonging to some later key is not
 * collected. A workflow with no top-level `name:` returns null and the caller
 * falls back to the file name -- which is what GitHub itself displays.
 */
export function extractGithubSchedules(text) {
  const lines = text.split('\n')
  const named = /^name:\s*(.+)$/m.exec(text)
  const name = named ? cleanScalar(named[1]) || null : null
  const crons = []
  for (let i = 0; i < lines.length; i++) {
    const head = /^(\s*)schedule:\s*(#.*)?$/.exec(lines[i])
    if (!head) continue
    const indent = head[1].length
    for (let j = i + 1; j < lines.length; j++) {
      const line = lines[j]
      if (!line.trim() || /^\s*#/.test(line)) continue
      if (line.length - line.trimStart().length <= indent) break
      const m = /^\s*-\s*cron:\s*(.+)$/.exec(line)
      if (m) crons.push({ expr: cleanScalar(m[1]), line: j + 1 })
    }
  }
  return { name, crons }
}

// ---------------------------------------------------------------------------
// The manifest
// ---------------------------------------------------------------------------

/** Every facet an entry belongs to, in a fixed order. */
export function entryTags(entry) {
  return [
    `kind/${entry.kind}`,
    `repo/${entry.repo}`,
    `host/${entry.where.host.replace(/^railway:/, '')}`,
    `every/${scheduleBucket(entry.schedule)}`,
    `health/${entry.health}`,
  ]
}

/**
 * The annotation gate.
 *
 * A scan that finds a new timer and quietly ships it with no description is a
 * catalog that decays. `missing` is fatal for the sync; `stale` is a warning,
 * because an annotation left behind by a deleted job costs the reader nothing.
 */
export function checkAnnotations(ids, annotations) {
  const known = new Set(Object.keys(annotations))
  return {
    missing: ids.filter((id) => !known.has(id)).sort(),
    stale: [...known].filter((id) => !ids.includes(id)).sort(),
  }
}

/** kind, then repo, then name -- the order the page renders. */
export function sortEntries(entries) {
  return [...entries].sort(
    (a, b) =>
      a.kind.localeCompare(b.kind) || a.repo.localeCompare(b.repo) || a.name.localeCompare(b.name),
  )
}

/** Counts of every value a key takes, highest first, ties by name. */
export function tally(values) {
  const counts = {}
  for (const v of values) counts[v] = (counts[v] || 0) + 1
  return Object.fromEntries(Object.entries(counts).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])))
}
