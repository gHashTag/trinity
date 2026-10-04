// Queen round contract: when lastTick.decidedAt changes, the round tile and the
// gold block show the resolution strip and the is-resolved flash for ~6 s, then
// clear. Headless Chrome; /queen/status is intercepted with CDP Fetch and
// answers decidedAt A twice, then B. Written before the fix; shown to fail.
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
if (!CHROME) { console.log('  no Chrome found — skipping the round check.'); process.exit(0); }
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json', '.woff2': 'font/woff2' };
const server = createServer((req, res) => { let f = join(DIST, decodeURIComponent(new URL(req.url, 'http://x').pathname)); if (!existsSync(f) || statSync(f).isDirectory()) f = join(DIST, 'index.html'); res.writeHead(200, { 'Content-Type': MIME[extname(f)] || 'application/octet-stream' }); res.end(readFileSync(f)); }).listen(0, '127.0.0.1');
await new Promise(r => server.once('listening', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;
const profile = mkdtempSync(join(tmpdir(), 'round-'));
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

// The intercepted status: A for the first two answers, then B (a new round, allowed, 4 running).
let served = 0;
const status = decidedAt => ({ status: 'ok', swarmState: 'busy', scheduler: { enabled: true, intervalSeconds: 300, billingMode: 'coding_plan', estimatedUSDGateEnabled: false },
  lastTick: { decidedAt, allowed: true, refusal: null, skippedCount: 33, skipSummary: { claimed: 17, completed: 6, missingBoundary: 2, fileConflict: 1, incompleteSpec: 1, notFirst: 6 } },
  dispatches: { total: 124, finished: 120, running: 4, unreviewed: 1, latest: { issue: 1386, dispatchedAt: decidedAt, finishedAt: null, outcome: null } } });
const A = new Date(Date.now() - 200_000).toISOString();
const B = new Date(Date.now() - 1_000).toISOString();
listeners.push(async msg => {
  if (msg.sessionId !== sessionId || msg.method !== 'Fetch.requestPaused') return;
  const { requestId, request } = msg.params;
  if (!/\/queen\/status/.test(request.url)) { await call('Fetch.continueRequest', { requestId }); return; }
  served += 1;
  const body = Buffer.from(JSON.stringify(status(served <= 2 ? A : B))).toString('base64');
  await call('Fetch.fulfillRequest', { requestId, responseCode: 200, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Access-Control-Allow-Origin', value: '*' }], body });
});
await call('Page.enable');
await call('Fetch.enable', { patterns: [{ urlPattern: '*queen/status*', requestStage: 'Request' }] });
await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await call('Page.navigate', { url: `${ORIGIN}/?round=1#/queen` });
const probe = `(() => { const t = document.querySelector('.queen27-hud-res-round'); const g = document.querySelector('.queen27-hud-round'); return { served: null, tileResolved: !!t && t.classList.contains('is-resolved'), blockResolved: !!g && g.classList.contains('is-resolved'), strip: ((document.querySelector('.queen27-hud-round-strip') || {}).textContent || '').trim(), round: ((document.getElementById('stat-round') || {}).textContent || '').trim() }; })()`;
// wait for the first status answer to land (A) and no flash
let s = null; for (let i = 0; i < 40; i++) { await wait(500); s = await evaluate(probe); if (served >= 1 && /\d\d:\d\d:\d\d/.test(s.round)) break; }
const beforeSwitch = s;
// wait until B has been served, then watch for the flash within 20 s
for (let i = 0; i < 40 && served < 3; i++) await wait(500);
const tSwitch = Date.now(); let seen = null;
while (Date.now() - tSwitch < 20000) { await wait(250); s = await evaluate(probe); if (s.tileResolved && s.blockResolved) { seen = s; break; } }
let cleared = false;
if (seen) { const t0 = Date.now(); while (Date.now() - t0 < 9000) { await wait(500); s = await evaluate(probe); if (!s.tileResolved && !s.blockResolved) { cleared = true; break; } } }
cleanup();
const fails = [];
if (beforeSwitch.tileResolved || beforeSwitch.blockResolved) fails.push('flashing before any change of decidedAt');
if (!seen) fails.push(`no is-resolved within 20 s of a new decidedAt (served ${served})`);
else if (!/ALLOW|РАЗРЕШЕНО/.test(seen.strip) || !/33/.test(seen.strip)) fails.push(`strip text lacks the verdict or the skip count: "${seen.strip}"`);
if (seen && !cleared) fails.push('is-resolved did not clear within 9 s');
if (fails.length) { for (const f of fails) console.log('  ✗ ' + f); console.log(`  Queen round contract: FAIL (${fails.length})`); process.exit(1); }
console.log(`  Queen round contract: PASS (strip "${seen.strip.slice(0, 70)}", cleared ${cleared})`);
