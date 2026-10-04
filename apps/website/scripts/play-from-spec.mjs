#!/usr/bin/env node
// play-from-spec.mjs -- the X player card pages from `specs/x/player.t27`.
//
// Reads the spec through the real compiler (`t27_compiler.wasm`), checks the constant schema,
// evaluates every `test` block against the declared constants, checks what the schema cannot say
// (every play's spec, recording and card image exist; X's length and size limits hold; every tab
// the spec names has a pane in the player), and writes the files nobody edits by hand:
//
//   public/play/player.t27         this spec, byte for byte: the player compiles it in the browser
//   public/play/site.js            the spec explorer's highlighter and palette (SITE_MODULES),
//                                  bundled by esbuild from the site's own source, not copied
//   public/play/<id>/index.html    one share page per play, carrying twitter:card = player
//
// The share page is the address a post links to. X reads its meta tags and, on a click, loads
// `twitter:player` in an iframe; the page itself shows the same player full-window to anyone who
// opens the link, which is what the X apps on a phone do.
//
// Run:      node scripts/play-from-spec.mjs            (write)
//           node scripts/play-from-spec.mjs --check    (fail if the committed files are stale)
//           node scripts/play-from-spec.mjs --json     (print the constants as JSON)
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { buildSync } from 'esbuild'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { CYRILLIC, SITE, checkSchema, compilerErrors, constsOf, loadCompiler, readCast, sha256, verdictOf } from './agents-from-specs.mjs'
import { runSpecTests } from './viewport-from-spec.mjs'

const WASM = 'public/t27/t27_compiler.wasm'
export const PLAYER_SPEC = 'specs/x/player.t27'
export const PUBLIC_SPEC_OUT = 'public/play/player.t27'
export const SITE_BUNDLE_OUT = 'public/play/site.js'
export const EXPECTED_MODULE = 'x_player'
// What the player is built from. A change to any of them is a new player, so it is a new
// `v=` on the iframe address and a page --check will call stale.
export const PLAYER_FILES = ['public/play/embed.html', 'public/play/embed.js', 'public/play/t27run.js', 'public/play/rtl.js', 'public/term/player.js', WASM]
// The outcomes `public/play/t27run.js` reports, in the order the spec lists them.
export const RUNNER_OUTCOMES = ['pass', 'fail', 'skip']

export const PLAYER_REQUIRED = {
  KIND: 'str', ID: 'str', NAME: 'str', GENERATED: 'arr',
  CARD: 'str', SITE_HANDLE: 'str', ORIGIN: 'str', EMBED: 'str', SPEC_PAGE: 'str',
  TITLE_MAX: 'u8', DESCRIPTION_MAX: 'u8', IMAGE_ALT_MAX: 'u16',
  PLAYER_WIDTH: 'u16', PLAYER_HEIGHT: 'u16', IMAGE_WIDTH: 'u16', IMAGE_HEIGHT: 'u16',
  IMAGE_MIN_AREA: 'u32', IMAGE_MAX_BYTES: 'u32', IMAGE_FILE: 'str',
  AUTOPLAY_LIMIT_MS: 'u16', COMPILE_ANIMATION_MS: 'u16', HAS_SOUND: 'bool', AUTOPLAY_PARAMS: 'arr',
  TABS: 'arr', TAB_LABELS: 'arr', FIRST_TAB: 'str', WIDE_MIN_PX: 'u16', RECOMPILE_DEBOUNCE_MS: 'u16',
  IOS_FOCUS_ZOOM_BELOW_PX: 'u8', EDITOR_TOUCH_FONT_PX: 'u8',
  OUTCOMES: 'arr', SKIP_IS_NEVER_PASS: 'bool', TESTS_NOTE: 'str',
  SITE_MODULES: 'arr', SITE_IMPORTS: 'arr', SITE_BUNDLE: 'str',
  PLAY_COUNT: 'u8', PLAY_IDS: 'arr', PLAY_SPECS: 'arr', PLAY_CASTS: 'arr',
  PLAY_TITLES: 'arr', PLAY_DESCRIPTIONS: 'arr', PLAY_IMAGE_ALTS: 'arr',
}
const PLAY_FIELDS = ['PLAY_IDS', 'PLAY_SPECS', 'PLAY_CASTS', 'PLAY_TITLES', 'PLAY_DESCRIPTIONS', 'PLAY_IMAGE_ALTS']
// The same two patterns embed.js applies to its query before it fetches anything.
export const SPEC_PATH_RE = /^specs\/[A-Za-z0-9_\-/.]+\.t27$/
export const CAST_ID_RE = /^[a-z0-9][a-z0-9-]{0,63}$/

export const pageOut = (id) => `public/play/${id}/index.html`
export const imageOf = (f, id) => `public/play/${id}/${f.IMAGE_FILE}`

/** Width and height from a PNG's IHDR, or null when the bytes are not a PNG. */
export function pngSize(bytes) {
  const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
  if (bytes.length < 24 || sig.some((b, i) => bytes[i] !== b) || bytes.toString('latin1', 12, 16) !== 'IHDR') return null
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) }
}

// ---------------------------------------------------------------------------
// Semantic checks the schema cannot express. `root` is the site, so a test can point it
// at a fixture; `files` reads a site-relative path or returns null.
// ---------------------------------------------------------------------------
export function semanticProblems(f, file, root = SITE) {
  const problems = []
  const p = (m) => problems.push(`${file}: ${m}`)
  if (f.KIND !== 'player') p('KIND must be "player"')
  if (f.CARD !== 'player') p('CARD must be "player": the iframe is the point')
  if (!/^https:\/\/[^/]+\/$/.test(f.ORIGIN)) p(`ORIGIN must be an https origin ending in "/", is ${f.ORIGIN}`)
  if (!/^@[A-Za-z0-9_]{1,15}$/.test(f.SITE_HANDLE)) p(`SITE_HANDLE ${f.SITE_HANDLE} is not an X handle`)
  if (!existsSync(join(root, 'public', f.EMBED))) p(`EMBED public/${f.EMBED} does not exist`)
  for (const k of PLAY_FIELDS) if (f[k].length !== f.PLAY_COUNT) p(`${k} has ${f[k].length} entries, PLAY_COUNT is ${f.PLAY_COUNT}`)
  const want = [PUBLIC_SPEC_OUT, SITE_BUNDLE_OUT, ...f.PLAY_IDS.map(pageOut)]
  if (f.SITE_BUNDLE !== SITE_BUNDLE_OUT) p(`SITE_BUNDLE must be ${SITE_BUNDLE_OUT}, the module embed.js imports as ./site.js`)
  if (f.SITE_MODULES.length !== f.SITE_IMPORTS.length) p('SITE_MODULES and SITE_IMPORTS must have one entry each per module')
  for (const m of f.SITE_MODULES) if (!/^src\/lib\/[A-Za-z0-9_]+\.ts$/.test(m) || !existsSync(join(root, m))) p(`SITE_MODULES: ${m} is not a module under src/lib/`)
  for (const names of f.SITE_IMPORTS) if (!/^[A-Za-z_$][\w$]*(, [A-Za-z_$][\w$]*)*$/.test(names)) p(`SITE_IMPORTS: "${names}" is not a comma-separated list of names`)
  if (JSON.stringify(f.GENERATED) !== JSON.stringify(want)) p(`GENERATED must be ${JSON.stringify(want)}`)
  if (JSON.stringify(f.OUTCOMES) !== JSON.stringify(RUNNER_OUTCOMES)) p(`OUTCOMES must be ${JSON.stringify(RUNNER_OUTCOMES)}, what t27run.js reports`)
  if (f.TABS.length !== f.TAB_LABELS.length) p('TABS and TAB_LABELS must have one entry each per tab')
  if (!f.TABS.includes(f.FIRST_TAB)) p(`FIRST_TAB ${f.FIRST_TAB} is not one of TABS`)
  const embedPath = join(root, 'public', f.EMBED)
  const embed = existsSync(embedPath) ? readFileSync(embedPath, 'utf8') : ''
  for (const t of f.TABS) if (!embed.includes(`id="pane-${t}"`)) p(`tab ${t} has no pane-${t} in public/${f.EMBED}`)
  if (f.COMPILE_ANIMATION_MS > f.AUTOPLAY_LIMIT_MS) p('COMPILE_ANIMATION_MS exceeds AUTOPLAY_LIMIT_MS')
  if (new Set(f.PLAY_IDS).size !== f.PLAY_IDS.length) p('PLAY_IDS repeats an id')
  for (let i = 0; i < f.PLAY_COUNT; i++) {
    const id = f.PLAY_IDS[i]
    const at = `play ${id ?? i}`
    if (!CAST_ID_RE.test(id ?? '')) p(`${at}: id must match ${CAST_ID_RE}`)
    const spec = f.PLAY_SPECS[i] ?? ''
    if (!SPEC_PATH_RE.test(spec) || spec.includes('..')) p(`${at}: spec ${spec} must match ${SPEC_PATH_RE} without ".."`)
    else if (!existsSync(join(root, 'public/t27/files', spec))) p(`${at}: public/t27/files/${spec} is not vendored`)
    const cast = f.PLAY_CASTS[i] ?? ''
    if (!CAST_ID_RE.test(cast)) p(`${at}: cast ${cast} must match ${CAST_ID_RE}`)
    else {
      const c = readCast(cast, root)
      if (!c.hasCast || !c.hasMeta) p(`${at}: public/term/${cast}/ has no session.cast and meta.json; publish the recording first`)
      else if (!c.exits.length || c.exits.some((x) => x !== '0') || c.badEvents) p(`${at}: recording ${cast} has exit codes ${JSON.stringify(c.exits)} and ${c.badEvents} unreadable event(s)`)
    }
    const len = (k, max) => { const s = f[k][i] ?? ''; if (!s || s.length > max) p(`${at}: ${k} is ${s.length} characters, X allows 1..${max}`) }
    len('PLAY_TITLES', f.TITLE_MAX)
    len('PLAY_DESCRIPTIONS', f.DESCRIPTION_MAX)
    len('PLAY_IMAGE_ALTS', f.IMAGE_ALT_MAX)
    const img = join(root, imageOf(f, id))
    if (!existsSync(img)) { p(`${at}: ${imageOf(f, id)} is missing`); continue }
    const bytes = readFileSync(img)
    const size = pngSize(bytes)
    if (!size) p(`${at}: ${imageOf(f, id)} is not a PNG`)
    else if (size.width !== f.IMAGE_WIDTH || size.height !== f.IMAGE_HEIGHT) p(`${at}: ${imageOf(f, id)} is ${size.width}x${size.height}, the card declares ${f.IMAGE_WIDTH}x${f.IMAGE_HEIGHT}`)
    if (statSync(img).size > f.IMAGE_MAX_BYTES) p(`${at}: ${imageOf(f, id)} is ${statSync(img).size} bytes, over ${f.IMAGE_MAX_BYTES}`)
  }
  return problems
}

// ---------------------------------------------------------------------------
// Render. Every value is escaped for an attribute; the page is ASCII, with entities.
// ---------------------------------------------------------------------------
export const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/[^\x00-\x7f]/gu, (ch) => `&#${ch.codePointAt(0)};`)

/** The iframe's query, the same for the card and the page; `v` is the player build. */
export const playQuery = (f, i, build) => `spec=${encodeURIComponent(f.PLAY_SPECS[i])}&cast=${encodeURIComponent(f.PLAY_CASTS[i])}&v=${build}`

export function renderPage(f, i, { specSha, build, imageSha }) {
  const id = f.PLAY_IDS[i]
  const page = `${f.ORIGIN}play/${id}/`
  const q = playQuery(f, i, build)
  const player = `${f.ORIGIN}${f.EMBED}?${q}`
  const image = `${page}${f.IMAGE_FILE}?v=${imageSha}`
  const title = f.PLAY_TITLES[i]
  const desc = f.PLAY_DESCRIPTIONS[i]
  const alt = f.PLAY_IMAGE_ALTS[i]
  const open = `${f.ORIGIN}${f.SPEC_PAGE}${encodeURIComponent(f.PLAY_SPECS[i])}`
  const meta = (attr, k, v) => `<meta ${attr}="${k}" content="${esc(v)}">`
  return `<!doctype html>
<!-- Generated by scripts/play-from-spec.mjs from ${PLAYER_SPEC} (sha256 ${specSha.slice(0, 16)}); do not edit. -->
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} &middot; Trinity S&sup3;AI</title>
${meta('name', 'description', desc)}
<link rel="canonical" href="${esc(page)}">
<link rel="icon" href="../../favicon.svg" type="image/svg+xml">
${meta('property', 'og:type', 'website')}
${meta('property', 'og:site_name', 'Trinity S³AI')}
${meta('property', 'og:url', page)}
${meta('property', 'og:title', title)}
${meta('property', 'og:description', desc)}
${meta('property', 'og:image', image)}
${meta('property', 'og:image:width', f.IMAGE_WIDTH)}
${meta('property', 'og:image:height', f.IMAGE_HEIGHT)}
${meta('property', 'og:image:alt', alt)}
${meta('name', 'twitter:card', f.CARD)}
${meta('name', 'twitter:site', f.SITE_HANDLE)}
${meta('name', 'twitter:title', title)}
${meta('name', 'twitter:description', desc)}
${meta('name', 'twitter:player', player)}
${meta('name', 'twitter:player:width', f.PLAYER_WIDTH)}
${meta('name', 'twitter:player:height', f.PLAYER_HEIGHT)}
${meta('name', 'twitter:image', image)}
${meta('name', 'twitter:image:alt', alt)}
<style>html,body{margin:0;height:100%;background:#000}iframe{display:block;border:0;width:100%;height:100%}noscript p{color:#888;font:15px system-ui;padding:1em}a{color:#00ff88}</style>
</head>
<body>
<iframe src="../../${esc(f.EMBED)}?${esc(q)}&amp;autoplay=1" title="${esc(title)}" allow="clipboard-write"></iframe>
<noscript><p>${esc(desc)} <a href="${esc(open)}">Open the spec on t27.ai</a>.</p></noscript>
</body>
</html>
`
}

// ---------------------------------------------------------------------------
// The site bundle. One ES module re-exporting the names SITE_IMPORTS lists from SITE_MODULES,
// bundled with the esbuild the site already builds with, ASCII-escaped so the file obeys L3.
// ---------------------------------------------------------------------------
export function renderSiteBundle(f, root = SITE) {
  const entry = f.SITE_MODULES.map((m, i) => `export { ${f.SITE_IMPORTS[i]} } from './${m}'`).join('\n') + '\n'
  const r = buildSync({ stdin: { contents: entry, resolveDir: root, loader: 'ts', sourcefile: 'site-entry.ts' }, bundle: true, format: 'esm', write: false, charset: 'ascii', legalComments: 'none', logLevel: 'silent' })
  return `// Generated by scripts/play-from-spec.mjs from ${f.SITE_MODULES.join(', ')} (named in ${PLAYER_SPEC}); do not edit.\n${r.outputFiles[0].text}`
}

// ---------------------------------------------------------------------------
// Build.
// ---------------------------------------------------------------------------
export function playerBuild(root = SITE, generated = {}) {
  // One hash over the player's files, each length-prefixed so two files cannot trade bytes.
  // `generated` supplies files this run writes, so the hash names what is about to be on disk.
  const parts = [...PLAYER_FILES, SITE_BUNDLE_OUT].map((rel) => {
    const b = rel in generated ? Buffer.from(generated[rel], 'utf8') : readFileSync(join(root, rel))
    return Buffer.concat([Buffer.from(`${rel}\0${b.length}\0`), b])
  })
  return sha256(Buffer.concat(parts)).slice(0, 12)
}

export async function buildPlay({ specText, analyze, root = SITE }) {
  const problems = []
  const analysis = analyze(specText)
  const verdict = verdictOf(analysis)
  if (!verdict.typecheckOk || verdict.discarded > 0 || !verdict.hirOk) problems.push(`${PLAYER_SPEC}: compiler verdict not clean (${JSON.stringify(verdict)})`)
  problems.push(...compilerErrors(analysis).map((m) => `${PLAYER_SPEC}: ${m}`))
  if (/[^\x00-\x7f]/.test(specText)) problems.push(`${PLAYER_SPEC}: non-ASCII byte in the spec (L3)`)
  if (CYRILLIC.test(specText)) problems.push(`${PLAYER_SPEC}: Cyrillic in the spec (LANG-EN)`)
  if (analysis.ast?.name !== EXPECTED_MODULE) problems.push(`${PLAYER_SPEC}: module must be ${EXPECTED_MODULE}, is ${analysis.ast?.name ?? 'missing'}`)
  let consts = {}
  try { consts = constsOf(analysis) } catch (e) { problems.push(`${PLAYER_SPEC}: ${e.message}`) }
  problems.push(...checkSchema(consts, PLAYER_REQUIRED, {}, PLAYER_SPEC))
  const f = Object.fromEntries(Object.entries(consts).map(([k, v]) => [k, v.value]))
  let tests = { tests: 0, asserts: 0, failures: [] }
  if (problems.length === 0) {
    problems.push(...semanticProblems(f, PLAYER_SPEC, root))
    tests = runSpecTests(analysis, f)
    if (tests.tests === 0) problems.push(`${PLAYER_SPEC}: no test block; the player must test its own limits`)
    problems.push(...tests.failures.map((m) => `${PLAYER_SPEC}: test ${m}`))
  }
  const specSha = sha256(Buffer.from(specText, 'utf8'))
  if (problems.length) return { problems, verdict, fields: f, specSha, tests, files: null }
  let site
  try { site = renderSiteBundle(f, root) } catch (e) { return { problems: [`${PLAYER_SPEC}: the site bundle did not build: ${e.message}`], verdict, fields: f, specSha, tests, files: null } }
  const build = playerBuild(root, { [SITE_BUNDLE_OUT]: site })
  const files = [[PUBLIC_SPEC_OUT, specText], [SITE_BUNDLE_OUT, site]]
  f.PLAY_IDS.forEach((id, i) => {
    const imageSha = sha256(readFileSync(join(root, imageOf(f, id)))).slice(0, 12)
    files.push([pageOut(id), renderPage(f, i, { specSha, build, imageSha })])
  })
  return { problems, verdict, fields: f, specSha, tests, build, files }
}

async function main() {
  const check = process.argv.includes('--check')
  const json = process.argv.includes('--json')
  const specPath = join(SITE, PLAYER_SPEC)
  if (!existsSync(specPath)) { console.error(`play-from-spec: ${PLAYER_SPEC} is missing`); process.exit(1) }
  const analyze = await loadCompiler(readFileSync(join(SITE, WASM)))
  const specText = readFileSync(specPath, 'utf8')
  const out = await buildPlay({ specText, analyze })
  if (out.problems.length) {
    console.error(`play-from-spec: ${out.problems.length} problem(s)`)
    for (const p of out.problems) console.error('  ' + p)
    process.exit(1)
  }
  if (json) { console.log(JSON.stringify({ specSha: out.specSha, build: out.build, ...out.fields })); return }
  if (check) {
    const stale = out.files.filter(([rel, text]) => !existsSync(join(SITE, rel)) || readFileSync(join(SITE, rel), 'utf8') !== text)
    if (stale.length) {
      console.error(`play-from-spec --check: stale ${stale.map(([r]) => r).join(', ')}; run node scripts/play-from-spec.mjs`)
      process.exit(1)
    }
  } else {
    for (const [rel, text] of out.files) {
      mkdirSync(dirname(join(SITE, rel)), { recursive: true })
      writeFileSync(join(SITE, rel), text)
    }
  }
  console.log(`play-from-spec: ${check ? 'up to date' : 'wrote'} ${out.files.map(([r]) => r).join(', ')}; spec ${out.specSha.slice(0, 16)}; player build ${out.build}; ${out.fields.PLAY_COUNT} play(s): ${out.fields.PLAY_IDS.join(', ')}; spec tests ${out.tests.tests}, asserts ${out.tests.asserts}, all hold`)
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => { console.error(e); process.exit(1) })
}
