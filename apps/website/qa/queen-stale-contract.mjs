// Queen pick contract: the pick is a card number, not a cell index. The field
// is rebuilt from the card list on every poll, so after a poll that reorders
// the board the outline, the SELECTED panel and OPEN ISSUE must still name the
// same card. Headless Chrome; /queen/public-board is intercepted with CDP
// Fetch: the first answer is the live board, every later answer is the same
// Stale contract (P1-12): after a first successful board poll the board is
// blocked; within 10 s the viewport head must carry a STALE badge with an age
// while the status pill (its endpoint untouched) still reads LIVE. Written
// before the fix; shown to fail on the old dist.
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
const profile = mkdtempSync(join(tmpdir(), 'stale-'));
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

let served = 0; let block = false;
listeners.push(async msg => {
  if (msg.sessionId !== sessionId || msg.method !== 'Fetch.requestPaused') return;
  const { requestId, request } = msg.params;
  if (!/\/queen\/public-board/.test(request.url) || !block) { await call('Fetch.continueRequest', { requestId }); if (/\/queen\/public-board/.test(request.url)) served += 1; return; }
  await call('Fetch.failRequest', { requestId, errorReason: 'Failed' });
});
await call('Page.enable');
await call('Fetch.enable', { patterns: [{ urlPattern: '*queen/public-board*', requestStage: 'Request' }] });
await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await call('Page.navigate', { url: `${ORIGIN}/?stale=1#/queen` });
let ready = false;
for (let i = 0; i < 60 && !ready; i++) { await wait(500); ready = await evaluate(`document.querySelectorAll('.queen27-sectors-row').length === 6 && !!document.querySelector('.queen27-hud-viewport')`); }
if (!ready) { console.log('  Queen stale contract: FAIL (page never became ready)'); cleanup(); process.exit(1); }
const state = () => evaluate(`(() => { const b = document.querySelector('.queen27-hud-vp-head [data-stale]'); const r = b ? b.getBoundingClientRect() : null; return { badge: b ? (b.textContent || '').replace(/\\s+/g, ' ').trim() : null, age: b ? b.getAttribute('data-stale') : null, visible: !!(r && r.width > 0 && r.height > 0), live: !!document.querySelector('#stat-status.is-live') }; })()`);
const before = await state();
const fails = [];
if (before.badge !== null) fails.push(`a STALE badge showed while polls succeed: "${before.badge}"`);
if (!before.live) fails.push('the status pill did not read LIVE before the block (the harness itself is broken)');
block = true;
let after = null;
for (let i = 0; i < 40; i++) { await wait(250); after = await state(); if (after.badge !== null) break; }
cleanup();
if (after.badge === null) fails.push('no STALE badge within 10 s of the board being blocked');
else {
  if (!/\d\d:\d\d/.test(after.badge)) fails.push(`the badge carries no age: "${after.badge}"`);
  if (!after.visible) fails.push('the badge is in the DOM but not visible');
  if (!(Number(after.age) >= 0)) fails.push(`data-stale is not a number: ${after.age}`);
}
if (after && !after.live) fails.push('the status pill stopped reading LIVE although only the board was blocked');
if (fails.length) { for (const f of fails) console.log('  ✗ ' + f); console.log(`  Queen stale contract: FAIL (${fails.length})`); process.exit(1); }
console.log(`  Queen stale contract: PASS (badge "${after.badge}" ${after.age}s after the board was blocked; pill still LIVE)`);
