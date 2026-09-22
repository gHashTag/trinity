// Every var(--token, fallback) whose fallback disagrees with the token.
//
// A fallback is reached ONLY when the name is unknown at that element. So a
// fallback that disagrees with the declaration is one of two things, and both
// are defects:
//
//   dead and lying   the token IS in scope, the fallback never draws, and the
//                    line records a colour the board does not use. Harmless to
//                    the eye and poisonous to anything that reads the source --
//                    var(--muted, #8b9490) over a real --muted: #888888 made a
//                    contrast gate report 1.74:1 for ink drawing at 1.53:1, and
//                    the same shape with a LIGHTER fallback hides a real one.
//   live and undeclared  the token is NOT in scope, the fallback is what draws,
//                    and it draws a colour no token declares -- so no gate that
//                    reasons about tokens can see it at all.
//
// This gate does not try to decide which. It cannot: whether a token is in
// scope at a given element depends on the markup, and a stylesheet cannot know
// which markup a component sheet renders inside. Deciding that needs the
// running page (open the board and read getComputedStyle(el).getPropertyValue
// (token): it returns the inherited value when the token is in scope and ''
// when it is not). A scoped version of this check -- parity only where the
// declaring selector is a textual prefix of the using selector -- was tried and
// discarded: it proves 2 of 111 uses and shrugs at 109, which is a green light
// that means nothing.
//
// What this gate asserts instead needs no ancestry at all, and so abstains on
// nothing: a fallback must agree with SOME declaration of its token. If it
// agrees with none, the value is wrong in every scope it could possibly be
// reached from. That is checkable, total, and exactly the defect class above.
//
// Two things it deliberately does not flag:
//   - a token declared nowhere. Then the fallback is the only value there is,
//     and writing one is correct, not drift.
//   - a fallback that is itself a var(). Chained defaults are their own idiom.
//
// A stylesheet no module imports declares nothing: src/App.css sets --accent to
// #00d4ff and --border to #222 on :root and is imported by nobody, so matching
// a fallback against it would excuse drift against a colour that never loads.
// Those sheets are listed and skipped.
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'src')

// A use whose fallback matches no declaration, deliberately. Each entry states
// the element it renders on and why the token cannot be in scope there; a use
// that only LOOKS unreachable does not belong here, it belongs in the running
// page's answer.
const ALLOWED = new Map([])

const files = []
;(function walk(dir) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry)
    if (statSync(p).isDirectory()) walk(p)
    else if (p.endsWith('.css') || /\.tsx?$/.test(p)) files.push(p)
  }
})(ROOT)

const imported = new Set()
for (const m of files.filter((p) => /\.tsx?$/.test(p))) {
  for (const match of readFileSync(m, 'utf8').matchAll(/import\s+["']([^"']+\.css)["']/g)) {
    imported.add(resolve(dirname(m), match[1]))
  }
}
const sheets = files.filter((p) => p.endsWith('.css') && imported.has(p))
const orphans = files.filter((p) => p.endsWith('.css') && !imported.has(p))

// Two spellings of one value must compare equal: #FFF and #ffffff, rgba(0,0,0,
// .5) and rgba(0, 0, 0, 0.5), 'Outfit' and "Outfit".
const norm = (v) =>
  v
    .trim()
    .toLowerCase()
    .replace(/["']/g, '')
    .replace(/\s+/g, '')
    .replace(/(^|[,(])\.(\d)/g, '$10.$2')
    .replace(/^#([0-9a-f])([0-9a-f])([0-9a-f])$/, '#$1$1$2$2$3$3')
    .replace(/^#([0-9a-f]{6})ff$/, '#$1')

// var() with a balanced-paren fallback: a regex that stops at the first ')'
// truncates rgba(255, 255, 255, 0.55) and reports every one of them as drift.
function varCalls(text) {
  const out = []
  for (let i = text.indexOf('var('); i !== -1; i = text.indexOf('var(', i + 1)) {
    let depth = 0
    let comma = -1
    let end = -1
    for (let j = i + 3; j < text.length; j++) {
      const ch = text[j]
      if (ch === '(') depth++
      else if (ch === ')') {
        depth--
        if (depth === 0) {
          end = j
          break
        }
      } else if (ch === ',' && depth === 1 && comma === -1) comma = j
    }
    if (end === -1) continue
    const token = text.slice(i + 4, comma === -1 ? end : comma).trim()
    if (!token.startsWith('--')) continue
    out.push({ token, fallback: comma === -1 ? null : text.slice(comma + 1, end).trim(), index: i })
  }
  return out
}

const decls = new Map()
const uses = []

for (const file of sheets) {
  const rel = relative(ROOT, file)
  const raw = readFileSync(file, 'utf8')
  // Blank the comments so a commented example is not read as source, keeping
  // newlines so line numbers stay true.
  const text = raw.replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '))
  const lineAt = (i) => text.slice(0, i).split('\n').length

  // Walk the braces to know which selector each declaration belongs to.
  const blocks = []
  let selector = ''
  let buffer = ''
  let depth = 0
  let blockStart = 0
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    if (ch === '{') {
      if (depth === 0) {
        selector = buffer.trim().replace(/\s+/g, ' ')
        blockStart = i + 1
      }
      depth++
      buffer = ''
    } else if (ch === '}') {
      depth--
      if (depth === 0) {
        blocks.push({ selector, body: text.slice(blockStart, i), start: blockStart })
        buffer = ''
      }
    } else if (depth === 0) buffer += ch
  }

  for (const block of blocks) {
    if (/^@/.test(block.selector)) {
      // An at-rule swallowed its inner blocks; re-walk one level down.
      let d = 0
      let sel = ''
      let buf = ''
      let start = 0
      for (let i = 0; i < block.body.length; i++) {
        const ch = block.body[i]
        if (ch === '{') {
          if (d === 0) {
            sel = buf.trim().replace(/\s+/g, ' ')
            start = i + 1
          }
          d++
          buf = ''
        } else if (ch === '}') {
          d--
          if (d === 0) {
            blocks.push({
              selector: `${block.selector} ${sel}`,
              body: block.body.slice(start, i),
              start: block.start + start,
            })
            buf = ''
          }
        } else if (d === 0) buf += ch
      }
      continue
    }
    for (const m of block.body.matchAll(/(--[a-z0-9-]+)\s*:\s*([^;}]+)/gi)) {
      if (!decls.has(m[1])) decls.set(m[1], [])
      decls.get(m[1]).push({
        value: m[2].trim(),
        selector: block.selector,
        where: `${rel}:${lineAt(block.start + m.index)}`,
      })
    }
    for (const call of varCalls(block.body)) {
      if (call.fallback === null) continue
      uses.push({
        token: call.token,
        fallback: call.fallback,
        selector: block.selector,
        where: `${rel}:${lineAt(block.start + call.index)}`,
      })
    }
  }
}

const drifted = []
let checked = 0
for (const use of uses) {
  if (use.fallback.includes('var(')) continue
  // A token whose only "declaration" is itself (--x: var(--x, y)) declares
  // nothing new.
  const declared = (decls.get(use.token) ?? []).filter((d) => d.value !== use.token)
  if (!declared.length) continue
  checked++
  const values = [...new Set(declared.map((d) => norm(d.value)))]
  if (values.includes(norm(use.fallback))) continue
  if (ALLOWED.has(`${use.where} ${use.token}`)) continue
  drifted.push({ ...use, declared })
}

console.log('  Queen fallback parity')
if (orphans.length) {
  console.log(`  ignored ${orphans.length} stylesheet(s) no module imports: ${orphans.map((p) => relative(ROOT, p)).join(', ')}`)
}
console.log(`  ${checked} var() fallbacks name a token that is declared somewhere; ${drifted.length} disagree with every declaration`)
for (const d of drifted) {
  console.log(`\n  ${d.where}  ${d.selector}`)
  console.log(`    written   ${d.fallback}`)
  for (const decl of d.declared) console.log(`    declared  ${decl.value}  on ${decl.selector}  (${decl.where})`)
}
if (drifted.length) {
  console.log('\n  A fallback that matches no declaration is wrong in every scope it')
  console.log('  could be reached from. Open the board and read the token at one of')
  console.log('  these elements: if it resolves, the fallback is dead and should')
  console.log('  say what draws; if it does not, the fallback is what draws and')
  console.log('  must be justified against 4.5:1 (qa/queen-contrast-contract.mjs).')
}
console.log(`\n  Queen fallback parity: ${drifted.length ? 'FAIL' : 'PASS'} (${checked - drifted.length}/${checked})`)
process.exit(drifted.length ? 1 : 0)
