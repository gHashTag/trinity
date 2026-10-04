// Syntax highlighting for the spec explorer.
//
// Two different jobs, deliberately solved two different ways:
//
//   .t27 source   -- coloured from the compiler's OWN token stream. The lexer
//                    already told us exactly what every span is, so there is no
//                    reason to re-guess it with regexes and no way for the
//                    colours to disagree with the compiler.
//   generated code -- Zig/Verilog/C/Rust/JavaScript/TypeScript output has no
//                    token stream coming back from us, so this falls back to a
//                    small regex pass. It is presentation only; nothing
//                    downstream depends on it.

import type { T27Token } from './t27Compiler'

export type Cls =
  | 'kw' | 'num' | 'str' | 'ident' | 'op' | 'punct' | 'comment' | 'type' | 'plain'

export interface Span { text: string; cls: Cls }

const KW = new Set([
  'KwPub', 'KwConst', 'KwFn', 'KwEnum', 'KwStruct', 'KwTest', 'KwInvariant',
  'KwBench', 'KwModule', 'KwIf', 'KwElse', 'KwFor', 'KwWhile', 'KwSwitch',
  'KwReturn', 'KwVar', 'KwUsing', 'KwVoid', 'KwTrue', 'KwFalse', 'KwUse',
  'KwOr', 'KwAnd', 'KwTry', 'KwBreak', 'KwContinue',
])

const PUNCT = new Set([
  'Colon', 'Comma', 'LParen', 'RParen', 'LBrace', 'RBrace', 'LBracket',
  'RBracket', 'Dot', 'Semicolon',
])

function classOf(kind: string): Cls {
  if (KW.has(kind)) return 'kw'
  if (kind === 'Number') return 'num'
  if (kind === 'String' || kind === 'CharLiteral') return 'str'
  if (kind === 'Ident') return 'ident'
  if (PUNCT.has(kind)) return 'punct'
  if (kind === 'Eof') return 'plain'
  return 'op'
}

// What the lexer skips without emitting a token (bootstrap/src/compiler.rs,
// the comment loop before `check_keyword`): `//` and `#` to the end of the
// line, `/* ... */` nested, and `;` in column 1 followed by a space or a tab.
// A `;` alone on its line is NOT one of them -- it lexes as a Semicolon, which
// is how a module declaration after it gets swallowed -- so it stays code here.
interface GapState { depth: number }

function gapSpans(text: string, lineStart: boolean, st: GapState): Span[] {
  const out: Span[] = []
  const put = (t: string, cls: Cls) => {
    if (!t) return
    const last = out[out.length - 1]
    if (last && last.cls === cls) last.text += t
    else out.push({ text: t, cls })
  }
  let i = 0
  while (i < text.length) {
    if (st.depth > 0) {
      if (text.startsWith('*/', i)) { put('*/', 'comment'); i += 2; st.depth -= 1; continue }
      if (text.startsWith('/*', i)) { put('/*', 'comment'); i += 2; st.depth += 1; continue }
      put(text[i], 'comment'); i += 1; continue
    }
    if (text.startsWith('/*', i)) { put('/*', 'comment'); i += 2; st.depth = 1; continue }
    const semicolonComment = lineStart && i === 0 && text[0] === ';' && (text[1] === ' ' || text[1] === '\t')
    if (text.startsWith('//', i) || text[i] === '#' || semicolonComment) { put(text.slice(i), 'comment'); break }
    put(text[i], 'plain'); i += 1
  }
  return out
}

/**
 * Rebuild each source line as coloured spans, driven by the real tokens.
 *
 * The lexer reports 1-based line/col per token but does not emit comments or
 * whitespace, so anything between two tokens is copied through verbatim and
 * comment stretches are found by the lexer's own skip rules (`gapSpans`)
 * rather than invented upstream.
 */
export function highlightSource(source: string, tokens: T27Token[]): Span[][] {
  const lines = source.split('\n')
  const byLine = new Map<number, T27Token[]>()
  for (const t of tokens) {
    // An empty lexeme carries nothing to colour -- except `""`, whose quotes are in the source.
    if (t.kind === 'Eof' || (!t.lexeme && t.kind !== 'String' && t.kind !== 'CharLiteral')) continue
    const arr = byLine.get(t.line)
    if (arr) arr.push(t)
    else byLine.set(t.line, [t])
  }

  const st: GapState = { depth: 0 }
  return lines.map((text, i) => {
    const toks = (byLine.get(i + 1) ?? []).slice().sort((a, b) => a.col - b.col)
    const out: Span[] = []
    let cursor = 0
    for (const t of toks) {
      // `col` is 1-based; trust the lexeme's own length rather than re-scanning.
      const start = Math.max(0, t.col - 1)
      if (start < cursor) continue
      let len = t.lexeme.length
      // A string token's lexeme is its contents, unescaped: the quotes are in
      // the source and not in the lexeme (`"\"H\""` lexes as `"H"`, which
      // starts with a quote of its own), so the span runs to the closing quote.
      const q = text[start]
      if ((t.kind === 'String' || t.kind === 'CharLiteral') && (q === '"' || q === "'")) {
        let j = start + 1
        while (j < text.length && text[j] !== q) j += text[j] === '\\' ? 2 : 1
        len = Math.min(text.length, j + 1) - start
      } else if (text.slice(start, start + len) !== t.lexeme) {
        // The reported span does not match the lexeme: the line has something
        // the token list cannot explain -- leave it plain rather than mis-colour.
        continue
      }
      if (start > cursor) out.push(...gapSpans(text.slice(cursor, start), cursor === 0, st))
      out.push({ text: text.slice(start, start + len), cls: classOf(t.kind) })
      cursor = start + len
    }
    if (cursor < text.length) out.push(...gapSpans(text.slice(cursor), cursor === 0, st))
    return out.length ? out : [{ text, cls: 'plain' }]
  })
}

// `gen-js` emits declarations only -- const, export, and the two frozen order
// arrays -- so most of this list will never appear in the output. It is the
// language's keyword set rather than the backend's, because the day the backend
// lowers a body the colours should already be right.
const JS_KEYWORDS = ['export', 'import', 'from', 'default', 'const', 'let', 'var', 'function', 'class', 'extends', 'new', 'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'break', 'continue', 'try', 'catch', 'finally', 'throw', 'typeof', 'instanceof', 'in', 'of', 'this', 'null', 'undefined', 'true', 'false', 'async', 'await', 'yield', 'delete', 'void']

// What TypeScript adds, and nothing TypeScript already shares. Written as a
// difference rather than a second full list for the same reason `codegen_ts`
// shares `codegen_js`'s value layer upstream: a copy is where the two drift.
// `interface`, `readonly`, `satisfies`, `as` and the predefined type names are
// the ones `gen-ts` can actually print; the rest is the language's surface.
const TS_ONLY = ['interface', 'type', 'namespace', 'declare', 'abstract', 'implements', 'readonly', 'satisfies', 'as', 'is', 'asserts', 'keyof', 'infer', 'enum', 'public', 'private', 'protected', 'override', 'unique', 'any', 'unknown', 'never', 'number', 'string', 'boolean', 'object', 'symbol', 'bigint']

const KEYWORDS: Record<string, string[]> = {
  zig: ['const', 'var', 'fn', 'pub', 'return', 'if', 'else', 'while', 'for', 'switch', 'struct', 'enum', 'union', 'try', 'catch', 'defer', 'errdefer', 'comptime', 'inline', 'test', 'and', 'or', 'orelse', 'unreachable', 'break', 'continue', 'export', 'extern', 'usingnamespace'],
  verilog: ['module', 'endmodule', 'input', 'output', 'inout', 'wire', 'reg', 'logic', 'always', 'always_ff', 'always_comb', 'assign', 'begin', 'end', 'if', 'else', 'case', 'endcase', 'for', 'while', 'function', 'endfunction', 'task', 'endtask', 'parameter', 'localparam', 'integer', 'genvar', 'generate', 'endgenerate', 'posedge', 'negedge', 'default', 'initial'],
  c: ['int', 'char', 'void', 'return', 'if', 'else', 'while', 'for', 'switch', 'case', 'break', 'continue', 'struct', 'enum', 'union', 'typedef', 'const', 'static', 'unsigned', 'signed', 'long', 'short', 'float', 'double', 'sizeof', 'include', 'define', 'ifndef', 'endif'],
  rust: ['fn', 'let', 'mut', 'const', 'pub', 'struct', 'enum', 'impl', 'trait', 'use', 'mod', 'return', 'if', 'else', 'while', 'for', 'loop', 'match', 'break', 'continue', 'where', 'type', 'self', 'Self', 'crate', 'unsafe', 'as', 'in', 'ref', 'move'],
  js: JS_KEYWORDS,
  ts: [...JS_KEYWORDS, ...TS_ONLY],
}

/** The highlighter language for each compiler target; `hir` prints as Verilog. */
export const TARGET_LANG: Record<string, string> = {
  zig: 'zig', verilog: 'verilog', verilog_hir: 'verilog', hir: 'verilog', c: 'c', rust: 'rust', js: 'js', ts: 'ts',
}

/** Cheap regex highlighter for generated output. Presentation only. */
export function highlightCode(code: string, lang: string): Span[][] {
  const kws = new Set(KEYWORDS[lang] || [])
  const lineComment = lang === 'verilog' || lang === 'c' || lang === 'rust' || lang === 'zig' ? '//' : '//'

  return code.split('\n').map((line) => {
    const out: Span[] = []
    const c = line.indexOf(lineComment)
    // Only treat `//` as a comment when it is not inside a string on this line.
    const q = line.indexOf('"')
    const codePart = c >= 0 && (q < 0 || c < q) ? line.slice(0, c) : line
    const commentPart = c >= 0 && (q < 0 || c < q) ? line.slice(c) : ''

    // One pass: strings, numbers, identifiers, everything else.
    const re = /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\b\d[\w'.]*\b|[A-Za-z_`$][\w$]*|\s+|.)/g
    let m: RegExpExecArray | null
    while ((m = re.exec(codePart)) !== null) {
      const tok = m[0]
      if (/^["']/.test(tok)) out.push({ text: tok, cls: 'str' })
      else if (/^\d/.test(tok)) out.push({ text: tok, cls: 'num' })
      else if (/^[`$]/.test(tok)) out.push({ text: tok, cls: 'kw' })
      else if (/^[A-Za-z_]/.test(tok)) out.push({ text: tok, cls: kws.has(tok) ? 'kw' : 'ident' })
      else if (/^\s+$/.test(tok)) out.push({ text: tok, cls: 'plain' })
      else out.push({ text: tok, cls: /[{}()[\];,.]/.test(tok) ? 'punct' : 'op' })
    }
    if (commentPart) out.push({ text: commentPart, cls: 'comment' })
    return out.length ? out : [{ text: line, cls: 'plain' }]
  })
}

/**
 * Markdown as coloured spans, for the skill bodies.
 *
 * A skill is a document, not a program: there is no token stream to colour it
 * from, so this is the same honest regex pass the generated-code highlighter
 * is — presentation only, nothing downstream depends on it. Fenced blocks are
 * handed to `highlightCode` with the fence's own language, so a shell recipe
 * inside a skill reads the way it reads on the /specs page.
 */
export function highlightMarkdown(text: string): Span[][] {
  const lines = text.split('\n')
  const out: Span[][] = []
  let fence: { lang: string; body: string[]; open: string } | null = null

  const flush = () => {
    if (!fence) return
    const coloured = highlightCode(fence.body.join('\n'), fence.lang)
    // An empty fenced block yields one empty line from split; keep the shape.
    for (const line of fence.body.length ? coloured : [[{ text: '', cls: 'plain' as Cls }]]) out.push(line)
    fence = null
  }

  for (const raw of lines) {
    const fenceMatch = raw.match(/^\s*(```+|~~~+)\s*([A-Za-z0-9_+-]*)\s*$/)
    if (fence) {
      if (fenceMatch && fenceMatch[1][0] === fence.open[0] && fenceMatch[1].length >= fence.open.length) {
        flush()
        out.push([{ text: raw, cls: 'punct' }])
      } else {
        fence.body.push(raw)
      }
      continue
    }
    if (fenceMatch) {
      fence = { lang: fenceMatch[2].toLowerCase(), body: [], open: fenceMatch[1] }
      out.push([{ text: raw, cls: 'punct' }])
      continue
    }
    out.push(markdownLine(raw))
  }
  flush()
  return out
}

/** One line of prose: headings, list bullets, quotes, inline code, links, emphasis. */
function markdownLine(line: string): Span[] {
  if (/^\s{0,3}#{1,6}\s/.test(line)) return [{ text: line, cls: 'kw' }]
  if (/^\s*(---+|===+|\*\*\*+)\s*$/.test(line)) return [{ text: line, cls: 'punct' }]
  if (/^\s*>/.test(line)) return [{ text: line, cls: 'comment' }]
  // The frontmatter block reads as key/value pairs; colour the key like one.
  const kv = line.match(/^([A-Za-z_][\w-]*)(:\s*)(.*)$/)
  if (kv && kv[3] !== '') return [{ text: kv[1], cls: 'type' }, { text: kv[2], cls: 'punct' }, ...inlineSpans(kv[3])]

  const bullet = line.match(/^(\s*(?:[-*+]|\d+\.)\s+)(.*)$/)
  if (bullet) return [{ text: bullet[1], cls: 'op' }, ...inlineSpans(bullet[2])]
  return inlineSpans(line)
}

function inlineSpans(text: string): Span[] {
  const out: Span[] = []
  // Inline code first: everything inside backticks is literal and must not be
  // re-read as emphasis or a link.
  const re = /(`[^`]*`|\[[^\]]*\]\([^)\s]*\)|https?:\/\/\S+|\*\*[^*]+\*\*|__[^_]+__|\*[^*\n]+\*)/g
  let last = 0
  let m: RegExpExecArray | null
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push({ text: text.slice(last, m.index), cls: 'plain' })
    const tok = m[0]
    if (tok.startsWith('`')) out.push({ text: tok, cls: 'str' })
    else if (tok.startsWith('http')) out.push({ text: tok, cls: 'num' })
    else if (tok.startsWith('[')) out.push({ text: tok, cls: 'ident' })
    else out.push({ text: tok, cls: 'type' })
    last = m.index + tok.length
  }
  if (last < text.length) out.push({ text: text.slice(last), cls: 'plain' })
  return out.length ? out : [{ text, cls: 'plain' }]
}

/**
 * Built from the site's own tokens rather than a stock editor theme.
 *
 * `--accent` (#00FF88) and `--golden` (#FFD700) are the two colours the rest of
 * t27.ai is built from, so keywords take the gold and identifiers the green:
 * that puts the page's own palette on the thing the page is actually about.
 * The remaining hues are chosen to sit beside those two without competing --
 * a cool cyan for numbers, a soft violet for strings.
 *
 * Contrast on #0a0a0a: every colour below clears 4.5:1 except `comment`, which
 * is deliberately quiet at ~4.6:1 and carries no information a reader needs.
 */
export const CLS_COLOR: Record<Cls, string> = {
  kw: '#FFD700',      // --golden: the keywords that give a spec its shape
  num: '#5ad4ff',
  str: '#c9a2ff',
  ident: '#00FF88',   // --accent
  op: '#ff9ec4',
  punct: '#7c8794',
  comment: '#6b7480',
  type: '#ffb454',
  plain: '#d6dde4',
}
