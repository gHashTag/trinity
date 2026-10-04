// Does every Queen tab show one spec corpus?
//
// The owner's report, 2026-09-30: the specs were not in sync across the tabs of
// /game. Measured before src/lib/queenCorpus.ts: the shell read t27/manifest.json,
// the Spec Explorer frame inside it read the same 1.8 MB again, the Specs
// directive a third time, and the comb and the hero block each read the universe
// atlas themselves -- five holders, no statement that any two of them were the
// same scan. The SPECS rung printed `ladder.specs` from a sixth file. Every number
// happened to be 1577 because one scan wrote every file; nothing said so.
//
// This contract says so, four ways, and proves each way can fail:
//
//   A  the files: the manifest, the universe atlas, the shared core and the five
//      spec-* ladders describe one scan -- same count, atlas and core built from
//      the very bytes of the served manifest, every world of the comb counting
//      what the Explorer lists for it (src/lib/queenCorpusCheck.ts);
//   B  the source: only src/lib/queenCorpus.ts names the four corpus files, so
//      no tab can grow a private copy again;
//   C  the store: a part is fetched once however many tabs ask, a failed first
//      read is retried, a failed poll keeps the part on show, and the version the
//      store prints is the files' own;
//   D  the address: a tab switch keeps spec= and drops the other tabs' cards, and
//      the world chosen in the shell rides into the Explorer frame's hash.
//
//   N  negative fixtures: a stale ladder, an atlas from another manifest, a comb
//      world that disagrees, a rogue fetch in a component, a tab reading 1576 --
//      each must be reported, and the whole contract run against a stale copy of
//      public/ must exit 1. A check that has never failed has not been shown to work.
//
//   --browser  E  the built page in real Chrome: on every Queen tab the shell's
//      root and, on SPECS, the Explorer frame's root report the same
//      data-spec-count and data-corpus-version; the manifest is fetched once for
//      the whole window tree; a world written into the shell's address narrows the
//      frame's list to exactly the comb's count for that world.
//
//   npm run check:queen-spec-sync                          A-D and N, no browser
//   npm run check:queen-spec-sync -- --browser             and E (builds first)
//   npm run check:queen-spec-sync -- --browser --no-build  E on the existing dist/
//   node --experimental-strip-types qa/queen-spec-sync-contract.mjs --public=DIR
//                                                          A against another tree
//
// Exit 0: every check passed. 1: a check failed. 2: the check could not run (no
// Chrome, no page) -- never read that as a pass.
import { execSync, spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, extname, join, normalize, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import { corpusDisagreements, corpusIdentity, corpusVersion, specWorld } from '../src/lib/queenCorpusCheck.ts';
import { specExplorerHash } from '../src/lib/specCatalog.ts';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const SELF = fileURLToPath(import.meta.url);
const arg = (name) => process.argv.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const PUBLIC = arg('public') ?? join(ROOT, 'public');
const FILES_ONLY = !!arg('public');
const BROWSER = process.argv.includes('--browser');

const checks = [];
const record = (name, ok, detail) => { checks.push({ name, ok: !!ok, detail }); console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${name}`); };
const report = (code, couldNotRun) => {
  const failed = checks.filter((c) => !c.ok);
  for (const c of failed) console.log(`\n  FAIL ${c.name}\n  ${JSON.stringify(c.detail).slice(0, 1500)}`);
  console.log(`\n  Queen spec sync contract: ${couldNotRun ? `COULD NOT RUN (${couldNotRun})` : failed.length ? `FAIL (${failed.length} of ${checks.length})` : `PASS (${checks.length} checks)`}`);
  process.exit(code);
};

// ── A. The files ──
/** The spec-* catalogs whose `ladder.specs` the SPECS rung has printed. */
const LADDERS = ['agents/spec-agents.json', 'crons/spec-crons.json', 'functions/spec-functions.json', 'skills/spec-skills.json', 'tools/spec-tools.json'];

/** Everything the files of one public/ tree disagree about; `read` returns a file's bytes. */
function corpusFindings(read) {
  const bytes = read('t27/manifest.json');
  const manifest = JSON.parse(bytes.toString('utf8'));
  const sha = createHash('sha256').update(bytes).digest('hex');
  const json = (path) => JSON.parse(read(path).toString('utf8'));
  return corpusDisagreements(manifest, sha, {
    atlas: json('t27/universe-atlas.json'),
    sharedCore: json('t27/shared-core.json'),
    ladders: Object.fromEntries(LADDERS.map((path) => [path, json(path).ladder?.specs])),
  });
}
const readFrom = (dir) => (path) => readFileSync(join(dir, path));

const served = corpusFindings(readFrom(PUBLIC));
record(`A the manifest, atlas, shared core and ${LADDERS.length} ladders under ${relative(process.cwd(), PUBLIC) || '.'} describe one scan`, served.length === 0, served);
if (FILES_ONLY) report(served.length ? 1 : 0);

// ── B. The source ──
/** The four parts the store owns; a quoted relative path to one outside it is a private copy. */
const CORPUS_PATHS = ['t27/manifest.json', 't27/universe-atlas.json', 'queen/modules.json', 'queen/foundation.json'];
const STORE = 'lib/queenCorpus.ts';

/** Every file under `dir` that names a corpus part in code, other than the store. */
function sourceFindings(dir) {
  const out = [];
  const walk = (d) => {
    for (const name of readdirSync(d)) {
      const path = join(d, name);
      if (statSync(path).isDirectory()) { walk(path); continue; }
      if (!/\.(ts|tsx|js|jsx|mjs)$/.test(name) || relative(dir, path) === STORE) continue;
      // Comments may name the files (several explain where a number comes from);
      // code may not. A URL loses its tail at `//` here, so a link to a file on
      // GitHub is not mistaken for a fetch of the served one.
      const code = readFileSync(path, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
      for (const part of CORPUS_PATHS) if (code.includes(part)) out.push(`${relative(dir, path)} names ${part}; only src/${STORE} may`);
    }
  };
  walk(dir);
  return out;
}
const rogue = sourceFindings(join(ROOT, 'src'));
record(`B only src/${STORE} reads ${CORPUS_PATHS.join(', ')}`, rogue.length === 0, rogue);

// ── C. The store ──
const fetched = [];
let failNext = 0;
globalThis.fetch = async (url) => {
  fetched.push(String(url));
  if (failNext > 0) { failNext -= 1; return new Response('down', { status: 503 }); }
  if (/^https?:/.test(String(url))) return new Response('not here', { status: 404 });
  const file = join(PUBLIC, String(url));
  return existsSync(file) ? new Response(readFileSync(file)) : new Response('missing', { status: 404 });
};
const { loadCorpus } = await import('../src/lib/queenCorpus.ts');
const manifestBytes = readFileSync(join(PUBLIC, 't27/manifest.json'));
const manifestFile = JSON.parse(manifestBytes.toString('utf8'));
const expected = corpusVersion(corpusIdentity(manifestFile, createHash('sha256').update(manifestBytes).digest('hex')));
{
  const [one, two, three] = await Promise.all([loadCorpus('manifest'), loadCorpus('manifest'), loadCorpus('manifest')]);
  const reads = fetched.filter((u) => u.endsWith('t27/manifest.json')).length;
  record('C three tabs asking for the manifest at once share one fetch and one part', reads === 1 && one === two && two === three, { reads });
  record(`C the store's version is the files' own (${expected})`, one.version === expected && one.identity.specCount === manifestFile.specs.length && one.source === 'file'
    && one.identity.manifestSha256 === createHash('sha256').update(manifestBytes).digest('hex'), { version: one.version, identity: one.identity });
  const later = await loadCorpus('manifest');
  record('C a tab opened later gets the same part without a second fetch', later === one && fetched.filter((u) => u.endsWith('t27/manifest.json')).length === 1, { reads: fetched.length });

  failNext = 1;
  const kept = await loadCorpus('manifest', { fresh: true }).then(() => 'replaced', () => 'refused');
  const still = await loadCorpus('manifest');
  record('C a failed poll keeps the part on show rather than dropping it', kept === 'refused' && still === one, { kept });

  failNext = 1;
  const first = await loadCorpus('atlas').then(() => 'loaded', (e) => String(e.message));
  const retry = await loadCorpus('atlas').then((part) => part, () => null);
  record('C a failed first read is forgotten, so the next tab retries instead of inheriting the failure', first !== 'loaded' && retry?.data?.specs?.length === manifestFile.specCount && retry.generatedAt === retry.data.at, { first, at: retry?.generatedAt });

  const wire = 'https://api.invalid/queen/public-modules';
  fetched.length = 0;
  const modules = await loadCorpus('modules', { wire });
  record('C a part with a wire tries it first and says so when it fell back to the vendored file', fetched[0] === wire && fetched[1].endsWith('queen/modules.json') && modules.source === 'file' && typeof modules.generatedAt === 'string', { fetched, source: modules.source });
}

// ── D. The address ──
const bundled = async (entry) => import(`data:text/javascript;base64,${Buffer.from((await build({
  entryPoints: [join(ROOT, entry)], bundle: true, format: 'esm', platform: 'node', write: false, logLevel: 'silent',
})).outputFiles[0].text).toString('base64')}`);
const { leaveTabSelections, explorerFrameHash, SELECTION_KEY } = await bundled('src/lib/queenEmbed.ts');
{
  const spec = 'specs/demos/hello_world.t27';
  const kept = leaveTabSelections(new URLSearchParams({ tab: 'skills', spec, skill: 'x', cron: 'y', agent: 'A', world: 'ghashtag/t27' }));
  const others = Object.entries(SELECTION_KEY).filter(([tab]) => tab !== 'specs').map(([, key]) => key);
  record('D a tab switch keeps spec= and the world, and drops every other tab\'s card', kept.get('spec') === spec && kept.get('world') === 'ghashtag/t27' && others.every((k) => !kept.has(k)), Object.fromEntries(kept));

  const world = specWorld('dmitrii-f-t27/trinity-memory');
  const hash = explorerFrameHash('specs', spec, world);
  const params = new URLSearchParams(hash.split('?')[1]);
  record(`D the shell's world (${world}) rides into the Spec Explorer frame`, params.get('world') === world && params.get('spec') === spec && params.get('embed') === '1', hash);
  record('D another tab\'s frame carries no world', !new URLSearchParams(explorerFrameHash('skills', null, world).split('?')[1] ?? '').has('world'), explorerFrameHash('skills', null, world));
  let refused = false;
  try { specExplorerHash(spec, { world: '../../evil' }); } catch { refused = true; }
  record('D a world that is not a repository name is refused, not written', refused);
}

// ── N. Negative fixtures: each must be reported ──
const FIXTURES = join(ROOT, 'qa/fixtures/queen-spec-sync');
{
  const real = readFrom(PUBLIC);
  const mutate = (path, change) => (p) => {
    if (p !== path) return real(p);
    const value = JSON.parse(real(p).toString('utf8'));
    change(value);
    return Buffer.from(JSON.stringify(value));
  };
  const cases = {
    'a ladder one spec behind': mutate('skills/spec-skills.json', (v) => { v.ladder.specs -= 1; }),
    'an atlas with one spec fewer': mutate('t27/universe-atlas.json', (v) => { v.specs.pop(); }),
    'an atlas built from another manifest': mutate('t27/universe-atlas.json', (v) => { v.provenance.manifestSha256 = '0'.repeat(64); }),
    'a comb world counting one more than the Explorer lists': mutate('t27/universe-atlas.json', (v) => { v.worlds[0].specCount += 1; }),
    'a shared core from a newer scan': mutate('t27/shared-core.json', (v) => { v.specs.push(v.specs[0]); }),
    'a manifest whose count is not its list': mutate('t27/manifest.json', (v) => { v.specCount += 1; }),
  };
  for (const [name, read] of Object.entries(cases)) {
    const found = corpusFindings(read);
    record(`N A reports ${name}`, found.length > 0, found);
  }

  const planted = sourceFindings(join(FIXTURES, 'src'));
  record('N B reports a component that fetches the manifest itself', planted.some((f) => f.startsWith('components/RogueManifest.ts names t27/manifest.json')), planted);
  record('N B lets a comment or a GitHub link name the files', !planted.some((f) => f.includes('CommentOnly')), planted);

  // The whole contract, on a copy of public/ that one stale catalog has drifted from.
  const stale = mkdtempSync(join(tmpdir(), 'queen-spec-sync-'));
  try {
    for (const path of ['t27/manifest.json', 't27/universe-atlas.json', 't27/shared-core.json', ...LADDERS]) {
      mkdirSync(dirname(join(stale, path)), { recursive: true });
      copyFileSync(join(PUBLIC, path), join(stale, path));
    }
    const ladder = JSON.parse(readFileSync(join(stale, 'tools/spec-tools.json'), 'utf8'));
    ladder.ladder.specs -= 1;
    writeFileSync(join(stale, 'tools/spec-tools.json'), JSON.stringify(ladder));
    const run = spawnSync(process.execPath, ['--experimental-strip-types', '--no-warnings', SELF, `--public=${stale}`], { encoding: 'utf8' });
    record('N the contract run on a public/ with one stale ladder exits 1', run.status === 1 && /spec-tools\.json ladder says/.test(run.stdout), { status: run.status, out: run.stdout.slice(-400) });
  } finally { rmSync(stale, { recursive: true, force: true }); }
}

// ── E. The page, every tab ──
/** Every way the tabs' readings disagree with each other or with the store's version. */
function tabFindings(readings, version) {
  const out = [];
  for (const r of readings) {
    if (r.version !== version) out.push(`${r.tab} ${r.where}: version ${r.version ?? 'absent'}, the files say ${version}`);
    if (String(r.count) !== version.split('/').pop()) out.push(`${r.tab} ${r.where}: ${r.count ?? 'no'} specs, the files say ${version.split('/').pop()}`);
  }
  return out;
}
{
  const good = [{ tab: 'specs', where: 'shell', count: manifestFile.specCount, version: expected }];
  record('N E reports a tab reading one spec fewer', tabFindings([...good, { tab: 'skills', where: 'frame', count: manifestFile.specCount - 1, version: expected }], expected).length === 1);
  record('N E reports a tab that never said which corpus it shows', tabFindings([...good, { tab: 'map', where: 'shell', count: null, version: null }], expected).length === 2);
  record('N E finds nothing wrong with agreeing tabs', tabFindings(good, expected).length === 0);
}

if (!BROWSER) report(checks.some((c) => !c.ok) ? 1 : 0);

const CHROME = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome', '/usr/bin/chromium-browser', '/usr/bin/chromium',
].filter(Boolean).find((p) => existsSync(p));
if (!CHROME) report(2, 'no Chrome found; set CHROME_PATH');

const DIST = join(ROOT, 'dist');
if (!process.argv.includes('--no-build')) { console.log('  building…'); execSync('npx vite build', { cwd: ROOT, stdio: ['ignore', 'ignore', 'inherit'] }); }
if (!existsSync(join(DIST, 'index.html'))) report(2, 'dist/index.html missing');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.webp': 'image/webp', '.wasm': 'application/wasm', '.woff2': 'font/woff2', '.t27': 'text/plain' };
const server = createServer((req, res) => {
  const path = normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
  let file = join(DIST, path);
  if (!file.startsWith(DIST) || !existsSync(file) || statSync(file).isDirectory()) file = join(DIST, 'index.html');
  res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream' });
  res.end(readFileSync(file));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const origin = `http://127.0.0.1:${server.address().port}`;

const profile = mkdtempSync(join(tmpdir(), 'queen-spec-sync-chrome-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check',
  '--disable-extensions', '--window-size=1440,900', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  // A CI runner's Chrome cannot start its sandbox, and /dev/shm there is small.
  ...(process.platform === 'linux' ? ['--no-sandbox', '--disable-dev-shm-usage'] : []), 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
process.on('exit', () => { try { chrome.kill('SIGKILL'); } catch { /* gone */ } try { rmSync(profile, { recursive: true, force: true }); } catch { /* gone */ } server.close(); });
const deadline = setTimeout(() => report(2, 'deadline 15 min'), 15 * 60000);

let evaluate, open;
try {
  const wsUrl = await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('Chrome never announced a debugging port')), 30000);
    let buf = '';
    chrome.stderr.on('data', (d) => { buf += d; const m = buf.match(/DevTools listening on (ws:\/\/\S+)/); if (m) { clearTimeout(t); resolve(m[1]); } });
  });
  const ws = new WebSocket(wsUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP socket refused')); });
  let id = 0; const pending = new Map();
  ws.onmessage = (ev) => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { const q = pending.get(m.id); pending.delete(m.id); if (m.error) q.reject(new Error(m.error.message)); else q.resolve(m.result); } };
  const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => { const i = ++id; pending.set(i, { resolve, reject }); ws.send(JSON.stringify({ id: i, method, params, ...(sessionId ? { sessionId } : {}) })); });
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  await send('Runtime.enable', {}, sessionId);
  evaluate = async (expression) => {
    const r = await Promise.race([send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId), new Promise((_, rej) => setTimeout(() => rej(new Error('evaluate timed out')), 60000))]);
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };
  open = (hash) => send('Page.navigate', { url: `${origin}/?lang=en#/queen?${hash}` }, sessionId);
  await open('tab=specs');
} catch (e) { report(2, String(e?.message || e)); }

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
// The hive's long tasks can hold the renderer past one evaluate's deadline; an
// action is retried rather than read as a page that cannot run.
const settle = async (expr) => { for (let i = 0; ; i++) { try { return await evaluate(expr); } catch (e) { if (i >= 3) throw e; await wait(2000); } } };
const until = async (expr, ms) => { const start = Date.now(); while (Date.now() - start < ms) { try { const v = await evaluate(expr); if (v) return v; } catch { /* between documents */ } await wait(300); } return null; };
// The shell's root, the SPECS rung and, where a Spec Explorer is framed, the frame's root.
const READ = `(() => {
  const main = document.querySelector('main[data-view]'); if (!main) return null;
  const out = { view: main.dataset.view, shell: { count: main.dataset.specCount ?? null, version: main.dataset.corpusVersion ?? null, source: main.dataset.corpusSource ?? null } };
  const rung = document.querySelector('.queen27-ladder-step[data-layer="specs"] .queen27-ladder-count');
  if (rung) out.rung = rung.textContent.trim() || null;
  const f = document.querySelector('iframe.queen27-specs-frame');
  try { const x = f?.contentDocument?.querySelector('.spec-x'); if (x) out.frame = { count: x.dataset.specCount ?? null, version: x.dataset.corpusVersion ?? null, world: x.dataset.specWorld ?? null, listed: f.contentDocument.querySelector('.spec-x-listed')?.dataset.specListed ?? null, hash: f.contentWindow.location.hash }; } catch { /* cross-origin */ }
  const reads = (w) => { try { return w.performance.getEntriesByType('resource').filter((e) => /\\/t27\\/manifest\\.json/.test(e.name)).length; } catch { return 0; } };
  out.manifestReads = reads(window) + (f ? reads(f.contentWindow) : 0);
  return out; })()`;

try {
  if (!(await until(`!!document.querySelector('main[data-view][data-corpus-version]')`, 150000))) report(2, 'the Queen shell never reported a corpus');
  const tabs = await settle(`[...document.querySelectorAll('button.queen27-hud-cmd[data-view]')].map((b) => b.dataset.view)`);
  const views = [...new Set([...tabs, 'specs', 'skills', 'crons', 'agents', 'functions', 'tools', 'providers'])];
  const readings = [];
  let specsSeen = null;
  for (const view of views) {
    await settle(`location.hash = ${JSON.stringify(`#/queen?tab=${view}`)}`);
    // A tab is reached the way a reader reaches it, by the address. Under a
    // software renderer the roadmap game's frame loop can hold the router's
    // transition off for minutes, so a tab that has not switched in 30 s is
    // opened by its own address instead -- the question is what the tab shows,
    // not how fast this Chrome switches. One that never answers is recorded with
    // what was last read.
    const arrived = `(() => { const r = ${READ}; return r && r.view === ${JSON.stringify(view)} && r.shell.version ? r : null })()`;
    let settled = await until(arrived, 30000);
    if (!settled) { await open(`tab=${view}`); settled = await until(arrived, 150000); }
    if (!settled) { const last = await settle(READ).catch((e) => ({ error: String(e?.message || e) })); readings.push({ tab: view, where: 'shell', count: null, version: null, last }); continue; }
    readings.push({ tab: view, where: 'shell', ...settled.shell });
    if ('rung' in settled) readings.push({ tab: view, where: 'SPECS rung', count: settled.rung, version: settled.shell.version });
    if (view === 'specs') {
      specsSeen = await until(`(() => { const r = ${READ}; return r?.frame?.version && r.frame.listed ? r : null })()`, 150000);
      readings.push({ tab: view, where: 'Explorer frame', count: specsSeen?.frame.count ?? null, version: specsSeen?.frame.version ?? null });
      if (specsSeen) readings.push({ tab: view, where: 'Explorer list', count: specsSeen.frame.listed, version: specsSeen.frame.version });
    }
  }
  const found = tabFindings(readings, expected);
  const where = readings.reduce((n, r) => ({ ...n, [r.where]: (n[r.where] ?? 0) + 1 }), {});
  console.log(`  read ${readings.length} numbers: ${Object.entries(where).map(([w, n]) => `${n} ${w}`).join(', ')}`);
  record(`E every one of ${views.length} tabs reports ${expected}, shell, rung and frame alike`, found.length === 0, { found, readings });
  record('E the shell and the Explorer frame read the manifest once between them', specsSeen?.manifestReads === 1, { reads: specsSeen?.manifestReads });

  // A world chosen in the shell narrows the frame to the comb's count for it.
  const counts = new Map(); for (const s of manifestFile.specs) counts.set(specWorld(s.repo), (counts.get(specWorld(s.repo)) ?? 0) + 1);
  const [world, size] = [...counts].filter(([w]) => w !== 'ghashtag/t27').sort((a, b) => b[1] - a[1])[0];
  await open('tab=specs');
  await until(`!!(${READ})?.frame?.listed`, 150000);
  await settle(`location.hash = ${JSON.stringify(`#/queen?tab=specs&world=${world}`)}`);
  const narrowed = await until(`(() => { const r = ${READ}; return r?.frame?.world === ${JSON.stringify(world)} && r.frame.listed === ${JSON.stringify(String(size))} ? r : null })()`, 60000);
  record(`E world=${world} in the shell's address narrows the Explorer frame to its ${size} specs`, !!narrowed, narrowed ?? await settle(READ));
} catch (e) {
  clearTimeout(deadline);
  report(2, String(e?.message || e));
}
clearTimeout(deadline);
report(checks.some((c) => !c.ok) ? 1 : 0);
