// Do the explorers keep the viewport contract, or does the CSS just claim to?
//
// The contract is specs/ui/viewport.t27 (vendored under public/t27/files), read
// here through `node scripts/viewport-from-spec.mjs --json` so the matrix and
// the thresholds are the spec's numbers and nothing is typed twice. The built
// site is opened in real Chrome at every size of VIEWPORTS, for the five
// catalog explorers and the spec explorer, each through its deep link, and the
// live DOM is asserted against:
//
//   - the document does not scroll sideways (scrollWidth <= clientWidth), and
//     no pane is wider than the viewport or scrolls sideways inside itself;
//   - phone and tablet: the document does not scroll at all (DOCUMENT_SCROLLS
//     = false) -- the panes are the scrollers;
//   - the deep-linked card is open and its top edge is inside the viewport;
//   - phone: exactly one pane (list OR card, never both); tablet and up: both;
//   - phone and tablet: every control in the explorer chrome is at least
//     TOUCH_TARGET_MIN_PX on each side. Inline links inside prose are exempt
//     (WCAG 2.5.8 exempts them the same way): a control is a button, select,
//     input, [role=button], or an anchor that is not display:inline;
//   - phone and tablet: at most one live vertical scroller per visible pane
//     (ONE_SCROLLER_PER_PANE). Desktop and wide are frozen by the P0 brief
//     (pixel-identical at 1280), so their nested scrollers and 80px document
//     scroll are reported as warnings, not failures.
//
// Queen (#/queen) is P1 and is not opened here; qa/queen-viewport-contract.mjs
// keeps its own rules.
//
//   npm run check:explorer-viewport               build, then check
//   npm run check:explorer-viewport -- --no-build reuse dist/
//
// The harness is qa/queen-viewport-contract.mjs's: serve dist over node:http,
// launch the installed Chrome with --headless=new, speak CDP over Node's
// WebSocket. No Chrome: exit 0 with "skipping", as the render check does.
// Screenshots land in /tmp/explorer-viewport-shots/ (or $SHOTS_DIR).
//
// The guard: a probe that matches nothing reports a broken selector, never a
// clean page. Zero controls, no explorer root or no card is a failure.
import { execFileSync, execSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import { tmpdir } from 'node:os';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
const SHOTS = process.env.SHOTS_DIR || '/tmp/explorer-viewport-shots';
const SETTLE_MS = Number(process.env.SETTLE_MS || 4000);

const CHROMES = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium',
].filter(Boolean);
const CHROME = CHROMES.find(p => existsSync(p));
if (!CHROME) {
  console.log('  no Chrome found — skipping the explorer viewport check. Set CHROME_PATH to force it.');
  process.exit(0);
}

// ── The contract, from the spec ──
const SPEC = JSON.parse(execFileSync(process.execPath, [join(ROOT, 'scripts/viewport-from-spec.mjs'), '--json'], { cwd: ROOT, encoding: 'utf8' }));
const tierOf = w => (w <= SPEC.PHONE_MAX ? 'phone' : w <= SPEC.TABLET_MAX ? 'tablet' : w <= SPEC.DESKTOP_MAX ? 'desktop' : 'wide');
const PANES = { phone: SPEC.PHONE_PANES, tablet: SPEC.TABLET_PANES, desktop: SPEC.DESKTOP_PANES, wide: SPEC.DESKTOP_PANES };
const SIZES = SPEC.VIEWPORTS.map(s => s.split('x').map(Number));
if (SIZES.length !== 6) { console.error(`  VIEWPORTS has ${SIZES.length} sizes, expected 6`); process.exit(1); }

// One deep link per explorer. The ids are entries every catalog build has
// carried since the explorers shipped; a missing one fails loudly below (no
// card), it does not pass quietly.
const EXPLORERS = [
  { name: 'tools', route: '#/tools?tool=mcp%2Fgitbutler', card: 'mcp/gitbutler' },
  { name: 'skills', route: '#/skills?skill=t27%2Ftri-pipeline', card: 't27/tri-pipeline' },
  { name: 'crons', route: '#/crons?cron=github-actions%2Ft27%2Fpr-dashboard', card: 'github-actions/t27/pr-dashboard' },
  { name: 'agents', route: '#/agents?agent=D', card: 't27/D' },
  { name: 'functions', route: '#/functions?function=content-detailed-script-generate', card: 'content-detailed-script-generate' },
  // The spec explorer marks no card; its open detail is the code view.
  { name: 'specs', route: '#/specs?spec=specs%2Ftutorial%2F02_functions.t27', card: null, detail: '.spec-x main' },
];

if (!process.argv.includes('--no-build')) {
  console.log('  building…');
  execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] });
}
if (!existsSync(join(DIST, 'index.html'))) {
  console.error('  dist/index.html missing — nothing to open.');
  process.exit(1);
}
mkdirSync(SHOTS, { recursive: true });

// ── Serve dist the way Pages serves it ──
const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.md': 'text/markdown',
  '.ico': 'image/x-icon', '.wasm': 'application/wasm', '.woff2': 'font/woff2', '.t27': 'text/plain',
};
const server = createServer((req, res) => {
  const path = normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
  let file = join(DIST, path);
  if (!file.startsWith(DIST) || !existsSync(file) || path === '/') file = join(DIST, 'index.html');
  try {
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream' });
    res.end(readFileSync(file));
  } catch { res.writeHead(404).end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;

// ── Chrome over CDP ──
const profile = mkdtempSync(join(tmpdir(), 'explorer-viewport-'));
const chrome = spawn(CHROME, [
  '--headless=new',
  '--remote-debugging-port=0',
  `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-extensions',
  '--disable-background-networking', '--disable-sync', '--mute-audio',
  '--window-size=1920,1080',
  ...(process.platform === 'linux' ? ['--no-sandbox', '--disable-dev-shm-usage'] : []),
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });

const browserWs = await new Promise((resolve, reject) => {
  const t = setTimeout(() => reject(new Error('Chrome never announced a debugging port')), 30000);
  let buf = '';
  chrome.stderr.on('data', d => {
    buf += d;
    const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) { clearTimeout(t); resolve(m[1]); }
  });
  chrome.on('exit', c => { clearTimeout(t); reject(new Error(`Chrome exited (${c}) before listening`)); });
});

const ws = new WebSocket(browserWs);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP socket refused')); });
let nextId = 0;
const pending = new Map();
const listeners = [];
ws.onmessage = ev => {
  const msg = JSON.parse(ev.data);
  if (msg.id !== undefined && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(`${msg.error.message}`)) : resolve(msg.result);
  } else if (msg.method) listeners.forEach(f => f(msg));
};
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const id = ++nextId;
  pending.set(id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});

const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
const call = (m, p) => send(m, p, sessionId);

const errors = [];
listeners.push(msg => {
  if (msg.sessionId !== sessionId) return;
  if (msg.method === 'Runtime.exceptionThrown') {
    const d = msg.params.exceptionDetails;
    errors.push(d.exception?.description || d.text || 'uncaught exception');
  }
});
await call('Runtime.enable');
await call('Page.enable');

const evaluate = async expr => {
  const r = await call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(`probe failed: ${r.exceptionDetails.text} ${r.exceptionDetails.exception?.description ?? ''}`);
  return r.result.value;
};
const sleep = ms => new Promise(r => setTimeout(r, ms));
const cleanup = () => {
  try { chrome.kill(); } catch { /* gone */ }
  server.close();
  // Chrome may still be writing its profile as it dies; a leftover temp dir is
  // not a contract failure.
  try { rmSync(profile, { recursive: true, force: true }); } catch { /* ENOTEMPTY race */ }
};

// Runs inside the page. Everything measured, nothing inferred from class names.
const PROBE = `(() => {
  const root = document.querySelector('.spec-x');
  if (!root) return { root: false };
  const de = document.documentElement;
  const vw = window.innerWidth, vh = window.innerHeight;
  const controls = [];
  for (const el of root.querySelectorAll('button, a, select, input, textarea, [role=button]')) {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) continue;
    const cs = getComputedStyle(el);
    if (el.tagName === 'A' && cs.display === 'inline') continue;
    controls.push({ tag: el.tagName.toLowerCase(), w: Math.round(r.width), h: Math.round(r.height), text: (el.getAttribute('aria-label') || el.textContent || '').trim().slice(0, 40) });
  }
  const scrollers = [];
  for (const el of root.querySelectorAll('*')) {
    const cs = getComputedStyle(el);
    // A textarea scrolls its own text; it is a control, not a pane.
    if (el.tagName === 'TEXTAREA') continue;
    if ((cs.overflowY === 'auto' || cs.overflowY === 'scroll') && el.scrollHeight > el.clientHeight + 1) {
      scrollers.push({ tag: el.tagName.toLowerCase(), cls: String(el.className).slice(0, 40), h: el.clientHeight, sh: el.scrollHeight });
    }
  }
  // A pane wider than the viewport, or scrolling sideways inside itself, is the
  // same defect the document check looks for one level down: the card's right
  // edge is off screen while document.scrollWidth stays clean.
  const wide = [];
  for (const el of root.querySelectorAll('.spec-x-pane, aside, main')) {
    const r = el.getBoundingClientRect();
    if (r.width === 0) continue;
    if (r.right > vw + 1 || el.scrollWidth > el.clientWidth + 1) wide.push({ tag: el.tagName.toLowerCase(), cls: String(el.className).slice(0, 40), right: Math.round(r.right), sw: el.scrollWidth, cw: el.clientWidth });
  }
  const asides = [...root.querySelectorAll('aside')].filter(a => a.getBoundingClientRect().width > 0);
  const mains = [...root.querySelectorAll('main')].filter(m => m.getBoundingClientRect().width > 0);
  const card = root.querySelector('[data-card]');
  const cr = card ? card.getBoundingClientRect() : null;
  const back = root.querySelector('.spec-x-back');
  const br = back ? back.getBoundingClientRect() : null;
  return {
    root: true, tier: root.dataset.tier || null,
    doc: { sw: de.scrollWidth, cw: de.clientWidth, sh: de.scrollHeight, ch: de.clientHeight, vw, vh },
    controls, scrollers, wide, panes: asides.length + mains.length, asides: asides.length, mains: mains.length,
    card: card ? card.dataset.card : null,
    cardRect: cr ? { top: Math.round(cr.top), left: Math.round(cr.left), right: Math.round(cr.right), bottom: Math.round(cr.bottom) } : null,
    back: br ? { w: Math.round(br.width), h: Math.round(br.height) } : null,
  };
})()`;

let failures = 0;
let warnings = 0;
console.log(`  spec ${SPEC.specSha.slice(0, 12)}  tiers phone<=${SPEC.PHONE_MAX} tablet<=${SPEC.TABLET_MAX} desktop<=${SPEC.DESKTOP_MAX}  target>=${SPEC.TOUCH_TARGET_MIN_PX}px  matrix ${SPEC.VIEWPORTS.join(' ')}`);
for (const [w, h] of SIZES) {
  const tier = tierOf(w);
  const compact = tier === 'phone' || tier === 'tablet';
  await call('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: compact });
  for (const x of EXPLORERS) {
    await call('Page.navigate', { url: `${ORIGIN}/?lang=en${x.route}` });
    await sleep(SETTLE_MS);
    let r;
    try { r = await evaluate(PROBE); } catch (e) { failures++; console.log(`  ${w}x${h} ${x.name.padEnd(9)} FAIL  ${e.message}`); continue; }
    const fail = [];
    const warn = [];
    if (!r.root) { failures++; console.log(`  ${w}x${h} ${x.name.padEnd(9)} FAIL  no .spec-x root rendered`); continue; }
    if (r.tier !== tier) fail.push(`data-tier=${r.tier} expected ${tier}`);
    if (r.doc.sw > r.doc.cw) fail.push(`document scrolls sideways: scrollWidth ${r.doc.sw} > clientWidth ${r.doc.cw}`);
    if (r.wide.length) (compact ? fail : warn).push(`${r.wide.length} pane(s) wider than the viewport or scrolling sideways: ${r.wide.map(p => `${p.tag}.${p.cls || '-'} right=${p.right} ${p.sw}/${p.cw}`).join(', ')}`);
    if (r.doc.sh > r.doc.ch) (compact && !SPEC.DOCUMENT_SCROLLS ? fail : warn).push(`document scrolls: scrollHeight ${r.doc.sh} > clientHeight ${r.doc.ch}`);
    // Panes: phone shows one, the others two.
    if (r.panes !== PANES[tier]) fail.push(`${r.panes} pane(s) visible (aside ${r.asides}, main ${r.mains}), spec says ${PANES[tier]}`);
    // The deep link opened its card, inside the viewport.
    if (x.card !== null) {
      if (r.card !== x.card) fail.push(`card ${JSON.stringify(r.card)} open, deep link named ${JSON.stringify(x.card)}`);
      else if (!r.cardRect || r.cardRect.top < 0 || r.cardRect.top >= r.doc.vh || r.cardRect.left < 0 || r.cardRect.right > r.doc.vw + 1) fail.push(`card not in viewport: ${JSON.stringify(r.cardRect)}`);
    } else if (r.mains !== 1) fail.push(`detail pane not open (${r.mains} main)`);
    if (tier === 'phone') {
      if (!r.back) fail.push('no .spec-x-back control on the card');
      else if (r.back.h < SPEC.BACK_CONTROL_MIN_PX || r.back.w < SPEC.BACK_CONTROL_MIN_PX) fail.push(`back control ${r.back.w}x${r.back.h} < ${SPEC.BACK_CONTROL_MIN_PX}`);
    }
    if (compact) {
      if (r.controls.length === 0) fail.push('zero controls matched — broken probe');
      const small = r.controls.filter(c => c.h < SPEC.TOUCH_TARGET_MIN_PX || c.w < SPEC.TOUCH_TARGET_MIN_PX);
      if (small.length) fail.push(`${small.length} target(s) < ${SPEC.TOUCH_TARGET_MIN_PX}px: ${small.slice(0, 4).map(c => `${c.tag} ${c.w}x${c.h} "${c.text}"`).join(', ')}`);
    }
    if (SPEC.ONE_SCROLLER_PER_PANE && r.scrollers.length > PANES[tier]) {
      (compact ? fail : warn).push(`${r.scrollers.length} live vertical scrollers for ${PANES[tier]} pane(s): ${r.scrollers.map(s => `${s.tag}.${s.cls || '-'} ${s.h}/${s.sh}`).join(', ')}`);
    }
    if (r.scrollers.length === 0 && x.card !== null) warn.push('no live scroller at all (short catalog?)');
    const shot = await call('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(SHOTS, `${x.name}-${w}x${h}.png`), Buffer.from(shot.data, 'base64'));
    if (fail.length) {
      failures++;
      console.log(`  ${w}x${h} ${x.name.padEnd(9)} FAIL  ${fail.join(' ; ')}${warn.length ? ' ; warn: ' + warn.join(' ; ') : ''}`);
    } else {
      warnings += warn.length;
      console.log(`  ${w}x${h} ${x.name.padEnd(9)} PASS  tier=${tier} panes=${r.panes} controls=${r.controls.length} scrollers=${r.scrollers.length}${warn.length ? '  warn: ' + warn.join(' ; ') : ''}`);
    }
  }
}

if (errors.length) {
  console.error(`\n  ${errors.length} uncaught exception(s) while probing:`);
  for (const e of errors.slice(0, 5)) console.error(`    ${e.split('\n')[0]}`);
  failures++;
}

cleanup();
if (failures) {
  console.error(`\n  Explorer viewport contract: FAIL (${failures} size/explorer combination(s))`);
  process.exit(1);
}
console.log(`\n  Explorer viewport contract: PASS (${SIZES.length} sizes × ${EXPLORERS.length} explorers, ${warnings} warning(s), screenshots in ${SHOTS})`);
process.exit(0);
