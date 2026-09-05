// Foundation contract (H-C1..: one honey hex per closed GitHub issue from the loop's snapshot, spiral by closedAt, the LAYER switch hides them)
// Scaffolded by `tri game-contract foundation` from the pick harness; the tail below is the contract.
// Queen foundation contract: the pick is a card number, not a cell index. The field
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
  if (/queen\/foundation\.json|queen\/public-foundation/.test(request.url)) return; // the foundation listener answers these
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
// the loop's snapshot is replaced by a fixture of 37 closed issues (wire order descending, closedAt ascending by number); the server route answers 404 so the page falls through to the file
const FIXTURE = { generatedAt: '2026-09-05T12:00:00Z', repo: 'gHashTag/trios', source: 'fixture', rings: ['SR-00', 'RUST-13'], closedIssues: Array.from({ length: 37 }, (_, i) => ({ number: 9037 - i, title: `fixture issue ${9037 - i}`, closedAt: new Date(Date.parse('2026-09-05T00:00:00Z') + (36 - i) * 60000).toISOString(), stateReason: 'COMPLETED', labels: [], epicRefs: [] })), epics: [], releases: [] };
listeners.push(async msg => {
  if (msg.sessionId !== sessionId || msg.method !== 'Fetch.requestPaused') return;
  const { requestId, request, responseStatusCode } = msg.params;
  if (/queen\/public-foundation/.test(request.url)) { await call('Fetch.fulfillRequest', { requestId, responseCode: 404, responseHeaders: [{ name: 'Access-Control-Allow-Origin', value: '*' }], body: '' }); return; }
  if (!/queen\/foundation\.json/.test(request.url) || responseStatusCode === undefined) return;
  await call('Fetch.fulfillRequest', { requestId, responseCode: 200, responseHeaders: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Access-Control-Allow-Origin', value: '*' }], body: Buffer.from(JSON.stringify(FIXTURE)).toString('base64') });
});
await call('Fetch.enable', { patterns: [{ urlPattern: '*queen/modules.json*', requestStage: 'Response' }, { urlPattern: '*queen/foundation.json*', requestStage: 'Response' }, { urlPattern: '*queen/public-foundation*', requestStage: 'Request' }] });
await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await call('Page.navigate', { url: `${ORIGIN}/?foundation=1${process.env.QUEEN_ENGINE ? '&engine=' + process.env.QUEEN_ENGINE : ''}#/queen` });
let ready = false;
for (let i = 0; i < 60 && !ready; i++) { await wait(500); ready = await evaluate(`document.querySelectorAll('.queen27-sectors-row').length === 6 && !!document.querySelector('.queen27-comb-field canvas') && !!document.querySelector('.queen27-hud-viewport')`); }
if (!ready) { console.log('  Queen foundation contract: FAIL (page never became ready)'); cleanup(); process.exit(1); }
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
if (!picked) { console.log('  Queen foundation contract: FAIL (no card could be picked; data-pick-number never set)'); cleanup(); process.exit(1); }


// (a) the page carries the snapshot: the viewport names the count, the moment and the source
let found = null;
for (let i = 0; i < 40 && !found; i++) { await wait(500); const v = await evaluate(`(() => { const s = document.querySelector('.queen27-hud-viewport'); return s ? s.getAttribute('data-foundation') : null; })()`); if (v && v.startsWith('37@')) found = v; }
if (!found) { const v = await evaluate(`(() => { const s = document.querySelector('.queen27-hud-viewport'); return s ? s.getAttribute('data-foundation') : 'no viewport'; })()`); console.log(`  Queen foundation contract: FAIL (the viewport does not carry the snapshot: data-foundation=${v}; expected 37@<generatedAt>:file)`); cleanup(); process.exit(1); }
if (!/:file$/.test(found) || !found.includes('2026-09-05T12:00:00Z')) { console.log(`  Queen foundation contract: FAIL (data-foundation=${found}: the source must be the file and the moment the snapshot's)`); cleanup(); process.exit(1); }
// (b) the field draws one cell per closed issue, in spiral order by closedAt: the host names the count and the first and last cells
let hostA = null;
for (let i = 0; i < 40 && !hostA; i++) { const a = await evaluate(`(() => { const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return f && f.getAttribute('data-foundation-cells') ? { cells: f.getAttribute('data-foundation-cells'), first: f.getAttribute('data-foundation-first'), last: f.getAttribute('data-foundation-last'), orient: f.getAttribute('data-hex-orient'), ratio: f.getAttribute('data-hex-ratio') } : null; })()`); if (a) hostA = a; else await wait(500); }
if (!hostA) { const why = await evaluate(`(() => { const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return f ? ['tile', f.getAttribute('data-tile'), 'orient', f.getAttribute('data-hex-orient'), 'error', f.getAttribute('data-foundation-error'), 'frames', f.getAttribute('data-frames'), 'cells', document.querySelectorAll('.queen27-comb-field').length].join(' ') : 'no field'; })()`); console.log(`  Queen foundation contract: FAIL (the field never reported data-foundation-cells: no honey drawn; ${why})`); cleanup(); process.exit(1); }
if (hostA.cells !== '37' || hostA.first !== '9001@1,0' || hostA.last !== '9037@4,0') { console.log(`  Queen foundation contract: FAIL (field cells=${hostA.cells} first=${hostA.first} last=${hostA.last}; expected 37, 9001@1,0, 9037@4,0)`); cleanup(); process.exit(1); }
// (c) a click on a honey cell picks the issue: CODE off (the fixture's issues lie under the module cells), sweep until data-hit=issue, the panel names the issue
await evaluate(`document.querySelector('button[data-layer="code"]').click()`); await wait(400);
let issuePick = null;
outerC: for (let gy = 0; gy < 8; gy++) for (let gx = 0; gx < 12; gx++) {
  const x = rect.x + rect.w * (0.2 + 0.6 * (gx / 11)), y = rect.y + rect.h * (0.08 + 0.4 * (gy / 7));
  await evaluate(`(() => { const cv = document.querySelector('.queen27-comb-field canvas'); cv.dispatchEvent(new PointerEvent('pointermove', { clientX: ${x}, clientY: ${y}, bubbles: true, pointerId: 1 })); cv.dispatchEvent(new MouseEvent('click', { clientX: ${x}, clientY: ${y}, bubbles: true })); })()`);
  await wait(80);
  const h = await evaluate(`document.querySelector('.queen27-comb-field[data-engine="babylon"]').getAttribute('data-hit')`);
  if (h === 'issue') { issuePick = await evaluate(`(() => { const v = document.querySelector('.queen27-hud-viewport'); const u = document.querySelector('.queen27-context-selected'); return { kind: v.getAttribute('data-pick-kind'), issue: v.getAttribute('data-pick-issue'), text: ((u && u.textContent) || '').replace(/\\s+/g, ' ').trim().slice(0, 200) }; })()`); break outerC; }
}
if (!issuePick) { console.log('  Queen foundation contract: FAIL (no click on the honey reported data-hit=issue with CODE off)'); cleanup(); process.exit(1); }
if (issuePick.kind !== 'issue' || !/^\d+$/.test(issuePick.issue || '') || !issuePick.text.includes('#' + issuePick.issue) || !issuePick.text.includes('fixture issue ' + issuePick.issue)) { console.log(`  Queen foundation contract: FAIL (an issue pick did not reach the panel: kind=${issuePick.kind} issue=${issuePick.issue} text="${issuePick.text.slice(0, 120)}")`); cleanup(); process.exit(1); }
await evaluate(`document.querySelector('button[data-layer="code"]').click()`); await wait(300);
// (d) the FOUNDATION button hides the honey: the section names the layers, the host shows 0
await evaluate(`document.querySelector('button[data-layer="foundation"]').click()`);
let hidden = null;
for (let i = 0; i < 20 && !hidden; i++) { await wait(250); const v = await evaluate(`(() => { const s = document.querySelector('.queen27-hud-viewport'); const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return { layers: s && s.getAttribute('data-layers'), shown: f && f.getAttribute('data-foundation-shown'), pressed: (document.querySelector('button[data-layer="foundation"]') || {}).getAttribute && document.querySelector('button[data-layer="foundation"]').getAttribute('aria-pressed') }; })()`); if (v.shown === '0' && v.layers && !v.layers.split(',').includes('foundation') && v.pressed === 'false') hidden = v; }
if (!hidden) { const v = await evaluate(`(() => { const s = document.querySelector('.queen27-hud-viewport'); const f = document.querySelector('.queen27-comb-field[data-engine="babylon"]'); return [s && s.getAttribute('data-layers'), f && f.getAttribute('data-foundation-shown')].join(' '); })()`); console.log(`  Queen foundation contract: FAIL (the FOUNDATION button did not hide the honey: layers/shown = ${v})`); cleanup(); process.exit(1); }
await evaluate(`document.querySelector('button[data-layer="foundation"]').click()`);
await wait(500);
// (e) the toolbar's zoom reaches the field: + then FIT VIEW
await evaluate(`document.querySelector('button[data-tool="in"]').click()`); await wait(300);
const zIn = await evaluate(`document.querySelector('.queen27-comb-field[data-engine="babylon"]').getAttribute('data-zoom')`);
await evaluate(`document.querySelector('button[data-tool="fit"]').click()`); await wait(300);
const zFit = await evaluate(`document.querySelector('.queen27-comb-field[data-engine="babylon"]').getAttribute('data-zoom')`);
if (zIn !== '1.25' || zFit !== '1.00') { console.log(`  Queen foundation contract: FAIL (zoom: + gave ${zIn}, FIT VIEW gave ${zFit}; expected 1.25 then 1.00)`); cleanup(); process.exit(1); }
console.log(`  Queen foundation contract: PASS (data-foundation=${found}; field ${hostA.cells} cells, first ${hostA.first}, last ${hostA.last}, tile ${hostA.orient} ratio ${hostA.ratio}; FOUNDATION off -> shown 0, layers ${hidden.layers}; zoom ${zIn} -> ${zFit}; issue #${issuePick.issue} picked and named; picked ${picked.module} at index ${picked.index})`);
cleanup(); process.exit(0);
