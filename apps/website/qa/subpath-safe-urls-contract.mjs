// The same build must work from a subdirectory as well as from the apex.
//
// It is served at https://t27.ai/ and under https://app.t27.ai/game/. vite's
// base is './' and routing is HashRouter, so everything the bundle ships
// resolves against the page -- except a URL written root-absolute. Under
// /game/, '/favicon.svg' asks app.t27.ai's own root, which is the VIBEE
// player: a 404, or a 200 carrying somebody else's file (measured 2026-09-14:
// app.t27.ai/manifest.json is VIBEE's manifest, app.t27.ai/verification/ is
// VIBEE's index page).
//
// So a URL in src/ or public/manifest.json is relative (shipped in the build),
// absolute https://t27.ai/... (a page or file that exists only on the apex),
// or a hash route. Never root-absolute.
//
// What counts as a URL is decided by where the string goes, not by its shape:
// '/queen' is a route in <Route path> and <Link to>, a separator in
// split('/'), and a URL only in href, src, fetch() and their kin. The detector
// reads the TypeScript AST and proves itself on a fixture before it reads src/.
//
//   node qa/subpath-safe-urls-contract.mjs

import assert from 'node:assert/strict'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import ts from 'typescript'

const ROOT = fileURLToPath(new URL('..', import.meta.url))
const ROOT_ABSOLUTE = /^\/(?!\/)/ // '/x' and '/', not '//host'

// Left root-absolute on purpose, each with its reason. An entry that no longer
// matches anything fails the check, so the list cannot outlive its code.
const KNOWN = [
  // Nothing imports this component. /play is not a file on the apex (404, then
  // public/404.html bounces it to /#/play); which of the two it should be is
  // not decided here.
  { file: 'src/components/sections/InvestSection.tsx', url: '/play' },
  // Nothing imports this component. An API the apex does not serve (404);
  // where it should point is unknown.
  { file: 'src/components/sections/FPGASynthesisWidget.tsx', url: '/api/fpga/synthesis' },
]

const ATTRS = new Set(['href', 'src', 'srcSet', 'action', 'formAction', 'poster'])
const PROPS = new Set(['href', 'src', 'url'])
const CALLS = new Set(['fetch', 'window.fetch', 'window.open', 'navigator.sendBeacon', 'location.assign', 'location.replace', 'window.location.assign', 'window.location.replace'])
const CTORS = new Set(['URL', 'WebSocket', 'EventSource', 'Worker', 'SharedWorker'])

// Every string an expression can begin with, as far as literals decide it.
// `${lang === 'ru' ? '/ru' : ''}/blog/` begins with '/ru/blog/' or '/blog/';
// `${BASE}/api` begins with whatever BASE is, which is not known here.
function leads(node) {
  if (!node) return []
  if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return [node.text]
  if (ts.isTemplateExpression(node)) {
    if (node.head.text) return [node.head.text]
    const [first] = node.templateSpans
    return leads(first.expression).map((s) => s + first.literal.text)
  }
  if (ts.isParenthesizedExpression(node) || ts.isAsExpression(node) || ts.isJsxExpression(node)) return leads(node.expression)
  if (ts.isConditionalExpression(node)) return [...leads(node.whenTrue), ...leads(node.whenFalse)]
  if (ts.isBinaryExpression(node)) {
    const op = node.operatorToken.kind
    if (op === ts.SyntaxKind.PlusToken) return leads(node.left)
    if (op === ts.SyntaxKind.BarBarToken || op === ts.SyntaxKind.QuestionQuestionToken) return [...leads(node.left), ...leads(node.right)]
  }
  return []
}

const nameOf = (n) => (n && (ts.isIdentifier(n) || ts.isStringLiteral(n)) ? n.text : '')

function rootAbsoluteUrls(sf) {
  const found = []
  const flag = (expr) => {
    for (const url of leads(expr)) {
      if (ROOT_ABSOLUTE.test(url)) found.push({ url, line: sf.getLineAndCharacterOfPosition(expr.getStart(sf)).line + 1 })
    }
  }
  const visit = (node) => {
    if (ts.isJsxAttribute(node) && ATTRS.has(nameOf(node.name))) flag(node.initializer)
    else if (ts.isPropertyAssignment(node) && PROPS.has(nameOf(node.name))) flag(node.initializer)
    else if (ts.isVariableDeclaration(node) && /(src|href|url)$/i.test(nameOf(node.name))) flag(node.initializer)
    else if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.EqualsToken
      && ts.isPropertyAccessExpression(node.left) && PROPS.has(node.left.name.text)) flag(node.right)
    else if (ts.isCallExpression(node) && CALLS.has(node.expression.getText(sf))) flag(node.arguments[0])
    else if (ts.isNewExpression(node) && CTORS.has(node.expression.getText(sf))) flag(node.arguments?.[0])
    ts.forEachChild(node, visit)
  }
  visit(sf)
  return found
}

function manifestUrls(value, at = '') {
  if (typeof value === 'string') return ROOT_ABSOLUTE.test(value) ? [{ url: value, at }] : []
  if (value && typeof value === 'object') return Object.entries(value).flatMap(([k, v]) => manifestUrls(v, at ? `${at}.${k}` : k))
  return []
}

const parse = (file, text) =>
  ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true, /\.[jt]sx$/.test(file) ? ts.ScriptKind.TSX : ts.ScriptKind.TS)

// ── the detector can fail ─────────────────────────────────────────────────────
const FIXTURE = `
const coverSrc = \`/og-blog-\${slug}.png\`
export const Page = () => <>
  <a href="/verification/">a</a>
  <a href={\`\${lang === 'ru' ? '/ru' : ''}/blog/\${slug}/\`}>b</a>
  <Route path="/queen" element={<Queen />} />
  <Link to="/blog">c</Link>
  <a href="#/proof">d</a>
  <a href="https://t27.ai/ip/">e</a>
  <img src="favicon.svg" />
</>
const tracks = { href: '/about/', title: '/not-a-url' }
fetch('/api/x'); fetch('t27/manifest.json'); fetch(\`\${BASE}/api/y\`)
new URL('/r/', location.href)
'a/b'.split('/'); navigate('/queen')
`
assert.deepEqual(
  rootAbsoluteUrls(parse('fixture.tsx', FIXTURE)).map((h) => h.url).sort(),
  ['/about/', '/api/x', '/blog/', '/og-blog-', '/r/', '/ru/blog/', '/verification/'],
  'the detector must report exactly the root-absolute URLs in its fixture',
)
assert.deepEqual(
  manifestUrls({ start_url: '/', scope: './', icons: [{ src: '/a.png' }, { src: 'b.png' }, { src: 'https://t27.ai/c.png' }] }).map((h) => h.at),
  ['start_url', 'icons.0.src'],
  'the manifest walker must report exactly the root-absolute values in its fixture',
)

// ── the real tree ─────────────────────────────────────────────────────────────
function walk(dir) {
  const out = []
  for (const name of readdirSync(dir)) {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) out.push(...walk(path))
    else if (/\.(ts|tsx|js|jsx|mjs)$/.test(name)) out.push(path)
  }
  return out
}

const problems = []
const used = new Set()
const files = walk(join(ROOT, 'src'))
for (const path of files) {
  const file = relative(ROOT, path)
  for (const { url, line } of rootAbsoluteUrls(parse(file, readFileSync(path, 'utf8')))) {
    const known = KNOWN.find((k) => k.file === file && k.url === url)
    if (known) used.add(known)
    else problems.push(`${file}:${line} root-absolute URL '${url}' -- make it relative if the build ships it, https://t27.ai/... if only the apex has it`)
  }
}
for (const k of KNOWN) if (!used.has(k)) problems.push(`${k.file}: known exception '${k.url}' no longer occurs -- remove it from KNOWN`)

const manifest = JSON.parse(readFileSync(join(ROOT, 'public/manifest.json'), 'utf8'))
for (const { url, at } of manifestUrls(manifest)) {
  problems.push(`public/manifest.json ${at} is root-absolute '${url}' -- manifest URLs resolve against the manifest, so write it relative`)
}

if (problems.length) {
  console.error(`subpath-safe URLs: ${problems.length} problem(s)`)
  for (const p of problems) console.error(`  ${p}`)
  process.exit(1)
}
console.log(`subpath-safe URLs: ${files.length} source files and public/manifest.json, ${KNOWN.length} known exceptions -- ok`)
