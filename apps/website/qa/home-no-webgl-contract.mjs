// The landing without WebGL: the page renders, the scene is the only thing lost.
//
// Measured 2026-10-03 on a Chromium with no GPU (the remote browser pod on
// Railway, Chrome 151 on Linux): t27.ai/ loaded its entry bundle and then left
// #root empty, with "Uncaught Error: WebGL not supported" in the console. The
// throw came from Babylon's Engine, built by the comb that QueenHeroBlock
// mounts, and nothing between it and createRoot caught it -- so React unmounted
// the navigation, the copy, the FAQ and the footer for one decorative panel.
//
// Three loads of the built landing in headless Chrome, each in a fresh tab so
// the page's own WebGL answer (lib/webgl.ts) is asked again:
//
//   control         WebGL as the browser has it. The scene must be drawn: a
//                   contract that passes because the comb is never mounted for
//                   anyone proves nothing about the other two.
//   no-webgl        every getContext('webgl'|'webgl2') answers null, as it does
//                   on a GPU-less Chromium. The page renders, the comb's chunk
//                   is not fetched, nothing throws.
//   engine-refused  the probe is granted and the comb's own canvas is refused,
//                   so Babylon throws inside the effect. The boundary must take
//                   it: the page renders, the frame says the scene failed.
//
//   npm run check:home-no-webgl               build, then check
//   npm run check:home-no-webgl -- --no-build reuse dist/
//
// Written before the fix and shown to fail on it: no-webgl found an empty
// #root, as the pod did.
import { spawn, execSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
if (!process.argv.includes('--no-build')) { console.log('  building…'); execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] }); }
const CHROMES = [process.env.CHROME_PATH, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium', '/usr/bin/google-chrome', '/usr/bin/chromium'].filter(Boolean);
const CHROME = CHROMES.find(p => existsSync(p));
if (!CHROME) { console.log('  no Chrome found — skipping the no-WebGL check.'); process.exit(0); }
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json', '.woff2': 'font/woff2' };
const server = createServer((req, res) => { let f = join(DIST, decodeURIComponent(new URL(req.url, 'http://x').pathname)); if (!existsSync(f) || statSync(f).isDirectory()) f = join(DIST, 'index.html'); res.writeHead(200, { 'Content-Type': MIME[extname(f)] || 'application/octet-stream' }); res.end(readFileSync(f)); }).listen(0, '127.0.0.1');
await new Promise(r => server.once('listening', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;
const profile = mkdtempSync(join(tmpdir(), 'no-webgl-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--disable-extensions', '--mute-audio', '--window-size=1440,900', ...(process.platform === 'linux' ? ['--no-sandbox', '--disable-dev-shm-usage'] : []), '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const browserWs = await new Promise((resolve, reject) => { const t = setTimeout(() => reject(new Error('no port')), 30000); let buf = ''; chrome.stderr.on('data', d => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); resolve(m[1]); } }); });
const ws = new WebSocket(browserWs); await new Promise(r => ws.addEventListener('open', r));
let nextId = 0; const pending = new Map(); const listeners = [];
ws.addEventListener('message', ev => { const msg = JSON.parse(ev.data); if (msg.id && pending.has(msg.id)) { const { resolve, reject } = pending.get(msg.id); pending.delete(msg.id); msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result); } else if (msg.method) { for (const l of listeners) l(msg); } });
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => { const id = ++nextId; pending.set(id, { resolve, reject }); ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) })); });
const wait = ms => new Promise(r => setTimeout(r, ms));
const cleanup = () => { try { ws.close(); } catch {} chrome.kill(); server.close(); };

// Injected before any of the page's own scripts. Each answers null exactly
// where a browser without WebGL would, and leaves every other context alone --
// the starfield behind the page draws with '2d'.
const REFUSE = {
  control: null,
  'no-webgl': `(() => { const own = HTMLCanvasElement.prototype.getContext; HTMLCanvasElement.prototype.getContext = function (type, ...rest) { return /webgl/.test(String(type)) ? null : own.call(this, type, ...rest); }; })()`,
  'engine-refused': `(() => { const own = HTMLCanvasElement.prototype.getContext; HTMLCanvasElement.prototype.getContext = function (type, ...rest) { return /webgl/.test(String(type)) && this.classList.contains('queen-hive-scene') ? null : own.call(this, type, ...rest); }; })()`,
};

const PROBE = `(() => {
  const root = document.getElementById('root');
  const atlas = document.querySelector('.queen-hero-block-atlas');
  return {
    rootChildren: root ? root.childElementCount : -1,
    rootText: root ? root.innerText.trim().length : 0,
    title: (document.getElementById('queen-hero-title') || {}).textContent || null,
    nav: !!document.querySelector('nav'),
    footer: !!document.querySelector('footer'),
    scene: atlas ? atlas.getAttribute('data-scene') : null,
    snapshot: ((atlas && atlas.querySelector(':scope > small')) || {}).textContent || '',
    canvas: !!document.querySelector('canvas.queen-hive-scene'),
    combChunk: performance.getEntriesByType('resource').some(e => /QueenCatalogHive-|QueenCombBabylon-/.test(e.name)),
  };
})()`;

async function load(name) {
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const call = (m, p) => send(m, p, sessionId);
  const uncaught = [];
  listeners.push(msg => {
    if (msg.sessionId === sessionId && msg.method === 'Runtime.exceptionThrown') {
      const d = msg.params.exceptionDetails;
      uncaught.push(d.exception?.description?.split('\n')[0] || d.text);
    }
  });
  await call('Runtime.enable');
  await call('Page.enable');
  if (REFUSE[name]) await call('Page.addScriptToEvaluateOnNewDocument', { source: REFUSE[name] });
  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: `${ORIGIN}/?lang=en#/` });
  const evaluate = async () => { const r = await call('Runtime.evaluate', { expression: PROBE, returnByValue: true }); if (r.exceptionDetails) throw new Error('probe failed: ' + r.exceptionDetails.text); return r.result.value; };
  // Settled when the atlas has landed (the scene is only mounted after it) and
  // the scene has either drawn or been given up on; a blank page settles too,
  // by timeout, and is then judged on what it shows.
  let s = null;
  const t0 = Date.now();
  while (Date.now() - t0 < 30000) {
    await wait(500);
    s = await evaluate();
    const atlasLanded = /snapshot/.test(s.snapshot);
    if (atlasLanded && (s.canvas || s.scene !== 'webgl')) break;
  }
  // A throw from the engine arrives after the chunk and one effect; give it a
  // moment to arrive before calling the page quiet.
  await wait(2500);
  s = await evaluate();
  await send('Target.closeTarget', { targetId });
  return { ...s, uncaught };
}

const fails = [];
const results = {};
for (const name of Object.keys(REFUSE)) results[name] = await load(name);
cleanup();

const page = (name, s) => {
  if (s.rootChildren < 1 || s.rootText < 500) fails.push(`${name}: #root is blank (children ${s.rootChildren}, ${s.rootText} chars of text)`);
  if (!s.title) fails.push(`${name}: the Queen block's title is missing`);
  if (!s.nav || !s.footer) fails.push(`${name}: navigation ${s.nav ? 'present' : 'missing'}, footer ${s.footer ? 'present' : 'missing'}`);
  if (s.uncaught.length) fails.push(`${name}: uncaught ${s.uncaught.join(' | ')}`);
};

const c = results.control;
if (!c.canvas || c.scene !== 'webgl') fails.push(`control: the scene was not drawn with WebGL available (scene=${c.scene}, canvas=${c.canvas}) -- the other two cases would prove nothing`);
page('control', c);

const n = results['no-webgl'];
page('no-webgl', n);
if (n.scene !== 'none') fails.push(`no-webgl: the frame says data-scene=${n.scene}, not none`);
if (n.canvas) fails.push('no-webgl: a scene canvas was mounted with no WebGL to draw it');
if (n.combChunk) fails.push('no-webgl: the comb chunk was fetched for a scene that cannot be drawn');

const e = results['engine-refused'];
page('engine-refused', e);
if (e.scene !== 'failed') fails.push(`engine-refused: the frame says data-scene=${e.scene}, not failed -- the boundary did not see the throw`);

for (const [name, s] of Object.entries(results)) console.log(`  ${name.padEnd(15)} scene=${s.scene} canvas=${s.canvas} chunk=${s.combChunk} text=${s.rootText} uncaught=${s.uncaught.length}`);
if (fails.length) { for (const f of fails) console.log('  ✗ ' + f); console.log(`  Landing without WebGL: FAIL (${fails.length})`); process.exit(1); }
console.log('  Landing without WebGL: PASS (control draws; no WebGL and a refused engine both leave the page whole)');
