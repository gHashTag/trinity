// Castle contract (K-2..K-4): the 21 ring directories stand on spiral ring 7, towers by epic stage from the loop's snapshot; a missing snapshot shows plinths with dashes
// Scaffolded by `tri game-contract castle` from the pick harness; the tail below is the contract.
// Queen castle contract: the pick is a card number, not a cell index. The field
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
  if (/queen\/foundation\.json|queen\/public-foundation/.test(request.url)) return; // the castle listener answers these
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
// the loop's snapshot is replaced by a castle fixture: two rings, one epic bound by title with 3 of 5 children closed, one bound by label with no children, one release; the server route answers 404
let castleMode = 'fixture';
const CASTLE = { generatedAt: '2026-09-05T12:00:00Z', repo: 'gHashTag/trios', source: 'fixture', rings: ['SR-00', 'RUST-13'], closedIssues: Array.from({ length: 5 }, (_, i) => ({ number: 9101 + i, title: `castle issue ${9101 + i}`, closedAt: new Date(Date.parse('2026-09-05T00:00:00Z') + i * 60000).toISOString(), stateReason: 'COMPLETED', labels: [], epicRefs: [9001] })),
  epics: [
    { number: 9001, title: 'EPIC: RING-SR-00 has one source', state: 'open', closedAt: null, labels: [], ring: null, ringBy: null, children: [...Array.from({ length: 3 }, (_, i) => ({ number: 9101 + i, title: 'c', state: 'closed', closedAt: '2026-09-05T00:00:00Z' })), ...Array.from({ length: 2 }, (_, i) => ({ number: 9201 + i, title: 'o', state: 'open', closedAt: null }))] },
    { number: 9002, title: 'EPIC: one mesh', state: 'open', closedAt: null, labels: ['ring:RUST-13'], ring: null, ringBy: null, children: [] },
    { number: 9003, title: 'EPIC: nowhere', state: 'open', closedAt: null, labels: [], ring: null, ringBy: null, children: [] },
  ], releases: [{ tag: 'v6.0.0', name: 'trios-server v6.0.0', publishedAt: '2026-07-01T00:00:00Z', prerelease: false }] };
listeners.push(async msg => {
  if (msg.sessionId !== sessionId || msg.method !== 'Fetch.requestPaused') return;
  const { requestId, request, responseStatusCode } = msg.params;
  if (/queen\/public-foundation/.test(request.url)) { await call('Fetch.fulfillRequest', { requestId, responseCode: 404, responseHeaders: [{ name: 'Access-Control-Allow-Origin', value: '*' }], body: '' }); return; }
  if (!/queen\/foundation\.json/.test(request.url) || responseStatusCode === undefined) return;
  if (castleMode === 'missing') { await call('Fetch.fulfillRequest', { requestId, responseCode: 404, responseHeaders: [{ name: 'Content-Type', value: 'text/plain' }], body: '' }); return; }
  await call('Fetch.fulfillRequest', { requestId, responseCode: 200, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Access-Control-Allow-Origin', value: '*' }], body: Buffer.from(JSON.stringify(CASTLE)).toString('base64') });
});
await call('Fetch.enable', { patterns: [{ urlPattern: '*queen/modules.json*', requestStage: 'Response' }, { urlPattern: '*queen/foundation.json*', requestStage: 'Response' }, { urlPattern: '*queen/public-foundation*', requestStage: 'Request' }] });
await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await call('Page.navigate', { url: `${ORIGIN}/?castle=1${process.env.QUEEN_ENGINE ? '&engine=' + process.env.QUEEN_ENGINE : ''}#/queen` });
let ready = false;
for (let i = 0; i < 60 && !ready; i++) { await wait(500); ready = await evaluate(`document.querySelectorAll('.queen27-sectors-row').length === 6 && !!document.querySelector('.queen27-comb-field canvas') && !!document.querySelector('.queen27-hud-viewport')`); }
if (!ready) { console.log('  Queen castle contract: FAIL (page never became ready)'); cleanup(); process.exit(1); }
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
if (!picked) { console.log('  Queen castle contract: FAIL (no card could be picked; data-pick-number never set)'); cleanup(); process.exit(1); }


// the castle's testimony on the host
const castle = async () => evaluate(`(() => { const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return f ? { source: f.getAttribute('data-castle-source'), rings: f.getAttribute('data-castle-rings'), stages: f.getAttribute('data-castle-stages'), unassigned: f.getAttribute('data-castle-unassigned'), releases: f.getAttribute('data-castle-releases') } : null; })()`);
let c = null;
for (let i = 0; i < 60 && !(c && c.source); i++) { await wait(500); c = await castle(); }
if (!c || !c.source) { console.log('  Queen castle contract: FAIL (the field never reported data-castle-source: no castle drawn)'); cleanup(); process.exit(1); }
// K-4: the keep at the hub, a nameplate per plinth, a banner per release
const k4 = await evaluate(`(() => { const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return { keep: f.getAttribute('data-castle-keep'), plates: f.getAttribute('data-castle-plates'), banners: f.getAttribute('data-castle-banners') }; })()`);
if (k4.keep !== '1' || k4.plates !== '2' || k4.banners !== '1') { console.log(`  Queen castle contract: FAIL (keep=${k4.keep} plates=${k4.plates} banners=${k4.banners}; expected the keep, 2 nameplates, 1 banner)`); cleanup(); process.exit(1); }
// K-5: ring marks on the module cells under rings/<NAME> (castle layer) equal the served modules under the fixture's two rings
const k5 = await evaluate(`(async () => { const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); const mods = await fetch('./queen/modules.json', { cache: 'no-cache' }).then((r) => r.json()); const list = Array.isArray(mods) ? mods : mods.modules; const want = list.filter((m) => new RegExp('^rings/(SR-00|RUST-13)(/|$)').test(m.path)).length; return { marks: f.getAttribute('data-castle-marks'), want }; })()`);
if (k5.want < 1 || k5.marks !== String(k5.want)) { console.log(`  Queen castle contract: FAIL (ring marks ${k5.marks}, the served modules under SR-00/RUST-13 count ${k5.want})`); cleanup(); process.exit(1); }
// K-5: a pick on a child of epic 9001 draws the roots from the SR-00 tower to its 3 closed children (CODE off: the fixture's issues lie under the module cells)
await evaluate(`document.querySelector('button[data-layer="code"]').click()`); await wait(400);
const box = await evaluate(`(() => { const r = document.querySelector('.queen27-comb-field canvas').getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height }; })()`);
let roots = null;
outer: for (let rad = 0; rad <= Math.min(box.w, box.h) * 0.36; rad += 11) {
  const steps = rad === 0 ? 1 : Math.max(6, Math.round(rad / 4));
  for (let st = 0; st < steps; st += 1) {
    const ang = (Math.PI * 2 * st) / steps; const x = Math.round(box.x + Math.cos(ang) * rad), y = Math.round(box.y + Math.sin(ang) * rad);
    await evaluate(`(() => { const cv = document.querySelector('.queen27-comb-field canvas'); const o = { clientX: ${x}, clientY: ${y}, bubbles: true, pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0 }; cv.dispatchEvent(new PointerEvent('pointermove', o)); cv.dispatchEvent(new PointerEvent('pointerdown', o)); cv.dispatchEvent(new PointerEvent('pointerup', o)); cv.dispatchEvent(new MouseEvent('click', o)); })()`);
    await wait(90);
    const got = await evaluate(`(() => { const v = document.querySelector('[data-layers]'); const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return { issue: v && v.getAttribute('data-pick-issue'), roots: f.getAttribute('data-castle-roots') }; })()`);
    if (got.issue && ['9101', '9102', '9103'].includes(got.issue)) { roots = got.roots; break outer; }
  }
}
if (roots !== '9001:3') { console.log(`  Queen castle contract: FAIL (roots ${roots}; expected 9001:3 after picking a closed child of epic 9001)`); cleanup(); process.exit(1); }
await evaluate(`document.querySelector('button[data-layer="code"]').click()`); await wait(200);
if (c.source !== 'file' || c.rings !== '2' || c.stages !== 'RUST-13:plinth;SR-00:tower' || c.unassigned !== '1' || c.releases !== '1') { console.log(`  Queen castle contract: FAIL (source=${c.source} rings=${c.rings} stages=${c.stages} unassigned=${c.unassigned} releases=${c.releases}; expected file, 2, RUST-13:plinth;SR-00:tower, 1, 1)`); cleanup(); process.exit(1); }
// a missing snapshot: plinths with dashes, the source says none, no stages
castleMode = 'missing';
await call('Page.navigate', { url: `${ORIGIN}/?castle=none${process.env.QUEEN_ENGINE ? '&engine=' + process.env.QUEEN_ENGINE : ''}#/queen` });
let m = null;
for (let i = 0; i < 60 && !(m && m.source); i++) { await wait(500); m = await castle(); }
if (!m || m.source !== 'none' || m.stages) { console.log(`  Queen castle contract: FAIL (without the snapshot: source=${m && m.source} stages=${m && m.stages}; expected none and no stages)`); cleanup(); process.exit(1); }
console.log(`  Queen castle contract: PASS (2 rings on ring 7, stages ${c.stages}, ${c.unassigned} unassigned, ${c.releases} release; without the snapshot source=none)`);
cleanup(); process.exit(0);
