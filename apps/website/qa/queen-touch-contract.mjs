// Queen touch contract: a tap on the comb picks the cell under the finger, and
// a touch drag orbits without picking. Headless Chrome with touch emulation,
// CDP Input.dispatchTouchEvent, the served dist/ (build first, or --no-build).
// Written before the fix and shown to fail against the code it was written for.
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import { execSync } from 'node:child_process';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
if (!process.argv.includes('--no-build')) {
  console.log('  building…');
  execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] });
}
const CHROMES = [process.env.CHROME_PATH, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium', '/usr/bin/google-chrome', '/usr/bin/chromium'].filter(Boolean);
const CHROME = CHROMES.find(p => existsSync(p));
if (!CHROME) { console.log('  no Chrome found — skipping the touch check.'); process.exit(0); }
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json', '.woff2': 'font/woff2' };
const server = createServer((req, res) => {
  let f = join(DIST, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!existsSync(f) || statSync(f).isDirectory()) f = join(DIST, 'index.html');
  res.writeHead(200, { 'Content-Type': MIME[extname(f)] || 'application/octet-stream' });
  res.end(readFileSync(f));
}).listen(0, '127.0.0.1');
await new Promise(r => server.once('listening', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;
const profile = mkdtempSync(join(tmpdir(), 'touch-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--disable-extensions', '--mute-audio', '--window-size=1272,806', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const browserWs = await new Promise((resolve, reject) => { const t = setTimeout(() => reject(new Error('no port')), 30000); let buf = ''; chrome.stderr.on('data', d => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); resolve(m[1]); } }); });
const ws = new WebSocket(browserWs); await new Promise(r => ws.addEventListener('open', r));
let nextId = 0; const pending = new Map();
ws.addEventListener('message', ev => { const msg = JSON.parse(ev.data); if (msg.id && pending.has(msg.id)) { const { resolve, reject } = pending.get(msg.id); pending.delete(msg.id); msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result); } });
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => { const id = ++nextId; pending.set(id, { resolve, reject }); ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) })); });
const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
const call = (m, p) => send(m, p, sessionId);
const evaluate = async expr => { const r = await call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }); if (r.exceptionDetails) throw new Error('probe failed: ' + (r.exceptionDetails.exception?.description ?? r.exceptionDetails.text)); return r.result.value; };
const wait = ms => new Promise(r => setTimeout(r, ms));
const cleanup = () => { try { ws.close(); } catch {} chrome.kill(); server.close(); };

await call('Page.enable');
await call('Emulation.setDeviceMetricsOverride', { width: 1272, height: 806, deviceScaleFactor: 1, mobile: true });
await call('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
await call('Page.navigate', { url: `${ORIGIN}/?touch=1${process.env.QUEEN_ENGINE ? '&engine=' + process.env.QUEEN_ENGINE : ''}#/queen` });
let ready = false;
for (let i = 0; i < 60 && !ready; i++) { await wait(500); ready = await evaluate(`document.querySelectorAll('.queen27-sectors-row').length === 6 && !!document.querySelector('.queen27-comb-field canvas') && !!document.querySelector('.queen27-context-unit-text')`); }
if (!ready) { console.log('  Queen touch contract: FAIL (page never became ready - board or comb missing)'); cleanup(); process.exit(1); }
await wait(1500);
const rect = await evaluate(`(() => { const r = document.querySelector('.queen27-comb-field canvas').getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; })()`);
const selected = () => evaluate(`(() => { const u = document.querySelector('.queen27-context-unit-text'); const dd = document.querySelector('.queen27-context-stats dd'); return ((u && u.textContent) || '').replace(/\\s+/g, ' ').trim().slice(0, 80) + ' | ' + ((dd && dd.textContent) || '').trim(); })()`);
const tap = async (x, y) => { await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] }); await wait(40); await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await wait(140); };

const before = await selected();
const picks = new Set();
for (let gy = 0; gy < 5; gy++) for (let gx = 0; gx < 8; gx++) {
  const x = rect.x + rect.w * (0.18 + 0.64 * (gx / 7));
  const y = rect.y + rect.h * (0.10 + 0.40 * (gy / 4));
  await tap(x, y);
  const s = await selected();
  if (s !== before && !/THE QUEEN|КОРОЛЕВА/i.test(s)) picks.add(s);
}
// A touch drag must orbit, not pick: the selection after the drag equals the one before it.
const beforeDrag = await selected();
const sx = rect.x + rect.w * 0.5, sy = rect.y + rect.h * 0.3;
await call('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: sx, y: sy }] });
for (let k = 1; k <= 8; k++) { await call('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: sx + k * 14, y: sy + k * 4 }] }); await wait(25); }
await call('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
await wait(160);
const afterDrag = await selected();
const pageMoved = await evaluate(`document.documentElement.scrollTop !== 0 || document.documentElement.scrollLeft !== 0`);
cleanup();
const fails = [];
if (picks.size < 3) fails.push(`taps picked ${picks.size} distinct cells (need >= 3)`);
if (afterDrag !== beforeDrag) fails.push('a touch drag changed the pick');
if (pageMoved) fails.push('a touch drag scrolled the page');
if (fails.length) { for (const f of fails) console.log('  ✗ ' + f); console.log(`  Queen touch contract: FAIL (${fails.length})`); process.exit(1); }
console.log(`  Queen touch contract: PASS (taps picked ${picks.size} distinct cells; a drag kept "${afterDrag.slice(0, 40)}")`);
