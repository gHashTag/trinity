// Is t27.ai/#/queen one screen, or did the CSS just claim to be?
//
// The page used to be twelve screens tall (documentElement.scrollHeight 12269
// at 1272x806). The single-screen HUD makes it exactly one: nothing scrolls
// except the named inner scrollers. Every rule that makes that true is CSS,
// and CSS is not proven by reading it. So this opens the built page in real
// Chrome at five device sizes, switches through every view, and asserts the
// contract from tabs-at-height §5.1 against the live DOM.
//
//   npm run check:queen-viewport              build, then check
//   npm run check:queen-viewport -- --no-build reuse dist/
//
// The harness is scripts/render-check.mjs's: serve dist over node:http, launch
// the installed Chrome with --headless=new, speak CDP over Node's WebSocket.
// No Playwright, no Puppeteer. Screenshots land in /tmp/hud-shots/.
//
// The guard at the bottom is the same as render-check's: a probe that matches
// nothing reports a broken selector, never a clean page. Zero command buttons,
// zero resource cells or zero sector rows is a failure.
import { execSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import { tmpdir } from 'node:os';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
const ROUTE = '#/queen';
const SHOTS = '/tmp/hud-shots';
const SIZES = [[1920, 1080], [1440, 900], [1272, 806], [1280, 600], [390, 844]];
const VIEWS = ['comb', 'kanban', 'map', 'factory', 'research'];
const DATA_WAIT_MS = 60000; // under the gate chain's load the sectors rows render late (the "sectors=0" readiness flake, cycles 015 and 035): a minute, like the windows gate
const SETTLE_MS = 700;

const CHROMES = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium',
].filter(Boolean);
const CHROME = CHROMES.find(p => existsSync(p));
if (!CHROME) {
  console.log('  no Chrome found — skipping the viewport check. Set CHROME_PATH to force it.');
  process.exit(0);
}

// --dead-api: build against an address that refuses every connection, then
// assert that no tile, count or stat renders a bare number while its endpoint
// is silent (data-honesty: absent reads as a dash, never 0), and that the
// status pill never reads LIVE. Only the sizes with the most counts run.
const DEAD = process.argv.includes('--dead-api');
if (!process.argv.includes('--no-build')) {
  console.log(DEAD ? '  building against a dead API…' : '  building…');
  execSync('npx vite build', {
    cwd: ROOT,
    stdio: ['ignore', 'ignore', 'inherit'],
    env: { ...process.env, ...(DEAD ? { VITE_QUEEN_API: 'http://127.0.0.1:1' } : {}) },
  });
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
  '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp',
  '.ico': 'image/x-icon', '.wasm': 'application/wasm', '.woff2': 'font/woff2',
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
const profile = mkdtempSync(join(tmpdir(), 'queen-viewport-'));
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
    errors.push((d.exception?.description || d.text || 'uncaught exception') + (d.stackTrace ? ' @ ' + d.stackTrace.callFrames.slice(0, 4).map(f => (f.url || '').split('/').pop() + ':' + f.lineNumber + ':' + f.columnNumber + (f.functionName ? ' ' + f.functionName : '')).join(' < ') : ''));
  }
});

await call('Runtime.enable');
await call('Page.enable');

const evaluate = async expr => {
  const r = await call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(`probe failed: ${r.exceptionDetails.text} ${r.exceptionDetails.exception?.description ?? ''}`);
  return r.result.value;
};
const wait = ms => new Promise(r => setTimeout(r, ms));

function cleanup() {
  try { ws.close(); } catch { /* already gone */ }
  chrome.kill();
  server.close();
  try {
    rmSync(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
  } catch (e) {
    console.error(`  (temporary profile could not be removed: ${e.code}; ignored)`);
  }
}

// ── The probe, from tabs-at-height §5.1, adapted to the HUD ──
//
// Scroll owners are declared by name. An element that overflows and is not
// on this list, and is not a designed truncation (text-overflow: ellipsis or
// a line clamp), is content the reader cannot reach.
const DECLARED = [
  // the HUD's own scrollers
  '.queen27-intel-list', '.queen27-sectors-list', '.queen27-context-col',
  '.queen27-hud-menu', '.queen27-hud-round-pop',
  // the views
  '.queen27-cards', '.queen27-kanban', '.queen27-mission-map',
  '.queen27-factory', '.queen27-factory-viewport', '.queen27-factory-bays ol', '.queen27-factory-modules',
  '.queen27-tech', '.queen27-tech-console', '.queen27-tech-map', '.queen27-tech-details',
  '.queen27-city-build-queue ol', '.queen27-hardware-foundry ol', '.queen27-city-console ol',
  '.queen27-city-head dl', '.queen27-city-build-queue dl', '.queen27-hardware-foundry dl', '.queen27-factory-command dl',
  '.queen27-activity-stream ol', '.queen27-flow-grid',
].join(', ');
// designed clippers: overflow:hidden boxes whose content is meant to be cut
const CLIPPERS = [
  '.queen27-hud-orbit', '.queen27-tech-node', '.queen27-factory-bus', '.queen27-factory-machine',
  '.queen27-context-portrait', '.queen27-city-canvas', '.queen27-comb-field',
].join(', ');
const PHONE_DECLARED = '.queen27-hud-top';

const PROBE = (phone) => `(() => {
  const de = document.documentElement;
  const fail = [];
  const A = (cond, msg, ...ctx) => { if (!cond) fail.push([msg, ...ctx].join(' ')); };
  const name = el => (el.id ? '#' + el.id : '') + (typeof el.className === 'string' && el.className ? '.' + el.className.trim().split(/\\s+/).join('.') : el.tagName.toLowerCase());
  const phone = ${phone ? 'true' : 'false'};

  // 1. The shell is exactly one viewport tall and does not scroll.
  A(de.scrollHeight <= de.clientHeight + 1, 'PAGE SCROLLS Y', de.scrollHeight, de.clientHeight);
  A(de.scrollWidth <= de.clientWidth + 1, 'PAGE SCROLLS X', de.scrollWidth, de.clientWidth);
  A(document.body.scrollHeight <= de.clientHeight + 1, 'BODY SCROLLS Y', document.body.scrollHeight);
  A(document.body.scrollWidth <= de.clientWidth + 1, 'BODY SCROLLS X', document.body.scrollWidth);

  // 2. The shell owns the viewport height, within one device pixel.
  const shell = document.querySelector('.queen27-page.is-shell');
  A(!!shell, 'SHELL MISSING');
  if (!shell) return { fail, counts: {} };
  A(Math.abs(shell.getBoundingClientRect().height - de.clientHeight) <= 1, 'SHELL NOT ONE VIEWPORT', Math.round(shell.getBoundingClientRect().height), de.clientHeight);
  A(getComputedStyle(document.body).paddingBottom === '0px', 'body padding-bottom SURVIVES', getComputedStyle(document.body).paddingBottom);

  // 3. The 60vh floor is gone from every section inside the shell.
  [...shell.querySelectorAll('section')].forEach(s =>
    A(getComputedStyle(s).minHeight === '0px', 'SECTION KEEPS A MIN-HEIGHT', name(s), getComputedStyle(s).minHeight));

  // 4. Exactly one view rendered.
  const body = shell.querySelector('.queen27-hud-vp-body');
  A(!!body, 'VIEWPORT BODY MISSING');
  const views = body ? body.querySelectorAll(':scope > .queen27-comb, :scope > .queen27-kanban, :scope > .queen27-mission-map, :scope > .queen27-factory, :scope > .queen27-tech') : [];
  A(views.length === 1, 'NOT EXACTLY ONE VIEW RENDERED', views.length);

  // 5. Every overflowing element inside the shell is a declared scroller or a designed truncation.
  const declared = ${JSON.stringify(DECLARED)} + (phone ? ', ' + ${JSON.stringify(PHONE_DECLARED)} : '');
  const clippers = ${JSON.stringify(CLIPPERS)};
  const undeclared = [];
  [...shell.querySelectorAll('*')].forEach(n => {
    if (!(n instanceof HTMLElement)) return;
    if (!(n.scrollHeight > n.clientHeight + 1 || n.scrollWidth > n.clientWidth + 1)) return;
    if (n.clientHeight === 0 && n.clientWidth === 0) return;         // inline boxes report 0/0
    if (n.matches(declared) || n.matches(clippers)) return;
    // inside a designed clipper everything is cut by design (the rotated orbit ring, the 3D canvas)
    if (n.parentElement && n.parentElement.closest(clippers) && shell.contains(n.parentElement.closest(clippers))) return;
    const cs = getComputedStyle(n);
    const truncates = cs.textOverflow === 'ellipsis' && cs.overflowX !== 'visible';
    const clamps = cs.webkitLineClamp && cs.webkitLineClamp !== 'none';
    if (truncates || clamps) return;
    undeclared.push(name(n) + '[' + n.scrollWidth + 'x' + n.scrollHeight + ' in ' + n.clientWidth + 'x' + n.clientHeight + ']');
  });
  A(undeclared.length === 0, 'UNDECLARED SCROLLER', undeclared.slice(0, 6).join(' | '));

  // 6. Nothing crosses the viewport edge unless a clipping ancestor INSIDE the shell clips it.
  const clipper = el => { for (let n = el.parentElement; n && n !== shell; n = n.parentElement) {
    const o = getComputedStyle(n); if (o.overflowX !== 'visible' || o.overflowY !== 'visible' || o.clipPath !== 'none') return n; } return null; };
  const escapes = [];
  [...shell.querySelectorAll('*')].forEach(el => {
    if (!(el instanceof HTMLElement)) return;
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    if ((r.right > de.clientWidth + 0.5 || r.left < -0.5 || r.bottom > de.clientHeight + 0.5 || r.top < -0.5) && !clipper(el))
      escapes.push(name(el) + '[' + Math.round(r.left) + ',' + Math.round(r.top) + '..' + Math.round(r.right) + ',' + Math.round(r.bottom) + ']');
  });
  A(escapes.length === 0, 'ESCAPES VIEWPORT', escapes.slice(0, 6).join(' | '));

  // 7. The status numbers are on screen.
  const required = phone ? ['round', 'bees'] : ['bees', 'accepted', 'verdicts', 'research', 'foundry', 'round', 'alerts', 'status'];
  required.forEach(id => {
    const n = document.getElementById('stat-' + id);
    A(!!n, 'STATUS SLOT MISSING: ' + id);
    if (!n) return;
    const r = n.getBoundingClientRect();
    A(r.top >= -0.5 && r.bottom <= de.clientHeight + 0.5 && r.left >= -0.5 && r.right <= de.clientWidth + 0.5 && r.width > 0, 'STATUS OFF SCREEN: ' + id, Math.round(r.left), Math.round(r.right));
  });

  // 8. Positive counts, so a broken selector is not a clean page.
  const counts = {
    shell: shell ? 1 : 0,
    commands: shell.querySelectorAll('.queen27-hud-command .queen27-hud-cmd').length,
    resources: shell.querySelectorAll('.queen27-hud-res').length,
    sectors: shell.querySelectorAll('.queen27-sectors-row').length,
    view: views.length,
  };
  // 9. Bare numbers where the feeding endpoint may be silent. Asserted only in
  // --dead-api mode; collected always so a live run can print them.
  const ZERO_SEL = '#stat-bees,#stat-accepted,#stat-verdicts,#stat-research,#stat-foundry,#stat-alerts,' +
    '.queen27-sectors-count,.queen27-column > header > span,.queen27-map-sector header b,' +
    '.queen27-hud-sector-text dd,.queen27-context-stats dd,.queen27-hud-minimap .queen27-hud-panel-head span:last-child';
  const zeros = [];
  for (const n of document.querySelectorAll(ZERO_SEL)) {
    const text = (n.textContent || '').replace(/\\s+/g, ' ').trim();
    if (/^[0-9]+(\\s*\\/\\s*[0-9]+)?(\\s*%|\\s*cards|\\s*карточ\\S*)?$/i.test(text)) zeros.push((n.id ? '#' + n.id : n.className || n.tagName) + '=' + text);
  }
  const live = !!document.querySelector('#stat-status.is-live');
  // 10. Raw fetch error strings in content slots. "Failed to fetch" is the
  // engine's English string; it must never be a column's, tile's or note's
  // text (it may live in a title attribute). Asserted in --dead-api mode.
  const RAW_SEL = '.queen27-cards em,.queen27-column em,.queen27-map-sector em,.queen27-hud-menu-note b,' +
    '.queen27-factory em,.queen27-factory p,.queen27-factory span,.queen27-hud-res span,.queen27-hud-res strong';
  const rawErrors = [];
  for (const n of document.querySelectorAll(RAW_SEL)) {
    const text = (n.textContent || '').replace(/\\s+/g, ' ').trim();
    if (/fetch|http[s ]|TypeError|NetworkError|Load failed|ECONN|status \\d{3}/i.test(text)) rawErrors.push((n.className || n.tagName) + '=' + text.slice(0, 60));
  }
  return { fail, counts, zeros, live, rawErrors, round: (document.getElementById('stat-round') || {}).textContent || '' };
})()`;

const CLICK = (view) => `(() => {
  const b = document.querySelector('.queen27-hud-command .queen27-hud-cmd[data-view="${view}"]');
  if (!b) return false;
  b.click();
  return true;
})()`;

let failures = 0;
for (const [w, h] of (DEAD ? SIZES.filter(([w]) => w === 1440 || w === 390) : SIZES)) {
  const phone = w < 600;
  await call('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: phone });
  // A distinct query string forces a full load at every size rather than a
  // hash-only navigation that keeps the previous document.
  await call('Page.navigate', { url: `${ORIGIN}/?v=${w}x${h}${ROUTE}` });
  await new Promise(r => {
    const t = setTimeout(r, 20000);
    listeners.push(m => { if (m.sessionId === sessionId && m.method === 'Page.loadEventFired') { clearTimeout(t); r(); } });
  });
  // Wait for the round slot and, when the backend answers, the live pill; the
  // countdown reads "—" until both endpoints have answered (and stays "—"
  // with the scheduler off), so the pill is the data signal, not the clock.
  const start = Date.now();
  let ready = false;
  while (Date.now() - start < DATA_WAIT_MS) {
    ready = await evaluate(`(() => {
      const n = document.getElementById('stat-round');
      const round = !!n && (n.textContent || '').trim().length > 0;
      const live = !!document.querySelector('#stat-status.is-live');
      const dead = !!document.querySelector('#stat-status.is-cold');
      const rows = document.querySelectorAll('.queen27-sectors-row').length;
      const data = ${DEAD} ? dead : (live || rows === 6);
      return round && data && document.querySelectorAll('.queen27-hud-cmd').length === 5;
    })()`);
    if (ready) break;
    await wait(250);
  }
  await wait(1200);

  for (const view of VIEWS) {
    const clicked = await evaluate(CLICK(view));
    if (!clicked) {
      console.log(`  ${w}x${h} ${view.padEnd(8)} FAIL  no command button for "${view}"`);
      failures++;
      continue;
    }
    await wait(SETTLE_MS);
    let result;
    try {
      result = await evaluate(PROBE(phone));
    } catch (e) {
      console.log(`  ${w}x${h} ${view.padEnd(8)} FAIL  ${e.message}`);
      failures++;
      continue;
    }
    const { fail, counts } = result;
    const zero = [];
    if (counts.shell !== 1) zero.push('shell');
    if (counts.commands !== 5) zero.push(`commands=${counts.commands}`);
    if (counts.resources < 7) zero.push(`resources=${counts.resources}`);
    if (!DEAD && !phone && w > 1100 && counts.sectors !== 6) zero.push(`sectors=${counts.sectors}`);
    if (DEAD && counts.sectors !== 0) fail.push(`sectors rendered without a board: ${counts.sectors}`);
    if (DEAD && result.live) fail.push('status pill reads LIVE with a dead API');
    if (DEAD) for (const z of result.zeros) fail.push('BARE ZERO ' + z);
    if (DEAD) for (const r of result.rawErrors || []) fail.push('RAW ERROR AS CONTENT ' + r);
    if (counts.view !== 1) zero.push(`views=${counts.view}`);
    const problems = [...fail, ...zero.map(z => 'COUNT ' + z)];
    if (view === 'comb' || (w === 1440 && h === 900)) {
      const shot = await call('Page.captureScreenshot', { format: 'png' });
      writeFileSync(join(SHOTS, `${DEAD ? 'dead-' : ''}${w}x${h}-${view}.png`), Buffer.from(shot.data, 'base64'));
    }
    if (problems.length) {
      failures++;
      console.log(`  ${w}x${h} ${view.padEnd(8)} FAIL  ${problems.join(' ; ')}`);
    } else {
      console.log(`  ${w}x${h} ${view.padEnd(8)} PASS  round=${result.round} cmd=${counts.commands} res=${counts.resources} sectors=${counts.sectors}`);
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
  console.error(`\n  Queen viewport contract: FAIL (${failures} size/view combination(s))`);
  process.exit(1);
}
console.log(`\n  Queen viewport contract: PASS (${SIZES.length} sizes × ${VIEWS.length} views, screenshots in ${SHOTS})`);
process.exit(0);
