#!/usr/bin/env node
// t27c-mutation-casts.mjs -- record the nine "AI numbers" lessons 13 to 21 the way t27c-gfternary was made.
//
// Each recording runs, in a clean checkout of gHashTag/t27: the commit, `t27c --version && zig version`,
// the spec's hash and the lines it is about to change, `t27c test-report <spec>` (every test passes), a
// one-line `sed -i` mutation and its diff, `t27c test-report <spec>` again (exactly the test the lesson
// names fails), and `git checkout <spec> && sha256sum <spec>` (the same hash as before: the spec is back).
//
// It writes public/term/<id>/session.cast (asciicast v2), meta.json, index.html and card.png in the shape of
// the published recordings, and puts the nine at the top of public/term/index.html. Staged: the prompt and
// the typing. Real: every byte the command printed, at the time it printed it (stdout and stderr, as they
// arrived on the pipes). Nothing else is drawn by hand: the page's static screen and the card are the
// recorded bytes replayed through a small terminal of 104 x 30.
//
// It refuses to write a recording whose baseline does not pass every test, whose mutant does not fail
// exactly the named test, or whose checkout is not clean before and after: a recording that does not show
// what its lesson says is not published. There is no GIF: no GIF encoder is used here, so meta.json says
// "gif": null and the gallery links the card instead (widgets-from-spec.mjs).
//
// Run:  node scripts/t27c-mutation-casts.mjs --t27 DIR --t27c PATH --zig PATH [--where TEXT] [--only id,id]
//       node scripts/t27c-mutation-casts.mjs --index-only    (relist the nine in public/term/index.html)
//       CHROME=/path/to/chromium for the cards (as scripts/course-pages.mjs). A Chromium whose --window-size
//       is the window, not the page (Chrome 141 --headless=new), cuts the card short: chrome-headless-shell is exact.
import { spawn, spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { bareEnv } from './tri-help-casts.mjs'

const SITE = join(dirname(fileURLToPath(import.meta.url)), '..')
const PUBLIC = join(SITE, 'public')
const TERM = join(PUBLIC, 'term')
const ORIGIN = 'https://t27.ai'
const WIDTH = 104
const HEIGHT = 30
const MAX_IDLE = 2 // public/term/player.js: a silence longer than this is shown for this long
const PROMPT = '\u001b[38;2;255;215;0mt27 $ \u001b[0m'
const GOLD = '#ffd700'
const TEXT = '#ebebeb'
const TYPE_STEP_S = 0.0351
const CARD = { width: 1200, height: 630, rows: 17 }

// One row per lesson. `show` is the sed range printed before the run: the line the mutation changes and
// the test the lesson names (lesson 15 also shows the test that expects 512). `mutate` is the sed script;
// `fails` is the one test that must fail; `what` names the bug in the page's own words.
export const RECORDINGS = [
  { id: 't27c-gft-smul', spec: 'specs/ternary/gft_smul.t27', title: 't27c on gft_smul.t27 -- a sign is one bit, native', show: '110p;121p', mutate: 's/if (sgn != sb) { sgn = 1; } else { sgn = 0; }/sgn = 0;/', fails: 'm2', what: 'a sign that is always 0' },
  { id: 't27c-gft-sadd', spec: 'specs/ternary/gft_sadd.t27', title: 't27c on gft_sadd.t27 -- opposite signs subtract, native', show: '75p;120p', mutate: 's/} else { r = magsub(ma, mb); }/} else { r = magadd(ma, mb); }/', fails: 'a2', what: 'adding the sizes where opposite signs must subtract' },
  { id: 't27c-gft-signed-mac', spec: 'specs/ternary/gft_signed_mac.t27', title: 't27c on gft_signed_mac.t27 -- multiply, then add, native', show: '109p;138p;155p', mutate: 's/(sa ^ sb)/(sa | sb)/', fails: 'pp', what: 'OR in place of the sign XOR' },
  { id: 't27c-gft-relu', spec: 'specs/ternary/gft_relu.t27', title: 't27c on gft_relu.t27 -- a bend at zero, native', show: '12p;19p', mutate: 's/== 1) { return 0; }/== 1) { return x; }/', fails: 'negz', what: 'letting negative inputs through' },
  { id: 't27c-gft-exp2', spec: 'specs/ternary/gft_exp2.t27', title: 't27c on gft_exp2.t27 -- two to the x, native', show: '49p;64p', mutate: 's/k = 0 - ki; f = 0;/k = ki; f = 0;/', fails: 'em1', what: 'dropping the minus sign of k' },
  { id: 't27c-gft-argmax4', spec: 'specs/ternary/gft_argmax4.t27', title: 't27c on gft_argmax4.t27 -- pick the largest, native', show: '28p;50p', mutate: 's/ma > mb/ma >= mb/', fails: 'tie_low', what: '>= in place of > for two positive scores' },
  { id: 't27c-gft-nll', spec: 'specs/ternary/gft_nll.t27', title: 't27c on gft_nll.t27 -- a loss in bits, native', show: '88p;97p', mutate: 's/if (v == 0) { return 0; }/if (v == 0) { return 65536; }/', fails: 'perfect', what: 'a zero with the sign bit set from neg' },
  { id: 't27c-gft-sgd-step', spec: 'specs/ternary/gft_sgd_step.t27', title: 't27c on gft_sgd_step.t27 -- one step downhill, native', show: '118p;127p', mutate: 's/smul(eta, g)/smul(g, g)/', fails: 'ascend', what: 'g times g in place of eta times g' },
  { id: 't27c-gft-xornet', spec: 'specs/ternary/gft_xornet.t27', title: 't27c on gft_xornet.t27 -- XOR needs a bend, native', show: '137p;142p', mutate: 's/relu(z1)/z1/', fails: 'x00', what: 'removing relu from h1' },
]

/** The commands of one recording, in the order they run. */
export function commandsOf(r) {
  return [
    "git log -1 --format='%h %s' | cut -c1-100",
    't27c --version && zig version',
    `sha256sum ${r.spec} && sed -n '${r.show}' ${r.spec}`,
    `t27c test-report ${r.spec}`,
    `sed -i '${r.mutate}' ${r.spec} && git diff -U0 | tail -n 2`,
    `t27c test-report ${r.spec}`,
    `git checkout ${r.spec} && sha256sum ${r.spec}`,
  ]
}

// ------------------------------------------------------------------ what the report says

/** The counts `t27c test-report` prints, and the tests it names as failed. */
export function reportOf(text) {
  const num = (k) => { const m = new RegExp(`^\\s+${k}\\s+(\\d+)\\s*$`, 'm').exec(text); return m ? Number(m[1]) : null }
  const vac = /vacuous passes\s+(\d+) of (\d+)/.exec(text)
  return {
    tests: num('tests'), pass: num('pass'), fail: num('FAIL'),
    failed: [...text.matchAll(/^\s+FAIL\s{2}(\S+)\s*$/gm)].map((m) => m[1]),
    vacuous: vac ? Number(vac[1]) : null,
  }
}

/** Why a run does not show what its lesson says, or [] when it does. */
export function problemsOf(r, run) {
  const p = []
  const out = (i) => run.steps[i].chunks.map((c) => c.text).join('')
  const base = reportOf(out(3))
  const mutant = reportOf(out(5))
  const exits = run.steps.map((s) => s.exit)
  if (exits.some((e) => e !== '0')) p.push(`${r.id}: a command exited ${exits.join(' ')}`)
  if (!(base.tests > 0 && base.pass === base.tests && base.fail === 0)) p.push(`${r.id}: the baseline does not pass every test (${JSON.stringify(base)})`)
  if (!(mutant.fail === 1 && mutant.failed.length === 1 && mutant.failed[0] === r.fails)) p.push(`${r.id}: the mutant fails ${JSON.stringify(mutant.failed)}, not exactly ${r.fails}`)
  const diff = out(4).trim().split('\n')
  if (diff.length !== 2 || !diff[0].startsWith('-') || !diff[1].startsWith('+')) p.push(`${r.id}: the mutation is not a one-line change:\n${out(4)}`)
  const hashOf = (i) => (/^([0-9a-f]{64})\s/m.exec(out(i)) || [])[1]
  if (!hashOf(2) || hashOf(2) !== hashOf(6)) p.push(`${r.id}: the spec's hash after git checkout differs from the hash before`)
  return p
}

// ------------------------------------------------------------------ running

function run(command, cwd, env) {
  return new Promise((resolve) => {
    const t0 = process.hrtime.bigint()
    const at = () => Number(process.hrtime.bigint() - t0) / 1e9
    const chunks = []
    const child = spawn('bash', ['-c', command], { cwd, env, stdio: ['ignore', 'pipe', 'pipe'] })
    const take = (buf) => chunks.push({ at: at(), text: buf.toString('utf8') })
    child.stdout.on('data', take)
    child.stderr.on('data', take)
    child.on('error', (e) => resolve({ chunks: [{ at: at(), text: `${e.message}\n` }], exit: 'spawn-error', real: at() }))
    child.on('close', (code, signal) => resolve({ chunks, exit: String(code ?? signal), real: at() }))
  })
}

const gitClean = (cwd) => spawnSync('git', ['status', '--porcelain'], { cwd, encoding: 'utf8' }).stdout.trim() === ''

// ------------------------------------------------------------------ the cast

const num = (t) => { const s = Number(t.toFixed(4)).toString(); return s.includes('.') || s.includes('e') ? s : `${s}.0` }
// The published casts were written by Python's json.dumps: ", " between items, \u escapes.
const pyStr = (s) => JSON.stringify(s).replace(/[\u007f-￿]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, '0')}`)
const pyJson = (v) => {
  if (Array.isArray(v)) return `[${v.map(pyJson).join(', ')}]`
  if (v && typeof v === 'object') return `{${Object.entries(v).map(([k, x]) => `${pyStr(k)}: ${pyJson(x)}`).join(', ')}}`
  if (typeof v === 'string') return pyStr(v)
  return String(v)
}

/** Staged prompt and typing, then the real output and the exit of every command, as timed events. */
export function eventsOf(commands, steps, redact = (s) => s) {
  const ev = []
  let t = 0
  commands.forEach((cmd, i) => {
    ev.push([t, 'o', PROMPT])
    t += 0.4
    for (const ch of cmd) { ev.push([t, 'o', ch]); t += TYPE_STEP_S }
    t += 0.3
    ev.push([t, 'o', '\r\n'])
    const start = t
    for (const c of steps[i].chunks) ev.push([start + c.at, 'o', redact(c.text).replace(/\r?\n/g, '\r\n')])
    t = start + steps[i].real
    ev.push([t, 'x', steps[i].exit])
    t += 1
  })
  ev.push([t, 'o', PROMPT])
  return ev
}

export const castText = (header, events) => [pyJson(header), ...events.map(([t, k, s]) => `[${num(t)}, ${pyStr(k)}, ${pyStr(s)}]`)].join('\n') + '\n'

/** Seconds a viewer waits: every silence longer than MAX_IDLE counts as MAX_IDLE (player.js timeline). */
export function shownOf(events) {
  let shown = 0
  for (let i = 1; i < events.length; i++) shown += Math.min(events[i][0] - events[i - 1][0], MAX_IDLE)
  return shown
}

// ------------------------------------------------------------------ the screen

/** A 104 x 30 terminal that knows what these casts print: text, CR, LF, wrap, and SGR colour for the prompt. */
export class Screen {
  constructor(cols = WIDTH, rows = HEIGHT) { this.c = cols; this.r = rows; this.rows = Array.from({ length: rows }, () => this.blank()); this.x = 0; this.y = 0; this.fg = TEXT }
  blank() { return Array.from({ length: this.c }, () => [' ', TEXT]) }
  nl() { this.y += 1; if (this.y >= this.r) { this.rows.shift(); this.rows.push(this.blank()); this.y = this.r - 1 } }
  feed(s) {
    for (let i = 0; i < s.length; i++) {
      const ch = s[i]
      if (ch === '\u001b') {
        const m = /^\u001b\[([0-9;]*)m/.exec(s.slice(i, i + 40))
        if (m) { const ps = m[1].split(';').map(Number); this.fg = ps[0] === 38 && ps[1] === 2 ? `#${ps.slice(2, 5).map((v) => v.toString(16).padStart(2, '0')).join('')}` : TEXT; i += m[0].length - 1 }
        continue
      }
      if (ch === '\n') { this.nl(); this.x = 0 } else if (ch === '\r') this.x = 0
      else if (ch >= ' ') { if (this.x >= this.c) { this.nl(); this.x = 0 } this.rows[this.y][this.x] = [ch, this.fg]; this.x += 1 }
    }
    return this
  }
  /** Each row as runs of one colour; a row of spaces is empty. */
  runs() {
    return this.rows.map((row) => {
      if (row.every(([ch]) => ch === ' ')) return []
      const out = []
      for (const [ch, fg] of row) { const last = out[out.length - 1]; if (last && last.fg === fg) last.text += ch; else out.push({ fg, text: ch }) }
      return out
    })
  }
}

const screenAfter = (events, upTo = Infinity) => {
  const s = new Screen()
  for (const [t, k, text] of events) if (k === 'o' && t <= upTo) s.feed(text)
  return s
}

// ------------------------------------------------------------------ the page

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
const escAttr = (s) => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')
const escPre = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')

function noscriptOf(title, screen) {
  const rows = screen.runs().map((runs) => runs.map((r) => `<span style='color:${r.fg}'>${escPre(r.text)}</span>`).join(''))
  return `<noscript><figure style='margin:0 0 1.6em;border:1px solid rgba(255,255,255,.08);border-radius:12px;overflow:hidden;background:#000'><div style='padding:8px 12px;background:#0a0a0a;color:#888;font:12px system-ui;text-align:center;border-bottom:1px solid rgba(255,255,255,.08)'>${escPre(title)}</div><pre style='margin:0;padding:14px 16px;color:#ebebeb;background:#000;font:12px/1.25 Menlo,monospace;overflow-x:auto'>${rows.join('\n')}</pre></figure></noscript>`
}

// The style block of the published recording pages (public/term/t27c-gfternary/index.html), unchanged.
const STYLE = `<style>@font-face{font-family:Outfit;src:url(../../fonts/outfit-latin.woff2) format('woff2');font-weight:100 900;font-display:swap}
*{box-sizing:border-box}html,body{margin:0;background:#000;color:#ebebeb}
body{font:16px/1.6 Outfit,system-ui,sans-serif;background-image:linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);background-size:40px 40px}
main{max-width:980px;margin:0 auto;padding:28px 20px 64px}
a{color:#00ff88}a:hover{color:#fff}
.brand{display:flex;align-items:center;gap:10px;color:#fff;text-decoration:none;font-weight:700;font-size:20px}
.brand img{width:30px;height:30px}
.top{display:flex;justify-content:space-between;align-items:center;margin-bottom:28px}
.top .all{color:#888;font-size:14px;text-decoration:none}.top .all:hover{color:#00ff88}
h1{font-size:clamp(26px,4.4vw,42px);line-height:1.15;margin:0 0 10px;color:#fff}
.lede{color:#888;margin:0 0 22px;font-size:18px}
.facts{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0}
.facts span{border:1px solid rgba(255,255,255,.08);border-radius:999px;padding:3px 12px;font-size:13px;color:#bbb}
.facts b{color:#ffd700;font-weight:600}
.cmds{font:13px/1.5 'JetBrains Mono',Menlo,monospace;background:#0a0a0a;border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:12px 16px;margin:18px 0;white-space:pre-wrap;overflow-wrap:anywhere}
.cmds i{color:#ffd700;font-style:normal}
.honest{color:#888;font-size:14px;border-left:2px solid #00ff88;padding-left:12px}
.links{display:flex;flex-wrap:wrap;gap:10px;margin-top:22px}
.links a{border:1px solid rgba(255,255,255,.16);border-radius:8px;padding:6px 14px;text-decoration:none;font-size:14px}
.links a.x{background:#00ff88;color:#000;border-color:#00ff88;font-weight:600}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px}
.grid a{display:block;border:1px solid rgba(255,255,255,.08);border-radius:12px;overflow:hidden;text-decoration:none;color:#ebebeb;background:#050505}
.grid a:hover{border-color:#00ff88}.grid img{width:100%;display:block;aspect-ratio:1200/630}
.grid div{padding:10px 14px}.grid b{display:block;color:#fff}.grid small{color:#888}</style>`

export function pageHtml(meta, screen) {
  const edited = meta.redacted.length ? `Edited: ${meta.redacted.join('; ')}.` : 'Edited: nothing.'
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escPre(meta.title)} · Trinity S³AI</title>
<meta name="description" content="${escAttr(meta.desc)}">
<link rel="canonical" href="${meta.url}">
<link rel="icon" href="../../favicon.svg" type="image/svg+xml">
<meta property="og:type" content="article">
<meta property="og:site_name" content="Trinity S³AI">
<meta property="og:title" content="${escAttr(meta.title)}">
<meta property="og:description" content="${escAttr(meta.desc)}">
<meta property="og:url" content="${meta.url}">
<meta property="og:image" content="${meta.url}card.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${escAttr(meta.title)}: the terminal session it shows">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escAttr(meta.title)}">
<meta name="twitter:description" content="${escAttr(meta.desc)}">
<meta name="twitter:image" content="${meta.url}card.png">
<meta name="twitter:image:alt" content="${escAttr(meta.title)}: the terminal session it shows">
${STYLE}
</head>
<body>
<main>
<div class="top"><a class="brand" href="../../"><img src="../../favicon.svg" alt="">Trinity S³AI</a><a class="all" href="../">All recordings →</a></div>
<h1>${escPre(meta.title)}</h1>
<p class="lede">${escPre(meta.desc)}</p>
<div id="player">${noscriptOf(meta.title, screen)}</div>
<div class="facts"><span>recorded <b>${meta.recorded}</b></span><span>real <b>${meta.real_s} s</b></span><span>shown <b>${meta.shown_s} s</b></span><span>exit codes <b>${meta.exit_codes.join(' ')}</b></span></div>
<div class="cmds">${meta.commands.map((c) => `<i>$</i> ${esc(c)}`).join('\n')}</div>
<p class="honest">Staged: the prompt and the typing. Real: every byte the commands printed, at the time they printed it. Any silence longer than 2 s is shown for 2 s, and the title bar says so while it happens. ${edited} No GIF: this recording has none.</p>
<div class="links"><a href="card.png">Preview card</a></div>
</main>
<script type="module">
import { mount } from '../player.js'
mount(document.getElementById('player'), { src: 'session.cast', share: ${JSON.stringify(meta.url)}, title: ${JSON.stringify(meta.title)} })
</script>
</body>
</html>
`
}

// ------------------------------------------------------------------ the card

export function cardHtml(meta, screen) {
  const fonts = pathToFileURL(join(PUBLIC, 'fonts')).href
  const logo = pathToFileURL(join(PUBLIC, 'favicon.svg')).href
  const rows = screen.runs().slice(-CARD.rows)
  const body = rows.map((runs) => `<div class="r">${runs.map((r, i) => `<span style="color:${r.fg}">${escPre(i === runs.length - 1 ? r.text.replace(/\s+$/, '') : r.text)}</span>`).join('')}</div>`).join('')
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><style>
@font-face { font-family: 'Outfit'; font-weight: 100 900; src: url(${fonts}/outfit-latin.woff2) format('woff2'); }
@font-face { font-family: 'JetBrains Mono'; font-weight: 400 500; src: url(${fonts}/jetbrains-mono-latin.woff2) format('woff2'); }
* { margin: 0; box-sizing: border-box; }
html, body { width: ${CARD.width}px; height: ${CARD.height}px; overflow: hidden; background: #000; }
body { font-family: 'Outfit', sans-serif; color: #fff; padding: 28px 48px; background-image: linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.04) 1px, transparent 1px); background-size: 40px 40px; }
.top { display: flex; justify-content: space-between; align-items: center; height: 36px; }
.brand { display: flex; align-items: center; gap: 14px; font-weight: 700; font-size: 21px; } .brand img { width: 40px; height: 40px; }
.url { color: #ffd700; font-weight: 600; font-size: 19px; }
h1 { margin-top: 12px; font-size: 38px; font-weight: 700; line-height: 1.15; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
p { margin-top: 6px; font-size: 21px; color: #8a8a8a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.term { margin-top: 18px; height: 422px; border: 1px solid rgba(255,255,255,.14); border-radius: 12px; overflow: hidden; background: #000; }
.bar { display: flex; align-items: center; justify-content: space-between; height: 34px; padding: 0 12px; background: #0d0d0d; border-bottom: 1px solid rgba(255,255,255,.1); }
.dots i { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 7px; }
.badge { color: #00ff88; background: #002a17; border-radius: 10px; padding: 2px 10px; font-size: 14px; font-weight: 600; }
.scr { padding: 10px 18px; font: 15.5px/1.38 'JetBrains Mono', monospace; font-variant-ligatures: none; }
.r { white-space: pre; height: 1.38em; overflow: hidden; }
</style></head><body>
<div class="top"><div class="brand"><img src="${logo}">Trinity S³AI</div><div class="url">t27.ai/term/${meta.id}</div></div>
<h1>${escPre(meta.title)}</h1>
<p>${escPre(meta.desc)}</p>
<div class="term"><div class="bar"><span class="dots"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i></span><span class="badge">▶ recorded session · real output</span></div><div class="scr">${body}</div></div>
</body></html>`
}

function findChrome() {
  return [process.env.CHROME, '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium'].find((p) => p && existsSync(p))
}

// As scripts/course-pages.mjs renders its cards: headless Chromium, one screenshot, the process group killed.
async function render(chrome, html, png) {
  const work = mkdtempSync(join(tmpdir(), 'term-card-'))
  const src = join(work, 'card.html')
  writeFileSync(src, html)
  const before = existsSync(png) ? statSync(png).mtimeMs : 0
  const b = spawn(chrome, ['--headless=new', `--user-data-dir=${join(work, 'profile')}`, '--allow-file-access-from-files', '--hide-scrollbars',
    '--force-device-scale-factor=1', `--window-size=${CARD.width},${CARD.height}`, '--virtual-time-budget=3000', `--screenshot=${png}`, pathToFileURL(src).href], { stdio: 'ignore', detached: true })
  const deadline = Date.now() + 60_000
  while (Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 300))
    if (existsSync(png) && statSync(png).mtimeMs > before && statSync(png).size > 0) break
  }
  await new Promise((r) => setTimeout(r, 300))
  const exited = new Promise((r) => b.once('exit', r))
  try { process.kill(-b.pid, 'SIGKILL') } catch { b.kill('SIGKILL') }
  await Promise.race([exited, new Promise((r) => setTimeout(r, 5000))])
  try { rmSync(work, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }) } catch { /* a temp dir the OS will clear */ }
  if (!existsSync(png) || statSync(png).mtimeMs <= before) throw new Error(`t27c-mutation-casts: no card written to ${png}`)
}

// ------------------------------------------------------------------ the list of recordings

/** Put these recordings first in public/term/index.html, replacing their old rows; the count stays honest. */
export function indexWith(html, metas) {
  const row = (m) => `<a href="${m.id}/"><img src="${m.id}/card.png" alt="" loading="lazy"><div><b>${escPre(m.title)}</b><small>${m.recorded} · ${m.real_s} s real</small></div></a>`
  const ids = new Set(metas.map((m) => m.id))
  const lines = html.split('\n').filter((l) => { const m = /^<a href="([^"/]+)\/">/.exec(l); return !(m && ids.has(m[1])) })
  const at = lines.indexOf('<div class="grid">')
  if (at < 0) throw new Error('public/term/index.html has no <div class="grid">')
  // Newest first, as the list is kept; within one minute the later recording first.
  const sorted = metas.map((m, i) => [m, i]).sort(([a, i], [b, j]) => (a.recorded < b.recorded ? 1 : a.recorded > b.recorded ? -1 : j - i)).map(([m]) => m)
  lines.splice(at + 1, 0, ...sorted.map(row))
  const count = lines.filter((l) => /^<a href="[^"/]+\/"><img /.test(l)).length
  // The list's own preview is the newest recording's card.
  const newest = /^<a href="([^"/]+)\/">/.exec(lines[at + 1])[1]
  return lines.join('\n')
    .replace(/(the output is what the commands printed\. )\d+( so far\.)/, `$1${count}$2`)
    .replace(/(<meta (?:property="og:image"|name="twitter:image") content="https:\/\/t27\.ai\/term\/)[^/"]+(\/card\.png">)/g, `$1${newest}$2`)
}

// ------------------------------------------------------------------ main

async function main() {
  const arg = (k) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : undefined }
  const t27 = arg('--t27'), t27c = arg('--t27c'), zig = arg('--zig')
  const indexOnly = process.argv.includes('--index-only')
  const where = arg('--where') ?? 'a Claude Code cloud container (Linux x86_64)'
  const only = (arg('--only') ?? '').split(',').filter(Boolean)
  if (!indexOnly && (!t27 || !t27c || !zig)) { console.error('usage: t27c-mutation-casts.mjs --t27 DIR --t27c PATH --zig PATH [--where TEXT] [--only id,id]'); process.exit(2) }
  if (process.argv.includes('--index-only')) {
    // Rewrite only public/term/index.html from the meta.json the recordings already have.
    const metas = RECORDINGS.map((r) => JSON.parse(readFileSync(join(TERM, r.id, 'meta.json'), 'utf8')))
    writeFileSync(join(TERM, 'index.html'), indexWith(readFileSync(join(TERM, 'index.html'), 'utf8'), metas))
    console.log(`t27c-mutation-casts: listed ${metas.length} recording(s) in public/term/index.html`)
    return
  }
  const chrome = findChrome()
  if (!chrome) throw new Error('t27c-mutation-casts: no Chromium for the cards; set CHROME')
  if (!gitClean(t27)) throw new Error(`${t27} has uncommitted changes; record from a clean checkout so git checkout really restores the spec`)
  const home = mkdtempSync(join(tmpdir(), 't27c-cast-home-'))
  const env = { ...bareEnv(), HOME: home, COLUMNS: String(WIDTH), LINES: String(HEIGHT), PATH: `${dirname(t27c)}:${dirname(zig)}:/usr/bin:/bin` }
  const redactions = [[t27, '~/t27'], [home, '~'], [process.env.HOME ?? '/root', '~']].filter(([from]) => from && from !== '/')
  const todo = RECORDINGS.filter((r) => !only.length || only.includes(r.id))
  const metas = []
  const failures = []
  for (const r of todo) {
    const commands = commandsOf(r)
    const steps = []
    for (const c of commands) steps.push(await run(c, t27, env))
    const clean = gitClean(t27)
    const problems = problemsOf(r, { steps })
    if (!clean) problems.push(`${r.id}: the checkout is not clean after the recording`)
    if (problems.length) { failures.push(...problems); console.error(problems.join('\n')); continue }
    let edited = false
    const redact = (s) => redactions.reduce((out, [from, to]) => { if (out.includes(from)) { edited = true; return out.split(from).join(to) } return out }, s)
    const events = eventsOf(commands, steps, redact)
    const out = (i) => steps[i].chunks.map((c) => c.text).join('')
    const [t27cVersion, zigVersion] = out(1).trim().split('\n')
    const commit = out(0).trim().split(' ')[0]
    const base = reportOf(out(3))
    const recordedAt = new Date()
    const recorded = recordedAt.toISOString().replace('T', ' ').slice(0, 16) + ' UTC'
    const real = events[events.length - 1][0]
    const vacuous = base.vacuous === 0 ? 'none vacuous' : `${base.vacuous} vacuous`
    const meta = {
      id: r.id,
      title: r.title,
      desc: `${t27cVersion} and zig ${zigVersion} in ${where}, spec at t27 ${commit}: all ${base.tests} tests pass natively, ${vacuous}; ${r.what} makes exactly one test fail, ${r.fails}; git restores the spec.`,
      url: `${ORIGIN}/term/${r.id}/`,
      gif: null,
      post: null,
      recorded,
      real_s: Number(real.toFixed(1)),
      shown_s: Number(shownOf(events).toFixed(1)),
      commands,
      exit_codes: steps.map((s) => s.exit),
      redacted: edited ? ['home directory shown as ~'] : [],
      published: recordedAt.toISOString().slice(0, 10),
    }
    const header = { version: 2, width: WIDTH, height: HEIGHT, timestamp: Math.floor(recordedAt.getTime() / 1000), title: meta.title, commands, redacted: meta.redacted }
    const dir = join(TERM, r.id)
    mkdirSync(dir, { recursive: true })
    writeFileSync(join(dir, 'session.cast'), castText(header, events))
    writeFileSync(join(dir, 'meta.json'), JSON.stringify(meta, null, 2) + '\n')
    writeFileSync(join(dir, 'index.html'), pageHtml(meta, screenAfter(events)))
    // The card shows the moment the mutant's report has printed: the diff and the one failing test.
    const afterMutant = events.filter((e) => e[1] === 'x')[5][0]
    await render(chrome, cardHtml(meta, screenAfter(events, afterMutant)), join(dir, 'card.png'))
    metas.push(meta)
    console.log(`ok   ${r.id}: ${base.tests} pass, mutant fails ${r.fails}, ${meta.real_s} s real`)
  }
  if (metas.length) writeFileSync(join(TERM, 'index.html'), indexWith(readFileSync(join(TERM, 'index.html'), 'utf8'), metas))
  rmSync(home, { recursive: true, force: true })
  if (failures.length) { console.error(`t27c-mutation-casts: ${failures.length} recording(s) refused`); process.exit(1) }
  console.log(`t27c-mutation-casts: wrote ${metas.length} recording(s)`)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main()
