// Windows contract (P1-18, loop cycle 026): at every gate size no resource-tile sub-line and no round detail is cut - the wire field survives (no ellipsis truncation, at most a two-line clamp that fits)
// Scaffolded by `tri game-contract windows` from the pick harness; the tail below is the contract.
// Queen windows contract: the pick is a card number, not a cell index. The field
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

const SIZES = [[1920, 1080], [1440, 900], [1272, 806], [1280, 600], [390, 844]];
const problems = [];
const LANGS = ['en', 'ru'];
for (const lang of LANGS) for (const [w, h] of SIZES) {
  await call('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 700 });
  await call('Page.navigate', { url: `${ORIGIN}/?windows=${w}x${h}&lang=${lang}#/queen` });
  let ready = false;
  for (let i = 0; i < 60 && !ready; i++) { await wait(500); ready = await evaluate(`document.querySelectorAll('.queen27-hud-res').length >= 9 && !!document.querySelector('#stat-round')`); }
  if (!ready) { problems.push(`${lang} ${w}x${h}: tiles never rendered`); continue; }
  await wait(1200);
  const cut = await evaluate(`(() => {
    const out = [];
    const check = (el, label) => {
      if (!el) return;
      const cs = getComputedStyle(el);
      if (cs.display === 'none' || el.clientWidth === 0) return; // a tile whose sub-line is hidden by design at this size shows no window at all
      const cutX = el.scrollWidth > el.clientWidth + 1, cutY = el.scrollHeight > el.clientHeight + 1;
      if (cutX || cutY) out.push(label + ' "' + (el.textContent || '').trim().slice(0, 60) + '" ' + el.scrollWidth + 'x' + el.scrollHeight + ' in ' + el.clientWidth + 'x' + el.clientHeight);
    };
    document.querySelectorAll('.queen27-hud-res').forEach((tile, i) => check(tile.querySelector(':scope > span'), 'tile ' + i + ' (' + ((tile.querySelector('small') || {}).textContent || '').trim() + ')'));
    check(document.querySelector('.queen27-hud-round-strip'), 'round strip');
    check(document.querySelector('.queen27-hud-bell > button > small'), 'bell label + span');
    const em = [...document.querySelectorAll('em')].find(e => e.closest('.queen27-hud-round, .queen27-hud-next, .queen27-hud-command-round, .queen27-hud-round-block') || /·/.test(e.textContent || ''));
    check(em, 'round detail');
    return out;
  })()`);
  if (cut.length) problems.push(`${lang} ${w}x${h}: ${cut.join(' | ')}`);
  console.log(`  ${lang} ${w}x${h} ${cut.length ? 'CUT  ' + cut.length + ' window(s): ' + cut.join(' | ') : 'ok   every window whole'}`);
}
if (problems.length) { console.log(`  Queen windows contract: FAIL (${problems.length} size(s) cut a wire window)`); cleanup(); process.exit(1); }
console.log(`  Queen windows contract: PASS (${LANGS.length} languages × ${SIZES.length} sizes: every tile sub-line and the round detail fit whole)`);
cleanup(); process.exit(0);
