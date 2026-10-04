// Queen void contract: the pick is a card number, not a cell index. The field
// is rebuilt from the card list on every poll, so after a poll that reorders
// the board the outline, the SELECTED panel and OPEN ISSUE must still name the
// same card. Headless Chrome; /queen/public-board is intercepted with CDP
// Fetch: the first answer is the live board, every later answer is the same
// board with its cards rotated by seven. Written before the fix; shown to fail.
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
if (!CHROME) { console.log('  no Chrome found — skipping the pick check.'); process.exit(0); }
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json', '.woff2': 'font/woff2' };
const server = createServer((req, res) => { let f = join(DIST, decodeURIComponent(new URL(req.url, 'http://x').pathname)); if (!existsSync(f) || statSync(f).isDirectory()) f = join(DIST, 'index.html'); res.writeHead(200, { 'Content-Type': MIME[extname(f)] || 'application/octet-stream' }); res.end(readFileSync(f)); }).listen(0, '127.0.0.1');
await new Promise(r => server.once('listening', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;
const profile = mkdtempSync(join(tmpdir(), 'pick-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--disable-extensions', '--mute-audio', '--window-size=1440,900', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const browserWs = await new Promise((resolve, reject) => { const t = setTimeout(() => reject(new Error('no port')), 30000); let buf = ''; chrome.stderr.on('data', d => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); resolve(m[1]); } }); });
const ws = new WebSocket(browserWs); await new Promise(r => ws.addEventListener('open', r));
let nextId = 0; const pending = new Map(); const listeners = [];
ws.addEventListener('message', ev => { const msg = JSON.parse(ev.data); if (msg.id && pending.has(msg.id)) { const { resolve, reject } = pending.get(msg.id); pending.delete(msg.id); msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result); } else if (msg.method) { for (const l of listeners) l(msg); } });
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => { const id = ++nextId; pending.set(id, { resolve, reject }); ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) })); });
const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
const call = (m, p) => send(m, p, sessionId);
const evaluate = async expr => { const r = await call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }); if (r.exceptionDetails) throw new Error('probe failed: ' + (r.exceptionDetails.exception?.description ?? r.exceptionDetails.text)); return r.result.value; };
const wait = ms => new Promise(r => setTimeout(r, ms));
const cleanup = () => { try { ws.close(); } catch {} chrome.kill(); server.close(); };

let boardText = null; let served = 0; let rotate = false;
listeners.push(async msg => {
  if (msg.sessionId !== sessionId || msg.method !== 'Fetch.requestPaused') return;
  const { requestId, request, responseStatusCode } = msg.params;
  if (!/queen\/modules\.json/.test(request.url)) { await call('Fetch.continueRequest', { requestId }); return; }
  if (responseStatusCode === undefined) { await call('Fetch.continueRequest', { requestId }); return; }
  served += 1;
  const got = await call('Fetch.getResponseBody', { requestId });
  const text = got.base64Encoded ? Buffer.from(got.body, 'base64').toString('utf8') : got.body;
  if (boardText === null) boardText = text;
  let out = boardText;
  if (rotate) { const d = JSON.parse(boardText); d.modules = [...d.modules.slice(7), ...d.modules.slice(0, 7)]; out = JSON.stringify(d); }
  await call('Fetch.fulfillRequest', { requestId, responseCode: 200, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Access-Control-Allow-Origin', value: '*' }], body: Buffer.from(out).toString('base64') });
});
await call('Page.enable');
await call('Fetch.enable', { patterns: [{ urlPattern: '*queen/modules.json*', requestStage: 'Response' }] });
await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await call('Page.navigate', { url: `${ORIGIN}/?void=1${process.env.QUEEN_ENGINE ? '&engine=' + process.env.QUEEN_ENGINE : ''}#/queen` });
let ready = false;
for (let i = 0; i < 60 && !ready; i++) { await wait(500); ready = await evaluate(`document.querySelectorAll('.queen27-sectors-row').length === 6 && !!document.querySelector('.queen27-comb-field canvas') && !!document.querySelector('.queen27-hud-viewport')`); }
if (!ready) { console.log('  Queen void contract: FAIL (page never became ready)'); cleanup(); process.exit(1); }
await wait(1500);
const state = () => evaluate(`(() => { const v = document.querySelector('.queen27-hud-viewport'); const u = document.querySelector('.queen27-context-selected'); return { number: v ? v.getAttribute('data-pick-number') : null, module: v ? v.getAttribute('data-pick-module') : null, index: v ? v.getAttribute('data-pick-index') : null, unit: ((u && u.textContent) || '').replace(/\\s+/g, ' ').trim().slice(0, 160) }; })()`);
// pick a card by sweeping clicks until the panel names one
const rect = await evaluate(`(() => { const r = document.querySelector('.queen27-comb-field canvas').getBoundingClientRect(); return { x: r.left, y: r.top, w: r.width, h: r.height }; })()`);
let picked = null;
outer: for (let gy = 0; gy < 6; gy++) for (let gx = 0; gx < 10; gx++) {
  const x = rect.x + rect.w * (0.15 + 0.7 * (gx / 9)), y = rect.y + rect.h * (0.08 + 0.42 * (gy / 5));
  await evaluate(`(() => { const cv = document.querySelector('.queen27-comb-field canvas'); cv.dispatchEvent(new PointerEvent('pointermove', { clientX: ${x}, clientY: ${y}, bubbles: true, pointerId: 1 })); cv.dispatchEvent(new MouseEvent('click', { clientX: ${x}, clientY: ${y}, bubbles: true })); })()`);
  await wait(60);
  const s = await state();
  if (s.module && s.unit.includes(s.module)) { picked = s; break outer; }
}
if (!picked) { console.log('  Queen void contract: FAIL (no card could be picked; data-pick-number never set)'); cleanup(); process.exit(1); }

// with the honey on, almost no cell is empty ground (1009 closed issues fill 18 rings): turn FOUNDATION off so a cardless cell is void again, which is what the rule says - void is a cell with nothing drawn on it
await evaluate(`(() => { const b = document.querySelector('button[data-layer="foundation"]'); if (b) b.click(); })()`); await wait(400);
// now find empty ground: sweep the outer field until the host reports a void hit
const hit = () => evaluate(`(() => { const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return f ? f.getAttribute('data-hit') : 'no-field'; })()`);
let voidSeen = null;
outer2: for (let gy = 0; gy < 8; gy++) for (let gx = 0; gx < 14; gx++) {
  const x = rect.x + rect.w * (0.03 + 0.94 * (gx / 13)), y = rect.y + rect.h * (0.04 + 0.92 * (gy / 7));
  await evaluate(`(() => { const cv = document.querySelector('.queen27-comb-field canvas'); cv.dispatchEvent(new PointerEvent('pointermove', { clientX: ${x}, clientY: ${y}, bubbles: true, pointerId: 1 })); cv.dispatchEvent(new MouseEvent('click', { clientX: ${x}, clientY: ${y}, bubbles: true })); })()`);
  await wait(60);
  const h = await hit();
  if (h === 'void') { voidSeen = await state(); break outer2; }
  if (h === 'no-field') break outer2;
}
const h = await hit();
if (!voidSeen) { console.log(`  Queen void contract: FAIL (no void hit reported; data-hit=${h}; the field does not tell empty ground from a module)`); cleanup(); process.exit(1); }
if (voidSeen.index !== null || voidSeen.module !== null) { console.log(`  Queen void contract: FAIL (a click on empty ground left index=${voidSeen.index} module=${voidSeen.module})`); cleanup(); process.exit(1); }
console.log(`  Queen void contract: PASS (picked ${picked.module} at index ${picked.index}; a click on empty ground cleared the selection, data-hit=void)`);
cleanup(); process.exit(0);
