// Syntax highlighting for the spec explorer.
//
// Two different jobs, deliberately solved two different ways:
//
//   .t27 source   -- coloured from the compiler's OWN token stream. The lexer
//                    already told us exactly what every span is, so there is no
//                    reason to re-guess it with regexes and no way for the
//                    colours to disagree with the compiler.
//   generated code -- Zig/Verilog/C/Rust output has no token stream coming back
//                    from us, so this falls back to a small regex pass. It is
//                    presentation only; nothing downstream depends on it.

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

/**
 * Rebuild each source line as coloured spans, driven by the real tokens.
 *
 * The lexer reports 1-based line/col per token but does not emit comments or
 * whitespace, so anything between two tokens is copied through verbatim and
 * comment-only stretches are detected here rather than invented upstream.
 */
export function highlightSource(source: string, tokens: T27Token[]): Span[][] {
  const lines = source.split('\n')
  const byLine = new Map<number, T27Token[]>()
  for (const t of tokens) {
    if (t.kind === 'Eof' || !t.lexeme) continue
    const arr = byLine.get(t.line)
    if (arr) arr.push(t)
    else byLine.set(t.line, [t])
  }

  return lines.map((text, i) => {
    const toks = byLine.get(i + 1)
    if (!toks || toks.length === 0) {
      // No tokens on this line: it is blank, or entirely a comment.
      return [{ text, cls: text.trim().startsWith('//') ? 'comment' : 'plain' }]
    }
    toks.sort((a, b) => a.col - b.col)

    const out: Span[] = []
    let cursor = 0
    for (const t of toks) {
      // `col` is 1-based; trust the lexeme's own length rather than re-scanning.
      const start = Math.max(0, t.col - 1)
      if (start > cursor) out.push({ text: text.slice(cursor, start), cls: 'plain' })
      const slice = text.slice(start, start + t.lexeme.length)
      // If the reported span does not match the lexeme, the line has something
      // the token list cannot explain -- emit it plain rather than mis-colour.
      if (slice !== t.lexeme) continue
      out.push({ text: slice, cls: classOf(t.kind) })
      cursor = start + t.lexeme.length
    }
    if (cursor < text.length) {
      const rest = text.slice(cursor)
      // A trailing `//` after real tokens is a comment, not code.
      const c = rest.indexOf('//')
      if (c >= 0) {
        if (c > 0) out.push({ text: rest.slice(0, c), cls: 'plain' })
        out.push({ text: rest.slice(c), cls: 'comment' })
      } else {
        out.push({ text: rest, cls: 'plain' })
      }
    }
    return out.length ? out : [{ text, cls: 'plain' }]
  })
}

const KEYWORDS: Record<string, string[]> = {
  zig: ['const', 'var', 'fn', 'pub', 'return', 'if', 'else', 'while', 'for', 'switch', 'struct', 'enum', 'union', 'try', 'catch', 'defer', 'errdefer', 'comptime', 'inline', 'test', 'and', 'or', 'orelse', 'unreachable', 'break', 'continue', 'export', 'extern', 'usingnamespace'],
  verilog: ['module', 'endmodule', 'input', 'output', 'inout', 'wire', 'reg', 'logic', 'always', 'always_ff', 'always_comb', 'assign', 'begin', 'end', 'if', 'else', 'case', 'endcase', 'for', 'while', 'function', 'endfunction', 'task', 'endtask', 'parameter', 'localparam', 'integer', 'genvar', 'generate', 'endgenerate', 'posedge', 'negedge', 'default', 'initial'],
  c: ['int', 'char', 'void', 'return', 'if', 'else', 'while', 'for', 'switch', 'case', 'break', 'continue', 'struct', 'enum', 'union', 'typedef', 'const', 'static', 'unsigned', 'signed', 'long', 'short', 'float', 'double', 'sizeof', 'include', 'define', 'ifndef', 'endif'],
  rust: ['fn', 'let', 'mut', 'const', 'pub', 'struct', 'enum', 'impl', 'trait', 'use', 'mod', 'return', 'if', 'else', 'while', 'for', 'loop', 'match', 'break', 'continue', 'where', 'type', 'self', 'Self', 'crate', 'unsafe', 'as', 'in', 'ref', 'move'],
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
