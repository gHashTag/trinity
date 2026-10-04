// Engine spike measurement (loop cycle 011). Loads the comb twice in headless
// Chrome (swiftshader, the same GPU-less path every gate uses): the shipped
// canvas2D comb and the Babylon spike behind ?engine=babylon, at the two gate
// sizes that bracket the layout, and samples rAF intervals for 4 s. Prints
// p50/p95/p99 frame intervals, long frames (> 20 ms, i.e. a missed 60 Hz vsync), first-frame time and
// the brotli size of the babylon chunk. Not a pass/fail gate: a measurement
// the user reads. `--no-build` skips vite build.
import { execSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, statSync, mkdtempSync, readdirSync } from 'node:fs';
import { join, extname } from 'node:path';
import { tmpdir } from 'node:os';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
if (!process.argv.includes('--no-build')) { console.log('  building…'); execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] }); }
const CHROMES = [process.env.CHROME_PATH, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium', '/usr/bin/google-chrome', '/usr/bin/chromium'].filter(Boolean);
const CHROME = CHROMES.find(p => existsSync(p));
if (!CHROME) { console.log('  no Chrome found — skipping.'); process.exit(0); }
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json', '.woff2': 'font/woff2' };
const server = createServer((req, res) => { let f = join(DIST, decodeURIComponent(new URL(req.url, 'http://x').pathname)); if (!existsSync(f) || statSync(f).isDirectory()) f = join(DIST, 'index.html'); res.writeHead(200, { 'Content-Type': MIME[extname(f)] || 'application/octet-stream' }); res.end(readFileSync(f)); }).listen(0, '127.0.0.1');
await new Promise(r => server.once('listening', r));
const ORIGIN = `http://127.0.0.1:${server.address().port}`;

// chunk sizes
const assets = readdirSync(join(DIST, 'assets'));
const size = (re) => { const name = assets.find(a => re.test(a)); if (!name) return null; const raw = statSync(join(DIST, 'assets', name)).size; let br = null; try { br = Number(execSync(`brotli -q 11 -c "${join(DIST, 'assets', name)}" | wc -c`).toString().trim()); } catch {} return { name, raw, br }; };
const babylonChunk = size(/^QueenCombBabylon-|^babylon|^core-/i) || size(/QueenCombBabylon/);
const threeChunk = size(/^three-/);
const queenChunk = size(/^Queen-[A-Za-z0-9_-]+\.js$/);

const profile = mkdtempSync(join(tmpdir(), 'spike-'));
const GPU = process.argv.includes('--gpu');
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--disable-extensions', '--mute-audio', '--window-size=1440,900', ...(GPU ? ['--use-gl=angle', '--use-angle=metal', '--enable-gpu-rasterization', '--ignore-gpu-blocklist'] : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']), 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const browserWs = await new Promise((resolve, reject) => { const t = setTimeout(() => reject(new Error('no port')), 30000); let buf = ''; chrome.stderr.on('data', d => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); resolve(m[1]); } }); });
const ws = new WebSocket(browserWs);
await new Promise(r => ws.addEventListener('open', r, { once: true }));
let id = 0; const pending = new Map();
ws.addEventListener('message', ev => { const msg = JSON.parse(ev.data); if (msg.id && pending.has(msg.id)) { const { resolve, reject } = pending.get(msg.id); pending.delete(msg.id); msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result); } });
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => { const mid = ++id; pending.set(mid, { resolve, reject }); ws.send(JSON.stringify({ id: mid, method, params, sessionId })); });
const wait = ms => new Promise(r => setTimeout(r, ms));
const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
await send('Target.activateTarget', { targetId });
const call = (m, p) => send(m, p, sessionId);
const evaluate = async (expr) => { const r = await call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }); if (r.exceptionDetails) throw new Error(r.exceptionDetails.text); return r.result.value; };
await call('Page.enable'); await call('Runtime.enable');
await call('Emulation.setFocusEmulationEnabled', { enabled: true });
await call('Page.setWebLifecycleState', { state: 'active' }).catch(() => {});

const SIZES = [[1440, 900], [390, 844]];
const ENGINES = [['canvas2D', ''], ['babylon', 'engine=babylon']];
const pct = (arr, p) => { const s = [...arr].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; };
const rows = [];
for (const [w, h] of SIZES) for (const [name, q] of ENGINES) {
  await call('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 700 });
  const t0 = Date.now();
  await call('Page.navigate', { url: `${ORIGIN}/?spike=${Date.now()}${q ? '&' + q : ''}#/queen` });
  let ready = false;
  for (let i = 0; i < 80 && !ready; i++) { await wait(250); ready = await evaluate(name === 'babylon' ? `!!document.querySelector('[data-engine="babylon"][data-frames]') && Number(document.querySelector('[data-engine="babylon"]').getAttribute('data-frames')) > 5` : `!!document.querySelector('.queen27-comb-field canvas') && !!document.querySelector('.queen27-hud-viewport')`); }
  const readyMs = Date.now() - t0;
  if (!ready) { rows.push({ w, h, name, error: 'never ready' }); continue; }
  const firstFrame = name === 'babylon' ? await evaluate(`document.querySelector('[data-engine="babylon"]').getAttribute('data-first-frame-ms')`) : null;
  if (name === 'babylon' && w === 1440) { const r = await evaluate(`(() => { const gl = document.querySelector('[data-engine="babylon"] canvas').getContext('webgl2'); const d = gl && gl.getExtension('WEBGL_debug_renderer_info'); return d ? gl.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'n/a'; })()`); console.log('  renderer:', r); }
  await wait(1000);
  const samples = await evaluate(`new Promise(res => { const d = []; let last = performance.now(); const end = last + 4000; const step = (t) => { d.push(t - last); last = t; if (t < end) requestAnimationFrame(step); else res(d.slice(1)); }; requestAnimationFrame(step); })`);
  const long = samples.filter(x => x > 20).length;
  rows.push({ w, h, name, readyMs, firstFrame, n: samples.length, p50: pct(samples, 0.5).toFixed(1), p95: pct(samples, 0.95).toFixed(1), p99: pct(samples, 0.99).toFixed(1), max: Math.max(...samples).toFixed(1), long });
  if (w === 1440 && name === 'babylon') { const shot = await call('Page.captureScreenshot', { format: 'png' }); const { writeFileSync } = await import('node:fs'); writeFileSync('/tmp/hud-shots/spike-babylon-1440x900.png', Buffer.from(shot.data, 'base64')); }
}
chrome.kill(); server.close();
console.log('  chunks (raw / brotli -q 11):');
for (const [label, c] of [['babylon spike chunk', babylonChunk], ['three.js chunk (shipped today)', threeChunk], ['Queen page chunk', queenChunk]]) console.log(`    ${label.padEnd(30)} ${c ? `${c.name}  ${c.raw} / ${c.br}` : 'not found'}`);
console.log(`  frames (rAF intervals, 4 s, ${GPU ? 'GPU via ANGLE/Metal' : 'swiftshader'}):`);
for (const r of rows) console.log(r.error ? `    ${r.w}x${r.h} ${r.name.padEnd(9)} ${r.error}` : `    ${r.w}x${r.h} ${r.name.padEnd(9)} ready ${r.readyMs} ms${r.firstFrame ? ` first frame ${r.firstFrame} ms` : ''}  n=${r.n}  p50 ${r.p50}  p95 ${r.p95}  p99 ${r.p99}  max ${r.max}  long ${r.long}`);
process.exit(0);
