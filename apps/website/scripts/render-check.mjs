// Does the page actually render, or did the bundler just succeed?
//
// `vite build` was green through every one of A31-A37: four React branches that
// were statically dead, a roadmap panel that crashed, seventeen fields with
// `.toFixed()` called on undefined, and a production bundle pointing at
// localhost. Green means "modules resolved". Nothing in the pipeline ever
// opened the page.
//
// So this opens it. Build, serve dist the way Pages serves it, load #/canvas in
// real Chrome, click every collapsed panel one at a time, and fail on the first
// uncaught error or console.error -- naming the panel that was clicked when it
// appeared. A33's four dead panels are exactly the thing that only shows up
// after a click, which is why expanding is half the check.
//
//   npm run check:render          build, then check
//   npm run check:render -- --no-build   reuse dist/
//   npm run check:render -- --head       watch it happen
//
// ── Why there is no browser dependency here ──
//
// The obvious implementation is Playwright or Puppeteer. Measured, on this
// machine: puppeteer-core is 29 MB over 2221 files, playwright-core 14 MB over
// 112, and both still need a Chrome to drive. This repo has no test tooling at
// all -- devDependencies are eslint, typescript, vite and types -- so either
// one is the largest thing in it, added to run one script.
//
// Chrome is already installed, Chrome speaks CDP over a WebSocket, and Node 22
// has a WebSocket client built in. The part of CDP this needs is four domains
// and about a dozen messages. That is cheaper than the dependency, and it is
// the whole reason this check exists rather than staying a good intention in
// api-contract-check's header comment.
//
// The cost of that choice is that this file is bespoke: no upstream fixes it
// when Chrome changes. The guard against it rotting into a checker that always
// passes is at the bottom -- zero panels expanded is reported as a driver
// failure, never as a clean page.
//
// ── What it cannot see ──
//
// Wrong, not absent. It proves nothing threw; it does not read the screen. A36
// and A37 are invisible here: `0.618` hardcoded where a measurement belongs
// renders perfectly and throws nothing. Same for a panel that renders an empty
// box, a mislabelled unit, or a number in the wrong order of magnitude.
//
// Not console.error. A component that swallows its own failure and draws a dash
// is silent to this check by construction -- which is what A33's fix does on
// purpose. It catches the crash, not the emptiness the crash was hiding.
//
// Only what a click reveals. Panels behind a chat round-trip, or behind a route
// this file does not list, are never opened.
//
// The first run of this check found 0 panels and refused to call that a clean
// page -- which is the guard at the bottom working. /canvas defaults to the
// 'petals' layer, seven DOM nodes of constants ticker; every panel A31-A38 was
// about lives on 'tools', one of NINE layers reachable only by pressing 1-9.
// Six loops of fixes had gone into panels that the default view does not
// render. So this presses every layer key and expands what each one mounts.
//
// Localhost:8080 is expected to fail. A33: the deployed bundle fetches metrics
// from the visitor's own machine, so the fetch fails here too, and the mock
// path is what gets rendered. Network failures are therefore counted and shown,
// not fatal -- otherwise this would fail on every run for a reason it already
// knows about, and get muted within a week.
import { execSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import { tmpdir } from 'node:os';

const ROOT = new URL('..', import.meta.url).pathname;
const DIST = join(ROOT, 'dist');
const ROUTE = "#/canvas";
const HEADED = process.argv.includes('--head');
const MAX_PANELS = 80;      // a click that never expands anything must not loop forever
const SETTLE_MS = 250;      // per click: React commit + a frame, not a data fetch

// Chrome, wherever this Mac keeps it. No download, no bundled browser: if the
// developer has no Chrome, that is a fact to state, not to fix with 100 MB.
const CHROMES = [
  // First, so it can override rather than only fill a gap -- CI sets it, and
  // "set CHROME_PATH to force it" has to mean force.
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium',
].filter(Boolean);
const CHROME = CHROMES.find(p => existsSync(p));
if (!CHROME) {
  // Skip, do not fail. A missing browser is a fact about the environment, not
  // a defect in the change being made -- and a check that fails for a reason
  // it already knows about gets muted within a week.
  console.log('  no Chrome found — skipping the render check. Set CHROME_PATH to force it.');
  process.exit(0);
}

if (!process.argv.includes('--no-build')) {
  console.log('  building…');
  execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] });
}
if (!existsSync(join(DIST, 'index.html'))) {
  console.error('  dist/index.html missing — nothing to open.');
  process.exit(1);
}

// ── Serve dist the way Pages serves it ──
//
// Deliberately not `vite preview` and deliberately no COOP/COEP: the dev server
// sets those headers, GitHub Pages does not, and the bug this exists to catch
// is the one that only appears in the built, statically-served bundle.
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
const profile = mkdtempSync(join(tmpdir(), 'render-check-'));
const chrome = spawn(CHROME, [
  HEADED ? '--auto-open-devtools-for-tabs' : '--headless=new',
  '--remote-debugging-port=0',
  `--user-data-dir=${profile}`,
  '--no-first-run', '--no-default-browser-check', '--disable-extensions',
  '--disable-background-networking', '--disable-sync', '--mute-audio',
  '--window-size=1440,900',
  // three.js is on this page. Without a software GL fallback every WebGL
  // context fails to create and the check reports the headless environment as
  // a rendering bug.
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

// ── What counts as a failure ──
//
// Uncaught exceptions and console.error only. Everything else the browser calls
// an "error" -- a 404, a refused fetch, a CSP report -- is counted separately
// and printed, because A33's localhost:8080 fetch fails here on every single
// run and a check that cries wolf every run is a check nobody reads.
const errors = [];
const network = [];
const describe = a =>
  a.description || (a.value !== undefined ? String(a.value) : a.unserializableValue || a.type);
listeners.push(msg => {
  if (msg.sessionId !== sessionId) return;
  if (msg.method === 'Runtime.exceptionThrown') {
    const d = msg.params.exceptionDetails;
    const text = d.exception?.description || d.text || 'uncaught exception';
    errors.push({ kind: 'uncaught', text });
  } else if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') {
    const text = msg.params.args.map(describe).join(' ');
    // The app logging its own failure to reach localhost:8080 is the expected
    // condition here, not a finding -- pasWebSocket.ts opens
    // ws://localhost:8080/ws/pas, which cannot connect in this harness and, on
    // an HTTPS page, is blocked as mixed content before it is even tried. This
    // list stays SHORT and each entry names the endpoint it excuses; a broad
    // pattern here would mute the class of error this check exists to find.
    const ABSENT_BACKEND = [/^\[PAS WS\] Error/];
    if (ABSENT_BACKEND.some(re => re.test(text))) network.push(text);
    else errors.push({ kind: 'console.error', text });
  } else if (msg.method === 'Log.entryAdded' && msg.params.entry.level === 'error') {
    network.push(msg.params.entry.text);
  }
});

await call('Runtime.enable');
await call('Log.enable');
await call('Page.enable');

const drain = () => errors.splice(0, errors.length);
const evaluate = async expr => {
  const r = await call('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  // A throw inside our own probe is a bug in this file, not a finding about the page.
  if (r.exceptionDetails) throw new Error(`probe failed: ${r.exceptionDetails.text}`);
  return r.result.value;
};
const wait = ms => new Promise(r => setTimeout(r, ms));

console.log(`  ${ORIGIN}/${ROUTE} in ${CHROME.split('/').pop()}`);
await call('Page.navigate', { url: `${ORIGIN}/${ROUTE}` });
await new Promise(r => {
  const t = setTimeout(r, 20000);
  listeners.push(m => { if (m.sessionId === sessionId && m.method === 'Page.loadEventFired') { clearTimeout(t); r(); } });
});
await wait(1500);  // lazy chunks and the first data tick

const report = (label, found) => {
  console.error(`\n  ${found.length} error(s) ${label}:`);
  for (const e of found.slice(0, 8)) console.error(`    [${e.kind}] ${e.text.split('\n').slice(0, 4).join('\n      ')}`);
  if (network.length) console.error(`\n  (${network.length} network/resource error(s), not counted: ${network[0].slice(0, 90)}…)`);
  cleanup();
  process.exit(1);
};
function cleanup() {
  try { ws.close(); } catch { /* already gone */ }
  chrome.kill();
  server.close();
  rmSync(profile, { recursive: true, force: true });
}

const onLoad = drain();
if (onLoad.length) report('on load, before any click', onLoad);

// ── Every layer, not just the default one ──
//
// LAYER_KEYS is nine entries and keys 1-9 switch between them (TrinityCanvas
// line 681). switchLayer animates for ~200ms and sets a transition lock, so
// pressing faster than that silently drops layers -- which would look exactly
// like a layer with no panels.
const LAYERS = 9;
//
// And blur first. Layer 2 is the chat layer and it focuses its textarea on
// mount, so every digit after that gets TYPED INTO THE BOX instead of reaching
// the window handler. The symptom is indistinguishable from nine empty layers,
// which is exactly what the first run of this loop reported.
// Escape returns to 'petals' (TrinityCanvas line 684). Going home before each
// layer makes every switch a single hop from a known state.
//
// Walking 1..9 in sequence chains them, and one missed press shifts everything
// after it: a run reported the tools panels on layer 8 instead of 7, and the
// next run found nothing at all. A check whose results depend on nine
// consecutive successes is a check that reports the transition lock, not the
// page.
const escape = async () => {
  await evaluate('document.activeElement && document.activeElement.blur(), 1');
  for (const type of ['keyDown', 'keyUp'])
    await call('Input.dispatchKeyEvent', { type, key: 'Escape', code: 'Escape',
      windowsVirtualKeyCode: 27, nativeVirtualKeyCode: 27 });
  await wait(700);
};

const key = async (text) => {
  await evaluate('document.activeElement && document.activeElement.blur(), 1');
  for (const type of ['keyDown', 'keyUp'])
    await call('Input.dispatchKeyEvent', { type, text, key: text, code: `Digit${text}`,
      windowsVirtualKeyCode: text.charCodeAt(0), nativeVirtualKeyCode: text.charCodeAt(0) });
};

// ── Expand every collapsed panel, one at a time ──
//
// One at a time on purpose. Clicking them all and reading a stack trace off a
// minified bundle names a chunk; clicking one and reading the errors that
// appear next names the panel. That is the difference between "something on
// /canvas throws" and "CONSCIOUSNESS throws".
//
// A collapsed panel here is a `+` glyph inside a clickable header — there are
// no test ids on this page and adding them would be a second change riding on
// this one. Expanding may reveal further collapsed panels, so this re-queries
// after every click rather than taking a snapshot of the list up front.
const PROBE = `(() => {
  const next = [...document.querySelectorAll('span')].find(s =>
    s.textContent.trim() === '+' && !s.dataset.rcSeen && s.closest('[style*="cursor: pointer"], [style*="cursor:pointer"]'));
  if (!next) return null;
  next.dataset.rcSeen = '1';
  const header = next.closest('[style*="cursor: pointer"], [style*="cursor:pointer"]');
  const label = (header.textContent || '').replace(/\\s+/g, ' ').replace(/\\+$/, '').trim().slice(0, 48) || '(unlabelled)';
  header.click();
  return label;
})()`;

const expanded = [];
for (let layer = 1; layer <= LAYERS; layer++) {
  // Wait for the layer to have actually changed, not for a duration.
  //
  // switchLayer holds a `transitioning` lock across a 200ms fade and returns
  // early while it is set, so a fixed sleep races it: the same build gave 4
  // panels on one run and 0 on the next. A timing-flaky check is muted within
  // a week, so this presses, watches the DOM for a change, and presses again
  // if nothing moved -- and says so if it never does.
  await escape();
  const before = await evaluate('document.body.innerText.length');
  await key(String(layer));
  let changed = false;
  for (let t = 0; t < 14 && !changed; t++) {
    await wait(150);
    changed = (await evaluate('document.body.innerText.length')) !== before;
  }
  // ONE retry, and only after the transition lock has had time to clear.
  //
  // The first version pressed up to four times. Layer 1 is 'petals', which is
  // where /canvas already starts, so the press is a no-op and it pressed
  // again three more times -- each call re-entering switchLayer, which holds a
  // `transitioning` flag across a 200ms fade and returns early while it is
  // set. Hammering it left the flag stuck and every LATER layer silently
  // refused to switch: nine empty layers, reported twice in a row, from a
  // page that was fine.
  //
  // No change is also what "already on this layer" looks like, and that is not
  // a failure. Say so and move on rather than retrying into the lock.
  if (!changed) {
    await wait(700);
    await key(String(layer));
    await wait(900);
    changed = (await evaluate('document.body.innerText.length')) !== before;
    if (!changed) console.log(`  layer ${layer}: no DOM change (already there, or the switch is broken)`);
  }
  await wait(600);  // the first data tick of whatever mounted
  const arriving = drain();
  if (arriving.length) report(`on switching to layer ${layer}`, arriving);

  // Probe, and if a layer yields nothing, do the whole hop again before
  // believing it. Zero panels is the answer for most layers and a symptom on
  // the one that has them, and the check cannot tell those apart from a single
  // attempt -- runs alternated between 4 panels and 0 on an unchanged build.
  const countBefore = expanded.length;
  for (let attempt = 0; attempt < 2; attempt++) {
    if (attempt) {
      await escape();
      await key(String(layer));
      await wait(1400);
      drain();
    }
    for (let i = 0; i < MAX_PANELS; i++) {
      const label = await evaluate(PROBE);
      if (label === null) break;
      expanded.push(`${layer}:${label}`);
      await wait(SETTLE_MS);
      const found = drain();
      if (found.length) report(`after expanding "${label}" on layer ${layer}`, found);
    }
    if (expanded.length > countBefore) break;
  }
  console.log(`  layer ${layer}: ${expanded.length - countBefore} panel(s)`);
}

await wait(1000);  // whatever the newly-mounted panels do on their next tick
const late = drain();
if (late.length) report('after everything was expanded', late);

// ── The check that this check ran ──
//
// A probe that silently matches nothing reports a clean page, which is the
// failure mode the whole anomaly register is about (A34: "0 fields" was the
// regex, not the server). /canvas has collapsed panels. If none were found,
// the selector broke — say so, and fail.
console.log(`  expanded ${expanded.length} panel(s): ${expanded.join(' · ')}`);
if (expanded.length === 0) {
  console.error('\n  0 panels expanded across all nine layers. /canvas has collapsed panels,');
  console.error('  so this is a broken selector or a broken layer switch, not a clean page.');
  cleanup();
  process.exit(1);
}
if (network.length) console.log(`  ${network.length} network/resource error(s), expected — see A33: ${network[0].slice(0, 70)}…`);
console.log(`  no uncaught errors and no console.error across ${expanded.length} panels.`);
cleanup();
process.exit(0);
